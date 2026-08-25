-- =============================================
--   PVP DROPS - Client
-- =============================================

local drop          = nil
local dropStartTime = 0
local isController  = false
local dropDone      = true

local planeEntity   = nil
local crateEntity   = nil
local planeBlip     = nil
local crateBlip     = nil

-- Phases : 'approach' → 'fall' → 'secured' → 'ready'
local phase         = nil
local landZ         = nil       -- Z de la surface d'impact (confirmée ou estimée)
local landConfirmed = false
local landedAt      = nil       -- GetGameTimer() au moment de l'atterrissage
local openDelayMs   = nil

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

-- =========================================================================
--   TRAJECTOIRE — flèches rouges sur la minimap
-- =========================================================================
-- La grande carte (pause) est rendue par le moteur : impossible d'y injecter
-- une texture custom sans streamer un minimap.ytd modifié. On dessine donc
-- les flèches sur la minimap (radar), et on retombe sur des petits blips
-- rouges UNIQUEMENT quand la grande carte est ouverte (voir plus bas).

local TXD_NAME  = 'vanta_drops_txd'
local TXN_ARROW = 'trail_arrow'
local trailReady = false

CreateThread(function()
    if not Config.Trail or not Config.Trail.enabled then return end
    local txd = CreateRuntimeTxd(TXD_NAME)
    if not txd then return end
    if CreateRuntimeTextureFromImage(txd, TXN_ARROW, Config.Trail.texture) then
        trailReady = true
    else
        print('[pvp_drops] Impossible de charger la texture de trajectoire : ' .. tostring(Config.Trail.texture))
    end
end)

-- Rectangle de la minimap en coordonnées écran (0.0 → 1.0)
local function getMinimapRect()
    local safeZone   = GetSafeZoneSize()
    local aspect     = GetAspectRatio(false)
    local resX, resY = GetActiveScreenResolution()
    if resX == 0 or resY == 0 or aspect == 0 then return nil end

    local xs, ys       = 1.0 / resX, 1.0 / resY
    local safeX, safeY = 1.0 / 20.0, (1.0 / 20.0) * aspect
    local pad          = math.abs(safeZone - 1.0) * 10.0

    local r    = {}
    r.width    = xs * (resX / (4 * aspect))
    r.height   = ys * (resY / 5.674)
    r.left     = xs * (resX * (safeX * pad))
    r.bottom   = 1.0 - ys * (resY * (safeY * pad))

    -- Minimap agrandie (bigmap) : le radar occupe une zone bien plus large.
    -- Facteurs approximatifs — ajuster ici si besoin.
    if IsBigmapActive and IsBigmapActive() then
        r.width  = r.width  * 3.0
        r.height = r.height * 2.0
        r.bigmap = true
    end

    r.top    = r.bottom - r.height
    r.right  = r.left + r.width
    r.cx     = r.left + r.width * 0.5
    r.cy     = r.bottom - r.height * 0.5
    return r
end

local function radarVisible()
    if IsPauseMenuActive() then return false end
    if IsRadarHidden() then return false end
    if IsHudHidden() then return false end
    return true
end

