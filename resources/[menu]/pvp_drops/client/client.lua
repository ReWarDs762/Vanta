-- =============================================
--   PVP DROPS - Client
-- =============================================

local drop          = nil
local dropStartTime = 0
local isController  = false
local dropDone      = true

-- Génération : incrémentée à chaque `pvp_drops:start` reçu. Le thread principal
-- capture la valeur courante et s'arrête dès qu'elle change — sans ça, un second
-- `pvp_drops:start` (resync) laissait deux threads tourner en parallèle sur le
-- même drop (markers doublés, entités spawnées deux fois).
local dropGen       = 0

local planeEntity   = nil
local crateEntity   = nil
local planeBlip     = nil
local crateBlip     = nil
local trailBlips    = {}

local planeSpawning = false
local crateSpawning = false
local flaresSpawning = false

local flarePtfx     = {}    -- handles de particules (locaux à ce client)
local flareProps    = {}    -- props réseau (contrôleur uniquement)
local flaresStarted = false

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

-- ── Reprise d'entités existantes (failover de contrôleur) ────────────────
-- Quand le contrôleur se déconnecte, ses entités ne disparaissent pas
-- forcément (OneSync les migre). Le nouveau contrôleur doit donc d'abord
-- tenter de reprendre celles déjà en jeu avant d'en créer de nouvelles,
-- sinon on se retrouve avec deux avions / deux caisses.
--
-- Le filtre `NetworkGetEntityIsNetworked` est indispensable : les modèles
-- utilisés (prop_mil_crate_01, prop_flare_01, cargoplane) existent aussi en
-- décor statique sur la carte — Fort Zancudo est à la fois une zone de drop
-- ET un endroit rempli de caisses militaires. Sans ce filtre, un nouveau
-- contrôleur pouvait « adopter » un prop de la map et se mettre à le
-- téléporter.
local function findEntityNear(poolName, modelHash, x, y, z, radius)
    for _, ent in ipairs(GetGamePool(poolName)) do
        if DoesEntityExist(ent)
           and GetEntityModel(ent) == modelHash
           and NetworkGetEntityIsNetworked(ent) then
            if #(GetEntityCoords(ent) - vector3(x, y, z)) <= radius then
                return ent
            end
        end
    end
    return nil
end

local function requestControl(ent)
    if not DoesEntityExist(ent) then return false end
    if NetworkGetEntityIsNetworked(ent) then
        local t = 0
        while not NetworkHasControlOfEntity(ent) and t < 2000 do
            NetworkRequestControlOfEntity(ent)
            Wait(50); t = t + 50
        end
    end
    return DoesEntityExist(ent)
end

