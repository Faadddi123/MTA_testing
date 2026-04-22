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

local HOUSE_EXTERIOR_CREATE_Z_OFFSET = -0.50

local INTERIOR_CATALOG = {
    -- ─── Native GTA:SA Interiors ─────────────────────────────────
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
        label = "Small Garage (Shell)", size = "small",
        x = 2233.64, y = -1115.26, z = 1050.88,
        exit_x = 2238.50, exit_y = -1115.26, exit_z = 1050.88,
        interior = 5,
    },
    garage_large = {
        label = "Large Garage (Warehouse Shell)", size = "medium",
        x = 140.17, y = 1366.07, z = 1083.65,
        exit_x = 145.00, exit_y = 1366.07, exit_z = 1083.65,
        interior = 5,
    },

    -- ─── Custom Interiors (multitheftauto-custominteriors) ────────
    -- Residential
    custom_modern_small_house = {
        label = "Modern Small House (Custom)", size = "medium",
        x = 1482.76, y = 1529.41, z = 6.12,
        exit_x = 1486.76, exit_y = 1529.41, exit_z = 6.12,
        interior = 1,
        custom_map = "int_ModernSmallHouse",
    },
    custom_modern_condo = {
        label = "Modern Condo (Custom)", size = "large",
        x = 1389.38, y = 1492.08, z = 5.33,
        exit_x = 1393.38, exit_y = 1492.08, exit_z = 5.33,
        interior = 1,
        custom_map = "Int_ModernCondo",
    },
    custom_modern_mansion = {
        label = "Modern Mansion (Custom)", size = "large",
        x = 1448.94, y = 1563.74, z = 6.46,
        exit_x = 1452.94, exit_y = 1563.74, exit_z = 6.46,
        interior = 1,
        custom_map = "Int_ModernMansion",
    },
    custom_modern_mansion2 = {
        label = "Modern Mansion 2 (Custom)", size = "large",
        x = 1417.66, y = 1388.75, z = 5.02,
        exit_x = 1421.66, exit_y = 1388.75, exit_z = 5.02,
        interior = 1,
        custom_map = "Int_ModernMansion2",
    },

    -- Commercial / Public
    custom_italian_bistro = {
        label = "Italian Bistro (Custom)", size = "medium",
        x = -1983.35, y = 1325.79, z = 34.08,
        exit_x = -1979.35, exit_y = 1325.79, exit_z = 34.08,
        interior = 1,
        custom_map = "int_ItalianBistro",
    },
    custom_asian_restaurant = {
        label = "Asian Restaurant (Custom)", size = "medium",
        x = 1528.86, y = 1615.24, z = 3.97,
        exit_x = 1532.86, exit_y = 1615.24, exit_z = 3.97,
        interior = 1,
        custom_map = "int_AsianResteraunt",
    },
    custom_butcher = {
        label = "Butcher Shop (Custom)", size = "small",
        x = 970.30, y = 2141.75, z = 1079.00,
        exit_x = 974.30, exit_y = 2141.75, exit_z = 1079.00,
        interior = 1,
        custom_map = "int_Butcher",
    },
    custom_art_gallery = {
        label = "Art Gallery (Custom)", size = "large",
        x = 1517.69, y = 1634.37, z = 7.06,
        exit_x = 1521.69, exit_y = 1634.37, exit_z = 7.06,
        interior = 1,
        custom_map = "int_ArtGalleryEntry",
    },
    custom_china_cinema = {
        label = "China Cinema (Custom)", size = "large",
        x = 1503.28, y = 1546.36, z = 4.82,
        exit_x = 1507.28, exit_y = 1546.36, exit_z = 4.82,
        interior = 1,
        custom_map = "int_ChinaCinemaEntry",
    },
    custom_castle_casino = {
        label = "Castle Casino (Custom)", size = "large",
        x = 2220.60, y = 1602.11, z = 1003.97,
        exit_x = 2224.60, exit_y = 1602.11, exit_z = 1003.97,
        interior = 1,
        custom_map = "int_CastleCasino",
    },
    custom_skyscraper_atrium = {
        label = "Skyscraper Atrium (Custom)", size = "large",
        x = -2235.68, y = 610.50, z = 433.32,
        exit_x = -2231.68, exit_y = 610.50, exit_z = 433.32,
        interior = 1,
        custom_map = "int_SkyScraperAtrium",
    },
    custom_skyscraper_offices = {
        label = "Skyscraper Offices (Custom)", size = "large",
        x = -994.47, y = 193.26, z = 14.44,
        exit_x = -990.47, exit_y = 193.26, exit_z = 14.44,
        interior = 1,
        custom_map = "int_SkyScraperOffices",
    },

    -- Government / Public Services
    custom_city_hall = {
        label = "City Hall (Custom)", size = "large",
        x = 2189.24, y = 1674.68, z = 993.49,
        exit_x = 2193.24, exit_y = 1674.68, exit_z = 993.49,
        interior = 1,
        custom_map = "int_CityHall",
    },
    custom_courthouse = {
        label = "Courthouse (Custom)", size = "large",
        x = 2323.02, y = 1630.76, z = 1108.64,
        exit_x = 2327.02, exit_y = 1630.76, exit_z = 1108.64,
        interior = 1,
        custom_map = "int_Courthouse",
    },
    custom_dmv = {
        label = "DMV (Custom)", size = "medium",
        x = 681.26, y = -445.25, z = -23.81,
        exit_x = 685.26, exit_y = -445.25, exit_z = -23.81,
        interior = 1,
        custom_map = "int_DMV",
    },
    custom_fire_department = {
        label = "Fire Department (Custom)", size = "large",
        x = 1441.26, y = 1690.09, z = 4.16,
        exit_x = 1445.26, exit_y = 1690.09, exit_z = 4.16,
        interior = 1,
        custom_map = "int_FireDepartment",
    },
    custom_gov_entryway = {
        label = "Government Entryway (Custom)", size = "medium",
        x = 1480.82, y = 1658.82, z = 3.67,
        exit_x = 1484.82, exit_y = 1658.82, exit_z = 3.67,
        interior = 1,
        custom_map = "int_Government Entryway",
    },
    custom_gov_offices = {
        label = "Government Offices (Custom)", size = "large",
        x = 1470.24, y = 1638.49, z = -33.51,
        exit_x = 1474.24, exit_y = 1638.49, exit_z = -33.51,
        interior = 1,
        custom_map = "int_GovernmentOffices",
    },

    -- Vehicle / Service
    custom_taxi_depot = {
        label = "Taxi Depot (Custom)", size = "medium",
        x = 1535.57, y = 1610.68, z = 10.96,
        exit_x = 1539.57, exit_y = 1610.68, exit_z = 10.96,
        interior = 1,
        custom_map = "int_TaxiDepot",
    },
    custom_towing_company = {
        label = "Towing Company (Custom)", size = "medium",
        x = 2209.72, y = 1638.02, z = 991.10,
        exit_x = 2213.72, exit_y = 1638.02, exit_z = 991.10,
        interior = 1,
        custom_map = "int_TowingCompany",
    },
    custom_carther = {
        label = "Carther Warehouse (Custom)", size = "large",
        x = 1631.14, y = 1616.82, z = 4.13,
        exit_x = 1635.14, exit_y = 1616.82, exit_z = 4.13,
        interior = 1,
        custom_map = "int_Carther",
    },

    -- ─── Custom Garages ──────────────────────────────────────────
    custom_auto_garage = {
        label = "Auto Garage (Custom)", size = "medium",
        x = 1514.88, y = 1623.57, z = 11.00,
        exit_x = 1518.00, exit_y = 1623.57, exit_z = 11.00,
        interior = 1,
        custom_map = "int_AutoGarage",
    },
    custom_parking_garage = {
        label = "Parking Garage (Custom)", size = "large",
        x = 2257.65, y = 1638.15, z = 1109.46,
        exit_x = 2261.65, exit_y = 1638.15, exit_z = 1109.46,
        interior = 1,
        custom_map = "int_ParkingGarage",
    },
}

