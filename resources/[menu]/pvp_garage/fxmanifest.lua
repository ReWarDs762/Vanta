fx_version 'cerulean'
game 'gta5'

name 'pvp_garage'
description 'Vehicle customization & dealer — PVP Extinction'
author 'PVP Extinction'
version '1.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/dealer.css',
    'html/app.js',
}
