-- ============================================================
--  VEHICLE LOCKPICK — CLIENT
-- ============================================================

local isLockpicking    = false
local isHotwiring      = false
local lockpickTarget   = nil
local hotwireTarget    = nil
local unlockedVehicles = {}    -- netId -> true
local hotwiredVehicles = {}    -- netId -> true
local cooldownVehicles = {}    -- netId -> GetGameTimer()
local nearestVehicle   = nil
local nearestDist      = 999.0

-- ─── Obtenir le netId en toute securite ─────────────────────────────────
local function SafeGetNetId(entity)
    if not entity or not DoesEntityExist(entity) then return nil end
    if not NetworkGetEntityIsNetworked(entity) then return nil end
    return NetworkGetNetworkIdFromEntity(entity)
end

-- ─── Table des classes ignorees ─────────────────────────────────────────
local ignoredClasses = {}
for _, cls in ipairs(Config.IgnoredVehicleClasses) do
    ignoredClasses[cls] = true
end

-- ─── Verifier si un vehicule est un PNJ ─────────────────────────────────
local function IsNPCVehicle(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    local driver = GetPedInVehicleSeat(vehicle, -1)
    if driver ~= 0 and IsPedAPlayer(driver) then return false end
    local netId = SafeGetNetId(vehicle)
    if not netId then return true end
    if unlockedVehicles[netId] then return false end
    return true
end

-- ─── Verifier si un PNJ occupe un siege du vehicule ────────────────────
local function HasNPCOccupant(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
    for seat = -1, maxSeats - 1 do
        local ped = GetPedInVehicleSeat(vehicle, seat)
        if ped ~= 0 and DoesEntityExist(ped) and not IsPedAPlayer(ped) then
            return true
        end
    end
    return false
end

-- ─── Verifier si le joueur a la cle d'un vehicule ─────────────────────────
local function PlayerHasKeyForVehicle(vehicle)
    local ok, hasKey = pcall(function()
        return exports['vehicle_keys']:hasKeyForVehicle(vehicle)
    end)
    if ok and hasKey then return true end
    return false
end

-- ─── Verifier si un vehicule doit etre verrouille ───────────────────────
local function ShouldLockVehicle(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    local vehClass = GetVehicleClass(vehicle)
    if ignoredClasses[vehClass] then return false end
    if not Config.LockPlayerVehicles and not IsNPCVehicle(vehicle) then return false end
    local netId = SafeGetNetId(vehicle)
    if netId and unlockedVehicles[netId] then return false end
    -- Si le joueur a la cle, ne pas verrouiller pour lui
    if PlayerHasKeyForVehicle(vehicle) then return false end
    return true
end

-- ─── Boucle de verrouillage des vehicules proches ───────────────────────
CreateThread(function()
    while true do
        Citizen.Wait(2000)
        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local pool   = GetGamePool('CVehicle')

        for i = 1, #pool do
            local veh = pool[i]
            if DoesEntityExist(veh) then
                local dist = #(coords - GetEntityCoords(veh))
                if dist < Config.LockRadius and ShouldLockVehicle(veh) then
                    SetVehicleDoorsLocked(veh, 2)
                end
            end
            if i % 10 == 0 then
                Citizen.Wait(0)
            end
        end
    end
end)

-- ─── Bloquer F + empecher moteur + prompt hotwire (un seul thread) ──────
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local inVehicle = IsPedInAnyVehicle(ped, false)

        if inVehicle then
            -- Dans un vehicule : gerer moteur + hotwire prompt
            Citizen.Wait(0)
            local vehicle = GetVehiclePedIsIn(ped, false)
            if vehicle and DoesEntityExist(vehicle) and not PlayerHasKeyForVehicle(vehicle) then
                local netId = SafeGetNetId(vehicle)
                if netId and unlockedVehicles[netId] and not hotwiredVehicles[netId] then
                    SetVehicleEngineOn(vehicle, false, true, true)
                    SetVehicleUndriveable(vehicle, true)
                    if GetPedInVehicleSeat(vehicle, -1) == ped and not isHotwiring then
                        DrawPromptText('[~g~E~w~] Faire les fils')
                        if IsControlJustReleased(0, 38) then
                            StartHotwire(vehicle)
                        end
                    end
                end
            end
        else
            -- A pied : bloquer F si vehicule verrouille
            local vehicle = GetVehiclePedIsTryingToEnter(ped)
            if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
                Citizen.Wait(0)
                if ShouldLockVehicle(vehicle) then
                    SetVehicleDoorsLocked(vehicle, 2)
                    ClearPedTasks(ped)
                    if Config.ShowLockedNotif then
                        ShowLockedNotification()
                    end
                end
            else
                Citizen.Wait(200)
            end
        end
    end
end)

-- ─── Notification vehicule verrouille ───────────────────────────────────
local lastNotifTime = 0
function ShowLockedNotification()
    local now = GetGameTimer()
    if now - lastNotifTime < 3000 then return end
    lastNotifTime = now
    ShowStyledNotif('!', 'Vehicule', 'Ce vehicule est verrouille', 200, 50, 50, 3000)
end

-- ─── Scan du vehicule le plus proche (GetClosestVehicle = 0 iteration) ──
CreateThread(function()
    while true do
        local ped = PlayerPedId()

        if IsPedInAnyVehicle(ped, false) or isLockpicking then
            nearestVehicle = nil
            nearestDist    = 999.0
            Citizen.Wait(500)
        else
            local coords = GetEntityCoords(ped)
            local veh = GetClosestVehicle(coords.x, coords.y, coords.z, Config.InteractDist, 0, 70)

            if veh and veh ~= 0 and DoesEntityExist(veh) and ShouldLockVehicle(veh) then
                nearestVehicle = veh
                nearestDist    = #(coords - GetEntityCoords(veh))
            else
                nearestVehicle = nil
                nearestDist    = 999.0
            end
            Citizen.Wait(250)
        end
    end
end)

-- ─── Prompt + input E pour crocheter (thread rapide, seulement si proche) ─
CreateThread(function()
    while true do
        if nearestVehicle and nearestDist <= Config.InteractDist and not isLockpicking then
            Citizen.Wait(0)
            if nearestVehicle and DoesEntityExist(nearestVehicle) then
                local netId = SafeGetNetId(nearestVehicle)
                local cooldown = netId and cooldownVehicles[netId]
                local now = GetGameTimer()

                if HasNPCOccupant(nearestVehicle) then
                    -- PNJ dans le vehicule, pas de crochetage
                elseif cooldown and (now - cooldown) < Config.RetryCooldown then
                    -- Cooldown affiche via le texte 3D
                else
                    if IsControlJustReleased(0, 38) and not isLockpicking then
                        StartLockpicking(nearestVehicle)
                    end
                end
            end
        else
            Citizen.Wait(500)
        end
    end
end)

-- ─── Dessiner le texte prompt avec encadrement ──────────────────────────
function DrawPromptText(text)
    local boxX = 0.5
    local boxY = 0.885
    local boxW = 0.16
    local boxH = 0.038

    -- Fond sombre
    DrawRect(boxX, boxY, boxW, boxH, 10, 10, 15, 200)

    -- Bordure fine doree (haut)
    DrawRect(boxX, boxY - boxH / 2, boxW, 0.002, 200, 170, 100, 180)
    -- Bordure fine doree (bas)
    DrawRect(boxX, boxY + boxH / 2, boxW, 0.002, 200, 170, 100, 180)
    -- Bordure gauche
    DrawRect(boxX - boxW / 2, boxY, 0.002, boxH, 200, 170, 100, 180)
    -- Bordure droite
    DrawRect(boxX + boxW / 2, boxY, 0.002, boxH, 200, 170, 100, 180)

    -- Texte centre
    SetTextFont(4)
    SetTextScale(0.0, 0.33)
    SetTextColour(230, 220, 200, 240)
    SetTextDropshadow(1, 0, 0, 0, 200)
    SetTextCentre(true)
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(boxX, boxY - 0.013)
end

-- ─── Texte 3D au-dessus du vehicule avec encadrement ─────────────────────
CreateThread(function()
    while true do
        if nearestVehicle and nearestDist <= Config.InteractDist and not isLockpicking then
            Citizen.Wait(0)
            if nearestVehicle and DoesEntityExist(nearestVehicle) then
                local vehCoords = GetEntityCoords(nearestVehicle)
                local netId = SafeGetNetId(nearestVehicle)
                local cooldown = netId and cooldownVehicles[netId]
                local now = GetGameTimer()

                if HasNPCOccupant(nearestVehicle) then
                    -- PNJ dans le vehicule, on n'affiche rien
                elseif cooldown and (now - cooldown) < Config.RetryCooldown then
                    local remaining = math.ceil((Config.RetryCooldown - (now - cooldown)) / 1000)
                    DrawText3D(vehCoords.x, vehCoords.y, vehCoords.z + 1.2, 'Patientez ' .. remaining .. 's...', true)
                else
                    DrawText3D(vehCoords.x, vehCoords.y, vehCoords.z + 1.2, 'E  Crocheter', false)
                end
            end
        else
            Citizen.Wait(500)
        end
    end
end)

function DrawText3D(x, y, z, text, isWarning)
    local onScreen, screenX, screenY = World3dToScreen2d(x, y, z)
    if onScreen then
        local boxW = 0.08
        local boxH = 0.028

        local br, bg, bb = 200, 170, 100
        local tr, tg, tb = 230, 220, 200
        if isWarning then
            br, bg, bb = 200, 50, 50
            tr, tg, tb = 255, 80, 80
        end

        -- Fond
        DrawRect(screenX, screenY + boxH / 2, boxW, boxH, 10, 10, 15, 190)

        -- Bordures fines
        DrawRect(screenX, screenY, boxW, 0.002, br, bg, bb, 160)
        DrawRect(screenX, screenY + boxH, boxW, 0.002, br, bg, bb, 160)
        DrawRect(screenX - boxW / 2, screenY + boxH / 2, 0.002, boxH, br, bg, bb, 160)
        DrawRect(screenX + boxW / 2, screenY + boxH / 2, 0.002, boxH, br, bg, bb, 160)

        -- Texte
        SetTextFont(4)
        SetTextScale(0.0, 0.26)
        SetTextColour(tr, tg, tb, 220)
        SetTextDropshadow(1, 0, 0, 0, 180)
        SetTextCentre(true)
        SetTextEntry('STRING')
        AddTextComponentString(text)
        DrawText(screenX, screenY + 0.003)
    end
end

-- =====================================================================
--  CROCHETAGE (LOCKPICK)
-- =====================================================================

local waitingForItem = false

function StartLockpicking(vehicle)
    if isLockpicking or waitingForItem then return end
    if not DoesEntityExist(vehicle) then return end
    if HasNPCOccupant(vehicle) then
        ShowStyledNotif('!', 'Crochetage', 'Impossible : un PNJ est dans le vehicule', 200, 50, 50, 3000)
        return
    end

    if Config.RequireLockpickItem then
        -- Demander au serveur de verifier et consommer l'item
        waitingForItem = true
        lockpickTarget = vehicle
        TriggerServerEvent('lockpick:tryUseLockpick')
    else
        DoStartLockpicking(vehicle)
    end
end

-- Reponse du serveur : l'item a ete verifie
RegisterNetEvent('lockpick:lockpickItemResult')
AddEventHandler('lockpick:lockpickItemResult', function(hasItem)
    waitingForItem = false

    if hasItem then
        local vehicle = lockpickTarget
        if vehicle and DoesEntityExist(vehicle) then
            DoStartLockpicking(vehicle)
        else
            lockpickTarget = nil
        end
    else
        lockpickTarget = nil
        ShowLeftAlert('~r~Crochetage impossible : pas de kit de crochetage', 4000)
    end
end)

function DoStartLockpicking(vehicle)
    isLockpicking  = true
    lockpickTarget = vehicle
    local ped = PlayerPedId()

    RequestAnimDict('anim@amb@clubhouse@tutorial@bkr_tut_ig3@')
    while not HasAnimDictLoaded('anim@amb@clubhouse@tutorial@bkr_tut_ig3@') do
        Citizen.Wait(10)
    end
    TaskPlayAnim(ped, 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandler', 2.0, 2.0, -1, 49, 0, false, false, false)

    SetNuiFocus(true, true)
    SendNUIMessage({
        action   = 'open',
        pinCount = Config.PinCount,
    })
end

RegisterNUICallback('lockpick_success', function(data, cb)
    cb('ok')
    local vehicle  = lockpickTarget
    isLockpicking  = false
    lockpickTarget = nil
    SetNuiFocus(false, false)

    local ped = PlayerPedId()
    ClearPedTasks(ped)

    if vehicle and DoesEntityExist(vehicle) then
        local netId = SafeGetNetId(vehicle)
        if netId then
            unlockedVehicles[netId] = true
            TriggerServerEvent('lockpick:unlocked', netId)
        end
        SetVehicleDoorsLocked(vehicle, 1)
        SetVehicleEngineOn(vehicle, false, true, true)

        ShowStyledNotif('~', 'Crochetage', 'Vehicule deverrouille !', 50, 180, 80, 4000)

        CreateThread(function()
            Citizen.Wait(600)
            local p = PlayerPedId()
            if DoesEntityExist(vehicle) then
                TaskEnterVehicle(p, vehicle, 5000, -1, 2.0, 1, 0)
            end
        end)
    end
end)

RegisterNUICallback('lockpick_fail', function(data, cb)
    cb('ok')
    local vehicle  = lockpickTarget
    isLockpicking  = false
    lockpickTarget = nil
    SetNuiFocus(false, false)

    local ped = PlayerPedId()
    ClearPedTasks(ped)

    if vehicle and DoesEntityExist(vehicle) then
        local netId = SafeGetNetId(vehicle)
        if netId then cooldownVehicles[netId] = GetGameTimer() end

        StartVehicleAlarm(vehicle)
        SetVehicleAlarm(vehicle, true)
        ShowStyledNotif('!', 'Crochetage', 'Echec ! Alarme declenchee.', 200, 50, 50, 5000)

        CreateThread(function()
            Citizen.Wait(Config.AlarmDuration)
            if DoesEntityExist(vehicle) then
                SetVehicleAlarm(vehicle, false)
            end
        end)
    end
end)

RegisterNUICallback('lockpick_close', function(data, cb)
    cb('ok')
    isLockpicking  = false
    lockpickTarget = nil
    SetNuiFocus(false, false)

    local ped = PlayerPedId()
    ClearPedTasks(ped)
end)

-- =====================================================================
--  HOTWIRE (CABLAGE)
-- =====================================================================

function StartHotwire(vehicle)
    if isHotwiring then return end
    if not DoesEntityExist(vehicle) then return end

    isHotwiring   = true
    hotwireTarget = vehicle

    SetNuiFocus(true, true)
    SendNUIMessage({
        action    = 'open_hotwire',
        wireCount = Config.HotwireWireCount or 4,
    })
end

RegisterNUICallback('hotwire_success', function(data, cb)
    cb('ok')
    local vehicle = hotwireTarget
    isHotwiring   = false
    hotwireTarget = nil
    SetNuiFocus(false, false)

    if vehicle and DoesEntityExist(vehicle) then
        local ped = PlayerPedId()

        -- Animation de branchement des fils (5 secondes)
        RequestAnimDict('anim@amb@clubhouse@tutorial@bkr_tut_ig3@')
        while not HasAnimDictLoaded('anim@amb@clubhouse@tutorial@bkr_tut_ig3@') do
            Citizen.Wait(10)
        end
        TaskPlayAnim(ped, 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandler', 2.0, 2.0, -1, 49, 0, false, false, false)

        -- Ouvrir la barre de chargement NUI
        SetNuiFocus(true, false)
        SendNUIMessage({
            action   = 'open_loading',
            duration = Config.HotwireDuration or 5000,
            text     = 'Branchement des fils...',
        })
    end
end)

RegisterNUICallback('loading_complete', function(data, cb)
    cb('ok')
    local vehicle = hotwireTarget
    if not vehicle then
        -- Recuperer le vehicule actuel
        local ped = PlayerPedId()
        vehicle = GetVehiclePedIsIn(ped, false)
    end
    SetNuiFocus(false, false)

    local ped = PlayerPedId()
    ClearPedTasks(ped)

    if vehicle and DoesEntityExist(vehicle) then
        local netId = SafeGetNetId(vehicle)
        if netId then
            hotwiredVehicles[netId] = true
            TriggerServerEvent('lockpick:hotwired', netId)
        end
        SetVehicleUndriveable(vehicle, false)
        SetVehicleEngineOn(vehicle, true, false, true)
        SetVehicleEngineHealth(vehicle, 1000.0)

        ShowStyledNotif('~', 'Cablage', 'Vehicule demarre !', 50, 180, 80, 4000)
    end
end)

RegisterNUICallback('hotwire_fail', function(data, cb)
    cb('ok')
    isHotwiring   = false
    hotwireTarget = nil
    SetNuiFocus(false, false)

    ShowStyledNotif('!', 'Cablage', 'Cablage echoue !', 200, 50, 50, 4000)
end)

RegisterNUICallback('hotwire_close', function(data, cb)
    cb('ok')
    isHotwiring   = false
    hotwireTarget = nil
    SetNuiFocus(false, false)
end)

-- =====================================================================
--  UTILITAIRES
-- =====================================================================

-- ─── Notification stylisee (meme theme que la notif salaire) ────────────
local lockNotif = { active = false, icon = '', title = '', text = '', startTime = 0, duration = 5000, r = 200, g = 50, b = 50 }

function ShowNotification(text)
    ShowStyledNotif('~', 'Vehicule', text, 200, 50, 50, 4000)
end

function ShowLeftAlert(text, durationMs)
    ShowStyledNotif('!', 'Crochetage', text, 200, 50, 50, durationMs or 4000)
end

function ShowStyledNotif(icon, title, text, r, g, b, duration)
    lockNotif.active    = true
    lockNotif.icon      = icon
    lockNotif.title     = title
    lockNotif.text      = text
    lockNotif.r         = r or 200
    lockNotif.g         = g or 50
    lockNotif.b         = b or 50
    lockNotif.startTime = GetGameTimer()
    lockNotif.duration  = duration or 5000
    PlaySoundFrontend(-1, 'ROBBERY_MONEY_TOTAL', 'HUD_FRONTEND_CUSTOM_SOUNDSET', false)
end

local function drawStyledNotification()
    local elapsed = GetGameTimer() - lockNotif.startTime
    if elapsed > lockNotif.duration then
        lockNotif.active = false
        return
    end

    local alpha   = 255
    local offsetX = 0.0
    local fadeIn  = 400
    local fadeOut = 600

    if elapsed < fadeIn then
        local t = elapsed / fadeIn
        offsetX = -0.20 * (1.0 - t)
        alpha = math.floor(255 * t)
    elseif elapsed > (lockNotif.duration - fadeOut) then
        local t = (elapsed - (lockNotif.duration - fadeOut)) / fadeOut
        alpha = math.floor(255 * (1.0 - t))
    end

    local baseX = 0.01 + offsetX
    local baseY = 0.46
    local boxW  = 0.20
    local boxH  = 0.065

    -- Fond sombre
    DrawRect(baseX + boxW / 2, baseY + boxH / 2, boxW, boxH, 10, 10, 15, math.floor(alpha * 0.85))

    -- Barre coloree a gauche
    DrawRect(baseX + 0.002, baseY + boxH / 2, 0.004, boxH, lockNotif.r, lockNotif.g, lockNotif.b, alpha)

    -- Icone
    SetTextFont(7)
    SetTextScale(0.0, 0.40)
    SetTextColour(lockNotif.r, lockNotif.g, lockNotif.b, alpha)
    SetTextDropshadow(0, 0, 0, 0, 0)
    SetTextEntry('STRING')
    AddTextComponentString(lockNotif.icon)
    DrawText(baseX + 0.012, baseY + 0.008)

    -- Titre
    SetTextFont(4)
    SetTextScale(0.0, 0.32)
    SetTextColour(lockNotif.r, lockNotif.g + 10, lockNotif.b + 10, alpha)
    SetTextDropshadow(1, 0, 0, 0, math.floor(alpha * 0.5))
    SetTextEntry('STRING')
    AddTextComponentString(lockNotif.title)
    DrawText(baseX + 0.028, baseY + 0.005)

    -- Texte
    SetTextFont(4)
    SetTextScale(0.0, 0.28)
    SetTextColour(220, 220, 220, alpha)
    SetTextDropshadow(1, 0, 0, 0, math.floor(alpha * 0.5))
    SetTextEntry('STRING')
    AddTextComponentString(lockNotif.text)
    DrawText(baseX + 0.028, baseY + 0.032)
end

CreateThread(function()
    while true do
        Citizen.Wait(0)
        if lockNotif.active then
            drawStyledNotification()
        else
            Citizen.Wait(500)
        end
    end
end)

RegisterNetEvent('lockpick:syncUnlock')
AddEventHandler('lockpick:syncUnlock', function(netId)
    unlockedVehicles[netId] = true
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(vehicle) then
        SetVehicleDoorsLocked(vehicle, 1)
    end
end)

RegisterNetEvent('lockpick:syncHotwire')
AddEventHandler('lockpick:syncHotwire', function(netId)
    hotwiredVehicles[netId] = true
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(vehicle) then
        SetVehicleUndriveable(vehicle, false)
        SetVehicleEngineOn(vehicle, true, false, true)
    end
end)

-- ─── Admin spawn : marquer le vehicule comme deverrouille + hotwire ─────
AddEventHandler('lockpick:adminSpawn', function(netId)
    unlockedVehicles[netId] = true
    hotwiredVehicles[netId] = true
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(vehicle) then
        SetVehicleDoorsLocked(vehicle, 1)
        SetVehicleUndriveable(vehicle, false)
        SetVehicleEngineOn(vehicle, true, false, true)
    end
end)

RegisterNetEvent('lockpick:syncAdminSpawn')
AddEventHandler('lockpick:syncAdminSpawn', function(netId)
    unlockedVehicles[netId] = true
    hotwiredVehicles[netId] = true
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(vehicle) then
        SetVehicleDoorsLocked(vehicle, 1)
        SetVehicleUndriveable(vehicle, false)
        SetVehicleEngineOn(vehicle, true, false, true)
    end
end)
