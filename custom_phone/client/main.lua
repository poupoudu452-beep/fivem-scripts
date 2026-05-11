-- client/main.lua - iFruit 17 Pro Max

local phoneOpen = false
local cameraActive = false
local isFrontCamera = false
local selfieCam = nil
local phoneObj = nil
local cursorVisible = false
local altPressed = false
local savedCamViewMode = nil
local escCooldown = 0
local phoneMouseDisabled = false

exports('IsPhoneOpen', function()
    return phoneOpen or cameraActive
end)

-- Commande + keybind F1
RegisterCommand('openphone', function()
    TogglePhone()
end, false)
RegisterKeyMapping('openphone', 'Ouvrir/Fermer le telephone', 'keyboard', 'F1')

function TogglePhone()
    if cameraActive then
        CloseCamera()
        return
    end
    if phoneOpen then
        ClosePhone()
    else
        OpenPhone()
    end
end

function OpenPhone()
    if phoneOpen then return end
    TriggerServerEvent('phone:checkHasPhone')
end

function ClosePhone()
    if not phoneOpen then return end
    if cameraActive then
        CloseCamera()
    end
    phoneOpen = false
    phoneMouseDisabled = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'close' })
end

-- Reponse du serveur : le joueur a un telephone
RegisterNetEvent('phone:hasPhoneResult')
AddEventHandler('phone:hasPhoneResult', function(result)
    if result then
        phoneOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'open' })
        -- Verifier si le joueur a deja configure son numero
        TriggerServerEvent('phone:checkSetup')
    else
        SetNotificationTextEntry('STRING')
        AddTextComponentString('~r~Tu n\'as pas de telephone !')
        DrawNotification(false, false)
    end
end)

-- Resultat de la verification de configuration
RegisterNetEvent('phone:setupStatus')
AddEventHandler('phone:setupStatus', function(isSetup, phoneNumber, displayName)
    SendNUIMessage({
        action = 'setupStatus',
        isSetup = isSetup,
        number = phoneNumber,
        name = displayName
    })
end)

-- NUI callback : fermer (ESC ou bouton)
RegisterNUICallback('closePhone', function(data, cb)
    ClosePhone()
    cb('ok')
end)

-- NUI callback : toggle souris (ALT)
RegisterNUICallback('togglePhoneMouse', function(data, cb)
    if not phoneOpen or cameraActive then
        cb('ok')
        return
    end
    phoneMouseDisabled = not phoneMouseDisabled
    if phoneMouseDisabled then
        SetNuiFocus(true, false)
        SetNuiFocusKeepInput(true)
    else
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
    end
    cb('ok')
end)

-- ==================== CAMERA ====================

