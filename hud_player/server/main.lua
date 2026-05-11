-- ═══════════════════════════════════════════════════════════════
--  hud_player — Server / main.lua
--  Persistance des stats joueur (en mémoire, pas de base de données)
--  Pour une persistance réelle → remplacer par oxmysql / exports db
-- ═══════════════════════════════════════════════════════════════

local playerStats = {}  -- [source] = { hunger, thirst, stamina }

-- ── Utilitaire debug ─────────────────────────────────────────
local function Log(msg)
  if Config.Debug then
    print('^3[hud_player:server]^7 ' .. tostring(msg))
  end
end

-- ── Joueur connecté : créer entrée avec valeurs par défaut ───
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
  local src = source
  playerStats[src] = {
    hunger  = Config.StartHunger,
    thirst  = Config.StartThirst,
    stamina = 100.0,
  }
  Log('Joueur connecté : ' .. name .. ' (src=' .. src .. ')')
end)

-- ── Joueur déconnecté : nettoyer ─────────────────────────────
AddEventHandler('playerDropped', function(reason)
  local src = source
  playerStats[src] = nil
  Log('Joueur déconnecté (src=' .. src .. ') — raison : ' .. reason)
end)

-- ── Client → Server : sauvegarder les stats ──────────────────
RegisterNetEvent('hud_player:saveStats', function(data)
  local src = source
  if not data then return end
  playerStats[src] = {
    hunger  = data.hunger  or Config.StartHunger,
    thirst  = data.thirst  or Config.StartThirst,
    stamina = data.stamina or 100.0,
  }
  Log('Stats sauvegardées pour src=' .. src)
end)

-- ── Client → Server : demander les stats sauvegardées ────────
RegisterNetEvent('hud_player:requestStats', function()
  local src = source
  local stats = playerStats[src] or {
    hunger  = Config.StartHunger,
    thirst  = Config.StartThirst,
    stamina = 100.0,
  }
  TriggerClientEvent('hud_player:loadStats', src, stats)
  Log('Stats envoyées à src=' .. src)
end)

-- ── Consommation depuis le serveur (items etc.) ──────────────
-- Manger : TriggerClientEvent('hud_player:eat', src, 25.0)
-- Boire  : TriggerClientEvent('hud_player:drink', src, 25.0)
-- Soigner: TriggerClientEvent('hud_player:heal', src, 25.0)

-- ── Commande admin : reset stats d'un joueur ─────────────────
RegisterCommand('resetstats', function(src, args)
  -- Réservé aux admins (src == 0 = console serveur)
  if src ~= 0 then return end
  local target = tonumber(args[1])
  if not target then
    print('[hud_player] Usage : resetstats <id>')
    return
  end
  playerStats[target] = {
    hunger  = Config.StartHunger,
    thirst  = Config.StartThirst,
    stamina = 100.0,
  }
  TriggerClientEvent('hud_player:loadStats', target, playerStats[target])
  print('[hud_player] Stats réinitialisées pour src=' .. target)
end, true)

-- ── Export serveur ───────────────────────────────────────────
exports('getPlayerStats', function(src)
  return playerStats[src]
end)

exports('setPlayerHunger', function(src, val)
  if playerStats[src] then
    playerStats[src].hunger = math.max(0, math.min(100, val))
    TriggerClientEvent('hud_player:eat', src, 0) -- force refresh
  end
end)

exports('setPlayerThirst', function(src, val)
  if playerStats[src] then
    playerStats[src].thirst = math.max(0, math.min(100, val))
    TriggerClientEvent('hud_player:drink', src, 0)
  end
end)
