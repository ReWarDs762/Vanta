-- ═══════════════════════════════════════════════════════════════════════════
--   VANTA XP — Client
--   NUI profil + notifications level up / prestige
-- ═══════════════════════════════════════════════════════════════════════════

local nuiOpen = false
local currentProfile = nil

-- ══════════════════════════════════════════════════════════════════════════
--   COMMANDE /xp — Toggle NUI profil
-- ══════════════════════════════════════════════════════════════════════════

RegisterCommand('xp', function()
    if nuiOpen then
        closeNUI()
    else
        openNUI()
    end
end, false)

-- Keybind optionnel (non mappé par défaut, le joueur peut le mapper)
-- RegisterKeyMapping('xp', 'Ouvrir le profil XP', 'keyboard', '')

function openNUI()
    if nuiOpen then return end
    -- Demander le profil frais au serveur
    TriggerServerEvent('vanta_xp:requestProfile')
    nuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', profile = currentProfile })
end

function closeNUI()
    if not nuiOpen then return end
    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- ══════════════════════════════════════════════════════════════════════════
--   NUI CALLBACKS
-- ══════════════════════════════════════════════════════════════════════════

-- Fermeture depuis la NUI (Echap ou clic extérieur)
RegisterNUICallback('close', function(data, cb)
    closeNUI()
    cb('ok')
end)

-- Bouton prestige depuis la NUI
RegisterNUICallback('prestige', function(data, cb)
    ExecuteCommand('prestige')
    cb('ok')
end)

-- ══════════════════════════════════════════════════════════════════════════
--   EVENTS SERVEUR → CLIENT
-- ══════════════════════════════════════════════════════════════════════════

-- Mise à jour du profil
RegisterNetEvent('vanta_xp:profileUpdate')
AddEventHandler('vanta_xp:profileUpdate', function(profile)
    currentProfile = profile
    if nuiOpen then
        SendNUIMessage({ action = 'updateProfile', profile = profile })
    end
end)

-- Notification XP ajouté (petit toast discret)
-- Pilote par VantaXP.ShowXPToast (config.lua) : l XP continue d etre gagnee et
-- enregistree normalement, seul l affichage est coupe.
RegisterNetEvent('vanta_xp:xpAdded')
AddEventHandler('vanta_xp:xpAdded', function(amount, source)
    if not VantaXP.ShowXPToast then return end
    SendNUIMessage({
        action = 'xpAdded',
        amount = amount,
        source = source,
    })
end)

-- Notification Level Up
RegisterNetEvent('vanta_xp:levelUp')
AddEventHandler('vanta_xp:levelUp', function(newLevel)
    SendNUIMessage({
        action = 'levelUp',
        level  = newLevel,
    })
end)

-- Notification Prestige Up
RegisterNetEvent('vanta_xp:prestigeUp')
AddEventHandler('vanta_xp:prestigeUp', function(newPrestige)
    SendNUIMessage({
        action   = 'prestigeUp',
        prestige = newPrestige,
    })
end)

-- ══════════════════════════════════════════════════════════════════════════
--   FERMETURE AUTOMATIQUE SI LE JOUEUR MEURT
-- ══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(1000)
        if nuiOpen and IsEntityDead(PlayerPedId()) then
            closeNUI()
        end
    end
end)
