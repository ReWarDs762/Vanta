// =============================================
//   PVP INVENTORY — app.js
// =============================================

let MAX_WEIGHT   = 50.0; // default, updated from server via data.maxWeight
const STASH_MAX_KG = 20.0;

const ICONS = {
  bandage:'🩹', medkit:'💊',
  kevlar:'🛡️',
  weapon_pistol:'🔫', weapon_rifle:'⚔️', weapon_sniper:'🎯',
  weapon_grenade:'💣', weapon_shotgun:'💥',
  lockpick:'🔑', default:'📦',
};

const WEAPON_SET = new Set([
  'weapon_pistol','weapon_snspistol','weapon_vintagepistol','weapon_machinepistol',
  'weapon_combatpistol','weapon_heavypistol','weapon_revolver','weapon_doubleaction',
  'weapon_knife','weapon_bat','weapon_crowbar','weapon_switchblade','weapon_hatchet','weapon_machete',
  'weapon_pumpshotgun','weapon_sawnoffshotgun','weapon_dbshotgun','weapon_assaultshotgun',
  'weapon_microsmg','weapon_minismg','weapon_smg','weapon_combatpdw',
  'weapon_assaultrifle','weapon_carbinerifle','weapon_compactrifle',
  'weapon_combatmg','weapon_mg',
  'weapon_rpg','weapon_grenadelauncher','weapon_grenade',
  'weapon_sniperrifle',
]);

// ══ Poids items — MIROIR EXACT de server.lua ITEM_WEIGHTS ═══════════════
// NE PAS modifier ici : source de vérité = pvp_inventory/server/server.lua
const WEIGHTS = {
  // Consommables
  bandage:0.2, medkit:0.4, lockpick:0.1,
  // Kevlar
  kevlar:1.0,
  // Shots
  shot_repel:0.2, shot_attract:0.2, shot_speed:0.2, shot_health:0.2,
  // Munitions
  ammo_sniper:0.1,
  // Mêlée
  weapon_knife:0.3, weapon_bat:1.0, weapon_crowbar:1.2,
  weapon_switchblade:0.2, weapon_hatchet:0.8, weapon_machete:0.7,
  // Pistols (1 kg)
  weapon_molotov:0.4,
  weapon_appistol:1.0,
  weapon_pistol:1.0, weapon_pistol_mk2:1.0,
  weapon_snspistol:1.0, weapon_snspistol_mk2:1.0,
  weapon_vintagepistol:1.0, weapon_combatpistol:1.0, weapon_heavypistol:1.0,
  weapon_machinepistol:1.0,
  weapon_revolver:1.0, weapon_doubleaction:1.0,
  // SMG (2 kg)
  weapon_microsmg:2.0, weapon_minismg:2.0,
  weapon_smg:2.0, weapon_smg_mk2:2.0,
  weapon_combatpdw:2.0,
  // Shotguns
  weapon_pumpshotgun:3.0, weapon_sawnoffshotgun:2.5, weapon_dbshotgun:3.0,
  weapon_assaultshotgun:4.0,
  // Fusils d'assaut (4 kg)
  weapon_assaultrifle:4.0, weapon_carbinerifle:4.0, weapon_specialcarbine:4.0,
  weapon_assaultrifle_mk2:4.0, weapon_carbinerifle_mk2:4.0, weapon_specialcarbine_mk2:4.0,
  weapon_compactrifle:4.0,
  weapon_stungun:1.0,
  // MG (5 kg)
  weapon_combatmg:5.0, weapon_mg:5.0,
  weapon_combatmg_mk2:5.0,
  // Épic
  weapon_precisionrifle:4.0, weapon_compactlauncher:5.0, weapon_emplauncher:5.0,
  weapon_musket:4.0,
  // Légendaire (10 kg)
  weapon_sniperrifle:10.0, weapon_marksmanrifle_mk2:10.0,
  weapon_heavysniper:10.0, weapon_heavysniper_mk2:10.0,
  weapon_rpg:10.0, weapon_hominglauncher:10.0,
  weapon_grenadelauncher:6.5, weapon_grenade:0.4,
};

const EQUIP_TYPES = new Set([
  'kevlar',
  ...WEAPON_SET,
]);

function isVehicle(name) { return name && name.startsWith('vehicle_'); }

// ══ Rareté ═══════════════════════════════════════════════════════════════
const RARITY = {
  // Consommables
  bandage:'common', medkit:'uncommon', kevlar:'uncommon',
  ammo_sniper:'uncommon', lockpick:'common',
  // Mêlée
  weapon_knife:'common', weapon_bat:'common', weapon_crowbar:'common',
  weapon_switchblade:'common', weapon_hatchet:'common', weapon_machete:'common',
  // Pistolets
  weapon_pistol:'common', weapon_snspistol:'common',
  weapon_vintagepistol:'common', weapon_machinepistol:'common',
  weapon_combatpistol:'uncommon', weapon_heavypistol:'uncommon',
  weapon_revolver:'uncommon', weapon_doubleaction:'uncommon',
  // Shotguns + SMG
  weapon_pumpshotgun:'uncommon', weapon_sawnoffshotgun:'uncommon',
  weapon_dbshotgun:'uncommon', weapon_assaultshotgun:'uncommon',
  weapon_microsmg:'uncommon', weapon_minismg:'uncommon',
  weapon_smg:'uncommon', weapon_combatpdw:'uncommon',
  // Fusils
  weapon_assaultrifle:'rare', weapon_carbinerifle:'rare', weapon_compactrifle:'rare',
  weapon_combatmg:'rare', weapon_mg:'rare',
  // Légendaires
  weapon_rpg:'legendary', weapon_grenadelauncher:'legendary',
  weapon_grenade:'rare', weapon_sniperrifle:'legendary',
  // Véhicules communs
  vehicle_ratloader:'common', vehicle_bodhi2:'common', vehicle_emperor:'common',
  vehicle_tornado:'common', vehicle_bmx:'common', vehicle_blazer:'common',
  // Véhicules peu communs
  vehicle_sanchez:'uncommon', vehicle_bati:'uncommon', vehicle_mesa:'uncommon',
  vehicle_dubsta:'uncommon', vehicle_brawler:'uncommon', vehicle_kamacho:'uncommon',
  vehicle_kuruma:'uncommon', vehicle_buffalo:'uncommon',
  // Véhicules rares
  vehicle_insurgent:'rare', vehicle_buffalo3:'rare', vehicle_hellion:'rare',
  vehicle_dominator:'rare', vehicle_guardian:'rare', vehicle_nightshark:'rare',
  vehicle_baller3:'rare', vehicle_baller6:'rare',
  vehicle_schafter5:'rare', vehicle_schafter6:'rare',
  vehicle_deathbike:'rare', vehicle_dominator4:'rare', vehicle_impaler2:'rare',
  vehicle_imperator:'rare', vehicle_bruiser:'rare', vehicle_brutus:'rare',
  vehicle_scarab:'rare', vehicle_slamvan4:'rare', vehicle_zr380:'rare',
  // Véhicules légendaires
  vehicle_zentorno:'legendary', vehicle_t20:'legendary',
  vehicle_vigilante:'legendary', vehicle_oppressor2:'legendary',
};
function getRarity(n) { return RARITY[n] || 'common'; }
const RARITY_LABEL = { common:'', uncommon:'PEU COMMUN', rare:'RARE', legendary:'LÉGENDAIRE' };

// ══ Badges ════════════════════════════════════════════════════════════════
const BADGE_DEFS = {
  // Saison
  survivor_s1:   { label:'Survivant Saison 1', icon:'🏅', color:'#c8a840', tier:'season' },
  survivor_s2:   { label:'Survivant Saison 2', icon:'🏅', color:'#a0c840', tier:'season' },
  survivor_s3:   { label:'Survivant Saison 3', icon:'🏅', color:'#40a0c8', tier:'season' },
  // Kills PVP
  first_blood:   { label:'Premier Sang',        icon:'🩸', color:'#cc3333', tier:'common' },
  killer_10:     { label:'Tueur',               icon:'⚔️', color:'#aa7722', tier:'uncommon' },
  killer_50:     { label:'Chasseur',            icon:'🎯', color:'#4477bb', tier:'rare' },
  predator_100:  { label:'Prédateur',           icon:'💀', color:'#aa33cc', tier:'legendary' },
  // Zombies
  zombie_hunter: { label:'Chasseur Zombie',     icon:'🧟', color:'#4a7a4a', tier:'common' },
  exterminator:  { label:'Exterminateur',       icon:'☣️', color:'#6a8a3a', tier:'rare' },
  annihilator:   { label:'Annihilateur',        icon:'💣', color:'#bb4422', tier:'legendary' },
  // Streak
  streak_5:      { label:'Sur une Lancée',      icon:'🔥', color:'#cc6600', tier:'uncommon' },
  unstoppable:   { label:'Inarrêtable',         icon:'⚡', color:'#ddcc00', tier:'rare' },
  // Prestige
  prestige_1:    { label:'Prestige I',          icon:'✦',   color:'#888888', tier:'prestige' },
  prestige_2:    { label:'Prestige II',         icon:'✦✦',  color:'#cc9900', tier:'prestige' },
  prestige_3:    { label:'Prestige III',        icon:'✦✦✦', color:'#22aacc', tier:'prestige' },
  prestige_4:    { label:'Prestige IV',         icon:'★',   color:'#cc22aa', tier:'prestige' },
  prestige_5:    { label:'Prestige V — MAÎTRE', icon:'★★',  color:'#ff4400', tier:'prestige' },
};

const PRESTIGE_ROMAN = ['I','II','III','IV','V'];

// ══ Système XP / Niveaux ══════════════════════════════════════════════════
const XP_THRESHOLDS = [
    0, 100, 250, 500, 800, 1200, 1700, 2300, 3000, 4000,
    5200, 6600, 8200, 10000, 12000, 14500, 17500, 21000, 25000, 30000
];
const MAX_LEVEL = XP_THRESHOLDS.length; // 20

function calcLevel(xp) {
  let level = 1;
  for (let i = 1; i < XP_THRESHOLDS.length; i++) {
    if (xp >= XP_THRESHOLDS[i]) level = i + 1;
    else break;
  }
  return Math.min(level, MAX_LEVEL);
}

function xpProgressInfo(xp) {
  const level = calcLevel(xp);
  if (level >= MAX_LEVEL) {
    return { level, current: xp, needed: XP_THRESHOLDS[MAX_LEVEL-1], pct: 100, maxed: true };
  }
  const base = XP_THRESHOLDS[level - 1];
  const next = XP_THRESHOLDS[level];
  const current = xp - base;
  const needed  = next - base;
  return { level, current, needed, pct: Math.min(100, Math.round(current / needed * 100)), maxed: false };
}

