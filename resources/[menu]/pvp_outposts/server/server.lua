-- =============================================
--   PVP OUTPOSTS - Serveur
--   Téléportation, boutique, coffres (BDD)
-- =============================================

local ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- ── Helper safe pour récupérer le solde bancaire ─────────────────────────
local function getBankMoney(xPlayer)
    local account = xPlayer.getAccount('bank')
    return account and account.money or 0
end

-- ── Index des IDs d'outposts valides (anti-injection outpostId) ───────────
local VALID_OUTPOST_IDS = {}
for _, op in ipairs(Config.Outposts) do
    VALID_OUTPOST_IDS[op.id] = true
end

local function isValidOutpostId(id)
    return type(id) == 'string' and VALID_OUTPOST_IDS[id] == true
end

-- ── Vérifie si le joueur est dans une zone safe ─────────────────────────
local function isPlayerInSafeZone(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local coords = GetEntityCoords(ped)
    for _, op in ipairs(Config.Outposts) do
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

-- ── Téléportation vers un avant-poste ─────────────────────────────────────
RegisterNetEvent('pvp_outposts:teleport')
AddEventHandler('pvp_outposts:teleport', function(targetId)
    local src = source
    if not isValidOutpostId(targetId) then return end
    -- Le joueur doit être en zone safe pour utiliser le NPC de téléportation
    if not isPlayerInSafeZone(src) then
        TriggerClientEvent('pvp_market:notify', src, 'Téléportation uniquement en zone safe !', false)
        return
    end
    -- Trouve les coordonnées de la destination
    for _, op in ipairs(Config.Outposts) do
        if op.id == targetId then
            TriggerClientEvent('pvp_outposts:doTeleport', src, {
                x = op.coords.x,
                y = op.coords.y,
                z = op.coords.z
            }, op.heading)
            return
        end
    end
end)

-- ── Utilitaire : trouver un item dans toutes les configs shop ────────────
local function findShopItem(itemName, specialty)
    -- Cherche dans le shop correspondant à la spécialité
    local shopLists = {
        weapons  = Config.WeaponShopItems,
        vehicles = Config.VehicleShopItems,
        medical  = Config.MedicalShopItems,
        all      = Config.ShopItems,
    }

    local list = shopLists[specialty]
    if list then
        for _, item in ipairs(list) do
            if item.item == itemName then return item end
        end
    end

    -- Fallback : cherche dans tous les shops
    local allLists = { Config.ShopItems, Config.WeaponShopItems, Config.VehicleShopItems, Config.MedicalShopItems }
    for _, l in ipairs(allLists) do
        for _, item in ipairs(l) do
            if item.item == itemName then return item end
        end
    end
    return nil
end

-- Table de tous les items avec leur prix (pour la vente)
-- Priorité : AllItemPrices (table complète), puis les shops en fallback
local function buildPriceIndex()
    local index = {}
    -- D'abord la table complète
    if Config.AllItemPrices then
        for _, item in ipairs(Config.AllItemPrices) do
            index[item.item] = item
        end
    end
    -- Puis les shops (écrase si doublon, les prix shop font foi)
    local shopLists = { Config.ShopItems, Config.WeaponShopItems, Config.VehicleShopItems, Config.MedicalShopItems }
    for _, l in ipairs(shopLists) do
        for _, item in ipairs(l) do
            index[item.item] = item
        end
    end
    return index
end
local PRICE_INDEX = buildPriceIndex()

-- ── Achat d'un item (legacy — conservé pour compatibilité) ────────────────
RegisterNetEvent('pvp_outposts:buyItem')
AddEventHandler('pvp_outposts:buyItem', function(itemName, itemPrice, specialty)
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    -- SÉCURITÉ : interaction boutique limitée aux zones safe (anti-triche).
    if not isPlayerInSafeZone(src) then
        TriggerClientEvent('pvp_outposts:buyResult', src, false, 'Achat uniquement en zone safe !')
        return
    end

    -- SÉCURITÉ : valider type et bornes de itemPrice (client → serveur).
    if type(itemName) ~= 'string' or type(itemPrice) ~= 'number' then return end
    if itemPrice < 0 or itemPrice > 10000000 then return end

    local account = xPlayer.getAccount('bank')
    if not account then
        TriggerClientEvent('pvp_outposts:buyResult', src, false, 'Erreur compte bancaire.')
        return
    end
    if account.money < itemPrice then
        TriggerClientEvent('pvp_outposts:buyResult', src, false, 'Fonds insuffisants.')
        return
    end

    local itemConfig = findShopItem(itemName, specialty or 'all')
    if not itemConfig then
        TriggerClientEvent('pvp_outposts:buyResult', src, false, 'Item introuvable.')
        return
    end

    if math.floor(itemConfig.price) ~= math.floor(itemPrice) then
        TriggerClientEvent('pvp_outposts:buyResult', src, false, 'Prix invalide.')
        return
    end

    xPlayer.removeAccountMoney('bank', itemConfig.price)
    xPlayer.addInventoryItem(itemName, 1)
    TriggerClientEvent('pvp_outposts:buyResult', src, true, itemConfig.label .. ' acheté pour $' .. itemConfig.price)
end)

-- ── Achat du panier NUI — Server Callback (attend la vraie réponse serveur)
ESX.RegisterServerCallback('pvp_outposts:buyCartCb', function(src, cb, cartItems, destination)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not cartItems or type(cartItems) ~= 'table' or #cartItems == 0 then
        cb(false, 'Erreur serveur.', 0)
        return
    end

    -- SÉCURITÉ : limite la taille du panier pour éviter un DoS par flood d'items.
    if #cartItems > 50 then
        cb(false, 'Panier trop grand.', 0)
        return
    end

    -- SÉCURITÉ : joueur doit être en zone safe pour interagir avec la boutique.
    if not isPlayerInSafeZone(src) then
        cb(false, 'Achat uniquement en zone safe !', 0)
        return
    end

    -- SÉCURITÉ : destination doit être 'bag' ou 'stash', rien d'autre.
    if destination ~= 'bag' and destination ~= 'stash' then
        cb(false, 'Destination invalide.', 0)
        return
    end

    -- Calcul du total + vérification anti-triche (prix depuis la config serveur)
    local total     = 0
    local itemCfgs  = {}
    for _, ci in ipairs(cartItems) do
        local cfg = findShopItem(ci.item, 'all')
        if not cfg then
            cb(false, 'Item invalide : ' .. tostring(ci.item), 0)
            return
        end
        -- Vérification anti-triche : comparer avec math.floor pour éviter les
        -- problèmes de float JSON (ex: 300 vs 300.0 est OK en LuaJIT, mais on
        -- sécurise quand même)
        if math.floor(cfg.price) ~= math.floor(ci.price or 0) then
            cb(false, 'Prix invalide pour ' .. tostring(ci.item) .. '.', 0)
            return
        end
        local qty = math.max(1, math.floor(tonumber(ci.qty) or 1))
        total = total + (cfg.price * qty)
        itemCfgs[#itemCfgs + 1] = { item = ci.item, label = cfg.label, qty = qty }
    end

    -- Vérification du solde
    local account = xPlayer.getAccount('bank')
    if not account then
        cb(false, 'Erreur compte bancaire.', 0)
        return
    end
    if account.money < total then
        cb(false, 'Fonds insuffisants ($' .. account.money .. ' / $' .. total .. ').', account.money)
        return
    end

    -- Débit
    xPlayer.removeAccountMoney('bank', total)
    local newBalance = account.money - total

    if destination == 'bag' then
        -- ── Ajout au sac du joueur ──
        for _, ci in ipairs(itemCfgs) do
            xPlayer.addInventoryItem(ci.item, ci.qty)
        end
        -- Forcer le refresh de pvp_inventory NUI
        TriggerEvent('pvp_inventory:refreshClient', src)
        cb(true, 'Achat effectué — $' .. total .. ' débités.', newBalance)

    else
        -- ── Ajout au coffre avant-poste (pvp_outpost_stash, GLOBAL_ID = 'global') ──
        local GLOBAL_ID = 'global'
        local pending   = #itemCfgs
        if pending == 0 then
            TriggerEvent('pvp_inventory:refreshClient', src)
            cb(true, 'Coffre mis à jour ($' .. total .. ').', newBalance)
            return
        end

        for _, ci in ipairs(itemCfgs) do
            MySQL.Async.execute(
                [[INSERT INTO pvp_outpost_stash (identifier, outpost_id, item, label, count)
                  VALUES (@id, @op, @item, @label, @qty)
                  ON DUPLICATE KEY UPDATE count = count + @qty]],
                {
                    ['@id']    = xPlayer.identifier,
                    ['@op']    = GLOBAL_ID,
                    ['@item']  = ci.item,
                    ['@label'] = ci.label,
                    ['@qty']   = ci.qty,
                },
                function()
                    pending = pending - 1
                    if pending == 0 then
                        TriggerEvent('pvp_inventory:refreshClient', src)
                        cb(true, 'Envoyé au coffre avant-poste ($' .. total .. ').', newBalance)
                    end
                end
            )
        end
    end
end)

-- ── Vente d'un item ─────────────────────────────────────────────────────────
RegisterNetEvent('pvp_outposts:sellItem')
AddEventHandler('pvp_outposts:sellItem', function(itemName, sellPrice)
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    -- SÉCURITÉ : vente uniquement en zone safe.
    if not isPlayerInSafeZone(src) then
        TriggerClientEvent('pvp_outposts:sellResult', src, false, 'Vente uniquement en zone safe !')
        return
    end

    if type(itemName) ~= 'string' then return end

    -- Vérifie que l'item a un prix de base
    local itemConfig = PRICE_INDEX[itemName]
    if not itemConfig then
        TriggerClientEvent('pvp_outposts:sellResult', src, false, 'Cet item ne peut pas être vendu ici.')
        return
    end

    -- Vérifie que le joueur possède l'item
    local invItem = xPlayer.getInventoryItem(itemName)
    if not invItem or invItem.count < 1 then
        TriggerClientEvent('pvp_outposts:sellResult', src, false, 'Vous ne possédez pas cet item.')
        return
    end

    -- Calcul prix serveur (anti-triche)
    local realSellPrice = math.floor(itemConfig.price * Config.SellRatio)

    -- Retirer l'item et créditer
    xPlayer.removeInventoryItem(itemName, 1)
    xPlayer.addAccountMoney('bank', realSellPrice)

    -- Déséquiper l'arme si c'est une arme
    if string.sub(itemName, 1, 7) == 'weapon_' then
        TriggerClientEvent('pvp_inventory:unequipWeapon', src, itemName)
    end

    TriggerClientEvent('pvp_outposts:sellResult', src, true, itemConfig.label .. ' vendu pour $' .. realSellPrice)
    -- Mise à jour du solde dans le NUI
    TriggerClientEvent('pvp_outposts:nuiBalanceUpdate', src, getBankMoney(xPlayer))
end)

-- ── Vendre un item — Server Callback ──────────────────────────────────────
ESX.RegisterServerCallback('pvp_outposts:sellItemCb', function(src, cb, itemName)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then cb(false, 'Erreur serveur.', 0) return end

    if type(itemName) ~= 'string' then cb(false, 'Item invalide.', 0) return end

    -- SÉCURITÉ : vente uniquement en zone safe.
    if not isPlayerInSafeZone(src) then
        cb(false, 'Vente uniquement en zone safe !', getBankMoney(xPlayer))
        return
    end

    local itemConfig = PRICE_INDEX[itemName]
    if not itemConfig then
        cb(false, 'Cet item ne peut pas être vendu ici.', getBankMoney(xPlayer))
        return
    end

    local invItem = xPlayer.getInventoryItem(itemName)
    if not invItem or invItem.count < 1 then
        cb(false, 'Vous ne possédez pas cet item.', getBankMoney(xPlayer))
        return
    end

    local realSellPrice = math.floor(itemConfig.price * Config.SellRatio)
    xPlayer.removeInventoryItem(itemName, 1)
    xPlayer.addAccountMoney('bank', realSellPrice)

    if string.sub(itemName, 1, 7) == 'weapon_' then
        TriggerClientEvent('pvp_inventory:unequipWeapon', src, itemName)
    end

    TriggerEvent('pvp_inventory:refreshClient', src)
    cb(true, itemConfig.label .. ' vendu pour $' .. realSellPrice .. '.', getBankMoney(xPlayer))
end)

-- ── Utilitaire : vérifier si un item correspond à une spécialité ─────────
local function matchesSpecialty(itemName, spec)
    if spec == nil then return true end
    if spec == 'all' then
        -- Shop général : seulement consommables (pas d'armes ni véhicules)
        return string.sub(itemName, 1, 7) ~= 'weapon_' and string.sub(itemName, 1, 8) ~= 'vehicle_'
    end
    if spec == 'weapons' then
        return string.sub(itemName, 1, 7) == 'weapon_' or string.sub(itemName, 1, 5) == 'ammo_'
    end
    if spec == 'vehicles' then
        return string.sub(itemName, 1, 8) == 'vehicle_'
    end
    if spec == 'medical' then
        return itemName == 'bandage' or itemName == 'medkit' or itemName == 'kevlar'
    end
    return true
end

-- ── Tout vendre — Server Callback ─────────────────────────────────────────
ESX.RegisterServerCallback('pvp_outposts:sellAllCb', function(src, cb, spec)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then cb(false, 'Erreur serveur.', 0) return end

    -- SÉCURITÉ : vente uniquement en zone safe.
    if not isPlayerInSafeZone(src) then
        cb(false, 'Vente uniquement en zone safe !', getBankMoney(xPlayer))
        return
    end

    local totalEarned = 0
    local soldCount   = 0
    local inventory   = xPlayer.getInventory()

    for _, item in ipairs(inventory) do
        if item.count > 0 and PRICE_INDEX[item.name] and matchesSpecialty(item.name, spec) then
            local sellPrice = math.floor(PRICE_INDEX[item.name].price * Config.SellRatio)
            local earned    = sellPrice * item.count
            totalEarned     = totalEarned + earned
            soldCount       = soldCount + item.count

            xPlayer.removeInventoryItem(item.name, item.count)

            -- Déséquiper les armes vendues
            if string.sub(item.name, 1, 7) == 'weapon_' then
                TriggerClientEvent('pvp_inventory:unequipWeapon', src, item.name)
            end
        end
    end

    if soldCount == 0 then
        cb(false, 'Rien à vendre.', getBankMoney(xPlayer))
        return
    end

    xPlayer.addAccountMoney('bank', totalEarned)
    TriggerEvent('pvp_inventory:refreshClient', src)
    cb(true, soldCount .. ' items vendus pour $' .. totalEarned .. '.', getBankMoney(xPlayer))
end)

-- ── Callback : items du joueur vendables ────────────────────────────────────
ESX.RegisterServerCallback('pvp_outposts:getPlayerItems', function(src, cb)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then cb({}) return end

    local result = {}
    local inventory = xPlayer.getInventory()
    for _, item in ipairs(inventory) do
        if item.count > 0 and PRICE_INDEX[item.name] then
            table.insert(result, {
                name  = item.name,
                label = PRICE_INDEX[item.name].label,
                count = item.count,
                price = PRICE_INDEX[item.name].price,
            })
        end
    end
    cb(result)
end)

-- ── Ouverture du coffre ────────────────────────────────────────────────────
RegisterNetEvent('pvp_outposts:openStash')
AddEventHandler('pvp_outposts:openStash', function(outpostId)
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if not isValidOutpostId(outpostId) then return end

    MySQL.Async.fetchAll(
        'SELECT items FROM pvp_player_stash WHERE identifier = @id AND outpost_id = @op',
        { ['@id'] = xPlayer.identifier, ['@op'] = outpostId },
        function(result)
            local items = {}
            if result[1] and result[1].items then
                items = json.decode(result[1].items) or {}
            end
            TriggerClientEvent('pvp_outposts:receiveStash', src, outpostId, items)
        end
    )
end)

-- ── Récupérer un item du coffre ───────────────────────────────────────────
RegisterNetEvent('pvp_outposts:retrieveItem')
AddEventHandler('pvp_outposts:retrieveItem', function(outpostId, itemName)
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if not isValidOutpostId(outpostId) then return end
    if type(itemName) ~= 'string' or itemName == '' then return end

    MySQL.Async.fetchAll(
        'SELECT items FROM pvp_player_stash WHERE identifier = @id AND outpost_id = @op',
        { ['@id'] = xPlayer.identifier, ['@op'] = outpostId },
        function(result)
            if not result[1] then return end
            local items = json.decode(result[1].items) or {}
            local newItems = {}
            local found = false

            for _, item in ipairs(items) do
                if item.name == itemName and not found then
                    -- Restitue l'item au joueur
                    xPlayer.addInventoryItem(itemName, item.count)
                    found = true
                else
                    table.insert(newItems, item)
                end
            end

            MySQL.Async.execute(
                'UPDATE pvp_player_stash SET items = @items WHERE identifier = @id AND outpost_id = @op',
                { ['@items'] = json.encode(newItems), ['@id'] = xPlayer.identifier, ['@op'] = outpostId }
            )
        end
    )
end)

-- ── Vider le coffre ────────────────────────────────────────────────────────
RegisterNetEvent('pvp_outposts:clearStash')
AddEventHandler('pvp_outposts:clearStash', function(outpostId)
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if not isValidOutpostId(outpostId) then return end

    MySQL.Async.fetchAll(
        'SELECT items FROM pvp_player_stash WHERE identifier = @id AND outpost_id = @op',
        { ['@id'] = xPlayer.identifier, ['@op'] = outpostId },
        function(result)
            if not result[1] then return end
            local items = json.decode(result[1].items) or {}
            -- Restitue tous les items
            for _, item in ipairs(items) do
                xPlayer.addInventoryItem(item.name, item.count)
            end
            -- Vide le coffre en BDD
            MySQL.Async.execute(
                'UPDATE pvp_player_stash SET items = @items WHERE identifier = @id AND outpost_id = @op',
                { ['@items'] = json.encode({}), ['@id'] = xPlayer.identifier, ['@op'] = outpostId }
            )
        end
    )
end)

-- ══════════════════════════════════════════════════════════════════════════
--   CUSTOM VÉHICULES — Sauvegarde / Chargement par modèle
-- ══════════════════════════════════════════════════════════════════════════

-- Créer la table si elle n'existe pas
MySQL.ready(function()
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS pvp_vehicle_customs (
            identifier  VARCHAR(60)  NOT NULL,
            vehicle_model VARCHAR(60) NOT NULL,
            mods_json   LONGTEXT     NOT NULL,
            PRIMARY KEY (identifier, vehicle_model)
        )
    ]], {})
end)

