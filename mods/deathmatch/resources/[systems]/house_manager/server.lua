-- house_manager/server.lua
-- Admin tooling for separate house and garage property creation, linking, and maintenance.

local function isAdmin(player)
    return isObjectInACLGroup("user." .. getAccountName(getPlayerAccount(player)), aclGetGroup("Admin")) or true
end

local function centralQuery(query, ...)
    return exports.database_manager:dbQuery(query, ...) or {}
end

local function centralExecute(query, ...)
    return exports.database_manager:dbExecute(query, ...)
end

local INTERIOR_CATALOG = {
    studio = {
        label = "Studio Flat", size = "small",
        x = 2233.64, y = -1115.26, z = 1050.88,
        exit_x = 2238.50, exit_y = -1115.26, exit_z = 1050.88,
        interior = 5,
    },
    apartment_small = {
        label = "Small Apartment", size = "small",
        x = 266.50, y = 304.90, z = 999.15,
        exit_x = 270.00, exit_y = 304.90, exit_z = 999.15,
        interior = 1,
    },
    apartment_medium = {
        label = "2-Room Apartment", size = "medium",
        x = 2317.89, y = -1026.76, z = 1050.22,
        exit_x = 2322.00, exit_y = -1026.76, exit_z = 1050.22,
        interior = 9,
    },
    apartment_large = {
        label = "3-Room Apartment", size = "large",
        x = 2324.53, y = -1149.54, z = 1050.71,
        exit_x = 2329.00, exit_y = -1149.54, exit_z = 1050.71,
        interior = 12,
    },
    penthouse = {
        label = "Penthouse", size = "large",
        x = 2365.31, y = -1135.60, z = 1050.88,
        exit_x = 2370.00, exit_y = -1135.60, exit_z = 1050.88,
        interior = 8,
    },
    villa = {
        label = "Villa", size = "large",
        x = 225.68, y = 1021.45, z = 1084.02,
        exit_x = 230.00, exit_y = 1021.45, exit_z = 1084.02,
        interior = 7,
    },
    mansion = {
        label = "Mansion", size = "large",
        x = 1260.64, y = -785.37, z = 1091.91,
        exit_x = 1265.00, exit_y = -785.37, exit_z = 1091.91,
        interior = 5,
    },
    warehouse = {
        label = "Warehouse", size = "large",
        x = 140.17, y = 1366.07, z = 1083.65,
        exit_x = 145.00, exit_y = 1366.07, exit_z = 1083.65,
        interior = 5,
    },
    garage_small = {
        label = "Small Garage", size = "small",
        x = 299.78, y = 309.89, z = 1003.30,
        exit_x = 303.00, exit_y = 309.89, exit_z = 1003.30,
        interior = 4,
    },
    garage_large = {
        label = "Large Garage", size = "medium",
        x = -283.44, y = 1470.93, z = 1084.38,
        exit_x = -278.00, exit_y = 1470.93, exit_z = 1084.38,
        interior = 15,
    },
}

local CATEGORY_TO_TYPE = {
    studio = "apartment",
    apartment_small = "apartment",
    apartment_medium = "apartment",
    apartment_large = "apartment",
    penthouse = "apartment",
    villa = "house",
    mansion = "house",
    warehouse = "house",
    garage_small = "garage",
    garage_large = "garage",
}

local HOUSE_CATEGORY_KEYS = {
    "studio",
    "apartment_small",
    "apartment_medium",
    "apartment_large",
    "penthouse",
    "villa",
    "mansion",
    "warehouse",
}

local GARAGE_CATEGORY_KEYS = {
    "garage_small",
    "garage_large",
}

local previewReturn = {}

local function getNextPropertyId()
    local row = centralQuery("SELECT MAX(id) AS maxid FROM houses")[1]
    return math.floor(tonumber(row and row.maxid) or 0) + 1
end

