/* ══════════════════════════════════════════════════════════════
   hud_player — NUI app.js (circular icons design)
══════════════════════════════════════════════════════════════ */

'use strict';

const statsWrapper  = document.getElementById('stats-wrapper');
const streetWrapper = document.getElementById('street-wrapper');
const streetName    = document.getElementById('street-name');
const streetInitial = document.getElementById('street-initial');

// Ring circumference: 2 * PI * 19 = 119.38
const RING_CIRCUMFERENCE = 119.38;

// ══════════════════════════════════════════════════════════════
//  STATS — circular ring update
// ══════════════════════════════════════════════════════════════

function updateStat(id, val) {
  var v      = Math.max(0, Math.min(100, val));
  var ring   = document.getElementById(id + '-ring');
  var circle = document.getElementById('stat-' + id);
  if (!ring) return;

  // stroke-dashoffset: 0 = full, RING_CIRCUMFERENCE = empty
  var offset = RING_CIRCUMFERENCE * (1 - v / 100);
  ring.style.strokeDashoffset = offset;

  // Toggle low state for pulse animation
  if (circle) {
    if (v <= 20) {
      circle.classList.add('low');
    } else {
      circle.classList.remove('low');
    }
  }
}

function toggleHUD(visible) {
  if (visible) { statsWrapper.classList.add('visible'); }
  else         {
    statsWrapper.classList.remove('visible');
  }
}

function toggleVehicle(inVehicle) {
  if (inVehicle) {
    streetWrapper.classList.add('visible');
  } else {
    streetWrapper.classList.remove('visible');
  }
}

function updateStreet(street) {
  streetName.textContent = street;
  if (street && street.length > 0) {
    streetInitial.textContent = street.charAt(0).toUpperCase();
  }
}

// ══════════════════════════════════════════════════════════════
//  LISTENER NUI
// ══════════════════════════════════════════════════════════════
window.addEventListener('message', function(e) {
  var d = e.data;
  if (!d || !d.type) return;
  switch (d.type) {
    case 'toggleHUD':     toggleHUD(d.visible);         break;
    case 'toggleVehicle': toggleVehicle(d.inVehicle);   break;
    case 'updateHealth':  updateStat('hp',  d.health);  break;
    case 'updateArmour':  updateStat('arm', d.armour);  break;
    case 'updateHunger':  updateStat('hng', d.hunger);  break;
    case 'updateThirst':  updateStat('thr', d.thirst);  break;
    case 'updateStamina': updateStat('stm', d.stamina); break;
    case 'updateStreet':  updateStreet(d.street);        break;
  }
});
