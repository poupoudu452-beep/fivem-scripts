local isThirdEyeActive = false
local isDialogueOpen   = false
local hoveredPed       = nil
local hoveredPedName   = nil
local hoveredPlayer    = nil
local hoveredPlayerName = nil
local hoveredPlayerServerId = nil
local talkingToPed     = nil
local pedNameCache     = {}
local pedMaleCache     = {}
local currentHeadshot  = nil
local pendingAction    = nil
local pendingPed       = nil
local tiedUpPeds       = {}
local seatedPeds       = {}
local policeActionTarget = nil

-- Vérifier si un PNJ est un dealer (marqué par go_fast)
function IsDealerPed(ped)
    return DecorExistOn(ped, 'gofast_dealer') and DecorGetInt(ped, 'gofast_dealer') == 1
end

-- Vérifier si un PNJ est le receveur de la mission go fast
function IsReceiverPed(ped)
    return DecorExistOn(ped, 'gofast_receiver') and DecorGetInt(ped, 'gofast_receiver') == 1
end

-- Vérifier si un PNJ est le PNJ du commissariat
function IsPoliceStationPed(ped)
    return DecorExistOn(ped, 'police_station_npc') and DecorGetInt(ped, 'police_station_npc') == 1
end

-- Helpers police (pcall pour éviter les erreurs si police_job n'est pas chargé)
function IsLocalPlayerPolice()
    local ok, val = pcall(function() return exports['police_job']:IsPoliceClient() end)
    return ok and val or false
end

function IsLocalPlayerOnDuty()
    local ok, val = pcall(function() return exports['police_job']:IsOnDutyClient() end)
    return ok and val or false
end

function IsLocalPlayerCommander()
    local ok, val = pcall(function() return exports['police_job']:IsCommanderClient() end)
    return ok and val or false
end

-- ═══════════════════════════════════════════
--  COOLDOWN : phrase approximative en français
-- ═══════════════════════════════════════════

function GetCooldownPhrase(remaining)
    local mins = math.floor(remaining / 60)
    if mins >= 40 then
        return "Reviens d'ici 45 minutes, c'est encore trop tôt."
    elseif mins >= 25 then
        return "Reviens d'ici une demi-heure, c'est encore trop tôt."
    elseif mins >= 15 then
        return "Reviens d'ici 20 minutes, c'est encore trop tôt."
    elseif mins >= 10 then
        return "Reviens d'ici un quart d'heure, c'est encore trop tôt."
    elseif mins >= 5 then
        return "Reviens d'ici 10 minutes, c'est encore trop tôt."
    elseif mins >= 2 then
        return "Reviens d'ici 5 minutes, c'est encore trop tôt."
    else
        return "Reviens dans quelques minutes, c'est encore trop tôt."
    end
end

-- ═══════════════════════════════════════════
--  ANIMATION : remise de clés (PNJ donne, joueur reçoit)
-- ═══════════════════════════════════════════

function PlayGiveKeysAnimation(ped, callback)
    local playerPed = PlayerPedId()

    -- Dégeler le PNJ pour qu'il puisse tourner
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
    ClearPedTasks(playerPed)

    -- Faire tourner le joueur et le PNJ face à face
    TaskTurnPedToFaceEntity(playerPed, ped, 1500)
    TaskTurnPedToFaceEntity(ped, playerPed, 1500)
    Citizen.Wait(1500)

    -- Charger le dictionnaire d'animation
    local dict = 'mp_common'
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Citizen.Wait(10)
    end

    -- Jouer les animations synchronisées (PNJ donne, joueur reçoit)
    TaskPlayAnim(ped, dict, 'givetake1_a', 8.0, -8.0, 2000, 0, 0, false, false, false)
    TaskPlayAnim(playerPed, dict, 'givetake1_b', 8.0, -8.0, 2000, 0, 0, false, false, false)

    -- Attendre la fin de l'animation
    Citizen.Wait(2000)

    -- Regeler le PNJ en place
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, true)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)

    if callback then
        callback()
    end
end

-- ═══════════════════════════════════════════
--  REGISTRE D'OBJETS EXTERNE (extensible)
--  Les scripts externes peuvent enregistrer
--  des modèles d'objets avec leur propre menu
-- ═══════════════════════════════════════════

local registeredObjects = {}  -- modelHash -> config
local hoveredObject     = nil
local hoveredObjectCfg  = nil

-- Export : RegisterObject(config)
-- config = {
--   models   = { 'prop_atm_01', 'prop_atm_02', ... }   -- noms de modèles (string)
--   label    = 'ATM'                                     -- texte affiché au survol
--   icon     = 'atm'                                     -- nom d'icône (voir NUI)
--   tag      = 'Distributeur'                             -- tag sous le nom dans le dialogue
--   dialogue = 'Texte du dialogue...'                     -- texte dans la bulle
--   responses = {
--     { label = 'Percer', icon = 'drill', event = 'atm_robbery:start', ... }
--     { label = 'Annuler', icon = 'wave' }
--   }
-- }
function RegisterObjectHandler(config)
    if not config or not config.models then return end
    for _, modelName in ipairs(config.models) do
        local hash = type(modelName) == 'number' and modelName or GetHashKey(modelName)
        registeredObjects[hash] = config
    end
end

exports('RegisterObject', RegisterObjectHandler)

-- ═══════════════════════════════════════════
--  TROISIÈME ŒIL (ALT)
-- ═══════════════════════════════════════════

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        DisableControlAction(0, 19, true)

        if IsDisabledControlJustPressed(0, 19) and not isDialogueOpen then
            ToggleThirdEye(true)
        end

        if IsDisabledControlJustReleased(0, 19) and isThirdEyeActive and not isDialogueOpen then
            ToggleThirdEye(false)
        end

        if isThirdEyeActive and not isDialogueOpen then
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 47, true)
            DisableControlAction(0, 58, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 263, true)

            HandleThirdEyeRaycast()

            if IsDisabledControlJustPressed(0, 24) then
                if hoveredObject then
                    OpenObjectMenu()
                elseif hoveredPlayer then
                    TalkToPlayer()
                elseif hoveredPed then
                    TalkToPed()
                end
            end
        end

        if isDialogueOpen then
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
        end
    end
end)

-- Thread qui détecte les actions en attente (kidnap, etc.)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)
        if pendingAction == 'kidnap' and pendingPed and DoesEntityExist(pendingPed) then
            local ped = pendingPed
            pendingAction = nil
            pendingPed = nil
            DoKidnapAnimation(ped)
        elseif pendingAction == 'untie' and pendingPed and DoesEntityExist(pendingPed) then
            local ped = pendingPed
            pendingAction = nil
            pendingPed = nil
            DoUntieAnimation(ped)
        elseif pendingAction == 'sitdown' and pendingPed and DoesEntityExist(pendingPed) then
            local ped = pendingPed
            pendingAction = nil
            pendingPed = nil
            DoSitDownAnimation(ped)
        elseif pendingAction == 'standup' and pendingPed and DoesEntityExist(pendingPed) then
            local ped = pendingPed
            pendingAction = nil
            pendingPed = nil
            DoStandUpAnimation(ped)
        end
    end
end)

function ToggleThirdEye(state)
    isThirdEyeActive = state

    if state then
        SendNUIMessage({
            action = 'showThirdEye',
        })
    else
        hoveredPed = nil
        hoveredPedName = nil
        hoveredPlayer = nil
        hoveredPlayerName = nil
        hoveredPlayerServerId = nil
        hoveredObject    = nil
        hoveredObjectCfg = nil

        SendNUIMessage({
            action = 'hideThirdEye',
        })
    end
end

-- ═══════════════════════════════════════════
--  RAYCAST : Détection du PNJ
-- ═══════════════════════════════════════════