local function getPropertyRow(propertyId)
    propertyId = tonumber(propertyId)
    if not propertyId then
        return nil
    end
    return centralQuery("SELECT * FROM houses WHERE id = ? LIMIT 1", propertyId)[1]
end

local function isGarageType(propertyRow)
    return propertyRow and propertyRow.property_type == "garage"
end

local function buildCatalogPayload()
    local function collect(keys)
        local result = {}
        for _, key in ipairs(keys) do
            local preset = INTERIOR_CATALOG[key]
            if preset then
                result[#result + 1] = {
                    key = key,
                    label = preset.label,
                    size = preset.size,
                    property_type = CATEGORY_TO_TYPE[key] or "house",
                }
            end
        end
        return result
    end

    return {
        houses = collect(HOUSE_CATEGORY_KEYS),
        garages = collect(GARAGE_CATEGORY_KEYS),
    }
end

local function sendCatalog(player)
    triggerClientEvent(player, "hm:receiveCatalog", player, buildCatalogPayload())
end

local function sendPropertiesList(player)
    local rows = centralQuery([[
        SELECT id, name, price, property_type, owner_account, locked, linked_property_id
        FROM houses
        ORDER BY id ASC
    ]])

    local namesById = {}
    for _, row in ipairs(rows) do
        namesById[tonumber(row.id)] = row.name
    end

    local list = {}
    for _, row in ipairs(rows) do
        local linkedId = tonumber(row.linked_property_id)
        list[#list + 1] = {
            id = tonumber(row.id),
            name = row.name,
            price = math.floor(tonumber(row.price) or 0),
            ptype = row.property_type or "house",
            owner = row.owner_account or "",
            locked = (tonumber(row.locked) or 0) ~= 0,
            linked_id = linkedId,
            linked_name = linkedId and namesById[linkedId] or "",
        }
    end

    triggerClientEvent(player, "hm:receiveList", player, list)
end

local function reloadHousing()
    setTimer(function()
        local resource = getResourceFromName("housing")
        if resource then
            restartResource(resource)
        end
    end, 400, 1)
end

local function clearLinkForProperty(propertyId)
    propertyId = tonumber(propertyId)
    if not propertyId then
        return
    end

    local row = getPropertyRow(propertyId)
    local linkedId = row and tonumber(row.linked_property_id) or nil

    centralExecute("UPDATE houses SET linked_property_id = NULL WHERE id = ? OR linked_property_id = ?", propertyId, propertyId)
    if linkedId then
        centralExecute("UPDATE houses SET linked_property_id = NULL WHERE id = ? OR linked_property_id = ?", linkedId, linkedId)
    end
end

local function syncOwnershipBetweenLinkedRows(sourceRow, targetRow)
    if not sourceRow or not targetRow then
        return true, nil
    end

    local sourceOwner = tostring(sourceRow.owner_key or "")
    local targetOwner = tostring(targetRow.owner_key or "")

    if sourceOwner ~= "" and targetOwner ~= "" and sourceOwner ~= targetOwner then
        return false, "Linked properties already belong to different owners."
    end

    if sourceOwner ~= "" and targetOwner == "" then
        centralExecute(
            "UPDATE houses SET owner_key = ?, owner_account = ?, locked = ? WHERE id = ?",
            sourceRow.owner_key,
            sourceRow.owner_account,
            tonumber(sourceRow.locked) or 0,
            tonumber(targetRow.id)
        )
    elseif targetOwner ~= "" and sourceOwner == "" then
        centralExecute(
            "UPDATE houses SET owner_key = ?, owner_account = ?, locked = ? WHERE id = ?",
            targetRow.owner_key,
            targetRow.owner_account,
            tonumber(targetRow.locked) or 0,
            tonumber(sourceRow.id)
        )
    elseif sourceOwner ~= "" and targetOwner ~= "" then
        centralExecute(
            "UPDATE houses SET locked = ? WHERE id IN (?, ?)",
            tonumber(sourceRow.locked) or 0,
            tonumber(sourceRow.id),
            tonumber(targetRow.id)
        )
    end

    return true, nil
