-- server/vehicle.lua
--
-- Gestion serveur des coffres de vehicules et boites a gants.
-- Les inventaires sont caches en memoire et sauvegardes en BDD.

VehicleInventories = {}   -- { ["PLATE:trunk"] = { [slot] = {item,amount,metadata} }, ... }

-- Cle de cache
local function VehKey(plate, storageType)
    return plate .. ':' .. storageType
end

-- Nombre max de slots selon le type
local function GetMaxSlots(storageType)
    if storageType == 'glovebox' then
        return Config.GloveboxSlots or 5
    end
    return Config.TrunkSlots or 20
end

local function GetMaxWeight(storageType)
    if storageType == 'glovebox' then
        return Config.GloveboxMaxWeight or 5
    end
    return Config.TrunkMaxWeight or 50
end

-- Serialise pour NUI (cles string)
local function SerializeVehicleInv(inv)
    local out = {}
    for slot, data in pairs(inv or {}) do
        out[tostring(slot)] = data
    end
    return out
end

-- Calcul du poids actuel
local function CalcWeight(inv)
    local total = 0
    for _, data in pairs(inv or {}) do
        if data and data.item then
            local def = Items[data.item]
            if def then total = total + (def.weight or 0) * (data.amount or 1) end
        end
    end
    return total
end

-- ─── Ouverture coffre / boite a gants ──────────────────────────────────────
RegisterNetEvent('inv:openVehicleStorage', function(plate, storageType)
    local src = source
    if not plate or plate == '' then return end
    storageType = storageType or 'trunk'
    if storageType ~= 'trunk' and storageType ~= 'glovebox' then return end

    local key = VehKey(plate, storageType)

    if VehicleInventories[key] then
        local inv = VehicleInventories[key]
        TriggerClientEvent('inv:receiveVehicleStorage', src, {
            plate       = plate,
            storageType = storageType,
            inventory   = SerializeVehicleInv(inv),
            maxSlots    = GetMaxSlots(storageType),
            maxWeight   = GetMaxWeight(storageType),
        })
    else
        DB_LoadVehicleInventory(plate, storageType, function(inv)
            VehicleInventories[key] = inv or {}
            TriggerClientEvent('inv:receiveVehicleStorage', src, {
                plate       = plate,
                storageType = storageType,
                inventory   = SerializeVehicleInv(VehicleInventories[key]),
                maxSlots    = GetMaxSlots(storageType),
                maxWeight   = GetMaxWeight(storageType),
            })
        end)
    end
end)

-- ─── Deposer un item dans le coffre (inv → vehicule) ───────────────────────
RegisterNetEvent('inv:moveToVehicle', function(plate, storageType, invSlot, vehSlot, amount)
    local src = source
    if not plate or plate == '' then return end
    storageType = storageType or 'trunk'
    invSlot = tonumber(invSlot)
    vehSlot = tonumber(vehSlot)
    amount  = tonumber(amount)
    if not invSlot or not vehSlot or not amount or amount <= 0 then return end

    local inv = PlayerInventories[src]
    if not inv or not inv[invSlot] then return end

    local key    = VehKey(plate, storageType)
    local vehInv = VehicleInventories[key]
    if not vehInv then return end

    local data    = inv[invSlot]
    local itemDef = Items[data.item]
    amount = math.min(amount, data.amount)
    if amount <= 0 then return end

    local maxSlots = GetMaxSlots(storageType)
    if vehSlot < 1 or vehSlot > maxSlots then return end

    -- Verifier le poids
    local maxWeight   = GetMaxWeight(storageType)
    local itemWeight  = itemDef and itemDef.weight or 0
    local currentWeight = CalcWeight(vehInv)
    if currentWeight + (itemWeight * amount) > maxWeight then
        TriggerClientEvent('inv:chatNotify', src, '~r~Coffre trop lourd !')
        return
    end

    -- Slot cible dans le vehicule
    if vehInv[vehSlot] then
        -- Meme item → stack
        if vehInv[vehSlot].item == data.item then
            local maxStack = (itemDef and itemDef.maxStack) or 99
            local canAdd   = maxStack - vehInv[vehSlot].amount
            local toAdd    = math.min(amount, canAdd)
            if toAdd <= 0 then
                TriggerClientEvent('inv:chatNotify', src, '~r~Stack plein !')
                return
            end
            vehInv[vehSlot].amount = vehInv[vehSlot].amount + toAdd
            data.amount = data.amount - toAdd
        else
            -- Swap : item different
            if amount == data.amount then
                local tmp = vehInv[vehSlot]
                vehInv[vehSlot] = { item = data.item, amount = data.amount, metadata = data.metadata }
                inv[invSlot] = tmp
            else
                return
            end
        end
    else
        -- Slot vide
        if amount == data.amount then
            vehInv[vehSlot] = { item = data.item, amount = data.amount, metadata = data.metadata }
            data.amount = 0
        else
            vehInv[vehSlot] = { item = data.item, amount = amount, metadata = data.metadata }
            data.amount = data.amount - amount
        end
    end

    if data.amount <= 0 then inv[invSlot] = nil end

    -- Sauvegarder
    local identifier = GetIdentifier(src)
    if identifier then DB_SaveInventory(identifier, inv) end
    DB_SaveVehicleInventory(plate, storageType, vehInv)

    -- Rafraichir
    TriggerClientEvent('inv:receiveInventory', src,
        SerializeInventory(inv), GetNearGroundForPlayer(src))
    TriggerClientEvent('inv:receiveVehicleStorage', src, {
        plate       = plate,
        storageType = storageType,
        inventory   = SerializeVehicleInv(vehInv),
        maxSlots    = GetMaxSlots(storageType),
        maxWeight   = GetMaxWeight(storageType),
    })
end)

