// ═══════════════════════════════════════════════════════════
//  TELEPORT MAP — NUI (with zoom & pan)
// ═══════════════════════════════════════════════════════════

let outposts = [];
let selectedOutpost = null;
let currentOutpostId = null;

// ── GTA V world bounds matching the satellite map image ────
const MAP_MIN_X = -3700;
const MAP_MAX_X = 4500;
const MAP_MIN_Y = -4300;
const MAP_MAX_Y = 8400;
const MAP_WIDTH  = MAP_MAX_X - MAP_MIN_X;
const MAP_HEIGHT = MAP_MAX_Y - MAP_MIN_Y;

// ── Zoom & Pan state ──────────────────────────────────────
let zoom = 1;
const ZOOM_MIN = 1;
const ZOOM_MAX = 5;
const ZOOM_STEP = 0.3;
let panX = 0;  // in pixels
let panY = 0;
let isDragging = false;
let dragStartX = 0;
let dragStartY = 0;
let panStartX = 0;
let panStartY = 0;

function applyTransform() {
    const inner = document.getElementById('mapInner');
    if (!inner) return;
    inner.style.transform = `translate(${panX}px, ${panY}px) scale(${zoom})`;
}

function clampPan() {
    const mapArea = document.getElementById('mapArea');
    if (!mapArea) return;
    const areaW = mapArea.clientWidth;
    const areaH = mapArea.clientHeight;

    // Max pan = how much the scaled content exceeds the container
    const maxPanX = Math.max(0, (areaW * zoom - areaW) / 2);
    const maxPanY = Math.max(0, (areaH * zoom - areaH) / 2);

    panX = Math.max(-maxPanX, Math.min(maxPanX, panX));
    panY = Math.max(-maxPanY, Math.min(maxPanY, panY));
}

function resetZoom() {
    zoom = 1;
    panX = 0;
    panY = 0;
    applyTransform();
}

// ── Image rect cache ──────────────────────────────────────
let imgRect = { left: 0, top: 0, width: 1, height: 1 };

function calcImageRect() {
    const mapArea = document.getElementById('mapArea');
    const areaW = mapArea.clientWidth;
    const areaH = mapArea.clientHeight;

    const imgRatio = 736 / 1074;
    const areaRatio = areaW / areaH;

    let displayW, displayH;
    if (areaRatio > imgRatio) {
        displayH = areaH;
        displayW = areaH * imgRatio;
    } else {
        displayW = areaW;
        displayH = areaW / imgRatio;
    }

    const offsetX = (areaW - displayW) / 2;
    const offsetY = (areaH - displayH) / 2;

    imgRect = { left: offsetX, top: offsetY, width: displayW, height: displayH };
}

function worldToMap(x, y) {
    const pctX = (x - MAP_MIN_X) / MAP_WIDTH;
    const pctY = 1 - (y - MAP_MIN_Y) / MAP_HEIGHT;

    const pixelX = imgRect.left + pctX * imgRect.width;
    const pixelY = imgRect.top  + pctY * imgRect.height;

    const mapArea = document.getElementById('mapArea');
    const leftPct = (pixelX / mapArea.clientWidth) * 100;
    const topPct  = (pixelY / mapArea.clientHeight) * 100;

    return {
        left: Math.max(1, Math.min(99, leftPct)) + '%',
        top:  Math.max(1, Math.min(99, topPct)) + '%'
    };
}

// ── Build outpost pins on the map ─────────────────────────
function buildMap(data) {
    outposts = data.outposts || [];
    currentOutpostId = data.currentOutpostId || null;
    selectedOutpost = null;

    const mapInner = document.getElementById('mapInner');
    if (!mapInner) return;

    // Remove old pins
    mapInner.querySelectorAll('.outpost-pin').forEach(el => el.remove());

    // Reset zoom
    resetZoom();

    // Calculate image rect based on mapInner size (= mapArea size at zoom 1)
    calcImageRect();

    // Create pins inside mapInner (they will zoom/pan with it)
    outposts.forEach(op => {
        const pos = worldToMap(op.x, op.y);
        const pin = document.createElement('div');
        pin.className = 'outpost-pin';
        if (op.id === currentOutpostId) {
            pin.classList.add('current');
        }
        pin.style.left = pos.left;
        pin.style.top = pos.top;
        pin.dataset.id = op.id;

        pin.innerHTML = `
            <div class="pin-label">${op.label}</div>
            <div class="pin-dot"></div>
        `;

        pin.addEventListener('click', (e) => {
            e.stopPropagation();
            selectOutpost(op, pin);
        });
        mapInner.appendChild(pin);
    });

    updateInfoPanel(null);
    document.getElementById('btnTeleport').disabled = true;
}

