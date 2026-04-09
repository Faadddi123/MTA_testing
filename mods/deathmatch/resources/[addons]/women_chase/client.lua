local DATA_ENABLED = "womenChase:enabled"
local DATA_PED = "womenChase:ped"
local DATA_TARGET_SERIAL = "womenChase:targetSerial"
local DATA_WALK_STYLE = "womenChase:walkStyle"

local UPDATE_INTERVAL = 100
local ATTACK_DISTANCE = 2.1
local RUN_DISTANCE = 7

local controlledPeds = {}
local updateTimer

local function findRotation(x1, y1, x2, y2)
    local rotation = -math.deg(math.atan2(x2 - x1, y2 - y1))
    if rotation < 0 then
        rotation = rotation + 360
    end

    return rotation
end

local function clearPedControls(ped)
    if not isElement(ped) then
        return
    end

    setPedControlState(ped, "forwards", false)
    setPedControlState(ped, "sprint", false)
    setPedControlState(ped, "walk", false)
    setPedControlState(ped, "fire", false)
end

local function clearAllControlledPeds()
    for ped in pairs(controlledPeds) do
        if isElement(ped) then
            clearPedControls(ped)
        end
    end

    controlledPeds = {}
end

local function isModeEnabled()
    return getElementData(root, DATA_ENABLED) == true
end

local function isPedAssignedToLocalPlayer(ped)
    return getElementData(ped, DATA_PED) == true
        and getElementData(ped, DATA_TARGET_SERIAL) == getPlayerSerial(localPlayer)
end

local function applyWalkingStyle(ped)
    local style = tonumber(getElementData(ped, DATA_WALK_STYLE)) or 136
    if getPedWalkingStyle(ped) ~= style then
        setPedAnimation(ped)
        setPedWalkingStyle(ped, style)
    end
end

local function updateControlledPeds()
    if not isModeEnabled() or isPedDead(localPlayer) then
        clearAllControlledPeds()
        return
    end

    local seen = {}
    local playerInterior = getElementInterior(localPlayer)
    local playerDimension = getElementDimension(localPlayer)
    local px, py, pz = getElementPosition(localPlayer)

    for _, ped in ipairs(getElementsByType("ped", root, true)) do
        if isElement(ped)
            and not isPedDead(ped)
            and isPedAssignedToLocalPlayer(ped)
            and getElementInterior(ped) == playerInterior
            and getElementDimension(ped) == playerDimension then
            local ex, ey, ez = getElementPosition(ped)
            local distance = getDistanceBetweenPoints3D(ex, ey, ez, px, py, pz)

            seen[ped] = true
            controlledPeds[ped] = true

            applyWalkingStyle(ped)
            setPedRotation(ped, findRotation(ex, ey, px, py))

            if distance > ATTACK_DISTANCE then
                setPedControlState(ped, "fire", false)
                setPedControlState(ped, "walk", false)
                setPedControlState(ped, "forwards", true)
                setPedControlState(ped, "sprint", distance > RUN_DISTANCE)
            else
                setPedControlState(ped, "forwards", false)
                setPedControlState(ped, "sprint", false)
                setPedControlState(ped, "walk", false)
                setPedControlState(ped, "fire", true)
            end
        end
    end

    for ped in pairs(controlledPeds) do
        if not seen[ped] then
            if isElement(ped) then
                clearPedControls(ped)
            end

            controlledPeds[ped] = nil
        end
    end
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    updateTimer = setTimer(updateControlledPeds, UPDATE_INTERVAL, 0)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if isTimer(updateTimer) then
        killTimer(updateTimer)
    end

    updateTimer = nil
    clearAllControlledPeds()
end)

addEventHandler("onClientElementDestroy", root, function()
    if controlledPeds[source] then
        controlledPeds[source] = nil
    end
end)