function AttachPhoneProp()
    local ped = PlayerPedId()
    local model = GetHashKey('prop_amb_phone')
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 50 do
        Wait(10)
        timeout = timeout + 1
    end
    if HasModelLoaded(model) then
        phoneObj = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
        local boneIndex = GetPedBoneIndex(ped, 28422)
        AttachEntityToEntity(phoneObj, ped, boneIndex, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
    end
end

function RemovePhoneProp()
    if phoneObj and DoesEntityExist(phoneObj) then
        DeleteEntity(phoneObj)
        phoneObj = nil
    end
end

function PlayPhoneAnim(isSelfie)
    local ped = PlayerPedId()
    if isSelfie then
        RequestAnimDict('cellphone@self')
        local timeout = 0
        while not HasAnimDictLoaded('cellphone@self') and timeout < 50 do
            Wait(10)
            timeout = timeout + 1
        end
        TaskPlayAnim(ped, 'cellphone@self', 'cellphone_photo_idle', 8.0, -8.0, -1, 49, 0, false, false, false)
    else
        RequestAnimDict('cellphone@')
        local timeout = 0
        while not HasAnimDictLoaded('cellphone@') and timeout < 50 do
            Wait(10)
            timeout = timeout + 1
        end
        TaskPlayAnim(ped, 'cellphone@', 'cellphone_photo_idle', 8.0, -8.0, -1, 49, 0, false, false, false)
    end
end

function StopPhoneAnim()
    local ped = PlayerPedId()
    StopAnimTask(ped, 'cellphone@', 'cellphone_photo_idle', 1.0)
    StopAnimTask(ped, 'cellphone@self', 'cellphone_photo_idle', 1.0)
end

function CreateSelfieCam()
    if selfieCam then
        DestroyCam(selfieCam, false)
        selfieCam = nil
    end
    local ped = PlayerPedId()
    selfieCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local headPos = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
    local headRot = GetEntityRotation(ped, 2)
    local forwardX = -math.sin(math.rad(headRot.z)) * 0.85
    local forwardY = math.cos(math.rad(headRot.z)) * 0.85
    SetCamCoord(selfieCam, headPos.x + forwardX, headPos.y + forwardY, headPos.z + 0.05)
    PointCamAtPedBone(selfieCam, ped, 31086, 0.0, 0.0, 0.05, true)
    SetCamActive(selfieCam, true)
    RenderScriptCams(true, true, 500, true, false)
end

function DestroySelfieCam()
    if selfieCam then
        SetCamActive(selfieCam, false)
        DestroyCam(selfieCam, false)
        selfieCam = nil
        RenderScriptCams(false, true, 500, true, false)
    end
end

function OpenCamera()
    cameraActive = true
    isFrontCamera = false
    cursorVisible = false

    -- Save current view mode and switch to first person
    savedCamViewMode = GetFollowPedCamViewMode()
    SetFollowPedCamViewMode(4)

    SendNUIMessage({ action = 'openCamera', frontCamera = false })
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
end

function CloseCamera()
    cameraActive = false
    isFrontCamera = false
    cursorVisible = false

    DestroySelfieCam()
    RemovePhoneProp()
    StopPhoneAnim()

    -- Restore previous camera view mode
    if savedCamViewMode then
        SetFollowPedCamViewMode(savedCamViewMode)
        savedCamViewMode = nil
    end

    SetNuiFocusKeepInput(false)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'closeCamera' })
end

function ToggleCameraCursor()
    if not cameraActive then return end
    cursorVisible = not cursorVisible
    if cursorVisible then
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(true)
        SendNUIMessage({ action = 'showCursor' })
    else
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({ action = 'hideCursor' })
    end
end

function SwitchCamera()
    isFrontCamera = not isFrontCamera
    if isFrontCamera then
        -- Selfie mode: scripted cam facing the player
        CreateSelfieCam()
        AttachPhoneProp()
        PlayPhoneAnim(true)
    else
        -- Rear camera: first person view
        SetFollowPedCamViewMode(4)
        DestroySelfieCam()
        RemovePhoneProp()
        StopPhoneAnim()
    end
    SendNUIMessage({ action = 'switchCamera', frontCamera = isFrontCamera })
end

function TakePhoto()
    SendNUIMessage({ action = 'photoFlash' })

    local ok, _ = pcall(function()
        exports['screenshot-basic']:requestScreenshot(function(data)
        end)
    end)

    PlaySoundFrontend(-1, 'Camera_Shoot', 'Phone_SoundSet_Michael', false)
end

-- NUI callbacks camera
RegisterNUICallback('openCamera', function(data, cb)
    OpenCamera()
    cb('ok')
end)

RegisterNUICallback('closeCamera', function(data, cb)
    CloseCamera()
    cb('ok')
end)

RegisterNUICallback('switchCamera', function(data, cb)
    SwitchCamera()
    cb('ok')
end)

RegisterNUICallback('takePhoto', function(data, cb)
    TakePhoto()
    cb('ok')
end)

RegisterNUICallback('toggleCursor', function(data, cb)
    ToggleCameraCursor()
    cb('ok')
end)

