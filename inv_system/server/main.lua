-- server/main.lua

PlayerInventories = {}
GroundItems       = {}
GroundCounter     = 0

-- ─── Helpers ──────────────────────────────────────────────────────────────────
function GetIdentifier(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, 8) == 'license:' then return id end
    end
    return nil
end

function SerializeInventory(inv)
    local out = {}
    for slot, data in pairs(inv or {}) do
        out[tostring(slot)] = data
    end
    return out
end

-- Ajoute des items dans un inventaire en respectant le maxStack.
-- Retourne le nombre d'items qui n'ont pas pu être placés (inventaire plein).
function AddItemToInventory(inv, itemName, totalAmount)
    local remaining = totalAmount
    local itemDef   = Items[itemName]
    local maxStack  = (itemDef and itemDef.maxStack) or 99
    local stackable = itemDef and itemDef.stackable

    if stackable then
        for slot = 1, Config.MaxSlots do
            if remaining <= 0 then break end
            local d = inv[slot]
            if d and d.item == itemName and d.amount < maxStack then
                local canAdd = maxStack - d.amount
                local toAdd  = math.min(remaining, canAdd)
                d.amount  = d.amount + toAdd
                remaining = remaining - toAdd
            end
        end
    end

    while remaining > 0 do
        local emptySlot = nil
        for slot = 1, Config.MaxSlots do
            if not inv[slot] then emptySlot = slot; break end
        end
        if not emptySlot then break end

        local toPlace = stackable and math.min(remaining, maxStack) or 1
        inv[emptySlot] = { item = itemName, amount = toPlace }
        remaining = remaining - toPlace
    end

    return remaining
end

function GetNearGroundForPlayer(src)
    local ped  = GetPlayerPed(src)
    local pPos = GetEntityCoords(ped)
    local near = {}
    for _, g in pairs(GroundItems) do
        local dist = #(vector3(pPos.x, pPos.y, pPos.z) - vector3(g.x, g.y, g.z))
        if dist <= 10.0 then
            near[#near + 1] = { groundId = g.id, item = g.item, amount = g.amount }
        end
    end
    return near
end

function NotifyNearbyPlayers(pos, excludeSrc)
    for _, playerId in ipairs(GetPlayers()) do
        local pid = tonumber(playerId)
        if pid ~= excludeSrc then
            local ped2 = GetPlayerPed(pid)
            local pos2 = GetEntityCoords(ped2)
            local dist = #(vector3(pos.x, pos.y, pos.z) - vector3(pos2.x, pos2.y, pos2.z))
            if dist <= 10.0 then
                TriggerClientEvent('inv:receiveInventory', pid,
                    SerializeInventory(PlayerInventories[pid] or {}),
                    GetNearGroundForPlayer(pid))
            end
        end
    end
end

-- ─── Connexion ────────────────────────────────────────────────────────────────
AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.defer()
    local identifier = GetIdentifier(src)
    if not identifier then
        deferrals.done('Impossible de lire votre identifiant.')
        return
    end
    DB_LoadInventory(identifier, function(inv)
        PlayerInventories[src] = inv
        deferrals.done()
    end)
end)

AddEventHandler('playerDropped', function()
    local src        = source
    local identifier = GetIdentifier(src)
    if identifier and PlayerInventories[src] then
        DB_SaveInventory(identifier, PlayerInventories[src])
    end
    PlayerInventories[src] = nil

    -- Sauvegarder tous les inventaires vehicules en cache
    if VehicleInventories then
        for key, inv in pairs(VehicleInventories) do
            local plate, sType = key:match('^(.+):(.+)$')
            if plate and sType then
                DB_SaveVehicleInventory(plate, sType, inv)
            end
        end
    end
end)

