-- ============================================================
--  CHARACTER CREATION — CLIENT
-- ============================================================

local charData     = nil
local inCreation   = false
local inAppearance = false

local PED_MODELS = {
    male   = 'mp_m_freemode_01',
    female = 'mp_f_freemode_01',
}

local DEFAULT_SPAWN = { x = -1042.12, y = -2745.86, z = 21.36, h = 0.0 }

local FEATURE_NAMES = {
    'noseWidth', 'nosePeakHeight', 'nosePeakLength', 'noseBoneHeight',
    'nosePeakLower', 'noseBoneTwist', 'eyebrowHeight', 'eyebrowDepth',
    'cheekboneHeight', 'cheekboneWidth', 'cheekWidth', 'eyeOpening',
    'lipThickness', 'jawBoneWidth', 'jawBoneLength', 'chinBoneHeight',
    'chinBoneLength', 'chinBoneWidth', 'chinDimple', 'neckThickness',
}

-- ─── Charger un modele ───────────────────────────────────────────────────
local function loadModel(model)
    RequestModel(model)
    local t = 0
    while not HasModelLoaded(model) and t < 100 do
        Citizen.Wait(50)
        t = t + 1
    end
    return HasModelLoaded(model)
end

-- ─── Appliquer l'apparence complete ──────────────────────────────────────
local function applyAppearance(ped, app)
    if not app or type(app) ~= 'table' then
        SetPedDefaultComponentVariation(ped)
        SetPedHeadBlendData(ped, 0, 0, 0, 0, 0, 0, 0.5, 0.5, 0.0, false)
        return
    end

    SetPedDefaultComponentVariation(ped)

    local h = app.heritage or {}
    SetPedHeadBlendData(ped,
        h.mother or 0, h.father or 0, 0,
        h.mother or 0, h.father or 0, 0,
        (h.shapeMix or 0.5) + 0.0, (h.skinMix or 0.5) + 0.0, 0.0, false)

    local hair = app.hair or {}
    SetPedComponentVariation(ped, 2, hair.style or 0, 0, 2)
    SetPedHairColor(ped, hair.color or 0, hair.highlight or 0)

    local features = app.features or {}
    for i, name in ipairs(FEATURE_NAMES) do
        SetPedFaceFeature(ped, i - 1, (features[name] or 0.0) + 0.0)
    end

    local overlays = app.overlays or {}
    if overlays.beard then
        local b = overlays.beard
        SetPedHeadOverlay(ped, 1, b.style or 255, (b.opacity or 1.0) + 0.0)
        if (b.style or 255) ~= 255 then
            SetPedHeadOverlayColor(ped, 1, 1, b.color or 0, b.color or 0)
        end
    end
    if overlays.eyebrows then
        local e = overlays.eyebrows
        SetPedHeadOverlay(ped, 2, e.style or 255, (e.opacity or 1.0) + 0.0)
        if (e.style or 255) ~= 255 then
            SetPedHeadOverlayColor(ped, 2, 1, e.color or 0, e.color or 0)
        end
    end

    local components = app.components or {}
    for compId, vals in pairs(components) do
        local id = tonumber(compId)
        if id and vals[1] ~= nil and vals[2] ~= nil then
            SetPedComponentVariation(ped, id, vals[1], vals[2], 2)
        end
    end
end

-- ─── Appliquer le skin legacy ────────────────────────────────────────────
local function applySkin(ped, skinData)
    SetPedDefaultComponentVariation(ped)
    if type(skinData) == 'table' then
        for _, comp in ipairs(skinData) do
            if comp[1] and comp[2] and comp[3] then
                SetPedComponentVariation(ped, comp[1], comp[2], comp[3], 2)
            end
        end
    end
    SetPedHeadBlendData(ped, 0, 0, 0, 0, 0, 0, 0.5, 0.5, 0.0, false)
end

-- ─── Max values pour l'editeur d'apparence ───────────────────────────────
local function getAppearanceMaxValues(ped)
    local maxValues = {
        parents       = 46,
        hairStyles    = GetNumberOfPedDrawableVariations(ped, 2),
        hairColors    = GetNumHairColors(),
        beardStyles   = GetNumHeadOverlayValues(1),
        eyebrowStyles = GetNumHeadOverlayValues(2),
        components    = {},
    }
    local compIds = {1, 3, 4, 5, 6, 7, 8, 9, 10, 11}
    for _, id in ipairs(compIds) do
        maxValues.components[tostring(id)] = GetNumberOfPedDrawableVariations(ped, id)
    end
    return maxValues
