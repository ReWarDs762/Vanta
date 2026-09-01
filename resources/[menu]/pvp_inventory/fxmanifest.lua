fx_version 'cerulean'
game 'gta5'

name        'pvp_inventory'
description 'Inventaire custom — Inventaire / Marché / Profil / Crew'
version     '1.0.0'
author      'MonServeur'

shared_scripts { 'config.lua' }

client_scripts { 'client/client.lua' }

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server/server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/ped_catalog.js',
    'html/badges.js',
    'html/app.js',
    'html/img/*.png'
}

dependencies {
    'es_extended',
    'mysql-async',
    'vanta_ui'
}
