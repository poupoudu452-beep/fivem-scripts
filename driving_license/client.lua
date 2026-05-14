-- ============================================================
--  PERMIS DE CONDUIRE — CLIENT
--  PNJ auto-école, quiz code, épreuve pratique
--  Checkpoints visibles au sol, notifications limites vitesse
-- ============================================================

local instructorPed  = nil
local isQuizOpen     = false
local examQuestions  = {}
local codePassed     = false
local hasLicense     = false
local lastExamTime   = 0

-- Épreuve pratique
local practicalActive     = false
local practicalVehicle    = nil
local practicalCheckpoint = 1
local practicalErrors     = 0
local practicalBlip       = nil
local previousSpeedLimit  = nil

-- ─── Utilitaires ────────────────────────────────────────────────────────────

local function ShuffleTable(t)
    local copy = {}
    for i, v in ipairs(t) do copy[i] = v end
    for i = #copy, 2, -1 do
        local j = math.random(i)
        copy[i], copy[j] = copy[j], copy[i]
    end
    return copy
end

function Notify(style, title, text, duration)
    SendNUIMessage({
        type     = 'showNotification',
        style    = style or 'info',
        title    = title or 'Auto-École',
        text     = text or '',
        duration = duration or 5000,
    })
end

-- ═══════════════════════════════════════════════════════════════
--  VÉRIFICATION PERMIS (côté client, via callback serveur)
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('driving:licenseStatus')
AddEventHandler('driving:licenseStatus', function(status)
    hasLicense = status
end)

Citizen.CreateThread(function()
    Wait(2000)
    TriggerServerEvent('driving:checkLicense')
end)

-- ═══════════════════════════════════════════════════════════════
--  QUIZ CODE DE LA ROUTE
-- ═══════════════════════════════════════════════════════════════

function OpenQuizMenu()
    if isQuizOpen then return end

    local all = ShuffleTable(DrivingConfig.Questions)
    local count = DrivingConfig.QuestionsPerExam or 10
    examQuestions = {}

    for i = 1, math.min(count, #all) do
        examQuestions[#examQuestions + 1] = {
            index    = i,
            question = all[i].question,
            choices  = all[i].choices,
            answer   = all[i].answer,
        }
    end

    local clientQuestions = {}
    for _, q in ipairs(examQuestions) do
        clientQuestions[#clientQuestions + 1] = {
            index    = q.index,
            question = q.question,
            choices  = q.choices,
        }
    end

    isQuizOpen = true
    SetNuiFocus(true, true)

    SendNUIMessage({
        action       = 'openQuiz',
        questions    = clientQuestions,
        required     = DrivingConfig.RequiredScore,
        resourceName = GetCurrentResourceName(),
    })
end

RegisterNUICallback('quizFinished', function(data, cb)
    cb('ok')
    isQuizOpen = false
    SetNuiFocus(false, false)

    local answers = data.answers or {}
    local score = 0
    for _, q in ipairs(examQuestions) do
        local playerAnswer = tonumber(answers[tostring(q.index)])
        if playerAnswer and playerAnswer == q.answer then
            score = score + 1
        end
    end

    local total    = #examQuestions
    local required = DrivingConfig.RequiredScore or 7
    local passed   = score >= required

    if passed then
        codePassed = true
        Notify('success', 'Code de la Route', 'Examen réussi ! (' .. score .. '/' .. total .. ') Parlez au moniteur pour passer la pratique.', 8000)
    else
        lastExamTime = GetGameTimer()
        Notify('error', 'Code de la Route', 'Examen raté... (' .. score .. '/' .. total .. ') Il faut au moins ' .. required .. ' bonnes réponses.', 6000)
    end

    examQuestions = {}
end)

RegisterNUICallback('quizClosed', function(data, cb)
    cb('ok')
    isQuizOpen = false
    SetNuiFocus(false, false)
    examQuestions = {}
end)

-- ═══════════════════════════════════════════════════════════════
--  ÉPREUVE PRATIQUE
-- ═══════════════════════════════════════════════════════════════

function StartPracticalTest()
    if practicalActive then return end

    local vCfg  = DrivingConfig.Vehicle
    local hash  = GetHashKey(vCfg.model)

    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 50 do
        Wait(100)
        t = t + 1
    end

    if not HasModelLoaded(hash) then
        Notify('error', 'Auto-École', 'Impossible de charger le véhicule.')
        return
    end

    local spawn = vCfg.spawn
    practicalVehicle = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w, true, false)
    SetVehicleOnGroundProperly(practicalVehicle)
    SetEntityAsMissionEntity(practicalVehicle, true, true)
    SetModelAsNoLongerNeeded(hash)

    local ped = PlayerPedId()
    TaskWarpPedIntoVehicle(ped, practicalVehicle, -1)

    practicalActive     = true
    practicalCheckpoint = 1
    practicalErrors     = 0
    previousSpeedLimit  = nil

    local firstCp = DrivingConfig.PracticalCheckpoints[1]
    Notify('info', 'Épreuve Pratique', 'Conduisez jusqu\'au premier checkpoint. Limite : ' .. firstCp.maxSpeed .. ' km/h', 6000)
    previousSpeedLimit = firstCp.maxSpeed

    UpdateCheckpointBlip()

    Citizen.CreateThread(PracticalTestLoop)
    Citizen.CreateThread(DrawCheckpointMarkers)
