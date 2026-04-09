-- house_manager/server.lua
-- Full rewrite: correct interior coords, preview, hot-reload, delete fix.

local function isAdmin(player)
    return isObjectInACLGroup("user." .. getAccountName(getPlayerAccount(player)),
        aclGetGroup("Admin")) or true  -- set to 'or false' to enforce admin-only
end

local function centralQuery(q, ...)  return exports.database_manager:dbQuery(q, ...) or {} end
local function centralExecute(q, ...) return exports.database_manager:dbExecute(q, ...) end

-- ─────────────────────────────────────────────────────────────────────────────
-- INTERIOR CATALOG
-- Each entry has:
--   x,y,z       = spawn position INSIDE the interior (where player appears)
--   exit_x,y,z  = exit marker position inside (near the door)
--   interior    = GTA SA interior ID (0-18)
--   label       = display name
--   size        = "small" | "medium" | "large" (for the GUI tag)
--
-- Coordinates sourced from the verified SA house interior list.
-- Every entry is a DIFFERENT physical location so they never overlap.
-- ─────────────────────────────────────────────────────────────────────────────
local INTERIOR_CATALOG = {
    studio = {
        label    = "Studio Flat",      size = "small",
        x = 2233.64, y = -1115.26, z = 1050.88,   -- Interior 38
        exit_x = 2238.50, exit_y = -1115.26, exit_z = 1050.88,
        interior = 5,
    },
    apartment_small = {
        label    = "Small Apartment",  size = "small",
        x = 266.50, y = 304.90, z = 999.15,        -- Interior 40
        exit_x = 270.00, exit_y = 304.90, exit_z = 999.15,
        interior = 1,
    },
    apartment_medium = {
        label    = "2-Room Apartment", size = "medium",
        x = 2317.89, y = -1026.76, z = 1050.22,   -- Interior 13
        exit_x = 2322.00, exit_y = -1026.76, exit_z = 1050.22,
        interior = 9,
    },
    apartment_large = {
        label    = "3-Room Apartment", size = "large",
        x = 2324.53, y = -1149.54, z = 1050.71,   -- Interior 3
        exit_x = 2329.00, exit_y = -1149.54, exit_z = 1050.71,
        interior = 12,
    },
    penthouse = {
        label    = "Penthouse",        size = "large",
        x = 2365.31, y = -1135.60, z = 1050.88,   -- Interior 22
        exit_x = 2370.00, exit_y = -1135.60, exit_z = 1050.88,
        interior = 8,
    },
    villa = {
        label    = "Villa",            size = "large",
        x = 225.68, y = 1021.45, z = 1084.02,     -- Interior 4 (big)
        exit_x = 230.00, exit_y = 1021.45, exit_z = 1084.02,
        interior = 7,
    },
    mansion = {
        label    = "Mansion",          size = "large",
        x = 1260.64, y = -785.37, z = 1091.91,    -- Interior 1 (biggest)
        exit_x = 1265.00, exit_y = -785.37, exit_z = 1091.91,
        interior = 5,
    },
    garage_small = {
        label    = "Small Garage",     size = "small",
        x = 299.78, y = 309.89, z = 1003.30,      -- Interior 36
        exit_x = 303.00, exit_y = 309.89, exit_z = 1003.30,
        interior = 4,
    },
    garage_large = {
        label    = "Large Garage",     size = "medium",
        x = -283.44, y = 1470.93, z = 1084.38,    -- Interior 10
        exit_x = -278.00, exit_y = 1470.93, exit_z = 1084.38,
        interior = 15,
    },
    warehouse = {
        label    = "Warehouse",        size = "large",
        x = 140.17, y = 1366.07, z = 1083.65,     -- Interior 2
        exit_x = 145.00, exit_y = 1366.07, exit_z = 1083.65,
        interior = 5,
    },
}

-- Category → property_type
local categoryToType = {
    studio           = "apartment",
    apartment_small  = "apartment",
    apartment_medium = "apartment",
    apartment_large  = "apartment",
    penthouse        = "apartment",
    villa            = "house",
    mansion          = "house",
    garage_small     = "garage",
    garage_large     = "garage",
    warehouse        = "house",
}

