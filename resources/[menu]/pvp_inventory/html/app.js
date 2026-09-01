// =============================================
//   PVP INVENTORY — app.js
// =============================================

let MAX_WEIGHT    = 50.0;  // default, updated from server via data.maxWeight
let STASH_MAX_KG  = 20.0;  // default, updated from server via data.maxStashWeight

// ── VCoins state ─────────────────────────────────────────────────────────
let vcData = { tier: 'none', vcoins: 0, expires: null, market: [], myOffers: [] };

const ICONS = {
  bandage:'🩹', medkit:'💊',
  kevlar:'🛡️',
  weapon_pistol:'🔫', weapon_rifle:'⚔️', weapon_sniper:'🎯',
  weapon_grenade:'💣', weapon_shotgun:'💥',
  default:'📦',
};

const WEAPON_SET = new Set([
  // Mêlée (achat armurerie uniquement, pas de drop zombie)
  'weapon_knife','weapon_machete','weapon_bat','weapon_crowbar','weapon_switchblade','weapon_hatchet',
  // Pistolets + lancers (très commun)
  'weapon_molotov','weapon_appistol',
  'weapon_pistol','weapon_pistol_mk2','weapon_snspistol','weapon_snspistol_mk2',
  'weapon_vintagepistol','weapon_combatpistol','weapon_heavypistol',
  'weapon_machinepistol',
  // SMG (très commun)
  'weapon_microsmg','weapon_minismg','weapon_smg','weapon_smg_mk2',
  // Fusils d'assaut (commun)
  'weapon_assaultrifle','weapon_carbinerifle','weapon_specialcarbine',
  // Rare
  'weapon_assaultrifle_mk2','weapon_carbinerifle_mk2','weapon_specialcarbine_mk2',
  'weapon_stungun','weapon_combatmg','weapon_mg',
  // Épique
  'weapon_precisionrifle','weapon_compactlauncher','weapon_emplauncher',
  'weapon_combatmg_mk2','weapon_musket',
  // Légendaire
  'weapon_sniperrifle','weapon_marksmanrifle_mk2',
  'weapon_heavysniper','weapon_heavysniper_mk2',
  'weapon_rpg','weapon_hominglauncher',
]);

// ══ Poids items — MIROIR EXACT de server.lua ITEM_WEIGHTS ═══════════════
// NE PAS modifier ici : source de vérité = pvp_inventory/server/server.lua
const WEIGHTS = {
  // Consommables
  bandage:0.2, medkit:0.4,
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
  // Consommables (très commun)
  bandage:'common', medkit:'common',
  kevlar:'rare',
  ammo_sniper:'legendary',
  // Shots
  shot_repel:'common', shot_attract:'common',
  shot_speed:'rare', shot_health:'rare',
  // Pistolets + lancers (très commun)
  weapon_molotov:'common', weapon_appistol:'common',
  weapon_pistol:'common', weapon_pistol_mk2:'common',
  weapon_snspistol:'common', weapon_snspistol_mk2:'common',
  weapon_vintagepistol:'common', weapon_combatpistol:'common', weapon_heavypistol:'common',
  weapon_machinepistol:'common',
  // SMG (très commun)
  weapon_microsmg:'common', weapon_minismg:'common',
  weapon_smg:'common', weapon_smg_mk2:'common',
  // Fusils d'assaut (commun → peu commun)
  weapon_assaultrifle:'uncommon', weapon_carbinerifle:'uncommon', weapon_specialcarbine:'uncommon',
  // Armes rares
  weapon_assaultrifle_mk2:'rare', weapon_carbinerifle_mk2:'rare', weapon_specialcarbine_mk2:'rare',
  weapon_stungun:'rare', weapon_combatmg:'rare', weapon_mg:'rare',
  // Armes épiques
  weapon_precisionrifle:'epic', weapon_compactlauncher:'epic', weapon_emplauncher:'epic',
  weapon_combatmg_mk2:'epic', weapon_musket:'epic',
  // Armes légendaires
  weapon_sniperrifle:'legendary', weapon_marksmanrifle_mk2:'legendary',
  weapon_heavysniper:'legendary', weapon_heavysniper_mk2:'legendary',
  weapon_rpg:'legendary', weapon_hominglauncher:'legendary',
  // Véhicules rares
  vehicle_ztype:'rare', vehicle_mule:'rare', vehicle_blazer5:'rare',
  vehicle_dominator4:'rare', vehicle_revolter:'rare', vehicle_microlight:'rare', vehicle_speedo2:'rare',
  // Véhicules épiques
  vehicle_schafter5:'epic', vehicle_baller6:'epic', vehicle_xls2:'epic', vehicle_voltic2:'epic',
  vehicle_cerberus:'epic', vehicle_zr380:'epic', vehicle_cog552:'epic', vehicle_sasquatch:'epic',
  vehicle_thruster:'epic', vehicle_vigilante:'epic', vehicle_buzzard2:'epic', vehicle_maverick:'epic', vehicle_havok:'epic',
  // Véhicules légendaires
  vehicle_deluxo:'legendary', vehicle_oppressor2:'legendary', vehicle_nightshark:'legendary',
  vehicle_scarab:'legendary', vehicle_insurgent3:'legendary', vehicle_dukes2:'legendary',
};
function getRarity(n) { return RARITY[n] || 'common'; }
const RARITY_LABEL = { common:'', uncommon:'PEU COMMUN', rare:'RARE', epic:'ÉPIQUE', legendary:'LÉGENDAIRE' };

// ══ Badges ════════════════════════════════════════════════════════════════
// Le système d'insignes vit dans html/badges.js (chargé avant app.js) et
// expose BADGE_DEFS + VantaBadges. Patte et règles : vanta_ui/BADGES.md.

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

