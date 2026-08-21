-- =============================================
--   PVP OUTPOSTS - Client
--   Zones safe, blips, NPCs, interactions
-- =============================================

local ESX              = nil
local inSafeZone       = false
local nearNpc          = nil   -- 'teleport' | 'shop' | 'stash' | 'weapon_custom' | 'vehicle_custom'
local nearOutpost      = nil   -- référence à l'outpost actif
local weaponCustomsCache = {}  -- { [weaponName] = { components = {}, tint = 0 } }
local weaponCustomCam  = nil   -- caméra NUI custom arme
local weaponCustomOpen = false
local weaponCustomNpc  = nil   -- entity du NPC armurier (pour hide/show)
local weaponCustomOldHeading = nil -- heading du joueur avant ouverture

-- Noms d'affichage français pour toutes les armes
local WEAPON_DISPLAY_NAMES = {
    weapon_pistol            = 'Pistolet',
    weapon_combatpistol      = 'Pistolet de Combat',
    weapon_heavypistol       = 'Pistolet Lourd',
    weapon_snspistol         = 'Pistolet SNS',
    weapon_vintagepistol     = 'Pistolet Vintage',
    weapon_revolver          = 'Revolver',
    weapon_doubleaction      = 'Revolver Double Action',
    weapon_machinepistol     = 'Pistolet Mitrailleur',
    weapon_appistol          = 'Pistolet AP',
    weapon_pistol_mk2        = 'Pistolet MK2',
    weapon_snspistol_mk2     = 'Pistolet SNS MK2',
    weapon_microsmg          = 'Micro SMG',
    weapon_minismg           = 'Mini SMG',
    weapon_smg               = 'SMG',
    weapon_combatpdw         = 'PDW de Combat',
    weapon_smg_mk2           = 'SMG MK2',
    weapon_pumpshotgun       = 'Shotgun Pump',
    weapon_sawnoffshotgun    = 'Shotgun Scié',
    weapon_assaultshotgun    = 'Shotgun d\'Assaut',
    weapon_dbshotgun         = 'Shotgun Double Canon',
    weapon_assaultrifle      = 'Fusil d\'Assaut',
    weapon_assaultrifle_mk2  = 'Fusil d\'Assaut MK2',
    weapon_carbinerifle      = 'Carabine',
    weapon_carbinerifle_mk2  = 'Carabine MK2',
    weapon_specialcarbine    = 'Carabine Spéciale',
    weapon_specialcarbine_mk2= 'Carabine Spéciale MK2',
    weapon_compactrifle      = 'Fusil Compact',
    weapon_combatmg          = 'Mitrailleuse de Combat',
    weapon_combatmg_mk2      = 'Mitrailleuse de Combat MK2',
    weapon_mg                = 'Mitrailleuse',
    weapon_sniperrifle       = 'Fusil de Sniper',
    weapon_precisionrifle    = 'Fusil de Précision',
    weapon_marksmanrifle_mk2 = 'Fusil Marksman MK2',
    weapon_stungun           = 'Pistolet Électrique',
    weapon_musket            = 'Mousquet',
}
local jumpCooldown   = false
local boostCooldown  = false
local shuntCooldown  = false
local lastXPress     = 0       -- timestamp du dernier appui X (pour double tap)

-- ── Commande /coords — copie position + heading dans le presse-papier ───
RegisterCommand('coords', function()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local head = GetEntityHeading(ped)
    local text = string.format('vector3(%.1f, %.1f, %.1f)  heading = %.1f', pos.x, pos.y, pos.z, head)

    -- Copier dans le presse-papier via NUI
    SendNUIMessage({ action = 'copyToClipboard', text = text })

    -- Aussi afficher dans le chat + F8
    TriggerEvent('chat:addMessage', { args = { 'COORDS', text } })
    print('[coords] ' .. text)
end, false)

RegisterNUICallback('clipboardDone', function(data, cb)
    TriggerEvent('chat:addMessage', { args = { 'COORDS', '~g~Copié dans le presse-papier !' } })
    cb({ ok = true })
end)

-- ── ESX ───────────────────────────────────────────────────────────────────
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(200)
    end
end)

-- ── Forcer le jour en permanence (12h00) ─────────────────────────────────
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        NetworkOverrideClockTime(12, 0, 0)
    end
end)

-- ── Utilitaires ───────────────────────────────────────────────────────────
local function getDistance(a, b)
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z))
end

local function getSafeRadius(op)
    return op.safeRadius or Config.SafeZoneRadius
end

-- Trouve l'avant-poste le plus proche des coordonnées données
function GetNearestOutpost(coords)
    local nearest, nearestDist = nil, math.huge
    for _, op in ipairs(Config.Outposts) do
        local d = getDistance(coords, op.coords)
        if d < nearestDist then
            nearest     = op
            nearestDist = d
        end
    end
    return nearest
end

-- ── Utilitaire blip ──────────────────────────────────────────────────────
local function addBlip(coords, sprite, color, scale, name, shortRange, minimapOnly)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite)
    -- display=2 → minimap radar uniquement (pas sur la grande map pause)
    -- display=3 → minimap + grande map
    SetBlipDisplay(blip, minimapOnly and 2 or 3)
    SetBlipScale(blip, scale)
    SetBlipColour(blip, color)
    SetBlipAsShortRange(blip, shortRange)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(name)
    EndTextCommandSetBlipName(blip)
    return blip
end

-- ── Blips sur la carte ────────────────────────────────────────────────────
local npcBlips = {}  -- blips internes à masquer/afficher selon la zone

Citizen.CreateThread(function()
    for idx, op in ipairs(Config.Outposts) do
        -- Zone safe verte (cercle sur la minimap uniquement)
        local radius = getSafeRadius(op)
        local zoneBlip = AddBlipForRadius(op.coords.x, op.coords.y, op.coords.z, radius + 0.0)
        SetBlipColour(zoneBlip, 2)
        SetBlipAlpha(zoneBlip, 60)
        SetBlipDisplay(zoneBlip, 5)  -- minimap uniquement

        -- Blip principal au centre (minimap uniquement)
        addBlip(op.coords, 473, 2, 1.0, op.label, false, true)

        -- Blips NPC internes (minimap uniquement, masqués par défaut)
        npcBlips[idx] = {}

    end
end)

-- ── Spawn des NPCs ────────────────────────────────────────────────────────
-- Récupère le Z exact du sol à une position donnée
local function getGroundZ(x, y, z)
    local found, groundZ = GetGroundZFor_3dCoord(x, y, z + 5.0, false)
    if found then return groundZ end
    return z
end

local function spawnNpc(coords, heading, model)
    local hash = GetHashKey(model)
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) do
        Citizen.Wait(10)
        timeout = timeout + 10
        if timeout > 5000 then
            print('[pvp_outposts] ERREUR: modèle NPC ' .. model .. ' impossible à charger! Abandon.')
            return nil
        end
    end

    -- Forcer le chargement du terrain
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    Citizen.Wait(100)

    -- Correction automatique du Z au sol
    local z = coords.z
    local found, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 5.0, false)
    if found then z = groundZ end

    local ped = CreatePed(4, hash, coords.x, coords.y, z, heading, false, true)
    if ped == 0 or ped == nil then
        print('[pvp_outposts] ERREUR: CreatePed retourné 0 pour ' .. model .. ' à ' .. tostring(coords))
        return nil
    end
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    FreezeEntityPosition(ped, true)
    SetModelAsNoLongerNeeded(hash)
    print('[pvp_outposts] NPC spawné: ' .. model .. ' (entity=' .. tostring(ped) .. ')')
    return ped
