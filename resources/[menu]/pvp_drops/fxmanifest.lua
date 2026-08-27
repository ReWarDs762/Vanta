fx_version 'cerulean'
game 'gta5'

name 'pvp_drops'
description 'Système de drop de ravitaillement - avion + caisse'
version '1.2.0'

shared_scripts {
    'config.lua',
}

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server/server.lua',
}

client_scripts {
    'client/client.lua',
}

-- Texture de la flèche de trajectoire (chargée via CreateRuntimeTextureFromImage)
files {
    'html/img/arrow.png',
}

-- Dépendances réelles (elles étaient implicites avant — un changement d'ordre
-- dans server.cfg cassait la resource silencieusement) :
--   es_extended    → ESX.GetPlayerFromId / getInventory / getAccount
--   vanta_ui       → exports notify (notifications génériques)
--   pvp_inventory  → export canAddToBag + events openUIWithDrop / refreshFromDrop
dependencies {
    'es_extended',
    'vanta_ui',
    'pvp_inventory',
}
