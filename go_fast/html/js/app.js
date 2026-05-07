/* =============================================
   GO FAST — Timer NUI
   ============================================= */

var timerHud   = document.getElementById('timer-hud');
var timerTime  = document.getElementById('timer-time');
var timerFill  = document.getElementById('timer-bar-fill');

var totalTime  = 0;

window.addEventListener('message', function(event) {
    var data = event.data;

    switch (data.action) {
        case 'showTimer':
            totalTime = data.total || 900;
            updateTimer(data.timeLeft, totalTime);
            timerHud.classList.remove('hidden');
            break;

        case 'updateTimer':
            updateTimer(data.timeLeft, totalTime);
            break;

        case 'hideTimer':
            timerHud.classList.add('hidden');
            break;
    }
});

function updateTimer(timeLeft, total) {
    var mins = Math.floor(timeLeft / 60);
    var secs = timeLeft % 60;
    timerTime.textContent = String(mins).padStart(2, '0') + ':' + String(secs).padStart(2, '0');

    var pct = (timeLeft / total) * 100;
    timerFill.style.width = pct + '%';

    // Couleur selon le temps restant
    timerFill.className = 'timer-bar-fill';
    timerTime.className = 'timer-time';

    if (pct <= 15) {
        timerFill.classList.add('timer-danger');
        timerTime.classList.add('timer-danger');
    } else if (pct <= 35) {
        timerFill.classList.add('timer-warning');
    }
}
