# VANTA — Statut du projet

Ce fichier contient tout ce qui change souvent : avancement par resource, bugs actifs,
roadmap, ce qui a été validé en jeu. À tenir à jour à chaque session — bien plus vite que
`CLAUDE.md`, qui ne décrit que l'architecture stable.

**Dernière mise à jour :** 3 septembre 2026 (audit de cohérence dépôt-wide : état du `main`, écarts doc/code, dette technique, priorités — voir « Bugs actifs connus » et `ROADMAP.md`)

> L'en-tête est resté figé au 24/08 pendant plusieurs sessions alors que le fichier
> contenait déjà des correctifs du 02/09. Vérifier cette ligne à chaque commit qui touche
> ce fichier.

---

## Statut par resource

Statut au 03/09/2026. « Testé » = exercé manette en main au moins une fois, pas « sans
bug ». Voir « Testé en jeu vs jamais testé » plus bas pour le détail des trois états.

| Resource | Statut | Détail |
|---|---|---|
| `pvp_character` | Testé (02/09), correctifs non rejoués | Parcours freemode + ped spécial validés lors de la session Cloudfive, ainsi que la restriction « changement de ped réservé Gold/Diamond » côté serveur. `/rename` (réservé abonnés) reste à exercer. |
| `pvp_inventory` | Testé (02/09), correctifs non rejoués | Le plus gros système (234 fichiers, ~12 000 lignes). Sac, hotbar, 3 coffres, marché, mort/death bag exercés. Trois correctifs postérieurs non rejoués : suppression d'item au double clic molette, sortie de véhicule contre un mur, propulsion au spawn véhicule. |
| `pvp_combat` | Testé (02/09) | Les 5 points d'A3 validés à 2 joueurs, déconnexion en plein combat incluse. `fxmanifest.lua` ne déclare toujours aucune dépendance (voir Bugs actifs). |
| `pvp_hud` | Testé (02/09), correctifs non rejoués | Session Cloudfive : 5 des 13 remontées venaient d'ici (one-shot tête, étoiles de police, radio, dégâts de collision, chute). Tous corrigés le 02/09, aucun rejoué. |
| `pvp_zombies` | Testé (02/09), correctifs non rejoués | Kill → loot → item validé. Correctifs postérieurs : voix `ALIENS`, anti-escalade par annulation du geste, poursuite du joueur en véhicule (`TaskGoToEntity`). Trou de sécurité sur `getSpawnToken` **corrigé le 03/09** (seau à jetons) — non testé en jeu. |
| `pvp_outposts` | Testé (02/09) | Armurerie, customisation d'arme, téléportation NPC + waypoint exercés. Stable. |
| `pvp_garage` | Testé (02/09) | Achat/vente/spawn véhicule exercés. `fxmanifest.lua` sans dépendances déclarées. |
| `pvp_spawn` | Testé (02/09), correctif non rejoué | Bug « téléporté à Sandy Shores au bout de 15 min » (course `playerSpawned` / `setLoginOutpost`) corrigé le 02/09, non rejoué. |
| `pvp_market` | Testé (02/09), design à retravailler | Annonce + achat exercés. Refonte visuelle toujours à faire (ROADMAP C4). |
| `vanta_ui` | Testé (01-02/09) | Notifications affichées en jeu, et c'est ce qui a révélé la boucle infinie de `notify.js` (corrigée le 01/09). Migration des 90 notifications terminée le 30/08. |
| `pvp_drops` | **Jamais exercé** | Audité et corrigé le 24/08, enrichi le 25/08 (flèches minimap, atterrissage par raycast, `/droptest`), mais aucun drop n'a jamais été joué. Le plus gros bloc de risque non levé du projet. |
| `pvp_crew` | **Jamais exercé** | 4 crews en base, 0 membre. Contrat quotidien, trésorerie, boutique de bonus : code écrit le 24/08, jamais exécuté par un joueur. |
| `pvp_redzones` | **Jamais exercé** | Rotation horaire et loot ×2 jamais vérifiés. Affichage écran volontairement coupé le 02/09 (`ShowRedzoneHUD = false`) — les zones restent actives, seul le cercle rouge sur la carte les signale. |
| `pvp_killfeed` | **Jamais exercé** | Créé, jamais vu à l'écran. |
| `pvp_vcoins` | **Jamais exercé** | Abonnements et marché VCoins jamais exercés. `TEBEX_URL_SECRET` toujours à `CHANGE_ME_...` (ROADMAP D1). |
| `pvp_admin` | **Jamais exercé** | Panel F7, noclip, spectate, `/givexp` après relais du 30/08 : rien de vérifié. |
| `vanta_xp` | **Jamais exercé** | Montée de niveau, prestige, bonus de capacité jamais observés. Collision `/xp` active (voir Bugs actifs). |
| `vanta_loading` | Désactivé | `# ensure vanta_loading` dans `server.cfg`, raison jamais documentée. Décision à prendre (ROADMAP D3). |
| `spooner` | ⚠️ Correctif hors dépôt | Faille `builtin.everyone` corrigée le 23/08 **sur le disque local seulement** — le dossier est gitignoré. Voir Bugs actifs. |
| `esx_identity` | ❌ Supprimé (21/08/2026) | Remplacé par `pvp_character`. Reste une table `characters` fantôme dans la doc — voir Bugs actifs. |

