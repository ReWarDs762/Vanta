// =============================================
//   PVP ADMIN — Panel NUI v2
//   Toasts, Search, Modals, Logs, Auto-refresh
// =============================================

let panelData = null;
let allPlayers = [];
let autoRefreshTimer = null;
let pendingConfirmAction = null;
let pendingKickId = null;
let pendingBanId = null;

// ═══ Messages depuis le client Lua ══════════════════════════════════════════
window.addEventListener('message', e => {
  const { type, data, msg, success, state } = e.data;

  if (type === 'open') {
    panelData = data;
    allPlayers = data.players || [];
    document.getElementById('panel').style.display = 'flex';
    document.getElementById('role-badge').textContent = (data.role || 'admin').toUpperCase();
    renderPlayers(allPlayers);
    renderRedzones(data.redzones || []);
    renderLogs(data.logs || []);
    updateTogglesFromState(data.state || {});
    updateHeaderCount(allPlayers.length);
    startAutoRefresh(data.autoRefresh || 10000);

  } else if (type === 'close') {
    document.getElementById('panel').style.display = 'none';
    stopAutoRefresh();

  } else if (type === 'toast') {
    showToast(msg, success);

  } else if (type === 'updateState') {
    if (state) updateTogglesFromState(state);
  }
});

// Fermer avec Echap
document.addEventListener('keydown', e => {
  if (e.key === 'Escape') {
    if (document.getElementById('storage-overlay').style.display !== 'none') { closeStorageModal(); return; }
    if (document.getElementById('detail-overlay').style.display !== 'none') { closeDetailModal(); return; }
    if (document.getElementById('ban-overlay').style.display !== 'none') { closeBanModal(); return; }
    if (document.getElementById('kick-overlay').style.display !== 'none') { closeKickModal(); return; }
    if (document.getElementById('modal-overlay').style.display !== 'none') { closeModal(); return; }
    closePanel();
  }
});

function closePanel() {
  document.getElementById('panel').style.display = 'none';
  stopAutoRefresh();
  fetch('https://pvp_admin/close', { method: 'POST', body: '{}' });
}

// ═══ TOAST SYSTEM ═══════════════════════════════════════════════════════════
function showToast(msg, success) {
  const container = document.getElementById('toast-container');
  const el = document.createElement('div');
  el.className = 'toast ' + (success ? 'success' : 'error');
  el.textContent = msg;
  container.appendChild(el);
  setTimeout(() => { if (el.parentNode) el.remove(); }, 3200);
}

// ═══ AUTO REFRESH ═══════════════════════════════════════════════════════════
function startAutoRefresh(interval) {
  stopAutoRefresh();
  autoRefreshTimer = setInterval(() => {
    if (document.getElementById('panel').style.display === 'none') return;
    silentRefresh();
  }, interval);
}

function stopAutoRefresh() {
  if (autoRefreshTimer) { clearInterval(autoRefreshTimer); autoRefreshTimer = null; }
}

function silentRefresh() {
  fetch('https://pvp_admin/refreshPlayers', {
    method: 'POST', body: '{}'
  }).then(r => r.json()).then(data => {
    if (data && data.players) {
      panelData = data;
      allPlayers = data.players;
      renderPlayers(allPlayers);
      renderRedzones(data.redzones || []);
      if (data.logs) renderLogs(data.logs);
      updateHeaderCount(allPlayers.length);
    }
  }).catch(() => {});
}

// ═══ Tabs ═══════════════════════════════════════════════════════════════════
function switchTab(name) {
  document.querySelectorAll('.tab').forEach(t =>
    t.classList.toggle('active', t.dataset.tab === name)
  );
  document.querySelectorAll('.tab-content').forEach(c =>
    c.classList.toggle('active', c.id === 'tab-' + name)
  );
}