-- ─── Chargement synchrone de l'inventaire si pas en mémoire ─────────────────
function EnsureInventoryLoaded(src)
    if PlayerInventories[src] then return true end
    local identifier = GetIdentifier(src)
    if not identifier then return false end
    local rows = MySQL.query.await(
        'SELECT slot, item, amount, metadata FROM character_inventory WHERE identifier = ?',
        { identifier }
    )
    local inv = {}
    if rows then
        for _, row in ipairs(rows) do
            local meta = nil
            if row.metadata and row.metadata ~= '' then
                local ok, decoded = pcall(json.decode, row.metadata)
                if ok then meta = decoded end
            end
            inv[row.slot] = { item = row.item, amount = row.amount, metadata = meta }
        end
    end
    PlayerInventories[src] = inv
    return true
end

-- ─── Envoi inventaire (avec fallback DB si pas en mémoire) ──────────────────
RegisterNetEvent('inv:requestInventory', function()
    local src        = source
    local identifier = GetIdentifier(src)

    if PlayerInventories[src] then
        TriggerClientEvent('inv:receiveInventory', src,
            SerializeInventory(PlayerInventories[src]),
            GetNearGroundForPlayer(src))
    elseif identifier then
        DB_LoadInventory(identifier, function(inv)
            PlayerInventories[src] = inv
            TriggerClientEvent('inv:receiveInventory', src,
                SerializeInventory(inv),
                GetNearGroundForPlayer(src))
        end)
    else
        PlayerInventories[src] = {}
        TriggerClientEvent('inv:receiveInventory', src,
            SerializeInventory({}),
            GetNearGroundForPlayer(src))
    end
end)

-- ─── Utiliser un item ─────────────────────────────────────────────────────────
-- Le client envoie le slot + le nom de l'arme actuellement équipée (pour les ammo boxes)
RegisterNetEvent('inv:useItem', function(slot, clientEquippedWeapon)
    local src  = source
    slot = tonumber(slot)
    if not slot then return end

    local inv  = PlayerInventories[src]
    if not inv or not inv[slot] then return end

    local data    = inv[slot]
    local itemDef = Items[data.item]
    if not itemDef then return end

    local identifier = GetIdentifier(src)

    -- ═══ BOÎTE DE MUNITIONS ═══
    if itemDef.isAmmo then
        local weaponName = itemDef.ammoForWeapon
        if not weaponName then return end

        -- Vérifier que l'arme correspondante est bien équipée
        local equippedWeapon = (type(clientEquippedWeapon) == 'string' and clientEquippedWeapon ~= '') and clientEquippedWeapon or nil
        if not equippedWeapon or equippedWeapon ~= weaponName then
            local wDef = Weapons[weaponName]
            local wLabel = wDef and wDef.label or weaponName
            TriggerClientEvent('inv:chatNotify', src, '~r~Tu dois équiper ~w~' .. wLabel .. ' ~r~pour utiliser ces munitions.')
            return
        end

        -- Quantité de munitions à ajouter (clipSize/2, calculée dans shared/weapons.lua)
        local amount = itemDef.ammoAmount or 30

        -- Consommer 1 boîte de munitions
        data.amount = data.amount - 1
        if data.amount <= 0 then inv[slot] = nil end

        if identifier then
            DB_SaveSlot(identifier, slot, data.item, math.max(data.amount, 0), data.metadata)
        end

        -- Ajouter les munitions : essayer weapon slot puis inventaire (hotbar)
        local newTotal = 0
        local updated  = false

        -- 1) Slot arme (PlayerWeapons)
        updated, newTotal = AddAmmoToPlayerWeapon(src, weaponName, amount)

        -- 2) Item arme dans l'inventaire (équipée via hotbar)
        if not updated then
            for invSlot, invData in pairs(inv) do
                local iDef = Items[invData.item]
                if iDef and iDef.isWeapon and iDef.weaponName == weaponName then
                    local oldAmmo = invData.amount or 0
                    newTotal = oldAmmo + amount
                    invData.amount = newTotal
                    if identifier then
                        MySQL.query(
                            'UPDATE character_inventory SET amount = ? WHERE identifier = ? AND slot = ?',
                            { newTotal, identifier, invSlot }
                        )
                    end
                    updated = true
                    break
                end
            end
        end

        -- Envoyer l'inventaire mis à jour
        TriggerClientEvent('inv:receiveInventory', src,
            SerializeInventory(inv), GetNearGroundForPlayer(src))

        -- Dire au client de recharger l'arme (animation + sync ammo)
        TriggerClientEvent('inv:ammoReloaded', src, weaponName, amount, newTotal)

        local weaponDef = Weapons[weaponName]
        local weaponLabel = weaponDef and weaponDef.label or weaponName
        TriggerClientEvent('inv:chatNotify', src, '~g~+' .. amount .. ' munitions ~w~(' .. weaponLabel .. ') — Total: ' .. newTotal)
        return
    end

    -- ═══ ITEM NORMAL ═══
    local shouldConsume = (itemDef.consumeOnUse == nil) or (itemDef.consumeOnUse == true)

    if shouldConsume then
        data.amount = data.amount - 1
        if data.amount <= 0 then inv[slot] = nil end

        if identifier then
            DB_SaveSlot(identifier, slot, data.item, data.amount, data.metadata)
        end
    end

    TriggerClientEvent('inv:itemUsed', src, data.item, slot, inv[slot])
