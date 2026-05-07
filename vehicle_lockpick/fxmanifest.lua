fx_version 'cerulean'
game 'gta5'

name        'vehicle_lockpick'
description 'Vehicules PNJ verrouilles avec mini-jeu de crochetage'
version     '1.0.0'
author      'Devin'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
}

shared_script 'config.lua'
client_script 'client.lua'

server_script 'server.lua'