// ═══ Player List ════════════════════════════════════════════════════════════
function renderPlayers(players) {
  const list = document.getElementById('player-list');
  const count = document.getElementById('player-count');
  count.textContent = players.length;

  if (players.length === 0) {
    list.innerHTML = '<div class="empty">Aucun joueur en ligne</div>';
    return;
  }

  list.innerHTML = players.map(p => {
    const isAdm = p.group === 'admin' || p.group === 'superadmin';
    const isMod = p.group === 'mod';
    const groupClass = isAdm ? 'admin' : (isMod ? 'mod' : '');
    const hpPct = Math.max(0, Math.min(100, ((p.health || 200) - 100) / 100 * 100));
    return `<div class="player-row" data-name="${esc(p.name).toLowerCase()}" data-id="${p.id}">
      <span class="p-id">#${p.id}</span>
      <span class="p-name" onclick="showPlayerDetail(${p.id})">${esc(p.name)}</span>
      <span class="p-group ${groupClass}">${p.group}</span>
      <div class="p-hp"><div class="p-hp-fill" style="width:${hpPct}%"></div></div>
      <span class="p-ping">${p.ping}ms</span>
      <div class="p-actions">
        <button class="p-btn" onclick="doAction('goto',{id:${p.id}})">TP</button>
        <button class="p-btn" onclick="doAction('bring',{id:${p.id}})">BRING</button>
        <button class="p-btn" onclick="doAction('heal',{id:${p.id}})">HEAL</button>
        <button class="p-btn" onclick="doAction('spectate',{id:${p.id}})">SPEC</button>
        <button class="p-btn" onclick="doAction('freeze',{id:${p.id}})">FREEZE</button>
        <button class="p-btn danger" onclick="confirmAction('slay','Tuer ${esc(p.name)} ?',{id:${p.id}})">SLAY</button>
        <button class="p-btn warn" onclick="openKickModal(${p.id},'${esc(p.name)}')">KICK</button>
        <button class="p-btn danger" onclick="openBanModal(${p.id},'${esc(p.name)}')">BAN</button>
      </div>
    </div>`;
  }).join('');

  // Re-apply search filter
  filterPlayers();
}

function updateHeaderCount(count) {
  document.getElementById('header-count').textContent = count + ' en ligne';
}

function filterPlayers() {
  const q = (document.getElementById('player-search').value || '').toLowerCase().trim();
  document.querySelectorAll('.player-row').forEach(row => {
    if (!q) { row.classList.remove('hidden'); return; }
    const name = row.dataset.name || '';
    const id = row.dataset.id || '';
    row.classList.toggle('hidden', !name.includes(q) && !id.includes(q));
  });
}

function refreshPlayers() {
  silentRefresh();
  showToast('Liste actualisee.', true);
}

// ═══ Redzones ═══════════════════════════════════════════════════════════════
function renderRedzones(zones) {
  const el = document.getElementById('rz-list');
  if (!zones || zones.length === 0) {
    el.innerHTML = '<div class="rz-item">Aucune redzone active</div>';
    return;
  }
  el.innerHTML = zones.map((z, i) => {
    const x = z.coords ? Math.round(z.coords.x || 0) : Math.round(z.x || 0);
    const y = z.coords ? Math.round(z.coords.y || 0) : Math.round(z.y || 0);
    return `<div class="rz-item"><strong>#${i + 1}</strong> ${esc(z.label || '?')} — (${x}, ${y})</div>`;
  }).join('');
}

// ═══ Logs ════════════════════════════════════════════════════════════════════
function renderLogs(logs) {
  const el = document.getElementById('log-list');
  if (!logs || logs.length === 0) {
    el.innerHTML = '<div class="empty">Aucun log.</div>';
    return;
  }

  // Afficher les plus récents en premier
  const sorted = [...logs].reverse();
  el.innerHTML = sorted.map(l => {
    const time = formatLogTime(l.created_at);
    const target = l.target_name ? (l.target_name + (l.target_id ? ' #' + l.target_id : '')) : '';
    const detail = [target, l.details || ''].filter(Boolean).join(' — ');
    return `<div class="log-row">
      <span class="log-time">${time}</span>
      <span class="log-admin">${esc(l.admin_name || '?')}</span>
      <span class="log-action a-${l.action || 'unknown'}">${l.action || '?'}</span>
      <span class="log-detail">${esc(detail)}</span>
    </div>`;
  }).join('');
}

