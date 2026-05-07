/* ============================================================
   POLICE JOB — NUI JavaScript
   ============================================================ */

let policeData = null;
let isCommander = false;
let isDuty = false;
let grades = [];
let officers = [];
let nearbyPlayers = [];
let currentAction = null;
let currentTarget = null;
let friskTarget = null;
let radioLog = [];

/* ─── NUI Message Listener ───────────────────────────────── */
window.addEventListener('message', function(event) {
    const msg = event.data;

    switch (msg.action) {
        case 'openMenu':
            policeData = msg.data;
            isCommander = policeData && policeData.grade_name === 'Commandant';
            isDuty = policeData && policeData.on_duty;
            showMenu();
            break;

        case 'closeMenu':
            hideMenu();
            break;

        case 'updateOfficers':
            officers = msg.officers || [];
            renderOfficers();
            updateStats();
            break;

        case 'updateGrades':
            grades = msg.grades || [];
            renderGrades();
            break;

        case 'updateNearbyPlayers':
            nearbyPlayers = msg.players || [];
            renderNearbyPlayers();
            break;

        case 'openFrisk':
            friskTarget = msg.targetId;
            document.getElementById('friskTargetName').textContent = msg.targetName || 'Joueur';
            renderFriskInventory(msg.inventory || []);
            document.getElementById('friskPanel').classList.remove('hidden');
            break;

        case 'closeFrisk':
            document.getElementById('friskPanel').classList.add('hidden');
            friskTarget = null;
            break;

        case 'updateFriskInventory':
            renderFriskInventory(msg.inventory || []);
            break;

        case 'openFines':
            renderFines(msg.fines || []);
            document.getElementById('finesPanel').classList.remove('hidden');
            break;

        case 'closeFines':
            document.getElementById('finesPanel').classList.add('hidden');
            break;

        case 'showFineNotification':
            showFineNotif(msg.amount, msg.reason);
            break;

        case 'openCompanyBank':
            renderCompanyBank(msg.data);
            break;

        case 'dutyUpdate':
            isDuty = msg.onDuty;
            updateDutyUI();
            break;
    }
});

/* ─── Escape key ─────────────────────────────────────────── */
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        closeMenu();
        closeFines();
        endFrisk();
    }
});

/* ═══ Menu Show / Hide ═══════════════════════════════════════ */
function showMenu() {
    document.getElementById('policeMenu').classList.remove('hidden');
    document.getElementById('headerGrade').textContent = policeData.grade_name || '—';
    document.getElementById('gradeDisplay').textContent = policeData.grade_name || '—';
    updateDutyUI();
    updateStats();

    // Show/hide commander-only tabs
    document.querySelectorAll('.commander-only').forEach(function(el) {
        el.style.display = isCommander ? '' : 'none';
    });

    switchTab('dashboard');
}

function hideMenu() {
    document.getElementById('policeMenu').classList.add('hidden');
}

function closeMenu() {
    fetch('https://police_job/closeMenu', { method: 'POST', body: JSON.stringify({}) });
}

/* ═══ Tabs ════════════════════════════════════════════════════ */
function switchTab(tab) {
    document.querySelectorAll('.tab').forEach(function(t) { t.classList.remove('active'); });
    document.querySelectorAll('.tab-content').forEach(function(c) { c.classList.remove('active'); });

    document.querySelector('[data-tab="' + tab + '"]').classList.add('active');
    document.getElementById('tab-' + tab).classList.add('active');

    if (tab === 'actions') {
        fetch('https://police_job/getNearbyPlayers', { method: 'POST', body: JSON.stringify({}) });
    }
    if (tab === 'bank' && isCommander) {
        fetch('https://police_job/openCompanyBank', { method: 'POST', body: JSON.stringify({}) });
    }
}

