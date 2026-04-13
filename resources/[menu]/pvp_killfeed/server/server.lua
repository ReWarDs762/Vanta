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

-- ── Récupérer le nom d'affichage d'un joueur ────────────────────────────
local function getPlayerName(src)
    if not src or src <= 0 then return 'Monde' end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return GetPlayerName(src) or 'Inconnu' end
    local first = xPlayer.get and xPlayer.get('firstName') or ''
    local last  = xPlayer.get and xPlayer.get('lastName')  or ''
    local name  = (first .. ' ' .. last):gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' then name = GetPlayerName(src) or 'Joueur' end
    return name
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

-- ── Event principal : un joueur meurt ───────────────────────────────────
-- Sécurité : on prend `source` comme victime, le client ne peut pas falsifier
RegisterNetEvent('pvp_killfeed:playerKilled')
AddEventHandler('pvp_killfeed:playerKilled', function(killerSrc, weaponHash, inRedzone)
    local victimSrc = source -- sécurité : on utilise le source réel
    print('[pvp_killfeed] EVENT reçu — victime=' .. tostring(victimSrc) .. ' killer=' .. tostring(killerSrc) .. ' arme=' .. tostring(weaponHash))
    local victimName = getPlayerName(victimSrc)
    local killerName = 'Monde'
    local killerIdentifier = nil
    local weaponLabel = getWeaponLabel(weaponHash)

    -- Validation du killerSrc
    if killerSrc and tonumber(killerSrc) and tonumber(killerSrc) > 0 and tonumber(killerSrc) ~= victimSrc then
        killerSrc = tonumber(killerSrc)
        killerName = getPlayerName(killerSrc)
        local killerXPlayer = ESX.GetPlayerFromId(killerSrc)
        if killerXPlayer then
            killerIdentifier = killerXPlayer.identifier
            if not sessionKills[killerIdentifier] then
                sessionKills[killerIdentifier] = { name = killerName, kills = 0, crewTag = nil, crewName = nil }
            end
            sessionKills[killerIdentifier].kills = sessionKills[killerIdentifier].kills + 1
            sessionKills[killerIdentifier].name = killerName
        end
    else
        killerSrc = 0
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
