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

dependencies {
    -- La mort par combat-log est entièrement déléguée : à la déconnexion en
    -- combat, `server/server.lua` émet `pvp_inventory:combatLogDeath`. Sans
    -- `pvp_inventory` démarré, l'anti combat-log ne fait plus rien du tout —
    -- le joueur se déconnecte en plein fight et garde son sac.
    'pvp_inventory',
}

-- Relation inverse, volontairement NON déclarée ici : `pvp_inventory` appelle
-- `exports['pvp_combat']:isInCombat` pour bloquer le dépôt au coffre protégé.
-- La déclarer des deux côtés ferait un cycle de dépendances ; l'appel est
-- résolu à l'exécution et protégé par pcall, donc l'ordre de démarrage n'a pas
-- d'incidence (`server.cfg` charge pvp_inventory avant pvp_combat).
