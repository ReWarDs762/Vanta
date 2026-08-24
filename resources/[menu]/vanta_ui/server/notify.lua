-- =============================================
--   VANTA UI — Notifications génériques (serveur)
-- =============================================
-- exports['vanta_ui']:notify(source, 'Message', 'success')
-- exports['vanta_ui']:notifyAll('Message', 'info')

exports('notify', function(src, msg, kind, duration, title)
    src = tonumber(src)
    if not src or src <= 0 then return end
    if type(msg) ~= 'string' or msg == '' then return end
    TriggerClientEvent('vanta_ui:notify', src, msg, kind, duration, title)
end)

exports('notifyAll', function(msg, kind, duration, title)
    if type(msg) ~= 'string' or msg == '' then return end
    TriggerClientEvent('vanta_ui:notify', -1, msg, kind, duration, title)
end)
