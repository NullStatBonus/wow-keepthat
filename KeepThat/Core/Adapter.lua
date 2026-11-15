-- The only place game functions are called. Every read is guarded and in pcall; a missing
-- function or an error gives nil. Feature modules call these instead of game globals, and
-- tests replace ns.Adapter.env with a fake table.
local _, ns = ...

local A = { env = _G }
ns.Adapter = A

-- Resolves "C_Container.GetContainerItemID" (or a plain global name) in env; nil when missing.
function A.Resolve(path, env)
    local t = env or A.env
    for part in path:gmatch("[^%.]+") do
        if type(t) ~= "table" then return nil end
        local ok, v = pcall(function() return t[part] end)
        if not ok then return nil end
        t = v
    end
    return t
end

-- True when path names a function the client provides.
function A.Has(path, env)
    return type(A.Resolve(path, env)) == "function"
end

-- Calls the function at path; returns its results, or nil when it is missing or errors.
function A.Call(path, ...)
    local f = A.Resolve(path)
    if type(f) ~= "function" then return nil end
    local res = { pcall(f, ...) }
    if not res[1] then return nil end
    return unpack(res, 2, table.maxn(res))
end

-- Profession name keys by skill line ID (the same on both clients).
A.SKILL_LINES = {
    [171] = "alchemy", [164] = "blacksmithing", [333] = "enchanting", [202] = "engineering",
    [165] = "leatherworking", [197] = "tailoring", [185] = "cooking", [129] = "firstaid", [186] = "mining",
}

-- Known professions and their ranks: { [profession] = rank }. Forever has C_SkillInfo (with skill line
-- IDs); Classic Era has the GetSkillLineInfo globals, which give only localized names, so those are
-- matched against the localized names of the same skill lines.
function A.ProfessionSkills()
    local out = {}
    local byID = A.Resolve("C_SkillInfo.GetSkillLineInfoByID")
    if type(byID) == "function" then
        for id, key in pairs(A.SKILL_LINES) do
            local ok, info = pcall(byID, id)
            local rank = ok and type(info) == "table" and (info.skillLineRank or info.rank) or nil
            if type(rank) == "number" and rank > 0 then out[key] = rank end
        end
        if next(out) then return out end
    end
    local num = A.Resolve("C_SkillInfo.GetNumSkillLines") or A.Resolve("GetNumSkillLines")
    local info = A.Resolve("C_SkillInfo.GetSkillLineInfo") or A.Resolve("GetSkillLineInfo")
    if type(num) ~= "function" or type(info) ~= "function" then return out end
    local names = A.SkillLineNames()
    local ok, n = pcall(num)
    if not ok or type(n) ~= "number" then return out end
    for i = 1, n do
        local okLine, name, isHeader, _, rank = pcall(info, i)
        if okLine and type(name) == "table" then -- C_SkillInfo returns a table
            name, isHeader, rank = name.skillLineName or name.name, name.isHeader, name.skillLineRank or name.rank
        end
        local key = okLine and not isHeader and names[name]
        if key and type(rank) == "number" then out[key] = rank end
    end
    return out
end

-- The apprentice spell of each profession; its spell name is the profession's localized name on both
-- clients (GetSpellInfo / C_Spell.GetSpellName), which is what Era's GetSkillLineInfo returns.
A.PROFESSION_SPELLS = {
    alchemy = 2259, blacksmithing = 2018, enchanting = 7411, engineering = 4036, leatherworking = 2108,
    tailoring = 3908, cooking = 2550, firstaid = 3273, mining = 2575,
}

