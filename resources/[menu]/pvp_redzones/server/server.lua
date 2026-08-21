-- =============================================
--   PVP REDZONES - Serveur
--   Rotation des zones, stats, loot boost
-- =============================================

local ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- ── État actuel des redzones ─────────────────────────────────────────────
local activeZones = {}       -- table de 3 zones actives { id, label, coords }
local nextRotation = 0       -- timestamp de la prochaine rotation
local rotationInterval = Config.RotationMinutes * 60 * 1000  -- en ms
local zoneControl = {}       -- [zoneId] = { scores = {}, owner = crewId, ownerName = '', ownerTag = '' }

-- ── Table SQL pour les stats redzone ─────────────────────────────────────
AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end

    -- Ajouter colonnes redzone aux tables existantes (portable)
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
    addCol('pvp_player_stats', 'redzone_kills',   'INT DEFAULT 0')
    addCol('pvp_player_stats', 'redzone_deaths',  'INT DEFAULT 0')
    addCol('pvp_player_stats', 'redzone_zombies', 'INT DEFAULT 0')
    addCol('pvp_crews',        'redzone_kills_total',   'INT DEFAULT 0')
    addCol('pvp_crews',        'redzone_zombies_total',  'INT DEFAULT 0')
    addCol('pvp_crews',        'redzone_controls_total', 'INT DEFAULT 0')
    addCol('pvp_crew_members', 'redzone_kills',   'INT DEFAULT 0')
    addCol('pvp_crew_members', 'redzone_zombies', 'INT DEFAULT 0')

    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `pvp_redzone_control_log` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `zone_id` VARCHAR(40) NOT NULL,
            `zone_label` VARCHAR(80) NOT NULL,
            `crew_id` INT NOT NULL,
            `crew_name` VARCHAR(30) NOT NULL,
            `crew_tag` VARCHAR(5) NOT NULL,
            `score` INT DEFAULT 0,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- Première rotation au démarrage
    rotateZones()

    print('[pvp_redzones] Système de Redzones démarré — ' .. Config.ActiveCount .. ' zones actives, rotation toutes les ' .. Config.RotationMinutes .. ' min')
end)

