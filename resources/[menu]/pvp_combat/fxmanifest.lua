-- =============================================
--   PVP COMBAT - Manifest
--   Mode combat : anti combat-log + restrictions associées (coffre protégé)
-- =============================================

fx_version 'cerulean'
game 'gta5'

name        'pvp_combat'
description 'VANTA - Mode combat (anti combat-log, restrictions en combat)'
version     '1.0.0'
author      'VANTA'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    'server/server.lua'
}
