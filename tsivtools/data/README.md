This folder is where tsivtools keeps its data when `Config.Database.enabled`
is `false`:

    bans.json      active and lifted bans
    logs.json      everything the log lookup searches
    garages.json   owned vehicles, when Config.Garage.mode is 'file'
    staff.json     ranks set at runtime through the menu
    settings.json  settings toggled from the menu, such as prop logging

The files are created on first use. They are written a few seconds after a
change and again when the resource stops, so do not edit them while the server
is running - your changes will be overwritten.

To wipe something, stop the server and delete the file.

If a file is ever unreadable it is renamed to `<name>.corrupt.json` and a fresh
one is started, so the old data is still there to look at.
