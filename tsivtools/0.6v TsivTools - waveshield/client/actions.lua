tsivtools.Actions = {}

local pendingRequests = {}
local nextRequestId = 0

function tsivtools.Action(name, payload)
    TriggerServerEvent(tsivtools.Events.action, name, payload or {})
end

function tsivtools.Request(name, payload, timeout)
    nextRequestId = nextRequestId + 1
    local requestId = nextRequestId

    pendingRequests[requestId] = { done = false, result = nil }
    TriggerServerEvent(tsivtools.Events.request, name, requestId, payload or {})

    local waited = 0
    timeout = timeout or 8000
    while not pendingRequests[requestId].done and waited < timeout do
        Wait(25)
        waited = waited + 25
    end

    local entry = pendingRequests[requestId]
    pendingRequests[requestId] = nil

    if not entry.done then
        tsivtools.Notify('The server did not answer in time !', 'error')
        return nil
    end

    return entry.result
end

RegisterNetEvent(tsivtools.Events.response, function(requestId, result)
    local entry = pendingRequests[requestId]
    if not entry then return end
    entry.result = result
    entry.done = true
end)

function tsivtools.ShowBlock(block, emptyMessage)
    if not block then
        tsivtools.Notify(emptyMessage or 'Nothing came back !', 'error')
        return
    end
    tsivtools.PrintBlock(block.title or 'tsivtools', block.lines or {})
    tsivtools.Notify('Printed results to console !', 'success')
end

tsivtools.State = {
    god = false,
    invisible = false,
    noclip = false,
    spectating = nil,
    frozen = false,
}

local function requestModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        return nil
    end

    RequestModel(hash)
    local waited = 0
    while not HasModelLoaded(hash) and waited < 5000 do
        Wait(25)
        waited = waited + 25
    end

    if not HasModelLoaded(hash) then return nil end
    return hash
end

function tsivtools.RaycastEntity(distance)
    local ped = PlayerPedId()
    local from = GetGameplayCamCoord()
    local rotation = GetGameplayCamRot(2)

    local radians = { x = math.rad(rotation.x), z = math.rad(rotation.z) }
    local direction = vector3(
        -math.sin(radians.z) * math.abs(math.cos(radians.x)),
        math.cos(radians.z) * math.abs(math.cos(radians.x)),
        math.sin(radians.x))

    local to = from + direction * (distance or 25.0)

    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, -1, ped, 0)
    local _, hit, coords, _, entity = GetShapeTestResult(ray)

    if hit == 1 and entity and entity ~= 0 then
        return entity, coords
    end
    return nil
end

function tsivtools.ClosestObject(maxDistance)
    local origin = GetEntityCoords(PlayerPedId())
    local closest, closestDistance = nil, maxDistance or 25.0

    local handle, object = FindFirstObject()
    local finished = false
    repeat
        if DoesEntityExist(object) then
            local distance = #(origin - GetEntityCoords(object))
            if distance < closestDistance then
                closest, closestDistance = object, distance
            end
        end
        finished, object = FindNextObject(handle)
    until not finished
    EndFindObject(handle)

    return closest
end

function tsivtools.DeleteEntityViaServer(entity, kind)
    if not entity or not DoesEntityExist(entity) then
        tsivtools.Notify('Nothing there to delete.', 'error')
        return
    end

    if not NetworkGetEntityIsNetworked(entity) then
        SetEntityAsMissionEntity(entity, true, true)
        DeleteEntity(entity)
        tsivtools.Notify('Deleted a local entity !', 'success')
        return
    end

    tsivtools.Action('entity.deleteNearest', {
        netId = NetworkGetNetworkIdFromEntity(entity),
        kind = kind or 'props',
    })
end

local noclipSpeed = 1.0

local function release(entity)
    if entity and DoesEntityExist(entity) then
        FreezeEntityPosition(entity, false)
        SetEntityCollision(entity, true, true)
    end
end

