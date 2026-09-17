This folder is where tsivtools keeps its data when `Config.database.enabled`
is `false`:

    bans.json      active and lifted bans
    logs.json      everything the log lookup searches
    garages.json   owned vehicles, when Config.garage.mode is 'file'
    staff.json     ranks set at runtime through the menu
    settings.json  settings toggled from the menu, such as prop logging
    watchlist.json  persistent watchlist entries
    tags.json       player tags
    relationships.json linked player records
    aliases.json    license/name/Steam history
    player_history.json first-seen, join and name history used by Security Center

The files are created on first use. They are written a few seconds after a
change and again when the resource stops, so do not edit them while the server
is running - your changes will be overwritten.

To wipe something, stop the server and delete the file.

If a file is ever unreadable it is renamed to `<name>.corrupt.json` and a fresh
one is started, so the old data is still there to look at.

## MySQL / oxmysql test-server setup

1. Install `oxmysql` and start it before `tsivtools` in `server.cfg`.
2. Add a connection string, for example:
   `set mysql_connection_string "mysql://user:password@127.0.0.1/tsivtools?charset=utf8mb4"`
3. Set `Config.database.enabled = true`. TsivTools creates its tables on startup.
4. Set `Config.garage.mode = 'mysql'` only when the configured ESX garage table
   and columns match the `Config.garage` mapping.

For a real multi-server/global ban, point every server at the same protected
database and keep the same `Config.database.banTable`. The existing ban check
then applies identifiers across those servers. A truly global ban across
unrelated communities requires a shared API/service; do not expose the
database directly to untrusted servers.

## ESX test server

Install a compatible `es_extended` release and its required dependencies,
start `oxmysql` first, then start ESX and finally `tsivtools`. Set
`Config.framework = 'esx'`, configure `Config.frameworkgroupmap`, and grant
the corresponding ACE permissions or staff identifiers. Test on a private
server before connecting production player data.

