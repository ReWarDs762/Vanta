-- =============================================
--   PVP ZOMBIES - Items ESX
--   Exécuter UNE FOIS dans phpMyAdmin
-- =============================================

INSERT IGNORE INTO `items` (`name`, `label`, `limit`, `rare`, `can_remove`) VALUES
('bandage',       'Bandage',          10,  0, 1),
('medkit',        'Kit de soins',     5,   0, 1),
('food',          'Nourriture',       10,  0, 1),
('water',         'Eau',              10,  0, 1),
('kevlar',        'Kevlar',           3,   0, 1),
('ammo_pistol',   'Munitions Pistol', 20,  0, 1),
('ammo_rifle',    'Munitions Rifle',  20,  0, 1),
('ammo_sniper',   'Munitions Sniper', 10,  0, 1),
('weapon_pistol', 'Pistolet',         1,   1, 1);
