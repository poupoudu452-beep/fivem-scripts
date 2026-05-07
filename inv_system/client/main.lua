-- client/main.lua

local isOpen     = false
local inventory  = {}
activeVehiclePlate   = nil   -- plaque du vehicule dont le coffre/boite est ouvert (global pour nui.lua)
activeStorageType    = nil   -- 'trunk' ou 'glovebox' (global pour nui.lua)

-- Camera personnage
local invCam     = nil
local pedClone   = nil

-- ─── Désactiver le menu d'arme natif GTA ─────────────────────────────────────
CreateThread(function()
    while true do
        Wait(0)
        -- Désactive la roue d'armes (INPUT_SELECT_WEAPON_UNARMED = 37)
        DisableControlAction(0, 37,  true)  -- Select weapon
        DisableControlAction(0, 157, true)  -- Select weapon (alt)
        DisableControlAction(0, 158, true)  -- Select weapon (alt2)
        DisableControlAction(0, 213, true)  -- Next weapon
        DisableControlAction(0, 214, true)  -- Prev weapon
        DisableControlAction(0, 255, true)  -- Weapon wheel up
        DisableControlAction(0, 256, true)  -- Weapon wheel down
        DisableControlAction(0, 257, true)  -- Weapon wheel left
        DisableControlAction(0, 258, true)  -- Weapon wheel right
    end
end)

-- ─── Gestion ouverture/fermeture TAB ─────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(0)
        -- TAB = control 37 dans le groupe 1 (INPUT_SELECT_WEAPON_UNARMED)
        -- On détecte avec IsDisabledControlJustPressed car on le désactive
        if IsDisabledControlJustPressed(0, 37) then
            ToggleInventory()
        end
    end
end)

function ToggleInventory()
    if isOpen then
        CloseInventory()
    else
        OpenInventory()
    end
end

