// =============================================
//   PVP CHARACTER — appearance_data.js
//   Données statiques purement visuelles (aucune logique de jeu).
//   Nommage préfixé CHAR_ pour ne jamais entrer en collision avec les
//   identifiants globaux de ped_catalog.js / app.js de pvp_inventory,
//   chargé juste avant ce fichier dans index.html.
// =============================================

// Aperçu hex des 12 teintes de peau (doit rester dans le même ordre que
// SKIN_TONES côté client.lua — sert uniquement au rendu du swatch, la
// couleur réelle en jeu vient de SetPedHeadBlendData).
const CHAR_SKIN_HEX = [
    '#f4d8c0', '#eecdb0', '#e3ba98', '#d6a67e',
    '#c28a5e', '#ad7248', '#96602f', '#7d4d24',
    '#65401f', '#4d3018', '#382412', '#28190d',
];

// Palette de 64 couleurs (8x8) pour la teinte de cheveux — index purement
// visuel envoyé à setHairColor, la couleur réelle vient de SetPedHairColor.
const CHAR_HAIR_COLORS = (function () {
    const out = [];
    const base = [
        [10,8,7], [26,16,10], [43,26,14], [61,38,18],
        [82,52,24], [105,70,34], [128,92,48], [153,118,68],
        [176,144,92], [198,172,120], [214,196,152], [230,220,188],
        [235,225,200], [180,60,30], [150,40,20], [90,90,95],
        [140,140,145], [200,200,205],
    ];
    for (let i = 0; i < 64; i++) {
        const c = base[i % base.length];
        const jitter = (i * 7) % 15 - 7;
        const clamp = (v) => Math.max(0, Math.min(255, v + jitter));
        out.push('#' + [c[0], c[1], c[2]].map(clamp).map(v => v.toString(16).padStart(2, '0')).join(''));
    }
    return out;
})();

// Catégories affichées dans le catalogue de peds spéciaux à la création.
// "freemode" et "animal" sont volontairement absentes : freemode a sa propre
// branche dédiée, et les animaux sont exclus des choix de personnage PVP
// permanents (décision produit).
const CHAR_PED_CATEGORIES = {
    all:      'TOUS',
    military: 'MILITAIRE',
    law:      'POLICE',
    gang:     'GANGS',
    street:   'RUE',
    business: 'BUSINESS',
    worker:   'TRAVAIL',
    beach:    'PLAGE',
    story:    'HISTOIRE',
    heist:    'BRAQUAGES',
    horror:   'HORREUR',
    misc:     'DIVERS',
};
