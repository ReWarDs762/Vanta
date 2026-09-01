-- =============================================
--   PVP MARKET - Serveur
--   Annonces, achats, annulations, échange direct
-- =============================================

local ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- ── Créer les tables SQL au démarrage ───────────────────────────────────
AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    MySQL.Async.execute([[
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
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `pvp_market_pending_payments` (
            `id`         INT(11)     NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(60) NOT NULL,
            `currency`   VARCHAR(20) NOT NULL DEFAULT 'bank',
            `amount`     INT(11)     NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`),
            UNIQUE KEY `unique_pending` (`identifier`, `currency`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    print('[pvp_market] Tables SQL créées/vérifiées.')
end)

-- Pending trades: pendingTrades[targetSrc] = { from=src, items={}, money=0, timestamp=os.time() }
local pendingTrades = {}
-- Active trade windows: activeTrades[src] = { partner=targetSrc, myOffer={items={},money=0}, partnerOffer={items={},money=0}, confirmed=false }
local activeTrades = {}
-- Lock pour empêcher l'exécution concurrente d'un même trade
local tradeExecuting = {} -- [pairKey] = true

-- ── Helper : vérifier si un joueur est en zone safe (côté serveur) ────────
local function isPlayerInSafeZone(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local coords = GetEntityCoords(ped)
    -- Lire Config.Outposts depuis pvp_outposts
    local ok, outposts = pcall(function()
        return exports['pvp_outposts']:getAllOutposts()
    end)
    if not ok or not outposts then return false end
    for _, op in ipairs(outposts) do
        local radius = op.safeRadius or 50.0
        local dx = coords.x - op.coords.x
        local dy = coords.y - op.coords.y
        local dz = coords.z - op.coords.z
        if (dx*dx + dy*dy + dz*dz) < (radius * radius) then
            return true
        end
    end
    return false
end

-- ── Sécurité : validation item + label serveur ───────────────────────────
local MAX_PRICE = 10000000   -- 10 M max par annonce
local MAX_QTY   = 10000
local MAX_TRADE_MONEY = 10000000
local MAX_TRADE_ITEMS = 30

local function isValidItemName(name)
    if type(name) ~= 'string' then return false end
    if #name < 1 or #name > 50 then return false end
    return name:match('^[a-z0-9_]+$') ~= nil
end

-- Label autoritaire depuis la table items ESX (cache)
local itemLabelCache = {}
local function getItemLabelServer(itemName)
    if itemLabelCache[itemName] then return itemLabelCache[itemName] end
    local ok, row = pcall(function()
        return MySQL.Sync.fetchAll('SELECT label FROM items WHERE name = @n', { ['@n'] = itemName })
    end)
    if ok and row and row[1] and row[1].label then
        itemLabelCache[itemName] = row[1].label
        return row[1].label
    end
    return itemName
end

-- ── Helper ──────────────────────────────────────────────────────────────────
local function getPlayerName(xPlayer)
    local firstName = xPlayer.get('firstName') or ''
    local lastName  = xPlayer.get('lastName')  or ''
    if firstName == '' and lastName == '' then return 'Joueur' end
    return firstName .. ' ' .. lastName
end

-- ── Crée une annonce (marché) ───────────────────────────────────────────────
RegisterNetEvent('pvp_market:createListing')
AddEventHandler('pvp_market:createListing', function(itemName, itemLabel, qty, price)
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    -- SÉCURITÉ : validation format item
    if not isValidItemName(itemName) then
        exports['vanta_ui']:notify(src, 'Nom d\'item invalide.', 'error')
        return
    end

    qty   = math.max(1, math.min(MAX_QTY,   math.floor(tonumber(qty)   or 1)))
    price = math.max(1, math.min(MAX_PRICE, math.floor(tonumber(price) or 1)))

    -- Label autoritaire serveur (ignore le label client)
    itemLabel = getItemLabelServer(itemName)

    -- Vérifie la zone safe
    if not isPlayerInSafeZone(src) then
        exports['vanta_ui']:notify(src, 'Ventes uniquement en zone safe !', 'warning')
        return
    end

    -- Vérifie la limite d'annonces par joueur
    local maxListings = Config.MaxListingsPerPlayer or 10
    local ok, currentCount = pcall(function()
        return MySQL.Sync.fetchScalar(
            'SELECT COUNT(*) FROM pvp_market_listings WHERE seller_identifier = @sid',
            { ['@sid'] = xPlayer.identifier })
    end)
    if ok and currentCount and currentCount >= maxListings then
        exports['vanta_ui']:notify(src, 'Limite d\'annonces atteinte (' .. maxListings .. ' max).', 'warning')
        return
    end

    -- Vérifie le stock
    local item = xPlayer.getInventoryItem(itemName)
    if not item or item.count < qty then
        exports['vanta_ui']:notify(src, 'Stock insuffisant.', 'error')
        return
    end

    -- Retire les items
    xPlayer.removeInventoryItem(itemName, qty)

    -- Déséquiper l'arme si elle était en main
    if string.sub(itemName, 1, 7) == 'weapon_' then
        TriggerClientEvent('pvp_inventory:unequipWeapon', src, itemName)
    end

    -- Insère l'annonce
    MySQL.Async.execute(
        [[INSERT INTO pvp_market_listings
          (seller_identifier, seller_name, item_name, item_label, quantity, price, currency)
          VALUES (@sid, @sname, @item, @label, @qty, @price, 'bank')]],
        {
            ['@sid']   = xPlayer.identifier,
            ['@sname'] = getPlayerName(xPlayer),
            ['@item']  = itemName,
            ['@label'] = itemLabel,
            ['@qty']   = qty,
            ['@price'] = price,
        },
        function()
            exports['vanta_ui']:notify(src,
                itemLabel .. ' x' .. qty .. ' mis en vente pour ' .. price .. ' $.', 'success')
            -- Rafraîchir l'inventaire du joueur pour que le NUI soit à jour
            TriggerEvent('pvp_inventory:refreshClient', src)
        end
    )
end)

-- ── Achète une annonce (atomique : DELETE-first pour éviter la race condition) ─
local buyLocks = {}  -- [listingId] = true pendant le traitement

RegisterNetEvent('pvp_market:buyListing')
AddEventHandler('pvp_market:buyListing', function(listingId)
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    listingId = tonumber(listingId)
    if not listingId then return end

    -- Anti-spam : verrouillage par listing
    if buyLocks[listingId] then
        exports['vanta_ui']:notify(src, 'Achat en cours de traitement...', 'info')
        return
    end
    buyLocks[listingId] = true

    -- Vérifie la zone safe
    if not isPlayerInSafeZone(src) then
        buyLocks[listingId] = nil
        exports['vanta_ui']:notify(src, 'Achats uniquement en zone safe !', 'warning')
        return
    end

    -- Étape 1 : SELECT pour vérifier les conditions AVANT de toucher à la DB
    MySQL.Async.fetchAll(
        'SELECT * FROM pvp_market_listings WHERE id = @id',
        { ['@id'] = listingId },
        function(rows)
            if not rows[1] then
                buyLocks[listingId] = nil
                exports['vanta_ui']:notify(src, 'Annonce introuvable ou déjà vendue.', 'warning')
                return
            end

            local listing = rows[1]

            if listing.seller_identifier == xPlayer.identifier then
                buyLocks[listingId] = nil
                exports['vanta_ui']:notify(src, 'Tu ne peux pas acheter ta propre annonce.', 'warning')
                return
            end

            local account = xPlayer.getAccount('bank')
            if not account or account.money < listing.price then
                buyLocks[listingId] = nil
                exports['vanta_ui']:notify(src, 'Fonds insuffisants.', 'error')
                return
            end

            -- Étape 2 : DELETE atomique — si rowsAffected == 0, un autre joueur a été plus rapide
            MySQL.Async.execute(
                'DELETE FROM pvp_market_listings WHERE id = @id',
                { ['@id'] = listingId },
                function(rowsAffected)
                    buyLocks[listingId] = nil

                    if rowsAffected == 0 then
                        exports['vanta_ui']:notify(src, 'Annonce déjà vendue.', 'warning')
                        return
                    end

                    -- Vérifier que l'acheteur a la place dans son sac
                    local canAdd = true
                    local ok_bag, result_bag = pcall(function()
                        return exports['pvp_inventory']:canAddToBag(src, listing.item_name, listing.quantity)
                    end)
                    if ok_bag and result_bag == false then
                        canAdd = false
                    end

                    if not canAdd then
                        -- Remettre l'annonce en base (rollback du DELETE)
                        MySQL.Async.execute(
                            [[INSERT INTO pvp_market_listings
                              (id, seller_identifier, seller_name, item_name, item_label, quantity, price, currency)
                              VALUES (@id, @seller, @name, @item, @label, @qty, @price, @cur)]],
                            {
                                ['@id']     = listingId,
                                ['@seller'] = listing.seller_identifier,
                                ['@name']   = listing.seller_name,
                                ['@item']   = listing.item_name,
                                ['@label']  = listing.item_label,
                                ['@qty']    = listing.quantity,
                                ['@price']  = listing.price,
                                ['@cur']    = listing.currency or 'bank',
                            }
                        )
                        exports['vanta_ui']:notify(src, 'Sac trop lourd pour cet achat !', 'warning')
                        return
                    end

                    -- Débite l'acheteur (seulement si DELETE a réussi et place dispo)
                    xPlayer.removeAccountMoney('bank', listing.price)
                    xPlayer.addInventoryItem(listing.item_name, listing.quantity)

                    -- Taxe
                    local tax       = math.floor(listing.price * Config.SalesTax / 100)
                    local netAmount = listing.price - tax

                    local seller = ESX.GetPlayerFromIdentifier(listing.seller_identifier)
                    if seller then
                        seller.addAccountMoney('bank', netAmount)
                        exports['vanta_ui']:notify(seller.source,
                            listing.item_label .. ' x' .. listing.quantity
                            .. ' vendu ! +' .. netAmount .. ' $ (taxe ' .. tax .. ' $)', 'success')
                    else
                        -- Vendeur hors ligne
                        MySQL.Async.execute(
                            [[INSERT INTO pvp_market_pending_payments
                              (identifier, currency, amount)
                              VALUES (@id, 'bank', @amount)
                              ON DUPLICATE KEY UPDATE amount = amount + @amount]],
                            { ['@id'] = listing.seller_identifier, ['@amount'] = netAmount }
                        )
                    end

                    exports['vanta_ui']:notify(src,
                        listing.item_label .. ' x' .. listing.quantity
                        .. ' acheté pour ' .. listing.price .. ' $.', 'success')
                end
            )
        end
    )
end)

-- ── Annule une annonce ──────────────────────────────────────────────────────
RegisterNetEvent('pvp_market:cancelListing')
AddEventHandler('pvp_market:cancelListing', function(listingId)
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    MySQL.Async.fetchAll(
        'SELECT * FROM pvp_market_listings WHERE id = @id AND seller_identifier = @sid',
        { ['@id'] = listingId, ['@sid'] = xPlayer.identifier },
        function(rows)
            if not rows[1] then
                exports['vanta_ui']:notify(src, 'Annonce introuvable.', 'warning')
                return
            end
            local listing = rows[1]

            MySQL.Async.execute(
                'DELETE FROM pvp_market_listings WHERE id = @id',
                { ['@id'] = listingId },
                function()
                    xPlayer.addInventoryItem(listing.item_name, listing.quantity)
                    exports['vanta_ui']:notify(src,
                        'Annonce annulée — ' .. listing.item_label
                        .. ' x' .. listing.quantity .. ' restitué.', 'info')
                end
            )
        end
    )
end)

-- ── Paiements en attente (vendeur hors-ligne) ─────────────────────────────
-- Approche sûre : SELECT les IDs + montants, puis DELETE par ID spécifique.
-- Si un nouveau paiement arrive entre SELECT et DELETE, il ne sera pas supprimé.
AddEventHandler('esx:playerLoaded', function(playerId)
    local src = type(playerId) == 'table' and playerId.source or playerId
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    MySQL.Async.fetchAll(
        'SELECT id, currency, amount FROM pvp_market_pending_payments WHERE identifier = @id AND amount > 0',
        { ['@id'] = xPlayer.identifier },
        function(rows)
            if not rows or #rows == 0 then return end
            local total = 0
            local ids = {}
            for _, row in ipairs(rows) do
                total = total + row.amount
                ids[#ids + 1] = tostring(row.id)
            end
            if total > 0 then
                xPlayer.addAccountMoney('bank', total)
                exports['vanta_ui']:notify(xPlayer.source,
                    'Ventes encaissées pendant ton absence : +' .. total .. ' $', 'success')
            end
            -- Supprimer uniquement les lignes récupérées (par ID)
            if #ids > 0 then
                MySQL.Async.execute(
                    'DELETE FROM pvp_market_pending_payments WHERE id IN (' .. table.concat(ids, ',') .. ')',
                    {}
                )
            end
        end
    )
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- ÉCHANGE DIRECT ENTRE JOUEURS
-- ══════════════════════════════════════════════════════════════════════════════

-- Demande d'échange (joueur A → joueur B)
RegisterNetEvent('pvp_market:requestTrade')
AddEventHandler('pvp_market:requestTrade', function(targetServerId)
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local target  = ESX.GetPlayerFromId(targetServerId)
    if not xPlayer or not target then
        exports['vanta_ui']:notify(src, 'Joueur introuvable.', 'error')
        return
    end
    if src == targetServerId then
        exports['vanta_ui']:notify(src, 'Tu ne peux pas échanger avec toi-même.', 'warning')
        return
    end

    -- Vérifier que les deux joueurs sont en zone safe
    if not isPlayerInSafeZone(src) then
        exports['vanta_ui']:notify(src, 'Échange uniquement en zone safe !', 'warning')
        return
    end
    if not isPlayerInSafeZone(targetServerId) then
        exports['vanta_ui']:notify(src, 'L\'autre joueur n\'est pas en zone safe.', 'warning')
        return
    end

    -- Stocker la demande (avec timestamp pour timeout)
    pendingTrades[targetServerId] = { from = src, fromName = getPlayerName(xPlayer), timestamp = os.time() }
    exports['vanta_ui']:notify(src, 'Demande d\'échange envoyée à ' .. getPlayerName(target), 'info')
    TriggerClientEvent('pvp_market:tradeRequest', targetServerId, src, getPlayerName(xPlayer))
end)

-- Réponse à la demande
RegisterNetEvent('pvp_market:respondTrade')
AddEventHandler('pvp_market:respondTrade', function(accepted)
    local src = source
    local pending = pendingTrades[src]
    if not pending then return end
    pendingTrades[src] = nil

    local fromSrc = pending.from
    local xFrom   = ESX.GetPlayerFromId(fromSrc)
    local xTo     = ESX.GetPlayerFromId(src)
    if not xFrom or not xTo then return end

    if not accepted then
        exports['vanta_ui']:notify(fromSrc, getPlayerName(xTo) .. ' a refusé l\'échange.', 'info')
        return
    end

    -- Ouvrir la fenêtre d'échange pour les deux (avec timestamp pour timeout)
    local now = os.time()
    activeTrades[fromSrc] = { partner = src, myOffer = { items = {}, money = 0 }, partnerOffer = { items = {}, money = 0 }, confirmed = false, openedAt = now }
    activeTrades[src]     = { partner = fromSrc, myOffer = { items = {}, money = 0 }, partnerOffer = { items = {}, money = 0 }, confirmed = false, openedAt = now }

    -- Envoyer l'inventaire de chaque joueur pour la fenêtre
    local invFrom = {}
    for _, item in ipairs(xFrom.getInventory()) do
        if item.count > 0 then invFrom[#invFrom+1] = { name = item.name, label = item.label, count = item.count } end
    end
    local invTo = {}
    for _, item in ipairs(xTo.getInventory()) do
        if item.count > 0 then invTo[#invTo+1] = { name = item.name, label = item.label, count = item.count } end
    end

    local bankFrom = xFrom.getAccount('bank')
    local bankTo   = xTo.getAccount('bank')

    TriggerClientEvent('pvp_market:openTrade', fromSrc, {
        partnerName = getPlayerName(xTo),
        myInventory = invFrom,
        myBank = bankFrom and bankFrom.money or 0,
    })
    TriggerClientEvent('pvp_market:openTrade', src, {
        partnerName = getPlayerName(xFrom),
        myInventory = invTo,
        myBank = bankTo and bankTo.money or 0,
    })
end)

-- Mettre à jour l'offre d'un joueur
RegisterNetEvent('pvp_market:updateTradeOffer')
AddEventHandler('pvp_market:updateTradeOffer', function(offer)
    local src = source
    local trade = activeTrades[src]
    if not trade then return end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    -- Reset confirm si offre modifiée + refresh timeout
    trade.confirmed = false
    trade.openedAt = os.time()
    activeTrades[trade.partner].confirmed = false
    activeTrades[trade.partner].openedAt = os.time()

    -- Valider le montant d'argent (plafond = solde actuel du joueur)
    local bankAcc = xPlayer.getAccount('bank')
    local maxMoney = bankAcc and bankAcc.money or 0
    local money = math.max(0, math.min(MAX_TRADE_MONEY, math.floor(tonumber(offer.money) or 0)))
    money = math.min(money, maxMoney)  -- Impossible d'offrir plus que ce qu'on a

    -- Valider les items offerts (vérifier que le joueur les possède)
    local validItems = {}
    local seen = {}
    if type(offer.items) == 'table' then
        for _, offered in ipairs(offer.items) do
            if #validItems >= MAX_TRADE_ITEMS then break end
            if type(offered) == 'table' and isValidItemName(offered.name) and type(offered.count) == 'number' and not seen[offered.name] then
                local item = xPlayer.getInventoryItem(offered.name)
                if item and item.count > 0 then
                    local count = math.max(1, math.min(math.floor(offered.count), item.count))
                    validItems[#validItems + 1] = { name = offered.name, label = item.label, count = count }
                    seen[offered.name] = true
                end
            end
        end
    end

    trade.myOffer = {
        items = validItems,
        money = money,
    }
    -- Mettre à jour le partnerOffer de l'autre
    activeTrades[trade.partner].partnerOffer = trade.myOffer

    -- Envoyer la mise à jour au partenaire
    TriggerClientEvent('pvp_market:updatePartnerOffer', trade.partner, trade.myOffer)
    -- Reset confirm des deux côtés
    TriggerClientEvent('pvp_market:tradeConfirmReset', src)
    TriggerClientEvent('pvp_market:tradeConfirmReset', trade.partner)
end)

-- Confirmer l'échange (avec lock pour empêcher la race condition)
RegisterNetEvent('pvp_market:confirmTrade')
AddEventHandler('pvp_market:confirmTrade', function()
    local src = source
    local trade = activeTrades[src]
    if not trade then return end

    trade.confirmed = true
    local partnerTrade = activeTrades[trade.partner]

    -- Notifier le partenaire
    TriggerClientEvent('pvp_market:partnerConfirmed', trade.partner)

    -- Si les deux ont confirmé → exécuter l'échange (avec lock atomique)
    if partnerTrade and partnerTrade.confirmed then
        -- Clé unique pour cette paire (plus petit src en premier)
        local a, b = math.min(src, trade.partner), math.max(src, trade.partner)
        local pairKey = a .. ':' .. b
        if tradeExecuting[pairKey] then return end -- Déjà en cours d'exécution
        tradeExecuting[pairKey] = true
        executeTrade(src, trade.partner)
        tradeExecuting[pairKey] = nil
    end
end)

-- Annuler l'échange
RegisterNetEvent('pvp_market:cancelTrade')
AddEventHandler('pvp_market:cancelTrade', function()
    local src = source
    local trade = activeTrades[src]
    if not trade then return end

    local partner = trade.partner
    activeTrades[src] = nil
    activeTrades[partner] = nil

    TriggerClientEvent('pvp_market:tradeClosed', src)
    TriggerClientEvent('pvp_market:tradeClosed', partner)
    exports['vanta_ui']:notify(src, 'Échange annulé.', 'info')
    exports['vanta_ui']:notify(partner, 'Échange annulé par l\'autre joueur.', 'info')
end)

-- Exécuter l'échange (les deux ont confirmé)
function executeTrade(srcA, srcB)
    local xA = ESX.GetPlayerFromId(srcA)
    local xB = ESX.GetPlayerFromId(srcB)
    if not xA or not xB then return end

    local tradeA = activeTrades[srcA]
    local tradeB = activeTrades[srcB]
    if not tradeA or not tradeB then return end

    -- Vérifier que A a bien les items
    for _, offer in ipairs(tradeA.myOffer.items) do
        local item = xA.getInventoryItem(offer.name)
        if not item or item.count < offer.count then
            exports['vanta_ui']:notify(srcA, 'Stock insuffisant pour l\'échange.', 'error')
            exports['vanta_ui']:notify(srcB, 'Échange échoué.', 'error')
            activeTrades[srcA] = nil
            activeTrades[srcB] = nil
            TriggerClientEvent('pvp_market:tradeClosed', srcA)
            TriggerClientEvent('pvp_market:tradeClosed', srcB)
            return
        end
    end

    -- Vérifier que B a bien les items
    for _, offer in ipairs(tradeB.myOffer.items) do
        local item = xB.getInventoryItem(offer.name)
        if not item or item.count < offer.count then
            exports['vanta_ui']:notify(srcB, 'Stock insuffisant pour l\'échange.', 'error')
            exports['vanta_ui']:notify(srcA, 'Échange échoué.', 'error')
            activeTrades[srcA] = nil
            activeTrades[srcB] = nil
            TriggerClientEvent('pvp_market:tradeClosed', srcA)
            TriggerClientEvent('pvp_market:tradeClosed', srcB)
            return
        end
    end

    -- Vérifier argent
    local bankA = xA.getAccount('bank')
    local bankB = xB.getAccount('bank')
    if tradeA.myOffer.money > 0 and (not bankA or bankA.money < tradeA.myOffer.money) then
        exports['vanta_ui']:notify(srcA, 'Pas assez d\'argent.', 'error')
        activeTrades[srcA] = nil
        activeTrades[srcB] = nil
        TriggerClientEvent('pvp_market:tradeClosed', srcA)
        TriggerClientEvent('pvp_market:tradeClosed', srcB)
        return
    end
    if tradeB.myOffer.money > 0 and (not bankB or bankB.money < tradeB.myOffer.money) then
        exports['vanta_ui']:notify(srcB, 'Pas assez d\'argent.', 'error')
        activeTrades[srcA] = nil
        activeTrades[srcB] = nil
        TriggerClientEvent('pvp_market:tradeClosed', srcA)
        TriggerClientEvent('pvp_market:tradeClosed', srcB)
        return
    end

    -- Exécuter : retirer items de A, donner à B
    for _, offer in ipairs(tradeA.myOffer.items) do
        xA.removeInventoryItem(offer.name, offer.count)
        xB.addInventoryItem(offer.name, offer.count)
    end
    -- Retirer items de B, donner à A
    for _, offer in ipairs(tradeB.myOffer.items) do
        xB.removeInventoryItem(offer.name, offer.count)
        xA.addInventoryItem(offer.name, offer.count)
    end
    -- Argent
    if tradeA.myOffer.money > 0 then
        xA.removeAccountMoney('bank', tradeA.myOffer.money)
        xB.addAccountMoney('bank', tradeA.myOffer.money)
    end
    if tradeB.myOffer.money > 0 then
        xB.removeAccountMoney('bank', tradeB.myOffer.money)
        xA.addAccountMoney('bank', tradeB.myOffer.money)
    end

    activeTrades[srcA] = nil
    activeTrades[srcB] = nil

    TriggerClientEvent('pvp_market:tradeClosed', srcA)
    TriggerClientEvent('pvp_market:tradeClosed', srcB)
    exports['vanta_ui']:notify(srcA, 'Échange réussi !', 'success')
    exports['vanta_ui']:notify(srcB, 'Échange réussi !', 'success')
end

-- Cleanup si un joueur se déconnecte pendant un échange
AddEventHandler('playerDropped', function()
    local src = source
    local trade = activeTrades[src]
    if trade then
        local partner = trade.partner
        activeTrades[src] = nil
        if activeTrades[partner] then
            activeTrades[partner] = nil
            TriggerClientEvent('pvp_market:tradeClosed', partner)
            exports['vanta_ui']:notify(partner, 'L\'autre joueur s\'est déconnecté.', 'warning')
        end
    end
    pendingTrades[src] = nil
end)

-- ── Réclamer les ventes en attente (bouton NUI) ──────────────────────────
-- SÉCURITÉ : lock anti-double-claim + SELECT-then-DELETE-by-ID pour éviter
-- qu'un paiement arrivé entre le SELECT et le DELETE soit effacé sans versement.
local claimLocks = {}
RegisterNetEvent('pvp_market:claimSales')
AddEventHandler('pvp_market:claimSales', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if claimLocks[xPlayer.identifier] then
        exports['vanta_ui']:notify(src, 'Traitement en cours...', 'info')
        return
    end
    claimLocks[xPlayer.identifier] = true
    MySQL.Async.fetchAll(
        'SELECT id, currency, amount FROM pvp_market_pending_payments WHERE identifier = @id AND amount > 0',
        { ['@id'] = xPlayer.identifier },
        function(rows)
            if not rows or #rows == 0 then
                claimLocks[xPlayer.identifier] = nil
                exports['vanta_ui']:notify(src, 'Aucun paiement en attente.', 'info')
                return
            end
            local ids = {}
            for _, row in ipairs(rows) do
                local acc = xPlayer.getAccount(row.currency)
                if acc then
                    xPlayer.addAccountMoney(row.currency, row.amount)
                end
                ids[#ids + 1] = tostring(row.id)
            end
            if #ids > 0 then
                MySQL.Async.execute(
                    'DELETE FROM pvp_market_pending_payments WHERE id IN (' .. table.concat(ids, ',') .. ')',
                    {},
                    function()
                        claimLocks[xPlayer.identifier] = nil
                    end
                )
            else
                claimLocks[xPlayer.identifier] = nil
            end
            exports['vanta_ui']:notify(src, 'Paiements réclamés !', 'success')
        end
    )
end)

-- ── Nettoyage périodique des pending trades expirés (timeout 2 min) ──────
CreateThread(function()
    while true do
        Wait(30000) -- Vérifier toutes les 30s
        local now = os.time()
        for targetSrc, pending in pairs(pendingTrades) do
            if pending.timestamp and (now - pending.timestamp) > 120 then
                -- Notifier l'expéditeur si encore connecté
                local xFrom = ESX.GetPlayerFromId(pending.from)
                if xFrom then
                    exports['vanta_ui']:notify(pending.from, 'Demande d\'échange expirée.', 'info')
                end
                pendingTrades[targetSrc] = nil
            end
        end
        -- Timeout des trades actifs (5 min sans activité)
        for src, trade in pairs(activeTrades) do
            if trade.openedAt and (now - trade.openedAt) > 300 then
                local partner = trade.partner
                activeTrades[src] = nil
                if activeTrades[partner] then
                    activeTrades[partner] = nil
                    TriggerClientEvent('pvp_market:tradeClosed', partner)
                    exports['vanta_ui']:notify(partner, 'Échange expiré (inactivité).', 'warning')
                end
                TriggerClientEvent('pvp_market:tradeClosed', src)
                exports['vanta_ui']:notify(src, 'Échange expiré (inactivité).', 'warning')
            end
        end
    end
end)