/* ═══ Duty ════════════════════════════════════════════════════ */
function toggleDuty() {
    fetch('https://police_job/toggleDuty', { method: 'POST', body: JSON.stringify({}) });
    isDuty = !isDuty;
    updateDutyUI();
}

function updateDutyUI() {
    var btn = document.getElementById('btnDuty');
    var txt = document.getElementById('dutyText');
    if (isDuty) {
        btn.classList.remove('off');
        btn.classList.add('on');
        txt.textContent = 'EN SERVICE';
    } else {
        btn.classList.remove('on');
        btn.classList.add('off');
        txt.textContent = 'HORS SERVICE';
    }
}

/* ═══ Stats ═══════════════════════════════════════════════════ */
function updateStats() {
    var online = officers.length;
    var onDuty = officers.filter(function(o) { return o.on_duty; }).length;
    document.getElementById('onlineCount').textContent = online;
    document.getElementById('onDutyCount').textContent = onDuty;
}

/* ═══ Officers List ═══════════════════════════════════════════ */
function renderOfficers() {
    var container = document.getElementById('officersList');
    if (officers.length === 0) {
        container.innerHTML = '<div class="empty-state">Aucun officier en ligne.</div>';
        return;
    }

    var html = '';
    officers.forEach(function(o) {
        html += '<div class="officer-item">';
        html += '  <div style="display:flex;align-items:center;gap:10px">';
        html += '    <div class="officer-status ' + (o.on_duty ? 'on' : 'off') + '"></div>';
        html += '    <span class="officer-name">' + escHtml(o.name) + '</span>';
        html += '    <span class="officer-grade">' + escHtml(o.grade_name) + '</span>';
        html += '  </div>';

        if (isCommander) {
            html += '  <div class="officer-actions">';
            html += '    <select class="grade-select" id="gradeSelect_' + o.src + '">';
            grades.forEach(function(g) {
                var sel = g.name === o.grade_name ? ' selected' : '';
                html += '      <option value="' + escHtml(g.name) + '"' + sel + '>' + escHtml(g.name) + '</option>';
            });
            html += '    </select>';
            html += '    <button class="btn-sm promote" onclick="setOfficerGrade(' + o.src + ')">Changer</button>';
            html += '    <button class="btn-sm fire" onclick="fireOfficer(' + o.src + ')">Virer</button>';
            html += '  </div>';
        }

        html += '</div>';
    });

    container.innerHTML = html;
}

function setOfficerGrade(src) {
    var sel = document.getElementById('gradeSelect_' + src);
    if (!sel) return;
    fetch('https://police_job/setGrade', {
        method: 'POST',
        body: JSON.stringify({ targetId: src, gradeName: sel.value })
    });
}

function fireOfficer(src) {
    if (!confirm('Virer cet officier ?')) return;
    fetch('https://police_job/fireOfficer', {
        method: 'POST',
        body: JSON.stringify({ targetId: src })
    });
}

/* ═══ Grades ══════════════════════════════════════════════════ */
function renderGrades() {
    var container = document.getElementById('gradesList');
    if (grades.length === 0) {
        container.innerHTML = '<div class="empty-state">Aucun grade.</div>';
        return;
    }

    var html = '';
    grades.forEach(function(g) {
        html += '<div class="grade-item">';
        html += '  <div class="grade-info">';
        html += '    <div class="grade-level">' + g.level + '</div>';
        html += '    <span class="grade-name">' + escHtml(g.name) + '</span>';
        html += '  </div>';
        html += '  <div class="grade-salary">';
        html += '    <input type="number" id="salary_' + escHtml(g.name) + '" value="' + g.salary + '" min="0">';
        html += '    <button class="btn-sm save" onclick="saveSalary(\'' + escHtml(g.name) + '\')">$</button>';
        if (g.name !== 'Commandant') {
            html += '    <button class="btn-sm remove" onclick="removeGrade(\'' + escHtml(g.name) + '\')">&times;</button>';
        }
        html += '  </div>';
        html += '</div>';
    });

    container.innerHTML = html;
}

