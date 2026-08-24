# VANTA — Serveur FiveM Zombie Survival PVP

> **Statut actuel du projet** (bugs connus, roadmap, resources testées en jeu) : voir `STATUS.md`.

## Infos Projet
- **Nom** : VANTA
- **Type** : Serveur FiveM PVP Zombie Survival — public
- **Path** : `C:/Users/Utilisateur/Desktop/Server/Server/`
- **Framework** : ESX (es_extended v1.1.0)
- **DB** : MySQL local (`mysql://root:@127.0.0.1/fivemserver`)
- **OneSync** : activé
- **Max clients** : 10 (test local)
- **Langue** : Français (UI et code)

---

## Architecture des Resources

```
resources/
├── [base]        — Resources FiveM de base (mapmanager, spawnmanager, chat, etc.)
├── [essential]   — ESX core (es_extended, mysql-async, essentialmode, esx_addonaccount)
└── [menu]        — Resources custom PVP :
    ├── vanta_ui       — Design system partagé v2 (CSS tokens, --v-*, Inter) + notifications génériques
    ├── vanta_loading  — Écran de chargement
    ├── vanta_xp       — XP, niveaux 1-100, prestige 0-5 — source unique de progression
    ├── pvp_character  — Création de personnage (pseudo + genre), remplace esx_identity
    ├── pvp_hud        — HUD coin bas-gauche (HP, armor, arme, munitions) + restrictions combat + nettoyage du monde
    ├── pvp_inventory  — Inventaire NUI complet (sac, coffre protégé, coffre avant-poste, hotbar, profil, paramètres)
    ├── pvp_spawn      — Spawn aléatoire aux avant-postes (login = random, mort = plus proche)
    ├── pvp_outposts   — Avant-postes avec zones safe, NPCs (shop/stash), custom armes (NUI + persistance DB)
    ├── pvp_zombies    — Système zombie (spawn, IA, loot pondéré)
    ├── pvp_market     — Marché joueur (listings persistants)
    ├── pvp_drops      — Caisses de ravitaillement larguées par avion
    ├── pvp_redzones   — 3 zones rouges PVP rotatives (loot x2)
    ├── pvp_killfeed   — Killfeed haut-droite (killer/victime + couleur zone)
    ├── pvp_crew       — Système de crew (créer/rejoindre, tag visible)
    ├── pvp_garage     — Personnalisation véhicule NUI + concessionnaire
    ├── pvp_vcoins     — Monnaie premium, abonnements Gold/Diamond, marché VCoins
    ├── pvp_admin      — Outil admin complet (panel NUI F7, noclip, spectate, god, commandes)
    └── spooner        — Map editor en jeu
```

> Il n'y a pas de dossier `[maps]` : les mappings custom ont été expérimentés puis retirés
> volontairement (non concluants). Les avant-postes tournent sur la carte GTA V standard.
> À reprendre plus tard si besoin.

---

## Identité Visuelle — VANTA Design System v2

### Direction artistique
- **Esthétique** : Dark premium, minimaliste, angular — Apple Monochrome × Tactical Premium
- **PAS de** : grunge, rouille, poussière, neon, glassmorphism, rounded pills, RGB gaming
- **Mots-clés** : Flat. Angular. Monochrome. Black on black. Military precision.

### Design system partagé — `vanta_ui`
Toutes les resources importent la feuille de style via :
```html
<link rel="stylesheet" href="nui://vanta_ui/html/vanta.css">
```

**Notifications génériques.** `vanta_ui` expose aussi une pile de toasts partagée
(`ui_page 'html/notify.html'`, transparente et sans focus NUI) :
```lua
exports['vanta_ui']:notify(src, 'Message', 'success')  -- serveur, un joueur
exports['vanta_ui']:notifyAll('Message', 'info')       -- serveur, tous
exports['vanta_ui']:notify('Message', 'success')       -- client
```
Types : `success` | `error` | `warning` | `info` (booléens `true`/`false` acceptés pour
compat). Un 4ᵉ argument optionnel donne la durée en ms, un 5ᵉ un titre en surtitre.
⚠️ Migration partielle : seul `pvp_drops` l'utilise. `pvp_market`, `pvp_zombies` et
`pvp_inventory` passent encore par l'event `pvp_market:notify` — voir `STATUS.md`.
**Toutes les resources sont sur v2.** Ne jamais utiliser les anciennes variables v1 (`--bg-primary`, `--accent-silver`, etc.).

