-- =============================================
--   PVP ADMIN — Client v2
--   Sécurité serveur, toasts, confirmations
-- =============================================

local ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

local panelOpen    = false
local noclipActive = false
local godActive    = false
local specActive   = false
local specTarget   = nil
local frozenState  = false
local savedCoords  = nil

-- ══ Vérification admin côté client (cache simple pour F7) ═══════════════
local isAdminCached = nil

local function checkAdmin(cb)
    if isAdminCached ~= nil then cb(isAdminCached) return end
    ESX.TriggerServerCallback('pvp_admin:getData', function(data)
        isAdminCached = data ~= nil
        cb(isAdminCached)
    end)
end

-- ══ F7 — Ouvrir le panel ════════════════════════════════════════════════
local function openPanel()
    ESX.TriggerServerCallback('pvp_admin:getData', function(data)
        if not data then return end
        panelOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({ type = 'open', data = data })
    end)
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if IsControlJustPressed(0, AdminConfig.OpenKey) and not panelOpen then
            checkAdmin(function(ok)
                if ok then openPanel() end
            end)
        end
    end
end)

-- ══ NUI CALLBACKS ══════════════════════════════════════════════════════════

RegisterNUICallback('close', function(_, cb)
    panelOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Toutes les actions passent par le serveur maintenant
RegisterNUICallback('action', function(data, cb)
    TriggerServerEvent('pvp_admin:action', data.action, data.payload or {})
    cb('ok')
end)

RegisterNUICallback('refreshPlayers', function(_, cb)
    ESX.TriggerServerCallback('pvp_admin:getData', function(data)
        cb(data or {})
    end)
end)

RegisterNUICallback('getPlayerDetail', function(data, cb)
    ESX.TriggerServerCallback('pvp_admin:getPlayerDetail', function(detail)
        cb(detail or {})
    end, data.id)
end)

RegisterNUICallback('getState', function(_, cb)
    cb({ noclip = noclipActive, god = godActive, spec = specActive })
end)

RegisterNUICallback('getPlayerStorage', function(data, cb)
    ESX.TriggerServerCallback('pvp_admin:getPlayerStorage', function(result)
        cb(result or {})
    end, data.id, data.storageType)
end)

RegisterNUICallback('removeFromStorage', function(data, cb)
    TriggerServerEvent('pvp_admin:removeFromStorage', data.targetId, data.storageType, data.itemName, data.qty)
    cb('ok')
end)

RegisterNUICallback('addToStorage', function(data, cb)
    TriggerServerEvent('pvp_admin:addToStorage', data.targetId, data.storageType, data.itemName, data.qty)
    cb('ok')
end)

-- ══ TOASTS — Feedback serveur → NUI ════════════════════════════════════════
RegisterNetEvent('pvp_admin:toast')
AddEventHandler('pvp_admin:toast', function(msg, success)
    SendNUIMessage({ type = 'toast', msg = msg, success = success })
end)

-- ══ NOCLIP — Confirmé par le serveur ══════════════════════════════════════

RegisterNetEvent('pvp_admin:noclipConfirmed')
AddEventHandler('pvp_admin:noclipConfirmed', function(active)
    noclipActive = active
    local ped = PlayerPedId()
    if noclipActive then
        SetEntityVisible(ped, false, false)
        SetEntityCollision(ped, false, false)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetEveryoneIgnorePlayer(PlayerId(), true)
    else
        SetEntityVisible(ped, true, false)
        SetEntityCollision(ped, true, true)
        FreezeEntityPosition(ped, false)
        if not godActive then SetEntityInvincible(ped, false) end
        SetEveryoneIgnorePlayer(PlayerId(), false)
    end
    -- Mettre à jour le panel si ouvert
    SendNUIMessage({ type = 'updateState', state = { noclip = noclipActive, god = godActive } })
end)

Citizen.CreateThread(function()
    while true do
        if noclipActive then
            Citizen.Wait(0)
            local ped = PlayerPedId()
            local camRot = GetGameplayCamRot(2)
            local camFwd = rotToDir(camRot)
            local camRight = getCamRight(camRot)
            local pos = GetEntityCoords(ped)

            local speed = AdminConfig.NoclipSpeedNormal
            if IsControlPressed(0, 209) then
                speed = AdminConfig.NoclipSpeedFast
            elseif IsControlPressed(0, 36) then
                speed = AdminConfig.NoclipSpeedSlow
            end

            local dx, dy, dz = 0, 0, 0
            if IsControlPressed(0, 32)  then dx=dx+camFwd.x*speed; dy=dy+camFwd.y*speed; dz=dz+camFwd.z*speed end
            if IsControlPressed(0, 33)  then dx=dx-camFwd.x*speed; dy=dy-camFwd.y*speed; dz=dz-camFwd.z*speed end
            if IsControlPressed(0, 34)  then dx=dx-camRight.x*speed; dy=dy-camRight.y*speed end
            if IsControlPressed(0, 35)  then dx=dx+camRight.x*speed; dy=dy+camRight.y*speed end
            if IsControlPressed(0, 44)  then dz=dz+speed end
            if IsControlPressed(0, 20)  then dz=dz-speed end

            local newPos = vector3(pos.x + dx, pos.y + dy, pos.z + dz)
            SetEntityCoordsNoOffset(ped, newPos.x, newPos.y, newPos.z, false, false, false)
            SetEntityHeading(ped, camRot.z)

            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 47, true)
            DisableControlAction(0, 58, true)
        else
            Citizen.Wait(200)
        end
    end
end)

