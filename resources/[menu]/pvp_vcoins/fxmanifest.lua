fx_version 'cerulean'
game 'gta5'

name        'pvp_vcoins'
description 'VANTA — VCoins, abonnements Gold/Diamond, marché joueur'
author      'VANTA'
version     '1.0.0'

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server/server.lua',
}

client_scripts {
    'client/client.lua',
}

lua54 'yes'
