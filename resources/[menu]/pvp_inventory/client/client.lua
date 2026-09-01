-- =============================================
--   PVP INVENTORY - Client
-- =============================================

local ESX    = nil
local isOpen = false
local playerHotbar = {} -- synced from NUI
local equippedWeapons = {} -- armes actuellement équipées {name=true}
local hudType = 'gta' -- 'gta' ou 'vanta' — préférence joueur
local pendingStartTab = nil -- onglet à afficher à l'ouverture suivante

-- Cooldowns heal en millisecondes (doit être déclaré avant hotbar)
local HEAL_DURATIONS = {
    bandage      = 1000,  -- 1 seconde, peut bouger
    kevlar       = 2000,  -- 2 secondes, accroupi + immobile
    medkit       = 3000,  -- 3 secondes, accroupi + immobile
}

-- Shots = effet instantané, pas de cooldown
local INSTANT_ITEMS = {
    shot_repel = true, shot_attract = true,
    shot_speed = true, shot_health  = true,
}

-- Items qui forcent l'accroupissement + blocage mouvement
local HEAL_FREEZE = { kevlar = true, medkit = true }

-- ══ Notification joueur ═══════════════════════════════════════════════════
-- Pendant client de notify() cote serveur : affiche le message via la pile
-- partagee de vanta_ui ET relache le verrou de transfert du NUI.
-- Voir le commentaire detaille dans server/server.lua.
local function notify(msg, kind)
    exports['vanta_ui']:notify(msg, kind)
    SendNUIMessage({ type = 'unlock' })
end

Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(200)
    end
end)

-- ── Keybinding TAB ────────────────────────────────────────────────────────
RegisterCommand('pvp_bag', function()
    if isOpen then
        closeInventory()
    else
        TriggerServerEvent('pvp_inventory:requestData')
    end
end, false)

RegisterKeyMapping('pvp_bag', 'Ouvrir l\'inventaire', 'keyboard', 'tab')

-- ── Commande /xp — Ouvrir directement sur l'onglet Profil ─────────────────
RegisterCommand('xp', function()
    if isOpen then
        closeInventory()
        return
    end
    pendingStartTab = 'profile'
    TriggerServerEvent('pvp_inventory:requestData')
end, false)

-- ── Mapping items → hash armes GTA (pour hotbar toggle) ─────────────────
local WEAPON_HASHES = {
    -- ── Très Commun — Pistolets ──
    weapon_molotov           = GetHashKey('WEAPON_MOLOTOV'),
    weapon_appistol          = GetHashKey('WEAPON_APPISTOL'),
    weapon_pistol            = GetHashKey('WEAPON_PISTOL'),
    weapon_pistol_mk2        = GetHashKey('WEAPON_PISTOL_MK2'),
    weapon_snspistol         = GetHashKey('WEAPON_SNSPISTOL'),
    weapon_snspistol_mk2     = GetHashKey('WEAPON_SNSPISTOL_MK2'),
    weapon_vintagepistol     = GetHashKey('WEAPON_VINTAGEPISTOL'),
    weapon_combatpistol      = GetHashKey('WEAPON_COMBATPISTOL'),
    weapon_heavypistol       = GetHashKey('WEAPON_HEAVYPISTOL'),
    -- ── Très Commun — SMG ──
    weapon_microsmg          = GetHashKey('WEAPON_MICROSMG'),
    weapon_minismg           = GetHashKey('WEAPON_MINISMG'),
    weapon_smg               = GetHashKey('WEAPON_SMG'),
    weapon_smg_mk2           = GetHashKey('WEAPON_SMG_MK2'),
    weapon_machinepistol     = GetHashKey('WEAPON_MACHINEPISTOL'),
    -- ── Commun — Fusils ──
    weapon_assaultrifle      = GetHashKey('WEAPON_ASSAULTRIFLE'),
    weapon_carbinerifle      = GetHashKey('WEAPON_CARBINERIFLE'),
    weapon_specialcarbine    = GetHashKey('WEAPON_SPECIALCARBINE'),
    -- ── Rare ──
    weapon_assaultrifle_mk2  = GetHashKey('WEAPON_ASSAULTRIFLE_MK2'),
    weapon_carbinerifle_mk2  = GetHashKey('WEAPON_CARBINERIFLE_MK2'),
    weapon_specialcarbine_mk2= GetHashKey('WEAPON_SPECIALCARBINE_MK2'),
    weapon_stungun           = GetHashKey('WEAPON_STUNGUN'),
    weapon_combatmg          = GetHashKey('WEAPON_COMBATMG'),
    weapon_mg                = GetHashKey('WEAPON_MG'),
    -- ── Épic ──
    weapon_precisionrifle    = GetHashKey('WEAPON_PRECISIONRIFLE'),
    weapon_compactlauncher   = GetHashKey('WEAPON_COMPACTLAUNCHER'),
    weapon_emplauncher       = GetHashKey('WEAPON_EMPLAUNCHER'),
    weapon_combatmg_mk2      = GetHashKey('WEAPON_COMBATMG_MK2'),
    weapon_musket            = GetHashKey('WEAPON_MUSKET'),
    -- ── Légendaire ──
    weapon_sniperrifle       = GetHashKey('WEAPON_SNIPERRIFLE'),
    weapon_marksmanrifle_mk2 = GetHashKey('WEAPON_MARKSMANRIFLE_MK2'),
    weapon_heavysniper       = GetHashKey('WEAPON_HEAVYSNIPER'),
    weapon_heavysniper_mk2   = GetHashKey('WEAPON_HEAVYSNIPER_MK2'),
    weapon_rpg               = GetHashKey('WEAPON_RPG'),
    weapon_hominglauncher    = GetHashKey('WEAPON_HOMINGLAUNCHER'),
}

-- ── Raccourcis hotbar 1-8 ────────────────────────────────────────────────
local HOTBAR_KEYS = {'1','2','3','4','5','6','7','8'}
for i = 1, 8 do
    RegisterCommand('pvp_hotbar_' .. i, function()
        if isOpen then return end -- pas pendant l'inventaire ouvert
        local slot = playerHotbar[i]
        if not slot or not slot.name then return end

        -- Si c'est une arme → toggle equip/unequip
        if WEAPON_HASHES[slot.name] then
            if isHealing then
                notify('Impossible pendant le soin !', 'warning')
                return
            end
            local ped  = PlayerPedId()
            local hash = WEAPON_HASHES[slot.name]
            if equippedWeapons[slot.name] then
                -- Déséquiper : ranger l'arme (on garde l'arme sur le ped pour conserver les customs)
                equippedWeapons[slot.name] = nil
                SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
            else
                -- Équiper : demander au serveur (le serveur enverra equipWeapon si OK)
                -- NE PAS marquer equippedWeapons ici — attendre la confirmation serveur
                TriggerServerEvent('pvp_inventory:useItem', slot.name)
            end
        elseif INSTANT_ITEMS[slot.name] then
            -- Shot = effet instantané, pas de cooldown
            TriggerServerEvent('pvp_inventory:useItemConfirmed', slot.name)
        elseif HEAL_DURATIONS[slot.name] then
            -- Consommable avec cooldown (bandage, medkit, kevlar)
            startHeal(slot.name)
        else
            -- Autre item → utiliser normalement
            TriggerServerEvent('pvp_inventory:useItem', slot.name)
        end
    end, false)
    RegisterKeyMapping('pvp_hotbar_' .. i, 'Hotbar slot ' .. i, 'keyboard', HOTBAR_KEYS[i])
end

-- ── Helper : vérifier zone safe (via export pvp_outposts) ─────────────────
local function isInSafeZone()
    local ok, result = pcall(function()
        return exports['pvp_outposts']:IsInSafeZone()
    end)
    return ok and result or false
end

