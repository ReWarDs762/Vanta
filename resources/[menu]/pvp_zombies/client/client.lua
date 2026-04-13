-- =============================================
--   PVP ZOMBIES - Client
--   Spawn, IA, détection mort, loot
-- =============================================

local activeZombies  = {}   -- { ped, dead }
local zombieGroupHash = nil
local playerGroupHash = nil

-- ── Relation groups (zombies attaquent les joueurs) ────────────────────────
local function setupRelationships()
    AddRelationshipGroup('ZOMBIE_HORDE')
    zombieGroupHash = GetHashKey('ZOMBIE_HORDE')
    playerGroupHash = GetHashKey('PLAYER')

    -- Zombies attaquent joueurs et joueurs peuvent attaquer zombies
    SetRelationshipBetweenGroups(5, zombieGroupHash, playerGroupHash)
    SetRelationshipBetweenGroups(5, playerGroupHash, zombieGroupHash)
    -- Zombies attaquent aussi les cops (pour éviter qu'ils les ignorent)
    SetRelationshipBetweenGroups(5, zombieGroupHash, GetHashKey('COP'))
end

-- ── Spawn d'un zombie ──────────────────────────────────────────────────────
local function spawnZombie(x, y, z)
    local typeData = Config.ZombieType
    local models   = typeData.models
    local modelStr = models[math.random(1, #models)]
    local model    = GetHashKey(modelStr)

    RequestModel(model)
    local timeout = GetGameTimer()
    while not HasModelLoaded(model) do
        if GetGameTimer() - timeout > 5000 then return end
        Citizen.Wait(0)
    end

    local ped = CreatePed(4, model,
        x, y, z - 1.0,
        math.random(0, 360) * 1.0,
        true, false
    )

    if not DoesEntityExist(ped) then
        SetModelAsNoLongerNeeded(model)
        return
    end

    -- Stats
    SetEntityMaxHealth(ped, 400)
    SetEntityHealth(ped, typeData.health + 100) -- +100 car GTA ajoute 100 au min

    -- Comportement zombie
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)   -- Attaque même si sans arme
    SetPedCombatAttributes(ped, 5, true)    -- Toujours combattre
    SetPedCombatAttributes(ped, 52, true)   -- Pas de couverture
    SetPedCombatRange(ped, 2)               -- Range 100m
    SetPedSeeingRange(ped, 80.0)
    SetPedHearingRange(ped, 40.0)

    -- Animation de marche zombie
    RequestClipSet(typeData.moveClipset)
    while not HasClipSetLoaded(typeData.moveClipset) do Citizen.Wait(0) end
    SetPedMovementClipset(ped, typeData.moveClipset, typeData.speed)

    -- Groupe
    SetPedRelationshipGroupHash(ped, zombieGroupHash)
    SetPedAsEnemy(ped, true)

    -- Empêcher le zombie de sortir les joueurs des véhicules
    SetPedCanBeDraggedOut(ped, false)
    SetPedConfigFlag(ped, 225, true) -- CPED_CONFIG_FLAG_PreventAllMeleeTaunts (no vehicle jack)

    -- Arme : mains nues (griffes)
    RemoveAllPedWeapons(ped, true)
    GiveWeaponToPed(ped, GetHashKey('WEAPON_UNARMED'), 0, false, true)
    SetPedArmour(ped, 0)

    -- Ordre d'attaquer le joueur
    local playerPed = PlayerPedId()
    TaskCombatPed(ped, playerPed, 0, 16)

    SetModelAsNoLongerNeeded(model)

    table.insert(activeZombies, {
        ped  = ped,
        dead = false,
    })
end

-- ── Position de spawn aléatoire autour du joueur ──────────────────────────
local function getSpawnPosition(playerCoords)
    local angle = math.random(0, 360) * math.pi / 180.0
    local dist  = math.random(
        math.floor(Config.SpawnRadiusMin),
        math.floor(Config.SpawnRadiusMax)
    )
    local x = playerCoords.x + math.cos(angle) * dist
    local y = playerCoords.y + math.sin(angle) * dist
    local z = playerCoords.z

    -- Trouve le sol à cette position
    local found, groundZ = GetGroundZFor_3dCoord(x, y, z + 50.0, false)
    if found then z = groundZ end

    return x, y, z
end

-- ── Vérifie si une position est trop proche d'un avant-poste (no-spawn) ──────
-- Utilise Config.ExclusionZones (données locales) pour éviter un export serveur
local function isInSafeZone(x, y, z)
    if not Config.RespectSafeZones then return false end
    local pos = vector3(x, y, z)
    for _, zone in ipairs(Config.ExclusionZones) do
        if #(pos - zone.coords) < zone.noSpawnRadius then
            return true
        end
    end
    return false
end

-- ── Vérifie si une position est dans le killRadius d'un avant-poste ──────────
-- (pour supprimer les zombies qui s'infiltrent dans la zone safe)
local function isInsideKillZone(x, y, z)
    local pos = vector3(x, y, z)
    for _, zone in ipairs(Config.ExclusionZones) do
        if #(pos - zone.coords) < zone.killRadius then
            return true
        end
    end
    return false
end

-- ── Initialisation ─────────────────────────────────────────────────────────
Citizen.CreateThread(function()
    setupRelationships()
    -- Désactive les zombies natifs de GTA (si présents)
    SetScenarioPedDensityMultiplierThisFrame(0.0)
end)

-- ── Protection joueur : empêcher les PNJ de le sortir du véhicule ────────
Citizen.CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            SetPedCanBeDraggedOut(ped, false)
            SetPedConfigFlag(ped, 32, false) -- CPED_CONFIG_FLAG_CanBeAgitated = empêche le carjack PNJ
        end
        Citizen.Wait(500)
    end
end)

-- ── Boucle de spawn ────────────────────────────────────────────────────────
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.SpawnInterval)

        -- Compte les zombies encore vivants
        local living = 0
        for _, z in ipairs(activeZombies) do
            if not z.dead and DoesEntityExist(z.ped) and not IsEntityDead(z.ped) then
                living = living + 1
            end
        end

        if living < Config.MaxZombiesPerPlayer then
            local playerCoords = GetEntityCoords(PlayerPedId())

            -- Si le joueur est dans une safe zone, on ne spawne rien du tout
            if not isInSafeZone(playerCoords.x, playerCoords.y, playerCoords.z) then
                local x, y, z = getSpawnPosition(playerCoords)

                -- La position de spawn elle-même ne doit pas non plus être dans une safe zone
                if not isInSafeZone(x, y, z) then
                    spawnZombie(x, y, z)
                end
            end
        end
    end
end)

