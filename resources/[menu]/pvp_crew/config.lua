Config = {}

Config.MaxCrewNameLength = 30
Config.MaxCrewTagLength  = 5
Config.MinCrewTagLength  = 2
Config.MaxCrewMembers    = 20
Config.MaxSquadMembers   = 4
Config.InviteExpireSeconds = 300  -- 5 minutes
Config.CrewCreationCost  = 5000  -- dollars (bank)

-- Blip pour les membres du squad sur la minimap
Config.SquadBlipSprite = 1
Config.SquadBlipColor  = 2   -- vert
Config.SquadBlipScale  = 0.8

-- Touche pour ouvrir le menu squad (J = 44)
Config.OpenKey = 44

-- ══════════════════════════════════════════════════════════════════════════
--   CONTRAT QUOTIDIEN DE CREW — élimination de zombies
-- ══════════════════════════════════════════════════════════════════════════
-- L'objectif du contrat s'adapte au nombre de membres qui participent
-- réellement (au moins 1 zombie tué pour le crew dans la journée) :
--   target = ZombiesPerMember × nombre de participants actifs
-- Basé sur pvp_zombies/config.lua : un joueur seul peut raisonnablement tuer
-- plusieurs dizaines de zombies/jour en jeu occasionnel (spawn toutes les 8s,
-- jusqu'à 40 zombies actifs autour de lui). 25/membre garde le contrat
-- atteignable à 1 joueur sans le rendre trivial pour un crew de 20.
Config.DailyContract = {
    ZombiesPerMember     = 25,   -- quota individuel (zombies) par participant actif
    MinParticipants      = 1,    -- target plancher = ZombiesPerMember × 1, même crew vide/inactif
    MaxParticipants       = Config.MaxCrewMembers, -- cap = taille max d'un crew (20)

    -- Récompense en crédits de crew (trésorerie collective = pvp_crews.bank,
    -- réutilisé tel quel : déjà un puits d'argent crédité par les objectifs
    -- existants, jamais retirable en argent personnel — voir pvp_crew_objectives).
    RewardPerParticipant = 40,   -- crédits par participant actif ayant contribué
    MinReward            = 40,   -- plancher (crew à 1 participant)
    MaxReward            = 800,  -- plafond (évite qu'un très gros crew farme sans limite)
}

-- ══════════════════════════════════════════════════════════════════════════
--   BOUTIQUE DE CREW — avantages temporaires payés en crédits de crew
-- ══════════════════════════════════════════════════════════════════════════
-- Un contrat quotidien avec un crew actif de 3-5 joueurs rapporte ~120-200
-- crédits/jour : chaque bonus coûte donc l'équivalent de 3 à 5 jours de
-- contrats, cohérent avec une trésorerie *collective* qui se construit sur
-- la durée plutôt qu'un achat impulsif.
-- `value` : multiplicateur XP (zombie_xp2/pvp_xp50) ou bonus kg (container_boost).
-- `durationMinutes`/`value` du bonus de conteneur configurables séparément.
Config.CrewShop = {
    {
        key             = 'zombie_xp2',
        label           = 'XP Zombies x2',
        description     = 'Double l\'XP gagnée sur les zombies pour tout le crew.',
        cost            = 600,
        durationMinutes = 120,
        value           = 2.0,
    },
    {
        key             = 'pvp_xp50',
        label           = 'XP PvP +50%',
        description     = '+50% d\'XP sur les kills joueurs pour tout le crew.',
        cost            = 800,
        durationMinutes = 120,
        value           = 1.5,
    },
    {
        key             = 'container_boost',
        label           = 'Coffre protégé +10kg',
        description     = 'Augmente la capacité du coffre protégé personnel de chaque membre.',
        cost            = 500,
        durationMinutes = 120,
        value           = 10, -- kg supplémentaires
    },
}

-- Seuls owner/officier peuvent dépenser la trésorerie du crew (achat boutique)
-- — même permission que MOTD/couleur/gestion ('manage' dans ROLE_PERMISSIONS).
