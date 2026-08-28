-- =============================================
--   PVP CHARACTER — body.lua
--   État corporel imposé : tous les joueurs sont en sous-vêtement.
--
--   DÉCISION PRODUIT : il n'y a pas de tenues sur VANTA. Aucun emplacement
--   vêtement n'est proposé à la création, et l'apparence corporelle est
--   forcée à l'identique pour tout le monde. Cohérent avec l'univers survie
--   (on arrive dépouillé, l'équipement vient du loot) et surtout : ça
--   supprime d'un coup toute la classe de bugs de couplage vestimentaire.
--
--   POURQUOI CE FICHIER EXISTE PLUTÔT QUE DES CONSTANTES ÉPARPILLÉES
--   Sur un ped freemode, le haut du corps est un triplet indissociable :
--     3  = torse / bras (mesh des manches)
--     8  = sous-vêtement
--     11 = vêtement extérieur
--   Les poser séparément est la cause des bras invisibles et des trous.
--   Ils sont donc appliqués ici, ensemble, et nulle part ailleurs.
-- =============================================

VantaBody = {}

-- ── Composants ───────────────────────────────────────────────────────────
VantaBody.COMP_MASK  = 1
VantaBody.COMP_TORSO = 3
VantaBody.COMP_LEGS  = 4
VantaBody.COMP_FEET  = 6
VantaBody.COMP_NECK  = 7
VantaBody.COMP_UNDER = 8
VantaBody.COMP_ARMOR = 9
VantaBody.COMP_TOP   = 11

-- Composant 9 = gilet pare-balles. Sur un ped freemode le drawable 0 est un
-- VRAI gilet visible, pas « aucun » — et SetPedDefaultComponentVariation pose
-- justement le 0. Sans ce nettoyage, tout le monde porte un kevlar.
VantaBody.ARMOR_NONE = -1

-- ── Tenue de base, par genre ─────────────────────────────────────────────
-- Index vérifiés sur le jeu de données de noms de vêtements GTA V
-- (root-cause/v-clothingnames) : une entrée sans libellé, à teinte unique,
-- et sans torse associé dans besttorso, correspond à « aucun vêtement ».
--
-- ⚠️ Une seule valeur n'a PAS pu être vérifiée dans les données : `torso`
-- (composant 3, bras nus), qu'aucune table ne nomme. 15 est la valeur de
-- convention pour les peds freemode. Si les bras s'affichaient mal, c'est
-- ce nombre-là qu'il faut ajuster, et lui seul.
VantaBody.UNDERWEAR = {
    male = {
        torso = 15, torsoTex = 0,   -- bras nus (non vérifiable dans les données)
        under = 15, underTex = 0,   -- aucun sous-vêtement (sans nom, 1 teinte)
        top   = 15, topTex   = 0,   -- aucun haut (sans nom, 1 teinte, besttorso -1)
        legs  = 61, legsTex  = 0,   -- « White Boxer Shorts »
        feet  = 33, feetTex  = 0,   -- pieds nus
    },
    female = {
        torso = 15, torsoTex = 0,   -- bras nus (non vérifiable dans les données)
        under = 15, underTex = 0,   -- masqué par le haut ci-dessous
        -- Contrairement au modèle masculin, le modèle féminin n'a pas d'entrée
        -- « aucun haut » exploitable : la signature qui marche chez l'homme
        -- (sans nom, 1 teinte, sans torse associé) attrape des uniformes chez
        -- la femme — le 48 rendait une chemise de police. On passe donc par un
        -- vêtement NOMMÉ, dont on sait ce qu'il affiche.
        -- Alternatives si le rendu ne convient pas : 17 « White Bikini »,
        -- 13 « Black Bustier ».
        top   = 15, topTex   = 0,   -- « Black Bikini »
        legs  = 19, legsTex  = 0,   -- « White Lace Panties »
        feet  = 34, feetTex  = 0,   -- pieds nus
    },
}

function VantaBody.get(gender)
    return VantaBody.UNDERWEAR[(gender == 'female') and 'female' or 'male']
end

-- Applique l'état corporel complet. Appelé après SetPedHeadBlendData et après
-- tout SetPedDefaultComponentVariation, qui rhabille le ped de zéro.
function VantaBody.apply(ped, gender)
    local b = VantaBody.get(gender)
    SetPedComponentVariation(ped, VantaBody.COMP_TORSO, b.torso, b.torsoTex, 0)
    SetPedComponentVariation(ped, VantaBody.COMP_UNDER, b.under, b.underTex, 0)
    SetPedComponentVariation(ped, VantaBody.COMP_TOP,   b.top,   b.topTex,   0)
    SetPedComponentVariation(ped, VantaBody.COMP_LEGS,  b.legs,  b.legsTex,  0)
    SetPedComponentVariation(ped, VantaBody.COMP_FEET,  b.feet,  b.feetTex,  0)
    -- Masque et accessoire de cou : 0 = aucun sur les peds freemode.
    SetPedComponentVariation(ped, VantaBody.COMP_MASK, 0, 0, 0)
    SetPedComponentVariation(ped, VantaBody.COMP_NECK, 0, 0, 0)
    SetPedComponentVariation(ped, VantaBody.COMP_ARMOR, VantaBody.ARMOR_NONE, 0, 0)
end
