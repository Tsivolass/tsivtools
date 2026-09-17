TSIV.Security = {}
local Security = TSIV.Security
local Logs = TSIV.Logs

local history = TSIV.Storage.Get('player_history')
local sessions = {}
local monitors = {}

local severityByCategory = {
    anticheat = 'high',
    ban = 'critical',
    props = 'medium',
}

local function now()
    return os.time()
end

local function remember(src)
    local identifier = TSIV.GetPrimaryIdentifier(src)
    local ids = TSIV.GetIdentifiers(src)
    local entry = history[identifier] or {
        identifier = identifier, names = {}, identifiers = {}, joins = {},
        firstSeen = now(),
    }
    entry.lastSeen = now()
    entry.currentName = TSIV.GetName(src)
    entry.currentId = src
    entry.identifiers = ids
    entry.names[#entry.names + 1] = entry.currentName
    if #entry.names > 20 then table.remove(entry.names, 1) end
    entry.joins[#entry.joins + 1] = entry.lastSeen
    if #entry.joins > 30 then table.remove(entry.joins, 1) end
    history[identifier] = entry
    TSIV.Storage.MarkDirty('player_history')
end

local function onlineByIdentifier(identifier)
    for _, raw in ipairs(GetPlayers()) do
        local src = tonumber(raw)
        if TSIV.GetPrimaryIdentifier(src) == identifier then return src end
    end
end

local function activeIdentifiers()
    local out = {}
    for _, raw in ipairs(GetPlayers()) do
        local src = tonumber(raw)
        out[TSIV.GetPrimaryIdentifier(src)] = true
    end
    return out
end

local function logEntries(limit)
    return TSIV.Logs.Search('', math.min(limit or 100, 100), 'all')
end

local function detection(entry)
    if entry.category ~= 'anticheat' and entry.category ~= 'props' then return nil end
    local severity = severityByCategory[entry.category] or 'medium'
    local message = entry.message or ''
    local kind = 'event abuse'
    if message:lower():find('vehicle') then kind = 'vehicle abuse'
    elseif message:lower():find('prop') then kind = 'entity abuse'
    elseif message:lower():find('explosion') then kind = 'explosion abuse' end
    return {
        id = entry.id, at = entry.at, source = entry.target,
        name = entry.targetName ~= '' and entry.targetName or 'Unknown player',
        severity = severity, kind = kind, message = message,
        sourceSystem = 'TsivTools',
    }
end

local function allDetections()
    local out = {}
    for _, entry in ipairs(logEntries(100)) do
        local item = detection(entry)
        if item then out[#out + 1] = item end
    end
    return out
end

local function riskFor(identifier, detections)
    local risk, count = 0, 0
    local points = { critical = 40, high = 25, medium = 12, low = 4 }
    for _, item in ipairs(detections) do
        if item.source == identifier then
            risk = risk + (points[item.severity] or 0)
            count = count + 1
        end
    end
    return math.min(100, risk), count
end

local function profile(src, target)
    local identifier = TSIV.GetPrimaryIdentifier(target)
    local entry = history[identifier] or {}
    local detections = allDetections()
    local risk, count = riskFor(identifier, detections)
    local lines = {
        ('player: %s (id %s)'):format(TSIV.GetName(target), target),
        ('risk score: %d/100'):format(risk),
        ('session duration: %s'):format(os.date('!%Hh %Mm', now() - (sessions[target] or now()))),
        ('first seen: %s'):format(entry.firstSeen and os.date('%Y-%m-%d %H:%M:%S', entry.firstSeen) or 'this session'),
        ('last seen: %s'):format(entry.lastSeen and os.date('%Y-%m-%d %H:%M:%S', entry.lastSeen) or 'now'),
        ('detections: %d'):format(count),
        ('previous names: %s'):format(table.concat(entry.names or {}, ', ')),
        ('identifiers: %s'):format(json.encode(entry.identifiers or TSIV.GetIdentifiers(target))),
    }
    for _, item in ipairs(detections) do
        if item.source == identifier then
            lines[#lines + 1] = ('[%s] %s - %s'):format(item.severity:upper(), item.kind, item.message)
        end
    end
    local actions = 0
    for _, item in ipairs(logEntries(100)) do
        if item.target == identifier and (item.category == 'ban' or item.category == 'staff') then
            lines[#lines + 1] = ('[HISTORY] %s - %s'):format(item.category, item.message)
            actions = actions + 1
            if actions >= 10 then break end
        end
    end
    return { title = 'Player Security Profile', lines = lines }
end

TSIV.RegisterRequest('security.status', 'security.view', function()
    local detections = allDetections()
    local online = activeIdentifiers()
    local active = {}
    for _, item in ipairs(detections) do
        if online[item.source] then active[item.source] = item end
    end
    local lines = {
        'SECURITY CENTER',
        ('active threats: %02d'):format((function() local n = 0 for _ in pairs(active) do n = n + 1 end return n end)()),
        ('tsiv detections: %d'):format(#detections),
        ('temporary monitors: %d'):format((function()
            local count = 0
            for target, expires in pairs(monitors) do
                if expires > now() and online[TSIV.GetPrimaryIdentifier(target)] then count = count + 1 end
            end
            return count
        end)()),
        '',
    }
    for _, item in ipairs(detections) do
        if online[item.source] then
        local risk = riskFor(item.source, detections)
        lines[#lines + 1] = ('#%s %s | %s: %s | Risk %d/100'):format(
            item.id, item.name, item.sourceSystem, item.kind, risk)
        end
    end
    return { title = 'Security Center', lines = lines }
end)

TSIV.RegisterRequest('security.health', 'security.view', function()
    local lines = {
        ('TsivTools anticheat: %s'):format(Config.anticheat.enabled and 'enabled' or 'disabled'),
        ('online players: %d'):format(#GetPlayers()),
        ('server resource: %s'):format(GetCurrentResourceName()),
    }
    return { title = 'Security Health Dashboard', lines = lines }
end)

TSIV.RegisterRequest('security.detections', 'security.view', function(_, payload)
    local severity = payload.severity and payload.severity:lower()
    local kind = payload.kind and payload.kind:lower()
    local lines = {}
    for _, item in ipairs(allDetections()) do
        if (not severity or severity == 'all' or item.severity == severity)
            and (not kind or kind == 'all' or item.kind == kind) then
            lines[#lines + 1] = ('[%s] %s | %s | %s'):format(
                item.severity:upper(), item.name, item.kind, item.message)
        end
    end
    if #lines == 0 then lines[1] = 'No detections match the selected filters.' end
    return { title = 'Unified Detection Feed', lines = lines }
end)

TSIV.RegisterRequest('security.alerts', 'security.view', function()
    local online = activeIdentifiers()
    local detections = allDetections()
    local out = {}
    for _, item in ipairs(detections) do
        if online[item.source] then
            local target = onlineByIdentifier(item.source)
            if target then
                item.target = target
                item.risk = riskFor(item.source, detections)
                out[#out + 1] = item
            end
        end
    end
    return out
end)

TSIV.RegisterRequest('security.profile', 'security.view', function(src, payload)
    local target = TSIV.ResolveTarget(payload.target)
    if not target then return { title = 'Player Security Profile', lines = { 'Player is not online.' } } end
    Logs.Staff(src, ('Opened security profile for %s'):format(TSIV.Describe(target)), target)
    return profile(src, target)
end)

TSIV.RegisterRequest('security.statistics', 'security.view', function()
    local detections = allDetections()
    local counts = {}
    for _, item in ipairs(detections) do counts[item.kind] = (counts[item.kind] or 0) + 1 end
    local lines = { ('detections: %d'):format(#detections), 'by category:' }
    for kind, count in pairs(counts) do lines[#lines + 1] = ('  %s: %d'):format(kind, count) end
    lines[#lines + 1] = ('online players: %d'):format(#GetPlayers())
    return { title = 'Security Statistics', lines = lines }
end)

RegisterNetEvent('tsivtools:security:monitor', function(target, minutes)
    local src = source
    if not TSIV.Can(src, 'security.monitor') then return end
    target = TSIV.ResolveTarget(target)
    minutes = TSIV.ToInt(minutes, 1, Config.security.maxMonitorMinutes)
    if not target or not minutes then TSIV.Notify(src, 'Invalid player or monitor duration.', 'error'); return end
    Logs.Staff(src, ('Started a %d minute security monitor for %s'):format(minutes, TSIV.Describe(target)), target)
    monitors[target] = now() + minutes * 60
    TSIV.Notify(src, ('Monitoring %s for %d minute(s).'):format(TSIV.GetName(target), minutes), 'success')
end)

AddEventHandler('playerJoining', function()
    local src = source
    sessions[src] = now()
    remember(src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local identifier = TSIV.GetPrimaryIdentifier(src)
    if history[identifier] then history[identifier].currentId = nil end
    monitors[src] = nil
    sessions[src] = nil
    TSIV.Storage.MarkDirty('player_history')
end)

CreateThread(function()
    Wait(1000)
    for _, raw in ipairs(GetPlayers()) do
        local src = tonumber(raw)
        sessions[src] = now()
        remember(src)
    end
end)
