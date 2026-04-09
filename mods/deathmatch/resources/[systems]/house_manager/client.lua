-- house_manager/client.lua
-- Rewrite: adds Preview button, instant delete row removal, cleaner layout.

local panel    = nil
local isOpen   = false
local propList = nil
local presets  = {}
local editRow  = -1
local isPreviewing = false

-- Forward declarations
local lblStatus, lblAddSt
local edtEName, edtEPrice, btnESave, btnECancel
local lblEName, lblEPrice
local btnExitPreview  -- visible only during preview

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

local function setStatus(msg, r, g, b)
    if lblStatus and isElement(lblStatus) then
        guiSetText(lblStatus, msg)
        if r then guiLabelSetColor(lblStatus, r, g, b) end
    end
end

local function setAddStatus(msg, r, g, b)
    if lblAddSt and isElement(lblAddSt) then
        guiSetText(lblAddSt, msg)
        if r then guiLabelSetColor(lblAddSt, r, g, b) end
    end
end

-- Remove a specific row from the grid by house ID
local function removeRowById(id)
    if not propList or not isElement(propList) then return end
    local count = guiGridListGetRowCount(propList)
    for i = 0, count - 1 do
        local rowId = tonumber(guiGridListGetItemText(propList, i, 1))
        if rowId == id then
            guiGridListRemoveRow(propList, i)
            return
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- SERVER EVENTS (registered early, outside buildPanel)
-- ═══════════════════════════════════════════════════════════════

-- Delete result: remove the row immediately without waiting for housing reload
addEvent("hm:deleteResult", true)
addEventHandler("hm:deleteResult", root, function(success, houseId)
    if success then
        removeRowById(tonumber(houseId))
        setStatus("Deleted #" .. tostring(houseId) .. ".", 255, 160, 60)
    else
        setStatus("Delete failed: property not found.", 255, 80, 80)
    end
    editRow = -1
    showEditWidgets(false)
end)

