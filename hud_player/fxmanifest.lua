fx_version 'cerulean'
game 'gta5'

name        'hud_player'
description 'HUD Joueur custom - Vie, Armure, Faim, Soif, Endurance'
author      'Custom'
version     '1.0.0'

lua54 'yes'

shared_scripts {
  'config/config.lua',
}

client_scripts {
  'client/main.lua',
  'client/stats.lua',
  'client/vehicle.lua',
}

server_scripts {
  'server/main.lua',
}

ui_page 'nui/index.html'

files {
  'nui/index.html',
  'nui/style.css',
  'nui/app.js',
}
