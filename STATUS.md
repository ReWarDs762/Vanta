# VANTA — Statut du projet

Ce fichier contient tout ce qui change souvent : avancement par resource, bugs actifs,
roadmap, ce qui a été validé en jeu. À tenir à jour à chaque session — bien plus vite que
`CLAUDE.md`, qui ne décrit que l'architecture stable.

**Dernière mise à jour :** 24 août 2026 (audit du système PVP + corrections de sécurité/gameplay, nouvelle resource `pvp_combat` ; `pvp_crew` — contrat quotidien de crew, trésorerie/monnaie collective, boutique de bonus temporaires, historique + fix bonus conteneur multi-sources ; audit + correctifs `pvp_drops`, système de notifications générique `vanta_ui`)

---

## Statut par resource

| Resource | Statut | Détail |
|---|---|---|
| `pvp_combat` | **Nouveau (23/08/2026), jamais testé** | Mode combat / anti combat-log : voir CLAUDE.md → « Mode combat (pvp_combat) ». Dépend de `pvp_outposts` (déclenche le mode combat) et `pvp_inventory` (délègue la mort par combat-log). À tester en priorité : déconnexion en plein fight (le stuff doit tomber), blocage du dépôt au coffre protégé en combat, expiration du mode combat 5s après le dernier coup. |
| `pvp_character` | Refondu (22/08/2026), **non testé en jeu** | Écran de création revu en profondeur : cadrage caméra corrigé (le perso était mal visible derrière le panel), personnalisation étendue (peau, morphologie, cheveux, 10 emplacements vêtements + 5 accessoires en freemode, ou choix d'un ped spécial du catalogue `pvp_inventory`). Fix du bug de timing qui empêchait l'écran de s'afficher (`Wait(400)` fixe → retry loop). Voir CLAUDE.md pour le détail. À valider intégralement en jeu avant de considérer ce chantier terminé. |
| `pvp_drops` | Audité + corrigé (24/08/2026), **non testé en jeu** | Audit complet : 3 bugs de fiabilité corrigés (failover du contrôleur, expiration du drop, dépendances implicites), notifications migrées vers `vanta_ui`, fusées éclairantes (son + particules) à l'atterrissage, trajectoire en flèches rouges clignotantes. Reste : validation manette en main. |
| `vanta_ui` | Étendu (24/08/2026), **non testé en jeu** | Ajout d'un système de notifications générique (`ui_page` + exports `notify`/`notifyAll`). Seul `pvp_drops` l'utilise pour l'instant — les autres resources passent toujours par `pvp_market:notify` (voir Écarts). |
| `pvp_redzones` | Fonctionnel, détails manquants | À polish : visuels carte/minimap, notifications de rotation, timer visible — à définir |
| `pvp_killfeed` | Créé, **jamais testé** | Voir « Testé en jeu » ci-dessous. Annonces chat de série de kills retirées (23/08/2026, trop bruyantes à plusieurs joueurs) — le killfeed NUI et les leaders de session restent inchangés. |
| `pvp_crew` | Fonctionnel, à approfondir | Ajouté (24/08/2026), **non testé en jeu** : contrat quotidien de crew (élimination de zombies, quota adaptatif au nombre de participants actifs), trésorerie/monnaie collective (réutilise `pvp_crews.bank`, jamais retirable en argent personnel), historique des gains/dépenses, boutique de 3 bonus temporaires (XP zombies x2, XP PvP +50%, bonus de coffre protégé personnel pour tout le crew). Le blocage de dégâts entre membres de SQUAD (pas crew) est maintenant réel côté serveur (23/08/2026, voir `pvp_outposts/server/server.lua`) — l'ancien code client ne faisait rien. Vision long terme restante : hiérarchie (leader + membres), coffre partagé crew, système d'affrontement entre crews (à brainstormer) |
| `pvp_market` | Opérationnel, design à retravailler | À faire : refonte visuelle pour plus de lisibilité et de présence |
| `vanta_loading` | Désactivé temporairement | Raison non documentée — écran de chargement prêt mais `# ensure vanta_loading` dans `server.cfg` |
| `pvp_hud` | ✅ Réactivé (21/08/2026) | Restrictions de combat + nettoyage du monde ambiant confirmés voulus. Bug serveur trouvé et corrigé (voir Bugs corrigés). Dégâts de chute désactivés (23/08/2026). Le nettoyage périodique protège maintenant les zombies (voir `pvp_zombies`). |
| `pvp_zombies` | Fonctionnel côté code, **jamais testé** | Fix (23/08/2026) : les zombies étaient supprimés par le nettoyage périodique de `pvp_hud` toutes les 5s (pas marqués mission entity) — probablement jamais remarqué faute de test en jeu. |
| `pvp_outposts` | Stable | Protection zone safe étendue aux explosions (23/08/2026) — seul `weaponDamageEvent` était filtré auparavant, un RPG/lance-grenades tuait normalement en zone safe. |
| `spooner` | ⚠️ Faille corrigée (23/08/2026) | `permissions.cfg` donnait tout l'arbre `spooner.*` à `builtin.everyone` (spawn/modify/delete d'entités, y compris celles des autres joueurs) — restreint à `group.admin`. À vérifier : les comptes qui doivent avoir accès à spooner sont bien dans `group.admin` (voir `add_principal` dans `server.cfg`). |
| `esx_identity` | ❌ Supprimé (21/08/2026) | Remplacé par `pvp_character`, dossier retiré du disque |