function rotToDir(rot)
    local rz = math.rad(rot.z)
    local rx = math.rad(rot.x)
    local cosx = math.abs(math.cos(rx))
    return vector3(-math.sin(rz) * cosx, math.cos(rz) * cosx, math.sin(rx))
end

function getCamRight(rot)
    local rz = math.rad(rot.z - 90)
    return vector3(-math.sin(rz), math.cos(rz), 0)
end

-- ══ GOD MODE — Confirmé par le serveur ════════════════════════════════════

RegisterNetEvent('pvp_admin:godConfirmed')
AddEventHandler('pvp_admin:godConfirmed', function(active)
    godActive = active
    SetEntityInvincible(PlayerPedId(), godActive)
    SendNUIMessage({ type = 'updateState', state = { noclip = noclipActive, god = godActive } })
end)

-- ══ SPAWN CAR — Confirmé par le serveur ═══════════════════════════════════

RegisterNetEvent('pvp_admin:spawnCarConfirmed')
AddEventHandler('pvp_admin:spawnCarConfirmed', function(model)
    local hash = GetHashKey(model)
    RequestModel(hash)
    local timeout = GetGameTimer()
    while not HasModelLoaded(hash) do
        if GetGameTimer() - timeout > 5000 then
            TriggerEvent('chat:addMessage', { args = { '^1[ADMIN]', 'Modèle invalide.' } })
            return
        end
        Citizen.Wait(50)
    end
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local veh = CreateVehicle(hash, pos.x, pos.y, pos.z + 1.0, heading, true, false)
    SetPedIntoVehicle(ped, veh, -1)
    SetEntityAsNoLongerNeeded(veh)
    SetModelAsNoLongerNeeded(hash)
end)

-- ══ DELETE CAR — Confirmé par le serveur ══════════════════════════════════

RegisterNetEvent('pvp_admin:deleteCarConfirmed')
AddEventHandler('pvp_admin:deleteCarConfirmed', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then veh = GetVehiclePedIsIn(ped, true) end
    if veh == 0 then
        veh = GetClosestVehicle(GetEntityCoords(ped), 10.0, 0, 71)
    end
    if veh ~= 0 then
        DeleteEntity(veh)
    end
end)

-- ══ TEST PED — Confirmé par le serveur ════════════════════════════════════
-- Change temporairement le modèle du ped pour tester des animations/modèles.
-- Sans argument (ou "reset") : revient au modèle d'origine (mémorisé au 1er changement).

local testPedOriginalModel = nil

RegisterNetEvent('pvp_admin:testPedConfirmed')
AddEventHandler('pvp_admin:testPedConfirmed', function(model)
    local ped = PlayerPedId()

    if not model then
        if not testPedOriginalModel then return end
        model = testPedOriginalModel
        testPedOriginalModel = nil
    elseif not testPedOriginalModel then
        testPedOriginalModel = GetEntityModel(ped)
    end

    local hash = type(model) == 'number' and model or GetHashKey(model)
    RequestModel(hash)
    local timeout = GetGameTimer()
    while not HasModelLoaded(hash) do
        if GetGameTimer() - timeout > 5000 then
            TriggerEvent('chat:addMessage', { args = { '^1[ADMIN]', 'Modèle de ped invalide.' } })
            return
        end
        Citizen.Wait(50)
    end

    local coords  = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    SetPlayerModel(PlayerId(), hash)
    SetModelAsNoLongerNeeded(hash)

    local newPed = PlayerPedId()
    SetEntityCoordsNoOffset(newPed, coords.x, coords.y, coords.z, false, false, false, true)
    SetEntityHeading(newPed, heading)
    SetEntityVisible(newPed, true, false)
    SetEntityCollision(newPed, true, true)
    SetEntityHealth(newPed, GetEntityMaxHealth(newPed))
    SetPedDefaultComponentVariation(newPed)
end)

-- ══ TP WAYPOINT — Confirmé par le serveur ═════════════════════════════════

RegisterNetEvent('pvp_admin:tpwpConfirmed')
AddEventHandler('pvp_admin:tpwpConfirmed', function()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then
        TriggerEvent('chat:addMessage', { args = { '^1[ADMIN]', 'Aucun waypoint.' } })
        return
    end
    local coords = GetBlipInfoIdCoord(blip)
    local ped = PlayerPedId()
    local found, z = false, 0
    for height = 1000.0, 0.0, -25.0 do
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, height, false, false, false)
        Citizen.Wait(50)
        found, z = GetGroundZFor_3dCoord(coords.x, coords.y, height, false)
        if found then break end
    end
    if found then
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, z + 1.0, false, false, false)
    else
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, 200.0, false, false, false)
    end
