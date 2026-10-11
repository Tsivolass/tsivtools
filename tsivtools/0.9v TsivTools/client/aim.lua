local rules = Config.anticheat.aimbot

local buffer = {}
local head = 0
local filled = 0
local capacity = 1

local lastReport = 0
local lastShot = false

local function active()
    if not Config.anticheat.enabled then return false end
    if not tsivtools.Module('aimbot') then return false end
    return rules.enabled
end

local function push(t, yaw, pitch)
    head = head % capacity + 1
    local slot = buffer[head]
    if slot then
        slot.t, slot.yaw, slot.pitch = t, yaw, pitch
    else
        buffer[head] = { t = t, yaw = yaw, pitch = pitch }
    end
    if filled < capacity then filled = filled + 1 end
end

local function ordered(windowMs, now)
    local out = {}
    local count = 0

    for offset = filled - 1, 0, -1 do
        local index = (head - offset - 1) % capacity + 1
        local slot = buffer[index]
        if slot and now - slot.t <= windowMs then
            count = count + 1
            out[count] = slot
        end
    end

    return out, count
end

local function usingPad()
    return not GetLastInputMethod(2)
end

local function report()
    local now = GetGameTimer()
    if now - lastReport < rules.reportCooldownMs then return end
    lastReport = now

    local samples, count = ordered(rules.windowMs, now)
    if count < rules.minSamples then return end

    local allowed = math.floor(rules.maxPacked / 3)
    local from = 1
    if count > allowed then from = count - allowed + 1 end

    local packed = {}
    for index = from, count do
        local sample = samples[index]
        packed[#packed + 1] = now - sample.t
        packed[#packed + 1] = math.floor(sample.yaw * 10.0 + 0.5)
        packed[#packed + 1] = math.floor(sample.pitch * 10.0 + 0.5)
    end

    TriggerServerEvent(tsivtools.Events.aim, packed, usingPad())
end

CreateThread(function()
    if not active() then return end

    local interval = math.max(5, tonumber(rules.sampleMs) or 20)
    capacity = math.max(8, math.ceil((tonumber(rules.windowMs) or 600) / interval) + 4)

    Wait(5000)

    while true do
        Wait(interval)

        local ped = PlayerPedId()
        if DoesEntityExist(ped) then
            local rot = GetGameplayCamRot(2)
            push(GetGameTimer(), rot.z, rot.x)

            local shooting = IsPedShooting(ped)
            if shooting and not lastShot then report() end
            lastShot = shooting
        else
            lastShot = false
        end
    end
end)
