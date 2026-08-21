-- =============================================
--   PVP CHARACTER - Client
--   Création de personnage avec preview ped + caméra cinématique
-- =============================================

local ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- ── Config : location du décor cinématique ──────────────────────────────
-- Top de la Maze Bank Tower (vue cinématique sur LS nuit)
local PREVIEW_COORDS  = vector3(-75.36, -818.62, 326.175)
local PREVIEW_HEADING = 160.0

-- ── État interne ────────────────────────────────────────────────────────
local isNewPlayer    = false
local inCreation     = false
local previewCam     = nil
local savedSpawn     = nil    -- { coords, heading } pour restaurer après création
local pendingApply   = nil    -- données de ped à appliquer à la prochaine spawn

-- ── Presets d'apparence ─────────────────────────────────────────────────
-- SetPedHeadBlendData : (ped, shapeDad, shapeMom, shape3, skinDad, skinMom, skin3, shapeMix, skinMix, thirdMix, isParent)
local SkinPresets = {
    -- shapeDad, shapeMom, shapeDad3, skinDad, skinMom, skin3, shapeMix, skinMix, thirdMix
    { 0, 0, 0,  0,  0, 0, 0.5, 0.0, 0.0 },  -- Clair
    { 0, 0, 0,  4,  4, 0, 0.5, 0.4, 0.0 },  -- Médium
    { 0, 0, 0, 14, 14, 0, 0.5, 0.7, 0.0 },  -- Bronzé
    { 0, 0, 0, 21, 21, 0, 0.5, 1.0, 0.0 },  -- Foncé
}

-- Hair component (2) drawable indices for mp_freemode
local HairPresetsMale = {
    { drawable = 0,  color = 0 },  -- Rasé court
    { drawable = 2,  color = 0 },  -- Crew cut
    { drawable = 4,  color = 0 },  -- Mi-long
    { drawable = 10, color = 1 },  -- Chignon
}
local HairPresetsFemale = {
    { drawable = 0,  color = 0 },  -- Court
    { drawable = 3,  color = 0 },  -- Queue de cheval
    { drawable = 5,  color = 0 },  -- Long ouvert
    { drawable = 12, color = 1 },  -- Tressé
}

-- ── Helpers : appliquer le modèle ped freemode ──────────────────────────
local function loadModel(model)
    RequestModel(model)
    local t = GetGameTimer()
    while not HasModelLoaded(model) and GetGameTimer() - t < 5000 do
        Citizen.Wait(0)
    end
end

local function applyFreemodeModel(gender)
    local modelName = (gender == 'f' or gender == 'female') and 'mp_f_freemode_01' or 'mp_m_freemode_01'
    local model = GetHashKey(modelName)

    local oldPed  = PlayerPedId()
    local coords  = GetEntityCoords(oldPed)
    local heading = GetEntityHeading(oldPed)

    loadModel(model)
    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)

    local newPed = PlayerPedId()
    SetEntityCoordsNoOffset(newPed, coords.x, coords.y, coords.z, false, false, false, true)
    SetEntityHeading(newPed, heading)
    SetEntityVisible(newPed, true, false)
    SetEntityCollision(newPed, true, true)
    SetEntityHealth(newPed, 200)
    SetPedDefaultComponentVariation(newPed)
end

local function applyAppearance(gender, skinIdx, hairIdx)
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end

    -- Sanitize indices (1-based côté Lua, 0-based côté JS)
    skinIdx = (skinIdx or 0) + 1
    hairIdx = (hairIdx or 0) + 1
    if skinIdx < 1 or skinIdx > #SkinPresets then skinIdx = 1 end

    local skin = SkinPresets[skinIdx]
    SetPedHeadBlendData(ped,
        skin[1], skin[2], skin[3],
        skin[4], skin[5], skin[6],
        skin[7], skin[8], skin[9],
        false
    )

    local hairs = (gender == 'female') and HairPresetsFemale or HairPresetsMale
    if hairIdx < 1 or hairIdx > #hairs then hairIdx = 1 end
    local hair = hairs[hairIdx]
    SetPedComponentVariation(ped, 2, hair.drawable, 0, 0)
    SetPedHairColor(ped, hair.color, 0)