-- Dessine la chaîne de flèches entre les deux extrémités de la trajectoire
local function drawTrailArrows(d)
    local cfg = Config.Trail
    local rect = getMinimapRect()
    if not rect then return end

    local ped   = PlayerPedId()
    local pc    = GetEntityCoords(ped)
    local camH  = GetGameplayCamRot(2).z          -- 0 = Nord
    local rad   = math.rad(camH)
    local cosH, sinH = math.cos(rad), math.sin(rad)

    local range = rect.bigmap and cfg.bigmapRange or cfg.minimapRange
    if range <= 0.0 then return end
    -- mètres → fraction d'écran (la hauteur du rect couvre `range` mètres)
    local scale = rect.height / range

    -- Direction de la trajectoire
    local tdx, tdy = d.planeEndX - d.planeStartX, d.planeEndY - d.planeStartY
    local tlen = math.sqrt(tdx * tdx + tdy * tdy)
    if tlen < 1.0 then return end
    local ux, uy = tdx / tlen, tdy / tlen

    -- Projection du joueur sur la trajectoire → on ne parcourt que le
    -- segment réellement visible autour de lui (au lieu des 6 km).
    local proj = (pc.x - d.planeStartX) * ux + (pc.y - d.planeStartY) * uy
    local spacing = math.max(5.0, cfg.spacing)
    local span    = range * (rect.bigmap and 1.2 or 1.0) + spacing
    local iStart  = math.floor((proj - span) / spacing)
    local iEnd    = math.ceil((proj + span) / spacing)
    local iMax    = math.floor(tlen / spacing)
    if iStart < 0 then iStart = 0 end
    if iEnd > iMax then iEnd = iMax end
    if iEnd < iStart then return end

    -- Cap écran de la flèche : direction de la trajectoire ramenée
    -- dans le repère caméra (la minimap tourne avec le joueur).
    local aRight = tdx * cosH + tdy * sinH
    local aFwd   = -tdx * sinH + tdy * cosH
    local heading = math.deg(math.atan(aRight, aFwd)) + (cfg.rotationOffset or 0.0)

    local resX, resY = GetActiveScreenResolution()
    local aspect = (resY > 0) and (resX / resY) or 1.777
    local h = cfg.size
    local w = cfg.size / aspect

    -- Marge : on n'affiche pas les flèches qui dépasseraient de la minimap
    local mx, my = w * 0.5, h * 0.5
    local r, g, b = cfg.tint[1], cfg.tint[2], cfg.tint[3]

    -- Défilement lent des flèches vers le point de largage : la direction
    -- de la trajectoire se lit d'un coup d'œil.
    local scroll = 0.0
    if (cfg.scrollSpeed or 0.0) > 0.0 then
        scroll = (GetGameTimer() / 1000.0 * cfg.scrollSpeed) % spacing
    end

    for i = iStart - 1, iEnd do
        local dist = i * spacing + scroll
        if dist >= 0.0 and dist <= tlen then
            local wx = d.planeStartX + ux * dist
            local wy = d.planeStartY + uy * dist

            local dx, dy  = wx - pc.x, wy - pc.y
            local sxWorld =  dx * cosH + dy * sinH     -- droite
            local syWorld = -dx * sinH + dy * cosH     -- avant

            -- `scale` est une fraction de la HAUTEUR d'écran par mètre ;
            -- sur l'axe X il faut la convertir en fraction de largeur (/ aspect).
            local sx = rect.cx + (sxWorld * scale) / aspect
            local sy = rect.cy - syWorld * scale

            if sx > rect.left + mx and sx < rect.right - mx
            and sy > rect.top + my  and sy < rect.bottom - my then
                DrawSprite(TXD_NAME, TXN_ARROW, sx, sy, w, h, heading, r, g, b, cfg.alpha)
            end
        end
    end
end

-- ── Trajectoire sur la GRANDE carte (pause) ──────────────────────────────
local pauseTrailBlips = {}

