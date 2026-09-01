-- =============================================
--   PVP CHARACTER - Serveur
--   Création de personnage (pseudo + genre + apparence détaillée)
--   Remplace esx_identity. Bloque pvp_spawn jusqu'à ready.
-- =============================================

local ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- ── Config ───────────────────────────────────────────────────────────────
-- Le rename n'est plus ni payant ni saisonnier : il est réservé aux abonnés
-- (Gold 1×/semaine, Diamond illimité) — voir la commande /rename plus bas.

-- Mots interdits dans les pseudos (vérifié en substring insensible à la casse)
local BannedWords = {
    'admin', 'vanta', 'staff', 'moderator', 'modo', 'owner', 'developer', 'developper',
    'nigger', 'nigga', 'fuck', 'bitch', 'cunt', 'pute', 'putain', 'salope', 'connard',
    'nazi', 'hitler', 'retard', 'fag', 'pedo', 'pedophile', 'rape', 'kill',
}

-- ── Migrations DB ────────────────────────────────────────────────────────
-- Helper portable : ajoute une colonne seulement si elle n'existe pas.
-- `ADD COLUMN IF NOT EXISTS` est MariaDB/MySQL 8.0.29+ uniquement.
local function addColumnIfMissing(tbl, col, definition)
    MySQL.Async.fetchScalar(
        [[SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
          WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = @t AND COLUMN_NAME = @c]],
        { ['@t'] = tbl, ['@c'] = col },
        function(count)
            if (tonumber(count) or 0) == 0 then
                MySQL.Async.execute('ALTER TABLE `' .. tbl .. '` ADD COLUMN `' .. col .. '` ' .. definition)
            end
        end
    )
end

Citizen.CreateThread(function()
    Citizen.Wait(1500)
    -- pvp_player_stats doit déjà exister (créée par pvp_inventory). On ajoute juste les colonnes manquantes.
    addColumnIfMissing('pvp_player_stats', 'skin_tone',          'TINYINT DEFAULT 0')
    addColumnIfMissing('pvp_player_stats', 'hair_style',         'TINYINT DEFAULT 0')
    -- rename_free_season : legacy (ancien rename gratuit 1×/saison), plus lu ni écrit.
    -- Migration conservée pour ne pas casser les bases existantes.
    addColumnIfMissing('pvp_player_stats', 'rename_free_season', 'INT DEFAULT 0')
    addColumnIfMissing('pvp_player_stats', 'rename_last_week',   'INT DEFAULT 0')
    addColumnIfMissing('pvp_player_stats', 'appearance_json',    'TEXT NULL')
end)

-- ── Presets legacy (pour convertir les anciens skin_tone/hair_style 0-3) ──
-- Copie exacte des anciennes tables client (avant refonte), utilisée UNE SEULE
-- fois par joueur pour générer un appearance_json de départ, jamais après.
local LegacySkinPresets = {
    { 0, 0, 0,  0,  0, 0, 0.5, 0.0, 0.0 },
    { 0, 0, 0,  4,  4, 0, 0.5, 0.4, 0.0 },
    { 0, 0, 0, 14, 14, 0, 0.5, 0.7, 0.0 },
    { 0, 0, 0, 21, 21, 0, 0.5, 1.0, 0.0 },
}
local LegacyHairMale   = { { 0, 0 }, { 2, 0 }, { 4, 0 }, { 10, 1 } }
local LegacyHairFemale = { { 0, 0 }, { 3, 0 }, { 5, 0 }, { 12, 1 } }

-- ── Apparence par défaut (nouveau joueur / reset) ───────────────────────
local function defaultAppearance(gender)
    local hairs = (gender == 'female') and LegacyHairFemale or LegacyHairMale
    local hair  = hairs[1]
    return {
        v      = 3,
        head   = { 0, 0, 0, 0, 0, 0, 0.5, 0.0, 0.0 },
        hair   = { hair[1], 0, hair[2], 0 },
        ovl    = {},
        ovlc   = {},
        eye    = 0,
        props  = {},
    }
