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
local pendingTokens = {}  -- [src] = { [token] = issuedAtMs }  (GetGameTimer, monotone)
local tokenBuckets  = {}  -- [src] = { tokens = n, lastRefillMs = t }
local lastWarnMs    = {}  -- [src] = t  — anti-spam des logs d'avertissement

-- Raccourci vers Config.AntiCheat avec repli, pour que la resource démarre même
-- si un config.lua plus ancien traîne encore sur le serveur.
local AC = Config.AntiCheat or {}
local TOKEN_BUCKET_CAPACITY = AC.TokenBucketCapacity or 20
local TOKEN_REFILL_MS       = AC.TokenRefillMs       or 8000
local TOKEN_HARD_CAP        = AC.TokenHardCap        or 400
local TOKEN_TTL_MS          = AC.TokenTTLMs          or 1800000
local TOKEN_MIN_AGE_MS      = AC.TokenMinAgeMs       or 1500
local EXEMPT_GROUPS         = AC.ExemptGroups        or { admin = true, superadmin = true }
local LOG_THROTTLE_MS       = AC.LogThrottleMs       or 10000

-- Avertissement anti-triche, throttlé : un client modifié qui boucle ne doit pas
-- pouvoir noyer la console ni faire gonfler le fichier de log.
local function warnCheat(src, identifier, fmt, ...)
    local now  = GetGameTimer()
    local last = lastWarnMs[src]
    if last and (now - last) < LOG_THROTTLE_MS then return end
    lastWarnMs[src] = now
    print(('[ZOMBIE-ANTICHEAT] %s (id:%s) — ' .. fmt):format(identifier or '?', tostring(src), ...))
end

-- Compte les jetons encore vivants d'un joueur, en purgeant les expirés au
-- passage. Sert au garde-fou mémoire.
local function countLiveTokens(src, nowMs)
    local tokens = pendingTokens[src]
    if not tokens then return 0 end
    local n = 0
    for token, issuedAt in pairs(tokens) do
        if (nowMs - issuedAt) > TOKEN_TTL_MS then
            tokens[token] = nil
        else
            n = n + 1
        end
    end
    return n
end

-- Seau à jetons : rend true si le joueur a le droit d'en recevoir un de plus.
-- Capacité = rafale tolérée, remplissage = 1 jeton par TOKEN_REFILL_MS. En
-- régime établi le débit ne peut donc pas dépasser la boucle de spawn client.
local function consumeBucket(src, nowMs)
    local b = tokenBuckets[src]
    if not b then
        b = { tokens = TOKEN_BUCKET_CAPACITY, lastRefillMs = nowMs }
        tokenBuckets[src] = b
    end

    local elapsed = nowMs - b.lastRefillMs
    if elapsed >= TOKEN_REFILL_MS then
        local refill = math.floor(elapsed / TOKEN_REFILL_MS)
        b.tokens = math.min(TOKEN_BUCKET_CAPACITY, b.tokens + refill)
        b.lastRefillMs = b.lastRefillMs + refill * TOKEN_REFILL_MS
    end

    if b.tokens < 1 then return false end
    b.tokens = b.tokens - 1
    return true
end

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

            -- Le joueur doit exister : sans ça, n'importe quel appel forgé
            -- alimentait le stock de jetons.
            local xPlayer = ESX.GetPlayerFromId(src)
            if not xPlayer then return cb(nil) end

            local nowMs = GetGameTimer()

            -- Les admins testent avec /spawnzombies (jusqu'à 30 d'un coup) :
            -- les soumettre au seau rendrait la moitié des cadavres non
            -- fouillables et fausserait le test.
            local exempt = EXEMPT_GROUPS[xPlayer.getGroup()] == true

            -- Garde-fou mémoire : un jeton fuit à chaque zombie qui despawn sans
            -- être fouillé. Purge les expirés et refuse au-delà du plafond.
            local live = countLiveTokens(src, nowMs)
            if live >= TOKEN_HARD_CAP then
                warnCheat(src, xPlayer.identifier,
                    'plafond de %d jetons vivants atteint — émission refusée', TOKEN_HARD_CAP)
                return cb(nil)
            end

            -- Seau à jetons : c'est ici que se joue la sécurité. Un client
            -- légitime demande 1 jeton par Config.SpawnInterval ; un client qui
            -- boucle vide le seau en quelques appels et n'obtient plus rien.
            if not exempt and not consumeBucket(src, nowMs) then
                warnCheat(src, xPlayer.identifier,
                    'débit de spawn anormal (> %d jetons / %ds) — émission refusée',
                    TOKEN_BUCKET_CAPACITY, math.floor(TOKEN_REFILL_MS / 1000))
                return cb(nil)
            end

            local token = ('%d_%d_%d'):format(src, nowMs, math.random(100000, 999999))
            pendingTokens[src] = pendingTokens[src] or {}
            pendingTokens[src][token] = nowMs

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

