// app.js - iFruit 17 Pro Max NUI (Contacts + Messages)

let isOpen = false;
let isLocked = true;
let cameraMode = false;
let isFrontCamera = false;

// Donnees du joueur
let myPhoneNumber = null;
let myDisplayName = 'Joueur';
let contactsList = [];
let currentChatNumber = null;
let currentChatName = null;
let currentScreen = 'home';
let isPhoneSetup = false;
let setupCheckTimer = null;
let numberCheckAvailable = false;

// Appels
let callState = null; // null, 'outgoing', 'incoming', 'active'
let callNumber = null;
let callName = null;
let callTimerInterval = null;
let callSeconds = 0;
let isMuted = false;
let isSpeaker = false;

// ==================== NOTIFICATION POPUP ====================

let notifTimer = null;
let notifQueue = [];
let notifShowing = false;

function showPhoneNotification(appName, senderName, messageText, appColor) {
    var notif = { appName: appName, senderName: senderName, messageText: messageText, appColor: appColor };

    if (notifShowing) {
        notifQueue.push(notif);
        return;
    }

    displayNotification(notif);
}

function displayNotification(notif) {
    notifShowing = true;

    var container = document.getElementById('notif-container');
    var appNameEl = document.getElementById('notif-app-name');
    var senderEl = document.getElementById('notif-sender');
    var textEl = document.getElementById('notif-text');
    var iconEl = document.getElementById('notif-app-icon');
    var timeEl = document.getElementById('notif-status-time');

    appNameEl.textContent = notif.appName || 'Messages';
    senderEl.textContent = notif.senderName || 'Inconnu';
    textEl.textContent = notif.messageText || '';

    if (notif.appColor) {
        iconEl.style.background = notif.appColor;
    } else {
        iconEl.style.background = 'linear-gradient(145deg, #5bd66a, #2eb84d)';
    }

    var now = new Date();
    var options = { timeZone: 'Europe/Paris', hour: '2-digit', minute: '2-digit', hour12: false };
    timeEl.textContent = now.toLocaleTimeString('fr-FR', options);

    container.classList.remove('notif-hidden', 'notif-closing');
    container.classList.add('notif-visible');

    if (notifTimer) clearTimeout(notifTimer);
    notifTimer = setTimeout(function() {
        hidePhoneNotification();
    }, 5000);
}

function hidePhoneNotification() {
    var container = document.getElementById('notif-container');
    container.classList.remove('notif-visible');
    container.classList.add('notif-closing');

    setTimeout(function() {
        container.classList.remove('notif-closing');
        container.classList.add('notif-hidden');
        notifShowing = false;

        if (notifQueue.length > 0) {
            var next = notifQueue.shift();
            displayNotification(next);
        }
    }, 450);
}

// ==================== NUI MESSAGES ====================

window.addEventListener('message', function(event) {
    const data = event.data;

    switch (data.action) {
        case 'open':
            openPhone();
            break;
        case 'close':
            closePhone();
            break;
        case 'openCamera':
            showCameraUI(data.frontCamera);
            break;
        case 'closeCamera':
            hideCameraUI();
            break;
        case 'switchCamera':
            updateCameraUI(data.frontCamera);
            break;
        case 'photoFlash':
            triggerFlash();
            break;
        case 'showCursor':
            setCursorVisible(true);
            break;
        case 'hideCursor':
            setCursorVisible(false);
            break;

        // Configuration initiale
        case 'setupStatus':
            isPhoneSetup = data.isSetup;
            if (data.isSetup) {
                myPhoneNumber = data.number;
                myDisplayName = data.name || 'Joueur';
                updateMyProfile();
            } else {
                myDisplayName = data.name || 'Joueur';
                document.getElementById('setup-player-name').textContent = myDisplayName;
                showSetupAfterUnlock();
            }
            break;
        case 'numberAvailableResult':
            showNumberAvailability(data.available, data.error);
            break;
        case 'registerResult':
            if (data.success) {
                isPhoneSetup = true;
                showScreen('home');
            } else {
                showSetupError(data.error || 'Erreur lors de l\'enregistrement');
            }
            break;

        // Appels
        case 'incomingCall':
            showIncomingCall(data.callerNumber, data.callerName);
            break;
        case 'callAccepted':
            showActiveCall();
            break;
        case 'callRejected':
        case 'callEnded':
            endCallUI();
            break;
        case 'callFailed':
            showCallFailedMessage(data.reason || 'Appel échoué');
            break;

        // Contacts & Messages
        case 'setMyInfo':
            myPhoneNumber = data.number;
            myDisplayName = data.name || 'Joueur';
            updateMyProfile();
            break;
        case 'updateContacts':
            contactsList = data.contacts || [];
            renderContactsList();
            break;
        case 'contactAddResult':
            if (data.success) {
                showScreen('contacts');
            } else {
                showFormError(data.error || 'Erreur lors de l\'ajout');
            }
            break;
        case 'contactDeleteResult':
            break;
        case 'updateConversations':
            renderConversationsList(data.conversations || []);
            break;
        case 'updateMessages':
            renderChatMessages(data.messages || [], data.otherNumber);
            break;
        case 'messageSentResult':
            if (data.success) {
                document.getElementById('chat-input').value = '';
            }
            break;
        case 'refreshCurrentConversation':
            if (currentScreen === 'chat' && currentChatNumber) {
                fetch('https://custom_phone/openConversation', {
                    method: 'POST',
                    body: JSON.stringify({ number: currentChatNumber }),
                });
            }
            break;
        case 'newMessageNotification':
            if (isOpen && currentScreen === 'chat' && currentChatNumber === data.senderNumber) {
                fetch('https://custom_phone/openConversation', {
                    method: 'POST',
                    body: JSON.stringify({ number: currentChatNumber }),
                });
            } else if (isOpen && currentScreen === 'messages') {
                fetch('https://custom_phone/openMessages', {
                    method: 'POST',
                    body: JSON.stringify({}),
                });
            }
            if (!isOpen) {
                var senderDisplay = data.contactName || data.senderDisplayName || data.senderNumber;
                showPhoneNotification('Messages', senderDisplay, data.message, null);
            }
            break;

        // Services
        case 'updateServices':
            renderServicesList(data.services || []);
            break;
        case 'updateServiceMessages':
            renderServiceChatMessages(data.messages || []);
            break;
        case 'serviceMessageSent':
            if (data.success) {
                document.getElementById('service-chat-input').value = '';
            }
            break;
        case 'refreshServiceChat':
            if (currentScreen === 'serviceChat' && currentServiceJob) {
                fetch('https://custom_phone/getServiceMessages', {
                    method: 'POST',
                    body: JSON.stringify({ job: currentServiceJob }),
                });
            }
            break;
        case 'newServiceMessage':
            if (isOpen && currentScreen === 'serviceChat' && currentServiceJob === data.job) {
                fetch('https://custom_phone/getServiceMessages', {
                    method: 'POST',
                    body: JSON.stringify({ job: currentServiceJob }),
                });
            }
            if (!isOpen) {
                var serviceLabel = data.serviceName || data.job || 'Service';
                var serviceSender = data.senderName || 'Membre';
                showPhoneNotification(serviceLabel, serviceSender, data.message, 'linear-gradient(145deg, #5856d6, #3634a3)');
            }
            break;
        case 'incomingServiceCall':
            showIncomingCall(data.callerNumber, 'Appel ' + data.serviceName);
            break;
    }
});

