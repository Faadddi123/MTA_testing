-- housing/server.lua
-- Main logic for RP housing system

local houses = {}
local entryMarkers = {}
local exitMarkers = {}
local houseBlips = {}

-- Exterior coordinate for the Free Apartment (Jefferson Hotel in Los Santos)
local FREE_APT_EXTERIOR_X = 2271.74
local FREE_APT_EXTERIOR_Y = -1139.75
local FREE_APT_EXTERIOR_Z = 25.80
local FREE_APT_EXTERIOR_ROT = 90
local FREE_APT_EXTERIOR_INT = 0

-- Interior coordinate for the Free Apartment (apartment_small preset, Interior 1)
local FREE_APT_INTERIOR_X = 266.50
local FREE_APT_INTERIOR_Y = 304.90
local FREE_APT_INTERIOR_Z = 999.15
local FREE_APT_INTERIOR_ROT = 0
local FREE_APT_INTERIOR_INT = 1


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

-- ─────────────────────────────────────────────────────────────
-- CLEANUP / LOAD / RELOAD
-- ─────────────────────────────────────────────────────────────

local function destroyHouseElements()
    for marker in pairs(entryMarkers) do if isElement(marker) then destroyElement(marker) end end
    for marker in pairs(exitMarkers) do if isElement(marker) then destroyElement(marker) end end
    for blip in pairs(houseBlips) do if isElement(blip) then destroyElement(blip) end end
    entryMarkers = {}
    exitMarkers = {}
    houseBlips = {}
end

-- Exported reload function used by house_manager
function reloadHouses()
    destroyHouseElements()
    houses = {}

    local rows = centralQuery("SELECT * FROM houses")
    for _, row in ipairs(rows) do
        local h = {
            id = tonumber(row.id),
            name = row.name,
            price = tonumber(row.price) or 0,
            property_type = row.property_type or "house",
            owner_key = row.owner_key or "",
            owner_account = row.owner_account or "",
            locked = (tonumber(row.locked) == 1),
            dimension = tonumber(row.dimension) or 0,
            
            exterior_x = tonumber(row.exterior_x),
            exterior_y = tonumber(row.exterior_y),
            exterior_z = tonumber(row.exterior_z),
            exterior_rot = tonumber(row.exterior_rot) or 0,
            exterior_interior = tonumber(row.exterior_interior) or 0,

            interior_x = tonumber(row.interior_x),
            interior_y = tonumber(row.interior_y),
            interior_z = tonumber(row.interior_z),
            interior_rot = tonumber(row.interior_rot) or 0,
            interior_interior = tonumber(row.interior_id) or 0,

            exterior = { interior = tonumber(row.exterior_interior) or 0 },
            garage = {
                x = tonumber(row.garage_x) or 0,
                y = tonumber(row.garage_y) or 0,
                z = tonumber(row.garage_z) or 0,
                radius = tonumber(row.garage_radius) or 6,
            },
            garage_int = {
                x = tonumber(row.garage_int_x) or 0,
                y = tonumber(row.garage_int_y) or 0,
                z = tonumber(row.garage_int_z) or 0,
                rotation = tonumber(row.garage_int_rot) or 0,
            }
        }

        houses[h.id] = h

        -- Map Elements
        if h.exterior_x and h.exterior_y and h.exterior_z then
            -- Exterior Marker (Yellow)
            local extMarker = createMarker(h.exterior_x, h.exterior_y, h.exterior_z + 0.5, "arrow", 2.0, 255, 255, 0, 150)
            setElementInterior(extMarker, h.exterior_interior)
            setElementDimension(extMarker, 0)
            setElementData(extMarker, "housing:houseId", h.id, false)
            entryMarkers[extMarker] = h.id

            -- Map Blip (GTA SA natively uses 31 for properties)
            local icon = 31
            local blip = createBlip(h.exterior_x, h.exterior_y, h.exterior_z, icon, 1, 255, 255, 255, 255, 0, 200)
            setElementInterior(blip, h.exterior_interior)
            setElementDimension(blip, 0)
            houseBlips[blip] = h.id
        end

        if h.interior_x and h.interior_y and h.interior_z then
            -- Interior Exit Marker (Orange)
            local intMarker = createMarker(h.interior_x, h.interior_y, h.interior_z - 1.0, "arrow", 1.5, 255, 120, 0, 150)
            setElementInterior(intMarker, h.interior_interior)
            setElementDimension(intMarker, h.dimension)
            setElementData(intMarker, "housing:houseId", h.id, false)
            exitMarkers[intMarker] = h.id
        end
    end
end
addEventHandler("onResourceStart", resourceRoot, reloadHouses)


-- ─────────────────────────────────────────────────────────────
-- ACCESS HELPERS
-- ─────────────────────────────────────────────────────────────

local function isHouseOwner(player, house)
    local pKey = getAccountOwnerKey(player)
    return pKey and pKey ~= "" and house.owner_key == pKey
