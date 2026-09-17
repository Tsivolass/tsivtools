--[[
    tsivtools - client output

    Three ways the resource talks to a player:

      TSIV.Print   - a line in the F8 console. Where all the lookups land.
      TSIV.Notify  - the standard GTA notification above the minimap.
      chat         - used for staff chat and alerts, so they persist.
]]

--- Print into the F8 console. FiveM's console strips ^ colour codes, so the
--- output is kept plain and aligned instead.
function TSIV.Print(message)
    print(Config.ConsolePrefix .. tostring(message))
end

--- A block of related lines with a heading and a rule, so a garage or log
--- lookup reads as one thing in a busy console.
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

-- ---------------------------------------------------------------------------
-- Server driven output
-- ---------------------------------------------------------------------------

RegisterNetEvent(TSIV.Events.console, function(payload, kind)
    if type(payload) == 'table' then
        TSIV.PrintBlock(payload.title or 'tsivtools', payload.lines)
    else
        TSIV.Print(payload)
    end

    -- A warning also nudges the player on screen, otherwise a detection that
    -- lands while F8 is closed goes unnoticed.
    if kind == 'warn' then
        TSIV.Notify('Check your F8 console.', 'warn')
    end
end)

RegisterNetEvent(TSIV.Events.notify, function(message, kind)
    TSIV.Notify(message, kind)
end)

RegisterNetEvent(TSIV.Events.alert, function(message)
    TSIV.Chat(message)
    TSIV.Notify('Anti-cheat alert, see chat and F8.', 'warn')
    PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', true)
end)