end

-- ─── Preview ped & camera ────────────────────────────────────────────────
local previewPedHandle = nil
local previewCam       = nil
local currentFov       = 45.0
local currentCamMode   = 'body'

local CAM_SETTINGS = {
    face = { offY = -1.2, offZ = 0.7,  lookZ = 0.65, fov = 30.0, minFov = 15.0, maxFov = 50.0 },
    body = { offY = -2.8, offZ = 0.4,  lookZ = 0.30, fov = 45.0, minFov = 20.0, maxFov = 70.0 },
}

local function setupCamera(mode)
    local coords = vector3(DEFAULT_SPAWN.x, DEFAULT_SPAWN.y, DEFAULT_SPAWN.z)
    if previewCam then DestroyCam(previewCam, false) end
    previewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)

    currentCamMode = mode or 'body'
    local s = CAM_SETTINGS[currentCamMode] or CAM_SETTINGS.body
    currentFov = s.fov

    SetCamCoord(previewCam, coords.x, coords.y + s.offY, coords.z + s.offZ)
    PointCamAtCoord(previewCam, coords.x, coords.y, coords.z + s.lookZ)
    SetCamFov(previewCam, currentFov)

    RenderScriptCams(true, true, 800, true, false)
end

local function spawnPreviewPed(gender, coords)
    if previewPedHandle and DoesEntityExist(previewPedHandle) then
        DeleteEntity(previewPedHandle)
        previewPedHandle = nil
    end

    local model = GetHashKey(PED_MODELS[gender] or PED_MODELS.male)
    if not loadModel(model) then return end

    local c = coords or vector3(DEFAULT_SPAWN.x, DEFAULT_SPAWN.y, DEFAULT_SPAWN.z)
    previewPedHandle = CreatePed(4, model, c.x, c.y, c.z, 180.0, false, false)
    Citizen.Wait(100)
    SetEntityVisible(previewPedHandle, true, false)
    FreezeEntityPosition(previewPedHandle, true)
    SetEntityInvincible(previewPedHandle, true)
    SetBlockingOfNonTemporaryEvents(previewPedHandle, true)
    SetPedDefaultComponentVariation(previewPedHandle)
    SetPedHeadBlendData(previewPedHandle, 0, 0, 0, 0, 0, 0, 0.5, 0.5, 0.0, false)
    TaskStartScenarioInPlace(previewPedHandle, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
    SetModelAsNoLongerNeeded(model)
end

local function cleanupPreview()
    if previewPedHandle and DoesEntityExist(previewPedHandle) then
        DeleteEntity(previewPedHandle)
        previewPedHandle = nil
    end
    if previewCam then
        RenderScriptCams(false, true, 800, true, false)
        DestroyCam(previewCam, false)
        previewCam = nil
    end
end

-- ─── Au demarrage ────────────────────────────────────────────────────────
AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    DisplayHud(false)
    DisplayRadar(false)
    DoScreenFadeOut(0)
    Citizen.SetTimeout(1500, function()
        TriggerServerEvent('charCreate:checkCharacter')
    end)
end)

-- ─── Afficher la creation (pas de personnage) ────────────────────────────
RegisterNetEvent('charCreate:showCreation')
AddEventHandler('charCreate:showCreation', function()
    inCreation = true
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    spawnPreviewPed('male', vector3(DEFAULT_SPAWN.x, DEFAULT_SPAWN.y, DEFAULT_SPAWN.z))
    setupCamera('body')
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'show' })
    DoScreenFadeIn(1000)
    DisplayHud(false)
    DisplayRadar(false)
end)

