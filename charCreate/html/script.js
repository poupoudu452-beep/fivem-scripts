/* ============================================================
   CHARACTER CREATION — NUI SCRIPT
   ============================================================ */
'use strict';

// ── Etat global ──────────────────────────────────────────────
const state = { currentStep: 0, gender: null, age: 28, height: 175 };

const RESOURCE_NAME = (function() {
    try { if (typeof GetParentResourceName === 'function') return GetParentResourceName(); } catch(e) {}
    return 'charCreate';
})();

function nuiFetch(endpoint, data) {
    return fetch('https://' + RESOURCE_NAME + '/' + endpoint, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    }).then(function(r) { return r.json().catch(function() { return {}; }); })
      .catch(function(err) { console.error('[NUI]', endpoint, err); });
}

// ── Apparence ────────────────────────────────────────────────
let appMaxValues = {};
const appearance = {
    heritage:   { mother: 0, father: 0, shapeMix: 0.5, skinMix: 0.5 },
    hair:       { style: 0, color: 0, highlight: 0 },
    features:   {},
    overlays:   { beard: { style: 255, opacity: 1.0, color: 0 }, eyebrows: { style: 255, opacity: 1.0, color: 0 } },
    components: { '1':[0,0], '3':[15,0], '4':[21,0], '5':[0,0], '6':[1,0], '7':[0,0], '8':[15,0], '9':[0,0], '10':[0,0], '11':[15,0] },
};

const FACE_FEATURES = [
    { key: 'noseWidth',      label: 'Largeur du nez',      index: 0 },
    { key: 'nosePeakHeight', label: 'Hauteur du nez',      index: 1 },
    { key: 'nosePeakLength', label: 'Longueur du nez',     index: 2 },
    { key: 'noseBoneHeight', label: 'Os du nez',           index: 3 },
    { key: 'lipThickness',   label: 'Epaisseur des levres',index: 12 },
    { key: 'jawBoneWidth',   label: 'Largeur machoire',    index: 13 },
    { key: 'jawBoneLength',  label: 'Longueur machoire',   index: 14 },
    { key: 'chinBoneHeight', label: 'Hauteur du menton',   index: 15 },
    { key: 'chinBoneLength', label: 'Longueur du menton',  index: 16 },
    { key: 'eyeOpening',     label: 'Ouverture des yeux',  index: 11 },
];

const COMP_LABELS = {
    '11': 'Haut', '8': 'Sous-vetement', '3': 'Bras', '4': 'Pantalon',
    '6': 'Chaussures', '1': 'Masque', '7': 'Accessoire', '5': 'Sac',
};
const COMP_ORDER = ['11','8','3','4','6','1','7','5'];

const CATEGORIES = [
    { id: 'heritage', label: 'Heritage',  camera: 'face' },
    { id: 'hair',     label: 'Cheveux',   camera: 'face' },
    { id: 'face',     label: 'Visage',    camera: 'face' },
    { id: 'beard',    label: 'Pilosite',  camera: 'face' },
    { id: 'clothing', label: 'Vetements', camera: 'body' },
];

let activeAppTab = 'heritage';
let compMaxTextures = {};

// ── Messages du client ───────────────────────────────────────
window.addEventListener('message', function(event) {
    const msg = event.data;
    if (!msg || !msg.type) return;

    switch (msg.type) {
        case 'show':
            document.getElementById('root').classList.remove('hidden');
            goStep(0);
            break;

        case 'hide':
            if (typeof confirmTimeout !== 'undefined' && confirmTimeout) { clearTimeout(confirmTimeout); confirmTimeout = null; }
            setConfirmLoading(false);
            document.getElementById('root').classList.add('hidden');
            break;

        case 'error':
            if (typeof confirmTimeout !== 'undefined' && confirmTimeout) { clearTimeout(confirmTimeout); confirmTimeout = null; }
            showError(msg.message || 'Une erreur est survenue.');
            setConfirmLoading(false);
            break;

        case 'showAppearance':
            document.getElementById('root').classList.remove('hidden');
            appMaxValues = msg.maxValues || {};
            initAppearanceEditor(msg.gender);
            setScreen('appearance');
            break;

        case 'showSelection':
            document.getElementById('root').classList.remove('hidden');
            fillSelection(msg);
            setScreen('select');
            break;

        case 'welcome':
            document.getElementById('root').classList.add('hidden');
            break;
    }
});