end)

-- ─── Déplacer inv → inv (supporte quantité partielle) ─────────────────────────
RegisterNetEvent('inv:moveItem', function(fromSlot, toSlot, moveAmount)
    local src = source
    local inv = PlayerInventories[src]
    if not inv then return end

    local fromData = inv[fromSlot]
    local toData   = inv[toSlot]
    if not fromData then return end

    local amount = moveAmount or fromData.amount
    amount = math.min(amount, fromData.amount)
    if amount <= 0 then return end

    if toData and toData.item == fromData.item then
        local maxStack = (Items[fromData.item] and Items[fromData.item].maxStack) or 99
        local canAdd   = maxStack - toData.amount
        local toAdd    = math.min(amount, canAdd)
        if toAdd <= 0 then return end

        toData.amount   = toData.amount + toAdd
        fromData.amount = fromData.amount - toAdd
        if fromData.amount <= 0 then inv[fromSlot] = nil end
    elseif toData then
        if amount == fromData.amount then
            inv[fromSlot] = toData
            inv[toSlot]   = fromData
        else
            return
        end
    else
        if amount == fromData.amount then
            inv[toSlot]   = fromData
            inv[fromSlot] = nil
        else
            inv[toSlot]     = { item = fromData.item, amount = amount, metadata = fromData.metadata }
            fromData.amount = fromData.amount - amount
        end
    end

    local identifier = GetIdentifier(src)
    DB_SaveInventory(identifier, inv)
    TriggerClientEvent('inv:receiveInventory', src,
        SerializeInventory(inv),
        GetNearGroundForPlayer(src))
end)

-- ─── Déposer au sol ───────────────────────────────────────────────────────────
RegisterNetEvent('inv:dropToGround', function(slot, amount)
    local src = source
    local inv = PlayerInventories[src]
    if not inv or not inv[slot] then return end

    local data  = inv[slot]
    amount      = math.min(amount, data.amount)
    if amount <= 0 then return end

    data.amount = data.amount - amount
    if data.amount <= 0 then inv[slot] = nil end

    local identifier = GetIdentifier(src)
    DB_SaveSlot(identifier, slot, data.item, data.amount, data.metadata)

    local ped = GetPlayerPed(src)
    local pos = GetEntityCoords(ped)
    GroundCounter = GroundCounter + 1
    GroundItems[GroundCounter] = {
        id       = GroundCounter,
        item     = data.item,
        amount   = amount,
        metadata = data.metadata,
        x = pos.x, y = pos.y, z = pos.z,
    }

    NotifyNearbyPlayers(pos, src)
    TriggerClientEvent('inv:receiveInventory', src,
        SerializeInventory(inv),
        GetNearGroundForPlayer(src))
end)

