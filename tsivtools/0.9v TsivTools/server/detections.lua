TSIV.Detections = {}

local Detections = TSIV.Detections
local settings = Config.anticheat

local meleeWeapons    = TSIV.BuildModelSet(settings.punch and settings.punch.meleeWeapons)
local damagingWeapons = TSIV.BuildModelSet(settings.godmode and settings.godmode.weapons)

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
    if not settings.enabled then return false end
    if not TSIV.Module(key) then return false end
    if rules and rules.enabled == false then return false end
    return true
end

local function punish(src, action, reason, banLength, detail)
    if TSIV.AntiCheat and TSIV.AntiCheat.Punish then
        TSIV.AntiCheat.Punish(src, action, reason, banLength, detail)
    end
end

local function isExempt(src)
    if TSIV.AntiCheat and TSIV.AntiCheat.IsExempt then
        return TSIV.AntiCheat.IsExempt(src)
    end
    return false
end

local function strike(src, kind, limit, window)
    strikes[src] = strikes[src] or {}

    local now = seconds()
    local entry = strikes[src][kind]

    if not entry or now - entry.first > (window or 60.0) then
        entry = { count = 0, first = now }
        strikes[src][kind] = entry
    end

    entry.count = entry.count + 1

    if limit and limit > 0 and entry.count >= limit then
        strikes[src][kind] = nil
        return entry.count, true
    end
    return entry.count, false
end

