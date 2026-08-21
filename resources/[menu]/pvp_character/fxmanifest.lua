fx_version 'cerulean'
game 'gta5'

author 'VANTA'
description 'Création de personnage — pseudo + genre'
version '1.0.0'

shared_scripts {
    '@es_extended/imports.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    '@es_extended/imports.lua',
    '@mysql-async/lib/MySQL.lua',
    'server/server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}
