-- =============================================
--   PVP OUTPOSTS - Table coffres joueurs
--   Exécuter UNE FOIS dans phpMyAdmin
-- =============================================

CREATE TABLE IF NOT EXISTS `pvp_player_stash` (
    `id`          INT(11)       NOT NULL AUTO_INCREMENT,
    `identifier`  VARCHAR(60)   NOT NULL,
    `outpost_id`  VARCHAR(30)   NOT NULL,
    `items`       LONGTEXT      DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_stash` (`identifier`, `outpost_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
