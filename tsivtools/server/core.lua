local actions = {}
local requests = {}
local rankCache = {}
local rateLimit = {}

function TSIV.GetIdentifiers(src)
    local out = {}
    local count = GetNumPlayerIdentifiers(src)
    for index = 0, count - 1 do
        local identifier = GetPlayerIdentifier(src, index)
        if identifier then
            local kind = identifier:match('^(%w+):')
            if kind then
                out[kind] = identifier
            end
        end
    end
    return out
end

function TSIV.GetPrimaryIdentifier(src)
    local ids = TSIV.GetIdentifiers(src)
    return ids.license or ids.steam or ids.discord or ids.fivem or ('src:' .. src)
end

function TSIV.GetSteamId(src)
    local ids = TSIV.GetIdentifiers(src)
    return ids.steam or 'no steam id'
end

function TSIV.GetName(src)
    local name = GetPlayerName(src)
    return name and TSIV.SafeString(name, 48) or ('unknown (' .. tostring(src) .. ')')
end

function TSIV.Describe(src)
    return ('%s (id %s)'):format(TSIV.GetName(src), src)
end

function TSIV.ResolveTarget(value)
    local id = TSIV.ToInt(value, 1, 65535)
    if not id then return nil end
    if GetPlayerName(id) == nil then return nil end
    return id
end

local function frameworkRank(src)
    if Config.Framework == 'esx' then
        local ok, esx = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if not ok or not esx then return nil end
        local player = esx.GetPlayerFromId(src)
        if not player then return nil end
        return Config.FrameworkGroupMap[player.getGroup()]
    elseif Config.Framework == 'qb' then
        local ok, qb = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        if not ok or not qb then return nil end
        local player = qb.Functions.GetPlayer(src)
        if not player then return nil end
        local group = qb.Functions.GetPermission and qb.Functions.GetPermission(src) or nil
        return group and Config.FrameworkGroupMap[group] or nil
    end
    return nil
end

