# VANTA — Roadmap de sortie

> **But de ce fichier** : document de pilotage unique pour amener le serveur jusqu'à la
> sortie publique. Sert à savoir, à chaque session, *où on en est* et *quoi faire ensuite*.
>
> - **Architecture stable** → `CLAUDE.md`
> - **Bugs actifs, détails par resource, écarts de doc** → `STATUS.md`
> - **Quoi faire, dans quel ordre, et où on en est** → *ce fichier*
>
> Tenir à jour à la fin de chaque session : cocher les cases faites, remplir le
> **Journal de session** en bas.

**Dernière mise à jour :** 3 septembre 2026 (audit de cohérence : resynchronisation du tableau de bord avec l'état réel du code et de la session de test du 02/09)

---

## 1. Tableau de bord

| Phase | Objet | Bloque la sortie ? | Statut | Avancement |
|---|---|---|---|---|
| **A** | Stabilisation — tester l'existant, corriger le noyau | 🔴 Oui | 🟡 En cours | 4 / 5 |
| **B** | Cohérence technique — dette, sources uniques, notifs | 🔴 Oui | 🟡 En cours | 2 / 5 |
| **C** | Polish gameplay & visuel | 🟠 Partiel | ⬜ Pas commencé | 0 / 5 |
| **D** | Pré-production & mise en ligne | 🔴 Oui | ⬜ Pas commencé | 0 / 6 |
| **E** | Post-lancement (v1.1+) | 🟢 Non | ⬜ Backlog | 0 / 4 |

**Chemin critique le plus court vers une sortie :** A → B → D.
C et E peuvent se faire après une sortie en *early access*.

> **Correction du 03/09.** Ce tableau affichait « 0 / 5 · Pas commencé » sur A alors que
> A1, A3, A4 et A5 étaient cochés point par point plus bas depuis la session de test
> Cloudfive du 02/09. B est passé de 3 à 5 items et C de 4 à 5, l'audit ayant ajouté
> B4 (sécurité `pvp_zombies`), B5 (dette technique) et C5 (identité visuelle v2.1).
> Le seul item bloquant restant sur A est **A2** : rejouer le parcours pour vérifier que
> les 13 correctifs du 02/09 n'ont pas introduit de régression.

### Légende des statuts
- ⬜ Pas commencé · 🟡 En cours · ✅ Fait · ⏸️ Bloqué (préciser par quoi) · ❌ Abandonné

---

## 2. État de test des resources

Référence rapide (détail dans `STATUS.md` → « Testé en jeu vs jamais testé »).
« Testé » = exercé manette en main au moins une fois, pas « sans bug ».

| Resource | Code | Testée en jeu |
|---|---|---|
| `pvp_character` | ✅ | ✅ 02/09 (correctifs postérieurs non rejoués) |
| `pvp_inventory` | ✅ | ✅ 02/09 (3 correctifs postérieurs non rejoués) |
| `pvp_combat` | ✅ | ✅ 02/09 (A3 complet, 2 joueurs) |
| `pvp_hud` | ✅ | ✅ 02/09 (5 correctifs postérieurs non rejoués) |
| `pvp_zombies` | ✅ | ✅ 02/09 (3 correctifs postérieurs non rejoués) |
| `pvp_outposts` | ✅ stable | ✅ 02/09 |
| `pvp_garage` | ✅ | ✅ 02/09 |
| `pvp_spawn` | ✅ | ✅ 02/09 (correctif postérieur non rejoué) |
| `pvp_market` | ✅ | ✅ 02/09 |
| `vanta_ui` (notifs) | ✅ | ✅ 01-02/09 |
| `pvp_drops` | ✅ (revue 25/08) | ⬜ **jamais exercé** |
| `pvp_crew` | ✅ (features 24/08) | ⬜ **jamais exercé** (0 membre en base) |
| `pvp_redzones` | ✅ | ⬜ **jamais exercé** |
| `pvp_killfeed` | ✅ | ⬜ **jamais exercé** |
| `pvp_vcoins` | ✅ | ⬜ **jamais exercé** |
| `pvp_admin` | ✅ | ⬜ **jamais exercé** |
| `vanta_xp` | ✅ | ⬜ **jamais exercé** |

**Lecture :** le noyau de boucle de jeu (créer un perso → looter → se battre → mourir →
recommencer) a été traversé une fois. Tout ce qui est **périphérique et différé dans le
temps** — un drop qui met 10 min, un contrat de crew quotidien, une rotation de redzone
horaire, un abonnement de 30 jours — n'a jamais tourné. C'est là que se concentre le
risque restant.

---

## 3. PHASE A — Stabilisation *(bloquant sortie)*

> Statut : **4 / 5**. La session de test multijoueur Cloudfive du 02/09 a validé A1, A3 et
> A5 ; A4 avait été tranchée le 30/08. Il reste **A2**, et il est bloquant : les 13
> correctifs issus de cette session n'ont été rejoués par personne.

### A1 — Session de test complète du parcours joueur ✅ (02/09/2026)
- [x] Création de personnage (freemode complet)
- [x] Création de personnage (ped spécial du catalogue)
- [x] Apparition (`pvp_spawn` attend bien la fin de création)
- [x] Ouverture inventaire, hotbar, coffres (sac / protégé / avant-poste)
- [x] Tuer un zombie → loot au corps → item en inventaire
- [x] Achat / vente armurerie + customisation arme
- [x] Achat / vente / spawn véhicule (garage)
- [x] Marché joueur : créer une annonce, acheter
- [x] Mort → perte du sac → death bag au sol → respawn avant-poste le plus proche
- [x] Téléportation entre avant-postes (NPC pilote + waypoint)

**Résultat :** parcours traversé de bout en bout, 13 anomalies remontées (détail dans
`STATUS.md` → « Retours de la session de test multijoueur Cloudfive »).

### A2 — Corriger les bugs remontés par A1 🟡 **← prochaine étape, bloquante**
- [x] Les 13 remontées corrigées le 02/09 (commit `8bc0693`)
- [ ] **Rejouer A1 de bout en bout** pour vérifier l'absence de régression
- [ ] Points à observer spécifiquement pendant ce second passage :
  - [ ] Rendu sonore des zombies (`ALIENS` — si le résultat ne convient pas, il faudra des
        fichiers audio custom dans la resource)
  - [ ] Dosage de `VEHICLE_SPAWN_BOOST` (véhicule propulsé à ~21 km/h au spawn)
  - [ ] Rangement d'un véhicule collé à un mur (4 sorties testées + recalage au sol)
  - [ ] Double clic molette = suppression d'un item du sac (chemin jamais appelé avant le
        02/09)
  - [ ] Zombies : anti-escalade par annulation du geste, poursuite d'un joueur en véhicule
  - [ ] Aucune régression du fix `vanta_ui` (spam de notifications > 8 simultanées)