-- Purge des jetons jamais réclamés (zombie despawné, joueur parti au loin...).
-- Horloge en ms via GetGameTimer, la même que l'émission : mélanger os.time()
-- (secondes, horloge murale) et GetGameTimer (ms, monotone) rendait le contrôle
-- d'âge minimum incalculable.
CreateThread(function()
    while true do
        Wait(60000)  -- toutes les minutes
        local nowMs = GetGameTimer()
        for src, tokens in pairs(pendingTokens) do
            for token, issuedAt in pairs(tokens) do
                if (nowMs - issuedAt) > TOKEN_TTL_MS then
                    tokens[token] = nil
                end
            end
        end
    end
end)

-- ── Anti-exploit : tracking des fouilles pour éviter le spam ──────────────
local recentLoots  = {}  -- [src] = { lastLoot, count, windowStart }

local LOOT_COOLDOWN    = AC.LootCooldownMs    or 500    -- ms minimum entre 2 fouilles
local MAX_LOOTS_WINDOW = AC.MaxLootsPerWindow or 15     -- max fouilles par fenêtre
local LOOT_WINDOW_MS   = AC.LootWindowMs      or 30000

-- 30 fouilles / 30 s auparavant, soit 60/min : huit fois le débit d'un joueur
-- légitime (la boucle de spawn client plafonne à 7,5 zombies/min). Ramené à 15
-- par fenêtre — assez pour ramasser les cadavres d'un gros combat d'affilée,
-- sans laisser de marge à un bot. Le vrai plafond reste le seau à jetons.

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
    if not tokens then return end
    local issuedAt = tokens[token]
    if not issuedAt then return end
    tokens[token] = nil  -- usage unique : consommé immédiatement (anti double-claim)

    local nowMs = GetGameTimer()

    -- Jeton périmé : le thread de purge ne passe qu'une fois par minute, donc
    -- l'expiration doit aussi être vérifiée ici, au moment de la consommation.
    if (nowMs - issuedAt) > TOKEN_TTL_MS then return end

    -- Âge minimum : un zombie ne peut pas naître, mourir et être fouillé dans le
    -- même souffle. Coupe la boucle getSpawnToken → claimLoot la plus serrée,
    -- celle qui ne laisse même pas le temps au seau de se vider.
    if (nowMs - issuedAt) < TOKEN_MIN_AGE_MS then
        warnCheat(src, xPlayer.identifier,
            'jeton réclamé %d ms après son émission (minimum %d ms) — fouille refusée',
            nowMs - issuedAt, TOKEN_MIN_AGE_MS)
        return
    end

    -- ── VALIDATION 2 : anti-spam (cooldown + rate limit) ──
    local record = recentLoots[src]
    if not record then
        record = { lastLoot = 0, count = 0, windowStart = nowMs }
        recentLoots[src] = record
    end
    if (nowMs - record.lastLoot) < LOOT_COOLDOWN then return end
    if (nowMs - record.windowStart) > LOOT_WINDOW_MS then
        record.count = 0
        record.windowStart = nowMs
    end
    record.count = record.count + 1
    record.lastLoot = nowMs
    if record.count > MAX_LOOTS_WINDOW then
        warnCheat(src, xPlayer.identifier,
            'plus de %d fouilles en %ds — fouille refusée',
            MAX_LOOTS_WINDOW, math.floor(LOOT_WINDOW_MS / 1000))
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
    local src = source
    recentLoots[src]   = nil
    pendingTokens[src] = nil
    tokenBuckets[src]  = nil
    lastWarnMs[src]    = nil
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
