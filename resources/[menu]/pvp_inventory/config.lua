Config = {}

-- Token du bot Discord pour récupérer l'avatar des joueurs (optionnel)
Config.DiscordBotToken = ''

-- Clé API Steam — lue automatiquement depuis server.cfg (steam_webApiKey)
if IsDuplicityVersion then
    Config.SteamApiKey = GetConvar('steam_webApiKey', '')
else
    Config.SteamApiKey = ''
end

-- Poids max que le joueur peut porter (kg)
Config.MaxWeight = 50.0

-- Les poids des items sont définis dans server.lua (table ITEM_WEIGHTS)
-- pour être la source de vérité unique côté serveur.
-- Ne pas dupliquer ici pour éviter les désynchronisations.
