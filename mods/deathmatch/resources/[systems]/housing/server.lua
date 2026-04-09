-- housing/server.lua
-- Houses + Apartments + Shared Keys + Garage Interior Dimensions
-- Integrates with: database_manager, inventory, vehicles, garage_system

local legacyDbConnect = dbConnect
local legacyDbPoll    = dbPoll
local legacyDbQuery   = dbQuery

-- ───────────────────────────────────────────────────────────────
-- PROPERTY DEFINITIONS
-- Each entry can be type "house" or "apartment"
-- garage_int_* = interior spawn point for garage dimension
-- ───────────────────────────────────────────────────────────────
local propertyDefinitions = {
    -- LOS SANTOS ─ Houses
    {
        id   = 1,
        name = "Ganton Safehouse",
        type = "house",
        price = 50000,
        exterior    = { x = 2495.33,  y = -1690.75, z = 13.78,  rotation = 180, interior = 0 },
        interior    = { x = 2496.05,  y = -1692.73, z = 1013.75, rotation = 0,   interior = 3 },
        garage      = { x = 2495.33,  y = -1684.90, z = 13.78,  radius = 11 },
        garage_int  = { x = 2495.33,  y = -1680.00, z = 13.78,  rotation = 0 },
    },
    {
        id   = 2,
        name = "East LS House",
        type = "house",
        price = 42000,
        exterior    = { x = 2402.52,  y = -1715.28, z = 14.13,  rotation = 180, interior = 0 },
        interior    = { x = 243.75,   y = 304.82,   z = 999.14, rotation = 270, interior = 1 },
        garage      = { x = 2398.50,  y = -1710.80, z = 13.80,  radius = 11 },
        garage_int  = { x = 2398.50,  y = -1706.00, z = 13.80,  rotation = 0 },
    },
    -- LOS SANTOS ─ Apartments
    {
        id   = 3,
        name = "Rodeo Apartment",
        type = "apartment",
        price = 62000,
        exterior    = { x = -382.67,  y = -1438.83, z = 26.12,  rotation = 270, interior = 0 },
        interior    = { x = 292.89,   y = 309.90,   z = 999.15, rotation = 90, interior = 3 },
        garage      = { x = -376.90,  y = -1438.83, z = 25.90,  radius = 10 },
        garage_int  = { x = -376.90,  y = -1434.00, z = 25.90,  rotation = 0 },
    },
    {
        id   = 10,
        name = "Commerce Apartment",
        type = "apartment",
        price = 55000,
        exterior    = { x = 1541.50,  y = -1330.80, z = 17.25,  rotation = 180, interior = 0 },
        interior    = { x = 295.00,   y = 310.00,   z = 999.15, rotation = 270, interior = 2 },
        garage      = { x = 1541.50,  y = -1325.00, z = 17.25,  radius = 10 },
        garage_int  = { x = 1541.50,  y = -1320.00, z = 17.25,  rotation = 0 },
    },
    {
        id   = 11,
        name = "Market Apartment",
        type = "apartment",
        price = 48000,
        exterior    = { x = 1968.60,  y = -1774.80, z = 13.55,  rotation = 90,  interior = 0 },
        interior    = { x = 265.20,   y = 303.50,   z = 999.15, rotation = 180, interior = 5 },
        garage      = { x = 1968.60,  y = -1780.00, z = 13.55,  radius = 10 },
        garage_int  = { x = 1968.60,  y = -1784.00, z = 13.55,  rotation = 0 },
    },
    -- SAN FIERRO ─ Houses
    {
        id   = 4,
        name = "San Fierro Condo",
        type = "house",
        price = 70000,
        exterior    = { x = -1800.21, y = 1200.58,  z = 25.12,  rotation = 180, interior = 0 },
        interior    = { x = 300.24,   y = 300.58,   z = 999.15, rotation = 0,   interior = 4 },
        garage      = { x = -1795.10, y = 1204.80,  z = 24.80,  radius = 11 },
        garage_int  = { x = -1795.10, y = 1209.00,  z = 24.80,  rotation = 0 },
    },
    -- SAN FIERRO ─ Apartments
    {
        id   = 12,
        name = "Calton Heights Apartment",
        type = "apartment",
        price = 65000,
        exterior    = { x = -2184.60, y = 646.00,   z = 35.47,  rotation = 0,   interior = 0 },
        interior    = { x = 321.00,   y = 305.00,   z = 999.15, rotation = 90,  interior = 6 },
        garage      = { x = -2184.60, y = 651.00,   z = 35.47,  radius = 10 },
        garage_int  = { x = -2184.60, y = 656.00,   z = 35.47,  rotation = 0 },
    },
    -- TIERRA ROBADA ─ Houses
    {
        id   = 5,
        name = "Tierra Robada House",
        type = "house",
        price = 55000,
        exterior    = { x = -1390.19, y = 2638.72,  z = 55.98,  rotation = 180, interior = 0 },
        interior    = { x = 322.25,   y = 302.42,   z = 999.15, rotation = 0,   interior = 5 },
        garage      = { x = -1385.40, y = 2644.20,  z = 55.80,  radius = 11 },
        garage_int  = { x = -1385.40, y = 2649.00,  z = 55.80,  rotation = 0 },
    },
    -- LAS VENTURAS ─ Houses
    {
        id   = 6,
        name = "Las Venturas House",
        type = "house",
        price = 78000,
        exterior    = { x = 2037.22,  y = 2721.81,  z = 11.29,  rotation = 0,   interior = 0 },
        interior    = { x = 343.74,   y = 305.03,   z = 999.15, rotation = 180, interior = 6 },
        garage      = { x = 2044.20,  y = 2722.10,  z = 10.90,  radius = 12 },
        garage_int  = { x = 2044.20,  y = 2727.00,  z = 10.90,  rotation = 0 },
    },
    -- LAS VENTURAS ─ Apartments
    {
        id   = 13,
        name = "The Camel's Toe Apartment",
        type = "apartment",
        price = 72000,
        exterior    = { x = 2536.90,  y = 2454.40,  z = 10.82,  rotation = 270, interior = 0 },
        interior    = { x = 265.00,   y = 303.00,   z = 999.15, rotation = 0,   interior = 8 },
        garage      = { x = 2536.90,  y = 2460.00,  z = 10.82,  radius = 10 },
        garage_int  = { x = 2536.90,  y = 2465.00,  z = 10.82,  rotation = 0 },
    },
    {
        id   = 14,
        name = "Redsands West Apartment",
        type = "apartment",
        price = 68000,
        exterior    = { x = 1458.50,  y = 2617.20,  z = 10.82,  rotation = 90,  interior = 0 },
        interior    = { x = 295.00,   y = 310.00,   z = 999.15, rotation = 180, interior = 9 },
        garage      = { x = 1458.50,  y = 2623.00,  z = 10.82,  radius = 10 },
        garage_int  = { x = 1458.50,  y = 2628.00,  z = 10.82,  rotation = 0 },
    },
}