-- ── Ouvrir ────────────────────────────────────────────────────────────────
RegisterNetEvent('pvp_inventory:openUI')
AddEventHandler('pvp_inventory:openUI', function(data)
    -- Restaurer la hotbar sauvegardée dans le client
    if data.savedHotbar and type(data.savedHotbar) == 'table' then
        playerHotbar = {}
        for i = 1, 8 do
            local slot = data.savedHotbar[tostring(i)] or data.savedHotbar[i]
            if slot and type(slot) == 'table' and slot.name then
                playerHotbar[i] = slot
            end
        end
    end
    isOpen = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    data.startTab = pendingStartTab or 'inventory'
    pendingStartTab = nil
    SendNUIMessage({ type = 'open', data = data })
    -- Informer le NUI de l'état safe zone
    SendNUIMessage({ type = 'setSafeZone', data = { inSafeZone = isInSafeZone() } })
end)

-- ── Fermer ────────────────────────────────────────────────────────────────
function closeInventory()
    isOpen = false
    currentOutpostId = nil
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'close' })
end

-- ── Bloquer la caméra quand inventaire ouvert (souris = UI seulement) ────
Citizen.CreateThread(function()
    while true do
        if isOpen then
            -- Bloquer rotation caméra (souris look)
            DisableControlAction(0, 1, true)   -- LookLeftRight
            DisableControlAction(0, 2, true)   -- LookUpDown
            DisableControlAction(0, 25, true)  -- Aim
            DisableControlAction(0, 24, true)  -- Attack
            DisableControlAction(0, 257, true) -- Attack2
            DisableControlAction(0, 140, true) -- MeleeAttackLight
            DisableControlAction(0, 141, true) -- MeleeAttackHeavy
            DisableControlAction(0, 142, true) -- MeleeAttackAlternate
            DisableControlAction(0, 106, true) -- VehicleMouseControlOverride
            -- Bloquer touches numériques 1-8 (sélection armes GTA) pour que le NUI les reçoive proprement
            DisableControlAction(0, 157, true) -- SelectWeaponUnarmed  (1)
            DisableControlAction(0, 158, true) -- SelectWeaponMelee    (2)
            DisableControlAction(0, 159, true) -- SelectWeaponHandgun  (3)
            DisableControlAction(0, 160, true) -- SelectWeaponShotgun  (4)
            DisableControlAction(0, 161, true) -- SelectWeaponSMG      (5)
            DisableControlAction(0, 162, true) -- SelectWeaponAutoRifle(6)
            DisableControlAction(0, 163, true) -- SelectWeaponSniper   (7)
            DisableControlAction(0, 164, true) -- SelectWeaponHeavy    (8)
            DisableControlAction(0, 14,  true) -- NextWeapon
            DisableControlAction(0, 15,  true) -- PrevWeapon
        end
        Citizen.Wait(0)
    end
end)

-- ── Callbacks NUI → Lua ───────────────────────────────────────────────────
-- Relais du toast interne du NUI vers la pile partagee de vanta_ui.
-- Volontairement SANS liberation du verrou de transfert : l ancien toast
-- local du NUI n y touchait pas non plus.
RegisterNUICallback('notify', function(data, cb)
    if type(data) == 'table' and type(data.msg) == 'string' and data.msg ~= '' then
        exports['vanta_ui']:notify(data.msg, data.kind)
    end
    cb('ok')
end)

RegisterNUICallback('close', function(_, cb)
    closeInventory()
    cb('ok')
end)

RegisterNUICallback('closeDrop', function(_, cb)
    local dropId = currentDropId
    currentDropId = nil
    closeInventory()
    if dropId then
        TriggerServerEvent('pvp_drops:closeUI', dropId)
    end
    cb('ok')
end)

RegisterNUICallback('useItem', function(data, cb)
    if INSTANT_ITEMS[data.item] then
        TriggerServerEvent('pvp_inventory:useItemConfirmed', data.item)
    elseif HEAL_DURATIONS[data.item] then
        startHeal(data.item)
    else
        TriggerServerEvent('pvp_inventory:useItem', data.item)
    end
    cb('ok')
end)

RegisterNUICallback('dropItem', function(data, cb)
    TriggerServerEvent('pvp_inventory:dropItem', data.item, data.qty)
    cb('ok')
end)

RegisterNUICallback('stashDeposit', function(data, cb)
    TriggerServerEvent('pvp_inventory:stashDeposit', data.item, data.qty)
    cb('ok')
end)

RegisterNUICallback('stashWithdraw', function(data, cb)
    TriggerServerEvent('pvp_inventory:stashWithdraw', data.item, data.qty)
    cb('ok')
end)

RegisterNUICallback('syncHotbar', function(data, cb)
    -- Reconstruire la table proprement (JSON null = absents en Lua)
    playerHotbar = {}
    if data.hotbar then
        for i = 1, 8 do
            local slot = data.hotbar[tostring(i)] or data.hotbar[i]
            if slot and type(slot) == 'table' and slot.name then
                playerHotbar[i] = slot
            else
                playerHotbar[i] = nil
            end
        end
    end
    -- Persister en DB via le serveur
    TriggerServerEvent('pvp_inventory:saveHotbar', data.hotbar or {})
    cb('ok')
end)

RegisterNUICallback('createListing', function(data, cb)
    if not isInSafeZone() then
        notify('Achats/ventes uniquement en zone safe !', 'warning')
        cb('ok')
        return
    end
    TriggerServerEvent('pvp_market:createListing',
        data.item, data.label, data.qty, data.price)
    cb('ok')
end)

RegisterNUICallback('buyListing', function(data, cb)
    if not isInSafeZone() then
        notify('Achats/ventes uniquement en zone safe !', 'warning')
        cb('ok')
        return
    end
    TriggerServerEvent('pvp_market:buyListing', data.id)
    cb('ok')
end)

RegisterNUICallback('cancelListing', function(data, cb)
    TriggerServerEvent('pvp_market:cancelListing', data.id)
    cb('ok')
end)

RegisterNUICallback('refreshMarket', function(_, cb)
    TriggerServerEvent('pvp_inventory:refreshData')
    cb('ok')
end)

RegisterNUICallback('claimSales', function(_, cb)
    TriggerServerEvent('pvp_market:claimSales')
    cb('ok')
end)

RegisterNUICallback('setActiveBadge', function(data, cb)
    TriggerServerEvent('pvp_inventory:setActiveBadge', data.badgeId or '')
    cb('ok')
end)

-- ── Toast badge débloqué ─────────────────────────────────────────────────
RegisterNetEvent('pvp_inventory:toastBadge')
AddEventHandler('pvp_inventory:toastBadge', function(badgeId)
    SendNUIMessage({ type = 'toastBadge', badgeId = badgeId })
end)

RegisterNetEvent('pvp_inventory:toastMsg')
AddEventHandler('pvp_inventory:toastMsg', function(msg)
    notify(msg, 'info')
end)

-- ── Coffre Avant-Poste ─────────────────────────────────────────────────
RegisterNUICallback('outpostStashDeposit', function(data, cb)
    TriggerServerEvent('pvp_inventory:outpostStashDeposit', data.outpostId, data.item, data.qty)
    cb('ok')
end)

RegisterNUICallback('outpostStashWithdraw', function(data, cb)
    TriggerServerEvent('pvp_inventory:outpostStashWithdraw', data.outpostId, data.item, data.qty)
    cb('ok')
end)

-- Coffre avant-poste → ouvre l'UI en mode coffre avant-poste (séparé du conteneur protégé)
local currentOutpostId = nil
local currentDropId    = nil

RegisterNetEvent('pvp_inventory:openUIWithOutpost')
AddEventHandler('pvp_inventory:openUIWithOutpost', function(data)
    currentOutpostId = data.outpostId
    isOpen = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    SendNUIMessage({ type = 'openOutpost', data = data })
    SendNUIMessage({ type = 'setSafeZone', data = { inSafeZone = isInSafeZone() } })
end)

-- ── Drop de ravitaillement ────────────────────────────────────────────────
RegisterNetEvent('pvp_inventory:openUIWithDrop')
AddEventHandler('pvp_inventory:openUIWithDrop', function(data)
    currentDropId = data.dropId
    isOpen = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    SendNUIMessage({ type = 'openDrop', data = data })
end)

