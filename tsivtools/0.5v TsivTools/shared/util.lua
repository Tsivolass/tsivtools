tsivtools = tsivtools or {}

tsivtools.resource = GetCurrentResourceName()

local rankByName = {}
local ranksSorted = {}

for _, rank in ipairs(Config.Ranks) do
    rankByName[rank.name] = rank
    ranksSorted[#ranksSorted + 1] = rank
end

table.sort(ranksSorted, function(a, b) return a.level < b.level end)

function tsivtools.RankLevel(name)
    if not name then return 0 end
    local rank = rankByName[name]
    return rank and rank.level or 0
end

function tsivtools.RankLabel(name)
    local rank = rankByName[name]
    return rank and rank.label or tostring(name)
end

function tsivtools.RankExists(name)
    return rankByName[name] ~= nil
end

function tsivtools.Ranks()
    return ranksSorted
end

function tsivtools.PermissionLevel(key)
    local required = Config.Permissions[key]
    if required == false then return nil end
    if required == nil then
        return ranksSorted[#ranksSorted].level
    end
    return tsivtools.RankLevel(required)
end

function tsivtools.FeatureEnabled(key)
    return Config.Features[key] ~= false
end

function tsivtools.HasPermission(rankName, key)
    if not tsivtools.FeatureEnabled(key) then return false end
    local needed = tsivtools.PermissionLevel(key)
    if needed == nil then return false end
    return tsivtools.RankLevel(rankName) >= needed
end

function tsivtools.Trim(str)
    if type(str) ~= 'string' then return '' end
    return (str:gsub('^%s*(.-)%s*$', '%1'))
end

function tsivtools.ToNumber(value)
    local n = tonumber(value)
    if not n then return nil end
    if n ~= n then return nil end
    if n == math.huge or n == -math.huge then return nil end
    return n
end

function tsivtools.ToInt(value, min, max)
    local n = tsivtools.ToNumber(value)
    if not n then return nil end
    n = math.floor(n)
    if min and n < min then return nil end
    if max and n > max then return nil end
    return n
end

function tsivtools.SafeString(value, maxLength)
    if type(value) ~= 'string' then
        if value == nil then return '' end
        value = tostring(value)
    end
    value = value:gsub('%c', ' '):gsub('%^%d', '')
    value = tsivtools.Trim(value)
    maxLength = maxLength or 128
    if #value > maxLength then
        value = value:sub(1, maxLength)
    end
    return value
end

function tsivtools.Round(value, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(value * mult + 0.5) / mult
end

function tsivtools.FormatDuration(minutes)
    minutes = tonumber(minutes) or 0
    if minutes <= 0 then return 'permanent' end
    local days = math.floor(minutes / 1440)
    local hours = math.floor((minutes % 1440) / 60)
    local mins = math.floor(minutes % 60)
    local parts = {}
    if days > 0 then parts[#parts + 1] = days .. 'd' end
    if hours > 0 then parts[#parts + 1] = hours .. 'h' end
    if mins > 0 then parts[#parts + 1] = mins .. 'm' end
    return table.concat(parts, ' ')
end

function tsivtools.FormatTimestamp(unix)
    if not unix or unix <= 0 then return 'never' end
    return os.date('%Y-%m-%d %H:%M:%S', unix)
end

function tsivtools.BuildModelSet(list)
    local set = {}
    for _, entry in ipairs(list or {}) do
        if type(entry) == 'number' then
            set[entry] = entry
        elseif type(entry) == 'string' then
            local lower = entry:lower()
            set[lower] = lower
            set[GetHashKey(lower)] = lower
        end
    end
    return set
end

function tsivtools.TableCount(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

function tsivtools.Copy(tbl)
    local out = {}
    for key, value in pairs(tbl) do
        if type(value) == 'table' then
            out[key] = tsivtools.Copy(value)
        else
            out[key] = value
        end
    end
    return out
end

local Window = {}
Window.__index = Window

function tsivtools.NewWindow(seconds)
    return setmetatable({ seconds = seconds, entries = {} }, Window)
end

function Window:push(value)
    local now = GetGameTimer() / 1000.0
    local cutoff = now - self.seconds
    local kept = {}
    for _, entry in ipairs(self.entries) do
        if entry.at >= cutoff then
            kept[#kept + 1] = entry
        end
    end
    kept[#kept + 1] = { at = now, value = value }
    self.entries = kept

    local values = {}
    for index, entry in ipairs(kept) do
        values[index] = entry.value
    end
    return #kept, values
end

function Window:reset()
    self.entries = {}
end

local prefix = 'tsivtools:'

tsivtools.Events = {
    action      = prefix .. 'sv:action',
    request     = prefix .. 'sv:request',
    report      = prefix .. 'sv:report',
    ready       = prefix .. 'sv:ready',
    staffChat   = prefix .. 'sv:staffChat',

    response    = prefix .. 'cl:response',
    permissions = prefix .. 'cl:permissions',
    console     = prefix .. 'cl:console',
    notify      = prefix .. 'cl:notify',
    run         = prefix .. 'cl:run',
    alert       = prefix .. 'cl:alert',
    chat        = prefix .. 'cl:chat',
}
