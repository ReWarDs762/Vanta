-- =============================================
--   PVP DROPS - Client
-- =============================================

local drop          = nil
local dropStartTime = 0
local isController  = false
local dropDone      = false

local planeEntity   = nil
local crateEntity   = nil
local planeBlip     = nil
local crateBlip     = nil
local trailBlips    = {}

-- ── Utilitaires ──────────────────────────────────────────────────────────
local function fmtTime(ms)
    local s = math.max(0, math.floor(ms / 1000))
    return string.format('%d:%02d', math.floor(s / 60), s % 60)
end

local function lerp(a, b, t) return a + (b - a) * t end

local function loadModel(name)
    local hash = GetHashKey(name)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 8000 do Wait(50); t = t + 50 end
    return hash
end

local function calcHeading(x1, y1, x2, y2)
    -- GTA heading : 0=Nord, 90=Ouest (anti-horaire)
    -- atan2(dx, dy) donne 0=Nord, 90=Est (horaire)
    -- → inverser avec 360 - angle
    local h = math.deg(math.atan(x2 - x1, y2 - y1))
    if h < 0 then h = h + 360 end
    h = 360.0 - h
    if h >= 360.0 then h = h - 360.0 end
    return h
end

local function draw3DText(x, y, z, text, r, g, b, scale)
    SetDrawOrigin(x, y, z, 0)
    SetTextFont(4)
    SetTextScale(0.0, scale or 0.5)
    SetTextColour(r, g, b, 255)
    SetTextCentre(true)
    SetTextOutline()
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

