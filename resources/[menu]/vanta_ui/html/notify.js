// =============================================
//   VANTA UI — Notifications génériques (NUI)
// =============================================
// Pile de toasts partagée par toutes les resources VANTA.
// Aucune interaction souris : ce NUI ne prend jamais le focus.

const STACK      = document.getElementById('notify-stack');
const MAX_VISIBLE = 5;        // au-delà, la plus ancienne est retirée
const KINDS       = ['success', 'error', 'warning', 'info'];

// Échappement : les messages peuvent contenir des pseudos joueurs.
// Jamais d'innerHTML avec du contenu non maîtrisé.
function el(tag, cls, text) {
  const n = document.createElement(tag);
  if (cls)  n.className = cls;
  if (text) n.textContent = text;
  return n;
}

function normalizeKind(kind) {
  // Compat : true → success, false → error (ancien format booléen).
  if (kind === true)  return 'success';
  if (kind === false) return 'error';
  return KINDS.includes(kind) ? kind : 'info';
}

function remove(node) {
  if (!node || node.dataset.leaving === '1') return;
  node.dataset.leaving = '1';
  node.classList.add('leaving');
  setTimeout(() => node.remove(), 200);
}

function push(msg, kind, duration, title) {
  if (typeof msg !== 'string' || msg === '') return;

  const node = el('div', 'v-notif ' + normalizeKind(kind));
  node.appendChild(el('span', 'dot'));

  const body = el('span', 'msg');
  if (typeof title === 'string' && title !== '') {
    body.appendChild(el('span', 'title', title));
  }
  body.appendChild(document.createTextNode(msg));
  node.appendChild(body);

  STACK.appendChild(node);

  while (STACK.children.length > MAX_VISIBLE) {
    remove(STACK.firstElementChild);
  }

  const ms = Math.max(1000, Math.min(15000, Number(duration) || 4000));
  setTimeout(() => remove(node), ms);
}

window.addEventListener('message', (e) => {
  const d = e.data || {};
  if (d.type === 'vanta:notify') {
    push(d.msg, d.kind, d.duration, d.title);
  } else if (d.type === 'vanta:notifyClear') {
    Array.from(STACK.children).forEach(remove);
  }
});