// ==================== CLAVIER ====================

document.addEventListener('keydown', function(e) {
    if ((e.key === 'Escape' || e.key === 'F1') && isOpen) {
        e.preventDefault();
        if (cameraMode) {
            fetch('https://custom_phone/closeCamera', {
                method: 'POST',
                body: JSON.stringify({}),
            });
        } else {
            if (callState) {
                if (callState === 'incoming') {
                    fetch('https://custom_phone/rejectCall', { method: 'POST', body: JSON.stringify({}) });
                } else {
                    fetch('https://custom_phone/hangupCall', { method: 'POST', body: JSON.stringify({}) });
                }
                endCallUI();
            }
            closePhone();
            fetch('https://custom_phone/closePhone', {
                method: 'POST',
                body: JSON.stringify({}),
            });
        }
    }
    // ALT toggle : desactiver/reactiver la souris
    if (e.key === 'Alt' && isOpen && !cameraMode) {
        e.preventDefault();
        fetch('https://custom_phone/togglePhoneMouse', {
            method: 'POST',
            body: JSON.stringify({}),
        });
    }
});

// ==================== HORLOGE ====================

function getFranceTime() {
    const now = new Date();
    const options = { timeZone: 'Europe/Paris', hour: '2-digit', minute: '2-digit', hour12: false };
    return now.toLocaleTimeString('fr-FR', options);
}

function getFranceDate() {
    const now = new Date();
    const options = { timeZone: 'Europe/Paris', weekday: 'long', day: 'numeric', month: 'long' };
    let dateStr = now.toLocaleDateString('fr-FR', options);
    return dateStr.charAt(0).toUpperCase() + dateStr.slice(1);
}

function updateTimeDisplay() {
    const time = getFranceTime();
    const date = getFranceDate();
    const statusTime = document.getElementById('status-time');
    const homeTime = document.getElementById('home-time');
    const homeDate = document.getElementById('home-date');
    const lockTime = document.getElementById('lock-time');
    const lockDate = document.getElementById('lock-date');
    if (statusTime) statusTime.textContent = time;
    if (homeTime) homeTime.textContent = time;
    if (homeDate) homeDate.textContent = date;
    if (lockTime) lockTime.textContent = time;
    if (lockDate) lockDate.textContent = date;
}

// ==================== TELEPHONE ====================

function openPhone() {
    isOpen = true;
    isLocked = true;

    if (notifShowing) {
        hidePhoneNotification();
    }

    const container = document.getElementById('phone-container');
    const lockScreen = document.getElementById('lock-screen');
    const homeScreen = document.getElementById('home-screen');
    const dock = document.getElementById('dock');

    lockScreen.classList.remove('unlocking', 'hidden');
    lockScreen.style.transform = '';
    lockScreen.style.transition = '';
    homeScreen.classList.remove('screen-visible');
    homeScreen.classList.add('screen-hidden');
    homeScreen.style.opacity = '';
    dock.classList.add('dock-hidden');

    hideAllAppScreens();

    container.classList.remove('hidden', 'closing');
    container.classList.add('opening');
    updateTimeDisplay();

    setTimeout(function() {
        container.classList.remove('opening');
    }, 400);
}

function completeUnlock() {
    if (!isLocked) return;
    isLocked = false;
    const lockScreen = document.getElementById('lock-screen');
    const homeScreen = document.getElementById('home-screen');
    const dock = document.getElementById('dock');

    lockScreen.style.transition = 'transform 0.3s ease, opacity 0.3s ease';
    lockScreen.style.transform = 'translateY(-100%)';
    lockScreen.style.opacity = '0';
    homeScreen.style.transition = 'opacity 0.3s ease';
    homeScreen.style.opacity = '1';

    setTimeout(function() {
        lockScreen.classList.add('hidden');
        lockScreen.style.transform = '';
        lockScreen.style.opacity = '';
        lockScreen.style.transition = '';
        homeScreen.classList.remove('screen-hidden');
        homeScreen.classList.add('screen-visible');
        homeScreen.style.opacity = '';
        homeScreen.style.transition = '';
        dock.classList.remove('dock-hidden');
        currentScreen = 'home';
    }, 300);
}

function cancelUnlock() {
    const lockScreen = document.getElementById('lock-screen');
    const homeScreen = document.getElementById('home-screen');

    lockScreen.style.transition = 'transform 0.3s ease, opacity 0.3s ease';
    lockScreen.style.transform = 'translateY(0)';
    lockScreen.style.opacity = '1';
    homeScreen.style.transition = 'opacity 0.3s ease';
    homeScreen.style.opacity = '0';

    setTimeout(function() {
        lockScreen.style.transition = '';
        homeScreen.style.transition = '';
    }, 300);
}

// Slide to unlock
let isDragging = false;
let dragStartY = 0;
let screenHeight = 0;

function initDrag(e) {
    if (!isOpen || !isLocked) return;
    e.preventDefault();
    isDragging = true;
    const phoneScreen = document.getElementById('phone-screen');
    screenHeight = phoneScreen.offsetHeight;
    dragStartY = e.type === 'touchstart' ? e.touches[0].clientY : e.clientY;
    const homeScreen = document.getElementById('home-screen');
    homeScreen.classList.remove('screen-hidden');
    homeScreen.style.opacity = '0';
}

