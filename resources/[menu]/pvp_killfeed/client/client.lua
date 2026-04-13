-- =============================================
--   PVP KILLFEED - Client
-- =============================================

local myServerId = nil
local nuiReady   = false
local lastDeathTime = 0

-- ── Init ────────────────────────────────────────────────────────────────
CreateThread(function()
    Wait(2000)
    myServerId = GetPlayerServerId(PlayerId())
    SendNUIMessage({ action = 'init' })
    TriggerServerEvent('pvp_killfeed:requestSync')
    nuiReady = true
end)

-- ── Recevoir un kill ────────────────────────────────────────────────────
RegisterNetEvent('pvp_killfeed:kill')
AddEventHandler('pvp_killfeed:kill', function(data)
    if not nuiReady then return end
    SendNUIMessage({
        action    = 'addKill',
        killer    = data.killer,
        victim    = data.victim,
        weapon    = data.weapon,
        inRedzone = data.inRedzone,
        isMe      = (data.killerId == myServerId or data.victimId == myServerId),
        iKilled   = (data.killerId == myServerId),
        iDied     = (data.victimId == myServerId),
    })
end)

-- ── Recevoir les leaders ────────────────────────────────────────────────
RegisterNetEvent('pvp_killfeed:updateLeaders')
AddEventHandler('pvp_killfeed:updateLeaders', function(killLeader, crewLeader)
    if not nuiReady then return end
    SendNUIMessage({
        action     = 'updateLeaders',
        killLeader = killLeader,
        crewLeader = crewLeader,
    })
end)

-- ── Helper : vérifier si en redzone ─────────────────────────────────────
local function isInRedzone()
    local ok, result = pcall(function() return exports['pvp_redzones']:isInRedzone() end)
    if ok then return result end
    return false
end

-- ── Helper : récupérer l'arme équipée actuellement ──────────────────────
local function getCurrentWeaponHash()
    local ped = PlayerPedId()
    if not ped or ped == 0 then return nil end
    return GetSelectedPedWeapon(ped)
end

-- ── Détection de mort via baseevents (même pipeline que pvp_inventory) ──
RegisterNetEvent('baseevents:onPlayerKilled')
AddEventHandler('baseevents:onPlayerKilled', function(killerClientId, deathData)
    local now = GetGameTimer()
    if (now - lastDeathTime) < 3000 then return end
    lastDeathTime = now

    -- Déterminer le killer
    -- baseevents passe déjà le server ID (résultat de GetPlayerServerId), pas un local ID
    local killerSrc = 0
    if killerClientId ~= nil then
        local killerServerId = tonumber(killerClientId)
        if killerServerId and killerServerId > 0 then
            killerSrc = killerServerId
        end
    end

    -- Récupérer l'arme utilisée depuis deathData (si dispo) sinon arme actuelle
    -- baseevents utilise "weaponhash" (minuscule)
    local weaponHash = nil
    if deathData and type(deathData) == 'table' then
        weaponHash = deathData.weaponhash or deathData.weaponHash or deathData.damageType
    end
    if not weaponHash or weaponHash == 0 then
        weaponHash = getCurrentWeaponHash()
    end

    TriggerServerEvent('pvp_killfeed:playerKilled', killerSrc, weaponHash, isInRedzone())
end)

-- ── Fallback : onPlayerDied (mort non-PVP ou killer inconnu) ────────────
RegisterNetEvent('baseevents:onPlayerDied')
AddEventHandler('baseevents:onPlayerDied', function()
    local now = GetGameTimer()
    if (now - lastDeathTime) < 3000 then return end
    lastDeathTime = now

    local weaponHash = getCurrentWeaponHash()
    TriggerServerEvent('pvp_killfeed:playerKilled', 0, weaponHash, isInRedzone())
end)

-- ── Debug : /kftest pour tester le NUI directement ──────────────────────
RegisterCommand('kftest', function()
    SendNUIMessage({
        action    = 'addKill',
        killer    = 'TestKiller',
        victim    = 'TestVictime',
        weapon    = 'Pistolet',
        inRedzone = false,
        isMe      = false,
        iKilled   = false,
        iDied     = false,
    })
    print('[pvp_killfeed] Test NUI envoyé')
end, false)
