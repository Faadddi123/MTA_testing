local DATA_ENABLED = "womenChase:enabled"
local DATA_COUNT = "womenChase:count"
local DATA_PED = "womenChase:ped"
local DATA_TARGET_SERIAL = "womenChase:targetSerial"
local DATA_WALK_STYLE = "womenChase:walkStyle"

local UPDATE_INTERVAL = 400
local ATTACK_INTERVAL = 850
local RESPAWN_DELAY = 1000
local TELEPORT_DISTANCE = 70
local ATTACK_DISTANCE = 2.1
local SPAWN_MIN_DISTANCE = 8
local SPAWN_MAX_DISTANCE = 18
local MAX_COUNT = 100
local DAMAGE_PER_ATTACKER = 5
local MAX_ATTACKERS_COUNTED = 6
local CHASE_WEAPON = 5

local femaleModels = {
    9, 10, 11, 12, 13,
    31, 38, 39, 40, 41,
    53, 54, 55, 56, 63,
    64, 69, 75, 76, 85,
    88, 89, 90, 91, 92,
    93, 129, 130, 131, 141,
    145, 148, 150, 151, 169,
    172, 178, 190, 191, 192,
    193, 194, 195, 211, 214,
    215, 216, 219, 224, 225,
    226, 232, 233, 238, 243,
}

local femaleWalkingStyles = {
    129, -- woman
    131, -- busywoman
    132, -- sexywoman
    136, -- jogwoman
}

local modeEnabled = true
local womenCount = 100
local chasePeds = {}
local updateTimer
local attackTimer
local respawnTimer

local function clampCount(value)
    value = math.floor(tonumber(value) or womenCount)
    if value < 1 then
        value = 1
    elseif value > MAX_COUNT then
        value = MAX_COUNT
    end

    return value
end

local function findRotation(x1, y1, x2, y2)
    local rotation = -math.deg(math.atan2(x2 - x1, y2 - y1))
    if rotation < 0 then
        rotation = rotation + 360
    end

    return rotation
end

local function hasWomenModeAccess(player)
    return hasObjectPermissionTo(player, "command.start", false)
        or hasObjectPermissionTo(player, "function.startResource", false)
        or hasObjectPermissionTo(player, "function.banPlayer", false)
end

local function sendModeMessage(target, message, r, g, b)
    if target and isElement(target) then
        outputChatBox(message, target, r, g, b, true)
    else
        outputServerLog(message:gsub("#%x%x%x%x%x%x", ""))
    end
end

local function syncModeState()
    setElementData(root, DATA_ENABLED, modeEnabled, true)
    setElementData(root, DATA_COUNT, womenCount, true)
end

