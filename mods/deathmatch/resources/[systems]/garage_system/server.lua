-- garage_system/server.lua
-- Handles linked garage access for both legacy embedded garages and standalone garage properties.

local garageZoneMarkers = {}
local garageExitMarkers = {}
local garageOccupants = {}
local garageBlips = {}
local recentEntrants = {}
local GARAGE_EXIT_Z_OFFSET = 0.00

local function debugGarage(player, message)
    if not isElement(player) or getElementType(player) ~= "player" then
        return
    end
    if getElementData(player, "housing:debug") ~= true then
        return
    end
    outputChatBox("[HousingDebug] garage_system: " .. tostring(message), player, 160, 220, 255, true)
end

local function centralQuery(query, ...)
    return exports.database_manager:dbQuery(query, ...) or {}
end

local function isHousingReady()
    local resource = getResourceFromName("housing")
    return resource and getResourceState(resource) == "running"
end

local function isVehiclesReady()
    local resource = getResourceFromName("vehicles")
    return resource and getResourceState(resource) == "running"
end

local function getHouseData(propertyId)
    if not isHousingReady() then
        return nil
    end
    return exports.housing:getHouseData(propertyId)
end

local function getPlayerOwnerKey(player)
    return exports.database_manager:getPlayerOwnerKey(player, true)
end

local function isStandaloneGarage(house)
    return house and house.property_type == "garage"
end

local function hasLegacyGarage(house)
    if not house or isStandaloneGarage(house) then
        return false
    end

    local garage = house.garage or {}
    return (tonumber(garage.x) or 0) ~= 0 or (tonumber(garage.y) or 0) ~= 0 or (tonumber(garage.z) or 0) ~= 0
end

local function getGarageExteriorContext(house)
    if isStandaloneGarage(house) then
        return {
            x = house.exterior_x,
            y = house.exterior_y,
            z = house.exterior_z,
            interior = house.exterior_interior or 0,
            dimension = 0,
            radius = 3.0,
        }
    end

    if hasLegacyGarage(house) then
        return {
            x = house.garage.x,
            y = house.garage.y,
            z = house.garage.z,
            interior = house.exterior_interior or 0,
            dimension = 0,
            radius = tonumber(house.garage.radius) or 3.0,
        }
    end

    return nil
end

local function getGarageInteriorContext(house, propertyId)
    if isStandaloneGarage(house) then
        return {
            x = house.interior_x,
            y = house.interior_y,
            z = house.interior_z,
            rotation = house.interior_rot or 0,
            interior = house.interior_interior or 0,
            dimension = house.dimension or (7000 + propertyId),
            exit_x = house.interior_x,
            exit_y = house.interior_y,
            exit_z = house.interior_z,
        }
    end

    if hasLegacyGarage(house) then
        return {
            x = house.garage_int.x,
            y = house.garage_int.y,
            z = house.garage_int.z,
            rotation = house.garage_int.rotation or 0,
            interior = 0,
            dimension = 7000 + propertyId,
            exit_x = house.garage_int.x,
            exit_y = house.garage_int.y - 3,
            exit_z = house.garage_int.z,
        }
    end

    return nil
end

local function getGarageRuntimeContext(propertyId)
    local house = getHouseData(propertyId)
    if not house then
        return nil
    end

    local exterior = getGarageExteriorContext(house)
    local interior = getGarageInteriorContext(house, propertyId)
    if not exterior or not interior then
        return nil
    end

    return {
        house = house,
        exterior = exterior,
        interior = interior,
    }
end

local function canAccessGarage(player, propertyId)
    if not isHousingReady() then
        return false
    end

    local house = getHouseData(propertyId)
    if not house then
        return false
    end

    if not house.owner_key or house.owner_key == "" then
        return true
    end

    local ownerKey = getPlayerOwnerKey(player)
    if not ownerKey then
        return false
    end

    return exports.housing:checkHouseAccess(propertyId, ownerKey)
end

local function getOccupantCount(propertyId)
    local occupants = garageOccupants[propertyId]
    if not occupants then
        return 0
    end

    local count = 0
    for _ in pairs(occupants) do
        count = count + 1
    end
    return count
end

local function onGarageEntered(propertyId)
    if getOccupantCount(propertyId) == 1 and isVehiclesReady() then
        exports.vehicles:spawnGarageVehicles(propertyId)
    end
end

local function onGarageExited(propertyId)
    if getOccupantCount(propertyId) == 0 and isVehiclesReady() then
        exports.vehicles:despawnGarageVehicles(propertyId)
    end
end

