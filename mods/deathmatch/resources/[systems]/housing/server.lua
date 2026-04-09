local legacyDbConnect = dbConnect
local legacyDbPoll = dbPoll
local legacyDbQuery = dbQuery

local houseDefinitions = {
    {
        id = 1,
        name = "Ganton Safehouse",
        price = 50000,
        exterior = { x = 2495.33, y = -1690.75, z = 13.78, rotation = 180, interior = 0 },
        interior = { x = 2496.05, y = -1692.73, z = 1013.75, rotation = 0, interior = 3 },
        garage = { x = 2495.33, y = -1684.90, z = 13.78, radius = 11 },
    },
    {
        id = 2,
        name = "East Los Santos House",
        price = 42000,
        exterior = { x = 2402.52, y = -1715.28, z = 14.13, rotation = 180, interior = 0 },
        interior = { x = 243.75, y = 304.82, z = 999.14, rotation = 270, interior = 1 },
        garage = { x = 2398.50, y = -1710.80, z = 13.80, radius = 11 },
    },
    {
        id = 3,
        name = "Rodeo Apartment",
        price = 62000,
        exterior = { x = -382.67, y = -1438.83, z = 26.12, rotation = 270, interior = 0 },
        interior = { x = 292.89, y = 309.90, z = 999.15, rotation = 90, interior = 3 },
        garage = { x = -376.90, y = -1438.83, z = 25.90, radius = 10 },
    },
    {
        id = 4,
        name = "San Fierro Condo",
        price = 70000,
        exterior = { x = -1800.21, y = 1200.576, z = 25.119, rotation = 180, interior = 0 },
        interior = { x = 300.239, y = 300.584, z = 999.15, rotation = 0, interior = 4 },
        garage = { x = -1795.10, y = 1204.80, z = 24.80, radius = 11 },
    },
    {
        id = 5,
        name = "Tierra Robada House",
        price = 55000,
        exterior = { x = -1390.186, y = 2638.72, z = 55.98, rotation = 180, interior = 0 },
        interior = { x = 322.25, y = 302.42, z = 999.15, rotation = 0, interior = 5 },
        garage = { x = -1385.40, y = 2644.20, z = 55.80, radius = 11 },
    },
    {
        id = 6,
        name = "Las Venturas House",
        price = 78000,
        exterior = { x = 2037.22, y = 2721.81, z = 11.29, rotation = 0, interior = 0 },
        interior = { x = 343.74, y = 305.03, z = 999.15, rotation = 180, interior = 6 },
        garage = { x = 2044.20, y = 2722.10, z = 10.90, radius = 12 },
    },
}

local houses = {}
local purchasePickups = {}
local exitMarkers = {}
local houseBlips = {}

local function centralExecute(queryText, ...)
    return exports.database_manager:dbExecute(queryText, ...)
end

local function centralQuery(queryText, ...)
    return exports.database_manager:dbQuery(queryText, ...) or {}
end

local function formatMoney(amount)
    return "$" .. tostring(math.floor(tonumber(amount) or 0))
end

local function getAccountOwnerKey(player)
    return exports.database_manager:getPlayerOwnerKey(player, true)
end

local function getAccountNameFromOwnerKey(ownerKey)
    ownerKey = tostring(ownerKey or "")
    if ownerKey:sub(1, 8) == "account:" then
        return ownerKey:sub(9)
    end

    return nil
end

local function isVehiclesResourceRunning()
    local vehiclesResource = getResourceFromName("vehicles")
    return vehiclesResource and getResourceState(vehiclesResource) == "running"
end

local function pushGarageLockState(house)
    if not house or not isVehiclesResourceRunning() then
        return
    end

    exports.vehicles:setGarageVehiclesLocked(house.id, house.locked)
end

