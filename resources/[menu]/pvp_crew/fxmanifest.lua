fx_version 'cerulean'
game 'gta5'

description 'PVP Extinction — Crew & Squad System'
author 'PVP Extinction'

ui_page 'html/crew.html'

files {
    'html/crew.html',
    'html/crew.css',
    'html/crew.js',
}

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/client.lua',
}

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server/server.lua',
}

dependencies {
    'es_extended',
    'mysql-async',
    -- Boutique de crew : le bonus « conteneur » est appliqué et retiré via
    -- `exports['pvp_inventory']:setContainerBonus(identifier, bonus, 'crew')`
    -- (connexion, exclusion, dissolution, expiration). Sans pvp_inventory,
    -- l'avantage acheté en crédits de crew n'a aucun effet.
    -- `server.cfg` charge bien pvp_inventory (46) avant pvp_crew (49).
    'pvp_inventory',
}
