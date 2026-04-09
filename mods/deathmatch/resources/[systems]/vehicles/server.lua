local spawnedVehicles = {}
local spawnedVehicleRows = {}

local function centralExecute(queryText, ...)
    return exports.database_manager:dbExecute(queryText, ...)
end

local function centralQuery(queryText, ...)
    return exports.database_manager:dbQuery(queryText, ...) or {}
end

local function getPlayerOwnership(player)
    local ownerKey = exports.database_manager:ensurePlayerRecord(player, true)
    if not ownerKey then
        return nil, nil
    end

    local account = getPlayerAccount(player)
    if not account or isGuestAccount(account) then
        return nil, nil
    end

    return ownerKey, getAccountName(account)
end

local function getHouseLockState(houseId)
    if not houseId then
        return false
    end

    local row = centralQuery("SELECT locked FROM houses WHERE id = ? LIMIT 1", houseId)[1]
    return row and tonumber(row.locked) ~= 0 or false
end

local function destroyPersistentVehicles()
    for vehicle in pairs(spawnedVehicles) do
        if isElement(vehicle) then
            destroyElement(vehicle)
        end
    end

    spawnedVehicles = {}
    spawnedVehicleRows = {}
end

local function cacheVehicleRow(vehicle, row)
    local recordId = tonumber(row.id)
    spawnedVehicles[vehicle] = recordId
    spawnedVehicleRows[recordId] = {
        id = recordId,
        owner_key = row.owner_key,
        owner_account = row.owner_account,
        house_id = row.house_id and tonumber(row.house_id) or nil,
        locked = tonumber(row.locked) ~= 0,
        element = vehicle,
    }

    setElementData(vehicle, "vehicles:id", recordId, false)
    setElementData(vehicle, "vehicles:owner", row.owner_account, false)
end

local function spawnVehicleFromRow(row)
    local vehicle = createVehicle(
        tonumber(row.model),
        tonumber(row.pos_x),
        tonumber(row.pos_y),
        tonumber(row.pos_z),
        tonumber(row.rot_x) or 0,
        tonumber(row.rot_y) or 0,
        tonumber(row.rot_z) or 0
    )

    if not vehicle then
        return
    end

    setElementInterior(vehicle, tonumber(row.interior) or 0)
    setElementDimension(vehicle, tonumber(row.dimension) or 0)
    setElementHealth(vehicle, tonumber(row.health) or 1000)
    setVehicleLocked(vehicle, tonumber(row.locked) ~= 0)

    local upgrades = fromJSON(row.upgrades or "[]") or {}
    if type(upgrades) == "table" then
        for _, upgradeId in ipairs(upgrades) do
            upgradeId = tonumber(upgradeId)
            if upgradeId then
                addVehicleUpgrade(vehicle, upgradeId)
            end
        end
    end

    setElementParent(vehicle, resourceRoot)
    cacheVehicleRow(vehicle, row)
end

local function respawnPersistentVehicles()
    destroyPersistentVehicles()

    for _, row in ipairs(centralQuery("SELECT * FROM vehicles ORDER BY id ASC")) do
        spawnVehicleFromRow(row)
    end
end

local function getLinkedGarageHouseId(ownerKey, vehicle)
    local housingResource = getResourceFromName("housing")
    if not housingResource or getResourceState(housingResource) ~= "running" then
        return nil
    end

    local x, y, z = getElementPosition(vehicle)
    local houseId = exports.housing:getOwnedGarageHouseIdForPosition(ownerKey, x, y, z)
    if not houseId or houseId == false then
        return nil
    end

    return tonumber(houseId)
end

local function serializeUpgrades(vehicle)
    return toJSON(getVehicleUpgrades(vehicle) or {})
end