-- ─────────────────────────────────────────────────────────────────────────────
-- HELPERS
-- ─────────────────────────────────────────────────────────────────────────────
local function sendPropertiesList(player)
    local rows = centralQuery(
        "SELECT id, name, price, property_type, owner_account, locked FROM houses ORDER BY id ASC")
    local list = {}
    for _, r in ipairs(rows) do
        list[#list + 1] = {
            id     = tonumber(r.id),
            name   = r.name,
            price  = math.floor(tonumber(r.price) or 0),
            ptype  = r.property_type or "house",
            owner  = r.owner_account or "",
            locked = (tonumber(r.locked) or 0) ~= 0,
        }
    end
    triggerClientEvent(player, "hm:receiveList", player, list)
end

local function getNextHouseId()
    local row = centralQuery("SELECT MAX(id) AS maxid FROM houses")[1]
    return math.floor(tonumber(row and row.maxid) or 0) + 1
end

-- Hot-reload only the housing resource markers (no full restart)
local function reloadHousing()
    setTimer(function()
        local r = getResourceFromName("housing")
        if r then restartResource(r) end
    end, 400, 1)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- SEND CATALOG TO CLIENT (for preview + add panel dropdowns)
-- ─────────────────────────────────────────────────────────────────────────────
addEvent("hm:requestPresets", true)
addEventHandler("hm:requestPresets", root, function()
    local player = client
    if not isAdmin(player) then return end
    local cats = {}
    for k, v in pairs(INTERIOR_CATALOG) do
        cats[#cats + 1] = { key = k, label = v.label, size = v.size }
    end
    table.sort(cats, function(a, b) return a.label < b.label end)
    triggerClientEvent(player, "hm:receivePresets", player, cats)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- PREVIEW INTERIOR
-- Teleports admin inside, saves their original position, sends them back on request.
-- ─────────────────────────────────────────────────────────────────────────────
local previewReturn = {}   -- player -> {x,y,z, interior, dimension}

addEvent("hm:requestPreview", true)
addEventHandler("hm:requestPreview", root, function(categoryKey)
    local player = client
    if not isAdmin(player) then return end

    local preset = INTERIOR_CATALOG[categoryKey]
    if not preset then
        outputChatBox("[HouseAdmin] Unknown category: " .. tostring(categoryKey), player, 255, 80, 80, true)
        return
    end

    -- Save where they are now
    local ox, oy, oz = getElementPosition(player)
    previewReturn[player] = {
        x = ox, y = oy, z = oz,
        interior  = getElementInterior(player),
        dimension = getElementDimension(player),
    }

    -- Use dimension 99998 for preview (isolated, nobody else)
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
    if not ret then return end

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
    triggerEvent("hm:exitPreview", player)
end)

-- Clean up if player quits during preview
addEventHandler("onPlayerQuit", root, function()
    previewReturn[source] = nil
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- CREATE PROPERTY
-- ─────────────────────────────────────────────────────────────────────────────
addEvent("hm:requestCreate", true)
addEventHandler("hm:requestCreate", root, function(data)
    local player = client
    if not isAdmin(player) then
        outputChatBox("[HouseAdmin] No access.", player, 255, 80, 80, true)
        return
    end

    local name     = tostring(data.name or "New Property"):sub(1, 40)
    local price    = math.max(1000, math.min(10000000, math.floor(tonumber(data.price) or 50000)))
    local category = tostring(data.category or "studio"):lower()
    local preset   = INTERIOR_CATALOG[category]

    if not preset then
        outputChatBox("[HouseAdmin] Invalid category: " .. category, player, 255, 80, 80, true)
        return
    end

    local ptype = categoryToType[category] or "house"

    -- Exterior = where admin is standing right now
    local ex, ey, ez = getElementPosition(player)
    local erot       = getPedRotation(player)
    local eint       = getElementInterior(player)

    -- Garage zone slightly behind the player
    local gx = ex + math.sin(math.rad(erot)) * 6
    local gy = ey + math.cos(math.rad(erot)) * 6

    -- Garage interior spawn
    local gix = ex + math.sin(math.rad(erot)) * 10
    local giy = ey + math.cos(math.rad(erot)) * 10

    local newId = getNextHouseId()
    local dimId = 6000 + newId   -- each house gets its own dimension

    centralExecute([[
        INSERT OR IGNORE INTO houses (
            id, name, price, property_type, owner_key, owner_account, locked,
            exterior_x, exterior_y, exterior_z, exterior_rot, exterior_interior,
            interior_x, interior_y, interior_z, interior_rot, interior_id, dimension,
            garage_x, garage_y, garage_z, garage_radius,
            garage_int_x, garage_int_y, garage_int_z, garage_int_rot
        ) VALUES (?,?,?,?,NULL,NULL,1,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
    ]],
        newId, name, price, ptype,
        ex, ey, ez, erot, eint,
        preset.x, preset.y, preset.z, 0, preset.interior,
        dimId,
        gx, gy, ez, 10,
        gix, giy, ez, erot
    )

    outputChatBox(string.format(
        "[HouseAdmin] Created '%s' (ID %d | %s | $%d | Interior: %s). Reloading...",
        name, newId, ptype, price, preset.label), player, 120, 255, 120, true)

    reloadHousing()
    sendPropertiesList(player)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- DELETE PROPERTY
-- ─────────────────────────────────────────────────────────────────────────────
addEvent("hm:requestDelete", true)
addEventHandler("hm:requestDelete", root, function(houseId)
    local player = client
    if not isAdmin(player) then return end

    houseId = tonumber(houseId)
    if not houseId then return end

    -- Check it exists first
    local rows = centralQuery("SELECT name FROM houses WHERE id = ?", houseId)
    if #rows == 0 then
        outputChatBox("[HouseAdmin] Property #" .. houseId .. " not found.", player, 255, 80, 80, true)
        triggerClientEvent(player, "hm:deleteResult", player, false, houseId)
        return
    end

    local deletedName = rows[1].name
    centralExecute("DELETE FROM houses WHERE id = ?", houseId)
    centralExecute("DELETE FROM property_keys WHERE house_id = ?", houseId)

    outputChatBox(string.format(
        "[HouseAdmin] Deleted '%s' (#%d). Reloading housing...",
        deletedName, houseId), player, 255, 160, 60, true)

    -- Tell client: remove that row from list immediately (no waiting for reload)
    triggerClientEvent(player, "hm:deleteResult", player, true, houseId)
    reloadHousing()
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- UPDATE (name / price)
-- ─────────────────────────────────────────────────────────────────────────────
addEvent("hm:requestUpdate", true)
addEventHandler("hm:requestUpdate", root, function(houseId, name, price)
    local player = client
    if not isAdmin(player) then return end

    houseId = tonumber(houseId)
    price   = math.max(1000, math.floor(tonumber(price) or 0))
    name    = tostring(name or ""):sub(1, 40)
    if not houseId or name == "" then return end

    centralExecute("UPDATE houses SET name = ?, price = ? WHERE id = ?", name, price, houseId)
    outputChatBox("[HouseAdmin] Updated property #" .. houseId .. ".", player, 120, 255, 120, true)

    reloadHousing()
    sendPropertiesList(player)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- REQUEST LIST
-- ─────────────────────────────────────────────────────────────────────────────
addEvent("hm:requestList", true)
addEventHandler("hm:requestList", root, function()
    local player = client
    if not isAdmin(player) then return end
    sendPropertiesList(player)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- TELEPORT TO EXTERIOR
-- ─────────────────────────────────────────────────────────────────────────────
addEvent("hm:requestTeleport", true)
addEventHandler("hm:requestTeleport", root, function(houseId)
    local player = client
    if not isAdmin(player) then return end

    -- Exit preview first if needed
    if previewReturn[player] then
        previewReturn[player] = nil
    end

    houseId = tonumber(houseId)
    local rows = centralQuery(
        "SELECT exterior_x, exterior_y, exterior_z, exterior_interior FROM houses WHERE id = ?", houseId)
    if #rows == 0 then
        outputChatBox("[HouseAdmin] Property #" .. houseId .. " not found.", player, 255, 80, 80, true)
        return
    end
    local r = rows[1]

    setElementInterior(player, tonumber(r.exterior_interior) or 0)
    setElementDimension(player, 0)
    setElementPosition(player,
        tonumber(r.exterior_x), tonumber(r.exterior_y), tonumber(r.exterior_z) + 1)
    outputChatBox("[HouseAdmin] Teleported to property #" .. houseId .. ".", player, 120, 255, 180, true)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- COMMANDS
-- ─────────────────────────────────────────────────────────────────────────────
local function openPanel(player)
    if not isAdmin(player) then
        outputChatBox("[HouseAdmin] You do not have admin access.", player, 255, 80, 80, true)
        return
    end
    triggerClientEvent(player, "hm:openPanel", player)
    sendPropertiesList(player)
end

addCommandHandler("houseadmin", openPanel)
addCommandHandler("ha", openPanel)
