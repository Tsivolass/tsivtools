--[[
    tsivtools - server actions

    Everything the menu can do, other than bans, garages and log lookups, which
    live in their own files. Each entry is a TSIV.RegisterAction or
    TSIV.RegisterRequest, so the permission check has already happened by the
    time the function body runs.

    Adding an option is two steps: register it here, and add a row to the menu
    in client/main.lua. See docs/EXTENDING.md for a worked example.
]]

local Logs = TSIV.Logs

-- ---------------------------------------------------------------------------
-- Runtime settings
-- ---------------------------------------------------------------------------
-- A handful of config values can be flipped from inside the menu. They are
-- kept in data/settings.json so a restart does not undo them, and they take
-- priority over the matching config.lua value.

local function settings()
    return TSIV.Storage.Get('settings')
end

function TSIV.Setting(key, default)
    local value = settings()[key]
    if value == nil then return default end
    return value
end

function TSIV.SetSetting(key, value)
    settings()[key] = value
    TSIV.Storage.MarkDirty('settings')
    TSIV.Storage.Flush('settings')
end

--- Used by the anti-cheat and by the permission handshake.
function TSIV.PropLoggingEnabled()
    return TSIV.Setting('logPropSpawns', Config.AntiCheat.logPropSpawns) and true or false
end

-- ---------------------------------------------------------------------------
-- Runtime staff ranks
-- ---------------------------------------------------------------------------

local function staffStore()
    return TSIV.Storage.Get('staff')
end

--- Read by TSIV.GetRank in server/core.lua.
function TSIV.StaffStore()
    return staffStore()
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Ask a client to do something locally. The client only ever runs commands
--- from this fixed list, never arbitrary code.
local function run(target, command, payload)
    TriggerClientEvent(TSIV.Events.run, target, command, payload or {})
end

--- Server side coordinates of a player, without asking their client.
local function pedCoords(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function distance(a, b)
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z))
end

-- ---------------------------------------------------------------------------
-- Player list
-- ---------------------------------------------------------------------------

TSIV.RegisterRequest('player.list', 'player.list', function(src)
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        local ped = GetPlayerPed(id)
        local coords = ped ~= 0 and GetEntityCoords(ped) or vector3(0.0, 0.0, 0.0)
        local rank = TSIV.GetRank(id)
        out[#out + 1] = {
            id = id,
            name = TSIV.GetName(id),
            rank = rank or nil,
            rankLabel = rank and TSIV.RankLabel(rank) or nil,
            ping = GetPlayerPing(id),
            health = ped ~= 0 and GetEntityHealth(ped) or 0,
            coords = { x = coords.x, y = coords.y, z = coords.z },
        }
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end)

