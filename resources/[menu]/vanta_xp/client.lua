-- ═══════════════════════════════════════════════════════════════════════════
--   VANTA XP — Client
--   NUI profil + notifications level up / prestige
-- ═══════════════════════════════════════════════════════════════════════════

local nuiOpen = false
local currentProfile = nil

-- ══════════════════════════════════════════════════════════════════════════
--   PAS DE COMMANDE ICI — /xp appartient à pvp_inventory
-- ══════════════════════════════════════════════════════════════════════════
--
-- `RegisterCommand('xp')` était déclaré ici ET dans
-- `pvp_inventory/client/client.lua`. FiveM ne garde que la dernière enregistrée
-- sous un nom donné : `vanta_xp` étant `ensure`d après `pvp_inventory` dans
-- `server.cfg`, c'est ce panneau qui gagnait et le raccourci vers l'onglet
-- Profil de l'inventaire était du code mort. Même collision que `/givexp`,
-- tranchée le 30/08.
--
-- Décision (03/09/2026) : `/xp` ouvre l'onglet Profil de `pvp_inventory`, qui
-- porte déjà la barre d'XP, les stats, les badges et le classement. Le panneau
-- NUI de cette resource n'a donc plus de point d'entrée joueur.
--
-- ⚠️ Ne PAS supprimer le `ui_page` ni les fonctions ci-dessous pour autant : la
-- même page NUI porte les toasts LEVEL UP et PRESTIGE (voir `vanta_xp:levelUp`
-- et `vanta_xp:prestigeUp` plus bas), qui eux restent bien actifs.
--
-- Conséquence à connaître : le bouton PRESTIGE vivait dans ce panneau. Il n'a
-- pas d'équivalent dans l'onglet Profil de `pvp_inventory` — le joueur passe
-- donc par la commande `/prestige`, qui reste pleinement fonctionnelle
-- (`vanta_xp/server.lua`, exige le niveau 100). Ajouter un bouton dans
-- l'inventaire est un item de roadmap, pas une régression de ce correctif.

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
