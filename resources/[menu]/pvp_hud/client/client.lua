-- =============================================
--   PVP HUD - Client Side
--   Envoie vie, kevlar, arme et munitions au HUD
-- =============================================

local hudVisible = true

-- Table qui traduit les hash d'armes GTA en noms lisibles
local WeaponNames = {
    -- Pistolets
    [GetHashKey("WEAPON_PISTOL")]             = "Pistolet",
    [GetHashKey("WEAPON_PISTOL50")]           = "Pistolet .50",
    [GetHashKey("WEAPON_COMBATPISTOL")]       = "Combat Pistol",
    [GetHashKey("WEAPON_APPISTOL")]           = "AP Pistol",
    [GetHashKey("WEAPON_HEAVYPISTOL")]        = "Heavy Pistol",
    [GetHashKey("WEAPON_SNSPISTOL")]          = "SNS Pistol",
    [GetHashKey("WEAPON_DOUBLEACTION")]       = "Double Action",
    [GetHashKey("WEAPON_VINTAGEPISTOL")]      = "Vintage Pistol",
    [GetHashKey("WEAPON_REVOLVER")]           = "Revolver",
    [GetHashKey("WEAPON_MACHINEPISTOL")]      = "Machine Pistol",
    -- SMG
    [GetHashKey("WEAPON_MICROSMG")]           = "Micro SMG",
    [GetHashKey("WEAPON_SMG")]                = "SMG",
    [GetHashKey("WEAPON_ASSAULTSMG")]         = "Assault SMG",
    [GetHashKey("WEAPON_COMBATPDW")]          = "Combat PDW",
    [GetHashKey("WEAPON_MINISMG")]            = "Mini SMG",
    -- Fusils d'assaut
    [GetHashKey("WEAPON_ASSAULTRIFLE")]       = "AK-47",
    [GetHashKey("WEAPON_CARBINERIFLE")]       = "M4",
    [GetHashKey("WEAPON_ADVANCEDRIFLE")]      = "Advanced Rifle",
    [GetHashKey("WEAPON_SPECIALCARBINE")]     = "Special Carbine",
    [GetHashKey("WEAPON_BULLPUPRIFLE")]       = "Bullpup Rifle",
    [GetHashKey("WEAPON_COMPACTRIFLE")]       = "Compact Rifle",
    -- MG
    [GetHashKey("WEAPON_MG")]                 = "Mitrailleuse",
    [GetHashKey("WEAPON_COMBATMG")]           = "Combat MG",
    -- Snipers
    [GetHashKey("WEAPON_SNIPERRIFLE")]        = "Sniper",
    [GetHashKey("WEAPON_HEAVYSNIPER")]        = "Heavy Sniper",
    [GetHashKey("WEAPON_MARKSMANRIFLE")]      = "Marksman Rifle",
    -- Shotguns
    [GetHashKey("WEAPON_PUMPSHOTGUN")]        = "Pump Shotgun",
    [GetHashKey("WEAPON_SAWNOFFSHOTGUN")]     = "Sawn-off",
    [GetHashKey("WEAPON_ASSAULTSHOTGUN")]     = "Assault Shotgun",
    [GetHashKey("WEAPON_DBSHOTGUN")]          = "Double Barrel",
    [GetHashKey("WEAPON_BULLPUPSHOTGUN")]     = "Bullpup Shotgun",
    [GetHashKey("WEAPON_HEAVYSHOTGUN")]       = "Heavy Shotgun",
    -- Lourdes / Explosifs
    [GetHashKey("WEAPON_MINIGUN")]            = "Minigun",
    [GetHashKey("WEAPON_RPG")]                = "RPG",
    [GetHashKey("WEAPON_GRENADELAUNCHER")]    = "Lance-grenades",
    -- Mêlée
    [GetHashKey("WEAPON_KNIFE")]              = "Couteau",
    [GetHashKey("WEAPON_BAT")]                = "Batte",
    [GetHashKey("WEAPON_HAMMER")]             = "Marteau",
    [GetHashKey("WEAPON_CROWBAR")]            = "Pied-de-biche",
    [GetHashKey("WEAPON_NIGHTSTICK")]         = "Matraque",
    [GetHashKey("WEAPON_MACHETE")]            = "Machette",
    [GetHashKey("WEAPON_SWITCHBLADE")]        = "Cran d'arrêt",
    [GetHashKey("WEAPON_HATCHET")]            = "Hache",
    [GetHashKey("WEAPON_KNUCKLE")]            = "Knuckle Duster",
    -- Grenades
    [GetHashKey("WEAPON_GRENADE")]            = "Grenade",
    [GetHashKey("WEAPON_SMOKEGRENADE")]       = "Fumigène",
    [GetHashKey("WEAPON_FLASHLIGHT")]         = "Lampe torche",
}

