-- [VARIABLES]
local ESX = nil
local menuOpen = false
local currentVehicle = nil
local originalMods = nil

-- [CAMERA ORBITALE]
local garageCam = nil
local camAngleH = 0.0    -- angle horizontal (degrés)
local camAngleV = 20.0   -- angle vertical (degrés)
local camRadius = 6.0    -- distance du véhicule
local CAM_MIN_V = -5.0
local CAM_MAX_V = 60.0
local CAM_MIN_R = 3.0
local CAM_MAX_R = 12.0
local CAM_FOV   = 50.0

-- [ESX INIT]
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(100)
    end
end)

-- [FIND NEAREST VEHICLE]
local function GetNearestVehicle(playerPed, radius)
    local playerCoords = GetEntityCoords(playerPed)
    local vehicle = nil
    local minDist = radius + 1.0

    -- Check if player is in vehicle first
    if IsPedInAnyVehicle(playerPed, false) then
        return GetVehiclePedIsIn(playerPed, false)
    end

    -- Search nearby vehicles
    local handle, veh = FindFirstVehicle()
    local found = true
    while found do
        local vehCoords = GetEntityCoords(veh)
        local dist = #(playerCoords - vehCoords)
        if dist < minDist then
            minDist = dist
            vehicle = veh
        end
        found, veh = FindNextVehicle(handle)
    end
    EndFindVehicle(handle)

    return vehicle
end

-- [SAVE ORIGINAL MODS]
local function SaveOriginalMods(veh)
    local mods = {}
    mods.primaryColor, mods.secondaryColor = GetVehicleColours(veh)
    mods.pearlescentColor, mods.wheelColor = GetVehicleExtraColours(veh)
    mods.wheelType = GetVehicleWheelType(veh)
    mods.wheelMod = GetVehicleMod(veh, 23)
    mods.engineMod = GetVehicleMod(veh, 11)
    mods.brakesMod = GetVehicleMod(veh, 12)
    mods.transmissionMod = GetVehicleMod(veh, 13)
    mods.armorMod = GetVehicleMod(veh, 16)
    mods.turbo = IsToggleModOn(veh, 18)
    mods.suspensionMod = GetVehicleMod(veh, 15)
    mods.livery = GetVehicleLivery(veh)
    mods.windowTint = GetVehicleWindowTint(veh)
    mods.xenon = IsToggleModOn(veh, 22)
    mods.xenonColor = GetVehicleXenonLightsColor(veh)

    mods.neonEnabled = {}
    for i = 0, 3 do
        mods.neonEnabled[i] = IsVehicleNeonLightEnabled(veh, i)
    end
    mods.neonR, mods.neonG, mods.neonB = GetVehicleNeonLightsColour(veh)

    -- Special mods for apocalypse
    mods.specialMods = {}
    for _, sm in ipairs(Config.SpecialMods) do
        mods.specialMods[sm.modIndex] = GetVehicleMod(veh, sm.modIndex)
    end

    return mods
end

-- [RESTORE ORIGINAL MODS]
local function RestoreOriginalMods(veh, mods)
    if not mods or not DoesEntityExist(veh) then return end

    SetVehicleModKit(veh, 0)
    SetVehicleColours(veh, mods.primaryColor, mods.secondaryColor)
    SetVehicleExtraColours(veh, mods.pearlescentColor, mods.wheelColor)
    SetVehicleWheelType(veh, mods.wheelType)
    SetVehicleMod(veh, 23, mods.wheelMod, false)
    SetVehicleMod(veh, 11, mods.engineMod, false)
    SetVehicleMod(veh, 12, mods.brakesMod, false)
    SetVehicleMod(veh, 13, mods.transmissionMod, false)
    SetVehicleMod(veh, 16, mods.armorMod, false)
    ToggleVehicleMod(veh, 18, mods.turbo)
    SetVehicleMod(veh, 15, mods.suspensionMod, false)
    if mods.livery >= 0 then
        SetVehicleLivery(veh, mods.livery)
    end
    SetVehicleWindowTint(veh, mods.windowTint)
    ToggleVehicleMod(veh, 22, mods.xenon)
    if mods.xenon then
        SetVehicleXenonLightsColor(veh, mods.xenonColor)
    end
    for i = 0, 3 do
        SetVehicleNeonLightEnabled(veh, i, mods.neonEnabled[i])
    end
    SetVehicleNeonLightsColour(veh, mods.neonR, mods.neonG, mods.neonB)

    for modIdx, modVal in pairs(mods.specialMods) do
        SetVehicleMod(veh, modIdx, modVal, false)
    end
