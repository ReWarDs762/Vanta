-- =============================================
--   PVP CHARACTER - Client
--   Création de personnage : preview ped live + caméra cinématique + apparence détaillée
-- =============================================

local ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- ── Config : décor cinématique ──────────────────────────────────────────
local PREVIEW_COORDS  = vector3(-75.36, -818.62, 326.175)
local PREVIEW_HEADING = 160.0

-- Décalage latéral de la caméra : le panneau NUI occupe ~32% de la droite,
-- on veut donc centrer le personnage sur les 68% restants (≈34% de l'écran).
-- NÉGATIF = la caméra pivote vers la droite, donc le sujet se décale vers la
-- GAUCHE de l'écran. Inverser le signe s'il part du mauvais côté.
local LATERAL_YAW = -13.3

-- ── Whitelists (mirroir des whitelists serveur — cohérence des bornes) ──
-- Volontairement restreint (décision produit) : pas de bras/torse, sac,
-- decal — et un seul emplacement "HAUTS" unifié (composant 11 uniquement,
-- sous-vêtement/gilet non exposés, ils gardent la valeur par défaut du jeu).
local COMPONENT_SLOTS = {
    { id = 1,  label = 'MASQUE' },
    { id = 4,  label = 'JAMBES' },
    { id = 6,  label = 'CHAUSSURES' },
    { id = 7,  label = 'ACCESSOIRE COU' },
    { id = 11, label = 'HAUTS' },
}
local PROP_SLOTS = {
    { id = 0, label = 'COUVRE-CHEF' },
    { id = 1, label = 'LUNETTES' },
    { id = 2, label = 'OREILLES' },
    { id = 6, label = 'MONTRE' },
    { id = 7, label = 'BRACELET' },
}

-- 12 teintes de peau (skinFirst, skinSecond, mix)
local SKIN_TONES = {
    {  0,  0, 0.0 }, {  0,  1, 0.3 }, {  1,  1, 0.0 }, {  1,  4, 0.4 },
    {  4,  4, 0.0 }, {  4,  9, 0.3 }, {  9,  9, 0.0 }, {  9, 14, 0.4 },
    { 14, 14, 0.0 }, { 14, 21, 0.4 }, { 21, 21, 0.0 }, { 21, 30, 0.5 },
}

local OVL_BEARD     = 1
local OVL_EYEBROWS  = 2

-- ── État interne ────────────────────────────────────────────────────────
local isNewPlayer  = false
local inCreation   = false
local previewCam   = nil
local savedSpawn   = nil
local pendingApply = nil   -- { model, appearance } à appliquer à la prochaine spawn

-- État courant de l'apparence en cours de création
local creation = nil

local function freshCreationState(gender)
    local hairs = { drawable = 0, texture = 0, color = 0, highlight = 0 }
    return {
        charType = 'freemode',   -- 'freemode' | 'special'
        gender   = gender or 'male',
        model    = (gender == 'female') and 'mp_f_freemode_01' or 'mp_m_freemode_01',
        specialModel = nil,
        skinIdx  = 0,
        head     = { 0, 0, 0, 0, 0, 0, 0.5, 0.0, 0.0 }, -- shapeF,shapeS,shapeT,skinF,skinS,skinT,shapeMix,skinMix,thirdMix
        hair     = hairs,
        beard    = { index = 255, opacity = 100 },
        eyebrows = { index = 0,   opacity = 100 },
        eye      = 0,
        comps    = {},  -- [componentId] = { drawable, texture }
        props    = {},  -- [propId]      = { drawable, texture }  (drawable -1 = aucun)
        camMode  = 'body',
        heading  = PREVIEW_HEADING,
    }
end

-- ── Helpers modèle ──────────────────────────────────────────────────────
local function loadModel(model)
    RequestModel(model)
    local t = GetGameTimer()
    while not HasModelLoaded(model) and GetGameTimer() - t < 5000 do
        Citizen.Wait(0)
    end
end

local function isFreemodeModel(model)
    return model == '' or model == nil or model == 'mp_m_freemode_01' or model == 'mp_f_freemode_01'
end

-- Change le modèle SEULEMENT s'il diffère du modèle actuel du ped.
local function ensureModel(modelName)
    local ped = PlayerPedId()
    local wantHash = GetHashKey(modelName)
    if GetEntityModel(ped) == wantHash then return false end

    local coords  = GetEntityCoords(ped)
    local heading = creation and creation.heading or GetEntityHeading(ped)

    loadModel(wantHash)
    SetPlayerModel(PlayerId(), wantHash)
    SetModelAsNoLongerNeeded(wantHash)

    local newPed = PlayerPedId()
    SetEntityCoordsNoOffset(newPed, coords.x, coords.y, coords.z, false, false, false, true)
    SetEntityHeading(newPed, heading)
    SetEntityVisible(newPed, true, false)
    SetEntityCollision(newPed, true, true)
    SetEntityHealth(newPed, 200)
    SetPedDefaultComponentVariation(newPed)
    FreezeEntityPosition(newPed, true)
    SetEntityInvincible(newPed, true)
    return true
end

-- ── Appliers granulaires ─────────────────────────────────────────────────
local function applyHead()
    local ped = PlayerPedId()
    local h = creation.head
    SetPedHeadBlendData(ped, h[1], h[2], h[3], h[4], h[5], h[6], h[7], h[8], h[9], false)
end

local function applyOverlays()
    local ped = PlayerPedId()
    local b = creation.beard
    local e = creation.eyebrows
    SetPedHeadOverlay(ped, OVL_BEARD, b.index, b.opacity / 100.0)
    if b.index ~= 255 then SetPedHeadOverlayColor(ped, OVL_BEARD, 1, 0, 0) end
    SetPedHeadOverlay(ped, OVL_EYEBROWS, e.index, e.opacity / 100.0)
    if e.index ~= 255 then SetPedHeadOverlayColor(ped, OVL_EYEBROWS, 1, 0, 0) end
    SetPedEyeColor(ped, creation.eye)
end

local function applyHair()
    local ped = PlayerPedId()
    local hr = creation.hair
    SetPedComponentVariation(ped, 2, hr.drawable, hr.texture, 0)
    SetPedHairColor(ped, hr.color, hr.highlight)
end

local function applyComponent(compId)
    local ped = PlayerPedId()
    local c = creation.comps[compId]
    if not c then return end
    SetPedComponentVariation(ped, compId, c.drawable, c.texture, 0)
end

local function applyProp(propId)
    local ped = PlayerPedId()
    local p = creation.props[propId]
    if not p then return end
    if p.drawable < 0 then
        ClearPedProp(ped, propId)
    else
        SetPedPropIndex(ped, propId, p.drawable, p.texture, true)
    end
end

-- Ordre obligatoire : SetPedHeadBlendData réinitialise overlays + couleur cheveux
local function applyAll()
    if creation.charType == 'special' then return end
    applyHead()
    applyOverlays()
    applyHair()
    for _, slot in ipairs(COMPONENT_SLOTS) do applyComponent(slot.id) end
    for _, slot in ipairs(PROP_SLOTS) do applyProp(slot.id) end
end

-- Capture l'apparence "par défaut du jeu" après un SetPedDefaultComponentVariation
-- (plus robuste que deviner des index à la main — toujours une tenue valide).
-- Appelle explicitement SetPedDefaultComponentVariation d'abord : ensureModel()
-- ne le fait QUE quand le modèle change réellement, ce qui laisserait une
-- apparence non déterministe si le ped était déjà sur le bon modèle.
local function captureDefaultOutfit()
    local ped = PlayerPedId()
    SetPedDefaultComponentVariation(ped)
    creation.comps = {}
    for _, slot in ipairs(COMPONENT_SLOTS) do
        creation.comps[slot.id] = {
            drawable = GetPedDrawableVariation(ped, slot.id),
            texture  = GetPedTextureVariation(ped, slot.id),
        }
    end
    creation.props = {}
    for _, slot in ipairs(PROP_SLOTS) do
        creation.props[slot.id] = { drawable = -1, texture = 0 }
    end
    creation.hair.drawable = GetPedDrawableVariation(ped, 2)
    creation.hair.texture  = GetPedTextureVariation(ped, 2)
end

-- ── Cyclers (bornes lues en direct sur le ped courant) ──────────────────
local function wrap(v, dir, maxV, minV)
    minV = minV or 0
    local span = maxV - minV + 1
    if span <= 0 then return minV end
    local nv = (v - minV + dir) % span
    if nv < 0 then nv = nv + span end
    return minV + nv
end

local function cycleComponent(compId, field, dir)
    local ped = PlayerPedId()
    local c = creation.comps[compId] or { drawable = 0, texture = 0 }
    local drawMax = math.max(0, GetNumberOfPedDrawableVariations(ped, compId) - 1)

    if field == 'drawable' then
        c.drawable = wrap(c.drawable, dir, drawMax)
        c.texture  = 0
    else
        local texMax = math.max(0, GetNumberOfPedTextureVariations(ped, compId, c.drawable) - 1)
        c.texture = wrap(c.texture, dir, texMax)
    end

    creation.comps[compId] = c
    applyComponent(compId)

    local texMax = math.max(0, GetNumberOfPedTextureVariations(ped, compId, c.drawable) - 1)
    return { drawable = c.drawable, drawableMax = drawMax, texture = c.texture, textureMax = texMax }
end

local function cycleProp(propId, field, dir)
    local ped = PlayerPedId()
    local p = creation.props[propId] or { drawable = -1, texture = 0 }
    local drawMax = math.max(0, GetNumberOfPedPropDrawableVariations(ped, propId) - 1)

    if field == 'drawable' then
        p.drawable = wrap(p.drawable, dir, drawMax, -1)
        p.texture  = 0
    else
        if p.drawable >= 0 then
            local texMax = math.max(0, GetNumberOfPedPropTextureVariations(ped, propId, p.drawable) - 1)
            p.texture = wrap(p.texture, dir, texMax)
        end
    end

    creation.props[propId] = p
    applyProp(propId)

    local texMax = (p.drawable >= 0) and math.max(0, GetNumberOfPedPropTextureVariations(ped, propId, p.drawable) - 1) or 0
    return { drawable = p.drawable, drawableMax = drawMax, texture = p.texture, textureMax = texMax }
end

local function cycleHair(field, dir)
    local ped = PlayerPedId()
    local hr = creation.hair

    if field == 'drawable' then
        local drawMax = math.max(0, GetNumberOfPedDrawableVariations(ped, 2) - 1)
        hr.drawable = wrap(hr.drawable, dir, drawMax)
        hr.texture  = 0
    elseif field == 'texture' then
        local texMax = math.max(0, GetNumberOfPedTextureVariations(ped, 2, hr.drawable) - 1)
        hr.texture = wrap(hr.texture, dir, texMax)
    elseif field == 'highlight' then
        hr.highlight = wrap(hr.highlight, dir, 63)
    end

    applyHair()

    local drawMax = math.max(0, GetNumberOfPedDrawableVariations(ped, 2) - 1)
    local texMax  = math.max(0, GetNumberOfPedTextureVariations(ped, 2, hr.drawable) - 1)
    return { drawable = hr.drawable, drawableMax = drawMax, texture = hr.texture, textureMax = texMax,
             color = hr.color, highlight = hr.highlight }
end

local function setHairColor(colorId)
    creation.hair.color = math.max(0, math.min(63, tonumber(colorId) or 0))
    applyHair()
end

local function cycleFace(field, dir)
    local h = creation.head
    if field == 'shapeFirst' then
        h[1] = wrap(h[1], dir, 45)
    elseif field == 'shapeSecond' then
        h[2] = wrap(h[2], dir, 45)
    elseif field == 'shapeMix' then
        local steps = math.floor((h[7] + 0.0001) * 10 + 0.0)
        steps = wrap(steps, dir, 10)
        h[7] = steps / 10.0
    elseif field == 'beard' then
        local maxV = math.max(0, GetNumHeadOverlayValues(OVL_BEARD) - 1)
        if creation.beard.index == 255 then
            creation.beard.index = (dir > 0) and 0 or maxV
        else
            local nv = creation.beard.index + dir
            if nv < 0 then creation.beard.index = 255
            elseif nv > maxV then creation.beard.index = 255
            else creation.beard.index = nv end
        end
    elseif field == 'eyebrows' then
        local maxV = math.max(0, GetNumHeadOverlayValues(OVL_EYEBROWS) - 1)
        if creation.eyebrows.index == 255 then
            creation.eyebrows.index = (dir > 0) and 0 or maxV
        else
            local nv = creation.eyebrows.index + dir
            if nv < 0 then creation.eyebrows.index = 255
            elseif nv > maxV then creation.eyebrows.index = 255
            else creation.eyebrows.index = nv end
        end
    elseif field == 'eyeColor' then
        creation.eye = wrap(creation.eye, dir, 31)
    end

    applyHead()
    applyOverlays()

    return {
        shapeFirst  = h[1], shapeSecond = h[2], shapeMix = h[7],
        beard       = creation.beard.index,
        eyebrows    = creation.eyebrows.index,
        eyeColor    = creation.eye,
    }
end

local function setSkin(index)
    index = math.max(0, math.min(#SKIN_TONES - 1, tonumber(index) or 0))
    local tone = SKIN_TONES[index + 1]
    creation.skinIdx = index
    creation.head[4] = tone[1]
    creation.head[5] = tone[2]
    creation.head[6] = 0
    creation.head[8] = tone[3]
    creation.head[9] = 0.0
    applyHead()
    applyOverlays()
end

-- ── Snapshot pour le NUI ─────────────────────────────────────────────────
local function componentSnapshot()
    local ped = PlayerPedId()
    local out = {}
    for _, slot in ipairs(COMPONENT_SLOTS) do
        local c = creation.comps[slot.id] or { drawable = 0, texture = 0 }
        out[#out + 1] = {
            id = slot.id, label = slot.label,
            drawable = c.drawable,
            drawableMax = math.max(0, GetNumberOfPedDrawableVariations(ped, slot.id) - 1),
            texture = c.texture,
            textureMax = math.max(0, GetNumberOfPedTextureVariations(ped, slot.id, c.drawable) - 1),
        }
    end
    return out
end

local function propSnapshot()
    local ped = PlayerPedId()
    local out = {}
    for _, slot in ipairs(PROP_SLOTS) do
        local p = creation.props[slot.id] or { drawable = -1, texture = 0 }
        local texMax = (p.drawable >= 0) and math.max(0, GetNumberOfPedPropTextureVariations(ped, slot.id, p.drawable) - 1) or 0
        out[#out + 1] = {
            id = slot.id, label = slot.label,
            drawable = p.drawable,
            drawableMax = math.max(0, GetNumberOfPedPropDrawableVariations(ped, slot.id) - 1),
            texture = p.texture,
            textureMax = texMax,
        }
    end
    return out
end

local function buildSnapshot()
    local ped = PlayerPedId()
    return {
        charType = creation.charType,
        gender   = creation.gender,
        skinIdx  = creation.skinIdx,
        skinCount = #SKIN_TONES,
        face = {
            shapeFirst = creation.head[1], shapeSecond = creation.head[2], shapeMix = creation.head[7],
        },
        beard    = { index = creation.beard.index,    max = math.max(0, GetNumHeadOverlayValues(OVL_BEARD) - 1) },
        eyebrows = { index = creation.eyebrows.index,  max = math.max(0, GetNumHeadOverlayValues(OVL_EYEBROWS) - 1) },
        eyeColor = creation.eye,
        hair = {
            drawable = creation.hair.drawable,
            drawableMax = math.max(0, GetNumberOfPedDrawableVariations(ped, 2) - 1),
            texture = creation.hair.texture,
            textureMax = math.max(0, GetNumberOfPedTextureVariations(ped, 2, creation.hair.drawable) - 1),
            color = creation.hair.color,
            highlight = creation.hair.highlight,
        },
        comps   = componentSnapshot(),
        props   = propSnapshot(),
        camMode = creation.camMode,
    }
end

-- ── Caméra cinématique ───────────────────────────────────────────────────
-- POINT CLÉ : pour un ped, GetEntityCoords renvoie son CENTRE (~0.95 m
-- au-dessus du sol), PAS ses pieds. Viser `base.z + hauteur*0.5` visait donc
-- au-dessus de la tête : d'où les pieds hors champ et le grand vide de ciel.
-- On se sert maintenant de base.z directement comme centre de cadrage.
local FRAME_HEIGHT_BODY = 2.55   -- hauteur de scène cadrée (sujet ≈ 1.87 m)
local FRAME_HEIGHT_FACE = 0.48
local FOV_BODY = 45.0
local FOV_FACE = 30.0
-- Visée légèrement sous le centre du ped : la hauteur exacte de ce centre
-- varie un peu selon le modèle, mieux vaut pencher du côté des pieds.
local BODY_AIM_DROP = 0.08

-- math.atan2 n'existe plus en Lua 5.3+ ; math.atan y accepte deux arguments.
local atan2 = math.atan2 or math.atan

-- Hauteur du visage au-dessus du centre du ped. Utilise le bone de tête quand
-- il est exploitable, sinon un offset fixe : GetPedBoneCoords renvoie l'origine
-- du monde (0,0,0) quand le bone est absent du modèle, ce qui faisait viser la
-- caméra vers le large au lieu du visage (bouton VISAGE cassé).
local function faceOffsetZ(ped, base)
    local hb = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0) -- SKEL_Head
    if hb and math.abs(hb.x - base.x) < 1.5 and math.abs(hb.y - base.y) < 1.5 then
        local off = hb.z - base.z
        if off > 0.3 and off < 1.2 then return off end
    end
    return 0.72
end

local function updatePreviewCam(mode)
    if not previewCam then return end
    local ped  = PlayerPedId()
    local base = GetEntityCoords(ped)

    -- Direction de la caméra FIXE (PREVIEW_HEADING, jamais creation.heading) :
    -- si la caméra suivait la rotation du ped, tourner le personnage ferait
    -- tourner la caméra avec lui et n'aurait aucun effet visible à l'écran.
    local fwdX = -math.sin(math.rad(PREVIEW_HEADING))
    local fwdY =  math.cos(math.rad(PREVIEW_HEADING))

    local aimZ, frameH, fov
    if mode == 'face' then
        aimZ, frameH, fov = base.z + faceOffsetZ(ped, base), FRAME_HEIGHT_FACE, FOV_FACE
    else
        aimZ, frameH, fov = base.z - BODY_AIM_DROP, FRAME_HEIGHT_BODY, FOV_BODY
    end

    -- Distance déduite du FOV vertical pour que `frameH` tienne exactement
    -- dans le cadre, au lieu d'une distance magique.
    local dist = (frameH * 0.5) / math.tan(math.rad(fov * 0.5))

    local camX = base.x + fwdX * dist
    local camY = base.y + fwdY * dist
    local camZ = aimZ  -- caméra à hauteur du point visé : aucun pitch, cadrage symétrique

    SetCamFov(previewCam, fov)
    SetCamCoord(previewCam, camX, camY, camZ)

    -- Rotation calculée à la main plutôt que PointCamAtCoord : ce dernier
    -- verrouille la caméra sur sa cible et écrase le SetCamRot appliqué
    -- ensuite, ce qui rendait le décalage latéral totalement sans effet
    -- (le personnage restait centré derrière le panneau).
    StopCamPointing(previewCam)
    local dx, dy, dz = base.x - camX, base.y - camY, aimZ - camZ
    local horiz = math.sqrt(dx * dx + dy * dy)
    local pitch = math.deg(atan2(dz, horiz))
    local yaw   = math.deg(atan2(-dx, dy))
    SetCamRot(previewCam, pitch, 0.0, yaw + LATERAL_YAW, 2)
end

local function setupPreviewScene()
    local ped = PlayerPedId()

    savedSpawn = { coords = GetEntityCoords(ped), heading = GetEntityHeading(ped) }

    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetPlayerControl(PlayerId(), false, 0)

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

    NetworkOverrideClockTime(22, 0, 0)
    SetWeatherTypeNowPersist('CLEAR')
    SetWeatherTypePersist('CLEAR')

    if previewCam then
        DestroyCam(previewCam, false)
        previewCam = nil
    end
    previewCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA',
        PREVIEW_COORDS.x, PREVIEW_COORDS.y, PREVIEW_COORDS.z + 1.0,
        0.0, 0.0, 0.0, 42.0, false, 0)
    SetCamActive(previewCam, true)
    RenderScriptCams(true, false, 0, true, true)

    updatePreviewCam('body')
    DisplayRadar(false)

    -- Empêche les anims idle de faire bouger le sujet hors cadre
    Citizen.CreateThread(function()
        while inCreation do
            HideHudAndRadarThisFrame()
            local p = PlayerPedId()
            SetPedCanPlayAmbientAnims(p, false)
            pcall(SetPedCanPlayGestureAnims, p, false)
            Citizen.Wait(0)
        end
    end)
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

-- ── Application d'une apparence stockée (joueur existant / après pvp_inventory) ──
local lastModel      = nil
local lastAppearance = nil

local function applyStoredAppearanceInternal(model, appearance)
    ensureModel(model)
    if isFreemodeModel(model) and type(appearance) == 'table' then
        creation = freshCreationState((model == 'mp_f_freemode_01') and 'female' or 'male')
        creation.charType = 'freemode'
        creation.head = appearance.head or creation.head
        if appearance.hair then
            creation.hair.drawable  = appearance.hair[1] or 0
            creation.hair.texture   = appearance.hair[2] or 0
            creation.hair.color     = appearance.hair[3] or 0
            creation.hair.highlight = appearance.hair[4] or 0
        end
        creation.eye = appearance.eye or 0
        if type(appearance.ovl) == 'table' then
            for _, entry in ipairs(appearance.ovl) do
                if entry[1] == OVL_BEARD then creation.beard = { index = entry[2], opacity = entry[3] } end
                if entry[1] == OVL_EYEBROWS then creation.eyebrows = { index = entry[2], opacity = entry[3] } end
            end
        end
        creation.comps = {}
        if type(appearance.comps) == 'table' then
            for _, c in ipairs(appearance.comps) do
                creation.comps[c[1]] = { drawable = c[2], texture = c[3] }
            end
        end
        creation.props = {}
        if type(appearance.props) == 'table' then
            for _, p in ipairs(appearance.props) do
                creation.props[p[1]] = { drawable = p[2], texture = p[3] }
            end
        end
        applyAll()
    end
end

exports('ApplyStoredAppearance', function()
    if lastModel then
        applyStoredAppearanceInternal(lastModel, lastAppearance)
    end
end)

-- ── Events serveur ──────────────────────────────────────────────────────
RegisterNetEvent('pvp_character:isNewPlayer')
AddEventHandler('pvp_character:isNewPlayer', function()
    isNewPlayer = true
end)

RegisterNetEvent('pvp_character:applyModel')
AddEventHandler('pvp_character:applyModel', function(data)
    lastModel      = data and data.model
    lastAppearance = data and data.appearance
    pendingApply   = data
    if NetworkIsPlayerActive(PlayerId()) and DoesEntityExist(PlayerPedId()) and GetEntityHealth(PlayerPedId()) > 0 then
        Citizen.CreateThread(function()
            Citizen.Wait(200)
            local d = pendingApply
            pendingApply = nil
            if not d then return end
            applyStoredAppearanceInternal(d.model, d.appearance)
        end)
    end
end)

-- ── Playerspawned : déclenche la création ou applique le modèle existant ──
-- Attend l'event serveur pvp_character:isNewPlayer avec retry (au lieu d'un
-- délai fixe) : le round-trip esx:playerLoaded → requête DB → event client
-- peut dépasser une fenêtre fixe, ce qui faisait que l'écran ne s'affichait
-- jamais auparavant.
AddEventHandler('playerSpawned', function()
    Citizen.CreateThread(function()
        local waited = 0
        while not isNewPlayer and not pendingApply and waited < 15000 do
            Citizen.Wait(200)
            waited = waited + 200
        end

        if isNewPlayer and not inCreation then
            inCreation = true
            creation = freshCreationState('male')
            setupPreviewScene()
            ensureModel('mp_m_freemode_01')
            captureDefaultOutfit()
            applyAll()
            SetNuiFocus(true, true)
            SendNUIMessage({ action = 'show' })
            SendNUIMessage({ action = 'state', state = buildSnapshot() })
            return
        end

        if pendingApply then
            local d = pendingApply
            pendingApply = nil
            applyStoredAppearanceInternal(d.model, d.appearance)
        end
    end)
end)

