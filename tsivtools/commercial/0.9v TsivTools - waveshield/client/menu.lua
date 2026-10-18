tsivtools.Menu = {}

local Menu = tsivtools.Menu
local Item = {}
Item.__index = Item

local current = nil
local stack = {}
local index = 1
local inputLocked = false

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

local MenuObject = {}
MenuObject.__index = MenuObject

function Menu.Create(title, subtitle)
    return setmetatable({
        title = title or Config.menutitle or 'Staff Panel',
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

local function serializeItem(item)
    local data = {
        kind = item.kind,
        label = item.label,
        description = item.description or '',
        enabled = item.enabled and true or false,
        right = '',
        checked = false,
    }

    if item.kind == 'checkbox' then
        data.checked = item.checked and true or false
    elseif item.kind == 'list' then
        local value = item.values[item.selected]
        data.right = tostring(type(value) == 'table' and (value.label or value.value) or value)
        data.listIndex = item.selected
        data.listCount = #item.values
    elseif item.kind == 'submenu' then
        data.right = '>'
    else
        data.right = item.right or ''
    end

    return data
end

local function render()
    if not current then return end

    local items = {}
    for i = 1, #current.items do
        items[i] = serializeItem(current.items[i])
    end

    local categories = {}
    local rootMenu = stack[1]
    if rootMenu then
        for i = 1, #rootMenu.items do
            local item = rootMenu.items[i]
            if item.kind == 'submenu' then
                categories[#categories + 1] = {
                    index = i,
                    label = item.label,
                    active = (stack[2] == item.submenu) and true or false,
                }
            end
        end
    end

    local path = {}
    for _, menu in ipairs(stack) do
        path[#path + 1] = menu.title
    end

    local accent = Config.menucolour or { 168, 85, 247 }

    SendNUIMessage({
        action = 'menu:render',
        title = current.title,
        subtitle = current.subtitle or '',
        path = path,
        categories = categories,
        items = items,
        index = index,
        accent = { r = accent[1], g = accent[2], b = accent[3] },
        position = Config.menuposition or 'right',
    })
end

local function focusMenu()
    SetNuiFocus(true, true)
end

function Menu.Open(menu)
    current = menu
    stack = { menu }
    index = firstSelectable(1, 1)
    if menu.onOpen then menu.onOpen(menu) end
    focusMenu()
    SendNUIMessage({ action = 'menu:open' })
    render()
end

function Menu.Close()
    if current and current.onClose then current.onClose(current) end
    current = nil
    stack = {}
    SendNUIMessage({ action = 'menu:close' })
    SetNuiFocus(false, false)
end

function Menu.IsOpen()
    return current ~= nil
end

function Menu.Current()
    return current
end

function Menu.Refresh()
    render()
end

local function push(menu)
    stack[#stack + 1] = menu
    current = menu
    index = firstSelectable(1, 1)
    if menu.onOpen then menu.onOpen(menu) end
    render()
end

local function pop()
    if #stack <= 1 then
        Menu.Close()
        return
    end
    table.remove(stack)
    current = stack[#stack]
    index = firstSelectable(1, 1)
    if current.onOpen then current.onOpen(current) end
    render()
end

Menu.Back = pop

function Menu.Push(menu)
    if not current then
        Menu.Open(menu)
        return
    end
    push(menu)
end

local function changeList(item, direction)
    if not item or item.kind ~= 'list' then return end

    item.selected = item.selected + direction
    if item.selected < 1 then item.selected = #item.values end
    if item.selected > #item.values then item.selected = 1 end

    if item.onChange then
        local value = item.values[item.selected]
        item.onChange(type(value) == 'table' and value.value or value, item.selected, item)
    end
end

local function select(item)
    if not item or not item.enabled then return end

    if item.kind == 'submenu' then
        push(item.submenu)
        return
    end

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

function Menu.LockInput(state)
    inputLocked = state and true or false
end

function Menu.InputLocked()
    return inputLocked
end

CreateThread(function()
    while true do
        if current then
            DisableAllControlActions(0)
            Wait(1)
        else
            Wait(250)
        end
    end
end)

RegisterNUICallback('menuList', function(data, cb)
    cb('ok')
    CreateThread(function()
        if not current then return end
        local itemIndex = tonumber(data and data.index)
        local direction = tonumber(data and data.direction) or 1
        local item = itemIndex and current.items[itemIndex]
        if not item then return end
        index = itemIndex
        changeList(item, direction)
        render()
    end)
end)

RegisterNUICallback('menuActivate', function(data, cb)
    cb('ok')
    CreateThread(function()
        if not current then return end
        local itemIndex = tonumber(data and data.index)
        local item = itemIndex and current.items[itemIndex]
        if not item then return end
        index = itemIndex
        select(item)
        render()
    end)
end)

RegisterNUICallback('menuCategory', function(data, cb)
    cb('ok')
    CreateThread(function()
        local rootMenu = stack[1]
        if not rootMenu then return end
        local itemIndex = tonumber(data and data.index)
        local item = itemIndex and rootMenu.items[itemIndex]
        if not item or item.kind ~= 'submenu' then return end

        stack = { rootMenu, item.submenu }
        current = item.submenu
        index = firstSelectable(1, 1)
        if current.onOpen then current.onOpen(current) end
        render()
    end)
end)

RegisterNUICallback('menuBack', function(_, cb)
    cb('ok')
    CreateThread(pop)
end)

RegisterNUICallback('menuClose', function(_, cb)
    cb('ok')
    CreateThread(Menu.Close)
end)

local pending = nil

RegisterNUICallback('inputSubmit', function(data, cb)
    if pending then
        pending.value = type(data) == 'table' and data.value or nil
        pending.done = true
    end
    cb('ok')
end)

RegisterNUICallback('inputCancel', function(_, cb)
    if pending then
        pending.value = nil
        pending.done = true
    end
    cb('ok')
end)

local function nuiInput(title, default, maxLength, numeric)
    if pending then
        return nil
    end

    pending = { done = false, value = nil }

    Menu.LockInput(true)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openInput',
        title = title or 'Enter a value',
        default = default or '',
        maxLength = maxLength or 64,
        numeric = numeric and true or false,
    })

    local waited = 0
    while pending and not pending.done and waited < 120000 do
        Wait(50)
        waited = waited + 50
    end

    if not pending then
        Menu.LockInput(false)
        if Menu.IsOpen() then
            SetNuiFocus(true, true)
        else
            SetNuiFocus(false, false)
        end
        return nil
    end

    local result = pending.value
    local timedOut = not pending.done
    pending = nil

    if timedOut then
        SendNUIMessage({ action = 'closeInput' })
    end

    Menu.LockInput(false)

    if Menu.IsOpen() then
        SetNuiFocus(true, true)
    else
        SetNuiFocus(false, false)
    end

    if timedOut then
        tsivtools.Notify('Input timed out', 'error')
        return nil
    end

    return result
end

local function nativeInput(title, default, maxLength)
    Menu.LockInput(true)

    AddTextEntry('TSIVTOOLS_INPUT', title or 'Enter a value')
    DisplayOnscreenKeyboard(1, 'TSIVTOOLS_INPUT', '', default or '', '', '', '', (maxLength or 64) + 1)

    local status = UpdateOnscreenKeyboard()
    local waited = 0
    while status ~= 1 and status ~= 2 and waited < 120000 do
        DisableAllControlActions(0)
        Wait(1)
        waited = waited + 1
        status = UpdateOnscreenKeyboard()
    end

    Menu.LockInput(false)

    if status ~= 1 then
        return nil
    end

    local result = GetOnscreenKeyboardResult()
    Wait(50)
    return result
end

function tsivtools.Input(title, default, maxLength)
    if Config.usenuiinput then
        return nuiInput(title, default, maxLength, false)
    end
    return nativeInput(title, default, maxLength)
end

function tsivtools.InputNumber(title, default, maxLength)
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
    if resource ~= tsivtools.resource then return end
    SetNuiFocus(false, false)
end)
