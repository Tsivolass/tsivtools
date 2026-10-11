tsivtools.Menu = {}

local Menu = tsivtools.Menu
local Item = {}
Item.__index = Item

local current = nil
local stack = {}
local index = 1
local offset = 0
local lastInput = 0
local inputLocked = false

local layout = {
    width = 0.250,
    header = 0.068,
    subtitle = 0.024,
    item = 0.035,
    scroll = 0.017,
    textScale = 0.335,
    font = 4,
}

local function anchorX()
    local pos = Config and Config.MenuPosition or 'right'
    if pos == 'left' then
        return 0.020
    elseif pos == 'center' then
        return 0.500 - layout.width / 2
    end
    return 0.975 - layout.width
end

local anchorY = 0.130

local function colour()
    local c = Config and Config.MenuColour or { 255, 100, 100 }
    return c[1], c[2], c[3]
end

local function drawText(text, x, y, scale, r, g, b, a, align, wrap)
    SetTextFont(layout.font)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, a)
    SetTextCentre(align == 'center')
    SetTextRightJustify(align == 'right')

    if align == 'right' then
        SetTextWrap(0.0, x)
    elseif wrap then
        SetTextWrap(x, x + wrap)
    else
        SetTextWrap(0.0, 1.0)
    end

    SetTextEntry('STRING')
    AddTextComponentSubstringPlayerName(text)
    DrawText(x, y)
end

