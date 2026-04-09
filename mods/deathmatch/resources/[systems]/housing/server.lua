-- housing/server.lua
-- Houses + Apartments + Shared Keys + Garage Interior Dimensions
-- Integrates with: database_manager, inventory, vehicles, garage_system

local legacyDbConnect = dbConnect
local legacyDbPoll    = dbPoll
local legacyDbQuery   = dbQuery

-- ─────────────────────────────────────────────────────────────────────────────
-- PROPERTY DEFINITIONS  (37 total – Houses & Apartments across all SA regions)
-- Each property uses its own dimension (6000+id) so interior skins can repeat.
-- ─────────────────────────────────────────────────────────────────────────────
local propertyDefinitions = {
    -- ═══ LOS SANTOS – HOUSES ══════════════════════════════
    {
        id = 1, name = "Ganton Safehouse", type = "house", price = 45000,
        exterior   = { x = 2495.33,  y = -1690.75, z = 13.78,  rotation = 180, interior = 0 },
        interior   = { x = 2496.05,  y = -1692.73, z = 1013.75, rotation = 0,  interior = 3 },
        garage     = { x = 2495.33,  y = -1683.50, z = 13.78,  radius = 10 },
        garage_int = { x = 2495.33,  y = -1678.00, z = 13.78,  rotation = 0 },
    },
    {
        id = 2, name = "East LS Bungalow", type = "house", price = 38000,
        exterior   = { x = 2402.52,  y = -1715.28, z = 14.13,  rotation = 180, interior = 0 },
        interior   = { x = 243.75,   y = 304.82,   z = 999.14, rotation = 270, interior = 1 },
        garage     = { x = 2398.50,  y = -1709.00, z = 13.80,  radius = 10 },
        garage_int = { x = 2398.50,  y = -1704.00, z = 13.80,  rotation = 0 },
    },
    {
        id = 15, name = "Idlewood House", type = "house", price = 32000,
        exterior   = { x = 1972.20,  y = -1744.80, z = 13.55,  rotation = 270, interior = 0 },
        interior   = { x = 265.20,   y = 303.50,   z = 999.15, rotation = 90,  interior = 4 },
        garage     = { x = 1967.00,  y = -1744.80, z = 13.55,  radius = 9 },
        garage_int = { x = 1962.00,  y = -1744.80, z = 13.55,  rotation = 90 },
    },
    {
        id = 16, name = "Playa del Seville House", type = "house", price = 40000,
        exterior   = { x = 2640.20,  y = -1835.80, z = 13.60,  rotation = 0,   interior = 0 },
        interior   = { x = 295.00,   y = 310.00,   z = 999.15, rotation = 180, interior = 2 },
        garage     = { x = 2640.20,  y = -1829.00, z = 13.60,  radius = 9 },
        garage_int = { x = 2640.20,  y = -1824.00, z = 13.60,  rotation = 0 },
    },
    {
        id = 17, name = "East Beach House", type = "house", price = 47000,
        exterior   = { x = 2747.50,  y = -1694.50, z = 13.60,  rotation = 90,  interior = 0 },
        interior   = { x = 322.25,   y = 302.42,   z = 999.15, rotation = 270, interior = 5 },
        garage     = { x = 2753.00,  y = -1694.50, z = 13.60,  radius = 9 },
        garage_int = { x = 2758.00,  y = -1694.50, z = 13.60,  rotation = 90 },
    },
    {
        id = 18, name = "Willowfield Safehouse", type = "house", price = 33000,
        exterior   = { x = 2261.60,  y = -1547.70, z = 25.60,  rotation = 180, interior = 0 },
        interior   = { x = 343.74,   y = 305.03,   z = 999.15, rotation = 0,   interior = 6 },
        garage     = { x = 2261.60,  y = -1541.00, z = 25.60,  radius = 9 },
        garage_int = { x = 2261.60,  y = -1536.00, z = 25.60,  rotation = 0 },
    },
    {
        id = 19, name = "Verona Beach Bungalow", type = "house", price = 52000,
        exterior   = { x = 490.40,   y = -1339.40, z = 17.30,  rotation = 90,  interior = 0 },
        interior   = { x = 265.00,   y = 303.00,   z = 999.15, rotation = 270, interior = 8 },
        garage     = { x = 496.00,   y = -1339.40, z = 17.30,  radius = 9 },
        garage_int = { x = 502.00,   y = -1339.40, z = 17.30,  rotation = 90 },
    },
    {
        id = 20, name = "Santa Maria House", type = "house", price = 58000,
        exterior   = { x = 832.90,   y = -1337.00, z = 13.60,  rotation = 270, interior = 0 },
        interior   = { x = 295.00,   y = 310.00,   z = 999.15, rotation = 90,  interior = 9 },
        garage     = { x = 827.00,   y = -1337.00, z = 13.60,  radius = 9 },
        garage_int = { x = 821.00,   y = -1337.00, z = 13.60,  rotation = 270 },
    },
    {
        id = 21, name = "Marina District House", type = "house", price = 75000,
        exterior   = { x = 851.50,   y = -1252.50, z = 13.60,  rotation = 180, interior = 0 },
        interior   = { x = 243.75,   y = 304.82,   z = 999.14, rotation = 0,   interior = 1 },
        garage     = { x = 851.50,   y = -1246.00, z = 13.60,  radius = 9 },
        garage_int = { x = 851.50,   y = -1240.00, z = 13.60,  rotation = 0 },
    },
    {
        id = 22, name = "Mulholland Mansion", type = "house", price = 120000,
        exterior   = { x = -502.00,  y = -1222.80, z = 30.30,  rotation = 270, interior = 0 },
        interior   = { x = 300.24,   y = 300.58,   z = 999.15, rotation = 90,  interior = 4 },
        garage     = { x = -508.00,  y = -1222.80, z = 30.30,  radius = 11 },
        garage_int = { x = -514.00,  y = -1222.80, z = 30.30,  rotation = 270 },
    },
    {
        id = 23, name = "Richman Estate", type = "house", price = 150000,
        exterior   = { x = -1354.50, y = -700.50,  z = 30.10,  rotation = 0,   interior = 0 },
        interior   = { x = 265.20,   y = 303.50,   z = 999.15, rotation = 180, interior = 5 },
        garage     = { x = -1354.50, y = -694.00,  z = 30.10,  radius = 12 },
        garage_int = { x = -1354.50, y = -688.00,  z = 30.10,  rotation = 0 },
    },
    {
        id = 24, name = "Vinewood Hills House", type = "house", price = 110000,
        exterior   = { x = -840.70,  y = -838.50,  z = 56.10,  rotation = 90,  interior = 0 },
        interior   = { x = 322.25,   y = 302.42,   z = 999.15, rotation = 270, interior = 5 },
        garage     = { x = -835.00,  y = -838.50,  z = 56.10,  radius = 10 },
        garage_int = { x = -829.00,  y = -838.50,  z = 56.10,  rotation = 90 },
    },
    {
        id = 25, name = "Los Flores House", type = "house", price = 36000,
        exterior   = { x = 2757.60,  y = -1836.30, z = 13.60,  rotation = 0,   interior = 0 },
        interior   = { x = 343.74,   y = 305.03,   z = 999.15, rotation = 180, interior = 6 },
        garage     = { x = 2757.60,  y = -1830.00, z = 13.60,  radius = 9 },
        garage_int = { x = 2757.60,  y = -1824.00, z = 13.60,  rotation = 0 },
    },
    {
        id = 26, name = "Jefferson House", type = "house", price = 41000,
        exterior   = { x = 2175.70,  y = -1160.50, z = 25.90,  rotation = 180, interior = 0 },
        interior   = { x = 295.00,   y = 310.00,   z = 999.15, rotation = 0,   interior = 2 },
        garage     = { x = 2175.70,  y = -1154.00, z = 25.90,  radius = 9 },
        garage_int = { x = 2175.70,  y = -1148.00, z = 25.90,  rotation = 0 },
    },
    -- ═══ LOS SANTOS – APARTMENTS ══════════════════════════
    {
        id = 3, name = "Rodeo Apartment", type = "apartment", price = 62000,
        exterior   = { x = -382.67,  y = -1438.83, z = 26.12,  rotation = 270, interior = 0 },
        interior   = { x = 292.89,   y = 309.90,   z = 999.15, rotation = 90,  interior = 3 },
        garage     = { x = -376.90,  y = -1438.83, z = 25.90,  radius = 10 },
        garage_int = { x = -370.90,  y = -1438.83, z = 25.90,  rotation = 90 },
    },
    {
        id = 10, name = "Commerce Apartment", type = "apartment", price = 55000,
        exterior   = { x = 1541.50,  y = -1330.80, z = 17.25,  rotation = 180, interior = 0 },
        interior   = { x = 295.00,   y = 310.00,   z = 999.15, rotation = 270, interior = 2 },
        garage     = { x = 1541.50,  y = -1324.00, z = 17.25,  radius = 10 },
        garage_int = { x = 1541.50,  y = -1318.00, z = 17.25,  rotation = 0 },
    },
    {
        id = 11, name = "Market Apartment", type = "apartment", price = 48000,
        exterior   = { x = 1968.60,  y = -1774.80, z = 13.55,  rotation = 90,  interior = 0 },
        interior   = { x = 265.20,   y = 303.50,   z = 999.15, rotation = 180, interior = 5 },
        garage     = { x = 1974.00,  y = -1774.80, z = 13.55,  radius = 10 },
        garage_int = { x = 1980.00,  y = -1774.80, z = 13.55,  rotation = 90 },
    },
    {
        id = 27, name = "Little Mexico Apartment", type = "apartment", price = 44000,
        exterior   = { x = 217.90,   y = -1789.50, z = 13.60,  rotation = 0,   interior = 0 },
        interior   = { x = 243.75,   y = 304.82,   z = 999.14, rotation = 180, interior = 1 },
        garage     = { x = 217.90,   y = -1783.00, z = 13.60,  radius = 9 },
        garage_int = { x = 217.90,   y = -1777.00, z = 13.60,  rotation = 0 },
    },
    {
        id = 28, name = "Verdant Bluffs Apartment", type = "apartment", price = 51000,
        exterior   = { x = 100.50,   y = -1505.00, z = 16.80,  rotation = 90,  interior = 0 },
        interior   = { x = 322.25,   y = 302.42,   z = 999.15, rotation = 0,   interior = 7 },
        garage     = { x = 106.50,   y = -1505.00, z = 16.80,  radius = 9 },
        garage_int = { x = 112.50,   y = -1505.00, z = 16.80,  rotation = 90 },
    },
    -- ═══ SAN FIERRO – HOUSES ══════════════════════════════
    {
        id = 4, name = "SF Ocean Condo", type = "house", price = 70000,
        exterior   = { x = -1800.21, y = 1200.58,  z = 25.12,  rotation = 180, interior = 0 },
        interior   = { x = 300.24,   y = 300.58,   z = 999.15, rotation = 0,   interior = 4 },
        garage     = { x = -1800.21, y = 1207.00,  z = 24.80,  radius = 11 },
        garage_int = { x = -1800.21, y = 1213.00,  z = 24.80,  rotation = 0 },
    },
    {
        id = 29, name = "Garcia House", type = "house", price = 58000,
        exterior   = { x = -1986.90, y = 327.20,   z = 35.00,  rotation = 180, interior = 0 },
        interior   = { x = 265.20,   y = 303.50,   z = 999.15, rotation = 0,   interior = 4 },
        garage     = { x = -1986.90, y = 333.50,   z = 35.00,  radius = 10 },
        garage_int = { x = -1986.90, y = 339.50,   z = 35.00,  rotation = 0 },
    },
    {
        id = 30, name = "Doherty House", type = "house", price = 53000,
        exterior   = { x = -1954.30, y = 219.40,   z = 34.90,  rotation = 90,  interior = 0 },
        interior   = { x = 295.00,   y = 310.00,   z = 999.15, rotation = 270, interior = 2 },
        garage     = { x = -1948.00, y = 219.40,   z = 34.90,  radius = 10 },
        garage_int = { x = -1942.00, y = 219.40,   z = 34.90,  rotation = 90 },
    },
    {
        id = 31, name = "Hashbury House", type = "house", price = 66000,
        exterior   = { x = -2236.80, y = 501.00,   z = 35.30,  rotation = 270, interior = 0 },
        interior   = { x = 243.75,   y = 304.82,   z = 999.14, rotation = 90,  interior = 1 },
        garage     = { x = -2243.00, y = 501.00,   z = 35.30,  radius = 10 },
        garage_int = { x = -2249.00, y = 501.00,   z = 35.30,  rotation = 270 },
    },
    -- ═══ SAN FIERRO – APARTMENTS ══════════════════════════
    {
        id = 12, name = "Calton Heights Apartment", type = "apartment", price = 65000,
        exterior   = { x = -2184.60, y = 646.00,   z = 35.47,  rotation = 0,   interior = 0 },
        interior   = { x = 321.00,   y = 305.00,   z = 999.15, rotation = 90,  interior = 6 },
        garage     = { x = -2184.60, y = 652.00,   z = 35.47,  radius = 10 },
        garage_int = { x = -2184.60, y = 658.00,   z = 35.47,  rotation = 0 },
    },
    {
        id = 32, name = "Chinatown Apartment", type = "apartment", price = 60000,
        exterior   = { x = -2237.80, y = 691.50,   z = 35.30,  rotation = 180, interior = 0 },
        interior   = { x = 265.00,   y = 303.00,   z = 999.15, rotation = 0,   interior = 8 },
        garage     = { x = -2237.80, y = 697.50,   z = 35.30,  radius = 9 },
        garage_int = { x = -2237.80, y = 703.50,   z = 35.30,  rotation = 0 },
    },
    -- ═══ TIERRA ROBADA / BAYSIDE ══════════════════════════
    {
        id = 5, name = "Tierra Robada House", type = "house", price = 55000,
        exterior   = { x = -1390.19, y = 2638.72,  z = 55.98,  rotation = 180, interior = 0 },
        interior   = { x = 322.25,   y = 302.42,   z = 999.15, rotation = 0,   interior = 5 },
        garage     = { x = -1390.19, y = 2645.00,  z = 55.80,  radius = 11 },
        garage_int = { x = -1390.19, y = 2651.00,  z = 55.80,  rotation = 0 },
    },
    {
        id = 33, name = "El Quebrados House", type = "house", price = 30000,
        exterior   = { x = -1308.50, y = 2688.20,  z = 55.50,  rotation = 0,   interior = 0 },
        interior   = { x = 322.25,   y = 302.42,   z = 999.15, rotation = 180, interior = 5 },
        garage     = { x = -1308.50, y = 2694.00,  z = 55.50,  radius = 9 },
        garage_int = { x = -1308.50, y = 2700.00,  z = 55.50,  rotation = 0 },
    },
    {
        id = 34, name = "Bayside Marina House", type = "house", price = 62000,
        exterior   = { x = -2052.40, y = 2304.80,  z = 16.80,  rotation = 90,  interior = 0 },
        interior   = { x = 300.24,   y = 300.58,   z = 999.15, rotation = 270, interior = 4 },
        garage     = { x = -2046.00, y = 2304.80,  z = 16.80,  radius = 10 },
        garage_int = { x = -2040.00, y = 2304.80,  z = 16.80,  rotation = 90 },
    },
    -- ═══ LAS VENTURAS – HOUSES ════════════════════════════
    {
        id = 6, name = "LV Boulevard House", type = "house", price = 78000,
        exterior   = { x = 2037.22,  y = 2721.81,  z = 11.29,  rotation = 0,   interior = 0 },
        interior   = { x = 343.74,   y = 305.03,   z = 999.15, rotation = 180, interior = 6 },
        garage     = { x = 2037.22,  y = 2728.00,  z = 10.90,  radius = 12 },
        garage_int = { x = 2037.22,  y = 2734.00,  z = 10.90,  rotation = 0 },
    },
    {
        id = 35, name = "Prickle Pine House", type = "house", price = 72000,
        exterior   = { x = 1378.40,  y = 2832.20,  z = 10.80,  rotation = 180, interior = 0 },
        interior   = { x = 265.20,   y = 303.50,   z = 999.15, rotation = 0,   interior = 4 },
        garage     = { x = 1378.40,  y = 2838.00,  z = 10.80,  radius = 10 },
        garage_int = { x = 1378.40,  y = 2844.00,  z = 10.80,  rotation = 0 },
    },
    {
        id = 36, name = "Whitewood Estates House", type = "house", price = 68000,
        exterior   = { x = 1013.50,  y = 2658.50,  z = 10.80,  rotation = 90,  interior = 0 },
        interior   = { x = 295.00,   y = 310.00,   z = 999.15, rotation = 270, interior = 2 },
        garage     = { x = 1019.00,  y = 2658.50,  z = 10.80,  radius = 10 },
        garage_int = { x = 1025.00,  y = 2658.50,  z = 10.80,  rotation = 90 },
    },
    {
        id = 37, name = "Julius Thruway House", type = "house", price = 65000,
        exterior   = { x = 2237.50,  y = 2578.50,  z = 10.80,  rotation = 270, interior = 0 },
        interior   = { x = 243.75,   y = 304.82,   z = 999.14, rotation = 90,  interior = 1 },
        garage     = { x = 2231.00,  y = 2578.50,  z = 10.80,  radius = 10 },
        garage_int = { x = 2225.00,  y = 2578.50,  z = 10.80,  rotation = 270 },
    },
    -- ═══ LAS VENTURAS – APARTMENTS ════════════════════════
    {
        id = 13, name = "The Strip Apartment", type = "apartment", price = 72000,
        exterior   = { x = 2536.90,  y = 2454.40,  z = 10.82,  rotation = 270, interior = 0 },
        interior   = { x = 265.00,   y = 303.00,   z = 999.15, rotation = 0,   interior = 8 },
        garage     = { x = 2530.00,  y = 2454.40,  z = 10.82,  radius = 10 },
        garage_int = { x = 2524.00,  y = 2454.40,  z = 10.82,  rotation = 270 },
    },
    {
        id = 14, name = "Redsands West Apartment", type = "apartment", price = 68000,
        exterior   = { x = 1458.50,  y = 2617.20,  z = 10.82,  rotation = 90,  interior = 0 },
        interior   = { x = 295.00,   y = 310.00,   z = 999.15, rotation = 180, interior = 9 },
        garage     = { x = 1464.00,  y = 2617.20,  z = 10.82,  radius = 10 },
        garage_int = { x = 1470.00,  y = 2617.20,  z = 10.82,  rotation = 90 },
    },
    {
        id = 38, name = "Redsands East Apartment", type = "apartment", price = 63000,
        exterior   = { x = 1905.40,  y = 2481.30,  z = 10.80,  rotation = 0,   interior = 0 },
        interior   = { x = 321.00,   y = 305.00,   z = 999.15, rotation = 180, interior = 6 },
        garage     = { x = 1905.40,  y = 2487.00,  z = 10.80,  radius = 9 },
        garage_int = { x = 1905.40,  y = 2493.00,  z = 10.80,  rotation = 0 },
    },
    -- ═══ RURAL / SMALL TOWNS ══════════════════════════════
    {
        id = 39, name = "Fort Carson House", type = "house", price = 25000,
        exterior   = { x = 338.80,   y = 1137.10,  z = 19.50,  rotation = 180, interior = 0 },
        interior   = { x = 265.20,   y = 303.50,   z = 999.15, rotation = 0,   interior = 4 },
        garage     = { x = 338.80,   y = 1143.00,  z = 19.50,  radius = 9 },
        garage_int = { x = 338.80,   y = 1149.00,  z = 19.50,  rotation = 0 },
    },
    {
        id = 40, name = "Palomino Creek House", type = "house", price = 28000,
        exterior   = { x = 1690.50,  y = -370.50,  z = 35.00,  rotation = 270, interior = 0 },
        interior   = { x = 295.00,   y = 310.00,   z = 999.15, rotation = 90,  interior = 2 },
        garage     = { x = 1684.00,  y = -370.50,  z = 35.00,  radius = 9 },
        garage_int = { x = 1678.00,  y = -370.50,  z = 35.00,  rotation = 270 },
    },
    {
        id = 41, name = "Blueberry House", type = "house", price = 22000,
        exterior   = { x = -3.80,    y = -193.50,  z = 3.20,   rotation = 0,   interior = 0 },
        interior   = { x = 243.75,   y = 304.82,   z = 999.14, rotation = 180, interior = 1 },
        garage     = { x = -3.80,    y = -187.00,  z = 3.20,   radius = 9 },
        garage_int = { x = -3.80,    y = -181.00,  z = 3.20,   rotation = 0 },
    },
    {
        id = 42, name = "Whetstone Cabin", type = "house", price = 18000,
        exterior   = { x = -2866.80, y = 1389.60,  z = 48.50,  rotation = 90,  interior = 0 },
        interior   = { x = 265.00,   y = 303.00,   z = 999.15, rotation = 270, interior = 8 },
        garage     = { x = -2860.00, y = 1389.60,  z = 48.50,  radius = 9 },
        garage_int = { x = -2854.00, y = 1389.60,  z = 48.50,  rotation = 90 },
    },
    {
        id = 43, name = "Montgomery House", type = "house", price = 26000,
        exterior   = { x = 1226.80,  y = 270.50,   z = 19.60,  rotation = 180, interior = 0 },
        interior   = { x = 295.00,   y = 310.00,   z = 999.15, rotation = 0,   interior = 9 },
        garage     = { x = 1226.80,  y = 276.50,   z = 19.60,  radius = 9 },
        garage_int = { x = 1226.80,  y = 282.50,   z = 19.60,  rotation = 0 },
    },
    {
        id = 44, name = "Dillimore House", type = "house", price = 20000,
        exterior   = { x = 783.70,   y = -477.40,  z = 25.30,  rotation = 0,   interior = 0 },
        interior   = { x = 265.20,   y = 303.50,   z = 999.15, rotation = 180, interior = 4 },
        garage     = { x = 783.70,   y = -471.00,  z = 25.30,  radius = 9 },
        garage_int = { x = 783.70,   y = -465.00,  z = 25.30,  rotation = 0 },
    },
}

