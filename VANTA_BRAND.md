# VANTA — Charte d'identité visuelle v2.1 « Monolithe »

> **Source de vérité technique** : `resources/[menu]/vanta_ui/html/vanta.css`
> **Référence visuelle** : `resources/[menu]/vanta_ui/html/index.html` (à ouvrir hors jeu)
> **Architecture des resources** : `CLAUDE.md` · **Avancement / bugs** : `STATUS.md`
> **Comparaison avant / après** : `VANTA_avant_apres.png` (8 écrans, rendus Chromium)

Cette charte ne remplace pas la direction artistique existante : elle la **consolide**.
Le noir profond, l'argent, Inter, les bordures 1px et l'esthétique plate/angulaire
étaient déjà les bons choix. Ce qui manquait, c'était une **marque** — une forme, une
construction de titre et un code couleur qu'on reconnaît sans lire le nom du serveur.

---

## 1. Positionnement

| | |
|---|---|
| **Univers** | Survie zombie · PVP · pénurie · territoire disputé |
| **Registre** | Dark premium, précision militaire, sobriété |
| **Référence** | Apple Monochrome × Tactical Premium |
| **Interdits** | grunge, rouille, poussière, néon, RGB gaming, glassmorphism, pilules arrondies |
| **Mots-clés** | Plat. Angulaire. Monochrome. Noir sur noir. |

Le nom **VANTA** vient du noir le plus absorbant connu. L'identité en découle
littéralement : **le fond ne brille jamais.** Toute la lisibilité vient du contraste
de graisse, du tracking et de filets d'1 pixel — jamais d'un halo ou d'un dégradé.

---

## 2. Les trois signatures

Trois constructions suffisent à rendre une capture d'écran identifiable. Elles se
combinent, ne coûtent aucun asset et restent lisibles par-dessus le rendu 3D.

### Signature 01 — Le chevron V

La marque unique de VANTA : un **chevron descendant**, tracé unique, jonctions à
onglet, extrémités carrées. Jamais arrondi, jamais plein, jamais incliné.

```
  \        /
   \      /
    \    /
     \  /
      \/
```

**Où il apparaît :** icône du serveur, bannières, écran de chargement, filigrane de
la topbar d'inventaire, filigrane de la création de personnage, en-tête des panneaux
(escouade, téléportation, XP), puce des notifications, **connecteur du killfeed**
(couché à 90°, il porte la direction tueur → victime), et l'icône des états vides.

**En CSS** : `.v-mark` (+ `-sm`, `-lg`, `-xl`, `-boxed`), ou le token `--v-mark-svg`
comme masque sur n'importe quel pseudo-élément — la couleur suit alors `currentColor`.

> **Ce qui a été corrigé :** la topbar de l'inventaire portait un triangle
> **ascendant** (`∧`) et l'écran de chargement un **crâne** générique, pendant que
> l'icône du serveur et les bannières portaient le chevron `∨`. Trois marques
> concurrentes. Il n'en reste qu'une.

### Signature 02 — Les équerres

Quatre équerres d'1px posées aux angles des surfaces majeures. Reprises de l'écran de
chargement — la seule interface qui avait déjà une vraie personnalité VANTA — et
étendues à tout le serveur.

**En CSS** : `.v-brackets` sur le conteneur (angles haut-gauche + bas-droite) ;
ajouter `<i class="v-brackets-alt"></i>` en enfant pour les quatre angles.
La teinte suit `--v-bracket-color`, surchargeable par domaine
(`.v-brackets.is-pvp`, `.is-crew`, `.is-reward`, `.is-infected`).

### Signature 03 — Le titre à filet

**Tous** les titres de section du serveur ont la même attaque :

```
VANTA · CREW                         ← surtitre (.v-eyebrow), 9px, tertiaire
▌ MEMBRES ─────────────────────  3/4  ← barre 2px + titre tracké + filet + valeur
```

Le filet court jusqu'au bord du conteneur ; seule la **couleur de la barre** change
selon le domaine. C'est ce qui rend « MON SAC », « MEMBRES », « PRESTIGE » et
« TÉLÉPORTATION » immédiatement parents.

**En CSS** : `.v-title` + `.v-title-text` (+ `.v-title-value`, `.v-eyebrow`,
et `.v-title-pvp` / `-crew` / `-reward` / `-infected`).

