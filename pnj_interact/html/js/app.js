/* =============================================
   PNJ INTERACT — NUI JavaScript
   ============================================= */
'use strict';

// --- DOM refs ---
const thirdeyeOverlay = document.getElementById('thirdeye-overlay');
const thirdeyeLabel   = document.getElementById('thirdeye-label');
const thirdeyePedName = document.getElementById('thirdeye-ped-name');
const dialogueHud     = document.getElementById('dialogue-hud');
const dialogueNpcName = document.getElementById('dialogue-npc-name');
const dialogueText    = document.getElementById('dialogue-text');
const dialogueResp    = document.getElementById('dialogue-responses');
const dialogueClose   = document.getElementById('dialogue-close');
const dialogueAvatar  = document.getElementById('dialogue-npc-avatar');
const trustBar        = document.getElementById('thirdeye-trust-bar');
const trustFill       = document.getElementById('thirdeye-trust-fill');
const trustValue      = document.getElementById('thirdeye-trust-value');
const dlgTrustBar     = document.getElementById('dialogue-trust-bar');
const dlgTrustFill    = document.getElementById('dialogue-trust-fill');
const dlgTrustValue   = document.getElementById('dialogue-trust-value');

// --- State ---
let isThirdEyeVisible = false;
let isDialogueVisible = false;
let typingTimer       = null;

// --- SVG icons pour les réponses ---
const RESPONSE_ICONS = {
    chat: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z"/></svg>',
    wave: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M18 11V6a2 2 0 00-4 0"/><path d="M14 10V4a2 2 0 00-4 0v6"/><path d="M10 10V6a2 2 0 00-4 0v8c0 5 4 8 8 8h1a5 5 0 005-5v-3a2 2 0 00-4 0"/></svg>',
    ask:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="12" cy="12" r="10"/><path d="M9 9a3 3 0 015.12 2.13c0 1.87-2.62 2.37-2.62 4.37"/><circle cx="12" cy="18" r="0.5"/></svg>',
    give: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M20 12H4M4 12l6-6M4 12l6 6"/></svg>',
    info: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01"/></svg>',
    kidnap: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2z"/><path d="M15 9h-6l-1 6h8l-1-6z"/><path d="M9 9V7a3 3 0 016 0v2"/></svg>',
    drill: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M14 2l6 6-8 8-6-6 8-8z"/><path d="M12 10l-8 8 2 2 8-8"/><path d="M4 18l-2 4 4-2"/></svg>',
    atm:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="2" y="4" width="20" height="16" rx="2"/><path d="M12 8v8M9 10h6M9 14h6"/></svg>',
    lock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0110 0v4"/></svg>',
    key:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 11-7.78 7.78 5.5 5.5 0 017.78-7.78zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4"/></svg>',
    car:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M7 17m-2 0a2 2 0 104 0 2 2 0 10-4 0M17 17m-2 0a2 2 0 104 0 2 2 0 10-4 0"/><path d="M5 17H3v-6l2-5h9l4 5h1a2 2 0 012 2v4h-2"/><path d="M9 17h6"/></svg>',
    shop: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>',
};

// Table d'icônes pour le label du troisième œil (par nom d'icône)
const THIRDEYE_ICONS = {
    person: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>',
    atm:   '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="2" y="4" width="20" height="16" rx="2"/><path d="M12 8v8M9 10h6M9 14h6"/></svg>',
    lock:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0110 0v4"/></svg>',
    info:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01"/></svg>',
    shop:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>',
    car:   '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M7 17m-2 0a2 2 0 104 0 2 2 0 10-4 0M17 17m-2 0a2 2 0 104 0 2 2 0 10-4 0"/><path d="M5 17H3v-6l2-5h9l4 5h1a2 2 0 012 2v4h-2"/><path d="M9 17h6"/></svg>',
};

// ═══════════════════════════════════════════
//  NUI MESSAGE HANDLER
// ═══════════════════════════════════════════

window.addEventListener('message', (e) => {
    const data = e.data;

    switch (data.action) {
        case 'showThirdEye':
            showThirdEye();
            break;

        case 'hideThirdEye':
            hideThirdEye();
            break;

        case 'hoverPed':
            showPedLabel(data.pedName, data.isReceiver, data.trust);
            break;

        case 'hoverObject':
            showObjectLabel(data.label, data.icon);
            break;

        case 'unhoverPed':
            hidePedLabel();
            break;

        case 'openDialogue':
            openDialogue(data.pedName, data.dialogue, data.responses, data.headshotUrl, data.isObject, data.objectIcon, data.objectTag, data.isReceiver, data.trust);
            break;

        case 'closeDialogue':
            closeDialogue();
            break;

        case 'showNotification':
            showNotification(data.message, data.type);
            break;
    }
});


