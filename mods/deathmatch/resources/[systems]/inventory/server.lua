local legacyDbConnect = dbConnect
local legacyDbPoll = dbPoll
local legacyDbQuery = dbQuery

local function centralExecute(queryText, ...)
    return exports.database_manager:dbExecute(queryText, ...)
end

local function centralQuery(queryText, ...)
    return exports.database_manager:dbQuery(queryText, ...) or {}
end

local function getPrimaryOwnerKey(player)
    return exports.database_manager:getPlayerOwnerKey(player, false)
end

local function normalizeItemName(itemName)
    itemName = tostring(itemName or "")
    itemName = itemName:gsub("^%s+", ""):gsub("%s+$", ""):lower():gsub("%s+", "_")
    if itemName == "" then
        return nil
    end

    return itemName
end

local itemWeights = {
    bread = 0.6,
    water = 0.4,
    pistol = 2.8,
    key = 0.1,
}

local itemIcons = {
    bread = "icons/bread.png",
    water = "icons/water.png",
    pistol = "icons/pistol.png",
    key = "icons/key.png",
}

local function sanitizePlayerName(playerName)
    return tostring(playerName or ""):gsub("#%x%x%x%x%x%x", "")
end

local function findPlayerByFragment(fragment)
    if not fragment or fragment == "" then
        return nil
    end

    fragment = fragment:lower()
    local partialMatch

    for _, player in ipairs(getElementsByType("player")) do
        local plainName = sanitizePlayerName(getPlayerName(player))
        local lowerName = plainName:lower()
        if lowerName == fragment then
            return player
        end

        if not partialMatch and lowerName:find(fragment, 1, true) then
            partialMatch = player
        end
    end

    return partialMatch
end

local function hasInventoryAdminAccess(player)
    return hasObjectPermissionTo(player, "command.start", false)
        or hasObjectPermissionTo(player, "function.banPlayer", false)
end

local function getAmountByOwner(ownerKey, itemName)
    local row = centralQuery(
        "SELECT amount FROM items WHERE owner_key = ? AND item_name = ? LIMIT 1",
        ownerKey,
        itemName
    )[1]
    if not row then
        return 0
    end

    return math.floor(tonumber(row.amount) or 0)
end

