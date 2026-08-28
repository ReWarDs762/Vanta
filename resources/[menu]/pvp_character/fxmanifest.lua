fx_version 'cerulean'
game 'gta5'

author 'VANTA'
description 'Création de personnage — pseudo + genre'
version '1.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    -- Etat corporel impose (sous-vetement) : partage client/serveur pour que la
    -- validation cote serveur parle des memes valeurs que le rendu cote client.
    'shared/body.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    '@es_extended/imports.lua',
    '@mysql-async/lib/MySQL.lua',
    'server/server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/appearance_data.js',
    'html/app.js'
}

-- pvp_inventory : fournit le catalogue de peds partagé (nui://pvp_inventory/html/ped_catalog.js)
-- et les exports GetPedTier/IsPedInCatalog consommés par server/server.lua.
dependencies {
    'es_extended',
    'mysql-async',
    'vanta_ui',
    'pvp_inventory',
}
