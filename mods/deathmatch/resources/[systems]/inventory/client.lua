-- inventory/client.lua
-- Browser  → Inventory panel only (F key opened, full cursor capture)
-- House popup → pure dxDraw overlay (no cursor capture, player moves freely)
-- House keys: [F] Enter/Exit  [B] Buy  [G] Lock  [P] Park  [ESC] Close

local screenWidth, screenHeight = guiGetScreenSize()

-- ╔══════════════════════════════════════════════════╗
-- ║  BROWSER STATE  (inventory only)                 ║
-- ╚══════════════════════════════════════════════════╝
local uiState = {
    browser       = nil,
    browserReady  = false,
    inventoryVisible = false,
    inventoryPayload = {
        items        = {},
        currentWeight = 0,
        maxWeight    = 35,
        quickSlots   = {},
    },
}

local remoteBrowserDomains = { "https://cdnjs.cloudflare.com" }

local function jsBool(v)    return v and "true" or "false" end
local function encodeJson(d) return toJSON(d or {}, true)   end

local function executeUiJavaScript(code)
    if uiState.browserReady and isElement(uiState.browser) then
        executeBrowserJavascript(uiState.browser, code)
    end
end

local function drawUiBrowser()
    if not isElement(uiState.browser) then return end
    if not uiState.inventoryVisible then return end
    dxDrawImage(0, 0, screenWidth, screenHeight, uiState.browser, 0, 0, 0, tocolor(255, 255, 255, 255), true)
end

local function refreshInventoryFocus()
    showCursor(uiState.inventoryVisible)
    if uiState.inventoryVisible and isElement(uiState.browser) then
        focusBrowser(uiState.browser)
    else
        focusBrowser(nil)
    end
end

local function setInventoryVisible(visible)
    uiState.inventoryVisible = visible and true or false
    refreshInventoryFocus()
    executeUiJavaScript("window.setInventoryVisible(" .. jsBool(uiState.inventoryVisible) .. ");")
    if uiState.inventoryVisible then
        triggerServerEvent("inventory:requestContents", localPlayer)
    end
end

local function toggleInventory()
    if isChatBoxInputActive() or isConsoleActive() or isMainMenuActive() then return end
    setInventoryVisible(not uiState.inventoryVisible)
end

local function syncInventoryToUi()
    if not uiState.browserReady then return end
    executeUiJavaScript("window.setInventoryVisible(" .. jsBool(uiState.inventoryVisible) .. ");")
    executeUiJavaScript("window.updateInventory(" .. encodeJson(uiState.inventoryPayload) .. ");")
    -- house popup now handled by dxDraw, not browser
    executeUiJavaScript("window.setHousePopupVisible(false);")
end

local function createUiBrowser()
    if isElement(uiState.browser) then return end
    uiState.browser = createBrowser(screenWidth, screenHeight, true, true)
    if not uiState.browser then return end

    if requestBrowserDomains then
        requestBrowserDomains(remoteBrowserDomains, true)
    end

    addEventHandler("onClientBrowserCreated", uiState.browser, function()
        loadBrowserURL(source, "http://mta/local/web/index.html")
    end)

    addEventHandler("onClientBrowserDocumentReady", uiState.browser, function()
        uiState.browserReady = true
        syncInventoryToUi()
    end)
end

function updateInventory(data)
    uiState.inventoryPayload = data or { items = {}, currentWeight = 0, maxWeight = 35, quickSlots = {} }
    executeUiJavaScript("window.updateInventory(" .. encodeJson(uiState.inventoryPayload) .. ");")
end

-- ╔══════════════════════════════════════════════════╗
-- ║  HOUSE POPUP  — dxDraw, NO cursor capture        ║
-- ╚══════════════════════════════════════════════════╝
local housePopup = {
    visible = false,
    payload = nil,
}

local function hideHousePopup()
    housePopup.visible = false
    housePopup.payload = nil
end

local function showHousePopupLocal(payload)
    housePopup.visible = true
    housePopup.payload = payload or {}
end

local function popupExpired()
    if not housePopup.visible or not housePopup.payload then return false end
    local pos = housePopup.payload.position
    if not pos then return true end

    local x   = tonumber(pos.x)
    local y   = tonumber(pos.y)
    local z   = tonumber(pos.z)
    local rad = tonumber(pos.radius) or 6
    local int = tonumber(pos.interior) or 0
    local dim = tonumber(pos.dimension) or 0
    if not x then return true end
    if getElementInterior(localPlayer) ~= int or getElementDimension(localPlayer) ~= dim then
        return true
    end
    local px, py, pz = getElementPosition(localPlayer)
    return getDistanceBetweenPoints3D(px, py, pz, x, y, z) > rad