RegisterNUICallback('dropWithdraw', function(data, cb)
    TriggerServerEvent('pvp_drops:takeItem', data.dropId, data.item, data.qty)
    cb('ok')
end)

RegisterNetEvent('pvp_inventory:refreshFromDrop')
AddEventHandler('pvp_inventory:refreshFromDrop', function(data)
    SendNUIMessage({ type = 'refreshDrop', data = data })
end)

-- Refresh du coffre avant-poste
RegisterNetEvent('pvp_inventory:refreshOutpostStash')
AddEventHandler('pvp_inventory:refreshOutpostStash', function(items)
    SendNUIMessage({
        type = 'refreshOutpostStash',
        data = { items = items }
    })
end)



-- ── Effets items ───────────────────────────────────────────────────────────
RegisterNetEvent('pvp_inventory:applyItem')
AddEventHandler('pvp_inventory:applyItem', function(item)
    local ped = PlayerPedId()
    if item == 'bandage' then
        SetEntityHealth(ped, math.min(200, GetEntityHealth(ped) + 25))

    elseif item == 'medkit' then
        SetEntityHealth(ped, 200)

    elseif item == 'kevlar' then
        SetPedArmour(ped, 100)

    -- ── Shot Répulsif : tue uniquement les ZOMBIES proches (pas les NPCs d'avant-poste) ──
    elseif item == 'shot_repel' then
        local pos = GetEntityCoords(ped)
        local peds = GetGamePool('CPed')
        local killed = 0
        local zombieHash = GetHashKey('ZOMBIE_HORDE')
        for _, p in ipairs(peds) do
            if p ~= ped and not IsPedAPlayer(p) then
                local rel = GetPedRelationshipGroupHash(p)
                if rel == zombieHash then
                    local dist = #(pos - GetEntityCoords(p))
                    if dist <= 30.0 then
                        SetEntityHealth(p, 0)
                        killed = killed + 1
                    end
                end
            end
        end
        notify(killed .. ' zombies repoussés !', 'success')

    -- ── Shot Attracteur : force le spawn de 6 zombies supplémentaires ──
    elseif item == 'shot_attract' then
        TriggerServerEvent('pvp_zombies:forceSpawn', 6)
        notify('Les zombies arrivent...', 'info')

    -- ── Shot de Vitesse : sprint boosté pendant 30s ────────────────────
    elseif item == 'shot_speed' then
        notify('Vitesse boostée 30s !', 'success')
        Citizen.CreateThread(function()
            local endTime = GetGameTimer() + 30000
            while GetGameTimer() < endTime do
                SetPedMoveRateOverride(PlayerPedId(), 1.8)
                Citizen.Wait(0)
            end
            SetPedMoveRateOverride(PlayerPedId(), 1.0)
        end)

    -- ── Shot de Santé : +80 HP temporaire (30s puis perd le surplus) ───
    elseif item == 'shot_health' then
        local maxHp  = 200
        local bonus  = 80
        local newHp  = math.min(maxHp + bonus, GetEntityHealth(ped) + bonus)
        SetEntityMaxHealth(ped, maxHp + bonus)
        SetEntityHealth(ped, newHp)
        notify('Boost de santé 30s !', 'success')
        Citizen.CreateThread(function()
            Citizen.Wait(30000)
            local p = PlayerPedId()
            SetEntityMaxHealth(p, maxHp)
            if GetEntityHealth(p) > maxHp then
                SetEntityHealth(p, maxHp)
            end
        end)
    end
end)

-- Armes nécessitant des munitions limitées (sniper + explosifs)
local LIMITED_AMMO = {
    weapon_sniperrifle=true, weapon_marksmanrifle_mk2=true,
    weapon_heavysniper=true, weapon_heavysniper_mk2=true,
    weapon_precisionrifle=true,
    weapon_rpg=true,         weapon_hominglauncher=true,
    weapon_compactlauncher=true, weapon_emplauncher=true,
}

-- Munitions de base pour les armes limitées (minimum pour être utilisable)
local LIMITED_AMMO_DEFAULT = {
    weapon_sniperrifle=5, weapon_marksmanrifle_mk2=5,
    weapon_heavysniper=3, weapon_heavysniper_mk2=3,
    weapon_precisionrifle=5,
    weapon_rpg=1,         weapon_hominglauncher=1,
    weapon_compactlauncher=3, weapon_emplauncher=3,
}

-- ── Équiper une arme (ne consomme pas l'item) ──────────────────────────
RegisterNetEvent('pvp_inventory:equipWeapon')
AddEventHandler('pvp_inventory:equipWeapon', function(itemName)
    local ped  = PlayerPedId()
    local hash = WEAPON_HASHES[itemName]
    if hash then
        if HasPedGotWeapon(ped, hash, false) then
            -- L'arme est déjà sur le ped (rangée via hotbar) → switch instantané + rechargement
            if not LIMITED_AMMO[itemName] then
                SetPedAmmo(ped, hash, 9999)
                local _, maxClip = GetMaxAmmoInClip(ped, hash, true)
                SetAmmoInClip(ped, hash, maxClip)
            end
            SetCurrentPedWeapon(ped, hash, true)
        else
            -- Première fois ou après respawn → donner + customs
            if LIMITED_AMMO[itemName] then
                local baseAmmo = LIMITED_AMMO_DEFAULT[itemName] or 1
                GiveWeaponToPed(ped, hash, baseAmmo, false, false)
            else
                GiveWeaponToPed(ped, hash, 9999, false, false)
            end
            pcall(exports['pvp_outposts'].applyWeaponCustomForItem, itemName)
            SetCurrentPedWeapon(ped, hash, true)
        end
        equippedWeapons[itemName] = true
    end
end)

-- ── Déséquiper une arme (appelé quand l'item est retiré : stash/coffre/marché) ──
RegisterNetEvent('pvp_inventory:unequipWeapon')
AddEventHandler('pvp_inventory:unequipWeapon', function(itemName)
    local hash = WEAPON_HASHES[itemName]
    if hash and equippedWeapons[itemName] then
        local ped = PlayerPedId()
        RemoveWeaponFromPed(ped, hash)
        equippedWeapons[itemName] = nil
        SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
    end
end)

-- ── Recharger munitions (sniper uniquement) ─────────────────────────────
local AMMO_MAP = { ammo_sniper = 'weapon_sniperrifle' }

RegisterNetEvent('pvp_inventory:addAmmo')
AddEventHandler('pvp_inventory:addAmmo', function(ammoItem, amount)
    local ped = PlayerPedId()
    local weaponItem = AMMO_MAP[ammoItem]
    if weaponItem then
        local hash = WEAPON_HASHES[weaponItem]
        if hash and HasPedGotWeapon(ped, hash, false) then
            AddAmmoToPed(ped, hash, amount)
        end
    end
end)


-- ══ SYSTÈME VÉHICULES ═══════════════════════════════════════════════════
local mySpawnedVehicle = nil  -- entity du véhicule que CE joueur a spawné (pour le supprimer à la mort)

-- Vitesse max autorisée pour ranger un véhicule (m/s) : le joueur doit être
-- quasiment à l'arrêt (1.5 m/s ~ 5 km/h).
local STORE_MAX_SPEED = 1.5

-- ── Spawn véhicule devant le joueur ─────────────────────────────────────
RegisterNetEvent('pvp_inventory:spawnVehicle')
AddEventHandler('pvp_inventory:spawnVehicle', function(model, itemName, itemLabel)
    -- Si ce joueur a déjà un véhicule sorti, empêcher
    if mySpawnedVehicle and DoesEntityExist(mySpawnedVehicle) then
        notify('Range ton véhicule actuel d\'abord ! (K)', 'warning')
        TriggerServerEvent('pvp_inventory:storeVehicle', itemName, itemLabel)
        return
    end

    local hash = GetHashKey(model)
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 50 do
        Citizen.Wait(100)
        timeout = timeout + 1
    end

    if not HasModelLoaded(hash) then
        notify('Modèle introuvable : ' .. model, 'error')
        TriggerServerEvent('pvp_inventory:storeVehicle', itemName, itemLabel)
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    -- Spawn devant le joueur
    local forward = GetEntityForwardVector(ped)
    local spawnPos = vector3(coords.x + forward.x * 5.0, coords.y + forward.y * 5.0, coords.z)

    local veh = CreateVehicle(hash, spawnPos.x, spawnPos.y, spawnPos.z, heading, true, false)
    SetModelAsNoLongerNeeded(hash)

    -- Mettre le joueur au volant
    TaskWarpPedIntoVehicle(ped, veh, -1)

    -- Marquer le véhicule avec ses infos (state bag) pour que n'importe quel conducteur puisse le ranger
    local netId = NetworkGetNetworkIdFromEntity(veh)
    Entity(veh).state:set('pvp_itemName', itemName, true)
    Entity(veh).state:set('pvp_itemLabel', itemLabel, true)

    -- Garder une ref locale pour suppression à la mort
    mySpawnedVehicle = veh

    -- Si véhicule Arena War : installer le mod boost (48) pour activer boost/shunt natif GTA
    SetVehicleModKit(veh, 0)
    local numBoostMods = GetNumVehicleMods(veh, 48)
    if numBoostMods > 0 then
        SetVehicleMod(veh, 48, numBoostMods - 1, false)  -- niveau max
    end

    -- Charger et appliquer la custom sauvegardée pour ce modèle
    TriggerServerEvent('pvp_vehiclecustom:load', itemName)
end)

-- ── Touche K : ranger le véhicule (conducteur uniquement) ──────────────
RegisterCommand('pvp_store_vehicle', function()
    if isOpen then return end

    local ped = PlayerPedId()

    -- Le joueur doit être dans un véhicule
    if not IsPedInAnyVehicle(ped, false) then
        return
    end

    local veh = GetVehiclePedIsIn(ped, false)

    -- Le joueur doit être le CONDUCTEUR (seat -1)
    if GetPedInVehicleSeat(veh, -1) ~= ped then
        notify('Tu dois être conducteur pour ranger ce véhicule !', 'warning')
        return
    end

    -- Vérifier que c'est un véhicule spawné PVP (a les state bags)
    local itemName  = Entity(veh).state.pvp_itemName
    local itemLabel = Entity(veh).state.pvp_itemLabel
    if not itemName or not itemLabel then
        notify('Ce véhicule ne peut pas être rangé.', 'warning')
        return
    end

    -- Le véhicule doit être quasiment à l'arrêt pour être rangé
    if GetEntitySpeed(veh) > STORE_MAX_SPEED then
        notify('Arrête-toi pour ranger le véhicule !', 'warning')
        return
    end

    -- Éjecter tous les passagers avant suppression
    for seat = 0, GetVehicleMaxNumberOfPassengers(veh) - 1 do
        local passengerPed = GetPedInVehicleSeat(veh, seat)
        if passengerPed ~= 0 then
            TaskLeaveVehicle(passengerPed, veh, 16) -- 16 = flag sortie immédiate
        end
    end

    -- Téléporter le conducteur hors du véhicule
    local coords = GetEntityCoords(veh)
    SetEntityCoords(ped, coords.x + 2.0, coords.y, coords.z, false, false, false, false)

    -- Supprimer le véhicule immédiatement
    SetEntityAsMissionEntity(veh, true, true)
    DeleteEntity(veh)

    -- Si c'était notre véhicule spawné, nettoyer la ref
    if mySpawnedVehicle and veh == mySpawnedVehicle then
        mySpawnedVehicle = nil
    end

    -- Redonner l'item au joueur qui range
    TriggerServerEvent('pvp_inventory:storeVehicle', itemName, itemLabel)
end, false)
RegisterKeyMapping('pvp_store_vehicle', 'Ranger le véhicule', 'keyboard', 'k')

-- Le texte des notifications est desormais affiche par vanta_ui ; cet event
-- ne porte plus que la liberation du verrou de transfert du NUI, que le
-- serveur emet a chaque notification (voir notify() dans server/server.lua).
RegisterNetEvent('pvp_inventory:unlockTransfer')
AddEventHandler('pvp_inventory:unlockTransfer', function()
    SendNUIMessage({ type = 'unlock' })
end)

RegisterNetEvent('pvp_inventory:refresh')
AddEventHandler('pvp_inventory:refresh', function(data)
    if isOpen then
        SendNUIMessage({ type = 'refresh', data = data })
    end
end)

-- ══ SUPPRESSION PNJ + VÉHICULES PNJ ═════════════════════════════════════
-- Densité + dispatch : ces fonctions sont "ThisFrame" mais tolèrent un léger
-- intervalle sans impact visible — 0ms n'apporte rien vs 0ms.
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        SetPedDensityMultiplierThisFrame(0.0)
        SetVehicleDensityMultiplierThisFrame(0.0)
        SetRandomVehicleDensityMultiplierThisFrame(0.0)
        SetParkedVehicleDensityMultiplierThisFrame(0.0)
        SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)
    end
end)

-- ══ DÉSACTIVATION DISPATCH (n'a pas besoin de tourner chaque frame) ═════
Citizen.CreateThread(function()
    while true do
        for i = 1, 15 do EnableDispatchService(i, false) end
        Citizen.Wait(5000) -- Toutes les 5s suffit largement
    end
end)

-- ══ RESTRICTIONS COMBAT + ROUE DES ARMES ════════════════════════════════
-- (migré depuis pvp_hud — restrictions coups de crosse + tir en véhicule)

-- Armes de mêlée légitimes : gardent leurs contrôles de frappe
local meleeWeapons = {
    [GetHashKey('WEAPON_KNIFE')]       = true,
    [GetHashKey('WEAPON_BAT')]         = true,
    [GetHashKey('WEAPON_CROWBAR')]     = true,
    [GetHashKey('WEAPON_SWITCHBLADE')] = true,
    [GetHashKey('WEAPON_HATCHET')]     = true,
    [GetHashKey('WEAPON_MACHETE')]     = true,
    [GetHashKey('WEAPON_UNARMED')]     = true,
}

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0) -- Chaque frame pour bloquer les inputs

        local ped = PlayerPedId()
        local weaponHash = GetSelectedPedWeapon(ped)

        -- ── Roue des armes + touches 1-9 désactivées ──
        DisableControlAction(0, 37,  true)  -- SelectWeapon
        DisableControlAction(0, 157, true)  -- SelectNextWeapon
        DisableControlAction(0, 158, true)  -- SelectPrevWeapon
        DisableControlAction(0, 14,  true)  -- SelectWeaponUnarmed
        DisableControlAction(0, 15,  true)  -- SelectWeaponMelee
        DisableControlAction(0, 160, true)  -- SelectWeaponShotgun
        DisableControlAction(0, 164, true)  -- SelectWeaponSMG
        DisableControlAction(0, 165, true)  -- SelectWeaponAutoRifle
        DisableControlAction(0, 159, true)  -- SelectWeaponSniper
        DisableControlAction(0, 161, true)  -- SelectWeaponHeavy
        DisableControlAction(0, 162, true)  -- SelectWeaponSpecial
        DisableControlAction(0, 163, true)  -- SelectWeaponHandgun

        -- ── Bloquer coups de crosse (pistol-whip) avec armes à feu ──
        -- Seules les armes de mêlée légitimes gardent leurs contrôles de frappe
        if not meleeWeapons[weaponHash] then
            DisableControlAction(0, 140, true) -- MELEE_ATTACK_LIGHT
            DisableControlAction(0, 141, true) -- MELEE_ATTACK_HEAVY
            DisableControlAction(0, 142, true) -- MELEE_ATTACK_ALTERNATE
        end

        -- ── Bloquer tir depuis un véhicule ──
        if IsPedInAnyVehicle(ped, false) then
            DisableControlAction(0, 24,  true) -- ATTACK
            DisableControlAction(0, 25,  true) -- AIM
            DisableControlAction(0, 69,  true) -- VEH_ATTACK
            DisableControlAction(0, 70,  true) -- VEH_ATTACK2
            DisableControlAction(0, 92,  true) -- VEH_GUN_LEFT
            DisableControlAction(0, 93,  true) -- VEH_GUN_RIGHT
        end
    end
end)

