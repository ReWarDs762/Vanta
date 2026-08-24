-- =============================================
--   PVP COMBAT - Serveur
--   Suivi de l'état "en combat" : anti combat-log + restrictions associées.
--   État purement en mémoire (transitoire par nature, pas de persistance).
-- =============================================

local combatUntil  = {} -- [src] = GetGameTimer() auquel le combat se termine
local lastKnownPos = {} -- [src] = coords — filet de sécurité pour le drop en combat

local function isInCombat(src)
    local until_ = combatUntil[src]
    return until_ ~= nil and GetGameTimer() < until_
end

-- Utilisable par les autres resources (pvp_inventory pour bloquer le dépôt
-- au coffre protégé pendant un fight).
exports('isInCombat', function(src)
    return isInCombat(tonumber(src))
end)

local function markCombat(src)
    src = tonumber(src)
    if not src or src <= 0 then return end
    local wasInCombat = isInCombat(src)
    combatUntil[src] = GetGameTimer() + Config.CombatDurationMs
    if not wasInCombat then
        TriggerClientEvent('pvp_combat:setState', src, true)
    end
end

-- ── Déclenché par pvp_outposts après validation serveur d'un dégât PVP réel
-- (hors zone safe, hors squad amie) — event INTERNE serveur→serveur, pas de
-- RegisterNetEvent : un client ne peut donc pas forger son propre mode combat.
AddEventHandler('pvp_combat:registerHit', function(attackerSrc, victimSrc)
    markCombat(attackerSrc)
    markCombat(victimSrc)
end)

-- ── Expiration du mode combat + notification client ──────────────────────
CreateThread(function()
    while true do
        Wait(1000)
        local now = GetGameTimer()
        for src, until_ in pairs(combatUntil) do
            if now >= until_ then
                combatUntil[src] = nil
                TriggerClientEvent('pvp_combat:setState', src, false)
            end
        end
    end
end)

-- ── Filet de sécurité : cache la position des joueurs actuellement en
-- combat toutes les 3s, au cas où leur ped ne serait plus résolvable pile
-- au moment de la déconnexion (playerDropped peut arriver en pleine
-- destruction d'entités).
CreateThread(function()
    while true do
        Wait(3000)
        for src in pairs(combatUntil) do
            local ped = GetPlayerPed(src)
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                lastKnownPos[src] = GetEntityCoords(ped)
            end
        end
    end
end)

-- ── Anti combat-log : déconnexion pendant le mode combat → mort + drop ───
-- (délègue la perte d'inventaire/création du sac de loot à pvp_inventory,
-- qui possède déjà toute cette logique pour une mort normale).
AddEventHandler('playerDropped', function()
    local src = source

    if not isInCombat(src) then
        combatUntil[src] = nil
        lastKnownPos[src] = nil
        return
    end

    local coords = nil
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        coords = GetEntityCoords(ped)
    end
    if not coords or (coords.x == 0.0 and coords.y == 0.0 and coords.z == 0.0) then
        coords = lastKnownPos[src]
    end

    if coords then
        TriggerEvent('pvp_inventory:combatLogDeath', src, { x = coords.x, y = coords.y, z = coords.z })
    end

    combatUntil[src] = nil
    lastKnownPos[src] = nil
end)
