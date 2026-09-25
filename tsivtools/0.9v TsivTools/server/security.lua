tsivtools.Security = {}
local Security = tsivtools.Security
local Logs = tsivtools.Logs

local history = tsivtools.Storage.Get('player_history')
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
    local identifier = tsivtools.GetPrimaryIdentifier(src)
    local entry = history[identifier] or {
        identifier = identifier, names = {}, joins = {},
        firstSeen = now(),
    }
    entry.lastSeen = now()
    entry.currentName = tsivtools.GetName(src)
    entry.currentId = src
    local known = false
    for _, name in ipairs(entry.names) do
        if name == entry.currentName then known = true break end
    end
    if not known then entry.names[#entry.names + 1] = entry.currentName end
    if #entry.names > 20 then table.remove(entry.names, 1) end
    entry.joins[#entry.joins + 1] = entry.lastSeen
    if #entry.joins > 30 then table.remove(entry.joins, 1) end
    history[identifier] = entry
    tsivtools.Storage.MarkDirty('player_history')
end

local function forgetOldPlayers()
    local cutoff = now() - Config.security.historyDays * 86400
    local changed = false
    for identifier, entry in pairs(history) do
        if entry.identifiers then
            entry.identifiers = nil
            changed = true
        end
        if (entry.lastSeen or 0) < cutoff then
            history[identifier] = nil
            changed = true
        end
    end
    if changed then tsivtools.Storage.MarkDirty('player_history') end
end

CreateThread(function()
    while true do
        forgetOldPlayers()
        Wait(3600000)
    end
end)

local function activeIdentifiers()
    local out = {}
    for _, raw in ipairs(GetPlayers()) do
        local src = tonumber(raw)
        out[tsivtools.GetPrimaryIdentifier(src)] = src
    end
    return out
end

local function logEntries(limit)
    return tsivtools.Logs.Search('', math.min(limit or 100, 100), 'all')
end

local kindWords = {
    { 'injection',       { 'stopped answering', 'not answering' } },
    { 'aim',             { 'aim', 'snap', 'crosshair' } },
    { 'vehicle abuse',   { 'vehicle' } },
    { 'entity abuse',    { 'prop', 'ped spawn' } },
    { 'explosion abuse', { 'explosion' } },
}

local function kindOf(text)
    text = text:lower()
    for _, entry in ipairs(kindWords) do
        for _, word in ipairs(entry[2]) do
            if text:find(word, 1, true) then return entry[1] end
        end
    end
    return 'event abuse'
end

local function reasonOf(entry)
    local data = entry.data
    if type(data) == 'string' then
        local ok, decoded = pcall(json.decode, data)
        data = ok and decoded or nil
    end
    return type(data) == 'table' and type(data.reason) == 'string' and data.reason or nil
end

local function detection(entry)
    if entry.category ~= 'anticheat' and entry.category ~= 'props' then return nil end
    local severity = severityByCategory[entry.category] or 'medium'
    local message = entry.message or ''
    local kind = kindOf(reasonOf(entry) or message)
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
    local identifier = tsivtools.GetPrimaryIdentifier(target)
    local entry = history[identifier] or {}
    local detections = allDetections()
    local risk, count = riskFor(identifier, detections)
    local lines = {
        ('player: %s (id %s)'):format(tsivtools.GetName(target), target),
        ('risk score: %d/100'):format(risk),
        ('session duration: %s'):format(os.date('!%Hh %Mm', now() - (sessions[target] or now()))),
        ('first seen: %s'):format(entry.firstSeen and os.date('%Y-%m-%d %H:%M:%S', entry.firstSeen) or 'this session'),
        ('last seen: %s'):format(entry.lastSeen and os.date('%Y-%m-%d %H:%M:%S', entry.lastSeen) or 'now'),
        ('detections: %d'):format(count),
        ('previous names: %s'):format(table.concat(entry.names or {}, ', ')),
        ('identifiers: %s'):format(json.encode(tsivtools.GetIdentifiers(target))),
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

tsivtools.RegisterRequest('security.status', 'security.view', function()
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
                if expires > now() and online[tsivtools.GetPrimaryIdentifier(target)] then count = count + 1 end
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

tsivtools.RegisterRequest('security.health', 'security.view', function()
    local lines = {
        ('TsivTools anticheat: %s'):format(Config.anticheat.enabled and 'enabled' or 'disabled'),
        ('online players: %d'):format(#GetPlayers()),
        ('server resource: %s'):format(GetCurrentResourceName()),
    }
    return { title = 'Security Health Dashboard', lines = lines }
end)

tsivtools.RegisterRequest('security.detections', 'security.view', function(_, payload)
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

tsivtools.RegisterRequest('security.alerts', 'security.view', function()
    local online = activeIdentifiers()
    local detections = allDetections()
    local out = {}
    for _, item in ipairs(detections) do
        local target = online[item.source]
        if target then
            item.target = target
            item.risk = riskFor(item.source, detections)
            out[#out + 1] = item
        end
    end
    return out
end)

tsivtools.RegisterRequest('security.profile', 'security.view', function(src, payload)
    local target = tsivtools.ResolveTarget(payload.target)
    if not target then return { title = 'Player Security Profile', lines = { 'Player is not online.' } } end
    Logs.Staff(src, ('Opened security profile for %s'):format(tsivtools.Describe(target)), target)
    return profile(src, target)
end)

tsivtools.RegisterRequest('security.statistics', 'security.view', function()
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
    if not tsivtools.Can(src, 'security.monitor') then return end
    target = tsivtools.ResolveTarget(target)
    minutes = tsivtools.ToInt(minutes, 1, Config.security.maxMonitorMinutes)
    if not target or not minutes then tsivtools.Notify(src, 'Invalid player or monitor duration.', 'error'); return end
    if not tsivtools.OutranksTarget(src, target) then tsivtools.Notify(src, 'That player is your rank or higher !', 'error'); return end
    Logs.Staff(src, ('Started a %d minute security monitor for %s'):format(minutes, tsivtools.Describe(target)), target)
    monitors[target] = now() + minutes * 60
    tsivtools.Notify(src, ('Monitoring %s for %d minute(s).'):format(tsivtools.GetName(target), minutes), 'success')
end)

AddEventHandler('playerJoining', function()
    local src = source
    sessions[src] = now()
    remember(src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local identifier = tsivtools.GetPrimaryIdentifier(src)
    if history[identifier] then history[identifier].currentId = nil end
    monitors[src] = nil
    sessions[src] = nil
    tsivtools.Storage.MarkDirty('player_history')
end)

CreateThread(function()
    Wait(1000)
    for _, raw in ipairs(GetPlayers()) do
        local src = tonumber(raw)
        sessions[src] = now()
        remember(src)
    end
end)
