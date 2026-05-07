/* =============================================
   DYNASTY INVENTORY — NUI JavaScript
   Dark Blue Glassmorphism Theme
   Drag via mousedown/mousemove/mouseup (CEF-safe)
   ============================================= */
'use strict';

// --- State ---
let state = {
    inventory      : {},
    groundItems    : [],
    items          : {},
    maxSlots       : 30,
    maxWeight      : 30,
    weaponSlots    : [],
    hotbarItems    : {},
    selectedSlot   : null,
    vehicleInv     : {},
    vehicleContext : null,
    vehiclePlate   : null,
    vehMaxSlots    : 20,
    vehMaxWeight   : 50,
};

// --- Drag state ---
let drag = {
    active    : false,
    type      : null,       // 'inv' | 'ground' | 'weapon' | 'vehicle'
    slot      : null,
    groundId  : null,
    category  : null,
    ghost     : null,
    srcEl     : null,
    startX    : 0,
    startY    : 0,
    moved     : false,
    itemDef   : null,
    data      : null,
};

let activeCtx = null;

// --- Qty modal state ---
let qtyModal = {
    resolve : null,
    maxQty  : 1,
};

// --- DOM refs ---
const overlay      = document.getElementById('inv-overlay');
const grid         = document.getElementById('slots-grid');
const weightDot    = document.getElementById('weight-dot');
const weightText   = document.getElementById('weight-text');
const tooltip      = document.getElementById('tooltip');
const groundZone   = document.getElementById('ground-drop-zone');
const groundSlots  = document.getElementById('ground-slots');
const groundHint   = document.getElementById('ground-drop-hint');
const hotbarEl     = document.getElementById('hotbar');

const vehicleZone  = document.getElementById('vehicle-storage-zone');
const vehicleSlots = document.getElementById('vehicle-slots');
const proxLabel    = document.getElementById('prox-label');
const proxIconDefault  = document.getElementById('prox-icon-default');
const proxIconTrunk    = document.getElementById('prox-icon-trunk');
const proxIconGlovebox = document.getElementById('prox-icon-glovebox');
const proxWeightText   = document.getElementById('prox-weight-text');
const proxWeightDot    = document.getElementById('prox-weight-dot');

const actionUse    = document.getElementById('action-use');
const actionGive   = document.getElementById('action-give');
const actionDrop   = document.getElementById('action-drop');
const actionQty    = document.getElementById('action-qty');

const WEAPON_ICONS = {
    melee:   '\u{1F52A}',
    handgun: '\u{1F52B}',
    smg:     '\u{1F4A8}',
    rifle:   '\u{1F3AF}',
    shotgun: '\u{1F4A5}',
    sniper:  '\u{1F52D}',
    heavy:   '\u{1F4A3}',
    thrown:  '\u{1F9E8}',
};

const ttIcon    = document.getElementById('tt-icon');
const ttName    = document.getElementById('tt-name');
const ttDesc    = document.getElementById('tt-desc');
const ttWeight  = document.getElementById('tt-weight');
const ttUse     = document.getElementById('tt-use');
const ttPickup  = document.getElementById('tt-pickup');
const ttDrop    = document.getElementById('tt-drop');
const ttDropAll = document.getElementById('tt-drop-all');
const ttGive    = document.getElementById('tt-give');

const qtyModalEl     = document.getElementById('qty-modal');
const qtyModalTitle  = document.getElementById('qty-modal-title');
const qtyTargetRow   = document.getElementById('qty-target-row');
const qtyTargetInput = document.getElementById('qty-target-input');
const qtyInput       = document.getElementById('qty-input');
const qtyAllBtn      = document.getElementById('qty-all-btn');
const qtyConfirmBtn  = document.getElementById('qty-confirm-btn');
const qtyCancelBtn   = document.getElementById('qty-cancel-btn');

// --- Used item notification ---
const usedItemNotif  = document.getElementById('used-item-notif');
const usedItemIcon   = document.getElementById('used-item-icon');
const usedItemLabel  = document.getElementById('used-item-label');
let usedItemTimer    = null;