-- Camera controls + ALT toggle each frame
Citizen.CreateThread(function()
    while true do
        if cameraActive then
            -- Disable ESC / pause menu FIRST
            DisableControlAction(0, 200, true)
            SetPauseMenuActive(false)

            -- Disable attack / weapon
            DisableControlAction(0, 24, true)  -- Attack
            DisableControlAction(0, 25, true)  -- Aim
            DisableControlAction(0, 47, true)  -- Weapon
            DisableControlAction(0, 58, true)  -- Weapon
            DisableControlAction(0, 140, true) -- Melee light
            DisableControlAction(0, 141, true) -- Melee heavy
            DisableControlAction(0, 142, true) -- Melee alt
            DisableControlAction(0, 143, true) -- Melee block
            DisableControlAction(0, 263, true) -- Melee
            DisableControlAction(0, 264, true) -- Melee

            -- Disable third eye (ALT / control 19) so it doesnt open
            DisableControlAction(0, 19, true)

            -- Detect ALT press (IsDisabledControlJustPressed because we disabled 19)
            if IsDisabledControlJustPressed(0, 19) then
                if not altPressed then
                    altPressed = true
                    Citizen.CreateThread(function()
                        Wait(150)
                        altPressed = false
                    end)
                    ToggleCameraCursor()
                end
            end

            -- Enter key to take photo (control 18 = Enter)
            if IsControlJustPressed(0, 18) then
                TakePhoto()
            end

            -- ESC to close phone from camera
            if IsDisabledControlJustPressed(0, 200) then
                CloseCamera()
                ClosePhone()
                escCooldown = 30
            end

            -- When cursor visible: lock head movement
            if cursorVisible then
                DisableControlAction(0, 1, true)   -- Look LR
                DisableControlAction(0, 2, true)   -- Look UD
                DisableControlAction(0, 270, true) -- Look LR (pad)
                DisableControlAction(0, 271, true) -- Look UD (pad)
            end

            -- Keep first person for rear camera (only if still active)
            if not isFrontCamera and cameraActive then
                SetFollowPedCamViewMode(4)
            end

            -- Update selfie cam
            if isFrontCamera and selfieCam then
                local ped = PlayerPedId()
                local headPos = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
                local headRot = GetEntityRotation(ped, 2)
                local forwardX = -math.sin(math.rad(headRot.z)) * 0.85
                local forwardY = math.cos(math.rad(headRot.z)) * 0.85
                SetCamCoord(selfieCam, headPos.x + forwardX, headPos.y + forwardY, headPos.z + 0.05)
                PointCamAtPedBone(selfieCam, ped, 31086, 0.0, 0.0, 0.05, true)
            end
        elseif phoneOpen then
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 19, true)  -- Third eye disabled when phone open
            DisableControlAction(0, 200, true) -- Block pause menu when phone open
            SetPauseMenuActive(false)

            if IsDisabledControlJustPressed(0, 200) then
                if inCall or callRinging then
                    -- Raccrocher l'appel pour les deux joueurs
                    if callRinging and not inCall then
                        TriggerServerEvent('phone:rejectCall')
                    else
                        TriggerServerEvent('phone:hangupCall')
                    end
                    StopRingtone()
                    EndVoiceCall()
                    inCall = false
                    callRinging = false
                    callTarget = nil
                    SendNUIMessage({ action = 'callEnded' })
                end
                ClosePhone()
                escCooldown = 30
            end
        end

        -- Cooldown: keep blocking ESC for a few frames after phone closes
        if escCooldown > 0 then
            escCooldown = escCooldown - 1
            DisableControlAction(0, 200, true)
            SetPauseMenuActive(false)
        end
        Citizen.Wait(0)
    end
end)

-- ==================== CONFIGURATION INITIALE ====================

-- Callback NUI : verifier si un numero est disponible
RegisterNUICallback('checkNumberAvailable', function(data, cb)
    if data.number then
        TriggerServerEvent('phone:checkNumberAvailable', data.number)
    end
    cb('ok')
end)

-- Callback NUI : enregistrer le numero choisi
RegisterNUICallback('registerNumber', function(data, cb)
    if data.number then
        TriggerServerEvent('phone:registerNumber', data.number)
    end
    cb('ok')
end)

-- Resultat de la verification de disponibilite
RegisterNetEvent('phone:numberAvailableResult')
AddEventHandler('phone:numberAvailableResult', function(available, errorMsg)
    SendNUIMessage({
        action = 'numberAvailableResult',
        available = available,
        error = errorMsg
    })
end)

-- Resultat de l'enregistrement du numero
RegisterNetEvent('phone:registerResult')
AddEventHandler('phone:registerResult', function(success, errorMsg)
    SendNUIMessage({
        action = 'registerResult',
        success = success,
        error = errorMsg
    })
end)

-- ==================== CONTACTS & MESSAGES ====================

