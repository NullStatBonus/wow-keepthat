-- A character's profile choice survives AceDB's new character key (spec settings, "Settings saved per
-- account with profiles"; design D4). AceDB-3.0 minor 40 names WoW Forever characters "Name Surname"
-- instead of "Name - Realm", so a per-character profile chosen under the old name would silently fall
-- back to the shared settings. Plain Lua: db is the AceDB object, oldKey the old-style key or nil.
local _, ns = ...

local ProfileKey = {}
ns.ProfileKey = ProfileKey

-- Applies the choice saved under oldKey once, never over a choice made under the new key, then forgets
-- the old entry so it cannot apply again. Returns true when it switched the profile.
function ProfileKey.Migrate(db, oldKey)
    if type(db) ~= "table" then return false end
    local sv, new = db.sv, db.keys and db.keys.char
    if type(oldKey) ~= "string" or type(new) ~= "string" or type(sv) ~= "table" then return false end
    if type(sv.profileKeys) ~= "table" or oldKey == new then return false end
    local chosen = sv.profileKeys[oldKey]
    if type(chosen) ~= "string" then return false end
    local switched = false
    local okCur, current = pcall(db.GetCurrentProfile, db)
    if okCur and current == "Default" and chosen ~= "Default" and type(sv.profiles) == "table" and sv.profiles[chosen] then
        local ok, err = pcall(db.SetProfile, db, chosen)
        if ok then switched = true elseif ns.Log and ns.Log.Failure then ns.Log.Failure("profile", err) end
    end
    sv.profileKeys[oldKey] = nil
    return switched
end

local function fail(err)
    if ns.Log and ns.Log.Failure then ns.Log.Failure("profile", err) end
end

-- Moves a profile named after oldKey to the character's new name once (spec settings, "Character profile
-- follows the new character name"; design D1), so "This character" off and on finds it again. Never
-- overwrites a profile under the new name. Returns true when it moved the profile.
function ProfileKey.Rename(db, oldKey)
    if type(db) ~= "table" then return false end
    local sv, new = db.sv, db.keys and db.keys.char
    if type(oldKey) ~= "string" or type(new) ~= "string" or type(sv) ~= "table" then return false end
    -- Equal names (Classic Era, older AceDB) need no guard: the profile then exists under the new name.
    local profiles = sv.profiles
    if type(profiles) ~= "table" or type(profiles[oldKey]) ~= "table" or profiles[new] ~= nil then return false end
    local okCur, current = pcall(db.GetCurrentProfile, db)
    if not okCur then return false end
    if current ~= oldKey then
        -- Not active: a plain saved table with defaults already removed, so moving it is exact.
        profiles[new], profiles[oldKey] = profiles[oldKey], nil
        return true
    end
    local ok, err = pcall(db.SetProfile, db, new)
    if not ok then fail(err); return false end
    ok, err = pcall(db.CopyProfile, db, oldKey)
    if not ok then
        -- Keep working settings: back to the old profile, and drop the half-made new one.
        fail(err)
        pcall(db.SetProfile, db, oldKey)
        pcall(db.DeleteProfile, db, new, true)
        return false
    end
    ok, err = pcall(db.DeleteProfile, db, oldKey)
    if not ok then fail(err) end
    return true
end
