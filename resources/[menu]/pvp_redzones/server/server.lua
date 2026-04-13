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

-- ── Table SQL pour les stats redzone ─────────────────────────────────────
AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end

    -- Ajouter colonnes redzone aux tables existantes
    MySQL.Async.execute("ALTER TABLE `pvp_player_stats` ADD COLUMN IF NOT EXISTS `redzone_kills` INT DEFAULT 0")
    MySQL.Async.execute("ALTER TABLE `pvp_player_stats` ADD COLUMN IF NOT EXISTS `redzone_deaths` INT DEFAULT 0")
    MySQL.Async.execute("ALTER TABLE `pvp_player_stats` ADD COLUMN IF NOT EXISTS `redzone_zombies` INT DEFAULT 0")

    MySQL.Async.execute("ALTER TABLE `pvp_crews` ADD COLUMN IF NOT EXISTS `redzone_kills_total` INT DEFAULT 0")
    MySQL.Async.execute("ALTER TABLE `pvp_crews` ADD COLUMN IF NOT EXISTS `redzone_zombies_total` INT DEFAULT 0")

    MySQL.Async.execute("ALTER TABLE `pvp_crew_members` ADD COLUMN IF NOT EXISTS `redzone_kills` INT DEFAULT 0")
    MySQL.Async.execute("ALTER TABLE `pvp_crew_members` ADD COLUMN IF NOT EXISTS `redzone_zombies` INT DEFAULT 0")

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
    for i = 1, math.min(Config.ActiveCount, #available) do
        local z = available[i].zone
        activeZones[#activeZones + 1] = {
            id     = z.id,
            label  = z.label,
            coords = z.coords,
            radius = Config.RedZoneRadius,
        }
    end

    nextRotation = GetGameTimer() + rotationInterval

    -- Notifier tous les clients
    TriggerClientEvent('pvp_redzones:sync', -1, activeZones, rotationInterval)

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
            -- Crew stats
            MySQL.Async.fetchAll(
                'SELECT crew_id FROM pvp_crew_members WHERE identifier = @id LIMIT 1',
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