local function movePlayerIntoGarage(player, propertyId)
    local now = getTickCount()
    local lastEnterTick = recentEntrants[player]
    if lastEnterTick and (now - lastEnterTick) < 2000 then
        return
    end

    local context = getGarageRuntimeContext(propertyId)
    if not context then
        return
    end

    recentEntrants[player] = now

    garageOccupants[propertyId] = garageOccupants[propertyId] or {}
    garageOccupants[propertyId][player] = true

    setElementInterior(player, context.interior.interior)
    setElementDimension(player, context.interior.dimension)
    setElementPosition(player, context.interior.x, context.interior.y, context.interior.z)
    setPedRotation(player, context.interior.rotation)
    setElementData(player, "garage:inside", propertyId)

    outputChatBox("Garage: entered " .. context.house.name .. ". Use /exitgarage to leave.", player, 120, 200, 255, true)
    onGarageEntered(propertyId)
end

local function movePlayerOutOfGarage(player, propertyId)
    local context = getGarageRuntimeContext(propertyId)
    if not context then
        return
    end

    if garageOccupants[propertyId] then
        garageOccupants[propertyId][player] = nil
    end

    setElementInterior(player, context.exterior.interior)
    setElementDimension(player, context.exterior.dimension)
    setElementPosition(player, context.exterior.x, context.exterior.y, context.exterior.z + GARAGE_EXIT_Z_OFFSET)
    setPedRotation(player, tonumber(context.house.exterior_rot) or 0)
    setElementData(player, "garage:inside", false)

    outputChatBox("Garage: exited " .. context.house.name .. ".", player, 120, 200, 255, true)
    onGarageExited(propertyId)
end

local function getNearbyGarageEntryPropertyId(player)
    for marker, propertyId in pairs(garageZoneMarkers) do
        if isElement(marker) and isElementWithinMarker(player, marker)
            and getElementDimension(player) == getElementDimension(marker)
            and getElementInterior(player) == getElementInterior(marker) then
            return propertyId
        end
    end

    return nil
end

local function getNearbyGarageExitPropertyId(player)
    for marker, propertyId in pairs(garageExitMarkers) do
        if isElement(marker) and isElementWithinMarker(player, marker)
            and getElementDimension(player) == getElementDimension(marker)
            and getElementInterior(player) == getElementInterior(marker) then
            return propertyId
        end
    end

    return nil
end

local function getGaragePropertyByPlayer(player)
    local propertyId = tonumber(getElementData(player, "garage:inside"))
    if not propertyId then
        return nil
    end

    if garageOccupants[propertyId] and garageOccupants[propertyId][player] then
        return propertyId
    end

    return nil
end

local function destroyGarageElements()
    for marker in pairs(garageZoneMarkers) do
        if isElement(marker) then
            destroyElement(marker)
        end
    end
    for marker in pairs(garageExitMarkers) do
        if isElement(marker) then
            destroyElement(marker)
        end
    end
    for blip in pairs(garageBlips) do
        if isElement(blip) then
            destroyElement(blip)
        end
    end

    garageZoneMarkers = {}
    garageExitMarkers = {}
    garageBlips = {}
end

local function buildGarageElements()
    if not isHousingReady() then
        setTimer(function()
            if isHousingReady() then
                buildGarageElements()
            end
        end, 2000, 1)
        return
    end

    destroyGarageElements()

    local rows = centralQuery([[
        SELECT id
        FROM houses
        WHERE property_type = 'garage'
           OR garage_x != 0
           OR garage_y != 0
           OR garage_z != 0
        ORDER BY id ASC
    ]])

    for _, row in ipairs(rows) do
        local propertyId = tonumber(row.id)
        local context = propertyId and getGarageRuntimeContext(propertyId) or nil
        if context then
            local entryMarker = createMarker(
                context.exterior.x,
                context.exterior.y,
                context.exterior.z - 0.3,
                "cylinder",
                context.exterior.radius,
                80,
                120,
                255,
                100
            )
            setElementInterior(entryMarker, context.exterior.interior)
            setElementDimension(entryMarker, context.exterior.dimension)
            setElementData(entryMarker, "garage:houseId", propertyId, false)
            setElementData(entryMarker, "garage:markerType", "entry", false)
            setElementParent(entryMarker, resourceRoot)
            garageZoneMarkers[entryMarker] = propertyId

            local exitMarker = createMarker(
                context.interior.exit_x,
                context.interior.exit_y,
                context.interior.exit_z - 0.3,
                "arrow",
                1.5,
                255,
                60,
                60,
                150
            )
            setElementInterior(exitMarker, context.interior.interior)
            setElementDimension(exitMarker, context.interior.dimension)
            setElementData(exitMarker, "garage:houseId", propertyId, false)
            setElementData(exitMarker, "garage:markerType", "exit", false)
            setElementParent(exitMarker, resourceRoot)
            garageExitMarkers[exitMarker] = propertyId

            local blip = createBlip(context.exterior.x, context.exterior.y, context.exterior.z, 55, 1, 80, 120, 255, 200, 0, 150)
            setElementInterior(blip, context.exterior.interior)
            setElementDimension(blip, context.exterior.dimension)
            setElementParent(blip, resourceRoot)
            garageBlips[blip] = propertyId
        end
    end
end