function formatLogTime(dt) {
  if (!dt) return '?';
  // dt peut etre "2024-01-15 14:30:22" ou juste un timestamp
  try {
    const d = new Date(dt);
    if (isNaN(d.getTime())) return dt.substring(11, 16) || '?';
    return d.getHours().toString().padStart(2, '0') + ':' + d.getMinutes().toString().padStart(2, '0');
  } catch(e) {
    return '?';
  }
}

// ═══ Actions ════════════════════════════════════════════════════════════════
function doAction(action, payload) {
  fetch('https://pvp_admin/action', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ action, payload: payload || {} })
  });
}

// ═══ CONFIRM MODAL (SLAY, CLEARINV etc.) ════════════════════════════════════
function confirmAction(action, message, payload) {
  pendingConfirmAction = { action, payload };
  document.getElementById('modal-body').textContent = message;
  document.getElementById('modal-overlay').style.display = 'flex';
}

function modalConfirmAction() {
  if (pendingConfirmAction) {
    doAction(pendingConfirmAction.action, pendingConfirmAction.payload);
    pendingConfirmAction = null;
  }
  closeModal();
}

function closeModal() {
  document.getElementById('modal-overlay').style.display = 'none';
  pendingConfirmAction = null;
}

// ═══ KICK MODAL ═════════════════════════════════════════════════════════════
function openKickModal(id, name) {
  pendingKickId = id;
  document.getElementById('kick-target').textContent = name + ' (#' + id + ')';
  document.getElementById('kick-reason').value = '';
  document.getElementById('kick-overlay').style.display = 'flex';
  document.getElementById('kick-reason').focus();
}

function closeKickModal() {
  document.getElementById('kick-overlay').style.display = 'none';
  pendingKickId = null;
}

function confirmKick() {
  if (pendingKickId !== null) {
    const reason = document.getElementById('kick-reason').value.trim() || 'Exclu par un administrateur.';
    doAction('kick', { id: pendingKickId, reason });
    pendingKickId = null;
  }
  closeKickModal();
}

// ═══ BAN MODAL ══════════════════════════════════════════════════════════════
function openBanModal(id, name) {
  pendingBanId = id;
  document.getElementById('ban-target').textContent = name + ' (#' + id + ')';
  document.getElementById('ban-reason').value = '';
  document.getElementById('ban-duration').value = '0';
  document.getElementById('ban-overlay').style.display = 'flex';
  document.getElementById('ban-reason').focus();
}

function closeBanModal() {
  document.getElementById('ban-overlay').style.display = 'none';
  pendingBanId = null;
}

function confirmBan() {
  if (pendingBanId !== null) {
    const reason = document.getElementById('ban-reason').value.trim() || 'Banni par un administrateur.';
    const duration = parseInt(document.getElementById('ban-duration').value) || 0;
    doAction('ban', { id: pendingBanId, reason, duration });
    pendingBanId = null;
  }
  closeBanModal();
}

function unbanPlayer() {
  const ident = document.getElementById('unban-ident').value.trim();
  if (!ident) return;
  doAction('unban', { identifier: ident });
  document.getElementById('unban-ident').value = '';
}

