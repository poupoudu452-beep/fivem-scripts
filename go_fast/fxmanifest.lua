fx_version 'cerulean'
game 'gta5'

name 'go_fast'
description 'Systeme de dealers persistants pour Go Fast'
author 'Devin'
version '1.0.0'

dependencies {
    'vehicle_keys',
    'admin_menu',
    'inv_system',
}

shared_scripts {
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
}
