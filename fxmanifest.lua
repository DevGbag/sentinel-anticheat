fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sentinel_ac'
author 'DevGeorge'
description 'Standalone anticheat + admin menu + item generator (framework-agnostic bridge)'
version '2.0.0'

shared_scripts {
    'config/config.lua',
    'shared/trolls.lua'
}

client_scripts {
    'bridge/bridge_client.lua',
    'bridge/frameworks/standalone_client.lua',
    'bridge/frameworks/esx_client.lua',
    'bridge/frameworks/qbcore_client.lua',
    'bridge/frameworks/qbx_client.lua',
    'bridge/frameworks/ox_client.lua',
    'client/main.lua',
    'client/anticheat.lua',
    'client/trolls.lua',
    'client/menu/nui.lua'
}

server_scripts {
    'bridge/bridge_server.lua',
    'bridge/frameworks/standalone_server.lua',
    'bridge/frameworks/esx_server.lua',
    'bridge/frameworks/qbcore_server.lua',
    'bridge/frameworks/qbx_server.lua',
    'bridge/frameworks/ox_server.lua',
    'server/permissions.lua',
    'server/main.lua',
    'server/logging.lua',
    'server/branding.lua',
    'server/anticheat/handlers.lua',
    'server/anticheat/bans.lua',
    'server/anticheat/connection.lua',
    'server/anticheat/monitor.lua',
    'server/anticheat/gameevents.lua',
    'server/anticheat/clientchecks.lua',
    'server/anticheat/chat.lua',
    'server/anticheat/convars.lua',
    'server/anticheat/screenshots.lua',
    'server/anticheat/trolls.lua',
    'server/menu/callbacks.lua',
    'server/menu/itemgen.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/branding.js'
}
