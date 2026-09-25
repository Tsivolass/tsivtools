tsivtools.Detections = {}

local Detections = tsivtools.Detections
local settings = Config.anticheat

local meleeWeapons    = tsivtools.BuildModelSet(settings.punch.meleeWeapons)
local damagingWeapons = tsivtools.BuildModelSet(settings.godmode.weapons)

local strikes  = {}
local joinedAt = {}
local lastShot = {}
local melee    = {}
local pending  = {}
local beats    = {}
local tokens   = {}

local pedCache = {}
local pedCacheAt = 0

local function seconds()
    return GetGameTimer() / 1000.0
end

local function moduleOn(key, rules)
    return settings.enabled and tsivtools.Module(key) and rules.enabled
end

local function strike(src, kind, limit, window)
    strikes[src] = strikes[src] or {}

    local now = seconds()
    local entry = strikes[src][kind]

    if not entry or now - entry.first > window then
        entry = { count = 0, first = now }
        strikes[src][kind] = entry
    end

    entry.count = entry.count + 1

    if limit > 0 and entry.count >= limit then
        strikes[src][kind] = nil
        return entry.count, true
    end
    return entry.count, false
end

local function sessionAge(src)
    local at = joinedAt[src]
    if not at then return math.huge end
    return seconds() - at
end

local function inSet(set, hash)
    if not hash then return false end
    if set[hash] then return true end
    local flipped = hash < 0 and (hash + 4294967296) or (hash - 4294967296)
    return set[flipped] ~= nil
end

local function vitality(ped)
    local health = GetEntityHealth(ped)
    return health + GetPedArmour(ped), health
end

local function refreshPeds()
    local now = seconds()
    if now - pedCacheAt < settings.pedCacheSeconds then return end
    pedCacheAt = now

    local map = {}
    for _, raw in ipairs(GetPlayers()) do
        local src = tonumber(raw)
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 then map[ped] = src end
    end
    pedCache = map
end

local function playerFromEntity(entity)
    if not entity or entity == 0 then return nil end

    local src = pedCache[entity]
    if src and GetPlayerName(src) and GetPlayerPed(src) == entity then return src end

    refreshPeds()
    src = pedCache[entity]
    if src and GetPlayerName(src) then return src end
    return nil
end