local function setAmountByOwner(ownerKey, itemName, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        return centralExecute("DELETE FROM items WHERE owner_key = ? AND item_name = ?", ownerKey, itemName)
    end

    exports.database_manager:ensureOwnerRecord(ownerKey)
    return centralExecute(
        "INSERT OR REPLACE INTO items (owner_key, item_name, amount) VALUES (?, ?, ?)",
        ownerKey,
        itemName,
        amount
    )
end

local function getInventoryRows(ownerKey)
    local rows = centralQuery(
        "SELECT item_name, amount FROM items WHERE owner_key = ? ORDER BY item_name ASC",
        ownerKey
    )
    local items = {}

    for _, row in ipairs(rows) do
        local amount = math.floor(tonumber(row.amount) or 0)
        if amount > 0 then
            local itemWeight = itemWeights[row.item_name] or 1
            items[#items + 1] = {
                item = row.item_name,
                amount = amount,
                label = row.item_name:gsub("_", " "),
                weight = itemWeight,
                icon = itemIcons[row.item_name] or "icons/key.png",
            }
        end
    end

    return items
end

local function buildInventoryPayload(ownerKey)
    local rows = getInventoryRows(ownerKey)
    local quickSlots = {}
    local currentWeight = 0

    for index, entry in ipairs(rows) do
        currentWeight = currentWeight + (entry.weight * entry.amount)
        if index <= 5 then
            quickSlots[index] = {
                slot = index,
                item = entry.item,
                label = entry.label,
                amount = entry.amount,
                icon = entry.icon,
            }
        end
    end

    for slotIndex = #quickSlots + 1, 5 do
        quickSlots[slotIndex] = { slot = slotIndex }
    end

    return {
        items = rows,
        quickSlots = quickSlots,
        currentWeight = math.floor(currentWeight * 10 + 0.5) / 10,
        maxWeight = 35,
        totalSlots = 30,
    }
end

local function getInventoryMap(ownerKey)
    local inventory = {}
    for _, row in ipairs(getInventoryRows(ownerKey)) do
        inventory[row.item] = row.amount
    end

    return inventory
end

local function pushInventoryToClient(player)
    if not isElement(player) then
        return
    end

    local ownerKey = exports.database_manager:ensurePlayerRecord(player, false)
    if not ownerKey then
        triggerClientEvent(player, "inventory:receiveContents", resourceRoot, buildInventoryPayload(false))
        return
    end

    triggerClientEvent(player, "inventory:receiveContents", resourceRoot, buildInventoryPayload(ownerKey))
end

local function migrateLegacyInventory()
    local migrationName = "inventory_legacy_v1"
    if exports.database_manager:isMigrationComplete(migrationName) then
        return
    end

    local legacyConnection = legacyDbConnect("sqlite", "inventory.db")
    if not legacyConnection then
        exports.database_manager:markMigrationComplete(migrationName)
        return
    end

    local rows = legacyDbPoll(legacyDbQuery(legacyConnection, "SELECT owner, item, amount FROM inventory"), -1) or {}
    for _, row in ipairs(rows) do
        local ownerKey = tostring(row.owner or "")
        local itemName = normalizeItemName(row.item)
        local amount = math.floor(tonumber(row.amount) or 0)

        if ownerKey ~= "" and itemName and amount > 0 then
            exports.database_manager:ensureOwnerRecord(ownerKey)
            local currentAmount = getAmountByOwner(ownerKey, itemName)
            setAmountByOwner(ownerKey, itemName, currentAmount + amount)
        end
    end

    exports.database_manager:markMigrationComplete(migrationName)
end

function getInventoryItemCount(player, itemName)
    local ownerKey = exports.database_manager:ensurePlayerRecord(player, false)
    itemName = normalizeItemName(itemName)
    if not ownerKey or not itemName then
        return 0
    end

    return getAmountByOwner(ownerKey, itemName)
end

function getInventoryContents(player)
    local ownerKey = exports.database_manager:ensurePlayerRecord(player, false)
    if not ownerKey then
        return {}
    end

    return getInventoryMap(ownerKey)
end

function addInventoryItem(player, itemName, amount)
    local ownerKey = exports.database_manager:ensurePlayerRecord(player, false)
    itemName = normalizeItemName(itemName)
    amount = math.floor(tonumber(amount) or 1)
    if not ownerKey or not itemName or amount <= 0 then
        return false
    end

    local currentAmount = getAmountByOwner(ownerKey, itemName)
    local success = setAmountByOwner(ownerKey, itemName, currentAmount + amount)
    if success then
        pushInventoryToClient(player)
    end

    return success
end

function removeInventoryItem(player, itemName, amount)
    local ownerKey = exports.database_manager:ensurePlayerRecord(player, false)
    itemName = normalizeItemName(itemName)
    amount = math.floor(tonumber(amount) or 1)
    if not ownerKey or not itemName or amount <= 0 then
        return false
    end

    local currentAmount = getAmountByOwner(ownerKey, itemName)
    if currentAmount < amount then
        return false
    end

    local success = setAmountByOwner(ownerKey, itemName, currentAmount - amount)
    if success then
        pushInventoryToClient(player)
    end

    return success
end

local function outputInventory(player)
    local items = getInventoryRows(exports.database_manager:ensurePlayerRecord(player, false))
    if #items == 0 then
        outputChatBox("Inventory: empty.", player, 255, 220, 120, true)
        return
    end

    local parts = {}
    for _, entry in ipairs(items) do
        parts[#parts + 1] = entry.item .. " x" .. entry.amount
    end

    outputChatBox("Inventory: " .. table.concat(parts, ", "), player, 255, 220, 120, true)
end

addEvent("inventory:requestContents", true)
addEventHandler("inventory:requestContents", root, function()
    pushInventoryToClient(client)
end)

addEventHandler("onResourceStart", resourceRoot, function()
    migrateLegacyInventory()
end)

addCommandHandler("inventory", function(player)
    outputInventory(player)
end)

addCommandHandler("inv", function(player)
    outputInventory(player)
end)

addCommandHandler("giveitem", function(player, _, targetFragment, itemName, amount)
    if not hasInventoryAdminAccess(player) then
        outputChatBox("Inventory: admin rights required.", player, 255, 80, 80, true)
        return
    end

    if not targetFragment or not itemName then
        outputChatBox("Usage: /giveitem <player> <item_name> [amount]", player, 255, 220, 120, true)
        return
    end

    local target = findPlayerByFragment(targetFragment)
    if not target then
        outputChatBox("Inventory: target player not found.", player, 255, 80, 80, true)
        return
    end

    amount = math.floor(tonumber(amount) or 1)
    if amount <= 0 then
        outputChatBox("Inventory: amount must be greater than zero.", player, 255, 80, 80, true)
        return
    end

    itemName = normalizeItemName(itemName)
    if not itemName or not addInventoryItem(target, itemName, amount) then
        outputChatBox("Inventory: failed to give item.", player, 255, 80, 80, true)
        return
    end

    local targetName = sanitizePlayerName(getPlayerName(target))
    outputChatBox("Inventory: gave " .. itemName .. " x" .. amount .. " to " .. targetName .. ".", player, 120, 255, 120, true)
    outputChatBox("Inventory: received " .. itemName .. " x" .. amount .. ".", target, 120, 255, 120, true)
end)

addCommandHandler("takeitem", function(player, _, targetFragment, itemName, amount)
    if not hasInventoryAdminAccess(player) then
        outputChatBox("Inventory: admin rights required.", player, 255, 80, 80, true)
        return
    end

    if not targetFragment or not itemName then
        outputChatBox("Usage: /takeitem <player> <item_name> [amount]", player, 255, 220, 120, true)
        return
    end

    local target = findPlayerByFragment(targetFragment)
    if not target then
        outputChatBox("Inventory: target player not found.", player, 255, 80, 80, true)
        return
    end

    amount = math.floor(tonumber(amount) or 1)
    if amount <= 0 then
        outputChatBox("Inventory: amount must be greater than zero.", player, 255, 80, 80, true)
        return
    end

    itemName = normalizeItemName(itemName)
    if not itemName or not removeInventoryItem(target, itemName, amount) then
        outputChatBox("Inventory: target does not have enough of that item.", player, 255, 80, 80, true)
        return
    end

    local targetName = sanitizePlayerName(getPlayerName(target))
    outputChatBox("Inventory: removed " .. itemName .. " x" .. amount .. " from " .. targetName .. ".", player, 120, 255, 120, true)
    outputChatBox("Inventory: removed " .. itemName .. " x" .. amount .. ".", target, 255, 220, 120, true)
end)
