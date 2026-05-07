// ============================================================
//  BANK SYSTEM — NUI SCRIPT
// ============================================================

var bankData = null;

// ─── NUI Message Handler ─────────────────────────────────────
window.addEventListener('message', function(event) {
    var msg = event.data;

    if (msg.action === 'open') {
        bankData = msg.data;
        populateUI(bankData);
        document.getElementById('bank-container').classList.remove('hidden');
        switchPage('dashboard');
    }

    if (msg.action === 'close') {
        document.getElementById('bank-container').classList.add('hidden');
        bankData = null;
    }

    if (msg.action === 'error') {
        showOperationMsg('deposit', msg.message, 'error');
        showOperationMsg('withdraw', msg.message, 'error');
    }

    if (msg.action === 'success') {
        showOperationMsg('deposit', msg.message, 'success');
        showOperationMsg('withdraw', msg.message, 'success');
        // Vider les inputs
        var depInput = document.getElementById('deposit-amount');
        var witInput = document.getElementById('withdraw-amount');
        if (depInput) depInput.value = '';
        if (witInput) witInput.value = '';
    }
});

// ─── Peupler l'interface ─────────────────────────────────────
function populateUI(data) {
    if (!data) return;

    var fullName  = (data.firstname || '') + ' ' + (data.lastname || '');
    var initials  = ((data.firstname || 'X')[0] + (data.lastname || 'X')[0]).toUpperCase();
    var balance   = data.balance || 0;
    var accountNr = data.accountNumber || 'XXXXXXXX';
    var lastFour  = accountNr.slice(-4);

    // Sidebar
    document.getElementById('user-name').textContent      = fullName;
    document.getElementById('user-account-short').textContent = accountNr;
    document.getElementById('user-avatar').textContent    = initials;

    // Dashboard stats
    document.getElementById('stat-balance').textContent     = formatMoney(balance);
    document.getElementById('stat-deposits').textContent    = formatMoney(data.totalDeposits || 0);
    document.getElementById('stat-withdrawals').textContent = formatMoney(data.totalWithdrawals || 0);

    // Card
    document.getElementById('card-number').textContent = '\u2022\u2022\u2022\u2022 \u2022\u2022\u2022\u2022 \u2022\u2022\u2022\u2022 ' + lastFour;
    document.getElementById('card-holder').textContent = fullName;

    // Details
    document.getElementById('detail-account').textContent = accountNr;
    document.getElementById('detail-created').textContent = formatDate(data.createdAt);

    // Withdraw balance
    document.getElementById('withdraw-balance').textContent = formatMoney(balance);

    // Account page
    document.getElementById('account-avatar-lg').textContent = initials;
    document.getElementById('account-fullname').textContent  = fullName;
    document.getElementById('account-number').textContent    = accountNr;
    document.getElementById('account-balance').textContent   = formatMoney(balance);
    document.getElementById('account-created').textContent   = formatDate(data.createdAt);
    document.getElementById('account-total-dep').textContent = formatMoney(data.totalDeposits || 0);
    document.getElementById('account-total-wit').textContent = formatMoney(data.totalWithdrawals || 0);

    // Transactions
    renderTransactions('recent-list', data.transactions, 5);
    renderTransactions('transactions-list', data.transactions, 50);
}

// ─── Formater l'argent ───────────────────────────────────────
function formatMoney(amount) {
    return '$' + Number(amount).toLocaleString('fr-FR');
}

// ─── Formater la date ────────────────────────────────────────
function formatDate(dateStr) {
    if (!dateStr || dateStr === 'Inconnu') return 'Inconnu';
    try {
        var d = new Date(dateStr);
        var day   = String(d.getDate()).padStart(2, '0');
        var month = String(d.getMonth() + 1).padStart(2, '0');
        var year  = d.getFullYear();
        var hour  = String(d.getHours()).padStart(2, '0');
        var min   = String(d.getMinutes()).padStart(2, '0');
        return day + '/' + month + '/' + year + ' ' + hour + ':' + min;
    } catch(e) {
        return dateStr;
    }
}