-- ─── Ramasser du sol ──────────────────────────────────────────────────────────
RegisterNetEvent('inv:pickupFromGround', function(groundId, toSlot)
    local src = source
    local inv = PlayerInventories[src]
    if not inv then return end

    local g = GroundItems[groundId]
    if not g then return end

    local ped  = GetPlayerPed(src)
    local pos  = GetEntityCoords(ped)
    local dist = #(vector3(pos.x, pos.y, pos.z) - vector3(g.x, g.y, g.z))
    if dist > 12.0 then return end

    local targetSlot = toSlot
    if not targetSlot then
        for s = 1, Config.MaxSlots do
            local d = inv[s]
            if d and d.item == g.item and Items[g.item] and Items[g.item].stackable then
                local maxStack = Items[g.item].maxStack or 99
                if d.amount < maxStack then
                    targetSlot = s
                    break
                end
            end
        end
        if not targetSlot then
            for s = 1, Config.MaxSlots do
                if not inv[s] then targetSlot = s; break end
            end
        end
    end

    if not targetSlot then
        TriggerClientEvent('inv:notify', src, 'Inventaire plein !')
        return
    end

    if inv[targetSlot] and inv[targetSlot].item == g.item then
        local maxStack = (Items[g.item] and Items[g.item].maxStack) or 99
        local canAdd   = maxStack - inv[targetSlot].amount
        local toAdd    = math.min(g.amount, canAdd)
        if toAdd <= 0 then
            TriggerClientEvent('inv:notify', src, 'Stack plein !')
            return
        end
        inv[targetSlot].amount = inv[targetSlot].amount + toAdd
        local leftover = g.amount - toAdd
        if leftover > 0 then
            g.amount = leftover
        else
            GroundItems[groundId] = nil
        end
    else
        inv[targetSlot] = { item = g.item, amount = g.amount, metadata = g.metadata }
        GroundItems[groundId] = nil
    end

    local identifier = GetIdentifier(src)
    DB_SaveInventory(identifier, inv)
    TriggerClientEvent('inv:receiveInventory', src,
        SerializeInventory(inv),
        GetNearGroundForPlayer(src))
end)

