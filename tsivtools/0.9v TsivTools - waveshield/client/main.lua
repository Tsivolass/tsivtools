local permissions = nil
local root = nil

local function can(key)
    return permissions ~= nil and permissions.granted[key] == true
end

local function section(parent, label, description, builder)
    local menu = tsivtools.Menu.Create(label, permissions.rankLabel)
    builder(menu)
    if #menu.items > 0 then
        parent:Attach(label, description, menu)
    end
    return menu
end

local function withTarget(fn)
    CreateThread(function()
        local id = tsivtools.InputNumber('User ID', '', 6)
        if not id then return end

        id = math.floor(id)
        if id < 1 then
            tsivtools.Notify('Thats not a valid User ID !', 'error')
            return
        end

        fn(id)
    end)
end

local function choosePlayer(title, onPick)
    CreateThread(function()
        local id = tsivtools.InputNumber(title or 'User ID', '', 6)
        if id then onPick({ id = math.floor(id), name = ('id %d'):format(math.floor(id)) }) end
    end)
end

local function radiusList(menu, label, description, onPick)
    local values = {}
    for _, radius in ipairs(Config.arearadiusoptions) do
        values[#values + 1] = { label = radius .. 'm', value = radius }
    end
    menu:List(label, description, values, function(value)
        onPick(value)
    end)
end

local function buildSelf(menu)
    if can('self.godmode') then
        menu:Checkbox('GodMode', 'Deny Damage !!', tsivtools.State.god, function(state)
            tsivtools.ToggleGod(state)
        end)
    end

    if can('self.invisible') then
        menu:Checkbox('Invisible', 'Self explainatory !!', tsivtools.State.invisible, function(state)
            tsivtools.ToggleInvisible(state)
        end)
    end

    if can('self.noclip') then
        menu:Checkbox('Noclip', 'activate/deactivate noclip',
            tsivtools.State.noclip, function(state)
                tsivtools.ToggleNoclip(state)
            end)

        menu:List('Noclip speed', 'How fast you move with noclip', {
            { label = 'slow',   value = 0.5 },
            { label = 'normal', value = 1.0 },
            { label = 'fast',   value = 2.5 },
            { label = 'silly',  value = 6.0 },
        }, function(value)
            tsivtools.SetNoclipSpeed(value)
            tsivtools.Notify(('Noclip speed set to %s !!'):format(value), 'info')
        end, function(value)
            tsivtools.SetNoclipSpeed(value)
        end)
    end

    if can('self.heal') then
        menu:Button('Heal yourself', 'restores health !!', function()
            local ped = PlayerPedId()
            SetEntityHealth(ped, GetEntityMaxHealth(ped))
            ClearPedBloodDamage(ped)
            tsivtools.Notify('Healed !!', 'success')
        end)
    end

    if can('self.armour') then
        menu:Button('Full armour', 'gives 100 armor !!', function()
            SetPedArmour(PlayerPedId(), 100)
            tsivtools.Notify('Armour restored !', 'success')
        end)
    end

    if can('self.tpmarker') then
        menu:Button('Teleport to your waypoint', 'Please set a waypoint on the map first !!', function()
            CreateThread(tsivtools.TeleportToMarker)
        end)
    end

    if can('self.tpcoords') then
        menu:Button('Teleport to coordinates', 'Type x, y, z separated by spaces or commas !', function()
            CreateThread(function()
                local input = tsivtools.Input('Coordinates (x y z)', '', 48)
                if not input then return end

                local x, y, z = input:match('(-?%d+%.?%d*)[%s,]+(-?%d+%.?%d*)[%s,]+(-?%d+%.?%d*)')
                if not x then
                    tsivtools.Notify('Could not read those coordinates :(', 'error')
                    return
                end

                tsivtools.Action('self.teleport', { x = tonumber(x), y = tonumber(y), z = tonumber(z) })
            end)
        end)
    end

    if can('self.tpsaved') and #Config.teleports > 0 then
        local teleports = tsivtools.Menu.Create('Teleports', 'from config.lua')
        for index, entry in ipairs(Config.teleports) do
            teleports:Button(entry.label, ('%.0f, %.0f, %.0f'):format(entry.coords.x, entry.coords.y, entry.coords.z), function()
                tsivtools.Action('self.teleport', { saved = index })
            end)
        end
        menu:Attach('Saved locations', 'Known locations across all fiveM servers', teleports)
    end

    menu:Button('print coords to console', 'print coordinates in the F8 console', function()
        local coords = GetEntityCoords(PlayerPedId())
        local heading = GetEntityHeading(PlayerPedId())
        tsivtools.PrintBlock('your position', {
            ('vector3(%.2f, %.2f, %.2f)'):format(coords.x, coords.y, coords.z),
            ('heading %.2f'):format(heading),
            ('config line: { label = \'name here\', coords = vector3(%.1f, %.1f, %.1f) },')
                :format(coords.x, coords.y, coords.z),
        })
        tsivtools.Notify('Printed to console :))', 'success')
    end)
end

local function playerList(onPick)
    local list = tsivtools.Menu.Create('Online Players', 'Press Enter on a player for actions !')

    list.onOpen = function()
        CreateThread(function()
            local players = tsivtools.Request('player.list')
            if not players then return end
            local query = list.query

            list:Clear()
            local search = list:Button('Search by name or ID', 'Leave it empty to show everyone again !', function()
                CreateThread(function()
                    local text = tsivtools.Input('Search players', query or '', 32)
                    if not text then return end
                    list.query = text ~= '' and text:lower() or nil
                    list.onOpen()
                end)
            end)
            search.right = query or ''

            local shown = 0
            for _, player in ipairs(players) do
                if not query or tostring(player.id) == query or player.name:lower():find(query, 1, true) then
                    local row = list:Button(('[%d] %s'):format(player.id, player.name),
                        ('ping %dms   health %d%s'):format(player.ping, player.health,
                            player.rankLabel and ('   staff: ' .. player.rankLabel) or ''),
                        function() onPick(player) end)
                    row.right = ('%dms'):format(player.ping)
                    shown = shown + 1
                end
            end

            if shown == 0 then
                list:Label(query and 'Nobody matches that search !' or 'Nobody online !!')
            end
            list.subtitle = ('%d online'):format(#players)
            tsivtools.Menu.Refresh()
        end)
    end

    return list
end

local function buildPlayers(menu, player)
    if not can('player.list') then return end

    local withTarget = withTarget
    if player then
        withTarget = function(fn)
            CreateThread(function() fn(player.id) end)
        end
    else
        menu:Attach('Online Players', 'Everyone on the server, pick one for actions !', playerList(function(picked)
            local actions = tsivtools.Menu.Create(picked.name, ('id %d'):format(picked.id))
            buildPlayers(actions, picked)
            tsivtools.Menu.Push(actions)
        end))
    end

    if can('security.view') then
        if not player then
            menu:Button('Suspicious Players', 'Players that have been recently flagged by TsivTools !', function()
                CreateThread(function()
                    tsivtools.ShowBlock(tsivtools.Request('security.detections', { severity = 'all', kind = 'all' }))
                end)
            end)
        end
        menu:Button('Player Security Profile', 'Identity, detections and risk !', function()
            withTarget(function(target)
                CreateThread(function()
                    tsivtools.ShowBlock(tsivtools.Request('security.profile', { target = target }))
                end)
            end)
        end)
        menu:Button('WaveShield Player Profile', 'WaveShield analysis for a player !', function()
            withTarget(function(target)
                CreateThread(function()
                    local details = tsivtools.Request('player.identifiers', { target = target })
                    local identifier = details and details.identifier
                    tsivtools.ShowBlock(tsivtools.Request('security.waveshield.profile', { identifier = identifier }))
                end)
            end)
        end)
        if can('security.waveshield.ban') then
            menu:Button('WaveShield Ban', 'Wave Ban a player !', function()
                withTarget(function(target)
                    CreateThread(function()
                        local duration = tsivtools.InputNumber('WaveShield duration value (0 = permanent)', '0', 10)
                        if duration == nil then return end
                        local reason = tsivtools.Input('WaveShield ban reason', '', 150)
                        if reason then
                            tsivtools.Action('security.waveshield.ban', {
                                target = target, duration = math.floor(duration), reason = reason,
                            })
                        end
                    end)
                end)
            end)
        end
        if can('security.monitor') then
            menu:Button('Temporary Monitor player', 'Monitor a player for up to 10 minutes !', function()
                withTarget(function(target)
                    CreateThread(function()
                        local minutes = tsivtools.InputNumber('Monitor duration (1-10 minutes)', '10', 2)
                        if minutes then
                            TriggerServerEvent('tsivtools:security:monitor', target, math.floor(minutes))
                        end
                    end)
                end)
            end)
        end
    end

    local function targeted(label, description, permission, action, payload)
        if not can(permission) then return end
        menu:Button(label, description, function()
            withTarget(function(target)
                local body = { target = target }
                for key, value in pairs(payload or {}) do body[key] = value end
                tsivtools.Action(action, body)
            end)
        end)
    end

    targeted('Go to',   'Teleport yourself to them !',    'player.goto',    'player.goto')
    targeted('Bring',   'Teleport them to you !',         'player.bring',   'player.bring')
    targeted('Revive',  'Revive them !','player.revive',  'player.revive')
    targeted('Heal',    'Restore their health and armour !',       'player.heal',    'player.heal')
    targeted('Slay',    'Kill them !',   'player.slay',    'player.slay')

    if can('player.spectate') then
        menu:Button('Spectate', 'Enter a user ID! Use backspace to stop spectating !', function()
            withTarget(function(target)
                tsivtools.Action('player.spectate', { target = target })
            end)
        end)
        menu:Button('Stop spectating', 'Stop spectating a player !', function()
            tsivtools.StopSpectating()
            tsivtools.Action('player.spectate', {})
        end)
    end

    if can('player.freeze') then
        menu:Button('Freeze', 'Lock the player in place !', function()
            withTarget(function(target)
                tsivtools.Action('player.freeze', { target = target, state = true })
            end)
        end)
        menu:Button('Unfreeze', 'remove freeze from the player !', function()
            withTarget(function(target)
                tsivtools.Action('player.freeze', { target = target, state = false })
            end)
        end)
    end

    if can('player.warn') then
        menu:Button('Warn', 'Send a warning to a player !', function()
            withTarget(function(target)
                CreateThread(function()
                    local reason = tsivtools.Input('Warning reason :', '', 120)
                    if not reason then return end
                    tsivtools.Action('player.warn', { target = target, reason = reason })
                end)
            end)
        end)
    end

    if can('player.kick') then
        menu:Button('Kick', 'Kick the player from the server !', function()
            withTarget(function(target)
                CreateThread(function()
                    local reason = tsivtools.Input('Kick reason', '', 120)
                    if not reason then return end
                    tsivtools.Action('player.kick', { target = target, reason = reason })
                end)
            end)
        end)
    end

    if can('player.ban') then
        menu:Button('Ban', 'duration is minutes, 0 for permanent !', function()
            withTarget(function(target)
                CreateThread(function()
                    local minutes = tsivtools.InputNumber('Ban length in minutes (0 = permanent)', '0', 8)
                    if minutes == nil then return end
                    local reason = tsivtools.Input('Ban reason', '', 150)
                    if not reason then return end
                    tsivtools.Action('player.ban', { target = target, minutes = minutes, reason = reason })
                end)
            end)
        end)
    end

    if can('player.identifiers') then
        menu:Button('Identifiers', 'Print the players identifiers in the console !', function()
            withTarget(function(target)
                CreateThread(function()
                    tsivtools.ShowBlock(tsivtools.Request('player.identifiers', { target = target }))
                end)
            end)
        end)
    end

    if can('player.watchlist') then
        menu:Button('Add player to watchlist', 'Enter a user ID !', function()
            withTarget(function(target)
                CreateThread(function()
                    local note = tsivtools.Input('Watchlist note', '', 160)
                    if note then tsivtools.Action('watchlist.add', { target = target, note = note }) end
                end)
            end)
        end)
        local function ask(title, length, send)
            CreateThread(function()
                local text = tsivtools.Input(title, '', length)
                if text then send(text) end
            end)
        end

        local function watchMenu(online)
            local sub = tsivtools.Menu.Create(online and 'Online watchlisted players' or 'All watchlisted players', 'Press Enter for actions !')
            sub.onOpen = function() CreateThread(function()
                local list = tsivtools.Request('watchlist.list', { online = online })
                sub:Clear()
                if not list or #list == 0 then sub:Label('No watchlisted players.')
                else
                    for _, entry in ipairs(list) do
                        local item = sub:Button(('%s%s'):format(entry.online and ('[%d] '):format(entry.online) or '', entry.name),
                            entry.note or entry.identifier, function()
                                local actions = tsivtools.Menu.Create(entry.name, entry.identifier)
                                actions:Button('Remove watchlist', 'Stop monitoring this player !', function()
                                    tsivtools.Action('watchlist.remove', { identifier = entry.identifier }); tsivtools.Menu.Back()
                                end)
                                actions:Button('Get identifiers', 'Print identifiers to console !', function()
                                    local lines = { entry.identifier }
                                    for kind, value in pairs(entry.identifiers or {}) do lines[#lines + 1] = kind .. ': ' .. value end
                                    tsivtools.ShowBlock({ title = entry.name .. ' identifiers', lines = lines })
                                end)
                                actions:Button('Get Discord ID', 'Print the Discord ID !', function()
                                    local discord = entry.identifiers and entry.identifiers.discord or 'not recorded'
                                    tsivtools.ShowBlock({ title = entry.name .. ' Discord', lines = { discord } })
                                end)
                                local target = entry.online
                                if target then
                                    if can('player.spectate') then
                                        actions:Button('Spectate', 'Spectate this player !', function() tsivtools.Action('player.spectate', { target = target }) end)
                                    end
                                    if can('player.goto') then
                                        actions:Button('Goto', 'Teleport to this player !', function() tsivtools.Action('player.goto', { target = target }) end)
                                    end
                                    if can('player.bring') then
                                        actions:Button('Bring', 'Bring this player !', function() tsivtools.Action('player.bring', { target = target }) end)
                                    end
                                    if can('player.warn') then
                                        actions:Button('Warn', 'Warn this player !', function()
                                            ask('Warning reason', 120, function(reason) tsivtools.Action('player.warn', { target = target, reason = reason }) end)
                                        end)
                                    end
                                    if can('player.ban') then
                                        actions:Button('Ban', 'Ban this player !', function()
                                            ask('Ban reason', 150, function(reason) tsivtools.Action('player.ban', { target = target, minutes = 0, reason = reason }) end)
                                        end)
                                    end
                                elseif can('player.ban') then
                                    actions:Button('Offline Ban', 'Ban this player using his identifiers !', function()
                                        ask('Ban reason', 150, function(reason)
                                            tsivtools.Action('watchlist.ban', { identifiers = entry.identifiers, name = entry.name, reason = reason })
                                        end)
                                    end)
                                end
                                tsivtools.Menu.Push(actions)
                            end)
                        item.right = entry.online and 'online' or 'offline'
                    end
                end
                tsivtools.Menu.Refresh()
            end) end
            tsivtools.Menu.Push(sub)
        end
        if not player then
            menu:Button('Online watchlisted players', 'search online watchlisted players !', function() watchMenu(true) end)
            menu:Button('All watchlisted players', 'search all watchlisted players !', function() watchMenu(false) end)
        end
    end

    if can('player.tags') then
        menu:Button('Add player tag', '30m, 2h, 7d, permanent.', function()
            withTarget(function(target)
                CreateThread(function()
                    local time = tsivtools.Input('Duration', 'permanent', 24)
                    local content = time and tsivtools.Input('Tag content', '', 160)
                    if time and content then tsivtools.Action('player.tag', { target = target, duration = time, content = content }) end
                end)
            end)
        end)
    end

    if can('player.rating') then
        menu:Button('Player rating', 'Show logs, bans, warns, alerts and history for an ID !', function()
            withTarget(function(target)
                tsivtools.ShowBlock(tsivtools.Request('player.rating', { target = target }))
            end)
        end)
    end

    if can('player.aliases') then
        menu:Button('Player aliases', 'Show all names and Steam accounts linked to an ID !', function()
            withTarget(function(target)
                tsivtools.ShowBlock(tsivtools.Request('player.aliases', { target = target }))
            end)
        end)
    end

    if can('player.relationships') and not player then
        menu:Button('Link player to another', 'Enter the current player ID, then the related player ID !', function()
            CreateThread(function()
                local target = tsivtools.InputNumber('Current player ID', '', 6)
                if not target then return end
                local related = tsivtools.InputNumber('Related player ID', '', 6)
                if not related then return end
                local note = tsivtools.Input('Relationship note', '', 160)
                if note then tsivtools.Action('player.link', { target = target, related = related, note = note }) end
            end)
        end)
    end

    if can('player.setrank') then
        local values = {}
        for _, rank in ipairs(tsivtools.Ranks()) do
            values[#values + 1] = { label = rank.label, value = rank.name }
        end
        values[#values + 1] = { label = 'remove rank', value = 'none' }

        menu:List('Set staff group',
            'Use arrowkeys to select a group, press enter to set that group to the user !',
            values, function(value)
                withTarget(function(target)
                    tsivtools.Action('player.setrank', { target = target, rank = value })
                end)
            end)
    end

    if can('player.unban') and not player then
        local bans = tsivtools.Menu.Create('Active bans', 'Select a ban to remove it !')
        bans.onOpen = function()
            CreateThread(function()
                bans:Clear()
                bans:Button('Search by name or identifier', 'Find a specific players ban', function()
                    CreateThread(function()
                        local query = tsivtools.Input('Search bans', '', 64)
                        if not query then return end
                        bans.query = query
                        bans.onOpen()
                    end)
                end)

                local list = tsivtools.Request('bans.list', { query = bans.query })
                if not list or #list == 0 then
                    bans:Label('No active bans.')
                else
                    for _, ban in ipairs(list) do
                        bans:Button(('#%s  %s'):format(ban.id, ban.name ~= '' and ban.name or ban.identifier),
                            ('%s  /  expires %s  /  by %s'):format(ban.reason, ban.expiresText, ban.bannedBy),
                            function()
                                tsivtools.Action('player.unban', { banId = ban.id })
                                bans.onOpen()
                            end)
                    end
                end
                tsivtools.Menu.Refresh()
            end)
        end
        menu:Attach('Bans', 'Browse bans !', bans)
    end
end

local function buildSecurity(menu)
    if not can('security.view') then return end
    menu:Button('Overview', 'Live security dashboard !', function()
        CreateThread(function() tsivtools.ShowBlock(tsivtools.Request('security.status')) end)
    end)
    menu:Button('Live Alerts', 'Live security alerts from TsivTools and WaveShield !', function()
        CreateThread(function()
            local alerts = tsivtools.Request('security.alerts')
            local sub = tsivtools.Menu.Create('Live Alerts', 'Select an alert for actions !')
            for _, alert in ipairs(alerts or {}) do
                local item = sub:Button(('[%s] %s'):format(alert.severity:upper(), alert.name),
                    ('%s | risk %d/100'):format(alert.kind, alert.risk), function()
                        local actions = tsivtools.Menu.Create(alert.name, 'Security response')
                        actions:Button('Investigate', 'Open a player security profile !', function()
                            CreateThread(function()
                                tsivtools.ShowBlock(tsivtools.Request('security.profile', { target = alert.target }))
                            end)
                        end)
                        if can('player.spectate') then
                            actions:Button('Spectate', 'spectate this alert !', function()
                                tsivtools.Action('player.spectate', { target = alert.target })
                            end)
                        end
                        tsivtools.Menu.Push(actions)
                    end)
                item.right = ('%d/100'):format(alert.risk)
            end
            if #sub.items == 0 then sub:Label('No active alerts.') end
            tsivtools.Menu.Push(sub)
        end)
    end)
    menu:Button('WaveShield', 'WaveShield integration status !', function()
        CreateThread(function() tsivtools.ShowBlock(tsivtools.Request('security.waveshield')) end)
    end)
    menu:Button('Verify WaveShield Server Integration', 'Checks the API credentials ! (if not owner, please report to Dev !!)', function()
        CreateThread(function() tsivtools.ShowBlock(tsivtools.Request('security.waveshield.verify')) end)
    end)
    menu:Button('WaveShield Detection Feed', 'Recent logs from Wave !', function()
        CreateThread(function() tsivtools.ShowBlock(tsivtools.Request('security.waveshield.logs')) end)
    end)
    local wavePlayers = tsivtools.Menu.Create('WaveShield Online Players', 'Press Enter for their WaveShield profile !')
    wavePlayers.onOpen = function()
        CreateThread(function()
            local result = tsivtools.Request('security.waveshield.players')
            wavePlayers:Clear()
            if not result or result.error then
                wavePlayers:Label('Unavailable: ' .. (result and result.error or 'no answer from the server'))
            elseif #result.players == 0 then
                wavePlayers:Label('No WaveShield online players were returned.')
            else
                for _, player in ipairs(result.players) do
                    wavePlayers:Button(player.name, player.license, function()
                        CreateThread(function()
                            tsivtools.ShowBlock(tsivtools.Request('security.waveshield.profile', { identifier = player.license }))
                        end)
                    end)
                end
                wavePlayers.subtitle = ('%d reported by WaveShield'):format(#result.players)
            end
            tsivtools.Menu.Refresh()
        end)
    end
    menu:Attach('WaveShield Online Players', 'Players currently reported by WaveShield !', wavePlayers)
    if can('security.waveshield.ban') then
        menu:Button('WaveShield Ban Player', 'Wave Ban a player !', function()
            withTarget(function(target)
                CreateThread(function()
                    local duration = tsivtools.InputNumber('WaveShield duration (0 = permanent)', '0', 10)
                    if duration == nil then return end
                    local reason = tsivtools.Input('WaveShield ban reason', '', 150)
                    if reason then
                        tsivtools.Action('security.waveshield.ban', {
                            target = target, duration = math.floor(duration), reason = reason,
                        })
                    end
                end)
            end)
        end)
    end
    if can('security.waveshield.unban') then
        menu:Button('WaveShield Bans', 'View active WaveShield bans !', function()
            CreateThread(function() tsivtools.ShowBlock(tsivtools.Request('security.waveshield.bans')) end)
        end)
        menu:Button('WaveShield Unban', 'Remove a Wave ban by ban ID !', function()
            CreateThread(function()
                local banId = tsivtools.Input('WaveShield ban ID', '', 128)
                if banId and banId ~= '' then
                    tsivtools.Action('security.waveshield.unban', { banId = banId })
                end
            end)
        end)
    end
    menu:Button('WaveShield Health', 'WaveShield, TsivTools and server health !', function()
        CreateThread(function() tsivtools.ShowBlock(tsivtools.Request('security.health')) end)
    end)
    local severities = { 'all', 'critical', 'high', 'medium', 'low' }
    local kinds = { 'all', 'aim', 'injection', 'event abuse', 'entity abuse', 'explosion abuse', 'vehicle abuse' }
    local function feed(title, values, field)
        local sub = tsivtools.Menu.Create(title, 'Select a filter and press Enter !')
        for _, value in ipairs(values) do
            sub:Button(value:upper(), 'Print matching detections !!', function()
                CreateThread(function() tsivtools.ShowBlock(tsivtools.Request('security.detections', { [field] = value })) end)
            end)
        end
        tsivtools.Menu.Push(sub)
    end
    menu:Button('TsivTools Detections', 'Filter by severity !', function() feed('Detection severity', severities, 'severity') end)
    menu:Button('Detection Type Filter', 'Filter by detection category !', function() feed('Detection type', kinds, 'kind') end)
    menu:Button('Active Incidents', 'Players with current security activity !', function()
        CreateThread(function() tsivtools.ShowBlock(tsivtools.Request('security.status')) end)
    end)
    menu:Button('Security Statistics', 'Cheater statistics !', function()
        CreateThread(function() tsivtools.ShowBlock(tsivtools.Request('security.statistics')) end)
    end)
end

local function buildVehicles(menu)
    if can('vehicle.spawn') then
        if #Config.vehiclelist > 0 then
            local list = tsivtools.Menu.Create('Spawn a vehicle', 'Select a a vehicle to spawn !')
            for _, entry in ipairs(Config.vehiclelist) do
                list:Button(entry.label, entry.model, function()
                    tsivtools.Action('vehicle.spawn', { model = entry.model })
                end)
            end
            menu:Attach('Spawn from the list', 'Certain popular vehicles are in this list !', list)
        end

        menu:Button('Spawn by model name', 'Use any model available in the server !', function()
            CreateThread(function()
                local model = tsivtools.Input('Vehicle model name', '', 32)
                if not model then return end
                tsivtools.Action('vehicle.spawn', { model = model })
            end)
        end)
    end

    if can('vehicle.repair') then
        menu:Button('Repair', 'repairs the nearest vehicle !!', function()
            tsivtools.Action('vehicle.repair', {})
        end)
    end

    if can('vehicle.refuel') then
        menu:Button('Refuel', 'refuels the nearest vehicle !!', function()
            tsivtools.Action('vehicle.refuel', {})
        end)
    end

    if can('vehicle.flip') then
        menu:Button('Flip', 'flips a vehicle back on its wheels !', function()
            tsivtools.Action('vehicle.flip', {})
        end)
    end

    if can('vehicle.delete') then
        menu:Button('Delete aimed vehicle', 'Aim at a vehicle and press enter !', function()
            tsivtools.Action('vehicle.delete', {})
        end)
    end

    if can('vehicle.dvarea') then
        radiusList(menu, 'Delete vehicles in a radius',
            'use arrowkeys to select radius, occupied vehicles will not be included',
            function(radius)
                tsivtools.Action('cleanup.area', { kind = 'vehicles', radius = radius })
            end)

        radiusList(menu, 'Delete vehicles in a radius, including occupied',
            'use arrowkeys to select radius !',
            function(radius)
                tsivtools.Action('cleanup.area', { kind = 'vehicles', radius = radius, includeOccupied = true })
            end)
    end

    if can('vehicle.dvall') then
        menu:Button('Delete every vehicle on the map', 'occupied vehicles are left untouched, all staff get alerted with this !!!', function()
            tsivtools.Action('cleanup.area', { kind = 'vehicles', all = true })
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
            'Every prop spawned in the server gets logged in console !',
            permissions.propLogging, function(state)
                tsivtools.Action('prop.toggleproplog', { state = state })
            end)
    end

    if can('prop.spawn') then
        menu:Button('Spawn a prop', 'self explainatory !', function()
            CreateThread(function()
                local model = tsivtools.Input('Prop model name', '', 48)
                if not model or model == '' then return end
                tsivtools.Action('prop.spawn', { model = model })
            end)
        end)
    end

    if can('world.traffic') then
        local state = (permissions and permissions.traffic) or {}
        for _, entry in ipairs(trafficLabels) do
            menu:Checkbox(entry.label, 'Applies to everyone on the server !', state[entry.key] == true,
                function(checked)
                    tsivtools.Action('world.traffic', { key = entry.key, state = checked })
                end)
        end
    end

    if can('world.cleartraffic') then
        menu:Button('Clear traffic now', 'Deletes cars and peds the game spawned, not yours !', function()
            tsivtools.Action('world.cleartraffic', {})
        end)
    end

    if can('prop.deletenearest') then
        menu:Button('Delete aimed prop', 'TsivTools :))', function()
            local entity = tsivtools.RaycastEntity(30.0)
            if not entity or GetEntityType(entity) ~= 3 then
                entity = tsivtools.ClosestObject(10.0)
            end
            tsivtools.DeleteEntityViaServer(entity, 'props')
        end)
    end

    if can('prop.deletearea') then
        radiusList(menu, 'Delete props in a radius',
            'use arrowkeys to select radius !',
            function(radius)
                tsivtools.Action('cleanup.area', { kind = 'props', radius = radius })
            end)

        radiusList(menu, 'Delete spawned peds in a radius',
            'use arrowkeys to select radius !!',
            function(radius)
                tsivtools.Action('cleanup.area', { kind = 'peds', radius = radius })
            end)
    end

    if can('prop.deleteall') then
        menu:Button('Delete every prop on the map', 'all staff get informed about this action !!!', function()
            tsivtools.Action('cleanup.area', { kind = 'props', all = true })
        end)
    end

    if can('prop.deleteplayer') then
        menu:Button('Delete everything a player spawned',
            'Deletes all entities spawned from a player !!', function()
                choosePlayer('User ID:', function(player)
                    tsivtools.Action('cleanup.player', { target = player.id, kind = 'all' })
                end)
            end)

        menu:Button('Delete only the props a player spawned', 'TsivTools :))', function()
            choosePlayer('User ID: ', function(player)
                tsivtools.Action('cleanup.player', { target = player.id, kind = 'props' })
            end)
        end)
    end

    if can('staff.alerts') then
        menu:Button('anticheat status', 'prints live anticheat updates and settings to console !', function()
            CreateThread(function()
                tsivtools.ShowBlock(tsivtools.Request('anticheat.status'))
            end)
        end)
    end
end

local function askIdentifier(title, onGot)
    CreateThread(function()
        local value = tsivtools.Input(title, '', 80)
        if not value then return end
        onGot(value)
    end)
end

local function buildGarage(menu)
    if can('garage.lookup') then
        menu:Button('Look up a garage', 'prints all owned vehicles by a user in the console !', function()
            choosePlayer('User ID:', function(player)
                CreateThread(function()
                    tsivtools.ShowBlock(tsivtools.Request('garage.lookup', { target = player.id }))
                end)
            end)
        end)

        menu:Button('Look up a garage by identifier', 'made for offline use ! steam ID or License key :)', function()
            askIdentifier('Identifier', function(identifier)
                CreateThread(function()
                    tsivtools.ShowBlock(tsivtools.Request('garage.lookup', { target = identifier }))
                end)
            end)
        end)
    end

    if can('garage.give') then
        menu:Button('Give a vehicle to a garage', 'TsivTools :))', function()
            choosePlayer('user ID: ', function(player)
                CreateThread(function()
                    local model = tsivtools.Input('Vehicle model name', '', 32)
                    if not model then return end
                    local plate = tsivtools.Input('Plate (leave empty to generate one)', '', 8)
                    tsivtools.Action('garage.give', { target = player.id, model = model, plate = plate })
                end)
            end)
        end)
    end

    if can('garage.remove') then
        menu:Button('Remove a vehicle from a garage', 'TsivTools :))', function()
            choosePlayer('user ID: ', function(player)
                CreateThread(function()
                    local plate = tsivtools.Input('Plate to remove: ', '', 8)
                    if not plate then return end
                    tsivtools.Action('garage.remove', { target = player.id, plate = plate })
                end)
            end)
        end)

        menu:Button('Remove by identifier and plate', 'for offline use !', function()
            askIdentifier('Identifier', function(identifier)
                CreateThread(function()
                    local plate = tsivtools.Input('Plate to remove', '', 8)
                    if not plate then return end
                    tsivtools.Action('garage.remove', { target = identifier, plate = plate })
                end)
            end)
        end)
    end
end

local function buildStaff(menu)
    if can('staff.online') then
        menu:Button('Online staff', 'Prints all online staff to console !!', function()
            CreateThread(function()
                tsivtools.ShowBlock(tsivtools.Request('staff.online'))
            end)
        end)
    end

    if can('staff.chat') then
        menu:Button('Staff chat', 'Send a message only staff can see !!', function()
            CreateThread(function()
                local message = tsivtools.Input('Staff chat', '', 180)
                if not message or message == '' then return end
                tsivtools.Action('staff.chat', { message = message })
            end)
        end)
    end

    if can('staff.announce') then
        menu:Button('Announce to the server', 'TsivTools :))', function()
            CreateThread(function()
                local message = tsivtools.Input('Announcement', '', 180)
                if not message or message == '' then return end
                tsivtools.Action('staff.announce', { message = message })
            end)
        end)
    end

    if can('staff.logs') then
        menu:Button('Look up an identifier', 'Steam ID, License or name !', function()
            askIdentifier('Identifier or name: ', function(query)
                CreateThread(function()
                    tsivtools.ShowBlock(tsivtools.Request('logs.lookup', { query = query, limit = 40 }))
                end)
            end)
        end)

        menu:Button('Look up user ID', 'Get identifiers and logs from a user ID !', function()
            withTarget(function(target)
                CreateThread(function()
                    local details = tsivtools.Request('player.identifiers', { target = target })
                    local query = details and details.identifier or tostring(target)
                    tsivtools.ShowBlock(tsivtools.Request('logs.lookup', { query = query, limit = 40 }))
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
                tsivtools.ShowBlock(tsivtools.Request('logs.recent', { category = value, limit = 40 }))
            end)
        end)
    end

    if can('staff.serverinfo') then
        menu:Button('Server info', 'Player entity and resource count !', function()
            CreateThread(function()
                tsivtools.ShowBlock(tsivtools.Request('staff.serverinfo'))
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
    security = buildSecurity,
}

local descriptions = {
    self    = 'TsivTools :))',
    players = 'TsivTools :))',
    vehicle = 'TsivTools :))',
    props   = 'TsivTools :))',
    garage  = 'TsivTools :))',
    staff   = 'TsivTools :))',
    security = 'TsivTools :))',
}

local function buildRoot()
    root = tsivtools.Menu.Create('tsivtools', ('%s  /  %s'):format(
        GetPlayerName(PlayerId()), permissions.rankLabel))

    for _, entry in ipairs(Config.menusections) do
        local builder = builders[entry.id]
        if builder then
            section(root, entry.label, descriptions[entry.id] or '', builder)
        end
    end

    if #root.items == 0 then
        root:Label('You are not allowed to use TsivTools :)) ')
    end
end

local function sameAccess(a, b)
    if not a or not b or a.rank ~= b.rank then return false end
    for key in pairs(a.granted) do
        if not b.granted[key] then return false end
    end
    for key in pairs(b.granted) do
        if not a.granted[key] then return false end
    end
    return true
end

RegisterNetEvent(tsivtools.Events.permissions, function(payload)
    local previous = permissions
    permissions = payload

    if payload and payload.traffic then
        tsivtools.ApplyTraffic(payload.traffic)
    end

    if not permissions then
        root = nil
        if tsivtools.Menu.IsOpen() then tsivtools.Menu.Close() end
        return
    end

    if tsivtools.Menu.IsOpen() then
        if sameAccess(previous, permissions) then return end
        buildRoot()
        tsivtools.Menu.Open(root)
        return
    end

    buildRoot()
end)

local function askForPermissions()
    TriggerServerEvent(tsivtools.Events.ready)
end

AddEventHandler('playerSpawned', askForPermissions)

CreateThread(function()
    Wait(2000)
    askForPermissions()
end)

local function toggleMenu()
    if tsivtools.Menu.IsOpen() then
        tsivtools.Menu.Close()
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
    tsivtools.Menu.Open(root)
end

RegisterCommand(Config.menucommand, function()
    CreateThread(toggleMenu)
end, false)

RegisterKeyMapping(Config.menucommand, 'TsivTools :))', 'keyboard', Config.menukey)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= tsivtools.resource then return end
    if tsivtools.Menu.IsOpen() then tsivtools.Menu.Close() end
    if tsivtools.State.noclip then tsivtools.ToggleNoclip(false) end
    if tsivtools.State.spectating then tsivtools.StopSpectating() end
end)
