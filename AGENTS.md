# VANTA — Serveur FiveM Zombie Survival PVP

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
├── [essential]   — ESX core (es_extended, mysql-async, essentialmode, esx_identity, esx_addonaccount)
├── [menu]        — Resources custom PVP :
│   ├── vanta_ui       — Design system partagé v2 (CSS tokens, variables --v-*, font Inter)
│   ├── pvp_hud        — HUD minimaliste coin bas-gauche (HP, armor, arme, munitions) + restrictions combat
│   ├── pvp_inventory  — Inventaire NUI complet (sac, coffre protégé, coffre avant-poste, hotbar, profil, paramètres)
│   ├── pvp_spawn      — Spawn aléatoire aux avant-postes (login = random, mort = plus proche)
│   ├── pvp_outposts   — Avant-postes avec zones safe, NPCs (shop/stash), custom armes (NUI + persistance DB)
│   ├── pvp_zombies    — Système zombie (spawn, IA, loot pondéré)
│   ├── pvp_market     — Marché joueur (listings persistants) — design à retravailler
│   ├── pvp_drops      — Caisses de ravitaillement larguées par avion — fonctionnel, polish en cours
│   ├── pvp_redzones   — 3 zones rouges PVP rotatives (loot x2) — fonctionnel, détails manquants
│   ├── pvp_killfeed   — Killfeed haut-droite (killer/victime + couleur zone) — créé, non testé
│   ├── pvp_crew       — Système de crew (créer/rejoindre, tag visible) — fonctionnel, à approfondir
│   ├── pvp_garage     — Personnalisation véhicule NUI + concessionnaire
│   ├── pvp_admin      — Outil admin complet (panel NUI F7, noclip, spectate, god, commandes)
│   └── spooner        — Map editor en jeu
└── [maps]        — Mappings :
    ├── base_v15           — Base zombie Murietta Heights (1519 props, converti depuis Menyoo XML)
    └── total_apocalypse/  — Mapping apocalyptique global (pack1, pack2, pack3 — 163 ymaps)