### Palette de couleurs (variables v2)
Valeurs complètes : [resources/[menu]/vanta_ui/html/vanta.css](resources/[menu]/vanta_ui/html/vanta.css).
Catégories de variables disponibles (préfixe `--v-`) : Backgrounds (`black`, `bg`,
`surface`/`surface-2`/`surface-3`, `elevated`), Borders (`separator`, `separator-bold`,
`border`, `border-hover`), Text (`text`, `text-secondary`, `text-tertiary`,
`text-disabled`), Brand (`silver`, `silver-dim`, `silver-glow`), Semantic (`danger`,
`success`, `warning`, `info`, chacune avec une variante `-dim`), Rarités (`common`,
`uncommon`, `rare`, `legendary`, chacune avec une variante `-solid`).

### Typographie
- **Font** : `Inter` (Google Fonts) — toutes les UIs
- **Titres** : weight 600, letter-spacing 0.08em, uppercase
- **Labels** : weight 500, 11-12px
- **Metadata** : weight 400, color `--v-text-secondary`

### Règles de forme
- Border-radius : MAX 4px — esthétique plate et angulaire
- Pas de gradients sur les fonds
- Pas de drop shadows (bordures uniquement)
- Bordures 1px, variables `--v-border` / `--v-border-hover`
- Animations CSS only : fadeSlideIn (translateY 6px, opacity), transitions 0.15s ease
- Pas de bounce, scale, glow pulses

---

## Systèmes Clés

### Inventaire (pvp_inventory)
- NUI HTML/CSS/JS, thème VANTA v2
- Grille items 180×100px, bordures 1px
- Slots vides : fond `--v-bg`, bordure dashed
- Tabs navigation avec icônes SVG inline (inventaire, marché, crew, classement, profil, paramètres)
- Grille unique "MON SAC" (poids limité)
- Coffre protégé personnel (persistant à la mort)
- Coffre avant-poste (pas de limite de poids, par joueur par outpost)
- Hotbar 7 slots (hover + touche 1-7 pour bind)
- Drag & drop custom (mousedown/mousemove/mouseup, pas HTML5 drag car cassé dans FiveM CEF)
- Clic droit = transfert rapide entre sac ↔ coffre (pas de menu contextuel)
- Images PNG pour armes (`html/img/weapon_pistol.png`) et véhicules (`html/img/adder.png`)
- Transparence dynamique via injection CSS `<style id="dynamic-opacity">`
- Camera lock quand inventaire ouvert (DisableControlAction sur controls 1, 2, 24, 25, 106, 140, 141, 142, 257)
- Sons désactivés (fonctions vides)
- **Sélecteur de ped (onglet Profil)** : changer de ped après la création est réservé aux
  abonnés Gold/Diamond (le choix libre unique se fait à la création, via `pvp_character`).
  Contrôle fait **côté serveur** (`server/server.lua`, event `pvp_inventory:savePedModel` —
  vérifie l'abonnement via `exports['pvp_vcoins']:GetTier` + le tier du ped demandé, jamais
  seulement côté NUI). Exporte `GetPedTier`/`IsPedInCatalog`/`IsPedCreationEligible`,
  consommés par `pvp_character` pour valider le choix fait à la création.

