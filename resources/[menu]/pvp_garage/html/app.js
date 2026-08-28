/* ═══════════════════════════════════════════════════════════════
   PVP GARAGE — NUI Controller
   Vanilla JS · No frameworks · No jQuery
   ═══════════════════════════════════════════════════════════════ */

// [STATE — Mechanic]
let currentMode = null; // 'mechanic' | 'dealer'
let categories = [];
let vehicleColors = [];
let wheelTypes = {};
let windowTints = [];
let xenonColors = [];
let specialModsDef = [];
let vehicleData = {};
let selectedCategory = null;
let paintSubTab = 'primary';

// [STATE — Garage Dealer]
let gdVehicles   = [];   // catalogue achetable
let gdSellItems  = [];   // items vendables (vehicle_* dans inventaire)
let gdBalance    = 0;
let gdCart       = {};   // { itemName: { item, label, price, qty } }
let gdSellSel    = null; // item sélectionné en mode vente
let gdMode       = 'buy';
let gdSrch       = '';
let gdFilter     = '';

// [DOM REFS]
const mechanicPanel = document.getElementById('mechanic-panel');
const mechSidebar   = document.getElementById('mech-sidebar');
const mechContent   = document.getElementById('mech-content');

// [NUI POST HELPER]
function post(action, data) {
    return fetch('https://pvp_garage/' + action, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {})
    });
}

// [MESSAGE LISTENER]
window.addEventListener('message', function(event) {
    const msg = event.data;

    if (msg.action === 'openMechanic') {
        categories = msg.data.categories || [];
        vehicleColors = msg.data.vehicleColors || [];
        wheelTypes = msg.data.wheelTypes || {};
        windowTints = msg.data.windowTints || [];
        xenonColors = msg.data.xenonColors || [];
        specialModsDef = msg.data.specialMods || [];
        vehicleData = msg.data.vehicleData || {};
        currentMode = 'mechanic';
        openMechanic();
    }

    if (msg.action === 'openDealer') {
        gdVehicles  = msg.data.vehicles   || [];
        gdSellItems = msg.data.sellItems  || [];
        gdBalance   = msg.data.balance    || 0;
        currentMode = 'dealer';
        gdOpenDealer();
    }

    if (msg.action === 'close') {
        closeAll();
    }
});

// [KEYBOARD — ESC to close]
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        if (currentMode === 'mechanic') {
            post('cancel');
        } else if (currentMode === 'dealer') {
            post('close');
        }
        closeAll();
    }
});

// [CAMERA ORBITALE — clic droit + drag = rotation, molette = zoom]
(function() {
    var isDragging = false;
    var lastX = 0, lastY = 0;
    var SENSITIVITY = 0.3;

    document.addEventListener('mousedown', function(e) {
        if (e.button === 2 && currentMode === 'mechanic') {
            isDragging = true;
            lastX = e.clientX;
            lastY = e.clientY;
            e.preventDefault();
        }
    });

    document.addEventListener('mousemove', function(e) {
        if (!isDragging) return;
        var dx = (e.clientX - lastX) * SENSITIVITY;
        var dy = (e.clientY - lastY) * SENSITIVITY;
        lastX = e.clientX;
        lastY = e.clientY;
        if (dx !== 0 || dy !== 0) {
            post('cameraRotate', { dx: dx, dy: dy });
        }
    });

    document.addEventListener('mouseup', function(e) {
        if (e.button === 2) isDragging = false;
    });

    document.addEventListener('wheel', function(e) {
        if (currentMode !== 'mechanic') return;
        var delta = e.deltaY > 0 ? -0.5 : 0.5;
        post('cameraZoom', { delta: delta });
        e.preventDefault();
    }, { passive: false });

    document.addEventListener('contextmenu', function(e) {
        if (currentMode === 'mechanic') e.preventDefault();
    });
})();

// [CLOSE ALL]
function closeAll() {
    mechanicPanel.classList.add('hidden');
    var gd = document.getElementById('garage-dealer');
    gd.classList.remove('open');
    gd.style.display = 'none';
    currentMode = null;
    selectedCategory = null;
    gdCart    = {};
    gdSellSel = null;
}

// ═══════════════════════════════════════════════════════════════
// MECHANIC PANEL
// ═══════════════════════════════════════════════════════════════

function openMechanic() {
    var gd = document.getElementById('garage-dealer');
    gd.classList.remove('open');
    gd.style.display = 'none';
    mechanicPanel.classList.remove('hidden');
    buildMechanicSidebar();
    mechContent.innerHTML = '<div class="empty-state">Sélectionnez une catégorie</div>';
}

// [BUILD SIDEBAR]
function buildMechanicSidebar() {
    mechSidebar.innerHTML = '';

    categories.forEach(function(cat) {
        var item = document.createElement('div');
        item.className = 'sidebar-item';
        item.textContent = cat.label;
        item.dataset.id = cat.id;
        item.addEventListener('click', function() {
            selectCategory(cat.id);
        });
        mechSidebar.appendChild(item);
    });

    // Special tab for apocalypse vehicles
    if (vehicleData.isApocalypse) {
        var sep = document.createElement('div');
        sep.style.height = '1px';
        sep.style.background = 'var(--border)';
        sep.style.margin = '6px 12px';
        mechSidebar.appendChild(sep);

        var specialItem = document.createElement('div');
        specialItem.className = 'sidebar-item special';
        specialItem.textContent = 'SPECIAL';
        specialItem.dataset.id = 'special';
        specialItem.addEventListener('click', function() {
            selectCategory('special');
        });
        mechSidebar.appendChild(specialItem);
    }
}

