fx_version 'cerulean'
game 'gta5'

name        'pvp_vcoins'
description 'VANTA — VCoins, abonnements Gold/Diamond, marché joueur'
author      'VANTA'
version     '1.0.0'

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server/server.lua',
}

client_scripts {
    'client/client.lua',
}

dependencies {
    'es_extended',
    'mysql-async',
}

-- NON déclaré : `pvp_inventory`. `server/server.lua` pousse le bonus de stash
-- d'abonnement via `exports['pvp_inventory']:setContainerBonus(id, bonus,
-- 'subscription')` et débloque les badges gold/diamond via `unlockBadge`, mais
-- `server.cfg` charge délibérément pvp_vcoins AVANT pvp_inventory (ce dernier
-- consomme `GetTier`). Les deux appels sont résolus à l'exécution et protégés
-- par pcall.
lua54 'yes'