-- Localized profession name -> key. English names always work; the client's own names are added from
-- its trade skill display names (Forever) or the profession spells' names (both clients).
function A.SkillLineNames()
    local out = {
        Alchemy = "alchemy", Blacksmithing = "blacksmithing", Enchanting = "enchanting", Engineering = "engineering",
        Leatherworking = "leatherworking", Tailoring = "tailoring", Cooking = "cooking", ["First Aid"] = "firstaid",
        Mining = "mining",
    }
    local display = A.Resolve("C_TradeSkillUI.GetTradeSkillDisplayName")
    if type(display) == "function" then
        for id, key in pairs(A.SKILL_LINES) do
            local ok, name = pcall(display, id)
            if ok and type(name) == "string" and name ~= "" then out[name] = key end
        end
    end
    local spellName = A.Resolve("C_Spell.GetSpellName") or A.Resolve("GetSpellInfo")
    if type(spellName) == "function" then
        for key, spell in pairs(A.PROFESSION_SPELLS) do
            local ok, name = pcall(spellName, spell)
            if ok and type(name) == "string" and name ~= "" then out[name] = key end
        end
    end
    return out
end

-- The client's localized profession names: { [profession] = name }, from the trade skill display names
-- (Forever) or the profession spells' names (both clients). Missing names are left out.
function A.ProfessionDisplayNames()
    local out = {}
    local display = A.Resolve("C_TradeSkillUI.GetTradeSkillDisplayName")
    if type(display) == "function" then
        for id, key in pairs(A.SKILL_LINES) do
            local ok, name = pcall(display, id)
            if ok and type(name) == "string" and name ~= "" then out[key] = name end
        end
    end
    local spellName = A.Resolve("C_Spell.GetSpellName") or A.Resolve("GetSpellInfo")
    if type(spellName) == "function" then
        for key, spell in pairs(A.PROFESSION_SPELLS) do
            if not out[key] then
                local ok, name = pcall(spellName, spell)
                if ok and type(name) == "string" and name ~= "" then out[key] = name end
            end
        end
    end
    return out
end


-- A small dialog with the text selected in an edit box, ready for Ctrl+C (the game's StaticPopup with
-- an edit box, the standard pattern for copying a link). Escape or Enter closes it.
local COPY = "KEEPTHAT_COPY_LINK"
local function copyEditBox(dialog)
    return dialog and (dialog.editBox or dialog.EditBox or (dialog.GetEditBox and dialog:GetEditBox()))
end

-- title: the popup's first line; a grey "Press Ctrl+C to copy." line is added under it.
function A.ShowCopyBox(title, text)
    local dialogs = A.Resolve("StaticPopupDialogs")
    local show = A.Resolve("StaticPopup_Show")
    if type(dialogs) ~= "table" or type(show) ~= "function" then return false end
    if not dialogs[COPY] then
        dialogs[COPY] = {
            text = "%s", button1 = A.Resolve("CLOSE") or "Close",
            hasEditBox = true, editBoxWidth = 350,
            timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
            OnShow = function(dialog, data)
                local box = copyEditBox(dialog)
                if box then
                    box:SetText(data or "")
                    box:SetFocus()
                    box:HighlightText()
                end
            end,
            OnHide = function(dialog)
                local box = copyEditBox(dialog)
                if box then box:ClearFocus() end
            end,
            EditBoxOnEnterPressed = function(box) box:GetParent():Hide() end,
            EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
            -- An accidental edit would change the link: put it back, selected again. Our own SetText
            -- leaves the text equal, so this only acts on a real edit. (StaticPopup passes the dialog's
            -- data as the second argument, not a user-input flag.)
            EditBoxOnTextChanged = function(box)
                local dialog = box:GetParent()
                local want = dialog and dialog.data
                if want and box:GetText() ~= want then box:SetText(want); box:HighlightText() end
            end,
        }
    end
    local hint = ns.L and ns.L["Press Ctrl+C to copy."] or "Press Ctrl+C to copy."
    return (pcall(show, COPY, ("%s\n|cffaaaaaa%s|r"):format(title, hint), nil, text))
end

-- A button in an AceGUI Frame's footer, left of its Close button (same Blizzard template and size),
-- shown only while wanted. The status bar beside it is narrowed while it shows. AceGUI pools its
-- windows across addons, so one cleanup runs on the window's OnRelease callback (which AceGUI fires
-- whenever it releases a window, including Close and Escape), on a change of window, and when no
-- window is open: the button never stays in another addon's window.
local footer = {}

