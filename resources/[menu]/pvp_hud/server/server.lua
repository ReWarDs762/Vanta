-- =============================================
--   PVP HUD - Server Side
--   Wanted level bloqué à 0 côté serveur
-- =============================================

-- Bloquer le wanted level max dès le démarrage
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        SetMaxWantedLevel(0)
    end
end)

-- Réappliquer à chaque connexion joueur
AddEventHandler('playerConnecting', function()
    SetMaxWantedLevel(0)
end)

-- Réappliquer périodiquement (sécurité)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(30000)
        SetMaxWantedLevel(0)
    end
end)
