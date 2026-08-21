-- =============================================
--   PVP CHARACTER - Serveur
--   Création de personnage (pseudo + genre + apparence)
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
end)

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

-- Dispatch : signale à pvp_spawn (et autres) que le personnage est prêt
local function markCharacterReady(src)
    TriggerEvent('pvp_character:characterReady', src)
end

-- ── Connexion : détecte nouveau vs existant ──────────────────────────────
AddEventHandler('esx:playerLoaded', function(playerId)
    local src = type(playerId) == 'table' and playerId.source or playerId
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    MySQL.Async.fetchAll(
        [[
            SELECT u.firstname, u.sex,
                   COALESCE(s.skin_tone, 0)  AS skin_tone,
                   COALESCE(s.hair_style, 0) AS hair_style,
                   COALESCE(s.ped_model, '') AS ped_model
            FROM users u
            LEFT JOIN pvp_player_stats s ON s.identifier = u.identifier
            WHERE u.identifier = @id
        ]],
        { ['@id'] = xPlayer.identifier },
        function(result)
            local row = result and result[1]
            local firstname = row and row.firstname

            if row and firstname and firstname ~= '' then
                -- Joueur existant : applique le ped + signale ready
                xPlayer.set('firstName', firstname)
                TriggerClientEvent('pvp_character:applyModel', src, {
                    sex        = row.sex or 'm',
                    skin_tone  = tonumber(row.skin_tone) or 0,
                    hair_style = tonumber(row.hair_style) or 0,
                    ped_model  = row.ped_model or '',
                })
                markCharacterReady(src)
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
    local skinTone = math.max(0, math.min(3, tonumber(data.skin_tone) or 0))
    local hairIdx  = math.max(0, math.min(3, tonumber(data.hair_style) or 0))

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
                    INSERT INTO pvp_player_stats (identifier, skin_tone, hair_style)
                    VALUES (@id, @skin, @hair)
                    ON DUPLICATE KEY UPDATE skin_tone = @skin, hair_style = @hair
                ]],
                {
                    ['@id']   = xPlayer.identifier,
                    ['@skin'] = skinTone,
                    ['@hair'] = hairIdx,
                },
                function()
                    saveCharLocks[xPlayer.identifier] = nil
                    xPlayer.set('firstName', pseudo)
                    TriggerClientEvent('pvp_character:creationDone', src, {
                        sex        = gender,
                        skin_tone  = skinTone,
                        hair_style = hairIdx,
                    })
                    markCharacterReady(src)
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