// ─── Rendu des transactions ──────────────────────────────────
function renderTransactions(containerId, transactions, limit) {
    var container = document.getElementById(containerId);
    if (!container) return;

    if (!transactions || transactions.length === 0) {
        container.innerHTML = '<div class="empty-state">Aucune transaction</div>';
        return;
    }

    var html = '';
    var max  = Math.min(transactions.length, limit || 50);

    for (var i = 0; i < max; i++) {
        var tx     = transactions[i];
        var isDepo = tx.type === 'deposit';
        var icon   = isDepo ? '⬇' : '⬆';
        var cls    = isDepo ? 'deposit'  : 'withdrawal';
        var label  = isDepo ? 'Depot'    : 'Retrait';
        var sign   = isDepo ? '+' : '-';
        var amtCls = isDepo ? 'positive' : 'negative';

        html += '<div class="tx-item">';
        html += '  <div class="tx-icon ' + cls + '">' + icon + '</div>';
        html += '  <div class="tx-info">';
        html += '    <div class="tx-type">' + label + '</div>';
        html += '    <div class="tx-date">' + formatDate(tx.date) + '</div>';
        html += '  </div>';
        html += '  <div class="tx-amount ' + amtCls + '">' + sign + formatMoney(tx.amount) + '</div>';
        html += '</div>';
    }

    container.innerHTML = html;
}

// ─── Navigation ──────────────────────────────────────────────
function switchPage(page) {
    // Pages
    var pages = document.querySelectorAll('.page');
    for (var i = 0; i < pages.length; i++) {
        pages[i].classList.remove('active');
    }
    var target = document.getElementById('page-' + page);
    if (target) target.classList.add('active');

    // Nav buttons
    var btns = document.querySelectorAll('.nav-btn');
    for (var j = 0; j < btns.length; j++) {
        btns[j].classList.remove('active');
        if (btns[j].getAttribute('data-page') === page) {
            btns[j].classList.add('active');
        }
    }

    // Clear messages
    clearMessages();
}

// ─── Montants rapides ────────────────────────────────────────
function setAmount(type, amount) {
    document.getElementById(type + '-amount').value = amount;
}

function setAmountAll(type) {
    if (!bankData) return;
    if (type === 'withdraw') {
        document.getElementById('withdraw-amount').value = bankData.balance || 0;
    } else {
        // Pour deposit, on ne connaît pas le cash en poche depuis le NUI
        // On met un montant max symbolique que le serveur validera
        document.getElementById('deposit-amount').value = 999999999;
    }
}

// ─── Actions ─────────────────────────────────────────────────
function doDeposit() {
    var amount = parseInt(document.getElementById('deposit-amount').value) || 0;
    if (amount <= 0) {
        showOperationMsg('deposit', 'Entrez un montant valide.', 'error');
        return;
    }
    clearMessages();
    fetch('https://bank_system/deposit', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ amount: amount })
    });
}

function doWithdraw() {
    var amount = parseInt(document.getElementById('withdraw-amount').value) || 0;
    if (amount <= 0) {
        showOperationMsg('withdraw', 'Entrez un montant valide.', 'error');
        return;
    }
    if (bankData && amount > bankData.balance) {
        showOperationMsg('withdraw', 'Solde insuffisant.', 'error');
        return;
    }
    clearMessages();
    fetch('https://bank_system/withdraw', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ amount: amount })
    });
}

// ─── Messages ────────────────────────────────────────────────
function showOperationMsg(type, message, cls) {
    var el = document.getElementById(type + '-msg');
    if (el) {
        el.textContent = message;
        el.className   = 'operation-msg ' + cls;
    }
}

function clearMessages() {
    var msgs = document.querySelectorAll('.operation-msg');
    for (var i = 0; i < msgs.length; i++) {
        msgs[i].className = 'operation-msg';
        msgs[i].textContent = '';
    }
}

// ─── Fermer ──────────────────────────────────────────────────
function closeBank() {
    document.getElementById('bank-container').classList.add('hidden');
    fetch('https://bank_system/close', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

// ─── Escape pour fermer ──────────────────────────────────────
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        closeBank();
    }
});

// ─── Enter pour valider ──────────────────────────────────────
document.addEventListener('keydown', function(e) {
    if (e.key === 'Enter') {
        var depPage = document.getElementById('page-deposit');
        var witPage = document.getElementById('page-withdraw');
        if (depPage && depPage.classList.contains('active')) {
            doDeposit();
        } else if (witPage && witPage.classList.contains('active')) {
            doWithdraw();
        }
    }
});
