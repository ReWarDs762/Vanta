# VANTA — Patte des insignes

> Code : [`pvp_inventory/html/badges.js`](../pvp_inventory/html/badges.js) — tout le
> système tient dans ce seul fichier, chargé avant `app.js`.

## 1. Le parti

Les insignes VANTA sont des **insignes de prestige illustrés** : plaque émaillée,
charge centrale, ornements empilés derrière, listel en bas. C'est la grammaire des
emblèmes de rang militaires — mais réécrite pour un monde mort.

**Trois substitutions font l'identité.** Elles ne sont pas décoratives, elles sont
la marque : sans elles on retombe sur un insigne militaire générique.

| Le cliché du genre | Ce que VANTA met à la place |
|---|---|
| Ailes d'aigle héraldique | **Ailes de charognard** — anguleuses, en éventail dur |
| Couronne de laurier | **Ronces barbelées** — arc de fil avec barbelures |
| Or partout | **Métal d'os noirci** — l'or est réservé aux abonnements |

**La règle d'or du métal** : le métal d'os pour tout ce qui se **mérite**, l'or pour
tout ce qui s'**achète**. On ne doit jamais confondre un joueur qui a payé et un
joueur qui a joué. Ne jamais donner d'or à un haut fait ou à un prestige.

Cette patte est **l'exception ornementale du serveur**. Le design system VANTA v2
(`vanta.css`) interdit dégradés, ombres et matière — les insignes s'en affranchissent
volontairement, et sont le seul endroit qui en a le droit. Ne pas propager ces
dégradés au HUD, à l'inventaire ou aux menus.

## 2. Anatomie

Les couches, de l'arrière vers l'avant. Toutes sont des pièces réutilisables
définies une fois dans `badges.js` :

| Couche | Def SVG | Rôle |
|---|---|---|
| Halo | `vb-halo` | Léger éclaircissement radial, toujours présent |
| Rayons | *(généré)* | 16 pointes rayonnantes — réservé au sommet de chaque famille |
| Ailes | `vb-aile` | Cinq plumes en éventail, dessinées à droite puis mirroir |
| Lames | `vb-lame` | Deux lames croisées, pointes en haut, poignées en bas |
| Ronces | `vb-ronce` | Arc barbelé sous la plaque |
| Plaque | `vb-plaque` / `vb-plaqueI` / `vb-plaqueC` | Monture métal, fond noirci, émail |
| Charge | `CHARGE[...]` | Le sujet du badge, au centre |
| Listel | `vb-banniere` / `vb-bannQ` | Bandeau + queues, porte le texte court |

Repères géométriques, dans le `viewBox 0 0 240 250` : plaque centrée sur
**(120, 112)**, charge sur **(120, 108)**, listel sur **(120, 196)**.

## 3. Trois tailles, trois dessins

Un insigne illustré **ne se réduit pas** : réduit à 44 px, les cinq couches se
referment en bouillie. Chaque badge existe donc en trois dessins distincts.

| | Classe | viewBox | Affiché à | Contenu | Utilisé par |
|---|---|---|---|---|---|
| **L** | `.rank-full` | `0 0 240 250` | 96 px | tout, listel compris | grille du profil |
| **M** | `.rank-svg` | `0 0 240 250` | 44 × 46 | plaque + charge, traits épaissis, **aucun ornement** | *(disponible, inutilisé)* |
| **S** | `.rank-mini` | `-34 -34 68 68` | 12 × 12 | charge seule, trait de 3 | pastille de la carte identité |

`L` est produit à la demande par `BADGE_DEFS[id].full()`. `M` et `S` sont
précalculés sur chaque entrée de `BADGE_DEFS`.

> **Ce qui lâche en premier quand on réduit, c'est le listel — pas l'ornement.**
> Mesuré sur les insignes réels : à 96 px ailes, lames, ronces et rayons se
> lisent encore tous ; vers 84 px le texte du listel devient illisible (un
> `DIAMOND` avant un `V`) ; sous ~72 px l'ornement commence à se refermer sur
> lui-même. La grille du profil est donc en
> `repeat(auto-fill, minmax(112px, 1fr))` — cinq colonnes dans les 660 px du
> profil, insigne plafonné à 96 px. En dessous de 80 px, servir `M` plutôt que
> `L` réduit.

