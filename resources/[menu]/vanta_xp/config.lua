-- ═══════════════════════════════════════════════════════════════════════════
--   VANTA XP — Configuration
-- ═══════════════════════════════════════════════════════════════════════════

VantaXP = {}

-- ── XP par source ────────────────────────────────────────────────────────
VantaXP.XPSources = {
    player_kill = 300,   -- Kill d'un joueur
    zombie_kill = 50,    -- Kill d'un zombie
    -- Extensible : ajouter d'autres sources ici
    -- mission_complete = 500,
    -- outpost_capture = 200,
}

-- ── Niveaux ──────────────────────────────────────────────────────────────
VantaXP.MaxLevel    = 100
VantaXP.MaxPrestige = 5

-- Formule XP requis pour atteindre un niveau donné (cumulatif depuis le niveau 1)
-- xp_requis = 100 * (level ^ 1.5)
function VantaXP.GetXPForLevel(level)
    if level <= 1 then return 0 end
    return math.floor(100 * (level ^ 1.5))
end

-- ── Capacités de base ────────────────────────────────────────────────────
VantaXP.BaseBagCapacity       = 50   -- kg
VantaXP.BaseContainerCapacity = 20   -- kg

-- ── Prestige — bonus cumulatifs ──────────────────────────────────────────
-- Chaque prestige ajoute +6kg sac et +4kg conteneur (cumulatif)
VantaXP.Prestige = {
    -- P0 : pas de bonus (recrut)
    [0] = {
        label        = 'RECRUIT',
        bag_bonus    = 0,
        cont_bonus   = 0,
        badge_html   = '<span class="badge-prestige p0">RECRUIT</span>',
    },
    [1] = {
        label        = 'PRESTIGE I',
        bag_bonus    = 6,    -- 56 kg total
        cont_bonus   = 4,    -- 24 kg total
        badge_html   = '<span class="badge-prestige p1">◆ I</span>',
    },
    [2] = {
        label        = 'PRESTIGE II',
        bag_bonus    = 12,   -- 62 kg total
        cont_bonus   = 8,    -- 28 kg total
        badge_html   = '<span class="badge-prestige p2">◆◆ II</span>',
    },
    [3] = {
        label        = 'PRESTIGE III',
        bag_bonus    = 18,   -- 68 kg total
        cont_bonus   = 12,   -- 32 kg total
        badge_html   = '<span class="badge-prestige p3">✦✦✦ III</span>',
    },
    [4] = {
        label        = 'PRESTIGE IV',
        bag_bonus    = 24,   -- 74 kg total
        cont_bonus   = 16,   -- 36 kg total
        badge_html   = '<span class="badge-prestige p4">⬡ IV</span>',
    },
    [5] = {
        label        = 'PRESTIGE V — VANTA',
        bag_bonus    = 30,   -- 80 kg total
        cont_bonus   = 20,   -- 40 kg total
        badge_html   = '<span class="badge-prestige p5">⬟ VANTA</span>',
    },
}

-- ── Sauvegarde automatique (ms) ──────────────────────────────────────────
VantaXP.AutoSaveInterval = 300000  -- 5 minutes

-- ── Groupes admin autorisés ──────────────────────────────────────────────
VantaXP.AdminGroups = { ['admin'] = true, ['superadmin'] = true }
