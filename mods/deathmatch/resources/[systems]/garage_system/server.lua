-- garage_system/server.lua
-- Manages garage entry, interior dimension teleport, and on-demand vehicle spawning.
-- Each property's garage uses dimension 7000 + house_id.
-- Players enter the garage exterior zone → teleported into garage interior dimension.
-- When they leave the dimension, vehicles despawn.

-- ───────────────────────────────────────────────────────────────
-- STATE
-- ───────────────────────────────────────────────────────────────
local garageZoneMarkers = {}   -- marker element → house_id
local garageExitMarkers = {}   -- marker element → house_id  (inside garage)
local garageOccupants   = {}   -- house_id → { player_element, ... }
local garageBlips       = {}   -- blip element → house_id

-- ───────────────────────────────────────────────────────────────
-- HELPERS
-- ───────────────────────────────────────────────────────────────
local function isHousingReady()
    local r = getResourceFromName("housing")
    return r and getResourceState(r) == "running"
end

local function isVehiclesReady()
    local r = getResourceFromName("vehicles")
    return r and getResourceState(r) == "running"
end

local function getHouseData(houseId)
    if not isHousingReady() then return nil end
    return exports.housing:getHouseData(houseId)
end

local function getPlayerOwnerKey(player)
    return exports.database_manager:getPlayerOwnerKey(player, true)
end

local function canAccessGarage(player, houseId)
    local ownerKey = getPlayerOwnerKey(player)
    if not ownerKey then return false end
    if not isHousingReady() then return false end
    return exports.housing:checkHouseAccess(houseId, ownerKey)
end

local function garageDimension(houseId)
    return 7000 + houseId
end

local function getOccupantCount(houseId)
    local occupants = garageOccupants[houseId]
    if not occupants then return 0 end
    local count = 0
    for _ in pairs(occupants) do count = count + 1 end
    return count
end

-- ───────────────────────────────────────────────────────────────
-- VEHICLE MANAGEMENT
-- ───────────────────────────────────────────────────────────────
local function onGarageEntered(houseId)
    -- First occupant entering: spawn garage vehicles
    if getOccupantCount(houseId) == 1 and isVehiclesReady() then
        exports.vehicles:spawnGarageVehicles(houseId)
        -- Teleport spawned vehicles to garage interior dimension
        local house = getHouseData(houseId)
        if house then
            local garageDim = garageDimension(houseId)
            for _, vehicle in ipairs(getElementsByType("vehicle")) do
                if getElementDimension(vehicle) == garageDim then
                    -- vehicle already in this dimension (freshly spawned with correct dim from DB)
                    -- do nothing; spawnGarageVehicles sets dimension from DB record
                end
            end
        end
    end
end

local function onGarageExited(houseId)
    -- Last occupant leaving: despawn garage vehicles
    if getOccupantCount(houseId) == 0 and isVehiclesReady() then
        exports.vehicles:despawnGarageVehicles(houseId)
    end
end

-- ───────────────────────────────────────────────────────────────
-- TELEPORT
-- ───────────────────────────────────────────────────────────────
local function movePlayerIntoGarage(player, houseId)
    local house = getHouseData(houseId)
    if not house then return end

    local garageDim = garageDimension(houseId)

    -- Register as occupant
    if not garageOccupants[houseId] then
        garageOccupants[houseId] = {}
    end
    garageOccupants[houseId][player] = true

    local gx = house.garage_int and house.garage_int.x or house.garage_int_x
    local gy = house.garage_int and house.garage_int.y or house.garage_int_y
    local gz = house.garage_int and house.garage_int.z or house.garage_int_z
    local grot = house.garage_int and house.garage_int.rotation or house.garage_int_rot

    setElementInterior(player, 0)
    setElementDimension(player, garageDim)
    setElementPosition(player, gx, gy, gz)
    setPedRotation(player, grot)

    outputChatBox("Garage: entered " .. house.name .. " garage. Use /exitgarage to leave.", player, 120, 200, 255, true)

    onGarageEntered(houseId)