-- ── Sélection aléatoire de N zones ───────────────────────────────────────
function rotateZones()
    local available = {}
    for i, zone in ipairs(Config.Zones) do
        available[#available + 1] = { idx = i, zone = zone }
    end

    -- Mélanger (Fisher-Yates)
    for i = #available, 2, -1 do
        local j = math.random(1, i)
        available[i], available[j] = available[j], available[i]
    end

    -- Prendre les N premières
    activeZones = {}
    zoneControl = {}
    for i = 1, math.min(Config.ActiveCount, #available) do
        local z = available[i].zone
        activeZones[#activeZones + 1] = {
            id     = z.id,
            label  = z.label,
            coords = z.coords,
            radius = Config.RedZoneRadius,
        }
        zoneControl[z.id] = { scores = {}, owner = nil, ownerName = '', ownerTag = '' }
    end

    nextRotation = GetGameTimer() + rotationInterval

    -- Notifier tous les clients
    TriggerClientEvent('pvp_redzones:sync', -1, activeZones, rotationInterval)
    TriggerClientEvent('pvp_redzones:syncControl', -1, zoneControl)

    -- Notification en jeu
    local zoneNames = {}
    for _, z in ipairs(activeZones) do
        zoneNames[#zoneNames + 1] = z.label
    end
    TriggerClientEvent('chat:addMessage', -1, {
        color = { 255, 50, 50 },
        args = { '[REDZONE]', 'Nouvelles zones dangereuses : ' .. table.concat(zoneNames, ', ') .. ' — Loot x' .. Config.LootMultiplier .. ' !' }
    })

    print('[pvp_redzones] Rotation : ' .. table.concat(zoneNames, ', '))
end

-- ── Timer de rotation ────────────────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(60000)  -- check toutes les minutes
        if GetGameTimer() >= nextRotation and nextRotation > 0 then
            -- Avancer nextRotation immédiatement pour éviter double rotation
            nextRotation = GetGameTimer() + rotationInterval
            rotateZones()
        end
    end
end)

-- ── Sync quand un joueur rejoint ─────────────────────────────────────────
RegisterNetEvent('pvp_redzones:requestSync')
AddEventHandler('pvp_redzones:requestSync', function()
    local src = source
    local remaining = math.max(0, nextRotation - GetGameTimer())
    TriggerClientEvent('pvp_redzones:sync', src, activeZones, remaining)
    TriggerClientEvent('pvp_redzones:syncControl', src, zoneControl)
end)

-- ── Export : vérifier si un joueur est en redzone ────────────────────────
-- Utilisable par pvp_zombies pour booster le loot
exports('isPlayerInRedzone', function(playerId)
    local ped = GetPlayerPed(playerId)
    if not ped or ped == 0 then return false end
    local playerCoords = GetEntityCoords(ped)
    for _, zone in ipairs(activeZones) do
        local dist = #(playerCoords - zone.coords)
        if dist <= zone.radius then
            return true
        end
    end
    return false
end)

local function getPlayerRedzone(playerId)
    local ped = GetPlayerPed(playerId)
    if not ped or ped == 0 then return nil end
    local playerCoords = GetEntityCoords(ped)
    for _, zone in ipairs(activeZones) do
        if #(playerCoords - zone.coords) <= zone.radius then
            return zone
        end
    end
    return nil
end

exports('getPlayerRedzone', function(playerId)
    return getPlayerRedzone(playerId)
end)

local function getTopScores(control)
    local first, second = nil, nil
    for crewId, data in pairs(control.scores or {}) do
        local entry = {
            crewId = crewId,
            name = data.name,
            tag = data.tag,
            score = tonumber(data.score) or 0,
        }
        if not first or entry.score > first.score then
            second = first
            first = entry
        elseif not second or entry.score > second.score then
            second = entry
        end
    end
    return first, second
end

local function addControlScore(zone, crew, points)
    if not zone or not crew or not crew.id then return end
    local control = zoneControl[zone.id]
    if not control then
        control = { scores = {}, owner = nil, ownerName = '', ownerTag = '' }
        zoneControl[zone.id] = control
    end

    local key = tostring(crew.id)
    control.scores[key] = control.scores[key] or { name = crew.name, tag = crew.tag, score = 0 }
    control.scores[key].score = (tonumber(control.scores[key].score) or 0) + (points or Config.ControlPointsPerKill)
    control.scores[key].name = crew.name
    control.scores[key].tag = crew.tag

    local leader, runnerUp = getTopScores(control)
    local runnerScore = runnerUp and runnerUp.score or 0
    local canControl = leader
        and leader.score >= Config.ControlThreshold
        and (leader.score - runnerScore) >= Config.ControlLeadRequired

    if canControl and tostring(control.owner or '') ~= tostring(leader.crewId) then
        control.owner = tonumber(leader.crewId)
        control.ownerName = leader.name
        control.ownerTag = leader.tag

        MySQL.Async.execute('UPDATE pvp_crews SET redzone_controls_total = redzone_controls_total + 1, xp = COALESCE(xp,0) + @xp, bank = COALESCE(bank,0) + @bank WHERE id = @cid', {
            ['@cid'] = control.owner,
            ['@xp'] = Config.ControlRewardXP,
            ['@bank'] = Config.ControlRewardBank,
        })
        MySQL.Async.execute('INSERT INTO pvp_redzone_control_log (zone_id, zone_label, crew_id, crew_name, crew_tag, score) VALUES (@zid, @zl, @cid, @cn, @tag, @score)', {
            ['@zid'] = zone.id,
            ['@zl'] = zone.label,
            ['@cid'] = control.owner,
            ['@cn'] = leader.name,
            ['@tag'] = leader.tag,
            ['@score'] = leader.score,
        })

        TriggerClientEvent('chat:addMessage', -1, {
            color = { 255, 60, 60 },
            args = { '[REDZONE]', ('[%s] %s contrôle %s ! +%d XP crew / +$%d'):format(leader.tag, leader.name, zone.label, Config.ControlRewardXP, Config.ControlRewardBank) }
        })
    end

    TriggerClientEvent('pvp_redzones:syncControl', -1, zoneControl)
end

exports('getActiveZones', function()
    return activeZones
end)

exports('getLootMultiplier', function()
    return Config.LootMultiplier
end)

exports('getCashMultiplier', function()
    return Config.CashMultiplier
end)

-- ── Event pour forcer une rotation depuis pvp_admin (vérification admin) ──
RegisterNetEvent('pvp_redzones:forceRotate')
AddEventHandler('pvp_redzones:forceRotate', function()
    local src = source
    if src and src > 0 then
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return end
        local group = xPlayer.getGroup()
        if group ~= 'admin' and group ~= 'superadmin' then
            print(('[pvp_redzones] BLOCKED: joueur %d a tenté de forcer rotation sans permission admin'):format(src))
            return
        end
    end
    rotateZones()
end)

-- ── Stats : kill PVP en redzone ──────────────────────────────────────────
RegisterNetEvent('pvp_redzones:pvpKill')
AddEventHandler('pvp_redzones:pvpKill', function(killerSrc, victimSrc)
    -- Killer stats
    if killerSrc then
        local killer = ESX.GetPlayerFromId(killerSrc)
        if killer then
            MySQL.Async.execute(
                'UPDATE pvp_player_stats SET redzone_kills = redzone_kills + 1 WHERE identifier = @id',
                { ['@id'] = killer.identifier }
            )
            TriggerEvent('pvp_crew:redzoneKill', killer.identifier)
            -- Crew stats
            MySQL.Async.fetchAll(
                'SELECT m.crew_id, c.name, c.tag FROM pvp_crew_members m JOIN pvp_crews c ON c.id = m.crew_id WHERE m.identifier = @id LIMIT 1',
                { ['@id'] = killer.identifier },
                function(rows)
                    if rows and rows[1] then
                        MySQL.Async.execute(
                            'UPDATE pvp_crew_members SET redzone_kills = redzone_kills + 1 WHERE identifier = @id',
                            { ['@id'] = killer.identifier }
                        )
                        MySQL.Async.execute(
                            'UPDATE pvp_crews SET redzone_kills_total = redzone_kills_total + 1 WHERE id = @cid',
                            { ['@cid'] = rows[1].crew_id }
                        )
                        local zone = getPlayerRedzone(killerSrc)
                        if zone then
                            addControlScore(zone, {
                                id = rows[1].crew_id,
                                name = rows[1].name,
                                tag = rows[1].tag,
                            }, Config.ControlPointsPerKill)
                        end
                    end
                end
            )
        end
    end

    -- Victim stats
    if victimSrc then
        local victim = ESX.GetPlayerFromId(victimSrc)
        if victim then
            MySQL.Async.execute(
                'UPDATE pvp_player_stats SET redzone_deaths = redzone_deaths + 1 WHERE identifier = @id',
                { ['@id'] = victim.identifier }
            )
        end
    end
end)

-- ── Stats : zombie tué en redzone ────────────────────────────────────────
-- Peut être appelé via TriggerEvent (server→server) avec src en paramètre
-- ou via TriggerServerEvent (client→server) avec source
AddEventHandler('pvp_redzones:zombieKill', function(playerSrc)
    local src = playerSrc or source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    MySQL.Async.execute(
        'UPDATE pvp_player_stats SET redzone_zombies = redzone_zombies + 1 WHERE identifier = @id',
        { ['@id'] = xPlayer.identifier }
    )

    -- Crew stats
    MySQL.Async.fetchAll(
        'SELECT crew_id FROM pvp_crew_members WHERE identifier = @id LIMIT 1',
        { ['@id'] = xPlayer.identifier },
        function(rows)
            if rows and rows[1] then
                MySQL.Async.execute(
                    'UPDATE pvp_crew_members SET redzone_zombies = redzone_zombies + 1 WHERE identifier = @id',
                    { ['@id'] = xPlayer.identifier }
                )
                MySQL.Async.execute(
                    'UPDATE pvp_crews SET redzone_zombies_total = redzone_zombies_total + 1 WHERE id = @cid',
                    { ['@cid'] = rows[1].crew_id }
                )
            end
        end
    )
end)
