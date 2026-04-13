-- =============================================
--   PVP CREW & SQUAD — Client
--   Le crew est géré dans pvp_inventory NUI
--   Ici on gère uniquement le SQUAD (touche J)
-- =============================================

local ESX = nil
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(200)
    end
end)

local crewTag     = nil
local squadUIOpen = false
local squadData   = nil
local squadBlips  = {}
local squadInvitePending = nil

-- ══════════════════════════════════════════════════════════════════════════
--   SQUAD NUI — Ouvrir / Fermer (touche J = 44)
-- ══════════════════════════════════════════════════════════════════════════

local function openSquadUI()
    if squadUIOpen then return end
    squadUIOpen = true
    SetNuiFocus(true, true)

    ESX.TriggerServerCallback('pvp_crew:getOnlinePlayers', function(players)
        SendNUIMessage({
            action      = 'openSquad',
            squad       = squadData,
            squadInvite = squadInvitePending,
            players     = players or {},
            maxSquad    = Config.MaxSquadMembers,
        })
    end)
end

local function closeSquadUI()
    if not squadUIOpen then return end
    squadUIOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeSquad' })
end

-- Touche J (44) pour ouvrir/fermer
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if IsControlJustReleased(0, 44) and not squadUIOpen then
            openSquadUI()
        end
        if squadUIOpen then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 106, true)
        end
    end
end)

-- ══════════════════════════════════════════════════════════════════════════
--   NUI Callbacks — Squad
-- ══════════════════════════════════════════════════════════════════════════

RegisterNUICallback('closeSquad', function(data, cb)
    closeSquadUI()
    cb({ ok = true })
end)

RegisterNUICallback('squadInvite', function(data, cb)
    ESX.TriggerServerCallback('pvp_crew:squadInvite', function(success, message)
        cb({ ok = success, message = message })
    end, data.targetId)
end)

RegisterNUICallback('squadAccept', function(data, cb)
    squadInvitePending = nil
    ESX.TriggerServerCallback('pvp_crew:squadAccept', function(success, message)
        cb({ ok = success, message = message })
    end)
end)

RegisterNUICallback('squadDecline', function(data, cb)
    squadInvitePending = nil
    ESX.TriggerServerCallback('pvp_crew:squadDecline', function(success, message)
        cb({ ok = success, message = message })
    end)
end)

RegisterNUICallback('squadLeave', function(data, cb)
    ESX.TriggerServerCallback('pvp_crew:squadLeave', function(success, message)
        cb({ ok = success, message = message })
    end)
end)

RegisterNUICallback('squadKick', function(data, cb)
    ESX.TriggerServerCallback('pvp_crew:squadKick', function(success, message)
        cb({ ok = success, message = message })
    end, data.targetId)
end)

-- ══════════════════════════════════════════════════════════════════════════
--   Events du serveur
-- ══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('pvp_crew:updateTag')
AddEventHandler('pvp_crew:updateTag', function(tag)
    crewTag = tag
end)

RegisterNetEvent('pvp_crew:kicked')
AddEventHandler('pvp_crew:kicked', function()
    crewTag = nil
    ESX.ShowNotification('~r~Vous avez été exclu de votre crew.')
end)

RegisterNetEvent('pvp_crew:disbanded')
AddEventHandler('pvp_crew:disbanded', function()
    crewTag = nil
    ESX.ShowNotification('~r~Votre crew a été dissous par le chef.')
end)

RegisterNetEvent('pvp_crew:notifyInvite')
AddEventHandler('pvp_crew:notifyInvite', function()
    ESX.ShowNotification('~g~Invitation crew reçue ! Ouvrez l\'inventaire > onglet CREW.')
end)

RegisterNetEvent('pvp_crew:notify')
AddEventHandler('pvp_crew:notify', function(msg)
    ESX.ShowNotification(msg)
end)

-- ── Squad events ─────────────────────────────────────────────────────────

RegisterNetEvent('pvp_crew:squadUpdate')
AddEventHandler('pvp_crew:squadUpdate', function(data)
    squadData = data
    updateSquadBlips()
    if squadUIOpen then
        SendNUIMessage({ action = 'updateSquad', squad = squadData })
    end
end)

RegisterNetEvent('pvp_crew:squadInviteReceived')
AddEventHandler('pvp_crew:squadInviteReceived', function(invite)
    squadInvitePending = invite
    ESX.ShowNotification('~g~' .. invite.fromName .. ' vous invite dans son squad ! Appuyez sur J.')
    if squadUIOpen then
        SendNUIMessage({ action = 'squadInviteReceived', squadInvite = invite })
    end
end)

-- ══════════════════════════════════════════════════════════════════════════
--   Squad Blips
-- ══════════════════════════════════════════════════════════════════════════

function updateSquadBlips()
    for sid, blip in pairs(squadBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    squadBlips = {}

    if not squadData or not squadData.members then return end

    local myId = GetPlayerServerId(PlayerId())
    for _, member in ipairs(squadData.members) do
        if member.id ~= myId then
            local playerIdx = GetPlayerFromServerId(member.id)
            if playerIdx ~= -1 then
                local ped = GetPlayerPed(playerIdx)
                if DoesEntityExist(ped) then
                    local blip = AddBlipForEntity(ped)
                    SetBlipSprite(blip, Config.SquadBlipSprite)
                    SetBlipColour(blip, Config.SquadBlipColor)
                    SetBlipScale(blip, Config.SquadBlipScale)
                    SetBlipDisplay(blip, 2)
                    BeginTextCommandSetBlipName('STRING')
                    AddTextComponentString(member.name)
                    EndTextCommandSetBlipName(blip)
                    squadBlips[member.id] = blip
                end
            end
        end
    end
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000)
        if squadData and squadData.members and #squadData.members > 1 then
            updateSquadBlips()
        end
    end
end)

-- ══════════════════════════════════════════════════════════════════════════
--   Friendly Fire Prevention
-- ══════════════════════════════════════════════════════════════════════════

AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' then
        local victim   = args[1]
        local attacker = args[2]
        if attacker == PlayerPedId() and IsEntityAPed(victim) and IsPedAPlayer(victim) then
            if squadData and squadData.members then
                local victimPlayer = NetworkGetPlayerIndexFromPed(victim)
                local victimServerId = GetPlayerServerId(victimPlayer)
                for _, member in ipairs(squadData.members) do
                    if member.id == victimServerId then
                        ClearEntityLastDamageEntity(victim)
                        break
                    end
                end
            end
        end
    end
end)

print('[pvp_crew] Client démarré — Squad: touche J')
