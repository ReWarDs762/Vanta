-- =============================================
--   PVP SPAWN - Serveur
-- =============================================

local ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- Envoie un avant-poste aléatoire au client UNIQUEMENT quand pvp_character
-- signale que le personnage est prêt (nouveau joueur après création, ou existant)
AddEventHandler('pvp_character:characterReady', function(src)
    if not src then return end

    local ok, outpost = pcall(function()
        local outposts = exports['pvp_outposts']:getAllOutposts()
        if outposts and #outposts > 0 then
            return outposts[math.random(1, #outposts)]
        end
        return nil
    end)

    if ok and outpost then
        TriggerClientEvent('pvp_spawn:setLoginOutpost', src,
            { x = outpost.coords.x, y = outpost.coords.y, z = outpost.coords.z },
            outpost.heading
        )
    else
        print(('[pvp_spawn] ECHEC getAllOutposts (login) pour joueur %s - pvp_outposts indisponible ? erreur: %s'):format(src, tostring(outpost)))
    end
end)

-- Appelé depuis le client quand le joueur meurt :
-- calcule l'avant-poste le plus proche et envoie les coords au client
RegisterNetEvent('pvp_spawn:resetLastPosition')
AddEventHandler('pvp_spawn:resetLastPosition', function()
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    -- Récupère l'avant-poste le plus proche via l'export de pvp_outposts
    -- (pvp_outposts doit être chargé avant pvp_spawn dans server.cfg)
    local lastPos = xPlayer.getCoords and xPlayer.getCoords() or nil

    -- pvp_outposts expose getNearestOutpost
    local ok, nearest = pcall(function()
        return exports['pvp_outposts']:getNearestOutpost(lastPos or {x=1747,y=3273,z=41})
    end)

    if ok and nearest then
        TriggerClientEvent('pvp_spawn:setRespawnOutpost', src,
            { x = nearest.coords.x, y = nearest.coords.y, z = nearest.coords.z },
            nearest.heading
        )
    else
        print(('[pvp_spawn] ECHEC getNearestOutpost (mort) pour joueur %s - pvp_outposts indisponible ? erreur: %s'):format(src, tostring(nearest)))
    end
end)
