-- =============================================
--   PVP ADMIN — Configuration
-- =============================================

AdminConfig = {}

-- Touche pour ouvrir le panel admin (F7 = 168)
AdminConfig.OpenKey = 168

-- Vitesse du noclip
AdminConfig.NoclipSpeedNormal = 2.0
AdminConfig.NoclipSpeedFast   = 6.0   -- maintenir SHIFT
AdminConfig.NoclipSpeedSlow   = 0.5   -- maintenir CTRL

-- Distance max pour tuer les zombies autour (/killzombies)
AdminConfig.KillZombiesRadius = 200.0

-- Auto-refresh liste joueurs dans le panel (ms)
AdminConfig.AutoRefreshMs = 10000

-- ══ PERMISSIONS PAR RÔLE ═══════════════════════════════════════════════════
-- Les rôles sont cumulatifs : admin hérite de mod, superadmin hérite de admin
-- Tu peux ajouter le groupe "mod" à un joueur dans ESX pour un accès limité

AdminConfig.RolePermissions = {
    mod = {
        'heal', 'freeze', 'spectate', 'goto', 'bring', 'kick',
        'killzombies', 'tpwp', 'noclip', 'god',
    },
    admin = {
        -- hérite de mod +
        'slay', 'revive', 'give', 'givemoney', 'givexp', 'clearinv',
        'spawncar', 'deletecar', 'spawnzombies',
        'announce', 'setweather', 'settime',
        'forcedrop', 'rzrotate',
        'ban', 'unban',
    },
    superadmin = {
        -- hérite de admin — tout est autorisé
    },
}
