tsivtools.Security = {}
local Security = tsivtools.Security
local Logs = tsivtools.Logs

local history = tsivtools.Storage.Get('player_history')
local sessions = {}
local monitors = {}
local waveCache = { detections = {}, status = nil, fetchedAt = 0 }

local severityByCategory = {
    anticheat = 'high',
    ban = 'critical',
    props = 'medium',
}

local function now()
    return os.time()
end

local function urlEncode(value)
    return tostring(value):gsub('[^%w%-%._~]', function(char)
        return ('%%%02X'):format(string.byte(char))
    end)
end

local function waveConfigured()
    local api = Config.waveshield.api
    return Config.waveshield.enabled and Config.waveshield.mode == 'api'
        and api.baseUrl ~= '' and GetConvar(api.apiKeyConvar, '') ~= ''
        and GetConvar(api.apiSecretConvar, '') ~= ''
end

local function waveRequest(method, path, query, body)
    if not waveConfigured() or not path or path == '' then return nil, 'not configured' end
    local api = Config.waveshield.api
    local url = api.baseUrl .. path
    local queryParts = {}
    for key, value in pairs(query or {}) do
        if value ~= nil and value ~= '' then
            queryParts[#queryParts + 1] = urlEncode(key) .. '=' .. urlEncode(value)
        end
    end
    if #queryParts > 0 then url = url .. '?' .. table.concat(queryParts, '&') end

    local pending = { done = false, status = 0, body = nil }
    local headers = {
        ['Content-Type'] = 'application/json',
        [api.apiKeyHeader] = GetConvar(api.apiKeyConvar, ''),
        [api.apiSecretHeader] = GetConvar(api.apiSecretConvar, ''),
    }
    PerformHttpRequest(url, function(status, response)
        pending.status = status or 0
        pending.body = response
        pending.done = true
    end, method, body and json.encode(body) or '', headers)

    local waited = 0
    while not pending.done and waited < api.timeoutMs do
        Wait(25)
        waited = waited + 25
    end
    if not pending.done then return nil, 'request timed out' end
    if pending.status < 200 or pending.status >= 300 then
        return nil, ('HTTP %d'):format(pending.status)
    end
    local ok, decoded = pcall(json.decode, pending.body or '')
    if not ok or type(decoded) ~= 'table' then return nil, 'invalid JSON response' end
    return decoded
end

local function waveArray(payload)
    if type(payload) ~= 'table' then return {} end
    if type(payload.data) == 'table' then return payload.data end
    if type(payload.logs) == 'table' then return payload.logs end
    if type(payload.players) == 'table' then return payload.players end
    return payload[1] and payload or {}
end

local function waveLogDetection(entry)
    local kind = tostring(entry.type or 'event abuse'):lower()
    local severity = 'medium'
    if kind:find('ban') or kind:find('cheat') then severity = 'critical'
    elseif kind:find('aim') or kind:find('inject') or kind:find('hack') then severity = 'high'
    elseif kind:find('warn') then severity = 'low' end
    return {
        id = 'waveshield:' .. tostring(entry.id or entry.timestamp or #waveCache.detections + 1),
        at = entry.timestamp or now(), source = entry.target, name = entry.target or 'Unknown player',
        severity = severity, kind = kind, message = type(entry.details) == 'table' and json.encode(entry.details)
            or tostring(entry.details or entry.type or 'WaveShield event'),
        sourceSystem = 'WaveShield',
    }
end

local function waveGet(path, query)
    return waveRequest('GET', path, query)
end

local function refreshWaveDetections()
    if not waveConfigured() or not Config.waveshield.polling.enabled then return end
    if now() - waveCache.fetchedAt < Config.waveshield.polling.intervalSeconds then return end
    local response, err = waveRequest('GET', Config.waveshield.api.logsPath, {
        limit = Config.waveshield.polling.recentDetectionLimit,
    })
    if not response then
        print(('%sWaveShield logs request failed: %s'):format(Config.consoleprefix, err or 'unknown error'))
        return
    end
    waveCache.detections = {}
    for _, entry in ipairs(waveArray(response)) do
        waveCache.detections[#waveCache.detections + 1] = waveLogDetection(entry)
    end
    waveCache.fetchedAt = now()
end

CreateThread(function()
    while true do
        Wait(1000)
        if Config.waveshield.enabled and Config.waveshield.mode == 'api'
            and Config.waveshield.polling.enabled then
            refreshWaveDetections()
        end
    end
end)

local function remember(src)
    local identifier = tsivtools.GetPrimaryIdentifier(src)
    local ids = tsivtools.GetIdentifiers(src)
    local entry = history[identifier] or {
        identifier = identifier, names = {}, identifiers = {}, joins = {},
        firstSeen = now(),
    }
    entry.lastSeen = now()
    entry.currentName = tsivtools.GetName(src)
    entry.currentId = src
    entry.identifiers = ids
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

local function onlineByIdentifier(identifier)
    for _, raw in ipairs(GetPlayers()) do
        local src = tonumber(raw)
        if tsivtools.GetPrimaryIdentifier(src) == identifier then return src end
    end
end

local function activeIdentifiers()
    local out = {}
    for _, raw in ipairs(GetPlayers()) do
        local src = tonumber(raw)
        out[tsivtools.GetPrimaryIdentifier(src)] = true
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
    refreshWaveDetections()
    local out = {}
    for _, entry in ipairs(logEntries(100)) do
        local item = detection(entry)
        if item then out[#out + 1] = item end
    end
    for _, item in ipairs(waveCache.detections) do out[#out + 1] = item end
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

function Security.WaveShieldStatus()
    local settings = Config.waveshield
    if settings.mode == 'api' then
        local configured = waveConfigured()
        if not configured then
            return { connected = false, state = 'disconnected', version = 'not configured',
                heartbeat = nil, protection = 'TsivTools anticheat only' }
        end
        local server, err = waveRequest('GET', settings.api.serverPath)
        if not server then
            return { connected = false, state = 'disconnected', version = err or 'API unavailable',
                heartbeat = nil, protection = 'TsivTools anticheat only' }
        end
        waveCache.status = server
        waveCache.fetchedAt = now()
        local serverOnline = not server or server.status == nil or server.status == 'ONLINE'
        return { connected = serverOnline, state = serverOnline and 'connected' or 'disconnected',
            version = server and server.info and server.info.version or 'unknown',
            heartbeat = server and server.stats and server.stats.lastSeen
                or now(),
            protection = serverOnline and 'provided by WaveShield API' or 'WaveShield server unavailable' }
    end
    local state = GetResourceState(settings.resourceName)
    local connected = settings.enabled and settings.mode == 'resource' and state == 'started'
    return {
        connected = connected, state = connected and 'connected' or 'disconnected',
        version = connected and GetResourceMetadata(settings.resourceName, 'version', 0) or
            (settings.enabled and settings.mode == 'api' and 'API configured' or 'not configured'),
        heartbeat = connected and now() or nil,
        protection = connected and 'provided by WaveShield' or 'TsivTools anticheat only',
    }
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
        ('identifiers: %s'):format(json.encode(entry.identifiers or tsivtools.GetIdentifiers(target))),
    }
    for _, item in ipairs(detections) do
        if item.source == identifier then
            lines[#lines + 1] = ('[%s] %s - %s'):format(item.severity:upper(), item.kind, item.message)
        end
    end
    if waveConfigured() then
        local path = Config.waveshield.api.analysisPath:format(urlEncode(identifier))
        local analysis = waveGet(path)
        if analysis then
            local player = analysis.player or {}
            lines[#lines + 1] = ('WaveShield play time: %s'):format(player.playTime or 'unknown')
            lines[#lines + 1] = ('WaveShield bans: %d'):format(
                type(analysis.playerBans) == 'table' and #analysis.playerBans or 0)
            lines[#lines + 1] = ('WaveShield alt accounts: %d'):format(
                type(analysis.altAccounts) == 'table' and #analysis.altAccounts or 0)
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
        ('waveshield: %s'):format(Security.WaveShieldStatus().state),
        ('waveshield alerts: %d'):format(#waveCache.detections),
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

tsivtools.RegisterRequest('security.waveshield.bans', 'security.waveshield.ban', function()
    local response, err = waveGet(Config.waveshield.api.serverBansPath)
    if not response then
        return { title = 'WaveShield bans', lines = { 'Unavailable: ' .. (err or 'unknown error') } }
    end
    local lines = {}
    for _, ban in ipairs(waveArray(response)) do
        lines[#lines + 1] = ('#%s | %s | %s'):format(
            tostring(ban.id or 'unknown'), tostring(ban.player or ban.identifier or 'unknown'),
            tostring(ban.reason or 'no reason'))
    end
    if #lines == 0 then lines[1] = 'No active WaveShield bans were returned.' end
    return { title = 'WaveShield bans', lines = lines }
end)

tsivtools.RegisterAction('security.waveshield.ban', 'security.waveshield.ban', function(src, payload)
    local target = tsivtools.ResolveTarget(payload.target)
    if not target then tsivtools.Notify(src, 'Player is not online.', 'error'); return end
    local details = tsivtools.GetIdentifiers(target)
    local playerId = details.license or tsivtools.GetPrimaryIdentifier(target)
    local duration = tsivtools.ToInt(payload.duration, 0, 2147483647)
    local reason = tsivtools.SafeString(payload.reason, 255)
    if not duration or reason == '' then tsivtools.Notify(src, 'A valid duration and reason are required.', 'error'); return end
    local response, err = waveRequest('POST', Config.waveshield.api.banPath, nil, {
        playerId = playerId, reason = reason, duration = duration,
        by = tsivtools.GetName(src),
    })
    if not response then tsivtools.Notify(src, 'WaveShield ban failed: ' .. (err or 'unknown error'), 'error'); return end
    Logs.Staff(src, ('WaveShield banned %s'):format(tsivtools.Describe(target)), target, { reason = reason, duration = duration })
    tsivtools.Notify(src, 'WaveShield ban created.', 'success')
end)

tsivtools.RegisterAction('security.waveshield.unban', 'security.waveshield.unban', function(src, payload)
    local banId = tsivtools.SafeString(payload.banId, 128)
    if banId == '' then tsivtools.Notify(src, 'A WaveShield ban ID is required.', 'error'); return end
    local response, err = waveRequest('POST', Config.waveshield.api.unbanPath, nil, { banId = banId })
    if not response then tsivtools.Notify(src, 'WaveShield unban failed: ' .. (err or 'unknown error'), 'error'); return end
    Logs.Staff(src, ('WaveShield unbanned ban %s'):format(banId))
    tsivtools.Notify(src, 'WaveShield ban removed.', 'success')
end)

tsivtools.RegisterRequest('security.waveshield', 'security.view', function()
    local status = Security.WaveShieldStatus()
    return {
        title = 'WaveShield status',
        lines = {
            'state: ' .. status.state,
            'version: ' .. status.version,
            'heartbeat: ' .. (status.heartbeat and os.date('%Y-%m-%d %H:%M:%S', status.heartbeat) or 'unavailable'),
            'protection: ' .. status.protection,
        },
    }
end)

tsivtools.RegisterRequest('security.waveshield.verify', 'security.view', function()
    local response, err = waveRequest('POST', Config.waveshield.api.verifyPath, nil, {})
    if not response then
        return {
            title = 'WaveShield server integration',
            lines = { 'Server integration check failed: ' .. (err or 'unknown error') },
        }
    end

    local key = response.key or {}
    return {
        title = 'WaveShield server integration',
        lines = {
            response.valid == false and 'server credentials: invalid' or 'server credentials: valid',
            ('integration key: %s'):format(key.name or key.id or 'unknown'),
            ('tier: %s'):format(key.tier or 'unknown'),
            ('status: %s'):format(key.status or 'unknown'),
            ('expires: %s'):format(key.expiresAt or 'unknown'),
        },
    }
end)

tsivtools.RegisterRequest('security.waveshield.logs', 'security.view', function()
    local response, err = waveGet(Config.waveshield.api.logsPath, {
        limit = Config.waveshield.polling.recentDetectionLimit,
    })
    if not response then
        return { title = 'WaveShield detection feed', lines = { 'Unavailable: ' .. (err or 'unknown error') } }
    end
    local lines = {}
    for _, entry in ipairs(waveArray(response)) do
        lines[#lines + 1] = ('[%s] %s | %s | %s'):format(
            tostring(entry.type or 'event'):upper(), tostring(entry.target or 'unknown'),
            tostring(entry.timestamp or ''), type(entry.details) == 'table' and json.encode(entry.details)
                or tostring(entry.details or ''))
    end
    if #lines == 0 then lines[1] = 'No WaveShield server logs were returned.' end
    return { title = 'WaveShield detection feed', lines = lines }
end)

tsivtools.RegisterRequest('security.waveshield.players', 'security.view', function()
    local response, err = waveGet(Config.waveshield.api.playersPath)
    if not response then
        return { title = 'WaveShield players', lines = { 'Unavailable: ' .. (err or 'unknown error') } }
    end
    local lines = {}
    for _, player in ipairs(waveArray(response)) do
        lines[#lines + 1] = ('%s | %s'):format(
            tostring(player.playerName or player.name or player.id or 'unknown'),
            tostring(player.license or player.identifier or player.id or ''))
    end
    if #lines == 0 then lines[1] = 'No WaveShield online players were returned.' end
    return { title = 'WaveShield online players', lines = lines }
end)

tsivtools.RegisterRequest('security.waveshield.profile', 'security.view', function(_, payload)
    local identifier = tsivtools.SafeString(payload.identifier, 160)
    if identifier == '' then return { title = 'WaveShield player profile', lines = { 'Identifier is required.' } } end
    local path = Config.waveshield.api.analysisPath:format(urlEncode(identifier))
    local response, err = waveGet(path)
    if not response then
        return { title = 'WaveShield player profile', lines = { 'Unavailable: ' .. (err or 'unknown error') } }
    end
    local player = response.player or {}
    local lines = {
        ('player: %s'):format(player.playerName or identifier),
        ('license: %s'):format(player.playerLicense or 'unknown'),
        ('first join: %s'):format(player.firstJoin or 'unknown'),
        ('last join: %s'):format(player.lastJoin or 'unknown'),
        ('play time: %s'):format(player.playTime or 'unknown'),
        ('old names: %s'):format(table.concat(player.oldNames or {}, ', ')),
        ('old identifiers: %s'):format(table.concat(player.oldIdentifiers or {}, ', ')),
        ('bans: %d'):format(type(response.playerBans) == 'table' and #response.playerBans or 0),
        ('alt accounts: %d'):format(type(response.altAccounts) == 'table' and #response.altAccounts or 0),
    }
    return { title = 'WaveShield player profile', lines = lines }
end)

tsivtools.RegisterRequest('security.health', 'security.view', function()
    local status = Security.WaveShieldStatus()
    local lines = {
        ('WaveShield: %s'):format(status.state),
        ('WaveShield protection: %s'):format(status.protection),
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
