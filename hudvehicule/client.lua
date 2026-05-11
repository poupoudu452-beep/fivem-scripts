-- ============================================================
--  vehicle_hud | client.lua
--  Compatible avec lc_fuel : le carburant est lu depuis lc_fuel
-- ============================================================

local isInVehicle  = false
local hudVisible   = false

-- ── Engine condition system ───────────────────────────────────
-- On lit GetVehicleBodyHealth (0-1000) pour détecter les dégâts de collision
-- et on normalise en pourcentage (0-100).

-- powerMult  : multiplicateur SetVehicleEnginePowerMultiplier  (1.0 = normal)
-- torqueMult : multiplicateur SetVehicleEngineTorqueMultiplier (1.0 = normal)
-- maxSpeedMs : vitesse max en m/s (200 = ~720 km/h = pas de limite effective)
local ENGINE_STATES = {
    { name = "cyan",     minPct = 85, maxSpeedMs = 200.0, powerMult = 1.00, torqueMult = 1.00 },
    { name = "green",    minPct = 65, maxSpeedMs = 72.2,  powerMult = 0.75, torqueMult = 0.70 },
    { name = "orange",   minPct = 40, maxSpeedMs = 52.8,  powerMult = 0.50, torqueMult = 0.45 },
    { name = "red",      minPct = 15, maxSpeedMs = 30.6,  powerMult = 0.28, torqueMult = 0.22 },
    { name = "critical", minPct = 0,  maxSpeedMs = 13.9,  powerMult = 0.10, torqueMult = 0.08 },
}

local lastEngineState  = {}
local critStallTimer   = {}

-- Variables partagées entre les threads
local currentVeh       = nil
local currentEngState  = nil

local function GetEngineStateFromPct(pct)
    for _, s in ipairs(ENGINE_STATES) do
        if pct >= s.minPct then return s end
    end
    return ENGINE_STATES[#ENGINE_STATES]
end

-- ─────────────────────────────────────────────────────────────

local function SetHudVisible(visible)
    if hudVisible == visible then return end
    hudVisible = visible
    SendNUIMessage({ type = "toggleHUD", visible = visible })
end

local function GetOrInitFuel(veh)
    -- Lire le carburant depuis lc_fuel si disponible
    if GetResourceState('lc_fuel') == 'started' then
        local ok, val = pcall(function()
            return exports['lc_fuel']:GetFuel(veh)
        end)
        if ok and type(val) == 'number' then
            return val
        end
    end
    -- Fallback : carburant natif GTA
    return GetVehicleFuelLevel(veh)
end

-- ══════════════════════════════════════════════════════════════
--  BOUCLE PERFORMANCE : Wait(0) = chaque frame
--  SetVehicleEnginePowerMultiplier et SetVehicleEngineTorqueMultiplier
--  sont réinitialisés par GTA à chaque frame, il FAUT les rappeler
--  à chaque frame pour qu'ils aient un effet.
-- ══════════════════════════════════════════════════════════════
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        if isInVehicle and currentVeh and DoesEntityExist(currentVeh) and currentEngState then
            local ped = PlayerPedId()
            if GetPedInVehicleSeat(currentVeh, -1) == ped then
                -- Appliquer le couple et la puissance chaque frame
                SetVehicleEngineTorqueMultiplier(currentVeh, currentEngState.torqueMult)
                SetVehicleEnginePowerMultiplier(currentVeh, currentEngState.powerMult)

                -- Brider la vitesse max
                SetVehicleMaxSpeed(currentVeh, currentEngState.maxSpeedMs)

                -- Freinage progressif si la vitesse dépasse le plafond
                local speed = GetEntitySpeed(currentVeh)
                if currentEngState.maxSpeedMs < 200.0 and speed > currentEngState.maxSpeedMs then
                    -- Appliquer un frein proportionnel au dépassement
                    local excess = speed - currentEngState.maxSpeedMs
                    local brakeForce = math.min(1.0, excess / 5.0)
                    SetVehicleBrake(currentVeh, true)
                    SetVehicleBrakeLights(currentVeh, false)
                    -- Réduire la vitesse de l'entité directement
                    local heading = GetEntityHeading(currentVeh)
                    local vel = GetEntityVelocity(currentVeh)
                    local factor = currentEngState.maxSpeedMs / speed
                    factor = math.max(factor, 0.92) -- pas trop brusque
                    SetEntityVelocity(currentVeh, vel.x * factor, vel.y * factor, vel.z)
                end
            end
        end
    end
end)

