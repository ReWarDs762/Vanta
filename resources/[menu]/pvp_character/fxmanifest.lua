fx_version 'cerulean'
game 'gta5'

author 'VANTA'
description 'Création de personnage — pseudo + genre'
version '1.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    -- Table de tenues (composants 11 + 3 + 8 validés ensemble) : partagée
    -- client/serveur pour que les bornes de validation soient les mêmes des
    -- deux côtés. tops_data.lua est généré par la commande admin /topbuilder
    -- et doit être chargé AVANT tops.lua qui l'expose.
    'shared/tops_data.lua',
    'shared/tops.lua'
}

client_scripts {
    'client/client.lua',
    'client/topbuilder.lua'
}

server_scripts {
    '@es_extended/imports.lua',
    '@mysql-async/lib/MySQL.lua',
    'server/server.lua',
    'server/topbuilder.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/appearance_data.js',
    'html/app.js',
    -- Table haut → torse, lue à la demande par l'outil de dev /topbuilder via
    -- LoadResourceFile : déclarée ici, mais jamais chargée en jeu normal.
    -- Provenance et limites : data/SOURCE.md
    'data/besttorso.json'
}

-- pvp_inventory : fournit le catalogue de peds partagé (nui://pvp_inventory/html/ped_catalog.js)
-- et les exports GetPedTier/IsPedInCatalog consommés par server/server.lua.
dependencies {
    'es_extended',
    'mysql-async',
    'vanta_ui',
    'pvp_inventory',
}