function saveSalary(name) {
    var input = document.getElementById('salary_' + name);
    if (!input) return;
    var val = parseInt(input.value) || 0;
    fetch('https://police_job/setSalary', {
        method: 'POST',
        body: JSON.stringify({ gradeName: name, salary: val })
    });
}

function removeGrade(name) {
    if (!confirm('Supprimer le grade "' + name + '" ?')) return;
    fetch('https://police_job/removeGrade', {
        method: 'POST',
        body: JSON.stringify({ name: name })
    });
}

function addGrade() {
    var name   = document.getElementById('newGradeName').value.trim();
    var level  = parseInt(document.getElementById('newGradeLevel').value) || 0;
    var salary = parseInt(document.getElementById('newGradeSalary').value) || 0;
    if (!name || level <= 0) return;

    fetch('https://police_job/addGrade', {
        method: 'POST',
        body: JSON.stringify({ name: name, level: level, salary: salary })
    });

    document.getElementById('newGradeName').value = '';
    document.getElementById('newGradeLevel').value = '';
    document.getElementById('newGradeSalary').value = '';
}

/* ═══ Nearby Players / Actions ════════════════════════════════ */
function requestNearby(action) {
    currentAction = action;
    switchTab('actions');
}

function renderNearbyPlayers() {
    var container = document.getElementById('nearbyList');
    var title     = document.getElementById('actionTitle');
    var form      = document.getElementById('actionForm');

    form.classList.add('hidden');

    var actionLabels = {
        frisk:    'Fouiller',
        handcuff: 'Menotter',
        fine:     'Amender',
        escort:   'Escorter',
        jail:     'Emprisonner',
        vehicle:  'Mettre en vehicule',
        recruit:  'Recruter',
    };
    title.textContent = (currentAction ? actionLabels[currentAction] || 'Action' : 'Selectionner') + ' — Joueur';

    if (nearbyPlayers.length === 0) {
        container.innerHTML = '<div class="empty-state">Aucun joueur a proximite.</div>';
        return;
    }

    var html = '';
    nearbyPlayers.forEach(function(p) {
        html += '<div class="player-item" onclick="selectPlayer(' + p.src + ', \'' + escHtml(p.name) + '\')">';
        html += '  <span class="player-name">' + escHtml(p.name) + ' (ID: ' + p.src + ')</span>';
        html += '</div>';
    });
    container.innerHTML = html;
}

function selectPlayer(src, name) {
    currentTarget = src;

    if (currentAction === 'frisk') {
        fetch('https://police_job/friskPlayer', { method: 'POST', body: JSON.stringify({ targetId: src }) });
    } else if (currentAction === 'handcuff') {
        fetch('https://police_job/handcuffPlayer', { method: 'POST', body: JSON.stringify({ targetId: src }) });
    } else if (currentAction === 'escort') {
        fetch('https://police_job/escortPlayer', { method: 'POST', body: JSON.stringify({ targetId: src }) });
    } else if (currentAction === 'vehicle') {
        fetch('https://police_job/putInVehicle', { method: 'POST', body: JSON.stringify({ targetId: src }) });
    } else if (currentAction === 'recruit') {
        fetch('https://police_job/recruit', { method: 'POST', body: JSON.stringify({ targetId: src }) });
    } else if (currentAction === 'fine') {
        showFineForm(src, name);
        return;
    } else if (currentAction === 'jail') {
        showJailForm(src, name);
        return;
    }

    closeMenu();
}

function showFineForm(src, name) {
    var form = document.getElementById('actionForm');
    form.classList.remove('hidden');
    form.innerHTML = '<h4>Amender ' + escHtml(name) + '</h4>' +
        '<div class="form-row">' +
        '  <input type="number" id="fineAmount" placeholder="Montant ($)" class="input-field" min="1">' +
        '  <input type="text" id="fineReason" placeholder="Motif" class="input-field">' +
        '  <button class="btn-primary" onclick="submitFine(' + src + ')">Amender</button>' +
        '</div>';
}

