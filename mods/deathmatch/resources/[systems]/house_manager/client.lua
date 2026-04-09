-- house_manager/client.lua
-- Pure MTA native GUI admin panel. No browser, no cursor lock issues.
-- Open with /houseadmin (or /ha). Admin only.

local panel      = nil   -- main window
local isOpen     = false
local propList   = nil   -- gridlist element
local presets    = {}    -- received from server
local editRow    = -1    -- currently selected row in list

-- ── Attach GUI click handlers concisely ──
function guiAddEventHandler(element, eventName, handler)
    local fullName = ({
        onClick    = "onClientGUIClick",
        onChange   = "onClientGUIChanged",
        onAccepted = "onClientGUIComboBoxAccepted",
    })[eventName] or ("onClientGUI" .. eventName)
    addEventHandler(fullName, element, handler)
end

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

-- ═══════════════════════════════════════════════════════════════
-- BUILD GUI
-- ═══════════════════════════════════════════════════════════════
local function buildPanel()
    if panel and isElement(panel) then return end

    local W, H = 820, 560
    panel = guiCreateWindow(0, 0, W, H, "🏘  House Manager  —  Admin Only", false)
    guiCenter(panel)
    guiWindowSetSizable(panel, false)
    guiSetAlpha(panel, 0.96)

    -- Close on X
    guiCreateButton(W - 28, 4, 22, 22, "✕", false, panel)

    -- ── TAB PANEL ──────────────────────────────────────────────
    local tabs = guiCreateTabPanel(6, 28, W - 12, H - 36, false, panel)

    -- ╔══════════════════════════════════════════════════════╗
    -- ║  TAB 1 – Properties List                            ║
    -- ╚══════════════════════════════════════════════════════╝
    local tabList = guiCreateTab("📋  Properties List", tabs)

    propList = guiCreateGridList(4, 4, W - 24, 380, false, tabList)
    guiGridListSetSelectionMode(propList, 0)
    local cols = {
        { name = "ID",    w = 40  },
        { name = "Name",  w = 200 },
        { name = "Type",  w = 90  },
        { name = "Price", w = 90  },
        { name = "Owner", w = 150 },
        { name = "Lock",  w = 50  },
    }
    for _, c in ipairs(cols) do
        guiGridListAddColumn(propList, c.name, c.w / (W - 24))
    end

    -- Action bar below the list
    local btnTeleport = guiCreateButton( 4,  390, 120, 28, "🚀 Go There",   false, tabList)
    local btnEdit     = guiCreateButton(130,  390, 120, 28, "✏  Edit",       false, tabList)
    local btnDelete   = guiCreateButton(256,  390, 120, 28, "🗑  Delete",     false, tabList)
    local btnRefresh  = guiCreateButton(382,  390, 120, 28, "🔄 Refresh",    false, tabList)

    local lblStatus   = guiCreateLabel(4, 424, W - 30, 20, "", false, tabList)
    guiLabelSetColor(lblStatus, 180, 255, 180)

    -- ── Edit row (inline, shown when a row is selected + Edit clicked) ──
    local editFrame  = guiCreateStaticImage(4, 444, W - 26, 90, "white.png", false, tabList)    -- placeholder
    guiSetVisible(editFrame, false)
    local lblEName   = guiCreateLabel(    8, 448,  60, 20, "Name:",  false, tabList)
    local edtEName   = guiCreateEdit(    70, 448, 220, 22, "",       false, tabList)
    local lblEPrice  = guiCreateLabel(  300, 448,  50, 20, "Price:", false, tabList)
    local edtEPrice  = guiCreateEdit(   352, 448, 120, 22, "",       false, tabList)
    local btnESave   = guiCreateButton( 480, 448, 100, 22, "💾 Save", false, tabList)
    local btnECancel = guiCreateButton( 586, 448, 100, 22, "✖ Cancel",false, tabList)
    guiSetVisible(lblEName,  false)
    guiSetVisible(edtEName,  false)
    guiSetVisible(lblEPrice, false)
    guiSetVisible(edtEPrice, false)
    guiSetVisible(btnESave,  false)
    guiSetVisible(btnECancel,false)

    local function showEditRow(show)
        guiSetVisible(lblEName,  show)
        guiSetVisible(edtEName,  show)
        guiSetVisible(lblEPrice, show)
        guiSetVisible(edtEPrice, show)
        guiSetVisible(btnESave,  show)
        guiSetVisible(btnECancel,show)
    end

    -- ╔══════════════════════════════════════════════════════╗
    -- ║  TAB 2 – Add New Property                           ║
    -- ╚══════════════════════════════════════════════════════╝
    local tabAdd = guiCreateTab("➕  Add Property", tabs)

    -- Info box
    guiCreateLabel(10, 10, W - 30, 40,
        "Stand exactly at the front door of the property you want to add.\n"..
        "The entry point will be captured from your current world position.",
        false, tabAdd)

    -- Fields
    local function addRow(y, labelText, ...)
        guiCreateLabel(10, y, 120, 22, labelText, false, tabAdd)
    end

    local Y = 58
    local ROW = 34

    -- Name
    addRow(Y, "Property Name:")
    local edtName = guiCreateEdit(140, Y, 300, 24, "My House", false, tabAdd)
    Y = Y + ROW

    -- Category
    addRow(Y, "Category:")
    local cmbCat = guiCreateComboBox(140, Y, 250, 24, "Select type...", false, tabAdd)
    Y = Y + ROW

    -- Price
    addRow(Y, "Price ($):")
    local edtPrice = guiCreateEdit(140, Y, 180, 24, "50000", false, tabAdd)
    Y = Y + ROW

    -- Info labels
    local lblPos = guiCreateLabel(10, Y, W - 30, 20, "Entry: (will use your position when you click Add)", false, tabAdd)
    guiLabelSetColor(lblPos, 200, 200, 255)
    Y = Y + 26

    local lblPreview = guiCreateLabel(10, Y, W - 30, 60,
        "Interior: chosen automatically from category preset\n"..
        "Garage zone: 10 units behind you\n"..
        "Dimension: auto-assigned (6000 + new ID)",
        false, tabAdd)
    guiLabelSetColor(lblPreview, 160, 160, 160)
    Y = Y + 72

    -- Submit
    local btnAdd    = guiCreateButton(140, Y, 200, 32, "✅  Add Property Here", false, tabAdd)
    local lblAddSt  = guiCreateLabel(  10, Y + 38, W - 30, 20, "", false, tabAdd)
    guiLabelSetColor(lblAddSt, 180, 255, 180)

    -- ╔══════════════════════════════════════════════════════╗
    -- ║  TAB 3 – Help                                       ║
    -- ╚══════════════════════════════════════════════════════╝
    local tabHelp = guiCreateTab("❓  Help", tabs)
    guiCreateLabel(10, 10, W - 30, 500,
        "COMMANDS\n"..
        "  /houseadmin  or  /ha   — open this panel\n\n"..
        "PROPERTY CATEGORIES\n"..
        "  Small House   — compact 1-bed interior (Interior 4)\n"..
        "  Medium House  — standard 2-bed interior (Interior 1)\n"..
        "  Large House   — spacious 3-bed interior (Interior 2)\n"..
        "  Mansion       — luxury interior (Interior 4, dim 0)\n"..
        "  Apartment     — high-rise apartment (Interior 3)\n"..
        "  Penthouse     — rooftop suite (Interior 5)\n"..
        "  Warehouse     — industrial space (Interior 18)\n\n"..
        "PROCESS TO ADD A PROPERTY\n"..
        "  1. Drive to the actual door of the house/building in-game\n"..
        "  2. Open /houseadmin → 'Add Property' tab\n"..
        "  3. Fill in name, category, and price\n"..
        "  4. Click '✅ Add Property Here'\n"..
        "  5. Housing resource restarts automatically (~1 second)\n"..
        "  6. Yellow triangle appears at that location\n\n"..
        "ENTRY / EXIT\n"..
        "  Yellow arrow  → property entrance. Walk into it to see popup.\n"..
        "  [F] Enter   [B] Buy   [G] Lock/Unlock   [ESC] Dismiss\n"..
        "  Orange arrow inside the property → exit back outside.\n\n"..
        "SHARING KEYS\n"..
        "  /sharekey <playerName>   — on your property\n"..
        "  /revokekey <playerName>  — on your property\n"..
        "  /myproperties            — list your own properties",
        false, tabHelp)

    -- ═══════════════════════════════════════════════════════════
    -- EVENT WIRING
    -- ═══════════════════════════════════════════════════════════

    -- Populate category combobox when presets arrive
    addEvent("hm:receivePresets", false)
    addEventHandler("hm:receivePresets", root, function(cats)
        presets = cats
        for _, c in ipairs(cats) do
            guiComboBoxAddItem(cmbCat, c.label)
        end
        if #cats > 0 then guiComboBoxSetSelected(cmbCat, 0) end
    end)

    -- Populate list when data arrives
    addEvent("hm:receiveList", false)
    addEventHandler("hm:receiveList", root, function(list)
        guiGridListClear(propList)
        for _, p in ipairs(list) do
            local row = guiGridListAddRow(propList)
            guiGridListSetItemText(propList, row, 1, tostring(p.id), false, false)
            guiGridListSetItemText(propList, row, 2, p.name,         false, false)
            guiGridListSetItemText(propList, row, 3, p.ptype,        false, false)
            guiGridListSetItemText(propList, row, 4, fmtMoney(p.price), false, false)
            guiGridListSetItemText(propList, row, 5, p.owner ~= "" and p.owner or "Available", false, false)
            guiGridListSetItemText(propList, row, 6, p.locked and "🔒" or "🔓", false, false)
        end
        guiSetText(lblStatus, "Loaded " .. #list .. " properties.")
    end)

    -- Refresh
    guiAddEventHandler(btnRefresh, "onClick", function()
        triggerServerEvent("hm:requestList", localPlayer)
        guiSetText(lblStatus, "Refreshing...")
    end)

    -- Teleport
    guiAddEventHandler(btnTeleport, "onClick", function()
        local selRow = guiGridListGetSelectedItem(propList)
        if selRow < 0 then guiSetText(lblStatus, "Select a property first.") return end
        local id = tonumber(guiGridListGetItemText(propList, selRow, 1))
        if id then triggerServerEvent("hm:requestTeleport", localPlayer, id) end
    end)

    -- Edit
    guiAddEventHandler(btnEdit, "onClick", function()
        local selRow = guiGridListGetSelectedItem(propList)
        if selRow < 0 then guiSetText(lblStatus, "Select a property first.") return end
        editRow = selRow
        guiSetText(edtEName, guiGridListGetItemText(propList, selRow, 2))
        guiSetText(edtEPrice, (guiGridListGetItemText(propList, selRow, 4)):gsub("%$", ""))
        showEditRow(true)
    end)

    -- Edit Save
    guiAddEventHandler(btnESave, "onClick", function()
        if editRow < 0 then return end
        local id    = tonumber(guiGridListGetItemText(propList, editRow, 1))
        local name  = guiGetText(edtEName)
        local price = tonumber(guiGetText(edtEPrice))
        if not id or not name or name == "" or not price then
            guiSetText(lblStatus, "Invalid name or price.")
            return
        end
        triggerServerEvent("hm:requestUpdate", localPlayer, id, name, price)
        showEditRow(false)
        editRow = -1
        guiSetText(lblStatus, "Update sent for #" .. id .. "...")
    end)

    -- Edit Cancel
    guiAddEventHandler(btnECancel, "onClick", function()
        showEditRow(false)
        editRow = -1
    end)

    -- Delete
    guiAddEventHandler(btnDelete, "onClick", function()
        local selRow = guiGridListGetSelectedItem(propList)
        if selRow < 0 then guiSetText(lblStatus, "Select a property first.") return end
        local id   = tonumber(guiGridListGetItemText(propList, selRow, 1))
        local name = guiGridListGetItemText(propList, selRow, 2)
        if not id then return end
        -- Simple confirm via re-click (second click within 3s deletes)
        if not panel._confirmDelete or panel._confirmDelete ~= id then
            panel._confirmDelete = id
            guiSetText(lblStatus, "⚠ Click Delete again to confirm deleting '" .. name .. "' #" .. id)
            setTimer(function() panel._confirmDelete = nil end, 4000, 1)
        else
            panel._confirmDelete = nil
            triggerServerEvent("hm:requestDelete", localPlayer, id)
            guiSetText(lblStatus, "Deleting #" .. id .. "...")
        end
    end)

    -- Add property
    guiAddEventHandler(btnAdd, "onClick", function()
        local name  = guiGetText(edtName)
        local price = tonumber(guiGetText(edtPrice))
        local catIdx = guiComboBoxGetSelected(cmbCat)
        if name == "" or not price or catIdx < 0 then
            guiSetText(lblAddSt, "Fill in all fields first.")
            return
        end
        local category = presets[catIdx + 1] and presets[catIdx + 1].key or "small"
        triggerServerEvent("hm:requestCreate", localPlayer, {
            name     = name,
            price    = price,
            category = category,
        })
        guiSetText(lblAddSt, "✅ Sent! Housing restarting in ~1s…")
    end)

    -- Close panel (onClientGUIClose fires when the X is clicked)
    addEventHandler("onClientGUIClose", panel, function()
        isOpen = false
        showCursor(false)
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- OPEN / CLOSE
-- ═══════════════════════════════════════════════════════════════
addEvent("hm:openPanel", false)
addEventHandler("hm:openPanel", root, function()
    buildPanel()
    guiSetVisible(panel, true)
    guiBringToFront(panel)
    showCursor(true)
    isOpen = true
    triggerServerEvent("hm:requestPresets", localPlayer)
    triggerServerEvent("hm:requestList",   localPlayer)
end)

-- ESC to close
addEventHandler("onClientKey", root, function(key, press)
    if press and key == "escape" and isOpen then
        isOpen = false
        showCursor(false)
        if panel and isElement(panel) then
            guiSetVisible(panel, false)
        end
    end
end)