-- ══ SYSTÈME DE HEAL AVEC COOLDOWN + BLOCAGE TIR/MOUVEMENT ═══════════════
local isHealing = false
local healingItem = nil  -- quel item est en cours
local healGeneration = 0 -- incrémenté à chaque annulation pour invalider le timer

-- Bloquer tir + mouvement pendant le heal
Citizen.CreateThread(function()
    while true do
        if isHealing then
            local ped = PlayerPedId()
            -- Toujours bloquer le tir
            DisableControlAction(0, 24, true)   -- Attack
            DisableControlAction(0, 25, true)   -- Aim
            DisableControlAction(0, 257, true)  -- Attack2
            DisableControlAction(0, 140, true)  -- MeleeAttackLight
            DisableControlAction(0, 141, true)  -- MeleeAttackHeavy
            DisableControlAction(0, 142, true)  -- MeleeAttackAlternate
            -- Bloquer mouvement pour kevlar/medkit
            if HEAL_FREEZE[healingItem] then
                DisableControlAction(0, 30, true)   -- MoveLeftRight
                DisableControlAction(0, 31, true)   -- MoveUpDown
                DisableControlAction(0, 21, true)   -- Sprint
                DisableControlAction(0, 22, true)   -- Jump
                DisableControlAction(0, 44, true)   -- Cover
                DisableControlAction(0, 36, true)   -- Stealth (duck)
            end
            Citizen.Wait(0)
        else
            Citizen.Wait(200)
        end
    end
end)

