local screenWidth, screenHeight = guiGetScreenSize()

local uiState = {
    browser = nil,
    browserReady = false,
    inventoryVisible = false,
    housePopupVisible = false,
    inventoryPayload = {
        items = {},
        currentWeight = 0,
        maxWeight = 35,
        quickSlots = {},
    },
    housePopupPayload = nil,
}

local remoteBrowserDomains = {
    "https://cdnjs.cloudflare.com",
}

local function jsBool(value)
    return value and "true" or "false"
end

local function encodeJson(data)
    return toJSON(data or {}, true)
end

local function executeUiJavaScript(code)
    if uiState.browserReady and isElement(uiState.browser) then
        executeBrowserJavascript(uiState.browser, code)
    end
end

local function drawUiBrowser()
    if not isElement(uiState.browser) then
        return
    end

    if not uiState.inventoryVisible and not uiState.housePopupVisible then
        return
    end

    dxDrawImage(0, 0, screenWidth, screenHeight, uiState.browser, 0, 0, 0, tocolor(255, 255, 255, 255), true)
end

local function syncUiState()
    if not uiState.browserReady then
        return
    end

    executeUiJavaScript("window.setInventoryVisible(" .. jsBool(uiState.inventoryVisible) .. ");")
    executeUiJavaScript("window.updateInventory(" .. encodeJson(uiState.inventoryPayload) .. ");")
    executeUiJavaScript("window.setHousePopupVisible(" .. jsBool(uiState.housePopupVisible) .. ");")
    executeUiJavaScript("window.updateHousePopup(" .. encodeJson(uiState.housePopupPayload or {}) .. ");")
end

local function refreshFocus()
    local shouldFocusUi = uiState.inventoryVisible or uiState.housePopupVisible
    showCursor(shouldFocusUi)

    if shouldFocusUi and isElement(uiState.browser) then
        focusBrowser(uiState.browser)
    else
        focusBrowser(nil)
    end
end

local function setInventoryVisible(visible)
    uiState.inventoryVisible = visible and true or false
    refreshFocus()
    executeUiJavaScript("window.setInventoryVisible(" .. jsBool(uiState.inventoryVisible) .. ");")

    if uiState.inventoryVisible then
        triggerServerEvent("inventory:requestContents", localPlayer)
    end
end

local function hideHousePopup()
    uiState.housePopupVisible = false
    uiState.housePopupPayload = nil
    refreshFocus()
    executeUiJavaScript("window.setHousePopupVisible(false);")
end

local function showHousePopup(payload)
    uiState.housePopupVisible = true
    uiState.housePopupPayload = payload or {}
    refreshFocus()
    executeUiJavaScript("window.updateHousePopup(" .. encodeJson(uiState.housePopupPayload) .. ");")
    executeUiJavaScript("window.setHousePopupVisible(true);")
end

function updateInventory(data)
    uiState.inventoryPayload = data or {
        items = {},
        currentWeight = 0,
        maxWeight = 35,
        quickSlots = {},
    }

    executeUiJavaScript("window.updateInventory(" .. encodeJson(uiState.inventoryPayload) .. ");")
end

local function toggleInventory()
    if isChatBoxInputActive() or isConsoleActive() or isMainMenuActive() then
        return
    end

    setInventoryVisible(not uiState.inventoryVisible)
end

local function createUiBrowser()
    if isElement(uiState.browser) then
        return
    end

    uiState.browser = createBrowser(screenWidth, screenHeight, true, true)
    if not uiState.browser then
        outputChatBox("Inventory UI: failed to create browser.", 255, 80, 80, true)
        return
    end

    if requestBrowserDomains then
        requestBrowserDomains(remoteBrowserDomains, true)
    elseif Browser and Browser.requestDomains then
        Browser.requestDomains(remoteBrowserDomains, true)
    end

    addEventHandler("onClientBrowserCreated", uiState.browser, function()
        loadBrowserURL(source, "http://mta/local/web/index.html")
    end)

    addEventHandler("onClientBrowserDocumentReady", uiState.browser, function()
        uiState.browserReady = true
        syncUiState()
    end)
end

local function popupExpired()
    if not uiState.housePopupVisible or not uiState.housePopupPayload or not uiState.housePopupPayload.position then
        return false
    end

    local position = uiState.housePopupPayload.position
    local x = tonumber(position.x)
    local y = tonumber(position.y)
    local z = tonumber(position.z)
    local radius = tonumber(position.radius) or 6
    local popupInterior = tonumber(position.interior) or 0
    local popupDimension = tonumber(position.dimension) or 0

    if not x or not y or not z then
        return true
    end

    if getElementInterior(localPlayer) ~= popupInterior or getElementDimension(localPlayer) ~= popupDimension then
        return true
    end

    local px, py, pz = getElementPosition(localPlayer)
    return getDistanceBetweenPoints3D(px, py, pz, x, y, z) > radius
end

addEvent("inventory:receiveContents", true)
addEventHandler("inventory:receiveContents", root, function(payload)
    updateInventory(payload or {})
end)

addEvent("rp_ui:showHousePopup", true)
addEventHandler("rp_ui:showHousePopup", root, function(payload)
    showHousePopup(payload)
end)

addEvent("rp_ui:hideHousePopup", true)
addEventHandler("rp_ui:hideHousePopup", root, function()
    hideHousePopup()
end)

addEvent("inventory:browserClose", true)
addEventHandler("inventory:browserClose", root, function()
    if uiState.inventoryVisible then
        setInventoryVisible(false)
    end
end)

addEvent("housing:browserBuy", true)
addEventHandler("housing:browserBuy", root, function()
    triggerServerEvent("housing:requestBuy", localPlayer, uiState.housePopupPayload and uiState.housePopupPayload.id or false)
end)

addEvent("housing:browserEnter", true)
addEventHandler("housing:browserEnter", root, function()
    triggerServerEvent("housing:requestEnter", localPlayer, uiState.housePopupPayload and uiState.housePopupPayload.id or false)
end)

addEvent("housing:browserLock", true)
addEventHandler("housing:browserLock", root, function()
    triggerServerEvent("housing:requestToggleLock", localPlayer, uiState.housePopupPayload and uiState.housePopupPayload.id or false)
end)

addEvent("vehicles:browserPark", true)
addEventHandler("vehicles:browserPark", root, function()
    triggerServerEvent("vehicles:requestPark", localPlayer, uiState.housePopupPayload and uiState.housePopupPayload.id or false)
end)

addEventHandler("onClientRender", root, function()
    if popupExpired() then
        hideHousePopup()
    end

    drawUiBrowser()
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    createUiBrowser()
    bindKey("i", "down", toggleInventory)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    showCursor(false)
    focusBrowser(nil)
end)