// ── Select an outpost ─────────────────────────────────────
function selectOutpost(op, pinEl) {
    if (op.id === currentOutpostId) return;

    document.querySelectorAll('.outpost-pin.selected').forEach(el => el.classList.remove('selected'));

    pinEl.classList.add('selected');
    selectedOutpost = op;

    updateInfoPanel(op);
    document.getElementById('btnTeleport').disabled = false;
}

// ── Update info panel ─────────────────────────────────────
function updateInfoPanel(op) {
    const panel = document.getElementById('infoPanel');
    if (!op) {
        panel.innerHTML = '<div class="info-empty">Cliquez sur un avant-poste pour le sélectionner</div>';
        return;
    }

    const typeLabel = 'Avant-poste';
    const services = '<span>Armes</span><span>Objets</span><span>Véhicules</span><span>Custom</span>';

    panel.innerHTML = `
        <div class="info-content">
            <div class="info-name">${op.label}</div>
            <div class="info-type">${typeLabel}</div>
            <div class="info-services">${services}</div>
        </div>
    `;
}

// ── Zoom (mouse wheel) ───────────────────────────────────
function initZoomPan() {
    const mapArea = document.getElementById('mapArea');
    if (!mapArea) return;

    // Scroll to zoom
    mapArea.addEventListener('wheel', (e) => {
        e.preventDefault();
        const oldZoom = zoom;

        if (e.deltaY < 0) {
            zoom = Math.min(ZOOM_MAX, zoom + ZOOM_STEP);
        } else {
            zoom = Math.max(ZOOM_MIN, zoom - ZOOM_STEP);
        }

        // If back to zoom 1, reset pan
        if (zoom <= 1) {
            zoom = 1;
            panX = 0;
            panY = 0;
        } else {
            // Adjust pan to zoom towards mouse position
            const rect = mapArea.getBoundingClientRect();
            const mouseX = e.clientX - rect.left - rect.width / 2;
            const mouseY = e.clientY - rect.top - rect.height / 2;
            const scale = zoom / oldZoom;
            panX = mouseX - scale * (mouseX - panX);
            panY = mouseY - scale * (mouseY - panY);
            clampPan();
        }

        applyTransform();
    }, { passive: false });

    // Drag to pan
    mapArea.addEventListener('mousedown', (e) => {
        if (zoom <= 1) return;
        if (e.target.closest('.outpost-pin')) return; // don't drag when clicking pins
        isDragging = true;
        dragStartX = e.clientX;
        dragStartY = e.clientY;
        panStartX = panX;
        panStartY = panY;
        mapArea.style.cursor = 'grabbing';
        e.preventDefault();
    });

    window.addEventListener('mousemove', (e) => {
        if (!isDragging) return;
        panX = panStartX + (e.clientX - dragStartX);
        panY = panStartY + (e.clientY - dragStartY);
        clampPan();
        applyTransform();
    });

    window.addEventListener('mouseup', () => {
        if (isDragging) {
            isDragging = false;
            const mapArea = document.getElementById('mapArea');
            if (mapArea) mapArea.style.cursor = zoom > 1 ? 'grab' : 'default';
        }
    });
}

// Init zoom/pan once DOM is ready
initZoomPan();

// ── Buttons ───────────────────────────────────────────────
document.getElementById('btnTeleport').addEventListener('click', () => {
    if (!selectedOutpost) return;
    fetch(`https://${GetParentResourceName()}/teleportTo`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ outpostId: selectedOutpost.id })
    });
    closeMap();
});

document.getElementById('btnClose').addEventListener('click', () => {
    fetch(`https://${GetParentResourceName()}/closeTeleportMap`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
    closeMap();
});

function closeMap() {
    document.getElementById('teleport-overlay').classList.add('hidden');
    selectedOutpost = null;
    resetZoom();
}

// ── Escape key ────────────────────────────────────────────
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        const overlay = document.getElementById('teleport-overlay');
        if (!overlay.classList.contains('hidden')) {
            fetch(`https://${GetParentResourceName()}/closeTeleportMap`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            });
            closeMap();
        }
    }
});

// ── NUI Message Handler ───────────────────────────────────
window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'openTeleportMap') {
        document.getElementById('teleport-overlay').classList.remove('hidden');
        buildMap(data);
    }

    if (data.action === 'closeTeleportMap') {
        closeMap();
    }
});
