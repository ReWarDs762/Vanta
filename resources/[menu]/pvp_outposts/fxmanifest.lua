fx_version 'cerulean'
game 'gta5'

name        'pvp_outposts'
description 'Avant-postes PVP : zones safe, téléport, boutique, coffres'
version     '1.0.0'
author      'MonServeur'

ui_page 'html/shop.html'

files {
    'html/shop.html',
    'html/shop.css',
    'html/shop.js',
    'html/teleport.css',
    'html/teleport.js',
    'html/img/gtav_map.jpg',
    'html/weapon_custom.css',
    'html/weapon_custom.js',
}

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

exports {
    'applyWeaponCustomForItem'
}

dependencies {
    'es_extended',
    'mysql-async',
    'esx_menu_default'
}
