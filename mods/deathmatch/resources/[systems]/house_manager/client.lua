-- house_manager/client.lua
-- Admin UI for separate house and garage management.

local panel = nil
local isOpen = false
local isPreviewing = false
local isNoclipping = false
local noclipTimer = nil
local customSpawnOverride = nil
local selectedPropertyId = nil

local propertyRows = {}
local catalog = {
    houses = {},
    garages = {},
}

local comboValues = {}
local ui = {
    propertyList = nil,
    listStatus = nil,
    editName = nil,
    editPrice = nil,
    linkCombo = nil,
    add = {
        house = {},
        garage = {},
    },
}

local function guiCenter(element)
    local sw, sh = guiGetScreenSize()
    local w, h = guiGetSize(element, false)
    guiSetPosition(element, (sw - w) / 2, (sh - h) / 2, false)
end

local function fmtMoney(amount)
    return "$" .. tostring(math.floor(tonumber(amount) or 0))
end

local function setListStatus(message, r, g, b)
    if ui.listStatus and isElement(ui.listStatus) then
        guiSetText(ui.listStatus, message or "")
        if r then
            guiLabelSetColor(ui.listStatus, r, g, b)
        end
    end
end

local function setAddStatus(kind, message, r, g, b)
    local label = ui.add[kind] and ui.add[kind].status or nil
    if label and isElement(label) then
        guiSetText(label, message or "")
        if r then
            guiLabelSetColor(label, r, g, b)
        end
    end
end

local function stopNoclip()
    if noclipTimer and isTimer(noclipTimer) then
        killTimer(noclipTimer)
        noclipTimer = nil
    end
    if isNoclipping then
        isNoclipping = false
        local x, y, z = getElementPosition(localPlayer)
        setElementVelocity(localPlayer, 0, 0, 0)
        setElementPosition(localPlayer, x, y, z)
    end
end

local function closePanel()
    isOpen = false
    showCursor(false)
    stopNoclip()
    if panel and isElement(panel) then
        guiSetVisible(panel, false)
    end
end

