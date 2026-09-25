local Logs = tsivtools.Logs

local function settings()
    return tsivtools.Storage.Get('settings')
end

function tsivtools.Setting(key, default)
    local value = settings()[key]
    if value == nil then return default end
    return value
end

function tsivtools.SetSetting(key, value)
    settings()[key] = value
    tsivtools.Storage.MarkDirty('settings')
    tsivtools.Storage.Flush('settings')
end

function tsivtools.PropLoggingEnabled()
    return tsivtools.Setting('logPropSpawns', Config.AntiCheat.logPropSpawns) and true or false
end

local function staffStore()
    return tsivtools.Storage.Get('staff')
end

function tsivtools.StaffStore()
    return staffStore()
end

local function run(target, command, payload)
    TriggerClientEvent(tsivtools.Events.run, target, command, payload or {})
end

local function pedCoords(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function distance(a, b)
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z))
end

tsivtools.RegisterRequest('player.list', 'player.list', function(src)
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        local ped = GetPlayerPed(id)
        local rank = tsivtools.GetRank(id)
        out[#out + 1] = {
            id = id,
            name = tsivtools.GetName(id),
            rank = rank or nil,
            rankLabel = rank and tsivtools.RankLabel(rank) or nil,
            ping = GetPlayerPing(id),
            health = ped ~= 0 and GetEntityHealth(ped) or 0,
        }
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end)

