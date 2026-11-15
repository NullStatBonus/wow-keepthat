-- Each TOC's file list loads only its own client's data, and Core/Client.lua picks it up.
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq

local function tocFiles(name)
    local files = {}
    for line in io.lines("KeepThat/KeepThat_" .. name .. ".toc") do
        line = line:gsub("\r", "")
        if line ~= "" and not line:find("^#") then files[#files + 1] = (line:gsub("\\", "/")) end
    end
    return files
end

for toc, client in pairs({ Vanilla = "era", Camelot = "forever" }) do
    local ns = {}
    for _, file in ipairs(tocFiles(toc)) do
        if file:find("^Data/") or file == "Core/Client.lua" then H.load(file, ns) end
    end
    eq(ns.client, client, toc .. ".toc: client")
    eq(ns.Data.Catalog.client, client, toc .. ".toc: the catalog in use")
    eq(type(ns.Data.Routes), "table", toc .. ".toc: the routes in use")
    eq(ns.Data["Catalog_" .. (client == "era" and "Forever" or "Era")], nil, toc .. ".toc: the other client's catalog is not loaded")
end

-- No data loaded: nothing is guessed.
local ns = {}
H.load("Core/Client.lua", ns)
eq(ns.client, nil, "no catalog: no client")

H.done()
