/* ═══════════════════════════════════════════════════════════════════════════
   VANTA XP — Script NUI
   Communication FiveM ↔ NUI
   ═══════════════════════════════════════════════════════════════════════════ */

// ── Badges prestige (HTML pur, reproduit depuis config) ──────────────────
const PRESTIGE_BADGES = {
    0: { symbol: 'RECRUIT',   cssClass: 'p0', label: 'RECRUIT' },
    1: { symbol: '◆ I',       cssClass: 'p1', label: 'PRESTIGE I' },
    2: { symbol: '◆◆ II',     cssClass: 'p2', label: 'PRESTIGE II' },
    3: { symbol: '✦✦✦ III',   cssClass: 'p3', label: 'PRESTIGE III' },
    4: { symbol: '⬡ IV',      cssClass: 'p4', label: 'PRESTIGE IV' },
    5: { symbol: '⬟ VANTA',   cssClass: 'p5', label: 'VANTA' },
};

const MINI_SYMBOLS = {
    1: '◆',
    2: '◆◆',
    3: '✦✦✦',
    4: '⬡',
    5: '⬟',
};

// ── Éléments DOM ─────────────────────────────────────────────────────────
const $ = (id) => document.getElementById(id);

const overlay        = $('overlay');
const xpPanel        = $('xpPanel');
const prestigeBadge  = $('prestigeBadge');
const levelDisplay   = $('levelDisplay');
const totalXP        = $('totalXP');
const xpBar          = $('xpBar');
const xpPercent      = $('xpPercent');
const xpCurrent      = $('xpCurrent');
const xpNext         = $('xpNext');
const prestigeBtn    = $('prestigeBtn');
const bagCapacity    = $('bagCapacity');
const contCapacity   = $('contCapacity');
const prestigesRow   = $('prestigesRow');
const toastContainer = $('toastContainer');
const prestigeNotif  = $('prestigeNotif');

// ── État ─────────────────────────────────────────────────────────────────
let isOpen = false;

// ══════════════════════════════════════════════════════════════════════════
//   FONCTIONS D'AFFICHAGE
// ══════════════════════════════════════════════════════════════════════════

function updateProfile(profile) {
    if (!profile) return;

    // Badge prestige
    const pData = PRESTIGE_BADGES[profile.prestige_level] || PRESTIGE_BADGES[0];
    prestigeBadge.innerHTML = `<span class="badge-prestige ${pData.cssClass}">${pData.symbol}</span>`;

    // Niveau
    levelDisplay.textContent = `LVL ${profile.level}`;

    // XP total
    totalXP.textContent = `${formatNumber(profile.total_xp_earned)} XP total`;

    // Barre XP
    const percent = profile.level >= (profile.max_level || 100) ? 100 : (profile.xp_percent || 0);
    xpBar.style.width = `${percent}%`;
    xpPercent.textContent = `${percent}%`;

    // Labels XP
    if (profile.level >= (profile.max_level || 100)) {
        xpCurrent.textContent = 'MAX';
        xpNext.textContent = '';
    } else {
        xpCurrent.textContent = formatNumber(profile.xp_in_level);
        xpNext.textContent = `/ ${formatNumber(profile.xp_to_next)} XP`;
    }

    // Bouton prestige
    if (profile.can_prestige) {
        prestigeBtn.classList.remove('hidden');
    } else {
        prestigeBtn.classList.add('hidden');
    }

    // Capacités
    bagCapacity.textContent = `${profile.bag_capacity}kg`;
    contCapacity.textContent = `${profile.cont_capacity}kg`;

    // Ligne prestiges
    renderPrestigeRow(profile.prestige_level, profile.max_prestige || 5);
}

