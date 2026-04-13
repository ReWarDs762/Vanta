// =============================================
//   PVP OUTPOSTS — shop.js
//   NUI Shop : acheter / vendre
// =============================================

'use strict';

// ── État global ───────────────────────────────────────────────────────────

let shopItems   = [];   // items achetables { item, label, price }
let sellItems   = [];   // items vendables   { name, label, count, price }
let specialty   = 'all';
let balance     = 0;
let outpostId   = '';
let mode        = 'buy';  // 'buy' | 'sell'
let cart        = {};     // { itemName: { item, label, price, qty } }
let sellSel     = null;   // item sélectionné en mode vente
let favorites   = JSON.parse(localStorage.getItem('pvp_shop_favs') || '[]');
let srchVal     = '';
let filterVal   = '';

// ── Utilitaires ───────────────────────────────────────────────────────────

function fmt(n) {
  return '$' + Number(n).toLocaleString('fr-FR');
}

function getCategory(itemName) {
  if (!itemName) return 'Divers';
  const n = itemName;
  if (n.startsWith('vehicle_')) return 'Véhicule';
  if (n === 'bandage' || n === 'medkit') return 'Soin';
  if (n === 'kevlar') return 'Équipement';
  if (n.startsWith('ammo_')) return 'Munitions';
  if (['weapon_knife','weapon_bat','weapon_crowbar','weapon_switchblade','weapon_hatchet','weapon_machete'].includes(n)) return 'Mêlée';
  if (['weapon_pistol','weapon_snspistol','weapon_vintagepistol','weapon_machinepistol',
       'weapon_combatpistol','weapon_heavypistol','weapon_revolver','weapon_doubleaction'].includes(n)) return 'Pistolet';
  if (['weapon_microsmg','weapon_minismg','weapon_smg','weapon_combatpdw'].includes(n)) return 'SMG';
  if (['weapon_pumpshotgun','weapon_sawnoffshotgun','weapon_dbshotgun','weapon_assaultshotgun'].includes(n)) return 'Shotgun';
  if (['weapon_assaultrifle','weapon_carbinerifle','weapon_compactrifle','weapon_combatmg','weapon_mg'].includes(n)) return 'Fusil';
  if (n === 'weapon_sniperrifle') return 'Sniper';
  if (['weapon_rpg','weapon_grenadelauncher','weapon_grenade'].includes(n)) return 'Explosif';
  return 'Divers';
}

function getIcon(itemName) {
  const map = {
    bandage:'🩹', medkit:'💊', kevlar:'🛡️', ammo_sniper:'🔫',
    weapon_knife:'🔪', weapon_bat:'🏏', weapon_crowbar:'🔧',
    weapon_hatchet:'🪓', weapon_machete:'⚔️', weapon_switchblade:'🔪',
    weapon_grenade:'💣', weapon_rpg:'🚀', weapon_grenadelauncher:'💥',
  };
  if (map[itemName]) return map[itemName];
  if (itemName && itemName.startsWith('vehicle_')) return '🚗';
  if (itemName && itemName.startsWith('weapon_')) return '🔫';
  return '📦';
}

function imgSrc(itemName) {
  if (itemName && itemName.startsWith('vehicle_'))
    return `nui://pvp_inventory/html/img/${itemName.replace('vehicle_','')}.png`;
  return `nui://pvp_inventory/html/img/${itemName}.png`;
}

function buildImgTag(itemName, cls) {
  const ico = getIcon(itemName);
  return `<img class="${cls}-img" src="${imgSrc(itemName)}" alt=""
    onerror="this.style.display='none';this.nextElementSibling.style.display='flex'"/>
    <div class="${cls}-ico" style="display:none">${ico}</div>`;
}

function getShopTitle(spec) {
  if (spec === 'weapons') return 'ARMURERIE';
  if (spec === 'vehicles') return 'GARAGE';
  if (spec === 'medical') return 'INFIRMERIE';
  return "VENDEUR D'ÉQUIPEMENTS";
}

// ── Toast ─────────────────────────────────────────────────────────────────

let toastTimer = null;
function toast(msg, type = 'ok') {
  const el = document.getElementById('shop-toast');
  el.textContent = msg;
  el.className = 'show ' + type;
  if (toastTimer) clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { el.className = ''; }, 3000);
}

