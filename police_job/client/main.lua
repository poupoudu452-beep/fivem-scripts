-- ============================================================
--  POLICE JOB — CLIENT MAIN
-- ============================================================

PlayerPoliceData = nil -- { identifier, grade_name, grade_level, on_duty, salary, badge }
IsOnDuty = false
IsPolice = false

-- ─── Reception des donnees police ───────────────────────────
RegisterNetEvent('police:loadData')
AddEventHandler('police:loadData', function(data)
    PlayerPoliceData = data
    IsPolice = true
    IsOnDuty = data.on_duty or false
    SendNUIMessage({ action = 'setPoliceData', data = data })
end)

RegisterNetEvent('police:dutyChanged')
AddEventHandler('police:dutyChanged', function(onDuty)
    IsOnDuty = onDuty
    if PlayerPoliceData then
        PlayerPoliceData.on_duty = onDuty
    end
    SendNUIMessage({ action = 'setDuty', onDuty = onDuty })
end)

RegisterNetEvent('police:fired')
AddEventHandler('police:fired', function()
    PlayerPoliceData = nil
    IsPolice = false
    IsOnDuty = false
    SendNUIMessage({ action = 'policeFired' })
end)

-- ─── Demander les donnees au serveur ────────────────────────
CreateThread(function()
    Citizen.Wait(3000)
    TriggerServerEvent('police:requestData')
    TriggerServerEvent('police:checkJail')
end)

-- ─── Spawn PNJ au commissariat ──────────────────────────────
local stationPed = nil

