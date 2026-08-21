Config                      = {}

Config.Locale               = 'fr'



-- Comptes disponibles : dollars uniquement
Config.Accounts             = { 'bank' }
Config.AccountLabels        = { bank = 'Dollars' }

-- PVP : pas de société/emploi
Config.EnableSocietyPayouts = false

-- Pas de point au-dessus des joueurs (PVP)
Config.ShowDotAbovePlayer   = false

-- Niveau de recherche désactivé (pas de police)
Config.DisableWantedLevel   = true

-- HUD ESX désactivé : on utilise pvp_hud à la place
Config.EnableHud            = false

-- Pas de salaire automatique (l'argent vient des zombies et du marché)
Config.EnablePaycheck       = false
Config.PaycheckInterval     = 30 * 60000

Config.MaxPlayers           = GetConvarInt('sv_maxclients', 64)

Config.EnableDebug          = false

-- Spawn par défaut : Sandy Shores Airfield (zone ouverte, bon pour PVP)
Config.DefaultSpawnPos      = vector3(1747.0, 3273.0, 41.1)
Config.DefaultSpawnVar      = 0.0

-- Argent de départ : 500$ pour acheter quelques items de base
Config.StartingAccountMoney = {bank = 500}

Config.EnableCash           = true
