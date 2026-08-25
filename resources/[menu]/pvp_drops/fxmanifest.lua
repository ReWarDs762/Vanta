fx_version 'cerulean'
game 'gta5'

name 'pvp_drops'
description 'Système de drop de ravitaillement - avion + caisse légendaire'
version '1.0.0'

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

dependencies {
    'es_extended',
}