end

-- ── Spawn d'un prop ──────────────────────────────────────────────────────
local function spawnProp(coords, heading, model)
    local hash = GetHashKey(model)
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) do
        Citizen.Wait(10)
        timeout = timeout + 10
        if timeout > 5000 then
            print('[pvp_outposts] ERREUR: modèle prop ' .. model .. ' impossible à charger!')
            return nil
        end
    end

    -- Forcer le chargement du terrain
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    Citizen.Wait(200)

    -- Correction automatique du Z au sol
    local z = coords.z
    local found, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 5.0, false)
    if found then
        z = groundZ
        print('[pvp_outposts] Prop groundZ trouvé: ' .. groundZ)
    else
        print('[pvp_outposts] Prop groundZ NON trouvé, utilise Z=' .. z)
    end

    local obj = CreateObject(hash, coords.x, coords.y, z, false, false, false)
    print('[pvp_outposts] CreateObject résultat: ' .. tostring(obj) .. ' pour ' .. model)
    if obj == 0 or obj == nil then
        print('[pvp_outposts] ERREUR: CreateObject retourné 0 pour ' .. model)
        return nil
    end
    SetEntityHeading(obj, heading or 0.0)
    FreezeEntityPosition(obj, true)
    SetEntityInvincible(obj, true)
    SetModelAsNoLongerNeeded(hash)
    print('[pvp_outposts] Prop spawné OK: ' .. model .. ' à ' .. coords.x .. ', ' .. coords.y .. ', ' .. z)
    return obj
end

-- ── Spawn des NPCs/props par proximité (terrain doit être chargé) ────────
local spawnedOutposts = {}  -- idx → true si déjà spawné
local spawnedEntities = {}  -- liste de toutes les entités spawnées (pour cleanup)

-- Nettoyage au restart de la resource
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for i, entity in ipairs(spawnedEntities) do
        if DoesEntityExist(entity) then
            SetEntityAsMissionEntity(entity, true, true)
            SetEntityAsNoLongerNeeded(entity)
            DetachEntity(entity, true, true)
            DeleteObject(entity)
            if DoesEntityExist(entity) then
                DeleteEntity(entity)
            end
        end
    end
    spawnedEntities = {}
    spawnedOutposts = {}
end)

local function spawnOutpostEntities(idx, op)
    if spawnedOutposts[idx] then return end
    spawnedOutposts[idx] = true

    print('[pvp_outposts] Spawn des entités pour ' .. op.label .. ' (idx=' .. idx .. ')')

    -- NPC téléporteur (pilote militaire)
    if op.npcTeleport then
        print('[pvp_outposts]   -> NPC Téléporteur à ' .. tostring(op.npcTeleport))
        local ent = spawnNpc(op.npcTeleport, op.headingTeleport or op.heading, 's_m_y_pilot_01')
        if ent then table.insert(spawnedEntities, ent) end
        Citizen.Wait(200)
    end

    -- NPC marchand (paramédic)
    if op.npcShop then
        print('[pvp_outposts]   -> NPC Boutique à ' .. tostring(op.npcShop))
        local ent = spawnNpc(op.npcShop, op.headingShop or op.heading, 's_m_m_paramedic_01')
        if ent then table.insert(spawnedEntities, ent) end
        Citizen.Wait(200)
    end

    -- NPC custom armes (mécanicien armée)
    if op.npcWeaponCustom then
        print('[pvp_outposts]   -> NPC Custom Armes à ' .. tostring(op.npcWeaponCustom))
        local ent = spawnNpc(op.npcWeaponCustom, op.headingWeaponCustom or op.heading, 's_m_y_armymech_01')
        if ent then
            table.insert(spawnedEntities, ent)
            weaponCustomNpc = ent
        end
        Citizen.Wait(200)
    end

    -- NPC custom véhicules (mécanicien)
    if op.npcVehicleCustom then
        print('[pvp_outposts]   -> NPC Custom Véhicules à ' .. tostring(op.npcVehicleCustom))
        local ent = spawnNpc(op.npcVehicleCustom, op.headingVehicleCustom or op.heading, 's_m_m_autoshop_01')
        if ent then table.insert(spawnedEntities, ent) end
        Citizen.Wait(200)
    else
        print('[pvp_outposts]   -> PAS de npcVehicleCustom défini pour ' .. op.label)
    end


    -- Prop coffre (caisse militaire)
    if op.stashProp then
        print('[pvp_outposts]   -> Prop Coffre à ' .. tostring(op.stashProp))
        local obj = spawnProp(op.stashProp, op.stashPropHeading or op.heading, 'prop_mil_crate_01')
        if obj then
            table.insert(spawnedEntities, obj)
            print('[pvp_outposts]   -> Coffre OK (entity=' .. tostring(obj) .. ')')
        else
            print('[pvp_outposts]   -> ECHEC spawn coffre!')
        end
    else
        print('[pvp_outposts]   -> PAS de stashProp défini pour ' .. op.label)
    end

    print('[pvp_outposts] NPCs/props spawnés pour ' .. op.label)
end

-- Thread de spawn par proximité (150m)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(2000)
        local coords = GetEntityCoords(PlayerPedId())
        for idx, op in ipairs(Config.Outposts) do
            if not spawnedOutposts[idx] then
                local d = #(coords - op.coords)
                if d < 150.0 then
                    spawnOutpostEntities(idx, op)
                end
            end
        end
    end
end)

-- ── Marqueurs 3D au-dessus des NPCs (DrawMarker = 100% stable) ──────────
-- DrawMarker est rendu par le moteur GTA directement, zéro jitter
local function drawNpcMarker(x, y, z, r, g, b, label)
    -- DrawMarker type 21 (chevron) = rendu 3D natif GTA, 0 mouvement
    DrawMarker(21,
        x, y, z + 1.3,
        0.0, 0.0, 0.0,
        0.0, 180.0, 0.0,
        0.4, 0.4, 0.4,
        r, g, b, 220,
        false, false, 2, false, nil, nil, false
    )
end

