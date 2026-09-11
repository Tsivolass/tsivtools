--[[
    tsivtools - client checks

    Cheap sanity checks that run on the player's own machine and report back.
    A client can lie about all of this, so nothing here bans anybody by itself:
    every result arrives at the server as an alert for staff to look at.

    Turn the whole thing off with Config.AntiCheat.client.enabled = false.
]]

local settings = Config.AntiCheat.client
local blacklistedWeapons = {}

for _, weapon in ipairs(settings.blacklistedWeapons or {}) do
    blacklistedWeapons[#blacklistedWeapons + 1] = { name = weapon, hash = GetHashKey(weapon) }
end

local function report(kind, detail)
    TriggerServerEvent(TSIV.Events.report, kind, detail)
end

-- ---------------------------------------------------------------------------
-- Checks
-- ---------------------------------------------------------------------------

local lastCoords = nil
local lastCheck = 0

local function speedCheck(ped)
    local now = GetGameTimer()
    local coords = GetEntityCoords(ped)

    if lastCoords and lastCheck > 0 then
        local elapsed = (now - lastCheck) / 1000.0
        if elapsed > 0.1 then
            local travelled = #(coords - lastCoords)
            local speed = travelled / elapsed

            -- Only meaningful on foot and on the ground. A vehicle, a fall, a
            -- parachute or a legitimate teleport all produce large numbers.
            local onFoot = not IsPedInAnyVehicle(ped, true)
                and not IsPedFalling(ped)
                and not IsPedInParachuteFreeFall(ped)
                and not IsPedRagdoll(ped)
                and not IsPedSwimming(ped)

            if onFoot and speed > settings.speedThreshold and travelled < 200.0 then
                report('speed', ('%.1f m/s on foot (threshold %.1f)'):format(speed, settings.speedThreshold))
            end
        end
    end

    lastCoords = coords
    lastCheck = now
end

local function healthCheck(ped)
    local health = GetEntityHealth(ped)
    local armour = GetPedArmour(ped)

    if health > settings.maxHealth then
        report('health', ('health is %d, maximum is %d'):format(health, settings.maxHealth))
    end
    if armour > settings.maxArmour then
        report('armour', ('armour is %d, maximum is %d'):format(armour, settings.maxArmour))
    end
end

local function weaponCheck(ped)
    for _, weapon in ipairs(blacklistedWeapons) do
        if HasPedGotWeapon(ped, weapon.hash, false) then
            RemoveWeaponFromPed(ped, weapon.hash)
            report('weapon', ('carrying %s'):format(weapon.name))
        end
    end
end

-- ---------------------------------------------------------------------------
-- Loop
-- ---------------------------------------------------------------------------

CreateThread(function()
    if not Config.AntiCheat.enabled or not settings.enabled then return end

    -- Give the player time to spawn in before the first check, otherwise the
    -- initial spawn teleport reads as a speed violation.
    Wait(30000)

    while true do
        Wait((settings.interval or 5) * 1000)

        local ped = PlayerPedId()
        if DoesEntityExist(ped) and not IsEntityDead(ped) then
            if settings.speedCheck then speedCheck(ped) end
            if settings.healthCheck then healthCheck(ped) end
            if settings.weaponCheck then weaponCheck(ped) end
        else
            -- Reset the speed baseline while dead, so the respawn does not
            -- count as movement.
            lastCoords = nil
            lastCheck = 0
        end
    end
end)

-- A teleport performed by tsivtools itself must not trip the speed check.
AddEventHandler('tsivtools:teleported', function()
    lastCoords = nil
    lastCheck = 0
end)