// ══ Catalogue marché — items disponibles ingame (CLAUDE.md) ══════════════
const CATALOG = [
  // ── Soins & Équipement ──
  { name:'bandage',     label:'Bandage' },
  { name:'medkit',      label:'Medkit' },
  { name:'kevlar',      label:'Kevlar' },
  { name:'ammo_sniper', label:'Munitions Sniper' },
  // ── Shots ──
  { name:'shot_repel',   label:'Shot Répulsif' },
  { name:'shot_attract', label:'Shot Attracteur' },
  { name:'shot_speed',   label:'Shot de Vitesse' },
  { name:'shot_health',  label:'Shot de Santé' },
  // ── Pistolets & Lancers (Commun) ──
  { name:'weapon_molotov',       label:'Molotov' },
  { name:'weapon_appistol',      label:'AP Pistol' },
  { name:'weapon_pistol',        label:'Pistol' },
  { name:'weapon_pistol_mk2',    label:'Pistol MK2' },
  { name:'weapon_snspistol',     label:'SNS Pistol' },
  { name:'weapon_snspistol_mk2', label:'SNS Pistol MK2' },
  { name:'weapon_vintagepistol', label:'Vintage Pistol' },
  { name:'weapon_combatpistol',  label:'Combat Pistol' },
  { name:'weapon_heavypistol',   label:'Heavy Pistol' },
  // ── SMG (Commun) ──
  { name:'weapon_microsmg',      label:'Micro SMG' },
  { name:'weapon_minismg',       label:'Mini SMG' },
  { name:'weapon_smg',           label:'SMG' },
  { name:'weapon_smg_mk2',       label:'SMG MK2' },
  { name:'weapon_machinepistol', label:'Machine Pistol' },
  // ── Fusils d'assaut (Peu commun) ──
  { name:'weapon_assaultrifle',   label:'AK-47' },
  { name:'weapon_carbinerifle',   label:'Carabine' },
  { name:'weapon_specialcarbine', label:'Carabine Spéciale' },
  // ── Armes Rares ──
  { name:'weapon_assaultrifle_mk2',   label:'AK-47 MK2' },
  { name:'weapon_carbinerifle_mk2',   label:'Carabine MK2' },
  { name:'weapon_specialcarbine_mk2', label:'Carabine Spéciale MK2' },
  { name:'weapon_stungun',            label:'Pistolet Paralysant' },
  { name:'weapon_combatmg',           label:'M60' },
  { name:'weapon_mg',                 label:'Mitrailleuse' },
  // ── Armes Épiques ──
  { name:'weapon_precisionrifle',  label:'Fusil de Précision' },
  { name:'weapon_compactlauncher', label:'Lance-Grenades Compact' },
  { name:'weapon_emplauncher',     label:'Lanceur IEM' },
  { name:'weapon_combatmg_mk2',   label:'M60 MK2' },
  { name:'weapon_musket',          label:'Mousquet' },
  // ── Armes Légendaires ──
  { name:'weapon_sniperrifle',       label:'Fusil à Lunette' },
  { name:'weapon_marksmanrifle_mk2', label:'Marksman MK2' },
  { name:'weapon_heavysniper',       label:'AWP' },
  { name:'weapon_heavysniper_mk2',   label:'AWP MK2' },
  { name:'weapon_rpg',               label:'Lance-Roquettes' },
  { name:'weapon_hominglauncher',    label:'Lance-Missiles' },
  // ── Véhicules Rares ──
  { name:'vehicle_ztype',      label:'Z-Type' },
  { name:'vehicle_mule',       label:'Mule' },
  { name:'vehicle_blazer5',    label:'Blazer Aqua' },
  { name:'vehicle_dominator4', label:'Dominator Apocalypse' },
  { name:'vehicle_revolter',   label:'Revolter' },
  { name:'vehicle_microlight', label:'Ultralight' },
  { name:'vehicle_speedo2',    label:'Speedo Custom' },
  // ── Véhicules Épiques ──
  { name:'vehicle_schafter5',  label:'Schafter V12 Blindé' },
  { name:'vehicle_baller6',    label:'Baller LE Blindé' },
  { name:'vehicle_xls2',       label:'XLS Blindé' },
  { name:'vehicle_voltic2',    label:'Voltic Rocket' },
  { name:'vehicle_cerberus',   label:'Cerberus' },
  { name:'vehicle_zr380',      label:'ZR380' },
  { name:'vehicle_cog552',     label:'Cognoscenti Blindé' },
  { name:'vehicle_sasquatch',  label:'Sasquatch' },
  { name:'vehicle_thruster',   label:'Thruster' },
  { name:'vehicle_vigilante',  label:'Vigilante' },
  { name:'vehicle_buzzard2',   label:'Buzzard' },
  { name:'vehicle_maverick',   label:'Maverick' },
  { name:'vehicle_havok',      label:'Havok' },
  // ── Véhicules Légendaires ──
  { name:'vehicle_deluxo',     label:'Deluxo' },
  { name:'vehicle_oppressor2', label:'Oppressor MK II' },
  { name:'vehicle_nightshark', label:'Nightshark' },
  { name:'vehicle_scarab',     label:'Scarab' },
  { name:'vehicle_insurgent3', label:'Insurgent Pick-Up Custom' },
  { name:'vehicle_dukes2',     label:'Duke O\'Death' },
];

