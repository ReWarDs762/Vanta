-- =============================================
--   PVP CHARACTER — topbuilder.lua  (OUTIL DE DEV, ADMIN UNIQUEMENT)
--
--   Construit la table de tenues de shared/tops_data.lua.
--
--   Le problème qu'il résout : aucune native n'expose la correspondance entre
--   un haut (composant 11) et le torse/bras (3) qu'il exige. On s'appuie donc
--   sur data/besttorso.json — table pré-calculée (voir data/SOURCE.md) qui
--   donne, pour chaque haut, le torse à poser avec. Restent à régler à l'œil :
--   le sous-vêtement (composant 8, absent de cette table) et le tri esthétique.
--
--   Le builder parcourt donc les ~560 hauts candidats et on GARDE ceux qu'on
--   veut (sélection additive) — les tenues déjà figées sont en tête de liste
--   et verrouillées, puisque leur index est persisté en base.
--
--   Ouverture : commande serveur /topbuilder [male|female] (admin+),
--   puis ENTRÉE pour écrire shared/tops_data.lua.
-- =============================================

local BUILD_GENDER   = 'male'
local builderActive  = false
local entries        = {}   -- candidats, gardés ou non
local cursor         = 1
local onlyKept       = false
local builderCam     = nil
local defaultUnder   = 0

-- Contrôles (libellés AZERTY — le jeu raisonne en INPUT_*, pas en touches)
local K_PREV, K_NEXT   = 174, 175  -- flèches gauche / droite
local K_TORSO_UP       = 172       -- flèche haut
local K_TORSO_DOWN     = 173       -- flèche bas
local K_UNDER_DOWN     = 44        -- A
local K_UNDER_UP       = 38        -- E
local K_TEX            = 47        -- G
local K_KEEP           = 22        -- ESPACE
local K_FILTER         = 23        -- F
local K_HARVEST        = 45        -- R
local K_ARMOR          = 311       -- K
local K_SAVE           = 191       -- ENTRÉE
local K_QUIT           = 194       -- RETOUR ARRIÈRE

-- Sonde du composant 9 (gilet pare-balles). nil = « aucun » (VantaTops.ARMOR_NONE),
-- ce qui doit être l'état normal. La touche K parcourt les drawables du 9
-- uniquement pour vérifier quel index correspond réellement à « aucun gilet »
-- si jamais un kevlar restait visible — la valeur trouvée se reporte alors
-- dans VantaTops.ARMOR_NONE (shared/tops.lua). Jamais sauvegardée dans la table.
local armorProbe = nil

local function drawText(x, y, scale, text, r, g, b)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(r or 255, g or 255, b or 255, 255)
    SetTextOutline()
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(x, y)
end

local function drawBox(x, y, w, h, a)
    DrawRect(x + w / 2, y + h / 2, w, h, 8, 8, 8, a or 200)
end

local function loadModelSync(hash)
    RequestModel(hash)
    local t = GetGameTimer()
    while not HasModelLoaded(hash) and GetGameTimer() - t < 5000 do Citizen.Wait(0) end
end

-- Le builder ne compare que des tenues : il force un ped freemode neutre du
-- genre demandé pour que les index lus soient ceux qui seront rejoués en jeu.
local function forceFreemode(gender)
    local want = GetHashKey((gender == 'female') and 'mp_f_freemode_01' or 'mp_m_freemode_01')
    local ped  = PlayerPedId()
    if GetEntityModel(ped) ~= want then
        local coords  = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        loadModelSync(want)
        SetPlayerModel(PlayerId(), want)
        SetModelAsNoLongerNeeded(want)
        ped = PlayerPedId()
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false, true)
        SetEntityHeading(ped, heading)
    end
    SetPedDefaultComponentVariation(ped)
    VantaTops.clearArmor(ped)
    SetPedHeadBlendData(ped, 0, 0, 0, 0, 0, 0, 0.5, 0.0, 0.0, false)
    return ped
end