-- ─── Donner un item à un autre joueur (via UI) ───────────────────────────────
RegisterNetEvent('inv:giveToPlayer', function(slot, targetId, amount)
    local src = source
    slot     = tonumber(slot)
    targetId = tonumber(targetId)
    amount   = tonumber(amount)
    if not slot or not targetId or not amount then return end
    if amount <= 0 then return end

    if targetId == src then
        TriggerClientEvent('inv:chatNotify', src, '~r~Tu ne peux pas te donner un item à toi-même.')
        return
    end

    EnsureInventoryLoaded(src)
    local inv = PlayerInventories[src]
    if not inv or not inv[slot] then return end

    -- Verifier que le joueur cible existe sur le serveur
    local targetPed = GetPlayerPed(targetId)
    if not targetPed or targetPed == 0 then
        TriggerClientEvent('inv:chatNotify', src, '~r~Joueur introuvable (ID ' .. targetId .. ').')
        return
    end

    -- Charger l'inventaire du joueur cible si pas en memoire
    EnsureInventoryLoaded(targetId)
    local targetInv = PlayerInventories[targetId]
    if not targetInv then
        PlayerInventories[targetId] = {}
        targetInv = PlayerInventories[targetId]
    end

    -- Verifier la distance
    local ped1 = GetPlayerPed(src)
    local pos1 = GetEntityCoords(ped1)
    local pos2 = GetEntityCoords(targetPed)
    local dist = #(vector3(pos1.x, pos1.y, pos1.z) - vector3(pos2.x, pos2.y, pos2.z))
    if dist > 5.0 then
        TriggerClientEvent('inv:chatNotify', src, '~r~Joueur trop loin.')
        return
    end

    local data     = inv[slot]
    local itemName = data.item
    local itemLabel = Items[itemName] and Items[itemName].label or itemName

    -- Verifier que le joueur a assez de cet item
    if data.amount < amount then
        TriggerClientEvent('inv:chatNotify', src, '~r~Tu n\'as pas assez de ~w~' .. itemLabel .. '~r~. (Tu as x' .. data.amount .. ', besoin de x' .. amount .. ')')
        return
    end

    -- Ajouter au joueur cible
    local remaining = AddItemToInventory(targetInv, itemName, amount)
    local given     = amount - remaining

    if given <= 0 then
        TriggerClientEvent('inv:chatNotify', src, '~r~Inventaire du joueur plein.')
        return
    end

    -- Retirer du joueur source
    data.amount = data.amount - given
    if data.amount <= 0 then inv[slot] = nil end

    -- Sauvegarder les deux inventaires
    local srcIdentifier = GetIdentifier(src)
    local tgtIdentifier = GetIdentifier(targetId)
    if srcIdentifier then DB_SaveInventory(srcIdentifier, inv) end
    if tgtIdentifier then DB_SaveInventory(tgtIdentifier, targetInv) end

    -- Rafraichir les deux clients
    TriggerClientEvent('inv:receiveInventory', src,
        SerializeInventory(inv), GetNearGroundForPlayer(src))
    TriggerClientEvent('inv:receiveInventory', targetId,
        SerializeInventory(targetInv), GetNearGroundForPlayer(targetId))

    -- Notifications claires pour les deux joueurs
    TriggerClientEvent('inv:chatNotify', src,
        '~g~Tu as donné ~w~x' .. given .. ' ' .. itemLabel .. ' ~g~au joueur ~w~' .. targetId)
    TriggerClientEvent('inv:chatNotify', targetId,
        '~b~Tu as reçu ~w~x' .. given .. ' ' .. itemLabel .. ' ~b~d\'un autre joueur.')

    -- Si on n'a pas pu tout donner (inventaire cible partiellement plein)
    if remaining > 0 then
        TriggerClientEvent('inv:chatNotify', src,
            '~o~Attention : ~w~x' .. remaining .. ' ' .. itemLabel .. ' ~o~n\'ont pas pu être donnés (inventaire du joueur plein).')
    end
end)

-- ─── Admin command /giveitem (console + joueurs avec permission) ─────────────
RegisterCommand('giveitem', function(src, args)
    -- Vérifier la permission (console = toujours autorisé)
    if src ~= 0 then
        local allowed = false
        local ok, result = pcall(function() return exports.admin_menu:hasPermission(src, 'inventory.giveitem') end)
        if ok and result then allowed = true end
        if not allowed then
            TriggerClientEvent('inv:chatNotify', src, '~r~Tu n\'as pas la permission d\'utiliser cette commande.')
            return
        end
    end

    local target   = tonumber(args[1])
    local itemName = args[2]
    local amount   = tonumber(args[3]) or 1

    if not target or not itemName or not Items[itemName] then
        if src == 0 then
            print('[INV] Usage: giveitem <playerId> <itemName> <amount>')
        else
            TriggerClientEvent('inv:chatNotify', src, '~r~Usage: /giveitem [ID] [item] [amount]')
        end
        return
    end

    EnsureInventoryLoaded(target)
    local inv = PlayerInventories[target]
    if not inv then
        if src == 0 then
            print('[INV] Joueur introuvable.')
        else
            TriggerClientEvent('inv:chatNotify', src, '~r~Joueur ID ' .. target .. ' introuvable.')
        end
        return
    end

    local remaining = AddItemToInventory(inv, itemName, amount)
    local placed    = amount - remaining

    if placed <= 0 then
        if src == 0 then
            print('[INV] Inventaire plein.')
        else
            TriggerClientEvent('inv:chatNotify', src, '~r~Inventaire du joueur plein.')
        end
        return
    end

    if remaining > 0 then
        local msg = placed .. ' items placés, ' .. remaining .. ' non placés (inventaire plein).'
        if src == 0 then print('[INV] ' .. msg)
        else TriggerClientEvent('inv:chatNotify', src, '~o~' .. msg) end
    end

    local identifier = GetIdentifier(target)
    if identifier then
        DB_SaveInventory(identifier, inv)
    end

    TriggerClientEvent('inv:receiveInventory', target,
        SerializeInventory(inv),
        GetNearGroundForPlayer(target))

    local itemLabel = Items[itemName] and Items[itemName].label or itemName
    if src == 0 then
        print('[INV] Item donné: x' .. placed .. ' ' .. itemName)
    else
        TriggerClientEvent('inv:chatNotify', src,
            '~g~Item donné: ~w~x' .. placed .. ' ' .. itemLabel .. ' ~g~→ Joueur ' .. target)
    end
end, false)

