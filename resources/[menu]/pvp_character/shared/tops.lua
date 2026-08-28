-- =============================================
--   PVP CHARACTER — tops.lua
--   Accès à la table de tenues (shared client + serveur).
--   Les données vivent dans tops_data.lua (généré par /topbuilder),
--   cette couche n'expose que des accesseurs bornés.
--
--   Convention d'index : 0-based, comme les drawables GTA et comme le reste
--   du NUI (qui affiche `value + 1`). `get()` prend donc 0 pour la 1ʳᵉ tenue.
-- =============================================

VantaTops = {}

-- Composants pilotés ensemble par une tenue.
VantaTops.COMP_TOP   = 11  -- vêtement extérieur
VantaTops.COMP_TORSO = 3   -- torse / bras
VantaTops.COMP_UNDER = 8   -- sous-vêtement

-- Composant 9 = gilet pare-balles (« kevlar »).
-- ⚠️ Sur un ped freemode, SetPedDefaultComponentVariation pose le drawable 0
-- de ce composant, et le drawable 0 est un VRAI gilet visible, pas « aucun ».
-- Résultat sans traitement : tous les personnages portent un kevlar par-dessus
-- n'importe quelle tenue. Il n'est jamais exposé au joueur (aucune resource de
-- VANTA ne s'en sert), on le remet donc systématiquement à « aucun ».
VantaTops.COMP_ARMOR = 9
-- Index « aucun gilet ». -1 est la valeur de nettoyage documentée ; si un
-- gilet reste visible en jeu, la touche K du builder permet de parcourir les
-- drawables du composant 9 pour trouver le bon index et le poser ici.
VantaTops.ARMOR_NONE = -1

function VantaTops.clearArmor(ped)
    SetPedComponentVariation(ped, VantaTops.COMP_ARMOR, VantaTops.ARMOR_NONE, 0, 0)
end

local function listFor(gender)
    local data = VantaTopsData or {}
    return data[(gender == 'female') and 'female' or 'male'] or {}
end

VantaTops.list = listFor

function VantaTops.count(gender)
    return #listFor(gender)
end

-- Retourne la tenue à l'index 0-based, ou nil si la table est vide / l'index
-- hors bornes. L'appelant décide du repli (le client retombe sur la tenue par
-- défaut du jeu tant que la table n'a pas été générée).
function VantaTops.get(gender, idx)
    idx = tonumber(idx)
    if not idx then return nil end
    return listFor(gender)[math.floor(idx) + 1]
end

function VantaTops.clampIndex(gender, idx)
    local n = VantaTops.count(gender)
    if n <= 0 then return 0 end
    idx = math.floor(tonumber(idx) or 0)
    if idx < 0 then return 0 end
    if idx > n - 1 then return n - 1 end
    return idx
end

-- Migration v1 → v2 : les anciennes apparences ne stockaient que le drawable
-- brut du composant 11. On retrouve la tenue qui utilise ce haut, sinon 0.
function VantaTops.findByTop(gender, drawable11)
    drawable11 = tonumber(drawable11)
    if not drawable11 then return 0 end
    local list = listFor(gender)
    for i = 1, #list do
        if list[i].top == drawable11 then return i - 1 end
    end
    return 0
end
