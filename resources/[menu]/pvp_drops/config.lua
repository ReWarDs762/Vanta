-- =============================================
--   PVP DROPS - Configuration
-- =============================================

Config = {}

-- Intervalle entre chaque drop (ms)
Config.DropInterval = 120 * 60 * 1000   -- toutes les 2h

-- Délai avant le 1er drop au démarrage du serveur (ms)
Config.FirstDropDelay = 10 * 60 * 1000  -- 10 min après démarrage

-- Temps d'approche de l'avion avant le largage (ms)
Config.ApproachTime = 45 * 1000         -- 45 secondes

-- Durée de chute de la caisse (ms)
Config.FallDuration = 5 * 60 * 1000     -- 5 minutes

-- Délai avant ouverture après atterrissage (ms)
Config.OpenDelay = 5 * 60 * 1000        -- 5 minutes

-- Durée de vie totale d'un drop, du largage à sa disparition (ms).
-- Passé ce délai la caisse est retirée même si elle n'a pas été vidée, et tous
-- les clients sont notifiés (sinon blips/caisse restaient affichés côté client
-- pour un drop déjà supprimé côté serveur).
-- Timeline : approche 45s + chute 5min + sécurisation 5min ≈ 11min avant
-- ouverture → il reste ~49min de disponibilité réelle sur 1h.
Config.DropLifetime = 60 * 60 * 1000    -- 1 heure

-- Altitude de départ de la caisse (mètres au-dessus du sol)
Config.DropAltitude = 450.0

-- Distance depuis la zone de drop où l'avion spawn (mètres)
Config.PlaneStartDistance = 3000.0

-- Rayon d'interaction pour ouvrir la caisse (mètres)
Config.InteractRadius = 4.0

-- ── Atterrissage : détection de collision ────────────────────────────────
-- La caisse s'arrête au PREMIER contact (toit de bâtiment, montagne, sol...).
-- Hauteur depuis laquelle part le raycast vertical de recherche de surface.
Config.LandingProbeTop    = 1500.0
-- Profondeur maximale sondée sous la zone (sous le niveau de la mer)
Config.LandingProbeBottom = -250.0
-- Ré-sondage pendant la chute (ms) : la collision peut arriver en streaming
-- après le largage, on réévalue la surface d'impact en continu.
Config.LandingRefreshMs   = 400
-- Distance sondée sous la caisse pendant la chute (mètres)
Config.LandingLookAhead   = 60.0