local CATEGORY_TO_TYPE = {
    -- Native
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
    -- Custom residential
    custom_modern_small_house = "house",
    custom_modern_condo = "house",
    custom_modern_mansion = "house",
    custom_modern_mansion2 = "house",
    -- Custom commercial/public
    custom_italian_bistro = "house",
    custom_asian_restaurant = "house",
    custom_butcher = "house",
    custom_art_gallery = "house",
    custom_china_cinema = "house",
    custom_castle_casino = "house",
    custom_skyscraper_atrium = "house",
    custom_skyscraper_offices = "house",
    -- Custom government/public
    custom_city_hall = "house",
    custom_courthouse = "house",
    custom_dmv = "house",
    custom_fire_department = "house",
    custom_gov_entryway = "house",
    custom_gov_offices = "house",
    -- Custom vehicle/service
    custom_taxi_depot = "house",
    custom_towing_company = "house",
    custom_carther = "house",
    -- Custom garages
    custom_auto_garage = "garage",
    custom_parking_garage = "garage",
}

local HOUSE_CATEGORY_KEYS = {
    -- Native
    "studio",
    "apartment_small",
    "apartment_medium",
    "apartment_large",
    "penthouse",
    "villa",
    "mansion",
    "warehouse",
    -- Custom Residential
    "custom_modern_small_house",
    "custom_modern_condo",
    "custom_modern_mansion",
    "custom_modern_mansion2",
    -- Custom Commercial / Public
    "custom_italian_bistro",
    "custom_asian_restaurant",
    "custom_butcher",
    "custom_art_gallery",
    "custom_china_cinema",
    "custom_castle_casino",
    "custom_skyscraper_atrium",
    "custom_skyscraper_offices",
    -- Custom Government / Public Services
    "custom_city_hall",
    "custom_courthouse",
    "custom_dmv",
    "custom_fire_department",
    "custom_gov_entryway",
    "custom_gov_offices",
    -- Custom Vehicle / Service
    "custom_taxi_depot",
    "custom_towing_company",
    "custom_carther",
}