-- ─── Afficher la selection (personnage existant) ─────────────────────────
RegisterNetEvent('charCreate:showSelection')
AddEventHandler('charCreate:showSelection', function(data)
    inCreation = false
    charData = data

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)

    spawnPreviewPed(data.gender or 'male', vector3(DEFAULT_SPAWN.x, DEFAULT_SPAWN.y, DEFAULT_SPAWN.z))
    Citizen.Wait(200)

    if previewPedHandle and DoesEntityExist(previewPedHandle) then
        if data.appearance then
            applyAppearance(previewPedHandle, data.appearance)
        elseif data.skin then
            applySkin(previewPedHandle, data.skin)
        end
    end

    setupCamera('body')
    SetNuiFocus(true, true)
    SendNUIMessage({
        type      = 'showSelection',
        firstname = data.firstname,
        lastname  = data.lastname,
        gender    = data.gender,
        age       = data.age,
    })
    DoScreenFadeIn(1000)
    DisplayHud(false)
    DisplayRadar(false)
end)

-- ─── Personnage cree → ouvrir editeur d'apparence ───────────────────────
RegisterNetEvent('charCreate:characterCreated')
AddEventHandler('charCreate:characterCreated', function(data)
    inCreation   = false
    inAppearance = true
    charData     = data

    DoScreenFadeOut(500)
    Citizen.Wait(600)
    cleanupPreview()

    local gender    = data.gender or 'male'
    local modelHash = GetHashKey(PED_MODELS[gender] or PED_MODELS.male)
    if loadModel(modelHash) then
        SetPlayerModel(PlayerId(), modelHash)
        SetModelAsNoLongerNeeded(modelHash)
    end

    Citizen.Wait(500)
    local ped = PlayerPedId()
    local timeout = 0
    while not DoesEntityExist(ped) and timeout < 50 do
        Citizen.Wait(100)
        ped = PlayerPedId()
        timeout = timeout + 1
    end

    SetPedDefaultComponentVariation(ped)
    SetPedHeadBlendData(ped, 0, 0, 0, 0, 0, 0, 0.5, 0.5, 0.0, false)

    local x, y, z = DEFAULT_SPAWN.x, DEFAULT_SPAWN.y, DEFAULT_SPAWN.z
    RequestCollisionAtCoord(x, y, z)
    local ct = 0
    while not HasCollisionLoadedAroundEntity(ped) and ct < 30 do
        Citizen.Wait(100)
        ct = ct + 1
    end

    SetEntityCoords(ped, x, y, z, false, false, false, true)
    SetEntityHeading(ped, 180.0)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, true, false)

    setupCamera('body')
    DoScreenFadeIn(1000)

    Citizen.Wait(300)
    ped = PlayerPedId()
    local maxValues = getAppearanceMaxValues(ped)

    SendNUIMessage({
        type      = 'showAppearance',
        gender    = gender,
        maxValues = maxValues,
    })
end)

-- ─── Apparence sauvegardee ───────────────────────────────────────────────
RegisterNetEvent('charCreate:appearanceSaved')
AddEventHandler('charCreate:appearanceSaved', function()
    inAppearance = false
    cleanupPreview()

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'hide' })
    DisplayHud(true)
    DisplayRadar(true)
end)

-- ─── Erreur serveur ─────────────────────────────────────────────────────
RegisterNetEvent('charCreate:error')
AddEventHandler('charCreate:error', function(msg)
    SendNUIMessage({ type = 'error', message = msg })
end)

-- ─── NUI Callbacks ──────────────────────────────────────────────────────
RegisterNUICallback('createCharacter', function(data, cb)
    TriggerServerEvent('charCreate:saveCharacter', data)
    cb('ok')
end)

RegisterNUICallback('previewGender', function(data, cb)
    spawnPreviewPed(data.gender, vector3(DEFAULT_SPAWN.x, DEFAULT_SPAWN.y, DEFAULT_SPAWN.z))
    cb('ok')
end)

RegisterNUICallback('closeNui', function(data, cb)
    cb('blocked')
end)

