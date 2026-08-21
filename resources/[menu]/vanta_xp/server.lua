-- ═══════════════════════════════════════════════════════════════════════════
--   VANTA XP — Serveur
--   Système XP / Niveaux 1-100 / Prestige 0-5 / Bonus capacité
--   ESX Legacy + oxmysql
-- ═══════════════════════════════════════════════════════════════════════════

local ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- ── Cache des profils en mémoire ─────────────────────────────────────────
-- [identifier] = { xp, level, prestige_level, total_xp_earned, dirty }
local profiles = {}

-- ══════════════════════════════════════════════════════════════════════════
--   INITIALISATION : Table SQL
-- ══════════════════════════════════════════════════════════════════════════

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `vanta_xp` (
            `identifier`      VARCHAR(60)  NOT NULL,
            `xp`              INT          NOT NULL DEFAULT 0,
            `level`           INT          NOT NULL DEFAULT 1,
            `prestige_level`  INT          NOT NULL DEFAULT 0,
            `total_xp_earned` INT          NOT NULL DEFAULT 0,
            PRIMARY KEY (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {}, function()
        print('[vanta_xp] Table vanta_xp prête.')
    end)
end)

-- ══════════════════════════════════════════════════════════════════════════
--   HELPERS
-- ══════════════════════════════════════════════════════════════════════════

-- Récupère le source serveur d'un joueur par identifier
local function getSourceByIdentifier(identifier)
    local xPlayers = ESX.GetPlayers()
    for _, src in ipairs(xPlayers) do
        local xP = ESX.GetPlayerFromId(src)
        if xP and xP.identifier == identifier then
            return src
        end
    end
    return nil
end

-- Données prestige depuis config
local function getPrestigeData(prestigeLevel)
    return VantaXP.Prestige[prestigeLevel] or VantaXP.Prestige[0]
end

-- XP nécessaire pour passer du niveau actuel au suivant
local function xpToNextLevel(currentLevel)
    if currentLevel >= VantaXP.MaxLevel then return 0 end
    return VantaXP.GetXPForLevel(currentLevel + 1) - VantaXP.GetXPForLevel(currentLevel)
end

-- XP accumulé dans le niveau actuel (pour la barre de progression)
local function xpInCurrentLevel(profile)
    if profile.level >= VantaXP.MaxLevel then return 0 end
    local xpForCurrent = VantaXP.GetXPForLevel(profile.level)
    return profile.xp - xpForCurrent
end

-- XP nécessaire pour le niveau actuel (pour la barre)
local function xpNeededForCurrentLevel(profile)
    if profile.level >= VantaXP.MaxLevel then return 0 end
    return VantaXP.GetXPForLevel(profile.level + 1) - VantaXP.GetXPForLevel(profile.level)
end

-- ══════════════════════════════════════════════════════════════════════════
--   CHARGEMENT / SAUVEGARDE PROFIL
-- ══════════════════════════════════════════════════════════════════════════

local function loadProfile(identifier, cb)
    if profiles[identifier] then
        if cb then cb(profiles[identifier]) end
        return
    end

    MySQL.Async.fetchAll(
        'SELECT * FROM vanta_xp WHERE identifier = @id',
        { ['@id'] = identifier },
        function(rows)
            if rows and rows[1] then
                profiles[identifier] = {
                    xp              = tonumber(rows[1].xp) or 0,
                    level           = tonumber(rows[1].level) or 1,
                    prestige_level  = tonumber(rows[1].prestige_level) or 0,
                    total_xp_earned = tonumber(rows[1].total_xp_earned) or 0,
                    dirty           = false,
                }
            else
                -- Nouveau joueur : créer en BDD
                profiles[identifier] = {
                    xp = 0, level = 1, prestige_level = 0,
                    total_xp_earned = 0, dirty = false,
                }
                MySQL.Async.execute(
                    'INSERT INTO vanta_xp (identifier, xp, level, prestige_level, total_xp_earned) VALUES (@id, 0, 1, 0, 0)',
                    { ['@id'] = identifier }
                )
            end
            if cb then cb(profiles[identifier]) end
        end
    )
