tsivtools.Aimbot = {}

local Aimbot = tsivtools.Aimbot
local rules = Config.anticheat.aimbot or { enabled = false }
local Aim = tsivtools.Aim

local reports = {}
local accepted = {}
local watched = {}
local headings = {}
local overshoot = {}
local missing = {}

local function seconds()
    return GetGameTimer() / 1000.0
end

local function active()
    if not Config.anticheat.enabled then return false end
    if not tsivtools.Module('aimbot') then return false end
    return rules.enabled ~= false
end

local function flag(src, module, points, reason, detail)
    if rules.action == 'confidence' or rules.action == nil then
        tsivtools.Confidence.Add(src, module, points, reason, detail)
        return
    end
    tsivtools.AntiCheat.Punish(src, rules.action, reason, rules.banLength or 0, detail)
end

RegisterNetEvent(tsivtools.Events.aim, function(packed, pad)
    local src = source
    if not active() then return end
    if type(packed) ~= 'table' then return end

    local count = #packed
    if count % 3 ~= 0 then return end
    if count < 9 then return end

    if count > (rules.maxPacked or 900) then
        if not Aimbot.warnedSize then
            Aimbot.warnedSize = true
            print(('%saim reports are bigger than maxPacked (%d numbers), raise Config.anticheat.aimbot.maxPacked or lower windowMs')
                :format(Config.consoleprefix, count))
        end
        return
    end

    local now = GetGameTimer()
    local gate = (rules.reportCooldownMs or 250) * 0.5
    if accepted[src] and now - accepted[src] < gate then return end
    accepted[src] = now

    local window = (rules.windowMs or 600) + 200
    local samples = {}
    local total = 0
    local previousAge = nil

    for index = 1, count, 3 do
        local age = packed[index]
        local yaw = packed[index + 1]
        local pitch = packed[index + 2]

        if type(age) ~= 'number' or type(yaw) ~= 'number' or type(pitch) ~= 'number' then return end
        if age < 0 or age > window then return end
        if yaw < -3600 or yaw > 3600 then return end
        if pitch < -900 or pitch > 900 then return end
        if previousAge and age > previousAge then return end
        previousAge = age

        total = total + 1
        samples[total] = { t = -age, yaw = yaw / 10.0, pitch = pitch / 10.0 }
    end

    if total < (rules.minSamples or 6) then return end

    reports[src] = { at = now, samples = samples, count = total, pad = pad == true }
    Aimbot.Watch(src)
end)

function Aimbot.LastAim(src)
    local report = reports[src]
    if not report or not report.count then return nil end

    local final = report.samples[report.count]
    if not final then return nil end

    return final.yaw, final.pitch, GetGameTimer() - report.at
end

function Aimbot.Watch(src)
    if not active() then return end
    if rules.serverCheck and rules.serverCheck.enabled == false then return end
    watched[src] = seconds() + (rules.serverCheck and rules.serverCheck.watchSeconds or 20.0)
end

local function serverPath(src, fromMs, toMs)
    local ring = headings[src]
    if not ring then return nil end

    local previous = nil
    local length = 0.0
    local seen = 0

    for _, sample in ipairs(ring) do
        if sample.t >= fromMs and sample.t <= toMs then
            if previous then
                local step = math.abs((sample.yaw - previous + 180.0) % 360.0 - 180.0)
                length = length + step
            end
            previous = sample.yaw
            seen = seen + 1
        end
    end

    if seen < 3 then return nil end
    return length, seen
end

function Aimbot.Missing(src)
    local gate = rules.missing
    if not gate or gate.enabled == false then return end
    if tsivtools.AntiCheat.IsExempt(src) then return end

    missing[src] = (missing[src] or 0) + 1
    if missing[src] < (gate.shots or 12) then return end

    missing[src] = 0
    tsivtools.AntiCheat.Punish(src, gate.action or 'kick',
        gate.reason or 'TsivTools aim module is not answering', gate.banLength or 0, {
            ('shots     : %d fired with no aim data'):format(gate.shots or 12),
            'note      : the client module was blocked or stopped',
        })
end

