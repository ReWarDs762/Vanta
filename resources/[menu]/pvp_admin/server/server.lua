-- =============================================
--   PVP ADMIN — Serveur v2
--   Sécurité renforcée, logs, bans, permissions
-- =============================================

local ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- ══ État serveur ═══════════════════════════════════════════════════════════
local adminStates = {}   -- [src] = { noclip=bool, god=bool }
local recentLogs  = {}   -- cache des 50 derniers logs pour le panel
local MAX_LOGS    = 50

-- ══ Tables SQL ═════════════════════════════════════════════════════════════
AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end

    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `pvp_admin_bans` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `identifier` VARCHAR(60) NOT NULL,
            `player_name` VARCHAR(100) DEFAULT '',
            `admin_name` VARCHAR(100) DEFAULT '',
            `admin_identifier` VARCHAR(60) DEFAULT '',
            `reason` VARCHAR(255) DEFAULT 'Banni par un administrateur.',
            `duration` INT DEFAULT 0,
            `banned_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
            `expires_at` DATETIME DEFAULT NULL,
            `active` TINYINT(1) DEFAULT 1,
            INDEX(`identifier`),
            INDEX(`active`)
        )
    ]])

    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `pvp_admin_logs` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `admin_name` VARCHAR(100) DEFAULT '',
            `admin_identifier` VARCHAR(60) DEFAULT '',
            `action` VARCHAR(50) NOT NULL,
            `target_name` VARCHAR(100) DEFAULT '',
            `target_id` INT DEFAULT 0,
            `details` VARCHAR(500) DEFAULT '',
            `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
            INDEX(`created_at`)
        )
    ]])

    -- Charger les derniers logs en mémoire
    MySQL.Async.fetchAll(
        'SELECT admin_name, action, target_name, target_id, details, created_at FROM pvp_admin_logs ORDER BY id DESC LIMIT @lim',
        { ['@lim'] = MAX_LOGS },
        function(rows)
            if rows then
                recentLogs = {}
                for i = #rows, 1, -1 do
                    recentLogs[#recentLogs + 1] = rows[i]
                end
            end
        end
    )

    print('[pvp_admin] ^2Admin system v2 loaded — Permissions, Logs, Bans^0')
end)

-- ══ PERMISSIONS ════════════════════════════════════════════════════════════

local permissionCache = {}  -- [role] = { [perm] = true }

local function buildPermCache()
    permissionCache = {}
    -- Mod permissions
    permissionCache['mod'] = {}
    for _, p in ipairs(AdminConfig.RolePermissions.mod or {}) do
        permissionCache['mod'][p] = true
    end
    -- Admin = mod + admin
    permissionCache['admin'] = {}
    for k, v in pairs(permissionCache['mod']) do permissionCache['admin'][k] = v end
    for _, p in ipairs(AdminConfig.RolePermissions.admin or {}) do
        permissionCache['admin'][p] = true
    end
    -- Superadmin = tout
    permissionCache['superadmin'] = {}
    for k, v in pairs(permissionCache['admin']) do permissionCache['superadmin'][k] = v end
    for _, p in ipairs(AdminConfig.RolePermissions.superadmin or {}) do
        permissionCache['superadmin'][p] = true
    end
end
buildPermCache()