-- ── Boucle principale : zones safe + invincibilité + interaction NPCs ────
local lastSafeIdx        = nil   -- index de l'outpost safe zone précédent
local wasInSafeZone      = false -- pour détecter la transition sortie
local safeZoneGraceUntil = 0    -- GetGameTimer() timestamp fin de grâce (3 sec)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(300)

        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)

        inSafeZone  = false
        nearNpc     = nil
        nearOutpost = nil
        local currentSafeIdx = nil

        for idx, op in ipairs(Config.Outposts) do
            local d = getDistance(coords, op.coords)
            local radius = getSafeRadius(op)

            -- Zone safe
            if d < radius then
                inSafeZone  = true
                nearOutpost = op
                currentSafeIdx = idx

                -- NPC Téléporteur (dans les 3m)
                if getDistance(coords, op.npcTeleport) < 3.0 then
                    nearNpc = 'teleport'
                -- NPC Boutique
                elseif getDistance(coords, op.npcShop) < 3.0 then
                    nearNpc = 'shop'
                -- NPC Custom Armes
                elseif op.npcWeaponCustom and getDistance(coords, op.npcWeaponCustom) < 3.0 then
                    nearNpc = 'weapon_custom'
                -- NPC Custom Véhicules
                elseif op.npcVehicleCustom and getDistance(coords, op.npcVehicleCustom) < 5.0 then
                    nearNpc = 'vehicle_custom'
                -- Prop Coffre
                elseif op.stashProp and getDistance(coords, op.stashProp) < 2.5 then
                    nearNpc = 'stash'
                end
                break
            end
        end

        -- Afficher/masquer les blips NPC et icônes selon la zone safe
        if currentSafeIdx ~= lastSafeIdx then
            -- Masquer les blips de l'ancien outpost
            if lastSafeIdx and npcBlips[lastSafeIdx] then
                for _, b in ipairs(npcBlips[lastSafeIdx]) do
                    SetBlipAlpha(b, 0)
                end
            end
            -- Afficher les blips du nouvel outpost
            if currentSafeIdx and npcBlips[currentSafeIdx] then
                for _, b in ipairs(npcBlips[currentSafeIdx]) do
                    SetBlipAlpha(b, 255)
                end
            end

            lastSafeIdx = currentSafeIdx
        end

        -- Détection sortie de zone safe → grâce 3 secondes
        if wasInSafeZone and not inSafeZone then
            safeZoneGraceUntil = GetGameTimer() + 3000
            TriggerEvent('pvp_hud:showGrace', 3)
        end
        wasInSafeZone = inSafeZone

        -- Protection = en zone safe OU pendant la grâce post-safe
        local isProtected = inSafeZone or (GetGameTimer() < safeZoneGraceUntil)

        -- Invincibilité
        SetEntityInvincible(ped, isProtected)

        -- Désactiver / réactiver PvP selon zone
        NetworkSetFriendlyFireOption(not isProtected)
        SetCanAttackFriendly(ped, not isProtected, not isProtected)
    end
end)

-- ── Bloquer les attaques émises pendant la période de grâce ─────────────
Citizen.CreateThread(function()
    while true do
        if GetGameTimer() < safeZoneGraceUntil then
            Citizen.Wait(0)
            DisableControlAction(0, 24,  true) -- ATTACK (tir)
            DisableControlAction(0, 25,  true) -- AIM (visée)
            DisableControlAction(0, 140, true) -- MELEE_ATTACK_LIGHT
            DisableControlAction(0, 141, true) -- MELEE_ATTACK_HEAVY
            DisableControlAction(0, 142, true) -- MELEE_ATTACK_ALTERNATE
        else
            Citizen.Wait(500)
        end
    end
end)

-- ── Affichage des hints, marqueurs au sol et marqueurs NPC ──────────────
Citizen.CreateThread(function()

    while true do
        Citizen.Wait(0)

        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)

        for _, op in ipairs(Config.Outposts) do
            local d = getDistance(coords, op.coords)
            local radius = getSafeRadius(op)

            -- Cercle au sol de la zone safe
            if d < radius + 20.0 then
                DrawMarker(1,
                    op.coords.x, op.coords.y, op.coords.z - 0.8,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    radius * 2, radius * 2, 0.5,
                    80, 200, 80, 25,
                    false, false, 2, false, nil, nil, false
                )
            end
        end

        -- Marqueurs 3D au-dessus des NPCs (uniquement en zone safe)
        if inSafeZone and nearOutpost then
            local op = nearOutpost
            if op.npcShop then
                drawNpcMarker(op.npcShop.x, op.npcShop.y, op.npcShop.z, 229, 57, 53, 'Boutique')           -- rouge
            end
            if op.npcWeaponCustom then
                drawNpcMarker(op.npcWeaponCustom.x, op.npcWeaponCustom.y, op.npcWeaponCustom.z, 255, 152, 0, 'Armurerie')  -- orange
            end
            if op.npcVehicleCustom then
                drawNpcMarker(op.npcVehicleCustom.x, op.npcVehicleCustom.y, op.npcVehicleCustom.z, 33, 150, 243, 'Garage') -- bleu
                -- Cercle vert au sol indiquant la zone de personnalisation (rayon 5m)
                DrawMarker(1,
                    op.npcVehicleCustom.x, op.npcVehicleCustom.y, op.npcVehicleCustom.z - 0.95,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    10.0, 10.0, 0.5,
                    0, 200, 80, 40,
                    false, false, 2, false, nil, nil, false
                )
            end
            if op.npcTeleport then
                drawNpcMarker(op.npcTeleport.x, op.npcTeleport.y, op.npcTeleport.z, 156, 39, 176, 'Teleport')  -- violet
            end
            if op.stashProp then
                drawNpcMarker(op.stashProp.x, op.stashProp.y, op.stashProp.z, 76, 175, 80, 'Coffre')       -- vert
            end

        end

        -- Texte d'aide si proche d'un NPC
        if nearNpc == 'teleport' then
            ESX.ShowHelpNotification('[E] Téléportation entre avant-postes')
        elseif nearNpc == 'shop' then
            ESX.ShowHelpNotification('[E] Ouvrir la boutique')
        elseif nearNpc == 'stash' then
            ESX.ShowHelpNotification('[E] Ouvrir votre coffre')
        elseif nearNpc == 'weapon_custom' then
            ESX.ShowHelpNotification('[E] Armurerie (achat/vente/custom)')
        elseif nearNpc == 'vehicle_custom' then
            local hasDiamond = false
            pcall(function() hasDiamond = exports['pvp_vcoins']:HasDiamond() end)
            if hasDiamond then
                ESX.ShowHelpNotification('[E] Garage (achat/vente/custom)')
            else
                ESX.ShowHelpNotification('[E] Garage ~r~(Diamond requis)')
            end
        end

        if inSafeZone and nearNpc == nil then
            ESX.ShowHelpNotification('~g~Zone Safe~s~ — Invincible')
        end
    end
end)

-- ── Touche E : interaction NPC ─────────────────────────────────────────────
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        if nearNpc ~= nil and IsControlJustReleased(0, 38) then -- E

            if nearNpc == 'teleport' then
                openTeleportMenu()
            elseif nearNpc == 'shop' then
                openShopMenu()
            elseif nearNpc == 'stash' then
                openStashMenu()
            elseif nearNpc == 'weapon_custom' then
                openWeaponCustomMenu()
            elseif nearNpc == 'vehicle_custom' then
                -- Customisation véhicule : réservé aux abonnés Diamond
                local hasDiamond = false
                local ok = pcall(function()
                    hasDiamond = exports['pvp_vcoins']:HasDiamond()
                end)
                if ok and hasDiamond then
                    openVehicleCustomMenu()
                else
                    ESX.ShowNotification('~r~Accès réservé aux abonnés ~y~DIAMOND')
                end
            end

        end
    end
end)

-- ── Menu Téléportation (NUI Map) ─────────────────────────────────────────
function openTeleportMenu()
    local outpostList = {}
    for _, op in ipairs(Config.Outposts) do
        table.insert(outpostList, {
            id        = op.id,
            label     = op.label,
            specialty = op.specialty or 'all',
            x         = op.coords.x,
            y         = op.coords.y,
        })
    end

    local currentId = nil
    if nearOutpost then currentId = nearOutpost.id end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action         = 'openTeleportMap',
        outposts       = outpostList,
        currentOutpostId = currentId,
    })
end

-- NUI Callback : téléporter vers un avant-poste
RegisterNUICallback('teleportTo', function(data, cb)
    SetNuiFocus(false, false)
    if data.outpostId then
        TriggerServerEvent('pvp_outposts:teleport', data.outpostId)
    end
    cb({ ok = true })
end)