function onDrag(e) {
    if (!isDragging) return;
    e.preventDefault();
    const currentY = e.type === 'touchmove' ? e.touches[0].clientY : e.clientY;
    let deltaY = dragStartY - currentY;
    if (deltaY < 0) deltaY = 0;
    if (deltaY > screenHeight) deltaY = screenHeight;
    const progress = deltaY / screenHeight;
    const lockScreen = document.getElementById('lock-screen');
    const homeScreen = document.getElementById('home-screen');
    lockScreen.style.transform = 'translateY(-' + deltaY + 'px)';
    lockScreen.style.opacity = String(1 - progress * 0.5);
    homeScreen.style.opacity = String(progress);
}

function endDrag(e) {
    if (!isDragging) return;
    isDragging = false;
    const currentY = e.type === 'touchend' ? e.changedTouches[0].clientY : e.clientY;
    const deltaY = dragStartY - currentY;
    const progress = deltaY / screenHeight;
    if (progress > 0.3) {
        completeUnlock();
    } else {
        cancelUnlock();
    }
}

function closePhone() {
    if (!isOpen) return;
    isOpen = false;
    const container = document.getElementById('phone-container');
    container.classList.add('closing');
    setTimeout(function() {
        container.classList.remove('closing');
        container.classList.add('hidden');
        hideAllAppScreens();
        currentScreen = 'home';
    }, 300);
}

// ==================== NAVIGATION ECRANS ====================

function hideAllAppScreens() {
    var screens = ['contacts-screen', 'add-contact-screen', 'messages-screen', 'chat-screen', 'new-message-screen', 'call-outgoing-screen', 'call-incoming-screen', 'call-active-screen', 'services-screen', 'service-chat-screen'];
    screens.forEach(function(id) {
        var el = document.getElementById(id);
        if (el) {
            el.classList.remove('screen-visible');
            el.classList.add('screen-hidden');
        }
    });
}

function showScreen(name) {
    // Si le telephone n'est pas configure et on essaie d'aller ailleurs que setup
    // Les ecrans d'appel sont toujours accessibles
    if (!isPhoneSetup && name !== 'setup' && name !== 'home' && name !== 'callIncoming' && name !== 'callOutgoing' && name !== 'callActive') {
        return;
    }

    var homeScreen = document.getElementById('home-screen');
    var dock = document.getElementById('dock');

    hideAllAppScreens();

    // Masquer aussi le setup screen
    var setupScreen = document.getElementById('setup-screen');
    if (setupScreen) {
        setupScreen.classList.remove('screen-visible');
        setupScreen.classList.add('screen-hidden');
    }

    if (name === 'home') {
        homeScreen.classList.remove('screen-hidden');
        homeScreen.classList.add('screen-visible');
        dock.classList.remove('dock-hidden');
        currentScreen = 'home';
        return;
    }

    homeScreen.classList.remove('screen-visible');
    homeScreen.classList.add('screen-hidden');
    dock.classList.add('dock-hidden');

    var screenMap = {
        'contacts': 'contacts-screen',
        'addContact': 'add-contact-screen',
        'messages': 'messages-screen',
        'chat': 'chat-screen',
        'newMessage': 'new-message-screen',
        'setup': 'setup-screen',
        'callOutgoing': 'call-outgoing-screen',
        'callIncoming': 'call-incoming-screen',
        'callActive': 'call-active-screen',
        'services': 'services-screen',
        'serviceChat': 'service-chat-screen'
    };

    var screenId = screenMap[name];
    if (screenId) {
        var el = document.getElementById(screenId);
        el.classList.remove('screen-hidden');
        el.classList.add('screen-visible');
    }
    currentScreen = name;
}

// ==================== PROFIL ====================

function updateMyProfile() {
    var nameEl = document.getElementById('my-profile-name');
    var numberEl = document.getElementById('my-profile-number');
    var detailName = document.getElementById('detail-my-name');
    var detailNumber = document.getElementById('detail-my-number');

    if (nameEl) nameEl.textContent = myDisplayName;
    if (numberEl) numberEl.textContent = myPhoneNumber || '...';
    if (detailName) detailName.textContent = myDisplayName;
    if (detailNumber) detailNumber.textContent = myPhoneNumber || 'Non attribue';
}

// ==================== CONTACTS ====================

function renderContactsList() {
    var list = document.getElementById('contacts-list');
    if (!list) return;

    if (!contactsList || contactsList.length === 0) {
        list.innerHTML = '<div class="contacts-empty">Aucun contact</div>';
        return;
    }

    var html = '';
    contactsList.forEach(function(contact) {
        html += '<div class="contact-item" data-id="' + contact.id + '" data-number="' + escapeHtml(contact.contact_number) + '" data-name="' + escapeHtml(contact.contact_name) + '">';
        html += '  <div class="contact-avatar">' + getInitials(contact.contact_name) + '</div>';
        html += '  <div class="contact-info">';
        html += '    <span class="contact-name">' + escapeHtml(contact.contact_name) + '</span>';
        html += '    <span class="contact-number">' + escapeHtml(contact.contact_number) + '</span>';
        html += '  </div>';
        html += '  <div class="contact-actions">';
        html += '    <div class="contact-action-btn contact-call-btn" data-number="' + escapeHtml(contact.contact_number) + '" data-name="' + escapeHtml(contact.contact_name) + '" title="Appeler">';
        html += '      <svg viewBox="0 0 24 24" fill="white" width="16" height="16"><path d="M6.62 10.79c1.44 2.83 3.76 5.14 6.59 6.59l2.2-2.2c.27-.27.67-.36 1.02-.24 1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1-9.39 0-17-7.61-17-17 0-.55.45-1 1-1h3.5c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.25 1.02l-2.2 2.2z"/></svg>';
        html += '    </div>';
        html += '    <div class="contact-action-btn contact-msg-btn" data-number="' + escapeHtml(contact.contact_number) + '" data-name="' + escapeHtml(contact.contact_name) + '" title="Envoyer un message">';
        html += '      <svg viewBox="0 0 24 24" fill="white" width="16" height="16"><path d="M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2z"/></svg>';
        html += '    </div>';
        html += '    <div class="contact-action-btn contact-del-btn" data-id="' + contact.id + '" title="Supprimer">';
        html += '      <svg viewBox="0 0 24 24" fill="#ff453a" width="16" height="16"><path d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z"/></svg>';
        html += '    </div>';
        html += '  </div>';
        html += '</div>';
    });

    list.innerHTML = html;

    // Clic sur message
    list.querySelectorAll('.contact-msg-btn').forEach(function(btn) {
        btn.addEventListener('click', function(e) {
            e.stopPropagation();
            var number = this.getAttribute('data-number');
            var name = this.getAttribute('data-name');
            openChat(number, name);
        });
    });

    // Clic sur appeler
    list.querySelectorAll('.contact-call-btn').forEach(function(btn) {
        btn.addEventListener('click', function(e) {
            e.stopPropagation();
            var number = this.getAttribute('data-number');
            var name = this.getAttribute('data-name');
            initiateCall(number, name);
        });
    });

    // Clic sur supprimer
    list.querySelectorAll('.contact-del-btn').forEach(function(btn) {
        btn.addEventListener('click', function(e) {
            e.stopPropagation();
            var id = parseInt(this.getAttribute('data-id'));
            fetch('https://custom_phone/deleteContact', {
                method: 'POST',
                body: JSON.stringify({ id: id }),
            });
        });
    });
}