-- ── Trajectoire : flèches rouges ─────────────────────────────────────────
local function createTrailBlips(d)
    for _, b in ipairs(trailBlips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    trailBlips = {}

    local dx  = d.planeEndX - d.planeStartX
    local dy  = d.planeEndY - d.planeStartY
    local len = math.sqrt(dx * dx + dy * dy)
    local hdg = calcHeading(d.planeStartX, d.planeStartY, d.planeEndX, d.planeEndY)
    local steps = math.floor(len / 350)

    for i = 0, steps do
        local pct = i / math.max(steps, 1)
        local bx  = lerp(d.planeStartX, d.planeEndX, pct)
        local by  = lerp(d.planeStartY, d.planeEndY, pct)
        local blip = AddBlipForCoord(bx, by, 200.0)
        SetBlipSprite(blip, 1)
        SetBlipColour(blip, 1)              -- rouge
        SetBlipScale(blip, 0.8)
        ShowHeadingIndicatorOnBlip(blip, true) -- cône directionnel
        SetBlipRotation(blip, math.floor(hdg))
        SetBlipAsShortRange(blip, false)
        trailBlips[#trailBlips + 1] = blip
    end
end

local function removeTrailBlips()
    for _, b in ipairs(trailBlips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    trailBlips = {}
end

-- ── Blip avion mobile ─────────────────────────────────────────────────────
local planeBlipOnEntity = false  -- true si le blip est attaché à l'entité avion

local function createPlaneBlip(hdg)
    if planeBlip and DoesBlipExist(planeBlip) then RemoveBlip(planeBlip) end
    planeBlipOnEntity = false
    planeBlip = AddBlipForCoord(0.0, 0.0, 0.0)
    SetBlipSprite(planeBlip, 307)
    SetBlipColour(planeBlip, 6)
    SetBlipScale(planeBlip, 1.2)
    SetBlipAsShortRange(planeBlip, false)
    ShowHeadingIndicatorOnBlip(planeBlip, true)
    if hdg then SetBlipRotation(planeBlip, math.floor(hdg)) end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Avion de ravitaillement')
    EndTextCommandSetBlipName(planeBlip)
end

-- Attacher le blip à l'entité avion (heading auto par le moteur GTA)
local function attachPlaneBlipToEntity(entity)
    if planeBlip and DoesBlipExist(planeBlip) then RemoveBlip(planeBlip) end
    planeBlip = AddBlipForEntity(entity)
    SetBlipSprite(planeBlip, 307)
    SetBlipColour(planeBlip, 6)
    SetBlipScale(planeBlip, 1.2)
    SetBlipAsShortRange(planeBlip, false)
    ShowHeadingIndicatorOnBlip(planeBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Avion de ravitaillement')
    EndTextCommandSetBlipName(planeBlip)
    planeBlipOnEntity = true
end

local function updatePlaneBlip(x, y, hdg)
    if planeBlip and DoesBlipExist(planeBlip) and not planeBlipOnEntity then
        SetBlipCoords(planeBlip, x, y, 200.0)
        SetBlipRotation(planeBlip, math.floor(hdg))
    end
end

local function removePlaneBlip()
    if planeBlip and DoesBlipExist(planeBlip) then RemoveBlip(planeBlip) end
    planeBlip = nil
end

-- ── Blip caisse ───────────────────────────────────────────────────────────
local function createCrateBlip(x, y, z)
    if crateBlip and DoesBlipExist(crateBlip) then RemoveBlip(crateBlip) end
    crateBlip = AddBlipForCoord(x, y, z)
    SetBlipSprite(crateBlip, 545)
    SetBlipColour(crateBlip, 1)
    SetBlipScale(crateBlip, 1.5)
    SetBlipDisplay(crateBlip, 2)
    SetBlipFlashes(crateBlip, true)
    SetBlipAsShortRange(crateBlip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('★ DROP de Ravitaillement')
    EndTextCommandSetBlipName(crateBlip)
end

local function removeCrateBlip()
    if crateBlip and DoesBlipExist(crateBlip) then RemoveBlip(crateBlip) end
    crateBlip = nil
end

-- ── Cleanup ───────────────────────────────────────────────────────────────
local function cleanup()
    dropDone = true
    removeTrailBlips(); removePlaneBlip(); removeCrateBlip()
    if planeEntity and DoesEntityExist(planeEntity) then DeleteEntity(planeEntity) end
    if crateEntity and DoesEntityExist(crateEntity) then DeleteEntity(crateEntity) end
    planeEntity = nil; crateEntity = nil; drop = nil
end

-- ── Réception du drop ────────────────────────────────────────────────────
RegisterNetEvent('pvp_drops:start')
AddEventHandler('pvp_drops:start', function(data)
    cleanup()
    dropDone    = false
    drop        = data
    -- Initialiser landZ dès réception si le serveur l'a envoyé
    if data.landZ then drop.landZ = data.landZ end
    dropStartTime = GetGameTimer()
    isController  = (GetPlayerServerId(PlayerId()) == data.controller)

    local hdg = calcHeading(data.planeStartX, data.planeStartY, data.planeEndX, data.planeEndY)
    createTrailBlips(data)
    createPlaneBlip(hdg)

    StartDropThread()
end)

-- ── Ground Z reçu du serveur (optionnel, affine la position) ─────────────
RegisterNetEvent('pvp_drops:landingCoords')
AddEventHandler('pvp_drops:landingCoords', function(dropId, lx, ly, lz)
    if not drop or drop.id ~= dropId then return end
    drop.landZ = lz  -- on affine le Z uniquement, XY déjà connus
end)

-- ── Drop ouvert ───────────────────────────────────────────────────────────
RegisterNetEvent('pvp_drops:opened')
AddEventHandler('pvp_drops:opened', function(dropId)
    if not drop or drop.id ~= dropId then return end
    cleanup()
end)

-- ── Thread principal ──────────────────────────────────────────────────────
function StartDropThread()
    CreateThread(function()
        local d   = drop
        local myId = d.id

        local dx  = d.planeEndX - d.planeStartX
        local dy  = d.planeEndY - d.planeStartY
        local hdg = calcHeading(d.planeStartX, d.planeStartY, d.planeEndX, d.planeEndY)

        -- Temps total de vol : approachTime * 2 (drop au milieu selon dropPct)
        local planeTotalTime = d.approachTime * 2
        local dropTimeMs     = d.dropPct * planeTotalTime

        -- Z par défaut : utiliser le Z envoyé par le serveur (zone connue), sinon fallback
        local DEFAULT_Z = d.landZ or 30.0

        -- Spawn avion (contrôleur)
        if isController then
            CreateThread(function()
                local hash = loadModel(Config.PlaneModel)
                if not HasModelLoaded(hash) then hash = loadModel('titan') end
                local az = DEFAULT_Z + d.altitude + 50.0
                planeEntity = CreateVehicle(hash,
                    d.planeStartX, d.planeStartY, az,
                    hdg, true, false)
                SetEntityAsMissionEntity(planeEntity, true, true)
                SetVehicleEngineOn(planeEntity, true, true, false)
                SetVehicleDoorsLocked(planeEntity, 4)
                SetModelAsNoLongerNeeded(hash)

                -- Attacher le blip à l'entité avion → heading automatique
                if planeEntity and DoesEntityExist(planeEntity) then
                    attachPlaneBlipToEntity(planeEntity)
                end

                -- Calculer le Z du sol en arrière-plan (essais multiples)
                CreateThread(function()
                    local gz = nil
                    -- Essayer plusieurs fois avec des hauteurs de scan différentes
                    for attempt = 1, 10 do
                        RequestCollisionAtCoord(d.dropX, d.dropY, 1000.0)
                        Wait(1000)
                        -- Tester depuis plusieurs hauteurs
                        for _, testZ in ipairs({1000.0, 800.0, 500.0, 300.0, 100.0}) do
                            local found, z = GetGroundZFor_3dCoord(d.dropX, d.dropY, testZ, false)
                            if found and z > -50 and z < 1500 then
                                gz = z
                                break
                            end
                        end
                        if gz then break end
                    end
                    if gz then
                        TriggerServerEvent('pvp_drops:reportGroundZ', d.id, d.dropX, d.dropY, gz)
                    end
                end)
            end)
        end

        local crateSpawned   = false
        local crateSpawnDone = false
        local crateLanded    = false
        local canOpen        = false

        while not dropDone and drop and drop.id == myId do
            Wait(0)

            local elapsed  = GetGameTimer() - dropStartTime
            local planePct = math.min(elapsed / planeTotalTime, 1.0)
            local landZ    = drop.landZ or DEFAULT_Z

            -- Position de l'avion
            local px = lerp(d.planeStartX, d.planeEndX, planePct)
            local py = lerp(d.planeStartY, d.planeEndY, planePct)
            local az = landZ + d.altitude + 50.0

            updatePlaneBlip(px, py, hdg)

            if isController and planeEntity and DoesEntityExist(planeEntity) then
                SetEntityCoordsNoOffset(planeEntity, px, py, az, false, false, false)
                SetEntityHeading(planeEntity, hdg)
            end
            if planePct >= 1.0 then removePlaneBlip() end

            -- ── Largage (dropTimeMs atteint) ────────────────────────────
            if elapsed >= dropTimeMs and not crateSpawned then
                crateSpawned = true
                removeTrailBlips()

                -- Blip caisse visible immédiatement
                createCrateBlip(d.dropX, d.dropY, landZ)

                -- Notification
                local ped = PlayerPedId()
                local pc  = GetEntityCoords(ped)
                if #(pc - vector3(d.dropX, d.dropY, landZ)) < 2000.0 then
                    SetNotificationTextEntry('STRING')
                    AddTextComponentString('~y~★ LARGAGE~s~ ! La caisse descend en parachute !')
                    DrawNotification(false, false)
                end

                -- Spawn caisse (contrôleur)
                if isController then
                    CreateThread(function()
                        local hash = loadModel(Config.CrateModel)
                        crateEntity = CreateObject(hash,
                            d.dropX, d.dropY, landZ + d.altitude,
                            true, false, false)
                        SetEntityAsMissionEntity(crateEntity, true, true)
                        FreezeEntityPosition(crateEntity, true)
                        SetModelAsNoLongerNeeded(hash)
                        crateSpawnDone = true
                    end)
                else
                    crateSpawnDone = true
                end
            end

            -- ── Animation chute ─────────────────────────────────────────
            if crateSpawned and crateSpawnDone and not crateLanded then
                local fallEl   = elapsed - dropTimeMs
                local fallPct  = math.min(fallEl / d.fallDuration, 1.0)

                -- Z du sol : utiliser landZ reçu, sinon tenter en temps réel
                local landZ2 = drop.landZ
                if not landZ2 then
                    local found, gz = GetGroundZFor_3dCoord(d.dropX, d.dropY, 1000.0, false)
                    if found and gz > -50 and gz < 1500 then
                        drop.landZ = gz
                        landZ2 = gz
                        TriggerServerEvent('pvp_drops:reportGroundZ', d.id, d.dropX, d.dropY, gz)
                    else
                        landZ2 = DEFAULT_Z
                    end
                end

                local cz  = lerp(landZ2 + d.altitude, landZ2 + 0.1, fallPct)
                local rem = d.fallDuration - fallEl

                -- Sécurité : si la caisse est sous le sol, la remonter
                if cz < landZ2 + 0.1 then cz = landZ2 + 0.1 end

                -- Déplacer la caisse
                if isController and crateEntity and DoesEntityExist(crateEntity) then
                    SetEntityCoordsNoOffset(crateEntity, d.dropX, d.dropY, cz, false, false, false)
                end

                -- Timer 3D (visible à 800m)
                local ped  = PlayerPedId()
                local pc   = GetEntityCoords(ped)
                local dist = #(pc - vector3(d.dropX, d.dropY, landZ2))

                if dist < 800.0 then
                    draw3DText(d.dropX, d.dropY, cz + 3.0,
                        'CHUTE  ' .. fmtTime(rem), 255, 200, 50, 0.6)
                end

                if fallPct >= 1.0 then
                    crateLanded = true
                    if isController and crateEntity and DoesEntityExist(crateEntity) then
                        SetEntityCoordsNoOffset(crateEntity, d.dropX, d.dropY, landZ2 + 0.1, false, false, false)
                        FreezeEntityPosition(crateEntity, true)
                    end
                    createCrateBlip(d.dropX, d.dropY, landZ2)
                end
            end

            -- ── Timer après atterrissage ─────────────────────────────────
            if crateLanded and not canOpen then
                local landZ3  = drop.landZ or DEFAULT_Z
                local landEl  = elapsed - dropTimeMs - d.fallDuration
                local openRem = d.openDelay - landEl

                local ped  = PlayerPedId()
                local pc   = GetEntityCoords(ped)
                local dist = #(pc - vector3(d.dropX, d.dropY, landZ3))

                if dist < 300.0 then
                    DrawMarker(1,
                        d.dropX, d.dropY, landZ3 + 0.1,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        3.5, 3.5, 1.5,
                        200, 50, 50, 100,
                        false, true, 2, false, nil, nil, false)
                    draw3DText(d.dropX, d.dropY, landZ3 + 4.0,
                        'SÉCURISÉ  ' .. fmtTime(openRem), 255, 80, 50, 0.65)
                end

                if landEl >= d.openDelay then canOpen = true end
            end

            -- ── Caisse prête ─────────────────────────────────────────────
            if canOpen then
                local landZ4 = drop.landZ or DEFAULT_Z
                local ped    = PlayerPedId()
                local pc     = GetEntityCoords(ped)
                local dist   = #(pc - vector3(d.dropX, d.dropY, landZ4))

                if dist < 300.0 then
                    local pulse = math.abs(math.sin(GetGameTimer() / 400.0)) * 0.8
                    DrawMarker(1,
                        d.dropX, d.dropY, landZ4 + 0.1,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        3.0 + pulse, 3.0 + pulse, 1.5,
                        50, 220, 100, 120,
                        false, true, 2, false, nil, nil, false)

                    local label = dist <= Config.InteractRadius + 5.0
                        and '★  OUVRIR  [E]' or '★  DROP DISPONIBLE'
                    draw3DText(d.dropX, d.dropY, landZ4 + 4.5,
                        label, 80, 255, 120, 0.75)
                end

                if dist <= Config.InteractRadius then
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentString('Appuie sur ~INPUT_CONTEXT~ pour ouvrir le drop')
                    EndTextCommandDisplayHelp(0, false, true, -1)
                    if IsControlJustPressed(0, 38) then
                        TriggerServerEvent('pvp_drops:open', drop.id)
                    end
                end
            end
        end
    end)
end
