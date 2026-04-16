-- housing/server.lua
-- Main logic for RP housing system
-- Audit-rebuilt: proper indentation, ghost validation, preview system, marker Z fixes.

-- ─────────────────────────────────────────────────────────────
-- STATE
-- ─────────────────────────────────────────────────────────────
local houses       = {}   -- id → house data table
local entryMarkers = {}   -- marker element → house id (exterior, yellow arrow)
local exitMarkers  = {}   -- marker element → house id (interior, orange arrow)
local houseBlips   = {}   -- blip element   → house id

local previewTimers = {}  -- player → preview expiration timer
local previewData   = {}  -- player → { houseId, x, y, z, int, dim, rot }

local ENTRY_MARKER_Z_OFFSET = 2.00
local EXIT_MARKER_Z_OFFSET  = 1.00
local EXTERIOR_RETURN_Z_OFFSET = 1.00

-- ─────────────────────────────────────────────────────────────
-- FREE APARTMENT COORDINATES
-- ─────────────────────────────────────────────────────────────
local FREE_APT_EXTERIOR_X   = 2271.74
local FREE_APT_EXTERIOR_Y   = -1139.75
local FREE_APT_EXTERIOR_Z   = 25.80
local FREE_APT_EXTERIOR_ROT = 90
local FREE_APT_EXTERIOR_INT = 0

local FREE_APT_INTERIOR_X   = 266.50
local FREE_APT_INTERIOR_Y   = 304.90
local FREE_APT_INTERIOR_Z   = 999.15
local FREE_APT_INTERIOR_ROT = 0
local FREE_APT_INTERIOR_INT = 1

-- ─────────────────────────────────────────────────────────────
-- DATABASE HELPERS
-- ─────────────────────────────────────────────────────────────
local function centralExecute(query, ...)
    return exports.database_manager:dbExecute(query, ...)
end

local function centralQuery(query, ...)
    return exports.database_manager:dbQuery(query, ...) or {}
end

local function getAccountOwnerKey(player)
    if not exports.database_manager then return nil end
    return exports.database_manager:getPlayerOwnerKey(player, true)
end

local function getAccountNameForKeys(player)
    local account = getPlayerAccount(player)
    if not account or isGuestAccount(account) then return "" end
    return getAccountName(account)
end

local function formatMoney(amount)
    return "$" .. tostring(math.floor(tonumber(amount) or 0))
end

local function isGarageProperty(house)
    return house and house.property_type == "garage"
end

local function hasLegacyGarage(house)
    if not house or isGarageProperty(house) then
        return false
    end

    local garage = house.garage or {}
    return (tonumber(garage.x) or 0) ~= 0 or (tonumber(garage.y) or 0) ~= 0 or (tonumber(garage.z) or 0) ~= 0
end

local function getLinkedHouse(house)
    if not house then
        return nil
    end

    local linkedId = tonumber(house.linked_property_id)
    if not linkedId then
        return nil
    end

    return houses[linkedId]
end

