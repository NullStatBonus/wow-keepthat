package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq
local ns = H.locale({ Start = function() end })
H.load("Core/Adapter.lua", ns)
H.load("Core/Adapter_Tooltip.lua", ns)
H.load("Model/Leveling.lua", ns)
H.load("Model/Classify.lua", ns)
H.load("Model/Wording.lua", ns)
local catalog = { itemNames = { [100] = "Real Bar", [200] = "Real Cloth" },
    spellNames = { [10] = "Real Recipe" },
    endgame = { [100] = { blacksmithing = { "Used for gear", "Guide", 0 } } },
    recipes = { [10] = { p = "blacksmithing", learn = 40, r = { 100, 5 } } } }
local routes = { guides = { { name = "Real guide" } }, materials = {
    blacksmithing = { [100] = { 1, 25, 50, 40, 45, 0 } }, tailoring = { [200] = { 1, 1, 40, 30, 30, 0 } } } }
local p = { tooltip = false, endgame = false, leveling = false, disabled = { endgame = { [100] = true } },
    colors = { endgame = { r = 0.6, g = 0.2, b = 0.9 }, leveling = { r = 0.1, g = 1, b = 0 } } }
ns.addon = { db = { profile = p } }
local productionCalls = 0
ns.Context = { Get = function() return { catalog = catalog, routes = routes } end,
    Classify = function() productionCalls = productionCalls + 1; error("preview must not call production classification") end }
H.load("UI/Tooltip.lua", ns)
local sample = ns.Tooltip.Sample(function(n) eq(n, 2, "random selects union without duplicate items"); return 1 end)
eq(sample.itemID, 100, "actual catalog item chosen")
eq(sample.name, "Real Bar", "actual material name")
eq(sample.result.endgame[1].profession, "blacksmithing", "real endgame profession")
eq(sample.result.leveling[1].need.from, 25, "sample skill matches real route")
eq(sample.result.leveling[1].need.low, 40, "realistic route count")
eq(ns.Tooltip.Sample(function() return 2 end).itemID, 200, "random can select leveling-only materials")
eq(p.tooltip, false, "sample leaves disabled feature off")
eq(p.disabled.endgame[100], true, "sample leaves material override intact")
local shift, cached, nativeCalls = false, true, 0
local tip = { lines = {}, scripts = {} }
function tip:AddLine(text, r, g, b) self.lines[#self.lines + 1] = { text = text, r = r, g = g, b = b } end
function tip:ClearLines() self.lines = {} end
function tip:SetOwner() end
function tip:Show() self.shown = true end
function tip:Hide() self.shown = false end
function tip:IsShown() return self.shown end
function tip:SetScript(k, fn) self.scripts[k] = fn end
function tip:SetItemByID(id)
    nativeCalls = nativeCalls + 1
    self:AddLine("Real Bar", 0, 1, 0)
    self:AddLine("Native item description", 1, 1, 1)
    ns.Tooltip.OnItem(self, id) -- simulate global item tooltip hook
end
ns.Adapter.env = { CreateFrame = function() return tip end, UIParent = {},
    GetItemInfo = function(id) if cached then return catalog.itemNames[id] end end,
    IsShiftKeyDown = function() return shift end,
    GetItemCount = function() error("preview must not read real bag counts") end }
-- Make selection deterministic without changing the runtime RNG.
local originalSample = ns.Tooltip.Sample
ns.Tooltip.Sample = function() return sample end
eq(ns.Tooltip.Preview(), true, "preview works with real feature disabled")
eq(nativeCalls, 1, "native item tooltip populated")
eq(tip.lines[1].g, 1, "native quality ink retained")
eq(tip.lines[2].text, "Native item description", "native item content retained")
eq(tip.lines[3].text:find("Shift", 1, true) ~= nil, true, "same collapsed Shift hint as live")
eq(tip.lines[4].text, "Preview — sample profession skills and bag counts", "sample data clearly labeled")
p.tooltip = true
ns.Tooltip.Preview()
eq(productionCalls, 0, "private tooltip bypasses production hooks even with feature on")
shift = true; tip.scripts.OnUpdate(tip, 0.1)
local previewRows = {}
for i = 3, #tip.lines - 1 do previewRows[#previewRows + 1] = tip.lines[i] end
local text = {}; for _, row in ipairs(previewRows) do text[#text + 1] = row.text end
local all = table.concat(text, "\n")
eq(all:find("Real Recipe - 5 per craft", 1, true) ~= nil, true, "real recipe rendered")
eq(all:find("40-45 needed, 12 in bags", 1, true) ~= nil, true, "dummy bag count and real route need rendered")
eq(all:find("Real guide", 1, true) ~= nil, true, "real guide rendered")
-- Exact live/preview row and color parity, apart from native item content and explicit sample label.
local live = { lines = {} }; live.AddLine = tip.AddLine
ns.Adapter.env.GetItemCount = function() return 12 end
ns.Tooltip.Draw(live, sample.itemID, sample.result, true)
eq(#live.lines, #previewRows, "same live and preview row count")
for i, row in ipairs(live.lines) do
    for _, k in ipairs({ "text", "r", "g", "b" }) do eq(previewRows[i][k], row[k], "live/preview parity " .. i .. " " .. k) end
end
cached = false; ns.Tooltip.Preview()
eq(tip.lines[1].text, "Real Bar", "uncached item uses real catalog name")
local before = nativeCalls; cached = true; tip.scripts.OnUpdate(tip, 0.1)
eq(nativeCalls, before + 1, "native tooltip restored when item cache arrives")
ns.Tooltip.Preview(); tip.scripts.OnUpdate(tip, 14)
eq(tip.shown, true, "repeating restarts lifetime")
tip.scripts.OnUpdate(tip, 1.1); eq(tip.shown, false, "sample expires")
ns.Tooltip.Sample = originalSample
ns.Context.Get = function() return {} end
eq(ns.Tooltip.Preview(), false, "empty catalog fails safely")
H.done()
