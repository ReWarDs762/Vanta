-- =============================================
--   PVP CHARACTER - Serveur
--   Création de personnage (pseudo + genre + apparence détaillée)
--   Remplace esx_identity. Bloque pvp_spawn jusqu'à ready.
-- =============================================

local ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- ── Config ───────────────────────────────────────────────────────────────
local CURRENT_SEASON = 1
local RENAME_PRICE   = 5000

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
        v      = 2,
        head   = { 0, 0, 0, 0, 0, 0, 0.5, 0.0, 0.0 },
        hair   = { hair[1], 0, hair[2], 0 },
        ovl    = {},
        ovlc   = {},
        eye    = 0,
        comps  = {},
        props  = {},
        top    = { 0, 0 },
    }
end

-- ── Whitelists de validation ─────────────────────────────────────────────
-- Volontairement restreint (décision produit) : pas de sac(5), gilet(9) ni
-- decal(10) — seulement masque/jambes/chaussures/accessoire cou.
--
-- Le haut n'est PAS dans cette liste : les composants 11 (vêtement), 3
-- (torse/bras) et 8 (sous-vêtement) forment un triplet indissociable, validé
-- en amont dans shared/tops_data.lua. Le client n'envoie donc qu'un index de
-- tenue (`top`), jamais des drawables libres — il lui est structurellement
-- impossible de demander une combinaison incohérente ou hors catalogue.
local ALLOWED_COMPONENTS = { [1]=true, [4]=true, [6]=true, [7]=true }
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

    local out = { v = 2, head = {}, hair = {}, ovl = {}, ovlc = {}, eye = 0, comps = {}, props = {}, top = { 0, 0 } }

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

    -- top : { indexDeTenue, teinteDuHaut }. Borné sur la table de tenues du
    -- genre, donc jamais sur une combinaison non validée.
    local topIdx, topTex = 0, 0
    if type(input.top) == 'table' then
        topIdx = VantaTops.clampIndex(gender, input.top[1])
        topTex = clamp(input.top[2], 0, 63)
    elseif type(input.comps) == 'table' then
        -- Migration v1 : le haut n'était qu'un drawable brut du composant 11.
        -- On retrouve la tenue qui l'utilise, sinon la première du catalogue.
        for _, entry in ipairs(input.comps) do
            if type(entry) == 'table' and tonumber(entry[1]) == VantaTops.COMP_TOP then
                topIdx = VantaTops.findByTop(gender, entry[2])
                break
            end
        end
    end
    out.top = { topIdx, topTex }

    -- comps : { componentId, drawable, texture }, whitelist stricte, max 10, dernier gagne
    if type(input.comps) == 'table' then
        local byId = {}
        for _, entry in ipairs(input.comps) do
            if type(entry) == 'table' then
                local cid = tonumber(entry[1])
                if cid and ALLOWED_COMPONENTS[math.floor(cid)] then
                    byId[math.floor(cid)] = {
                        math.floor(cid),
                        clamp(entry[2], 0, 511),
                        clamp(entry[3], 0, 63),
                    }
                end
            end
        end
        for _, v in pairs(byId) do out.comps[#out.comps + 1] = v end
    end

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
        v     = 2,
        head  = { skin[1], skin[2], skin[3], skin[4], skin[5], skin[6], skin[7], skin[8], skin[9] },
        hair  = { hair[1], 0, hair[2], 0 },
        ovl   = {},
        ovlc  = {},
        eye   = 0,
        comps = {},
        props = {},
        top   = { 0, 0 },
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
-- Gold    : 1× gratuit/semaine (au lieu de 1×/saison), sinon 5000$
-- Diamond : illimité gratuit
-- Autres  : 1× gratuit/saison, sinon 5000$
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

    -- Récupère le tier d'abonnement depuis pvp_vcoins
    local tier = 'none'
    pcall(function()
        tier = exports['pvp_vcoins']:GetTier(xPlayer.identifier) or 'none'
    end)

    -- Diamond = rename illimité gratuit
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

    MySQL.Async.fetchAll(
        'SELECT rename_free_season, rename_last_week FROM pvp_player_stats WHERE identifier = @id',
        { ['@id'] = xPlayer.identifier },
        function(result)
            local row        = result and result[1]
            local lastSeason = tonumber(row and row.rename_free_season) or 0
            local lastWeek   = tonumber(row and row.rename_last_week) or 0
            local nowWeek    = math.floor(os.time() / (7 * 24 * 3600))  -- numéro de semaine Unix

            local isFree = false
            local freeReason = ''

            if tier == 'gold' then
                -- Gold : 1× gratuit par semaine
                if lastWeek ~= nowWeek then
                    isFree = true
                    freeReason = 'Gold — 1×/semaine'
                end
            else
                -- Aucun abonnement : 1× gratuit par saison
                if lastSeason ~= CURRENT_SEASON then
                    isFree = true
                    freeReason = ('saison %d'):format(CURRENT_SEASON)
                end
            end

            local bank = xPlayer.getAccount('bank').money
            if not isFree and bank < RENAME_PRICE then
                local hint = tier == 'gold'
                    and '(Gold : 1×/sem gratuit déjà utilisé)'
                    or  ('(rename gratuit de la saison %d déjà utilisé)'):format(CURRENT_SEASON)
                renameLocks[xPlayer.identifier] = nil
                notify(source, ('~r~Il te faut %d$ %s'):format(RENAME_PRICE, hint))
                return
            end

            if not isFree then
                xPlayer.removeAccountMoney('bank', RENAME_PRICE)
            end

            MySQL.Async.execute(
                'UPDATE users SET firstname = @n WHERE identifier = @id',
                { ['@n'] = newPseudo, ['@id'] = xPlayer.identifier },
                function()
                    -- Met à jour les compteurs de free rename
                    MySQL.Async.execute([[
                        INSERT INTO pvp_player_stats (identifier, rename_free_season, rename_last_week)
                        VALUES (@id, @season, @week)
                        ON DUPLICATE KEY UPDATE
                            rename_free_season = @season,
                            rename_last_week   = @week
                    ]], {
                        ['@id']     = xPlayer.identifier,
                        ['@season'] = isFree and (tier ~= 'gold' and CURRENT_SEASON or lastSeason) or lastSeason,
                        ['@week']   = isFree and (tier == 'gold' and nowWeek or lastWeek) or lastWeek,
                    }, function()
                        xPlayer.set('firstName', newPseudo)
                        renameLocks[xPlayer.identifier] = nil
                        if isFree then
                            notify(source, ('~g~Pseudo changé pour ~w~%s~g~ (gratuit — %s)'):format(newPseudo, freeReason))
                        else
                            notify(source, ('~g~Pseudo changé pour ~w~%s~g~ (-%d$)'):format(newPseudo, RENAME_PRICE))
                        end
                    end)
                end
            )
        end
    )
end, false)

TriggerEvent('chat:addSuggestion', '/rename', 'Change ton pseudo (1x gratuit/saison, sinon 5000$)', {
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
