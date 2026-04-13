-- =============================================
--   PVP REDZONES - Client
--   Blips, HUD, détection de zone
-- =============================================

local activeZones = {}
local zoneBlips = {}
local zoneCircles = {}
local isInRedzone = false
local currentZoneLabel = ''
local timeRemaining = 0       -- ms restant avant rotation
local syncedAt = 0            -- GetGameTimer() au moment du sync

-- ── Demander sync au spawn ───────────────────────────────────────────────
AddEventHandler('playerSpawned', function()
    TriggerServerEvent('pvp_redzones:requestSync')
end)

-- Aussi au démarrage de la resource
CreateThread(function()
    Wait(2000)
    TriggerServerEvent('pvp_redzones:requestSync')
end)

-- ── Recevoir les zones actives depuis le serveur ─────────────────────────
RegisterNetEvent('pvp_redzones:sync')
AddEventHandler('pvp_redzones:sync', function(zones, remaining)
    activeZones = zones or {}
    timeRemaining = remaining or 0
    syncedAt = GetGameTimer()

    -- Recréer les blips
    clearBlips()
    createBlips()
end)

-- ── Blips sur la map ─────────────────────────────────────────────────────
function clearBlips()
    for _, blip in ipairs(zoneBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    zoneBlips = {}

    for _, circle in ipairs(zoneCircles) do
        if DoesBlipExist(circle) then
            RemoveBlip(circle)
        end
    end
    zoneCircles = {}
end

function createBlips()
    for _, zone in ipairs(activeZones) do
        -- Uniquement le cercle rouge, pas de marqueur central
        local radius = AddBlipForRadius(zone.coords.x, zone.coords.y, zone.coords.z, zone.radius)
        SetBlipColour(radius, 1)
        SetBlipAlpha(radius, Config.BlipAlpha)
        SetBlipDisplay(radius, 3)  -- minimap + grande carte
        zoneCircles[#zoneCircles + 1] = radius
    end
end

-- ── Détection : le joueur est-il en redzone ? ────────────────────────────
CreateThread(function()
    while true do
        Wait(500)
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local wasInRedzone = isInRedzone
        isInRedzone = false
        currentZoneLabel = ''

        for _, zone in ipairs(activeZones) do
            local dist = #(coords - zone.coords)
            if dist <= zone.radius then
                isInRedzone = true
                currentZoneLabel = zone.label
                break
            end
        end

        -- Notification entrée/sortie
        if isInRedzone and not wasInRedzone then
            showNotification('~r~REDZONE~s~ : ' .. currentZoneLabel .. '\nLoot x' .. Config.LootMultiplier .. ' | Danger accru !')
        elseif not isInRedzone and wasInRedzone then
            showNotification('~g~Zone sûre~s~ : Vous avez quitté la Redzone')
        end
    end
end)

-- ── HUD : affichage redzone + timer ──────────────────────────────────────
CreateThread(function()
    while true do
        if isInRedzone then
            Wait(0)
            -- Bandeau rouge en haut de l'écran
            DrawRect(0.5, 0.015, 0.22, 0.03, 180, 30, 30, 180)

            SetTextFont(4)
            SetTextScale(0.0, 0.38)
            SetTextColour(255, 255, 255, 255)
            SetTextCentre(true)
            SetTextOutline()
            SetTextEntry('STRING')
            AddTextComponentString('REDZONE — ' .. currentZoneLabel)
            DrawText(0.5, 0.003)

            -- Timer de rotation
            local elapsed = GetGameTimer() - syncedAt
            local remaining = math.max(0, timeRemaining - elapsed)
            local minutes = math.floor(remaining / 60000)
            local seconds = math.floor((remaining % 60000) / 1000)
            local timerText = string.format('Rotation : %02d:%02d', minutes, seconds)

            SetTextFont(4)
            SetTextScale(0.0, 0.30)
            SetTextColour(255, 200, 200, 200)
            SetTextCentre(true)
            SetTextOutline()
            SetTextEntry('STRING')
            AddTextComponentString(timerText)
            DrawText(0.5, 0.030)
        else
            -- Même hors redzone, afficher un petit timer discret
            Wait(500)
        end
    end
end)

-- ── Timer discret hors redzone (coin supérieur droit) ────────────────────
CreateThread(function()
    while true do
        if not isInRedzone and #activeZones > 0 then
            Wait(0)
            local elapsed = GetGameTimer() - syncedAt
            local remaining = math.max(0, timeRemaining - elapsed)
            local minutes = math.floor(remaining / 60000)
            local seconds = math.floor((remaining % 60000) / 1000)

            SetTextFont(4)
            SetTextScale(0.0, 0.28)
            SetTextColour(200, 60, 60, 180)
            SetTextRightJustify(true)
            SetTextWrap(0.0, 0.985)
            SetTextOutline()
            SetTextEntry('STRING')
            AddTextComponentString('Redzone : ' .. string.format('%02d:%02d', minutes, seconds))
            DrawText(0.985, 0.005)
        else
            Wait(1000)
        end
    end
end)

-- ── Notification helper ──────────────────────────────────────────────────
function showNotification(msg)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end

-- ── Export pour pvp_zombies : est-ce que le joueur local est en redzone ──
exports('isInRedzone', function()
    return isInRedzone
end)

exports('getCurrentZoneLabel', function()
    return currentZoneLabel
end)
