local legacyDbConnect = dbConnect
local legacyDbPoll = dbPoll
local legacyDbQuery = dbQuery

local bankLocations = {
    { name = "Los Santos Bank", x = 594.43, y = -1247.16, z = 18.28 },
    { name = "San Fierro Bank", x = -1491.12, y = 920.06, z = 7.18 },
    { name = "Las Venturas Bank", x = 2308.73, y = -15.18, z = 26.74 },
}

local playerBankContext = {}

local function centralExecute(queryText, ...)
    return exports.database_manager:dbExecute(queryText, ...)
end

local function centralQuery(queryText, ...)
    return exports.database_manager:dbQuery(queryText, ...) or {}
end

local function formatMoney(amount)
    return "$" .. tostring(math.floor(tonumber(amount) or 0))
end

local function getPrimaryOwnerKey(player)
    return exports.database_manager:ensurePlayerRecord(player, false)
end

local function getBalanceForOwner(ownerKey)
    if not ownerKey then
        return 0
    end

    local row = centralQuery("SELECT bank_balance FROM players WHERE owner_key = ? LIMIT 1", ownerKey)[1]
    if not row then
        return 0
    end

    return math.floor(tonumber(row.bank_balance) or 0)
end

local function setBalanceForOwner(ownerKey, balance)
    balance = math.max(0, math.floor(tonumber(balance) or 0))
    exports.database_manager:ensureOwnerRecord(ownerKey)
    return centralExecute(
        "UPDATE players SET bank_balance = ?, updated_at = ? WHERE owner_key = ?",
        balance,
        getRealTime().timestamp,
        ownerKey
    )
end

local function hasBankAdminAccess(player)
    return hasObjectPermissionTo(player, "command.start", false)
        or hasObjectPermissionTo(player, "function.banPlayer", false)
end

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
        local playerName = sanitizePlayerName(getPlayerName(player))
        local lowerName = playerName:lower()
        if lowerName == fragment then
            return player
        end

        if not partialMatch and lowerName:find(fragment, 1, true) then
            partialMatch = player
        end
    end

    return partialMatch
end

local function isNearBank(player)
    return playerBankContext[player] ~= nil
end

local function migrateLegacyBank()
    local migrationName = "bank_legacy_v1"
    if exports.database_manager:isMigrationComplete(migrationName) then
        return
    end

    local legacyConnection = legacyDbConnect("sqlite", "bank.db")
    if not legacyConnection then
        exports.database_manager:markMigrationComplete(migrationName)
        return
    end

    local rows = legacyDbPoll(legacyDbQuery(legacyConnection, "SELECT owner, balance FROM bank_accounts"), -1) or {}
    for _, row in ipairs(rows) do
        local ownerKey = tostring(row.owner or "")
        local balance = math.floor(tonumber(row.balance) or 0)

        if ownerKey ~= "" and balance >= 0 then
            exports.database_manager:ensureOwnerRecord(ownerKey)
            setBalanceForOwner(ownerKey, getBalanceForOwner(ownerKey) + balance)
        end
    end

    exports.database_manager:markMigrationComplete(migrationName)
end

function getBankBalance(player)
    return getBalanceForOwner(getPrimaryOwnerKey(player))
end

function depositPlayerBankMoney(player, amount)
    local ownerKey = getPrimaryOwnerKey(player)
    amount = math.floor(tonumber(amount) or 0)

    if not ownerKey or amount <= 0 or getPlayerMoney(player) < amount then
        return false
    end

    takePlayerMoney(player, amount)
    return setBalanceForOwner(ownerKey, getBalanceForOwner(ownerKey) + amount)
end

function withdrawPlayerBankMoney(player, amount)
    local ownerKey = getPrimaryOwnerKey(player)
    amount = math.floor(tonumber(amount) or 0)

    if not ownerKey or amount <= 0 then
        return false
    end

    local balance = getBalanceForOwner(ownerKey)
    if balance < amount then
        return false
    end

    givePlayerMoney(player, amount)
    return setBalanceForOwner(ownerKey, balance - amount)
