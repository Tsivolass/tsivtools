-- TSIV MENU STYLE 05: LUXURY
-- Luxury: restrained gold/cream palette with elegant proportions.
TSIV.Menu = {}

local Menu = TSIV.Menu
local Item = {}
Item.__index = Item

local current = nil
local stack = {}
local index = 1
local offset = 0
local lastInput = 0
local inputLocked = false

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
    if Config.menuposition == 'left' then
        return 0.020
    elseif Config.menuposition == 'center' then
        return 0.500 - layout.width / 2
    end
    return 0.975 - layout.width
end

local anchorY = 0.130

local function colour()
    local c = Config.menucolour
    return c[1], c[2], c[3]
end

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
    if not Config.menusounds then return end
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
    local maxVisible = Config.menumaxvisible
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
    local count = #current.items
    if count == 0 then return end

    index = index + direction
    if index < 1 then index = count end
    if index > count then index = 1 end
    index = firstSelectable(index, direction)

    local maxVisible = Config.menumaxvisible
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

local controlsToDisable = {
    1, 2,
    24, 25,
    37,
    44,
    140, 141, 142,
    143,
    257, 263, 264,
    288, 289,
    170,
    166, 167, 168,
    73,
    172, 173, 174, 175, 176, 177,
}

local function drawMenu()
    local x,y,w=anchorX(),anchorY,layout.width; local ar,ag,ab=210,175,70
    drawRect(x,y,w,0.080,13,13,15,242); drawRect(x,y,w,0.004,ar,ag,ab,255); drawText(current.title,x+w/2,y+0.022,0.66,246,240,220,255,'center'); y=y+0.080
    drawRect(x,y,w,0.026,30,27,23,238); drawText(current.subtitle~='' and current.subtitle or 'PRIVATE CONTROL',x+0.007,y+0.003,0.27,205,195,175,255); if #current.items>0 then drawText(('%02d  •  %02d'):format(index,#current.items),x+w-0.007,y+0.003,0.27,205,195,175,255,'right') end; y=y+0.026
    local maxV=Config.menumaxvisible; local last=math.min(offset+maxV,#current.items)
    for p=offset+1,last do local item=current.items[p]; local sel=p==index; if sel then drawRect(x+0.002,y,w-0.004,layout.item,54,47,34,238); drawRect(x+0.002,y,w-0.004,0.002,ar,ag,ab,255) else drawRect(x,y,w,layout.item,15,14,15,205) end; local tr,tg,tb=235,228,215; if sel then tr,tg,tb=255,235,175 elseif not item.enabled then tr,tg,tb=120,115,105 end; drawText(item.label,x+0.009,y+0.006,0.30,tr,tg,tb,255); local rt=item:rightText(); if rt~='' then drawText(rt,x+w-0.009,y+0.006,0.28,tr,tg,tb,255,'right') end; y=y+layout.item end
    local item=current.items[index]; if item and item.description~='' then local h=0.008+descriptionLines(item.description)*0.019; drawRect(x,y+0.003,w,h,36,31,25,235); drawText(item.description,x+0.008,y+0.008,0.25,225,215,190,255) end
    if Config.menuwatermark then drawText('TsivTools :)  /  coded by tsivolakos',x+w,anchorY-0.020,0.25,ar,ag,ab,255,'right') end
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
        TSIV.Notify('The text box timed out !', 'error')
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

function TSIV.Input(title, default, maxLength)
    if Config.usenuiinput then
        return nuiInput(title, default, maxLength, false)
    end
    return nativeInput(title, default, maxLength)
end

function TSIV.InputNumber(title, default, maxLength)
    local value
    if Config.usenuiinput then
        value = nuiInput(title, default and tostring(default) or '', maxLength or 10, true)
    else
        value = nativeInput(title, default and tostring(default) or '', maxLength or 10)
    end

    if value == nil then return nil end
    return tonumber((value:gsub('%s', '')))
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= TSIV.resource then return end
    SetNuiFocus(false, false)
end)
