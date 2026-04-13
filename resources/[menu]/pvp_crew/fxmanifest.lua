fx_version 'cerulean'
game 'gta5'

description 'PVP Extinction — Crew & Squad System'
author 'PVP Extinction'

ui_page 'html/crew.html'

files {
    'html/crew.html',
    'html/crew.css',
    'html/crew.js',
}

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/client.lua',
}

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server/server.lua',
}

dependencies {
    'es_extended',
    'mysql-async',
}