end

local function linkProperties(propertyId, targetId)
    local sourceRow = getPropertyRow(propertyId)
    local targetRow = getPropertyRow(targetId)
    if not sourceRow or not targetRow then
        return false, "One of the selected properties does not exist."
    end

    if tonumber(sourceRow.id) == tonumber(targetRow.id) then
        return false, "A property cannot be linked to itself."
    end

    if isGarageType(sourceRow) == isGarageType(targetRow) then
        return false, "Links must connect one garage and one house/apartment."
    end

    local ok, err = syncOwnershipBetweenLinkedRows(sourceRow, targetRow)
    if not ok then
        return false, err
    end

    clearLinkForProperty(sourceRow.id)
    clearLinkForProperty(targetRow.id)

    centralExecute("UPDATE houses SET linked_property_id = ? WHERE id = ?", tonumber(targetRow.id), tonumber(sourceRow.id))
    centralExecute("UPDATE houses SET linked_property_id = ? WHERE id = ?", tonumber(sourceRow.id), tonumber(targetRow.id))

    return true, "Linked #" .. tostring(sourceRow.id) .. " with #" .. tostring(targetRow.id) .. "."
end

local function unlinkProperty(propertyId)
    local row = getPropertyRow(propertyId)
    if not row then
        return false, "Property not found."
    end

    local linkedId = tonumber(row.linked_property_id)
    if not linkedId then
        return false, "Property is not linked."
    end

    clearLinkForProperty(row.id)
    return true, "Removed link between #" .. tostring(row.id) .. " and #" .. tostring(linkedId) .. "."
end

local function releaseGarageVehicles(propertyId)
    local vehiclesResource = getResourceFromName("vehicles")
    if not vehiclesResource or getResourceState(vehiclesResource) ~= "running" then
        return
    end
    exports.vehicles:releaseHouseVehicles(propertyId)
end

addEvent("hm:requestCatalog", true)
addEventHandler("hm:requestCatalog", root, function()
    local player = client
    if not isAdmin(player) then
        return
    end
    sendCatalog(player)
end)

addEvent("hm:requestPreview", true)
addEventHandler("hm:requestPreview", root, function(categoryKey)
    local player = client
    if not isAdmin(player) then
        return
    end

    local preset = INTERIOR_CATALOG[tostring(categoryKey or "")]
    if not preset then
        outputChatBox("[HouseAdmin] Unknown category: " .. tostring(categoryKey), player, 255, 80, 80, true)
        return
    end

    local ox, oy, oz = getElementPosition(player)
    previewReturn[player] = {
        x = ox,
        y = oy,
        z = oz,
        interior = getElementInterior(player),
        dimension = getElementDimension(player),
    }

    setElementInterior(player, preset.interior)
    setElementDimension(player, 99998)
    setElementPosition(player, preset.x, preset.y, preset.z)

    outputChatBox("[Preview] You are inside: " .. preset.label, player, 100, 230, 255, true)
    outputChatBox("[Preview] Type /exitpreview or click the button to return.", player, 200, 200, 200, true)
end)

addEvent("hm:exitPreview", true)
addEventHandler("hm:exitPreview", root, function()
    local player = client
    local ret = previewReturn[player]
    if not ret then
        return
    end

    setElementInterior(player, ret.interior)
    setElementDimension(player, ret.dimension)
    setElementPosition(player, ret.x, ret.y, ret.z)
    previewReturn[player] = nil

    outputChatBox("[Preview] Returned to your original position.", player, 120, 255, 120, true)
end)

addCommandHandler("exitpreview", function(player)
    local ret = previewReturn[player]
    if not ret then
        outputChatBox("[Preview] You are not in preview mode.", player, 255, 150, 50, true)
        return
    end

    setElementInterior(player, ret.interior)
    setElementDimension(player, ret.dimension)
    setElementPosition(player, ret.x, ret.y, ret.z)
    previewReturn[player] = nil

    outputChatBox("[Preview] Returned to your original position.", player, 120, 255, 120, true)
end)