// [SELECT CATEGORY]
function selectCategory(catId) {
    selectedCategory = catId;

    // Update sidebar active state
    var items = mechSidebar.querySelectorAll('.sidebar-item');
    items.forEach(function(el) {
        el.classList.toggle('active', el.dataset.id === catId);
    });

    // Render content
    switch (catId) {
        case 'paint':        renderPaint(); break;
        case 'wheels':       renderWheels(); break;
        case 'engine':       renderUpgrade('engine', 11, vehicleData.engineLevel, vehicleData.numEngineLevels, 'Moteur'); break;
        case 'brakes':       renderUpgrade('brakes', 12, vehicleData.brakesLevel, vehicleData.numBrakesLevels, 'Freins'); break;
        case 'transmission': renderUpgrade('transmission', 13, vehicleData.transmissionLevel, vehicleData.numTransmissionLevels, 'Transmission'); break;
        case 'armor':        renderUpgrade('armor', 16, vehicleData.armorLevel, vehicleData.numArmorLevels, 'Blindage'); break;
        case 'turbo':        renderTurbo(); break;
        case 'suspension':   renderUpgrade('suspension', 15, vehicleData.suspensionLevel, vehicleData.numSuspensionLevels, 'Suspension'); break;
        case 'livery':       renderLivery(); break;
        case 'neon':         renderNeon(); break;
        case 'tint':         renderWindowTint(); break;
        case 'xenon':        renderXenon(); break;
        case 'special':      renderSpecial(); break;
    }
}

// ═══════════════════════════════════════════════════════════════
// RENDER — PAINT
// ═══════════════════════════════════════════════════════════════

function renderPaint() {
    paintSubTab = 'primary';
    var html = '';

    // Sub-tabs
    html += '<div class="sub-tabs">';
    html += '<button class="sub-tab active" data-paint="primary">Primaire</button>';
    html += '<button class="sub-tab" data-paint="secondary">Secondaire</button>';
    html += '<button class="sub-tab" data-paint="pearlescent">Nacré</button>';
    html += '<button class="sub-tab" data-paint="wheel">Roues</button>';
    html += '</div>';

    html += '<div id="paint-grid-container"></div>';

    mechContent.innerHTML = html;

    // Sub-tab clicks
    var tabs = mechContent.querySelectorAll('.sub-tab');
    tabs.forEach(function(tab) {
        tab.addEventListener('click', function() {
            tabs.forEach(function(t) { t.classList.remove('active'); });
            tab.classList.add('active');
            paintSubTab = tab.dataset.paint;
            renderColorGrid();
        });
    });

    renderColorGrid();
}

function renderColorGrid() {
    var container = document.getElementById('paint-grid-container');
    var activeIndex = -1;

    if (paintSubTab === 'primary') activeIndex = vehicleData.primaryColor;
    else if (paintSubTab === 'secondary') activeIndex = vehicleData.secondaryColor;
    else if (paintSubTab === 'pearlescent') activeIndex = vehicleData.pearlescentColor;
    else if (paintSubTab === 'wheel') activeIndex = vehicleData.wheelColor;

    var html = '<div class="color-grid">';
    vehicleColors.forEach(function(c) {
        var isActive = c.index === activeIndex ? ' active' : '';
        html += '<div class="color-swatch' + isActive + '" data-index="' + c.index + '" '
             + 'style="background:rgb(' + c.r + ',' + c.g + ',' + c.b + ')" '
             + 'title="' + c.label + '"></div>';
    });
    html += '</div>';

    container.innerHTML = html;

    // Swatch clicks
    var swatches = container.querySelectorAll('.color-swatch');
    swatches.forEach(function(sw) {
        sw.addEventListener('click', function() {
            var idx = parseInt(sw.dataset.index);

            // Update active state
            swatches.forEach(function(s) { s.classList.remove('active'); });
            sw.classList.add('active');

            // Send to client
            if (paintSubTab === 'primary') {
                vehicleData.primaryColor = idx;
                post('setPrimaryColor', { color: idx });
            } else if (paintSubTab === 'secondary') {
                vehicleData.secondaryColor = idx;
                post('setSecondaryColor', { color: idx });
            } else if (paintSubTab === 'pearlescent') {
                vehicleData.pearlescentColor = idx;
                post('setPearlescentColor', { color: idx });
            } else if (paintSubTab === 'wheel') {
                vehicleData.wheelColor = idx;
                post('setWheelColor', { color: idx });
            }
        });
    });
}

// ═══════════════════════════════════════════════════════════════
// RENDER — WHEELS
// ═══════════════════════════════════════════════════════════════

function renderWheels() {
    var html = '';

    // Wheel type grid
    html += '<div class="section-title">Type de roue</div>';
    html += '<div class="wheel-type-grid">';
    for (var key in wheelTypes) {
        if (wheelTypes.hasOwnProperty(key)) {
            var typeIndex = parseInt(key);
            var isActive = typeIndex === vehicleData.wheelType ? ' active' : '';
            html += '<div class="wheel-type-btn' + isActive + '" data-type="' + typeIndex + '">'
                 + wheelTypes[key] + '</div>';
        }
    }
    html += '</div>';

    // Wheel style list
    html += '<div class="section-title">Style de roue</div>';
    html += '<div class="option-list" id="wheel-style-list"></div>';

    mechContent.innerHTML = html;

    // Render wheel styles for current type
    renderWheelStyles();

    // Wheel type clicks
    var typeBtns = mechContent.querySelectorAll('.wheel-type-btn');
    typeBtns.forEach(function(btn) {
        btn.addEventListener('click', function() {
            var wt = parseInt(btn.dataset.type);
            vehicleData.wheelType = wt;

            typeBtns.forEach(function(b) { b.classList.remove('active'); });
            btn.classList.add('active');

            post('setWheelType', { wheelType: wt }).then(function(resp) {
                return resp.json();
            }).then(function(result) {
                if (result && result.numWheelMods !== undefined) {
                    vehicleData.numWheelMods = result.numWheelMods;
                }
                vehicleData.wheelMod = -1;
                renderWheelStyles();
            }).catch(function() {
                renderWheelStyles();
            });
        });
    });
}

