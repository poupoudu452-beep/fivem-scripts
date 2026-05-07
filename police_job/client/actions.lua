-- ============================================================
--  POLICE JOB — CLIENT ACTIONS (handcuff, escort, jail, impound, spikes, radar)
-- ============================================================

local isHandcuffed = false
local isEscorted   = false
local escortBy     = nil
local isJailed     = false
local jailTimeLeft = 0

-- ─── Menottage ──────────────────────────────────────────────
RegisterNetEvent('police:setHandcuffed')
AddEventHandler('police:setHandcuffed', function(cuffed)
    isHandcuffed = cuffed
    local playerPed = PlayerPedId()

    if cuffed then
        RequestAnimDict('mp_arresting')
        while not HasAnimDictLoaded('mp_arresting') do
            Citizen.Wait(10)
        end
        TaskPlayAnim(playerPed, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
        SetEnableHandcuffs(playerPed, true)
        DisablePlayerFiring(playerPed, true)
    else
        ClearPedTasks(playerPed)
        SetEnableHandcuffs(playerPed, false)
        DisablePlayerFiring(playerPed, false)
        isEscorted = false
        escortBy = nil
    end
end)

-- Thread menottage : desactiver les actions
CreateThread(function()
    while true do
        Citizen.Wait(0)
        if isHandcuffed then
            local playerPed = PlayerPedId()
            DisableControlAction(0, 24, true)  -- attack
            DisableControlAction(0, 25, true)  -- aim
            DisableControlAction(0, 47, true)  -- weapon
            DisableControlAction(0, 58, true)  -- weapon
            DisableControlAction(0, 263, true) -- melee
            DisableControlAction(0, 264, true) -- melee
            DisableControlAction(0, 257, true) -- melee
            DisableControlAction(0, 140, true) -- melee
            DisableControlAction(0, 141, true) -- melee
            DisableControlAction(0, 142, true) -- melee
            DisableControlAction(0, 143, true) -- melee
            DisableControlAction(0, 75, true)  -- exit vehicle

            if not IsEntityPlayingAnim(playerPed, 'mp_arresting', 'idle', 3) then
                TaskPlayAnim(playerPed, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
            end
        else
            Citizen.Wait(500)
        end
    end
end)

-- ─── Escorte ────────────────────────────────────────────────
RegisterNetEvent('police:startEscort')
AddEventHandler('police:startEscort', function(officerSrc)
    isEscorted = true
    escortBy = officerSrc
end)

CreateThread(function()
    while true do
        Citizen.Wait(0)
        if isEscorted and escortBy then
            local playerPed = PlayerPedId()
            local officerPed = GetPlayerPed(GetPlayerFromServerId(escortBy))
            if officerPed and DoesEntityExist(officerPed) then
                local officerCoords = GetEntityCoords(officerPed)
                local officerForward = GetEntityForwardVector(officerPed)
                local targetX = officerCoords.x - officerForward.x * 1.0
                local targetY = officerCoords.y - officerForward.y * 1.0
                local targetZ = officerCoords.z

                local myCoords = GetEntityCoords(playerPed)
                local dist = #(myCoords - vector3(targetX, targetY, targetZ))
                if dist > 1.5 then
                    TaskGoStraightToCoord(playerPed, targetX, targetY, targetZ, 1.0, -1, GetEntityHeading(officerPed), 0.5)
                end
            end

            DisableControlAction(0, 21, true)  -- sprint
            DisableControlAction(0, 24, true)  -- attack
            DisableControlAction(0, 25, true)  -- aim
        else
            Citizen.Wait(500)
        end
    end
end)

-- ─── Mettre dans un vehicule ────────────────────────────────
RegisterNetEvent('police:enterVehicle')
AddEventHandler('police:enterVehicle', function(officerSrc)
    local playerPed = PlayerPedId()
    local officerPed = GetPlayerPed(GetPlayerFromServerId(officerSrc))
    if not officerPed or not DoesEntityExist(officerPed) then return end

    local vehicle = GetVehiclePedIsIn(officerPed, false)
    if vehicle == 0 then
        -- Chercher le vehicule le plus proche de l'officier
        local officerCoords = GetEntityCoords(officerPed)
        vehicle = GetClosestVehicle(officerCoords.x, officerCoords.y, officerCoords.z, 5.0, 0, 71)
    end

    if vehicle and vehicle ~= 0 then
        if IsPedInAnyVehicle(playerPed, false) then
            TaskLeaveVehicle(playerPed, GetVehiclePedIsIn(playerPed, false), 0)
            Citizen.Wait(2000)
        end

        -- Trouver un siege libre (arriere de preference)
        local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
        local seat = nil
        for i = 1, maxSeats - 1 do
            if IsVehicleSeatFree(vehicle, i) then
                seat = i
                break
            end
        end
        if not seat and IsVehicleSeatFree(vehicle, 0) then
            seat = 0
        end

        if seat then
            TaskEnterVehicle(playerPed, vehicle, -1, seat, 1.0, 1, 0)
            isEscorted = false
            escortBy = nil
        end
    end
end)

-- ─── Prison ─────────────────────────────────────────────────
RegisterNetEvent('police:goToJail')
AddEventHandler('police:goToJail', function(minutes)
    isJailed = true
    jailTimeLeft = minutes
    local playerPed = PlayerPedId()

    -- Teleporter en prison
    SetEntityCoords(playerPed,
        PoliceConfig.JailCoords.x,
        PoliceConfig.JailCoords.y,
        PoliceConfig.JailCoords.z,
        false, false, false, true)

    -- Retirer les armes
    RemoveAllPedWeapons(playerPed, true)

    -- Demenotter
    isHandcuffed = false
    ClearPedTasks(playerPed)
    SetEnableHandcuffs(playerPed, false)

    -- Timer de prison
    Citizen.CreateThread(function()
        while isJailed and jailTimeLeft > 0 do
            Citizen.Wait(60000) -- 1 minute
            jailTimeLeft = jailTimeLeft - 1

            if jailTimeLeft <= 0 then
                isJailed = false
                TriggerEvent('police:releaseFromJail')
            end
        end
    end)
end)

-- Thread prison : maintenir le joueur dans la zone
CreateThread(function()
    while true do
        Citizen.Wait(0)
        if isJailed then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local dist = #(playerCoords - PoliceConfig.JailCoords)

            -- Afficher le temps restant
            SetTextFont(4)
            SetTextScale(0.0, 0.40)
            SetTextColour(239, 68, 68, 255)
            SetTextDropshadow(1, 0, 0, 0, 200)
            SetTextOutline()
            SetTextCentre(true)
            SetTextEntry('STRING')
            AddTextComponentString('PRISON — ' .. jailTimeLeft .. ' min restantes')
            DrawText(0.5, 0.05)

            -- Empecher de sortir de la zone
            if dist > PoliceConfig.JailRadius then
                SetEntityCoords(playerPed,
                    PoliceConfig.JailCoords.x,
                    PoliceConfig.JailCoords.y,
                    PoliceConfig.JailCoords.z,
                    false, false, false, true)
            end
        else
            Citizen.Wait(1000)
        end
    end
end)

RegisterNetEvent('police:releaseFromJail')
AddEventHandler('police:releaseFromJail', function()
    isJailed = false
    jailTimeLeft = 0
    local playerPed = PlayerPedId()
    -- Teleporter hors de la prison (devant le commissariat)
    SetEntityCoords(playerPed, 441.89, -982.06, 30.69, false, false, false, true)
end)

-- ─── Fourriere ──────────────────────────────────────────────
RegisterNetEvent('police:doImpound')
AddEventHandler('police:doImpound', function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    local vehicle = GetClosestVehicle(playerCoords.x, playerCoords.y, playerCoords.z, PoliceConfig.ImpoundDistance, 0, 71)
    if vehicle and vehicle ~= 0 then
        -- Animation
        RequestAnimDict('mini@repair')
        while not HasAnimDictLoaded('mini@repair') do
            Citizen.Wait(10)
        end
        TaskPlayAnim(playerPed, 'mini@repair', 'fixing_a_player', 8.0, -8.0, 5000, 0, 0, false, false, false)
        Citizen.Wait(5000)

        -- Supprimer le vehicule
        SetEntityAsMissionEntity(vehicle, true, true)
        DeleteVehicle(vehicle)

        TriggerEvent('police:notify', 'Vehicule mis en fourriere.', 'success')
    else
        TriggerEvent('police:notify', 'Aucun vehicule a proximite.', 'error')
    end
end)

-- ─── Herses (spike strips) ──────────────────────────────────
local spikeStrips = {}

RegisterNetEvent('police:spawnSpikeStrip')
AddEventHandler('police:spawnSpikeStrip', function(coords, heading, officerSrc)
    local model = GetHashKey(PoliceConfig.SpikeModel)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Citizen.Wait(10)
    end

    local spike = CreateObject(model, coords.x, coords.y, coords.z - 1.0, true, true, false)
    SetEntityHeading(spike, heading)
    PlaceObjectOnGroundProperly(spike)
    FreezeEntityPosition(spike, true)
    SetModelAsNoLongerNeeded(model)

    spikeStrips[#spikeStrips + 1] = spike
end)

RegisterNetEvent('police:deleteSpikeStrip')
AddEventHandler('police:deleteSpikeStrip', function(netId)
    -- Supprimer les herses proches du joueur
    local playerCoords = GetEntityCoords(PlayerPedId())
    for i = #spikeStrips, 1, -1 do
        local spike = spikeStrips[i]
        if DoesEntityExist(spike) then
            local spikeCoords = GetEntityCoords(spike)
            if #(playerCoords - spikeCoords) < 5.0 then
                DeleteObject(spike)
                table.remove(spikeStrips, i)
            end
        else
            table.remove(spikeStrips, i)
        end
    end
end)

-- Thread herses : crever les pneus des vehicules qui passent dessus
CreateThread(function()
    while true do
        Citizen.Wait(500)
        for _, spike in ipairs(spikeStrips) do
            if DoesEntityExist(spike) then
                local spikeCoords = GetEntityCoords(spike)
                local vehicle = GetClosestVehicle(spikeCoords.x, spikeCoords.y, spikeCoords.z, 3.0, 0, 71)
                if vehicle and vehicle ~= 0 and IsVehicleOnAllWheels(vehicle) then
                    local vehCoords = GetEntityCoords(vehicle)
                    local dist = #(spikeCoords - vehCoords)
                    if dist < 2.5 then
                        for wheel = 0, 7 do
                            if not IsVehicleTyreBurst(vehicle, wheel, true) then
                                SetVehicleTyreBurst(vehicle, wheel, true, 1000.0)
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ─── Radar de vitesse ───────────────────────────────────────
local radarActive = false

RegisterCommand('radar', function()
    if not IsPolice or not IsOnDuty then return end
    radarActive = not radarActive
    if radarActive then
        TriggerEvent('police:notify', 'Radar de vitesse active.', 'success')
    else
        TriggerEvent('police:notify', 'Radar de vitesse desactive.', 'warning')
    end
end, false)

CreateThread(function()
    while true do
        Citizen.Wait(0)
        if radarActive and IsPolice and IsOnDuty then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)

            -- Detecter les vehicules proches
            local vehicle = GetClosestVehicle(playerCoords.x, playerCoords.y, playerCoords.z,
                PoliceConfig.SpeedRadarDistance, 0, 71)

            if vehicle and vehicle ~= 0 then
                local speed = GetEntitySpeed(vehicle) * 3.6 -- m/s -> km/h
                if speed > 5.0 then
                    local vehCoords = GetEntityCoords(vehicle)

                    -- Afficher la vitesse
                    SetTextFont(4)
                    SetTextScale(0.0, 0.45)
                    if speed > PoliceConfig.SpeedLimit then
                        SetTextColour(239, 68, 68, 255)
                    else
                        SetTextColour(34, 197, 94, 255)
                    end
                    SetTextDropshadow(1, 0, 0, 0, 200)
                    SetTextOutline()
                    SetTextCentre(true)
                    SetTextEntry('STRING')
                    AddTextComponentString('RADAR: ' .. math.floor(speed) .. ' km/h')
                    DrawText(0.5, 0.10)
                end
            end
        else
            Citizen.Wait(500)
        end
    end
end)

print('[PoliceJob] Client actions charge.')