function submitFine(src) {
    var amount = parseInt(document.getElementById('fineAmount').value) || 0;
    var reason = document.getElementById('fineReason').value.trim();
    if (amount <= 0 || !reason) return;

    fetch('https://police_job/createFine', {
        method: 'POST',
        body: JSON.stringify({ targetId: src, amount: amount, reason: reason })
    });
    closeMenu();
}

function showJailForm(src, name) {
    var form = document.getElementById('actionForm');
    form.classList.remove('hidden');
    form.innerHTML = '<h4>Emprisonner ' + escHtml(name) + '</h4>' +
        '<div class="form-row">' +
        '  <input type="number" id="jailMinutes" placeholder="Minutes" class="input-field small" min="1" max="999">' +
        '  <button class="btn-primary" onclick="submitJail(' + src + ')">Emprisonner</button>' +
        '</div>';
}

function submitJail(src) {
    var minutes = parseInt(document.getElementById('jailMinutes').value) || 0;
    if (minutes <= 0) return;

    fetch('https://police_job/jailPlayer', {
        method: 'POST',
        body: JSON.stringify({ targetId: src, minutes: minutes })
    });
    closeMenu();
}

/* ═══ Quick actions (no player selection) ════════════════════ */
function doImpound() {
    fetch('https://police_job/impoundVehicle', { method: 'POST', body: JSON.stringify({}) });
}

function doSpikeStrip() {
    fetch('https://police_job/deploySpikeStrip', { method: 'POST', body: JSON.stringify({}) });
}

/* ═══ Frisk ═══════════════════════════════════════════════════ */
function renderFriskInventory(inventory) {
    var container = document.getElementById('friskInventory');
    if (!inventory || inventory.length === 0) {
        container.innerHTML = '<div class="empty-state" style="grid-column:1/-1">Inventaire vide.</div>';
        return;
    }

    var html = '';
    inventory.forEach(function(item, idx) {
        if (item && item.name) {
            html += '<div class="frisk-slot" onclick="confiscateItem(' + idx + ', 1)">';
            html += '  <span class="item-name">' + escHtml(item.name) + '</span>';
            if (item.amount && item.amount > 1) {
                html += '  <span class="item-count">x' + item.amount + '</span>';
            }
            html += '  <button class="confiscate-btn" onclick="event.stopPropagation();confiscateItem(' + idx + ', ' + (item.amount || 1) + ')">X</button>';
            html += '</div>';
        } else {
            html += '<div class="frisk-slot empty"></div>';
        }
    });
    container.innerHTML = html;
}

function confiscateItem(slot, amount) {
    if (!friskTarget) return;
    fetch('https://police_job/confiscateItem', {
        method: 'POST',
        body: JSON.stringify({ targetId: friskTarget, slot: slot, amount: amount })
    });
}

function endFrisk() {
    if (!friskTarget) {
        document.getElementById('friskPanel').classList.add('hidden');
        return;
    }
    fetch('https://police_job/endFrisk', {
        method: 'POST',
        body: JSON.stringify({ targetId: friskTarget })
    });
}

/* ═══ Fines (civilian panel) ══════════════════════════════════ */
function renderFines(fines) {
    var container = document.getElementById('finesList');
    if (!fines || fines.length === 0) {
        container.innerHTML = '<div class="no-fines">Aucune amende en cours.</div>';
        return;
    }

    var html = '';
    fines.forEach(function(f) {
        html += '<div class="fine-item">';
        html += '  <div class="fine-info">';
        html += '    <div class="fine-reason">' + escHtml(f.reason) + '</div>';
        html += '    <div class="fine-date">' + (f.created_at || '') + '</div>';
        html += '  </div>';
        html += '  <div class="fine-amount">$' + formatNum(f.amount) + '</div>';
        html += '  <button class="fine-pay" onclick="payFine(' + f.id + ')">Payer</button>';
        html += '</div>';
    });
    container.innerHTML = html;
}