-- ───────────────────────────────────────────────────────────────
-- STATE
-- ───────────────────────────────────────────────────────────────
local houses          = {}   -- id → house data table
local purchasePickups = {}   -- pickup element → house id
local exitMarkers     = {}   -- marker element → house id
local houseBlips      = {}   -- blip element → house id

-- ───────────────────────────────────────────────────────────────
-- HELPERS
-- ───────────────────────────────────────────────────────────────
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
    local r = getResourceFromName("vehicles")
    return r and getResourceState(r) == "running"
end

local function isInventoryResourceRunning()
    local r = getResourceFromName("inventory")
    return r and getResourceState(r) == "running"
end

local function isGarageSystemRunning()
    local r = getResourceFromName("garage_system")
    return r and getResourceState(r) == "running"
end

local function pushGarageLockState(house)
    if not house or not isVehiclesResourceRunning() then return end
    exports.vehicles:setGarageVehiclesLocked(house.id, house.locked)
end

-- ───────────────────────────────────────────────────────────────
-- DATABASE SEED / LOAD
-- ───────────────────────────────────────────────────────────────
local function seedHouses()
    for _, def in ipairs(propertyDefinitions) do
        local dimension = 6000 + def.id
        centralExecute([[
            INSERT OR IGNORE INTO houses (
                id, name, price, property_type, owner_key, owner_account, locked,
                exterior_x, exterior_y, exterior_z, exterior_rot, exterior_interior,
                interior_x, interior_y, interior_z, interior_rot, interior_id, dimension,
                garage_x, garage_y, garage_z, garage_radius,
                garage_int_x, garage_int_y, garage_int_z, garage_int_rot
            ) VALUES (?, ?, ?, ?, NULL, NULL, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]],
            def.id, def.name, def.price, def.type or "house",
            def.exterior.x, def.exterior.y, def.exterior.z, def.exterior.rotation, def.exterior.interior,
            def.interior.x, def.interior.y, def.interior.z, def.interior.rotation, def.interior.interior,
            dimension,
            def.garage.x, def.garage.y, def.garage.z, def.garage.radius,
            def.garage_int.x, def.garage_int.y, def.garage_int.z, def.garage_int.rotation
        )

        centralExecute([[
            UPDATE houses SET
                name = ?, price = ?, property_type = ?,
                exterior_x = ?, exterior_y = ?, exterior_z = ?, exterior_rot = ?, exterior_interior = ?,
                interior_x = ?, interior_y = ?, interior_z = ?, interior_rot = ?, interior_id = ?,
                dimension = ?,
                garage_x = ?, garage_y = ?, garage_z = ?, garage_radius = ?,
                garage_int_x = ?, garage_int_y = ?, garage_int_z = ?, garage_int_rot = ?
            WHERE id = ?
        ]],
            def.name, def.price, def.type or "house",
            def.exterior.x, def.exterior.y, def.exterior.z, def.exterior.rotation, def.exterior.interior,
            def.interior.x, def.interior.y, def.interior.z, def.interior.rotation, def.interior.interior,
            dimension,
            def.garage.x, def.garage.y, def.garage.z, def.garage.radius,
            def.garage_int.x, def.garage_int.y, def.garage_int.z, def.garage_int.rotation,
            def.id
        )
    end
end

local function migrateLegacyHousing()
    local migrationName = "housing_legacy_v1"
    if exports.database_manager:isMigrationComplete(migrationName) then return end

    local legacyConnection = legacyDbConnect("sqlite", "housing.db")
    if not legacyConnection then
        exports.database_manager:markMigrationComplete(migrationName)
        return
    end

    local rows = legacyDbPoll(legacyDbQuery(legacyConnection, "SELECT id, owner, locked FROM houses"), -1) or {}
    for _, row in ipairs(rows) do
        local ownerKey = tostring(row.owner or "")
        local locked   = tonumber(row.locked) ~= 0 and 1 or 0

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
            id            = houseId,
            name          = row.name,
            property_type = row.property_type or "house",
            price         = math.floor(tonumber(row.price) or 0),
            owner_key     = row.owner_key,
            owner_account = row.owner_account,
            locked        = tonumber(row.locked) ~= 0,
            exterior = {
                x        = tonumber(row.exterior_x) or 0,
                y        = tonumber(row.exterior_y) or 0,
                z        = tonumber(row.exterior_z) or 0,
                rotation = tonumber(row.exterior_rot) or 0,
                interior = tonumber(row.exterior_interior) or 0,
            },
            interior = {
                x        = tonumber(row.interior_x) or 0,
                y        = tonumber(row.interior_y) or 0,
                z        = tonumber(row.interior_z) or 0,
                rotation = tonumber(row.interior_rot) or 0,
                interior = tonumber(row.interior_id) or 0,
            },
            dimension = tonumber(row.dimension) or 0,
            garage = {
                x      = tonumber(row.garage_x) or 0,
                y      = tonumber(row.garage_y) or 0,
                z      = tonumber(row.garage_z) or 0,
                radius = tonumber(row.garage_radius) or 8,
            },
            garage_int = {
                x        = tonumber(row.garage_int_x) or 0,
                y        = tonumber(row.garage_int_y) or 0,
                z        = tonumber(row.garage_int_z) or 0,
                rotation = tonumber(row.garage_int_rot) or 0,
            },
        }
    end