addCommandHandler("parkgarage", function(player)
    local propertyId = getGaragePropertyByPlayer(player)
    if not propertyId then
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

    exports.vehicles:parkVehicle(player, propertyId)
end)

addCommandHandler("exitgarage", function(player)
    local propertyId = getGaragePropertyByPlayer(player)
    if not propertyId then
        outputChatBox("Garage: you are not inside a garage.", player, 255, 80, 80, true)
        return
    end

    movePlayerOutOfGarage(player, propertyId)
end)

addEventHandler("onMarkerHit", resourceRoot, function(hitElement, matchingDimension)
    if not matchingDimension or getElementType(hitElement) ~= "player" then
        return
    end

    local player = hitElement

    local entryPropertyId = garageZoneMarkers[source]
    if entryPropertyId then
        local context = getGarageRuntimeContext(entryPropertyId)
        if context then
            debugGarage(player, string.format(
                "garage entry marker hit property=%d exterior=(%.2f, %.2f, %.2f) interior=(%.2f, %.2f, %.2f)",
                tonumber(entryPropertyId) or 0,
                tonumber(context.exterior.x) or 0,
                tonumber(context.exterior.y) or 0,
                tonumber(context.exterior.z) or 0,
                tonumber(context.interior.x) or 0,
                tonumber(context.interior.y) or 0,
                tonumber(context.interior.z) or 0
            ))
        end

        if getElementData(player, "garage:inside") then
            return
        end

        if not canAccessGarage(player, entryPropertyId) then
            outputChatBox("Garage: buy or unlock this garage before entering it.", player, 255, 80, 80, true)
            return
        end

        movePlayerIntoGarage(player, entryPropertyId)
        return
    end

    local exitPropertyId = garageExitMarkers[source]
    if exitPropertyId then
        local context = getGarageRuntimeContext(exitPropertyId)
        if context then
            debugGarage(player, string.format(
                "garage exit marker hit property=%d exit=(%.2f, %.2f, %.2f) exterior=(%.2f, %.2f, %.2f)",
                tonumber(exitPropertyId) or 0,
                tonumber(context.interior.exit_x) or 0,
                tonumber(context.interior.exit_y) or 0,
                tonumber(context.interior.exit_z) or 0,
                tonumber(context.exterior.x) or 0,
                tonumber(context.exterior.y) or 0,
                tonumber(context.exterior.z) or 0
            ))
        end
        movePlayerOutOfGarage(player, exitPropertyId)
    end
end)

addEventHandler("onPlayerQuit", root, function()
    local player = source
    for propertyId, occupants in pairs(garageOccupants) do
        if occupants[player] then
            occupants[player] = nil
            onGarageExited(propertyId)
        end
    end
end)

addEvent("garage:requestEnter", true)
addEventHandler("garage:requestEnter", root, function(requestedPropertyId)
    local player = client
    if not isElement(player) or getElementType(player) ~= "player" or isPedInVehicle(player) then
        return
    end

    if getElementData(player, "garage:inside") then
        return
    end

    local propertyId = getNearbyGarageEntryPropertyId(player)
    if not propertyId then
        return
    end

    if requestedPropertyId and tonumber(requestedPropertyId) and tonumber(requestedPropertyId) ~= tonumber(propertyId) then
        debugGarage(player, "requestEnter ignored mismatched client property id.")
    end

    movePlayerIntoGarage(player, propertyId)
end)

addEvent("garage:requestExit", true)
addEventHandler("garage:requestExit", root, function(requestedPropertyId)
    local player = client
    if not isElement(player) or getElementType(player) ~= "player" or isPedInVehicle(player) then
        return
    end

    local propertyId = getNearbyGarageExitPropertyId(player)
    if not propertyId then
        return
    end

    if requestedPropertyId and tonumber(requestedPropertyId) and tonumber(requestedPropertyId) ~= tonumber(propertyId) then
        debugGarage(player, "requestExit ignored mismatched client property id.")
    end

    movePlayerOutOfGarage(player, propertyId)
end)

addEventHandler("onResourceStart", resourceRoot, function()
    setTimer(buildGarageElements, 1500, 1)
end)

addEventHandler("onResourceStop", resourceRoot, function()
    destroyGarageElements()

    for propertyId, occupants in pairs(garageOccupants) do
        for player in pairs(occupants) do
            if isElement(player) then
                local context = getGarageRuntimeContext(propertyId)
                if context then
                    setElementInterior(player, context.exterior.interior)
                    setElementDimension(player, context.exterior.dimension)
                    setElementPosition(player, context.exterior.x, context.exterior.y, context.exterior.z + GARAGE_EXIT_Z_OFFSET)
                end
                setElementData(player, "garage:inside", false)
            end
        end
    end

    garageOccupants = {}
end)

addEventHandler("onResourceStart", root, function(startedResource)
    if getResourceName(startedResource) == "housing" then
        setTimer(buildGarageElements, 1500, 1)
    end
end)
