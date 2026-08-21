// =============================================
//   PVP CHARACTER — app.js
// =============================================

const pseudoInput = document.getElementById('pseudo-input');
const pseudoHint  = document.getElementById('pseudo-hint');
const confirmBtn  = document.getElementById('confirm-btn');
const errorMsg    = document.getElementById('error-msg');
const genderCards = document.querySelectorAll('.gender-card');
const swatches    = document.querySelectorAll('.swatch');
const hairCards   = document.querySelectorAll('.hair-card');

const state = {
    pseudoValid: false,
    gender:      'male',
    skin_tone:   0,
    hair_style:  0,
};

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
    state.pseudoValid = result.valid;

    const hasInput = this.value.length > 0;
    pseudoHint.textContent = result.msg;
    pseudoHint.classList.toggle('error', !result.valid && hasInput);
    pseudoInput.classList.toggle('error', !result.valid && hasInput);

    updateBtn();
});

// ── Sélection du genre ───────────────────────────────────────────────────
genderCards.forEach(function (card) {
    card.addEventListener('click', function () {
        genderCards.forEach(function (c) { c.classList.remove('selected'); });
        this.classList.add('selected');
        state.gender = this.dataset.gender;
        sendPreview();
        updateBtn();
    });
});

// ── Sélection de la peau ─────────────────────────────────────────────────
swatches.forEach(function (sw) {
    sw.addEventListener('click', function () {
        swatches.forEach(function (s) { s.classList.remove('selected'); });
        this.classList.add('selected');
        state.skin_tone = parseInt(this.dataset.skin, 10) || 0;
        sendPreview();
    });
});

// ── Sélection des cheveux ────────────────────────────────────────────────
hairCards.forEach(function (h) {
    h.addEventListener('click', function () {
        hairCards.forEach(function (c) { c.classList.remove('selected'); });
        this.classList.add('selected');
        state.hair_style = parseInt(this.dataset.hair, 10) || 0;
        sendPreview();
    });
});

// ── Défauts sélectionnés visuellement ────────────────────────────────────
function selectDefaults() {
    document.querySelector('[data-gender="male"]').classList.add('selected');
    document.querySelector('[data-skin="0"]').classList.add('selected');
    document.querySelector('[data-hair="0"]').classList.add('selected');
}

// ── Activer / désactiver le bouton ───────────────────────────────────────
function updateBtn() {
    confirmBtn.disabled = !(state.pseudoValid && state.gender);
}

// ── Envoi du preview au client Lua ───────────────────────────────────────
function sendPreview() {
    fetch('https://pvp_character/updatePreview', {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify({
            gender:     state.gender,
            skin_tone:  state.skin_tone,
            hair_style: state.hair_style,
        })
    }).catch(function () {});
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
    fetch('https://pvp_character/confirmCharacter', {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify({
            pseudo:     pseudo,
            gender:     state.gender,
            skin_tone:  state.skin_tone,
            hair_style: state.hair_style,
        })
    }).catch(function () {
        showError('Erreur de communication, réessaie');
    });
});

// ── Reset du formulaire ──────────────────────────────────────────────────
function resetForm() {
    pseudoInput.value = '';
    pseudoHint.textContent = '2–20 caractères';
    pseudoHint.classList.remove('error');
    pseudoInput.classList.remove('error');
    clearError();

    state.pseudoValid = false;
    state.gender      = 'male';
    state.skin_tone   = 0;
    state.hair_style  = 0;

    genderCards.forEach(function (c) { c.classList.remove('selected'); });
    swatches.forEach(function (s) { s.classList.remove('selected'); });
    hairCards.forEach(function (h) { h.classList.remove('selected'); });

    selectDefaults();
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

    if (data.action === 'hide') {
        document.getElementById('overlay').classList.add('hidden');
    }

    if (data.action === 'error') {
        showError(data.message || 'Erreur');
    }
});

// Init défaut au chargement
selectDefaults();