-- ══ SYSTÈME HUD VANTA (intégré, contrôlé par préférence joueur) ═════════
-- Noms lisibles des armes pour le HUD VANTA
local WeaponLabels = {
    [GetHashKey('WEAPON_PISTOL')]           = 'Pistol',
    [GetHashKey('WEAPON_PISTOL_MK2')]       = 'Pistol MK2',
    [GetHashKey('WEAPON_PISTOL50')]         = 'Pistol .50',
    [GetHashKey('WEAPON_COMBATPISTOL')]     = 'Combat Pistol',
    [GetHashKey('WEAPON_APPISTOL')]         = 'AP Pistol',
    [GetHashKey('WEAPON_HEAVYPISTOL')]      = 'Heavy Pistol',
    [GetHashKey('WEAPON_SNSPISTOL')]        = 'SNS Pistol',
    [GetHashKey('WEAPON_SNSPISTOL_MK2')]    = 'SNS MK2',
    [GetHashKey('WEAPON_DOUBLEACTION')]     = 'Double Action',
    [GetHashKey('WEAPON_VINTAGEPISTOL')]    = 'Vintage Pistol',
    [GetHashKey('WEAPON_REVOLVER')]         = 'Revolver',
    [GetHashKey('WEAPON_MACHINEPISTOL')]    = 'Machine Pistol',
    [GetHashKey('WEAPON_MICROSMG')]         = 'Micro SMG',
    [GetHashKey('WEAPON_SMG')]              = 'SMG',
    [GetHashKey('WEAPON_SMG_MK2')]          = 'SMG MK2',
    [GetHashKey('WEAPON_MINISMG')]          = 'Mini SMG',
    [GetHashKey('WEAPON_COMBATPDW')]        = 'Combat PDW',
    [GetHashKey('WEAPON_ASSAULTRIFLE')]     = 'AK-47',
    [GetHashKey('WEAPON_ASSAULTRIFLE_MK2')] = 'AK-47 MK2',
    [GetHashKey('WEAPON_CARBINERIFLE')]     = 'M4',
    [GetHashKey('WEAPON_CARBINERIFLE_MK2')] = 'M4 MK2',
    [GetHashKey('WEAPON_SPECIALCARBINE')]   = 'Special Carbine',
    [GetHashKey('WEAPON_SPECIALCARBINE_MK2')]= 'Special Carbine MK2',
    [GetHashKey('WEAPON_COMPACTRIFLE')]     = 'Compact Rifle',
    [GetHashKey('WEAPON_MG')]               = 'Mitrailleuse',
    [GetHashKey('WEAPON_COMBATMG')]         = 'Combat MG',
    [GetHashKey('WEAPON_COMBATMG_MK2')]     = 'Combat MG MK2',
    [GetHashKey('WEAPON_SNIPERRIFLE')]      = 'Sniper',
    [GetHashKey('WEAPON_HEAVYSNIPER')]      = 'Heavy Sniper',
    [GetHashKey('WEAPON_HEAVYSNIPER_MK2')]  = 'Heavy Sniper MK2',
    [GetHashKey('WEAPON_MARKSMANRIFLE_MK2')]= 'Marksman MK2',
    [GetHashKey('WEAPON_PRECISIONRIFLE')]   = 'Precision Rifle',
    [GetHashKey('WEAPON_PUMPSHOTGUN')]      = 'Pump Shotgun',
    [GetHashKey('WEAPON_SAWNOFFSHOTGUN')]   = 'Sawed-Off',
    [GetHashKey('WEAPON_ASSAULTSHOTGUN')]   = 'Assault Shotgun',
    [GetHashKey('WEAPON_DBSHOTGUN')]        = 'Double Barrel',
    [GetHashKey('WEAPON_RPG')]              = 'RPG',
    [GetHashKey('WEAPON_HOMINGLAUNCHER')]   = 'Homing Launcher',
    [GetHashKey('WEAPON_GRENADELAUNCHER')]  = 'Lance-grenades',
    [GetHashKey('WEAPON_COMPACTLAUNCHER')]  = 'Compact Launcher',
    [GetHashKey('WEAPON_EMPLAUNCHER')]      = 'EMP Launcher',
    [GetHashKey('WEAPON_MUSKET')]           = 'Mousquet',
    [GetHashKey('WEAPON_STUNGUN')]          = 'Stungun',
    [GetHashKey('WEAPON_MOLOTOV')]          = 'Molotov',
    [GetHashKey('WEAPON_GRENADE')]          = 'Grenade',
    [GetHashKey('WEAPON_KNIFE')]            = 'Couteau',
    [GetHashKey('WEAPON_BAT')]              = 'Batte',
    [GetHashKey('WEAPON_CROWBAR')]          = 'Pied-de-biche',
    [GetHashKey('WEAPON_SWITCHBLADE')]      = 'Cran d\'arret',
    [GetHashKey('WEAPON_HATCHET')]          = 'Hachette',
    [GetHashKey('WEAPON_MACHETE')]          = 'Machette',
}

local lastHudHP = 200

-- Callback NUI : changement de préférence HUD
RegisterNUICallback('setHudType', function(data, cb)
    local newType = data.hudType
    if newType ~= 'gta' and newType ~= 'vanta' then
        cb('ok')
        return
    end
    hudType = newType
    -- Sauvegarder en DB
    TriggerServerEvent('pvp_inventory:saveHudType', newType)

    if newType == 'gta' then
        -- Cacher le HUD VANTA, réactiver le HUD GTA
        SendNUIMessage({ type = 'vantaHud', action = 'hide' })
        DisplayRadar(true)
    else
        -- Afficher le HUD VANTA, cacher le HUD GTA
        SendNUIMessage({ type = 'vantaHud', action = 'show' })
        DisplayRadar(false)
    end
    cb('ok')
end)

