TSIV.AntiCheat = {}

local AntiCheat = TSIV.AntiCheat
local settings = Config.AntiCheat

local blacklistedProps    = TSIV.BuildModelSet(settings.blacklistedProps)
local blacklistedVehicles = TSIV.BuildModelSet(settings.blacklistedVehicles)
local blacklistedPeds     = TSIV.BuildModelSet(settings.blacklistedPeds)

local windows = {}
local createdBy = {}
local ownerOfEntity = {}
local burst = {}
local reportedAt = {}

local reportKinds = { speed = true, health = true, armour = true, weapon = true }

local function isExempt(src)
    if not src or src <= 0 then return true end
    local rank = TSIV.GetRank(src)
    if not rank then return false end
    return TSIV.RankLevel(rank) >= TSIV.RankLevel(settings.exemptRank)
end

local function windowFor(src, kind, seconds)
    windows[src] = windows[src] or {}
    if not windows[src][kind] then
        windows[src][kind] = TSIV.NewWindow(seconds)
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
        ('player     : %s'):format(player.name),
        ('user ID    : %s'):format(src),
        ('steam ID   : %s'):format(player.steam),
        ('identifier : %s'):format(player.identifier),
        ('detection  : %s'):format(reason),
    }
    for _, extra in ipairs(detail or {}) do
        lines[#lines + 1] = extra
    end
    lines[#lines + 1] = ('action     : %s'):format(action)

    TSIV.StaffBroadcast(settings.alertRank, headline, lines)

    TSIV.Logs.Write({
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
            TSIV.Bans.BanPlayer(src, text, banLength or 0, 'tsivtools anticheat')
        else
            TSIV.Bans.Add(player.identifiers, player.name, text, banLength or 0, 'tsivtools anticheat')
        end
    elseif action == 'kick' and online then
        DropPlayer(src, ('Kicked by tsivtools.\n\nReason: %s'):format(reason))
    end
end

local function punish(src, action, reason, banLength, detail)
    local ids = TSIV.GetIdentifiers(src)
    local player = {
        name = TSIV.GetName(src),
        steam = ids.steam or 'no steam id',
        identifier = TSIV.GetPrimaryIdentifier(src),
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

    local detail = {
        ('count      : %d in %.1f second(s), limit is %d'):format(count, rules.window, rules.threshold),
        ('last model : %s'):format(modelName or 'unknown'),
    }

    if rules.cleanup then
        local removed = 0
        for _, handle in ipairs(burst[src][kind]) do
            if DoesEntityExist(handle) then
                DeleteEntity(handle)
                removed = removed + 1
            end
        end
        detail[#detail + 1] = ('cleanup    : deleted %d entity(s) from the burst'):format(removed)
    end
    burst[src][kind] = {}

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

local function modelLabel(model)
    return tostring(model)
end

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

    for _, member in ipairs(TSIV.GetStaff(settings.alertRank)) do
        TSIV.Console(member.source, message, 'warn')
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

    local model = GetEntityModel(entity)
    remember(owner, entity, model, kind)

    local netId = NetworkGetNetworkIdFromEntity(entity)

    local shouldLog =
        (kind == 'props'    and TSIV.PropLoggingEnabled())
        or (kind == 'vehicles' and settings.logVehicleSpawns)
        or (kind == 'peds'     and settings.logPedSpawns)

    if shouldLog then
        local line = ('%s spawned: user ID = %s (%s), prop ID = %s, netId = %s, model = %s'):format(
            kind:sub(1, #kind - 1), owner, TSIV.GetName(owner), entity, netId, modelLabel(model))

        for _, member in ipairs(TSIV.GetStaff(settings.propLogRank)) do
            TSIV.Console(member.source, line)
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

RegisterNetEvent(TSIV.Events.report, function(kind, detail)
    local src = source
    if not settings.enabled or not settings.client.enabled then return end
    if not reportKinds[kind] then return end
    if isExempt(src) then return end

    reportedAt[src] = reportedAt[src] or {}
    local now = GetGameTimer()
    if reportedAt[src][kind] and now - reportedAt[src][kind] < 30000 then return end
    reportedAt[src][kind] = now

    detail = TSIV.SafeString(detail, 160)

    TSIV.StaffBroadcast(settings.alertRank,
        ('%s^3[client check]^7 %s ^3(id %s)^7 - %s'):format(Config.Prefix, TSIV.GetName(src), src, kind), {
            ('player     : %s'):format(TSIV.GetName(src)),
            ('user ID    : %s'):format(src),
            ('steam ID   : %s'):format(TSIV.GetSteamId(src)),
            ('check      : %s'):format(kind),
            ('detail     : %s'):format(detail),
            'note       : client side check, verify before acting on it',
        })

    TSIV.Logs.Write({
        category = 'anticheat',
        message = ('client check "%s" on %s - %s'):format(kind, TSIV.Describe(src), detail),
        target = TSIV.GetPrimaryIdentifier(src),
        targetName = TSIV.GetName(src),
        data = { userId = src, steam = TSIV.GetSteamId(src), check = kind, reason = 'client check ' .. kind, detail = detail },
    })
end)

AddEventHandler('playerDropped', function()
    local src = source

    if settings.cleanupOnDisconnect then
        local removed = AntiCheat.DeleteEntitiesOf(src)
        if removed > 0 then
            print(('%scleaned up %d entity(s) left behind by %s'):format(
                Config.ConsolePrefix, removed, TSIV.Describe(src)))
        end
    end

    for entity in pairs(createdBy[src] or {}) do
        ownerOfEntity[entity] = nil
    end

    windows[src] = nil
    createdBy[src] = nil
    burst[src] = nil
    reportedAt[src] = nil
end)

TSIV.RegisterRequest('anticheat.status', 'staff.alerts', function()
    local lines = {
        ('enabled           : %s'):format(settings.enabled and 'yes' or 'no'),
        ('prop logging      : %s'):format(TSIV.PropLoggingEnabled() and 'on' or 'off'),
        ('prop spam         : %s, >%d in %.1fs -> %s'):format(
            settings.propSpam.enabled and 'on' or 'off',
            settings.propSpam.threshold, settings.propSpam.window, settings.propSpam.action),
        ('vehicle spam      : %s, >%d in %.1fs -> %s'):format(
            settings.vehicleSpam.enabled and 'on' or 'off',
            settings.vehicleSpam.threshold, settings.vehicleSpam.window, settings.vehicleSpam.action),
        ('ped spam          : %s, >%d in %.1fs -> %s'):format(
            settings.pedSpam.enabled and 'on' or 'off',
            settings.pedSpam.threshold, settings.pedSpam.window, settings.pedSpam.action),
        ('explosions        : %s, >%d in %.1fs -> %s'):format(
            settings.explosions.enabled and 'on' or 'off',
            settings.explosions.threshold, settings.explosions.window, settings.explosions.action),
        ('blacklisted props : %d'):format(#settings.blacklistedProps),
        ('blacklisted cars  : %d'):format(#settings.blacklistedVehicles),
        ('blacklist action  : %s'):format(settings.blacklistAction),
        ('alerts go to      : %s and above'):format(TSIV.RankLabel(settings.alertRank)),
        ('exempt from       : %s and above'):format(TSIV.RankLabel(settings.exemptRank)),
    }
    return { title = 'tsivtools anticheat status', lines = lines }
end)
