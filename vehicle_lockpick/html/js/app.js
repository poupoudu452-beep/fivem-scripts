// ============================================================
//  VEHICLE LOCKPICK + HOTWIRE — NUI MINIGAMES
// ============================================================

// ─────────────────────────────────────────────────────────────
//  LOCKPICK STATE (systeme de goupilles)
// ─────────────────────────────────────────────────────────────
var lockpickState = {
    active: false,
    pinCount: 7,
    pins: [],           // { currentHeight, targetHeight, locked, tolerance }
    selectedPin: 0,
    scrollSpeed: 3,
    fallTimer: null,
    fallInterval: null,
};

// ─────────────────────────────────────────────────────────────
//  HOTWIRE STATE
// ─────────────────────────────────────────────────────────────
var hotwireState = {
    active: false,
    wireCount: 4,
    selectedLeft: null,
    connections: {},
    correctPairs: {},
    leftColors: [],
    rightColors: [],
    connectedCount: 0,
};

// ─────────────────────────────────────────────────────────────
//  LOADING STATE
// ─────────────────────────────────────────────────────────────
var loadingState = {
    active: false,
    duration: 5000,
    startTime: 0,
    animFrame: null,
};

var WIRE_COLORS = [
    { name: 'red',    hex: '#e74c3c', symbol: '\u25CF' },
    { name: 'blue',   hex: '#3498db', symbol: '\u2715' },
    { name: 'yellow', hex: '#f1c40f', symbol: '\u25B3' },
    { name: 'green',  hex: '#2ecc71', symbol: '\u25A0' },
    { name: 'pink',   hex: '#e91e90', symbol: '\u25C6' },
    { name: 'orange', hex: '#e67e22', symbol: '\u2605' },
];

// ═════════════════════════════════════════════════════════════
//  NUI MESSAGE HANDLER
// ═════════════════════════════════════════════════════════════
window.addEventListener('message', function(event) {
    var msg = event.data;

    // --- LOCKPICK ---
    if (msg.action === 'open') {
        lockpickState.pinCount = msg.pinCount || 7;
        lockpickState.active   = true;
        lockpickState.selectedPin = 0;

        document.getElementById('lockpick-container').classList.remove('hidden');
        document.getElementById('lockpick-container').classList.remove('closing');

        initPins();
        startPinFall();
    }

    if (msg.action === 'close') {
        closeLockpick();
    }

    // --- HOTWIRE ---
    if (msg.action === 'open_hotwire') {
        hotwireState.wireCount = msg.wireCount || 4;
        hotwireState.active = true;
        hotwireState.selectedLeft = null;
        hotwireState.connections = {};
        hotwireState.connectedCount = 0;

        document.getElementById('hotwire-container').classList.remove('hidden');
        document.getElementById('hotwire-container').classList.remove('closing');

        initHotwire();
    }

    // --- LOADING BAR ---
    if (msg.action === 'open_loading') {
        loadingState.duration  = msg.duration || 5000;
        loadingState.active    = true;
        loadingState.startTime = performance.now();

        var textEl = document.getElementById('loading-text');
        if (msg.text) textEl.textContent = msg.text;

        document.getElementById('loading-container').classList.remove('hidden');
        document.getElementById('loading-bar-fill').style.width = '0%';
        document.getElementById('loading-percent').textContent = '0%';

        startLoading();
    }
});

// ═════════════════════════════════════════════════════════════
//  KEYBOARD
// ═════════════════════════════════════════════════════════════
window.addEventListener('keydown', function(e) {
    if (lockpickState.active) {
        if (e.key === 'Escape') {
            e.preventDefault();
            closeLockpick();
            sendNUI('lockpick_close', {});
        }
        // Fleches gauche/droite pour selectionner la goupille
        if (e.key === 'ArrowLeft' || e.key === 'a' || e.key === 'A') {
            e.preventDefault();
            selectPin(lockpickState.selectedPin - 1);
        }
        if (e.key === 'ArrowRight' || e.key === 'd' || e.key === 'D') {
            e.preventDefault();
            selectPin(lockpickState.selectedPin + 1);
        }
    }

    if (hotwireState.active) {
        if (e.key === 'Escape') {
            e.preventDefault();
            closeHotwire();
            sendNUI('hotwire_close', {});
        }
    }
});

// ═════════════════════════════════════════════════════════════
//  LOCKPICK — SYSTEME DE GOUPILLES
// ═════════════════════════════════════════════════════════════

