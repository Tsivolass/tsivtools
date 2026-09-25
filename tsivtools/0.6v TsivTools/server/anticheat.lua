tsivtools.AntiCheat = {}

local AntiCheat = tsivtools.AntiCheat
local settings = Config.AntiCheat

local blacklistedProps    = tsivtools.BuildModelSet(settings.blacklistedProps)
local blacklistedVehicles = tsivtools.BuildModelSet(settings.blacklistedVehicles)
local blacklistedPeds     = tsivtools.BuildModelSet(settings.blacklistedPeds)

local windows = {}
local createdBy = {}
local ownerOfEntity = {}
local burst = {}
local reportedAt = {}

local reportKinds = { speed = true, health = true, armour = true, weapon = true }

local scriptPopulationTypes = { [6] = true, [7] = true }

local function isScriptSpawned(entity)
    if not settings.ignoreAmbientEntities then return true end
    return scriptPopulationTypes[GetEntityPopulationType(entity)] == true
end

local alertedAt = {}

local function alertAllowed(src, kind)
    local cooldown = settings.alertCooldownSeconds
    if cooldown <= 0 then return true, 0 end

    alertedAt[src] = alertedAt[src] or {}
    local entry = alertedAt[src][kind]
    local now = GetGameTimer() / 1000.0

    if entry and now - entry.at < cooldown then
        entry.held = entry.held + 1
        return false, entry.held
    end

    local held = entry and entry.held or 0
    alertedAt[src][kind] = { at = now, held = 0 }
    return true, held
end

local function isExempt(src)
    if not src or src <= 0 then return true end
    local rank = tsivtools.GetRank(src)
    if not rank then return false end
    return tsivtools.RankLevel(rank) >= tsivtools.RankLevel(settings.exemptRank)
end

local function windowFor(src, kind, seconds)
    windows[src] = windows[src] or {}
    if not windows[src][kind] then
        windows[src][kind] = tsivtools.NewWindow(seconds)
    end
    return windows[src][kind]
end

function AntiCheat.IsBlacklistedProp(model)
    if type(model) == 'string' then model = model:lower() end
    return blacklistedProps[model] ~= nil
end

function AntiCheat.IsBlacklistedVehicle(model)
    if type(model) == 'string' then model = model:lower() end
    return blacklistedVehicles[model] ~= nil
end

function AntiCheat.IsBlacklistedPed(model)
    if type(model) == 'string' then model = model:lower() end
    return blacklistedPeds[model] ~= nil
end

local function remember(src, entity, model, kind)
    createdBy[src] = createdBy[src] or {}
    createdBy[src][entity] = { model = model, kind = kind, at = os.time() }
    ownerOfEntity[entity] = src
end

function AntiCheat.DeleteEntitiesOf(src, kind)
    local owned = createdBy[src]
    if not owned then return 0 end

    local removed = 0
    for entity, info in pairs(owned) do
        if not kind or kind == 'all' or info.kind == kind then
            if DoesEntityExist(entity) then
                DeleteEntity(entity)
                removed = removed + 1
            end
            owned[entity] = nil
            ownerOfEntity[entity] = nil
        end
    end
    return removed
end

