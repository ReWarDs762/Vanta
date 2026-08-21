-- =============================================
--   PVP REDZONES - Configuration
-- =============================================

Config = {}

-- Nombre de redzones actives simultanément
Config.ActiveCount = 3

-- Durée d'une rotation (en minutes)
Config.RotationMinutes = 60

-- Rayon des redzones (en mètres)
Config.RedZoneRadius = 150.0

-- Multiplicateur de loot en redzone (les chances des items rares sont multipliées)
Config.LootMultiplier = 2.0

-- Multiplicateur de récompense en cash en redzone
Config.CashMultiplier = 2.5

-- Contrôle crew des redzones
Config.ControlPointsPerKill = 10
Config.ControlThreshold = 50
Config.ControlLeadRequired = 20
Config.ControlRewardXP = 150
Config.ControlRewardBank = 250

-- Couleur du blip redzone
Config.BlipColor = 1      -- rouge
Config.BlipAlpha = 100     -- transparence du cercle sur la map

-- ── Zones potentielles (proches des avant-postes mais hors zone safe) ────
-- Chaque zone a un centre et un label. 3 seront choisies aléatoirement chaque heure.
Config.Zones = {
    -- Casino Diamond — zone urbaine, bâtiments, cover partout
    {
        id     = 'rz_casino',
        label  = 'Diamond Casino',
        coords = vector3(929.0, 47.0, 81.0),
    },
    -- Aéroport LSIA — hangar, terminal, open field + bâtiments
    {
        id     = 'rz_airport',
        label  = 'Aéroport LSIA',
        coords = vector3(-1300.0, -2900.0, 14.0),
    },
    -- Sandy Shores Airfield — hangars, piste, bâtiments abandonnés
    {
        id     = 'rz_ss_airfield',
        label  = 'Sandy Shores Airfield',
        coords = vector3(1748.0, 3300.0, 41.0),
    },
    -- Prison Bolingbroke — murs, cours intérieure, cover béton
    {
        id     = 'rz_prison',
        label  = 'Prison Bolingbroke',
        coords = vector3(1635.0, 2519.0, 45.0),
    },
    -- Humane Labs — installation désertique, bâtiments, clôtures
    {
        id     = 'rz_humane_labs',
        label  = 'Humane Labs',
        coords = vector3(3619.0, 3741.0, 28.0),
    },
    -- Elysian Island / Port — zone industrielle, grues, containers
    {
        id     = 'rz_elysian_port',
        label  = 'Port Elysian',
        coords = vector3(600.0, -2800.0, 6.0),
    },
    -- La Mesa — zone industrielle est LS, entrepôts, rues étroites
    {
        id     = 'rz_la_mesa',
        label  = 'La Mesa',
        coords = vector3(850.0, -2100.0, 30.0),
    },
    -- Maze Bank Arena — stade + parking immense, zone ouverte
    {
        id     = 'rz_arena',
        label  = 'Maze Bank Arena',
        coords = vector3(-290.0, -2000.0, 22.0),
    },
    -- Pillbox Hill / Downtown LS — gratte-ciels, rues, parkings
    {
        id     = 'rz_downtown',
        label  = 'Downtown LS',
        coords = vector3(250.0, -700.0, 35.0),
    },
    -- Rockford Hills — quartier résidentiel, rues, maisons
    {
        id     = 'rz_rockford',
        label  = 'Rockford Hills',
        coords = vector3(-650.0, -300.0, 36.0),
    },
    -- Paleto Bay — ville côtière, rues, bâtiments variés
    {
        id     = 'rz_paleto_bay',
        label  = 'Paleto Bay',
        coords = vector3(-300.0, 6250.0, 31.0),
    },
    -- Sandy Shores — ville désertique, maisons, ateliers, rues
    {
        id     = 'rz_sandy_shores',
        label  = 'Sandy Shores',
        coords = vector3(1850.0, 3700.0, 32.0),
    },
    -- Fort Zancudo — base militaire, bâtiments, hangars, piste
    {
        id     = 'rz_zancudo',
        label  = 'Fort Zancudo',
        coords = vector3(-2180.0, 3215.0, 32.0),
    },
    -- Del Perro / Pier — front de mer, pier, bâtiments côtiers
    {
        id     = 'rz_del_perro',
        label  = 'Del Perro Pier',
        coords = vector3(-1595.0, -1110.0, 5.0),
    },
    -- Davis / Strawberry — quartier sud LS, rues urbaines, bâtiments
    {
        id     = 'rz_davis',
        label  = 'Davis',
        coords = vector3(100.0, -1700.0, 30.0),
    },
}
