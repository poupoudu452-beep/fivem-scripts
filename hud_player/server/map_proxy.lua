-- ═══════════════════════════════════════════════════════════════
--  hud_player — Server / map_proxy.lua
--
--  FiveM bloque les requêtes HTTP externes depuis le NUI.
--  Ce proxy les fait transiter par le serveur FiveM, qui lui
--  peut contacter tiles.fivem.net sans restriction.
--
--  Route : GET /hud_player/tile?z=2&x=1&y=1
--  → Récupère le tile depuis tiles.fivem.net et le renvoie
-- ═══════════════════════════════════════════════════════════════

local TILE_BASE = 'https://tiles.fivem.net/raster/gtav/satellite/'
local CACHE     = {}   -- cache en mémoire : clé = "z_x_y" → données

SetHttpHandler(function(req, res)
  -- On ne répond qu'aux requêtes /tile
  if not req.path:match('^/tile') then
    res.writeHead(404)
    res.send('Not found')
    return
  end

  -- Parser les paramètres z, x, y
  local z = tonumber(req.query.z) or 2
  local x = tonumber(req.query.x) or 0
  local y = tonumber(req.query.y) or 0

  -- Sécurité : limiter le zoom aux niveaux utilisés (0-3)
  z = math.max(0, math.min(3, z))
  local maxTile = math.pow(2, z) - 1
  x = math.max(0, math.min(maxTile, x))
  y = math.max(0, math.min(maxTile, y))

  local key = z .. '_' .. x .. '_' .. y

  -- Cache hit
  if CACHE[key] then
    res.writeHead(200, { ['Content-Type'] = 'image/jpeg', ['Cache-Control'] = 'max-age=86400' })
    res.send(CACHE[key])
    return
  end

  -- Requête vers tiles.fivem.net
  local url = TILE_BASE .. z .. '/' .. x .. '/' .. y .. '.jpg'

  PerformHttpRequest(url, function(status, body, headers)
    if status == 200 and body then
      CACHE[key] = body
      res.writeHead(200, {
        ['Content-Type']  = 'image/jpeg',
        ['Cache-Control'] = 'max-age=86400',
      })
      res.send(body)
    else
      -- Tile vide en cas d'erreur
      res.writeHead(404)
      res.send('')
    end
  end, 'GET', '', { ['Accept'] = 'image/jpeg' })
end)