-- NUI Callback : fermer la map
RegisterNUICallback('closeTeleportMap', function(data, cb)
    SetNuiFocus(false, false)
    cb({ ok = true })
end)

-- ── Menu Boutique NUI ────────────────────────────────────────────────────
function openShopMenu(forceSpecialty)
    if nearOutpost == nil then return end

    local specialty = forceSpecialty or nearOutpost.specialty or 'all'

    -- Sélection des items vendables selon la spécialité
    local shopList = Config.ShopItems
    if specialty == 'weapons' then
        shopList = Config.WeaponShopItems
    elseif specialty == 'vehicles' then
        shopList = Config.VehicleShopItems
    elseif specialty == 'medical' then
        shopList = Config.MedicalShopItems
    end

    -- Récupérer les items vendables du joueur (callback serveur)
    ESX.TriggerServerCallback('pvp_outposts:getPlayerItems', function(sellItemsList)
        local xPlayer = ESX.GetPlayerData()
        local bankBalance = 0
        for _, acc in ipairs(xPlayer.accounts) do
            if acc.name == 'bank' then
                bankBalance = acc.money
                break
            end
        end

        SetNuiFocus(true, true)
        SendNUIMessage({
            action    = 'openShop',
            items     = shopList,
            sellItems = sellItemsList,
            specialty = specialty,
            balance   = bankBalance,
            outpostId = nearOutpost.id,
        })
    end)
end

-- ── NUI Callbacks ─────────────────────────────────────────────────────────

-- Fermer le shop
RegisterNUICallback('closeShop', function(data, cb)
    SetNuiFocus(false, false)
    cb({ ok = true })
end)

-- Acheter le panier — attend la vraie confirmation du serveur
RegisterNUICallback('buyCart', function(data, cb)
    if nearOutpost == nil then
        cb({ ok = false, message = 'Erreur : outpost introuvable.' })
        return
    end
    ESX.TriggerServerCallback('pvp_outposts:buyCartCb', function(success, message, newBalance)
        cb({ ok = success, message = message, balance = newBalance })
    end, data.items, data.destination)
end)

-- Vendre un item — attend la confirmation serveur
RegisterNUICallback('sellItem', function(data, cb)
    ESX.TriggerServerCallback('pvp_outposts:sellItemCb', function(success, message, newBalance)
        cb({ ok = success, message = message, balance = newBalance })
    end, data.item)
end)

-- Vendre tout l'inventaire — attend la confirmation serveur
RegisterNUICallback('sellAll', function(data, cb)
    ESX.TriggerServerCallback('pvp_outposts:sellAllCb', function(success, message, newBalance)
        cb({ ok = success, message = message, balance = newBalance })
    end, data.specialty or 'all')
end)

-- (buyCartResult supprimé — la réponse passe maintenant par ESX.TriggerServerCallback)

-- ── Coffre (ouvre l'inventaire NUI avec section coffre avant-poste) ──────
function openStashMenu()
    if nearOutpost == nil then return end
    TriggerServerEvent('pvp_inventory:requestOutpostStash', nearOutpost.id, nearOutpost.label)
end

-- ── Export : est-ce que le joueur est en zone safe ? ─────────────────────
exports('IsInSafeZone', function()
    return inSafeZone
end)

-- ── Export : source de vérité des véhicules apocalypse ──────────────────
exports('getApocalypseVehicles', function()
    return Config.ApocalypseVehicles or {}
end)

-- ── Retour de téléportation ───────────────────────────────────────────────
RegisterNetEvent('pvp_outposts:doTeleport')
AddEventHandler('pvp_outposts:doTeleport', function(coords, heading)
    local ped = PlayerPedId()
    DoScreenFadeOut(300)
    while not IsScreenFadedOut() do Citizen.Wait(0) end

    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false, true)
    SetEntityHeading(ped, heading)

    Citizen.Wait(500)
    DoScreenFadeIn(300)
end)

-- ── Notification achat/vente ─────────────────────────────────────────────
RegisterNetEvent('pvp_outposts:buyResult')
AddEventHandler('pvp_outposts:buyResult', function(success, message)
    if success then
        ESX.ShowNotification('~g~' .. message)
    else
        ESX.ShowNotification('~r~' .. message)
    end
end)

RegisterNetEvent('pvp_outposts:sellResult')
AddEventHandler('pvp_outposts:sellResult', function(success, message)
    if success then
        ESX.ShowNotification('~g~' .. message)
    else
        ESX.ShowNotification('~r~' .. message)
    end
end)

-- Mise à jour du solde dans le NUI après vente
RegisterNetEvent('pvp_outposts:nuiBalanceUpdate')
AddEventHandler('pvp_outposts:nuiBalanceUpdate', function(newBalance)
    SendNUIMessage({ action = 'updateBalance', balance = newBalance })
end)

-- ══════════════════════════════════════════════════════════════════════════
--   ARMES — Menu principal (acheter/vendre + personnaliser)
-- ══════════════════════════════════════════════════════════════════════════
function openWeaponCustomMenu()
    local elements = {
        { label = 'Acheter / Vendre des armes',  value = 'shop'   },
        { label = 'Personnaliser l\'arme équipée', value = 'custom' },
    }

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'weapon_main_menu',
        { title = 'Armurerie', align = 'top-left', elements = elements },
        function(data, menu)
            menu.close()
            if data.current.value == 'shop' then
                openShopMenu('weapons')
            elseif data.current.value == 'custom' then
                openWeaponNUI()
            end
        end,
        function(data, menu)
            menu.close()
        end
    )
end

-- ── Sauvegarde la custom de l'arme courante ───────────────────────────────
function saveWeaponCustom(weaponName, weaponHash)
    local ped   = PlayerPedId()
    local comps = {}
    if Config.WeaponComponents[weaponName] then
        for _, comp in ipairs(Config.WeaponComponents[weaponName]) do
            local compHash = GetHashKey(comp.component)
            if HasPedGotWeaponComponent(ped, weaponHash, compHash) then
                table.insert(comps, comp.component)
            end
        end
    end
    local tint = 0
    if Config.WeaponsTintEnabled[weaponName] then
        tint = GetPedWeaponTintIndex(ped, weaponHash)
    end
    weaponCustomsCache[weaponName] = { components = comps, tint = tint }
    TriggerServerEvent('pvp_weaponcustom:save', weaponName, { components = comps, tint = tint })
end

-- ── Applique une custom à une arme ────────────────────────────────────────
function applyWeaponCustom(ped, weaponHash, data)
    if data.components then
        for _, compName in ipairs(data.components) do
            GiveWeaponComponentToPed(ped, weaponHash, GetHashKey(compName))
        end
    end
    if data.tint ~= nil then
        SetPedWeaponTintIndex(ped, weaponHash, data.tint)
    end
end

-- ── Applique toutes les customs en cache ─────────────────────────────────
function applyAllWeaponCustoms()
    local ped = PlayerPedId()
    for weaponName, data in pairs(weaponCustomsCache) do
        local wHash = GetHashKey(string.upper(weaponName))
        if HasPedGotWeapon(ped, wHash, false) then
            applyWeaponCustom(ped, wHash, data)
        end
    end
end

-- ── Export : applique la custom d'une arme spécifique (appelé par pvp_inventory) ─
function applyWeaponCustomForItem(itemName)
    local data = weaponCustomsCache[itemName]
    if not data then return end
    local ped   = PlayerPedId()
    local wHash = GetHashKey(string.upper(itemName))
    if HasPedGotWeapon(ped, wHash, false) then
        applyWeaponCustom(ped, wHash, data)
    end