local function saveVehicleState(vehicle, ownerKey, ownerAccount)
    local x, y, z = getElementPosition(vehicle)
    local rx, ry, rz = getElementRotation(vehicle)
    local houseId = getLinkedGarageHouseId(ownerKey, vehicle)
    local shouldLock = houseId and getHouseLockState(houseId) or isVehicleLocked(vehicle)
    local recordId = spawnedVehicles[vehicle]

    setVehicleLocked(vehicle, shouldLock)

    if recordId then
        centralExecute([[
            UPDATE vehicles SET
                owner_key = ?,
                owner_account = ?,
                house_id = ?,
                model = ?,
                pos_x = ?,
                pos_y = ?,
                pos_z = ?,
                rot_x = ?,
                rot_y = ?,
                rot_z = ?,
                interior = ?,
                dimension = ?,
                health = ?,
                upgrades = ?,
                locked = ?
            WHERE id = ?
        ]],
            ownerKey,
            ownerAccount,
            houseId,
            getElementModel(vehicle),
            x,
            y,
            z,
            rx,
            ry,
            rz,
            getElementInterior(vehicle),
            getElementDimension(vehicle),
            getElementHealth(vehicle),
            serializeUpgrades(vehicle),
            shouldLock and 1 or 0,
            recordId
        )
    else
        centralExecute([[
            INSERT INTO vehicles (
                owner_key, owner_account, house_id, model,
                pos_x, pos_y, pos_z, rot_x, rot_y, rot_z,
                interior, dimension, health, upgrades, locked
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]],
            ownerKey,
            ownerAccount,
            houseId,
            getElementModel(vehicle),
            x,
            y,
            z,
            rx,
            ry,
            rz,
            getElementInterior(vehicle),
            getElementDimension(vehicle),
            getElementHealth(vehicle),
            serializeUpgrades(vehicle),
            shouldLock and 1 or 0
        )

        local row = centralQuery("SELECT last_insert_rowid() AS id")[1]
        recordId = row and tonumber(row.id) or nil
    end

    if not recordId then
        return false
    end

    local savedRow = centralQuery("SELECT * FROM vehicles WHERE id = ? LIMIT 1", recordId)[1]
    if not savedRow then
        return false
    end

    cacheVehicleRow(vehicle, savedRow)
    return true, houseId
end

local function parkVehicleForPlayer(player, requestedHouseId)
    local vehicle = getPedOccupiedVehicle(player)
    if not vehicle or getPedOccupiedVehicleSeat(player) ~= 0 then
        outputChatBox("Vehicles: you must be driving a vehicle to use /park.", player, 255, 80, 80, true)
        return false
    end

    local ownerKey, ownerAccount = getPlayerOwnership(player)
    if not ownerKey or not ownerAccount then
        outputChatBox("Vehicles: you need to be logged into an account to persist vehicles.", player, 255, 80, 80, true)
        return false
    end

    local recordId = spawnedVehicles[vehicle]
    if recordId then
        local record = centralQuery("SELECT owner_key FROM vehicles WHERE id = ? LIMIT 1", recordId)[1]
        if record and record.owner_key ~= ownerKey then
            outputChatBox("Vehicles: this persistent vehicle belongs to another account.", player, 255, 80, 80, true)
            return false
        end
    end

    local linkedHouseId = getLinkedGarageHouseId(ownerKey, vehicle)
    local requestedId = requestedHouseId and requestedHouseId ~= false and tonumber(requestedHouseId) or nil
    if requestedId and requestedId ~= linkedHouseId then
        outputChatBox("Vehicles: move the vehicle into the linked garage area before saving it here.", player, 255, 80, 80, true)
        return false
    end

    local success, houseId = saveVehicleState(vehicle, ownerKey, ownerAccount)
    if not success then
        outputChatBox("Vehicles: failed to save this vehicle.", player, 255, 80, 80, true)
        return false
    end

    local garageMessage = houseId and (" linked to house #" .. houseId .. ".") or " not linked to a garage."
    outputChatBox("Vehicles: parked and saved successfully," .. garageMessage, player, 120, 255, 120, true)
    return true
end

function setGarageVehiclesLocked(houseId, locked)
    houseId = tonumber(houseId)
    locked = locked and true or false
    if not houseId then
        return false
    end

    centralExecute("UPDATE vehicles SET locked = ? WHERE house_id = ?", locked and 1 or 0, houseId)

    for vehicle, recordId in pairs(spawnedVehicles) do
        local row = spawnedVehicleRows[recordId]
        if row and row.house_id == houseId and isElement(vehicle) then
            row.locked = locked
            setVehicleLocked(vehicle, locked)
        end
    end

    return true
end

function releaseHouseVehicles(houseId)
    houseId = tonumber(houseId)
    if not houseId then
        return false
    end

    centralExecute("UPDATE vehicles SET house_id = NULL, locked = 0 WHERE house_id = ?", houseId)

    for vehicle, recordId in pairs(spawnedVehicles) do
        local row = spawnedVehicleRows[recordId]
        if row and row.house_id == houseId then
            row.house_id = nil
            row.locked = false
            if isElement(vehicle) then
                setVehicleLocked(vehicle, false)
            end
        end
    end

    return true
end

addEventHandler("onResourceStart", resourceRoot, function()
    respawnPersistentVehicles()
end)

addEventHandler("onResourceStop", resourceRoot, function()
    destroyPersistentVehicles()
end)

addEventHandler("onElementDestroy", root, function()
    local recordId = spawnedVehicles[source]
    if not recordId then
        return
    end

    spawnedVehicles[source] = nil
    if spawnedVehicleRows[recordId] then
        spawnedVehicleRows[recordId].element = nil
    end
end)

addCommandHandler("park", function(player)
    parkVehicleForPlayer(player, false)
end)

addEvent("vehicles:requestPark", true)
addEventHandler("vehicles:requestPark", root, function(requestedHouseId)
    parkVehicleForPlayer(client, requestedHouseId)
end)
