/* ═══════════════════════════════════════════
   PERMIS DE CONDUIRE — NUI
   Quiz + Notifications
   ═══════════════════════════════════════════ */
'use strict';

var questions     = [];
var currentIndex  = 0;
var answers       = {};
var correctAnswers = {};
var requiredScore = 7;
var answered      = false;
var resourceName  = 'driving_license';
var scoreRight    = 0;
var scoreWrongCount = 0;

var overlay        = document.getElementById('quiz-overlay');
var container      = document.getElementById('quiz-container');
var questionText   = document.getElementById('question-text');
var choicesDiv     = document.getElementById('choices-container');
var progressText   = document.getElementById('progress-text');
var progressFill   = document.getElementById('progress-fill');
var scoreCorrect   = document.getElementById('score-correct');
var scoreWrong     = document.getElementById('score-wrong');
var btnNext        = document.getElementById('btn-next');

// ─── Notification Icons ──────────────────────────────────────────────────────

var NOTIF_ICONS = {
    success: '\u2714',
    warning: '\u26A0',
    error:   '\u2716',
    info:    '\uD83D\uDCCB',
};

// ─── NUI Messages ────────────────────────────────────────────────────────────

window.addEventListener('message', function(e) {
    var data = e.data;

    if (data.action === 'openQuiz') {
        resourceName   = data.resourceName || 'driving_license';
        questions      = data.questions || [];
        correctAnswers = data.correctAnswers || {};
        requiredScore  = data.required || 7;
        currentIndex   = 0;
        answers        = {};
        answered       = false;
        scoreRight     = 0;
        scoreWrongCount = 0;

        scoreCorrect.textContent = '\u2713 0';
        scoreWrong.textContent   = '\u2717 0';

        overlay.classList.remove('hidden');
        container.classList.remove('hidden');

        showQuestion();
    }

    if (data.type === 'showNotification') {
        showNotification(
            data.style    || 'info',
            data.title    || 'Auto-\u00C9cole',
            data.text     || '',
            data.duration || 5000
        );
    }
});

// ─── Notifications ───────────────────────────────────────────────────────────

function showNotification(style, title, text, duration) {
    var notifContainer = document.getElementById('notif-container');
    if (!notifContainer) return;

    duration = duration || 5000;

    var notif = document.createElement('div');
    notif.className = 'notif' + (style !== 'info' ? ' notif-' + style : '');

    var icon = NOTIF_ICONS[style] || NOTIF_ICONS.info;

    notif.innerHTML =
        '<div class="notif-icon">' + icon + '</div>' +
        '<div class="notif-body">' +
            '<span class="notif-title">' + escapeHtml(title) + '</span>' +
            '<span class="notif-text">' + escapeHtml(text) + '</span>' +
        '</div>';

    notifContainer.appendChild(notif);

    setTimeout(function() {
        notif.classList.add('notif-hide');
        setTimeout(function() {
            if (notif.parentNode) notif.parentNode.removeChild(notif);
        }, 400);
    }, duration);
}

function escapeHtml(str) {
    if (!str) return '';
    var div = document.createElement('div');
    div.appendChild(document.createTextNode(str));
    return div.innerHTML;
}

// ─── Quiz: Afficher une question ─────────────────────────────────────────────

function showQuestion() {
    if (currentIndex >= questions.length) {
        submitAnswers();
        return;
    }

    answered = false;
    btnNext.classList.add('hidden');

    var q = questions[currentIndex];
    var total = questions.length;

    progressText.textContent = 'Question ' + (currentIndex + 1) + '/' + total;
    progressFill.style.width = ((currentIndex + 1) / total * 100) + '%';

    questionText.textContent = q.question;

    choicesDiv.innerHTML = '';
    var letters = ['A', 'B', 'C', 'D'];

    q.choices.forEach(function(choice, idx) {
        var btn = document.createElement('button');
        btn.className = 'choice-btn';
        btn.innerHTML = '<span class="choice-letter">' + letters[idx] + '</span>' +
                        '<span>' + escapeHtml(choice) + '</span>';
        btn.onclick = function() { selectAnswer(idx + 1); };
        choicesDiv.appendChild(btn);
    });
}

// ─── Quiz: Sélectionner une réponse ──────────────────────────────────────────

function selectAnswer(choiceIndex) {
    if (answered) return;
    answered = true;

    var q = questions[currentIndex];
    answers[String(q.index)] = choiceIndex;

    var buttons = choicesDiv.querySelectorAll('.choice-btn');
    buttons.forEach(function(btn, idx) {
        btn.style.pointerEvents = 'none';
        if (idx + 1 === choiceIndex) {
            btn.style.background = 'rgba(79, 195, 247, 0.25)';
            btn.style.borderColor = 'rgba(79, 195, 247, 0.6)';
            btn.style.color = '#4fc3f7';
        } else {
            btn.classList.add('disabled');
        }
    });

    if (currentIndex < questions.length - 1) {
        btnNext.classList.remove('hidden');
    } else {
        setTimeout(function() {
            submitAnswers();
        }, 800);
    }
}

// ─── Quiz: Question suivante ─────────────────────────────────────────────────

function nextQuestion() {
    currentIndex++;
    showQuestion();
}

// ─── Quiz: Soumettre les réponses ────────────────────────────────────────────

function submitAnswers() {
    overlay.classList.add('hidden');
    postNUI('quizFinished', { answers: answers });
}

// ─── Quiz: Fermer / Abandonner ───────────────────────────────────────────────

function closeQuiz() {
    overlay.classList.add('hidden');
    postNUI('quizClosed', {});
}

// ─── Touche Echap ────────────────────────────────────────────────────────────

document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && !overlay.classList.contains('hidden')) {
        closeQuiz();
    }
});

// ─── NUI Callback ────────────────────────────────────────────────────────────

function postNUI(event, data) {
    fetch('https://' + resourceName + '/' + event, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {}),
    });
}