end

-- ── Thread : réapplique les customs toutes les 2s ────────────────────────
-- Garantit que les customs sont bien sur l'arme après respawn/reco/inventaire
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(2000)
        if next(weaponCustomsCache) ~= nil then
            applyAllWeaponCustoms()
        end
    end
end)

-- ── Chargement des customs au login ──────────────────────────────────────
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function()
    Citizen.CreateThread(function()
        Citizen.Wait(4000)  -- Attend que pvp_inventory ait chargé les armes
        TriggerServerEvent('pvp_weaponcustom:loadAll')
    end)
end)

-- ── Recharge aussi après chaque respawn (mort → spawn) ───────────────────
AddEventHandler('playerSpawned', function()
    Citizen.CreateThread(function()
        Citizen.Wait(4000)  -- Attend que pvp_inventory redonne les armes
        TriggerServerEvent('pvp_weaponcustom:loadAll')
    end)
end)

RegisterNetEvent('pvp_weaponcustom:applyAll')
AddEventHandler('pvp_weaponcustom:applyAll', function(customs)
    weaponCustomsCache = customs or {}
    applyAllWeaponCustoms()
end)

-- ══════════════════════════════════════════════════════════════════════════
--   ARMES — Panneau NUI custom (caméra 3D + VANTA design)
-- ══════════════════════════════════════════════════════════════════════════

-- ── Crée la caméra zoomée sur la main droite du joueur ────────────────────
function createWeaponCamera(ped)
    local pedPos = GetEntityCoords(ped)
    local fwd    = GetEntityForwardVector(ped)

    -- Caméra de face : 3m devant le joueur, hauteur yeux, corps entier visible
    local camPos = vector3(
        pedPos.x + fwd.x * 3.0,
        pedPos.y + fwd.y * 3.0,
        pedPos.z + 0.5
    )

    -- Vise le centre du corps (mi-hauteur)
    local targetPos = vector3(pedPos.x, pedPos.y, pedPos.z + 0.4)

    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(cam, targetPos.x, targetPos.y, targetPos.z)
    SetCamFov(cam, 40.0)
    RenderScriptCams(true, false, 0, true, true)
    return cam
end

-- ── Ouvre le panneau NUI custom arme ─────────────────────────────────────
function openWeaponNUI()
    local ped = PlayerPedId()
    local _, currentWeaponHash = GetCurrentPedWeapon(ped)

    -- Trouver l'arme dans la config
    local weaponName = nil
    for name, _ in pairs(Config.WeaponComponents) do
        if GetHashKey(string.upper(name)) == currentWeaponHash then
            weaponName = name
            break
        end
    end

    if not weaponName then
        ESX.ShowNotification('~r~Équipez d\'abord une arme customisable.')
        return
    end

    local hasTints = Config.WeaponsTintEnabled[weaponName] == true
    local compList = Config.WeaponComponents[weaponName] or {}

    -- Build composants avec état actuel
    local compData = {}
    for _, comp in ipairs(compList) do
        local compHash = GetHashKey(comp.component)
        table.insert(compData, {
            name   = comp.component,
            label  = comp.label,
            active = HasPedGotWeaponComponent(ped, currentWeaponHash, compHash),
        })
    end

    local currentTint = 0
    if hasTints then
        currentTint = GetPedWeaponTintIndex(ped, currentWeaponHash)
    end

    -- Sauvegarder le heading actuel et tourner le joueur face à la caméra
    weaponCustomOldHeading = GetEntityHeading(ped)
    SetCurrentPedWeapon(ped, currentWeaponHash, true)

    -- Cacher le NPC armurier pour ne pas gêner la vue
    if weaponCustomNpc and DoesEntityExist(weaponCustomNpc) then
        SetEntityVisible(weaponCustomNpc, false, false)
    end

    -- Geler le ped + caméra de face instantanée
    FreezeEntityPosition(ped, true)
    weaponCustomCam  = createWeaponCamera(ped)
    weaponCustomOpen = true

    SetNuiFocus(true, true)
    SendNUIMessage({
        action      = 'openWeaponCustom',
        weaponName  = weaponName,
        displayName = WEAPON_DISPLAY_NAMES[weaponName] or weaponName,
        components  = compData,
        currentTint = currentTint,
        hasTints    = hasTints,
    })
end

-- ── Fermeture : restore caméra + ped ─────────────────────────────────────
function closeWeaponNUI()
    weaponCustomOpen = false
    SetNuiFocus(false, false)

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)

    -- Restaurer le heading d'origine
    if weaponCustomOldHeading then
        SetEntityHeading(ped, weaponCustomOldHeading)
        weaponCustomOldHeading = nil
    end

    -- Réafficher le NPC armurier
    if weaponCustomNpc and DoesEntityExist(weaponCustomNpc) then
        SetEntityVisible(weaponCustomNpc, true, false)
    end

    if weaponCustomCam then
        RenderScriptCams(false, true, 500, true, true)
        Citizen.SetTimeout(500, function()
            if weaponCustomCam then
                DestroyCam(weaponCustomCam, false)
                weaponCustomCam = nil
            end
        end)
    end
end

-- ── NUI callbacks ────────────────────────────────────────────────────────
RegisterNUICallback('wc_close', function(_, cb)
    closeWeaponNUI()
    cb({})
end)

RegisterNUICallback('wc_toggle_comp', function(data, cb)
    local ped = PlayerPedId()
    local _, wHash = GetCurrentPedWeapon(ped)
    local compHash = GetHashKey(data.component)
    if data.active then
        GiveWeaponComponentToPed(ped, wHash, compHash)
    else
        RemoveWeaponComponentFromPed(ped, wHash, compHash)
    end
    cb({})
end)

RegisterNUICallback('wc_set_tint', function(data, cb)
    local ped = PlayerPedId()
    local _, wHash = GetCurrentPedWeapon(ped)
    SetPedWeaponTintIndex(ped, wHash, data.tint)
    cb({})
end)

RegisterNUICallback('wc_save', function(_, cb)
    local ped = PlayerPedId()
    local _, wHash = GetCurrentPedWeapon(ped)
    local weaponName = nil
    for name, _ in pairs(Config.WeaponComponents) do
        if GetHashKey(string.upper(name)) == wHash then
            weaponName = name
            break
        end
    end
    if weaponName then
        saveWeaponCustom(weaponName, wHash)
    end
    cb({})
end)

-- ══════════════════════════════════════════════════════════════════════════
--   VÉHICULES — Menu principal (acheter/vendre + personnaliser)
--   Redirige vers pvp_garage NUI pour customisation et concessionnaire
-- ══════════════════════════════════════════════════════════════════════════
function openVehicleCustomMenu()
    local elements = {
        { label = 'Acheter un véhicule',        value = 'dealer'  },
        { label = 'Personnaliser le véhicule',   value = 'custom'  },
    }

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'vehicle_main_menu',
        { title = 'Garage', align = 'top-left', elements = elements },
        function(data, menu)
            menu.close()
            if data.current.value == 'dealer' then
                TriggerEvent('pvp_garage:openDealer')
            elseif data.current.value == 'custom' then
                TriggerEvent('pvp_garage:openMechanic')
            end
        end,
        function(data, menu)
            menu.close()
        end
    )
end

