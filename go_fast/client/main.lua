local spawnedDealers = {} -- { [id] = pedHandle }
local dealerPaid = false -- le joueur a-t-il déjà payé le dealer ?

-- Enregistrer les décorateurs
DecorRegister('gofast_dealer', 3)   -- 3 = Int (marquer les dealers)
DecorRegister('gofast_receiver', 3) -- 3 = Int (marquer le receveur)

-- ═══════════════════════════════════════════
--  SPAWN / DESPAWN
-- ═══════════════════════════════════════════

function SpawnDealer(dealer, id)
    local model = GetHashKey(Config.DealerModel)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Citizen.Wait(10)
    end

    local ped = CreatePed(4, model, dealer.x, dealer.y, dealer.z, dealer.heading, false, false)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 17, true)
    SetPedCanRagdoll(ped, false)

    -- Marquer comme dealer (pour pnj_interact)
    DecorSetInt(ped, 'gofast_dealer', 1)

    -- Animation idle naturelle
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)

    spawnedDealers[id] = ped
    SetModelAsNoLongerNeeded(model)
end

function DespawnAll()
    for id, ped in pairs(spawnedDealers) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    spawnedDealers = {}
end

-- ═══════════════════════════════════════════
--  EVENTS DU SERVEUR
-- ═══════════════════════════════════════════

RegisterNetEvent('go_fast:spawnAllDealers')
AddEventHandler('go_fast:spawnAllDealers', function(dealers)
    for id, dealer in ipairs(dealers) do
        SpawnDealer(dealer, id)
    end
end)

RegisterNetEvent('go_fast:spawnDealer')
AddEventHandler('go_fast:spawnDealer', function(dealer, id)
    SpawnDealer(dealer, id)
end)

RegisterNetEvent('go_fast:despawnAll')
AddEventHandler('go_fast:despawnAll', function()
    DespawnAll()
end)

-- ═══════════════════════════════════════════
--  SYNC : ATTAQUE DEALER
-- ═══════════════════════════════════════════

RegisterNetEvent('go_fast:dealerAttackSync')
AddEventHandler('go_fast:dealerAttackSync', function(dx, dy, dz, targetServerId)
    -- Trouver le dealer le plus proche des coordonnees
    local dealerPos = vector3(dx, dy, dz)
    local closestPed = nil
    local closestDist = 3.0

    for id, ped in pairs(spawnedDealers) do
        if DoesEntityExist(ped) then
            local pedCoords = GetEntityCoords(ped)
            local dist = #(pedCoords - dealerPos)
            if dist < closestDist then
                closestDist = dist
                closestPed = ped
            end
        end
    end

    if closestPed then
        -- Dégeler et rendre vulnérable
        FreezeEntityPosition(closestPed, false)
        SetEntityInvincible(closestPed, false)
        SetBlockingOfNonTemporaryEvents(closestPed, false)
        SetPedFleeAttributes(closestPed, 0, false)
        SetPedCombatAttributes(closestPed, 46, true)
        SetPedCombatAttributes(closestPed, 5, true)

        -- Donner un pistolet
        local weapon = GetHashKey('WEAPON_PISTOL')
        GiveWeaponToPed(closestPed, weapon, 250, false, true)
        SetCurrentPedWeapon(closestPed, weapon, true)
        SetPedDropsWeaponsWhenDead(closestPed, false)

        -- Attaquer le joueur cible
        local targetPlayer = GetPlayerFromServerId(targetServerId)
        if targetPlayer and targetPlayer ~= -1 then
            local targetPed = GetPlayerPed(targetPlayer)
            if DoesEntityExist(targetPed) then
                TaskCombatPed(closestPed, targetPed, 0, 16)
            end
        end
    end
end)

-- ═══════════════════════════════════════════
--  MISSION GO FAST
-- ═══════════════════════════════════════════

local missionVehicle  = nil
local missionVehiclePlate = nil -- plaque du véhicule de mission (pour les clés)
local missionBlip     = nil
local missionReceiver = nil
local missionActive   = false
local missionBlocked  = false -- bloque les go fast jusqu'au reboot
local missionTimeLeft = 0
local pendingMissionDealerCoords = nil
local currentTrust    = 0 -- confiance actuelle du joueur (0-100)
local missionDriver   = nil -- PNJ conducteur
local driverArrived   = false -- le conducteur est-il arrivé au point ?