CreateThread(function()
    local cfg = PoliceConfig.StationNPC
    local hash = GetHashKey(cfg.model)
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Citizen.Wait(10)
    end

    stationPed = CreatePed(4, hash, cfg.coords.x, cfg.coords.y, cfg.coords.z, cfg.coords.w, false, true)
    SetEntityInvincible(stationPed, true)
    SetBlockingOfNonTemporaryEvents(stationPed, true)
    FreezeEntityPosition(stationPed, true)
    TaskStartScenarioInPlace(stationPed, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    SetModelAsNoLongerNeeded(hash)
end)

-- ─── Blip commissariat ─────────────────────────────────────
CreateThread(function()
    local cfg = PoliceConfig.StationBlip
    local blip = AddBlipForCoord(cfg.coords.x, cfg.coords.y, cfg.coords.z)
    SetBlipSprite(blip, cfg.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, cfg.scale)
    SetBlipColour(blip, cfg.color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(cfg.label)
    EndTextCommandSetBlipName(blip)
end)

-- ─── Interaction PNJ commissariat (E) ───────────────────────
CreateThread(function()
    while true do
        Citizen.Wait(0)
        if stationPed then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local npcCoords = GetEntityCoords(stationPed)
            local dist = #(playerCoords - npcCoords)

            if dist <= 2.5 then
                -- Afficher prompt
                SetTextFont(4)
                SetTextScale(0.0, 0.35)
                SetTextColour(255, 255, 255, 240)
                SetTextDropshadow(1, 0, 0, 0, 200)
                SetTextOutline()
                SetTextCentre(true)
                SetTextEntry('STRING')

                if IsPolice then
                    AddTextComponentString('[E] Menu Police')
                else
                    AddTextComponentString('[E] Parler')
                end
                DrawText(0.5, 0.88)

                if IsControlJustReleased(0, 38) then -- E key
                    if IsPolice then
                        OpenPoliceMenu()
                    else
                        -- Joueur civil, verifier ses amendes
                        TriggerServerEvent('police:getMyFines')
                    end
                end
            else
                Citizen.Wait(500)
            end
        else
            Citizen.Wait(1000)
        end
    end
end)

-- ─── Touche F7 pour ouvrir le menu police ───────────────────
CreateThread(function()
    while true do
        Citizen.Wait(0)
        if IsPolice and IsControlJustReleased(0, 168) then -- F7
            OpenPoliceMenu()
        end
    end
end)

-- ─── Touche F6 pour toggle duty ─────────────────────────────
CreateThread(function()
    while true do
        Citizen.Wait(0)
        if IsPolice and IsControlJustReleased(0, 167) then -- F6
            TriggerServerEvent('police:toggleDuty')
        end
    end
end)

-- ─── Notifications ──────────────────────────────────────────
local policeNotif = { active = false, title = '', text = '', notifType = 'info', startTime = 0, duration = 5000 }

RegisterNetEvent('police:notify')
AddEventHandler('police:notify', function(message, notifType)
    policeNotif.active    = true
    policeNotif.title     = '[Police]'
    policeNotif.text      = message or ''
    policeNotif.notifType = notifType or 'info'
    policeNotif.startTime = GetGameTimer()

    if notifType == 'success' then
        PlaySoundFrontend(-1, 'ROBBERY_MONEY_TOTAL', 'HUD_FRONTEND_CUSTOM_SOUNDSET', false)
    elseif notifType == 'error' then
        PlaySoundFrontend(-1, 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
    else
        PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
    end
end)

CreateThread(function()
    while true do
        Citizen.Wait(0)
        if policeNotif.active then
            DrawPoliceNotification()
        else
            Citizen.Wait(500)
        end
    end
end)

function DrawPoliceNotification()
    local elapsed = GetGameTimer() - policeNotif.startTime
    if elapsed > policeNotif.duration then
        policeNotif.active = false
        return
    end

    local alpha = 255
    local offsetX = 0.0
    local fadeIn  = 400
    local fadeOut = 600

    if elapsed < fadeIn then
        local t = elapsed / fadeIn
        offsetX = -0.20 * (1.0 - t)
        alpha = math.floor(255 * t)
    elseif elapsed > (policeNotif.duration - fadeOut) then
        local t = (elapsed - (policeNotif.duration - fadeOut)) / fadeOut
        alpha = math.floor(255 * (1.0 - t))
    end

    local baseX = 0.01 + offsetX
    local baseY = 0.38
    local boxW  = 0.22
    local boxH  = 0.065

    DrawRect(baseX + boxW / 2, baseY + boxH / 2, boxW, boxH, 10, 15, 30, math.floor(alpha * 0.92))

    local barR, barG, barB = 37, 99, 235
    if policeNotif.notifType == 'success' then
        barR, barG, barB = 34, 197, 94
    elseif policeNotif.notifType == 'error' then
        barR, barG, barB = 239, 68, 68
    elseif policeNotif.notifType == 'warning' then
        barR, barG, barB = 245, 158, 11
    end
    DrawRect(baseX + 0.002, baseY + boxH / 2, 0.004, boxH, barR, barG, barB, alpha)

    SetTextFont(4)
    SetTextScale(0.0, 0.30)
    SetTextColour(barR, barG, barB, alpha)
    SetTextDropshadow(1, 0, 0, 0, math.floor(alpha * 0.5))
    SetTextEntry('STRING')
    AddTextComponentString(policeNotif.title)
    DrawText(baseX + 0.012, baseY + 0.005)

    SetTextFont(4)
    SetTextScale(0.0, 0.26)
    SetTextColour(220, 220, 220, alpha)
    SetTextDropshadow(1, 0, 0, 0, math.floor(alpha * 0.5))
    SetTextEntry('STRING')
    AddTextComponentString(policeNotif.text)
    DrawText(baseX + 0.012, baseY + 0.032)
end

-- ─── Go Fast Alert ──────────────────────────────────────────
local goFastBlip = nil

RegisterNetEvent('police:goFastAlertClient')
AddEventHandler('police:goFastAlertClient', function(vehicleNetId, coords)
    -- Alerte sonore
    PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', false)

    -- Notification
    policeNotif.active    = true
    policeNotif.title     = '[ALERTE POLICE]'
    policeNotif.text      = 'Go Fast en cours ! Vehicule suspect detecte.'
    policeNotif.notifType = 'error'
    policeNotif.startTime = GetGameTimer()
    policeNotif.duration  = 8000

    -- Blip rouge sur la carte
    if goFastBlip and DoesBlipExist(goFastBlip) then
        RemoveBlip(goFastBlip)
    end
    goFastBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(goFastBlip, 225) -- car icon
    SetBlipColour(goFastBlip, 1) -- rouge
    SetBlipScale(goFastBlip, 1.2)
    SetBlipFlashes(goFastBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Vehicule suspect - Go Fast')
    EndTextCommandSetBlipName(goFastBlip)

    -- Flash l'ecran en rouge brievement
    StartScreenEffect('RaceTurbo', 0, false)
    Citizen.SetTimeout(3000, function()
        StopScreenEffect('RaceTurbo')
    end)
end)

RegisterNetEvent('police:updateGoFastBlip')
AddEventHandler('police:updateGoFastBlip', function(coords)
    if goFastBlip and DoesBlipExist(goFastBlip) then
        SetBlipCoords(goFastBlip, coords.x, coords.y, coords.z)
    end
end)

RegisterNetEvent('police:removeGoFastBlip')
AddEventHandler('police:removeGoFastBlip', function()
    if goFastBlip and DoesBlipExist(goFastBlip) then
        RemoveBlip(goFastBlip)
        goFastBlip = nil
    end
end)

-- ─── Salaire recu ───────────────────────────────────────────
RegisterNetEvent('police:salaryReceived')
AddEventHandler('police:salaryReceived', function(amount)
    SendNUIMessage({ action = 'salaryReceived', amount = amount })
end)

-- ─── Amendes recues (joueur civil) ──────────────────────────
RegisterNetEvent('police:receiveFine')
AddEventHandler('police:receiveFine', function(fineData)
    SendNUIMessage({ action = 'receiveFine', data = fineData })
    PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', false)
end)

RegisterNetEvent('police:receiveMyFines')
AddEventHandler('police:receiveMyFines', function(fines)
    if #fines > 0 then
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'showMyFines', fines = fines })
    else
        policeNotif.active    = true
        policeNotif.title     = '[Police]'
        policeNotif.text      = 'Vous n\'avez aucune amende en cours.'
        policeNotif.notifType = 'success'
        policeNotif.startTime = GetGameTimer()
    end
end)

RegisterNetEvent('police:finePaid')
AddEventHandler('police:finePaid', function(fineId)
    SendNUIMessage({ action = 'finePaid', fineId = fineId })
end)

-- ─── Radio ──────────────────────────────────────────────────
RegisterNetEvent('police:radioReceive')
AddEventHandler('police:radioReceive', function(formattedMsg, grade, sender)
    SendNUIMessage({ action = 'radioMessage', message = formattedMsg, grade = grade, sender = sender })
    PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
end)

-- ─── Commandes chat ─────────────────────────────────────────
RegisterCommand('radio', function(source, args)
    if not IsPolice or not IsOnDuty then return end
    local msg = table.concat(args, ' ')
    if #msg > 0 then
        TriggerServerEvent('police:radioMessage', msg)
    end
end, false)

RegisterCommand('duty', function()
    if IsPolice then
        TriggerServerEvent('police:toggleDuty')
    end
end, false)

print('[PoliceJob] Client main charge.')
