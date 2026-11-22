package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq
local ns = H.locale({ Start = function() end })
H.load("Core/Defaults.lua", ns)
H.load("Core/Presentation.lua", ns)
H.load("Core/Slash.lua", ns)
H.load("Model/RecipeKnowledge.lua", ns)
H.load("Model/Wording.lua", ns)
ns.Adapter = { Resolve = function() end }
local invalidations = 0
ns.Context = { Invalidate = function() invalidations = invalidations + 1 end,
    Classify = function() return { endgame = { { profession = "alchemy" } } } end }
H.load("UI/Toast.lua", ns)
local p = { toastOpacity = 0.37, toast = false, tooltip = true, colors = ns.defaults.profile.colors }
local current = "Default"
ns.addon = { db = { profile = p, global = { log = { "old" } }, GetCurrentProfile = function() return current end } }
local P, T = ns.Presentation, ns.Toast
local page, query, preview, confirm
local deps = { open = function(v) page = v end, find = function(v) query = v; return {} end,
    preview = function(v) preview = v end, clearLog = function() confirm = true end }
local function run(s) return ns.Slash.Run(s, deps) end
-- Get is strictly read-only, including an unmigrated legacy profile.
eq(run("get appearance.toast.text-opacity")[1], "appearance.toast.text-opacity = 37", "legacy effective value")
eq(p.toastTextOpacity, nil, "get does not migrate or write")
P.Migrate(p)
eq(p.toastBackgroundOpacity, 0.37, "background migration")
eq(p.toastTextOpacity, 0.37, "ink migration")
eq(p.toast, false, "migration does not enable toast")
p.toastTextOpacity = 0.2; P.Migrate(p)
eq(p.toastTextOpacity, 0.2, "migration does not overwrite new settings")
for _, s in ipairs({ "set toast", "set toast yes", "set toast on surplus", "get toast surplus",
    "set arbitrary.path on", "set appearance.toast.scale 49", "set appearance.toast.scale 201",
    "set appearance.toast.scale 100.5", "set appearance.toast.scale nan", "set appearance.toast.background-opacity -1",
    "set appearance.toast.text-opacity 101", "set" }) do
    local n = invalidations; run(s); eq(invalidations, n, "invalid input never refreshes: " .. s)
    eq(p.toast, false, "invalid input never writes: " .. s)