-- ══════════════════════════════════════════════════════════════
--  BOUCLE PRINCIPALE : HUD + fuel + détection véhicule
-- ══════════════════════════════════════════════════════════════
Citizen.CreateThread(function()
    while true do
        local ped       = PlayerPedId()
        local inVehicle = IsPedInAnyVehicle(ped, false)

        if inVehicle and not isInVehicle then
            isInVehicle = true
            SetHudVisible(true)
        elseif not inVehicle and isInVehicle then
            isInVehicle = false
            currentVeh  = nil
            currentEngState = nil
            SetHudVisible(false)
        end

        if isInVehicle then
            local veh      = GetVehiclePedIsIn(ped, false)
            local speed    = GetEntitySpeed(veh)
            local speedKmh = math.floor(speed * 3.6)
            local fuel     = GetOrInitFuel(veh)
            local engineOn = GetIsVehicleEngineRunning(veh)
            local isDriver = (GetPedInVehicleSeat(veh, -1) == ped)

            -- ── SYSTÈME MOTEUR ──────────────────────────────────────
            local bodyHealth = math.max(0.0, math.min(1000.0, GetVehicleBodyHealth(veh)))
            local enginePct  = (bodyHealth / 1000.0) * 100.0

            local eState = GetEngineStateFromPct(enginePct)

            -- Stocker pour la boucle performance (Wait(0))
            if isDriver then
                currentVeh      = veh
                currentEngState = eState
            end

            -- ── Calages aléatoires en état CRITIQUE ─────────────────
            if eState.name == "critical" and engineOn and isDriver then
                critStallTimer[veh] = (critStallTimer[veh] or 0) - 1
                if critStallTimer[veh] <= 0 then
                    if math.random() < 0.45 then
                        SetVehicleEngineOn(veh, false, true, true)
                        SendNUIMessage({ type = "engineStall" })
                        Citizen.Wait(800 + math.random(0, 2200))
                        SetVehicleEngineOn(veh, true, false, true)
                        critStallTimer[veh] = math.random(50, 120)
                    else
                        critStallTimer[veh] = math.random(20, 60)
                    end
                end
            else
                critStallTimer[veh] = critStallTimer[veh] or 0
            end

            -- ── Envoi NUI : moteur ──────────────────────────────────
            SendNUIMessage({
                type        = "updateEngine",
                state       = eState.name,
                pct         = math.floor(enginePct),
            })

            -- ── Alerte panne sèche ──────────────────────────────────
            if fuel <= 0.0 then
                SendNUIMessage({ type = "fuelEmpty" })
            end

            -- Envoi NUI
            SendNUIMessage({ type = "updateSpeed", speed = speedKmh })
            SendNUIMessage({ type = "updateFuel",  fuel  = fuel      })

            Citizen.Wait(50)
        else
            Citizen.Wait(300)
        end
    end
end)

-- ── Nettoyage : remettre les valeurs normales en sortant ─────
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        local ped = PlayerPedId()

        if not IsPedInAnyVehicle(ped, false) and currentVeh and DoesEntityExist(currentVeh) then
            SetVehicleEnginePowerMultiplier(currentVeh, 1.0)
            SetVehicleEngineTorqueMultiplier(currentVeh, 1.0)
            SetVehicleMaxSpeed(currentVeh, 0.0)
            currentVeh      = nil
            currentEngState = nil
        end
    end
end)
