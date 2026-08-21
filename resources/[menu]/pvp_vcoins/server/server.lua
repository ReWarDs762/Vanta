-- =============================================
--   PVP_VCOINS — Serveur
--   VCoins, abonnements Gold/Diamond, marché
-- =============================================

local ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- ── Configuration ─────────────────────────────────────────────────────────
local TIERS = {
    gold    = { label = 'GOLD',    price = 800,  stash_bonus = 5.0  },
    diamond = { label = 'DIAMOND', price = 1500, stash_bonus = 10.0 },
}
local SUB_DURATION_DAYS  = 30
local MARKET_MAX_OFFERS  = 5

-- Webhook Tebex — à remplir après création du compte :
-- 1) Va dans ton dashboard Tebex → Settings → Webhooks
-- 2) URL : http://TON_IP:30120/pvp_vcoins/tebex/<TEBEX_URL_SECRET>
--    (ex: http://1.2.3.4:30120/pvp_vcoins/tebex/Xk9aB2pQ8mV4nL7rW5yT)
-- 3) Copie le secret ici — DOIT être la même chaîne que dans l'URL :
-- IMPORTANT : génère une chaîne aléatoire d'au moins 32 caractères (ex: openssl rand -hex 32).
-- C'est la première barrière : sans ce secret dans l'URL, tout POST est rejeté.
local TEBEX_URL_SECRET = 'CHANGE_ME_TO_A_LONG_RANDOM_STRING_32_CHARS_MIN'

-- Mappe tes package IDs Tebex vers les montants de VCoins :
-- [ID_PACKAGE_TEBEX] = montant_vcoins
local TEBEX_PACKAGES = {
    -- [1001] = 100,    -- Pack Starter  : 100 VC = 1€
    -- [1002] = 550,    -- Pack Standard : 550 VC = 5€  (+50 bonus)
    -- [1003] = 1200,   -- Pack Premium  : 1200 VC = 10€ (+200 bonus)
    -- [1004] = 2800,   -- Pack Ultimate : 2800 VC = 20€ (+800 bonus)
}

-- ── Cache mémoire ─────────────────────────────────────────────────────────
-- [identifier] = { tier='none'|'gold'|'diamond', vcoins=N, expires='2025-06-01 12:00:00' }
local cache = {}

-- ── Migrations DB ─────────────────────────────────────────────────────────
-- Helper : ajoute une colonne seulement si elle n'existe pas.
-- Évite `ADD COLUMN IF NOT EXISTS` (syntaxe MariaDB / MySQL 8.0.29+ uniquement).
local function addColumnIfMissing(tbl, col, definition)
    MySQL.Async.fetchScalar(
        [[SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
          WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = @t AND COLUMN_NAME = @c]],
        { ['@t'] = tbl, ['@c'] = col },
        function(count)
            if (tonumber(count) or 0) == 0 then
                MySQL.Async.execute('ALTER TABLE `' .. tbl .. '` ADD COLUMN `' .. col .. '` ' .. definition)
            end
        end
    )
end