end

function UpdateCheckpointBlip()
    if practicalBlip then
        RemoveBlip(practicalBlip)
        practicalBlip = nil
    end

    local cps = DrivingConfig.PracticalCheckpoints
    if practicalCheckpoint > #cps then return end

    local cp = cps[practicalCheckpoint]
    practicalBlip = AddBlipForCoord(cp.coords.x, cp.coords.y, cp.coords.z)
    SetBlipSprite(practicalBlip, 1)
    SetBlipColour(practicalBlip, 5)
    SetBlipScale(practicalBlip, 0.9)
    SetBlipRoute(practicalBlip, true)
    SetBlipRouteColour(practicalBlip, 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Checkpoint ' .. practicalCheckpoint)
    EndTextCommandSetBlipName(practicalBlip)
end

function CleanupPractical()
    practicalActive = false
    previousSpeedLimit = nil

    if practicalBlip then
        RemoveBlip(practicalBlip)
        practicalBlip = nil
    end

    if practicalVehicle and DoesEntityExist(practicalVehicle) then
        local ped = PlayerPedId()
        if GetVehiclePedIsIn(ped, false) == practicalVehicle then
            TaskLeaveVehicle(ped, practicalVehicle, 0)
            Wait(1500)
        end
        DeleteEntity(practicalVehicle)
        practicalVehicle = nil
    end
end

-- ─── MARKERS AU SOL ─────────────────────────────────────────────────────────

function DrawCheckpointMarkers()
    local cfg = DrivingConfig.Marker

    while practicalActive do
        Citizen.Wait(0)

        local cps = DrivingConfig.PracticalCheckpoints
        local playerPos = GetEntityCoords(PlayerPedId())

        for i = practicalCheckpoint, math.min(practicalCheckpoint + 1, #cps) do
            local cp = cps[i]
            local dist = #(playerPos - cp.coords)

            if dist < cfg.drawDist then
                local color
                if i == practicalCheckpoint then
                    color = cfg.colorNext
                else
                    color = cfg.colorAhead
                end

                DrawMarker(
                    cfg.type,
                    cp.coords.x, cp.coords.y, cp.coords.z - 1.0,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    cfg.scale.x, cfg.scale.y, cfg.scale.z,
                    color.r, color.g, color.b, color.a,
                    cfg.bobUpDown, false, 2,
                    cfg.rotate, nil, nil, false
                )

                if i == practicalCheckpoint then
                    DrawMarker(
                        2,
                        cp.coords.x, cp.coords.y, cp.coords.z + 2.5,
                        0.0, 0.0, 0.0,
                        0.0, 180.0, 0.0,
                        0.5, 0.5, 0.5,
                        color.r, color.g, color.b, math.min(color.a + 60, 255),
                        true, false, 2,
                        true, nil, nil, false
                    )
                end
            end
        end
    end
end

-- ─── BOUCLE PRINCIPALE PRATIQUE ─────────────────────────────────────────────

function PracticalTestLoop()
    local checkpoints = DrivingConfig.PracticalCheckpoints
    local maxErrors   = DrivingConfig.PracticalMaxErrors or 5
    local speedWarningCooldown = 0

    while practicalActive do
        Citizen.Wait(200)

        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if veh == 0 or veh ~= practicalVehicle then
            Notify('error', 'Épreuve Pratique', 'Vous avez quitté le véhicule ! Épreuve annulée.', 5000)
            CleanupPractical()
            return
        end

        if practicalCheckpoint > #checkpoints then
            Notify('success', 'Épreuve Pratique', 'Parcours terminé avec ' .. practicalErrors .. ' erreur(s) ! Permis obtenu !', 8000)
            TriggerServerEvent('driving:giveLicense')
            hasLicense = true
            CleanupPractical()
            return
        end

        local cp = checkpoints[practicalCheckpoint]
        local playerPos = GetEntityCoords(ped)
        local dist = #(playerPos - cp.coords)

        local speedMs  = GetEntitySpeed(veh)
        local speedKmh = speedMs * 3.6

        if speedKmh > cp.maxSpeed + 2.0 then
            if GetGameTimer() > speedWarningCooldown then
                practicalErrors = practicalErrors + 1
                speedWarningCooldown = GetGameTimer() + 3000

                if practicalErrors >= maxErrors then
                    Notify('error', 'Épreuve Pratique', 'Trop d\'infractions (' .. practicalErrors .. '/' .. maxErrors .. ') ! Épreuve échouée.', 6000)
                    CleanupPractical()
                    return
                else
                    Notify('warning', 'Infraction', 'Excès de vitesse ! (' .. math.floor(speedKmh) .. ' km/h au lieu de ' .. cp.maxSpeed .. ' km/h) — Erreur ' .. practicalErrors .. '/' .. maxErrors, 4000)
                end
            end
        end

        if dist < cp.radius then
            practicalCheckpoint = practicalCheckpoint + 1
            UpdateCheckpointBlip()

            if practicalCheckpoint > #checkpoints then
                Notify('success', 'Épreuve Pratique', 'Parcours terminé avec ' .. practicalErrors .. ' erreur(s) ! Permis obtenu !', 8000)
                TriggerServerEvent('driving:giveLicense')
                hasLicense = true
                CleanupPractical()
                return
            end

            local nextCp = checkpoints[practicalCheckpoint]
            Notify('success', 'Checkpoint', 'Checkpoint ' .. (practicalCheckpoint - 1) .. '/' .. #checkpoints .. ' validé !', 3000)

            if previousSpeedLimit and nextCp.maxSpeed ~= previousSpeedLimit then
                local direction = nextCp.maxSpeed > previousSpeedLimit and 'augmente' or 'diminue'
                Notify('info', 'Limite de Vitesse', 'La vitesse limite ' .. direction .. ' : ' .. nextCp.maxSpeed .. ' km/h', 4000)
            end
            previousSpeedLimit = nextCp.maxSpeed
        end
    end
end


-- ═══════════════════════════════════════════════════════════════
--  SPAWN PNJ + HANDLER pnj_interact
-- ═══════════════════════════════════════════════════════════════

function SpawnInstructor()
    local cfg  = DrivingConfig.Ped
    local hash = GetHashKey(cfg.model)

    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 50 do
        Wait(100)
        timeout = timeout + 1
    end

    if not HasModelLoaded(hash) then
        print('[DrivingLicense] Impossible de charger le modèle : ' .. cfg.model)
        return
    end

    instructorPed = CreatePed(4, hash, cfg.coords.x, cfg.coords.y, cfg.coords.z, cfg.heading, false, true)
    SetEntityHeading(instructorPed, cfg.heading)
    FreezeEntityPosition(instructorPed, true)
    SetEntityInvincible(instructorPed, true)
    SetBlockingOfNonTemporaryEvents(instructorPed, true)
    TaskStartScenarioInPlace(instructorPed, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    SetModelAsNoLongerNeeded(hash)

    print('[DrivingLicense] PNJ moniteur créé')
end

Citizen.CreateThread(function()
    Wait(1000)
    SpawnInstructor()

    while GetResourceState('pnj_interact') ~= 'started' do
        Citizen.Wait(500)
    end
    Citizen.Wait(500)

    exports['pnj_interact']:RegisterPedHandler({
        name     = 'driving_instructor',
        priority = 15,

        detect = function(ped)
            return ped == instructorPed
        end,

        getName = function(ped)
            return DrivingConfig.Ped.name
        end,

        getHoverData = function(ped)
            return {}
        end,

        getMenuOptions = function(ped, isTied, isSeated, name)
            return {
                { label = 'Parler', icon = 'chat', action = 'talk' },
            }
        end,

        getDialogue = function(ped, isTied, isSeated, male, name)
            if hasLicense then
                return {
                    name      = DrivingConfig.Ped.name,
                    dialogue  = DrivingConfig.DialogueAlready,
                    responses = {
                        { label = 'Au revoir', icon = 'wave', action = 'leave' },
                    },
                    extraData = {},
                }
            elseif codePassed then
                return {
                    name      = DrivingConfig.Ped.name,
                    dialogue  = DrivingConfig.DialoguePratique,
                    responses = {
                        { label = 'Passer la pratique', icon = 'chat', action = 'start_practical' },
                        { label = 'Au revoir',          icon = 'wave', action = 'leave' },
                    },
                    extraData = {},
                }
            else
                return {
                    name      = DrivingConfig.Ped.name,
                    dialogue  = DrivingConfig.DialogueCode,
                    responses = {
                        { label = 'Passer le code', icon = 'chat', action = 'start_exam' },
                        { label = 'Au revoir',      icon = 'wave', action = 'leave' },
                    },
                    extraData = {},
                }
            end
        end,

        onResponse = function(ped, action, label)
            if action == 'start_exam' then
                local cooldown = (DrivingConfig.ExamCooldown or 60) * 1000
                if GetGameTimer() - lastExamTime < cooldown then
                    local remaining = math.ceil((cooldown - (GetGameTimer() - lastExamTime)) / 1000)
                    Notify('warning', 'Auto-École', 'Veuillez patienter ' .. remaining .. ' secondes avant de repasser l\'examen.', 4000)
                    return true
                end
                exports['pnj_interact']:CloseCurrentDialogue(false)
                Citizen.Wait(200)
                OpenQuizMenu()
                return true

            elseif action == 'start_practical' then
                exports['pnj_interact']:CloseCurrentDialogue(false)
                Citizen.Wait(200)
                StartPracticalTest()
                return true

            elseif action == 'leave' then
                exports['pnj_interact']:CloseCurrentDialogue(false)
                return true
            end

            return false
        end,

        onClose = function(ped)
            FreezeEntityPosition(ped, true)
            TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)
        end,
    })

    print('[DrivingLicense] Handler pnj_interact enregistré')
end)

-- ═══════════════════════════════════════════════════════════════
--  NETTOYAGE
-- ═══════════════════════════════════════════════════════════════

AddEventHandler('onResourceStop', function(resName)
    if GetCurrentResourceName() ~= resName then return end

    if instructorPed and DoesEntityExist(instructorPed) then
        DeleteEntity(instructorPed)
    end

    if isQuizOpen then
        SetNuiFocus(false, false)
        isQuizOpen = false
    end

    if practicalActive then
        CleanupPractical()
    end
end)