end

local function hasHouseKey(player, houseId)
    local pKey = getAccountOwnerKey(player)
    if not pKey or pKey == "" then return false end
    
    local rows = centralQuery("SELECT id FROM property_keys WHERE house_id = ? AND account_name = ?", houseId, getAccountNameForKeys(player))
    return #rows > 0
end

local function canAccessHouse(player, house)
    if not house.owner_key or house.owner_key == "" then return true end -- For sale (unowned)
    if isHouseOwner(player, house) then return true end
    if not house.locked then return true end
    return hasHouseKey(player, house.id)
end

-- Exported access check
function checkHouseAccess(houseId, ownerKey)
    local h = houses[tonumber(houseId)]
    if not h then return false end
    if h.owner_key == ownerKey then return true end
    
    local rows = centralQuery("SELECT account_name FROM property_keys WHERE house_id = ?", h.id)
    for _, row in ipairs(rows) do
        local accKey = "account:" .. tostring(row.account_name)
        if accKey == ownerKey then return true end
    end
    return false
end

-- Exported full house data
function getHouseData(houseId)
    return houses[tonumber(houseId)] or false
end

-- Exported garage position check
function getOwnedGarageHouseIdForPosition(ownerKey, x, y, z)
    if not ownerKey or ownerKey == "" then return false end
    for id, h in pairs(houses) do
        if h.owner_key == ownerKey then
            local dist = getDistanceBetweenPoints3D(x, y, z, h.garage_x, h.garage_y, h.garage_z)
            if dist <= h.garage_radius then return h.id end
        end
    end
    return false
end

-- ─────────────────────────────────────────────────────────────
-- UI AND NOTIFICATIONS
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

local function showHousePopup(player, house)
    local payload = {
        id = house.id,
        name = house.name,
        property_type = house.property_type,
        ownerName = (house.owner_key ~= "") and house.owner_account or "Available",
        price = house.price,
        locked = house.locked,
        canBuy = (house.owner_key == ""),
        canEnter = canAccessHouse(player, house),
        canLock = isHouseOwner(player, house),
        canPark = false -- parking handled by garage system/vehicles resource if needed
    }
    triggerClientEvent(player, "rp_ui:showHousePopup", root, payload)
end

addEventHandler("onMarkerHit", resourceRoot, function(player, matchDim)
    if not matchDim or getElementType(player) ~= "player" then return end
    if isPedInVehicle(player) then return end

    local houseId = entryMarkers[source] or exitMarkers[source]
    if houseId and houses[houseId] then
        showHousePopup(player, houses[houseId])
        
        -- Additional chat fallback if UI doesn't catch it
        local h = houses[houseId]
        if h.owner_key == "" then
            outputChatBox("Housing: " .. h.name .. " is for sale for " .. formatMoney(h.price) .. ". Press [B] to buy.", player, 100, 255, 100)
        else
            if isHouseOwner(player, h) then
                local st = h.locked and "Locked" or "Unlocked"
                outputChatBox("Housing: Your " .. h.property_type .. " (" .. st .. "). Press [F] Enter, [G] Lock.", player, 100, 255, 100)
            else
                outputChatBox("Housing: " .. h.name .. ". Owner: " .. h.owner_account .. ".", player, 200, 200, 200)
            end
        end
    end
end)

addEventHandler("onMarkerLeave", resourceRoot, function(player, matchDim)
    if not matchDim or getElementType(player) ~= "player" then return end
    triggerClientEvent(player, "rp_ui:hideHousePopup", root)
end)


-- ─────────────────────────────────────────────────────────────
-- INTERACT ACTIONS (F, B, G)
-- ─────────────────────────────────────────────────────────────

addEvent("housing:requestEnter", true)
addEventHandler("housing:requestEnter", root, function()
    local house, mType = getNearbyMarkerHouse(client)
    if not house then return end

    if mType == "exterior" then
        if not canAccessHouse(client, house) then
            outputChatBox("Housing: The door is locked.", client, 255, 80, 80)
            return
        end
        triggerClientEvent(client, "rp_ui:hideHousePopup", root)
        setElementInterior(client, house.interior_interior)
        setElementDimension(client, house.dimension)
        setElementPosition(client, house.interior_x, house.interior_y, house.interior_z)
        setPedRotation(client, house.interior_rot)
    elseif mType == "interior" then
        triggerClientEvent(client, "rp_ui:hideHousePopup", root)
        setElementInterior(client, house.exterior_interior)
        setElementDimension(client, 0)
        setElementPosition(client, house.exterior_x, house.exterior_y, house.exterior_z)
        setPedRotation(client, house.exterior_rot)
    end
end)

