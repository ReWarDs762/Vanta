-- =============================================
--   PVP ZOMBIES - Serveur
--   Récompenses, loot, stats kills
-- =============================================

local ESX = nil

-- Jetons de spawn (anti-triche) — déclaré tôt car référencé par le callback
-- ESX enregistré juste en dessous. Les zombies sont des peds 100% locaux
-- (isNetwork = false), invisibles pour les autres joueurs : le serveur ne
-- peut plus vérifier une entité réseau au moment du kill. À la place,
-- chaque zombie spawné se voit attribuer un jeton unique par le serveur ;
-- seul ce jeton (à usage unique) permet de réclamer la récompense/le loot
-- à la fouille.
local pendingTokens = {}  -- [src] = { [token] = issuedAt }

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
        ESX.RegisterServerCallback('pvp_zombies:getSpawnToken', function(source, cb)
            local src = source
            if not src or src <= 0 then return cb(nil) end

            local token = ('%d_%d_%d'):format(src, os.time(), math.random(100000, 999999))
            pendingTokens[src] = pendingTokens[src] or {}
            pendingTokens[src][token] = os.time()

            cb(token)
        end)
    end
end)

-- ── Tirage du loot : 1 seul item par zombie (pondéré par chance) ──────────
-- Si inRedzone = true, tout ce qui n'est pas 'tres_commun' a son poids
-- multiplié (commun/rare/épic/légendaire boostés, très commun inchangé).
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

    -- Calcul du poids total (avec boost redzone sur commun/rare/épic/légendaire)
    local totalWeight = 0
    local weights = {}
    for i, entry in ipairs(lootTable) do
        local w = entry.chance
        if inRedzone and entry.category ~= 'tres_commun' then
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

local TOKEN_TTL_S = 1800  -- 30 min : purge des jetons jamais réclamés (zombie despawn, joueur parti, etc.)

CreateThread(function()
    while true do
        Wait(60000)  -- toutes les minutes
        local now = os.time()
        for src, tokens in pairs(pendingTokens) do
            for token, issuedAt in pairs(tokens) do
                if (now - issuedAt) > TOKEN_TTL_S then
                    tokens[token] = nil
                end
            end
        end
    end
end)

-- ── Anti-exploit : tracking des fouilles pour éviter le spam ──────────────
local recentLoots  = {}  -- [src] = { lastLoot, count, windowStart }

local LOOT_COOLDOWN    = 500   -- ms minimum entre 2 fouilles
local MAX_LOOTS_WINDOW = 30    -- max fouilles par fenêtre de 30s
local LOOT_WINDOW_MS   = 30000

-- ── Appelé quand un joueur fouille un cadavre de zombie (touche E) ─────────
RegisterNetEvent('pvp_zombies:claimLoot')
AddEventHandler('pvp_zombies:claimLoot', function(token)
    if not ESX then return end  -- ESX pas encore chargé
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    -- ── VALIDATION 1 : jeton obligatoire et valide pour ce joueur ──
    if not token or type(token) ~= 'string' then return end
    local tokens = pendingTokens[src]
    if not tokens or not tokens[token] then return end
    tokens[token] = nil  -- usage unique : consommé immédiatement (anti double-claim)

    -- ── VALIDATION 2 : anti-spam (cooldown + rate limit) ──
    local now = GetGameTimer()
    local record = recentLoots[src]
    if not record then
        record = { lastLoot = 0, count = 0, windowStart = now }
        recentLoots[src] = record
    end
    if (now - record.lastLoot) < LOOT_COOLDOWN then return end
    if (now - record.windowStart) > LOOT_WINDOW_MS then
        record.count = 0
        record.windowStart = now
    end
    record.count = record.count + 1
    record.lastLoot = now
    if record.count > MAX_LOOTS_WINDOW then
        print(('[ZOMBIE-ANTICHEAT] %s (id:%d) a dépassé %d fouilles en %ds — bloqué'):format(
            xPlayer.identifier, src, MAX_LOOTS_WINDOW, LOOT_WINDOW_MS / 1000))
        return
    end

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
            exports['vanta_ui']:notify(src, 'Sac trop lourd — +' .. reward .. '$ mais pas de loot !', 'warning')
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
    TriggerEvent('pvp_inventory:recordZombieKill', src)

    -- SÉCURITÉ : dispatch interne vers vanta_xp APRÈS validation complète.
    TriggerEvent('vanta_xp:internalZombieKill', src)

    -- Stats redzone
    if inRedzone then
        TriggerEvent('pvp_redzones:zombieKill', src)
    end

    -- Stats (optionnel : log serveur)
    local rzTag = inRedzone and ' [REDZONE]' or ''
    print(('[ZOMBIE]%s %s a fouillé un Zombie | +%d$ | loot: %s'):format(
        rzTag, xPlayer.identifier, reward, table.concat(lootNames, ', ')
    ))
end)

-- ── Nettoyage anti-spam à la déconnexion ────────────────────────────────────
AddEventHandler('playerDropped', function()
    recentLoots[source]   = nil
    pendingTokens[source] = nil
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