var PIN_MAX_HEIGHT = 100;  // pourcentage max
var PIN_TOLERANCE  = 6;    // marge d'erreur pour "correct"
var PIN_FALL_BASE  = 0.6;  // vitesse de retombee de base (non selectionnee)
var PIN_RESIST_BASE = 0.25; // resistance sur la goupille selectionnee
var PIN_JITTER_AMP  = 0.8;  // amplitude du tremblement de resistance

function initPins() {
    var area = document.getElementById('pins-area');
    area.innerHTML = '';

    lockpickState.pins = [];

    for (var i = 0; i < lockpickState.pinCount; i++) {
        // Hauteur cible aleatoire entre 30% et 85%
        var target = 30 + Math.floor(Math.random() * 55);

        // Chaque goupille a sa propre resistance (certaines sont plus dures)
        var resistance = PIN_RESIST_BASE + Math.random() * 0.3;
        var fallSpeed  = PIN_FALL_BASE + Math.random() * 0.4;

        lockpickState.pins.push({
            currentHeight: 15 + Math.floor(Math.random() * 15),
            targetHeight: target,
            locked: false,
            tolerance: PIN_TOLERANCE,
            resistance: resistance,
            fallSpeed: fallSpeed,
            jitterPhase: Math.random() * Math.PI * 2,
        });

        // Creer le DOM de la goupille
        var slot = document.createElement('div');
        slot.className = 'pin-slot' + (i === 0 ? ' active' : '');
        slot.dataset.index = i;

        var channel = document.createElement('div');
        channel.className = 'pin-channel';

        var spring = document.createElement('div');
        spring.className = 'pin-spring';
        channel.appendChild(spring);

        var bar = document.createElement('div');
        bar.className = 'pin-bar' + (i === 0 ? ' selected' : '');
        bar.id = 'pin-bar-' + i;
        bar.style.height = lockpickState.pins[i].currentHeight + '%';
        channel.appendChild(bar);

        slot.appendChild(channel);
        area.appendChild(slot);

        // Clic pour selectionner la goupille
        (function(idx) {
            slot.addEventListener('click', function() {
                if (!lockpickState.active) return;
                selectPin(idx);
            });
        })(i);
    }
}

function selectPin(idx) {
    if (idx < 0 || idx >= lockpickState.pinCount) return;
    if (lockpickState.pins[idx].locked) return;

    // Retirer la selection de l'ancien
    var oldSlot = document.querySelector('.pin-slot.active');
    if (oldSlot) oldSlot.classList.remove('active');
    var oldBar = document.getElementById('pin-bar-' + lockpickState.selectedPin);
    if (oldBar && !lockpickState.pins[lockpickState.selectedPin].locked) {
        oldBar.classList.remove('selected');
    }

    lockpickState.selectedPin = idx;

    // Ajouter la selection au nouveau
    var slots = document.querySelectorAll('.pin-slot');
    if (slots[idx]) slots[idx].classList.add('active');
    var newBar = document.getElementById('pin-bar-' + idx);
    if (newBar && !lockpickState.pins[idx].locked) {
        newBar.classList.add('selected');
    }
}

// Scroll pour monter/descendre la goupille
window.addEventListener('wheel', function(e) {
    if (!lockpickState.active) return;
    e.preventDefault();

    var idx = lockpickState.selectedPin;
    var pin = lockpickState.pins[idx];
    if (!pin || pin.locked) return;

    // Scroll up = monter la goupille, scroll down = baisser
    var delta = e.deltaY < 0 ? lockpickState.scrollSpeed : -lockpickState.scrollSpeed;
    pin.currentHeight = Math.max(5, Math.min(PIN_MAX_HEIGHT, pin.currentHeight + delta));

    var bar = document.getElementById('pin-bar-' + idx);
    if (bar) {
        bar.style.height = pin.currentHeight + '%';
    }

    // Verifier si la goupille est a la bonne hauteur
    checkPinPosition(idx);
}, { passive: false });

function checkPinPosition(idx) {
    var pin = lockpickState.pins[idx];
    if (pin.locked) return;

    var diff = Math.abs(pin.currentHeight - pin.targetHeight);
    var bar = document.getElementById('pin-bar-' + idx);

    if (diff <= pin.tolerance) {
        bar.classList.add('correct');
        bar.classList.remove('selected');
    } else {
        bar.classList.remove('correct');
        if (idx === lockpickState.selectedPin) {
            bar.classList.add('selected');
        }
    }
}