local function noclipThread()
    CreateThread(function()
        local ped = PlayerPedId()
        local vehicle = nil
        SetEntityInvincible(ped, true)
        SetEntityVisible(ped, not tsivtools.State.invisible, false)
        FreezeEntityPosition(ped, true)
        SetEntityCollision(ped, false, false)

        while tsivtools.State.noclip do
            ped = PlayerPedId()
            local entity = ped
            local current = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or nil
            if current ~= vehicle then
                release(vehicle)
                vehicle = current
            end
            if vehicle then
                entity = vehicle
                FreezeEntityPosition(entity, true)
                SetEntityCollision(entity, false, false)
            end

            local coords = GetEntityCoords(entity)
            local camRotation = GetGameplayCamRot(2)
            local radians = { x = math.rad(camRotation.x), z = math.rad(camRotation.z) }
            local forward = vector3(
                -math.sin(radians.z) * math.abs(math.cos(radians.x)),
                math.cos(radians.z) * math.abs(math.cos(radians.x)),
                math.sin(radians.x))

            local move = vector3(0.0, 0.0, 0.0)

            if IsControlPressed(0, 32) then move = move + forward end
            if IsControlPressed(0, 33) then move = move - forward end
            if IsControlPressed(0, 34) then
                move = move + vector3(-forward.y, forward.x, 0.0)
            end
            if IsControlPressed(0, 35) then
                move = move + vector3(forward.y, -forward.x, 0.0)
            end
            if IsControlPressed(0, 44) then move = move + vector3(0.0, 0.0, 1.0) end
            if IsControlPressed(0, 38) then move = move - vector3(0.0, 0.0, 1.0) end

            local speed = noclipSpeed * GetFrameTime() * 60.0
            if IsControlPressed(0, 21) then speed = speed * 4.0 end
            if IsControlPressed(0, 36) then speed = speed * 0.25 end

            if #move > 0.0 then
                local target = coords + move * speed
                SetEntityCoordsNoOffset(entity, target.x, target.y, target.z, true, true, true)
            end

            SetEntityHeading(ped, camRotation.z)
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            Wait(0)
        end

        ped = PlayerPedId()
        release(vehicle)
        release(ped)
        SetEntityInvincible(ped, tsivtools.State.god)
        SetEntityVisible(ped, not tsivtools.State.invisible, false)

        local coords = GetEntityCoords(ped)
        local found, ground = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, false)
        if found then
            SetEntityCoordsNoOffset(ped, coords.x, coords.y, ground + 1.0, true, true, true)
        end
    end)
end

function tsivtools.ToggleNoclip(state)
    tsivtools.State.noclip = state
    if state then noclipThread() end
    tsivtools.Action('self.state', { key = 'self.noclip', state = state })
end

function tsivtools.SetNoclipSpeed(speed)
    noclipSpeed = speed
end

function tsivtools.ToggleGod(state)
    tsivtools.State.god = state
    SetEntityInvincible(PlayerPedId(), state)
    SetPlayerInvincible(PlayerId(), state)
    tsivtools.Action('self.state', { key = 'self.godmode', state = state })
end

function tsivtools.ToggleInvisible(state)
    tsivtools.State.invisible = state
    SetEntityVisible(PlayerPedId(), not state, false)
    tsivtools.Action('self.state', { key = 'self.invisible', state = state })
end

CreateThread(function()
    while true do
        Wait(2000)
        local ped = PlayerPedId()
        if tsivtools.State.god then
            SetEntityInvincible(ped, true)
            SetPlayerInvincible(PlayerId(), true)
        end
        if tsivtools.State.invisible then
            SetEntityVisible(ped, false, false)
        end
    end
end)

local spectateReturn = nil

local function stopSpectating()
    if not tsivtools.State.spectating then return end

    NetworkSetInSpectatorMode(false, PlayerPedId())
    tsivtools.State.spectating = nil

    local ped = PlayerPedId()
    SetEntityVisible(ped, not tsivtools.State.invisible, false)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)

    if spectateReturn then
        SetEntityCoordsNoOffset(ped, spectateReturn.x, spectateReturn.y, spectateReturn.z, true, true, true)
        spectateReturn = nil
    end

    tsivtools.Notify('Stopped spectating !', 'info')
end

tsivtools.StopSpectating = stopSpectating

local function startSpectating(serverId, name)
    local playerIndex = GetPlayerFromServerId(serverId)
    if playerIndex == -1 then
        tsivtools.Notify('Too far away from player. Teleport nearer first !', 'error')
        return
    end

    local ped = PlayerPedId()
    if not spectateReturn then
        spectateReturn = GetEntityCoords(ped)
    end

    local targetPed = GetPlayerPed(playerIndex)
    local coords = GetEntityCoords(targetPed)

    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z + 2.0, true, true, true)

    NetworkSetInSpectatorMode(true, targetPed)
    tsivtools.State.spectating = serverId

    tsivtools.Notify(('Spectating %s. Press backspace or use Stop Spectating from tsivtools menu to go back !')
        :format(name or serverId), 'info')
end

CreateThread(function()
    while true do
        Wait(1000)
        if tsivtools.State.spectating then
            local playerIndex = GetPlayerFromServerId(tsivtools.State.spectating)
            if playerIndex == -1 then
                tsivtools.Notify('Player too far away !', 'warn')
                stopSpectating()
            else
                local targetPed = GetPlayerPed(playerIndex)
                local coords = GetEntityCoords(targetPed)
                SetEntityCoordsNoOffset(PlayerPedId(), coords.x, coords.y, coords.z + 2.0, true, true, true)
            end
        end
    end
end)

