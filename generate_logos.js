// =============================================
//   VANTA — Générateur d'assets de marque
//   Sort : server_icon.png, banner_detail.png, banner_connecting.png
//
//   Rendu via Playwright/Chromium (déjà présent) plutôt que sharp :
//   pas de dépendance native à installer, et le texte est composé par
//   le vrai moteur de rendu (tracking Inter fidèle à la charte NUI).
//
//   Usage : node generate_logos.js
//   Charte : VANTA_BRAND.md · Tokens : resources/[menu]/vanta_ui/html/vanta.css
// =============================================

const path = require('path');
const { chromium } = require(process.env.PW_PATH || '/opt/node22/lib/node_modules/playwright');

// ── Jetons de marque (miroir de vanta.css) ───────────────────────────────────
const BLACK  = '#000000';
const SILVER = '#c8cdd4';
const WHITE  = '#ffffff';
const FONT   = "Inter, 'Helvetica Neue', Arial, sans-serif";

// Le chevron VANTA : un seul tracé, jonctions à onglet, extrémités carrées.
const chevron = (x, y, w, h, stroke, width, opacity = 1) =>
  `<path d="M${x} ${y} L${x + w / 2} ${y + h} L${x + w} ${y}" fill="none"
      stroke="${stroke}" stroke-width="${width}" stroke-linecap="square"
      stroke-linejoin="miter" opacity="${opacity}"/>`;

// ── ICÔNE 96×96 ─────────────────────────────────────────────────────────────
const iconSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96">
  <rect width="96" height="96" fill="${BLACK}"/>
  <rect x="4" y="4" width="88" height="88" fill="none" stroke="${SILVER}" stroke-width="1.6" opacity="0.5"/>
  ${chevron(16, 20, 64, 54, SILVER, 5.5)}
</svg>`;

// ── BANNIÈRE DÉTAIL 900×200 ─────────────────────────────────────────────────
// Construction « titre à filet » : barre verticale + mot tracké + tagline.
const bannerSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="900" height="200" viewBox="0 0 900 200">
  <rect width="900" height="200" fill="${BLACK}"/>

  <!-- équerres d'angle — signature VANTA -->
  <path d="M24 24 H52 M24 24 V52"   fill="none" stroke="${SILVER}" stroke-width="1" opacity="0.3"/>
  <path d="M876 176 H848 M876 176 V148" fill="none" stroke="${SILVER}" stroke-width="1" opacity="0.3"/>

  <!-- chevron de marque -->
  ${chevron(48, 76, 46, 38, SILVER, 5)}

  <!-- filet vertical : attaque du titre -->
  <line x1="120" y1="62" x2="120" y2="138" stroke="${SILVER}" stroke-width="2" opacity="0.85"/>

  <text x="146" y="112" font-family="${FONT}" font-weight="600" font-size="60"
        fill="${WHITE}" letter-spacing="18">VANTA</text>
  <text x="149" y="140" font-family="${FONT}" font-weight="500" font-size="12"
        fill="${SILVER}" letter-spacing="6" opacity="0.62">ZOMBIE SURVIVAL · PVP</text>

  <!-- filet bas -->
  <line x1="0" y1="199" x2="900" y2="199" stroke="${SILVER}" stroke-width="1" opacity="0.18"/>
</svg>`;

// ── BANNIÈRE DE CONNEXION 1280×720 ──────────────────────────────────────────
const gridLines = () => {
  let out = '';
  for (let y = 32; y < 720; y += 32) out += `<line x1="0" y1="${y}" x2="1280" y2="${y}" stroke="${WHITE}" stroke-width="1" opacity="0.022"/>`;
  for (let x = 32; x < 1280; x += 32) out += `<line x1="${x}" y1="0" x2="${x}" y2="720" stroke="${WHITE}" stroke-width="1" opacity="0.022"/>`;
  return out;
};

const connectingSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="720" viewBox="0 0 1280 720">
  <rect width="1280" height="720" fill="${BLACK}"/>

  <!-- trame hairline : même pas (32px) et même opacité que les NUI -->
  ${gridLines()}

  <!-- équerres d'angle aux quatre coins -->
  <path d="M40 40 H72 M40 40 V72"         fill="none" stroke="${SILVER}" stroke-width="1" opacity="0.3"/>
  <path d="M1240 40 H1208 M1240 40 V72"   fill="none" stroke="${SILVER}" stroke-width="1" opacity="0.3"/>
  <path d="M40 680 H72 M40 680 V648"      fill="none" stroke="${SILVER}" stroke-width="1" opacity="0.3"/>
  <path d="M1240 680 H1208 M1240 680 V648" fill="none" stroke="${SILVER}" stroke-width="1" opacity="0.3"/>

  <!-- bloc-logo encadré, identique à l'écran de chargement -->
  <rect x="612" y="244" width="56" height="56" fill="none" stroke="${WHITE}" stroke-width="1" opacity="0.15"/>
  <rect x="616" y="248" width="48" height="48" fill="none" stroke="${WHITE}" stroke-width="1" opacity="0.08"/>
  ${chevron(627, 262, 26, 22, SILVER, 4)}

  <text x="640" y="372" font-family="${FONT}" font-weight="500" font-size="72"
        fill="${WHITE}" text-anchor="middle" letter-spacing="21">VANTA</text>

  <line x1="470" y1="404" x2="810" y2="404" stroke="${SILVER}" stroke-width="1" opacity="0.30"/>

  <text x="640" y="434" font-family="${FONT}" font-weight="500" font-size="13"
        fill="${SILVER}" text-anchor="middle" letter-spacing="7" opacity="0.62">ZOMBIE SURVIVAL · PVP</text>

  <text x="640" y="470" font-family="${FONT}" font-weight="400" font-size="10"
        fill="${SILVER}" text-anchor="middle" letter-spacing="5" opacity="0.28">ENTREZ DANS LA ZONE</text>
</svg>`;

const TARGETS = [
  { file: 'server_icon.png',      svg: iconSvg,       w: 96,   h: 96  },
  { file: 'banner_detail.png',    svg: bannerSvg,     w: 900,  h: 200 },
  { file: 'banner_connecting.png', svg: connectingSvg, w: 1280, h: 720 },
];

(async () => {
  const browser = await chromium.launch({
    executablePath: process.env.PW_CHROME || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
    args: ['--no-sandbox'],
  });
  for (const t of TARGETS) {
    const page = await browser.newPage({ viewport: { width: t.w, height: t.h }, deviceScaleFactor: 1 });
    await page.setContent(
      `<!doctype html><meta charset="utf-8">
       <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap">
       <style>html,body{margin:0;padding:0;background:${BLACK};overflow:hidden}svg{display:block}</style>
       ${t.svg}`,
      { waitUntil: 'load' }
    );
    // laisser Inter s'installer avant la capture (sinon fallback Arial)
    await page.evaluate(() => document.fonts && document.fonts.ready);
    await page.waitForTimeout(400);
    await page.screenshot({ path: path.join(__dirname, t.file) });
    console.log(`OK ${t.file} (${t.w}x${t.h})`);
    await page.close();
  }
  await browser.close();
})().catch(e => { console.error(e); process.exit(1); });
