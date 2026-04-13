fx_version 'cerulean'
game 'gta5'

name        'pvp_spawn'
description 'Gestionnaire de spawn PVP - Sandy Shores multi-points'
version     '1.0.0'
author      'MonServeur'

client_scripts {
    'client/client.lua'
}

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server/server.lua'
}

dependencies {
    'spawnmanager',
    'es_extended'
}