-- ══════════════════════════════════════════════════════════════════════════
--   UTILITAIRES CUSTOM VÉHICULE — Sérialisation / Application des mods
-- ══════════════════════════════════════════════════════════════════════════

-- Extraire toutes les customs d'un véhicule (pour sauvegarde)
function getVehicleCustomData(veh)
    SetVehicleModKit(veh, 0)
    local primary, secondary = GetVehicleColours(veh)
    local data = {
        mods       = {},
        primary    = primary,
        secondary  = secondary,
        windowTint = GetVehicleWindowTint(veh),
        xenon      = IsToggleModOn(veh, 22),
        turbo      = IsToggleModOn(veh, 18),
        arenaBoost = Entity(veh).state.arena_boost or false,
        arenaJump  = Entity(veh).state.arena_jump  or false,
    }
    for modType = 0, 49 do
        local numMods = GetNumVehicleMods(veh, modType)
        if numMods > 0 then
            local mod = GetVehicleMod(veh, modType)
            if mod ~= -1 then
                data.mods[tostring(modType)] = mod
            end
        end
    end
    return data
end

-- Appliquer des customs sauvegardées sur un véhicule
function applyVehicleCustomData(veh, data)
    if not data then return end
    SetVehicleModKit(veh, 0)

    if data.primary and data.secondary then
        SetVehicleColours(veh, data.primary, data.secondary)
    end
    if data.windowTint then
        SetVehicleWindowTint(veh, data.windowTint)
    end
    if data.xenon then
        ToggleVehicleMod(veh, 22, true)
    end
    if data.turbo then
        ToggleVehicleMod(veh, 18, true)
    end
    if data.mods then
        for modTypeStr, modIndex in pairs(data.mods) do
            SetVehicleMod(veh, tonumber(modTypeStr), modIndex, false)
        end
    end
    -- Restaurer les capacités Apocalypse
    if data.arenaBoost then
        Entity(veh).state:set('arena_boost', true, true)
    end
    if data.arenaJump then
        Entity(veh).state:set('arena_jump', true, true)
    end
end

-- Event : appliquer une custom reçue du serveur (après spawn véhicule)
RegisterNetEvent('pvp_vehiclecustom:apply')
AddEventHandler('pvp_vehiclecustom:apply', function(customData)
    if not customData then return end
    -- Attendre que le joueur soit bien dans le véhicule (timing MySQL async)
    local ped = PlayerPedId()
    local attempts = 0
    while not IsPedInAnyVehicle(ped, false) and attempts < 20 do
        Citizen.Wait(100)
        ped = PlayerPedId()
        attempts = attempts + 1
    end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then
        SetVehicleModKit(veh, 0)
        applyVehicleCustomData(veh, customData)
    end
end)

-- ══════════════════════════════════════════════════════════════════════════
--   VÉHICULES — Menu customisation principal
-- ══════════════════════════════════════════════════════════════════════════

function openVehicleCustomSubMenu()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if veh == 0 then
        ESX.ShowNotification('~r~Montez dans un vehicule d\'abord.')
        return
    end

    -- IMPORTANT : initialiser le kit de mods avant toute modification
    SetVehicleModKit(veh, 0)

    -- Détecter si c'est un véhicule apocalypse (Arena War)
    local vehModel = GetEntityModel(veh)
    local isApocalypse = false
    for _, model in ipairs(Config.ApocalypseVehicles) do
        if GetHashKey(model) == vehModel then
            isApocalypse = true
            break
        end
    end

    local elements = {
        { label = 'Modifications (performances & carrosserie)', value = 'mods'   },
        { label = 'Apparence (couleurs, Xenon, vitres)',        value = 'extras'  },
    }
    if isApocalypse then
        table.insert(elements, { label = '~o~Mods Apocalypse (boost, shunt, saut)', value = 'apocalypse' })
    end
    table.insert(elements, { label = '~y~Enregistrer cette custom', value = 'save' })

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'vehicle_custom_menu',
        { title = 'Atelier Mecanique — Gratuit', align = 'top-left', elements = elements },
        function(data, menu)
            menu.close()
            if data.current.value == 'mods' then
                openVehicleModsMenu(veh)
            elseif data.current.value == 'extras' then
                openVehicleExtrasMenu(veh)
            elseif data.current.value == 'apocalypse' then
                openApocalypseModsMenu(veh)
            elseif data.current.value == 'save' then
                -- Sauvegarder la custom du véhicule
                local customData = getVehicleCustomData(veh)
                local itemName = Entity(veh).state.pvp_itemName
                if itemName then
                    TriggerServerEvent('pvp_vehiclecustom:save', itemName, customData)
                    ESX.ShowNotification('~g~Custom enregistree ! Tous vos futurs ' .. (Entity(veh).state.pvp_itemLabel or itemName) .. ' auront cette apparence.')
                else
                    ESX.ShowNotification('~r~Ce vehicule ne peut pas etre customise (pas un vehicule PVP).')
                end
                openVehicleCustomSubMenu()
            end
        end,
        function(data, menu)
            menu.close()
        end
    )
end

-- ── Sous-menu : catégories de mods (performances & carrosserie) ─────────
function openVehicleModsMenu(veh)
    SetVehicleModKit(veh, 0)

    local elements = {
        {
            label   = '~g~[BOOST] Tout maximiser (performances)',
            value   = 'maxall',
            isMax   = true,
            isTurbo = false,
            numMods = 0,
        }
    }

    for _, mod in ipairs(Config.VehicleMods) do
        local numMods = GetNumVehicleMods(veh, mod.modType)
        if numMods > 0 or mod.isTurbo then
            local current = ''
            if mod.isTurbo then
                current = IsToggleModOn(veh, 18) and ' ~g~[ON]' or ' ~r~[OFF]'
            else
                local idx = GetVehicleMod(veh, mod.modType)
                local lbl = (idx == -1) and 'Stock' or ('Niv.' .. (idx + 1) .. '/' .. numMods)
                current = ' [' .. lbl .. ']'
            end
            table.insert(elements, {
                label   = mod.label .. current,
                value   = mod.modType,
                isTurbo = mod.isTurbo or false,
                isMax   = false,
                numMods = numMods,
            })
        end
    end

    if #elements == 1 then
        ESX.ShowNotification('~r~Aucune modification disponible pour ce vehicule.')
        openVehicleCustomSubMenu()
        return
    end

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'vehicle_mods_cat',
        { title = 'Modifications', align = 'top-left', elements = elements },
        function(data, menu)
            if data.current.isMax then
                local perfMods = {11, 12, 13, 15, 16}
                for _, modType in ipairs(perfMods) do
                    local n = GetNumVehicleMods(veh, modType)
                    if n > 0 then SetVehicleMod(veh, modType, n - 1, false) end
                end
                ToggleVehicleMod(veh, 18, true)
                ESX.ShowNotification('~g~Performances maximisees !')
                menu.close()
                openVehicleModsMenu(veh)
            elseif data.current.isTurbo then
                ToggleVehicleMod(veh, 18, not IsToggleModOn(veh, 18))
                menu.close()
                openVehicleModsMenu(veh)
            else
                menu.close()
                openVehicleModLevelMenu(veh, data.current.value, data.current.numMods)
            end
        end,
        function(data, menu)
            menu.close()
            openVehicleCustomSubMenu()  -- ← Retour au menu parent
        end
    )
end