end

local function movePlayerOutOfGarage(player, houseId)
    local house = getHouseData(houseId)
    if not house then return end

    -- Deregister occupant
    if garageOccupants[houseId] then
        garageOccupants[houseId][player] = nil
    end

    local gx = house.garage and house.garage.x or house.garage_x
    local gy = house.garage and house.garage.y or house.garage_y
    local gz = house.garage and house.garage.z or house.garage_z
    local eint = house.exterior and house.exterior.interior or house.exterior_interior or 0

    setElementInterior(player, eint)
    setElementDimension(player, 0)
    setElementPosition(player, gx, gy, gz)
    setPedRotation(player, 0)

    outputChatBox("Garage: exited " .. house.name .. " garage.", player, 120, 200, 255, true)

    onGarageExited(houseId)
end

local function getGarageHouseByPlayer(player)
    local dim = getElementDimension(player)
    if dim < 7001 then return nil end
    local houseId = dim - 7000
    if garageOccupants[houseId] and garageOccupants[houseId][player] then
        return houseId
    end
    return nil
end

-- ───────────────────────────────────────────────────────────────
-- ZONE MARKERS (exterior entry zone)
-- ───────────────────────────────────────────────────────────────
local function destroyGarageElements()
    for marker in pairs(garageZoneMarkers) do
        if isElement(marker) then destroyElement(marker) end
    end
    for marker in pairs(garageExitMarkers) do
        if isElement(marker) then destroyElement(marker) end
    end
    for blip in pairs(garageBlips) do
        if isElement(blip) then destroyElement(blip) end
    end
    garageZoneMarkers = {}
    garageExitMarkers = {}
    garageBlips       = {}
end

local function buildGarageElements()
    if not isHousingReady() then
        setTimer(function()
            if isHousingReady() then buildGarageElements() end
        end, 2000, 1)
        return
    end

    destroyGarageElements()

    -- Iterate all house IDs 1..30
    for houseId = 1, 30 do
        local house = getHouseData(houseId)
        if house then
            local gx = house.garage and house.garage.x or house.garage_x
            local gy = house.garage and house.garage.y or house.garage_y
            local gz = house.garage and house.garage.z or house.garage_z

            if gx and gy and gz then
                -- Exterior entry marker (on world)
                local entryMarker = createMarker(
                    gx, gy, gz - 1,
                    "cylinder", 3.0, 80, 120, 255, 100
                )
                local eint = house.exterior and house.exterior.interior or house.exterior_interior or 0
                setElementInterior(entryMarker, eint)
                setElementDimension(entryMarker, 0)
                setElementData(entryMarker, "garage:houseId", houseId, false)
                setElementParent(entryMarker, resourceRoot)
                garageZoneMarkers[entryMarker] = houseId

                -- Garage interior exit marker (inside garage dimension)
                local garageDim = garageDimension(houseId)
                local gix = house.garage_int and house.garage_int.x or house.garage_int_x
                local giy = house.garage_int and house.garage_int.y or house.garage_int_y
                local giz = house.garage_int and house.garage_int.z or house.garage_int_z
                local exitMx = gix
                local exitMy = giy - 3  -- slightly behind spawn point
                local exitMz = giz - 1

                local exitMarker = createMarker(exitMx, exitMy, exitMz, "arrow", 1.5, 255, 60, 60, 150)
                setElementInterior(exitMarker, 0)
                setElementDimension(exitMarker, garageDim)
                setElementData(exitMarker, "garage:houseId", houseId, false)
                setElementParent(exitMarker, resourceRoot)
                garageExitMarkers[exitMarker] = houseId

                -- Blip for the garage
                local blip = createBlip(gx, gy, gz, 55, 1, 80, 120, 255, 200, 0, 150)
                setElementInterior(blip, eint)
                setElementDimension(blip, 0)
                setElementParent(blip, resourceRoot)
                garageBlips[blip] = houseId
            end
        end
    end
end