-- ── Trajectoire : flèches rouges sur la carte ────────────────────────────
Config.Trail = {
    enabled  = true,

    -- Texture de la flèche (déclarée dans fxmanifest > files).
    -- La flèche pointe vers le HAUT dans l'image : la rotation appliquée
    -- correspond donc directement au cap à l'écran.
    texture  = 'html/img/arrow.png',

    spacing  = 55.0,    -- distance en mètres entre 2 flèches sur la trajectoire
    scrollSpeed = 14.0, -- défilement des flèches vers le point de largage (m/s, 0 = fixe)
    size     = 0.030,   -- taille de la flèche (fraction de la hauteur d'écran)
    tint     = { 255, 255, 255 },  -- teinte (la texture est déjà rouge)
    alpha    = 235,

    -- Portée monde couverte par la HAUTEUR de la minimap, en mètres.
    -- ⚠ À calibrer en jeu si les flèches défilent trop vite/trop lentement :
    --   flèches trop espacées / trop rapides  → augmenter la valeur
    --   flèches trop tassées / trop lentes    → diminuer la valeur
    minimapRange = 260.0,
    bigmapRange  = 900.0,   -- idem quand la minimap est agrandie (bigmap)

    -- Décalage de rotation en degrés (0 = flèche pointant vers le haut)
    rotationOffset = 0.0,

    -- La grande carte (pause) est rendue par le moteur : impossible d'y
    -- injecter une texture custom. On y trace donc la trajectoire avec des
    -- petits blips rouges, UNIQUEMENT pendant que la carte est ouverte.
    pauseMapBlips = true,
    pauseMapSpacing = 300.0,
}

-- ── Mode test (commande /droptest fast) ──────────────────────────────────
Config.TestTimers = {
    approachTime = 10 * 1000,
    fallDuration = 15 * 1000,
    openDelay    = 10 * 1000,
    altitude     = 150.0,
    planeStartDistance = 800.0,
}

-- Groupes ESX autorisés sur /droptest et /dropadmin
Config.AdminGroups = { admin = true, superadmin = true }

-- Modèle de l'avion
Config.PlaneModel = 'cargoplane'

-- Modèle de la caisse
Config.CrateModel = 'prop_mil_crate_01'

-- ── Fusées éclairantes autour de la caisse posée ─────────────────────────
Config.FlareModel   = 'prop_flare_01'   -- prop de fusée éclairante
Config.FlareCount   = 6                 -- nombre de fusées en cercle
Config.FlareRadius  = 4.5               -- rayon du cercle (mètres)
Config.FlarePtfxDict = 'core'           -- dictionnaire de particules
Config.FlarePtfxName = 'exp_grd_flare'  -- effet de flamme/fumée rouge
Config.FlareSoundSet = 'FBI_05_SOUNDS'  -- soundset contenant le son de flare
Config.FlareSoundName = 'Flare'         -- son d'allumage joué à l'atterrissage
Config.FlareSoundRange = 80             -- portée du son (mètres)

-- ── Zones de drop (avec Z au sol précis) ─────────────────────────────────
Config.DropZones = {
    { x =  929.0,   y =   47.0,   z =  81.0, label = 'Casino' },
    { x = -1300.0,  y = -2900.0,  z =  14.0, label = 'Aéroport LSIA' },
    { x =  1748.0,  y =  3300.0,  z =  41.0, label = 'Sandy Shores Airfield' },
    { x =  1635.0,  y =  2519.0,  z =  45.0, label = 'Prison' },
    { x =  3619.0,  y =  3741.0,  z =  28.0, label = 'Humane Labs' },
    { x =   600.0,  y = -2800.0,  z =   6.0, label = 'Port Elysian' },
    { x =   250.0,  y =  -700.0,  z =  35.0, label = 'Downtown LS' },
    { x =  -290.0,  y = -2000.0,  z =  22.0, label = 'Maze Bank Arena' },
    { x = -2180.0,  y =  3215.0,  z =  32.0, label = 'Fort Zancudo' },
    { x =  1850.0,  y =  3700.0,  z =  32.0, label = 'Sandy Shores' },
    { x =  -300.0,  y =  6250.0,  z =  31.0, label = 'Paleto Bay' },
    { x =   100.0,  y = -1700.0,  z =  30.0, label = 'Davis' },
}

-- ── Loot de la caisse de ravitaillement ──────────────────────────────────
-- Uniquement catégories Légendaire et Épic
-- 1 seul item tiré par caisse (revu le 25/08/2026 — auparavant 3)
Config.LootCount = 1

-- NOTE BALANCE : les chances sont pondérées entre elles (pas des %).
-- Légendaire total 54, Épic total 229 → ratio ~81% épic, ~19% légendaire.
-- Ajuster si inflation observée : réduire chances ou augmenter DropInterval.
Config.LootTable = {
    -- ══ LÉGENDAIRE (chances réduites pour limiter l'inflation) ═══════════
    -- Armes légendaires
    { item = 'weapon_heavysniper',       chance = 5,  count = 1 },  -- AWP (drop exclusif)
    { item = 'weapon_heavysniper_mk2',   chance = 3,  count = 1 },  -- AWP MK2 (drop exclusif)
    { item = 'weapon_sniperrifle',       chance = 8,  count = 1 },
    { item = 'weapon_marksmanrifle_mk2', chance = 7,  count = 1 },
    { item = 'weapon_rpg',               chance = 4,  count = 1 },
    { item = 'weapon_hominglauncher',    chance = 3,  count = 1 },
    -- Véhicules légendaires
    { item = 'vehicle_deluxo',           chance = 3,  count = 1 },
    { item = 'vehicle_oppressor2',       chance = 2,  count = 1 },
    { item = 'vehicle_nightshark',       chance = 5,  count = 1 },
    { item = 'vehicle_scarab',           chance = 4,  count = 1 },
    { item = 'vehicle_insurgent3',       chance = 5,  count = 1 },
    { item = 'vehicle_dukes2',           chance = 5,  count = 1 },

    -- ══ ÉPIC ══════════════════════════════════════════════════════════════
    -- Armes épic
    { item = 'weapon_precisionrifle',    chance = 25, count = 1 },
    { item = 'weapon_compactlauncher',   chance = 20, count = 1 },
    { item = 'weapon_emplauncher',       chance = 20, count = 1 },
    { item = 'weapon_combatmg_mk2',      chance = 25, count = 1 },
    { item = 'weapon_musket',            chance = 22, count = 1 },
    -- Véhicules épic
    -- Retirés le 25/08/2026 : vehicle_maverick, vehicle_schafter5,
    -- vehicle_baller6, vehicle_buzzard2, vehicle_xls2, vehicle_cog552,
    -- vehicle_havok — restent disponibles ailleurs (zombies/marché), juste
    -- plus tirables dans une caisse de ravitaillement.
    { item = 'vehicle_voltic2',          chance = 18, count = 1 },
    { item = 'vehicle_cerberus',         chance = 22, count = 1 },
    { item = 'vehicle_zr380',            chance = 22, count = 1 },
    { item = 'vehicle_sasquatch',        chance = 18, count = 1 },
    { item = 'vehicle_thruster',         chance = 15, count = 1 },
    { item = 'vehicle_vigilante',        chance = 22, count = 1 },
}
