# PVP Extinction — Serveur FiveM Zombie Survival

## Infos Projet
- **Nom** : PVP Extinction
- **Type** : Serveur FiveM PVP Zombie Survival
- **Path** : `C:/Users/Utilisateur/Desktop/Server/Server/`
- **Framework** : ESX (es_extended v1.1.0)
- **DB** : MySQL local (`mysql://root:@127.0.0.1/fivemserver`)
- **OneSync** : activé
- **Max clients** : 10 (test local)
- **Langue** : Français (UI et code)

## Architecture des Resources

```
resources/
├── [base]        — Resources FiveM de base (mapmanager, spawnmanager, chat, etc.)
├── [essential]   — ESX core (es_extended, mysql-async, essentialmode, esx_identity, esx_addonaccount)
├── [menu]        — Resources custom PVP :
│   ├── pvp_hud        — HUD minimaliste coin bas-gauche (HP, armor, arme, munitions)
│   ├── pvp_inventory  — Inventaire NUI complet (sac, coffre protégé, coffre avant-poste, hotbar, marché, profil, paramètres)
│   ├── pvp_spawn      — Spawn aléatoire aux avant-postes (login = random, mort = plus proche)
│   ├── pvp_outposts   — Avant-postes avec zones safe, NPCs (shop/stash)
│   ├── pvp_zombies    — Système zombie (spawn, IA, loot pondéré)
│   ├── pvp_market     — Marché joueur
│   └── spooner        — Map editor en jeu
└── [maps]        — Mappings :
    ├── base_v15           — Base zombie Murietta Heights (1519 props, converti depuis Menyoo XML)
    └── total_apocalypse/  — Mapping apocalyptique global (pack1, pack2, pack3 — 163 ymaps)
```

## Systèmes Clés

### Inventaire (pvp_inventory)
- NUI HTML/CSS/JS, thème post-apocalyptique (rust reds, military greens, dirty beige)
- Grille unique "MON SAC" (poids limité)
- Coffre protégé personnel (persistant à la mort, pas de limite de poids)
- Coffre avant-poste (pas de limite de poids, par joueur par outpost)
- Hotbar 7 slots (hover + touche 1-7 pour bind)
- Drag & drop custom (mousedown/mousemove/mouseup, pas HTML5 drag car cassé dans FiveM CEF)
- Clic droit = transfert rapide entre sac ↔ coffre (pas de menu contextuel)
- Images PNG pour armes (`html/img/weapon_pistol.png`) et véhicules (`html/img/adder.png`)
- Transparence dynamique via injection CSS `<style id="dynamic-opacity">`
- Camera lock quand inventaire ouvert (DisableControlAction sur controls 1, 2, 24, 25, 106, 140, 141, 142, 257)
- Sons désactivés (fonctions vides)

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

**Commun :**
- `vehicle_ratloader`, `vehicle_bodhi2`, `vehicle_emperor`, `vehicle_tornado`, `vehicle_bmx`, `vehicle_blazer`

**Peu Commun :**
- `vehicle_sanchez`, `vehicle_bati`, `vehicle_mesa`, `vehicle_dubsta`, `vehicle_brawler`, `vehicle_kamacho`, `vehicle_kuruma`, `vehicle_buffalo`

**Rare :**
- `vehicle_insurgent`, `vehicle_buffalo3`, `vehicle_hellion`, `vehicle_dominator`
- `vehicle_guardian`, `vehicle_nightshark`

**Rare — Blindés :**
- `vehicle_baller3` (Baller Blindé), `vehicle_baller6` (Baller LE Blindé)
- `vehicle_schafter5` (Schafter V12 Blindé), `vehicle_schafter6` (Schafter LWB Blindé)

**Rare — Apocalypse :**
- `vehicle_deathbike` (Deathbike), `vehicle_dominator4` (Dominator Apocalypse)
- `vehicle_impaler2` (Impaler Apocalypse), `vehicle_imperator` (Imperator)
- `vehicle_bruiser`, `vehicle_brutus`, `vehicle_scarab`, `vehicle_slamvan4`, `vehicle_zr380`

**Légendaire :**
- `vehicle_zentorno`, `vehicle_t20`, `vehicle_vigilante`, `vehicle_oppressor2`

