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

dependencies {
    'es_extended',
    'pvp_outposts'
}