addEventHandler("onPlayerQuit", root, function()
    previewReturn[source] = nil
end)

addEvent("hm:requestCreate", true)
addEventHandler("hm:requestCreate", root, function(data)
    local player = client
    if not isAdmin(player) then
        outputChatBox("[HouseAdmin] No access.", player, 255, 80, 80, true)
        return
    end

    local category = tostring(data and data.category or ""):lower()
    local preset = INTERIOR_CATALOG[category]
    local propertyType = CATEGORY_TO_TYPE[category]
    if not preset or not propertyType then
        outputChatBox("[HouseAdmin] Invalid category: " .. tostring(category), player, 255, 80, 80, true)
        return
    end

    local name = tostring(data and data.name or "New Property"):sub(1, 48)
    local price = math.max(1000, math.min(10000000, math.floor(tonumber(data and data.price or 50000) or 50000)))
    local linkTo = tonumber(data and data.link_to)

    local ex, ey, ez = getElementPosition(player)
    local exteriorRot = getPedRotation(player)
    local exteriorInterior = getElementInterior(player)
    local newId = getNextPropertyId()
    local dimensionBase = propertyType == "garage" and 7000 or 6000
    local propertyDimension = dimensionBase + newId

    centralExecute([[
        INSERT OR IGNORE INTO houses (
            id, name, price, property_type, linked_property_id, owner_key, owner_account, locked,
            exterior_x, exterior_y, exterior_z, exterior_rot, exterior_interior,
            interior_x, interior_y, interior_z, interior_rot, interior_id, dimension,
            garage_x, garage_y, garage_z, garage_radius,
            garage_int_x, garage_int_y, garage_int_z, garage_int_rot
        ) VALUES (?, ?, ?, ?, NULL, NULL, NULL, 1, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, 0, 0, 0, 8, 0, 0, 0, 0)
    ]],
        newId,
        name,
        price,
        propertyType,
        ex,
        ey,
        ez,
        exteriorRot,
        exteriorInterior,
        preset.x,
        preset.y,
        preset.z,
        preset.interior,
        propertyDimension
    )

    if linkTo then
        local ok, err = linkProperties(newId, linkTo)
        if not ok then
            outputChatBox("[HouseAdmin] Created property #" .. tostring(newId) .. " but link failed: " .. tostring(err), player, 255, 180, 60, true)
        end
    end

    outputChatBox(string.format(
        "[HouseAdmin] Created '%s' (#%d, %s, $%d).",
        name,
        newId,
        propertyType,
        price
    ), player, 120, 255, 120, true)

    reloadHousing()
    sendPropertiesList(player)
end)

addEvent("hm:requestLink", true)
addEventHandler("hm:requestLink", root, function(propertyId, targetId)
    local player = client
    if not isAdmin(player) then
        return
    end

    local ok, message = linkProperties(propertyId, targetId)
    outputChatBox("[HouseAdmin] " .. tostring(message), player, ok and 120 or 255, ok and 255 or 80, ok and 120 or 80, true)
    if ok then
        reloadHousing()
        sendPropertiesList(player)
    end
end)

addEvent("hm:requestUnlink", true)
addEventHandler("hm:requestUnlink", root, function(propertyId)
    local player = client
    if not isAdmin(player) then
        return
    end

    local ok, message = unlinkProperty(propertyId)
    outputChatBox("[HouseAdmin] " .. tostring(message), player, ok and 255 or 255, ok and 200 or 120, ok and 80 or 120, true)
    if ok then
        reloadHousing()
        sendPropertiesList(player)
    end
end)