function icon(n) {
  if (n.startsWith('weapon_')) {
    return `<img src="img/${n}.png" class="ic-img"/>`;
  }
  if (n.startsWith('vehicle_')) return `<img src="img/${n.replace('vehicle_','')}.png" class="ic-img"/>`;
  const fallback = (ICONS[n] || ICONS.default).replace(/'/g, "\\'");
  return `<img src="img/${n}.png" class="ic-img" onerror="this.outerHTML='${fallback}'"/>`;
}
function getWeight(n) {
  if (WEIGHTS[n]) return WEIGHTS[n];
  if (n.startsWith('vehicle_')) return 1.0; // miroir server.lua getItemWeight
  return 0;
}
const wOf  = (n, qty) => (getWeight(n) * qty).toFixed(1);

// Items du kit de départ — invendables sur le marché
const KIT_ITEMS = new Set(['weapon_pistol', 'vehicle_bmx']);

// ══ Catalogue marché — items disponibles ingame (CLAUDE.md) ══════════════
const CATALOG = [
  // ── Équipement ──
  { name:'bandage',     label:'Bandage' },
  { name:'medkit',      label:'Medkit' },
  { name:'kevlar',      label:'Kevlar' },
  { name:'ammo_sniper', label:'Munitions Sniper' },
  // ── Mêlée (Commun) ──
  { name:'weapon_knife',        label:'Couteau' },
  { name:'weapon_bat',          label:'Batte' },
  { name:'weapon_crowbar',      label:'Pied-de-biche' },
  { name:'weapon_switchblade',  label:'Cran d\'arrêt' },
  { name:'weapon_hatchet',      label:'Hachette' },
  { name:'weapon_machete',      label:'Machette' },
  // ── Pistolets communs ──
  { name:'weapon_pistol',        label:'Pistol' },
  { name:'weapon_snspistol',     label:'SNS Pistol' },
  { name:'weapon_vintagepistol', label:'Vintage Pistol' },
  { name:'weapon_machinepistol', label:'Machine Pistol' },
  // ── Pistolets peu communs ──
  { name:'weapon_combatpistol',  label:'Combat Pistol' },
  { name:'weapon_heavypistol',   label:'Heavy Pistol' },
  { name:'weapon_revolver',      label:'Revolver' },
  { name:'weapon_doubleaction',  label:'Double Action' },
  // ── Shotguns (Peu commun) ──
  { name:'weapon_pumpshotgun',    label:'Pump Shotgun' },
  { name:'weapon_sawnoffshotgun', label:'Sawed-Off Shotgun' },
  { name:'weapon_dbshotgun',      label:'Double Barrel Shotgun' },
  { name:'weapon_assaultshotgun', label:'Assault Shotgun' },
  // ── SMG (Peu commun) ──
  { name:'weapon_microsmg',  label:'Micro SMG' },
  { name:'weapon_minismg',   label:'Mini SMG' },
  { name:'weapon_smg',       label:'SMG' },
  { name:'weapon_combatpdw', label:'Combat PDW' },
  // ── Fusils d'assaut (Rare) ──
  { name:'weapon_assaultrifle', label:'Assault Rifle' },
  { name:'weapon_carbinerifle', label:'Carbine Rifle' },
  { name:'weapon_compactrifle', label:'Compact Rifle' },
  // ── Mitrailleuses (Rare) ──
  { name:'weapon_combatmg', label:'Combat MG' },
  { name:'weapon_mg',        label:'MG' },
  // ── Légendaires ──
  { name:'weapon_rpg',             label:'RPG' },
  { name:'weapon_grenadelauncher', label:'Lance-Grenades' },
  { name:'weapon_grenade',         label:'Grenade' },
  { name:'weapon_sniperrifle',     label:'Sniper Rifle' },
  // ── Véhicules communs ──
  { name:'vehicle_ratloader', label:'Rat-Loader' },
  { name:'vehicle_bodhi2',    label:'Bodhi' },
  { name:'vehicle_emperor',   label:'Emperor' },
  { name:'vehicle_tornado',   label:'Tornado' },
  { name:'vehicle_bmx',       label:'BMX' },
  { name:'vehicle_blazer',    label:'Blazer' },
  // ── Véhicules peu communs ──
  { name:'vehicle_sanchez', label:'Sanchez' },
  { name:'vehicle_bati',    label:'Bati 801' },
  { name:'vehicle_mesa',    label:'Mesa' },
  { name:'vehicle_dubsta',  label:'Dubsta' },
  { name:'vehicle_brawler', label:'Brawler' },
  { name:'vehicle_kamacho', label:'Kamacho' },
  { name:'vehicle_kuruma',  label:'Kuruma' },
  { name:'vehicle_buffalo', label:'Buffalo' },
  // ── Véhicules rares ──
  { name:'vehicle_insurgent',  label:'Insurgent' },
  { name:'vehicle_buffalo3',   label:'Buffalo S' },
  { name:'vehicle_hellion',    label:'Hellion' },
  { name:'vehicle_dominator',  label:'Dominator' },
  { name:'vehicle_guardian',   label:'Guardian' },
  { name:'vehicle_nightshark', label:'Nightshark' },
  // ── Véhicules rares — blindés ──
  { name:'vehicle_baller3',   label:'Baller Blindé' },
  { name:'vehicle_baller6',   label:'Baller LE Blindé' },
  { name:'vehicle_schafter5', label:'Schafter V12 Blindé' },
  { name:'vehicle_schafter6', label:'Schafter LWB Blindé' },
  // ── Véhicules rares — apocalypse ──
  { name:'vehicle_deathbike',  label:'Deathbike' },
  { name:'vehicle_dominator4', label:'Dominator Apocalypse' },
  { name:'vehicle_impaler2',   label:'Impaler Apocalypse' },
  { name:'vehicle_imperator',  label:'Imperator' },
  { name:'vehicle_bruiser',    label:'Bruiser' },
  { name:'vehicle_brutus',     label:'Brutus' },
  { name:'vehicle_slamvan4',   label:'Slamvan Apocalypse' },
  { name:'vehicle_zr380',      label:'ZR380' },
  // ── Véhicules légendaires ──
  { name:'vehicle_deluxo',     label:'Deluxo' },
  { name:'vehicle_scarab',     label:'Scarab' },
  { name:'vehicle_vigilante',  label:'Vigilante' },
  { name:'vehicle_oppressor2', label:'Oppressor MK II' },
];

let hotbar = [null,null,null,null,null,null,null,null];
let state  = { inventory:[], stash:[], money:{}, profile:{}, market:[], myListings:[] };
let outpostMode   = null; // null | { id, label, items }
let dropMode      = null; // null | { id, label, items }
let deathBagMode  = null; // null | { id, label, items }
let ctxItem = null, ctxSource = 'inv', toastT = null;
let marketMode = 'browse'; // 'browse' | 'sell'
let selectedMarketItem = null; // item_name selected in browse mode
let selectedSellItem = null;   // {name, label, maxQty} in sell mode
let settings = { opacity:80, blur:0, hudType:'gta' };
let inSafeZone = false; // mis à jour par le client Lua
let leaderboardData = { players: [], crews: [], myIdentifier: null, myCrewId: null };
let leaderboardType = 'players'; // players | crews
let leaderboardCategory = 'kills'; // kills | deaths | zombies | kd
let leaderboardLoaded = false;

// ══ Drag custom ═══════════════════════════════════════════════════════════
let dragging    = null;
let dragGhost   = null;
let dragOffsetX = 0;
let dragOffsetY = 0;
let dragRafId   = null;   // requestAnimationFrame id pour throttler mousemove
let pendingX    = 0;
let pendingY    = 0;

// ── Stagger d'entrée (seulement à l'ouverture, pas après chaque renderGrid) ──
function triggerEntranceAnim() {
  const gm = document.getElementById('grid-main');
  const gs = document.getElementById('grid-stash');
  if (!gm || !gs) return;
  gm.classList.add('entrance');
  gs.classList.add('entrance');
  // Retirer après la fin du dernier stagger (100ms delay + 180ms anim + 120ms marge)
  setTimeout(() => {
    gm.classList.remove('entrance');
    gs.classList.remove('entrance');
  }, 420);
}

// ══ Sons (désactivés) ════════════════════════════════════════════════════
function sndUse()   {}
function sndDrop()  {}
function sndStash() {}
function sndClick() {}
function sndError() {}

// ══ Lua → NUI ════════════════════════════════════════════════════════════
window.addEventListener('message', e => {
  const {type, data} = e.data;
  if      (type==='open')        openUI(data);
  else if (type==='openOutpost') openOutpostUI(data);
  else if (type==='openDrop')    openDropUI(data);
  else if (type==='close')       forceClose();
  else if (type==='refresh')     onRefresh(data);
  else if (type==='notify')      { transferLocked = false; toast(e.data.msg, e.data.success); }
  else if (type==='refreshOutpostStash') {
    transferLocked = false;
    if (outpostMode) { outpostMode.items = data.items; renderInventory(); }
  }
  else if (type==='refreshDrop') {
    transferLocked = false;
    if (dropMode) {
      if (data.dropItems !== undefined) { dropMode.items = data.dropItems; }
      if (data.inventory)  { state = {...state, inventory: data.inventory}; }
      renderInventory();
    }
  }
  else if (type==='openDeathBag') openDeathBagUI(data);
  else if (type==='refreshDeathBag') {
    transferLocked = false;
    if (deathBagMode) {
      if (data.bagItems !== undefined) { deathBagMode.items = data.bagItems; }
      if (data.inventory) { state = {...state, inventory: data.inventory}; }
      renderInventory();
    }
  }
  else if (type==='setSafeZone') inSafeZone = data.inSafeZone;
  else if (type==='toastBadge') {
    const b = BADGE_DEFS[e.data.badgeId];
    if (b) toast('🏆 Badge débloqué : ' + b.icon + ' ' + b.label, true);
    // Rafraîchir les badges si le profil est ouvert
    if (state.profile && state.profile.badgesUnlocked) {
      if (!state.profile.badgesUnlocked.includes(e.data.badgeId))
        state.profile.badgesUnlocked.push(e.data.badgeId);
      renderBadgesGrid(state.profile.badgesUnlocked, state.profile.activeBadge||'');
    }
  }
  else if (type==='healStart')   showHealBar(e.data);
  else if (type==='healEnd')     hideHealBar();
  // VANTA HUD overlay
  else if (type==='vantaHud')    handleVantaHud(e.data);
  // Échange direct
  else if (type==='openTrade') openTradeWindow(data);
  else if (type==='updatePartnerOffer') updatePartnerOfferUI(data);
  else if (type==='partnerConfirmed') onPartnerConfirmed();
  else if (type==='tradeConfirmReset') onTradeConfirmReset();
  else if (type==='tradeClosed') closeTradeWindow();
});

function openUI(data) {
  outpostMode  = null;
  dropMode     = null;
  deathBagMode = null;
  if (data.maxWeight) MAX_WEIGHT = data.maxWeight;
  state = {...state, ...data};
  leaderboardLoaded = false;
  marketMode = 'browse';
  selectedMarketItem = null;
  selectedSellItem = null;
  // Restaurer la hotbar sauvegardée depuis le serveur
  if (data.savedHotbar && typeof data.savedHotbar === 'object') {
    for (let i = 0; i < 8; i++) {
      const slot = data.savedHotbar[String(i+1)] || null;
      hotbar[i] = (slot && slot.name) ? { name: slot.name, label: slot.label } : null;
    }
  }
  // Restaurer la préférence HUD depuis le serveur (priorité sur localStorage)
  if (data.hudType && (data.hudType === 'gta' || data.hudType === 'vanta')) {
    settings.hudType = data.hudType;
    updateHudToggleUI();
    try { localStorage.setItem('pvp_inv_settings', JSON.stringify(settings)); } catch(e) {}
  }
  // Afficher l'overlay EN PREMIER — le browser peut peindre immédiatement
  // renderAll() après : l'animation d'entrée se joue pendant le rendu
  document.getElementById('overlay').classList.add('open');
  switchTab(data.startTab || 'inventory');
  triggerEntranceAnim();
  renderAll();
}

function openOutpostUI(data) {
  outpostMode  = { id: data.outpostId, label: data.outpostLabel || 'COFFRE AVANT-POSTE', items: data.outpostItems || [] };
  dropMode     = null;
  deathBagMode = null;
  state = {...state, inventory: data.inventory || [], money: data.money || state.money };
  leaderboardLoaded = false;
  document.getElementById('overlay').classList.add('open');
  switchTab('inventory');
  triggerEntranceAnim();
  renderAll();
}

function openDropUI(data) {
  dropMode      = { id: data.dropId, label: data.dropLabel || '★ DROP DE RAVITAILLEMENT', items: data.dropItems || [] };
  outpostMode   = null;
  deathBagMode  = null;
  state = {...state, inventory: data.inventory || [], money: data.money || state.money };
  leaderboardLoaded = false;
  document.getElementById('overlay').classList.add('open');
  switchTab('inventory');
  triggerEntranceAnim();
  renderAll();
}

function openDeathBagUI(data) {
  deathBagMode  = { id: data.bagId, label: data.bagLabel || 'SAC DE LOOT', items: data.bagItems || [] };
  dropMode      = null;
  outpostMode   = null;
  state = {...state, inventory: data.inventory || [], money: data.money || state.money };
  if (data.maxWeight) MAX_WEIGHT = data.maxWeight;
  leaderboardLoaded = false;
  document.getElementById('overlay').classList.add('open');
  switchTab('inventory');
  triggerEntranceAnim();
  renderAll();
}

function closeUI() {
  const hadDrop     = !!dropMode;
  const hadDeathBag = !!deathBagMode;
  outpostMode  = null;
  dropMode     = null;
  deathBagMode = null;
  document.getElementById('overlay').classList.remove('open');
  closeCtx();
  if (hadDeathBag) {
    fetch('https://pvp_inventory/closeDeathBag', {method:'POST', body:'{}'});
  } else if (hadDrop) {
    fetch('https://pvp_inventory/closeDrop', {method:'POST', body:'{}'});
  } else {
    fetch('https://pvp_inventory/close', {method:'POST', body:'{}'});
  }
}
function forceClose() {
  transferLocked = false;
  outpostMode  = null;
  dropMode     = null;
  deathBagMode = null;
  document.getElementById('overlay').classList.remove('open');
  closeCtx();
}
function onRefresh(data) {
  transferLocked = false; // débloquer le verrou de transfert
  if (data.maxWeight) MAX_WEIGHT = data.maxWeight;
  const hasMarket = data.market !== undefined;
  state = {...state, ...data};
  renderInventory();
  renderMoney();
  if (hasMarket) renderMarket();
}

// ══ Rendu ════════════════════════════════════════════════════════════════
function renderAll() {
  // Rend l'onglet actif en priorité, diffère les onglets cachés au frame suivant
  renderMoney();
  renderInventory();
  requestAnimationFrame(() => {
    renderMarket();
    renderProfile();
    // renderLeaderboard est lazy (loadLeaderboard au clic de tab) — pas besoin ici
  });
}

function renderMoney() {
  const b = state.money.bank||0;
  document.getElementById('tb-bank').textContent = fmt(b);
  document.getElementById('sb').textContent = fmt(b);
}

function fmt(n) { return Number(n).toLocaleString('fr-FR'); }

function renderInventory() {
  const inv = state.inventory || [];
  let total = 0;
  inv.forEach(i => { total += getWeight(i.name) * i.count; });
  total = Math.min(total, MAX_WEIGHT);
  const pct = Math.min(100, total / MAX_WEIGHT * 100);

  document.getElementById('weight-display').textContent =
    total.toFixed(1) + ' / ' + MAX_WEIGHT.toFixed(1) + ' kg';
  const bar = document.getElementById('weight-bar');
  bar.style.width = pct + '%';
  bar.className   = pct >= 90 ? 'danger' : pct >= 70 ? 'warn' : '';

  // Layout côte-à-côte si mode externe (outpost / drop / deathbag)
  const viewEl = document.getElementById('view-inventory');
  if (viewEl) {
    if (outpostMode || dropMode || deathBagMode) {
      viewEl.classList.add('mode-external');
    } else {
      viewEl.classList.remove('mode-external');
    }
  }

  renderGrid('grid-main', inv, 'inv');
  renderStash();
  renderHotbar();
}

function renderStash() {
  const titleEl = document.querySelector('#inv-right .sec-title');
  const weightEl = document.getElementById('stash-weight');
  const sbar = document.getElementById('stash-bar');

  if (deathBagMode) {
    if (titleEl) titleEl.textContent = deathBagMode.label;
    weightEl.textContent = deathBagMode.items.length + ' item(s) disponible(s)';
    sbar.style.width = '0%';
    sbar.className = '';
    renderGrid('grid-stash', deathBagMode.items, 'deathbag');
  } else if (dropMode) {
    if (titleEl) titleEl.textContent = dropMode.label;
    weightEl.textContent = dropMode.items.length + ' item(s) disponible(s)';
    sbar.style.width = '0%';
    sbar.className = '';
    renderGrid('grid-stash', dropMode.items, 'drop');
  } else if (outpostMode) {
    // Coffre avant-poste : sans limite de poids
    if (titleEl) titleEl.textContent = outpostMode.label;
    weightEl.textContent = 'Sans limite de poids';
    sbar.style.width = '0%';
    sbar.className = '';
    renderGrid('grid-stash', outpostMode.items, 'outpost');
  } else {
    // Conteneur protégé personnel
    if (titleEl) titleEl.textContent = 'CONTENEUR PROTÉGÉ';
    const stash = state.stash || [];
    let stashW = 0;
    stash.forEach(i => { stashW += getWeight(i.name) * i.count; });
    stashW = Math.min(stashW, STASH_MAX_KG);
    const pctS = Math.min(100, stashW / STASH_MAX_KG * 100);
    weightEl.textContent = stashW.toFixed(1) + ' / ' + STASH_MAX_KG.toFixed(1) + ' kg';
    sbar.style.width = pctS + '%';
    sbar.className = pctS >= 90 ? 'danger' : '';
    renderGrid('grid-stash', stash, 'stash');
  }
}

function renderGrid(id, items, source) {
  const el = document.getElementById(id);
  if (!items.length) {
    const icons = {
      inv:      `<svg class="grid-empty-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.2"><path d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z"/></svg>`,
      stash:    `<svg class="grid-empty-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.2"><path d="M3 6h18v4H3zM3 10v10h18V10"/><path d="M10 14h4"/></svg>`,
      outpost:  `<svg class="grid-empty-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.2"><path d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/></svg>`,
      drop:     `<svg class="grid-empty-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.2"><path d="M12 2l4 8H8l4-8z"/><rect x="4" y="10" width="16" height="10" rx="1"/></svg>`,
      deathbag: `<svg class="grid-empty-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.2"><path d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z"/></svg>`,
    };
    const titles = {
      inv:      'SAC VIDE',
      stash:    'COFFRE VIDE',
      outpost:  'COFFRE VIDE',
      drop:     'CAISSE VIDE',
      deathbag: 'SAC VIDE',
    };
    const subs = {
      inv:      'Loote des zombies pour obtenir des items',
      stash:    'Transfère des items depuis ton sac',
      outpost:  '',
      drop:     '',
      deathbag: '',
    };
    const src = source || 'inv';
    el.innerHTML = `<div class="grid-empty">
      ${icons[src] || icons.inv}
      <div class="grid-empty-title">${titles[src] || 'VIDE'}</div>
      ${subs[src] ? `<div class="grid-empty-sub">${subs[src]}</div>` : ''}
    </div>`;
    return;
  }
  el.innerHTML = items.map(item => {
    const w = wOf(item.name, item.count);
    const src = source || 'inv';
    const r = getRarity(item.name);
    const rTag = RARITY_LABEL[r] ? `<span class="rarity-tag ${r}">${RARITY_LABEL[r]}</span>` : '';
    return `
    <div class="item-card" data-rarity="${r}"
         data-name="${esc(item.name)}" data-label="${esc(item.label)}" data-count="${item.count}" data-source="${src}"
         onmousedown="startDrag(event,'${esc(item.name)}','${esc(item.label)}')"
         oncontextmenu="quickStash(event,'${esc(item.name)}','${src}')">
      ${rTag}
      <span class="ic-qty">×${item.count}</span>
      <span class="ic-icon">${icon(item.name)}</span>
      <span class="ic-name">${item.label}</span>
      <span class="ic-w">${w}kg</span>
    </div>`;
  }).join('');
}

// ── Verrou de transfert : bloque les clics rapides jusqu'à la confirmation serveur ──
let transferLocked = false;

function optimisticMove(itemName, from, to) {
  const srcIdx = from.findIndex(i => i.name === itemName);
  if (srcIdx === -1) return;
  const src = from[srcIdx];
  if (src.count <= 1) { from.splice(srcIdx, 1); }
  else                { src.count--; }
  const dstIdx = to.findIndex(i => i.name === itemName);
  if (dstIdx >= 0) { to[dstIdx].count++; }
  else             { to.push({ name: itemName, label: src.label, count: 1 }); }
  renderInventory();
}

// ── Coffre Avant-Poste → redirigé vers le CONTENEUR PROTÉGÉ global ──────
// Le conteneur protégé est le même pour tous les avant-postes (pvp_player_stash).
// Les fonctions ci-dessous sont gardées pour compatibilité mais ne font rien de spécial.

// ── Hotbar ────────────────────────────────────────────────────────────────
const HOTBAR_LABELS = ['1','2','3','4','5','6','7'];
function renderHotbar() {
  for (let i = 0; i < 7; i++) {
    const slot = document.getElementById('hs'+i);
    if (!slot) continue;
    const item = hotbar[i];
    const inInv = item && (state.inventory||[]).find(x => x.name === item.name);
    if (item && inInv) {
      slot.className = 'hs filled';
      slot.innerHTML = `<span class="ic-qty">×${inInv.count}</span><span class="ic-icon">${icon(item.name)}</span>`;
    } else {
      if (item) hotbar[i] = null;
      slot.className = 'hs';
      slot.innerHTML = '';
    }
  }
}

function syncHotbarToLua() {
  const obj = {};
  for (let i = 0; i < 8; i++) {
    if (hotbar[i]) obj[String(i+1)] = { name: hotbar[i].name, label: hotbar[i].label };
  }
  lua('syncHotbar', { hotbar: obj });
}

// ══ Marché ════════════════════════════════════════════════════════════════
function getItemType(name) {
  if (!name) return 'Équipement';
  if (name.startsWith('weapon_')) return 'Arme';
  if (name.startsWith('vehicle_')) return 'Véhicule';
  return 'Équipement';
}

function renderMarket() {
  document.getElementById('market-zone-warn').style.display = inSafeZone ? 'none' : 'block';
  if (marketMode === 'sell') {
    renderMarketSellMode();
  } else {
    renderMarketBrowse();
  }
}

function toggleMarketMode() {
  marketMode = marketMode === 'browse' ? 'sell' : 'browse';
  selectedMarketItem = null;
  selectedSellItem = null;
  renderMarket();
}

// ── Browse mode ──────────────────────────────────────────────────────────
function renderMarketBrowse() {
  const leftEl  = document.getElementById('market-left');
  const rightEl = document.getElementById('market-right');

  // LEFT panel — catalogue complet
  leftEl.innerHTML = `
    <div class="sec-header">
      <span class="sec-title">MARCHÉ</span>
    </div>
    <div class="sec-sub">Tous les items du serveur</div>
    <div class="mkt-toolbar">
      <input class="mkt-search" type="text" placeholder="Rechercher..." id="mkt-search-input" oninput="filterMarketItems()"/>
      <select class="mkt-filter" id="mkt-filter-select" onchange="filterMarketItems()">
        <option value="all">Tous</option>
        <option value="Équipement">Équipement</option>
        <option value="Arme">Armes</option>
        <option value="Véhicule">Véhicules</option>
      </select>
      <button class="btn-accent" onclick="toggleMarketMode()">Mes offres</button>
    </div>
    <div id="mkt-browse-table-wrap"></div>
  `;

  renderMarketTable();
  renderMarketOffers();
}

function getOfferCounts() {
  const listings = (state.market||[]);
  const counts = {};
  listings.forEach(l => {
    if (!counts[l.item_name]) counts[l.item_name] = { qty: 0, minPrice: Infinity };
    counts[l.item_name].qty += l.quantity;
    counts[l.item_name].minPrice = Math.min(counts[l.item_name].minPrice, l.price);
  });
  return counts;
}

function renderMarketTable() {
  const offerCounts = getOfferCounts();

  // Build catalog items with offer info
  let items = CATALOG.map(c => ({
    name: c.name,
    label: c.label,
    type: getItemType(c.name),
    rarity: getRarity(c.name),
    offers: offerCounts[c.name] ? offerCounts[c.name].qty : 0,
    minPrice: offerCounts[c.name] ? offerCounts[c.name].minPrice : 0,
  }));

  // Apply filters
  const searchEl = document.getElementById('mkt-search-input');
  const filterEl = document.getElementById('mkt-filter-select');
  const search = searchEl ? searchEl.value.toLowerCase() : '';
  const filter = filterEl ? filterEl.value : 'all';

  if (search) items = items.filter(i => i.label.toLowerCase().includes(search) || i.name.toLowerCase().includes(search));
  if (filter !== 'all') items = items.filter(i => i.type === filter);

  const wrap = document.getElementById('mkt-browse-table-wrap');
  if (!wrap) return;

  wrap.innerHTML = `
    <table class="mkt-table">
      <thead><tr>
        <th>NOM</th><th>TYPE</th><th class="mkt-th-icon">ITEM</th><th class="mkt-th-num">QTÉ</th>
      </tr></thead>
      <tbody>
        ${items.map(i => `
          <tr class="${selectedMarketItem === i.name ? 'mkt-selected' : ''} ${i.offers ? '' : 'mkt-no-offer'}" onclick="selectMarketItem('${esc(i.name)}')">
            <td class="mkt-td-name">${esc(i.label)}</td>
            <td class="mkt-td-type">${i.type}</td>
            <td class="mkt-td-icon"><span class="mkt-item-cell">${icon(i.name)}</span></td>
            <td class="mkt-td-num">${i.offers ? '<span class="mkt-qty-has">' + i.offers + '</span>' : '<span class="mkt-qty-none">—</span>'}</td>
          </tr>
        `).join('')}
      </tbody>
    </table>
  `;
}

function filterMarketItems() {
  renderMarketTable();
}

function selectMarketItem(itemName) {
  selectedMarketItem = selectedMarketItem === itemName ? null : itemName;
  renderMarketTable();
  renderMarketOffers();
}

function deselectMarketItem() {
  selectedMarketItem = null;
  renderMarketTable();
  renderMarketOffers();
}

function renderMarketOffers() {
  const rightEl = document.getElementById('market-right');
  if (!selectedMarketItem) {
    rightEl.innerHTML = `
      <div class="sec-header"><span class="sec-title">OFFRES</span></div>
      <div class="sec-sub">Sélectionne un article à gauche</div>
      <div class="grid-empty">AUCUN ARTICLE SÉLECTIONNÉ</div>
    `;
    return;
  }

  const offers = (state.market||[]).filter(l => l.item_name === selectedMarketItem);
  const myIds = new Set((state.myListings||[]).map(l=>l.id));

  const catItem = CATALOG.find(c => c.name === selectedMarketItem);
  const label = catItem ? catItem.label : selectedMarketItem;

  rightEl.innerHTML = `
    <div class="sec-header">
      <span class="sec-title">OFFRES</span>
      <button class="btn-accent" onclick="deselectMarketItem()">RETOUR</button>
    </div>
    <div class="sec-sub">Toutes les offres pour cet article</div>
    <div class="mkt-offer-preview">
      <div class="mkt-offer-preview-img">${icon(selectedMarketItem)}</div>
      <div class="mkt-offer-preview-name">${esc(label)}</div>
    </div>
    ${offers.length ? `
      <table class="mkt-offer-table">
        <thead><tr><th>ACTION</th><th>VENDEUR</th><th>PRIX</th><th>QTÉ</th></tr></thead>
        <tbody>
          ${offers.map(o => {
            const isMine = myIds.has(o.id);
            return `
            <tr${isMine ? ' class="mkt-offer-mine"' : ''}>
              <td class="mkt-offer-action">${isMine
                ? '<span class="mkt-own-tag">MON OFFRE</span>'
                : '<button class="btn-buy" onclick="buyListing('+o.id+')">ACHETER</button>'}</td>
              <td class="mkt-offer-seller">${esc(o.seller_name)}</td>
              <td class="mkt-offer-price">$ ${fmt(o.price)}</td>
              <td class="mkt-offer-qty">${o.quantity}</td>
            </tr>`;
          }).join('')}
        </tbody>
      </table>
    ` : '<div class="grid-empty">AUCUNE OFFRE POUR CET ARTICLE</div>'}
  `;
}

// ── Sell mode ────────────────────────────────────────────────────────────
function renderMarketSellMode() {
  const leftEl  = document.getElementById('market-left');
  const rightEl = document.getElementById('market-right');

  // Inventory items (filtrer kit items)
  const inv = (state.inventory || []).filter(i => !KIT_ITEMS.has(i.name));

  leftEl.innerHTML = `
    <div class="sec-header">
      <span class="sec-title">INVENTAIRE</span>
    </div>
    <div class="sec-sub">Items dans votre inventaire</div>
    <div class="mkt-sell-grid">
      ${inv.length ? inv.map(i => `
        <div class="mkt-sell-card ${selectedSellItem && selectedSellItem.name === i.name ? 'mkt-sell-selected' : ''}"
             onclick="selectSellItem('${esc(i.name)}','${esc(i.label)}',${i.count})">
          <span class="ic-qty">x${i.count}</span>
          <span class="ic-icon">${icon(i.name)}</span>
          <span class="ic-name">${i.label}</span>
        </div>
      `).join('') : '<div class="grid-empty">INVENTAIRE VIDE</div>'}
    </div>

    <div class="sec-header" style="margin-top:8px">
      <span class="sec-title">MES OFFRES</span>
    </div>
    <div class="sec-sub">Offres actives sur le marché</div>
    <div style="display:flex;gap:6px;margin-bottom:8px">
      <button class="btn-green" onclick="refreshMarketData()">Actualiser</button>
      <button class="btn-accent" onclick="claimSales()">Réclamer mes ventes</button>
    </div>
    <div id="mkt-my-listings-list" class="market-list">
      ${renderMyListingsHTML()}
    </div>
  `;

  renderCreatePanel();
}

function renderMyListingsHTML() {
  const mine = state.myListings || [];
  if (!mine.length) return '<div class="grid-empty">AUCUNE OFFRE</div>';
  return mine.map(l => `
    <div class="my-row">
      <div class="mr-info">${icon(l.item_name || '')} ${l.item_label} x${l.quantity}</div>
      <div class="mr-price">$ ${fmt(l.price)}</div>
      <button class="btn-cancel-s" onclick="cancelList(${l.id})">✕</button>
    </div>
  `).join('');
}

function selectSellItem(name, label, maxQty) {
  if (selectedSellItem && selectedSellItem.name === name) {
    selectedSellItem = null;
  } else {
    selectedSellItem = { name, label, maxQty };
  }
  renderMarketSellMode();
}

function renderCreatePanel() {
  const rightEl = document.getElementById('market-right');
  if (!selectedSellItem) {
    rightEl.innerHTML = `
      <div class="sec-header">
        <span class="sec-title">CRÉER UNE OFFRE</span>
        <button class="btn-accent" onclick="toggleMarketMode()">Retour</button>
      </div>
      <div class="sec-sub">Sélectionnez un item à gauche</div>
      <div class="grid-empty">AUCUN ITEM SÉLECTIONNÉ</div>
    `;
    return;
  }

  // Find similar offers
  const similar = (state.market || []).filter(l => l.item_name === selectedSellItem.name);

  rightEl.innerHTML = `
    <div class="sec-header">
      <span class="sec-title">CRÉER UNE OFFRE</span>
      <button class="btn-accent" onclick="toggleMarketMode()">Retour</button>
    </div>
    <div class="mkt-offer-img">${icon(selectedSellItem.name)}</div>
    <div class="mkt-create-form">
      <label>Nom</label>
      <input type="text" value="${selectedSellItem.label}" readonly/>
      <div class="form-row">
        <div class="form-col">
          <label>Prix ($)</label>
          <input type="number" id="mkt-sell-price" min="1" value="100"/>
        </div>
        <div class="form-col">
          <label>Quantité (max ${selectedSellItem.maxQty})</label>
          <input type="number" id="mkt-sell-qty" min="1" max="${selectedSellItem.maxQty}" value="1"/>
        </div>
      </div>
      <div class="form-btns">
        <button class="btn-cancel" onclick="selectedSellItem=null;renderMarketSellMode()">Retour</button>
        <button class="btn-confirm" onclick="submitCreateOffer()">Confirmer</button>
      </div>
    </div>

    <div class="sec-header" style="margin-top:14px">
      <span class="sec-title">OFFRES SIMILAIRES</span>
    </div>
    <div class="sec-sub">Double clic pour acheter/vendre</div>
    ${similar.length ? `
      <table class="mkt-offer-table">
        <thead><tr><th>VENDEUR</th><th>PRIX</th><th>QTÉ</th></tr></thead>
        <tbody>
          ${similar.map(s => `
            <tr>
              <td style="font-size:10px">${s.seller_name}</td>
              <td class="green" style="font-family:var(--fh)">$ ${fmt(s.price)}</td>
              <td>${s.quantity}</td>
            </tr>
          `).join('')}
        </tbody>
      </table>
    ` : '<div class="grid-empty">AUCUNE OFFRE SIMILAIRE</div>'}
  `;
}

function submitCreateOffer() {
  if (!inSafeZone) { toast('Ventes uniquement en zone safe !', false); return; }
  if (!selectedSellItem) { toast('Sélectionne un item à gauche !', false); return; }
  const priceEl = document.getElementById('mkt-sell-price');
  const qtyEl   = document.getElementById('mkt-sell-qty');
  if (!priceEl || !qtyEl) return;
  const price = Math.max(1, parseInt(priceEl.value) || 1);
  const qty   = Math.max(1, Math.min(selectedSellItem.maxQty, parseInt(qtyEl.value) || 1));
  lua('createListing', { item: selectedSellItem.name, label: selectedSellItem.label, qty, price });
  toast('Offre mise en vente !', true);
  selectedSellItem = null;
  // Rafraîchir les données après que le serveur ait traité la vente
  setTimeout(function() { lua('refreshMarket', {}); }, 500);
}

function refreshMarketData() {
  lua('refreshMarket', {});
}

function claimSales() {
  lua('claimSales', {});
}

// ══ Profil ════════════════════════════════════════════════════════════════
function renderProfile() {
  const p = state.profile||{};
  const name = ((p.firstName||'')+' '+(p.lastName||'')).trim()||'Joueur';
  document.getElementById('tb-name').textContent = name;
  document.getElementById('pname').textContent   = name;
  document.getElementById('pid').textContent     = p.identifier||'';

  // Stats principales
  document.getElementById('sk').textContent  = p.kills||0;
  document.getElementById('sd').textContent  = p.deaths||0;
  document.getElementById('skd').textContent = p.kd||0;
  document.getElementById('sz').textContent  = p.zombies||0;

  // Kill streak record
  const streakEl = document.getElementById('pstreak');
  if (streakEl) streakEl.textContent = p.killStreakRecord||0;

  // XP + Niveau — données depuis vanta_xp si disponible, sinon fallback local
  const vxp = p.vantaXP || null;
  let xpLevel, xpCurrent, xpNeeded, xpPct, xpMaxed, prestige, prestigeLabel;
  if (vxp) {
    xpLevel      = vxp.level           || 1;
    xpCurrent    = vxp.xp_in_level     || 0;
    xpNeeded     = vxp.xp_to_next      || 0;
    xpPct        = vxp.xp_percent      || 0;
    xpMaxed      = vxp.can_prestige    || false;
    prestige     = vxp.prestige_level  || 0;
    prestigeLabel = vxp.prestige_label || '';
  } else {
    const info   = xpProgressInfo(p.xp||0);
    xpLevel      = info.level;
    xpCurrent    = info.current;
    xpNeeded     = info.needed;
    xpPct        = info.pct;
    xpMaxed      = info.maxed;
    prestige     = p.prestige || 0;
    prestigeLabel = prestige > 0 ? 'PRESTIGE ' + (PRESTIGE_ROMAN[prestige-1]||prestige) : '';
  }

  const levelEl = document.getElementById('pxp-level');
  const valEl   = document.getElementById('pxp-val');
  const fillEl  = document.getElementById('pxp-fill');
  const lblEl   = document.getElementById('pxp-level-label');
  if (levelEl) levelEl.textContent = xpLevel;
  if (fillEl)  fillEl.style.width  = xpPct + '%';
  if (valEl) {
    if (xpMaxed) valEl.textContent = 'NIVEAU MAX — Prestige disponible !';
    else valEl.textContent = xpCurrent + ' / ' + xpNeeded + ' XP';
  }
  if (lblEl) lblEl.innerHTML = 'NIVEAU <span id="pxp-level">' + xpLevel + '</span>';

  // Label prestige
  const prestigeEl = document.getElementById('pprestige-label');
  if (prestigeEl) {
    if (prestige > 0) {
      prestigeEl.textContent = prestigeLabel || ('PRESTIGE ' + (PRESTIGE_ROMAN[prestige-1]||prestige));
      prestigeEl.style.display = 'inline-block';
      const pColors = ['#888','#cc9900','#22aacc','#cc22aa','#ff4400'];
      prestigeEl.style.color = pColors[prestige-1]||'#ffcc44';
      prestigeEl.style.textShadow = '0 0 8px ' + (pColors[prestige-1]||'#ffcc44') + '80';
    } else {
      prestigeEl.style.display = 'none';
    }
  }

  // Badge actif affiché dans la carte identité
  const activeBadgeEl = document.getElementById('pactive-badge');
  if (activeBadgeEl) {
    const bId = p.activeBadge||'';
    const bDef = bId && BADGE_DEFS[bId];
    if (bDef) {
      activeBadgeEl.textContent = bDef.icon + ' ' + bDef.label;
      activeBadgeEl.style.borderColor = bDef.color;
      activeBadgeEl.style.color = bDef.color;
      activeBadgeEl.style.display = 'inline-block';
    } else {
      activeBadgeEl.style.display = 'none';
    }
  }

  // Classement personnel
  renderPersonalRanks(p);

  // Grille des badges
  renderBadgesGrid(p.badgesUnlocked||[], p.activeBadge||'');

  // Stats redzone
  const rzContainer = document.getElementById('rz-stats');
  if (rzContainer) {
    rzContainer.innerHTML = `
      <div class="rz-stat"><span class="rz-label">RZ Kills</span><span class="rz-value">${p.redzoneKills||0}</span></div>
      <div class="rz-stat"><span class="rz-label">RZ Morts</span><span class="rz-value">${p.redzoneDeaths||0}</span></div>
      <div class="rz-stat"><span class="rz-label">RZ Zombies</span><span class="rz-value">${p.redzoneZombies||0}</span></div>
    `;
  }

  // Avatar : URL bot token → avatar Discord par défaut → emoji fallback
  const avatarEl = document.getElementById('pavatar');
  let avatarSrc = null;
  if (p.avatarUrl) {
    avatarSrc = p.avatarUrl;
  } else if (p.discordId) {
    try {
      const idx = Number(BigInt(p.discordId) >> 22n) % 6;
      avatarSrc = 'https://cdn.discordapp.com/embed/avatars/' + idx + '.png';
    } catch(e) {}
  }
  if (avatarSrc) {
    avatarEl.innerHTML = '<img src="' + avatarSrc + '" alt="avatar" onerror="this.parentElement.innerHTML=\'&#128100;\'">';
  } else {
    avatarEl.textContent = '👤';
  }
}

function renderPersonalRanks(p) {
  const killsEl   = document.getElementById('prank-kills');
  const zombiesEl = document.getElementById('prank-zombies');
  const kdEl      = document.getElementById('prank-kd');
  if (!killsEl) return;
  if (!leaderboardLoaded || !leaderboardData.players) {
    killsEl.textContent = '#—'; zombiesEl.textContent = '#—'; kdEl.textContent = '#—';
    return;
  }
  const players = leaderboardData.players;
  const myId = p.identifier;
  const findRank = (sorted) => {
    const idx = sorted.findIndex(e => e.identifier === myId);
    return idx >= 0 ? '#' + (idx + 1) : '#—';
  };
  const byKills   = [...players].sort((a,b)=>(b.kills||0)-(a.kills||0));
  const byZombies = [...players].sort((a,b)=>(b.zombies||0)-(a.zombies||0));
  const byKd      = [...players].sort((a,b)=>(b.kd||0)-(a.kd||0));
  killsEl.textContent   = findRank(byKills);
  zombiesEl.textContent = findRank(byZombies);
  kdEl.textContent      = findRank(byKd);
}

function renderBadgesGrid(unlocked, activeBadgeId) {
  const grid = document.getElementById('pbadges-grid');
  if (!grid) return;
  if (!unlocked || unlocked.length === 0) {
    grid.innerHTML = '<div class="badges-empty">Aucun badge débloqué pour l\'instant</div>';
    return;
  }
  grid.innerHTML = unlocked.map(id => {
    const b = BADGE_DEFS[id] || { label: id, icon: '🏷️', color: '#666666', tier: 'common' };
    const isActive = id === activeBadgeId;
    return `<div class="badge-card ${isActive?'badge-active':''}" style="border-color:${b.color}"
               onclick="setActiveBadge('${id}')" title="${b.label}">
      <div class="badge-icon">${b.icon}</div>
      <div class="badge-label">${b.label}</div>
      ${isActive?'<div class="badge-active-dot"></div>':''}
    </div>`;
  }).join('');
}

function setActiveBadge(badgeId) {
  const current = state.profile && state.profile.activeBadge;
  const newBadge = current === badgeId ? '' : badgeId;
  state.profile.activeBadge = newBadge;
  lua('setActiveBadge', { badgeId: newBadge });
  renderProfile();
}

// ══ Leaderboard ═══════════════════════════════════════════════════════════════
function leaderboardSkeleton() {
  const body = document.getElementById('lb-body');
  const rankBox = document.getElementById('lb-my-rank');
  if (!body) return;
  body.innerHTML = Array(6).fill(null).map((_, i) => `
    <tr class="lb-skel-row">
      <td><span class="skel lb-skel-rank"></span></td>
      <td class="lb-avatar-cell"><span class="skel lb-skel-avatar"></span></td>
      <td><span class="skel lb-skel-name" style="width:${80 + (i % 3) * 25}px"></span></td>
      <td><span class="skel lb-skel-val"></span></td>
      <td><span class="skel lb-skel-val"></span></td>
      <td><span class="skel lb-skel-val"></span></td>
      <td><span class="skel lb-skel-val"></span></td>
    </tr>
  `).join('');
  if (rankBox) rankBox.innerHTML = '<span class="skel" style="width:150px;height:10px;display:inline-block;border-radius:2px"></span>';
}

function leaderboardMetricValue(entry) {
  if (leaderboardCategory === 'deaths') return Number(entry.deaths || 0);
  if (leaderboardCategory === 'zombies') return Number(entry.zombies || 0);
  if (leaderboardCategory === 'kd') return Number(entry.kd || 0);
  if (leaderboardCategory === 'redzoneKills') return Number(entry.redzoneKills || 0);
  if (leaderboardCategory === 'redzoneZombies') return Number(entry.redzoneZombies || 0);
  return Number(entry.kills || 0);
}

function leaderboardCategoryLabel() {
  if (leaderboardCategory === 'deaths') return 'MORTS';
  if (leaderboardCategory === 'zombies') return 'ZOMBIES';
  if (leaderboardCategory === 'kd') return 'K/D';
  if (leaderboardCategory === 'redzoneKills') return 'RZ KILLS';
  if (leaderboardCategory === 'redzoneZombies') return 'RZ ZOMBIES';
  return 'KILLS';
}

function loadLeaderboard(force) {
  if (leaderboardLoaded && !force) {
    renderLeaderboard();
    renderPersonalRanks(state.profile || {});
    return;
  }
  leaderboardSkeleton();
  fetch('https://pvp_inventory/leaderboardGetData', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: '{}'
  })
    .then(r => r.json())
    .then(data => {
      leaderboardData = data || { players: [], crews: [], myIdentifier: null, myCrewId: null };
      leaderboardLoaded = true;
      renderLeaderboard();
      renderPersonalRanks(state.profile || {});
    })
    .catch(() => {
      leaderboardData = { players: [], crews: [], myIdentifier: null, myCrewId: null };
      leaderboardLoaded = true;
      renderLeaderboard();
      renderPersonalRanks(state.profile || {});
    });
}

