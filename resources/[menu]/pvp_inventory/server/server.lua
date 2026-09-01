-- =============================================
--   PVP INVENTORY - Serveur
-- =============================================

local ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- ══ Saison en cours ═══════════════════════════════════════════════════════
local CURRENT_SEASON = 1

-- ══ Kill streaks en mémoire (reset à la mort) ═════════════════════════════
local playerStreaks = {} -- [identifier] = streak actuel

-- ══ Lock anti-spam changement de ped ═══════════════════════════════════════
local pedChangeLocks = {} -- [identifier] = true pendant une sauvegarde de ped

-- ══ Notification joueur ═══════════════════════════════════════════════════
-- Affiche le message via la pile partagee de vanta_ui ET libere le verrou de
-- transfert du NUI (transferLocked).
--
-- ⚠️ Les deux roles sont indissociables : sur tous les chemins d erreur d un
-- transfert (poids depasse, stock insuffisant, mode combat...), le serveur
-- repond UNIQUEMENT par une notification, sans refresh. C est donc elle qui
-- doit relacher le verrou, sinon le joueur ne peut plus rien deplacer dans
-- son inventaire jusqu a le fermer et le rouvrir.
-- Toute notification emise depuis pvp_inventory doit passer par cette fonction.
local function notify(src, msg, kind)
    exports['vanta_ui']:notify(src, msg, kind)
    TriggerClientEvent('pvp_inventory:unlockTransfer', src)
end

-- ══ Utilitaire : trouver le source d'un joueur par identifier ═════════════
local function getSourceByIdentifier(identifier)
    for _, src in ipairs(GetPlayers()) do
        local xp = ESX.GetPlayerFromId(tonumber(src))
        if xp and xp.identifier == identifier then
            return tonumber(src)
        end
    end
    return nil
end

