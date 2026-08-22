// =============================================
//   PVP CHARACTER — app.js
// =============================================

const CATALOG_OK = (typeof PED_CATALOG !== 'undefined' && Array.isArray(PED_CATALOG) && PED_CATALOG.length > 0);
// Catégories exclues du catalogue de création (freemode a sa propre branche,
// les animaux sont exclus des choix de personnage PVP permanents).
const EXCLUDED_PED_CATS = ['freemode', 'animal'];
const CREATION_CATALOG = CATALOG_OK ? PED_CATALOG.filter(p => !EXCLUDED_PED_CATS.includes(p.cat)) : [];

const pseudoInput  = document.getElementById('pseudo-input');
const pseudoHint   = document.getElementById('pseudo-hint');
const confirmBtn   = document.getElementById('confirm-btn');
const errorMsg     = document.getElementById('error-msg');
const typeCards    = document.querySelectorAll('.type-card');
const genderCards  = document.querySelectorAll('.gender-card');
const branchFree   = document.getElementById('branch-freemode');
const branchSpecial = document.getElementById('branch-special');
const specialWarning = document.getElementById('special-warning');
const catalogUnavail = document.getElementById('catalog-unavailable');

const local = {
    pseudoValid: false,
    charType: 'freemode',
    gender: 'male',
    selectedPedModel: '',
    pedCategory: 'all',
};

let st = null; // dernier snapshot reçu du client Lua (state)