end

addEventHandler("onResourceStart", resourceRoot, function()
    migrateLegacyBank()

    for _, location in ipairs(bankLocations) do
        local marker = createMarker(location.x, location.y, location.z - 1, "cylinder", 1.4, 0, 170, 60, 120)
        local blip = createBlip(location.x, location.y, location.z, 52, 2, 0, 170, 60, 255, 0, 200)
        setElementData(marker, "bank:name", location.name, false)
        setElementParent(marker, resourceRoot)
        setElementParent(blip, resourceRoot)
    end
end)

addEventHandler("onMarkerHit", resourceRoot, function(hitElement, matchingDimension)
    if not matchingDimension or getElementType(hitElement) ~= "player" then
        return
    end

    playerBankContext[hitElement] = source
    outputChatBox("Bank: use /balance, /deposit <amount>, /withdraw <amount>.", hitElement, 120, 255, 120, true)
end)

addEventHandler("onMarkerLeave", resourceRoot, function(leftElement, matchingDimension)
    if not matchingDimension or getElementType(leftElement) ~= "player" then
        return
    end

    if playerBankContext[leftElement] == source then
        playerBankContext[leftElement] = nil
    end
end)

addEventHandler("onPlayerQuit", root, function()
    playerBankContext[source] = nil
end)

addCommandHandler("balance", function(player)
    outputChatBox("Bank balance: " .. formatMoney(getBankBalance(player)) .. ".", player, 120, 255, 120, true)
end)

addCommandHandler("deposit", function(player, _, amount)
    amount = math.floor(tonumber(amount) or 0)
    if not isNearBank(player) then
        outputChatBox("Bank: stand in a bank marker first.", player, 255, 80, 80, true)
        return
    end

    if amount <= 0 then
        outputChatBox("Usage: /deposit <amount>", player, 255, 220, 120, true)
        return
    end

    if not depositPlayerBankMoney(player, amount) then
        outputChatBox("Bank: deposit failed.", player, 255, 80, 80, true)
        return
    end

    outputChatBox(
        "Bank: deposited " .. formatMoney(amount) .. ". New balance: " .. formatMoney(getBankBalance(player)) .. ".",
        player,
        120,
        255,
        120,
        true
    )
end)

addCommandHandler("withdraw", function(player, _, amount)
    amount = math.floor(tonumber(amount) or 0)
    if not isNearBank(player) then
        outputChatBox("Bank: stand in a bank marker first.", player, 255, 80, 80, true)
        return
    end

    if amount <= 0 then
        outputChatBox("Usage: /withdraw <amount>", player, 255, 220, 120, true)
        return
    end

    if not withdrawPlayerBankMoney(player, amount) then
        outputChatBox("Bank: insufficient funds.", player, 255, 80, 80, true)
        return
    end

    outputChatBox(
        "Bank: withdrew " .. formatMoney(amount) .. ". New balance: " .. formatMoney(getBankBalance(player)) .. ".",
        player,
        120,
        255,
        120,
        true
    )
end)

addCommandHandler("setbank", function(player, _, targetFragment, amount)
    if not hasBankAdminAccess(player) then
        outputChatBox("Bank: admin rights required.", player, 255, 80, 80, true)
        return
    end

    local target = findPlayerByFragment(targetFragment)
    amount = math.floor(tonumber(amount) or -1)
    if not target or amount < 0 then
        outputChatBox("Usage: /setbank <player> <amount>", player, 255, 220, 120, true)
        return
    end

    local ownerKey = getPrimaryOwnerKey(target)
    if not ownerKey or not setBalanceForOwner(ownerKey, amount) then
        outputChatBox("Bank: failed to set balance.", player, 255, 80, 80, true)
        return
    end

    local targetName = sanitizePlayerName(getPlayerName(target))
    outputChatBox("Bank: set " .. targetName .. "'s balance to " .. formatMoney(amount) .. ".", player, 120, 255, 120, true)
    outputChatBox("Bank: your balance was set to " .. formatMoney(amount) .. ".", target, 120, 255, 120, true)
end)