// --- NUI Message handler ---
window.addEventListener('message', (e) => {
    const { action, inventory, groundItems, maxSlots, items } = e.data;

    if (action === 'open' || action === 'update') {
        if (items)    state.items    = items;
        if (maxSlots) state.maxSlots = maxSlots;

        if (inventory) {
            if (Array.isArray(inventory)) {
                const normalized = {};
                inventory.forEach((val, idx) => { if (val) normalized[idx + 1] = val; });
                state.inventory = normalized;
            } else {
                state.inventory = inventory;
            }
            // Sync: reconcile hotbar with server inventory
            for (const [key, hItem] of Object.entries(state.hotbarItems)) {
                if (hItem && hItem.invSlot) {
                    if (state.inventory[hItem.invSlot]) {
                        // Update hotbar data from server (amount may have changed)
                        hItem.data = { ...state.inventory[hItem.invSlot] };
                        delete state.inventory[hItem.invSlot];
                    } else {
                        // Item was consumed/removed by server — clean from hotbar
                        delete state.hotbarItems[key];
                    }
                }
            }
        }

        if (groundItems) state.groundItems = groundItems;

        if (action === 'open') {
            overlay.classList.remove('hidden');
        }

        // Toujours re-render le hotbar (il est toujours visible)
        renderHotbar();

        if (!overlay.classList.contains('hidden')) {
            renderGrid();
            renderGround();
            updateWeight();
        }
    }

    if (action === 'updateWeapons') {
        if (e.data.weaponSlots) {
            state.weaponSlots = e.data.weaponSlots;
            renderHotbar();
        }
        return;
    }

    if (action === 'updateVehicleStorage') {
        const d = e.data;
        state.vehicleContext = d.storageType || null;
        state.vehiclePlate  = d.plate || null;
        state.vehMaxSlots   = d.vehMaxSlots || 20;
        state.vehMaxWeight  = d.vehMaxWeight || 50;
        if (d.vehicleInv) {
            state.vehicleInv = d.vehicleInv;
        }
        renderGround();
        updateVehicleWeight();
    }

    if (action === 'close') {
        overlay.classList.add('hidden');
        cancelDrag();
        hideTooltip();
        hideQtyModal();
        activeCtx = null;
        state.selectedSlot = null;
        state.vehicleContext = null;
        state.vehiclePlate   = null;
        state.vehicleInv     = {};
    }

    if (action === 'showUsedItem') {
        const def = e.data.itemDef;
        if (def) showUsedItemNotif(def);
    }

    // Mise à jour ammo en temps réel (envoyé par le thread client à chaque tir)
    if (action === 'updateAmmoDisplay') {
        const weaponName = e.data.weaponName;
        const newAmmo    = e.data.ammo;
        if (weaponName != null && newAmmo != null) {
            // Mettre à jour les items hotbar
            for (const [key, hItem] of Object.entries(state.hotbarItems)) {
                if (hItem && hItem.data) {
                    const def = state.items[hItem.data.item];
                    if (def && def.weaponName === weaponName) {
                        hItem.data.amount = newAmmo;
                    }
                }
            }
            // Mettre à jour les items inventaire
            for (const [slot, sData] of Object.entries(state.inventory)) {
                const def = state.items[sData.item];
                if (def && def.weaponName === weaponName) {
                    sData.amount = newAmmo;
                }
            }
            renderHotbar();
            if (!overlay.classList.contains('hidden')) {
                renderGrid();
            }
        }
    }

    // Hotbar keyboard shortcut from Lua (keys 1-5)
    if (action === 'hotbarUse') {
        const slotNum = e.data.slot;
        const hItem = state.hotbarItems[slotNum];
        if (hItem && hItem.data) {
            const itemDef = state.items[hItem.data.item];
            if (itemDef) {
                if (itemDef.isWeapon) {
                    // Equip weapon directly on ped (no weapon slot system)
                    postNUI('hotbarEquipWeapon', { weaponName: itemDef.weaponName, category: itemDef.weaponCategory, ammo: hItem.data.amount != null ? hItem.data.amount : 1 });
                } else if (itemDef.usable) {
                    showUsedItemNotif(itemDef);
                    // Use item (server has the item in inventory)
                    postNUI('useItem', { slot: hItem.invSlot, itemName: hItem.data.item });
                }
            }
        } else {
            // Hotbar slot empty — fallback to weapon system
            postNUI('fallbackWeaponSlot', { slotIndex: slotNum });
        }
    }
});

// --- Helper: get inventory slots currently in hotbar ---
function getSlotsInHotbar() {
    const set = new Set();
    for (const [, hItem] of Object.entries(state.hotbarItems)) {
        if (hItem && hItem.invSlot) set.add(hItem.invSlot);
    }
    return set;
}

// --- Helper: find first empty inv slot ---
function findEmptyInvSlot() {
    const inHotbar = getSlotsInHotbar();
    for (let s = 1; s <= state.maxSlots; s++) {
        if (!state.inventory[s] && !inHotbar.has(s)) return s;
    }
    return null;
}

// --- Render inventaire ---
function renderGrid() {
    grid.innerHTML = '';
    const inHotbar = getSlotsInHotbar();
    for (let s = 1; s <= state.maxSlots; s++) {
        const isInHotbar = inHotbar.has(s);
        const data    = (!isInHotbar && state.inventory[s]) ? state.inventory[s] : null;
        const itemDef = data ? state.items[data.item] : null;
        grid.appendChild(makeSlot(s, data, itemDef));
    }
}

// --- Render sol / vehicle storage ---
function renderGround() {
    const isVehicle = state.vehicleContext != null;

    // Toggle proximity panel header
    if (proxIconDefault)  proxIconDefault.classList.toggle('hidden', isVehicle);
    if (proxIconTrunk)    proxIconTrunk.classList.toggle('hidden', state.vehicleContext !== 'trunk');
    if (proxIconGlovebox) proxIconGlovebox.classList.toggle('hidden', state.vehicleContext !== 'glovebox');
    if (proxLabel) {
        if (state.vehicleContext === 'trunk')    proxLabel.textContent = 'Coffre';
        else if (state.vehicleContext === 'glovebox') proxLabel.textContent = 'Boite a gants';
        else proxLabel.textContent = 'a proximite';
    }

    if (isVehicle) {
        groundZone.classList.add('hidden');
        vehicleZone.classList.remove('hidden');
        renderVehicleSlots();
        updateVehicleWeight();
        return;
    }

    groundZone.classList.remove('hidden');
    vehicleZone.classList.add('hidden');

    groundSlots.innerHTML = '';
    const hasItems = state.groundItems && state.groundItems.length > 0;
    groundHint.classList.toggle('hidden', hasItems);
    if (!hasItems) return;

    state.groundItems.forEach((g) => {
        const itemDef = state.items[g.item];
        const el      = document.createElement('div');
        el.className  = 'ground-slot';
        el.dataset.groundId = String(g.groundId);

        if (itemDef) {
            const icon = document.createElement('div');
            icon.className   = 'slot-icon';
            icon.textContent = itemDef.icon || '\u{1F4E6}';
            el.appendChild(icon);

            const label = document.createElement('div');
            label.className   = 'slot-label';
            label.textContent = itemDef.label || g.item;
            el.appendChild(label);

            if (g.amount > 1) {
                const amt = document.createElement('div');
                amt.className   = 'slot-amount';
                amt.textContent = 'x' + g.amount;
                el.appendChild(amt);
            }
        }

        el.addEventListener('mousedown', (ev) => {
            if (ev.button !== 0) return;
            if (itemDef) startDrag(ev, 'ground', null, g.groundId, el, itemDef, g);
        });

        el.addEventListener('contextmenu', (ev) => {
            ev.preventDefault();
            if (itemDef) {
                activeCtx = { type: 'ground', groundId: g.groundId, data: g, itemDef };
                showTooltip(ev.clientX, ev.clientY, activeCtx);
            }
        });

        groundSlots.appendChild(el);
    });
}

