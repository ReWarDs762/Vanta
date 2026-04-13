-- =============================================
--   PVP SPAWN - Client
--   Gère le spawn initial (login → avant-poste aléatoire)
--   et le respawn après mort (→ avant-poste le plus proche)
-- =============================================

local SpawnPoints = {
    { x = 1747.0, y = 3273.0, z = 41.1, h = 180.0 }, -- Airfield centre
    { x = 1680.5, y = 3285.0, z = 40.8, h = 90.0  }, -- Airfield ouest
    { x = 1812.0, y = 3260.0, z = 41.5, h = 270.0 }, -- Airfield est
    { x = 1745.0, y = 3350.0, z = 41.1, h = 0.0   }, -- Airfield nord
    { x = 1956.0, y = 3740.0, z = 32.2, h = 220.0 }, -- Sandy Shores ville N
    { x = 1848.0, y = 3683.0, z = 33.7, h = 180.0 }, -- Sandy Shores ville O
    { x = 2005.0, y = 3795.0, z = 31.4, h = 90.0  }, -- Sandy Shores ville E
    { x = 1384.0, y = 3608.0, z = 38.8, h = 45.0  }, -- Route 68 ouest
}

-- ── État interne ─────────────────────────────────────────────────────────
local spawnHandled       = false  -- empêche double-tp si esx_skin handler a déjà agi
local loginOutpost       = nil    -- outpost pour spawn à la connexion
local deathRespawnActive = false  -- true pendant le flow de mort (pvp_spawn gère)

-- ── Désactiver l'auto-respawn du spawnmanager sur mort ───────────────────
-- basic-gamemode (chargé via la resource fivem) active setAutoSpawn(true),
-- ce qui fait que le spawnmanager respawn automatiquement aux coords par défaut.
-- On le remplace par un callback qui ne fait rien quand on gère la mort nous-mêmes.
AddEventHandler('onClientMapStart', function()
    exports.spawnmanager:setAutoSpawnCallback(function()
        if deathRespawnActive then
            -- La mort est gérée par esx:onPlayerDeath ci-dessous, ne rien faire
            return
        end
        -- Spawn initial (connexion) : laisser spawnmanager spawner, playerSpawned téléportera
        exports.spawnmanager:spawnPlayer()
    end)
end)

-- ── Réception de l'outpost de login (aléatoire, envoyé à la connexion) ───
RegisterNetEvent('pvp_spawn:setLoginOutpost')
AddEventHandler('pvp_spawn:setLoginOutpost', function(outpostCoords, outpostHeading)
    loginOutpost = { x = outpostCoords.x, y = outpostCoords.y, z = outpostCoords.z, h = outpostHeading }
end)

-- ── Réception de l'outpost de respawn (le plus proche, envoyé à la mort) ─
-- Quand on reçoit la réponse du serveur pendant le flow de mort,
-- on appelle spawnPlayer directement avec les bonnes coords.
RegisterNetEvent('pvp_spawn:setRespawnOutpost')
AddEventHandler('pvp_spawn:setRespawnOutpost', function(outpostCoords, outpostHeading)
    if deathRespawnActive then
        deathRespawnActive = false
        exports.spawnmanager:spawnPlayer({
            x = outpostCoords.x, y = outpostCoords.y, z = outpostCoords.z,
            heading = outpostHeading or 0.0,
        })
    end
end)

-- ── Modèle freemode masculin par défaut ───────────────────────────────────
local function applyFreemodeModel()
    local model = GetHashKey('mp_m_freemode_01')
    RequestModel(model)
    while not HasModelLoaded(model) do
        Citizen.Wait(0)
    end
    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)
end

-- ── Téléportation vers un point aléatoire (fallback Sandy Shores) ────────
local function teleportToSpawn()
    local sp  = SpawnPoints[math.random(1, #SpawnPoints)]
    local ped = PlayerPedId()

    RequestCollisionAtCoord(sp.x, sp.y, sp.z)
    local timer = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(ped) and (GetGameTimer() - timer) < 3000 do
        Citizen.Wait(0)
    end

    SetEntityCoordsNoOffset(ped, sp.x, sp.y, sp.z, false, false, false, true)
    SetEntityHeading(ped, sp.h)
end

-- ── Dégel complet du joueur ────────────────────────────────────────────────
local function unfreezePlayer()
    local pid = PlayerId()
    local ped = PlayerPedId()
    SetPlayerControl(pid, true, 0)
    SetPlayerInvincible(pid, false)
    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
    SetEntityVisible(ped, true, false)
    SetEntityHealth(ped, 200) -- 100 HP max
    ClearPlayerWantedLevel(pid)
    SetNuiFocus(false, false)
end

-- ── CAS 1 : Nouveau joueur ────────────────────────────────────────────────
-- esx_identity appelle esx_skin:openSaveableMenu après l'inscription.
-- Comme le skinchanger n'est pas installé, on intercepte pour
-- appliquer le modèle freemode + téléporter + dégeler.
AddEventHandler('esx_skin:openSaveableMenu', function()
    spawnHandled = true
    Citizen.CreateThread(function()
        applyFreemodeModel()
        Citizen.Wait(300)
        teleportToSpawn()
        Citizen.Wait(200)
        unfreezePlayer()
    end)
end)

-- ── CAS 2 : Joueur existant (reconnexion ou respawn après mort) ──────────
AddEventHandler('playerSpawned', function()
    Citizen.CreateThread(function()
        -- Laisser le temps à esx_skin:openSaveableMenu de poser spawnHandled
        Citizen.Wait(200)
        if spawnHandled then
            spawnHandled = false
            return
        end

        -- Login : téléporter à l'avant-poste aléatoire si disponible
        if loginOutpost ~= nil then
            local sp = loginOutpost
            loginOutpost = nil

            local ped = PlayerPedId()
            RequestCollisionAtCoord(sp.x, sp.y, sp.z)
            local timer = GetGameTimer()
            while not HasCollisionLoadedAroundEntity(ped) and (GetGameTimer() - timer) < 3000 do
                Citizen.Wait(0)
            end
            SetEntityCoordsNoOffset(ped, sp.x, sp.y, sp.z, false, false, false, true)
            SetEntityHeading(ped, sp.h)
        end
        -- Respawn après mort : spawnPlayer a déjà mis les bonnes coords

        unfreezePlayer()
    end)
end)

-- ── Respawn après mort ────────────────────────────────────────────────────
RegisterNetEvent('esx:onPlayerDeath')
AddEventHandler('esx:onPlayerDeath', function()
    Citizen.CreateThread(function()
        -- Signaler au callback auto-spawn de ne rien faire
        deathRespawnActive = true

        -- Délai avant respawn (écran de mort)
        Citizen.Wait(3000)

        -- Demande l'avant-poste le plus proche au serveur
        TriggerServerEvent('pvp_spawn:resetLastPosition')

        -- Attend la réponse du serveur (max 5s de sécurité)
        local timeout = GetGameTimer()
        while deathRespawnActive and (GetGameTimer() - timeout) < 5000 do
            Citizen.Wait(50)
        end

        if deathRespawnActive then
            -- Timeout : le serveur n'a pas répondu, fallback spawn aléatoire
            deathRespawnActive = false
            local fallback = SpawnPoints[math.random(1, #SpawnPoints)]
            exports.spawnmanager:spawnPlayer({
                x = fallback.x, y = fallback.y, z = fallback.z,
                heading = fallback.h or 0.0,
            })
        end
    end)
end)
