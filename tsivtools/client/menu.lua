--[[
    tsivtools - menu

    A small menu drawn with native draw calls. It is written here rather than
    pulled in from a UI library so the resource has no dependencies at all and
    so the look is controlled from config.lua.

    Usage:

        local menu = TSIV.Menu.Create('title', 'subtitle')
        menu:Button('Label', 'Description', function() ... end)
        menu:Checkbox('Label', 'Description', true, function(state) ... end)
        menu:List('Label', 'Description', { 'a', 'b' }, function(value, index) ... end)
        local sub = menu:Submenu('More', 'A submenu')
        TSIV.Menu.Open(menu)

    Controls: arrow keys move and change list values, Enter selects,
    Backspace goes back one level and closes at the top.
]]

TSIV.Menu = {}

local Menu = TSIV.Menu
local Item = {}
Item.__index = Item

local current = nil
local stack = {}
local index = 1
local offset = 0
local lastInput = 0

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

local layout = {
    width = 0.230,
    header = 0.085,
    subtitle = 0.030,
    item = 0.032,
    description = 0.030,
    textScale = 0.335,
    font = 4,
}

local function anchorX()
    if Config.MenuPosition == 'left' then
        return 0.020
    elseif Config.MenuPosition == 'center' then
        return 0.500 - layout.width / 2
    end
    return 0.975 - layout.width
end

local anchorY = 0.130

local function colour()
    local c = Config.MenuColour
    return c[1], c[2], c[3]
end

-- ---------------------------------------------------------------------------
-- Drawing
-- ---------------------------------------------------------------------------

local function drawText(text, x, y, scale, r, g, b, a, align)
    SetTextFont(layout.font)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, a)
    if align == 'right' then
        SetTextRightJustify(true)
        SetTextWrap(0.0, x)
    elseif align == 'center' then
        SetTextCentre(true)
    end
    SetTextEntry('STRING')
    AddTextComponentSubstringPlayerName(text)
    DrawText(x, y)
end