-- ══ Déverrouillage de badge (idempotent) ══════════════════════════════════
local function unlockBadge(identifier, badgeId, cb)
    if not identifier or not badgeId or badgeId == '' then return end
    -- Valider le format du badge (prestige_N sont dynamiques)
    if not badgeId:match('^[a-z0-9_]+$') then return end
    MySQL.Async.fetchAll(
        'SELECT badges_unlocked FROM pvp_player_stats WHERE identifier = @id',
        { ['@id'] = identifier },
        function(rows)
            local current = rows and rows[1] and rows[1].badges_unlocked or '[]'
            local ok, badges = pcall(json.decode, current)
            if not ok or type(badges) ~= 'table' then badges = {} end
            for _, b in ipairs(badges) do
                if b == badgeId then
                    if cb then cb(false) end
                    return
                end
            end
            badges[#badges + 1] = badgeId
            local newJson = json.encode(badges)
            MySQL.Async.execute(
                'UPDATE pvp_player_stats SET badges_unlocked = @b WHERE identifier = @id',
                { ['@id'] = identifier, ['@b'] = newJson },
                function()
                    -- Notifier le joueur si en ligne
                    local src = getSourceByIdentifier(identifier)
                    if src then
                        TriggerClientEvent('pvp_inventory:toastBadge', src, badgeId)
                    end
                    if cb then cb(true) end
                end
            )
        end
    )
end

-- Export : débloque un badge pour un joueur (appelé par pvp_vcoins, vanta_xp, etc.)
exports('unlockBadge', function(identifier, badgeId)
    unlockBadge(identifier, badgeId)
end)

-- ══ Vérification globale des badges selon les stats ═══════════════════════
local function checkAllBadges(identifier, stats)
    local kills   = stats.kills   or 0
    local zombies = stats.zombies or 0
    local streak  = stats.streak  or 0
    if kills   >= 1    then unlockBadge(identifier, 'first_blood') end
    if kills   >= 10   then unlockBadge(identifier, 'killer_10') end
    if kills   >= 50   then unlockBadge(identifier, 'killer_50') end
    if kills   >= 100  then unlockBadge(identifier, 'predator_100') end
    if zombies >= 100  then unlockBadge(identifier, 'zombie_hunter') end
    if zombies >= 500  then unlockBadge(identifier, 'exterminator') end
    if zombies >= 1000 then unlockBadge(identifier, 'annihilator') end
    if streak  >= 5    then unlockBadge(identifier, 'streak_5') end
    if streak  >= 10   then unlockBadge(identifier, 'unstoppable') end
end

-- ══ Système de poids du sac ═══════════════════════════════════════════════
local MAX_BAG_WEIGHT = Config.MaxWeight or 50.0

-- ── Bonus de capacité par joueur (utilisé par vanta_xp prestige, pvp_vcoins,
--    et pvp_crew) ────────────────────────────────────────────────────────
local playerBagBonus = {}  -- [identifier] = bonus kg

-- SÉCURITÉ/COHÉRENCE : le bonus de conteneur a plusieurs sources indépendantes
-- (prestige vanta_xp, abonnement pvp_vcoins, boutique de crew pvp_crew) qui
-- peuvent toutes être actives en même temps. Avant, `setContainerBonus`
-- écrasait une valeur unique par identifiant : la dernière source à appeler
-- l'export gagnait et effaçait silencieusement le bonus des autres (ex:
-- reconnexion → vanta_xp applique le bonus prestige, puis pvp_vcoins écrase
-- avec le bonus d'abonnement, prestige perdu). Stocké maintenant par source,
-- additionné à la lecture.
local containerBonusSources = {}  -- [identifier] = { [source] = bonus kg }

-- Export : définir le bonus sac d'un joueur (appelé par vanta_xp)
exports('setBagBonus', function(identifier, bonus)
    if not identifier then return end
    playerBagBonus[identifier] = tonumber(bonus) or 0
end)

-- Export : définir le bonus conteneur d'un joueur pour une source donnée
-- (appelé par vanta_xp avec source='prestige', pvp_vcoins avec
-- source='subscription', pvp_crew avec source='crew'). `source` omis => 'default'.
exports('setContainerBonus', function(identifier, bonus, source)
    if not identifier then return end
    source = source or 'default'
    containerBonusSources[identifier] = containerBonusSources[identifier] or {}
    containerBonusSources[identifier][source] = tonumber(bonus) or 0

    -- Pousse immédiatement la nouvelle capacité au client si en ligne
    -- (sinon le bonus n'apparaît qu'au prochain refresh déclenché ailleurs)
    local src = getSourceByIdentifier(identifier)
    if src then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then refreshStash(src, xPlayer) end
    end
end)

-- Helper : somme de tous les bonus conteneur (toutes sources) pour un joueur
local function getContainerBonusTotal(identifier)
    local sources = containerBonusSources[identifier]
    if not sources then return 0 end
    local total = 0
    for _, v in pairs(sources) do total = total + v end
    return total
end

-- Export : récupérer la capacité effective du sac d'un joueur
exports('getPlayerBagCapacity', function(identifier)
    return MAX_BAG_WEIGHT + (playerBagBonus[identifier] or 0)
end)

-- Export : récupérer la capacité effective du conteneur d'un joueur
exports('getPlayerContainerCapacity', function(identifier)
    return 20.0 + getContainerBonusTotal(identifier)
end)

-- Helper : capacité sac effective pour un joueur
local function getEffectiveBagWeight(identifier)
    return MAX_BAG_WEIGHT + (playerBagBonus[identifier] or 0)
end

-- Helper : capacité conteneur effective pour un joueur
local function getEffectiveStashWeight(identifier)
    return 20.0 + getContainerBonusTotal(identifier)
end

local ITEM_WEIGHTS = {
    -- Consommables (0.2 kg)
    bandage=0.2, medkit=0.4,
    -- Kevlar (1 kg)
    kevlar=1.0,
    -- Munitions
    ammo_sniper=0.1,
    -- Mêlée
    weapon_knife=0.3, weapon_bat=1.0, weapon_crowbar=1.2,
    weapon_switchblade=0.2, weapon_hatchet=0.8, weapon_machete=0.7,
    -- Shots (0.2 kg)
    shot_repel=0.2, shot_attract=0.2, shot_speed=0.2, shot_health=0.2,
    -- ── Pistols (1 kg) ──
    weapon_molotov=0.4,
    weapon_appistol=1.0,
    weapon_pistol=1.0,        weapon_pistol_mk2=1.0,
    weapon_snspistol=1.0,     weapon_snspistol_mk2=1.0,
    weapon_vintagepistol=1.0, weapon_combatpistol=1.0,   weapon_heavypistol=1.0,
    weapon_machinepistol=1.0,
    -- ── SMG (2 kg) ──
    weapon_microsmg=2.0,      weapon_minismg=2.0,
    weapon_smg=2.0,           weapon_smg_mk2=2.0,
    -- ── Carabines / Fusils d'assaut (4 kg) ──
    weapon_assaultrifle=4.0,  weapon_carbinerifle=4.0,   weapon_specialcarbine=4.0,
    weapon_assaultrifle_mk2=4.0,  weapon_carbinerifle_mk2=4.0,  weapon_specialcarbine_mk2=4.0,
    weapon_stungun=1.0,
    -- ── M60 / MG (5 kg) ──
    weapon_combatmg=5.0,      weapon_mg=5.0,
    weapon_combatmg_mk2=5.0,
    -- ── Épic (5 kg) ──
    weapon_precisionrifle=4.0, weapon_compactlauncher=5.0, weapon_emplauncher=5.0,
    weapon_musket=4.0,
    -- ── Légendaire (10 kg) ──
    weapon_sniperrifle=10.0,   weapon_marksmanrifle_mk2=10.0,
    weapon_heavysniper=10.0,   weapon_heavysniper_mk2=10.0,
    weapon_rpg=10.0,           weapon_hominglauncher=10.0,
}

local function getItemWeight(name)
    if ITEM_WEIGHTS[name] then return ITEM_WEIGHTS[name] end
    if name and name:find('^vehicle_') then return 1.0 end
    return 0.0
end

local function getBagWeight(xPlayer)
    local total = 0.0
    for _, item in ipairs(xPlayer.getInventory()) do
        if item.count > 0 then
            total = total + getItemWeight(item.name) * item.count
        end
    end
    return total
end

-- Export utilisable depuis pvp_zombies (prend src au lieu de xPlayer)
exports('canAddToBag', function(src, itemName, qty)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    local addWeight = getItemWeight(itemName) * (qty or 1)
    local effectiveMax = getEffectiveBagWeight(xPlayer.identifier)
    return (getBagWeight(xPlayer) + addWeight) <= effectiveMax
end)

-- ── Tables SQL ──────────────────────────────────────────────────────────
AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `pvp_player_stats` (
            `identifier`     VARCHAR(60) NOT NULL,
            `display_name`   VARCHAR(64) DEFAULT '',
            `kills`          INT DEFAULT 0,
            `deaths`         INT DEFAULT 0,
            `zombies_killed` INT DEFAULT 0,
            PRIMARY KEY (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    -- Migrations portables (évite ADD COLUMN IF NOT EXISTS — MariaDB < 10.0.2 / MySQL < 8.0.29)
    local function addCol(tbl, col, def)
        MySQL.Async.fetchScalar(
            [[SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = @t AND COLUMN_NAME = @c]],
            { ['@t'] = tbl, ['@c'] = col },
            function(count)
                if (tonumber(count) or 0) == 0 then
                    MySQL.Async.execute('ALTER TABLE `' .. tbl .. '` ADD COLUMN `' .. col .. '` ' .. def)
                end
            end
        )
    end
    addCol('pvp_player_stats', 'display_name',      "VARCHAR(64) DEFAULT ''")
    addCol('pvp_player_stats', 'zombies_killed',     'INT DEFAULT 0')
    addCol('pvp_player_stats', 'kill_streak_record', 'INT DEFAULT 0')
    addCol('pvp_player_stats', 'xp',                 'INT DEFAULT 0')
    addCol('pvp_player_stats', 'prestige',           'TINYINT DEFAULT 0')
    addCol('pvp_player_stats', 'active_badge',       "VARCHAR(32) DEFAULT ''")
    addCol('pvp_player_stats', 'badges_unlocked',    "TEXT DEFAULT '[]'")
    addCol('pvp_player_stats', 'hotbar',             "TEXT DEFAULT '[]'")
    addCol('pvp_player_stats', 'hud_type',           "VARCHAR(10) DEFAULT 'gta'")
    addCol('pvp_player_stats', 'ped_model',          "VARCHAR(64) DEFAULT ''")
    addCol('pvp_player_stats', 'kit_start_used',     'TINYINT DEFAULT 0')
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `pvp_player_stash` (
            `id`         INT AUTO_INCREMENT PRIMARY KEY,
            `identifier` VARCHAR(60) NOT NULL,
            `item`       VARCHAR(50) NOT NULL,
            `label`      VARCHAR(100) NOT NULL,
            `count`      INT DEFAULT 1,
            UNIQUE KEY `unique_item` (`identifier`, `item`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `pvp_outpost_stash` (
            `id`         INT AUTO_INCREMENT PRIMARY KEY,
            `identifier` VARCHAR(60) NOT NULL,
            `outpost_id` VARCHAR(50) NOT NULL,
            `item`       VARCHAR(50) NOT NULL,
            `label`      VARCHAR(100) NOT NULL,
            `count`      INT DEFAULT 1,
            UNIQUE KEY `unique_outpost_item` (`identifier`, `outpost_id`, `item`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    -- Auto-insert armes + véhicules + consommables dans la table items ESX
    registerConsumableItems()
    registerWeaponItems()
    registerVehicleItems()
end)

-- ── Enregistrer les consommables comme items ESX ─────────────────────────
function registerConsumableItems()
    MySQL.Async.execute([[
        INSERT IGNORE INTO `items` (`name`, `label`, `limit`, `rare`, `can_remove`) VALUES
        ('bandage',      'Bandage',                  -1, 0, 1),
        ('medkit',       'Kit de Soins',             -1, 0, 1),
        ('kevlar',       'Kevlar',                   -1, 0, 1),
        ('shot_repel',   'Shot Répulsif',            -1, 0, 1),
        ('shot_attract', 'Shot Attracteur',          -1, 0, 1),
        ('shot_speed',   'Shot de Vitesse',          -1, 0, 1),
        ('shot_health',  'Shot de Santé',            -1, 0, 1)
    ]])
    print('[pvp_inventory] 7 consommables enregistrés dans items.')
end

-- ── Enregistrer les armes comme items ESX ───────────────────────────────
function registerWeaponItems()
    local weapons = {
        -- ── MÊLÉE ──
        { name = 'weapon_knife',             label = 'Couteau' },
        { name = 'weapon_machete',           label = 'Machette' },
        { name = 'weapon_bat',               label = 'Batte de Baseball' },
        { name = 'weapon_crowbar',           label = 'Pied de Biche' },
        { name = 'weapon_switchblade',       label = 'Cran d\'Arrêt' },
        { name = 'weapon_hatchet',           label = 'Hachette' },
        -- ── TRÈS COMMUN ──
        { name = 'weapon_molotov',           label = 'Molotov' },
        { name = 'weapon_appistol',          label = 'AP Pistol' },
        { name = 'weapon_pistol',            label = 'Pistolet' },
        { name = 'weapon_pistol_mk2',        label = 'Pistolet MK2' },
        { name = 'weapon_snspistol',         label = 'SNS Pistol' },
        { name = 'weapon_snspistol_mk2',     label = 'SNS Pistol MK2' },
        { name = 'weapon_vintagepistol',     label = 'Pistolet Vintage' },
        { name = 'weapon_combatpistol',      label = 'Pistolet Combat' },
        { name = 'weapon_heavypistol',       label = 'Pistolet Lourd' },
        { name = 'weapon_microsmg',          label = 'Micro SMG' },
        { name = 'weapon_minismg',           label = 'Mini SMG' },
        { name = 'weapon_smg',               label = 'SMG' },
        { name = 'weapon_smg_mk2',           label = 'SMG MK2' },
        { name = 'weapon_machinepistol',     label = 'Pistolet Mitrailleur' },
        -- ── COMMUN ──
        { name = 'weapon_assaultrifle',      label = 'AK-47' },
        { name = 'weapon_carbinerifle',      label = 'Carabine' },
        { name = 'weapon_specialcarbine',    label = 'Carabine Spécial' },
        -- ── RARE ──
        { name = 'weapon_assaultrifle_mk2',  label = 'AK-47 MK2' },
        { name = 'weapon_carbinerifle_mk2',  label = 'Carabine MK2' },
        { name = 'weapon_specialcarbine_mk2',label = 'Carabine Spécial MK2' },
        { name = 'weapon_stungun',           label = 'Pistolet Paralysant' },
        { name = 'weapon_combatmg',          label = 'M60' },
        { name = 'weapon_mg',                label = 'Mitrailleuse' },
        -- ── ÉPIC ──
        { name = 'weapon_precisionrifle',    label = 'Fusil de Précision' },
        { name = 'weapon_compactlauncher',   label = 'Lance-Grenades Compact' },
        { name = 'weapon_emplauncher',       label = 'Lanceur IEM Compact' },
        { name = 'weapon_combatmg_mk2',      label = 'M60 MK2' },
        { name = 'weapon_musket',            label = 'Mousquet' },
        -- ── LÉGENDAIRE ──
        { name = 'weapon_sniperrifle',       label = 'Fusil à Lunette' },
        { name = 'weapon_marksmanrifle_mk2', label = 'Fusil à Lunette MK2' },
        { name = 'weapon_heavysniper',       label = 'AWP' },
        { name = 'weapon_heavysniper_mk2',   label = 'AWP MK2' },
        { name = 'weapon_rpg',               label = 'Lance-Roquettes' },
        { name = 'weapon_hominglauncher',    label = 'Lance-Missiles' },
    }

    local batch = {}
    for _, w in ipairs(weapons) do
        batch[#batch+1] = string.format("('%s', '%s', 1, 0, 1)", w.name, w.label:gsub("'", "\\'"))
    end
    if #batch > 0 then
        MySQL.Async.execute(
            "INSERT IGNORE INTO `items` (`name`, `label`, `limit`, `rare`, `can_remove`) VALUES " ..
            table.concat(batch, ", ")
        )
    end
    print('[pvp_inventory] ' .. #weapons .. ' armes enregistrées dans items.')
end

-- ── Enregistrer tous les véhicules comme items ESX ──────────────────────
function registerVehicleItems()
    local vehicles = {
        'adder','airbus','airtug','akula','akuma','alkonost','alpha','alphaz1',
        'ambulance','annihilator','annihilator2','apc','arbitergt','ardent',
        'asbo','asea','asea2','asterope','astron','astron2','autarch','avarus',
        'avenger','avenger2','avisa','bagger','baller','baller2','baller3',
        'baller4','baller5','baller6','baller7','banshee','banshee2','barracks',
        'barracks2','barracks3','barrage','bati','bati2','benson','besra',
        'bestiagts','bf400','bfinjection','bifta','bison','bjxl','blade',
        'blazer','blazer2','blazer3','blazer4','blazer5','blista','blista2',
        'blista3','bmx','bobcatxl','bodhi2','bombushka','boor','boxville',
        'boxville2','boxville3','boxville4','brawler','brickade','brioso',
        'brioso2','brioso3','bruiser','bruiser2','bruiser3','brutus','brutus2',
        'brutus3','buccaneer','buccaneer2','buffalo','buffalo2','buffalo3',
        'buffalo4','bulldozer','bullet','burrito','burrito2','burrito3',
        'burrito4','burrito5','bus','buzzard','buzzard2','cablecar','caddy',
        'caddy2','caddy3','calico','camper','carbonizzare','carbonrs',
        'cargobob','cargobob2','cargobob3','cargobob4','carracara','carracara2',
        'cavalcade','cavalcade2','champion','cheetah','cheetah2','checkpoint',
        'cerberus','cerberus2','cerberus3','cheburek','chinook','chino','chino2',
        'clique','club','cog552','cogcabrio',
        'cognet','comet2','comet3','comet4','comet5','comet6','comet7',
        'conada','contender','coquette','coquette2','coquette3','coquette4',
        'corsita','cruiser','crusader','cuban800','cutter','cyclone','cyclone2',
        'daemon','daemon2','deathbike','deathbike2','deathbike3','deluxo',
        'deveste','deviant','diablous','diablous2','dinghy','dinghy2','dinghy3',
        'dinghy4','dinghy5','dloader','dodo','dominator','dominator2',
        'dominator3','dominator4','dominator5','dominator6','dominator7',
        'dominator8','dominator9','dominator10','double','drafter','draugur',
        'dubsta','dubsta2','dubsta3','dukes','dukes2','dukes3','dump',
        'dune','dune2','dune3','dune4','dune5','dynasty','elegy','elegy2',
        'ellie','emerus','emperor','emperor2','emperor3','enduro','entity2',
        'entity3','entityxf','esskey','euros','everon','everon2','exemplar',
        'f620','faggio','faggio2','faggio3','faction','faction2','faction3',
        'felon','felon2','feltzer2','feltzer3','firetruk','fixter','flashgt',
        'flatbed','fmj','forklift','formula','formula2','fq2','freecrawler',
        'frogger','frogger2','fugitive','furia','furoregt','fusilade',
        'futo','futo2','gargoyle','gauntlet','gauntlet2','gauntlet3',
        'gauntlet4','gauntlet5','gburrito','gburrito2','glendale','glendale2',
        'gp1','granger','granger2','greenwood','gresley','growler','gt500',
        'guardian','habanero','hakuchou','hakuchou2','halftrack','handler',
        'hauler','hauler2','havok','hellion','hermes','hexer','hotknife',
        'hotring','howard','hunter','huntley','hustler','hydra','ignus',
        'imorgon','impaler','impaler2','impaler3','impaler4','imperator',
        'imperator2','imperator3','infernus','infernus2','ingot','innovation',
        'insurgent','insurgent2','insurgent3','intruder','issi2','issi3',
        'issi4','issi5','issi6','issi7','italigtb','italigtb2','italigto',
        'italirsx','iwagen','jackal','jb700','jb7002','jester','jester2',
        'jester3','jester4','jet','jetmax','journey','journey2','jubilee',
        'kalahari','kamacho','kanjo','kanjo2','khamelion','khanjali','komoda',
        'krieger','kuruma','kuruma2','landstalker','landstalker2','lazer',
        'le7b','lectro','lguard','limo2','locust','longfin','lurcher',
        'luxor','luxor2','lynx','mamba','mammatus','manana','manana2',
        'manchez','manchez2','manchez3','marquis','marshall','massacro',
        'massacro2','maverick','menacer','mesa','mesa2','mesa3','metrotrain',
        'michelli','microlight','miljet','minitank','minivan','minivan2',
        'mkart','mogul','molecule','monroe','monster','monster3','monster4',
        'monster5','moonbeam','moonbeam2','morningstar','mower','mule',
        'mule2','mule3','mule4','mule5','nebula','nemesis','nero','nero2',
        'nightblade','nightshade','nightshark','nimbus','neon','ninef',
        'ninef2','noose','novak','omnis','omnisegt','openwheel1','openwheel2',
        'oppressor','oppressor2','oracle','oracle2','osiris','outlaw',
        'packer','panthere','panto','paragon','paragon2','pariah','patriot',
        'patriot2','patriot3','pbus','pbus2','pcj','penumbra','penumbra2',
        'peyote','peyote2','peyote3','pfister811','phantom','phantom2',
        'phantom3','phoenix','pigalle','policeold1','policeold2','policet',
        'police','police2','police3','police4','policeb','policeinterceptor',
        'polmav','pony','pony2','postlude','pounder','pounder2','prairie',
        'pranger','predator','premier','previon','primo','primo2','proptrailer',
        'prototipo','pyro','r300','radi','raiden','ratbike','ratloader',
        'ratloader2','rcbandito','rebla','reever','regina','remus','rentalbus',
        'retinue','retinue2','revolter','rhapsody','rhino','riata','riley',
        'rinato','rogue','romero','rrocket','rt3000','rubble','ruffian',
        'ruiner','ruiner2','ruiner3','ruiner4','rumpo','rumpo2','rumpo3',
        'ruston','rustbowl','s80','sabregt','sabregt2','sadler','sadler2',
        'sanchez','sanchez2','sanctus','sandking','sandking2','savage',
        'savestra','sc1','scarab','scarab2','scarab3','schafter2','schafter3',
        'schafter4','schafter5','schafter6','schlagen','schwarzer','scorcher',
        'scramjet','seasparrow','seasparrow2','seasparrow3','seminole',
        'seminole2','sentinel','sentinel2','sentinel3','sentinel4','serrano',
        'seven70','shamal','sheava','sheriff','sheriff2','shinobi','shotaro',
        'skylift','slamvan','slamvan2','slamvan3','slamvan4','slamvan5',
        'slamvan6','sm722','specter','specter2','speeder','speeder2',
        'speedo','speedo2','speedo4',
        'squaddie','stafford','stalion','stalion2','stanier','stinger',
        'stingergt','stockade','stratum','streamer216','streiter','stretch',
        'strikeforce','stromberg','sultan','sultan2','sultan3','sultanrs',
        'superd','supervolito','supervolito2','surge','surfer','surfer2',
        'surfer3','swift','swift2','t20','tahoma','taipan','tampa','tampa2',
        'tampa3','terbyte','thrax','thrust','thruster','tigon','tiptruck','tiptruck2',
        'titan','toreador','torero','torero2','tornado','tornado2','tornado3',
        'tornado4','tornado5','tornado6','toro','toro2','toros','tractor',
        'tractor2','tractor3','trailerlarge','trailerlogs','trailers','trailers2',
        'trailers3','trailers4','trailersmall','trailersmall2','trash','trash2',
        'trflat','tribike','tribike2','tribike3','trophytruck','trophytruck2',
        'tropos','tulip','tulip2','tula','turismo2','turismor','tusam',
        'tyrant','tyrus','utillitruck','utillitruck2','utillitruck3',
        'vacca','vader','vagner','vagrant','valkyrie','valkyrie2','vamos',
        'vectre','velum','velum2','verlierer2','verus','vetir','veto',
        'veto2','vigero','vigero2','vigero3','vigilante','vindicator',
        'virgo','virgo2','virgo3','virtue','viseris','visione','volatol',
        'volatus','voltic','voltic2','voodoo','voodoo2','vstr','warrener',
        'warrener2','washington','wastlndr','weevil','weevil2','windsor',
        'windsor2','winky','wolfsbane','xls','xls2','yosemite','yosemite2',
        'yosemite3','youga','youga2','youga3','youga4','z190','zeno',
        'zentorno','zhaba','zion','zion2','zion3','zombiea','zombieb',
        'zorrusso','zr350','zr380','zr3802','zr3803','ztype',
    }

    -- Construire les VALUES par batch
    local batch = {}
    local count = 0
    for _, v in ipairs(vehicles) do
        local name  = 'vehicle_' .. v
        local label = v:sub(1,1):upper() .. v:sub(2)
        batch[#batch+1] = string.format("('%s', '%s', -1, 0, 1)", name, label)
        count = count + 1

        if count >= 50 then
            MySQL.Async.execute(
                "INSERT IGNORE INTO `items` (`name`, `label`, `limit`, `rare`, `can_remove`) VALUES " ..
                table.concat(batch, ", ")
            )
            batch = {}
            count = 0
        end
    end
    -- Dernier batch
    if #batch > 0 then
        MySQL.Async.execute(
            "INSERT IGNORE INTO `items` (`name`, `label`, `limit`, `rare`, `can_remove`) VALUES " ..
            table.concat(batch, ", ")
        )
    end
    print('[pvp_inventory] ' .. #vehicles .. ' véhicules enregistrés dans items.')
end

-- ── Helper : charger le coffre d'un joueur ──────────────────────────────
function loadStash(identifier, cb)
    MySQL.Async.fetchAll(
        'SELECT item, label, count FROM pvp_player_stash WHERE identifier = @id AND count > 0',
        { ['@id'] = identifier },
        function(rows)
            local stash = {}
            for _, r in ipairs(rows or {}) do
                stash[#stash+1] = { name = r.item, label = r.label, count = r.count }
            end
            cb(stash)
        end
    )
end

local function getDisplayNameFromPlayer(xPlayer)
    if not xPlayer then return 'Joueur' end
    local name = nil
    if xPlayer.getName then
        name = xPlayer.getName()
    end
    if (not name or name == '') and xPlayer.source then
        name = GetPlayerName(xPlayer.source)
    end
    if (not name or name == '') then
        name = xPlayer.identifier or 'Joueur'
    end
    return name
end

local function upsertPlayerStats(identifier, displayName, addKills, addDeaths, addZombies)
    if not identifier then return end
    MySQL.Async.execute(
        [[INSERT INTO pvp_player_stats (identifier, display_name, kills, deaths, zombies_killed)
          VALUES (@id, @name, @k, @d, @z)
          ON DUPLICATE KEY UPDATE
            display_name = CASE
                WHEN @name IS NULL OR @name = '' THEN display_name
                ELSE @name
            END,
            kills = kills + @k,
            deaths = deaths + @d,
            zombies_killed = zombies_killed + @z]],
        {
            ['@id'] = identifier,
            ['@name'] = displayName or '',
            ['@k'] = addKills or 0,
            ['@d'] = addDeaths or 0,
            ['@z'] = addZombies or 0
        }
    )
end

-- Cache avatar par identifier ═══════════════════════════════════════════
local avatarCache = {} -- [identifier] = url

-- Export pour les autres resources (pvp_crew, etc.)
exports('getAvatarUrl', function(identifier)
    return avatarCache[identifier]
end)

-- ── Récupérer l'avatar Steam via l'API Steam ──────────────────────────────
local function getSteamAvatar(steamHex, cb)
    if not Config.SteamApiKey or Config.SteamApiKey == '' then
        print('[AVATAR] Pas de clé Steam API configurée')
        cb(nil)
        return
    end
    -- Convertir hex en SteamID64 (decimal) — %d pour garder la précision 64-bit
    local steam64 = tonumber('0x' .. steamHex)
    if not steam64 then
        print('[AVATAR] Conversion hex échouée pour: ' .. tostring(steamHex))
        cb(nil)
        return
    end
    local steam64str = string.format('%d', steam64)
    print('[AVATAR] Steam hex=' .. steamHex .. ' → SteamID64=' .. steam64str)
    local url = 'https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key='
        .. Config.SteamApiKey .. '&steamids=' .. steam64str
    PerformHttpRequest(url, function(code, body, _headers)
        if code == 200 then
            local ok, data = pcall(json.decode, body)
            if ok and data and data.response and data.response.players and data.response.players[1] then
                local avatarUrl = data.response.players[1].avatarmedium or data.response.players[1].avatar
                print('[AVATAR] OK → ' .. tostring(avatarUrl))
                cb(avatarUrl)
            else
                print('[AVATAR] Réponse Steam invalide: ' .. tostring(body):sub(1, 200))
                cb(nil)
            end
        else
            print('[AVATAR] Erreur Steam API code=' .. tostring(code))
            cb(nil)
        end
    end, 'GET', '', {})
end

-- ── Récupérer l'avatar Discord via l'API (nécessite un bot token) ────────
local function getDiscordAvatar(discordId, cb)
    if not Config.DiscordBotToken or Config.DiscordBotToken == '' then
        cb(nil)
        return
    end
    PerformHttpRequest(
        'https://discord.com/api/v10/users/' .. discordId,
        function(code, body, _headers)
            if code == 200 then
                local ok, data = pcall(json.decode, body)
                if ok and data and data.avatar then
                    local ext = string.sub(data.avatar, 1, 2) == 'a_' and 'gif' or 'png'
                    cb('https://cdn.discordapp.com/avatars/' .. discordId .. '/' .. data.avatar .. '.' .. ext .. '?size=128')
                else
                    cb(nil)
                end
            else
                cb(nil)
            end
        end,
        'GET',
        '',
        { ['Authorization'] = 'Bot ' .. Config.DiscordBotToken }
    )
end

-- ── Résoudre l'avatar : cache d'abord, puis Steam/Discord en fallback ────
local function resolveAvatar(playerIds, identifier, cb)
    -- Vérifier le cache en premier — évite les appels HTTP à chaque ouverture
    if avatarCache[identifier] then
        cb(avatarCache[identifier])
        return
    end
    if playerIds.steam then
        getSteamAvatar(playerIds.steam, function(url)
            if url then
                avatarCache[identifier] = url
                cb(url)
            elseif playerIds.discord then
                getDiscordAvatar(playerIds.discord, function(durl)
                    if durl then avatarCache[identifier] = durl end
                    cb(durl)
                end)
            else
                cb(nil)
            end
        end)
    elseif playerIds.discord then
        getDiscordAvatar(playerIds.discord, function(url)
            if url then avatarCache[identifier] = url end
            cb(url)
        end)
    else
        cb(nil)
    end
end

-- ── Extraire les identifiants du joueur ──────────────────────────────────
local function getPlayerIdentifiers(src)
    local ids = { discord = nil, steam = nil, fivem = nil }
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id then
            if string.sub(id, 1, 8) == 'discord:' then
                ids.discord = string.sub(id, 9)
            elseif string.sub(id, 1, 6) == 'steam:' then
                ids.steam = string.sub(id, 7)
            elseif string.sub(id, 1, 6) == 'fivem:' then
                ids.fivem = string.sub(id, 7)
            end
        end
    end
    return ids
end

-- ── Prépare toutes les données et ouvre l'UI ──────────────────────────────
-- PERF: toutes les requêtes async lancées en parallèle, assemblées via compteur
RegisterNetEvent('pvp_inventory:requestData')
AddEventHandler('pvp_inventory:requestData', function()
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    -- Inventaire (en mémoire ESX, instantané)
    local inventory = {}
    for _, item in ipairs(xPlayer.getInventory()) do
        if item.count > 0 then
            inventory[#inventory+1] = {
                name  = item.name,
                label = item.label,
                count = item.count
            }
        end
    end

    -- Argent (en mémoire ESX, instantané)
    local bankAcc = xPlayer.getAccount('bank')
    local money = {
        bank = bankAcc and bankAcc.money or 0,
    }

    -- Identifiants du joueur (natif, instantané)
    local playerIds = getPlayerIdentifiers(src)
    local identifier = xPlayer.identifier

    -- Profil de base (instantané)
    local profile = {
        firstName  = xPlayer.get('firstName') or '',
        lastName   = xPlayer.get('lastName')  or '',
        identifier = identifier,
        discordId  = playerIds.discord,
    }

    -- ── Collecteur parallèle : lance toutes les requêtes en même temps ──
    local results    = {}
    local pending    = 5  -- stats, stash, market, hotbar, avatar
    local responded  = false

    -- Filet de sécurité : si un des 5 callbacks async ne répond jamais (ex: l'appel
    -- HTTP de resolveAvatar qui ne revient pas), l'UI doit quand même s'ouvrir avec
    -- les données déjà disponibles plutôt que de rester bloquée indéfiniment.
    local function finish()
        if responded then return end
        responded = true

        -- Assembler le profil avec les stats
        local s = results.stats
        if s then
            profile.kills            = s.kills
            profile.deaths           = s.deaths
            profile.zombies          = s.zombies_killed
            profile.kd               = s.deaths > 0 and math.floor(s.kills / s.deaths * 100) / 100 or s.kills
            profile.redzoneKills     = s.redzone_kills
            profile.redzoneDeaths    = s.redzone_deaths
            profile.redzoneZombies   = s.redzone_zombies
            profile.killStreakRecord  = s.kill_streak_record
            profile.xp               = s.xp
            profile.prestige         = s.prestige
            profile.activeBadge      = s.active_badge
            profile.badgesUnlocked   = s.badgesUnlocked
        end
        profile.pedModel  = results.pedModel or ''
        profile.avatarUrl = results.avatarUrl

        -- Données XP depuis vanta_xp (source unique)
        local ok, vxp = pcall(function() return exports['vanta_xp']:getProfile(identifier) end)
        if ok and type(vxp) == 'table' then
            profile.vantaXP = vxp
        end

        TriggerClientEvent('pvp_inventory:openUI', src, {
            inventory      = inventory,
            money          = money,
            profile        = profile,
            stash          = results.stash    or {},
            market         = results.market   or {},
            myListings     = results.myList   or {},
            savedHotbar    = results.hotbar   or {},
            hudType        = results.hudType  or 'gta',
            maxWeight      = getEffectiveBagWeight(xPlayer.identifier),
            maxStashWeight = getEffectiveStashWeight(xPlayer.identifier),
        })
    end

    local function tryFinish()
        pending = pending - 1
        if pending <= 0 then finish() end
    end

    -- Watchdog : force l'ouverture après 4s même si un callback n'a jamais répondu
    SetTimeout(4000, finish)

    -- ① Stats joueur (async)
    MySQL.Async.fetchAll(
        [[SELECT kills, deaths, zombies_killed,
                 COALESCE(redzone_kills, 0)     AS redzone_kills,
                 COALESCE(redzone_deaths, 0)    AS redzone_deaths,
                 COALESCE(redzone_zombies, 0)   AS redzone_zombies,
                 COALESCE(kill_streak_record, 0) AS kill_streak_record,
                 COALESCE(xp, 0)               AS xp,
                 COALESCE(prestige, 0)          AS prestige,
                 COALESCE(active_badge, '')     AS active_badge,
                 COALESCE(badges_unlocked, '[]') AS badges_unlocked,
                 COALESCE(hud_type, 'gta')     AS hud_type,
                 COALESCE(ped_model, '')       AS ped_model
          FROM pvp_player_stats WHERE identifier = @id]],
        { ['@id'] = identifier },
        function(statsRows)
            local row = statsRows and statsRows[1]
            if row then
                local okB, badges = pcall(json.decode, row.badges_unlocked or '[]')
                if not okB or type(badges) ~= 'table' then badges = {} end
                results.stats = {
                    kills            = row.kills or 0,
                    deaths           = row.deaths or 0,
                    zombies_killed   = row.zombies_killed or 0,
                    redzone_kills    = tonumber(row.redzone_kills) or 0,
                    redzone_deaths   = tonumber(row.redzone_deaths) or 0,
                    redzone_zombies  = tonumber(row.redzone_zombies) or 0,
                    kill_streak_record = tonumber(row.kill_streak_record) or 0,
                    xp               = tonumber(row.xp) or 0,
                    prestige         = tonumber(row.prestige) or 0,
                    active_badge     = row.active_badge or '',
                    badgesUnlocked   = badges,
                }
                results.hudType = row.hud_type or 'gta'
                results.pedModel = row.ped_model or ''
            else
                results.stats = {
                    kills=0, deaths=0, zombies_killed=0,
                    redzone_kills=0, redzone_deaths=0, redzone_zombies=0,
                    kill_streak_record=0, xp=0, prestige=0,
                    active_badge='', badgesUnlocked={},
                }
                results.hudType = 'gta'
            end
            tryFinish()
        end
    )

    -- ② Coffre protégé (async)
    loadStash(identifier, function(stash)
        results.stash = stash
        tryFinish()
    end)

    -- ③ Marché (async, plus de Sync.fetchAll)
    MySQL.Async.fetchAll(
        [[SELECT id, seller_name, item_name, item_label, quantity, price, currency
          FROM pvp_market_listings ORDER BY created_at DESC]],
        {},
        function(rows)
            results.market = rows or {}
            -- Mes annonces (async)
            MySQL.Async.fetchAll(
                [[SELECT id, item_name, item_label, quantity, price, currency
                  FROM pvp_market_listings WHERE seller_identifier = @id]],
                { ['@id'] = identifier },
                function(myRows)
                    results.myList = myRows or {}
                    tryFinish()
                end
            )
        end
    )

    -- ④ Hotbar (async)
    loadHotbar(identifier, function(savedHotbar)
        results.hotbar = savedHotbar
        tryFinish()
    end)

    -- ⑤ Avatar (cache prioritaire, HTTP uniquement au 1er appel)
    resolveAvatar(playerIds, identifier, function(avatarUrl)
        results.avatarUrl = avatarUrl
        tryFinish()
    end)
end)

-- ── Tables d'items par catégorie ──────────────────────────────────────────
local CONSUMABLE = {
    bandage=true, medkit=true, kevlar=true,
    shot_repel=true, shot_attract=true, shot_speed=true, shot_health=true,
}
local WEAPONS = {
    -- Mêlée
    weapon_knife=true,        weapon_machete=true,       weapon_bat=true,
    weapon_crowbar=true,      weapon_switchblade=true,   weapon_hatchet=true,
    -- Très commun
    weapon_molotov=true,
    weapon_appistol=true,     weapon_pistol=true,        weapon_pistol_mk2=true,
    weapon_snspistol=true,    weapon_snspistol_mk2=true,
    weapon_vintagepistol=true, weapon_combatpistol=true,  weapon_heavypistol=true,
    weapon_microsmg=true,     weapon_minismg=true,        weapon_smg=true,
    weapon_smg_mk2=true,      weapon_machinepistol=true,
    -- Commun
    weapon_assaultrifle=true, weapon_carbinerifle=true,   weapon_specialcarbine=true,
    -- Rare
    weapon_assaultrifle_mk2=true, weapon_carbinerifle_mk2=true, weapon_specialcarbine_mk2=true,
    weapon_stungun=true,      weapon_combatmg=true,       weapon_mg=true,
    -- Épic
    weapon_precisionrifle=true, weapon_compactlauncher=true, weapon_emplauncher=true,
    weapon_combatmg_mk2=true, weapon_musket=true,
    -- Légendaire
    weapon_sniperrifle=true,  weapon_marksmanrifle_mk2=true,
    weapon_heavysniper=true,  weapon_heavysniper_mk2=true,
    weapon_rpg=true,          weapon_hominglauncher=true,
}

-- ── Validation centralisée des noms d'items ─────────────────────────────
local function isValidItemName(name)
    if type(name) ~= 'string' or name == '' then return false end
    if CONSUMABLE[name] then return true end
    if WEAPONS[name] then return true end
    if name:find('^vehicle_') then return true end
    -- Munitions spéciales
    if name == 'ammo_sniper' then return true end
    return false
end

-- ── Tracking des véhicules spawnés côté serveur ───────────────────────────
-- SÉCURITÉ : activeVehicleSpawns[itemName] = count — incrémenté par useItem,
-- décrémenté par storeVehicle. Empêche un client de forger storeVehicle
-- pour générer des items sans qu'un spawn serveur légitime ait eu lieu.
local activeVehicleSpawns = {}
local function registerVehicleSpawn(itemName)
    activeVehicleSpawns[itemName] = (activeVehicleSpawns[itemName] or 0) + 1
end

-- Cooldown de re-sortie après rangement : après avoir rangé un véhicule (K),
-- le joueur doit attendre avant de pouvoir en ressortir un. Contrôle 100%
-- serveur (le client ne fait qu'afficher la notif).
local VEHICLE_RESPAWN_COOLDOWN_MS = 5000
local vehicleSpawnCooldown = {}  -- [src] = timestamp (GetGameTimer) de fin de cooldown

-- ── Utiliser un item ──────────────────────────────────────────────────────
RegisterNetEvent('pvp_inventory:useItem')
AddEventHandler('pvp_inventory:useItem', function(itemName)
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if not isValidItemName(itemName) then return end

    local item = xPlayer.getInventoryItem(itemName)
    if not item or item.count < 1 then
        notify(src, 'Item indisponible.', 'error')
        return
    end

    -- Consommables (bandage, medkit, armures) → géré par le client avec cooldown
    -- Le client appelle pvp_inventory:useItemConfirmed après le timer
    if CONSUMABLE[itemName] then
        return

    -- Armes → équiper sans consommer (toutes avec munitions infinies)
    elseif WEAPONS[itemName] then
        TriggerClientEvent('pvp_inventory:equipWeapon', src, itemName)
        notify(src, item.label .. ' équipé.', 'success')

    -- Véhicules → spawn (consomme l'item, le joueur le récupère avec K)
    elseif string.sub(itemName, 1, 8) == 'vehicle_' then
        -- Cooldown après rangement : pas de re-sortie immédiate
        local readyAt = vehicleSpawnCooldown[src]
        if readyAt and GetGameTimer() < readyAt then
            local remain = math.ceil((readyAt - GetGameTimer()) / 1000)
            notify(src,
                'Attends ' .. remain .. 's avant de ressortir un véhicule.', 'warning')
            return
        end

        local model = string.sub(itemName, 9)
        xPlayer.removeInventoryItem(itemName, 1)
        registerVehicleSpawn(itemName)
        TriggerClientEvent('pvp_inventory:spawnVehicle', src, model, itemName, item.label)
        notify(src, item.label .. ' spawn !', 'success')
        refreshClient(src, xPlayer)
    end
end)

-- ── Utiliser un consommable après cooldown (appelé par le client) ────────
RegisterNetEvent('pvp_inventory:useItemConfirmed')
AddEventHandler('pvp_inventory:useItemConfirmed', function(itemName)
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if type(itemName) ~= 'string' then return end

    -- Seulement les consommables
    if not CONSUMABLE[itemName] then return end

    local item = xPlayer.getInventoryItem(itemName)
    if not item or item.count < 1 then
        notify(src, 'Item indisponible.', 'error')
        return
    end

    xPlayer.removeInventoryItem(itemName, 1)
    TriggerClientEvent('pvp_inventory:applyItem', src, itemName)
    notify(src, item.label .. ' appliqué !', 'success')
    refreshClient(src, xPlayer)
end)

-- ── Déposer un item (drop) ────────────────────────────────────────────────
RegisterNetEvent('pvp_inventory:dropItem')
AddEventHandler('pvp_inventory:dropItem', function(itemName, qty)
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if not isValidItemName(itemName) then return end

    qty = math.max(1, math.floor(tonumber(qty) or 1))
    local item = xPlayer.getInventoryItem(itemName)
    if not item or item.count < qty then return end

    xPlayer.removeInventoryItem(itemName, qty)
    notify(src, item.label .. ' x' .. qty .. ' déposé.', 'success')
    refreshClient(src, xPlayer)
end)

-- ── Anti race condition : verrouillage par joueur sur les opérations coffre ──
-- [identifier] = os.time() du début de l'opération. Horodaté (et non plus un
-- simple booléen) pour qu'un lock ne puisse pas rester posé indéfiniment si un
-- callback MySQL ne revient jamais : sinon le joueur ne peut plus rien déposer
-- ni retirer de son coffre jusqu'à sa reconnexion.
local stashLocks = {}
local STASH_LOCK_TIMEOUT = 10  -- secondes

local function isStashLocked(identifier)
    local startedAt = stashLocks[identifier]
    if not startedAt then return false end
    if os.time() - startedAt >= STASH_LOCK_TIMEOUT then
        stashLocks[identifier] = nil
        return false
    end
    return true
end

-- ── Coffre protégé : déposer ─────────────────────────────────────────────
local STASH_MAX_WEIGHT = 20.0

RegisterNetEvent('pvp_inventory:stashDeposit')
AddEventHandler('pvp_inventory:stashDeposit', function(itemName, qty)
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if not isValidItemName(itemName) then return end

    -- SÉCURITÉ / GAMEPLAY : impossible de ranger dans le coffre protégé en
    -- mode combat (pvp_combat) — empêche de sécuriser son loot en pleine
    -- fuite pendant un fight.
    local ok, inCombat = pcall(function() return exports['pvp_combat']:isInCombat(src) end)
    if ok and inCombat then
        notify(src, 'Impossible en mode combat !', 'warning')
        return
    end

    -- Anti race condition : une seule opération coffre à la fois par joueur
    if isStashLocked(xPlayer.identifier) then
        notify(src, 'Opération en cours...', 'info')
        return
    end
    stashLocks[xPlayer.identifier] = os.time()

    qty = math.max(1, math.floor(tonumber(qty) or 1))
    local item = xPlayer.getInventoryItem(itemName)
    if not item or item.count < qty then
        stashLocks[xPlayer.identifier] = nil
        notify(src, 'Item indisponible.', 'error')
        return
    end

    -- Vérifier le poids du coffre (utilise getItemWeight, la même source de vérité que le sac)
    loadStash(xPlayer.identifier, function(stash)
        local currentWeight = 0
        for _, s in ipairs(stash) do
            currentWeight = currentWeight + getItemWeight(s.name) * s.count
        end
        local addWeight = getItemWeight(itemName) * qty
        local effectiveStashMax = getEffectiveStashWeight(xPlayer.identifier)
        if currentWeight + addWeight > effectiveStashMax then
            stashLocks[xPlayer.identifier] = nil
            notify(src, 'Coffre trop lourd ! ('..effectiveStashMax..' kg max)', 'warning')
            return
        end

        xPlayer.removeInventoryItem(itemName, qty)
        -- Déséquiper l'arme si elle était en main
        if WEAPONS[itemName] then
            TriggerClientEvent('pvp_inventory:unequipWeapon', src, itemName)
        end
        -- PERF: attendre la fin de l'écriture DB avant de refresh + release lock
        MySQL.Async.execute(
            [[INSERT INTO pvp_player_stash (identifier, item, label, count)
              VALUES (@id, @item, @label, @qty)
              ON DUPLICATE KEY UPDATE count = count + @qty]],
            { ['@id'] = xPlayer.identifier, ['@item'] = itemName, ['@label'] = item.label, ['@qty'] = qty },
            function()
                notify(src, item.label .. ' x' .. qty .. ' → coffre.', 'success')
                refreshStash(src, xPlayer, function()
                    stashLocks[xPlayer.identifier] = nil
                end)
            end
        )
    end)
end)

-- ── Coffre protégé : retirer ─────────────────────────────────────────────
RegisterNetEvent('pvp_inventory:stashWithdraw')
AddEventHandler('pvp_inventory:stashWithdraw', function(itemName, qty)
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if not isValidItemName(itemName) then return end

    -- Anti race condition
    if isStashLocked(xPlayer.identifier) then
        notify(src, 'Opération en cours...', 'info')
        return
    end
    stashLocks[xPlayer.identifier] = os.time()

    qty = math.max(1, math.floor(tonumber(qty) or 1))

    MySQL.Async.fetchAll(
        'SELECT count, label FROM pvp_player_stash WHERE identifier = @id AND item = @item',
        { ['@id'] = xPlayer.identifier, ['@item'] = itemName },
        function(rows)
            if not rows[1] or rows[1].count < qty then
                stashLocks[xPlayer.identifier] = nil
                notify(src, 'Pas assez dans le coffre.', 'error')
                return
            end

            local label = rows[1].label
            local newCount = rows[1].count - qty

            -- Vérification poids sac (avec bonus prestige)
            local addWeight = getItemWeight(itemName) * qty
            local effBagMax = getEffectiveBagWeight(xPlayer.identifier)
            if getBagWeight(xPlayer) + addWeight > effBagMax then
                stashLocks[xPlayer.identifier] = nil
                notify(src, 'Sac trop lourd ! (' .. effBagMax .. ' kg max)', 'warning')
                return
            end

            xPlayer.addInventoryItem(itemName, qty)

            local function afterDbWrite()
                notify(src, label .. ' x' .. qty .. ' ← coffre.', 'success')
                refreshStash(src, xPlayer, function()
                    stashLocks[xPlayer.identifier] = nil
                end)
            end

            if newCount <= 0 then
                MySQL.Async.execute(
                    'DELETE FROM pvp_player_stash WHERE identifier = @id AND item = @item',
                    { ['@id'] = xPlayer.identifier, ['@item'] = itemName },
                    afterDbWrite
                )
            else
                MySQL.Async.execute(
                    'UPDATE pvp_player_stash SET count = @c WHERE identifier = @id AND item = @item',
                    { ['@id'] = xPlayer.identifier, ['@item'] = itemName, ['@c'] = newCount },
                    afterDbWrite
                )
            end
        end
    )
end)

-- ── Refresh léger : inventaire + stash uniquement (pas de requêtes marché) ──
-- Utilisé par stashDeposit/stashWithdraw pour un feedback instantané
function refreshStash(src, xPlayer, onDone)
    local inventory = {}
    for _, item in ipairs(xPlayer.getInventory()) do
        if item.count > 0 then
            inventory[#inventory+1] = { name=item.name, label=item.label, count=item.count }
        end
    end
    local bankAcc = xPlayer.getAccount('bank')
    loadStash(xPlayer.identifier, function(stash)
        TriggerClientEvent('pvp_inventory:refresh', src, {
            inventory      = inventory,
            stash          = stash,
            money          = { bank = bankAcc and bankAcc.money or 0 },
            maxWeight      = getEffectiveBagWeight(xPlayer.identifier),
            maxStashWeight = getEffectiveStashWeight(xPlayer.identifier),
        })
        if onDone then onDone() end
    end)
end

-- ── Refresh complet (inventaire + argent + stash + marché) ────────────────
function refreshClient(src, xPlayer)
    local inventory = {}
    for _, item in ipairs(xPlayer.getInventory()) do
        if item.count > 0 then
            inventory[#inventory+1] = { name=item.name, label=item.label, count=item.count }
        end
    end
    local bankAcc = xPlayer.getAccount('bank')

    loadStash(xPlayer.identifier, function(stash)
        local ok1, allListings = pcall(function()
            return MySQL.Sync.fetchAll(
                [[SELECT id, seller_name, item_name, item_label, quantity, price
                  FROM pvp_market_listings ORDER BY created_at DESC]], {})
        end)
        if not ok1 then allListings = {} end

        local ok2, myListings = pcall(function()
            return MySQL.Sync.fetchAll(
                'SELECT id, item_name, item_label, quantity, price FROM pvp_market_listings WHERE seller_identifier = @id',
                { ['@id'] = xPlayer.identifier })
        end)
        if not ok2 then myListings = {} end

        TriggerClientEvent('pvp_inventory:refresh', src, {
            inventory      = inventory,
            stash          = stash,
            money          = { bank = bankAcc and bankAcc.money or 0 },
            market         = allListings or {},
            myListings     = myListings  or {},
            maxWeight      = getEffectiveBagWeight(xPlayer.identifier),
            maxStashWeight = getEffectiveStashWeight(xPlayer.identifier),
        })
    end)
end

-- ── Zombie tué : incrémente les stats (event INTERNE — déclenché par
-- pvp_zombies via TriggerEvent local, jamais de RegisterNetEvent ici : sinon
-- un client pourrait forger l'event pour booster ses stats/XP via F8).
AddEventHandler('pvp_inventory:recordZombieKill', function(targetSrc)
    local src = tonumber(targetSrc)
    if not src then return end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    upsertPlayerStats(xPlayer.identifier, getDisplayNameFromPlayer(xPlayer), 0, 0, 1)
    TriggerEvent('pvp_crew:zombieKill', xPlayer.identifier)
end)

AddEventHandler('pvp_inventory:recordPvpKill', function(killerIdentifier, victimIdentifier, killerName, victimName)
    if not killerIdentifier and not victimIdentifier then return end

    if victimIdentifier then
        upsertPlayerStats(victimIdentifier, victimName or victimIdentifier, 0, 1, 0)
        playerStreaks[victimIdentifier] = 0
    end

    if killerIdentifier and killerIdentifier ~= victimIdentifier then
        upsertPlayerStats(killerIdentifier, killerName or killerIdentifier, 1, 0, 0)

        playerStreaks[killerIdentifier] = (playerStreaks[killerIdentifier] or 0) + 1
        local streak = playerStreaks[killerIdentifier]

        MySQL.Async.fetchAll(
            'SELECT kill_streak_record, kills, zombies_killed FROM pvp_player_stats WHERE identifier = @id',
            { ['@id'] = killerIdentifier },
            function(rows)
                local record  = rows and rows[1] and tonumber(rows[1].kill_streak_record) or 0
                local kills   = rows and rows[1] and tonumber(rows[1].kills)              or 0
                local zombies = rows and rows[1] and tonumber(rows[1].zombies_killed)     or 0
                if streak > record then
                    MySQL.Async.execute(
                        'UPDATE pvp_player_stats SET kill_streak_record = @s WHERE identifier = @id',
                        { ['@id'] = killerIdentifier, ['@s'] = streak }
                    )
                end
                checkAllBadges(killerIdentifier, { kills = kills, zombies = zombies, streak = streak })
            end
        )
    end

    TriggerEvent('pvp_crew:pvpKill', killerIdentifier, victimIdentifier)
end)

ESX.RegisterServerCallback('pvp_inventory:getLeaderboards', function(src, cb)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then
        cb({ players = {}, crews = {}, myIdentifier = nil, myCrewId = nil })
        return
    end

    local myIdentifier = xPlayer.identifier
    local myCrewId = nil

    local function finish(crews, players)
        cb({
            players = players or {},
            crews = crews or {},
            myIdentifier = myIdentifier,
            myCrewId = myCrewId
        })
    end

    MySQL.Async.fetchAll(
        'SELECT crew_id FROM pvp_crew_members WHERE identifier = @id LIMIT 1',
        { ['@id'] = myIdentifier },
        function(myCrewRows)
            if myCrewRows and myCrewRows[1] then
                myCrewId = myCrewRows[1].crew_id
            end

            MySQL.Async.fetchAll(
                [[SELECT p.identifier, p.display_name, p.kills, p.deaths, p.zombies_killed,
                         COALESCE(p.redzone_kills, 0) AS redzone_kills,
                         COALESCE(p.redzone_deaths, 0) AS redzone_deaths,
                         COALESCE(p.redzone_zombies, 0) AS redzone_zombies,
                         c.id AS crew_id, c.name AS crew_name, c.tag AS crew_tag
                  FROM pvp_player_stats p
                  LEFT JOIN pvp_crew_members m ON m.identifier = p.identifier
                  LEFT JOIN pvp_crews c ON c.id = m.crew_id
                  WHERE (p.kills + p.deaths + p.zombies_killed) > 0
                  LIMIT 300]],
                {},
                function(playerRows)
                    local players = {}
                    for _, row in ipairs(playerRows or {}) do
                        local kills = tonumber(row.kills) or 0
                        local deaths = tonumber(row.deaths) or 0
                        local zombies = tonumber(row.zombies_killed) or 0
                        local name = row.display_name
                        if not name or name == '' then
                            name = row.identifier
                        end
                        players[#players + 1] = {
                            identifier = row.identifier,
                            name = name,
                            kills = kills,
                            deaths = deaths,
                            zombies = zombies,
                            kd = deaths > 0 and math.floor((kills / deaths) * 100) / 100 or kills,
                            redzoneKills   = tonumber(row.redzone_kills) or 0,
                            redzoneDeaths  = tonumber(row.redzone_deaths) or 0,
                            redzoneZombies = tonumber(row.redzone_zombies) or 0,
                            crew_id = row.crew_id and tonumber(row.crew_id) or nil,
                            crew_name = row.crew_name or nil,
                            crew_tag = row.crew_tag or nil,
                            avatarUrl = avatarCache[row.identifier] or nil
                        }
                    end

                    MySQL.Async.fetchAll(
                        [[SELECT
                            c.id,
                            c.name,
                            c.tag,
                            c.kills_total,
                            c.deaths_total,
                            c.zombies_total,
                            COALESCE(c.redzone_kills_total, 0) AS redzone_kills_total,
                            COALESCE(c.redzone_zombies_total, 0) AS redzone_zombies_total,
                            COALESCE(c.level, 1) AS level,
                            COALESCE(c.xp, 0) AS xp,
                            COALESCE(c.bank, 0) AS bank,
                            COALESCE(c.objectives_completed, 0) AS objectives_completed,
                            COALESCE(c.events_won, 0) AS events_won,
                            COALESCE(c.redzone_controls_total, 0) AS redzone_controls_total,
                            COUNT(m.id) AS members_count
                          FROM pvp_crews c
                          LEFT JOIN pvp_crew_members m ON m.crew_id = c.id
                          GROUP BY c.id
                          HAVING (c.kills_total + c.deaths_total + c.zombies_total) > 0
                          LIMIT 300]],
                        {},
                        function(crewRows)
                            local crews = {}
                            for _, row in ipairs(crewRows or {}) do
                                local kills = tonumber(row.kills_total) or 0
                                local deaths = tonumber(row.deaths_total) or 0
                                local zombies = tonumber(row.zombies_total) or 0
                                crews[#crews + 1] = {
                                    id = tonumber(row.id),
                                    name = row.name,
                                    tag = row.tag,
                                    kills = kills,
                                    deaths = deaths,
                                    zombies = zombies,
                                    redzoneKills   = tonumber(row.redzone_kills_total) or 0,
                                    redzoneZombies = tonumber(row.redzone_zombies_total) or 0,
                                    level = tonumber(row.level) or 1,
                                    xp = tonumber(row.xp) or 0,
                                    bank = tonumber(row.bank) or 0,
                                    objectives = tonumber(row.objectives_completed) or 0,
                                    eventsWon = tonumber(row.events_won) or 0,
                                    controls = tonumber(row.redzone_controls_total) or 0,
                                    members = tonumber(row.members_count) or 0,
                                    kd = deaths > 0 and math.floor((kills / deaths) * 100) / 100 or kills
                                }
                            end
                            finish(crews, players)
                        end
                    )
                end
            )
        end
    )
end)

-- ══ DEATH BAGS ═══════════════════════════════════════════════════════════
-- Persistés en BDD (pvp_death_bags) : survivent à un restart serveur (avant,
-- ils vivaient uniquement en mémoire et disparaissaient au redémarrage).
-- Visibilité par proximité : un joueur n'apprend l'existence d'un sac (et
-- son prop n'apparaît chez lui) que s'il se trouve à moins de
-- DEATH_BAG_VISIBILITY_RADIUS mètres. Avant, la position de TOUS les sacs de
-- la map était broadcastée à TOUS les clients (à la création ET à la connexion
-- via requestDeathBagSync) — un client modifié pouvait donc cartographier
-- tous les sacs du serveur en temps réel. La fonctionnalité (n'importe qui
-- peut looter n'importe quel sac en s'approchant) est inchangée.
local deathBags = {}        -- [bagId] = { dbId, coords, items[] }
local deathBagLocks = {}    -- anti-race-condition per bag
local knownBags = {}        -- [src] = { [bagId] = true } — sacs déjà notifiés à ce joueur
local DEATH_BAG_VISIBILITY_RADIUS = 150.0
local DEATH_BAG_VIS_RADIUS_SQ = DEATH_BAG_VISIBILITY_RADIUS * DEATH_BAG_VISIBILITY_RADIUS

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `pvp_death_bags` (
            `id`         INT AUTO_INCREMENT PRIMARY KEY,
            `pos_x`      FLOAT NOT NULL,
            `pos_y`      FLOAT NOT NULL,
            `pos_z`      FLOAT NOT NULL,
            `items_json` LONGTEXT NOT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]], {}, function()
        MySQL.Async.fetchAll('SELECT id, pos_x, pos_y, pos_z, items_json FROM pvp_death_bags', {}, function(rows)
            for _, row in ipairs(rows or {}) do
                local ok, items = pcall(json.decode, row.items_json)
                if ok and type(items) == 'table' and #items > 0 then
                    deathBags['dbag_' .. row.id] = {
                        dbId   = row.id,
                        coords = { x = row.pos_x, y = row.pos_y, z = row.pos_z },
                        items  = items,
                    }
                end
            end
            print(('[pvp_inventory] %d death bag(s) rechargé(s) depuis la BDD'):format(#(rows or {})))
        end)
    end)
end)

local function persistDeathBagItems(bag)
    MySQL.Async.execute(
        'UPDATE pvp_death_bags SET items_json = @items WHERE id = @id',
        { ['@id'] = bag.dbId, ['@items'] = json.encode(bag.items) }
    )
end

-- Joueurs connectés à moins de sqrt(radiusSq) mètres de coords
local function getPlayersNear(coords, radiusSq)
    local nearby = {}
    for _, src in ipairs(GetPlayers()) do
        src = tonumber(src)
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 then
            local pCoords = GetEntityCoords(ped)
            local dx = pCoords.x - coords.x
            local dy = pCoords.y - coords.y
            local dz = pCoords.z - coords.z
            if (dx*dx + dy*dy + dz*dz) <= radiusSq then
                nearby[#nearby+1] = src
            end
        end
    end
    return nearby
end

local function notifyBagToPlayer(src, bagId, bag)
    knownBags[src] = knownBags[src] or {}
    if knownBags[src][bagId] then return end
    knownBags[src][bagId] = true
    TriggerClientEvent('pvp_inventory:deathBagCreated', src, bagId, bag.coords)
end

-- ── Scan périodique : notifie les sacs existants aux joueurs qui s'en
-- approchent (couvre les sacs créés avant leur connexion, ou rechargés
-- depuis la BDD après un restart, sans jamais broadcaster à tout le monde).
CreateThread(function()
    while true do
        Wait(6000)
        for bagId, bag in pairs(deathBags) do
            for _, src in ipairs(getPlayersNear(bag.coords, DEATH_BAG_VIS_RADIUS_SQ)) do
                notifyBagToPlayer(src, bagId, bag)
            end
        end
    end
end)

-- ── Vide l'inventaire du joueur dans un sac de loot au sol ───────────────
-- Partagé entre une mort normale (playerDied) et une mort par combat-log
-- (combatLogDeath, déclenché par pvp_combat à la déconnexion).
local function createDeathBagFromInventory(src, xPlayer, deathCoords)
    -- Vérifier si la mort s'est produite en zone safe → inventaire préservé
    if deathCoords and deathCoords.x then
        local ok, outposts = pcall(function() return exports['pvp_outposts']:getAllOutposts() end)
        if ok and outposts then
            for _, op in ipairs(outposts) do
                local radius = op.safeRadius or 50.0
                local dx = deathCoords.x - op.coords.x
                local dy = deathCoords.y - op.coords.y
                local dz = deathCoords.z - op.coords.z
                if (dx*dx + dy*dy + dz*dz) < (radius * radius) then
                    notify(src, 'Mort en zone safe — inventaire préservé.', 'info')
                    return
                end
            end
        end
    end

    -- Collecter tous les items avant de les retirer
    local bagItems = {}
    local cleared  = {}
    for _, item in ipairs(xPlayer.getInventory()) do
        if item.count > 0 then
            cleared[#cleared+1] = item.label .. ' x' .. item.count
            bagItems[#bagItems+1] = { name = item.name, label = item.label, count = item.count }
            xPlayer.removeInventoryItem(item.name, item.count)
        end
    end

    if #cleared > 0 then
        notify(src, 'Inventaire perdu ! (' .. #cleared .. ' items)', 'error')
    end

    -- Créer le sac de loot si le joueur avait des items
    if #bagItems > 0 and deathCoords and deathCoords.x then
        MySQL.Async.insert(
            'INSERT INTO pvp_death_bags (pos_x, pos_y, pos_z, items_json) VALUES (@x, @y, @z, @items)',
            { ['@x'] = deathCoords.x, ['@y'] = deathCoords.y, ['@z'] = deathCoords.z, ['@items'] = json.encode(bagItems) },
            function(dbId)
                if not dbId then return end
                local bagId = 'dbag_' .. dbId
                local coords = { x = deathCoords.x, y = deathCoords.y, z = deathCoords.z }
                local bag = { dbId = dbId, coords = coords, items = bagItems }
                deathBags[bagId] = bag
                -- Notifie tout de suite les joueurs déjà à proximité — les
                -- autres le découvriront via le scan périodique en s'approchant.
                for _, nearSrc in ipairs(getPlayersNear(coords, DEATH_BAG_VIS_RADIUS_SQ)) do
                    notifyBagToPlayer(nearSrc, bagId, bag)
                end
            end
        )
    end
end

-- ── Mort du joueur : créer un sac de loot à l'emplacement de la mort ─────
RegisterNetEvent('pvp_inventory:playerDied')
AddEventHandler('pvp_inventory:playerDied', function(deathCoords)
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    createDeathBagFromInventory(src, xPlayer, deathCoords)
end)

-- ── Mort par combat-log (anti combat-log, déclenché par pvp_combat quand un
-- joueur en mode combat se déconnecte) — event INTERNE, pas de RegisterNetEvent
-- (src vient de pvp_combat, pas d'un client).
AddEventHandler('pvp_inventory:combatLogDeath', function(src, deathCoords)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    createDeathBagFromInventory(src, xPlayer, deathCoords)
end)

-- ── Demander l'ouverture d'un death bag ──────────────────────────────────
RegisterNetEvent('pvp_inventory:requestDeathBag')
AddEventHandler('pvp_inventory:requestDeathBag', function(bagId)
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local bag = deathBags[bagId]
    if not bag then
        notify(src, 'Ce sac a disparu.', 'warning')
        return
    end

    -- Inventaire du joueur
    local inventory = {}
    for _, item in ipairs(xPlayer.getInventory()) do
        if item.count > 0 then
            inventory[#inventory+1] = { name = item.name, label = item.label, count = item.count }
        end
    end

    local bankAcc = xPlayer.getAccount('bank')
    local money = { bank = bankAcc and bankAcc.money or 0 }

    TriggerClientEvent('pvp_inventory:openUIWithDeathBag', src, {
        inventory = inventory,
        money     = money,
        maxWeight = getEffectiveBagWeight(xPlayer.identifier),
        bagId     = bagId,
        bagLabel  = 'SAC DE LOOT',
        bagItems  = bag.items,
    })
end)

-- ── Retirer un item d'un death bag ───────────────────────────────────────
RegisterNetEvent('pvp_inventory:deathBagWithdraw')
AddEventHandler('pvp_inventory:deathBagWithdraw', function(bagId, itemName, qty)
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    -- SÉCURITÉ : bagId doit être une string, itemName validé par la whitelist
    if type(bagId) ~= 'string' then return end
    if not isValidItemName(itemName) then return end

    qty = tonumber(qty) or 1
    if qty < 1 or qty > 1000 then return end
    qty = math.floor(qty)

    local bag = deathBags[bagId]
    if not bag then
        notify(src, 'Ce sac a disparu.', 'warning')
        return
    end

    -- SÉCURITÉ : distance check serveur (anti-téléport/loot à distance).
    -- Le client pouvait trigger cet event depuis n'importe où.
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 and bag.coords then
        local pCoords = GetEntityCoords(ped)
        local bCoords = bag.coords
        local dx = pCoords.x - bCoords.x
        local dy = pCoords.y - bCoords.y
        local dz = pCoords.z - bCoords.z
        if (dx * dx + dy * dy + dz * dz) > 25.0 then -- >5m
            notify(src, 'Trop loin du sac.', 'warning')
            return
        end
    end

    -- Lock anti-race
    if deathBagLocks[bagId] then return end
    deathBagLocks[bagId] = true

    -- Vérifier poids côté serveur avec les vraies helpers (prestige bonus pris en compte).
    local currentWeight = getBagWeight(xPlayer)
    local addWeight = getItemWeight(itemName) * qty
    local maxWeight = getEffectiveBagWeight(xPlayer.identifier)
    if currentWeight + addWeight > maxWeight then
        notify(src, 'Sac trop lourd ! (' .. maxWeight .. ' kg max)', 'warning')
        deathBagLocks[bagId] = nil
        return
    end

    -- Trouver et retirer l'item du sac
    local found = false
    for i, item in ipairs(bag.items) do
        if item.name == itemName then
            local take = math.min(qty, item.count)
            item.count = item.count - take
            if item.count <= 0 then
                table.remove(bag.items, i)
            end
            xPlayer.addInventoryItem(itemName, take)
            found = true
            break
        end
    end

    deathBagLocks[bagId] = nil

    if not found then
        notify(src, 'Item introuvable dans le sac.', 'error')
        return
    end

    -- Rafraîchir l'inventaire du joueur
    local inventory = {}
    for _, item in ipairs(xPlayer.getInventory()) do
        if item.count > 0 then
            inventory[#inventory+1] = { name = item.name, label = item.label, count = item.count }
        end
    end

    -- Envoyer le refresh au joueur
    TriggerClientEvent('pvp_inventory:refreshDeathBag', src, {
        inventory = inventory,
        bagItems  = bag.items,
    })

    -- Si le sac est vide → le supprimer (BDD + mémoire), sinon persister le reste
    if #bag.items == 0 then
        deathBags[bagId] = nil
        for _, ks in pairs(knownBags) do ks[bagId] = nil end
        MySQL.Async.execute('DELETE FROM pvp_death_bags WHERE id = @id', { ['@id'] = bag.dbId })
        TriggerClientEvent('pvp_inventory:deathBagRemoved', -1, bagId)
    else
        persistDeathBagItems(bag)
    end
end)

-- ── Sync à la connexion : n'envoie que les sacs déjà à portée du joueur —
-- le scan périodique se charge des sacs découverts en se déplaçant ensuite.
RegisterNetEvent('pvp_inventory:requestDeathBagSync')
AddEventHandler('pvp_inventory:requestDeathBagSync', function()
    local src = source
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local pCoords = GetEntityCoords(ped)
    for bagId, bag in pairs(deathBags) do
        local dx = pCoords.x - bag.coords.x
        local dy = pCoords.y - bag.coords.y
        local dz = pCoords.z - bag.coords.z
        if (dx*dx + dy*dy + dz*dz) <= DEATH_BAG_VIS_RADIUS_SQ then
            notifyBagToPlayer(src, bagId, bag)
        end
    end
end)

-- ══ COFFRE AVANT-POSTE ═══════════════════════════════════════════════════
-- Coffre unifié : un seul contenu par joueur, partagé par TOUS les avant-postes
-- du serveur (l'outpost_id envoyé par le client est ignoré au profit de 'global',
-- donc un avant-poste ajouté plus tard ouvre automatiquement le même coffre).
-- Pas de limite de poids : c'est le stockage longue durée, la limite ne vit que
-- sur le sac (Config.MaxWeight) et sur le conteneur protégé (20 kg + bonus).

-- Helper : charger le coffre d'un avant-poste pour un joueur
function loadOutpostStash(identifier, outpostId, cb)
    MySQL.Async.fetchAll(
        'SELECT item, label, count FROM pvp_outpost_stash WHERE identifier = @id AND outpost_id = @op AND count > 0',
        { ['@id'] = identifier, ['@op'] = outpostId },
        function(rows)
            local stash = {}
            for _, r in ipairs(rows or {}) do
                stash[#stash+1] = { name = r.item, label = r.label, count = r.count }
            end
            cb(stash)
        end
    )
end

-- Ouvrir le coffre avant-poste (appelé depuis pvp_outposts)
-- Envoie aussi l'inventaire pour ouvrir l'UI complète en mode coffre avant-poste
RegisterNetEvent('pvp_inventory:requestOutpostStash')
AddEventHandler('pvp_inventory:requestOutpostStash', function(_, outpostLabel)
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local GLOBAL_ID = 'global' -- coffre unifié pour tous les avant-postes

    -- Inventaire du joueur
    local inventory = {}
    for _, item in ipairs(xPlayer.getInventory()) do
        if item.count > 0 then
            inventory[#inventory+1] = { name=item.name, label=item.label, count=item.count }
        end
    end

    local bankAcc = xPlayer.getAccount('bank')
    local money = { bank = bankAcc and bankAcc.money or 0 }

    loadOutpostStash(xPlayer.identifier, GLOBAL_ID, function(outpostItems)
        TriggerClientEvent('pvp_inventory:openUIWithOutpost', src, {
            inventory    = inventory,
            money        = money,
            outpostId    = GLOBAL_ID,
            outpostLabel = 'COFFRE AVANT-POSTE',
            outpostItems = outpostItems,
        })
    end)
end)

-- Déposer un item dans le coffre avant-poste (coffre unifié, sans limite de poids)
RegisterNetEvent('pvp_inventory:outpostStashDeposit')
AddEventHandler('pvp_inventory:outpostStashDeposit', function(_, itemName, qty)
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if not isValidItemName(itemName) then return end

    -- Anti race : même lock que le coffre protégé (une seule op coffre à la fois)
    if isStashLocked(xPlayer.identifier) then
        notify(src, 'Opération en cours...', 'info')
        return
    end
    stashLocks[xPlayer.identifier] = os.time()

    local GLOBAL_ID = 'global'
    qty = math.max(1, math.floor(tonumber(qty) or 1))
    local item = xPlayer.getInventoryItem(itemName)
    if not item or item.count < qty then
        stashLocks[xPlayer.identifier] = nil
        notify(src, 'Item indisponible.', 'error')
        return
    end

    -- Pas de vérification de poids : le coffre avant-poste est illimité.
    xPlayer.removeInventoryItem(itemName, qty)
    -- Déséquiper l'arme si elle était en main
    if WEAPONS[itemName] then
        TriggerClientEvent('pvp_inventory:unequipWeapon', src, itemName)
    end
    MySQL.Async.execute(
        [[INSERT INTO pvp_outpost_stash (identifier, outpost_id, item, label, count)
          VALUES (@id, @op, @item, @label, @qty)
          ON DUPLICATE KEY UPDATE count = count + @qty]],
        { ['@id'] = xPlayer.identifier, ['@op'] = GLOBAL_ID, ['@item'] = itemName, ['@label'] = item.label, ['@qty'] = qty },
        function()
            notify(src, item.label .. ' x' .. qty .. ' → coffre avant-poste.', 'success')
            refreshStash(src, xPlayer)
            loadOutpostStash(xPlayer.identifier, GLOBAL_ID, function(items)
                TriggerClientEvent('pvp_inventory:refreshOutpostStash', src, items)
                stashLocks[xPlayer.identifier] = nil
            end)
        end
    )
end)

-- Retirer un item du coffre avant-poste (coffre unifié)
RegisterNetEvent('pvp_inventory:outpostStashWithdraw')
AddEventHandler('pvp_inventory:outpostStashWithdraw', function(_, itemName, qty)
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if not isValidItemName(itemName) then return end

    -- Anti race : empêche un double-clic de retirer 2x la même quantité
    -- (race classique : 2 fetchAll vus count=10 → 2 UPDATE → -20 au lieu de -10 → count<0)
    if isStashLocked(xPlayer.identifier) then
        notify(src, 'Opération en cours...', 'info')
        return
    end
    stashLocks[xPlayer.identifier] = os.time()

    local GLOBAL_ID = 'global'
    qty = math.max(1, math.floor(tonumber(qty) or 1))

    MySQL.Async.fetchAll(
        'SELECT count, label FROM pvp_outpost_stash WHERE identifier = @id AND outpost_id = @op AND item = @item',
        { ['@id'] = xPlayer.identifier, ['@op'] = GLOBAL_ID, ['@item'] = itemName },
        function(rows)
            if not rows[1] or rows[1].count < qty then
                stashLocks[xPlayer.identifier] = nil
                notify(src, 'Pas assez dans le coffre.', 'error')
                return
            end

            local label = rows[1].label
            local newCount = rows[1].count - qty

            -- Vérification poids sac (avec bonus prestige)
            local addWeight = getItemWeight(itemName) * qty
            local effBagMax2 = getEffectiveBagWeight(xPlayer.identifier)
            if getBagWeight(xPlayer) + addWeight > effBagMax2 then
                stashLocks[xPlayer.identifier] = nil
                notify(src, 'Sac trop lourd ! (' .. effBagMax2 .. ' kg max)', 'warning')
                return
            end

            -- Atomic conditional update (WHERE count >= qty) pour éviter la race
            -- si un autre chemin a touché la ligne entre fetch et update.
            local sql, params
            if newCount <= 0 then
                sql = 'DELETE FROM pvp_outpost_stash WHERE identifier = @id AND outpost_id = @op AND item = @item AND count >= @qty'
                params = { ['@id'] = xPlayer.identifier, ['@op'] = GLOBAL_ID, ['@item'] = itemName, ['@qty'] = qty }
            else
                sql = 'UPDATE pvp_outpost_stash SET count = count - @qty WHERE identifier = @id AND outpost_id = @op AND item = @item AND count >= @qty'
                params = { ['@id'] = xPlayer.identifier, ['@op'] = GLOBAL_ID, ['@item'] = itemName, ['@qty'] = qty }
            end
            MySQL.Async.execute(sql, params, function(affected)
                if not affected or affected < 1 then
                    stashLocks[xPlayer.identifier] = nil
                    notify(src, 'Erreur : stock modifié.', 'error')
                    return
                end
                xPlayer.addInventoryItem(itemName, qty)
                notify(src, label .. ' x' .. qty .. ' ← coffre avant-poste.', 'success')
                refreshStash(src, xPlayer)
                loadOutpostStash(xPlayer.identifier, GLOBAL_ID, function(items)
                    TriggerClientEvent('pvp_inventory:refreshOutpostStash', src, items)
                    stashLocks[xPlayer.identifier] = nil
                end)
            end)
        end
    )
end)

-- ══ KIT DE DÉPART ═══════════════════════════════════════════════════════
-- Donné une seule fois par personnage via /kitstart (items normaux, vendables)
local KIT_START_ITEMS = {
    { name = 'weapon_specialcarbine', label = 'Carabine Spéciale', count = 5 },
    { name = 'vehicle_revolter',      label = 'Revolter',          count = 5 },
    { name = 'shot_attract',          label = 'Shot Attracteur',   count = 5 },
}

-- SÉCURITÉ : verrou en mémoire pendant la requête DB. Sans ça, un joueur qui
-- spam /kitstart avant la fin du round-trip MySQL pourrait dupliquer le kit
-- (même exploit que l'ancien giveKit, qui nécessitait un cooldown pour ça).
local kitStartInProgress = {}  -- [identifier] = true pendant la vérification/écriture DB
local kitStartDone       = {}  -- [identifier] = true une fois confirmé (évite un aller-retour DB)

RegisterCommand('kitstart', function(source)
    local src = source
    if src == 0 then return end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local identifier = xPlayer.identifier

    if kitStartDone[identifier] or kitStartInProgress[identifier] then
        notify(src, 'Tu as déjà utilisé ton kit de départ.', 'warning')
        return
    end
    kitStartInProgress[identifier] = true

    MySQL.Async.fetchScalar(
        'SELECT kit_start_used FROM pvp_player_stats WHERE identifier = @id',
        { ['@id'] = identifier },
        function(used)
            if (tonumber(used) or 0) == 1 then
                kitStartInProgress[identifier] = nil
                kitStartDone[identifier] = true
                notify(src, 'Tu as déjà utilisé ton kit de départ.', 'warning')
                return
            end

            for _, kitItem in ipairs(KIT_START_ITEMS) do
                xPlayer.addInventoryItem(kitItem.name, kitItem.count)
            end

            MySQL.Async.execute(
                [[INSERT INTO pvp_player_stats (identifier, kit_start_used) VALUES (@id, 1)
                  ON DUPLICATE KEY UPDATE kit_start_used = 1]],
                { ['@id'] = identifier }
            )

            kitStartInProgress[identifier] = nil
            kitStartDone[identifier] = true
            notify(src, 'Kit de départ reçu : 5x Carabine Spéciale, 5x Revolter, 5x Shot Attracteur !', 'success')
        end
    )
end, false)

-- Nettoyage du verrou si le joueur se déconnecte pendant la requête DB
AddEventHandler('playerDropped', function()
    local src = source
    vehicleSpawnCooldown[src] = nil
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then kitStartInProgress[xPlayer.identifier] = nil end
end)

-- ── Ranger un véhicule (K) → redonner l'item ────────────────────────────
-- SÉCURITÉ : whitelist + tracking du spawn serveur (cf. activeVehicleSpawns
-- déclaré en amont pour être visible depuis useItem).
RegisterNetEvent('pvp_inventory:storeVehicle')
AddEventHandler('pvp_inventory:storeVehicle', function(itemName, itemLabel)
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    -- Validation : itemName doit être une string vehicle_* valide.
    if type(itemName) ~= 'string' then return end
    if not string.match(itemName, '^vehicle_[a-z0-9_]+$') then return end
    if not isValidItemName(itemName) then return end

    -- Il doit y avoir eu au moins un spawn actif de ce véhicule côté serveur.
    -- Empêche un client de forger l'event sans qu'aucun véhicule ne soit spawné.
    if (activeVehicleSpawns[itemName] or 0) <= 0 then return end
    activeVehicleSpawns[itemName] = activeVehicleSpawns[itemName] - 1

    -- Le label est fourni par le client mais n'est utilisé que pour la notif.
    -- On récupère le vrai label depuis ESX si possible pour éviter l'affichage forgé.
    local trueItem = xPlayer.getInventoryItem(itemName)
    local label = (trueItem and trueItem.label) or (type(itemLabel) == 'string' and itemLabel:sub(1, 50)) or itemName

    xPlayer.addInventoryItem(itemName, 1)
    vehicleSpawnCooldown[src] = GetGameTimer() + VEHICLE_RESPAWN_COOLDOWN_MS
    notify(src, label .. ' rangé.', 'success')
    refreshClient(src, xPlayer)
end)

-- ── Refresh data (appelé depuis NUI pour actualiser le marché) ────────────
-- ── Sauvegarde préférence HUD en DB ────────────────────────────────────────
RegisterNetEvent('pvp_inventory:saveHudType')
AddEventHandler('pvp_inventory:saveHudType', function(hudType)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if hudType ~= 'gta' and hudType ~= 'vanta' then return end
    MySQL.Async.execute(
        'UPDATE pvp_player_stats SET hud_type = @h WHERE identifier = @id',
        { ['@id'] = xPlayer.identifier, ['@h'] = hudType }
    )
end)

-- ── Sauvegarde hotbar en DB ────────────────────────────────────────────────
RegisterNetEvent('pvp_inventory:saveHotbar')
AddEventHandler('pvp_inventory:saveHotbar', function(hotbarData)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if type(hotbarData) ~= 'table' then return end

    -- Valider et nettoyer les données hotbar (max 8 slots)
    local clean = {}
    for i = 1, 8 do
        local slot = hotbarData[tostring(i)] or hotbarData[i]
        if slot and type(slot) == 'table' and type(slot.name) == 'string' and type(slot.label) == 'string' then
            clean[tostring(i)] = { name = slot.name, label = slot.label }
        end
    end

    local jsonStr = json.encode(clean)
    MySQL.Async.execute(
        'UPDATE pvp_player_stats SET hotbar = @h WHERE identifier = @id',
        { ['@id'] = xPlayer.identifier, ['@h'] = jsonStr }
    )
end)

-- ── Chargement hotbar depuis la DB ────────────────────────────────────────
function loadHotbar(identifier, cb)
    MySQL.Async.fetchAll(
        'SELECT hotbar FROM pvp_player_stats WHERE identifier = @id',
        { ['@id'] = identifier },
        function(rows)
            if not rows or not rows[1] or not rows[1].hotbar then
                cb({})
                return
            end
            local ok, data = pcall(json.decode, rows[1].hotbar)
            if ok and type(data) == 'table' then
                cb(data)
            else
                cb({})
            end
        end
    )
end

RegisterNetEvent('pvp_inventory:refreshData')
AddEventHandler('pvp_inventory:refreshData', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    refreshClient(src, xPlayer)
end)

-- ── Nettoyage à la déconnexion ────────────────────────────────────────────
AddEventHandler('playerDropped', function()
    local src = source
    -- Nettoyer le lock coffre + streaks
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
        stashLocks[xPlayer.identifier] = nil
        playerStreaks[xPlayer.identifier] = nil
        pedChangeLocks[xPlayer.identifier] = nil
    end
    knownBags[src] = nil
end)

-- ── Sauvegarde du ped model choisi ──────────────────────────────────────
-- Préfixes autorisés par la catalogue client (ped_catalog.js). Couvre les
-- ped freemode, civils, militaires, zombies, animals. Refuse explicitement
-- les hashes "player_zero/one/two" (protagonistes histoire) et tout ce qui
-- ne commence pas par un préfixe GTA valide.
local PED_MODEL_PREFIXES = {
    '^mp_m_', '^mp_f_',        -- multijoueur freemode
    '^a_m_m_', '^a_m_y_', '^a_m_o_',
    '^a_f_m_', '^a_f_y_', '^a_f_o_',
    '^u_m_m_', '^u_m_y_', '^u_m_o_',
    '^u_f_m_', '^u_f_y_',
    '^g_m_m_', '^g_m_y_',
    '^g_f_y_',
    '^s_m_m_', '^s_m_y_', '^s_m_o_',
    '^s_f_m_', '^s_f_y_',
    '^cs_', '^csb_',            -- scripted civilian/story NPCs
    '^ig_',                     -- ig_* event NPCs
    '^hc_',                     -- hardcore NPCs
    '^a_c_',                    -- animals
}
local function isValidPedModel(model)
    if type(model) ~= 'string' then return false end
    if model == '' then return true end                              -- reset autorisé
    if #model < 4 or #model > 64 then return false end
    if not model:match('^[a-z0-9_]+$') then return false end
    -- Blacklist des protagonistes du mode histoire
    if model == 'player_zero' or model == 'player_one' or model == 'player_two' then
        return false
    end
    for _, pattern in ipairs(PED_MODEL_PREFIXES) do
        if model:match(pattern) then return true end
    end
    return false
end

-- ── Tiers de peds : parsés depuis le MÊME fichier que celui servi au NUI ──
-- (html/ped_catalog.js) via LoadResourceFile, pour qu'il n'existe jamais
-- qu'une seule source de vérité model→tier. Si le parsing échoue ou renvoie
-- un nombre de peds anormalement bas, on passe en fail-safe : tout ped
-- non-freemode est refusé plutôt que de risquer d'ouvrir la vanne.
local PED_TIER = {}
local PED_CAT  = {}
local pedCatalogSafe = false

Citizen.CreateThread(function()
    local content = LoadResourceFile(GetCurrentResourceName(), 'html/ped_catalog.js')
    if not content then
        print('^1[pvp_inventory] ped_catalog.js introuvable — fail-safe : changement de ped désactivé^0')
        return
    end

    local count = 0
    for model, cat, tier in content:gmatch('model:%s*"([%w_]+)".-cat:%s*"(%a+)".-tier:%s*"(%a+)"') do
        PED_TIER[model] = tier
        PED_CAT[model]  = cat
        count = count + 1
    end

    if count < 500 then
        PED_TIER = {}
        PED_CAT  = {}
        print(('^1[pvp_inventory] catalogue de peds parsé de façon suspecte (%d entrées) — fail-safe activé^0'):format(count))
        return
    end

    pedCatalogSafe = true
end)

exports('GetPedTier', function(model)
    return PED_TIER[model]
end)

exports('IsPedInCatalog', function(model)
    return PED_TIER[model] ~= nil
end)

-- Consommé par pvp_character à la création : n'importe quel ped humain du
-- catalogue est autorisé (peu importe le tier — choix libre et unique), mais
-- les animaux et l'entrée "freemode" (qui a sa propre branche dédiée) sont
-- exclus d'un choix de personnage PVP permanent.
exports('IsPedCreationEligible', function(model)
    local cat = PED_CAT[model]
    return cat ~= nil and cat ~= 'animal' and cat ~= 'freemode'
end)

RegisterNetEvent('pvp_inventory:savePedModel')
AddEventHandler('pvp_inventory:savePedModel', function(model)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    if pedChangeLocks[xPlayer.identifier] then return end
    pedChangeLocks[xPlayer.identifier] = true

    if not isValidPedModel(model) then
        pedChangeLocks[xPlayer.identifier] = nil
        return
    end

    -- SÉCURITÉ : le changement de ped après création est réservé aux abonnés
    -- Gold/Diamond (le choix fait à la création, lui, est libre et unique —
    -- géré par pvp_character, pas ici). Sans ce contrôle serveur, un client
    -- modifié pouvait appeler cet event directement et changer de ped sans
    -- aucun abonnement : le filtre par tier n'existait qu'en JS côté NUI.
    local tier = 'none'
    pcall(function()
        tier = exports['pvp_vcoins']:GetTier(xPlayer.identifier) or 'none'
    end)

    if tier ~= 'gold' and tier ~= 'diamond' then
        pedChangeLocks[xPlayer.identifier] = nil
        TriggerClientEvent('esx:showNotification', src, '~r~Changement de ped réservé aux abonnés Gold / Diamond')
        TriggerClientEvent('pvp_inventory:pedModelRejected', src)
        return
    end

    -- Reset vers freemode = aussi un changement de ped, soumis au même gate
    -- d'abonnement (sinon un joueur sans sub pourrait "revenir" en freemode
    -- depuis un ped spécial choisi à la création).
    if model ~= '' then
        if not pedCatalogSafe then
            pedChangeLocks[xPlayer.identifier] = nil
            TriggerClientEvent('esx:showNotification', src, '~r~Catalogue de peds indisponible, réessaie plus tard')
            TriggerClientEvent('pvp_inventory:pedModelRejected', src)
            return
        end
        local pedTier = PED_TIER[model]
        if not pedTier or (pedTier == 'diamond' and tier ~= 'diamond') then
            pedChangeLocks[xPlayer.identifier] = nil
            TriggerClientEvent('esx:showNotification', src, '~r~Ce ped nécessite un abonnement Diamond')
            TriggerClientEvent('pvp_inventory:pedModelRejected', src)
            return
        end
    end

    MySQL.Async.execute(
        'UPDATE pvp_player_stats SET ped_model = @m WHERE identifier = @id',
        { ['@m'] = model, ['@id'] = xPlayer.identifier },
        function()
            pedChangeLocks[xPlayer.identifier] = nil
        end
    )
end)

-- ── Refresh cross-resource (appelé par pvp_market après vente/achat) ──────
AddEventHandler('pvp_inventory:refreshClient', function(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    refreshClient(src, xPlayer)
end)

-- ── Badge actif : le joueur choisit son badge affiché ─────────────────────
local VALID_BADGES = {
    survivor_s1=true, survivor_s2=true, survivor_s3=true,
    first_blood=true, killer_10=true, killer_50=true, predator_100=true,
    zombie_hunter=true, exterminator=true, annihilator=true,
    streak_5=true, unstoppable=true,
    gold_member=true, diamond_member=true,
    prestige_1=true, prestige_2=true, prestige_3=true, prestige_4=true, prestige_5=true,
}

RegisterNetEvent('pvp_inventory:setActiveBadge')
AddEventHandler('pvp_inventory:setActiveBadge', function(badgeId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if type(badgeId) ~= 'string' then return end
    -- badgeId = '' pour retirer le badge
    if badgeId == '' then
        MySQL.Async.execute(
            "UPDATE pvp_player_stats SET active_badge = '' WHERE identifier = @id",
            { ['@id'] = xPlayer.identifier }
        )
        return
    end
    -- Valider que le badgeId existe dans les badges connus
    if not VALID_BADGES[badgeId] then return end
    -- Valider que le badge est bien débloqué
    MySQL.Async.fetchAll(
        'SELECT badges_unlocked FROM pvp_player_stats WHERE identifier = @id',
        { ['@id'] = xPlayer.identifier },
        function(rows)
            local current = rows and rows[1] and rows[1].badges_unlocked or '[]'
            local ok, badges = pcall(json.decode, current)
            if not ok or type(badges) ~= 'table' then return end
            local found = false
            for _, b in ipairs(badges) do
                if b == badgeId then found = true; break end
            end
            if found then
                MySQL.Async.execute(
                    'UPDATE pvp_player_stats SET active_badge = @b WHERE identifier = @id',
                    { ['@id'] = xPlayer.identifier, ['@b'] = badgeId }
                )
            end
        end
    )
end)

-- ── Appliquer la préférence HUD au login (avant ouverture inventaire) ─────
AddEventHandler('esx:playerLoaded', function(playerId)
    local src = type(playerId) == 'number' and playerId or source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local identifier = xPlayer.identifier
    local displayName = getDisplayNameFromPlayer(xPlayer)
    -- Upsert stats au login (une seule fois, pas à chaque TAB)
    upsertPlayerStats(identifier, displayName, 0, 0, 0)
    MySQL.Async.fetchAll(
        [[SELECT COALESCE(hud_type, 'gta') AS hud_type,
                 COALESCE(kills, 0) AS kills,
                 COALESCE(zombies_killed, 0) AS zombies_killed
          FROM pvp_player_stats WHERE identifier = @id]],
        { ['@id'] = identifier },
        function(rows)
            local row = rows and rows[1]
            local pref = row and row.hud_type or 'gta'
            TriggerClientEvent('pvp_inventory:setHudPreference', src, pref)
            -- Badge de saison + vérification globale au login uniquement
            local kills   = row and tonumber(row.kills) or 0
            local zombies = row and tonumber(row.zombies_killed) or 0
            if kills + zombies > 0 then
                unlockBadge(identifier, 'survivor_s' .. CURRENT_SEASON)
            end
            checkAllBadges(identifier, {
                kills   = kills,
                zombies = zombies,
                streak  = playerStreaks[identifier] or 0,
            })
        end
    )
end)