function tsivtools.TeleportTo(x, y, z)
    local ped = PlayerPedId()
    local entity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped

    DoScreenFadeOut(200)
    while not IsScreenFadedOut() do Wait(0) end

    SetEntityCoordsNoOffset(entity, x, y, z, false, false, false)
    RequestCollisionAtCoord(x, y, z)

    local waited = 0
    while not HasCollisionLoadedAroundEntity(entity) and waited < 3000 do
        RequestCollisionAtCoord(x, y, z)
        Wait(50)
        waited = waited + 50
    end

    local found, ground = GetGroundZFor_3dCoord(x, y, z + 10.0, false)
    if found and math.abs(ground - z) < 50.0 then
        SetEntityCoordsNoOffset(entity, x, y, ground + 1.0, false, false, false)
    end

    DoScreenFadeIn(300)
    TriggerEvent('tsivtools:teleported')
end

function tsivtools.TeleportToMarker()
    local waypoint = GetFirstBlipInfoId(8)
    if not DoesBlipExist(waypoint) then
        tsivtools.Notify('You have not set a waypoint!', 'error')
        return
    end

    local coords = GetBlipInfoIdCoord(waypoint)

    local ped = PlayerPedId()
    local entity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped

    DoScreenFadeOut(200)
    while not IsScreenFadedOut() do Wait(0) end

    local groundZ = nil
    for height = 0, 1000, 25 do
        SetEntityCoordsNoOffset(entity, coords.x, coords.y, height + 0.0, false, false, false)
        RequestCollisionAtCoord(coords.x, coords.y, height + 0.0)
        Wait(10)
        local found, z = GetGroundZFor_3dCoord(coords.x, coords.y, height + 0.0, false)
        if found then
            groundZ = z
            break
        end
    end

    if not groundZ then
        groundZ = GetHeightmapTopZForPosition(coords.x, coords.y)
    end

    SetEntityCoordsNoOffset(entity, coords.x, coords.y, groundZ + 1.0, false, false, false)
    DoScreenFadeIn(300)
    TriggerEvent('tsivtools:teleported')
    tsivtools.Notify('Teleported to your waypoint.', 'success')
end

local function spawnVehicle(model, plate)
    local hash = requestModel(model)
    if not hash then
        tsivtools.Notify(('"%s" is incorrect vehicle model!'):format(model), 'error')
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, heading, true, false)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetEntityAsMissionEntity(vehicle, true, true)

    if plate and plate ~= '' then
        SetVehicleNumberPlateText(vehicle, plate)
    end

    SetPedIntoVehicle(ped, vehicle, -1)
    SetModelAsNoLongerNeeded(hash)

    tsivtools.Notify(('vehicle named %s was spawned !'):format(model), 'success')
end

local function currentVehicle()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        return GetVehiclePedIsIn(ped, false)
    end
    local coords = GetEntityCoords(ped)
    local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 6.0, 0, 71)
    if vehicle and vehicle ~= 0 then return vehicle end
    return nil
end

tsivtools.Traffic = { vehicles = false, peds = false, cops = false, boats = false, trains = false }

local trafficRunning = false

local function trafficActive()
    local t = tsivtools.Traffic
    return t.vehicles or t.peds or t.cops or t.boats or t.trains
end

local function startTrafficThread()
    if trafficRunning then return end
    trafficRunning = true

    CreateThread(function()
        while trafficActive() do
            local t = tsivtools.Traffic

            if t.vehicles then
                SetVehicleDensityMultiplierThisFrame(0.0)
                SetRandomVehicleDensityMultiplierThisFrame(0.0)
                SetParkedVehicleDensityMultiplierThisFrame(0.0)
                SetFarDrawVehicles(false)
            end

            if t.peds then
                SetPedDensityMultiplierThisFrame(0.0)
                SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)
            end

            if t.cops then
                SetCreateRandomCops(false)
                SetCreateRandomCopsNotOnScenarios(false)
                SetCreateRandomCopsOnScenarios(false)
            end

            if t.boats then
                SetRandomBoats(false)
                SetGarbageTrucks(false)
            end

            Wait(0)
        end

        trafficRunning = false

        SetCreateRandomCops(true)
        SetCreateRandomCopsNotOnScenarios(true)
        SetCreateRandomCopsOnScenarios(true)
        SetRandomBoats(true)
        SetGarbageTrucks(true)
        SetFarDrawVehicles(true)
    end)
end

function tsivtools.ApplyTraffic(state)
    for key, value in pairs(state or {}) do
        tsivtools.Traffic[key] = value and true or false
    end

    if tsivtools.Traffic.trains ~= nil then
        SetRandomTrains(not tsivtools.Traffic.trains)
    end

    if trafficActive() then
        startTrafficThread()
    end
end

local commands = {}

