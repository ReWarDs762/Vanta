fx_version 'cerulean'
game 'gta5'

name 'pvp_garage'
description 'Vehicle customization & dealer — PVP Extinction'
author 'PVP Extinction'
version '1.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/dealer.css',
    'html/app.js',
}

dependencies {
    'es_extended',
    -- Chargé au moment où la NUI s'affiche :
    -- html/index.html fait <link href="nui://vanta_ui/html/vanta.css">.
    'vanta_ui',
}

-- NON déclaré : `pvp_outposts`. `server/main.lua` appelle bien
-- `exports['pvp_outposts']:getAllOutposts()` (contrôle zone safe du
-- concessionnaire), mais `server.cfg` charge délibérément pvp_garage AVANT
-- pvp_outposts — ce dernier redirige tout son NPC garage vers cette resource.
-- L'appel est résolu à l'exécution et protégé par pcall : le déclarer ici
-- inverserait un ordre voulu sans rien gagner.