// Clic gauche pour verrouiller la goupille en position
window.addEventListener('mousedown', function(e) {
    if (!lockpickState.active) return;
    if (e.button !== 0) return; // seulement clic gauche

    var idx = lockpickState.selectedPin;
    var pin = lockpickState.pins[idx];
    if (!pin || pin.locked) return;

    var diff = Math.abs(pin.currentHeight - pin.targetHeight);

    if (diff <= pin.tolerance) {
        // Verrouiller la goupille
        pin.locked = true;
        pin.currentHeight = pin.targetHeight;

        var bar = document.getElementById('pin-bar-' + idx);
        if (bar) {
            bar.style.height = pin.currentHeight + '%';
            bar.classList.remove('correct', 'selected');
            bar.classList.add('locked');
        }

        // Selectionner la prochaine goupille non verrouillee
        var nextFound = false;
        for (var i = 0; i < lockpickState.pinCount; i++) {
            if (!lockpickState.pins[i].locked) {
                selectPin(i);
                nextFound = true;
                break;
            }
        }

        // Verifier si toutes les goupilles sont verrouillee
        if (!nextFound) {
            onLockpickSuccess();
        }
    } else {
        // Mauvaise position — echec : reset toutes les goupilles
        onLockpickFail();
    }
});

// Resistance et retombee dynamique des goupilles
function startPinFall() {
    if (lockpickState.fallInterval) {
        clearInterval(lockpickState.fallInterval);
    }

    var tickCount = 0;

    lockpickState.fallInterval = setInterval(function() {
        if (!lockpickState.active) return;
        tickCount++;

        for (var i = 0; i < lockpickState.pinCount; i++) {
            var pin = lockpickState.pins[i];
            if (pin.locked) continue;

            var bar = document.getElementById('pin-bar-' + i);
            if (!bar) continue;

            if (i === lockpickState.selectedPin) {
                // === Goupille selectionnee : resistance active ===
                // La goupille pousse vers le bas meme pendant qu'on scroll
                if (pin.currentHeight > 12) {
                    pin.currentHeight = Math.max(10, pin.currentHeight - pin.resistance);
                }

                // Tremblement/vibration pour simuler la pression du ressort
                var jitter = Math.sin(tickCount * 0.3 + pin.jitterPhase) * PIN_JITTER_AMP;
                var displayHeight = Math.max(5, Math.min(PIN_MAX_HEIGHT, pin.currentHeight + jitter));
                bar.style.height = displayHeight + '%';

                // Re-verifier la position avec la hauteur reelle (sans jitter)
                checkPinPosition(i);
            } else {
                // === Goupille non selectionnee : retombe plus vite ===
                if (pin.currentHeight > 10) {
                    pin.currentHeight = Math.max(10, pin.currentHeight - pin.fallSpeed);
                    bar.style.height = pin.currentHeight + '%';
                    bar.classList.remove('correct');
                }
            }
        }
    }, 40);
}

function onLockpickSuccess() {
    lockpickState.active = false;
    if (lockpickState.fallInterval) {
        clearInterval(lockpickState.fallInterval);
        lockpickState.fallInterval = null;
    }

    var housing = document.querySelector('.lock-housing');
    if (housing) housing.classList.add('success-flash');

    setTimeout(function() {
        closeLockpick();
        sendNUI('lockpick_success', {});
    }, 1000);
}

function onLockpickFail() {
    lockpickState.active = false;
    if (lockpickState.fallInterval) {
        clearInterval(lockpickState.fallInterval);
        lockpickState.fallInterval = null;
    }

    // Faire trembler le boitier
    var housing = document.querySelector('.lock-housing');
    if (housing) housing.classList.add('fail-shake');

    // Toutes les goupilles retombent
    for (var i = 0; i < lockpickState.pinCount; i++) {
        var pin = lockpickState.pins[i];
        pin.locked = false;
        pin.currentHeight = 5;
        var bar = document.getElementById('pin-bar-' + i);
        if (bar) {
            bar.style.height = '5%';
            bar.classList.remove('correct', 'selected', 'locked');
        }
    }

    setTimeout(function() {
        closeLockpick();
        sendNUI('lockpick_fail', {});
    }, 1000);
}

function closeLockpick() {
    lockpickState.active = false;

    if (lockpickState.fallInterval) {
        clearInterval(lockpickState.fallInterval);
        lockpickState.fallInterval = null;
    }

    var container = document.getElementById('lockpick-container');
    container.classList.add('closing');

    setTimeout(function() {
        container.classList.add('hidden');
        container.classList.remove('closing');

        var housing = document.querySelector('.lock-housing');
        if (housing) {
            housing.classList.remove('success-flash', 'fail-shake');
        }
    }, 250);
}

