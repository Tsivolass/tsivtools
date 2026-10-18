function tsivtools.Print(message)
    print(Config.consoleprefix .. tostring(message))
end

function tsivtools.PrintBlock(title, lines)
    local rule = string.rep('-', 48)
    print(Config.consoleprefix .. tostring(title))
    print(rule)
    for _, line in ipairs(lines or {}) do
        print('  ' .. tostring(line))
    end
    print(rule)
    print('')
end

function tsivtools.Notify(message, kind)
    kind = kind or 'info'
    local dtype = 'Info'
    if kind == 'success' then dtype = 'Success'
    elseif kind == 'error' then dtype = 'Error'
    elseif kind == 'warn' then dtype = 'Warning'
    end
    TriggerEvent('did_notifications:notify', dtype, tostring(message), 5000, dtype)
end

local feed = {}
local topAlerts = {}

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

RegisterNetEvent(tsivtools.Events.chat, function(message)
    tsivtools.Chat(message)
end)

RegisterNetEvent(tsivtools.Events.console, function(payload, kind)
    if type(payload) == 'table' then
        tsivtools.PrintBlock(payload.title or '', payload.lines)
    else
        tsivtools.Print(payload)
    end

    if kind == 'warn' then
        tsivtools.Notify('Printed in console', 'warn')
    end
end)

RegisterNetEvent(tsivtools.Events.notify, function(message, kind)
    tsivtools.Notify(message, kind)
end)

RegisterNetEvent(tsivtools.Events.alert, function(message)
    if message then tsivtools.Print(stripColours(message)) end
    tsivtools.Notify('Anticheat alert - check console', 'warn')
    PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', true)
end)

RegisterNetEvent(tsivtools.Events.watchlist, function(name, id)
    topAlerts[#topAlerts + 1] = {
        text = ('WATCHLIST: %s joined (ID %d)'):format(name, id),
        expires = GetGameTimer() + 15000,
    }
    PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', true)
end)