end)

-- ══ SPECTATE ═══════════════════════════════════════════════════════════════

local function startSpectate(tid)
    local targetPed = GetPlayerPed(GetPlayerFromServerId(tid))
    if not targetPed or targetPed == 0 then
        TriggerEvent('chat:addMessage', { args = { '^1[ADMIN]', 'Joueur introuvable.' } })
        return
    end
    local ped = PlayerPedId()
    savedCoords = GetEntityCoords(ped)
    specTarget = tid
    specActive = true

    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetEveryoneIgnorePlayer(PlayerId(), true)

    local tCoords = GetEntityCoords(targetPed)
    SetEntityCoords(ped, tCoords.x, tCoords.y, tCoords.z - 10.0, false, false, false, false)
    NetworkSetInSpectatorMode(true, targetPed)
end

local function stopSpectate()
    local ped = PlayerPedId()
    NetworkSetInSpectatorMode(false, ped)
    specActive = false
    specTarget = nil

    if savedCoords then
        SetEntityCoords(ped, savedCoords.x, savedCoords.y, savedCoords.z, false, false, false, false)
        savedCoords = nil
    end

    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    if not godActive then SetEntityInvincible(ped, false) end
    if not noclipActive then FreezeEntityPosition(ped, false) end
    SetEveryoneIgnorePlayer(PlayerId(), false)
end

-- Surveiller la validité du joueur spectate (déconnexion, etc.)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        if specActive and specTarget then
            local targetPlayer = GetPlayerFromServerId(specTarget)
            local targetPed = targetPlayer and GetPlayerPed(targetPlayer) or 0
            if not targetPed or targetPed == 0 or not DoesEntityExist(targetPed) then
                TriggerEvent('chat:addMessage', { args = { '^1[ADMIN]', 'Le joueur observé s\'est déconnecté.' } })
                stopSpectate()
            end
        end
    end
end)

RegisterNetEvent('pvp_admin:startSpec')
AddEventHandler('pvp_admin:startSpec', function(targetId)
    if specActive then stopSpectate() end
    startSpectate(targetId)
end)

RegisterCommand('spec', function(_, args)
    local tid = tonumber(args[1])
    if not tid or specActive then
        if specActive then stopSpectate() end
        return
    end
    -- Demander au serveur la permission via action
    TriggerServerEvent('pvp_admin:action', 'spectate', { id = tid })
end, false)

-- ══ EVENTS REÇUS DU SERVEUR ═══════════════════════════════════════════════

RegisterNetEvent('pvp_admin:teleport')
AddEventHandler('pvp_admin:teleport', function(x, y, z)
    SetEntityCoordsNoOffset(PlayerPedId(), x, y, z + 1.0, false, false, false)
end)

RegisterNetEvent('pvp_admin:heal')
AddEventHandler('pvp_admin:heal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 100)
end)

RegisterNetEvent('pvp_admin:revive')
AddEventHandler('pvp_admin:revive', function()
    local ped = PlayerPedId()
    NetworkResurrectLocalPlayer(GetEntityCoords(ped), true, true, false)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 100)
    ClearPedBloodDamage(ped)
end)

RegisterNetEvent('pvp_admin:slay')
AddEventHandler('pvp_admin:slay', function()
    SetEntityHealth(PlayerPedId(), 0)
end)

RegisterNetEvent('pvp_admin:freeze')
AddEventHandler('pvp_admin:freeze', function()
    frozenState = not frozenState
    FreezeEntityPosition(PlayerPedId(), frozenState)
end)

RegisterNetEvent('pvp_admin:setWeather')
AddEventHandler('pvp_admin:setWeather', function(weather)
    SetWeatherTypeNowPersist(weather)
    SetWeatherTypeNow(weather)
end)

RegisterNetEvent('pvp_admin:setTime')
AddEventHandler('pvp_admin:setTime', function(hour)
    NetworkOverrideClockTime(hour, 0, 0)
end)

RegisterNetEvent('pvp_admin:killZombies')
AddEventHandler('pvp_admin:killZombies', function()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local radius = AdminConfig.KillZombiesRadius
    local count = 0
    local handle, entity = FindFirstPed()
    local found = handle ~= -1
    while found do
        if entity ~= ped and DoesEntityExist(entity) and not IsPedAPlayer(entity) then
            local d = #(pos - GetEntityCoords(entity))
            if d < radius and not IsEntityDead(entity) then
                SetEntityHealth(entity, 0)
                count = count + 1
            end
        end
        found, entity = FindNextPed(handle)
    end
    EndFindPed(handle)
    TriggerEvent('chat:addMessage', { args = { '^2[ADMIN]', count .. ' PNJ/zombies éliminés.' } })
end)
