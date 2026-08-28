# data/besttorso.json — provenance

Table de correspondance **haut (composant 11) → torse/bras (composant 3)** pour les peds
freemode. Utilisée uniquement par l'outil de dev `/topbuilder` (chargée à la demande via
`LoadResourceFile`, jamais envoyée au client en jeu normal).

## Source

Dérivée de **[root-cause/v-besttorso](https://github.com/root-cause/v-besttorso)**
(`besttorso_male.json` / `besttorso_female.json`), récupérée le 2026-08-28.

⚠️ **Ce dépôt ne porte aucune licence** — pas de fichier LICENSE, pas de mention d'usage
dans le README. Juridiquement, « pas de licence » signifie tous droits réservés. En
pratique c'est un jeu de données de correspondance largement réutilisé dans l'écosystème
FiveM, mais si VANTA passe en public/commercial, mieux vaut soit recréer la table avec le
mode récolte du builder (touche `R`), soit demander l'autorisation à l'auteur.

## Transformation appliquée

Les fichiers d'origine donnent le torse par couple *(haut, teinte du haut)* — 5 017 entrées
côté masculin, 5 547 côté féminin. Le format de tenue de VANTA fige **un seul torse par
tenue**, alors que le joueur peut changer la teinte du haut dans la création. On a donc
retenu, pour chaque haut, le **torse majoritaire sur toutes ses teintes**, avec son taux de
couverture :

```
{ "male": [ [haut, torse, teinteTorse, couverture%], ... ], "female": [ ... ] }
```

- masculin : 558 hauts retenus, dont 535 valides sur 100 % de leurs teintes
- féminin : 602 hauts retenus, dont 569 valides sur 100 % de leurs teintes
- les hauts sans aucun torse valide (`-1` partout) sont écartés à la conversion

Le builder affiche ce taux de couverture : en dessous de 100 %, certaines teintes du haut
peuvent mal s'accorder avec le torse figé — à vérifier à l'œil avec `G`, ou à écarter.

## Ce que la table ne couvre PAS

- **Le sous-vêtement (composant 8)** — hors périmètre du jeu de données d'origine. C'est lui
  qui produit les trous et les mélanges veste/t-shirt sur les hauts ouverts. Le builder
  part du sous-vêtement de la tenue par défaut du jeu et se corrige à l'œil (`A`/`E`).
- **Les gants** (variantes du composant 3), non pertinent ici.
- **Les vêtements addon / DLC plus récents** que le jeu de données. Pour ceux-là, la touche
  `R` du builder récolte des tenues cohérentes directement auprès du jeu via
  `SetPedRandomComponentVariation`.
