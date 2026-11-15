-- Core loads the way the game loads it: the locale table, the version from the TOC, and an Ace addon.
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq
local stubs = require("stubs")

local created
stubs.install({
    C_AddOns = { GetAddOnMetadata = function(name, field) return name == "KeepThat" and field == "Version" and "9.9.9" or nil end },
    LibStub = function(lib)
        eq(lib, "AceAddon-3.0", "Core asks for AceAddon")
        return { NewAddon = function(_, name, ...) created = { name = name, mixins = { ... } }; return created end }
    end,
})

local ns = {}
H.locale(ns)
H.load("Core/Init.lua", ns)
H.load("Core/Addon.lua", ns)

eq(ns.L["Any sentence"], "Any sentence", "an untranslated sentence comes back as written")
eq(ns.name, "KeepThat", "the addon name comes from the game")
eq(ns.version, "9.9.9", "the version comes from the TOC")
eq(ns.addon, created, "the Ace addon is stored in ns")
eq(created.name, "KeepThat", "the Ace addon is named after the addon")
eq(table.concat(created.mixins, ","), "AceEvent-3.0,AceConsole-3.0,AceHook-3.0", "the Ace mixins")

stubs.restore()
H.done()