// ── Navigation ───────────────────────────────────────────────
function goStep(n) {
    state.currentStep = n;
    setScreen(n === 0 ? 'welcome' : 'form');
    if (n >= 1) { activateStep(n); updateProgressBar(n); }
}

function setScreen(name) {
    document.querySelectorAll('.screen').forEach(function(s) { s.classList.remove('active'); });
    var target = document.getElementById('screen-' + name);
    if (target) target.classList.add('active');
}

function activateStep(n) {
    document.querySelectorAll('.step').forEach(function(s) { s.classList.remove('active'); });
    var step = document.getElementById('step-' + n);
    if (step) step.classList.add('active');
}

function updateProgressBar(n) {
    var pct = ((n - 1) / 3) * 100;
    document.getElementById('progress-fill').style.width = pct + '%';
    document.querySelectorAll('.pstep').forEach(function(p) {
        var sn = parseInt(p.dataset.step);
        p.classList.toggle('active', sn === n);
        p.classList.toggle('completed', sn < n);
    });
}

// ── Etape 1 : Genre ──────────────────────────────────────────
function selectGender(gender) {
    state.gender = gender;
    document.querySelectorAll('.gender-card').forEach(function(c) { c.classList.remove('selected'); });
    document.getElementById('card-' + gender).classList.add('selected');
    document.getElementById('btn-next-1').disabled = false;
    nuiFetch('previewGender', { gender: gender });
}

// ── Etape 2 : Identite ──────────────────────────────────────
function validateIdentity() {
    var fn = document.getElementById('inp-firstname').value.trim();
    var ln = document.getElementById('inp-lastname').value.trim();
    var ok = fn.length >= 2 && fn.length <= 50 && ln.length >= 2 && ln.length <= 50;
    document.getElementById('btn-next-2').disabled = !ok;
    return ok;
}

// ── Sliders generiques ──────────────────────────────────────
function updateRange(field) {
    var input = document.getElementById('inp-' + field);
    var val = parseInt(input.value);
    state[field] = val;
    if (field === 'age')    document.getElementById('val-age').textContent = val + ' ans';
    if (field === 'height') { document.getElementById('val-height').textContent = val + ' cm'; updateHeightVisual(val); }
}

function updateHeightVisual(val) {
    var bar = document.getElementById('hv-bar');
    if (!bar) return;
    bar.style.height = ((val - 150) / 70) * 100 + '%';
}

// ── Navigation entre etapes ──────────────────────────────────
function nextStep(current) {
    if (current === 1 && !state.gender) { showError('Veuillez choisir un genre.'); return; }
    if (current === 2) { if (!validateIdentity()) { showError('Prenom et nom requis.'); return; } state.age = parseInt(document.getElementById('inp-age').value); }
    if (current === 3) { state.height = parseInt(document.getElementById('inp-height').value); }
    var next = current + 1;
    if (next === 4) fillRecap();
    goStep(next);
}

function prevStep(current) { goStep(current - 1); }

function fillRecap() {
    var fn = document.getElementById('inp-firstname').value.trim();
    var ln = document.getElementById('inp-lastname').value.trim();
    document.getElementById('recap-name').textContent   = fn + ' ' + ln;
    document.getElementById('recap-gender').textContent = state.gender === 'female' ? 'Feminin' : 'Masculin';
    document.getElementById('recap-age').textContent    = state.age + ' ans';
    document.getElementById('recap-height').textContent = state.height + ' cm';
}

// ── Confirmation ─────────────────────────────────────────────
let confirmTimeout = null;

function confirmCreation() {
    var fn = document.getElementById('inp-firstname').value.trim();
    var ln = document.getElementById('inp-lastname').value.trim();
    if (!fn || !ln || !state.gender) { showError('Donnees manquantes.'); return; }

    setConfirmLoading(true);
    if (confirmTimeout) clearTimeout(confirmTimeout);
    confirmTimeout = setTimeout(function() { setConfirmLoading(false); showError('Le serveur ne repond pas.'); }, 10000);

    nuiFetch('createCharacter', { firstname: fn, lastname: ln, age: state.age, height: state.height, gender: state.gender });
}

function setConfirmLoading(loading) {
    var label  = document.getElementById('confirm-label');
    var loader = document.getElementById('confirm-loader');
    var btn    = document.getElementById('btn-confirm');
    if (!label || !loader || !btn) return;
    if (loading) { label.classList.add('hidden'); loader.classList.remove('hidden'); btn.disabled = true; }
    else         { label.classList.remove('hidden'); loader.classList.add('hidden'); btn.disabled = false; }
}