function renderLeaderboard() {
  const body = document.getElementById('lb-body');
  const rankBox = document.getElementById('lb-my-rank');
  const colName = document.getElementById('lb-col-name');
  const colMain = document.getElementById('lb-col-main');
  if (!body || !rankBox || !colName || !colMain) return;

  colName.textContent = leaderboardType === 'players' ? 'JOUEUR' : 'CREW';
  colMain.textContent = leaderboardCategoryLabel();

  const source = leaderboardType === 'players'
    ? (leaderboardData.players || [])
    : (leaderboardData.crews || []);

  const rows = source.slice().sort((a, b) => {
    const diff = leaderboardMetricValue(b) - leaderboardMetricValue(a);
    if (diff !== 0) return diff;
    return (Number(b.kills || 0) - Number(a.kills || 0));
  });

  if (rows.length === 0) {
    body.innerHTML = `<tr><td colspan="7">
      <div class="grid-empty" style="padding:32px 0">
        <svg class="grid-empty-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.2"><path d="M3 21h18M9 8h6M12 8V3m-4 18v-7h8v7"/></svg>
        <div class="grid-empty-title">AUCUNE DONNÉE</div>
        <div class="grid-empty-sub">Le classement se remplira dès les premiers combats</div>
      </div>
    </td></tr>`;
    rankBox.textContent = '';
    return;
  }

  let myRank = null;
  const myKey = leaderboardType === 'players' ? leaderboardData.myIdentifier : leaderboardData.myCrewId;

  body.innerHTML = rows.slice(0, 50).map((entry, index) => {
    const rank = index + 1;
    const isMe = leaderboardType === 'players'
      ? (entry.identifier && entry.identifier === myKey)
      : (Number(entry.id) === Number(myKey));

    if (isMe) myRank = rank;
    const name = leaderboardType === 'players'
      ? (entry.name || entry.identifier || 'Joueur')
      : ('[' + (entry.tag || 'CREW') + '] ' + (entry.name || 'Crew'));
    const main = leaderboardMetricValue(entry);
    const clickable = leaderboardType === 'players';
    const avatarHtml = (entry.avatarUrl && leaderboardType === 'players')
      ? `<img src="${esc(entry.avatarUrl)}" class="lb-avatar" onerror="this.style.display='none'">`
      : `<div class="lb-avatar lb-avatar-placeholder"></div>`;

    return `
      <tr class="${isMe ? 'lb-me' : ''}${clickable ? ' lb-clickable' : ''}"
          ${clickable ? `data-identifier="${esc(entry.identifier || '')}" data-rank="${rank}"` : ''}>
        <td>${rank}</td>
        <td class="lb-avatar-cell">${avatarHtml}</td>
        <td>${esc(name)}</td>
        <td>${leaderboardCategory === 'kd' ? Number(main).toFixed(2) : fmt(main)}</td>
        <td>${fmt(entry.deaths || 0)}</td>
        <td>${fmt(entry.zombies || 0)}</td>
        <td>${Number(entry.kd || 0).toFixed(2)}</td>
      </tr>
    `;
  }).join('');

  if (!myRank && myKey) {
    const idx = rows.findIndex(entry => (
      leaderboardType === 'players'
        ? (entry.identifier && entry.identifier === myKey)
        : (Number(entry.id) === Number(myKey))
    ));
    if (idx >= 0) myRank = idx + 1;
  }

  if (myRank) {
    rankBox.textContent = 'Mon rang: #' + myRank + ' (' + leaderboardCategoryLabel() + ')';
  } else {
    rankBox.textContent = leaderboardType === 'players'
      ? 'Tu n es pas encore classe sur cette categorie.'
      : 'Ton crew n est pas encore classe sur cette categorie.';
  }
}