-- Récupère le nom lisible d'une arme via son hash
local function getWeaponLabel(weaponHash)
    if WeaponNames[weaponHash] then
        return WeaponNames[weaponHash]
    end
    return "Arme"
end

-- Ancienne HP pour détecter les dégâts
local lastHP = 200

-- Dégâts de chute désactivés : snapshot de vie avant/après une chute (voir
-- boucle principale ci-dessous). Pas de natif GTA dédié aux seuls dégâts de
-- chute (SetEntityProofs n'a pas de flag "fall") — on utilise donc IS_PED_FALLING
-- pour délimiter la fenêtre et restaurer la vie perdue pendant celle-ci.
-- Limite assumée : un joueur touché par balle PENDANT sa chute verrait aussi
-- ces dégâts restaurés — fenêtre trop courte en pratique pour justifier un
-- système plus lourd.
local wasFalling = false
local healthBeforeFall = 200

-- Boucle principale : se répète toutes les 100ms
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)

        local ped = PlayerPedId()

        local isFalling = IsPedFalling(ped)
        if isFalling and not wasFalling then
            healthBeforeFall = GetEntityHealth(ped)
        elseif not isFalling and wasFalling then
            local currentHealth = GetEntityHealth(ped)
            if currentHealth > 0 and currentHealth < healthBeforeFall then
                SetEntityHealth(ped, healthBeforeFall)
            end
        end
        wasFalling = isFalling

        local health = GetEntityHealth(ped) - 100  -- GTA stocke la vie entre 100 et 200
        local armor  = GetPedArmour(ped)

        -- Clamp entre 0 et 100
        if health < 0  then health = 0  end
        if health > 100 then health = 100 end

        -- Détection des dégâts pour le flash rouge
        if health < lastHP then
            SendNUIMessage({ type = "damage" })
        end
        lastHP = health

        -- Arme actuelle
        local weaponHash = GetSelectedPedWeapon(ped)
        local weaponLabel = ""
        local ammo = 0
        local reserve = 0

        if weaponHash ~= GetHashKey("WEAPON_UNARMED") then
            weaponLabel = getWeaponLabel(weaponHash)
            ammo        = GetAmmoInPedWeapon(ped, weaponHash)
            -- Munitions dans le chargeur actuel (approximation)
            local _, maxAmmo = GetMaxAmmo(ped, weaponHash)
            reserve = math.max(0, ammo)
            -- On sépare chargeur et réserve
            local clipSize = GetWeaponClipSize(weaponHash)
            if clipSize > 0 then
                local inClip = math.min(ammo, clipSize)
                reserve      = math.max(0, ammo - inClip)
                ammo         = inClip
            end
        end

        -- Envoi des données au HUD HTML
        SendNUIMessage({
            type    = "update",
            hp      = health,
            armor   = armor,
            weapon  = weaponLabel,
            ammo    = ammo,
            reserve = reserve,
        })
    end
end)

-- Commande pour cacher/afficher le HUD (utile pour les streams)
RegisterCommand('togglehud', function()
    hudVisible = not hudVisible
    SendNUIMessage({ type = "show", show = hudVisible })
end, false)

-- Affiche le HUD au spawn du joueur
AddEventHandler('playerSpawned', function()
    hudVisible = true
    SendNUIMessage({ type = "show", show = true })
end)

-- Notification grâce zone safe (déclenchée par pvp_outposts)
AddEventHandler('pvp_hud:showGrace', function(durationSec)
    SendNUIMessage({ type = 'graceStart', duration = durationSec })
end)

-- ── Désactiver dispatch + bateaux aléatoires + camions poubelle ──────────
Citizen.CreateThread(function()
    for i = 1, 15 do
        EnableDispatchService(i, false)
    end
    SetRandomBoats(false)
    SetGarbageTrucks(false)
    SetRandomTrains(false)
end)

-- ── Roue des armes + touches 1-9 désactivées en permanence ──────────────
-- ── Suppression PNJ + véhicules PNJ (natives ThisFrame = chaque frame) ──
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        -- Maintenir la densité à 0 chaque frame
        SetPedDensityMultiplierThisFrame(0.0)
        SetVehicleDensityMultiplierThisFrame(0.0)
        SetRandomVehicleDensityMultiplierThisFrame(0.0)
        SetParkedVehicleDensityMultiplierThisFrame(0.0)
        SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)

        -- Supprimer les étoiles (wanted level) chaque frame
        local playerId = PlayerId()
        if GetPlayerWantedLevel(playerId) > 0 then
            SetPlayerWantedLevel(playerId, 0, false)
            SetPlayerWantedLevelNow(playerId, false)
        end

        -- Roue des armes + touches 1-9
        DisableControlAction(0, 37,  true)
        DisableControlAction(0, 157, true)
        DisableControlAction(0, 158, true)
        DisableControlAction(0, 14,  true)
        DisableControlAction(0, 15,  true)
        DisableControlAction(0, 160, true)
        DisableControlAction(0, 164, true)
        DisableControlAction(0, 165, true)
        DisableControlAction(0, 159, true)
        DisableControlAction(0, 161, true)
        DisableControlAction(0, 162, true)
        DisableControlAction(0, 163, true)
    end
