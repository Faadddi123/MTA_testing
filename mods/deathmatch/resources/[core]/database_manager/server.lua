local nativeDbConnect = dbConnect
local nativeDbExec = dbExec
local nativeDbPoll = dbPoll
local nativeDbQuery = dbQuery

local connection = nativeDbConnect("sqlite", "roleplay.db")
assert(connection, "database_manager: failed to open roleplay.db")

local function getTimestamp()
    return getRealTime().timestamp
end

local function sanitizePlayerName(playerName)
    return tostring(playerName or ""):gsub("#%x%x%x%x%x%x", "")
end

local function queryRowsInternal(queryText, ...)
    local queryHandle = nativeDbQuery(connection, queryText, ...)
    return nativeDbPoll(queryHandle, -1) or {}
end

local function querySingleInternal(queryText, ...)
    return queryRowsInternal(queryText, ...)[1]
end

local function parseOwnerKey(ownerKey)
    ownerKey = tostring(ownerKey or "")
    if ownerKey == "" then
        return nil
    end

    if ownerKey:sub(1, 8) == "account:" then
        return {
            ownerType = "account",
            ownerKey = ownerKey,
            accountName = ownerKey:sub(9),
            serial = nil,
        }
    end

    if ownerKey:sub(1, 7) == "serial:" then
        return {
            ownerType = "serial",
            ownerKey = ownerKey,
            accountName = nil,
            serial = ownerKey:sub(8),
        }
    end

    return {
        ownerType = "account",
        ownerKey = "account:" .. ownerKey,
        accountName = ownerKey,
        serial = nil,
    }
end

local function getPlayerAccountName(player)
    if not isElement(player) or getElementType(player) ~= "player" then
        return nil
    end

    local account = getPlayerAccount(player)
    if account and not isGuestAccount(account) then
        return getAccountName(account)
    end

    return nil
end

function getPlayerOwnerKey(player, requireAccount)
    if not isElement(player) or getElementType(player) ~= "player" then
        return nil
    end

    local accountName = getPlayerAccountName(player)
    if accountName then
        return "account:" .. accountName
    end

    if requireAccount then
        return nil
    end

    local serial = getPlayerSerial(player)
    if serial and serial ~= "" then
        return "serial:" .. serial
    end

    return nil
end

function dbExecute(queryText, ...)
    return nativeDbExec(connection, queryText, ...)
end

function dbQuery(queryText, ...)
    return queryRowsInternal(queryText, ...)
end

function ensureOwnerRecord(ownerKey, displayName)
    local ownerData = parseOwnerKey(ownerKey)
    if not ownerData then
        return false
    end

    local now = getTimestamp()
    local existingRow = querySingleInternal("SELECT owner_key FROM players WHERE owner_key = ? LIMIT 1", ownerData.ownerKey)
    if not existingRow then
        return dbExecute(
            "INSERT INTO players (owner_key, account_name, serial, display_name, bank_balance, created_at, updated_at) VALUES (?, ?, ?, ?, 0, ?, ?)",
            ownerData.ownerKey,
            ownerData.accountName,
            ownerData.serial,
            displayName or ownerData.accountName or ownerData.serial or ownerData.ownerKey,
            now,
            now
        )
    end

    return dbExecute(
        "UPDATE players SET account_name = COALESCE(account_name, ?), serial = COALESCE(serial, ?), display_name = COALESCE(?, display_name), updated_at = ? WHERE owner_key = ?",
        ownerData.accountName,
        ownerData.serial,
        displayName,
        now,
        ownerData.ownerKey
    )
end

local function getBankBalance(ownerKey)
    local row = querySingleInternal("SELECT bank_balance FROM players WHERE owner_key = ? LIMIT 1", ownerKey)
    if not row then
        return 0
    end

    return math.floor(tonumber(row.bank_balance) or 0)
end

function ensurePlayerRecord(player, requireAccount)
    local ownerKey = getPlayerOwnerKey(player, requireAccount)
    if not ownerKey then
        return nil
    end

    local displayName = sanitizePlayerName(getPlayerName(player))
    ensureOwnerRecord(ownerKey, displayName)

    dbExecute(
        "UPDATE players SET account_name = ?, serial = ?, display_name = ?, updated_at = ? WHERE owner_key = ?",
        getPlayerAccountName(player),
        getPlayerSerial(player),
        displayName,
        getTimestamp(),
        ownerKey
    )

    return ownerKey
end