local function applyEntry(e)
    if not e then return end
    local ped = PlayerPedId()
    SetPedComponentVariation(ped, VantaTops.COMP_TORSO, e.torso, e.torsoTex, 0)
    SetPedComponentVariation(ped, VantaTops.COMP_UNDER, e.under, e.underTex, 0)
    SetPedComponentVariation(ped, VantaTops.COMP_TOP,   e.top,   e.topTex,   0)
    if armorProbe then
        SetPedComponentVariation(ped, VantaTops.COMP_ARMOR, armorProbe, 0, 0)
    else
        VantaTops.clearArmor(ped)
    end
end

local function cycleArmorProbe()
    local maxV = math.max(0, GetNumberOfPedDrawableVariations(PlayerPedId(), VantaTops.COMP_ARMOR) - 1)
    if armorProbe == nil then
        armorProbe = 0
    elseif armorProbe >= maxV then
        armorProbe = nil          -- retour à « aucun »
    else
        armorProbe = armorProbe + 1
    end
    applyEntry(entries[cursor])
end

-- ── Construction de la liste de candidats ────────────────────────────────
local function loadBestTorso(gender)
    local raw = LoadResourceFile(GetCurrentResourceName(), 'data/besttorso.json')
    if not raw then return nil end
    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then return nil end
    return decoded[gender]
end

local function buildEntries(gender)
    entries = {}
    local seen = {}

    -- 1. Tenues déjà figées : en tête, gardées, verrouillées. Leur index est
    --    persisté dans appearance_json, il ne doit jamais bouger.
    for _, e in ipairs(VantaTops.list(gender)) do
        seen[e.top] = true
        entries[#entries + 1] = {
            top   = e.top,   topTex   = e.topTex or 0,
            torso = e.torso, torsoTex = e.torsoTex or 0,
            under = e.under, underTex = e.underTex or 0,
            label = e.label or 'TENUE',
            keep  = true, locked = true, coverage = 100,
        }
    end

    -- 2. Candidats issus de la table besttorso, non encore figés.
    local list = loadBestTorso(gender)
    if not list then return false end
    for _, row in ipairs(list) do
        local top, torso, torsoTex, coverage = row[1], row[2], row[3], row[4]
        if not seen[top] then
            seen[top] = true
            entries[#entries + 1] = {
                top   = top,   topTex   = 0,
                torso = torso, torsoTex = torsoTex,
                under = defaultUnder, underTex = 0,
                label = 'HAUT ' .. top,
                keep  = false, locked = false, coverage = coverage,
            }
        end
    end
    return true
end

-- Récolte aléatoire — filet de sécurité pour les hauts absents de la table
-- besttorso (vêtements addon, DLC plus récents que le jeu de données).
local function harvestRandom(count)
    local ped  = forceFreemode(BUILD_GENDER)
    local seen = {}
    for _, e in ipairs(entries) do seen[e.top] = true end

    local added, tries = 0, 0
    while added < count and tries < count * 40 do
        tries = tries + 1
        SetPedRandomComponentVariation(ped, 0)
        local top = GetPedDrawableVariation(ped, VantaTops.COMP_TOP)
        if not seen[top] then
            seen[top] = true
            entries[#entries + 1] = {
                top      = top,
                topTex   = GetPedTextureVariation(ped, VantaTops.COMP_TOP),
                torso    = GetPedDrawableVariation(ped, VantaTops.COMP_TORSO),
                torsoTex = GetPedTextureVariation(ped, VantaTops.COMP_TORSO),
                under    = GetPedDrawableVariation(ped, VantaTops.COMP_UNDER),
                underTex = GetPedTextureVariation(ped, VantaTops.COMP_UNDER),
                label    = 'HAUT ' .. top,
                keep     = false, locked = false, coverage = -1,
            }
            added = added + 1
        end
        Citizen.Wait(0)
    end
    return added
end

-- ── Navigation ───────────────────────────────────────────────────────────
local function keptCount()
    local n = 0
    for _, e in ipairs(entries) do if e.keep then n = n + 1 end end
    return n
end

local function visible(e)
    return (not onlyKept) or e.keep
end

local function moveCursor(dir)
    if #entries == 0 then return end
    local i = cursor
    for _ = 1, #entries do
        i = i + dir
        if i < 1 then i = #entries elseif i > #entries then i = 1 end
        if visible(entries[i]) then
            cursor = i
            applyEntry(entries[cursor])
            return
        end
    end