-- ── NUI : type de personnage ──────────────────────────────────────────────
RegisterNUICallback('setType', function(data, cb)
    if not inCreation then cb({}) return end
    creation.charType = (data and data.type == 'special') and 'special' or 'freemode'
    if creation.charType == 'freemode' then
        ensureModel(creation.model)
        captureDefaultOutfit()
        applyAll()
    end
    updatePreviewCam(creation.camMode)
    cb(buildSnapshot())
end)

RegisterNUICallback('setGender', function(data, cb)
    if not inCreation then cb({}) return end
    local gender = (data and data.gender == 'female') and 'female' or 'male'
    creation.gender = gender
    creation.model  = (gender == 'female') and 'mp_f_freemode_01' or 'mp_m_freemode_01'
    ensureModel(creation.model)
    captureDefaultOutfit()
    setSkin(creation.skinIdx)
    applyAll()
    updatePreviewCam(creation.camMode)
    cb(buildSnapshot())
end)

RegisterNUICallback('setSkin', function(data, cb)
    if not inCreation then cb({}) return end
    setSkin(data and data.index)
    cb({ ok = true })
end)

RegisterNUICallback('cycleFace', function(data, cb)
    if not inCreation then cb({}) return end
    cb(cycleFace(data and data.field, (data and data.dir) or 1))
end)