end

-- [GET VEHICLE DATA FOR NUI]
local function GetVehicleCustomData(veh)
    local data = {}

    SetVehicleModKit(veh, 0)

    -- Colors
    local pc, sc = GetVehicleColours(veh)
    local pearl, wc = GetVehicleExtraColours(veh)
    data.primaryColor = pc
    data.secondaryColor = sc
    data.pearlescentColor = pearl
    data.wheelColor = wc

    -- Wheels
    data.wheelType = GetVehicleWheelType(veh)
    data.wheelMod = GetVehicleMod(veh, 23)
    data.numWheelMods = GetNumVehicleMods(veh, 23)

    -- Performance
    data.engineLevel = GetVehicleMod(veh, 11)
    data.numEngineLevels = GetNumVehicleMods(veh, 11)
    data.brakesLevel = GetVehicleMod(veh, 12)
    data.numBrakesLevels = GetNumVehicleMods(veh, 12)
    data.transmissionLevel = GetVehicleMod(veh, 13)
    data.numTransmissionLevels = GetNumVehicleMods(veh, 13)
    data.armorLevel = GetVehicleMod(veh, 16)
    data.numArmorLevels = GetNumVehicleMods(veh, 16)
    data.turboEnabled = IsToggleModOn(veh, 18)
    data.suspensionLevel = GetVehicleMod(veh, 15)
    data.numSuspensionLevels = GetNumVehicleMods(veh, 15)

    -- Livery
    data.livery = GetVehicleLivery(veh)
    data.numLiveries = GetVehicleLiveryCount(veh)

    -- Neon
    data.neonEnabled = {}
    for i = 0, 3 do
        data.neonEnabled[tostring(i)] = IsVehicleNeonLightEnabled(veh, i)
    end
    local nr, ng, nb = GetVehicleNeonLightsColour(veh)
    data.neonR = nr
    data.neonG = ng
    data.neonB = nb

    -- Window tint
    data.windowTint = GetVehicleWindowTint(veh)

    -- Xenon
    data.xenonEnabled = IsToggleModOn(veh, 22)
    data.xenonColor = GetVehicleXenonLightsColor(veh)

    -- Check apocalypse
    local model = GetEntityModel(veh)
    data.isApocalypse = Config.ApocalypseVehicles[model] == true

    -- Special mods data
    if data.isApocalypse then
        data.specialMods = {}
        for _, sm in ipairs(Config.SpecialMods) do
            local numMods = GetNumVehicleMods(veh, sm.modIndex)
            data.specialMods[sm.id] = {
                current = GetVehicleMod(veh, sm.modIndex),
                numMods = numMods,
            }
        end
    end

    return data
end

-- [CAMERA ORBITALE — fonctions]
local function UpdateGarageCam()
    if not garageCam or not currentVehicle or not DoesEntityExist(currentVehicle) then return end

    local vehPos = GetEntityCoords(currentVehicle)
    -- Centre un peu plus haut que le sol du véhicule
    local targetZ = vehPos.z + 0.5

    local radH = math.rad(camAngleH)
    local radV = math.rad(camAngleV)

    local camX = vehPos.x + camRadius * math.cos(radV) * math.sin(radH)
    local camY = vehPos.y + camRadius * math.cos(radV) * math.cos(radH)
    local camZ = targetZ  + camRadius * math.sin(radV)

    SetCamCoord(garageCam, camX, camY, camZ)
    PointCamAtCoord(garageCam, vehPos.x, vehPos.y, targetZ)
