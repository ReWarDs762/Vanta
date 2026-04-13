-- =============================================
--   PVP HUD - Manifest
-- =============================================

fx_version 'cerulean'
game 'gta5'

name        'pvp_hud'
description 'VANTA HUD - Vie, Kevlar, Arme — Design System v2'
version     '2.0.0'
author      'VANTA'

dependencies {
    'vanta_ui'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    'server/server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html'
}