let hotbar = [null,null,null,null,null,null,null,null];
let state  = { inventory:[], stash:[], money:{}, profile:{}, market:[], myListings:[] };
let outpostMode   = null; // null | { id, label, items }
let dropMode      = null; // null | { id, label, items }
let deathBagMode  = null; // null | { id, label, items }
let ctxItem = null, ctxSource = 'inv';
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
  // Le texte des notifications est affiche par vanta_ui (pile partagee) ;
  // ce message ne sert plus qu a relacher le verrou de transfert.
  else if (type==='unlock')      { unlockTransfer(); }
  else if (type==='refreshOutpostStash') {
    unlockTransfer();
    if (outpostMode) { outpostMode.items = data.items; renderInventory(); }
  }
  else if (type==='refreshDrop') {
    unlockTransfer();
    if (dropMode) {
      if (data.dropItems !== undefined) { dropMode.items = data.dropItems; }
      if (data.inventory)  { state = {...state, inventory: data.inventory}; }
      renderInventory();
    }
  }
  else if (type==='openDeathBag') openDeathBagUI(data);
  else if (type==='refreshDeathBag') {
    unlockTransfer();
    if (deathBagMode) {
      if (data.bagItems !== undefined) { deathBagMode.items = data.bagItems; }
      if (data.inventory) { state = {...state, inventory: data.inventory}; }
      renderInventory();
    }
  }
  else if (type==='setSafeZone') inSafeZone = data.inSafeZone;
  else if (type==='toastBadge') {
    const b = BADGE_DEFS[e.data.badgeId];
    if (b) toast('Badge débloqué : ' + b.label, true);
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
  if (data.maxWeight)      MAX_WEIGHT   = data.maxWeight;
  if (data.maxStashWeight) STASH_MAX_KG = data.maxStashWeight;
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
  dropMode      = { id: data.dropId, label: data.dropLabel || 'DROP DE RAVITAILLEMENT', items: data.dropItems || [] };
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
  unlockTransfer();
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
  unlockTransfer();
  outpostMode  = null;
  dropMode     = null;
  deathBagMode = null;
  document.getElementById('overlay').classList.remove('open');
  closeCtx();
}
function onRefresh(data) {
  unlockTransfer(); // débloquer le verrou de transfert
  if (data.maxWeight)      MAX_WEIGHT   = data.maxWeight;
  if (data.maxStashWeight) STASH_MAX_KG = data.maxStashWeight;
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
    // Coffre avant-poste : sans limite de poids — on affiche le nombre d'items
    // (la seule métrique utile ici) plutôt qu'un simple rappel « sans limite ».
    if (titleEl) titleEl.textContent = outpostMode.label;
    const nStacks = outpostMode.items.length;
    const nUnits  = outpostMode.items.reduce((s, i) => s + (i.count || 1), 0);
    weightEl.textContent = nStacks === 0
      ? 'Vide · sans limite de poids'
      : nUnits + ' item' + (nUnits > 1 ? 's' : '') + ' · sans limite de poids';
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
// Filet de sécurité : si la réponse serveur ne revient jamais (event droppé,
// callback DB perdu, resource redémarrée), le verrou se libère seul. Sans lui,
// l'inventaire reste définitivement bloqué — plus aucun clic droit ni drag ne
// passe, et rouvrir l'UI ne change rien (la page NUI n'est pas rechargée).
let transferLocked = false;
let transferLockTimer = null;
const TRANSFER_LOCK_TIMEOUT = 3000;

function lockTransfer() {
  transferLocked = true;
  if (transferLockTimer) clearTimeout(transferLockTimer);
  transferLockTimer = setTimeout(() => { transferLocked=false; transferLockTimer=null; }, TRANSFER_LOCK_TIMEOUT);
}

function unlockTransfer() {
  transferLocked=false;
  if (transferLockTimer) { clearTimeout(transferLockTimer); transferLockTimer=null; }
}

// ── Capacité du conteneur protégé : test côté client avant l'aller-retour ──
// Le serveur reste seul juge (il refait le calcul avec les mêmes poids), mais
// envoyer un dépôt voué à l'échec à chaque clic droit ne sert à rien : quand le
// coffre est plein, le spam de clics devient un spam d'events serveur.
function stashWeightNow() {
  let w = 0;
  (state.stash || []).forEach(i => { w += getWeight(i.name) * i.count; });
  return w;
}
function stashHasRoomFor(name, qty) {
  return stashWeightNow() + getWeight(name) * qty <= STASH_MAX_KG + 0.0001;
}
let stashFullToastAt = 0;
function stashFullToast() {
  // Un seul toast par 1,5 s : en spammant le clic droit sur un coffre plein on
  // enverrait sinon une notification par clic.
  const now = Date.now();
  if (now - stashFullToastAt < 1500) return;
  stashFullToastAt = now;
  toast('Conteneur protégé plein ! (' + STASH_MAX_KG.toFixed(1) + ' kg max)', false);
}

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

  const inv = state.inventory || [];

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
      // Pastille en ligne : la variante mini (emblème seul). Le dessin 120×140
      // réduit à 12px n'était plus lisible.
      const iconHtml = `<span class="active-badge-svg">${bDef.mini}</span>`;
      activeBadgeEl.innerHTML = iconHtml + bDef.label;
      activeBadgeEl.style.borderColor = bDef.color;
      activeBadgeEl.style.color = bDef.color;
      activeBadgeEl.style.display = 'inline-flex';
    } else {
      activeBadgeEl.style.display = 'none';
    }
  }

  // Ped actuel
  const pedModelEl = document.getElementById('ped-current-model');
  if (pedModelEl) {
    const pm = p.pedModel || '';
    pedModelEl.textContent = pm ? pm.toUpperCase().replace(/^(A_|S_|G_|IG_|CSB_|U_|MP_)/, '') : 'FREEMODE';
  }
  const pedChangeBtn = document.getElementById('ped-change-btn');
  if (pedChangeBtn) {
    const canChange = vcData.tier === 'gold' || vcData.tier === 'diamond';
    pedChangeBtn.classList.toggle('ped-change-locked', !canChange);
    pedChangeBtn.textContent = canChange ? 'CHANGER DE PED' : 'CHANGER DE PED 🔒 GOLD';
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
    const b = BADGE_DEFS[id] || VantaBadges.inconnu(id);
    const isActive = id === activeBadgeId;
    // Insigne complet : ailes, lames, ronces et listel. La grille est
    // dimensionnée pour, voir .badges-grid dans style.css.
    const iconHtml = b.full();
    const iconClass = 'badge-icon badge-icon-svg';
    return `<div class="badge-card ${isActive?'badge-active':''}"
               onclick="setActiveBadge('${id}')" title="${b.label}">
      <div class="${iconClass}">${iconHtml}</div>
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
  if (leaderboardCategory === 'controls') return Number(entry.controls || 0);
  return Number(entry.kills || 0);
}

function leaderboardCategoryLabel() {
  if (leaderboardCategory === 'deaths') return 'MORTS';
  if (leaderboardCategory === 'zombies') return 'ZOMBIES';
  if (leaderboardCategory === 'kd') return 'K/D';
  if (leaderboardCategory === 'redzoneKills') return 'RZ KILLS';
  if (leaderboardCategory === 'redzoneZombies') return 'RZ ZOMBIES';
  if (leaderboardCategory === 'controls') return 'RZ CONTROL';
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

// ── Menu contextuel natif : toujours annulé ──────────────────────────────
// Seules les cartes d'items appelaient preventDefault (via oncontextmenu). Un
// clic droit qui tombe à côté (gouttière de 8px de la grille, panneau, fond)
// laisse CEF ouvrir son menu contextuel natif : il se dessine par-dessus le
// NUI, avale clics et touches, et l'inventaire paraît figé — plus moyen de le
// fermer ni de déplacer un item. Très facile à déclencher en spammant le clic
// droit sur un conteneur plein (les cartes ne bougent pas, donc on continue de
// cliquer au même endroit). Même garde que pvp_garage.
document.addEventListener('contextmenu', e => e.preventDefault());

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
        lockTransfer();
        lua('outpostStashDeposit', { outpostId: outpostMode.id, item: dragging.name, qty: 1 });
      } else if (!stashHasRoomFor(dragging.name, 1)) {
        stashFullToast();
      } else {
        lockTransfer();
        lua('stashDeposit', { item: dragging.name, qty: 1 });
      }
    } else if (invZone && dragging.source === 'deathbag' && !transferLocked) {
      lockTransfer();
      lua('deathBagWithdraw', { bagId: deathBagMode.id, item: dragging.name, qty: 1 });
    } else if (invZone && dragging.source === 'drop' && !transferLocked) {
      lockTransfer();
      lua('dropWithdraw', { dropId: dropMode.id, item: dragging.name, qty: 1 });
    } else if (invZone && dragging.source === 'outpost' && !transferLocked) {
      lockTransfer();
      lua('outpostStashWithdraw', { outpostId: outpostMode.id, item: dragging.name, qty: 1 });
    } else if (invZone && dragging.source === 'stash' && !transferLocked) {
      lockTransfer();
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
    lockTransfer();
    lua('deathBagWithdraw', { bagId: deathBagMode.id, item: name, qty: 1 });
    return;
  } else if (source === 'drop') {
    lockTransfer();
    lua('dropWithdraw', { dropId: dropMode.id, item: name, qty: 1 });
  } else if (source === 'inv') {
    if (dropMode || deathBagMode) {
      // On ne peut pas déposer dans un drop ou un death bag
    } else if (outpostMode) {
      lockTransfer();
      lua('outpostStashDeposit', { outpostId: outpostMode.id, item: name, qty: 1 });
    } else {
      if (!stashHasRoomFor(name, 1)) { stashFullToast(); return; }
      lockTransfer();
      lua('stashDeposit', { item: name, qty: 1 });
    }
  } else if (source === 'outpost') {
    lockTransfer();
    lua('outpostStashWithdraw', { outpostId: outpostMode.id, item: name, qty: 1 });
  } else if (source === 'stash') {
    lockTransfer();
    lua('stashWithdraw', { item: name, qty: 1 });
  }
}

// ══ Toast ════════════════════════════════════════════════════════════════
// Pont vers la pile de notifications partagee de vanta_ui.
// Le NUI de pvp_inventory ne peut pas ecrire dans la page NUI d une autre
// resource : on passe par Lua, qui relaie a exports['vanta_ui']:notify.
// 2e argument : true -> succes, false -> erreur, omis -> info.
function toast(msg, ok) {
  const kind = ok === true ? 'success' : ok === false ? 'error' : 'info';
  lua('notify', { msg: String(msg == null ? '' : msg), kind });
}

// ══ Fetch Lua ════════════════════════════════════════════════════════════
// Retourne la Promise du fetch (résolue en JSON) pour les appelants qui ont
// besoin de la réponse Lua ; les appels existants qui ignorent la valeur de
// retour continuent de fonctionner à l'identique (fire-and-forget).
function lua(cb, data) {
  return fetch('https://pvp_inventory/'+cb, {
    method:'POST', headers:{'Content-Type':'application/json'},
    body: JSON.stringify(data)
  }).then(r => r.json()).catch(() => ({}));
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
  }).catch(() => toast('Erreur chargement crew.', false));
}

function renderCrewTab() {
  const noCrew = document.getElementById('crew-no-crew');
  const inCrew = document.getElementById('crew-in-crew');
  if (!noCrew || !inCrew) return;

  if (!crewData) {
    noCrew.style.display = '';
    inCrew.style.display = 'none';
    const cost = document.getElementById('crew-cost-val');
    if (cost) cost.textContent = '$' + Number(crewCost || 5000).toLocaleString('fr-FR');
    renderCrewInvites();
    return;
  }

  noCrew.style.display = 'none';
  inCrew.style.display = '';
  const invitePanel = document.getElementById('crew-invite-panel');
  if (invitePanel) invitePanel.style.display = 'none';
  crewMyRank = crewData.myRank;

  const crewColor = crewData.color || '#a0a0a8';
  const tagEl = document.getElementById('crew-tag-disp');
  if (tagEl) {
    tagEl.textContent = crewData.tag || '';
    tagEl.style.color = crewColor;
    tagEl.style.background = crewColor + '18';
    tagEl.style.borderColor = crewColor + '55';
  }
  const nameEl = document.getElementById('crew-name-disp');
  if (nameEl) nameEl.textContent = crewData.name || 'Crew';

  const dateEl = document.getElementById('crew-date-disp');
  if (dateEl) {
    dateEl.textContent = crewData.created_at ? 'Créé le ' + new Date(crewData.created_at).toLocaleDateString('fr-FR') : '';
  }

  const colorArea = document.getElementById('crew-color-area');
  if (colorArea) colorArea.style.display = crewMyRank === 'owner' ? '' : 'none';
  const colorInput = document.getElementById('crew-color-input');
  if (colorInput) colorInput.value = crewColor;

  const motdText = document.getElementById('crew-motd-text');
  const motdEdit = document.getElementById('crew-motd-edit');
  if (motdText) motdText.textContent = crewData.motd || 'Aucun message défini.';
  const motdBox = document.getElementById('crew-motd-box');
  if (motdBox) motdBox.style.borderLeftColor = crewColor;
  if (motdEdit) motdEdit.style.display = (crewMyRank === 'owner' || crewMyRank === 'officer') ? 'flex' : 'none';
  const motdInput = document.getElementById('crew-motd-input');
  if (motdInput) motdInput.value = crewData.motd || '';

  const kills = Number(crewData.kills_total || 0);
  const deaths = Number(crewData.deaths_total || 0);
  const kd = deaths > 0 ? (kills / deaths).toFixed(2) : kills.toFixed(2);
  const setText = (id, value) => { const el = document.getElementById(id); if (el) el.textContent = value; };
  setText('crew-s-kills', kills.toLocaleString('fr-FR'));
  setText('crew-s-deaths', deaths.toLocaleString('fr-FR'));
  setText('crew-s-kd', kd);
  setText('crew-s-zombies', Number(crewData.zombies_total || 0).toLocaleString('fr-FR'));
  setText('crew-s-count', crewData.members ? crewData.members.length : 0);
  setText('crew-s-best', crewData.bestPlayer || '---');
  setText('crew-s-bank', Number(crewData.bank || 0).toLocaleString('fr-FR'));
  const best = document.getElementById('crew-s-best');
  if (best) best.title = 'Niveau ' + (crewData.level || 1) + ' | XP ' + (crewData.xp || 0) + ' | Banque crew $' + (crewData.bank || 0);

  const inviteBtn = document.getElementById('crew-btn-invite');
  if (inviteBtn) inviteBtn.style.display = crewMyRank === 'member' || crewMyRank === 'recruit' || crewMyRank === 'quartermaster' ? 'none' : '';
  const disbandBtn = document.getElementById('crew-btn-disband');
  if (disbandBtn) disbandBtn.style.display = crewMyRank === 'owner' ? '' : 'none';

  renderCrewMembers();
  renderCrewActivity();
  renderCrewStash();
  renderCrewObjectives();
  renderCrewEvents();
  renderCrewContract();
  renderCrewShop();
  renderCrewHistory();
}

function roleLabel(rank) {
  const labels = { owner:'CHEF', officer:'OFFICIER', quartermaster:'INTENDANT', recruiter:'RECRUTEUR', member:'MEMBRE', recruit:'RECRUE' };
  return labels[rank] || 'MEMBRE';
}

function renderCrewMembers() {
  const list = document.getElementById('crew-members-list');
  if (!list) return;
  if (!crewData || !crewData.members || crewData.members.length === 0) {
    list.innerHTML = '<p class="crew-empty">Aucun membre</p>';
    return;
  }
  list.innerHTML = crewData.members.map((m, i) => {
    const rc = 'crew-rank-' + m.rank;
    const rl = roleLabel(m.rank);
    const kd = (m.deaths || 0) > 0 ? ((m.kills || 0) / m.deaths).toFixed(2) : (m.kills || 0).toFixed(2);
    const onClass = m.online ? 'on' : 'off';
    let acts = '';
    if (crewMyRank === 'owner' && m.rank !== 'owner') {
      const ranks = ['officer', 'quartermaster', 'recruiter', 'member', 'recruit'];
      acts = ranks.map(r => `<button class="crew-btn-sm promote" onclick="crewPromote('${esc(m.identifier)}','${r}')" title="${roleLabel(r)}">${roleLabel(r).slice(0,3)}</button>`).join('') +
        `<button class="crew-btn-sm danger" onclick="crewKick('${esc(m.identifier)}')" title="Exclure">X</button>`;
    } else if (crewMyRank === 'officer' && (m.rank === 'member' || m.rank === 'recruit')) {
      acts = `<button class="crew-btn-sm danger" onclick="crewKick('${esc(m.identifier)}')" title="Exclure">X</button>`;
    }
    const avatar = m.avatarUrl ? `<img src="${esc(m.avatarUrl)}" class="cm-avatar" onerror="this.style.display='none'">` : `<div class="cm-avatar cm-avatar-placeholder"></div>`;
    return `<div class="crew-member-row${i === 0 ? ' top1' : ''}">
      <span class="cm-rank-num${i === 0 ? ' gold' : ''}">${i + 1}</span>
      <div class="cm-info">${avatar}<span class="cm-online ${onClass}"></span><span class="cm-name">${esc(m.name || 'Joueur')}</span><span class="crew-rank ${rc}">${rl}</span></div>
      <span class="cm-stat">${fmt(m.kills || 0)}</span><span class="cm-stat">${fmt(m.deaths || 0)}</span><span class="cm-stat">${kd}</span><span class="cm-stat">${fmt(m.zombies_killed || 0)}</span>
      <div class="cm-actions">${acts}</div>
    </div>`;
  }).join('');
}

function renderCrewActivity() {
  const list = document.getElementById('crew-activity-list');
  if (!list) return;
  if (!crewData || !crewData.activity || crewData.activity.length === 0) {
    list.innerHTML = '<p class="crew-empty">Aucune activité récente</p>';
    return;
  }
  const icons = { create:'+', join:'+', kick:'-', leave:'-', motd:'msg', promote:'*', kill:'KO', zombie:'Z', stash:'BOX', objective:'OBJ', event:'EVT' };
  list.innerHTML = crewData.activity.map(a => {
    const d = new Date(a.created_at);
    const time = d.toLocaleDateString('fr-FR') + ' ' + d.toLocaleTimeString('fr-FR', { hour:'2-digit', minute:'2-digit' });
    return `<div class="crew-activity-row"><span class="ca-icon">${icons[a.type] || 'LOG'}</span><span class="ca-msg">${esc(a.message || '')}</span><span class="ca-time">${time}</span></div>`;
  }).join('');
}

function renderCrewStash() {
  const list = document.getElementById('crew-stash-list');
  if (!list) return;
  const stash = crewData && crewData.stash ? crewData.stash : [];
  if (!stash.length) {
    list.innerHTML = '<p class="crew-empty">Coffre vide</p>';
    return;
  }
  list.innerHTML = stash.map(s => `<div class="crew-member-row" onclick="document.getElementById('crew-stash-item').value='${esc(s.item)}'">
    <span class="cm-info"><span class="cm-name">${esc(s.item)}</span></span><span class="cm-stat">x${fmt(s.count || 0)}</span>
  </div>`).join('');
}

function renderCrewObjectives() {
  const list = document.getElementById('crew-objectives-list');
  if (!list) return;
  const objectives = crewData && crewData.objectives ? crewData.objectives : [];
  if (!objectives.length) {
    list.innerHTML = '<p class="crew-empty">Aucun objectif actif</p>';
    return;
  }
  list.innerHTML = objectives.map(o => {
    const progress = Number(o.progress || 0);
    const target = Math.max(1, Number(o.target || 1));
    const pct = Math.min(100, Math.floor((progress / target) * 100));
    const done = Number(o.completed || 0) === 1;
    return `<div class="crew-objective-row ${done ? 'done' : ''}"><div class="crew-objective-head"><strong>${esc(o.label || 'Objectif')}</strong><span>${done ? 'TERMINE' : pct + '%'}</span></div><div class="crew-progress"><i style="width:${pct}%"></i></div><div class="crew-objective-meta">${fmt(progress)} / ${fmt(target)} | +${fmt(o.reward_xp || 0)} XP | +$${fmt(o.reward_bank || 0)}</div></div>`;
  }).join('');
}

function renderCrewEvents() {
  const list = document.getElementById('crew-events-list');
  if (!list) return;
  const events = crewData && crewData.events ? crewData.events : [];
  if (!events.length) {
    list.innerHTML = '<p class="crew-empty">Aucun evenement planifie</p>';
    return;
  }
  list.innerHTML = events.map(ev => `<div class="crew-event-row"><div><strong>${esc(ev.title || 'Event')}</strong><span>${esc(ev.starts_at || 'Date libre')} | ${esc(ev.status || 'planned')}</span></div><div class="crew-event-actions"><button class="crew-btn-sm promote" onclick="crewSetEventStatus(${Number(ev.id)}, 'active')">START</button><button class="crew-btn-sm promote" onclick="crewSetEventStatus(${Number(ev.id)}, 'won')">WIN</button><button class="crew-btn-sm danger" onclick="crewSetEventStatus(${Number(ev.id)}, 'cancelled')">X</button></div></div>`).join('');
}

// ── Contrat quotidien de crew (élimination de zombies) ──────────────────
function renderCrewContract() {
  const box = document.getElementById('crew-contract-box');
  if (!box) return;
  const c = crewData && crewData.contract;
  if (!c) {
    box.innerHTML = '<p class="crew-empty">Aucun contrat en cours.</p>';
    return;
  }
  const progress = Number(c.progress || 0);
  const target = Math.max(1, Number(c.target || 1));
  const pct = Math.min(100, Math.floor((progress / target) * 100));
  const done = Number(c.completed || 0) === 1;
  const participants = Number(c.participants || 0);
  const rewardLine = done ? ` | +${fmt(c.reward_credits || 0)} crédits gagnés` : '';
  box.innerHTML = `<div class="crew-objective-row ${done ? 'done' : ''}">
      <div class="crew-objective-head"><strong>Contrat du jour — Élimination de zombies</strong><span>${done ? 'TERMINÉ' : pct + '%'}</span></div>
      <div class="crew-progress"><i style="width:${pct}%"></i></div>
      <div class="crew-objective-meta">${fmt(progress)} / ${fmt(target)} zombies | ${participants} participant${participants > 1 ? 's' : ''} actif${participants > 1 ? 's' : ''}${rewardLine}</div>
    </div>
    <p class="crew-empty">L'objectif s'ajuste automatiquement au nombre de membres qui participent réellement ce jour-là. Récompense en crédits de crew, versée dans la trésorerie collective. Se réinitialise chaque jour.</p>`;
}

// ── Boutique de crew : avantages temporaires ─────────────────────────────
function renderCrewShop() {
  const list = document.getElementById('crew-shop-list');
  if (!list) return;
  const items = crewData && crewData.shopItems ? crewData.shopItems : [];
  const canBuy = crewMyRank === 'owner' || crewMyRank === 'officer';
  const hint = document.getElementById('crew-shop-hint');
  if (hint) hint.style.display = canBuy ? 'none' : '';
  if (!items.length) {
    list.innerHTML = '<p class="crew-empty">Boutique indisponible.</p>';
    return;
  }
  const now = Date.now() / 1000;
  list.innerHTML = items.map(it => {
    const active = it.activeUntil && it.activeUntil > now;
    const minsLeft = active ? Math.max(1, Math.ceil((it.activeUntil - now) / 60)) : 0;
    const disabled = active || !canBuy;
    const btnLabel = active ? ('ACTIF — ' + minsLeft + ' min restantes') : ('ACHETER — ' + fmt(it.cost) + ' crédits');
    return `<div class="crew-shop-item${active ? ' active' : ''}">
        <div class="crew-shop-item-head"><strong>${esc(it.label)}</strong><span>${Number(it.durationMinutes || 0)} min</span></div>
        <p class="crew-shop-item-desc">${esc(it.description || '')}</p>
        <button class="crew-btn-action" ${disabled ? 'disabled' : ''} onclick="crewBuyShop('${esc(it.key)}')">${btnLabel}</button>
      </div>`;
  }).join('');
}

// ── Historique des gains/dépenses de la trésorerie de crew ──────────────
function renderCrewHistory() {
  const list = document.getElementById('crew-history-list');
  if (!list) return;
  const history = crewData && crewData.history ? crewData.history : [];
  if (!history.length) {
    list.innerHTML = '<p class="crew-empty">Aucune opération de trésorerie.</p>';
    return;
  }
  list.innerHTML = history.map(h => {
    const amount = Number(h.amount || 0);
    const positive = amount > 0;
    const d = new Date(h.created_at);
    const time = d.toLocaleDateString('fr-FR') + ' ' + d.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
    const who = h.player_name ? (' — ' + esc(h.player_name)) : '';
    return `<div class="crew-history-row ${positive ? 'gain' : 'expense'}">
        <div class="ch-info"><span class="ch-label">${esc(h.label || '')}${who}</span><span class="ch-time">${time}</span></div>
        <span class="ch-amount">${positive ? '+' : ''}${fmt(amount)}</span>
      </div>`;
  }).join('');
}

function renderCrewInvites() {
  const list = document.getElementById('crew-invites-list');
  if (!list) return;
  if (!crewInvites || crewInvites.length === 0) {
    list.innerHTML = '<p class="crew-empty">Aucune invitation</p>';
    return;
  }
  list.innerHTML = crewInvites.map(inv => `<div class="crew-invite-row"><div class="crew-invite-info"><span class="crew-invite-name">${esc(inv.crew_name || 'Crew')}</span><span class="crew-invite-tag">[${esc(inv.crew_tag || '')}]</span></div><div class="crew-invite-btns"><button class="crew-btn-sm promote" onclick="crewAcceptInvite(${Number(inv.crew_id)})">Accepter</button><button class="crew-btn-sm danger" onclick="crewDeclineInvite(${Number(inv.crew_id)})">Refuser</button></div></div>`).join('');
}

function renderCrewOnlinePlayers() {
  const list = document.getElementById('crew-online-list');
  if (!list) return;
  if (!crewPlayers || crewPlayers.length === 0) {
    list.innerHTML = '<p class="crew-empty">Aucun joueur en ligne</p>';
    return;
  }
  list.innerHTML = crewPlayers.map(p => `<div class="crew-player-row" onclick="crewInvitePlayer(${Number(p.id)})"><span class="crew-player-name">${esc(p.name || 'Joueur')}</span><span class="crew-player-id">ID: ${Number(p.id)}</span></div>`).join('');
}

function bindCrewButton(id, handler) {
  const el = document.getElementById(id);
  if (el && !el.dataset.bound) {
    el.dataset.bound = '1';
    el.addEventListener('click', handler);
  }
}

bindCrewButton('crew-btn-create', () => {
  const name = document.getElementById('crew-input-name').value.trim();
  const tag = document.getElementById('crew-input-tag').value.trim();
  if (!name || !tag) { toast('Remplissez le nom et le tag.', false); return; }
  crewFetch('crewCreate', { name, tag }).then(r => { toast(r.message, r.ok); if (r.ok) setTimeout(loadCrewTab, 800); });
});

document.querySelectorAll('.crew-subtab').forEach(t => {
  if (t.dataset.bound) return;
  t.dataset.bound = '1';
  t.addEventListener('click', () => {
    document.querySelectorAll('.crew-subtab').forEach(s => s.classList.remove('active'));
    t.classList.add('active');
    const sub = t.dataset.subtab;
    ['members', 'activity', 'stash', 'objectives', 'events', 'contract', 'shop', 'history'].forEach(name => {
      const el = document.getElementById('crew-sub-' + name);
      if (el) el.style.display = sub === name ? '' : 'none';
    });
  });
});

const crewColorInput = document.getElementById('crew-color-input');
if (crewColorInput && !crewColorInput.dataset.bound) {
  crewColorInput.dataset.bound = '1';
  crewColorInput.addEventListener('change', e => crewFetch('crewSetColor', { color: e.target.value }).then(r => { toast(r.message, r.ok); if (r.ok) setTimeout(loadCrewTab, 500); }));
}

bindCrewButton('crew-motd-save', () => {
  const motd = document.getElementById('crew-motd-input').value.trim();
  crewFetch('crewSetMotd', { motd }).then(r => { toast(r.message, r.ok); if (r.ok) setTimeout(loadCrewTab, 500); });
});

bindCrewButton('crew-btn-invite', () => { document.getElementById('crew-invite-panel').style.display = ''; renderCrewOnlinePlayers(); });
bindCrewButton('crew-btn-cancel-invite', () => { document.getElementById('crew-invite-panel').style.display = 'none'; });
bindCrewButton('crew-stash-deposit', () => {
  const item = document.getElementById('crew-stash-item').value.trim();
  const qty = Number(document.getElementById('crew-stash-qty').value || 1);
  crewFetch('crewStashDeposit', { item, qty }).then(r => { toast(r.message, r.ok); if (r.ok) setTimeout(loadCrewTab, 500); });
});
bindCrewButton('crew-stash-withdraw', () => {
  const item = document.getElementById('crew-stash-item').value.trim();
  const qty = Number(document.getElementById('crew-stash-qty').value || 1);
  crewFetch('crewStashWithdraw', { item, qty }).then(r => { toast(r.message, r.ok); if (r.ok) setTimeout(loadCrewTab, 500); });
});
bindCrewButton('crew-event-create', () => {
  const title = document.getElementById('crew-event-title').value.trim();
  const startsAt = document.getElementById('crew-event-start').value.trim();
  crewFetch('crewCreateEvent', { title, type: 'operation', startsAt }).then(r => { toast(r.message, r.ok); if (r.ok) setTimeout(loadCrewTab, 500); });
});
bindCrewButton('crew-btn-leave', () => crewShowConfirm('Voulez-vous quitter le crew ?', () => crewFetch('crewLeave').then(r => { toast(r.message, r.ok); if (r.ok) setTimeout(loadCrewTab, 800); })));
bindCrewButton('crew-btn-disband', () => crewShowConfirm('DISSOUDRE le crew ? Cette action est irreversible !', () => crewFetch('crewDisband').then(r => { toast(r.message, r.ok); if (r.ok) setTimeout(loadCrewTab, 800); })));

window.crewInvitePlayer = targetId => crewFetch('crewInvitePlayer', { targetId }).then(r => toast(r.message, r.ok));
window.crewAcceptInvite = crewId => crewFetch('crewAcceptInvite', { crewId }).then(r => { toast(r.message, r.ok); if (r.ok) setTimeout(loadCrewTab, 800); });
window.crewDeclineInvite = crewId => crewFetch('crewDeclineInvite', { crewId }).then(r => { toast(r.message, r.ok); if (r.ok) { crewInvites = crewInvites.filter(i => i.crew_id !== crewId); renderCrewInvites(); } });
window.crewPromote = (identifier, rank) => crewShowConfirm('Changer le role de ce joueur ?', () => crewFetch('crewPromote', { identifier, rank }).then(r => { toast(r.message, r.ok); if (r.ok) setTimeout(loadCrewTab, 800); }));
window.crewKick = identifier => crewShowConfirm('Exclure ce membre du crew ?', () => crewFetch('crewKick', { identifier }).then(r => { toast(r.message, r.ok); if (r.ok) setTimeout(loadCrewTab, 800); }));
window.crewSetEventStatus = (eventId, status) => crewFetch('crewSetEventStatus', { eventId, status }).then(r => { toast(r.message, r.ok); if (r.ok) setTimeout(loadCrewTab, 500); });
window.crewBuyShop = key => crewFetch('crewBuyShopItem', { key }).then(r => { toast(r.message, r.ok); if (r.ok) setTimeout(loadCrewTab, 500); });
// ══════════════════════════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════════════════════════
//   PED SELECTOR
// ══════════════════════════════════════════════════════════════════════════

var PED_CATEGORIES = {
  all:      'TOUS',
  freemode: 'FREEMODE',
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
  animal:   'ANIMAUX',
  misc:     'DIVERS',
};

// Le catalogue complet est déclaré dans ped_catalog.js (const PED_CATALOG),
// chargé avant ce script — pas de redéclaration ici (var + const sur le même
// identifiant lève une SyntaxError qui bloque tout app.js).

var pedSelectorActive = false;
var pedSelectedModel  = '';
var pedCurrentCategory = 'all';

function getPedAccess(pedTier) {
  // Changement de ped après création réservé aux abonnés Gold/Diamond —
  // sans abonnement, aucun ped n'est sélectionnable (le choix libre unique
  // se fait uniquement à la création du personnage, via pvp_character).
  const t = vcData.tier || 'none';
  if (t === 'diamond') return true;
  if (t === 'gold')    return pedTier !== 'diamond';
  return false;
}

function openPedSelector() {
  const t = vcData.tier || 'none';
  if (t !== 'gold' && t !== 'diamond') {
    toast('Changement de ped réservé aux abonnés Gold / Diamond');
    return;
  }

  pedSelectorActive = true;
  pedSelectedModel  = (state.profile && state.profile.pedModel) || '';
  pedCurrentCategory = 'all';

  document.getElementById('ped-selector-overlay').style.display = 'flex';

  // Tier info
  const tierEl = document.getElementById('ped-tier-info');
  const total = PED_CATALOG.length;
  const accessible = PED_CATALOG.filter(p => getPedAccess(p.tier)).length;
  const tierLabel = t === 'diamond' ? '💎 DIAMOND — TOUS LES PEDS' : '👑 GOLD — CATALOGUE DE BASE';
  tierEl.innerHTML = `${tierLabel} <span style="margin-left:8px;opacity:0.5">${accessible}/${total} disponibles</span>`;

  // Categories
  renderPedCategories();
  renderPedGrid();

  // Activer la caméra preview côté client
  lua('openPedSelector', {}).then(function (res) {
    if (res && res.ok === false) {
      closePedSelector();
    }
  });
}

function closePedSelector() {
  pedSelectorActive = false;
  document.getElementById('ped-selector-overlay').style.display = 'none';
}

function cancelPedSelection() {
  closePedSelector();
  lua('cancelPedSelector', {});
}

function confirmPedSelection() {
  closePedSelector();
  lua('confirmPedModel', { model: pedSelectedModel });
  if (state.profile) state.profile.pedModel = pedSelectedModel;
  renderProfile();
}

function renderPedCategories() {
  const container = document.getElementById('ped-categories');
  container.innerHTML = Object.entries(PED_CATEGORIES).map(([key, label]) =>
    `<button class="ped-cat-btn ${key === pedCurrentCategory ? 'active' : ''}"
            onclick="setPedCategory('${key}')">${label}</button>`
  ).join('');
}

function setPedCategory(cat) {
  pedCurrentCategory = cat;
  renderPedCategories();
  renderPedGrid();
}

function filterPedGrid() {
  renderPedGrid();
}

function renderPedGrid() {
  const grid = document.getElementById('ped-grid');
  const search = (document.getElementById('ped-search').value || '').toLowerCase().trim();

  var peds = PED_CATALOG;
  if (pedCurrentCategory !== 'all') {
    peds = peds.filter(p => p.cat === pedCurrentCategory);
  }
  if (search) {
    peds = peds.filter(p => p.model.includes(search) || p.name.toLowerCase().includes(search));
  }

  // Limiter à 200 pour la perf (CEF)
  const displayed = peds.slice(0, 200);
  const hasMore = peds.length > 200;

  grid.innerHTML = displayed.map(p => {
    const accessible = getPedAccess(p.tier);
    const selected   = pedSelectedModel === p.model;
    const tierTag = p.tier === 'gold' ? '<span class="ped-card-tier ped-tier-gold">G</span>' :
                    p.tier === 'diamond' ? '<span class="ped-card-tier ped-tier-diamond">D</span>' : '';
    const lockIcon = !accessible ? '<div class="ped-lock-icon">🔒</div>' : '';

    return `<div class="ped-card ${selected ? 'ped-selected' : ''} ${!accessible ? 'ped-locked' : ''}"
                onclick="${accessible ? `selectPed('${p.model}')` : `toast('Abonnement ${p.tier === 'diamond' ? 'Diamond' : 'Gold'} requis')`}">
      ${tierTag}
      ${lockIcon}
      <div class="ped-card-name">${p.name}</div>
    </div>`;
  }).join('') + (hasMore ? '<div style="grid-column:1/-1;text-align:center;color:var(--v-text-tertiary);font-size:10px;padding:8px;">Affinez votre recherche...</div>' : '');
}

function selectPed(model) {
  pedSelectedModel = model;
  renderPedGrid();
  // Preview en temps réel
  lua('previewPed', { model: model });
}
//   VCOINS — Onglet abonnements & marché
// ══════════════════════════════════════════════════════════════════════════

// Syncs depuis pvp_vcoins client (via NUI message relayé par le client Lua)
window.addEventListener('message', function(e) {
  if (e.data.type === 'vcSync') {
    if (e.data.tier    !== undefined) vcData.tier    = e.data.tier;
    if (e.data.vcoins  !== undefined) vcData.vcoins  = e.data.vcoins;
    if (e.data.expires !== undefined) vcData.expires = e.data.expires;
    if (document.getElementById('view-vcoins').classList.contains('active')) {
      renderVCoinsStatus();
    }
    // Rafraîchit le poids stash affiché si le stash est ouvert
    if (e.data.maxStashWeight) {
      STASH_MAX_KG = e.data.maxStashWeight;
      renderInventory();
    }
  }
});

// Charge les données depuis le serveur (à l'ouverture de l'onglet)
function loadVCoinsTab() {
  fetch('https://pvp_inventory/vcGetData', { method: 'POST', body: '{}' })
    .then(r => r.json())
    .then(data => {
      if (!data) return;
      vcData = { ...vcData, ...data };
      renderVCoinsStatus();
      renderVCoinsMarket();
    })
    .catch(() => {});
}

// ── Rendu statut abonnement ───────────────────────────────────────────────
// Prix et durée : doivent rester alignés sur TIERS / SUB_DURATION_DAYS dans
// pvp_vcoins/server/server.lua. Le serveur reste seul juge du débit.
var VC_PRIX  = { gold: 800, diamond: 1500 };
var VC_NOM   = { gold: 'GOLD', diamond: 'DIAMOND' };
// Grade désigné par un premier clic. Le second clic (sur le bouton) souscrit.
var vcArme = null;

function vcFmt(n) { return Number(n || 0).toLocaleString('fr-FR'); }

// 'YYYY-MM-DD HH:MM:SS' → nombre de jours entiers restants, ou null.
function vcJoursRestants(s) {
  if (!s) return null;
  const d = new Date(String(s).replace(' ', 'T'));
  if (isNaN(d.getTime())) return null;
  return Math.max(0, Math.ceil((d.getTime() - Date.now()) / 86400000));
}

function vcArmer(tier) {
  // Le grade déjà pris ne s'arme pas : son bouton prolonge directement.
  if (vcData.tier === tier) return;
  vcArme = (vcArme === tier) ? null : tier;
  renderVCoinsStatus();
}

function vcCliqueBouton(tier) {
  const prix = VC_PRIX[tier];
  if ((vcData.vcoins || 0) < prix) {
    toast('Il te manque ' + vcFmt(prix - (vcData.vcoins || 0)) + ' VC', false);
    return;
  }
  // Grade déjà actif → prolongation, pas de confirmation à armer.
  if (vcData.tier === tier || vcArme === tier) { vcArme = null; vcSubscribe(tier); return; }
  vcArme = tier;
  renderVCoinsStatus();
}

function renderVCoinsStatus() {
  const tier  = vcData.tier || 'none';
  const solde = vcData.vcoins || 0;
  const jours = vcJoursRestants(vcData.expires);

  // ── Bandeau ──
  const badge   = document.getElementById('vc-tier-badge');
  const expiry  = document.getElementById('vc-expiry');
  const insigne = document.getElementById('vc-statut-insigne');
  const prolong = document.getElementById('vc-btn-prolonger');

  document.getElementById('vc-balance').innerHTML =
    vcFmt(solde) + ' <span class="vc-solde-u">VC</span>';

  if (tier === 'gold' || tier === 'diamond') {
    badge.textContent = VC_NOM[tier];
    badge.style.color = tier === 'gold' ? '#e9c66d' : '#64d2ff';
    expiry.innerHTML = jours === null
      ? '— actif'
      : (jours <= 0 ? '— expire aujourd\'hui' : '— actif, expire dans <b>' + jours + ' jour' + (jours > 1 ? 's' : '') + '</b>');
    const def = window.BADGE_DEFS && BADGE_DEFS[tier + '_member'];
    insigne.innerHTML = def ? def.mini : '';
    insigne.style.display = def ? 'block' : 'none';
    prolong.style.display = '';
    prolong.className = 'vc-cta vc-cta-court vc-pour-' + tier;
    prolong.textContent = 'PROLONGER 30 JOURS — ' + vcFmt(VC_PRIX[tier]) + ' VC';
    prolong.onclick = function () { vcCliqueBouton(tier); };
  } else {
    badge.textContent = 'SANS GRADE';
    badge.style.color = '';
    expiry.textContent = '— aucun avantage actif';
    insigne.style.display = 'none';
    insigne.innerHTML = '';
    prolong.style.display = 'none';
  }

  document.getElementById('vc-sec-titre').textContent =
    tier === 'none' ? 'CHOISIR UN GRADE' : 'TON GRADE';

  // ── Les deux cartes ──
  ['gold', 'diamond'].forEach(function (t) {
    const carte  = document.getElementById('vc-carte-' + t);
    const listel = document.getElementById('vc-listel-' + t);
    const btn    = document.getElementById('vc-btn-' + t);
    const ins    = document.getElementById('vc-insigne-' + t);
    if (!carte) return;

    const def = window.BADGE_DEFS && BADGE_DEFS[t + '_member'];
    if (def && !ins.firstChild) ins.innerHTML = def.full();

    const actuel = (tier === t);
    const manque = VC_PRIX[t] - solde;

    // Listel : le grade pris se ferme, l'autre invite à monter d'un cran.
    let texte = '';
    if (actuel)              texte = 'TON GRADE ACTUEL';
    else if (tier !== 'none') texte = t === 'diamond' ? 'MONTER D\'UN CRAN' : 'REDESCENDRE D\'UN CRAN';
    else if (t === 'diamond') texte = 'LE PALIER SUPÉRIEUR';
    listel.textContent = texte;
    carte.classList.toggle('a-listel', texte !== '');

    carte.classList.toggle('vc-actuel', actuel);
    carte.classList.toggle('vc-arme', vcArme === t && !actuel);

    btn.className = 'vc-cta';
    if (manque > 0) {
      btn.classList.add('vc-inerte');
      btn.textContent = 'IL TE MANQUE ' + vcFmt(manque) + ' VC';
    } else if (actuel) {
      btn.textContent = 'PROLONGER — ' + vcFmt(VC_PRIX[t]) + ' VC';
    } else if (vcArme === t) {
      btn.classList.add('vc-plein');
      btn.textContent = 'CONFIRMER — ' + vcFmt(VC_PRIX[t]) + ' VC';
    } else {
      btn.textContent = (tier === 'none' ? 'SOUSCRIRE ' : 'PASSER ') + VC_NOM[t];
    }
  });
}

// ── Rendu marché ──────────────────────────────────────────────────────────
function renderVCoinsMarket() {
  const list     = document.getElementById('vc-market-list');
  const mySection = document.getElementById('vc-my-offers-section');
  const myList   = document.getElementById('vc-my-offers-list');

  // Mes offres
  if (vcData.myOffers && vcData.myOffers.length > 0) {
    mySection.style.display = '';
    myList.innerHTML = vcData.myOffers.map(o => `
      <div class="vc-offer-row vc-offer-mine">
        <span class="vc-offer-amount">${Number(o.vcoin_amount).toLocaleString('fr-FR')} VC</span>
        <span class="vc-offer-arrow">→</span>
        <span class="vc-offer-price">${Number(o.price_ingame).toLocaleString('fr-FR')} $</span>
        <button class="vc-offer-cancel" onclick="vcCancelOffer(${o.id})">ANNULER</button>
      </div>
    `).join('');
  } else {
    mySection.style.display = 'none';
  }

  // Marché global
  if (!vcData.market || vcData.market.length === 0) {
    list.innerHTML = '<div class="vc-market-empty">Aucune offre disponible</div>';
    return;
  }
  list.innerHTML = vcData.market.map(o => {
    const rate = o.vcoin_amount > 0 ? Math.round(o.price_ingame / o.vcoin_amount) : 0;
    return `
      <div class="vc-offer-row">
        <span class="vc-offer-seller">${o.seller_name}</span>
        <span class="vc-offer-amount">${Number(o.vcoin_amount).toLocaleString('fr-FR')} VC</span>
        <span class="vc-offer-arrow">→</span>
        <span class="vc-offer-price">${Number(o.price_ingame).toLocaleString('fr-FR')} $</span>
        <span class="vc-offer-rate">${rate} $/VC</span>
        <button class="vc-offer-buy" onclick="vcBuyOffer(${o.id})">ACHETER</button>
      </div>
    `;
  }).join('');
}

// ── Actions ───────────────────────────────────────────────────────────────
window.vcSubscribe = function(tier) {
  fetch('https://pvp_inventory/vcSubscribe', {
    method: 'POST',
    body: JSON.stringify({ tier })
  }).then(r => r.json()).then(res => {
    if (res && res.ok === false) {
      toast(res.msg || 'Erreur', false);
    }
  }).catch(() => {});
};

window.vcCreateOffer = function() {
  const amt   = parseInt(document.getElementById('vc-offer-amount').value) || 0;
  const price = parseInt(document.getElementById('vc-offer-price').value)  || 0;
  if (amt < 10)   { toast('Minimum 10 VC', false); return; }
  if (price < 100){ toast('Prix minimum 100$', false); return; }
  fetch('https://pvp_inventory/vcCreateOffer', {
    method: 'POST',
    body: JSON.stringify({ vcoinAmount: amt, priceIngame: price })
  }).then(() => {
    document.getElementById('vc-offer-amount').value = '';
    document.getElementById('vc-offer-price').value  = '';
    setTimeout(loadVCoinsTab, 500);
  }).catch(() => {});
};

window.vcCancelOffer = function(id) {
  fetch('https://pvp_inventory/vcCancelOffer', {
    method: 'POST',
    body: JSON.stringify({ offerId: id })
  }).then(() => setTimeout(loadVCoinsTab, 500)).catch(() => {});
};

window.vcBuyOffer = function(id) {
  fetch('https://pvp_inventory/vcBuyOffer', {
    method: 'POST',
    body: JSON.stringify({ offerId: id })
  }).then(() => setTimeout(loadVCoinsTab, 500)).catch(() => {});
};

// Hook sur le clic de l'onglet VCOINS pour charger les données
document.addEventListener('DOMContentLoaded', function() {
  const vcTab = document.querySelector('[data-tab="vcoins"]');
  if (vcTab) {
    vcTab.addEventListener('click', function() {
      loadVCoinsTab();
    });
  }
});