// ═════════════════════════════════════════════════════════════
//  HOTWIRE MINI-GAME (CABLAGE — DRAG & DROP)
// ═════════════════════════════════════════════════════════════

var dragState = {
    isDragging: false,
    leftIndex: -1,
    color: '',
    colorHex: '',
    dragLine: null,
    dragGlow: null,
    startX: 0,
    startY: 0,
};

function initHotwire() {
    var count = hotwireState.wireCount;
    if (count > WIRE_COLORS.length) count = WIRE_COLORS.length;

    var leftDiv  = document.getElementById('wire-left');
    var rightDiv = document.getElementById('wire-right');
    var svg      = document.getElementById('wire-svg');

    leftDiv.innerHTML  = '';
    rightDiv.innerHTML = '';
    svg.innerHTML      = '';

    hotwireState.connections    = {};
    hotwireState.connectedCount = 0;

    var colors = [];
    for (var i = 0; i < count; i++) {
        colors.push(WIRE_COLORS[i]);
    }
    hotwireState.leftColors = colors.slice();

    var shuffled = colors.slice();
    for (var s = shuffled.length - 1; s > 0; s--) {
        var j = Math.floor(Math.random() * (s + 1));
        var tmp = shuffled[s];
        shuffled[s] = shuffled[j];
        shuffled[j] = tmp;
    }
    hotwireState.rightColors = shuffled;

    for (var li = 0; li < count; li++) {
        var lc = hotwireState.leftColors[li];
        var lEl = document.createElement('div');
        lEl.className = 'wire-connector wire-' + lc.name;
        lEl.dataset.index     = li;
        lEl.dataset.colorName = lc.name;
        lEl.dataset.colorHex  = lc.hex;
        lEl.innerHTML = '<span class="connector-symbol">' + lc.symbol + '</span>';
        leftDiv.appendChild(lEl);

        lEl.addEventListener('mousedown', onLeftMouseDown);
    }

    for (var ri = 0; ri < count; ri++) {
        var rc = hotwireState.rightColors[ri];
        var rEl = document.createElement('div');
        rEl.className = 'wire-connector wire-' + rc.name;
        rEl.dataset.index     = ri;
        rEl.dataset.colorName = rc.name;
        rEl.dataset.colorHex  = rc.hex;
        rEl.innerHTML = '<span class="connector-symbol">' + rc.symbol + '</span>';
        rightDiv.appendChild(rEl);
    }

    document.addEventListener('mousemove', onDragMove);
    document.addEventListener('mouseup', onDragEnd);

    updateHotwireStatus('Glissez les fils vers la bonne couleur');
}

function onLeftMouseDown(e) {
    if (!hotwireState.active) return;
    var el = e.currentTarget;
    if (el.classList.contains('connected')) return;

    e.preventDefault();

    var idx = parseInt(el.dataset.index);
    var board = document.querySelector('.hotwire-board');
    var boardRect = board.getBoundingClientRect();

    var elRect = el.getBoundingClientRect();
    var startX = elRect.right - boardRect.left;
    var startY = elRect.top + elRect.height / 2 - boardRect.top;

    dragState.isDragging = true;
    dragState.leftIndex  = idx;
    dragState.color      = el.dataset.colorName;
    dragState.colorHex   = el.dataset.colorHex;
    dragState.startX     = startX;
    dragState.startY     = startY;

    el.classList.add('dragging');

    var svg = document.getElementById('wire-svg');

    var glow = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    glow.setAttribute('stroke', dragState.colorHex);
    glow.setAttribute('stroke-width', '10');
    glow.setAttribute('fill', 'none');
    glow.setAttribute('stroke-linecap', 'round');
    glow.setAttribute('opacity', '0.2');
    svg.appendChild(glow);
    dragState.dragGlow = glow;

    var line = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    line.setAttribute('stroke', dragState.colorHex);
    line.setAttribute('stroke-width', '5');
    line.setAttribute('fill', 'none');
    line.setAttribute('stroke-linecap', 'round');
    line.setAttribute('opacity', '0.9');
    svg.appendChild(line);
    dragState.dragLine = line;

    updateDragLine(startX, startY);
}