end

local function CreateGarageCam()
    if garageCam then
        DestroyCam(garageCam, false)
    end

    -- Angle initial : face à l'avant du véhicule
    if currentVehicle and DoesEntityExist(currentVehicle) then
        local heading = GetEntityHeading(currentVehicle)
        camAngleH = heading + 180.0
    end
    camAngleV = 20.0
    camRadius = 6.0

    garageCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(garageCam, CAM_FOV)
    UpdateGarageCam()
    RenderScriptCams(true, true, 500, true, true)
end

local function DestroyGarageCam()
    if garageCam then
        RenderScriptCams(false, true, 500, true, true)
        Citizen.SetTimeout(500, function()
            if garageCam then
                DestroyCam(garageCam, false)
                garageCam = nil
            end
        end)
    end
end

-- [OPEN MECHANIC MENU — called via event from pvp_outposts]
local function OpenMechanicMenu()
    local playerPed = PlayerPedId()
    local veh = GetNearestVehicle(playerPed, Config.VehicleSearchRadius)

    if not veh or not DoesEntityExist(veh) then
        ESX.ShowNotification('~r~Aucun véhicule à proximité (montez dedans ou garez-vous à moins de 15m).')
        return
    end

    currentVehicle = veh
    SetVehicleModKit(veh, 0)
    originalMods = SaveOriginalMods(veh)
    menuOpen = true

    -- Entrer dans une instance privée (routing bucket) pour isoler le joueur et son véhicule
    if NetworkGetEntityIsNetworked(veh) then
        local netId = NetworkGetNetworkIdFromEntity(veh)
        TriggerServerEvent('pvp_garage:enterCustomSession', netId)
    end

    local vehicleData = GetVehicleCustomData(veh)

    -- Caméra orbitale
    CreateGarageCam()

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openMechanic',
        data = {
            categories = Config.Categories,
            wheelTypes = Config.WheelTypes,
            windowTints = Config.WindowTints,
            xenonColors = Config.XenonColors,
            vehicleColors = Config.VehicleColors,
            specialMods = Config.SpecialMods,
            vehicleData = vehicleData,
        }
    })
end

-- [OPEN DEALER MENU — called via event from pvp_outposts]
local function OpenDealerMenu()
    local playerData = ESX.GetPlayerData()

    -- Solde bancaire
    local balance = 0
    if playerData and playerData.accounts then
        for _, account in ipairs(playerData.accounts) do
            if account.name == 'bank' then
                balance = account.money
                break
            end
        end
    end

    -- Set marché-only (épique/légendaire) — jamais listés à la vente garagiste
    local marketOnly = {}
    for _, m in ipairs(Config.MarketOnlyVehicles or {}) do
        marketOnly[m] = true
    end

    -- Items véhicules dans l'inventaire (pour la vente).
    -- N'affiche que ce qui est réellement rachetable ici : modèle au catalogue
    -- garagiste ET sellPrice > 0. Le reste (marché-only, invendable explicite,
    -- modèle hors catalogue) est masqué — le serveur refuserait la vente.
    local sellItems = {}
    if playerData and playerData.inventory then
        for _, item in ipairs(playerData.inventory) do
            if item.name:sub(1, 8) == 'vehicle_' and item.count > 0 then
                local model = item.name:sub(9)  -- retire 'vehicle_'
                if not marketOnly[model] then
                    local sellPrice = nil
                    for _, v in ipairs(Config.Vehicles) do
                        if v.model == model then
                            if v.sellPrice ~= nil then
                                sellPrice = v.sellPrice
                            else
                                sellPrice = math.floor(v.price * 0.5)
                            end
                            break
                        end
                    end
                    if sellPrice and sellPrice > 0 then
                        table.insert(sellItems, {
                            name      = item.name,
                            label     = item.label or item.name,
                            count     = item.count,
                            sellPrice = sellPrice,
                        })
                    end
                end
            end
        end
    end

    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openDealer',
        data = {
            vehicles  = Config.Vehicles,
            balance   = balance,
            sellItems = sellItems,
        }
    })