function renderWheelStyles() {
    var list = document.getElementById('wheel-style-list');
    if (!list) return;

    var numMods = vehicleData.numWheelMods || 0;
    var html = '';

    // Stock option
    var stockActive = vehicleData.wheelMod === -1 ? ' active' : '';
    html += '<div class="option-item' + stockActive + '" data-wheel="-1">'
         + '<span class="option-label">Stock</span>'
         + '<span class="option-badge">Origine</span>'
         + '</div>';

    for (var i = 0; i < numMods; i++) {
        var isActive = vehicleData.wheelMod === i ? ' active' : '';
        html += '<div class="option-item' + isActive + '" data-wheel="' + i + '">'
             + '<span class="option-label">Roue #' + (i + 1) + '</span>'
             + '<span class="option-badge">Niv. ' + (i + 1) + '</span>'
             + '</div>';
    }

    list.innerHTML = html;

    // Clicks
    var items = list.querySelectorAll('.option-item');
    items.forEach(function(item) {
        item.addEventListener('click', function() {
            var idx = parseInt(item.dataset.wheel);
            vehicleData.wheelMod = idx;
            items.forEach(function(it) { it.classList.remove('active'); });
            item.classList.add('active');
            post('setWheelMod', { index: idx });
        });
    });
}

// ═══════════════════════════════════════════════════════════════
// RENDER — UPGRADE (generic for engine, brakes, transmission, armor, suspension)
// ═══════════════════════════════════════════════════════════════

function renderUpgrade(callbackName, modIndex, currentLevel, numLevels, title) {
    var html = '<div class="section-title">' + title + '</div>';
    html += '<div class="option-list">';

    var upgradeLabels = ['Stock', 'Niveau 1', 'Niveau 2', 'Niveau 3', 'Niveau 4', 'Niveau MAX'];

    // Stock = -1
    var stockActive = currentLevel === -1 ? ' active' : '';
    html += '<div class="option-item' + stockActive + '" data-level="-1">'
         + '<span class="option-label">Stock</span>'
         + '<span class="option-badge">Origine</span>'
         + '</div>';

    for (var i = 0; i < numLevels; i++) {
        var isActive = currentLevel === i ? ' active' : '';
        var label = upgradeLabels[i + 1] || ('Niveau ' + (i + 1));
        html += '<div class="option-item' + isActive + '" data-level="' + i + '">'
             + '<span class="option-label">' + label + '</span>'
             + '<span class="option-badge">+' + Math.round(((i + 1) / numLevels) * 100) + '%</span>'
             + '</div>';
    }

    html += '</div>';
    mechContent.innerHTML = html;

    // Map callback names to NUI callback
    var callbackMap = {
        'engine': 'setEngine',
        'brakes': 'setBrakes',
        'transmission': 'setTransmission',
        'armor': 'setArmor',
        'suspension': 'setSuspension'
    };
    var cbName = callbackMap[callbackName];

    // State keys for vehicleData
    var stateMap = {
        'engine': 'engineLevel',
        'brakes': 'brakesLevel',
        'transmission': 'transmissionLevel',
        'armor': 'armorLevel',
        'suspension': 'suspensionLevel'
    };
    var stateKey = stateMap[callbackName];

    var items = mechContent.querySelectorAll('.option-item');
    items.forEach(function(item) {
        item.addEventListener('click', function() {
            var level = parseInt(item.dataset.level);
            vehicleData[stateKey] = level;
            items.forEach(function(it) { it.classList.remove('active'); });
            item.classList.add('active');
            post(cbName, { level: level });
        });
    });
}

// ═══════════════════════════════════════════════════════════════
// RENDER — TURBO
// ═══════════════════════════════════════════════════════════════

function renderTurbo() {
    var isOn = vehicleData.turboEnabled;
    var html = '<div class="section-title">Turbo</div>';
    html += '<div class="toggle-row">';
    html += '<span class="toggle-label">Activer le turbo</span>';
    html += '<div class="toggle-switch' + (isOn ? ' active' : '') + '" id="turbo-toggle"></div>';
    html += '</div>';

    mechContent.innerHTML = html;

    var toggle = document.getElementById('turbo-toggle');
    toggle.addEventListener('click', function() {
        vehicleData.turboEnabled = !vehicleData.turboEnabled;
        toggle.classList.toggle('active', vehicleData.turboEnabled);
        post('setTurbo', { enabled: vehicleData.turboEnabled });
    });
}

// ═══════════════════════════════════════════════════════════════
// RENDER — LIVERY
// ═══════════════════════════════════════════════════════════════

function renderLivery() {
    var numLiveries = vehicleData.numLiveries || 0;
    var html = '<div class="section-title">Livrée</div>';

    if (numLiveries <= 0) {
        html += '<div class="empty-state">Aucune livrée disponible pour ce véhicule</div>';
        mechContent.innerHTML = html;
        return;
    }

    html += '<div class="option-list">';

    // None
    var noneActive = vehicleData.livery === -1 ? ' active' : '';
    html += '<div class="option-item' + noneActive + '" data-livery="-1">'
         + '<span class="option-label">Aucune</span>'
         + '<span class="option-badge">Stock</span>'
         + '</div>';

    for (var i = 0; i < numLiveries; i++) {
        var isActive = vehicleData.livery === i ? ' active' : '';
        html += '<div class="option-item' + isActive + '" data-livery="' + i + '">'
             + '<span class="option-label">Livrée #' + (i + 1) + '</span>'
             + '<span class="option-badge">' + (i + 1) + '/' + numLiveries + '</span>'
             + '</div>';
    }

    html += '</div>';
    mechContent.innerHTML = html;

    var items = mechContent.querySelectorAll('.option-item');
    items.forEach(function(item) {
        item.addEventListener('click', function() {
            var idx = parseInt(item.dataset.livery);
            vehicleData.livery = idx;
            items.forEach(function(it) { it.classList.remove('active'); });
            item.classList.add('active');
            post('setLivery', { index: idx });
        });
    });
}

// ═══════════════════════════════════════════════════════════════
// RENDER — NEON
// ═══════════════════════════════════════════════════════════════

