--[[----------------------------------
Creation Date:	22/06/2021
]]------------------------------------
fx_version 'cerulean'
game 'gta5'
author 'Leah#0001'
version '1.0.6'
versioncheck 'https://raw.githubusercontent.com/Leah-UK/bixbi_prison/main/fxmanifest.lua'

shared_scripts {
	'@es_extended/imports.lua',
	'config.lua'
}

client_scripts {
	'client/client.lua'
}

server_scripts {
	'server/server.lua'
}

dependencies {
	'bixbi_core'
}