tsivtools.RegisterRequest('player.identifiers', 'player.identifiers', function(src, payload)
    local target = tsivtools.ResolveTarget(payload.target)
    if not target then
        return { title = 'TsivTools', lines = { 'Player isnt Online !' } }
    end

    local lines = {
        ('name : %s'):format(tsivtools.GetName(target)),
        ('id   : %s'):format(target),
        ('rank : %s'):format(tsivtools.GetRank(target) or 'none'),

    }
    for kind, identifier in pairs(tsivtools.GetIdentifiers(target)) do
        lines[#lines + 1] = ('%-8s %s'):format(kind, identifier)
    end

    Logs.Staff(src, ('Got identifiers of: %s'):format(tsivtools.Describe(target)), target)

    return {
        title = ('tsivtools identifiers: %s'):format(tsivtools.GetName(target)),
        lines = lines,
        identifier = tsivtools.GetPrimaryIdentifier(target),
        steam = tsivtools.GetSteamId(target),
    }
end)

tsivtools.RegisterAction('player.goto', 'player.goto', function(src, payload)
    local target = tsivtools.ResolveTarget(payload.target)
    if not target then
        tsivtools.Notify(src, 'Player isnt online !', 'error')
        return
    end

    local coords = pedCoords(target)
    if not coords then
        tsivtools.Notify(src, 'Unavailable ped !', 'error')
        return
    end

    run(src, 'teleport', { x = coords.x, y = coords.y + 1.0, z = coords.z })
    tsivtools.Notify(src, ('Teleported to %s'):format(tsivtools.GetName(target)), 'success')
    Logs.Staff(src, ('Teleported to %s'):format(tsivtools.Describe(target)), target)
end)

tsivtools.RegisterAction('player.bring', 'player.bring', function(src, payload)
    local target = tsivtools.ResolveTarget(payload.target)
    if not target then
        tsivtools.Notify(src, 'Player isnt online !', 'error')
        return
    end

    local coords = pedCoords(src)
    if not coords then return end

    run(target, 'teleport', { x = coords.x, y = coords.y + 1.0, z = coords.z })
    tsivtools.Notify(target, ('%s brought you'):format(tsivtools.GetName(src)), 'info')
    tsivtools.Notify(src, ('Brought %s to you'):format(tsivtools.GetName(target)), 'success')
    Logs.Staff(src, ('Brought %s'):format(tsivtools.Describe(target)), target)
end)

tsivtools.RegisterAction('player.spectate', 'player.spectate', function(src, payload)
    local target = tsivtools.ResolveTarget(payload.target)
    if not target then
        run(src, 'spectate', { stop = true })
        return
    end

    run(src, 'spectate', { target = target, name = tsivtools.GetName(target) })
    Logs.Staff(src, ('Started spectating %s'):format(tsivtools.Describe(target)), target)
end)

local function simpleTargetAction(action, permission, command, message, logLine)
    tsivtools.RegisterAction(action, permission, function(src, payload)
        local target = tsivtools.ResolveTarget(payload.target)
        if not target then
            tsivtools.Notify(src, 'Player isnt online !', 'error')
            return
        end

        run(target, command, payload)
        tsivtools.Notify(src, message:format(tsivtools.GetName(target)), 'success')
        Logs.Staff(src, logLine:format(tsivtools.Describe(target)), target)
    end)
end

simpleTargetAction('player.revive', 'player.revive', 'revive', 'Revived %s', 'Revived %s')
simpleTargetAction('player.heal',   'player.heal',   'heal',   'Healed %s',  'Healed %s')
simpleTargetAction('player.slay',   'player.slay',   'slay',   'Slayed %s',  'Slayed %s')

tsivtools.RegisterAction('player.freeze', 'player.freeze', function(src, payload)
    local target = tsivtools.ResolveTarget(payload.target)
    if not target then
        tsivtools.Notify(src, 'Player isnt online !', 'error')
        return
    end

    local frozen = payload.state and true or false
    run(target, 'freeze', { state = frozen })
    tsivtools.Notify(target, frozen and 'You have been frozen by staff !' or 'You have been unfrozen :)', 'info')
    tsivtools.Notify(src, ('%s %s'):format(frozen and 'Froze' or 'Unfroze', tsivtools.GetName(target)), 'success')
    Logs.Staff(src, ('%s %s'):format(frozen and 'Froze' or 'Unfroze', tsivtools.Describe(target)), target)
end)

tsivtools.RegisterAction('player.kick', 'player.kick', function(src, payload)
    local target = tsivtools.ResolveTarget(payload.target)
    if not target then
        tsivtools.Notify(src, 'Player isnt online !', 'error')
        return
    end

    local reason = tsivtools.SafeString(payload.reason, 200)
    if reason == '' then reason = 'No reason given' end

    local name = tsivtools.GetName(target)
    local identifier = tsivtools.GetPrimaryIdentifier(target)

    Logs.Staff(src, ('Kicked %s - %s'):format(tsivtools.Describe(target), reason), identifier)
    DropPlayer(target, ('Kicked by staff !\n\nReason: %s'):format(reason))

    tsivtools.Notify(src, ('Kicked %s'):format(name), 'success')
    tsivtools.StaffBroadcast('mod', ('%s%s kicked %s (%s)'):format(Config.Prefix, tsivtools.GetName(src), name, reason))
end)

tsivtools.RegisterAction('player.warn', 'player.warn', function(src, payload)
    local target = tsivtools.ResolveTarget(payload.target)
    if not target then
        tsivtools.Notify(src, 'Player isnt online !', 'error')
        return
    end

    local reason = tsivtools.SafeString(payload.reason, 200)
    if reason == '' then reason = 'No reason given' end

    run(target, 'warn', { reason = reason, by = tsivtools.GetName(src) })
    tsivtools.Notify(src, ('Warned %s'):format(tsivtools.GetName(target)), 'success')
    Logs.Staff(src, ('Warned %s - %s'):format(tsivtools.Describe(target), reason), target)
end)

tsivtools.RegisterAction('player.setrank', 'player.setrank', function(src, payload)
    local target = tsivtools.ResolveTarget(payload.target)
    if not target then
        tsivtools.Notify(src, 'Player isnt online !', 'error')
        return
    end

    local rank = tsivtools.SafeString(payload.rank, 24):lower()
    if rank ~= 'none' and not tsivtools.RankExists(rank) then
        tsivtools.Notify(src, ('"%s" isnt staff !'):format(rank), 'error')
        return
    end

    if rank ~= 'none' and src ~= 0 and tsivtools.RankLevel(rank) > tsivtools.RankLevel(tsivtools.GetRank(src)) then
        tsivtools.Notify(src, ('%s is above your rank !'):format(tsivtools.RankLabel(rank)), 'error')
        return
    end

    local identifier = tsivtools.GetPrimaryIdentifier(target)
    local store = staffStore()

    if rank == 'none' then
        store[identifier] = nil
    else
        store[identifier] = rank
    end
    tsivtools.Storage.MarkDirty('staff')
    tsivtools.Storage.Flush('staff')

    tsivtools.ClearRankCache(target)
    tsivtools.SendPermissions(target)

    tsivtools.Notify(src, ('Set %s to %s'):format(tsivtools.GetName(target), rank), 'success')
    tsivtools.Notify(target, ('Your new rank: %s'):format(rank), 'info')

    Logs.Staff(src, ('Set the rank of %s to %s'):format(tsivtools.Describe(target), rank), identifier,
        { rank = rank, identifier = identifier })
end)

local selfStates = {
    ['self.godmode']   = 'God mode',
    ['self.invisible'] = 'Invisibility',
    ['self.noclip']    = 'Noclip',
}

tsivtools.RegisterAction('self.state', nil, function(src, payload)
    local key = payload.key
    if not selfStates[key] then return end
    if not tsivtools.Can(src, key) then
        tsivtools.Notify(src, 'You dont have permission to do that !!', 'error')
        return
    end

    Logs.Staff(src, ('%s %s'):format(selfStates[key], payload.state and 'on' or 'off'))
end)

tsivtools.RegisterAction('self.teleport', nil, function(src, payload)
    local x, y, z
    local saved = payload.saved ~= nil and Config.Teleports[tsivtools.ToInt(payload.saved, 1)]

    if payload.saved ~= nil then
        if not saved then return end
        if not tsivtools.Can(src, 'self.tpsaved') then
            tsivtools.Notify(src, 'You dont have permission to do that !!', 'error')
            return
        end
        x, y, z = saved.coords.x, saved.coords.y, saved.coords.z
    else
        if not tsivtools.Can(src, 'self.tpcoords') then
            tsivtools.Notify(src, 'You dont have permission to do that !!', 'error')
            return
        end
        x, y, z = tsivtools.ToNumber(payload.x), tsivtools.ToNumber(payload.y), tsivtools.ToNumber(payload.z)
        if not x or not y or not z then
            tsivtools.Notify(src, 'Those arent valid coordinates !', 'error')
            return
        end
    end

    run(src, 'teleport', { x = x, y = y, z = z })
    Logs.Staff(src, ('Teleported to %.1f, %.1f, %.1f'):format(x, y, z))
end)

tsivtools.RegisterAction('vehicle.spawn', 'vehicle.spawn', function(src, payload)
    local model = tsivtools.SafeString(payload.model, 32):lower()
    if model == '' then
        tsivtools.Notify(src, 'You need a model name !!', 'error')
        return
    end

    if tsivtools.AntiCheat.IsBlacklistedVehicle(model)
        and tsivtools.RankLevel(tsivtools.GetRank(src)) < tsivtools.RankLevel('superadmin') then
        tsivtools.Notify(src, ('%s is blacklisted !!'):format(model), 'error')
        return
    end

    run(src, 'spawnVehicle', { model = model, plate = tsivtools.SafeString(payload.plate, 8) })
    Logs.Staff(src, ('Spawned a %s'):format(model))
end)

local vehicleSelfActions = {
    ['vehicle.repair'] = { command = 'repairVehicle', message = 'Repaired your vehicle',  log = 'Repaired their vehicle' },
    ['vehicle.refuel'] = { command = 'refuelVehicle', message = 'Refuelled your vehicle', log = 'Refuelled their vehicle' },
    ['vehicle.flip']   = { command = 'flipVehicle',   message = 'Flipped your vehicle',   log = 'Flipped their vehicle' },
    ['vehicle.delete'] = { command = 'deleteVehicle', message = 'Deleted the vehicle',    log = 'Deleted the nearest vehicle' },
}

for key, entry in pairs(vehicleSelfActions) do
    tsivtools.RegisterAction(key, key, function(src)
        run(src, entry.command, {})
        tsivtools.Notify(src, entry.message, 'success')
        Logs.Staff(src, entry.log)
    end)
end

local cleanupKinds = {
    props = {
        permissionArea = 'prop.deletearea',
        permissionAll  = 'prop.deleteall',
        list           = function() return GetAllObjects() end,
        label          = 'prop',
    },
    vehicles = {
        permissionArea = 'vehicle.dvarea',
        permissionAll  = 'vehicle.dvall',
        list           = function() return GetAllVehicles() end,
        label          = 'vehicle',
    },
    peds = {
        permissionArea = 'prop.deletearea',
        permissionAll  = 'prop.deleteall',
        list           = function() return GetAllPeds() end,
        label          = 'ped',
    },
}

local function playerPedSet()
    local set = {}
    for _, id in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(tonumber(id))
        if ped and ped ~= 0 then set[ped] = true end
    end
    return set
end

local function cleanup(kind, origin, radius, skipOccupied)
    local entry = cleanupKinds[kind]
    if not entry then return 0 end

    local playerPeds = kind == 'peds' and playerPedSet() or nil
    local removed = 0

    for _, entity in ipairs(entry.list()) do
        if DoesEntityExist(entity) then
            local keep = false

            if kind == 'vehicles' and skipOccupied then
                for seat = -1, 6 do
                    if GetPedInVehicleSeat(entity, seat) ~= 0 then
                        keep = true
                        break
                    end
                end
            elseif kind == 'peds' then
                keep = playerPeds[entity] == true
            end

            if not keep then
                local inRange = true
                if origin and radius then
                    inRange = distance(origin, GetEntityCoords(entity)) <= radius
                end

                if inRange then
                    DeleteEntity(entity)
                    removed = removed + 1
                end
            end
        end
    end

    return removed
end

tsivtools.Cleanup = cleanup

tsivtools.RegisterAction('cleanup.area', nil, function(src, payload)
    local kind = payload.kind
    local entry = cleanupKinds[kind]
    if not entry then return end

    local all = payload.all and true or false
    local permission = all and entry.permissionAll or entry.permissionArea
    if not tsivtools.Can(src, permission) then
        tsivtools.Notify(src, 'You dont have permission to do that !!', 'error')
        return
    end

    local origin, radius
    if not all then
        radius = tsivtools.ToNumber(payload.radius)
        if not radius or radius <= 0 or radius > 2000 then
            tsivtools.Notify(src, 'Invalid radius :)', 'error')
            return
        end
        origin = pedCoords(src)
        if not origin then return end
    end

    local removed = cleanup(kind, origin, radius, payload.includeOccupied ~= true)

    local where = all and 'across the whole map' or ('within %dm'):format(math.floor(radius))
    tsivtools.Notify(src, ('Deleted %d %s(s) %s'):format(removed, entry.label, where), 'success')
    Logs.Staff(src, ('Deleted %d %s(s) %s'):format(removed, entry.label, where), nil,
        { kind = kind, radius = radius, all = all, removed = removed })

    if all or removed > 50 then
        tsivtools.StaffBroadcast('admin', ('%s%s deleted %d %s(s) %s'):format(
            Config.Prefix, tsivtools.GetName(src), removed, entry.label, where))
    end
end)

tsivtools.RegisterAction('cleanup.player', 'prop.deleteplayer', function(src, payload)
    local target = tsivtools.ResolveTarget(payload.target)
    if not target then
        tsivtools.Notify(src, 'Player isnt online !', 'error')
        return
    end

    local removed = tsivtools.AntiCheat.DeleteEntitiesOf(target, payload.kind)
    tsivtools.Notify(src, ('Deleted %d entity(s) created by %s'):format(removed, tsivtools.GetName(target)), 'success')
    Logs.Staff(src, ('Deleted %d entity(s) created by %s'):format(removed, tsivtools.Describe(target)), target)
end)

tsivtools.RegisterAction('entity.deleteNearest', nil, function(src, payload)
    local permission = payload.kind == 'vehicles' and 'vehicle.delete' or 'prop.deletenearest'
    if not tsivtools.Can(src, permission) then
        tsivtools.Notify(src, 'You dont have permission to do that.', 'error')
        return
    end

    local netId = tsivtools.ToInt(payload.netId, 1)
    if not netId then return end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        tsivtools.Notify(src, 'Entity no longer exists !!', 'error')
        return
    end

    local wanted = payload.kind == 'vehicles' and 2 or 3
    if GetEntityType(entity) ~= wanted or playerPedSet()[entity] then
        tsivtools.Notify(src, 'You can only delete props and vehicles with this !', 'error')
        return
    end

    local origin = pedCoords(src)
    local coords = GetEntityCoords(entity)
    if origin and distance(origin, coords) > 50.0 then
        tsivtools.Notify(src, 'Entity too far away !', 'error')
        return
    end

    local model = GetEntityModel(entity)
    DeleteEntity(entity)
    tsivtools.Notify(src, 'Entity deleted !!!', 'success')
    Logs.Staff(src, ('Deleted entity %s (model %s)'):format(netId, model))
end)

tsivtools.RegisterAction('prop.toggleproplog', 'prop.toggleproplog', function(src, payload)
    local state = payload.state and true or false
    tsivtools.SetSetting('logPropSpawns', state)

    tsivtools.Notify(src, ('Prop spawn logging is now %s'):format(state and 'ON' or 'OFF'), 'success')
    Logs.Staff(src, ('Turned prop spawn logging %s'):format(state and 'on' or 'off'))
    tsivtools.StaffBroadcast(Config.AntiCheat.propLogRank, ('%s%s turned prop spawn logging %s'):format(
        Config.Prefix, tsivtools.GetName(src), state and 'ON' or 'OFF'))

    for _, player in ipairs(GetPlayers()) do
        tsivtools.SendPermissions(tonumber(player))
    end
end)

tsivtools.RegisterRequest('staff.online', 'staff.online', function(src)
    local staff = tsivtools.GetStaff()
    local lines = {}

    if #staff == 0 then
        lines[1] = 'No staff online.'
    else
        lines[#lines + 1] = ('%-4s %-24s %-12s %s'):format('ID', 'NAME', 'RANK', 'IDENTIFIER')
        lines[#lines + 1] = ('-'):rep(76)
        for _, member in ipairs(staff) do
            lines[#lines + 1] = ('%-4s %-24s %-12s %s'):format(
                member.source, member.name:sub(1, 24), member.rankLabel, member.identifier)
        end
        lines[#lines + 1] = ('-'):rep(76)

        local counts = {}
        for _, member in ipairs(staff) do
            counts[member.rank] = (counts[member.rank] or 0) + 1
        end
        local summary = {}
        for _, rank in ipairs(tsivtools.Ranks()) do
            if counts[rank.name] then
                summary[#summary + 1] = ('%s: %d'):format(rank.label, counts[rank.name])
            end
        end
        lines[#lines + 1] = ('%d online  |  %s'):format(#staff, table.concat(summary, '   '))
    end

    return { title = 'TsivTools // online staff', lines = lines, staff = staff }
end)

local function staffChat(src, text)
    local message = tsivtools.SafeString(text, 200)
    if message == '' then return end

    local name = src == 0 and 'console' or tsivtools.GetName(src)
    local line = ('^5[staff]^7 ^3%s^7 (%s): %s'):format(name, tsivtools.RankLabel(tsivtools.GetRank(src)), message)

    for _, member in ipairs(tsivtools.GetStaff('mod')) do
        TriggerClientEvent('chat:addMessage', member.source, { args = { line }, multiline = true })
    end

    print(('%s[staff chat] %s: %s'):format(Config.ConsolePrefix, name, message))
    Logs.Write({
        category = 'chat',
        message = ('[staff chat] %s'):format(message),
        actor = src == 0 and 'console' or tsivtools.GetPrimaryIdentifier(src),
        actorName = name,
    })
end

tsivtools.RegisterAction('staff.chat', 'staff.chat', function(src, payload)
    staffChat(src, payload.message)
end)

tsivtools.RegisterAction('staff.announce', 'staff.announce', function(src, payload)
    local message = tsivtools.SafeString(payload.message, 200)
    if message == '' then return end

    TriggerClientEvent('chat:addMessage', -1, {
        args = { ('^1[ANNOUNCEMENT]^7 %s'):format(message) },
        multiline = true,
    })
    tsivtools.Notify(src, 'Announcement sent !!', 'success')
    Logs.Staff(src, ('Announced: %s'):format(message))
end)

tsivtools.RegisterRequest('staff.serverinfo', 'staff.serverinfo', function(src)
    local objects = GetAllObjects()
    local vehicles = GetAllVehicles()
    local peds = GetAllPeds()
    local players = GetPlayers()

    local uptime = math.floor(GetGameTimer() / 60000)

    local lines = {
        ('players       : %d'):format(#players),
        ('staff online  : %d'):format(#tsivtools.GetStaff()),
        ('objects       : %d'):format(#objects),
        ('vehicles      : %d'):format(#vehicles),
        ('peds          : %d'):format(#peds),
        ('resources     : %d'):format(GetNumResources()),
        ('storage       : %s'):format(tsivtools.Storage.UsingMysql() and 'mysql' or 'file'),
        ('prop logging  : %s'):format(tsivtools.PropLoggingEnabled() and 'on' or 'off'),
        ('uptime        : %d minute(s)'):format(uptime),
    }

    return { title = 'TsivTools // server info', lines = lines }
end)

local function commandPermission(src, key)
    if src == 0 then return true end
    if tsivtools.Can(src, key) then return true end
    tsivtools.Notify(src, 'You dont have permission to do that !!', 'error')
    return false
end

RegisterCommand('bring', function(src, args)
    if not commandPermission(src, 'player.bring') then return end
    local target = tsivtools.ResolveTarget(args[1])
    if not target then
        tsivtools.Notify(src, '/bring <id>', 'error')
        return
    end

    local coords = pedCoords(src)
    if coords then
        run(target, 'teleport', { x = coords.x, y = coords.y + 1.0, z = coords.z })
        tsivtools.Notify(target, ('%s brought you'):format(tsivtools.GetName(src)), 'info')
        tsivtools.Notify(src, ('Brought %s to you'):format(tsivtools.GetName(target)), 'success')
        Logs.Staff(src, ('Brought %s'):format(tsivtools.Describe(target)), target)
    end
end, false)

RegisterCommand('goto', function(src, args)
    if not commandPermission(src, 'player.goto') then return end
    local target = tsivtools.ResolveTarget(args[1])
    if not target then
        tsivtools.Notify(src, '/goto <id>', 'error')
        return
    end
    local coords = pedCoords(target)
    if coords then
        run(src, 'teleport', { x = coords.x, y = coords.y + 1.0, z = coords.z })
        Logs.Staff(src, ('Teleported to %s'):format(tsivtools.Describe(target)), target)
    end
end, false)

RegisterCommand('revive', function(src, args)
    if not commandPermission(src, 'player.revive') then return end
    local target = tsivtools.ResolveTarget(args[1]) or (src ~= 0 and src or nil)
    if not target then
        tsivtools.Notify(src, 'usage: /revive <server id>', 'error')
        return
    end
    run(target, 'revive', {})
    tsivtools.Notify(src, ('Revived %s'):format(tsivtools.GetName(target)), 'success')
    Logs.Staff(src, ('Revived %s'):format(tsivtools.Describe(target)), target)
end, false)

RegisterCommand('slay', function(src, args)
    if not commandPermission(src, 'player.slay') then return end
    local target = tsivtools.ResolveTarget(args[1])
    if not target then
        tsivtools.Notify(src, 'usage: /slay <server id>', 'error')
        return
    end
    run(target, 'slay', {})
    tsivtools.Notify(src, ('Slayed %s'):format(tsivtools.GetName(target)), 'success')
    Logs.Staff(src, ('Slayed %s'):format(tsivtools.Describe(target)), target)
end, false)

RegisterCommand('dv', function(src, args)
    if not commandPermission(src, 'vehicle.dvarea') then return end
    local radius = tsivtools.ToNumber(args[1]) or 10.0
    radius = math.min(math.max(radius, 1.0), 2000.0)
    local origin = pedCoords(src)
    if not origin then return end
    local removed = cleanup('vehicles', origin, radius, true)
    tsivtools.Notify(src, ('Deleted %d vehicle(s) within %dm'):format(removed, math.floor(radius)), 'success')
    Logs.Staff(src, ('Deleted %d vehicle(s) within %dm'):format(removed, math.floor(radius)))
end, false)

RegisterCommand('dp', function(src, args)
    if not commandPermission(src, 'prop.deletearea') then return end
    local radius = tsivtools.ToNumber(args[1]) or 10.0
    radius = math.min(math.max(radius, 1.0), 2000.0)
    local origin = pedCoords(src)
    if not origin then return end
    local removed = cleanup('props', origin, radius)
    tsivtools.Notify(src, ('Deleted %d prop(s) within %dm'):format(removed, math.floor(radius)), 'success')
    Logs.Staff(src, ('Deleted %d prop(s) within %dm'):format(removed, math.floor(radius)))
end, false)

RegisterCommand('staffchat', function(src, args)
    if not commandPermission(src, 'staff.chat') then return end
    staffChat(src, table.concat(args, ' '))
end, false)