end

local function cycleField(field, dir, compId)
    local e = entries[cursor]
    if not e then return end
    local maxV = math.max(0, GetNumberOfPedDrawableVariations(PlayerPedId(), compId) - 1)
    local nv = e[field] + dir
    if nv < 0 then nv = maxV elseif nv > maxV then nv = 0 end
    e[field] = nv
    if field == 'torso' then e.torsoTex = 0 elseif field == 'under' then e.underTex = 0 end
    applyEntry(e)
end

local function cycleTopTexture()
    local e = entries[cursor]
    if not e then return end
    local maxV = math.max(0, GetNumberOfPedTextureVariations(PlayerPedId(), VantaTops.COMP_TOP, e.top) - 1)
    e.topTex = (e.topTex + 1 > maxV) and 0 or (e.topTex + 1)
    applyEntry(e)
end

local function toggleKeep()
    local e = entries[cursor]
    if not e then return end
    -- Une tenue figée ne peut pas être retirée ici : son index est en base,
    -- la retirer décalerait la tenue de tous les joueurs suivants.
    if e.locked then return end
    e.keep = not e.keep
end

-- ── HUD ──────────────────────────────────────────────────────────────────
local function drawHud()
    local e = entries[cursor]
    drawBox(0.02, 0.06, 0.54, 0.37, 210)
    drawText(0.03, 0.075, 0.50, 'CONSTRUCTEUR DE TENUES — ' .. string.upper(BUILD_GENDER), 235, 235, 235)
    drawText(0.03, 0.115, 0.42, string.format('candidat %d / %d       SELECTION : %d%s',
        cursor, #entries, keptCount(), onlyKept and '   [filtre: gardees]' or ''), 160, 160, 160)

    if e then
        local state = e.locked and '[FIGEE]' or (e.keep and '[GARDEE]' or '[ignoree]')
        local cov   = (e.coverage or -1) >= 0 and (e.coverage .. '% teintes') or 'recolte aleatoire'
        drawText(0.03, 0.150, 0.40, string.format('%s  %s', state, e.label),
            e.keep and 120 or 200, e.keep and 230 or 200, e.keep and 120 or 200)
        drawText(0.03, 0.178, 0.36, string.format('haut %d (teinte %d)   torse %d   sous-vetement %d   %s',
            e.top, e.topTex, e.torso, e.under, cov), 255, 255, 255)
    else
        drawText(0.03, 0.150, 0.40, 'AUCUN CANDIDAT — data/besttorso.json introuvable, R pour recolter', 230, 120, 120)
    end

    drawText(0.03, 0.225, 0.34, 'FLECHES G/D  candidat precedent / suivant', 150, 150, 150)
    drawText(0.03, 0.251, 0.34, 'ESPACE       garder / retirer de la selection', 150, 150, 150)
    drawText(0.03, 0.277, 0.34, 'FLECHES H/B  corriger le torse (bras) - composant 3', 150, 150, 150)
    drawText(0.03, 0.303, 0.34, 'A / E        corriger le sous-vetement - composant 8', 150, 150, 150)
    drawText(0.03, 0.329, 0.34, 'G  teinte du haut    F  voir seulement les gardees    Q/D  tourner', 150, 150, 150)
    drawText(0.03, 0.355, 0.34, 'R  recolter des hauts hors table (addon/DLC recent)', 150, 150, 150)
    drawText(0.03, 0.381, 0.34, string.format('K  sonde gilet pare-balles (comp 9) : %s',
        armorProbe and ('drawable ' .. armorProbe) or 'aucun'),
        armorProbe and 230 or 150, armorProbe and 200 or 150, 150)
    drawText(0.03, 0.407, 0.34, 'ENTREE  sauvegarder et quitter    RETOUR  quitter sans sauver', 190, 190, 190)
end

-- ── Cycle de vie ─────────────────────────────────────────────────────────
local function setupCam()
    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)
    builderCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA',
        coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 42.0, false, 0)
    local fwd = GetEntityForwardVector(ped)
    SetCamCoord(builderCam, coords.x + fwd.x * 2.4, coords.y + fwd.y * 2.4, coords.z + 0.15)
    PointCamAtEntity(builderCam, ped, 0.0, 0.0, 0.15, true)
    SetCamActive(builderCam, true)
    RenderScriptCams(true, false, 0, true, true)