function renderNeon() {
    var positions = [
        { index: 0, label: 'Avant' },
        { index: 1, label: 'Arrière' },
        { index: 2, label: 'Gauche' },
        { index: 3, label: 'Droite' }
    ];

    var html = '<div class="section-title">Positions néon</div>';
    html += '<div class="neon-positions">';
    positions.forEach(function(pos) {
        var isOn = vehicleData.neonEnabled && vehicleData.neonEnabled[String(pos.index)];
        var activeClass = isOn ? ' active' : '';
        html += '<div class="neon-pos-btn' + activeClass + '" data-pos="' + pos.index + '">'
             + pos.label + '</div>';
    });
    html += '</div>';

    // Color picker
    var nr = vehicleData.neonR || 255;
    var ng = vehicleData.neonG || 255;
    var nb = vehicleData.neonB || 255;

    html += '<div class="section-title">Couleur néon</div>';
    html += '<div class="color-picker-row">';
    html += '<div class="color-preview" id="neon-preview" style="background:rgb(' + nr + ',' + ng + ',' + nb + ')"></div>';
    html += '<div class="color-input-group">';
    html += '<label>R</label><input type="number" id="neon-r" min="0" max="255" value="' + nr + '">';
    html += '<label>G</label><input type="number" id="neon-g" min="0" max="255" value="' + ng + '">';
    html += '<label>B</label><input type="number" id="neon-b" min="0" max="255" value="' + nb + '">';
    html += '</div>';
    html += '<button class="btn-apply-color" id="btn-neon-apply">APPLIQUER</button>';
    html += '</div>';

    // Quick color presets
    html += '<div class="section-title">Préréglages</div>';
    html += '<div class="color-grid" style="grid-template-columns: repeat(10, 1fr); gap: 4px;">';
    var presets = [
        { r: 255, g: 0,   b: 0 },
        { r: 255, g: 50,  b: 0 },
        { r: 255, g: 150, b: 0 },
        { r: 255, g: 255, b: 0 },
        { r: 0,   g: 255, b: 0 },
        { r: 0,   g: 255, b: 255 },
        { r: 0,   g: 100, b: 255 },
        { r: 0,   g: 0,   b: 255 },
        { r: 150, g: 0,   b: 255 },
        { r: 255, g: 0,   b: 255 },
        { r: 255, g: 255, b: 255 },
        { r: 255, g: 100, b: 100 },
        { r: 255, g: 200, b: 100 },
        { r: 200, g: 255, b: 100 },
        { r: 100, g: 255, b: 100 },
        { r: 100, g: 255, b: 200 },
        { r: 100, g: 200, b: 255 },
        { r: 100, g: 100, b: 255 },
        { r: 200, g: 100, b: 255 },
        { r: 255, g: 100, b: 200 },
    ];
    presets.forEach(function(p) {
        html += '<div class="color-swatch" data-r="' + p.r + '" data-g="' + p.g + '" data-b="' + p.b + '" '
             + 'style="background:rgb(' + p.r + ',' + p.g + ',' + p.b + ')"></div>';
    });
    html += '</div>';

    mechContent.innerHTML = html;

    // Position toggles
    var posBtns = mechContent.querySelectorAll('.neon-pos-btn');
    posBtns.forEach(function(btn) {
        btn.addEventListener('click', function() {
            var pos = parseInt(btn.dataset.pos);
            var isActive = btn.classList.contains('active');
            btn.classList.toggle('active', !isActive);

            if (!vehicleData.neonEnabled) vehicleData.neonEnabled = {};
            vehicleData.neonEnabled[String(pos)] = !isActive;

            post('setNeonEnabled', { position: pos, enabled: !isActive });
        });
    });

    // Color inputs
    var rInput = document.getElementById('neon-r');
    var gInput = document.getElementById('neon-g');
    var bInput = document.getElementById('neon-b');
    var preview = document.getElementById('neon-preview');

    function updateNeonPreview() {
        var r = clampColor(parseInt(rInput.value) || 0);
        var g = clampColor(parseInt(gInput.value) || 0);
        var b = clampColor(parseInt(bInput.value) || 0);
        preview.style.background = 'rgb(' + r + ',' + g + ',' + b + ')';
    }

    rInput.addEventListener('input', updateNeonPreview);
    gInput.addEventListener('input', updateNeonPreview);
    bInput.addEventListener('input', updateNeonPreview);

    // Apply button
    document.getElementById('btn-neon-apply').addEventListener('click', function() {
        var r = clampColor(parseInt(rInput.value) || 0);
        var g = clampColor(parseInt(gInput.value) || 0);
        var b = clampColor(parseInt(bInput.value) || 0);
        vehicleData.neonR = r;
        vehicleData.neonG = g;
        vehicleData.neonB = b;
        post('setNeonColor', { r: r, g: g, b: b });
    });

    // Preset clicks
    var presetSwatches = mechContent.querySelectorAll('.color-grid .color-swatch');
    presetSwatches.forEach(function(sw) {
        sw.addEventListener('click', function() {
            var r = parseInt(sw.dataset.r);
            var g = parseInt(sw.dataset.g);
            var b = parseInt(sw.dataset.b);
            rInput.value = r;
            gInput.value = g;
            bInput.value = b;
            updateNeonPreview();
            vehicleData.neonR = r;
            vehicleData.neonG = g;
            vehicleData.neonB = b;
            post('setNeonColor', { r: r, g: g, b: b });
        });
    });
}

function clampColor(val) {
    return Math.max(0, Math.min(255, val));
}

// ═══════════════════════════════════════════════════════════════
// RENDER — WINDOW TINT
// ═══════════════════════════════════════════════════════════════

function renderWindowTint() {
    var html = '<div class="section-title">Teinte des vitres</div>';
    html += '<div class="option-list">';

    windowTints.forEach(function(t) {
        var isActive = vehicleData.windowTint === t.index ? ' active' : '';
        html += '<div class="option-item' + isActive + '" data-tint="' + t.index + '">'
             + '<span class="option-label">' + t.label + '</span>'
             + '</div>';
    });

    html += '</div>';
    mechContent.innerHTML = html;

    var items = mechContent.querySelectorAll('.option-item');
    items.forEach(function(item) {
        item.addEventListener('click', function() {
            var idx = parseInt(item.dataset.tint);
            vehicleData.windowTint = idx;
            items.forEach(function(it) { it.classList.remove('active'); });
            item.classList.add('active');
            post('setWindowTint', { index: idx });
        });
    });
}

