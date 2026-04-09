-- garage_system/client.lua
-- Displays an on-screen hint when the player is near a garage zone marker.

local screenWidth, screenHeight = guiGetScreenSize()
local nearGarageHint = false
local nearGarageHouseId = nil

local function isInGarageDimension()
    local dim = getElementDimension(localPlayer)
    return dim >= 7001 and dim <= 7030
end

-- Draw hint text near top center of screen
local function drawGarageHint()
    if nearGarageHint and not isInGarageDimension() then
        local text = "Press [E] or enter marker to access garage"
        dxDrawText(text, screenWidth * 0.5 - 200, screenHeight * 0.85, screenWidth * 0.5 + 200, screenHeight * 0.9,
            tocolor(80, 180, 255, 220), 1.0, "default-bold", "center", "center", false, false, true)
    end

    if isInGarageDimension() then
        local lines = {
            "/exitgarage  – leave garage",
            "/parkgarage  – save vehicle here",
            "/park        – save vehicle (general)",
        }
        local y = screenHeight * 0.08
        for _, line in ipairs(lines) do
            dxDrawText(line, screenWidth * 0.5 - 200, y, screenWidth * 0.5 + 200, y + 18,
                tocolor(100, 200, 255, 200), 0.85, "default-bold", "center", "center", false, false, true)
            y = y + 20
        end
    end
end

addEventHandler("onClientRender", root, drawGarageHint)

addEventHandler("onClientResourceStart", resourceRoot, function()
    -- Marker proximity detection
    setTimer(function()
        if not isElement(localPlayer) then return end

        local px, py, pz = getElementPosition(localPlayer)
        local dim = getElementDimension(localPlayer)

        -- Only check when in exterior world
        if dim ~= 0 then
            if nearGarageHint then
                nearGarageHint = false
                nearGarageHouseId = nil
            end
            return
        end

        -- Check all garage markers (server-synced via element data)
        local found = false
        for _, marker in ipairs(getElementsByType("marker")) do
            local houseId = getElementData(marker, "garage:houseId")
            if houseId and getElementDimension(marker) == 0 then
                local mx, my, mz = getElementPosition(marker)
                local dist = getDistanceBetweenPoints3D(px, py, pz, mx, my, mz)
                if dist < 8 then
                    found = true
                    nearGarageHouseId = houseId
                    break
                end
            end
        end

        nearGarageHint = found
        if not found then nearGarageHouseId = nil end
    end, 500, 0)
end)
