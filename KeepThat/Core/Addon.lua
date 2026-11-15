local addonName, ns = ...

local addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0", "AceConsole-3.0", "AceHook-3.0")
ns.addon = addon

function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("KeepThatDB", ns.defaults, true)
    ns.Presentation.Migrate(self.db.profile)
    -- Profession names in KeepThat's own text come from the client, so they match the game's language
    -- with no translation file needed.
    ns.Wording.UseClientNames(ns.Adapter.ProfessionDisplayNames())
    ns.Slash.Register(self)
    -- Feature modules register a starter in ns.starters (UI/Tooltip.lua, UI/Toast.lua, Integrations/...).
    for _, start in ipairs(ns.starters or {}) do
        local ok, err = pcall(start, self)
        if not ok and ns.Log then ns.Log.Failure("start", err) end
    end
end

-- A profession rank changed: counts and leveling marks depend on it.
function addon:OnEnable()
    self:RegisterEvent("SKILL_LINES_CHANGED", function() ns.Context.Invalidate() end)
    self:RegisterEvent("LEARNED_SPELL_IN_TAB", function() ns.Context.Invalidate() end)
end

-- Feature files call ns.Start(fn) at load; fn(addon) runs once saved settings are ready.
function ns.Start(fn)
    ns.starters = ns.starters or {}
    ns.starters[#ns.starters + 1] = fn
end
