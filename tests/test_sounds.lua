-- Model/Sounds.lua: the built-in list, resolving choices, fallback to the default, None (spec loot-toast).
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq

local ns = H.locale({})
H.load("Model/Sounds.lua", ns)
local S = ns.Sounds

-- The list: ten sounds in picker order, default first.
local order = { "auction", "levelup", "questcomplete", "readycheck", "raidwarning", "pvpqueue", "murloc",
    "bellalliance", "bellhorde", "bnettoast" }
eq(#S.list, 10, "ten built-in sounds")
for i, k in ipairs(order) do eq(S.list[i].key, k, "picker order " .. i) end
eq(S.default, "auction", "default is Auction open")
eq(S.list[1].id, 5274, "Auction open is kit 5274")
eq(S.list[7].id, 416, "Murloc aggro is kit 416")

-- Resolve.
local packs = { ["Air Horn"] = "Interface\\AddOns\\Pack\\horn.ogg" }
local kind, id = S.Resolve("levelup", packs)
eq(kind, "kit", "built-in is a kit"); eq(id, 888, "level up id")
kind, id = S.Resolve("lsm:Air Horn", packs)
eq(kind, "file", "pack is a file"); eq(id, packs["Air Horn"], "pack path")
eq(S.Resolve("lsm:Air Horn", nil), nil, "pack without the library")
eq(S.Resolve("lsm:Gone", packs), nil, "missing pack")
eq(S.Resolve("nonsense", packs), nil, "unknown key")
eq(S.Resolve(nil, packs), nil, "no key")

-- Effective: what the picker shows.
eq(S.Effective("murloc", nil), "murloc", "built-in stays")
eq(S.Effective("none", nil), "none", "None stays")
eq(S.Effective("lsm:Gone", packs), "auction", "missing pack shows the default")
eq(S.Effective("lsm:Air Horn", packs), "lsm:Air Horn", "present pack stays")

-- Play through a fake adapter.
local function fake(opts)
    opts = opts or {}
    local a = { calls = {} }
    a.PlaySound = function(id, ch) a.calls[#a.calls + 1] = { "kit", id, ch }; if opts.kitFails and opts.kitFails[id] then return false end; return true end
    a.PlaySoundFile = function(p, ch) a.calls[#a.calls + 1] = { "file", p, ch }; return not opts.fileFails end
    a.SoundPacks = function() return opts.packs end
    return a
end
local a = fake()
eq(S.Play("none", "Master", a), false, "None plays nothing"); eq(#a.calls, 0, "None: no call")
a = fake()
eq(S.Play("murloc", "SFX", a), true, "murloc plays"); eq(a.calls[1][2], 416, "murloc id"); eq(a.calls[1][3], "SFX", "channel passed")
a = fake()
eq(S.Play("lsm:Gone", "Master", a), true, "missing pack falls back"); eq(#a.calls, 1, "one call"); eq(a.calls[1][2], 5274, "fallback is the default")
a = fake({ packs = packs })
eq(S.Play("lsm:Air Horn", "Master", a), true, "pack plays"); eq(a.calls[1][1], "file", "pack via PlaySoundFile")
a = fake({ packs = packs, fileFails = true })
eq(S.Play("lsm:Air Horn", "Master", a), true, "pack that will not play falls back"); eq(a.calls[2][2], 5274, "then the default")
a = fake({ kitFails = { [888] = true } })
eq(S.Play("levelup", "Master", a), true, "willPlay false falls back"); eq(a.calls[2][2], 5274, "default after failure")
a = fake({ kitFails = { [5274] = true } })
eq(S.Play("auction", "Master", a), false, "default failing: false"); eq(#a.calls, 1, "default not retried")
eq(S.Play("murloc", "Master", {}), false, "no play function: false, no error")
eq(S.Play("murloc", "Master", nil), false, "no adapter: false")
a = fake(); a.PlaySound = function() error("boom") end
eq(S.Play("murloc", "Master", a), false, "an error is contained")

-- Entries: None, built-in, packs sorted, labeled.
local e = S.Entries({ zeta = "z", ["Air Horn"] = "a" })
eq(e[1].key, "none", "None first"); eq(e[1].label, "None", "None label")
eq(e[2].label, "Auction open", "default second")
eq(#e, 13, "None + 10 + 2 packs")
eq(e[12].key, "lsm:Air Horn", "packs sorted"); eq(e[12].label, "Air Horn (sound pack)", "pack label")
eq(e[13].key, "lsm:zeta", "case-insensitive sort")
eq(#S.Entries(nil), 11, "no library: None + 10")

H.done()
