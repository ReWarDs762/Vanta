# VANTA XP — Notes de développement

## Tableau XP par niveaux (formule : 100 * level^1.5)

| Niveau | XP Cumulé Requis | XP pour ce niveau |
|--------|-----------------|-------------------|
| 1      | 0               | -                 |
| 2      | 282             | 282               |
| 5      | 1 118           | ~230              |
| 10     | 3 162           | ~280              |
| 20     | 8 944           | ~400              |
| 30     | 16 431          | ~490              |
| 40     | 25 298          | ~570              |
| 50     | 35 355          | ~640              |
| 60     | 46 475          | ~710              |
| 70     | 58 565          | ~770              |
| 80     | 71 554          | ~830              |
| 90     | 85 381          | ~890              |
| 100    | 100 000         | ~940              |

## Temps estimés (approx.)

| Source           | XP/action | Actions pour LVL 100 (100k XP) |
|------------------|-----------|---------------------------------|
| Kill Joueur      | +300      | ~334 kills                      |
| Kill Zombie      | +50       | ~2 000 kills                    |
| Mix PVP+Zombies  | —         | ~200 PVP + ~800 zombies         |

## Prestige — Bonus cumulatifs

| Prestige | Sac (base 50kg) | Conteneur (base 20kg) | Badge         |
|----------|----------------|-----------------------|---------------|
| P0       | 50 kg          | 20 kg                 | RECRUIT (gris)|
| P1       | 56 kg (+6)     | 24 kg (+4)            | ◆ I (argent)  |
| P2       | 62 kg (+12)    | 28 kg (+8)            | ◆◆ II (gold)  |
| P3       | 68 kg (+18)    | 32 kg (+12)           | ✦✦✦ III (gold+)|
| P4       | 74 kg (+24)    | 36 kg (+16)           | ⬡ IV (orange) |
| P5       | 80 kg (+30)    | 40 kg (+20)           | ⬟ VANTA (prem)|

## Exports disponibles

### Depuis `vanta_xp` (ce que cette resource expose)

```lua
exports['vanta_xp']:addXP(identifier, amount, source)
exports['vanta_xp']:getProfile(identifier)      -- retourne table complète
exports['vanta_xp']:getBagBonus(identifier)      -- retourne bonus kg sac
exports['vanta_xp']:getContainerBonus(identifier)-- retourne bonus kg conteneur
```

### Depuis `pvp_inventory` (ajoutés par ce patch)

```lua
exports['pvp_inventory']:setBagBonus(identifier, bonus_kg)
exports['pvp_inventory']:setContainerBonus(identifier, bonus_kg, source)
exports['pvp_inventory']:getPlayerBagCapacity(identifier)
exports['pvp_inventory']:getPlayerContainerCapacity(identifier)
```

`setContainerBonus` prend un 3ᵉ paramètre `source` (24/08/2026) : le bonus conteneur a
plusieurs sources indépendantes qui doivent s'additionner sans s'écraser — `'prestige'`
(ce patch, vanta_xp), `'subscription'` (pvp_vcoins), `'crew'` (pvp_crew, boutique). Toujours
passer une valeur `source` explicite lors d'un nouvel appel.

## Events écoutés (hooks)

| Event                         | Source           | Action vanta_xp          |
|-------------------------------|------------------|--------------------------|
| `pvp_killfeed:playerKilled`   | pvp_killfeed     | +300 XP au killer        |
| `pvp_zombies:onKill`          | pvp_zombies      | +50 XP au joueur         |
| `esx:playerLoaded`            | es_extended      | Charge profil + bonus    |

## Commandes

| Commande                       | Rôle       | Description                    |
|--------------------------------|------------|--------------------------------|
| `/xp`                          | Joueur     | Toggle NUI profil XP           |
| `/prestige`                    | Joueur     | Passer au prestige (si LVL100) |
| `/givexp [id] [amount]`        | Admin      | Donner de l'XP                 |
| `/setlevel [id] [level]`       | Admin      | Définir le niveau              |
| `/setprestige [id] [prestige]` | Admin      | Définir le prestige            |

## Ligne server.cfg

```
ensure vanta_xp
```

Doit être placé **après** `pvp_inventory` et **après** `pvp_killfeed` / `pvp_zombies`.

## Tests manuels

1. **XP Zombie** : tuer un zombie → vérifier toast +50 XP
2. **XP PVP** : tuer un joueur → vérifier toast +300 XP
3. **Level Up** : `/givexp [id] 500` → vérifier toast "LEVEL UP"
4. **NUI** : taper `/xp` → vérifier ouverture panel, données correctes
5. **Fermeture** : Echap ou clic extérieur → panel se ferme
6. **Prestige** : `/setlevel [id] 100` → `/prestige` → vérifier reset LVL 1, prestige +1, badge mis à jour
7. **Bonus capacité** : après prestige, vérifier que le sac accepte plus de poids
8. **Sauvegarde** : kill serveur + restart → vérifier que les données persistent
9. **Admin** : `/setprestige [id] 5` → vérifier badge P5 VANTA avec animation

## TODO / Améliorations futures

- [ ] Ajouter des sources XP supplémentaires (missions, captures d'outpost, etc.)
- [ ] Système de récompenses par niveau (items, skins, etc.)
- [ ] Leaderboard XP intégré au killfeed
- [ ] Sons custom pour level up et prestige
- [ ] Intégration Discord webhook pour les prestiges