// ═══ PLAYER DETAIL MODAL ═══════════════════════════════════════════════════
function showPlayerDetail(id) {
  document.getElementById('detail-body').innerHTML = '<div class="empty">Chargement...</div>';
  document.getElementById('detail-overlay').style.display = 'flex';

  fetch('https://pvp_admin/getPlayerDetail', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ id })
  }).then(r => r.json()).then(d => {
    if (!d || !d.id) {
      document.getElementById('detail-body').innerHTML = '<div class="empty">Joueur introuvable.</div>';
      return;
    }
    const kd = d.deaths > 0 ? (d.kills / d.deaths).toFixed(2) : d.kills.toFixed(2);
    let html = `
      <div class="detail-grid">
        <div class="detail-item"><div class="label">NOM</div><div class="value">${esc(d.name)}</div></div>
        <div class="detail-item"><div class="label">ID / GROUPE</div><div class="value">#${d.id} — ${d.group}</div></div>
        <div class="detail-item"><div class="label">KILLS / MORTS</div><div class="value">${d.kills} / ${d.deaths} (K/D: ${kd})</div></div>
        <div class="detail-item"><div class="label">ZOMBIES</div><div class="value">${d.zombies}</div></div>
        <div class="detail-item"><div class="label">STREAK RECORD</div><div class="value">${d.streak}</div></div>
        <div class="detail-item"><div class="label">XP / PRESTIGE</div><div class="value">${d.xp} XP — P${d.prestige}</div></div>
        <div class="detail-item"><div class="label">BANQUE</div><div class="value">$${d.bank}</div></div>
        <div class="detail-item"><div class="label">HP / ARMURE</div><div class="value">${Math.max(0, (d.health||200)-100)} / ${d.armor||0}</div></div>
      </div>
    `;

    if (d.inventory && d.inventory.length > 0) {
      html += '<div class="detail-section">INVENTAIRE</div><div class="detail-inv">';
      d.inventory.forEach(item => {
        html += `<div class="detail-inv-item">${esc(item.label || item.name)} <span>x${item.count}</span></div>`;
      });
      html += '</div>';
    } else {
      html += '<div class="detail-section">INVENTAIRE</div><div class="empty">Inventaire vide.</div>';
    }

    html += `<div class="detail-section">IDENTIFIANTS</div><div class="detail-ident">${esc(d.identifiers || d.identifier || '?')}</div>`;

    // Boutons pour ouvrir les stockages
    html += `<div class="detail-section">GESTION STOCKAGE</div>`;
    html += `<div class="detail-storage-btns">
      <button onclick="openStorageModal(${d.id}, 'inventory')">INVENTAIRE (SAC)</button>
      <button onclick="openStorageModal(${d.id}, 'stash')">COFFRE PROTEGE</button>
      <button onclick="openStorageModal(${d.id}, 'outpost')">COFFRE AVANT-POSTE</button>
    </div>`;

    document.getElementById('detail-body').innerHTML = html;
  }).catch(() => {
    document.getElementById('detail-body').innerHTML = '<div class="empty">Erreur de chargement.</div>';
  });
}

function closeDetailModal() {
  document.getElementById('detail-overlay').style.display = 'none';
}

// ═══ STORAGE MODAL ══════════════════════════════════════════════════════════
let currentStorage = { targetId: null, storageType: null };

function openStorageModal(targetId, storageType) {
  currentStorage = { targetId, storageType };
  document.getElementById('storage-title').textContent = 'Chargement...';
  document.getElementById('storage-body').innerHTML = '<div class="empty">Chargement...</div>';
  document.getElementById('storage-add-item').value = '';
  document.getElementById('storage-add-qty').value = '1';
  document.getElementById('storage-overlay').style.display = 'flex';

  loadStorage(targetId, storageType);
}

function loadStorage(targetId, storageType) {
  fetch('https://pvp_admin/getPlayerStorage', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ id: targetId, storageType })
  }).then(r => r.json()).then(data => {
    if (!data || !data.storageType) {
      document.getElementById('storage-body').innerHTML = '<div class="empty">Erreur de chargement.</div>';
      return;
    }

    document.getElementById('storage-title').textContent =
      data.storageLabel + ' — ' + esc(data.targetName) + ' #' + data.targetId;

    renderStorageItems(data.items || []);
  }).catch(() => {
    document.getElementById('storage-body').innerHTML = '<div class="empty">Erreur de chargement.</div>';
  });
}