local GARAGE_CATEGORY_KEYS = {
    -- Native
    "garage_small",
    "garage_large",
    -- Custom Garages
    "custom_auto_garage",
    "custom_parking_garage",
}

local previewReturn = {}
local previewObjects = {}  -- player → { element, element, ... }
local PREVIEW_DIMENSION = 65000

function destroyPreviewMapObjects(player)
    local objs = previewObjects[player]
    if objs then
        for _, obj in ipairs(objs) do
            if isElement(obj) then destroyElement(obj) end
        end
        previewObjects[player] = nil
    end
    -- Also clean up any custom map objects at the preview dimension
    local housingRes = getResourceFromName("housing")
    if housingRes and getResourceState(housingRes) == "running" then
        exports.housing:leaveCustomInterior(nil, nil, PREVIEW_DIMENSION)
    end
end

local function spawnPreviewMapObjects(player, mapName, interiorId, dimension)
    destroyPreviewMapObjects(player)
    -- Use housing resource's exports to spawn the objects
    local housingRes = getResourceFromName("housing")
    if housingRes and getResourceState(housingRes) == "running" then
        exports.housing:enterCustomInterior(nil, mapName, interiorId, dimension)
    end
end

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

-- ─────────────────────────────────────────────────────────────
-- INTERIOR MANAGER: Track disabled custom interiors
-- ─────────────────────────────────────────────────────────────
local disabledInteriors = {}  -- key → true if disabled

local function isInteriorEnabled(key)
    return not disabledInteriors[key]
end

local function buildCatalogPayload()
    local function collect(keys)
        local result = {}
        for _, key in ipairs(keys) do
            local preset = INTERIOR_CATALOG[key]
            if preset and isInteriorEnabled(key) then
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
    setElementDimension(player, PREVIEW_DIMENSION)
    setElementPosition(player, preset.x, preset.y, preset.z)

    -- Spawn custom map objects in the preview dimension if applicable
    if preset.custom_map then
        spawnPreviewMapObjects(player, preset.custom_map, preset.interior, PREVIEW_DIMENSION)
    end

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

    destroyPreviewMapObjects(player)
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

    destroyPreviewMapObjects(player)
    setElementInterior(player, ret.interior)
    setElementDimension(player, ret.dimension)
    setElementPosition(player, ret.x, ret.y, ret.z)
    previewReturn[player] = nil

    outputChatBox("[Preview] Returned to your original position.", player, 120, 255, 120, true)
end)