// ═══════════════════════════════════════════════════════════════
// RENDER — XENON
// ═══════════════════════════════════════════════════════════════

function renderXenon() {
    var isOn = vehicleData.xenonEnabled;
    var html = '<div class="section-title">Phares Xenon</div>';

    // Toggle
    html += '<div class="toggle-row" style="margin-bottom:16px">';
    html += '<span class="toggle-label">Activer Xenon</span>';
    html += '<div class="toggle-switch' + (isOn ? ' active' : '') + '" id="xenon-toggle"></div>';
    html += '</div>';

    // Color list
    html += '<div class="section-title">Couleur Xenon</div>';
    html += '<div class="option-list" id="xenon-color-list">';

    xenonColors.forEach(function(xc) {
        var isActive = vehicleData.xenonColor === xc.index ? ' active' : '';
        html += '<div class="option-item' + isActive + '" data-xenon="' + xc.index + '">'
             + '<span class="option-label">' + xc.label + '</span>'
             + '</div>';
    });

    html += '</div>';
    mechContent.innerHTML = html;

    // Toggle click
    var toggle = document.getElementById('xenon-toggle');
    toggle.addEventListener('click', function() {
        vehicleData.xenonEnabled = !vehicleData.xenonEnabled;
        toggle.classList.toggle('active', vehicleData.xenonEnabled);
        post('setXenon', { enabled: vehicleData.xenonEnabled, color: vehicleData.xenonColor });
    });

    // Color clicks
    var colorItems = mechContent.querySelectorAll('#xenon-color-list .option-item');
    colorItems.forEach(function(item) {
        item.addEventListener('click', function() {
            var idx = parseInt(item.dataset.xenon);
            vehicleData.xenonColor = idx;
            colorItems.forEach(function(it) { it.classList.remove('active'); });
            item.classList.add('active');

            // Enable xenon automatically when choosing a color
            if (!vehicleData.xenonEnabled) {
                vehicleData.xenonEnabled = true;
                toggle.classList.add('active');
                post('setXenon', { enabled: true, color: idx });
            } else {
                post('setXenonColor', { color: idx });
            }
        });
    });
}

// ═══════════════════════════════════════════════════════════════
// RENDER — SPECIAL MODS (Apocalypse)
// ═══════════════════════════════════════════════════════════════

function renderSpecial() {
    if (!vehicleData.isApocalypse || !vehicleData.specialMods) {
        mechContent.innerHTML = '<div class="empty-state">Aucun mod spécial disponible</div>';
        return;
    }

    var html = '<div class="section-title">Mods Apocalypse</div>';
    var hasAnyMod = false;

    specialModsDef.forEach(function(sm) {
        var modData = vehicleData.specialMods[sm.id];
        var numMods = modData ? modData.numMods : 0;
        var currentVal = modData ? modData.current : -1;

        // Seuls les mods réellement disponibles sur ce véhicule
        if (numMods <= 0) return;
        hasAnyMod = true;

        html += '<div class="special-mod-group">';
        html += '<div class="special-mod-label">' + sm.label + '</div>';
        html += '<div class="segmented-group">';

        // Bouton "Aucun" toujours présent
        var noneActive = (currentVal === -1) ? ' active' : '';
        html += '<button class="segment-btn' + noneActive + '" '
             + 'data-mod-index="' + sm.modIndex + '" '
             + 'data-mod-id="' + sm.id + '" '
             + 'data-level="-1">Aucun</button>';

        // Niveaux disponibles (0 à numMods-1)
        for (var i = 0; i < numMods; i++) {
            var lvl = sm.levels[i + 1]; // index 0 dans levels = "Aucun", donc +1
            var label = lvl ? lvl.label : ('Option ' + (i + 1));
            var isActive = (currentVal === i) ? ' active' : '';
            html += '<button class="segment-btn' + isActive + '" '
                 + 'data-mod-index="' + sm.modIndex + '" '
                 + 'data-mod-id="' + sm.id + '" '
                 + 'data-level="' + i + '">'
                 + label + '</button>';
        }

        html += '</div>';
        html += '</div>';
    });

    if (!hasAnyMod) {
        mechContent.innerHTML = '<div class="empty-state">Ce véhicule n\'a pas de mods spéciaux disponibles</div>';
        return;
    }

    mechContent.innerHTML = html;

    // Segment clicks
    var segBtns = mechContent.querySelectorAll('.segment-btn');
    segBtns.forEach(function(btn) {
        btn.addEventListener('click', function() {
            var modIndex = parseInt(btn.dataset.modIndex);
            var modId = btn.dataset.modId;
            var level = parseInt(btn.dataset.level);

            var group = btn.parentElement;
            group.querySelectorAll('.segment-btn').forEach(function(b) {
                b.classList.remove('active');
            });
            btn.classList.add('active');

            if (vehicleData.specialMods[modId]) {
                vehicleData.specialMods[modId].current = level;
            }

            post('setSpecialMod', { modIndex: modIndex, level: level });
        });
    });
}

// ═══════════════════════════════════════════════════════════════
// MECHANIC BUTTONS
// ═══════════════════════════════════════════════════════════════

document.getElementById('btn-confirm-mech').addEventListener('click', function() {
    post('confirm');
    closeAll();
});

document.getElementById('btn-cancel-mech').addEventListener('click', function() {
    post('cancel');
    closeAll();
});

// ═══════════════════════════════════════════════════════════════
// GARAGE DEALER — Achat / Vente véhicules (design shop outposts)
// ═══════════════════════════════════════════════════════════════

function gdFmt(n) {
    return '$' + Number(n).toLocaleString('fr-FR');
}