local function footerCleanup()
    local b = footer.button
    if b then
        b:Hide()
        b:SetScript("OnClick", nil)
    end
    if footer.statusbg then footer.statusbg:SetPoint("BOTTOMRIGHT", -132, 15) end
    footer.widget, footer.statusbg = nil, nil
end
A.FooterCleanup = footerCleanup

function A.FooterButton(widget, text, onClick, show)
    local frame = type(widget) == "table" and widget.frame
    if type(frame) ~= "table" then
        footerCleanup()
        return false
    end
    local create = A.Resolve("CreateFrame")
    if type(create) ~= "function" then return false end
    if footer.widget and footer.widget ~= widget then footerCleanup() end
    if not footer.button then
        footer.button = create("Button", nil, frame, "UIPanelButtonTemplate")
        footer.button:SetSize(100, 20)
    end
    local b = footer.button
    if footer.widget ~= widget then
        footer.widget = widget
        b:SetParent(frame)
        b:ClearAllPoints()
        b:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -131, 17)
        if type(widget.SetCallback) == "function" then
            widget:SetCallback("OnRelease", function() footerCleanup() end)
        end
    end
    local statusbg = widget.statustext and widget.statustext.GetParent and widget.statustext:GetParent()
    footer.statusbg = statusbg
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    if show then
        b:Show()
        if statusbg then statusbg:SetPoint("BOTTOMRIGHT", -236, 15) end
    else
        b:Hide()
        if statusbg then statusbg:SetPoint("BOTTOMRIGHT", -132, 15) end
    end
    return true
end

-- Native confirmation, with no write when unavailable or cancelled.
function A.ConfirmClearLog(accept)
    local dialogs = A.Resolve("StaticPopupDialogs")
    if type(dialogs) ~= "table" then return false end
    dialogs.KEEPTHAT_CLEAR_LOG = {
        text = ns.L["Clear recorded diagnostics? Gameplay data and settings are retained."],
        button1 = ns.L["Clear"], button2 = ns.L["Cancel"],
        OnAccept = function() accept() end, timeout = 0, whileDead = true, hideOnEscape = true,
        preferredIndex = 3,
    }
    return A.Call("StaticPopup_Show", "KEEPTHAT_CLEAR_LOG") ~= nil
end

-- A private tint sample. Never attaches to an inventory button or changes its classification.
local tintSample
function A.ShowTintSample(p)
    local ok = pcall(function()
        if not tintSample then
            tintSample = A.Call("CreateFrame", "Frame", nil, A.Resolve("UIParent"))
            if not tintSample then return end
            tintSample:SetSize(180, 64); tintSample:SetPoint("CENTER")
            local icon = tintSample:CreateTexture(nil, "ARTWORK")
            icon:SetSize(28, 28); icon:SetPoint("LEFT", 8, 0); icon:SetTexture(134400)
            tintSample.tint = tintSample:CreateTexture(nil, "OVERLAY")
            tintSample.tint:SetAllPoints(icon); tintSample.tint:SetBlendMode("ADD")
            local text = tintSample:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("LEFT", 44, 0); text:SetWidth(128); text:SetTextColor(0.667, 0.667, 0.667); text:SetText(ns.L["Sample — Endgame tint"])
            tintSample:SetScript("OnUpdate", function(self, dt)
                self.age = self.age + dt
                if self.age >= 4 then self:Hide()
                else
                    local current = ns.Presentation and ns.Presentation.Profile() or p
                    local c = current.colors.endgame
                    self.tint:SetColorTexture(c.r, c.g, c.b, current.maskOpacity or 0.4)
                end
            end)
        end
        local c = p.colors.endgame
        tintSample.tint:SetColorTexture(c.r, c.g, c.b, p.maskOpacity or 0.4)
        tintSample.age = 0; tintSample:Show()
    end)
    return ok and tintSample ~= nil
end

-- Font objects are client-owned. Prefer the requested role, then the game's normal font.
function A.FontName(preferred)
    for _, name in ipairs({ preferred, "GameFontHighlightSmall", "GameFontNormal" }) do
        if A.Resolve(name) then return name end
    end
    return nil
end