Citizen.CreateThread(function()
    Citizen.Wait(2000)

    -- Pas de clauses AFTER : les colonnes sont ajoutées en fin de table (l'ordre n'impacte pas la logique).
    -- Éviter AFTER évite une race condition : les 3 checks tournent en parallèle, donc si
    -- `subscription` est vérifié avant que `vcoins` soit réellement créé, l'ALTER échoue.
    addColumnIfMissing('users', 'vcoins',         'INT DEFAULT 0')
    addColumnIfMissing('users', 'subscription',   "VARCHAR(10) DEFAULT 'none'")
    addColumnIfMissing('users', 'sub_expires_at', 'DATETIME NULL')

    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `vcoin_market` (
            `id`                INT AUTO_INCREMENT PRIMARY KEY,
            `seller_identifier` VARCHAR(100) NOT NULL,
            `seller_name`       VARCHAR(50)  NOT NULL,
            `vcoin_amount`      INT          NOT NULL,
            `price_ingame`      INT          NOT NULL,
            `created_at`        DATETIME     DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_seller (`seller_identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `vcoin_pending_bank` (
            `identifier` VARCHAR(100) PRIMARY KEY,
            `amount`     INT          DEFAULT 0
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    -- Idempotence Tebex : on stocke chaque transaction_id reçue pour refuser les replays.
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `vcoin_tebex_transactions` (
            `transaction_id` VARCHAR(100) PRIMARY KEY,
            `identifier`     VARCHAR(100) NOT NULL,
            `amount`         INT          NOT NULL,
            `processed_at`   DATETIME     DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_identifier (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    print('[pvp_vcoins] Migrations DB OK')
end)

-- ── Helpers ───────────────────────────────────────────────────────────────
local function notify(src, msg)
    TriggerClientEvent('esx:showNotification', src, msg)
end

local function isValidTier(tier)
    return tier == 'gold' or tier == 'diamond'
end

-- ── Chargement joueur au login ────────────────────────────────────────────
AddEventHandler('esx:playerLoaded', function(playerId)
    local src = type(playerId) == 'table' and playerId.source or playerId
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local id = xPlayer.identifier

    -- Charge solde + subscription (vérifie l'expiry côté SQL)
    MySQL.Async.fetchAll([[
        SELECT
            vcoins,
            IF(subscription IS NOT NULL AND sub_expires_at IS NOT NULL AND sub_expires_at > NOW(),
               subscription, 'none') AS active_tier,
            sub_expires_at
        FROM users
        WHERE identifier = @id
    ]], { ['@id'] = id }, function(result)
        local row    = result and result[1]
        local tier   = row and row.active_tier or 'none'
        local vcoins = row and tonumber(row.vcoins) or 0
        local expires = row and row.sub_expires_at or nil

        -- Si la sub est expirée en DB mais pas encore nettoyée → nettoie
        if row and (row.subscription or 'none') ~= 'none' and tier == 'none' then
            MySQL.Async.execute(
                "UPDATE users SET subscription='none', sub_expires_at=NULL WHERE identifier=@id",
                { ['@id'] = id }
            )
        end

        cache[id] = { tier = tier, vcoins = vcoins, expires = expires }

        -- Applique le bonus de conteneur à pvp_inventory
        local bonus = (TIERS[tier] and TIERS[tier].stash_bonus) or 0.0
        local ok = pcall(function()
            exports['pvp_inventory']:setContainerBonus(id, bonus)
        end)
        if not ok then
            print('[pvp_vcoins] WARN: pvp_inventory:setContainerBonus non disponible')
        end

        -- Débloque le badge d'abonnement si sub active
        if tier == 'gold' or tier == 'diamond' then
            pcall(function()
                exports['pvp_inventory']:unlockBadge(id, tier .. '_member')
            end)
        end

        -- Paie les VCoins en attente (vendeur hors-ligne)
        MySQL.Async.fetchScalar(
            'SELECT amount FROM vcoin_pending_bank WHERE identifier=@id',
            { ['@id'] = id },
            function(pending)
                pending = tonumber(pending) or 0
                if pending > 0 then
                    xPlayer.addAccountMoney('bank', pending)
                    MySQL.Async.execute(
                        'DELETE FROM vcoin_pending_bank WHERE identifier=@id',
                        { ['@id'] = id }
                    )
                    notify(src, ('~g~+%d$ reçus de ventes VCoins en votre absence !'):format(pending))
                end
            end
        )

        -- Envoie les données au client
        TriggerClientEvent('pvp_vcoins:syncData', src, {
            tier    = tier,
            vcoins  = vcoins,
            expires = expires,
        })
    end)
end)

AddEventHandler('playerDropped', function()
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then cache[xPlayer.identifier] = nil end
end)

-- ── Exports serveur ───────────────────────────────────────────────────────

-- Appelé par pvp_inventory:server pour le poids max du stash
exports('GetStashBonus', function(identifier)
    local c = cache[identifier]
    if not c then return 0.0 end
    return (TIERS[c.tier] and TIERS[c.tier].stash_bonus) or 0.0
end)

-- Appelé par pvp_killfeed, pvp_character, etc.
exports('GetTier', function(identifier)
    local c = cache[identifier]
    return c and c.tier or 'none'
end)

-- ── Callback : données complètes pour l'onglet NUI ────────────────────────
ESX.RegisterServerCallback('pvp_vcoins:getData', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then cb(nil) return end
    local id = xPlayer.identifier

    MySQL.Async.fetchAll([[
        SELECT
            vcoins,
            IF(sub_expires_at IS NOT NULL AND sub_expires_at > NOW(), subscription, 'none') AS active_tier,
            IF(sub_expires_at > NOW(), sub_expires_at, NULL) AS expires_active
        FROM users WHERE identifier = @id
    ]], { ['@id'] = id }, function(result)
        local row    = result and result[1]
        local tier   = row and row.active_tier or 'none'
        local vcoins = row and tonumber(row.vcoins) or 0
        local expires = row and row.expires_active or nil

        if cache[id] then
            cache[id].tier    = tier
            cache[id].vcoins  = vcoins
            cache[id].expires = expires
        end

        -- Marché : toutes les offres
        MySQL.Async.fetchAll(
            'SELECT id, seller_name, vcoin_amount, price_ingame, created_at FROM vcoin_market ORDER BY created_at DESC LIMIT 50',
            {}, function(market)
                -- Mes offres actives
                MySQL.Async.fetchAll(
                    'SELECT id, vcoin_amount, price_ingame FROM vcoin_market WHERE seller_identifier=@id',
                    { ['@id'] = id }, function(myOffers)
                        cb({
                            vcoins   = vcoins,
                            tier     = tier,
                            expires  = expires and tostring(expires):sub(1,10) or nil,
                            market   = market   or {},
                            myOffers = myOffers or {},
                        })
                    end
                )
            end
        )
    end)
end)

-- ── Event : Activer un abonnement ─────────────────────────────────────────
-- Flag mémoire pour sérialiser les souscriptions par joueur (évite races).
local subscribeLocks = {}

RegisterNetEvent('pvp_vcoins:subscribe')
AddEventHandler('pvp_vcoins:subscribe', function(tierName)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not isValidTier(tierName) then return end
    local id      = xPlayer.identifier
    local tierDef = TIERS[tierName]

    -- Anti-spam : un seul subscribe en cours par joueur.
    if subscribeLocks[id] then
        notify(src, '~r~Opération en cours, patiente...')
        return
    end
    subscribeLocks[id] = true

    -- UPDATE atomique conditionnel : débite les VCoins + pose la sub en UNE requête,
    -- seulement si le joueur a assez de VC. Empêche les dupes/spam concurrent.
    -- DATE_ADD sur sub_expires_at prolonge si actif, sinon part de NOW().
    MySQL.Async.execute([[
        UPDATE users
        SET vcoins         = vcoins - @price,
            subscription   = @tier,
            sub_expires_at = IF(
                sub_expires_at IS NOT NULL AND sub_expires_at > NOW(),
                DATE_ADD(sub_expires_at, INTERVAL @days DAY),
                DATE_ADD(NOW(), INTERVAL @days DAY)
            )
        WHERE identifier = @id AND vcoins >= @price
    ]], {
        ['@price'] = tierDef.price,
        ['@tier']  = tierName,
        ['@days']  = SUB_DURATION_DAYS,
        ['@id']    = id,
    }, function(rows)
        if not rows or rows == 0 then
            subscribeLocks[id] = nil
            notify(src, ('~r~VCoins insuffisants pour %s (%d VC requis)'):format(tierDef.label, tierDef.price))
            return
        end

        -- Relit l'état DB (expires + vcoins) après l'UPDATE pour refléter la vérité
        MySQL.Async.fetchAll(
            'SELECT vcoins, sub_expires_at FROM users WHERE identifier = @id',
            { ['@id'] = id },
            function(result)
                subscribeLocks[id] = nil
                local row = result and result[1] or {}
                local remaining = tonumber(row.vcoins) or 0
                local newExpiry = row.sub_expires_at

                cache[id] = { tier = tierName, vcoins = remaining, expires = newExpiry }

                pcall(function()
                    exports['pvp_inventory']:setContainerBonus(id, tierDef.stash_bonus)
                end)
                pcall(function()
                    exports['pvp_inventory']:unlockBadge(id, tierName .. '_member')
                end)

                notify(src, ('~g~Abonnement %s activé ! Expire le %s'):format(
                    tierDef.label, tostring(newExpiry):sub(1,10)))

                TriggerClientEvent('pvp_vcoins:syncData', src, {
                    tier    = tierName,
                    vcoins  = remaining,
                    expires = tostring(newExpiry):sub(1,10),
                })
                TriggerClientEvent('pvp_vcoins:subChanged', src, tierName)
            end
        )
    end)
end)

-- ── Event : Créer une offre marché ────────────────────────────────────────
RegisterNetEvent('pvp_vcoins:createOffer')
AddEventHandler('pvp_vcoins:createOffer', function(vcoinAmount, priceIngame)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local id = xPlayer.identifier

    vcoinAmount = math.floor(tonumber(vcoinAmount) or 0)
    priceIngame = math.floor(tonumber(priceIngame) or 0)

    if vcoinAmount < 10 or vcoinAmount > 10000 then
        notify(src, '~r~Montant invalide (10 — 10 000 VC)')
        return
    end
    if priceIngame < 100 or priceIngame > 10000000 then
        notify(src, '~r~Prix invalide (100$ — 10 000 000$)')
        return
    end

    MySQL.Async.fetchScalar(
        'SELECT vcoins FROM users WHERE identifier=@id',
        { ['@id'] = id },
        function(vcoins)
            vcoins = tonumber(vcoins) or 0
            if vcoins < vcoinAmount then
                notify(src, ('~r~VCoins insuffisants (%d/%d VC)'):format(vcoins, vcoinAmount))
                return
            end
            MySQL.Async.fetchScalar(
                'SELECT COUNT(*) FROM vcoin_market WHERE seller_identifier=@id',
                { ['@id'] = id },
                function(cnt)
                    cnt = tonumber(cnt) or 0
                    if cnt >= MARKET_MAX_OFFERS then
                        notify(src, ('~r~Maximum %d offres actives'):format(MARKET_MAX_OFFERS))
                        return
                    end
                    -- Déduit + crée l'offre (vérifie solde en condition WHERE)
                    MySQL.Async.execute(
                        'UPDATE users SET vcoins = vcoins - @amt WHERE identifier=@id AND vcoins >= @amt',
                        { ['@amt'] = vcoinAmount, ['@id'] = id },
                        function(rows)
                            if not rows or rows == 0 then
                                notify(src, '~r~Erreur : solde insuffisant')
                                return
                            end
                            MySQL.Async.execute([[
                                INSERT INTO vcoin_market (seller_identifier, seller_name, vcoin_amount, price_ingame)
                                VALUES (@sid, @sn, @va, @pi)
                            ]], {
                                ['@sid'] = id,
                                ['@sn']  = xPlayer.getName(),
                                ['@va']  = vcoinAmount,
                                ['@pi']  = priceIngame,
                            }, function()
                                if cache[id] then cache[id].vcoins = vcoins - vcoinAmount end
                                notify(src, ('~g~Offre créée : %d VC pour %d$'):format(vcoinAmount, priceIngame))
                                TriggerClientEvent('pvp_vcoins:syncVCoins', src, vcoins - vcoinAmount)
                            end)
                        end
                    )
                end
            )
        end
    )
end)

-- ── Event : Annuler une offre ─────────────────────────────────────────────
RegisterNetEvent('pvp_vcoins:cancelOffer')
AddEventHandler('pvp_vcoins:cancelOffer', function(offerId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local id = xPlayer.identifier

    offerId = math.floor(tonumber(offerId) or 0)
    if offerId <= 0 then return end

    -- Lit d'abord le montant pour le refund, PUIS DELETE en vérifiant rows > 0.
    -- Si DELETE a échoué (autre handler a supprimé avant nous), on NE refund PAS.
    -- Évite le dupe "spam cancel → refund multiple" qui existait auparavant.
    MySQL.Async.fetchAll(
        'SELECT vcoin_amount FROM vcoin_market WHERE id=@id AND seller_identifier=@sid',
        { ['@id'] = offerId, ['@sid'] = id },
        function(result)
            local row = result and result[1]
            if not row then notify(src, '~r~Offre introuvable') return end

            local refund = tonumber(row.vcoin_amount) or 0
            MySQL.Async.execute(
                'DELETE FROM vcoin_market WHERE id=@id AND seller_identifier=@sid',
                { ['@id'] = offerId, ['@sid'] = id },
                function(rows)
                    if not rows or rows == 0 then
                        -- Le DELETE n'a rien supprimé (autre handler a déjà été plus rapide).
                        -- Ne surtout PAS refund — ou on crédite N fois pour une seule offre.
                        notify(src, '~r~Offre déjà annulée')
                        return
                    end
                    MySQL.Async.execute(
                        'UPDATE users SET vcoins = vcoins + @amt WHERE identifier=@id',
                        { ['@amt'] = refund, ['@id'] = id },
                        function()
                            if cache[id] then cache[id].vcoins = (cache[id].vcoins or 0) + refund end
                            MySQL.Async.fetchScalar(
                                'SELECT vcoins FROM users WHERE identifier=@id',
                                { ['@id'] = id },
                                function(newBal)
                                    TriggerClientEvent('pvp_vcoins:syncVCoins', src, tonumber(newBal) or 0)
                                end
                            )
                            notify(src, ('~g~Offre annulée, %d VC remboursés'):format(refund))
                        end
                    )
                end
            )
        end
    )
end)

-- ── Event : Acheter une offre du marché ───────────────────────────────────
RegisterNetEvent('pvp_vcoins:buyOffer')
AddEventHandler('pvp_vcoins:buyOffer', function(offerId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local id = xPlayer.identifier

    offerId = math.floor(tonumber(offerId) or 0)
    if offerId <= 0 then return end

    MySQL.Async.fetchAll(
        'SELECT id, seller_identifier, seller_name, vcoin_amount, price_ingame FROM vcoin_market WHERE id=@id',
        { ['@id'] = offerId },
        function(result)
            local offer = result and result[1]
            if not offer then
                notify(src, "~r~Cette offre n'existe plus")
                return
            end
            if offer.seller_identifier == id then
                notify(src, '~r~Tu ne peux pas acheter ta propre offre')
                return
            end

            local price  = tonumber(offer.price_ingame) or 0
            local amount = tonumber(offer.vcoin_amount) or 0
            local bank   = xPlayer.getAccount('bank').money

            if bank < price then
                notify(src, ('~r~Fonds insuffisants (%d$ requis)'):format(price))
                return
            end

            -- Supprime l'offre atomiquement (évite double-achat)
            MySQL.Async.execute(
                'DELETE FROM vcoin_market WHERE id=@id AND seller_identifier=@sid',
                { ['@id'] = offerId, ['@sid'] = offer.seller_identifier },
                function(rows)
                    if not rows or rows == 0 then
                        notify(src, "~r~Cette offre a déjà été achetée")
                        return
                    end

                    -- Débite l'acheteur en argent
                    xPlayer.removeAccountMoney('bank', price)

                    -- Crédite les VCoins à l'acheteur
                    MySQL.Async.execute(
                        'UPDATE users SET vcoins = vcoins + @amt WHERE identifier=@id',
                        { ['@amt'] = amount, ['@id'] = id },
                        function()
                            if cache[id] then cache[id].vcoins = (cache[id].vcoins or 0) + amount end

                            -- Crédite l'argent au vendeur (en ligne ou hors ligne)
                            local seller = ESX.GetPlayerFromIdentifier(offer.seller_identifier)
                            if seller then
                                seller.addAccountMoney('bank', price)
                                TriggerClientEvent('esx:showNotification', seller.source,
                                    ('~g~Ton offre de %d VC a été vendue pour %d$'):format(amount, price))
                            else
                                -- Vendeur hors ligne → paiement en attente
                                MySQL.Async.execute([[
                                    INSERT INTO vcoin_pending_bank (identifier, amount) VALUES (@id, @amt)
                                    ON DUPLICATE KEY UPDATE amount = amount + @amt
                                ]], { ['@id'] = offer.seller_identifier, ['@amt'] = price })
                            end

                            MySQL.Async.fetchScalar(
                                'SELECT vcoins FROM users WHERE identifier=@id',
                                { ['@id'] = id },
                                function(newBal)
                                    TriggerClientEvent('pvp_vcoins:syncVCoins', src, tonumber(newBal) or 0)
                                end
                            )
                            notify(src, ('~g~Achat effectué : +%d VC pour %d$'):format(amount, price))
                        end
                    )
                end
            )
        end
    )
end)

-- ── Webhook Tebex (HTTP handler) ──────────────────────────────────────────
-- SÉCURITÉ — deux barrières :
--   1) Le secret DOIT apparaître dans l'URL path.
--      Configure dans Tebex : URL = http://TON_IP:30120/pvp_vcoins/tebex/<TEBEX_URL_SECRET>
--   2) Idempotence via vcoin_tebex_transactions : chaque transaction_id est mémorisé,
--      un replay du même webhook est refusé silencieusement.
--
-- Sans ces deux protections, n'importe qui connaissant l'IP publique pouvait forger
-- des crédits VCoins illimités via un simple POST curl.
--
-- TODO (à ajouter quand une lib SHA256 sera disponible côté Lua) : validation HMAC
-- du body via header X-Signature, voir https://creator.tebex.io/webhooks
SetHttpHandler(function(req, res)
    -- Refuse tout sauf POST sur /tebex/<secret>
    local expectedPath = '/tebex/' .. TEBEX_URL_SECRET
    if req.method ~= 'POST' or req.path ~= expectedPath then
        res.writeHead(404)
        res.send('')
        return
    end

    -- Refuse si le secret est encore à sa valeur par défaut (sinon tout POST passe).
    if TEBEX_URL_SECRET == 'CHANGE_ME_TO_A_LONG_RANDOM_STRING_32_CHARS_MIN' or #TEBEX_URL_SECRET < 16 then
        print('[pvp_vcoins] FATAL: TEBEX_URL_SECRET non configuré — webhook refusé')
        res.writeHead(503)
        res.send('webhook disabled — secret not configured')
        return
    end

    req.setDataHandler(function(body)
        local ok, data = pcall(json.decode, body)
        if not ok or not data then
            res.writeHead(400)
            res.send('bad json')
            return
        end

        -- Tebex envoie différents types d'events (validation, payment, refund, chargeback...).
        -- On n'accepte que les paiements complétés.
        local eventType = data.type or data.event_type
        if eventType and eventType ~= 'payment.completed' and eventType ~= 'payment' then
            res.writeHead(200)
            res.send('ignored')
            return
        end

        local identifier = data.customer and data.customer.identifier
        if not identifier or type(identifier) ~= 'string' or #identifier > 100 then
            res.writeHead(200) res.send('ok') return
        end

        -- Idempotence : Tebex inclut un id de transaction unique. Si déjà traité, skip.
        local txId = tostring(data.transaction_id or data.id or data.payment_id or '')
        if txId == '' then
            print('[pvp_vcoins] WARN Tebex: transaction_id manquant, webhook refusé')
            res.writeHead(400) res.send('missing transaction_id') return
        end

        local totalVC = 0
        if data.packages and type(data.packages) == 'table' then
            for _, pkg in ipairs(data.packages) do
                local pkgId  = tonumber(pkg and pkg.id)
                local amount = pkgId and TEBEX_PACKAGES[pkgId] or nil
                if amount and amount > 0 then totalVC = totalVC + amount end
            end
        end

        if totalVC <= 0 then
            res.writeHead(200) res.send('ok') return
        end

        -- Tentative d'insertion du transaction_id. Si déjà présent, INSERT IGNORE rend rows=0 → replay.
        MySQL.Async.execute([[
            INSERT IGNORE INTO vcoin_tebex_transactions (transaction_id, identifier, amount)
            VALUES (@tx, @id, @amt)
        ]], {
            ['@tx']  = txId,
            ['@id']  = identifier,
            ['@amt'] = totalVC,
        }, function(insertRows)
            if not insertRows or insertRows == 0 then
                -- Transaction déjà traitée → replay refusé
                print(('[pvp_vcoins] Tebex: replay refusé (tx=%s)'):format(txId))
                return
            end

            MySQL.Async.execute(
                'UPDATE users SET vcoins = vcoins + @amt WHERE identifier = @id',
                { ['@amt'] = totalVC, ['@id'] = identifier },
                function(rows)
                    if rows and rows > 0 then
                        print(('[pvp_vcoins] Tebex: +%d VC → %s (tx=%s)'):format(totalVC, identifier, txId))
                        local player = ESX.GetPlayerFromIdentifier(identifier)
                        if player then
                            MySQL.Async.fetchScalar(
                                'SELECT vcoins FROM users WHERE identifier=@id',
                                { ['@id'] = identifier },
                                function(newBal)
                                    local nb = tonumber(newBal) or 0
                                    if cache[identifier] then cache[identifier].vcoins = nb end
                                    TriggerClientEvent('pvp_vcoins:syncVCoins', player.source, nb)
                                    TriggerClientEvent('esx:showNotification', player.source,
                                        ('~g~+%d VCoins reçus ! Solde : %d VC'):format(totalVC, nb))
                                end
                            )
                        end
                    else
                        print(('[pvp_vcoins] WARN Tebex: identifier non trouvé en DB: %s'):format(identifier))
                    end
                end
            )
        end)

        res.writeHead(200)
        res.send('ok')
    end)
end)
