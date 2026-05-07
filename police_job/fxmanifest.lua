fx_version 'cerulean'
game 'gta5'

author      'Custom'
description 'Police Job System — Grades, HUD, Recruitment, Frisk, Fines, Salary, Company Bank'
version     '1.0.0'

shared_scripts {
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
    'client/menu.lua',
    'client/frisk.lua',
    'client/actions.lua',
    'client/hud.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/main.lua',
    'server/salary.lua',
    'server/fines.lua',
    'server/company_bank.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
}

dependencies {
    'oxmysql',
    'charCreate',
    'inv_system',
    'pnj_interact',
}
