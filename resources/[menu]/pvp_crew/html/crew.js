/* ═══════════════════════════════════════════════
   PVP SQUAD — NUI JavaScript
   ═══════════════════════════════════════════════ */

let squadData     = null;
let squadInvite   = null;
let onlinePlayers = [];
let maxSquad      = 4;

function nuiFetch(ep, data) {
    return fetch('https://pvp_crew/' + ep, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {})
    }).then(r => r.json());
}

function showToast(msg, type) {
    const t = document.getElementById('sq-toast');
    t.textContent = msg;
    t.className = type || 'success';
    clearTimeout(t._timer);
    t._timer = setTimeout(() => { t.className = 'hidden'; }, 3000);
}

// ── Fermer ──────────────────────────────────────────────────────────────

document.getElementById('btn-close').addEventListener('click', () => nuiFetch('closeSquad'));
document.addEventListener('keydown', e => { if (e.key === 'Escape') nuiFetch('closeSquad'); });

// ══════════════════════════════════════════════════════════════════════════
//   Rendu
// ══════════════════════════════════════════════════════════════════════════

function renderSquad() {
    const noSq   = document.getElementById('no-squad');
    const inSq   = document.getElementById('in-squad');
    const invB   = document.getElementById('squad-invite-banner');
    const invP   = document.getElementById('squad-invite-panel');

    invP.classList.add('hidden');

    // Invitation reçue
    if (squadInvite) {
        invB.classList.remove('hidden');
        document.getElementById('squad-invite-from').textContent = squadInvite.fromName;
    } else {
        invB.classList.add('hidden');
    }

    if (!squadData || !squadData.members || squadData.members.length === 0) {
        noSq.classList.remove('hidden');
        inSq.classList.add('hidden');
        return;
    }

    noSq.classList.add('hidden');
    inSq.classList.remove('hidden');

    document.getElementById('squad-count').textContent = squadData.members.length + '/' + maxSquad;

    const list = document.getElementById('squad-members-list');
    list.innerHTML = squadData.members.map(m => {
        const badge = m.isLeader ? '<span class="sq-leader-badge">LEADER</span>' : '';
        const kick  = !m.isLeader ? `<button class="sq-btn-sm" onclick="doSquadKick(${m.id})">Exclure</button>` : '';
        return `<div class="sq-member-row">
            <div class="sq-member-info">
                <span class="sq-member-name">${m.name}</span>
                ${badge}
            </div>
            <div>${kick}</div>
        </div>`;
    }).join('');
}

function renderOnlinePlayers() {
    const list = document.getElementById('squad-online-list');
    if (!onlinePlayers || onlinePlayers.length === 0) {
        list.innerHTML = '<p class="sq-empty">Aucun joueur en ligne</p>';
        return;
    }
    list.innerHTML = onlinePlayers.map(p => `
        <div class="sq-player-row" onclick="doSquadInvite(${p.id})">
            <span class="sq-player-name">${p.name}</span>
            <span class="sq-player-id">ID: ${p.id}</span>
        </div>
    `).join('');
}

// ══════════════════════════════════════════════════════════════════════════
//   Actions
// ══════════════════════════════════════════════════════════════════════════

document.getElementById('btn-squad-invite').addEventListener('click', () => {
    document.getElementById('no-squad').classList.add('hidden');
    document.getElementById('squad-invite-panel').classList.remove('hidden');
    renderOnlinePlayers();
});

document.getElementById('btn-squad-invite-more').addEventListener('click', () => {
    document.getElementById('squad-invite-panel').classList.remove('hidden');
    renderOnlinePlayers();
});

document.getElementById('btn-squad-cancel-invite').addEventListener('click', () => {
    document.getElementById('squad-invite-panel').classList.add('hidden');
    if (!squadData || squadData.members.length === 0) {
        document.getElementById('no-squad').classList.remove('hidden');
    }
});

document.getElementById('btn-squad-accept').addEventListener('click', () => {
    nuiFetch('squadAccept').then(r => {
        showToast(r.message, r.ok ? 'success' : 'error');
        if (r.ok) squadInvite = null;
        renderSquad();
    });
});

document.getElementById('btn-squad-decline').addEventListener('click', () => {
    nuiFetch('squadDecline').then(r => {
        showToast(r.message, r.ok ? 'success' : 'error');
        squadInvite = null;
        renderSquad();
    });
});

document.getElementById('btn-squad-leave').addEventListener('click', () => {
    nuiFetch('squadLeave').then(r => {
        showToast(r.message, r.ok ? 'success' : 'error');
        if (r.ok) { squadData = null; renderSquad(); }
    });
});

window.doSquadInvite = function(targetId) {
    nuiFetch('squadInvite', { targetId }).then(r => {
        showToast(r.message, r.ok ? 'success' : 'error');
    });
};

window.doSquadKick = function(targetId) {
    nuiFetch('squadKick', { targetId }).then(r => {
        showToast(r.message, r.ok ? 'success' : 'error');
    });
};

// ══════════════════════════════════════════════════════════════════════════
//   NUI Messages
// ══════════════════════════════════════════════════════════════════════════

window.addEventListener('message', event => {
    const d = event.data;

    if (d.action === 'openSquad') {
        document.getElementById('squad-overlay').classList.remove('hidden');
        squadData     = d.squad;
        squadInvite   = d.squadInvite;
        onlinePlayers = d.players || [];
        maxSquad      = d.maxSquad || 4;
        renderSquad();
    }

    if (d.action === 'closeSquad') {
        document.getElementById('squad-overlay').classList.add('hidden');
    }

    if (d.action === 'updateSquad') {
        squadData = d.squad;
        renderSquad();
    }

    if (d.action === 'squadInviteReceived') {
        squadInvite = d.squadInvite;
        renderSquad();
    }
});