-- ══════════════════════════════════════════════════════════════════════════
--   CUSTOM ARMES — Persistance DB
-- ══════════════════════════════════════════════════════════════════════════

-- Créer la table au démarrage de la resource
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS pvp_weapon_customs (
            identifier  VARCHAR(60)  NOT NULL,
            weapon_name VARCHAR(60)  NOT NULL,
            custom_json LONGTEXT     NOT NULL,
            PRIMARY KEY (identifier, weapon_name)
        )
    ]], {})
end)

-- ── Sauvegarder la custom d'une arme ─────────────────────────────────────
RegisterNetEvent('pvp_weaponcustom:save')
AddEventHandler('pvp_weaponcustom:save', function(weaponName, customData)
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or type(weaponName) ~= 'string' or type(customData) ~= 'table' then return end
    -- Validation : weaponName doit être dans Config.WeaponComponents
    if not Config.WeaponComponents[weaponName] and not Config.WeaponsTintEnabled[weaponName] then return end

    local encoded = json.encode(customData)
    -- SÉCURITÉ : borne de taille pour éviter un DoS en DB (un client pouvait
    -- envoyer plusieurs Mo de données custom pour saturer la table).
    if type(encoded) ~= 'string' or #encoded > 4096 then return end

    MySQL.Async.execute(
        [[INSERT INTO pvp_weapon_customs (identifier, weapon_name, custom_json)
          VALUES (@id, @weapon, @json)
          ON DUPLICATE KEY UPDATE custom_json = @json]],
        {
            ['@id']     = xPlayer.identifier,
            ['@weapon'] = weaponName,
            ['@json']   = encoded,
        }
    )
end)

