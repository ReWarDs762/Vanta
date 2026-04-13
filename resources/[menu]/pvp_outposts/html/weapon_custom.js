// ═══════════════════════════════════════════════════════════════
//   WEAPON CUSTOM PANEL — VANTA Design System
// ═══════════════════════════════════════════════════════════════

(function () {
'use strict';

// ── Icônes SVG inline (data URI) ──────────────────────────────
const ICONS = {
  flashlight: svgUri('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#c8cdd4" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="2" width="6" height="5" rx="1"/><path d="M9 7L6 20h12L15 7"/><circle cx="12" cy="15" r="2.2" fill="#c8cdd4" stroke="none"/><line x1="12" y1="10" x2="12" y2="12.5"/></svg>'),

  suppressor: svgUri('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#c8cdd4"><rect x="1" y="10.5" width="22" height="3" rx="1.5"/><rect x="4"  y="7.5" width="1.8" height="9" rx="0.9" opacity="0.35"/><rect x="7.5" y="7.5" width="1.8" height="9" rx="0.9" opacity="0.35"/><rect x="11" y="7.5" width="1.8" height="9" rx="0.9" opacity="0.35"/><rect x="14.5" y="7.5" width="1.8" height="9" rx="0.9" opacity="0.35"/><rect x="18" y="7.5" width="1.8" height="9" rx="0.9" opacity="0.35"/></svg>'),

  extmag: svgUri('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#c8cdd4"><rect x="8.5" y="2" width="7" height="12" rx="1"/><rect x="10" y="14" width="4" height="7.5" rx="1" opacity="0.42"/><line x1="11.5" y1="4.5" x2="11.5" y2="11.5" stroke="#0a0a0a" stroke-width="1" stroke-dasharray="1.5 2"/></svg>'),

  scope: svgUri('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#c8cdd4" stroke-width="1.5" stroke-linecap="round"><circle cx="12" cy="12" r="8.5"/><line x1="12" y1="3.5" x2="12" y2="7"/><line x1="12" y1="17" x2="12" y2="20.5"/><line x1="3.5" y1="12" x2="7"   y2="12"/><line x1="17"  y1="12" x2="20.5" y2="12"/><circle cx="12" cy="12" r="2" fill="#c8cdd4" stroke="none"/></svg>'),

  scope_adv: svgUri('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#c8cdd4" stroke-width="1.5" stroke-linecap="round"><circle cx="12" cy="12" r="9.5"/><circle cx="12" cy="12" r="5.5"/><line x1="12" y1="2.5" x2="12" y2="6.5"/><line x1="12" y1="17.5" x2="12" y2="21.5"/><line x1="2.5"  y1="12" x2="6.5"  y2="12"/><line x1="17.5" y1="12" x2="21.5" y2="12"/><circle cx="12" cy="12" r="1.6" fill="#c8cdd4" stroke="none"/></svg>'),

  grip: svgUri('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#c8cdd4"><rect x="10.5" y="1.5" width="3" height="21" rx="1.5"/><rect x="5.5" y="8.5"  width="5" height="2" rx="1" opacity="0.45"/><rect x="13.5" y="8.5"  width="5" height="2" rx="1" opacity="0.45"/><rect x="5.5" y="13.5" width="5" height="2" rx="1" opacity="0.28"/><rect x="13.5" y="13.5" width="5" height="2" rx="1" opacity="0.28"/></svg>'),

  default: svgUri('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#c8cdd4" stroke-width="1.5"><rect x="3" y="3" width="18" height="18" rx="2"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/></svg>'),
};

function svgUri(svg) {
  return 'data:image/svg+xml,' + encodeURIComponent(svg);
}

function getIcon(compName) {
  if (!compName) return ICONS.default;
  if (compName.includes('FLSH'))        return ICONS.flashlight;
  if (compName.includes('SUPP'))        return ICONS.suppressor;
  if (compName.includes('CLIP'))        return ICONS.extmag;
  if (compName.includes('SCOPE_MAX'))   return ICONS.scope_adv;
  if (compName.includes('SCOPE') || compName.includes('SIGHTS')) return ICONS.scope;
  if (compName.includes('AFGRIP'))      return ICONS.grip;
  return ICONS.default;
}

// ── Teintes GTA V ─────────────────────────────────────────────
const TINTS = [
  { index: 0, name: 'Normal',  color: '#363636' },
  { index: 1, name: 'Vert',    color: '#1e4d28' },
  { index: 2, name: 'Or',      color: '#5a4800' },
  { index: 3, name: 'Rose',    color: '#5a1a38' },
  { index: 4, name: 'Armée',   color: '#2a3e18' },
  { index: 5, name: 'LSPD',    color: '#10287a' },
  { index: 6, name: 'Orange',  color: '#5a2800' },
  { index: 7, name: 'Platine', color: '#505060' },
];

// ── État ──────────────────────────────────────────────────────
let state = {
  weaponName:  '',
  components:  [],
  currentTint: 0,
  hasTints:    false,
};

// ── Ouvrir le panel ───────────────────────────────────────────
function open(data) {
  state.weaponName  = data.weaponName  || '';
  state.components  = data.components  || [];
  state.currentTint = data.currentTint || 0;
  state.hasTints    = data.hasTints    || false;

  document.getElementById('wc-weapon-name').textContent =
    data.displayName || data.weaponName || '—';

  // Reset footer
  const btn = document.getElementById('wc-save-btn');
  btn.classList.remove('saved');
  btn.textContent = 'SAUVEGARDER';
  document.getElementById('wc-status').textContent = '';

  // Onglet Teinte visible seulement si supporté
  const tintTab = document.querySelector('[data-tab="tint"]');
  if (tintTab) tintTab.style.display = state.hasTints ? '' : 'none';

  renderComponents();
  renderTints();
  setTab('components');

  document.getElementById('wc-overlay').classList.add('visible');
}

function close() {
  document.getElementById('wc-overlay').classList.remove('visible');
  fetch('https://pvp_outposts/wc_close', {
    method: 'POST',
    body: JSON.stringify({}),
  });
}

// ── Onglets ───────────────────────────────────────────────────
function setTab(tab) {
  document.querySelectorAll('.wc-tab').forEach(t =>
    t.classList.toggle('active', t.dataset.tab === tab)
  );
  document.querySelectorAll('.wc-pane').forEach(p =>
    p.classList.toggle('active', p.id === 'wc-pane-' + tab)
  );
}

// ── Composants ────────────────────────────────────────────────
function renderComponents() {
  const grid = document.getElementById('wc-comp-grid');
  grid.innerHTML = '';

  if (!state.components.length) {
    grid.innerHTML =
      '<div class="wc-no-comp">Aucun composant<br>disponible pour cette arme</div>';
    return;
  }

  state.components.forEach(comp => {
    const card = document.createElement('div');
    card.className = 'wc-comp-card' + (comp.active ? ' active' : '');
    card.dataset.comp = comp.name;

    card.innerHTML = `
      <img class="wc-comp-icon" src="${getIcon(comp.name)}" alt="${comp.label}">
      <span class="wc-comp-label">${comp.label}</span>
      <span class="wc-comp-badge ${comp.active ? 'wc-badge-on' : 'wc-badge-off'}">
        ${comp.active ? 'ACTIF' : 'OFF'}
      </span>`;

    card.addEventListener('click', () => toggleComp(comp.name));
    grid.appendChild(card);
  });
}

function toggleComp(compName) {
  const comp = state.components.find(c => c.name === compName);
  if (!comp) return;
  comp.active = !comp.active;

  const card = document.querySelector(`.wc-comp-card[data-comp="${compName}"]`);
  if (card) {
    card.classList.toggle('active', comp.active);
    const badge = card.querySelector('.wc-comp-badge');
    badge.className = 'wc-comp-badge ' + (comp.active ? 'wc-badge-on' : 'wc-badge-off');
    badge.textContent = comp.active ? 'ACTIF' : 'OFF';
  }

  fetch('https://pvp_outposts/wc_toggle_comp', {
    method: 'POST',
    body: JSON.stringify({ component: compName, active: comp.active }),
  });
}

// ── Teintes ───────────────────────────────────────────────────
function renderTints() {
  const grid = document.getElementById('wc-tint-grid');
  grid.innerHTML = '';

  TINTS.forEach(t => {
    const card = document.createElement('div');
    card.className = 'wc-tint-card' + (t.index === state.currentTint ? ' active' : '');
    card.dataset.tint = t.index;

    card.innerHTML = `
      <div class="wc-tint-color" style="background:${t.color}"></div>
      <span class="wc-tint-label">${t.name}</span>`;

    card.addEventListener('click', () => setTint(t.index));
    grid.appendChild(card);
  });
}

function setTint(index) {
  state.currentTint = index;
  document.querySelectorAll('.wc-tint-card').forEach(c =>
    c.classList.toggle('active', parseInt(c.dataset.tint) === index)
  );
  fetch('https://pvp_outposts/wc_set_tint', {
    method: 'POST',
    body: JSON.stringify({ tint: index }),
  });
}

// ── Sauvegarder ───────────────────────────────────────────────
function save() {
  fetch('https://pvp_outposts/wc_save', {
    method: 'POST',
    body: JSON.stringify({}),
  });

  const btn    = document.getElementById('wc-save-btn');
  const status = document.getElementById('wc-status');
  btn.classList.add('saved');
  btn.textContent    = 'SAUVEGARDÉ ✓';
  status.textContent = 'Modifications enregistrées';

  setTimeout(() => {
    btn.classList.remove('saved');
    btn.textContent    = 'SAUVEGARDER';
    status.textContent = '';
  }, 2500);
}

// ── Message handler depuis Lua ─────────────────────────────────
window.addEventListener('message', e => {
  const d = e.data;
  if (!d || !d.action) return;
  if (d.action === 'openWeaponCustom')  open(d);
  if (d.action === 'closeWeaponCustom')
    document.getElementById('wc-overlay').classList.remove('visible');
});

// ── Echap pour fermer ─────────────────────────────────────────
document.addEventListener('keydown', e => {
  if (e.key === 'Escape') {
    const ov = document.getElementById('wc-overlay');
    if (ov && ov.classList.contains('visible')) close();
  }
});

// ── Expose pour onclick HTML ──────────────────────────────────
window.WC = { close, setTab, save };

})();
