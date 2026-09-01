/* ═══════════════════════════════════════════════════════════════════════════
   VANTA — SYSTÈME D'INSIGNES
   ───────────────────────────────────────────────────────────────────────────
   Documentation complète de la patte : resources/[menu]/vanta_ui/BADGES.md

   Un insigne = une PLAQUE émaillée + une CHARGE au centre + des ORNEMENTS
   empilés derrière (lames, ailes, ronces, rayons) + une BANNIÈRE.

   Trois tailles, trois dessins — un insigne illustré ne se réduit pas :
     .full  L  (240×250)  complet          — fiche, annonces        [non câblé]
     .svg   M  (44×46)    plaque + charge  — grille du profil
     .mini  S  (12×12)    charge seule     — pastille en ligne

   POUR AJOUTER UN BADGE : une charge dans CHARGE, une entrée dans BADGES.
   L'ornement et l'émail découlent du palier (tier), il n'y a rien à choisir.
   ═══════════════════════════════════════════════════════════════════════════ */
(function () {
  'use strict';

  const FT = "Big Shoulders Display, Oswald, Arial Narrow, sans-serif";

  // ── 1. Métaux et émaux (injectés une fois dans le DOM) ───────────────────
  const DEFS = `
<svg width="0" height="0" style="position:absolute" aria-hidden="true"><defs>
<linearGradient id="vb-mtl" x1="0.15" y1="0" x2="0.55" y2="1">
<stop offset="0" stop-color="#f4f1e8"/><stop offset="0.22" stop-color="#c3bdad"/>
<stop offset="0.44" stop-color="#6c675c"/><stop offset="0.62" stop-color="#b3ada0"/>
<stop offset="0.82" stop-color="#7d786c"/><stop offset="1" stop-color="#403c34"/></linearGradient>
<linearGradient id="vb-mtlB" x1="0.2" y1="0" x2="0.6" y2="1">
<stop offset="0" stop-color="#d8d3c5"/><stop offset="0.3" stop-color="#8b8578"/>
<stop offset="0.6" stop-color="#4e4a41"/><stop offset="1" stop-color="#2a2721"/></linearGradient>
<linearGradient id="vb-or" x1="0.15" y1="0" x2="0.55" y2="1">
<stop offset="0" stop-color="#fff6d2"/><stop offset="0.22" stop-color="#e9c66d"/>
<stop offset="0.44" stop-color="#8a6a15"/><stop offset="0.62" stop-color="#dcb95a"/>
<stop offset="0.82" stop-color="#9c7a20"/><stop offset="1" stop-color="#4d3a0a"/></linearGradient>
<linearGradient id="vb-orB" x1="0.2" y1="0" x2="0.6" y2="1">
<stop offset="0" stop-color="#e0c079"/><stop offset="0.3" stop-color="#a2801f"/>
<stop offset="0.6" stop-color="#5c4710"/><stop offset="1" stop-color="#2e2306"/></linearGradient>
<linearGradient id="vb-noir" x1="0" y1="0" x2="0.3" y2="1">
<stop offset="0" stop-color="#2b2822"/><stop offset="0.5" stop-color="#141310"/>
<stop offset="1" stop-color="#070706"/></linearGradient>
<linearGradient id="vb-e-argent" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#eef1f5"/><stop offset="0.5" stop-color="#9aa1ab"/><stop offset="1" stop-color="#42474e"/></linearGradient>
<linearGradient id="vb-e-acier"  x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#b9bfc6"/><stop offset="0.5" stop-color="#6b7178"/><stop offset="1" stop-color="#2f3338"/></linearGradient>
<linearGradient id="vb-e-vert"   x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8df0aa"/><stop offset="0.5" stop-color="#22a34c"/><stop offset="1" stop-color="#0a3d1c"/></linearGradient>
<linearGradient id="vb-e-cyan"   x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7fe0f5"/><stop offset="0.5" stop-color="#1f9dbd"/><stop offset="1" stop-color="#093b4a"/></linearGradient>
<linearGradient id="vb-e-or"     x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f6cd5e"/><stop offset="0.5" stop-color="#bd8c11"/><stop offset="1" stop-color="#4f3a05"/></linearGradient>
<linearGradient id="vb-e-magenta" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f57fdc"/><stop offset="0.5" stop-color="#bd1f9d"/><stop offset="1" stop-color="#4a0a3a"/></linearGradient>
<linearGradient id="vb-e-orange" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ff9a5c"/><stop offset="0.5" stop-color="#f03c00"/><stop offset="1" stop-color="#5c1400"/></linearGradient>
<linearGradient id="vb-e-os"     x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f7f3e6"/><stop offset="0.5" stop-color="#c2b9a0"/><stop offset="1" stop-color="#585244"/></linearGradient>
<radialGradient id="vb-halo" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#fff" stop-opacity="0.10"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>
<path id="vb-plaque"  d="M 120 42 L 172 64 L 172 124 L 120 182 L 68 124 L 68 64 Z"/>
<path id="vb-plaqueI" d="M 120 54 L 162 71 L 162 120 L 120 168 L 78 120 L 78 71 Z"/>
<path id="vb-plaqueC" d="M 120 59 L 158 75 L 158 117 L 120 161 L 82 117 L 82 75 Z"/>
<g id="vb-aile">
<path d="M 4 -16 L 78 -62 L 92 -42 L 16 -4 Z"/><path d="M 6 2 L 96 -26 L 105 -5 L 18 16 Z"/>
<path d="M 8 22 L 100 12 L 102 34 L 20 34 Z"/><path d="M 10 40 L 88 44 L 84 65 L 22 52 Z"/>
<path d="M 12 56 L 70 72 L 62 90 L 24 68 Z"/></g>
<g id="vb-ronce" fill="none" stroke-linecap="square">
<path d="M -96 -22 C -92 34, -50 72, 0 76 C 50 72, 92 34, 96 -22"/>
<path d="M -92 4 l -13 -7 m 13 7 l -10 12 M -68 44 l -12 4 m 12 -4 l -3 13 M -30 70 l -6 12 m 6 -12 l 11 9 M 30 70 l 6 12 m -6 -12 l -11 9 M 68 44 l 12 4 m -12 -4 l 3 13 M 92 4 l 13 -7 m -13 7 l 10 12"/></g>
<g id="vb-lame">
<path d="M -8 62 L 4 55 L 76 -72 L 61 -84 L -20 52 Z"/><path d="M -22 47 L 7 64 L -3 81 L -32 64 Z"/>
<path d="M 61 -84 L 76 -72 L 70 -62 L 55 -74 Z"/></g>
<g id="vb-banniere"><path d="M -78 0 L 78 0 L 70 16 L 78 34 L -78 34 L -70 16 Z"/></g>
<g id="vb-bannQ"><path d="M -96 4 L -78 0 L -78 34 L -96 40 L -87 22 Z"/><path d="M 96 4 L 78 0 L 78 34 L 96 40 L 87 22 Z"/></g>
</defs></svg>`;

  // ── 2. Charges ───────────────────────────────────────────────────────────
  // Formes PLEINES, centrées sur (0,0), tenant dans ±29. Le métal et le
  // contour sont posés par la fabrique : ici on ne dessine que la silhouette.
  // Les creux (orbites, dents) se font en noir semi-opaque par-dessus.
  const chevrons = (n) => {
    let o = '';
    for (let i = 0; i < n; i++) {
      const y = -16 + i * 14;
      o += `<path d="M -25 ${y + 21} L 0 ${y} L 25 ${y + 21} L 25 ${y + 31} L 0 ${y + 10} L -25 ${y + 31} Z"/>`;
    }
    return o;
  };
  const creux = (d, op) => `<path d="${d}" fill="#0a0a0a" fill-opacity="${op || 0.85}" stroke="none"/>`;
  const ecu = (n) => `<path d="M 0 -28 L 24 -19 L 24 3 L 0 28 L -24 3 L -24 -19 Z"/>`
    + `<text x="0" y="11" text-anchor="middle" font-family="${FT}" font-size="27" font-weight="900" fill="#0a0a0a" fill-opacity="0.8" stroke="none">${n}</text>`;

  const CHARGE = {
    chev1: chevrons(1),
    chev2: chevrons(2),
    chev3: chevrons(3),
    etoile:  '<path d="M 0 -29 L 8 -8 L 29 0 L 8 8 L 0 29 L -8 8 L -29 0 L -8 -8 Z"/>',
    vee:     '<path d="M -29 -25 L -13 -25 L 0 9 L 13 -25 L 29 -25 L 7 29 L -7 29 Z"/>',
    couronne:'<path d="M -28 11 L 28 11 L 28 22 L -28 22 Z"/><path d="M -28 11 L -28 -15 L -14 0 L 0 -24 L 14 0 L 28 -15 L 28 11 Z"/>'
           + '<circle cx="0" cy="-24" r="3.8"/><circle cx="-28" cy="-15" r="3.2"/><circle cx="28" cy="-15" r="3.2"/>',
    gemme:   '<path d="M 0 -26 L 25 -7 L 0 28 L -25 -7 Z"/>'
           + '<path d="M -25 -7 L 25 -7" fill="none" stroke="#0a0a0a" stroke-opacity="0.5" stroke-width="2"/>'
           + '<path d="M -12 -7 L 0 -26 L 12 -7" fill="none" stroke="#0a0a0a" stroke-opacity="0.45" stroke-width="1.6"/>',
    crane:   '<path d="M -24 -4 C -24 -30, 24 -30, 24 -4 L 24 5 L 16 15 L 16 24 L 11 30 L -11 30 L -16 24 L -16 15 L -24 5 Z"/>'
           + creux('M -17 -9 C -17 -18, -4 -17, -5 -6 C -5 1, -16 2, -17 -9 Z')
           + creux('M 17 -9 C 17 -18, 4 -17, 5 -6 C 5 1, 16 2, 17 -9 Z')
           + creux('M 0 3 L 6 14 L -6 14 Z')
           + creux('M -11 18 L 11 18 L 11 25 L -11 25 Z', 0.45)
           + '<path d="M -5.5 18 L -5.5 25 M 0 18 L 0 25 M 5.5 18 L 5.5 25" fill="none" stroke="#0a0a0a" stroke-opacity="0.7" stroke-width="1.5"/>'
           + '<path d="M -13 -25 L -7 -18 L -11 -13" fill="none" stroke="#0a0a0a" stroke-opacity="0.5" stroke-width="1.7"/>',
    trefle:  '<circle cx="0" cy="0" r="6"/>'
           + '<path d="M -9 -11 L -13 -28 L 13 -28 L 9 -11 Z"/>'
           + '<path d="M -9 -11 L -13 -28 L 13 -28 L 9 -11 Z" transform="rotate(120)"/>'
           + '<path d="M -9 -11 L -13 -28 L 13 -28 L 9 -11 Z" transform="rotate(240)"/>',
    danger:  '<path d="M 0 -27 L 27 19 L -27 19 Z"/>'
           + creux('M -3.5 -11 L 3.5 -11 L 2.5 5 L -2.5 5 Z', 0.8)
           + '<circle cx="0" cy="12" r="3" fill="#0a0a0a" fill-opacity="0.8" stroke="none"/>',
    souffle: '<path d="M 0 -29 L 9 -11 L 27 -16 L 18 0 L 29 13 L 10 13 L 4 29 L -6 14 L -25 18 L -16 2 L -27 -11 L -9 -10 Z"/>'
           + '<circle cx="0" cy="0" r="5" fill="#0a0a0a" fill-opacity="0.55" stroke="none"/>',
    goutte:  '<path d="M 0 -28 L 9 -9 L 17 8 L 9 24 L -9 24 L -17 8 L -9 -9 Z"/>'
           + '<path d="M -9 8 L 0 15 L 9 8" fill="none" stroke="#0a0a0a" stroke-opacity="0.5" stroke-width="2"/>',
    dagues:  '<path d="M -6 26 L -1 22 L 23 -20 L 16 -26 L -12 20 Z"/>'
           + '<path d="M 6 26 L 1 22 L -23 -20 L -16 -26 L 12 20 Z"/>',
    viseur:  '<path d="M -29 -15 L -29 -29 L -15 -29 L -15 -23 L -23 -23 L -23 -15 Z"/>'
           + '<path d="M -29 -15 L -29 -29 L -15 -29 L -15 -23 L -23 -23 L -23 -15 Z" transform="rotate(90)"/>'
           + '<path d="M -29 -15 L -29 -29 L -15 -29 L -15 -23 L -23 -23 L -23 -15 Z" transform="rotate(180)"/>'
           + '<path d="M -29 -15 L -29 -29 L -15 -29 L -15 -23 L -23 -23 L -23 -15 Z" transform="rotate(270)"/>'
           + '<path d="M 0 -10 L 5 0 L 0 10 L -5 0 Z"/>'
           + '<path d="M -19 -2.5 L -9 -2.5 L -9 2.5 L -19 2.5 Z"/><path d="M 19 -2.5 L 9 -2.5 L 9 2.5 L 19 2.5 Z"/>',
    eclair:  '<path d="M 6 -29 L -16 4 L -2 4 L -7 29 L 16 -5 L 2 -5 Z"/>',
    eclairs: '<path d="M 6 -29 L -16 4 L -2 4 L -7 29 L 16 -5 L 2 -5 Z" transform="translate(-13,0) scale(0.74)"/>'
           + '<path d="M 6 -29 L -16 4 L -2 4 L -7 29 L 16 -5 L 2 -5 Z" transform="translate(13,0) scale(0.74)"/>',
    ecu1: ecu(1), ecu2: ecu(2), ecu3: ecu(3),
  };

  // ── 3. L'ornement suit le palier, pas le badge ───────────────────────────
  // C'est la règle qui tient tout le système : plus c'est rare, plus c'est
  // chargé. On lit la valeur d'un badge à sa densité avant de lire son nom.
  const ORNEMENT = {
    common:    {},
    uncommon:  { lames: true },
    rare:      { lames: true, ailes: true },
    legendary: { lames: true, ailes: true, ronces: true },
    season:    { ronces: true },
    premium:   { or: true, ailes: true, ronces: true },
  };
  const EMAIL_PALIER = {
    common: 'acier', uncommon: 'vert', rare: 'cyan', legendary: 'or', season: 'os',
  };
  const COULEUR = {
    acier: '#6b7178', vert: '#22a34c', cyan: '#1f9dbd', or: '#bd8c11',
    magenta: '#bd1f9d', orange: '#f03c00', argent: '#9aa1ab', os: '#c2b9a0',
  };

  // ── 4. Fabrique ──────────────────────────────────────────────────────────
  const rayonnement = () => {
    let o = '';
    for (let i = 0; i < 16; i++) o += `<path d="M 0 -112 L 6 -70 L -6 -70 Z" transform="rotate(${i * 22.5})"/>`;
    return o;
  };

  // L — insigne complet, toutes les couches. Fiche profil, annonces.
  function full(b) {
    const M = b.or ? 'vb-or' : 'vb-mtl', MB = b.or ? 'vb-orB' : 'vb-mtlB';
    let s = '<svg class="rank-full" viewBox="0 0 240 250" xmlns="http://www.w3.org/2000/svg">';
    s += '<ellipse cx="120" cy="112" rx="118" ry="118" fill="url(#vb-halo)"/>';
    if (b.rayons) s += `<g transform="translate(120,112)" fill="url(#${MB})" opacity="0.5">${rayonnement()}</g>`;
    if (b.ailes) s += `<g transform="translate(120,100)" fill="url(#${MB})" stroke="#0a0a0a" stroke-opacity="0.5" stroke-width="1.2">`
      + '<use href="#vb-aile"/><g transform="scale(-1,1)"><use href="#vb-aile"/></g></g>';
    if (b.lames) s += `<g transform="translate(120,112)" fill="url(#${M})" stroke="#0a0a0a" stroke-opacity="0.55" stroke-width="1.2">`
      + '<use href="#vb-lame"/><g transform="scale(-1,1)"><use href="#vb-lame"/></g></g>';
    if (b.ronces) s += `<g transform="translate(120,120)" stroke="url(#${MB})" stroke-width="3.4" fill="none"><use href="#vb-ronce"/></g>`;
    s += `<use href="#vb-plaque" fill="url(#${M})" stroke="#0a0a0a" stroke-opacity="0.6" stroke-width="1.2"/>`;
    s += '<use href="#vb-plaqueI" fill="url(#vb-noir)"/>';
    s += `<use href="#vb-plaqueC" fill="url(#vb-e-${b.email})" opacity="0.94"/>`;
    s += '<use href="#vb-plaqueC" fill="none" stroke="#0a0a0a" stroke-opacity="0.45" stroke-width="3"/>';
    s += `<use href="#vb-plaqueC" fill="none" stroke="url(#${MB})" stroke-width="1.6" stroke-linejoin="miter"/>`;
    s += `<g transform="translate(120,108)" fill="url(#${M})" stroke="#0a0a0a" stroke-opacity="0.6" stroke-width="1.3" stroke-linejoin="miter">${CHARGE[b.charge]}</g>`;
    if (b.banniere) s += '<g transform="translate(120,196)">'
      + `<use href="#vb-bannQ" fill="url(#${MB})" stroke="#0a0a0a" stroke-opacity="0.5" stroke-width="1.2"/>`
      + `<use href="#vb-banniere" fill="url(#${M})" stroke="#0a0a0a" stroke-opacity="0.5" stroke-width="1.2"/>`
      + `<text x="0" y="24" text-anchor="middle" font-family="${FT}" font-size="${b.banniere.length > 5 ? 15 : 19}" font-weight="900" letter-spacing="1.2" fill="#141310">${b.banniere}</text></g>`;
    return s + '</svg>';
  }

  // M — plaque et charge seules, traits épaissis. L'insigne complet réduit à
  // 44px devient illisible : c'est un dessin allégé, pas une réduction.
  function moyen(b) {
    const M = b.or ? 'vb-or' : 'vb-mtl';
    return '<svg class="rank-svg" viewBox="0 0 240 250" xmlns="http://www.w3.org/2000/svg">'
      + `<use href="#vb-plaque" fill="url(#${M})" stroke="#0a0a0a" stroke-opacity="0.7" stroke-width="3"/>`
      + '<use href="#vb-plaqueI" fill="url(#vb-noir)"/>'
      + `<use href="#vb-plaqueC" fill="url(#vb-e-${b.email})"/>`
      + '<use href="#vb-plaqueC" fill="none" stroke="#0a0a0a" stroke-opacity="0.6" stroke-width="5"/>'
      + `<g transform="translate(120,110) scale(1.25)" fill="url(#${M})" stroke="#0a0a0a" stroke-opacity="0.7" stroke-width="2.5" stroke-linejoin="miter">${CHARGE[b.charge]}</g>`
      + '</svg>';
  }

  // S — la charge seule. À 12px il ne reste que la silhouette.
  function mini(b) {
    const M = b.or ? 'vb-or' : 'vb-mtl';
    return '<svg class="rank-mini" viewBox="-34 -34 68 68" xmlns="http://www.w3.org/2000/svg">'
      + `<g fill="url(#${M})" stroke="#0a0a0a" stroke-opacity="0.7" stroke-width="3" stroke-linejoin="miter">${CHARGE[b.charge]}</g></svg>`;
  }

  // ── 5. Catalogue ─────────────────────────────────────────────────────────
  // label      : nom affiché sous la carte
  // tier       : décide l'ornement ET l'émail (sauf prestige / premium)
  // charge     : clé dans CHARGE
  // banniere   : texte du listel, sur la taille L uniquement
  // email      : force l'émail (prestige et abonnements seulement)
  // ornement   : force les couches (prestige seulement)
  const CATALOGUE = {
    // Saison — écu marqué du millésime, ronces, pas de lames : on a survécu,
    // on n'a rien tué pour ça.
    survivor_s1:    { label: 'Survivant Saison 1', tier: 'season',    charge: 'ecu1',     banniere: 'S1' },
    survivor_s2:    { label: 'Survivant Saison 2', tier: 'season',    charge: 'ecu2',     banniere: 'S2' },
    survivor_s3:    { label: 'Survivant Saison 3', tier: 'season',    charge: 'ecu3',     banniere: 'S3' },
    // Éliminations PVP — 1 / 10 / 50 / 100
    first_blood:    { label: 'Premier Sang',       tier: 'common',    charge: 'goutte',   banniere: '×1' },
    killer_10:      { label: 'Tueur',              tier: 'uncommon',  charge: 'dagues',   banniere: '×10' },
    killer_50:      { label: 'Chasseur',           tier: 'rare',      charge: 'viseur',   banniere: '×50' },
    predator_100:   { label: 'Prédateur',          tier: 'legendary', charge: 'crane',    banniere: '×100' },
    // Zombies — 100 / 500 / 1000
    zombie_hunter:  { label: 'Chasseur Zombie',    tier: 'common',    charge: 'trefle',   banniere: '×100' },
    exterminator:   { label: 'Exterminateur',      tier: 'rare',      charge: 'danger',   banniere: '×500' },
    annihilator:    { label: 'Annihilateur',       tier: 'legendary', charge: 'souffle',  banniere: '×1000' },
    // Série de kills — 5 / 10
    streak_5:       { label: 'Sur une Lancée',     tier: 'uncommon',  charge: 'eclair',   banniere: '×5' },
    unstoppable:    { label: 'Inarrêtable',        tier: 'rare',      charge: 'eclairs',  banniere: '×10' },
    // Abonnements — monture OR, jamais de métal d'os : ce qui s'achète ne doit
    // jamais être confondu avec ce qui se gagne.
    gold_member:    { label: 'Abonné Gold',        tier: 'premium',   charge: 'couronne', banniere: 'GOLD',    email: 'or',      couleur: '#e9c66d' },
    diamond_member: { label: 'Abonné Diamond',     tier: 'premium',   charge: 'gemme',    banniere: 'DIAMOND', email: 'cyan',    couleur: '#e9c66d', rayons: true },
    // Prestige — l'ornement s'empile palier par palier. C'est le seul endroit
    // où les couches sont écrites à la main plutôt que déduites du palier.
    prestige_1:     { label: 'Prestige I',         tier: 'prestige',  charge: 'chev1',    banniere: 'I',   email: 'argent',  couleur: COULEUR.argent,  ornement: {} },
    prestige_2:     { label: 'Prestige II',        tier: 'prestige',  charge: 'chev2',    banniere: 'II',  email: 'or',      couleur: COULEUR.or,      ornement: { lames: true } },
    prestige_3:     { label: 'Prestige III',       tier: 'prestige',  charge: 'chev3',    banniere: 'III', email: 'cyan',    couleur: COULEUR.cyan,    ornement: { lames: true, ailes: true } },
    prestige_4:     { label: 'Prestige IV',        tier: 'prestige',  charge: 'etoile',   banniere: 'IV',  email: 'magenta', couleur: COULEUR.magenta, ornement: { lames: true, ailes: true, ronces: true } },
    prestige_5:     { label: 'Prestige V — VANTA', tier: 'prestige',  charge: 'vee',      banniere: 'V',   email: 'orange',  couleur: COULEUR.orange,  ornement: { lames: true, ailes: true, ronces: true, rayons: true } },
  };

  // ── 6. Montage ───────────────────────────────────────────────────────────
  function monter(id, def) {
    const orn = def.ornement || ORNEMENT[def.tier] || {};
    const b = Object.assign({}, orn, def);
    b.email = def.email || EMAIL_PALIER[def.tier] || 'acier';
    if (def.rayons) b.rayons = true;
    return {
      id: id,
      label: def.label,
      tier: def.tier,
      color: def.couleur || COULEUR[b.email] || '#6b7178',
      svg: moyen(b),
      mini: mini(b),
      full: function () { return full(b); },
    };
  }

  const BADGE_DEFS = {};
  for (const id in CATALOGUE) BADGE_DEFS[id] = monter(id, CATALOGUE[id]);

  // Badge inconnu (id en base qui n'existe plus dans le catalogue).
  function inconnu(id) {
    return monter(id, { label: id, tier: 'common', charge: 'ecu1', banniere: '?' });
  }

  // Les dégradés doivent exister dans le DOM avant le premier insigne.
  function installer() {
    if (document.getElementById('vanta-badge-defs')) return;
    const d = document.createElement('div');
    d.id = 'vanta-badge-defs';
    d.style.cssText = 'position:absolute;width:0;height:0;overflow:hidden';
    d.innerHTML = DEFS;
    document.body.insertBefore(d, document.body.firstChild);
  }
  if (document.body) installer();
  else document.addEventListener('DOMContentLoaded', installer);

  window.BADGE_DEFS = BADGE_DEFS;
  window.VantaBadges = { defs: BADGE_DEFS, inconnu: inconnu, CHARGE: CHARGE, ORNEMENT: ORNEMENT, installer: installer };
})();
