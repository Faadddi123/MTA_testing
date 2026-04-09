const inventoryShell = document.getElementById("inventory-shell");
const inventoryGrid = document.getElementById("inventory-grid");
const weightText = document.getElementById("weight-text");
const weightFill = document.getElementById("weight-fill");
const quickSlots = document.getElementById("quick-slots");
const housePopup = document.getElementById("house-popup");
const houseName = document.getElementById("house-name");
const houseOwner = document.getElementById("house-owner");
const housePrice = document.getElementById("house-price");
const houseStatus = document.getElementById("house-status");
const houseActions = document.getElementById("house-actions");
const inventoryClose = document.getElementById("inventory-close");

const defaultIcons = {
    bread: "icons/bread.png",
    water: "icons/water.png",
    pistol: "icons/pistol.png",
    key: "icons/key.png",
};

const state = {
    inventoryVisible: false,
    housePopupVisible: false,
    inventory: {
        items: [],
        currentWeight: 0,
        maxWeight: 35,
        quickSlots: [],
        totalSlots: 30,
    },
    house: null,
};

function escapeHtml(value) {
    return String(value == null ? "" : value)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#39;");
}

function safeTrigger(eventName) {
    if (window.mta && typeof window.mta.triggerEvent === "function") {
        window.mta.triggerEvent(eventName);
    }
}

function getItemIcon(item) {
    if (item && item.icon) {
        return item.icon;
    }

    const key = item && item.item ? String(item.item).toLowerCase() : "key";
    return defaultIcons[key] || defaultIcons.key;
}

function formatMoney(value) {
    return `$${Number(value || 0).toLocaleString()}`;
}

function createSlot(item) {
    const element = document.createElement("article");
    element.className = "inventory-slot";

    if (!item) {
        element.classList.add("empty");
        element.innerHTML = `
            <img class="slot-icon" src="${defaultIcons.key}" alt="">
            <h3 class="slot-title">Empty Slot</h3>
            <p class="slot-subtext">No item stored</p>
            <div class="slot-body"><span>Amount</span><strong>0</strong></div>
        `;
        return element;
    }

    element.innerHTML = `
        <img class="slot-icon" src="${getItemIcon(item)}" alt="${escapeHtml(item.label || item.item || "item")}">
        <h3 class="slot-title">${escapeHtml(item.label || item.item || "Unknown Item")}</h3>
        <p class="slot-subtext">${Number(item.weight || 0).toFixed(1)} kg each</p>
        <div class="slot-body"><span>Amount</span><strong>x${Number(item.amount || 0)}</strong></div>
    `;
    return element;
}

function renderInventory() {
    inventoryGrid.innerHTML = "";

    const items = Array.isArray(state.inventory.items) ? state.inventory.items.slice(0, state.inventory.totalSlots || 30) : [];
    const totalSlots = Math.max(30, items.length);
    for (let index = 0; index < totalSlots; index += 1) {
        inventoryGrid.appendChild(createSlot(items[index] || null));
    }

    const currentWeight = Number(state.inventory.currentWeight || 0);
    const maxWeight = Math.max(Number(state.inventory.maxWeight || 1), 1);
    const weightPercent = Math.max(0, Math.min(100, (currentWeight / maxWeight) * 100));
    weightText.textContent = `${currentWeight.toFixed(1)} / ${maxWeight.toFixed(1)} kg`;
    weightFill.style.width = `${weightPercent}%`;

    quickSlots.innerHTML = "";
    const slots = Array.isArray(state.inventory.quickSlots) ? state.inventory.quickSlots : [];
    for (let index = 0; index < 5; index += 1) {
        const slotData = slots[index] || { slot: index + 1 };
        const node = document.createElement("div");
        node.className = "quick-slot-card";
        node.innerHTML = `
            <div class="quick-slot-top">
                <span class="quick-slot-number">${slotData.slot || index + 1}</span>
                <img class="slot-icon" src="${slotData.item ? getItemIcon(slotData) : defaultIcons.key}" alt="">
            </div>
            <strong>${escapeHtml(slotData.label || "Empty")}</strong>
            <span>${slotData.amount ? `x${slotData.amount}` : "Unassigned"}</span>
        `;
        quickSlots.appendChild(node);
    }
}

function buildActionButton(label, eventName, variant) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `action-button${variant ? ` ${variant}` : ""}`;
    button.textContent = label;
    button.addEventListener("click", () => safeTrigger(eventName));
    return button;
}

function renderHousePopup() {
    const house = state.house || {};
    houseName.textContent = house.name || "Property";
    houseOwner.textContent = house.ownerName || "Available";
    housePrice.textContent = formatMoney(house.price || 0);
    houseStatus.textContent = house.locked ? "Locked" : "Unlocked";

    houseActions.innerHTML = "";

    if (house.canBuy) {
        houseActions.appendChild(buildActionButton("Buy", "housing:browserBuy", "primary"));
    }

    if (house.canEnter) {
        houseActions.appendChild(buildActionButton("Enter", "housing:browserEnter"));
    }

    if (house.canLock) {
        houseActions.appendChild(buildActionButton(house.locked ? "Unlock" : "Lock", "housing:browserLock", "warning"));
    }

    if (house.canPark) {
        houseActions.appendChild(buildActionButton("Park Vehicle", "vehicles:browserPark"));
    }
}

window.setInventoryVisible = function setInventoryVisible(visible) {
    state.inventoryVisible = Boolean(visible);
    inventoryShell.classList.toggle("hidden", !state.inventoryVisible);
};

window.updateInventory = function updateInventory(data) {
    state.inventory = Object.assign({}, state.inventory, data || {});
    renderInventory();
};

window.setHousePopupVisible = function setHousePopupVisible(visible) {
    state.housePopupVisible = Boolean(visible);
    housePopup.classList.toggle("hidden", !state.housePopupVisible);
};

window.updateHousePopup = function updateHousePopup(data) {
    state.house = data || null;
    renderHousePopup();
};

inventoryClose.addEventListener("click", () => safeTrigger("inventory:browserClose"));

renderInventory();
renderHousePopup();
