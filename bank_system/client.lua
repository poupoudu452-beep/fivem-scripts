-- ============================================================
--  BANK SYSTEM — CLIENT
-- ============================================================

local isOpen = false

-- ─── Positions des comptoirs de banque ────────────────────────────────────
local BANK_LOCATIONS = {
    vector3(149.26,   -1040.90, 29.37),  -- Pillbox Hill (Legion Square)
    vector3(314.19,   -278.62,  54.17),  -- Alta
    vector3(-351.53,  -49.53,   49.04),  -- Burton
    vector3(-1212.98, -330.76,  37.79),  -- Rockford Hills
    vector3(-2962.58, 482.63,   15.70),  -- Great Ocean Highway
    vector3(1175.07,  2706.44,  38.09),  -- Route 68
    vector3(247.03,   223.78,   106.29), -- Vinewood
    vector3(-113.22,  6469.29,  31.63),  -- Paleto Bay
}

local INTERACT_DIST = 2.5

-- ─── Prompt "E" et ouverture ──────────────────────────────────────────────
CreateThread(function()
    while true do
        Citizen.Wait(0)
        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local nearest = nil
        local minDist = INTERACT_DIST + 1

        for _, loc in ipairs(BANK_LOCATIONS) do
            local dist = #(coords - loc)
            if dist < minDist then
                minDist = dist
                nearest = loc
            end
        end

        if nearest and minDist <= INTERACT_DIST then
            SetTextFont(4)
            SetTextScale(0.0, 0.35)
            SetTextColour(255, 255, 255, 240)
            SetTextDropshadow(1, 0, 0, 0, 200)
            SetTextOutline()
            SetTextCentre(true)
            SetTextEntry('STRING')
            AddTextComponentString('[E] Acceder a la banque')
            DrawText(0.5, 0.88)

            if IsControlJustReleased(0, 38) and not isOpen then
                OpenBank()
            end
        else
            Citizen.Wait(500)
        end
    end
end)

-- ─── Blips banque sur la carte ────────────────────────────────────────────
CreateThread(function()
    for _, loc in ipairs(BANK_LOCATIONS) do
        local blip = AddBlipForCoord(loc.x, loc.y, loc.z)
        SetBlipSprite(blip, 108)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, 2)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Banque')
        EndTextCommandSetBlipName(blip)
    end
end)

-- ─── Ouvrir la banque ─────────────────────────────────────────────────────
function OpenBank()
    isOpen = true
    SetNuiFocus(true, true)
    TriggerServerEvent('bank:requestData')
    TriggerServerEvent('bank:requestCompanyData')
end

-- ─── Fermer la banque ─────────────────────────────────────────────────────
function CloseBank()
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- ─── Réception des données ────────────────────────────────────────────────
RegisterNetEvent('bank:receiveData')
AddEventHandler('bank:receiveData', function(data)
    if not isOpen then
        isOpen = true
        SetNuiFocus(true, true)
    end
    SendNUIMessage({
        action = 'open',
        data   = data,
    })
end)

-- ─── Réception des données entreprise ───────────────────────────────────────
RegisterNetEvent('bank:receiveCompanyData')
AddEventHandler('bank:receiveCompanyData', function(data)
    SendNUIMessage({
        action      = 'companyData',
        companyData = data,
    })
end)

-- ─── Notification custom à gauche de l'écran ──────────────────────────────
local bankNotif = { active = false, title = '', text = '', notifType = 'error', startTime = 0, duration = 5000 }

local function drawBankNotification()
    local elapsed = GetGameTimer() - bankNotif.startTime
    if elapsed > bankNotif.duration then
        bankNotif.active = false
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
    elseif elapsed > (bankNotif.duration - fadeOut) then
        local t = (elapsed - (bankNotif.duration - fadeOut)) / fadeOut
        alpha = math.floor(255 * (1.0 - t))
    end

    local baseX = 0.01 + offsetX
    local baseY = 0.46
    local boxW  = 0.20
    local boxH  = 0.065

    -- Fond sombre
    DrawRect(baseX + boxW / 2, baseY + boxH / 2, boxW, boxH, 10, 10, 15, math.floor(alpha * 0.88))

    -- Barre colorée à gauche
    local barR, barG, barB = 200, 50, 50
    if bankNotif.notifType == 'success' then
        barR, barG, barB = 34, 197, 94
    end
    DrawRect(baseX + 0.002, baseY + boxH / 2, 0.004, boxH, barR, barG, barB, alpha)

    -- Icône
    SetTextFont(7)
    SetTextScale(0.0, 0.38)
    SetTextColour(barR, barG, barB, alpha)
    SetTextDropshadow(0, 0, 0, 0, 0)
    SetTextEntry('STRING')
    AddTextComponentString('$')
    DrawText(baseX + 0.012, baseY + 0.008)

    -- Titre [Banque]
    SetTextFont(4)
    SetTextScale(0.0, 0.30)
    SetTextColour(barR, barG, barB, alpha)
    SetTextDropshadow(1, 0, 0, 0, math.floor(alpha * 0.5))
    SetTextEntry('STRING')
    AddTextComponentString(bankNotif.title)
    DrawText(baseX + 0.026, baseY + 0.005)

    -- Texte du message
    SetTextFont(4)
    SetTextScale(0.0, 0.26)
    SetTextColour(220, 220, 220, alpha)
    SetTextDropshadow(1, 0, 0, 0, math.floor(alpha * 0.5))
    SetTextEntry('STRING')
    AddTextComponentString(bankNotif.text)
    DrawText(baseX + 0.026, baseY + 0.032)
end

RegisterNetEvent('bank:notify')
AddEventHandler('bank:notify', function(message, notifType)
    bankNotif.active    = true
    bankNotif.title     = '[Banque]'
    bankNotif.text      = message or ''
    bankNotif.notifType = notifType or 'error'
    bankNotif.startTime = GetGameTimer()

    if notifType == 'success' then
        PlaySoundFrontend(-1, 'ROBBERY_MONEY_TOTAL', 'HUD_FRONTEND_CUSTOM_SOUNDSET', false)
    else
        PlaySoundFrontend(-1, 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if bankNotif.active then
            drawBankNotification()
        else
            Citizen.Wait(500)
        end
    end
end)

-- ─── NUI Callbacks ────────────────────────────────────────────────────────
RegisterNUICallback('close', function(data, cb)
    CloseBank()
    cb('ok')
end)

RegisterNUICallback('deposit', function(data, cb)
    local amount = tonumber(data.amount) or 0
    if amount > 0 then
        TriggerServerEvent('bank:deposit', amount)
    end
    cb('ok')
end)

RegisterNUICallback('withdraw', function(data, cb)
    local amount = tonumber(data.amount) or 0
    if amount > 0 then
        TriggerServerEvent('bank:withdraw', amount)
    end
    cb('ok')
end)

RegisterNUICallback('companyDeposit', function(data, cb)
    local amount = tonumber(data.amount) or 0
    if amount > 0 then
        TriggerServerEvent('bank:companyDeposit', amount)
    end
    cb('ok')
end)

RegisterNUICallback('companyWithdraw', function(data, cb)
    local amount = tonumber(data.amount) or 0
    if amount > 0 then
        TriggerServerEvent('bank:companyWithdraw', amount)
    end
    cb('ok')
end)

print('[BankSystem] Client script charge.')
