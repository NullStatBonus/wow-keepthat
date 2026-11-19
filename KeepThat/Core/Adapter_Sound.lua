-- Game sound calls for the loot toast sound (Model/Sounds.lua; design D3). Every call is guarded; nil when missing.
local _, ns = ...
local A = ns.Adapter

local CHANNELS = { Master = true, SFX = true }
local function channel(c) return CHANNELS[c] and c or "Master" end

-- willPlay from the game (true when the sound will be heard), or nil when the function is missing or errors.
function A.PlaySound(id, ch)
    return (A.Call("PlaySound", id, channel(ch)))
end

function A.PlaySoundFile(path, ch)
    return (A.Call("PlaySoundFile", path, channel(ch)))
end

-- Sound packs registered with LibSharedMedia-3.0 by other addons: { [name] = path }, or nil without the library.
function A.SoundPacks()
    local stub = A.Resolve("LibStub")
    if type(stub) ~= "table" and type(stub) ~= "function" then return nil end
    local ok, lib = pcall(stub, "LibSharedMedia-3.0", true)
    if not ok or type(lib) ~= "table" or type(lib.HashTable) ~= "function" then return nil end
    local okH, hash = pcall(lib.HashTable, lib, "sound")
    if not okH or type(hash) ~= "table" then return nil end
    local out = {}
    for name, path in pairs(hash) do
        if name ~= "None" and type(name) == "string" and (type(path) == "string" or type(path) == "number") then out[name] = path end
    end
    return out
end
