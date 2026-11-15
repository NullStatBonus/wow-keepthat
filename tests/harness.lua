-- Shared test helpers. Usage in a test file:
--   package.path = "tests/?.lua;" .. package.path
--   local H = require("harness"); local eq = H.eq
--   ... eq(actual, expected, "what is checked") ...
--   H.done()
local H = { n = 0 }

function H.eq(actual, expected, msg)
    H.n = H.n + 1
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(msg, tostring(expected), tostring(actual)), 2)
    end
end

-- Last line of a passing test: the runner shows it.
function H.done(extra)
    print(("ok (%d checks%s)"):format(H.n, extra and (", " .. extra) or ""))
end

-- Load an addon file the way the game does: (addonName, ns) as varargs.
function H.load(path, ns)
    assert(loadfile("KeepThat/" .. path))("KeepThat", ns)
    return ns
end

-- Load the English text table into ns (every module that prints text needs ns.L).
function H.locale(ns)
    return H.load("Locales/enUS.lua", ns)
end

return H