-- Thread HUD VANTA : envoie les données au NUI toutes les 100ms
Citizen.CreateThread(function()
    while true do
        if hudType == 'vanta' then
            local ped = PlayerPedId()
            local health = GetEntityHealth(ped) - 100
            local armor  = GetPedArmour(ped)
            if health < 0  then health = 0  end
            if health > 100 then health = 100 end

            -- Détection dégâts
            local damaged = health < lastHudHP
            lastHudHP = health

            -- Arme actuelle
            local weaponHash = GetSelectedPedWeapon(ped)
            local weaponLabel = ''
            local ammo = -1
            local reserve = 0

            if weaponHash ~= GetHashKey('WEAPON_UNARMED') then
                weaponLabel = WeaponLabels[weaponHash] or 'Arme'
                local totalAmmo = GetAmmoInPedWeapon(ped, weaponHash)
                local clipSize  = GetWeaponClipSize(weaponHash)
                if clipSize > 0 then
                    ammo    = math.min(totalAmmo, clipSize)
                    reserve = math.max(0, totalAmmo - ammo)
                else
                    ammo = -1 -- Mêlée ou pas de chargeur
                end
            end

            SendNUIMessage({
                type    = 'vantaHud',
                action  = 'update',
                hp      = health,
                armor   = armor,
                weapon  = weaponLabel,
                ammo    = ammo,
                reserve = reserve,
                damaged = damaged,
            })

            -- Cacher le HUD GTA natif
            DisplayRadar(false)
            HideHudComponentThisFrame(1)  -- Wanted stars
            HideHudComponentThisFrame(2)  -- Weapon icon
            HideHudComponentThisFrame(3)  -- Cash
            HideHudComponentThisFrame(4)  -- MP Cash
            HideHudComponentThisFrame(6)  -- Vehicle name
            HideHudComponentThisFrame(7)  -- Area name
            HideHudComponentThisFrame(8)  -- Vehicle class
            HideHudComponentThisFrame(9)  -- Street name

            Citizen.Wait(100)
        else
            -- HUD GTA : s'assurer que le radar est visible
            DisplayRadar(true)
            Citizen.Wait(500) -- Pas besoin de vérifier souvent en mode GTA
        end
    end
end)

-- Appliquer la préférence HUD au login
RegisterNetEvent('pvp_inventory:setHudPreference')
AddEventHandler('pvp_inventory:setHudPreference', function(pref)
    if pref == 'vanta' then
        hudType = 'vanta'
        SendNUIMessage({ type = 'vantaHud', action = 'show' })
        DisplayRadar(false)
    else
        hudType = 'gta'
        SendNUIMessage({ type = 'vantaHud', action = 'hide' })
        DisplayRadar(true)
    end
end)

-- Helper : charger un dict d'animation
local function loadAnimDict(dict)
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 50 do
        Citizen.Wait(100)
        t = t + 1
    end
    return HasAnimDictLoaded(dict)
end

-- Fonction appelée pour démarrer un heal avec cooldown
function startHeal(itemName)
    local duration = HEAL_DURATIONS[itemName]
    if not duration then return false end

    if isHealing then
        notify('Déjà en train de se soigner !', 'warning')
        return false
    end

    isHealing = true
    healingItem = itemName
    healGeneration = healGeneration + 1
    local myGen = healGeneration

    -- Barre de progression NUI
    SendNUIMessage({ type = 'healStart', item = itemName, duration = duration })

    local ped = PlayerPedId()
    local wasCrouching = GetPedStealthMovement(ped)

    if itemName == 'bandage' then
        -- Animation bandage (debout, le joueur peut bouger après)
        if loadAnimDict('anim@heists@narcotics@funding@gang_idle') then
            TaskPlayAnim(ped, 'anim@heists@narcotics@funding@gang_idle', 'gang_chatting_idle01', 8.0, -8.0, duration, 49, 0, false, false, false)
        end
    elseif HEAL_FREEZE[itemName] then
        -- Medkit / Kevlar : accroupir + animation au sol
        SetPedStealthMovement(ped, true, "DEFAULT_ACTION")
        ClearPedTasks(ped)
        if loadAnimDict('anim@heists@narcotics@funding@gang_idle') then
            TaskPlayAnim(ped, 'anim@heists@narcotics@funding@gang_idle', 'gang_chatting_idle01', 8.0, -8.0, duration, 1, 0, false, false, false)
        end
    end

    -- Timer asynchrone
    Citizen.CreateThread(function()
        Citizen.Wait(duration)

        -- Si le heal a été annulé (mort, etc.), ne rien appliquer
        if myGen ~= healGeneration then return end

        local p = PlayerPedId()

        -- Arrêter l'animation
        ClearPedTasks(p)

        -- Relever le joueur si on l'avait accroupi
        if HEAL_FREEZE[itemName] and not wasCrouching then
            SetPedStealthMovement(p, false, "DEFAULT_ACTION")
        end

        -- Vérifier que le joueur est toujours vivant
        if IsEntityDead(p) then
            isHealing = false
            healingItem = nil
            SendNUIMessage({ type = 'healEnd' })
            return
        end

        -- Appliquer l'effet côté serveur (retire l'item + applique)
        TriggerServerEvent('pvp_inventory:useItemConfirmed', itemName)
        SendNUIMessage({ type = 'healEnd' })
        isHealing = false
        healingItem = nil
    end)

    return true
end

-- ── Détection de mort : vider inventaire ─────────────────────────────────
local wasDead = false

local function registerPvpDeath()
    -- Les stats PVP sont unifiées côté serveur via pvp_killfeed.
    -- On garde cette fonction pour ne pas casser les hooks baseevents.
end

RegisterNetEvent('baseevents:onPlayerDied')
AddEventHandler('baseevents:onPlayerDied', function()
    registerPvpDeath(nil)
end)

RegisterNetEvent('baseevents:onPlayerKilled')
AddEventHandler('baseevents:onPlayerKilled', function(killerClientId)
    local killerServerId = nil
    if killerClientId ~= nil then
        local killerClientNum = tonumber(killerClientId)
        if killerClientNum and killerClientNum >= 0 and killerClientNum ~= PlayerId() then
            killerServerId = GetPlayerServerId(killerClientNum)
        end
    end
    registerPvpDeath(killerServerId)
end)

Citizen.CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local isDead = IsEntityDead(ped)
        if isDead and not wasDead then
            -- Le joueur vient de mourir
            wasDead = true
            registerPvpDeath(nil)
            -- Annuler heal en cours (generation bump invalide le timer)
            isHealing = false
            healingItem = nil
            healGeneration = healGeneration + 1
            SendNUIMessage({ type = 'healEnd' })
            -- Retirer toutes les armes du ped
            RemoveAllPedWeapons(ped, true)
            equippedWeapons = {}
            -- Supprimer véhicule sorti
            if mySpawnedVehicle and DoesEntityExist(mySpawnedVehicle) then
                SetEntityAsMissionEntity(mySpawnedVehicle, true, true)
                DeleteEntity(mySpawnedVehicle)
                mySpawnedVehicle = nil
            end
            -- Vider inventaire côté serveur + créer death bag aux coords de mort
            local deathPos = GetEntityCoords(ped)
            TriggerServerEvent('pvp_inventory:playerDied', { x = deathPos.x, y = deathPos.y, z = deathPos.z })
            -- Fermer l'inventaire si ouvert
            if isOpen then closeInventory() end
        elseif not isDead and wasDead then
            wasDead = false
        end
        Citizen.Wait(500)
    end
end)

-- ══════════════════════════════════════════════════════════════════════════
--   CREW — NUI Callbacks (pont vers pvp_crew serveur)
-- ══════════════════════════════════════════════════════════════════════════

RegisterNUICallback('crewGetData', function(data, cb)
    ESX.TriggerServerCallback('pvp_crew:getMyCrewData', function(crewData)
        ESX.TriggerServerCallback('pvp_crew:getMyInvites', function(invites)
            ESX.TriggerServerCallback('pvp_crew:getOnlinePlayers', function(players)
                cb({
                    crew     = crewData,
                    invites  = invites or {},
                    players  = players or {},
                    crewCost = 5000,
                })
            end)
        end)
    end)
end)

RegisterNUICallback('crewCreate', function(data, cb)
    ESX.TriggerServerCallback('pvp_crew:createCrew', function(success, message)
        cb({ ok = success, message = message })
    end, data.name, data.tag)
end)

RegisterNUICallback('crewInvitePlayer', function(data, cb)
    ESX.TriggerServerCallback('pvp_crew:invitePlayer', function(success, message)
        cb({ ok = success, message = message })
    end, data.targetId)
end)

