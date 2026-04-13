fx_version 'cerulean'
game 'gta5'

name 'pvp_admin'
description 'PVP Extinction — Panel d\'administration complet'
author 'PVP Extinction'
version '2.0.0'

dependencies { 'vanta_ui' }

shared_scripts { 'config.lua' }
server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server/server.lua',
}
client_scripts { 'client/client.lua' }

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}
