-- =============================================
--   PVP OUTPOSTS - Configuration
-- =============================================

Config = {}

-- Rayon de la zone safe autour de chaque avant-poste (en mètres)
Config.SafeZoneRadius = 80.0

-- Délai de respawn après la mort (ms)
Config.RespawnDelay = 4000

-- Délai d'invincibilité au spawn (ms)
Config.SpawnInvincibleDuration = 5000

-- Capacité max du coffre par joueur par avant-poste (slots d'items)
Config.StashSlots = 20

-- ── Avant-postes ───────────────────────────────────────────────────────────
-- 2 grandes bases (tous services) + 3 petits camps (spécialité unique)
Config.Outposts = {
    -- ═══════════════════════════════════════════════
    -- GRANDES BASES (tous services : shop, teleport, custom armes, custom véhicules)
    -- ═══════════════════════════════════════════════
    [1] = {
        id          = 'murietta_base',
        label       = 'Avant-poste 1',
        type        = 'military',
        specialty   = 'all',          -- tous les services
        coords      = vector3(1153.0, -1520.0, 35.0),
        heading     = 0.0,
        safeRadius  = 100.0,           -- grande base = zone safe plus large
        npcTeleport      = vector3(1146.0, -1522.0, 35.0),
        headingTeleport  = 225.0,
        npcShop          = vector3(1164.0, -1502.0, 35.0),
        headingShop      = 180.0,
        npcWeaponCustom  = vector3(1159.0, -1502.0, 35.0),
        headingWeaponCustom = 180.0,
        npcVehicleCustom = vector3(1176.0, -1510.0, 35.0),
        headingVehicleCustom = 0.0,

        stashProp        = vector3(1146.0, -1512.0, 35.0),
        stashPropHeading = 0.0,
        blipSprite  = 478,
        blipColor   = 1,    -- rouge (base militaire)
    },
    [2] = {
        id          = 'zancudo_base',
        label       = 'Avant-poste 2',
        type        = 'military',
        specialty   = 'all',
        coords      = vector3(1130.0, -289.0, 69.5),
        heading     = 0.0,
        safeRadius  = 100.0,
        npcTeleport      = vector3(1130.0, -289.0, 69.5),
        headingTeleport  = -85.0,
        npcShop          = vector3(1143.0, -282.0, 69.5),
        headingShop      = -85.0,
        npcWeaponCustom  = vector3(1143.0, -276.0, 69.5),
        headingWeaponCustom = -85.0,
        npcVehicleCustom = vector3(1143.0, -271.0, 69.5),
        headingVehicleCustom = -85.0,
        stashProp        = vector3(1146.0, -292.0, 69.5),
        stashPropHeading = 5.0,
        blipSprite  = 478,
        blipColor   = 1,
    },

    -- ═══════════════════════════════════════════════
    -- PETITS CAMPS (une spécialité chacun)
    -- ═══════════════════════════════════════════════
    [3] = {
        id          = 'ls_armory',
        label       = 'Avant-poste 3',
        type        = 'camp',
        specialty   = 'all',      -- shop armes + custom armes
        coords      = vector3(-1049.9, -2020.0, 13.2),
        heading     = 0.0,
        safeRadius  = 60.0,
        npcTeleport      = vector3(-1049.9, -2011.0, 13.2),
        headingTeleport  = 134.8,
        npcShop          = vector3(-1047.7, -2029.3, 13.2),
        headingShop      = 44.9,
        npcWeaponCustom  = vector3(-1050.3, -2031.9, 13.2),
        headingWeaponCustom = 46.3,
        npcVehicleCustom = vector3(-1053.5, -2007.5, 13.2),
        headingVehicleCustom = 136.3,
        stashProp        = vector3(-1045.3, -2026.9, 13.2),
        stashPropHeading = 44.3,
        blipSprite  = 110,   -- gun shop
        blipColor   = 17,   -- orange
    },
    [4] = {
        id          = 'vespucci_camp',
        label       = 'Avant-poste 4',
        type        = 'camp',
        specialty   = 'all',
        coords      = vector3(-1269.0, -1360.0, 4.2),
        heading     = 0.0,
        safeRadius  = 60.0,
        npcTeleport      = vector3(-1259.1, -1352.0, 4.0),
        headingTeleport  = 109.6,
        npcShop          = vector3(-1279.5, -1357.9, 4.3),
        headingShop      = 288.9,
        npcWeaponCustom  = vector3(-1276.9, -1365.0, 4.3),
        headingWeaponCustom = 288.2,
        npcVehicleCustom = vector3(-1274.0, -1369.1, 4.3),
        headingVehicleCustom = 292.1,
        stashProp        = vector3(-1276.9, -1350.8, 4.3),
        stashPropHeading = 204.3,
        blipSprite  = 478,
        blipColor   = 1,    -- rouge
    },
    [5] = {
        id          = 'ls_camp',
        label       = 'Avant-poste 5',
        type        = 'camp',
        specialty   = 'all',
        coords      = vector3(-518.0, -990.0, 23.4),
        heading     = 0.0,
        safeRadius  = 60.0,
        npcTeleport      = vector3(-511.0, -987.9, 23.6),
        headingTeleport  = 94.7,
        npcShop          = vector3(-524.7, -988.9, 23.3),
        headingShop      = 271.5,
        npcWeaponCustom  = vector3(-524.6, -985.5, 23.3),
        headingWeaponCustom = 269.5,
        npcVehicleCustom = vector3(-524.6, -981.8, 23.3),
        headingVehicleCustom = 269.1,
        stashProp        = vector3(-517.4, -997.9, 23.5),
        stashPropHeading = 2.0,
        blipSprite  = 478,
        blipColor   = 1,
    },
    [6] = {
        id          = 'west_ls_camp',
        label       = 'Avant-poste 6',
        type        = 'camp',
        specialty   = 'all',
        coords      = vector3(-1545.0, -408.0, 42.0),
        heading     = 0.0,
        safeRadius  = 60.0,
        npcTeleport      = vector3(-1551.3, -418.2, 42.0),
        headingTeleport  = 320.0,
        npcShop          = vector3(-1551.4, -409.6, 42.0),
        headingShop      = 321.9,
        npcWeaponCustom  = vector3(-1553.7, -407.7, 42.0),
        headingWeaponCustom = 317.7,
        npcVehicleCustom = vector3(-1542.3, -394.8, 42.0),
        headingVehicleCustom = 147.9,
        stashProp        = vector3(-1530.4, -407.5, 42.0),
        stashPropHeading = 51.9,
        blipSprite  = 478,
        blipColor   = 1,
    },
    [7] = {
        id          = 'mountain_camp',
        label       = 'Avant-poste 7',
        type        = 'camp',
        specialty   = 'all',
        coords      = vector3(-430.0, 1122.0, 325.9),
        heading     = 0.0,
        safeRadius  = 60.0,
        npcTeleport      = vector3(-426.2, 1120.3, 325.9),
        headingTeleport  = 344.4,
        npcShop          = vector3(-435.2, 1123.0, 325.9),
        headingShop      = 345.9,
        npcWeaponCustom  = vector3(-441.7, 1124.3, 325.9),
        headingWeaponCustom = 345.5,
        npcVehicleCustom = vector3(-415.8, 1117.4, 325.9),
        headingVehicleCustom = 340.2,
        stashProp        = vector3(-424.7, 1126.6, 325.9),
        stashPropHeading = 341.8,
        blipSprite  = 478,
        blipColor   = 1,
    },
    [8] = {
        id          = 'route68_camp',
        label       = 'Avant-poste 8',
        type        = 'camp',
        specialty   = 'all',
        coords      = vector3(-1153.0, 2678.0, 18.1),
        heading     = 0.0,
        safeRadius  = 60.0,
        npcTeleport      = vector3(-1159.7, 2676.5, 18.1),
        headingTeleport  = 219.2,
        npcShop          = vector3(-1156.1, 2679.1, 18.1),
        headingShop      = 222.6,
        npcWeaponCustom  = vector3(-1153.6, 2681.2, 18.1),
        headingWeaponCustom = 220.4,
        npcVehicleCustom = vector3(-1149.1, 2682.9, 18.1),
        headingVehicleCustom = 201.9,
        stashProp        = vector3(-1147.5, 2673.6, 18.1),
        stashPropHeading = 41.2,
        blipSprite  = 478,
        blipColor   = 1,
    },
    [9] = {
        id          = 'grand_senora_camp',
        label       = 'Avant-poste 9',
        type        = 'camp',
        specialty   = 'all',
        coords      = vector3(1220.0, 1842.0, 79.2),
        heading     = 0.0,
        safeRadius  = 60.0,
        npcTeleport      = vector3(1224.9, 1836.5, 79.6),
        headingTeleport  = 39.7,
        npcShop          = vector3(1217.7, 1847.2, 78.9),
        headingShop      = 225.0,
        npcWeaponCustom  = vector3(1212.6, 1843.8, 78.9),
        headingWeaponCustom = 191.9,
        npcVehicleCustom = vector3(1225.5, 1848.7, 79.2),
        headingVehicleCustom = 163.1,
        stashProp        = vector3(1232.2, 1840.2, 79.6),
        stashPropHeading = 40.9,
        blipSprite  = 478,
        blipColor   = 1,
    },
    [10] = {
        id          = 'grapeseed_camp',
        label       = 'Avant-poste 10',
        type        = 'camp',
        specialty   = 'all',
        coords      = vector3(2755.0, 3456.0, 55.9),
        heading     = 0.0,
        safeRadius  = 60.0,
        npcTeleport      = vector3(2751.7, 3458.7, 55.9),
        headingTeleport  = 245.5,
        npcShop          = vector3(2749.3, 3453.7, 56.0),
        headingShop      = 249.2,
        npcWeaponCustom  = vector3(2747.8, 3449.6, 56.1),
        headingWeaponCustom = 250.0,
        npcVehicleCustom = vector3(2759.3, 3460.5, 55.8),
        headingVehicleCustom = 157.0,
        stashProp        = vector3(2761.1, 3448.4, 55.9),
        stashPropHeading = 65.8,
        blipSprite  = 478,
        blipColor   = 1,
    },
    [11] = {
        id          = 'grapeseed_north_camp',
        label       = 'Avant-poste 11',
        type        = 'camp',
        specialty   = 'all',
        coords      = vector3(1965.0, 5164.0, 47.5),
        heading     = 0.0,
        safeRadius  = 60.0,
        npcTeleport      = vector3(1970.4, 5168.8, 47.6),
        headingTeleport  = 129.5,
        npcShop          = vector3(1971.2, 5160.0, 47.6),
        headingShop      = 25.1,
        npcWeaponCustom  = vector3(1965.9, 5159.0, 47.4),
        headingWeaponCustom = 13.7,
        npcVehicleCustom = vector3(1960.0, 5158.2, 47.1),
        headingVehicleCustom = 359.6,
        stashProp        = vector3(1958.0, 5173.7, 47.9),
        stashPropHeading = 185.8,
        blipSprite  = 478,
        blipColor   = 1,
    },
    [12] = {
        id          = 'paleto_camp',
        label       = 'Avant-poste 12',
        type        = 'camp',
        specialty   = 'all',
        coords      = vector3(-675.0, 5786.0, 17.3),
        heading     = 0.0,
        safeRadius  = 60.0,
        npcTeleport      = vector3(-672.4, 5793.2, 17.3),
        headingTeleport  = 154.8,
        npcShop          = vector3(-677.6, 5791.9, 17.3),
        headingShop      = 246.6,
        npcWeaponCustom  = vector3(-679.3, 5788.5, 17.3),
        headingWeaponCustom = 247.3,
        npcVehicleCustom = vector3(-678.4, 5773.8, 17.3),
        headingVehicleCustom = 334.6,
        stashProp        = vector3(-671.3, 5782.3, 17.3),
        stashPropHeading = 68.7,
        blipSprite  = 478,
        blipColor   = 1,
    },
}


-- ── Items vendus dans les shops ──────────────────────────────────────────
-- Chaque avant-poste vend selon sa spécialité

-- Shop général (grandes bases uniquement)
Config.ShopItems = {
    { label = 'Bandage',          item = 'bandage',        price = 50   },
    { label = 'Kit de soins',     item = 'medkit',         price = 150  },
    { label = 'Kevlar',            item = 'kevlar',         price = 300  },
    { label = 'Munitions Sniper', item = 'ammo_sniper',    price = 120  },
    { label = 'Grenade',          item = 'weapon_grenade', price = 300  },
}

-- Shop armurerie (camp armes)
Config.WeaponShopItems = {
    { label = 'Pistolet',         item = 'weapon_pistol',       price = 300  },
    { label = 'SMG',              item = 'weapon_smg',          price = 800  },
    { label = 'Pompe',            item = 'weapon_pumpshotgun',  price = 600  },
    { label = 'Fusil d\'assaut',  item = 'weapon_assaultrifle', price = 1500 },
    { label = 'Sniper',           item = 'weapon_sniperrifle',  price = 3000 },
    { label = 'Munitions Sniper', item = 'ammo_sniper',         price = 120  },
    { label = 'Grenade',          item = 'weapon_grenade',      price = 300  },
    { label = 'Couteau',          item = 'weapon_knife',        price = 100  },
    { label = 'Machette',         item = 'weapon_machete',      price = 200  },
}

-- Shop garage (camp véhicules)
Config.VehicleShopItems = {
    { label = 'BMX',              item = 'vehicle_bmx',         price = 200  },
    { label = 'Blazer',           item = 'vehicle_blazer',      price = 500  },
    { label = 'Sanchez',          item = 'vehicle_sanchez',     price = 800  },
    { label = 'Bodhi',            item = 'vehicle_bodhi2',      price = 600  },
    { label = 'Mesa',             item = 'vehicle_mesa',        price = 1200 },
    { label = 'Kuruma',           item = 'vehicle_kuruma',      price = 2500 },
    { label = 'Insurgent',        item = 'vehicle_insurgent',   price = 5000 },
}

-- Shop médical (camp médical)
Config.MedicalShopItems = {
    { label = 'Bandage',          item = 'bandage',        price = 30   },
    { label = 'Kit de soins',     item = 'medkit',         price = 100  },
    { label = 'Kevlar',            item = 'kevlar',         price = 200  },
}

-- Ratio de revente au NPC (50% du prix d'achat)
Config.SellRatio = 0.5

-- ══ Prix de base de TOUS les items (pour la vente) ═══════════════════════
-- Sert de référence pour le prix de revente (prix × SellRatio).
-- Les items des shops sont déjà inclus, cette table couvre le reste.
Config.AllItemPrices = {
    -- Consommables
    { item = 'bandage',              label = 'Bandage',               price = 50   },
    { item = 'medkit',               label = 'Kit de Soins',          price = 150  },
    { item = 'kevlar',               label = 'Kevlar',                price = 300  },
    { item = 'ammo_sniper',          label = 'Munitions Sniper',      price = 120  },
    { item = 'lockpick',             label = 'Lockpick',              price = 80   },
    -- Mêlée
    { item = 'weapon_knife',         label = 'Couteau',               price = 100  },
    { item = 'weapon_bat',           label = 'Batte de Baseball',     price = 80   },
    { item = 'weapon_crowbar',       label = 'Pied de Biche',         price = 90   },
    { item = 'weapon_switchblade',   label = 'Cran d\'Arrêt',         price = 70   },
    { item = 'weapon_hatchet',       label = 'Hachette',              price = 120  },
    { item = 'weapon_machete',       label = 'Machette',              price = 200  },
    -- Pistolets
    { item = 'weapon_pistol',        label = 'Pistolet',              price = 300  },
    { item = 'weapon_snspistol',     label = 'SNS Pistol',            price = 200  },
    { item = 'weapon_vintagepistol', label = 'Pistolet Vintage',      price = 350  },
    { item = 'weapon_machinepistol', label = 'Pistolet Mitrailleur',  price = 500  },
    { item = 'weapon_combatpistol',  label = 'Pistolet Combat',       price = 400  },
    { item = 'weapon_heavypistol',   label = 'Pistolet Lourd',        price = 500  },
    { item = 'weapon_revolver',      label = 'Revolver',              price = 600  },
    { item = 'weapon_doubleaction',  label = 'Revolver DA',           price = 500  },
    -- SMGs
    { item = 'weapon_microsmg',      label = 'Micro SMG',             price = 600  },
    { item = 'weapon_minismg',       label = 'Mini SMG',              price = 700  },
    { item = 'weapon_smg',           label = 'SMG',                   price = 800  },
    { item = 'weapon_combatpdw',     label = 'PDW Combat',            price = 900  },
    -- Shotguns
    { item = 'weapon_pumpshotgun',   label = 'Pompe',                 price = 600  },
    { item = 'weapon_sawnoffshotgun',label = 'Canon Scié',            price = 500  },
    { item = 'weapon_dbshotgun',     label = 'Double Canon',          price = 700  },
    { item = 'weapon_assaultshotgun',label = 'Shotgun Assaut',        price = 1200 },
    -- Fusils d'assaut
    { item = 'weapon_assaultrifle',  label = 'AK-47',                 price = 1500 },
    { item = 'weapon_carbinerifle',  label = 'Carabine M4',           price = 1500 },
    { item = 'weapon_compactrifle',  label = 'Fusil Compact',         price = 1200 },
    -- LMGs
    { item = 'weapon_combatmg',      label = 'Mitrailleuse Combat',   price = 2500 },
    { item = 'weapon_mg',            label = 'Mitrailleuse',          price = 3000 },
    -- Sniper
    { item = 'weapon_sniperrifle',   label = 'Sniper',                price = 3000 },
    -- Explosifs
    { item = 'weapon_rpg',           label = 'Lance-Roquettes',       price = 5000 },
    { item = 'weapon_grenadelauncher',label= 'Lance-Grenades',        price = 4000 },
    { item = 'weapon_grenade',       label = 'Grenade',               price = 300  },
    -- Véhicules communs
    { item = 'vehicle_ratloader',    label = 'Ratloader',             price = 300  },
    { item = 'vehicle_bodhi2',       label = 'Bodhi',                 price = 600  },
    { item = 'vehicle_emperor',      label = 'Emperor',               price = 400  },
    { item = 'vehicle_tornado',      label = 'Tornado',               price = 400  },
    { item = 'vehicle_bmx',          label = 'BMX',                   price = 200  },
    { item = 'vehicle_blazer',       label = 'Blazer',                price = 500  },
    -- Véhicules peu communs
    { item = 'vehicle_sanchez',      label = 'Sanchez',               price = 800  },
    { item = 'vehicle_bati',         label = 'Bati 801',              price = 1000 },
    { item = 'vehicle_mesa',         label = 'Mesa',                  price = 1200 },
    { item = 'vehicle_dubsta',       label = 'Dubsta',                price = 1500 },
    { item = 'vehicle_brawler',      label = 'Brawler',               price = 2000 },
    { item = 'vehicle_kamacho',      label = 'Kamacho',               price = 2000 },
    { item = 'vehicle_kuruma',       label = 'Kuruma',                price = 2500 },
    { item = 'vehicle_buffalo',      label = 'Buffalo',               price = 1800 },
    -- Véhicules rares
    { item = 'vehicle_insurgent',    label = 'Insurgent',             price = 5000 },
    { item = 'vehicle_buffalo3',     label = 'Buffalo S',             price = 3000 },
    { item = 'vehicle_hellion',      label = 'Hellion',               price = 3500 },
    { item = 'vehicle_dominator',    label = 'Dominator',             price = 3000 },
    { item = 'vehicle_guardian',     label = 'Guardian',              price = 4000 },
    { item = 'vehicle_nightshark',   label = 'Nightshark',            price = 6000 },
    -- Véhicules rares blindés
    { item = 'vehicle_baller3',      label = 'Baller Blindé',         price = 5000 },
    { item = 'vehicle_baller6',      label = 'Baller LE Blindé',      price = 5500 },
    { item = 'vehicle_schafter5',    label = 'Schafter V12 Blindé',   price = 5000 },
    { item = 'vehicle_schafter6',    label = 'Schafter LWB Blindé',   price = 5500 },
    -- Véhicules apocalypse
    { item = 'vehicle_deathbike',    label = 'Deathbike',             price = 4000 },
    { item = 'vehicle_dominator4',   label = 'Dominator Apocalypse',  price = 4500 },
    { item = 'vehicle_impaler2',     label = 'Impaler Apocalypse',    price = 4500 },
    { item = 'vehicle_imperator',    label = 'Imperator',             price = 5000 },
    { item = 'vehicle_bruiser',      label = 'Bruiser',               price = 5000 },
    { item = 'vehicle_brutus',       label = 'Brutus',                price = 5000 },
    { item = 'vehicle_scarab',       label = 'Scarab',                price = 5500 },
    { item = 'vehicle_slamvan4',     label = 'Slamvan Apocalypse',    price = 4500 },
    { item = 'vehicle_zr380',        label = 'ZR380',                 price = 4000 },
    -- Véhicules légendaires
    { item = 'vehicle_zentorno',     label = 'Zentorno',              price = 8000 },
    { item = 'vehicle_t20',          label = 'T20',                   price = 10000},
    { item = 'vehicle_vigilante',    label = 'Vigilante',             price = 12000},
    { item = 'vehicle_oppressor2',   label = 'Oppressor MK2',        price = 15000},
}

-- ══ CUSTOM ARMES — Composants GTA natifs (gratuit) ══════════════════════
-- Clé = item name dans l'inventaire, valeur = liste de catégories de composants
Config.WeaponComponents = {
    -- ── Pistolets ──
    weapon_pistol = {
        { label = 'Chargeur étendu',  component = 'COMPONENT_PISTOL_CLIP_02' },
        { label = 'Lampe torche',     component = 'COMPONENT_AT_PI_FLSH' },
        { label = 'Silencieux',       component = 'COMPONENT_AT_PI_SUPP_02' },
    },
    weapon_combatpistol = {
        { label = 'Chargeur étendu',  component = 'COMPONENT_COMBATPISTOL_CLIP_02' },
        { label = 'Lampe torche',     component = 'COMPONENT_AT_PI_FLSH' },
        { label = 'Silencieux',       component = 'COMPONENT_AT_PI_SUPP' },
    },
    weapon_heavypistol = {
        { label = 'Chargeur étendu',  component = 'COMPONENT_HEAVYPISTOL_CLIP_02' },
        { label = 'Lampe torche',     component = 'COMPONENT_AT_PI_FLSH' },
        { label = 'Silencieux',       component = 'COMPONENT_AT_PI_SUPP' },
    },
    weapon_snspistol = {
        { label = 'Chargeur étendu',  component = 'COMPONENT_SNSPISTOL_CLIP_02' },
    },
    weapon_vintagepistol = {
        { label = 'Chargeur étendu',  component = 'COMPONENT_VINTAGEPISTOL_CLIP_02' },
        { label = 'Silencieux',       component = 'COMPONENT_AT_PI_SUPP' },
    },
    weapon_revolver = {},
    weapon_doubleaction = {},
    weapon_machinepistol = {
        { label = 'Chargeur étendu',  component = 'COMPONENT_MACHINEPISTOL_CLIP_02' },
        { label = 'Silencieux',       component = 'COMPONENT_AT_PI_SUPP' },
    },
    -- ── SMG ──
    weapon_microsmg = {
        { label = 'Chargeur étendu',  component = 'COMPONENT_MICROSMG_CLIP_02' },
        { label = 'Lampe torche',     component = 'COMPONENT_AT_PI_FLSH' },
        { label = 'Viseur',           component = 'COMPONENT_AT_SCOPE_MACRO' },
        { label = 'Silencieux',       component = 'COMPONENT_AT_AR_SUPP_02' },
    },
    weapon_smg = {
        { label = 'Chargeur étendu',  component = 'COMPONENT_SMG_CLIP_02' },
        { label = 'Lampe torche',     component = 'COMPONENT_AT_AR_FLSH' },
        { label = 'Viseur',           component = 'COMPONENT_AT_SCOPE_MACRO_02' },
        { label = 'Silencieux',       component = 'COMPONENT_AT_PI_SUPP' },
    },
    weapon_minismg = {
        { label = 'Chargeur étendu',  component = 'COMPONENT_MINISMG_CLIP_02' },
    },
    weapon_combatpdw = {
        { label = 'Chargeur étendu',  component = 'COMPONENT_COMBATPDW_CLIP_02' },
        { label = 'Lampe torche',     component = 'COMPONENT_AT_AR_FLSH' },
        { label = 'Viseur',           component = 'COMPONENT_AT_SCOPE_SMALL' },
        { label = 'Grip',             component = 'COMPONENT_AT_AR_AFGRIP' },
    },
    -- ── Shotguns ──
    weapon_pumpshotgun = {
        { label = 'Lampe torche',     component = 'COMPONENT_AT_AR_FLSH' },
        { label = 'Silencieux',       component = 'COMPONENT_AT_SR_SUPP' },
    },
    weapon_sawnoffshotgun = {},
    weapon_assaultshotgun = {
        { label = 'Chargeur étendu',  component = 'COMPONENT_ASSAULTSHOTGUN_CLIP_02' },
        { label = 'Lampe torche',     component = 'COMPONENT_AT_AR_FLSH' },
        { label = 'Silencieux',       component = 'COMPONENT_AT_AR_SUPP' },
        { label = 'Grip',             component = 'COMPONENT_AT_AR_AFGRIP' },
    },
    weapon_dbshotgun = {},
    -- ── Fusils d'assaut ──
    weapon_assaultrifle = {
        { label = 'Chargeur étendu',  component = 'COMPONENT_ASSAULTRIFLE_CLIP_02' },
        { label = 'Lampe torche',     component = 'COMPONENT_AT_AR_FLSH' },
        { label = 'Viseur',           component = 'COMPONENT_AT_SCOPE_MACRO' },
        { label = 'Silencieux',       component = 'COMPONENT_AT_AR_SUPP_02' },
        { label = 'Grip',             component = 'COMPONENT_AT_AR_AFGRIP' },
    },
    weapon_assaultrifle_mk2 = {
        { label = 'Chargeur étendu',  component = 'COMPONENT_ASSAULTRIFLE_MK2_CLIP_02' },
        { label = 'Lampe torche',     component = 'COMPONENT_AT_AR_FLSH' },
        { label = 'Viseur',           component = 'COMPONENT_AT_SCOPE_MACRO_MK2' },
        { label = 'Silencieux',       component = 'COMPONENT_AT_AR_SUPP_02' },
        { label = 'Grip',             component = 'COMPONENT_AT_AR_AFGRIP_02' },
    },
    weapon_carbinerifle = {
        { label = 'Chargeur étendu',  component = 'COMPONENT_CARBINERIFLE_CLIP_02' },
        { label = 'Lampe torche',     component = 'COMPONENT_AT_AR_FLSH' },
        { label = 'Viseur',           component = 'COMPONENT_AT_SCOPE_MEDIUM' },
        { label = 'Silencieux',       component = 'COMPONENT_AT_AR_SUPP' },
        { label = 'Grip',             component = 'COMPONENT_AT_AR_AFGRIP' },
    },
    weapon_carbinerifle_mk2 = {
        { label = 'Chargeur étendu',  component = 'COMPONENT_CARBINERIFLE_MK2_CLIP_02' },
        { label = 'Lampe torche',     component = 'COMPONENT_AT_AR_FLSH' },
        { label = 'Viseur',           component = 'COMPONENT_AT_SCOPE_MEDIUM_MK2' },
        { label = 'Silencieux',       component = 'COMPONENT_AT_AR_SUPP' },
        { label = 'Grip',             component = 'COMPONENT_AT_AR_AFGRIP_02' },
    },
    weapon_specialcarbine = {
        { label = 'Chargeur étendu',  component = 'COMPONENT_SPECIALCARBINE_CLIP_02' },
        { label = 'Lampe torche',     component = 'COMPONENT_AT_AR_FLSH' },
        { label = 'Viseur',           component = 'COMPONENT_AT_SCOPE_MEDIUM' },
        { label = 'Silencieux',       component = 'COMPONENT_AT_AR_SUPP_02' },
        { label = 'Grip',             component = 'COMPONENT_AT_AR_AFGRIP' },
    },
    weapon_specialcarbine_mk2 = {
        { label = 'Chargeur étendu',  component = 'COMPONENT_SPECIALCARBINE_MK2_CLIP_02' },
        { label = 'Lampe torche',     component = 'COMPONENT_AT_AR_FLSH' },
        { label = 'Viseur',           component = 'COMPONENT_AT_SCOPE_MEDIUM_MK2' },
        { label = 'Silencieux',       component = 'COMPONENT_AT_AR_SUPP_02' },
        { label = 'Grip',             component = 'COMPONENT_AT_AR_AFGRIP_02' },
    },
    weapon_compactrifle = {
        { label = 'Chargeur étendu',  component = 'COMPONENT_COMPACTRIFLE_CLIP_02' },
    },
    -- ── MG ──
    weapon_combatmg = {
        { label = 'Chargeur étendu',  component = 'COMPONENT_COMBATMG_CLIP_02' },
        { label = 'Viseur',           component = 'COMPONENT_AT_SCOPE_MEDIUM' },
        { label = 'Grip',             component = 'COMPONENT_AT_AR_AFGRIP' },
    },
    weapon_combatmg_mk2 = {
        { label = 'Chargeur étendu',  component = 'COMPONENT_COMBATMG_MK2_CLIP_02' },
        { label = 'Viseur',           component = 'COMPONENT_AT_SCOPE_MEDIUM_MK2' },
        { label = 'Grip',             component = 'COMPONENT_AT_AR_AFGRIP_02' },
    },
    weapon_mg = {
        { label = 'Chargeur étendu',  component = 'COMPONENT_MG_CLIP_02' },
        { label = 'Viseur',           component = 'COMPONENT_AT_SCOPE_SMALL_02' },
    },
    -- ── Sniper ──
    weapon_sniperrifle = {
        { label = 'Silencieux',       component = 'COMPONENT_AT_AR_SUPP_02' },
        { label = 'Viseur avancé',    component = 'COMPONENT_AT_SCOPE_MAX' },
    },
    weapon_precisionrifle = {},
    weapon_marksmanrifle_mk2 = {
        { label = 'Chargeur étendu',  component = 'COMPONENT_MARKSMANRIFLE_MK2_CLIP_02' },
        { label = 'Lampe torche',     component = 'COMPONENT_AT_AR_FLSH' },
        { label = 'Viseur',           component = 'COMPONENT_AT_SCOPE_MEDIUM_MK2' },
        { label = 'Silencieux',       component = 'COMPONENT_AT_AR_SUPP' },
        { label = 'Grip',             component = 'COMPONENT_AT_AR_AFGRIP_02' },
    },
    -- ── Pistolets MK2 / AP ──
    weapon_appistol = {
        { label = 'Chargeur étendu',  component = 'COMPONENT_APPISTOL_CLIP_02' },
        { label = 'Lampe torche',     component = 'COMPONENT_AT_PI_FLSH' },
        { label = 'Silencieux',       component = 'COMPONENT_AT_PI_SUPP' },
    },
    weapon_pistol_mk2 = {
        { label = 'Chargeur étendu',  component = 'COMPONENT_PISTOL_MK2_CLIP_02' },
        { label = 'Lampe torche',     component = 'COMPONENT_AT_PI_FLSH_02' },
        { label = 'Silencieux',       component = 'COMPONENT_AT_PI_SUPP_02' },
        { label = 'Viseur',           component = 'COMPONENT_AT_SIGHTS' },
    },
    weapon_snspistol_mk2 = {
        { label = 'Chargeur étendu',  component = 'COMPONENT_SNSPISTOL_MK2_CLIP_02' },
    },
    -- ── SMG MK2 ──
    weapon_smg_mk2 = {
        { label = 'Chargeur étendu',  component = 'COMPONENT_SMG_MK2_CLIP_02' },
        { label = 'Lampe torche',     component = 'COMPONENT_AT_AR_FLSH' },
        { label = 'Viseur',           component = 'COMPONENT_AT_SCOPE_MACRO_02_MK2' },
        { label = 'Silencieux',       component = 'COMPONENT_AT_PI_SUPP' },
    },
    -- ── Explosifs (pas de composants) ──
    weapon_rpg = {},
    weapon_grenadelauncher = {},
    weapon_grenade = {},
    weapon_compactlauncher = {},
    weapon_emplauncher = {},
    weapon_hominglauncher = {},
    weapon_molotov = {},
    weapon_stungun = {},
    weapon_musket = {},
    -- ── Mêlée (pas de composants) ──
    weapon_knife = {},
    weapon_bat = {},
    weapon_crowbar = {},
    weapon_switchblade = {},
    weapon_hatchet = {},
    weapon_machete = {},
}

-- ══ TEINTES D'ARMES — 8 teintes GTA V (SetPedWeaponTint) ════════════════
-- Index 0-7, compatibles avec toutes les armes à feu
Config.WeaponTints = {
    [0] = 'Normal',
    [1] = 'Vert',
    [2] = 'Or',
    [3] = 'Rose',
    [4] = 'Armée',
    [5] = 'LSPD',
    [6] = 'Orange',
    [7] = 'Platine',
}

-- Armes supportant les teintes (toutes les armes à feu, pas mêlée/explosifs)
Config.WeaponsTintEnabled = {
    -- Pistolets
    weapon_pistol = true,         weapon_combatpistol = true,
    weapon_heavypistol = true,    weapon_snspistol = true,
    weapon_vintagepistol = true,  weapon_revolver = true,
    weapon_doubleaction = true,   weapon_machinepistol = true,
    weapon_appistol = true,       weapon_pistol_mk2 = true,
    weapon_snspistol_mk2 = true,
    -- SMG
    weapon_microsmg = true,       weapon_minismg = true,
    weapon_smg = true,            weapon_combatpdw = true,
    weapon_smg_mk2 = true,
    -- Shotguns
    weapon_pumpshotgun = true,    weapon_sawnoffshotgun = true,
    weapon_assaultshotgun = true, weapon_dbshotgun = true,
    -- Fusils d'assaut
    weapon_assaultrifle = true,   weapon_assaultrifle_mk2 = true,
    weapon_carbinerifle = true,   weapon_carbinerifle_mk2 = true,
    weapon_specialcarbine = true, weapon_specialcarbine_mk2 = true,
    weapon_compactrifle = true,
    -- MG
    weapon_combatmg = true,       weapon_combatmg_mk2 = true,
    weapon_mg = true,
    -- Sniper
    weapon_sniperrifle = true,    weapon_precisionrifle = true,
    weapon_marksmanrifle_mk2 = true,
    -- Divers (tirs)
    weapon_stungun = true,        weapon_musket = true,
}

-- ══ CUSTOM VÉHICULES — Catégories de mods ═══════════════════════════════
-- modType = index GTA natif pour SetVehicleMod
Config.VehicleMods = {
    { label = 'Moteur',       modType = 11 },
    { label = 'Freins',       modType = 12 },
    { label = 'Transmission', modType = 13 },
    { label = 'Suspension',   modType = 15 },
    { label = 'Blindage',     modType = 16 },
    { label = 'Turbo',        modType = 18, isTurbo = true },
    { label = 'Klaxon',       modType = 14 },
    { label = 'Roues',        modType = 23 },
    { label = 'Échappement',  modType = 4  },
    { label = 'Pare-chocs AV',modType = 1  },
    { label = 'Pare-chocs AR',modType = 2  },
    { label = 'Jupes lat.',   modType = 3  },
    { label = 'Capot',        modType = 7  },
    { label = 'Aileron',      modType = 0  },
    { label = 'Grille',       modType = 6  },
}

-- Mods supplémentaires pour véhicules Arena War / Apocalypse (modTypes 38-49)
Config.ApocalypseMods = {
    { label = 'Armure',           modType = 38 },
    { label = 'Lames / Piques',   modType = 39 },
    { label = 'Arme montée',     modType = 40 },
    { label = 'Drapeau',          modType = 41 },
    { label = 'Couleur néon',    modType = 42 },
    { label = 'Roues Arena',      modType = 24 },
    { label = 'Arche lumineuse',  modType = 43 },
    { label = 'Plaque avant',     modType = 44 },
    { label = 'Garniture',        modType = 46 },
    { label = 'Hydrauliques',     modType = 47 },
    { label = 'Boost (visuel)',   modType = 48 },
}

-- Couleurs disponibles (index GTA)
Config.VehicleColors = {
    { label = 'Noir',          color = 0   },
    { label = 'Noir carbone',  color = 1   },
    { label = 'Gris foncé',   color = 3   },
    { label = 'Argent',        color = 4   },
    { label = 'Gris clair',   color = 6   },
    { label = 'Blanc',         color = 111 },
    { label = 'Rouge',         color = 27  },
    { label = 'Rouge foncé',  color = 28  },
    { label = 'Orange',        color = 38  },
    { label = 'Jaune',         color = 42  },
    { label = 'Vert foncé',   color = 49  },
    { label = 'Vert',          color = 53  },
    { label = 'Bleu foncé',   color = 61  },
    { label = 'Bleu',          color = 64  },
    { label = 'Bleu clair',   color = 70  },
    { label = 'Violet',        color = 71  },
    { label = 'Rose',          color = 135 },
    { label = 'Beige',         color = 94  },
    { label = 'Marron',        color = 97  },
    { label = 'Rouille',       color = 36  },
    { label = 'Or',             color = 37  },
    { label = 'Camo vert',    color = 110 },
    { label = 'Camo gris',    color = 155 },
}

-- Véhicules apocalypse avec mods spéciaux (saut, boost, etc.)
Config.ApocalypseVehicles = {
    'deathbike', 'deathbike2', 'deathbike3',
    'dominator4', 'dominator5', 'dominator6',
    'impaler2', 'impaler3', 'impaler4',
    'imperator', 'imperator2', 'imperator3',
    'bruiser', 'bruiser2', 'bruiser3',
    'brutus', 'brutus2', 'brutus3',
    'scarab', 'scarab2', 'scarab3',
    'slamvan4', 'slamvan5', 'slamvan6',
    'zr380', 'zr3802', 'zr3803',
    'cerberus', 'cerberus2', 'cerberus3',
}