### Détails récurrents (support)

| Détail | Classe | Rôle |
|---|---|---|
| **Trame hairline** | `.v-grid-bg` | Quadrillage 1px à 2,2 % d'opacité, pas de 32px. Donne une matière au noir sans jamais se voir consciemment. |
| **Filet de déploiement** | `.v-sweep` | Filet argenté qui se déploie de gauche à droite à l'ouverture d'un panneau. Élément autonome (pas un pseudo-élément) pour rester combinable avec `.v-brackets`. |
| **Bloc chiffre** | `.v-figure` | Toute statistique : label 9px tracké au-dessus, valeur Inter **Light** tabulaire au-dessous. Le contraste de graisse (500 → 300) fait la lecture. |

---

## 3. Les quatre signaux

La base reste **monochrome**. La couleur ne décore pas : elle **nomme un système de
jeu**. Quatre teintes, désaturées vers l'argent pour ne jamais virer au néon.

| Signal | Token | Valeur | Porte |
|---|---|---|---|
| 🔴 **PVP** | `--v-pvp` | `#e8564b` | Redzone, mort, danger, actions destructrices, admin |
| 🟢 **Infecté** | `--v-infected` | `#8a9e5b` | Zombies, infection, rareté « peu commun » |
| 🔵 **Crew** | `--v-crew` | `#6f9fc4` | Escouade, alliés, information, rareté « rare », Diamond |
| 🟡 **Récompense** | `--v-reward` | `#d9a441` | Loot, légendaire, VCoins, prestige, Gold |

Toute la sémantique d'interface y est **mappée**, pour qu'il n'existe qu'une échelle :

```css
--v-danger  = var(--v-pvp)      --v-warning = var(--v-reward)
--v-info    = var(--v-crew)     --v-success = #5f9e63
```

Et les raretés d'objets suivent les mêmes signaux :
`commun` = argent · `peu commun` = infecté · `rare` = crew · `légendaire` = récompense.

> **Ce qui a été corrigé :** cinq rouges coexistaient (`#8b2020` admin/HUD,
> `#e53935` crew, `#ff453a` killfeed, `#c83232` téléportation, `#8b5a1a` orange
> admin), plus deux ors (`#ffd60a`, `#e8c860`) et deux verts (`#30d158`, `#1a6b3a`).
> Le `#8b2020` du HUD et de l'admin échouait au contraste WCAG (**2.19:1**).

**Accessibilité** — les huit couleurs de texte passent WCAG AA (≥ 4.5:1) sur les
quatre fonds VANTA (`#000000`, `#0a0a0a`, `#141414`, `#1c1c1e`). Le plus serré est
`--v-pvp` à 4.75:1 sur `--v-surface-2`.

---

## 4. Typographie

**Une seule famille : Inter.** La hiérarchie se joue au **tracking et à la graisse**,
jamais au changement de police.

| Rôle | Graisse | Taille | Tracking | Token |
|---|---|---|---|---|
| Display (VANTA, écrans héros) | 200–500 | 32–40px | `0.30em` | `--v-track-display` |
| Titre de panneau | 600 | 13px | `0.14em` | `--v-track-title` |
| Label / onglet / bouton | 500–600 | 9–11px | `0.10em` | `--v-track-label` |
| Chiffre | **300** | 18–40px | `-0.02em` | `tabular-nums` obligatoire |
| Métadonnée | 400 | 11–13px | `0.04em` | `--v-track-meta` |

> **Ce qui a été corrigé :** Bebas Neue et Rajdhani étaient utilisées dans
> `pvp_crew`, `vanta_xp`, `pvp_outposts` (téléportation + custom armes). Elles
> fabriquaient un « militaire » de banque d'images, faisaient charger deux familles
> de plus dans le CEF, et cassaient la parenté entre écrans.

**Le mot VANTA** s'écrit toujours en capitales, Inter, tracking display, sans
italique ni dégradé. Un tracking positif ajoute un blanc après la dernière lettre :
le compenser avec `margin-right: calc(var(--v-track-display) * -1)` pour recentrer
optiquement (déjà fait dans `.v-lockup`).

---

## 5. Formes, élévation, mouvement