> La carte de badge est volontairement muette — fond et bordure transparents,
> révélés au survol et sur l'état actif. C'est l'insigne qui porte la couleur ;
> une bordure teintée par badge en plus de l'émail faisait doublon.

## 4. L'ornement suit le palier, jamais le badge

C'est la règle qui tient tout le système : **plus c'est rare, plus c'est chargé**.
On lit la valeur d'un badge à sa densité avant de lire son nom. Il n'y a donc rien
à choisir quand on ajoute un badge — le palier décide.

| `tier` | Ornements | Émail | Métal |
|---|---|---|---|
| `common` | *(plaque nue)* | acier | os |
| `uncommon` | lames | vert | os |
| `rare` | lames + ailes | cyan | os |
| `legendary` | lames + ailes + ronces | or | os |
| `season` | ronces | os | os |
| `premium` | ailes + ronces | *(forcé)* | **or** |
| `prestige` | *(forcé, voir ci-dessous)* | *(forcé)* | os |

`season` reçoit les ronces mais pas les lames : on a survécu, on n'a rien tué pour ça.

**Prestige** est le seul endroit où les couches sont écrites à la main, parce que
l'escalade *est* le sujet : I plaque nue · II + lames · III + ailes · IV + ronces ·
V + rayons. L'émail suit l'échelle existante (argent, or, cyan, magenta, orange).

Émaux disponibles : `argent` `acier` `vert` `cyan` `or` `magenta` `orange` `os`.

## 5. Ajouter un badge

**Étape 1 — dessiner la charge** dans `CHARGE` (`badges.js`), si aucune existante
ne convient. Contraintes :

- Forme **pleine**, centrée sur `(0,0)`, tenant dans **±29**. Le métal, le contour
  et le mirroir sont posés par la fabrique : ne dessiner que la silhouette.
- Les creux (orbites, dents, gravures) se font **par-dessus**, en noir semi-opaque —
  utiliser le helper `creux(d, opacité)`.
- **Jamais d'émoji, jamais de glyphe de police.** Le dessin doit tenir à 12 px :
  si la silhouette n'est pas reconnaissable en aplat, la charge est trop détaillée.
- Angles francs plutôt que courbes molles, sauf pour l'organique (le crâne est la
  seule charge qui utilise des courbes, et c'est délibéré).

**Étape 2 — ajouter l'entrée** dans `CATALOGUE` :

```js
mon_badge: { label: 'Mon Badge', tier: 'rare', charge: 'maCharge', banniere: '×25' },
```

`banniere` est un texte **court** (5 caractères ou moins idéalement — au-delà la
fabrique réduit le corps). Pour les hauts faits c'est le seuil (`×50`), pour les
saisons le millésime (`S1`), pour les rangs le chiffre romain.

**Étape 3 — autoriser l'id côté serveur** dans `VALID_BADGES`
([`pvp_inventory/server/server.lua`](../pvp_inventory/server/server.lua)), sinon le
badge ne pourra jamais être débloqué.

Rien d'autre. L'ornement, l'émail, la couleur de bordure de carte et les trois
tailles sont déduits automatiquement.

## 6. Ce qu'il ne faut pas faire

- **Donner de l'or à autre chose qu'un abonnement.** C'est la seule distinction
  visuelle entre ce qui s'achète et ce qui se gagne.
- **Inventer une couleur d'émail par badge.** La couleur porte le palier. Un badge
  qui a sa teinte à lui casse la lecture de rareté d'un coup d'œil.
- **Ajouter une charge figurative forte** sans raison. Le crâne (Prédateur) et la
  charge V (Prestige V) sont volontairement les deux seules du système : leur poids
  vient de leur rareté.
- **Réduire le L au lieu de dessiner le M.** C'est l'erreur qui rend la grille
  illisible.
- **Propager les dégradés hors des insignes.** Le reste du serveur est plat.

## 7. Typographie

Les insignes utilisent **Big Shoulders Display** (900) pour le listel, avec repli
`Oswald, Arial Narrow, sans-serif`. C'est la seule police d'affichage du serveur ;
tout le reste de l'UI est en Inter. Elle est chargée par la page qui affiche les
badges, pas par `badges.js`.