-- Callback NUI : ouvrir les contacts
RegisterNUICallback('openContacts', function(data, cb)
    TriggerServerEvent('phone:getMyNumber')
    TriggerServerEvent('phone:getContacts')
    cb('ok')
end)

-- Callback NUI : ajouter un contact
RegisterNUICallback('addContact', function(data, cb)
    if data.name and data.number then
        TriggerServerEvent('phone:addContact', data.name, data.number)
    end
    cb('ok')
end)

-- Callback NUI : supprimer un contact
RegisterNUICallback('deleteContact', function(data, cb)
    if data.id then
        TriggerServerEvent('phone:deleteContact', data.id)
    end
    cb('ok')
end)

-- Callback NUI : ouvrir les messages (liste des conversations)
RegisterNUICallback('openMessages', function(data, cb)
    TriggerServerEvent('phone:getMyNumber')
    TriggerServerEvent('phone:getConversations')
    cb('ok')
end)

-- Callback NUI : ouvrir une conversation
RegisterNUICallback('openConversation', function(data, cb)
    if data.number then
        TriggerServerEvent('phone:getMessages', data.number)
    end
    cb('ok')
end)

-- Callback NUI : envoyer un message
RegisterNUICallback('sendMessage', function(data, cb)
    if data.number and data.message then
        TriggerServerEvent('phone:sendMessage', data.number, data.message)
    end
    cb('ok')
end)

-- Callback NUI : retour a l'accueil
RegisterNUICallback('goHome', function(data, cb)
    cb('ok')
end)

-- ==================== EVENTS SERVEUR -> CLIENT -> NUI ====================

RegisterNetEvent('phone:myNumberResult')
AddEventHandler('phone:myNumberResult', function(number, displayName)
    SendNUIMessage({
        action = 'setMyInfo',
        number = number,
        name = displayName
    })
end)

RegisterNetEvent('phone:contactsList')
AddEventHandler('phone:contactsList', function(contacts)
    SendNUIMessage({
        action = 'updateContacts',
        contacts = contacts
    })
end)

RegisterNetEvent('phone:contactAdded')
AddEventHandler('phone:contactAdded', function(success, errorMsg)
    SendNUIMessage({
        action = 'contactAddResult',
        success = success,
        error = errorMsg
    })
    if success then
        TriggerServerEvent('phone:getContacts')
    end
end)

RegisterNetEvent('phone:contactDeleted')
AddEventHandler('phone:contactDeleted', function(success)
    SendNUIMessage({
        action = 'contactDeleteResult',
        success = success
    })
    if success then
        TriggerServerEvent('phone:getContacts')
    end
end)

RegisterNetEvent('phone:conversationsList')
AddEventHandler('phone:conversationsList', function(conversations)
    SendNUIMessage({
        action = 'updateConversations',
        conversations = conversations
    })
end)

RegisterNetEvent('phone:messagesList')
AddEventHandler('phone:messagesList', function(messages, otherNumber)
    SendNUIMessage({
        action = 'updateMessages',
        messages = messages,
        otherNumber = otherNumber
    })
end)

RegisterNetEvent('phone:messageSent')
AddEventHandler('phone:messageSent', function(success)
    SendNUIMessage({
        action = 'messageSentResult',
        success = success
    })
    if success then
        -- Rafraichir la conversation en cours
        SendNUIMessage({ action = 'refreshCurrentConversation' })
    end
end)

RegisterNetEvent('phone:newMessageNotification')
AddEventHandler('phone:newMessageNotification', function(senderNumber, messageText, contactName, senderDisplayName)
    SendNUIMessage({
        action = 'newMessageNotification',
        senderNumber = senderNumber,
        message = messageText,
        contactName = contactName,
        senderDisplayName = senderDisplayName
    })
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', false)
end)

-- ==================== APPELS ====================

local inCall = false
local callTarget = nil
local callRinging = false
local isSpeakerOn = false
local isMuted = false
local ringtoneSoundId = nil

-- Callback NUI : initier un appel
RegisterNUICallback('initiateCall', function(data, cb)
    if data.number then
        TriggerServerEvent('phone:initiateCall', data.number)
    end
    cb('ok')
end)