end

local function saveProfile(identifier)
    local p = profiles[identifier]
    if not p or not p.dirty then return end
    MySQL.Async.execute(
        'UPDATE vanta_xp SET xp = @xp, level = @lvl, prestige_level = @pres, total_xp_earned = @total WHERE identifier = @id',
        {
            ['@id']    = identifier,
            ['@xp']    = p.xp,
            ['@lvl']   = p.level,
            ['@pres']  = p.prestige_level,
            ['@total'] = p.total_xp_earned,
        }
    )
    p.dirty = false
end

local function saveAllProfiles()
    for identifier, _ in pairs(profiles) do
        saveProfile(identifier)
    end
end

-- ══════════════════════════════════════════════════════════════════════════
--   APPLIQUER BONUS CAPACITÉ (via exports pvp_inventory)
-- ══════════════════════════════════════════════════════════════════════════

local function applyPrestigeBonuses(identifier)
    local p = profiles[identifier]
    if not p then return end

    local presData = getPrestigeData(p.prestige_level)

    -- Appliquer les bonus via les exports ajoutés dans pvp_inventory
    local ok1, err1 = pcall(function()
        exports['pvp_inventory']:setBagBonus(identifier, presData.bag_bonus)
    end)
    if not ok1 then
        print('[vanta_xp] WARN: setBagBonus échoué pour ' .. identifier .. ' : ' .. tostring(err1))
    end

    local ok2, err2 = pcall(function()
        exports['pvp_inventory']:setContainerBonus(identifier, presData.cont_bonus)
    end)
    if not ok2 then
        print('[vanta_xp] WARN: setContainerBonus échoué pour ' .. identifier .. ' : ' .. tostring(err2))
    end

    if ok1 and ok2 then
        print(('[vanta_xp] Bonus prestige %d appliqués pour %s — sac +%dkg, coffre +%dkg'):format(
            p.prestige_level, identifier, presData.bag_bonus, presData.cont_bonus))
    end
end

-- ══════════════════════════════════════════════════════════════════════════
--   CORE : AJOUTER DE L'XP
-- ══════════════════════════════════════════════════════════════════════════

local function addXP(identifier, amount, source)
    if not identifier or not amount or amount <= 0 then return end
    local p = profiles[identifier]
    if not p then
        -- Charger le profil d'abord puis réessayer
        loadProfile(identifier, function()
            addXP(identifier, amount, source)
        end)
        return
    end

    -- Ajouter l'XP
    p.xp = p.xp + amount
    p.total_xp_earned = p.total_xp_earned + amount
    p.dirty = true

    -- Level up multi-niveaux
    local levelsGained = 0
    while p.level < VantaXP.MaxLevel do
        local xpNeeded = VantaXP.GetXPForLevel(p.level + 1)
        if p.xp >= xpNeeded then
            p.level = p.level + 1
            levelsGained = levelsGained + 1
        else
            break
        end
    end

    -- Cap au max level
    if p.level >= VantaXP.MaxLevel then
        p.level = VantaXP.MaxLevel
        local maxXP = VantaXP.GetXPForLevel(VantaXP.MaxLevel)
        if p.xp > maxXP then p.xp = maxXP end
    end

    -- Notifier le client
    local src = getSourceByIdentifier(identifier)
    if src then
        -- Notifier l'ajout d'XP
        TriggerClientEvent('vanta_xp:xpAdded', src, amount, source or 'unknown')

        -- Notifier les level ups
        if levelsGained > 0 then
            TriggerClientEvent('vanta_xp:levelUp', src, p.level)
        end

        -- Envoyer le profil mis à jour pour la NUI
        TriggerClientEvent('vanta_xp:profileUpdate', src, buildProfilePayload(identifier))
    end

    -- Log serveur
    print(('[vanta_xp] %s +%d XP (%s) → LVL %d | Total: %d'):format(
        identifier, amount, source or '?', p.level, p.total_xp_earned))
end

