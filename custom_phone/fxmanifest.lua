fx_version 'cerulean'
game 'gta5'

author      'Custom'
description 'Custom Phone - Telephone RP (Contacts + Messages)'
version     '2.0.0'

dependencies {
    'inv_system',
    'oxmysql',
}

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
}