local function hitPlayers(data)
    local out, seen = {}, {}

    local function add(netId)
        netId = tonumber(netId)
        if not netId or netId == 0 or seen[netId] then return end
        seen[netId] = true

        local entity = NetworkGetEntityFromNetworkId(netId)
        local victim = playerFromEntity(entity)
        if victim then out[#out + 1] = victim end
    end

    if type(data.hitGlobalIds) == 'table' then
        for _, netId in ipairs(data.hitGlobalIds) do add(netId) end
    end
    add(data.hitGlobalId)

    return out
end

local function aimOffset(shooter, victim)
    local rules = settings.silentAim

    local from = GetPlayerPed(shooter)
    local to   = GetPlayerPed(victim)
    if not from or from == 0 or not to or to == 0 then return nil end

    if rules.skipInVehicle and GetVehiclePedIsIn(from, false) ~= 0 then return nil end
    if rules.requireVisible and not IsEntityVisible(to) then return nil end

    local origin = GetEntityCoords(from)
    local target = GetEntityCoords(to)

    local dx = target.x - origin.x
    local dy = target.y - origin.y
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance < rules.minDistance or distance > rules.maxDistance then return nil end

    local heading = GetEntityHeading(from) % 360.0
    local bearing = math.deg(math.atan(-dx, dy)) % 360.0
    local off = math.abs((bearing - heading + 180.0) % 360.0 - 180.0)

    return off, distance
end

local function allowedOffset(distance)
    local rules = settings.silentAim
    local allowed = math.deg(math.atan(rules.lateralTolerance / distance))
    if allowed < rules.minAngle then allowed = rules.minAngle end
    if allowed > rules.maxAngle then allowed = rules.maxAngle end
    return allowed
end

function Detections.CheckSilentAim(src, victims, weapon)
    local rules = settings.silentAim
    if not moduleOn('silentAim', rules) then return end
    if sessionAge(src) < rules.joinGrace then return end

    local now = GetGameTimer()
    if lastShot[src] and now - lastShot[src] < rules.sampleCooldownMs then return end

    for _, victim in ipairs(victims) do
        if victim ~= src and not tsivtools.AntiCheat.IsExempt(victim) then
            local off, distance = aimOffset(src, victim)
            if off then
                lastShot[src] = now

                local allowed = allowedOffset(distance)
                local lateral = off >= 89.9 and math.huge or distance * math.tan(math.rad(off))

                if off > allowed and lateral > rules.lateralTolerance then
                    local count, reached = strike(src, 'silentaim', rules.strikes, rules.strikeWindow)
                    if reached then
                        tsivtools.AntiCheat.Punish(src, rules.action, rules.reason, rules.banLength, {
                            ('victim    : %s (id %s)'):format(tsivtools.GetName(victim), victim),
                            ('weapon    : %s'):format(tsivtools.AntiCheat.ModelLabel(weapon)),
                            ('distance  : %.1f m'):format(distance),
                            ('aim off   : %.1f degrees, allowed %.1f'):format(off, allowed),
                            ('side miss : %.2f m, tolerance %.2f m'):format(
                                lateral == math.huge and 999.0 or lateral, rules.lateralTolerance),
                            ('strikes   : %d in %.0f second(s)'):format(count, rules.strikeWindow),
                        })
                        return
                    end
                end
                return
            end
        end
    end
end

function Detections.CheckPing(src)
    local rules = settings.pingGate
    if not moduleOn('pingGate', rules) then return false end
    if rules.action == 'off' then return false end
    if rules.maxPing <= 0 then return false end

    local ping = GetPlayerPing(src)
    if ping <= rules.maxPing then return false end

    local count, reached = strike(src, 'ping', rules.strikes, rules.window)

    if rules.action == 'kick' or reached then
        tsivtools.AntiCheat.Punish(src, rules.action == 'block' and 'kick' or rules.action, rules.reason, rules.banLength, {
            ('ping      : %d ms, limit is %d ms'):format(ping, rules.maxPing),
            ('blocked   : %d shot(s) in %.0f second(s)'):format(count, rules.window),
        })
    end

    return true
end

function Detections.CheckGodmode(src, victims, weapon)
    local rules = settings.godmode
    if not moduleOn('godmode', rules) then return end
    if not inSet(damagingWeapons, weapon) then return end

    for _, victim in ipairs(victims) do
        if victim ~= src and not pending[victim] then
            local allowed = (rules.skipExempt and tsivtools.AntiCheat.IsExempt(victim)) or tsivtools.Can(victim, 'self.godmode')
            local ped = GetPlayerPed(victim)
            if not allowed and ped ~= 0 and sessionAge(victim) >= rules.joinGrace then
                local before, health = vitality(ped)

                if health > 0 then
                    pending[victim] = true

                    SetTimeout(rules.checkDelayMs, function()
                        pending[victim] = nil
                        if not GetPlayerName(victim) then return end
                        if GetPlayerPed(victim) ~= ped then return end

                        local after = vitality(ped)
                        if after < before then return end

                        local count, reached = strike(victim, 'godmode', rules.strikes, rules.strikeWindow)
                        if not reached then return end

                        tsivtools.AntiCheat.Punish(victim, rules.action, rules.reason, rules.banLength, {
                            ('shot by   : %s (id %s)'):format(tsivtools.GetName(src), src),
                            ('weapon    : %s'):format(tsivtools.AntiCheat.ModelLabel(weapon)),
                            ('health    : %d before, %d after %d ms'):format(before, after, rules.checkDelayMs),
                            ('strikes   : %d in %.0f second(s)'):format(count, rules.strikeWindow),
                        })
                    end)
                end
            end
        end
    end
end

function Detections.CheckMelee(src, victims, weapon)
    local rules = settings.punch
    if not moduleOn('punch', rules) then return false end
    if #victims == 0 then return false end

    local state = melee[src]
    if not state then
        state = { at = 0, victims = {}, recent = tsivtools.NewWindow(rules.multiWindow) }
        melee[src] = state
    end

    local now = GetGameTimer()
    local problem = nil

    if now - state.at < rules.minIntervalMs then
        problem = ('%d ms since the last hit, minimum is %d ms'):format(now - state.at, rules.minIntervalMs)
    end

    for _, victim in ipairs(victims) do
        local last = state.victims[victim]
        if not problem and last and now - last < rules.victimIntervalMs then
            problem = ('hit %s again after %d ms, minimum is %d ms'):format(
                tsivtools.GetName(victim), now - last, rules.victimIntervalMs)
        end
        state.victims[victim] = now
    end

    local _, recent = state.recent:push(victims[1])
    for index = 2, #victims do
        _, recent = state.recent:push(victims[index])
    end

    local distinct, unique = 0, {}
    for _, victim in ipairs(recent) do
        if not unique[victim] then
            unique[victim] = true
            distinct = distinct + 1
        end
    end

    if not problem and distinct >= rules.multiTargets then
        problem = ('%d different players hit within %.1f second(s)'):format(distinct, rules.multiWindow)
    end

    state.at = now

    if not problem then return false end

    local count, reached = strike(src, 'punch', rules.strikes, rules.strikeWindow)
    if reached then
        tsivtools.AntiCheat.Punish(src, rules.action, rules.reason, rules.banLength, {
            ('weapon    : %s'):format(tsivtools.AntiCheat.ModelLabel(weapon)),
            ('problem   : %s'):format(problem),
            ('strikes   : %d in %.0f second(s)'):format(count, rules.strikeWindow),
        })
    end

    return rules.block
end

AddEventHandler('weaponDamageEvent', function(sender, data)
    if not settings.enabled then return end
    if type(data) ~= 'table' then return end

    local src = tonumber(sender)
    if not src or not GetPlayerName(src) then return end

    local pingOn   = moduleOn('pingGate', settings.pingGate)
    local silentOn = moduleOn('silentAim', settings.silentAim)
    local godOn    = moduleOn('godmode', settings.godmode)
    local meleeOn  = moduleOn('punch', settings.punch)
    if not (pingOn or silentOn or godOn or meleeOn) then return end

    local exempt = tsivtools.AntiCheat.IsExempt(src)

    if pingOn and not exempt and Detections.CheckPing(src) then
        CancelEvent()
        return
    end

    local weapon = tonumber(data.weaponType) or 0
    local victims = hitPlayers(data)
    if #victims == 0 then return end

    local isMelee = inSet(meleeWeapons, weapon) or tonumber(data.damageType) == 1

    if isMelee then
        if meleeOn and not exempt and Detections.CheckMelee(src, victims, weapon) then
            CancelEvent()
            return
        end
    elseif silentOn and not exempt then
        Detections.CheckSilentAim(src, victims, weapon)
    end

    if godOn then
        local override = data.overrideDefaultDamage
        local amount = tonumber(data.weaponDamage) or 0
        if not (override and amount <= 0 and not data.willKill) then
            Detections.CheckGodmode(src, victims, weapon)
        end
    end
end)

local function newToken()
    return ('%06x%06x'):format(math.random(0, 0xFFFFFF), math.random(0, 0xFFFFFF))
end

function Detections.StartHeartbeat(src)
    local rules = settings.heartbeat
    local now = seconds()

    beats[src] = { at = now, since = now }
    tokens[src] = newToken()
    TriggerClientEvent(tsivtools.Events.heartbeat, src, rules.intervalSeconds, tokens[src])
end

RegisterNetEvent(tsivtools.Events.beat, function(token)
    local src = source
    local rules = settings.heartbeat

    local entry = beats[src]
    if not entry then return end
    if seconds() - entry.at < 1.0 then return end
    if rules.useToken and token ~= tokens[src] then return end

    entry.at = seconds()
    tokens[src] = newToken()
    TriggerClientEvent(tsivtools.Events.heartbeat, src, rules.intervalSeconds, tokens[src])
end)

CreateThread(function()
    math.randomseed(math.floor(GetGameTimer()) + os.time())

    while true do
        local rules = settings.heartbeat
        Wait(math.max(5, rules.intervalSeconds) * 1000)

        if moduleOn('heartbeat', rules) then
            local now = seconds()
            local limit = rules.intervalSeconds * (rules.missTolerance + 1)

            for _, raw in ipairs(GetPlayers()) do
                local src = tonumber(raw)
                local entry = beats[src]

                if not entry then
                    Detections.StartHeartbeat(src)
                elseif now - entry.since > rules.graceSeconds
                    and now - entry.at > limit
                    and not tsivtools.AntiCheat.IsExempt(src) then
                    beats[src] = nil
                    tokens[src] = nil
                    tsivtools.AntiCheat.Punish(src, rules.action, rules.reason, rules.banLength, {
                        ('last beat : %.0f second(s) ago'):format(now - entry.at),
                        ('expected  : every %d second(s), %d missed allowed'):format(
                            rules.intervalSeconds, rules.missTolerance),
                    })
                end
            end
        end
    end
end)

AddEventHandler('playerJoining', function()
    local src = source
    joinedAt[src] = seconds()
    pedCacheAt = 0
end)

AddEventHandler('playerDropped', function()
    local src = source
    strikes[src] = nil
    joinedAt[src] = nil
    lastShot[src] = nil
    melee[src] = nil
    pending[src] = nil
    beats[src] = nil
    tokens[src] = nil
    pedCacheAt = 0

    for _, state in pairs(melee) do
        state.victims[src] = nil
    end
end)

CreateThread(function()
    Wait(1000)
    local now = seconds()
    for _, raw in ipairs(GetPlayers()) do
        joinedAt[tonumber(raw)] = now
    end
end)