### Profil joueur (pvp_inventory → onglet PROFIL)
- **Carte identité** : avatar Discord, nom, identifier, badge actif, label prestige
- **Barre XP / Niveaux / Prestige** : gérée par `vanta_xp` (voir section dédiée) — pas par pvp_inventory
- **Stats** : Kills, Morts, K/D, Zombies tués total (table `pvp_player_stats`)
- **Records** : Kill streak record (suivi en mémoire serveur, persisté dans `pvp_player_stats.kill_streak_record`)
- **Classement personnel** : rang #X en kills, zombies, K/D
- **15 badges déblocables** (`pvp_player_stats.badges_unlocked`, JSON) :
  - Saison : `survivor_s1`
  - Kills PVP : `first_blood` (1), `killer_10` (10), `killer_50` (50), `predator_100` (100)
  - Zombies : `zombie_hunter` (100), `exterminator` (500), `annihilator` (1000)
  - Streak : `streak_5` (5), `unstoppable` (10)
  - Prestige : `prestige_1` à `prestige_5`
- Saison en cours : `CURRENT_SEASON = 1`

> **Piège** : `pvp_player_stats` a aussi des colonnes `xp` et `prestige` — ce sont des
> **restes de l'ancien système**, avant la création de `vanta_xp`. Elles ne pilotent plus
> rien. Bug actif lié à ces colonnes mortes : voir `STATUS.md`.

### Armes et véhicules — pas de liste unique, voir le code directement

**Munitions :** infinies sauf sniper/RPG/lance-grenades (LIMITED_AMMO). Seule munition lootable : `ammo_sniper`.

**Système véhicules :** lootables sur zombies → item dans inventaire → hotbar pour spawn → touche K pour ranger → despawn instantané

> ⚠️ Il n'existe pas une liste unique et à jour des armes/véhicules par rareté — deux
> sources différentes coexistent selon le besoin, et aucune n'est exhaustive à elle seule :
> - **Armes en vente** : `pvp_outposts/config.lua` (`Config.WeaponShopItems`, armurerie)
> - **Armes autorisées côté serveur** (whitelist anti-triche, plus large, inclut les
>   variantes MK2) : `pvp_inventory/server/server.lua`, table `WEAPONS`
> - **Véhicules lootables sur zombies** (table de loot pondérée complète) :
>   `pvp_zombies/config.lua`
>
> Détail de cet écart : voir `STATUS.md` → « Écarts de documentation connus ».

### Zombies (pvp_zombies)
- **1 seul type de zombie** (pas de Walker/Runner/Brute)
- Modèles : `u_m_y_zombie_01`, `u_m_y_corpse_01`, `a_m_m_tramp_01`, `a_f_m_tramp_01`, `u_m_y_militarybum`, `a_m_m_fatbla_01`, `s_m_y_prisoner_01`
- HP : 200, Vitesse : 1.0, Dégâts : 15, Récompense : 20-60$
- Animation : `move_m@drunk@verydrunk`
- Loot pondéré : **1 zombie = 1 item**
- **Taux de loot :**
  - Très Commun (~82.8%) : Soins, Shots, Pistols, SMG, Molotov
  - Commun (~15%) : AK47, Carabine, Carabine Spécial
  - Rare (~1.5%) : MK2 fusils, M60, Mitrailleuse, Stungun + Véhicules rares
  - Épic (~0.5%) : Fusil précision, Lance-grenades, M60 MK2, Mousquet + Véhicules épic
  - Légendaire (~0.01%) : Sniper, RPG, Homing Launcher + Véhicules légendaires
- **Zones d'exclusion** : `Config.ExclusionZones` dans pvp_zombies/config.lua (coords + rayon). À maintenir si les avant-postes bougent.
- **Boost redzone** : items rares (chance < 10) × `Config.LootMultiplier` (x2)
- **XP** : +50 XP par zombie tué (via `vanta_xp`, event interne `vanta_xp:internalZombieKill`)
- AWP/AWP MK2 : exclusifs aux caisses de ravitaillement (pvp_drops), pas sur zombies

### Système XP (vanta_xp) — source unique de progression
- **Niveaux** : 1 à 100. XP requis pour un niveau = `100 × niveau^1.5` (cumulatif)
- **Prestige** : 0 à 5. Chaque prestige ajoute un bonus de capacité cumulatif :
  - P1 : +6kg sac / +4kg conteneur · P2 : +12/+8 · P3 : +18/+12 · P4 : +24/+16 · P5 (VANTA) : +30/+20
  - Capacité de base : 50kg (sac), 20kg (conteneur), avant bonus prestige
