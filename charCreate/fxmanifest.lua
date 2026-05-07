fx_version 'cerulean'
game 'gta5'

name        'Character Creation'
description 'Système de création de personnage standalone — MySQL/oxmysql'
version     '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'

-- oxmysql doit être démarré AVANT cette ressource dans server.cfg
dependency 'oxmysql'