commands.teleport = function(payload)
    tsivtools.TeleportTo(payload.x, payload.y, payload.z)
end

commands.revive = function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    if IsEntityDead(ped) then
        NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    end

    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    ClearPedTasksImmediately(ped)

    TriggerEvent('tsivtools:revived')
    tsivtools.Notify('You were revived by staff !', 'success')
end

commands.heal = function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 100)
    ClearPedBloodDamage(ped)
    tsivtools.Notify('You were healed by staff !', 'success')
end

commands.slay = function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, 0)
    tsivtools.Notify('You were slain by staff !', 'error')
end

commands.freeze = function(payload)
    local ped = PlayerPedId()
    tsivtools.State.frozen = payload.state and true or false
    FreezeEntityPosition(ped, tsivtools.State.frozen)
    if IsPedInAnyVehicle(ped, false) then
        FreezeEntityPosition(GetVehiclePedIsIn(ped, false), tsivtools.State.frozen)
    end
end

commands.warn = function(payload)
    tsivtools.Chat(('^1[WARNING]^7 from ^3%s^7: %s'):format(payload.by or 'staff', payload.reason or ''))
    tsivtools.Notify('You have been warned by staff ! Please read chat !', 'warn')
    PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', true)
end

commands.spectate = function(payload)
    if payload.stop then
        stopSpectating()
    else
        startSpectating(payload.target, payload.name)
    end
end

commands.spawnVehicle = function(payload)
    spawnVehicle(payload.model, payload.plate)
end

commands.repairVehicle = function()
    local vehicle = currentVehicle()
    if not vehicle then
        tsivtools.Notify('No vehicle nearby !', 'error')
        return
    end
    SetVehicleFixed(vehicle)
    SetVehicleDeformationFixed(vehicle)
    SetVehicleUndriveable(vehicle, false)
    SetVehicleEngineOn(vehicle, true, true, false)
end

commands.refuelVehicle = function()
    local vehicle = currentVehicle()
    if not vehicle then
        tsivtools.Notify('No vehicle nearby !', 'error')
        return
    end
    SetVehicleFuelLevel(vehicle, 100.0)
    if NetworkGetEntityIsNetworked(vehicle) then
        Entity(vehicle).state:set('fuel', 100.0, true)
    end
end

commands.flipVehicle = function()
    local vehicle = currentVehicle()
    if not vehicle then
        tsivtools.Notify('No vehicle nearby !', 'error')
        return
    end
    local roll = GetEntityRoll(vehicle)
    SetVehicleOnGroundProperly(vehicle)
    if math.abs(roll) > 75.0 then
        local coords = GetEntityCoords(vehicle)
        SetEntityCoordsNoOffset(vehicle, coords.x, coords.y, coords.z + 1.0, true, true, true)
        SetEntityRotation(vehicle, 0.0, 0.0, GetEntityHeading(vehicle), 2, true)
    end
end

commands.deleteVehicle = function()
    local entity = tsivtools.RaycastEntity(30.0)
    if not entity or GetEntityType(entity) ~= 2 then
        entity = currentVehicle()
    end
    if not entity then
        tsivtools.Notify('No vehicle found !', 'error')
        return
    end
    if IsPedInAnyVehicle(PlayerPedId(), false) and GetVehiclePedIsIn(PlayerPedId(), false) == entity then
        TaskLeaveVehicle(PlayerPedId(), entity, 16)
        Wait(400)
    end
    tsivtools.DeleteEntityViaServer(entity, 'vehicles')
end

commands.setTraffic = function(payload)
    tsivtools.ApplyTraffic(payload)
end

commands.spawnProp = function(payload)
    local model = payload.model
    local hash = requestModel(model)
    if not hash then
        tsivtools.Notify(('"%s" is not a valid prop model !'):format(tostring(model)), 'error')
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local target = coords + forward * (payload.distance or 2.5)

    local object = CreateObject(hash, target.x, target.y, target.z, true, true, false)
    if object == 0 then
        tsivtools.Notify('The prop could not be created !', 'error')
        SetModelAsNoLongerNeeded(hash)
        return
    end

    SetEntityAsMissionEntity(object, true, true)
    PlaceObjectOnGroundProperly(object)
    FreezeEntityPosition(object, true)
    SetModelAsNoLongerNeeded(hash)

    tsivtools.Notify(('Spawned %s !'):format(model), 'success')
end

RegisterNetEvent(tsivtools.Events.run, function(command, payload)
    local handler = commands[command]
    if not handler then
        tsivtools.Print(('ignored an unknown command from the server: %s'):format(tostring(command)))
        return
    end
    handler(type(payload) == 'table' and payload or {})
end)

tsivtools.Actions.SpawnVehicle = spawnVehicle
tsivtools.Actions.CurrentVehicle = currentVehicle