-- ── Boucle de mise à jour : détection mort + nettoyage ─────────────────────
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.UpdateInterval)

        local playerCoords = GetEntityCoords(PlayerPedId())
        local toRemove     = {}

        for i, z in ipairs(activeZombies) do
            if not DoesEntityExist(z.ped) then
                table.insert(toRemove, i)

            elseif IsEntityDead(z.ped) and not z.dead then
                -- Zombie vient de mourir
                z.dead = true
                z.deathTime = GetGameTimer()
                -- Envoie le netId du zombie pour validation serveur (avec check validité)
                local netId = NetworkGetNetworkIdFromEntity(z.ped)
                if netId and netId > 0 then
                    TriggerServerEvent('pvp_zombies:onKill', netId)
                end
                -- NE PAS retirer de la table ici : on garde le ped pour le supprimer dans la boucle

            elseif z.dead and z.deathTime then
                -- Nettoyage des morts après 8 secondes
                if (GetGameTimer() - z.deathTime) > 8000 then
                    if DoesEntityExist(z.ped) then
                        DeleteEntity(z.ped)
                    end
                    table.insert(toRemove, i)
                end

            else
                local zCoords = GetEntityCoords(z.ped)

                -- Suppression si dans la kill zone d'un avant-poste
                if isInsideKillZone(zCoords.x, zCoords.y, zCoords.z) then
                    DeleteEntity(z.ped)
                    table.insert(toRemove, i)
                else
                    -- Nettoyage des zombies trop loin
                    local d = #(playerCoords - zCoords)
                    if d > Config.DespawnRadius then
                        DeleteEntity(z.ped)
                        table.insert(toRemove, i)
                    else
                        -- Si le zombie ne combat plus, relance la tâche
                        if not IsPedInCombat(z.ped, PlayerPedId()) and not z.dead then
                            local playerPed = PlayerPedId()
                            local dist = #(zCoords - GetEntityCoords(playerPed))
                            if dist < 60.0 then
                                TaskCombatPed(z.ped, playerPed, 0, 16)
                            end
                        end
                    end
                end
            end
        end

        -- Supprime les entrées obsolètes (en partant de la fin)
        for i = #toRemove, 1, -1 do
            table.remove(activeZombies, toRemove[i])
        end
    end
end)

-- ── Réception du loot depuis le serveur ────────────────────────────────────
RegisterNetEvent('pvp_zombies:receiveLoot')
AddEventHandler('pvp_zombies:receiveLoot', function(zombieLabel, reward, lootItems)
    -- Notification kill + argent
    local msg = '~r~[KILL]~s~ ' .. zombieLabel .. '  ~y~+' .. reward .. ' Butin'
    if #lootItems > 0 then
        local itemNames = {}
        for _, item in ipairs(lootItems) do
            table.insert(itemNames, item)
        end
        msg = msg .. '  ~w~| ' .. table.concat(itemNames, ', ')
    end

    -- Affiche en haut à droite type "kill feed"
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, true)
end)

-- ── Shot Attracteur : force le spawn de N zombies supplémentaires ──────────
RegisterNetEvent('pvp_zombies:forceSpawn')
AddEventHandler('pvp_zombies:forceSpawn', function(count)
    local playerCoords = GetEntityCoords(PlayerPedId())
    for i = 1, count do
        local x, y, z = getSpawnPosition(playerCoords)
        spawnZombie(x, y, z)
        Citizen.Wait(100)
    end
end)

-- ── Nettoyage des entités zombie ─────────────────────────────────────────
local function cleanupAllZombies()
    for _, z in ipairs(activeZombies) do
        if DoesEntityExist(z.ped) then
            DeleteEntity(z.ped)
        end
    end
    activeZombies = {}
end

-- Nettoyage au stop de la resource
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    cleanupAllZombies()
end)

-- Nettoyage quand le joueur meurt (les zombies seront respawn au prochain cycle)
AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' then
        local victim = args[1]
        local isDead = args[4] == 1
        if isDead and victim == PlayerPedId() then
            -- Petit délai pour éviter de supprimer pendant l'animation de mort
            Citizen.SetTimeout(2000, function()
                cleanupAllZombies()
            end)
        end
    end
end)
