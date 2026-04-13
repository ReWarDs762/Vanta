// ══════════════════════════════════════════════
//  KILLFEED — NUI
// ══════════════════════════════════════════════

const MAX_FEED_ENTRIES = 8;
const ENTRY_LIFETIME  = 10000;  // ms avant disparition

// ── Ajouter un kill dans le feed ──────────────────────────────
function addKillEntry(data) {
  const feed = document.getElementById('killfeed');
  const entry = document.createElement('div');
  entry.className = 'kill-entry';

  if (data.iKilled)   entry.classList.add('i-killed');
  else if (data.iDied) entry.classList.add('i-died');
  else if (data.inRedzone) entry.classList.add('in-redzone');
  else if (data.isMe)  entry.classList.add('is-me');

  let inner = '';

  if (data.killer) {
    inner += `<span class="kf-name killer">${esc(data.killer)}</span>`;
    inner += `<span class="kf-arrow">&#8594;</span>`;
  }

  inner += `<span class="kf-name victim">${esc(data.victim)}</span>`;

  if (data.weapon) {
    inner += `<span class="kf-weapon">${esc(data.weapon)}</span>`;
  }

  if (data.inRedzone) {
    inner += `<span class="kf-rz">RZ</span>`;
  }

  entry.innerHTML = inner;
  feed.insertBefore(entry, feed.firstChild);

  // Limiter le nombre d'entrées
  const entries = feed.querySelectorAll('.kill-entry');
  if (entries.length > MAX_FEED_ENTRIES) {
    const last = entries[entries.length - 1];
    last.remove();
  }

  // Disparaître après ENTRY_LIFETIME
  setTimeout(() => {
    entry.classList.add('fading');
    setTimeout(() => entry.remove(), 500);
  }, ENTRY_LIFETIME);
}

// ── Mettre à jour les leaders ─────────────────────────────────
function updateLeaders(killLeader, crewLeader) {
  const leadersEl = document.getElementById('leaders');
  const klBox = document.getElementById('kill-leader-box');
  const clBox = document.getElementById('crew-leader-box');

  let hasAny = false;

  if (killLeader && killLeader.kills > 0) {
    hasAny = true;
    klBox.classList.remove('hidden');
    let name = killLeader.name || 'Joueur';
    if (killLeader.crewTag) name = '[' + killLeader.crewTag + '] ' + name;
    document.getElementById('kl-name').textContent = name;
    document.getElementById('kl-kills').textContent = killLeader.kills + ' kill' + (killLeader.kills > 1 ? 's' : '');
  } else {
    klBox.classList.add('hidden');
  }

  if (crewLeader && crewLeader.kills > 0) {
    hasAny = true;
    clBox.classList.remove('hidden');
    document.getElementById('cl-name').textContent = '[' + (crewLeader.tag || '?') + '] ' + (crewLeader.name || 'Crew');
    document.getElementById('cl-kills').textContent = crewLeader.kills + ' kill' + (crewLeader.kills > 1 ? 's' : '');
  } else {
    clBox.classList.add('hidden');
  }

  if (hasAny) {
    leadersEl.classList.remove('hidden');
  } else {
    leadersEl.classList.add('hidden');
  }
}

// ── Escape HTML ───────────────────────────────────────────────
function esc(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// ── NUI Message Handler ───────────────────────────────────────
window.addEventListener('message', (e) => {
  const d = e.data;
  if (!d || !d.action) return;

  if (d.action === 'addKill') {
    addKillEntry(d);
  }

  if (d.action === 'updateLeaders') {
    updateLeaders(d.killLeader, d.crewLeader);
  }
});