end

-- ───────────────────────────────────────────────────────────────
-- ELEMENT CREATION / CLEANUP
-- ───────────────────────────────────────────────────────────────
local function destroyHouseElements()
    for pickup in pairs(purchasePickups) do
        if isElement(pickup) then destroyElement(pickup) end
    end
    for marker in pairs(exitMarkers) do
        if isElement(marker) then destroyElement(marker) end
    end
    for blip in pairs(houseBlips) do
        if isElement(blip) then destroyElement(blip) end
    end
    purchasePickups = {}
    exitMarkers     = {}
    houseBlips      = {}
end

local function createHouseElements()
    destroyHouseElements()

    for _, house in pairs(houses) do
        local isApartment = house.property_type == "apartment"
        local pickupModel = isApartment and 1318 or 1273         -- apartment key vs house icon
        local blipIcon    = isApartment and 40 or 31             -- different blip icons
        local blipColor   = isApartment and { 255, 120, 40 } or { 40, 140, 255 }

        local pickup      = createPickup(house.exterior.x, house.exterior.y, house.exterior.z, 3, pickupModel)
        local exitMarker  = createMarker(house.interior.x, house.interior.y, house.interior.z - 1, "arrow", 1.1, 255, 140, 40, 120)
        local blip        = createBlip(house.exterior.x, house.exterior.y, house.exterior.z, blipIcon, 2, blipColor[1], blipColor[2], blipColor[3], 255, 0, 200)

        setElementInterior(pickup, house.exterior.interior)
        setElementDimension(pickup, 0)
        setElementInterior(exitMarker, house.interior.interior)
        setElementDimension(exitMarker, house.dimension)

        setElementData(pickup, "housing:houseId", house.id, false)
        setElementData(exitMarker, "housing:houseId", house.id, false)

        setElementParent(pickup, resourceRoot)
        setElementParent(exitMarker, resourceRoot)
        setElementParent(blip, resourceRoot)

        purchasePickups[pickup]  = house.id
        exitMarkers[exitMarker]  = house.id
        houseBlips[blip]         = house.id
    end
