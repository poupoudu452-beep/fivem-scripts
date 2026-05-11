-- ═══════════════════════════════════════════════════════════════
--  hud_player — Client / vehicle.lua
--  Détection véhicule uniquement (la carte GTA native gère tout)
-- ═══════════════════════════════════════════════════════════════

local wasInVehicle = false

-- ── Détection véhicule + nom de rue ─────────────────────────
Citizen.CreateThread(function()
  while true do
    Citizen.Wait(Config.VehicleTickInterval)

    local ped       = PlayerPedId()
    local inVehicle = IsPedInAnyVehicle(ped, false)

    if inVehicle ~= wasInVehicle then
      wasInVehicle = inVehicle
      SendHUD({ type = 'toggleVehicle', inVehicle = inVehicle })
    end

    -- Envoyer le nom de rue en véhicule
    if wasInVehicle then
      local coords = GetEntityCoords(ped)
      local hash1, hash2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
      local street = GetStreetNameFromHashKey(hash1)
      if hash2 ~= 0 then
        street = street .. ' / ' .. GetStreetNameFromHashKey(hash2)
      end
      SendHUD({ type = 'updateStreet', street = street })
    end
  end
end)

-- ── Chaque frame : cacher le HUD natif + afficher la carte ──
Citizen.CreateThread(function()
  local minimap = RequestScaleformMovie("minimap")
  SetRadarBigmapEnabled(true, false)
  Wait(0)
  SetRadarBigmapEnabled(false, false)

  while true do
    Citizen.Wait(0)
    DisplayHud(false)
    DisplayRadar(wasInVehicle)

    -- Cacher les barres de vie/armure natives sous la minimap
    BeginScaleformMovieMethod(minimap, "SETUP_HEALTH_ARMOUR")
    ScaleformMovieMethodAddParamInt(3)
    EndScaleformMovieMethod()
  end
end)
