-- ═══════════════════════════════════════════════════════════════
--  hud_player — Client / stats.lua
--  Gestion : HP, Armure, Faim, Soif, Endurance
-- ═══════════════════════════════════════════════════════════════

local hunger  = Config.StartHunger
local thirst  = Config.StartThirst
local stamina = 100.0

local lastSprint = false

-- ── Utilitaires ──────────────────────────────────────────────
local function Clamp(val, min, max)
  return math.max(min, math.min(max, val))
end

-- GTA encode HP entre 100 (vide) et 200 (plein) pour le ped par défaut
local function GetHealthPercent()
  local ped    = PlayerPedId()
  local health = GetEntityHealth(ped)
  local pct = ((health - Config.MinHealth) / (Config.MaxHealth - Config.MinHealth)) * 100.0
  return Clamp(pct, 0.0, 100.0)
end

local function GetArmourPercent()
  local ped    = PlayerPedId()
  local armour = GetPedArmour(ped)   -- 0-100 natif
  return Clamp(armour, 0.0, 100.0)
end

-- ── Sauvegarde / restauration (serveur) ──────────────────────
local function SaveStats()
  TriggerServerEvent('hud_player:saveStats', {
    hunger  = hunger,
    thirst  = thirst,
    stamina = stamina,
  })
end

-- Récupération au spawn
RegisterNetEvent('hud_player:loadStats', function(data)
  if data then
    hunger  = data.hunger  or Config.StartHunger
    thirst  = data.thirst  or Config.StartThirst
    stamina = data.stamina or 100.0
  end
end)

-- Demander les stats au serveur au spawn
AddEventHandler('playerSpawned', function()
  TriggerServerEvent('hud_player:requestStats')
end)

-- ── Désactiver le système de stamina natif GTA ──────────────
-- On gère notre propre endurance, on empêche GTA de drainer la sienne
Citizen.CreateThread(function()
  while true do
    Citizen.Wait(1000)
    RestorePlayerStamina(PlayerId(), 1.0)
  end
end)

-- ── Bloquer le sprint quand endurance = 0 ───────────────────
-- Ce thread tourne chaque frame UNIQUEMENT quand stamina <= 0
-- pour bloquer l'input sprint (INPUT_SPRINT = 21)
Citizen.CreateThread(function()
  while true do
    if stamina <= 0.0 then
      Citizen.Wait(0)
      DisableControlAction(0, 21, true)
    else
      Citizen.Wait(200)
    end
  end
end)

-- ── Tick principal des stats ─────────────────────────────────
Citizen.CreateThread(function()
  while true do
    Citizen.Wait(Config.TickInterval)

    local ped = PlayerPedId()

    -- ── Faim ────────────────────────────────────────────────
    hunger = Clamp(hunger - Config.HungerDecay, 0.0, 100.0)

    -- ── Soif ────────────────────────────────────────────────
    thirst = Clamp(thirst - Config.ThirstDecay, 0.0, 100.0)

    -- ── Endurance ───────────────────────────────────────────
    local isSprinting = IsPedSprinting(ped) and not IsPedInAnyVehicle(ped, false)
    if isSprinting then
      stamina = Clamp(stamina - Config.StaminaSprintDrain, 0.0, 100.0)
    else
      stamina = Clamp(stamina + Config.StaminaRegenRate, 0.0, 100.0)
    end

    -- ── Dégâts si faim à 0 ──────────────────────────────────
    local inComa = false
    pcall(function()
      inComa = exports['coma_system']:isDead() or exports['coma_system']:isBleedingOut()
    end)

    if not inComa then
      if hunger <= Config.HungerDamageThreshold then
        local hp = GetEntityHealth(ped)
        local dmg = math.floor(Config.HungerDamageAmount)
        SetEntityHealth(ped, math.max(Config.MinHealth, hp - dmg))
      end

      if thirst <= Config.ThirstDamageThreshold then
        local hp = GetEntityHealth(ped)
        local dmg = math.floor(Config.ThirstDamageAmount)
        SetEntityHealth(ped, math.max(Config.MinHealth, hp - dmg))
      end
    end

    -- ── Envoi au NUI ────────────────────────────────────────
    local hp     = inComa and 0.0 or GetHealthPercent()
    local armour = GetArmourPercent()

    SendHUD({ type = 'updateHealth',  health  = hp        })
    SendHUD({ type = 'updateArmour',  armour  = armour    })
    SendHUD({ type = 'updateHunger',  hunger  = hunger    })
    SendHUD({ type = 'updateThirst',  thirst  = thirst    })
    SendHUD({ type = 'updateStamina', stamina = stamina   })

    -- Sauvegarde toutes les 30 ticks (~15s par défaut)
    if math.random(1, 30) == 1 then
      SaveStats()
    end
  end
end)

-- ── Events consommation (manger / boire) ─────────────────────

-- Manger : +valeur à la faim
RegisterNetEvent('hud_player:eat', function(amount)
  hunger = Clamp(hunger + (amount or 25.0), 0.0, 100.0)
  SendHUD({ type = 'updateHunger', hunger = hunger })
end)

-- Boire : +valeur à la soif
RegisterNetEvent('hud_player:drink', function(amount)
  thirst = Clamp(thirst + (amount or 25.0), 0.0, 100.0)
  SendHUD({ type = 'updateThirst', thirst = thirst })
end)

-- Soigner : +HP via objet
RegisterNetEvent('hud_player:heal', function(amount)
  local ped = PlayerPedId()
  local hp  = GetEntityHealth(ped)
  local add = math.floor(((amount or 25.0) / 100.0) * Config.MaxHealth)
  SetEntityHealth(ped, math.min(Config.MaxHealth, hp + add))
end)

-- ── Exports pour autres ressources ───────────────────────────
exports('getHunger',  function() return hunger  end)
exports('getThirst',  function() return thirst  end)
exports('getStamina', function() return stamina end)

exports('setHunger',  function(v) hunger  = Clamp(v, 0, 100) end)
exports('setThirst',  function(v) thirst  = Clamp(v, 0, 100) end)
exports('setStamina', function(v) stamina = Clamp(v, 0, 100) end)