end

-- ── Caméra cinématique sur le ped ───────────────────────────────────────
local function setupPreviewScene()
    local ped = PlayerPedId()

    -- Sauvegarder la position actuelle avant de téléporter
    savedSpawn = {
        coords  = GetEntityCoords(ped),
        heading = GetEntityHeading(ped),
    }

    -- Freeze + invincible
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetPlayerControl(PlayerId(), false, 0)

    -- Load la zone avant téléportation
    RequestCollisionAtCoord(PREVIEW_COORDS.x, PREVIEW_COORDS.y, PREVIEW_COORDS.z)
    NewLoadSceneStart(PREVIEW_COORDS.x, PREVIEW_COORDS.y, PREVIEW_COORDS.z, 0.0, 0.0, 0.0, 50.0, 0)
    local t = GetGameTimer()
    while IsNetworkLoadingScene() and GetGameTimer() - t < 3000 do
        Citizen.Wait(0)
    end
    NewLoadSceneStop()

    SetEntityCoordsNoOffset(ped, PREVIEW_COORDS.x, PREVIEW_COORDS.y, PREVIEW_COORDS.z, false, false, false, true)
    SetEntityHeading(ped, PREVIEW_HEADING)
    FreezeEntityPosition(ped, true)

    -- Ambiance : nuit claire
    NetworkOverrideClockTime(22, 0, 0)
    SetWeatherTypeNowPersist('CLEAR')
    SetWeatherTypePersist('CLEAR')

    -- Caméra : positionnée de face, offset latéral pour que le ped soit à droite de l'écran
    local fwdX = -math.sin(math.rad(PREVIEW_HEADING))
    local fwdY =  math.cos(math.rad(PREVIEW_HEADING))
    local rightX =  fwdY
    local rightY = -fwdX

    local camX = PREVIEW_COORDS.x + fwdX * 2.6 + rightX * 0.3
    local camY = PREVIEW_COORDS.y + fwdY * 2.6 + rightY * 0.3
    local camZ = PREVIEW_COORDS.z + 0.3

    if previewCam then
        DestroyCam(previewCam, false)
        previewCam = nil
    end
    previewCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camX, camY, camZ, 0.0, 0.0, 0.0, 42.0, false, 0)

    -- Point cam sur un offset à gauche du ped (fait apparaître le ped à droite de l'écran)
    local lookOffX = -rightX * 0.9
    local lookOffY = -rightY * 0.9
    PointCamAtCoord(previewCam,
        PREVIEW_COORDS.x + lookOffX,
        PREVIEW_COORDS.y + lookOffY,
        PREVIEW_COORDS.z - 0.2
    )
    SetCamActive(previewCam, true)
    RenderScriptCams(true, false, 0, true, true)

    -- Masquer HUD / radar
    DisplayRadar(false)
end

local function teardownPreviewScene()
    RenderScriptCams(false, false, 0, true, true)
    if previewCam then
        DestroyCam(previewCam, false)
        previewCam = nil
    end
    DisplayRadar(true)
    NetworkClearClockOverride()
    ClearOverrideWeather()
    ClearWeatherTypePersist()
end

-- ── Events serveur ──────────────────────────────────────────────────────
RegisterNetEvent('pvp_character:isNewPlayer')
AddEventHandler('pvp_character:isNewPlayer', function()
    isNewPlayer = true
end)

-- Applique un ped custom (non-freemode) à partir de son nom
local function applyCustomPedModel(modelName)
    local model = GetHashKey(modelName)
    local ped   = PlayerPedId()
    local coords  = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    loadModel(model)
    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)
    local newPed = PlayerPedId()
    SetEntityCoordsNoOffset(newPed, coords.x, coords.y, coords.z, false, false, false, true)
    SetEntityHeading(newPed, heading)
    SetEntityVisible(newPed, true, false)
    SetEntityCollision(newPed, true, true)
    SetEntityHealth(newPed, 200)
    SetPedDefaultComponentVariation(newPed)