**Système véhicules :** lootables sur zombies → item dans inventaire → hotbar pour spawn → touche K pour ranger → despawn instantané (téléport joueur + delete entity)

### Zombies (pvp_zombies)
- 3 types : Walker (60% spawn), Runner (30%), Brute (10%)
- Modèles GTA V zombie : `u_m_y_zombie_01`, `u_m_y_corpse_01`, `u_m_y_militarybum`, etc.
- Loot pondéré : **1 zombie = 1 item** (weighted random)
- Walker = surtout mêlée/pistolets + bandages, très rare véhicule commun
- Runner = toutes armes + soins + véhicules communs à rares
- Brute = meilleur loot, toutes armes + véhicules rares/légendaires/apocalypse

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
| # | ID | Label | Spécialité | Emplacement | Zone safe |
|---|----|-------|-----------|-------------|-----------|
| 3 | `ls_armory` | LS Armurerie | Armes + custom armes | Centre-ville LS | 35m |
| 4 | `sandy_garage` | Sandy Shores Garage | Véhicules + custom véhicules | Sandy Shores | 35m |
| 5 | `paleto_medical` | Paleto Bay Infirmerie | Soins | Paleto Bay | 35m |

**Fonctionnalités :**
- Zone safe = joueur **invincible** (`SetEntityInvincible`)
- NPCs : téléport, shop (adapté à la spécialité), custom armes, custom véhicules
- Coffres = props (pas de NPC), ouvre le NUI inventaire
- Blips différenciés par type (rouge militaire, orange armurerie, jaune garage, vert médical)
- Téléportation entre avant-postes via NPC pilote
- Mapping : base_v15 (Murietta) + Total Apocalypse (ambiance globale)

## Config ESX
- Accounts : `bank` (Dollars) + `black_money` (Butin)
- StartingMoney : 500$ bank
- EnablePaycheck : false (argent vient des zombies/marché)
- EnableHud : false (pvp_hud custom utilisé)
- EnableSocietyPayouts : false
- Pas de système de nourriture/eau
- Pas de jobs (esx_society désactivé)

## Base de données
- Table `pvp_player_stash` — coffre protégé personnel (JSON items)
- Table `pvp_outpost_stash` — coffre avant-poste (JSON items, par outpost_id par joueur)
- Table `items` — items ESX (armes + véhicules enregistrés au démarrage par pvp_inventory)

## Pièges Techniques — IMPORTANT
- **JAMAIS** utiliser `confirm()` ou `prompt()` dans le NUI → **freeze le jeu** FiveM CEF
- **JAMAIS** `backdrop-filter: blur()` dans le CSS NUI → rend opaque dans FiveM CEF
- `esx:playerLoaded` passe un `playerId` (number), PAS un objet xPlayer → toujours vérifier avec `type()`
- JSON `null` → Lua `nil` cause des trous dans les tables → utiliser des objets avec clés string
- `SetNuiFocusKeepInput(true)` passe TOUT l'input → besoin de `DisableControlAction` pour bloquer la caméra
- Pas de colonne `last_position` dans la table `users` → ne pas faire de requêtes SQL dessus
- HTML5 drag & drop cassé dans FiveM CEF → utiliser mousedown/mousemove/mouseup custom
- Pas de Web Audio autoplay dans certains cas FiveM → sons désactivés

## Roadmap
- [x] Phase 1 — Base solide (server.cfg, ESX config PVP)
- [x] Phase 2 — Zombies (spawn, IA, loot pondéré, modèles zombie)
- [x] Phase 2.5 — Inventaire NUI complet + armes + véhicules
- [ ] Phase 3 — Économie libre + Marché joueur
- [ ] Phase 4 — Crew & Squad system
- [ ] Phase 5 — Drop zones & Redzones
- [ ] Phase 6 — Polish PVP (killfeed, leaderboard)
- [ ] Mapping — Avant-postes (CodeWalker + mappings internet)

## Commandes utiles
- `/giveitem [id] [item] [qty]` — donner un item
- `/giveweapon [id] [weapon]` — donner une arme
- `/givecar [id] [vehicle]` — donner un véhicule
