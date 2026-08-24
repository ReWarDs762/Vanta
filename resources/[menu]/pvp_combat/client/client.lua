-- =============================================
--   PVP COMBAT - Client
--   Indicateur "EN COMBAT" à l'écran (natif, pas de NUI — même logique
--   d'affichage que le bandeau redzone de pvp_redzones).
-- =============================================

local inCombat = false

RegisterNetEvent('pvp_combat:setState')
AddEventHandler('pvp_combat:setState', function(state)
    inCombat = state and true or false
end)

Citizen.CreateThread(function()
    while true do
        if inCombat then
            Wait(0)

            DrawRect(0.5, 0.945, 0.16, 0.032, 150, 20, 20, 170)

            SetTextFont(4)
            SetTextScale(0.0, 0.35)
            SetTextColour(255, 255, 255, 255)
            SetTextCentre(true)
            SetTextOutline()
            SetTextEntry('STRING')
            AddTextComponentString('EN COMBAT')
            DrawText(0.5, 0.933)
        else
            Wait(500)
        end
    end
end)
