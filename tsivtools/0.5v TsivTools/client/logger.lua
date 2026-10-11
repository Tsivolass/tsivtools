function tsivtools.Print(message)
    print(Config.ConsolePrefix .. tostring(message))
end

function tsivtools.PrintBlock(title, lines)
    local rule = ('='):rep(72)
    print('TsivTools :))')
    print(rule)
    print(Config.ConsolePrefix .. tostring(title))
    print(rule)
    for _, line in ipairs(lines or {}) do
        print('  ' .. tostring(line))
    end
    print(rule)
    print('')
end

function tsivtools.Notify(message, kind)
    kind = kind or 'info'

    local prefix = '~s~'
    if kind == 'success' then prefix = '~g~'
    elseif kind == 'error' then prefix = '~r~'
    elseif kind == 'warn' then prefix = '~y~' end

    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(('~b~tsivtools~s~: %s%s'):format(prefix, message))
    EndTextCommandThefeedPostTicker(false, true)
end

local feed = {}

local function chatAvailable()
    return GetResourceState('chat') == 'started'
end

local function stripColours(text)
    return (tostring(text):gsub('%^%d', ''))
end

function tsivtools.Chat(message)
    if chatAvailable() then
        TriggerEvent('chat:addMessage', { args = { message }, multiline = true })
        return
    end

    local plain = stripColours(message)
    feed[#feed + 1] = { text = plain, expires = GetGameTimer() + 15000 }
    while #feed > 8 do table.remove(feed, 1) end
    tsivtools.Print(plain)
end

CreateThread(function()
    while true do
        if #feed == 0 then
            Wait(500)
        else
            local now = GetGameTimer()
            for i = #feed, 1, -1 do
                if feed[i].expires <= now then table.remove(feed, i) end
            end

            local y = 0.62
            for _, entry in ipairs(feed) do
                SetTextFont(4)
                SetTextScale(0.34, 0.34)
                SetTextColour(255, 255, 255, 220)
                SetTextDropShadow()
                SetTextOutline()
                SetTextEntry('STRING')
                AddTextComponentSubstringPlayerName(entry.text)
                DrawText(0.015, y)
                y = y + 0.022
            end
            Wait(0)
        end
    end
end)

RegisterNetEvent(tsivtools.Events.chat, function(message)
    tsivtools.Chat(message)
end)

RegisterNetEvent(tsivtools.Events.console, function(payload, kind)
    if type(payload) == 'table' then
        tsivtools.PrintBlock(payload.title or 'tsivtools', payload.lines)
    else
        tsivtools.Print(payload)
    end

    if kind == 'warn' then
        tsivtools.Notify('Printed in console :)', 'warn')
    end
end)

RegisterNetEvent(tsivtools.Events.notify, function(message, kind)
    tsivtools.Notify(message, kind)
end)

local prefix = '^' .. stripColours(Config.Prefix):gsub('(%W)', '%%%1')

RegisterNetEvent(tsivtools.Events.alert, function(message)
    if message then
        local plain = stripColours(message)
        tsivtools.Print(plain)
        tsivtools.Notify(plain:gsub(prefix, ''), 'info')
        return
    end
    tsivtools.Notify('anticheat alert !! check console :)', 'warn')
    PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', true)
end)