const lbPlayersBtn = document.getElementById('lb-btn-players');
const lbCrewsBtn = document.getElementById('lb-btn-crews');
if (lbPlayersBtn && lbCrewsBtn) {
  lbPlayersBtn.addEventListener('click', () => {
    leaderboardType = 'players';
    lbPlayersBtn.classList.add('active');
    lbCrewsBtn.classList.remove('active');
    renderLeaderboard();
  });
  lbCrewsBtn.addEventListener('click', () => {
    leaderboardType = 'crews';
    lbCrewsBtn.classList.add('active');
    lbPlayersBtn.classList.remove('active');
    renderLeaderboard();
  });
}

document.querySelectorAll('.lb-cat').forEach(btn => {
  btn.addEventListener('click', () => {
    leaderboardCategory = btn.dataset.cat || 'kills';
    document.querySelectorAll('.lb-cat').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    renderLeaderboard();
  });
});

// ── Clic sur une ligne joueur → profil ─────────────────────────────────────
const ppmOverlay = document.getElementById('player-profile-modal');
const ppmCloseBtn = document.getElementById('ppm-close-btn');

function openPlayerProfile(identifier, rank) {
  if (!ppmOverlay) return;
  const entry = (leaderboardData.players || []).find(p => p.identifier === identifier);
  if (!entry) return;

  document.getElementById('ppm-name').textContent = entry.name || identifier;
  document.getElementById('ppm-id').textContent = identifier;

  const ppmAvatarEl = document.querySelector('.ppm-avatar');
  if (ppmAvatarEl) {
    if (entry.avatarUrl) {
      ppmAvatarEl.innerHTML = `<img src="${esc(entry.avatarUrl)}" alt="" onerror="this.parentElement.innerHTML='👤'">`;
    } else {
      ppmAvatarEl.textContent = '👤';
    }
  }
  document.getElementById('ppm-kills').textContent = fmt(entry.kills || 0);
  document.getElementById('ppm-deaths').textContent = fmt(entry.deaths || 0);
  document.getElementById('ppm-kd').textContent = Number(entry.kd || 0).toFixed(2);
  document.getElementById('ppm-zombies').textContent = fmt(entry.zombies || 0);
  document.getElementById('ppm-rank').textContent = rank;

  const crewSection = document.getElementById('ppm-crew-section');
  const noCrew = document.getElementById('ppm-no-crew');
  if (entry.crew_name) {
    document.getElementById('ppm-crew-tag').textContent = '[' + (entry.crew_tag || '') + ']';
    document.getElementById('ppm-crew-name').textContent = entry.crew_name;
    crewSection.style.display = '';
    noCrew.style.display = 'none';
  } else {
    crewSection.style.display = 'none';
    noCrew.style.display = '';
  }

  ppmOverlay.style.display = 'flex';
}