// ==================== CONVERSATIONS ====================

function renderConversationsList(conversations) {
    var list = document.getElementById('conversations-list');
    if (!list) return;

    if (!conversations || conversations.length === 0) {
        list.innerHTML = '<div class="conversations-empty">Aucune conversation</div>';
        return;
    }

    var html = '';
    conversations.forEach(function(conv) {
        var otherNumber = conv.other_number;
        var contactName = getContactName(otherNumber);
        var lastMsg = conv.message || '';
        if (lastMsg.length > 35) lastMsg = lastMsg.substring(0, 35) + '...';
        var time = formatMessageTime(conv.created_at);
        var unread = conv.unread_count || 0;

        html += '<div class="conversation-item" data-number="' + escapeHtml(otherNumber) + '" data-name="' + escapeHtml(contactName) + '">';
        html += '  <div class="conv-avatar">' + getInitials(contactName) + '</div>';
        html += '  <div class="conv-info">';
        html += '    <div class="conv-top-row">';
        html += '      <span class="conv-name">' + escapeHtml(contactName) + '</span>';
        html += '      <span class="conv-time">' + time + '</span>';
        html += '    </div>';
        html += '    <div class="conv-bottom-row">';
        html += '      <span class="conv-last-msg">' + escapeHtml(lastMsg) + '</span>';
        if (unread > 0) {
            html += '      <span class="conv-unread">' + unread + '</span>';
        }
        html += '    </div>';
        html += '  </div>';
        html += '</div>';
    });

    list.innerHTML = html;

    list.querySelectorAll('.conversation-item').forEach(function(item) {
        item.addEventListener('click', function() {
            var number = this.getAttribute('data-number');
            var name = this.getAttribute('data-name');
            openChat(number, name);
        });
    });
}

// ==================== CHAT ====================

function openChat(number, name) {
    currentChatNumber = number;
    currentChatName = name || getContactName(number);

    document.getElementById('chat-contact-name').textContent = currentChatName;
    document.getElementById('chat-contact-number').textContent = number;
    document.getElementById('chat-messages').innerHTML = '<div class="chat-loading">Chargement...</div>';
    document.getElementById('chat-input').value = '';

    showScreen('chat');

    fetch('https://custom_phone/openConversation', {
        method: 'POST',
        body: JSON.stringify({ number: number }),
    });
}

function renderChatMessages(messages, otherNumber) {
    var container = document.getElementById('chat-messages');
    if (!container) return;

    if (!messages || messages.length === 0) {
        container.innerHTML = '<div class="chat-empty">Aucun message. Ecrivez le premier !</div>';
        return;
    }

    var html = '';
    var lastDate = '';

    messages.forEach(function(msg) {
        var msgDate = formatMessageDate(msg.created_at);
        if (msgDate !== lastDate) {
            html += '<div class="chat-date-separator">' + msgDate + '</div>';
            lastDate = msgDate;
        }

        var isMine = msg.sender_number === myPhoneNumber;
        var bubbleClass = isMine ? 'chat-bubble-sent' : 'chat-bubble-received';
        var time = formatMessageTime(msg.created_at);

        html += '<div class="chat-bubble ' + bubbleClass + '">';
        if (msg.message && msg.message.indexOf('GPS:') === 0) {
            var coords = msg.message.substring(4);
            html += '  <div class="bubble-gps" data-coords="' + escapeHtml(coords) + '">';
            html += '    <svg viewBox="0 0 24 24" fill="white" width="16" height="16"><path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/></svg>';
            html += '    <span>Position GPS</span>';
            html += '  </div>';
        } else {
            html += '  <div class="bubble-text">' + escapeHtml(msg.message) + '</div>';
        }
        html += '  <div class="bubble-time">' + time + '</div>';
        html += '</div>';
    });

    container.innerHTML = html;
    container.scrollTop = container.scrollHeight;

    // Click sur les messages GPS
    container.querySelectorAll('.bubble-gps').forEach(function(gps) {
        gps.addEventListener('click', function() {
            var coords = this.getAttribute('data-coords');
            fetch('https://custom_phone/setGPSWaypoint', {
                method: 'POST',
                body: JSON.stringify({ coords: coords })
            });
        });
    });
}

function sendCurrentMessage() {
    var input = document.getElementById('chat-input');
    var message = input.value.trim();
    if (!message || !currentChatNumber) return;

    fetch('https://custom_phone/sendMessage', {
        method: 'POST',
        body: JSON.stringify({ number: currentChatNumber, message: message }),
    });
}

// ==================== UTILITAIRES ====================