Tout ce qui n'apparaît pas dans ce tableau est considéré stable — voir `CLAUDE.md` pour son
architecture.

---

## Bugs actifs connus

*Relevés par l'audit de cohérence du 03/09/2026. Aucun n'a été corrigé — ils sont listés
ici pour être traités dans l'ordre défini par `ROADMAP.md`.*

### ~~🔴 `pvp_zombies` — jetons de fouille délivrés sans aucune limite~~ ✅ CORRIGÉ (03/09/2026, non testé en jeu)

**Le trou.** `ESX.RegisterServerCallback('pvp_zombies:getSpawnToken')` fabriquait un jeton à
chaque appel : pas de cap, pas de cooldown, pas même une vérification que le joueur
existe. Les zombies étant des peds 100 % locaux (`isNetwork = false`), le serveur n'a
aucune entité à valider au moment du kill — mais il ne validait alors plus rien du tout. Un
client modifié bouclait `getSpawnToken` → `claimLoot` **sans jamais tuer un zombie**,
plafonné uniquement par le rate-limiter de `claimLoot` (30 fouilles / 30 s), soit
**60 fouilles/minute** — huit fois le débit d'un joueur légitime.

**Le plafond légitime, mesuré dans le client.** La boucle de spawn de
`client/client.lua` produit **1 zombie par `Config.SpawnInterval` (8 s)**, et seulement
tant que moins de `Config.MaxZombiesPerPlayer` (40) sont vivants. S'y ajoutent des rafales
de 3 via l'item `shot_attract`, et jusqu'à 30 d'un coup via `/spawnzombies` (admin). Le
débit soutenu d'un joueur qui joue réellement est donc de **7,5 zombies/minute**.

**Le correctif.** Un seau à jetons côté serveur, calé sur ce débit
(`Config.AntiCheat` dans `config.lua`) :

| Contrôle | Valeur | Ce qu'il empêche |
|---|---|---|
| Seau à jetons | capacité 20, remplissage 1 / 8 s | Le débit moyen d'émission ne peut plus dépasser la boucle de spawn du client |
| Joueur inexistant | `ESX.GetPlayerFromId` obligatoire | Un appel forgé hors session n'alimente plus le stock |
| Âge minimum du jeton | 1 500 ms | Un zombie ne peut pas naître, mourir et être fouillé dans le même souffle |
| TTL vérifié à la consommation | 30 min | Le thread de purge ne passe qu'une fois par minute — un jeton périmé passait entre les mailles |
| Plafond mémoire | 400 jetons vivants | Accumulation par les zombies despawnés sans être fouillés |
| Fouilles par fenêtre | 30 → **15** / 30 s | Rafale après un gros combat tolérée, débit soutenu ramené au niveau légitime |
| Logs | throttlés à 1 / 10 s / joueur | Un bot ne peut plus noyer la console ni gonfler le fichier de log |

Groupes `admin`/`superadmin` exemptés du seau : `/spawnzombies 30` reste testable sans
rendre la moitié des cadavres non fouillables.

**Effet mesuré** (simulation du seau sur 10 minutes) :

| Scénario | Avant | Après |
|---|---|---|
| Joueur légitime (1 spawn / 8 s) | 7,6 fouilles/min | 7,6 fouilles/min, 0 refus |
| Bot à 10 requêtes/s | 60 fouilles/min | **9,5 fouilles/min** |
| Bot à 100 requêtes/s | 60 fouilles/min | **9,5 fouilles/min** |

