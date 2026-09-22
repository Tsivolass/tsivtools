local chunkSize = 48000

local function available()
    return GetResourceState('screenshot-basic') == 'started'
end

local function freeze(state)
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end
    FreezeEntityPosition(ped, state)
end

local function payloadOf(data)
    if type(data) ~= 'string' then return nil end
    local comma = data:find(',', 1, true)
    if data:sub(1, 5) == 'data:' and comma then
        return data:sub(comma + 1)
    end
    return data
end

local function send(id, index, data)
    local total = math.max(1, math.ceil(#data / chunkSize))
    if total > 64 then return end

    for part = 1, total do
        TriggerServerEvent(TSIV.Events.clipUpload, id, index, part, total,
            data:sub((part - 1) * chunkSize + 1, part * chunkSize))
        Wait(60)
    end
end

local function relay(request)
    for index = 1, request.frames do
        local started = GetGameTimer()
        local waiting = true

        exports['screenshot-basic']:requestScreenshot(
            { encoding = 'jpg', quality = request.quality },
            function(data)
                waiting = false
                local payload = payloadOf(data)
                if payload and #payload > 0 then
                    CreateThread(function() send(request.id, index, payload) end)
                end
            end)

        local guard = 0
        while waiting and guard < 100 do
            Wait(20)
            guard = guard + 1
        end

        local left = request.intervalMs - (GetGameTimer() - started)
        if left > 0 then Wait(left) end
    end
end

local function direct(request)
    for _ = 1, request.frames do
        exports['screenshot-basic']:requestScreenshotUpload(
            request.url, 'files[0]',
            { encoding = 'jpg', quality = request.quality },
            function() end)
        Wait(request.intervalMs)
    end
end

RegisterNetEvent(TSIV.Events.clipRequest, function(request)
    if type(request) ~= 'table' then return end
    if not available() then return end

    request.frames = math.min(tonumber(request.frames) or 3, 10)
    request.intervalMs = math.min(math.max(tonumber(request.intervalMs) or 1000, 100), 5000)
    request.quality = tonumber(request.quality) or 0.35

    CreateThread(function()
        if request.freeze then freeze(true) end

        if request.mode == 'direct' and request.url then
            direct(request)
        else
            relay(request)
        end

        if request.freeze then freeze(false) end
    end)
end)