-- ── Trajectoire : petites flèches rouges clignotantes ────────────────────
-- Sprite 1 + ShowHeadingIndicatorOnBlip = pointe directionnelle GTA:O, orientée
-- le long de la trajectoire. SetBlipFlashes/SetBlipFlashInterval les fait
-- clignoter ; l'intervalle est décalé par flèche pour donner un effet de vague
-- qui « coule » dans le sens de vol.
local function removeTrailBlips()
    for _, b in ipairs(trailBlips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    trailBlips = {}
end

local function createTrailBlips(d)
    removeTrailBlips()

    local dx  = d.planeEndX - d.planeStartX
    local dy  = d.planeEndY - d.planeStartY
    local len = math.sqrt(dx * dx + dy * dy)
    local hdg = calcHeading(d.planeStartX, d.planeStartY, d.planeEndX, d.planeEndY)
    local steps = math.max(1, math.floor(len / Config.TrailSpacing))

    for i = 0, steps do
        local pct = i / steps
        local bx  = lerp(d.planeStartX, d.planeEndX, pct)
        local by  = lerp(d.planeStartY, d.planeEndY, pct)

        local blip = AddBlipForCoord(bx, by, 200.0)
        SetBlipSprite(blip, 1)
        SetBlipColour(blip, 1)                  -- rouge
        SetBlipScale(blip, Config.TrailScale)   -- petites flèches
        ShowHeadingIndicatorOnBlip(blip, true)  -- pointe directionnelle
        SetBlipRotation(blip, math.floor(hdg))
        SetBlipAsShortRange(blip, false)
        SetBlipFlashes(blip, true)
        SetBlipFlashInterval(blip, Config.TrailFlashBase + (i % 4) * Config.TrailFlashStagger)

        trailBlips[#trailBlips + 1] = blip
    end
end

-- ── Blip avion mobile ─────────────────────────────────────────────────────
local planeBlipOnEntity = false  -- true si le blip est attaché à l'entité avion

local function nameBlip(blip, label)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label)
    EndTextCommandSetBlipName(blip)
end

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
    nameBlip(planeBlip, 'Avion de ravitaillement')
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
    nameBlip(planeBlip, 'Avion de ravitaillement')
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
    nameBlip(crateBlip, 'Drop de ravitaillement')
end

local function removeCrateBlip()
    if crateBlip and DoesBlipExist(crateBlip) then RemoveBlip(crateBlip) end
    crateBlip = nil
end

-- ── Fusées éclairantes autour de la caisse ───────────────────────────────
local function flarePos(i, cx, cy)
    local a = ((i - 1) / Config.FlareCount) * math.pi * 2
    return cx + math.cos(a) * Config.FlareRadius,
           cy + math.sin(a) * Config.FlareRadius
end

local function clearFlares()
    for _, h in ipairs(flarePtfx) do
        if DoesParticleFxLoopedExist(h) then StopParticleFxLooped(h, false) end
    end
    flarePtfx = {}

    for _, obj in ipairs(flareProps) do
        if DoesEntityExist(obj) then
            SetEntityAsMissionEntity(obj, true, true)
            DeleteEntity(obj)
        end
    end
    flareProps = {}
    flaresStarted  = false
    flaresSpawning = false
end

-- Particules + son : locaux à chaque client (pas de réseau, pas de doublon).
local function startLocalFlares(cx, cy, cz)
    local gen = dropGen

    PlaySoundFromCoord(-1, Config.FlareSoundName, cx, cy, cz,
        Config.FlareSoundSet, false, Config.FlareSoundRange, false)

    CreateThread(function()
        RequestNamedPtfxAsset(Config.FlarePtfxDict)
        local t = 0
        while not HasNamedPtfxAssetLoaded(Config.FlarePtfxDict) and t < 5000 do
            Wait(50); t = t + 50
        end
        if not HasNamedPtfxAssetLoaded(Config.FlarePtfxDict) then return end
        if dropDone or dropGen ~= gen then return end

        for i = 1, Config.FlareCount do
            local fx, fy = flarePos(i, cx, cy)
            UseParticleFxAssetNextCall(Config.FlarePtfxDict)
            local handle = StartParticleFxLoopedAtCoord(
                Config.FlarePtfxName,
                fx, fy, cz + 0.15,
                0.0, 0.0, 0.0,
                1.3, false, false, false, false
            )
            flarePtfx[#flarePtfx + 1] = handle
        end
    end)
end

-- Props : réseau, donc contrôleur uniquement.
local function ensureFlareProps(cx, cy, cz)
    if not isController or flaresSpawning or #flareProps > 0 then return end
    flaresSpawning = true
    local gen = dropGen

    CreateThread(function()
        local hash = loadModel(Config.FlareModel)
        if not HasModelLoaded(hash) or dropDone or dropGen ~= gen then
            flaresSpawning = false
            return
        end

        for i = 1, Config.FlareCount do
            local fx, fy = flarePos(i, cx, cy)
            -- Reprise après failover : ne pas doubler les fusées déjà posées.
            local existing = findEntityNear('CObject', hash, fx, fy, cz, 2.0)
            if existing then
                requestControl(existing)
                flareProps[#flareProps + 1] = existing
            else
                local obj = CreateObject(hash, fx, fy, cz + 0.05, true, false, false)
                SetEntityAsMissionEntity(obj, true, true)
                PlaceObjectOnGroundProperly(obj)
                FreezeEntityPosition(obj, true)
                flareProps[#flareProps + 1] = obj
            end
        end

        SetModelAsNoLongerNeeded(hash)
        flaresSpawning = false
    end)
end

-- ── Cleanup ───────────────────────────────────────────────────────────────
local function cleanup()
    dropDone = true
    removeTrailBlips(); removePlaneBlip(); removeCrateBlip()
    clearFlares()

    if planeEntity and DoesEntityExist(planeEntity) then
        SetEntityAsMissionEntity(planeEntity, true, true)
        DeleteEntity(planeEntity)
    end
    if crateEntity and DoesEntityExist(crateEntity) then
        SetEntityAsMissionEntity(crateEntity, true, true)
        DeleteEntity(crateEntity)
    end

    planeEntity = nil; crateEntity = nil; drop = nil
    planeSpawning = false; crateSpawning = false
    isController = false
end

-- ── Entités pilotées par le contrôleur ───────────────────────────────────
-- Créées paresseusement dans la boucle principale (et non une seule fois au
-- démarrage) : c'est ce qui permet à un nouveau contrôleur de reprendre le
-- drop en cours de vol ou de chute après la déconnexion du précédent.
local function ensurePlane(dropId, px, py, pz, hdg)
    if not isController or planeSpawning then return end
    if planeEntity and DoesEntityExist(planeEntity) then return end
    planeSpawning = true
    local gen = dropGen

    CreateThread(function()
        local hash = loadModel(Config.PlaneModel)
        if not HasModelLoaded(hash) then hash = loadModel('titan') end

        -- Le drop a pu se terminer / changer pendant le chargement du modèle.
        if dropDone or dropGen ~= gen or not drop or drop.id ~= dropId
           or not isController or not HasModelLoaded(hash) then
            planeSpawning = false
            return
        end

        -- Rayon serré : tous les clients calculent la même interpolation à
        -- partir du même payload serveur, l'avion du contrôleur précédent est
        -- donc à quelques mètres de la position attendue.
        local existing = findEntityNear('CVehicle', hash, px, py, pz, 150.0)
        if existing and requestControl(existing) then
            planeEntity = existing
        else
            planeEntity = CreateVehicle(hash, px, py, pz, hdg, true, false)
            SetVehicleEngineOn(planeEntity, true, true, false)
            SetVehicleDoorsLocked(planeEntity, 4)
        end

        SetModelAsNoLongerNeeded(hash)

        if planeEntity and DoesEntityExist(planeEntity) then
            SetEntityAsMissionEntity(planeEntity, true, true)
            -- Blip attaché à l'entité → heading automatique par le moteur
            attachPlaneBlipToEntity(planeEntity)
        else
            planeEntity = nil
        end
        planeSpawning = false
    end)
end

local function ensureCrate(dropId, cx, cy, cz)
    if not isController or crateSpawning then return end
    if crateEntity and DoesEntityExist(crateEntity) then return end
    crateSpawning = true
    local gen = dropGen

    CreateThread(function()
        local hash = loadModel(Config.CrateModel)
        if dropDone or dropGen ~= gen or not drop or drop.id ~= dropId
           or not isController or not HasModelLoaded(hash) then
            crateSpawning = false
            return
        end

        local existing = findEntityNear('CObject', hash, cx, cy, cz, 60.0)
        if existing and requestControl(existing) then
            crateEntity = existing
        else
            crateEntity = CreateObject(hash, cx, cy, cz, true, false, false)
        end

        SetModelAsNoLongerNeeded(hash)

        if crateEntity and DoesEntityExist(crateEntity) then
            SetEntityAsMissionEntity(crateEntity, true, true)
            FreezeEntityPosition(crateEntity, true)
        else
            crateEntity = nil
        end
        crateSpawning = false
    end)
end

-- ── Scan du Z au sol (filet de sécurité si le serveur ne l'a pas envoyé) ──
local function scanGroundZ(d)
    CreateThread(function()
        for _ = 1, 10 do
            RequestCollisionAtCoord(d.dropX, d.dropY, 1000.0)
            Wait(1000)
            for _, testZ in ipairs({ 1000.0, 800.0, 500.0, 300.0, 100.0 }) do
                local found, z = GetGroundZFor_3dCoord(d.dropX, d.dropY, testZ, false)
                if found and z > -50 and z < 1500 then
                    TriggerServerEvent('pvp_drops:reportGroundZ', d.id, d.dropX, d.dropY, z)
                    return
                end
            end
        end
    end)
end

-- ── Thread principal ──────────────────────────────────────────────────────
local function startDropThread()
    CreateThread(function()
        local d     = drop
        local myId  = d.id
        local myGen = dropGen

        local hdg = calcHeading(d.planeStartX, d.planeStartY, d.planeEndX, d.planeEndY)

        -- Temps total de vol : approachTime * 2 (drop au milieu selon dropPct)
        local planeTotalTime = d.approachTime * 2
        local dropTimeMs     = d.dropPct * planeTotalTime

        -- Z par défaut : celui envoyé par le serveur (zone connue), sinon fallback
        local DEFAULT_Z = d.landZ or 30.0
        if not d.landZ and isController then scanGroundZ(d) end

        local crateSpawned = false
        local crateLanded  = false
        local canOpen      = false

        while not dropDone and drop and drop.id == myId and dropGen == myGen do
            Wait(0)

            local elapsed  = GetGameTimer() - dropStartTime
            local planePct = math.min(elapsed / planeTotalTime, 1.0)
            local landZ    = drop.landZ or DEFAULT_Z

            -- ── Avion ────────────────────────────────────────────────────
            local px = lerp(d.planeStartX, d.planeEndX, planePct)
            local py = lerp(d.planeStartY, d.planeEndY, planePct)
            local az = landZ + d.altitude + 50.0

            if planePct < 1.0 then
                updatePlaneBlip(px, py, hdg)
                ensurePlane(myId, px, py, az, hdg)

                if isController and planeEntity and DoesEntityExist(planeEntity) then
                    SetEntityCoordsNoOffset(planeEntity, px, py, az, false, false, false)
                    SetEntityHeading(planeEntity, hdg)
                end
            else
                removePlaneBlip()
                if planeEntity and DoesEntityExist(planeEntity) then
                    SetEntityAsMissionEntity(planeEntity, true, true)
                    DeleteEntity(planeEntity)
                end
                planeEntity = nil
            end

            -- ── Largage ──────────────────────────────────────────────────
            if elapsed >= dropTimeMs and not crateSpawned then
                crateSpawned = true
                removeTrailBlips()
                createCrateBlip(d.dropX, d.dropY, landZ)

                -- `elapsed < dropTimeMs + 5000` : un joueur qui rejoint après le
                -- largage rattrape la timeline d'un coup — inutile de lui
                -- annoncer un largage qui a déjà eu lieu.
                local pc = GetEntityCoords(PlayerPedId())
                if elapsed < dropTimeMs + 5000
                   and #(pc - vector3(d.dropX, d.dropY, landZ)) < 2000.0 then
                    exports['vanta_ui']:notify(
                        'Largage en cours — la caisse descend en parachute.',
                        'warning', 6000, 'Drop de ravitaillement')
                end
            end

            -- ── Chute ────────────────────────────────────────────────────
            if crateSpawned and not crateLanded then
                local fallEl  = elapsed - dropTimeMs
                local fallPct = math.min(fallEl / d.fallDuration, 1.0)
                local landZ2  = drop.landZ or DEFAULT_Z

                local cz = lerp(landZ2 + d.altitude, landZ2 + 0.1, fallPct)
                if cz < landZ2 + 0.1 then cz = landZ2 + 0.1 end

                ensureCrate(myId, d.dropX, d.dropY, cz)
                if isController and crateEntity and DoesEntityExist(crateEntity) then
                    SetEntityCoordsNoOffset(crateEntity, d.dropX, d.dropY, cz, false, false, false)
                end

                -- Timer 3D (visible à 800m)
                local pc   = GetEntityCoords(PlayerPedId())
                local dist = #(pc - vector3(d.dropX, d.dropY, landZ2))
                if dist < 800.0 then
                    draw3DText(d.dropX, d.dropY, cz + 3.0,
                        'CHUTE  ' .. fmtTime(d.fallDuration - fallEl), 255, 200, 50, 0.6)
                end

                if fallPct >= 1.0 then
                    crateLanded = true
                    ensureCrate(myId, d.dropX, d.dropY, landZ2 + 0.1)
                    if isController and crateEntity and DoesEntityExist(crateEntity) then
                        SetEntityCoordsNoOffset(crateEntity, d.dropX, d.dropY, landZ2 + 0.1, false, false, false)
                        FreezeEntityPosition(crateEntity, true)
                    end
                    createCrateBlip(d.dropX, d.dropY, landZ2)

                    -- Fusées éclairantes : son + particules dès le contact au sol
                    if not flaresStarted then
                        flaresStarted = true
                        startLocalFlares(d.dropX, d.dropY, landZ2)
                    end
                end
            end

            -- ── Caisse au sol ────────────────────────────────────────────
            if crateLanded then
                local landZg = drop.landZ or DEFAULT_Z
                ensureCrate(myId, d.dropX, d.dropY, landZg + 0.1)
                ensureFlareProps(d.dropX, d.dropY, landZg)

                local pc   = GetEntityCoords(PlayerPedId())
                local dist = #(pc - vector3(d.dropX, d.dropY, landZg))

                if not canOpen then
                    -- Sécurisation en cours
                    local landEl  = elapsed - dropTimeMs - d.fallDuration
                    local openRem = d.openDelay - landEl

                    if dist < 300.0 then
                        DrawMarker(1,
                            d.dropX, d.dropY, landZg + 0.1,
                            0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            3.5, 3.5, 1.5,
                            200, 50, 50, 100,
                            false, true, 2, false, nil, nil, false)
                        draw3DText(d.dropX, d.dropY, landZg + 4.0,
                            'SÉCURISÉ  ' .. fmtTime(openRem), 255, 80, 50, 0.65)
                    end

                    if landEl >= d.openDelay then canOpen = true end
                else
                    -- Caisse prête
                    if dist < 300.0 then
                        local pulse = math.abs(math.sin(GetGameTimer() / 400.0)) * 0.8
                        DrawMarker(1,
                            d.dropX, d.dropY, landZg + 0.1,
                            0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            3.0 + pulse, 3.0 + pulse, 1.5,
                            50, 220, 100, 120,
                            false, true, 2, false, nil, nil, false)

                        local label = dist <= Config.InteractRadius + 5.0
                            and 'OUVRIR  [E]' or 'DROP DISPONIBLE'
                        draw3DText(d.dropX, d.dropY, landZg + 4.5,
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
        end
    end)
end

-- ── Réception du drop ────────────────────────────────────────────────────
RegisterNetEvent('pvp_drops:start')
AddEventHandler('pvp_drops:start', function(data)
    if type(data) ~= 'table' or not data.id then return end

    -- Resync d'un drop déjà suivi (double requestSync au chargement) : ne pas
    -- rejouer l'animation depuis le début.
    if drop and drop.id == data.id and not dropDone then return end

    cleanup()

    dropGen  = dropGen + 1
    dropDone = false
    drop     = data
    if data.landZ then drop.landZ = data.landZ end

    -- `elapsed` > 0 pour un joueur qui rejoint en cours de drop : sa timeline
    -- est recalée sur celle du serveur au lieu de repartir de zéro.
    dropStartTime = GetGameTimer() - (tonumber(data.elapsed) or 0)
    isController  = (GetPlayerServerId(PlayerId()) == data.controller)

    createTrailBlips(data)
    createPlaneBlip(calcHeading(data.planeStartX, data.planeStartY, data.planeEndX, data.planeEndY))

    startDropThread()
end)

-- ── Changement de contrôleur (déco du précédent) ─────────────────────────
RegisterNetEvent('pvp_drops:controllerChanged')
AddEventHandler('pvp_drops:controllerChanged', function(dropId, newController)
    if not drop or drop.id ~= dropId then return end

    local wasController = isController
    isController = (GetPlayerServerId(PlayerId()) == newController)
    drop.controller = newController

    if isController and not wasController then
        -- Les entités du contrôleur précédent seront reprises (ou recréées) au
        -- prochain tour de boucle via ensurePlane / ensureCrate.
        planeEntity = nil
        crateEntity = nil
        planeSpawning = false
        crateSpawning = false
    end
end)

-- ── Ground Z reçu du serveur (affine la position) ────────────────────────
RegisterNetEvent('pvp_drops:landingCoords')
AddEventHandler('pvp_drops:landingCoords', function(dropId, lx, ly, lz)
    if not drop or drop.id ~= dropId then return end
    drop.landZ = lz  -- on affine le Z uniquement, XY déjà connus
end)

-- ── Fin de drop (vidé, expiré, remplacé, plus de joueurs, admin) ─────────
RegisterNetEvent('pvp_drops:ended')
AddEventHandler('pvp_drops:ended', function(dropId, reason)
    if not drop or drop.id ~= dropId then return end
    cleanup()
end)

-- ── Synchronisation à la connexion ───────────────────────────────────────
-- Sans ça, un joueur connecté après le début d'un drop n'en sait rien — et
-- pouvait être désigné contrôleur sans avoir la moindre donnée de trajectoire.
AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    TriggerServerEvent('pvp_drops:requestSync')
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function()
    TriggerServerEvent('pvp_drops:requestSync')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    cleanup()
end)