addEvent("hm:requestDelete", true)
addEventHandler("hm:requestDelete", root, function(propertyId)
    local player = client
    if not isAdmin(player) then
        return
    end

    propertyId = tonumber(propertyId)
    local row = getPropertyRow(propertyId)
    if not row then
        outputChatBox("[HouseAdmin] Property #" .. tostring(propertyId) .. " not found.", player, 255, 80, 80, true)
        triggerClientEvent(player, "hm:deleteResult", player, false, propertyId)
        return
    end

    clearLinkForProperty(propertyId)
    releaseGarageVehicles(propertyId)
    centralExecute("DELETE FROM property_keys WHERE house_id = ?", propertyId)
    centralExecute("DELETE FROM houses WHERE id = ?", propertyId)

    outputChatBox("[HouseAdmin] Deleted '" .. tostring(row.name) .. "' (#" .. tostring(propertyId) .. ").", player, 255, 160, 60, true)
    triggerClientEvent(player, "hm:deleteResult", player, true, propertyId)
    reloadHousing()
end)

addEvent("hm:requestUpdate", true)
addEventHandler("hm:requestUpdate", root, function(propertyId, name, price)
    local player = client
    if not isAdmin(player) then
        return
    end

    propertyId = tonumber(propertyId)
    name = tostring(name or ""):sub(1, 48)
    price = math.max(1000, math.floor(tonumber(price) or 0))
    if not propertyId or name == "" then
        return
    end

    centralExecute("UPDATE houses SET name = ?, price = ? WHERE id = ?", name, price, propertyId)
    outputChatBox("[HouseAdmin] Updated property #" .. tostring(propertyId) .. ".", player, 120, 255, 120, true)
    reloadHousing()
    sendPropertiesList(player)
end)

addEvent("hm:requestList", true)
addEventHandler("hm:requestList", root, function()
    local player = client
    if not isAdmin(player) then
        return
    end
    sendPropertiesList(player)
end)

addEvent("hm:requestTeleport", true)
addEventHandler("hm:requestTeleport", root, function(propertyId)
    local player = client
    if not isAdmin(player) then
        return
    end

    previewReturn[player] = nil

    local row = centralQuery("SELECT exterior_x, exterior_y, exterior_z, exterior_interior FROM houses WHERE id = ? LIMIT 1", tonumber(propertyId))[1]
    if not row then
        outputChatBox("[HouseAdmin] Property #" .. tostring(propertyId) .. " not found.", player, 255, 80, 80, true)
        return
    end

    setElementInterior(player, tonumber(row.exterior_interior) or 0)
    setElementDimension(player, 0)
    setElementPosition(player, tonumber(row.exterior_x), tonumber(row.exterior_y), tonumber(row.exterior_z) + 1)
    outputChatBox("[HouseAdmin] Teleported to property #" .. tostring(propertyId) .. ".", player, 120, 255, 180, true)
end)

addEvent("hm:requestTeleportInterior", true)
addEventHandler("hm:requestTeleportInterior", root, function(propertyId)
    local player = client
    if not isAdmin(player) then
        return
    end

    local row = centralQuery("SELECT interior_x, interior_y, interior_z, interior_id, dimension FROM houses WHERE id = ? LIMIT 1", tonumber(propertyId))[1]
    if not row then
        return
    end

    setElementInterior(player, tonumber(row.interior_id) or 0)
    setElementDimension(player, tonumber(row.dimension) or 0)
    setElementPosition(player, tonumber(row.interior_x), tonumber(row.interior_y), tonumber(row.interior_z))
    outputChatBox("[HouseAdmin] Teleported to property interior #" .. tostring(propertyId) .. ".", player, 120, 255, 180, true)
end)

local function openPanel(player)
    if not isAdmin(player) then
        outputChatBox("[HouseAdmin] You do not have admin access.", player, 255, 80, 80, true)
        return
    end

    triggerClientEvent(player, "hm:openPanel", player)
    sendCatalog(player)
    sendPropertiesList(player)
end

addCommandHandler("houseadmin", openPanel)
addCommandHandler("ha", openPanel)