end

local function stopBuilder()
    builderActive = false
    RenderScriptCams(false, false, 0, true, true)
    if builderCam then DestroyCam(builderCam, true) builderCam = nil end
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    -- Le builder a écrasé l'apparence du ped (teinte neutre + tenue en cours
    -- d'essai) : on remet celle du personnage avant de rendre la main.
    pcall(function() exports['pvp_character']:ApplyStoredAppearance() end)
end

local function save()
    local out = {}
    for _, e in ipairs(entries) do
        if e.keep then
            out[#out + 1] = {
                top = e.top, topTex = e.topTex, torso = e.torso, torsoTex = e.torsoTex,
                under = e.under, underTex = e.underTex, label = e.label,
            }
        end
    end
    TriggerServerEvent('pvp_character:topbuilder:save', BUILD_GENDER, out)
end

RegisterNetEvent('pvp_character:topbuilder:open')
AddEventHandler('pvp_character:topbuilder:open', function(gender)
    if builderActive then return end
    BUILD_GENDER  = (gender == 'female') and 'female' or 'male'
    builderActive = true
    cursor        = 1
    onlyKept      = false

    local ped = forceFreemode(BUILD_GENDER)
    -- Sous-vêtement de départ : celui de la tenue par défaut du jeu, donc une
    -- valeur cohérente. C'est le point que la table besttorso ne couvre pas —
    -- à corriger à l'œil (A/E) sur les hauts ouverts.
    defaultUnder = GetPedDrawableVariation(ped, VantaTops.COMP_UNDER)

    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    setupCam()

    if not buildEntries(BUILD_GENDER) then harvestRandom(20) end
    applyEntry(entries[cursor])

    Citizen.CreateThread(function()
        while builderActive do
            Citizen.Wait(0)
            drawHud()

            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)

            if IsDisabledControlJustPressed(0, K_PREV)       then moveCursor(-1) end
            if IsDisabledControlJustPressed(0, K_NEXT)       then moveCursor(1) end
            if IsDisabledControlJustPressed(0, K_KEEP)       then toggleKeep() end
            if IsDisabledControlJustPressed(0, K_TORSO_UP)   then cycleField('torso', 1, VantaTops.COMP_TORSO) end
            if IsDisabledControlJustPressed(0, K_TORSO_DOWN) then cycleField('torso', -1, VantaTops.COMP_TORSO) end
            if IsDisabledControlJustPressed(0, K_UNDER_UP)   then cycleField('under', 1, VantaTops.COMP_UNDER) end
            if IsDisabledControlJustPressed(0, K_UNDER_DOWN) then cycleField('under', -1, VantaTops.COMP_UNDER) end
            if IsDisabledControlJustPressed(0, K_TEX)        then cycleTopTexture() end
            if IsDisabledControlJustPressed(0, K_ARMOR)      then cycleArmorProbe() end

            if IsDisabledControlJustPressed(0, K_FILTER) then
                onlyKept = not onlyKept
                if onlyKept and entries[cursor] and not entries[cursor].keep then moveCursor(1) end
            end

            -- harvestRandom() repasse par SetPedDefaultComponentVariation puis
            -- randomise : il faut reposer la tenue courante derrière.
            if IsDisabledControlJustPressed(0, K_HARVEST) then
                harvestRandom(10)
                applyEntry(entries[cursor])
            end

            -- Rotation continue du ped pour juger les bras sous tous les angles
            if IsDisabledControlPressed(0, 34) then SetEntityHeading(PlayerPedId(), GetEntityHeading(PlayerPedId()) + 1.5) end
            if IsDisabledControlPressed(0, 35) then SetEntityHeading(PlayerPedId(), GetEntityHeading(PlayerPedId()) - 1.5) end

            if IsDisabledControlJustPressed(0, K_SAVE) then
                save()
                stopBuilder()
            elseif IsDisabledControlJustPressed(0, K_QUIT) then
                stopBuilder()
            end
        end
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and builderActive then stopBuilder() end
end)
