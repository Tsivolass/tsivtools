

TSIV.Actions = {}

local pendingRequests = {}
local nextRequestId = 0


function TSIV.Action(name, payload)
    TriggerServerEvent(TSIV.Events.action, name, payload or {})
end

function TSIV.Request(name, payload, timeout)
    nextRequestId = nextRequestId + 1
    local requestId = nextRequestId

    pendingRequests[requestId] = { done = false, result = nil }
    TriggerServerEvent(TSIV.Events.request, name, requestId, payload or {})

    local waited = 0
    timeout = timeout or 8000
    while not pendingRequests[requestId].done and waited < timeout do
        Wait(25)
        waited = waited + 25
    end

    local entry = pendingRequests[requestId]
    pendingRequests[requestId] = nil

    if not entry.done then
        TSIV.Notify('The server did not answer in time !', 'error')
        return nil
    end

    return entry.result
end

RegisterNetEvent(TSIV.Events.response, function(requestId, result)
    local entry = pendingRequests[requestId]
    if not entry then return end
    entry.result = result
    entry.done = true
end)

function TSIV.ShowBlock(block, emptyMessage)
    if not block then
        TSIV.Notify(emptyMessage or 'Nothing came back !', 'error')
        return
    end
    TSIV.PrintBlock(block.title or 'tsivtools', block.lines or {})
    TSIV.Notify('Printed results to console !', 'success')
end



TSIV.State = {
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


function TSIV.RaycastEntity(distance)
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

function TSIV.ClosestObject(maxDistance)
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


function TSIV.DeleteEntityViaServer(entity, kind)
    if not entity or not DoesEntityExist(entity) then
        TSIV.Notify('Nothing there to delete.', 'error')
        return
    end

    if not NetworkGetEntityIsNetworked(entity) then
        SetEntityAsMissionEntity(entity, true, true)
        DeleteEntity(entity)
        TSIV.Notify('Deleted a local entity !', 'success')
        return
    end

    TSIV.Action('entity.deleteNearest', {
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
        SetEntityVisible(ped, not TSIV.State.invisible, false)
        FreezeEntityPosition(ped, true)
        SetEntityCollision(ped, false, false)

        while TSIV.State.noclip do
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
        SetEntityInvincible(ped, TSIV.State.god)
        SetEntityVisible(ped, not TSIV.State.invisible, false)

        local coords = GetEntityCoords(ped)
        local found, ground = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, false)
        if found then
            SetEntityCoordsNoOffset(ped, coords.x, coords.y, ground + 1.0, true, true, true)
        end
    end)
end

function TSIV.ToggleNoclip(state)
    TSIV.State.noclip = state
    if state then noclipThread() end
    TSIV.Action('self.state', { key = 'self.noclip', state = state })
end

function TSIV.SetNoclipSpeed(speed)
    noclipSpeed = speed
end


function TSIV.ToggleGod(state)
    TSIV.State.god = state
    SetEntityInvincible(PlayerPedId(), state)
    SetPlayerInvincible(PlayerId(), state)
    TSIV.Action('self.state', { key = 'self.godmode', state = state })
end

function TSIV.ToggleInvisible(state)
    TSIV.State.invisible = state
    SetEntityVisible(PlayerPedId(), not state, false)
    TSIV.Action('self.state', { key = 'self.invisible', state = state })
end

CreateThread(function()
    while true do
        Wait(2000)
        local ped = PlayerPedId()
        if TSIV.State.god then
            SetEntityInvincible(ped, true)
            SetPlayerInvincible(PlayerId(), true)
        end
        if TSIV.State.invisible then
            SetEntityVisible(ped, false, false)
        end
    end
end)


local spectateReturn = nil

local function stopSpectating()
    if not TSIV.State.spectating then return end

    NetworkSetInSpectatorMode(false, PlayerPedId())
    TSIV.State.spectating = nil

    local ped = PlayerPedId()
    SetEntityVisible(ped, not TSIV.State.invisible, false)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)

    if spectateReturn then
        SetEntityCoordsNoOffset(ped, spectateReturn.x, spectateReturn.y, spectateReturn.z, true, true, true)
        spectateReturn = nil
    end

    TSIV.Notify('Stopped spectating !', 'info')
