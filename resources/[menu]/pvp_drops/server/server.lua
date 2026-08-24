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

-- ── Contrôleur : le client qui pilote les entités (avion + caisse) ───────
-- Les autres clients ne font qu'interpoler la même trajectoire localement.
local function pickController(excludeSrc)
    for _, pid in ipairs(GetPlayers()) do
        local id = tonumber(pid)
        if id and id ~= excludeSrc then return id end
    end
    return nil
end

-- ── Payload client ───────────────────────────────────────────────────────
-- `elapsed` permet à un joueur qui rejoint en cours de drop de recaler sa
-- timeline locale sur celle du serveur au lieu de rejouer l'animation depuis
-- le début.
local function dropPayload()
    if not activeDrop then return nil end
    return {
        id           = activeDrop.id,
        planeStartX  = activeDrop.planeStartX,
        planeStartY  = activeDrop.planeStartY,
        planeEndX    = activeDrop.planeEndX,
        planeEndY    = activeDrop.planeEndY,
        dropPct      = activeDrop.dropPct,
        dropX        = activeDrop.dropX,
        dropY        = activeDrop.dropY,
        landZ        = activeDrop.landZ,
        altitude     = Config.DropAltitude,
        approachTime = Config.ApproachTime,
        fallDuration = Config.FallDuration,
        openDelay    = Config.OpenDelay,
        controller   = activeDrop.controller,
        elapsed      = GetGameTimer() - activeDrop.startedAt,
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

-- ── Démarrer un drop ─────────────────────────────────────────────────────
local function startDrop()
    if activeDrop then return end

    -- Choisir une zone de drop prédéfinie (Z fiable, pas de traversée de sol)
    local zone = Config.DropZones[math.random(#Config.DropZones)]
    local dropX = zone.x
    local dropY = zone.y
    local dropZ = zone.z

    -- Trajectoire de l'avion : passe au-dessus de la zone de drop
    local angle = math.random() * math.pi * 2
    local halfLen = Config.PlaneStartDistance

    local startX = dropX + math.cos(angle) * halfLen
    local startY = dropY + math.sin(angle) * halfLen
    local endX   = dropX - math.cos(angle) * halfLen
    local endY   = dropY - math.sin(angle) * halfLen

    -- Le drop tombe au milieu de la trajectoire (50%)
    local dropPct = 0.5

    -- Désigner un contrôleur (premier joueur connecté)
    local controller = pickController(nil)

    -- Si aucun joueur connecté, annuler le drop
    if not controller then
        print('[pvp_drops] Aucun joueur connecté — drop annulé.')
        return
    end

    activeDrop = {
        id          = math.random(10000, 99999),
        planeStartX = startX,
        planeStartY = startY,
        planeEndX   = endX,
        planeEndY   = endY,
        dropPct     = dropPct,
        dropX       = dropX,
        dropY       = dropY,
        landX       = dropX,
        landY       = dropY,
        landZ       = dropZ,   -- Z connu depuis Config.DropZones
        loot        = rollDropLoot(),
        opened      = false,
        controller  = controller,
        startedAt   = GetGameTimer(),
        expiresAt   = os.time() + math.floor(Config.DropLifetime / 1000),
    }

    TriggerClientEvent('pvp_drops:start', -1, dropPayload())

    notifyAll(
        'Un avion de ravitaillement a été détecté — suivez sa trajectoire. [' .. zone.label .. ']',
        'warning',
        8000
    )

    print(('[pvp_drops] Drop #%d — zone: %s (%.0f, %.0f, %.0f) — contrôleur: %d'):format(
        activeDrop.id, zone.label, dropX, dropY, dropZ, controller
    ))
end

-- ── Synchronisation d'un client qui rejoint en cours de drop ─────────────
RegisterNetEvent('pvp_drops:requestSync')
AddEventHandler('pvp_drops:requestSync', function()
    local src = source
    local payload = dropPayload()
    if not payload then return end
    TriggerClientEvent('pvp_drops:start', src, payload)
end)

-- ── Le contrôleur rapporte le Z du sol au point de drop ──────────────────
-- Filet de sécurité : en pratique le Z vient déjà de Config.DropZones.
RegisterNetEvent('pvp_drops:reportGroundZ')
AddEventHandler('pvp_drops:reportGroundZ', function(dropId, landX, landY, landZ)
    if not activeDrop or activeDrop.id ~= dropId then return end
    if activeDrop.landZ then return end  -- déjà connu
    if type(landZ) ~= 'number' then return end

    activeDrop.landX = landX
    activeDrop.landY = landY
    activeDrop.landZ = landZ

    -- Diffuser les coordonnées d'atterrissage à tous
    TriggerClientEvent('pvp_drops:landingCoords', -1, dropId, landX, landY, landZ)

    print(('[pvp_drops] Atterrissage confirmé : %.1f, %.1f, %.1f'):format(landX, landY, landZ))
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
    if not activeDrop or not activeDrop.landZ then return false end
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

    -- SÉCURITÉ : le joueur doit être à proximité du drop.
    if not playerNearDrop(src) then
        notify(src, 'Trop loin du drop.', 'error')
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
        dropLabel = 'DROP DE RAVITAILLEMENT',
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
    local found = false
    for i, item in ipairs(activeDrop.loot) do
        if item.item == itemName then
            found = true
            local taken = math.min(qty, item.count)
            xPlayer.addInventoryItem(itemName, taken)
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

-- SÉCURITÉ : restricted = true force une ACE admin. Sans ça, n'importe quel
-- joueur pouvait exécuter /dropadmin et déclencher un drop à volonté.
RegisterCommand('dropadmin', function(src, args, raw)
    if src and src > 0 then
        local xPlayer = ESX and ESX.GetPlayerFromId(src) or nil
        if not xPlayer then return end
        local group = xPlayer.getGroup()
        if group ~= 'admin' and group ~= 'superadmin' then return end
    end
    endDrop('admin')
    startDrop()
end, true)

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
        local newController = pickController(src)
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

-- ── Event pour forcer un drop depuis pvp_admin (vérification admin) ──────
RegisterNetEvent('pvp_drops:forceStart')
AddEventHandler('pvp_drops:forceStart', function()
    local src = source
    -- Si appelé depuis le serveur (src == 0), pas de vérif
    if src and src > 0 then
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return end
        local group = xPlayer.getGroup()
        if group ~= 'admin' and group ~= 'superadmin' then
            print(('[pvp_drops] BLOCKED: joueur %d (%s) a tenté de forcer un drop sans permission admin'):format(
                src, xPlayer.identifier))
            return
        end
    end
    endDrop('admin')
    startDrop()
end)
