-- =============================================
--   PVP ZOMBIES - Configuration
-- =============================================

Config = {}

-- Max zombies actifs autour d'un joueur
Config.MaxZombiesPerPlayer  = 40

-- Distance de spawn (min/max autour du joueur)
Config.SpawnRadiusMin       = 15.0
Config.SpawnRadiusMax       = 40.0

-- Distance au-delà de laquelle un zombie (ou son cadavre non-fouillé) est supprimé
Config.DespawnRadius        = 120.0

-- Fréquence de spawn (ms) - toutes les 8s on tente de spawner
Config.SpawnInterval        = 8000

-- Fréquence de check des zombies morts (ms)
Config.UpdateInterval       = 500

-- Distance (m) à laquelle le prompt "[E] Fouiller" apparaît sur un cadavre
Config.LootPromptRadius     = 3.0

-- Ne pas spawner dans les zones safe des avant-postes
Config.RespectSafeZones     = true

-- Buffer supplémentaire autour de la safe zone (en mètres)
-- Les zombies ne peuvent pas spawner à moins de (safeRadius + Buffer) d'un avant-poste
-- Les zombies qui entrent dans (safeRadius) sont automatiquement supprimés
Config.SafeZoneBuffer       = 40.0

-- ── Zones d'exclusion (copie des coords avant-postes + rayon no-spawn) ───────
-- noSpawnRadius = safeRadius de l'avant-poste + Config.SafeZoneBuffer
-- killRadius    = safeRadius de l'avant-poste (suppression auto des zombies intrusifs)
Config.ExclusionZones = {
    { coords = vector3(1153.0, -1520.0, 35.0),   noSpawnRadius = 140.0, killRadius = 100.0 }, -- murietta_base
    { coords = vector3(1130.0, -289.0,  69.5),   noSpawnRadius = 140.0, killRadius = 100.0 }, -- zancudo_base
    { coords = vector3(-1049.9, -2020.0, 13.2),  noSpawnRadius = 100.0, killRadius = 60.0  }, -- ls_armory
    { coords = vector3(-1269.0, -1360.0, 4.2),   noSpawnRadius = 100.0, killRadius = 60.0  }, -- vespucci_camp
    { coords = vector3(-518.0,  -990.0,  23.4),  noSpawnRadius = 100.0, killRadius = 60.0  }, -- ls_camp
    { coords = vector3(-1545.0, -408.0,  42.0),  noSpawnRadius = 100.0, killRadius = 60.0  }, -- west_ls_camp
    { coords = vector3(-430.0,  1122.0,  325.9), noSpawnRadius = 100.0, killRadius = 60.0  }, -- mountain_camp
    { coords = vector3(-1153.0, 2678.0,  18.1),  noSpawnRadius = 100.0, killRadius = 60.0  }, -- route68_camp
    { coords = vector3(1220.0,  1842.0,  79.2),  noSpawnRadius = 100.0, killRadius = 60.0  }, -- grand_senora_camp
    { coords = vector3(2755.0,  3456.0,  55.9),  noSpawnRadius = 100.0, killRadius = 60.0  }, -- grapeseed_camp
    { coords = vector3(1965.0,  5164.0,  47.5),  noSpawnRadius = 100.0, killRadius = 60.0  }, -- grapeseed_north_camp
    { coords = vector3(-675.0,  5786.0,  17.3),  noSpawnRadius = 100.0, killRadius = 60.0  }, -- paleto_camp
}

-- ── Type de zombie unique ───────────────────────────────────────────────────
Config.ZombieType = {
    label       = 'Zombie',
    models      = {
        'u_m_y_zombie_01',
    },
    health      = 200,
    moveClipset = 'move_m@drunk@verydrunk',
    speed       = 1.0,
    damage      = 15, -- documentaire uniquement : le dégât réel vient du combo anim + WEAPON_UNARMED géré par GTA
    reward      = { min = 20, max = 60 },
}

