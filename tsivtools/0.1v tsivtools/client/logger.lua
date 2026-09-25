function TSIV.Print(message)
    print(Config.ConsolePrefix .. tostring(message))
end

function TSIV.PrintBlock(title, lines)
    local rule = ('='):rep(72)
    print('')
    print(rule)
    print(Config.ConsolePrefix .. tostring(title))
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

function TSIV.Chat(message)
    TriggerEvent('chat:addMessage', { args = { message }, multiline = true })
end

RegisterNetEvent(TSIV.Events.console, function(payload, kind)
    if type(payload) == 'table' then
        TSIV.PrintBlock(payload.title or 'tsivtools', payload.lines)
    else
        TSIV.Print(payload)
    end

    if kind == 'warn' then
        TSIV.Notify('Check your F8 console.', 'warn')
    end
end)

RegisterNetEvent(TSIV.Events.notify, function(message, kind)
    TSIV.Notify(message, kind)
end)

RegisterNetEvent(TSIV.Events.alert, function(message)
    TSIV.Chat(message)
    if not message:find('[anticheat]', 1, true) and not message:find('[client check]', 1, true) then return end
    TSIV.Notify('Anti-cheat alert, see chat and F8.', 'warn')
    PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', true)
end)