// ═══════════════════════════════════════════
//  TROISIÈME ŒIL
// ═══════════════════════════════════════════

function showThirdEye() {
    isThirdEyeVisible = true;
    document.body.classList.add('thirdeye-active');
    thirdeyeOverlay.classList.remove('hidden');
    thirdeyeOverlay.classList.remove('ped-detected');
    thirdeyeLabel.classList.add('hidden');
}

function hideThirdEye() {
    isThirdEyeVisible = false;
    document.body.classList.remove('thirdeye-active');
    thirdeyeOverlay.classList.add('hidden');
    thirdeyeOverlay.classList.remove('ped-detected');
    thirdeyeLabel.classList.add('hidden');
}

function showPedLabel(name, isReceiver, trust) {
    thirdeyePedName.textContent = name || 'Inconnu';
    thirdeyeLabel.classList.remove('hidden');
    thirdeyeOverlay.classList.add('ped-detected');

    if (isReceiver && trustBar) {
        trustBar.classList.remove('hidden');
        var t = Math.max(0, Math.min(100, trust || 0));
        trustFill.style.width = t + '%';
        trustValue.textContent = Math.round(t) + '%';

        // Couleur dynamique selon le niveau
        if (t >= 70) {
            trustFill.className = 'thirdeye-trust-fill trust-high';
        } else if (t >= 30) {
            trustFill.className = 'thirdeye-trust-fill trust-mid';
        } else {
            trustFill.className = 'thirdeye-trust-fill trust-low';
        }
    } else if (trustBar) {
        trustBar.classList.add('hidden');
    }
}

function showObjectLabel(label, iconName) {
    thirdeyePedName.textContent = label || 'Objet';
    thirdeyeLabel.classList.remove('hidden');
    thirdeyeOverlay.classList.add('ped-detected');

    var iconEl = thirdeyeLabel.querySelector('.thirdeye-label-icon');
    if (iconEl && THIRDEYE_ICONS[iconName]) {
        iconEl.innerHTML = THIRDEYE_ICONS[iconName];
    } else if (iconEl && iconName) {
        iconEl.innerHTML = THIRDEYE_ICONS['info'];
    }
}

function hidePedLabel() {
    thirdeyeLabel.classList.add('hidden');
    thirdeyeOverlay.classList.remove('ped-detected');

    // Remettre l'icône PNJ par défaut
    var iconEl = thirdeyeLabel.querySelector('.thirdeye-label-icon');
    if (iconEl) {
        iconEl.innerHTML = THIRDEYE_ICONS['person'];
    }

    // Cacher la barre de confiance
    if (trustBar) {
        trustBar.classList.add('hidden');
    }
}


// ═══════════════════════════════════════════
//  DIALOGUE HUD
// ═══════════════════════════════════════════

