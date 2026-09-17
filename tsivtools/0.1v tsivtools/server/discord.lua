--[[
    tsivtools - Discord webhooks

    Optional mirror of the log store into Discord. Turn it on in
    Config.Logging.discord and paste a webhook URL per category. A category
    with an empty URL is simply skipped.
]]

TSIV.Discord = {}

local queue = {}
local sending = false

local function post(url, payload)
    PerformHttpRequest(url, function(status)
        if status ~= 200 and status ~= 204 then
            print(('%sdiscord webhook returned %s'):format(Config.ConsolePrefix, tostring(status)))
        end
    end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

-- Discord rate limits webhooks fairly aggressively. Entries are queued and
-- drained slowly so a burst of detections does not get dropped on the floor.
CreateThread(function()
    while true do
        Wait(1200)
        if #queue > 0 and not sending then
            sending = true
            local item = table.remove(queue, 1)
            post(item.url, item.payload)
            sending = false
        end
    end
end)

--- Called by TSIV.Logs.Write for every record.
function TSIV.Discord.Send(category, record)
    local settings = Config.Logging.discord
    if not settings.enabled then return end

    local url = settings.webhooks[category]
    if not url or url == '' then return end

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
                footer = { text = ('tsivtools  |  %s'):format(TSIV.FormatTimestamp(record.at)) },
            } },
        },
    }
end