TSIV.RegisterRequest('player.identifiers', 'player.identifiers', function(src, payload)
    local target = TSIV.ResolveTarget(payload.target)
    if not target then
        return { title = 'tsivtools', lines = { 'That player is not online.' } }
    end

    local lines = {
        ('name  : %s'):format(TSIV.GetName(target)),
        ('id    : %s'):format(target),
        ('rank  : %s'):format(TSIV.GetRank(target) or 'none'),
        ('ping  : %sms'):format(GetPlayerPing(target)),
        ('-'):rep(60),
    }
    for kind, identifier in pairs(TSIV.GetIdentifiers(target)) do
        lines[#lines + 1] = ('%-8s %s'):format(kind, identifier)
    end

    Logs.Staff(src, ('Pulled the identifiers of %s'):format(TSIV.Describe(target)), target)

    return {
        title = ('tsivtools identifiers: %s'):format(TSIV.GetName(target)),
        lines = lines,
        -- Handed back as well as printed, so the log lookup can chain off it.
        identifier = TSIV.GetPrimaryIdentifier(target),
        steam = TSIV.GetSteamId(target),
    }
end)

-- ---------------------------------------------------------------------------
-- Moving people around
-- ---------------------------------------------------------------------------

TSIV.RegisterAction('player.goto', 'player.goto', function(src, payload)
    local target = TSIV.ResolveTarget(payload.target)
    if not target then
        TSIV.Notify(src, 'That player is not online.', 'error')
        return
    end

    local coords = pedCoords(target)
    if not coords then
        TSIV.Notify(src, 'That player has no ped yet.', 'error')
        return
    end

    run(src, 'teleport', { x = coords.x, y = coords.y + 1.0, z = coords.z })
    TSIV.Notify(src, ('Teleported to %s'):format(TSIV.GetName(target)), 'success')
    Logs.Staff(src, ('Teleported to %s'):format(TSIV.Describe(target)), target)
end)

TSIV.RegisterAction('player.bring', 'player.bring', function(src, payload)
    local target = TSIV.ResolveTarget(payload.target)
    if not target then
        TSIV.Notify(src, 'That player is not online.', 'error')
        return
    end
    if not TSIV.OutranksTarget(src, target) then
        TSIV.Notify(src, 'You cannot bring somebody of your own rank or higher.', 'error')
        return
    end

    local coords = pedCoords(src)
    if not coords then return end

    run(target, 'teleport', { x = coords.x, y = coords.y + 1.0, z = coords.z })
    TSIV.Notify(target, ('%s brought you to them.'):format(TSIV.GetName(src)), 'info')
    TSIV.Notify(src, ('Brought %s to you'):format(TSIV.GetName(target)), 'success')
    Logs.Staff(src, ('Brought %s'):format(TSIV.Describe(target)), target)
end)

TSIV.RegisterAction('player.spectate', 'player.spectate', function(src, payload)
    local target = TSIV.ResolveTarget(payload.target)
    if not target then
        -- No target means "stop spectating".
        run(src, 'spectate', { stop = true })
        return
    end

    run(src, 'spectate', { target = target, name = TSIV.GetName(target) })
    Logs.Staff(src, ('Started spectating %s'):format(TSIV.Describe(target)), target)
end)

-- ---------------------------------------------------------------------------
-- Doing things to people
-- ---------------------------------------------------------------------------

local function simpleTargetAction(action, permission, command, message, logLine, needsOutrank)
    TSIV.RegisterAction(action, permission, function(src, payload)
        local target = TSIV.ResolveTarget(payload.target)
        if not target then
            TSIV.Notify(src, 'That player is not online.', 'error')
            return
        end
        if needsOutrank and not TSIV.OutranksTarget(src, target) then
            TSIV.Notify(src, 'You cannot do that to somebody of your own rank or higher.', 'error')
            return
        end

        run(target, command, payload)
        TSIV.Notify(src, message:format(TSIV.GetName(target)), 'success')
        Logs.Staff(src, logLine:format(TSIV.Describe(target)), target)
    end)
end

simpleTargetAction('player.revive', 'player.revive', 'revive', 'Revived %s',        'Revived %s',        false)
simpleTargetAction('player.heal',   'player.heal',   'heal',   'Healed %s',         'Healed %s',         false)
simpleTargetAction('player.slay',   'player.slay',   'slay',   'Slayed %s',         'Slayed %s',         true)

TSIV.RegisterAction('player.freeze', 'player.freeze', function(src, payload)
    local target = TSIV.ResolveTarget(payload.target)
    if not target then
        TSIV.Notify(src, 'That player is not online.', 'error')
        return
    end
    if not TSIV.OutranksTarget(src, target) then
        TSIV.Notify(src, 'You cannot freeze somebody of your own rank or higher.', 'error')
        return
    end

    local frozen = payload.state and true or false
    run(target, 'freeze', { state = frozen })
    TSIV.Notify(target, frozen and 'You have been frozen by staff.' or 'You have been unfrozen.', 'info')
    TSIV.Notify(src, ('%s %s'):format(frozen and 'Froze' or 'Unfroze', TSIV.GetName(target)), 'success')
    Logs.Staff(src, ('%s %s'):format(frozen and 'Froze' or 'Unfroze', TSIV.Describe(target)), target)
end)

TSIV.RegisterAction('player.kick', 'player.kick', function(src, payload)
    local target = TSIV.ResolveTarget(payload.target)
    if not target then
        TSIV.Notify(src, 'That player is not online.', 'error')
        return
    end
    if not TSIV.OutranksTarget(src, target) then
        TSIV.Notify(src, 'You cannot kick somebody of your own rank or higher.', 'error')
        return
    end

    local reason = TSIV.SafeString(payload.reason, 200)
    if reason == '' then reason = 'No reason given' end

    local name = TSIV.GetName(target)
    local identifier = TSIV.GetPrimaryIdentifier(target)

    Logs.Staff(src, ('Kicked %s - %s'):format(TSIV.Describe(target), reason), identifier)
    DropPlayer(target, ('Kicked by staff.\n\nReason: %s'):format(reason))

    TSIV.Notify(src, ('Kicked %s'):format(name), 'success')
    TSIV.StaffBroadcast('mod', ('%s%s kicked %s (%s)'):format(Config.Prefix, TSIV.GetName(src), name, reason))
end)

TSIV.RegisterAction('player.warn', 'player.warn', function(src, payload)
    local target = TSIV.ResolveTarget(payload.target)
    if not target then
        TSIV.Notify(src, 'That player is not online.', 'error')
        return
    end

    local reason = TSIV.SafeString(payload.reason, 200)
    if reason == '' then reason = 'No reason given' end

    run(target, 'warn', { reason = reason, by = TSIV.GetName(src) })
    TSIV.Notify(src, ('Warned %s'):format(TSIV.GetName(target)), 'success')
    Logs.Staff(src, ('Warned %s - %s'):format(TSIV.Describe(target), reason), target)
end)

TSIV.RegisterAction('player.setrank', 'player.setrank', function(src, payload)
    local target = TSIV.ResolveTarget(payload.target)
    if not target then
        TSIV.Notify(src, 'That player is not online.', 'error')
        return
    end

    local rank = TSIV.SafeString(payload.rank, 24):lower()
    if rank ~= 'none' and not TSIV.RankExists(rank) then
        TSIV.Notify(src, ('"%s" is not a rank in Config.Ranks.'):format(rank), 'error')
        return
    end

    -- Nobody hands out a rank ABOVE their own. Granting your own rank is
    -- allowed, otherwise the top rank could never be given to anybody: an
    -- owner would be unable to make a second owner.
    if rank ~= 'none' and src ~= 0 and TSIV.RankLevel(rank) > TSIV.RankLevel(TSIV.GetRank(src)) then
        TSIV.Notify(src, ('You cannot grant %s. It is above your own rank (%s).')
            :format(TSIV.RankLabel(rank), TSIV.RankLabel(TSIV.GetRank(src))), 'error')
        return
    end
    if not TSIV.OutranksTarget(src, target) then
        TSIV.Notify(src, ('You cannot change the rank of %s. They are %s, the same as you or higher.')
            :format(TSIV.GetName(target), TSIV.RankLabel(TSIV.GetRank(target) or 'none')), 'error')
        return
    end

    local identifier = TSIV.GetPrimaryIdentifier(target)
    local store = staffStore()

    if rank == 'none' then
        store[identifier] = nil
    else
        store[identifier] = rank
    end
    TSIV.Storage.MarkDirty('staff')
    TSIV.Storage.Flush('staff')

    TSIV.ClearRankCache(target)
    TSIV.SendPermissions(target)

    TSIV.Notify(src, ('Set %s to %s'):format(TSIV.GetName(target), rank), 'success')
    TSIV.Notify(target, ('Your staff rank is now: %s'):format(rank), 'info')

    if rank ~= 'none' and src ~= 0 and TSIV.RankLevel(rank) == TSIV.RankLevel(TSIV.GetRank(src)) then
        TSIV.Notify(src, 'They now hold your rank, so neither of you can change the other.', 'warn')
    end
    Logs.Staff(src, ('Set the rank of %s to %s'):format(TSIV.Describe(target), rank), identifier,
        { rank = rank, identifier = identifier })

    if Config.Staff[identifier] then
        TSIV.Notify(src, 'Note: this identifier is also in Config.Staff, and the higher of the two ranks wins.', 'info')
    end
end)

-- ---------------------------------------------------------------------------
-- Self
-- ---------------------------------------------------------------------------
-- Godmode, noclip and friends run entirely on the staff member's own client.
-- The server is told so the action shows up in the logs, and so a permission
-- check happens for the toggle rather than trusting the menu alone.

local selfStates = {
    ['self.godmode']   = 'God mode',
    ['self.invisible'] = 'Invisibility',
    ['self.noclip']    = 'Noclip',
}

TSIV.RegisterAction('self.state', nil, function(src, payload)
    local key = payload.key
    if not selfStates[key] then return end
    if not TSIV.Can(src, key) then
        TSIV.Notify(src, 'You do not have permission to do that.', 'error')
        return
    end

    Logs.Staff(src, ('%s %s'):format(selfStates[key], payload.state and 'on' or 'off'))
end)

TSIV.RegisterAction('self.teleport', nil, function(src, payload)
    local permission = payload.saved and 'self.tpsaved' or 'self.tpcoords'
    if not TSIV.Can(src, permission) then
        TSIV.Notify(src, 'You do not have permission to do that.', 'error')
        return
    end

    local x = TSIV.ToNumber(payload.x)
    local y = TSIV.ToNumber(payload.y)
    local z = TSIV.ToNumber(payload.z)
    if not x or not y or not z then
        TSIV.Notify(src, 'Those are not valid coordinates.', 'error')
        return
    end

    run(src, 'teleport', { x = x, y = y, z = z })
    Logs.Staff(src, ('Teleported to %.1f, %.1f, %.1f'):format(x, y, z))
end)

-- ---------------------------------------------------------------------------
-- Vehicles
-- ---------------------------------------------------------------------------

TSIV.RegisterAction('vehicle.spawn', 'vehicle.spawn', function(src, payload)
    local model = TSIV.SafeString(payload.model, 32):lower()
    if model == '' then
        TSIV.Notify(src, 'You need a model name.', 'error')
        return
    end

    -- The blacklist applies to staff too, unless they are exempt. A menu that
    -- lets an admin hand themselves a tank is a menu that gets abused.
    if TSIV.AntiCheat and TSIV.AntiCheat.IsBlacklistedVehicle
        and TSIV.AntiCheat.IsBlacklistedVehicle(model)
        and TSIV.RankLevel(TSIV.GetRank(src)) < TSIV.RankLevel('superadmin') then
        TSIV.Notify(src, ('%s is on the vehicle blacklist.'):format(model), 'error')
        return
    end

    run(src, 'spawnVehicle', { model = model, plate = TSIV.SafeString(payload.plate, 8) })
    Logs.Staff(src, ('Spawned a %s'):format(model))
end)

local vehicleSelfActions = {
    ['vehicle.repair'] = { command = 'repairVehicle', message = 'Repaired your vehicle',  log = 'Repaired their vehicle' },
    ['vehicle.refuel'] = { command = 'refuelVehicle', message = 'Refuelled your vehicle', log = 'Refuelled their vehicle' },
    ['vehicle.flip']   = { command = 'flipVehicle',   message = 'Flipped your vehicle',   log = 'Flipped their vehicle' },
    ['vehicle.delete'] = { command = 'deleteVehicle', message = 'Deleted the vehicle',    log = 'Deleted the vehicle they were looking at' },
}

for key, entry in pairs(vehicleSelfActions) do
    TSIV.RegisterAction(key, key, function(src)
        run(src, entry.command, {})
        TSIV.Notify(src, entry.message, 'success')
        Logs.Staff(src, entry.log)
    end)
end

-- ---------------------------------------------------------------------------
-- Area cleanup
-- ---------------------------------------------------------------------------
-- Enumeration and deletion both happen on the server. The client never gets to
-- say "delete this entity" - it says "delete props within 25 metres of me",
-- and the server works out what that means. A modified client therefore cannot
-- delete an entity it is nowhere near.

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

--- Delete entities of a kind, either within a radius of the caller or across
--- the whole map. Returns how many were removed.
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

            -- Never delete a vehicle somebody is sitting in, or a player's own
            -- ped, unless explicitly asked to.
            if kind == 'vehicles' and skipOccupied ~= false then
                for seat = -1, 6 do
                    if GetPedInVehicleSeat(entity, seat) ~= 0 then
                        keep = true
                        break
                    end
                end
            elseif kind == 'peds' then
                -- GetAllPeds includes player peds. Those are never touched.
                keep = playerPeds[entity] == true
            end

            if not keep then
                local inRange = true
                if origin and radius then
                    local ok, coords = pcall(GetEntityCoords, entity)
                    inRange = ok and coords and distance(origin, coords) <= radius
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

TSIV.Cleanup = cleanup

TSIV.RegisterAction('cleanup.area', nil, function(src, payload)
    local kind = payload.kind
    local entry = cleanupKinds[kind]
    if not entry then return end

    local all = payload.all and true or false
    local permission = all and entry.permissionAll or entry.permissionArea
    if not TSIV.Can(src, permission) then
        TSIV.Notify(src, 'You do not have permission to do that.', 'error')
        return
    end

    local origin, radius
    if not all then
        radius = TSIV.ToNumber(payload.radius)
        if not radius or radius <= 0 or radius > 2000 then
            TSIV.Notify(src, 'That radius is not valid.', 'error')
            return
        end
        origin = pedCoords(src)
        if not origin then return end
    end

    local removed = cleanup(kind, origin, radius, payload.includeOccupied ~= true)

    local where = all and 'across the whole map' or ('within %dm'):format(math.floor(radius))
    TSIV.Notify(src, ('Deleted %d %s(s) %s'):format(removed, entry.label, where), 'success')
    Logs.Staff(src, ('Deleted %d %s(s) %s'):format(removed, entry.label, where), nil,
        { kind = kind, radius = radius, all = all, removed = removed })

    if all or removed > 50 then
        TSIV.StaffBroadcast('admin', ('%s%s deleted %d %s(s) %s'):format(
            Config.Prefix, TSIV.GetName(src), removed, entry.label, where))
    end
end)

--- Delete every entity a specific player created, using the ownership table
--- the anti-cheat keeps.
TSIV.RegisterAction('cleanup.player', 'prop.deleteplayer', function(src, payload)
    local target = TSIV.ResolveTarget(payload.target)
    if not target then
        TSIV.Notify(src, 'That player is not online.', 'error')
        return
    end

    local removed = TSIV.AntiCheat.DeleteEntitiesOf(target, payload.kind)
    TSIV.Notify(src, ('Deleted %d entity(s) created by %s'):format(removed, TSIV.GetName(target)), 'success')
    Logs.Staff(src, ('Deleted %d entity(s) created by %s'):format(removed, TSIV.Describe(target)), target)
end)

--- Delete the single entity the caller is aiming at. The client works out
--- which one, but the server re-checks that it is actually close to them
--- before removing it.
TSIV.RegisterAction('entity.deleteNearest', nil, function(src, payload)
    local permission = payload.kind == 'vehicles' and 'vehicle.delete' or 'prop.deletenearest'
    if not TSIV.Can(src, permission) then
        TSIV.Notify(src, 'You do not have permission to do that.', 'error')
        return
    end

    local netId = TSIV.ToInt(payload.netId, 1)
    if not netId then return end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        TSIV.Notify(src, 'That entity no longer exists.', 'error')
        return
    end

    local origin = pedCoords(src)
    local coords = GetEntityCoords(entity)
    if origin and distance(origin, coords) > 50.0 then
        TSIV.Notify(src, 'That entity is too far away.', 'error')
        return
    end

    local model = GetEntityModel(entity)
    DeleteEntity(entity)
    TSIV.Notify(src, 'Entity deleted.', 'success')
    Logs.Staff(src, ('Deleted entity %s (model %s)'):format(netId, model))
end)

-- ---------------------------------------------------------------------------
-- Prop logging toggle
-- ---------------------------------------------------------------------------

TSIV.RegisterAction('prop.toggleproplog', 'prop.toggleproplog', function(src, payload)
    local state = payload.state and true or false
    TSIV.SetSetting('logPropSpawns', state)

    TSIV.Notify(src, ('Prop spawn logging is now %s'):format(state and 'ON' or 'OFF'), 'success')
    Logs.Staff(src, ('Turned prop spawn logging %s'):format(state and 'on' or 'off'))
    TSIV.StaffBroadcast(Config.AntiCheat.propLogRank, ('%s%s turned prop spawn logging %s'):format(
        Config.Prefix, TSIV.GetName(src), state and 'ON' or 'OFF'))

    -- Everyone who can see the toggle needs their menu row updating.
    for _, player in ipairs(GetPlayers()) do
        TSIV.SendPermissions(tonumber(player))
    end
end)

-- ---------------------------------------------------------------------------
-- Staff
-- ---------------------------------------------------------------------------

TSIV.RegisterRequest('staff.online', 'staff.online', function(src)
    local staff = TSIV.GetStaff()
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
        for _, rank in ipairs(TSIV.Ranks()) do
            if counts[rank.name] then
                summary[#summary + 1] = ('%s: %d'):format(rank.label, counts[rank.name])
            end
        end
        lines[#lines + 1] = ('%d online  |  %s'):format(#staff, table.concat(summary, '   '))
    end

    return { title = 'tsivtools online staff', lines = lines, staff = staff }
end)

TSIV.RegisterAction('staff.chat', 'staff.chat', function(src, payload)
    local message = TSIV.SafeString(payload.message, 200)
    if message == '' then return end

    local rank = TSIV.GetRank(src)
    local line = ('^5[staff]^7 ^3%s^7 (%s): %s'):format(TSIV.GetName(src), TSIV.RankLabel(rank), message)

    for _, member in ipairs(TSIV.GetStaff('mod')) do
        TriggerClientEvent('chat:addMessage', member.source, { args = { line }, multiline = true })
    end

    print(('%s[staff chat] %s: %s'):format(Config.ConsolePrefix, TSIV.GetName(src), message))
    Logs.Write({
        category = 'chat',
        message = ('[staff chat] %s'):format(message),
        actor = TSIV.GetPrimaryIdentifier(src),
        actorName = TSIV.GetName(src),
    })
end)

TSIV.RegisterAction('staff.announce', 'staff.announce', function(src, payload)
    local message = TSIV.SafeString(payload.message, 200)
    if message == '' then return end

    TriggerClientEvent('chat:addMessage', -1, {
        args = { ('^1[ANNOUNCEMENT]^7 %s'):format(message) },
        multiline = true,
    })
    TSIV.Notify(src, 'Announcement sent.', 'success')
    Logs.Staff(src, ('Announced: %s'):format(message))
end)

TSIV.RegisterRequest('staff.serverinfo', 'staff.serverinfo', function(src)
    local objects = GetAllObjects()
    local vehicles = GetAllVehicles()
    local peds = GetAllPeds()
    local players = GetPlayers()

    local uptime = math.floor(GetGameTimer() / 60000)

    local lines = {
        ('players       : %d'):format(#players),
        ('staff online  : %d'):format(#TSIV.GetStaff()),
        ('objects       : %d'):format(#objects),
        ('vehicles      : %d'):format(#vehicles),
        ('peds          : %d'):format(#peds),
        ('resources     : %d'):format(GetNumResources()),
        ('storage       : %s'):format(TSIV.Storage.UsingMysql() and 'mysql' or 'file'),
        ('prop logging  : %s'):format(TSIV.PropLoggingEnabled() and 'on' or 'off'),
        ('uptime        : %d minute(s)'):format(uptime),
    }

    return { title = 'tsivtools server info', lines = lines }
end)

-- ---------------------------------------------------------------------------
-- Chat commands
-- ---------------------------------------------------------------------------
-- Handy shortcuts for the things staff use constantly. They all funnel through
-- the same permission check as the menu.

local function commandPermission(src, key)
    if src == 0 then return true end
    if TSIV.Can(src, key) then return true end
    TSIV.Notify(src, 'You do not have permission to do that.', 'error')
    return false
end

RegisterCommand('bring', function(src, args)
    if not commandPermission(src, 'player.bring') then return end
    local target = TSIV.ResolveTarget(args[1])
    if not target then
        TSIV.Notify(src, 'usage: /bring <server id>', 'error')
        return
    end
    if not TSIV.OutranksTarget(src, target) then
        TSIV.Notify(src, 'You cannot bring somebody of your own rank or higher.', 'error')
        return
    end
    local coords = pedCoords(src)
    if coords then
        run(target, 'teleport', { x = coords.x, y = coords.y + 1.0, z = coords.z })
        TSIV.Notify(target, ('%s brought you to them.'):format(TSIV.GetName(src)), 'info')
        TSIV.Notify(src, ('Brought %s to you'):format(TSIV.GetName(target)), 'success')
        Logs.Staff(src, ('Brought %s'):format(TSIV.Describe(target)), target)
    end
end, false)

RegisterCommand('goto', function(src, args)
    if not commandPermission(src, 'player.goto') then return end
    local target = TSIV.ResolveTarget(args[1])
    if not target then
        TSIV.Notify(src, 'usage: /goto <server id>', 'error')
        return
    end
    local coords = pedCoords(target)
    if coords then
        run(src, 'teleport', { x = coords.x, y = coords.y + 1.0, z = coords.z })
        Logs.Staff(src, ('Teleported to %s'):format(TSIV.Describe(target)), target)
    end
end, false)

RegisterCommand('revive', function(src, args)
    if not commandPermission(src, 'player.revive') then return end
    local target = TSIV.ResolveTarget(args[1]) or src
    run(target, 'revive', {})
    TSIV.Notify(src, ('Revived %s'):format(TSIV.GetName(target)), 'success')
    Logs.Staff(src, ('Revived %s'):format(TSIV.Describe(target)), target)
end, false)

RegisterCommand('slay', function(src, args)
    if not commandPermission(src, 'player.slay') then return end
    local target = TSIV.ResolveTarget(args[1])
    if not target then
        TSIV.Notify(src, 'usage: /slay <server id>', 'error')
        return
    end
    if not TSIV.OutranksTarget(src, target) then
        TSIV.Notify(src, 'You cannot slay somebody of your own rank or higher.', 'error')
        return
    end
    run(target, 'slay', {})
    TSIV.Notify(src, ('Slayed %s'):format(TSIV.GetName(target)), 'success')
    Logs.Staff(src, ('Slayed %s'):format(TSIV.Describe(target)), target)
end, false)

RegisterCommand('dv', function(src, args)
    if not commandPermission(src, 'vehicle.dvarea') then return end
    local radius = TSIV.ToNumber(args[1]) or 10.0
    radius = math.min(math.max(radius, 1.0), 2000.0)
    local origin = pedCoords(src)
    if not origin then return end
    local removed = cleanup('vehicles', origin, radius, true)
    TSIV.Notify(src, ('Deleted %d vehicle(s) within %dm'):format(removed, math.floor(radius)), 'success')
    Logs.Staff(src, ('Deleted %d vehicle(s) within %dm'):format(removed, math.floor(radius)))
end, false)

RegisterCommand('dp', function(src, args)
    if not commandPermission(src, 'prop.deletearea') then return end
    local radius = TSIV.ToNumber(args[1]) or 10.0
    radius = math.min(math.max(radius, 1.0), 2000.0)
    local origin = pedCoords(src)
    if not origin then return end
    local removed = cleanup('props', origin, radius)
    TSIV.Notify(src, ('Deleted %d prop(s) within %dm'):format(removed, math.floor(radius)), 'success')
    Logs.Staff(src, ('Deleted %d prop(s) within %dm'):format(removed, math.floor(radius)))
end, false)

RegisterCommand('staffchat', function(src, args)
    if not commandPermission(src, 'staff.chat') then return end
    local message = table.concat(args, ' ')
    if message == '' then return end
    TriggerEvent('__tsivtools_staffchat', src, message)
end, false)

AddEventHandler('__tsivtools_staffchat', function(src, message)
    message = TSIV.SafeString(message, 200)
    local rank = TSIV.GetRank(src)
    local line = ('^5[staff]^7 ^3%s^7 (%s): %s'):format(TSIV.GetName(src), TSIV.RankLabel(rank), message)
    for _, member in ipairs(TSIV.GetStaff('mod')) do
        TriggerClientEvent('chat:addMessage', member.source, { args = { line }, multiline = true })
    end
end)