function openDialogue(pedName, text, responses, headshotUrl, isObject, objectIcon, objectTag, isReceiver, trust) {
    // Cacher le troisième œil
    document.body.classList.remove('thirdeye-active');
    thirdeyeOverlay.classList.add('hidden');
    thirdeyeOverlay.classList.remove('ped-detected');

    // Remplir les infos
    dialogueNpcName.textContent = pedName || 'Inconnu';

    // Tag (Habitant / Distributeur / custom)
    var tagEl = document.querySelector('.dialogue-npc-tag');
    if (tagEl) {
        tagEl.textContent = isObject ? (objectTag || 'Objet') : 'Habitant';
    }

    // Avatar : headshot du PNJ, icône objet, ou icône par défaut
    if (dialogueAvatar) {
        // Toujours vider l'ancien contenu d'abord
        dialogueAvatar.innerHTML = '';
        dialogueAvatar.classList.remove('has-headshot');

        if (isObject && objectIcon && RESPONSE_ICONS[objectIcon]) {
            dialogueAvatar.innerHTML = RESPONSE_ICONS[objectIcon];
        } else if (headshotUrl) {
            const img = document.createElement('img');
            img.src = headshotUrl;
            img.alt = 'PNJ';
            img.onerror = function() {
                // Fallback si l'image ne charge pas
                dialogueAvatar.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>';
                dialogueAvatar.classList.remove('has-headshot');
            };
            dialogueAvatar.appendChild(img);
            dialogueAvatar.classList.add('has-headshot');
        } else {
            dialogueAvatar.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>';
        }
    }

    // Effet machine à écrire
    typeText(text || '...');

    // Générer les boutons de réponse
    dialogueResp.innerHTML = '';
    if (responses && responses.length > 0) {
        responses.forEach((resp, idx) => {
            const btn = document.createElement('button');
            btn.className = 'response-btn';

            // Numero raccourci
            const keyEl = document.createElement('span');
            keyEl.className = 'response-key';
            keyEl.textContent = idx + 1;
            btn.appendChild(keyEl);

            // Icone
            if (resp.icon && RESPONSE_ICONS[resp.icon]) {
                const iconEl = document.createElement('span');
                iconEl.className = 'response-icon';
                iconEl.innerHTML = RESPONSE_ICONS[resp.icon];
                btn.appendChild(iconEl);
            }

            // Texte
            const textEl = document.createElement('span');
            textEl.textContent = resp.label;
            btn.appendChild(textEl);

            btn.addEventListener('click', () => {
                postNUI('selectResponse', { index: idx, label: resp.label, action: resp.action || 'talk' });
            });

            dialogueResp.appendChild(btn);
        });
    }

    // Barre de confiance dans le dialogue
    if (isReceiver && dlgTrustBar) {
        dlgTrustBar.classList.remove('hidden');
        var t = Math.max(0, Math.min(100, trust || 0));
        dlgTrustFill.style.width = t + '%';
        dlgTrustValue.textContent = Math.round(t) + '%';

        if (t >= 70) {
            dlgTrustFill.className = 'dialogue-trust-fill trust-high';
        } else if (t >= 30) {
            dlgTrustFill.className = 'dialogue-trust-fill trust-mid';
        } else {
            dlgTrustFill.className = 'dialogue-trust-fill trust-low';
        }
    } else if (dlgTrustBar) {
        dlgTrustBar.classList.add('hidden');
    }

    // Afficher
    isDialogueVisible = true;
    dialogueHud.classList.remove('hidden');
}

function closeDialogue() {
    isDialogueVisible = false;
    dialogueHud.classList.add('hidden');

    if (typingTimer) {
        clearTimeout(typingTimer);
        typingTimer = null;
    }
}

// Effet typewriter
function typeText(fullText) {
    // Annuler l'ancien typewriter s'il est encore en cours
    if (typingTimer) {
        clearTimeout(typingTimer);
        typingTimer = null;
    }

    dialogueText.textContent = '';
    dialogueText.classList.add('typing-anim');

    const indicator = document.querySelector('.dialogue-indicator');
    if (indicator) indicator.classList.add('typing');

    let i = 0;
    const speed = 25;

    function typeChar() {
        if (i < fullText.length) {
            dialogueText.textContent += fullText.charAt(i);
            i++;
            typingTimer = setTimeout(typeChar, speed);
        } else {
            dialogueText.classList.remove('typing-anim');
            if (indicator) indicator.classList.remove('typing');
        }
    }

    typeChar();
}


// ═══════════════════════════════════════════
//  EVENTS
// ═══════════════════════════════════════════

// Bouton fermer dialogue
dialogueClose.addEventListener('click', () => {
    postNUI('closeDialogue', {});
});

// ESC pour fermer
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        if (isDialogueVisible) {
            postNUI('closeDialogue', {});
        } else if (isThirdEyeVisible) {
            postNUI('closeThirdEye', {});
        }
    }

    // Raccourcis numériques pour les réponses
    if (isDialogueVisible && e.key >= '1' && e.key <= '9') {
        const idx = parseInt(e.key) - 1;
        const btns = dialogueResp.querySelectorAll('.response-btn');
        if (btns[idx]) {
            btns[idx].click();
        }
    }
});

// Clic droit = fermer troisième œil
document.addEventListener('contextmenu', (e) => {
    e.preventDefault();
    if (isThirdEyeVisible && !isDialogueVisible) {
        postNUI('closeThirdEye', {});
    }
});


// ═══════════════════════════════════════════
//  NUI CALLBACK
// ═══════════════════════════════════════════

function postNUI(event, data) {
    fetch(`https://pnj_interact/${event}`, {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify(data),
    }).catch(() => {});
}


// ═══════════════════════════════════════════
//  NOTIFICATIONS
// ═══════════════════════════════════════════

function showNotification(message, type) {
    // Supprimer l'ancienne notification si elle existe
    const existing = document.getElementById('notification');
    if (existing) existing.remove();

    const notif = document.createElement('div');
    notif.id = 'notification';
    notif.className = 'notification ' + (type || 'info');
    notif.textContent = message;
    document.body.appendChild(notif);

    // Disparaît après 4 secondes
    setTimeout(() => {
        notif.classList.add('fade-out');
        setTimeout(() => notif.remove(), 500);
    }, 4000);
}
