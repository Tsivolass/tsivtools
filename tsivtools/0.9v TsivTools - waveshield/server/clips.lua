TSIV.Clips = {}

local Clips = TSIV.Clips
local settings = Config.anticheat.clips

local captures = {}
local nextId = 1

local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local b64lookup = {}

for index = 1, #b64chars do
    b64lookup[b64chars:sub(index, index)] = index - 1
end

local function b64decode(input)
    if type(input) ~= 'string' then return '' end

    local comma = input:find(',', 1, true)
    if input:sub(1, 5) == 'data:' and comma then
        input = input:sub(comma + 1)
    end

    local out, chunk = {}, {}
    local bits, count = 0, 0

    for index = 1, #input do
        local value = b64lookup[input:sub(index, index)]
        if value then
            bits = (bits << 6) | value
            count = count + 6
            if count >= 8 then
                count = count - 8
                chunk[#chunk + 1] = string.char((bits >> count) & 0xFF)
                bits = bits & ((1 << count) - 1)
                if #chunk >= 4096 then
                    out[#out + 1] = table.concat(chunk)
                    chunk = {}
                end
            end
        end
    end

    out[#out + 1] = table.concat(chunk)
    return table.concat(out)
end

Clips.Decode = b64decode

local function webhookUrl()
    if settings.webhook and settings.webhook ~= '' then return settings.webhook end

    local convar = settings.webhookConvar
    if convar and convar ~= '' then
        local value = GetConvar(convar, '')
        if value and value ~= '' then return value end
    end
    return nil
end

Clips.Webhook = webhookUrl

function Clips.Available()
    if not Config.anticheat.enabled then return false end
    if not TSIV.Module('banClips') then return false end
    if settings.enabled == false then return false end
    if GetResourceState('screenshot-basic') ~= 'started' then return false end
    return webhookUrl() ~= nil
end

local function multipart(url, payload, files)
    local boundary = ('tsivtools%d%06x'):format(os.time(), math.random(0, 0xFFFFFF))
    local parts = {}

    parts[#parts + 1] = ('--%s\r\nContent-Disposition: form-data; name="payload_json"\r\nContent-Type: application/json\r\n\r\n%s\r\n')
        :format(boundary, json.encode(payload))

    for index, file in ipairs(files) do
        parts[#parts + 1] = ('--%s\r\nContent-Disposition: form-data; name="files[%d]"; filename="%s"\r\nContent-Type: image/jpeg\r\n\r\n')
            :format(boundary, index - 1, file.name)
        parts[#parts + 1] = file.data
        parts[#parts + 1] = '\r\n'
    end

    parts[#parts + 1] = ('--%s--\r\n'):format(boundary)

    PerformHttpRequest(url, function(status)
        if status ~= 200 and status ~= 204 then
            print(('%sclip upload returned %s'):format(Config.consoleprefix, tostring(status)))
        end
    end, 'POST', table.concat(parts), {
        ['Content-Type'] = ('multipart/form-data; boundary=%s'):format(boundary),
    })
end

local function postJson(url, payload)
    PerformHttpRequest(url, function(status)
        if status ~= 200 and status ~= 204 then
            print(('%sclip webhook returned %s'):format(Config.consoleprefix, tostring(status)))
        end
    end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

local function embedFor(context, framesFound)
    return {
        username = settings.username ~= '' and settings.username or nil,
        embeds = { {
            title = 'Ban clip',
            description = context.reason,
            color = 10038562,
            fields = {
                { name = 'Player', value = ('%s\n`id %s`'):format(context.name, context.id), inline = true },
                { name = 'Steam', value = ('`%s`'):format(context.steam), inline = true },
                { name = 'Identifier', value = ('`%s`'):format(context.identifier), inline = false },
                { name = 'Frames', value = ('%d over %.1f second(s)'):format(framesFound, settings.seconds), inline = true },
            },
            footer = { text = ('TsivTools  /  %s'):format(TSIV.FormatTimestamp(os.time())) },
        } },
    }
end

local function release(entry)
    if entry.released then return end
    entry.released = true
    if entry.done then entry.done() end
end

local function finish(id)
    local entry = captures[id]
    if not entry then return end
    captures[id] = nil

    release(entry)

    local files = {}
    for index = 1, entry.expected do
        local frame = entry.frames[index]
        if frame and frame.complete then
            local data = b64decode(table.concat(frame.parts))
            if #data > 0 then
                files[#files + 1] = { name = ('clip_%d_%02d.jpg'):format(id, index), data = data }
            end
        end
    end

    if #files == 0 then
        print(('%sno clip frames arrived for %s'):format(Config.consoleprefix, entry.context.name))
        return
    end

    multipart(entry.url, embedFor(entry.context, #files), files)
end

function Clips.Before(src, reason, done)
    done = done or function() end

    if not Clips.Available() then
        done()
        return
    end

    local url = webhookUrl()
    local id = nextId
    nextId = nextId + 1

    local frames = math.max(1, TSIV.ToInt(settings.frames, 1, 10) or 3)
    local span = math.max(1.0, tonumber(settings.seconds) or 5.0)

    local context = {
        id = src,
        name = TSIV.GetName(src),
        steam = TSIV.GetSteamId(src),
        identifier = TSIV.GetPrimaryIdentifier(src),
        reason = TSIV.SafeString(reason, 200),
    }

    captures[id] = {
        src = src,
        url = url,
        expected = frames,
        frames = {},
        context = context,
        done = done,
    }

    TriggerClientEvent(TSIV.Events.clipRequest, src, {
        id = id,
        mode = settings.mode,
        frames = frames,
        intervalMs = math.floor(span * 1000 / frames),
        quality = tonumber(settings.quality) or 0.35,
        freeze = settings.freezeTarget ~= false,
        url = settings.mode == 'direct' and url or nil,
    })

    if settings.mode == 'direct' then
        postJson(url, embedFor(context, frames))
        SetTimeout(math.max(1000, settings.holdMs or 7000), function()
            local entry = captures[id]
            if entry then
                captures[id] = nil
                release(entry)
            end
        end)
        return
    end

    SetTimeout(math.max(1000, settings.holdMs or 7000), function()
        finish(id)
    end)
end

RegisterNetEvent(TSIV.Events.clipUpload, function(id, index, part, total, data)
    local src = source

    local entry = captures[id]
    if not entry or entry.src ~= src then return end

    index = TSIV.ToInt(index, 1, entry.expected)
    part = TSIV.ToInt(part, 1, 64)
    total = TSIV.ToInt(total, 1, 64)
    if not index or not part or not total or part > total then return end
    if type(data) ~= 'string' then return end

    local frame = entry.frames[index]
    if not frame then
        frame = { parts = {}, seen = 0, total = total, size = 0 }
        entry.frames[index] = frame
    end

    if frame.complete or frame.parts[part] then return end

    frame.size = frame.size + #data
    if frame.size > (settings.maxFrameBytes or 700000) then
        frame.complete = false
        return
    end

    frame.parts[part] = data
    frame.seen = frame.seen + 1

    if frame.seen >= frame.total then
        frame.complete = true
    end

    local ready = 0
    for slot = 1, entry.expected do
        local stored = entry.frames[slot]
        if stored and stored.complete then ready = ready + 1 end
    end

    if ready >= entry.expected then
        finish(id)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for id, entry in pairs(captures) do
        if entry.src == src then
            captures[id] = nil
            release(entry)
        end
    end
end)