// ── Toast d'erreur ───────────────────────────────────────────
let errorTimer = null;
function showError(msg) {
    var toast = document.getElementById('error-toast');
    toast.textContent = msg;
    toast.classList.remove('hidden');
    toast.classList.add('visible');
    if (errorTimer) clearTimeout(errorTimer);
    errorTimer = setTimeout(function() { toast.classList.remove('visible'); setTimeout(function() { toast.classList.add('hidden'); }, 400); }, 3500);
}

// ══════════════════════════════════════════════════════════════
//  EDITEUR D'APPARENCE
// ══════════════════════════════════════════════════════════════

function initAppearanceEditor(gender) {
    if (confirmTimeout) { clearTimeout(confirmTimeout); confirmTimeout = null; }
    setConfirmLoading(false);

    // Reset features
    FACE_FEATURES.forEach(function(f) { appearance.features[f.key] = 0; });

    // Default components based on gender
    if (gender === 'female') {
        appearance.components['4'] = [15, 0];
    } else {
        appearance.components['4'] = [21, 0];
    }

    buildTabs();
    switchAppTab('heritage');
}

function buildTabs() {
    var tabsEl = document.getElementById('app-tabs');
    tabsEl.innerHTML = '';
    CATEGORIES.forEach(function(cat) {
        var btn = document.createElement('button');
        btn.className = 'app-tab' + (cat.id === activeAppTab ? ' active' : '');
        btn.textContent = cat.label;
        btn.dataset.tab = cat.id;
        btn.onclick = function() { switchAppTab(cat.id); };
        tabsEl.appendChild(btn);
    });
}

function switchAppTab(tabId) {
    activeAppTab = tabId;
    document.querySelectorAll('.app-tab').forEach(function(t) { t.classList.toggle('active', t.dataset.tab === tabId); });

    var cat = CATEGORIES.find(function(c) { return c.id === tabId; });
    if (cat) nuiFetch('switchCamera', { mode: cat.camera });

    var body = document.getElementById('app-body');
    body.innerHTML = '';

    switch (tabId) {
        case 'heritage': buildHeritage(body); break;
        case 'hair':     buildHair(body);     break;
        case 'face':     buildFace(body);     break;
        case 'beard':    buildBeard(body);    break;
        case 'clothing': buildClothing(body); break;
    }
}

// ── Helper : creer un stepper ────────────────────────────────
function makeStepper(label, value, displayFn, onStep) {
    var row = document.createElement('div');
    row.className = 'app-row';

    var lbl = document.createElement('span');
    lbl.className = 'app-label';
    lbl.textContent = label;

    var stepper = document.createElement('div');
    stepper.className = 'app-stepper';

    var btnL = document.createElement('button');
    btnL.className = 'step-btn';
    btnL.innerHTML = '&#9664;';

    var valSpan = document.createElement('span');
    valSpan.className = 'step-val';
    valSpan.textContent = displayFn(value);

    var btnR = document.createElement('button');
    btnR.className = 'step-btn';
    btnR.innerHTML = '&#9654;';

    btnL.onclick = function() { var nv = onStep(-1); valSpan.textContent = displayFn(nv); };
    btnR.onclick = function() { var nv = onStep(1);  valSpan.textContent = displayFn(nv); };

    stepper.appendChild(btnL);
    stepper.appendChild(valSpan);
    stepper.appendChild(btnR);
    row.appendChild(lbl);
    row.appendChild(stepper);
    return row;
}

// ── Helper : creer un slider ─────────────────────────────────
function makeSlider(label, min, max, value, step, displayFn, onChange) {
    var row = document.createElement('div');
    row.className = 'app-row';

    var lbl = document.createElement('span');
    lbl.className = 'app-label';
    lbl.textContent = label;

    var wrap = document.createElement('div');
    wrap.className = 'app-slider-wrap';

    var input = document.createElement('input');
    input.type = 'range';
    input.className = 'app-range';
    input.min = min;
    input.max = max;
    input.value = value;
    if (step) input.step = step;

    var valSpan = document.createElement('span');
    valSpan.className = 'slider-val';
    valSpan.textContent = displayFn(value);

    input.oninput = function() {
        var v = parseFloat(input.value);
        valSpan.textContent = displayFn(v);
        onChange(v);
    };

    wrap.appendChild(input);
    wrap.appendChild(valSpan);
    row.appendChild(lbl);
    row.appendChild(wrap);
    return row;
}

