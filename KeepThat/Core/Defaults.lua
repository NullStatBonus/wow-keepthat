-- Saved settings and their defaults (spec settings, "Defaults"; design D8). AceDB fills in missing keys,
-- so a setting added later starts at its default. Material toggles store only what the player turned
-- off, so materials added in an update start on.
local _, ns = ...

ns.defaults = {
    profile = {
        endgame = true,          -- mark endgame materials
        leveling = false,        -- mark leveling materials
        tooltip = true,          -- the tooltip line (the main feature)
        toast = false,           -- loot toast
        toastPosition = { point = "TOP", x = 0, y = -140 },
        toastOpacity = 1,        -- legacy alpha, migrated independently into background/text alpha
        toastScale = 1,
        toastLocked = false,
        maskOpacity = 0.4,       -- icon tint strength (OLED: dimmable)  -- where the first toast shows; more stack below
        mask = false,            -- icon tint
        colors = {
            endgame = { r = 0.64, g = 0.21, b = 0.93 },   -- purple (epic quality color)
            leveling = { r = 0.12, g = 1.00, b = 0.00 },  -- green (uncommon quality color)
        },
        -- Where the icon tint shows ("Show marks in"); all on by default. The merchant covers its buyback tab.
        locations = { bags = true, bank = true, merchant = true },
        disabled = { endgame = {}, leveling = {} },       -- [itemID] = true for materials turned off
        integrations = { baganator = true, bagnon = true, ellesmereui = true, auctionator = true, professionjournal = true },
        debug = false,
    },
    global = {
        log = {},                -- debug log lines (Debug/Log.lua)
    },
}