function payFine(id) {
    fetch('https://police_job/payFine', { method: 'POST', body: JSON.stringify({ fineId: id }) });
}

function closeFines() {
    fetch('https://police_job/closeFines', { method: 'POST', body: JSON.stringify({}) });
}

function showFineNotif(amount, reason) {
    var el = document.getElementById('fineNotif');
    document.getElementById('fineNotifText').textContent = '$' + formatNum(amount) + ' — ' + reason;
    el.classList.remove('hidden');
    setTimeout(function() { el.classList.add('hidden'); }, 8000);
}

/* ═══ Company Bank ════════════════════════════════════════════ */
function renderCompanyBank(data) {
    if (!data) return;
    document.getElementById('companyBalance').textContent = '$' + formatNum(data.balance || 0);
    switchTab('bank');

    var txContainer = document.getElementById('companyTransactions');
    if (!data.transactions || data.transactions.length === 0) {
        txContainer.innerHTML = '<div class="empty-state">Aucune transaction.</div>';
        return;
    }

    var html = '';
    data.transactions.forEach(function(tx) {
        var cls = tx.type === 'credit' ? 'credit' : 'debit';
        var sign = tx.type === 'credit' ? '+' : '-';
        html += '<div class="transaction-item">';
        html += '  <div>';
        html += '    <div class="transaction-label">' + escHtml(tx.label || '—') + '</div>';
        html += '    <div class="transaction-date">' + (tx.date || '') + '</div>';
        html += '  </div>';
        html += '  <div class="transaction-amount ' + cls + '">' + sign + '$' + formatNum(tx.amount) + '</div>';
        html += '</div>';
    });
    txContainer.innerHTML = html;
}

function companyDeposit() {
    var val = parseInt(document.getElementById('bankAmount').value) || 0;
    if (val <= 0) return;
    fetch('https://police_job/companyDeposit', { method: 'POST', body: JSON.stringify({ amount: val }) });
    document.getElementById('bankAmount').value = '';
}

function companyWithdraw() {
    var val = parseInt(document.getElementById('bankAmount').value) || 0;
    if (val <= 0) return;
    fetch('https://police_job/companyWithdraw', { method: 'POST', body: JSON.stringify({ amount: val }) });
    document.getElementById('bankAmount').value = '';
}

/* ═══ Radio ═══════════════════════════════════════════════════ */
function sendRadio() {
    var input = document.getElementById('radioText');
    var msg = input.value.trim();
    if (!msg) return;
    fetch('https://police_job/sendRadio', { method: 'POST', body: JSON.stringify({ message: msg }) });
    addRadioMsg('Vous', msg);
    input.value = '';
}

function addRadioMsg(sender, text) {
    var now = new Date();
    var time = pad(now.getHours()) + ':' + pad(now.getMinutes());
    radioLog.push({ sender: sender, text: text, time: time });
    renderRadio();
}

function renderRadio() {
    var container = document.getElementById('radioMessages');
    var html = '';
    radioLog.forEach(function(m) {
        html += '<div class="radio-msg">';
        html += '  <span class="sender">' + escHtml(m.sender) + '</span>';
        html += '  <span class="msg-text">' + escHtml(m.text) + '</span>';
        html += '  <span class="msg-time">' + m.time + '</span>';
        html += '</div>';
    });
    container.innerHTML = html;
    container.scrollTop = container.scrollHeight;
}

/* ═══ Helpers ═════════════════════════════════════════════════ */
function escHtml(s) {
    if (!s) return '';
    return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

function formatNum(n) {
    return Number(n).toLocaleString('fr-FR');
}

function pad(n) {
    return n < 10 ? '0' + n : String(n);
}