RegisterNUICallback('crewAcceptInvite', function(data, cb)
    ESX.TriggerServerCallback('pvp_crew:acceptInvite', function(success, message)
        cb({ ok = success, message = message })
    end, data.crewId)
end)

RegisterNUICallback('crewDeclineInvite', function(data, cb)
    ESX.TriggerServerCallback('pvp_crew:declineInvite', function(success, message)
        cb({ ok = success, message = message })
    end, data.crewId)
end)

RegisterNUICallback('crewKick', function(data, cb)
    ESX.TriggerServerCallback('pvp_crew:kickMember', function(success, message)
        cb({ ok = success, message = message })
    end, data.identifier)
end)

RegisterNUICallback('crewPromote', function(data, cb)
    ESX.TriggerServerCallback('pvp_crew:promoteMember', function(success, message)
        cb({ ok = success, message = message })
    end, data.identifier, data.rank)
end)

RegisterNUICallback('crewLeave', function(data, cb)
    ESX.TriggerServerCallback('pvp_crew:leaveCrew', function(success, message)
        cb({ ok = success, message = message })
    end)
end)

RegisterNUICallback('crewDisband', function(data, cb)
    ESX.TriggerServerCallback('pvp_crew:disbandCrew', function(success, message)
        cb({ ok = success, message = message })
    end)
end)

RegisterNUICallback('crewSetMotd', function(data, cb)
    ESX.TriggerServerCallback('pvp_crew:setMotd', function(success, message)
        cb({ ok = success, message = message })
    end, data.motd)
end)

RegisterNUICallback('crewSetColor', function(data, cb)
    ESX.TriggerServerCallback('pvp_crew:setColor', function(success, message)
        cb({ ok = success, message = message })
    end, data.color)
end)

RegisterNUICallback('crewAdvancedGetData', function(_, cb)
    ESX.TriggerServerCallback('pvp_crew:getAdvancedData', function(payload)
        cb(payload or { ok = false, message = 'Erreur crew.' })
    end)
end)

RegisterNUICallback('crewStashDeposit', function(data, cb)
    ESX.TriggerServerCallback('pvp_crew:stashDeposit', function(success, message)
        cb({ ok = success, message = message })
        if success then TriggerServerEvent('pvp_inventory:refreshData') end
    end, data.item, data.qty)
end)

RegisterNUICallback('crewStashWithdraw', function(data, cb)
    ESX.TriggerServerCallback('pvp_crew:stashWithdraw', function(success, message)
        cb({ ok = success, message = message })
        if success then TriggerServerEvent('pvp_inventory:refreshData') end
    end, data.item, data.qty)
end)

RegisterNUICallback('crewCreateEvent', function(data, cb)
    ESX.TriggerServerCallback('pvp_crew:createEvent', function(success, message)
        cb({ ok = success, message = message })
    end, data.title, data.type, data.startsAt)
end)

RegisterNUICallback('crewSetEventStatus', function(data, cb)
    ESX.TriggerServerCallback('pvp_crew:setEventStatus', function(success, message)
        cb({ ok = success, message = message })
    end, data.eventId, data.status)
end)

RegisterNUICallback('crewBuyShopItem', function(data, cb)
    ESX.TriggerServerCallback('pvp_crew:buyShopItem', function(success, message)
        cb({ ok = success, message = message })
    end, data.key)
end)

RegisterNUICallback('leaderboardGetData', function(_, cb)
    ESX.TriggerServerCallback('pvp_inventory:getLeaderboards', function(payload)
        cb(payload or {
            players = {},
            crews = {},
            myIdentifier = nil,
            myCrewId = nil
        })
    end)
end)

-- ══════════════════════════════════════════════════════════════════════════
--   DEATH BAGS — Sacs de loot au sol après la mort d'un joueur
-- ══════════════════════════════════════════════════════════════════════════

local deathBagPositions = {} -- [bagId] = { x, y, z }
local deathBagProps     = {} -- [bagId] = entityHandle
local currentDeathBagId = nil
local DEATH_BAG_MODEL   = GetHashKey('xm_prop_x17_bag_01a')
local DEATH_BAG_INTERACT_DIST = 2.0

-- ── Sync : demander les bags existants à la connexion ────────────────────
AddEventHandler('esx:playerLoaded', function()
    Citizen.CreateThread(function()
        Citizen.Wait(5000)
        TriggerServerEvent('pvp_inventory:requestDeathBagSync')
    end)
end)

-- ── Recevoir un nouveau death bag ────────────────────────────────────────
RegisterNetEvent('pvp_inventory:deathBagCreated')
AddEventHandler('pvp_inventory:deathBagCreated', function(bagId, coords)
    deathBagPositions[bagId] = coords
    -- Créer le prop
    RequestModel(DEATH_BAG_MODEL)
    local timeout = GetGameTimer()
    while not HasModelLoaded(DEATH_BAG_MODEL) and (GetGameTimer() - timeout) < 5000 do
        Citizen.Wait(10)
    end
    if HasModelLoaded(DEATH_BAG_MODEL) then
        local obj = CreateObject(DEATH_BAG_MODEL, coords.x, coords.y, coords.z - 0.5, false, false, false)
        PlaceObjectOnGroundProperly(obj)
        FreezeEntityPosition(obj, true)
        SetEntityCollision(obj, false, false)
        deathBagProps[bagId] = obj
    end
end)

-- ── Supprimer un death bag (vide ou expiré) ──────────────────────────────
RegisterNetEvent('pvp_inventory:deathBagRemoved')
AddEventHandler('pvp_inventory:deathBagRemoved', function(bagId)
    deathBagPositions[bagId] = nil
    if deathBagProps[bagId] and DoesEntityExist(deathBagProps[bagId]) then
        DeleteEntity(deathBagProps[bagId])
    end
    deathBagProps[bagId] = nil
    -- Fermer l'UI si on consultait ce sac
    if currentDeathBagId == bagId and isOpen then
        closeInventory()
        currentDeathBagId = nil
    end
end)

-- ── Thread : détection proximité + prompt E ──────────────────────────────
Citizen.CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        if not IsEntityDead(ped) and not isOpen then
            local pos = GetEntityCoords(ped)
            for bagId, coords in pairs(deathBagPositions) do
                local dist = #(pos - vector3(coords.x, coords.y, coords.z))
                if dist < DEATH_BAG_INTERACT_DIST then
                    sleep = 0
                    -- Afficher le texte d'aide
                    SetTextComponentFormat('STRING')
                    AddTextComponentString('~INPUT_CONTEXT~ Fouiller le sac')
                    DisplayHelpTextFromStringLabel(0, false, true, -1)
                    -- Appuyer sur E
                    if IsControlJustPressed(0, 38) then
                        TriggerServerEvent('pvp_inventory:requestDeathBag', bagId)
                    end
                    break
                end
            end
        end
        Citizen.Wait(sleep)
    end
end)

-- ── Ouvrir l'inventaire avec un death bag ────────────────────────────────
RegisterNetEvent('pvp_inventory:openUIWithDeathBag')
AddEventHandler('pvp_inventory:openUIWithDeathBag', function(data)
    currentDeathBagId = data.bagId
    isOpen = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    SendNUIMessage({ type = 'openDeathBag', data = data })
end)

-- ── Callback NUI : retirer un item du death bag ──────────────────────────
RegisterNUICallback('deathBagWithdraw', function(data, cb)
    TriggerServerEvent('pvp_inventory:deathBagWithdraw', data.bagId, data.item, data.qty)
    cb('ok')
end)

-- ── Callback NUI : fermer le death bag ───────────────────────────────────
RegisterNUICallback('closeDeathBag', function(_, cb)
    currentDeathBagId = nil
    closeInventory()
    cb('ok')
end)

-- ── Refresh du death bag ─────────────────────────────────────────────────
RegisterNetEvent('pvp_inventory:refreshDeathBag')
AddEventHandler('pvp_inventory:refreshDeathBag', function(data)
    SendNUIMessage({ type = 'refreshDeathBag', data = data })
end)