// --- Render vehicle storage slots ---
function renderVehicleSlots() {
    vehicleSlots.innerHTML = '';
    const maxSlots = state.vehMaxSlots || 20;
    for (let s = 1; s <= maxSlots; s++) {
        const data    = state.vehicleInv[String(s)] || state.vehicleInv[s] || null;
        const itemDef = data ? state.items[data.item] : null;
        const el = document.createElement('div');
        el.className    = 'veh-slot' + (data ? '' : ' empty');
        el.dataset.vehSlot = String(s);

        const num = document.createElement('span');
        num.className   = 'slot-num';
        num.textContent = s;
        el.appendChild(num);

        if (data && itemDef) {
            if (itemDef.icon && itemDef.icon.endsWith('.png')) {
                const img = document.createElement('img');
                img.className = 'slot-icon-img';
                img.src       = itemDef.icon;
                img.alt       = itemDef.label || '';
                el.appendChild(img);
            } else {
                const icon = document.createElement('div');
                icon.className   = 'slot-icon';
                icon.textContent = itemDef.icon || '\u{1F4E6}';
                el.appendChild(icon);
            }

            const label = document.createElement('div');
            label.className   = 'slot-label';
            label.textContent = itemDef.label || data.item;
            el.appendChild(label);

            if (itemDef.isWeapon) {
                const amt = document.createElement('div');
                amt.className   = 'slot-amount weapon-item-ammo';
                amt.textContent = data.amount + ' mun.';
                el.appendChild(amt);
            } else if (data.amount > 1) {
                const amt = document.createElement('div');
                amt.className   = 'slot-amount';
                amt.textContent = 'x' + data.amount;
                el.appendChild(amt);
            }

            el.addEventListener('mousedown', (ev) => {
                if (ev.button !== 0) return;
                startDrag(ev, 'vehicle', s, null, el, itemDef, data);
            });

            el.addEventListener('contextmenu', (ev) => {
                ev.preventDefault();
                activeCtx = { type: 'vehicle', slot: s, data, itemDef };
                showTooltip(ev.clientX, ev.clientY, activeCtx);
            });
        } else {
            el.classList.add('empty');
        }

        vehicleSlots.appendChild(el);
    }
}

// --- Vehicle weight ---
function updateVehicleWeight() {
    if (!state.vehicleContext) return;
    let total = 0;
    for (const [, data] of Object.entries(state.vehicleInv)) {
        if (!data) continue;
        const d = state.items[data.item];
        if (d) total += d.weight * data.amount;
    }
    total = Math.round(total * 10) / 10;
    const maxW = state.vehMaxWeight || 50;
    const pct = Math.min((total / maxW) * 100, 100);
    if (proxWeightDot) {
        proxWeightDot.style.width = pct + '%';
        proxWeightDot.classList.toggle('danger', pct > 80);
    }
    if (proxWeightText) proxWeightText.textContent = total + '/' + maxW + 'Kg';
}

// --- Render hotbar (armes + items) ---
function renderHotbar() {
    if (!hotbarEl) return;
    const slots = hotbarEl.querySelectorAll('.hotbar-slot');

    slots.forEach((el, idx) => {
        const slotNum = idx + 1;
        el.innerHTML = '';
        el.className = 'hotbar-slot';
        el.onmousedown = null;
        el.onclick = null;
        el.oncontextmenu = null;

        // Check weapon slot
        const wSlot = state.weaponSlots && state.weaponSlots[idx];
        const hasWeapon = wSlot && wSlot.hasWeapon;

        // Check item slot (hotbar now stores full data)
        const hotbarItem = state.hotbarItems[slotNum];
        const hasItem = hotbarItem && hotbarItem.data;

        if (hasWeapon) {
            el.classList.add('has-weapon');
            el.dataset.slotIndex = String(wSlot.index);
            el.dataset.category  = wSlot.category;
            if (wSlot.equipped) el.classList.add('equipped');

            const weaponKey = wSlot.weapon ? wSlot.weapon.toLowerCase() : null;
            if (weaponKey) {
                const wImg = document.createElement('img');
                wImg.className = 'hotbar-weapon-img';
                wImg.src       = 'img/weapons/' + weaponKey + '.png';
                wImg.alt       = wSlot.weaponLabel;
                el.appendChild(wImg);
            } else {
                const name = document.createElement('span');
                name.className   = 'hotbar-weapon-name';
                name.textContent = wSlot.weaponLabel;
                el.appendChild(name);
            }

            el.onmousedown = (ev) => {
                if (ev.button !== 0) return;
                const weaponImg = weaponKey ? ('img/weapons/' + weaponKey + '.png') : null;
                const fakeItemDef = { icon: weaponImg || (WEAPON_ICONS[wSlot.category] || '\u{1F52B}'), isWeapon: true };
                startDrag(ev, 'weapon', null, null, el, fakeItemDef, null, wSlot.category);
            };

            el.onclick = () => {
                if (!drag.moved) {
                    postNUI('equipWeapon', { slotIndex: wSlot.index });
                }
            };

            el.oncontextmenu = (ev) => {
                ev.preventDefault();
                postNUI('unequipWeaponToInv', { category: wSlot.category });
            };
        } else if (hasItem) {
            const invData = hotbarItem.data;
            const itemDef = state.items[invData.item];
            if (itemDef) {
                el.classList.add('has-item');

                if (itemDef.icon && itemDef.icon.endsWith('.png')) {
                    const img = document.createElement('img');
                    img.className = 'hotbar-weapon-img';
                    img.src       = itemDef.icon;
                    img.alt       = itemDef.label || '';
                    el.appendChild(img);
                } else {
                    const icon = document.createElement('span');
                    icon.className   = 'hotbar-item-icon';
                    icon.textContent = itemDef.icon || '\u{1F4E6}';
                    el.appendChild(icon);
                }

                const label = document.createElement('span');
                label.className   = 'hotbar-item-label';
                label.textContent = itemDef.label || invData.item;
                el.appendChild(label);

                if (itemDef.isWeapon) {
                    const amt = document.createElement('span');
                    amt.className   = 'hotbar-item-amount';
                    amt.textContent = invData.amount + ' mun.';
                    el.appendChild(amt);
                } else if (invData.amount > 1) {
                    const amt = document.createElement('span');
                    amt.className   = 'hotbar-item-amount';
                    amt.textContent = 'x' + invData.amount;
                    el.appendChild(amt);
                }

                el.onmousedown = (ev) => {
                    if (ev.button !== 0) return;
                    startDrag(ev, 'hotbar-item', null, null, el, itemDef, invData, null);
                    drag.hotbarSlot = slotNum;
                };

                el.onclick = () => {
                    if (!drag.moved) {
                        if (itemDef.isWeapon) {
                            // Equip weapon directly on ped (no weapon slot system)
                            postNUI('hotbarEquipWeapon', { weaponName: itemDef.weaponName, category: itemDef.weaponCategory, ammo: hotbarItem.data.amount != null ? hotbarItem.data.amount : 1 });
                            postNUI('closeInventory', {});
                        } else if (itemDef.usable) {
                            showUsedItemNotif(itemDef);
                            // Use item (server has the item in inventory)
                            postNUI('useItem', { slot: hotbarItem.invSlot, itemName: hotbarItem.data.item });
                            postNUI('closeInventory', {});
                        }
                    }
                };

                el.oncontextmenu = (ev) => {
                    ev.preventDefault();
                    // Restore item to inventory
                    const targetSlot = hotbarItem.invSlot || findEmptyInvSlot();
                    if (targetSlot) {
                        state.inventory[targetSlot] = hotbarItem.data;
                    }
                    delete state.hotbarItems[slotNum];
                    renderGrid();
                    renderHotbar();
                    updateWeight();
                };
            } else {
                // itemDef not found — restore to inventory
                if (hotbarItem.invSlot) state.inventory[hotbarItem.invSlot] = hotbarItem.data;
                delete state.hotbarItems[slotNum];
                const key = document.createElement('span');
                key.className   = 'hotbar-key';
                key.textContent = 'Slot ' + slotNum;
                el.appendChild(key);
            }
        } else {
            if (hotbarItem) delete state.hotbarItems[slotNum];
            const key = document.createElement('span');
            key.className   = 'hotbar-key';
            key.textContent = 'Slot ' + slotNum;
            el.appendChild(key);
        }
    });
}