function gdImgSrc(itemName) {
    // vehicle_zentorno → nui://pvp_inventory/html/img/zentorno.png
    var model = itemName.replace('vehicle_', '');
    return 'nui://pvp_inventory/html/img/' + model + '.png';
}

// Fallback affiché quand le PNG du modèle n'existe pas encore dans
// pvp_inventory/html/img/ — silhouette monochrome (thème VANTA) plutôt qu'un emoji.
var GD_VEH_SVG =
    '<svg viewBox="0 0 48 48" width="40" height="40" fill="none" stroke="currentColor"'
  + ' stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
  + '<path d="M5 29l3.2-9A5 5 0 0 1 13 17h16a5 5 0 0 1 4 2l4.6 6 4.2 1.4A3 3 0 0 1 44 29v4a2 2 0 0 1-2 2h-3"/>'
  + '<path d="M15 35h16"/><circle cx="11" cy="35" r="3.4"/><circle cx="35" cy="35" r="3.4"/>'
  + '<path d="M5 29h5m22-6H17"/></svg>';

function gdBuildImg(itemName, cls) {
    return '<img class="' + cls + '-img" src="' + gdImgSrc(itemName) + '" alt=""'
         + ' onerror="this.style.display=\'none\';this.nextElementSibling.style.display=\'flex\'"/>'
         + '<div class="' + cls + '-ico" style="display:none">' + GD_VEH_SVG + '</div>';
}

// ── Toast ─────────────────────────────────────────────────────

var gdToastTimer = null;
function gdToast(msg, type) {
    var el = document.getElementById('gd-toast');
    el.textContent = msg;
    el.className = 'show ' + (type || 'ok');
    if (gdToastTimer) clearTimeout(gdToastTimer);
    gdToastTimer = setTimeout(function() { el.className = ''; }, 3000);
}

// ── Panier ────────────────────────────────────────────────────

function gdCartTotal() {
    return Object.values(gdCart).reduce(function(s, c) { return s + c.price * c.qty; }, 0);
}

function gdAddToCart(item) {
    if (gdCart[item.item]) {
        gdCart[item.item].qty++;
    } else {
        gdCart[item.item] = { item: item.item, label: item.label, price: item.price, qty: 1 };
    }
    gdRenderCart();
    gdRenderBuyGrid();
}

function gdRemoveFromCart(itemName) {
    delete gdCart[itemName];
    gdRenderCart();
    gdRenderBuyGrid();
}

function gdRenderCart() {
    var list  = document.getElementById('gd-cart-items');
    var empty = document.getElementById('gd-cart-empty');
    var total = document.getElementById('gd-cart-total');
    var btnB  = document.getElementById('gd-btn-buy');
    var btnS  = document.getElementById('gd-btn-stash');
    var entries = Object.values(gdCart);

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
    total.textContent = gdFmt(gdCartTotal());

    list.innerHTML = '';
    entries.forEach(function(ci) {
        var row = document.createElement('div');
        row.className = 'gd-cart-row';
        row.innerHTML = gdBuildImg(ci.item, 'gd-cart-row')
            + '<div class="gd-cart-row-info">'
            + '<div class="gd-cart-row-name">' + ci.label + '</div>'
            + '<div class="gd-cart-row-sub">' + gdFmt(ci.price) + ' / unité &nbsp;·&nbsp; x' + ci.qty + '</div>'
            + '</div>'
            + '<div class="gd-cart-rm" data-item="' + ci.item + '">&#10005;</div>';
        list.appendChild(row);
    });

    list.querySelectorAll('.gd-cart-rm').forEach(function(btn) {
        btn.addEventListener('click', function() { gdRemoveFromCart(btn.dataset.item); });
    });
}

// ── Filtre catégorie ──────────────────────────────────────────

function gdBuildFilterOptions(items, keyFn) {
    var cats = [];
    var seen = {};
    items.forEach(function(i) {
        var k = keyFn(i);
        if (!seen[k]) { seen[k] = true; cats.push(k); }
    });
    cats.sort();
    var sel = document.getElementById('gd-filter');
    sel.innerHTML = '<option value="">Tous</option>';
    cats.forEach(function(c) {
        var o = document.createElement('option');
        o.value = c; o.textContent = c;
        sel.appendChild(o);
    });
}

// ── Grille Acheter ────────────────────────────────────────────

function gdRenderBuyGrid() {
    var grid = document.getElementById('gd-buy-grid');
    grid.innerHTML = '';

    var filtered = gdVehicles.filter(function(v) {
        var ms = !gdSrch || v.label.toLowerCase().includes(gdSrch) || v.model.toLowerCase().includes(gdSrch);
        var mf = !gdFilter || v.category === gdFilter;
        return ms && mf;
    });

    if (!filtered.length) {
        grid.innerHTML = '<div class="gd-grid-empty">AUCUN VÉHICULE TROUVÉ</div>';
        return;
    }

    filtered.forEach(function(v) {
        var itemName = 'vehicle_' + v.model;
        var inCart = !!gdCart[itemName];
        var card = document.createElement('div');
        card.className = 'gd-card';

        var vJson = encodeURIComponent(JSON.stringify({ item: itemName, label: v.label, price: v.price }));
        card.innerHTML = gdBuildImg(itemName, 'gd-card')
            + '<div class="gd-card-name">' + v.label + '</div>'
            + '<div class="gd-card-cat">' + v.category + '</div>'
            + '<div class="gd-card-price">' + gdFmt(v.price) + '</div>'
            + '<button class="gd-card-btn' + (inCart ? ' added' : '') + '" data-v="' + vJson + '">'
            + (inCart ? '+ Ajouter' : 'Acheter') + '</button>';

        card.querySelector('.gd-card-btn').addEventListener('click', function(e) {
            e.stopPropagation();
            gdAddToCart(JSON.parse(decodeURIComponent(this.dataset.v)));
        });

        grid.appendChild(card);
    });
}

// ── Grille Vendre ─────────────────────────────────────────────

