fx_version 'cerulean'
game 'gta5'

description 'VANTA Design System v2 — Shared UI tokens, components & notifications'
author 'VANTA'
version '2.1.0'

-- vanta_ui expose deux choses :
--  1. Le design system partagé (vanta.css), importé par les autres resources via
--     nui://vanta_ui/html/vanta.css — index.html en est le showcase hors jeu.
--  2. Un système de notifications générique (ui_page notify.html) utilisable par
--     n'importe quelle resource sans dépendre de pvp_market / pvp_inventory :
--        exports['vanta_ui']:notify(src, 'Message', 'success')   -- serveur
--        exports['vanta_ui']:notify('Message', 'success')        -- client
--
-- notify.html est volontairement transparent et sans interaction : SetNuiFocus
-- n'est jamais appelé, le NUI ne vole donc jamais l'input au joueur.

ui_page 'html/notify.html'

client_scripts {
    'client/notify.lua',
}

server_scripts {
    'server/notify.lua',
}

files {
    'html/vanta.css',
    'html/notify.html',
    'html/notify.js',
}