function TSIV.GetRank(src)
    if src == 0 then
        local ranks = TSIV.Ranks()
        return ranks[#ranks].name
    end

    if rankCache[src] then return rankCache[src] end

    local best, bestLevel = nil, 0

    local identifiers = TSIV.GetIdentifiers(src)
    for _, identifier in pairs(identifiers) do
        local rank = Config.Staff[identifier]
        if rank and TSIV.RankLevel(rank) > bestLevel then
            best, bestLevel = rank, TSIV.RankLevel(rank)
        end

        local stored = TSIV.StaffStore and TSIV.StaffStore()[identifier] or nil
        if stored and TSIV.RankLevel(stored) > bestLevel then
            best, bestLevel = stored, TSIV.RankLevel(stored)
        end
    end

    if Config.UseAcePermissions then
        for _, rank in ipairs(TSIV.Ranks()) do
            local ace = ('%s.%s'):format(Config.AcePrefix, rank.name)
            if IsPlayerAceAllowed(src, ace) and rank.level > bestLevel then
                best, bestLevel = rank.name, rank.level
            end
        end
    end

    if Config.Framework ~= 'none' then
        local rank = frameworkRank(src)
        if rank and TSIV.RankLevel(rank) > bestLevel then
            best, bestLevel = rank, TSIV.RankLevel(rank)
        end
    end

    rankCache[src] = best or false
    return best
end

function TSIV.ClearRankCache(src)
    if src then
        rankCache[src] = nil
    else
        rankCache = {}
    end
end

function TSIV.IsStaff(src)
    return TSIV.GetRank(src) ~= nil and TSIV.GetRank(src) ~= false
end

function TSIV.Can(src, key)
    local rank = TSIV.GetRank(src)
    if not rank then return false end
    return TSIV.HasPermission(rank, key)
end

function TSIV.GetStaff(minRank)
    local minLevel = minRank and TSIV.RankLevel(minRank) or 1
    local out = {}
    for _, src in ipairs(GetPlayers()) do
        src = tonumber(src)
        local rank = TSIV.GetRank(src)
        if rank and TSIV.RankLevel(rank) >= minLevel then
            out[#out + 1] = {
                source = src,
                name = TSIV.GetName(src),
                rank = rank,
                rankLabel = TSIV.RankLabel(rank),
                level = TSIV.RankLevel(rank),
                identifier = TSIV.GetPrimaryIdentifier(src),
                steam = TSIV.GetSteamId(src),
            }
        end
    end
    table.sort(out, function(a, b)
        if a.level == b.level then return a.name < b.name end
        return a.level > b.level
    end)
    return out
end

function TSIV.Notify(src, message, kind)
    if src == 0 then
        print(Config.ConsolePrefix .. message)
        return
    end
    TriggerClientEvent(TSIV.Events.notify, src, message, kind or 'info')
end

function TSIV.Console(src, message, colour)
    if src == 0 then
        print(Config.ConsolePrefix .. message)
        return
    end
    TriggerClientEvent(TSIV.Events.console, src, message, colour)
end

function TSIV.ConsoleBlock(src, title, lines)
    if src == 0 then
        print(Config.ConsolePrefix .. title)
        for _, line in ipairs(lines) do print('  ' .. line) end
        return
    end
    TriggerClientEvent(TSIV.Events.console, src, { title = title, lines = lines })
end

function TSIV.StaffBroadcast(minRank, message, consoleLines)
    for _, member in ipairs(TSIV.GetStaff(minRank)) do
        if message then
            TriggerClientEvent(TSIV.Events.alert, member.source, message)
        end
        if consoleLines then
            TSIV.ConsoleBlock(member.source, message or 'tsivtools alert', consoleLines)
        end
    end

    local plain = (message or ''):gsub('%^%d', '')
    plain = plain:gsub('^' .. Config.Prefix:gsub('%^%d', ''):gsub('(%W)', '%%%1'), '')
    print(('%s%s'):format(Config.ConsolePrefix, plain))
    if consoleLines then
        for _, line in ipairs(consoleLines) do print('  ' .. line) end
    end
end

function TSIV.RegisterAction(name, permission, handler)
    actions[name] = { permission = permission, handler = handler }
end

function TSIV.RegisterRequest(name, permission, handler)
    requests[name] = { permission = permission, handler = handler }
end

local function allowRate(src)
    local now = GetGameTimer() / 1000.0
    local bucket = rateLimit[src]
    if not bucket or now - bucket.start > 10.0 then
        rateLimit[src] = { start = now, count = 1 }
        return true
    end
    bucket.count = bucket.count + 1
    if bucket.count > 40 then
        if bucket.count == 41 then
            print(('%s%s is sending events far too quickly and is being throttled')
                :format(Config.ConsolePrefix, TSIV.Describe(src)))
        end
        return false
    end
    return true
end

RegisterNetEvent(TSIV.Events.action, function(name, payload)
    local src = source
    if type(name) ~= 'string' then return end
    if not allowRate(src) then return end

    local entry = actions[name]
    if not entry then
        print(('%s%s asked for the unknown action "%s"'):format(Config.ConsolePrefix, TSIV.Describe(src), TSIV.SafeString(name, 40)))
        return
    end

    if entry.permission and not TSIV.Can(src, entry.permission) then
        TSIV.Notify(src, 'You do not have permission to do that !!', 'error')
        print(('%s%s tried to use "%s" without the %s permission')
            :format(Config.ConsolePrefix, TSIV.Describe(src), name, entry.permission))
        return
    end

    local ok, err = pcall(entry.handler, src, type(payload) == 'table' and payload or {})
    if not ok then
        print(('%saction "%s" failed: %s'):format(Config.ConsolePrefix, name, err))
        TSIV.Notify(src, 'That action failed! report to dev !!', 'error')
    end
end)

RegisterNetEvent(TSIV.Events.request, function(name, requestId, payload)
    local src = source
    if type(name) ~= 'string' or type(requestId) ~= 'number' then return end
    if not allowRate(src) then return end

    local entry = requests[name]
    if not entry then return end

    if entry.permission and not TSIV.Can(src, entry.permission) then
        TriggerClientEvent(TSIV.Events.response, src, requestId, nil)
        return
    end

    local ok, result = pcall(entry.handler, src, type(payload) == 'table' and payload or {})
    if not ok then
        print(('%srequest "%s" failed: %s'):format(Config.ConsolePrefix, name, result))
        result = nil
    end
    TriggerClientEvent(TSIV.Events.response, src, requestId, result)
end)

local function sendPermissions(src)
    local rank = TSIV.GetRank(src)
    if not rank then
        TriggerClientEvent(TSIV.Events.permissions, src, nil)
        return
    end

    local granted = {}
    for key in pairs(Config.Permissions) do
        if TSIV.HasPermission(rank, key) then
            granted[key] = true
        end
    end

    TriggerClientEvent(TSIV.Events.permissions, src, {
        rank = rank,
        rankLabel = TSIV.RankLabel(rank),
        level = TSIV.RankLevel(rank),
        granted = granted,
        propLogging = TSIV.PropLoggingEnabled and TSIV.PropLoggingEnabled() or false,
    })
end

TSIV.SendPermissions = sendPermissions

RegisterNetEvent(TSIV.Events.ready, function()
    sendPermissions(source)
end)

AddEventHandler('playerDropped', function()
    local src = source
    rankCache[src] = nil
    rateLimit[src] = nil
end)

RegisterCommand('tsivtools_whoami', function(src, args)
    local target = TSIV.ResolveTarget(args[1]) or (src ~= 0 and src or nil)
    if not target then
        print(('%susage: tsivtools_whoami <user id>'):format(Config.ConsolePrefix))
        return
    end

    if src ~= 0 and not TSIV.Can(src, 'player.identifiers') and src ~= target then
        return
    end

    local lines = { ('rank: %s'):format(TSIV.GetRank(target) or 'none') }
    for kind, identifier in pairs(TSIV.GetIdentifiers(target)) do
        lines[#lines + 1] = ('%s = %s'):format(kind, identifier)
    end

    if src == 0 then
        print(('%sidentifiers for %s'):format(Config.ConsolePrefix, TSIV.Describe(target)))
        for _, line in ipairs(lines) do print('  ' .. line) end
    else
        TSIV.ConsoleBlock(src, ('identifiers for %s'):format(TSIV.Describe(target)), lines)
    end
end, false)

RegisterCommand('tsivtools_reload', function(src)
    if src ~= 0 then
        if not TSIV.Can(src, 'player.setrank') then return end
    end
    TSIV.ClearRankCache()
    for _, player in ipairs(GetPlayers()) do
        sendPermissions(tonumber(player))
    end
    print(('%sranks re-evaluated for every online player'):format(Config.ConsolePrefix))
end, false)