**Limite assumée, à connaître.** Ceci ne rend pas la fouille infalsifiable : tant que les
zombies sont des peds locaux, le serveur ne peut pas prouver qu'un zombie est mort. Le
correctif ramène le tricheur **au débit d'un joueur qui joue vraiment** — il ne gagne plus
que l'effort de tirer. Rendre la chose impossible demanderait des zombies en entités
réseau, avec le coût OneSync que ça implique. Décision à prendre si le problème se pose
réellement en production.

**À tester en jeu :** fouille normale d'une dizaine de zombies d'affilée (aucun refus
attendu), `shot_attract` en rafale, `/spawnzombies 30` en admin (les 30 cadavres doivent
rester fouillables), et vérifier qu'aucun `[ZOMBIE-ANTICHEAT]` n'apparaît en console pour
un joueur normal.

### ~~🟠 Collision de commande `/xp`~~ ✅ CORRIGÉ (03/09/2026, non testé en jeu)

`vanta_xp/client.lua` et `pvp_inventory/client/client.lua` enregistraient tous deux
`RegisterCommand('xp')`. FiveM ne garde que la dernière — `vanta_xp` étant `ensure`d en
52ᵉ position contre 46, c'est son panneau qui gagnait et le raccourci vers l'onglet Profil
de l'inventaire était du code mort. Même classe de bug que `/givexp`, jamais recherchée
ailleurs après le fix du 30/08.

**Décision : `/xp` revient à `pvp_inventory`**, dont l'onglet Profil porte déjà la barre
d'XP, les stats, les badges et le classement. La commande de `vanta_xp` est supprimée.

⚠️ **Conséquence à connaître.** Le `ui_page` de `vanta_xp` reste chargé — il porte les
toasts LEVEL UP et PRESTIGE, qui eux fonctionnent toujours. En revanche son **panneau
profil n'a plus de point d'entrée joueur**, et avec lui le **bouton PRESTIGE** qu'il était
seul à offrir. Le passage au prestige reste pleinement fonctionnel via la commande
`/prestige` (`vanta_xp/server.lua`, exige le niveau 100), mais il n'y a plus de bouton.
Ajouter un bouton PRESTIGE à l'onglet Profil de `pvp_inventory` est un item de roadmap
(C6), pas une régression de ce correctif.

### ~~🟠 `fxmanifest.lua` — dépendances non déclarées~~ ✅ CORRIGÉ (03/09/2026)

**Correction de l'audit initial.** Il annonçait « quatre resources consomment des exports
sans les déclarer, donc sans garantie d'ordre de chargement ». Vérification faite, c'est
plus nuancé :

- **`pvp_combat` ne consomme aucun export.** L'audit avait inversé le sens : c'est
  `pvp_inventory` qui appelle `exports['pvp_combat']:isInCombat`. La vraie dépendance de
  `pvp_combat` est l'event `pvp_inventory:combatLogDeath` — sans `pvp_inventory` démarré,
  l'anti combat-log ne fait plus rien. C'est elle qui a été déclarée.
- **Tous les appels d'exports inter-resources sont résolus à l'exécution et protégés par
  `pcall`.** L'ordre de démarrage n'a donc aucune incidence sur eux : c'était un manque de
  documentation et de robustesse, pas un bug fonctionnel comme l'audit le laissait croire.

Déclaré : `pvp_combat` → `pvp_inventory` ; `pvp_garage` → `es_extended`, `vanta_ui` (le
`<link nui://vanta_ui/html/vanta.css>` est une vraie dépendance au chargement de la NUI) ;
`pvp_vcoins` → `es_extended`, `mysql-async` ; `pvp_crew` → `pvp_inventory`.

Volontairement **non** déclaré, avec un commentaire expliquant pourquoi dans chaque
manifest : `pvp_garage` → `pvp_outposts` et `pvp_vcoins` → `pvp_inventory`. Les deux
inverseraient un ordre de `server.cfg` délibéré, pour des appels de toute façon résolus à
l'exécution.

### ~~🟡 Exports morts, documentés comme vivants~~ ✅ CORRIGÉ (03/09/2026)

Sept exports supprimés, tous sans le moindre appelant :

| Export | Fichier | Ce que le commentaire prétendait |
|---|---|---|
| `getBagBonus`, `getContainerBonus` | `vanta_xp/server.lua` | « utilisés par `pvp_inventory` » |
| `GetStashBonus` | `pvp_vcoins/server/server.lua` | « appelé par `pvp_inventory:server` » |
| `GetSubscriptionTier`, `GetVCoins`, `HasDiamond`, `HasGoldOrDiamond` | `pvp_vcoins/client/client.lua` | « appelé par `pvp_outposts` » |