function onDragMove(e) {
    if (!dragState.isDragging) return;

    var board = document.querySelector('.hotwire-board');
    var boardRect = board.getBoundingClientRect();

    var mouseX = e.clientX - boardRect.left;
    var mouseY = e.clientY - boardRect.top;

    updateDragLine(mouseX, mouseY);

    var rightConnectors = document.querySelectorAll('.wire-right .wire-connector');
    for (var i = 0; i < rightConnectors.length; i++) {
        var rc = rightConnectors[i];
        if (rc.classList.contains('connected')) continue;

        var rcRect = rc.getBoundingClientRect();
        if (e.clientX >= rcRect.left && e.clientX <= rcRect.right &&
            e.clientY >= rcRect.top && e.clientY <= rcRect.bottom) {
            rc.classList.add('drop-target');
        } else {
            rc.classList.remove('drop-target');
        }
    }
}

function updateDragLine(endX, endY) {
    var sx = dragState.startX;
    var sy = dragState.startY;
    var cp1x = sx + (endX - sx) * 0.4;
    var cp2x = sx + (endX - sx) * 0.6;

    var d = 'M ' + sx + ' ' + sy +
            ' C ' + cp1x + ' ' + sy + ', ' + cp2x + ' ' + endY + ', ' + endX + ' ' + endY;

    if (dragState.dragLine) dragState.dragLine.setAttribute('d', d);
    if (dragState.dragGlow) dragState.dragGlow.setAttribute('d', d);
}

function onDragEnd(e) {
    if (!dragState.isDragging) return;
    dragState.isDragging = false;

    var leftEl = document.querySelector('.wire-left .wire-connector[data-index="' + dragState.leftIndex + '"]');
    if (leftEl) leftEl.classList.remove('dragging');

    var allRight = document.querySelectorAll('.wire-right .wire-connector');
    for (var i = 0; i < allRight.length; i++) {
        allRight[i].classList.remove('drop-target');
    }

    var droppedOn = null;
    for (var j = 0; j < allRight.length; j++) {
        var rc = allRight[j];
        if (rc.classList.contains('connected')) continue;

        var rcRect = rc.getBoundingClientRect();
        if (e.clientX >= rcRect.left && e.clientX <= rcRect.right &&
            e.clientY >= rcRect.top && e.clientY <= rcRect.bottom) {
            droppedOn = rc;
            break;
        }
    }

    if (dragState.dragLine) { dragState.dragLine.remove(); dragState.dragLine = null; }
    if (dragState.dragGlow) { dragState.dragGlow.remove(); dragState.dragGlow = null; }

    if (!droppedOn) return;

    var rightIdx    = parseInt(droppedOn.dataset.index);
    var rightColor  = droppedOn.dataset.colorName;
    var leftIdx     = dragState.leftIndex;
    var leftColor   = dragState.color;

    if (leftColor === rightColor) {
        hotwireState.connections[leftIdx] = rightIdx;
        hotwireState.connectedCount++;

        if (leftEl) leftEl.classList.add('connected');
        droppedOn.classList.add('connected');

        drawPermanentWire(leftIdx, rightIdx, dragState.colorHex);

        if (hotwireState.connectedCount >= hotwireState.wireCount) {
            onHotwireSuccess();
        } else {
            updateHotwireStatus(hotwireState.connectedCount + ' / ' + hotwireState.wireCount + ' fils connectes');
        }
    } else {
        droppedOn.classList.add('wrong');
        if (leftEl) leftEl.classList.add('wrong');
        setTimeout(function() {
            droppedOn.classList.remove('wrong');
            if (leftEl) leftEl.classList.remove('wrong');
        }, 400);

        updateHotwireStatus('Mauvaise couleur !', 'fail');
        setTimeout(function() {
            if (hotwireState.active) {
                updateHotwireStatus('Glissez les fils vers la bonne couleur');
            }
        }, 1000);
    }
}

