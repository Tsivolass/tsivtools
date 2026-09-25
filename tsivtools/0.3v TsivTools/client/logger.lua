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

function tsivtools.Chat(message)
    TriggerEvent('chat:addMessage', { args = { message }, multiline = true })
end

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

RegisterNetEvent(tsivtools.Events.alert, function(message)
    tsivtools.Chat(message)
    if not message:find('[anticheat]', 1, true) and not message:find('[client check]', 1, true) then return end
    tsivtools.Notify('anticheat alert !! check console and chat :))', 'warn')
    PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', true)
end)
