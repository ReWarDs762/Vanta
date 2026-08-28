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

**Dernière mise à jour :** 27 août 2026

---

## 1. Tableau de bord

| Phase | Objet | Bloque la sortie ? | Statut | Avancement |
|---|---|---|---|---|
| **A** | Stabilisation — tester l'existant, corriger le noyau | 🔴 Oui | ⬜ Pas commencé | 0 / 5 |
| **B** | Cohérence technique — dette, sources uniques, notifs | 🔴 Oui | ⬜ Pas commencé | 0 / 3 |
| **C** | Polish gameplay & visuel | 🟠 Partiel | ⬜ Pas commencé | 0 / 4 |
| **D** | Pré-production & mise en ligne | 🔴 Oui | ⬜ Pas commencé | 0 / 6 |
| **E** | Post-lancement (v1.1+) | 🟢 Non | ⬜ Backlog | 0 / 4 |

**Chemin critique le plus court vers une sortie :** A → B → D.
C et E peuvent se faire après une sortie en *early access*.

### Légende des statuts
- ⬜ Pas commencé · 🟡 En cours · ✅ Fait · ⏸️ Bloqué (préciser par quoi) · ❌ Abandonné

---

## 2. État de test des resources

Référence rapide (détail dans `STATUS.md` → « Testé en jeu vs jamais testé »).
Une resource ne passe à ✅ **testée** qu'après validation manette en main.

| Resource | Code | Testée en jeu |
|---|---|---|
| `pvp_hud` | ✅ | ⬜ (restrictions combat réactivées, jamais vues) |
| `pvp_outposts` | ✅ stable | ⬜ |
| `pvp_zombies` | ✅ (refonte 22/08) | ⬜ |
| `pvp_inventory` | ✅ | ⬜ (le plus gros système) |
| `pvp_character` | ✅ (refonte 22/08) | ⬜ |
| `pvp_combat` | ✅ (neuf 23/08) | ⬜ |
| `pvp_drops` | ✅ (revue 25/08) | ⬜ |
| `pvp_crew` | ✅ (features 24/08) | ⬜ (0 membre en base) |
| `pvp_killfeed` | ✅ | ⬜ |
| `pvp_redzones` | ✅ | ⬜ |
| `vanta_ui` (notifs) | ✅ | ⬜ |
| `vanta_xp` | ✅ | ⬜ |
| `pvp_market` | ✅ | ⬜ |
| `pvp_garage` | ✅ | ⬜ |
| `pvp_vcoins` | ✅ | ⬜ |
| `pvp_admin` | ✅ | ⬜ |

---

## 3. PHASE A — Stabilisation *(bloquant sortie)*

> Depuis la reprise (21/08), énormément de code produit et **rien testé manette en main**.
> Priorité absolue : prouver que le noyau fonctionne.

### A1 — Session de test complète du parcours joueur
- [ ] Création de personnage (freemode complet)  ✅
- [ ] Création de personnage (ped spécial du catalogue) ✅
- [ ] Apparition (`pvp_spawn` attend bien la fin de création)  ✅
- [ ] Ouverture inventaire, hotbar, coffres (sac / protégé / avant-poste) ✅
- [ ] Tuer un zombie → loot au corps → item en inventaire  ✅ 
- [ ] Achat / vente armurerie + customisation arme ✅
- [ ] Achat / vente / spawn véhicule (garage)✅
- [ ] Marché joueur : créer une annonce, acheter  ⏸️ mettre une annonce valider, mais besoin de joueur pour acheter 
- [ ] Mort → perte du sac → death bag au sol → respawn avant-poste le plus proche ✅ 
- [ ] Téléportation entre avant-postes (NPC pilote + waypoint) ✅ 

**Fait quand :** le parcours complet tourne sans blocage ni erreur console serveur/client.

### A2 — Corriger les bugs remontés par A1
- [ ] Lister ici les bugs trouvés pendant A1, puis les corriger
  - …

**Fait quand :** A1 rejoué de bout en bout sans régression.

### A3 — Valider `pvp_combat` (anti combat-log)
- [ ] Un coup donné/reçu passe attaquant + victime en « EN COMBAT » 5s
- [ ] Fenêtre glissante : un nouveau coup prolonge le timer
- [ ] Déconnexion en plein combat → le joueur meurt, sac perdu, death bag créé à la dernière position
- [ ] Dépôt au coffre protégé refusé tant que le mode combat est actif
- [ ] Le mode combat ne se déclenche **pas** en zone safe ni entre membres de squad