end

-- ───────────────────────────────────────────────────────────────
-- ACCESS LOGIC
-- ───────────────────────────────────────────────────────────────
local function saveHouseOwnership(house)
    return centralExecute(
        "UPDATE houses SET owner_key = ?, owner_account = ?, locked = ? WHERE id = ?",
        house.owner_key, house.owner_account, house.locked and 1 or 0, house.id
    )
end

local function getNearbyExteriorHouse(player, maxDistance)
    maxDistance = maxDistance or 4
    if getElementInterior(player) ~= 0 or getElementDimension(player) ~= 0 then return nil end

    local px, py, pz = getElementPosition(player)
    for _, house in pairs(houses) do
        local dist = getDistanceBetweenPoints3D(px, py, pz, house.exterior.x, house.exterior.y, house.exterior.z)
        if dist <= maxDistance then return house end
    end
    return nil
end

local function getInteriorHouse(player)
    local dimension = getElementDimension(player)
    if dimension == 0 then return nil end

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

local function hasKeyAccess(player, house)
    if isHouseOwner(player, house) then return true end
    local ownerKey = getAccountOwnerKey(player)
    if not ownerKey or not house then return false end
    return exports.database_manager:hasPropertyKeyAccess(house.id, ownerKey)
end

local function getOwnedHouseCount(player)
    local ownerKey = getAccountOwnerKey(player)
    if not ownerKey then return 0 end

    local row = centralQuery("SELECT COUNT(*) AS owned_total FROM houses WHERE owner_key = ?", ownerKey)[1]
    return row and math.floor(tonumber(row.owned_total) or 0) or 0