end

RegisterNetEvent('pvp_character:applyModel')
AddEventHandler('pvp_character:applyModel', function(data)
    pendingApply = data
    if NetworkIsPlayerActive(PlayerId()) and DoesEntityExist(PlayerPedId()) and GetEntityHealth(PlayerPedId()) > 0 then
        Citizen.CreateThread(function()
            Citizen.Wait(200)
            local d = pendingApply
            pendingApply = nil
            if not d then return end
            if d.ped_model and d.ped_model ~= '' then
                applyCustomPedModel(d.ped_model)
            else
                applyFreemodeModel(d.sex)
                applyAppearance(d.sex == 'f' and 'female' or 'male', d.skin_tone, d.hair_style)
            end
        end)
    end
end)

-- ── Playerspawned : déclenche la création ou applique le modèle existant
AddEventHandler('playerSpawned', function()
    Citizen.CreateThread(function()
        Citizen.Wait(400)

        if isNewPlayer and not inCreation then
            inCreation = true
            setupPreviewScene()
            -- Appliquer le ped masculin par défaut + apparence preset 0
            applyFreemodeModel('male')
            applyAppearance('male', 0, 0)
            SetNuiFocus(true, true)
            SendNUIMessage({ action = 'show' })
            return
        end

        if pendingApply then
            local d = pendingApply
            pendingApply = nil
            if d.ped_model and d.ped_model ~= '' then
                applyCustomPedModel(d.ped_model)
            else
                applyFreemodeModel(d.sex)
                applyAppearance(d.sex == 'f' and 'female' or 'male', d.skin_tone, d.hair_style)
            end
        end
    end)
end)

-- ── NUI : preview live ──────────────────────────────────────────────────
RegisterNUICallback('updatePreview', function(data, cb)
    cb({})
    if not inCreation then return end
    local gender = (data and data.gender) or 'male'
    applyFreemodeModel(gender)
    applyAppearance(gender, data and data.skin_tone or 0, data and data.hair_style or 0)
end)

-- ── NUI : confirmation ──────────────────────────────────────────────────
RegisterNUICallback('confirmCharacter', function(data, cb)
    cb({})
    TriggerServerEvent('pvp_character:saveCharacter', {
        pseudo     = data.pseudo or 'Joueur',
        gender     = data.gender or 'male',
        skin_tone  = data.skin_tone or 0,
        hair_style = data.hair_style or 0,
    })
end)

-- ── Erreur de création : réactiver le bouton + afficher dans NUI ────────
RegisterNetEvent('pvp_character:creationError')
AddEventHandler('pvp_character:creationError', function(message)
    SendNUIMessage({ action = 'error', message = message })
end)

-- ── Création OK : tear down + dispatch à pvp_spawn ──────────────────────
RegisterNetEvent('pvp_character:creationDone')
AddEventHandler('pvp_character:creationDone', function(data)
    isNewPlayer = false
    inCreation  = false

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })

    Citizen.CreateThread(function()
        -- Appliquer définitivement le ped choisi (sera transporté par pvp_spawn après)
        applyFreemodeModel(data.sex)
        applyAppearance(data.sex, data.skin_tone, data.hair_style)

        -- Tear down de la scène preview
        teardownPreviewScene()

        local ped = PlayerPedId()
        SetEntityInvincible(ped, false)
        FreezeEntityPosition(ped, false)
        SetPlayerControl(PlayerId(), true, 0)

        -- pvp_spawn va maintenant recevoir setLoginOutpost (via pvp_character:characterReady serveur)
        -- et téléporter le joueur. En attendant on laisse le ped freeze court pour éviter la chute.
        FreezeEntityPosition(ped, true)
    end)
end)
