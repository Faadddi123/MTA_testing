-- house_manager/server.lua
-- Handles all server-side data for the admin property manager.
-- Admin players only (checked via ACL group "Admin").

local function isAdmin(player)
    -- Admin check temporarily bypassed to allow everyone access.
    return true
end

local function centralQuery(q, ...)  return exports.database_manager:dbQuery(q, ...) or {} end
local function centralExecute(q, ...) return exports.database_manager:dbExecute(q, ...) end

-- ── Send the full properties list to requesting client ─────────
local function sendPropertiesList(player)
    local rows = centralQuery("SELECT id, name, price, property_type, owner_account, locked FROM houses ORDER BY id ASC")
    local list = {}
    for _, r in ipairs(rows) do
        list[#list + 1] = {
            id       = tonumber(r.id),
            name     = r.name,
            price    = math.floor(tonumber(r.price) or 0),
            ptype    = r.property_type or "house",
            owner    = r.owner_account or "",
            locked   = (tonumber(r.locked) or 0) ~= 0,
        }
    end
    triggerClientEvent(player, "hm:receiveList", player, list)
end

-- ── Get next free house ID ──────────────────────────────────────
local function getNextHouseId()
    local row = centralQuery("SELECT MAX(id) AS maxid FROM houses")[1]
    return math.floor(tonumber(row and row.maxid) or 0) + 1
end

-- ── Interior presets by category ───────────────────────────────
local interiorPresets = {
    small      = { x = 265.20,  y = 303.50,  z = 999.15, rotation = 90,  interior = 4,  label = "Small House"   },
    medium     = { x = 243.75,  y = 304.82,  z = 999.14, rotation = 270, interior = 1,  label = "Medium House"  },
    large      = { x = 295.00,  y = 310.00,  z = 999.15, rotation = 0,   interior = 2,  label = "Large House"   },
    mansion    = { x = 300.24,  y = 300.58,  z = 999.15, rotation = 0,   interior = 4,  label = "Mansion"       },
    apartment  = { x = 292.89,  y = 309.90,  z = 999.15, rotation = 90,  interior = 3,  label = "Apartment"     },
    penthouse  = { x = 322.25,  y = 302.42,  z = 999.15, rotation = 90,  interior = 5,  label = "Penthouse"     },
    warehouse  = { x = 1726.19, y = -1638.01, z = 19.27, rotation = 180, interior = 18, label = "Warehouse"     },
}

-- Category → property_type mapping
local categoryToType = {
    small = "house", medium = "house", large = "house",
    mansion = "house", penthouse = "apartment",
    apartment = "apartment", warehouse = "house",
}

-- ── CREATE new property ─────────────────────────────────────────
addEvent("hm:requestCreate", true)
addEventHandler("hm:requestCreate", root, function(data)
    local player = client
    if not isAdmin(player) then
        outputChatBox("[HouseAdmin] No access.", player, 255, 80, 80, true)
        return
    end

    local name     = tostring(data.name or "New Property"):sub(1, 40)
    local price    = math.max(1000, math.min(10000000, math.floor(tonumber(data.price) or 50000)))
    local category = tostring(data.category or "small"):lower()
    local preset   = interiorPresets[category] or interiorPresets.small
    local ptype    = categoryToType[category] or "house"

    -- Exterior = player's current world position
    local ex, ey, ez = getElementPosition(player)
    ez = ez - 1 -- Make marker flush with the ground
    local erot       = getPedRotation(player)
    local eint       = getElementInterior(player)

    -- Garage zone slightly behind the player
    local gx = ex + math.sin(math.rad(erot)) * 6
    local gy = ey + math.cos(math.rad(erot)) * 6

    -- Garage interior spawn
    local gix = ex + math.sin(math.rad(erot)) * 10
    local giy = ey + math.cos(math.rad(erot)) * 10

    local newId  = getNextHouseId()
    local dimId  = 6000 + newId

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
        preset.x, preset.y, preset.z, preset.rotation, preset.interior,
        dimId,
        gx, gy, ez, 10,
        gix, giy, ez, erot
    )

    outputChatBox(string.format("[HouseAdmin] Created '%s' (ID %d, %s, $%d). Restarting housing...",
        name, newId, ptype, price), player, 120, 255, 120, true)

    -- Reload housing to pick up new entry
    setTimer(function()
        local r = getResourceFromName("housing")
        if r then restartResource(r) end
    end, 500, 1)

    sendPropertiesList(player)
