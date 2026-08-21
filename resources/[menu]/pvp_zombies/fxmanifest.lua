fx_version 'cerulean'
game 'gta5'

name        'pvp_zombies'
description 'Zombies PVP — Spawn dynamique, IA hostile, loot, récompenses'
version     '1.0.0'
author      'MonServeur'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    'server/server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependencies {
    'es_extended',
    'pvp_outposts',
    'vanta_ui'
}