- **Gain d'XP** : +300 par kill joueur, +50 par kill zombie (`VantaXP.XPSources` dans `vanta_xp/config.lua`)
- **Sécurité** : les kills sont notifiés à `vanta_xp` via des `AddEventHandler` internes
  (`vanta_xp:internalPlayerKill`, `vanta_xp:internalZombieKill`), jamais via `RegisterNetEvent`
  — un client ne peut donc pas se déclencher de l'XP lui-même
- **Table** : `vanta_xp` (identifier, xp, level, prestige_level, total_xp_earned)
- **Exports** : `addXP(identifier, amount, source)`, `getProfile(identifier)`,
  `getBagBonus(identifier)`, `getContainerBonus(identifier)` — utilisés par `pvp_inventory`
  pour les bonus de poids

> ⚠️ Bug actif connu sur la commande `/givexp` (collision avec `pvp_admin`) : voir `STATUS.md`.

### Mort
- Perd tout l'inventaire sac
- Coffre protégé préservé
- Respawn à l'avant-poste le plus proche
- Armes retirées, véhicule spawné supprimé

### Avant-postes (pvp_outposts) — 5 total

**2 Grandes bases (tous services) :**
| # | ID | Label | Emplacement | Zone safe |
|---|----|-------|-------------|-----------|
| 1 | `murietta_base` | Murietta Heights Base | Ville (carte GTA V standard — mapping custom retiré) | 60m |
| 2 | `zancudo_base` | Zancudo Valley Base | Campagne | 60m |

**3 Petits camps (spécialité unique) :**
| # | ID | Label | Spécialité | Zone safe |
|---|----|-------|-----------|-----------|
| 3 | `ls_armory` | LS Armurerie | Armes + custom armes | 35m |
| 4 | `sandy_garage` | Sandy Shores Garage | Véhicules + custom véhicules | 35m |
| 5 | `paleto_medical` | Paleto Bay Infirmerie | Soins | 35m |

**Fonctionnalités :**
- Zone safe = joueur invincible (`SetEntityInvincible`)
- NPCs : téléport, shop (adapté à la spécialité), custom armes, custom véhicules
- Coffres = props (pas de NPC), ouvre le NUI inventaire
- Blips différenciés par type
- Téléportation entre avant-postes via NPC pilote

*Statut d'avancement de chaque resource ci-dessous (fonctionnel/en cours/testé ou non) :
voir `STATUS.md`. Ce qui suit ne décrit que l'architecture.*

### Drops de ravitaillement (pvp_drops)
- Un avion traverse la carte aléatoirement, sa trajectoire est visible sur la minimap sous
  forme de **petites flèches rouges clignotantes** orientées dans le sens du vol
  (sprite 1 + `ShowHeadingIndicatorOnBlip` + `SetBlipFlashInterval` décalé par flèche →
  effet de vague). Elles disparaissent au largage.
- Le drop tombe en parachute pendant 5 min (`Config.FallDuration`), puis devient ouvrable
  après 5 min de « sécurisation » au sol (`Config.OpenDelay`)
- **À l'atterrissage** : cercle de fusées éclairantes autour de la caisse
  (`prop_flare_01` × 6, `Config.FlareRadius`) + particules `core`/`exp_grd_flare` +
  son d'allumage `Flare` du soundset `FBI_05_SOUNDS`. Particules et son sont **locaux à
  chaque client** (pas de réseau, pas de doublon) ; seuls les props sont réseau et donc
  créés par le contrôleur.
- **Loot** : catégories Épic et Légendaire (AWP/AWP MK2 exclusifs aux drops). Le ratio réel
  penche largement vers l'épic — voir `STATUS.md` → « Écarts de documentation connus ».