-- ── Sous-menu : niveaux d'un mod ────────────────────────────────────────
function openVehicleModLevelMenu(veh, modType, numMods)
    local currentMod = GetVehicleMod(veh, modType)
    local elements = {
        { label = (currentMod == -1 and '~g~> ' or '') .. 'Stock (origine)', value = -1 }
    }
    for i = 0, numMods - 1 do
        local prefix = (currentMod == i) and '~g~> ' or ''
        local suffix = (i == numMods - 1) and ' ~y~[MAX]' or ''
        table.insert(elements, { label = prefix .. 'Niveau ' .. (i + 1) .. suffix, value = i })
    end

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'vehicle_mod_level',
        { title = 'Choisir le niveau', align = 'top-left', elements = elements },
        function(data, menu)
            if data.current.value == -1 then
                RemoveVehicleMod(veh, modType)
            else
                SetVehicleMod(veh, modType, data.current.value, false)
            end
            menu.close()
            openVehicleModsMenu(veh)  -- Retour à la liste des mods (rafraîchie)
        end,
        function(data, menu)
            menu.close()
            openVehicleModsMenu(veh)  -- ← Retour au menu parent
        end
    )
end

-- ── Sous-menu : apparence (couleurs, Xenon, vitres) ─────────────────────
function openVehicleExtrasMenu(veh)
    SetVehicleModKit(veh, 0)
    local primary, secondary = GetVehicleColours(veh)
    local xenonOn = IsToggleModOn(veh, 22)
    local tint    = GetVehicleWindowTint(veh)

    local tintLabels = { [0]='Aucune', [1]='Noir total', [2]='Fume fonce', [3]='Fume clair', [4]='Stock', [5]='Limousine', [6]='Verte' }
    local tintLabel = tintLabels[tint] or 'Inconnue'

    local elements = {
        { label = 'Couleur principale  ~s~> changer',       value = 'primary'   },
        { label = 'Couleur secondaire  ~s~> changer',       value = 'secondary' },
        { label = (xenonOn and '~g~[ON]~s~' or '~r~[OFF]~s~') .. ' Phares Xenon', value = 'xenon' },
        { label = 'Teinte des vitres  [' .. tintLabel .. ']', value = 'tint'     },
    }

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'vehicle_extras_menu',
        { title = 'Apparence', align = 'top-left', elements = elements },
        function(data, menu)
            if data.current.value == 'primary' then
                menu.close()
                openVehicleColorsMenu(veh, false)
            elseif data.current.value == 'secondary' then
                menu.close()
                openVehicleColorsMenu(veh, true)
            elseif data.current.value == 'xenon' then
                ToggleVehicleMod(veh, 22, not IsToggleModOn(veh, 22))
                menu.close()
                openVehicleExtrasMenu(veh)  -- Refresh pour mettre à jour le label
            elseif data.current.value == 'tint' then
                menu.close()
                openVehicleTintMenu(veh)
            end
        end,
        function(data, menu)
            menu.close()
            openVehicleCustomSubMenu()  -- ← Retour au menu parent
        end
    )
end

-- ── Sous-menu : choix de couleur (principale ou secondaire) ─────────────
function openVehicleColorsMenu(veh, isSecondary)
    local primary, secondary = GetVehicleColours(veh)
    local currentColor = isSecondary and secondary or primary
    local title = isSecondary and 'Couleur secondaire' or 'Couleur principale'

    local elements = {}
    for _, c in ipairs(Config.VehicleColors) do
        local prefix = (c.color == currentColor) and '~g~> ' or ''
        table.insert(elements, { label = prefix .. c.label, value = c.color })
    end

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'vehicle_colors',
        { title = title, align = 'top-left', elements = elements },
        function(data, menu)
            local col = data.current.value
            if isSecondary then
                SetVehicleColours(veh, primary, col)
            else
                SetVehicleColours(veh, col, secondary)
            end
            menu.close()
            openVehicleExtrasMenu(veh)  -- Retour au menu apparence
        end,
        function(data, menu)
            menu.close()
            openVehicleExtrasMenu(veh)  -- ← Retour au menu parent
        end
    )
end

-- ── Sous-menu : teinte des vitres ───────────────────────────────────────
function openVehicleTintMenu(veh)
    local currentTint = GetVehicleWindowTint(veh)
    local tints = {
        { label = 'Aucune (transparente)',  value = 0 },
        { label = 'Noir total',             value = 1 },
        { label = 'Fume fonce',            value = 2 },
        { label = 'Fume clair',            value = 3 },
        { label = 'Stock',                  value = 4 },
        { label = 'Limousine',              value = 5 },
        { label = 'Verte',                  value = 6 },
    }
    local elements = {}
    for _, t in ipairs(tints) do
        local prefix = (t.value == currentTint) and '~g~> ' or ''
        table.insert(elements, { label = prefix .. t.label, value = t.value })
    end

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'vehicle_tint',
        { title = 'Teinte des vitres', align = 'top-left', elements = elements },
        function(data, menu)
            SetVehicleWindowTint(veh, data.current.value)
            menu.close()
            openVehicleExtrasMenu(veh)  -- Retour au menu apparence
        end,
        function(data, menu)
            menu.close()
            openVehicleExtrasMenu(veh)  -- ← Retour au menu parent
        end
    )
end

-- ══════════════════════════════════════════════════════════════════════════
--   MODS APOCALYPSE — Boost Nitro & Saut Hydraulique (custom FiveM)
--   Ces capacités ne sont PAS des mods GTA natifs pour Arena War.
--   On les implémente manuellement via ApplyForceToEntity / SetVehicleForwardSpeed.
-- ══════════════════════════════════════════════════════════════════════════

function openApocalypseModsMenu(veh)
    SetVehicleModKit(veh, 0)

    local boostOn = Entity(veh).state.arena_boost or false
    local jumpOn  = Entity(veh).state.arena_jump  or false

    local elements = {
        {
            label = (boostOn and '~g~[ACTIF]' or '~r~[INACTIF]') .. '~s~  Boost / Shunt  ~c~(X×2 = boost, X+clic = lateral)',
            value = 'boost',
            isAbility = true,
        },
        {
            label = (jumpOn and '~g~[ACTIF]' or '~r~[INACTIF]') .. '~s~  Saut Hydraulique  ~c~(E en roulant)',
            value = 'jump',
            isAbility = true,
        },
    }

    -- Ajouter les mods Arena War natifs disponibles sur ce véhicule
    for _, mod in ipairs(Config.ApocalypseMods) do
        local numMods = GetNumVehicleMods(veh, mod.modType)
        if numMods > 0 then
            local idx = GetVehicleMod(veh, mod.modType)
            local lbl = (idx == -1) and 'Stock' or ('Niv.' .. (idx + 1) .. '/' .. numMods)
            table.insert(elements, {
                label   = '~o~' .. mod.label .. '~s~  [' .. lbl .. ']',
                value   = mod.modType,
                isAbility = false,
                numMods = numMods,
            })
        end
    end

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'vehicle_apocalypse',
        { title = 'Mods Apocalypse', align = 'top-left', elements = elements },
        function(data, menu)
            if data.current.isAbility then
                if data.current.value == 'boost' then
                    Entity(veh).state:set('arena_boost', not boostOn, true)
                    ESX.ShowNotification(not boostOn and '~g~Boost/Shunt active ! (X×2 = boost, X+clic = lateral)' or '~r~Boost/Shunt desactive.')
                elseif data.current.value == 'jump' then
                    Entity(veh).state:set('arena_jump', not jumpOn, true)
                    ESX.ShowNotification(not jumpOn and '~g~Saut Hydraulique active ! (E)' or '~r~Saut Hydraulique desactive.')
                end
                menu.close()
                openApocalypseModsMenu(veh)
            else
                -- Ouvrir le sous-menu des niveaux pour ce mod Arena
                menu.close()
                openApocalypseModLevelMenu(veh, data.current.value, data.current.numMods)
            end
        end,
        function(data, menu)
            menu.close()
            openVehicleCustomSubMenu()  -- ← Retour au menu parent
        end
    )