// ── Panier ────────────────────────────────────────────────────────────────

function cartTotal() {
  return Object.values(cart).reduce((s, c) => s + c.price * c.qty, 0);
}

function addToCart(item) {
  if (cart[item.item]) {
    cart[item.item].qty++;
  } else {
    cart[item.item] = { item: item.item, label: item.label, price: item.price, qty: 1 };
  }
  renderCart();
  renderBuyGrid();
}

function removeFromCart(itemName) {
  delete cart[itemName];
  renderCart();
  renderBuyGrid();
}

function changeQty(itemName, delta) {
  if (!cart[itemName]) return;
  cart[itemName].qty += delta;
  if (cart[itemName].qty <= 0) delete cart[itemName];
  renderCart();
  renderBuyGrid();
}

function clearCart() {
  cart = {};
  renderCart();
  renderBuyGrid();
}

function renderCart() {
  const list  = document.getElementById('cart-items-list');
  const empty = document.getElementById('cart-empty');
  const total = document.getElementById('cart-total');
  const btnB  = document.getElementById('btn-buy-bag');
  const btnS  = document.getElementById('btn-buy-stash');
  const entries = Object.values(cart);

  if (entries.length === 0) {
    empty.style.display = 'flex';
    list.innerHTML = '';
    total.textContent = '$0';
    btnB.disabled = true;
    btnS.disabled = true;
    return;
  }

  empty.style.display = 'none';
  btnB.disabled = false;
  btnS.disabled = false;
  total.textContent = fmt(cartTotal());

  list.innerHTML = '';
  for (const ci of entries) {
    const row = document.createElement('div');
    row.className = 'cart-row';
    row.innerHTML = `
      ${buildImgTag(ci.item, 'cart-row')}
      <div class="cart-row-info">
        <div class="cart-row-name">${ci.label}</div>
        <div class="cart-row-sub">${fmt(ci.price)} / unité</div>
      </div>
      <div class="cart-qty">
        <div class="cqb" onclick="changeQty('${ci.item}',-1)">&#8722;</div>
        <div class="cqn">${ci.qty}</div>
        <div class="cqb" onclick="changeQty('${ci.item}',1)">+</div>
      </div>
      <div class="cart-rm" onclick="removeFromCart('${ci.item}')">&#10005;</div>
    `;
    list.appendChild(row);
  }
}

// ── Grille Acheter ────────────────────────────────────────────────────────

function buildFilterOptions(items, keyFn) {
  const cats = [...new Set(items.map(i => keyFn(i.item || i.name)))].sort();
  const sel = document.getElementById('shop-filter');
  sel.innerHTML = '<option value="">Tous</option>';
  cats.forEach(c => {
    const o = document.createElement('option');
    o.value = c; o.textContent = c;
    sel.appendChild(o);
  });
}