function HandleThirdEyeRaycast()
    local foundPed    = nil
    local foundPlayer = nil
    local foundObject = nil
    local foundObjCfg = nil

    -- Raycast : flag 28 = peds(4) + vehicles(8) + objects(16)
    local hit, coords, entity = RaycastFromCamera(Config.MaxDistance)
    if hit and DoesEntityExist(entity) then
        if IsEntityAPed(entity) then
            if IsPedAPlayer(entity) then
                foundPlayer = entity
            else
                foundPed = entity
            end
        else
            -- Verifier si c'est un objet enregistre
            local model = GetEntityModel(entity)
            if registeredObjects[model] then
                foundObject = entity
                foundObjCfg = registeredObjects[model]
            end
        end
    end

    -- Fallback : détection PNJ en face (si rien trouvé par raycast)
    if not foundPed and not foundPlayer and not foundObject then
        local fallbackPed, fallbackIsPlayer = GetClosestPedInFront(Config.MaxDistance)
        if fallbackPed then
            if fallbackIsPlayer then
                foundPlayer = fallbackPed
            else
                foundPed = fallbackPed
            end
        end
    end

    -- Objet enregistré détecté
    if foundObject then
        if foundObject ~= hoveredObject then
            hoveredObject    = foundObject
            hoveredObjectCfg = foundObjCfg
            hoveredPed     = nil
            hoveredPedName = nil
            hoveredPlayer = nil
            hoveredPlayerName = nil
            hoveredPlayerServerId = nil

            SendNUIMessage({
                action = 'hoverObject',
                label  = foundObjCfg.label or 'Objet',
                icon   = foundObjCfg.icon or 'info',
            })
        end
    elseif hoveredObject then
        hoveredObject    = nil
        hoveredObjectCfg = nil
        SendNUIMessage({ action = 'unhoverPed' })
    end

    -- Joueur détecté (priorité sur les PNJ)
    if foundPlayer and not foundObject then
        if foundPlayer ~= hoveredPlayer then
            hoveredPlayer = foundPlayer
            -- Récupérer le server ID du joueur ciblé
            local targetPlayerId = NetworkGetPlayerIndexFromPed(foundPlayer)
            hoveredPlayerServerId = GetPlayerServerId(targetPlayerId)
            hoveredPlayerName = GetPlayerName(targetPlayerId) or ('Joueur ' .. hoveredPlayerServerId)
            -- Masquer le PNJ
            hoveredPed = nil
            hoveredPedName = nil

            local isPolice = IsLocalPlayerPolice()
            local isOnDuty = IsLocalPlayerOnDuty()

            SendNUIMessage({
                action      = 'hoverPed',
                pedName     = hoveredPlayerName,
                isPlayer    = true,
                isPolice    = isPolice and isOnDuty,
            })
        end
    elseif not foundPlayer then
        if hoveredPlayer ~= nil then
            hoveredPlayer = nil
            hoveredPlayerName = nil
            hoveredPlayerServerId = nil
            SendNUIMessage({ action = 'unhoverPed' })
        end
    end

    -- PNJ détecté (seulement si pas d'objet et pas de joueur)
    if foundPed and not foundObject and not foundPlayer then
        if foundPed ~= hoveredPed then
            hoveredPed = foundPed
            hoveredPedName = GetPedName(foundPed)
            hoveredPlayer = nil
            hoveredPlayerName = nil
            hoveredPlayerServerId = nil

            local trust = nil
            local isReceiver = IsReceiverPed(foundPed)
            if isReceiver then
                trust = exports['go_fast']:GetTrust()
            end

            SendNUIMessage({
                action      = 'hoverPed',
                pedName     = hoveredPedName,
                pedModel    = GetEntityModel(foundPed),
                isReceiver  = isReceiver,
                trust       = trust,
            })
        end
    elseif not foundPed and not foundPlayer and not foundObject then
        if hoveredPed ~= nil then
            hoveredPed = nil
            hoveredPedName = nil

            SendNUIMessage({ action = 'unhoverPed' })
        end
    end
end

function RaycastFromCamera(maxDist)
    local camRot = GetGameplayCamRot(2)
    local camPos = GetGameplayCamCoord()

    local dir = RotToDir(camRot)
    local dest = vector3(
        camPos.x + dir.x * maxDist,
        camPos.y + dir.y * maxDist,
        camPos.z + dir.z * maxDist
    )

    local ray = StartShapeTestRay(camPos.x, camPos.y, camPos.z, dest.x, dest.y, dest.z, 28, PlayerPedId(), 0)
    local _, hit, coords, _, entity = GetShapeTestResult(ray)

    return hit == 1, coords, entity
end

function GetClosestPedInFront(maxDist)
    local playerPed = PlayerPedId()
    local playerPos = GetEntityCoords(playerPed)
    local playerFwd = GetEntityForwardVector(playerPed)
    local closestPed = nil
    local closestDist = maxDist
    local closestIsPlayer = false

    local handle, ped = FindFirstPed()
    local found = true

    while found do
        if DoesEntityExist(ped) and ped ~= playerPed and not IsPedDeadOrDying(ped, true) then
            local pedPos = GetEntityCoords(ped)
            local dist = #(playerPos - pedPos)

            if dist < closestDist then
                local toTarget = pedPos - playerPos
                local dot = toTarget.x * playerFwd.x + toTarget.y * playerFwd.y
                if dot > 0.0 then
                    closestDist = dist
                    closestPed = ped
                    closestIsPlayer = IsPedAPlayer(ped)
                end
            end
        end
        found, ped = FindNextPed(handle)
    end
    EndFindPed(handle)

    return closestPed, closestIsPlayer
end

function RotToDir(rot)
    local rz = math.rad(rot.z)
    local rx = math.rad(rot.x)
    local cosx = math.abs(math.cos(rx))
    return vector3(-math.sin(rz) * cosx, math.cos(rz) * cosx, math.sin(rx))
end

-- ═══════════════════════════════════════════
--  NOM DU PNJ (caché par entity, genre détecté)
-- ═══════════════════════════════════════════

function GetReceiverDisplayName()
    local trust = exports['go_fast']:GetTrust()
    local threshold = exports['go_fast']:GetTrustRevealThreshold()
    if trust >= threshold then
        return exports['go_fast']:GetReceiverRealName()
    end
    return "???"
end

function GetPedName(ped)
    local entityId = ped

    -- Receveur : afficher le nom réel si confiance >= seuil
    if IsReceiverPed(ped) then
        local name = GetReceiverDisplayName()
        pedNameCache[entityId] = name
        return name
    end

        -- Dealer : afficher Ghost si le joueur a déjà payé, sinon ???
        -- (pas de cache pour que le nom se mette à jour après le premier paiement)
    if IsDealerPed(ped) then
        local hasPaid = exports['go_fast']:HasPaidDealer()
        if hasPaid then
            return exports['go_fast']:GetDealerRealName()
        else
            return "???"
        end
    end

    if pedNameCache[entityId] then
        return pedNameCache[entityId]
    end

    local male = Citizen.InvokeNative(0x6D9F5FAA7488BA46, ped)
    pedMaleCache[entityId] = male

    local firstName
    if male then
        firstName = Config.MaleFirstNames[math.random(#Config.MaleFirstNames)]
    else
        firstName = Config.FemaleFirstNames[math.random(#Config.FemaleFirstNames)]
    end
    local lastName = Config.LastNames[math.random(#Config.LastNames)]
    local name = firstName .. " " .. lastName

    pedNameCache[entityId] = name
    return name
end

function IsPedModelMale(ped)
    if pedMaleCache[ped] ~= nil then
        return pedMaleCache[ped]
    end
    local male = Citizen.InvokeNative(0x6D9F5FAA7488BA46, ped)
    pedMaleCache[ped] = male
    return male
end

-- ═══════════════════════════════════════════
--  PARLER AU PNJ (clic gauche direct)
-- ═══════════════════════════════════════════

function TalkToPed()
    if not hoveredPed or not DoesEntityExist(hoveredPed) then return end

    talkingToPed = hoveredPed
    isDialogueOpen = true
    SetNuiFocus(true, true)

    local isTied = IsPedTiedUp(hoveredPed)
    local male = IsPedModelMale(hoveredPed)
    local name = hoveredPedName or (male and "Inconnu" or "Inconnue")

    local isDealer = IsDealerPed(hoveredPed)
    local isReceiver = IsReceiverPed(hoveredPed)

    if not isTied and not isDealer and not isReceiver then
        ClearPedTasks(hoveredPed)
        local playerPed = PlayerPedId()
        TaskTurnPedToFaceEntity(hoveredPed, playerPed, 1500)
        Citizen.Wait(500)
        if DoesEntityExist(hoveredPed) then
            TaskStartScenarioInPlace(hoveredPed, "WORLD_HUMAN_STAND_IMPATIENT", 0, true)
        end
    end

    local headshotUrl = GetPedHeadshotUrl(hoveredPed)

    local dialogue
    local responses

    local isSeated = seatedPeds[hoveredPed] == true

    if isReceiver then
        -- Receveur go fast : menu special
        name = GetReceiverDisplayName()
        dialogue = "C'est toi qui viens me livrer ?"
        responses = {
            { label = "Oui c'est moi", icon = "chat", action = "receiver_oui" },
            { label = "Non non gros débile je suis des Stups", icon = "wave", action = "receiver_stups" },
        }
    elseif isDealer then
        -- Dealer : menu spécial
        local hasPaid = exports['go_fast']:HasPaidDealer()
        if hasPaid then
            name = exports['go_fast']:GetDealerRealName()
            dialogue = "Salut, t'as besoin d'un go fast ?"
            responses = {
                { label = "Ouais", icon = "give", action = "dealer_gofast_direct" },
                { label = "Non merci", icon = "wave", action = "dealer_non_merci" },
            }
        else
            dialogue = "Cet individu a l'air suspect..."
            responses = {
                { label = "En savoir plus sur l'individu", icon = "info", action = "dealer_info" },
            }
        end
    elseif isTied and isSeated then
                dialogue = male
                    and (name .. " est ligoté et assis.")
                    or  (name .. " est ligotée et assise.")
        responses = {
            { label = "Relever", icon = "wave" },
                { label = "Déligoter", icon = "wave" },
            }
        elseif isTied then
            dialogue = male
                and (name .. " est ligoté.")
                or  (name .. " est ligotée.")
        responses = {
                        { label = "Assis-toi ici", icon = "wave" },
                        { label = "Déligoter", icon = "wave" },
        }
    elseif IsPoliceStationPed(hoveredPed) then
        -- PNJ du commissariat de police
        local isPolice = IsLocalPlayerPolice()
        local isOnDuty = IsLocalPlayerOnDuty()
        local isCommander = IsLocalPlayerCommander()

        name = "Officier d'accueil"
        if isPolice then
            dialogue = "Bienvenue au commissariat. Que souhaitez-vous faire ?"
            responses = {
                { label = isOnDuty and "Fin de service" or "Prise de service", icon = "key", action = "station_toggle_duty" },
            }
            if isCommander then
                responses[#responses + 1] = { label = "Gérer les grades",    icon = "info", action = "station_grades" }
                responses[#responses + 1] = { label = "Modifier les salaires", icon = "atm", action = "station_salary" }
            end
            responses[#responses + 1] = { label = "Déployer des herses",  icon = "lock",  action = "station_spikes" }
            responses[#responses + 1] = { label = "Radar de vitesse",     icon = "car",   action = "station_radar" }
            responses[#responses + 1] = { label = "Au revoir",            icon = "wave",  action = "station_bye" }
        else
            dialogue = "Bonjour, bienvenue au commissariat. Vous avez des amendes à régler ?"
            responses = {
                { label = "Consulter mes amendes", icon = "atm",  action = "station_check_fines" },
                { label = "Au revoir",             icon = "wave", action = "station_bye" },
            }
        end
    else
        dialogue = Config.DefaultDialogues[math.random(#Config.DefaultDialogues)]
        responses = {
            { label = "Salut, comment ça va ?",    icon = "chat" },
            { label = "Ligoter " .. name,          icon = "kidnap" },
            { label = "Au revoir",                 icon = "wave" },
        }
    end

    local trust = nil
    if isReceiver then
        trust = exports['go_fast']:GetTrust()
    end

    SendNUIMessage({
        action      = 'openDialogue',
        pedName     = name,
        dialogue    = dialogue,
        responses   = responses,
        headshotUrl = headshotUrl,
        isReceiver  = isReceiver,
        trust       = trust,
    })
end

-- ═══════════════════════════════════════════
--  PARLER À UN JOUEUR (clic gauche sur joueur)
--  → Actions police si policier en service
-- ═══════════════════════════════════════════

function TalkToPlayer()
    if not hoveredPlayer or not DoesEntityExist(hoveredPlayer) then return end

    policeActionTarget = hoveredPlayerServerId
    isDialogueOpen = true
    SetNuiFocus(true, true)

    local name = hoveredPlayerName or 'Joueur'
    local headshotUrl = GetPedHeadshotUrl(hoveredPlayer)

    local isPolice = IsLocalPlayerPolice()
    local isOnDuty = IsLocalPlayerOnDuty()
    local isCommander = IsLocalPlayerCommander()

    local dialogue
    local responses = {}

    if isPolice and isOnDuty then
        dialogue = name .. " — Actions de police"
        responses = {
            { label = "Menotter / Démenotter",   icon = "kidnap",  action = "police_handcuff" },
            { label = "Fouiller",                icon = "info",    action = "police_frisk" },
            { label = "Escorter",                icon = "give",    action = "police_escort" },
            { label = "Mettre dans le véhicule", icon = "car",     action = "police_vehicle" },
            { label = "Amender",                 icon = "atm",     action = "police_fine_menu" },
            { label = "Emprisonner",             icon = "lock",    action = "police_jail_menu" },
        }
        if isCommander then
            responses[#responses + 1] = { label = "Recruter dans la Police", icon = "key", action = "police_recruit" }
        end
        responses[#responses + 1] = { label = "Annuler", icon = "wave", action = "police_cancel" }
    else
        dialogue = "C'est un joueur. Vous n'avez pas d'actions disponibles."
        responses = {
            { label = "Ok", icon = "wave", action = "police_cancel" },
        }
    end

    SendNUIMessage({
        action      = 'openDialogue',
        pedName     = name,
        dialogue    = dialogue,
        responses   = responses,
        headshotUrl = headshotUrl,
        isPlayer    = true,
    })
end

function GetPedHeadshotUrl(ped)
    if currentHeadshot then
        UnregisterPedheadshot(currentHeadshot)
        currentHeadshot = nil
    end

    Citizen.Wait(50)

    local handle = RegisterPedheadshot_3(ped)

    local timeout = 0
    while not IsPedheadshotReady(handle) and timeout < 200 do
        Citizen.Wait(10)
        timeout = timeout + 1
    end

    if IsPedheadshotReady(handle) then
        currentHeadshot = handle
        local txd = GetPedheadshotTxdString(handle)
        return "https://nui-img/" .. txd .. "/" .. txd .. "?t=" .. GetGameTimer()
    end

    handle = RegisterPedheadshot(ped)
    timeout = 0
    while not IsPedheadshotReady(handle) and timeout < 200 do
        Citizen.Wait(10)
        timeout = timeout + 1
    end

    if IsPedheadshotReady(handle) then
        currentHeadshot = handle
        local txd = GetPedheadshotTxdString(handle)
        return "https://nui-img/" .. txd .. "/" .. txd .. "?t=" .. GetGameTimer()
    end

    return nil
end

-- ═══════════════════════════════════════════
--  MENU OBJET GÉNÉRIQUE (clic gauche)
-- ═══════════════════════════════════════════

function OpenObjectMenu()
    if not hoveredObject or not DoesEntityExist(hoveredObject) then return end
    if not hoveredObjectCfg then return end

    local cfg = hoveredObjectCfg

    isDialogueOpen = true
    SetNuiFocus(true, true)

    SendNUIMessage({
        action      = 'openDialogue',
        pedName     = cfg.label or 'Objet',
        dialogue    = cfg.dialogue or '...',
        responses   = cfg.responses or {},
        headshotUrl = nil,
        isObject    = true,
        objectIcon  = cfg.icon or 'info',
        objectTag   = cfg.tag or 'Objet',
    })
end

-- ═══════════════════════════════════════════
--  NUI CALLBACKS
-- ═══════════════════════════════════════════

RegisterNUICallback('selectResponse', function(data, cb)
    cb('ok')

    local label  = data.label or ''
    local action = data.action or ''

    -- ─── Actions police sur joueur ───────────────────────────
    if string.find(action, '^police_') then
        HandlePoliceAction(action)
        return
    end

    -- ─── Actions commissariat ─────────────────────────────────
    if string.find(action, '^station_') then
        HandleStationAction(action)
        return
    end

    -- Réponse d'un objet enregistré : déclencher l'event associé
    -- (ignorer les actions dealer_ qui sont gérées plus bas)
    if action ~= '' and action ~= 'talk' and not string.find(action, '^dealer_') and not string.find(action, '^receiver_') then
        local obj = hoveredObject
        CloseDialogue(false)
        -- Chercher dans les responses la config correspondante
        if hoveredObjectCfg and hoveredObjectCfg.responses then
            for _, resp in ipairs(hoveredObjectCfg.responses) do
                if resp.action == action and resp.event then
                    TriggerEvent(resp.event, obj)
                    return
                end
            end
        end
        return
    end

    -- Receveur go fast : réponses
    if action == 'receiver_oui' then
        -- Clic sur "Oui c'est moi" -> vérifier que la voiture est dans un rayon de 15m
        local ped = talkingToPed
        local pedCoords = GetEntityCoords(ped)
        local missionVeh = exports['go_fast']:GetMissionVehicle()
        local vehicleNearby = false

        if missionVeh and DoesEntityExist(missionVeh) then
            local vehCoords = GetEntityCoords(missionVeh)
            local dist = #(pedCoords - vehCoords)
            if dist <= 15.0 then
                vehicleNearby = true
            end
        end

        if not vehicleNearby then
            -- Véhicule trop loin ou introuvable -> perte totale de confiance
            local receiverName = GetReceiverDisplayName()
            SendNUIMessage({
                action      = 'openDialogue',
                pedName     = receiverName,
                dialogue    = "Ouais tu te fout de ma gueule ? T'as même pas ramené la voiture...",
                responses   = {},
                headshotUrl = GetPedHeadshotUrl(talkingToPed),
                isReceiver  = true,
                trust       = exports['go_fast']:GetTrust(),
            })
            -- Remettre la confiance à 0
            TriggerServerEvent('go_fast:resetTrust')
            -- Retirer les clés
            TriggerEvent('go_fast:missionSuccess')
            Citizen.SetTimeout(3000, function()
                CloseDialogue(false)
                -- Le PNJ se casse
                if ped and DoesEntityExist(ped) then
                    FreezeEntityPosition(ped, false)
                    SetEntityInvincible(ped, false)
                    SetBlockingOfNonTemporaryEvents(ped, false)
                    DecorRemove(ped, 'gofast_receiver')
                    ClearPedTasks(ped)
                    TaskWanderStandard(ped, 10.0, 10)
                    SetPedAsNoLongerNeeded(ped)
                end
            end)
            return
        end

        -- Véhicule dans le rayon -> mission réussie, propose une voiture
        TriggerEvent('go_fast:missionSuccess')
        local receiverName = GetReceiverDisplayName()
        SendNUIMessage({
            action      = 'openDialogue',
            pedName     = receiverName,
            dialogue    = "T'as besoin que j'te file une voiture contre 500$ ou t'as ce qu'il faut pour partir ?",
            responses   = {
                { label = "Oui s'il te plaît", icon = "give", action = "receiver_voiture_oui" },
                { label = "Non c'est bon", icon = "wave", action = "receiver_voiture_non" },
            },
            headshotUrl = GetPedHeadshotUrl(talkingToPed),
            isReceiver  = true,
            trust       = exports['go_fast']:GetTrust(),
        })
        return
    elseif action == 'receiver_voiture_oui' then
        -- Clic sur "Oui s'il te plaît" -> vérifier 500$ côté serveur
        TriggerServerEvent('go_fast:payMoney', 500, 'receiver_500')
        return
    elseif action == 'receiver_voiture_ok' then
        -- Clic sur "Ok" -> spawn vieille voiture + PNJ part
        local ped = talkingToPed
        CloseDialogue(false)
        -- Spawn la voiture
        local carModel = GetHashKey('emperor')
        RequestModel(carModel)
        while not HasModelLoaded(carModel) do
            Citizen.Wait(10)
        end
        local car = CreateVehicle(carModel, 477.49, -1569.33, 29.11, 230.10, true, false)
        SetEntityAsMissionEntity(car, true, true)
        SetVehicleOnGroundProperly(car)
        SetVehicleDoorsLocked(car, 1)
        SetModelAsNoLongerNeeded(carModel)
        -- Le PNJ part faire sa vie
        if ped and DoesEntityExist(ped) then
            FreezeEntityPosition(ped, false)
            SetEntityInvincible(ped, false)
            SetBlockingOfNonTemporaryEvents(ped, false)
            DecorRemove(ped, 'gofast_receiver')
            ClearPedTasks(ped)
            TaskWanderStandard(ped, 10.0, 10)
            SetPedAsNoLongerNeeded(ped)
        end
        return
    elseif action == 'receiver_voiture_non' then
        -- Clic sur "Non c'est bon" -> PNJ part faire sa vie
        local ped = talkingToPed
        CloseDialogue(false)
        if ped and DoesEntityExist(ped) then
            FreezeEntityPosition(ped, false)
            SetEntityInvincible(ped, false)
            SetBlockingOfNonTemporaryEvents(ped, false)
            DecorRemove(ped, 'gofast_receiver')
            ClearPedTasks(ped)
            TaskWanderStandard(ped, 10.0, 10)
            SetPedAsNoLongerNeeded(ped)
        end
        return
    elseif action == 'receiver_stups' then
        -- Clic sur "Non non gros débile je suis des Stups" -> mission échouée
        local ped = talkingToPed
        CloseDialogue(false)
        if ped and DoesEntityExist(ped) then
            local pedCoords = GetEntityCoords(ped)
            TriggerEvent('go_fast:missionFail', pedCoords.x, pedCoords.y, pedCoords.z)
        end
        return
    end

    -- Dealer : arbre de dialogue (joueur qui a déjà payé)
    if action == 'dealer_gofast_direct' then
        -- Clic sur "Ouais" -> vérifier le cooldown avant animation
        local ped = talkingToPed
        local dealerName = exports['go_fast']:GetDealerRealName()
        exports['go_fast']:CheckCooldown(function(onCooldown, remaining)
            if onCooldown then
                -- Cooldown actif -> dialogue d'attente, pas d'animation
                local phrase = GetCooldownPhrase(remaining)
                SendNUIMessage({
                    action      = 'openDialogue',
                    pedName     = dealerName,
                    dialogue    = phrase,
                    responses   = {},
                    headshotUrl = GetPedHeadshotUrl(ped),
                })
                Citizen.SetTimeout(3000, function()
                    CloseDialogue(false)
                end)
            else
                -- Pas de cooldown -> animation + mission
                SendNUIMessage({
                    action      = 'openDialogue',
                    pedName     = dealerName,
                    dialogue    = "Ok la voiture t'attend, ramène-la à mon gars comme d'hab",
                    responses   = {},
                    headshotUrl = GetPedHeadshotUrl(ped),
                })
                Citizen.SetTimeout(2000, function()
                    CloseDialogue(false)
                    if ped and DoesEntityExist(ped) then
                        PlayGiveKeysAnimation(ped, function()
                            local pedCoords = GetEntityCoords(ped)
                            TriggerEvent('go_fast:startMission', pedCoords.x, pedCoords.y, pedCoords.z)
                        end)
                    end
                end)
            end
        end)
        return
    elseif action == 'dealer_non_merci' then
        -- Clic sur "Non merci" -> fermer le dialogue
        CloseDialogue(false)
        return

    -- Dealer : arbre de dialogue (première fois)
    elseif action == 'dealer_info' then
        -- Clic sur "En savoir plus sur l'individu" -> "Yo, tu veux quoi ?"
        SendNUIMessage({
            action      = 'openDialogue',
            pedName     = '???',
            dialogue    = "Yo, tu veux quoi ?",
            responses   = {
                { label = "Je cherche de quoi arrondir les fins de mois", icon = "chat", action = "dealer_taff" },
                { label = "Je voulais juste te dire que tu puais d'la gueule", icon = "wave", action = "dealer_insulte" },
            },
            headshotUrl = GetPedHeadshotUrl(talkingToPed),
        })
        return
    elseif action == 'dealer_taff' then
        -- Clic sur "Je cherche de quoi arrondir les fins de mois"
        SendNUIMessage({
            action      = 'openDialogue',
            pedName     = '???',
            dialogue    = "J'ai sûrement du boulot pour toi, mais faut payer",
            responses   = {
                { label = "Tu veux combien ?", icon = "chat", action = "dealer_combien" },
                { label = "J'ai pas d'fric", icon = "wave", action = "dealer_pasfric" },
            },
            headshotUrl = GetPedHeadshotUrl(talkingToPed),
        })
        return
    elseif action == 'dealer_combien' then
        -- Clic sur "Tu veux combien ?" -> Dealer dit "Hmm 5000$"
        SendNUIMessage({
            action      = 'openDialogue',
            pedName     = '???',
            dialogue    = "Hmm 5000$",
            responses   = {
                { label = "Voilà l'argent", icon = "give", action = "dealer_payer" },
                { label = "On peut négocier ?", icon = "chat", action = "dealer_negocier" },
            },
            headshotUrl = GetPedHeadshotUrl(talkingToPed),
        })
        return
    elseif action == 'dealer_payer' then
        -- Clic sur "Voilà l'argent" (5000$) -> vérifier cooldown puis argent
        exports['go_fast']:CheckCooldown(function(onCooldown, remaining)
            if onCooldown then
                local phrase = GetCooldownPhrase(remaining)
                SendNUIMessage({
                    action      = 'openDialogue',
                    pedName     = '???',
                    dialogue    = phrase,
                    responses   = {},
                    headshotUrl = GetPedHeadshotUrl(talkingToPed),
                })
                Citizen.SetTimeout(3000, function()
                    CloseDialogue(false)
                end)
            else
                TriggerServerEvent('go_fast:payMoney', 5000, 'dealer_5000')
            end
        end)
        return
    elseif action == 'dealer_negocier' then
        -- Clic sur "On peut négocier ?"
        SendNUIMessage({
            action      = 'openDialogue',
            pedName     = '???',
            dialogue    = "Pour 4000$ on en parle plus",
            responses   = {
                { label = "Voilà l'argent", icon = "give", action = "dealer_payer_nego" },
            },
            headshotUrl = GetPedHeadshotUrl(talkingToPed),
        })
        return
    elseif action == 'dealer_payer_nego' then
        -- Clic sur "Voilà l'argent" (4000$ après négo) -> vérifier cooldown puis argent
        exports['go_fast']:CheckCooldown(function(onCooldown, remaining)
            if onCooldown then
                local phrase = GetCooldownPhrase(remaining)
                SendNUIMessage({
                    action      = 'openDialogue',
                    pedName     = '???',
                    dialogue    = phrase,
                    responses   = {},
                    headshotUrl = GetPedHeadshotUrl(talkingToPed),
                })
                Citizen.SetTimeout(3000, function()
                    CloseDialogue(false)
                end)
            else
                TriggerServerEvent('go_fast:payMoney', 4000, 'dealer_4000')
            end
        end)
        return
    elseif action == 'dealer_pasfric' then
        -- Clic sur "J'ai pas d'fric" -> Dealer dit "Ça c'est pas mon problème" puis ferme
        SendNUIMessage({
            action      = 'openDialogue',
            pedName     = '???',
            dialogue    = "Ça c'est pas mon problème",
            responses   = {},
            headshotUrl = GetPedHeadshotUrl(talkingToPed),
        })
        -- Fermer après 2 secondes
        Citizen.SetTimeout(2000, function()
            CloseDialogue(false)
        end)
        return
    elseif action == 'dealer_insulte' then
        -- Clic sur "Je voulais juste te dire que tu puais d'la gueule"
        local ped = talkingToPed
        CloseDialogue(false)
        if ped and DoesEntityExist(ped) then
            local pedCoords = GetEntityCoords(ped)
            local myServerId = GetPlayerServerId(PlayerId())
            -- Envoyer au serveur pour synchroniser sur tous les clients
            TriggerServerEvent('go_fast:dealerAttack', pedCoords.x, pedCoords.y, pedCoords.z, myServerId)
        end
        return
    end

    if string.find(label, 'Ligoter') then
        pendingPed = talkingToPed
        pendingAction = 'kidnap'
        CloseDialogue(true)
    elseif label == 'Déligoter' then
        pendingPed = talkingToPed
        pendingAction = 'untie'
        CloseDialogue(true)
    elseif label == 'Assis-toi ici' then
        pendingPed = talkingToPed
        pendingAction = 'sitdown'
        CloseDialogue(true)
    elseif label == 'Relever' then
        pendingPed = talkingToPed
        pendingAction = 'standup'
        CloseDialogue(true)
    else
        CloseDialogue(false)
    end
end)

RegisterNUICallback('closeDialogue', function(data, cb)
    cb('ok')
    CloseDialogue(false)
end)

RegisterNUICallback('closeThirdEye', function(data, cb)
    cb('ok')
    ToggleThirdEye(false)
end)

function CloseDialogue(keepPed)
    isDialogueOpen = false

    if not keepPed and talkingToPed and DoesEntityExist(talkingToPed) then
        if IsDealerPed(talkingToPed) or IsReceiverPed(talkingToPed) then
            -- Dealer / Receveur : rester immobile, remettre le scenario idle
            FreezeEntityPosition(talkingToPed, true)
            TaskStartScenarioInPlace(talkingToPed, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
        else
            ClearPedTasks(talkingToPed)
            TaskWanderStandard(talkingToPed, 10.0, 10)
        end
    end

    if currentHeadshot then
        UnregisterPedheadshot(currentHeadshot)
        currentHeadshot = nil
    end

    if not keepPed then
        talkingToPed = nil
    end
    hoveredPed       = nil
    hoveredPedName   = nil
    hoveredObject    = nil
    hoveredObjectCfg = nil
    SetNuiFocus(false, false)

    SendNUIMessage({
        action = 'closeDialogue',
    })

    ToggleThirdEye(false)
end

-- ═══════════════════════════════════════════
--  KIDNAP : Animation du PNJ
-- ═══════════════════════════════════════════

function IsPedTiedUp(ped)
    return tiedUpPeds[ped] == true
end

-- Fait venir le PNJ devant le joueur, dos au joueur, et joue l'animation d'attacher/détacher
function PlayTieAnimation(ped)
    local playerPed = PlayerPedId()

    -- Calculer la position 1m devant le joueur
    local playerCoords = GetEntityCoords(playerPed)
    local playerForward = GetEntityForwardVector(playerPed)
    local targetX = playerCoords.x + playerForward.x * 1.0
    local targetY = playerCoords.y + playerForward.y * 1.0
    local targetZ = playerCoords.z

    -- Le PNJ marche vers la position devant le joueur
    local playerHeading = GetEntityHeading(playerPed)
    TaskGoStraightToCoord(ped, targetX, targetY, targetZ, 1.0, 5000, playerHeading, 0.5)

    -- Attendre que le PNJ arrive (max 5s)
    local timeout = 0
    while timeout < 5000 do
        Citizen.Wait(200)
        timeout = timeout + 200
        local pedPos = GetEntityCoords(ped)
        local dist = #(vector3(targetX, targetY, targetZ) - pedPos)
        if dist < 1.0 then
            break
        end
    end

    -- Arrêter le PNJ et le geler sur place pour qu'il ne bouge plus
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, true)

    -- Forcer le heading du PNJ (même direction que le joueur = dos au joueur)
    SetEntityHeading(ped, playerHeading)
    Citizen.Wait(200)

    -- Le joueur se tourne face au dos du PNJ
    TaskTurnPedToFaceEntity(playerPed, ped, 1000)
    Citizen.Wait(1000)

    -- Charger le dictionnaire d'animation
    RequestAnimDict("mp_arresting")
    while not HasAnimDictLoaded("mp_arresting") do
        Citizen.Wait(10)
    end

    -- Le joueur joue l'animation (mains sur les poignets)
    TaskPlayAnim(playerPed, "mp_arresting", "a_uncuff", 8.0, -8.0, 3500, 0, 0, false, false, false)
    Citizen.Wait(3500)

    -- Dégeler le PNJ après l'animation
    FreezeEntityPosition(ped, false)
end

function DoKidnapAnimation(ped)
    if not ped or not DoesEntityExist(ped) then return end

    local playerPed = PlayerPedId()

    -- Arrêter le PNJ pour qu'il se déplace vers le joueur
    ClearPedTasks(ped)
    SetEntityInvincible(ped, true)

    -- Le PNJ vient devant le joueur, dos à lui, puis le joueur joue l'animation
    PlayTieAnimation(ped)

    -- Bloquer les événements seulement après le positionnement
    SetBlockingOfNonTemporaryEvents(ped, true)

    -- Animation du joueur terminée, maintenant le PNJ est ligoté
    tiedUpPeds[ped] = true

    -- Le PNJ suit le joueur avec l'animation ligotée
    TaskFollowToOffsetOfEntity(ped, playerPed, 0.0, -1.5, 0.0, 1.0, -1, 1.5, true)

    -- flag 49 = loop + upper body, pour que l'anim des bras se joue pendant la marche
    TaskPlayAnim(ped, "mp_arresting", "idle", 8.0, -8.0, -1, 49, 0, false, false, false)

    -- Thread pour gerer le suivi, l'animation et les vehicules
    Citizen.CreateThread(function()
        local wasPlayerInVehicle = false

        while DoesEntityExist(ped) and tiedUpPeds[ped] do
            Citizen.Wait(500)

            -- Si le PNJ est assis, ne pas gerer le suivi ni les vehicules
            if seatedPeds[ped] then
                goto continue
            end

            local isPlayerInVehicle = IsPedInAnyVehicle(playerPed, false)

            -- Le joueur vient de monter en voiture
            if isPlayerInVehicle and not wasPlayerInVehicle then
                local vehicle = GetVehiclePedIsIn(playerPed, false)
                if vehicle and vehicle ~= 0 then
                    -- Trouver une place libre (passager arriere en priorite)
                    local seat = GetFreeSeat(vehicle)
                    if seat then
                        -- Lancer l'entree en voiture (sans ClearPedTasks pour garder l'anim ligote)
                        TaskEnterVehicle(ped, vehicle, -1, seat, 1.0, 1, 0)
                        -- Forcer l'animation ligotée upper body par-dessus l'anim d'entrée
                        Citizen.Wait(100)
                        TaskPlayAnim(ped, "mp_arresting", "idle", 8.0, -8.0, -1, 49, 0, false, false, false)
                    end
                end
            end

            -- Le joueur vient de sortir de la voiture
            if not isPlayerInVehicle and wasPlayerInVehicle then
                if IsPedInAnyVehicle(ped, false) then
                    local pedVeh = GetVehiclePedIsIn(ped, false)
                    TaskLeaveVehicle(ped, pedVeh, 0)
                    -- Forcer l'animation ligotée pendant la sortie du véhicule
                    TaskPlayAnim(ped, "mp_arresting", "idle", 8.0, -8.0, -1, 49, 0, false, false, false)
                    Citizen.Wait(2000)
                end

                -- Reprendre le suivi a pied avec l'animation
                if DoesEntityExist(ped) and tiedUpPeds[ped] then
                    TaskFollowToOffsetOfEntity(ped, playerPed, 0.0, -1.5, 0.0, 1.0, -1, 1.5, true)
                    TaskPlayAnim(ped, "mp_arresting", "idle", 8.0, -8.0, -1, 49, 0, false, false, false)
                end
            end

            wasPlayerInVehicle = isPlayerInVehicle

            -- Re-forcer l'anim ligotée en permanence (à pied ou en véhicule)
            if not IsEntityPlayingAnim(ped, "mp_arresting", "idle", 3) then
                TaskPlayAnim(ped, "mp_arresting", "idle", 8.0, -8.0, -1, 49, 0, false, false, false)
            end

            -- Quand a pied, re-forcer le suivi si besoin
            if not isPlayerInVehicle and not IsPedInAnyVehicle(ped, false) then
                local dist = #(GetEntityCoords(ped) - GetEntityCoords(playerPed))
                if dist > 10.0 then
                    TaskFollowToOffsetOfEntity(ped, playerPed, 0.0, -1.5, 0.0, 1.0, -1, 1.5, true)
                end
            end

            ::continue::
        end
    end)

    talkingToPed = nil
end

-- Trouver un siege libre dans le vehicule (arriere en priorite)
function GetFreeSeat(vehicle)
    local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
    -- Essayer les sieges arriere d'abord (1, 2)
    for i = 1, maxSeats - 1 do
        if IsVehicleSeatFree(vehicle, i) then
            return i
        end
    end
    -- Sinon le siege passager avant (0)
    if IsVehicleSeatFree(vehicle, 0) then
        return 0
    end
    return nil
end

function DoUntieAnimation(ped)
    if not ped or not DoesEntityExist(ped) then return end

    local playerPed = PlayerPedId()
    local wasSeated = seatedPeds[ped] == true

    -- Si le PNJ est dans un vehicule, le faire sortir d'abord
    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 0)
        Citizen.Wait(2000)
    end

    -- Si le PNJ était assis, le relever d'abord
    if wasSeated then
        seatedPeds[ped] = nil
        FreezeEntityPosition(ped, false)

        RequestAnimDict("random@arrests")
        while not HasAnimDictLoaded("random@arrests") do
            Citizen.Wait(10)
        end

        ClearPedTasks(ped)
        TaskPlayAnim(ped, "random@arrests", "kneeling_arrest_get_up", 8.0, -8.0, -1, 0, 0, false, false, false)
        TaskPlayAnim(ped, "mp_arresting", "idle", 8.0, -8.0, -1, 49, 0, false, false, false)
        Citizen.Wait(3000)
    end

    -- Le PNJ vient devant le joueur, dos à lui, puis le joueur joue l'animation
    PlayTieAnimation(ped)

    -- Animation terminée, maintenant déligoter le PNJ
    tiedUpPeds[ped] = nil
    seatedPeds[ped] = nil

    -- Dégeler au cas où
    FreezeEntityPosition(ped, false)

    -- Annuler toutes les tâches principales
    ClearPedTasks(ped)

    -- Stopper l'animation upper body (mp_arresting) via le native STOP_ANIM_TASK
    Citizen.InvokeNative(0x97FF36A1D40EA00A, ped, "mp_arresting", "idle", -4.0)

    -- Nettoyer les tâches secondaires (animations upper body overlay)
    ClearPedSecondaryTask(ped)

    SetEntityInvincible(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, false)

    -- Attendre que les threads de surveillance se terminent
    Citizen.Wait(600)

    -- Re-clear tout au cas où un thread aurait ré-appliqué une anim
    if DoesEntityExist(ped) then
        ClearPedTasks(ped)
        Citizen.InvokeNative(0x97FF36A1D40EA00A, ped, "mp_arresting", "idle", -4.0)
        ClearPedSecondaryTask(ped)
        TaskWanderStandard(ped, 10.0, 10)
    end

    talkingToPed = nil
end

-- ═══════════════════════════════════════════
--  ASSIS-TOI ICI : Le PNJ s'assoit au sol, ligoté
-- ═══════════════════════════════════════════

function DoSitDownAnimation(ped)
    if not ped or not DoesEntityExist(ped) then return end

    -- Marquer le PNJ comme assis
    seatedPeds[ped] = true

    -- Arreter le suivi
    ClearPedTasks(ped)

    -- Geler le PNJ sur place
    FreezeEntityPosition(ped, true)

    -- Charger le dictionnaire d'animation assise au sol
    RequestAnimDict("random@arrests@busted")
    while not HasAnimDictLoaded("random@arrests@busted") do
        Citizen.Wait(10)
    end

    -- Jouer l'animation assise au sol (full body, loop)
    TaskPlayAnim(ped, "random@arrests@busted", "idle_a", 8.0, -8.0, -1, 1, 0, false, false, false)

    Citizen.Wait(200)

    -- Superposer l'animation ligotée (upper body, loop) par-dessus
    TaskPlayAnim(ped, "mp_arresting", "idle", 8.0, -8.0, -1, 49, 0, false, false, false)

    -- Thread pour maintenir les deux animations en permanence
    Citizen.CreateThread(function()
        while DoesEntityExist(ped) and seatedPeds[ped] do
            Citizen.Wait(500)

            -- Re-forcer l'anim assise si elle se perd
            if not IsEntityPlayingAnim(ped, "random@arrests@busted", "idle_a", 3) then
                TaskPlayAnim(ped, "random@arrests@busted", "idle_a", 8.0, -8.0, -1, 1, 0, false, false, false)
                Citizen.Wait(200)
            end

            -- Re-forcer l'anim ligotée upper body
            if not IsEntityPlayingAnim(ped, "mp_arresting", "idle", 3) then
                TaskPlayAnim(ped, "mp_arresting", "idle", 8.0, -8.0, -1, 49, 0, false, false, false)
            end
        end
    end)

    talkingToPed = nil
end

function DoStandUpAnimation(ped)
    if not ped or not DoesEntityExist(ped) then return end

    -- Retirer de la liste des assis
    seatedPeds[ped] = nil

    -- Degeler le PNJ pour qu'il puisse bouger
    FreezeEntityPosition(ped, false)

    -- Charger l'animation de se relever
    RequestAnimDict("random@arrests")
    while not HasAnimDictLoaded("random@arrests") do
        Citizen.Wait(10)
    end

    -- Jouer l'animation pour se relever (full body, une seule fois)
    ClearPedTasks(ped)
    TaskPlayAnim(ped, "random@arrests", "kneeling_arrest_get_up", 8.0, -8.0, -1, 0, 0, false, false, false)

    -- Superposer l'animation ligotée (upper body) pendant qu'il se relève
    Citizen.Wait(100)
    TaskPlayAnim(ped, "mp_arresting", "idle", 8.0, -8.0, -1, 49, 0, false, false, false)

    -- Attendre la fin de l'animation de se relever
    Citizen.Wait(3000)

    -- Reprendre le suivi du joueur avec l'animation ligotée
    if DoesEntityExist(ped) and tiedUpPeds[ped] then
        local playerPed = PlayerPedId()
        ClearPedTasks(ped)
        TaskFollowToOffsetOfEntity(ped, playerPed, 0.0, -1.5, 0.0, 1.0, -1, 1.5, true)
        TaskPlayAnim(ped, "mp_arresting", "idle", 8.0, -8.0, -1, 49, 0, false, false, false)
    end

    talkingToPed = nil
end

-- ═══════════════════════════════════════════
--  PAIEMENT : réponse du serveur
-- ═══════════════════════════════════════════

RegisterNetEvent('go_fast:payMoneyResult')
AddEventHandler('go_fast:payMoneyResult', function(success, purpose)
    if purpose == 'dealer_5000' then
        if success then
            -- Paiement OK -> animation remise des clés, nom révélé en Ghost
            local ped = talkingToPed
            local dealerName = exports['go_fast']:GetDealerRealName()
            SendNUIMessage({
                action      = 'openDialogue',
                pedName     = dealerName,
                dialogue    = "Hmm ok voilà la clé de la voiture, ramène-la à mon gars",
                responses   = {},
                headshotUrl = GetPedHeadshotUrl(talkingToPed),
            })
            Citizen.SetTimeout(2000, function()
                CloseDialogue(false)
                if ped and DoesEntityExist(ped) then
                    PlayGiveKeysAnimation(ped, function()
                        local pedCoords = GetEntityCoords(ped)
                        TriggerEvent('go_fast:startMission', pedCoords.x, pedCoords.y, pedCoords.z)
                    end)
                end
            end)
        else
            -- Pas assez d'argent
            SendNUIMessage({
                action      = 'openDialogue',
                pedName     = '???',
                dialogue    = "T'as même pas les 5000$ sur toi... Reviens quand t'auras le fric.",
                responses   = {},
                headshotUrl = GetPedHeadshotUrl(talkingToPed),
            })
            Citizen.SetTimeout(3000, function()
                CloseDialogue(false)
            end)
        end

    elseif purpose == 'dealer_4000' then
        if success then
            -- Paiement OK -> dealer part en courant, PAS de mission
            local ped = talkingToPed
            CloseDialogue(false)
            if ped and DoesEntityExist(ped) then
                FreezeEntityPosition(ped, false)
                SetEntityInvincible(ped, false)
                SetBlockingOfNonTemporaryEvents(ped, false)
                ClearPedTasks(ped)
                TaskSmartFleePed(ped, PlayerPedId(), 100.0, -1, false, false)
            end
        else
            -- Pas assez d'argent
            SendNUIMessage({
                action      = 'openDialogue',
                pedName     = '???',
                dialogue    = "T'as même pas les 4000$ sur toi... Reviens quand t'auras le fric.",
                responses   = {},
                headshotUrl = GetPedHeadshotUrl(talkingToPed),
            })
            Citizen.SetTimeout(3000, function()
                CloseDialogue(false)
            end)
        end

    elseif purpose == 'receiver_500' then
        if success then
            -- Paiement OK -> animation remise des clés + PNJ donne les clés
            local ped = talkingToPed
            local receiverName = GetReceiverDisplayName()
            SendNUIMessage({
                action      = 'openDialogue',
                pedName     = receiverName,
                dialogue    = "Prends les clés, elle est garée dans le parking en face",
                responses   = {},
                headshotUrl = GetPedHeadshotUrl(talkingToPed),
                isReceiver  = true,
                trust       = exports['go_fast']:GetTrust(),
            })
            Citizen.SetTimeout(2000, function()
                CloseDialogue(false)
                if ped and DoesEntityExist(ped) then
                    PlayGiveKeysAnimation(ped, function()
                        -- Spawn la voiture
                        local carModel = GetHashKey('emperor')
                        RequestModel(carModel)
                        while not HasModelLoaded(carModel) do
                            Citizen.Wait(10)
                        end
                        local car = CreateVehicle(carModel, 477.49, -1569.33, 29.11, 230.10, true, false)
                        SetEntityAsMissionEntity(car, true, true)
                        SetVehicleOnGroundProperly(car)
                        SetVehicleDoorsLocked(car, 1)
                        SetModelAsNoLongerNeeded(carModel)
                        -- Donner la clé du véhicule avec la plaque
                        local plate = GetVehicleNumberPlateText(car)
                        if plate then
                            plate = plate:gsub('%s+', '')
                            TriggerServerEvent('go_fast:giveVehicleKeyForPlate', plate)
                        end
                        -- Le PNJ part faire sa vie
                        FreezeEntityPosition(ped, false)
                        SetEntityInvincible(ped, false)
                        SetBlockingOfNonTemporaryEvents(ped, false)
                        DecorRemove(ped, 'gofast_receiver')
                        ClearPedTasks(ped)
                        TaskWanderStandard(ped, 10.0, 10)
                        SetPedAsNoLongerNeeded(ped)
                    end)
                end
            end)
        else
            -- Pas assez d'argent
            local receiverName = GetReceiverDisplayName()
            SendNUIMessage({
                action      = 'openDialogue',
                pedName     = receiverName,
                dialogue    = "T'as pas les 500$ sur toi... Tant pis, démerde-toi pour rentrer.",
                responses   = {},
                headshotUrl = GetPedHeadshotUrl(talkingToPed),
                isReceiver  = true,
                trust       = exports['go_fast']:GetTrust(),
            })
            Citizen.SetTimeout(3000, function()
                CloseDialogue(false)
                                -- Le PNJ part faire sa vie
                                local ped = talkingToPed
                if ped and DoesEntityExist(ped) then
                    FreezeEntityPosition(ped, false)
                    SetEntityInvincible(ped, false)
                    SetBlockingOfNonTemporaryEvents(ped, false)
                    DecorRemove(ped, 'gofast_receiver')
                    ClearPedTasks(ped)
                    TaskWanderStandard(ped, 10.0, 10)
                    SetPedAsNoLongerNeeded(ped)
                end
            end)
        end
    end
end)

-- ═══════════════════════════════════════════
--  ACTIONS POLICE (via ALT sur joueur)
-- ═══════════════════════════════════════════

function HandlePoliceAction(action)
    local targetId = policeActionTarget

    if action == 'police_cancel' then
        CloseDialogue(false)
        return
    end

    if action == 'police_handcuff' then
        CloseDialogue(false)
        if targetId then
            TriggerServerEvent('police:handcuff', targetId)
        end
        return
    end

    if action == 'police_frisk' then
        CloseDialogue(false)
        if targetId then
            TriggerServerEvent('police:friskPlayer', targetId)
        end
        return
    end

    if action == 'police_escort' then
        CloseDialogue(false)
        if targetId then
            TriggerServerEvent('police:escort', targetId)
        end
        return
    end

    if action == 'police_vehicle' then
        CloseDialogue(false)
        if targetId then
            TriggerServerEvent('police:putInVehicle', targetId)
        end
        return
    end

    if action == 'police_recruit' then
        CloseDialogue(false)
        if targetId then
            TriggerServerEvent('police:recruit', targetId)
        end
        return
    end

    -- ─── Sous-menu amende : choix du montant ──────────────────
    if action == 'police_fine_menu' then
        SendNUIMessage({
            action    = 'openDialogue',
            pedName   = hoveredPlayerName or 'Joueur',
            dialogue  = "Choisissez le montant de l'amende :",
            responses = {
                { label = "$500",    icon = "atm", action = "police_fine_500" },
                { label = "$1 000",  icon = "atm", action = "police_fine_1000" },
                { label = "$2 500",  icon = "atm", action = "police_fine_2500" },
                { label = "$5 000",  icon = "atm", action = "police_fine_5000" },
                { label = "$10 000", icon = "atm", action = "police_fine_10000" },
                { label = "$25 000", icon = "atm", action = "police_fine_25000" },
                { label = "$50 000", icon = "atm", action = "police_fine_50000" },
                { label = "Annuler", icon = "wave", action = "police_cancel" },
            },
            isPlayer = true,
        })
        return
    end

    -- Amendes avec montants prédéfinis
    if string.find(action, '^police_fine_') then
        local amountStr = string.gsub(action, 'police_fine_', '')
        local amount = tonumber(amountStr) or 0
        if amount > 0 and targetId then
            -- Sous-menu raison de l'amende
            SendNUIMessage({
                action    = 'openDialogue',
                pedName   = hoveredPlayerName or 'Joueur',
                dialogue  = "Amende de $" .. amount .. " — Motif :",
                responses = {
                    { label = "Excès de vitesse",         icon = "car",  action = "police_fine_reason_vitesse_" .. amount },
                    { label = "Stationnement interdit",   icon = "car",  action = "police_fine_reason_stationnement_" .. amount },
                    { label = "Conduite dangereuse",      icon = "car",  action = "police_fine_reason_conduite_" .. amount },
                    { label = "Trouble à l'ordre public", icon = "info", action = "police_fine_reason_trouble_" .. amount },
                    { label = "Port d'arme illégal",      icon = "lock", action = "police_fine_reason_arme_" .. amount },
                    { label = "Autre infraction",         icon = "info", action = "police_fine_reason_autre_" .. amount },
                    { label = "Annuler",                  icon = "wave", action = "police_cancel" },
                },
                isPlayer = true,
            })
        end
        return
    end

    -- Amende avec raison
    if string.find(action, '^police_fine_reason_') then
        local parts = string.gsub(action, 'police_fine_reason_', '')
        local reason, amount
        local reasonMap = {
            vitesse        = "Excès de vitesse",
            stationnement  = "Stationnement interdit",
            conduite       = "Conduite dangereuse",
            trouble        = "Trouble à l'ordre public",
            arme           = "Port d'arme illégal",
            autre          = "Autre infraction",
        }
        for key, label in pairs(reasonMap) do
            if string.find(parts, '^' .. key .. '_') then
                reason = label
                amount = tonumber(string.gsub(parts, '^' .. key .. '_', ''))
                break
            end
        end
        if reason and amount and amount > 0 and targetId then
            CloseDialogue(false)
            TriggerServerEvent('police:createFine', targetId, amount, reason)
        end
        return
    end

    -- ─── Sous-menu prison : choix de la durée ─────────────────
    if action == 'police_jail_menu' then
        SendNUIMessage({
            action    = 'openDialogue',
            pedName   = hoveredPlayerName or 'Joueur',
            dialogue  = "Choisissez la durée d'emprisonnement :",
            responses = {
                { label = "5 minutes",  icon = "lock", action = "police_jail_5" },
                { label = "10 minutes", icon = "lock", action = "police_jail_10" },
                { label = "15 minutes", icon = "lock", action = "police_jail_15" },
                { label = "30 minutes", icon = "lock", action = "police_jail_30" },
                { label = "60 minutes", icon = "lock", action = "police_jail_60" },
                { label = "Annuler",    icon = "wave", action = "police_cancel" },
            },
            isPlayer = true,
        })
        return
    end

    -- Prison avec durée prédéfinie
    if string.find(action, '^police_jail_') then
        local minutes = tonumber(string.gsub(action, 'police_jail_', ''))
        if minutes and minutes > 0 and targetId then
            CloseDialogue(false)
            TriggerServerEvent('police:jailPlayer', targetId, minutes)
        end
        return
    end
end

-- ═══════════════════════════════════════════
--  ACTIONS COMMISSARIAT (via ALT sur PNJ station)
-- ═══════════════════════════════════════════

function HandleStationAction(action)
    if action == 'station_bye' then
        CloseDialogue(false)
        return
    end

    if action == 'station_toggle_duty' then
        CloseDialogue(false)
        TriggerServerEvent('police:toggleDuty')
        return
    end

    if action == 'station_check_fines' then
        CloseDialogue(false)
        TriggerServerEvent('police:getMyFines')
        return
    end

    if action == 'station_spikes' then
        CloseDialogue(false)
        TriggerEvent('police:deploySpikeStrip')
        return
    end

    if action == 'station_radar' then
        CloseDialogue(false)
        TriggerEvent('police:toggleRadar')
        return
    end

    if action == 'station_grades' then
        CloseDialogue(false)
        TriggerServerEvent('police:requestGrades')
        return
    end

    if action == 'station_salary' then
        CloseDialogue(false)
        TriggerServerEvent('police:requestGrades')
        return
    end
end