RegisterNUICallback('cycleHair', function(data, cb)
    if not inCreation then cb({}) return end
    cb(cycleHair(data and data.field, (data and data.dir) or 1))
end)

RegisterNUICallback('setHairColor', function(data, cb)
    if not inCreation then cb({}) return end
    setHairColor(data and data.color)
    cb({ ok = true })
end)

RegisterNUICallback('cycleComponent', function(data, cb)
    if not inCreation then cb({}) return end
    cb(cycleComponent(tonumber(data and data.comp) or 0, data and data.field, (data and data.dir) or 1))
end)

RegisterNUICallback('cycleProp', function(data, cb)
    if not inCreation then cb({}) return end
    cb(cycleProp(tonumber(data and data.prop) or 0, data and data.field, (data and data.dir) or 1))
end)

RegisterNUICallback('previewSpecialPed', function(data, cb)
    if not inCreation then cb({}) return end
    local model = data and data.model
    if type(model) ~= 'string' or model == '' then cb({ ok = false }) return end
    creation.specialModel = model
    ensureModel(model)
    updatePreviewCam(creation.camMode)  -- gabarits de peds très variables
    cb({ ok = true })
end)

RegisterNUICallback('randomizeAppearance', function(data, cb)
    if not inCreation or creation.charType ~= 'freemode' then cb(buildSnapshot()) return end
    setSkin(math.random(0, #SKIN_TONES - 1))
    creation.head[1] = math.random(0, 45)
    creation.head[2] = math.random(0, 45)
    creation.head[7] = math.random(0, 10) / 10.0
    applyHead()
    for _, slot in ipairs(COMPONENT_SLOTS) do
        cycleComponent(slot.id, 'drawable', math.random(1, 5))
    end
    cycleHair('drawable', math.random(1, 5))
    cb(buildSnapshot())
end)

RegisterNUICallback('rotatePed', function(data, cb)
    if not inCreation then cb({}) return end
    local dir = (data and data.dir) or 1
    creation.heading = (creation.heading + dir * 15.0) % 360.0
    SetEntityHeading(PlayerPedId(), creation.heading)
    -- La caméra ne bouge pas ici (voir updatePreviewCam) : seul le ped tourne.
    cb({ ok = true })
end)

RegisterNUICallback('setCamMode', function(data, cb)
    if not inCreation then cb({}) return end
    creation.camMode = (data and data.mode == 'face') and 'face' or 'body'
    updatePreviewCam(creation.camMode)
    cb({ ok = true })
end)

-- ── NUI : confirmation ──────────────────────────────────────────────────
RegisterNUICallback('confirmCharacter', function(data, cb)
    cb({})
    if not inCreation then return end

    local payload = {
        pseudo = data and data.pseudo or 'Joueur',
        type   = creation.charType,
        gender = creation.gender,
    }

    if creation.charType == 'special' then
        payload.model = creation.specialModel
    else
        payload.appearance = {
            v     = 1,
            head  = creation.head,
            hair  = { creation.hair.drawable, creation.hair.texture, creation.hair.color, creation.hair.highlight },
            eye   = creation.eye,
            ovl   = {
                { OVL_BEARD, creation.beard.index, creation.beard.opacity },
                { OVL_EYEBROWS, creation.eyebrows.index, creation.eyebrows.opacity },
            },
            ovlc  = {},
            comps = (function()
                local out = {}
                for id, c in pairs(creation.comps) do out[#out + 1] = { id, c.drawable, c.texture } end
                return out
            end)(),
            props = (function()
                local out = {}
                for id, p in pairs(creation.props) do out[#out + 1] = { id, p.drawable, p.texture } end
                return out
            end)(),
        }
    end

    TriggerServerEvent('pvp_character:saveCharacter', payload)
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

    lastModel      = data.model
    lastAppearance = data.appearance

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })

    Citizen.CreateThread(function()
        applyStoredAppearanceInternal(data.model, data.appearance)

        teardownPreviewScene()

        local ped = PlayerPedId()
        SetPedCanPlayAmbientAnims(ped, true)
        pcall(SetPedCanPlayGestureAnims, ped, true)
        SetEntityInvincible(ped, false)
        FreezeEntityPosition(ped, false)
        SetPlayerControl(PlayerId(), true, 0)

        -- pvp_spawn va maintenant recevoir setLoginOutpost (via pvp_character:characterReady serveur)
        -- et téléporter le joueur. En attendant on laisse le ped freeze court pour éviter la chute.
        FreezeEntityPosition(ped, true)
    end)
end)
