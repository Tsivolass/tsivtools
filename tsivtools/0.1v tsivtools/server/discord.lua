tsivtools.Discord = {}

local queue = {}
local dropped = 0

local function post(url, payload)
    PerformHttpRequest(url, function(status)
        if status ~= 200 and status ~= 204 then
            print(('%sdiscord webhook returned %s'):format(Config.ConsolePrefix, tostring(status)))
        end
    end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

local function embedSize(embed)
    local size = #embed.title + #embed.description + #embed.footer.text
    for _, field in ipairs(embed.fields) do
        size = size + #field.name + #field.value
    end
    return size
end

CreateThread(function()
    while true do
        Wait(1200)
        local item = table.remove(queue, 1)
        if item then
            local embeds = item.payload.embeds
            local size = embedSize(embeds[1])
            local index = 1
            while index <= #queue and #embeds < 10 do
                local waiting = queue[index]
                if waiting.url == item.url then
                    local extra = embedSize(waiting.payload.embeds[1])
                    if size + extra > 5500 then break end
                    embeds[#embeds + 1] = waiting.payload.embeds[1]
                    size = size + extra
                    table.remove(queue, index)
                else
                    index = index + 1
                end
            end
            post(item.url, item.payload)
        end
        if dropped > 0 and #queue == 0 then
            print(('%sdiscord was too slow, %d log message(s) were skipped'):format(Config.ConsolePrefix, dropped))
            dropped = 0
        end
    end
end)

function tsivtools.Discord.Send(category, record)
    local settings = Config.Logging.discord
    if not settings.enabled then return end

    local url = GetConvar('tsivtoolswebhook' .. category, '')
    if url == '' then url = settings.webhooks[category] or '' end
    if url == '' then return end

    local fields = {}
    if record.actor ~= '' then
        fields[#fields + 1] = {
            name = 'By',
            value = ('%s\n`%s`'):format(record.actorName ~= '' and record.actorName or 'unknown', record.actor),
            inline = true,
        }
    end
    if record.target ~= '' then
        fields[#fields + 1] = {
            name = 'Target',
            value = ('%s\n`%s`'):format(record.targetName ~= '' and record.targetName or 'unknown', record.target),
            inline = true,
        }
    end
    if record.data then
        local ok, encoded = pcall(json.encode, record.data)
        if ok and #encoded < 900 then
            fields[#fields + 1] = { name = 'Details', value = ('```json\n%s\n```'):format(encoded), inline = false }
        end
    end

    if #queue >= 200 then
        table.remove(queue, 1)
        dropped = dropped + 1
    end

    queue[#queue + 1] = {
        url = url,
        payload = {
            username = settings.username,
            avatar_url = settings.avatar ~= '' and settings.avatar or nil,
            embeds = { {
                title = category,
                description = record.message,
                color = settings.colours[category] or 8421504,
                fields = fields,
                footer = { text = ('tsivtools  |  %s'):format(tsivtools.FormatTimestamp(record.at)) },
            } },
        },
    }
end

CreateThread(function()
    for category, url in pairs(Config.Logging.discord.webhooks) do
        if url ~= '' then
            print(('%sthe %s discord webhook is written in config.lua, which every player downloads. Move it to server.cfg: set tsivtoolswebhook%s "<url>"')
                :format(Config.ConsolePrefix, category, category))
        end
    end
end)
