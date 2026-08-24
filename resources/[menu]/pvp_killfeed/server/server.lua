-- =============================================
--   PVP KILLFEED - Serveur
-- =============================================

local ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- ── Labels des armes (table construite via GetHashKey pour éviter les hashes hardcodés faux) ──
local weaponLabels = {
    -- Mêlée
    [GetHashKey('WEAPON_UNARMED')]       = 'Mains nues',
    [GetHashKey('WEAPON_KNIFE')]         = 'Couteau',
    [GetHashKey('WEAPON_BAT')]           = 'Batte',
    [GetHashKey('WEAPON_CROWBAR')]       = 'Pied-de-biche',
    [GetHashKey('WEAPON_SWITCHBLADE')]   = 'Cran d\'arrêt',
    [GetHashKey('WEAPON_HATCHET')]       = 'Hache',
    [GetHashKey('WEAPON_MACHETE')]       = 'Machette',
    -- Pistolets
    [GetHashKey('WEAPON_PISTOL')]        = 'Pistolet',
    [GetHashKey('WEAPON_SNSPISTOL')]     = 'Pistolet SNS',
    [GetHashKey('WEAPON_VINTAGEPISTOL')] = 'Pistolet Vintage',
    [GetHashKey('WEAPON_MACHINEPISTOL')] = 'Pistolet Auto',
    [GetHashKey('WEAPON_COMBATPISTOL')]  = 'Pistolet Combat',
    [GetHashKey('WEAPON_HEAVYPISTOL')]   = 'Pistolet Lourd',
    [GetHashKey('WEAPON_REVOLVER')]      = 'Revolver',
    [GetHashKey('WEAPON_DOUBLEACTION')]  = 'Double Action',
    -- Shotguns
    [GetHashKey('WEAPON_PUMPSHOTGUN')]   = 'Pump Shotgun',
    [GetHashKey('WEAPON_SAWNOFFSHOTGUN')] = 'Shotgun Scié',
    [GetHashKey('WEAPON_DBSHOTGUN')]     = 'Shotgun DB',
    [GetHashKey('WEAPON_ASSAULTSHOTGUN')] = 'Shotgun Assault',
    -- SMG
    [GetHashKey('WEAPON_MICROSMG')]      = 'Micro SMG',
    [GetHashKey('WEAPON_MINISMG')]       = 'Mini SMG',
    [GetHashKey('WEAPON_SMG')]           = 'SMG',
    [GetHashKey('WEAPON_COMBATPDW')]     = 'Combat PDW',
    -- Assault
    [GetHashKey('WEAPON_ASSAULTRIFLE')]  = 'Fusil Assault',
    [GetHashKey('WEAPON_CARBINERIFLE')]  = 'Carabine',
    [GetHashKey('WEAPON_COMPACTRIFLE')]  = 'Carabine Compacte',
    -- MG
    [GetHashKey('WEAPON_COMBATMG')]      = 'Combat MG',
    [GetHashKey('WEAPON_MG')]            = 'MG',
    -- Sniper / Explosifs
    [GetHashKey('WEAPON_SNIPERRIFLE')]   = 'Sniper',
    [GetHashKey('WEAPON_RPG')]           = 'RPG',
    [GetHashKey('WEAPON_GRENADELAUNCHER')] = 'Lance-grenades',
    [GetHashKey('WEAPON_GRENADE')]       = 'Grenade',
    [GetHashKey('WEAPON_MOLOTOV')]       = 'Molotov',
    -- Véhicule
    [GetHashKey('WEAPON_RAMMED_BY_CAR')] = 'Véhicule',
    [GetHashKey('WEAPON_RUN_OVER_BY_CAR')] = 'Véhicule',
    [GetHashKey('WEAPON_FALL')]          = 'Chute',
    [GetHashKey('WEAPON_DROWNING')]      = 'Noyade',
    [GetHashKey('WEAPON_EXPLOSION')]     = 'Explosion',
    [GetHashKey('WEAPON_FIRE')]          = 'Feu',
}

local function getWeaponLabel(hash)
    if not hash then return 'Arme' end
    return weaponLabels[hash] or 'Arme'
end

-- ── Stats de session (reset au restart serveur) ──────────────────────────
local sessionKills = {}     -- [identifier] = { name, kills, crewTag, crewName }
local sessionCrewKills = {} -- [crewId] = { name, tag, kills }