function renderStorageItems(items) {
  const el = document.getElementById('storage-body');
  if (!items || items.length === 0) {
    el.innerHTML = '<div class="storage-empty">Aucun item.</div>';
    return;
  }

  el.innerHTML = items.map(item => {
    const nameEsc = esc(item.name);
    const labelEsc = esc(item.label || item.name);
    return `<div class="storage-item-row">
      <div class="storage-item-name">
        <span class="storage-item-label">${labelEsc}</span>
        <span class="storage-item-code">(${nameEsc})</span>
      </div>
      <span class="storage-item-count">x${item.count}</span>
      <div class="storage-item-actions">
        <button onclick="removeFromStorage('${nameEsc}', 1)">-1</button>
        <button onclick="removeFromStorage('${nameEsc}', ${item.count})" class="remove">TOUT</button>
      </div>
    </div>`;
  }).join('');
}

function removeFromStorage(itemName, qty) {
  if (!currentStorage.targetId) return;
  fetch('https://pvp_admin/removeFromStorage', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      targetId: currentStorage.targetId,
      storageType: currentStorage.storageType,
      itemName, qty
    })
  });
  // Refresh après un court délai (temps que le serveur traite)
  setTimeout(() => refreshCurrentStorage(), 400);
}

function addToCurrentStorage() {
  if (!currentStorage.targetId) return;
  const item = document.getElementById('storage-add-item').value.trim();
  const qty = parseInt(document.getElementById('storage-add-qty').value) || 1;
  if (!item) return;

  fetch('https://pvp_admin/addToStorage', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      targetId: currentStorage.targetId,
      storageType: currentStorage.storageType,
      itemName: item, qty
    })
  });
  document.getElementById('storage-add-item').value = '';
  document.getElementById('storage-add-qty').value = '1';
  setTimeout(() => refreshCurrentStorage(), 400);
}

function refreshCurrentStorage() {
  if (!currentStorage.targetId || !currentStorage.storageType) return;
  loadStorage(currentStorage.targetId, currentStorage.storageType);
}

function closeStorageModal() {
  document.getElementById('storage-overlay').style.display = 'none';
  currentStorage = { targetId: null, storageType: null };
}

// ═══ Tools tab ══════════════════════════════════════════════════════════════
function toggleNoclip() {
  doAction('noclip', {});
}

function toggleGod() {
  doAction('god', {});
}

function updateTogglesFromState(s) {
  const nc = document.getElementById('btn-noclip');
  nc.textContent = s.noclip ? 'ON' : 'OFF';
  nc.classList.toggle('on', s.noclip);
  const gd = document.getElementById('btn-god');
  gd.textContent = s.god ? 'ON' : 'OFF';
  gd.classList.toggle('on', s.god);
}

function spawnCar() {
  const model = document.getElementById('car-model').value.trim();
  if (!model) return;
  doAction('spawncar', { model });
}

function deleteCar() {
  doAction('deletecar', {});
}

function tpWaypoint() {
  doAction('tpwp', {});
}

function sendAnnounce() {
  const input = document.getElementById('announce-input');
  const msg = input.value.trim();
  if (!msg) return;
  doAction('announce', { msg });
  input.value = '';
}

function giveItem() {
  const id = document.getElementById('give-id').value;
  const item = document.getElementById('give-item').value.trim();
  const qty = document.getElementById('give-qty').value || 1;
  if (!id || !item) return;
  doAction('give', { id: +id, item, qty: +qty });
}

function giveMoney() {
  const id = document.getElementById('givem-id').value;
  const amount = document.getElementById('givem-amount').value;
  if (!id || !amount) return;
  doAction('givemoney', { id: +id, amount: +amount });
}

// ═══ Utilitaires ════════════════════════════════════════════════════════════
function esc(s) {
  const d = document.createElement('div');
  d.textContent = s || '';
  return d.innerHTML;
}