end

-- [CLOSE MENU]
local function CloseMenu()
    menuOpen = false
    DestroyGarageCam()
    currentVehicle = nil
    originalMods = nil
    -- Quitter l'instance privée et revenir dans le monde principal
    TriggerServerEvent('pvp_garage:exitCustomSession')
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- [EVENTS — triggered by pvp_outposts NPC interactions]
RegisterNetEvent('pvp_garage:openMechanic')
AddEventHandler('pvp_garage:openMechanic', function()
    -- Attend que le menu ESX soit totalement fermé avant d'ouvrir le NUI
    Citizen.CreateThread(function()
        Citizen.Wait(150)
        OpenMechanicMenu()
    end)
end)

RegisterNetEvent('pvp_garage:openDealer')
AddEventHandler('pvp_garage:openDealer', function()
    Citizen.CreateThread(function()
        Citizen.Wait(150)
        OpenDealerMenu()
    end)
end)

-- [NUI CALLBACKS — MECHANIC]
RegisterNUICallback('close', function(data, cb)
    CloseMenu()
    cb('ok')
end)

RegisterNUICallback('confirm', function(data, cb)
    -- Sauvegarder les mods actuels du véhicule en DB pour ce joueur/modèle
    if currentVehicle and DoesEntityExist(currentVehicle) then
        local itemName = Entity(currentVehicle).state.pvp_itemName
        if itemName then
            SetVehicleModKit(currentVehicle, 0)
            local primary, secondary = GetVehicleColours(currentVehicle)
            local customData = {
                mods       = {},
                primary    = primary,
                secondary  = secondary,
                windowTint = GetVehicleWindowTint(currentVehicle),
                xenon      = IsToggleModOn(currentVehicle, 22),
                turbo      = IsToggleModOn(currentVehicle, 18),
            }
            for modType = 0, 49 do
                local numMods = GetNumVehicleMods(currentVehicle, modType)
                if numMods > 0 then
                    local mod = GetVehicleMod(currentVehicle, modType)
                    if mod ~= -1 then
                        customData.mods[tostring(modType)] = mod
                    end
                end
            end
            TriggerServerEvent('pvp_vehiclecustom:save', itemName, customData)
            ESX.ShowNotification('~g~Custom sauvegardée ! Elle sera appliquée à chaque spawn.')
        end
    end
    CloseMenu()
    cb('ok')
end)

RegisterNUICallback('cancel', function(data, cb)
    if currentVehicle and DoesEntityExist(currentVehicle) and originalMods then
        RestoreOriginalMods(currentVehicle, originalMods)
    end
    CloseMenu()
    cb('ok')
end)

-- [PAINT]
RegisterNUICallback('setPrimaryColor', function(data, cb)
    if currentVehicle and DoesEntityExist(currentVehicle) then
        local _, sc = GetVehicleColours(currentVehicle)
        SetVehicleColours(currentVehicle, data.color, sc)
    end
    cb('ok')
end)

RegisterNUICallback('setSecondaryColor', function(data, cb)
    if currentVehicle and DoesEntityExist(currentVehicle) then
        local pc, _ = GetVehicleColours(currentVehicle)
        SetVehicleColours(currentVehicle, pc, data.color)
    end
    cb('ok')
end)