// --- Factory slot inventaire ---
function makeSlot(s, data, itemDef) {
    const el = document.createElement('div');
    el.className    = 'slot' + (data ? '' : ' empty');
    el.dataset.slot = String(s);

    const num = document.createElement('span');
    num.className   = 'slot-num';
    num.textContent = s;
    el.appendChild(num);

    if (state.selectedSlot === s) {
        el.classList.add('active-slot');
    }

    if (data && itemDef) {
        if (itemDef.icon && itemDef.icon.endsWith('.png')) {
            const img = document.createElement('img');
            img.className = 'slot-icon-img';
            img.src       = itemDef.icon;
            img.alt       = itemDef.label || '';
            el.appendChild(img);
        } else {
            const icon = document.createElement('div');
            icon.className   = 'slot-icon';
            icon.textContent = itemDef.icon || '\u{1F4E6}';
            el.appendChild(icon);
        }

        const label = document.createElement('div');
        label.className   = 'slot-label';
        label.textContent = itemDef.label || data.item;
        el.appendChild(label);

        if (itemDef.isWeapon) {
            const amt = document.createElement('div');
            amt.className   = 'slot-amount weapon-item-ammo';
            amt.textContent = data.amount + ' mun.';
            el.appendChild(amt);
        } else if (data.amount > 1) {
            const amt = document.createElement('div');
            amt.className   = 'slot-amount';
            amt.textContent = 'x' + data.amount;
            el.appendChild(amt);
        }

        // Drag
        el.addEventListener('mousedown', (ev) => {
            if (ev.button !== 0) return;
            startDrag(ev, 'inv', s, null, el, itemDef, data);
        });

        // Right click
        el.addEventListener('contextmenu', (ev) => {
            ev.preventDefault();
            activeCtx = { type: 'inv', slot: s, data, itemDef };
            state.selectedSlot = s;
            document.querySelectorAll('.slot').forEach(sl => sl.classList.remove('active-slot'));
            el.classList.add('active-slot');
            showTooltip(ev.clientX, ev.clientY, activeCtx);
            updateActionButtons();
        });

        // Left click to select
        el.addEventListener('click', () => {
            if (!drag.moved) {
                if (state.selectedSlot === s) {
                    state.selectedSlot = null;
                    activeCtx = null;
                    hideTooltip();
                } else {
                    state.selectedSlot = s;
                    activeCtx = { type: 'inv', slot: s, data, itemDef };
                }
                document.querySelectorAll('.slot').forEach(sl => sl.classList.remove('active-slot'));
                if (state.selectedSlot === s) el.classList.add('active-slot');
            }
        });
    } else {
        el.addEventListener('click', () => {
            if (activeCtx && !drag.moved) {
                hideTooltip();
                document.querySelectorAll('.slot').forEach(sl => sl.classList.remove('active-slot'));
                activeCtx = null;
                state.selectedSlot = null;
            }
        });
    }

    return el;
}


// ============================================
//  DRAG SYSTEM
// ============================================

