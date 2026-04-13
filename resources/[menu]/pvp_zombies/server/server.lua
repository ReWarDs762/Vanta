-- =============================================
--   PVP ZOMBIES - Serveur
--   Récompenses, loot, stats kills
-- =============================================

local ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- Attente ESX prêt avant de traiter des events
CreateThread(function()
    local attempts = 0
    while ESX == nil do
        Wait(100)
        attempts = attempts + 1
        if attempts > 100 then
            print('[pvp_zombies] ERREUR : ESX non chargé après 10s !')
            break
        end
    end
    if ESX then
        print('[pvp_zombies] ESX chargé avec succès.')
    end
end)

-- ── Tirage du loot : 1 seul item par zombie (pondéré par chance) ──────────
-- Si inRedzone = true, les items rares/légendaires ont leurs chances multipliées
local function rollLoot(inRedzone)
    local lootTable = Config.LootTable
    if not lootTable or #lootTable == 0 then return {} end

    local multiplier = 1.0
    if inRedzone then
        -- Récupérer le multiplicateur depuis pvp_redzones config (fallback 2.0)
        local ok, rzMult = pcall(function()
            return exports['pvp_redzones']:getLootMultiplier()
        end)
        multiplier = (ok and rzMult) or 2.0
    end

    -- Calcul du poids total (avec boost redzone pour items rares)
    local totalWeight = 0
    local weights = {}
    for i, entry in ipairs(lootTable) do
        local w = entry.chance
        -- En redzone : boost les items avec chance < 10 (rares/légendaires)
        if inRedzone and w < 10 then
            w = w * multiplier
        end
        weights[i] = w
        totalWeight = totalWeight + w
    end

    -- Tirage pondéré
    local roll = math.random() * totalWeight
    local cumul = 0
    for i, entry in ipairs(lootTable) do
        cumul = cumul + weights[i]
        if roll <= cumul then
            return { entry }
        end
    end

    return { lootTable[#lootTable] }
end

-- ── Anti-exploit : tracking des kills pour éviter le spam ─────────────────
local recentKills   = {}  -- [src] = { lastKillTime, killCount }
local usedZombieIds = {}  -- [netId] = true (empêche double-claim)

local KILL_COOLDOWN    = 500   -- ms minimum entre 2 kills
local MAX_KILLS_WINDOW = 30    -- max kills par fenêtre de 30s
local KILL_WINDOW_MS   = 30000

-- Nettoyage périodique des netIds utilisés (toutes les 5 min)
CreateThread(function()
    while true do
        Wait(300000)
        usedZombieIds = {}
    end
end)

-- ── Appelé quand un joueur tue un zombie ───────────────────────────────────
RegisterNetEvent('pvp_zombies:onKill')
AddEventHandler('pvp_zombies:onKill', function(zombieNetId)
    if not ESX then return end  -- ESX pas encore chargé
    local src      = source
    local xPlayer  = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    -- ── VALIDATION 1 : netId obligatoire ──
    if not zombieNetId or type(zombieNetId) ~= 'number' then return end

    -- ── VALIDATION 2 : netId pas déjà utilisé (anti double-claim) ──
    if usedZombieIds[zombieNetId] then return end
    usedZombieIds[zombieNetId] = true

    -- ── VALIDATION 3 : anti-spam (cooldown + rate limit) ──
    local now = GetGameTimer()
    local record = recentKills[src]
    if not record then
        record = { lastKill = 0, count = 0, windowStart = now }
        recentKills[src] = record
    end
    -- Cooldown entre 2 kills
    if (now - record.lastKill) < KILL_COOLDOWN then return end
    -- Reset fenêtre si expirée
    if (now - record.windowStart) > KILL_WINDOW_MS then
        record.count = 0
        record.windowStart = now
    end
    record.count = record.count + 1
    record.lastKill = now
    -- Trop de kills dans la fenêtre → suspect
    if record.count > MAX_KILLS_WINDOW then
        print(('[ZOMBIE-ANTICHEAT] %s (id:%d) a dépassé %d kills en %ds — bloqué'):format(
            xPlayer.identifier, src, MAX_KILLS_WINDOW, KILL_WINDOW_MS / 1000))
        return
    end

    -- ── VALIDATION 4 : vérifier l'entité réseau ──
    local zombieEntity = NetworkGetEntityFromNetworkId(zombieNetId)
    if zombieEntity and zombieEntity ~= 0 and DoesEntityExist(zombieEntity) then
        -- Vérifier la distance (max 200m)
        local playerPed = GetPlayerPed(src)
        if playerPed and playerPed ~= 0 then
            local pCoords = GetEntityCoords(playerPed)
            local zCoords = GetEntityCoords(zombieEntity)
            local dist = #(pCoords - zCoords)
            if dist > 200.0 then return end
        end
    end
    -- Note : si l'entité n'existe plus côté serveur (OneSync scope),
    -- on accepte quand même car les validations 1-3 protègent contre le spam

    local typeData = Config.ZombieType

    -- Vérifier si le joueur est en redzone
    local inRedzone = false
    local ok, result = pcall(function()
        return exports['pvp_redzones']:isPlayerInRedzone(src)
    end)
    if ok then inRedzone = result end

    -- Récompense en dollars (boost en redzone)
    local reward = math.random(typeData.reward.min, typeData.reward.max)
    if inRedzone then
        local cashMult = 2.5
        local ok2, cm = pcall(function()
            return exports['pvp_redzones']:getCashMultiplier()
        end)
        if ok2 and cm then cashMult = cm end
        reward = math.floor(reward * cashMult)
    end
    xPlayer.addAccountMoney('bank', reward)

    -- Loot items (boost en redzone)
    local lootList  = rollLoot(inRedzone)
    local lootNames = {}

    for _, item in ipairs(lootList) do
        -- Vérifie le poids disponible dans le sac
        local ok_bag, canAdd = pcall(function()
            return exports['pvp_inventory']:canAddToBag(src, item.item, item.count)
        end)
        if not ok_bag or not canAdd then
            TriggerClientEvent('pvp_zombies:receiveLoot', src, typeData.label, reward, {})
            TriggerClientEvent('pvp_market:notify', src, 'Sac trop lourd — +' .. reward .. '$ mais pas de loot !', false)
            return
        end
        -- Vérifie que l'item existe dans ESX
        local ok3 = pcall(function()
            xPlayer.addInventoryItem(item.item, item.count)
        end)
        if ok3 then
            local itemObj = ESX.GetItem and ESX.GetItem(item.item) or nil
            local label   = itemObj and itemObj.label or item.item
            table.insert(lootNames, label)
        end
    end

    -- Envoie le résultat au client pour affichage
    local labelPrefix = inRedzone and ('[RZ] ' .. typeData.label) or typeData.label
    TriggerClientEvent('pvp_zombies:receiveLoot', src, labelPrefix, reward, lootNames)
    TriggerEvent('pvp_inventory:addZombieKillBySource', src)

    -- Stats redzone
    if inRedzone then
        TriggerEvent('pvp_redzones:zombieKill', src)
    end

    -- Stats (optionnel : log serveur)
    local rzTag = inRedzone and ' [REDZONE]' or ''
    print(('[ZOMBIE]%s %s a tué un Zombie | +%d$ | loot: %s'):format(
        rzTag, xPlayer.identifier, reward, table.concat(lootNames, ', ')
    ))
end)

-- ── Nettoyage anti-spam à la déconnexion ────────────────────────────────────
AddEventHandler('playerDropped', function()
    recentKills[source] = nil
end)

-- ── Shot Attracteur : route l'event vers le client source ─────────────────
-- Note : forceSpawn est aussi utilisé par pvp_admin, vérification admin requise
RegisterNetEvent('pvp_zombies:forceSpawn')
AddEventHandler('pvp_zombies:forceSpawn', function(count)
    if not ESX then return end
    local src = source
    if not src or src <= 0 then return end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    -- Autoriser les admins OU les joueurs qui utilisent un shot_attract (count limité)
    local group = xPlayer.getGroup()
    local maxCount = 3  -- limite joueur normal (shot_attract)
    if group == 'admin' or group == 'superadmin' then
        maxCount = 10  -- les admins peuvent spawn jusqu'à 10
    end
    count = math.min(math.max(1, math.floor(tonumber(count) or 1)), maxCount)
    TriggerClientEvent('pvp_zombies:forceSpawn', src, count)
end)