function drawPermanentWire(leftIdx, rightIdx, colorHex) {
    var svg   = document.getElementById('wire-svg');
    var board = document.querySelector('.hotwire-board');
    var boardRect = board.getBoundingClientRect();

    var leftEl  = document.querySelector('.wire-left .wire-connector[data-index="' + leftIdx + '"]');
    var rightEl = document.querySelector('.wire-right .wire-connector[data-index="' + rightIdx + '"]');

    if (!leftEl || !rightEl) return;

    var leftRect  = leftEl.getBoundingClientRect();
    var rightRect = rightEl.getBoundingClientRect();

    var sx = leftRect.right - boardRect.left;
    var sy = leftRect.top + leftRect.height / 2 - boardRect.top;
    var ex = rightRect.left - boardRect.left;
    var ey = rightRect.top + rightRect.height / 2 - boardRect.top;

    var cp1x = sx + (ex - sx) * 0.35;
    var cp2x = sx + (ex - sx) * 0.65;

    var d = 'M ' + sx + ' ' + sy +
            ' C ' + cp1x + ' ' + sy + ', ' + cp2x + ' ' + ey + ', ' + ex + ' ' + ey;

    var glow = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    glow.setAttribute('d', d);
    glow.setAttribute('stroke', colorHex);
    glow.setAttribute('stroke-width', '10');
    glow.setAttribute('fill', 'none');
    glow.setAttribute('stroke-linecap', 'round');
    glow.setAttribute('opacity', '0.2');
    svg.appendChild(glow);

    var path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    path.setAttribute('d', d);
    path.setAttribute('stroke', colorHex);
    path.setAttribute('stroke-width', '5');
    path.setAttribute('fill', 'none');
    path.setAttribute('stroke-linecap', 'round');
    path.setAttribute('opacity', '0.9');

    var totalLen = 600;
    path.style.strokeDasharray = totalLen;
    path.style.strokeDashoffset = totalLen;
    path.style.transition = 'stroke-dashoffset 0.35s ease';
    glow.style.strokeDasharray = totalLen;
    glow.style.strokeDashoffset = totalLen;
    glow.style.transition = 'stroke-dashoffset 0.35s ease';

    svg.appendChild(path);

    path.getBoundingClientRect();
    glow.getBoundingClientRect();
    path.style.strokeDashoffset = '0';
    glow.style.strokeDashoffset = '0';
}

function updateHotwireStatus(text, type) {
    var el = document.getElementById('hotwire-status');
    el.textContent = text;
    el.className = 'hotwire-status';
    if (type === 'success') el.classList.add('success-text');
    if (type === 'fail')    el.classList.add('fail-text');
}

function onHotwireSuccess() {
    hotwireState.active = false;
    updateHotwireStatus('Cablage reussi !', 'success');
    document.getElementById('hotwire-title-text').textContent = 'Reussi !';

    setTimeout(function() {
        closeHotwire();
        sendNUI('hotwire_success', {});
    }, 1000);
}

function closeHotwire() {
    hotwireState.active = false;
    dragState.isDragging = false;

    document.removeEventListener('mousemove', onDragMove);
    document.removeEventListener('mouseup', onDragEnd);

    if (dragState.dragLine) { dragState.dragLine.remove(); dragState.dragLine = null; }
    if (dragState.dragGlow) { dragState.dragGlow.remove(); dragState.dragGlow = null; }

    var container = document.getElementById('hotwire-container');
    container.classList.add('closing');

    setTimeout(function() {
        container.classList.add('hidden');
        container.classList.remove('closing');
    }, 250);
}

// ═════════════════════════════════════════════════════════════
//  LOADING BAR (branchement animation)
// ═════════════════════════════════════════════════════════════

function startLoading() {
    if (loadingState.animFrame) {
        cancelAnimationFrame(loadingState.animFrame);
    }

    function animate(time) {
        if (!loadingState.active) return;

        var elapsed = time - loadingState.startTime;
        var pct = Math.min(100, (elapsed / loadingState.duration) * 100);

        document.getElementById('loading-bar-fill').style.width = pct + '%';
        document.getElementById('loading-percent').textContent = Math.floor(pct) + '%';

        if (pct >= 100) {
            loadingState.active = false;
            setTimeout(function() {
                closeLoading();
                sendNUI('loading_complete', {});
            }, 300);
            return;
        }

        loadingState.animFrame = requestAnimationFrame(animate);
    }

    loadingState.animFrame = requestAnimationFrame(animate);
}

function closeLoading() {
    loadingState.active = false;

    if (loadingState.animFrame) {
        cancelAnimationFrame(loadingState.animFrame);
        loadingState.animFrame = null;
    }

    var container = document.getElementById('loading-container');
    container.classList.add('closing');

    setTimeout(function() {
        container.classList.add('hidden');
        container.classList.remove('closing');
    }, 250);
}

// ═════════════════════════════════════════════════════════════
//  NUI COMMUNICATION
// ═════════════════════════════════════════════════════════════

function sendNUI(endpoint, data) {
    fetch('https://vehicle_lockpick/' + endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {}),
    }).catch(function() {});
}