function renderPrestigeRow(currentPrestige, maxPrestige) {
    let html = '';
    for (let i = 1; i <= maxPrestige; i++) {
        const isUnlocked = i <= currentPrestige;
        const isCurrent  = i === currentPrestige;
        const symbol     = MINI_SYMBOLS[i] || i;
        const cssClass   = PRESTIGE_BADGES[i]?.cssClass || 'p0';

        let slotClass = 'prestige-slot';
        if (!isUnlocked) slotClass += ' locked';
        if (isCurrent)   slotClass += ' active';

        if (isUnlocked) {
            html += `<div class="${slotClass}">
                <span class="mini-badge ${cssClass}">${symbol}</span>
            </div>`;
        } else {
            html += `<div class="${slotClass}">
                <span class="mini-badge" style="color:#444">${symbol}</span>
            </div>`;
        }
    }
    prestigesRow.innerHTML = html;
}

function formatNumber(n) {
    if (n === undefined || n === null) return '0';
    return n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
}

// ══════════════════════════════════════════════════════════════════════════
//   OUVERTURE / FERMETURE
// ══════════════════════════════════════════════════════════════════════════

function openPanel(profile) {
    isOpen = true;
    overlay.classList.remove('hidden');
    xpPanel.classList.remove('hidden');
    if (profile) updateProfile(profile);
}

function closePanel() {
    if (!isOpen) return;
    isOpen = false;
    overlay.classList.add('hidden');
    xpPanel.classList.add('hidden');
    // Informer le client Lua
    fetch('https://vanta_xp/close', { method: 'POST', body: JSON.stringify({}) });
}

// ── Echap pour fermer ────────────────────────────────────────────────────
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && isOpen) {
        closePanel();
    }
});

// ── Bouton prestige ──────────────────────────────────────────────────────
function doPrestige() {
    fetch('https://vanta_xp/prestige', { method: 'POST', body: JSON.stringify({}) });
}

// ══════════════════════════════════════════════════════════════════════════
//   NOTIFICATIONS / TOASTS
// ══════════════════════════════════════════════════════════════════════════

function showLevelUpToast(level) {
    const toast = document.createElement('div');
    toast.className = 'toast';
    toast.innerHTML = `<span class="toast-icon">▲</span> LEVEL UP → <strong>${level}</strong>`;
    toastContainer.appendChild(toast);
    setTimeout(() => { if (toast.parentNode) toast.remove(); }, 3200);
}

function showXPToast(amount, source) {
    const sourceLabels = {
        player_kill: 'PVP KILL',
        zombie_kill: 'ZOMBIE',
        admin_givexp: 'ADMIN',
    };
    const label = sourceLabels[source] || source || '';
    const toast = document.createElement('div');
    toast.className = 'toast-xp';
    toast.textContent = `+${amount} XP ${label}`;
    toastContainer.appendChild(toast);
    setTimeout(() => { if (toast.parentNode) toast.remove(); }, 2200);
}

function showPrestigeNotif(prestige) {
    const pData = PRESTIGE_BADGES[prestige] || PRESTIGE_BADGES[0];
    prestigeNotif.innerHTML = `
        <div class="notif-title">✦ PRESTIGE ATTEINT</div>
        <div class="notif-level">${pData.label}</div>
        <div class="notif-badge">
            <span class="badge-prestige ${pData.cssClass}">${pData.symbol}</span>
        </div>
    `;
    prestigeNotif.classList.remove('hidden');
    setTimeout(() => { prestigeNotif.classList.add('hidden'); }, 5200);
}

// ══════════════════════════════════════════════════════════════════════════
//   LISTENER MESSAGE NUI (FiveM → NUI)
// ══════════════════════════════════════════════════════════════════════════

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || !data.action) return;

    switch (data.action) {
        case 'open':
            openPanel(data.profile);
            break;

        case 'close':
            isOpen = false;
            overlay.classList.add('hidden');
            xpPanel.classList.add('hidden');
            break;

        case 'updateProfile':
            updateProfile(data.profile);
            break;

        case 'xpAdded':
            showXPToast(data.amount, data.source);
            break;

        case 'levelUp':
            showLevelUpToast(data.level);
            break;

        case 'prestigeUp':
            showPrestigeNotif(data.prestige);
            break;
    }
});
