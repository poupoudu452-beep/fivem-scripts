fx_version 'cerulean'
game 'gta5'

name        'driving_license'
description 'Permis de conduire — Auto-école avec quiz, épreuve pratique, checkpoints au sol et notifications'
author      'Custom'
version     '2.0.0'

dependencies {
    'pnj_interact',
    'inv_system',
}

shared_script 'config.lua'

client_script 'client.lua'
server_script 'server.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}
