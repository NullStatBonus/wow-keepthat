-- The copy window shows the report in a read-only, selected text box, and a second report
-- replaces the first window instead of stacking a new one on top.
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local S = require("stubs")
local eq = H.eq

-- A fake AceGUI that records what Export builds.
local made, released = {}, {}
local function widget(kind)
    local w = { kind = kind, callbacks = {}, children = {} }
    function w:SetTitle(t) self.title = t end
    function w:SetStatusText(t) self.status = t end
    function w:SetLayout(l) self.layout = l end
    function w:SetCallback(name, fn) self.callbacks[name] = fn end
    function w:AddChild(c) self.children[#self.children + 1] = c end
    function w:Release() released[#released + 1] = self end
    function w:SetLabel(l) self.label = l end
    function w:DisableButton(b) self.buttonOff = b end
    function w:SetText(t) self.text = t end
    function w:SetFocus() self.focused = true end
    function w:HighlightText(from, to) self.highlighted = { from, to } end
    made[#made + 1] = w
    return w
end
local AceGUI = {
    Create = function(_, kind) return widget(kind) end,
    Release = function(_, w) released[#released + 1] = w end,
}
S.install({ LibStub = function(name) assert(name == "AceGUI-3.0"); return AceGUI end })

local ns = {}
H.locale(ns)
H.load("Debug/Export.lua", ns)

ns.Export.Show("KeepThat log", "line one\nline two")
local frame, box = made[1], made[2]
eq(frame.kind, "Frame", "window is an AceGUI Frame")
eq(frame.title, "KeepThat log", "window title")
eq(frame.status, ns.L["Press Ctrl+A to select everything, then Ctrl+C to copy."], "copy hint in the status bar")
eq(box.kind, "MultiLineEditBox", "text box")
eq(frame.children[1], box, "text box is inside the window")
eq(box.text, "line one\nline two", "report text shown")
eq(box.buttonOff, true, "no Accept button")
eq(box.focused, true, "text box focused")
-- HighlightText() with no range selects everything; (0, 0) would clear the selection.
eq(box.highlighted and box.highlighted[1], nil, "whole report selected for Ctrl+C (no start)")
eq(box.highlighted and box.highlighted[2], nil, "whole report selected for Ctrl+C (no end)")

-- Typing in the box puts the report back (read-only).
box.text = "edited"
box.callbacks.OnTextChanged(box)
eq(box.text, "line one\nline two", "edits are undone")

-- A second report releases the first window.
ns.Export.Show("Probe", "other")
eq(released[1], frame, "first window released")
eq(made[4].text, "other", "second report shown")

-- Closing releases the window, and the next report does not release it again.
local second = made[3]
second.callbacks.OnClose(second)
eq(released[2], second, "closed window released")
ns.Export.Show("Again", "x")
eq(#released, 2, "a closed window is not released twice")

S.restore()
H.done()
