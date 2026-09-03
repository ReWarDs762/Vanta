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

-- ── Tâche d'un zombie : poursuite ou combat ───────────────────────────────
-- TaskCombatPed ne fait PAS avancer un ped à mains nues vers une cible assise
-- dans un véhicule : sans attaque valide à sa portée, l'IA de combat le laisse
-- planté sur place. C'est la vraie cause des zombies immobiles dès que le
-- joueur roule — constaté en test sur une route parfaitement dégagée, donc sans
-- aucun rapport avec le pathfinding (deux tentatives dans cette direction ont
-- échoué avant, voir spawnZombie).
--
-- Tant que le joueur est en véhicule, on ne laisse donc pas l'IA de combat
-- décider : on pilote le déplacement à la main avec TaskGoToEntity, qui suit
-- une cible mobile. Dès qu'il remet pied à terre, on repasse en combat pour
-- qu'ils frappent.
local CHASE_SPEED     = 2.0   -- m/s passés à TaskGoToEntity
local CHASE_STOP_DIST = 1.5   -- distance d'arrêt autour du véhicule

local function taskZombie(zed, playerPed, playerInVehicle)
    if playerInVehicle then
        zed.mode = 'chase'
        TaskGoToEntity(zed.ped, playerPed, -1, CHASE_STOP_DIST, CHASE_SPEED, 1073741824, 0)
    else
        zed.mode = 'combat'
        TaskCombatPed(zed.ped, playerPed, 0, 16)
    end
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

    -- bScriptHostPed=true (dernier param) : marque le ped comme mission entity
    -- dès sa création. Sans ça, pvp_hud le traitait comme un ped ambiant et le
    -- supprimait dans sa boucle de nettoyage toutes les 5s (IsEntityAMissionEntity
    -- == false pour tout modèle humain non marqué). La durée de vie du zombie
    -- reste entièrement gérée manuellement plus bas (DespawnRadius, mort, loot).
    local ped = CreatePed(4, model,
        x, y, z - 1.0,
        math.random(0, 360) * 1.0,
        false, true
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
    SetPedCombatAttributes(ped, 21, true)   -- BF_CanChaseTargetOnFoot : poursuit
                                            -- une cible qui s'échappe, notamment
                                            -- en véhicule (filet en plus du mode
                                            -- 'chase' piloté à la main)

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

    -- ── Audio : plus de voix de PNJ ──────────────────────────────────────
    -- Les modèles utilisés sont des PNJ GTA standards : ils partaient donc dans
    -- les dialogues d'ambiance et les cris de douleur humains. On leur assigne
    -- la banque de voix ALIENS (la seule voix non humaine disponible en natif
    -- dans GTA V — feulements/râles), et on coupe l'audio de douleur humain.
    SetAmbientVoiceName(ped, 'ALIENS')
    DisablePedPainAudio(ped, true)
    StopCurrentPlayingAmbientSpeech(ped)

    -- ── Déplacement : pas d'escalade ─────────────────────────────────────
    -- Un zombie ne doit pas franchir un mur ou une clôture : le décor doit
    -- rester un abri fiable.
    --
    -- L'interdiction porte sur le GESTE, pas sur le calcul de chemin. Deux
    -- versions ont tenté de passer par le pathfinding et ont été retirées :
    --   1. SetPedPathCanDropFromHeight(false) + coût d'escalade prohibitif ;
    --   2. SetPedPathCanUseClimbovers(false).
    -- Dans le navmesh GTA, les « climbovers » ne sont pas que les murs : ce sont
    -- les liens entre polygones pour tous les petits obstacles (bordures,
    -- barrières, rebords). Les interdire ampute une grande partie des chemins de
    -- la carte — trop risqué pour ce qu'on y gagne. Ce n'était d'ailleurs PAS la
    -- cause des zombies figés : celle-là était dans la tâche de combat, voir
    -- taskZombie plus haut.
    --
    -- Restent donc ici les échelles (liens ponctuels, sans risque pour la
    -- navigation générale) et un coût d'escalade dissuasif, qui fait préférer le
    -- contournement sans jamais rendre un chemin impossible. Toute escalade
    -- réellement entamée est annulée par la boucle anti-escalade plus bas.
    SetPedPathCanUseLadders(ped, false)
    SetPedPathClimbCostModifier(ped, 100.0)

    -- Arme : mains nues (griffes)
    RemoveAllPedWeapons(ped, true)
    GiveWeaponToPed(ped, GetHashKey('WEAPON_UNARMED'), 0, false, true)
    SetPedArmour(ped, 0)

    SetModelAsNoLongerNeeded(model)

    local zombieEntry = {
        ped    = ped,
        dead   = false,
        looted = false,
        token  = nil,
        mode   = nil,   -- 'combat' | 'chase', posé par taskZombie
    }
    table.insert(activeZombies, zombieEntry)

    -- Aggro immédiate, pas de détection à simuler. Passe par taskZombie pour
    -- naître déjà dans le bon mode : un zombie qui apparaît alors que le joueur
    -- roule doit poursuivre, pas se mettre en combat et rester planté.
    local playerPed = PlayerPedId()
    taskZombie(zombieEntry, playerPed, IsPedInAnyVehicle(playerPed, false))

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
-- Seuils de l'anti-blocage (voir plus bas) : déplacement minimum attendu entre
-- deux passages, distance à partir de laquelle un zombie immobile est anormal,
-- et nombre de passages consécutifs avant de le débloquer.
local STUCK_MIN_MOVE = 0.35   -- mètres
local STUCK_MIN_DIST = 3.0    -- mètres (au-delà de la portée de frappe)
local STUCK_TICKS    = 4      -- × Config.UpdateInterval (500ms) = 2s

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.UpdateInterval)

        local playerPed       = PlayerPedId()
        local playerCoords    = GetEntityCoords(playerPed)
        local playerInVehicle = IsPedInAnyVehicle(playerPed, false)
        local toRemove        = {}

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
                        -- Bascule poursuite ↔ combat selon que le joueur est en
                        -- véhicule ou à pied (voir taskZombie plus haut). On ne
                        -- re-tâche qu'au changement de mode : ré-émettre la
                        -- tâche à chaque passage la réinitialiserait et ferait
                        -- bégayer le déplacement.
                        local wantMode = playerInVehicle and 'chase' or 'combat'

                        if z.mode ~= wantMode then
                            z.stuck = 0
                            ClearPedTasksImmediately(z.ped)
                            taskZombie(z, playerPed, playerInVehicle)
                        elseif wantMode == 'combat' and not IsPedInCombat(z.ped, playerPed) then
                            -- La tâche de combat s'est arrêtée d'elle-même
                            taskZombie(z, playerPed, playerInVehicle)
                        end

                        -- Anti-blocage. Un zombie qui n'a pas bougé depuis
                        -- STUCK_TICKS passages ALORS qu'il est encore trop loin
                        -- pour frapper a perdu sa tâche : on repart propre. Un
                        -- zombie immobile au corps à corps, lui, est normal.
                        if z.lastPos
                            and #(zCoords - z.lastPos) < STUCK_MIN_MOVE
                            and d > STUCK_MIN_DIST then
                            z.stuck = (z.stuck or 0) + 1
                            if z.stuck >= STUCK_TICKS then
                                z.stuck = 0
                                ClearPedTasksImmediately(z.ped)
                                taskZombie(z, playerPed, playerInVehicle)
                            end
                        else
                            z.stuck = 0
                        end
                        z.lastPos = zCoords
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

