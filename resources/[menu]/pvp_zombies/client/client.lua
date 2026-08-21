-- =============================================
--   PVP ZOMBIES - Client
--   Spawn, IA, détection mort, fouille au corps
-- =============================================

local ESX = nil
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(200)
    end
end)

local activeZombies   = {}   -- { ped, dead, looted, token }
local zombieGroupHash = nil
local playerGroupHash = nil

-- ── Relation groups (zombies attaquent les joueurs, pas de flics sur ce serveur) ──
local function setupRelationships()
    AddRelationshipGroup('ZOMBIE_HORDE')
    zombieGroupHash = GetHashKey('ZOMBIE_HORDE')
    playerGroupHash = GetHashKey('PLAYER')

    SetRelationshipBetweenGroups(5, zombieGroupHash, playerGroupHash)
    SetRelationshipBetweenGroups(5, playerGroupHash, zombieGroupHash)
end

-- ── Spawn d'un zombie ──────────────────────────────────────────────────────
-- Ped local uniquement (isNetwork = false) : invisible et non-interactible
-- pour les autres joueurs, seul le client qui l'a spawné le voit/gère.
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
        false, false
    )

    if not DoesEntityExist(ped) then
        SetModelAsNoLongerNeeded(model)
        return
    end

    -- Stats
    SetEntityMaxHealth(ped, 400)
    SetEntityHealth(ped, typeData.health + 100) -- +100 car GTA ajoute 100 au min

    -- Comportement zombie : agressif sans condition de vue/portée
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)   -- Attaque même si sans arme
    SetPedCombatAttributes(ped, 5, true)    -- Toujours combattre
    SetPedCombatAttributes(ped, 52, true)   -- Pas de couverture

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

    -- Ordre d'attaquer le joueur (aggro immédiate, pas de détection à simuler)
    local playerPed = PlayerPedId()
    TaskCombatPed(ped, playerPed, 0, 16)

    SetModelAsNoLongerNeeded(model)

    local zombieEntry = {
        ped    = ped,
        dead   = false,
        looted = false,
        token  = nil,
    }
    table.insert(activeZombies, zombieEntry)

    -- Jeton anti-triche serveur, attaché de façon asynchrone (n'affecte pas le spawn)
    if ESX then
        ESX.TriggerServerCallback('pvp_zombies:getSpawnToken', function(token)
            zombieEntry.token = token
        end)
    end
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
-- (pour supprimer les zombies/cadavres qui s'infiltrent dans la zone safe)
local function isInsideKillZone(x, y, z)
    local pos = vector3(x, y, z)
    for _, zone in ipairs(Config.ExclusionZones) do
        if #(pos - zone.coords) < zone.killRadius then
            return true
        end
    end
    return false
end

-- ── Texte 3D flottant (prompt de fouille) ─────────────────────────────────
local function DrawText3D(x, y, z, text)
    local onScreen, sx, sy = GetScreenCoordFromWorldCoord(x, y, z)
    if not onScreen then return end

    local camCoords = GetGameplayCamCoords()
    local dist  = #(camCoords - vector3(x, y, z))
    local scale = (1 / dist) * 2 * ((1 / GetGameplayCamFov()) * 100)

    SetTextScale(0.55 * scale, 0.55 * scale)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextEntry('STRING')
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(sx, sy)
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

        -- Compte les zombies encore vivants (les cadavres non fouillés ne comptent pas)
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
        local toRemove      = {}

        for i, z in ipairs(activeZombies) do
            if not DoesEntityExist(z.ped) then
                table.insert(toRemove, i)

            elseif z.dead and z.looted then
                -- Fouillé : suppression immédiate du cadavre
                DeleteEntity(z.ped)
                table.insert(toRemove, i)

            elseif IsEntityDead(z.ped) and not z.dead then
                -- Zombie vient de mourir : devient un cadavre fouillable
                -- (aucun contact serveur ici, le loot se règle au moment du "E")
                z.dead = true

            else
                local zCoords = GetEntityCoords(z.ped)

                -- Suppression si dans la kill zone d'un avant-poste
                if isInsideKillZone(zCoords.x, zCoords.y, zCoords.z) then
                    DeleteEntity(z.ped)
                    table.insert(toRemove, i)
                else
                    -- Nettoyage (vivant ou cadavre non fouillé) si trop loin du joueur
                    local d = #(playerCoords - zCoords)
                    if d > Config.DespawnRadius then
                        DeleteEntity(z.ped)
                        table.insert(toRemove, i)
                    elseif not z.dead then
                        -- Relance la tâche de combat si elle s'est arrêtée
                        if not IsPedInCombat(z.ped, PlayerPedId()) then
                            TaskCombatPed(z.ped, PlayerPedId(), 0, 16)
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

-- ── Boucle de fouille : prompt "[E] Fouiller" + interaction ────────────────
-- Seul le propriétaire des zombies peut voir/interagir (peds non-réseau).
Citizen.CreateThread(function()
    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())
        local nearest, nearestDist = nil, Config.LootPromptRadius

        for _, z in ipairs(activeZombies) do
            if z.dead and not z.looted and DoesEntityExist(z.ped) then
                local d = #(playerCoords - GetEntityCoords(z.ped))
                if d < nearestDist then
                    nearest, nearestDist = z, d
                end
            end
        end

        if nearest then
            local zc = GetEntityCoords(nearest.ped)
            DrawText3D(zc.x, zc.y, zc.z + 1.0, '[E] Fouiller')

            if IsControlJustPressed(0, 38) and nearest.token then -- INPUT_CONTEXT (E)
                nearest.looted = true
                TriggerServerEvent('pvp_zombies:claimLoot', nearest.token)
            end

            Citizen.Wait(0)
        else
            Citizen.Wait(300)
        end
    end
end)

-- ── Réception du loot depuis le serveur ────────────────────────────────────
RegisterNetEvent('pvp_zombies:receiveLoot')
AddEventHandler('pvp_zombies:receiveLoot', function(zombieLabel, reward, lootItems)
    SendNUIMessage({
        action = 'showLootToast',
        amount = reward,
        item   = lootItems[1], -- 1 seul item par zombie
    })
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

-- ── Test admin : spawn N zombies collés à la position du joueur ──────────
-- Distinct de forceSpawn (utilisé aussi par l'item shot_attract côté joueur) :
-- ici on ignore le rayon normal et les zones d'exclusion pour un test rapide.
RegisterNetEvent('pvp_admin:spawnZombiesOnMe')
AddEventHandler('pvp_admin:spawnZombiesOnMe', function(count)
    local playerCoords = GetEntityCoords(PlayerPedId())
    count = math.min(math.max(1, math.floor(tonumber(count) or 5)), 30)
    for i = 1, count do
        local angle = (i / count) * 2 * math.pi
        local x = playerCoords.x + math.cos(angle) * 2.0
        local y = playerCoords.y + math.sin(angle) * 2.0
        local z = playerCoords.z
        local found, groundZ = GetGroundZFor_3dCoord(x, y, z + 5.0, false)
        if found then z = groundZ end
        spawnZombie(x, y, z)
        Citizen.Wait(50)
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

-- Nettoyage quand le joueur meurt (zombies ET cadavres non fouillés)
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
