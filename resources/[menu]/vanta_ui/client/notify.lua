-- =============================================
--   VANTA UI — Notifications génériques (client)
-- =============================================
-- Remplace le détournement de `pvp_market:notify` : n'importe quelle resource
-- VANTA peut notifier un joueur sans dépendre de pvp_market ni de pvp_inventory.
--
-- Usage client  : exports['vanta_ui']:notify('Message', 'success')
-- Usage serveur : exports['vanta_ui']:notify(source, 'Message', 'success')
--
-- Types acceptés : 'success' | 'error' | 'warning' | 'info'
-- (true/false acceptés aussi pour compat avec l'ancien format booléen)

local VALID_KINDS = {
    success = true,
    error   = true,
    warning = true,
    info    = true,
}

local function normalizeKind(kind)
    if kind == true  then return 'success' end
    if kind == false then return 'error'   end
    if type(kind) == 'string' and VALID_KINDS[kind] then return kind end
    return 'info'
end

local function show(msg, kind, duration, title)
    if type(msg) ~= 'string' or msg == '' then return end
    SendNUIMessage({
        type     = 'vanta:notify',
        msg      = msg,
        kind     = normalizeKind(kind),
        duration = tonumber(duration) or 4000,
        title    = type(title) == 'string' and title or nil,
    })
end

-- ── Export client ────────────────────────────────────────────────────────
exports('notify', function(msg, kind, duration, title)
    show(msg, kind, duration, title)
end)

exports('notifyClear', function()
    SendNUIMessage({ type = 'vanta:notifyClear' })
end)

-- ── Event réseau (déclenché par le serveur) ──────────────────────────────
RegisterNetEvent('vanta_ui:notify')
AddEventHandler('vanta_ui:notify', function(msg, kind, duration, title)
    show(msg, kind, duration, title)
end)
