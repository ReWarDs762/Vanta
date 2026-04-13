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

-- [CALLBACK — Acheter un panier de véhicules → items inventaire]
-- items = tableau de { name, label, price, count }
-- destination = 'inventory' | 'stash'
ESX.RegisterServerCallback('pvp_garage:buyVehicleCart', function(source, cb, items, destination)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then cb(false, 'Joueur introuvable') return end

    -- Calcul du total
    local total = 0
    for _, entry in ipairs(items) do
        local price = GetVehiclePrice(entry.name:gsub('^vehicle_', ''))
        if not price then
            cb(false, 'Véhicule introuvable : ' .. tostring(entry.name))
            return
        end
        total = total + price * (entry.count or 1)
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
RegisterServerEvent('pvp_garage:log')
AddEventHandler('pvp_garage:log', function(message)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        print(('[pvp_garage] %s (ID:%s): %s'):format(xPlayer.getName(), source, message))
    end
end)