function Aimbot.Check(src, victim, aimX, aimY, aimZ, weapon)
    if not active() then return end

    local shooter = GetPlayerPed(src)
    if shooter == 0 or GetVehiclePedIsIn(shooter, false) ~= 0 then return end

    local report = reports[src]
    if not report or (GetGameTimer() - report.at) > (rules.maxReportAgeMs or 900) then
        Aimbot.Missing(src)
        return
    end

    missing[src] = 0

    if report.pad and rules.controller == 'skip' then return end

    local origin = GetEntityCoords(shooter)
    if not origin then return end

    local eye = rules.eyeHeight or 0.6
    local targetYaw, targetPitch, distance = Aim.Bearing(origin.x, origin.y, origin.z + eye, aimX, aimY, aimZ)
    if not targetYaw then return end
    if distance < (rules.minDistance or 4.0) then return end

    local samples = report.samples
    local count = report.count

    local final = samples[count]
    local lockCone = rules.lockCone or 6.0
    if Aim.Between(final.yaw, final.pitch, targetYaw, targetPitch) > lockCone then return end

    local first, last = Aim.FindSnap(samples, count, rules.idleStep or 0.35, rules.maxGap or 2)
    if not first then return end

    local vectors, vectorCount = Aim.Vectors(samples, first, last)
    local metrics = Aim.PathMetrics(vectors, vectorCount, rules.corridorDegrees or 1.5)
    if not metrics then return end

    local delta = metrics.displacement
    if delta < (rules.minSnapDegrees or 12.0) then return end

    local scale = report.pad and rules.controller == 'raise' and (rules.controllerSlack or 1.25) or 1.0

    local allowedStraight = math.min(100.0, Aim.AllowedStraightness(delta, rules) * scale)
    local allowedCorridor = math.min(100.0, Aim.AllowedCorridor(delta, rules) * scale)

    local detail = {
        ('victim    : %s (id %s)'):format(tsivtools.GetName(victim), victim),
        ('weapon    : %s'):format(tsivtools.AntiCheat.ModelLabel(weapon)),
        ('distance  : %.1f m'):format(distance),
        ('snap dx   : %.1f degrees over %d ms'):format(delta, metrics.durationMs),
        ('path      : %.1f degrees travelled'):format(metrics.pathLength),
        ('straight  : %.1f%%, allowed %.1f%%'):format(metrics.straightness, allowedStraight),
        ('corridor  : %.1f%% within %.2f deg, allowed %.1f%%'):format(
            metrics.corridor, rules.corridorDegrees or 1.5, allowedCorridor),
        ('input     : %s'):format(report.pad and 'controller' or 'keyboard and mouse'),
    }

    local teleport = rules.teleport
    if teleport and teleport.enabled ~= false
        and metrics.longestStep >= (teleport.maxStepDegrees or 25.0) then
        local jumpDetail = {}
        for _, line in ipairs(detail) do jumpDetail[#jumpDetail + 1] = line end
        jumpDetail[#jumpDetail + 1] = ('jump      : %.1f degrees in one %d ms sample, limit %.1f')
            :format(metrics.longestStep, metrics.longestStepMs, teleport.maxStepDegrees or 25.0)
        flag(src, 'teleport', teleport.points or 45, 'Crosshair jumped in a single frame', jumpDetail)
    end

    if metrics.samples >= (rules.minSnapSamples or 4)
        and metrics.straightness > allowedStraight and metrics.corridor > allowedCorridor then
        local over = (metrics.straightness - allowedStraight) / math.max(1.0, 100.0 - allowedStraight)
        local points = (rules.points or 30) * (0.5 + math.min(1.0, over) * 0.5)
        flag(src, 'aimbot', points, 'Aimbot snap is too straight', detail)
    end

    local snapSpeed = rules.snapSpeed
    if snapSpeed and snapSpeed.enabled ~= false and metrics.durationMs > 0 then
        local degPerSecond = delta / (metrics.durationMs / 1000.0)

        if snapSpeed.useLongestStep ~= false and metrics.longestStepMs > 0 then
            local stepSpeed = metrics.longestStep / (metrics.longestStepMs / 1000.0)
            if stepSpeed > degPerSecond then degPerSecond = stepSpeed end
        end

        local limit = (snapSpeed.maxDegreesPerSecond or 1400.0) * scale
        if degPerSecond > limit and delta >= (snapSpeed.minSnap or 20.0) then
            local speedDetail = {}
            for _, line in ipairs(detail) do speedDetail[#speedDetail + 1] = line end
            speedDetail[#speedDetail + 1] = ('speed     : %.0f deg/s, human limit %.0f'):format(degPerSecond, limit)
            flag(src, 'snapspeed', snapSpeed.points or 25, 'Crosshair moved faster than a human can', speedDetail)
        end
    end

    local settleRules = rules.settle
    if settleRules and settleRules.enabled ~= false then
        local settleMs = samples[count].t - samples[last].t
        if settleMs < (settleRules.minMs or 60) and delta >= (settleRules.minSnap or 20.0) then
            local settleDetail = {}
            for _, line in ipairs(detail) do settleDetail[#settleDetail + 1] = line end
            settleDetail[#settleDetail + 1] = ('settle    : fired %d ms after the snap landed, minimum %d ms')
                :format(settleMs, settleRules.minMs or 60)
            flag(src, 'settle', settleRules.points or 20, 'Fired the instant the crosshair landed', settleDetail)
        end
    end

    local overshootRules = rules.overshoot
    if overshootRules and overshootRules.enabled ~= false and delta >= (overshootRules.minSnap or 25.0) then
        local worst = 0.0
        local entered = false
        for index = first, count do
            local sample = samples[index]
            local off = Aim.Between(sample.yaw, sample.pitch, targetYaw, targetPitch)
            if off <= lockCone then
                entered = true
            elseif entered and off > worst then
                worst = off
            end
        end

        if entered then
            local history = overshoot[src] or {}
            history[#history + 1] = worst
            if #history > (overshootRules.samples or 12) then table.remove(history, 1) end
            overshoot[src] = history

            if #history >= (overshootRules.samples or 12) then
                local sum = 0.0
                for _, value in ipairs(history) do sum = sum + value end
                local average = sum / #history

                if average < (overshootRules.maxAverage or 0.4) then
                    overshoot[src] = {}
                    local overshootDetail = {}
                    for _, line in ipairs(detail) do overshootDetail[#overshootDetail + 1] = line end
                    overshootDetail[#overshootDetail + 1] =
                        ('overshoot : %.2f degrees average over %d snaps, humans overshoot more')
                        :format(average, #history)
                    flag(src, 'overshoot', overshootRules.points or 15,
                        'Crosshair never overshoots the target', overshootDetail)
                end
            end
        end
    end

    local check = rules.serverCheck
    if check and check.enabled ~= false then
        local slack = check.slackMs or 150
        local fromMs = report.at + samples[first].t - slack
        local toMs = report.at + slack

        local observed, seen = serverPath(src, fromMs, toMs)
        if observed
            and observed > metrics.pathLength * (check.tolerance or 2.5)
            and observed - metrics.pathLength > (check.minDifference or 25.0) then
            flag(src, 'aimmismatch', check.points or 40,
                'Reported aim path does not match what the server saw', {
                    ('client    : %.1f degrees of movement reported'):format(metrics.pathLength),
                    ('server    : %.1f degrees observed over %d sample(s)'):format(observed, seen),
                    'note      : the aim report looks forged',
                })
        end
    end
end

CreateThread(function()
    while true do
        local check = rules.serverCheck
        local interval = math.max(20, (check and check.sampleMs) or 100)
        Wait(interval)

        if active() and check and check.enabled ~= false then
            local now = GetGameTimer()
            local cutoff = seconds()

            for src, expires in pairs(watched) do
                if expires < cutoff or not GetPlayerName(src) then
                    watched[src] = nil
                    headings[src] = nil
                else
                    local ped = GetPlayerPed(src)
                    if ped and ped ~= 0 then
                        local ring = headings[src] or {}
                        ring[#ring + 1] = { t = now, yaw = GetEntityHeading(ped) }
                        local limit = math.ceil(((rules.windowMs or 600) + 400) / interval) + 2
                        while #ring > limit do table.remove(ring, 1) end
                        headings[src] = ring
                    end
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    reports[src] = nil
    accepted[src] = nil
    watched[src] = nil
    headings[src] = nil
    overshoot[src] = nil
    missing[src] = nil
end)
