Config = {}

-- [NPC — pas de spawn propre, pvp_garage est appelé via events depuis pvp_outposts]
Config.VehicleSearchRadius = 15.0

-- [APOCALYPSE VEHICLES]
-- SOURCE DE VÉRITÉ : pvp_outposts/config.lua → Config.ApocalypseVehicles (liste de strings).
-- Cette table est un hash map GetHashKey(model)→true construit au démarrage via un export.
-- Si pvp_outposts n'est pas disponible, fallback sur la liste locale.
Config.ApocalypseVehicles = {}

local fallback = {
    'scarab', 'scarab2', 'scarab3',
    'deathbike', 'deathbike2', 'deathbike3',
    'dominator3', 'dominator4', 'dominator5',
    'bruiser', 'bruiser2', 'bruiser3',
    'nightmare',
    'impaler', 'impaler2', 'impaler3', 'impaler4',
}

Citizen.CreateThread(function()
    Citizen.Wait(500)
    local list = nil
    local ok = pcall(function()
        list = exports['pvp_outposts']:getApocalypseVehicles()
    end)
    if not ok or type(list) ~= 'table' or #list == 0 then
        list = fallback
    end
    for _, model in ipairs(list) do
        Config.ApocalypseVehicles[GetHashKey(model)] = true
    end
end)