-- Callback NUI : accepter un appel
RegisterNUICallback('acceptCall', function(data, cb)
    TriggerServerEvent('phone:acceptCall')
    cb('ok')
end)

-- Callback NUI : refuser un appel
RegisterNUICallback('rejectCall', function(data, cb)
    TriggerServerEvent('phone:rejectCall')
    StopRingtone()
    callRinging = false

    cb('ok')
end)

-- Callback NUI : raccrocher
RegisterNUICallback('hangupCall', function(data, cb)
    TriggerServerEvent('phone:hangupCall')
    EndVoiceCall()
    callRinging = false
    cb('ok')
end)

-- Callback NUI : toggle muet
RegisterNUICallback('toggleMute', function(data, cb)
    isMuted = data.muted or false
    if isMuted then
        MumbleSetVoiceChannel(0)
    else
        if callTarget then
            local callChannel = GetPlayerServerId(PlayerId()) * 100 + 10
            MumbleSetVoiceChannel(callChannel)
        end
    end
    cb('ok')
end)

-- Callback NUI : toggle haut-parleur
RegisterNUICallback('toggleSpeaker', function(data, cb)
    isSpeakerOn = data.speaker or false
    if isSpeakerOn then
        -- Mode haut-parleur : on entend le son autour du joueur
        NetworkSetTalkerProximity(15.0)
    else
        -- Mode prive : seul le joueur en appel entend
        NetworkSetTalkerProximity(0.0)
    end
    cb('ok')
end)

-- Appel entrant
RegisterNetEvent('phone:incomingCall')
AddEventHandler('phone:incomingCall', function(callerNumber, callerName, callerServerId)
    callTarget = callerServerId
    callRinging = true
    PlayRingtone()
    if not phoneOpen then
        phoneOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'open' })
    end
    SendNUIMessage({
        action = 'incomingCall',
        callerNumber = callerNumber,
        callerName = callerName
    })
end)

-- Sonnerie confirmee (appel sortant)
RegisterNetEvent('phone:callRinging')
AddEventHandler('phone:callRinging', function()
    callRinging = true
    PlayOutgoingRingtone()
end)

-- Appel accepte
RegisterNetEvent('phone:callAccepted')
AddEventHandler('phone:callAccepted', function(otherServerId)
    StopRingtone()
    inCall = true
    callRinging = false
    callTarget = otherServerId

    StartVoiceCall(otherServerId)
    SendNUIMessage({ action = 'callAccepted' })
end)

-- Appel refuse
RegisterNetEvent('phone:callRejected')
AddEventHandler('phone:callRejected', function()
    StopRingtone()
    EndVoiceCall()
    inCall = false
    callRinging = false
    callTarget = nil

    SendNUIMessage({ action = 'callRejected' })
end)

-- Appel termine
RegisterNetEvent('phone:callEnded')
AddEventHandler('phone:callEnded', function()
    StopRingtone()
    EndVoiceCall()
    inCall = false
    callRinging = false
    callTarget = nil

    SendNUIMessage({ action = 'callEnded' })
end)

-- Appel echoue
RegisterNetEvent('phone:callFailed')
AddEventHandler('phone:callFailed', function(reason)
    StopRingtone()
    EndVoiceCall()
    inCall = false
    callRinging = false
    callTarget = nil

    SendNUIMessage({ action = 'callFailed', reason = reason or 'Appel echoue' })
end)

-- ==================== VOIP / VOICE ====================

function StartVoiceCall(targetServerId)
    -- Utiliser un canal mumble unique pour l'appel
    local myId = GetPlayerServerId(PlayerId())
    local callChannel = math.min(myId, targetServerId) * 100 + 10
    MumbleSetVoiceChannel(callChannel)
    NetworkSetTalkerProximity(0.0) -- Par defaut : mode prive
    isSpeakerOn = false
    isMuted = false
end

function EndVoiceCall()
    MumbleSetVoiceChannel(0)
    NetworkSetTalkerProximity(5.0) -- Remettre la proximite par defaut
    isSpeakerOn = false
    isMuted = false
end

-- ==================== SONNERIES ====================

function PlayRingtone()
    StopRingtone()
    ringtoneSoundId = GetSoundId()
    PlaySoundFrontend(ringtoneSoundId, 'Remote_Ring', 'Phone_SoundSet_Michael', false)
