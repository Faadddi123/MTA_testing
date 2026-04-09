-- house_manager/client.lua
-- Native MTA GUI admin panel. Open with /houseadmin or /ha.
-- NOTE: MTA CEGUI does NOT support emoji/unicode – all labels use plain ASCII.

local panel    = nil
local isOpen   = false
local propList = nil    -- gridlist
local presets  = {}     -- { key, label } list from server
local editRow  = -1     -- selected row index for Edit mode

-- ── forward declarations ────────────────────────────────────────
local lblStatus, lblAddSt
local edtEName, edtEPrice, btnESave, btnECancel
local lblEName, lblEPrice

-- ═══════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════
local function guiCenter(el)
    local sw, sh = guiGetScreenSize()
    local w, h   = guiGetSize(el, false)
    guiSetPosition(el, (sw - w) / 2, (sh - h) / 2, false)
end

local function fmtMoney(n)
    return "$" .. tostring(math.floor(tonumber(n) or 0))
end

local function showEditWidgets(show)
    guiSetVisible(lblEName,   show)
    guiSetVisible(edtEName,   show)
    guiSetVisible(lblEPrice,  show)
    guiSetVisible(edtEPrice,  show)
    guiSetVisible(btnESave,   show)
    guiSetVisible(btnECancel, show)
end