end
eq(#run("set ToAsT ON"), 1, "one acknowledgement")
eq(run("get toast")[1], "toast = on", "case insensitive key and enum")
eq(p.toast, true, "primary key persisted")
run("set toast off"); eq(p.toast, false, "false boolean is preserved")
run("settings ApPeArAnCe"); eq(page, "appearance", "case insensitive page")
run("settings unknown"); eq(page, "appearance", "unknown page does not navigate")
run("settings"); eq(page, "home", "settings defaults home")
run("find ArcANite Bar"); eq(query, "ArcANite Bar", "search case preserved")
run("preview tint"); eq(preview, "tint", "focused preview")
run("preview bogus"); eq(preview, "tint", "invalid preview no action")
run("log clear trailing"); eq(confirm, nil, "surplus log argument no action")
run("log clear"); eq(confirm, true, "clear requests confirmation")
eq(run("help appearance")[1]:find("appearance.toast.scale", 1, true) ~= nil, true, "targeted keys")
eq(run("status")[1], "Shared settings", "status includes scope")
eq(run("get stock.reminder")[1], "stock.reminder = on", "stock.reminder defaults on")
eq(run("set stock.reminder off")[1], "stock.reminder = off", "stock.reminder set")
eq(p.stockReminder, false, "the profile value changes")
eq(run("get stock.reminder")[1], "stock.reminder = off", "get reads back what set wrote")
run("set stock.reminder on"); eq(p.stockReminder, true, "and back on")
eq(run("set stock.reminder maybe")[1], "Usage: /kt set stock.reminder on|off", "bad value rejected")
eq(run("help appearance")[1]:find("stock.reminder (on|off)", 1, true) ~= nil, true, "help lists stock.reminder")
current = "Me - Realm"; eq(P.Scope(), "This character", "character scope")
-- Move uses a separate tentative value and refuses a different profile at commit.
eq(T.BeginMove(), true, "move starts")
T.TentativePosition("CENTER", 100, 200)
eq(p.toastPosition, nil, "drag does not save")
T.CancelMove(); eq(p.toastPosition, nil, "cancel restores persisted anchor")
T.BeginMove(); T.TentativePosition("CENTER", 100.4, 200.6); T.DoneMove()
eq(p.toastPosition.y, 201, "done saves rounded coordinates")
T.BeginMove(); T.TentativePosition("TOP", 9, 8)
P.Set("appearance.toast.locked", "on")
eq(T.move, nil, "locking cancels move")
eq(T.BeginMove(), false, "locked move refused")
T.SavePosition("TOP", 9, 8); eq(p.toastPosition.y, 201, "locked direct save refused")
T.ResetPosition(); eq(p.toastPosition.y, 201, "locked reset refused")
P.Set("appearance.toast.locked", "off")
T.BeginMove(); T.TentativePosition("TOP", 9, 8)
local other = { toastOpacity = 0.8 }
ns.addon.db.profile = other
eq(T.DoneMove(), false, "cross-profile commit refused")
eq(other.toastPosition, nil, "tentative coordinates never leak into new scope")
ns.addon.db.profile = p
T.ResetPosition(); eq(p.toastPosition.y, -140, "reset position")
eq(p.toastTextOpacity, 0.2, "reset retains appearance")
-- Demos and live pickups use independent entries, queues and deduplication.
T.factory = function()
    return { Set = function() end, Place = function() end, SetAlpha = function() end, Show = function() end, Hide = function() end }
end
p.toast = true; T.Handle(12360, 2)
local live, seen = T.active[1], T.seen
T.Demo(); T.Demo()
eq(#T.samples, 3, "repeat replaces samples")
eq(T.active[1], live, "demo retains live entry")
eq(T.seen, seen, "demo retains dedup map")
T.Handle(12360, 3); eq(live.count, 5, "real loot combines only with live entry")
eq(T.samples[1].count, 1, "sample count remains synthetic")
T.Tick(5); eq(#T.samples, 0, "samples expire")
H.load("Debug/Log.lua", ns)
ns.Log.failures = { { area = "test", message = "x" } }; ns.Log.Clear()
eq(#ns.addon.db.global.log, 0, "clear diagnostics")
eq(p.toast, true, "clear retains gameplay settings")
eq(p.toastTextOpacity, 0.2, "clear retains appearance")
-- UI and CLI share the same registry, normalization and refresh.
H.load("Options/Options.lua", ns)
local notices = 0
ns.Options.NotifyChange = function() notices = notices + 1 end
local appearance = ns.Options.Appearance(4)
run("set appearance.toast.text-opacity 80")
eq(appearance.args.textOpacity.get(), 80, "CLI updates UI getter")
appearance.args.textOpacity.set(nil, 25)
eq(run("get appearance.toast.text-opacity")[1], "appearance.toast.text-opacity = 25", "UI uses CLI validator and units")
eq(notices, 2, "both setters notify open UI")
p.toast = false
eq(appearance.args.textOpacity.disabled(), true, "dependent appearance disabled")
eq(appearance.args.textOpacity.get(), 25, "disabled controls retain values")
eq(ns.Options.Home(1).args.toastMove, nil, "movement relocated off Home")
-- Native confirmation cancellation and acceptance, with no gameplay writes.
H.load("Core/Adapter.lua", ns)
ns.Adapter.env = { StaticPopupDialogs = {}, StaticPopup_Show = function() return {} end }
ns.addon.db.global.log = { "keep" }
ns.Adapter.ConfirmClearLog(ns.Log.Clear)
local popup = ns.Adapter.env.StaticPopupDialogs.KEEPTHAT_CLEAR_LOG
eq(popup.hideOnEscape, true, "confirmation supports Escape cancellation")
eq(#ns.addon.db.global.log, 1, "requesting confirmation leaves log intact")
popup.OnAccept()
eq(#ns.addon.db.global.log, 0, "explicit accept clears log")
eq(p.toastTextOpacity, 0.25, "confirmation never clears settings")
-- Render contract with actual drawing code and measured synthetic text heights.
local made = {}
local function node(kind)
    local n = { kind = kind, scripts = {} }; made[#made + 1] = n
    function n:SetSize(w, h) self.width, self.height = w, h end
    function n:SetWidth(w) self.width = w end
    function n:SetHeight(h) self.height = h end
    function n:GetHeight() return self.height end
    function n:SetAlpha(a) self.alpha = a end
    function n:SetScale(v) self.scale = v end
    function n:SetText(v) self.text = v end
    function n:SetTexture(v) self.texture = v end
    function n:SetColorTexture(r, g, b, a) self.r, self.g, self.b, self.a = r, g, b, a end
    function n:GetStringHeight() return math.ceil(#(self.text or "") / 30) * 12 end
    function n:SetScript(k, fn) self.scripts[k] = fn end
    function n:SetPoint(point, parent, relative, x, y) self.point, self.x, self.y = point, x, y end
    function n:GetPoint() return self.point, nil, self.point, self.x, self.y end
    function n:Show() self.shown = true end
    function n:Hide() self.shown = false end
    function n:IsShown() return self.shown end
    function n:CreateTexture() return node("texture") end
    function n:CreateFontString() return node("font") end
    for _, k in ipairs({ "SetFrameStrata", "SetAllPoints", "SetTexCoord", "SetJustifyH", "SetWordWrap", "SetTextColor",
        "ClearAllPoints", "EnableMouse", "SetMovable", "SetClampedToScreen", "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "EnableKeyboard", "SetPropagateKeyboardInput" }) do
        n[k] = function() end
    end
    return n
end
ns.Adapter.env = { CreateFrame = function(kind) return node(kind) end, UIParent = {} }
H.load("UI/Toast.lua", ns); T = ns.Toast
p.toastBackgroundOpacity, p.toastTextOpacity, p.toastScale = 0, 0.8, 1.5
local f = T.factory()
f:Set(nil, string.rep("Long localized title ", 8), string.rep("Endgame recommendation ", 10), p.colors.endgame)
eq(made[1].height > 40, true, "long copy grows frame")
eq(made[2].alpha, 0, "zero background alpha")
eq(made[3].alpha, 0, "zero accent alpha")
eq(made[4].alpha, 0.8, "new icon follows independent ink")
eq(made[4].texture, 134400, "missing icon fallback")
eq(made[5].alpha, 0.8, "new title follows independent ink")
eq(made[1].scale, 1.5, "scale applies to frame")
p.toastBackgroundOpacity = 1; p.toastTextOpacity = 0.25
f:SetAlpha(0.5)
eq(made[1].alpha, 0.5, "lifetime fade is separate")
eq(made[2].alpha, 1, "background refresh applies")
eq(made[5].alpha, 0.25, "existing text refresh applies")
local anchor = p.toastPosition
T.ShowMover()
local mover
for _, n in ipairs(made) do if n.scripts.OnKeyDown then mover = n end end
eq(mover ~= nil, true, "mover has Escape handler")
T.TentativePosition("TOP", 2, 3)
mover.scripts.OnKeyDown(mover, "ESCAPE")
eq(T.move, nil, "Escape cancels transaction")
eq(p.toastPosition, anchor, "Escape keeps persisted anchor")
T.ShowMover(); mover:SetPoint("TOP", nil, "TOP", 8, -70)
mover.scripts.OnDragStop(mover)
eq(p.toastPosition, anchor, "real drag-stop does not save")
T.DoneMove(); eq(p.toastPosition.y, -70, "Done commits measured frame point")
H.done()