- **Modèle contrôleur** : un client est désigné « contrôleur » et pilote les entités réseau
  (avion, caisse, props de flares) ; les autres se contentent d'interpoler localement la
  même trajectoire. Le serveur **réassigne automatiquement un nouveau contrôleur** si
  celui-ci se déconnecte (`pvp_drops:controllerChanged`), et le nouveau *reprend* les
  entités existantes (`findEntityNear` + `NetworkRequestControlOfEntity`) au lieu d'en
  créer de nouvelles. Le filtre `NetworkGetEntityIsNetworked` y est indispensable : les
  modèles utilisés existent aussi en décor statique sur la carte (Fort Zancudo est à la
  fois une zone de drop et un site rempli de caisses militaires).
- **Expiration** : un drop non vidé disparaît après `Config.DropLifetime` (1h) et tous les
  clients sont prévenus via `pvp_drops:ended`. Ne jamais remettre `activeDrop = nil` sans
  passer par `endDrop()` — sinon la caisse et les blips restent affichés côté client pour
  un drop qui n'existe plus côté serveur.
- **Sync à la connexion** : un client qui rejoint en cours de drop demande l'état via
  `pvp_drops:requestSync` et reçoit un `elapsed` qui recale sa timeline locale.
- Dépend de `vanta_ui` (notifications) et `pvp_inventory` (export `canAddToBag`, UI de la
  caisse) — déclaré dans `fxmanifest.lua`

### Redzones (pvp_redzones)
- 3 zones rouges actives en permanence sur la carte
- Loot doublé dans les zones (`Config.LootMultiplier` x2)
- Rotation automatique toutes les heures
- Killfeed affiche une couleur différente pour les kills en redzone

### Killfeed (pvp_killfeed)
- **Vision** : haut-droite de l'écran, affiche "KILLER → VICTIME"
- Couleur neutre pour kill en zone normale
- Couleur distincte pour kill en redzone
- Intégré au style VANTA v2

### Crew (pvp_crew)
- Créer / rejoindre un crew
- Tag de crew visible sur le joueur

### Marché joueur (pvp_market)
- Listings persistants (joueur → joueur)

### Customisation armes (pvp_outposts) — style VANTA v2
- **NUI** : panel latéral droit (30% écran), fond semi-transparent (`rgba(10,10,10,0.85)`), joueur visible à 70%
- **Composants** : grille 2 colonnes, toggle on/off par composant (chargeur, lampe, viseur, silencieux, grip)
- **Teintes** : grille 4 colonnes, 8 teintes GTA (Normal, Vert, Or, Rose, Armée, LSPD, Orange, Platine)
- **Persistance** : table `pvp_weapon_customs` (identifier + weapon_name → custom_json)
- **Export** : `applyWeaponCustomForItem(itemName)` — applique tint + composants depuis le cache client
- **Équipement instantané** : quand le joueur range une arme via hotbar, l'arme reste sur le ped (pas de `RemoveWeaponFromPed`) → re-sortie instantanée avec customs intactes via `SetCurrentPedWeapon`. Le vrai retrait (`RemoveWeaponFromPed`) ne se fait que pour stash/coffre/mort via `pvp_inventory:unequipWeapon`.
- **Flow équipement** : `HasPedGotWeapon` → si oui, switch direct + rechargement (`SetPedAmmo(9999)` + `SetAmmoInClip(maxClip)`) ; si non, `GiveWeaponToPed(false)` → export customs → `SetCurrentPedWeapon`
- **Rechargement au re-sortie** : armes munitions infinies uniquement — pool remis à 9999 + chargeur rempli via `GetMaxAmmoInClip`/`SetAmmoInClip`. LIMITED_AMMO (sniper, RPG, etc.) non rechargées.
- **Config** : `Config.WeaponComponents` et `Config.WeaponsTintEnabled` dans `pvp_outposts/config.lua`

