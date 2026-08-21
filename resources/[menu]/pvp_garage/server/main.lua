-- [SERVER — pvp_garage]

local ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- [ROUTING BUCKETS — sessions de customisation privées]
-- Chaque joueur reçoit un bucket = source + 1000 (évite les conflits avec bucket 0)
local customSessions = {} -- [source] = vehicleNetId

local function getBucketId(source)
    return tonumber(source) + 1000
end

local function exitSession(source)
    local vehicleNetId = customSessions[tostring(source)]
    SetPlayerRoutingBucket(source, 0)
    if vehicleNetId then
        local entity = NetworkGetEntityFromNetworkId(vehicleNetId)
        if entity and entity ~= 0 then
            SetEntityRoutingBucket(entity, 0)
        end
    end
    customSessions[tostring(source)] = nil
end

RegisterServerEvent('pvp_garage:enterCustomSession')
AddEventHandler('pvp_garage:enterCustomSession', function(vehicleNetId)
    local source = source
    local bucketId = getBucketId(source)
    customSessions[tostring(source)] = vehicleNetId

    SetPlayerRoutingBucket(source, bucketId)

    -- Attend que l'entité soit disponible côté serveur avant de changer son bucket
    Citizen.CreateThread(function()
        local entity = 0
        local attempts = 0
        while entity == 0 and attempts < 30 do
            entity = NetworkGetEntityFromNetworkId(vehicleNetId)
            if entity == 0 then
                Citizen.Wait(100)
                attempts = attempts + 1
            end
        end
        if entity ~= 0 then
            SetEntityRoutingBucket(entity, bucketId)
            print(('[pvp_garage] Source %s → bucket %s (vehicle entity %s)'):format(source, bucketId, entity))
        else
            print(('[pvp_garage] WARN: entité véhicule introuvable pour netId %s'):format(vehicleNetId))
        end
    end)
end)

RegisterServerEvent('pvp_garage:exitCustomSession')
AddEventHandler('pvp_garage:exitCustomSession', function()
    local source = source
    exitSession(source)
    print(('[pvp_garage] Source %s → bucket 0 (retour monde principal)'):format(source))
end)

-- Nettoyage automatique si le joueur quitte pendant une session
AddEventHandler('playerDropped', function()
    local source = source
    if customSessions[tostring(source)] then
        exitSession(source)
    end
end)

-- [HELPER — find vehicle price in catalog]
local function GetVehiclePrice(model)
    for _, v in ipairs(Config.Vehicles) do
        if v.model == model then
            return v.price
        end
    end
    return nil
end

-- SÉCURITÉ : validation format item véhicule
local function isValidVehicleItemName(name)
    if type(name) ~= 'string' then return false end
    if #name < 9 or #name > 50 then return false end
    return name:match('^vehicle_[a-z0-9_]+$') ~= nil
end

-- SÉCURITÉ : helper safe-zone côté serveur (dealer dispo uniquement dans les outposts)
local function isPlayerInSafeZone(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local coords = GetEntityCoords(ped)
    local ok, outposts = pcall(function()
        return exports['pvp_outposts']:getAllOutposts()
    end)
    if not ok or not outposts then return false end
    for _, op in ipairs(outposts) do
        local r = op.safeRadius or 50.0
        local dx = coords.x - op.coords.x
        local dy = coords.y - op.coords.y
        local dz = coords.z - op.coords.z
        if (dx*dx + dy*dy + dz*dz) < (r * r) then return true end
    end
    return false
end

-- [CALLBACK — Acheter un panier de véhicules → items inventaire]
-- items = tableau de { name, label, price, count }
-- destination = 'inventory' | 'stash'
ESX.RegisterServerCallback('pvp_garage:buyVehicleCart', function(source, cb, items, destination)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then cb(false, 'Joueur introuvable') return end

    -- SÉCURITÉ : achat dealer = safe-zone uniquement
    if not isPlayerInSafeZone(source) then
        cb(false, 'Concessionnaire disponible en zone safe uniquement')
        return
    end

    -- SÉCURITÉ : validation structure panier
    if type(items) ~= 'table' or #items == 0 or #items > 50 then
        cb(false, 'Panier invalide')
        return
    end

    -- Calcul du total
    local total = 0
    for _, entry in ipairs(items) do
        if type(entry) ~= 'table' or not isValidVehicleItemName(entry.name) then
            cb(false, 'Item invalide')
            return
        end
        local count = math.floor(tonumber(entry.count) or 1)
        if count < 1 or count > 50 then
            cb(false, 'Quantité invalide')
            return
        end
        entry.count = count
        local price = GetVehiclePrice(entry.name:gsub('^vehicle_', ''))
        if not price then
            cb(false, 'Véhicule introuvable : ' .. tostring(entry.name))
            return
        end
        total = total + price * count
    end

    local bankAccount = xPlayer.getAccount('bank')
    if bankAccount.money < total then
        cb(false, 'Fonds insuffisants (' .. total .. '$ requis)')
        return
    end

    xPlayer.removeAccountMoney('bank', total)

    -- Ajoute chaque item à l'inventaire
    for _, entry in ipairs(items) do
        local count = entry.count or 1
        for _ = 1, count do
            xPlayer.addInventoryItem(entry.name, 1)
        end
        print(('[pvp_garage] %s (ID:%s) a acheté x%s %s'):format(xPlayer.getName(), source, count, entry.name))
    end

    local newBalance = xPlayer.getAccount('bank').money
    cb(true, newBalance)
end)

-- [CALLBACK — Vendre un item véhicule depuis l'inventaire]
-- item = nom de l'item (ex: 'vehicle_zentorno')
ESX.RegisterServerCallback('pvp_garage:sellVehicleItem', function(source, cb, itemName)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then cb(false, 0) return end

    -- SÉCURITÉ : vente dealer = safe-zone + nom valide
    if not isValidVehicleItemName(itemName) then cb(false, 0) return end
    if not isPlayerInSafeZone(source) then cb(false, 0) return end

    -- Vérifie que le joueur possède l'item
    local invItem = xPlayer.getInventoryItem(itemName)
    if not invItem or invItem.count < 1 then
        cb(false, 0)
        return
    end

    local model = itemName:gsub('^vehicle_', '')
    local price = GetVehiclePrice(model)
    local sellPrice = price and math.floor(price * 0.5) or 500

    xPlayer.removeInventoryItem(itemName, 1)
    xPlayer.addAccountMoney('bank', sellPrice)
    print(('[pvp_garage] %s (ID:%s) a vendu %s pour %s$'):format(xPlayer.getName(), source, itemName, sellPrice))
    local newBalance = xPlayer.getAccount('bank').money
    cb(true, sellPrice, newBalance)
end)

-- [LOG EVENTS]
-- SÉCURITÉ : strip control chars + cap length (anti log injection)
RegisterServerEvent('pvp_garage:log')
AddEventHandler('pvp_garage:log', function(message)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    if type(message) ~= 'string' then return end
    message = message:gsub('[%z\1-\31]', ''):sub(1, 200)
    print(('[pvp_garage] %s (ID:%s): %s'):format(xPlayer.getName(), source, message))
end)