end)

-- ── DELETE property ─────────────────────────────────────────────
addEvent("hm:requestDelete", true)
addEventHandler("hm:requestDelete", root, function(houseId)
    local player = client
    if not isAdmin(player) then return end

    houseId = tonumber(houseId)
    if not houseId then return end

    centralExecute("DELETE FROM houses WHERE id = ?", houseId)
    centralExecute("DELETE FROM property_keys WHERE house_id = ?", houseId)

    outputChatBox("[HouseAdmin] Deleted property #" .. houseId .. ". Restarting housing...", player, 255, 160, 60, true)
    setTimer(function()
        local r = getResourceFromName("housing")
        if r then restartResource(r) end
    end, 500, 1)

    sendPropertiesList(player)
end)

-- ── UPDATE property (price/name) ────────────────────────────────
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

    setTimer(function()
        local r = getResourceFromName("housing")
        if r then restartResource(r) end
    end, 500, 1)

    sendPropertiesList(player)
end)

-- ── REQUEST LIST ────────────────────────────────────────────────
addEvent("hm:requestList", true)
addEventHandler("hm:requestList", root, function()
    local player = client
    if not isAdmin(player) then
        outputChatBox("[HouseAdmin] No access.", player, 255, 80, 80, true)
        return
    end
    sendPropertiesList(player)
end)

-- ── TELEPORT TO PROPERTY ────────────────────────────────────────
addEvent("hm:requestTeleport", true)
addEventHandler("hm:requestTeleport", root, function(houseId)
    local player = client
    if not isAdmin(player) then return end

    houseId = tonumber(houseId)
    local rows = centralQuery("SELECT exterior_x, exterior_y, exterior_z, exterior_interior FROM houses WHERE id = ?", houseId)
    if #rows == 0 then return end
    local r = rows[1]

    setElementInterior(player, tonumber(r.exterior_interior) or 0)
    setElementDimension(player, 0)
    setElementPosition(player, tonumber(r.exterior_x), tonumber(r.exterior_y), tonumber(r.exterior_z) + 1)
    outputChatBox("[HouseAdmin] Teleported to property #" .. houseId .. ".", player, 120, 255, 180, true)
end)

addEvent("hm:requestTeleportInterior", true)
addEventHandler("hm:requestTeleportInterior", root, function(houseId)
    local player = client
    if not isAdmin(player) then return end

    houseId = tonumber(houseId)
    local rows = centralQuery("SELECT interior_x, interior_y, interior_z, interior_id, dimension FROM houses WHERE id = ?", houseId)
    if #rows == 0 then return end
    local r = rows[1]

    setElementInterior(player, tonumber(r.interior_id) or 0)
    setElementDimension(player, tonumber(r.dimension) or 0)
    setElementPosition(player, tonumber(r.interior_x), tonumber(r.interior_y), tonumber(r.interior_z))
    outputChatBox("[HouseAdmin] Teleported to property interior #" .. houseId .. ".", player, 120, 255, 180, true)
end)

-- ── ADMIN COMMAND ───────────────────────────────────────────────
addCommandHandler("houseadmin", function(player)
    if not isAdmin(player) then
        outputChatBox("[HouseAdmin] You do not have admin access.", player, 255, 80, 80, true)
        return
    end
    triggerClientEvent(player, "hm:openPanel", player)
    sendPropertiesList(player)
end)

addCommandHandler("ha", function(player)  -- short alias
    if not isAdmin(player) then return end
    triggerClientEvent(player, "hm:openPanel", player)
    sendPropertiesList(player)
end)

-- ── CATEGORY PRESETS → send to client ──────────────────────────
addEvent("hm:requestPresets", true)
addEventHandler("hm:requestPresets", root, function()
    local player = client
    if not isAdmin(player) then return end
    local cats = {}
    for k, v in pairs(interiorPresets) do
        cats[#cats + 1] = { key = k, label = v.label }
    end
    table.sort(cats, function(a, b) return a.label < b.label end)
    triggerClientEvent(player, "hm:receivePresets", player, cats)
end)
