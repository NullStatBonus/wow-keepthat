-- Model/ProfileKey.lua with the real shipped AceDB-3.0 (minor 40): a Forever character's profile choice
-- survives the new character key (spec settings, "Settings saved per account with profiles").
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq
local stubs = require("stubs")

local ns = H.locale({})
H.load("Core/Defaults.lua", ns)
local failures = {}
ns.Log = { Failure = function(area, err) failures[#failures + 1] = area .. ": " .. tostring(err) end }
H.load("Model/ProfileKey.lua", ns)
local Migrate = ns.ProfileKey.Migrate

local function copy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = copy(v) end
    return c
end
local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local OLD = "Me - Realm"
-- A 0.4.2 save: Me chose its own profile (named after the old key) with custom values; Alt is shared.
local function oldSave()
    return {
        profileKeys = { [OLD] = OLD, ["Alt - Realm"] = "Default" },
        profiles = { [OLD] = { toastScale = 1.5, toast = true }, Default = { toast = false } },
        global = { log = {} },
    }
end
local function login(saved, opts)
    local db = stubs.loadAceDB(saved, ns.defaults, opts)
    Migrate(db, opts.oldKey or OLD)
    return db
end

-- (a) Forever: the old choice and its values come back; another character stays shared.
local saved = oldSave()
local db = login(saved, { forever = true })
eq(db.keys.char, "Me Smith", "AceDB 40 uses the new Forever key")
eq(db:GetCurrentProfile(), OLD, "the character's own profile is chosen again")
eq(db.profile.toastScale, 1.5, "with its values")
eq(saved.profileKeys[OLD], nil, "the old entry is cleared")
local alt = login(saved, { forever = true, name = "Alt", oldKey = "Alt - Realm" })
eq(alt:GetCurrentProfile(), "Default", "the other character stays on the shared settings")

-- (b) Restored only once: switched back to shared, it stays shared on the next login.
db = login(saved, { forever = true })
db:SetProfile("Default")
db = login(saved, { forever = true })
eq(db:GetCurrentProfile(), "Default", "stays on the shared settings")

-- (c) Classic Era: the key did not change, nothing is touched.
saved = oldSave()
local before = copy(saved)
db = stubs.loadAceDB(saved, ns.defaults, {})
local afterLoad = copy(saved)
eq(db.keys.char, OLD, "Era key is unchanged")
eq(Migrate(db, OLD), false, "nothing to migrate")
eq(same(saved, afterLoad), true, "saved data deep-equal after the migration")
eq(db:GetCurrentProfile(), OLD, "the profile choice stays")
eq(same(saved.profiles, before.profiles), true, "profiles untouched")

-- (d) A choice already made under the new key is kept.
saved = oldSave()
saved.profileKeys["Me Smith"] = "Me Smith"
saved.profiles["Me Smith"] = { toastScale = 0.8 }
db = login(saved, { forever = true })
eq(db:GetCurrentProfile(), "Me Smith", "the new-key choice stays")
eq(db.profile.toastScale, 0.8, "with its values")

-- (e) An older AceDB (key unchanged): a fake db whose char key is the old key changes nothing.
local fake = { sv = oldSave(), keys = { char = OLD }, GetCurrentProfile = function() return "Default" end,
    SetProfile = function() error("must not switch") end }
local fakeBefore = copy(fake.sv)
eq(Migrate(fake, OLD), false, "no change with the old key")
eq(same(fake.sv, fakeBefore), true, "saved data untouched")

-- (f) An invalid saved profile name: no Lua error, the profile stays.
saved = oldSave()
saved.profileKeys[OLD] = "   "
saved.profiles["   "] = { toastScale = 2 }
db = login(saved, { forever = true })
eq(db:GetCurrentProfile(), "Default", "invalid name: stays on the shared settings")
eq(#failures, 1, "the error is recorded"); eq(failures[1]:find("^profile:") ~= nil, true, "under profile")
eq(saved.profileKeys[OLD], nil, "and the old entry is cleared")

-- Guards: missing pieces return without error.
eq(Migrate(nil, OLD), false, "no db")
eq(Migrate({ keys = { char = "X" } }, OLD), false, "no sv (the smoke test's fake db)")
eq(Migrate({ sv = {}, keys = { char = "X" } }, nil), false, "no old key")
eq(Migrate({ sv = { profileKeys = { [OLD] = "Gone" }, profiles = {} }, keys = { char = "X" },
    GetCurrentProfile = function() return "Default" end, SetProfile = function() error("no") end }, OLD), false,
    "a chosen profile that no longer exists is not applied")

-- Rename (issue #20): the old-named profile moves to the new name, so "This character" off and on keeps it.
local Rename = ns.ProfileKey.Rename
local NEW = "Me Smith"
local function load(saved, opts)
    local d = stubs.loadAceDB(saved, ns.defaults, opts)
    Migrate(d, OLD); Rename(d, OLD)
    return d
end

-- (a) A 0.4.2 save using its own profile: one load restores it under the new name.
saved = oldSave()
db = load(saved, { forever = true })
eq(db:GetCurrentProfile(), NEW, "now under the new name")
eq(db.profile.toastScale, 1.5, "same values")
eq(saved.profiles[OLD], nil, "the old-named profile is gone")

-- (b) Toggle off and on: the same settings come back.
db:SetProfile("Default")
eq(db.profile.toastScale, ns.defaults.profile.toastScale, "shared settings while off")
db:SetProfile(db.keys.char)
eq(db.profile.toastScale, 1.5, "back on: the same settings, not defaults")

-- A character 0.4.3 already restored (current is the old-named profile) is renamed too.
saved = oldSave()
db = stubs.loadAceDB(saved, ns.defaults, { forever = true })
Migrate(db, OLD)
eq(db:GetCurrentProfile(), OLD, "0.4.3 state: on the old-named profile")
db = load(saved, { forever = true })
eq(db:GetCurrentProfile(), NEW, "next load: renamed")
eq(db.profile.toastScale, 1.5, "with its values")

-- (c) On the shared settings with an old-named profile (toggled off under 0.4.3): moved, not switched.
saved = { profileKeys = { [NEW] = "Default" }, profiles = { [OLD] = { toastScale = 1.5 }, Default = {} } }
db = load(saved, { forever = true })
eq(db:GetCurrentProfile(), "Default", "stays on the shared settings")
eq(saved.profiles[OLD], nil, "old name gone")
eq(saved.profiles[NEW].toastScale, 1.5, "moved to the new name")
db:SetProfile(db.keys.char)
eq(db.profile.toastScale, 1.5, "turning This character on brings it back")

-- (d) Both names exist: nothing changes.
saved = { profileKeys = { [NEW] = NEW }, profiles = { [OLD] = { toastScale = 1.5 }, [NEW] = { toastScale = 0.7 } } }
db = load(saved, { forever = true })
eq(db:GetCurrentProfile(), NEW, "current kept")
eq(db.profile.toastScale, 0.7, "new-name values kept")
eq(saved.profiles[OLD].toastScale, 1.5, "old-named profile left as is")

-- (e) Classic Era: deep-equal.
saved = oldSave()
db = stubs.loadAceDB(saved, ns.defaults, {})
afterLoad = copy(saved)
Migrate(db, OLD); eq(Rename(db, OLD), false, "Era: nothing to rename")
eq(same(saved, afterLoad), true, "Era saved data unchanged")

-- (f) A second load does nothing more.
saved = oldSave()
load(saved, { forever = true })
local once = copy(saved)
db = load(saved, { forever = true })
eq(Rename(db, OLD), false, "second run: nothing to do")
eq(same(saved.profiles, once.profiles), true, "profiles unchanged by later loads")

-- (g) CopyProfile fails: back on the old profile, no half-made new one, failure recorded.
failures = {}
local current = OLD
local fdb = { sv = { profileKeys = {}, profiles = { [OLD] = { toastScale = 1.5 } } }, keys = { char = NEW } }
function fdb:GetCurrentProfile() return current end
function fdb:SetProfile(n) current = n; if not self.sv.profiles[n] then self.sv.profiles[n] = {} end end
function fdb:CopyProfile() error("copy broke") end
function fdb:DeleteProfile(n) self.sv.profiles[n] = nil end
eq(Rename(fdb, OLD), false, "failed copy: not renamed")
eq(current, OLD, "back on the old profile")
eq(fdb.sv.profiles[NEW], nil, "no half-made new profile")
eq(fdb.sv.profiles[OLD].toastScale, 1.5, "old profile intact")
eq(#failures, 1, "failure recorded")

_G.KeepThatDB = nil
stubs.restore()
H.done()
