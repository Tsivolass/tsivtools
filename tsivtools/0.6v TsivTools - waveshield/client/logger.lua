function TSIV.Print(message)
    print(Config.consoleprefix .. tostring(message))
end

function TSIV.PrintBlock(title, lines)
    local rule = ('='):rep(72)
    print('TsivTools :))')
    print(rule)
    print(Config.consoleprefix .. tostring(title))
    print(rule)
    for _, line in ipairs(lines or {}) do
        print('  ' .. tostring(line))
    end
    print(rule)
    print('')
end

function TSIV.Notify(message, kind)
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
local topAlerts = {}

local function chatAvailable()
    return GetResourceState('chat') == 'started'
end

local function stripColours(text)
    return (tostring(text):gsub('%^%d', ''))
end

function TSIV.Chat(message)
    if chatAvailable() then
        TriggerEvent('chat:addMessage', { args = { message }, multiline = true })
        return
    end

    local plain = stripColours(message)
    feed[#feed + 1] = { text = plain, expires = GetGameTimer() + 15000 }
    while #feed > 8 do table.remove(feed, 1) end
    TSIV.Print(plain)
end

CreateThread(function()
    while true do
        if #feed == 0 and #topAlerts == 0 then
            Wait(500)
        else
            local now = GetGameTimer()
            for i = #feed, 1, -1 do
                if feed[i].expires <= now then table.remove(feed, i) end
            end
            for i = #topAlerts, 1, -1 do
                if topAlerts[i].expires <= now then table.remove(topAlerts, i) end
            end
            for index, entry in ipairs(topAlerts) do
                SetTextFont(4); SetTextScale(0.42, 0.42); SetTextColour(255, 220, 70, 245)
                SetTextCentre(true); SetTextEntry('STRING'); AddTextComponentSubstringPlayerName(entry.text)
                DrawText(0.5, 0.045 + (index - 1) * 0.027)
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

RegisterNetEvent(TSIV.Events.chat, function(message)
    TSIV.Chat(message)
end)

RegisterNetEvent(TSIV.Events.console, function(payload, kind)
    if type(payload) == 'table' then
        TSIV.PrintBlock(payload.title or 'tsivtools', payload.lines)
    else
        TSIV.Print(payload)
    end

    if kind == 'warn' then
        TSIV.Notify('Printed in console :)', 'warn')
    end
end)

RegisterNetEvent(TSIV.Events.notify, function(message, kind)
    TSIV.Notify(message, kind)
end)

local prefix = '^' .. stripColours(Config.prefix):gsub('(%W)', '%%%1')

RegisterNetEvent(TSIV.Events.alert, function(message)
    if message then
        local plain = stripColours(message)
        TSIV.Print(plain)
        TSIV.Notify(plain:gsub(prefix, ''), 'info')
        return
    end
    TSIV.Notify('anticheat alert !! check console :)', 'warn')
    PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', true)
end)

RegisterNetEvent(TSIV.Events.watchlist, function(name, id)
    topAlerts[#topAlerts + 1] = {
        text = ('WATCHLIST: %s joined (ID %d)'):format(name, id),
        expires = GetGameTimer() + 15000,
    }
    PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', true)
end)