-- ── Charger toutes les customs d'armes du joueur ─────────────────────────
RegisterNetEvent('pvp_weaponcustom:loadAll')
AddEventHandler('pvp_weaponcustom:loadAll', function()
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    MySQL.Async.fetchAll(
        'SELECT weapon_name, custom_json FROM pvp_weapon_customs WHERE identifier = @id',
        { ['@id'] = xPlayer.identifier },
        function(results)
            local customs = {}
            for _, row in ipairs(results) do
                local data = json.decode(row.custom_json)
                if data then
                    customs[row.weapon_name] = data
                end
            end
            TriggerClientEvent('pvp_weaponcustom:applyAll', src, customs)
        end
    )
end)

-- ── Sauvegarder la custom d'un modèle de véhicule ───────────────────────
RegisterNetEvent('pvp_vehiclecustom:save')
AddEventHandler('pvp_vehiclecustom:save', function(vehicleModel, customData)
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or type(vehicleModel) ~= 'string' or type(customData) ~= 'table' then return end
    -- SÉCURITÉ : vehicleModel doit être alphanumérique (nom de modèle GTA).
    if #vehicleModel < 2 or #vehicleModel > 32 or not vehicleModel:match('^[a-z0-9_]+$') then return end

    local modsJson = json.encode(customData)
    if type(modsJson) ~= 'string' or #modsJson > 8192 then return end

    MySQL.Async.execute(
        [[INSERT INTO pvp_vehicle_customs (identifier, vehicle_model, mods_json)
          VALUES (@id, @model, @json)
          ON DUPLICATE KEY UPDATE mods_json = @json]],
        {
            ['@id']    = xPlayer.identifier,
            ['@model'] = vehicleModel,
            ['@json']  = modsJson,
        }
    )
end)

