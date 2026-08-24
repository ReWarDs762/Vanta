-- =============================================
--   PVP CREW & SQUAD — Server
-- =============================================

local ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- ── Cache mémoire des bonus temporaires de crew (boutique) ─────────────────
-- [crewId] = { [buff_key] = { value = number, expiresAt = os.time() epoch } }
-- Rechargé depuis `pvp_crew_buffs` au démarrage (persistance redémarrage serveur).
local crewBuffsCache = {}

-- ── Création des tables au démarrage ──────────────────────────────────────
Citizen.CreateThread(function()
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `pvp_crews` (
            `id`            INT AUTO_INCREMENT PRIMARY KEY,
            `name`          VARCHAR(30) NOT NULL UNIQUE,
            `tag`           VARCHAR(5) NOT NULL UNIQUE,
            `owner`         VARCHAR(60) NOT NULL,
            `color`         VARCHAR(7) DEFAULT '#e53935',
            `motd`          VARCHAR(200) DEFAULT '',
            `kills_total`   INT DEFAULT 0,
            `deaths_total`  INT DEFAULT 0,
            `zombies_total` INT DEFAULT 0,
            `created_at`    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `pvp_crew_members` (
            `id`             INT AUTO_INCREMENT PRIMARY KEY,
            `crew_id`        INT NOT NULL,
            `identifier`     VARCHAR(60) NOT NULL UNIQUE,
            `name`           VARCHAR(60) DEFAULT 'Inconnu',
            `rank`           VARCHAR(20) DEFAULT 'member',
            `kills`          INT DEFAULT 0,
            `deaths`         INT DEFAULT 0,
            `zombies_killed` INT DEFAULT 0,
            `joined_at`      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (`crew_id`) REFERENCES `pvp_crews`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `pvp_crew_invites` (
            `id`         INT AUTO_INCREMENT PRIMARY KEY,
            `crew_id`    INT NOT NULL,
            `identifier` VARCHAR(60) NOT NULL,
            `invited_by` VARCHAR(60) NOT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY `unique_invite` (`crew_id`, `identifier`),
            FOREIGN KEY (`crew_id`) REFERENCES `pvp_crews`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `pvp_crew_activity` (
            `id`        INT AUTO_INCREMENT PRIMARY KEY,
            `crew_id`   INT NOT NULL,
            `type`      VARCHAR(20) NOT NULL,
            `message`   VARCHAR(200) NOT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (`crew_id`) REFERENCES `pvp_crews`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `pvp_crew_stash` (
            `id`      INT AUTO_INCREMENT PRIMARY KEY,
            `crew_id` INT NOT NULL,
            `item`    VARCHAR(64) NOT NULL,
            `count`   INT DEFAULT 0,
            UNIQUE KEY `unique_crew_item` (`crew_id`, `item`),
            FOREIGN KEY (`crew_id`) REFERENCES `pvp_crews`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `pvp_crew_objectives` (
            `id`            INT AUTO_INCREMENT PRIMARY KEY,
            `crew_id`       INT NOT NULL,
            `objective_key` VARCHAR(40) NOT NULL,
            `label`         VARCHAR(80) NOT NULL,
            `type`          VARCHAR(30) NOT NULL,
            `target`        INT NOT NULL,
            `progress`      INT DEFAULT 0,
            `reward_xp`     INT DEFAULT 0,
            `reward_bank`   INT DEFAULT 0,
            `period_key`    VARCHAR(20) NOT NULL,
            `completed`     TINYINT DEFAULT 0,
            `created_at`    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY `unique_objective_period` (`crew_id`, `objective_key`, `period_key`),
            FOREIGN KEY (`crew_id`) REFERENCES `pvp_crews`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `pvp_crew_events` (
            `id`         INT AUTO_INCREMENT PRIMARY KEY,
            `crew_id`    INT NOT NULL,
            `type`       VARCHAR(30) DEFAULT 'operation',
            `title`      VARCHAR(80) NOT NULL,
            `status`     VARCHAR(20) DEFAULT 'planned',
            `starts_at`  VARCHAR(30) DEFAULT '',
            `ends_at`    VARCHAR(30) DEFAULT '',
            `created_by` VARCHAR(60) NOT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (`crew_id`) REFERENCES `pvp_crews`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- ── Contrat quotidien de crew (élimination de zombies) ────────────────
    -- Une ligne par crew par jour (period_key = YYYY-MM-DD). `target` est
    -- recalculé en cours de journée quand un nouveau participant contribue
    -- (voir Config.DailyContract). Les lignes passées restent en base =
    -- historique implicite des contrats (même logique que pvp_crew_objectives).
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `pvp_crew_contracts` (
            `id`             INT AUTO_INCREMENT PRIMARY KEY,
            `crew_id`        INT NOT NULL,
            `period_key`     VARCHAR(20) NOT NULL,
            `target`         INT NOT NULL DEFAULT 0,
            `progress`       INT NOT NULL DEFAULT 0,
            `participants`   INT NOT NULL DEFAULT 0,
            `completed`      TINYINT DEFAULT 0,
            `reward_credits` INT DEFAULT 0,
            `completed_at`   TIMESTAMP NULL DEFAULT NULL,
            `created_at`     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY `unique_crew_contract_period` (`crew_id`, `period_key`),
            FOREIGN KEY (`crew_id`) REFERENCES `pvp_crews`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- ── Participants actifs par contrat (qui a contribué, combien) ─────────
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `pvp_crew_contract_participants` (
            `id`         INT AUTO_INCREMENT PRIMARY KEY,
            `crew_id`    INT NOT NULL,
            `period_key` VARCHAR(20) NOT NULL,
            `identifier` VARCHAR(60) NOT NULL,
            `kills`      INT NOT NULL DEFAULT 0,
            UNIQUE KEY `unique_contract_participant` (`crew_id`, `period_key`, `identifier`),
            FOREIGN KEY (`crew_id`) REFERENCES `pvp_crews`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- ── Historique des gains/dépenses de la trésorerie de crew ─────────────
    -- amount > 0 = gain (contrat), amount < 0 = dépense (achat boutique).
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `pvp_crew_treasury_log` (
            `id`          INT AUTO_INCREMENT PRIMARY KEY,
            `crew_id`     INT NOT NULL,
            `type`        VARCHAR(30) NOT NULL,
            `label`       VARCHAR(120) NOT NULL,
            `amount`      INT NOT NULL,
            `identifier`  VARCHAR(60) DEFAULT NULL,
            `player_name` VARCHAR(60) DEFAULT NULL,
            `created_at`  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (`crew_id`) REFERENCES `pvp_crews`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- ── Avantages temporaires de crew achetés en boutique ──────────────────
    -- expires_at/purchased_at en UNIX timestamp (secondes, os.time()) plutôt
    -- que TIMESTAMP SQL : évite tout décalage de fuseau horaire entre le
    -- calcul Lua (os.time()) et la comparaison SQL (NOW()) au redémarrage.
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `pvp_crew_buffs` (
            `id`            INT AUTO_INCREMENT PRIMARY KEY,
            `crew_id`       INT NOT NULL,
            `buff_key`      VARCHAR(30) NOT NULL,
            `value`         DECIMAL(10,2) NOT NULL,
            `purchased_by`  VARCHAR(60) NOT NULL,
            `purchased_at`  INT NOT NULL,
            `expires_at`    INT NOT NULL,
            FOREIGN KEY (`crew_id`) REFERENCES `pvp_crews`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- Ajouter les colonnes manquantes si tables existent déjà (portable)
    local function addCol(tbl, col, def)
        MySQL.Async.fetchScalar(
            [[SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = @t AND COLUMN_NAME = @c]],
            { ['@t'] = tbl, ['@c'] = col },
            function(count)
                if (tonumber(count) or 0) == 0 then
                    MySQL.Async.execute('ALTER TABLE `' .. tbl .. '` ADD COLUMN `' .. col .. '` ' .. def)
                end
            end
        )
    end
    addCol('pvp_crews',        'color',          "VARCHAR(7) DEFAULT '#e53935'")
    addCol('pvp_crews',        'motd',           "VARCHAR(200) DEFAULT ''")
    addCol('pvp_crews',        'zombies_total',  'INT DEFAULT 0')
    addCol('pvp_crews',        'bank',           'INT DEFAULT 0')
    addCol('pvp_crews',        'xp',             'INT DEFAULT 0')
    addCol('pvp_crews',        'level',          'INT DEFAULT 1')
    addCol('pvp_crews',        'objectives_completed', 'INT DEFAULT 0')
    addCol('pvp_crews',        'events_won',     'INT DEFAULT 0')
    addCol('pvp_crew_members', 'zombies_killed', 'INT DEFAULT 0')
    addCol('pvp_crew_members', 'stash_deposits', 'INT DEFAULT 0')
    addCol('pvp_crew_members', 'stash_withdraws','INT DEFAULT 0')

    print('[pvp_crew] Tables crew créées.')
end)

-- ── Rechargement des bonus de crew actifs au démarrage (persistance) ───────
-- Attend que les tables soient prêtes (créées dans le thread ci-dessus, sur
-- la même connexion : l'ordre d'exécution des requêtes MySQL.Async est
-- préservé). Réapplique aussi le bonus de conteneur à tout membre déjà
-- connecté (cas: redémarrage resource pendant qu'un bonus est actif).
Citizen.CreateThread(function()
    Citizen.Wait(1500)
    MySQL.Async.fetchAll('SELECT crew_id, buff_key, value, expires_at FROM pvp_crew_buffs WHERE expires_at > @now', {
        ['@now'] = os.time()
    }, function(rows)
        for _, r in ipairs(rows or {}) do
            crewBuffsCache[r.crew_id] = crewBuffsCache[r.crew_id] or {}
            crewBuffsCache[r.crew_id][r.buff_key] = { value = tonumber(r.value), expiresAt = tonumber(r.expires_at) }
        end
        if reapplyAllCrewContainerBoosts then reapplyAllCrewContainerBoosts() end
        print(('[pvp_crew] %d bonus de crew actifs rechargés.'):format(#(rows or {})))
    end)
end)

-- ══════════════════════════════════════════════════════════════════════════
--   UTILITAIRES
-- ══════════════════════════════════════════════════════════════════════════

-- SÉCURITÉ : sanitisation des inputs texte exposés à la NUI.
-- Le NUI peut rendre ces champs en innerHTML → risque XSS.
-- On strip les chars HTML/JS et les caractères de contrôle.
local function sanitizeText(s, maxLen)
    if type(s) ~= 'string' then return '' end
    -- Retire caractères de contrôle (< 0x20), <, >, &, ", ', `, \
    s = s:gsub('[%z\1-\31<>&"\'`\\]', '')
    -- Trim whitespace en début/fin
    s = s:match('^%s*(.-)%s*$') or ''
    if maxLen and #s > maxLen then s = s:sub(1, maxLen) end
    return s
end

local function getIdentifier(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then return xPlayer.identifier end
    return nil
end

local function getPlayerName(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    local raw = (xPlayer and xPlayer.getName()) or GetPlayerName(src) or 'Inconnu'
    -- SÉCURITÉ : les noms joueur sont injectés dans les messages d'activité
    -- et rendus en NUI → sanitiser pour éviter XSS par pseudo malveillant.
    return sanitizeText(raw, 60)
end

-- Récupère le crew_id + rank d'un joueur
local function getPlayerCrewInfo(identifier, cb)
    MySQL.Async.fetchAll('SELECT crew_id, rank FROM pvp_crew_members WHERE identifier = @id', {
        ['@id'] = identifier
    }, function(results)
        if results and #results > 0 then
            cb(results[1].crew_id, results[1].rank)
        else
            cb(nil, nil)
        end
    end)
end

-- Récupère les données complètes d'un crew
local loadCrewAdvanced
local function getCrewData(crewId, cb)
    MySQL.Async.fetchAll('SELECT * FROM pvp_crews WHERE id = @id', { ['@id'] = crewId }, function(crews)
        if not crews or #crews == 0 then cb(nil) return end
        local crew = crews[1]
        MySQL.Async.fetchAll('SELECT identifier, name, rank, kills, deaths, zombies_killed, joined_at FROM pvp_crew_members WHERE crew_id = @id ORDER BY kills DESC, zombies_killed DESC', {
            ['@id'] = crewId
        }, function(members)
            crew.members = members or {}
            -- Déterminer le meilleur joueur
            if #crew.members > 0 then
                crew.bestPlayer = crew.members[1].name
            end
            -- Joueurs en ligne
            local xPlayers = ESX.GetPlayers()
            local onlineIds = {}
            for _, pid in ipairs(xPlayers) do
                local xP = ESX.GetPlayerFromId(pid)
                if xP then onlineIds[xP.identifier] = true end
            end
            for _, m in ipairs(crew.members) do
                m.online = onlineIds[m.identifier] or false
                local ok, url = pcall(function()
                    return exports['pvp_inventory']:getAvatarUrl(m.identifier)
                end)
                m.avatarUrl = (ok and url) or nil
            end
            -- Récupérer l'activité récente
            MySQL.Async.fetchAll('SELECT type, message, created_at FROM pvp_crew_activity WHERE crew_id = @id ORDER BY created_at DESC LIMIT 15', {
                ['@id'] = crewId
            }, function(activity)
                crew.activity = activity or {}
                loadCrewAdvanced(crewId, function(advanced)
                    crew.stash = advanced.stash
                    crew.objectives = advanced.objectives
                    crew.events = advanced.events
                    crew.contract = advanced.contract
                    crew.history = advanced.history
                    crew.shopItems = advanced.shopItems
                    cb(crew)
                end)
            end)
        end)
    end)
end

-- Ajouter une entrée d'activité
local function addCrewActivity(crewId, actType, message)
    MySQL.Async.execute('INSERT INTO pvp_crew_activity (crew_id, type, message) VALUES (@cid, @type, @msg)', {
        ['@cid'] = crewId, ['@type'] = actType, ['@msg'] = message
    })
    -- Nettoyer les anciennes entrées (garder max 50)
    MySQL.Async.execute('DELETE FROM pvp_crew_activity WHERE crew_id = @cid AND id NOT IN (SELECT id FROM (SELECT id FROM pvp_crew_activity WHERE crew_id = @cid ORDER BY created_at DESC LIMIT 50) AS t)', {
        ['@cid'] = crewId
    })
end

-- ══════════════════════════════════════════════════════════════════════════
local ROLE_LABELS = {
    owner = 'Chef',
    officer = 'Officier',
    quartermaster = 'Intendant',
    recruiter = 'Recruteur',
    member = 'Membre',
    recruit = 'Recrue',
}

local ROLE_PERMISSIONS = {
    owner = { invite=true, kick=true, promote=true, manage=true, stashDeposit=true, stashWithdraw=true, event=true },
    officer = { invite=true, kick=true, manage=true, stashDeposit=true, stashWithdraw=true, event=true },
    quartermaster = { stashDeposit=true, stashWithdraw=true },
    recruiter = { invite=true, stashDeposit=true },
    member = { stashDeposit=true },
    recruit = {},
}

local function hasPermission(rank, permission)
    local perms = ROLE_PERMISSIONS[rank or 'recruit']
    return perms and perms[permission] == true
end

local function normalizeRank(rank)
    if ROLE_PERMISSIONS[rank] then return rank end
    return 'member'
end

local function isValidItemName(name)
    return type(name) == 'string' and #name >= 2 and #name <= 64 and name:match('^[a-z0-9_]+$') ~= nil
end

local function getInventoryItem(xPlayer, itemName)
    if not xPlayer or not itemName then return nil end
    local ok, item = pcall(function() return xPlayer.getInventoryItem(itemName) end)
    if ok then return item end
    return nil
end

local function getItemLabel(xPlayer, itemName)
    local item = getInventoryItem(xPlayer, itemName)
    return (item and item.label) or itemName
end

local function getPeriodKey(kind)
    if kind == 'weekly' then return os.date('%Y-W%W') end
    return os.date('%Y-%m-%d')
end

-- NOTE : l'ancien objectif générique 'daily_zombies' (75 zombies, cible fixe)
-- a été retiré et remplacé par le Contrat Quotidien de Crew dédié ci-dessous
-- (voir ensureCrewContract/progressContract) : cible qui s'adapte au nombre
-- de participants actifs + récompense en crédits de crew + historique dédié.
-- Le garder ici aurait doublé la récompense pour les mêmes kills de zombies.
local DEFAULT_OBJECTIVES = {
    { key='daily_pvp_kills', label='Abattre 10 survivants', type='pvp_kill', target=10, rewardXp=300, rewardBank=750, period='daily' },
    { key='weekly_redzone', label='Dominer la redzone: 25 kills', type='redzone_kill', target=25, rewardXp=1200, rewardBank=2500, period='weekly' },
}

local function ensureCrewObjectives(crewId)
    for _, obj in ipairs(DEFAULT_OBJECTIVES) do
        MySQL.Async.execute([[
            INSERT IGNORE INTO pvp_crew_objectives
                (crew_id, objective_key, label, type, target, reward_xp, reward_bank, period_key)
            VALUES (@cid, @key, @label, @type, @target, @xp, @bank, @period)
        ]], {
            ['@cid'] = crewId,
            ['@key'] = obj.key,
            ['@label'] = obj.label,
            ['@type'] = obj.type,
            ['@target'] = obj.target,
            ['@xp'] = obj.rewardXp,
            ['@bank'] = obj.rewardBank,
            ['@period'] = getPeriodKey(obj.period),
        })
    end
end

-- ══════════════════════════════════════════════════════════════════════════
--   TRÉSORERIE DE CREW — historique des gains/dépenses
-- ══════════════════════════════════════════════════════════════════════════
-- amount > 0 = gain (contrat), amount < 0 = dépense (achat boutique).
local function logTreasury(crewId, opType, label, amount, identifier, playerName)
    MySQL.Async.execute([[
        INSERT INTO pvp_crew_treasury_log (crew_id, type, label, amount, identifier, player_name)
        VALUES (@cid, @type, @label, @amount, @id, @name)
    ]], {
        ['@cid'] = crewId, ['@type'] = opType, ['@label'] = label,
        ['@amount'] = amount, ['@id'] = identifier, ['@name'] = playerName,
    })
end

-- ── Notifie tous les membres en ligne d'un crew (toast client) ────────────
local function notifyCrewMembers(crewId, message)
    MySQL.Async.fetchAll('SELECT identifier FROM pvp_crew_members WHERE crew_id = @cid', { ['@cid'] = crewId }, function(rows)
        local ids = {}
        for _, r in ipairs(rows or {}) do ids[r.identifier] = true end
        local xPlayers = ESX.GetPlayers()
        for _, playerId in ipairs(xPlayers) do
            local xP = ESX.GetPlayerFromId(playerId)
            if xP and ids[xP.identifier] then
                TriggerClientEvent('pvp_crew:notify', playerId, message)
            end
        end
    end)
end

local function getCrewMemberIdentifiers(crewId, cb)
    MySQL.Async.fetchAll('SELECT identifier FROM pvp_crew_members WHERE crew_id = @cid', { ['@cid'] = crewId }, function(rows)
        local ids = {}
        for _, r in ipairs(rows or {}) do ids[#ids + 1] = r.identifier end
        cb(ids)
    end)
end

-- ── Applique/retire le bonus de conteneur "boutique de crew" à tous les
--    membres d'un crew. Utilise la source dédiée 'crew' de pvp_inventory,
--    additive avec les bonus prestige (vanta_xp) et abonnement (pvp_vcoins) —
--    voir exports('setContainerBonus', ...) dans pvp_inventory/server/server.lua.
--    Ré-appelée avec bonus=0 quand le buff expire ou qu'un membre part :
--    ça ne supprime ni ne duplique aucun objet, ça ajuste juste la capacité
--    max — un coffre déjà au-dessus de la nouvelle limite reste intact, le
--    joueur ne peut simplement plus rien y déposer tant qu'il n'est pas repassé
--    sous la limite (même logique que pour tout changement de capacité).
function applyCrewContainerBoost(crewId)
    local buffs = crewBuffsCache[crewId]
    local buff = buffs and buffs.container_boost
    local now = os.time()
    local bonus = (buff and buff.expiresAt > now) and buff.value or 0
    getCrewMemberIdentifiers(crewId, function(ids)
        for _, identifier in ipairs(ids) do
            pcall(function()
                exports['pvp_inventory']:setContainerBonus(identifier, bonus, 'crew')
            end)
        end
    end)
end

-- ── Retire le bonus de conteneur "boutique de crew" d'un joueur qui quitte
--    (leave/kick/disband) : il n'est plus couvert par le buff de son ancien
--    crew, quel que soit son état (actif ou déjà expiré).
local function resetMemberCrewContainerBonus(identifier)
    pcall(function()
        exports['pvp_inventory']:setContainerBonus(identifier, 0, 'crew')
    end)
end

-- ── Réapplique le bonus de conteneur pour tous les crews ayant un buff actif
--    (appelé une seule fois au démarrage de la resource, après le rechargement
--    de crewBuffsCache — couvre le cas d'un redémarrage pendant un bonus actif).
function reapplyAllCrewContainerBoosts()
    for crewId, buffs in pairs(crewBuffsCache) do
        if buffs.container_boost then
            applyCrewContainerBoost(crewId)
        end
    end
end

local BUFF_LABELS = {
    zombie_xp2      = 'XP Zombies x2',
    pvp_xp50        = 'XP PvP +50%',
    container_boost = 'Coffre protégé (bonus temporaire)',
}

-- ── Construit le payload boutique pour la NUI (config statique + état live) ─
local function buildShopPayload(crewId)
    local buffs = crewBuffsCache[crewId] or {}
    local now = os.time()
    local list = {}
    for _, it in ipairs(Config.CrewShop) do
        local active = buffs[it.key]
        local activeUntil = (active and active.expiresAt > now) and active.expiresAt or nil
        list[#list + 1] = {
            key = it.key,
            label = it.label,
            description = it.description,
            cost = it.cost,
            durationMinutes = it.durationMinutes,
            value = it.value,
            activeUntil = activeUntil, -- epoch secondes (os.time()), nil si inactif
        }
    end
    return list
end

-- ══════════════════════════════════════════════════════════════════════════
--   CONTRAT QUOTIDIEN DE CREW — élimination de zombies
-- ══════════════════════════════════════════════════════════════════════════
-- target = ZombiesPerMember × nombre de participants actifs (membres ayant
-- contribué au moins 1 kill au contrat du jour). Recalculé à chaque nouveau
-- participant. Progression et complétion 100% côté serveur (déclenché
-- uniquement par le handler interne pvp_crew:zombieKill, jamais par le client).

local function computeContractTarget(participants)
    participants = math.max(Config.DailyContract.MinParticipants, math.min(participants, Config.DailyContract.MaxParticipants))
    return Config.DailyContract.ZombiesPerMember * participants
end

local function ensureCrewContract(crewId, cb)
    local period = getPeriodKey('daily')
    MySQL.Async.fetchAll('SELECT * FROM pvp_crew_contracts WHERE crew_id = @cid AND period_key = @p', {
        ['@cid'] = crewId, ['@p'] = period
    }, function(rows)
        if rows and rows[1] then cb(rows[1]) return end
        local target = computeContractTarget(0)
        MySQL.Async.insert([[
            INSERT INTO pvp_crew_contracts (crew_id, period_key, target, participants)
            VALUES (@cid, @p, @t, 0)
        ]], { ['@cid'] = crewId, ['@p'] = period, ['@t'] = target }, function(id)
            cb({
                id = id, crew_id = crewId, period_key = period,
                target = target, progress = 0, participants = 0,
                completed = 0, reward_credits = 0,
            })
        end)
    end)
end

local function completeContract(crewId, contract)
    local participants = math.max(tonumber(contract.participants) or 1, 1)
    local reward = math.floor(Config.DailyContract.RewardPerParticipant * participants)
    reward = math.max(Config.DailyContract.MinReward, math.min(reward, Config.DailyContract.MaxReward))

    -- Garde `completed = 0` dans le WHERE : anti-race si deux kills concurrents
    -- déclenchent la complétion en même temps, un seul l'emporte réellement
    -- (affected = 0 pour le second) → pas de double récompense.
    MySQL.Async.execute(
        'UPDATE pvp_crew_contracts SET completed = 1, reward_credits = @r, completed_at = NOW() WHERE id = @id AND completed = 0',
        { ['@r'] = reward, ['@id'] = contract.id },
        function(affected)
            if not affected or affected < 1 then return end
            MySQL.Async.execute('UPDATE pvp_crews SET bank = bank + @r WHERE id = @cid', { ['@r'] = reward, ['@cid'] = crewId })
            logTreasury(crewId, 'contract_reward', 'Contrat quotidien : élimination de zombies', reward, nil, nil)
            addCrewActivity(crewId, 'contract', ('Contrat quotidien terminé (%d participants) : +%d crédits de crew.'):format(participants, reward))
            notifyCrewMembers(crewId, ('Contrat quotidien terminé ! +%d crédits de crew.'):format(reward))
        end
    )
end

-- ── Progression du contrat, appelée depuis le handler interne zombieKill.
-- `identifier` est déjà garanti membre du crew par l'appelant.
local function progressContract(crewId, identifier)
    ensureCrewContract(crewId, function(contract)
        if tonumber(contract.completed) == 1 then return end -- contrat du jour déjà bouclé

        MySQL.Async.fetchScalar(
            'SELECT COUNT(*) FROM pvp_crew_contract_participants WHERE crew_id = @cid AND period_key = @p AND identifier = @id',
            { ['@cid'] = crewId, ['@p'] = contract.period_key, ['@id'] = identifier },
            function(existCount)
                local isNewParticipant = (tonumber(existCount) or 0) == 0

                MySQL.Async.execute([[
                    INSERT INTO pvp_crew_contract_participants (crew_id, period_key, identifier, kills)
                    VALUES (@cid, @p, @id, 1)
                    ON DUPLICATE KEY UPDATE kills = kills + 1
                ]], { ['@cid'] = crewId, ['@p'] = contract.period_key, ['@id'] = identifier })

                local function bumpProgress()
                    -- LEAST(...) : ne dépasse jamais la cible même si plusieurs
                    -- kills arrivent groupés juste avant la complétion.
                    MySQL.Async.execute(
                        'UPDATE pvp_crew_contracts SET progress = LEAST(progress + 1, target) WHERE id = @id AND completed = 0',
                        { ['@id'] = contract.id },
                        function()
                            MySQL.Async.fetchAll('SELECT * FROM pvp_crew_contracts WHERE id = @id', { ['@id'] = contract.id }, function(rows2)
                                local c = rows2 and rows2[1]
                                if c and tonumber(c.completed) == 0 and tonumber(c.target) > 0 and tonumber(c.progress) >= tonumber(c.target) then
                                    completeContract(crewId, c)
                                end
                            end)
                        end
                    )
                end

                if isNewParticipant then
                    local newParticipants = math.min((tonumber(contract.participants) or 0) + 1, Config.DailyContract.MaxParticipants)
                    local newTarget = computeContractTarget(newParticipants)
                    MySQL.Async.execute(
                        'UPDATE pvp_crew_contracts SET participants = @pc, target = @t WHERE id = @id AND completed = 0',
                        { ['@pc'] = newParticipants, ['@t'] = newTarget, ['@id'] = contract.id },
                        bumpProgress
                    )
                else
                    bumpProgress()
                end
            end
        )
    end)
end

function loadCrewAdvanced(crewId, cb)
    ensureCrewObjectives(crewId)
    MySQL.Async.fetchAll('SELECT item, count FROM pvp_crew_stash WHERE crew_id = @cid AND count > 0 ORDER BY item ASC', {
        ['@cid'] = crewId
    }, function(stash)
        MySQL.Async.fetchAll('SELECT * FROM pvp_crew_objectives WHERE crew_id = @cid ORDER BY completed ASC, period_key DESC, id ASC', {
            ['@cid'] = crewId
        }, function(objectives)
            MySQL.Async.fetchAll('SELECT id, type, title, status, starts_at, ends_at, created_by, created_at FROM pvp_crew_events WHERE crew_id = @cid ORDER BY created_at DESC LIMIT 20', {
                ['@cid'] = crewId
            }, function(events)
                ensureCrewContract(crewId, function(contract)
                    MySQL.Async.fetchAll([[
                        SELECT type, label, amount, identifier, player_name, created_at
                        FROM pvp_crew_treasury_log WHERE crew_id = @cid
                        ORDER BY created_at DESC LIMIT 30
                    ]], { ['@cid'] = crewId }, function(history)
                        cb({
                            stash = stash or {}, objectives = objectives or {}, events = events or {},
                            contract = contract, history = history or {},
                            shopItems = buildShopPayload(crewId),
                        })
                    end)
                end)
            end)
        end)
    end)
end

local function rewardObjective(crewId, objective)
    local xp = tonumber(objective.reward_xp) or 0
    local bank = tonumber(objective.reward_bank) or 0
    MySQL.Async.execute(
        'UPDATE pvp_crews SET xp = xp + @xp, bank = bank + @bank, level = FLOOR((xp + @xp) / 1000) + 1, objectives_completed = objectives_completed + 1 WHERE id = @cid',
        { ['@cid'] = crewId, ['@xp'] = xp, ['@bank'] = bank }
    )
    addCrewActivity(crewId, 'objective', ('Objectif termine: %s (+%d XP, +$%d coffre crew).'):format(objective.label, xp, bank))
end

local function updateCrewObjectives(crewId, objType, amount)
    amount = tonumber(amount) or 1
    if not crewId or amount <= 0 then return end
    ensureCrewObjectives(crewId)
    MySQL.Async.fetchAll(
        'SELECT * FROM pvp_crew_objectives WHERE crew_id = @cid AND type = @type AND completed = 0',
        { ['@cid'] = crewId, ['@type'] = objType },
        function(rows)
            for _, obj in ipairs(rows or {}) do
                local target = tonumber(obj.target) or 0
                local progress = math.min(target, (tonumber(obj.progress) or 0) + amount)
                local completed = target > 0 and progress >= target
                MySQL.Async.execute(
                    'UPDATE pvp_crew_objectives SET progress = @progress, completed = @done WHERE id = @id AND completed = 0',
                    { ['@id'] = obj.id, ['@progress'] = progress, ['@done'] = completed and 1 or 0 }
                )
                if completed then rewardObjective(crewId, obj) end
            end
        end
    )
end
--   CREW — Création
-- ══════════════════════════════════════════════════════════════════════════

ESX.RegisterServerCallback('pvp_crew:createCrew', function(src, cb, name, tag)
    local identifier = getIdentifier(src)
    if not identifier then cb(false, 'Erreur joueur.') return end

    -- SÉCURITÉ : sanitisation (anti-XSS dans la NUI) + validation longueur.
    name = sanitizeText(name, Config.MaxCrewNameLength)
    tag  = sanitizeText(tag,  Config.MaxCrewTagLength)

    if #name < 3 or #name > Config.MaxCrewNameLength then
        cb(false, 'Nom invalide (3-' .. Config.MaxCrewNameLength .. ' caractères).')
        return
    end
    if #tag < Config.MinCrewTagLength or #tag > Config.MaxCrewTagLength then
        cb(false, 'Tag invalide (' .. Config.MinCrewTagLength .. '-' .. Config.MaxCrewTagLength .. ' caractères).')
        return
    end
    -- Tag : alphanumérique uniquement (pas de caractères exotiques)
    if not tag:match('^[%w]+$') then
        cb(false, 'Tag doit être alphanumérique.')
        return
    end

    -- Vérifier que le joueur n'est pas déjà dans un crew
    getPlayerCrewInfo(identifier, function(existingCrewId)
        if existingCrewId then
            cb(false, 'Vous êtes déjà dans un crew.')
            return
        end

        -- Vérifier le solde
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then cb(false, 'Erreur joueur.') return end
        local balance = xPlayer.getAccount('bank').money
        if balance < Config.CrewCreationCost then
            cb(false, 'Fonds insuffisants ($' .. Config.CrewCreationCost .. ' requis).')
            return
        end

        -- Vérifier unicité du nom et tag
        MySQL.Async.fetchAll('SELECT id FROM pvp_crews WHERE name = @name OR tag = @tag', {
            ['@name'] = name, ['@tag'] = tag:upper()
        }, function(existing)
            if existing and #existing > 0 then
                cb(false, 'Ce nom ou tag est déjà pris.')
                return
            end

            -- Créer le crew
            xPlayer.removeAccountMoney('bank', Config.CrewCreationCost)
            MySQL.Async.insert('INSERT INTO pvp_crews (name, tag, owner) VALUES (@name, @tag, @owner)', {
                ['@name'] = name, ['@tag'] = tag:upper(), ['@owner'] = identifier
            }, function(crewId)
                MySQL.Async.execute('INSERT INTO pvp_crew_members (crew_id, identifier, name, rank) VALUES (@cid, @id, @name, "owner")', {
                    ['@cid'] = crewId, ['@id'] = identifier, ['@name'] = getPlayerName(src)
                })
                ensureCrewObjectives(crewId)
                addCrewActivity(crewId, 'create', getPlayerName(src) .. ' a créé le crew.')
                cb(true, 'Crew "' .. name .. '" [' .. tag:upper() .. '] créé !')
                TriggerClientEvent('pvp_crew:updateTag', src, tag:upper())
            end)
        end)
    end)
end)

-- ══════════════════════════════════════════════════════════════════════════
--   CREW — Données
-- ══════════════════════════════════════════════════════════════════════════

ESX.RegisterServerCallback('pvp_crew:getMyCrewData', function(src, cb)
    local identifier = getIdentifier(src)
    if not identifier then cb(nil) return end

    getPlayerCrewInfo(identifier, function(crewId, rank)
        if not crewId then cb(nil) return end
        getCrewData(crewId, function(crew)
            if crew then crew.myRank = rank end
            cb(crew)
        end)
    end)
end)

ESX.RegisterServerCallback('pvp_crew:getMyInvites', function(src, cb)
    local identifier = getIdentifier(src)
    if not identifier then cb({}) return end

    MySQL.Async.fetchAll([[
        SELECT i.id, i.crew_id, c.name AS crew_name, c.tag AS crew_tag, i.invited_by, i.created_at
        FROM pvp_crew_invites i
        JOIN pvp_crews c ON c.id = i.crew_id
        WHERE i.identifier = @id
        ORDER BY i.created_at DESC
    ]], { ['@id'] = identifier }, function(results)
        cb(results or {})
    end)
end)

-- ══════════════════════════════════════════════════════════════════════════
--   CREW — Invitations
-- ══════════════════════════════════════════════════════════════════════════

ESX.RegisterServerCallback('pvp_crew:invitePlayer', function(src, cb, targetId)
    local identifier = getIdentifier(src)
    if not identifier then cb(false, 'Erreur.') return end

    local targetId = tonumber(targetId)
    if not targetId or targetId == src then cb(false, 'Cible invalide.') return end

    local targetIdentifier = getIdentifier(targetId)
    if not targetIdentifier then cb(false, 'Joueur introuvable.') return end

    getPlayerCrewInfo(identifier, function(crewId, rank)
        if not crewId then cb(false, 'Vous n\'êtes pas dans un crew.') return end
        if not hasPermission(rank, 'invite') then
            cb(false, 'Votre rôle ne peut pas inviter.')
            return
        end

        -- Vérifier que la cible n'a pas déjà un crew
        getPlayerCrewInfo(targetIdentifier, function(existingCrewId)
            if existingCrewId then
                cb(false, 'Ce joueur est déjà dans un crew.')
                return
            end

            -- Vérifier nombre de membres
            MySQL.Async.fetchScalar('SELECT COUNT(*) FROM pvp_crew_members WHERE crew_id = @cid', {
                ['@cid'] = crewId
            }, function(count)
                if count >= Config.MaxCrewMembers then
                    cb(false, 'Crew plein (' .. Config.MaxCrewMembers .. ' max).')
                    return
                end

                -- Insérer l'invitation
                MySQL.Async.execute('INSERT IGNORE INTO pvp_crew_invites (crew_id, identifier, invited_by) VALUES (@cid, @id, @by)', {
                    ['@cid'] = crewId, ['@id'] = targetIdentifier, ['@by'] = identifier
                }, function(rows)
                    if rows == 0 then
                        cb(false, 'Invitation déjà envoyée.')
                    else
                        cb(true, 'Invitation envoyée !')
                        -- Notifier la cible
                        TriggerClientEvent('pvp_crew:notifyInvite', targetId)
                    end
                end)
            end)
        end)
    end)
end)

ESX.RegisterServerCallback('pvp_crew:acceptInvite', function(src, cb, crewId)
    local identifier = getIdentifier(src)
    if not identifier then cb(false, 'Erreur.') return end

    -- Vérifier que l'invitation existe
    MySQL.Async.fetchAll('SELECT id FROM pvp_crew_invites WHERE crew_id = @cid AND identifier = @id', {
        ['@cid'] = crewId, ['@id'] = identifier
    }, function(results)
        if not results or #results == 0 then
            cb(false, 'Invitation expirée ou invalide.')
            return
        end

        -- Vérifier que le joueur n'est pas déjà dans un crew
        getPlayerCrewInfo(identifier, function(existingCrewId)
            if existingCrewId then
                cb(false, 'Vous êtes déjà dans un crew.')
                return
            end

            -- Rejoindre le crew
            MySQL.Async.execute('INSERT INTO pvp_crew_members (crew_id, identifier, name, rank) VALUES (@cid, @id, @name, "member")', {
                ['@cid'] = crewId, ['@id'] = identifier, ['@name'] = getPlayerName(src)
            })
            -- Supprimer toutes les invitations pour ce joueur
            MySQL.Async.execute('DELETE FROM pvp_crew_invites WHERE identifier = @id', { ['@id'] = identifier })

            -- Récupérer le tag
            addCrewActivity(crewId, 'join', getPlayerName(src) .. ' a rejoint le crew.')
            MySQL.Async.fetchScalar('SELECT tag FROM pvp_crews WHERE id = @cid', { ['@cid'] = crewId }, function(tag)
                TriggerClientEvent('pvp_crew:updateTag', src, tag)

                -- Si le crew a un bonus "Coffre protégé" actif, le nouveau
                -- membre doit en bénéficier immédiatement.
                local buffs = crewBuffsCache[crewId]
                local buff = buffs and buffs.container_boost
                if buff and buff.expiresAt > os.time() then
                    pcall(function()
                        exports['pvp_inventory']:setContainerBonus(identifier, buff.value, 'crew')
                    end)
                end

                cb(true, 'Vous avez rejoint le crew !')
            end)
        end)
    end)
end)

ESX.RegisterServerCallback('pvp_crew:declineInvite', function(src, cb, crewId)
    local identifier = getIdentifier(src)
    if not identifier then cb(false) return end
    MySQL.Async.execute('DELETE FROM pvp_crew_invites WHERE crew_id = @cid AND identifier = @id', {
        ['@cid'] = crewId, ['@id'] = identifier
    })
    cb(true, 'Invitation refusée.')
end)

-- ══════════════════════════════════════════════════════════════════════════
--   CREW — Gestion des membres
-- ══════════════════════════════════════════════════════════════════════════

ESX.RegisterServerCallback('pvp_crew:kickMember', function(src, cb, targetIdentifier)
    local identifier = getIdentifier(src)
    if not identifier then cb(false, 'Erreur.') return end

    getPlayerCrewInfo(identifier, function(crewId, rank)
        if not crewId then cb(false, 'Pas de crew.') return end
        if not hasPermission(rank, 'kick') then
            cb(false, 'Permissions insuffisantes.')
            return
        end

        -- Vérifier le rang de la cible
        MySQL.Async.fetchAll('SELECT rank FROM pvp_crew_members WHERE crew_id = @cid AND identifier = @tid', {
            ['@cid'] = crewId, ['@tid'] = targetIdentifier
        }, function(results)
            if not results or #results == 0 then cb(false, 'Membre introuvable.') return end
            local targetRank = results[1].rank
            if targetRank == 'owner' then cb(false, 'Impossible d\'exclure le chef.') return end
            if rank == 'officer' and targetRank == 'officer' then
                cb(false, 'Un officier ne peut pas exclure un autre officier.')
                return
            end

            MySQL.Async.execute('DELETE FROM pvp_crew_members WHERE crew_id = @cid AND identifier = @tid', {
                ['@cid'] = crewId, ['@tid'] = targetIdentifier
            })
            addCrewActivity(crewId, 'kick', getPlayerName(src) .. ' a exclu un membre.')
            resetMemberCrewContainerBonus(targetIdentifier)
            cb(true, 'Membre exclu.')

            -- Notifier la cible si en ligne
            local xPlayers = ESX.GetPlayers()
            for _, playerId in ipairs(xPlayers) do
                local xP = ESX.GetPlayerFromId(playerId)
                if xP and xP.identifier == targetIdentifier then
                    TriggerClientEvent('pvp_crew:updateTag', playerId, nil)
                    TriggerClientEvent('pvp_crew:kicked', playerId)
                    break
                end
            end
        end)
    end)
end)

ESX.RegisterServerCallback('pvp_crew:promoteMember', function(src, cb, targetIdentifier, newRank)
    local identifier = getIdentifier(src)
    if not identifier then cb(false, 'Erreur.') return end

    newRank = normalizeRank(newRank)
    if newRank == 'owner' then
        cb(false, 'Rang invalide.')
        return
    end

    getPlayerCrewInfo(identifier, function(crewId, rank)
        if not crewId then cb(false, 'Pas de crew.') return end
        if rank ~= 'owner' then
            cb(false, 'Seul le chef peut promouvoir/rétrograder.')
            return
        end

        MySQL.Async.execute('UPDATE pvp_crew_members SET rank = @rank WHERE crew_id = @cid AND identifier = @tid AND rank != "owner"', {
            ['@rank'] = newRank, ['@cid'] = crewId, ['@tid'] = targetIdentifier
        })
        cb(true, 'Rang mis à jour.')
    end)
end)

-- ══════════════════════════════════════════════════════════════════════════
--   CREW — Quitter / Dissoudre
-- ══════════════════════════════════════════════════════════════════════════

ESX.RegisterServerCallback('pvp_crew:leaveCrew', function(src, cb)
    local identifier = getIdentifier(src)
    if not identifier then cb(false, 'Erreur.') return end

    getPlayerCrewInfo(identifier, function(crewId, rank)
        if not crewId then cb(false, 'Pas de crew.') return end

        if rank == 'owner' then
            -- Transférer le ownership au plus ancien officier, sinon au plus ancien membre
            MySQL.Async.fetchAll('SELECT identifier FROM pvp_crew_members WHERE crew_id = @cid AND identifier != @id ORDER BY FIELD(rank, "officer", "member"), joined_at ASC LIMIT 1', {
                ['@cid'] = crewId, ['@id'] = identifier
            }, function(results)
                if not results or #results == 0 then
                    -- Seul membre → dissoudre
                    MySQL.Async.execute('DELETE FROM pvp_crews WHERE id = @cid', { ['@cid'] = crewId })
                    TriggerClientEvent('pvp_crew:updateTag', src, nil)
                    resetMemberCrewContainerBonus(identifier)
                    cb(true, 'Crew dissous (vous étiez le dernier membre).')
                else
                    -- Transférer
                    local newOwner = results[1].identifier
                    MySQL.Async.execute('UPDATE pvp_crew_members SET rank = "owner" WHERE crew_id = @cid AND identifier = @nid', {
                        ['@cid'] = crewId, ['@nid'] = newOwner
                    })
                    MySQL.Async.execute('UPDATE pvp_crews SET owner = @nid WHERE id = @cid', {
                        ['@cid'] = crewId, ['@nid'] = newOwner
                    })
                    MySQL.Async.execute('DELETE FROM pvp_crew_members WHERE crew_id = @cid AND identifier = @id', {
                        ['@cid'] = crewId, ['@id'] = identifier
                    })
                    TriggerClientEvent('pvp_crew:updateTag', src, nil)
                    resetMemberCrewContainerBonus(identifier)
                    cb(true, 'Vous avez quitté le crew. Le chef a été transféré.')
                end
            end)
        else
            MySQL.Async.execute('DELETE FROM pvp_crew_members WHERE crew_id = @cid AND identifier = @id', {
                ['@cid'] = crewId, ['@id'] = identifier
            })
            TriggerClientEvent('pvp_crew:updateTag', src, nil)
            resetMemberCrewContainerBonus(identifier)
            cb(true, 'Vous avez quitté le crew.')
        end
    end)
end)

ESX.RegisterServerCallback('pvp_crew:disbandCrew', function(src, cb)
    local identifier = getIdentifier(src)
    if not identifier then cb(false, 'Erreur.') return end

    getPlayerCrewInfo(identifier, function(crewId, rank)
        if not crewId then cb(false, 'Pas de crew.') return end
        if rank ~= 'owner' then cb(false, 'Seul le chef peut dissoudre.') return end

        -- Récupérer les membres pour les notifier
        MySQL.Async.fetchAll('SELECT identifier FROM pvp_crew_members WHERE crew_id = @cid', {
            ['@cid'] = crewId
        }, function(members)
            MySQL.Async.execute('DELETE FROM pvp_crews WHERE id = @cid', { ['@cid'] = crewId })

            -- Plus de crew : retire le bonus de conteneur de tous les membres
            -- (en ligne ou non — le mapping est par identifiant, pas par session).
            for _, m in ipairs(members or {}) do
                resetMemberCrewContainerBonus(m.identifier)
            end

            -- Notifier tous les membres en ligne
            local xPlayers = ESX.GetPlayers()
            for _, playerId in ipairs(xPlayers) do
                local xP = ESX.GetPlayerFromId(playerId)
                if xP then
                    for _, m in ipairs(members) do
                        if xP.identifier == m.identifier then
                            TriggerClientEvent('pvp_crew:updateTag', playerId, nil)
                            if playerId ~= src then
                                TriggerClientEvent('pvp_crew:disbanded', playerId)
                            end
                        end
                    end
                end
            end
            cb(true, 'Crew dissous.')
        end)
    end)
end)

-- ══════════════════════════════════════════════════════════════════════════
--   CREW — Liste des joueurs en ligne (pour inviter)
-- ══════════════════════════════════════════════════════════════════════════

ESX.RegisterServerCallback('pvp_crew:getOnlinePlayers', function(src, cb)
    local players = {}
    local xPlayers = ESX.GetPlayers()
    for _, playerId in ipairs(xPlayers) do
        if playerId ~= src then
            players[#players+1] = {
                id   = playerId,
                -- SÉCURITÉ : sanitisation (nom FiveM d'un joueur peut contenir du HTML/JS).
                name = sanitizeText(GetPlayerName(playerId) or ('Joueur #' .. playerId), 30)
            }
        end
    end
    cb(players)
end)

-- ══════════════════════════════════════════════════════════════════════════
--   CREW — MOTD, Couleur, Stats
-- ══════════════════════════════════════════════════════════════════════════

ESX.RegisterServerCallback('pvp_crew:setMotd', function(src, cb, motd)
    local identifier = getIdentifier(src)
    if not identifier then cb(false, 'Erreur.') return end
    -- SÉCURITÉ : sanitisation anti-XSS (le motd est rendu dans la NUI).
    motd = sanitizeText(motd, 200)
    if #motd > 200 then cb(false, 'Message trop long (200 max).') return end

    getPlayerCrewInfo(identifier, function(crewId, rank)
        if not crewId then cb(false, 'Pas de crew.') return end
        if not hasPermission(rank, 'manage') then cb(false, 'Permissions insuffisantes.') return end

        MySQL.Async.execute('UPDATE pvp_crews SET motd = @motd WHERE id = @cid', {
            ['@motd'] = motd, ['@cid'] = crewId
        })
        addCrewActivity(crewId, 'motd', getPlayerName(src) .. ' a modifié le message du crew.')
        cb(true, 'Message mis à jour.')
    end)
end)

ESX.RegisterServerCallback('pvp_crew:setColor', function(src, cb, color)
    local identifier = getIdentifier(src)
    if not identifier then cb(false, 'Erreur.') return end
    if not color or not color:match('^#%x%x%x%x%x%x$') then cb(false, 'Couleur invalide.') return end

    getPlayerCrewInfo(identifier, function(crewId, rank)
        if not crewId then cb(false, 'Pas de crew.') return end
        if not hasPermission(rank, 'manage') then cb(false, 'Permissions insuffisantes.') return end

        MySQL.Async.execute('UPDATE pvp_crews SET color = @color WHERE id = @cid', {
            ['@color'] = color, ['@cid'] = crewId
        })
        cb(true, 'Couleur mise à jour.')
    end)
end)

-- ── Incrémenter stats zombie pour le crew du joueur ──────────────────────
-- SÉCURITÉ : event INTERNE serveur (pas de RegisterNetEvent).
-- Prend un identifier en paramètre (appelé par pvp_zombies côté serveur).
-- ========================================================================
--   CREW AVANCE - Coffre, objectifs, evenements
-- ========================================================================

ESX.RegisterServerCallback('pvp_crew:getAdvancedData', function(src, cb)
    local identifier = getIdentifier(src)
    if not identifier then cb({ ok=false, message='Erreur joueur.' }) return end
    getPlayerCrewInfo(identifier, function(crewId, rank)
        if not crewId then cb({ ok=false, message='Pas de crew.' }) return end
        loadCrewAdvanced(crewId, function(data)
            data.ok = true
            data.permissions = ROLE_PERMISSIONS[rank] or {}
            data.roleLabels = ROLE_LABELS
            cb(data)
        end)
    end)
end)

ESX.RegisterServerCallback('pvp_crew:stashDeposit', function(src, cb, itemName, qty)
    local identifier = getIdentifier(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    qty = tonumber(qty) or 0
    if not identifier or not xPlayer then cb(false, 'Erreur joueur.') return end
    if qty < 1 or qty > 1000 or not isValidItemName(itemName) then cb(false, 'Item invalide.') return end

    getPlayerCrewInfo(identifier, function(crewId, rank)
        if not crewId then cb(false, 'Pas de crew.') return end
        if not hasPermission(rank, 'stashDeposit') then cb(false, 'Votre role ne peut pas deposer.') return end

        local item = getInventoryItem(xPlayer, itemName)
        if not item or (tonumber(item.count) or 0) < qty then cb(false, 'Quantite insuffisante.') return end
        xPlayer.removeInventoryItem(itemName, qty)
        MySQL.Async.execute([[
            INSERT INTO pvp_crew_stash (crew_id, item, count) VALUES (@cid, @item, @qty)
            ON DUPLICATE KEY UPDATE count = count + @qty
        ]], { ['@cid'] = crewId, ['@item'] = itemName, ['@qty'] = qty })
        MySQL.Async.execute('UPDATE pvp_crew_members SET stash_deposits = stash_deposits + @qty WHERE identifier = @id', {
            ['@id'] = identifier, ['@qty'] = qty
        })
        addCrewActivity(crewId, 'stash', getPlayerName(src) .. ' a depose ' .. qty .. 'x ' .. getItemLabel(xPlayer, itemName) .. '.')
        cb(true, 'Depot crew effectue.')
    end)
end)

ESX.RegisterServerCallback('pvp_crew:stashWithdraw', function(src, cb, itemName, qty)
    local identifier = getIdentifier(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    qty = tonumber(qty) or 0
    if not identifier or not xPlayer then cb(false, 'Erreur joueur.') return end
    if qty < 1 or qty > 1000 or not isValidItemName(itemName) then cb(false, 'Item invalide.') return end

    getPlayerCrewInfo(identifier, function(crewId, rank)
        if not crewId then cb(false, 'Pas de crew.') return end
        if not hasPermission(rank, 'stashWithdraw') then cb(false, 'Votre role ne peut pas retirer.') return end

        MySQL.Async.fetchScalar('SELECT count FROM pvp_crew_stash WHERE crew_id = @cid AND item = @item', {
            ['@cid'] = crewId, ['@item'] = itemName
        }, function(count)
            count = tonumber(count) or 0
            if count < qty then cb(false, 'Stock insuffisant.') return end

            local sql = count == qty
                and 'DELETE FROM pvp_crew_stash WHERE crew_id = @cid AND item = @item AND count >= @qty'
                or 'UPDATE pvp_crew_stash SET count = count - @qty WHERE crew_id = @cid AND item = @item AND count >= @qty'
            MySQL.Async.execute(sql, { ['@cid'] = crewId, ['@item'] = itemName, ['@qty'] = qty }, function(affected)
                if not affected or affected < 1 then cb(false, 'Stock modifie, reessayez.') return end
                xPlayer.addInventoryItem(itemName, qty)
                MySQL.Async.execute('UPDATE pvp_crew_members SET stash_withdraws = stash_withdraws + @qty WHERE identifier = @id', {
                    ['@id'] = identifier, ['@qty'] = qty
                })
                addCrewActivity(crewId, 'stash', getPlayerName(src) .. ' a retire ' .. qty .. 'x ' .. getItemLabel(xPlayer, itemName) .. '.')
                cb(true, 'Retrait crew effectue.')
            end)
        end)
    end)
end)

ESX.RegisterServerCallback('pvp_crew:createEvent', function(src, cb, title, eventType, startsAt)
    local identifier = getIdentifier(src)
    if not identifier then cb(false, 'Erreur joueur.') return end
    title = sanitizeText(title, 80)
    eventType = sanitizeText(eventType or 'operation', 30)
    startsAt = sanitizeText(startsAt or '', 30)
    if #title < 3 then cb(false, 'Titre trop court.') return end

    getPlayerCrewInfo(identifier, function(crewId, rank)
        if not crewId then cb(false, 'Pas de crew.') return end
        if not hasPermission(rank, 'event') then cb(false, 'Votre role ne peut pas creer un evenement.') return end
        MySQL.Async.execute('INSERT INTO pvp_crew_events (crew_id, type, title, starts_at, created_by) VALUES (@cid, @type, @title, @start, @by)', {
            ['@cid'] = crewId, ['@type'] = eventType, ['@title'] = title, ['@start'] = startsAt, ['@by'] = identifier
        })
        addCrewActivity(crewId, 'event', getPlayerName(src) .. ' a planifie: ' .. title)
        cb(true, 'Evenement crew cree.')
    end)
end)

ESX.RegisterServerCallback('pvp_crew:setEventStatus', function(src, cb, eventId, status)
    local identifier = getIdentifier(src)
    eventId = tonumber(eventId)
    status = sanitizeText(status or '', 20)
    if not identifier or not eventId then cb(false, 'Erreur.') return end
    if status ~= 'planned' and status ~= 'active' and status ~= 'won' and status ~= 'lost' and status ~= 'cancelled' then
        cb(false, 'Statut invalide.') return
    end

    getPlayerCrewInfo(identifier, function(crewId, rank)
        if not crewId then cb(false, 'Pas de crew.') return end
        if not hasPermission(rank, 'event') then cb(false, 'Permissions insuffisantes.') return end
        MySQL.Async.execute('UPDATE pvp_crew_events SET status = @status WHERE id = @id AND crew_id = @cid', {
            ['@status'] = status, ['@id'] = eventId, ['@cid'] = crewId
        })
        if status == 'won' then
            MySQL.Async.execute('UPDATE pvp_crews SET events_won = events_won + 1, xp = xp + 500, level = FLOOR((xp + 500) / 1000) + 1 WHERE id = @cid', { ['@cid'] = crewId })
            addCrewActivity(crewId, 'event', 'Evenement gagne: +500 XP crew.')
        else
            addCrewActivity(crewId, 'event', 'Statut evenement mis a jour: ' .. status)
        end
        cb(true, 'Evenement mis a jour.')
    end)
end)

-- ══════════════════════════════════════════════════════════════════════════
--   BOUTIQUE DE CREW — achat d'un avantage temporaire
-- ══════════════════════════════════════════════════════════════════════════
ESX.RegisterServerCallback('pvp_crew:buyShopItem', function(src, cb, buffKey)
    local identifier = getIdentifier(src)
    if not identifier then cb(false, 'Erreur joueur.') return end

    local shopItem = nil
    for _, it in ipairs(Config.CrewShop) do
        if it.key == buffKey then shopItem = it break end
    end
    if not shopItem then cb(false, 'Bonus invalide.') return end

    getPlayerCrewInfo(identifier, function(crewId, rank)
        if not crewId then cb(false, 'Pas de crew.') return end
        -- Dépense de la trésorerie collective : réservé au chef/officier,
        -- même permission que MOTD/couleur ('manage').
        if not hasPermission(rank, 'manage') then
            cb(false, 'Seuls le chef et les officiers peuvent acheter un bonus.')
            return
        end

        -- Anti cumul abusif : un bonus déjà actif ne peut pas être racheté
        -- par-dessus (pas d'extension ni de stack de valeur), il faut attendre
        -- son expiration.
        local now = os.time()
        local buffs = crewBuffsCache[crewId]
        local active = buffs and buffs[buffKey]
        if active and active.expiresAt > now then
            local minsLeft = math.ceil((active.expiresAt - now) / 60)
            cb(false, ('%s est déjà actif (expire dans %d min).'):format(shopItem.label, minsLeft))
            return
        end

        -- Débit atomique de la trésorerie : la condition bank >= cost dans le
        -- WHERE empêche un double-achat concurrent de passer en négatif.
        MySQL.Async.execute('UPDATE pvp_crews SET bank = bank - @cost WHERE id = @cid AND bank >= @cost', {
            ['@cost'] = shopItem.cost, ['@cid'] = crewId
        }, function(affected)
            if not affected or affected < 1 then
                cb(false, 'Crédits de crew insuffisants (' .. shopItem.cost .. ' requis).')
                return
            end

            local expiresAt = now + (shopItem.durationMinutes * 60)
            MySQL.Async.execute([[
                INSERT INTO pvp_crew_buffs (crew_id, buff_key, value, purchased_by, purchased_at, expires_at)
                VALUES (@cid, @key, @val, @by, @now, @exp)
            ]], {
                ['@cid'] = crewId, ['@key'] = buffKey, ['@val'] = shopItem.value,
                ['@by'] = identifier, ['@now'] = now, ['@exp'] = expiresAt,
            }, function()
                crewBuffsCache[crewId] = crewBuffsCache[crewId] or {}
                crewBuffsCache[crewId][buffKey] = { value = shopItem.value, expiresAt = expiresAt }

                logTreasury(crewId, 'shop_purchase', shopItem.label, -shopItem.cost, identifier, getPlayerName(src))
                addCrewActivity(crewId, 'shop', ('%s a acheté "%s" (-%d crédits, %d min).'):format(
                    getPlayerName(src), shopItem.label, shopItem.cost, shopItem.durationMinutes))

                if buffKey == 'container_boost' then
                    applyCrewContainerBoost(crewId)
                end

                notifyCrewMembers(crewId, ('%s activé pour %d minutes !'):format(shopItem.label, shopItem.durationMinutes))
                cb(true, shopItem.label .. ' activé !')
            end)
        end)
    end)
end)

AddEventHandler('pvp_crew:zombieKill', function(identifier)
    if type(identifier) ~= 'string' or identifier == '' then return end

    MySQL.Async.fetchAll('SELECT crew_id FROM pvp_crew_members WHERE identifier = @id', {
        ['@id'] = identifier
    }, function(results)
        if results and #results > 0 then
            local crewId = results[1].crew_id
            MySQL.Async.execute('UPDATE pvp_crew_members SET zombies_killed = zombies_killed + 1 WHERE identifier = @id', { ['@id'] = identifier })
            MySQL.Async.execute('UPDATE pvp_crews SET zombies_total = zombies_total + 1 WHERE id = @cid', { ['@cid'] = crewId })
            updateCrewObjectives(crewId, 'zombie_kill', 1)
            progressContract(crewId, identifier)
        end
    end)
end)

-- ── Incrémenter stats PVP pour le crew du joueur ─────────────────────────
-- SÉCURITÉ : event INTERNE serveur (pas de RegisterNetEvent).
-- Sans ça, un client pouvait trigger pvp_crew:pvpKill avec des identifiers
-- arbitraires pour inflate les stats de n'importe quel crew.
AddEventHandler('pvp_crew:pvpKill', function(killerIdentifier, victimIdentifier)
    -- Killer stats
    if killerIdentifier then
        MySQL.Async.fetchAll('SELECT crew_id FROM pvp_crew_members WHERE identifier = @id', { ['@id'] = killerIdentifier }, function(results)
            if results and #results > 0 then
                local crewId = results[1].crew_id
                MySQL.Async.execute('UPDATE pvp_crew_members SET kills = kills + 1 WHERE identifier = @id', { ['@id'] = killerIdentifier })
                MySQL.Async.execute('UPDATE pvp_crews SET kills_total = kills_total + 1 WHERE id = @cid', { ['@cid'] = crewId })
                updateCrewObjectives(crewId, 'pvp_kill', 1)
            end
        end)
    end
    -- Victim stats
    if victimIdentifier then
        MySQL.Async.fetchAll('SELECT crew_id FROM pvp_crew_members WHERE identifier = @id', { ['@id'] = victimIdentifier }, function(results)
            if results and #results > 0 then
                local crewId = results[1].crew_id
                MySQL.Async.execute('UPDATE pvp_crew_members SET deaths = deaths + 1 WHERE identifier = @id', { ['@id'] = victimIdentifier })
                MySQL.Async.execute('UPDATE pvp_crews SET deaths_total = deaths_total + 1 WHERE id = @cid', { ['@cid'] = crewId })
            end
        end)
    end
end)

-- ══════════════════════════════════════════════════════════════════════════
AddEventHandler('pvp_crew:redzoneKill', function(identifier)
    if type(identifier) ~= 'string' or identifier == '' then return end
    MySQL.Async.fetchAll('SELECT crew_id FROM pvp_crew_members WHERE identifier = @id', {
        ['@id'] = identifier
    }, function(results)
        if results and #results > 0 then
            updateCrewObjectives(results[1].crew_id, 'redzone_kill', 1)
        end
    end)
end)
--   SQUAD — Système temporaire (mémoire uniquement)
-- ══════════════════════════════════════════════════════════════════════════

local squads       = {}     -- { [squadId] = { leader=src, members={src1, src2...} } }
local playerSquad  = {}     -- { [src] = squadId }
local squadInvites = {}     -- { [targetSrc] = { from=src, squadId=id } }
local nextSquadId  = 1

local function getSquadData(squadId)
    local squad = squads[squadId]
    if not squad then return nil end
    local data = { id = squadId, leader = squad.leader, members = {} }
    for _, memberId in ipairs(squad.members) do
        data.members[#data.members+1] = {
            id   = memberId,
            -- SÉCURITÉ : sanitisation avant envoi NUI (cf. sanitizeText).
            name = sanitizeText(GetPlayerName(memberId) or ('Joueur #' .. memberId), 30),
            isLeader = (memberId == squad.leader)
        }
    end
    return data
end

local function broadcastSquadUpdate(squadId)
    local squad = squads[squadId]
    if not squad then return end
    local data = getSquadData(squadId)
    for _, memberId in ipairs(squad.members) do
        TriggerClientEvent('pvp_crew:squadUpdate', memberId, data)
    end
end

local function removeFromSquad(src)
    local squadId = playerSquad[src]
    if not squadId or not squads[squadId] then return end

    local squad = squads[squadId]
    -- Retirer le membre
    for i, m in ipairs(squad.members) do
        if m == src then
            table.remove(squad.members, i)
            break
        end
    end
    playerSquad[src] = nil
    TriggerClientEvent('pvp_crew:squadUpdate', src, nil)

    if #squad.members == 0 then
        squads[squadId] = nil
    elseif src == squad.leader then
        squad.leader = squad.members[1]
        broadcastSquadUpdate(squadId)
    else
        broadcastSquadUpdate(squadId)
    end
end

-- Créer un squad (le joueur qui invite en premier le crée)
local function ensureSquad(src)
    if playerSquad[src] then return playerSquad[src] end
    local id = nextSquadId
    nextSquadId = nextSquadId + 1
    squads[id] = { leader = src, members = { src } }
    playerSquad[src] = id
    return id
end

ESX.RegisterServerCallback('pvp_crew:squadInvite', function(src, cb, targetId)
    targetId = tonumber(targetId)
    if not targetId or targetId == src then cb(false, 'Cible invalide.') return end
    if not GetPlayerName(targetId) then cb(false, 'Joueur introuvable.') return end
    if playerSquad[targetId] then cb(false, 'Ce joueur est déjà dans un squad.') return end

    local squadId = ensureSquad(src)
    local squad = squads[squadId]

    if #squad.members >= Config.MaxSquadMembers then
        cb(false, 'Squad plein (' .. Config.MaxSquadMembers .. ' max).')
        return
    end

    squadInvites[targetId] = { from = src, squadId = squadId }
    TriggerClientEvent('pvp_crew:squadInviteReceived', targetId, {
        from = src,
        fromName = GetPlayerName(src)
    })
    cb(true, 'Invitation squad envoyée !')
    broadcastSquadUpdate(squadId)
end)

ESX.RegisterServerCallback('pvp_crew:squadAccept', function(src, cb)
    local invite = squadInvites[src]
    if not invite then cb(false, 'Pas d\'invitation.') return end
    if playerSquad[src] then cb(false, 'Vous êtes déjà dans un squad.') return end

    local squadId = invite.squadId
    local squad = squads[squadId]
    if not squad then cb(false, 'Squad dissous.') return end
    if #squad.members >= Config.MaxSquadMembers then cb(false, 'Squad plein.') return end

    squad.members[#squad.members+1] = src
    playerSquad[src] = squadId
    squadInvites[src] = nil
    cb(true, 'Vous avez rejoint le squad !')
    broadcastSquadUpdate(squadId)
end)

ESX.RegisterServerCallback('pvp_crew:squadDecline', function(src, cb)
    squadInvites[src] = nil
    cb(true, 'Invitation refusée.')
end)

ESX.RegisterServerCallback('pvp_crew:squadLeave', function(src, cb)
    if not playerSquad[src] then cb(false, 'Pas de squad.') return end
    removeFromSquad(src)
    cb(true, 'Vous avez quitté le squad.')
end)

ESX.RegisterServerCallback('pvp_crew:squadKick', function(src, cb, targetId)
    targetId = tonumber(targetId)
    local squadId = playerSquad[src]
    if not squadId then cb(false, 'Pas de squad.') return end
    local squad = squads[squadId]
    if squad.leader ~= src then cb(false, 'Seul le leader peut exclure.') return end
    if not playerSquad[targetId] or playerSquad[targetId] ~= squadId then
        cb(false, 'Ce joueur n\'est pas dans votre squad.')
        return
    end
    removeFromSquad(targetId)
    TriggerClientEvent('pvp_crew:notify', targetId, 'Vous avez été exclu du squad.')
    cb(true, 'Membre exclu du squad.')
end)

-- ── Nettoyage à la déconnexion ───────────────────────────────────────────
AddEventHandler('playerDropped', function()
    local src = source
    removeFromSquad(src)
    squadInvites[src] = nil
end)

-- ── Export pour friendly fire (utilisable par d'autres resources) ────────
exports('areInSameSquad', function(src1, src2)
    if not playerSquad[src1] then return false end
    return playerSquad[src1] == playerSquad[src2]
end)

exports('getPlayerCrewTag', function(src)
    local identifier = getIdentifier(src)
    if not identifier then return nil end
    local result = MySQL.Sync.fetchAll('SELECT c.tag FROM pvp_crews c JOIN pvp_crew_members m ON m.crew_id = c.id WHERE m.identifier = @id', {
        ['@id'] = identifier
    })
    if result and #result > 0 then return result[1].tag end
    return nil
end)

-- ── Export : multiplicateur d'XP courant pour un joueur (boutique de crew) ─
-- Appelé par vanta_xp (synchrone, même style que getPlayerCrewTag ci-dessus)
-- juste avant d'ajouter de l'XP : addXP() n'a pas de notion de callback async,
-- donc pvp_crew reste la seule source de vérité pour ses propres buffs mais
-- doit répondre immédiatement. sourceKind = 'zombie_kill' | 'player_kill'.
exports('getXPMultiplier', function(identifier, sourceKind)
    if not identifier or not sourceKind then return 1.0 end
    local ok, result = pcall(function()
        return MySQL.Sync.fetchAll('SELECT crew_id FROM pvp_crew_members WHERE identifier = @id', { ['@id'] = identifier })
    end)
    if not ok or not result or #result == 0 then return 1.0 end

    local crewId = result[1].crew_id
    local buffs = crewBuffsCache[crewId]
    if not buffs then return 1.0 end

    local now = os.time()
    local buffKey = (sourceKind == 'zombie_kill') and 'zombie_xp2'
        or (sourceKind == 'player_kill') and 'pvp_xp50'
        or nil
    if not buffKey then return 1.0 end

    local b = buffs[buffKey]
    if b and b.expiresAt > now and type(b.value) == 'number' and b.value > 0 then
        return b.value
    end
    return 1.0
end)

-- ── Charger le tag au login + réappliquer le bonus de conteneur de crew ────
-- (couvre le cas d'un membre qui se reconnecte pendant qu'un bonus
-- "Coffre protégé" acheté par son crew est toujours actif).
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(playerId)
    local src = source
    Citizen.Wait(2000) -- attendre que tout soit chargé
    local identifier = getIdentifier(src)
    if not identifier then return end
    MySQL.Async.fetchAll('SELECT c.id AS crew_id, c.tag FROM pvp_crews c JOIN pvp_crew_members m ON m.crew_id = c.id WHERE m.identifier = @id', {
        ['@id'] = identifier
    }, function(results)
        if results and #results > 0 then
            TriggerClientEvent('pvp_crew:updateTag', src, results[1].tag)

            local crewId = results[1].crew_id
            local buffs = crewBuffsCache[crewId]
            local buff = buffs and buffs.container_boost
            local bonus = (buff and buff.expiresAt > os.time()) and buff.value or 0
            pcall(function()
                exports['pvp_inventory']:setContainerBonus(identifier, bonus, 'crew')
            end)
        end
    end)
end)

-- ── Balayage périodique : expire les bonus de crew arrivés à échéance ──────
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(30000) -- 30s : assez réactif sans matraquer la BDD
        local now = os.time()
        for crewId, buffs in pairs(crewBuffsCache) do
            for key, b in pairs(buffs) do
                if b.expiresAt <= now then
                    buffs[key] = nil
                    if key == 'container_boost' then
                        applyCrewContainerBoost(crewId) -- réapplique avec bonus=0
                    end
                    local label = BUFF_LABELS[key] or key
                    addCrewActivity(crewId, 'shop', 'Bonus expiré : ' .. label .. '.')
                    notifyCrewMembers(crewId, 'Le bonus "' .. label .. '" est terminé.')
                end
            end
        end
    end
end)

print('[pvp_crew] Resource démarrée.')