-- ── Construire le payload profil pour le client ──────────────────────────
function buildProfilePayload(identifier)
    local p = profiles[identifier]
    if not p then return nil end

    local presData = getPrestigeData(p.prestige_level)
    local xpCurrent = xpInCurrentLevel(p)
    local xpNeeded  = xpNeededForCurrentLevel(p)

    return {
        xp              = p.xp,
        level           = p.level,
        prestige_level  = p.prestige_level,
        total_xp_earned = p.total_xp_earned,
        xp_in_level     = xpCurrent,
        xp_to_next      = xpNeeded,
        xp_percent      = (xpNeeded > 0) and math.floor((xpCurrent / xpNeeded) * 100) or 100,
        bag_capacity    = VantaXP.BaseBagCapacity + presData.bag_bonus,
        cont_capacity   = VantaXP.BaseContainerCapacity + presData.cont_bonus,
        badge_html      = presData.badge_html,
        prestige_label  = presData.label,
        max_level       = VantaXP.MaxLevel,
        max_prestige    = VantaXP.MaxPrestige,
        can_prestige    = (p.level >= VantaXP.MaxLevel and p.prestige_level < VantaXP.MaxPrestige),
    }
end

-- ══════════════════════════════════════════════════════════════════════════
--   EXPORTS
-- ══════════════════════════════════════════════════════════════════════════

-- Export : ajouter de l'XP à un joueur
exports('addXP', function(identifier, amount, source)
    addXP(identifier, amount, source)
end)

-- Export : récupérer le profil complet d'un joueur
exports('getProfile', function(identifier)
    local p = profiles[identifier]
    if not p then return nil end
    return buildProfilePayload(identifier)
end)

-- Export : récupérer le bonus sac d'un joueur (en kg)
exports('getBagBonus', function(identifier)
    local p = profiles[identifier]
    if not p then return 0 end
    local presData = getPrestigeData(p.prestige_level)
    return presData.bag_bonus
end)

-- Export : récupérer le bonus conteneur d'un joueur (en kg)
exports('getContainerBonus', function(identifier)
    local p = profiles[identifier]
    if not p then return 0 end
    local presData = getPrestigeData(p.prestige_level)
    return presData.cont_bonus
end)

-- ══════════════════════════════════════════════════════════════════════════
--   HOOKS : EVENTS PVP & ZOMBIES
-- ══════════════════════════════════════════════════════════════════════════

-- ── Hooks INTERNES serveur (pas de RegisterNetEvent : clients ne peuvent pas trigger) ─
-- SÉCURITÉ : avant, vanta_xp utilisait RegisterNetEvent sur les mêmes events que
-- pvp_killfeed/pvp_zombies. Un client pouvait TriggerServerEvent directement et
-- farmer de l'XP. Ces events ne sont plus que des AddEventHandler, et sont fired
-- uniquement depuis le serveur par pvp_killfeed/pvp_zombies APRÈS leurs validations.

AddEventHandler('vanta_xp:internalPlayerKill', function(killerSrc)
    killerSrc = tonumber(killerSrc)
    if not killerSrc or killerSrc <= 0 then return end
    local killerXPlayer = ESX.GetPlayerFromId(killerSrc)
    if not killerXPlayer then return end
    addXP(killerXPlayer.identifier, VantaXP.XPSources.player_kill, 'player_kill')
end)

AddEventHandler('vanta_xp:internalZombieKill', function(killerSrc)
    killerSrc = tonumber(killerSrc)
    if not killerSrc or killerSrc <= 0 then return end
    local xPlayer = ESX.GetPlayerFromId(killerSrc)
    if not xPlayer then return end
    addXP(xPlayer.identifier, VantaXP.XPSources.zombie_kill, 'zombie_kill')
end)

-- ══════════════════════════════════════════════════════════════════════════
--   CHARGEMENT AU SPAWN / CONNEXION
-- ══════════════════════════════════════════════════════════════════════════