### Garage (pvp_garage) — style VANTA v2
- NUI HTML/CSS/JS, importé depuis `vanta_ui`
- Déclenché depuis `pvp_outposts` via `TriggerEvent('pvp_garage:openMechanic')` et `TriggerEvent('pvp_garage:openDealer')`
- **Personnalisation** (12 catégories) : Peinture, Roues, Moteur, Freins, Transmission, Blindage, Turbo, Suspension, Livrée, Néons, Teinte vitres, Phares Xenon
- **Mods Spéciaux** (véhicules Apocalypse) : Saut, Tourelle, Propulseurs, Bélier, Boost
- **Concessionnaire** : grille de véhicules (35 entrées, 7 catégories), gratuit, double-clic = spawn
- Annuler = restaure les mods d'origine
- `Config.ApocalypseVehicles` : hash map pour détection rapide
- Ordre server.cfg : `pvp_garage` avant `pvp_outposts`

### Admin (pvp_admin) — style VANTA v2
- **Panel NUI** : touche F7, 3 onglets (Joueurs, Serveur, Outils)
- **Noclip** : mouvement relatif caméra, WASD + Q/Z, 3 vitesses (CTRL/normal/SHIFT)
- **Spectate** : `/spec [id]`, sauvegarde/restaure position
- **God mode** : `/god`
- **Events inter-resources** : `pvp_drops:forceStart`, `pvp_redzones:forceRotate`
- `AdminConfig.OpenKey = 168` (F7)

### Création de personnage (pvp_character)
- Remplace `esx_identity` (supprimé) : pas d'identité civile GTA — pseudo + apparence détaillée
- Écran plein cadrage : panel semi-transparent ~32% à droite (style repris de
  `pvp_outposts/html/weapon_custom.css`), personnage visible en entier à gauche,
  rotation + bascule caméra corps/visage, toutes les modifications s'appliquent en direct sur le ped
- NUI bloquant : `pvp_spawn` attend l'événement de fin de création avant de faire apparaître le joueur
- **Deux types de personnage, choisis une seule fois à la création** :
  - **Standard (freemode)** : personnalisation complète — 12 teintes de peau, morphologie
    (père/mère/mix), barbe, sourcils, couleur des yeux, coiffure + 64 couleurs, et 5
    emplacements de vêtements (masque, jambes, chaussures, accessoire cou, hauts —
    volontairement pas de bras/torse, sac, decal, ni de sous-vêtement/gilet séparés du
    haut) + 5 accessoires (navigation flèches, bornée par les variantes réellement dispo
    sur le modèle via `GetNumberOfPedDrawableVariations`/`...TextureVariations`)
  - **Ped spécial** : choix libre dans le catalogue de peds de `pvp_inventory`
    (`ped_catalog.js`, partagé via `nui://pvp_inventory/html/ped_catalog.js` — pas de
    duplication), catégorie "animaux" exclue. Accessible à tous sans condition
    d'abonnement à la création, mais **définitif** : sans Gold/Diamond, plus aucun
    changement de ped possible ensuite (voir pvp_inventory ci-dessous)
- **Modération pseudo** : liste de mots interdits vérifiée en sous-chaîne, insensible à la casse
- **Renommage** (`/rename`) : payant (5000$) sauf abonnement VCoins Diamond (gratuit, illimité) —
  dépend de `pvp_vcoins`, ne touche jamais l'apparence/le ped
- Saison courante : `CURRENT_SEASON = 1` (indépendante de celle de `pvp_inventory`)
- Pas de table `characters` dédiée : le pseudo vit dans `users.firstname`/`sex` (ESX standard)
- Apparence détaillée stockée en JSON compact dans `pvp_player_stats.appearance_json`
  (tableaux de nombres uniquement — jamais de `null`), le ped choisi dans
  `pvp_player_stats.ped_model` (colonne partagée avec `pvp_inventory`). Les anciennes
  colonnes `skin_tone`/`hair_style` (index 0-3) sont converties automatiquement vers
  `appearance_json` à la première connexion post-refonte, puis ignorées.
- Ajoute par migration les colonnes à `pvp_player_stats` : `skin_tone`, `hair_style`,
  `rename_free_season`, `rename_last_week`, `appearance_json` (`ped_model`/`hud_type`/`hotbar`
  restent migrées par `pvp_inventory`, voir plus bas)
- `fxmanifest.lua` déclare `dependencies { es_extended, mysql-async, vanta_ui, pvp_inventory }`
  — chargé APRÈS `pvp_inventory` dans `server.cfg` (catalogue de peds + table `pvp_player_stats`)

