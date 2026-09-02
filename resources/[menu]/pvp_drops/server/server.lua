-- =============================================
--   PVP DROPS - Serveur
-- =============================================

local ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

local activeDrop     = nil
local dropItemLocks  = {}   -- [itemName] = true pendant le traitement

-- ── Notifications ────────────────────────────────────────────────────────
-- Système générique de vanta_ui : plus de détournement de `pvp_market:notify`
-- (event nommé d'après pvp_market mais en réalité géré par pvp_inventory —
-- pvp_drops cassait donc si l'une ou l'autre resource bougeait).
local function notify(src, msg, kind)
    exports['vanta_ui']:notify(src, msg, kind)
end

local function notifyAll(msg, kind, duration)
    exports['vanta_ui']:notifyAll(msg, kind, duration, 'Drop de ravitaillement')
end

-- ── Tirage du loot ────────────────────────────────────────────────────────
local function rollDropLoot()
    local usedItems = {}
    local result = {}

    for i = 1, Config.LootCount do
        local totalWeight = 0
        local available = {}
        for _, entry in ipairs(Config.LootTable) do
            if not usedItems[entry.item] then
                totalWeight = totalWeight + entry.chance
                available[#available + 1] = entry
            end
        end
        if #available == 0 then break end

        local roll = math.random() * totalWeight
        local cumul = 0
        for _, entry in ipairs(available) do
            cumul = cumul + entry.chance
            if roll <= cumul then
                result[#result + 1] = { item = entry.item, count = entry.count }
                usedItems[entry.item] = true
                break
            end
        end
    end
    return result
end

-- ── Contrôleur : le joueur le plus proche de la zone ─────────────────────
-- (c'est lui qui fait tourner l'avion, la caisse et les raycasts de
--  collision — le plus proche est celui qui a la map en streaming)
-- `excludeSrc` sert à la réassignation : on ne veut jamais redésigner le
-- joueur qui vient de se déconnecter.
local function pickController(x, y, excludeSrc)
    local best, bestDist = nil, nil
    for _, pid in ipairs(GetPlayers()) do
        local src = tonumber(pid)
        if src and src ~= excludeSrc then
            local ped = GetPlayerPed(src)
            if ped and ped ~= 0 then
                local c = GetEntityCoords(ped)
                local dx, dy = c.x - x, c.y - y
                local d2 = dx * dx + dy * dy
                if not bestDist or d2 < bestDist then best, bestDist = src, d2 end
            end
        end
    end
    return best
end

-- ── Payload client ───────────────────────────────────────────────────────
-- `elapsed` permet à un joueur qui rejoint en cours de drop de recaler sa
-- timeline locale sur celle du serveur au lieu de rejouer l'animation depuis
-- le début. Si la caisse est déjà posée, `landed`/`landZ`/`openRemainingMs`
-- permettent au client de sauter directement en phase "sécurisation"/"prête"
-- plutôt que de rejouer une chute déjà terminée.
local function dropPayload()
    if not activeDrop then return nil end
    local openRemainingMs = nil
    if activeDrop.landed and activeDrop.openAt then
        openRemainingMs = activeDrop.openAt - GetGameTimer()
    end
    return {
        id              = activeDrop.id,
        planeStartX     = activeDrop.planeStartX,
        planeStartY     = activeDrop.planeStartY,
        planeEndX       = activeDrop.planeEndX,
        planeEndY       = activeDrop.planeEndY,
        dropPct         = activeDrop.dropPct,
        dropX           = activeDrop.dropX,
        dropY           = activeDrop.dropY,
        fallbackZ       = activeDrop.fallbackZ,
        altitude        = activeDrop.altitude,
        approachTime    = activeDrop.approachTime,
        fallDuration    = activeDrop.fallDuration,
        openDelay       = activeDrop.openDelay,
        controller      = activeDrop.controller,
        elapsed         = GetGameTimer() - activeDrop.startedAt,
        landed          = activeDrop.landed,
        landZ           = activeDrop.landZ,
        openRemainingMs = openRemainingMs,
    }
end

-- ── Fin de drop ──────────────────────────────────────────────────────────
-- Toujours passer par ici : mettre `activeDrop = nil` sans prévenir les clients
-- laissait la caisse, les blips et le marker affichés indéfiniment en jeu.
local function endDrop(reason)
    if not activeDrop then return end
    local id = activeDrop.id
    local remaining = #activeDrop.loot
    activeDrop    = nil
    dropItemLocks = {}
    TriggerClientEvent('pvp_drops:ended', -1, id, reason)
    print(('[pvp_drops] Drop #%d terminé (%s) — %d item(s) restant(s)'):format(id, reason, remaining))
end

-- Déclaration anticipée : le watchdog de largage (dans startDrop) référence
-- markLanded avant sa définition plus bas (dépend de reportGroundZ/reportLanded).
local markLanded

-- ── Démarrer un drop ─────────────────────────────────────────────────────
-- opts = { x, y, z, label, fast }
--   x/y/z : position imposée (tests) — sinon une zone de Config.DropZones
--   fast  : timers courts de Config.TestTimers (commande /droptest)
local function startDrop(opts)
    opts = opts or {}
    if activeDrop then return false, 'Un drop est déjà en cours (/droptest stop pour l\'annuler).' end

    local zone
    if opts.x and opts.y then
        zone = { x = opts.x + 0.0, y = opts.y + 0.0, z = (opts.z or 30.0) + 0.0,
                 label = opts.label or 'Position de test' }
    else
        zone = Config.DropZones[math.random(#Config.DropZones)]
    end

    local T = opts.fast and Config.TestTimers or nil
    local approachTime = (T and T.approachTime) or Config.ApproachTime
    local fallDuration = (T and T.fallDuration) or Config.FallDuration
    local openDelay    = (T and T.openDelay)    or Config.OpenDelay
    local altitude     = (T and T.altitude)     or Config.DropAltitude
    local halfLen      = (T and T.planeStartDistance) or Config.PlaneStartDistance

    -- Trajectoire de l'avion : passe au-dessus de la zone de drop
    local angle  = math.random() * math.pi * 2
    local startX = zone.x + math.cos(angle) * halfLen
    local startY = zone.y + math.sin(angle) * halfLen
    local endX   = zone.x - math.cos(angle) * halfLen
    local endY   = zone.y - math.sin(angle) * halfLen

    -- Le drop tombe au milieu de la trajectoire (50%)
    local dropPct = 0.5

    local controller = pickController(zone.x, zone.y)
    if not controller then
        print('[pvp_drops] Aucun joueur connecté — drop annulé.')
        return false, 'Aucun joueur connecté.'
    end

    activeDrop = {
        id          = math.random(10000, 99999),
        planeStartX = startX,
        planeStartY = startY,
        planeEndX   = endX,
        planeEndY   = endY,
        dropPct     = dropPct,
        dropX       = zone.x,
        dropY       = zone.y,
        landX       = zone.x,
        landY       = zone.y,
        -- ⚠ Z de SECOURS uniquement : la vraie altitude d'impact est
        -- déterminée côté client par raycast (toit de bâtiment, relief...).
        fallbackZ   = zone.z,
        landZ       = nil,
        landed      = false,
        landedAt    = nil,
        openAt      = nil,
        loot        = rollDropLoot(),
        opened      = false,
        controller  = controller,
        label       = zone.label,
        startedAt   = GetGameTimer(),
        approachTime = approachTime,
        fallDuration = fallDuration,
        openDelay    = openDelay,
        altitude     = altitude,
        dropTimeMs   = dropPct * approachTime * 2,
        fast         = opts.fast and true or false,
        -- Durée de vie totale : passé ce délai la caisse est retirée même
        -- si elle n'a pas été vidée (sinon blips/caisse restaient affichés
        -- côté client pour un drop déjà supprimé côté serveur).
        expiresAt   = os.time() + math.floor(Config.DropLifetime / 1000),
    }

    TriggerClientEvent('pvp_drops:start', -1, dropPayload())

    notifyAll(
        'Un avion de ravitaillement a été détecté — suivez sa trajectoire. [' .. zone.label .. ']',
        'warning',
        8000
    )

    print(('[pvp_drops] Drop #%d — zone: %s (%.0f, %.0f) %s — contrôleur: %d'):format(
        activeDrop.id, zone.label, zone.x, zone.y, activeDrop.fast and '[TEST]' or '', controller
    ))

    -- Watchdog : si le contrôleur ne rapporte jamais l'atterrissage
    -- (déconnexion, collision jamais chargée...), on pose la caisse d'office.
    local watchId    = activeDrop.id
    local watchDelay = activeDrop.dropTimeMs + fallDuration + 15000
    CreateThread(function()
        Wait(watchDelay)
        if activeDrop and activeDrop.id == watchId and not activeDrop.landed then
            print('[pvp_drops] Watchdog : atterrissage non rapporté, Z de secours utilisé.')
            markLanded(activeDrop.landZ or activeDrop.fallbackZ)
        end
    end)

    return true
end

-- ── Synchronisation d'un client qui rejoint en cours de drop ─────────────
RegisterNetEvent('pvp_drops:requestSync')
AddEventHandler('pvp_drops:requestSync', function()
    local src = source
    local payload = dropPayload()
    if not payload then return end
    TriggerClientEvent('pvp_drops:start', src, payload)
end)

-- ── Atterrissage ─────────────────────────────────────────────────────────
-- Le contrôleur affine le Z de la surface d'impact pendant l'approche
-- (raycast vertical : toit de bâtiment, montagne, prop, sol...).
RegisterNetEvent('pvp_drops:reportGroundZ')
AddEventHandler('pvp_drops:reportGroundZ', function(dropId, landX, landY, landZ)
    local src = source
    if not activeDrop or activeDrop.id ~= dropId then return end
    if activeDrop.controller ~= src then return end
    if activeDrop.landed then return end
    if type(landZ) ~= 'number' or landZ ~= landZ then return end   -- NaN
    if landZ < -300.0 or landZ > 2000.0 then return end

    activeDrop.landX = landX
    activeDrop.landY = landY
    activeDrop.landZ = landZ

    TriggerClientEvent('pvp_drops:landingCoords', -1, dropId, landX, landY, landZ)
end)

-- Bascule serveur : la caisse a touché une surface → départ du chrono
-- d'ouverture, identique pour tout le monde.
markLanded = function(z)
    if not activeDrop or activeDrop.landed then return end
    activeDrop.landed   = true
    activeDrop.landZ    = z
    activeDrop.landedAt = GetGameTimer()
    activeDrop.openAt   = activeDrop.landedAt + activeDrop.openDelay

    TriggerClientEvent('pvp_drops:landed', -1, activeDrop.id,
        activeDrop.landX, activeDrop.landY, z, activeDrop.openDelay)

    print(('[pvp_drops] Caisse posée : %.1f, %.1f, %.1f (ouverture dans %ds)'):format(
        activeDrop.landX, activeDrop.landY, z, activeDrop.openDelay / 1000))
end

-- Le contrôleur signale le contact.
RegisterNetEvent('pvp_drops:reportLanded')
AddEventHandler('pvp_drops:reportLanded', function(dropId, landX, landY, landZ)
    local src = source
    if not activeDrop or activeDrop.id ~= dropId then return end
    if activeDrop.controller ~= src then return end
    if type(landZ) ~= 'number' or landZ ~= landZ then return end
    if landZ < -300.0 or landZ > 2000.0 then return end

    activeDrop.landX = landX
    activeDrop.landY = landY
    markLanded(landZ)
end)

-- ── Utilitaire : loot avec labels pour le NUI ────────────────────────────
local function lootWithLabels(loot)
    local result = {}
    for _, item in ipairs(loot) do
        local obj = ESX.GetItem and ESX.GetItem(item.item) or nil
        result[#result + 1] = {
            name  = item.item,
            label = obj and obj.label or item.item,
            count = item.count,
        }
    end
    return result
end

-- ── Helper : distance horizontale d'un joueur au drop ──────────────────
local LOCK_TIMEOUT_S = 60  -- SÉCURITÉ : un joueur qui laisse l'UI ouverte
                            -- > 60s (crash, déco, AFK) libère le drop.
local function playerNearDrop(src)
    if not activeDrop or not activeDrop.landed or not activeDrop.landZ then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local c = GetEntityCoords(ped)
    local dx = c.x - (activeDrop.landX or 0)
    local dy = c.y - (activeDrop.landY or 0)
    local dz = c.z - (activeDrop.landZ or 0)
    return (dx * dx + dy * dy + dz * dz) <= 100.0  -- <=10m (radius généreux vs parachute)
end

-- ── Ouvrir la caisse → ouvre l'UI inventaire ─────────────────────────────
RegisterNetEvent('pvp_drops:open')
AddEventHandler('pvp_drops:open', function(dropId)
    local src = source
    if not activeDrop or activeDrop.id ~= dropId then return end
    if activeDrop.opened then
        notify(src, 'La caisse a déjà été ouverte !', 'error')
        return
    end
    -- SÉCURITÉ : timeout sur lockedBy (un joueur peut avoir déco sans trigger closeUI).
    if activeDrop.lockedBy and activeDrop.lockedAt then
        if (os.time() - activeDrop.lockedAt) > LOCK_TIMEOUT_S then
            activeDrop.lockedBy = nil
            activeDrop.lockedAt = nil
        end
    end
    if activeDrop.lockedBy and activeDrop.lockedBy ~= src then
        -- Vérifier que le joueur est encore connecté, sinon libérer
        if not GetPlayerName(activeDrop.lockedBy) then
            activeDrop.lockedBy = nil
            activeDrop.lockedAt = nil
        else
            notify(src, 'Un joueur accède déjà à ce drop !', 'error')
            return
        end
    end

    -- SÉCURITÉ : la caisse doit être posée et le délai de sécurisation écoulé
    -- (le client affiche le compte à rebours, le serveur fait foi).
    if not activeDrop.landed then
        notify(src, 'La caisse n\'a pas encore touché le sol !', 'error')
        return
    end
    if activeDrop.openAt and GetGameTimer() < activeDrop.openAt then
        local rem = math.ceil((activeDrop.openAt - GetGameTimer()) / 1000)
        notify(src, ('Caisse verrouillée encore %ds.'):format(rem), 'error')
        return
    end

    -- SÉCURITÉ : le joueur doit être à proximité du drop.
    if not playerNearDrop(src) then
        notify(src, 'Trop loin du drop.', 'error')
        return
    end

    -- SÉCURITÉ : impossible de fouiller depuis un véhicule (le client bloque
    -- déjà le prompt, ceci ferme la porte à un trigger forgé).
    local srcPed = GetPlayerPed(src)
    -- Côté serveur, GET_VEHICLE_PED_IS_IN ne prend que le ped (pas de flag
    -- "lastVehicle") et renvoie 0 quand le joueur est à pied.
    if srcPed and srcPed ~= 0 and GetVehiclePedIsIn(srcPed) ~= 0 then
        notify(src, 'Descends de ton véhicule pour ouvrir le drop.', 'error')
        return
    end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    activeDrop.lockedBy = src
    activeDrop.lockedAt = os.time()

    -- Inventaire du joueur
    local inventory = {}
    for _, item in ipairs(xPlayer.getInventory()) do
        if item.count > 0 then
            inventory[#inventory + 1] = { name = item.name, label = item.label, count = item.count }
        end
    end

    TriggerClientEvent('pvp_inventory:openUIWithDrop', src, {
        dropId    = activeDrop.id,
        dropLabel = '★ DROP DE RAVITAILLEMENT',
        dropItems = lootWithLabels(activeDrop.loot),
        inventory = inventory,
        money     = { bank = xPlayer.getAccount('bank').money },
    })

    print('[pvp_drops] ' .. (GetPlayerName(src) or 'Joueur') .. ' ouvre le drop #' .. dropId)
end)

-- ── Prendre un item du drop ───────────────────────────────────────────────
RegisterNetEvent('pvp_drops:takeItem')
AddEventHandler('pvp_drops:takeItem', function(dropId, itemName, qty)
    local src = source
    if not activeDrop or activeDrop.id ~= dropId then return end
    if activeDrop.lockedBy ~= src then return end

    -- SÉCURITÉ : validations d'entrée (anti-type-confusion, anti-injection).
    if type(itemName) ~= 'string' or itemName == '' or #itemName > 64 then return end
    if not itemName:match('^[a-z0-9_]+$') then return end

    -- SÉCURITÉ : le joueur doit toujours être proche du drop.
    if not playerNearDrop(src) then return end

    -- Anti-duplication : verrouillage par item
    if dropItemLocks[itemName] then return end
    dropItemLocks[itemName] = true

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then
        dropItemLocks[itemName] = nil
        return
    end

    -- Valider qty (cap 999 pour éviter tonumber('inf') ou overflow)
    qty = math.max(1, math.min(999, math.floor(tonumber(qty) or 1)))

    -- SÉCURITÉ : vérification poids sac serveur (même logique que pvp_inventory).
    local canAdd = true
    local ok, res = pcall(function()
        return exports['pvp_inventory']:canAddToBag(src, itemName, qty)
    end)
    if ok and res == false then canAdd = false end
    if not canAdd then
        dropItemLocks[itemName] = nil
        notify(src, 'Sac trop lourd !', 'error')
        return
    end

    -- Trouver et retirer l'item du drop
    local found     = false
    local takenLabel = itemName
    for i, item in ipairs(activeDrop.loot) do
        if item.item == itemName then
            found = true
            local taken = math.min(qty, item.count)
            xPlayer.addInventoryItem(itemName, taken)
            local obj = ESX.GetItem and ESX.GetItem(itemName) or nil
            takenLabel = obj and obj.label or itemName
            if item.count <= taken then
                table.remove(activeDrop.loot, i)
            else
                item.count = item.count - taken
            end
            break
        end
    end
    dropItemLocks[itemName] = nil
    if not found then return end

    -- Annonce chat : qui a pris quoi dans l'airdrop (visible de tout le serveur).
    TriggerClientEvent('chat:addMessage', -1, {
        color = { 255, 200, 50 },
        args = { '★ DROP ★', (GetPlayerName(src) or 'Joueur') .. ' a récupéré ' .. takenLabel .. ' dans le airdrop.' }
    })

    -- Inventaire mis à jour
    local inventory = {}
    for _, item in ipairs(xPlayer.getInventory()) do
        if item.count > 0 then
            inventory[#inventory + 1] = { name = item.name, label = item.label, count = item.count }
        end
    end

    -- Rafraîchir le NUI
    TriggerClientEvent('pvp_inventory:refreshFromDrop', src, {
        dropItems = lootWithLabels(activeDrop.loot),
        inventory = inventory,
    })

    -- Drop vide → fermer pour tout le monde
    if #activeDrop.loot == 0 then
        local playerName = GetPlayerName(src) or 'Joueur'
        notifyAll(playerName .. ' a tout récupéré dans le drop.', 'info', 6000)
        endDrop('looted')
    end
end)

-- ── Joueur ferme l'UI sans tout prendre ──────────────────────────────────
RegisterNetEvent('pvp_drops:closeUI')
AddEventHandler('pvp_drops:closeUI', function(dropId)
    local src = source
    if not activeDrop or activeDrop.id ~= dropId then return end
    if activeDrop.lockedBy ~= src then return end
    activeDrop.lockedBy = nil  -- libère le drop pour un autre joueur
    activeDrop.lockedAt = nil
    print('[pvp_drops] ' .. (GetPlayerName(src) or 'Joueur') .. ' ferme le drop #' .. dropId .. ' (' .. #activeDrop.loot .. ' items restants)')
end)

-- ── Scheduler ─────────────────────────────────────────────────────────────
AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    print('[pvp_drops] 1er drop dans ' .. (Config.FirstDropDelay / 60000) .. ' min')
end)

CreateThread(function()
    Wait(Config.FirstDropDelay)
    startDrop()
    while true do
        Wait(Config.DropInterval)
        endDrop('replaced')
        Wait(5000)
        startDrop()
    end
end)

-- ── Watchdog d'expiration ────────────────────────────────────────────────
-- Un drop jamais vidé ne doit pas rester en jeu jusqu'au prochain cycle.
CreateThread(function()
    while true do
        Wait(10000)
        if activeDrop and activeDrop.expiresAt and os.time() >= activeDrop.expiresAt then
            notifyAll('La caisse de ravitaillement n\'a pas été récupérée à temps.', 'info', 6000)
            endDrop('expired')
        end
    end
end)

-- =========================================================================
--   COMMANDES ADMIN
-- =========================================================================
local function isAdmin(src)
    if not src or src == 0 then return true end          -- console
    local xPlayer = ESX and ESX.GetPlayerFromId(src) or nil
    if not xPlayer then return false end
    return Config.AdminGroups[xPlayer.getGroup()] == true
end

local function say(src, msg)
    if not src or src == 0 then print('[pvp_drops] ' .. msg) return end
    TriggerClientEvent('chat:addMessage', src, { color = { 255, 200, 50 }, args = { '★ DROP ★', msg } })
end

-- SÉCURITÉ : restricted = true force une ACE admin. Sans ça, n'importe quel
-- joueur pouvait exécuter /dropadmin et déclencher un drop à volonté.
RegisterCommand('dropadmin', function(src, args, raw)
    if not isAdmin(src) then return end
    endDrop('admin')
    startDrop()
end, true)

-- ── /droptest — outil de test des étapes du drop ─────────────────────────
-- Permet de valider chaque phase sans attendre les minuteurs de production.
local TEST_HELP = {
    '/droptest            — drop de test (timers courts) sur une zone aléatoire',
    '/droptest ici        — drop de test à TA position (idéal pour tester un toit)',
    '/droptest zone <n>   — drop de test sur la zone n de Config.DropZones',
    '/droptest zones      — liste les zones disponibles',
    '/droptest reel       — drop avec les VRAIS timers de production',
    '/droptest largage    — saute l\'approche : largage immédiat',
    '/droptest sol        — pose la caisse immédiatement (fin de chute)',
    '/droptest ouvrir     — pose la caisse ET débloque l\'ouverture',
    '/droptest tp         — te téléporte sur la caisse',
    '/droptest info       — état du drop en cours (phase, position, loot)',
    '/droptest stop       — annule le drop en cours',
}

-- Avance tous les compteurs (serveur + clients) de `ms`
local function fastForward(ms)
    if ms <= 0 then return end
    activeDrop.startedAt = activeDrop.startedAt - ms
    if activeDrop.openAt then activeDrop.openAt = activeDrop.openAt - ms end
    TriggerClientEvent('pvp_drops:timeShift', -1, activeDrop.id, ms)
end

local function phaseName()
    if not activeDrop then return 'aucun' end
    if activeDrop.opened then return 'ouvert' end
    if activeDrop.landed then
        if activeDrop.openAt and GetGameTimer() < activeDrop.openAt then return 'sécurisation' end
        return 'ouvrable'
    end
    local el = GetGameTimer() - activeDrop.startedAt
    if el < activeDrop.dropTimeMs then return 'approche' end
    return 'chute'
end

RegisterCommand('droptest', function(src, args)
    if not isAdmin(src) then say(src, 'Accès refusé.') return end
    local sub = (args[1] or ''):lower()

    -- ── Lancer ───────────────────────────────────────────────────────────
    if sub == '' or sub == 'start' or sub == 'fast' then
        endDrop('test_restart')
        local ok, err = startDrop({ fast = true })
        say(src, ok and 'Drop de test lancé (timers courts).' or err)

    elseif sub == 'reel' or sub == 'réel' or sub == 'full' then
        endDrop('test_restart')
        local ok, err = startDrop()
        say(src, ok and 'Drop lancé avec les timers de production.' or err)

    elseif sub == 'ici' or sub == 'here' then
        if not src or src == 0 then say(src, 'Commande à utiliser en jeu.') return end
        local ped = GetPlayerPed(src)
        local c   = GetEntityCoords(ped)
        endDrop('test_restart')
        local ok, err = startDrop({ x = c.x, y = c.y, z = c.z, fast = true,
                                    label = 'Test — position admin' })
        say(src, ok and ('Drop de test sur ta position (%.0f, %.0f).'):format(c.x, c.y) or err)

    elseif sub == 'zones' then
        for i, z in ipairs(Config.DropZones) do
            say(src, ('%d — %s (%.0f, %.0f)'):format(i, z.label, z.x, z.y))
        end

    elseif sub == 'zone' then
        local n = tonumber(args[2] or '')
        local z = n and Config.DropZones[n] or nil
        if not z then say(src, 'Zone inconnue. /droptest zones') return end
        endDrop('test_restart')
        local ok, err = startDrop({ x = z.x, y = z.y, z = z.z, label = z.label, fast = true })
        say(src, ok and ('Drop de test sur %s.'):format(z.label) or err)

    -- ── Sauter des étapes ────────────────────────────────────────────────
    elseif sub == 'largage' or sub == 'drop' or sub == 'skip' then
        if not activeDrop then say(src, 'Aucun drop en cours.') return end
        if activeDrop.landed then say(src, 'La caisse est déjà posée.') return end
        local el  = GetGameTimer() - activeDrop.startedAt
        local rem = activeDrop.dropTimeMs - el
        if rem <= 0 then say(src, 'Le largage a déjà eu lieu.') return end
        fastForward(rem + 100)
        say(src, 'Approche sautée → largage immédiat.')

    elseif sub == 'sol' or sub == 'land' then
        if not activeDrop then say(src, 'Aucun drop en cours.') return end
        if activeDrop.landed then say(src, 'La caisse est déjà posée.') return end
        local el  = GetGameTimer() - activeDrop.startedAt
        if el < activeDrop.dropTimeMs then fastForward(activeDrop.dropTimeMs - el + 100) end
        -- le contrôleur pose la caisse sur la 1re surface trouvée
        TriggerClientEvent('pvp_drops:forceLand', activeDrop.controller, activeDrop.id)
        say(src, 'Chute sautée → la caisse se pose sur la première surface.')

    elseif sub == 'ouvrir' or sub == 'open' then
        if not activeDrop then say(src, 'Aucun drop en cours.') return end
        local dropId = activeDrop.id
        if not activeDrop.landed then
            local el = GetGameTimer() - activeDrop.startedAt
            if el < activeDrop.dropTimeMs then fastForward(activeDrop.dropTimeMs - el + 100) end
            TriggerClientEvent('pvp_drops:forceLand', activeDrop.controller, dropId)
        end
        say(src, 'Caisse débloquée : ouverture immédiate.')
        CreateThread(function()
            -- laisse au contrôleur le temps de poser la caisse et de rapporter
            local waited = 0
            while activeDrop and activeDrop.id == dropId and not activeDrop.landed and waited < 4000 do
                Wait(200); waited = waited + 200
            end
            if not activeDrop or activeDrop.id ~= dropId then return end
            if not activeDrop.landed then
                markLanded(activeDrop.landZ or activeDrop.fallbackZ)
            end
            activeDrop.openAt = GetGameTimer()
            TriggerClientEvent('pvp_drops:openNow', -1, dropId)
        end)

    -- ── Divers ───────────────────────────────────────────────────────────
    elseif sub == 'tp' then
        if not activeDrop then say(src, 'Aucun drop en cours.') return end
        if not src or src == 0 then return end
        TriggerClientEvent('pvp_drops:tpToDrop', src,
            activeDrop.landX, activeDrop.landY,
            activeDrop.landZ or activeDrop.fallbackZ)
        say(src, 'Téléporté sur la caisse.')

    elseif sub == 'info' then
        if not activeDrop then say(src, 'Aucun drop en cours.') return end
        say(src, ('Drop #%d — %s — phase: %s%s'):format(
            activeDrop.id, activeDrop.label or '?', phaseName(),
            activeDrop.fast and ' [TEST]' or ''))
        say(src, ('Position: %.0f, %.0f, Z=%s (secours %.1f) — contrôleur: %s'):format(
            activeDrop.landX, activeDrop.landY,
            activeDrop.landZ and ('%.1f'):format(activeDrop.landZ) or 'non sondé',
            activeDrop.fallbackZ, GetPlayerName(activeDrop.controller) or '?'))
        local names = {}
        for _, it in ipairs(activeDrop.loot) do names[#names + 1] = it.item .. ' x' .. it.count end
        say(src, 'Loot: ' .. (#names > 0 and table.concat(names, ', ') or 'vide'))

    elseif sub == 'stop' or sub == 'cancel' then
        if not activeDrop then say(src, 'Aucun drop en cours.') return end
        endDrop('test_stop')
        say(src, 'Drop annulé et nettoyé.')

    else
        for _, line in ipairs(TEST_HELP) do say(src, line) end
    end
end, false)

-- ── Déconnexion : libérer le lock ET réassigner le contrôleur ────────────
-- Sans réassignation, la déco du contrôleur figeait l'avion et la caisse pour
-- tous les autres joueurs, sans erreur ni message.
AddEventHandler('playerDropped', function()
    local src = source
    if not activeDrop then return end

    if activeDrop.lockedBy == src then
        activeDrop.lockedBy = nil
        activeDrop.lockedAt = nil
    end

    if activeDrop.controller == src then
        local newController = pickController(activeDrop.dropX, activeDrop.dropY, src)
        if not newController then
            -- Plus personne pour piloter les entités : le drop n'a plus de sens.
            endDrop('no_players')
            return
        end
        activeDrop.controller = newController
        TriggerClientEvent('pvp_drops:controllerChanged', -1, activeDrop.id, newController)
        print(('[pvp_drops] Contrôleur %d déconnecté — drop #%d réassigné à %d'):format(
            src, activeDrop.id, newController))
    end
end)

-- ── Event pour forcer un drop depuis un CLIENT (vérification admin) ──────
-- Chemin réseau uniquement : un client modifié pourrait appeler
-- TriggerServerEvent('pvp_drops:forceStart') directement sans passer par
-- pvp_admin, d'où la vérification de groupe ESX ici.
RegisterNetEvent('pvp_drops:forceStart')
AddEventHandler('pvp_drops:forceStart', function()
    -- `source` n'est pas forcément un nombre : sur un TriggerEvent serveur
    -- local (autre resource), FXServer laisse une string dans le global, et
    -- `src <= 0` levait « attempt to compare string with number ».
    local src = tonumber(source)
    if not src or src <= 0 then return end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local group = xPlayer.getGroup()
    if group ~= 'admin' and group ~= 'superadmin' then
        print(('[pvp_drops] BLOCKED: joueur %d (%s) a tenté de forcer un drop sans permission admin'):format(
            src, xPlayer.identifier))
        return
    end
    endDrop('admin')
    startDrop()
end)

-- ── Export pour forcer un drop depuis une AUTRE RESOURCE SERVEUR (pvp_admin) ──
-- Ne pas utiliser TriggerEvent() ici : `source` est un global PAR RESOURCE
-- dans FXServer, il ne porte donc PAS l'id du joueur qui a appelé pvp_admin
-- côté pvp_drops (il vaut 0, ou une valeur périmée d'un event réseau
-- précédent) — la vérification de groupe ci-dessus échouait ou passait au
-- hasard selon l'historique d'events, bloquant silencieusement le drop forcé
-- (aucun message d'erreur, juste un print serveur invisible du joueur).
-- pvp_admin a déjà vérifié la permission ('forcedrop') avant d'appeler cet
-- export : aucune revérification nécessaire ici.
exports('AdminForceStart', function()
    endDrop('admin')
    startDrop()
end)