**Rayons** — échelle angulaire, **4px maximum** :

```
--v-radius-xs 2px · --v-radius-sm 2px · --v-radius-md 3px · --v-radius-lg 4px
--v-radius-full  → réservé aux toggles et pastilles rondes uniquement
```

> **Ce qui a été corrigé :** `CLAUDE.md` documentait « rayon max 4px » pendant que
> `vanta.css` définissait `--v-radius-lg: 14px` et `--v-radius-xl: 20px`, appliqués
> aux cartes et aux modales. Le système contredisait sa propre charte. `vanta_xp`
> était à 12px, `pvp_crew` à 8px.

**Élévation** — **aucune ombre** sur une surface posée : la séparation se fait à la
bordure 1px. Une seule exception, `--v-shadow-float`, pour les couches qui flottent
au-dessus du rendu 3D du jeu (toasts, tooltips) — sinon elles se perdent sur un fond
clair en plein jour.

**Mouvement** — opacité et translation courte, 0,15–0,18 s, `--v-ease`.
Interdits : bounce, scale, glow pulses. Le seul mouvement « signé » est
`v-sweep` : le filet supérieur d'un panneau qui se déploie en 0,32 s à l'ouverture.

---

## 6. Écrire une nouvelle NUI

1. Importer la charte, **avant** la feuille locale :
   ```html
   <link rel="stylesheet" href="nui://vanta_ui/html/vanta.css">
   <link rel="stylesheet" href="style.css">
   ```
   *(Ne pas importer Inter à part : `vanta.css` s'en charge, graisses 200→700.)*
2. **Ne jamais écrire une couleur, un rayon ou un interlettrage en dur.** Si la
   resource a besoin de noms locaux, en faire des **alias** :
   ```css
   :root { --accent: var(--v-silver); --card-bg: var(--v-surface); }
   ```
3. Poser au moins **une** signature : un `.v-title` en tête de section, ou
   `.v-brackets` sur le panneau, ou le chevron dans l'en-tête.
4. Pièges FiveM/CEF à respecter (voir aussi `CLAUDE.md`) :
   `backdrop-filter: blur()` rend opaque · `confirm()`/`prompt()` gèlent le jeu ·
   le drag & drop HTML5 est cassé · `:has()` n'est pas garanti (non utilisé ici).

### Exception documentée — `vanta_loading`

Un *loadscreen* démarre **avant** toutes les autres resources : `nui://vanta_ui/` n'y
est pas résoluble. Sa feuille contient donc une **copie locale** du bloc de tokens,
explicitement signalée en commentaire. **À resynchroniser si la charte évolue.**

---

## 7. Fichiers morts — ne pas s'en inspirer

Trois fichiers restés en DA v1 ne sont chargés par rien (vérifié : aucun `ui_page`,
aucun import HTML). Ils portent désormais un bandeau d'avertissement en tête :

| Fichier | Statut |
|---|---|
| `pvp_hud/html/index_classic.html` | HUD « classique » archivé — Bebas Neue |
| `pvp_inventory/html/style_glass.css` | Prototype glassmorphism abandonné — Rajdhani |
| `pvp_garage/html/dealer.css` | Listé dans `fxmanifest` mais jamais importé : le CSS du concessionnaire est **inliné** dans `pvp_garage/html/index.html` |

---

## 8. Assets de marque

| Fichier | Format | Usage |
|---|---|---|
| `resources/[menu]/vanta_ui/html/brand/mark.svg` | SVG 44×36 | Chevron seul |
| `resources/[menu]/vanta_ui/html/brand/mark-boxed.svg` | SVG 96×96 | Chevron encadré (icône applicative) |
| `resources/[menu]/vanta_ui/html/brand/lockup.svg` | SVG 420×96 | Verrou marque + mot + tagline |
| `server_icon.png` | PNG 96×96 | Icône du serveur (liste FiveM) |
| `banner_detail.png` | PNG 900×200 | Bannière de détail (liste FiveM) |
| `banner_connecting.png` | PNG 1280×720 | Écran de connexion |

Les trois PNG se régénèrent avec **`node generate_logos.js`** (rendu Playwright/Chromium,
aucune dépendance à installer — l'ancienne version dépendait de `sharp`, absent du projet).
