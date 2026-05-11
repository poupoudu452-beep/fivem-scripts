-- ═══════════════════════════════════════════════════════════════
--  hud_player — Client / main.lua
--  Gestion centrale : affichage NUI, toggle HUD, cutscenes
--  La carte GTA native reste telle quelle (aucune modification)
-- ═══════════════════════════════════════════════════════════════

local hudVisible   = false
local inCutscene   = false

-- ── Utilitaire debug ─────────────────────────────────────────
local function Log(msg)
  if Config.Debug then
    print('^3[hud_player]^7 ' .. tostring(msg))
  end
end

-- ── Envoyer un message NUI ───────────────────────────────────
function SendHUD(data)
  SendNUIMessage(data)
end

-- ── Afficher / Cacher le HUD ─────────────────────────────────
function ToggleHUD(visible)
  hudVisible = visible
  SendHUD({ type = 'toggleHUD', visible = visible })
  Log('HUD ' .. (visible and 'affiché' or 'caché'))
end

-- ── Init au spawn ────────────────────────────────────────────
AddEventHandler('playerSpawned', function()
  Wait(500)
  ToggleHUD(true)
  Log('Spawn détecté — HUD activé')
end)

-- ── Gestion des cutscenes ────────────────────────────────────
if Config.HideInCutscene then
  Citizen.CreateThread(function()
    while true do
      Citizen.Wait(1000)
      local cutscene = IsPlayerSwitchInProgress() or IsCutsceneActive() or IsScreenFadedOut()
      if cutscene and not inCutscene then
        inCutscene = true
        ToggleHUD(false)
      elseif not cutscene and inCutscene then
        inCutscene = false
        ToggleHUD(true)
      end
    end
  end)
end

-- ── Commande debug pour toggle manuel ────────────────────────
RegisterCommand('hud', function()
  ToggleHUD(not hudVisible)
end, false)

-- ── Init au chargement de la ressource ───────────────────────
AddEventHandler('onClientResourceStart', function(resourceName)
  if resourceName == GetCurrentResourceName() then
    Wait(1000)
    ToggleHUD(true)
    Log('Ressource démarrée')
  end
end)