-- ─── Retirer un item du coffre (vehicule → inv) ────────────────────────────
RegisterNetEvent('inv:moveFromVehicle', function(plate, storageType, vehSlot, invSlot, amount)
    local src = source
    if not plate or plate == '' then return end
    storageType = storageType or 'trunk'
    vehSlot = tonumber(vehSlot)
    invSlot = tonumber(invSlot)
    amount  = tonumber(amount)
    if not vehSlot or not invSlot or not amount or amount <= 0 then return end

    local inv = PlayerInventories[src]
    if not inv then return end

    local key    = VehKey(plate, storageType)
    local vehInv = VehicleInventories[key]
    if not vehInv or not vehInv[vehSlot] then return end

    local vData   = vehInv[vehSlot]
    local itemDef = Items[vData.item]
    amount = math.min(amount, vData.amount)
    if amount <= 0 then return end

    if invSlot < 1 or invSlot > Config.MaxSlots then return end

    -- Verifier le poids inventaire joueur
    local playerWeight = 0
    for _, d in pairs(inv) do
        if d and d.item then
            local def = Items[d.item]
            if def then playerWeight = playerWeight + (def.weight or 0) * (d.amount or 1) end
        end
    end
    local itemWeight = itemDef and itemDef.weight or 0
    if playerWeight + (itemWeight * amount) > Config.MaxWeight then
        TriggerClientEvent('inv:chatNotify', src, '~r~Inventaire trop lourd !')
        return
    end

    -- Slot cible dans l'inventaire
    if inv[invSlot] then
        if inv[invSlot].item == vData.item then
            local maxStack = (itemDef and itemDef.maxStack) or 99
            local canAdd   = maxStack - inv[invSlot].amount
            local toAdd    = math.min(amount, canAdd)
            if toAdd <= 0 then
                TriggerClientEvent('inv:chatNotify', src, '~r~Stack plein !')
                return
            end
            inv[invSlot].amount = inv[invSlot].amount + toAdd
            vData.amount = vData.amount - toAdd
        else
            if amount == vData.amount then
                local tmp = inv[invSlot]
                inv[invSlot] = { item = vData.item, amount = vData.amount, metadata = vData.metadata }
                vehInv[vehSlot] = tmp
            else
                return
            end
        end
    else
        if amount == vData.amount then
            inv[invSlot] = { item = vData.item, amount = vData.amount, metadata = vData.metadata }
            vData.amount = 0
        else
            inv[invSlot] = { item = vData.item, amount = amount, metadata = vData.metadata }
            vData.amount = vData.amount - amount
        end
    end

    if vData.amount <= 0 then vehInv[vehSlot] = nil end

    -- Sauvegarder
    local identifier = GetIdentifier(src)
    if identifier then DB_SaveInventory(identifier, inv) end
    DB_SaveVehicleInventory(plate, storageType, vehInv)

    -- Rafraichir
    TriggerClientEvent('inv:receiveInventory', src,
        SerializeInventory(inv), GetNearGroundForPlayer(src))
    TriggerClientEvent('inv:receiveVehicleStorage', src, {
        plate       = plate,
        storageType = storageType,
        inventory   = SerializeVehicleInv(vehInv),
        maxSlots    = GetMaxSlots(storageType),
        maxWeight   = GetMaxWeight(storageType),
    })
end)