**Fait quand :** les 5 points validés à 2 joueurs. *Critique — anti combat-log cassé = exploit au lancement.*

### A4 — Trancher la collision `/givexp`
- [ ] Décision : faire relayer `pvp_admin` vers `exports['vanta_xp']:addXP` (recommandé) **ou** supprimer la commande de `pvp_admin`
- [ ] Vérifier en jeu : `/givexp <id> <n>` fait bien monter l'XP réelle (`vanta_xp`), niveau/prestige suivent

**Fait quand :** `/givexp` a un effet observable et écrit dans la bonne table.

### A5 — Valider `pvp_character` en profondeur
- [ ] Parcours freemode : peau, morphologie, cheveux + couleur, vêtements, accessoires — tout s'applique en direct sur le ped
- [ ] Choix d'un ped spécial → définitif sans Gold/Diamond
- [ ] `/rename` : payant 5000$ (gratuit + illimité si Diamond)
- [ ] Modération pseudo (mot interdit refusé)
- [ ] `pvp_inventory` onglet Profil : bouton changement de ped **verrouillé** sans Gold/Diamond, et rejet serveur si forcé

**Fait quand :** aucun chemin de création ne bloque l'apparition, et la restriction de ped tient côté serveur.

---

## 4. PHASE B — Cohérence technique *(bloquant sortie)*

### B1 — Migration des notifications vers `vanta_ui`
- [ ] `pvp_market` → `exports['vanta_ui']:notify`
- [ ] `pvp_zombies` → idem
- [ ] `pvp_inventory` → retirer le handler `pvp_market:notify` (déclaré ici malgré son nom)
- [ ] Vérifier qu'aucune resource n'appelle plus `pvp_market:notify`

**Fait quand :** un seul style de toast à l'écran, `pvp_market:notify` supprimé du code.

### B2 — Source unique des tables de loot (armes / véhicules)
- [ ] Auditer `pvp_outposts/config.lua` (`WeaponShopItems`), `pvp_inventory/server/server.lua` (`WEAPONS`), `pvp_zombies/config.lua`
- [ ] Décider d'une organisation par rareté qui fait foi
- [ ] Reporter la liste consolidée dans `CLAUDE.md`, résorber la section « Écarts » de `STATUS.md`

**Fait quand :** une seule liste de référence documentée, les autres pointent dessus ou en dérivent.

### B3 — `pvp_drops` : équilibrage loot + test terrain
- [ ] Trancher le ratio épic / légendaire (~81 / 19 aujourd'hui) : assumer ou augmenter la part légendaire
- [ ] Tester avion + trajectoire flèches-sprite minimap (bigmap + écran large)
- [ ] Tester atterrissage par raycast au premier contact (toit de bâtiment surtout)
- [ ] Tester failover contrôleur : déco en plein vol **et** en pleine chute
- [ ] Tester expiration d'un drop non récupéré (`Config.DropLifetime`, 1h)
- [ ] Tester fusées éclairantes (props + son `Flare`) et `/droptest`

**Fait quand :** un drop complet (largage → sécurisation → ouverture) validé à 2 joueurs, failover inclus.

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

- [ ] Parcours joueur complet (A1) validé sans blocage
- [ ] `pvp_combat` anti combat-log validé à 2 joueurs (A3)
- [ ] `pvp_character` : aucun chemin de création ne bloque l'apparition (A5)
- [ ] Aucune erreur console serveur au démarrage ni en boucle
- [ ] Notifications unifiées (B1)
- [ ] `pvp_drops` : un drop complet validé, failover inclus (B3)
- [ ] `TEBEX_URL_SECRET` changé ou Tebex désactivé (D1)
- [ ] Comptes admin dans `group.admin`, commandes de test non accessibles aux joueurs (D2, D4)
- [ ] `server.cfg` prod complet (D4)
- [ ] Test de charge à 3-4 joueurs passé (D5)
- [ ] Backup DB automatique en place (D6)

---

## 9. Journal de session

> Une ligne par session de travail. But : ne plus jamais « se perdre entre les sessions ».
> Format : date — ce qui a été fait — ce qui bloque — prochaine étape.

| Date | Fait | Bloqué par | Prochaine étape |
|---|---|---|---|
| 2026-08-27 | Création de ce ROADMAP.md à partir de STATUS.md + historique git | — | Attaquer A1 (session de test parcours joueur) |
| | | | |
