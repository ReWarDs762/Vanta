-- =============================================
--   PVP MARKET - Tables BDD
--   Exécuter UNE FOIS dans phpMyAdmin
-- =============================================

-- Annonces actives
CREATE TABLE IF NOT EXISTS `pvp_market_listings` (
    `id`                 INT(11)      NOT NULL AUTO_INCREMENT,
    `seller_identifier`  VARCHAR(60)  NOT NULL,
    `seller_name`        VARCHAR(100) NOT NULL DEFAULT '',
    `item_name`          VARCHAR(50)  NOT NULL,
    `item_label`         VARCHAR(100) NOT NULL DEFAULT '',
    `quantity`           INT(11)      NOT NULL DEFAULT 1,
    `price`              INT(11)      NOT NULL,
    `currency`           VARCHAR(20)  NOT NULL DEFAULT 'bank',
    `created_at`         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_seller` (`seller_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Paiements en attente (vendeur hors-ligne au moment de la vente)
CREATE TABLE IF NOT EXISTS `pvp_market_pending_payments` (
    `id`         INT(11)     NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60) NOT NULL,
    `currency`   VARCHAR(20) NOT NULL DEFAULT 'bank',
    `amount`     INT(11)     NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_pending` (`identifier`, `currency`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