-- ─── Event pour donner des items (utilisé par charCreate) ─────────────────────
AddEventHandler('inv:giveStarterItem', function(target, itemName, amount)
    if not target or not itemName or not Items[itemName] then return end
    amount = tonumber(amount) or 1
    if amount <= 0 then return end

    local inv = PlayerInventories[target]
    if not inv then
        -- Inventaire pas encore chargé, on le crée
        PlayerInventories[target] = {}
        inv = PlayerInventories[target]
    end

    local remaining = AddItemToInventory(inv, itemName, amount)
    local placed    = amount - remaining

    if placed > 0 then
        local identifier = GetIdentifier(target)
        if identifier then
            DB_SaveInventory(identifier, inv)
        end
        TriggerClientEvent('inv:receiveInventory', target,
            SerializeInventory(inv),
            GetNearGroundForPlayer(target))
        print('[INV] Starter item: x' .. placed .. ' ' .. itemName .. ' -> joueur ' .. target)
    end
end)

-- ─── Commande /give (joueurs avec permission) ───────────────────────────────
RegisterCommand('give', function(src, args)
    if src == 0 then
        print('[INV] Utilise "giveitem <id> <item> <amount>" depuis la console.')
        return
    end

    -- Vérifier la permission via admin_menu
    local allowed = false
    local ok, result = pcall(function() return exports.admin_menu:hasPermission(src, 'inventory.give') end)
    if ok and result then allowed = true end
    if not allowed then
        TriggerClientEvent('inv:chatNotify', src, '~r~Tu n\'as pas la permission d\'utiliser cette commande.')
        return
    end

    local targetId = tonumber(args[1])
    local itemName = args[2]
    local amount   = tonumber(args[3]) or 1

    if not targetId or not itemName or amount < 1 then
        TriggerClientEvent('inv:chatNotify', src, '~r~Usage: /give [ID] [item] [amount]')
        return
    end

    if not Items[itemName] then
        local list = {}
        for k in pairs(Items) do list[#list + 1] = k end
        TriggerClientEvent('inv:chatNotify', src,
            '~r~Item inconnu. Items disponibles: ~w~' .. table.concat(list, ', '))
        return
    end

    EnsureInventoryLoaded(targetId)
    local targetInv = PlayerInventories[targetId]
    if not targetInv then
        TriggerClientEvent('inv:chatNotify', src, '~r~Joueur ID ' .. targetId .. ' introuvable.')
        return
    end

    local remaining = AddItemToInventory(targetInv, itemName, amount)
    local placed    = amount - remaining

    if placed <= 0 then
        TriggerClientEvent('inv:chatNotify', src,
            '~r~Inventaire du joueur ' .. targetId .. ' plein.')
        return
    end

    if remaining > 0 then
        TriggerClientEvent('inv:chatNotify', src,
            '~o~Seuls ~w~x' .. placed .. '~o~ items ont été placés (~w~' .. remaining .. '~o~ non placés, inventaire plein).')
    end

    local targetIdentifier = GetIdentifier(targetId)
    if targetIdentifier then
        DB_SaveInventory(targetIdentifier, targetInv)
    end

    TriggerClientEvent('inv:receiveInventory', targetId,
        SerializeInventory(targetInv),
        GetNearGroundForPlayer(targetId))

    local itemLabel = Items[itemName].label or itemName
    if targetId == src then
        TriggerClientEvent('inv:chatNotify', src,
            '~g~Tu as reçu ~w~x' .. placed .. ' ~g~' .. itemLabel)
    else
        TriggerClientEvent('inv:chatNotify', src,
            '~g~Item donné: ~w~x' .. placed .. ' ' .. itemLabel .. ' ~g~→ Joueur ' .. targetId)
        TriggerClientEvent('inv:chatNotify', targetId,
            '~b~Tu as reçu ~w~x' .. placed .. ' ~b~' .. itemLabel .. ' ~b~d\'un autre joueur.')
    end
end, false)

-- ─── Exports pour autres ressources (bank_system) ────────────────────────
exports('getPlayerInventory', function(src)
    return PlayerInventories[src]
end)

exports('countItem', function(src, itemName)
    EnsureInventoryLoaded(src)
    local inv = PlayerInventories[src]
    if not inv then return 0 end
    local total = 0
    for _, data in pairs(inv) do
        if data and data.item == itemName then
            total = total + data.amount
        end
    end
    return total
end)

exports('removeItem', function(src, itemName, amount)
    EnsureInventoryLoaded(src)
    local inv = PlayerInventories[src]
    if not inv then return false end

    -- Vérifier si assez d'items
    local total = 0
    for _, data in pairs(inv) do
        if data and data.item == itemName then
            total = total + data.amount
        end
    end
    if total < amount then return false end

    -- Retirer les items
    local toRemove = amount
    for slot, data in pairs(inv) do
        if toRemove <= 0 then break end
        if data and data.item == itemName then
            local take = math.min(data.amount, toRemove)
            data.amount = data.amount - take
            toRemove = toRemove - take
            if data.amount <= 0 then
                inv[slot] = nil
            end
        end
    end

    -- Sauvegarder et rafraîchir
    local identifier = GetIdentifier(src)
    if identifier then
        DB_SaveInventory(identifier, inv)
    end
    TriggerClientEvent('inv:receiveInventory', src,
        SerializeInventory(inv),
        GetNearGroundForPlayer(src))
    return true
end)

-- ─── Vérifie si un joueur possède un item (pour les autres resources) ────────
exports('HasItem', function(src, itemName, amount)
    EnsureInventoryLoaded(src)
    local inv = PlayerInventories[src]
    if not inv then return false end
    amount = amount or 1
    local total = 0
    for _, data in pairs(inv) do
        if data.item == itemName then
            total = total + data.amount
            if total >= amount then return true end
        end
    end
    return false
end)

-- ─── Retire un item de l'inventaire d'un joueur (pour les autres resources) ──
exports('RemoveItem', function(src, itemName, amount)
    EnsureInventoryLoaded(src)
    local inv = PlayerInventories[src]
    if not inv then return false end
    amount = amount or 1

    local total = 0
    for _, data in pairs(inv) do
        if data.item == itemName then total = total + data.amount end
    end
    if total < amount then return false end

    local remaining  = amount
    local identifier = GetIdentifier(src)

    for slot, data in pairs(inv) do
        if remaining <= 0 then break end
        if data.item == itemName then
            local toRemove = math.min(remaining, data.amount)
            data.amount = data.amount - toRemove
            remaining   = remaining - toRemove

            if data.amount <= 0 then inv[slot] = nil end
            DB_SaveSlot(identifier, slot, itemName, data.amount, data.metadata)
        end
    end

    TriggerClientEvent('inv:receiveInventory', src,
        SerializeInventory(inv), GetNearGroundForPlayer(src))
    return true
end)

-- ─── Ajouter un item avec metadata (ex: vehicle_key avec plaque) ─────────────
exports('addItemWithMetadata', function(src, itemName, amount, metadata)
    local inv = PlayerInventories[src]
    if not inv then return false end

    local itemDef = Items[itemName]
    if not itemDef then return false end

    amount = amount or 1

    for i = 1, amount do
        local emptySlot = nil
        for slot = 1, Config.MaxSlots do
            if not inv[slot] then emptySlot = slot; break end
        end
        if not emptySlot then return false end

        inv[emptySlot] = { item = itemName, amount = 1, metadata = metadata }
    end

    local identifier = GetIdentifier(src)
    if identifier then
        DB_SaveInventory(identifier, inv)
    end
    TriggerClientEvent('inv:receiveInventory', src,
        SerializeInventory(inv),
        GetNearGroundForPlayer(src))
    return true
end)

-- ─── Retirer un item par metadata (ex: retirer une cle de vehicule par plaque) ─
exports('removeItemByMetadata', function(src, itemName, metaKey, metaValue)
    local inv = PlayerInventories[src]
    if not inv then return false end

    for slot, data in pairs(inv) do
        if data and data.item == itemName and data.metadata and data.metadata[metaKey] == metaValue then
            inv[slot] = nil
            local identifier = GetIdentifier(src)
            if identifier then
                DB_SaveSlot(identifier, slot, itemName, 0)
            end
            TriggerClientEvent('inv:receiveInventory', src,
                SerializeInventory(inv),
                GetNearGroundForPlayer(src))
            return true
        end
    end
    return false
end)

-- ─── Verifier si un joueur a un item avec metadata specifique ────────────────
exports('hasItemWithMetadata', function(src, itemName, metaKey, metaValue)
    local inv = PlayerInventories[src]
    if not inv then return false end

    for _, data in pairs(inv) do
        if data and data.item == itemName and data.metadata and data.metadata[metaKey] == metaValue then
            return true
        end
    end
    return false
end)

-- ─── Recuperer toutes les metadata d'un item (ex: toutes les plaques) ────────
exports('getItemsMetadata', function(src, itemName)
    local inv = PlayerInventories[src]
    if not inv then return {} end

    local results = {}
    for _, data in pairs(inv) do
        if data and data.item == itemName and data.metadata then
            results[#results + 1] = data.metadata
        end
    end
    return results
end)

-- ─── Ajouter des items a un joueur (pour les autres resources) ──────────────
exports('addItem', function(src, itemName, amount)
    EnsureInventoryLoaded(src)
    local inv = PlayerInventories[src]
    if not inv then return false end
    amount = amount or 1

    local itemDef = Items[itemName]
    if not itemDef then return false end

    local remaining = AddItemToInventory(inv, itemName, amount)
    local placed = amount - remaining

    if placed <= 0 then return false end

    local identifier = GetIdentifier(src)
    if identifier then
        DB_SaveInventory(identifier, inv)
    end
    TriggerClientEvent('inv:receiveInventory', src,
        SerializeInventory(inv),
        GetNearGroundForPlayer(src))
    return true, placed
end)

exports('savePlayerInventory', function(src)
    local identifier = GetIdentifier(src)
    if identifier and PlayerInventories[src] then
        DB_SaveInventory(identifier, PlayerInventories[src])
        TriggerClientEvent('inv:receiveInventory', src,
            SerializeInventory(PlayerInventories[src]),
            GetNearGroundForPlayer(src))
    end
end)

-- Rafraîchir l'inventaire côté client
AddEventHandler('inv:refreshPlayer', function(src)
    if PlayerInventories[src] then
        TriggerClientEvent('inv:receiveInventory', src,
            SerializeInventory(PlayerInventories[src]),
            GetNearGroundForPlayer(src))
    end
end)