// ── Heritage ─────────────────────────────────────────────────
function buildHeritage(container) {
    var maxP = (appMaxValues.parents || 46) - 1;

    container.appendChild(makeStepper('Mere', appearance.heritage.mother, function(v) { return v; }, function(dir) {
        appearance.heritage.mother = (appearance.heritage.mother + dir + maxP + 1) % (maxP + 1);
        previewHeritage();
        return appearance.heritage.mother;
    }));

    container.appendChild(makeStepper('Pere', appearance.heritage.father, function(v) { return v; }, function(dir) {
        appearance.heritage.father = (appearance.heritage.father + dir + maxP + 1) % (maxP + 1);
        previewHeritage();
        return appearance.heritage.father;
    }));

    container.appendChild(makeSlider('Ressemblance', 0, 100, Math.round(appearance.heritage.shapeMix * 100), 1,
        function(v) { return Math.round(v) + '%'; },
        function(v) { appearance.heritage.shapeMix = v / 100; previewHeritage(); }));

    container.appendChild(makeSlider('Teint', 0, 100, Math.round(appearance.heritage.skinMix * 100), 1,
        function(v) { return Math.round(v) + '%'; },
        function(v) { appearance.heritage.skinMix = v / 100; previewHeritage(); }));
}

function previewHeritage() {
    nuiFetch('updateAppearance', {
        category: 'heritage',
        mother: appearance.heritage.mother,
        father: appearance.heritage.father,
        shapeMix: appearance.heritage.shapeMix,
        skinMix: appearance.heritage.skinMix,
    });
}

// ── Cheveux ──────────────────────────────────────────────────
function buildHair(container) {
    var maxHS = (appMaxValues.hairStyles || 36) - 1;
    var maxHC = (appMaxValues.hairColors || 64) - 1;

    container.appendChild(makeStepper('Style', appearance.hair.style, function(v) { return v; }, function(dir) {
        appearance.hair.style = (appearance.hair.style + dir + maxHS + 1) % (maxHS + 1);
        previewHair(); return appearance.hair.style;
    }));

    container.appendChild(makeStepper('Couleur', appearance.hair.color, function(v) { return v; }, function(dir) {
        appearance.hair.color = (appearance.hair.color + dir + maxHC + 1) % (maxHC + 1);
        previewHair(); return appearance.hair.color;
    }));

    container.appendChild(makeStepper('Reflets', appearance.hair.highlight, function(v) { return v; }, function(dir) {
        appearance.hair.highlight = (appearance.hair.highlight + dir + maxHC + 1) % (maxHC + 1);
        previewHair(); return appearance.hair.highlight;
    }));
}

function previewHair() {
    nuiFetch('updateAppearance', {
        category: 'hair',
        style: appearance.hair.style,
        color: appearance.hair.color,
        highlight: appearance.hair.highlight,
    });
}

// ── Visage ───────────────────────────────────────────────────
function buildFace(container) {
    FACE_FEATURES.forEach(function(feat) {
        var cur = appearance.features[feat.key] || 0;
        container.appendChild(makeSlider(feat.label, -100, 100, Math.round(cur * 100), 1,
            function(v) { return Math.round(v); },
            function(v) {
                var fv = v / 100;
                appearance.features[feat.key] = fv;
                nuiFetch('updateAppearance', { category: 'feature', index: feat.index, value: fv });
            }));
    });
}