end

-- ── Sous-menu : niveaux d'un mod Arena War ────────────────────────────
function openApocalypseModLevelMenu(veh, modType, numMods)
    local currentMod = GetVehicleMod(veh, modType)
    local elements = {
        { label = (currentMod == -1 and '~g~> ' or '') .. 'Stock (aucun)', value = -1 }
    }
    for i = 0, numMods - 1 do
        local prefix = (currentMod == i) and '~g~> ' or ''
        table.insert(elements, { label = prefix .. 'Variante ' .. (i + 1), value = i })
    end

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'vehicle_arena_mod_level',
        { title = 'Choisir la variante', align = 'top-left', elements = elements },
        function(data, menu)
            if data.current.value == -1 then
                RemoveVehicleMod(veh, modType)
            else
                SetVehicleMod(veh, modType, data.current.value, false)
            end
            menu.close()
            openApocalypseModsMenu(veh)
        end,
        function(data, menu)
            menu.close()
            openApocalypseModsMenu(veh)
        end
    )
end

-- ══════════════════════════════════════════════════════════════════════════
--   THREAD — Boost, Shunt & Saut (Arena War custom)
--   X double tap     = boost avant (rocket natif GTA)
--   X maintenu + clic gauche = shunt gauche
--   X maintenu + clic droit  = shunt droite
--   E = saut hydraulique
-- ══════════════════════════════════════════════════════════════════════════
local DOUBLE_TAP_MS = 300  -- fenêtre pour le double tap X (ms)
local xHeld = false        -- X est maintenu

Citizen.CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            Citizen.Wait(0)
            local veh = GetVehiclePedIsIn(ped, false)

            if GetPedInVehicleSeat(veh, -1) == ped then
                local hasBoost = Entity(veh).state.arena_boost

                if hasBoost then
                    -- Tracker l'état de la touche X (INPUT_VEH_DUCK = 73)
                    if IsControlPressed(0, 73) then
                        xHeld = true
                    end

                    -- ── X appuyé : double tap = boost, maintenu + clic = shunt ──
                    if IsControlJustPressed(0, 73) then
                        local now = GetGameTimer()
                        if (now - lastXPress) < DOUBLE_TAP_MS and not boostCooldown then
                            -- DOUBLE TAP X → Boost avant (rocket natif)
                            boostCooldown = true
                            SetVehicleRocketBoostActive(veh, true)
                            SetVehicleRocketBoostPercentage(veh, 100.0)
                            StartScreenEffect('RaceTurbo', 1500, false)
                            Citizen.SetTimeout(1500, function()
                                SetVehicleRocketBoostActive(veh, false)
                            end)
                            Citizen.SetTimeout(3000, function()
                                boostCooldown = false
                                SetVehicleRocketBoostPercentage(veh, 100.0)
                            end)
                            lastXPress = 0  -- reset pour pas re-trigger
                        else
                            lastXPress = now
                        end
                    end

                    -- ── X maintenu + clic = shunt latéral ──
                    if xHeld and not shuntCooldown then
                        local dir = nil
                        if IsControlJustPressed(0, 24) then dir = -15.0 end  -- clic gauche → shunt gauche
                        if IsControlJustPressed(0, 25) then dir = 15.0  end  -- clic droit  → shunt droite
                        if dir then
                            shuntCooldown = true
                            ApplyForceToEntity(veh, 1, dir, 0.0, 0.0, 0.0, 0.0, 0.0, 0, true, true, true, false, true)
                            StartScreenEffect('FocusOut', 300, false)
                            Citizen.SetTimeout(2000, function()
                                shuntCooldown = false
                            end)
                        end
                    end

                    -- Reset xHeld quand relâché
                    if IsControlJustReleased(0, 73) then
                        xHeld = false
                    end
                end

                -- ── Saut Hydraulique (E = INPUT_PICKUP = 38) ─────────────
                if Entity(veh).state.arena_jump and IsControlJustPressed(0, 38) and not jumpCooldown then
                    jumpCooldown = true
                    ApplyForceToEntity(veh, 1, 0.0, 0.0, 18.0, 0.0, 0.0, 0.0, 0, true, true, true, false, true)
                    Citizen.SetTimeout(2500, function()
                        jumpCooldown = false
                    end)
                end
            end
        else
            Citizen.Wait(500)
        end
    end
end)

-- =============================================
--   TÉLÉPORTATION PAR WAYPOINT (carte)
--   En safe zone, poser un waypoint sur un
--   avant-poste → prompt E pour se téléporter
-- =============================================

local waypointTarget   = nil   -- outpost matché par le waypoint
local waypointPromptOn = false -- prompt affiché à l'écran

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)

        -- Seulement si le joueur est en zone safe
        if not inSafeZone then
            if waypointTarget then
                waypointTarget   = nil
                waypointPromptOn = false
            end
            goto continue
        end

        -- Vérifier si un waypoint est posé
        local wpBlip = GetFirstBlipInfoId(8) -- 8 = waypoint
        if not DoesBlipExist(wpBlip) then
            if waypointTarget then
                waypointTarget   = nil
                waypointPromptOn = false
            end
            goto continue
        end

        -- Récupérer les coords du waypoint
        local wpCoords = GetBlipInfoIdCoord(wpBlip)

        -- Chercher un avant-poste proche du waypoint (< 80m en 2D)
        local matched = nil
        for _, op in ipairs(Config.Outposts) do
            local dx = wpCoords.x - op.coords.x
            local dy = wpCoords.y - op.coords.y
            local dist2d = math.sqrt(dx * dx + dy * dy)
            if dist2d < 80.0 then
                -- Ne pas proposer l'avant-poste dans lequel on est déjà
                if nearOutpost == nil or nearOutpost.id ~= op.id then
                    matched = op
                end
                break
            end
        end

        waypointTarget = matched
        waypointPromptOn = (matched ~= nil)

        ::continue::
    end
end)

-- Thread pour le prompt NUI + détection touche E
local wpPromptShown = false

Citizen.CreateThread(function()
    while true do
        if waypointPromptOn and waypointTarget then
            -- Afficher le prompt NUI
            if not wpPromptShown then
                wpPromptShown = true
                SendNUIMessage({ type = 'waypointPrompt', show = true, label = waypointTarget.label })
            end

            -- E = INPUT_PICKUP = 38
            if IsControlJustPressed(0, 38) then
                wpPromptShown = false
                SendNUIMessage({ type = 'waypointPrompt', show = false })
                local targetId = waypointTarget.id
                waypointTarget = nil
                waypointPromptOn = false
                -- Supprimer le waypoint
                SetWaypointOff()
                -- Demander la TP au serveur
                TriggerServerEvent('pvp_outposts:teleport', targetId)
            end

            Citizen.Wait(0)
        else
            -- Cacher le prompt si visible
            if wpPromptShown then
                wpPromptShown = false
                SendNUIMessage({ type = 'waypointPrompt', show = false })
            end
            Citizen.Wait(300)
        end
    end
end)