### VCoins (pvp_vcoins) — monnaie premium
- Deux abonnements : **Gold** (800 VC/30j, bonus stash +5%) et **Diamond** (1500 VC/30j, bonus stash +10%)
- Marché VCoins entre joueurs : jusqu'à 5 offres actives par vendeur (`MARKET_MAX_OFFERS`)
- Intégration Tebex prévue (webhook `pvp_vcoins/tebex/<secret>`) — **secret par défaut non changé**
  dans `pvp_vcoins/server/server.lua` (`TEBEX_URL_SECRET = 'CHANGE_ME_TO_A_LONG_RANDOM_STRING...'`).
  À générer avant toute mise en production si l'intégration Tebex est activée.
- Exports consommés par d'autres resources : `GetTier`, `HasDiamond`, `HasGoldOrDiamond`,
  `GetSubscriptionTier`, `GetVCoins`, `GetStashBonus`
- Tables : `vcoin_market`, `vcoin_pending_bank`, `vcoin_tebex_transactions`, colonnes `vcoins`/`subscription`/`sub_expires_at` sur `users`
- Chargé avant `pvp_inventory` et `pvp_outposts` dans `server.cfg` (bonus stash consommé par eux)

### Écran de chargement (vanta_loading)
- `loadscreen` FiveM standard, thème VANTA v2
- Aucune dépendance d'autres resources envers lui
- Statut d'activation actuel : voir `STATUS.md`

---

## Config ESX
- Accounts : `bank` (Dollars)
- StartingMoney : 500$ bank
- EnablePaycheck : false
- EnableHud : false (pvp_hud custom)
- EnableSocietyPayouts : false
- Pas de nourriture/eau, pas de jobs

---

## Base de données

**Toutes les tables ci-dessous sont créées automatiquement au démarrage**
(`CREATE TABLE IF NOT EXISTS` + migrations `ALTER TABLE` par les resources elles-mêmes).
Perdre la base perd les données joueurs, pas la structure.

### Table `users` (ESX core)
Pas de colonnes custom ajoutées par VANTA. Contient uniquement les champs standards ESX
(`identifier`, `money`, `bank`, `job`, `group`, `firstname`, `lastname`...) + `vcoins`,
`subscription`, `sub_expires_at` ajoutés par `pvp_vcoins`.
⚠️ Ne contient **pas** `xp`, `prestige`, `active_badge`, `badges_unlocked`,
`kill_streak_record` — contrairement à une ancienne version de cette doc. Ces champs sont
dans `pvp_player_stats` (voir ci-dessous).

### Progression & profil
- `pvp_player_stats` — stats joueur : `kills`, `deaths`, `zombies_killed`, `redzone_kills`,
  `redzone_deaths`, `redzone_zombies`, `kill_streak_record`, `active_badge`,
  `badges_unlocked` (JSON), `hotbar` (JSON), `hud_type`, `skin_tone`, `hair_style`,
  `rename_free_season`, `rename_last_week`, `ped_model`, `display_name`
  — ⚠️ contient aussi `xp` et `prestige`, **legacy non utilisés** (voir « Système XP »)
- `vanta_xp` — progression réelle : `xp`, `level`, `prestige_level`, `total_xp_earned`
- `characters` — identité personnage (`pvp_character`) : prénom, nom, date de naissance, sexe, taille

### Inventaire & customisation
- `pvp_player_stash` — coffre protégé personnel (JSON items)
- `pvp_outpost_stash` — coffre avant-poste (JSON items, par outpost_id par joueur)
- `pvp_weapon_customs` — customisation armes (identifier + weapon_name → custom_json avec components[] et tint)
- `pvp_vehicle_customs` — customisation véhicules (identifier + vehicle_model → mods_json)
- `user_inventory` — inventaire ESX standard (identifier, item, count)
- `items` — items ESX (armes + véhicules enregistrés au démarrage)

