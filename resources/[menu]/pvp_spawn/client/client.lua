-- =============================================
--   PVP SPAWN - Client
--   Gère le spawn initial (login → avant-poste aléatoire)
--   et le respawn après mort (→ avant-poste le plus proche)
--
--   Pour les nouveaux joueurs, pvp_character bloque cette resource
--   en retardant l'envoi du setLoginOutpost jusqu'à la fin de la création.
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
local spawnHandled       = false  -- compat legacy (esx_skin hook)
local loginOutpost       = nil    -- outpost pour spawn à la connexion
local hasSpawnedOnce     = false  -- true après le premier playerSpawned
local deathRespawnActive = false  -- true pendant le flow de mort

-- ── Désactiver l'auto-respawn du spawnmanager sur mort ───────────────────
AddEventHandler('onClientMapStart', function()
    exports.spawnmanager:setAutoSpawnCallback(function()
        if deathRespawnActive then
            return
        end
        exports.spawnmanager:spawnPlayer()
    end)
end)

-- ── Helpers ──────────────────────────────────────────────────────────────
local function unfreezePlayer()
    local pid = PlayerId()
    local ped = PlayerPedId()
    SetPlayerControl(pid, true, 0)
    SetPlayerInvincible(pid, false)
    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
    SetEntityVisible(ped, true, false)
    SetEntityHealth(ped, 200)
    ClearPlayerWantedLevel(pid)
    SetNuiFocus(false, false)
end

local function teleportToOutpost(sp)
    local ped = PlayerPedId()
    RequestCollisionAtCoord(sp.x, sp.y, sp.z)
    local timer = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(ped) and (GetGameTimer() - timer) < 3000 do
        Citizen.Wait(0)
    end
    SetEntityCoordsNoOffset(ped, sp.x, sp.y, sp.z, false, false, false, true)
    SetEntityHeading(ped, sp.h or 0.0)
end

local function teleportToRandomFallback()
    local sp = SpawnPoints[math.random(1, #SpawnPoints)]
    teleportToOutpost(sp)
end

-- ── Réception de l'outpost de login ──────────────────────────────────────
-- Peut arriver AVANT ou APRÈS le playerSpawned (pour les nouveaux joueurs
-- qui viennent de terminer leur création, le setLoginOutpost arrive tard).
RegisterNetEvent('pvp_spawn:setLoginOutpost')
AddEventHandler('pvp_spawn:setLoginOutpost', function(outpostCoords, outpostHeading)
    loginOutpost = {
        x = outpostCoords.x, y = outpostCoords.y, z = outpostCoords.z,
        h = outpostHeading or 0.0
    }

    -- Si le joueur a déjà spawn (cas nouveau joueur sortant de la création),
    -- on effectue la téléportation + dégel tout de suite
    if hasSpawnedOnce and NetworkIsPlayerActive(PlayerId()) and DoesEntityExist(PlayerPedId()) then
        Citizen.CreateThread(function()
            local sp = loginOutpost
            loginOutpost = nil
            teleportToOutpost(sp)
            unfreezePlayer()
        end)
    end
    -- Sinon : playerSpawned le prendra en charge
end)

-- ── Réception de l'outpost de respawn (mort) ─────────────────────────────
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

-- ── playerSpawned : login ou respawn ─────────────────────────────────────
AddEventHandler('playerSpawned', function()
    Citizen.CreateThread(function()
        -- Laisser le temps au hook legacy de poser spawnHandled
        Citizen.Wait(200)
        if spawnHandled then
            spawnHandled = false
            hasSpawnedOnce = true
            return
        end

        hasSpawnedOnce = true

        if loginOutpost ~= nil then
            -- Cas 1 : outpost déjà reçu (joueur existant) → téléporte maintenant
            local sp = loginOutpost
            loginOutpost = nil
            teleportToOutpost(sp)
            unfreezePlayer()
            return
        end

        -- Cas 2 : loginOutpost pas encore arrivé
        -- → nouveau joueur en création, pvp_character gère le freeze.
        -- On NE dégèle PAS, on attend setLoginOutpost qui déclenchera le dégel.
        -- Sécurité : si après 30s aucun outpost n'est arrivé, fallback aléatoire
        local deadline = GetGameTimer() + 30000
        while loginOutpost == nil and GetGameTimer() < deadline do
            Citizen.Wait(200)
        end

        if loginOutpost ~= nil then
            local sp = loginOutpost
            loginOutpost = nil
            teleportToOutpost(sp)
            unfreezePlayer()
        else
            -- Fallback de dernier recours
            teleportToRandomFallback()
            unfreezePlayer()
        end
    end)
end)

-- ── Respawn après mort ───────────────────────────────────────────────────
RegisterNetEvent('esx:onPlayerDeath')
AddEventHandler('esx:onPlayerDeath', function()
    Citizen.CreateThread(function()
        deathRespawnActive = true
        Citizen.Wait(3000)
        TriggerServerEvent('pvp_spawn:resetLastPosition')

        local timeout = GetGameTimer()
        while deathRespawnActive and (GetGameTimer() - timeout) < 5000 do
            Citizen.Wait(50)
        end

        if deathRespawnActive then
            deathRespawnActive = false
            local fallback = SpawnPoints[math.random(1, #SpawnPoints)]
            exports.spawnmanager:spawnPlayer({
                x = fallback.x, y = fallback.y, z = fallback.z,
                heading = fallback.h or 0.0,
            })
        end
    end)
end)
