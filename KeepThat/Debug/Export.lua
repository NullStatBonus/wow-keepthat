-- A window with a read-only, selectable text box, so reports can be copied (Ctrl+A, Ctrl+C).
-- Uses AceGUI's standard Frame and MultiLineEditBox.
local _, ns = ...
local L = ns.L

local Export = {}
ns.Export = Export

local window

function Export.Show(title, text)
    local AceGUI = LibStub("AceGUI-3.0")
    if window then window:Release() end
    window = AceGUI:Create("Frame")
    window:SetTitle(title)
    window:SetStatusText(L["Press Ctrl+A to select everything, then Ctrl+C to copy."])
    window:SetLayout("Fill")
    window:SetCallback("OnClose", function(w) AceGUI:Release(w); window = nil end)
    local box = AceGUI:Create("MultiLineEditBox")
    box:SetLabel("")
    box:DisableButton(true)
    box:SetText(text)
    box:SetCallback("OnTextChanged", function(b) b:SetText(text) end)
    window:AddChild(box)
    box:SetFocus()
    box:HighlightText()
end
