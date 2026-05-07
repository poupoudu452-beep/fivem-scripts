fx_version 'cerulean'
game 'gta5'

name 'pnj_interact'
description 'Third Eye + Dialogue PNJ System (extensible via exports)'
author 'Shuubby'
version '2.0.0'

ui_page 'html/index.html'

shared_scripts {
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
}

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
}