function isMigrationComplete(migrationName)
    migrationName = tostring(migrationName or "")
    if migrationName == "" then
        return false
    end

    return querySingleInternal("SELECT migration_name FROM migration_state WHERE migration_name = ? LIMIT 1", migrationName) ~= nil
end

function markMigrationComplete(migrationName)
    migrationName = tostring(migrationName or "")
    if migrationName == "" then
        return false
    end

    return dbExecute(
        "INSERT OR REPLACE INTO migration_state (migration_name, migrated_at) VALUES (?, ?)",
        migrationName,
        getTimestamp()
    )
end

function hasPropertyKeyAccess(houseId, ownerKey)
    houseId = tonumber(houseId)
    ownerKey = tostring(ownerKey or "")
    if not houseId or ownerKey == "" then return false end
    return querySingleInternal(
        "SELECT id FROM property_keys WHERE house_id = ? AND grantee_key = ? LIMIT 1",
        houseId, ownerKey
    ) ~= nil
end

function grantPropertyKey(houseId, granteeKey, grantedByKey)
    houseId = tonumber(houseId)
    granteeKey = tostring(granteeKey or "")
    grantedByKey = tostring(grantedByKey or "")
    if not houseId or granteeKey == "" then return false end
    return dbExecute(
        "INSERT OR IGNORE INTO property_keys (house_id, grantee_key, granted_by, granted_at) VALUES (?, ?, ?, ?)",
        houseId, granteeKey, grantedByKey, getTimestamp()
    )
end

function revokePropertyKey(houseId, granteeKey)
    houseId = tonumber(houseId)
    granteeKey = tostring(granteeKey or "")
    if not houseId or granteeKey == "" then return false end
    return dbExecute(
        "DELETE FROM property_keys WHERE house_id = ? AND grantee_key = ?",
        houseId, granteeKey
    )
end

local function mergeOwnerKeys(fromOwnerKey, toOwnerKey)
    if not fromOwnerKey or not toOwnerKey or fromOwnerKey == toOwnerKey then
        return
    end

    ensureOwnerRecord(fromOwnerKey)
    ensureOwnerRecord(toOwnerKey)

    for _, row in ipairs(queryRowsInternal("SELECT item_name, amount FROM items WHERE owner_key = ?", fromOwnerKey)) do
        local existingRow = querySingleInternal(
            "SELECT amount FROM items WHERE owner_key = ? AND item_name = ? LIMIT 1",
            toOwnerKey,
            row.item_name
        )
        local totalAmount = (existingRow and tonumber(existingRow.amount) or 0) + (tonumber(row.amount) or 0)
        dbExecute(
            "INSERT OR REPLACE INTO items (owner_key, item_name, amount) VALUES (?, ?, ?)",
            toOwnerKey,
            row.item_name,
            totalAmount
        )
    end
    dbExecute("DELETE FROM items WHERE owner_key = ?", fromOwnerKey)

    local mergedBalance = getBankBalance(toOwnerKey) + getBankBalance(fromOwnerKey)
    dbExecute("UPDATE players SET bank_balance = ?, updated_at = ? WHERE owner_key = ?", mergedBalance, getTimestamp(), toOwnerKey)

    local targetOwner = parseOwnerKey(toOwnerKey)
    dbExecute(
        "UPDATE houses SET owner_key = ?, owner_account = ? WHERE owner_key = ?",
        toOwnerKey,
        targetOwner and targetOwner.accountName or nil,
        fromOwnerKey
    )
    dbExecute(
        "UPDATE vehicles SET owner_key = ?, owner_account = ? WHERE owner_key = ?",
        toOwnerKey,
        targetOwner and targetOwner.accountName or nil,
        fromOwnerKey
    )

    dbExecute("DELETE FROM players WHERE owner_key = ?", fromOwnerKey)
end

