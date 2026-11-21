local addonName, ns = ...

local addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0", "AceConsole-3.0")
ns.addon = addon

function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("KeepThatDB", ns.defaults, true)
    -- First, so the restored profile is the one the presentation upgrade runs on (SetProfile replaces it).
    local oldKey = ns.Adapter.LegacyCharacterKey()
    ns.ProfileKey.Migrate(self.db, oldKey)
    ns.ProfileKey.Rename(self.db, oldKey)
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

-- Registers only events the client has: registering a removed event raises a Lua error.
-- When the client cannot say, try it and drop the error.
function ns.Listen(target, event, fn)
    if ns.Adapter.EventKnown(event) == false then return false end
    return (pcall(target.RegisterEvent, target, event, fn))
end

-- A profession rank changed: counts and leveling marks depend on it. SKILL_LINES_CHANGED checks the
-- visible ranks and a skill chat message ("Your skill in Tailoring has increased") every rank
-- (Context.SkillsChanged); a learned spell always refreshes. Newer clients renamed LEARNED_SPELL_IN_TAB to
-- LEARNED_SPELL_IN_SKILL_LINE.
function addon:OnEnable()
    ns.Listen(self, "SKILL_LINES_CHANGED", function() ns.Context.SkillsChanged() end)
    ns.Listen(self, "CHAT_MSG_SKILL", function() ns.Context.SkillsChanged(true) end)
    local invalidate = function() ns.Context.Invalidate() end
    for _, event in ipairs({ "LEARNED_SPELL_IN_TAB", "LEARNED_SPELL_IN_SKILL_LINE" }) do
        ns.Listen(self, event, invalidate)
    end
end

-- Feature files call ns.Start(fn) at load; fn(addon) runs once saved settings are ready.
function ns.Start(fn)
    ns.starters = ns.starters or {}
    ns.starters[#ns.starters + 1] = fn
end
