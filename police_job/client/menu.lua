-- ============================================================
--  POLICE JOB — CLIENT MENU (NUI interactions)
-- ============================================================

local isMenuOpen = false

function OpenPoliceMenu()
    if not IsPolice then return end
    isMenuOpen = true
    SetNuiFocus(true, true)
    TriggerServerEvent('police:getOnlineOfficers')
    TriggerServerEvent('police:requestGrades')
    SendNUIMessage({
        action = 'openMenu',
        data   = PlayerPoliceData,
    })
end

function ClosePoliceMenu()
    isMenuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeMenu' })
end

-- ─── NUI Callbacks ──────────────────────────────────────────

RegisterNUICallback('closeMenu', function(data, cb)
    ClosePoliceMenu()
    cb('ok')
end)

RegisterNUICallback('toggleDuty', function(data, cb)
    TriggerServerEvent('police:toggleDuty')
    cb('ok')
end)

RegisterNUICallback('recruit', function(data, cb)
    TriggerServerEvent('police:recruit', data.targetId)
    cb('ok')
end)

RegisterNUICallback('fireOfficer', function(data, cb)
    TriggerServerEvent('police:fire', data.targetId)
    cb('ok')
end)

RegisterNUICallback('setGrade', function(data, cb)
    TriggerServerEvent('police:setGrade', data.targetId, data.gradeName)
    cb('ok')
end)

RegisterNUICallback('addGrade', function(data, cb)
    TriggerServerEvent('police:addGrade', data.name, data.level, data.salary)
    cb('ok')
end)

RegisterNUICallback('removeGrade', function(data, cb)
    TriggerServerEvent('police:removeGrade', data.name)
    cb('ok')
end)

RegisterNUICallback('setSalary', function(data, cb)
    TriggerServerEvent('police:setSalary', data.gradeName, data.salary)
    cb('ok')
end)

RegisterNUICallback('getNearbyPlayers', function(data, cb)
    TriggerServerEvent('police:getNearbyPlayers')
    cb('ok')
end)

RegisterNUICallback('friskPlayer', function(data, cb)
    TriggerServerEvent('police:friskPlayer', data.targetId)
    ClosePoliceMenu()
    cb('ok')
end)

RegisterNUICallback('confiscateItem', function(data, cb)
    TriggerServerEvent('police:confiscateItem', data.targetId, data.slot, data.amount)
    cb('ok')
end)

RegisterNUICallback('endFrisk', function(data, cb)
    TriggerServerEvent('police:endFrisk', data.targetId)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeFrisk' })
    cb('ok')
end)

RegisterNUICallback('handcuffPlayer', function(data, cb)
    TriggerServerEvent('police:handcuff', data.targetId)
    cb('ok')
end)

RegisterNUICallback('escortPlayer', function(data, cb)
    TriggerServerEvent('police:escort', data.targetId)
    cb('ok')
end)

RegisterNUICallback('putInVehicle', function(data, cb)
    TriggerServerEvent('police:putInVehicle', data.targetId)
    cb('ok')
end)

RegisterNUICallback('jailPlayer', function(data, cb)
    TriggerServerEvent('police:jailPlayer', data.targetId, data.minutes)
    cb('ok')
end)

RegisterNUICallback('unjailPlayer', function(data, cb)
    TriggerServerEvent('police:unjailPlayer', data.targetId)
    cb('ok')
end)

RegisterNUICallback('createFine', function(data, cb)
    TriggerServerEvent('police:createFine', data.targetId, data.amount, data.reason)
    cb('ok')
end)

RegisterNUICallback('payFine', function(data, cb)
    TriggerServerEvent('police:payFine', data.fineId)
    cb('ok')
end)

RegisterNUICallback('closeFines', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeFines' })
    cb('ok')
end)

RegisterNUICallback('openCompanyBank', function(data, cb)
    TriggerServerEvent('police:requestCompanyBank')
    cb('ok')
end)

RegisterNUICallback('companyDeposit', function(data, cb)
    TriggerServerEvent('police:companyDeposit', data.amount)
    cb('ok')
end)

RegisterNUICallback('companyWithdraw', function(data, cb)
    TriggerServerEvent('police:companyWithdraw', data.amount)
    cb('ok')
end)

RegisterNUICallback('impoundVehicle', function(data, cb)
    TriggerServerEvent('police:impoundVehicle')
    ClosePoliceMenu()
    cb('ok')
end)

RegisterNUICallback('deploySpikeStrip', function(data, cb)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    TriggerServerEvent('police:deploySpikeStrip', coords, heading)
    ClosePoliceMenu()
    cb('ok')
end)

RegisterNUICallback('sendRadio', function(data, cb)
    if data.message and #data.message > 0 then
        TriggerServerEvent('police:radioMessage', data.message)
    end
    cb('ok')
end)

-- ─── Recevoir les donnees ───────────────────────────────────
RegisterNetEvent('police:updateOfficers')
AddEventHandler('police:updateOfficers', function(officers)
    SendNUIMessage({ action = 'updateOfficers', officers = officers })
end)

RegisterNetEvent('police:receiveGrades')
AddEventHandler('police:receiveGrades', function(grades)
    SendNUIMessage({ action = 'updateGrades', grades = grades })
end)

RegisterNetEvent('police:receiveNearbyPlayers')
AddEventHandler('police:receiveNearbyPlayers', function(players)
    SendNUIMessage({ action = 'updateNearbyPlayers', players = players })
end)

RegisterNetEvent('police:openFrisk')
AddEventHandler('police:openFrisk', function(targetId, inventory)
    SetNuiFocus(true, true)
    local targetName = GetPlayerName(targetId) or ('Joueur ' .. targetId)
    SendNUIMessage({
        action    = 'openFrisk',
        targetId  = targetId,
        targetName = targetName,
        inventory = inventory,
    })
end)

RegisterNetEvent('police:updateFriskInventory')
AddEventHandler('police:updateFriskInventory', function(inventory)
    SendNUIMessage({ action = 'updateFriskInventory', inventory = inventory })
end)

RegisterNetEvent('police:receiveCompanyBank')
AddEventHandler('police:receiveCompanyBank', function(data)
    SendNUIMessage({ action = 'openCompanyBank', data = data })
end)

RegisterNetEvent('police:companyBankUpdated')
AddEventHandler('police:companyBankUpdated', function(balance)
    TriggerServerEvent('police:requestCompanyBank')
end)

print('[PoliceJob] Client menu charge.')
