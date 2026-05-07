fx_version 'cerulean'
game 'gta5'

name        'Bank System'
description 'Systeme bancaire avec interface NUI'
version     '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
}

client_script 'client.lua'
server_script 'server.lua'

dependencies {
    'oxmysql',
    'charCreate',
    'inv_system',
}