-- [VEHICLE SHOP LIST]
-- price = prix d'achat en $ | sellPrice = prix de revente (calculé automatiquement à 50% côté serveur)
-- Seul point de vente véhicule du serveur (achat ET revente d'objets-véhicule).
-- Les modèles marqués "Butin Rare" sont aussi un drop zombie (Config.LootTable
-- dans pvp_zombies) ; les modèles épique/légendaire (Schafter V12, Baller LE,
-- ZR380, Vigilante, Oppressor MK2, Nightshark, Scarab) ne sont VOLONTAIREMENT
-- PAS ici — invendables/inachetables au garagiste, échange marché joueur/trade
-- uniquement (voir le blocage explicite dans server/main.lua:sellVehicleItem).
Config.Vehicles = {
    -- Military
    { label = 'Insurgent',   model = 'insurgent',   category = 'Militaire',    price = 60000 },

    -- Apocalypse
    { label = 'Deathbike',            model = 'deathbike',   category = 'Apocalypse', price = 70000 },
    { label = 'Impaler Apocalypse',   model = 'impaler2',    category = 'Apocalypse', price = 68000 },
    { label = 'Bruiser',              model = 'bruiser',     category = 'Apocalypse', price = 72000 },
    { label = 'Brutus',               model = 'brutus',      category = 'Apocalypse', price = 75000 },
    { label = 'Imperator',            model = 'imperator',   category = 'Apocalypse', price = 78000 },
    { label = 'Slamvan Apocalypse',   model = 'slamvan4',    category = 'Apocalypse', price = 60000 },

    -- Armored
    { label = 'Baller Blindé',        model = 'baller3',   category = 'Blindé', price = 25000 },
    { label = 'Schafter LWB Blindé',  model = 'schafter6', category = 'Blindé', price = 40000 },
    { label = 'Kuruma Blindé',        model = 'kuruma',    category = 'Blindé', price = 45000 },

    -- Off-Road
    { label = 'Mesa',      model = 'mesa',    category = 'Tout-Terrain', price = 5000  },
    { label = 'Dubsta',    model = 'dubsta',  category = 'Tout-Terrain', price = 8000  },
    { label = 'Brawler',   model = 'brawler', category = 'Tout-Terrain', price = 9000  },
    { label = 'Kamacho',   model = 'kamacho', category = 'Tout-Terrain', price = 7000  },
    { label = 'Hellion',   model = 'hellion', category = 'Tout-Terrain', price = 10000 },

    -- Muscle
    { label = 'Dominator',    model = 'dominator', category = 'Muscle', price = 4000 },
    { label = 'Buffalo',      model = 'buffalo',   category = 'Muscle', price = 4500 },
    { label = 'Buffalo STX',  model = 'buffalo3',  category = 'Muscle', price = 6000 },

    -- Motorcycles
    { label = 'Sanchez',   model = 'sanchez', category = 'Motos', price = 1200 },
    { label = 'Bati 801',  model = 'bati',    category = 'Motos', price = 2500 },
    { label = 'BMX',       model = 'bmx',     category = 'Motos', price = 300  },

    -- Utility
    { label = 'Ratloader', model = 'ratloader', category = 'Utilitaire', price = 1500 },
    { label = 'Bodhi',     model = 'bodhi2',    category = 'Utilitaire', price = 2000 },
    { label = 'Blazer',    model = 'blazer',    category = 'Utilitaire', price = 800  },

    -- Butin Rare (aussi un drop zombie ~2.2% cumulé, palier "rare")
    { label = 'Z-Type',               model = 'ztype',      category = 'Butin Rare', price = 30000 },
    { label = 'Mule',                 model = 'mule',       category = 'Butin Rare', price = 15000 },
    { label = 'Blazer 5',             model = 'blazer5',    category = 'Butin Rare', price = 15000 },
    { label = 'Dominator Apocalypse', model = 'dominator4', category = 'Butin Rare', price = 30000 },
    { label = 'Revolter',             model = 'revolter',   category = 'Butin Rare', price = 30000 },
    { label = 'Ultralight',           model = 'ultralight', category = 'Butin Rare', price = 30000 },
    { label = 'Speedo 2',             model = 'speedo2',    category = 'Butin Rare', price = 15000 },
}

-- Modèles épique/légendaire : jamais vendus/rachetés par le garagiste, quel que
-- soit leur statut dans Config.Vehicles (fallback flat 500$ de sellVehicleItem
-- neutralisé explicitement côté serveur pour ces modèles précis).
Config.MarketOnlyVehicles = {
    'schafter5', 'baller6', 'zr380', 'vigilante',       -- épique (loot zombie + caisse)
    'oppressor2', 'nightshark', 'scarab',               -- légendaire (loot zombie + caisse)
}

-- [CUSTOMIZATION CATEGORY LABELS]
Config.Categories = {
    { id = 'paint',       label = 'Peinture' },
    { id = 'wheels',      label = 'Roues' },
    { id = 'engine',      label = 'Moteur' },
    { id = 'brakes',      label = 'Freins' },
    { id = 'transmission',label = 'Transmission' },
    { id = 'armor',       label = 'Blindage' },
    { id = 'turbo',       label = 'Turbo' },
    { id = 'suspension',  label = 'Suspension' },
    { id = 'livery',      label = 'Livrée' },
    { id = 'neon',        label = 'Néons' },
    { id = 'tint',        label = 'Vitres' },
    { id = 'xenon',       label = 'Phares Xenon' },
}

-- [WHEEL TYPE LABELS]
Config.WheelTypes = {
    [0]  = 'Sport',
    [1]  = 'Muscle',
    [2]  = 'Lowrider',
    [3]  = 'SUV',
    [4]  = 'Offroad',
    [5]  = 'Tuner',
    [6]  = 'Moto',
    [7]  = 'High End',
    [8]  = 'Benny\'s Original',
    [9]  = 'Benny\'s Bespoke',
    [10] = 'Open Wheel',
    [11] = 'Street',
    [12] = 'Track',
}

-- [WINDOW TINT LABELS]
Config.WindowTints = {
    { index = 0, label = 'Aucune' },
    { index = 1, label = 'Noire' },
    { index = 2, label = 'Sombre' },
    { index = 3, label = 'Claire' },
    { index = 4, label = 'Vert Limousine' },
    { index = 5, label = 'Pure Black' },
}

-- [XENON COLORS]
Config.XenonColors = {
    { index = -1, label = 'Blanc par défaut' },
    { index = 0,  label = 'Blanc' },
    { index = 1,  label = 'Bleu' },
    { index = 2,  label = 'Bleu Electrique' },
    { index = 3,  label = 'Vert Menthe' },
    { index = 4,  label = 'Vert Citron' },
    { index = 5,  label = 'Jaune' },
    { index = 6,  label = 'Or' },
    { index = 7,  label = 'Orange' },
    { index = 8,  label = 'Rouge' },
    { index = 9,  label = 'Rose Poney' },
    { index = 10, label = 'Rose Vif' },
    { index = 11, label = 'Violet' },
    { index = 12, label = 'Blacklight' },
}

-- [GTA STANDARD COLORS — 160 entries, label + RGB]
Config.VehicleColors = {
    { index = 0,   label = 'Metallic Black',            r = 13,  g = 17,  b = 22  },
    { index = 1,   label = 'Metallic Graphite Black',   r = 28,  g = 29,  b = 33  },
    { index = 2,   label = 'Metallic Black Steal',      r = 50,  g = 56,  b = 61  },
    { index = 3,   label = 'Metallic Dark Silver',      r = 69,  g = 75,  b = 79  },
    { index = 4,   label = 'Metallic Silver',           r = 153, g = 157, b = 160 },
    { index = 5,   label = 'Metallic Blue Silver',      r = 194, g = 196, b = 198 },
    { index = 6,   label = 'Metallic Steel Gray',       r = 151, g = 154, b = 151 },
    { index = 7,   label = 'Metallic Shadow Silver',    r = 99,  g = 115, b = 128 },
    { index = 8,   label = 'Metallic Stone Silver',     r = 99,  g = 98,  b = 92  },
    { index = 9,   label = 'Metallic Midnight Silver',  r = 60,  g = 63,  b = 71  },
    { index = 10,  label = 'Metallic Gun Metal',        r = 68,  g = 78,  b = 84  },
    { index = 11,  label = 'Metallic Anthracite Grey',  r = 29,  g = 33,  b = 41  },
    { index = 12,  label = 'Matte Black',               r = 19,  g = 24,  b = 31  },
    { index = 13,  label = 'Matte Gray',                r = 38,  g = 40,  b = 42  },
    { index = 14,  label = 'Matte Light Grey',          r = 81,  g = 85,  b = 84  },
    { index = 15,  label = 'Util Black',                r = 21,  g = 25,  b = 33  },
    { index = 16,  label = 'Util Black Poly',           r = 30,  g = 36,  b = 41  },
    { index = 17,  label = 'Util Dark Silver',          r = 51,  g = 58,  b = 60  },
    { index = 18,  label = 'Util Silver',               r = 140, g = 144, b = 149 },
    { index = 19,  label = 'Util Gun Metal',            r = 57,  g = 67,  b = 77  },
    { index = 20,  label = 'Util Shadow Silver',        r = 80,  g = 98,  b = 114 },
    { index = 21,  label = 'Worn Black',                r = 30,  g = 35,  b = 47  },
    { index = 22,  label = 'Worn Graphite',             r = 54,  g = 58,  b = 63  },
    { index = 23,  label = 'Worn Silver Grey',          r = 160, g = 161, b = 153 },
    { index = 24,  label = 'Worn Silver',               r = 211, g = 211, b = 211 },
    { index = 25,  label = 'Worn Blue Silver',          r = 183, g = 191, b = 202 },
    { index = 26,  label = 'Worn Shadow Silver',        r = 119, g = 135, b = 148 },
    { index = 27,  label = 'Metallic Red',              r = 192, g = 14,  b = 26  },
    { index = 28,  label = 'Metallic Torino Red',       r = 218, g = 25,  b = 24  },
    { index = 29,  label = 'Metallic Formula Red',      r = 182, g = 17,  b = 27  },
    { index = 30,  label = 'Metallic Blaze Red',        r = 165, g = 30,  b = 35  },
    { index = 31,  label = 'Metallic Graceful Red',     r = 123, g = 26,  b = 34  },
    { index = 32,  label = 'Metallic Garnet Red',       r = 142, g = 27,  b = 31  },
    { index = 33,  label = 'Metallic Desert Red',       r = 111, g = 24,  b = 24  },
    { index = 34,  label = 'Metallic Cabernet Red',     r = 73,  g = 17,  b = 29  },
    { index = 35,  label = 'Metallic Candy Red',        r = 182, g = 15,  b = 37  },
    { index = 36,  label = 'Metallic Sunrise Orange',   r = 212, g = 74,  b = 23  },
    { index = 37,  label = 'Metallic Classic Gold',     r = 194, g = 142, b = 31  },
    { index = 38,  label = 'Metallic Orange',           r = 247, g = 134, b = 22  },
    { index = 39,  label = 'Matte Red',                 r = 207, g = 31,  b = 33  },
    { index = 40,  label = 'Matte Dark Red',            r = 115, g = 32,  b = 32  },
    { index = 41,  label = 'Matte Orange',              r = 242, g = 125, b = 32  },
    { index = 42,  label = 'Matte Yellow',              r = 255, g = 201, b = 31  },
    { index = 43,  label = 'Util Red',                  r = 156, g = 16,  b = 22  },
    { index = 44,  label = 'Util Bright Red',           r = 222, g = 15,  b = 15  },
    { index = 45,  label = 'Util Garnet Red',           r = 143, g = 30,  b = 23  },
    { index = 46,  label = 'Worn Red',                  r = 169, g = 71,  b = 68  },
    { index = 47,  label = 'Worn Golden Red',           r = 177, g = 108, b = 81  },
    { index = 48,  label = 'Worn Dark Red',             r = 55,  g = 28,  b = 37  },
    { index = 49,  label = 'Metallic Dark Green',       r = 19,  g = 36,  b = 40  },
    { index = 50,  label = 'Metallic Racing Green',     r = 18,  g = 46,  b = 43  },
    { index = 51,  label = 'Metallic Sea Green',        r = 18,  g = 56,  b = 60  },
    { index = 52,  label = 'Metallic Olive Green',      r = 49,  g = 66,  b = 42  },
    { index = 53,  label = 'Metallic Green',            r = 21,  g = 92,  b = 45  },
    { index = 54,  label = 'Metallic Gasoline Blue Green', r = 27, g = 103, b = 112 },
    { index = 55,  label = 'Matte Lime Green',          r = 102, g = 184, b = 31  },
    { index = 56,  label = 'Util Dark Green',           r = 34,  g = 56,  b = 62  },
    { index = 57,  label = 'Util Green',                r = 29,  g = 90,  b = 63  },
    { index = 58,  label = 'Worn Dark Green',           r = 45,  g = 66,  b = 63  },
    { index = 59,  label = 'Worn Green',                r = 69,  g = 89,  b = 75  },
    { index = 60,  label = 'Worn Sea Wash',             r = 101, g = 134, b = 127 },
    { index = 61,  label = 'Metallic Midnight Blue',    r = 34,  g = 46,  b = 70  },
    { index = 62,  label = 'Metallic Dark Blue',        r = 35,  g = 49,  b = 85  },
    { index = 63,  label = 'Metallic Saxony Blue',      r = 48,  g = 76,  b = 126 },
    { index = 64,  label = 'Metallic Blue',             r = 71,  g = 87,  b = 143 },
    { index = 65,  label = 'Metallic Mariner Blue',     r = 99,  g = 123, b = 167 },
    { index = 66,  label = 'Metallic Harbor Blue',      r = 57,  g = 71,  b = 98  },
    { index = 67,  label = 'Metallic Diamond Blue',     r = 214, g = 231, b = 241 },
    { index = 68,  label = 'Metallic Surf Blue',        r = 118, g = 175, b = 190 },
    { index = 69,  label = 'Metallic Nautical Blue',    r = 52,  g = 94,  b = 114 },
    { index = 70,  label = 'Metallic Bright Blue',      r = 11,  g = 156, b = 241 },
    { index = 71,  label = 'Metallic Purple Blue',      r = 47,  g = 45,  b = 82  },
    { index = 72,  label = 'Metallic Spinnaker Blue',   r = 40,  g = 44,  b = 77  },
    { index = 73,  label = 'Metallic Ultra Blue',       r = 35,  g = 84,  b = 161 },
    { index = 74,  label = 'Metallic Bright Blue 2',    r = 110, g = 163, b = 198 },
    { index = 75,  label = 'Util Dark Blue',            r = 17,  g = 37,  b = 82  },
    { index = 76,  label = 'Util Midnight Blue',        r = 27,  g = 32,  b = 62  },
    { index = 77,  label = 'Util Blue',                 r = 39,  g = 81,  b = 132 },
    { index = 78,  label = 'Util Sea Foam Blue',        r = 96,  g = 133, b = 146 },
    { index = 79,  label = 'Util Lightning Blue',       r = 36,  g = 70,  b = 168 },
    { index = 80,  label = 'Util Maui Blue Poly',       r = 66,  g = 113, b = 225 },
    { index = 81,  label = 'Util Bright Blue',          r = 59,  g = 57,  b = 224 },
    { index = 82,  label = 'Matte Dark Blue',           r = 31,  g = 40,  b = 82  },
    { index = 83,  label = 'Matte Blue',                r = 37,  g = 58,  b = 167 },
    { index = 84,  label = 'Matte Midnight Blue',       r = 28,  g = 53,  b = 81  },
    { index = 85,  label = 'Worn Dark Blue',            r = 76,  g = 95,  b = 129 },
    { index = 86,  label = 'Worn Blue',                 r = 88,  g = 104, b = 142 },
    { index = 87,  label = 'Worn Light Blue',           r = 116, g = 181, b = 216 },
    { index = 88,  label = 'Metallic Taxi Yellow',      r = 255, g = 207, b = 32  },
    { index = 89,  label = 'Metallic Race Yellow',      r = 251, g = 226, b = 18  },
    { index = 90,  label = 'Metallic Bronze',           r = 145, g = 101, b = 50  },
    { index = 91,  label = 'Metallic Yellow Bird',      r = 224, g = 225, b = 61  },
    { index = 92,  label = 'Metallic Lime',             r = 152, g = 210, b = 35  },
    { index = 93,  label = 'Metallic Champagne',        r = 155, g = 140, b = 120 },
    { index = 94,  label = 'Metallic Pueblo Beige',     r = 80,  g = 50,  b = 24  },
    { index = 95,  label = 'Metallic Dark Ivory',       r = 71,  g = 60,  b = 42  },
    { index = 96,  label = 'Metallic Choco Brown',      r = 34,  g = 27,  b = 25  },
    { index = 97,  label = 'Metallic Golden Brown',     r = 101, g = 63,  b = 35  },
    { index = 98,  label = 'Metallic Light Brown',      r = 119, g = 92,  b = 62  },
    { index = 99,  label = 'Metallic Straw Beige',      r = 172, g = 153, b = 117 },
    { index = 100, label = 'Metallic Moss Brown',       r = 108, g = 107, b = 75  },
    { index = 101, label = 'Metallic Biston Brown',     r = 64,  g = 46,  b = 43  },
    { index = 102, label = 'Metallic Beechwood',        r = 164, g = 150, b = 95  },
    { index = 103, label = 'Metallic Dark Beechwood',   r = 70,  g = 35,  b = 26  },
    { index = 104, label = 'Metallic Choco Orange',     r = 117, g = 43,  b = 25  },
    { index = 105, label = 'Metallic Beach Sand',       r = 191, g = 174, b = 123 },
    { index = 106, label = 'Metallic Sun Bleeched Sand',r = 223, g = 213, b = 178 },
    { index = 107, label = 'Metallic Cream',            r = 247, g = 237, b = 213 },
    { index = 108, label = 'Util Brown',                r = 58,  g = 42,  b = 27  },
    { index = 109, label = 'Util Medium Brown',         r = 120, g = 95,  b = 51  },
    { index = 110, label = 'Util Light Brown',          r = 181, g = 160, b = 121 },
    { index = 111, label = 'Metallic White',            r = 255, g = 255, b = 246 },
    { index = 112, label = 'Metallic Frost White',      r = 234, g = 234, b = 234 },
    { index = 113, label = 'Worn Honey Beige',          r = 176, g = 171, b = 148 },
    { index = 114, label = 'Worn Brown',                r = 69,  g = 56,  b = 49  },
    { index = 115, label = 'Worn Dark Brown',           r = 42,  g = 40,  b = 43  },
    { index = 116, label = 'Worn Straw Beige',          r = 114, g = 108, b = 87  },
    { index = 117, label = 'Brushed Steel',             r = 106, g = 116, b = 124 },
    { index = 118, label = 'Brushed Black Steel',       r = 53,  g = 65,  b = 88  },
    { index = 119, label = 'Brushed Aluminium',         r = 155, g = 160, b = 168 },
    { index = 120, label = 'Chrome',                    r = 88,  g = 112, b = 161 },
    { index = 121, label = 'Worn Off White',            r = 234, g = 230, b = 222 },
    { index = 122, label = 'Util Off White',            r = 223, g = 221, b = 208 },
    { index = 123, label = 'Worn Orange',               r = 242, g = 173, b = 46  },
    { index = 124, label = 'Worn Light Orange',         r = 249, g = 164, b = 88  },
    { index = 125, label = 'Metallic Securicor Green',  r = 131, g = 197, b = 102 },
    { index = 126, label = 'Worn Taxi Yellow',          r = 241, g = 204, b = 64  },
    { index = 127, label = 'Police Car Blue',           r = 76,  g = 195, b = 218 },
    { index = 128, label = 'Matte Green',               r = 78,  g = 100, b = 67  },
    { index = 129, label = 'Matte Brown',               r = 188, g = 172, b = 143 },
    { index = 130, label = 'Worn Orange 2',             r = 248, g = 182, b = 88  },
    { index = 131, label = 'Matte White',               r = 252, g = 249, b = 241 },
    { index = 132, label = 'Worn White',                r = 255, g = 255, b = 251 },
    { index = 133, label = 'Worn Olive Army Green',     r = 129, g = 132, b = 76  },
    { index = 134, label = 'Pure White',                r = 255, g = 255, b = 255 },
    { index = 135, label = 'Hot Pink',                  r = 242, g = 31,  b = 153 },
    { index = 136, label = 'Salmon Pink',               r = 253, g = 214, b = 197 },
    { index = 137, label = 'Metallic Vermillion Pink',  r = 223, g = 88,  b = 145 },
    { index = 138, label = 'Orange',                    r = 246, g = 174, b = 32  },
    { index = 139, label = 'Green',                     r = 176, g = 238, b = 110 },
    { index = 140, label = 'Blue',                      r = 8,   g = 233, b = 250 },
    { index = 141, label = 'Mettalic Black Blue',       r = 10,  g = 12,  b = 23  },
    { index = 142, label = 'Metallic Black Purple',     r = 12,  g = 13,  b = 24  },
    { index = 143, label = 'Metallic Black Red',        r = 14,  g = 13,  b = 20  },
    { index = 144, label = 'Hunter Green',              r = 159, g = 158, b = 138 },
    { index = 145, label = 'Metallic Purple',           r = 98,  g = 18,  b = 118 },
    { index = 146, label = 'Metallic V Dark Blue',      r = 11,  g = 20,  b = 33  },
    { index = 147, label = 'MODSHOP BLACK1',            r = 17,  g = 20,  b = 26  },
    { index = 148, label = 'Matte Purple',              r = 107, g = 31,  b = 123 },
    { index = 149, label = 'Matte Dark Purple',         r = 30,  g = 29,  b = 34  },
    { index = 150, label = 'Metallic Lava Red',         r = 188, g = 25,  b = 23  },
    { index = 151, label = 'Matte Forest Green',        r = 45,  g = 54,  b = 42  },
    { index = 152, label = 'Matte Olive Drab',          r = 105, g = 103, b = 72  },
    { index = 153, label = 'Matte Desert Brown',        r = 122, g = 108, b = 85  },
    { index = 154, label = 'Matte Desert Tan',          r = 195, g = 180, b = 146 },
    { index = 155, label = 'Matte Foliage Green',       r = 90,  g = 99,  b = 82  },
    { index = 156, label = 'DEFAULT ALLOY COLOR',       r = 129, g = 130, b = 127 },
    { index = 157, label = 'Epsilon Blue',              r = 175, g = 214, b = 228 },
    { index = 158, label = 'Pure Gold',                 r = 122, g = 100, b = 64  },
    { index = 159, label = 'Brushed Gold',              r = 127, g = 106, b = 72  },
}

-- [SPECIAL MODS — Apocalypse vehicles only]
Config.SpecialMods = {
    { id = 'jump',      label = 'Saut',              modIndex = 54, levels = { { v = -1, label = 'Aucun' }, { v = 0, label = 'Boost Jump' }, { v = 1, label = 'Super Jump' } } },
    { id = 'turret',    label = 'Tourelle latérale', modIndex = 52, levels = { { v = -1, label = 'Aucune' }, { v = 0, label = 'Activée' } } },
    { id = 'thrusters', label = 'Propulseurs',       modIndex = 53, levels = { { v = -1, label = 'Aucun' }, { v = 0, label = 'Activés' } } },
    { id = 'ram',       label = 'Bélier',            modIndex = 55, levels = { { v = -1, label = 'Aucun' }, { v = 0, label = 'Standard' }, { v = 1, label = 'Renforcé' } } },
    { id = 'boost',     label = 'Boost',             modIndex = 56, levels = { { v = -1, label = 'Aucun' }, { v = 0, label = 'Nitrous' }, { v = 1, label = 'Fusée' } } },
}
