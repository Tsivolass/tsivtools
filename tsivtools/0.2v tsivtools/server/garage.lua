tsivtools.Garage = {}

local Garage = tsivtools.Garage

local function usingMysql()
    return     Config.Garage.mode == 'mysql' and tsivtools.Storage.UsingMysql()
end

local function fileStore()
    return tsivtools.Storage.Get('garages')
end

local function modelOf(props)
    if type(props) == 'string' then
        local ok, decoded = pcall(json.decode, props)
        props = ok and decoded or nil
    end
    return type(props) == 'table' and props.modelName or 'unknown'
end

local function generatePlate()
    local prefix = Config.Garage.platePrefix:sub(1, 7)
    local length = math.max(#prefix + 1, math.min(Config.Garage.plateLength, 8))
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local plate = prefix
    for _ = 1, length - #prefix do
        local index = math.random(#chars)
        plate = plate .. chars:sub(index, index)
    end
    return plate
end

local function plateExists(plate)
    if usingMysql() then
        local found = tsivtools.Storage.Scalar(([[SELECT `%s` FROM `%s` WHERE `%s` = ? LIMIT 1]])
            :format(Config.Garage.plateColumn, Config.Garage.table, Config.Garage.plateColumn), { plate })
        return found ~= nil
    end
    for _, vehicles in pairs(fileStore()) do
        for _, vehicle in ipairs(vehicles) do
            if vehicle.plate == plate then return true end
        end
    end
    return false
end

local function uniquePlate()
    for _ = 1, 25 do
        local plate = generatePlate()
        if not plateExists(plate) then return plate end
    end
    return generatePlate() .. tostring(math.random(9))
end

function Garage.Give(identifier, model, plate, props)
    plate = tsivtools.SafeString(plate, 8):upper()
    if plate == '' then plate = uniquePlate() end
    model = tsivtools.SafeString(model, 32):lower()
    if model == '' then return nil, 'no model given' end
    if plateExists(plate) then return nil, ('plate %s already exists'):format(plate) end

    props = props or {}
    props.model = props.model or GetHashKey(model)
    props.plate = plate
    props.modelName = model

    if usingMysql() then
        local columns = { Config.Garage.ownerColumn, Config.Garage.plateColumn, Config.Garage.propsColumn }
        local values = { identifier, plate, json.encode(props) }
        for column, value in pairs(Config.Garage.extraColumns) do
            columns[#columns + 1] = column
            values[#values + 1] = value
        end

        local placeholders = {}
        local quoted = {}
        for index, column in ipairs(columns) do
            placeholders[index] = '?'
            quoted[index] = ('`%s`'):format(column)
        end

        tsivtools.Storage.Insert(('INSERT INTO `%s` (%s) VALUES (%s)')
            :format(Config.Garage.table, table.concat(quoted, ', '), table.concat(placeholders, ', ')), values)
    else
        local store = fileStore()
        store[identifier] = store[identifier] or {}
        table.insert(store[identifier], {
            plate = plate,
            model = model,
            hash = GetHashKey(model),
            props = props,
            addedAt = os.time(),
        })
        tsivtools.Storage.MarkDirty('garages')
        tsivtools.Storage.Flush('garages')
    end

    return plate
end

function Garage.Remove(identifier, plate)
    plate = tsivtools.SafeString(plate, 8):upper()
    if plate == '' then return nil end

    if usingMysql() then
        local row = tsivtools.Storage.Single(([[SELECT * FROM `%s` WHERE `%s` = ? AND `%s` = ? LIMIT 1]])
            :format(Config.Garage.table, Config.Garage.ownerColumn, Config.Garage.plateColumn),
            { identifier, plate })
        if not row then return nil end
        tsivtools.Storage.Execute(([[DELETE FROM `%s` WHERE `%s` = ? AND `%s` = ?]])
            :format(Config.Garage.table, Config.Garage.ownerColumn, Config.Garage.plateColumn),
            { identifier, plate })
        return { plate = plate, model = modelOf(row[Config.Garage.propsColumn]) }
    end

    local store = fileStore()
    local vehicles = store[identifier]
    if not vehicles then return nil end

    for index, vehicle in ipairs(vehicles) do
        if vehicle.plate == plate then
            table.remove(vehicles, index)
            tsivtools.Storage.MarkDirty('garages')
            tsivtools.Storage.Flush('garages')
            return vehicle
        end
    end
    return nil
end

function Garage.List(identifier)
    if usingMysql() then
        local rows = tsivtools.Storage.Query(([[SELECT * FROM `%s` WHERE `%s` = ?]])
            :format(Config.Garage.table, Config.Garage.ownerColumn), { identifier }) or {}
        local out = {}
        for _, row in ipairs(rows) do
            out[#out + 1] = {
                plate = row[Config.Garage.plateColumn],
                model = modelOf(row[Config.Garage.propsColumn]),
                stored = row.stored,
            }
        end
        return out
    end

    return fileStore()[identifier] or {}
end

local function resolveIdentifier(value)
    local target = tsivtools.ResolveTarget(value)
    if target then
        return tsivtools.GetPrimaryIdentifier(target), tsivtools.GetName(target), target
    end

    local text = tsivtools.SafeString(value, 80)
    if text:find(':') then
        return text, text, nil
    end
    return nil
end

tsivtools.RegisterRequest('garage.lookup', 'garage.lookup', function(src, payload)
    local identifier, name = resolveIdentifier(payload.target)
    if not identifier then
        return { title = 'TsivTools garage lookup', lines = { 'No player with that user ID or identifier !' } }
    end

    local vehicles = Garage.List(identifier)
    local lines = {
        ('owner : %s'):format(name or identifier),
        ('id    : %s'):format(identifier),
        ('count : %d'):format(#vehicles),
        ('-'):rep(60),
    }

    if #vehicles == 0 then
        lines[#lines + 1] = 'This garage is empty.'
    else
        for index, vehicle in ipairs(vehicles) do
            lines[#lines + 1] = ('%2d. plate %-9s model %s%s'):format(
                index, vehicle.plate or '?', vehicle.model or '?',
                vehicle.addedAt and ('   added ' .. tsivtools.FormatTimestamp(vehicle.addedAt)) or '')
        end
    end

    tsivtools.Logs.Staff(src, ('Looked up the garage of %s'):format(name or identifier), identifier)

    return { title = ('TsivTools garage lookup: %s'):format(name or identifier), lines = lines, vehicles = vehicles }
end)

tsivtools.RegisterAction('garage.give', 'garage.give', function(src, payload)
    local identifier, name, target = resolveIdentifier(payload.target)
    if not identifier then
        tsivtools.Notify(src, 'No player with that ID !', 'error')
        return
    end

    local model = tsivtools.SafeString(payload.model, 32):lower()
    if model == '' then
        tsivtools.Notify(src, 'You need to input a vehicle model name !', 'error')
        return
    end

    local plate, err = Garage.Give(identifier, model, payload.plate)
    if not plate then
        tsivtools.Notify(src, ('Could not add the vehicle: %s'):format(err or 'unknown error'), 'error')
        return
    end

    tsivtools.Notify(src, ('Added %s (plate %s) to the garage of %s'):format(model, plate, name or identifier), 'success')
    if target then
        tsivtools.Notify(target, ('A %s was added to your garage, plate %s'):format(model, plate), 'info')
    end

    tsivtools.Logs.Write({
        category = 'garage',
        message = ('Added %s (plate %s) to the garage of %s'):format(model, plate, name or identifier),
        actor = tsivtools.GetPrimaryIdentifier(src),
        actorName = tsivtools.GetName(src),
        target = identifier,
        targetName = name or '',
        data = { model = model, plate = plate },
    })
end)

tsivtools.RegisterAction('garage.remove', 'garage.remove', function(src, payload)
    local identifier, name, target = resolveIdentifier(payload.target)
    if not identifier then
        tsivtools.Notify(src, 'No player with that ID !', 'error')
        return
    end

    local plate = tsivtools.SafeString(payload.plate, 8):upper()
    local removed = Garage.Remove(identifier, plate)
    if not removed then
        tsivtools.Notify(src, ('No vehicle with plate %s in that garage !'):format(plate), 'error')
        return
    end

    tsivtools.Notify(src, ('Removed plate %s from the garage of %s'):format(plate, name or identifier), 'success')
    if target then
        tsivtools.Notify(target, ('The vehicle with plate %s was removed from your garage !'):format(plate), 'info')
    end

    tsivtools.Logs.Write({
        category = 'garage',
        message = ('Removed plate %s (%s) from the garage of %s'):format(plate, removed.model or '?', name or identifier),
        actor = tsivtools.GetPrimaryIdentifier(src),
        actorName = tsivtools.GetName(src),
        target = identifier,
        targetName = name or '',
        data = { plate = plate, model = removed.model },
    })
end)