local function seedHouses()
    for _, definition in ipairs(houseDefinitions) do
        local dimension = 6000 + definition.id
        centralExecute([[
            INSERT OR IGNORE INTO houses (
                id, name, price, owner_key, owner_account, locked,
                exterior_x, exterior_y, exterior_z, exterior_rot, exterior_interior,
                interior_x, interior_y, interior_z, interior_rot, interior_id, dimension,
                garage_x, garage_y, garage_z, garage_radius
            ) VALUES (?, ?, ?, NULL, NULL, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]],
            definition.id,
            definition.name,
            definition.price,
            definition.exterior.x,
            definition.exterior.y,
            definition.exterior.z,
            definition.exterior.rotation,
            definition.exterior.interior,
            definition.interior.x,
            definition.interior.y,
            definition.interior.z,
            definition.interior.rotation,
            definition.interior.interior,
            dimension,
            definition.garage.x,
            definition.garage.y,
            definition.garage.z,
            definition.garage.radius
        )

        centralExecute([[
            UPDATE houses SET
                name = ?,
                price = ?,
                exterior_x = ?,
                exterior_y = ?,
                exterior_z = ?,
                exterior_rot = ?,
                exterior_interior = ?,
                interior_x = ?,
                interior_y = ?,
                interior_z = ?,
                interior_rot = ?,
                interior_id = ?,
                dimension = ?,
                garage_x = ?,
                garage_y = ?,
                garage_z = ?,
                garage_radius = ?
            WHERE id = ?
        ]],
            definition.name,
            definition.price,
            definition.exterior.x,
            definition.exterior.y,
            definition.exterior.z,
            definition.exterior.rotation,
            definition.exterior.interior,
            definition.interior.x,
            definition.interior.y,
            definition.interior.z,
            definition.interior.rotation,
            definition.interior.interior,
            dimension,
            definition.garage.x,
            definition.garage.y,
            definition.garage.z,
            definition.garage.radius,
            definition.id
        )
    end
end

local function migrateLegacyHousing()
    local migrationName = "housing_legacy_v1"
    if exports.database_manager:isMigrationComplete(migrationName) then
        return
    end

    local legacyConnection = legacyDbConnect("sqlite", "housing.db")
    if not legacyConnection then
        exports.database_manager:markMigrationComplete(migrationName)
        return
    end

    local rows = legacyDbPoll(legacyDbQuery(legacyConnection, "SELECT id, owner, locked FROM houses"), -1) or {}
    for _, row in ipairs(rows) do
        local ownerKey = tostring(row.owner or "")
        local locked = tonumber(row.locked) ~= 0 and 1 or 0

        if ownerKey == "" then
            ownerKey = nil
        else
            exports.database_manager:ensureOwnerRecord(ownerKey)
        end

        centralExecute(
            "UPDATE houses SET owner_key = ?, owner_account = ?, locked = ? WHERE id = ?",
            ownerKey,
            getAccountNameFromOwnerKey(ownerKey),
            locked,
            tonumber(row.id) or 0
        )
    end

    exports.database_manager:markMigrationComplete(migrationName)
end

local function loadHouses()
    houses = {}

    for _, row in ipairs(centralQuery("SELECT * FROM houses ORDER BY id ASC")) do
        local houseId = tonumber(row.id)
        houses[houseId] = {
            id = houseId,
            name = row.name,
            price = math.floor(tonumber(row.price) or 0),
            owner_key = row.owner_key,
            owner_account = row.owner_account,
            locked = tonumber(row.locked) ~= 0,
            exterior = {
                x = tonumber(row.exterior_x) or 0,
                y = tonumber(row.exterior_y) or 0,
                z = tonumber(row.exterior_z) or 0,
                rotation = tonumber(row.exterior_rot) or 0,
                interior = tonumber(row.exterior_interior) or 0,
            },
            interior = {
                x = tonumber(row.interior_x) or 0,
                y = tonumber(row.interior_y) or 0,
                z = tonumber(row.interior_z) or 0,
                rotation = tonumber(row.interior_rot) or 0,
                interior = tonumber(row.interior_id) or 0,
            },
            dimension = tonumber(row.dimension) or 0,
            garage = {
                x = tonumber(row.garage_x) or 0,
                y = tonumber(row.garage_y) or 0,
                z = tonumber(row.garage_z) or 0,
                radius = tonumber(row.garage_radius) or 8,
            },
        }
    end
end

local function destroyHouseElements()
    for pickup in pairs(purchasePickups) do
        if isElement(pickup) then
            destroyElement(pickup)
        end
    end

    for marker in pairs(exitMarkers) do
        if isElement(marker) then
            destroyElement(marker)
        end
    end

    for blip in pairs(houseBlips) do
        if isElement(blip) then
            destroyElement(blip)
        end
    end

    purchasePickups = {}
    exitMarkers = {}
    houseBlips = {}
end

local function createHouseElements()
    destroyHouseElements()

    for _, house in pairs(houses) do
        local pickup = createPickup(house.exterior.x, house.exterior.y, house.exterior.z, 3, 1273)
        local exitMarker = createMarker(house.interior.x, house.interior.y, house.interior.z - 1, "arrow", 1.1, 255, 140, 40, 120)
        local blip = createBlip(house.exterior.x, house.exterior.y, house.exterior.z, 31, 2, 40, 140, 255, 255, 0, 200)

        setElementInterior(pickup, house.exterior.interior)
        setElementDimension(pickup, 0)
        setElementInterior(exitMarker, house.interior.interior)
        setElementDimension(exitMarker, house.dimension)

        setElementData(pickup, "housing:houseId", house.id, false)
        setElementData(exitMarker, "housing:houseId", house.id, false)

        setElementParent(pickup, resourceRoot)
        setElementParent(exitMarker, resourceRoot)
        setElementParent(blip, resourceRoot)

        purchasePickups[pickup] = house.id
        exitMarkers[exitMarker] = house.id
        houseBlips[blip] = house.id
    end
end

local function saveHouseOwnership(house)
    return centralExecute(
        "UPDATE houses SET owner_key = ?, owner_account = ?, locked = ? WHERE id = ?",
        house.owner_key,
        house.owner_account,
        house.locked and 1 or 0,
        house.id
    )
end

local function getNearbyExteriorHouse(player, maxDistance)
    maxDistance = maxDistance or 4
    if getElementInterior(player) ~= 0 or getElementDimension(player) ~= 0 then
        return nil
    end

    local px, py, pz = getElementPosition(player)
    for _, house in pairs(houses) do
        local distance = getDistanceBetweenPoints3D(px, py, pz, house.exterior.x, house.exterior.y, house.exterior.z)
        if distance <= maxDistance then
            return house
        end
    end

    return nil
end

local function getInteriorHouse(player)
    local dimension = getElementDimension(player)
    if dimension == 0 then
        return nil
    end

    for _, house in pairs(houses) do
        if house.dimension == dimension and house.interior.interior == getElementInterior(player) then
            return house
        end
    end

    return nil
end

local function isHouseOwner(player, house)
    local ownerKey = getAccountOwnerKey(player)
    return ownerKey and house and house.owner_key == ownerKey
end

local function getOwnedHouseCount(player)
    local ownerKey = getAccountOwnerKey(player)
    if not ownerKey then
        return 0
    end

    local row = centralQuery("SELECT COUNT(*) AS owned_total FROM houses WHERE owner_key = ?", ownerKey)[1]
    return row and math.floor(tonumber(row.owned_total) or 0) or 0
end

local function hideHousePopupForPlayer(player)
    triggerClientEvent(player, "rp_ui:hideHousePopup", root)
end

local function buildHousePopupPayload(player, house)
    local ownerName = "Available"
    if house.owner_key and house.owner_key ~= "" then
        ownerName = house.owner_account or house.owner_key
    end

    local ownedByPlayer = isHouseOwner(player, house)
    local canBuy = not house.owner_key or house.owner_key == ""
    local canEnter = canBuy or ownedByPlayer or not house.locked
    local canLock = ownedByPlayer
    local canPark = ownedByPlayer and isPedInVehicle(player) and getPedOccupiedVehicleSeat(player) == 0

    return {
        id = house.id,
        name = house.name,
        ownerName = ownerName,
        price = house.price,
        locked = house.locked,
        canBuy = canBuy,
        canEnter = canEnter,
        canLock = canLock,
        canPark = canPark,
        position = {
            x = house.exterior.x,
            y = house.exterior.y,
            z = house.exterior.z,
            radius = 6,
            interior = house.exterior.interior,
            dimension = 0,
        },
    }
end

local function showHousePopupForPlayer(player, house)
    triggerClientEvent(player, "rp_ui:showHousePopup", root, buildHousePopupPayload(player, house))
end

local function movePlayerIntoHouse(player, house)
    hideHousePopupForPlayer(player)
    setElementInterior(player, house.interior.interior)
    setElementDimension(player, house.dimension)
    setElementPosition(player, house.interior.x, house.interior.y, house.interior.z)
    setPedRotation(player, house.interior.rotation)
    outputChatBox("Housing: entered " .. house.name .. ".", player, 120, 255, 120, true)
end

local function movePlayerOutOfHouse(player, house)
    hideHousePopupForPlayer(player)
    setElementInterior(player, house.exterior.interior)
    setElementDimension(player, 0)
    setElementPosition(player, house.exterior.x, house.exterior.y, house.exterior.z)
    setPedRotation(player, house.exterior.rotation)
    outputChatBox("Housing: exited " .. house.name .. ".", player, 120, 255, 120, true)
end

local function showHouseInfo(player, house)
    if not house then
        hideHousePopupForPlayer(player)
        return
    end

    showHousePopupForPlayer(player, house)

    if not house.owner_key or house.owner_key == "" then
        outputChatBox(
            "Housing: " .. house.name .. " is for sale for " .. formatMoney(house.price) .. ". Use /buyhouse or /enterhouse to preview.",
            player,
            120,
            255,
            120,
            true
        )
        return
    end

    if isHouseOwner(player, house) then
        local state = house.locked and "locked" or "unlocked"
        outputChatBox(
            "Housing: " .. house.name .. " is yours and " .. state .. ". Use /enterhouse, /lockhouse or /sellhouse. Garage lock follows the house lock.",
            player,
            120,
            255,
            120,
            true
        )
        return
    end

    if house.locked then
        outputChatBox("Housing: " .. house.name .. " is owned and locked.", player, 255, 180, 120, true)
    else
        outputChatBox("Housing: " .. house.name .. " is owned but unlocked. Use /enterhouse.", player, 255, 220, 120, true)
    end
end

function getOwnedGarageHouseIdForPosition(ownerKey, x, y, z)
    ownerKey = tostring(ownerKey or "")
    x = tonumber(x)
    y = tonumber(y)
    z = tonumber(z)
    if ownerKey == "" or not x or not y or not z then
        return false
    end

    for _, house in pairs(houses) do
        if house.owner_key == ownerKey then
            local distance = getDistanceBetweenPoints3D(x, y, z, house.garage.x, house.garage.y, house.garage.z)
            if distance <= house.garage.radius then
                return house.id
            end
        end
    end

    return false
end

local function getExteriorHouseForUiRequest(player, requestedHouseId)
    local house = getNearbyExteriorHouse(player, 5)
    if not house then
        return nil
    end

    if requestedHouseId and requestedHouseId ~= false and tonumber(requestedHouseId) ~= house.id then
        return nil
    end

    return house
end

local function getHouseForEnterRequest(player, requestedHouseId)
    local house = getInteriorHouse(player) or getNearbyExteriorHouse(player, 5)
    if not house then
        return nil
    end

    if requestedHouseId and requestedHouseId ~= false and tonumber(requestedHouseId) ~= house.id then
        return nil
    end

    return house
end

local function tryEnterHouse(player, house)
    if not house then
        outputChatBox("Housing: stand near a house pickup first.", player, 255, 80, 80, true)
        return false
    end

    if house.owner_key and house.owner_key ~= "" and house.locked and not isHouseOwner(player, house) then
        outputChatBox("Housing: this house is locked.", player, 255, 80, 80, true)
        return false
    end

    movePlayerIntoHouse(player, house)
    return true
end

local function tryBuyHouse(player, house)
    if not house then
        outputChatBox("Housing: stand near a house pickup first.", player, 255, 80, 80, true)
        return false
    end

    if house.owner_key and house.owner_key ~= "" then
        outputChatBox("Housing: this house is already owned.", player, 255, 80, 80, true)
        return false
    end

    if getOwnedHouseCount(player) > 0 then
        outputChatBox("Housing: you already own a house in this starter setup.", player, 255, 80, 80, true)
        return false
    end

    if getPlayerMoney(player) < house.price then
        outputChatBox("Housing: you need " .. formatMoney(house.price) .. " to buy this house.", player, 255, 80, 80, true)
        return false
    end

    local ownerKey = exports.database_manager:ensurePlayerRecord(player, true)
    if not ownerKey then
        outputChatBox("Housing: you need to be logged into an account to buy a house.", player, 255, 80, 80, true)
        return false
    end

    takePlayerMoney(player, house.price)
    house.owner_key = ownerKey
    house.owner_account = getAccountNameFromOwnerKey(ownerKey)
    house.locked = true
    saveHouseOwnership(house)
    pushGarageLockState(house)
    outputChatBox("Housing: you bought " .. house.name .. " for " .. formatMoney(house.price) .. ".", player, 120, 255, 120, true)
    showHousePopupForPlayer(player, house)
    return true
end

local function tryToggleHouseLock(player, house)
    if not house or not isHouseOwner(player, house) then
        outputChatBox("Housing: you must be at your house to lock or unlock it.", player, 255, 80, 80, true)
        return false
    end

    house.locked = not house.locked
    saveHouseOwnership(house)
    pushGarageLockState(house)
    outputChatBox(
        "Housing: " .. house.name .. " is now " .. (house.locked and "locked" or "unlocked") .. ".",
        player,
        120,
        255,
        120,
        true
    )
    showHousePopupForPlayer(player, house)
    return true
end

addEventHandler("onResourceStart", resourceRoot, function()
    seedHouses()
    migrateLegacyHousing()
    loadHouses()
    createHouseElements()
end)

addEventHandler("onPickupHit", resourceRoot, function(hitElement)
    if getElementType(hitElement) ~= "player" then
        return
    end

    showHouseInfo(hitElement, houses[purchasePickups[source]])
end)

addEventHandler("onMarkerHit", resourceRoot, function(hitElement, matchingDimension)
    if not matchingDimension or getElementType(hitElement) ~= "player" then
        return
    end

    local house = houses[exitMarkers[source]]
    if house then
        movePlayerOutOfHouse(hitElement, house)
    end
end)

addCommandHandler("enterhouse", function(player)
    local house = getInteriorHouse(player)
    if house then
        movePlayerOutOfHouse(player, house)
        return
    end

    tryEnterHouse(player, getNearbyExteriorHouse(player, 4))
end)

addCommandHandler("buyhouse", function(player)
    tryBuyHouse(player, getNearbyExteriorHouse(player, 4))
end)

addCommandHandler("sellhouse", function(player)
    local house = getNearbyExteriorHouse(player, 4) or getInteriorHouse(player)
    if not house or not isHouseOwner(player, house) then
        outputChatBox("Housing: stand at your house to sell it.", player, 255, 80, 80, true)
        return
    end

    local refund = math.floor(house.price * 0.7)
    givePlayerMoney(player, refund)
    house.owner_key = nil
    house.owner_account = nil
    house.locked = true
    saveHouseOwnership(house)

    if isVehiclesResourceRunning() then
        exports.vehicles:releaseHouseVehicles(house.id)
    end

    outputChatBox("Housing: sold " .. house.name .. " for " .. formatMoney(refund) .. ".", player, 120, 255, 120, true)
end)

addCommandHandler("lockhouse", function(player)
    tryToggleHouseLock(player, getNearbyExteriorHouse(player, 4) or getInteriorHouse(player))
end)

addEvent("housing:requestBuy", true)
addEventHandler("housing:requestBuy", root, function(requestedHouseId)
    tryBuyHouse(client, getExteriorHouseForUiRequest(client, requestedHouseId))
end)

addEvent("housing:requestEnter", true)
addEventHandler("housing:requestEnter", root, function(requestedHouseId)
    local house = getHouseForEnterRequest(client, requestedHouseId)
    if house and getInteriorHouse(client) == house then
        movePlayerOutOfHouse(client, house)
        return
    end

    tryEnterHouse(client, house)
end)

addEvent("housing:requestToggleLock", true)
addEventHandler("housing:requestToggleLock", root, function(requestedHouseId)
    tryToggleHouseLock(client, getExteriorHouseForUiRequest(client, requestedHouseId) or getInteriorHouse(client))
end)