end

-- ── dxDraw rendering ───────────────────────────────────────────
local function drawHousePopup()
    if not housePopup.visible or not housePopup.payload then return end

    local house = housePopup.payload
    local pw, ph = 310, 210
    local px = screenWidth  - pw - 22
    local py = screenHeight - ph - 22

    local isApartment  = house.property_type == "apartment"
    local accentR, accentG, accentB = isApartment and 255 or 50, isApartment and 130 or 140, isApartment and 40 or 255
    local accentCol    = tocolor(accentR, accentG, accentB, 255)

    -- ── shadow
    dxDrawRectangle(px + 5, py + 5, pw, ph, tocolor(0, 0, 0, 100), true)
    -- ── background
    dxDrawRectangle(px, py, pw, ph, tocolor(10, 12, 20, 235), true)
    -- ── border
    dxDrawRectangle(px,      py,      pw, 1,  tocolor(accentR, accentG, accentB, 80), true)
    dxDrawRectangle(px,      py + ph - 1, pw, 1, tocolor(accentR, accentG, accentB, 40), true)
    dxDrawRectangle(px,      py,      1, ph,  tocolor(accentR, accentG, accentB, 80), true)
    dxDrawRectangle(px + pw - 1, py, 1, ph,  tocolor(accentR, accentG, accentB, 80), true)
    -- ── top accent strip
    dxDrawRectangle(px, py, pw, 4, accentCol, true)

    -- ── type tag
    local typeLabel = isApartment and "APARTMENT" or "HOUSE"
    dxDrawText(typeLabel, px + 12, py + 10, px + pw, py + 23, accentCol, 0.65, "default-bold")

    -- ── property name
    local name = house.name or "Property"
    dxDrawText(name, px + 12, py + 26, px + pw - 12, py + 50, tocolor(245, 245, 255, 255), 1.05, "default-bold")

    -- ── divider
    dxDrawRectangle(px + 12, py + 54, pw - 24, 1, tocolor(35, 40, 65, 255), true)

    -- ── info rows
    local iy = py + 62
    local function row(label, value, vCol)
        dxDrawText(label, px + 12, iy, px + 115, iy + 16, tocolor(120, 130, 165, 255), 0.75, "default")
        dxDrawText(value, px + 115, iy, px + pw - 12, iy + 16, vCol or tocolor(220, 225, 255, 255), 0.75, "default-bold", "left")
        iy = iy + 19
    end

    local ownerText  = house.ownerName or "Available"
    local priceText  = "$" .. tostring(math.floor(tonumber(house.price) or 0))
    local lockedText = house.locked and "\xF0\x9F\x94\x92 Locked" or "\xF0\x9F\x94\x93 Unlocked"
    local lockCol    = house.locked and tocolor(255, 88, 88, 255) or tocolor(88, 230, 130, 255)

    row("Owner",  ownerText,  nil)
    row("Price",  priceText,  tocolor(255, 215, 70, 255))
    row("Status", lockedText, lockCol)

    -- ── divider
    dxDrawRectangle(px + 12, iy + 2, pw - 24, 1, tocolor(35, 40, 65, 255), true)
    iy = iy + 8

    -- ── key hints
    local hints = {}
    if house.canBuy   then hints[#hints + 1] = "\xE2\x96\xBA [B] Buy"       end
    if house.canEnter then hints[#hints + 1] = "\xE2\x96\xBA [F] Enter/Exit" end
    if house.canLock  then hints[#hints + 1] = "\xE2\x96\xBA [G] Lock"       end
    if house.canPark  then hints[#hints + 1] = "\xE2\x96\xBA [P] Park"       end
    hints[#hints + 1] = "\xE2\x96\xBA [ESC] Dismiss"

    for _, hint in ipairs(hints) do
        dxDrawText(hint, px + 14, iy, px + pw - 12, iy + 15, tocolor(90, 170, 255, 210), 0.68, "default")
        iy = iy + 16
    end
end

-- ╔══════════════════════════════════════════════════╗
-- ║  GARAGE DIM HINTS                                ║
-- ╚══════════════════════════════════════════════════╝
local function drawGarageHints()
    local dim = getElementDimension(localPlayer)
    if dim < 7001 or dim > 7030 then return end

    local hints = {
        "[/exitgarage]  Leave garage",
        "[/parkgarage]  Save vehicle here",
        "[/park]        Save vehicle (any zone)",
    }
    local bw, bh = 260, 14 * #hints + 16
    local bx = 20
    local by = screenHeight * 0.08

    dxDrawRectangle(bx - 6, by - 6, bw + 12, bh + 12, tocolor(8, 10, 18, 200), true)
    dxDrawRectangle(bx - 6, by - 6, 3, bh + 12, tocolor(80, 200, 255, 255), true)

    for i, h in ipairs(hints) do
        dxDrawText(h, bx, by + (i - 1) * 14, bx + bw, by + i * 14,
            tocolor(100, 210, 255, 220), 0.75, "default-bold")
    end
end

-- ╔══════════════════════════════════════════════════╗
-- ║  EVENTS → server                                 ║
-- ╚══════════════════════════════════════════════════╝
local function triggerHouseAction(event)
    if not housePopup.visible or not housePopup.payload then return end
    triggerServerEvent(event, localPlayer, housePopup.payload.id or false)
end

-- ╔══════════════════════════════════════════════════╗
-- ║  NETWORK EVENTS ← server                         ║
-- ╚══════════════════════════════════════════════════╝
addEvent("inventory:receiveContents", true)
addEventHandler("inventory:receiveContents", root, function(payload)
    updateInventory(payload or {})
end)

addEvent("rp_ui:showHousePopup", true)
addEventHandler("rp_ui:showHousePopup", root, function(payload)
    showHousePopupLocal(payload)
end)

addEvent("rp_ui:hideHousePopup", true)
addEventHandler("rp_ui:hideHousePopup", root, function()
    hideHousePopup()
end)

addEvent("inventory:browserClose", true)
addEventHandler("inventory:browserClose", root, function()
    if uiState.inventoryVisible then setInventoryVisible(false) end
end)

-- legacy browser events (still wired but popup uses dxDraw now)
addEvent("housing:browserBuy",   true)
addEventHandler("housing:browserBuy",   root, function() triggerHouseAction("housing:requestBuy") end)
addEvent("housing:browserEnter", true)
addEventHandler("housing:browserEnter", root, function() triggerHouseAction("housing:requestEnter") end)
addEvent("housing:browserLock",  true)
addEventHandler("housing:browserLock",  root, function() triggerHouseAction("housing:requestToggleLock") end)
addEvent("vehicles:browserPark", true)
addEventHandler("vehicles:browserPark", root, function()
    if housePopup.visible and housePopup.payload then
        triggerServerEvent("vehicles:requestPark", localPlayer, housePopup.payload.id or false)
    end
end)

-- ╔══════════════════════════════════════════════════╗
-- ║  RENDER LOOP                                     ║
-- ╚══════════════════════════════════════════════════╝
addEventHandler("onClientRender", root, function()
    if popupExpired() then hideHousePopup() end
    drawHousePopup()
    drawGarageHints()
    drawUiBrowser()
end)

-- ╔══════════════════════════════════════════════════╗
-- ║  RESOURCE LIFECYCLE + KEY BINDS                  ║
-- ╚══════════════════════════════════════════════════╝
addEventHandler("onClientResourceStart", resourceRoot, function()
    createUiBrowser()

    -- Inventory toggle
    bindKey("i", "down", toggleInventory)

    -- House popup actions (only when popup is visible and not typing)
    local function guardedKey(fn)
        return function()
            if isChatBoxInputActive() or isConsoleActive() or isMainMenuActive() then return end
            fn()
        end
    end

    bindKey("f", "down", guardedKey(function()
        if housePopup.visible and housePopup.payload and housePopup.payload.canEnter then
            triggerHouseAction("housing:requestEnter")
        end
    end))

    bindKey("b", "down", guardedKey(function()
        if housePopup.visible and housePopup.payload and housePopup.payload.canBuy then
            triggerHouseAction("housing:requestBuy")
        end
    end))

    bindKey("g", "down", guardedKey(function()
        if housePopup.visible and housePopup.payload and housePopup.payload.canLock then
            triggerHouseAction("housing:requestToggleLock")
        end
    end))

    bindKey("p", "down", guardedKey(function()
        if housePopup.visible and housePopup.payload and housePopup.payload.canPark then
            triggerServerEvent("vehicles:requestPark", localPlayer, housePopup.payload.id or false)
        end
    end))

    bindKey("escape", "down", guardedKey(function()
        if housePopup.visible then
            hideHousePopup()
            return
        end
        if uiState.inventoryVisible then
            setInventoryVisible(false)
        end
    end))
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    showCursor(false)
    focusBrowser(nil)
    hideHousePopup()
end)