RegisterNUICallback('setPearlescentColor', function(data, cb)
    if currentVehicle and DoesEntityExist(currentVehicle) then
        local _, wc = GetVehicleExtraColours(currentVehicle)
        SetVehicleExtraColours(currentVehicle, data.color, wc)
    end
    cb('ok')
end)

RegisterNUICallback('setWheelColor', function(data, cb)
    if currentVehicle and DoesEntityExist(currentVehicle) then
        local pearl, _ = GetVehicleExtraColours(currentVehicle)
        SetVehicleExtraColours(currentVehicle, pearl, data.color)
    end
    cb('ok')
end)

-- [WHEELS]
RegisterNUICallback('setWheelType', function(data, cb)
    if currentVehicle and DoesEntityExist(currentVehicle) then
        SetVehicleWheelType(currentVehicle, data.wheelType)
        local numMods = GetNumVehicleMods(currentVehicle, 23)
        cb(json.encode({ numWheelMods = numMods }))
        return
    end
    cb('ok')
end)

RegisterNUICallback('setWheelMod', function(data, cb)
    if currentVehicle and DoesEntityExist(currentVehicle) then
        SetVehicleMod(currentVehicle, 23, data.index, false)
    end
    cb('ok')
end)

-- [ENGINE]
RegisterNUICallback('setEngine', function(data, cb)
    if currentVehicle and DoesEntityExist(currentVehicle) then
        SetVehicleMod(currentVehicle, 11, data.level, false)
    end
    cb('ok')
end)

-- [BRAKES]
RegisterNUICallback('setBrakes', function(data, cb)
    if currentVehicle and DoesEntityExist(currentVehicle) then
        SetVehicleMod(currentVehicle, 12, data.level, false)
    end
    cb('ok')
end)

-- [TRANSMISSION]
RegisterNUICallback('setTransmission', function(data, cb)
    if currentVehicle and DoesEntityExist(currentVehicle) then
        SetVehicleMod(currentVehicle, 13, data.level, false)
    end
    cb('ok')
end)

-- [ARMOR]
RegisterNUICallback('setArmor', function(data, cb)
    if currentVehicle and DoesEntityExist(currentVehicle) then
        SetVehicleMod(currentVehicle, 16, data.level, false)
    end
    cb('ok')
end)

-- [TURBO]
RegisterNUICallback('setTurbo', function(data, cb)
    if currentVehicle and DoesEntityExist(currentVehicle) then
        ToggleVehicleMod(currentVehicle, 18, data.enabled)
    end
    cb('ok')
end)

-- [SUSPENSION]
RegisterNUICallback('setSuspension', function(data, cb)
    if currentVehicle and DoesEntityExist(currentVehicle) then
        SetVehicleMod(currentVehicle, 15, data.level, false)
    end
    cb('ok')
end)

-- [LIVERY]
RegisterNUICallback('setLivery', function(data, cb)
    if currentVehicle and DoesEntityExist(currentVehicle) then
        SetVehicleLivery(currentVehicle, data.index)
    end
    cb('ok')
end)

-- [NEON]
RegisterNUICallback('setNeonEnabled', function(data, cb)
    if currentVehicle and DoesEntityExist(currentVehicle) then
        SetVehicleNeonLightEnabled(currentVehicle, data.position, data.enabled)
    end
    cb('ok')
end)

RegisterNUICallback('setNeonColor', function(data, cb)
    if currentVehicle and DoesEntityExist(currentVehicle) then
        SetVehicleNeonLightsColour(currentVehicle, data.r, data.g, data.b)
    end
    cb('ok')
end)

-- [WINDOW TINT]
RegisterNUICallback('setWindowTint', function(data, cb)
    if currentVehicle and DoesEntityExist(currentVehicle) then
        SetVehicleWindowTint(currentVehicle, data.index)
    end
    cb('ok')
end)