Les trois commentaires étaient faux. Le bonus circule par *push* (`vanta_xp` et
`pvp_vcoins` appellent `setBagBonus`/`setContainerBonus`), et le seul export de
`pvp_vcoins` consommé de l'extérieur est `GetTier`. Les quatre exports client étaient de
surcroît un contrôle d'abonnement côté client — qui ne prouve rien. Un commentaire
explicite a été laissé à chaque emplacement pour éviter qu'ils soient réintroduits.

### ~~🟡 `setBagBonus` — même faille latente que l'ancien `setContainerBonus`~~ ✅ CORRIGÉ (03/09/2026)

`setBagBonus` stockait un bonus unique par identifiant, en écrasement pur. Aligné sur
`setContainerBonus` : stockage par source, somme à la lecture. `vanta_xp` passe désormais
`'prestige'` en 3ᵉ argument. Le paramètre est optionnel (`'default'` si omis), donc un
appelant à deux arguments continue de fonctionner.

Aucune source concurrente n'existait encore — c'est exactement la situation du bonus de
conteneur avant l'arrivée de `pvp_vcoins` puis `pvp_crew`, où l'écrasement était devenu
silencieux. Corrigé par avance plutôt qu'après le bug.

### ~~🟡 `spooner/` est gitignoré — le correctif de permissions n'est pas dans le dépôt~~ ✅ CORRIGÉ (03/09/2026)

Le problème était **pire que décrit** : la procédure de restauration d'`audit-initial.md`
(annexe A) fait re-cloner le dépôt amont et concluait « le fichier `permissions.cfg` fait
partie du dépôt d'origine » — or ce fichier-là est précisément celui qui ouvre
`spooner.*` à `builtin.everyone`. La procédure officielle de restauration réintroduisait
donc la faille à chaque fois.

Corrigé : les permissions VANTA vivent maintenant dans **`vanta_spooner_permissions.cfg`
à la racine du dépôt**, versionné (`add_ace group.admin spooner allow` +
`add_ace builtin.everyone spooner deny`). `server.cfg` l'exécute **à la place** du
`permissions.cfg` amont, qui ne doit plus jamais être `exec`'d — les deux jeux de règles
entreraient en concurrence. L'annexe A d'`audit-initial.md` a été corrigée en
conséquence.

Reste ouvert : vérifier que les comptes qui doivent l'être sont bien dans `group.admin`
(`add_principal` dans `server.cfg`) — c'est le point D2 de `ROADMAP.md`, et sans ça plus
personne n'a accès à spooner.

### ~~🟡 `AGENTS.md` a divergé de `CLAUDE.md`~~ ✅ CORRIGÉ (03/09/2026)

389 lignes contre 618, ignorant `pvp_combat` et tout ce qui a suivi le 23/08. Réduit à un
pointeur de 24 lignes vers `CLAUDE.md`, `STATUS.md`, `ROADMAP.md` et `audit-initial.md`.
Un second document d'architecture entretenu à la main finira toujours par mentir.

### 🟠 Le design system n'est pas appliqué partout — contrairement à ce qu'affirme `CLAUDE.md`

*Trouvé le 03/09 en vérifiant les dépendances NUI. Non corrigé.*

`CLAUDE.md` affirme « **Toutes les resources** importent la feuille de style via
`nui://vanta_ui/html/vanta.css` », « Toutes les resources sont sur v2 » et « Font : Inter
— **toutes** les UIs ». Le relevé fichier par fichier dit autre chose :

| NUI | `vanta.css` | Polices chargées |
|---|---|---|
| `pvp_crew/html/crew.html` | ❌ | Bebas Neue + Rajdhani |
| `pvp_outposts/html/shop.html` | ❌ | Bebas Neue + Rajdhani |
| `pvp_outposts/html/teleport.html` | ❌ | — |
| `vanta_xp/html/index.html` | ❌ | Rajdhani |
| `vanta_loading/html/index.html` | ❌ | — |
| `pvp_hud/html/index_classic.html` | ❌ | Bebas Neue + Rajdhani |
| `pvp_inventory/html/index.html` | ✅ | Inter **+ Big Shoulders Display** |