-- ══════════════════════════════════════════════════════════════════════════
--   VCOINS — NUI Callbacks (pont vers pvp_vcoins serveur)
-- ══════════════════════════════════════════════════════════════════════════

-- Relaie le sync VCoins depuis pvp_vcoins vers le NUI
local myTier = 'none' -- tier VCoins courant, mis à jour ici — gate le sélecteur de ped plus bas

RegisterNetEvent('pvp_vcoins:syncData')
AddEventHandler('pvp_vcoins:syncData', function(data)
    if not data then return end
    if data.tier then myTier = data.tier end
    local bonus = 0.0
    if data.tier == 'gold'    then bonus = 5.0
    elseif data.tier == 'diamond' then bonus = 10.0 end
    SendNUIMessage({
        type          = 'vcSync',
        tier          = data.tier,
        vcoins        = data.vcoins,
        expires       = data.expires,
        maxStashWeight = 20.0 + bonus,
    })
end)

RegisterNetEvent('pvp_vcoins:syncVCoins')
AddEventHandler('pvp_vcoins:syncVCoins', function(newBal)
    SendNUIMessage({ type = 'vcSync', vcoins = newBal })
end)

-- Refresh poids stash si l'abonnement change
-- Le serveur renverra maxStashWeight lors du prochain refresh complet (pas de logique client nécessaire).
AddEventHandler('pvp_inventory:refreshStashWeight', function() end)

RegisterNUICallback('vcGetData', function(_, cb)
    ESX.TriggerServerCallback('pvp_vcoins:getData', function(data)
        cb(data or {})
    end)
end)

RegisterNUICallback('vcSubscribe', function(data, cb)
    TriggerServerEvent('pvp_vcoins:subscribe', data.tier)
    cb({ ok = true })
end)

RegisterNUICallback('vcCreateOffer', function(data, cb)
    TriggerServerEvent('pvp_vcoins:createOffer', data.vcoinAmount, data.priceIngame)
    cb({ ok = true })
end)

RegisterNUICallback('vcCancelOffer', function(data, cb)
    TriggerServerEvent('pvp_vcoins:cancelOffer', data.offerId)
    cb({ ok = true })
end)

RegisterNUICallback('vcBuyOffer', function(data, cb)
    TriggerServerEvent('pvp_vcoins:buyOffer', data.offerId)
    cb({ ok = true })
end)

-- ══════════════════════════════════════════════════════════════════════════
--   PED SELECTOR — Preview en temps réel
-- ══════════════════════════════════════════════════════════════════════════
local pedSelectorOpen  = false
local pedSelectorState = nil   -- { modelHash, coords, heading, health, armor }
local pedSelectorCam   = nil

local function loadModel(model)
    RequestModel(model)
    local t = GetGameTimer()
    while not HasModelLoaded(model) and GetGameTimer() - t < 5000 do
        Citizen.Wait(0)
    end
end

local function isFreemodeModelPed(model)
    return model == '' or model == nil or model == 'mp_m_freemode_01' or model == 'mp_f_freemode_01'
end

local function restoreWeapons()
    local ped = PlayerPedId()
    for itemName, _ in pairs(equippedWeapons) do
        local hash = WEAPON_HASHES[itemName]
        if hash then
            GiveWeaponToPed(ped, hash, 9999, false, false)
            pcall(function()
                exports['pvp_outposts']:applyWeaponCustomForItem(itemName)
            end)
        end
    end
    SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
end

local function createPedPreviewCam()
    local ped     = PlayerPedId()
    local coords  = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    -- Caméra positionnée devant le joueur
    local fwdX = -math.sin(math.rad(heading))
    local fwdY =  math.cos(math.rad(heading))
    local camX = coords.x + fwdX * 2.5
    local camY = coords.y + fwdY * 2.5
    local camZ = coords.z + 0.3

    pedSelectorCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camX, camY, camZ, 0.0, 0.0, 0.0, 40.0, false, 0)
    PointCamAtCoord(pedSelectorCam, coords.x, coords.y, coords.z - 0.1)
    SetCamActive(pedSelectorCam, true)
    RenderScriptCams(true, true, 500, true, true)
end

local function destroyPedPreviewCam()
    RenderScriptCams(false, true, 500, true, true)
    if pedSelectorCam then
        DestroyCam(pedSelectorCam, false)
        pedSelectorCam = nil
    end
end

RegisterNUICallback('openPedSelector', function(_, cb)
    if myTier ~= 'gold' and myTier ~= 'diamond' then
        cb({ ok = false, reason = 'subscription' })
        TriggerEvent('esx:showNotification', '~r~Changement de ped réservé aux abonnés Gold / Diamond')
        return
    end
    cb({ ok = true })
    if pedSelectorOpen then return end
    local ped = PlayerPedId()
    pedSelectorState = {
        modelHash = GetEntityModel(ped),
        coords    = GetEntityCoords(ped),
        heading   = GetEntityHeading(ped),
        health    = GetEntityHealth(ped),
        armor     = GetPedArmour(ped),
    }
    pedSelectorOpen = true
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    createPedPreviewCam()
end)

RegisterNUICallback('previewPed', function(data, cb)
    cb({})
    if not pedSelectorOpen or not data or not data.model then return end
    local modelName = data.model
    local model     = GetHashKey(modelName)
    loadModel(model)
    if not HasModelLoaded(model) then return end

    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, pedSelectorState.coords.x, pedSelectorState.coords.y, pedSelectorState.coords.z, false, false, false, true)
    SetEntityHeading(ped, pedSelectorState.heading)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetEntityHealth(ped, 200)
    SetPedDefaultComponentVariation(ped)
end)

RegisterNUICallback('confirmPedModel', function(data, cb)
    cb({})
    if not pedSelectorOpen then return end
    pedSelectorOpen = false

    destroyPedPreviewCam()

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetEntityHealth(ped, pedSelectorState.health)
    SetPedArmour(ped, pedSelectorState.armor)

    restoreWeapons()

    local model = data and data.model or ''
    if isFreemodeModelPed(model) then
        pcall(function() exports['pvp_character']:ApplyStoredAppearance() end)
    end
    TriggerServerEvent('pvp_inventory:savePedModel', model)
end)

RegisterNUICallback('cancelPedSelector', function(_, cb)
    cb({})
    if not pedSelectorOpen then return end
    pedSelectorOpen = false

    -- Restaurer le modèle original
    local origHash = pedSelectorState.modelHash
    loadModel(origHash)
    SetPlayerModel(PlayerId(), origHash)
    SetModelAsNoLongerNeeded(origHash)

    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, pedSelectorState.coords.x, pedSelectorState.coords.y, pedSelectorState.coords.z, false, false, false, true)
    SetEntityHeading(ped, pedSelectorState.heading)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetEntityHealth(ped, pedSelectorState.health)
    SetPedArmour(ped, pedSelectorState.armor)
    SetPedDefaultComponentVariation(ped)

    destroyPedPreviewCam()

    -- Ré-appliquer l'apparence freemode d'origine (teinte, cheveux, tenue)
    local fmM = GetHashKey('mp_m_freemode_01')
    local fmF = GetHashKey('mp_f_freemode_01')
    if origHash == fmM or origHash == fmF then
        pcall(function() exports['pvp_character']:ApplyStoredAppearance() end)
    end

    restoreWeapons()
    pedSelectorState = nil
end)

-- Rejet serveur (pas d'abonnement / ped hors tier) : restaure le ped courant
RegisterNetEvent('pvp_inventory:pedModelRejected')
AddEventHandler('pvp_inventory:pedModelRejected', function()
    local ped = PlayerPedId()
    local currentHash = GetEntityModel(ped)
    local fmM = GetHashKey('mp_m_freemode_01')
    local fmF = GetHashKey('mp_f_freemode_01')

    if currentHash == fmM or currentHash == fmF then
        pcall(function() exports['pvp_character']:ApplyStoredAppearance() end)
    end
    restoreWeapons()
end)