end

function PlayOutgoingRingtone()
    StopRingtone()
    ringtoneSoundId = GetSoundId()
    PlaySoundFrontend(ringtoneSoundId, 'Dial_and_Remote_Ring', 'Phone_SoundSet_Default', false)
end

function StopRingtone()
    if ringtoneSoundId then
        StopSound(ringtoneSoundId)
        ReleaseSoundId(ringtoneSoundId)
        ringtoneSoundId = nil
    end
end

-- ==================== GPS ====================

RegisterNUICallback('sendGPS', function(data, cb)
    if data.number then
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local gpsMessage = string.format('GPS:%.2f,%.2f,%.2f', coords.x, coords.y, coords.z)
        TriggerServerEvent('phone:sendMessage', data.number, gpsMessage)
    end
    cb('ok')
end)

RegisterNUICallback('setGPSWaypoint', function(data, cb)
    if data.coords then
        local parts = {}
        for part in string.gmatch(data.coords, '([^,]+)') do
            table.insert(parts, tonumber(part))
        end
        if #parts >= 2 then
            SetNewWaypoint(parts[1], parts[2])
            SetNotificationTextEntry('STRING')
            AddTextComponentString('~g~GPS mis a jour !')
            DrawNotification(false, false)
        end
    end
    cb('ok')
end)

-- ==================== SERVICES ====================

-- Callback NUI : ouvrir les services
RegisterNUICallback('openServices', function(data, cb)
    TriggerServerEvent('phone:openServices')
    cb('ok')
end)

-- Callback NUI : appeler un service
RegisterNUICallback('callService', function(data, cb)
    if data.job then
        TriggerServerEvent('phone:callService', data.job, data.label or data.job)
    end
    cb('ok')
end)

-- Callback NUI : recuperer les messages d'un service
RegisterNUICallback('getServiceMessages', function(data, cb)
    if data.job then
        TriggerServerEvent('phone:getServiceMessages', data.job)
    end
    cb('ok')
end)

-- Callback NUI : envoyer un message a un service
RegisterNUICallback('sendServiceMessage', function(data, cb)
    if data.job and data.message then
        TriggerServerEvent('phone:sendServiceMessage', data.job, data.message)
    end
    cb('ok')
end)

-- Recevoir la liste des services
RegisterNetEvent('phone:servicesList')
AddEventHandler('phone:servicesList', function(services)
    SendNUIMessage({
        action = 'updateServices',
        services = services
    })
end)

-- Recevoir les messages d'un service
RegisterNetEvent('phone:serviceMessagesList')
AddEventHandler('phone:serviceMessagesList', function(messages)
    SendNUIMessage({
        action = 'updateServiceMessages',
        messages = messages
    })
end)

-- Message de service envoye
RegisterNetEvent('phone:serviceMessageSent')
AddEventHandler('phone:serviceMessageSent', function(success)
    SendNUIMessage({
        action = 'serviceMessageSent',
        success = success
    })
end)

-- Rafraichir le chat service
RegisterNetEvent('phone:refreshServiceChat')
AddEventHandler('phone:refreshServiceChat', function(jobName)
    SendNUIMessage({
        action = 'refreshServiceChat',
        job = jobName
    })
end)

-- Nouveau message service (notification)
RegisterNetEvent('phone:newServiceMessage')
AddEventHandler('phone:newServiceMessage', function(jobName, senderName, messageText, serviceLabel)
    SendNUIMessage({
        action = 'newServiceMessage',
        job = jobName,
        senderName = senderName,
        message = messageText,
        serviceName = serviceLabel or jobName
    })
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', false)
end)

-- Appel entrant de service
RegisterNetEvent('phone:incomingServiceCall')
AddEventHandler('phone:incomingServiceCall', function(callerNumber, callerName, serviceName, callerServerId)
    callTarget = callerServerId
    callRinging = true
    PlayRingtone()
    if not phoneOpen then
        phoneOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'open' })
    end
    SendNUIMessage({
        action = 'incomingServiceCall',
        callerNumber = callerNumber,
        callerName = callerName,
        serviceName = serviceName
    })
end)
