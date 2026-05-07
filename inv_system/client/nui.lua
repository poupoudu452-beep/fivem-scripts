-- client/nui.lua

RegisterNUICallback('closeInventory', function(_, cb)
    CloseInventory()
    cb('ok')
end)

RegisterNUICallback('useItem', function(data, cb)
    local slot = tonumber(data.slot)
    if not slot then cb('ok') return end

    -- Envoyer au serveur avec le contexte de l'arme équipée
    -- Le serveur gère TOUT : détection ammo, validation arme, consommation, rechargement
    TriggerServerEvent('inv:useItem', slot, equippedWeaponName or '')
    cb('ok')
end)

RegisterNUICallback('moveItem', function(data, cb)
    TriggerServerEvent('inv:moveItem', data.fromSlot, data.toSlot, data.amount)
    cb('ok')
end)

-- Déposer au sol depuis l'inventaire
RegisterNUICallback('dropToGround', function(data, cb)
    TriggerServerEvent('inv:dropToGround', data.slot, data.amount or 1)
    cb('ok')
end)

-- Ramasser un objet au sol
RegisterNUICallback('pickupFromGround', function(data, cb)
    TriggerServerEvent('inv:pickupFromGround', data.groundId, data.toSlot)
    cb('ok')
end)

-- Donner un item à un joueur proche
RegisterNUICallback('giveToPlayer', function(data, cb)
    local slot     = tonumber(data.slot)
    local targetId = tonumber(data.targetId)
    local amount   = tonumber(data.amount)
    if not slot or not targetId or not amount then cb('ok') return end
    TriggerServerEvent('inv:giveToPlayer', slot, targetId, amount)
    cb('ok')
end)

-- ─── Vehicle storage NUI callbacks ─────────────────────────────────────────

-- Deposer dans le coffre/boite a gants (inv → vehicule)
RegisterNUICallback('moveToVehicle', function(data, cb)
    if not activeVehiclePlate or not activeStorageType then cb('ok') return end
    TriggerServerEvent('inv:moveToVehicle', activeVehiclePlate, activeStorageType,
        data.invSlot, data.vehSlot, data.amount)
    cb('ok')
end)

-- Retirer du coffre/boite a gants (vehicule → inv)
RegisterNUICallback('moveFromVehicle', function(data, cb)
    if not activeVehiclePlate or not activeStorageType then cb('ok') return end
    TriggerServerEvent('inv:moveFromVehicle', activeVehiclePlate, activeStorageType,
        data.vehSlot, data.invSlot, data.amount)
    cb('ok')
end)

-- Deplacer dans le coffre (vehicule → vehicule)
RegisterNUICallback('moveInVehicle', function(data, cb)
    if not activeVehiclePlate or not activeStorageType then cb('ok') return end
    TriggerServerEvent('inv:moveInVehicle', activeVehiclePlate, activeStorageType,
        data.fromSlot, data.toSlot, data.amount)
    cb('ok')
end)