-- SÉCURITÉ : sanitisation anti-XSS (nom est injecté en NUI via template literal).
local function sanitizeName(s)
    if type(s) ~= 'string' then return 'Inconnu' end
    s = s:gsub('[%z\1-\31<>&"\'`\\]', '')
    s = s:match('^%s*(.-)%s*$') or ''
    if #s == 0 then return 'Inconnu' end
    if #s > 40 then s = s:sub(1, 40) end
    return s
end

-- ── Récupérer le nom d'affichage d'un joueur ────────────────────────────
local function getPlayerName(src)
    if not src or src <= 0 then return 'Monde' end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return sanitizeName(GetPlayerName(src) or 'Inconnu') end
    local first = xPlayer.get and xPlayer.get('firstName') or ''
    local last  = xPlayer.get and xPlayer.get('lastName')  or ''
    local name  = (first .. ' ' .. last):gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' then name = GetPlayerName(src) or 'Joueur' end
    return sanitizeName(name)
end

-- ── Récupérer les infos crew d'un joueur ────────────────────────────────
local function getPlayerCrewInfo(identifier, cb)
    MySQL.Async.fetchAll(
        [[SELECT c.id, c.name, c.tag FROM pvp_crew_members m
          JOIN pvp_crews c ON c.id = m.crew_id
          WHERE m.identifier = @id LIMIT 1]],
        { ['@id'] = identifier },
        function(rows)
            if rows and rows[1] then
                cb({ id = rows[1].id, name = rows[1].name, tag = rows[1].tag })
            else
                cb(nil)
            end
        end
    )
end

-- ── Calculer les leaders de session ──────────────────────────────────────
local function getKillLeader()
    local leader = nil
    local maxKills = 0
    for id, data in pairs(sessionKills) do
        if data.kills > maxKills then
            maxKills = data.kills
            leader = { identifier = id, name = data.name, kills = data.kills, crewTag = data.crewTag }
        end
    end
    return leader
end

local function getCrewLeader()
    local leader = nil
    local maxKills = 0
    for id, data in pairs(sessionCrewKills) do
        if data.kills > maxKills then
            maxKills = data.kills
            leader = { id = id, name = data.name, tag = data.tag, kills = data.kills }
        end
    end
    return leader
end

-- ── Diffuser les leaders à tous les clients ─────────────────────────────
local function broadcastLeaders()
    local killLeader = getKillLeader()
    local crewLeader = getCrewLeader()
    TriggerClientEvent('pvp_killfeed:updateLeaders', -1, killLeader, crewLeader)
end

-- ── Anti-spam killfeed : une victime ne peut déclarer qu'un kill / 5s ────
-- SÉCURITÉ : empêche un client de spam playerKilled pour faire exploser
-- artificiellement les stats d'un allié (ou ruiner celles d'un ennemi en
-- se faisant passer pour lui).
local lastKillfeedAt = {}  -- [victimSrc] = os.time()
local KILLFEED_COOLDOWN_S = 3