-- ───────────────────────────────────────────────────────────────
-- STATE
-- ───────────────────────────────────────────────────────────────
local houses          = {}   -- id → house data table
local entryMarkers    = {}   -- marker element → house id  (exterior, yellow)
local exitMarkers     = {}   -- marker element → house id  (interior, orange)
local houseBlips      = {}   -- blip element   → house id

local previewTimers   = {}   -- player → preview expiration timer
local previewData     = {}   -- player → return location data

-- ───────────────────────────────────────────────────────────────
-- HELPERS
-- ───────────────────────────────────────────────────────────────
local function centralExecute(queryText, ...)
    return exports.database_manager:dbExecute(queryText, ...)
end

local function centralQuery(queryText, ...)
    return exports.database_manager:dbQuery(queryText, ...) or {}
end

local function formatMoney(amount)
    return "$" .. tostring(math.floor(tonumber(amount) or 0))
end

local function getAccountOwnerKey(player)
    return exports.database_manager:getPlayerOwnerKey(player, true)
end

local function getAccountNameFromOwnerKey(ownerKey)
    ownerKey = tostring(ownerKey or "")
    if ownerKey:sub(1, 8) == "account:" then
        return ownerKey:sub(9)
    end
    return nil
end

local function isVehiclesResourceRunning()
    local r = getResourceFromName("vehicles")
    return r and getResourceState(r) == "running"