end

-- ── Whitelists de validation ─────────────────────────────────────────────
-- Aucun composant vêtement n'est validé ici : le client n'en envoie plus.
-- Le corps entier est imposé côté serveur ET client par shared/body.lua, il
-- est donc structurellement impossible pour un client de demander une
-- apparence vestimentaire quelconque. Seuls restent les accessoires portés.
local ALLOWED_PROPS      = { [0]=true, [1]=true, [2]=true, [6]=true, [7]=true }
local ALLOWED_OVERLAYS   = { [0]=true, [1]=true, [2]=true, [3]=true, [4]=true, [5]=true, [6]=true, [7]=true, [8]=true, [9]=true, [10]=true, [11]=true, [12]=true }

local function clamp(n, lo, hi)
    n = tonumber(n)
    if not n then return lo end
    if n < lo then return lo end
    if n > hi then return hi end
    return math.floor(n)
end

local function clampFloat(n, lo, hi)
    n = tonumber(n)
    if not n then return lo end
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

-- Reconstruit un objet appearance propre depuis zéro à partir de l'input
-- client — ne fait JAMAIS confiance au payload, ne le repasse jamais tel quel.
local function sanitizeAppearance(input, gender)
    if type(input) ~= 'table' then return defaultAppearance(gender) end

    local out = { v = 3, head = {}, hair = {}, ovl = {}, ovlc = {}, eye = 0, props = {} }

    -- head : 9 valeurs (6 index morpho/peau clampés 0-45, 3 mix clampés 0-1)
    local h = type(input.head) == 'table' and input.head or {}
    for i = 1, 6 do out.head[i] = clamp(h[i], 0, 45) end
    for i = 7, 9 do out.head[i] = clampFloat(h[i], 0.0, 1.0) end

    -- hair : drawable, texture, color, highlight
    local hr = type(input.hair) == 'table' and input.hair or {}
    out.hair = {
        clamp(hr[1], 0, 255),
        clamp(hr[2], 0, 63),
        clamp(hr[3], 0, 63),
        clamp(hr[4], 0, 63),
    }

    -- eye color
    out.eye = clamp(input.eye, 0, 31)

    -- overlays : { overlayId, index, opacity*100 }, max 13
    if type(input.ovl) == 'table' then
        local n = 0
        for _, entry in ipairs(input.ovl) do
            if n >= 13 then break end
            if type(entry) == 'table' then
                local oid = tonumber(entry[1])
                if oid and ALLOWED_OVERLAYS[math.floor(oid)] then
                    out.ovl[#out.ovl + 1] = {
                        math.floor(oid),
                        clamp(entry[2], 0, 255),
                        clamp(entry[3], 0, 100),
                    }
                    n = n + 1
                end
            end
        end
    end

    -- overlay colors : { overlayId, colorType, colorId, secondColorId }, max 13
    if type(input.ovlc) == 'table' then
        local n = 0
        for _, entry in ipairs(input.ovlc) do
            if n >= 13 then break end
            if type(entry) == 'table' then
                local oid = tonumber(entry[1])
                if oid and ALLOWED_OVERLAYS[math.floor(oid)] then
                    out.ovlc[#out.ovlc + 1] = {
                        math.floor(oid),
                        clamp(entry[2], 0, 2),
                        clamp(entry[3], 0, 63),
                        clamp(entry[4], 0, 63),
                    }
                    n = n + 1
                end
            end
        end
    end

    -- Les anciennes apparences (v1/v2) portaient des `comps` et un `top` :
    -- ils sont simplement ignorés, il n'y a rien à migrer puisque plus aucun
    -- vêtement n'existe.

    -- props : { propId, drawable, texture }, whitelist stricte, max 5, dernier gagne
    if type(input.props) == 'table' then
        local byId = {}
        for _, entry in ipairs(input.props) do
            if type(entry) == 'table' then
                local pid = tonumber(entry[1])
                if pid ~= nil and ALLOWED_PROPS[math.floor(pid)] then
                    byId[math.floor(pid)] = {
                        math.floor(pid),
                        clamp(entry[2], -1, 255),
                        clamp(entry[3], 0, 63),
                    }
                end
            end
        end
        for _, v in pairs(byId) do out.props[#out.props + 1] = v end
    end

    -- Garde-fou de taille (défense en profondeur, ~380o attendu)
    local ok, encoded = pcall(json.encode, out)
    if not ok or #encoded > 4000 then
        return defaultAppearance(gender)
    end

    return out
end

-- Reconstruit un appearance_json legacy depuis les anciens index skin_tone/hair_style (0-3)
local function legacyToAppearance(skinIdx, hairIdx, gender)
    skinIdx = clamp(skinIdx, 0, 3) + 1
    hairIdx = clamp(hairIdx, 0, 3) + 1
    local skin  = LegacySkinPresets[skinIdx] or LegacySkinPresets[1]
    local hairs = (gender == 'female') and LegacyHairFemale or LegacyHairMale
    local hair  = hairs[hairIdx] or hairs[1]
    return {
        v     = 3,
        head  = { skin[1], skin[2], skin[3], skin[4], skin[5], skin[6], skin[7], skin[8], skin[9] },
        hair  = { hair[1], 0, hair[2], 0 },
        ovl   = {},
        ovlc  = {},
        eye   = 0,
        props = {},
    }
end

local function isFreemodeModel(model)
    return model == '' or model == nil or model == 'mp_m_freemode_01' or model == 'mp_f_freemode_01'
end

-- ── Helpers ──────────────────────────────────────────────────────────────
local function sanitizePseudo(pseudo)
    if type(pseudo) ~= 'string' then return nil end
    pseudo = pseudo:gsub('^%s+', ''):gsub('%s+$', '')
    if #pseudo < 2 or #pseudo > 20 then return nil end
    if not pseudo:match('^[%w%s%-_ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝàáâãäåæçèéêëìíîïðñòóôõöøùúûüýÿ]+$') then
        return nil
    end
    return pseudo
end

local function isBanned(pseudo)
    local lower = pseudo:lower()
    for _, word in ipairs(BannedWords) do
        if lower:find(word, 1, true) then return true end
    end
    return false
end

local function notify(src, msg)
    TriggerClientEvent('esx:showNotification', src, msg)
end

-- Dispatch : signale à pvp_spawn (et autres) que le personnage est prêt.
-- SÉCURITÉ/FIABILITÉ : ne se déclenche QUE quand le client confirme avoir fini
-- d'appliquer le modèle/apparence (event pvp_character:appearanceApplied),
-- jamais immédiatement après l'envoi de applyModel/creationDone. Sans cette
-- attente, pvp_spawn pouvait téléporter le joueur PENDANT que ce script
-- déplaçait/recréait encore le ped (SetPlayerModel) → spawn sous la map.
local function markCharacterReady(src)
    TriggerEvent('pvp_character:characterReady', src)
end

RegisterNetEvent('pvp_character:appearanceApplied')
AddEventHandler('pvp_character:appearanceApplied', function()
    markCharacterReady(source)
end)

-- ── Connexion : détecte nouveau vs existant ──────────────────────────────
AddEventHandler('esx:playerLoaded', function(playerId)
    local src = type(playerId) == 'table' and playerId.source or playerId
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    MySQL.Async.fetchAll(
        [[
            SELECT u.firstname, u.sex,
                   COALESCE(s.skin_tone, 0)        AS skin_tone,
                   COALESCE(s.hair_style, 0)        AS hair_style,
                   COALESCE(s.ped_model, '')        AS ped_model,
                   COALESCE(s.appearance_json, '')  AS appearance_json
            FROM users u
            LEFT JOIN pvp_player_stats s ON s.identifier = u.identifier
            WHERE u.identifier = @id
        ]],
        { ['@id'] = xPlayer.identifier },
        function(result)
            local row = result and result[1]
            local firstname = row and row.firstname

            if row and firstname and firstname ~= '' then
                -- Joueur existant : reconstruit l'apparence, migre si besoin, signale ready
                xPlayer.set('firstName', firstname)

                local gender = (row.sex == 'f') and 'female' or 'male'
                local model  = row.ped_model or ''
                local needsModelFix = (model == '')
                if needsModelFix then
                    model = (gender == 'female') and 'mp_f_freemode_01' or 'mp_m_freemode_01'
                end

                -- Un ped spécial n'a pas d'apparence détaillée (apparence fixe) —
                -- ne pas fabriquer/écrire un appearance_json legacy inutile pour lui.
                local appearance = nil
                local needsAppearanceFix = false
                if isFreemodeModel(model) then
                    needsAppearanceFix = (row.appearance_json == '' or row.appearance_json == nil)
                    if needsAppearanceFix then
                        appearance = legacyToAppearance(row.skin_tone, row.hair_style, gender)
                    else
                        local ok, decoded = pcall(json.decode, row.appearance_json)
                        appearance = (ok and type(decoded) == 'table') and sanitizeAppearance(decoded, gender) or defaultAppearance(gender)
                    end
                end

                if needsModelFix or needsAppearanceFix then
                    MySQL.Async.execute(
                        [[
                            INSERT INTO pvp_player_stats (identifier, ped_model, appearance_json)
                            VALUES (@id, @model, @app)
                            ON DUPLICATE KEY UPDATE ped_model = @model, appearance_json = @app
                        ]],
                        { ['@id'] = xPlayer.identifier, ['@model'] = model, ['@app'] = json.encode(appearance) }
                    )
                end

                TriggerClientEvent('pvp_character:applyModel', src, {
                    model      = model,
                    appearance = appearance,
                    sex        = row.sex or 'm',
                })
                -- markCharacterReady() se déclenche via pvp_character:appearanceApplied
                -- (voir plus haut), une fois le client confirmé avoir fini le swap de ped.
            else
                -- Nouveau joueur : affiche le NUI
                TriggerClientEvent('pvp_character:isNewPlayer', src)
            end
        end
    )
end)

-- ── Sauvegarde de la création ────────────────────────────────────────────
-- SÉCURITÉ : lock anti-spam + vérif idempotence (si déjà créé, reject) + unicité pseudo
local saveCharLocks = {}

RegisterNetEvent('pvp_character:saveCharacter')
AddEventHandler('pvp_character:saveCharacter', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    if saveCharLocks[xPlayer.identifier] then return end
    saveCharLocks[xPlayer.identifier] = true

    local pseudo = sanitizePseudo(data and data.pseudo)
    if not pseudo then
        saveCharLocks[xPlayer.identifier] = nil
        TriggerClientEvent('pvp_character:creationError', src, 'Pseudo invalide (2-20 caractères)')
        return
    end
    if isBanned(pseudo) then
        saveCharLocks[xPlayer.identifier] = nil
        TriggerClientEvent('pvp_character:creationError', src, 'Ce pseudo est interdit')
        return
    end

    -- SÉCURITÉ : vérif idempotence + unicité pseudo
    local exOk, existing = pcall(function()
        return MySQL.Sync.fetchAll(
            'SELECT firstname FROM users WHERE identifier = @id',
            { ['@id'] = xPlayer.identifier })
    end)
    if exOk and existing and existing[1] and existing[1].firstname and existing[1].firstname ~= '' then
        saveCharLocks[xPlayer.identifier] = nil
        TriggerClientEvent('pvp_character:creationError', src, 'Personnage déjà créé')
        return
    end
    local dupOk, dup = pcall(function()
        return MySQL.Sync.fetchAll(
            'SELECT identifier FROM users WHERE firstname = @n AND identifier != @id LIMIT 1',
            { ['@n'] = pseudo, ['@id'] = xPlayer.identifier })
    end)
    if dupOk and dup and dup[1] then
        saveCharLocks[xPlayer.identifier] = nil
        TriggerClientEvent('pvp_character:creationError', src, 'Ce pseudo est déjà pris')
        return
    end

    local gender   = (data.gender == 'female') and 'female' or 'male'
    local sexValue = (gender == 'female') and 'f' or 'm'
    local charType = (data.type == 'special') and 'special' or 'freemode'

    local model
    local appearance

    if charType == 'special' then
        local requestedModel = type(data.model) == 'string' and data.model or ''
        local catalogOk, eligible = pcall(function()
            return exports['pvp_inventory']:IsPedCreationEligible(requestedModel)
        end)
        if not catalogOk or not eligible then
            saveCharLocks[xPlayer.identifier] = nil
            TriggerClientEvent('pvp_character:creationError', src, 'Ped invalide')
            return
        end
        model      = requestedModel
        appearance = nil -- pas d'apparence détaillée pour un ped spécial (apparence fixe)
    else
        model      = (gender == 'female') and 'mp_f_freemode_01' or 'mp_m_freemode_01'
        appearance = sanitizeAppearance(data.appearance, gender)
    end

    MySQL.Async.execute(
        'UPDATE users SET firstname = @firstname, lastname = @lastname, sex = @sex WHERE identifier = @id',
        {
            ['@firstname'] = pseudo,
            ['@lastname']  = '',
            ['@sex']       = sexValue,
            ['@id']        = xPlayer.identifier,
        },
        function(rows)
            if not rows or rows == 0 then
                saveCharLocks[xPlayer.identifier] = nil
                TriggerClientEvent('pvp_character:creationError', src, 'Erreur base de données, réessaie')
                return
            end

            -- Upsert les customisations sur pvp_player_stats
            MySQL.Async.execute(
                [[
                    INSERT INTO pvp_player_stats (identifier, ped_model, appearance_json)
                    VALUES (@id, @model, @app)
                    ON DUPLICATE KEY UPDATE ped_model = @model, appearance_json = @app
                ]],
                {
                    ['@id']    = xPlayer.identifier,
                    ['@model'] = model,
                    ['@app']   = appearance and json.encode(appearance) or nil,
                },
                function()
                    saveCharLocks[xPlayer.identifier] = nil
                    xPlayer.set('firstName', pseudo)
                    TriggerClientEvent('pvp_character:creationDone', src, {
                        model      = model,
                        appearance = appearance,
                        sex        = gender,
                    })
                    -- markCharacterReady() se déclenche via pvp_character:appearanceApplied
                    -- (voir plus haut), une fois le client confirmé avoir fini le swap de ped.
                end
            )
        end
    )
end)

-- ── Commande /rename ─────────────────────────────────────────────────────
-- Diamond : illimité
-- Gold    : 1× par semaine
-- Autres  : jamais (réservé aux abonnés)
local RENAME_WEEK_SECONDS = 7 * 24 * 3600

-- Formate une durée en secondes → "2j 5h" / "5h 12min" / "12min"
local function formatDelay(seconds)
    seconds = math.max(0, math.floor(seconds))
    local days  = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local mins  = math.floor((seconds % 3600) / 60)
    if days  > 0 then return ('%dj %dh'):format(days, hours) end
    if hours > 0 then return ('%dh %dmin'):format(hours, mins) end
    return ('%dmin'):format(mins)
end

local renameLocks = {}
RegisterCommand('rename', function(source, args, raw)
    if source == 0 then return end
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    if renameLocks[xPlayer.identifier] then
        notify(source, '~r~Traitement en cours...')
        return
    end
    renameLocks[xPlayer.identifier] = true

    local newPseudo = table.concat(args, ' ')
    newPseudo = sanitizePseudo(newPseudo)
    if not newPseudo then
        renameLocks[xPlayer.identifier] = nil
        notify(source, '~r~Usage : /rename <pseudo valide 2-20 caractères>')
        return
    end
    if isBanned(newPseudo) then
        renameLocks[xPlayer.identifier] = nil
        notify(source, '~r~Ce pseudo est interdit')
        return
    end

    -- Récupère le tier d'abonnement depuis pvp_vcoins
    local tier = 'none'
    pcall(function()
        tier = exports['pvp_vcoins']:GetTier(xPlayer.identifier) or 'none'
    end)

    -- Sans abonnement : rename impossible, quel que soit l'argent du joueur
    if tier ~= 'gold' and tier ~= 'diamond' then
        renameLocks[xPlayer.identifier] = nil
        notify(source, '~r~Le changement de pseudo est réservé aux abonnés ~y~Gold~r~ (1×/semaine) et ~b~Diamond~r~ (illimité)')
        return
    end

    -- Unicité pseudo
    local dupOk, dup = pcall(function()
        return MySQL.Sync.fetchAll(
            'SELECT identifier FROM users WHERE firstname = @n AND identifier != @id LIMIT 1',
            { ['@n'] = newPseudo, ['@id'] = xPlayer.identifier })
    end)
    if dupOk and dup and dup[1] then
        renameLocks[xPlayer.identifier] = nil
        notify(source, '~r~Ce pseudo est déjà pris')
        return
    end

    -- Diamond = rename illimité
    if tier == 'diamond' then
        MySQL.Async.execute(
            'UPDATE users SET firstname = @n WHERE identifier = @id',
            { ['@n'] = newPseudo, ['@id'] = xPlayer.identifier },
            function()
                xPlayer.set('firstName', newPseudo)
                renameLocks[xPlayer.identifier] = nil
                notify(source, ('~g~Pseudo changé pour ~w~%s~g~ ~y~(Diamond — illimité)'):format(newPseudo))
            end
        )
        return
    end

    -- Gold = 1× par semaine (fenêtre = numéro de semaine Unix, comme avant)
    MySQL.Async.fetchAll(
        'SELECT rename_last_week FROM pvp_player_stats WHERE identifier = @id',
        { ['@id'] = xPlayer.identifier },
        function(result)
            local row      = result and result[1]
            local lastWeek = tonumber(row and row.rename_last_week) or 0
            local nowWeek  = math.floor(os.time() / RENAME_WEEK_SECONDS)

            if lastWeek == nowWeek then
                local remaining = ((nowWeek + 1) * RENAME_WEEK_SECONDS) - os.time()
                renameLocks[xPlayer.identifier] = nil
                notify(source, ('~r~Gold : 1 rename par semaine — prochain disponible dans ~w~%s'):format(formatDelay(remaining)))
                return
            end

            MySQL.Async.execute(
                'UPDATE users SET firstname = @n WHERE identifier = @id',
                { ['@n'] = newPseudo, ['@id'] = xPlayer.identifier },
                function()
                    -- Consomme le rename hebdomadaire
                    MySQL.Async.execute([[
                        INSERT INTO pvp_player_stats (identifier, rename_last_week)
                        VALUES (@id, @week)
                        ON DUPLICATE KEY UPDATE rename_last_week = @week
                    ]], {
                        ['@id']   = xPlayer.identifier,
                        ['@week'] = nowWeek,
                    }, function()
                        xPlayer.set('firstName', newPseudo)
                        renameLocks[xPlayer.identifier] = nil
                        notify(source, ('~g~Pseudo changé pour ~w~%s~g~ ~y~(Gold — 1×/semaine)'):format(newPseudo))
                    end)
                end
            )
        end
    )
end, false)

TriggerEvent('chat:addSuggestion', '/rename', 'Change ton pseudo (Gold : 1x/semaine — Diamond : illimité)', {
    { name = 'nouveau_pseudo', help = '2-20 caractères' }
})

-- Cleanup des locks si le joueur se déconnecte
AddEventHandler('playerDropped', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
        saveCharLocks[xPlayer.identifier] = nil
        renameLocks[xPlayer.identifier] = nil
    end
end)