**Fait quand :** A1 rejoué de bout en bout sans régression ni erreur console.

### A3 — Valider `pvp_combat` (anti combat-log) ✅ (02/09/2026)
- [x] Un coup donné/reçu passe attaquant + victime en « EN COMBAT » 5 s
- [x] Fenêtre glissante : un nouveau coup prolonge le timer
- [x] Déconnexion en plein combat → le joueur meurt, sac perdu, death bag créé
- [x] Dépôt au coffre protégé refusé tant que le mode combat est actif
- [x] Le mode combat ne se déclenche pas en zone safe ni entre membres de squad

### A4 — Trancher la collision `/givexp` ✅ (30/08/2026)
- [x] Décision : `pvp_admin` relaie vers `exports['vanta_xp']:addXP`, le
      `RegisterCommand('givexp')` de `vanta_xp` est supprimé
- [x] Vérifié en jeu : l'XP réelle monte, niveau et prestige suivent

> ⚠️ **La même classe de bug existe toujours sur `/xp`** (`vanta_xp/client.lua:13` vs
> `pvp_inventory/client/client.lua:56`). Traité en **B5**.

### A5 — Valider `pvp_character` en profondeur ✅ (02/09/2026)
- [x] Parcours freemode : peau, morphologie, cheveux + couleur, vêtements, accessoires
- [x] Choix d'un ped spécial → définitif sans Gold/Diamond
- [x] Modération pseudo (mot interdit refusé)
- [x] `pvp_inventory` onglet Profil : bouton de changement de ped verrouillé sans
      abonnement, rejet serveur si forcé

> Reste hors périmètre A5, à exercer plus tard : `/rename` (réservé aux abonnés — Diamond
> illimité, Gold 1×/semaine), jamais testé faute d'abonnement actif en base.

