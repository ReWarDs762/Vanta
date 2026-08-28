-- =============================================
--   PVP CHARACTER — tops_data.lua
--   TABLE DE TENUES (composant 11 + 3 + 8) — FICHIER GÉNÉRÉ
--
--   ⚠️ Ce fichier est réécrit intégralement par la commande admin
--   /topbuilder (touche ENTRÉE = sauvegarder). Toute modification manuelle
--   est conservée tant que l'outil n'est pas resauvegardé — le champ `label`
--   est justement fait pour être renommé à la main.
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
    -- { top = <comp 11>, topTex = <teinte par défaut>,
    --   torso = <comp 3>, torsoTex = <teinte>,
    --   under = <comp 8>, underTex = <teinte>,
    --   label = 'NOM AFFICHÉ' }
    male   = {},
    female = {},
}
