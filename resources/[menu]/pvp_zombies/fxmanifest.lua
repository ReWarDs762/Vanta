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

-- Plus de ui_page : le toast de loot local a ete remplace par la pile
-- partagee de vanta_ui (voir client/client.lua, pvp_zombies:receiveLoot).
-- Le dossier html/ est conserve mais n est plus charge.

dependencies {
    'es_extended',
    'pvp_outposts',
    'vanta_ui'
}