// ── Pont NUI ──────────────────────────────────────────────────────────────
function lua(name, data) {
    return fetch(`https://pvp_character/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {}),
    }).then(r => r.json()).catch(() => ({}));
}

// ── Validation du pseudo ─────────────────────────────────────────────────
function validatePseudo(value) {
    const v = value.trim();
    if (v.length === 0)   return { valid: false, msg: '2–20 caractères' };
    if (v.length < 2)     return { valid: false, msg: '2 caractères minimum' };
    if (v.length > 20)    return { valid: false, msg: '20 caractères maximum' };
    if (!/^[a-zA-Z0-9À-ÿ _\-]+$/.test(v)) return { valid: false, msg: 'Caractères non autorisés' };
    return { valid: true, msg: '2–20 caractères' };
}

pseudoInput.addEventListener('input', function () {
    clearError();
    const result = validatePseudo(this.value);
    local.pseudoValid = result.valid;

    const hasInput = this.value.length > 0;
    pseudoHint.textContent = result.msg;
    pseudoHint.classList.toggle('error', !result.valid && hasInput);
    pseudoInput.classList.toggle('error', !result.valid && hasInput);

    updateBtn();
});

// ── Type de personnage ───────────────────────────────────────────────────
typeCards.forEach(function (card) {
    card.addEventListener('click', function () {
        if (this.dataset.type === 'special' && !CATALOG_OK) return;
        typeCards.forEach(function (c) { c.classList.remove('selected'); });
        this.classList.add('selected');
        local.charType = this.dataset.type;

        branchFree.classList.toggle('hidden', local.charType !== 'freemode');
        branchSpecial.classList.toggle('hidden', local.charType !== 'special');

        if (local.charType === 'special') {
            renderPedCategories();
            renderPedGrid();
        }

        lua('setType', { type: local.charType }).then(function (data) {
            if (data && data.charType) { st = data; renderAll(); }
        });
        updateBtn();
    });
});

if (!CATALOG_OK) {
    document.getElementById('type-special').classList.add('locked');
} else {
    catalogUnavail.classList.add('hidden');
}

// ── Genre ─────────────────────────────────────────────────────────────────
genderCards.forEach(function (card) {
    card.addEventListener('click', function () {
        genderCards.forEach(function (c) { c.classList.remove('selected'); });
        this.classList.add('selected');
        local.gender = this.dataset.gender;
        lua('setGender', { gender: local.gender }).then(function (data) {
            if (data && data.charType) { st = data; renderAll(); }
        });
    });
});

// ── Générique : ligne "cycler" ──────────────────────────────────────────
// row = { label, fields: [ { key, value, max, formatValue? } ], onCycle(field, dir) }
function buildCyclerRow(label, fields, onCycleId, extra) {
    const rows = fields.map(function (f) {
        const display = f.formatValue ? f.formatValue(f.value) : (f.value + 1) + '/' + (f.max + 1);
        return `
            <div class="cycler-line">
                <button class="cycler-arrow" onclick="${onCycleId}('${f.key}', -1)">◀</button>
                <span class="cycler-value">${display}</span>
                <button class="cycler-arrow" onclick="${onCycleId}('${f.key}', 1)">▶</button>
                <span class="cycler-count">${f.max >= 0 ? (f.value + 1) + '/' + (f.max + 1) : ''}</span>
            </div>`;
    }).join('');

    return `
        <div class="cycler-row">
            <div class="cycler-label">${label}</div>
            <div class="cycler-fields">${rows}</div>
        </div>`;
}

// ── Visage ────────────────────────────────────────────────────────────────
function renderSkinGrid() {
    const grid = document.getElementById('skin-grid');
    grid.innerHTML = CHAR_SKIN_HEX.map(function (hex, i) {
        const selected = st && st.skinIdx === i ? 'selected' : '';
        return `<div class="swatch ${selected}" style="--tone:${hex}" onclick="onSetSkin(${i})"><span class="swatch-dot"></span></div>`;
    }).join('');
}

function onSetSkin(i) {
    lua('setSkin', { index: i }).then(function () {
        st.skinIdx = i;
        renderSkinGrid();
    });
}

function renderFaceCyclers() {
    if (!st) return;
    const container = document.getElementById('face-cyclers');
    let html = '';
    html += buildCyclerRow('MORPHOLOGIE (PÈRE)', [{ key: 'shapeFirst', value: st.face.shapeFirst, max: 45 }], 'onCycleFace');
    html += buildCyclerRow('MORPHOLOGIE (MÈRE)', [{ key: 'shapeSecond', value: st.face.shapeSecond, max: 45 }], 'onCycleFace');
    html += buildCyclerRow('MIXAGE', [{ key: 'shapeMix', value: Math.round(st.face.shapeMix * 10), max: 10, formatValue: v => (v * 10) + '%' }], 'onCycleFace');
    html += buildCyclerRow('BARBE', [{ key: 'beard', value: st.beard.index === 255 ? -1 : st.beard.index, max: st.beard.max, formatValue: v => v < 0 ? 'AUCUNE' : (v + 1) + '/' + (st.beard.max + 1) }], 'onCycleFace');
    html += buildCyclerRow('SOURCILS', [{ key: 'eyebrows', value: st.eyebrows.index === 255 ? -1 : st.eyebrows.index, max: st.eyebrows.max, formatValue: v => v < 0 ? 'AUCUN' : (v + 1) + '/' + (st.eyebrows.max + 1) }], 'onCycleFace');
    html += buildCyclerRow('COULEUR DES YEUX', [{ key: 'eyeColor', value: st.eyeColor, max: 31 }], 'onCycleFace');
    container.innerHTML = html;
}

function onCycleFace(field, dir) {
    lua('cycleFace', { field: field, dir: dir }).then(function (data) {
        if (!data) return;
        st.face.shapeFirst  = data.shapeFirst;
        st.face.shapeSecond = data.shapeSecond;
        st.face.shapeMix    = data.shapeMix;
        st.beard.index      = data.beard;
        st.eyebrows.index   = data.eyebrows;
        st.eyeColor         = data.eyeColor;
        renderFaceCyclers();
    });
}

// ── Cheveux ───────────────────────────────────────────────────────────────
function renderHairCyclers() {
    if (!st) return;
    const container = document.getElementById('hair-cyclers');
    let html = '';
    html += buildCyclerRow('COIFFURE', [{ key: 'drawable', value: st.hair.drawable, max: st.hair.drawableMax }], 'onCycleHair');
    html += buildCyclerRow('VARIANTE', [{ key: 'texture', value: st.hair.texture, max: st.hair.textureMax }], 'onCycleHair');
    html += buildCyclerRow('REFLETS', [{ key: 'highlight', value: st.hair.highlight, max: 63 }], 'onCycleHair');
    container.innerHTML = html;

    const grid = document.getElementById('hair-color-grid');
    grid.innerHTML = CHAR_HAIR_COLORS.map(function (hex, i) {
        const selected = st.hair.color === i ? 'selected' : '';
        return `<div class="palette-dot ${selected}" style="--tone:${hex}" onclick="onSetHairColor(${i})"></div>`;
    }).join('');
}

function onCycleHair(field, dir) {
    lua('cycleHair', { field: field, dir: dir }).then(function (data) {
        if (!data) return;
        Object.assign(st.hair, data);
        renderHairCyclers();
    });
}

function onSetHairColor(i) {
    lua('setHairColor', { color: i }).then(function () {
        st.hair.color = i;
        renderHairCyclers();
    });
}

// ── Tenue / accessoires ──────────────────────────────────────────────────
function renderOutfitCyclers() {
    if (!st) return;
    const container = document.getElementById('outfit-cyclers');
    container.innerHTML = st.comps.map(renderComponentRow).join('');
}

function renderComponentRow(c) {
    const dLabel = (c.drawable + 1) + '/' + (c.drawableMax + 1);
    const tLabel = (c.texture + 1) + '/' + (c.textureMax + 1);
    return `
        <div class="cycler-row">
            <div class="cycler-label">${c.label}</div>
            <div class="cycler-fields">
                <div class="cycler-line">
                    <button class="cycler-arrow" onclick="onCycleComponent(${c.id},'drawable',-1)">◀</button>
                    <span class="cycler-value">Variante</span>
                    <button class="cycler-arrow" onclick="onCycleComponent(${c.id},'drawable',1)">▶</button>
                    <span class="cycler-count">${dLabel}</span>
                </div>
                ${c.textureMax > 0 ? `
                <div class="cycler-line">
                    <button class="cycler-arrow" onclick="onCycleComponent(${c.id},'texture',-1)">◀</button>
                    <span class="cycler-value">Teinte</span>
                    <button class="cycler-arrow" onclick="onCycleComponent(${c.id},'texture',1)">▶</button>
                    <span class="cycler-count">${tLabel}</span>
                </div>` : ''}
            </div>
        </div>`;
}

function onCycleComponent(compId, field, dir) {
    lua('cycleComponent', { comp: compId, field: field, dir: dir }).then(function (data) {
        if (!data) return;
        const entry = st.comps.find(c => c.id === compId);
        if (entry) Object.assign(entry, data);
        renderOutfitCyclers();
    });
}

function renderPropCyclers() {
    if (!st) return;
    const container = document.getElementById('prop-cyclers');
    container.innerHTML = st.props.map(renderPropRow).join('');
}

function renderPropRow(p) {
    const none = p.drawable < 0;
    const dLabel = none ? 'AUCUN' : (p.drawable + 1) + '/' + (p.drawableMax + 1);
    const tLabel = (p.texture + 1) + '/' + (p.textureMax + 1);
    return `
        <div class="cycler-row">
            <div class="cycler-label">${p.label}</div>
            <div class="cycler-fields">
                <div class="cycler-line">
                    <button class="cycler-arrow" onclick="onCycleProp(${p.id},'drawable',-1)">◀</button>
                    <span class="cycler-value">${none ? 'Aucun' : 'Variante'}</span>
                    <button class="cycler-arrow" onclick="onCycleProp(${p.id},'drawable',1)">▶</button>
                    <span class="cycler-count">${dLabel}</span>
                </div>
                ${(!none && p.textureMax > 0) ? `
                <div class="cycler-line">
                    <button class="cycler-arrow" onclick="onCycleProp(${p.id},'texture',-1)">◀</button>
                    <span class="cycler-value">Teinte</span>
                    <button class="cycler-arrow" onclick="onCycleProp(${p.id},'texture',1)">▶</button>
                    <span class="cycler-count">${tLabel}</span>
                </div>` : ''}
            </div>
        </div>`;
}

function onCycleProp(propId, field, dir) {
    lua('cycleProp', { prop: propId, field: field, dir: dir }).then(function (data) {
        if (!data) return;
        const entry = st.props.find(p => p.id === propId);
        if (entry) Object.assign(entry, data);
        renderPropCyclers();
    });
}

// ── Catalogue de peds spéciaux ───────────────────────────────────────────
function renderPedCategories() {
    const container = document.getElementById('ped-categories');
    container.innerHTML = Object.entries(CHAR_PED_CATEGORIES).map(([key, label]) =>
        `<button class="chip ${key === local.pedCategory ? 'active' : ''}" onclick="setPedCategory('${key}')">${label}</button>`
    ).join('');
}

function setPedCategory(cat) {
    local.pedCategory = cat;
    renderPedCategories();
    renderPedGrid();
}

function renderPedGrid() {
    const grid = document.getElementById('ped-grid');
    const search = (document.getElementById('ped-search').value || '').toLowerCase().trim();

    let peds = CREATION_CATALOG;
    if (local.pedCategory !== 'all') peds = peds.filter(p => p.cat === local.pedCategory);
    if (search) peds = peds.filter(p => p.model.includes(search) || p.name.toLowerCase().includes(search));

    const displayed = peds.slice(0, 200);
    const hasMore = peds.length > 200;

    grid.innerHTML = displayed.map(function (p) {
        const selected = local.selectedPedModel === p.model;
        return `<div class="ped-card ${selected ? 'ped-selected' : ''}" onclick="selectSpecialPed('${p.model}')">
            <div class="ped-card-name">${p.name}</div>
        </div>`;
    }).join('') + (hasMore ? '<div class="ped-grid-more">Affinez votre recherche...</div>' : '');
}

document.getElementById('ped-search').addEventListener('input', renderPedGrid);

function selectSpecialPed(model) {
    local.selectedPedModel = model;
    renderPedGrid();
    lua('previewSpecialPed', { model: model });
    updateBtn();
}

// ── Aléatoire ─────────────────────────────────────────────────────────────
document.getElementById('btn-random').addEventListener('click', function () {
    if (local.charType !== 'freemode') return;
    lua('randomizeAppearance', {}).then(function (data) {
        if (data && data.charType) { st = data; renderAll(); }
    });
});

// ── Rotation / mode caméra ────────────────────────────────────────────────
document.getElementById('rot-left').addEventListener('click', function () { lua('rotatePed', { dir: -1 }); });
document.getElementById('rot-right').addEventListener('click', function () { lua('rotatePed', { dir: 1 }); });

document.querySelectorAll('.view-cam-btn').forEach(function (btn) {
    btn.addEventListener('click', function () {
        document.querySelectorAll('.view-cam-btn').forEach(b => b.classList.remove('active'));
        this.classList.add('active');
        lua('setCamMode', { mode: this.dataset.mode });
    });
});

// ── Rendu global ──────────────────────────────────────────────────────────
function renderAll() {
    renderSkinGrid();
    renderFaceCyclers();
    renderHairCyclers();
    renderOutfitCyclers();
    renderPropCyclers();
}

// ── Activer / désactiver le bouton confirmer ─────────────────────────────
function updateBtn() {
    if (local.charType === 'special') {
        confirmBtn.disabled = !(local.pseudoValid && local.selectedPedModel);
        specialWarning.classList.toggle('hidden', !local.selectedPedModel);
    } else {
        confirmBtn.disabled = !local.pseudoValid;
        specialWarning.classList.add('hidden');
    }
}

// ── Gestion d'erreur ─────────────────────────────────────────────────────
function showError(msg) {
    errorMsg.textContent = msg;
    errorMsg.classList.add('visible');
    confirmBtn.disabled  = false;
    updateBtn();
}

function clearError() {
    errorMsg.textContent = '';
    errorMsg.classList.remove('visible');
}

// ── Confirmation ─────────────────────────────────────────────────────────
confirmBtn.addEventListener('click', function () {
    if (confirmBtn.disabled) return;
    clearError();
    confirmBtn.disabled = true;
    const pseudo = pseudoInput.value.trim();
    lua('confirmCharacter', { pseudo: pseudo });
});

// ── Reset du formulaire ──────────────────────────────────────────────────
function resetForm() {
    pseudoInput.value = '';
    pseudoHint.textContent = '2–20 caractères';
    pseudoHint.classList.remove('error');
    pseudoInput.classList.remove('error');
    clearError();

    local.pseudoValid = false;
    local.charType = 'freemode';
    local.gender = 'male';
    local.selectedPedModel = '';
    local.pedCategory = 'all';

    typeCards.forEach(function (c) { c.classList.remove('selected'); });
    document.getElementById('type-freemode').classList.add('selected');
    genderCards.forEach(function (c) { c.classList.remove('selected'); });
    document.getElementById('card-male').classList.add('selected');

    branchFree.classList.remove('hidden');
    branchSpecial.classList.add('hidden');

    updateBtn();
}

// ── Messages depuis le jeu ───────────────────────────────────────────────
window.addEventListener('message', function (e) {
    const data = e.data;
    if (!data || !data.action) return;

    if (data.action === 'show') {
        document.getElementById('overlay').classList.remove('hidden');
        resetForm();
        setTimeout(function () { pseudoInput.focus(); }, 50);
    }

    if (data.action === 'state') {
        st = data.state;
        renderAll();
    }

    if (data.action === 'hide') {
        document.getElementById('overlay').classList.add('hidden');
    }

    if (data.action === 'error') {
        showError(data.message || 'Erreur');
    }
});

updateBtn();