// ── Pilosite ─────────────────────────────────────────────────
function buildBeard(container) {
    var maxBeard = appMaxValues.beardStyles || 28;
    var maxBrow  = appMaxValues.eyebrowStyles || 34;
    var maxHC    = (appMaxValues.hairColors || 64) - 1;

    // Barbe
    container.appendChild(makeStepper('Barbe', appearance.overlays.beard.style, function(v) { return v === 255 ? 'Aucun' : v; }, function(dir) {
        var cur = appearance.overlays.beard.style;
        if (cur === 255) cur = dir > 0 ? 0 : maxBeard - 1;
        else { cur += dir; if (cur < 0) cur = 255; else if (cur >= maxBeard) cur = 255; }
        appearance.overlays.beard.style = cur;
        previewOverlay('beard', 1); return cur;
    }));

    container.appendChild(makeSlider('Opacite barbe', 0, 100, Math.round(appearance.overlays.beard.opacity * 100), 1,
        function(v) { return Math.round(v) + '%'; },
        function(v) { appearance.overlays.beard.opacity = v / 100; previewOverlay('beard', 1); }));

    container.appendChild(makeStepper('Couleur barbe', appearance.overlays.beard.color, function(v) { return v; }, function(dir) {
        appearance.overlays.beard.color = (appearance.overlays.beard.color + dir + maxHC + 1) % (maxHC + 1);
        previewOverlay('beard', 1); return appearance.overlays.beard.color;
    }));

    // Separator
    var sep = document.createElement('div');
    sep.className = 'app-separator';
    container.appendChild(sep);

    // Sourcils
    container.appendChild(makeStepper('Sourcils', appearance.overlays.eyebrows.style, function(v) { return v === 255 ? 'Aucun' : v; }, function(dir) {
        var cur = appearance.overlays.eyebrows.style;
        if (cur === 255) cur = dir > 0 ? 0 : maxBrow - 1;
        else { cur += dir; if (cur < 0) cur = 255; else if (cur >= maxBrow) cur = 255; }
        appearance.overlays.eyebrows.style = cur;
        previewOverlay('eyebrows', 2); return cur;
    }));

    container.appendChild(makeSlider('Opacite sourcils', 0, 100, Math.round(appearance.overlays.eyebrows.opacity * 100), 1,
        function(v) { return Math.round(v) + '%'; },
        function(v) { appearance.overlays.eyebrows.opacity = v / 100; previewOverlay('eyebrows', 2); }));

    container.appendChild(makeStepper('Couleur sourcils', appearance.overlays.eyebrows.color, function(v) { return v; }, function(dir) {
        appearance.overlays.eyebrows.color = (appearance.overlays.eyebrows.color + dir + maxHC + 1) % (maxHC + 1);
        previewOverlay('eyebrows', 2); return appearance.overlays.eyebrows.color;
    }));
}

function previewOverlay(type, overlayId) {
    var o = appearance.overlays[type];
    nuiFetch('updateAppearance', {
        category: 'overlay',
        overlayId: overlayId,
        style: o.style,
        opacity: o.opacity,
        color: o.color,
    });
}

// ── Vetements ────────────────────────────────────────────────
function buildClothing(container) {
    COMP_ORDER.forEach(function(compId) {
        var label = COMP_LABELS[compId] || 'Comp ' + compId;
        var maxDr = (appMaxValues.components && appMaxValues.components[compId]) || 20;
        var curDr = appearance.components[compId] ? appearance.components[compId][0] : 0;
        var curTx = appearance.components[compId] ? appearance.components[compId][1] : 0;

        container.appendChild(makeStepper(label, curDr, function(v) { return v; }, function(dir) {
            var c = appearance.components[compId] || [0, 0];
            c[0] = (c[0] + dir + maxDr) % maxDr;
            c[1] = 0; // reset texture on drawable change
            appearance.components[compId] = c;
            nuiFetch('updateAppearance', { category: 'component', componentId: parseInt(compId), drawable: c[0], texture: c[1] })
                .then(function(r) {
                    if (r && r.maxTexture !== undefined) {
                        compMaxTextures[compId] = r.maxTexture;
                    }
                });
            return c[0];
        }));
    });
}

// ── Sauvegarder l'apparence ──────────────────────────────────
function saveAppearance() {
    nuiFetch('saveAppearance', appearance);
}

// ── Tourner le ped ───────────────────────────────────────────
function rotatePed(angle) {
    nuiFetch('rotatePed', { angle: angle });
}

// ══════════════════════════════════════════════════════════════
//  SELECTION DU PERSONNAGE
// ══════════════════════════════════════════════════════════════

function fillSelection(data) {
    document.getElementById('select-name').textContent   = (data.firstname || '') + ' ' + (data.lastname || '');
    document.getElementById('select-gender').textContent = data.gender === 'female' ? 'Feminin' : 'Masculin';
    document.getElementById('select-age').textContent    = (data.age || '?') + ' ans';
}

function playCharacter() {
    nuiFetch('playCharacter', {});
}

// ── Zoom camera (molette) ────────────────────────────────────
function zoomCamera(delta) {
    nuiFetch('zoomCamera', { delta: delta });
}

// ── Init ─────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', function() {
    updateRange('age');
    updateRange('height');
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') e.preventDefault();
    });
    document.addEventListener('wheel', function(e) {
        var root = document.getElementById('root');
        if (root && !root.classList.contains('hidden')) {
            var delta = e.deltaY > 0 ? 1 : -1;
            zoomCamera(delta);
        }
    }, { passive: true });
});
