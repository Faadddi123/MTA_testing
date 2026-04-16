-- housing/client.lua
-- Client side logic for housing system. Handles global property keybinds.

local function canTrigger()
    return not isChatBoxInputActive() and not isConsoleActive() and not isMainMenuActive()
end

local function requestEnterExit()
    if canTrigger() then
        triggerServerEvent("housing:requestEnter", localPlayer)
    end
end

local function requestBuy()
    if canTrigger() then
        triggerServerEvent("housing:requestBuy", localPlayer)
    end
end

local function requestLock()
    if canTrigger() then
        triggerServerEvent("housing:requestToggleLock", localPlayer)
    end
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    -- Global binds for housing. Server-side logic will check proximity.
    bindKey("f", "down", requestEnterExit)
    bindKey("b", "down", requestBuy)
    bindKey("g", "down", requestLock)
end)
