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

local function evidenceOnly(module)
    local list = rules.evidenceOnly
    return list ~= nil and list[module] == true
end

Confidence.EvidenceOnly = evidenceOnly

local function prune(entry, now)
    local window = rules.window or 180.0
    local kept = {}
    local total = 0.0
    local banTotal = 0.0
    local modules = {}
    local distinct = 0
    local banDistinct = 0

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
                    if not evidenceOnly(item.module) then
                        banDistinct = banDistinct + 1
                    end
                end
                modules[item.module] = modules[item.module] + points

                if not evidenceOnly(item.module) then
                    banTotal = banTotal + points
                end
            end
        end
    end

    entry.entries = kept
    entry.total = total
    entry.banTotal = banTotal
    entry.modules = modules
    entry.distinct = distinct
    entry.banDistinct = banDistinct
end

local function breakdown(entry)
    local lines = {}
    local ordered = {}

    for name, points in pairs(entry.modules) do
        ordered[#ordered + 1] = { name = name, points = points }
    end
    table.sort(ordered, function(a, b) return a.points > b.points end)

    for _, item in ipairs(ordered) do
        lines[#lines + 1] = ('  %-12s %5.1f%%%s'):format(
            item.name, item.points, evidenceOnly(item.name) and '  (evidence only)' or '')
    end

    return lines
end

function Confidence.Score(src)
    local entry = scores[src]
    if not entry then return 0, 0, 0, 0 end
    prune(entry, seconds())
    return entry.total, entry.distinct, entry.banTotal, entry.banDistinct
end

function Confidence.Lines(src)
    local entry = scores[src]
    if not entry then return { 'no anticheat confidence on record' } end

    prune(entry, seconds())

    local solo = rules.soloBanAt or 0
    local lines = {
        ('certainty : %.1f%% overall, %.1f%% of it can act'):format(entry.total, entry.banTotal),
        ('ban needs : %.0f%% with %d module(s) agreeing'):format(
            rules.banAt or 100, rules.requireDistinctModules or 2),
        ('or alone  : %s'):format(solo > 0 and ('%.0f%% from one module'):format(solo) or 'never'),
        ('modules   : %d agreeing, %d of them actionable'):format(entry.distinct, entry.banDistinct),
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
    local banAt = rules.banAt or 100
    local solo = rules.soloBanAt or 0
    local kickAt = rules.kickAt or 0

    local lines = {
        ('trigger   : %s'):format(reason or module),
        ('certainty : %.1f%% overall, %.1f%% of it can act'):format(entry.total, entry.banTotal),
        ('threshold : %.0f%% with %d module(s), or %s alone'):format(
            banAt, needed, solo > 0 and ('%.0f%%'):format(solo) or 'never'),
        ('modules   : %d agreeing, %d of them actionable'):format(entry.distinct, entry.banDistinct),
    }
    for _, line in ipairs(detail or {}) do lines[#lines + 1] = line end
    lines[#lines + 1] = 'breakdown :'
    for _, line in ipairs(breakdown(entry)) do lines[#lines + 1] = line end

    local corroborated = entry.banTotal >= banAt and entry.banDistinct >= needed
    local overwhelming = solo > 0 and entry.banTotal >= solo

    if corroborated or overwhelming then
        lines[#lines + 1] = ('verdict   : %s'):format(
            overwhelming and 'one module is past the certain threshold on its own'
            or 'two or more modules agree past the ban threshold')
        Confidence.Clear(src)
        TSIV.AntiCheat.Punish(src, 'ban', rules.banReason or 'Anticheat confidence threshold',
            rules.banLength or 0, lines)
        return true
    end

    if kickAt > 0 and entry.banTotal >= kickAt and entry.banDistinct >= needed then
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