function closePlayerProfile() {
  if (ppmOverlay) ppmOverlay.style.display = 'none';
}

if (ppmCloseBtn) ppmCloseBtn.addEventListener('click', closePlayerProfile);
if (ppmOverlay) ppmOverlay.addEventListener('click', e => {
  if (e.target === ppmOverlay) closePlayerProfile();
});

document.getElementById('lb-body').addEventListener('click', e => {
  if (leaderboardType !== 'players') return;
  const row = e.target.closest('tr.lb-clickable');
  if (!row) return;
  const identifier = row.dataset.identifier;
  const rank = parseInt(row.dataset.rank, 10);
  if (identifier) openPlayerProfile(identifier, rank);
});

// ══ Onglets ════════════════════════════════════════════════════════════════
function switchTab(name) {
  document.querySelectorAll('.tab').forEach(t=>t.classList.toggle('active',t.dataset.tab===name));
  document.querySelectorAll('.view').forEach(v=>v.classList.toggle('active',v.id==='view-'+name));
  if (name === 'crew') loadCrewTab();
  if (name === 'leaderboard') loadLeaderboard();
  if (name === 'profile') loadLeaderboard(false);
}
document.querySelectorAll('.tab').forEach(t=>t.addEventListener('click',()=>switchTab(t.dataset.tab)));

