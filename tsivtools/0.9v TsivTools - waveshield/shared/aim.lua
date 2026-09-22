TSIV.Aim = {}

local Aim = TSIV.Aim

local rad = math.rad
local deg = math.deg
local sin = math.sin
local cos = math.cos
local asin = math.asin
local sqrt = math.sqrt
local atan = math.atan

function Aim.Direction(yaw, pitch)
    local ry = rad(yaw)
    local rp = rad(pitch)
    local flat = cos(rp)
    return -sin(ry) * flat, cos(ry) * flat, sin(rp)
end

function Aim.Bearing(fromX, fromY, fromZ, toX, toY, toZ)
    local dx = toX - fromX
    local dy = toY - fromY
    local dz = toZ - fromZ
    local flat = sqrt(dx * dx + dy * dy)
    if flat < 0.0001 and math.abs(dz) < 0.0001 then return nil end
    return deg(atan(-dx, dy)), deg(atan(dz, flat)), sqrt(flat * flat + dz * dz), flat
end

function Aim.Angle(ax, ay, az, bx, by, bz)
    local cx = ay * bz - az * by
    local cy = az * bx - ax * bz
    local cz = ax * by - ay * bx
    local cross = sqrt(cx * cx + cy * cy + cz * cz)
    local dot = ax * bx + ay * by + az * bz
    if cross == 0.0 and dot == 0.0 then return 0.0 end
    return deg(atan(cross, dot))
end

function Aim.Between(yawA, pitchA, yawB, pitchB)
    local ax, ay, az = Aim.Direction(yawA, pitchA)
    local bx, by, bz = Aim.Direction(yawB, pitchB)
    return Aim.Angle(ax, ay, az, bx, by, bz)
end

function Aim.Vectors(samples, from, to)
    local out = {}
    local count = 0
    for index = from, to do
        local sample = samples[index]
        count = count + 1
        local x, y, z = Aim.Direction(sample.yaw, sample.pitch)
        out[count] = { x = x, y = y, z = z, t = sample.t }
    end
    return out, count
end

local function normal(a, b)
    local nx = a.y * b.z - a.z * b.y
    local ny = a.z * b.x - a.x * b.z
    local nz = a.x * b.y - a.y * b.x
    local length = sqrt(nx * nx + ny * ny + nz * nz)
    if length < 0.000001 then return nil end
    return nx / length, ny / length, nz / length
end

function Aim.Deviation(point, nx, ny, nz)
    local dot = point.x * nx + point.y * ny + point.z * nz
    if dot < 0 then dot = -dot end
    if dot > 1.0 then dot = 1.0 end
    return deg(asin(dot))
end

function Aim.PathMetrics(vectors, count, corridorDegrees)
    if not count or count < 2 then return nil end

    local first = vectors[1]
    local last = vectors[count]

    local displacement = Aim.Angle(first.x, first.y, first.z, last.x, last.y, last.z)

    local pathLength = 0.0
    local longestStep = 0.0
    local longestStepMs = 0
    for index = 2, count do
        local a = vectors[index - 1]
        local b = vectors[index]
        local step = Aim.Angle(a.x, a.y, a.z, b.x, b.y, b.z)
        pathLength = pathLength + step
        if step > longestStep then
            longestStep = step
            if a.t and b.t then longestStepMs = b.t - a.t end
        end
    end

    local straightness = 100.0
    if pathLength > 0.0001 then
        straightness = displacement / pathLength * 100.0
        if straightness > 100.0 then straightness = 100.0 end
    end

    local corridor = 100.0
    local maxDeviation = 0.0
    local nx, ny, nz = normal(first, last)
    if nx then
        local inside = 0
        for index = 1, count do
            local deviation = Aim.Deviation(vectors[index], nx, ny, nz)
            if deviation > maxDeviation then maxDeviation = deviation end
            if deviation <= corridorDegrees then inside = inside + 1 end
        end
        corridor = inside / count * 100.0
    end

    local duration = 0
    if last.t and first.t then duration = last.t - first.t end

    return {
        displacement = displacement,
        pathLength = pathLength,
        straightness = straightness,
        corridor = corridor,
        maxDeviation = maxDeviation,
        longestStep = longestStep,
        longestStepMs = longestStepMs,
        samples = count,
        durationMs = duration,
    }
end

function Aim.AllowedStraightness(displacement, rules)
    local small = rules.smallSnap or 5.0
    local large = rules.largeSnap or 90.0
    local high = rules.maxAllowed or 100.0
    local low = rules.minAllowed or 82.0

    local span = large - small
    local ratio
    if span <= 0 then
        ratio = 1.0
    else
        ratio = (displacement - small) / span
    end

    if ratio < 0 then ratio = 0 elseif ratio > 1 then ratio = 1 end

    local curve = rules.curve or 1.0
    if curve ~= 1.0 then ratio = ratio ^ curve end

    return high - (high - low) * ratio
end

function Aim.AllowedCorridor(displacement, rules)
    local small = rules.smallSnap or 5.0
    local large = rules.largeSnap or 90.0
    local high = rules.maxCorridor or 100.0
    local low = rules.minCorridor or 88.0

    local span = large - small
    local ratio
    if span <= 0 then
        ratio = 1.0
    else
        ratio = (displacement - small) / span
    end

    if ratio < 0 then ratio = 0 elseif ratio > 1 then ratio = 1 end

    local curve = rules.curve or 1.0
    if curve ~= 1.0 then ratio = ratio ^ curve end

    return high - (high - low) * ratio
end

function Aim.FindSnap(samples, count, idleStep, maxGap)
    if count < 2 then return nil end

    local last = count
    while last > 1 do
        local a = samples[last - 1]
        local b = samples[last]
        if Aim.Between(a.yaw, a.pitch, b.yaw, b.pitch) >= idleStep then break end
        last = last - 1
    end

    if last < 2 then return nil end

    local first = last
    local gap = 0
    local index = last

    while index > 1 do
        local a = samples[index - 1]
        local b = samples[index]

        if Aim.Between(a.yaw, a.pitch, b.yaw, b.pitch) >= idleStep then
            first = index - 1
            gap = 0
        else
            gap = gap + 1
            if gap > maxGap then break end
        end

        index = index - 1
    end

    if first >= last then return nil end
    return first, last
end
