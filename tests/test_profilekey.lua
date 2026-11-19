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

_G.KeepThatDB = nil
stubs.restore()
H.done()