function escapeHtml(text) {
    if (!text) return '';
    var div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function getInitials(name) {
    if (!name) return '?';
    var parts = name.trim().split(' ');
    if (parts.length >= 2) {
        return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
}

function getContactName(number) {
    for (var i = 0; i < contactsList.length; i++) {
        if (contactsList[i].contact_number === number) {
            return contactsList[i].contact_name;
        }
    }
    return number;
}

function formatMessageTime(timestamp) {
    if (!timestamp) return '';
    var date = new Date(timestamp);
    if (isNaN(date.getTime())) return '';
    var hours = String(date.getHours()).padStart(2, '0');
    var minutes = String(date.getMinutes()).padStart(2, '0');
    return hours + ':' + minutes;
}

function formatMessageDate(timestamp) {
    if (!timestamp) return '';
    var date = new Date(timestamp);
    if (isNaN(date.getTime())) return '';
    var today = new Date();
    if (date.toDateString() === today.toDateString()) return "Aujourd'hui";
    var yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    if (date.toDateString() === yesterday.toDateString()) return 'Hier';
    return date.toLocaleDateString('fr-FR', { day: 'numeric', month: 'long' });
}

function showFormError(msg) {
    var el = document.getElementById('add-contact-error');
    if (el) {
        el.textContent = msg;
        el.classList.remove('hidden');
        setTimeout(function() { el.classList.add('hidden'); }, 3000);
    }
}

// ==================== EVENT LISTENERS ====================

// Bouton power
document.getElementById('btn-power').addEventListener('click', function() {
    if (isOpen) {
        closePhone();
        fetch('https://custom_phone/closePhone', {
            method: 'POST',
            body: JSON.stringify({}),
        });
    }
});

// Slide to unlock
var unlockBar = document.getElementById('lock-unlock-bar');
unlockBar.addEventListener('mousedown', initDrag);
unlockBar.addEventListener('touchstart', initDrag, { passive: false });
document.addEventListener('mousemove', onDrag);
document.addEventListener('touchmove', onDrag, { passive: false });
document.addEventListener('mouseup', endDrag);
document.addEventListener('touchend', endDrag);

// ==================== ICONES APPLICATIONS ====================

// Contacts (icone + dock phone)
document.querySelector('.app-icon[data-app="contacts"]').addEventListener('click', function() {
    fetch('https://custom_phone/openContacts', {
        method: 'POST',
        body: JSON.stringify({}),
    });
    showScreen('contacts');
});

// Appels -> ouvre aussi les contacts
document.querySelector('.app-icon[data-app="appels"]').addEventListener('click', function() {
    fetch('https://custom_phone/openContacts', {
        method: 'POST',
        body: JSON.stringify({}),
    });
    showScreen('contacts');
});

// Messages (icone)
document.querySelector('.app-icon[data-app="messages"]').addEventListener('click', function() {
    fetch('https://custom_phone/openMessages', {
        method: 'POST',
        body: JSON.stringify({}),
    });
    showScreen('messages');
});

// Services (icone)
var servicesIcon = document.querySelector('.app-icon[data-app="services"]');
if (servicesIcon) {
    servicesIcon.addEventListener('click', function() {
        fetch('https://custom_phone/openServices', {
            method: 'POST',
            body: JSON.stringify({}),
        });
        showScreen('services');
    });
}

// Dock phone -> contacts
document.getElementById('dock-phone').addEventListener('click', function() {
    fetch('https://custom_phone/openContacts', {
        method: 'POST',
        body: JSON.stringify({}),
    });
    showScreen('contacts');
});

// Dock messages
document.getElementById('dock-messages').addEventListener('click', function() {
    fetch('https://custom_phone/openMessages', {
        method: 'POST',
        body: JSON.stringify({}),
    });
    showScreen('messages');
});

// ==================== CONTACTS UI ====================

// Retour contacts -> home
document.getElementById('contacts-back').addEventListener('click', function() {
    showScreen('home');
});

// Bouton + ajouter contact
document.getElementById('contacts-add-btn').addEventListener('click', function() {
    document.getElementById('input-contact-name').value = '';
    document.getElementById('input-contact-number').value = '';
    document.getElementById('add-contact-error').classList.add('hidden');
    showScreen('addContact');
});

// Mon profil toggle
document.getElementById('my-profile-toggle').addEventListener('click', function() {
    var details = document.getElementById('my-profile-details');
    var arrow = this.querySelector('svg');
    if (details.classList.contains('hidden')) {
        details.classList.remove('hidden');
        this.classList.add('expanded');
    } else {
        details.classList.add('hidden');
        this.classList.remove('expanded');
    }
});

document.getElementById('my-profile-card').addEventListener('click', function(e) {
    if (e.target.closest('#my-profile-toggle')) return;
    document.getElementById('my-profile-toggle').click();
});

// ==================== AJOUT CONTACT UI ====================

document.getElementById('add-contact-back').addEventListener('click', function() {
    showScreen('contacts');
});

document.getElementById('btn-save-contact').addEventListener('click', function() {
    var name = document.getElementById('input-contact-name').value.trim();
    var number = document.getElementById('input-contact-number').value.trim();

    if (!name) {
        showFormError('Veuillez entrer un nom');
        return;
    }
    if (!number) {
        showFormError('Veuillez entrer un numero');
        return;
    }

    fetch('https://custom_phone/addContact', {
        method: 'POST',
        body: JSON.stringify({ name: name, number: number }),
    });
});

// ==================== MESSAGES UI ====================

document.getElementById('messages-back').addEventListener('click', function() {
    showScreen('home');
});

document.getElementById('new-message-btn').addEventListener('click', function() {
    document.getElementById('input-msg-number').value = '';
    renderNewMessageContactsList();
    showScreen('newMessage');
});

// ==================== NOUVEAU MESSAGE UI ====================

document.getElementById('new-msg-back').addEventListener('click', function() {
    showScreen('messages');
});

function renderNewMessageContactsList() {
    var list = document.getElementById('new-msg-contacts-list');
    if (!contactsList || contactsList.length === 0) {
        list.innerHTML = '<div class="contacts-empty" style="padding-top: 20px;">Aucun contact. Ajoutez-en d\'abord !</div>';
        return;
    }

    var html = '';
    contactsList.forEach(function(contact) {
        html += '<div class="contact-item new-msg-contact" data-number="' + escapeHtml(contact.contact_number) + '" data-name="' + escapeHtml(contact.contact_name) + '">';
        html += '  <div class="contact-avatar">' + getInitials(contact.contact_name) + '</div>';
        html += '  <div class="contact-info">';
        html += '    <span class="contact-name">' + escapeHtml(contact.contact_name) + '</span>';
        html += '    <span class="contact-number">' + escapeHtml(contact.contact_number) + '</span>';
        html += '  </div>';
        html += '</div>';
    });
    list.innerHTML = html;

    list.querySelectorAll('.new-msg-contact').forEach(function(item) {
        item.addEventListener('click', function() {
            var number = this.getAttribute('data-number');
            var name = this.getAttribute('data-name');
            openChat(number, name);
        });
    });
}

// Filtrer les contacts dans nouveau message
document.getElementById('input-msg-number').addEventListener('input', function() {
    var query = this.value.trim().toLowerCase();
    var items = document.querySelectorAll('#new-msg-contacts-list .new-msg-contact');
    items.forEach(function(item) {
        var name = (item.getAttribute('data-name') || '').toLowerCase();
        var number = (item.getAttribute('data-number') || '').toLowerCase();
        if (!query || name.indexOf(query) !== -1 || number.indexOf(query) !== -1) {
            item.style.display = '';
        } else {
            item.style.display = 'none';
        }
    });
});

// Entrer un numero direct dans nouveau message
document.getElementById('input-msg-number').addEventListener('keydown', function(e) {
    if (e.key === 'Enter') {
        var number = this.value.trim();
        if (number) {
            openChat(number, getContactName(number));
        }
    }
});

// ==================== CHAT UI ====================

document.getElementById('chat-back').addEventListener('click', function() {
    currentChatNumber = null;
    currentChatName = null;
    fetch('https://custom_phone/openMessages', {
        method: 'POST',
        body: JSON.stringify({}),
    });
    showScreen('messages');
});

document.getElementById('chat-send-btn').addEventListener('click', function() {
    sendCurrentMessage();
});

document.getElementById('chat-input').addEventListener('keydown', function(e) {
    if (e.key === 'Enter') {
        e.preventDefault();
        sendCurrentMessage();
    }
});

// ==================== CAMERA ====================

function showCameraUI(frontCam) {
    cameraMode = true;
    isFrontCamera = frontCam;
    var cameraScreen = document.getElementById('camera-screen');
    var homeScreen = document.getElementById('home-screen');
    var lockScreen = document.getElementById('lock-screen');
    var dock = document.getElementById('dock');
    var frontLabel = document.getElementById('camera-front-label');
    var phoneFrame = document.getElementById('phone-frame');
    var container = document.getElementById('phone-container');
    var vignette = document.getElementById('camera-vignette');

    hideAllAppScreens();
    homeScreen.classList.remove('screen-visible');
    homeScreen.classList.add('screen-hidden');
    lockScreen.classList.add('hidden');
    dock.classList.add('dock-hidden');

    phoneFrame.classList.add('camera-active');
    container.classList.add('camera-mode');
    vignette.classList.add('active');
    cameraScreen.classList.remove('screen-hidden', 'cursor-active');
    cameraScreen.classList.add('screen-visible');

    if (frontCam) {
        frontLabel.classList.remove('hidden');
    } else {
        frontLabel.classList.add('hidden');
    }
}

function hideCameraUI() {
    cameraMode = false;
    isFrontCamera = false;
    var cameraScreen = document.getElementById('camera-screen');
    var homeScreen = document.getElementById('home-screen');
    var dock = document.getElementById('dock');
    var phoneFrame = document.getElementById('phone-frame');
    var container = document.getElementById('phone-container');
    var vignette = document.getElementById('camera-vignette');

    phoneFrame.classList.remove('camera-active');
    container.classList.remove('camera-mode');
    vignette.classList.remove('active');
    cameraScreen.classList.remove('screen-visible');
    cameraScreen.classList.add('screen-hidden');

    homeScreen.classList.remove('screen-hidden');
    homeScreen.classList.add('screen-visible');
    dock.classList.remove('dock-hidden');
    currentScreen = 'home';
}

function updateCameraUI(frontCam) {
    isFrontCamera = frontCam;
    var frontLabel = document.getElementById('camera-front-label');
    if (frontCam) {
        frontLabel.classList.remove('hidden');
    } else {
        frontLabel.classList.add('hidden');
    }
}

function triggerFlash() {
    var flash = document.getElementById('camera-flash-overlay');
    flash.classList.remove('flash-active');
    void flash.offsetWidth;
    flash.classList.add('flash-active');
    setTimeout(function() { flash.classList.remove('flash-active'); }, 350);
}

function setCursorVisible(visible) {
    var cameraScreen = document.getElementById('camera-screen');
    if (visible) {
        cameraScreen.classList.add('cursor-active');
    } else {
        cameraScreen.classList.remove('cursor-active');
    }
}

// Camera buttons
document.getElementById('camera-shutter').addEventListener('click', function() {
    fetch('https://custom_phone/takePhoto', { method: 'POST', body: JSON.stringify({}) });
});

document.getElementById('camera-switch-btn').addEventListener('click', function() {
    fetch('https://custom_phone/switchCamera', { method: 'POST', body: JSON.stringify({}) });
});

document.getElementById('camera-close-btn').addEventListener('click', function() {
    fetch('https://custom_phone/closeCamera', { method: 'POST', body: JSON.stringify({}) });
});

function openCameraFromUI() {
    fetch('https://custom_phone/openCamera', { method: 'POST', body: JSON.stringify({}) });
}

// ==================== CONFIGURATION INITIALE ====================

function showSetupAfterUnlock() {
    var checkUnlock = setInterval(function() {
        if (!isLocked) {
            clearInterval(checkUnlock);
            showScreen('setup');
        }
    }, 200);
}

// Input du numero avec debounce pour verifier la disponibilite
var setupNumberInput = document.getElementById('input-setup-number');
if (setupNumberInput) {
    setupNumberInput.addEventListener('input', function() {
        var val = setupNumberInput.value.trim();
        var btnConfirm = document.getElementById('btn-confirm-setup');
        var statusEl = document.getElementById('setup-number-status');

        if (setupCheckTimer) clearTimeout(setupCheckTimer);

        if (val.length < 3) {
            statusEl.classList.add('hidden');
            btnConfirm.disabled = true;
            numberCheckAvailable = false;
            return;
        }

        statusEl.classList.remove('hidden');
        statusEl.textContent = 'Verification...';
        statusEl.className = 'setup-status checking';
        btnConfirm.disabled = true;
        numberCheckAvailable = false;

        setupCheckTimer = setTimeout(function() {
            fetch('https://custom_phone/checkNumberAvailable', {
                method: 'POST',
                body: JSON.stringify({ number: val })
            });
        }, 500);
    });

    setupNumberInput.addEventListener('keydown', function(e) {
        if (e.key === 'Enter' && numberCheckAvailable) {
            document.getElementById('btn-confirm-setup').click();
        }
    });
}

function showNumberAvailability(available, errorMsg) {
    var statusEl = document.getElementById('setup-number-status');
    var btnConfirm = document.getElementById('btn-confirm-setup');

    statusEl.classList.remove('hidden');
    if (available) {
        statusEl.textContent = 'Numero disponible !';
        statusEl.className = 'setup-status available';
        btnConfirm.disabled = false;
        numberCheckAvailable = true;
    } else {
        statusEl.textContent = errorMsg || 'Numero indisponible';
        statusEl.className = 'setup-status taken';
        btnConfirm.disabled = true;
        numberCheckAvailable = false;
    }
}

function showSetupError(msg) {
    var errorEl = document.getElementById('setup-error');
    errorEl.textContent = msg;
    errorEl.classList.remove('hidden');
    var btnConfirm = document.getElementById('btn-confirm-setup');
    btnConfirm.disabled = false;
}

// Bouton confirmer le numero
var btnConfirmSetup = document.getElementById('btn-confirm-setup');
if (btnConfirmSetup) {
    btnConfirmSetup.addEventListener('click', function() {
        var chosenNumber = document.getElementById('input-setup-number').value.trim();
        if (!chosenNumber || !numberCheckAvailable) return;

        btnConfirmSetup.disabled = true;
        document.getElementById('setup-error').classList.add('hidden');

        fetch('https://custom_phone/registerNumber', {
            method: 'POST',
            body: JSON.stringify({ number: chosenNumber })
        });
    });
}

// ==================== SYSTEME D'APPEL ====================

function initiateCall(number, name) {
    if (callState) return;
    callState = 'outgoing';
    callNumber = number;
    callName = name || number;

    // Mettre a jour l'UI d'appel sortant
    document.getElementById('call-out-avatar').textContent = getInitials(callName);
    document.getElementById('call-out-name').textContent = callName;
    document.getElementById('call-out-number').textContent = number;
    document.getElementById('call-out-timer').textContent = '';

    showScreen('callOutgoing');

    // Ne pas envoyer initiateCall pour les appels service (deja gere par callService)
    if (!number.startsWith('SVC-')) {
        fetch('https://custom_phone/initiateCall', {
            method: 'POST',
            body: JSON.stringify({ number: number, name: callName })
        });
    }
}

function showCallFailedMessage(reason) {
    // Afficher brievement la raison de l'echec sur l'ecran d'appel sortant
    var timerEl = document.getElementById('call-out-timer');
    if (timerEl) {
        timerEl.textContent = reason;
        timerEl.style.color = '#ff453a';
    }
    // Retour a l'accueil apres 2 secondes
    setTimeout(function() {
        if (timerEl) {
            timerEl.style.color = '';
        }
        endCallUI();
    }, 2000);
}

function showIncomingCall(callerNumber, callerName) {
    callState = 'incoming';
    callNumber = callerNumber;
    callName = callerName || callerNumber;

    // Chercher le nom dans les contacts
    if (callName === callerNumber && contactsList) {
        for (var i = 0; i < contactsList.length; i++) {
            if (contactsList[i].contact_number === callerNumber) {
                callName = contactsList[i].contact_name;
                break;
            }
        }
    }

    // Si le telephone est verrouille, deverrouiller pour afficher l'appel
    if (isLocked) {
        isLocked = false;
        var lockScreen = document.getElementById('lock-screen');
        lockScreen.classList.add('hidden');
        lockScreen.style.transform = '';
        lockScreen.style.opacity = '';
        lockScreen.style.transition = '';
    }

    document.getElementById('call-in-avatar').textContent = getInitials(callName);
    document.getElementById('call-in-name').textContent = callName;
    document.getElementById('call-in-number').textContent = callerNumber;

    showScreen('callIncoming');
}

function showActiveCall() {
    callState = 'active';
    callSeconds = 0;
    isMuted = false;
    isSpeaker = false;

    document.getElementById('call-active-avatar').textContent = getInitials(callName);
    document.getElementById('call-active-name').textContent = callName;
    document.getElementById('call-active-number').textContent = callNumber;
    document.getElementById('call-active-timer').textContent = '00:00';

    // Reset les boutons
    document.getElementById('call-mute-btn').setAttribute('data-active', 'false');
    document.getElementById('call-speaker-btn').setAttribute('data-active', 'false');

    showScreen('callActive');

    // Timer
    callTimerInterval = setInterval(function() {
        callSeconds++;
        var mins = Math.floor(callSeconds / 60).toString().padStart(2, '0');
        var secs = (callSeconds % 60).toString().padStart(2, '0');
        document.getElementById('call-active-timer').textContent = mins + ':' + secs;
    }, 1000);
}

function endCallUI() {
    callState = null;
    callNumber = null;
    callName = null;
    isMuted = false;
    isSpeaker = false;
    if (callTimerInterval) {
        clearInterval(callTimerInterval);
        callTimerInterval = null;
    }
    callSeconds = 0;
    showScreen('home');
}

// Bouton raccrocher (appel sortant)
document.getElementById('call-out-hangup').addEventListener('click', function() {
    fetch('https://custom_phone/hangupCall', { method: 'POST', body: JSON.stringify({}) });
    endCallUI();
});

// Bouton accepter (appel entrant)
document.getElementById('call-in-accept').addEventListener('click', function() {
    fetch('https://custom_phone/acceptCall', { method: 'POST', body: JSON.stringify({}) });
});

// Bouton refuser (appel entrant)
document.getElementById('call-in-reject').addEventListener('click', function() {
    fetch('https://custom_phone/rejectCall', { method: 'POST', body: JSON.stringify({}) });
    endCallUI();
});

// Bouton raccrocher (en appel)
document.getElementById('call-active-hangup').addEventListener('click', function() {
    fetch('https://custom_phone/hangupCall', { method: 'POST', body: JSON.stringify({}) });
    endCallUI();
});

// Bouton muet
document.getElementById('call-mute-btn').addEventListener('click', function() {
    isMuted = !isMuted;
    this.setAttribute('data-active', isMuted ? 'true' : 'false');
    fetch('https://custom_phone/toggleMute', { method: 'POST', body: JSON.stringify({ muted: isMuted }) });
});

// Bouton haut-parleur
document.getElementById('call-speaker-btn').addEventListener('click', function() {
    isSpeaker = !isSpeaker;
    this.setAttribute('data-active', isSpeaker ? 'true' : 'false');
    fetch('https://custom_phone/toggleSpeaker', { method: 'POST', body: JSON.stringify({ speaker: isSpeaker }) });
});

// ==================== GPS ====================

document.getElementById('chat-gps-btn').addEventListener('click', function() {
    fetch('https://custom_phone/sendGPS', {
        method: 'POST',
        body: JSON.stringify({ number: currentChatNumber, name: currentChatName })
    });
});

function renderGPSBubble(msg) {
    if (msg.message && msg.message.indexOf('GPS:') === 0) {
        return true;
    }
    return false;
}

// ==================== SERVICES ====================

var currentServiceJob = null;
var currentServiceName = null;


function getServiceInitials(label) {
    var words = label.split(' ');
    if (words.length >= 2) return (words[0][0] + words[1][0]).toUpperCase();
    return label.substring(0, 2).toUpperCase();
}

function renderServicesList(services) {
    var container = document.getElementById('services-list');
    if (!container) return;
    var html = '';
    for (var i = 0; i < services.length; i++) {
        var svc = services[i];
        var color = svc.color || '#5856d6';
        var initials = getServiceInitials(svc.label);
        html += '<div class="service-item">';
        html += '  <div class="service-logo" style="background: ' + color + ';">' + initials + '</div>';
        html += '  <div class="service-info">';
        html += '    <span class="service-name">' + escapeHtml(svc.label) + '</span>';
        var statusText = svc.statusText || (svc.online ? 'En service' : 'Personne n\'est en service');
        var statusColor = svc.online ? 'color: #30d158;' : 'color: rgba(255,100,100,0.7);';
        html += '    <span class="service-desc" style="' + statusColor + '">' + statusText + '</span>';
        html += '  </div>';
        html += '  <div class="service-actions">';
        html += '    <div class="service-action-btn service-call-btn" data-job="' + escapeHtml(svc.job) + '" data-label="' + escapeHtml(svc.label) + '" title="Appeler">';
        html += '      <svg viewBox="0 0 24 24" fill="white" width="16" height="16"><path d="M6.62 10.79c1.44 2.83 3.76 5.14 6.59 6.59l2.2-2.2c.27-.27.67-.36 1.02-.24 1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1-9.39 0-17-7.61-17-17 0-.55.45-1 1-1h3.5c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.25 1.02l-2.2 2.2z"/></svg>';
        html += '    </div>';
        html += '    <div class="service-action-btn service-msg-btn" data-job="' + escapeHtml(svc.job) + '" data-label="' + escapeHtml(svc.label) + '" title="Message">';
        html += '      <svg viewBox="0 0 24 24" fill="white" width="16" height="16"><path d="M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2z"/></svg>';
        html += '    </div>';
        html += '  </div>';
        html += '</div>';
    }
    if (services.length === 0) {
        html = '<div style="text-align: center; color: rgba(255,255,255,0.3); padding: 40px 20px; font-size: 13px;">Aucun service disponible</div>';
    }
    container.innerHTML = html;

    // Event listeners appeler
    var callBtns = container.querySelectorAll('.service-call-btn');
    for (var c = 0; c < callBtns.length; c++) {
        callBtns[c].addEventListener('click', function() {
            var job = this.getAttribute('data-job');
            var label = this.getAttribute('data-label');
            fetch('https://custom_phone/callService', {
                method: 'POST',
                body: JSON.stringify({ job: job, label: label }),
            });
            initiateCall('SVC-' + job, label);
        });
    }

    // Event listeners message
    var msgBtns = container.querySelectorAll('.service-msg-btn');
    for (var m = 0; m < msgBtns.length; m++) {
        msgBtns[m].addEventListener('click', function() {
            var job = this.getAttribute('data-job');
            var label = this.getAttribute('data-label');
            openServiceChat(job, label);
        });
    }
}

function openServiceChat(job, label) {
    currentServiceJob = job;
    currentServiceName = label;
    document.getElementById('service-chat-name').textContent = label;
    document.getElementById('service-chat-job').textContent = 'Service ' + label;
    document.getElementById('service-chat-messages').innerHTML = '';
    showScreen('serviceChat');
    fetch('https://custom_phone/getServiceMessages', {
        method: 'POST',
        body: JSON.stringify({ job: job }),
    });
}

function renderServiceChatMessages(messages) {
    var container = document.getElementById('service-chat-messages');
    if (!container) return;
    var html = '';
    for (var i = 0; i < messages.length; i++) {
        var msg = messages[i];
        var isMine = msg.is_mine;
        var bubbleClass = isMine ? 'service-msg-sent' : 'service-msg-received';
        var time = '';
        if (msg.created_at) {
            var d = new Date(msg.created_at);
            time = d.getHours().toString().padStart(2, '0') + ':' + d.getMinutes().toString().padStart(2, '0');
        }
        html += '<div class="service-msg-bubble ' + bubbleClass + '">';
        if (!isMine && msg.sender_name) {
            html += '<span class="service-msg-sender">' + escapeHtml(msg.sender_name) + '</span>';
        }
        html += escapeHtml(msg.message);
        html += '<span class="service-msg-time">' + time + '</span>';
        html += '</div>';
    }
    container.innerHTML = html;
    container.scrollTop = container.scrollHeight;
}

// Service back button
var servicesBackBtn = document.getElementById('services-back');
if (servicesBackBtn) {
    servicesBackBtn.addEventListener('click', function() {
        showScreen('home');
    });
}

var serviceChatBackBtn = document.getElementById('service-chat-back');
if (serviceChatBackBtn) {
    serviceChatBackBtn.addEventListener('click', function() {
        currentServiceJob = null;
        currentServiceName = null;
        showScreen('services');
        fetch('https://custom_phone/openServices', {
            method: 'POST',
            body: JSON.stringify({}),
        });
    });
}

// Service chat send
var serviceChatSendBtn = document.getElementById('service-chat-send-btn');
if (serviceChatSendBtn) {
    serviceChatSendBtn.addEventListener('click', function() {
        var input = document.getElementById('service-chat-input');
        var msg = input.value.trim();
        if (!msg || !currentServiceJob) return;
        fetch('https://custom_phone/sendServiceMessage', {
            method: 'POST',
            body: JSON.stringify({ job: currentServiceJob, message: msg }),
        });
        input.value = '';
    });
}

var serviceChatInput = document.getElementById('service-chat-input');
if (serviceChatInput) {
    serviceChatInput.addEventListener('keydown', function(e) {
        if (e.key === 'Enter') {
            e.preventDefault();
            document.getElementById('service-chat-send-btn').click();
        }
    });
}

// Horloge
setInterval(function() {
    if (isOpen) updateTimeDisplay();
}, 1000);
