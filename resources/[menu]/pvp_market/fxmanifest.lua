fx_version 'cerulean'
game 'gta5'

name        'pvp_market'
description 'Marché libre joueur à joueur — vente, achat, annonces'
version     '1.0.0'
author      'MonServeur'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server/server.lua'
}

dependencies {
    'es_extended',
    'mysql-async',
    'pvp_outposts',
    'vanta_ui'
}