local function punishNow(src, player, action, reason, banLength, detail)
    local headline = ('%s^1[anticheat]^7 %s ^3(id %s)^7 - %s'):format(Config.Prefix, player.name, src, reason)

    local lines = {
        ('player    : %s'):format(player.name),
        ('user ID   : %s'):format(src),
        ('steam ID  : %s'):format(player.steam),
        ('identifier: %s'):format(player.identifier),
        ('detection : %s'):format(reason),
    }
    for _, extra in ipairs(detail or {}) do
        lines[#lines + 1] = extra
    end
    lines[#lines + 1] = ('action     : %s'):format(action)

    tsivtools.StaffBroadcast(settings.alertRank, headline, lines)

    tsivtools.Logs.Write({
        category = 'anticheat',
        message = ('%s - %s (action: %s)'):format(player.name, reason, action),
        target = player.identifier,
        targetName = player.name,
        data = { steam = player.steam, userId = src, reason = reason, detail = detail },
    })

    local online = GetPlayerName(src) ~= nil

    if action == 'ban' then
        local text = ('[tsivtools] %s'):format(reason)
        if online then
            tsivtools.Bans.BanPlayer(src, text, banLength or 0, 'tsivtools anticheat')
        else
            tsivtools.Bans.Add(player.identifiers, player.name, text, banLength or 0, 'tsivtools anticheat')
        end
    elseif action == 'kick' and online then
        DropPlayer(src, ('Kicked by TsivTools.\n\nReason: %s'):format(reason))
    end
end

local function punish(src, action, reason, banLength, detail)
    local ids = tsivtools.GetIdentifiers(src)
    local player = {
        name = tsivtools.GetName(src),
        steam = ids.steam or 'no steam id',
        identifier = tsivtools.GetPrimaryIdentifier(src),
        identifiers = {},
    }
    for _, identifier in pairs(ids) do
        player.identifiers[#player.identifiers + 1] = identifier
    end

    CreateThread(function()
        punishNow(src, player, action, reason, banLength, detail)
    end)
end

AntiCheat.Punish = punish

local function checkSpam(src, kind, rules, entity, modelName)
    if not rules.enabled then return end
    if isExempt(src) then return end

    local window = windowFor(src, kind, rules.window)
    local count = window:push(entity)

    burst[src] = burst[src] or {}
    burst[src][kind] = burst[src][kind] or {}
    table.insert(burst[src][kind], entity)
    if #burst[src][kind] > 128 then
        table.remove(burst[src][kind], 1)
    end

    if count <= rules.threshold then return end

    window:reset()

    local allowed, held = alertAllowed(src, kind)

    local detail = {
        ('count     : %d in %.1f second(s), limit is %d'):format(count, rules.window, rules.threshold),
        ('last model: %s'):format(modelName or 'unknown'),
    }
    if held > 0 then
        detail[#detail + 1] = ('suppressed: %d more since the last alert'):format(held)
    end

    if rules.cleanup then
        local removed = 0
        for _, handle in ipairs(burst[src][kind]) do
            if DoesEntityExist(handle) then
                DeleteEntity(handle)
                removed = removed + 1
            end
        end
        detail[#detail + 1] = ('cleanup : deleted %d entity(s) from the burst'):format(removed)
    end
    burst[src][kind] = {}

    if rules.action == 'alert' and not allowed then return end

    punish(src, rules.action, rules.reason, rules.banLength, detail)
end

local kindByType = { [1] = 'peds', [2] = 'vehicles', [3] = 'props' }

local function ownerOf(entity)
    local owner = NetworkGetEntityOwner(entity)
    if owner and owner > 0 and GetPlayerName(owner) then
        return owner
    end
    return nil
end

local modelNames = {}

local function learnModels(list, field)
    for _, entry in ipairs(list or {}) do
        local name = field and entry[field] or entry
        if type(name) == 'string' then
            modelNames[GetHashKey(name:lower())] = name:lower()
        end
    end
end

learnModels(settings.blacklistedProps)
learnModels(settings.blacklistedVehicles)
learnModels(settings.blacklistedPeds)
learnModels(settings.knownModels)
learnModels(Config.VehicleList, 'model')

local function modelLabel(model)
    if type(model) ~= 'number' then return tostring(model) end

    local unsigned = model < 0 and (model + 4294967296) or model
    local name = modelNames[model]

    if name then
        return ('%s (%d)'):format(name, unsigned)
    end
    return tostring(unsigned)
end

tsivtools.AntiCheat.ModelLabel = modelLabel

AddEventHandler('entityCreating', function(entity)
    if not settings.enabled then return end
    if not DoesEntityExist(entity) then return end

    local model = GetEntityModel(entity)
    local entityType = GetEntityType(entity)
    local kind = kindByType[entityType]
    if not kind then return end

    local blacklisted =
        (kind == 'props'    and blacklistedProps[model])
        or (kind == 'vehicles' and blacklistedVehicles[model])
        or (kind == 'peds'     and blacklistedPeds[model])

    if not blacklisted then return end

    local owner = ownerOf(entity)

    if owner and isExempt(owner) then return end

    CancelEvent()

    if not owner then
        print(('%sblocked a blacklisted %s (model %s) with no identifiable owner'):format(
            Config.ConsolePrefix, kind, modelLabel(model)))
        return
    end

    local message = ('potential cheater spawning props: user ID = %s, prop ID: %s'):format(owner, entity)

    for _, member in ipairs(tsivtools.GetStaff(settings.alertRank)) do
        tsivtools.Console(member.source, message, 'warn')
    end
    print(Config.ConsolePrefix .. message)

    local detail = {
        ('blocked    : %s (%s)'):format(blacklisted, kind),
        ('model hash : %s'):format(modelLabel(model)),
        ('prop ID    : %s'):format(entity),
    }

    punish(owner, settings.blacklistAction, settings.blacklistReason, settings.blacklistBanLength, detail)
end)

AddEventHandler('entityCreated', function(entity)
    if not settings.enabled then return end
    if not DoesEntityExist(entity) then return end

    local entityType = GetEntityType(entity)
    local kind = kindByType[entityType]
    if not kind then return end

    local owner = ownerOf(entity)
    if not owner then return end
    if not isScriptSpawned(entity) then return end

    local model = GetEntityModel(entity)
    remember(owner, entity, model, kind)

    local netId = NetworkGetNetworkIdFromEntity(entity)

    local shouldLog =
        (kind == 'props'    and tsivtools.PropLoggingEnabled())
        or (kind == 'vehicles' and settings.logVehicleSpawns)
        or (kind == 'peds'     and settings.logPedSpawns)

    if shouldLog then
        local singular = kind:sub(1, #kind - 1)
        local line = ('%s spawned: user ID = %s (%s), prop ID = %s, model = %s'):format(
            singular, owner, tsivtools.GetName(owner), entity, modelLabel(model))

        for _, member in ipairs(tsivtools.GetStaff(settings.propLogRank)) do
            tsivtools.Console(member.source, line)
        end

        if settings.logSpawnsToStore then
            tsivtools.Logs.Write({
                category = 'props',
                message = line,
                actor = tsivtools.GetPrimaryIdentifier(owner),
                actorName = tsivtools.GetName(owner),
                target = tsivtools.GetPrimaryIdentifier(owner),
                targetName = tsivtools.GetName(owner),
                data = {
                    kind = singular,
                    userId = owner,
                    entity = entity,
                    netId = netId,
                    model = modelLabel(model),
                    steam = tsivtools.GetSteamId(owner),
                },
            })
        end
    end

    if kind == 'props' then
        checkSpam(owner, 'props', settings.propSpam, entity, modelLabel(model))
    elseif kind == 'vehicles' then
        checkSpam(owner, 'vehicles', settings.vehicleSpam, entity, modelLabel(model))
    elseif kind == 'peds' then
        checkSpam(owner, 'peds', settings.pedSpam, entity, modelLabel(model))
    end
end)

AddEventHandler('entityRemoved', function(entity)
    local owner = ownerOfEntity[entity]
    if not owner then return end
    ownerOfEntity[entity] = nil
    if createdBy[owner] then createdBy[owner][entity] = nil end
end)

AddEventHandler('explosionEvent', function(sender, ev)
    if not settings.enabled or not settings.explosions.enabled then return end

    local src = tonumber(sender)
    if not src or not GetPlayerName(src) then return end
    if isExempt(src) then return end

    local rules = settings.explosions

    for _, blockedType in ipairs(rules.blocked) do
        if ev.explosionType == blockedType then
            CancelEvent()
            punish(src, rules.action, ('Blocked explosion type %s'):format(ev.explosionType), rules.banLength, {
                ('explosion  : type %s at %.1f, %.1f, %.1f'):format(
                    ev.explosionType, ev.posX or 0.0, ev.posY or 0.0, ev.posZ or 0.0),
            })
            return
        end
    end

    local window = windowFor(src, 'explosions', rules.window)
    local count = window:push(ev.explosionType)
    if count > rules.threshold then
        window:reset()
        punish(src, rules.action, rules.reason, rules.banLength, {
            ('count      : %d explosion(s) in %.1f second(s)'):format(count, rules.window),
            ('last type  : %s'):format(ev.explosionType),
        })
    end
end)

RegisterNetEvent(tsivtools.Events.report, function(kind, detail)
    local src = source
    if not settings.enabled or not settings.client.enabled then return end
    if not reportKinds[kind] then return end
    if isExempt(src) then return end

    reportedAt[src] = reportedAt[src] or {}
    local now = GetGameTimer()
    if reportedAt[src][kind] and now - reportedAt[src][kind] < 30000 then return end
    reportedAt[src][kind] = now

    detail = tsivtools.SafeString(detail, 160)

    tsivtools.StaffBroadcast(settings.alertRank,
        ('%s^3[client check]^7 %s ^3(id %s)^7 - %s'):format(Config.Prefix, tsivtools.GetName(src), src, kind), {
            ('player   : %s'):format(tsivtools.GetName(src)),
            ('user ID  : %s'):format(src),
            ('steam ID : %s'):format(tsivtools.GetSteamId(src)),
            ('check    : %s'):format(kind),
            ('detail   : %s'):format(detail),
            'note      : client side check, verify before acting on it!',
        })

    tsivtools.Logs.Write({
        category = 'anticheat',
        message = ('client check "%s" on %s - %s'):format(kind, tsivtools.Describe(src), detail),
        target = tsivtools.GetPrimaryIdentifier(src),
        targetName = tsivtools.GetName(src),
        data = { userId = src, steam = tsivtools.GetSteamId(src), check = kind, reason = 'client check ' .. kind, detail = detail },
    })
end)

AddEventHandler('playerDropped', function()
    local src = source

    if settings.cleanupOnDisconnect then
        local removed = AntiCheat.DeleteEntitiesOf(src)
        if removed > 0 then
            print(('%scleaned up %d entity(s) left behind by %s'):format(
                Config.ConsolePrefix, removed, tsivtools.Describe(src)))
        end
    end

    for entity in pairs(createdBy[src] or {}) do
        ownerOfEntity[entity] = nil
    end

    windows[src] = nil
    createdBy[src] = nil
    burst[src] = nil
    alertedAt[src] = nil
    reportedAt[src] = nil
end)

tsivtools.RegisterRequest('anticheat.status', 'staff.alerts', function()
    local lines = {
        ('enabled     : %s'):format(settings.enabled and 'yes' or 'no'),
        ('prop logging: %s'):format(tsivtools.PropLoggingEnabled() and 'on' or 'off'),
        ('prop spam   : %s, >%d in %.1fs -> %s'):format(
            settings.propSpam.enabled and 'on' or 'off',
            settings.propSpam.threshold, settings.propSpam.window, settings.propSpam.action),
        ('vehicle spam: %s, >%d in %.1fs -> %s'):format(
            settings.vehicleSpam.enabled and 'on' or 'off',
            settings.vehicleSpam.threshold, settings.vehicleSpam.window, settings.vehicleSpam.action),
        ('ped spam    : %s, >%d in %.1fs -> %s'):format(
            settings.pedSpam.enabled and 'on' or 'off',
            settings.pedSpam.threshold, settings.pedSpam.window, settings.pedSpam.action),
        ('explosions  : %s, >%d in %.1fs -> %s'):format(
            settings.explosions.enabled and 'on' or 'off',
            settings.explosions.threshold, settings.explosions.window, settings.explosions.action),
        ('blacklisted props : %d'):format(#settings.blacklistedProps),
        ('blacklisted cars  : %d'):format(#settings.blacklistedVehicles),
        ('blacklist action  : %s'):format(settings.blacklistAction),
        ('alerts go to      : %s and above'):format(tsivtools.RankLabel(settings.alertRank)),
        ('exempt from       : %s and above'):format(tsivtools.RankLabel(settings.exemptRank)),
    }
    return { title = 'TsivTools anticheat status', lines = lines }
end)