-- ── Boucle anti-escalade ──────────────────────────────────────────────────
-- C'est ici qu'est réellement appliquée l'interdiction de grimper (voir le
-- commentaire dans spawnZombie). Plutôt que de retirer les franchissements du
-- pathfinding — ce qui fige les zombies faute de chemin — on laisse la
-- navigation complète et on annule le geste dès qu'il démarre : le zombie
-- retombe au pied de l'obstacle et repart chercher un contournement.
--
-- Cadence courte : un vault se joue en moins d'une seconde, la boucle de mise
-- à jour (500ms) le laisserait passer une fois sur deux.
local CLIMB_CHECK_MS = 100

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(CLIMB_CHECK_MS)

        local playerPed       = PlayerPedId()
        local playerInVehicle = IsPedInAnyVehicle(playerPed, false)

        for _, z in ipairs(activeZombies) do
            if not z.dead and DoesEntityExist(z.ped) and not IsEntityDead(z.ped) then
                -- IsPedClimbing seulement, pas IsPedJumping : descendre d'un
                -- rebord joue aussi une animation de saut, et l'interrompre
                -- ferait bégayer les zombies en navigation normale.
                if IsPedClimbing(z.ped) then
                    ClearPedTasksImmediately(z.ped)
                    taskZombie(z, playerPed, playerInVehicle)
                end
            end
        end
    end