-- Preview apparence en temps reel
RegisterNUICallback('updateAppearance', function(data, cb)
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then cb(json.encode({ok = false})) return end

    local cat = data.category

    if cat == 'heritage' then
        SetPedHeadBlendData(ped,
            data.mother or 0, data.father or 0, 0,
            data.mother or 0, data.father or 0, 0,
            (data.shapeMix or 0.5) + 0.0, (data.skinMix or 0.5) + 0.0, 0.0, false)

    elseif cat == 'hair' then
        SetPedComponentVariation(ped, 2, data.style or 0, 0, 2)
        SetPedHairColor(ped, data.color or 0, data.highlight or 0)

    elseif cat == 'feature' then
        if data.index ~= nil then
            SetPedFaceFeature(ped, data.index, (data.value or 0.0) + 0.0)
        end

    elseif cat == 'overlay' then
        local oid = data.overlayId
        SetPedHeadOverlay(ped, oid, data.style or 255, (data.opacity or 1.0) + 0.0)
        if (data.style or 255) ~= 255 then
            SetPedHeadOverlayColor(ped, oid, 1, data.color or 0, data.color or 0)
        end

    elseif cat == 'component' then
        local cid = data.componentId
        local dr  = data.drawable or 0
        local tx  = data.texture  or 0
        SetPedComponentVariation(ped, cid, dr, tx, 2)
        local maxTx = GetNumberOfPedTextureVariations(ped, cid, dr)
        cb(json.encode({ok = true, maxTexture = maxTx}))
        return
    end

    cb(json.encode({ok = true}))
end)

-- Changer la camera (face / body)
RegisterNUICallback('switchCamera', function(data, cb)
    setupCamera(data.mode or 'body')
    cb('ok')
end)

-- Zoom camera (molette)
RegisterNUICallback('zoomCamera', function(data, cb)
    if not previewCam then cb('ok') return end
    local s = CAM_SETTINGS[currentCamMode] or CAM_SETTINGS.body
    local delta = (data.delta or 0) * 2.0
    currentFov = math.max(s.minFov, math.min(s.maxFov, currentFov + delta))
    SetCamFov(previewCam, currentFov)
    cb('ok')
end)

-- Tourner le ped
RegisterNUICallback('rotatePed', function(data, cb)
    local ped = PlayerPedId()
    local cur = GetEntityHeading(ped)
    SetEntityHeading(ped, (cur + (data.angle or 0)) % 360.0)
    cb('ok')
end)

-- Sauvegarder l'apparence
RegisterNUICallback('saveAppearance', function(data, cb)
    TriggerServerEvent('charCreate:saveAppearance', data)
    cb('ok')
end)

-- Jouer (depuis l'ecran de selection)
RegisterNUICallback('playCharacter', function(data, cb)
    if not charData then cb('error') return end
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'hide' })
    spawnCharacter(charData)
    cb('ok')
end)

-- Legacy : charger personnage directement
RegisterNetEvent('charCreate:loadCharacter')
AddEventHandler('charCreate:loadCharacter', function(data)
    charData   = data
    inCreation = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'hide' })
    spawnCharacter(data)
end)

-- ─── Spawn du vrai personnage ────────────────────────────────────────────
function spawnCharacter(data)
    DoScreenFadeOut(500)
    Citizen.Wait(600)
    cleanupPreview()

    local gender    = data.gender or 'male'
    local modelHash = GetHashKey(PED_MODELS[gender] or PED_MODELS.male)
    if loadModel(modelHash) then
        SetPlayerModel(PlayerId(), modelHash)
        SetModelAsNoLongerNeeded(modelHash)
    end

    Citizen.Wait(500)
    local ped = PlayerPedId()
    local timeout = 0
    while not DoesEntityExist(ped) and timeout < 50 do
        Citizen.Wait(100)
        ped = PlayerPedId()
        timeout = timeout + 1
    end

    if data.appearance then
        applyAppearance(ped, data.appearance)
    elseif data.skin then
        applySkin(ped, data.skin)
    else
        SetPedDefaultComponentVariation(ped)
        SetPedHeadBlendData(ped, 0, 0, 0, 0, 0, 0, 0.5, 0.5, 0.0, false)
    end

    local x = tonumber(data.pos_x) or DEFAULT_SPAWN.x
    local y = tonumber(data.pos_y) or DEFAULT_SPAWN.y
    local z = tonumber(data.pos_z) or DEFAULT_SPAWN.z
    local h = tonumber(data.pos_h) or DEFAULT_SPAWN.h

    if x == 0 and y == 0 and z == 0 then
        x = DEFAULT_SPAWN.x
        y = DEFAULT_SPAWN.y
        z = DEFAULT_SPAWN.z
        h = DEFAULT_SPAWN.h
    end

    RequestCollisionAtCoord(x, y, z)
    local ct = 0
    while not HasCollisionLoadedAroundEntity(ped) and ct < 30 do
        Citizen.Wait(100)
        ct = ct + 1
    end

    SetEntityCoords(ped, x, y, z, false, false, false, true)
    SetEntityHeading(ped, h)
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    DisplayHud(true)
    DisplayRadar(true)
    DoScreenFadeIn(1000)
    charData = data