end

-- ───────────────────────────────────────────────────────────────
-- KEY ITEM GRANT / REVOKE
-- ───────────────────────────────────────────────────────────────
local function grantPropertyKeyItem(player, house)
    if not isInventoryResourceRunning() then return end
    -- item name encodes the property id: "property_key_N"
    local itemName = "property_key_" .. house.id
    exports.inventory:addInventoryItem(player, itemName, 1)
    outputChatBox(
        "Housing: you received a key for " .. house.name .. ". Check your inventory (I).",
        player, 120, 255, 180, true
    )
end

local function revokePropertyKeyItem(player, house)
    if not isInventoryResourceRunning() then return end
    local itemName = "property_key_" .. house.id
    exports.inventory:removeInventoryItem(player, itemName, 1)
end

-- ───────────────────────────────────────────────────────────────
-- UI HELPERS
-- ───────────────────────────────────────────────────────────────
local function hideHousePopupForPlayer(player)
    triggerClientEvent(player, "rp_ui:hideHousePopup", root)
end

local function buildHousePopupPayload(player, house)
    local ownerName   = "Available"
    if house.owner_key and house.owner_key ~= "" then
        ownerName = house.owner_account or house.owner_key
    end

    local ownedByPlayer = isHouseOwner(player, house)
    local hasKey        = hasKeyAccess(player, house)
    local canBuy        = not house.owner_key or house.owner_key == ""
    local canEnter      = canBuy or hasKey or not house.locked
    local canLock       = ownedByPlayer
    local canPark       = ownedByPlayer and isPedInVehicle(player) and getPedOccupiedVehicleSeat(player) == 0

    return {
        id           = house.id,
        name         = house.name,
        property_type = house.property_type,
        ownerName    = ownerName,
        price        = house.price,
        locked       = house.locked,
        canBuy       = canBuy,
        canEnter     = canEnter,
        canLock      = canLock,
        canPark      = canPark,
        position = {
            x         = house.exterior.x,
            y         = house.exterior.y,
            z         = house.exterior.z,
            radius    = 6,
            interior  = house.exterior.interior,
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
    local label = house.property_type == "apartment" and "apartment" or "house"
    outputChatBox("Housing: entered " .. house.name .. " (" .. label .. ").", player, 120, 255, 120, true)
end

local function movePlayerOutOfHouse(player, house)
    hideHousePopupForPlayer(player)
    setElementInterior(player, house.exterior.interior)
    setElementDimension(player, 0)
    setElementPosition(player, house.exterior.x, house.exterior.y, house.exterior.z)
    setPedRotation(player, house.exterior.rotation)
    local label = house.property_type == "apartment" and "apartment" or "house"
    outputChatBox("Housing: exited " .. house.name .. " (" .. label .. ").", player, 120, 255, 120, true)
end

local function showHouseInfo(player, house)
    if not house then
        hideHousePopupForPlayer(player)
        return
    end

    showHousePopupForPlayer(player, house)
    local label = house.property_type == "apartment" and "Apartment" or "House"

    if not house.owner_key or house.owner_key == "" then
        outputChatBox(
            "Housing: " .. label .. " \"" .. house.name .. "\" is for sale for " .. formatMoney(house.price) .. ". Use /buyhouse to purchase.",
            player, 120, 255, 120, true
        )
        return
    end

    if isHouseOwner(player, house) then
        local state = house.locked and "locked" or "unlocked"
        outputChatBox(
            "Housing: " .. label .. " \"" .. house.name .. "\" is yours (" .. state .. "). Commands: /enterhouse /lockhouse /sellhouse /sharekey <player> /revokekey <player>",
            player, 120, 255, 120, true
        )
        return
    end

    if hasKeyAccess(player, house) then
        outputChatBox("Housing: you have a shared key for " .. house.name .. ". Use /enterhouse.", player, 180, 255, 120, true)
        return
    end

    if house.locked then
        outputChatBox("Housing: " .. house.name .. " is owned and locked.", player, 255, 180, 120, true)
    else
        outputChatBox("Housing: " .. house.name .. " is owned but unlocked. Use /enterhouse.", player, 255, 220, 120, true)
    end
end

-- ───────────────────────────────────────────────────────────────
-- EXPORTED: garage system uses this to find the house linked to a garage zone
-- ───────────────────────────────────────────────────────────────
function getOwnedGarageHouseIdForPosition(ownerKey, x, y, z)
    ownerKey = tostring(ownerKey or "")
    x = tonumber(x)
    y = tonumber(y)
    z = tonumber(z)
    if ownerKey == "" or not x or not y or not z then return false end

    for _, house in pairs(houses) do
        if house.owner_key == ownerKey then
            local dist = getDistanceBetweenPoints3D(x, y, z, house.garage.x, house.garage.y, house.garage.z)
            if dist <= house.garage.radius then
                return house.id
            end
        end
    end
    return false
end

-- ───────────────────────────────────────────────────────────────
-- EXPORTED: returns full house data for a given id (used by garage_system)
-- ───────────────────────────────────────────────────────────────
function getHouseData(houseId)
    return houses[tonumber(houseId)] or false
end

-- ───────────────────────────────────────────────────────────────
-- EXPORTED: check if a key (ownerKey) is authorised for houseId
-- ───────────────────────────────────────────────────────────────
function checkHouseAccess(houseId, ownerKey)
    local house = houses[tonumber(houseId)]
    if not house then return false end
    ownerKey = tostring(ownerKey or "")
    if ownerKey == "" then return false end

    if house.owner_key == ownerKey then return true end
    return exports.database_manager:hasPropertyKeyAccess(houseId, ownerKey)
end

-- ───────────────────────────────────────────────────────────────
-- ENTER / BUY / SELL / LOCK HELPERS
-- ───────────────────────────────────────────────────────────────
local function getExteriorHouseForUiRequest(player, requestedHouseId)
    local house = getNearbyExteriorHouse(player, 5)
    if not house then return nil end
    if requestedHouseId and requestedHouseId ~= false and tonumber(requestedHouseId) ~= house.id then return nil end
    return house
end

local function getHouseForEnterRequest(player, requestedHouseId)
    local house = getInteriorHouse(player) or getNearbyExteriorHouse(player, 5)
    if not house then return nil end
    if requestedHouseId and requestedHouseId ~= false and tonumber(requestedHouseId) ~= house.id then return nil end
    return house
end

local function tryEnterHouse(player, house)
    if not house then
        outputChatBox("Housing: stand near a property pickup first.", player, 255, 80, 80, true)
        return false
    end

    if house.owner_key and house.owner_key ~= "" and house.locked and not hasKeyAccess(player, house) then
        outputChatBox("Housing: this property is locked. You need a key.", player, 255, 80, 80, true)
        return false
    end

    movePlayerIntoHouse(player, house)
    return true
end

local function tryBuyHouse(player, house)
    if not house then
        outputChatBox("Housing: stand near a property pickup first.", player, 255, 80, 80, true)
        return false
    end

    if house.owner_key and house.owner_key ~= "" then
        outputChatBox("Housing: this property is already owned.", player, 255, 80, 80, true)
        return false
    end

    if getOwnedHouseCount(player) >= 3 then
        outputChatBox("Housing: you already own 3 properties (maximum).", player, 255, 80, 80, true)
        return false
    end

    if getPlayerMoney(player) < house.price then
        outputChatBox("Housing: you need " .. formatMoney(house.price) .. " to buy this property.", player, 255, 80, 80, true)
        return false
    end

    local ownerKey = exports.database_manager:ensurePlayerRecord(player, true)
    if not ownerKey then
        outputChatBox("Housing: you need to be logged into an account to buy.", player, 255, 80, 80, true)
        return false
    end

    takePlayerMoney(player, house.price)
    house.owner_key     = ownerKey
    house.owner_account = getAccountNameFromOwnerKey(ownerKey)
    house.locked        = true
    saveHouseOwnership(house)
    pushGarageLockState(house)

    -- Grant property key item to buyer
    grantPropertyKeyItem(player, house)

    local label = house.property_type == "apartment" and "apartment" or "house"
    outputChatBox(
        "Housing: you bought " .. house.name .. " (" .. label .. ") for " .. formatMoney(house.price) .. "!",
        player, 120, 255, 120, true
    )
    showHousePopupForPlayer(player, house)
    return true
end

local function tryToggleHouseLock(player, house)
    if not house or not isHouseOwner(player, house) then
        outputChatBox("Housing: you must be at your property to lock/unlock.", player, 255, 80, 80, true)
        return false
    end

    house.locked = not house.locked
    saveHouseOwnership(house)
    pushGarageLockState(house)
    outputChatBox(
        "Housing: " .. house.name .. " is now " .. (house.locked and "locked" or "unlocked") .. ".",
        player, 120, 255, 120, true
    )
    showHousePopupForPlayer(player, house)
    return true
end

-- ───────────────────────────────────────────────────────────────
-- SHARED KEY COMMANDS
-- ───────────────────────────────────────────────────────────────
local function sanitizeName(playerName)
    return tostring(playerName or ""):gsub("#%x%x%x%x%x%x", "")
end

local function findPlayerByFragment(fragment)
    if not fragment or fragment == "" then return nil end
    fragment = fragment:lower()
    local partialMatch
    for _, p in ipairs(getElementsByType("player")) do
        local plain = sanitizeName(getPlayerName(p))
        local lower = plain:lower()
        if lower == fragment then return p end
        if not partialMatch and lower:find(fragment, 1, true) then
            partialMatch = p
        end
    end
    return partialMatch
end

addCommandHandler("sharekey", function(player, _, targetFragment)
    local house = getNearbyExteriorHouse(player, 4) or getInteriorHouse(player)
    if not house or not isHouseOwner(player, house) then
        outputChatBox("Housing: stand at your property to share a key.", player, 255, 80, 80, true)
        return
    end

    if not targetFragment then
        outputChatBox("Usage: /sharekey <player>", player, 255, 220, 120, true)
        return
    end

    local target = findPlayerByFragment(targetFragment)
    if not target then
        outputChatBox("Housing: player not found.", player, 255, 80, 80, true)
        return
    end

    if target == player then
        outputChatBox("Housing: you cannot share a key with yourself.", player, 255, 80, 80, true)
        return
    end

    local ownerKey      = getAccountOwnerKey(player)
    local targetOwnerKey = exports.database_manager:getPlayerOwnerKey(target, true)
    if not targetOwnerKey then
        outputChatBox("Housing: target player must be logged in.", player, 255, 80, 80, true)
        return
    end

    exports.database_manager:grantPropertyKey(house.id, targetOwnerKey, ownerKey)
    grantPropertyKeyItem(target, house)

    local targetName = sanitizeName(getPlayerName(target))
    outputChatBox("Housing: shared key for " .. house.name .. " with " .. targetName .. ".", player, 120, 255, 120, true)
    outputChatBox("Housing: " .. sanitizeName(getPlayerName(player)) .. " shared a key for " .. house.name .. " with you!", target, 120, 255, 180, true)
end)

addCommandHandler("revokekey", function(player, _, targetFragment)
    local house = getNearbyExteriorHouse(player, 4) or getInteriorHouse(player)
    if not house or not isHouseOwner(player, house) then
        outputChatBox("Housing: stand at your property to revoke a key.", player, 255, 80, 80, true)
        return
    end

    if not targetFragment then
        outputChatBox("Usage: /revokekey <player>", player, 255, 220, 120, true)
        return
    end

    local target = findPlayerByFragment(targetFragment)
    if not target then
        outputChatBox("Housing: player not found.", player, 255, 80, 80, true)
        return
    end

    local targetOwnerKey = exports.database_manager:getPlayerOwnerKey(target, true)
    if not targetOwnerKey then
        outputChatBox("Housing: target player must be logged in.", player, 255, 80, 80, true)
        return
    end

    exports.database_manager:revokePropertyKey(house.id, targetOwnerKey)
    revokePropertyKeyItem(target, house)

    local targetName = sanitizeName(getPlayerName(target))
    outputChatBox("Housing: revoked key for " .. house.name .. " from " .. targetName .. ".", player, 120, 255, 120, true)
    outputChatBox("Housing: your key for " .. house.name .. " was revoked.", target, 255, 180, 120, true)
end)

-- ───────────────────────────────────────────────────────────────
-- STANDARD COMMANDS
-- ───────────────────────────────────────────────────────────────
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
        outputChatBox("Housing: stand at your property to sell it.", player, 255, 80, 80, true)
        return
    end

    -- Revoke all shared keys and remove key items from owner
    centralExecute("DELETE FROM property_keys WHERE house_id = ?", house.id)
    revokePropertyKeyItem(player, house)

    local refund = math.floor(house.price * 0.7)
    givePlayerMoney(player, refund)
    house.owner_key     = nil
    house.owner_account = nil
    house.locked        = true
    saveHouseOwnership(house)

    if isVehiclesResourceRunning() then
        exports.vehicles:releaseHouseVehicles(house.id)
    end

    outputChatBox("Housing: sold " .. house.name .. " for " .. formatMoney(refund) .. " (70% refund).", player, 120, 255, 120, true)
end)

addCommandHandler("lockhouse", function(player)
    tryToggleHouseLock(player, getNearbyExteriorHouse(player, 4) or getInteriorHouse(player))
end)

addCommandHandler("myproperties", function(player)
    local ownerKey = getAccountOwnerKey(player)
    if not ownerKey then
        outputChatBox("Housing: you are not logged in.", player, 255, 80, 80, true)
        return
    end

    local owned = {}
    for _, house in pairs(houses) do
        if house.owner_key == ownerKey then
            owned[#owned + 1] = house.name .. " (" .. house.property_type .. ", " .. (house.locked and "locked" or "unlocked") .. ")"
        end
    end

    if #owned == 0 then
        outputChatBox("Housing: you do not own any properties.", player, 255, 220, 120, true)
    else
        outputChatBox("Housing: your properties: " .. table.concat(owned, " | "), player, 120, 255, 120, true)
    end
end)

-- ───────────────────────────────────────────────────────────────
-- EVENTS
-- ───────────────────────────────────────────────────────────────
addEventHandler("onResourceStart", resourceRoot, function()
    seedHouses()
    migrateLegacyHousing()
    loadHouses()
    createHouseElements()
end)

addEventHandler("onPickupHit", resourceRoot, function(hitElement)
    if getElementType(hitElement) ~= "player" then return end
    showHouseInfo(hitElement, houses[purchasePickups[source]])
end)

addEventHandler("onMarkerHit", resourceRoot, function(hitElement, matchingDimension)
    if not matchingDimension or getElementType(hitElement) ~= "player" then return end
    local house = houses[exitMarkers[source]]
    if house then
        movePlayerOutOfHouse(hitElement, house)
    end
end)

-- Remote UI events
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