-- ─── Ajouter un item dans le coffre d'un vehicule (export serveur) ───────────
-- Utilise par go_fast pour placer la drogue dans le coffre au spawn
-- plate       : plaque du vehicule (string)
-- storageType : 'trunk' ou 'glovebox'
-- itemName    : nom de l'item (string, doit exister dans Items)
-- amount      : quantite a ajouter (number)
-- Retourne le nombre d'items qui n'ont pas pu etre places (coffre plein)
function addItemToVehicle(plate, storageType, itemName, amount)
    if not plate or plate == '' then return amount end
    storageType = storageType or 'trunk'
    if not Items[itemName] then return amount end

    local key = VehKey(plate, storageType)

    -- Charger l'inventaire vehicule s'il n'est pas en cache
    if not VehicleInventories[key] then
        VehicleInventories[key] = {}
    end

    local vehInv   = VehicleInventories[key]
    local maxSlots = GetMaxSlots(storageType)
    local maxWeight = GetMaxWeight(storageType)
    local itemDef  = Items[itemName]
    local maxStack = (itemDef and itemDef.maxStack) or 99
    local stackable = itemDef and itemDef.stackable
    local remaining = amount

    -- Stacker sur les slots existants
    if stackable then
        for slot = 1, maxSlots do
            if remaining <= 0 then break end
            local d = vehInv[slot]
            if d and d.item == itemName and d.amount < maxStack then
                local canAdd = maxStack - d.amount
                local toAdd  = math.min(remaining, canAdd)
                -- Verifier le poids
                local curWeight = CalcWeight(vehInv)
                local addWeight = (itemDef.weight or 0) * toAdd
                if curWeight + addWeight > maxWeight then
                    toAdd = math.floor((maxWeight - curWeight) / (itemDef.weight or 1))
                    if toAdd <= 0 then break end
                end
                d.amount  = d.amount + toAdd
                remaining = remaining - toAdd
            end
        end
    end

    -- Placer dans les slots vides
    while remaining > 0 do
        local emptySlot = nil
        for slot = 1, maxSlots do
            if not vehInv[slot] then emptySlot = slot; break end
        end
        if not emptySlot then break end

        local toPlace = stackable and math.min(remaining, maxStack) or 1
        -- Verifier le poids
        local curWeight = CalcWeight(vehInv)
        local addWeight = (itemDef.weight or 0) * toPlace
        if curWeight + addWeight > maxWeight then
            toPlace = math.floor((maxWeight - curWeight) / (itemDef.weight or 1))
            if toPlace <= 0 then break end
        end

        vehInv[emptySlot] = { item = itemName, amount = toPlace }
        remaining = remaining - toPlace
    end

    -- Sauvegarder en BDD
    DB_SaveVehicleInventory(plate, storageType, vehInv)

    return remaining
end

exports('addItemToVehicle', addItemToVehicle)

-- ─── Deplacer dans le coffre (vehicule → vehicule) ─────────────────────────
RegisterNetEvent('inv:moveInVehicle', function(plate, storageType, fromSlot, toSlot, amount)
    local src = source
    if not plate or plate == '' then return end
    storageType = storageType or 'trunk'
    fromSlot = tonumber(fromSlot)
    toSlot   = tonumber(toSlot)
    amount   = tonumber(amount)
    if not fromSlot or not toSlot or fromSlot == toSlot then return end

    local key    = VehKey(plate, storageType)
    local vehInv = VehicleInventories[key]
    if not vehInv or not vehInv[fromSlot] then return end

    local maxSlots = GetMaxSlots(storageType)
    if toSlot < 1 or toSlot > maxSlots then return end

    local fromData = vehInv[fromSlot]
    local toData   = vehInv[toSlot]
    amount = amount or fromData.amount
    amount = math.min(amount, fromData.amount)
    if amount <= 0 then return end

    if toData and toData.item == fromData.item then
        local itemDef  = Items[fromData.item]
        local maxStack = (itemDef and itemDef.maxStack) or 99
        local canAdd   = maxStack - toData.amount
        local toAdd    = math.min(amount, canAdd)
        if toAdd <= 0 then return end
        toData.amount   = toData.amount + toAdd
        fromData.amount = fromData.amount - toAdd
        if fromData.amount <= 0 then vehInv[fromSlot] = nil end
    elseif toData then
        if amount == fromData.amount then
            vehInv[fromSlot] = toData
            vehInv[toSlot]   = fromData
        else
            return
        end
    else
        if amount == fromData.amount then
            vehInv[toSlot]   = fromData
            vehInv[fromSlot] = nil
        else
            vehInv[toSlot]     = { item = fromData.item, amount = amount, metadata = fromData.metadata }
            fromData.amount    = fromData.amount - amount
        end
    end

    DB_SaveVehicleInventory(plate, storageType, vehInv)

    TriggerClientEvent('inv:receiveVehicleStorage', src, {
        plate       = plate,
        storageType = storageType,
        inventory   = SerializeVehicleInv(vehInv),
        maxSlots    = GetMaxSlots(storageType),
        maxWeight   = GetMaxWeight(storageType),
    })
end)