local function setComboEntries(combo, entries, noneLabel)
    guiComboBoxClear(combo)
    comboValues[combo] = {}

    if noneLabel then
        guiComboBoxAddItem(combo, noneLabel)
        comboValues[combo][1] = false
    end

    for _, entry in ipairs(entries) do
        guiComboBoxAddItem(combo, entry.label)
        comboValues[combo][#comboValues[combo] + 1] = entry.value
    end

    if #(comboValues[combo] or {}) > 0 then
        guiComboBoxSetSelected(combo, 0)
    end
end

local function getComboValue(combo)
    local selected = guiComboBoxGetSelected(combo)
    if selected < 0 then
        return nil
    end
    local values = comboValues[combo] or {}
    return values[selected + 1]
end

local function selectComboValue(combo, value)
    local values = comboValues[combo] or {}
    for index, comboValue in ipairs(values) do
        if comboValue == value then
            guiComboBoxSetSelected(combo, index - 1)
            return true
        end
    end
    return false
end

local function findPropertyById(propertyId)
    propertyId = tonumber(propertyId)
    if not propertyId then
        return nil
    end

    for _, row in ipairs(propertyRows) do
        if tonumber(row.id) == propertyId then
            return row
        end
    end

    return nil
end

local function getSelectedProperty()
    return findPropertyById(selectedPropertyId)
end

local function buildPropertyLinkChoices(selectedRow)
    local entries = {}
    if not selectedRow then
        return entries
    end

    local selectedIsGarage = selectedRow.ptype == "garage"
    for _, row in ipairs(propertyRows) do
        if row.id ~= selectedRow.id then
            local rowIsGarage = row.ptype == "garage"
            if selectedIsGarage ~= rowIsGarage then
                entries[#entries + 1] = {
                    label = "#" .. tostring(row.id) .. " - " .. tostring(row.name) .. " [" .. tostring(row.ptype) .. "]",
                    value = tonumber(row.id),
                }
            end
        end
    end

    return entries
end

local function buildCreationLinkChoices(targetKind)
    local wantGarage = targetKind == "garage"
    local entries = {}

    for _, row in ipairs(propertyRows) do
        local isGarage = row.ptype == "garage"
        if wantGarage == isGarage then
            entries[#entries + 1] = {
                label = "#" .. tostring(row.id) .. " - " .. tostring(row.name) .. " [" .. tostring(row.ptype) .. "]",
                value = tonumber(row.id),
            }
        end
    end

    return entries
end

local function refreshSelectionDetails()
    local row = getSelectedProperty()
    if not row then
        if ui.editName and isElement(ui.editName) then guiSetText(ui.editName, "") end
        if ui.editPrice and isElement(ui.editPrice) then guiSetText(ui.editPrice, "") end
        if ui.linkCombo and isElement(ui.linkCombo) then
            setComboEntries(ui.linkCombo, {}, "No link")
        end
        return
    end

    guiSetText(ui.editName, row.name or "")
    guiSetText(ui.editPrice, tostring(math.floor(tonumber(row.price) or 0)))

    setComboEntries(ui.linkCombo, buildPropertyLinkChoices(row), "No link")
    if row.linked_id then
        selectComboValue(ui.linkCombo, tonumber(row.linked_id))
    end
end

local function refreshCreateLinkCombos()
    if ui.add.house.linkCombo and isElement(ui.add.house.linkCombo) then
        setComboEntries(ui.add.house.linkCombo, buildCreationLinkChoices("garage"), "No linked garage")
    end
    if ui.add.garage.linkCombo and isElement(ui.add.garage.linkCombo) then
        setComboEntries(ui.add.garage.linkCombo, buildCreationLinkChoices("house"), "No linked house")
    end
end

local function refreshPropertyGrid()
    if not ui.propertyList or not isElement(ui.propertyList) then
        return
    end

    guiGridListClear(ui.propertyList)
    local selectedRowIndex = nil

    for _, row in ipairs(propertyRows) do
        local gridRow = guiGridListAddRow(ui.propertyList)
        local linkedLabel = row.linked_id and ("#" .. tostring(row.linked_id) .. " " .. tostring(row.linked_name or "")) or "--"

        guiGridListSetItemText(ui.propertyList, gridRow, 1, tostring(row.id), false, false)
        guiGridListSetItemText(ui.propertyList, gridRow, 2, tostring(row.name), false, false)
        guiGridListSetItemText(ui.propertyList, gridRow, 3, tostring(row.ptype), false, false)
        guiGridListSetItemText(ui.propertyList, gridRow, 4, fmtMoney(row.price), false, false)
        guiGridListSetItemText(ui.propertyList, gridRow, 5, (row.owner ~= "" and row.owner or "-- Available --"), false, false)
        guiGridListSetItemText(ui.propertyList, gridRow, 6, row.locked and "[L]" or "[U]", false, false)
        guiGridListSetItemText(ui.propertyList, gridRow, 7, linkedLabel, false, false)

        if tonumber(row.id) == tonumber(selectedPropertyId) then
            selectedRowIndex = gridRow
        end
    end

    if selectedRowIndex then
        guiGridListSetSelectedItem(ui.propertyList, selectedRowIndex, 1)
    else
        selectedPropertyId = nil
    end

    refreshSelectionDetails()
    refreshCreateLinkCombos()
    setListStatus("Loaded " .. tostring(#propertyRows) .. " properties.", 120, 255, 120)
end

local function buildAddTab(tabPanel, kind, title, buttonLabel, linkLabel)
    local tab = guiCreateTab(title, tabPanel)
    local categoryCombo = guiCreateComboBox(160, 80, 280, 180, "Select type...", false, tab)
    local linkCombo = guiCreateComboBox(160, 146, 280, 180, linkLabel, false, tab)
    local previewButton = guiCreateButton(160, 182, 170, 28, "Preview Interior", false, tab)
    local exitPreviewButton = guiCreateButton(340, 182, 100, 28, "Exit Preview", false, tab)
    local addButton = guiCreateButton(160, 220, 280, 30, buttonLabel, false, tab)
    local status = guiCreateLabel(12, 260, 860, 18, "", false, tab)

    guiCreateLabel(12, 12, 860, 18,
        kind == "garage"
            and "Create garages separately, then link them to houses when needed."
            or "Create houses/apartments without automatic garage generation.",
        false, tab)
    guiCreateLabel(12, 50, 140, 22, "Property Name:", false, tab)
    local nameEdit = guiCreateEdit(160, 48, 280, 24, kind == "garage" and "My Garage" or "My Property", false, tab)

    guiCreateLabel(12, 82, 140, 22, "Interior Type:", false, tab)
    guiCreateLabel(12, 114, 140, 22, "Price ($):", false, tab)
    local priceEdit = guiCreateEdit(160, 112, 180, 24, kind == "garage" and "35000" or "50000", false, tab)
    guiCreateLabel(12, 148, 140, 22, linkLabel .. ":", false, tab)
    guiLabelSetColor(status, 120, 255, 120)
    guiSetVisible(exitPreviewButton, false)

    ui.add[kind] = {
        tab = tab,
        nameEdit = nameEdit,
        categoryCombo = categoryCombo,
        priceEdit = priceEdit,
        linkCombo = linkCombo,
        previewButton = previewButton,
        exitPreviewButton = exitPreviewButton,
        addButton = addButton,
        status = status,
    }
end

local function buildPanel()
    if panel and isElement(panel) then
        return
    end

    local W, H = 980, 640
    panel = guiCreateWindow(0, 0, W, H, "House Manager - Property and Garage Admin", false)
    if not panel then
        outputChatBox("[HouseAdmin] ERROR: Could not create GUI window.", 255, 60, 60)
        return
    end

    guiCenter(panel)
    guiWindowSetSizable(panel, false)
    guiWindowSetMovable(panel, true)

    local tabs = guiCreateTabPanel(8, 24, W - 16, H - 68, false, panel)
    local btnClose = guiCreateButton(W - 100, H - 34, 84, 24, "Close", false, panel)

    guiCreateLabel(12, H - 32, 60, 22, "Amount:", false, panel)
    local editMoney = guiCreateEdit(68, H - 34, 80, 24, "50000", false, panel)
    local btnGiveMoney = guiCreateButton(156, H - 34, 100, 24, "Give Money", false, panel)
    local btnNoclip = guiCreateButton(266, H - 34, 100, 24, "Noclip", false, panel)
    local btnSetSpawn = guiCreateButton(376, H - 34, 130, 24, "Set Spawn Here", false, panel)
    guiSetEnabled(btnSetSpawn, false)

    addEventHandler("onClientGUIClick", btnGiveMoney, function()
        local amt = tonumber(guiGetText(editMoney))
        if amt and amt > 0 then
            triggerServerEvent("hm:giveMoney", localPlayer, amt)
        end
    end, false)

    addEventHandler("onClientGUIClick", btnNoclip, function()
        if not isPreviewing then
            outputChatBox("[HouseAdmin] Enter preview mode first.", 255, 160, 60)
            return
        end
        isNoclipping = not isNoclipping
        if isNoclipping then
            guiSetText(btnNoclip, "Stop Noclip")
            guiSetEnabled(btnSetSpawn, true)
            outputChatBox("[HouseAdmin] Noclip ON. Use WASD + Space/Shift to fly. Click 'Set Spawn Here' when ready.", 100, 255, 100)
            local speed = 0.5
            noclipTimer = setTimer(function()
                if not isNoclipping then return end
                local camX, camY, camZ, lookX, lookY, lookZ = getCameraMatrix()
                local dirX = lookX - camX
                local dirY = lookY - camY
                local dirZ = lookZ - camZ
                local len = math.sqrt(dirX*dirX + dirY*dirY + dirZ*dirZ)
                if len > 0 then dirX, dirY, dirZ = dirX/len, dirY/len, dirZ/len end

                local rightX = dirY
                local rightY = -dirX

                local moveX, moveY, moveZ = 0, 0, 0
                if getKeyState("w") then moveX = moveX + dirX * speed; moveY = moveY + dirY * speed; moveZ = moveZ + dirZ * speed end
                if getKeyState("s") then moveX = moveX - dirX * speed; moveY = moveY - dirY * speed; moveZ = moveZ - dirZ * speed end
                if getKeyState("a") then moveX = moveX - rightX * speed; moveY = moveY - rightY * speed end
                if getKeyState("d") then moveX = moveX + rightX * speed; moveY = moveY + rightY * speed end
                if getKeyState("space") then moveZ = moveZ + speed end
                if getKeyState("lshift") then moveZ = moveZ - speed end

                local px, py, pz = getElementPosition(localPlayer)
                setElementPosition(localPlayer, px + moveX, py + moveY, pz + moveZ)
                setElementVelocity(localPlayer, 0, 0, 0)
            end, 50, 0)
        else
            guiSetText(btnNoclip, "Noclip")
            stopNoclip()
            outputChatBox("[HouseAdmin] Noclip OFF.", 255, 180, 80)
        end
    end, false)

    addEventHandler("onClientGUIClick", btnSetSpawn, function()
        if not isPreviewing then
            outputChatBox("[HouseAdmin] You must be in preview mode.", 255, 80, 80)
            return
        end
        local px, py, pz = getElementPosition(localPlayer)
        customSpawnOverride = { x = px, y = py, z = pz }
        outputChatBox(string.format(
            "[HouseAdmin] Spawn point set to (%.2f, %.2f, %.2f). Create the property to use this position.",
            px, py, pz
        ), 100, 255, 100)
    end, false)

    local tabList = guiCreateTab("Properties", tabs)
    ui.propertyList = guiCreateGridList(8, 8, W - 40, 320, false, tabList)
    guiGridListSetSelectionMode(ui.propertyList, 0)
    guiGridListAddColumn(ui.propertyList, "ID", 45 / (W - 40))
    guiGridListAddColumn(ui.propertyList, "Name", 240 / (W - 40))
    guiGridListAddColumn(ui.propertyList, "Type", 90 / (W - 40))
    guiGridListAddColumn(ui.propertyList, "Price", 90 / (W - 40))
    guiGridListAddColumn(ui.propertyList, "Owner", 180 / (W - 40))
    guiGridListAddColumn(ui.propertyList, "Lock", 50 / (W - 40))
    guiGridListAddColumn(ui.propertyList, "Linked", 180 / (W - 40))

    local btnTeleport = guiCreateButton(8, 338, 100, 28, "Go Ext.", false, tabList)
    local btnTeleInt = guiCreateButton(116, 338, 100, 28, "Go Int.", false, tabList)
    local btnRefresh = guiCreateButton(224, 338, 100, 28, "Refresh", false, tabList)
    local btnDelete = guiCreateButton(332, 338, 100, 28, "Delete", false, tabList)

    guiCreateLabel(8, 382, 70, 22, "Name:", false, tabList)
    ui.editName = guiCreateEdit(84, 380, 240, 24, "", false, tabList)
    guiCreateLabel(340, 382, 70, 22, "Price:", false, tabList)
    ui.editPrice = guiCreateEdit(392, 380, 120, 24, "", false, tabList)
    local btnSave = guiCreateButton(526, 380, 100, 24, "Save Edit", false, tabList)

    guiCreateLabel(8, 416, 110, 22, "Link To:", false, tabList)
    ui.linkCombo = guiCreateComboBox(84, 414, 340, 180, "No link", false, tabList)
    local btnApplyLink = guiCreateButton(434, 414, 92, 24, "Apply Link", false, tabList)
    local btnClearLink = guiCreateButton(534, 414, 92, 24, "Clear Link", false, tabList)

    ui.listStatus = guiCreateLabel(8, 454, W - 40, 22, "", false, tabList)
    guiLabelSetColor(ui.listStatus, 180, 180, 180)

    buildAddTab(tabs, "house", "Add House", "Create House at My Position", "Link To Garage")
    buildAddTab(tabs, "garage", "Add Garage", "Create Garage at My Position", "Link To House")

    -- ─── Interiors Manager Tab ───────────────────────────────────
    local tabInteriors = guiCreateTab("Interiors", tabs)

    guiCreateLabel(8, 8, W - 40, 20,
        "Manage custom interiors. Disable unused ones or stop conflicting original resources.",
        false, tabInteriors)

    ui.interiorGrid = guiCreateGridList(8, 32, W - 40, 360, false, tabInteriors)
    guiGridListSetSelectionMode(ui.interiorGrid, 0)
    guiGridListAddColumn(ui.interiorGrid, "Name", 0.30)
    guiGridListAddColumn(ui.interiorGrid, "Type", 0.08)
    guiGridListAddColumn(ui.interiorGrid, "Size", 0.07)
    guiGridListAddColumn(ui.interiorGrid, "Source", 0.10)
    guiGridListAddColumn(ui.interiorGrid, "Status", 0.10)
    guiGridListAddColumn(ui.interiorGrid, "Orig. Res.", 0.15)
    guiGridListAddColumn(ui.interiorGrid, "Conflict", 0.10)

    local btnToggle = guiCreateButton(8, 400, 160, 30, "Toggle Enable/Disable", false, tabInteriors)
    local btnStopOrig = guiCreateButton(180, 400, 180, 30, "Stop Original Resource", false, tabInteriors)
    local btnStopAll = guiCreateButton(372, 400, 200, 30, "Stop ALL Original Resources", false, tabInteriors)
    local btnRefreshInt = guiCreateButton(584, 400, 100, 30, "Refresh", false, tabInteriors)
    ui.interiorStatus = guiCreateLabel(8, 440, W - 40, 20, "", false, tabInteriors)
    guiLabelSetColor(ui.interiorStatus, 180, 180, 180)

    guiCreateLabel(8, 465, W - 40, 40,
        "TIP: If an interior looks corrupted, its original resource in [maps] may be running and creating duplicate objects.\n" ..
        "Use 'Stop Original Resource' to fix it, or 'Stop ALL' to clear all conflicts at once.",
        false, tabInteriors)

    addEventHandler("onClientGUIClick", btnToggle, function()
        local row = guiGridListGetSelectedItem(ui.interiorGrid)
        if row < 0 then
            guiSetText(ui.interiorStatus, "Select an interior first.")
            guiLabelSetColor(ui.interiorStatus, 255, 160, 60)
            return
        end
        local key = guiGridListGetItemData(ui.interiorGrid, row, 1)
        if key then
            triggerServerEvent("hm:toggleInterior", localPlayer, key)
        end
    end, false)

    addEventHandler("onClientGUIClick", btnStopOrig, function()
        local row = guiGridListGetSelectedItem(ui.interiorGrid)
        if row < 0 then
            guiSetText(ui.interiorStatus, "Select a custom interior first.")
            guiLabelSetColor(ui.interiorStatus, 255, 160, 60)
            return
        end
        local resName = guiGridListGetItemText(ui.interiorGrid, row, 6)
        if resName and resName ~= "" and resName ~= "--" then
            triggerServerEvent("hm:stopOriginalResource", localPlayer, resName)
            guiSetText(ui.interiorStatus, "Stopping " .. resName .. "...")
            guiLabelSetColor(ui.interiorStatus, 255, 200, 50)
        else
            guiSetText(ui.interiorStatus, "Selected interior is native (no original resource to stop).")
            guiLabelSetColor(ui.interiorStatus, 200, 200, 200)
        end
    end, false)

    addEventHandler("onClientGUIClick", btnStopAll, function()
        triggerServerEvent("hm:stopAllOriginals", localPlayer)
        guiSetText(ui.interiorStatus, "Stopping all original resources...")
        guiLabelSetColor(ui.interiorStatus, 255, 200, 50)
    end, false)

    addEventHandler("onClientGUIClick", btnRefreshInt, function()
        triggerServerEvent("hm:requestInteriorList", localPlayer)
        guiSetText(ui.interiorStatus, "Refreshing...")
        guiLabelSetColor(ui.interiorStatus, 200, 200, 100)
    end, false)

    local tabHelp = guiCreateTab("Help", tabs)
    guiCreateLabel(12, 12, W - 60, 520,
        "WORKFLOW\n" ..
        "  1. Create houses and garages separately.\n" ..
        "  2. Use the Properties tab to edit name/price, link, unlink, teleport, or delete.\n" ..
        "  3. Linked properties share ownership and key access if one side is already owned.\n\n" ..
        "LINKING RULES\n" ..
        "  - Links connect one garage to one house/apartment.\n" ..
        "  - Standalone houses stay unlinked.\n" ..
        "  - Standalone garages stay unlinked.\n" ..
        "  - Linking a sold property to an empty one copies owner/lock data.\n\n" ..
        "GARAGE NOTE\n" ..
        "  - New houses do not auto-create garages anymore.\n" ..
        "  - Garage properties use the garage system markers after they are created.\n\n" ..
        "COMMANDS\n" ..
        "  /houseadmin or /ha    Open this panel\n" ..
        "  /exitpreview          Leave admin preview mode",
        false, tabHelp)

    addEventHandler("onClientGUIClick", ui.propertyList, function()
        local row = guiGridListGetSelectedItem(ui.propertyList)
        if row < 0 then
            selectedPropertyId = nil
            refreshSelectionDetails()
            return
        end
        selectedPropertyId = tonumber(guiGridListGetItemText(ui.propertyList, row, 1))
        refreshSelectionDetails()
    end, false)

    addEventHandler("onClientGUIClick", btnTeleport, function()
        local row = getSelectedProperty()
        if not row then
            setListStatus("Select a property first.", 255, 160, 60)
            return
        end
        triggerServerEvent("hm:requestTeleport", localPlayer, row.id)
    end, false)

    addEventHandler("onClientGUIClick", btnTeleInt, function()
        local row = getSelectedProperty()
        if not row then
            setListStatus("Select a property first.", 255, 160, 60)
            return
        end
        triggerServerEvent("hm:requestTeleportInterior", localPlayer, row.id)
    end, false)

    addEventHandler("onClientGUIClick", btnRefresh, function()
        triggerServerEvent("hm:requestList", localPlayer)
        triggerServerEvent("hm:requestCatalog", localPlayer)
        setListStatus("Refreshing...", 200, 200, 100)
    end, false)

    local confirmDeleteId = nil
    local confirmTimer = nil
    addEventHandler("onClientGUIClick", btnDelete, function()
        local row = getSelectedProperty()
        if not row then
            setListStatus("Select a property first.", 255, 160, 60)
            return
        end

        if confirmDeleteId ~= row.id then
            confirmDeleteId = row.id
            if confirmTimer and isTimer(confirmTimer) then
                killTimer(confirmTimer)
            end
            confirmTimer = setTimer(function()
                confirmDeleteId = nil
                setListStatus("", 180, 180, 180)
            end, 4000, 1)
            setListStatus("Click Delete again to confirm '" .. tostring(row.name) .. "'.", 255, 200, 50)
            return
        end

        confirmDeleteId = nil
        if confirmTimer and isTimer(confirmTimer) then
            killTimer(confirmTimer)
        end
        triggerServerEvent("hm:requestDelete", localPlayer, row.id)
        setListStatus("Deleting #" .. tostring(row.id) .. "...", 255, 160, 60)
    end, false)

    addEventHandler("onClientGUIClick", btnSave, function()
        local row = getSelectedProperty()
        if not row then
            setListStatus("Select a property first.", 255, 160, 60)
            return
        end

        local name = guiGetText(ui.editName)
        local price = tonumber(guiGetText(ui.editPrice))
        if name == "" or not price then
            setListStatus("Enter a valid name and price.", 255, 80, 80)
            return
        end

        triggerServerEvent("hm:requestUpdate", localPlayer, row.id, name, price)
        setListStatus("Saving changes for #" .. tostring(row.id) .. "...", 200, 200, 100)
    end, false)

    addEventHandler("onClientGUIClick", btnApplyLink, function()
        local row = getSelectedProperty()
        if not row then
            setListStatus("Select a property first.", 255, 160, 60)
            return
        end

        local targetId = getComboValue(ui.linkCombo)
        if not targetId then
            setListStatus("Select a target property to link.", 255, 160, 60)
            return
        end

        triggerServerEvent("hm:requestLink", localPlayer, row.id, targetId)
        setListStatus("Linking #" .. tostring(row.id) .. " to #" .. tostring(targetId) .. "...", 200, 200, 100)
    end, false)

    addEventHandler("onClientGUIClick", btnClearLink, function()
        local row = getSelectedProperty()
        if not row then
            setListStatus("Select a property first.", 255, 160, 60)
            return
        end

        triggerServerEvent("hm:requestUnlink", localPlayer, row.id)
        setListStatus("Clearing link for #" .. tostring(row.id) .. "...", 255, 180, 80)
    end, false)

    local function bindAddTab(kind)
        local tabUi = ui.add[kind]

        addEventHandler("onClientGUIClick", tabUi.previewButton, function()
            local category = getComboValue(tabUi.categoryCombo)
            if not category then
                setAddStatus(kind, "Select a type first.", 255, 160, 60)
                return
            end
            isPreviewing = true
            guiSetVisible(ui.add.house.exitPreviewButton, true)
            guiSetVisible(ui.add.garage.exitPreviewButton, true)
            triggerServerEvent("hm:requestPreview", localPlayer, category)
            setAddStatus(kind, "Previewing selected interior...", 100, 200, 255)
        end, false)

        addEventHandler("onClientGUIClick", tabUi.exitPreviewButton, function()
            isPreviewing = false
            stopNoclip()
            guiSetText(btnNoclip, "Noclip")
            guiSetEnabled(btnSetSpawn, false)
            guiSetVisible(ui.add.house.exitPreviewButton, false)
            guiSetVisible(ui.add.garage.exitPreviewButton, false)
            triggerServerEvent("hm:exitPreview", localPlayer)
            setAddStatus(kind, "Returned from preview.", 120, 255, 120)
        end, false)

        addEventHandler("onClientGUIClick", tabUi.addButton, function()
            if isPreviewing then
                setAddStatus(kind, "Exit preview first before creating.", 255, 160, 60)
                return
            end

            local name = guiGetText(tabUi.nameEdit)
            local price = tonumber(guiGetText(tabUi.priceEdit))
            local category = getComboValue(tabUi.categoryCombo)
            local linkTo = getComboValue(tabUi.linkCombo)
            if name == "" or not price or not category then
                setAddStatus(kind, "Fill in the name, type, and price first.", 255, 80, 80)
                return
            end

            local createData = {
                name = name,
                price = price,
                category = category,
                link_to = linkTo or false,
            }
            if customSpawnOverride then
                createData.custom_x = customSpawnOverride.x
                createData.custom_y = customSpawnOverride.y
                createData.custom_z = customSpawnOverride.z
                customSpawnOverride = nil
            end
            triggerServerEvent("hm:requestCreate", localPlayer, createData)
            setAddStatus(kind, "Creating property and reloading housing...", 100, 255, 100)
        end, false)
    end

    bindAddTab("house")
    bindAddTab("garage")

    addEventHandler("onClientGUIClick", btnClose, function()
        closePanel()
    end, false)

    addEventHandler("onClientGUIClose", panel, function()
        cancelEvent()
        closePanel()
    end, false)
end

addEvent("hm:receiveCatalog", true)
addEventHandler("hm:receiveCatalog", root, function(payload)
    catalog = payload or { houses = {}, garages = {} }

    local houseEntries = {}
    for _, entry in ipairs(catalog.houses or {}) do
        houseEntries[#houseEntries + 1] = {
            label = tostring(entry.label) .. " [" .. tostring(entry.size or "?") .. "]",
            value = entry.key,
        }
    end

    local garageEntries = {}
    for _, entry in ipairs(catalog.garages or {}) do
        garageEntries[#garageEntries + 1] = {
            label = tostring(entry.label) .. " [" .. tostring(entry.size or "?") .. "]",
            value = entry.key,
        }
    end

    if ui.add.house.categoryCombo and isElement(ui.add.house.categoryCombo) then
        setComboEntries(ui.add.house.categoryCombo, houseEntries, nil)
    end
    if ui.add.garage.categoryCombo and isElement(ui.add.garage.categoryCombo) then
        setComboEntries(ui.add.garage.categoryCombo, garageEntries, nil)
    end

    refreshCreateLinkCombos()
end)

addEvent("hm:receiveList", true)
addEventHandler("hm:receiveList", root, function(list)
    propertyRows = list or {}
    refreshPropertyGrid()
end)

addEvent("hm:deleteResult", true)
addEventHandler("hm:deleteResult", root, function(success, propertyId)
    if success then
        if tonumber(selectedPropertyId) == tonumber(propertyId) then
            selectedPropertyId = nil
        end
        triggerServerEvent("hm:requestList", localPlayer)
        setListStatus("Deleted #" .. tostring(propertyId) .. ".", 255, 160, 60)
    else
        setListStatus("Delete failed: property not found.", 255, 80, 80)
    end
end)

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
    triggerServerEvent("hm:requestCatalog", localPlayer)
    triggerServerEvent("hm:requestList", localPlayer)
    triggerServerEvent("hm:requestInteriorList", localPlayer)
end)

addEventHandler("onClientKey", root, function(key, press)
    if press and key == "escape" and isOpen then
        closePanel()
    end
end)

-- ─────────────────────────────────────────────────────────────
-- INTERIOR MANAGER: Client events
-- ─────────────────────────────────────────────────────────────
addEvent("hm:receiveInteriorList", true)
addEventHandler("hm:receiveInteriorList", root, function(list)
    if not ui.interiorGrid or not isElement(ui.interiorGrid) then return end

    guiGridListClear(ui.interiorGrid)

    for _, entry in ipairs(list or {}) do
        local row = guiGridListAddRow(ui.interiorGrid)
        guiGridListSetItemText(ui.interiorGrid, row, 1, entry.label, false, false)
        guiGridListSetItemData(ui.interiorGrid, row, 1, entry.key)
        guiGridListSetItemText(ui.interiorGrid, row, 2, entry.ptype, false, false)
        guiGridListSetItemText(ui.interiorGrid, row, 3, entry.size, false, false)
        guiGridListSetItemText(ui.interiorGrid, row, 4, entry.is_custom and "Custom" or "Native", false, false)
        guiGridListSetItemText(ui.interiorGrid, row, 5, entry.enabled and "Enabled" or "DISABLED", false, false)
        guiGridListSetItemText(ui.interiorGrid, row, 6, entry.custom_map ~= "" and entry.custom_map or "--", false, false)
        guiGridListSetItemText(ui.interiorGrid, row, 7, entry.orig_running and "RUNNING!" or "OK", false, false)

        -- Color the status column
        if entry.enabled then
            guiGridListSetItemColor(ui.interiorGrid, row, 5, 100, 255, 100)
        else
            guiGridListSetItemColor(ui.interiorGrid, row, 5, 255, 100, 100)
        end

        -- Color the conflict column
        if entry.orig_running then
            guiGridListSetItemColor(ui.interiorGrid, row, 7, 255, 80, 80)
        else
            guiGridListSetItemColor(ui.interiorGrid, row, 7, 100, 255, 100)
        end
    end

    if ui.interiorStatus and isElement(ui.interiorStatus) then
        guiSetText(ui.interiorStatus, "Loaded " .. #(list or {}) .. " interiors.")
        guiLabelSetColor(ui.interiorStatus, 120, 255, 120)
    end
end)