function gdRenderSellGrid() {
    var grid = document.getElementById('gd-sell-grid');
    grid.innerHTML = '';

    // Bouton "Vendre tout" actif seulement si au moins 1 item
    document.getElementById('gd-btn-sell-all').disabled = gdSellItems.length === 0;

    var filtered = gdSellItems.filter(function(i) {
        var ms = !gdSrch || i.label.toLowerCase().includes(gdSrch) || i.name.toLowerCase().includes(gdSrch);
        var mf = !gdFilter || i.category === gdFilter;
        return ms && mf;
    });

    if (!filtered.length) {
        grid.innerHTML = '<div class="gd-grid-empty">' + (gdSellItems.length === 0 ? 'AUCUN VÉHICULE À VENDRE' : 'AUCUN RÉSULTAT') + '</div>';
        return;
    }

    filtered.forEach(function(item) {
        // Le Lua envoie sellPrice (override / prix·2) — item.price n'existe pas ici.
        var sellPrice = (item.sellPrice != null)
            ? item.sellPrice
            : Math.floor((item.price || 0) * 0.5);
        var isSel = gdSellSel && gdSellSel.name === item.name;
        var card = document.createElement('div');
        card.className = 'gd-card' + (isSel ? ' gd-card-sell-selected' : '');
        card.innerHTML = gdBuildImg(item.name, 'gd-card')
            + '<div class="gd-card-name">' + item.label + '</div>'
            + '<div class="gd-card-qty-badge">x' + item.count + '</div>'
            + '<div class="gd-card-sell-price">' + gdFmt(sellPrice) + '</div>'
            + '<button class="gd-card-btn sell-btn' + (isSel ? ' selected-btn' : '') + '">'
            + (isSel ? 'Sélectionné' : 'Vendre') + '</button>';

        card.querySelector('.gd-card-btn').addEventListener('click', function(e) {
            e.stopPropagation();
            gdSelectSellItem(item, sellPrice);
        });

        grid.appendChild(card);
    });
}

function gdSelectSellItem(item, sellPrice) {
    gdSellSel = { name: item.name, label: item.label, count: item.count, sellPrice: sellPrice };

    document.getElementById('gd-sell-hint').style.display = 'none';
    var detail = document.getElementById('gd-sell-detail');
    detail.style.display = 'flex';

    var sellWrap = document.getElementById('gd-sell-img-wrap');
    sellWrap.innerHTML = '<img src="' + gdImgSrc(item.name) + '" alt=""'
        + ' style="width:72px;height:72px;object-fit:contain"/>';
    sellWrap.firstChild.onerror = function() {
        sellWrap.innerHTML = '<div style="color:var(--gd-text-dim)">' + GD_VEH_SVG + '</div>';
    };
    document.getElementById('gd-sell-item-name').textContent  = item.label;
    document.getElementById('gd-sell-item-price').textContent = gdFmt(sellPrice);
    document.getElementById('gd-sell-total').textContent      = gdFmt(sellPrice);
    document.getElementById('gd-btn-sell-confirm').disabled   = false;

    gdRenderSellGrid();
}

// ── Mode (buy / sell) ─────────────────────────────────────────

function gdSetMode(newMode) {
    gdMode   = newMode;
    gdSrch   = '';
    gdFilter = '';
    document.getElementById('gd-search').value = '';
    document.getElementById('gd-filter').value = '';

    document.querySelectorAll('.gd-tab').forEach(function(t) {
        t.classList.toggle('active', t.dataset.mode === gdMode);
    });

    if (gdMode === 'buy') {
        document.getElementById('gd-buy-grid').style.display  = 'grid';
        document.getElementById('gd-sell-grid').style.display = 'none';
        document.getElementById('gd-buy-panel').style.display  = 'flex';
        document.getElementById('gd-sell-panel').style.display = 'none';
        gdBuildFilterOptions(gdVehicles, function(v) { return v.category; });
        gdRenderBuyGrid();
        gdRenderCart();
    } else {
        document.getElementById('gd-buy-grid').style.display  = 'none';
        document.getElementById('gd-sell-grid').style.display = 'grid';
        document.getElementById('gd-buy-panel').style.display  = 'none';
        document.getElementById('gd-sell-panel').style.display = 'flex';
        gdSellSel = null;
        document.getElementById('gd-sell-hint').style.display   = 'block';
        document.getElementById('gd-sell-detail').style.display = 'none';
        document.getElementById('gd-btn-sell-confirm').disabled = true;
        document.getElementById('gd-sell-total').textContent    = '$0';
        gdBuildFilterOptions(gdSellItems, function(i) { return i.category || 'Véhicule'; });
        gdRenderSellGrid();
    }
}

// ── NUI fetch ─────────────────────────────────────────────────

function gdFetch(action, data) {
    return fetch('https://pvp_garage/' + action, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {})
    }).then(function(r) { return r.json(); });
}

// ── Achat panier ──────────────────────────────────────────────

function gdDoBuy(destination) {
    var entries = Object.values(gdCart);
    if (!entries.length) return;

    document.getElementById('gd-btn-buy').disabled   = true;
    document.getElementById('gd-btn-stash').disabled = true;

    // Convertit le format panier → format attendu par le Lua (name / count)
    var payload = entries.map(function(ci) {
        return { name: ci.item, label: ci.label, price: ci.price, count: ci.qty };
    });

    gdFetch('buyVehicleCart', { items: payload, destination: destination })
        .then(function(resp) {
            if (resp.success) {
                gdClose();
            } else {
                gdToast(resp.message || 'Achat refusé.', 'fail');
                document.getElementById('gd-btn-buy').disabled   = false;
                document.getElementById('gd-btn-stash').disabled = false;
                gdRenderCart();
            }
        })
        .catch(function() {
            gdToast('Erreur de connexion.', 'fail');
            document.getElementById('gd-btn-buy').disabled   = false;
            document.getElementById('gd-btn-stash').disabled = false;
            gdRenderCart();
        });
}

