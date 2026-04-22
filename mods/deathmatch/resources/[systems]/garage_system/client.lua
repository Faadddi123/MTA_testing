-- garage_system/client.lua
-- Displays hints near garage markers and lets players use F to enter or exit.

local screenWidth, screenHeight = guiGetScreenSize()
local nearGarageHint = false
local nearGarageHouseId = nil
local nearGarageMarkerType = nil
local MAX_DISTANCE = 4

local function isInGarageDimension()
    local val = getElementData(localPlayer, "garage:inside")
    if not val or val == false or val == "" then
        return false
    end
    return true
end

local function canTrigger()
    return not isChatBoxInputActive() and not isConsoleActive() and not isMainMenuActive()
end

local function getNearestGarageMarker()
    if not isElement(localPlayer) then
        return nil, nil
    end

    local px, py, pz = getElementPosition(localPlayer)
    local playerDim = getElementDimension(localPlayer)
    local playerInt = getElementInterior(localPlayer)
    local bestMarker = nil
    local bestDistance = math.huge

    for _, marker in ipairs(getElementsByType("marker", resourceRoot)) do
        local houseId = tonumber(getElementData(marker, "garage:houseId"))
        local markerType = getElementData(marker, "garage:markerType")
        if houseId and markerType and getElementDimension(marker) == playerDim and getElementInterior(marker) == playerInt then
            local mx, my, mz = getElementPosition(marker)
            local dist = getDistanceBetweenPoints3D(px, py, pz, mx, my, mz)
            if dist < bestDistance then
                bestMarker = marker
                bestDistance = dist
            end
        end
    end

    if not bestMarker then
        return nil, nil, nil
    end

    if bestDistance > MAX_DISTANCE then
        return nil, nil, nil
    end

    return tonumber(getElementData(bestMarker, "garage:houseId")), getElementData(bestMarker, "garage:markerType"), bestMarker
end

local wasNearGarage = false

local function refreshGarageHint()
    local houseId, markerType, marker = getNearestGarageMarker()
    nearGarageHouseId = houseId
    nearGarageMarkerType = markerType
    nearGarageHint = houseId ~= nil and markerType ~= nil

    if nearGarageHint and not wasNearGarage then
        if nearGarageMarkerType == "entry" then
            local name = getElementData(marker, "garage:name") or "Garage"
            local owner = getElementData(marker, "garage:owner") or ""
            local price = tonumber(getElementData(marker, "garage:price")) or 0

            if owner == "" then
                -- Unowned garage: show full buy info
                outputChatBox("Garage: " .. tostring(name) .. " - For Sale ($" .. tostring(price) .. ")", 100, 255, 100)
                outputChatBox("Type /buy_garage to purchase. Press [F] to enter.", 255, 255, 100)
            else
                -- Owned garage: just show press F
                outputChatBox("Garage: " .. tostring(name) .. " - Press [F] to enter.", 100, 200, 255)
            end
        else
            outputChatBox("Press [F] to exit the garage.", 80, 180, 255)
        end
    end
    wasNearGarage = nearGarageHint
end

local function requestGarageInteract()
    if not canTrigger() then
        return
    end

    refreshGarageHint()

    if nearGarageMarkerType == "entry" then
        triggerServerEvent("garage:requestEnter", localPlayer, nearGarageHouseId)
    elseif nearGarageMarkerType == "exit" then
        triggerServerEvent("garage:requestExit", localPlayer, nearGarageHouseId)
    end
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    bindKey("f", "down", requestGarageInteract)

    setTimer(function()
        if not isElement(localPlayer) then
            return
        end
        refreshGarageHint()
    end, 250, 0)
end)
