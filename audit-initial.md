# Audit initial — Serveur VANTA

**Date de l'audit :** 21 août 2026
**État de départ :** serveur en pause depuis plusieurs mois, non retesté depuis l'arrêt
**Périmètre initial :** lecture seule + un démarrage de contrôle.
**Mis à jour :** après vos retours, `CLAUDE.md`/`AGENTS.md` ont été corrigés et deux bugs
réels ont été traités — détail complet en Annexe C. Ce n'est plus un audit à lecture seule.
**Point de retour git :** commit `d64363c` — les changements de l'Annexe C ne sont pas encore commités.

---

## 1. Résumé — l'essentiel en 10 lignes

**Le serveur démarre. Complètement.** C'était déjà vrai à l'audit initial, et ça l'est
resté après les corrections.

Les 34 resources demandées dans `server.cfg` se chargent toutes, la clé de licence FiveM est toujours valide, la base de données répond, et le serveur s'enregistre auprès de Cfx.re.

Depuis l'audit initial : **la documentation (`CLAUDE.md`/`AGENTS.md`) a été entièrement
remise à niveau** (§8, Annexe C) — les 10 écarts relevés sont corrigés. **`pvp_hud` a été
réactivé** avec ses restrictions de combat, et son vrai bug (un native serveur cassé qui
plantait en boucle toutes les 30 secondes) a été trouvé et corrigé (Annexe C.3).
`esx_identity` a été supprimé. Un nouveau bug a été découvert en chemin — une collision de
commande `/givexp` qui rend la commande admin inopérante — documenté mais **pas corrigé**,
en attente de votre décision (§9).

Le sujet qui reste ouvert : **rien de ce qui se joue en partie n'a encore été testé** en
jeu (combat, loot, inventaire, crew, killfeed). Le démarrage prouve que le code se charge,
pas qu'il fonctionne.

**Verdict : la base est saine et la documentation est à jour. Le chantier restant est la
validation en jeu et la décision sur `/givexp`.**

---

## 2. ✅ Ce qui démarre sans erreur

### Résultat brut du démarrage

| Indicateur | Résultat |
|---|---|
| Resources trouvées | 57 |
| Resources demandées (`ensure`) | 34 |
| Resources effectivement démarrées | **34 / 34** |
| Erreurs applicatives | **1** (non bloquante) |
| Avertissements | 2 |
| Clé de licence FiveM | ✅ **Valide** — `Server license key authentication succeeded` |
| Base de données | ✅ Connectée (MariaDB 10.4.32) |
| Enregistrement Cfx.re | ✅ `Authenticated with cfx.re Nucleus` |

> **Note :** un premier relevé réseau m'avait laissé croire que MySQL était éteint. C'était une erreur de mesure de mon environnement : MariaDB tournait déjà. Rien n'a eu besoin d'être démarré.

### Les 15 resources maison actives — toutes chargées sans erreur

`vanta_ui` · `pvp_vcoins` · `pvp_garage` · `pvp_outposts` · `pvp_spawn` · `pvp_zombies` · `pvp_market` · `pvp_inventory` · `pvp_crew` · `pvp_redzones` · `pvp_killfeed` · `vanta_xp` · `pvp_drops` · `pvp_admin` · (+ `pvp_character`, voir §3)

Messages de bonne santé relevés dans la console :

```
[pvp_market]    Tables SQL créées/vérifiées.
[pvp_inventory] 8 consommables enregistrés dans items.
[pvp_inventory] 34 armes enregistrées dans items.
[vanta_xp]      Table vanta_xp prête.
[pvp_vcoins]    Migrations DB OK
```

### La base de données est en bon état

**30 tables** présentes et cohérentes. Point rassurant : **8 resources créent et migrent leurs tables toutes seules au démarrage** (`CREATE TABLE IF NOT EXISTS` + vérification de colonnes).

Concrètement : **si vous perdiez votre base de données, le serveur la reconstruirait seul au démarrage suivant.** Vous perdriez les données des joueurs, mais pas la structure. C'est une sécurité importante, et elle fonctionne.

Données actuellement présentes : 743 items enregistrés, 743 lignes d'inventaire, 4 crews, 1 joueur de test, 62 lignes de logs admin.

### L'ordre de chargement est correct

Toutes les dépendances déclarées sont chargées **avant** les resources qui en dépendent :

```
vanta_ui          --->  pvp_inventory, pvp_admin
esx_menu_default  --->  pvp_outposts
pvp_outposts      --->  pvp_spawn, pvp_market, pvp_zombies, pvp_redzones, pvp_garage
pvp_inventory     --->  vanta_xp
```

Aucune inversion détectée. Les commentaires laissés dans `server.cfg` (« avant pvp_spawn », « avant pvp_outposts ») sont respectés.

### Les échanges entre resources sont sains