local function getAlivePlayers()
    local players = {}

    for _, player in ipairs(getElementsByType("player")) do
        if not isPedDead(player) then
            players[#players + 1] = player
        end
    end

    return players
end

local function stopTimers()
    if isTimer(updateTimer) then
        killTimer(updateTimer)
    end

    if isTimer(attackTimer) then
        killTimer(attackTimer)
    end

    if isTimer(respawnTimer) then
        killTimer(respawnTimer)
    end

    updateTimer = nil
    attackTimer = nil
    respawnTimer = nil
end

local function clearPedTarget(ped)
    if not isElement(ped) then
        return
    end

    setElementData(ped, DATA_TARGET_SERIAL, "", true)
end

local function destroySwarm()
    for ped in pairs(chasePeds) do
        if isElement(ped) then
            clearPedTarget(ped)
            destroyElement(ped)
        end
    end

    chasePeds = {}
end

local function getNearestAlivePlayer(x, y, z, interior, dimension)
    local nearestPlayer
    local nearestDistance

    for _, player in ipairs(getAlivePlayers()) do
        if getElementInterior(player) == interior and getElementDimension(player) == dimension then
            local px, py, pz = getElementPosition(player)
            local distance = getDistanceBetweenPoints3D(x, y, z, px, py, pz)
            if not nearestDistance or distance < nearestDistance then
                nearestDistance = distance
                nearestPlayer = player
            end
        end
    end

    return nearestPlayer, nearestDistance
end

local function assignPedTarget(ped, player)
    if not isElement(ped) then
        return
    end

    local serial = ""
    if isElement(player) then
        serial = getPlayerSerial(player) or ""
        if setElementSyncer then
            setElementSyncer(ped, player, true)
        end
    end

    setElementData(ped, DATA_TARGET_SERIAL, serial, true)
end

local function spawnSinglePed(anchorPlayer, index)
    if not isElement(anchorPlayer) then
        return nil
    end

    local px, py, pz = getElementPosition(anchorPlayer)
    local angle = ((index - 1) / math.max(womenCount, 1)) * math.pi * 2 + math.rad(math.random(-25, 25))
    local distance = math.random(SPAWN_MIN_DISTANCE, SPAWN_MAX_DISTANCE)
    local spawnX = px + math.cos(angle) * distance
    local spawnY = py + math.sin(angle) * distance
    local spawnZ = pz
    local model = femaleModels[((index - 1) % #femaleModels) + 1]
    local walkingStyle = femaleWalkingStyles[((index - 1) % #femaleWalkingStyles) + 1]
    local ped = createPed(model, spawnX, spawnY, spawnZ, math.random(0, 359))

    if not ped then
        return nil
    end

    setElementInterior(ped, getElementInterior(anchorPlayer))
    setElementDimension(ped, getElementDimension(anchorPlayer))
    setElementCollisionsEnabled(ped, false)
    setPedWalkingStyle(ped, walkingStyle)
    giveWeapon(ped, CHASE_WEAPON, 1, true)
    setPedWeaponSlot(ped, 1)
    setElementData(ped, DATA_PED, true, true)
    setElementData(ped, DATA_WALK_STYLE, walkingStyle, true)
    assignPedTarget(ped, anchorPlayer)
    chasePeds[ped] = true
    return ped
end

local function ensureSwarm(anchorPlayer)
    if not modeEnabled then
        return
    end

    local players = getAlivePlayers()
    if #players == 0 then
        destroySwarm()
        return
    end

    local anchors = {}
    if isElement(anchorPlayer) and not isPedDead(anchorPlayer) then
        anchors[1] = anchorPlayer
    else
        for index, player in ipairs(players) do
            anchors[index] = player
        end
    end

    local livePeds = {}
    for ped in pairs(chasePeds) do
        if isElement(ped) and not isPedDead(ped) then
            livePeds[#livePeds + 1] = ped
        else
            chasePeds[ped] = nil
        end
    end

    while #livePeds > womenCount do
        local ped = table.remove(livePeds)
        chasePeds[ped] = nil
        if isElement(ped) then
            clearPedTarget(ped)
            destroyElement(ped)
        end
    end

    while #livePeds < womenCount do
        local anchor = anchors[((#livePeds) % #anchors) + 1]
        local ped = spawnSinglePed(anchor, #livePeds + 1)
        if not ped then
            break
        end

        livePeds[#livePeds + 1] = ped
    end
end

local function queueRespawn(anchorPlayer, delay)
    if isTimer(respawnTimer) then
        killTimer(respawnTimer)
    end

    respawnTimer = setTimer(function(player)
        respawnTimer = nil
        ensureSwarm(player)
    end, delay or RESPAWN_DELAY, 1, anchorPlayer)
end

local function updateSwarm()
    if not modeEnabled then
        return
    end

    local players = getAlivePlayers()
    if #players == 0 then
        destroySwarm()
        return
    end

    ensureSwarm(players[1])

    local needsRespawn = false
    for ped in pairs(chasePeds) do
        if not isElement(ped) or isPedDead(ped) then
            chasePeds[ped] = nil
            needsRespawn = true
        else
            local pedX, pedY, pedZ = getElementPosition(ped)
            local target, distance = getNearestAlivePlayer(pedX, pedY, pedZ, getElementInterior(ped), getElementDimension(ped))

            if not target then
                target = players[((math.random(1, #players) - 1) % #players) + 1]
                distance = nil
            end

            if target then
                local targetInterior = getElementInterior(target)
                local targetDimension = getElementDimension(target)
                local tx, ty, tz = getElementPosition(target)

                assignPedTarget(ped, target)

                if getElementInterior(ped) ~= targetInterior then
                    setElementInterior(ped, targetInterior)
                end

                if getElementDimension(ped) ~= targetDimension then
                    setElementDimension(ped, targetDimension)
                end

                if not distance or distance > TELEPORT_DISTANCE then
                    local angle = math.random() * math.pi * 2
                    local offset = math.random(SPAWN_MIN_DISTANCE, SPAWN_MAX_DISTANCE)
                    setElementPosition(ped, tx + math.cos(angle) * offset, ty + math.sin(angle) * offset, tz)
                end

                setPedRotation(ped, findRotation(pedX, pedY, tx, ty))
            else
                clearPedTarget(ped)
            end
        end
    end

    if needsRespawn then
        queueRespawn(players[1], 300)
    end
end

local function attackPlayers()
    if not modeEnabled then
        return
    end

    local attackersByPlayer = {}

    for ped in pairs(chasePeds) do
        if isElement(ped) and not isPedDead(ped) then
            local pedX, pedY, pedZ = getElementPosition(ped)
            local target = getNearestAlivePlayer(pedX, pedY, pedZ, getElementInterior(ped), getElementDimension(ped))

            if target then
                local px, py, pz = getElementPosition(target)
                local distance = getDistanceBetweenPoints3D(pedX, pedY, pedZ, px, py, pz)

                if distance <= ATTACK_DISTANCE then
                    attackersByPlayer[target] = (attackersByPlayer[target] or 0) + 1
                end
            end
        end
    end

    for player, attackers in pairs(attackersByPlayer) do
        if isElement(player) and not isPedDead(player) then
            local damage = math.min(attackers, MAX_ATTACKERS_COUNTED) * DAMAGE_PER_ATTACKER
            local health = getElementHealth(player)
            setElementHealth(player, math.max(0, health - damage))
        end
    end
end

local function startModeLoops(anchorPlayer)
    if not isTimer(updateTimer) then
        updateTimer = setTimer(updateSwarm, UPDATE_INTERVAL, 0)
    end

    if not isTimer(attackTimer) then
        attackTimer = setTimer(attackPlayers, ATTACK_INTERVAL, 0)
    end

    queueRespawn(anchorPlayer, 150)
end

addEventHandler("onResourceStart", resourceRoot, function()
    syncModeState()
    if modeEnabled then
        startModeLoops()
    end

    outputServerLog(("women_chase: enabled=%s count=%d"):format(tostring(modeEnabled), womenCount))
end)

addEventHandler("onResourceStop", resourceRoot, function()
    setElementData(root, DATA_ENABLED, false, true)
    stopTimers()
    destroySwarm()
end)

addEventHandler("onPlayerSpawn", root, function()
    if modeEnabled then
        queueRespawn(source, 250)
    end
end)

addEventHandler("onPlayerQuit", root, function()
    if modeEnabled then
        queueRespawn(getAlivePlayers()[1], 250)
    end
end)

addEventHandler("onPlayerWasted", root, function()
    if modeEnabled then
        queueRespawn(getAlivePlayers()[1], RESPAWN_DELAY)
    end
end)

addEventHandler("onPedWasted", root, function()
    if chasePeds[source] then
        chasePeds[source] = nil
        if modeEnabled then
            queueRespawn(getAlivePlayers()[1], 500)
        end
    end
end)

addCommandHandler("womenmode", function(player, _, action, value)
    local isConsole = not (player and isElement(player))

    if not isConsole and not hasWomenModeAccess(player) then
        outputChatBox("Women mode: admin rights required.", player, 255, 80, 80, true)
        return
    end

    action = (action or "status"):lower()

    if action == "on" then
        modeEnabled = true
        syncModeState()
        startModeLoops(player)
        ensureSwarm(player)
        outputChatBox(("Women mode: enabled. %d women are spawning and chasing live players now."):format(womenCount), root, 255, 105, 180, true)
        if isConsole then
            sendModeMessage(nil, "Women mode: enabled.", 255, 105, 180)
        end
        return
    end

    if action == "off" then
        modeEnabled = false
        syncModeState()
        stopTimers()
        destroySwarm()
        outputChatBox("Women mode: disabled.", root, 255, 180, 180, true)
        if isConsole then
            sendModeMessage(nil, "Women mode: disabled.", 255, 180, 180)
        end
        return
    end

    if action == "count" then
        local newCount = tonumber(value)
        if not newCount then
            sendModeMessage(player, "Usage: /womenmode count <1-100>", 255, 220, 120)
            return
        end

        womenCount = clampCount(newCount)
        syncModeState()
        if modeEnabled then
            ensureSwarm(player)
        end
        outputChatBox(("Women mode: chase count set to %d."):format(womenCount), root, 255, 105, 180, true)
        if isConsole then
            sendModeMessage(nil, ("Women mode: count set to %d."):format(womenCount), 255, 105, 180)
        end
        return
    end

    if action ~= "status" then
        sendModeMessage(player, "Usage: /womenmode <on|off|count|status>", 255, 220, 120)
        return
    end

    sendModeMessage(player, ("Women mode: %s, count=%d."):format(modeEnabled and "enabled" or "disabled", womenCount), 255, 220, 120)
end)