function startDrag(ev, type, slot, groundId, srcEl, itemDef, data, category) {
    ev.preventDefault();

    drag.active   = true;
    drag.type     = type;
    drag.slot     = slot;
    drag.groundId = groundId;
    drag.category = category || null;
    drag.srcEl    = srcEl;
    drag.startX   = ev.clientX;
    drag.startY   = ev.clientY;
    drag.moved    = false;
    drag.itemDef  = itemDef || null;
    drag.data     = data || null;

    const ghost = document.createElement('div');
    ghost.className = 'drag-ghost';
    const iconVal = itemDef.icon || '\u{1F4E6}';
    if (iconVal.endsWith && iconVal.endsWith('.png')) {
        const gImg = document.createElement('img');
        gImg.src = iconVal;
        gImg.style.cssText = 'width:40px; height:40px; object-fit:contain; filter:drop-shadow(0 0 4px rgba(74,144,217,0.8));';
        ghost.appendChild(gImg);
    } else {
        ghost.textContent = iconVal;
    }
    ghost.style.cssText =
        'position: fixed;' +
        'pointer-events: none;' +
        'z-index: 99999;' +
        'font-size: 28px;' +
        'background: rgba(20, 60, 120, 0.9);' +
        'border: 2px solid rgba(74, 144, 217, 0.8);' +
        'border-radius: 10px;' +
        'padding: 6px 10px;' +
        'box-shadow: 0 4px 20px rgba(74, 144, 217, 0.5);' +
        'transform: translate(-50%, -50%) scale(1.15);' +
        'transition: transform 0.1s;' +
        'opacity: 0.92;' +
        'left:' + ev.clientX + 'px;' +
        'top:' + ev.clientY + 'px;';
    document.body.appendChild(ghost);
    drag.ghost = ghost;
}

document.addEventListener('mousemove', (ev) => {
    if (!drag.active) return;

    const dx = ev.clientX - drag.startX;
    const dy = ev.clientY - drag.startY;

    if (!drag.moved && Math.sqrt(dx*dx + dy*dy) > 4) {
        drag.moved = true;
        drag.srcEl.classList.add('dragging');
    }

    if (drag.moved) {
        drag.ghost.style.left = ev.clientX + 'px';
        drag.ghost.style.top  = ev.clientY + 'px';

        document.querySelectorAll('.slot, .ground-slot, .hotbar-slot, .veh-slot')
                .forEach(sl => sl.classList.remove('drag-over'));

        const target = getDropTarget(ev.clientX, ev.clientY);
        if (target) target.classList.add('drag-over');

        // Ground zone highlight (only when no vehicle context)
        if (!state.vehicleContext) {
            const gRect = groundZone.getBoundingClientRect();
            const overGround = ev.clientX >= gRect.left && ev.clientX <= gRect.right
                            && ev.clientY >= gRect.top  && ev.clientY <= gRect.bottom;
            groundZone.classList.toggle('drag-over-ground',
                overGround && drag.type === 'inv');
        }

        // Vehicle zone highlight
        if (state.vehicleContext && vehicleZone) {
            const vRect = vehicleZone.getBoundingClientRect();
            const overVehicle = ev.clientX >= vRect.left && ev.clientX <= vRect.right
                             && ev.clientY >= vRect.top  && ev.clientY <= vRect.bottom;
            vehicleZone.classList.toggle('drag-over-vehicle',
                overVehicle && (drag.type === 'inv' || drag.type === 'vehicle'));
        }
    }
});

document.addEventListener('mouseup', (ev) => {
    if (!drag.active) return;
    if (ev.button !== 0) return;

    document.querySelectorAll('.slot, .ground-slot, .hotbar-slot, .veh-slot')
            .forEach(sl => sl.classList.remove('drag-over'));
    groundZone.classList.remove('drag-over-ground');
    if (vehicleZone) vehicleZone.classList.remove('drag-over-vehicle');

    let dropTarget = null;
    if (drag.moved) {
        dropTarget = getDropTarget(ev.clientX, ev.clientY);
    }

    const wasMoved       = drag.moved;
    const dragType       = drag.type;
    const dragSlot       = drag.slot;
    const dragGround     = drag.groundId;
    const dragCategory   = drag.category;
    const dragItemDef    = drag.itemDef;
    const dragData       = drag.data;
    const dragHotbarSlot = drag.hotbarSlot || null;
    const isShift        = ev.shiftKey;
    const evClientX      = ev.clientX;
    const evClientY      = ev.clientY;

    cancelDrag();

    if (wasMoved) {
        handleDrop(dropTarget, evClientX, evClientY, dragType, dragSlot, dragGround, isShift, dragCategory, dragItemDef, dragData, dragHotbarSlot);
    }
});