Les resources se parlent via 31 « exports » (des fonctions qu'une resource met à disposition des autres). J'ai vérifié le piège documenté dans `CLAUDE.md` — **un export serveur appelé depuis le client échoue sans le moindre message d'erreur**, ce qui est très difficile à diagnostiquer.

**Résultat : aucun appel mal orienté.** Les 25 appels croisés respectent tous la frontière client/serveur. Un cas limite mérite même d'être signalé comme bien conçu :

`pvp_garage/config.lua` appelle un export **client** de `pvp_outposts`. Ce fichier tournant aussi côté serveur, l'appel y échoue — mais il est protégé par un `pcall` avec une liste de secours codée en dur. Le comportement dégrade proprement au lieu de casser.

---

## 3. ❌ Ce qui échoue

### 3.1 — `pvp_character` : fichier ESX introuvable · Gravité : **faible**

**Message console exact :**

```
[c-scripting-core] Creating script environments for pvp_character
[c-scripting-core] Failed to load script @es_extended/imports.lua.
[c-scripting-core] Failed to load script @es_extended/imports.lua.
```

**En clair :** `pvp_character` (votre écran de création de personnage) réclame au démarrage un fichier nommé `imports.lua` fourni par ESX. Ce fichier **n'existe pas** dans votre version d'ESX. L'erreur apparaît deux fois car le fichier est demandé côté joueur *et* côté serveur.

**Pourquoi :** `imports.lua` appartient à **ESX Legacy** (version 1.9 et suivantes). Vous êtes en **ESX 1.1.0**, une version antérieure qui ne l'a jamais eu. La resource a vraisemblablement été écrite en suivant un tutoriel basé sur ESX Legacy.

**Pourquoi ce n'est pas grave :** j'ai vérifié le code. `pvp_character` ne se sert pas réellement de ce fichier — il récupère ESX par l'ancienne méthode, qui fonctionne parfaitement sur votre version :

```lua
local ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
```

La resource démarre (`Started resource pvp_character`) et devrait fonctionner. L'erreur est **bruyante mais inoffensive** : elle pollue votre console et vous fera perdre du temps à chaque futur diagnostic en vous faisant croire à un problème.

**Correction (non appliquée) :** supprimer les deux lignes `'@es_extended/imports.lua'` du fichier `resources/[menu]/pvp_character/fxmanifest.lua`. Deux lignes. À valider en jeu.

### 3.2 — `esx_identity` : manifest au format obsolète · Gravité : **cosmétique**

```
[resources:esx_identi] Warning: esx_identity has an outdated manifest
                       (__resource.lua instead of fxmanifest.lua)
```

`esx_identity` utilise `__resource.lua`, un format abandonné par FiveM. **La resource est désactivée** dans `server.cfg` (remplacée par `pvp_character`), mais FiveM scanne quand même tous les dossiers présents et signale le problème.

Aucun impact. Disparaîtra le jour où le dossier sera supprimé.

### 3.3 — Identité du serveur non renseignée · Gravité : **moyenne (visibilité publique)**

```
[citizen-server-impl] -- [server notice: hostname_rework]
[citizen-server-impl] You don't have sv_projectName/sv_projectDesc set.
```

Trois champs sont **vides** dans `server.cfg` :

| Champ | Valeur actuelle | Rôle |
|---|---|---|
| `sv_hostname` | `""` | Nom affiché dans la liste des serveurs |
| `sv_projectName` | `""` | Nom court du projet |
| `sv_projectDesc` | `""` | Description |

**Conséquence concrète :** en l'état, votre serveur apparaîtrait **sans nom** dans la liste publique FiveM. Sans importance en test local, **bloquant pour un lancement public**.

Les deux bannières (`banner_detail.png`, `banner_connecting.png`) sont également prêtes sur le disque mais leurs lignes de configuration sont commentées — elles attendent d'être hébergées sur une URL publique.

### 3.4 — Serveur de mise à jour EssentialMode injoignable · Gravité : **nulle**

```
[EssentialMode] Updater version: UPDATER UNAVAILABLE
[EssentialMode] This could be your internet connection or that the update server is not
                running. This won't impact the server
```

EssentialMode interroge `api.kanersps.pw`, un service tiers **arrêté depuis des années**. Le message le dit lui-même : aucun impact. C'est un symptôme d'ancienneté (voir §6), pas une panne.

---

## 4. ⚠️ Ce qui est incertain

Cette section est **la plus importante du rapport**. Tout ce qui suit se charge sans erreur — donc n'apparaît nulle part dans la console — mais n'a **jamais été prouvé fonctionnel**.

### 4.1 — Aucun test en jeu n'a été possible

Un démarrage vérifie que le code se **charge**. Il ne vérifie pas qu'il **marche**. Tout ce qui suit nécessite un joueur connecté :

| Système | Statut réel |
|---|---|
| `pvp_killfeed` | Documenté « **créé, non testé** ». Toujours pas testé. |
| `pvp_crew` | Documenté « fonctionnel, à approfondir ». 4 crews en base, mais 0 membre — donc jamais réellement exercé. |
| `pvp_drops` | Avion, parachute, ouverture de caisse : aucune validation possible sans joueur. |
| `pvp_redzones` | Rotation horaire, loot ×2 : non vérifiable à froid. |
| `pvp_zombies` | Spawn, IA, loot pondéré : non vérifiable à froid. |
| `pvp_character` | Démarre malgré l'erreur §3.1, mais l'écran n'a jamais été affiché. |
| `pvp_inventory` | 217 fichiers, le plus gros système du serveur. Non testé. |

**Ce n'est pas une liste de pannes** — c'est une liste d'inconnues. Certains marchent probablement très bien. Aucun moyen de le savoir sans se connecter.

### 4.2 — ~~Le mapping a disparu~~ · **Résolu : décision assumée**

*Mis à jour après votre retour.* `CLAUDE.md` documentait un dossier `resources/[maps]`
(`base_v15`, `total_apocalypse`) absent du disque. **Ce n'est pas une perte** : vous l'avez
confirmé — mapping expérimenté puis retiré volontairement, à reprendre plus tard.

La documentation a été corrigée en conséquence (voir §8 et Annexe C) : `CLAUDE.md` ne
mentionne plus `[maps]`, et l'avant-poste `murietta_base` est redécrit comme tournant sur la
carte GTA V standard, sans mapping custom.

### 4.3 — ~~`pvp_hud` désactivé : les restrictions de combat sont inactives~~ · **Résolu**

*Mis à jour après votre retour.* Vous avez confirmé vouloir les restrictions de combat
(coups de crosse et tir en véhicule désactivés). `pvp_hud` a été **réactivé** dans
`server.cfg`.

En creusant pour l'activer proprement, j'ai trouvé la cause probable du « HUD buggé » —
voir Annexe C pour le détail complet du bug et de sa correction.

### 4.4 — Deux systèmes d'XP coexistent

Deux mécaniques d'expérience tournent en parallèle sur des tables différentes :

| Système | Table | Écrit par |
|---|---|---|
| Stats joueur | `pvp_player_stats.xp` | `pvp_admin` (commande `/givexp`) |
| VANTA XP | `vanta_xp.xp` | `vanta_xp` |

Or `server.cfg` décrit `vanta_xp` comme « Système XP / Niveaux / Prestige — **source unique** ».

**Il n'y a donc pas de source unique.** Conséquence probable : la commande admin `/givexp` crédite une table que le système de progression ne lit pas. À vérifier en jeu — c'est le genre d'incohérence qui donne l'impression que « l'XP ne marche pas » sans aucune erreur.

### 4.5 — Un gamemode et une map par défaut se lancent tout seuls

Quatre resources démarrent **sans être demandées** dans `server.cfg` :

```
basic-gamemode     fivem-map-hipster     webpack     yarn
```

`webpack` et `yarn` sont des outils de compilation, normaux. En revanche `basic-gamemode` (gametype « Freeroam ») et `fivem-map-hipster` sont les **exemples livrés par défaut avec FiveM**, chargés automatiquement par `mapmanager`. Ils fournissent leurs propres points d'apparition.

`pvp_spawn` reprend la main (`setAutoSpawnCallback`) et gagne vraisemblablement, mais **deux systèmes de spawn se disputent le contrôle**. À surveiller si des joueurs apparaissent un jour à un endroit incohérent.

### 4.6 — La base contient des données de test résiduelles

`users` : 1 ligne · `characters` : 1 ligne · `pvp_crews` : **4 crews pour 0 membre** · `pvp_market_listings` : 2 annonces · `pvp_admin_logs` : 62 entrées.

Vestiges de vos tests d'avant l'arrêt. Sans gravité, mais à nettoyer avant un lancement public pour éviter de fausser les classements.

### 4.7 — MySQL s'est arrêté brutalement la dernière fois

Le journal MariaDB montre une `crash recovery` au dernier démarrage, et un fichier de dump (`mysqld.dmp`, 195 Ko) daté du **15 avril 2026** — le jour de votre dernière session.

La récupération s'est bien passée et les données sont intactes. Mais le serveur MySQL ne s'est pas arrêté proprement. Probablement un arrêt brutal de la machine, sans lien avec FiveM. Aucune action nécessaire, simple traçabilité.

---

## 5. Cartographie du serveur

### 5.1 — Framework identifié

| Composant | Version | Rôle |
|---|---|---|
| **ESX (`es_extended`)** | **1.1.0** | Framework principal : joueurs, argent, inventaire de base |
| `essentialmode` | 6.4.2 | Couche historique sous ESX (permissions, groupes) |
| `mysql-async` | 3.3.2 | Passerelle vers la base de données |
| MariaDB | 10.4.32 (XAMPP) | Base `fivemserver` |
| FXServer | binaire du 12 février 2026 | Serveur FiveM (numéro de build non exposé par le binaire) |

> **En clair :** vous êtes sur **ESX 1.1.0**, une version historique. L'écosystème FiveM est passé depuis à **ESX Legacy (1.9+)**. Voir §6.

### 5.2 — Les 17 resources maison

**15 actives :**

| Resource | Rôle | Dépend de | Tables |
|---|---|---|---|
| `vanta_ui` | Design system partagé (CSS v2) — pas de logique | — | — |
| `pvp_vcoins` | Monnaie premium, abonnements Gold/Diamond | mysql-async | `vcoin_market`, `vcoin_pending_bank`, `vcoin_tebex_transactions` |
| `pvp_character` | Création de personnage (pseudo + genre) | es_extended, pvp_vcoins | `characters` |
| `pvp_garage` | Personnalisation véhicule + concessionnaire | pvp_outposts | `pvp_vehicle_customs` |
| `pvp_outposts` | Avant-postes, zones safe, PNJ, custom armes | es_extended, esx_menu_default | `pvp_weapon_customs`, `pvp_outpost_stash` |
| `pvp_spawn` | Apparition aux avant-postes | spawnmanager, pvp_outposts | — |
| `pvp_zombies` | Spawn, IA et loot des zombies | pvp_outposts, pvp_redzones | — |
| `pvp_market` | Marché joueur à joueur | pvp_outposts, pvp_inventory | `pvp_market_listings`, `pvp_market_pending_payments` |
| `pvp_inventory` | Inventaire, coffres, profil, badges (**217 fichiers**) | vanta_ui, vanta_xp, pvp_outposts | `pvp_player_stash`, `pvp_player_stats` |
| `pvp_crew` | Crews, tags, coffre partagé | es_extended | 7 tables `pvp_crew_*` |
| `pvp_redzones` | 3 zones PVP rotatives, loot ×2 | pvp_outposts, pvp_crew | `pvp_redzone_control_log` |
| `pvp_killfeed` | Killfeed temps réel | es_extended, pvp_redzones | — |
| `vanta_xp` | XP, niveaux, prestige | pvp_inventory | `vanta_xp` |
| `pvp_drops` | Caisses larguées par avion | es_extended, pvp_inventory | — |
| `pvp_admin` | Panel admin F7, noclip, spectate | vanta_ui, pvp_redzones | `pvp_admin_bans`, `pvp_admin_logs` |

**2 désactivées :**

| Resource | Raison | Remarque |
|---|---|---|
| `pvp_hud` | « HUD buggé, pas nécessaire » | ⚠️ Emporte aussi les restrictions de combat — voir §4.3 |
| `vanta_loading` | « désactivé temporairement » | Écran de chargement. Absent de `CLAUDE.md`. |

### 5.3 — Carte des dépendances

```
                       vanta_ui  (CSS partagé, aucune logique)
                           |
        +------------------+------------------+
        v                  v                  v
   pvp_inventory <---- pvp_admin        (pvp_hud, désactivé)
     |     ^                |
     |     +---- vanta_xp   |
     |                      v
     |                pvp_redzones ----> pvp_killfeed
     |                    ^   |
     v                    |   v
   pvp_outposts ----------+  pvp_zombies
     |   ^
     |   +--- esx_menu_default
     +--> pvp_spawn ---> spawnmanager
     +--> pvp_market
     +--> pvp_garage

   pvp_vcoins ---> pvp_character
   pvp_drops  ---> pvp_inventory
```

**Point de fragilité :** `pvp_outposts` et `pvp_inventory` sont les deux **piliers**. Une panne sur l'un de ces deux fait tomber la moitié du serveur. Toute modification future mérite une prudence particulière.

### 5.4 — Dépendances externes

| Resource | Origine | Licence | Statut |
|---|---|---|---|
| `es_extended` 1.1.0 | ESX Framework | GPLv3 | ⚠️ Version historique |
| `essentialmode` 6.4.2, `es_ui`, `es_admin2`, `esplugin_mysql` | Kanersps | AGPLv3 | ⚠️ Non maintenu |
| `esx_addonaccount`, `esx_identity`, `esx_society` | ESX Framework | GPLv3 | `esx_identity` / `esx_society` désactivés |
| `mysql-async` 3.3.2 | brouznouf | MIT | ⚠️ Non maintenu |
| `async` | — | MIT | OK |
| `esx_menu_default` / `_dialog` / `_list` | ESX Framework | GPLv3 | OK |
| `esx_hud` | ESX Framework | GPLv3 | Désactivé |
| `spooner` | kibukj | Open source | OK (éditeur de map) |
| `resources/[base]/*` | `citizenfx/cfx-server-data` | Officiel Cfx.re | OK |

**Aucun script payant, aucun script sous licence commerciale, aucune protection escrow.** Recherche effectuée sur : fichiers `.fxap`, mentions `keymaster`, `tebex`, `escrow_ignore`. Résultat : zéro. **Vous êtes libre de republier l'ensemble.**

Nuance juridique : GPLv3 et AGPLv3 sont des licences « copyleft » — si vous redistribuez **publiquement**, vous devez transmettre les mêmes libertés (code source ouvert). Votre dépôt étant **privé**, aucune obligation ne se déclenche aujourd'hui.

---

## 6. Dette technique

Classée par **coût d'un report**, pas par difficulté.

### 6.1 — `mysql-async` n'est plus maintenu · Impact : **élevé** · Effort : **important**

**Utilisé par 11 de vos 15 resources actives.** Le projet n'est plus développé depuis des années ; tout l'écosystème FiveM est passé à **`oxmysql`**.

*Risque :* aucun aujourd'hui — ça marche. Mais aucun correctif ne viendra jamais, et toute resource moderne que vous voudrez installer attendra `oxmysql`.

*À savoir :* migrer touche 11 resources et toutes les requêtes SQL. **C'est un chantier en soi, à ne pas mélanger avec autre chose.**

### 6.2 — ESX 1.1.0 contre ESX Legacy · Impact : **élevé** · Effort : **très important**

Vous êtes sur une version antérieure à la refonte « Legacy » (1.9+). C'est déjà la cause de l'erreur §3.1.

*Risque :* la documentation et les tutoriels que vous trouverez en ligne visent Legacy. Chaque script tiers que vous voudrez ajouter demandera une adaptation.

*À savoir :* une migration vers Legacy **casserait vos 15 resources maison**, qui sont écrites pour l'API 1.1.0. À mon sens **à ne pas envisager** sauf raison impérieuse — le coût dépasse largement le bénéfice sur un serveur dont tout le code est déjà écrit.

### 6.3 — `essentialmode` est une couche héritée · Impact : **moyen** · Effort : **moyen**

`essentialmode` + `es_ui` + `es_admin2` + `esplugin_mysql` datent d'avant ESX. Sur ESX Legacy ils ne sont plus nécessaires. Sur votre ESX 1.1.0, ils le sont encore.

Ils traînent une base SQLite locale (`essentialmode.db`) et interrogent un serveur de mise à jour mort (§3.4). Vous disposez par ailleurs de votre propre `pvp_admin`, bien plus complet qu'`es_admin2`.

*Piste (à explorer, pas à appliquer) :* certains de ces composants sont peut-être retirables. À tester un par un, jamais en bloc.

### 6.4 — Démarrage ralenti par les migrations · Impact : **faible** · Effort : **faible**

À **chaque** démarrage, les resources rejouent leurs `CREATE TABLE IF NOT EXISTS` et interrogent `INFORMATION_SCHEMA` pour vérifier chaque colonne. `mysql-async` les signale comme requêtes lentes :

```
[WARNING] [pvp_outposts]  [771ms]  CREATE TABLE IF NOT EXISTS pvp_weapon_customs
[WARNING] [pvp_market]    [644ms]  CREATE TABLE IF NOT EXISTS pvp_market_pending_payments
[WARNING] [pvp_redzones]  [493ms]  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
```

Une trentaine de requêtes de 300 à 770 ms — plusieurs secondes ajoutées au démarrage.

**Ce n'est pas un bug** : c'est le prix de l'auto-création de schéma qui vous protège (§2). Le compromis est bon. Signalé pour que ces `[WARNING]` ne vous inquiètent pas : ils sont normaux.

### 6.5 — `esx_identity` au format obsolète · Impact : **cosmétique** · Effort : **trivial**

Voir §3.2. Supprimer le dossier ferait disparaître le seul avertissement du démarrage. À ne faire qu'une fois `pvp_character` confirmé fonctionnel en jeu.

---

## 7. Sécurité

### 7.1 — Deux clés en clair dans l'historique git · **Vous avez choisi de ne pas agir**

`server.cfg` est versionné et **poussé sur GitHub** avec :

| Secret | Ligne | Risque si divulgué |
|---|---|---|
| `sv_licenseKey` | 121 | Un tiers peut lancer un serveur sous **votre** licence. Sanction possible : révocation de votre clé par Cfx.re. |
| `steam_webApiKey` | 117 | Quota d'API consommé en votre nom, révocable par Valve. |

**État actuel :** dépôt `ReWarDs762/Vanta`, **privé**. L'exposition se limite aux personnes ayant accès au dépôt.

**Vous avez demandé de ne rien modifier — je n'ai rien modifié.** Le commit `d64363c` de cet audit contient donc toujours ces clés, comme le commit initial.

**Si vous changez d'avis**, la marche à suivre — dans cet ordre :

1. **Régénérer les deux clés d'abord** (seul vous pouvez le faire) :
   - Licence FiveM → https://keymaster.fivem.net (révoquer, recréer)
   - Clé Steam → https://steamcommunity.com/dev/apikey (révoquer, recréer)
2. **Ensuite seulement**, sortir `server.cfg` du suivi git et créer un `server.cfg.example` sans secrets.
3. Purger l'historique et forcer la mise à jour sur GitHub.

> **L'ordre compte.** Nettoyer l'historique avant de régénérer les clés ne sert à rien : ce qui a été poussé peut déjà avoir été copié. **La régénération est la seule action qui neutralise réellement le risque** ; le nettoyage git n'est que du rangement.

### 7.2 — Ce qui est déjà bien configuré

| Réglage | Valeur | Effet |
|---|---|---|
| `sv_scriptHookAllowed` | `0` | ✅ Bloque les menus de triche |
| `rcon_password` | commenté | ✅ Pas d'administration distante exposée |
| `sv_requestParanoia` | `3` | ✅ Protection contre les attaques applicatives |
| `sv_endpointprivacy` | `true` | ✅ Masque les IP des joueurs |
| `sv_authMinTrust` | `4` | ✅ Niveau de confiance maximal exigé |
| Certificats TLS | `*.crt` / `*.key` exclus de git | ✅ Correctement protégés |

**Le durcissement réseau est sérieux.** Le seul angle mort est celui du §7.1.

---

## 8. Écarts entre `CLAUDE.md` et la réalité du code · **Corrigés**

*Mis à jour après votre retour — les 10 écarts ci-dessous ont tous été corrigés dans
`CLAUDE.md` (et répliqués dans `AGENTS.md`, fichier identique). Table conservée telle
qu'observée initialement, à titre de trace.*

| # | `CLAUDE.md` affirmait | Réalité constatée | Statut |
|---|---|---|---|
| 1 | Colonnes `xp`, `prestige`, `active_badge`, `badges_unlocked`, `kill_streak_record` **dans la table `users`** | Faux. Ces colonnes sont dans `pvp_player_stats` (`xp`/`prestige` y sont d'ailleurs des restes morts — voir Annexe C) | ✅ Corrigé |
| 2 | Aucune mention de `pvp_character` | Resource active, remplace `esx_identity` (supprimé) | ✅ Section ajoutée |
| 3 | Aucune mention de `pvp_vcoins` | Resource active : monnaie premium, abonnements, tables `vcoin_*` | ✅ Section ajoutée |
| 4 | Aucune mention de `vanta_loading` | Resource présente, désactivée | ✅ Section ajoutée |
| 5 | `pvp_hud` porte les restrictions de combat | Était désactivé — **vous avez confirmé le vouloir actif** | ✅ Réactivé + bug corrigé (Annexe C) |
| 6 | `[maps]` : `base_v15` + `total_apocalypse` | **Retrait volontaire confirmé** (expérimenté, non concluant) | ✅ Doc retirée |
| 7 | `esx_identity` dans les resources ESX | Était désactivé | ✅ Resource supprimée, doc mise à jour |
| 8 | `vanta_xp` = « source unique » de l'XP | **Confirmé exact par vous** — mais `/givexp` (commande admin) écrit ailleurs à cause d'une collision de nom (Annexe C) | ✅ Doc corrigée, bug documenté (non corrigé) |
| 9 | Tables listées : 4 seulement | **30 tables** en base | ✅ Les 30 documentées, organisées par domaine |
| 10 | XP : +50/kill PVP, +15/zombie | Faux dans les deux cas : **+300/kill PVP, +50/zombie** (`vanta_xp/config.lua`) | ✅ Corrigé |

**Points où `CLAUDE.md` était déjà exact, non touchés :** ESX v1.1.0 ✅ · `sv_maxclients 10` ✅ · OneSync activé ✅ · liste des 5 avant-postes ✅ · pièges techniques NUI (`confirm()`, `backdrop-filter`, drag & drop CEF) ✅ · frontière client/serveur des exports ✅.

---

## 9. Recommandations

*Mis à jour après votre retour — les priorités 1 et 2 d'origine sont faites (détail en
Annexe C). Ce qui suit est la liste à jour.*

### Priorité 1 — Corriger la collision `/givexp` (nouveau, trouvé pendant la mise à jour doc)

`vanta_xp` et `pvp_admin` déclarent tous deux une commande `/givexp`. `pvp_admin` gagne
(chargé après) et écrit dans une colonne morte — **la commande admin actuelle ne fait
rien d'observable.** Détail technique en Annexe C. Décision à prendre : supprimer la
version de `pvp_admin` et faire relayer vers l'export `addXP` de `vanta_xp`, ou l'inverse.
Non corrigé — c'est un choix d'implémentation, pas une simple correction de doc.

### Priorité 2 — Valider en jeu (§4.1)

Se connecter et dérouler une session de test : création de personnage → apparition → inventaire → tuer un zombie → loot → coffre → marché → crew → mort → réapparition.

**C'est la seule façon de transformer les inconnues du §4 en faits.** Le HUD réactivé et
les restrictions de combat, en particulier, méritent d'être vues en jeu au moins une fois.

### Priorité 3 — Correctifs à faible risque restants

- Supprimer les 2 lignes `imports.lua` de `pvp_character` (§3.1) — dernière erreur console restante
- Renseigner `sv_hostname` / `sv_projectName` / `sv_projectDesc` (§3.3) — requis pour le public
- Nettoyer les données de test (§4.6) — avant lancement uniquement
- Générer un vrai secret pour `pvp_vcoins` (`TEBEX_URL_SECRET`) si l'intégration Tebex est utilisée un jour

### Priorité 4 — Chantiers de fond (à ne pas lancer maintenant)

- Migration `mysql-async` → `oxmysql` (§6.1) — projet dédié, 11 resources
- **Ne pas migrer vers ESX Legacy** (§6.2) — coût disproportionné, casserait tout votre code
- Nettoyage éventuel d'`essentialmode` (§6.3) — à explorer prudemment, un composant à la fois

### Sécurité — toujours en attente de votre décision (§7.1)

Les clés `sv_licenseKey` et `steam_webApiKey` restent en clair dans l'historique git. Vous
aviez choisi de ne rien faire lors du premier passage — inchangé depuis, aucune action prise.

---

## Annexe A — Restaurer `spooner`

`spooner` (éditeur de map en jeu) est exclu du dépôt : c'est un **dépôt git imbriqué**, que git ne saurait enregistrer que par référence — un clone récupérerait un dossier vide et `ensure spooner` échouerait.

Pour le restaurer depuis zéro :

```bash
git clone https://github.com/kibook/spooner.git "resources/[menu]/spooner"
```

```bash
git -C "resources/[menu]/spooner" checkout 4e2d100
```

Puis appliquer l'unique personnalisation locale — dans `spooner/fxmanifest.lua`, ligne 4 :

```lua
local gameName = "gta5"    -- au lieu de la valeur d'origine : ""
```

**⚠️ Ne PAS utiliser le `permissions.cfg` du dépôt d'origine.** Il ouvre tout l'arbre
`spooner.*` à `builtin.everyone` : n'importe quel joueur connecté peut alors spawner,
modifier et supprimer des entités, y compris celles des autres joueurs. Le durcissement
fait le 23/08/2026 vivait dans ce fichier, donc dans le dossier gitignoré — cette
procédure de restauration le réintroduisait donc à chaque fois.

Depuis le 03/09/2026, les permissions VANTA sont dans **`vanta_spooner_permissions.cfg`
à la racine du dépôt**, versionné, et `server.cfg` l'exécute à la place. Il n'y a donc
plus rien à faire après le clone : ne remettez simplement jamais
`exec resources/[menu]/spooner/permissions.cfg` dans `server.cfg`.

---

## Annexe B — Ce qui a changé pendant cet audit

**Fichiers modifiés — 2, aucun code métier :**

| Fichier | Changement |
|---|---|
| `.gitignore` | Complété : `node_modules/`, journaux, exception pour 5 DLL nécessaires, exclusion de `spooner` |
| `audit-initial.md` | Ce document |

**Commit `d64363c`** — point de retour complet : 549 fichiers ajoutés ou mis à jour, dépôt passé de 308 à **827 fichiers suivis**, en excluant ~142 Mo de caches de build.

Contenu ajouté par rapport au commit initial : le socle ESX complet (`[essential]`), les resources FiveM de base (`[base]`), et surtout **`pvp_character` et `pvp_vcoins` — deux resources actives qui n'avaient jamais été sauvegardées**.

> **Détail qui aurait coûté cher :** la règle `*.dll` du `.gitignore` excluait silencieusement 5 fichiers `.dll` **indispensables** au fonctionnement d'`essentialmode` (dont un chargé directement par son manifest). Une restauration depuis le dépôt aurait produit un serveur qui refuse de démarrer, sans raison apparente. Une exception explicite a été ajoutée.

**Aucune modification** de `server.cfg`, d'un `fxmanifest.lua`, d'un fichier Lua, JS, CSS ou HTML, ni du schéma de base de données. **Aucun `git push`** n'a été effectué.

---

## Annexe C — Suivi post-audit (après vos retours)

Vous avez répondu à 3 questions ouvertes du rapport (§4.2, §4.3, §8), ce qui a déclenché
des changements réels — plus qu'une simple mise à jour de doc. Détail complet ci-dessous.
**Ce commit n'a pas été fait — en attente de votre feu vert (voir fin de section).**

### C.1 — `CLAUDE.md` et `AGENTS.md` réécrits

Les 10 écarts du §8 ont été corrigés. Fichier passé de 363 à 472 lignes. Points ajoutés
qui dépassent une simple correction :

- **4 nouvelles sections** : `pvp_character`, `pvp_vcoins`, `vanta_xp`, `vanta_loading`
- **Base de données réorganisée par domaine** (Progression, Inventaire, Économie, Crew,
  Admin) au lieu des 4 tables listées à l'origine — 30 tables documentées
- **Section HUD étoffée** : elle ne décrivait que les restrictions de combat, alors que
  `pvp_hud` gère aussi la suppression des PNJ/véhicules ambiants, le niveau de recherché,
  la roue d'armes, et le dispatch — tout ça était invisible dans la doc
- `AGENTS.md` étant un doublon strict de `CLAUDE.md`, il a été resynchronisé à l'identique

### C.2 — `esx_identity` supprimé

Dossier `resources/[essential]/esx_identity/` retiré entièrement (5 fichiers : manifest,
client, server, SQL, html). Vérifié avant suppression qu'aucune resource active n'y fait
référence. La ligne correspondante dans `server.cfg` (déjà commentée) a été retirée.

### C.3 — `pvp_hud` réactivé — et son vrai bug corrigé

Vous avez choisi l'option « réactiver `pvp_hud` en entier » plutôt qu'extraire seulement
les restrictions de combat, pour récupérer aussi le nettoyage du monde ambiant (PNJ,
trafic, niveau de recherché).

**En le réactivant, j'ai trouvé la cause probable du « HUD buggé » d'origine :**
`pvp_hud/server/server.lua` appelait `SetMaxWantedLevel(0)`, un native **client
uniquement** dans FiveM. Côté serveur, cet appel plante systématiquement :

```
[script:pvp_hud] SCRIPT ERROR: @pvp_hud/server/server.lua:9:
                  attempt to call a nil value (global 'SetMaxWantedLevel')
```

Et il ne plante pas qu'une fois : le code le redéclenchait au démarrage, à **chaque
connexion joueur**, et **toutes les 30 secondes en boucle infinie** — de quoi noyer la
console sur une session un peu longue. Cette redondance était de toute façon inutile : le
client (`pvp_hud/client/client.lua`) retire déjà le niveau de recherché à chaque frame.

**Correction appliquée :** [resources/[menu]/pvp_hud/server/server.lua](resources/[menu]/pvp_hud/server/server.lua)
vidé des 3 appels cassés, remplacés par un commentaire expliquant pourquoi. Revérifié par
un redémarrage complet du serveur : **plus aucune erreur de script**, `pvp_hud` démarre
proprement.

`server.cfg` : la ligne `# ensure pvp_hud # désactivé - HUD buggé, pas nécessaire` est
devenue `ensure pvp_hud`, avec un commentaire à jour sur ce qu'elle couvre.

### C.4 — `[maps]` : rien à corriger côté code

Confirmé par vous : retrait volontaire, pas une perte. Seule la documentation a bougé
(§4.2, C.1). Aucune action sur le disque ou la base de données.

### C.5 — Bug trouvé en creusant l'XP : collision de commande `/givexp`

Non demandé, découvert en vérifiant les chiffres d'XP pour la doc. `vanta_xp/server.lua`
et `pvp_admin/server/server.lua` **déclarent chacun une commande `/givexp`** :

| Resource | Écrit dans | Chargée dans `server.cfg` |
|---|---|---|
| `vanta_xp` | `vanta_xp.xp` (la vraie table) | ligne 52 |
| `pvp_admin` | `pvp_player_stats.xp` (colonne morte) | ligne 54 — **après** |

FiveM ne garde que la dernière commande enregistrée sous un nom donné. `pvp_admin` étant
chargé après `vanta_xp`, **c'est sa version qui gagne** : aujourd'hui, `/givexp` ne fait
rien d'observable pour la progression du joueur.

**Non corrigé.** C'est un choix d'implémentation (laquelle des deux garder, ou faire
relayer l'une vers l'autre) qui vous appartient — voir §9, Priorité 1.

### C.6 — Vérification finale

Le serveur a été redémarré une dernière fois après tous les changements de code
(suppression `esx_identity`, réactivation `pvp_hud`, correctif `server.lua`) :

- **34/34 resources démarrées**, aucune régression
- **Une seule erreur restante** : `pvp_character` / `imports.lua` (§3.1, déjà connue,
  toujours pas corrigée — non demandée)
- Serveur arrêté proprement après vérification

### Fichiers modifiés dans cette annexe

| Fichier | Nature du changement |
|---|---|
| `CLAUDE.md` | Réécriture de 6 sections + 4 sections ajoutées (voir C.1) |
| `AGENTS.md` | Resynchronisé à l'identique de `CLAUDE.md` |
| `server.cfg` | Ligne `esx_identity` retirée, `pvp_hud` réactivé (2 lignes) |
| `resources/[menu]/pvp_hud/server/server.lua` | 3 appels natifs cassés retirés (C.3) |
| `resources/[essential]/esx_identity/` | **Dossier supprimé** (5 fichiers) |

**Rien de tout cela n'est commité.** Le dernier commit reste `d64363c`. Dites-moi si vous
voulez que je committe cet ensemble — je proposerai un message qui résume les deux natures
de changement (doc + correctif de bug) séparément si vous préférez deux commits plutôt qu'un.

---

*Fin du rapport.*