### Économie
- `vcoin_market` — annonces marché VCoins entre joueurs
- `vcoin_pending_bank` — paiements VCoins en attente
- `vcoin_tebex_transactions` — transactions Tebex traitées (idempotence)
- `pvp_market_listings` — annonces marché joueur classique (argent)
- `pvp_market_pending_payments` — paiements marché en attente
- `society_moneywash` — blanchiment société (hérité ESX, jobs désactivés sur ce serveur)

### Crew
- `pvp_crews` — crew : nom, tag, owner, stats agrégées, xp/level/bank de crew
- `pvp_crew_members`, `pvp_crew_invites`, `pvp_crew_stash`, `pvp_crew_activity`,
  `pvp_crew_events`, `pvp_crew_objectives`

### Admin & logs
- `pvp_admin_bans` — bannissements (identifier, raison, durée, actif)
- `pvp_admin_logs` — journal des actions admin
- `pvp_redzone_control_log` — historique de contrôle des redzones par crew

---

## HUD (pvp_hud)

Actif. Fait bien plus que l'affichage — tout tourne dans `pvp_hud/client/client.lua` :

- **Affichage** : HP, armor, arme équipée, munitions (chargeur + réserve), coin bas-gauche
- **Restrictions de combat** (voulu, actif) :
  - Coups de crosse désactivés : contrôles 140/141/142 bloqués sauf arme de mêlée équipée
  - Tir en véhicule désactivé : contrôles 24/25/69/70/92/93 bloqués quand `IsPedInAnyVehicle`
- **Nettoyage du monde ambiant** (thread `Wait(0)`, chaque frame) :
  - Densité PNJ/véhicules/PNJ scénario forcée à 0
  - Niveau de recherché (wanted level) retiré en continu
  - Roue des armes et touches 1-9 désactivées en permanence
- **Nettoyage périodique** (toutes les 5s) : supprime les PNJ et véhicules ambiants résiduels
  non pilotés par un joueur
- **Dispatch désactivé** au démarrage : police/services, bateaux, camions poubelle, trains aléatoires

`/togglehud` — masquer/afficher le HUD visuel (utile pour les streams). N'affecte ni les
restrictions ni le nettoyage du monde.

---

## Pièges Techniques — IMPORTANT
- **Exports pvp_outposts** : `getAllOutposts` et `getNearestOutpost` sont **serveur uniquement**. `IsInSafeZone` est côté client. Ne jamais appeler un export serveur depuis un client — le pcall échoue silencieusement.
- **JAMAIS** `confirm()` ou `prompt()` dans le NUI → freeze le jeu FiveM CEF
- **JAMAIS** `backdrop-filter: blur()` dans le CSS NUI → rend opaque dans FiveM CEF
- `esx:playerLoaded` passe un `playerId` (number), PAS un objet xPlayer → vérifier avec `type()`
- JSON `null` → Lua `nil` cause des trous dans les tables → utiliser des objets avec clés string
- `SetNuiFocusKeepInput(true)` passe TOUT l'input → `DisableControlAction` nécessaire pour la caméra
- Pas de colonne `last_position` dans `users` → ne pas requêter dessus
- HTML5 drag & drop cassé dans FiveM CEF → utiliser mousedown/mousemove/mouseup custom
- Web Audio autoplay peut ne pas fonctionner → sons désactivés dans pvp_inventory

---

## Roadmap

Voir `STATUS.md` — mise à jour plus fréquente, section « Roadmap ».

---

## Commandes Admin (pvp_admin)
`/ahelp`, `/tp [id]`, `/bring [id]`, `/tpc [x] [y] [z]`, `/heal [id]`, `/revive [id]`, `/slay [id]`, `/kick [id] [raison]`, `/give [id] [item] [qty]`, `/givemoney [id] [montant]`, `/givexp [id] [montant]`, `/clearinv [id]`, `/drop`, `/rzrotate`, `/rzlist`, `/killzombies`, `/spawnzombies [qty]`, `/weather [type]`, `/time [heure]`, `/announce [message]`, `/noclip`, `/god`, `/spec [id]`, `/car [modèle]`, `/dv`, `/tpwp`