local function getLinkedPropertyIds(houseId)
    local ids = {}
    local seen = {}

    local function addId(id)
        id = tonumber(id)
        if id and not seen[id] and houses[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end

    addId(houseId)

    local house = houses[tonumber(houseId)]
    if house then
        addId(house.linked_property_id)
    end

    return ids
end

local function getGarageZoneData(house)
    if not house then
        return nil
    end

    if isGarageProperty(house) then
        return {
            x = house.exterior_x,
            y = house.exterior_y,
            z = house.exterior_z,
            radius = 8,
        }
    end

    if hasLegacyGarage(house) then
        return {
            x = house.garage.x,
            y = house.garage.y,
            z = house.garage.z,
            radius = house.garage.radius or 8,
        }
    end

    return nil
end

local function getExteriorReturnZ(house)
    return (tonumber(house and house.exterior_z) or 0) + EXTERIOR_RETURN_Z_OFFSET
end

local function isHousingDebugEnabled(player)
    return isElement(player) and getElementType(player) == "player" and getElementData(player, "housing:debug") == true
end

local function debugHousing(player, message)
    if not isHousingDebugEnabled(player) then
        return
    end
    outputChatBox("[HousingDebug] " .. tostring(message), player, 255, 220, 120, true)
end

local function hasPropertyKeyAccess(houseId, ownerKey)
    houseId = tonumber(houseId)
    ownerKey = tostring(ownerKey or "")
    if not houseId or ownerKey == "" then
        return false
    end
    return exports.database_manager:hasPropertyKeyAccess(houseId, ownerKey)
end

local function setHouseOwnershipState(houseId, ownerKey, ownerAccount, locked)
    houseId = tonumber(houseId)
    if not houseId or not houses[houseId] then
        return false
    end

    ownerKey = tostring(ownerKey or "")
    ownerAccount = tostring(ownerAccount or "")
    locked = locked and true or false

    centralExecute(
        "UPDATE houses SET owner_key = ?, owner_account = ?, locked = ? WHERE id = ?",
        ownerKey ~= "" and ownerKey or nil,
        ownerAccount ~= "" and ownerAccount or nil,
        locked and 1 or 0,
        houseId
    )

    houses[houseId].owner_key = ownerKey
    houses[houseId].owner_account = ownerAccount
    houses[houseId].locked = locked
    return true
end

local function syncGarageVehicleLocks(houseId, locked)
    local vehiclesResource = getResourceFromName("vehicles")
    if not vehiclesResource or getResourceState(vehiclesResource) ~= "running" then
        return
    end
    exports.vehicles:setGarageVehiclesLocked(houseId, locked)
end

local function setLinkedLockState(house, locked)
    locked = locked and true or false

    for _, propertyId in ipairs(getLinkedPropertyIds(house.id)) do
        local property = houses[propertyId]
        if property then
            property.locked = locked
            centralExecute("UPDATE houses SET locked = ? WHERE id = ?", locked and 1 or 0, propertyId)
            if isGarageProperty(property) or hasLegacyGarage(property) then
                syncGarageVehicleLocks(propertyId, locked)
            end
        end
    end
end

-- ─────────────────────────────────────────────────────────────
-- CLEANUP / LOAD / RELOAD
-- ─────────────────────────────────────────────────────────────
-- Utility: count keys in a non-sequential table
local function countTable(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function destroyHouseElements()
    for marker in pairs(entryMarkers) do
        if isElement(marker) then destroyElement(marker) end
    end
    for marker in pairs(exitMarkers) do
        if isElement(marker) then destroyElement(marker) end
    end
    for blip in pairs(houseBlips) do
        if isElement(blip) then destroyElement(blip) end
    end
    entryMarkers = {}
    exitMarkers  = {}
    houseBlips   = {}
end

function reloadHouses()
    destroyHouseElements()
    houses = {}

    local rows = centralQuery("SELECT * FROM houses")
    for _, row in ipairs(rows) do
        local houseId = tonumber(row.id)
        local ex = tonumber(row.exterior_x) or 0
        local ey = tonumber(row.exterior_y) or 0
        local hasOwner = row.owner_key and row.owner_key ~= ""

        -- Ghost marker validation: skip unowned properties at world origin
        if ex == 0 and ey == 0 and not hasOwner then
            outputDebugString("[Housing] Skipping ghost property #" .. tostring(houseId) .. " (coords 0,0, no owner)", 2)
        else
            local h = {
                id             = houseId,
                name           = row.name,
                price          = tonumber(row.price) or 0,
                property_type  = row.property_type or "house",
                linked_property_id = tonumber(row.linked_property_id),
                owner_key      = row.owner_key or "",
                owner_account  = row.owner_account or "",
                locked         = (tonumber(row.locked) == 1),
                dimension      = tonumber(row.dimension) or 0,

                exterior_x         = ex,
                exterior_y         = ey,
                exterior_z         = tonumber(row.exterior_z) or 0,
                exterior_rot       = tonumber(row.exterior_rot) or 0,
                exterior_interior  = tonumber(row.exterior_interior) or 0,

                interior_x         = tonumber(row.interior_x),
                interior_y         = tonumber(row.interior_y),
                interior_z         = tonumber(row.interior_z),
                interior_rot       = tonumber(row.interior_rot) or 0,
                interior_interior  = tonumber(row.interior_id) or 0,

                garage = {
                    x      = tonumber(row.garage_x) or 0,
                    y      = tonumber(row.garage_y) or 0,
                    z      = tonumber(row.garage_z) or 0,
                    radius = tonumber(row.garage_radius) or 6,
                },
                garage_int = {
                    x        = tonumber(row.garage_int_x) or 0,
                    y        = tonumber(row.garage_int_y) or 0,
                    z        = tonumber(row.garage_int_z) or 0,
                    rotation = tonumber(row.garage_int_rot) or 0,
                },
            }

            houses[h.id] = h

            -- Raise house entry markers so they stay visible above uneven ground near doors.
            if h.exterior_x and h.exterior_y and h.exterior_z then
                local extMarker = createMarker(h.exterior_x, h.exterior_y, h.exterior_z + ENTRY_MARKER_Z_OFFSET, "arrow", 2.0, 255, 255, 0, 150)
                setElementInterior(extMarker, h.exterior_interior)
                setElementDimension(extMarker, 0)
                setElementData(extMarker, "housing:houseId", h.id, false)
                entryMarkers[extMarker] = h.id

                if not isGarageProperty(h) then
                    local blip = createBlip(h.exterior_x, h.exterior_y, h.exterior_z, 31, 1, 255, 255, 255, 255, 0, 200)
                    setElementInterior(blip, h.exterior_interior)
                    setElementDimension(blip, 0)
                    houseBlips[blip] = h.id
                end
            end

            -- Raise interior exit markers too, so they remain visible inside properties.
            if not isGarageProperty(h) and h.interior_x and h.interior_y and h.interior_z then
                local intMarker = createMarker(h.interior_x, h.interior_y, h.interior_z + EXIT_MARKER_Z_OFFSET, "arrow", 1.5, 255, 120, 0, 150)
                setElementInterior(intMarker, h.interior_interior)
                setElementDimension(intMarker, h.dimension)
                setElementData(intMarker, "housing:houseId", h.id, false)
                exitMarkers[intMarker] = h.id
            end
        end
    end

    outputDebugString("[Housing] Loaded " .. tostring(#rows) .. " rows, " .. tostring(countTable(houses)) .. " valid houses.", 3)
end

addEventHandler("onResourceStart", resourceRoot, reloadHouses)

-- ─────────────────────────────────────────────────────────────
-- ACCESS HELPERS
-- ─────────────────────────────────────────────────────────────
local function isHouseOwner(player, house)
    local pKey = getAccountOwnerKey(player)
    if not pKey or pKey == "" then
        return false
    end
    if house.owner_key == pKey then
        return true
    end

    local linked = getLinkedHouse(house)
    return linked and linked.owner_key == pKey or false
end

local function hasHouseKey(player, houseId)
    local pKey = getAccountOwnerKey(player)
    if not pKey or pKey == "" then
        return false
    end

    for _, propertyId in ipairs(getLinkedPropertyIds(houseId)) do
        if hasPropertyKeyAccess(propertyId, pKey) then
            return true
        end
    end

    return false
end

local function canAccessHouse(player, house)
    if not house.owner_key or house.owner_key == "" then return true end
    if isHouseOwner(player, house) then return true end
    if not house.locked then return true end
    local linked = getLinkedHouse(house)
    if linked and (linked.owner_key == "" or not linked.locked or isHouseOwner(player, linked)) then
        return true
    end
    return hasHouseKey(player, house.id)
end

-- ─────────────────────────────────────────────────────────────
-- EXPORTS (garage_system, vehicles, etc.)
-- ─────────────────────────────────────────────────────────────
function checkHouseAccess(houseId, ownerKey)
    local h = houses[tonumber(houseId)]
    if not h then return false end
    ownerKey = tostring(ownerKey or "")

    if h.owner_key == "" or not h.locked then return true end
    if h.owner_key == ownerKey then return true end
    if hasPropertyKeyAccess(h.id, ownerKey) then return true end

    local linked = getLinkedHouse(h)
    if linked then
        if linked.owner_key == "" or not linked.locked then return true end
        if linked.owner_key == ownerKey then return true end
        if hasPropertyKeyAccess(linked.id, ownerKey) then return true end
    end

    return false
end

function getHouseData(houseId)
    return houses[tonumber(houseId)] or false
end

function getOwnedGarageHouseIdForPosition(ownerKey, x, y, z)
    if not ownerKey or ownerKey == "" then return false end
    for _, h in pairs(houses) do
        local garageZone = getGarageZoneData(h)
        if garageZone then
            local effectiveOwner = h.owner_key or ""
            if effectiveOwner == "" then
                local linked = getLinkedHouse(h)
                effectiveOwner = linked and linked.owner_key or ""
            end
            if effectiveOwner == ownerKey then
                local dist = getDistanceBetweenPoints3D(x, y, z, garageZone.x, garageZone.y, garageZone.z)
                if dist <= (garageZone.radius or 8) then
                    return h.id
                end
                if isGarageProperty(h) and h.interior_x and h.interior_y and h.interior_z then
                    local interiorDist = getDistanceBetweenPoints3D(x, y, z, h.interior_x, h.interior_y, h.interior_z)
                    if interiorDist <= 12 then
                        return h.id
                    end
                end
                if hasLegacyGarage(h) and h.garage_int and h.garage_int.x and h.garage_int.y and h.garage_int.z then
                    local legacyInteriorDist = getDistanceBetweenPoints3D(x, y, z, h.garage_int.x, h.garage_int.y, h.garage_int.z)
                    if legacyInteriorDist <= 12 then
                        return h.id
                    end
                end
            end
        end
    end
    return false
end

-- ─────────────────────────────────────────────────────────────
-- PREVIEW HELPERS
-- ─────────────────────────────────────────────────────────────
local function isInPreview(player)
    return previewData[player] ~= nil
end

local function cleanUpPreview(player, warpBack)
    if previewTimers[player] and isTimer(previewTimers[player]) then
        killTimer(previewTimers[player])
    end
    previewTimers[player] = nil

    local data = previewData[player]
    previewData[player] = nil

    if warpBack and data and isElement(player) then
        fadeCamera(player, false, 1.0)
        setTimer(function(p, d)
            if not isElement(p) then return end
            setElementInterior(p, d.int)
            setElementDimension(p, d.dim)
            setElementPosition(p, d.x, d.y, d.z)
            setPedRotation(p, d.rot)
            fadeCamera(p, true, 1.0)
            outputChatBox("Housing: Preview ended.", p, 255, 180, 100)
        end, 1000, 1, player, data)
    end
end

local function isPlayerNearExitMarker(player)
    for marker, houseId in pairs(exitMarkers) do
        if isElementWithinMarker(player, marker) and getElementDimension(player) == getElementDimension(marker) then
            return true, houseId
        end
    end
    return false, nil
end

-- ─────────────────────────────────────────────────────────────
-- UI HELPERS
-- ─────────────────────────────────────────────────────────────
local function getNearbyMarkerHouse(player)
    for marker, houseId in pairs(entryMarkers) do
        if isElementWithinMarker(player, marker) and getElementDimension(player) == getElementDimension(marker) then
            return houses[houseId], "exterior"
        end
    end
    for marker, houseId in pairs(exitMarkers) do
        if isElementWithinMarker(player, marker) and getElementDimension(player) == getElementDimension(marker) then
            return houses[houseId], "interior"
        end
    end
    return nil, nil
end

local function getCurrentHouseContext(player)
    local house, markerType = getNearbyMarkerHouse(player)
    if house then
        return house, markerType
    end

    local dim = getElementDimension(player)
    if dim > 7000 then
        local garageId = dim - 7000
        if houses[garageId] then
            return houses[garageId], "interior"
        end
    end

    if dim > 6000 then
        local houseId = dim - 6000
        if houses[houseId] then
            return houses[houseId], "interior"
        end
    end

    return nil, nil
end

local function showHousePopup(player, house, markerType)
    local buyerKey = getAccountOwnerKey(player)
    local linked = getLinkedHouse(house)
    local linkedBuyBlocked = linked and linked.owner_key ~= "" and linked.owner_key ~= buyerKey
    local canEnter = not isGarageProperty(house) and canAccessHouse(player, house)
    local popupPosition = {
        x = house.exterior_x,
        y = house.exterior_y,
        z = house.exterior_z,
        radius = 6,
        interior = house.exterior_interior,
        dimension = 0,
    }

    if markerType == "interior" and not isGarageProperty(house) then
        popupPosition = {
            x = house.interior_x,
            y = house.interior_y,
            z = house.interior_z,
            radius = 6,
            interior = house.interior_interior,
            dimension = house.dimension,
        }
    end

    local payload = {
        id            = house.id,
        name          = house.name,
        property_type = house.property_type,
        ownerName     = (house.owner_key ~= "") and house.owner_account or "Available",
        price         = house.price,
        locked        = house.locked,
        canBuy        = (house.owner_key == "") and not linkedBuyBlocked,
        canEnter      = canEnter,
        canLock       = isHouseOwner(player, house),
        canPark       = false,
        position      = popupPosition,
    }
    triggerClientEvent(player, "rp_ui:showHousePopup", root, payload)
end

-- ─────────────────────────────────────────────────────────────
-- MARKER EVENTS
-- ─────────────────────────────────────────────────────────────
addEventHandler("onMarkerHit", resourceRoot, function(player, matchDim)
    if not matchDim or getElementType(player) ~= "player" then return end
    if isPedInVehicle(player) then return end

    -- Players in preview mode should not see popups or chat info
    if isInPreview(player) then return end

    local houseId = entryMarkers[source] or exitMarkers[source]
    if not houseId or not houses[houseId] then return end

    local h = houses[houseId]
    local markerType = entryMarkers[source] and "exterior" or "interior"
    debugHousing(player, string.format(
        "onMarkerHit house=%d marker=%s property=%s pos=(%.2f, %.2f, %.2f) int=%d dim=%d",
        tonumber(h.id) or 0,
        tostring(markerType),
        tostring(h.property_type),
        tonumber(h.exterior_x) or 0,
        tonumber(h.exterior_y) or 0,
        tonumber(h.exterior_z) or 0,
        tonumber(getElementInterior(player)) or 0,
        tonumber(getElementDimension(player)) or 0
    ))
    showHousePopup(player, h, markerType)

    -- Chat fallback
    if h.owner_key == "" then
        if isGarageProperty(h) then
            outputChatBox("Garage: " .. h.name .. " is for sale for " .. formatMoney(h.price) .. ". Press [B] to buy.", player, 100, 255, 100)
            outputChatBox("Garage: after buying, use the blue garage marker to enter it.", player, 180, 220, 255)
        else
            outputChatBox("Housing: " .. h.name .. " is for sale for " .. formatMoney(h.price) .. ". Press [B] to buy.", player, 100, 255, 100)
        end
    else
        if isHouseOwner(player, h) then
            local st = h.locked and "Locked" or "Unlocked"
            if isGarageProperty(h) then
                outputChatBox("Garage: Your garage (" .. st .. "). Use the blue marker to enter and [G] to lock.", player, 100, 255, 100)
            else
                outputChatBox("Housing: Your " .. h.property_type .. " (" .. st .. "). Press [F] Enter, [G] Lock.", player, 100, 255, 100)
            end
        else
            local prefix = isGarageProperty(h) and "Garage: " or "Housing: "
            outputChatBox(prefix .. h.name .. ". Owner: " .. h.owner_account .. ".", player, 200, 200, 200)
        end
    end
end)

addEventHandler("onMarkerLeave", resourceRoot, function(player, matchDim)
    if not matchDim or getElementType(player) ~= "player" then return end
    triggerClientEvent(player, "rp_ui:hideHousePopup", root)
end)

-- ─────────────────────────────────────────────────────────────
-- PLAYER QUIT CLEANUP
-- ─────────────────────────────────────────────────────────────
addEventHandler("onPlayerQuit", root, function()
    cleanUpPreview(source, false)
end)

-- ─────────────────────────────────────────────────────────────
-- INTERACT ACTIONS (F, B, G keybinds)
-- ─────────────────────────────────────────────────────────────
local function getLinkedBuyConflict(house, buyerKey)
    local linked = getLinkedHouse(house)
    if not linked or linked.owner_key == "" or linked.owner_key == buyerKey then
        return nil
    end
    return linked
end

local function applyLinkedOwnership(house, ownerKey, ownerAccount, locked)
    setHouseOwnershipState(house.id, ownerKey, ownerAccount, locked)

    local linked = getLinkedHouse(house)
    if linked and linked.owner_key == "" then
        setHouseOwnershipState(linked.id, ownerKey, ownerAccount, locked)
    end
end

addEvent("housing:requestEnter", true)
addEventHandler("housing:requestEnter", root, function()
    -- If in preview and standing at the exit marker, end the preview
    if isInPreview(client) then
        local nearExit, exitHouseId = isPlayerNearExitMarker(client)
        if nearExit then
            cleanUpPreview(client, true)
        end
        -- If not near exit marker, do nothing (player is just walking around)
        return
    end

    local px, py, pz = getElementPosition(client)
    debugHousing(client, string.format(
        "requestEnter tick=%d playerPos=(%.2f, %.2f, %.2f) int=%d dim=%d",
        getTickCount(),
        px,
        py,
        pz,
        tonumber(getElementInterior(client)) or 0,
        tonumber(getElementDimension(client)) or 0
    ))

    local house, mType = getNearbyMarkerHouse(client)
    if not house then
        debugHousing(client, "requestEnter found no nearby housing marker.")
        return
    end

    debugHousing(client, string.format(
        "requestEnter selected house=%d marker=%s property=%s interiorSpawn=(%.2f, %.2f, %.2f) exterior=(%.2f, %.2f, %.2f)",
        tonumber(house.id) or 0,
        tostring(mType),
        tostring(house.property_type),
        tonumber(house.interior_x) or 0,
        tonumber(house.interior_y) or 0,
        tonumber(house.interior_z) or 0,
        tonumber(house.exterior_x) or 0,
        tonumber(house.exterior_y) or 0,
        tonumber(house.exterior_z) or 0
    ))

    if mType == "exterior" then
        if isGarageProperty(house) then
            debugHousing(client, "requestEnter blocked: garage property on housing marker.")
            outputChatBox("Garage: use the blue garage marker to enter this garage.", client, 180, 220, 255)
            return
        end
        if not canAccessHouse(client, house) then
            debugHousing(client, "requestEnter blocked: property locked.")
            outputChatBox("Housing: The door is locked.", client, 255, 80, 80)
            return
        end
        debugHousing(client, string.format(
            "requestEnter teleporting INSIDE to (%.2f, %.2f, %.2f) int=%d dim=%d",
            tonumber(house.interior_x) or 0,
            tonumber(house.interior_y) or 0,
            tonumber(house.interior_z) or 0,
            tonumber(house.interior_interior) or 0,
            tonumber(house.dimension) or 0
        ))
        triggerClientEvent(client, "rp_ui:hideHousePopup", root)
        setElementInterior(client, house.interior_interior)
        setElementDimension(client, house.dimension)
        setElementPosition(client, house.interior_x, house.interior_y, house.interior_z)
        setPedRotation(client, house.interior_rot)
    elseif mType == "interior" then
        debugHousing(client, string.format(
            "requestEnter teleporting OUTSIDE to (%.2f, %.2f, %.2f) int=%d dim=0",
            tonumber(house.exterior_x) or 0,
            tonumber(house.exterior_y) or 0,
            tonumber(getExteriorReturnZ(house)) or 0,
            tonumber(house.exterior_interior) or 0
        ))
        triggerClientEvent(client, "rp_ui:hideHousePopup", root)
        setElementInterior(client, house.exterior_interior)
        setElementDimension(client, 0)
        setElementPosition(client, house.exterior_x, house.exterior_y, getExteriorReturnZ(house))
        setPedRotation(client, house.exterior_rot)
    end
end)

addEvent("housing:requestBuy", true)
addEventHandler("housing:requestBuy", root, function()
    if isInPreview(client) then
        outputChatBox("Housing: You cannot buy properties while previewing.", client, 255, 80, 80)
        return
    end

    local house, mType = getNearbyMarkerHouse(client)
    if not house or mType ~= "exterior" then return end

    if house.owner_key ~= "" then
        outputChatBox("Housing: This property is already owned.", client, 255, 80, 80)
        return
    end

    local buyerKey = getAccountOwnerKey(client)
    local buyerAccount = getAccountNameForKeys(client)
    local linkedConflict = getLinkedBuyConflict(house, buyerKey)
    if linkedConflict then
        outputChatBox("Housing: This property is linked to " .. linkedConflict.name .. ", which already belongs to another owner.", client, 255, 80, 80)
        return
    end

    local money = getPlayerMoney(client)
    if money < house.price then
        outputChatBox("Housing: You don't have enough money (" .. formatMoney(house.price) .. ").", client, 255, 80, 80)
        return
    end

    takePlayerMoney(client, house.price)
    applyLinkedOwnership(house, buyerKey, buyerAccount, true)
    local buyPrefix = isGarageProperty(house) and "Garage: " or "Housing: "
    outputChatBox(buyPrefix .. "You successfully bought " .. house.name .. " for " .. formatMoney(house.price) .. "!", client, 100, 255, 100)

    local linked = getLinkedHouse(house)
    if linked and linked.owner_key == buyerKey then
        outputChatBox("Housing: Linked property access was also assigned for " .. linked.name .. ".", client, 120, 220, 255)
    end

    showHousePopup(client, house, mType)
end)

addEvent("housing:requestToggleLock", true)
addEventHandler("housing:requestToggleLock", root, function()
    if isInPreview(client) then return end

    local house = getCurrentHouseContext(client)

    if not house then return end

    if not isHouseOwner(client, house) and not hasHouseKey(client, house.id) then
        outputChatBox("Housing: You do not have the keys to this property.", client, 255, 80, 80)
        return
    end

    local newLockedState = not house.locked
    setLinkedLockState(house, newLockedState)

    local txt = newLockedState and "locked" or "unlocked"
    outputChatBox("Housing: You " .. txt .. " the property.", client, 200, 255, 200)

    local _, markerType = getCurrentHouseContext(client)
    showHousePopup(client, house, markerType)
end)

-- ─────────────────────────────────────────────────────────────
-- COMMANDS (Share / Revoke / List / Preview)
-- ─────────────────────────────────────────────────────────────
addCommandHandler("sharekey", function(player, cmd, targetName)
    local house = getCurrentHouseContext(player)
    if not house then
        outputChatBox("Housing: You must be inside or at the door of your property.", player, 255, 100, 100)
        return
    end

    if not isHouseOwner(player, house) then
        outputChatBox("Housing: You do not own this property.", player, 255, 100, 100)
        return
    end

    if not targetName then
        outputChatBox("Syntax: /sharekey [player account name]", player, 255, 200, 100)
        return
    end

    local targetOwnerKey = "account:" .. tostring(targetName)
    local grantCount = 0
    local grantedByKey = getAccountOwnerKey(player) or ""

    for _, propertyId in ipairs(getLinkedPropertyIds(house.id)) do
        if not hasPropertyKeyAccess(propertyId, targetOwnerKey) then
            exports.database_manager:grantPropertyKey(propertyId, targetOwnerKey, grantedByKey)
            grantCount = grantCount + 1
        end
    end

    if grantCount == 0 then
        outputChatBox("Housing: " .. targetName .. " already has access to this property set.", player, 255, 200, 50)
        return
    end

    outputChatBox("Housing: You gave access to account '" .. targetName .. "' for " .. tostring(grantCount) .. " linked property(s).", player, 100, 255, 100)
end)

addCommandHandler("housedebug", function(player)
    local enabled = not isHousingDebugEnabled(player)
    setElementData(player, "housing:debug", enabled, false)
    outputChatBox("[HousingDebug] " .. (enabled and "Enabled" or "Disabled") .. ".", player, 255, 220, 120, true)

    if not enabled then
        return
    end

    local px, py, pz = getElementPosition(player)
    debugHousing(player, string.format(
        "status playerPos=(%.2f, %.2f, %.2f) int=%d dim=%d",
        px,
        py,
        pz,
        tonumber(getElementInterior(player)) or 0,
        tonumber(getElementDimension(player)) or 0
    ))

    local house, markerType = getNearbyMarkerHouse(player)
    if not house then
        debugHousing(player, "status no nearby housing marker.")
        return
    end

    debugHousing(player, string.format(
        "status nearby house=%d marker=%s property=%s exterior=(%.2f, %.2f, %.2f) interiorSpawn=(%.2f, %.2f, %.2f)",
        tonumber(house.id) or 0,
        tostring(markerType),
        tostring(house.property_type),
        tonumber(house.exterior_x) or 0,
        tonumber(house.exterior_y) or 0,
        tonumber(house.exterior_z) or 0,
        tonumber(house.interior_x) or 0,
        tonumber(house.interior_y) or 0,
        tonumber(house.interior_z) or 0
    ))
end)

addCommandHandler("revokekey", function(player, cmd, targetName)
    local house = getCurrentHouseContext(player)
    if not house then
        outputChatBox("Housing: You must be inside or at the door of your property.", player, 255, 100, 100)
        return
    end

    if not isHouseOwner(player, house) then
        outputChatBox("Housing: You do not own this property.", player, 255, 100, 100)
        return
    end

    if not targetName then
        outputChatBox("Syntax: /revokekey [player account name]", player, 255, 200, 100)
        return
    end

    local targetOwnerKey = "account:" .. tostring(targetName)
    local revokeCount = 0
    for _, propertyId in ipairs(getLinkedPropertyIds(house.id)) do
        if hasPropertyKeyAccess(propertyId, targetOwnerKey) then
            exports.database_manager:revokePropertyKey(propertyId, targetOwnerKey)
            revokeCount = revokeCount + 1
        end
    end

    if revokeCount == 0 then
        outputChatBox("Housing: '" .. targetName .. "' does not have access to this property set.", player, 255, 200, 100)
        return
    end

    outputChatBox("Housing: Revoked access for '" .. targetName .. "' from " .. tostring(revokeCount) .. " linked property(s).", player, 255, 150, 100)
end)

addCommandHandler("myproperties", function(player)
    if isInPreview(player) then return end
    local pKey = getAccountOwnerKey(player)
    if not pKey then return end

    local count = 0
    outputChatBox("--- Your Properties ---", player, 200, 200, 255)
    for _, h in pairs(houses) do
        if h.owner_key == pKey then
            outputChatBox(" - " .. h.name .. " (ID: " .. h.id .. ")", player, 200, 255, 200)
            count = count + 1
        end
    end
    if count == 0 then
        outputChatBox(" You do not own any properties.", player, 200, 200, 200)
    end
end)

addCommandHandler("previewhouse", function(player)
    if isInPreview(player) then
        outputChatBox("Housing: You are already in preview mode.", player, 255, 80, 80)
        return
    end

    local house, mType = getNearbyMarkerHouse(player)
    if not house or mType ~= "exterior" then
        outputChatBox("Housing: You must be at an exterior property marker to preview it.", player, 255, 80, 80)
        return
    end

    if house.owner_key and house.owner_key ~= "" then
        outputChatBox("Housing: You can only preview unowned houses.", player, 255, 80, 80)
        return
    end

    triggerClientEvent(player, "rp_ui:hideHousePopup", root)

    -- Save return position
    local ex, ey, ez = getElementPosition(player)
    previewData[player] = {
        houseId = house.id,
        x   = ex, y = ey, z = ez,
        int = getElementInterior(player),
        dim = getElementDimension(player),
        rot = getPedRotation(player),
    }

    -- Unique dimension per player element (deterministic, no collisions)
    local previewDimension = getElementID(player) + 2000

    fadeCamera(player, false, 1.0)
    setTimer(function()
        if not isElement(player) then return end
        setElementInterior(player, house.interior_interior)
        setElementDimension(player, previewDimension)
        setElementPosition(player, house.interior_x, house.interior_y, house.interior_z)
        setPedRotation(player, house.interior_rot)
        fadeCamera(player, true, 1.0)

        outputChatBox("Housing: Previewing " .. house.name .. " for 60 seconds. Press [F] at the door to exit.", player, 120, 255, 255)

        previewTimers[player] = setTimer(function(p)
            if not isElement(p) then return end
            if not previewData[p] then return end
            cleanUpPreview(p, true)
        end, 60000, 1, player)
    end, 1000, 1)
end)

-- ─────────────────────────────────────────────────────────────
-- FIRST-TIME PLAYER FREE APARTMENT
-- ─────────────────────────────────────────────────────────────
addEventHandler("onPlayerLogin", root, function(_, account)
    if not account or isGuestAccount(account) then return end

    if not getAccountData(account, "free_apartment_given") then
        local pKey  = getAccountOwnerKey(source)
        local aName = getAccountName(account)

        -- Allocate next house ID
        local maxRow = centralQuery("SELECT MAX(id) AS maxid FROM houses")[1]
        local newId  = (tonumber(maxRow and maxRow.maxid) or 0) + 1
        local newDim = 6000 + newId

        centralExecute([[
            INSERT INTO houses (
                id, name, price, property_type, owner_key, owner_account, locked,
                exterior_x, exterior_y, exterior_z, exterior_rot, exterior_interior,
                interior_x, interior_y, interior_z, interior_rot, interior_id, dimension
            ) VALUES (?, ?, 0, 'apartment', ?, ?, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]],
            newId, "Free Apartment (Unit " .. newId .. ")", pKey, aName,
            FREE_APT_EXTERIOR_X, FREE_APT_EXTERIOR_Y, FREE_APT_EXTERIOR_Z, FREE_APT_EXTERIOR_ROT, FREE_APT_EXTERIOR_INT,
            FREE_APT_INTERIOR_X, FREE_APT_INTERIOR_Y, FREE_APT_INTERIOR_Z, FREE_APT_INTERIOR_ROT, FREE_APT_INTERIOR_INT, newDim
        )

        setAccountData(account, "free_apartment_given", true)

        outputChatBox("-------------------------------------------", source, 100, 255, 100)
        outputChatBox("Welcome " .. getPlayerName(source) .. "! As a new citizen, you have been assigned", source, 255, 255, 255)
        outputChatBox("a free apartment located in Jefferson, Los Santos.", source, 255, 255, 255)
        outputChatBox("Look for the yellow house blip on your minimap/F11.", source, 255, 255, 255)
        outputChatBox("-------------------------------------------", source, 100, 255, 100)

        reloadHouses()
    end
end)
