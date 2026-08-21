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
-- Appelé par pvp_outposts avant d'ouvrir le custom véhicule
exports('GetSubscriptionTier', function()
    return localTier
end)

exports('GetVCoins', function()
    return localVCoins
end)

exports('HasDiamond', function()
    return localTier == 'diamond'
end)

exports('HasGoldOrDiamond', function()
    return localTier == 'gold' or localTier == 'diamond'
end)
