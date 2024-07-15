fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'citRa'
description 'Allows players to grow weed plants to harvest for items to sell'
version '2.0.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'locales/*.lua',
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}