-- ══════════════════════════════════════════════════════════════════════════
--  TABLE DE LOOT — 1 item par zombie, tirage pondéré
--
--  Taux d'apparition cibles par catégorie (rééquilibrage prix, cf CLAUDE.md) :
--  Très Commun   ~88%   Soins, Shots repel/attract, Pistols, SMG, Molotov
--  Commun        ~9.2%  AK47, Carabine, Carabine Spécial
--  Rare          ~2.2%  Kevlar, Shot vitesse/santé, MK2 fusils, M60, Mitrailleuse,
--                       Pistolet paralysant + Véhicules rares
--  Épic          ~0.46% Fusil précision, Lance-grenades, M60 MK2, Mousquet + Véhicules épic
--  Légendaire   ~0.013% Munitions Sniper, Snipers, RPG, Lance-missiles + Véhicules légendaires
--
--  Kevlar / Shot vitesse / Shot santé / Munitions Sniper ont été déplacés hors de
--  "très commun" lors du rééquilibrage prix (20 000$ / 10 000$ / 10 000$ / 80 000$
--  à l'achat) — leur rareté doit rester cohérente avec leur valeur.
--
--  Total poids ≈ 8665 → taux réels :
--    Très Commun : 7633   /8665 = 88.09% ✓
--    Commun      :  800   /8665 =  9.23% ✓
--    Rare        :  191   /8665 =  2.20% ✓
--    Épic        :   40   /8665 =  0.46% ✓
--    Légendaire  :    1.15/8665 =  0.013% ✓
--
--  `category` sert au boost redzone : en redzone, tout ce qui n'est PAS
--  'tres_commun' voit son poids multiplié (voir server.lua / rollLoot).
-- ══════════════════════════════════════════════════════════════════════════
Config.LootTable = {
    -- ══ TRÈS COMMUN (≈ 90%) — jamais boosté en redzone ═══════════════════

    -- Soins
    { item = 'bandage',                  chance = 1642, count = 1, category = 'tres_commun' },
    { item = 'medkit',                   chance = 876,  count = 1, category = 'tres_commun' },
    -- Shots courants (repel/attract — prix modeste, reste très commun)
    { item = 'shot_repel',               chance = 438,  count = 1, category = 'tres_commun' },
    { item = 'shot_attract',             chance = 328,  count = 1, category = 'tres_commun' },
    -- Pistols + Molotov
    { item = 'weapon_molotov',           chance = 274,  count = 1, category = 'tres_commun' },
    { item = 'weapon_appistol',          chance = 328,  count = 1, category = 'tres_commun' },
    { item = 'weapon_pistol',            chance = 383,  count = 1, category = 'tres_commun' },
    { item = 'weapon_pistol_mk2',        chance = 307,  count = 1, category = 'tres_commun' },
    { item = 'weapon_snspistol',         chance = 350,  count = 1, category = 'tres_commun' },
    { item = 'weapon_snspistol_mk2',     chance = 274,  count = 1, category = 'tres_commun' },
    { item = 'weapon_vintagepistol',     chance = 296,  count = 1, category = 'tres_commun' },
    { item = 'weapon_combatpistol',      chance = 296,  count = 1, category = 'tres_commun' },
    { item = 'weapon_heavypistol',       chance = 274,  count = 1, category = 'tres_commun' },
    -- SMG
    { item = 'weapon_microsmg',          chance = 318,  count = 1, category = 'tres_commun' },
    { item = 'weapon_minismg',           chance = 318,  count = 1, category = 'tres_commun' },
    { item = 'weapon_smg',               chance = 328,  count = 1, category = 'tres_commun' },
    { item = 'weapon_smg_mk2',           chance = 296,  count = 1, category = 'tres_commun' },
    { item = 'weapon_machinepistol',     chance = 307,  count = 1, category = 'tres_commun' },

    -- ══ COMMUN (≈ 8%) ═══════════════════════════════════════════════════
    { item = 'weapon_assaultrifle',      chance = 267,  count = 1, category = 'commun' },
    { item = 'weapon_carbinerifle',      chance = 267,  count = 1, category = 'commun' },
    { item = 'weapon_specialcarbine',    chance = 266,  count = 1, category = 'commun' },

    -- ══ RARE (≈ 1.5%) ═══════════════════════════════════════════════════
    -- Équipement premium (prix élevé en boutique → rendu rare ici)
    { item = 'kevlar',                   chance = 8,    count = 1, category = 'rare' },
    { item = 'shot_speed',               chance = 16,   count = 1, category = 'rare' },
    { item = 'shot_health',              chance = 16,   count = 1, category = 'rare' },
    { item = 'weapon_assaultrifle_mk2',  chance = 13,   count = 1, category = 'rare' },
    { item = 'weapon_carbinerifle_mk2',  chance = 13,   count = 1, category = 'rare' },
    { item = 'weapon_specialcarbine_mk2',chance = 12,   count = 1, category = 'rare' },
    { item = 'weapon_stungun',           chance = 8,    count = 1, category = 'rare' },
    { item = 'weapon_combatmg',          chance = 13,   count = 1, category = 'rare' },
    { item = 'weapon_mg',                chance = 12,   count = 1, category = 'rare' },
    -- Véhicules rares
    { item = 'vehicle_ztype',            chance = 12,   count = 1, category = 'rare' },
    { item = 'vehicle_mule',             chance = 13,   count = 1, category = 'rare' },
    { item = 'vehicle_blazer5',          chance = 12,   count = 1, category = 'rare' },
    { item = 'vehicle_dominator4',       chance = 11,   count = 1, category = 'rare' },
    { item = 'vehicle_revolter',         chance = 11,   count = 1, category = 'rare' },
    { item = 'vehicle_microlight',       chance = 11,   count = 1, category = 'rare' },  -- "Ultralight" en jeu, spawn code = microlight
    { item = 'vehicle_speedo2',          chance = 10,   count = 1, category = 'rare' },

    -- ══ ÉPIC (≈ 0.4%) ═══════════════════════════════════════════════════
    { item = 'weapon_precisionrifle',    chance = 2.42, count = 1, category = 'epic' },
    { item = 'weapon_compactlauncher',   chance = 2.02, count = 1, category = 'epic' },
    { item = 'weapon_emplauncher',       chance = 2.02, count = 1, category = 'epic' },
    { item = 'weapon_combatmg_mk2',      chance = 2.42, count = 1, category = 'epic' },
    { item = 'weapon_musket',            chance = 2.02, count = 1, category = 'epic' },
    -- Véhicules épic
    { item = 'vehicle_schafter5',        chance = 2.42, count = 1, category = 'epic' },
    { item = 'vehicle_baller6',          chance = 2.42, count = 1, category = 'epic' },
    { item = 'vehicle_xls2',             chance = 2.02, count = 1, category = 'epic' },
    { item = 'vehicle_voltic2',          chance = 2.02, count = 1, category = 'epic' },
    { item = 'vehicle_cerberus',         chance = 2.42, count = 1, category = 'epic' },
    { item = 'vehicle_zr380',            chance = 2.42, count = 1, category = 'epic' },
    { item = 'vehicle_cog552',           chance = 2.02, count = 1, category = 'epic' },
    { item = 'vehicle_sasquatch',        chance = 2.02, count = 1, category = 'epic' },
    { item = 'vehicle_thruster',         chance = 1.62, count = 1, category = 'epic' },
    { item = 'vehicle_vigilante',        chance = 2.42, count = 1, category = 'epic' },
    { item = 'vehicle_buzzard2',         chance = 2.42, count = 1, category = 'epic' },
    { item = 'vehicle_maverick',         chance = 2.83, count = 1, category = 'epic' },
    { item = 'vehicle_havok',            chance = 2.02, count = 1, category = 'epic' },

    -- ══ LÉGENDAIRE (≈ 0.01%) ════════════════════════════════════════════
    -- Munitions Sniper (80 000$ à l'achat — aussi rare qu'une arme légendaire)
    { item = 'ammo_sniper',              chance = 0.15,  count = 1, category = 'legendaire' },
    { item = 'weapon_sniperrifle',       chance = 0.183, count = 1, category = 'legendaire' },
    { item = 'weapon_marksmanrifle_mk2', chance = 0.146, count = 1, category = 'legendaire' },
    -- weapon_heavysniper (AWP) et weapon_heavysniper_mk2 (AWP MK2)
    -- → droppables uniquement dans les caisses de ravitaillement (pvp_drops)
    { item = 'weapon_rpg',               chance = 0.122, count = 1, category = 'legendaire' },
    { item = 'weapon_hominglauncher',    chance = 0.061, count = 1, category = 'legendaire' },
    -- Véhicules légendaires
    { item = 'vehicle_deluxo',           chance = 0.085, count = 1, category = 'legendaire' },
    { item = 'vehicle_oppressor2',       chance = 0.061, count = 1, category = 'legendaire' },
    { item = 'vehicle_nightshark',       chance = 0.098, count = 1, category = 'legendaire' },
    { item = 'vehicle_scarab',           chance = 0.073, count = 1, category = 'legendaire' },
    { item = 'vehicle_insurgent3',       chance = 0.085, count = 1, category = 'legendaire' },
    { item = 'vehicle_dukes2',           chance = 0.085, count = 1, category = 'legendaire' },
}