---

## 4. PHASE B — Cohérence technique *(bloquant sortie)*

### B1 — Migration des notifications vers `vanta_ui` ✅ (30/08/2026)
- [x] `pvp_market` → `exports['vanta_ui']:notify` (41 appels)
- [x] `pvp_zombies` → idem (1 appel) — et `pvp_outposts` (1), oublié de la liste initiale
- [x] `pvp_inventory` → handler `pvp_market:notify` retiré, remplacé par `pvp_inventory:unlockTransfer` (47 appels migrés)
- [x] Vérifier qu'aucune resource n'appelle plus `pvp_market:notify`

**Fait quand :** un seul style de toast à l'écran, `pvp_market:notify` supprimé du code.

**Résultat :** 90 notifications migrées. Seules 2 occurrences de `pvp_market:notify`
subsistent, dans des commentaires historiques. `vanta_ui/html/notify.html` est le seul
système de notification du projet — la pile est ancrée en bas au centre (position
historique du toast de `pvp_inventory`, conservée volontairement).

Les types ont été revus message par message plutôt que convertis mécaniquement depuis
`true`/`false` : 17 `success`, 20 `error`, 27 `warning`, 14 `info` — contre 73 rouges
avant. Les états transitoires (« Opération en cours... ») sont en bleu, les refus de règle
(zone safe, poids, limite d'annonces) en jaune.

Deux trouvailles pendant la migration :
- `pvp_inventory/client/client.lua` contenait 12 `SendNUIMessage({ type = 'notify' })`
  directs, invisibles dans une recherche sur `pvp_market:notify` — migrés aussi.
- `pvp_market/client/client.lua` en avait un, mais `pvp_market` n'a pas de `ui_page` :
  « Aucun joueur proche pour échanger. » n'était **jamais** affiché. Corrigé.

> ⚠️ **Piège à connaître.** Dans l'ancien système, la notification levait aussi le verrou
> anti-duplication des transferts d'items (`transferLocked` dans `html/app.js`), car les
> chemins d'erreur d'un transfert répondent **uniquement** par une notification, sans
> refresh. Les deux rôles sont désormais séparés : `vanta_ui` affiche le texte, l'event
> `pvp_inventory:unlockTransfer` porte le déverrouillage. Le helper `notify()` de
> `pvp_inventory/server/server.lua` émet les deux — **toute notification émise depuis
> `pvp_inventory` doit passer par ce helper**. Côté NUI, `toast()` n'affiche plus rien
> lui-même : c'est un pont vers `vanta_ui` via le callback NUI `notify`.

### B2 — Source unique des tables d'items *(à reprendre de zéro)*

> ⚠️ Le journal du 30/08 note « B2 fait également, création d'une resource dédiée à
> l'organisation des items ». **Vérifié le 03/09 : cette resource n'existe pas.** Aucun
> fichier ni dossier de catalogue partagé dans `resources/[menu]/`. L'entrée de journal est
> corrigée en bas de ce fichier et B2 repasse à zéro.

L'audit a par ailleurs trouvé **six** listes concurrentes, pas deux :

| Liste | Fichier | Rôle |
|---|---|---|
| `Config.ShopItems` | `pvp_outposts/config.lua:271` | Boutique générale |
| `Config.WeaponShopItems` | `pvp_outposts/config.lua:288` | Armurerie (29 entrées) |
| `Config.AllItemPrices` | `pvp_outposts/config.lua:322` | Prix de revente |
| `WEAPONS` | `pvp_inventory/server/server.lua:878` | Whitelist anti-triche (MK2 inclus) |
| `Config.LootTable` | `pvp_zombies/config.lua` | Loot pondéré zombies (66 entrées) |
| `Config.Vehicles` + `Config.MarketOnlyVehicles` | `pvp_garage/config.lua` | Catalogue véhicule (~35) |

- [ ] Créer une resource `vanta_items` (ou un `shared/items.lua` dans `vanta_ui`) portant
      **une** table : nom interne, label, rareté, poids, prix d'achat, prix de vente,
      achetable oui/non, lootable oui/non
- [ ] Faire dériver les six listes ci-dessus de cette table (filtres, pas copies)
- [ ] Reporter la liste consolidée dans `CLAUDE.md`, résorber la section « Écarts » de
      `STATUS.md`

**Fait quand :** ajouter un item se fait en un seul endroit, et une arme achetable ne peut
plus être absente de la whitelist anti-triche.

### B3 — `pvp_drops` : équilibrage loot + test terrain
- [ ] Trancher le ratio épic / légendaire (~81 / 19 aujourd'hui) : assumer ou augmenter
- [ ] Tester avion + trajectoire flèches-sprite minimap (bigmap + écran large)
- [ ] Tester atterrissage par raycast au premier contact (toit de bâtiment surtout)
- [ ] Tester failover contrôleur : déco en plein vol **et** en pleine chute
- [ ] Tester expiration d'un drop non récupéré (`Config.DropLifetime`, 1 h)
- [ ] Tester fusées éclairantes (props + son `Flare`) et `/droptest`

**Fait quand :** un drop complet (largage → sécurisation → ouverture) validé à 2 joueurs,
failover inclus.

### B4 — Sécurité : jetons de fouille `pvp_zombies` ✅ (03/09/2026, non testé en jeu)

- [x] Plafonner l'émission : seau à jetons (capacité 20, remplissage 1 / 8 s), calé sur la
      boucle de spawn du client
- [x] Exiger un joueur existant (`ESX.GetPlayerFromId`) avant toute émission
- [x] Refuser un `claimLoot` arrivant moins de 1 500 ms après l'émission du jeton
- [x] Vérifier le TTL au moment de la consommation, pas seulement dans le thread de purge
- [x] Plafond mémoire de 400 jetons vivants par joueur
- [x] `MAX_LOOTS_WINDOW` ramené de 30 à 15 par fenêtre de 30 s
- [x] Logs d'avertissement throttlés (1 / 10 s / joueur) + nettoyage complet à la
      déconnexion (seau et compteur de logs, pas seulement les jetons)
- [x] Exemption `admin`/`superadmin` pour que `/spawnzombies 30` reste testable
- [x] Client : plus de prompt « [E] Fouiller » sur un cadavre sans jeton (action muette)
- [ ] **Valider en jeu** (voir `STATUS.md` pour le protocole)

**Effet mesuré :** un bot passe de 60 à 9,5 fouilles/minute, contre 7,6 pour un joueur
légitime — 0 refus pour ce dernier.

**Limite assumée :** tant que les zombies sont des peds locaux, le serveur ne peut pas
prouver qu'un zombie est mort. Le correctif ramène le tricheur au débit d'un joueur normal,
il ne l'élimine pas. Passer les zombies en entités réseau est la seule vraie parade — coût
OneSync à évaluer, à décider seulement si le problème se manifeste en production.

### B5 — Dette technique relevée par l'audit du 03/09 *(nouveau)*

Détail de chaque point dans `STATUS.md` → « Bugs actifs connus ».

- [ ] **Collision `/xp`** : `vanta_xp/client.lua:13` et `pvp_inventory/client/client.lua:56`
      enregistrent la même commande, `vanta_xp` gagne (chargée après). Trancher comme pour
      `/givexp` : une seule des deux UI garde `/xp`, l'autre prend un autre nom ou disparaît
- [ ] **Dépendances `fxmanifest` manquantes** : `pvp_combat` (aucune → `pvp_outposts`,
      `pvp_inventory`), `pvp_garage` (aucune → `vanta_ui`, `pvp_inventory`), `pvp_vcoins`
      (aucune → `pvp_inventory`), `pvp_crew` (→ `pvp_inventory`, `vanta_ui`)
- [ ] **Exports morts** : supprimer `vanta_xp:getBagBonus`/`getContainerBonus` et les
      exports `pvp_vcoins` sans consommateur (`GetStashBonus`, `HasDiamond`,
      `HasGoldOrDiamond`, `GetSubscriptionTier`, `GetVCoins`) — ou les câbler. Corriger
      `CLAUDE.md`, qui les décrit comme utilisés
- [ ] **`setBagBonus` sans paramètre `source`** : appliquer le même correctif que
      `setContainerBonus` (somme par source) avant qu'une 2ᵉ source n'apparaisse
- [ ] **`spooner/` gitignoré** : sortir le `permissions.cfg` VANTA du dossier ignoré, sinon
      un clone frais du dépôt réintroduit la faille `builtin.everyone` du 23/08
- [ ] **Table `characters` fantôme** : retirer l'entrée de `CLAUDE.md` (aucune resource ne
      la crée, et la section `pvp_character` du même fichier dit l'inverse)
- [ ] **Resources ESX résiduelles** : documenter ou supprimer `esx_hud` (désactivé,
      114 fichiers sur le disque), `esx_menu_*` et `async`, absents de l'arborescence de
      `CLAUDE.md` alors que `pvp_outposts` dépend d'`esx_menu_default`
- [ ] **`AGENTS.md` a divergé de `CLAUDE.md`** : 389 lignes contre 618, il ignore
      `pvp_combat`, le système de notifications `vanta_ui` et tout ce qui a suivi le 23/08.
      Deux docs d'architecture contradictoires, lues par des outils différents. Trancher :
      un `AGENTS.md` d'une ligne pointant vers `CLAUDE.md`, ou une génération automatique
- [ ] **Google Fonts en dur** : `vanta.css:11` importe Inter depuis
      `fonts.googleapis.com`. Embarquer les `.woff2` dans `vanta_ui` avant la sortie

**Fait quand :** aucun export mort, aucune dépendance implicite, aucune collision de
commande, et le dépôt seul suffit à relancer un serveur sécurisé.

---

## 5. PHASE C — Polish gameplay & visuel

### C1 — `pvp_redzones`
- [ ] Visuels carte + minimap (zones lisibles)
- [ ] Notification de rotation (toutes les heures)
- [ ] Timer visible avant rotation
- [ ] Vérifier loot ×2 effectif dans la zone

### C2 — `pvp_killfeed`
- [ ] Tester affichage haut-droite « KILLER → VICTIME »
- [ ] Couleur distincte pour kill en redzone
- [ ] Vérifier le sanity-check distance (seuil 2000m) sur un tir sniper réel

### C3 — `pvp_crew` : test bout-en-bout
- [ ] Créer / rejoindre un crew, tag visible
- [ ] Contrat quotidien : progression multi-participants, complétion, crédit trésorerie + entrée `pvp_crew_treasury_log`
- [ ] Boutique : achat des 3 bonus, anti-cumul, expiration, application/retrait du bonus de coffre à la connexion/déconnexion/exclusion
- [ ] Non-régression : bonus de coffre prestige + abonnement + crew cumulés sans écrasement
- [ ] Friendly fire : squad protégée, crew entier peut se tuer entre membres

### C4 — `pvp_market` : refonte design
- [ ] Maquette / direction visuelle (VANTA v2, plus lisible et présent)
- [ ] Intégration NUI
- [ ] Test achat / vente après refonte

### C5 — Identité visuelle v2.1 « Monolithe » : trancher la branche non mergée *(nouveau, 03/09)*

La branche `origin/claude/vanta-visual-identity-gma5lm` (commit `ab5c8a9`, 24/08) porte une
refonte complète du design system : **38 fichiers, +2 997 / −1 569**, dont `vanta.css`
(+957/−…), toutes les NUI (`pvp_hud`, `pvp_inventory`, `pvp_crew`, `pvp_outposts`,
`vanta_xp`, `pvp_admin`, `pvp_character`, `pvp_garage`, `vanta_loading`, `pvp_killfeed`),
trois SVG de marque (`mark.svg`, `mark-boxed.svg`, `lockup.svg`), un `VANTA_BRAND.md` de
234 lignes, et de nouvelles bannières + `server_icon.png`.

Elle n'est **pas mergée** et a 12 commits de retard sur `main`. `vanta.css` en production
est toujours estampillé `VANTA DESIGN SYSTEM v2.0`. Plus le temps passe, plus le merge
coûte cher : chaque session qui touche une NUI creuse l'écart.

- [ ] Décider : merger v2.1, ou abandonner la branche explicitement
- [ ] Si merge : rebaser sur `main`, résoudre les conflits NUI (`pvp_hud/html/index.html`
      et `pvp_inventory/html/style.css` ont bougé des deux côtés), puis rejouer un tour
      d'UI en jeu
- [ ] Mettre `CLAUDE.md` (section « Identité Visuelle ») en cohérence avec la version
      retenue
- [ ] Nettoyer les 6 autres branches distantes, toutes déjà intégrées dans `main` par
      contenu (`airdrop-resource-audit-lp7ac2`, `airdrop-system-revisions-op4o66`,
      `character-top-display-bugs-a1be95`, `dreamy-franklin-ewgmls`,
      `verify-game-assets-images-67femy`, `pvp-drops-airdrop-revisions`)

**Fait quand :** une seule version du design system existe, dans `main`, et les branches
mortes sont supprimées.

---

## 6. PHASE D — Pré-production & mise en ligne *(bloquant sortie)*

### D1 — Secret Tebex
- [ ] Si intégration Tebex activée : générer un vrai `TEBEX_URL_SECRET` (≠ `CHANGE_ME_...`) dans `pvp_vcoins/server/server.lua`
- [ ] Sinon : documenter que Tebex est désactivé et le webhook non exposé

### D2 — Permissions admin
- [ ] Vérifier que tous les comptes qui doivent l'être sont dans `group.admin` (`add_principal` dans `server.cfg`) — sinon plus d'accès `spooner` ni panel admin

### D3 — `vanta_loading`
- [ ] Décider : réactiver (`ensure vanta_loading` dans `server.cfg`) ou retirer définitivement
- [ ] Documenter la raison de la désactivation actuelle

### D4 — `server.cfg` de production
- [ ] `sv_hostname`, tags, description, bannière
- [ ] `sv_licenseKey` (clé du serveur public)
- [ ] `steam_webApiKey`
- [ ] `sv_maxClients` réel (actuellement 10, test local)
- [ ] OneSync configuré pour la prod
- [ ] Retirer / sécuriser les commandes de test (`/droptest`, `/dropadmin`, spawn zombies…) hors `group.admin`

### D5 — Test de charge multi-joueurs
- [ ] Session à 3-4 joueurs minimum
- [ ] Perf OneSync + nettoyage monde chaque frame de `pvp_hud` (point de vigilance)
- [ ] Spawn zombies sous charge, drops avec plusieurs contrôleurs potentiels
- [ ] Relever le framerate serveur (`resmon`) et les scripts les plus lourds

### D6 — Infrastructure
- [ ] Machine / hébergement décidé (spécs, OS)
- [ ] Ports ouverts (30120 TCP/UDP par défaut)
- [ ] **Backup automatique de la base MySQL** (perdre la base = perdre les joueurs)
- [ ] Procédure de redémarrage / mise à jour documentée

---

## 7. PHASE E — Post-lancement (v1.1+)

- [ ] Crew vs crew — système d'affrontement entre crews (à brainstormer) — *STATUS.md Phase 4b*
- [ ] Mapping des avant-postes (CodeWalker) — *STATUS.md Phase 5*
- [ ] `pvp_crew` : hiérarchie avancée, coffre partagé, vision long terme
- [ ] Reprise éventuelle des mappings custom retirés

---

## 8. Check-list Go / No-Go sortie publique

Ne pas ouvrir au public tant que **tout** ci-dessous n'est pas ✅ :

- [x] Parcours joueur complet (A1) traversé une fois — 02/09/2026
- [ ] Parcours rejoué sans régression après les 13 correctifs du 02/09 (A2)
- [x] `pvp_combat` anti combat-log validé à 2 joueurs (A3) — 02/09/2026
- [x] `pvp_character` : aucun chemin de création ne bloque l'apparition (A5) — 02/09/2026
- [x] Notifications unifiées (B1) — 30/08/2026
- [x] Jetons de fouille `pvp_zombies` sécurisés (B4) — 03/09/2026, **reste à valider en jeu**
- [ ] `pvp_drops` : un drop complet validé, failover inclus (B3)
- [ ] `pvp_crew` : contrat quotidien + boutique exercés à 2 membres (C3)
- [ ] Aucune erreur console serveur au démarrage ni en boucle
- [ ] `TEBEX_URL_SECRET` changé ou Tebex désactivé (D1)
- [ ] Comptes admin dans `group.admin`, `spooner/permissions.cfg` restauré et versionné
      (D2, B5), commandes de test non accessibles aux joueurs (D4)
- [ ] `server.cfg` prod complet (D4)
- [ ] Test de charge à 3-4 joueurs passé (D5)
- [ ] Backup DB automatique en place (D6)

---

## 9. Ordre d'exécution recommandé *(établi le 03/09)*

Le critère de tri : **ce qui rend le reste du travail non réutilisable si on le fait
après**. Un test joué sur une base non sécurisée est à refaire ; un polish visuel posé sur
une NUI qui va être remplacée par la v2.1 est à refaire aussi.

| # | Action | Phase | Pourquoi maintenant | Fini quand |
|---|---|---|---|---|
| ~~1~~ | ~~Sécuriser `getSpawnToken`~~ ✅ 03/09 | B4 | — | Fait : bot ramené de 60 à 9,5 fouilles/min |
| 2 | Trancher la branche v2.1 « Monolithe » | C5 | Elle touche 10 NUI. Chaque jour de retard augmente le coût du merge, et tout polish visuel fait avant est perdu | Une seule version du design system dans `main` |
| 3 | Rejouer A1 de bout en bout | A2 | Dernier item bloquant de la phase A. À faire **après** 1 et 2 pour ne le jouer qu'une fois | Parcours sans régression ni erreur console |
| 4 | Premier drop réel à 2 joueurs | B3 | Le plus gros bloc de code jamais exécuté (1 958 lignes, avion + réseau + failover) | Largage → sécurisation → ouverture, failover inclus |
| 5 | Crew à 2 membres, contrat + boutique | C3 | 2ᵉ bloc jamais exécuté, et il touche le cumul de bonus de coffre (3 sources) | Contrat crédité, bonus appliqués sans écrasement |
| 6 | Dette technique | B5 | Peu risqué, mais `/xp` et les dépendances implicites produiront des bugs fantômes pendant les tests suivants | Aucun export mort, aucune collision |
| 7 | Source unique des items | B2 | Gros chantier structurel. À faire une fois l'équilibrage figé par 4 et 5, sinon on refactore une table qui bouge encore | Ajouter un item se fait en un seul endroit |
| 8 | Redzones, killfeed, VCoins, admin, XP | C1/C2 + tests | Le reste du jamais-exercé | Chaque resource vue au moins une fois |
| 9 | Pré-production | D1→D6 | Tebex, permissions, `server.cfg` prod, charge, backup | Check-list Go/No-Go complète |

**Estimation grossière du chemin critique** (1 → 6, hors B2 et polish) : 3 à 5 sessions de
travail, dont au moins deux à 2 joueurs minimum.

---

## 10. Journal de session

> Une ligne par session de travail. But : ne plus jamais « se perdre entre les sessions ».
> Format : date — ce qui a été fait — ce qui bloque — prochaine étape.

| Date | Fait | Bloqué par | Prochaine étape |
|---|---|---|---|
| 2026-08-27 | Création de ce ROADMAP.md à partir de STATUS.md + historique git | — | Attaquer A1 (session de test parcours joueur) |
| 2026-08-30 | A4 tranchée (`/givexp` → relais vers `vanta_xp`). B1 terminée : 90 notifications migrées vers `vanta_ui`. `/rename` repassé en réservé-abonnés (fin du tarif 5 000 $ et de `rename_free_season`) | — | A1 |
| 2026-09-01 | Fix de la boucle infinie `vanta_ui/notify.js` (NUI entièrement figée au-delà de 8 notifications) + durcissements `pvp_inventory` (chien de garde, verrous horodatés) | — | A1 |
| 2026-09-02 | **Session de test multijoueur Cloudfive** : A1, A3 et A5 traversés. 13 anomalies remontées et corrigées d'un bloc (commit `8bc0693`) | Correctifs non rejoués | A2 |
| 2026-09-03 | Audit de cohérence dépôt-wide. `main` confirmé à jour (`8bc0693`). 10 écarts doc/code et 1 trou de sécurité relevés, tableau de bord resynchronisé, B4/B5/C5 ajoutés, ordre d'exécution établi. **Correction : la « resource dédiée à l'organisation des items » notée faite le 30/08 n'existe pas** — B2 repasse à zéro | — | B4 (sécuriser `getSpawnToken`), puis C5, puis A2 |

> ⚠️ **Entrée corrigée.** Le journal du 30/08 affirmait « B2 fait également, création d'une
> resource dédiée à l'organisation des items ». Vérification du 03/09 : aucun fichier ni
> dossier de ce type dans `resources/[menu]/`, et six listes d'items concurrentes
> subsistent. B2 n'a jamais été entamée.