-- ═══════════════════════════════════════════════════════════════
-- BUILD GUI  (called once)
-- ═══════════════════════════════════════════════════════════════
local function buildPanel()
    if panel and isElement(panel) then return end

    local W, H = 800, 540

    panel = guiCreateWindow(0, 0, W, H, "House Manager - Property Admin", false)
    if not panel then
        outputChatBox("[HouseAdmin] ERROR: Could not create GUI window.", 255, 60, 60)
        return
    end
    guiCenter(panel)
    guiWindowSetSizable(panel, false)

    local tabs = guiCreateTabPanel(6, 24, W - 12, H - 32, false, panel)

    -- ╔══════════════════════════════════════════════════════╗
    -- TAB 1: Properties List
    -- ╚══════════════════════════════════════════════════════╝
    local tabList = guiCreateTab("Properties List", tabs)

    propList = guiCreateGridList(4, 4, W - 24, 360, false, tabList)
    guiGridListSetSelectionMode(propList, 0)

    -- columns (widths as fractions of gridlist width)
    local gw = W - 24
    guiGridListAddColumn(propList, "ID",    40  / gw)
    guiGridListAddColumn(propList, "Name",  200 / gw)
    guiGridListAddColumn(propList, "Type",  90  / gw)
    guiGridListAddColumn(propList, "Price", 90  / gw)
    guiGridListAddColumn(propList, "Owner", 160 / gw)
    guiGridListAddColumn(propList, "Lock",  55  / gw)

    -- action buttons
    local btnTeleport = guiCreateButton(  4, 372, 110, 26, "Go There",  false, tabList)
    local btnEdit     = guiCreateButton(120, 372, 110, 26, "Edit",      false, tabList)
    local btnDelete   = guiCreateButton(236, 372, 110, 26, "Delete",    false, tabList)
    local btnRefresh  = guiCreateButton(352, 372, 110, 26, "Refresh",   false, tabList)

    lblStatus = guiCreateLabel(4, 404, W - 30, 18, "", false, tabList)
    guiLabelSetColor(lblStatus, 100, 230, 100)

    -- inline edit widgets (hidden until Edit clicked)
    lblEName  = guiCreateLabel( 4, 428,  50, 20, "Name:",  false, tabList)
    edtEName  = guiCreateEdit( 58, 426, 210, 22, "",       false, tabList)
    lblEPrice = guiCreateLabel(276, 428,  45, 20, "Price:", false, tabList)
    edtEPrice = guiCreateEdit(324, 426, 120, 22, "",       false, tabList)
    btnESave  = guiCreateButton(452, 426,  90, 22, "Save",  false, tabList)
    btnECancel= guiCreateButton(548, 426,  90, 22, "Cancel",false, tabList)
    showEditWidgets(false)

    -- ╔══════════════════════════════════════════════════════╗
    -- TAB 2: Add Property
    -- ╚══════════════════════════════════════════════════════╝
    local tabAdd = guiCreateTab("Add Property", tabs)

    guiCreateLabel(10, 8, W - 30, 36,
        "Stand at the front door of the house, fill in the details below, then click Add.",
        false, tabAdd)

    guiCreateLabel(10, 52, 120, 22, "Property Name:", false, tabAdd)
    local edtName = guiCreateEdit(140, 50, 280, 24, "My House", false, tabAdd)

    guiCreateLabel(10, 84, 120, 22, "Category:", false, tabAdd)
    local cmbCat = guiCreateComboBox(140, 82, 240, 24, "Select type...", false, tabAdd)

    guiCreateLabel(10, 116, 120, 22, "Price ($):", false, tabAdd)
    local edtPrice = guiCreateEdit(140, 114, 160, 24, "50000", false, tabAdd)

    guiCreateLabel(10, 148, W - 30, 18,
        "Interior layout is chosen automatically from the category preset.",
        false, tabAdd)
    guiCreateLabel(10, 168, W - 30, 18,
        "Garage zone is placed 10m behind you. Dimension = 6000 + new house ID.",
        false, tabAdd)

    local btnAdd = guiCreateButton(140, 196, 210, 30, "Add Property at My Position", false, tabAdd)
    lblAddSt = guiCreateLabel(10, 234, W - 30, 18, "", false, tabAdd)
    guiLabelSetColor(lblAddSt, 100, 230, 100)

    -- ╔══════════════════════════════════════════════════════╗
    -- TAB 3: Help
    -- ╚══════════════════════════════════════════════════════╝
    local tabHelp = guiCreateTab("Help", tabs)
    guiCreateLabel(10, 8, W - 30, 460,
        "COMMANDS\n"..
        "  /houseadmin   or   /ha   - open this panel\n\n"..
        "CATEGORIES\n"..
        "  small      - compact 1-bed (Interior 4)\n"..
        "  medium     - standard 2-bed (Interior 1)\n"..
        "  large      - spacious 3-bed (Interior 2)\n"..
        "  mansion    - luxury (Interior 4)\n"..
        "  apartment  - high-rise (Interior 3)\n"..
        "  penthouse  - rooftop suite (Interior 5)\n"..
        "  warehouse  - industrial (Interior 18)\n\n"..
        "HOW TO ADD A PROPERTY\n"..
        "  1. Walk to the front door of the building in-game\n"..
        "  2. Open /ha, go to 'Add Property' tab\n"..
        "  3. Fill name, category, price\n"..
        "  4. Click 'Add Property at My Position'\n"..
        "  5. Housing restarts in ~1 second\n"..
        "  6. Yellow arrow appears at that door\n\n"..
        "KEY BINDS (at a property)\n"..
        "  [F] Enter / Exit     [B] Buy\n"..
        "  [G] Lock / Unlock    [ESC] Dismiss popup\n\n"..
        "SHARING\n"..
        "  /sharekey <player>    /revokekey <player>\n"..
        "  /myproperties",
        false, tabHelp)

    -- ═══════════════════════════════════════════════════════
    -- EVENTS: server -> client data
    -- ═══════════════════════════════════════════════════════

    addEvent("hm:receivePresets", true)
    addEventHandler("hm:receivePresets", root, function(cats)
        presets = cats
        guiComboBoxClear(cmbCat)
        for _, c in ipairs(cats) do
            guiComboBoxAddItem(cmbCat, c.label)
        end
        if #cats > 0 then guiComboBoxSetSelected(cmbCat, 0) end
    end)

    addEvent("hm:receiveList", true)
    addEventHandler("hm:receiveList", root, function(list)
        if not propList or not isElement(propList) then return end
        guiGridListClear(propList)
        for _, p in ipairs(list) do
            local row = guiGridListAddRow(propList)
            guiGridListSetItemText(propList, row, 1, tostring(p.id),  false, false)
            guiGridListSetItemText(propList, row, 2, p.name,          false, false)
            guiGridListSetItemText(propList, row, 3, p.ptype,         false, false)
            guiGridListSetItemText(propList, row, 4, fmtMoney(p.price), false, false)
            guiGridListSetItemText(propList, row, 5, (p.owner ~= "" and p.owner or "Available"), false, false)
            guiGridListSetItemText(propList, row, 6, p.locked and "[L]" or "[U]", false, false)
        end
        if lblStatus then guiSetText(lblStatus, "Loaded " .. #list .. " properties.") end
    end)

    -- ═══════════════════════════════════════════════════════
    -- BUTTON EVENTS
    -- ═══════════════════════════════════════════════════════

    addEventHandler("onClientGUIClick", btnRefresh, function()
        triggerServerEvent("hm:requestList", localPlayer)
        if lblStatus then guiSetText(lblStatus, "Refreshing...") end
    end, false)

    addEventHandler("onClientGUIClick", btnTeleport, function()
        local sel = guiGridListGetSelectedItem(propList)
        if sel < 0 then
            if lblStatus then guiSetText(lblStatus, "Select a property first.") end
            return
        end
        local id = tonumber(guiGridListGetItemText(propList, sel, 1))
        if id then triggerServerEvent("hm:requestTeleport", localPlayer, id) end
    end, false)

    addEventHandler("onClientGUIClick", btnEdit, function()
        local sel = guiGridListGetSelectedItem(propList)
        if sel < 0 then
            if lblStatus then guiSetText(lblStatus, "Select a property first.") end
            return
        end
        editRow = sel
        guiSetText(edtEName,  guiGridListGetItemText(propList, sel, 2))
        guiSetText(edtEPrice, guiGridListGetItemText(propList, sel, 4):gsub("%$", ""))
        showEditWidgets(true)
    end, false)

    addEventHandler("onClientGUIClick", btnESave, function()
        if editRow < 0 then return end
        local id    = tonumber(guiGridListGetItemText(propList, editRow, 1))
        local name  = guiGetText(edtEName)
        local price = tonumber(guiGetText(edtEPrice))
        if not id or not name or name == "" or not price then
            if lblStatus then guiSetText(lblStatus, "Invalid name or price.") end
            return
        end
        triggerServerEvent("hm:requestUpdate", localPlayer, id, name, price)
        showEditWidgets(false)
        editRow = -1
        if lblStatus then guiSetText(lblStatus, "Updated #" .. id) end
    end, false)

    addEventHandler("onClientGUIClick", btnECancel, function()
        showEditWidgets(false)
        editRow = -1
    end, false)

    -- Delete with double-click confirm
    local confirmDeleteId = nil
    local confirmTimer    = nil
    addEventHandler("onClientGUIClick", btnDelete, function()
        local sel = guiGridListGetSelectedItem(propList)
        if sel < 0 then
            if lblStatus then guiSetText(lblStatus, "Select a property first.") end
            return
        end
        local id   = tonumber(guiGridListGetItemText(propList, sel, 1))
        local name = guiGridListGetItemText(propList, sel, 2)
        if not id then return end

        if confirmDeleteId ~= id then
            confirmDeleteId = id
            if confirmTimer and isTimer(confirmTimer) then killTimer(confirmTimer) end
            confirmTimer = setTimer(function() confirmDeleteId = nil end, 4000, 1)
            if lblStatus then guiSetText(lblStatus, "Click Delete again to confirm: " .. name) end
        else
            confirmDeleteId = nil
            if confirmTimer and isTimer(confirmTimer) then killTimer(confirmTimer) end
            triggerServerEvent("hm:requestDelete", localPlayer, id)
            if lblStatus then guiSetText(lblStatus, "Deleting #" .. id .. "...") end
        end
    end, false)

    addEventHandler("onClientGUIClick", btnAdd, function()
        local name   = guiGetText(edtName)
        local price  = tonumber(guiGetText(edtPrice))
        local catIdx = guiComboBoxGetSelected(cmbCat)
        if name == "" or not price or catIdx < 0 then
            if lblAddSt then guiSetText(lblAddSt, "Fill in all fields first.") end
            return
        end
        local category = (presets[catIdx + 1] and presets[catIdx + 1].key) or "small"
        triggerServerEvent("hm:requestCreate", localPlayer, {
            name     = name,
            price    = price,
            category = category,
        })
        if lblAddSt then guiSetText(lblAddSt, "Done! Housing is restarting...") end
    end, false)

    addEventHandler("onClientGUIClose", panel, function()
        isOpen = false
        showCursor(false)
    end, false)

    outputChatBox("[HouseAdmin] Panel built OK.", 100, 230, 100)
end

-- ═══════════════════════════════════════════════════════════════
-- OPEN / CLOSE
-- ═══════════════════════════════════════════════════════════════
addEvent("hm:openPanel", true)
addEventHandler("hm:openPanel", root, function()
    outputChatBox("[HouseAdmin] Opening panel...", 100, 200, 255)
    buildPanel()
    if not panel or not isElement(panel) then
        outputChatBox("[HouseAdmin] ERROR: Panel is nil after build.", 255, 60, 60)
        return
    end
    guiSetVisible(panel, true)
    guiBringToFront(panel)
    showCursor(true)
    isOpen = true
    triggerServerEvent("hm:requestPresets", localPlayer)
    triggerServerEvent("hm:requestList",    localPlayer)
end)

addEventHandler("onClientKey", root, function(key, press)
    if press and key == "escape" and isOpen then
        isOpen = false
        showCursor(false)
        if panel and isElement(panel) then
            guiSetVisible(panel, false)
        end
    end
end)
