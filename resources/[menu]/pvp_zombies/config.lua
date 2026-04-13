-- =============================================
--   PVP ZOMBIES - Configuration
-- =============================================

Config = {}

-- Max zombies actifs autour d'un joueur
Config.MaxZombiesPerPlayer  = 12

-- Distance de spawn (min/max autour du joueur)
Config.SpawnRadiusMin       = 40.0
Config.SpawnRadiusMax       = 80.0

-- Distance au-delà de laquelle un zombie est supprimé
Config.DespawnRadius        = 120.0

-- Fréquence de spawn (ms) - toutes les 8s on tente de spawner
Config.SpawnInterval        = 8000

-- Fréquence de check des zombies morts (ms)
Config.UpdateInterval       = 500

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
        'u_m_y_corpse_01',
        'a_m_m_tramp_01',
        'a_f_m_tramp_01',
        'u_m_y_militarybum',
        'a_m_m_fatbla_01',
        's_m_y_prisoner_01',
    },
    health      = 200,
    moveClipset = 'move_m@drunk@verydrunk',
    speed       = 1.0,
    damage      = 15,
    reward      = { min = 20, max = 60 },
}

-- ══════════════════════════════════════════════════════════════════════════
--  TABLE DE LOOT — 1 item par zombie, tirage pondéré
--
--  Taux d'apparition exacts par catégorie :
--  Légendaire   0.01%   Snipers, RPG, Lance-missiles + Véhicules légendaires
--  Épic          0.5%   Fusil précision, Lance-grenades, M60 MK2, Mousquet + Véhicules épic
--  Rare          1.5%   MK2 fusils, M60, Mitrailleuse, Pistolet paralysant + Véhicules rares
--  Commun         15%   AK47, Carabine, Carabine Spécial
--  Très Commun  ~83%   Pistols, SMG, Molotov + Soins + Shots
-- ══════════════════════════════════════════════════════════════════════════

