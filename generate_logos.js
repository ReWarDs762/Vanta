// =============================================
//   VANTA — Générateur de logos serveur
//   Crée : server_icon.png, banner_detail.png, banner_connecting.png
// =============================================

const sharp = require('sharp');
const fs    = require('fs');

// ── ICON 96×96 ──────────────────────────────────────────────────────────────
// "V" comme paths SVG (pas de texte = rendu parfait sans dépendance de police)
const iconSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96">
  <!-- Fond noir -->
  <rect width="96" height="96" fill="#000000"/>
  <!-- Cadre silver fin -->
  <rect x="4" y="4" width="88" height="88" fill="none" stroke="#c8cdd4" stroke-width="0.8" opacity="0.5"/>
  <!-- Forme V en paths (angulaire, tactical) -->
  <polyline
    points="16,20 48,74 80,20"
    fill="none"
    stroke="#c8cdd4"
    stroke-width="5.5"
    stroke-linecap="square"
    stroke-linejoin="miter"
  />
</svg>`;

// ── BANNER DETAIL 900×200 ────────────────────────────────────────────────────
const bannerSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="900" height="200">
  <rect width="900" height="200" fill="#000000"/>

  <!-- Ligne verticale accent gauche -->
  <line x1="48" y1="38" x2="48" y2="162" stroke="#c8cdd4" stroke-width="1" opacity="0.45"/>

  <!-- VANTA -->
  <text x="72" y="128"
    font-family="Arial, Helvetica, sans-serif"
    font-weight="700"
    font-size="80"
    fill="#ffffff"
    letter-spacing="10">VANTA</text>

  <!-- Tagline -->
  <text x="74" y="158"
    font-family="Arial, Helvetica, sans-serif"
    font-weight="400"
    font-size="13"
    fill="#c8cdd4"
    letter-spacing="5"
    opacity="0.7">ZOMBIE SURVIVAL · PVP</text>

  <!-- Lignes décoratives droite -->
  <line x1="730" y1="56" x2="730" y2="144" stroke="#c8cdd4" stroke-width="1" opacity="0.18"/>
  <line x1="750" y1="56" x2="750" y2="144" stroke="#c8cdd4" stroke-width="1" opacity="0.12"/>
  <line x1="770" y1="56" x2="770" y2="144" stroke="#c8cdd4" stroke-width="1" opacity="0.07"/>

  <!-- Icône V miniature droite -->
  <polyline points="810,75 830,130 850,75"
    fill="none" stroke="#c8cdd4" stroke-width="2"
    stroke-linecap="square" stroke-linejoin="miter" opacity="0.25"/>

  <!-- Bordure bas -->
  <line x1="0" y1="198" x2="900" y2="198" stroke="#c8cdd4" stroke-width="1" opacity="0.2"/>
</svg>`;

// ── BANNER CONNECTING 1280×720 ───────────────────────────────────────────────
const connectingSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="720">
  <rect width="1280" height="720" fill="#000000"/>

  <!-- Grille subtile en arrière-plan -->
  <line x1="0" y1="180" x2="1280" y2="180" stroke="#c8cdd4" stroke-width="1" opacity="0.03"/>
  <line x1="0" y1="360" x2="1280" y2="360" stroke="#c8cdd4" stroke-width="1" opacity="0.03"/>
  <line x1="0" y1="540" x2="1280" y2="540" stroke="#c8cdd4" stroke-width="1" opacity="0.03"/>
  <line x1="320" y1="0"  x2="320" y2="720"  stroke="#c8cdd4" stroke-width="1" opacity="0.03"/>
  <line x1="640" y1="0"  x2="640" y2="720"  stroke="#c8cdd4" stroke-width="1" opacity="0.03"/>
  <line x1="960" y1="0"  x2="960" y2="720"  stroke="#c8cdd4" stroke-width="1" opacity="0.03"/>

  <!-- Cadre périphérique -->
  <rect x="40" y="40" width="1200" height="640" fill="none" stroke="#c8cdd4" stroke-width="1" opacity="0.08"/>

  <!-- Ligne accent gauche verticale -->
  <line x1="200" y1="240" x2="200" y2="480" stroke="#c8cdd4" stroke-width="1" opacity="0.3"/>

  <!-- V grand centré en arrière-plan (watermark) -->
  <polyline points="380,200 640,580 900,200"
    fill="none" stroke="#c8cdd4" stroke-width="1"
    stroke-linecap="square" stroke-linejoin="miter" opacity="0.04"/>

  <!-- VANTA titre principal -->
  <text x="640" y="380"
    font-family="Arial, Helvetica, sans-serif"
    font-weight="700"
    font-size="148"
    fill="#ffffff"
    text-anchor="middle"
    letter-spacing="28">VANTA</text>

  <!-- Ligne séparatrice -->
  <line x1="420" y1="418" x2="860" y2="418" stroke="#c8cdd4" stroke-width="1" opacity="0.35"/>

  <!-- Tagline -->
  <text x="640" y="452"
    font-family="Arial, Helvetica, sans-serif"
    font-weight="500"
    font-size="18"
    fill="#c8cdd4"
    text-anchor="middle"
    letter-spacing="8"
    opacity="0.85">ZOMBIE SURVIVAL · PVP</text>

  <!-- Sous-tagline -->
  <text x="640" y="488"
    font-family="Arial, Helvetica, sans-serif"
    font-weight="400"
    font-size="12"
    fill="#c8cdd4"
    text-anchor="middle"
    letter-spacing="5"
    opacity="0.35">ENTREZ DANS LA ZONE</text>

  <!-- Bordures haut/bas -->
  <line x1="0" y1="2"   x2="1280" y2="2"   stroke="#c8cdd4" stroke-width="2" opacity="0.12"/>
  <line x1="0" y1="718" x2="1280" y2="718" stroke="#c8cdd4" stroke-width="2" opacity="0.12"/>
</svg>`;

async function generate() {
    await sharp(Buffer.from(iconSvg)).resize(96, 96).png().toFile('server_icon.png');
    console.log('OK server_icon.png (96x96)');

    await sharp(Buffer.from(bannerSvg)).png().toFile('banner_detail.png');
    console.log('OK banner_detail.png (900x200)');

    await sharp(Buffer.from(connectingSvg)).png().toFile('banner_connecting.png');
    console.log('OK banner_connecting.png (1280x720)');
}

generate().catch(console.error);
