-- =============================================
--   PVP_VCOINS — Client
--   Cache local : tier, vcoins, expires
--   Exports pour pvp_outposts et pvp_killfeed
-- =============================================

local localTier    = 'none'   -- 'none' | 'gold' | 'diamond'
local localVCoins  = 0
local localExpires = nil       -- string 'YYYY-MM-DD' ou nil

-- ── Sync depuis le serveur ────────────────────────────────────────────────
RegisterNetEvent('pvp_vcoins:syncData')
AddEventHandler('pvp_vcoins:syncData', function(data)
    if not data then return end
    localTier    = data.tier    or 'none'
    localVCoins  = tonumber(data.vcoins) or 0
    localExpires = data.expires or nil
end)

RegisterNetEvent('pvp_vcoins:syncVCoins')
AddEventHandler('pvp_vcoins:syncVCoins', function(newBal)
    localVCoins = tonumber(newBal) or 0
end)

-- Abonnement changé → notifie l'inventaire pour rafraîchir le poids stash
RegisterNetEvent('pvp_vcoins:subChanged')
AddEventHandler('pvp_vcoins:subChanged', function(newTier)
    localTier = newTier or 'none'
    TriggerEvent('pvp_inventory:refreshStashWeight')
end)

-- ── Exports client ────────────────────────────────────────────────────────
--
-- `GetSubscriptionTier`, `GetVCoins`, `HasDiamond` et `HasGoldOrDiamond` ont été
-- supprimés le 03/09/2026. Le commentaire disait « appelé par pvp_outposts avant
-- d'ouvrir le custom véhicule » — c'était faux : aucune resource ne les appelait,
-- vérifié sur tout `resources/`. Les contrôles d'abonnement qui comptent se font
-- côté serveur via `exports['pvp_vcoins']:GetTier`, seul export réellement
-- consommé de l'extérieur (par `pvp_inventory` et `pvp_character`), et c'est
-- volontaire : un contrôle d'abonnement côté client ne prouve rien.
--
-- `localTier` et `localVCoins` restent utilisés localement par la NUI VCoins.