-- ── Calcul des chance values ───────────────────────────────────────────────
-- Total poids ≈ 9922 → taux réels :
--   Légendaire  :   1.00 /9922 = 0.0101%  ✓
--   Épic        :  50.00 /9922 = 0.504%   ✓
--   Rare        : 151.00 /9922 = 1.52%    ✓
--   Commun      : 1500   /9922 = 15.1%    ✓
--   TC+soins+shots: 8220 /9922 = 82.8%    ✓
Config.LootTable = {
    -- ══ TRÈS COMMUN + SOINS + SHOTS (≈ 82.8%) ══════════════════════════

    -- Soins
    { item = 'bandage',                  chance = 1500, count = 1 },
    { item = 'medkit',                   chance = 800,  count = 1 },
    { item = 'kevlar',                   chance = 500,  count = 1 },
    -- Shots
    { item = 'shot_repel',               chance = 400,  count = 1 },
    { item = 'shot_attract',             chance = 300,  count = 1 },
    { item = 'shot_speed',               chance = 400,  count = 1 },
    { item = 'shot_health',              chance = 350,  count = 1 },
    -- Pistols + Molotov
    { item = 'weapon_molotov',           chance = 250,  count = 1 },
    { item = 'weapon_appistol',          chance = 300,  count = 1 },
    { item = 'weapon_pistol',            chance = 350,  count = 1 },
    { item = 'weapon_pistol_mk2',        chance = 280,  count = 1 },
    { item = 'weapon_snspistol',         chance = 320,  count = 1 },
    { item = 'weapon_snspistol_mk2',     chance = 250,  count = 1 },
    { item = 'weapon_vintagepistol',     chance = 270,  count = 1 },
    { item = 'weapon_combatpistol',      chance = 270,  count = 1 },
    { item = 'weapon_heavypistol',       chance = 250,  count = 1 },
    -- SMG
    { item = 'weapon_microsmg',          chance = 290,  count = 1 },
    { item = 'weapon_minismg',           chance = 290,  count = 1 },
    { item = 'weapon_smg',              chance = 300,  count = 1 },
    { item = 'weapon_smg_mk2',           chance = 270,  count = 1 },
    { item = 'weapon_machinepistol',     chance = 280,  count = 1 },

    -- ══ COMMUN (≈ 15%) ══════════════════════════════════════════════════
    { item = 'weapon_assaultrifle',      chance = 500,  count = 1 },
    { item = 'weapon_carbinerifle',      chance = 500,  count = 1 },
    { item = 'weapon_specialcarbine',    chance = 500,  count = 1 },

    -- ══ RARE (≈ 1.5%) ═══════════════════════════════════════════════════
    { item = 'weapon_assaultrifle_mk2',  chance = 13,   count = 1 },
    { item = 'weapon_carbinerifle_mk2',  chance = 13,   count = 1 },
    { item = 'weapon_specialcarbine_mk2',chance = 12,   count = 1 },
    { item = 'weapon_stungun',           chance = 8,    count = 1 },
    { item = 'weapon_combatmg',          chance = 13,   count = 1 },
    { item = 'weapon_mg',                chance = 12,   count = 1 },
    -- Véhicules rares
    { item = 'vehicle_ztype',            chance = 12,   count = 1 },
    { item = 'vehicle_mule',             chance = 13,   count = 1 },
    { item = 'vehicle_blazer5',          chance = 12,   count = 1 },
    { item = 'vehicle_dominator4',       chance = 11,   count = 1 },
    { item = 'vehicle_revolter',         chance = 11,   count = 1 },
    { item = 'vehicle_ultralight',       chance = 11,   count = 1 },
    { item = 'vehicle_speedo2',          chance = 10,   count = 1 },

    -- ══ ÉPIC (≈ 0.5%) ═══════════════════════════════════════════════════
    { item = 'weapon_precisionrifle',    chance = 3,    count = 1 },
    { item = 'weapon_compactlauncher',   chance = 2.5,  count = 1 },
    { item = 'weapon_emplauncher',       chance = 2.5,  count = 1 },
    { item = 'weapon_combatmg_mk2',      chance = 3,    count = 1 },
    { item = 'weapon_musket',            chance = 2.5,  count = 1 },
    -- Véhicules épic
    { item = 'vehicle_schafter5',        chance = 3,    count = 1 },
    { item = 'vehicle_baller6',          chance = 3,    count = 1 },
    { item = 'vehicle_xls2',             chance = 2.5,  count = 1 },
    { item = 'vehicle_voltic2',          chance = 2.5,  count = 1 },
    { item = 'vehicle_cerberus',         chance = 3,    count = 1 },
    { item = 'vehicle_zr380',            chance = 3,    count = 1 },
    { item = 'vehicle_cog552',           chance = 2.5,  count = 1 },
    { item = 'vehicle_sasquatch',        chance = 2.5,  count = 1 },
    { item = 'vehicle_thruster',         chance = 2,    count = 1 },
    { item = 'vehicle_vigilante',        chance = 3,    count = 1 },
    { item = 'vehicle_buzzard2',         chance = 3,    count = 1 },
    { item = 'vehicle_maverick',         chance = 3.5,  count = 1 },
    { item = 'vehicle_havok',            chance = 2.5,  count = 1 },

    -- ══ LÉGENDAIRE (≈ 0.01%) ════════════════════════════════════════════
    { item = 'weapon_sniperrifle',       chance = 0.15, count = 1 },
    { item = 'weapon_marksmanrifle_mk2', chance = 0.12, count = 1 },
    -- weapon_heavysniper (AWP) et weapon_heavysniper_mk2 (AWP MK2)
    -- → droppables uniquement dans les caisses de ravitaillement (pvp_drops)
    { item = 'weapon_rpg',               chance = 0.10, count = 1 },
    { item = 'weapon_hominglauncher',    chance = 0.05, count = 1 },
    -- Véhicules légendaires
    { item = 'vehicle_deluxo',           chance = 0.07, count = 1 },
    { item = 'vehicle_oppressor2',       chance = 0.05, count = 1 },
    { item = 'vehicle_nightshark',       chance = 0.08, count = 1 },
    { item = 'vehicle_scarab',           chance = 0.06, count = 1 },
    { item = 'vehicle_insurgent3',       chance = 0.07, count = 1 },
    { item = 'vehicle_dukes2',           chance = 0.07, count = 1 },
}