// ── Vendre tout ───────────────────────────────────────────────

function gdDoSellAll() {
    if (!gdSellItems.length) return;

    var btn = document.getElementById('gd-btn-sell-all');
    var btnSingle = document.getElementById('gd-btn-sell-confirm');
    btn.disabled = true;
    btnSingle.disabled = true;

    // Vend en séquence : un item à la fois (pour éviter les race conditions ESX)
    var items = gdSellItems.slice(); // copie
    var totalEarned = 0;
    var lastBalance = gdBalance;

    function sellNext(i) {
        if (i >= items.length) {
            gdSellItems = [];
            gdSellSel = null;
            document.getElementById('gd-sell-hint').style.display   = 'block';
            document.getElementById('gd-sell-detail').style.display = 'none';
            document.getElementById('gd-sell-total').textContent    = '$0';
            gdRenderSellGrid();
            gdClose();
            return;
        }
        var item = items[i];
        var count = item.count || 1;
        var sellPrice = (item.sellPrice != null)
            ? item.sellPrice
            : Math.floor((item.price || 0) * 0.5);

        // Vend toutes les copies de cet item
        (function sellOne(remaining) {
            if (remaining <= 0) { sellNext(i + 1); return; }
            gdFetch('sellVehicleItem', { item: item.name })
                .then(function(resp) {
                    if (resp.success) {
                        totalEarned += resp.sellPrice || sellPrice;
                        if (typeof resp.balance === 'number') lastBalance = resp.balance;
                    }
                    sellOne(remaining - 1);
                })
                .catch(function() { sellNext(i + 1); });
        })(count);
    }

    sellNext(0);
}

// ── Vente ─────────────────────────────────────────────────────

function gdDoSell() {
    if (!gdSellSel) return;
    document.getElementById('gd-btn-sell-confirm').disabled = true;

    gdFetch('sellVehicleItem', { item: gdSellSel.name, sellPrice: gdSellSel.sellPrice })
        .then(function(resp) {
            if (resp.success) {
                gdToast('Véhicule vendu !', 'ok');
                if (typeof resp.balance === 'number') {
                    gdBalance = resp.balance;
                    document.getElementById('gd-balance').textContent = 'Solde : ' + gdFmt(gdBalance);
                }
                // Mise à jour locale de la liste
                var idx = gdSellItems.findIndex(function(i) { return i.name === gdSellSel.name; });
                if (idx >= 0) {
                    gdSellItems[idx].count--;
                    if (gdSellItems[idx].count <= 0) gdSellItems.splice(idx, 1);
                }
                gdSellSel = null;
                document.getElementById('gd-sell-hint').style.display   = 'block';
                document.getElementById('gd-sell-detail').style.display = 'none';
                document.getElementById('gd-btn-sell-confirm').disabled = true;
                document.getElementById('gd-sell-total').textContent    = '$0';
                gdRenderSellGrid();
            } else {
                gdToast(resp.message || 'Erreur vente.', 'fail');
                document.getElementById('gd-btn-sell-confirm').disabled = false;
            }
        })
        .catch(function() {
            gdToast('Erreur de connexion.', 'fail');
            document.getElementById('gd-btn-sell-confirm').disabled = false;
        });
}

// ── Fermer ────────────────────────────────────────────────────

function gdClose() {
    var gd = document.getElementById('garage-dealer');
    gd.classList.remove('open');
    gd.style.display = 'none';
    post('close');
    currentMode = null;
    gdCart    = {};
    gdSellSel = null;
}

// ── Ouvrir ────────────────────────────────────────────────────

function gdOpenDealer() {
    mechanicPanel.classList.add('hidden');

    document.getElementById('gd-balance').textContent = 'Solde : ' + gdFmt(gdBalance);

    // Reset
    gdCart    = {};
    gdSellSel = null;
    gdSrch    = '';
    gdFilter  = '';
    document.getElementById('gd-search').value = '';
    document.getElementById('gd-filter').value = '';
    document.getElementById('gd-sell-hint').style.display   = 'block';
    document.getElementById('gd-sell-detail').style.display = 'none';
    document.getElementById('gd-btn-sell-confirm').disabled = true;
    document.getElementById('gd-sell-total').textContent    = '$0';

    // Force mode buy
    gdMode = 'buy';
    document.getElementById('gd-buy-grid').style.display  = 'grid';
    document.getElementById('gd-sell-grid').style.display = 'none';
    document.getElementById('gd-buy-panel').style.display  = 'flex';
    document.getElementById('gd-sell-panel').style.display = 'none';
    document.querySelectorAll('.gd-tab').forEach(function(t) {
        t.classList.toggle('active', t.dataset.mode === 'buy');
    });

    gdBuildFilterOptions(gdVehicles, function(v) { return v.category; });
    gdRenderBuyGrid();
    gdRenderCart();

    var gd = document.getElementById('garage-dealer');
    gd.style.display = 'flex';
    gd.classList.add('open');
}

// ── Listeners ─────────────────────────────────────────────────

document.querySelectorAll('.gd-tab').forEach(function(btn) {
    btn.addEventListener('click', function() { gdSetMode(btn.dataset.mode); });
});

document.getElementById('gd-search').addEventListener('input', function() {
    gdSrch = this.value.toLowerCase();
    if (gdMode === 'buy') gdRenderBuyGrid(); else gdRenderSellGrid();
});

document.getElementById('gd-filter').addEventListener('change', function() {
    gdFilter = this.value;
    if (gdMode === 'buy') gdRenderBuyGrid(); else gdRenderSellGrid();
});

document.getElementById('gd-btn-buy').addEventListener('click',
    function() { gdDoBuy('bag'); });

document.getElementById('gd-btn-stash').addEventListener('click',
    function() { gdDoBuy('stash'); });

document.getElementById('gd-btn-sell-confirm').addEventListener('click', gdDoSell);
document.getElementById('gd-btn-sell-all').addEventListener('click', gdDoSellAll);

document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && currentMode === 'dealer') gdClose();
});