-- ── Event principal : un joueur meurt ───────────────────────────────────
-- Sécurité : on prend `source` comme victime, le client ne peut pas falsifier
RegisterNetEvent('pvp_killfeed:playerKilled')
AddEventHandler('pvp_killfeed:playerKilled', function(killerSrc, weaponHash, inRedzone)
    local victimSrc = source -- sécurité : on utilise le source réel

    -- SÉCURITÉ : rate-limit par victime (anti-spam).
    local now = os.time()
    if lastKillfeedAt[victimSrc] and (now - lastKillfeedAt[victimSrc]) < KILLFEED_COOLDOWN_S then
        return
    end
    lastKillfeedAt[victimSrc] = now

    -- SÉCURITÉ : weaponHash doit être un number connu (sinon fallback).
    if type(weaponHash) ~= 'number' then weaponHash = nil end
    -- SÉCURITÉ : inRedzone n'est jamais fait confiance — on le re-calcule côté
    -- serveur via pvp_redzones.
    inRedzone = false
    local ok, rz = pcall(function()
        return exports['pvp_redzones']:isPlayerInRedzone(victimSrc)
    end)
    if ok and rz then inRedzone = true end

    local victimName = getPlayerName(victimSrc)
    local killerName = 'Monde'
    local killerIdentifier = nil
    local weaponLabel = getWeaponLabel(weaponHash)

    -- Validation du killerSrc
    if killerSrc and tonumber(killerSrc) and tonumber(killerSrc) > 0 and tonumber(killerSrc) ~= victimSrc then
        killerSrc = tonumber(killerSrc)
        local killerXPlayer = ESX.GetPlayerFromId(killerSrc)
        if killerXPlayer then
            -- SÉCURITÉ : distance sanity-check côté serveur (max 2000m — au-delà
            -- de la portée effective de toute arme du jeu, y compris sniper/AWP).
            -- Empêche un client de revendiquer un kill sur un joueur à
            -- l'autre bout de la map qu'il n'a pas pu toucher.
            local killerPed = GetPlayerPed(killerSrc)
            local victimPed = GetPlayerPed(victimSrc)
            local distOk = true
            if killerPed and killerPed ~= 0 and victimPed and victimPed ~= 0
               and DoesEntityExist(killerPed) and DoesEntityExist(victimPed) then
                local kc = GetEntityCoords(killerPed)
                local vc = GetEntityCoords(victimPed)
                local dx, dy, dz = kc.x - vc.x, kc.y - vc.y, kc.z - vc.z
                if (dx*dx + dy*dy + dz*dz) > 4000000.0 then distOk = false end
            end
            if distOk then
                killerName = getPlayerName(killerSrc)
                killerIdentifier = killerXPlayer.identifier
                if not sessionKills[killerIdentifier] then
                    sessionKills[killerIdentifier] = { name = killerName, kills = 0, crewTag = nil, crewName = nil }
                end
                sessionKills[killerIdentifier].kills = sessionKills[killerIdentifier].kills + 1
                sessionKills[killerIdentifier].name = killerName
            else
                killerSrc = 0
            end
        else
            killerSrc = 0
        end
    else
        killerSrc = 0
    end

    local victimXPlayer = ESX.GetPlayerFromId(victimSrc)
    local victimIdentifier = victimXPlayer and victimXPlayer.identifier or nil

    -- SÉCURITÉ : dispatch interne vers vanta_xp APRÈS validation.
    -- Clients ne peuvent pas trigger cet event (pas de RegisterNetEvent ailleurs).
    if killerSrc and killerSrc > 0 then
        TriggerEvent('vanta_xp:internalPlayerKill', killerSrc)
    end

    -- Pipeline stats unifie: le killfeed valide le PVP, puis delegue aux
    -- systemes persistants sans repasser par un event client falsifiable.
    -- Le suivi de série (kill streak) vit uniquement dans pvp_inventory
    -- (kill_streak_record + badges) — plus de doublon ici, et plus
    -- d'annonces de série dans le chat (retirées, trop bruyantes à plusieurs
    -- joueurs).
    TriggerEvent('pvp_inventory:recordPvpKill', killerIdentifier, victimIdentifier, killerName, victimName)
    if inRedzone then
        TriggerEvent('pvp_redzones:pvpKill', killerSrc, victimSrc)
    end
    -- Broadcast le kill à tous les joueurs
    TriggerClientEvent('pvp_killfeed:kill', -1, {
        killer    = killerName,
        victim    = victimName,
        weapon    = weaponLabel,
        inRedzone = inRedzone or false,
        killerId  = killerSrc,
        victimId  = victimSrc,
    })

    -- Mettre à jour les crew kills
    if killerIdentifier then
        getPlayerCrewInfo(killerIdentifier, function(crew)
            if crew then
                if not sessionCrewKills[crew.id] then
                    sessionCrewKills[crew.id] = { name = crew.name, tag = crew.tag, kills = 0 }
                end
                sessionCrewKills[crew.id].kills = sessionCrewKills[crew.id].kills + 1
                if sessionKills[killerIdentifier] then
                    sessionKills[killerIdentifier].crewTag = crew.tag
                end
            end
            broadcastLeaders()
        end)
    else
        broadcastLeaders()
    end
end)

-- ── Demande de sync (nouveau joueur) ────────────────────────────────────
RegisterNetEvent('pvp_killfeed:requestSync')
AddEventHandler('pvp_killfeed:requestSync', function()
    local src = source
    TriggerClientEvent('pvp_killfeed:updateLeaders', src, getKillLeader(), getCrewLeader())
end)
