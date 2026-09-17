local permissions = nil
local root = nil

local function can(key)
    return permissions ~= nil and permissions.granted[key] == true
end

local function section(parent, label, description, builder)
    local menu = TSIV.Menu.Create(label, permissions.rankLabel)
    builder(menu)
    if #menu.items > 0 then
        parent:Attach(label, description, menu)
    end
    return menu
end

local function withTarget(fn)
    CreateThread(function()
        local id = TSIV.InputNumber('User ID', '', 6)
        if not id then return end

        id = math.floor(id)
        if id < 1 then
            TSIV.Notify('Thats not a valid User ID !', 'error')
            return
        end

        fn(id)
    end)
end

local function choosePlayer(title, onPick)
    CreateThread(function()
        local id = TSIV.InputNumber(title or 'User ID', '', 6)
        if id then onPick({ id = math.floor(id), name = ('id %d'):format(math.floor(id)) }) end
    end)
end

local function radiusList(menu, label, description, onPick)
    local values = {}
    for _, radius in ipairs(Config.AreaRadiusOptions) do
        values[#values + 1] = { label = radius .. 'm', value = radius }
    end
    menu:List(label, description, values, function(value)
        onPick(value)
    end)
end

local function buildSelf(menu)
    if can('self.godmode') then
        menu:Checkbox('GodMode', 'Deny Damage !!', TSIV.State.god, function(state)
            TSIV.ToggleGod(state)
        end)
    end

    if can('self.invisible') then
        menu:Checkbox('Invisible', 'Self explainatory !!', TSIV.State.invisible, function(state)
            TSIV.ToggleInvisible(state)
        end)
    end

    if can('self.noclip') then
        menu:Checkbox('Noclip', 'activate/deactivate noclip',
            TSIV.State.noclip, function(state)
                TSIV.ToggleNoclip(state)
            end)

        menu:List('Noclip speed', 'How fast you move with noclip', {
            { label = 'slow',   value = 0.5 },
            { label = 'normal', value = 1.0 },
            { label = 'fast',   value = 2.5 },
            { label = 'silly',  value = 6.0 },
        }, function(value)
            TSIV.SetNoclipSpeed(value)
            TSIV.Notify(('Noclip speed set to %s !!'):format(value), 'info')
        end, function(value)
            TSIV.SetNoclipSpeed(value)
        end)
    end

    if can('self.heal') then
        menu:Button('Heal yourself', 'restores health !!', function()
            local ped = PlayerPedId()
            SetEntityHealth(ped, GetEntityMaxHealth(ped))
            ClearPedBloodDamage(ped)
            TSIV.Notify('Healed !!', 'success')
        end)
    end

    if can('self.armour') then
        menu:Button('Full armour', 'gives 100 armor !!', function()
            SetPedArmour(PlayerPedId(), 100)
            TSIV.Notify('Armour restored !', 'success')
        end)
    end

    if can('self.tpmarker') then
        menu:Button('Teleport to your waypoint', 'Please set a waypoint on the map first !!', function()
            CreateThread(TSIV.TeleportToMarker)
        end)
    end

    if can('self.tpcoords') then
        menu:Button('Teleport to coordinates', 'Type x, y, z separated by spaces or commas !', function()
            CreateThread(function()
                local input = TSIV.Input('Coordinates (x y z)', '', 48)
                if not input then return end

                local x, y, z = input:match('(-?%d+%.?%d*)[%s,]+(-?%d+%.?%d*)[%s,]+(-?%d+%.?%d*)')
                if not x then
                    TSIV.Notify('Could not read those coordinates :(', 'error')
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
        menu:Attach('Saved locations', 'Known locations across all fiveM servers', teleports)
    end

    menu:Button('print coords to console', 'print coordinates in the F8 console', function()
        local coords = GetEntityCoords(PlayerPedId())
        local heading = GetEntityHeading(PlayerPedId())
        TSIV.PrintBlock('your position', {
            ('vector3(%.2f, %.2f, %.2f)'):format(coords.x, coords.y, coords.z),
            ('heading %.2f'):format(heading),
            ('config line: { label = \'name here\', coords = vector3(%.1f, %.1f, %.1f) },')
                :format(coords.x, coords.y, coords.z),
        })
        TSIV.Notify('Printed to console :))', 'success')
    end)
end

local function buildPlayers(menu)
    if not can('player.list') then return end

    local function targeted(label, description, permission, action, payload)
        if not can(permission) then return end
        menu:Button(label, description, function()
            withTarget(function(target)
                local body = { target = target }
                for key, value in pairs(payload or {}) do body[key] = value end
                TSIV.Action(action, body)
            end)
        end)
    end

    targeted('Go to',   'Teleport yourself to them !',    'player.goto',    'player.goto')
    targeted('Bring',   'Teleport them to you !',         'player.bring',   'player.bring')
    targeted('Revive',  'Revive them !','player.revive',  'player.revive')
    targeted('Heal',    'Restore their health and armour !',       'player.heal',    'player.heal')
    targeted('Slay',    'Kill them !',   'player.slay',    'player.slay')

    if can('player.spectate') then
        menu:Button('Spectate', 'Enter a numeric server ID. Use backspace to stop spectating.', function()
            withTarget(function(target)
                TSIV.Action('player.spectate', { target = target })
            end)
        end)
        menu:Button('Stop spectating', 'Stop spectating a player !', function()
            TSIV.StopSpectating()
            TSIV.Action('player.spectate', {})
        end)
    end

    if can('player.freeze') then
        menu:Button('Freeze', 'Lock the player in place !', function()
            withTarget(function(target)
                TSIV.Action('player.freeze', { target = target, state = true })
            end)
        end)
        menu:Button('Unfreeze', 'remove freeze from the player !', function()
            withTarget(function(target)
                TSIV.Action('player.freeze', { target = target, state = false })
            end)
        end)
    end

    if can('player.warn') then
        menu:Button('Warn', 'Send a warning to a player !', function()
            withTarget(function(target)
                CreateThread(function()
                    local reason = TSIV.Input('Warning reason :', '', 120)
                    if not reason then return end
                    TSIV.Action('player.warn', { target = target, reason = reason })
                end)
            end)
        end)
    end

    if can('player.kick') then
        menu:Button('Kick', 'Kick the player from the server !', function()
            withTarget(function(target)
                CreateThread(function()
                    local reason = TSIV.Input('Kick reason', '', 120)
                    if not reason then return end
                    TSIV.Action('player.kick', { target = target, reason = reason })
                end)
            end)
        end)
    end

    if can('player.ban') then
        menu:Button('Ban', 'duration is minutes, 0 for permanent !', function()
            withTarget(function(target)
                CreateThread(function()
                    local minutes = TSIV.InputNumber('Ban length in minutes (0 = permanent)', '0', 8)
                    if minutes == nil then return end
                    local reason = TSIV.Input('Ban reason', '', 150)
                    if not reason then return end
                    TSIV.Action('player.ban', { target = target, minutes = minutes, reason = reason })
                end)
            end)
        end)
    end

    if can('player.identifiers') then
        menu:Button('Identifiers', 'Print the players identifiers in the console !', function()
            withTarget(function(target)
                CreateThread(function()
                    TSIV.ShowBlock(TSIV.Request('player.identifiers', { target = target }))
                end)
            end)
        end)
    end

    if can('player.watchlist') then
        menu:Button('Add player to watchlist', 'Enter a numeric server ID.', function()
            withTarget(function(target)
                CreateThread(function()
                    local note = TSIV.Input('Watchlist note', '', 160)
                    if note then TSIV.Action('watchlist.add', { target = target, note = note }) end
                end)
            end)
        end)
        local function watchMenu(online)
            local sub = TSIV.Menu.Create(online and 'Online watchlisted players' or 'All watchlisted players', 'Press enter for actions')
            sub.onOpen = function()
                sub:Clear()
                local list = TSIV.Request('watchlist.list', { online = online })
                if not list or #list == 0 then sub:Label('No watchlisted players.')
                else
                    for _, entry in ipairs(list) do
                        local item = sub:Button(('%s%s'):format(entry.online and ('[%d] '):format(entry.online) or '', entry.name),
                            entry.note or entry.identifier, function()
                                local actions = TSIV.Menu.Create(entry.name, entry.identifier)
                                actions:Button('Remove watchlist', 'Stop monitoring this player.', function()
                                    TSIV.Action('watchlist.remove', { identifier = entry.identifier }); TSIV.Menu.Back()
                                end)
                                actions:Button('Get identifiers', 'Print stored identifiers to console.', function()
                                    local lines = { entry.identifier }
                                    for kind, value in pairs(entry.identifiers or {}) do lines[#lines + 1] = kind .. ': ' .. value end
                                    TSIV.ShowBlock({ title = entry.name .. ' identifiers', lines = lines })
                                end)
                                actions:Button('Get Discord ID', 'Print the stored Discord identifier.', function()
                                    local discord = entry.identifiers and entry.identifiers.discord or 'not recorded'
                                    TSIV.ShowBlock({ title = entry.name .. ' Discord', lines = { discord } })
                                end)
                                if entry.online then
                                    actions:Button('Spectate', 'Spectate this player.', function() TSIV.Action('player.spectate', { target = entry.online }) end)
                                    actions:Button('Goto', 'Teleport to this player.', function() TSIV.Action('player.goto', { target = entry.online }) end)
                                    actions:Button('Bring', 'Bring this player.', function() TSIV.Action('player.bring', { target = entry.online }) end)
                                    actions:Button('Warn', 'Warn this player.', function()
                                        local reason = TSIV.Input('Warning reason', '', 120)
                                        if reason then TSIV.Action('player.warn', { target = entry.online, reason = reason }) end
                                    end)
                                    actions:Button('Ban', 'Ban this player.', function()
                                        local reason = TSIV.Input('Ban reason', '', 150)
                                        if reason then TSIV.Action('player.ban', { target = entry.online, minutes = 0, reason = reason }) end
                                    end)
                                elseif can('player.ban') then
                                    actions:Button('Ban', 'Create a permanent ban from stored identifiers.', function()
                                        local reason = TSIV.Input('Ban reason', '', 150)
                                        if reason then TSIV.Action('watchlist.ban', {
                                            identifiers = entry.identifiers, name = entry.name, reason = reason,
                                        }) end
                                    end)
                                end
                                TSIV.Menu.Push(actions)
                            end)
                        item.right = entry.online and 'online' or 'offline'
                    end
                end
                TSIV.Menu.Refresh()
            end
            sub.onOpen()
            TSIV.Menu.Push(sub)
        end
        menu:Button('Online watchlisted players', 'Search only watchlisted players currently online.', function() watchMenu(true) end)
        menu:Button('All watchlisted players', 'Browse online and offline watchlist records.', function() watchMenu(false) end)
    end

    if can('player.tags') then
        menu:Button('Add player tag', 'Permanent or timed: 30m, 2h, 7d, permanent.', function()
            withTarget(function(target)
                CreateThread(function()
                    local time = TSIV.Input('Duration', 'permanent', 24)
                    local content = time and TSIV.Input('Tag content', '', 160)
                    if time and content then TSIV.Action('player.tag', { target = target, duration = time, content = content }) end
                end)
            end)
        end)
    end

    if can('player.rating') then
        menu:Button('Player rating', 'Show logs, bans, warns, alerts and history for an ID.', function()
            withTarget(function(target)
                TSIV.ShowBlock(TSIV.Request('player.rating', { target = target }))
            end)
        end)
    end

    if can('player.aliases') then
        menu:Button('Player aliases', 'Show all names and Steam accounts linked to an ID.', function()
            withTarget(function(target)
                TSIV.ShowBlock(TSIV.Request('player.aliases', { target = target }))
            end)
        end)
    end

    if can('player.relationships') then
        menu:Button('Link player to another', 'Enter the current player ID, then the related player ID.', function()
            CreateThread(function()
                local target = TSIV.InputNumber('Current player ID', '', 6)
                if not target then return end
                local related = TSIV.InputNumber('Related player ID', '', 6)
                if not related then return end
                local note = TSIV.Input('Relationship note', '', 160)
                if note then TSIV.Action('player.link', { target = target, related = related, note = note }) end
            end)
        end)
    end

    if can('player.setrank') then
        local values = {}
        for _, rank in ipairs(TSIV.Ranks()) do
            values[#values + 1] = { label = rank.label, value = rank.name }
        end
        values[#values + 1] = { label = 'remove rank', value = 'none' }

        menu:List('Set staff group',
            'Use arrowkeys to select a group, press enter to set that group to the user !',
            values, function(value)
                withTarget(function(target)
                    TSIV.Action('player.setrank', { target = target, rank = value })
                end)
            end)
    end

    if can('player.unban') then
        local bans = TSIV.Menu.Create('Active bans', 'Select a ban to remove it !')
        bans.onOpen = function()
            CreateThread(function()
                bans:Clear()
                bans:Button('Search by name or identifier', 'Find a specific players ban', function()
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
                            ('%s  /  expires %s  /  by %s'):format(ban.reason, ban.expiresText, ban.bannedBy),
                            function()
                                TSIV.Action('player.unban', { banId = ban.id })
                                bans.onOpen()
                            end)
                    end
                end
                TSIV.Menu.Refresh()
            end)
        end
        menu:Attach('Bans', 'Browse bans !', bans)
    end
end

local function buildVehicles(menu)
    if can('vehicle.spawn') then
        if #Config.VehicleList > 0 then
            local list = TSIV.Menu.Create('Spawn a vehicle', 'Select a a vehicle to spawn !')
            for _, entry in ipairs(Config.VehicleList) do
                list:Button(entry.label, entry.model, function()
                    TSIV.Action('vehicle.spawn', { model = entry.model })
                end)
            end
            menu:Attach('Spawn from the list', 'Certain popular vehicles are in this list !', list)
        end

        menu:Button('Spawn by model name', 'Use any model available in the server', function()
            CreateThread(function()
                local model = TSIV.Input('Vehicle model name', '', 32)
                if not model then return end
                TSIV.Action('vehicle.spawn', { model = model })
            end)
        end)
    end

    if can('vehicle.repair') then
        menu:Button('Repair', 'repairs the nearest vehicle !!', function()
            TSIV.Action('vehicle.repair', {})
        end)
    end

    if can('vehicle.refuel') then
        menu:Button('Refuel', 'refuels the nearest vehicle !!', function()
            TSIV.Action('vehicle.refuel', {})
        end)
    end

    if can('vehicle.flip') then
        menu:Button('Flip', 'flips a vehicle back on its wheels !', function()
            TSIV.Action('vehicle.flip', {})
        end)
    end

    if can('vehicle.delete') then
        menu:Button('Delete aimed vehicle', 'Aim at a vehicle and press enter !', function()
            TSIV.Action('vehicle.delete', {})
        end)
    end

    if can('vehicle.dvarea') then
        radiusList(menu, 'Delete vehicles in a radius',
            'use arrowkeys to select radius, occupied vehicles will not be included',
            function(radius)
                TSIV.Action('cleanup.area', { kind = 'vehicles', radius = radius })
            end)

        radiusList(menu, 'Delete vehicles in a radius, including occupied',
            'use arrowkeys to select radius !',
            function(radius)
                TSIV.Action('cleanup.area', { kind = 'vehicles', radius = radius, includeOccupied = true })
            end)
    end

    if can('vehicle.dvall') then
        menu:Button('Delete every vehicle on the map', 'occupied vehicles are left untouched, all staff get alerted with this !!!', function()
            TSIV.Action('cleanup.area', { kind = 'vehicles', all = true })
        end)
    end
end

local trafficLabels = {
    { key = 'vehicles', label = 'Disable traffic vehicles' },
    { key = 'peds',     label = 'Disable walking peds' },
    { key = 'cops',     label = 'Disable random cops' },
    { key = 'boats',    label = 'Disable random boats' },
    { key = 'trains',   label = 'Disable trains' },
}

local function buildProps(menu)
    if can('prop.toggleproplog') then
        menu:Checkbox('Log every prop spawn in the console',
            'Every prop spawned in the server gets logged in console.',
            permissions.propLogging, function(state)
                TSIV.Action('prop.toggleproplog', { state = state })
            end)
    end

    if can('prop.spawn') then
        menu:Button('Spawn a prop', 'Type a prop model name, it drops in front of you !', function()
            CreateThread(function()
                local model = TSIV.Input('Prop model name', '', 48)
                if not model or model == '' then return end
                TSIV.Action('prop.spawn', { model = model })
            end)
        end)
    end

    if can('world.traffic') then
        local state = (permissions and permissions.traffic) or {}
        for _, entry in ipairs(trafficLabels) do
            menu:Checkbox(entry.label, 'Applies to everyone on the server !', state[entry.key] == true,
                function(checked)
                    TSIV.Action('world.traffic', { key = entry.key, state = checked })
                end)
        end
    end

    if can('world.cleartraffic') then
        menu:Button('Clear traffic now', 'Deletes cars and peds the game spawned, not yours !', function()
            TSIV.Action('world.cleartraffic', {})
        end)
    end

    if can('prop.deletenearest') then
        menu:Button('Delete aimed prop', 'TsivTools :))', function()
            local entity = TSIV.RaycastEntity(30.0)
            if not entity or GetEntityType(entity) ~= 3 then
                entity = TSIV.ClosestObject(10.0)
            end
            TSIV.DeleteEntityViaServer(entity, 'props')
        end)
    end

    if can('prop.deletearea') then
        radiusList(menu, 'Delete props in a radius',
            'use arrowkeys to select radius !',
            function(radius)
                TSIV.Action('cleanup.area', { kind = 'props', radius = radius })
            end)

        radiusList(menu, 'Delete spawned peds in a radius',
            'use arrowkeys to select radius !!',
            function(radius)
                TSIV.Action('cleanup.area', { kind = 'peds', radius = radius })
            end)
    end

    if can('prop.deleteall') then
        menu:Button('Delete every prop on the map', 'all staff get informed about this action !!!', function()
            TSIV.Action('cleanup.area', { kind = 'props', all = true })
        end)
    end

    if can('prop.deleteplayer') then
        menu:Button('Delete everything a player spawned',
            'Deletes all entities spawned from a player !!', function()
                choosePlayer('User ID:', function(player)
                    TSIV.Action('cleanup.player', { target = player.id, kind = 'all' })
                end)
            end)

        menu:Button('Delete only the props a player spawned', 'TsivTools :))', function()
            choosePlayer('User ID: ', function(player)
                TSIV.Action('cleanup.player', { target = player.id, kind = 'props' })
            end)
        end)
    end

    if can('staff.alerts') then
        menu:Button('anticheat status', 'prints live anticheat updates and settings to console !', function()
            CreateThread(function()
                TSIV.ShowBlock(TSIV.Request('anticheat.status'))
            end)
        end)
    end
end

local function askIdentifier(title, onGot)
    CreateThread(function()
        local value = TSIV.Input(title, '', 80)
        if not value then return end
        onGot(value)
    end)
end

local function buildGarage(menu)
    if can('garage.lookup') then
        menu:Button('Look up a garage', 'prints all owned vehicles by a user in the console !', function()
            choosePlayer('User ID:', function(player)
                CreateThread(function()
                    TSIV.ShowBlock(TSIV.Request('garage.lookup', { target = player.id }))
                end)
            end)
        end)

        menu:Button('Look up a garage by identifier', 'made for offline use ! steam ID or License key :)', function()
            askIdentifier('Identifier', function(identifier)
                CreateThread(function()
                    TSIV.ShowBlock(TSIV.Request('garage.lookup', { target = identifier }))
                end)
            end)
        end)
    end

    if can('garage.give') then
        menu:Button('Give a vehicle to a garage', 'TsivTools :))', function()
            choosePlayer('user ID: ', function(player)
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
        menu:Button('Remove a vehicle from a garage', 'TsivTools :))', function()
            choosePlayer('user ID: ', function(player)
                CreateThread(function()
                    local plate = TSIV.Input('Plate to remove: ', '', 8)
                    if not plate then return end
                    TSIV.Action('garage.remove', { target = player.id, plate = plate })
                end)
            end)
        end)

        menu:Button('Remove by identifier and plate', 'for offline use !', function()
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

local function buildStaff(menu)
    if can('staff.online') then
        menu:Button('Online staff', 'Prints all online staff to console !!', function()
            CreateThread(function()
                TSIV.ShowBlock(TSIV.Request('staff.online'))
            end)
        end)
    end

    if can('staff.chat') then
        menu:Button('Staff chat', 'Send a message only staff can see !!', function()
            CreateThread(function()
                local message = TSIV.Input('Staff chat', '', 180)
                if not message or message == '' then return end
                TSIV.Action('staff.chat', { message = message })
            end)
        end)
    end

    if can('staff.announce') then
        menu:Button('Announce to the server', 'TsivTools :))', function()
            CreateThread(function()
                local message = TSIV.Input('Announcement', '', 180)
                if not message or message == '' then return end
                TSIV.Action('staff.announce', { message = message })
            end)
        end)
    end

    if can('staff.logs') then
        menu:Button('Look up an identifier', 'Paste a steam: or license: id, or part of a name.', function()
            askIdentifier('Identifier or name: ', function(query)
                CreateThread(function()
                    TSIV.ShowBlock(TSIV.Request('logs.lookup', { query = query, limit = 40 }))
                end)
            end)
        end)

        menu:Button('Look up player by ID', 'Get identifiers and logs from a numeric server ID.', function()
            withTarget(function(target)
                CreateThread(function()
                    local details = TSIV.Request('player.identifiers', { target = target })
                    local query = details and details.identifier or tostring(target)
                    TSIV.ShowBlock(TSIV.Request('logs.lookup', { query = query, limit = 40 }))
                end)
            end)
        end)

        local categories = { 'all', 'staff', 'anticheat', 'props', 'connect', 'ban', 'garage' }
        local values = {}
        for _, category in ipairs(categories) do
            values[#values + 1] = { label = category, value = category }
        end

        menu:List('Recent logs', 'use arrowkeys to choose logs, press enter to print said logs to console !', values, function(value)
            CreateThread(function()
                TSIV.ShowBlock(TSIV.Request('logs.recent', { category = value, limit = 40 }))
            end)
        end)
    end

    if can('staff.serverinfo') then
        menu:Button('Server info', 'Player entity and resource count !', function()
            CreateThread(function()
                TSIV.ShowBlock(TSIV.Request('staff.serverinfo'))
            end)
        end)
    end
end

local builders = {
    self    = buildSelf,
    players = buildPlayers,
    vehicle = buildVehicles,
    props   = buildProps,
    garage  = buildGarage,
    staff   = buildStaff,
}

local descriptions = {
    self    = 'TsivTools :))',
    players = 'TsivTools :))',
    vehicle = 'TsivTools :))',
    props   = 'TsivTools :))',
    garage  = 'TsivTools :))',
    staff   = 'TsivTools :))',
}

local function buildRoot()
    root = TSIV.Menu.Create('tsivtools', ('%s  /  %s'):format(
        GetPlayerName(PlayerId()), permissions.rankLabel))

    for _, entry in ipairs(Config.MenuSections) do
        local builder = builders[entry.id]
        if builder then
            section(root, entry.label, descriptions[entry.id] or '', builder)
        end
    end

    if #root.items == 0 then
        root:Label('You are not allowed to use TsivTools :)) ')
    end
end

RegisterNetEvent(TSIV.Events.permissions, function(payload)
    permissions = payload

    if payload and payload.traffic then
        TSIV.ApplyTraffic(payload.traffic)
    end

    if not permissions then
        root = nil
        return
    end

    buildRoot()

    if TSIV.Menu.IsOpen() then
        TSIV.Menu.Open(root)
    end
end)

local function askForPermissions()
    TriggerServerEvent(TSIV.Events.ready)
end

AddEventHandler('playerSpawned', askForPermissions)

CreateThread(function()
    Wait(2000)
    askForPermissions()
end)

local function toggleMenu()
    if TSIV.Menu.IsOpen() then
        TSIV.Menu.Close()
        return
    end

    if not permissions then

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

RegisterKeyMapping(Config.MenuCommand, 'TsivTools :))', 'keyboard', Config.MenuKey)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= TSIV.resource then return end
    if TSIV.Menu.IsOpen() then TSIV.Menu.Close() end
    if TSIV.State.noclip then TSIV.ToggleNoclip(false) end
    if TSIV.State.spectating then TSIV.StopSpectating() end
end)