async function handleDrop(target, clientX, clientY, dragType, dragSlot, dragGroundId, isShift, dragCategory, dragItemDef, dragData, dragHotbarSlot) {
    if (target) {
        const toSlot    = parseInt(target.dataset.slot, 10);
        const isHotbarTarget = target.classList.contains('hotbar-slot');
        const isInvTarget    = target.classList.contains('slot') && !isNaN(toSlot);
        const isVehTarget    = target.classList.contains('veh-slot');
        const vehSlot        = isVehTarget ? parseInt(target.dataset.vehSlot, 10) : null;

        if (dragType === 'inv') {
            if (isVehTarget && state.vehicleContext && vehSlot) {
                // inv → vehicle
                const data = state.inventory[dragSlot];
                if (data) {
                    const amount = data.amount;
                    if (isShift && amount > 1) {
                        const result = await showQtyModal('Deposer combien ?', amount, false);
                        if (result && result.qty > 0) {
                            postNUI('moveToVehicle', { invSlot: dragSlot, vehSlot, amount: result.qty });
                        }
                    } else {
                        postNUI('moveToVehicle', { invSlot: dragSlot, vehSlot, amount });
                    }
                }
            } else if (isHotbarTarget) {
                const hotbarSlotNum = parseInt(target.dataset.slot, 10);
                if (dragItemDef && !isNaN(hotbarSlotNum) && hotbarSlotNum >= 1) {
                    const existing = state.hotbarItems[hotbarSlotNum];
                    if (existing && existing.data && existing.invSlot) {
                        state.inventory[existing.invSlot] = existing.data;
                    }
                    const itemData = state.inventory[dragSlot];
                    state.hotbarItems[hotbarSlotNum] = { invSlot: dragSlot, data: { ...itemData } };
                    delete state.inventory[dragSlot];
                    renderGrid();
                    renderHotbar();
                    updateWeight();
                }
            } else if (isInvTarget && dragSlot !== toSlot) {
                const data = state.inventory[dragSlot];
                if (isShift && data && data.amount > 1) {
                    const result = await showQtyModal('Deplacer combien ?', data.amount, false);
                    if (result && result.qty > 0) {
                        postNUI('moveItem', { fromSlot: dragSlot, toSlot, amount: result.qty });
                    }
                } else {
                    postNUI('moveItem', { fromSlot: dragSlot, toSlot });
                }
            }
        }

        if (dragType === 'vehicle') {
            if (isInvTarget && state.vehicleContext) {
                // vehicle → inv
                const data = dragData;
                if (data) {
                    const amount = data.amount;
                    if (isShift && amount > 1) {
                        const result = await showQtyModal('Retirer combien ?', amount, false);
                        if (result && result.qty > 0) {
                            postNUI('moveFromVehicle', { vehSlot: dragSlot, invSlot: toSlot, amount: result.qty });
                        }
                    } else {
                        postNUI('moveFromVehicle', { vehSlot: dragSlot, invSlot: toSlot, amount });
                    }
                }
            } else if (isVehTarget && vehSlot && dragSlot !== vehSlot) {
                // vehicle → vehicle (reorganize within storage)
                const data = dragData;
                if (data) {
                    if (isShift && data.amount > 1) {
                        const result = await showQtyModal('Deplacer combien ?', data.amount, false);
                        if (result && result.qty > 0) {
                            postNUI('moveInVehicle', { fromSlot: dragSlot, toSlot: vehSlot, amount: result.qty });
                        }
                    } else {
                        postNUI('moveInVehicle', { fromSlot: dragSlot, toSlot: vehSlot });
                    }
                }
            }
        }

        if (dragType === 'ground' && isInvTarget) {
            postNUI('pickupFromGround', { groundId: dragGroundId, toSlot });
        }

        if (dragType === 'weapon' && isInvTarget) {
            postNUI('unequipWeaponToInv', { category: dragCategory });
        }

        if (dragType === 'hotbar-item') {
            if (dragHotbarSlot) {
                const hItem = state.hotbarItems[dragHotbarSlot];
                if (isInvTarget) {
                    if (hItem && hItem.data) {
                        const targetData = state.inventory[toSlot];
                        state.inventory[toSlot] = hItem.data;
                        if (targetData) {
                            const origSlot = hItem.invSlot || findEmptyInvSlot();
                            if (origSlot) state.inventory[origSlot] = targetData;
                        }
                    }
                    delete state.hotbarItems[dragHotbarSlot];
                    renderGrid();
                    renderHotbar();
                    updateWeight();
                } else if (isHotbarTarget) {
                    const newSlotNum = parseInt(target.dataset.slot, 10);
                    if (!isNaN(newSlotNum) && newSlotNum >= 1 && newSlotNum !== dragHotbarSlot) {
                        const otherItem = state.hotbarItems[newSlotNum] || null;
                        state.hotbarItems[newSlotNum] = hItem;
                        if (otherItem) {
                            state.hotbarItems[dragHotbarSlot] = otherItem;
                        } else {
                            delete state.hotbarItems[dragHotbarSlot];
                        }
                        renderHotbar();
                    }
                } else {
                    if (hItem && hItem.data) {
                        const origSlot = hItem.invSlot || findEmptyInvSlot();
                        if (origSlot) state.inventory[origSlot] = hItem.data;
                    }
                    delete state.hotbarItems[dragHotbarSlot];
                    renderGrid();
                    renderHotbar();
                    updateWeight();
                }
            }
        }

    } else {
        // Dropped on no specific slot target — check zone areas
        if (state.vehicleContext && vehicleZone && dragType === 'inv') {
            // Check if dropped in vehicle zone area (no specific slot)
            const vRect = vehicleZone.getBoundingClientRect();
            const overVeh = clientX >= vRect.left && clientX <= vRect.right
                         && clientY >= vRect.top  && clientY <= vRect.bottom;
            if (overVeh) {
                const data = state.inventory[dragSlot];
                if (!data) return;
                // Find first empty vehicle slot
                let emptyVehSlot = null;
                const maxVSlots = state.vehMaxSlots || 20;
                for (let vs = 1; vs <= maxVSlots; vs++) {
                    if (!state.vehicleInv[String(vs)] && !state.vehicleInv[vs]) {
                        emptyVehSlot = vs;
                        break;
                    }
                }
                if (emptyVehSlot) {
                    if (isShift && data.amount > 1) {
                        const result = await showQtyModal('Deposer combien ?', data.amount, false);
                        if (result && result.qty > 0) {
                            postNUI('moveToVehicle', { invSlot: dragSlot, vehSlot: emptyVehSlot, amount: result.qty });
                        }
                    } else {
                        postNUI('moveToVehicle', { invSlot: dragSlot, vehSlot: emptyVehSlot, amount: data.amount });
                    }
                }
                return;
            }
        }

        // Vehicle item dropped in inventory area (no specific slot) → find empty slot
        if (state.vehicleContext && dragType === 'vehicle') {
            const gRect = grid.getBoundingClientRect();
            const overInv = clientX >= gRect.left && clientX <= gRect.right
                         && clientY >= gRect.top  && clientY <= gRect.bottom;
            if (overInv) {
                const data = dragData;
                if (!data) return;
                const emptySlot = findEmptyInvSlot();
                if (emptySlot) {
                    if (isShift && data.amount > 1) {
                        const result = await showQtyModal('Retirer combien ?', data.amount, false);
                        if (result && result.qty > 0) {
                            postNUI('moveFromVehicle', { vehSlot: dragSlot, invSlot: emptySlot, amount: result.qty });
                        }
                    } else {
                        postNUI('moveFromVehicle', { vehSlot: dragSlot, invSlot: emptySlot, amount: data.amount });
                    }
                }
                return;
            }
        }

        if (!state.vehicleContext) {
            const gRect = groundZone.getBoundingClientRect();
            const overGround = clientX >= gRect.left && clientX <= gRect.right
                            && clientY >= gRect.top  && clientY <= gRect.bottom;
            if (overGround && dragType === 'inv') {
                const data = state.inventory[dragSlot];
                if (!data) return;
                if (isShift && data.amount > 1) {
                    const result = await showQtyModal('Jeter combien ?', data.amount, false);
                    if (result && result.qty > 0) {
                        postNUI('dropToGround', { slot: dragSlot, amount: result.qty });
                    }
                } else {
                    postNUI('dropToGround', { slot: dragSlot, amount: data.amount });
                }
            }
        }

        if (dragType === 'hotbar-item' && dragHotbarSlot) {
            const hItem = state.hotbarItems[dragHotbarSlot];
            if (hItem && hItem.data) {
                const origSlot = hItem.invSlot || findEmptyInvSlot();
                if (origSlot) state.inventory[origSlot] = hItem.data;
            }
            delete state.hotbarItems[dragHotbarSlot];
            renderGrid();
            renderHotbar();
            updateWeight();
        }
    }
}

