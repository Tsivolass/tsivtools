TSIV.Confidence = {}

local Confidence = TSIV.Confidence
local rules = Config.anticheat.confidence or { enabled = false }

local scores = {}
local alerted = {}

local function seconds()
    return GetGameTimer() / 1000.0
end

local function active()
    if not Config.anticheat.enabled then return false end
    if not TSIV.Module('confidence') then return false end
    return rules.enabled ~= false
end

local function prune(entry, now)
    local window = rules.window or 180.0
    local kept = {}
    local total = 0.0
    local modules = {}
    local distinct = 0

    for _, item in ipairs(entry.entries) do
        local age = now - item.at
        if age <= window then
            local points = item.points
            if rules.decay ~= false and window > 0 then
                points = points * (1.0 - age / window)
            end
            if points > 0 then
                kept[#kept + 1] = item
                total = total + points
                if not modules[item.module] then
                    modules[item.module] = 0
                    distinct = distinct + 1
                end
                modules[item.module] = modules[item.module] + points
            end
        end
    end

    entry.entries = kept
    entry.total = total
    entry.modules = modules
    entry.distinct = distinct
end

local function breakdown(entry)
    local lines = {}
    local ordered = {}

    for name, points in pairs(entry.modules) do
        ordered[#ordered + 1] = { name = name, points = points }
    end
    table.sort(ordered, function(a, b) return a.points > b.points end)

    for _, item in ipairs(ordered) do
        lines[#lines + 1] = ('  %-12s %5.1f point(s)'):format(item.name, item.points)
    end

    return lines
end

function Confidence.Score(src)
    local entry = scores[src]
    if not entry then return 0, 0 end
    prune(entry, seconds())
    return entry.total, entry.distinct
end

function Confidence.Lines(src)
    local entry = scores[src]
    if not entry then return { 'no anticheat confidence on record' } end

    prune(entry, seconds())

    local lines = {
        ('score     : %.1f of %.0f needed to ban'):format(entry.total, rules.banAt or 100),
        ('modules   : %d of %d needed'):format(entry.distinct, rules.requireDistinctModules or 2),
    }
    for _, line in ipairs(breakdown(entry)) do lines[#lines + 1] = line end
    return lines
end

function Confidence.Clear(src)
    scores[src] = nil
    alerted[src] = nil
end

function Confidence.Add(src, module, points, reason, detail)
    if not active() then return false end
    if not src or not GetPlayerName(src) then return false end
    if TSIV.AntiCheat and TSIV.AntiCheat.IsExempt and TSIV.AntiCheat.IsExempt(src) then return false end

    points = tonumber(points) or 0
    local weight = (rules.weights and rules.weights[module]) or rules.defaultWeight or 20
    points = points * (weight / 100.0)
    if points <= 0 then return false end

    local now = seconds()
    local entry = scores[src]
    if not entry then
        entry = { entries = {}, total = 0, modules = {}, distinct = 0 }
        scores[src] = entry
    end

    entry.entries[#entry.entries + 1] = { at = now, module = module, points = points, reason = reason }
    if #entry.entries > (rules.maxEntries or 200) then
        table.remove(entry.entries, 1)
    end

    prune(entry, now)

    local needed = rules.requireDistinctModules or 2
    local lines = {
        ('trigger   : %s'):format(reason or module),
        ('score     : %.1f of %.0f'):format(entry.total, rules.banAt or 100),
        ('modules   : %d of %d'):format(entry.distinct, needed),
    }
    for _, line in ipairs(detail or {}) do lines[#lines + 1] = line end
    lines[#lines + 1] = 'breakdown :'
    for _, line in ipairs(breakdown(entry)) do lines[#lines + 1] = line end

    local banAt = rules.banAt or 100
    local kickAt = rules.kickAt or 0

    if entry.total >= banAt and entry.distinct >= needed then
        Confidence.Clear(src)
        TSIV.AntiCheat.Punish(src, 'ban', rules.banReason or 'Anticheat confidence threshold',
            rules.banLength or 0, lines)
        return true
    end

    if kickAt > 0 and entry.total >= kickAt and entry.distinct >= needed then
        Confidence.Clear(src)
        TSIV.AntiCheat.Punish(src, 'kick', rules.kickReason or 'Anticheat confidence threshold', 0, lines)
        return true
    end

    local alertAt = rules.alertAt or 0
    if alertAt > 0 and entry.total >= alertAt then
        local cooldown = rules.alertCooldown or 20.0
        if not alerted[src] or now - alerted[src] >= cooldown then
            alerted[src] = now
            TSIV.AntiCheat.Punish(src, 'alert', ('%s (watching)'):format(reason or module), 0, lines)
        end
    end

    return false
end

AddEventHandler('playerDropped', function()
    Confidence.Clear(source)
end)

TSIV.RegisterRequest('anticheat.confidence', 'staff.alerts', function(_, payload)
    local target = TSIV.ResolveTarget(payload.target)
    if not target then
        return { title = 'Anticheat confidence', lines = { 'That player isnt online !' } }
    end
    return {
        title = ('Anticheat confidence for %s'):format(TSIV.Describe(target)),
        lines = Confidence.Lines(target),
    }
end)
