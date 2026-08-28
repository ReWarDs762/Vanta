-- =============================================
--   PVP CHARACTER — topbuilder.lua (serveur)
--   Ouverture de l'outil de dev + écriture de shared/tops_data.lua.
--   Réservé admin/superadmin : la commande est enregistrée côté SERVEUR
--   pour que le contrôle de groupe ne dépende jamais du client.
-- =============================================

local TB_ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) TB_ESX = obj end)

local function isBuilderAdmin(src)
    if src == 0 then return true end  -- console
    if not TB_ESX then return false end
    local xPlayer = TB_ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    local group = xPlayer.getGroup()
    return group == 'admin' or group == 'superadmin'
end

-- ── Sérialisation de la table ────────────────────────────────────────────
-- Parenthèses obligatoires : gsub renvoie (chaîne, nbRemplacements), et le
-- compteur partirait en argument surnuméraire de string.format.
local function escapeLabel(s)
    return (tostring(s or 'TENUE'):gsub('\\', '\\\\'):gsub("'", "\\'"):gsub('[\r\n]', ' '))
end

local function serializeList(list)
    local out = {}
    for _, e in ipairs(list or {}) do
        out[#out + 1] = string.format(
            "        { top = %d, topTex = %d, torso = %d, torsoTex = %d, under = %d, underTex = %d, label = '%s' },",
            math.floor(tonumber(e.top) or 0),
            math.floor(tonumber(e.topTex) or 0),
            math.floor(tonumber(e.torso) or 0),
            math.floor(tonumber(e.torsoTex) or 0),
            math.floor(tonumber(e.under) or 0),
            math.floor(tonumber(e.underTex) or 0),
            escapeLabel(e.label)
        )
    end
    return table.concat(out, '\n')
end

local HEADER = [[
-- =============================================
--   PVP CHARACTER — tops_data.lua
--   TABLE DE TENUES (composant 11 + 3 + 8) — FICHIER GÉNÉRÉ
--
--   ⚠️ Ce fichier est réécrit intégralement par la commande admin
--   /topbuilder (touche ENTRÉE = sauvegarder). Le champ `label` est fait
--   pour être renommé à la main, il est conservé d'une génération à l'autre.
--
--   POURQUOI CE FICHIER EXISTE
--   Sur un ped freemode, un « haut » n'est pas un composant mais trois :
--     3  = torse / bras (décide du mesh des manches)
--     8  = sous-vêtement (visible sous une veste ouverte)
--     11 = vêtement extérieur
--   Rockstar range la correspondance entre les trois dans les .meta DLC,
--   qu'aucune native n'expose. Faire défiler le 11 seul produit donc des
--   bras invisibles, des trous et des mélanges veste/t-shirt. On travaille
--   par combinaisons validées, jamais par drawable brut.
--
--   ⚠️ NE JAMAIS RÉORDONNER NI SUPPRIMER une entrée existante : l'index de
--   la tenue est ce qui est persisté dans `appearance_json`. Retirer la
--   3ᵉ entrée change la tenue de tous les joueurs qui l'avaient. On ajoute
--   uniquement en fin de liste.
-- =============================================

VantaTopsData = {
]]

local function writeFile(male, female)
    local body = HEADER
        .. '    male = {\n'   .. serializeList(male)   .. '\n    },\n'
        .. '    female = {\n' .. serializeList(female) .. '\n    },\n'
        .. '}\n'
    return SaveResourceFile(GetCurrentResourceName(), 'shared/tops_data.lua', body, -1)
end

-- ── Commande ─────────────────────────────────────────────────────────────
RegisterCommand('topbuilder', function(src, args)
    if not isBuilderAdmin(src) then
        if src > 0 then TriggerClientEvent('esx:showNotification', src, '~r~Permission refusée.') end
        return
    end
    if src == 0 then
        print('[pvp_character] /topbuilder doit être lancé en jeu (il pilote le ped du joueur).')
        return
    end
    local gender = (args and args[1] == 'female') and 'female' or 'male'
    TriggerClientEvent('pvp_character:topbuilder:open', src, gender)
end, false)

-- ── Sauvegarde ───────────────────────────────────────────────────────────
RegisterNetEvent('pvp_character:topbuilder:save')
AddEventHandler('pvp_character:topbuilder:save', function(gender, list)
    local src = source
    -- Re-contrôle : l'event est net, un client non-admin pourrait le déclencher.
    if not isBuilderAdmin(src) then return end
    if type(list) ~= 'table' or #list > 200 then return end

    gender = (gender == 'female') and 'female' or 'male'

    VantaTopsData = VantaTopsData or { male = {}, female = {} }
    local clean = {}
    for _, e in ipairs(list) do
        if type(e) == 'table' then
            clean[#clean + 1] = {
                top      = math.floor(tonumber(e.top) or 0),
                topTex   = math.floor(tonumber(e.topTex) or 0),
                torso    = math.floor(tonumber(e.torso) or 0),
                torsoTex = math.floor(tonumber(e.torsoTex) or 0),
                under    = math.floor(tonumber(e.under) or 0),
                underTex = math.floor(tonumber(e.underTex) or 0),
                label    = tostring(e.label or 'TENUE'):sub(1, 40),
            }
        end
    end
    VantaTopsData[gender] = clean

    local ok = writeFile(VantaTopsData.male or {}, VantaTopsData.female or {})
    local msg = ok
        and ('Table de tenues écrite (' .. #clean .. ' entrées, ' .. gender .. '). Fais "restart pvp_character" pour la charger.')
        or  'Échec de l\'écriture de shared/tops_data.lua (droits en écriture ?).'
    print('[pvp_character][topbuilder] ' .. msg)
    TriggerClientEvent('esx:showNotification', src, (ok and '~g~' or '~r~') .. msg)
end)
