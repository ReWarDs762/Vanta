# VANTA — Statut du projet

Ce fichier contient tout ce qui change souvent : avancement par resource, bugs actifs,
roadmap, ce qui a été validé en jeu. À tenir à jour à chaque session — bien plus vite que
`CLAUDE.md`, qui ne décrit que l'architecture stable.

**Dernière mise à jour :** 24 août 2026 (audit + correctifs `pvp_drops`, système de notifications générique `vanta_ui`)

---

## Statut par resource

| Resource | Statut | Détail |
|---|---|---|
| `pvp_character` | Refondu (22/08/2026), **non testé en jeu** | Écran de création revu en profondeur : cadrage caméra corrigé (le perso était mal visible derrière le panel), personnalisation étendue (peau, morphologie, cheveux, 10 emplacements vêtements + 5 accessoires en freemode, ou choix d'un ped spécial du catalogue `pvp_inventory`). Fix du bug de timing qui empêchait l'écran de s'afficher (`Wait(400)` fixe → retry loop). Voir CLAUDE.md pour le détail. À valider intégralement en jeu avant de considérer ce chantier terminé. |
| `pvp_drops` | Audité + corrigé (24/08/2026), **non testé en jeu** | Audit complet : 3 bugs de fiabilité corrigés (failover du contrôleur, expiration du drop, dépendances implicites), notifications migrées vers `vanta_ui`, fusées éclairantes (son + particules) à l'atterrissage, trajectoire en flèches rouges clignotantes. Reste : validation manette en main. |
| `vanta_ui` | Étendu (24/08/2026), **non testé en jeu** | Ajout d'un système de notifications générique (`ui_page` + exports `notify`/`notifyAll`). Seul `pvp_drops` l'utilise pour l'instant — les autres resources passent toujours par `pvp_market:notify` (voir Écarts). |
| `pvp_redzones` | Fonctionnel, détails manquants | À polish : visuels carte/minimap, notifications de rotation, timer visible — à définir |
| `pvp_killfeed` | Créé, **jamais testé** | Voir « Testé en jeu » ci-dessous |
| `pvp_crew` | Fonctionnel, à approfondir | Vision long terme : hiérarchie (leader + membres), coffre partagé crew, système d'affrontement entre crews (à brainstormer), stats de crew |
| `pvp_market` | Opérationnel, design à retravailler | À faire : refonte visuelle pour plus de lisibilité et de présence |
| `vanta_loading` | Désactivé temporairement | Raison non documentée — écran de chargement prêt mais `# ensure vanta_loading` dans `server.cfg` |
| `pvp_hud` | ✅ Réactivé (21/08/2026) | Restrictions de combat + nettoyage du monde ambiant confirmés voulus. Bug serveur trouvé et corrigé (voir Bugs corrigés) |
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
- [ ] `pvp_killfeed` — créé, jamais testé
- [ ] `pvp_crew` — 4 crews en base mais 0 membre, jamais réellement exercé
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
- [ ] Phase 4 — Crew system avancé (hiérarchie, coffre partagé, affrontements)
- [ ] Phase 5 — Mapping avant-postes (CodeWalker)
- [ ] Phase 6 — Lancement public