end

-- ─── Sauvegarde de position toutes les 2 minutes ─────────────────────────
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(120000)
        if charData ~= nil and not inCreation and not inAppearance then
            local ped = PlayerPedId()
            if DoesEntityExist(ped) then
                local pos = GetEntityCoords(ped)
                local h   = GetEntityHeading(ped)
                TriggerServerEvent('charCreate:savePosition', pos.x, pos.y, pos.z, h)
            end
        end
    end
end)

-- ─── Notification custom chômage (gauche de l'écran) ──────────────────────
local govNotif = { active = false, title = '', text = '', startTime = 0, duration = 6000 }

local function drawGovNotification()
    local elapsed = GetGameTimer() - govNotif.startTime
    if elapsed > govNotif.duration then
        govNotif.active = false
        return
    end

    -- Animation slide-in / slide-out
    local alpha = 255
    local offsetX = 0.0
    local fadeIn  = 400
    local fadeOut = 600

    if elapsed < fadeIn then
        local t = elapsed / fadeIn
        offsetX = -0.18 * (1.0 - t)
        alpha = math.floor(255 * t)
    elseif elapsed > (govNotif.duration - fadeOut) then
        local t = (elapsed - (govNotif.duration - fadeOut)) / fadeOut
        alpha = math.floor(255 * (1.0 - t))
    end

    local baseX = 0.01 + offsetX
    local baseY = 0.46
    local boxW  = 0.18
    local boxH  = 0.065

    -- Fond sombre
    DrawRect(baseX + boxW / 2, baseY + boxH / 2, boxW, boxH, 10, 10, 15, math.floor(alpha * 0.85))

    -- Barre rouge à gauche
    DrawRect(baseX + 0.002, baseY + boxH / 2, 0.004, boxH, 200, 50, 50, alpha)

    -- Icône $ dans un cercle
    SetTextFont(7)
    SetTextScale(0.0, 0.40)
    SetTextColour(200, 50, 50, alpha)
    SetTextDropshadow(0, 0, 0, 0, 0)
    SetTextEntry('STRING')
    AddTextComponentString('$')
    DrawText(baseX + 0.012, baseY + 0.008)

    -- Titre [Gouvernement]
    SetTextFont(4)
    SetTextScale(0.0, 0.32)
    SetTextColour(200, 60, 60, alpha)
    SetTextDropshadow(1, 0, 0, 0, math.floor(alpha * 0.5))
    SetTextEntry('STRING')
    AddTextComponentString(govNotif.title)
    DrawText(baseX + 0.028, baseY + 0.005)

    -- Texte du message
    SetTextFont(4)
    SetTextScale(0.0, 0.28)
    SetTextColour(220, 220, 220, alpha)
    SetTextDropshadow(1, 0, 0, 0, math.floor(alpha * 0.5))
    SetTextEntry('STRING')
    AddTextComponentString(govNotif.text)
    DrawText(baseX + 0.028, baseY + 0.032)
end

RegisterNetEvent('charCreate:unemploymentPay')
AddEventHandler('charCreate:unemploymentPay', function(amount, newBank, message)
    if charData then
        charData.bank = newBank
    end
    govNotif.active    = true
    govNotif.title     = '[Gouvernement]'
    govNotif.text      = message or (amount .. '$ verse pour votre chomage')
    govNotif.startTime = GetGameTimer()
    PlaySoundFrontend(-1, 'ROBBERY_MONEY_TOTAL', 'HUD_FRONTEND_CUSTOM_SOUNDSET', false)
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if govNotif.active then
            drawGovNotification()
        else
            Citizen.Wait(500)
        end
    end
end)

-- ─── Recevoir le solde banque ─────────────────────────────────────────────
RegisterNetEvent('charCreate:receiveBank')
AddEventHandler('charCreate:receiveBank', function(bank)
    if charData then
        charData.bank = bank
    end
end)

-- ─── Export ──────────────────────────────────────────────────────────────
exports('getCharacterData', function()
    return charData
end)

print('[CharCreate] Client script charge.')