Tout ce qui n'apparaît pas dans ce tableau est considéré stable — voir `CLAUDE.md` pour son
architecture.

---

## Bugs actifs connus

### `/givexp` — collision de commande, non corrigé

`vanta_xp/server.lua` et `pvp_admin/server/server.lua` déclarent chacun une commande
`/givexp`. FiveM ne garde que la dernière enregistrée sous un nom donné — `pvp_admin`
étant `ensure`d après `vanta_xp` dans `server.cfg`, **c'est la sienne qui gagne
aujourd'hui**. Elle écrit dans la colonne morte `pvp_player_stats.xp` au lieu d'appeler
l'export `addXP()` de `vanta_xp` (la vraie table de progression).

**Conséquence :** `/givexp` ne fait rien d'observable pour le joueur.

**Non corrigé** — nécessite une décision : garder la version de `vanta_xp` (supprimer
celle de `pvp_admin`), ou faire relayer `pvp_admin` vers l'export `addXP` de `vanta_xp`.

---

## Bugs corrigés

### `pvp_inventory` — bonus de coffre protégé écrasé entre sources (corrigé 24/08/2026)

`exports('setContainerBonus', ...)` stockait un unique bonus par identifiant
(`playerContainerBonus[identifier] = bonus`). `vanta_xp` (bonus de prestige) et
`pvp_vcoins` (bonus d'abonnement Gold/Diamond) l'appelaient tous les deux — le dernier à
écrire écrasait silencieusement le bonus de l'autre (ex : à la reconnexion, l'ordre entre
les deux handlers `esx:playerLoaded` décide qui « gagne », perte silencieuse du bonus
prestige ou abonnement selon l'ordre de démarrage des resources). Découvert en implémentant
la boutique de crew, qui ajoutait une **troisième** source concurrente au même point de
collision. Corrigé : le bonus est maintenant stocké par source (`prestige` / `subscription`
/ `crew`) et sommé à la lecture — les 3 sources peuvent être actives en même temps sans
s'écraser.

### `pvp_character` — écran de création jamais affiché (corrigé 22/08/2026)

`client/client.lua` attendait un délai fixe (`Citizen.Wait(400)`) après `playerSpawned`
avant de vérifier si le joueur était nouveau, sans aucun retry. Le round-trip serveur
(`esx:playerLoaded` → requête MySQL → event client `pvp_character:isNewPlayer`) pouvait
dépasser cette fenêtre, et rien ne relisait le flag ensuite. Corrigé : boucle de retry
(jusqu'à 15s) au lieu d'un délai figé.

### `pvp_inventory` — changement de ped non vérifié côté serveur (corrigé 22/08/2026)

Le sélecteur de ped (onglet Profil) filtrait les peds Gold/Diamond uniquement côté JS
(`getPedAccess`) — le serveur (`pvp_inventory:savePedModel`) ne vérifiait que le format
du nom de modèle, jamais l'abonnement. Un client modifié pouvait donc changer vers
n'importe quel ped du catalogue sans abonnement. Corrigé : vérification serveur de
l'abonnement (`exports['pvp_vcoins']:GetTier`) + du tier du ped demandé, avant tout
`UPDATE`. Découvert et corrigé dans le cadre de la refonte de `pvp_character`, qui
introduit une nouvelle règle produit (changement de ped bloqué sans Gold/Diamond) que ce
trou aurait rendu inefficace.

### `pvp_hud` — native serveur cassé (corrigé 21/08/2026)

`pvp_hud/server/server.lua` appelait `SetMaxWantedLevel(0)`, un native **client
uniquement** dans FiveM. Plantait au démarrage, à chaque connexion joueur, et toutes les
30 secondes en boucle infinie — probable cause du « HUD buggé » qui avait mené à sa
désactivation. Corrigé : les 3 appels cassés retirés (redondants avec le client, qui gère
déjà le wanted level à chaque frame).

### Audit du système PVP (23/08/2026) — corrections de sécurité et gameplay

Suite à un audit complet du pipeline PVP (voir historique de conversation), plusieurs
corrections appliquées d'un coup :

- **`spooner` ouvert à tout le monde** : `permissions.cfg` donnait tout l'arbre
  `spooner.*` à `builtin.everyone` — n'importe quel joueur connecté pouvait spawn/modifier/
  supprimer des entités, y compris celles des autres joueurs. Restreint à `group.admin`.
- **Zombies supprimés par le nettoyage de `pvp_hud`** : créés sans être marqués mission
  entity (`CreatePed(..., false, false)`), donc traités comme ambiants et supprimés dans la
  boucle de nettoyage périodique de `pvp_hud` (toutes les 5s). Corrigé (`..., false, true)`).
- **Kills longue distance rejetés à tort** : le sanity-check anti-triche de `pvp_killfeed`
  invalidait tout kill au-delà de 300m — en deçà de la portée réelle d'un sniper/AWP.
  Seuil remonté à 2000m.
- **Death bags visibles sur toute la map** : la position de chaque sac de loot était
  broadcastée à TOUS les clients à la création et à la connexion. Maintenant persistés en
  BDD (`pvp_death_bags`, survivent à un restart) et notifiés uniquement aux joueurs à moins
  de 150m — un client ne peut plus cartographier tous les sacs du serveur.
- **Explosions ignoraient la zone safe** : seul `weaponDamageEvent` était filtré, un
  RPG/lance-grenades tuait normalement en zone safe. `explosionEvent` annule maintenant
  toute explosion se déclenchant à portée de souffle (+15m) d'une zone safe.
- **Dégâts de chute désactivés** (demande produit) : `pvp_hud` restaure la vie perdue
  pendant une chute (snapshot avant/après via `IS_PED_FALLING`, pas de natif dédié).
- **Friendly fire crew inopérant** : `ClearEntityLastDamageEntity` côté client
  n'annulait aucun dégât, juste l'attribution — les membres de squad se blessaient
  normalement. Vrai blocage ajouté côté serveur (`pvp_outposts`, via l'export
  `pvp_crew:areInSameSquad`). Confirmé voulu : le CREW entier peut se tuer entre membres,
  seule la SQUAD (sous-groupe volontaire) est protégée.
- **Annonces chat de série de kills retirées** : jugées trop bruyantes à plusieurs
  joueurs. Le double comptage de série (`pvp_killfeed` + `pvp_inventory`) est résolu par la
  même occasion — seul le suivi de `pvp_inventory` (kill_streak_record + badges) subsiste,
  c'était le seul des deux à avoir un effet fonctionnel.
- **Code mort supprimé** : `pvp_inventory:addKill`, `addDeath`, `addZombieKill`,
  `addZombieKillBySource` n'avaient plus aucun appelant depuis l'unification du pipeline
  PVP via `pvp_killfeed` / `recordZombieKill`.
- **Doc `pvp_drops`** : `CLAUDE.md` disait 3 min avant ouverture de la caisse, le code
  dit 5 min (`Config.OpenDelay`) — doc corrigée.
- **Nouvelle resource `pvp_combat`** : mode combat / anti combat-log. Voir CLAUDE.md et la
  ligne dédiée dans le tableau ci-dessus.

---

## Testé en jeu vs jamais testé

Un démarrage de serveur prouve que le code se charge, pas qu'il fonctionne. Rien de ce qui
suit n'a été validé manette en main :

- [ ] `pvp_character` — refondu le 22/08/2026 (apparence détaillée, catalogue de peds,
      caméra recadrée), **jamais revalidé en jeu depuis** — à tester en priorité :
      parcours freemode complet, choix d'un ped spécial, `/rename`, et sur `pvp_inventory`
      la restriction "changement de ped réservé Gold/Diamond" (bouton verrouillé + rejet
      serveur si forcé sans abonnement)
- [ ] `pvp_inventory` — le plus gros système (217 fichiers), jamais testé
- [ ] `pvp_combat` — nouveau (23/08/2026), jamais testé : déconnexion en combat (drop du
      stuff), blocage dépôt coffre protégé en combat, expiration 5s après le dernier coup
- [ ] `pvp_killfeed` — créé, jamais testé
- [ ] `pvp_crew` — 4 crews en base mais 0 membre, jamais réellement exercé. En particulier
      le contrat quotidien (24/08/2026) : progression multi-participants, complétion +
      crédit de trésorerie, boutique (achat, anti-cumul, expiration, application/retrait
      du bonus de coffre à la connexion/déconnexion/exclusion), et non-régression du
      bonus de coffre prestige/abonnement (fix multi-sources ci-dessus)
- [ ] `pvp_drops` — avion, parachute, ouverture de caisse : jamais validés. Depuis les
      correctifs du 24/08/2026, à tester en plus : la déconnexion du contrôleur en plein
      vol (l'avion doit continuer sa trajectoire chez les autres joueurs), l'expiration
      d'un drop non récupéré (`Config.DropLifetime`, 1h), les fusées éclairantes
      (`prop_flare_01` + son `Flare`/`FBI_05_SOUNDS`), et les flèches rouges clignotantes
      de trajectoire sur la minimap
- [ ] `vanta_ui` — système de notifications générique : jamais affiché en jeu
- [ ] `pvp_redzones` — rotation horaire, loot ×2 : jamais validés
- [ ] `pvp_zombies` — spawn, IA, loot pondéré : jamais validés
- [ ] `pvp_hud` — restrictions de combat réactivées, jamais vues en jeu

Session de test suggérée : création de personnage → apparition → inventaire → tuer un
zombie → loot → coffre → marché → crew → mort → réapparition.

---

## Écarts de documentation connus, non résolus

### Listes armes/véhicules sans source unique

En vérifiant les pointeurs à ajouter dans `CLAUDE.md`, découvert que les listes d'armes et
de véhicules ne correspondent à **aucune source unique** dans le code :

- **Armes** : `pvp_outposts/config.lua` (`Config.WeaponShopItems`, l'armurerie) a sa
  propre liste ; `pvp_inventory/server/server.lua` (table `WEAPONS`) a une liste de
  validation anti-triche différente et plus large (variantes MK2, molotov, stungun...
  absents de la doc actuelle).
- **Véhicules** : `pvp_zombies/config.lua` a une table de loot pondérée bien plus fournie
  (dizaines d'entrées, ex. `vehicle_ztype`, `vehicle_mule`, `vehicle_blazer5`) que ce qui
  était documenté dans `CLAUDE.md`.

**Non résolu.** Un audit complet des tables de loot serait nécessaire pour produire une
doc fiable — hors périmètre de la session actuelle.

### `pvp_market:notify` — migration partielle vers `vanta_ui`

L'event `pvp_market:notify` est un faux ami : il est **nommé** d'après `pvp_market` mais
**déclaré** dans `pvp_inventory/client/client.lua`, et utilisé par `pvp_drops`,
`pvp_zombies` et `pvp_market`. N'importe quel renommage ou retrait de l'une de ces deux
resources casse les notifications des autres, sans lien apparent.

Un système générique existe désormais dans `vanta_ui` :

```lua
exports['vanta_ui']:notify(src, 'Message', 'success')  -- serveur
exports['vanta_ui']:notify('Message', 'success')       -- client
exports['vanta_ui']:notifyAll('Message', 'info')       -- serveur, tous les joueurs
```

Types : `success` | `error` | `warning` | `info` (les booléens `true`/`false` de l'ancien
format restent acceptés).

**Migré :** `pvp_drops` uniquement. **Reste à migrer :** `pvp_market`, `pvp_zombies`, et
l'ancien handler dans `pvp_inventory`. Tant que la migration n'est pas terminée, les deux
systèmes coexistent (deux styles de toast possibles à l'écran).

### `pvp_drops` — loot annoncé « légendaire », majoritairement épic

`Config.LootTable` pondère ~86 % d'épic pour ~14 % de légendaire. Les libellés en jeu ont
été neutralisés le 24/08/2026 (« DROP DE RAVITAILLEMENT », plus de mention de rareté),
mais **la table de loot elle-même n'a pas été rééquilibrée** — à trancher : soit augmenter
la part de légendaire, soit assumer le ratio actuel.

---

## Roadmap

### Priorité actuelle : rendre toutes les features existantes fonctionnelles et cohérentes avant d'en ajouter de nouvelles.

- [x] Phase 1 — Base solide (server.cfg, ESX config PVP)
- [x] Phase 2 — Zombies (spawn, IA, loot pondéré)
- [x] Phase 2.5 — Inventaire NUI complet + armes + véhicules
- [x] Phase 3 — Avant-postes, garage, admin, profil, badges, XP/prestige
- [ ] **En cours — Polish & consolidation** :
  - [x] pvp_drops : correctifs de fiabilité + sons/flares + trajectoire clignotante (24/08/2026, à tester)
  - [ ] pvp_drops : rééquilibrer la table de loot (voir Écarts) et tester en jeu
  - [ ] Migrer `pvp_market`, `pvp_zombies` et `pvp_inventory` vers `exports['vanta_ui']:notify`
  - [ ] pvp_redzones : polish visuel, notifications rotation, timer
  - [ ] pvp_killfeed : tester et finaliser
  - [ ] pvp_crew : tester, corriger, brainstormer la vision long terme
  - [ ] pvp_market : refonte design (plus lisible/visible)
  - [ ] `/givexp` : trancher la collision de commande (voir Bugs actifs)
- [x] Phase 4a — Crew : hiérarchie, coffre partagé, contrat quotidien, trésorerie/monnaie
      collective, boutique de bonus temporaires, historique (24/08/2026, non testé en jeu)
- [ ] Phase 4b — Crew : système d'affrontement entre crews (à brainstormer)
- [ ] Phase 5 — Mapping avant-postes (CodeWalker)
- [ ] Phase 6 — Lancement public
