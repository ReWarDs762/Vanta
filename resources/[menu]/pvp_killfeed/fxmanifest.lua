fx_version 'cerulean'
game 'gta5'

name 'pvp_killfeed'
description 'Killfeed, Kill Leader et Crew Leader en temps réel'
version '1.0.0'

ui_page 'html/killfeed.html'

files {
    'html/killfeed.html',
    'html/killfeed.css',
    'html/killfeed.js',
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
}