end)

-- ── Boucle de râles ───────────────────────────────────────────────────────
-- Les zombies ne "parlent" plus tout seuls : SetBlockingOfNonTemporaryEvents +
-- la voix ALIENS coupent l'essentiel du bavardage PNJ, mais laissent aussi le
-- ped muet la plupart du temps. On force donc un râle à intervalle irrégulier
-- sur les zombies vivants proches du joueur, pour garder une ambiance sonore.
local GROWL_INTERVAL_MS = 2500   -- fenêtre de tirage
local GROWL_CHANCE      = 35     -- % de chance par zombie et par fenêtre
local GROWL_RADIUS      = 35.0   -- au-delà, inaudible : inutile de déclencher

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(GROWL_INTERVAL_MS)

        local playerCoords = GetEntityCoords(PlayerPedId())
        for _, z in ipairs(activeZombies) do
            if not z.dead and DoesEntityExist(z.ped) and not IsEntityDead(z.ped) then
                if #(playerCoords - GetEntityCoords(z.ped)) < GROWL_RADIUS
                    and math.random(100) <= GROWL_CHANCE then
                    PlayAmbientSpeech1(z.ped, 'GENERIC_INSULT_HIGH', 'SPEECH_PARAMS_FORCE')
                end
            end
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
            -- `z.token == nil` = le serveur a refusé d'en émettre un (débit de
            -- spawn anormal, plafond mémoire) ou la réponse n'est pas encore
            -- arrivée. Sans jeton la fouille sera rejetée côté serveur : mieux
            -- vaut ne pas proposer le prompt que d'afficher une action muette.
            if z.dead and not z.looted and z.token and DoesEntityExist(z.ped) then
                local d = #(playerCoords - GetEntityCoords(z.ped))
                if d < nearestDist then
                    nearest, nearestDist = z, d
                end
            end
        end

        if nearest then
            local zc = GetEntityCoords(nearest.ped)
            DrawText3D(zc.x, zc.y, zc.z + 1.0, '[E] Fouiller')

            if IsControlJustPressed(0, 38) then -- INPUT_CONTEXT (E)
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
-- Nettoie le nom affiché au joueur : retire le préfixe technique weapon_ /
-- vehicle_ / veh_ (affichage uniquement, l'item reste inchangé côté inventaire).
local function prettyLootName(name)
    if type(name) ~= 'string' then return name end
    return (name:gsub('^[Ww][Ee][Aa][Pp][Oo][Nn]_', '')
                :gsub('^[Vv][Ee][Hh][Ii][Cc][Ll][Ee]_', '')
                :gsub('^[Vv][Ee][Hh]_', ''))
end

RegisterNetEvent('pvp_zombies:receiveLoot')
AddEventHandler('pvp_zombies:receiveLoot', function(zombieLabel, reward, lootItems)
    -- Passe par la pile partagee de vanta_ui : chaque loot occupe sa propre
    -- ligne et les precedentes remontent. L ancien toast local reutilisait une
    -- seule div, donc deux zombies tues coup sur coup n affichaient qu un seul
    -- message (le second ecrasait le premier).
    local item = prettyLootName(lootItems and lootItems[1]) -- 1 seul item par zombie
    local msg  = '+' .. tostring(reward) .. ' $'
    if type(item) == 'string' and item ~= '' then
        msg = msg .. '  ·  ' .. item
    end
    exports['vanta_ui']:notify(msg, 'success')
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
