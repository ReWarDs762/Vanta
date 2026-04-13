-- ═══════════════════════════════════════════════════════════════════════════
--   VANTA XP — Système de progression XP / Niveaux / Prestige
--   ESX Legacy + mysql-async
-- ═══════════════════════════════════════════════════════════════════════════
fx_version 'cerulean'
game 'gta5'

name        'vanta_xp'
description 'Système XP, niveaux 1-100, prestige 0-5 avec bonus capacité'
version     '1.0.0'
author      'VANTA'

shared_scripts { 'config.lua' }

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server.lua',
}

client_scripts { 'client.lua' }

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

dependencies {
    'es_extended',
    'mysql-async',
    'pvp_inventory',
}
