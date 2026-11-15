-- Localization: every sentence is an L["English"] literal, locale files only translate sentences
-- that exist and keep their %s/%d placeholders, translations are shown, and English is the fallback.
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq

local function read(path)
    local f = assert(io.open(path, "r"), path)
    local s = f:read("*a")
    f:close()
    return s
end

local function lines(cmd)
    local out = {}
    local p = io.popen(cmd)
    for l in p:lines() do out[#out + 1] = l end
    p:close()
    return out
end

-- Read a Lua string literal starting at position i (a quote); returns the value and the next position.
local function literal(src, i)
    local q = src:sub(i, i)
    if q ~= '"' and q ~= "'" then return nil end
    local j = i + 1
    while j <= #src do
        local c = src:sub(j, j)
        if c == "\\" then j = j + 2
        elseif c == q then break
        else j = j + 1 end
    end
    local chunk = loadstring("return " .. src:sub(i, j))
    return chunk and chunk(), j + 1
end

-- Every L[...] use: returns the literal keys and the number of uses that are not a plain literal.
local function uses(src)
    local keys, dynamic = {}, 0
    for start in src:gmatch("()L%[") do
        local before = src:sub(start - 1, start - 1)
        if not before:match("[%w_]") then
            local value, nextPos = literal(src, start + 2)
            if value and src:sub(nextPos, nextPos) == "]" then keys[#keys + 1] = value else dynamic = dynamic + 1 end
        end
    end
    return keys, dynamic
end

-- Assignments L["key"] = "value".
local function assignments(src)
    local out = {}
    for start in src:gmatch("()L%[") do
        local key, p = literal(src, start + 2)
        if key and src:sub(p, p) == "]" then
            local rest = src:match("^%s*=%s*()", p + 1)
            if rest then
                local value = literal(src, rest)
                if value then out[#out + 1] = { key = key, value = value } end
            end
        end
    end
    return out
end

local function specs(s)
    local t = {}
    for spec in s:gmatch("%%[%-%d%.]*[sdfi]") do t[#t + 1] = spec end
    table.sort(t)
    return table.concat(t, " ")
end

-- 1. The code: every use is a plain literal sentence (Libs/ and generated Data/ excluded).
local codeKeys, dynamic = {}, 0
for _, file in ipairs(lines("find KeepThat -name '*.lua' -not -path 'KeepThat/Libs/*' -not -path 'KeepThat/Data/*' | sort")) do
    local keys, dyn = uses(read(file))
    if dyn > 0 then print("dynamic L[...] in " .. file) end
    dynamic = dynamic + dyn
    for _, k in ipairs(keys) do codeKeys[k] = true end
end
eq(dynamic, 0, "every L[...] in the code is a plain string literal (no concatenation or variables)")
local count = 0
for _ in pairs(codeKeys) do count = count + 1 end
eq(count > 20, true, "the code has sentences to translate (found " .. count .. ")")

-- 2. Locale files other than enUS only translate sentences the code uses, with the same placeholders.
for _, file in ipairs(lines("ls KeepThat/Locales/*.lua")) do
    if not file:find("enUS.lua", 1, true) then
        for _, a in ipairs(assignments(read(file))) do
            eq(codeKeys[a.key], true, file .. ": '" .. a.key:sub(1, 40) .. "' is a sentence the code uses")
            eq(specs(a.value), specs(a.key), file .. ": placeholders match for '" .. a.key:sub(1, 40) .. "'")
        end
    end
end

-- The checker itself catches a bad key and bad placeholders.
local bad = assignments('L["No such sentence in the code"] = "x"\nL["Endgame: %s"] = "%d"')
eq(bad[1].key, "No such sentence in the code", "parser reads keys")
eq(codeKeys[bad[1].key], nil, "a made-up key is not a code sentence")
eq(specs(bad[2].value) == specs(bad[2].key), false, "a changed placeholder is caught")
local _, dyn = uses('local x = L["a" .. b] + L[k] + L["fine"]')
eq(dyn, 2, "concatenation and variables are flagged")

-- 3. English is the key; a missing translation falls back.
local ns = H.locale({})
eq(ns.L["Any sentence at all"], "Any sentence at all", "unknown sentence comes back as written")

H.done()