function StartGoFastMission(dealerCoords, vehicleSpawnData, drugType, drugAmount)
    print('[go_fast] StartGoFastMission appele, missionActive=' .. tostring(missionActive) .. ' missionBlocked=' .. tostring(missionBlocked))
    if missionActive then return end
    if missionBlocked then
        SetNotificationTextEntry("STRING")
        AddTextComponentString("~r~Tu ne peux plus faire de go fast.")
        DrawNotification(false, true)
        return
    end
    missionActive = true

    -- Choisir un point de livraison aléatoire
    local delivery = Config.DeliveryLocations[math.random(#Config.DeliveryLocations)]

    -- Position de spawn de la voiture
    local spawnX, spawnY, spawnZ, spawnHeading

    if vehicleSpawnData then
        -- Coords précises définies par /setvehiclespawn
        spawnX = vehicleSpawnData.x
        spawnY = vehicleSpawnData.y
        spawnZ = vehicleSpawnData.z
        spawnHeading = vehicleSpawnData.heading or 0.0
    else
        -- Fallback : à côté du dealer
        spawnX = dealerCoords.x + Config.VehicleSpawnDistance
        spawnY = dealerCoords.y
        spawnZ = dealerCoords.z
        spawnHeading = 0.0

        local found, groundZ = GetGroundZFor_3dCoord(spawnX, spawnY, spawnZ + 5.0, false)
        if found then
            spawnZ = groundZ
        end
    end

    -- Spawn la voiture
    local model = GetHashKey(Config.MissionVehicle)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Citizen.Wait(10)
    end

    missionVehicle = CreateVehicle(model, spawnX, spawnY, spawnZ + 0.5, spawnHeading, true, false)
    SetEntityAsMissionEntity(missionVehicle, true, true)
    SetVehicleOnGroundProperly(missionVehicle)
    SetVehicleDoorsLocked(missionVehicle, 2) -- verrouillé pendant que le PNJ conduit
    SetModelAsNoLongerNeeded(model)

    -- Placer la drogue dans le coffre du véhicule (avant que le PNJ conduise)
    local plate = GetVehicleNumberPlateText(missionVehicle)
    if plate then
        plate = plate:gsub('%s+', '')
        missionVehiclePlate = plate

        if drugType and drugAmount and drugAmount > 0 then
            TriggerServerEvent('go_fast:addDrugsToTrunk', plate, drugType, drugAmount)
        end
    end

    -- ═══════════════════════════════════════════
    --  SPAWN DU PNJ CONDUCTEUR
    -- ═══════════════════════════════════════════
    driverArrived = false

    local driverModel = GetHashKey(Config.DriverModel)
    RequestModel(driverModel)
    while not HasModelLoaded(driverModel) do
        Citizen.Wait(10)
    end

    missionDriver = CreatePedInsideVehicle(missionVehicle, 4, driverModel, -1, true, false)
    SetEntityAsMissionEntity(missionDriver, true, true)
    SetBlockingOfNonTemporaryEvents(missionDriver, true)
    SetEntityInvincible(missionDriver, true)
    SetPedCanRagdoll(missionDriver, false)
    SetPedKeepTask(missionDriver, true)
    SetModelAsNoLongerNeeded(driverModel)

    -- Faire conduire le PNJ jusqu'au point configuré
    local dest = Config.DriverDestination
    TaskVehicleDriveToCoordLongrange(
        missionDriver,
        missionVehicle,
        dest.x, dest.y, dest.z,
        Config.DriverSpeed,
        Config.DriverDrivingStyle,
        Config.DriverArrivalDistance
    )

    -- Notification : le PNJ amène la voiture
    SetNotificationTextEntry("STRING")
    AddTextComponentString("~g~Mission Go Fast lancée !~n~~y~Un conducteur amène la voiture...")
    DrawNotification(false, true)

    -- Créer un blip temporaire sur la destination du conducteur
    local driverBlip = AddBlipForCoord(dest.x, dest.y, dest.z)
    SetBlipSprite(driverBlip, 225) -- icône voiture
    SetBlipColour(driverBlip, 5) -- jaune
    SetBlipScale(driverBlip, 0.9)
    SetBlipRoute(driverBlip, true)
    SetBlipRouteColour(driverBlip, 5)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Voiture en route")
    EndTextCommandSetBlipName(driverBlip)

    -- Thread : surveiller l'arrivée du conducteur
    Citizen.CreateThread(function()
        while missionActive and not driverArrived do
            Citizen.Wait(500)

            if not missionDriver or not DoesEntityExist(missionDriver) then
                break
            end
            if not missionVehicle or not DoesEntityExist(missionVehicle) then
                break
            end

            local driverPos = GetEntityCoords(missionDriver)
            local distToDest = #(driverPos - vector3(dest.x, dest.y, dest.z))

            if distToDest <= Config.DriverArrivalDistance then
                driverArrived = true

                -- Arrêter la voiture
                TaskVehicleTempAction(missionDriver, missionVehicle, 1, 3000) -- freiner
                Citizen.Wait(2000)

                -- Le PNJ descend de la voiture
                TaskLeaveVehicle(missionDriver, missionVehicle, 0)
                Citizen.Wait(3000)

                -- Déverrouiller la voiture pour le joueur
                SetVehicleDoorsLocked(missionVehicle, 1)

                -- Donner la clé du véhicule au joueur
                if missionVehiclePlate then
                    TriggerServerEvent('go_fast:giveVehicleKeyForPlate', missionVehiclePlate)
                end

                -- Le PNJ s'enfuit en courant
                SetEntityInvincible(missionDriver, false)
                SetBlockingOfNonTemporaryEvents(missionDriver, false)
                SetPedKeepTask(missionDriver, true)
                TaskSmartFleePed(missionDriver, PlayerPedId(), 200.0, -1, false, false)

                -- Notification : voiture prête
                SetNotificationTextEntry("STRING")
                AddTextComponentString("~g~La voiture est arrivée !~n~~w~Monte dedans et va au point de livraison.")
                DrawNotification(false, true)

                -- Supprimer le blip du conducteur et afficher celui de la livraison
                if driverBlip then
                    RemoveBlip(driverBlip)
                    driverBlip = nil
                end

                -- Placer le waypoint GPS vers le point de livraison
                SetNewWaypoint(delivery.x, delivery.y)

                -- Créer le blip de livraison
                missionBlip = AddBlipForCoord(delivery.x, delivery.y, delivery.z)
                SetBlipSprite(missionBlip, 1)
                SetBlipColour(missionBlip, 1)
                SetBlipScale(missionBlip, 1.0)
                SetBlipRoute(missionBlip, true)
                SetBlipRouteColour(missionBlip, 1)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString("Livraison Go Fast")
                EndTextCommandSetBlipName(missionBlip)

                -- Supprimer le PNJ conducteur après qu'il soit parti
                Citizen.Wait(15000)
                if missionDriver and DoesEntityExist(missionDriver) then
                    DeleteEntity(missionDriver)
                    missionDriver = nil
                end
            end
        end

        -- Nettoyage si mission annulée avant arrivée du conducteur
        if not driverArrived and driverBlip then
            RemoveBlip(driverBlip)
            driverBlip = nil
        end
    end)

    -- Spawn le PNJ receveur (homme d'affaires) au point de livraison
    local recvModel = GetHashKey(Config.ReceiverModel)
    RequestModel(recvModel)
    while not HasModelLoaded(recvModel) do
        Citizen.Wait(10)
    end

    local rc = Config.ReceiverCoords
    local rcZ = rc.z
    local foundGround, groundZ = GetGroundZFor_3dCoord(rc.x, rc.y, rc.z + 5.0, false)
    if foundGround then
        rcZ = groundZ
    end
    missionReceiver = CreatePed(4, recvModel, rc.x, rc.y, rcZ, rc.heading, false, false)
    PlaceObjectOnGroundProperly(missionReceiver)
    SetEntityAsMissionEntity(missionReceiver, true, true)
    SetBlockingOfNonTemporaryEvents(missionReceiver, true)
    SetEntityInvincible(missionReceiver, true)
    FreezeEntityPosition(missionReceiver, true)
    SetPedFleeAttributes(missionReceiver, 0, false)
    SetPedCanRagdoll(missionReceiver, false)
    TaskStartScenarioInPlace(missionReceiver, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
    DecorSetInt(missionReceiver, 'gofast_receiver', 1)
    SetModelAsNoLongerNeeded(recvModel)

    -- Démarrer le timer
    missionTimeLeft = Config.MissionTimer

    -- Afficher le timer NUI
    SendNUIMessage({
        action   = 'showTimer',
        timeLeft = missionTimeLeft,
        total    = Config.MissionTimer,
    })

    -- Thread timer : décompte + mise à jour NUI
    Citizen.CreateThread(function()
        while missionActive and missionTimeLeft > 0 do
            Citizen.Wait(1000)
            if missionActive then
                missionTimeLeft = missionTimeLeft - 1
                SendNUIMessage({
                    action   = 'updateTimer',
                    timeLeft = missionTimeLeft,
                })
            end
        end
        -- Temps écoulé
        if missionActive and missionTimeLeft <= 0 then
            EndGoFastTimeout()
        end
    end)
end

-- Terminer la mission avec succès (appelé depuis pnj_interact via event)
function EndGoFastSuccess()
    if not missionActive then return end
    missionActive = false

    -- Retirer la clé du véhicule de l'inventaire
    if missionVehiclePlate then
        TriggerServerEvent('go_fast:removeVehicleKey', missionVehiclePlate)
        missionVehiclePlate = nil
    end

    -- Cacher le timer NUI
    SendNUIMessage({ action = 'hideTimer' })

    -- Augmenter la confiance
    TriggerServerEvent('go_fast:deliverySuccess')

    SetNotificationTextEntry("STRING")
    AddTextComponentString("~g~Livraison terminée !~n~~w~Le colis a été livré.")
    DrawNotification(false, true)

    -- Supprimer le blip + waypoint
    if missionBlip then
        RemoveBlip(missionBlip)
        missionBlip = nil
    end
    SetWaypointOff()

    -- Le receveur reste sur place (pnj_interact gère le dialogue de suite)
    missionReceiver = nil

    -- Supprimer le PNJ conducteur s'il existe encore
    if missionDriver and DoesEntityExist(missionDriver) then
        DeleteEntity(missionDriver)
        missionDriver = nil
    end

    -- Supprimer la voiture de mission
    if missionVehicle and DoesEntityExist(missionVehicle) then
        DeleteEntity(missionVehicle)
        missionVehicle = nil
    end
end

-- Échouer la mission : temps écoulé
function EndGoFastTimeout()
    if not missionActive then return end
    missionActive = false

    -- Retirer la clé du véhicule de l'inventaire
    if missionVehiclePlate then
        TriggerServerEvent('go_fast:removeVehicleKey', missionVehiclePlate)
        missionVehiclePlate = nil
    end

    -- Cacher le timer NUI
    SendNUIMessage({ action = 'hideTimer' })

    -- Diminuer la confiance
    TriggerServerEvent('go_fast:deliveryFail')

    SetNotificationTextEntry("STRING")
    AddTextComponentString("~r~Temps écoulé !~n~~w~La mission a échoué.")
    DrawNotification(false, true)

    -- Supprimer le blip + waypoint
    if missionBlip then
        RemoveBlip(missionBlip)
        missionBlip = nil
    end
    SetWaypointOff()

    -- Supprimer le receveur
    if missionReceiver and DoesEntityExist(missionReceiver) then
        DeleteEntity(missionReceiver)
        missionReceiver = nil
    end

    -- Supprimer le PNJ conducteur s'il existe encore
    if missionDriver and DoesEntityExist(missionDriver) then
        DeleteEntity(missionDriver)
        missionDriver = nil
    end

    -- Supprimer la voiture
    if missionVehicle and DoesEntityExist(missionVehicle) then
        DeleteEntity(missionVehicle)
        missionVehicle = nil
    end
end

-- Échouer la mission (le joueur a insulté le receveur)
function EndGoFastFail(receiverPed)
    if not missionActive then return end
    missionActive = false
    missionBlocked = true -- plus de go fast jusqu'au reboot

    -- Retirer la clé du véhicule de l'inventaire
    if missionVehiclePlate then
        TriggerServerEvent('go_fast:removeVehicleKey', missionVehiclePlate)
        missionVehiclePlate = nil
    end

    -- Cacher le timer NUI
    SendNUIMessage({ action = 'hideTimer' })

    -- Diminuer la confiance
    TriggerServerEvent('go_fast:deliveryFail')

    SetNotificationTextEntry("STRING")
    AddTextComponentString("~r~Mission échouée !~n~~w~Tu ne peux plus faire de go fast.")
    DrawNotification(false, true)

    -- Supprimer le blip + waypoint
    if missionBlip then
        RemoveBlip(missionBlip)
        missionBlip = nil
    end
    SetWaypointOff()

    -- Supprimer le PNJ conducteur s'il existe encore
    if missionDriver and DoesEntityExist(missionDriver) then
        DeleteEntity(missionDriver)
        missionDriver = nil
    end

    -- Le receveur attaque le joueur
    if receiverPed and DoesEntityExist(receiverPed) then
        FreezeEntityPosition(receiverPed, false)
        SetEntityInvincible(receiverPed, false)
        SetBlockingOfNonTemporaryEvents(receiverPed, false)
        SetPedCombatAttributes(receiverPed, 46, true)
        SetPedCombatAttributes(receiverPed, 5, true)

        local weapon = GetHashKey('WEAPON_PISTOL')
        GiveWeaponToPed(receiverPed, weapon, 250, false, true)
        SetCurrentPedWeapon(receiverPed, weapon, true)
        SetPedDropsWeaponsWhenDead(receiverPed, false)

        TaskCombatPed(receiverPed, PlayerPedId(), 0, 16)
    end
end

-- Events depuis pnj_interact
RegisterNetEvent('go_fast:missionSuccess')
AddEventHandler('go_fast:missionSuccess', function()
    EndGoFastSuccess()
end)

RegisterNetEvent('go_fast:missionFail')
AddEventHandler('go_fast:missionFail', function(pedX, pedY, pedZ)
    -- Trouver le receveur par ses coords
    local receiverPos = vector3(pedX, pedY, pedZ)
    if missionReceiver and DoesEntityExist(missionReceiver) then
        EndGoFastFail(missionReceiver)
    end
end)

-- Event pour lancer la mission depuis pnj_interact
RegisterNetEvent('go_fast:startMission')
AddEventHandler('go_fast:startMission', function(dx, dy, dz)
    -- Demander au serveur les coords de spawn vehicule du dealer
    pendingMissionDealerCoords = vector3(dx, dy, dz)
    TriggerServerEvent('go_fast:getDealerVehicleSpawn', dx, dy, dz)
end)

-- Réponse du serveur avec les coords de spawn véhicule + drogue
RegisterNetEvent('go_fast:startMissionWithSpawn')
AddEventHandler('go_fast:startMissionWithSpawn', function(vehicleSpawnData, drugType, drugAmount)
    if pendingMissionDealerCoords then
        StartGoFastMission(pendingMissionDealerCoords, vehicleSpawnData, drugType, drugAmount)
        pendingMissionDealerCoords = nil
    end
end)

-- ═══════════════════════════════════════════
--  COMMANDES
-- ═══════════════════════════════════════════

-- /spawndealer : place un dealer à la position du joueur
RegisterCommand('spawndealer', function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    local fwd = GetEntityForwardVector(playerPed)

    -- Spawn 2m devant le joueur, face au joueur
    local spawnX = coords.x + fwd.x * 2.0
    local spawnY = coords.y + fwd.y * 2.0
    local dealerHeading = heading + 180.0

    -- Trouver le vrai Z du sol à la position de spawn
    local spawnZ = coords.z
    local found, groundZ = GetGroundZFor_3dCoord(spawnX, spawnY, coords.z + 5.0, false)
    if found then
        spawnZ = groundZ
    end

    TriggerServerEvent('go_fast:addDealer', {
        x = spawnX,
        y = spawnY,
        z = spawnZ,
        heading = dealerHeading,
    })
end, false)

-- /removedealer : supprime le dealer le plus proche (dans un rayon de 5m)
RegisterCommand('removedealer', function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestId = nil
    local closestDist = Config.RemoveDistance

    for id, ped in pairs(spawnedDealers) do
        if DoesEntityExist(ped) then
            local pedCoords = GetEntityCoords(ped)
            local dist = #(playerCoords - pedCoords)
            if dist < closestDist then
                closestDist = dist
                closestId = id
            end
        end
    end

    if closestId then
        TriggerServerEvent('go_fast:removeDealer', closestId)
    else
        TriggerEvent('chatMessage', '', {255, 0, 0}, 'Aucun dealer à proximité (< ' .. Config.RemoveDistance .. 'm)')
    end
end, false)

-- /setvehiclespawn : définir le point de spawn de la voiture pour le dealer le plus proche
RegisterCommand('setvehiclespawn', function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)

    -- Trouver le dealer le plus proche
    local closestId = nil
    local closestDist = 50.0

    for id, ped in pairs(spawnedDealers) do
        if DoesEntityExist(ped) then
            local pedCoords = GetEntityCoords(ped)
            local dist = #(playerCoords - pedCoords)
            if dist < closestDist then
                closestDist = dist
                closestId = id
            end
        end
    end

    if closestId then
        TriggerServerEvent('go_fast:setVehicleSpawn', closestId, {
            x = playerCoords.x,
            y = playerCoords.y,
            z = playerCoords.z,
            heading = heading,
        })
    else
        TriggerEvent('chatMessage', '', {255, 0, 0}, 'Aucun dealer a proximite (< 50m)')
    end
end, false)

-- /getcoords : affiche les coordonnees GPS du joueur dans la console F8
RegisterCommand('getcoords', function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    print(string.format("[getcoords] x = %.2f, y = %.2f, z = %.2f, heading = %.2f", coords.x, coords.y, coords.z, heading))
end, false)

-- ═══════════════════════════════════════════
--  COOLDOWN : refus de mission
-- ═══════════════════════════════════════════

local pendingCooldownCallback = nil

RegisterNetEvent('go_fast:cooldownRefused')
AddEventHandler('go_fast:cooldownRefused', function(mins, secs)
    SetNotificationTextEntry("STRING")
    AddTextComponentString("~r~Cooldown actif !~n~~w~Prochaine mission dans " .. mins .. " min " .. secs .. " sec.")
    DrawNotification(false, true)
end)

-- Résultat du check de cooldown (appelé avant l'animation)
RegisterNetEvent('go_fast:cooldownResult')
AddEventHandler('go_fast:cooldownResult', function(onCooldown, remaining)
    if pendingCooldownCallback then
        pendingCooldownCallback(onCooldown, remaining)
        pendingCooldownCallback = nil
    end
end)

-- Export pour que pnj_interact puisse vérifier le cooldown
exports('CheckCooldown', function(callback)
    pendingCooldownCallback = callback
    TriggerServerEvent('go_fast:checkCooldown')
end)

-- ═══════════════════════════════════════════
--  CONFIANCE : réception de la mise à jour
-- ═══════════════════════════════════════════

RegisterNetEvent('go_fast:updateTrust')
AddEventHandler('go_fast:updateTrust', function(trust)
    currentTrust = trust or 0
end)

-- Export pour que pnj_interact puisse lire la confiance
exports('GetTrust', function()
    return currentTrust
end)

-- Export pour récupérer le seuil de révélation du nom
exports('GetTrustRevealThreshold', function()
    return Config.TrustRevealThreshold
end)

-- Export pour récupérer le nom réel du receveur
exports('GetReceiverRealName', function()
    return Config.ReceiverRealName
end)

-- Export pour récupérer le nom du dealer
exports('GetDealerRealName', function()
    return Config.DealerRealName
end)

-- Export pour récupérer le véhicule de mission (pour vérifier la proximité)
exports('GetMissionVehicle', function()
    return missionVehicle
end)

-- ═══════════════════════════════════════════
--  DEALER PAID : suivi du paiement
-- ═══════════════════════════════════════════

RegisterNetEvent('go_fast:updateDealerPaid')
AddEventHandler('go_fast:updateDealerPaid', function(paid)
    dealerPaid = paid or false
end)

-- Export pour que pnj_interact puisse vérifier si le joueur a déjà payé
exports('HasPaidDealer', function()
    return dealerPaid
end)

-- ═══════════════════════════════════════════
--  RÉCOMPENSE : notification au joueur
-- ═══════════════════════════════════════════

RegisterNetEvent('go_fast:rewardReceived')
AddEventHandler('go_fast:rewardReceived', function(amount)
    SetNotificationTextEntry("STRING")
    AddTextComponentString("~g~+" .. amount .. "$ reçus~w~ pour la livraison !")
    DrawNotification(false, true)
end)

-- ═══════════════════════════════════════════
--  INIT : demander les dealers au serveur
-- ═══════════════════════════════════════════

Citizen.CreateThread(function()
    -- Attendre que le joueur soit chargé
    while not NetworkIsPlayerActive(PlayerId()) do
        Citizen.Wait(500)
    end
    Citizen.Wait(2000)
    TriggerServerEvent('go_fast:requestDealers')
    TriggerServerEvent('go_fast:requestTrust')
    TriggerServerEvent('go_fast:requestDealerPaid')
end)