// ══ Custom Drag & Drop ═══════════════════════════════════════════════════
function startDrag(e, name, label) {
  if (e.button !== 0) return;
  e.preventDefault();
  const card = e.target.closest('.item-card');
  const source = card ? card.dataset.source : 'inv';
  dragging = { name, label, source };

  dragGhost = document.createElement('div');
  dragGhost.className = 'drag-ghost';
  dragGhost.innerHTML = `<span>${icon(name)}</span><span class="dg-name">${label}</span>`;
  document.body.appendChild(dragGhost);
  // Mesure l'offset une seule fois après insertion (évite calc() à chaque frame)
  dragOffsetX = Math.round(dragGhost.offsetWidth  / 2);
  dragOffsetY = Math.round(dragGhost.offsetHeight / 2);
  dragGhost.style.transform = `translate(${e.clientX - dragOffsetX}px, ${e.clientY - dragOffsetY}px)`;

  document.querySelectorAll('.hs').forEach(s => s.classList.add('drop-target'));
  document.getElementById('drop-remove').classList.add('drop-target');
  if (source === 'inv') {
    document.getElementById('grid-stash').classList.add('drop-zone-active');
  }
  if (source === 'stash' || source === 'outpost' || source === 'drop' || source === 'deathbag') {
    document.getElementById('grid-main').classList.add('drop-zone-active');
  }
}

document.addEventListener('mousemove', e => {
  if (!dragGhost) return;
  pendingX = e.clientX;
  pendingY = e.clientY;
  if (dragRafId) return; // déjà une frame en attente — skip
  dragRafId = requestAnimationFrame(() => {
    if (dragGhost) {
      dragGhost.style.transform = `translate(${pendingX - dragOffsetX}px, ${pendingY - dragOffsetY}px)`;
    }
    dragRafId = null;
  });
});

document.addEventListener('mouseup', e => {
  if (!dragging || !dragGhost) return;

  const target = document.elementFromPoint(e.clientX, e.clientY);
  if (target) {
    const slot = target.closest('.hs');
    const remove = target.closest('#drop-remove');
    const stashZone = target.closest('#grid-stash') || target.closest('#stash-bar-wrap') || target.closest('#stash-weight') || target.closest('#inv-right');
    const invZone   = target.closest('#grid-main')  || target.closest('#weight-bar-wrap')  || target.closest('#inv-left');

    if (slot) {
      const idx = parseInt(slot.id.replace('hs', ''));
      hotbar[idx] = { name: dragging.name, label: dragging.label };
      renderHotbar();
      syncHotbarToLua();
    } else if (remove) {
      hotbar = hotbar.map(s => s && s.name === dragging.name ? null : s);
      renderHotbar();
      syncHotbarToLua();
    } else if (stashZone && dragging.source === 'inv' && !transferLocked) {
      if (dropMode || deathBagMode) {
        // On ne peut pas déposer dans un drop ou un death bag
      } else if (outpostMode) {
        transferLocked = true;
        lua('outpostStashDeposit', { outpostId: outpostMode.id, item: dragging.name, qty: 1 });
      } else {
        transferLocked = true;
        lua('stashDeposit', { item: dragging.name, qty: 1 });
      }
    } else if (invZone && dragging.source === 'deathbag' && !transferLocked) {
      transferLocked = true;
      lua('deathBagWithdraw', { bagId: deathBagMode.id, item: dragging.name, qty: 1 });
    } else if (invZone && dragging.source === 'drop' && !transferLocked) {
      transferLocked = true;
      lua('dropWithdraw', { dropId: dropMode.id, item: dragging.name, qty: 1 });
    } else if (invZone && dragging.source === 'outpost' && !transferLocked) {
      transferLocked = true;
      lua('outpostStashWithdraw', { outpostId: outpostMode.id, item: dragging.name, qty: 1 });
    } else if (invZone && dragging.source === 'stash' && !transferLocked) {
      transferLocked = true;
      lua('stashWithdraw', { item: dragging.name, qty: 1 });
    }
  }

  dragGhost.remove();
  dragGhost = null;
  dragging  = null;
  if (dragRafId) { cancelAnimationFrame(dragRafId); dragRafId = null; }
  document.querySelectorAll('.hs').forEach(s => s.classList.remove('drop-target'));
  document.getElementById('drop-remove').classList.remove('drop-target');
  document.querySelectorAll('.drop-zone-active').forEach(z => z.classList.remove('drop-zone-active'));
});

function clickSlot(idx) {
  if (hotbar[idx]) {
    hotbar[idx] = null;
    renderHotbar();
    syncHotbarToLua();
  }
}

function clickRemove() {
  hotbar = [null,null,null,null,null,null,null];
  renderHotbar();
  syncHotbarToLua();
}

function buyListing(id) {
  if (!inSafeZone) { toast('Achats uniquement en zone safe !', false); return; }
  lua('buyListing', {id});
}
function cancelList(id) {
  lua('cancelListing', {id});
}

// ══ Clic droit : transfert rapide ═════════════════════════════════════════
function quickStash(e, name, source) {
  e.preventDefault();
  e.stopPropagation();
  // Bloquer les clics rapides — attendre la confirmation serveur
  if (transferLocked) return;
  if (source === 'deathbag') {
    transferLocked = true;
    lua('deathBagWithdraw', { bagId: deathBagMode.id, item: name, qty: 1 });
    return;
  } else if (source === 'drop') {
    transferLocked = true;
    lua('dropWithdraw', { dropId: dropMode.id, item: name, qty: 1 });
  } else if (source === 'inv') {
    if (dropMode || deathBagMode) {
      // On ne peut pas déposer dans un drop ou un death bag
    } else if (outpostMode) {
      transferLocked = true;
      lua('outpostStashDeposit', { outpostId: outpostMode.id, item: name, qty: 1 });
    } else {
      transferLocked = true;
      lua('stashDeposit', { item: name, qty: 1 });
    }
  } else if (source === 'outpost') {
    transferLocked = true;
    lua('outpostStashWithdraw', { outpostId: outpostMode.id, item: name, qty: 1 });
  } else if (source === 'stash') {
    transferLocked = true;
    lua('stashWithdraw', { item: name, qty: 1 });
  }
}

// ══ Toast ════════════════════════════════════════════════════════════════
function toast(msg, ok) {
  const el = document.getElementById('toast');
  el.textContent = msg;
  el.className   = 'show ' + (ok ? 'ok' : 'fail');
  clearTimeout(toastT);
  toastT = setTimeout(() => el.className='', 3000);
}