Six NUI actives sont hors du design system, dont **la boutique et l'armurerie**
(`shop.html`) et **le menu de crew** — deux écrans que le joueur voit constamment. Trois
familles de polices concurrentes (Inter, Bebas Neue, Rajdhani, Big Shoulders) circulent
alors que la règle est « Inter partout ».

⚠️ **Lien direct avec la décision d'abandonner la v2.1 « Monolithe ».** La branche
`claude/vanta-visual-identity-gma5lm` touchait précisément ces fichiers —
`pvp_crew/crew.css`, `pvp_outposts/shop.css` et `teleport.css`, `vanta_xp/style.css`,
`vanta_loading/style.css`. C'était le correctif de cet écart. L'abandonner laisse l'écart
entier : il faudra soit refaire ce travail, soit assumer que « design system v2 partout »
est faux et corriger `CLAUDE.md`. À trancher (ROADMAP C5).

### ~~🟡 Table `characters` documentée, jamais créée~~ ✅ CORRIGÉ (03/09/2026)

`CLAUDE.md` → « Base de données » listait une table `characters` (« prénom, nom, date de
naissance, sexe, taille »). Aucune resource ne la crée, et la section `pvp_character` du
même fichier disait l'inverse. Vestige d'`esx_identity`, supprimé le 21/08. L'entrée a été
retirée de `CLAUDE.md` et remplacée par une note explicite.

### 🟡 Resources ESX résiduelles absentes de l'architecture documentée

*Non corrigé — suppression de fichiers, à décider.*

`resources/[menu]/` contient `esx_hud`, `esx_menu_default`, `esx_menu_dialog-main`,
`esx_menu_list-main` et `async`, aucun ne figurant dans l'arborescence de `CLAUDE.md`.
Les trois `esx_menu_*` et `async` sont `ensure`d et `pvp_outposts` déclare bien
`esx_menu_default` en dépendance : ils sont **actifs**, juste non documentés.
`esx_hud` est désactivé dans `server.cfg` (`# ensure esx_hud`) mais ses 114 fichiers
restent sur le disque, et son `ui.html` charge Montserrat.

À trancher : documenter les quatre resources actives dans `CLAUDE.md`, et supprimer
`esx_hud` ou dire pourquoi on le garde. Supprimer 114 fichiers n'a pas été fait sans
décision explicite.

### 🟡 `vanta.css` dépend de Google Fonts par le réseau

`resources/[menu]/vanta_ui/html/vanta.css:11` fait
`@import url('https://fonts.googleapis.com/css2?family=Inter...')`. Toutes les NUI du
serveur en dépendent. Un joueur hors ligne côté DNS, derrière un filtrage, ou simplement
lent au premier chargement voit l'UI se rendre en police de repli. Pour un serveur public :
embarquer les `.woff2` dans `vanta_ui` et déclarer un `@font-face` local.

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

**Mise à jour du 03/09/2026.** La section précédente affirmait que *rien* n'avait été
validé manette en main. C'est faux depuis la session de test multijoueur Cloudfive du
02/09 : `ROADMAP.md` → A1/A3/A5 y sont cochés point par point. Trois états à distinguer
maintenant, et ne plus les confondre.

### ✅ Exercé en jeu lors de la session Cloudfive (02/09/2026)

Parcours joueur complet (A1) : création de personnage freemode **et** ped spécial,
apparition, inventaire/hotbar/coffres (sac, protégé, avant-poste), kill de zombie → loot au
corps → item en inventaire, achat/vente armurerie + customisation d'arme, achat/vente/spawn
véhicule au garage, marché joueur, mort → death bag → réapparition à l'avant-poste le plus
proche, téléportation entre avant-postes. Plus A3 (`pvp_combat` : les 5 points, dont la
déconnexion en plein combat) et A5 (`pvp_character` en profondeur, restriction de ped
Gold/Diamond incluse).

### 🟠 Correctifs appliqués après cette session, **jamais rejoués**

Les 13 correctifs du 02/09 (voir « Bugs corrigés » ci-dessus) et le fix de boucle infinie
`vanta_ui` du 01/09 ont été écrits **après** la session, donc validés par personne. Tant
qu'une seconde passe A1 n'a pas été jouée de bout en bout, l'absence de régression n'est
pas établie — c'est le point A2 de la roadmap. À vérifier en priorité : les voix/râles de
zombie (`ALIENS`), le dosage de `VEHICLE_SPAWN_BOOST`, la sortie de véhicule contre un mur,
et le double clic molette de suppression d'item.