local function descriptionLines(text)
    local perLine = 42
    return math.max(1, math.ceil(#text / perLine))
end

local function drawRect(x, y, w, h, r, g, b, a)
    DrawRect(x + w / 2, y + h / 2, w, h, r, g, b, a)
end

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

function Item:rightText()
    if self.kind == 'list' then
        if not self.values or #self.values == 0 then return '< - >' end
        local value = self.values[self.selected]
        return ('< %s >'):format(tostring(type(value) == 'table' and (value.label or value.value) or value))
    elseif self.kind == 'checkbox' then
        return self.checked and '[ ON ]' or '[ OFF ]'
    elseif self.kind == 'submenu' then
        return '>'
    end
    return self.right or ''
end

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

function MenuObject:List(label, description, values, onSelect, onChange)
    local item = newItem('list', label, description)
    item.values = values or {}
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

function MenuObject:Attach(label, description, submenu)
    submenu.parent = self

    local item = newItem('submenu', label, description)
    item.submenu = submenu
    self.items[#self.items + 1] = item

    return item
end

function MenuObject:Label(text)
    local item = newItem('label', text, '')
    item.enabled = false
    self.items[#self.items + 1] = item
    return item
end

function MenuObject:SelectedItem()
    return self.items[index]
end

local function firstSelectable(from, direction)
    local count = current and #current.items or 0
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
    if Config and Config.MenuSounds == false then return end
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

function Menu.Refresh()
    if not current then return end
    if index > #current.items then
        index = math.max(1, #current.items)
    end
    local maxVisible = Config.MenuMaxVisible
    if offset > math.max(0, #current.items - maxVisible) then
        offset = math.max(0, #current.items - maxVisible)
    end
    if index <= offset then offset = index - 1 end
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

function Menu.Push(menu)
    if not current then
        Menu.Open(menu)
        return
    end
    push(menu)
end

local function move(direction)
    local count = current and #current.items or 0
    if count == 0 then return end

    index = index + direction
    if index < 1 then index = count end
    if index > count then index = 1 end
    index = firstSelectable(index, direction)

    local maxVisible = Config and Config.MenuMaxVisible or 10
    if index > offset + maxVisible then
        offset = index - maxVisible
    elseif index <= offset then
        offset = index - 1
    end
    if offset < 0 then offset = 0 end

    sound('NAV_UP_DOWN')
end

local function changeList(direction)
    local item = current and current.items[index]
    if not item or item.kind ~= 'list' or not item.values then return end

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
    local item = current and current.items[index]
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
        if item.onSelect and item.values then
            local value = item.values[item.selected]
            item.onSelect(type(value) == 'table' and value.value or value, item.selected, item)
        end
    elseif item.onSelect then
        item.onSelect(item)
    end
end

local controlsToDisable = {
    1, 2, 24, 25, 37, 44, 140, 141, 142, 143, 257, 263, 264, 288, 289, 170, 166, 167, 168, 73, 172, 173, 174, 175, 176, 177,
}

local function drawMenu()
    if not current then return end
    local x = anchorX()
    local y = anchorY
    local width = layout.width
    local r, g, b = colour()
    local maxVisible = Config and Config.MenuMaxVisible or 10
    local last = math.min(offset + maxVisible, #current.items)
    local hasScroll = #current.items > maxVisible
    local selectedItem = current.items[index]
    local descriptionHeight = 0
    local footerHeight = 0.022

    if selectedItem and selectedItem.description ~= '' then
        descriptionHeight = 0.008 + descriptionLines(selectedItem.description) * 0.021
    end

    local contentHeight = layout.header + layout.subtitle + (last - offset) * layout.item
    if hasScroll then contentHeight = contentHeight + layout.scroll end
    if descriptionHeight > 0 then contentHeight = contentHeight + 0.006 + descriptionHeight end
    contentHeight = contentHeight + 0.006 + footerHeight

    drawRect(x - 0.003, y - 0.003, width + 0.006, contentHeight + 0.006, 0, 0, 0, 125)
    drawRect(x, y, width, layout.header, 12, 16, 24, 250)
    drawRect(x, y, width, 0.003, r, g, b, 255)
    drawRect(x + width * 0.58, y, width * 0.42, 0.003, 121, 83, 236, 210)

    drawText(current.title, x + 0.013, y + 0.026, 0.420, 243, 246, 252, 255)
    y = y + layout.header

    drawRect(x, y, width, layout.subtitle, 16, 20, 30, 250)
    drawText(current.subtitle ~= '' and current.subtitle or 'tsivtools', x + 0.013, y + 0.006, 0.220, 145, 157, 184, 255)
    if #current.items > 0 then
        drawRect(x + width - 0.050, y + 0.002, 0.037, 0.020, 24, 30, 43, 255)
        drawText(('%d / %d'):format(index, #current.items), x + width - 0.017, y + 0.006, 0.220, 194, 208, 239, 255, 'right')
    end
    y = y + layout.subtitle

    for position = offset + 1, last do
        local item = current.items[position]
        local selected = position == index
        local rowY = y
        local labelR, labelG, labelB = 220, 225, 236
        local valueR, valueG, valueB = 143, 158, 188

        drawRect(x, rowY, width, layout.item, 11, 14, 21, 250)
        if selected then
            drawRect(x, rowY, width, layout.item, 29, 40, 65, 252)
            drawRect(x, rowY, 0.003, layout.item, r, g, b, 255)
            drawRect(x + width - 0.002, rowY, 0.002, layout.item, 121, 83, 236, 230)
            labelR, labelG, labelB = 248, 250, 255
            valueR, valueG, valueB = 194, 210, 250
        elseif not item.enabled then
            labelR, labelG, labelB = 92, 102, 121
            valueR, valueG, valueB = 92, 102, 121
        end

        drawText(item.label, x + 0.013, rowY + 0.008, layout.textScale, labelR, labelG, labelB, 255)
        local right = item:rightText()
        if right ~= '' then
            drawText(right, x + width - 0.013, rowY + 0.008, layout.textScale, valueR, valueG, valueB, 255, 'right')
        end

        y = y + layout.item
    end

    if hasScroll then
        drawRect(x, y, width, layout.scroll, 14, 18, 27, 250)
        local progress = math.max(0.18, maxVisible / #current.items)
        local trackWidth = width - 0.072
        local travel = trackWidth * (1 - progress)
        local denominator = math.max(1, #current.items - maxVisible)
        local thumbX = x + 0.013 + travel * (offset / denominator)
        drawRect(x + 0.013, y + 0.008, trackWidth, 0.002, 60, 70, 91, 230)
        drawRect(thumbX, y + 0.007, trackWidth * progress, 0.004, r, g, b, 245)
        drawText(('%s  %d more  %s'):format(
            offset > 0 and '^' or ' ',
            #current.items - maxVisible,
            last < #current.items and 'v' or ' '),
            x + width / 2, y + 0.004, 0.205, 125, 137, 160, 255, 'center')
        y = y + layout.scroll
    end

    if descriptionHeight > 0 then
        y = y + 0.006
        drawRect(x, y, width, descriptionHeight, 15, 19, 29, 252)
        drawRect(x, y, 0.003, descriptionHeight, 121, 83, 236, 235)
        drawText(selectedItem.description, x + 0.013, y + 0.009, 0.275, 207, 215, 229, 255)
        y = y + descriptionHeight
    end

    y = y + 0.006
    drawRect(x, y, width, footerHeight, 12, 16, 24, 252)
    drawText('Developed by: Tsivolakos', x + width - 0.013, y + 0.005, 0.205, 125, 137, 160, 255, 'right')
end

local function handleInput()
    if inputLocked then return end

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

    if pressed(172, true) then move(-1) end
    if pressed(173, true) then move(1) end
    if pressed(174, true) then changeList(-1) end
    if pressed(175, true) then changeList(1) end
    if pressed(176) then select() end
    if pressed(177) then pop() end
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

function Menu.LockInput(state)
    inputLocked = state and true or false
end

function Menu.InputLocked()
    return inputLocked
end

local pending = nil

local function finish(value)
    if not pending then return end
    pending.value = value
    pending.done = true
end

RegisterNUICallback('inputSubmit', function(data, cb)
    SetNuiFocus(false, false)
    finish(type(data) == 'table' and data.value or nil)
    cb('ok')
end)

RegisterNUICallback('inputCancel', function(_, cb)
    SetNuiFocus(false, false)
    finish(nil)
    cb('ok')
end)

local function nuiInput(title, default, maxLength, numeric)
    local request = { done = false, value = nil }
    pending = request

    Menu.LockInput(true)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openInput',
        title = title or 'Enter a value',
        default = default or '',
        maxLength = maxLength or 64,
        numeric = numeric and true or false,
    })

    local deadline = GetGameTimer() + 120000
    while not request.done and GetGameTimer() < deadline do
        Wait(50)
    end

    local result = request.value
    local timedOut = not request.done
    if pending == request then pending = nil end

    if timedOut then
        SendNUIMessage({ action = 'closeInput' })
    end

    SetNuiFocus(false, false)
    Menu.LockInput(false)

    if timedOut then
        tsivtools.Notify('The text box timed out !', 'error')
        return nil
    end

    return result
end

local function nativeInput(title, default, maxLength)
    Menu.LockInput(true)

    AddTextEntry('TSIVTOOLS_INPUT', title or 'Enter a value')
    DisplayOnscreenKeyboard(1, 'TSIVTOOLS_INPUT', '', default or '', '', '', '', (maxLength or 64) + 1)

    local status = UpdateOnscreenKeyboard()
    local deadline = GetGameTimer() + 120000
    while status ~= 1 and status ~= 2 and GetGameTimer() < deadline do
        DisableAllControlActions(0)
        Wait(0)
        status = UpdateOnscreenKeyboard()
    end

    Menu.LockInput(false)

    if status ~= 1 then
        if status == 0 then CancelOnscreenKeyboard() end
        return nil
    end

    local result = GetOnscreenKeyboardResult()
    Wait(50)
    return result
end

function tsivtools.Input(title, default, maxLength)
    if Config.UseNuiInput then
        return nuiInput(title, default, maxLength, false)
    end
    return nativeInput(title, default, maxLength)
end

function tsivtools.InputNumber(title, default, maxLength)
    local value
    if Config.UseNuiInput then
        value = nuiInput(title, default and tostring(default) or '', maxLength or 10, true)
    else
        value = nativeInput(title, default and tostring(default) or '', maxLength or 10)
    end

    if value == nil then return nil end
    return tonumber((value:gsub('%s', '')))
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= tsivtools.resource then return end
    SetNuiFocus(false, false)
end)