// ══ Fetch Lua ════════════════════════════════════════════════════════════
function lua(cb, data) {
  fetch('https://pvp_inventory/'+cb, {
    method:'POST', headers:{'Content-Type':'application/json'},
    body: JSON.stringify(data)
  });
}
function esc(s) { return String(s).replace(/'/g,"\\'"); }
function closeCtx() {}

// ══ Paramètres ════════════════════════════════════════════════════════════
function applySetting(key, val) {
  if (key==='opacity') {
    settings.opacity = parseInt(val);
    const a = val / 100;
    const pa = Math.min(1, a + 0.15);
    const ca = Math.max(0.05, a - 0.1);
    let sheet = document.getElementById('dynamic-opacity');
    if (!sheet) {
      sheet = document.createElement('style');
      sheet.id = 'dynamic-opacity';
      document.head.appendChild(sheet);
    }
    sheet.textContent = `
      #overlay { background: rgba(15,15,20,${a}) !important; }
    `;
    document.getElementById('val-opacity').textContent = val+'%';
  } else if (key==='blur') {
    settings.blur = parseInt(val);
    document.getElementById('overlay').style.backdropFilter = val > 0 ? `blur(${val}px)` : 'none';
    document.getElementById('val-blur').textContent = val+'px';
  } else if (key==='hudType') {
    settings.hudType = val; // 'gta' ou 'vanta'
    updateHudToggleUI();
    lua('setHudType', { hudType: val });
  }
  try { localStorage.setItem('pvp_inv_settings', JSON.stringify(settings)); } catch(e) {}
}

function updateHudToggleUI() {
  const btnGta = document.getElementById('btn-hud-gta');
  const btnVanta = document.getElementById('btn-hud-vanta');
  if (btnGta) btnGta.classList.toggle('active', settings.hudType === 'gta');
  if (btnVanta) btnVanta.classList.toggle('active', settings.hudType === 'vanta');
}

// ══ VANTA HUD Overlay Handler ═══════════════════════════════════════════
let vhudFlashTimer = null;
function handleVantaHud(d) {
  const wrap = document.getElementById('vanta-hud');
  if (!wrap) return;

  if (d.action === 'show') {
    wrap.style.display = 'block';
    return;
  }
  if (d.action === 'hide') {
    wrap.style.display = 'none';
    return;
  }
  if (d.action === 'update') {
    // HP
    const hp = Math.max(0, Math.min(100, d.hp || 0));
    const hpBar = document.getElementById('vhud-hp-bar');
    const hpVal = document.getElementById('vhud-hp-val');
    const hpRow = document.getElementById('vhud-hp-row');
    if (hpBar) hpBar.style.width = hp + '%';
    if (hpVal) hpVal.textContent = Math.round(hp);
    const crit = hp <= 25;
    if (hpBar) hpBar.classList.toggle('critical', crit);
    if (hpVal) hpVal.classList.toggle('critical', crit);
    if (hpRow) hpRow.classList.toggle('vhud-hp-critical', crit);

    // Armor
    const armor = Math.max(0, Math.min(100, d.armor || 0));
    const armorBar = document.getElementById('vhud-armor-bar');
    const armorVal = document.getElementById('vhud-armor-val');
    if (armorBar) armorBar.style.width = armor + '%';
    if (armorVal) armorVal.textContent = Math.round(armor);

    // Weapon
    const wName = document.getElementById('vhud-weapon-name');
    const ammoDisp = document.getElementById('vhud-ammo-display');
    const ammoCur = document.getElementById('vhud-ammo-current');
    const ammoRes = document.getElementById('vhud-ammo-reserve');
    const ammoInf = document.getElementById('vhud-ammo-inf');

    if (!d.weapon || d.weapon === '') {
      if (wName) { wName.textContent = 'AUCUNE ARME'; wName.classList.remove('armed'); }
      if (ammoDisp) ammoDisp.style.display = 'none';
      if (ammoInf) ammoInf.style.display = 'none';
    } else {
      if (wName) { wName.textContent = d.weapon.toUpperCase(); wName.classList.add('armed'); }
      if (d.ammo === -1) {
        if (ammoDisp) ammoDisp.style.display = 'none';
        if (ammoInf) ammoInf.style.display = 'block';
      } else {
        if (ammoDisp) ammoDisp.style.display = 'flex';
        if (ammoInf) ammoInf.style.display = 'none';
        if (ammoCur) { ammoCur.textContent = d.ammo; ammoCur.classList.toggle('ammo-low', d.ammo <= 5 && d.ammo > 0); }
        if (ammoRes) ammoRes.textContent = d.reserve > 0 ? d.reserve : '\u221E';
      }
    }

    // Damage flash
    if (d.damaged) {
      const flash = document.getElementById('dmg-flash');
      if (flash) {
        flash.classList.add('active');
        if (vhudFlashTimer) clearTimeout(vhudFlashTimer);
        vhudFlashTimer = setTimeout(() => flash.classList.remove('active'), 180);
      }
    }
  }
}

function loadSettings() {
  try {
    const s = JSON.parse(localStorage.getItem('pvp_inv_settings'));
    if (s) {
      settings = {...settings, ...s};
      document.getElementById('opt-opacity').value = settings.opacity;
      document.getElementById('opt-blur').value = settings.blur;
      applySetting('opacity', settings.opacity);
      applySetting('blur', settings.blur);
    }
  } catch(e) {}
  // Toujours mettre a jour le toggle HUD
  updateHudToggleUI();
}
loadSettings();

// ══ Hover tracking pour bind rapide ══════════════════════════════════════
let hoveredItem = null;

document.addEventListener('mouseover', e => {
  const card = e.target.closest('.item-card');
  if (card && card.dataset.name) {
    hoveredItem = { name: card.dataset.name, label: card.dataset.label };
  }
});
document.addEventListener('mouseout', e => {
  const card = e.target.closest('.item-card');
  if (card) hoveredItem = null;
});

document.addEventListener('keydown', e => {
  if (e.key === 'Escape') {
    if (tradeOpen) { cancelTrade(); return; }
    closeUI();
    return;
  }
  if (hoveredItem) {
    let idx = -1;
    const num = parseInt(e.key);
    if (num >= 1 && num <= 8) idx = num - 1;
    if (idx >= 0) {
      hotbar[idx] = { name: hoveredItem.name, label: hoveredItem.label };
      renderHotbar();
      syncHotbarToLua();
      e.preventDefault();
      e.stopPropagation();
    }
  }
});

// ══════════════════════════════════════════════════════════════════════════
// ÉCHANGE DIRECT
// ══════════════════════════════════════════════════════════════════════════
let tradeOpen = false;
let tradeMyOffer = { items: [], money: 0 };
let tradeMyInv = [];
let tradeMyBank = 0;

function openTradeWindow(data) {
  tradeOpen = true;
  tradeMyOffer = { items: [], money: 0 };
  tradeMyInv = data.myInventory || [];
  tradeMyBank = data.myBank || 0;

  document.getElementById('trade-partner-name').textContent = data.partnerName || '?';
  document.getElementById('trade-my-money').value = 0;
  document.getElementById('trade-my-money').max = tradeMyBank;
  document.getElementById('trade-partner-money').textContent = '0';
  document.getElementById('trade-partner-items').innerHTML = '<div class="grid-empty">RIEN</div>';
  document.getElementById('trade-status').textContent = '';
  document.getElementById('trade-confirm-btn').className = 'btn-confirm';
  document.getElementById('trade-confirm-btn').textContent = 'CONFIRMER';

  renderTradeMyInv();
  renderTradeMyOffer();
  document.getElementById('trade-overlay').style.display = 'flex';
}

function closeTradeWindow() {
  tradeOpen = false;
  document.getElementById('trade-overlay').style.display = 'none';
}

function renderTradeMyInv() {
  const el = document.getElementById('trade-my-inv');
  // Exclure les items déjà dans l'offre
  const offered = {};
  tradeMyOffer.items.forEach(i => { offered[i.name] = (offered[i.name]||0) + i.count; });

  const available = tradeMyInv.map(i => {
    const remaining = i.count - (offered[i.name]||0);
    if (remaining <= 0) return null;
    return {...i, count: remaining};
  }).filter(Boolean);

  el.innerHTML = available.length ? available.map(i =>
    `<div class="trade-inv-item" onclick="addToTradeOffer('${esc(i.name)}','${esc(i.label)}')">
      ${icon(i.name)} <span>${i.label}</span> <small>×${i.count}</small>
    </div>`
  ).join('') : '<div class="grid-empty">VIDE</div>';
}

function renderTradeMyOffer() {
  const el = document.getElementById('trade-my-items');
  el.innerHTML = tradeMyOffer.items.length ? tradeMyOffer.items.map(i =>
    `<div class="trade-offer-item" onclick="removeFromTradeOffer('${esc(i.name)}')">
      ${icon(i.name)} <span>${i.label} ×${i.count}</span> <small class="trade-remove">✕</small>
    </div>`
  ).join('') : '<div class="grid-empty">RIEN</div>';
}

function addToTradeOffer(name, label) {
  const existing = tradeMyOffer.items.find(i => i.name === name);
  const invItem = tradeMyInv.find(i => i.name === name);
  if (!invItem) return;

  const offered = existing ? existing.count : 0;
  if (offered >= invItem.count) return;

  if (existing) {
    existing.count++;
  } else {
    tradeMyOffer.items.push({ name, label, count: 1 });
  }

  renderTradeMyOffer();
  renderTradeMyInv();
  sendTradeOffer();
}

function removeFromTradeOffer(name) {
  const idx = tradeMyOffer.items.findIndex(i => i.name === name);
  if (idx === -1) return;

  if (tradeMyOffer.items[idx].count > 1) {
    tradeMyOffer.items[idx].count--;
  } else {
    tradeMyOffer.items.splice(idx, 1);
  }

  renderTradeMyOffer();
  renderTradeMyInv();
  sendTradeOffer();
}

function sendTradeOffer() {
  tradeMyOffer.money = Math.max(0, parseInt(document.getElementById('trade-my-money').value)||0);
  fetch('https://pvp_inventory/updateTradeOffer', {
    method:'POST', headers:{'Content-Type':'application/json'},
    body: JSON.stringify({ items: tradeMyOffer.items, money: tradeMyOffer.money })
  });
}

function updatePartnerOfferUI(offer) {
  const el = document.getElementById('trade-partner-items');
  const items = offer.items || [];
  el.innerHTML = items.length ? items.map(i =>
    `<div class="trade-offer-item partner">
      ${icon(i.name)} <span>${i.label} ×${i.count}</span>
    </div>`
  ).join('') : '<div class="grid-empty">RIEN</div>';

  document.getElementById('trade-partner-money').textContent = fmt(offer.money || 0);
}

function confirmTrade() {
  document.getElementById('trade-confirm-btn').textContent = 'EN ATTENTE...';
  document.getElementById('trade-confirm-btn').className = 'btn-confirm confirmed';
  document.getElementById('trade-status').textContent = 'En attente du partenaire...';
  fetch('https://pvp_inventory/confirmTrade', {method:'POST',body:'{}'});
}

function onPartnerConfirmed() {
  document.getElementById('trade-status').textContent = 'Le partenaire a confirmé !';
}

function onTradeConfirmReset() {
  document.getElementById('trade-confirm-btn').textContent = 'CONFIRMER';
  document.getElementById('trade-confirm-btn').className = 'btn-confirm';
  document.getElementById('trade-status').textContent = 'Offre modifiée — reconfirmez';
}

function cancelTrade() {
  fetch('https://pvp_inventory/cancelTrade', {method:'POST',body:'{}'});
}

// ══ Barre de progression heal ═══════════════════════════════════════════
let healTimer = null;
function showHealBar(data) {
  const wrap  = document.getElementById('heal-bar-wrap');
  const bar   = document.getElementById('heal-bar');
  const label = document.getElementById('heal-label');
  if (!wrap || !bar || !label) return;

  const item = data.item || 'bandage';
  const dur  = data.duration || 1000;

  label.textContent = (item==='bandage'?'BANDAGE':item==='medkit'?'MEDKIT':'KEVLAR');
  label.style.display = 'block';
  wrap.style.display  = 'block';

  bar.className = item;
  bar.style.transition = 'none';
  bar.style.width = '0%';

  // Force reflow puis anime
  void bar.offsetWidth;
  bar.style.transition = `width ${dur}ms linear`;
  bar.style.width = '100%';

  clearTimeout(healTimer);
  healTimer = setTimeout(() => hideHealBar(), dur + 100);
}
function hideHealBar() {
  clearTimeout(healTimer);
  const wrap  = document.getElementById('heal-bar-wrap');
  const label = document.getElementById('heal-label');
  if (wrap) wrap.style.display = 'none';
  if (label) label.style.display = 'none';
}

// ══════════════════════════════════════════════════════════════════════════
//   CREW — Onglet intégré dans l'inventaire
// ══════════════════════════════════════════════════════════════════════════

let crewData      = null;
let crewInvites   = [];
let crewPlayers   = [];
let crewMyRank    = null;
let crewCost      = 5000;
let crewConfirmCb = null;

function crewFetch(endpoint, data) {
  return fetch('https://pvp_inventory/' + endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data || {})
  }).then(r => r.json());
}

function crewShowConfirm(text, cb) {
  document.getElementById('crew-confirm-text').textContent = text;
  document.getElementById('crew-confirm-modal').style.display = 'flex';
  crewConfirmCb = cb;
}

function crewHideConfirm() {
  document.getElementById('crew-confirm-modal').style.display = 'none';
  crewConfirmCb = null;
}

document.getElementById('crew-confirm-yes').addEventListener('click', () => {
  if (crewConfirmCb) crewConfirmCb();
  crewHideConfirm();
});
document.getElementById('crew-confirm-no').addEventListener('click', crewHideConfirm);