### ⬜ Jamais exercé du tout

- [ ] `pvp_drops` — avion, trajectoire en flèches sur minimap, parachute, atterrissage par
      raycast, fusées éclairantes, ouverture de caisse, failover du contrôleur, expiration
      à 1 h, `/droptest`
- [ ] `pvp_crew` — 4 crews en base mais 0 membre. Contrat quotidien (multi-participants,
      complétion, crédit de trésorerie), boutique (achat, anti-cumul, expiration,
      application/retrait du bonus de coffre), non-régression du cumul
      prestige + abonnement + crew
- [ ] `pvp_redzones` — rotation horaire, loot ×2 effectif, kills comptés en redzone
- [ ] `pvp_killfeed` — affichage haut-droite, couleur redzone, sanity-check 2000 m sur un
      tir sniper réel
- [ ] `pvp_vcoins` — abonnements Gold/Diamond, marché VCoins entre joueurs, bonus de stash
- [ ] `pvp_admin` — panel F7, noclip, spectate, `/givexp` après le relais du 30/08
- [ ] `vanta_xp` — `/xp`, montée de niveau, prestige, bonus de capacité (et la collision
      `/xp` signalée dans « Bugs actifs »)

Session de test suggérée pour A2 : rejouer A1 à l'identique, puis enchaîner sur un drop
complet à 2 joueurs et un crew à 2 membres avec contrat quotidien.

---

## Écarts de documentation connus, non résolus

### ~~`pvp_market:notify` — migration partielle vers `vanta_ui`~~ ✅ RÉSOLU (30/08/2026)

Migration terminée : 90 notifications déplacées, plus aucune occurrence de
`pvp_market:notify` dans le code exécutable (2 restantes, dans des commentaires
historiques de `pvp_drops/server/server.lua` et `vanta_ui/client/notify.lua`).
`vanta_ui/html/notify.html` est le seul système de notification du projet. Détail complet
dans `ROADMAP.md` → B1. **Cette section est restée listée comme « non résolue » pendant
4 jours après sa résolution** — d'où la vérification systématique ajoutée en tête de
fichier.

### Quatre listes d'items concurrentes, toujours sans source unique

Aggravation de l'écart déjà noté : ce ne sont pas deux listes mais **quatre**, aucune
n'étant dérivée d'une autre.

| Liste | Fichier | Rôle | Taille |
|---|---|---|---|
| `Config.ShopItems` | `pvp_outposts/config.lua:271` | Boutique générale (consommables) | — |
| `Config.WeaponShopItems` | `pvp_outposts/config.lua:288` | Armurerie (achat/vente) | 29 entrées |
| `Config.AllItemPrices` | `pvp_outposts/config.lua:322` | Prix de revente de tout item | — |
| `WEAPONS` | `pvp_inventory/server/server.lua:878` | Whitelist anti-triche (plus large, MK2 inclus) | — |
| `Config.LootTable` | `pvp_zombies/config.lua` | Loot pondéré zombies (armes + véhicules) | 66 entrées |
| `Config.Vehicles` / `Config.MarketOnlyVehicles` | `pvp_garage/config.lua` | Catalogue véhicule + exclusions | ~35 |

Le journal de session du 30/08 dans `ROADMAP.md` note « B2 fait également, création d'une
resource dédiée à l'organisation des items ». **Cette resource n'existe pas** : aucun
fichier ni dossier de catalogue partagé dans `resources/[menu]/`. B2 est donc à reprendre
de zéro, et son entrée de journal est à corriger.

### `pvp_drops` — loot annoncé « légendaire », majoritairement épic

`Config.LootTable` pondère ~86 % d'épic pour ~14 % de légendaire. Les libellés en jeu ont
été neutralisés le 24/08/2026 (« DROP DE RAVITAILLEMENT », plus de mention de rareté),
mais **la table de loot elle-même n'a pas été rééquilibrée** — à trancher : soit augmenter
la part de légendaire, soit assumer le ratio actuel.

---

## Roadmap

**La roadmap vit désormais dans `ROADMAP.md`** — phases, check-list Go/No-Go, journal de
session. Cette section était une copie divergente : elle listait encore la migration des
notifications comme à faire alors qu'elle est terminée depuis le 30/08.

Rappel du principe directeur, inchangé : *rendre toutes les features existantes
fonctionnelles et cohérentes avant d'en ajouter de nouvelles.*