local function route(src, module, rules, points, detail)
    if rules.action == 'confidence' or rules.action == nil then
        TSIV.Confidence.Add(src, module, points, rules.reason, detail)
        return
    end

    local count, reached = strike(src, module, rules.strikes, rules.strikeWindow)
    detail[#detail + 1] = ('strikes   : %d in %.0f second(s)'):format(count, rules.strikeWindow)
    if reached then
        punish(src, rules.action, rules.reason, rules.banLength, detail)
    end
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

local function safeCall(fn, fallback, ...)
    if type(fn) ~= 'function' then return fallback end
    local ok, value = pcall(fn, ...)
    if not ok or value == nil then return fallback end
    return value
end

local function isVisible(entity)
    return safeCall(IsEntityVisible, true, entity) and true or false
end

local function inVehicle(ped)
    local vehicle = safeCall(GetVehiclePedIsIn, 0, ped)
    return vehicle ~= nil and vehicle ~= 0
end

local function vitality(ped)
    local health = safeCall(GetEntityHealth, 0, ped) or 0
    local armour = safeCall(GetPedArmour, 0, ped) or 0
    return health + armour, health
end

local function refreshPeds()
    local now = seconds()
    if now - pedCacheAt < (settings.pedCacheSeconds or 3.0) then return end
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

local function velocityOf(entity)
    local ok, velocity = pcall(GetEntityVelocity, entity)
    if not ok or not velocity then return 0.0, 0.0, 0.0 end
    return velocity.x or 0.0, velocity.y or 0.0, velocity.z or 0.0
end

local function hitPoint(victim, data)
    local ped = GetPlayerPed(victim)
    if not ped or ped == 0 then return nil end

    local coords = GetEntityCoords(ped)
    if not coords then return nil end

    local x, y, z = coords.x, coords.y, coords.z
    local rules = settings.silentAim

    if rules.useHitOffset ~= false and type(data.localPosition) == 'table' then
        local offset = data.localPosition
        local ox = tonumber(offset.x) or tonumber(offset[1]) or 0.0
        local oy = tonumber(offset.y) or tonumber(offset[2]) or 0.0
        local oz = tonumber(offset.z) or tonumber(offset[3]) or 0.0
        local reach = rules.maxHitOffset or 1.5
        if math.abs(ox) <= reach and math.abs(oy) <= reach and math.abs(oz) <= reach then
            local heading = math.rad(GetEntityHeading(ped))
            local sinH, cosH = math.sin(heading), math.cos(heading)
            x = x + (ox * cosH - oy * sinH)
            y = y + (ox * sinH + oy * cosH)
            z = z + oz
        end
    end

    return x, y, z, ped
end

Detections.AimPoint = hitPoint

local function aimSource(src)
    local rules = settings.silentAim

    if rules.useClientAim ~= false and TSIV.Aimbot and TSIV.Aimbot.LastAim then
        local yaw, pitch, age = TSIV.Aimbot.LastAim(src)
        if yaw and age <= (rules.maxClientAimAgeMs or 900) then
            return yaw, pitch, 'camera'
        end
    end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityHeading(ped) % 360.0, 0.0, 'heading'
end

local function toleranceFor(src, victim, distance)
    local rules = settings.silentAim
    local tolerance = rules.lateralTolerance or 2.25

    if rules.latencyCompensation ~= false then
        local ping = (GetPlayerPing(src) or 0) / 1000.0
        if ping > (rules.maxCompensatedPing or 1.0) then ping = rules.maxCompensatedPing or 1.0 end

        local vx, vy, vz = velocityOf(GetPlayerPed(victim))
        local speed = math.sqrt(vx * vx + vy * vy + vz * vz)

        local drift = ping * speed * (rules.latencyFactor or 1.0)
        local cap = rules.maxCompensationMetres or 6.0
        if drift > cap then drift = cap end

        tolerance = tolerance + drift
    end

    if rules.distanceSlack and rules.distanceSlack > 0 then
        tolerance = tolerance + distance * rules.distanceSlack
    end

    return tolerance
end

local function allowedOffset(distance, tolerance)
    local rules = settings.silentAim
    local allowed = math.deg(math.atan(tolerance / distance))
    if allowed < rules.minAngle then allowed = rules.minAngle end
    if allowed > rules.maxAngle then allowed = rules.maxAngle end
    return allowed
end

Detections.AllowedOffset = allowedOffset

local function flagSilent(src, points, detail)
    local rules = settings.silentAim
    if rules.action == 'confidence' or rules.action == nil then
        TSIV.Confidence.Add(src, 'silentaim', points, rules.reason, detail)
        return
    end

    local count, reached = strike(src, 'silentaim', rules.strikes, rules.strikeWindow)
    detail[#detail + 1] = ('strikes   : %d in %.0f second(s)'):format(count, rules.strikeWindow)
    if reached then
        punish(src, rules.action, rules.reason, rules.banLength, detail)
    end
end

function Detections.CheckSilentAim(src, victims, weapon, data)
    local rules = settings.silentAim
    if not rules then return end
    if not moduleOn('silentAim', rules) then return end
    if sessionAge(src) < (rules.joinGrace or 0) then return end

    local shooter = GetPlayerPed(src)
    if not shooter or shooter == 0 then return end
    if rules.skipInVehicle and inVehicle(shooter) then return end

    local now = GetGameTimer()
    if lastShot[src] and now - lastShot[src] < (rules.sampleCooldownMs or 0) then return end

    local origin = GetEntityCoords(shooter)
    if not origin then return end

    local yaw, pitch, kind = aimSource(src)
    if not yaw then return end

    local eye = rules.eyeHeight or 0.6
    local worst = nil

    for _, victim in ipairs(victims) do
        if victim ~= src and not isExempt(victim) then
            local x, y, z, ped = hitPoint(victim, data)
            if x and not (rules.requireVisible and not isVisible(ped)) then
                local targetYaw, targetPitch, distance, flat =
                    TSIV.Aim.Bearing(origin.x, origin.y, origin.z + eye, x, y, z)

                if targetYaw
                    and distance >= (rules.minDistance or 6.0)
                    and distance <= (rules.maxDistance or 400.0) then

                    local off
                    if kind == 'camera' then
                        off = TSIV.Aim.Between(yaw, pitch, targetYaw, targetPitch)
                    else
                        off = math.abs((targetYaw - yaw + 180.0) % 360.0 - 180.0)
                        distance = flat
                    end

                    local tolerance = toleranceFor(src, victim, distance)
                    local allowed = allowedOffset(distance, tolerance)
                    local lateral = off >= 89.9 and math.huge or distance * math.tan(math.rad(off))

                    if off > allowed and lateral > tolerance then
                        local severity = off / math.max(0.01, allowed)
                        if not worst or severity > worst.severity then
                            worst = {
                                severity = severity,
                                victim = victim,
                                off = off,
                                allowed = allowed,
                                lateral = lateral,
                                tolerance = tolerance,
                                distance = distance,
                            }
                        end
                    end
                end
            end
        end
    end

    lastShot[src] = now
    if not worst then return end

    local points = (rules.points or 35) * math.min(2.0, worst.severity) * 0.5

    flagSilent(src, points, {
        ('victim    : %s (id %s)'):format(TSIV.GetName(worst.victim), worst.victim),
        ('weapon    : %s'):format(TSIV.AntiCheat.ModelLabel(weapon)),
        ('aim from  : %s'):format(kind == 'camera' and 'reported camera' or 'ped heading'),
        ('distance  : %.1f m'):format(worst.distance),
        ('aim off   : %.1f degrees, allowed %.1f'):format(worst.off, worst.allowed),
        ('side miss : %.2f m, tolerance %.2f m'):format(
            worst.lateral == math.huge and 999.0 or worst.lateral, worst.tolerance),
    })
end

function Detections.CheckPing(src)
    local rules = settings.pingGate
    if not moduleOn('pingGate', rules) then return false end
    if rules.action == 'off' then return false end
    if (rules.maxPing or 0) <= 0 then return false end

    local ping = GetPlayerPing(src) or 0
    if ping <= rules.maxPing then return false end

    local count, reached = strike(src, 'ping', rules.strikes, rules.window)

    if rules.action == 'kick' or reached then
        punish(src, rules.action == 'block' and 'kick' or rules.action, rules.reason, rules.banLength, {
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
            local allowed = (rules.skipExempt and isExempt(victim)) or TSIV.Can(victim, 'self.godmode')
            if not allowed and sessionAge(victim) >= (rules.joinGrace or 0) then
                local ped = GetPlayerPed(victim)
                local before, health = vitality(ped)

                if ped and ped ~= 0 and health > 0 then
                    pending[victim] = true

                    SetTimeout(rules.checkDelayMs or 900, function()
                        pending[victim] = nil
                        if not GetPlayerName(victim) then return end
                        if GetPlayerPed(victim) ~= ped then return end

                        local after = vitality(ped)
                        if after < before then return end

                        route(victim, 'godmode', rules, rules.points or 45, {
                            ('shot by   : %s (id %s)'):format(TSIV.GetName(src), src),
                            ('weapon    : %s'):format(TSIV.AntiCheat.ModelLabel(weapon)),
                            ('health    : %d before, %d after %d ms'):format(before, after, rules.checkDelayMs or 900),
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
        state = { at = 0, victims = {}, recent = TSIV.NewWindow(rules.multiWindow) }
        melee[src] = state
    end

    local now = GetGameTimer()
    local problem = nil

    if now - state.at < (rules.minIntervalMs or 0) then
        problem = ('%d ms since the last hit, minimum is %d ms'):format(now - state.at, rules.minIntervalMs)
    end

    for _, victim in ipairs(victims) do
        local last = state.victims[victim]
        if not problem and last and now - last < (rules.victimIntervalMs or 0) then
            problem = ('hit %s again after %d ms, minimum is %d ms'):format(
                TSIV.GetName(victim), now - last, rules.victimIntervalMs)
        end
        state.victims[victim] = now
    end

    local _, recent = state.recent:push(victims[1])
    for index = 2, #victims do
        _, recent = state.recent:push(victims[index])
    end

    local distinct, unique = 0, {}
    for _, victim in ipairs(recent or {}) do
        if not unique[victim] then
            unique[victim] = true
            distinct = distinct + 1
        end
    end

    if not problem and distinct >= (rules.multiTargets or 99) then
        problem = ('%d different players hit within %.1f second(s)'):format(distinct, rules.multiWindow)
    end

    state.at = now

    if not problem then return false end

    route(src, 'punch', rules, rules.points or 12, {
        ('weapon    : %s'):format(TSIV.AntiCheat.ModelLabel(weapon)),
        ('problem   : %s'):format(problem),
    })

    return rules.block ~= false
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
    local aimOn    = moduleOn('aimbot', settings.aimbot)
    if not (pingOn or silentOn or godOn or meleeOn or aimOn) then return end

    local exempt = isExempt(src)

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
    elseif not exempt then
        if silentOn then
            Detections.CheckSilentAim(src, victims, weapon, data)
        end

        if aimOn then
            TSIV.Aimbot.Watch(src)
            local x, y, z = Detections.AimPoint(victims[1], data)
            if x then
                TSIV.Aimbot.Check(src, victims[1], x, y, z, weapon)
            end
        end
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
    TriggerClientEvent(TSIV.Events.heartbeat, src, rules.intervalSeconds, tokens[src])
end

RegisterNetEvent(TSIV.Events.beat, function(token)
    local src = source
    local rules = settings.heartbeat

    local entry = beats[src]
    if not entry then return end
    if rules.useToken and token ~= tokens[src] then return end

    entry.at = seconds()
    tokens[src] = newToken()
    TriggerClientEvent(TSIV.Events.heartbeat, src, rules.intervalSeconds, tokens[src])
end)

CreateThread(function()
    math.randomseed(math.floor(GetGameTimer()) + os.time())

    while true do
        local rules = settings.heartbeat
        Wait(math.max(5, tonumber(rules.intervalSeconds) or 15) * 1000)

        if moduleOn('heartbeat', rules) then
            local now = seconds()
            local limit = rules.intervalSeconds * ((rules.missTolerance or 3) + 1)

            for _, raw in ipairs(GetPlayers()) do
                local src = tonumber(raw)
                local entry = beats[src]

                if not entry then
                    Detections.StartHeartbeat(src)
                elseif now - entry.since > (rules.graceSeconds or 120)
                    and now - entry.at > limit
                    and not isExempt(src) then
                    beats[src] = nil
                    tokens[src] = nil
                    punish(src, rules.action, rules.reason, rules.banLength, {
                        ('last beat : %.0f second(s) ago'):format(now - entry.at),
                        ('expected  : every %d second(s), %d missed allowed'):format(
                            rules.intervalSeconds, rules.missTolerance or 3),
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
        if state.victims then state.victims[src] = nil end
    end
end)

CreateThread(function()
    Wait(1000)
    local now = seconds()
    for _, raw in ipairs(GetPlayers()) do
        joinedAt[tonumber(raw)] = now
    end
end)