-- ── Charger et appliquer la custom d'un véhicule (appelé après spawn) ───
RegisterNetEvent('pvp_vehiclecustom:load')
AddEventHandler('pvp_vehiclecustom:load', function(vehicleModel)
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not vehicleModel then return end

    MySQL.Async.fetchAll(
        'SELECT mods_json FROM pvp_vehicle_customs WHERE identifier = @id AND vehicle_model = @model',
        { ['@id'] = xPlayer.identifier, ['@model'] = vehicleModel },
        function(result)
            if result[1] and result[1].mods_json then
                local customData = json.decode(result[1].mods_json)
                if customData then
                    TriggerClientEvent('pvp_vehiclecustom:apply', src, customData)
                end
            end
        end
    )
end)

-- ══════════════════════════════════════════════════════════════════════════
--   SAFE-ZONE ENFORCEMENT SERVEUR
-- ══════════════════════════════════════════════════════════════════════════
-- SÉCURITÉ : le client utilise SetEntityInvincible quand il est en safe zone,
-- mais un cheater peut désactiver ça et tuer des gens en zone safe. Ce hook
-- annule les dégâts côté serveur si la victime OU l'attaquant est en zone
-- safe. Double protection (client cosmétique + serveur autoritatif).
local function playerIsInSafeZoneByPed(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    local coords = GetEntityCoords(ped)
    for _, op in ipairs(Config.Outposts) do
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

AddEventHandler('weaponDamageEvent', function(sender, data)
    -- data.victimGlobalId peut être un player ou une entité. On ne bloque
    -- que les dégâts PVP ped-vs-ped.
    if not data or not data.hitGlobalId or data.hitGlobalId == 0 then return end
    local victimEntity = NetworkGetEntityFromNetworkId(data.hitGlobalId)
    if not victimEntity or victimEntity == 0 or not DoesEntityExist(victimEntity) then return end
    if not IsPedAPlayer(victimEntity) then return end  -- on laisse les zombies/PNJs

    local attackerPed = GetPlayerPed(sender)
    local inSafeVictim = playerIsInSafeZoneByPed(victimEntity)
    local inSafeAttacker = playerIsInSafeZoneByPed(attackerPed)
    if inSafeVictim or inSafeAttacker then
        CancelEvent()
    end
end)

-- ── Exposition : tous les outposts (utilisé par pvp_spawn login) ──────────
exports('getAllOutposts', function()
    return Config.Outposts
end)

-- ── Exposition : nearest outpost (utilisé par pvp_spawn) ──────────────────
exports('getNearestOutpost', function(coords)
    local nearest, nearestDist = nil, math.huge
    for _, op in ipairs(Config.Outposts) do
        local d = #(vector3(coords.x, coords.y, coords.z) - vector3(op.coords.x, op.coords.y, op.coords.z))
        if d < nearestDist then
            nearest     = op
            nearestDist = d
        end
    end
    return nearest
end)