addEventHandler("onPlayerQuit", root, function()
    destroyPreviewMapObjects(source)
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
    local exteriorZ = ez

    if propertyType ~= "garage" then
        exteriorZ = ez + HOUSE_EXTERIOR_CREATE_Z_OFFSET
    end

    centralExecute([[
        INSERT OR IGNORE INTO houses (
            id, name, price, property_type, linked_property_id, owner_key, owner_account, locked,
            exterior_x, exterior_y, exterior_z, exterior_rot, exterior_interior,
            interior_x, interior_y, interior_z, interior_rot, interior_id, dimension,
            garage_x, garage_y, garage_z, garage_radius,
            garage_int_x, garage_int_y, garage_int_z, garage_int_rot,
            custom_map
        ) VALUES (?, ?, ?, ?, NULL, NULL, NULL, 1, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, 0, 0, 0, 8, 0, 0, 0, 0, ?)
    ]],
        newId,
        name,
        price,
        propertyType,
        ex,
        ey,
        exteriorZ,
        exteriorRot,
        exteriorInterior,
        preset.x,
        preset.y,
        preset.z,
        preset.interior,
        propertyDimension,
        preset.custom_map or nil
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

-- ─────────────────────────────────────────────────────────────
-- INTERIOR MANAGER: Server events
-- ─────────────────────────────────────────────────────────────

-- Build the interior list for the manager tab
local function buildInteriorManagerList()
    local list = {}
    local allKeys = {}
    for _, key in ipairs(HOUSE_CATEGORY_KEYS) do allKeys[#allKeys + 1] = key end
    for _, key in ipairs(GARAGE_CATEGORY_KEYS) do allKeys[#allKeys + 1] = key end

    for _, key in ipairs(allKeys) do
        local preset = INTERIOR_CATALOG[key]
        if preset then
            local isCustom = preset.custom_map ~= nil
            local mapRes = isCustom and preset.custom_map or nil
            local origRunning = false
            if mapRes then
                local res = getResourceFromName(mapRes)
                origRunning = res and (getResourceState(res) == "running") or false
            end

            list[#list + 1] = {
                key = key,
                label = preset.label,
                size = preset.size or "?",
                ptype = CATEGORY_TO_TYPE[key] or "house",
                is_custom = isCustom,
                custom_map = mapRes or "",
                enabled = isInteriorEnabled(key),
                orig_running = origRunning,
            }
        end
    end
    return list
end

addEvent("hm:requestInteriorList", true)
addEventHandler("hm:requestInteriorList", root, function()
    local player = client
    if not isAdmin(player) then return end
    triggerClientEvent(player, "hm:receiveInteriorList", player, buildInteriorManagerList())
end)

addEvent("hm:toggleInterior", true)
addEventHandler("hm:toggleInterior", root, function(key)
    local player = client
    if not isAdmin(player) then return end
    if not INTERIOR_CATALOG[key] then return end

    if disabledInteriors[key] then
        disabledInteriors[key] = nil
        outputChatBox("[InteriorMgr] Enabled: " .. (INTERIOR_CATALOG[key].label or key), player, 100, 255, 100, true)
    else
        disabledInteriors[key] = true
        outputChatBox("[InteriorMgr] Disabled: " .. (INTERIOR_CATALOG[key].label or key), player, 255, 160, 60, true)
    end

    -- Refresh lists for the player
    triggerClientEvent(player, "hm:receiveInteriorList", player, buildInteriorManagerList())
    sendCatalog(player)
end)

addEvent("hm:stopOriginalResource", true)
addEventHandler("hm:stopOriginalResource", root, function(resName)
    local player = client
    if not isAdmin(player) then return end
    if not resName or resName == "" then return end

    local res = getResourceFromName(resName)
    if res and getResourceState(res) == "running" then
        stopResource(res)
        outputChatBox("[InteriorMgr] Stopped original resource: " .. resName, player, 255, 200, 50, true)
    else
        outputChatBox("[InteriorMgr] Resource '" .. resName .. "' is not running.", player, 200, 200, 200, true)
    end

    -- Refresh after stopping
    setTimer(function()
        triggerClientEvent(player, "hm:receiveInteriorList", player, buildInteriorManagerList())
    end, 500, 1)
end)

addEvent("hm:stopAllOriginals", true)
addEventHandler("hm:stopAllOriginals", root, function()
    local player = client
    if not isAdmin(player) then return end
    local stopped = 0

    local allKeys = {}
    for _, key in ipairs(HOUSE_CATEGORY_KEYS) do allKeys[#allKeys + 1] = key end
    for _, key in ipairs(GARAGE_CATEGORY_KEYS) do allKeys[#allKeys + 1] = key end

    for _, key in ipairs(allKeys) do
        local preset = INTERIOR_CATALOG[key]
        if preset and preset.custom_map then
            local res = getResourceFromName(preset.custom_map)
            if res and getResourceState(res) == "running" then
                stopResource(res)
                stopped = stopped + 1
            end
        end
    end

    outputChatBox("[InteriorMgr] Stopped " .. stopped .. " original resource(s).", player, 255, 200, 50, true)
    setTimer(function()
        triggerClientEvent(player, "hm:receiveInteriorList", player, buildInteriorManagerList())
    end, 500, 1)
end)
