--[[
    tsivtools - menu assembly and keybind

    The menu is built from the permission set the server sends after spawn. A
    row is only created if the server said this player holds the permission for
    it, so nothing a player is not allowed to use is ever sent to their client.
    The server checks again when the row is used.

    To add a row of your own, look at the builder for the section it belongs in
    and copy the pattern. docs/EXTENDING.md walks through one end to end.
]]

local permissions = nil
local root = nil
local selected = nil          -- the player most menu options act on

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function can(key)
    return permissions ~= nil and permissions.granted[key] == true
end

--- Build a section into its own menu, and only attach it to the root if it
--- ended up with rows. That way a moderator does not see an empty "Garage".
local function section(parent, label, description, builder)
    local menu = TSIV.Menu.Create(label, permissions.rankLabel)
    builder(menu)
    if #menu.items > 0 then
        parent:Attach(label, description, menu)
    end
    return menu
end

local function selectedLabel()
    if not selected then return 'none selected' end
    return ('[%d] %s'):format(selected.id, selected.name)
end

--- Make sure a player is selected before running an action that needs one.
local function requireSelection()
    if selected then return true end
    TSIV.Notify('Pick a player first, with "Select player".', 'error')
    return false
end

--- Ask the server for the player list and show it as a menu.
local function choosePlayer(title, onPick)
    CreateThread(function()
        local players = TSIV.Request('player.list')
        if not players then return end

        local menu = TSIV.Menu.Create(title or 'Select a player', ('%d online'):format(#players))

        menu:Button('Enter a server ID by hand', 'Type the ID instead of picking from the list.', function()
            local id = TSIV.InputNumber('Server ID', '', 6)
            if not id then return end
            onPick({ id = math.floor(id), name = ('id %d'):format(math.floor(id)) })
            TSIV.Menu.Back()
        end)

        for _, player in ipairs(players) do
            local description = ('ping %dms   health %d%s'):format(
                player.ping, player.health,
                player.rankLabel and ('   staff: ' .. player.rankLabel) or '')

            menu:Button(('[%d] %s'):format(player.id, player.name), description, function()
                onPick(player)
                TSIV.Menu.Back()
            end)
        end

        if #players == 0 then
            menu:Label('Nobody online.')
        end

        TSIV.Menu.Push(menu)
    end)
end

--- Radius list rows share this shape in three different places.
local function radiusList(menu, label, description, onPick)
    local values = {}
    for _, radius in ipairs(Config.AreaRadiusOptions) do
        values[#values + 1] = { label = radius .. 'm', value = radius }
    end
    menu:List(label, description, values, function(value)
        onPick(value)
    end)
end

-- ---------------------------------------------------------------------------
-- Section: Self
-- ---------------------------------------------------------------------------

local function buildSelf(menu)
    if can('self.godmode') then
        menu:Checkbox('God mode', 'Take no damage.', TSIV.State.god, function(state)
            TSIV.ToggleGod(state)
        end)
    end

    if can('self.invisible') then
        menu:Checkbox('Invisible', 'Other players stop seeing your ped.', TSIV.State.invisible, function(state)
            TSIV.ToggleInvisible(state)
        end)
    end

    if can('self.noclip') then
        menu:Checkbox('Noclip', 'Fly through the world. WASD to move, Q and E for up and down, Shift for faster.',
            TSIV.State.noclip, function(state)
                TSIV.ToggleNoclip(state)
            end)

        menu:List('Noclip speed', 'How far each step moves you.', {
            { label = 'slow',   value = 0.5 },
            { label = 'normal', value = 1.0 },
            { label = 'fast',   value = 2.5 },
            { label = 'silly',  value = 6.0 },
        }, function(value)
            TSIV.SetNoclipSpeed(value)
            TSIV.Notify(('Noclip speed set to %s.'):format(value), 'info')
        end, function(value)
            TSIV.SetNoclipSpeed(value)
        end)
    end

    if can('self.heal') then
        menu:Button('Heal yourself', 'Full health, and blood damage cleared.', function()
            local ped = PlayerPedId()
            SetEntityHealth(ped, GetEntityMaxHealth(ped))
            ClearPedBloodDamage(ped)
            TSIV.Notify('Healed.', 'success')
        end)
    end

    if can('self.armour') then
        menu:Button('Full armour', 'Sets your armour to 100.', function()
            SetPedArmour(PlayerPedId(), 100)
            TSIV.Notify('Armour restored.', 'success')
        end)
    end

    if can('self.tpmarker') then
        menu:Button('Teleport to your waypoint', 'Set a waypoint on the map first.', function()
            CreateThread(TSIV.TeleportToMarker)
        end)
    end

    if can('self.tpcoords') then
        menu:Button('Teleport to coordinates', 'Type x, y, z separated by spaces or commas.', function()
            CreateThread(function()
                local input = TSIV.Input('Coordinates (x y z)', '', 48)
                if not input then return end

                local x, y, z = input:match('(-?%d+%.?%d*)[%s,]+(-?%d+%.?%d*)[%s,]+(-?%d+%.?%d*)')
                if not x then
                    TSIV.Notify('Could not read those coordinates.', 'error')
                    return
                end

                TSIV.Action('self.teleport', { x = tonumber(x), y = tonumber(y), z = tonumber(z) })
            end)
        end)
    end

    if can('self.tpsaved') and #Config.Teleports > 0 then
        local teleports = TSIV.Menu.Create('Teleports', 'from config.lua')
        for _, entry in ipairs(Config.Teleports) do
            teleports:Button(entry.label, ('%.0f, %.0f, %.0f'):format(entry.coords.x, entry.coords.y, entry.coords.z), function()
                TSIV.Action('self.teleport', {
                    saved = true,
                    x = entry.coords.x, y = entry.coords.y, z = entry.coords.z,
                })
            end)
        end
        menu:Attach('Saved locations', 'The list in Config.Teleports.', teleports)
    end

    menu:Button('Copy your coordinates to F8', 'Prints your position, ready to paste into config.lua.', function()
        local coords = GetEntityCoords(PlayerPedId())
        local heading = GetEntityHeading(PlayerPedId())
        TSIV.PrintBlock('your position', {
            ('vector3(%.2f, %.2f, %.2f)'):format(coords.x, coords.y, coords.z),
            ('heading %.2f'):format(heading),
            ('config line: { label = \'name here\', coords = vector3(%.1f, %.1f, %.1f) },')
                :format(coords.x, coords.y, coords.z),
        })
        TSIV.Notify('Printed to your F8 console.', 'success')
    end)
end

-- ---------------------------------------------------------------------------
-- Section: Players
-- ---------------------------------------------------------------------------

local function buildPlayers(menu)
    if not can('player.list') then return end

    local selectedRow = menu:Button('Select player', 'Pick who the options below act on.', function()
        choosePlayer('Online players', function(player)
            selected = player
            TSIV.Notify(('Selected %s'):format(selectedLabel()), 'success')
        end)
    end)

    -- Keep the row showing who is selected without rebuilding the menu.
    menu.onOpen = function()
        selectedRow.right = selectedLabel()
    end
    selectedRow.right = selectedLabel()

    local function targeted(label, description, permission, action, payload)
        if not can(permission) then return end
        menu:Button(label, description, function()
            if not requireSelection() then return end
            local body = { target = selected.id }
            for key, value in pairs(payload or {}) do body[key] = value end
            TSIV.Action(action, body)
        end)
    end

    targeted('Go to',   'Teleport yourself to them.',    'player.goto',    'player.goto')
    targeted('Bring',   'Teleport them to you.',         'player.bring',   'player.bring')
    targeted('Revive',  'Bring them back and heal them.','player.revive',  'player.revive')
    targeted('Heal',    'Full health and armour.',       'player.heal',    'player.heal')
    targeted('Slay',    'Kill them where they stand.',   'player.slay',    'player.slay')

    if can('player.spectate') then
        menu:Button('Spectate', 'Watch them. Use the row below to come back.', function()
            if not requireSelection() then return end
            TSIV.Action('player.spectate', { target = selected.id })
        end)
        menu:Button('Stop spectating', 'Return to your own body.', function()
            TSIV.StopSpectating()
            TSIV.Action('player.spectate', {})
        end)
    end

    if can('player.freeze') then
        menu:Button('Freeze', 'Lock them in place.', function()
            if not requireSelection() then return end
            TSIV.Action('player.freeze', { target = selected.id, state = true })
        end)
        menu:Button('Unfreeze', 'Let them move again.', function()
            if not requireSelection() then return end
            TSIV.Action('player.freeze', { target = selected.id, state = false })
        end)
    end

    if can('player.warn') then
        menu:Button('Warn', 'Send them a warning in chat.', function()
            if not requireSelection() then return end
            CreateThread(function()
                local reason = TSIV.Input('Warning reason', '', 120)
                if not reason then return end
                TSIV.Action('player.warn', { target = selected.id, reason = reason })
            end)
        end)
    end

    if can('player.kick') then
        menu:Button('Kick', 'Remove them from the server.', function()
            if not requireSelection() then return end
            CreateThread(function()
                local reason = TSIV.Input('Kick reason', '', 120)
                if not reason then return end
                TSIV.Action('player.kick', { target = selected.id, reason = reason })
            end)
        end)
    end

    if can('player.ban') then
        menu:Button('Ban', 'Length in minutes, 0 for permanent.', function()
            if not requireSelection() then return end
            CreateThread(function()
                local minutes = TSIV.InputNumber('Ban length in minutes (0 = permanent)', '0', 8)
                if minutes == nil then return end
                local reason = TSIV.Input('Ban reason', '', 150)
                if not reason then return end
                TSIV.Action('player.ban', { target = selected.id, minutes = minutes, reason = reason })
            end)
        end)
    end

    if can('player.identifiers') then
        menu:Button('Identifiers', 'Prints every identifier they hold to F8.', function()
            if not requireSelection() then return end
            CreateThread(function()
                TSIV.ShowBlock(TSIV.Request('player.identifiers', { target = selected.id }))
            end)
        end)
    end

    if can('player.setrank') then
        -- "Remove rank" sits at the end rather than the start, so pressing
        -- Enter without arrowing first cannot strip somebody's rank by
        -- accident.
        local values = {}
        for _, rank in ipairs(TSIV.Ranks()) do
            values[#values + 1] = { label = rank.label, value = rank.name }
        end
        values[#values + 1] = { label = 'remove rank', value = 'none' }

        menu:List('Set staff rank',
            'Left and right to pick a rank, Enter to apply it. Stored in data/staff.json, so it survives a restart.',
            values, function(value)
                if not requireSelection() then return end
                TSIV.Action('player.setrank', { target = selected.id, rank = value })
            end)
    end

    if can('player.unban') then
        local bans = TSIV.Menu.Create('Active bans', 'select one to lift it')
        bans.onOpen = function()
            CreateThread(function()
                bans:Clear()
                bans:Button('Search by name or identifier', 'Filter the list below.', function()
                    CreateThread(function()
                        local query = TSIV.Input('Search bans', '', 64)
                        if not query then return end
                        bans.query = query
                        bans.onOpen()
                    end)
                end)

                local list = TSIV.Request('bans.list', { query = bans.query })
                if not list or #list == 0 then
                    bans:Label('No active bans.')
                else
                    for _, ban in ipairs(list) do
                        bans:Button(('#%s  %s'):format(ban.id, ban.name ~= '' and ban.name or ban.identifier),
                            ('%s  |  expires %s  |  by %s'):format(ban.reason, ban.expiresText, ban.bannedBy),
                            function()
                                TSIV.Action('player.unban', { banId = ban.id })
                                bans.onOpen()
                            end)
                    end
                end
                TSIV.Menu.Refresh()
            end)
        end
        menu:Attach('Bans', 'Browse and lift active bans.', bans)
    end
end

-- ---------------------------------------------------------------------------
-- Section: Vehicles
-- ---------------------------------------------------------------------------

local function buildVehicles(menu)
    if can('vehicle.spawn') then
        if #Config.VehicleList > 0 then
            local list = TSIV.Menu.Create('Spawn a vehicle', 'from Config.VehicleList')
            for _, entry in ipairs(Config.VehicleList) do
                list:Button(entry.label, entry.model, function()
                    TSIV.Action('vehicle.spawn', { model = entry.model })
                end)
            end
            menu:Attach('Spawn from the list', 'The vehicles in Config.VehicleList.', list)
        end

        menu:Button('Spawn by model name', 'Type any model name the server has.', function()
            CreateThread(function()
                local model = TSIV.Input('Vehicle model name', '', 32)
                if not model then return end
                TSIV.Action('vehicle.spawn', { model = model })
            end)
        end)
    end

    if can('vehicle.repair') then
        menu:Button('Repair', 'Fixes the vehicle you are in or standing next to.', function()
            TSIV.Action('vehicle.repair', {})
        end)
    end

    if can('vehicle.refuel') then
        menu:Button('Refuel', 'Fills the tank to full.', function()
            TSIV.Action('vehicle.refuel', {})
        end)
    end

    if can('vehicle.flip') then
        menu:Button('Flip upright', 'Puts a rolled vehicle back on its wheels.', function()
            TSIV.Action('vehicle.flip', {})
        end)
    end

    if can('vehicle.delete') then
        menu:Button('Delete the one you are looking at', 'Aim at a vehicle and select this.', function()
            TSIV.Action('vehicle.delete', {})
        end)
    end

    if can('vehicle.dvarea') then
        radiusList(menu, 'Delete vehicles in a radius',
            'Left and right to pick the radius, Enter to delete. Occupied vehicles are left alone.',
            function(radius)
                TSIV.Action('cleanup.area', { kind = 'vehicles', radius = radius })
            end)

        radiusList(menu, 'Delete vehicles in a radius, including occupied',
            'The same, but it also removes vehicles with somebody sitting in them.',
            function(radius)
                TSIV.Action('cleanup.area', { kind = 'vehicles', radius = radius, includeOccupied = true })
            end)
    end

    if can('vehicle.dvall') then
        menu:Button('Delete every vehicle on the map', 'Empty vehicles only. Other staff are told when you do this.', function()
            TSIV.Action('cleanup.area', { kind = 'vehicles', all = true })
        end)
    end
end

-- ---------------------------------------------------------------------------
-- Section: Props and entities
-- ---------------------------------------------------------------------------

local function buildProps(menu)
    if can('prop.toggleproplog') then
        menu:Checkbox('Log every prop spawn to F8',
            'While this is on, every prop created anywhere prints to the F8 console of staff at the configured rank.',
            permissions.propLogging, function(state)
                TSIV.Action('prop.toggleproplog', { state = state })
            end)
    end

    if can('prop.deletenearest') then
        menu:Button('Delete the prop you are looking at', 'Aim at it, then select this.', function()
            local entity = TSIV.RaycastEntity(30.0)
            if not entity or GetEntityType(entity) ~= 3 then
                entity = TSIV.ClosestObject(10.0)
            end
            TSIV.DeleteEntityViaServer(entity, 'props')
        end)
    end

    if can('prop.deletearea') then
        radiusList(menu, 'Delete props in a radius',
            'Left and right to pick the radius, Enter to delete.',
            function(radius)
                TSIV.Action('cleanup.area', { kind = 'props', radius = radius })
            end)

        radiusList(menu, 'Delete loose peds in a radius',
            'Removes spawned peds. Player characters are never touched.',
            function(radius)
                TSIV.Action('cleanup.area', { kind = 'peds', radius = radius })
            end)
    end

    if can('prop.deleteall') then
        menu:Button('Delete every prop on the map', 'Other staff are told when you do this.', function()
            TSIV.Action('cleanup.area', { kind = 'props', all = true })
        end)
    end

    if can('prop.deleteplayer') then
        menu:Button('Delete everything a player spawned',
            'Uses the ownership table the anti-cheat keeps, so it only removes their entities.', function()
                choosePlayer('Whose entities?', function(player)
                    TSIV.Action('cleanup.player', { target = player.id, kind = 'all' })
                end)
            end)

        menu:Button('Delete only the props a player spawned', 'The same, limited to props.', function()
            choosePlayer('Whose props?', function(player)
                TSIV.Action('cleanup.player', { target = player.id, kind = 'props' })
            end)
        end)
    end

    if can('staff.alerts') then
        menu:Button('Anti-cheat status', 'Prints the live anti-cheat settings to F8.', function()
            CreateThread(function()
                TSIV.ShowBlock(TSIV.Request('anticheat.status'))
            end)
        end)
    end
end

-- ---------------------------------------------------------------------------
-- Section: Garage
-- ---------------------------------------------------------------------------

--- Garage options work on a server id or a raw identifier, so an offline
--- player can still be dealt with.
local function askIdentifier(title, onGot)
    CreateThread(function()
        local value = TSIV.Input(title, '', 80)
        if not value then return end
        onGot(value)
    end)
end

local function buildGarage(menu)
    if can('garage.lookup') then
        menu:Button('Look up a garage', 'Prints everything that player owns to F8.', function()
            choosePlayer('Whose garage?', function(player)
                CreateThread(function()
                    TSIV.ShowBlock(TSIV.Request('garage.lookup', { target = player.id }))
                end)
            end)
        end)

        menu:Button('Look up a garage by identifier', 'For a player who is not online. Paste their steam: or license: id.', function()
            askIdentifier('Identifier', function(identifier)
                CreateThread(function()
                    TSIV.ShowBlock(TSIV.Request('garage.lookup', { target = identifier }))
                end)
            end)
        end)
    end

    if can('garage.give') then
        menu:Button('Give a vehicle to a garage', 'Pick a player, then type the model name.', function()
            choosePlayer('Give a vehicle to whom?', function(player)
                CreateThread(function()
                    local model = TSIV.Input('Vehicle model name', '', 32)
                    if not model then return end
                    local plate = TSIV.Input('Plate (leave empty to generate one)', '', 8)
                    TSIV.Action('garage.give', { target = player.id, model = model, plate = plate })
                end)
            end)
        end)
    end

    if can('garage.remove') then
        menu:Button('Remove a vehicle from a garage', 'Pick a player, then type the plate.', function()
            choosePlayer('Remove from whose garage?', function(player)
                CreateThread(function()
                    local plate = TSIV.Input('Plate to remove', '', 8)
                    if not plate then return end
                    TSIV.Action('garage.remove', { target = player.id, plate = plate })
                end)
            end)
        end)

        menu:Button('Remove by identifier and plate', 'For a player who is not online.', function()
            askIdentifier('Identifier', function(identifier)
                CreateThread(function()
                    local plate = TSIV.Input('Plate to remove', '', 8)
                    if not plate then return end
                    TSIV.Action('garage.remove', { target = identifier, plate = plate })
                end)
            end)
        end)
    end
end

-- ---------------------------------------------------------------------------
-- Section: Staff and logs
-- ---------------------------------------------------------------------------

local function buildStaff(menu)
    if can('staff.online') then
        menu:Button('Online staff', 'Prints every online staff member and their rank to F8.', function()
            CreateThread(function()
                TSIV.ShowBlock(TSIV.Request('staff.online'))
            end)
        end)
    end

    if can('staff.chat') then
        menu:Button('Staff chat', 'Send a message only staff can see.', function()
            CreateThread(function()
                local message = TSIV.Input('Staff chat', '', 180)
                if not message or message == '' then return end
                TSIV.Action('staff.chat', { message = message })
            end)
        end)
    end

    if can('staff.announce') then
        menu:Button('Announce to the server', 'Sends a message to everybody.', function()
            CreateThread(function()
                local message = TSIV.Input('Announcement', '', 180)
                if not message or message == '' then return end
                TSIV.Action('staff.announce', { message = message })
            end)
        end)
    end

    if can('staff.logs') then
        menu:Button('Look up an identifier', 'Paste a steam: or license: id, or part of a name.', function()
            askIdentifier('Identifier or name', function(query)
                CreateThread(function()
                    TSIV.ShowBlock(TSIV.Request('logs.lookup', { query = query, limit = 40 }))
                end)
            end)
        end)

        menu:Button('Look up the selected player', 'Runs the same lookup against whoever is selected in Players.', function()
            if not selected then
                TSIV.Notify('Pick a player in the Players menu first.', 'error')
                return
            end
            CreateThread(function()
                -- Resolve their identifier first, so the lookup matches on that
                -- rather than on a display name they could change.
                local details = TSIV.Request('player.identifiers', { target = selected.id })
                local query = details and details.identifier or selected.name
                TSIV.ShowBlock(TSIV.Request('logs.lookup', { query = query, limit = 40 }))
            end)
        end)

        local categories = { 'all', 'staff', 'anticheat', 'props', 'connect', 'ban', 'garage' }
        local values = {}
        for _, category in ipairs(categories) do
            values[#values + 1] = { label = category, value = category }
        end

        menu:List('Recent logs', 'Left and right to pick a category, Enter to print it to F8.', values, function(value)
            CreateThread(function()
                TSIV.ShowBlock(TSIV.Request('logs.recent', { category = value, limit = 40 }))
            end)
        end)
    end

    if can('staff.serverinfo') then
        menu:Button('Server info', 'Player, entity and resource counts.', function()
            CreateThread(function()
                TSIV.ShowBlock(TSIV.Request('staff.serverinfo'))
            end)
        end)
    end
end

-- ---------------------------------------------------------------------------
-- Assembly
-- ---------------------------------------------------------------------------

local builders = {
    self    = buildSelf,
    players = buildPlayers,
    vehicle = buildVehicles,
    props   = buildProps,
    garage  = buildGarage,
    staff   = buildStaff,
}

local descriptions = {
    self    = 'God mode, noclip, teleports.',
    players = 'Everything that acts on a player.',
    vehicle = 'Spawn, repair and clear vehicles.',
    props   = 'Prop logging and area cleanup.',
    garage  = 'Give, remove and look up owned vehicles.',
    staff   = 'Staff list, announcements and the log lookup.',
}

local function buildRoot()
    root = TSIV.Menu.Create('tsivtools', ('%s  |  %s'):format(
        GetPlayerName(PlayerId()), permissions.rankLabel))

    for _, entry in ipairs(Config.MenuSections) do
        local builder = builders[entry.id]
        if builder then
            section(root, entry.label, descriptions[entry.id] or '', builder)
        end
    end

    if #root.items == 0 then
        root:Label('You have a rank but no permissions are set for it.')
    end
end

-- ---------------------------------------------------------------------------
-- Permission handshake
-- ---------------------------------------------------------------------------

RegisterNetEvent(TSIV.Events.permissions, function(payload)
    permissions = payload

    if not permissions then
        root = nil
        return
    end

    buildRoot()

    -- A rank change while the menu is open replaces it with the new one rather
    -- than leaving stale rows on screen.
    if TSIV.Menu.IsOpen() then
        TSIV.Menu.Open(root)
    end
end)

local function askForPermissions()
    TriggerServerEvent(TSIV.Events.ready)
end

AddEventHandler('playerSpawned', askForPermissions)

CreateThread(function()
    -- Also ask on resource start, so a restart while players are in game does
    -- not leave everybody without a menu until they respawn.
    Wait(2000)
    askForPermissions()
end)

-- ---------------------------------------------------------------------------
-- Keybind
-- ---------------------------------------------------------------------------

local function toggleMenu()
    if TSIV.Menu.IsOpen() then
        TSIV.Menu.Close()
        return
    end

    if not permissions then
        -- Either not staff, or the handshake has not happened yet. Ask again
        -- rather than telling a genuine staff member they have no access.
        askForPermissions()
        Wait(400)
        if not permissions then
            return
        end
    end

    if not can('menu.open') then
        return
    end

    if not root then buildRoot() end
    TSIV.Menu.Open(root)
end

RegisterCommand(Config.MenuCommand, function()
    CreateThread(toggleMenu)
end, false)

-- This is what puts the bind in Settings -> Key Bindings -> FiveM. The key in
-- config.lua is only the default: once a player has connected, their own
-- choice is stored client side and takes over.
RegisterKeyMapping(Config.MenuCommand, 'Open the tsivtools menu', 'keyboard', Config.MenuKey)

-- Close the menu if the resource is stopped while it is open, otherwise the
-- rows stay drawn on screen with nothing behind them.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= TSIV.resource then return end
    if TSIV.Menu.IsOpen() then TSIV.Menu.Close() end
    if TSIV.State.noclip then TSIV.ToggleNoclip(false) end
    if TSIV.State.spectating then TSIV.StopSpectating() end
end)