```

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
**Toutes les resources sont sur v2.** Ne jamais utiliser les anciennes variables v1 (`--bg-primary`, `--accent-silver`, etc.).

### Palette de couleurs (variables v2)
```css
:root {
  /* Backgrounds */
  --v-black:        #000000;
  --v-bg:           #0a0a0a;
  --v-surface:      #141414;
  --v-surface-2:    #1c1c1e;
  --v-surface-3:    #242426;
  --v-elevated:     #2c2c2e;

  /* Borders */
  --v-separator:       rgba(255, 255, 255, 0.06);
  --v-separator-bold:  rgba(255, 255, 255, 0.10);
  --v-border:          rgba(255, 255, 255, 0.08);
  --v-border-hover:    rgba(255, 255, 255, 0.15);

  /* Text */
  --v-text:           #ffffff;
  --v-text-secondary: rgba(255, 255, 255, 0.55);
  --v-text-tertiary:  rgba(255, 255, 255, 0.28);
  --v-text-disabled:  rgba(255, 255, 255, 0.15);

  /* Brand */
  --v-silver:       #c8cdd4;
  --v-silver-dim:   rgba(200, 205, 212, 0.40);
  --v-silver-glow:  rgba(200, 205, 212, 0.06);

  /* Semantic */
  --v-danger:       #ff453a;
  --v-danger-dim:   rgba(255, 69, 58, 0.15);
  --v-success:      #30d158;
  --v-success-dim:  rgba(48, 209, 88, 0.15);
  --v-warning:      #ffd60a;
  --v-warning-dim:  rgba(255, 214, 10, 0.15);
  --v-info:         #64d2ff;
  --v-info-dim:     rgba(100, 210, 255, 0.15);

  /* Rarités */
  --v-rarity-common:           rgba(255, 255, 255, 0.10);
  --v-rarity-common-solid:     #3a3a3e;
  --v-rarity-uncommon:         rgba(48, 209, 88, 0.25);
  --v-rarity-uncommon-solid:   #1a5c32;
  --v-rarity-rare:             rgba(100, 210, 255, 0.25);
  --v-rarity-rare-solid:       #1a4a6e;
  --v-rarity-legendary:        rgba(255, 214, 10, 0.25);
  --v-rarity-legendary-solid:  #6e5a10;
}
```

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

### Profil joueur (pvp_inventory → onglet PROFIL)
- **Carte identité** : avatar Discord, nom, identifier, badge actif, label prestige
- **Barre XP** : 20 niveaux par cycle, barre animée, seuil prestige à 30 000 XP
- **Stats** : Kills, Morts, K/D, Zombies tués total
- **Records** : Kill streak record (suivi en mémoire serveur, persisté en DB)
- **Classement personnel** : rang #X en kills, zombies, K/D
- **XP** : +50 par kill PVP, +15 par zombie tué
- **Prestige** : 5 niveaux max, reset XP à 0, badge débloqué automatiquement
- **15 badges déblocables** :
  - Saison : `survivor_s1`
  - Kills PVP : `first_blood` (1), `killer_10` (10), `killer_50` (50), `predator_100` (100)
  - Zombies : `zombie_hunter` (100), `exterminator` (500), `annihilator` (1000)
  - Streak : `streak_5` (5), `unstoppable` (10)
  - Prestige : `prestige_1` à `prestige_5`
- Saison en cours : `CURRENT_SEASON = 1`
- DB colonnes : `kill_streak_record`, `xp`, `prestige`, `active_badge`, `badges_unlocked` (JSON)

### Armes (31 total, 4 tiers de rareté)

**Commun (mêlée + pistolets) :**
- `weapon_knife`, `weapon_bat`, `weapon_crowbar`, `weapon_switchblade`, `weapon_hatchet`, `weapon_machete`
- `weapon_pistol`, `weapon_snspistol`, `weapon_vintagepistol`, `weapon_machinepistol`

**Peu Commun (shotguns + SMG) :**
- `weapon_combatpistol`, `weapon_heavypistol`, `weapon_revolver`, `weapon_doubleaction`
- `weapon_pumpshotgun`, `weapon_sawnoffshotgun`, `weapon_dbshotgun`, `weapon_assaultshotgun`
- `weapon_microsmg`, `weapon_minismg`, `weapon_smg`, `weapon_combatpdw`

**Rare (fusils d'assaut + MG) :**
- `weapon_assaultrifle`, `weapon_carbinerifle`, `weapon_compactrifle`
- `weapon_combatmg`, `weapon_mg`

**Légendaire (explosifs + sniper) :**
- `weapon_rpg`, `weapon_grenadelauncher`, `weapon_grenade`
- `weapon_sniperrifle`

**Munitions :** infinies sauf sniper/RPG/lance-grenades (LIMITED_AMMO). Seule munition lootable : `ammo_sniper`.

### Véhicules Lootables (par rareté)

**Commun :** `vehicle_ratloader`, `vehicle_bodhi2`, `vehicle_emperor`, `vehicle_tornado`, `vehicle_bmx`, `vehicle_blazer`

**Peu Commun :** `vehicle_sanchez`, `vehicle_bati`, `vehicle_mesa`, `vehicle_dubsta`, `vehicle_brawler`, `vehicle_kamacho`, `vehicle_kuruma`, `vehicle_buffalo`

**Rare :** `vehicle_insurgent`, `vehicle_buffalo3`, `vehicle_hellion`, `vehicle_dominator`, `vehicle_guardian`, `vehicle_nightshark`

**Rare — Blindés :** `vehicle_baller3`, `vehicle_baller6`, `vehicle_schafter5`, `vehicle_schafter6`

**Rare — Apocalypse :** `vehicle_deathbike`, `vehicle_dominator4`, `vehicle_impaler2`, `vehicle_imperator`, `vehicle_bruiser`, `vehicle_brutus`, `vehicle_slamvan4`, `vehicle_zr380`

**Légendaire :** `vehicle_deluxo`, `vehicle_scarab`, `vehicle_vigilante`, `vehicle_oppressor2`

**Système véhicules :** lootables sur zombies → item dans inventaire → hotbar pour spawn → touche K pour ranger → despawn instantané

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
- **XP** : +15 XP par zombie tué
- AWP/AWP MK2 : exclusifs aux caisses de ravitaillement (pvp_drops), pas sur zombies

### Mort
- Perd tout l'inventaire sac
- Coffre protégé préservé
- Respawn à l'avant-poste le plus proche
- Armes retirées, véhicule spawné supprimé

### Avant-postes (pvp_outposts) — 5 total

**2 Grandes bases (tous services) :**
| # | ID | Label | Emplacement | Zone safe |
|---|----|-------|-------------|-----------|
| 1 | `murietta_base` | Murietta Heights Base | Ville (mapping base_v15) | 60m |
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

### Drops de ravitaillement (pvp_drops) — fonctionnel, polish en cours
- Un avion traverse la carte aléatoirement, sa trajectoire est visible sur la minimap
- Le drop tombe en parachute pendant 5 min, puis s'ouvre au sol après 3 min
- **Loot exclusif** : items légendaires uniquement (armes + véhicules légendaires, AWP/AWP MK2)
- **À finir** : UI d'annonce, animations, sons, polish visuel général

### Redzones (pvp_redzones) — fonctionnel, détails à définir
- 3 zones rouges actives en permanence sur la carte
- Loot doublé dans les zones (`Config.LootMultiplier` x2)
- Rotation automatique toutes les heures
- Killfeed affiche une couleur différente pour les kills en redzone
- **À polish** : visuels carte/minimap, notifications de rotation, timer visible — à définir

### Killfeed (pvp_killfeed) — créé, non testé
- **Vision** : haut-droite de l'écran, affiche "KILLER → VICTIME"
- Couleur neutre pour kill en zone normale
- Couleur distincte pour kill en redzone
- Intégré au style VANTA v2

### Crew (pvp_crew) — fonctionnel, à approfondir
- Créer / rejoindre un crew
- Tag de crew visible sur le joueur
- **Vision long terme** :
  - Hiérarchie : leader + membres
  - Coffre partagé crew
  - Système d'affrontement entre crews (à brainstormer)
  - Stats de crew

### Marché joueur (pvp_market) — opérationnel, design à retravailler
- Listings persistants (joueur → joueur)
- **À faire** : refonte visuelle pour plus de lisibilité et de présence

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
- Table `pvp_player_stash` — coffre protégé personnel (JSON items)
- Table `pvp_outpost_stash` — coffre avant-poste (JSON items, par outpost_id par joueur)
- Table `pvp_weapon_customs` — customisation armes (identifier + weapon_name → custom_json avec components[] et tint)
- Table `items` — items ESX (armes + véhicules enregistrés au démarrage)
- Colonnes `users` ajoutées : `kill_streak_record`, `xp`, `prestige`, `active_badge`, `badges_unlocked` (JSON)

---

## HUD (pvp_hud) — Restrictions combat
Thread dédié chaque frame dans `pvp_hud/client/client.lua` :
- **Coups de crosse désactivés** : contrôles 140/141/142 bloqués sauf arme de mêlée équipée
- **Tir en véhicule désactivé** : contrôles 24/25/69/70/92/93 bloqués quand `IsPedInAnyVehicle`

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

### Priorité actuelle : rendre toutes les features existantes fonctionnelles et cohérentes avant d'en ajouter de nouvelles.

- [x] Phase 1 — Base solide (server.cfg, ESX config PVP)
- [x] Phase 2 — Zombies (spawn, IA, loot pondéré)
- [x] Phase 2.5 — Inventaire NUI complet + armes + véhicules
- [x] Phase 3 — Avant-postes, garage, admin, profil, badges, XP/prestige
- [ ] **En cours — Polish & consolidation** :
  - [ ] pvp_drops : UI d'annonce, sons, animations
  - [ ] pvp_redzones : polish visuel, notifications rotation, timer
  - [ ] pvp_killfeed : tester et finaliser
  - [ ] pvp_crew : tester, corriger, brainstormer la vision long terme
  - [ ] pvp_market : refonte design (plus lisible/visible)
- [ ] Phase 4 — Crew system avancé (hiérarchie, coffre partagé, affrontements)
- [ ] Phase 5 — Mapping avant-postes (CodeWalker)
- [ ] Phase 6 — Lancement public

---

## Commandes Admin (pvp_admin)
`/ahelp`, `/tp [id]`, `/bring [id]`, `/tpc [x] [y] [z]`, `/heal [id]`, `/revive [id]`, `/slay [id]`, `/kick [id] [raison]`, `/give [id] [item] [qty]`, `/givemoney [id] [montant]`, `/givexp [id] [montant]`, `/clearinv [id]`, `/drop`, `/rzrotate`, `/rzlist`, `/killzombies`, `/spawnzombies [qty]`, `/weather [type]`, `/time [heure]`, `/announce [message]`, `/noclip`, `/god`, `/spec [id]`, `/car [modèle]`, `/dv`, `/tpwp`
