fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'tsivtools'
description 'A set of tools useful for anticheat and generic actions'
author 'Tsivolakos :)   discord username: tsivolass'
version '0.2'

shared_scripts {
    'config.lua',
    'shared/util.lua',
}

client_scripts {
    'client/menu.lua',
    'client/logger.lua',
    'client/actions.lua',
    'client/anticheat.lua',
    'client/main.lua',
}

ui_page 'ui/input.html'

files {
    'ui/input.html',
    'ui/input.css',
    'ui/input.js',
}

server_scripts {
    'server/storage.lua',
    'server/core.lua',
    'server/discord.lua',
    'server/logs.lua',
    'server/bans.lua',
    'server/player_records.lua',
    'server/garage.lua',
    'server/actions.lua',
    'server/anticheat.lua',
}

dependencies {
    '/server:5848',
    '/onesync',
}