-- [XENON]
RegisterNUICallback('setXenon', function(data, cb)
    if currentVehicle and DoesEntityExist(currentVehicle) then
        ToggleVehicleMod(currentVehicle, 22, data.enabled)
        if data.enabled and data.color ~= nil then
            SetVehicleXenonLightsColor(currentVehicle, data.color)
        end
    end
    cb('ok')
end)

RegisterNUICallback('setXenonColor', function(data, cb)
    if currentVehicle and DoesEntityExist(currentVehicle) then
        SetVehicleXenonLightsColor(currentVehicle, data.color)
    end
    cb('ok')
end)

-- [CAMERA CONTROLS — NUI callbacks]
RegisterNUICallback('cameraRotate', function(data, cb)
    if garageCam then
        camAngleH = camAngleH - (data.dx or 0)
        camAngleV = camAngleV + (data.dy or 0)
        if camAngleV < CAM_MIN_V then camAngleV = CAM_MIN_V end
        if camAngleV > CAM_MAX_V then camAngleV = CAM_MAX_V end
        UpdateGarageCam()
    end
    cb('ok')
end)

RegisterNUICallback('cameraZoom', function(data, cb)
    if garageCam then
        camRadius = camRadius - (data.delta or 0)
        if camRadius < CAM_MIN_R then camRadius = CAM_MIN_R end
        if camRadius > CAM_MAX_R then camRadius = CAM_MAX_R end
        UpdateGarageCam()
    end
    cb('ok')
end)

-- [SPECIAL MODS — Apocalypse]
RegisterNUICallback('setSpecialMod', function(data, cb)
    if currentVehicle and DoesEntityExist(currentVehicle) then
        -- Obligatoire avant toute modification de mod
        SetVehicleModKit(currentVehicle, 0)
        if data.level >= 0 then
            SetVehicleMod(currentVehicle, data.modIndex, data.level, false)
        else
            -- -1 = retirer le mod
            RemoveVehicleMod(currentVehicle, data.modIndex)
        end
    end
    cb('ok')
end)

-- [DEALER — ACHETER panier → items inventaire]
RegisterNUICallback('buyVehicleCart', function(data, cb)
    local items       = data.items
    local destination = data.destination or 'inventory'

    ESX.TriggerServerCallback('pvp_garage:buyVehicleCart', function(success, newBalance)
        if not success then
            cb(json.encode({ success = false, message = tostring(newBalance) }))
            return
        end
        cb(json.encode({ success = true, balance = newBalance }))
    end, items, destination)
end)

-- [DEALER — VENDRE un item véhicule de l'inventaire]
RegisterNUICallback('sellVehicleItem', function(data, cb)
    local itemName = data.item

    ESX.TriggerServerCallback('pvp_garage:sellVehicleItem', function(success, sellPrice, newBalance)
        if not success then
            cb(json.encode({ success = false, message = 'Vous ne possédez pas ce véhicule.' }))
            return
        end
        cb(json.encode({ success = true, sellPrice = sellPrice, balance = newBalance }))
    end, itemName)
end)

-- [DISABLE CONTROLS WHEN MENU OPEN]
Citizen.CreateThread(function()
    while true do
        if menuOpen then
            DisableControlAction(0, 1, true)   -- Look LR
            DisableControlAction(0, 2, true)   -- Look UD
            DisableControlAction(0, 24, true)  -- Attack
            DisableControlAction(0, 25, true)  -- Aim
            DisableControlAction(0, 106, true) -- Vehicle mouse control
            DisableControlAction(0, 140, true) -- Melee attack light
            DisableControlAction(0, 141, true) -- Melee attack alt
            DisableControlAction(0, 142, true) -- Melee attack 2
            DisableControlAction(0, 257, true) -- Attack 2
            Citizen.Wait(0)
        else
            Citizen.Wait(200)
        end
    end
end)

-- [CLEANUP ON RESOURCE STOP]
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if garageCam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(garageCam, false)
        garageCam = nil
    end
    if menuOpen then
        SetNuiFocus(false, false)
    end
end)