-- Quand un joueur spawn (ESX)
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    local src = playerId
    if not xPlayer then
        xPlayer = ESX.GetPlayerFromId(src)
    end
    if not xPlayer then return end

    loadProfile(xPlayer.identifier, function(profile)
        -- Appliquer les bonus de prestige
        applyPrestigeBonuses(xPlayer.identifier)

        -- Envoyer le profil au client
        TriggerClientEvent('vanta_xp:profileUpdate', src, buildProfilePayload(xPlayer.identifier))

        print(('[vanta_xp] Profil chargé pour %s — LVL %d | P%d | XP %d'):format(
            xPlayer.identifier, profile.level, profile.prestige_level, profile.xp))
    end)
end)

-- Au cas où le joueur se reconnecte (re-fetch)
RegisterNetEvent('vanta_xp:requestProfile')
AddEventHandler('vanta_xp:requestProfile', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    loadProfile(xPlayer.identifier, function()
        applyPrestigeBonuses(xPlayer.identifier)
        TriggerClientEvent('vanta_xp:profileUpdate', src, buildProfilePayload(xPlayer.identifier))
    end)
end)

-- ══════════════════════════════════════════════════════════════════════════
--   COMMANDE /prestige
-- ══════════════════════════════════════════════════════════════════════════

RegisterCommand('prestige', function(src, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local p = profiles[xPlayer.identifier]
    if not p then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1VANTA XP', 'Profil non chargé. Réessaie.' } })
        return
    end

    if p.level < VantaXP.MaxLevel then
        TriggerClientEvent('chat:addMessage', src, {
            args = { '^1VANTA XP', 'Tu dois être niveau ' .. VantaXP.MaxLevel .. ' pour passer au prestige ! (actuel: ' .. p.level .. ')' }
        })
        return
    end

    if p.prestige_level >= VantaXP.MaxPrestige then
        TriggerClientEvent('chat:addMessage', src, {
            args = { '^1VANTA XP', 'Tu es déjà au prestige maximum (' .. VantaXP.MaxPrestige .. ') !' }
        })
        return
    end

    -- Effectuer le prestige
    p.prestige_level = p.prestige_level + 1
    p.level = 1
    p.xp = 0
    p.dirty = true

    -- Sauvegarder immédiatement
    saveProfile(xPlayer.identifier)

    -- Appliquer les nouveaux bonus
    applyPrestigeBonuses(xPlayer.identifier)

    -- Notifier le client
    TriggerClientEvent('vanta_xp:prestigeUp', src, p.prestige_level)
    TriggerClientEvent('vanta_xp:profileUpdate', src, buildProfilePayload(xPlayer.identifier))

    -- Refresh inventaire pour appliquer les nouveaux poids max
    TriggerEvent('pvp_inventory:refreshData')

    local presData = getPrestigeData(p.prestige_level)
    print(('[vanta_xp] PRESTIGE ! %s → P%d (%s)'):format(
        xPlayer.identifier, p.prestige_level, presData.label))
end, false)

-- ══════════════════════════════════════════════════════════════════════════
--   COMMANDES ADMIN
-- ══════════════════════════════════════════════════════════════════════════

-- /givexp [id] [amount]
RegisterCommand('givexp', function(src, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if not VantaXP.AdminGroups[xPlayer.getGroup()] then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1ERREUR', 'Permission refusée.' } })
        return
    end

    local targetId = tonumber(args[1])
    local amount   = tonumber(args[2])
    if not targetId or not amount or amount <= 0 then
        TriggerClientEvent('chat:addMessage', src, { args = { '^3USAGE', '/givexp [id] [amount]' } })
        return
    end
    -- SÉCURITÉ : borner l'amount pour éviter overflow INT
    amount = math.min(math.floor(amount), 10000000)

    local targetXP = ESX.GetPlayerFromId(targetId)
    if not targetXP then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1ERREUR', 'Joueur #' .. targetId .. ' introuvable.' } })
        return
    end

    addXP(targetXP.identifier, amount, 'admin_givexp')
    TriggerClientEvent('chat:addMessage', src, {
        args = { '^2VANTA XP', '+' .. amount .. ' XP donné à #' .. targetId }
    })
end, false)

-- /setlevel [id] [level]
RegisterCommand('setlevel', function(src, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if not VantaXP.AdminGroups[xPlayer.getGroup()] then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1ERREUR', 'Permission refusée.' } })
        return
    end

    local targetId = tonumber(args[1])
    local level    = tonumber(args[2])
    if not targetId or not level or level < 1 or level > VantaXP.MaxLevel then
        TriggerClientEvent('chat:addMessage', src, { args = { '^3USAGE', '/setlevel [id] [1-' .. VantaXP.MaxLevel .. ']' } })
        return
    end

    local targetXP = ESX.GetPlayerFromId(targetId)
    if not targetXP then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1ERREUR', 'Joueur introuvable.' } })
        return
    end

    local p = profiles[targetXP.identifier]
    if not p then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1ERREUR', 'Profil non chargé.' } })
        return
    end

    p.level = level
    p.xp = VantaXP.GetXPForLevel(level)
    p.dirty = true
    saveProfile(targetXP.identifier)

    TriggerClientEvent('vanta_xp:profileUpdate', targetId, buildProfilePayload(targetXP.identifier))
    TriggerClientEvent('chat:addMessage', src, {
        args = { '^2VANTA XP', 'Joueur #' .. targetId .. ' → niveau ' .. level }
    })
end, false)

-- /setprestige [id] [level]
RegisterCommand('setprestige', function(src, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if not VantaXP.AdminGroups[xPlayer.getGroup()] then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1ERREUR', 'Permission refusée.' } })
        return
    end

    local targetId     = tonumber(args[1])
    local prestigeLevel = tonumber(args[2])
    if not targetId or not prestigeLevel or prestigeLevel < 0 or prestigeLevel > VantaXP.MaxPrestige then
        TriggerClientEvent('chat:addMessage', src, { args = { '^3USAGE', '/setprestige [id] [0-' .. VantaXP.MaxPrestige .. ']' } })
        return
    end

    local targetXP = ESX.GetPlayerFromId(targetId)
    if not targetXP then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1ERREUR', 'Joueur introuvable.' } })
        return
    end

    local p = profiles[targetXP.identifier]
    if not p then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1ERREUR', 'Profil non chargé.' } })
        return
    end

    p.prestige_level = prestigeLevel
    p.dirty = true
    saveProfile(targetXP.identifier)
    applyPrestigeBonuses(targetXP.identifier)

    TriggerClientEvent('vanta_xp:profileUpdate', targetId, buildProfilePayload(targetXP.identifier))
    TriggerClientEvent('chat:addMessage', src, {
        args = { '^2VANTA XP', 'Joueur #' .. targetId .. ' → prestige ' .. prestigeLevel }
    })
end, false)

-- ══════════════════════════════════════════════════════════════════════════
--   SAUVEGARDE AUTOMATIQUE
-- ══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(VantaXP.AutoSaveInterval)
        saveAllProfiles()
        print('[vanta_xp] Sauvegarde auto — ' .. tableCount(profiles) .. ' profils.')
    end
end)

-- Helper : compter les éléments d'une table
function tableCount(t)
    local c = 0
    for _ in pairs(t) do c = c + 1 end
    return c
end

-- ── Sauvegarde à la déconnexion ──────────────────────────────────────────
AddEventHandler('playerDropped', function(reason)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer and profiles[xPlayer.identifier] then
        saveProfile(xPlayer.identifier)
        -- Garder en cache quelques minutes au cas où reconn rapide
        SetTimeout(300000, function()
            -- Nettoyer le cache si le joueur ne s'est pas reconnecté
            if not getSourceByIdentifier(xPlayer.identifier) then
                profiles[xPlayer.identifier] = nil
            end
        end)
    end
end)

-- ── Sauvegarde à l'arrêt du serveur / restart resource ──────────────────
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    saveAllProfiles()
    print('[vanta_xp] Sauvegarde finale — tous les profils enregistrés.')
end)
