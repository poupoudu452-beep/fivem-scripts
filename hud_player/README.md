# hud_player — HUD Joueur FiveM Custom

HUD joueur standalone (sans ESX ni QBCore) dans le style du HUD véhicule Orbitron/violet-cyan.

## Structure

```
hud_player/
├── fxmanifest.lua
├── config/
│   └── config.lua          ← Tous les réglages ici
├── client/
│   ├── main.lua            ← Toggle HUD, cutscenes, commandes
│   ├── stats.lua           ← HP, Armure, Faim, Soif, Endurance
│   └── vehicle.lua         ← Minimap, cap, coordonnées
├── server/
│   └── main.lua            ← Persistance stats (mémoire)
└── nui/
    ├── index.html
    ├── style.css
    └── app.js
```

## Installation

1. Copier le dossier `hud_player` dans `resources/[custom]/`
2. Ajouter dans `server.cfg` :
   ```
   ensure hud_player
   ```
3. Redémarrer le serveur.

## Commandes

| Commande       | Description                              |
|----------------|------------------------------------------|
| `/hud`         | Afficher / cacher le HUD manuellement    |
| `resetstats <id>` | (Console serveur) Reset stats d'un joueur |

## Comportement

- **Barres de statut** : toujours visibles (bas gauche)
- **Minimap** : cachée à pied, apparaît automatiquement en véhicule
- **HUD natif GTA** : désactivé automatiquement
- **Cutscenes** : HUD masqué automatiquement
- **Faim / Soif** : descendent progressivement, infligent des dégâts si critiques (< 10%)
- **Endurance** : descend au sprint, remonte au repos
- **Clignotement** : toute barre ≤ 20% clignote

## Configuration (config/config.lua)

```lua
Config.TickInterval       = 500    -- ms entre chaque mise à jour
Config.HungerDecay        = 0.05   -- perte de faim par tick
Config.ThirstDecay        = 0.08   -- perte de soif par tick
Config.HungerDamageThreshold = 10  -- seuil dégâts faim
Config.ThirstDamageThreshold = 10  -- seuil dégâts soif
Config.Debug              = false  -- logs console
```

## Intégration avec d'autres ressources

### Depuis un script client

```lua
-- Lire les valeurs
local hunger  = exports['hud_player']:getHunger()
local thirst  = exports['hud_player']:getThirst()
local stamina = exports['hud_player']:getStamina()

-- Modifier les valeurs (ex: item nourriture)
exports['hud_player']:setHunger(hunger + 30)
exports['hud_player']:setThirst(thirst + 20)
```

### Depuis un script client via events

```lua
-- Faire manger le joueur local
TriggerEvent('hud_player:eat', 25.0)
TriggerEvent('hud_player:drink', 25.0)
TriggerEvent('hud_player:heal', 25.0)
```

### Depuis le serveur

```lua
-- Lire les stats d'un joueur
local stats = exports['hud_player']:getPlayerStats(source)

-- Modifier faim/soif d'un joueur (depuis le serveur)
exports['hud_player']:setPlayerHunger(source, 80)
exports['hud_player']:setPlayerThirst(source, 60)

-- Envoyer nourriture/soin à un joueur
TriggerClientEvent('hud_player:eat',   source, 25.0)
TriggerClientEvent('hud_player:drink', source, 25.0)
TriggerClientEvent('hud_player:heal',  source, 25.0)
```
