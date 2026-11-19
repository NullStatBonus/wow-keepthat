-- Loot toast sounds (spec loot-toast, "Toast sound"; design D1, D2). Plain Lua: the built-in list, and
-- resolving a saved choice to something playable. Playing goes through the adapter given to Play.
-- The kit IDs are game sounds verified on both clients (docs/contracts.md); KeepThat ships no sound files.
-- Sound packs come from LibSharedMedia-3.0 when another addon provides it; their keys are "lsm:<name>".
local _, ns = ...
local L = ns.L

local Sounds = {
    default = "auction",
    none = "none",
    list = {
        { key = "auction", label = L["Auction open"], id = 5274 },
        { key = "levelup", label = L["Level up"], id = 888 },
        { key = "questcomplete", label = L["Quest complete"], id = 878 },
        { key = "readycheck", label = L["Ready check"], id = 8960 },
        { key = "raidwarning", label = L["Raid warning"], id = 8959 },
        { key = "pvpqueue", label = L["PvP queue ready"], id = 8459 },
        { key = "murloc", label = L["Murloc aggro"], id = 416 },
        { key = "bellalliance", label = L["Bell toll (Alliance)"], id = 6594 },
        { key = "bellhorde", label = L["Bell toll (Horde)"], id = 6595 },
        { key = "bnettoast", label = L["Battle.net toast"], id = 18019 },
    },
}
ns.Sounds = Sounds

local byKey = {}
for _, e in ipairs(Sounds.list) do byKey[e.key] = e end

-- "kit", id or "file", path for a key; nil when it cannot be played here. packs: name -> path, or nil.
function Sounds.Resolve(key, packs)
    if type(key) ~= "string" then return nil end
    local e = byKey[key]
    if e then return "kit", e.id end
    if key:sub(1, 4) == "lsm:" and type(packs) == "table" then
        local path = packs[key:sub(5)]
        if path then return "file", path end
    end
    return nil
end

-- The key that will play: the saved key when it resolves (or is None), else the default.
function Sounds.Effective(key, packs)
    if key == Sounds.none or Sounds.Resolve(key, packs) then return key end
    return Sounds.default
end

local function play(adapter, kind, id, channel)
    local fn = kind == "file" and adapter.PlaySoundFile or adapter.PlaySound
    if type(fn) ~= "function" then return false end
    local ok, willPlay = pcall(fn, id, channel)
    return ok and willPlay ~= false -- as Don't Do That: only an explicit false means it will not play
end

-- Plays the key once; falls back to the default when the key cannot play. True when a sound played.
function Sounds.Play(key, channel, adapter)
    if key == Sounds.none or type(adapter) ~= "table" then return false end
    local packs = type(adapter.SoundPacks) == "function" and adapter.SoundPacks() or nil
    local kind, id = Sounds.Resolve(key, packs)
    if kind and play(adapter, kind, id, channel) then return true end
    if key == Sounds.default then return false end
    kind, id = Sounds.Resolve(Sounds.default, packs)
    return kind ~= nil and play(adapter, kind, id, channel)
end

-- Picker entries in order: None, the built-in sounds, then sound packs alphabetically.
function Sounds.Entries(packs)
    local out = { { key = Sounds.none, label = L["None"] } }
    for _, e in ipairs(Sounds.list) do out[#out + 1] = { key = e.key, label = e.label } end
    local names = {}
    for name in pairs(packs or {}) do names[#names + 1] = name end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    for _, name in ipairs(names) do out[#out + 1] = { key = "lsm:" .. name, label = L["%s (sound pack)"]:format(name) } end
    return out
end