end

TSIV.StopSpectating = stopSpectating

local function startSpectating(serverId, name)
    local playerIndex = GetPlayerFromServerId(serverId)
    if playerIndex == -1 then
        TSIV.Notify('Too far away from player. Teleport nearer first !', 'error')
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
    TSIV.State.spectating = serverId

    TSIV.Notify(('Spectating %s. Press backspace or use Stop Spectating from tsivtools menu to go back !')
        :format(name or serverId), 'info')
end

CreateThread(function()
    while true do
        Wait(1000)
        if TSIV.State.spectating then
            local playerIndex = GetPlayerFromServerId(TSIV.State.spectating)
            if playerIndex == -1 then
                TSIV.Notify('Player too far away !', 'warn')
                stopSpectating()
            else
                local targetPed = GetPlayerPed(playerIndex)
                local coords = GetEntityCoords(targetPed)
                SetEntityCoordsNoOffset(PlayerPedId(), coords.x, coords.y, coords.z + 2.0, true, true, true)
            end
        end
    end
end)


function TSIV.TeleportTo(x, y, z)
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

function TSIV.TeleportToMarker()
    local waypoint = GetFirstBlipInfoId(8)
    if not DoesBlipExist(waypoint) then
        TSIV.Notify('You have not set a waypoint!', 'error')
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
    TSIV.Notify('Teleported to your waypoint.', 'success')
end



local function spawnVehicle(model, plate)
    local hash = requestModel(model)
    if not hash then
        TSIV.Notify(('"%s" is incorrect vehicle model!'):format(model), 'error')
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

    TSIV.Notify(('vehicle named %s was spawned !'):format(model), 'success')
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



local commands = {}

commands.teleport = function(payload)
    TSIV.TeleportTo(payload.x, payload.y, payload.z)
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
    TSIV.Notify('You were revived by staff !', 'success')
end

commands.heal = function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 100)
    ClearPedBloodDamage(ped)
    TSIV.Notify('You were healed by staff !', 'success')
end

commands.slay = function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, 0)
    TSIV.Notify('You were slain by staff !', 'error')
end

commands.freeze = function(payload)
    local ped = PlayerPedId()
    TSIV.State.frozen = payload.state and true or false
    FreezeEntityPosition(ped, TSIV.State.frozen)
    if IsPedInAnyVehicle(ped, false) then
        FreezeEntityPosition(GetVehiclePedIsIn(ped, false), TSIV.State.frozen)
    end
end

commands.warn = function(payload)
    TSIV.Chat(('^1[WARNING]^7 from ^3%s^7: %s'):format(payload.by or 'staff', payload.reason or ''))
    TSIV.Notify('You have been warned by staff ! Please read chat !', 'warn')
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
        TSIV.Notify('No vehicle nearby !', 'error')
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
        TSIV.Notify('No vehicle nearby !', 'error')
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
        TSIV.Notify('No vehicle nearby !', 'error')
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
    local entity = TSIV.RaycastEntity(30.0)
    if not entity or GetEntityType(entity) ~= 2 then
        entity = currentVehicle()
    end
    if not entity then
        TSIV.Notify('No vehicle found !', 'error')
        return
    end
    if IsPedInAnyVehicle(PlayerPedId(), false) and GetVehiclePedIsIn(PlayerPedId(), false) == entity then
        TaskLeaveVehicle(PlayerPedId(), entity, 16)
        Wait(400)
    end
    TSIV.DeleteEntityViaServer(entity, 'vehicles')
end

RegisterNetEvent(TSIV.Events.run, function(command, payload)
    local handler = commands[command]
    if not handler then
        -- An unknown command means the server is a version ahead of the client,
        -- or something is trying to drive this client that should not be.
        TSIV.Print(('ignored an unknown command from the server: %s'):format(tostring(command)))
        return
    end
    handler(type(payload) == 'table' and payload or {})
end)

TSIV.Actions.SpawnVehicle = spawnVehicle
TSIV.Actions.CurrentVehicle = currentVehicle