local function getAdminRole(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return nil end
    local group = xPlayer.getGroup()
    if group == 'superadmin' then return 'superadmin' end
    if group == 'admin' then return 'admin' end
    if group == 'mod' then return 'mod' end
    return nil
end

local function isStaff(src)
    return getAdminRole(src) ~= nil
end

local function hasPerm(src, perm)
    local role = getAdminRole(src)
    if not role then return false end
    if role == 'superadmin' then return true end  -- superadmin = tout
    return permissionCache[role] and permissionCache[role][perm] == true
end

local function denyAccess(src)
    TriggerClientEvent('chat:addMessage', src, { args = { '^1[ADMIN]', 'Accès refusé.' } })
end

local function adminMsg(src, msg)
    TriggerClientEvent('chat:addMessage', src, { args = { '^2[ADMIN]', msg } })
end

local function toast(src, msg, success)
    TriggerClientEvent('pvp_admin:toast', src, msg, success ~= false)
end

local function getXPlayer(src, targetId)
    local tid = tonumber(targetId)
    if not tid then
        toast(src, 'ID invalide.', false)
        return nil
    end
    local xTarget = ESX.GetPlayerFromId(tid)
    if not xTarget then
        toast(src, 'Joueur #' .. tid .. ' introuvable.', false)
        return nil
    end
    return xTarget, tid
end

-- ══ LOGGING ════════════════════════════════════════════════════════════════

local function logAction(src, action, targetName, targetId, details)
    local adminName = (src > 0) and (GetPlayerName(src) or 'Admin') or 'Console'
    local adminIdent = ''
    if src > 0 then
        local xP = ESX.GetPlayerFromId(src)
        if xP then adminIdent = xP.identifier or '' end
    end

    local entry = {
        admin_name  = adminName,
        action      = action,
        target_name = targetName or '',
        target_id   = targetId or 0,
        details     = details or '',
        created_at  = os.date('%Y-%m-%d %H:%M:%S'),
    }

    -- Ajouter au cache mémoire
    recentLogs[#recentLogs + 1] = entry
    if #recentLogs > MAX_LOGS then table.remove(recentLogs, 1) end

    -- Persister en DB
    MySQL.Async.execute(
        'INSERT INTO pvp_admin_logs (admin_name, admin_identifier, action, target_name, target_id, details) VALUES (@an, @ai, @act, @tn, @tid, @det)',
        {
            ['@an']  = adminName,
            ['@ai']  = adminIdent,
            ['@act'] = action,
            ['@tn']  = targetName or '',
            ['@tid'] = targetId or 0,
            ['@det'] = details or '',
        }
    )

    print(('[pvp_admin] %s: %s → %s #%s (%s)'):format(adminName, action, targetName or '', tostring(targetId or ''), details or ''))
end

-- ══ BAN SYSTEM ═════════════════════════════════════════════════════════════

-- Vérification au connect
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    deferrals.defer()
    deferrals.update('Vérification anti-ban...')

    local identifiers = GetPlayerIdentifiers(src)
    local checks = {}
    for _, ident in ipairs(identifiers) do
        checks[#checks + 1] = ident
    end

    Citizen.Wait(100)

    MySQL.Async.fetchAll(
        'SELECT reason, expires_at FROM pvp_admin_bans WHERE identifier IN (?) AND active = 1 AND (expires_at IS NULL OR expires_at > NOW()) LIMIT 1',
        { checks },
        function(rows)
            if rows and rows[1] then
                local ban = rows[1]
                local msg = '🚫 Vous êtes banni.\nRaison: ' .. (ban.reason or 'Non spécifiée')
                if ban.expires_at then
                    msg = msg .. '\nExpire: ' .. ban.expires_at
                else
                    msg = msg .. '\nDurée: Permanent'
                end
                deferrals.done(msg)
            else
                deferrals.done()
            end
        end
    )
end)

local function banPlayer(src, targetId, durationMinutes, reason)
    local tid = tonumber(targetId)
    if not tid then toast(src, 'ID invalide.', false) return end

    local targetName = GetPlayerName(tid) or 'Inconnu'
    local identifiers = GetPlayerIdentifiers(tid)
    if not identifiers or #identifiers == 0 then
        toast(src, 'Impossible de récupérer les identifiants.', false)
        return
    end

    local adminName = GetPlayerName(src) or 'Admin'
    local adminIdent = ''
    local xAdmin = ESX.GetPlayerFromId(src)
    if xAdmin then adminIdent = xAdmin.identifier or '' end

    local dur = tonumber(durationMinutes) or 0
    local expiresAt = nil
    local durLabel = 'Permanent'
    if dur > 0 then
        expiresAt = os.date('%Y-%m-%d %H:%M:%S', os.time() + dur * 60)
        if dur >= 1440 then
            durLabel = math.floor(dur / 1440) .. ' jour(s)'
        elseif dur >= 60 then
            durLabel = math.floor(dur / 60) .. ' heure(s)'
        else
            durLabel = dur .. ' minute(s)'
        end
    end

    reason = reason or 'Banni par un administrateur.'
    if reason == '' then reason = 'Banni par un administrateur.' end

    -- Insérer un ban par identifiant
    for _, ident in ipairs(identifiers) do
        MySQL.Async.execute(
            'INSERT INTO pvp_admin_bans (identifier, player_name, admin_name, admin_identifier, reason, duration, expires_at) VALUES (@id, @pn, @an, @ai, @r, @d, @e)',
            {
                ['@id'] = ident,
                ['@pn'] = targetName,
                ['@an'] = adminName,
                ['@ai'] = adminIdent,
                ['@r']  = reason,
                ['@d']  = dur,
                ['@e']  = expiresAt,
            }
        )
    end

    -- Kick immédiat
    DropPlayer(tid, '🚫 Banni: ' .. reason .. ' (' .. durLabel .. ')')

    logAction(src, 'ban', targetName, tid, durLabel .. ' — ' .. reason)
    toast(src, targetName .. ' banni (' .. durLabel .. ')')
    adminMsg(src, targetName .. ' banni pour ' .. durLabel .. ' — ' .. reason)
end

local function unbanPlayer(src, identifier)
    if not identifier or identifier == '' then
        toast(src, 'Identifiant requis.', false)
        return
    end
    -- Sécurité : match exact au lieu de LIKE wildcard pour éviter de déban tout le monde
    -- L'identifier doit correspondre au format FiveM (steam:xxx, license:xxx, etc.)
    if not identifier:match('^[a-zA-Z_]+:[a-fA-F0-9]+$') then
        toast(src, 'Format identifiant invalide (ex: steam:110000xxxxxxx)', false)
        return
    end
    MySQL.Async.execute(
        'UPDATE pvp_admin_bans SET active = 0 WHERE identifier = @id AND active = 1',
        { ['@id'] = identifier },
        function(affected)
            if affected and affected > 0 then
                logAction(src, 'unban', identifier, 0, 'Débanni')
                toast(src, identifier .. ' débanni.')
            else
                toast(src, 'Aucun ban actif trouvé pour cet identifiant.', false)
            end
        end
    )
end

-- ══ Données pour le panel NUI ════════════════════════════════════════════
ESX.RegisterServerCallback('pvp_admin:getData', function(src, cb)
    local role = getAdminRole(src)
    if not role then cb(nil) return end

    -- Joueurs en ligne
    local players = {}
    for _, xp in pairs(ESX.GetPlayers()) do
        local xPlayer = ESX.GetPlayerFromId(xp)
        if xPlayer then
            local name = ''
            local fn = xPlayer.get('firstName')
            local ln = xPlayer.get('lastName')
            if fn and fn ~= '' then name = fn .. ' ' .. (ln or '') end
            if name == '' or name == ' ' then name = GetPlayerName(xp) or 'Joueur' end
            players[#players + 1] = {
                id       = xp,
                name     = name:gsub('^%s+',''):gsub('%s+$',''),
                group    = xPlayer.getGroup(),
                ping     = GetPlayerPing(xp),
                health   = GetEntityHealth(GetPlayerPed(xp)),
                armor    = GetPedArmour(GetPlayerPed(xp)),
            }
        end
    end

    -- Redzones actives
    local redzones = {}
    local okRz, rzData = pcall(function()
        return exports['pvp_redzones']:getActiveZones()
    end)
    if okRz and rzData then redzones = rzData end

    -- État admin de celui qui demande
    local state = adminStates[src] or { noclip = false, god = false }

    cb({
        players    = players,
        redzones   = redzones,
        role       = role,
        state      = state,
        logs       = recentLogs,
        autoRefresh = AdminConfig.AutoRefreshMs,
    })
end)

-- ══ Détails d'un joueur ════════════════════════════════════════════════════
ESX.RegisterServerCallback('pvp_admin:getPlayerDetail', function(src, cb, targetId)
    if not isStaff(src) then cb(nil) return end
    local tid = tonumber(targetId)
    if not tid then cb(nil) return end

    local xTarget = ESX.GetPlayerFromId(tid)
    if not xTarget then cb(nil) return end

    local identifiers = GetPlayerIdentifiers(tid)
    local identStr = table.concat(identifiers or {}, ', ')

    -- Inventaire
    local inventory = {}
    for _, item in ipairs(xTarget.getInventory()) do
        if item.count > 0 then
            inventory[#inventory + 1] = { name = item.name, label = item.label, count = item.count }
        end
    end

    -- Stats depuis la DB
    MySQL.Async.fetchAll(
        'SELECT kills, deaths, zombies_killed, kill_streak_record, xp, prestige FROM pvp_player_stats WHERE identifier = @id LIMIT 1',
        { ['@id'] = xTarget.identifier },
        function(rows)
            local stats = rows and rows[1] or {}
            cb({
                id          = tid,
                name        = GetPlayerName(tid) or 'Joueur',
                group       = xTarget.getGroup(),
                identifier  = xTarget.identifier,
                identifiers = identStr,
                ping        = GetPlayerPing(tid),
                health      = GetEntityHealth(GetPlayerPed(tid)),
                armor       = GetPedArmour(GetPlayerPed(tid)),
                bank        = xTarget.getAccount('bank').money,
                inventory   = inventory,
                kills       = stats.kills or 0,
                deaths      = stats.deaths or 0,
                zombies     = stats.zombies_killed or 0,
                streak      = stats.kill_streak_record or 0,
                xp          = stats.xp or 0,
                prestige    = stats.prestige or 0,
            })
        end
    )
end)

-- ══ Stash admin — Voir/modifier inventaire, coffre protégé, coffre avant-poste ═

ESX.RegisterServerCallback('pvp_admin:getPlayerStorage', function(src, cb, targetId, storageType)
    if not isStaff(src) then cb(nil) return end
    local tid = tonumber(targetId)
    if not tid then cb(nil) return end

    local xTarget = ESX.GetPlayerFromId(tid)
    if not xTarget then cb(nil) return end

    local targetName = GetPlayerName(tid) or 'Joueur'
    local identifier = xTarget.identifier

    if storageType == 'inventory' then
        -- Inventaire ESX (sac)
        local items = {}
        for _, item in ipairs(xTarget.getInventory()) do
            if item.count > 0 then
                items[#items + 1] = { name = item.name, label = item.label, count = item.count }
            end
        end
        cb({ items = items, targetName = targetName, targetId = tid, storageType = 'inventory', storageLabel = 'INVENTAIRE (SAC)' })

    elseif storageType == 'stash' then
        -- Coffre protégé (pvp_player_stash)
        MySQL.Async.fetchAll(
            'SELECT item, label, `count` FROM pvp_player_stash WHERE identifier = @id AND `count` > 0',
            { ['@id'] = identifier },
            function(rows)
                local items = {}
                for _, r in ipairs(rows or {}) do
                    items[#items + 1] = { name = r.item, label = r.label, count = r['count'] }
                end
                cb({ items = items, targetName = targetName, targetId = tid, storageType = 'stash', storageLabel = 'COFFRE PROTEGE' })
            end
        )

    elseif storageType == 'outpost' then
        -- Coffre avant-poste (pvp_outpost_stash, outpost_id = 'global')
        MySQL.Async.fetchAll(
            'SELECT item, label, `count` FROM pvp_outpost_stash WHERE identifier = @id AND outpost_id = @op AND `count` > 0',
            { ['@id'] = identifier, ['@op'] = 'global' },
            function(rows)
                local items = {}
                for _, r in ipairs(rows or {}) do
                    items[#items + 1] = { name = r.item, label = r.label, count = r['count'] }
                end
                cb({ items = items, targetName = targetName, targetId = tid, storageType = 'outpost', storageLabel = 'COFFRE AVANT-POSTE' })
            end
        )
    else
        cb(nil)
    end
end)

-- Admin : retirer un item du stockage d'un joueur
RegisterNetEvent('pvp_admin:removeFromStorage')
AddEventHandler('pvp_admin:removeFromStorage', function(targetId, storageType, itemName, qty)
    local src = source
    if not hasPerm(src, 'clearinv') then toast(src, 'Permission refusée.', false) return end

    local tid = tonumber(targetId)
    if not tid then return end
    local xTarget = ESX.GetPlayerFromId(tid)
    if not xTarget then toast(src, 'Joueur introuvable.', false) return end

    local identifier = xTarget.identifier
    local amount = tonumber(qty) or 1
    local targetName = GetPlayerName(tid) or 'Joueur'

    if storageType == 'inventory' then
        xTarget.removeInventoryItem(itemName, amount)
        logAction(src, 'admin_remove_inv', targetName, tid, itemName .. ' x' .. amount)
        toast(src, itemName .. ' x' .. amount .. ' retiré du sac de ' .. targetName)

    elseif storageType == 'stash' then
        MySQL.Async.fetchAll(
            'SELECT `count` FROM pvp_player_stash WHERE identifier = @id AND item = @item',
            { ['@id'] = identifier, ['@item'] = itemName },
            function(rows)
                if not rows or not rows[1] then toast(src, 'Item introuvable.', false) return end
                local current = rows[1]['count']
                if amount >= current then
                    MySQL.Async.execute('DELETE FROM pvp_player_stash WHERE identifier = @id AND item = @item',
                        { ['@id'] = identifier, ['@item'] = itemName })
                else
                    MySQL.Async.execute('UPDATE pvp_player_stash SET `count` = `count` - @qty WHERE identifier = @id AND item = @item',
                        { ['@id'] = identifier, ['@item'] = itemName, ['@qty'] = amount })
                end
                logAction(src, 'admin_remove_stash', targetName, tid, itemName .. ' x' .. amount)
                toast(src, itemName .. ' x' .. amount .. ' retiré du coffre de ' .. targetName)
            end
        )

    elseif storageType == 'outpost' then
        MySQL.Async.fetchAll(
            'SELECT `count` FROM pvp_outpost_stash WHERE identifier = @id AND outpost_id = @op AND item = @item',
            { ['@id'] = identifier, ['@op'] = 'global', ['@item'] = itemName },
            function(rows)
                if not rows or not rows[1] then toast(src, 'Item introuvable.', false) return end
                local current = rows[1]['count']
                if amount >= current then
                    MySQL.Async.execute('DELETE FROM pvp_outpost_stash WHERE identifier = @id AND outpost_id = @op AND item = @item',
                        { ['@id'] = identifier, ['@op'] = 'global', ['@item'] = itemName })
                else
                    MySQL.Async.execute('UPDATE pvp_outpost_stash SET `count` = `count` - @qty WHERE identifier = @id AND outpost_id = @op AND item = @item',
                        { ['@id'] = identifier, ['@op'] = 'global', ['@item'] = itemName, ['@qty'] = amount })
                end
                logAction(src, 'admin_remove_outpost', targetName, tid, itemName .. ' x' .. amount)
                toast(src, itemName .. ' x' .. amount .. ' retiré du coffre avant-poste de ' .. targetName)
            end
        )
    end
end)

-- Admin : ajouter un item dans le stockage d'un joueur
local VALID_STORAGE_TYPES = { inventory = true, stash = true, outpost = true }

RegisterNetEvent('pvp_admin:addToStorage')
AddEventHandler('pvp_admin:addToStorage', function(targetId, storageType, itemName, qty)
    local src = source
    if not hasPerm(src, 'give') then toast(src, 'Permission refusée.', false) return end

    -- Whitelist du type de stockage
    if type(storageType) ~= 'string' or not VALID_STORAGE_TYPES[storageType] then
        toast(src, 'Type de stockage invalide.', false)
        return
    end

    -- Validation du nom d'item
    if type(itemName) ~= 'string' or itemName == '' or not itemName:match('^[a-z0-9_]+$') then
        toast(src, 'Nom d\'item invalide.', false)
        return
    end

    local tid = tonumber(targetId)
    if not tid then return end
    local xTarget = ESX.GetPlayerFromId(tid)
    if not xTarget then toast(src, 'Joueur introuvable.', false) return end

    local identifier = xTarget.identifier
    local amount = tonumber(qty) or 1
    local targetName = GetPlayerName(tid) or 'Joueur'

    -- Récupérer le label de l'item
    local itemLabel = itemName
    local esxItem = ESX.GetItem and ESX.GetItem(itemName) or nil
    if esxItem and esxItem.label then itemLabel = esxItem.label end

    if storageType == 'inventory' then
        xTarget.addInventoryItem(itemName, amount)
        logAction(src, 'admin_add_inv', targetName, tid, itemName .. ' x' .. amount)
        toast(src, itemName .. ' x' .. amount .. ' ajouté au sac de ' .. targetName)

    elseif storageType == 'stash' then
        MySQL.Async.execute(
            'INSERT INTO pvp_player_stash (identifier, item, label, `count`) VALUES (@id, @item, @label, @qty) ON DUPLICATE KEY UPDATE `count` = `count` + @qty',
            { ['@id'] = identifier, ['@item'] = itemName, ['@label'] = itemLabel, ['@qty'] = amount }
        )
        logAction(src, 'admin_add_stash', targetName, tid, itemName .. ' x' .. amount)
        toast(src, itemName .. ' x' .. amount .. ' ajouté au coffre de ' .. targetName)

    elseif storageType == 'outpost' then
        MySQL.Async.execute(
            'INSERT INTO pvp_outpost_stash (identifier, outpost_id, item, label, `count`) VALUES (@id, @op, @item, @label, @qty) ON DUPLICATE KEY UPDATE `count` = `count` + @qty',
            { ['@id'] = identifier, ['@op'] = 'global', ['@item'] = itemName, ['@label'] = itemLabel, ['@qty'] = amount }
        )
        logAction(src, 'admin_add_outpost', targetName, tid, itemName .. ' x' .. amount)
        toast(src, itemName .. ' x' .. amount .. ' ajouté au coffre avant-poste de ' .. targetName)
    end
end)

-- ══ Actions sécurisées depuis le panel NUI ═════════════════════════════════

-- Whitelist des actions valides depuis le panel NUI
local VALID_ACTIONS = {
    kick=true, ban=true, unban=true, heal=true, revive=true, slay=true,
    freeze=true, bring=true, ['goto']=true, spectate=true,
    give=true, givemoney=true, givexp=true, clearinv=true,
    announce=true, forcedrop=true, rzrotate=true,
    setweather=true, settime=true, killzombies=true, spawnzombies=true,
    noclip=true, god=true, spawncar=true, deletecar=true, tpwp=true,
}

RegisterNetEvent('pvp_admin:action')
AddEventHandler('pvp_admin:action', function(action, data)
    local src = source
    if not isStaff(src) then return end

    -- Valider que l'action est dans la whitelist
    if type(action) ~= 'string' or not VALID_ACTIONS[action] then
        print(('[pvp_admin] BLOCKED: joueur %d a envoyé une action invalide: %s'):format(src, tostring(action)))
        return
    end

    -- Valider que data est une table
    if type(data) ~= 'table' then data = {} end

    -- Vérifier la permission pour cette action
    if not hasPerm(src, action) then
        toast(src, 'Permission refusée pour: ' .. action, false)
        return
    end

    local targetName = ''
    if data.id then
        targetName = GetPlayerName(tonumber(data.id)) or ('Joueur #' .. tostring(data.id))
    end

    -- ── ACTIONS JOUEURS ──────────────────────────────────────────────────

    if action == 'kick' then
        local tid = tonumber(data.id)
        if tid then
            local reason = data.reason or 'Exclu par un administrateur.'
            if reason == '' then reason = 'Exclu par un administrateur.' end
            DropPlayer(tid, reason)
            logAction(src, 'kick', targetName, tid, reason)
            toast(src, targetName .. ' expulsé.')
        end

    elseif action == 'ban' then
        -- Validation durée : nombre positif, max 1 an (525600 min)
        local duration = tonumber(data.duration) or 0
        if duration < 0 then duration = 0 end
        if duration > 525600 then duration = 525600 end
        -- Validation raison : string non vide
        local reason = type(data.reason) == 'string' and data.reason or ''
        banPlayer(src, data.id, duration, reason)

    elseif action == 'unban' then
        unbanPlayer(src, data.identifier)

    elseif action == 'heal' then
        local tid = tonumber(data.id)
        if tid then
            TriggerClientEvent('pvp_admin:heal', tid)
            logAction(src, 'heal', targetName, tid)
            toast(src, targetName .. ' soigné.')
        end

    elseif action == 'revive' then
        local tid = tonumber(data.id)
        if tid then
            TriggerClientEvent('pvp_admin:revive', tid)
            logAction(src, 'revive', targetName, tid)
            toast(src, targetName .. ' réanimé.')
        end

    elseif action == 'slay' then
        local tid = tonumber(data.id)
        if tid then
            TriggerClientEvent('pvp_admin:slay', tid)
            logAction(src, 'slay', targetName, tid)
            toast(src, targetName .. ' tué.')
        end

    elseif action == 'freeze' then
        local tid = tonumber(data.id)
        if tid then
            TriggerClientEvent('pvp_admin:freeze', tid)
            logAction(src, 'freeze', targetName, tid)
            toast(src, targetName .. ' freeze toggle.')
        end

    elseif action == 'bring' then
        local tid = tonumber(data.id)
        if tid then
            local adminPed = GetPlayerPed(src)
            if not adminPed or adminPed == 0 then
                toast(src, 'Erreur : ped admin invalide.', false)
            else
                local coords = GetEntityCoords(adminPed)
                TriggerClientEvent('pvp_admin:teleport', tid, coords.x, coords.y, coords.z)
                logAction(src, 'bring', targetName, tid)
                toast(src, targetName .. ' téléporté à toi.')
            end
        end

    elseif action == 'goto' then
        local tid = tonumber(data.id)
        if tid then
            local targetPed = GetPlayerPed(tid)
            if not targetPed or targetPed == 0 then
                toast(src, 'Erreur : joueur cible introuvable.', false)
            else
                local coords = GetEntityCoords(targetPed)
                TriggerClientEvent('pvp_admin:teleport', src, coords.x, coords.y, coords.z)
                logAction(src, 'goto', targetName, tid)
                toast(src, 'Téléporté à ' .. targetName)
            end
        end

    elseif action == 'spectate' then
        local tid = tonumber(data.id)
        if tid and tid ~= src then
            TriggerClientEvent('pvp_admin:startSpec', src, tid)
            logAction(src, 'spectate', targetName, tid)
            toast(src, 'Spectate ' .. targetName)
        end

    -- ── ITEMS / ARGENT ──────────────────────────────────────────────────

    elseif action == 'give' then
        local xTarget, tid = getXPlayer(src, data.id)
        if xTarget then
            local qty = tonumber(data.qty) or 1
            xTarget.addInventoryItem(data.item, qty)
            logAction(src, 'give', targetName, tid, data.item .. ' x' .. qty)
            toast(src, data.item .. ' x' .. qty .. ' donné à ' .. targetName)
        end

    elseif action == 'givemoney' then
        local xTarget, tid = getXPlayer(src, data.id)
        if xTarget then
            local amount = math.floor(tonumber(data.amount) or 0)
            -- SÉCURITÉ : bornes pour éviter overflow/exploit
            if amount < 1 or amount > 100000000 then
                adminMsg(src, 'Montant invalide (1 - 100M)')
            else
                xTarget.addAccountMoney('bank', amount)
                logAction(src, 'givemoney', targetName, tid, '$' .. amount)
                toast(src, '$' .. amount .. ' donné à ' .. targetName)
            end
        end

    elseif action == 'givexp' then
        local xTarget, tid = getXPlayer(src, data.id)
        if xTarget then
            local amount = math.floor(tonumber(data.amount) or 0)
            if amount < 1 or amount > 10000000 then
                adminMsg(src, 'Montant XP invalide (1 - 10M)')
            else
                TriggerEvent('pvp_admin:awardXP', xTarget.identifier, amount)
                logAction(src, 'givexp', targetName, tid, amount .. ' XP')
                toast(src, amount .. ' XP donné à ' .. targetName)
            end
        end

    elseif action == 'clearinv' then
        local xTarget, tid = getXPlayer(src, data.id)
        if xTarget then
            for _, item in ipairs(xTarget.getInventory()) do
                if item.count > 0 then
                    xTarget.removeInventoryItem(item.name, item.count)
                end
            end
            logAction(src, 'clearinv', targetName, tid)
            toast(src, 'Inventaire de ' .. targetName .. ' vidé.')
        end

    -- ── SERVEUR ─────────────────────────────────────────────────────────

    elseif action == 'announce' then
        local msg = data.msg or ''
        if msg ~= '' then
            TriggerClientEvent('chat:addMessage', -1, {
                args = { '^1[ANNONCE]', msg }
            })
            logAction(src, 'announce', '', 0, msg)
            toast(src, 'Annonce envoyée.')
        end

    elseif action == 'forcedrop' then
        TriggerEvent('pvp_drops:forceStart')
        logAction(src, 'forcedrop', '', 0)
        toast(src, 'Drop de ravitaillement lancé !')

    elseif action == 'rzrotate' then
        TriggerEvent('pvp_redzones:forceRotate')
        logAction(src, 'rzrotate', '', 0)
        toast(src, 'Rotation des redzones forcée !')

    elseif action == 'setweather' then
        local w = data.weather or 'CLEAR'
        TriggerClientEvent('pvp_admin:setWeather', -1, w)
        logAction(src, 'setweather', '', 0, w)
        toast(src, 'Météo : ' .. w)

    elseif action == 'settime' then
        local h = tonumber(data.hour) or 12
        TriggerClientEvent('pvp_admin:setTime', -1, h)
        logAction(src, 'settime', '', 0, h .. 'h')
        toast(src, 'Heure : ' .. h .. 'h')

    elseif action == 'killzombies' then
        TriggerClientEvent('pvp_admin:killZombies', src)
        logAction(src, 'killzombies', '', 0)
        toast(src, 'Zombies à proximité éliminés.')

    elseif action == 'spawnzombies' then
        local count = math.min(tonumber(data.count) or 5, 30)
        TriggerClientEvent('pvp_zombies:forceSpawn', src, count)
        logAction(src, 'spawnzombies', '', 0, count .. ' zombies')
        toast(src, count .. ' zombies spawnés.')

    -- ── OUTILS ADMIN (noclip, god, car) ─────────────────────────────────

    elseif action == 'noclip' then
        if not adminStates[src] then adminStates[src] = { noclip = false, god = false } end
        adminStates[src].noclip = not adminStates[src].noclip
        TriggerClientEvent('pvp_admin:noclipConfirmed', src, adminStates[src].noclip)
        logAction(src, 'noclip', '', 0, adminStates[src].noclip and 'ON' or 'OFF')
        toast(src, 'Noclip ' .. (adminStates[src].noclip and 'activé' or 'désactivé'))

    elseif action == 'god' then
        if not adminStates[src] then adminStates[src] = { noclip = false, god = false } end
        adminStates[src].god = not adminStates[src].god
        TriggerClientEvent('pvp_admin:godConfirmed', src, adminStates[src].god)
        logAction(src, 'god', '', 0, adminStates[src].god and 'ON' or 'OFF')
        toast(src, 'God mode ' .. (adminStates[src].god and 'activé' or 'désactivé'))

    elseif action == 'spawncar' then
        local model = data.model or ''
        if model ~= '' then
            TriggerClientEvent('pvp_admin:spawnCarConfirmed', src, model)
            logAction(src, 'spawncar', '', 0, model)
            toast(src, model .. ' spawné.')
        end

    elseif action == 'deletecar' then
        TriggerClientEvent('pvp_admin:deleteCarConfirmed', src)
        logAction(src, 'deletecar', '', 0)
        toast(src, 'Véhicule supprimé.')

    elseif action == 'tpwp' then
        TriggerClientEvent('pvp_admin:tpwpConfirmed', src)
        logAction(src, 'tpwp', '', 0)
    end
end)

-- ══ XP admin (relais vers pvp_inventory) ═════════════════════════════════
AddEventHandler('pvp_admin:awardXP', function(identifier, amount)
    if not identifier or not amount or amount <= 0 then return end
    MySQL.Async.execute(
        'UPDATE pvp_player_stats SET xp = xp + @xp WHERE identifier = @id',
        { ['@id'] = identifier, ['@xp'] = amount }
    )
end)

-- ══ Force drop (relais vers pvp_drops) ═══════════════════════════════════
AddEventHandler('pvp_drops:adminForceDrop', function()
    TriggerEvent('pvp_drops:forceStart')
end)

-- ══ Force rotation redzones (relais vers pvp_redzones) ═══════════════════
AddEventHandler('pvp_redzones:adminForceRotation', function()
    TriggerEvent('pvp_redzones:forceRotate')
end)

-- ══ Nettoyage quand un admin quitte ════════════════════════════════════════
AddEventHandler('playerDropped', function()
    local src = source
    adminStates[src] = nil
end)

-- ══ Commandes chat ═══════════════════════════════════════════════════════

RegisterCommand('ahelp', function(src)
    if src == 0 or not isStaff(src) then return end
    local cmds = {
        '/noclip — Noclip amélioré (SHIFT=rapide, CTRL=lent)',
        '/god — Mode invincible',
        '/spec [id] — Spectater un joueur (sans id = quitter)',
        '/tp [id] — Téléporter au joueur',
        '/bring [id] — Téléporter le joueur à toi',
        '/tpwp — Téléporter au waypoint',
        '/tpc [x] [y] [z] — Téléporter aux coordonnées',
        '/car [modèle] — Spawn un véhicule',
        '/dv — Supprimer le véhicule actuel',
        '/heal [id] — Soigner un joueur',
        '/revive [id] — Réanimer un joueur',
        '/slay [id] — Tuer un joueur',
        '/kick [id] [raison] — Expulser',
        '/ban [id] [minutes] [raison] — Bannir (0 = permanent)',
        '/unban [identifier] — Débannir',
        '/give [id] [item] [qty] — Donner un item',
        '/givemoney [id] [montant] — Donner de l\'argent',
        '/givexp [id] [montant] — Donner de l\'XP',
        '/clearinv [id] — Vider l\'inventaire',
        '/drop — Forcer un drop de ravitaillement',
        '/rzrotate — Forcer la rotation des redzones',
        '/killzombies — Tuer les zombies proches',
        '/spawnzombies [n] — Spawn N zombies',
        '/weather [type] — Changer la météo',
        '/time [h] — Changer l\'heure',
        '/announce [msg] — Annonce serveur',
        'F7 — Panel admin complet',
    }
    for _, c in ipairs(cmds) do adminMsg(src, c) end
end, false)

RegisterCommand('tp', function(src, args)
    if src == 0 or not hasPerm(src, 'goto') then if src > 0 then denyAccess(src) end return end
    local tid = tonumber(args[1])
    if not tid then adminMsg(src, 'Usage: /tp [id]') return end
    local targetPed = GetPlayerPed(tid)
    if not targetPed or targetPed == 0 then adminMsg(src, 'Joueur introuvable.') return end
    local c = GetEntityCoords(targetPed)
    TriggerClientEvent('pvp_admin:teleport', src, c.x, c.y, c.z)
    logAction(src, 'goto', GetPlayerName(tid) or '', tid)
    adminMsg(src, 'Téléporté au joueur #' .. tid)
end, false)

RegisterCommand('bring', function(src, args)
    if src == 0 or not hasPerm(src, 'bring') then if src > 0 then denyAccess(src) end return end
    local tid = tonumber(args[1])
    if not tid then adminMsg(src, 'Usage: /bring [id]') return end
    local adminPed = GetPlayerPed(src)
    local c = GetEntityCoords(adminPed)
    TriggerClientEvent('pvp_admin:teleport', tid, c.x, c.y, c.z)
    logAction(src, 'bring', GetPlayerName(tid) or '', tid)
    adminMsg(src, 'Joueur #' .. tid .. ' téléporté à toi.')
end, false)

RegisterCommand('tpc', function(src, args)
    if src == 0 or not hasPerm(src, 'tpwp') then if src > 0 then denyAccess(src) end return end
    local x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
    if not x or not y or not z then adminMsg(src, 'Usage: /tpc [x] [y] [z]') return end
    TriggerClientEvent('pvp_admin:teleport', src, x, y, z)
    logAction(src, 'tpc', '', 0, x .. ', ' .. y .. ', ' .. z)
    adminMsg(src, 'Téléporté à ' .. x .. ', ' .. y .. ', ' .. z)
end, false)

RegisterCommand('heal', function(src, args)
    if src == 0 or not hasPerm(src, 'heal') then if src > 0 then denyAccess(src) end return end
    local tid = tonumber(args[1]) or src
    TriggerClientEvent('pvp_admin:heal', tid)
    logAction(src, 'heal', GetPlayerName(tid) or '', tid)
    adminMsg(src, 'Joueur #' .. tid .. ' soigné.')
end, false)

RegisterCommand('revive', function(src, args)
    if src == 0 or not hasPerm(src, 'revive') then if src > 0 then denyAccess(src) end return end
    local tid = tonumber(args[1]) or src
    TriggerClientEvent('pvp_admin:revive', tid)
    logAction(src, 'revive', GetPlayerName(tid) or '', tid)
    adminMsg(src, 'Joueur #' .. tid .. ' réanimé.')
end, false)

RegisterCommand('slay', function(src, args)
    if src == 0 or not hasPerm(src, 'slay') then if src > 0 then denyAccess(src) end return end
    local tid = tonumber(args[1])
    if not tid then adminMsg(src, 'Usage: /slay [id]') return end
    TriggerClientEvent('pvp_admin:slay', tid)
    logAction(src, 'slay', GetPlayerName(tid) or '', tid)
    adminMsg(src, 'Joueur #' .. tid .. ' tué.')
end, false)

RegisterCommand('kick', function(src, args)
    if src == 0 or not hasPerm(src, 'kick') then if src > 0 then denyAccess(src) end return end
    local tid = tonumber(args[1])
    if not tid then adminMsg(src, 'Usage: /kick [id] [raison]') return end
    local reason = table.concat(args, ' ', 2) or 'Exclu par un admin.'
    if reason == '' then reason = 'Exclu par un admin.' end
    DropPlayer(tid, reason)
    logAction(src, 'kick', GetPlayerName(tid) or '', tid, reason)
    adminMsg(src, 'Joueur #' .. tid .. ' expulsé.')
end, false)

RegisterCommand('ban', function(src, args)
    if src == 0 or not hasPerm(src, 'ban') then if src > 0 then denyAccess(src) end return end
    local tid = tonumber(args[1])
    local dur = tonumber(args[2])
    if not tid then adminMsg(src, 'Usage: /ban [id] [minutes] [raison] (0 = permanent)') return end
    if not dur then dur = 0 end
    local reason = table.concat(args, ' ', 3) or 'Banni par un administrateur.'
    if reason == '' then reason = 'Banni par un administrateur.' end
    banPlayer(src, tid, dur, reason)
end, false)

RegisterCommand('unban', function(src, args)
    if src == 0 or not hasPerm(src, 'unban') then if src > 0 then denyAccess(src) end return end
    local ident = args[1]
    if not ident then adminMsg(src, 'Usage: /unban [identifier]') return end
    unbanPlayer(src, ident)
end, false)

RegisterCommand('give', function(src, args)
    if src == 0 or not hasPerm(src, 'give') then if src > 0 then denyAccess(src) end return end
    local tid = tonumber(args[1])
    local item = args[2]
    local qty = tonumber(args[3]) or 1
    if not tid or not item then adminMsg(src, 'Usage: /give [id] [item] [qty]') return end
    local xTarget = ESX.GetPlayerFromId(tid)
    if not xTarget then adminMsg(src, 'Joueur introuvable.') return end
    xTarget.addInventoryItem(item, qty)
    logAction(src, 'give', GetPlayerName(tid) or '', tid, item .. ' x' .. qty)
    adminMsg(src, item .. ' x' .. qty .. ' donné à #' .. tid)
end, false)

RegisterCommand('givemoney', function(src, args)
    if src == 0 or not hasPerm(src, 'givemoney') then if src > 0 then denyAccess(src) end return end
    local tid = tonumber(args[1])
    local amount = tonumber(args[2])
    if not tid or not amount then adminMsg(src, 'Usage: /givemoney [id] [montant]') return end
    amount = math.floor(amount)
    if amount < 1 or amount > 100000000 then adminMsg(src, 'Montant invalide (1 - 100M)') return end
    local xTarget = ESX.GetPlayerFromId(tid)
    if not xTarget then adminMsg(src, 'Joueur introuvable.') return end
    xTarget.addAccountMoney('bank', amount)
    logAction(src, 'givemoney', GetPlayerName(tid) or '', tid, '$' .. amount)
    adminMsg(src, '$' .. amount .. ' donné à #' .. tid)
end, false)

RegisterCommand('givexp', function(src, args)
    if src == 0 or not hasPerm(src, 'givexp') then if src > 0 then denyAccess(src) end return end
    local tid = tonumber(args[1])
    local amount = tonumber(args[2])
    if not tid or not amount then adminMsg(src, 'Usage: /givexp [id] [montant]') return end
    amount = math.floor(amount)
    if amount < 1 or amount > 10000000 then adminMsg(src, 'Montant XP invalide (1 - 10M)') return end
    local xTarget = ESX.GetPlayerFromId(tid)
    if not xTarget then adminMsg(src, 'Joueur introuvable.') return end
    TriggerEvent('pvp_admin:awardXP', xTarget.identifier, amount)
    logAction(src, 'givexp', GetPlayerName(tid) or '', tid, amount .. ' XP')
    adminMsg(src, amount .. ' XP donné à #' .. tid)
end, false)

RegisterCommand('clearinv', function(src, args)
    if src == 0 or not hasPerm(src, 'clearinv') then if src > 0 then denyAccess(src) end return end
    local tid = tonumber(args[1])
    if not tid then adminMsg(src, 'Usage: /clearinv [id]') return end
    local xTarget = ESX.GetPlayerFromId(tid)
    if not xTarget then adminMsg(src, 'Joueur introuvable.') return end
    for _, item in ipairs(xTarget.getInventory()) do
        if item.count > 0 then xTarget.removeInventoryItem(item.name, item.count) end
    end
    logAction(src, 'clearinv', GetPlayerName(tid) or '', tid)
    adminMsg(src, 'Inventaire de #' .. tid .. ' vidé.')
end, false)

RegisterCommand('drop', function(src)
    if src == 0 or not hasPerm(src, 'forcedrop') then if src > 0 then denyAccess(src) end return end
    TriggerEvent('pvp_drops:forceStart')
    logAction(src, 'forcedrop', '', 0)
    adminMsg(src, 'Drop de ravitaillement lancé !')
end, false)

RegisterCommand('rzrotate', function(src)
    if src == 0 or not hasPerm(src, 'rzrotate') then if src > 0 then denyAccess(src) end return end
    TriggerEvent('pvp_redzones:forceRotate')
    logAction(src, 'rzrotate', '', 0)
    adminMsg(src, 'Rotation des redzones forcée !')
end, false)

RegisterCommand('rzlist', function(src)
    if src == 0 or not isStaff(src) then return end
    local ok, zones = pcall(function() return exports['pvp_redzones']:getActiveZones() end)
    if ok and zones then
        adminMsg(src, '--- Redzones actives ---')
        for i, z in ipairs(zones) do
            adminMsg(src, '#' .. i .. ' : ' .. (z.label or '?') .. ' (' .. math.floor(z.coords and z.coords.x or 0) .. ', ' .. math.floor(z.coords and z.coords.y or 0) .. ')')
        end
    else
        adminMsg(src, 'Impossible de récupérer les redzones.')
    end
end, false)

RegisterCommand('killzombies', function(src)
    if src == 0 or not hasPerm(src, 'killzombies') then if src > 0 then denyAccess(src) end return end
    TriggerClientEvent('pvp_admin:killZombies', src)
    logAction(src, 'killzombies', '', 0)
    adminMsg(src, 'Zombies proches éliminés.')
end, false)

RegisterCommand('spawnzombies', function(src, args)
    if src == 0 or not hasPerm(src, 'spawnzombies') then if src > 0 then denyAccess(src) end return end
    local count = math.min(tonumber(args[1]) or 5, 30)
    TriggerClientEvent('pvp_zombies:forceSpawn', src, count)
    logAction(src, 'spawnzombies', '', 0, count .. ' zombies')
    adminMsg(src, count .. ' zombies spawnés.')
end, false)

RegisterCommand('weather', function(src, args)
    if src == 0 or not hasPerm(src, 'setweather') then if src > 0 then denyAccess(src) end return end
    local w = (args[1] or 'CLEAR'):upper()
    TriggerClientEvent('pvp_admin:setWeather', -1, w)
    logAction(src, 'setweather', '', 0, w)
    adminMsg(src, 'Météo : ' .. w)
end, false)

RegisterCommand('time', function(src, args)
    if src == 0 or not hasPerm(src, 'settime') then if src > 0 then denyAccess(src) end return end
    local h = tonumber(args[1]) or 12
    TriggerClientEvent('pvp_admin:setTime', -1, h)
    logAction(src, 'settime', '', 0, h .. 'h')
    adminMsg(src, 'Heure : ' .. h .. 'h')
end, false)

RegisterCommand('announce', function(src, args)
    if src == 0 or not hasPerm(src, 'announce') then if src > 0 then denyAccess(src) end return end
    local msg = table.concat(args, ' ')
    if msg == '' then adminMsg(src, 'Usage: /announce [message]') return end
    TriggerClientEvent('chat:addMessage', -1, { args = { '^1[ANNONCE]', msg } })
    logAction(src, 'announce', '', 0, msg)
end, false)

-- Commandes noclip/god via chat (passent par le serveur maintenant)
RegisterCommand('noclip', function(src)
    if src == 0 then return end
    if not hasPerm(src, 'noclip') then denyAccess(src) return end
    if not adminStates[src] then adminStates[src] = { noclip = false, god = false } end
    adminStates[src].noclip = not adminStates[src].noclip
    TriggerClientEvent('pvp_admin:noclipConfirmed', src, adminStates[src].noclip)
    logAction(src, 'noclip', '', 0, adminStates[src].noclip and 'ON' or 'OFF')
end, false)

RegisterCommand('god', function(src)
    if src == 0 then return end
    if not hasPerm(src, 'god') then denyAccess(src) return end
    if not adminStates[src] then adminStates[src] = { noclip = false, god = false } end
    adminStates[src].god = not adminStates[src].god
    TriggerClientEvent('pvp_admin:godConfirmed', src, adminStates[src].god)
    logAction(src, 'god', '', 0, adminStates[src].god and 'ON' or 'OFF')
end, false)

RegisterCommand('car', function(src, args)
    if src == 0 then return end
    if not hasPerm(src, 'spawncar') then denyAccess(src) return end
    local model = args[1]
    if not model then adminMsg(src, 'Usage: /car [modèle]') return end
    TriggerClientEvent('pvp_admin:spawnCarConfirmed', src, model)
    logAction(src, 'spawncar', '', 0, model)
end, false)

RegisterCommand('dv', function(src)
    if src == 0 then return end
    if not hasPerm(src, 'deletecar') then denyAccess(src) return end
    TriggerClientEvent('pvp_admin:deleteCarConfirmed', src)
    logAction(src, 'deletecar', '', 0)
end, false)

RegisterCommand('tpwp', function(src)
    if src == 0 then return end
    if not hasPerm(src, 'tpwp') then denyAccess(src) return end
    TriggerClientEvent('pvp_admin:tpwpConfirmed', src)
    logAction(src, 'tpwp', '', 0)
end, false)