end

local function isInventoryResourceRunning()
    local r = getResourceFromName("inventory")
    return r and getResourceState(r) == "running"
end

local function isGarageSystemRunning()
    local r = getResourceFromName("garage_system")
    return r and getResourceState(r) == "running"
end

local function pushGarageLockState(house)
    if not house or not isVehiclesResourceRunning() then return end
    exports.vehicles:setGarageVehiclesLocked(house.id, house.locked)
end

-- ───────────────────────────────────────────────────────────────
-- DATABASE SEED / LOAD
-- ───────────────────────────────────────────────────────────────
local function seedHouses()
    for _, def in ipairs(propertyDefinitions) do
        local dimension = 6000 + def.id
        centralExecute([[
            INSERT OR IGNORE INTO houses (
                id, name, price, property_type, owner_key, owner_account, locked,
                exterior_x, exterior_y, exterior_z, exterior_rot, exterior_interior,
                interior_x, interior_y, interior_z, interior_rot, interior_id, dimension,
                garage_x, garage_y, garage_z, garage_radius,
                garage_int_x, garage_int_y, garage_int_z, garage_int_rot
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]],
            def.id, def.name, def.price, def.type or "house",
            nil, nil, 1,
            def.exterior.x, def.exterior.y, def.exterior.z, def.exterior.rotation, def.exterior.interior,
            def.interior.x, def.interior.y, def.interior.z, def.interior.rotation, def.interior.interior,
            dimension,
            def.garage.x, def.garage.y, def.garage.z, def.garage.radius,
            def.garage_int.x, def.garage_int.y, def.garage_int.z, def.garage_int.rotation
        )

        centralExecute([[
            UPDATE houses SET
                name = ?, price = ?, property_type = ?,
                exterior_x = ?, exterior_y = ?, exterior_z = ?, exterior_rot = ?, exterior_interior = ?,
                interior_x = ?, interior_y = ?, interior_z = ?, interior_rot = ?, interior_id = ?,
                dimension = ?,
                garage_x = ?, garage_y = ?, garage_z = ?, garage_radius = ?,
                garage_int_x = ?, garage_int_y = ?, garage_int_z = ?, garage_int_rot = ?
            WHERE id = ?
        ]],
            def.name, def.price, def.type or "house",
            def.exterior.x, def.exterior.y, def.exterior.z, def.exterior.rotation, def.exterior.interior,
            def.interior.x, def.interior.y, def.interior.z, def.interior.rotation, def.interior.interior,
            dimension,
            def.garage.x, def.garage.y, def.garage.z, def.garage.radius,
            def.garage_int.x, def.garage_int.y, def.garage_int.z, def.garage_int.rotation,
            def.id
        )
    end
end

local function migrateLegacyHousing()
    local migrationName = "housing_legacy_v1"
    if exports.database_manager:isMigrationComplete(migrationName) then return end

    local legacyConnection = legacyDbConnect("sqlite", "housing.db")
    if not legacyConnection then
        exports.database_manager:markMigrationComplete(migrationName)
        return
    end

    local rows = legacyDbPoll(legacyDbQuery(legacyConnection, "SELECT id, owner, locked FROM houses"), -1) or {}
    for _, row in ipairs(rows) do
        local ownerKey = tostring(row.owner or "")
        local locked   = tonumber(row.locked) ~= 0 and 1 or 0

        if ownerKey == "" then
            ownerKey = nil
        else
            exports.database_manager:ensureOwnerRecord(ownerKey)
        end

        centralExecute(
            "UPDATE houses SET owner_key = ?, owner_account = ?, locked = ? WHERE id = ?",
            ownerKey,
            getAccountNameFromOwnerKey(ownerKey),
            locked,
            tonumber(row.id) or 0
        )
    end

    exports.database_manager:markMigrationComplete(migrationName)
end

local function loadHouses()
    houses = {}

    for _, row in ipairs(centralQuery("SELECT * FROM houses ORDER BY id ASC")) do
        local houseId = tonumber(row.id)
        local ex = tonumber(row.exterior_x) or 0
        local ey = tonumber(row.exterior_y) or 0
        
        -- Prevent ghost markers: skip loading orphaned coordinates (0, 0, 0)
        local hasOwner = row.owner_key and row.owner_key ~= ""
        if ex == 0 and ey == 0 and not hasOwner then
            -- We safely ignore this ghost property frame
        else
            houses[houseId] = {
                id            = houseId,
                name          = row.name,
                property_type = row.property_type or "house",
                price         = math.floor(tonumber(row.price) or 0),
                owner_key     = row.owner_key,
                owner_account = row.owner_account,
                locked        = tonumber(row.locked) ~= 0,
                exterior = {
                    x        = ex,
                    y        = ey,
                    z        = tonumber(row.exterior_z) or 0,
                    rotation = tonumber(row.exterior_rot) or 0,
                    interior = tonumber(row.exterior_interior) or 0,
                },
                interior = {
                    x        = tonumber(row.interior_x) or 0,
                    y        = tonumber(row.interior_y) or 0,
                    z        = tonumber(row.interior_z) or 0,
                    rotation = tonumber(row.interior_rot) or 0,
                    interior = tonumber(row.interior_id) or 0,
                },
                dimension = tonumber(row.dimension) or 0,
                garage = {
                    x      = tonumber(row.garage_x) or 0,
                    y      = tonumber(row.garage_y) or 0,
                    z      = tonumber(row.garage_z) or 0,
                    radius = tonumber(row.garage_radius) or 8,
                },
                garage_int = {
                    x        = tonumber(row.garage_int_x) or 0,
                    y        = tonumber(row.garage_int_y) or 0,
                    z        = tonumber(row.garage_int_z) or 0,
                    rotation = tonumber(row.garage_int_rot) or 0,
                },
            }
        end
    end
end

-- ───────────────────────────────────────────────────────────────
-- ELEMENT CREATION / CLEANUP
-- ───────────────────────────────────────────────────────────────
local function destroyHouseElements()
    for marker in pairs(entryMarkers) do
        if isElement(marker) then destroyElement(marker) end
    end
    for marker in pairs(exitMarkers) do
        if isElement(marker) then destroyElement(marker) end
    end
    for blip in pairs(houseBlips) do
        if isElement(blip) then destroyElement(blip) end
    end
    entryMarkers = {}
    exitMarkers  = {}
    houseBlips   = {}
end

-- Build a lookup of positions already covered by interiors.map entries
local function buildInteriorsCoverageMap()
    local covered = {}
    for _, el in ipairs(getElementsByType("interiorEntry")) do
        local ex = tonumber(getElementData(el, "posX")) or 0
        local ey = tonumber(getElementData(el, "posY")) or 0
        local ez = tonumber(getElementData(el, "posZ")) or 0
        covered[#covered + 1] = { x = ex, y = ey, z = ez }
    end
    return covered
end

local function isCoveredByInteriors(houseExt, covered)
    for _, pos in ipairs(covered) do
        if getDistanceBetweenPoints3D(houseExt.x, houseExt.y, houseExt.z,
                                      pos.x, pos.y, pos.z) <= 3 then
            return true
        end
    end
    return false
end

local function createHouseElements()
    destroyHouseElements()

    local covered = buildInteriorsCoverageMap()

    for _, house in pairs(houses) do
        local isApart = house.property_type == "apartment"

        -- ── Exterior yellow entry arrow ──────────────────────────────
        -- Only create if interiors.map doesn't already have a marker here.
        -- (Properties 1-6 are in interiors.map; new admin-added ones are not.)
        if not isCoveredByInteriors(house.exterior, covered) then
            local entryMarker = createMarker(
                house.exterior.x, house.exterior.y, house.exterior.z + 0.5,
                "arrow", 2.0, 255, 255, 0, 200
            )
            setElementInterior(entryMarker, house.exterior.interior)
            setElementDimension(entryMarker, 0)
            setElementData(entryMarker, "housing:houseId", house.id, false)
            setElementParent(entryMarker, resourceRoot)
            entryMarkers[entryMarker] = house.id
        end

        -- ── Interior exit marker (orange arrow, inside private dimension) ──
        local exitMarker = createMarker(
            house.interior.x, house.interior.y, house.interior.z - 1,
            "arrow", 1.2, 255, 140, 40, 160
        )
        setElementInterior(exitMarker, house.interior.interior)
        setElementDimension(exitMarker, house.dimension)
        setElementData(exitMarker, "housing:houseId", house.id, false)
        setElementParent(exitMarker, resourceRoot)
        exitMarkers[exitMarker] = house.id

        -- ── Map blip (house/apartment icon, shown on radar) ──
        local blipIcon      = isApart and 40 or 31
        local br, bg, bb    = isApart and 255 or 80, isApart and 160 or 200, isApart and 60 or 255
        local blip = createBlip(
            house.exterior.x, house.exterior.y, house.exterior.z,
            blipIcon, 1, br, bg, bb, 200, 0, 180
        )
        setElementInterior(blip, house.exterior.interior)
        setElementDimension(blip, 0)
        setElementParent(blip, resourceRoot)
        houseBlips[blip] = house.id
    end
end


-- ───────────────────────────────────────────────────────────────
-- ACCESS LOGIC
-- ───────────────────────────────────────────────────────────────
local function saveHouseOwnership(house)
    return centralExecute(
        "UPDATE houses SET owner_key = ?, owner_account = ?, locked = ? WHERE id = ?",
        house.owner_key, house.owner_account, house.locked and 1 or 0, house.id
    )
end

local function getNearbyExteriorHouse(player, maxDistance)
    maxDistance = maxDistance or 4
    if getElementInterior(player) ~= 0 or getElementDimension(player) ~= 0 then return nil end

    local px, py, pz = getElementPosition(player)
    for _, house in pairs(houses) do
        local dist = getDistanceBetweenPoints3D(px, py, pz, house.exterior.x, house.exterior.y, house.exterior.z)
        if dist <= maxDistance then return house end
    end
    return nil
end

local function getInteriorHouse(player)
    local dimension = getElementDimension(player)
    if dimension == 0 then return nil end

    for _, house in pairs(houses) do
        if house.dimension == dimension and house.interior.interior == getElementInterior(player) then
            return house
        end
    end
    return nil
end

local function isHouseOwner(player, house)
    local ownerKey = getAccountOwnerKey(player)
    return ownerKey and house and house.owner_key == ownerKey
end

local function hasKeyAccess(player, house)
    if isHouseOwner(player, house) then return true end
    local ownerKey = getAccountOwnerKey(player)
    if not ownerKey or not house then return false end
    return exports.database_manager:hasPropertyKeyAccess(house.id, ownerKey)
end

local function getOwnedHouseCount(player)
    local ownerKey = getAccountOwnerKey(player)
    if not ownerKey then return 0 end

    local row = centralQuery("SELECT COUNT(*) AS owned_total FROM houses WHERE owner_key = ?", ownerKey)[1]
    return row and math.floor(tonumber(row.owned_total) or 0) or 0
end

-- ───────────────────────────────────────────────────────────────
-- KEY ITEM GRANT / REVOKE
-- ───────────────────────────────────────────────────────────────
local function grantPropertyKeyItem(player, house)
    if not isInventoryResourceRunning() then return end
    -- item name encodes the property id: "property_key_N"
    local itemName = "property_key_" .. house.id
    exports.inventory:addInventoryItem(player, itemName, 1)
    outputChatBox(
        "Housing: you received a key for " .. house.name .. ". Check your inventory (I).",
        player, 120, 255, 180, true
    )
end

local function revokePropertyKeyItem(player, house)
    if not isInventoryResourceRunning() then return end
    local itemName = "property_key_" .. house.id
    exports.inventory:removeInventoryItem(player, itemName, 1)
end

-- ───────────────────────────────────────────────────────────────
-- UI HELPERS
-- ───────────────────────────────────────────────────────────────
local function hideHousePopupForPlayer(player)
    triggerClientEvent(player, "rp_ui:hideHousePopup", root)
end

local function buildHousePopupPayload(player, house)
    local ownerName   = "Available"
    if house.owner_key and house.owner_key ~= "" then
        ownerName = house.owner_account or house.owner_key
    end

    local ownedByPlayer = isHouseOwner(player, house)
    local hasKey        = hasKeyAccess(player, house)
    local canBuy        = not house.owner_key or house.owner_key == ""
    local canEnter      = canBuy or hasKey or not house.locked
    local canLock       = ownedByPlayer
    local canPark       = ownedByPlayer and isPedInVehicle(player) and getPedOccupiedVehicleSeat(player) == 0

    return {
        id           = house.id,
        name         = house.name,
        property_type = house.property_type,
        ownerName    = ownerName,
        price        = house.price,
        locked       = house.locked,
        canBuy       = canBuy,
        canEnter     = canEnter,
        canLock      = canLock,
        canPark      = canPark,
        position = {
            x         = house.exterior.x,
            y         = house.exterior.y,
            z         = house.exterior.z,
            radius    = 6,
            interior  = house.exterior.interior,
            dimension = 0,
        },
    }
end

local function showHousePopupForPlayer(player, house)
    if previewData[player] then return end -- Hide popup if previewing
    triggerClientEvent(player, "rp_ui:showHousePopup", root, buildHousePopupPayload(player, house))
end

local function movePlayerIntoHouse(player, house)
    hideHousePopupForPlayer(player)
    setElementInterior(player, house.interior.interior)
    setElementDimension(player, house.dimension)
    setElementPosition(player, house.interior.x, house.interior.y, house.interior.z)
    setPedRotation(player, house.interior.rotation)
    local label = house.property_type == "apartment" and "apartment" or "house"
    outputChatBox("Housing: entered " .. house.name .. " (" .. label .. ").", player, 120, 255, 120, true)
end

local function movePlayerOutOfHouse(player, house)
    hideHousePopupForPlayer(player)
    setElementInterior(player, house.exterior.interior)
    setElementDimension(player, 0)
    setElementPosition(player, house.exterior.x, house.exterior.y, house.exterior.z)
    setPedRotation(player, house.exterior.rotation)
    local label = house.property_type == "apartment" and "apartment" or "house"
    outputChatBox("Housing: exited " .. house.name .. " (" .. label .. ").", player, 120, 255, 120, true)
end

-- ───────────────────────────────────────────────────────────────
-- PREVIEW LOGIC
-- ───────────────────────────────────────────────────────────────
local function cleanUpPreview(player, warpBack)
    if isTimer(previewTimers[player]) then
        killTimer(previewTimers[player])
    end
    previewTimers[player] = nil

    if warpBack and previewData[player] then
        fadeCamera(player, false, 1.0)
        local data = previewData[player]
        setTimer(function()
            if not isElement(player) then return end
            setElementInterior(player, data.int)
            setElementDimension(player, data.dim)
            setElementPosition(player, data.x, data.y, data.z)
            setPedRotation(player, data.rot)
            fadeCamera(player, true, 1.0)
            outputChatBox("Housing: Preview ended.", player, 255, 180, 100, true)
        end, 1000, 1)
    end
    previewData[player] = nil
end

local function beginHousePreview(player, house)
    if previewData[player] then
        outputChatBox("Housing: You are already in preview mode.", player, 255, 80, 80, true)
        return
    end

    if house.owner_key and house.owner_key ~= "" then
        outputChatBox("Housing: You can only preview unowned houses.", player, 255, 80, 80, true)
        return
    end

    hideHousePopupForPlayer(player)
    
    local ex, ey, ez = getElementPosition(player)
    previewData[player] = {
        houseId = house.id,
        x = ex, y = ey, z = ez,
        int = getElementInterior(player),
        dim = getElementDimension(player),
        rot = getPedRotation(player)
    }

    local previewDimension = 90000 + math.random(1, 9999)

    fadeCamera(player, false, 1.0)
    setTimer(function()
        if not isElement(player) then return end
        setElementInterior(player, house.interior.interior)
        setElementDimension(player, previewDimension)
        setElementPosition(player, house.interior.x, house.interior.y, house.interior.z)
        setPedRotation(player, house.interior.rotation)
        fadeCamera(player, true, 1.0)
        
        outputChatBox("Housing: Previewing " .. house.name .. " for 60 seconds.", player, 120, 255, 255, true)
        
        previewTimers[player] = setTimer(cleanUpPreview, 60000, 1, player, true)
    end, 1000, 1)
end

local function showHouseInfo(player, house)
    if not house then
        hideHousePopupForPlayer(player)
        return
    end

    showHousePopupForPlayer(player, house)
    local label = house.property_type == "apartment" and "Apartment" or "House"

    if not house.owner_key or house.owner_key == "" then
        outputChatBox(
            "Housing: " .. label .. " \"" .. house.name .. "\" is for sale for " .. formatMoney(house.price) .. ". Use /buyhouse to purchase.",
            player, 120, 255, 120, true
        )
        return
    end

    if isHouseOwner(player, house) then
        local state = house.locked and "locked" or "unlocked"
        outputChatBox(
            "Housing: " .. label .. " \"" .. house.name .. "\" is yours (" .. state .. "). Commands: /enterhouse /lockhouse /sellhouse /sharekey <player> /revokekey <player>",
            player, 120, 255, 120, true
        )
        return
    end

    if hasKeyAccess(player, house) then
        outputChatBox("Housing: you have a shared key for " .. house.name .. ". Use /enterhouse.", player, 180, 255, 120, true)
        return
    end

    if house.locked then
        outputChatBox("Housing: " .. house.name .. " is owned and locked.", player, 255, 180, 120, true)
    else
        outputChatBox("Housing: " .. house.name .. " is owned but unlocked. Use /enterhouse.", player, 255, 220, 120, true)
    end
end

-- ───────────────────────────────────────────────────────────────
-- EXPORTED: garage system uses this to find the house linked to a garage zone
-- ───────────────────────────────────────────────────────────────
function getOwnedGarageHouseIdForPosition(ownerKey, x, y, z)
    ownerKey = tostring(ownerKey or "")
    x = tonumber(x)
    y = tonumber(y)
    z = tonumber(z)
    if ownerKey == "" or not x or not y or not z then return false end

    for _, house in pairs(houses) do
        if house.owner_key == ownerKey then
            local dist = getDistanceBetweenPoints3D(x, y, z, house.garage.x, house.garage.y, house.garage.z)
            if dist <= house.garage.radius then
                return house.id
            end
        end
    end
    return false
end

-- ───────────────────────────────────────────────────────────────
-- EXPORTED: returns full house data for a given id (used by garage_system)
-- ───────────────────────────────────────────────────────────────
function getHouseData(houseId)
    return houses[tonumber(houseId)] or false
end

-- ───────────────────────────────────────────────────────────────
-- EXPORTED: check if a key (ownerKey) is authorised for houseId
-- ───────────────────────────────────────────────────────────────
function checkHouseAccess(houseId, ownerKey)
    local house = houses[tonumber(houseId)]
    if not house then return false end
    ownerKey = tostring(ownerKey or "")
    if ownerKey == "" then return false end

    if house.owner_key == ownerKey then return true end
    return exports.database_manager:hasPropertyKeyAccess(houseId, ownerKey)
end

-- ───────────────────────────────────────────────────────────────
-- ENTER / BUY / SELL / LOCK HELPERS
-- ───────────────────────────────────────────────────────────────
local function getExteriorHouseForUiRequest(player, requestedHouseId)
    local house = getNearbyExteriorHouse(player, 5)
    if not house then return nil end
    if requestedHouseId and requestedHouseId ~= false and tonumber(requestedHouseId) ~= house.id then return nil end
    return house
end

local function getHouseForEnterRequest(player, requestedHouseId)
    local house = getInteriorHouse(player) or getNearbyExteriorHouse(player, 5)
    if not house then return nil end
    if requestedHouseId and requestedHouseId ~= false and tonumber(requestedHouseId) ~= house.id then return nil end
    return house
end

local function tryEnterHouse(player, house)
    if not house then
        outputChatBox("Housing: stand near a property pickup first.", player, 255, 80, 80, true)
        return false
    end

    if house.owner_key and house.owner_key ~= "" and house.locked and not hasKeyAccess(player, house) then
        outputChatBox("Housing: this property is locked. You need a key.", player, 255, 80, 80, true)
        return false
    end

    movePlayerIntoHouse(player, house)
    return true
end

local function tryBuyHouse(player, house)
    if previewData[player] then
        outputChatBox("Housing: you cannot buy properties while previewing.", player, 255, 80, 80, true)
        return false
    end

    if not house then
        outputChatBox("Housing: stand near a property pickup first.", player, 255, 80, 80, true)
        return false
    end

    if house.owner_key and house.owner_key ~= "" then
        outputChatBox("Housing: this property is already owned.", player, 255, 80, 80, true)
        return false
    end

    if getOwnedHouseCount(player) >= 3 then
        outputChatBox("Housing: you already own 3 properties (maximum).", player, 255, 80, 80, true)
        return false
    end

    if getPlayerMoney(player) < house.price then
        outputChatBox("Housing: you need " .. formatMoney(house.price) .. " to buy this property.", player, 255, 80, 80, true)
        return false
    end

    local ownerKey = exports.database_manager:ensurePlayerRecord(player, true)
    if not ownerKey then
        outputChatBox("Housing: you need to be logged into an account to buy.", player, 255, 80, 80, true)
        return false
    end

    takePlayerMoney(player, house.price)
    house.owner_key     = ownerKey
    house.owner_account = getAccountNameFromOwnerKey(ownerKey)
    house.locked        = true
    saveHouseOwnership(house)
    pushGarageLockState(house)

    -- Grant property key item to buyer
    grantPropertyKeyItem(player, house)

    local label = house.property_type == "apartment" and "apartment" or "house"
    outputChatBox(
        "Housing: you bought " .. house.name .. " (" .. label .. ") for " .. formatMoney(house.price) .. "!",
        player, 120, 255, 120, true
    )
    showHousePopupForPlayer(player, house)
    return true
end

local function tryToggleHouseLock(player, house)
    if previewData[player] then return false end

    if not house or not isHouseOwner(player, house) then
        outputChatBox("Housing: you must be at your property to lock/unlock.", player, 255, 80, 80, true)
        return false
    end

    house.locked = not house.locked
    saveHouseOwnership(house)
    pushGarageLockState(house)
    outputChatBox(
        "Housing: " .. house.name .. " is now " .. (house.locked and "locked" or "unlocked") .. ".",
        player, 120, 255, 120, true
    )
    showHousePopupForPlayer(player, house)
    return true
end

-- ───────────────────────────────────────────────────────────────
-- SHARED KEY COMMANDS
-- ───────────────────────────────────────────────────────────────
local function sanitizeName(playerName)
    return tostring(playerName or ""):gsub("#%x%x%x%x%x%x", "")
end

local function findPlayerByFragment(fragment)
    if not fragment or fragment == "" then return nil end
    fragment = fragment:lower()
    local partialMatch
    for _, p in ipairs(getElementsByType("player")) do
        local plain = sanitizeName(getPlayerName(p))
        local lower = plain:lower()
        if lower == fragment then return p end
        if not partialMatch and lower:find(fragment, 1, true) then
            partialMatch = p
        end
    end
    return partialMatch
end

addCommandHandler("sharekey", function(player, _, targetFragment)
    local house = getNearbyExteriorHouse(player, 4) or getInteriorHouse(player)
    if not house or not isHouseOwner(player, house) then
        outputChatBox("Housing: stand at your property to share a key.", player, 255, 80, 80, true)
        return
    end

    if not targetFragment then
        outputChatBox("Usage: /sharekey <player>", player, 255, 220, 120, true)
        return
    end

    local target = findPlayerByFragment(targetFragment)
    if not target then
        outputChatBox("Housing: player not found.", player, 255, 80, 80, true)
        return
    end

    if target == player then
        outputChatBox("Housing: you cannot share a key with yourself.", player, 255, 80, 80, true)
        return
    end

    local ownerKey      = getAccountOwnerKey(player)
    local targetOwnerKey = exports.database_manager:getPlayerOwnerKey(target, true)
    if not targetOwnerKey then
        outputChatBox("Housing: target player must be logged in.", player, 255, 80, 80, true)
        return
    end

    exports.database_manager:grantPropertyKey(house.id, targetOwnerKey, ownerKey)
    grantPropertyKeyItem(target, house)

    local targetName = sanitizeName(getPlayerName(target))
    outputChatBox("Housing: shared key for " .. house.name .. " with " .. targetName .. ".", player, 120, 255, 120, true)
    outputChatBox("Housing: " .. sanitizeName(getPlayerName(player)) .. " shared a key for " .. house.name .. " with you!", target, 120, 255, 180, true)
end)

addCommandHandler("revokekey", function(player, _, targetFragment)
    local house = getNearbyExteriorHouse(player, 4) or getInteriorHouse(player)
    if not house or not isHouseOwner(player, house) then
        outputChatBox("Housing: stand at your property to revoke a key.", player, 255, 80, 80, true)
        return
    end

    if not targetFragment then
        outputChatBox("Usage: /revokekey <player>", player, 255, 220, 120, true)
        return
    end

    local target = findPlayerByFragment(targetFragment)
    if not target then
        outputChatBox("Housing: player not found.", player, 255, 80, 80, true)
        return
    end

    local targetOwnerKey = exports.database_manager:getPlayerOwnerKey(target, true)
    if not targetOwnerKey then
        outputChatBox("Housing: target player must be logged in.", player, 255, 80, 80, true)
        return
    end

    exports.database_manager:revokePropertyKey(house.id, targetOwnerKey)
    revokePropertyKeyItem(target, house)

    local targetName = sanitizeName(getPlayerName(target))
    outputChatBox("Housing: revoked key for " .. house.name .. " from " .. targetName .. ".", player, 120, 255, 120, true)
    outputChatBox("Housing: your key for " .. house.name .. " was revoked.", target, 255, 180, 120, true)
end)

-- ───────────────────────────────────────────────────────────────
-- STANDARD COMMANDS
-- ───────────────────────────────────────────────────────────────
addCommandHandler("enterhouse", function(player)
    local house = getInteriorHouse(player)
    if house then
        movePlayerOutOfHouse(player, house)
        return
    end
    tryEnterHouse(player, getNearbyExteriorHouse(player, 4))
end)

addCommandHandler("buyhouse", function(player)
    tryBuyHouse(player, getNearbyExteriorHouse(player, 4))
end)

addCommandHandler("sellhouse", function(player)
    local house = getNearbyExteriorHouse(player, 4) or getInteriorHouse(player)
    if not house or not isHouseOwner(player, house) then
        outputChatBox("Housing: stand at your property to sell it.", player, 255, 80, 80, true)
        return
    end

    -- Revoke all shared keys and remove key items from owner
    centralExecute("DELETE FROM property_keys WHERE house_id = ?", house.id)
    revokePropertyKeyItem(player, house)

    local refund = math.floor(house.price * 0.7)
    givePlayerMoney(player, refund)
    house.owner_key     = nil
    house.owner_account = nil
    house.locked        = true
    saveHouseOwnership(house)

    if isVehiclesResourceRunning() then
        exports.vehicles:releaseHouseVehicles(house.id)
    end

    outputChatBox("Housing: sold " .. house.name .. " for " .. formatMoney(refund) .. " (70% refund).", player, 120, 255, 120, true)
end)

addCommandHandler("lockhouse", function(player)
    tryToggleHouseLock(player, getNearbyExteriorHouse(player, 4) or getInteriorHouse(player))
end)

addCommandHandler("myproperties", function(player)
    if previewData[player] then return end
    local ownerKey = getAccountOwnerKey(player)
    if not ownerKey then
        outputChatBox("Housing: you are not logged in.", player, 255, 80, 80, true)
        return
    end

    local owned = {}
    for _, house in pairs(houses) do
        if house.owner_key == ownerKey then
            owned[#owned + 1] = house.name .. " (" .. house.property_type .. ", " .. (house.locked and "locked" or "unlocked") .. ")"
        end
    end

    if #owned == 0 then
        outputChatBox("Housing: you do not own any properties.", player, 255, 220, 120, true)
    else
        outputChatBox("Housing: your properties: " .. table.concat(owned, " | "), player, 120, 255, 120, true)
    end
end)

addCommandHandler("previewhouse", function(player)
    local house = getNearbyExteriorHouse(player, 4)
    if not house then
        outputChatBox("Housing: you must be at an unowned property to preview it.", player, 255, 80, 80, true)
        return
    end
    beginHousePreview(player, house)
end)

-- ───────────────────────────────────────────────────────────────
-- EVENTS
-- ───────────────────────────────────────────────────────────────
addEventHandler("onResourceStart", resourceRoot, function()
    seedHouses()
    migrateLegacyHousing()
    loadHouses()
    -- Delay element creation 3s so interiors resource finishes loading first.
    -- interiors.map interiorEntry elements must exist for isCoveredByInteriors() to work.
    setTimer(createHouseElements, 3000, 1)
end)


-- Interior exit marker → warp player back outside
addEventHandler("onMarkerHit", resourceRoot, function(hitElement, matchingDimension)
    if not matchingDimension or getElementType(hitElement) ~= "player" then return end
    local player = hitElement

    -- Entry marker (exterior yellow arrow) → show popup
    local entryHouseId = entryMarkers[source]
    if entryHouseId then
        local house = houses[entryHouseId]
        if house and not previewData[player] then
            showHousePopupForPlayer(player, house)
            showHouseInfo(player, house)
        end
        return
    end

    -- Exit marker (interior orange arrow) → warp out
    local exitHouseId = exitMarkers[source]
    if exitHouseId then
        local house = houses[exitHouseId]
        if previewData[player] and previewData[player].houseId == exitHouseId then
            cleanUpPreview(player, true)
        elseif house then
            movePlayerOutOfHouse(player, house)
        end
    end
end)

addEventHandler("onPlayerQuit", root, function()
    cleanUpPreview(source, false)
end)


addEvent("housing:requestBuy", true)
addEventHandler("housing:requestBuy", root, function(requestedHouseId)
    tryBuyHouse(client, getExteriorHouseForUiRequest(client, requestedHouseId))
end)

addEvent("housing:requestEnter", true)
addEventHandler("housing:requestEnter", root, function(requestedHouseId)
    local house = getHouseForEnterRequest(client, requestedHouseId)
    if house and getInteriorHouse(client) == house then
        movePlayerOutOfHouse(client, house)
        return
    end
    tryEnterHouse(client, house)
end)

addEvent("housing:requestToggleLock", true)
addEventHandler("housing:requestToggleLock", root, function(requestedHouseId)
    tryToggleHouseLock(client, getExteriorHouseForUiRequest(client, requestedHouseId) or getInteriorHouse(client))
end)

