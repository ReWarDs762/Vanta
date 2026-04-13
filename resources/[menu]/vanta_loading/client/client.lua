-- =============================================
--   VANTA Loading Screen — Client
--   Ferme le loading screen dès que le joueur
--   est actif sur le réseau
-- =============================================

Citizen.CreateThread(function()
    -- Attendre que le joueur soit actif sur le réseau
    while not NetworkIsPlayerActive() do
        Citizen.Wait(100)
    end

    -- Déclencher l'animation fade-out côté NUI
    SendNUIMessage({ type = 'shutdown' })

    -- Laisser l'animation se jouer (400ms délai + 500ms fade = ~1s)
    Citizen.Wait(1000)

    -- Fermer le loading screen
    ShutdownLoadingScreen()
end)
