-- housing/client.lua
-- Client side logic for housing system. Handles global property keybinds.

local function canTrigger()
    return not isChatBoxInputActive() and not isConsoleActive() and not isMainMenuActive()
end

local function debugHousing(message)
    if getElementData(localPlayer, "housing:debug") ~= true then
        return
    end
    outputChatBox("[HousingDebug] " .. tostring(message), 255, 220, 120, true)
end

local function requestEnterExit()
    if canTrigger() then
        debugHousing("housing/client F bind -> housing:requestEnter")
        triggerServerEvent("housing:requestEnter", localPlayer)
    end
end

local function requestBuy()
    if canTrigger() then
        debugHousing("housing/client B bind -> housing:requestBuy")
        triggerServerEvent("housing:requestBuy", localPlayer)
    end
end

local function requestLock()
    if canTrigger() then
        debugHousing("housing/client G bind -> housing:requestToggleLock")
        triggerServerEvent("housing:requestToggleLock", localPlayer)
    end
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    -- Global binds for housing. Server-side logic will check proximity.
    bindKey("f", "down", requestEnterExit)
    bindKey("b", "down", requestBuy)
    bindKey("g", "down", requestLock)
end)