-- ─── Verifier si un vehicule est verrouille ─────────────────────────────────
local function IsVehicleLocked(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return false end
    local lockStatus = GetVehicleDoorLockStatus(vehicle)
    return lockStatus == 2 or lockStatus == 10
end

-- ─── Detection vehicule : coffre (arriere) ou boite a gants (interieur) ─────
local function GetNearbyTrunkPlate()
    local ped = PlayerPedId()
    local pCoords = GetEntityCoords(ped)
    local vehicle = nil
    local minDist = Config.TrunkDistance or 2.5

    -- Utiliser GetGamePool pour une detection fiable de tous les vehicules
    local vehicles = GetGamePool('CVehicle')
    for _, veh in ipairs(vehicles) do
        if DoesEntityExist(veh) then
            local vCoords = GetEntityCoords(veh)
            local dist = #(pCoords - vCoords)
            if dist < 10.0 then
                -- Utiliser les dimensions du modele pour trouver l'arriere exact
                local model = GetEntityModel(veh)
                local vMin, vMax = GetModelDimensions(model)
                -- vMin.y = arriere du vehicule (negatif), on ajoute un petit offset
                local rearPos = GetOffsetFromEntityInWorldCoords(veh, 0.0, vMin.y - 0.5, 0.0)
                local backDist = #(pCoords - rearPos)
                if backDist < minDist then
                    minDist = backDist
                    vehicle = veh
                end
            end
        end
    end

    if vehicle then
        local plate = string.gsub(GetVehicleNumberPlateText(vehicle), '%s+', '')
        return plate, vehicle
    end
    return nil, nil
end

local function GetGloveboxPlate()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh and veh ~= 0 then
        local plate = string.gsub(GetVehicleNumberPlateText(veh), '%s+', '')
        return plate, veh
    end
    return nil, nil
end

function OpenInventory()
    isOpen = true
    SetNuiFocus(true, true)
    TriggerServerEvent('inv:requestInventory')
    if SendWeaponsToNUI then
        SendWeaponsToNUI()
    end

    -- Detecter coffre ou boite a gants
    local ped = PlayerPedId()
    local inVehicle = GetVehiclePedIsIn(ped, false) ~= 0

    if inVehicle then
        -- Dans un vehicule → boite a gants
        local plate, veh = GetGloveboxPlate()
        if plate then
            if IsVehicleLocked(veh) then
                ShowNotification('~r~Vehicule verrouille !')
            else
                activeVehiclePlate = plate
                activeStorageType  = 'glovebox'
                TriggerServerEvent('inv:openVehicleStorage', plate, 'glovebox')
            end
        end
    else
        -- A pied → verifier si pres d'un coffre
        local plate, veh = GetNearbyTrunkPlate()
        if plate then
            if IsVehicleLocked(veh) then
                ShowNotification('~r~Coffre verrouille !')
            else
                activeVehiclePlate = plate
                activeStorageType  = 'trunk'
                TriggerServerEvent('inv:openVehicleStorage', plate, 'trunk')
            end
        end
    end
end

function CloseInventory()
    isOpen = false
    activeVehiclePlate = nil
    activeStorageType  = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- ─── Camera personnage pour l'inventaire ────────────────────────────────────
function CreateCharacterCamera()
    DestroyCharacterCamera()

    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local pedHeading = GetEntityHeading(ped)

    -- Position de la camera devant le ped
    local angleRad = math.rad(pedHeading + 180.0)
    local camDist = 1.8
    local camX = pedCoords.x + (math.sin(-angleRad) * camDist)
    local camY = pedCoords.y + (math.cos(-angleRad) * camDist)
    local camZ = pedCoords.z + 0.3

    invCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(invCam, camX, camY, camZ)
    PointCamAtCoord(invCam, pedCoords.x, pedCoords.y, pedCoords.z + 0.3)
    SetCamFov(invCam, 35.0)
    SetCamActive(invCam, true)
    RenderScriptCams(true, true, 500, true, false)

    -- Figer le ped
    FreezeEntityPosition(ped, true)
end

function DestroyCharacterCamera()
    if invCam then
        RenderScriptCams(false, true, 500, true, false)
        SetCamActive(invCam, false)
        DestroyCam(invCam, false)
        invCam = nil
    end

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
end


-- ─── Item utilisé (retour serveur) ───────────────────────────────────────────
RegisterNetEvent('inv:itemUsed', function(itemName, slot, remaining)
    -- Met à jour l'inventaire local
    if remaining then
        inventory[slot] = remaining
    else
        inventory[slot] = nil
    end

    -- Fermer l'inventaire si encore ouvert
    if isOpen then
        CloseInventory()
    end

    -- Afficher la notification de l'objet utilisé en bas de l'écran
    local itemDef = Items[itemName]
    if itemDef then
        SendNUIMessage({
            action  = 'showUsedItem',
            itemDef = {
                icon  = itemDef.icon or '📦',
                label = itemDef.label or itemName,
                name  = itemName,
            },
        })
    end

    -- Effets locaux selon la définition de l'item
    if itemDef and itemDef.isFood then
        local amount = itemDef.restoreAmount or 25.0
        if itemDef.foodType == 'drink' then
            TriggerEvent('hud_player:drink', amount)
        elseif itemDef.foodType == 'food' then
            TriggerEvent('hud_player:eat', amount)
        end
    end

    SendNUIMessage({
        action    = 'update',
        inventory = inventory,
        items     = Items,
    })
end)


function ShowNotification(msg)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end

-- ─── Reception inventaire vehicule ──────────────────────────────────────────
RegisterNetEvent('inv:receiveVehicleStorage', function(data)
    if not data then return end
    SendNUIMessage({
        action         = 'updateVehicleStorage',
        plate          = data.plate,
        storageType    = data.storageType,
        vehicleInv     = data.inventory,
        vehMaxSlots    = data.maxSlots,
        vehMaxWeight   = data.maxWeight,
    })
end)

-- ─── Callbacks NUI ───────────────────────────────────────────────────────────
-- Voir client/nui.lua

-- ─── Réception inventaire + sol ───────────────────────────────────────────────
RegisterNetEvent('inv:receiveInventory', function(inv, groundItems)
    inventory = inv
    -- Toujours envoyer au NUI pour que le hotbar reste sync (ammo en temps réel)
    SendNUIMessage({
        action      = isOpen and 'open' or 'update',
        inventory   = inv,
        groundItems = groundItems or {},
        maxSlots    = Config.MaxSlots,
        items       = Items,
    })
end)

-- ─── Munitions rechargées (retour serveur après utilisation d'une boîte) ─────
RegisterNetEvent('inv:ammoReloaded', function(weaponName, ammoAmount, newTotal)
    local weaponDef = Weapons[weaponName]
    if not weaponDef then return end

    local ped = PlayerPedId()

    -- Vérifier si l'arme est équipée via equippedWeaponName (fiable pour slots ET hotbar)
    local isEquipped = (equippedWeaponName == weaponName)

    if isEquipped then
        -- Calculer le nouveau total
        local finalAmmo = newTotal or (equippedRealAmmo + ammoAmount)
        if finalAmmo < 0 then finalAmmo = 0 end

        -- Mettre à jour le suivi local
        equippedRealAmmo = finalAmmo

        -- Sync vers playerWeapons si c'est une arme de slot
        if playerWeapons and equippedCategory then
            local weaponData = playerWeapons[equippedCategory]
            if weaponData and weaponData.weapon == weaponName then
                weaponData.ammo = finalAmmo
            end
        end

        -- Forcer les munitions sur le ped
        SetPedAmmo(ped, weaponDef.hash, finalAmmo)

        -- Animation de rechargement
        MakePedReload(ped)

        -- Sync vers le serveur
        TriggerServerEvent('weapons:updateAmmo', equippedCategory, finalAmmo)

        -- Mise à jour NUI temps réel
        SendNUIMessage({ action = 'updateAmmoDisplay', weaponName = weaponName, ammo = finalAmmo })
    end

    -- Mettre à jour le NUI
    if SendWeaponsToNUI then
        SendWeaponsToNUI()
    end
end)

-- ─── Notification simple ──────────────────────────────────────────────────────
RegisterNetEvent('inv:notify', function(msg)
    ShowNotification('~r~' .. msg)
end)

-- ─── Notification chat (/give feedback) ──────────────────────────────────────
RegisterNetEvent('inv:chatNotify', function(msg)
    TriggerEvent('chat:addMessage', {
        color   = { 255, 255, 255 },
        multiline = true,
        args    = { '[Inventaire]', msg }
    })
end)