local function removePauseTrailBlips()
    for _, b in ipairs(pauseTrailBlips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    pauseTrailBlips = {}
end

local function createPauseTrailBlips(d)
    removePauseTrailBlips()
    local spacing = math.max(50.0, Config.Trail.pauseMapSpacing or 300.0)
    local dx, dy  = d.planeEndX - d.planeStartX, d.planeEndY - d.planeStartY
    local len     = math.sqrt(dx * dx + dy * dy)
    local steps   = math.max(1, math.floor(len / spacing))
    for i = 0, steps do
        local pct = i / steps
        local blip = AddBlipForCoord(lerp(d.planeStartX, d.planeEndX, pct),
                                     lerp(d.planeStartY, d.planeEndY, pct), 200.0)
        SetBlipSprite(blip, 1)
        SetBlipColour(blip, 1)          -- rouge
        SetBlipScale(blip, 0.28)
        SetBlipAlpha(blip, 190)
        SetBlipAsShortRange(blip, false)
        SetBlipHiddenOnLegend(blip, true)
        pauseTrailBlips[#pauseTrailBlips + 1] = blip
    end
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
    planeBlipOnEntity = false
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

-- =========================================================================
--   ATTERRISSAGE — la caisse s'arrête au premier contact
-- =========================================================================
-- flags shapetest : 1 = monde/bâtiments, 2 = véhicules, 16 = objets
local PROBE_FLAGS = 1 + 2 + 16

-- Raycast vertical : renvoie le Z de la PREMIÈRE surface rencontrée en
-- descendant depuis fromZ, ou nil.
local function rayDown(x, y, fromZ, toZ, ignoreEntity)
    local handle = StartExpensiveSynchronousShapeTestLosProbe(
        x, y, fromZ, x, y, toZ, PROBE_FLAGS, ignoreEntity or 0, 4)
    local _, hit, coords = GetShapeTestResult(handle)
    if hit and hit ~= 0 and coords then
        local z = coords.z or coords[3]
        if z and z > -300.0 and z < 2000.0 then return z end
    end
    return nil
end

-- Meilleure estimation de la surface d'impact en (x, y) :
-- on prend le point le PLUS HAUT entre le raycast (toit de bâtiment, rocher,
-- prop...) et le sol GTA — c'est lui que la caisse doit toucher en premier.
local function findSurfaceZ(x, y, fromZ, ignoreEntity)
    RequestCollisionAtCoord(x, y, fromZ)
    local best = rayDown(x, y, fromZ, Config.LandingProbeBottom, ignoreEntity)

    local found, gz = GetGroundZFor_3dCoord(x, y, fromZ, false)
    if found and gz > -250.0 and gz < 1500.0 then
        if not best or gz > best then best = gz end
    end
    return best
end

-- Offset entre l'origine du modèle et sa face inférieure (pour poser la
-- caisse *sur* la surface au lieu de l'y enfoncer).
local function modelBottomOffset(hash)
    local min = GetModelDimensions(hash)
    if min and min.z then return -min.z end
    return 0.0
end

-- ── Cleanup ───────────────────────────────────────────────────────────────
local function cleanup()
    dropDone = true
    phase    = nil
    removePauseTrailBlips(); removePlaneBlip(); removeCrateBlip()
    if planeEntity and DoesEntityExist(planeEntity) then DeleteEntity(planeEntity) end
    if crateEntity and DoesEntityExist(crateEntity) then DeleteEntity(crateEntity) end
    planeEntity = nil; crateEntity = nil; drop = nil
    landZ = nil; landConfirmed = false; landedAt = nil; openDelayMs = nil
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then cleanup() end
end)

-- =========================================================================
--   RÉCEPTION DU DROP
-- =========================================================================
RegisterNetEvent('pvp_drops:start')
AddEventHandler('pvp_drops:start', function(data)
    cleanup()
    dropDone      = false
    drop          = data
    dropStartTime = GetGameTimer()
    isController  = (GetPlayerServerId(PlayerId()) == data.controller)
    phase         = 'approach'
    landZ         = data.fallbackZ or 30.0
    landConfirmed = false
    openDelayMs   = data.openDelay

    createPlaneBlip(calcHeading(data.planeStartX, data.planeStartY, data.planeEndX, data.planeEndY))
    StartDropThread()
    StartTrailThread()
end)

-- Surface d'impact confirmée (envoyée par le contrôleur via le serveur)
RegisterNetEvent('pvp_drops:landingCoords')
AddEventHandler('pvp_drops:landingCoords', function(dropId, lx, ly, lz)
    if not drop or drop.id ~= dropId then return end
    landZ = lz
end)

-- La caisse a touché une surface → tout le monde bascule en phase "sécurisé"
RegisterNetEvent('pvp_drops:landed')
AddEventHandler('pvp_drops:landed', function(dropId, lx, ly, lz, openDelay)
    if not drop or drop.id ~= dropId then return end
    landZ         = lz
    landConfirmed = true
    openDelayMs   = openDelay or openDelayMs
    if phase == 'approach' or phase == 'fall' then
        phase    = 'secured'
        landedAt = GetGameTimer()
    end
    removePauseTrailBlips()
    createCrateBlip(lx, ly, lz)   -- repositionné sur la vraie surface d'impact
end)

-- Le drop devient ouvrable (fin du délai, ou forcé par un admin)
RegisterNetEvent('pvp_drops:openNow')
AddEventHandler('pvp_drops:openNow', function(dropId)
    if not drop or drop.id ~= dropId then return end
    phase = 'ready'
end)

-- ── Drop ouvert / terminé ────────────────────────────────────────────────
RegisterNetEvent('pvp_drops:opened')
AddEventHandler('pvp_drops:opened', function(dropId)
    if not drop or drop.id ~= dropId then return end
    cleanup()
end)

-- =========================================================================
--   OUTILS DE TEST (admin)
-- =========================================================================
-- Avance tous les compteurs du drop en cours de `ms` millisecondes.
RegisterNetEvent('pvp_drops:timeShift')
AddEventHandler('pvp_drops:timeShift', function(dropId, ms)
    if not drop or drop.id ~= dropId then return end
    dropStartTime = dropStartTime - (tonumber(ms) or 0)
    if landedAt then landedAt = landedAt - (tonumber(ms) or 0) end
end)

-- Force la caisse à se poser immédiatement (contrôleur uniquement).
local forceLandRequested = false
RegisterNetEvent('pvp_drops:forceLand')
AddEventHandler('pvp_drops:forceLand', function(dropId)
    if not drop or drop.id ~= dropId then return end
    forceLandRequested = true
end)

-- Téléportation admin sur la caisse.
RegisterNetEvent('pvp_drops:tpToDrop')
AddEventHandler('pvp_drops:tpToDrop', function(x, y, z)
    local ped = PlayerPedId()
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoords(ped, x + 2.0, y + 2.0, z + 1.0, false, false, false, false)
end)

-- =========================================================================
--   THREAD TRAJECTOIRE
-- =========================================================================
function StartTrailThread()
    CreateThread(function()
        local myId = drop and drop.id
        if not myId then return end
        if not Config.Trail or not Config.Trail.enabled then return end

        local pauseBlipsUp = false

        while not dropDone and drop and drop.id == myId and phase == 'approach' do
            local d = drop

            -- Grande carte ouverte → blips discrets (le moteur ne rend pas
            -- les sprites custom sur la carte de pause).
            if Config.Trail.pauseMapBlips then
                local paused = IsPauseMenuActive()
                if paused and not pauseBlipsUp then
                    createPauseTrailBlips(d)
                    pauseBlipsUp = true
                elseif not paused and pauseBlipsUp then
                    removePauseTrailBlips()
                    pauseBlipsUp = false
                end
            end

            if trailReady and radarVisible() then
                drawTrailArrows(d)
            end
            Wait(0)
        end

        removePauseTrailBlips()
    end)
end

-- =========================================================================
--   THREAD PRINCIPAL
-- =========================================================================
function StartDropThread()
    CreateThread(function()
        local d    = drop
        local myId = d.id

        local hdg = calcHeading(d.planeStartX, d.planeStartY, d.planeEndX, d.planeEndY)

        -- Temps total de vol : approachTime * 2 (largage au milieu selon dropPct)
        local planeTotalTime = d.approachTime * 2
        local dropTimeMs     = d.dropPct * planeTotalTime

        local flightZ = (d.fallbackZ or 30.0) + d.altitude + 50.0

        -- ── Spawn avion (contrôleur) ─────────────────────────────────────
        if isController then
            CreateThread(function()
                local hash = loadModel(Config.PlaneModel)
                if not HasModelLoaded(hash) then hash = loadModel('titan') end
                planeEntity = CreateVehicle(hash, d.planeStartX, d.planeStartY, flightZ,
                    hdg, true, false)
                SetEntityAsMissionEntity(planeEntity, true, true)
                SetVehicleEngineOn(planeEntity, true, true, false)
                SetVehicleDoorsLocked(planeEntity, 4)
                SetModelAsNoLongerNeeded(hash)
                if planeEntity and DoesEntityExist(planeEntity) then
                    attachPlaneBlipToEntity(planeEntity)
                end
            end)

            -- Recherche de la surface d'impact en arrière-plan, avant même
            -- le largage : la caisse saura où s'arrêter dès sa création.
            CreateThread(function()
                for _ = 1, 20 do
                    if dropDone or not drop or drop.id ~= myId then return end
                    local z = findSurfaceZ(d.dropX, d.dropY, Config.LandingProbeTop, crateEntity)
                    if z then
                        landZ = z
                        TriggerServerEvent('pvp_drops:reportGroundZ', myId, d.dropX, d.dropY, z)
                        return
                    end
                    Wait(500)
                end
            end)
        end

        local crateSpawned   = false
        local crateSpawnDone = false
        local crateBottom    = 0.0
        local fallStartZ     = nil
        local fallSpeed      = 0.0
        local lastProbe      = 0
        local landReported   = false

        forceLandRequested = false

        while not dropDone and drop and drop.id == myId do
            Wait(0)

            local now     = GetGameTimer()
            local elapsed = now - dropStartTime
            local ped     = PlayerPedId()
            local pc      = GetEntityCoords(ped)

            -- ── Avion (continue sa route après le largage) ───────────────
            local planePct = math.min(elapsed / planeTotalTime, 1.0)
            if planePct < 1.0 then
                local px = lerp(d.planeStartX, d.planeEndX, planePct)
                local py = lerp(d.planeStartY, d.planeEndY, planePct)
                updatePlaneBlip(px, py, hdg)
                if isController and planeEntity and DoesEntityExist(planeEntity) then
                    SetEntityCoordsNoOffset(planeEntity, px, py, flightZ, false, false, false)
                    SetEntityHeading(planeEntity, hdg)
                end
            else
                removePlaneBlip()
                if isController and planeEntity and DoesEntityExist(planeEntity) then
                    DeleteEntity(planeEntity)
                    planeEntity = nil
                end
            end

            -- ── Largage ──────────────────────────────────────────────────
            if phase == 'approach' and elapsed >= dropTimeMs then
                phase        = 'fall'
                crateSpawned = true
                removePauseTrailBlips()
                createCrateBlip(d.dropX, d.dropY, landZ or 30.0)

                if #(pc - vector3(d.dropX, d.dropY, landZ or pc.z)) < 2000.0 then
                    SetNotificationTextEntry('STRING')
                    AddTextComponentString('~y~★ LARGAGE~s~ ! La caisse descend en parachute !')
                    DrawNotification(false, false)
                end

                -- la caisse quitte l'avion : même altitude, 50 m plus bas
                fallStartZ = flightZ - 50.0
                fallSpeed  = d.altitude / math.max(1, d.fallDuration)   -- m/ms

                if isController then
                    CreateThread(function()
                        local hash = loadModel(Config.CrateModel)
                        crateBottom = modelBottomOffset(hash)
                        crateEntity = CreateObject(hash, d.dropX, d.dropY, fallStartZ,
                            true, false, false)
                        SetEntityAsMissionEntity(crateEntity, true, true)
                        SetEntityCollision(crateEntity, false, false)
                        FreezeEntityPosition(crateEntity, true)
                        SetModelAsNoLongerNeeded(hash)
                        crateSpawnDone = true
                    end)
                else
                    crateSpawnDone = true
                end
            end

            -- ── Chute : arrêt au premier contact ─────────────────────────
            if phase == 'fall' then
                local fallEl = elapsed - dropTimeMs
                local cz     = (fallStartZ or (flightZ - 50.0)) - fallSpeed * fallEl

                if isController and crateSpawnDone then
                    -- Ré-sondage périodique : la collision peut arriver en
                    -- streaming APRÈS le largage (bâtiment, relief...).
                    if now - lastProbe >= (Config.LandingRefreshMs or 400) then
                        lastProbe = now
                        RequestCollisionAtCoord(d.dropX, d.dropY, cz)

                        -- 1) sonde courte sous la caisse (surface imminente)
                        local hit = rayDown(d.dropX, d.dropY, cz - 0.2,
                            cz - (Config.LandingLookAhead or 60.0), crateEntity)
                        -- 2) sonde longue tant que rien n'est confirmé
                        if not hit and not landConfirmed then
                            hit = findSurfaceZ(d.dropX, d.dropY, cz - 0.2, crateEntity)
                        end
                        if hit and (not landZ or hit > landZ or not landConfirmed) then
                            landZ = hit
                        end
                    end

                    local target = landZ or 0.0
                    local touched = forceLandRequested or (cz <= target)
                    if touched then
                        -- Dernière sonde précise avant de poser la caisse
                        local exact = findSurfaceZ(d.dropX, d.dropY,
                            math.max(cz, target) + 5.0, crateEntity)
                        if exact then target = exact end
                        landZ = target
                        cz    = target

                        if crateEntity and DoesEntityExist(crateEntity) then
                            SetEntityCoordsNoOffset(crateEntity, d.dropX, d.dropY,
                                target + crateBottom, false, false, false)
                            SetEntityCollision(crateEntity, true, true)
                            FreezeEntityPosition(crateEntity, true)
                        end
                        forceLandRequested = false
                        -- une seule notification serveur, même si la réponse tarde
                        if not landReported then
                            landReported = true
                            TriggerServerEvent('pvp_drops:reportLanded', myId, d.dropX, d.dropY, target)
                        end
                    elseif crateEntity and DoesEntityExist(crateEntity) then
                        SetEntityCoordsNoOffset(crateEntity, d.dropX, d.dropY,
                            cz + crateBottom, false, false, false)
                    end
                end

                -- Timer 3D (visible à 800m)
                local dist = #(pc - vector3(d.dropX, d.dropY, landZ or pc.z))
                if dist < 800.0 then
                    local rem = d.fallDuration - fallEl
                    draw3DText(d.dropX, d.dropY, cz + 3.0,
                        'CHUTE  ' .. fmtTime(rem), 255, 200, 50, 0.6)
                end
            end

            -- ── Caisse posée : délai de sécurisation ─────────────────────
            if phase == 'secured' then
                local lz      = landZ or 30.0
                local landEl  = now - (landedAt or now)
                local openRem = (openDelayMs or 0) - landEl
                local dist    = #(pc - vector3(d.dropX, d.dropY, lz))

                if dist < 300.0 then
                    DrawMarker(1, d.dropX, d.dropY, lz + 0.1,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        3.5, 3.5, 1.5, 200, 50, 50, 100,
                        false, true, 2, false, nil, nil, false)
                    draw3DText(d.dropX, d.dropY, lz + 4.0,
                        'SÉCURISÉ  ' .. fmtTime(openRem), 255, 80, 50, 0.65)
                end

                if openRem <= 0 then phase = 'ready' end
            end

            -- ── Caisse prête ─────────────────────────────────────────────
            if phase == 'ready' then
                local lz   = landZ or 30.0
                local dist = #(pc - vector3(d.dropX, d.dropY, lz))

                if dist < 300.0 then
                    local pulse = math.abs(math.sin(now / 400.0)) * 0.8
                    DrawMarker(1, d.dropX, d.dropY, lz + 0.1,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        3.0 + pulse, 3.0 + pulse, 1.5, 50, 220, 100, 120,
                        false, true, 2, false, nil, nil, false)

                    local label = dist <= Config.InteractRadius + 5.0
                        and '★  OUVRIR  [E]' or '★  DROP DISPONIBLE'
                    draw3DText(d.dropX, d.dropY, lz + 4.5, label, 80, 255, 120, 0.75)
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
