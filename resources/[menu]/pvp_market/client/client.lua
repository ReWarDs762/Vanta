-- =============================================
--   PVP MARKET - Client
--   Échange direct entre joueurs
-- =============================================

local ESX = nil

Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(200)
    end
end)

-- ── Échange direct : touche G pour proposer au joueur le plus proche ──────
RegisterCommand('pvp_trade', function()
    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)

    -- Trouver le joueur le plus proche
    local closestPlayer, closestDist = -1, Config.TradeDistance or 5.0
    local players = GetActivePlayers()
    for _, p in ipairs(players) do
        if p ~= PlayerId() then
            local targetPed = GetPlayerPed(p)
            if DoesEntityExist(targetPed) then
                local targetCoords = GetEntityCoords(targetPed)
                local dist = #(coords - targetCoords)
                if dist < closestDist then
                    closestDist = dist
                    closestPlayer = GetPlayerServerId(p)
                end
            end
        end
    end

    if closestPlayer == -1 then
        exports['vanta_ui']:notify('Aucun joueur proche pour échanger.', 'warning')
        return
    end

    TriggerServerEvent('pvp_market:requestTrade', closestPlayer)
end, false)
RegisterKeyMapping('pvp_trade', 'Proposer un échange', 'keyboard', 'g')

-- ── Recevoir une demande d'échange ──────────────────────────────────────────
RegisterNetEvent('pvp_market:tradeRequest')
AddEventHandler('pvp_market:tradeRequest', function(fromSrc, fromName)
    -- Utiliser le menu ESX pour accepter/refuser
    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'trade_request',
        {
            title    = fromName .. ' veut échanger',
            align    = 'top-left',
            elements = {
                { label = '~g~Accepter',  value = true },
                { label = '~r~Refuser', value = false },
            }
        },
        function(data, menu)
            menu.close()
            TriggerServerEvent('pvp_market:respondTrade', data.current.value)
        end,
        function(data, menu)
            menu.close()
            TriggerServerEvent('pvp_market:respondTrade', false)
        end
    )
end)

-- ── Ouvrir la fenêtre d'échange (NUI) ───────────────────────────────────────
RegisterNetEvent('pvp_market:openTrade')
AddEventHandler('pvp_market:openTrade', function(data)
    SendNUIMessage({
        type = 'openTrade',
        data = data
    })
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
end)

-- ── Mise à jour de l'offre du partenaire ────────────────────────────────────
RegisterNetEvent('pvp_market:updatePartnerOffer')
AddEventHandler('pvp_market:updatePartnerOffer', function(offer)
    SendNUIMessage({ type = 'updatePartnerOffer', data = offer })
end)

-- ── Le partenaire a confirmé ────────────────────────────────────────────────
RegisterNetEvent('pvp_market:partnerConfirmed')
AddEventHandler('pvp_market:partnerConfirmed', function()
    SendNUIMessage({ type = 'partnerConfirmed' })
end)

-- ── Reset de confirmation (offre modifiée) ──────────────────────────────────
RegisterNetEvent('pvp_market:tradeConfirmReset')
AddEventHandler('pvp_market:tradeConfirmReset', function()
    SendNUIMessage({ type = 'tradeConfirmReset' })
end)

-- ── Fermer la fenêtre d'échange ─────────────────────────────────────────────
RegisterNetEvent('pvp_market:tradeClosed')
AddEventHandler('pvp_market:tradeClosed', function()
    SendNUIMessage({ type = 'tradeClosed' })
end)

-- ── NUI Callbacks pour l'échange ────────────────────────────────────────────
RegisterNUICallback('updateTradeOffer', function(data, cb)
    TriggerServerEvent('pvp_market:updateTradeOffer', data)
    cb('ok')
end)

RegisterNUICallback('confirmTrade', function(_, cb)
    TriggerServerEvent('pvp_market:confirmTrade')
    cb('ok')
end)

RegisterNUICallback('cancelTrade', function(_, cb)
    TriggerServerEvent('pvp_market:cancelTrade')
    cb('ok')
end)