function renderBuyGrid() {
  const grid = document.getElementById('buy-grid');
  grid.innerHTML = '';

  const filtered = shopItems.filter(item => {
    const ms = !srchVal || item.label.toLowerCase().includes(srchVal) || item.item.toLowerCase().includes(srchVal);
    const mf = !filterVal || getCategory(item.item) === filterVal;
    return ms && mf;
  });

  if (!filtered.length) {
    grid.innerHTML = '<div class="grid-empty">AUCUN ARTICLE TROUVÉ</div>';
    return;
  }

  filtered.forEach(item => {
    const inCart = !!cart[item.item];
    const isFav  = favorites.includes(item.item);
    const cat    = getCategory(item.item);
    const card   = document.createElement('div');
    card.className = 'shop-card';

    const itemJson = JSON.stringify(item).replace(/'/g, "\\'");

    card.innerHTML = `
      <span class="card-star ${isFav ? 'on' : ''}" title="Favoris" onclick="toggleFav('${item.item}',this)">&#9733;</span>
      ${buildImgTag(item.item, 'card')}
      <div class="card-name">${item.label}</div>
      <div class="card-cat">${cat}</div>
      <div class="card-price">${fmt(item.price)}</div>
      <button class="card-btn ${inCart ? 'added' : ''}"
        onclick="addToCart(JSON.parse(decodeURIComponent('${encodeURIComponent(JSON.stringify(item))}')))">
        ${inCart ? '+ Ajouter' : 'Acheter'}
      </button>
    `;
    grid.appendChild(card);
  });
}

// ── Grille Vendre ─────────────────────────────────────────────────────────

function getSellAllTotal() {
  let t = 0;
  for (const item of sellItems) {
    t += Math.floor(item.price * 0.5) * item.count;
  }
  return t;
}

function updateSellAllUI() {
  const total = getSellAllTotal();
  document.getElementById('sell-all-total').textContent = fmt(total);
  document.getElementById('btn-sell-all').disabled = sellItems.length === 0;
}

function renderSellGrid() {
  const grid = document.getElementById('sell-grid');
  grid.innerHTML = '';

  const filtered = sellItems.filter(item => {
    const ms = !srchVal || item.label.toLowerCase().includes(srchVal) || item.name.toLowerCase().includes(srchVal);
    const mf = !filterVal || getCategory(item.name) === filterVal;
    return ms && mf;
  });

  if (!filtered.length) {
    grid.innerHTML = `<div class="grid-empty">${sellItems.length === 0 ? 'RIEN À VENDRE' : 'AUCUN ARTICLE TROUVÉ'}</div>`;
    updateSellAllUI();
    return;
  }

  filtered.forEach(item => {
    const sellPrice = Math.floor(item.price * 0.5);
    const isSel = sellSel && sellSel.name === item.name;
    const card = document.createElement('div');
    card.className = 'shop-card' + (isSel ? ' card-sell-selected' : '');

    card.innerHTML = `
      ${buildImgTag(item.name, 'card')}
      <div class="card-name">${item.label}</div>
      <div class="card-qty-badge">x${item.count}</div>
      <div class="card-sell-price">${fmt(sellPrice)}</div>
      <button class="card-btn sell-btn ${isSel ? 'selected-btn' : ''}"
        onclick="selectSellItem(${item.count},${item.price},'${item.name}','${item.label}',${sellPrice})">
        ${isSel ? 'Sélectionné' : 'Vendre'}
      </button>
    `;
    grid.appendChild(card);
  });

  updateSellAllUI();
}

function selectSellItem(count, price, name, label, sellPrice) {
  sellSel = { name, label, count, price, sellPrice };

  // Afficher le détail à droite
  document.getElementById('sell-hint').style.display = 'none';
  const detail = document.getElementById('sell-item-detail');
  detail.style.display = 'flex';

  document.getElementById('sell-img-wrap').innerHTML =
    `<img src="${imgSrc(name)}" alt="" style="width:90px;height:90px;object-fit:contain;filter:drop-shadow(0 2px 10px rgba(0,0,0,.6))"
      onerror="this.outerHTML='<span style=font-size:52px>${getIcon(name)}</span>'"/>`;
  document.getElementById('sell-item-name').textContent = label;
  document.getElementById('sell-item-price').textContent = fmt(sellPrice);
  document.getElementById('sell-total').textContent = fmt(sellPrice);
  document.getElementById('btn-sell-confirm').disabled = false;

  renderSellGrid();
}

// ── Favoris ───────────────────────────────────────────────────────────────

function toggleFav(itemName, el) {
  const idx = favorites.indexOf(itemName);
  if (idx >= 0) {
    favorites.splice(idx, 1);
    el.classList.remove('on');
  } else {
    favorites.push(itemName);
    el.classList.add('on');
  }
  localStorage.setItem('pvp_shop_favs', JSON.stringify(favorites));
}

// ── Mode Tabs ─────────────────────────────────────────────────────────────

function setMode(newMode) {
  mode = newMode;
  srchVal = '';
  filterVal = '';
  document.getElementById('shop-search').value = '';
  document.getElementById('shop-filter').value = '';

  document.querySelectorAll('.mode-tab').forEach(t =>
    t.classList.toggle('active', t.dataset.mode === mode));

  if (mode === 'buy') {
    document.getElementById('buy-grid').style.display  = 'grid';
    document.getElementById('sell-grid').style.display = 'none';
    document.getElementById('buy-panel').style.display  = 'flex';
    document.getElementById('sell-panel').style.display = 'none';
    buildFilterOptions(shopItems, n => getCategory(n));
    renderBuyGrid();
    renderCart();
  } else {
    document.getElementById('buy-grid').style.display  = 'none';
    document.getElementById('sell-grid').style.display = 'grid';
    document.getElementById('buy-panel').style.display  = 'none';
    document.getElementById('sell-panel').style.display = 'flex';
    sellSel = null;
    document.getElementById('sell-hint').style.display = 'block';
    document.getElementById('sell-item-detail').style.display = 'none';
    document.getElementById('btn-sell-confirm').disabled = true;
    document.getElementById('sell-total').textContent = '$0';
    buildFilterOptions(sellItems, n => getCategory(n));
    renderSellGrid();
  }
}

// ── NUI Callbacks ─────────────────────────────────────────────────────────

function nuiFetch(endpoint, data) {
  return fetch(`https://pvp_outposts/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data || {}),
  }).then(r => r.json());
}

function doBuyCart(destination) {
  const entries = Object.values(cart);
  if (!entries.length) return;

  // Désactiver les boutons pendant la requête
  document.getElementById('btn-buy-bag').disabled   = true;
  document.getElementById('btn-buy-stash').disabled = true;

  nuiFetch('buyCart', { items: entries, destination, outpostId })
    .then(resp => {
      if (resp.ok) {
        toast(resp.message || 'Achat effectué.', 'ok');
        // Mise à jour du solde depuis la réponse serveur (source de vérité)
        if (typeof resp.balance === 'number') {
          balance = resp.balance;
          document.getElementById('shop-vendor-balance').textContent = 'Solde : ' + fmt(balance);
        }
        clearCart();
      } else {
        toast(resp.message || 'Erreur achat.', 'fail');
        // Réactiver les boutons si le panier n'est pas vide
        renderCart();
      }
    })
    .catch(() => {
      toast('Erreur de connexion.', 'fail');
      renderCart();
    });
}

function doSell() {
  if (!sellSel) return;
  document.getElementById('btn-sell-confirm').disabled = true;

  nuiFetch('sellItem', { item: sellSel.name, sellPrice: sellSel.sellPrice })
    .then(resp => {
      if (resp.ok) {
        toast(resp.message || 'Article vendu.', 'ok');
        if (typeof resp.balance === 'number') {
          balance = resp.balance;
          document.getElementById('shop-vendor-balance').textContent = 'Solde : ' + fmt(balance);
        }
        // Mettre à jour sellItems
        const idx = sellItems.findIndex(i => i.name === sellSel.name);
        if (idx >= 0) {
          sellItems[idx].count--;
          if (sellItems[idx].count <= 0) sellItems.splice(idx, 1);
        }
        sellSel = null;
        document.getElementById('sell-hint').style.display = 'block';
        document.getElementById('sell-item-detail').style.display = 'none';
        document.getElementById('btn-sell-confirm').disabled = true;
        document.getElementById('sell-total').textContent = '$0';
        renderSellGrid();
      } else {
        toast(resp.message || 'Erreur vente.', 'fail');
        document.getElementById('btn-sell-confirm').disabled = false;
      }
    });
}

function doSellAll() {
  if (!sellItems.length) return;

  document.getElementById('btn-sell-all').disabled = true;

  nuiFetch('sellAll', { specialty: specialty })
    .then(resp => {
      if (resp.ok) {
        toast(resp.message || 'Tout vendu.', 'ok');
        if (typeof resp.balance === 'number') {
          balance = resp.balance;
          document.getElementById('shop-vendor-balance').textContent = 'Solde : ' + fmt(balance);
        }
        sellItems = [];
        sellSel = null;
        document.getElementById('sell-hint').style.display = 'block';
        document.getElementById('sell-item-detail').style.display = 'none';
        document.getElementById('btn-sell-confirm').disabled = true;
        document.getElementById('sell-total').textContent = '$0';
        renderSellGrid();
      } else {
        toast(resp.message || 'Erreur vente.', 'fail');
        document.getElementById('btn-sell-all').disabled = false;
      }
    })
    .catch(() => {
      toast('Erreur de connexion.', 'fail');
      document.getElementById('btn-sell-all').disabled = false;
    });
}

function closeShop() {
  document.getElementById('shop-overlay').classList.remove('open');
  nuiFetch('closeShop');
}

// ── Message Lua → NUI ─────────────────────────────────────────────────────

window.addEventListener('message', function(e) {
  const d = e.data;
  if (!d || !d.action) return;

  if (d.action === 'openShop') {
    shopItems = d.items    || [];
    specialty = d.specialty || 'all';
    balance   = d.balance  || 0;
    outpostId = d.outpostId || '';

    // Filtrer les items vendables selon la spécialité
    const allSell = d.sellItems || [];
    if (specialty === 'weapons') {
      sellItems = allSell.filter(i => i.name.startsWith('weapon_') || i.name.startsWith('ammo_'));
    } else if (specialty === 'vehicles') {
      sellItems = allSell.filter(i => i.name.startsWith('vehicle_'));
    } else if (specialty === 'medical') {
      sellItems = allSell.filter(i => ['bandage','medkit','kevlar'].includes(i.name));
    } else {
      // Shop général : seulement consommables (pas d'armes ni véhicules)
      sellItems = allSell.filter(i => !i.name.startsWith('weapon_') && !i.name.startsWith('vehicle_'));
    }

    document.getElementById('shop-vendor-title').textContent   = getShopTitle(specialty);
    document.getElementById('shop-vendor-balance').textContent = 'Solde : ' + fmt(balance);

    // Reset
    cart    = {};
    sellSel = null;
    srchVal = '';
    filterVal = '';
    document.getElementById('shop-search').value = '';
    document.getElementById('shop-filter').value = '';

    // Réinitialiser le panneau sell
    document.getElementById('sell-hint').style.display       = 'block';
    document.getElementById('sell-item-detail').style.display = 'none';
    document.getElementById('btn-sell-confirm').disabled     = true;
    document.getElementById('sell-total').textContent        = '$0';

    // Forcer le mode buy
    mode = 'buy';
    document.getElementById('buy-grid').style.display  = 'grid';
    document.getElementById('sell-grid').style.display = 'none';
    document.getElementById('buy-panel').style.display  = 'flex';
    document.getElementById('sell-panel').style.display = 'none';
    document.querySelectorAll('.mode-tab').forEach(t =>
      t.classList.toggle('active', t.dataset.mode === 'buy'));

    buildFilterOptions(shopItems, n => getCategory(n));
    renderBuyGrid();
    renderCart();

    document.getElementById('shop-overlay').classList.add('open');
  }

  if (d.action === 'updateBalance') {
    balance = d.balance;
    document.getElementById('shop-vendor-balance').textContent = 'Solde : ' + fmt(balance);
  }

});

// ── Listeners ─────────────────────────────────────────────────────────────

document.addEventListener('keydown', e => { if (e.key === 'Escape') closeShop(); });

document.querySelectorAll('.mode-tab').forEach(btn =>
  btn.addEventListener('click', () => setMode(btn.dataset.mode)));

document.getElementById('shop-search').addEventListener('input', function() {
  srchVal = this.value.toLowerCase();
  if (mode === 'buy') renderBuyGrid(); else renderSellGrid();
});
document.getElementById('shop-filter').addEventListener('change', function() {
  filterVal = this.value;
  if (mode === 'buy') renderBuyGrid(); else renderSellGrid();
});

document.getElementById('btn-buy-bag').addEventListener('click',   () => doBuyCart('bag'));
document.getElementById('btn-buy-stash').addEventListener('click', () => doBuyCart('stash'));
document.getElementById('btn-sell-confirm').addEventListener('click', doSell);
document.getElementById('btn-sell-all').addEventListener('click', doSellAll);

// ── Waypoint teleport prompt ─────────────────────────────────────────────
window.addEventListener('message', function(e) {
    if (e.data.type === 'waypointPrompt') {
        const el = document.getElementById('wp-tp-prompt');
        const dest = document.getElementById('wp-tp-dest');
        if (e.data.show) {
            dest.textContent = e.data.label || '—';
            el.classList.add('visible');
        } else {
            el.classList.remove('visible');
        }
    }
});

// ── Clipboard : copie automatique des coords (/coords) ─────────────────
window.addEventListener('message', function(e) {
    if (e.data.action === 'copyToClipboard') {
        const el = document.createElement('textarea');
        el.value = e.data.text;
        el.style.position = 'fixed';
        el.style.left = '-9999px';
        document.body.appendChild(el);
        el.select();
        document.execCommand('copy');
        document.body.removeChild(el);
        fetch('https://pvp_outposts/clipboardDone', { method: 'POST', body: JSON.stringify({}) });
    }
});