// ── Chargement des données crew ───────────────────────────────────────
function loadCrewTab() {
  crewFetch('crewGetData').then(r => {
    crewData = r.crew;
    crewInvites = r.invites || [];
    crewPlayers = r.players || [];
    crewCost = r.crewCost || 5000;
    renderCrewTab();
  });
}

function renderCrewTab() {
  const noCrew = document.getElementById('crew-no-crew');
  const inCrew = document.getElementById('crew-in-crew');

  if (!crewData) {
    noCrew.style.display = '';
    inCrew.style.display = 'none';
    document.getElementById('crew-cost-val').textContent = '$' + crewCost.toLocaleString('fr-FR');
    renderCrewInvites();
    return;
  }

  noCrew.style.display = 'none';
  inCrew.style.display = '';
  document.getElementById('crew-invite-panel').style.display = 'none';
  crewMyRank = crewData.myRank;

  // Bannière
  const crewColor = crewData.color || '#a0a0a8';
  const tagEl = document.getElementById('crew-tag-disp');
  tagEl.textContent = crewData.tag;
  tagEl.style.color = crewColor;
  tagEl.style.background = crewColor + '18';
  tagEl.style.borderColor = crewColor + '55';
  document.getElementById('crew-name-disp').textContent = crewData.name;

  // Date
  const dateEl = document.getElementById('crew-date-disp');
  if (crewData.created_at) {
    const d = new Date(crewData.created_at);
    dateEl.textContent = 'Créé le ' + d.toLocaleDateString('fr-FR');
  } else {
    dateEl.textContent = '';
  }

  // Couleur (chef uniquement)
  const colorArea = document.getElementById('crew-color-area');
  if (crewMyRank === 'owner') {
    colorArea.style.display = '';
    document.getElementById('crew-color-input').value = crewColor;
  } else {
    colorArea.style.display = 'none';
  }

  // MOTD
  const motdText = document.getElementById('crew-motd-text');
  const motdEdit = document.getElementById('crew-motd-edit');
  motdText.textContent = crewData.motd || 'Aucun message défini.';
  document.getElementById('crew-motd-box').style.borderLeftColor = crewColor;
  if (crewMyRank === 'owner') {
    motdEdit.style.display = 'flex';
    document.getElementById('crew-motd-input').value = crewData.motd || '';
  } else {
    motdEdit.style.display = 'none';
  }

  // Stats globales
  const kills = crewData.kills_total || 0;
  const deaths = crewData.deaths_total || 0;
  const kd = deaths > 0 ? (kills / deaths).toFixed(2) : kills.toFixed(2);
  document.getElementById('crew-s-kills').textContent = kills.toLocaleString('fr-FR');
  document.getElementById('crew-s-deaths').textContent = deaths.toLocaleString('fr-FR');
  document.getElementById('crew-s-kd').textContent = kd;
  document.getElementById('crew-s-zombies').textContent = (crewData.zombies_total || 0).toLocaleString('fr-FR');
  document.getElementById('crew-s-count').textContent = crewData.members ? crewData.members.length : 0;
  document.getElementById('crew-s-best').textContent = crewData.bestPlayer || '—';

  // Actions
  document.getElementById('crew-btn-invite').style.display = crewMyRank === 'member' ? 'none' : '';
  document.getElementById('crew-btn-disband').style.display = crewMyRank === 'owner' ? '' : 'none';

  renderCrewMembers();
  renderCrewActivity();
}

function renderCrewMembers() {
  const list = document.getElementById('crew-members-list');
  if (!crewData || !crewData.members || crewData.members.length === 0) {
    list.innerHTML = '<p class="crew-empty">Aucun membre</p>';
    return;
  }
  list.innerHTML = crewData.members.map((m, i) => {
    const rc = 'crew-rank-' + m.rank;
    const rl = m.rank === 'owner' ? 'CHEF' : m.rank === 'officer' ? 'OFFICIER' : 'MEMBRE';
    const kd = (m.deaths || 0) > 0 ? ((m.kills || 0) / m.deaths).toFixed(2) : (m.kills || 0).toFixed(2);
    const onClass = m.online ? 'on' : 'off';
    const isTop = i === 0;
    let acts = '';
    if (crewMyRank === 'owner' && m.rank !== 'owner') {
      const pl = m.rank === 'member' ? '▲' : '▼';
      const pr = m.rank === 'member' ? 'officer' : 'member';
      acts = `<button class="crew-btn-sm promote" onclick="crewPromote('${m.identifier}','${pr}')" title="${m.rank === 'member' ? 'Promouvoir' : 'Rétrograder'}">${pl}</button>` +
             `<button class="crew-btn-sm danger" onclick="crewKick('${m.identifier}')" title="Exclure">✕</button>`;
    } else if (crewMyRank === 'officer' && m.rank === 'member') {
      acts = `<button class="crew-btn-sm danger" onclick="crewKick('${m.identifier}')" title="Exclure">✕</button>`;
    }
    const memberAvatar = m.avatarUrl
      ? `<img src="${esc(m.avatarUrl)}" class="cm-avatar" onerror="this.style.display='none'">`
      : `<div class="cm-avatar cm-avatar-placeholder"></div>`;
    return `<div class="crew-member-row${isTop ? ' top1' : ''}">
      <span class="cm-rank-num${isTop ? ' gold' : ''}">${i + 1}</span>
      <div class="cm-info">
        ${memberAvatar}
        <span class="cm-online ${onClass}"></span>
        <span class="cm-name">${m.name}</span>
        <span class="crew-rank ${rc}">${rl}</span>
      </div>
      <span class="cm-stat">${(m.kills||0)}</span>
      <span class="cm-stat">${(m.deaths||0)}</span>
      <span class="cm-stat">${kd}</span>
      <span class="cm-stat">${(m.zombies_killed||0)}</span>
      <div class="cm-actions">${acts}</div>
    </div>`;
  }).join('');
}

function renderCrewActivity() {
  const list = document.getElementById('crew-activity-list');
  if (!crewData || !crewData.activity || crewData.activity.length === 0) {
    list.innerHTML = '<p class="crew-empty">Aucune activité récente</p>';
    return;
  }
  const icons = { create:'🏴', join:'📥', kick:'🚫', leave:'📤', motd:'💬', promote:'⭐', kill:'💀', zombie:'🧟' };
  list.innerHTML = crewData.activity.map(a => {
    const icon = icons[a.type] || '📋';
    const d = new Date(a.created_at);
    const time = d.toLocaleDateString('fr-FR') + ' ' + d.toLocaleTimeString('fr-FR', { hour:'2-digit', minute:'2-digit' });
    return `<div class="crew-activity-row">
      <span class="ca-icon">${icon}</span>
      <span class="ca-msg">${a.message}</span>
      <span class="ca-time">${time}</span>
    </div>`;
  }).join('');
}

function renderCrewInvites() {
  const list = document.getElementById('crew-invites-list');
  if (!crewInvites || crewInvites.length === 0) {
    list.innerHTML = '<p class="crew-empty">Aucune invitation</p>';
    return;
  }
  list.innerHTML = crewInvites.map(inv => `
    <div class="crew-invite-row">
      <div class="crew-invite-info">
        <span class="crew-invite-name">${inv.crew_name}</span>
        <span class="crew-invite-tag">[${inv.crew_tag}]</span>
      </div>
      <div class="crew-invite-btns">
        <button class="crew-btn-sm promote" onclick="crewAcceptInvite(${inv.crew_id})">Accepter</button>
        <button class="crew-btn-sm danger" onclick="crewDeclineInvite(${inv.crew_id})">Refuser</button>
      </div>
    </div>
  `).join('');
}

function renderCrewOnlinePlayers() {
  const list = document.getElementById('crew-online-list');
  if (!crewPlayers || crewPlayers.length === 0) {
    list.innerHTML = '<p class="crew-empty">Aucun joueur en ligne</p>';
    return;
  }
  list.innerHTML = crewPlayers.map(p => `
    <div class="crew-player-row" onclick="crewInvitePlayer(${p.id})">
      <span class="crew-player-name">${p.name}</span>
      <span class="crew-player-id">ID: ${p.id}</span>
    </div>
  `).join('');
}

// ── Actions crew ──────────────────────────────────────────────────────

document.getElementById('crew-btn-create').addEventListener('click', () => {
  const name = document.getElementById('crew-input-name').value.trim();
  const tag  = document.getElementById('crew-input-tag').value.trim();
  if (!name || !tag) { toast('Remplissez le nom et le tag.', false); return; }
  crewFetch('crewCreate', { name, tag }).then(r => {
    toast(r.message, r.ok);
    if (r.ok) setTimeout(loadCrewTab, 800);
  });
});

// ── Sous-tabs Classement / Activité ──
document.querySelectorAll('.crew-subtab').forEach(t => {
  t.addEventListener('click', () => {
    document.querySelectorAll('.crew-subtab').forEach(s => s.classList.remove('active'));
    t.classList.add('active');
    const sub = t.dataset.subtab;
    document.getElementById('crew-sub-members').style.display = sub === 'members' ? '' : 'none';
    document.getElementById('crew-sub-activity').style.display = sub === 'activity' ? '' : 'none';
  });
});

// ── Couleur du crew ──
document.getElementById('crew-color-input').addEventListener('change', (e) => {
  const color = e.target.value;
  crewFetch('crewSetColor', { color }).then(r => {
    toast(r.message, r.ok);
    if (r.ok) setTimeout(loadCrewTab, 500);
  });
});

// ── MOTD ──
document.getElementById('crew-motd-save').addEventListener('click', () => {
  const motd = document.getElementById('crew-motd-input').value.trim();
  crewFetch('crewSetMotd', { motd }).then(r => {
    toast(r.message, r.ok);
    if (r.ok) setTimeout(loadCrewTab, 500);
  });
});

document.getElementById('crew-btn-invite').addEventListener('click', () => {
  document.getElementById('crew-invite-panel').style.display = '';
  renderCrewOnlinePlayers();
});

document.getElementById('crew-btn-cancel-invite').addEventListener('click', () => {
  document.getElementById('crew-invite-panel').style.display = 'none';
});

document.getElementById('crew-btn-leave').addEventListener('click', () => {
  crewShowConfirm('Voulez-vous quitter le crew ?', () => {
    crewFetch('crewLeave').then(r => {
      toast(r.message, r.ok);
      if (r.ok) setTimeout(loadCrewTab, 800);
    });
  });
});

document.getElementById('crew-btn-disband').addEventListener('click', () => {
  crewShowConfirm('DISSOUDRE le crew ? Cette action est irréversible !', () => {
    crewFetch('crewDisband').then(r => {
      toast(r.message, r.ok);
      if (r.ok) setTimeout(loadCrewTab, 800);
    });
  });
});

window.crewInvitePlayer = function(targetId) {
  crewFetch('crewInvitePlayer', { targetId }).then(r => {
    toast(r.message, r.ok);
  });
};

window.crewAcceptInvite = function(crewId) {
  crewFetch('crewAcceptInvite', { crewId }).then(r => {
    toast(r.message, r.ok);
    if (r.ok) setTimeout(loadCrewTab, 800);
  });
};

window.crewDeclineInvite = function(crewId) {
  crewFetch('crewDeclineInvite', { crewId }).then(r => {
    toast(r.message, r.ok);
    if (r.ok) {
      crewInvites = crewInvites.filter(i => i.crew_id !== crewId);
      renderCrewInvites();
    }
  });
};

window.crewPromote = function(identifier, rank) {
  const lbl = rank === 'officer' ? 'promouvoir en officier' : 'rétrograder en membre';
  crewShowConfirm('Voulez-vous ' + lbl + ' ce joueur ?', () => {
    crewFetch('crewPromote', { identifier, rank }).then(r => {
      toast(r.message, r.ok);
      if (r.ok) setTimeout(loadCrewTab, 800);
    });
  });
};

window.crewKick = function(identifier) {
  crewShowConfirm('Exclure ce membre du crew ?', () => {
    crewFetch('crewKick', { identifier }).then(r => {
      toast(r.message, r.ok);
      if (r.ok) setTimeout(loadCrewTab, 800);
    });
  });
};
