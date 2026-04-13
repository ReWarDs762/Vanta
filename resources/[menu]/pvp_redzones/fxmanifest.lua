fx_version 'cerulean'
game 'gta5'

name 'pvp_redzones'
description 'Système de Redzones PVP - Zones dangereuses avec loot amélioré'
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

dependencies {
    'es_extended',
    'mysql-async',
    'pvp_outposts',
}