-- ═══════════════════════════════════════════════════════════════
-- BUILD GUI
-- ═══════════════════════════════════════════════════════════════
local function buildPanel()
    if panel and isElement(panel) then return end

    local W, H = 820, 560
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
    local tabList = guiCreateTab("Properties", tabs)
    local gw = W - 24

    propList = guiCreateGridList(4, 4, gw, 340, false, tabList)
    guiGridListSetSelectionMode(propList, 0)
    guiGridListAddColumn(propList, "ID",       45  / gw)
    guiGridListAddColumn(propList, "Name",     210 / gw)
    guiGridListAddColumn(propList, "Type",     90  / gw)
    guiGridListAddColumn(propList, "Price",    90  / gw)
    guiGridListAddColumn(propList, "Owner",    170 / gw)
    guiGridListAddColumn(propList, "Lock",     55  / gw)

    -- Row 1 of buttons
    local btnTeleport = guiCreateButton(  4, 350, 115, 26, "Go to Exterior",  false, tabList)
    local btnEdit     = guiCreateButton(124, 350, 90,  26, "Edit",             false, tabList)
    local btnDelete   = guiCreateButton(220, 350, 90,  26, "Delete",           false, tabList)
    local btnRefresh  = guiCreateButton(316, 350, 90,  26, "Refresh",          false, tabList)

    lblStatus = guiCreateLabel(4, 382, gw - 8, 18, "", false, tabList)
    guiLabelSetColor(lblStatus, 180, 180, 180)

    -- Inline edit row (hidden)
    lblEName  = guiCreateLabel( 4, 406,  50, 20, "Name:",  false, tabList)
    edtEName  = guiCreateEdit( 58, 404, 220, 22, "",       false, tabList)
    lblEPrice = guiCreateLabel(286, 406,  46, 20, "Price:", false, tabList)
    edtEPrice = guiCreateEdit(336, 404, 120, 22, "",       false, tabList)
    btnESave  = guiCreateButton(464, 404,  85, 22, "Save",  false, tabList)
    btnECancel= guiCreateButton(556, 404,  85, 22, "Cancel",false, tabList)
    showEditWidgets(false)

    -- ╔══════════════════════════════════════════════════════╗
    -- TAB 2: Add Property
    -- ╚══════════════════════════════════════════════════════╝
    local tabAdd = guiCreateTab("Add Property", tabs)

    guiCreateLabel(8, 6, gw - 16, 18,
        "Stand at the FRONT DOOR of the building, fill in the details, then click Add.",
        false, tabAdd)
    guiCreateLabel(8, 22, gw - 16, 18,
        "Use Preview to check how each interior looks before creating.",
        false, tabAdd)

    guiCreateLabel(8, 50, 130, 22, "Property Name:", false, tabAdd)
    local edtName = guiCreateEdit(142, 48, 260, 24, "My Property", false, tabAdd)

    guiCreateLabel(8, 82, 130, 22, "Interior Type:", false, tabAdd)
    local cmbCat = guiCreateComboBox(142, 80, 260, 24, "Select type...", false, tabAdd)

    guiCreateLabel(8, 114, 130, 22, "Price ($):", false, tabAdd)
    local edtPrice = guiCreateEdit(142, 112, 160, 24, "50000", false, tabAdd)

    -- Preview button
    local btnPreview = guiCreateButton(142, 146, 160, 26, "Preview Selected Interior", false, tabAdd)
    btnExitPreview   = guiCreateButton(310, 146, 130, 26, "Exit Preview",              false, tabAdd)
    guiSetVisible(btnExitPreview, false)

    local btnAdd = guiCreateButton(142, 184, 260, 30, "Add Property at My Position", false, tabAdd)

    lblAddSt = guiCreateLabel(8, 222, gw - 16, 18, "", false, tabAdd)
    guiLabelSetColor(lblAddSt, 100, 230, 100)

    guiCreateLabel(8, 248, gw - 16, 360,
        "SIZE GUIDE\n"..
        "  Studio Flat       - 1 room, tiny (Interior 5)\n"..
        "  Small Apartment   - compact 1-bed (Interior 1)\n"..
        "  2-Room Apartment  - standard (Interior 9)\n"..
        "  3-Room Apartment  - spacious (Interior 12)\n"..
        "  Penthouse         - luxury high-rise (Interior 8)\n"..
        "  Villa             - house interior (Interior 7)\n"..
        "  Mansion           - biggest available (Interior 5, zone 1)\n"..
        "  Small Garage      - 1-2 cars (Interior 4)\n"..
        "  Large Garage      - 4+ cars (Interior 15)\n"..
        "  Warehouse         - open plan (Interior 5, zone 2)\n\n"..
        "NOTE: Each house gets its own DIMENSION (6000 + house ID)\n"..
        "so players are always isolated in their own space.",
        false, tabAdd)

    -- ╔══════════════════════════════════════════════════════╗
    -- TAB 3: Help
    -- ╚══════════════════════════════════════════════════════╝
    local tabHelp = guiCreateTab("Help", tabs)
    guiCreateLabel(8, 6, gw - 16, 500,
        "COMMANDS\n"..
        "  /houseadmin  or  /ha          Open this panel\n"..
        "  /exitpreview                  Exit interior preview\n\n"..
        "PLAYER COMMANDS (in housing resource)\n"..
        "  F key      Enter / Exit property\n"..
        "  B key      Buy property\n"..
        "  G key      Lock / Unlock\n"..
        "  /sharekey <player>   Give house key\n"..
        "  /revokekey <player>  Remove house key\n"..
        "  /myproperties        List your owned properties\n\n"..
        "HOW TO ADD A PROPERTY\n"..
        "  1. Walk to the front door of a building in-game\n"..
        "  2. Open /ha -> 'Add Property' tab\n"..
        "  3. Choose the interior type (use Preview to check it first)\n"..
        "  4. Set name and price\n"..
        "  5. Click 'Add Property at My Position'\n"..
        "  6. Housing reloads (~1 second), blip appears at door\n\n"..
        "HOW TO DELETE\n"..
        "  1. Select a property in the list\n"..
        "  2. Click Delete\n"..
        "  3. Click Delete again to confirm (4 second window)\n"..
        "  -> Row disappears immediately from the list\n\n"..
        "DIMENSION SYSTEM\n"..
        "  Each property has dimension = 6000 + house_id\n"..
        "  Players are isolated - they never see each other inside\n"..
        "  Preview uses dimension 99998 (safe, isolated)",
        false, tabHelp)

    -- ═══════════════════════════════════════════════════════
    -- SERVER -> CLIENT EVENTS
    -- ═══════════════════════════════════════════════════════

    addEvent("hm:receivePresets", true)
    addEventHandler("hm:receivePresets", root, function(cats)
        presets = cats
        guiComboBoxClear(cmbCat)
        for _, c in ipairs(cats) do
            guiComboBoxAddItem(cmbCat, c.label .. " [" .. (c.size or "?") .. "]")
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
            guiGridListSetItemText(propList, row, 5, (p.owner ~= "" and p.owner or "-- Available --"), false, false)
            guiGridListSetItemText(propList, row, 6, p.locked and "[L]" or "[U]", false, false)
        end
        setStatus("Loaded " .. #list .. " properties.", 100, 230, 100)
    end)

    -- ═══════════════════════════════════════════════════════
    -- BUTTON EVENTS
    -- ═══════════════════════════════════════════════════════

    addEventHandler("onClientGUIClick", btnRefresh, function()
        triggerServerEvent("hm:requestList", localPlayer)
        setStatus("Refreshing...", 200, 200, 100)
    end, false)

    addEventHandler("onClientGUIClick", btnTeleport, function()
        local sel = guiGridListGetSelectedItem(propList)
        if sel < 0 then setStatus("Select a property first.", 255, 160, 60) return end
        local id = tonumber(guiGridListGetItemText(propList, sel, 1))
        if id then triggerServerEvent("hm:requestTeleport", localPlayer, id) end
    end, false)

    addEventHandler("onClientGUIClick", btnEdit, function()
        local sel = guiGridListGetSelectedItem(propList)
        if sel < 0 then setStatus("Select a property first.", 255, 160, 60) return end
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
            setStatus("Invalid name or price.", 255, 80, 80)
            return
        end
        triggerServerEvent("hm:requestUpdate", localPlayer, id, name, price)
        showEditWidgets(false)
        editRow = -1
        setStatus("Sending update for #" .. id .. "...", 200, 200, 100)
    end, false)

    addEventHandler("onClientGUIClick", btnECancel, function()
        showEditWidgets(false)
        editRow = -1
    end, false)

    -- Delete: double-click confirm
    local confirmDeleteId = nil
    local confirmTimer    = nil
    addEventHandler("onClientGUIClick", btnDelete, function()
        local sel = guiGridListGetSelectedItem(propList)
        if sel < 0 then setStatus("Select a property first.", 255, 160, 60) return end
        local id   = tonumber(guiGridListGetItemText(propList, sel, 1))
        local name = guiGridListGetItemText(propList, sel, 2)
        if not id then return end

        if confirmDeleteId ~= id then
            confirmDeleteId = id
            if confirmTimer and isTimer(confirmTimer) then killTimer(confirmTimer) end
            confirmTimer = setTimer(function()
                confirmDeleteId = nil
                setStatus("", 180, 180, 180)
            end, 4000, 1)
            setStatus("Click Delete again to confirm: '" .. name .. "'", 255, 200, 50)
        else
            confirmDeleteId = nil
            if confirmTimer and isTimer(confirmTimer) then killTimer(confirmTimer) end
            triggerServerEvent("hm:requestDelete", localPlayer, id)
            setStatus("Deleting #" .. id .. "...", 255, 160, 60)
        end
    end, false)

    -- Preview
    addEventHandler("onClientGUIClick", btnPreview, function()
        local catIdx = guiComboBoxGetSelected(cmbCat)
        if catIdx < 0 then
            setAddStatus("Select an interior type first.", 255, 160, 60)
            return
        end
        local cat = (presets[catIdx + 1] and presets[catIdx + 1].key) or nil
        if not cat then return end

        isPreviewing = true
        guiSetVisible(btnExitPreview, true)
        triggerServerEvent("hm:requestPreview", localPlayer, cat)
        setAddStatus("Previewing... click 'Exit Preview' or type /exitpreview to return.", 100, 200, 255)
    end, false)

    addEventHandler("onClientGUIClick", btnExitPreview, function()
        isPreviewing = false
        guiSetVisible(btnExitPreview, false)
        triggerServerEvent("hm:exitPreview", localPlayer)
        setAddStatus("Returned from preview.", 120, 255, 120)
    end, false)

    -- Add property
    addEventHandler("onClientGUIClick", btnAdd, function()
        if isPreviewing then
            setAddStatus("Exit preview first before creating.", 255, 160, 60)
            return
        end
        local name   = guiGetText(edtName)
        local price  = tonumber(guiGetText(edtPrice))
        local catIdx = guiComboBoxGetSelected(cmbCat)
        if name == "" or not price or catIdx < 0 then
            setAddStatus("Fill in all fields first.", 255, 80, 80)
            return
        end
        local category = (presets[catIdx + 1] and presets[catIdx + 1].key) or "studio"
        triggerServerEvent("hm:requestCreate", localPlayer, {
            name     = name,
            price    = price,
            category = category,
        })
        setAddStatus("Property created! Housing is reloading (~1s)...", 100, 255, 100)
    end, false)

    addEventHandler("onClientGUIClose", panel, function()
        isOpen = false
        showCursor(false)
    end, false)
end

-- ═══════════════════════════════════════════════════════════════
-- OPEN / CLOSE
-- ═══════════════════════════════════════════════════════════════
addEvent("hm:openPanel", true)
addEventHandler("hm:openPanel", root, function()
    buildPanel()
    if not panel or not isElement(panel) then
        outputChatBox("[HouseAdmin] ERROR: Panel failed to build.", 255, 60, 60)
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