-- ───────────────────────────────────────────────────────────────
-- PARK VEHICLE IN GARAGE
-- ───────────────────────────────────────────────────────────────
addCommandHandler("parkgarage", function(player)
    local houseId = getGarageHouseByPlayer(player)
    if not houseId then
        outputChatBox("Garage: you are not inside a garage.", player, 255, 80, 80, true)
        return
    end

    if not isPedInVehicle(player) or getPedOccupiedVehicleSeat(player) ~= 0 then
        outputChatBox("Garage: you must be the driver of a vehicle to park it.", player, 255, 80, 80, true)
        return
    end

    if not isVehiclesReady() then
        outputChatBox("Garage: vehicle system is not running.", player, 255, 80, 80, true)
        return
    end

    -- Call the vehicles resource directly (server→server export)
    exports.vehicles:parkVehicle(player, houseId)
end)

-- ───────────────────────────────────────────────────────────────
-- EXIT COMMAND
-- ───────────────────────────────────────────────────────────────
addCommandHandler("exitgarage", function(player)
    local houseId = getGarageHouseByPlayer(player)
    if not houseId then
        outputChatBox("Garage: you are not inside a garage.", player, 255, 80, 80, true)
        return
    end

    movePlayerOutOfGarage(player, houseId)
end)

-- ───────────────────────────────────────────────────────────────
-- MARKER EVENTS
-- ───────────────────────────────────────────────────────────────
addEventHandler("onMarkerHit", resourceRoot, function(hitElement, matchingDimension)
    if not matchingDimension or getElementType(hitElement) ~= "player" then return end
    local player = hitElement

    -- Entry marker (exterior)
    local entryHouseId = garageZoneMarkers[source]
    if entryHouseId then
        -- Don't teleport if already in a garage
        if getElementDimension(player) ~= 0 then return end

        if not canAccessGarage(player, entryHouseId) then
            outputChatBox("Garage: this garage is locked. You need a property key.", player, 255, 80, 80, true)
            return
        end

        movePlayerIntoGarage(player, entryHouseId)
        return
    end

    -- Exit marker (inside garage dimension)
    local exitHouseId = garageExitMarkers[source]
    if exitHouseId then
        movePlayerOutOfGarage(player, exitHouseId)
        return
    end
end)

-- ───────────────────────────────────────────────────────────────
-- CLEANUP ON QUIT/DISCONNECT
-- ───────────────────────────────────────────────────────────────
addEventHandler("onPlayerQuit", root, function()
    local player = source
    for houseId, occupants in pairs(garageOccupants) do
        if occupants[player] then
            occupants[player] = nil
            onGarageExited(houseId)
        end
    end
end)

-- ───────────────────────────────────────────────────────────────
-- RESOURCE EVENTS
-- ───────────────────────────────────────────────────────────────
addEventHandler("onResourceStart", resourceRoot, function()
    -- Wait briefly for housing to finish loading its houses
    setTimer(buildGarageElements, 1500, 1)
end)

addEventHandler("onResourceStop", resourceRoot, function()
    destroyGarageElements()

    -- Remove all players from garages
    for houseId, occupants in pairs(garageOccupants) do
        for player in pairs(occupants) do
            if isElement(player) then
                local house = getHouseData(houseId)
                if house then
                    local eint = house.exterior and house.exterior.interior or house.exterior_interior or 0
                    local gx = house.garage and house.garage.x or house.garage_x
                    local gy = house.garage and house.garage.y or house.garage_y
                    local gz = house.garage and house.garage.z or house.garage_z
                    
                    setElementInterior(player, eint)
                    setElementDimension(player, 0)
                    if gx and gy and gz then
                        setElementPosition(player, gx, gy, gz)
                    end
                end
            end
        end
    end

    garageOccupants = {}
end)

-- Re-build if housing restarts
addEventHandler("onResourceStart", root, function(startedResource)
    if getResourceName(startedResource) == "housing" then
        setTimer(buildGarageElements, 1500, 1)
    end
end)