--- Rough pixel-free line count for the description box, so a long description
--- does not spill out of its background.
local function descriptionLines(text)
    local perLine = 42
    return math.max(1, math.ceil(#text / perLine))
end

local function drawRect(x, y, w, h, r, g, b, a)
    DrawRect(x + w / 2, y + h / 2, w, h, r, g, b, a)
end

-- ---------------------------------------------------------------------------
-- Items
-- ---------------------------------------------------------------------------

local function newItem(kind, label, description)
    return setmetatable({
        kind = kind,
        label = label or '',
        description = description or '',
        enabled = true,
    }, Item)
end

function Item:SetLabel(label)
    self.label = label
end

function Item:SetDescription(description)
    self.description = description
end

--- The text drawn on the right hand side of a row.
function Item:rightText()
    if self.kind == 'list' then
        local value = self.values[self.selected]
        return ('< %s >'):format(tostring(type(value) == 'table' and (value.label or value.value) or value))
    elseif self.kind == 'checkbox' then
        return self.checked and '[ ON ]' or '[ OFF ]'
    elseif self.kind == 'submenu' then
        return '>'
    end
    return self.right or ''
end

-- ---------------------------------------------------------------------------
-- Menus
-- ---------------------------------------------------------------------------

local MenuObject = {}
MenuObject.__index = MenuObject

function Menu.Create(title, subtitle)
    return setmetatable({
        title = title or 'tsivtools',
        subtitle = subtitle or '',
        items = {},
        parent = nil,
    }, MenuObject)
end

function MenuObject:Clear()
    self.items = {}
end

function MenuObject:Button(label, description, onSelect)
    local item = newItem('button', label, description)
    item.onSelect = onSelect
    self.items[#self.items + 1] = item
    return item
end

function MenuObject:Checkbox(label, description, checked, onToggle)
    local item = newItem('checkbox', label, description)
    item.checked = checked and true or false
    item.onToggle = onToggle
    self.items[#self.items + 1] = item
    return item
end

--- values may be plain strings/numbers, or { label = 'x', value = 1 } tables.
function MenuObject:List(label, description, values, onSelect, onChange)
    local item = newItem('list', label, description)
    item.values = values
    item.selected = 1
    item.onSelect = onSelect
    item.onChange = onChange
    self.items[#self.items + 1] = item
    return item
end

function MenuObject:Submenu(label, description, subtitle)
    local sub = Menu.Create(label, subtitle or self.subtitle)
    sub.parent = self

    local item = newItem('submenu', label, description)
    item.submenu = sub
    self.items[#self.items + 1] = item

    return sub, item
end

--- Attach a menu that was built separately. Used when a section is only worth
--- adding if it ended up with any rows in it.
function MenuObject:Attach(label, description, submenu)
    submenu.parent = self

    local item = newItem('submenu', label, description)
    item.submenu = submenu
    self.items[#self.items + 1] = item

    return item
end

--- A plain, unselectable row. Useful as a heading or a status line.
function MenuObject:Label(text)
    local item = newItem('label', text, '')
    item.enabled = false
    self.items[#self.items + 1] = item
    return item
end

function MenuObject:SelectedItem()
    return self.items[index]
end

-- ---------------------------------------------------------------------------
-- Opening and closing
-- ---------------------------------------------------------------------------

local function firstSelectable(from, direction)
    local count = #current.items
    if count == 0 then return 1 end
    local candidate = from
    for _ = 1, count do
        local item = current.items[candidate]
        if item and item.enabled then return candidate end
        candidate = candidate + direction
        if candidate < 1 then candidate = count end
        if candidate > count then candidate = 1 end
    end
    return from
end

local function sound(name)
    if not Config.MenuSounds then return end
    PlaySoundFrontend(-1, name, 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end

function Menu.Open(menu)
    current = menu
    stack = { menu }
    index = firstSelectable(1, 1)
    offset = 0
    sound('SELECT')
    if menu.onOpen then menu.onOpen(menu) end
end

function Menu.Close()
    if current and current.onClose then current.onClose(current) end
    current = nil
    stack = {}
    sound('BACK')
end

function Menu.IsOpen()
    return current ~= nil
end

function Menu.Current()
    return current
end

--- Rebuild-safe refresh: keeps the cursor where it was if the row still exists.
function Menu.Refresh()
    if not current then return end
    if index > #current.items then
        index = math.max(1, #current.items)
    end
end

local function push(menu)
    stack[#stack + 1] = menu
    current = menu
    index = firstSelectable(1, 1)
    offset = 0
    sound('SELECT')
    if menu.onOpen then menu.onOpen(menu) end
end

local function pop()
    if #stack <= 1 then
        Menu.Close()
        return
    end
    table.remove(stack)
    current = stack[#stack]
    index = firstSelectable(1, 1)
    offset = 0
    sound('BACK')
    if current.onOpen then current.onOpen(current) end
end

Menu.Back = pop

--- Open a menu on top of the current one, so Backspace returns here. Used for
--- the lists that are built on demand, like the online player list.
function Menu.Push(menu)
    if not current then
        Menu.Open(menu)
        return
    end
    push(menu)
end

-- ---------------------------------------------------------------------------
-- Navigation
-- ---------------------------------------------------------------------------

local function move(direction)
    local count = #current.items
    if count == 0 then return end

    index = index + direction
    if index < 1 then index = count end
    if index > count then index = 1 end
    index = firstSelectable(index, direction)

    local maxVisible = Config.MenuMaxVisible
    if index > offset + maxVisible then
        offset = index - maxVisible
    elseif index <= offset then
        offset = index - 1
    end
    if offset < 0 then offset = 0 end

    sound('NAV_UP_DOWN')
end

local function changeList(direction)
    local item = current.items[index]
    if not item or item.kind ~= 'list' then return end

    item.selected = item.selected + direction
    if item.selected < 1 then item.selected = #item.values end
    if item.selected > #item.values then item.selected = 1 end

    sound('NAV_LEFT_RIGHT')
    if item.onChange then
        local value = item.values[item.selected]
        item.onChange(type(value) == 'table' and value.value or value, item.selected, item)
    end
end

local function select()
    local item = current.items[index]
    if not item or not item.enabled then return end

    if item.kind == 'submenu' then
        push(item.submenu)
        return
    end

    sound('SELECT')

    if item.kind == 'checkbox' then
        item.checked = not item.checked
        if item.onToggle then item.onToggle(item.checked, item) end
    elseif item.kind == 'list' then
        if item.onSelect then
            local value = item.values[item.selected]
            item.onSelect(type(value) == 'table' and value.value or value, item.selected, item)
        end
    elseif item.onSelect then
        item.onSelect(item)
    end
end

-- ---------------------------------------------------------------------------
-- Render loop
-- ---------------------------------------------------------------------------

local controlsToDisable = {
    1, 2,          -- look
    24, 25,        -- attack / aim
    37,            -- weapon wheel
    44,            -- cover
    140, 141, 142, -- melee
    143,
    257, 263, 264,
    288, 289,      -- F1 / F2
    170,           -- F3
    166, 167, 168, -- F5 F6 F7
    73,            -- X
    172, 173, 174, 175, 176, 177, -- the keys the menu itself uses
}

local function drawMenu()
    local x = anchorX()
    local y = anchorY
    local width = layout.width
    local r, g, b = colour()

    -- header
    drawRect(x, y, width, layout.header, r, g, b, 235)
    drawText(current.title, x + width / 2, y + 0.022, 0.75, 255, 255, 255, 255, 'center')
    y = y + layout.header

    -- subtitle and counter
    drawRect(x, y, width, layout.subtitle, 0, 0, 0, 230)
    drawText(current.subtitle ~= '' and current.subtitle or 'tsivtools', x + 0.006, y + 0.006,
        layout.textScale, 255, 255, 255, 255)
    if #current.items > 0 then
        drawText(('%d / %d'):format(index, #current.items), x + width - 0.006, y + 0.006,
            layout.textScale, 255, 255, 255, 255, 'right')
    end
    y = y + layout.subtitle

    -- rows
    local maxVisible = Config.MenuMaxVisible
    local last = math.min(offset + maxVisible, #current.items)

    for position = offset + 1, last do
        local item = current.items[position]
        local selected = position == index
        local rowY = y

        if selected then
            drawRect(x, rowY, width, layout.item, 245, 245, 245, 235)
        else
            drawRect(x, rowY, width, layout.item, 0, 0, 0, 190)
        end

        local tr, tg, tb = 255, 255, 255
        if selected then tr, tg, tb = 15, 15, 15 end
        if not item.enabled then tr, tg, tb = 155, 155, 155 end

        drawText(item.label, x + 0.006, rowY + 0.007, layout.textScale, tr, tg, tb, 255)

        local right = item:rightText()
        if right ~= '' then
            drawText(right, x + width - 0.006, rowY + 0.007, layout.textScale, tr, tg, tb, 255, 'right')
        end

        y = y + layout.item
    end

    -- scroll indicator
    if #current.items > maxVisible then
        drawRect(x, y, width, 0.020, 0, 0, 0, 225)
        drawText(('%s  %d more  %s'):format(
            offset > 0 and '^' or ' ',
            #current.items - maxVisible,
            last < #current.items and 'v' or ' '),
            x + width / 2, y + 0.002, 0.28, 200, 200, 200, 255, 'center')
        y = y + 0.020
    end

    -- description
    local item = current.items[index]
    if item and item.description ~= '' then
        local lines = descriptionLines(item.description)
        local height = 0.008 + lines * 0.021
        drawRect(x, y + 0.004, width, height, r, g, b, 225)
        drawText(item.description, x + 0.006, y + 0.009, 0.28, 255, 255, 255, 255)
    end

    -- watermark
    if Config.MenuWatermark then
        drawText('tsivtools', x + width - 0.006, anchorY - 0.024, 0.30, r, g, b, 255, 'right')
    end
end

local function handleInput()
    for _, control in ipairs(controlsToDisable) do
        DisableControlAction(0, control, true)
    end

    local now = GetGameTimer()
    local function pressed(control, repeatable)
        if IsDisabledControlJustPressed(0, control) then
            lastInput = now
            return true
        end
        if repeatable and IsDisabledControlPressed(0, control) and now - lastInput > 160 then
            lastInput = now
            return true
        end
        return false
    end

    if pressed(172, true) then move(-1) end          -- up
    if pressed(173, true) then move(1) end           -- down
    if pressed(174, true) then changeList(-1) end    -- left
    if pressed(175, true) then changeList(1) end     -- right
    if pressed(176) then select() end                -- enter
    if pressed(177) then pop() end                   -- backspace
end

CreateThread(function()
    while true do
        if current then
            drawMenu()
            handleInput()
            Wait(0)
        else
            Wait(150)
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Text input
-- ---------------------------------------------------------------------------

--- Blocking on-screen keyboard. Returns the typed string, or nil if cancelled.
function TSIV.Input(title, default, maxLength)
    AddTextEntry('TSIVTOOLS_INPUT', title or 'Enter a value')
    DisplayOnscreenKeyboard(1, 'TSIVTOOLS_INPUT', '', default or '', '', '', '', maxLength or 64)

    while UpdateOnscreenKeyboard() == 0 do
        DisableAllControlActions(0)
        Wait(0)
    end

    if UpdateOnscreenKeyboard() ~= 1 then
        return nil
    end

    local result = GetOnscreenKeyboardResult()
    Wait(100)
    return result
end

--- Input that must be a number. Returns nil when cancelled or not a number.
function TSIV.InputNumber(title, default, maxLength)
    local value = TSIV.Input(title, default and tostring(default) or '', maxLength or 10)
    if value == nil then return nil end
    return tonumber(value)
end