addEvent("housing:requestBuy", true)
addEventHandler("housing:requestBuy", root, function()
    local house, mType = getNearbyMarkerHouse(client)
    if not house or mType ~= "exterior" then return end

    if house.owner_key ~= "" then
        outputChatBox("Housing: This property is already owned.", client, 255, 80, 80)
        return
    end

    local money = getPlayerMoney(client)
    if money < house.price then
        outputChatBox("Housing: You don't have enough money (" .. formatMoney(house.price) .. ").", client, 255, 80, 80)
        return
    end

    takePlayerMoney(client, house.price)
    house.owner_key = getAccountOwnerKey(client)
    house.owner_account = getAccountNameForKeys(client)
    house.locked = true

    centralExecute("UPDATE houses SET owner_key = ?, owner_account = ?, locked = 1 WHERE id = ?", house.owner_key, house.owner_account, house.id)
    outputChatBox("Housing: You successfully bought " .. house.name .. " for " .. formatMoney(house.price) .. "!", client, 100, 255, 100)
    
    showHousePopup(client, house)
end)

addEvent("housing:requestToggleLock", true)
addEventHandler("housing:requestToggleLock", root, function()
    local house = getNearbyMarkerHouse(client)
    if not house then
        -- Also try to check if they are inside their dimension
        if getElementDimension(client) > 6000 then
            local possibleId = getElementDimension(client) - 6000
            if houses[possibleId] then house = houses[possibleId] end
        end
    end

    if not house then return end

    if not isHouseOwner(client, house) and not hasHouseKey(client, house.id) then
        outputChatBox("Housing: You do not have the keys to this property.", client, 255, 80, 80)
        return
    end

    house.locked = not house.locked
    centralExecute("UPDATE houses SET locked = ? WHERE id = ?", house.locked and 1 or 0, house.id)
    
    local txt = house.locked and "locked" or "unlocked"
    outputChatBox("Housing: You " .. txt .. " the property.", client, 200, 255, 200)

    showHousePopup(client, house)
end)

-- ─────────────────────────────────────────────────────────────
-- COMMANDS (Share / Revoke / List)
-- ─────────────────────────────────────────────────────────────

addCommandHandler("sharekey", function(player, cmd, targetName)
    local houseId = (getElementDimension(player) > 6000) and (getElementDimension(player) - 6000) or nil
    if not houseId and getNearbyMarkerHouse(player) then
        houseId = getNearbyMarkerHouse(player).id
    end

    if not houseId or not houses[houseId] then
        outputChatBox("Housing: You must be inside or at the door of your property.", player, 255, 100, 100)
        return
    end

    if not isHouseOwner(player, houses[houseId]) then
        outputChatBox("Housing: You do not own this property.", player, 255, 100, 100)
        return
    end

    if not targetName then
        outputChatBox("Syntax: /sharekey [player account name]", player, 255, 200, 100)
        return
    end

    local rows = centralQuery("SELECT id FROM property_keys WHERE house_id = ? AND account_name = ?", houseId, targetName)
    if #rows > 0 then
        outputChatBox("Housing: " .. targetName .. " already has a key.", player, 255, 200, 50)
        return
    end

    centralExecute("INSERT INTO property_keys (house_id, account_name) VALUES (?, ?)", houseId, targetName)
    outputChatBox("Housing: You gave a key to account '" .. targetName .. "'.", player, 100, 255, 100)
end)

addCommandHandler("revokekey", function(player, cmd, targetName)
    if not targetName then
        outputChatBox("Syntax: /revokekey [player account name]", player, 255, 200, 100)
        return
    end
    centralExecute("DELETE FROM property_keys WHERE account_name = ?", targetName)
    outputChatBox("Housing: Revoked all keys for '" .. targetName .. "'.", player, 255, 150, 100)
end)

addCommandHandler("myproperties", function(player)
    local pKey = getAccountOwnerKey(player)
    if not pKey then return end

    local count = 0
    outputChatBox("--- Your Properties ---", player, 200, 200, 255)
    for id, h in pairs(houses) do
        if h.owner_key == pKey then
            outputChatBox(" - " .. h.name .. " (ID: " .. h.id .. ")", player, 200, 255, 200)
            count = count + 1
        end
    end
    if count == 0 then
        outputChatBox(" You do not own any properties.", player, 200, 200, 200)
    end
end)

-- ─────────────────────────────────────────────────────────────
-- FIRST-TIME PLAYER FREE APARTMENT
-- ─────────────────────────────────────────────────────────────

addEventHandler("onPlayerLogin", root, function(_, account)
    if not account or isGuestAccount(account) then return end
    
    if not getAccountData(account, "free_apartment_given") then
        local pKey = getAccountOwnerKey(source)
        local aName = getAccountName(account)
        
        -- Allocate House ID
        local maxRow = centralQuery("SELECT MAX(id) AS maxid FROM houses")[1]
        local newId = (tonumber(maxRow and maxRow.maxid) or 0) + 1
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

        -- Reload everything to spawn the new marker
        reloadHouses()
    end
end)