end)

-- ── Nettoyage périodique des entités ambiantes résiduelles ───────────────
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000) -- toutes les 5 secondes

        local playerPed = PlayerPedId()

        -- Supprimer tous les peds non-joueur dans le rayon
        local peds = GetGamePool('CPed')
        for _, ped in ipairs(peds) do
            if not IsPedAPlayer(ped) and ped ~= playerPed then
                -- Ne pas supprimer les peds des avant-postes (network object non-local)
                if IsPedHuman(ped) and not IsEntityAMissionEntity(ped) then
                    SetEntityAsMissionEntity(ped, false, true)
                    DeleteEntity(ped)
                end
            end
        end

        -- Supprimer les véhicules ambiants (hors véhicules joueurs et mission)
        local vehicles = GetGamePool('CVehicle')
        for _, veh in ipairs(vehicles) do
            if not IsEntityAMissionEntity(veh) then
                local hasDriver = GetPedInVehicleSeat(veh, -1) ~= 0
                local driverIsPlayer = hasDriver and IsPedAPlayer(GetPedInVehicleSeat(veh, -1))
                if not driverIsPlayer and GetVehicleNumberOfPassengers(veh) == 0 then
                    -- Vérifier qu'aucun joueur n'est à bord
                    local occupied = false
                    for seat = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
                        local occupant = GetPedInVehicleSeat(veh, seat)
                        if occupant ~= 0 and IsPedAPlayer(occupant) then
                            occupied = true
                            break
                        end
                    end
                    if not occupied then
                        SetEntityAsMissionEntity(veh, false, true)
                        DeleteEntity(veh)
                    end
                end
            end
        end
    end
end)

-- ── Désactiver coups de crosse + tir en véhicule ────────────────────────
-- Armes de mêlée légitimes (ces armes gardent leurs contrôles de frappe)
local meleeWeapons = {
    [GetHashKey("WEAPON_KNIFE")]       = true,
    [GetHashKey("WEAPON_BAT")]         = true,
    [GetHashKey("WEAPON_CROWBAR")]     = true,
    [GetHashKey("WEAPON_SWITCHBLADE")] = true,
    [GetHashKey("WEAPON_HATCHET")]     = true,
    [GetHashKey("WEAPON_MACHETE")]     = true,
    [GetHashKey("WEAPON_UNARMED")]     = true,
}

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local ped = PlayerPedId()
        local weaponHash = GetSelectedPedWeapon(ped)

        -- Bloquer coups de crosse uniquement si arme à feu équipée
        if not meleeWeapons[weaponHash] then
            DisableControlAction(0, 140, true) -- MELEE_ATTACK_LIGHT  (coup de crosse gauche)
            DisableControlAction(0, 141, true) -- MELEE_ATTACK_HEAVY  (coup de crosse droit)
            DisableControlAction(0, 142, true) -- MELEE_ATTACK_ALTERNATE
        end

        -- Bloquer tir / visée / lancer d'explosifs depuis un véhicule
        -- (moto comme voiture). SetPlayerCanDoDriveBy(false) coupe nativement
        -- toute la mécanique de drive-by : visée, tir ET lancer de grenade /
        -- molotov depuis un siège. Les DisableControlAction restent en filet
        -- de sécurité pour la frame courante.
        if IsPedInAnyVehicle(ped, false) then
            local playerId = PlayerId()
            SetPlayerCanDoDriveBy(playerId, false)
            DisablePlayerFiring(playerId, true) -- bloque tout tir cette frame

            DisableControlAction(0, 24,  true) -- ATTACK (tir principal / lancer)
            DisableControlAction(0, 25,  true) -- AIM (visée)
            DisableControlAction(0, 257, true) -- ATTACK2 (lancer projectile)
            DisableControlAction(0, 140, true) -- MELEE_ATTACK_LIGHT
            DisableControlAction(0, 141, true) -- MELEE_ATTACK_HEAVY
            DisableControlAction(0, 142, true) -- MELEE_ATTACK_ALTERNATE
            DisableControlAction(0, 69,  true) -- VEH_ATTACK
            DisableControlAction(0, 70,  true) -- VEH_ATTACK2
            DisableControlAction(0, 92,  true) -- VEH_GUN_LEFT
            DisableControlAction(0, 93,  true) -- VEH_GUN_RIGHT
        end
    end
end)
