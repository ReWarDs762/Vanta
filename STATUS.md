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

*Aucun bug actif documenté pour l'instant.*

---

## Bugs corrigés

### Retours de la session de test multijoueur Cloudfive (corrigés 02/09/2026, non retestés en jeu)

Onze remontées d'une session de test en ligne, traitées d'un bloc.

| Remontée | Correctif | Fichier |
|---|---|---|
| Balle dans la tête = one-shot | `SetPedSuffersCriticalHits(ped, false)` sur le ped local (les dégâts s'appliquent chez la victime, donc le réglage vit côté client) | `pvp_hud/client/client.lua` |
| Étoiles de police disponibles | `SetMaxWantedLevel(0)` + multiplicateur à 0, police ignore le joueur, dispatch et flics aléatoires coupés. Le reset par frame existant ne rattrapait qu'après coup | `pvp_hud/client/client.lua` |
| Bruit de radio de police | `SetAudioFlag('PoliceScannerDisabled', true)` + `DistantCopCarSirens(false)` — le scanner audio tourne indépendamment du wanted level et des PNJ | `pvp_hud/client/client.lua` |
| Dégâts lors d'un accident | `collisionProof` **permanent** (véhicule ET à pied) + restauration explicite de la vie/armure dès qu'un véhicule est en cause (`HasEntityBeenDamagedByAnyVehicle`, `WEAPON_RUN_OVER_BY_CAR`, `WEAPON_RAMMED_BY_CAR`) + `SetPedCanBeKnockedOffVehicle(1)`, `SetPedRagdollOnCollision(false)`, `SetPedCanRagdollFromPlayerImpact(false)`. **Corrigé une 2e fois le 02/09** : `collisionProof` seul laissait encore passer les dégâts, et il fallait aussi qu'écraser un joueur ne le blesse ni ne le fasse tomber | `pvp_hud/client/client.lua` |
| Menu squad sur « A » au lieu de « J » | Le code écoutait le contrôle 44 (INPUT_COVER), câblé sur le Q du QWERTY → le A d'un AZERTY. Remplacé par `RegisterKeyMapping('pvp_squad', ..., 'j')`, indépendant de la disposition et rebindable | `pvp_crew/client/client.lua` |
| Joueur téléporté à Sandy Shores au bout de 15 min | Course entre `playerSpawned` et `setLoginOutpost` : le handler faisait la téléportation puis remettait `loginOutpost` à `nil`, la boucle d'attente ne voyait donc jamais la réponse, tournait ses 15 min et re-téléportait au fallback. Nouveau témoin durable `loginOutpostReceived` | `pvp_spawn/client/client.lua` |
| Zombies avec des voix de PNJ | Voix `ALIENS` (seule banque non humaine native), audio de douleur humain coupé, + boucle de râles forcés à proximité | `pvp_zombies/client/client.lua` |
| Zombies qui grimpent aux murs | `SetPedPathCanUseClimbovers/Ladders/DropFromHeight(false)` + coût d'escalade prohibitif | `pvp_zombies/client/client.lua` |
| Drop ouvrable depuis un véhicule | Prompt bloqué côté client + refus côté serveur dans `pvp_drops:open` (anti-trigger forgé) | `pvp_drops/client/client.lua`, `pvp_drops/server/server.lua` |
| Pas de suppression d'item | Double clic molette sur une carte du SAC → `dropItem` (1 unité, destruction pure). L'event serveur existait mais n'était appelé par personne ; il déséquipe maintenant l'arme si c'était la dernière unité | `pvp_inventory/html/app.js`, `pvp_inventory/server/server.lua` |
| Véhicule spawné à l'arrêt | Moteur allumé + `SetVehicleForwardSpeed` à 6 m/s (≈21 km/h) au moment du spawn | `pvp_inventory/client/client.lua` |
| Zombies immobiles quand le joueur est en véhicule | `TaskCombatPed` n'engage pas une cible en véhicule pour un ped à mains nues. Mode « poursuite » (`TaskGoToEntity`) tant que le joueur roule — voir l'encadré ci-dessous | `pvp_zombies/client/client.lua` |
| Sous la map en rangeant un véhicule contre un mur | La sortie était un `+2.0` aveugle sur X, qui tombait dans le décor. Remplacé par 4 sorties testées autour du véhicule via `GetSafeCoordForPed`, recalage sur le sol (`GetGroundZFor_3dCoord`) et repli sur la position du véhicule. Le véhicule est aussi supprimé **avant** le déplacement du joueur, sinon `SetEntityCoords` le traîne et c'est sa collision qui décide | `pvp_inventory/client/client.lua` |

#### Zombies immobiles quand le joueur est en véhicule — cause réelle

**Cause : `TaskCombatPed` ne fait pas avancer un ped à mains nues vers une cible
assise dans un véhicule.** Sans attaque valide à sa portée, l'IA de combat le
laisse planté. Rien à voir avec le pathfinding — constaté sur une capture d'écran
en pleine route dégagée, sans le moindre obstacle.

**Solution** : `taskZombie(zed, playerPed, playerInVehicle)` dans
`pvp_zombies/client/client.lua`, deux modes stockés dans `z.mode` :
- joueur à pied ⇒ `TaskCombatPed` (inchangé, ils frappent) ;
- joueur en véhicule ⇒ `TaskGoToEntity` piloté à la main, qui suit une cible
  mobile et les fait converger autour du véhicule.

La bascule se fait dans la boucle de mise à jour, **uniquement au changement de
mode** (ré-émettre la tâche à chaque passage la réinitialise et fait bégayer le
déplacement). `SetPedCombatAttributes(ped, 21, true)` (`BF_CanChaseTargetOnFoot`)
est posé en plus comme filet. Un zombie qui apparaît alors que le joueur roule
naît directement en mode poursuite.

#### Corollaire : ne pas restreindre le pathfinding pour empêcher l'escalade

Deux tentatives ont été faites dans cette direction avant d'identifier la vraie
cause ci-dessus, toutes deux retirées :

1. `SetPedPathCanDropFromHeight(false)` + coût d'escalade prohibitif — le moindre
   trottoir compte comme une descente.
2. `SetPedPathCanUseClimbovers(false)` — dans le navmesh GTA, les « climbovers »
   ne sont pas que les murs : ce sont les liens entre polygones pour tous les
   petits obstacles (bordures, barrières, rebords). Les interdire ampute une
   grande partie des chemins de la carte.

L'interdiction d'escalade porte donc sur le **geste** : une boucle à 100 ms annule
toute escalade entamée (`IsPedClimbing` ⇒ `ClearPedTasksImmediately` + re-tâche) ;
le zombie retombe au pied du mur et cherche un contournement. Côté pathfinding il
ne reste que les échelles (`SetPedPathCanUseLadders(false)`, liens ponctuels sans
risque) et un coût d'escalade dissuasif, qui n'a jamais rendu un chemin impossible.

`IsPedJumping` est volontairement exclu du test : descendre d'un rebord joue aussi
une animation de saut, l'interrompre ferait bégayer les zombies en navigation
normale.

**Points à valider en jeu :** le rendu sonore des zombies (GTA V n'a pas de banque
de voix zombie ; `ALIENS` est le plus proche en natif — si le résultat ne convient
pas, il faudra passer par des fichiers audio custom dans la resource) et le dosage
de la propulsion au spawn véhicule (`VEHICLE_SPAWN_BOOST`).

**Non traité, à confirmer :** « dégâts lors d'un accident » a été compris comme les
dégâts subis par le **joueur**. La déformation/casse du **véhicule** lui-même est
inchangée.

### `vanta_ui` — boucle infinie des notifications, tout le NUI figé (corrigé 01/09/2026)

Signalé en test : l'inventaire se fige (plus de clic, plus de fermeture, plus rien) en
spammant le clic droit — d'abord sur un conteneur protégé plein, puis en sortant des items
du coffre. Point commun réel : **le nombre de notifications affichées**, pas l'inventaire.

**Cause : boucle infinie dans `vanta_ui/html/notify.js`.**

```js
while (STACK.children.length > MAX_VISIBLE) {   // MAX_VISIBLE = 8
  remove(STACK.firstElementChild);
}
```

`remove()` ne retire pas le noeud : il le marque `leaving`, joue l'animation de sortie et
programme le retrait réel 200 ms plus tard — et un noeud déjà marqué est ignoré aux tours
suivants. `STACK.children.length` ne diminue donc jamais. **Dès la 9ᵉ notification simultanée,
la boucle part à l'infini.**

Pourquoi tout le jeu paraît figé : dans FiveM, les pages NUI de toutes les resources
partagent le **même thread JS du renderer CEF**. La boucle de `vanta_ui` bloque donc aussi
la page de `pvp_inventory`, qui reste affichée (dernière image peinte) mais ne traite plus
ni clic, ni touche, ni fermeture — jusqu'au redémarrage de la resource. Les deux captures
du bug montrent exactement 8 notifications à l'écran.

**Correction :** `trimStack()` ne compte que les notifications encore vivantes et retire
depuis une copie de la liste, qui raccourcit réellement à chaque tour (30 notifications
d'affilée : 0,9 ms, 1 tour par push, 8 vivantes conservées).

Durcissements gardés au passage sur `pvp_inventory` (utiles, mais ce n'étaient pas la
cause) :
- `document.addEventListener('contextmenu', e => e.preventDefault())` global — seules les
  cartes d'items annulaient l'événement, un clic droit à côté laissait CEF ouvrir son menu
  contextuel natif. `pvp_garage` avait déjà cette garde.
- Tests de capacité **côté client** avant l'envoi : dépôt refusé si le coffre est plein,
  retrait refusé si la carte est déjà vide ou le sac trop lourd (toasts throttlés à 1 par
  1,5 s). Le serveur refait le calcul, il reste seul juge. Effet secondaire important : ça
  réduit fortement le nombre de notifications, donc ça masquait le vrai bug sur le dépôt.
- `transferLocked` via `lockTransfer()`/`unlockTransfer()`, libération automatique après
  3 s et à la fermeture ; `stashLocks` serveur horodaté (expiration 10 s) au lieu d'un
  booléen.
- **Chien de garde NUI** : ping/pong chaque seconde tant que l'inventaire est ouvert. Sans
  réponse pendant 5 s, le client Lua ferme de force et écrit la raison dans la console F8
  (erreur JS remontée, nombre de requêtes NUI en attente, page muette). **F10** ferme
  l'inventaire depuis le jeu, même page morte.

### `/givexp` — collision de commande (corrigé 30/08/2026, non testé en jeu)

`vanta_xp/server.lua` et `pvp_admin/server/server.lua` déclaraient chacun une commande
`/givexp`. FiveM ne garde que la dernière enregistrée sous un nom donné — `pvp_admin`
étant `ensure`d après `vanta_xp` dans `server.cfg`, c'est la sienne qui gagnait, et elle
écrivait dans la colonne morte `pvp_player_stats.xp` au lieu de la vraie table de
progression. Résultat : `/givexp` ne faisait rien d'observable pour le joueur.

**Décision retenue :** relais. La commande reste dans `pvp_admin` (permissions `hasPerm`,
logs `pvp_admin_logs`, panel NUI) mais passe désormais par un helper `awardXP()` qui
appelle `exports['vanta_xp']:addXP(identifier, amount, 'admin_givexp')` — niveaux,
prestige, table `vanta_xp` et notification client compris. Le `RegisterCommand('givexp')`
de `vanta_xp` a été supprimé (code mort), `vanta_xp` ajouté aux `dependencies` de
`pvp_admin`. Si l'export est indisponible, l'admin reçoit une erreur explicite et aucun
log de succès n'est écrit.

**À tester en jeu :** `/givexp [id] [montant]` et le bouton XP du panel F7 → la barre
d'XP/niveau doit bouger côté joueur.

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
  - [x] `/givexp` : collision tranchée — relais `pvp_admin` → export `addXP` de `vanta_xp`
        (30/08/2026, à tester)
- [x] Phase 4a — Crew : hiérarchie, coffre partagé, contrat quotidien, trésorerie/monnaie
      collective, boutique de bonus temporaires, historique (24/08/2026, non testé en jeu)
- [ ] Phase 4b — Crew : système d'affrontement entre crews (à brainstormer)
- [ ] Phase 5 — Mapping avant-postes (CodeWalker)
- [ ] Phase 6 — Lancement public
