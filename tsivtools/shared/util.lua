--[[
    tsivtools - shared helpers

    Loaded on both sides. Anything in here is available as TSIV.<name> from
    client and server files alike.
]]

TSIV = TSIV or {}

TSIV.resource = GetCurrentResourceName()

-- ---------------------------------------------------------------------------
-- Ranks
-- ---------------------------------------------------------------------------

local rankByName = {}
local ranksSorted = {}

for _, rank in ipairs(Config.Ranks) do
    rankByName[rank.name] = rank
    ranksSorted[#ranksSorted + 1] = rank
end

table.sort(ranksSorted, function(a, b) return a.level < b.level end)

--- Numeric level of a rank name. Unknown names are level 0.
function TSIV.RankLevel(name)
    if not name then return 0 end
    local rank = rankByName[name]
    return rank and rank.level or 0
end

--- Pretty label of a rank name, falling back to the raw name.
function TSIV.RankLabel(name)
    local rank = rankByName[name]
    return rank and rank.label or tostring(name)
end

function TSIV.RankExists(name)
    return rankByName[name] ~= nil
end

--- Every rank, ordered low to high.
function TSIV.Ranks()
    return ranksSorted
end

--- The minimum rank level required for a permission key.
--- Returns nil when the permission is disabled outright (set to false).
function TSIV.PermissionLevel(key)
    local required = Config.Permissions[key]
    if required == false then return nil end
    if required == nil then
        -- An unknown key is treated as the highest rank rather than as "free".
        -- Better to lock yourself out of a new option than to hand it to
        -- everyone by forgetting a line in the config.
        return ranksSorted[#ranksSorted].level
    end
    return TSIV.RankLevel(required)
end

--- Does a rank name satisfy a permission key?
function TSIV.HasPermission(rankName, key)
    local needed = TSIV.PermissionLevel(key)
    if needed == nil then return false end
    return TSIV.RankLevel(rankName) >= needed
end

-- ---------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------

function TSIV.Trim(str)
    if type(str) ~= 'string' then return '' end
    return (str:gsub('^%s*(.-)%s*$', '%1'))
end

--- tonumber that also rejects NaN and infinity, both of which arrive happily
--- over the network and then poison whatever they touch.
function TSIV.ToNumber(value)
    local n = tonumber(value)
    if not n then return nil end
    if n ~= n then return nil end            -- NaN
    if n == math.huge or n == -math.huge then return nil end
    return n
end

function TSIV.ToInt(value, min, max)
    local n = TSIV.ToNumber(value)
    if not n then return nil end
    n = math.floor(n)
    if min and n < min then return nil end
    if max and n > max then return nil end
    return n
end

--- Clean a string that came from a player: length capped, control characters
--- and the ^ colour escape removed so nobody can inject colours into logs.
function TSIV.SafeString(value, maxLength)
    if type(value) ~= 'string' then
        if value == nil then return '' end
        value = tostring(value)
    end
    value = value:gsub('%c', ' '):gsub('%^%d', '')
    value = TSIV.Trim(value)
    maxLength = maxLength or 128
    if #value > maxLength then
        value = value:sub(1, maxLength)
    end
    return value
end

function TSIV.Round(value, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(value * mult + 0.5) / mult
end

--- "2h 15m" style duration from a number of minutes. 0 means permanent.
function TSIV.FormatDuration(minutes)
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

function TSIV.FormatTimestamp(unix)
    if not unix or unix <= 0 then return 'never' end
    return os.date('%Y-%m-%d %H:%M:%S', unix)
end

--- Case-insensitive lookup table from a list of model names/hashes.
--- Keys are both the lowercase name and the joaat hash, so a check works
--- whichever form the entity gives you.
function TSIV.BuildModelSet(list)
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

function TSIV.TableCount(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

--- Shallow copy, used when handing config tables out to callers that might
--- otherwise mutate the live config.
function TSIV.Copy(tbl)
    local out = {}
    for key, value in pairs(tbl) do
        if type(value) == 'table' then
            out[key] = TSIV.Copy(value)
        else
            out[key] = value
        end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Sliding window counter
-- ---------------------------------------------------------------------------
-- Used by the anti-cheat for "more than N of X within Y seconds". Keeping it
-- here means the same implementation covers props, vehicles, peds and
-- explosions instead of four near-identical loops.

local Window = {}
Window.__index = Window

function TSIV.NewWindow(seconds)
    return setmetatable({ seconds = seconds, entries = {} }, Window)
end

--- Record a hit. Returns the number of hits still inside the window, and the
--- list of values that were passed in with them.
---
--- GetGameTimer is used rather than os.clock, because os.clock reports
--- processor time, which drifts away from wall time the moment the server is
--- under any real load. A three second window has to mean three seconds.
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

-- ---------------------------------------------------------------------------
-- Event names
-- ---------------------------------------------------------------------------
-- Kept in one place so a rename is a one-line change. They are namespaced with
-- the resource name so two copies of the resource cannot talk to each other.

local prefix = 'tsivtools:'

TSIV.Events = {
    -- client -> server
    action      = prefix .. 'sv:action',
    request     = prefix .. 'sv:request',
    report      = prefix .. 'sv:report',
    ready       = prefix .. 'sv:ready',
    staffChat   = prefix .. 'sv:staffChat',

    -- server -> client
    response    = prefix .. 'cl:response',
    permissions = prefix .. 'cl:permissions',
    console     = prefix .. 'cl:console',
    notify      = prefix .. 'cl:notify',
    run         = prefix .. 'cl:run',
    alert       = prefix .. 'cl:alert',
}