document.addEventListener('mouseleave', cancelDrag);

function cancelDrag() {
    if (!drag.active) return;
    if (drag.ghost)  drag.ghost.remove();
    if (drag.srcEl)  drag.srcEl.classList.remove('dragging');
    document.querySelectorAll('.slot, .ground-slot, .hotbar-slot, .veh-slot')
            .forEach(sl => sl.classList.remove('drag-over'));
    groundZone.classList.remove('drag-over-ground');
    if (vehicleZone) vehicleZone.classList.remove('drag-over-vehicle');
    drag = { active: false, type: null, slot: null, groundId: null, category: null,
             ghost: null, srcEl: null, startX: 0, startY: 0, moved: false,
             itemDef: null, data: null };
}

function getDropTarget(x, y) {
    if (drag.ghost) drag.ghost.style.display = 'none';
    const el = document.elementFromPoint(x, y);
    if (drag.ghost) drag.ghost.style.display = '';

    if (!el) return null;
    const hotbarSlot = el.closest('.hotbar-slot');
    if (hotbarSlot) return hotbarSlot;
    const vehSlot = el.closest('.veh-slot');
    if (vehSlot) return vehSlot;
    const slot = el.closest('.slot');
    if (slot) return slot;
    return null;
}

// --- Weight ---
function updateWeight() {
    let total = 0;
    for (const [, data] of Object.entries(state.inventory)) {
        if (!data) continue;
        const d = state.items[data.item];
        if (d) total += d.weight * data.amount;
    }
    total = Math.round(total * 10) / 10;
    const pct = Math.min((total / state.maxWeight) * 100, 100);
    if (weightDot) {
        weightDot.style.width = pct + '%';
        weightDot.classList.toggle('danger', pct > 80);
    }
    if (weightText) weightText.textContent = total + '/' + state.maxWeight + 'Kg';
}

// --- Tooltip ---
function showTooltip(x, y, ctx) {
    const { type, slot, groundId, data, itemDef } = ctx;

    ttIcon.textContent   = itemDef.icon || '\u{1F4E6}';
    ttName.textContent   = itemDef.label || data.item;

    if (data.item === 'vehicle_key' && data.metadata && data.metadata.plate) {
        ttDesc.textContent = 'Plaque : ' + data.metadata.plate;
    } else {
        ttDesc.textContent = itemDef.description || '';
    }

    ttWeight.textContent = '\u2696 ' + itemDef.weight + ' kg  \u00b7  x' + data.amount;

    if (type === 'inv') {
        ttUse.style.display     = itemDef.usable ? '' : 'none';
        ttPickup.style.display  = 'none';
        ttDrop.style.display    = '';
        ttDropAll.style.display = '';
        ttGive.style.display    = '';

        ttDrop.textContent = 'Jeter';

        ttUse.onclick = () => {
            showUsedItemNotif(itemDef);
            postNUI('useItem', { slot, itemName: data.item });
            hideTooltip();
            postNUI('closeInventory', {});
        };

        ttDrop.onclick = async () => {
            hideTooltip();
            const result = await showQtyModal('Jeter combien ?', data.amount, false);
            if (result && result.qty > 0) {
                postNUI('dropToGround', { slot, amount: result.qty });
            }
        };

        ttDropAll.onclick = () => {
            postNUI('dropToGround', { slot, amount: data.amount });
            hideTooltip();
        };

        ttGive.onclick = async () => {
            hideTooltip();
            const result = await showQtyModal('Donner a un joueur', data.amount, true);
            if (result && result.qty > 0 && result.targetId) {
                postNUI('giveToPlayer', { slot, targetId: result.targetId, amount: result.qty });
            }
        };
    } else if (type === 'vehicle') {
        ttUse.style.display     = 'none';
        ttPickup.style.display  = '';
        ttDrop.style.display    = 'none';
        ttDropAll.style.display = 'none';
        ttGive.style.display    = 'none';

        ttPickup.textContent = 'Retirer';
        ttPickup.onclick = () => {
            const emptySlot = findEmptyInvSlot();
            if (emptySlot) {
                postNUI('moveFromVehicle', { vehSlot: slot, invSlot: emptySlot, amount: data.amount });
            }
            hideTooltip();
        };
    } else {
        ttUse.style.display     = 'none';
        ttPickup.style.display  = '';
        ttDrop.style.display    = 'none';
        ttDropAll.style.display = 'none';
        ttGive.style.display    = 'none';

        ttPickup.textContent = 'Ramasser';
        ttPickup.onclick = () => { postNUI('pickupFromGround', { groundId, toSlot: null }); hideTooltip(); };
    }

    tooltip.classList.remove('hidden');
    tooltip.classList.add('has-actions');

    const tw = tooltip.offsetWidth  || 230;
    const th = tooltip.offsetHeight || 160;
    let lx = x + 14, ly = y + 14;
    if (lx + tw > window.innerWidth)  lx = x - tw - 14;
    if (ly + th > window.innerHeight) ly = y - th - 14;
    tooltip.style.left = lx + 'px';
    tooltip.style.top  = ly + 'px';
}

function hideTooltip() {
    tooltip.classList.add('hidden');
    tooltip.classList.remove('has-actions');
}

