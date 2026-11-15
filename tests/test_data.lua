-- The generated catalogs load, are shaped as Model/ expects, and every endgame entry cites a source
-- and is a reagent of some recipe on that client (material-catalog).
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq

local PROFESSIONS = { alchemy = true, blacksmithing = true, enchanting = true, engineering = true,
    leatherworking = true, tailoring = true, cooking = true, firstaid = true, mining = true }

for _, client in ipairs({ "Era", "Forever" }) do
    local ns = {}
    H.load("Data/Catalog_" .. client .. ".lua", ns)
    local cat = ns.Data["Catalog_" .. client]
    eq(type(cat), "table", client .. ": catalog loads")
    eq(cat.client, client:lower(), client .. ": client field")

    local reagents, recipes = {}, 0
    for spell, rec in pairs(cat.recipes) do
        recipes = recipes + 1
        eq(PROFESSIONS[rec.p], true, client .. " " .. spell .. ": known profession")
        eq(rec.learn >= 1 and rec.learn <= 300, true, client .. " " .. spell .. ": learn skill in 1-300")
        eq(#rec.r > 0 and #rec.r % 2 == 0, true, client .. " " .. spell .. ": reagent pairs")
        for i = 1, #rec.r, 2 do
            reagents[rec.r[i]] = true
            eq(rec.r[i + 1] > 0, true, client .. " " .. spell .. ": positive quantity")
        end
    end
    eq(recipes > 1000, true, client .. ": every profession's recipes are present (" .. recipes .. ")")

    for item, profs in pairs(cat.endgame) do
        eq(reagents[item], true, client .. " endgame " .. item .. ": is a reagent of some recipe")
        for prof, entry in pairs(profs) do
            eq(PROFESSIONS[prof], true, client .. " endgame " .. item .. ": known profession")
            eq(type(entry[1]) == "string" and #entry[1] > 0, true, client .. " endgame " .. item .. ": has a reason")
            eq(type(entry[2]) == "string" and #entry[2] > 0, true, client .. " endgame " .. item .. ": cites a source")
        end
    end

    -- Spot checks against known recipes.
    local arcanite = cat.recipes[17187]
    eq(arcanite and arcanite.make, 12360, client .. ": Transmute: Arcanite makes Arcanite Bar")
    eq(cat.itemNames[12363], "Arcane Crystal", client .. ": reagent names are kept")
end

H.done()