addEventHandler("onResourceStart", resourceRoot, function()
    dbExecute("PRAGMA foreign_keys = ON")
    dbExecute([[
        CREATE TABLE IF NOT EXISTS players (
            owner_key TEXT PRIMARY KEY,
            account_name TEXT,
            serial TEXT,
            display_name TEXT,
            bank_balance INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        )
    ]])
    dbExecute([[
        CREATE TABLE IF NOT EXISTS items (
            owner_key TEXT NOT NULL,
            item_name TEXT NOT NULL,
            amount INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (owner_key, item_name)
        )
    ]])
    dbExecute([[
        CREATE TABLE IF NOT EXISTS houses (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            price INTEGER NOT NULL DEFAULT 0,
            property_type TEXT NOT NULL DEFAULT 'house',
            owner_key TEXT,
            owner_account TEXT,
            locked INTEGER NOT NULL DEFAULT 1,
            exterior_x REAL NOT NULL DEFAULT 0,
            exterior_y REAL NOT NULL DEFAULT 0,
            exterior_z REAL NOT NULL DEFAULT 0,
            exterior_rot REAL NOT NULL DEFAULT 0,
            exterior_interior INTEGER NOT NULL DEFAULT 0,
            interior_x REAL NOT NULL DEFAULT 0,
            interior_y REAL NOT NULL DEFAULT 0,
            interior_z REAL NOT NULL DEFAULT 0,
            interior_rot REAL NOT NULL DEFAULT 0,
            interior_id INTEGER NOT NULL DEFAULT 0,
            dimension INTEGER NOT NULL DEFAULT 0,
            garage_x REAL NOT NULL DEFAULT 0,
            garage_y REAL NOT NULL DEFAULT 0,
            garage_z REAL NOT NULL DEFAULT 0,
            garage_radius REAL NOT NULL DEFAULT 8,
            garage_int_x REAL NOT NULL DEFAULT 0,
            garage_int_y REAL NOT NULL DEFAULT 0,
            garage_int_z REAL NOT NULL DEFAULT 0,
            garage_int_rot REAL NOT NULL DEFAULT 0
        )
    ]])
    dbExecute([[
        CREATE TABLE IF NOT EXISTS property_keys (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            house_id INTEGER NOT NULL,
            grantee_key TEXT NOT NULL,
            granted_by TEXT NOT NULL,
            granted_at INTEGER NOT NULL,
            UNIQUE(house_id, grantee_key)
        )
    ]])
    -- Schema migrations for existing databases
    local colCheck = queryRowsInternal("PRAGMA table_info(houses)")
    local existingCols = {}
    for _, col in ipairs(colCheck) do existingCols[col.name] = true end
    if not existingCols["property_type"] then
        dbExecute("ALTER TABLE houses ADD COLUMN property_type TEXT NOT NULL DEFAULT 'house'")
    end
    if not existingCols["garage_int_x"] then
        dbExecute("ALTER TABLE houses ADD COLUMN garage_int_x REAL NOT NULL DEFAULT 0")
        dbExecute("ALTER TABLE houses ADD COLUMN garage_int_y REAL NOT NULL DEFAULT 0")
        dbExecute("ALTER TABLE houses ADD COLUMN garage_int_z REAL NOT NULL DEFAULT 0")
        dbExecute("ALTER TABLE houses ADD COLUMN garage_int_rot REAL NOT NULL DEFAULT 0")
    end
    dbExecute([[
        CREATE TABLE IF NOT EXISTS vehicles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            owner_key TEXT NOT NULL,
            owner_account TEXT NOT NULL,
            house_id INTEGER,
            model INTEGER NOT NULL,
            pos_x REAL NOT NULL,
            pos_y REAL NOT NULL,
            pos_z REAL NOT NULL,
            rot_x REAL NOT NULL DEFAULT 0,
            rot_y REAL NOT NULL DEFAULT 0,
            rot_z REAL NOT NULL DEFAULT 0,
            interior INTEGER NOT NULL DEFAULT 0,
            dimension INTEGER NOT NULL DEFAULT 0,
            health REAL NOT NULL DEFAULT 1000,
            upgrades TEXT NOT NULL DEFAULT '[]',
            locked INTEGER NOT NULL DEFAULT 0
        )
    ]])
    dbExecute([[
        CREATE TABLE IF NOT EXISTS migration_state (
            migration_name TEXT PRIMARY KEY,
            migrated_at INTEGER NOT NULL
        )
    ]])

    for _, player in ipairs(getElementsByType("player")) do
        ensurePlayerRecord(player, false)
    end
end)

addEventHandler("onPlayerJoin", root, function()
    ensurePlayerRecord(source, false)
end)

addEventHandler("onPlayerLogin", root, function(_, currentAccount)
    local serial = getPlayerSerial(source)
    local accountOwnerKey = "account:" .. getAccountName(currentAccount)
    ensureOwnerRecord(accountOwnerKey, sanitizePlayerName(getPlayerName(source)))

    if serial and serial ~= "" then
        mergeOwnerKeys("serial:" .. serial, accountOwnerKey)
    end

    ensurePlayerRecord(source, true)
end)

addEventHandler("onPlayerQuit", root, function()
    ensurePlayerRecord(source, false)
end)