// ============================================
//  QUANTITY MODAL
// ============================================

function showQtyModal(title, maxQty, showTarget) {
    return new Promise((resolve) => {
        qtyModal.resolve = resolve;
        qtyModal.maxQty  = maxQty;

        qtyModalTitle.textContent = title;
        qtyInput.value = maxQty;
        qtyInput.max   = maxQty;
        qtyInput.min   = 1;
        qtyTargetInput.value = '';

        if (showTarget) {
            qtyTargetRow.classList.remove('hidden');
        } else {
            qtyTargetRow.classList.add('hidden');
        }

        qtyModalEl.classList.remove('hidden');
        qtyInput.focus();
        qtyInput.select();
    });
}

function hideQtyModal() {
    qtyModalEl.classList.add('hidden');
    if (qtyModal.resolve) {
        qtyModal.resolve(null);
        qtyModal.resolve = null;
    }
}

qtyConfirmBtn.addEventListener('click', () => {
    let qty = parseInt(qtyInput.value, 10) || 0;
    qty = Math.max(1, Math.min(qty, qtyModal.maxQty));
    const targetId = parseInt(qtyTargetInput.value, 10) || null;

    qtyModalEl.classList.add('hidden');
    if (qtyModal.resolve) {
        qtyModal.resolve({ qty, targetId });
        qtyModal.resolve = null;
    }
});

qtyCancelBtn.addEventListener('click', () => {
    hideQtyModal();
});

qtyAllBtn.addEventListener('click', () => {
    qtyInput.value = qtyModal.maxQty;
    qtyInput.focus();
});

qtyInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') qtyConfirmBtn.click();
});
qtyTargetInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') qtyConfirmBtn.click();
});

// --- Close / Escape ---
overlay.addEventListener('click', (e) => {
    if (e.target === overlay) {
        hideTooltip();
        activeCtx = null;
        state.selectedSlot = null;
        updateActionButtons();
        document.querySelectorAll('.slot').forEach(sl => sl.classList.remove('active-slot'));
    }
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        if (!qtyModalEl.classList.contains('hidden')) {
            hideQtyModal();
        } else {
            postNUI('closeInventory', {});
        }
    }

    // Hotbar shortcuts 1-5 when inventory is open (NUI has focus, Lua keys don't fire)
    if (!qtyModalEl.classList.contains('hidden')) return;
    const num = parseInt(e.key, 10);
    if (num >= 1 && num <= 5 && !overlay.classList.contains('hidden')) {
        const hItem = state.hotbarItems[num];
        if (hItem && hItem.data) {
            const itemDef = state.items[hItem.data.item];
            if (itemDef) {
                if (itemDef.isWeapon) {
                    postNUI('hotbarEquipWeapon', { weaponName: itemDef.weaponName, category: itemDef.weaponCategory, ammo: hItem.data.amount != null ? hItem.data.amount : 1 });
                    postNUI('closeInventory', {});
                } else if (itemDef.usable) {
                    showUsedItemNotif(itemDef);
                    postNUI('useItem', { slot: hItem.invSlot, itemName: hItem.data.item });
                    postNUI('closeInventory', {});
                }
            }
        }
    }
});

// --- Action Buttons ---
function updateActionButtons() {
    const hasSelection = activeCtx && activeCtx.type === 'inv' && activeCtx.itemDef;
    if (actionUse)  actionUse.disabled  = !(hasSelection && activeCtx.itemDef.usable);
    if (actionGive) actionGive.disabled = !hasSelection;
    if (actionDrop) actionDrop.disabled = !hasSelection;
}

if (actionUse) {
    actionUse.addEventListener('click', () => {
        if (!activeCtx || activeCtx.type !== 'inv') return;
        showUsedItemNotif(activeCtx.itemDef);
        postNUI('useItem', { slot: activeCtx.slot, itemName: activeCtx.data.item });
        hideTooltip();
        postNUI('closeInventory', {});
    });
}

if (actionDrop) {
    actionDrop.addEventListener('click', () => {
        if (!activeCtx || activeCtx.type !== 'inv') return;
        const qty = parseInt(actionQty ? actionQty.value : '1', 10) || 1;
        const amount = Math.min(qty, activeCtx.data.amount);
        postNUI('dropToGround', { slot: activeCtx.slot, amount });
        hideTooltip();
        activeCtx = null;
        state.selectedSlot = null;
        updateActionButtons();
        document.querySelectorAll('.slot').forEach(sl => sl.classList.remove('active-slot'));
    });
}

if (actionGive) {
    actionGive.addEventListener('click', async () => {
        if (!activeCtx || activeCtx.type !== 'inv') return;
        hideTooltip();
        const result = await showQtyModal('Donner a un joueur', activeCtx.data.amount, true);
        if (result && result.qty > 0 && result.targetId) {
            postNUI('giveToPlayer', { slot: activeCtx.slot, targetId: result.targetId, amount: result.qty });
        }
        activeCtx = null;
        state.selectedSlot = null;
        updateActionButtons();
        document.querySelectorAll('.slot').forEach(sl => sl.classList.remove('active-slot'));
    });
}

// --- Used item notification ---
function showUsedItemNotif(itemDef) {
    if (!itemDef) return;

    usedItemIcon.textContent = itemDef.icon || '\u{1F4E6}';
    usedItemLabel.textContent = itemDef.label || itemDef.name || 'Objet';

    usedItemNotif.classList.remove('hidden');
    void usedItemNotif.offsetWidth;
    usedItemNotif.classList.add('show');

    if (usedItemTimer) clearTimeout(usedItemTimer);
    usedItemTimer = setTimeout(() => {
        usedItemNotif.classList.remove('show');
        setTimeout(() => usedItemNotif.classList.add('hidden'), 400);
        usedItemTimer = null;
    }, 3000);
}

// --- NUI Callback ---
function postNUI(event, data) {
    fetch('https://inv_system/' + event, {
        method : 'POST',
        headers: { 'Content-Type': 'application/json' },
        body   : JSON.stringify(data),
    }).catch(() => {});
}
