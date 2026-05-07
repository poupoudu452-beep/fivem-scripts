-- ============================================================
--  VEHICLE LOCKPICK — SERVER
-- ============================================================

local unlockedVehicles = {}
local hotwiredVehicles = {}

-- ─── Verifier et consommer l'item de crochetage ─────────────────────────
RegisterNetEvent('lockpick:tryUseLockpick')
AddEventHandler('lockpick:tryUseLockpick', function()
    local src = source

    if not Config.RequireLockpickItem then
        TriggerClientEvent('lockpick:lockpickItemResult', src, true)
        return
    end

    local itemName = Config.LockpickItemName or 'lockpick'

    -- Utiliser les exports de inv_system pour verifier et consommer l'item
    local hasItem = exports['inv_system']:HasItem(src, itemName, 1)

    if not hasItem then
        TriggerClientEvent('lockpick:lockpickItemResult', src, false)
        return
    end

    local removed = exports['inv_system']:RemoveItem(src, itemName, 1)

    if removed then
        TriggerClientEvent('lockpick:lockpickItemResult', src, true)
        print('[vehicle_lockpick] Joueur ' .. src .. ' utilise ' .. itemName)
    else
        TriggerClientEvent('lockpick:lockpickItemResult', src, false)
    end
end)

RegisterNetEvent('lockpick:unlocked')
AddEventHandler('lockpick:unlocked', function(netId)
    local src = source
    unlockedVehicles[netId] = true
    TriggerClientEvent('lockpick:syncUnlock', -1, netId)
    print('[vehicle_lockpick] Joueur ' .. src .. ' a deverrouille le vehicule netId=' .. netId)
end)

RegisterNetEvent('lockpick:hotwired')
AddEventHandler('lockpick:hotwired', function(netId)
    local src = source
    hotwiredVehicles[netId] = true
    TriggerClientEvent('lockpick:syncHotwire', -1, netId)
    print('[vehicle_lockpick] Joueur ' .. src .. ' a demarre le vehicule netId=' .. netId)
end)

-- ─── Admin spawn : vehicule deja deverrouille + hotwire ─────────────────
RegisterNetEvent('lockpick:adminSpawn')
AddEventHandler('lockpick:adminSpawn', function(netId)
    local src = source
    unlockedVehicles[netId] = true
    hotwiredVehicles[netId] = true
    TriggerClientEvent('lockpick:syncAdminSpawn', -1, netId)
    print('[vehicle_lockpick] Admin ' .. src .. ' spawn vehicule netId=' .. netId .. ' (pas de crochetage)')
end)

-- Nettoyage periodique des vehicules qui n'existent plus
CreateThread(function()
    while true do
        Citizen.Wait(60000)
        for netId, _ in pairs(unlockedVehicles) do
            if not NetworkDoesNetworkIdExist(netId) then
                unlockedVehicles[netId] = nil
                hotwiredVehicles[netId] = nil
            end
        end
    end
end)
