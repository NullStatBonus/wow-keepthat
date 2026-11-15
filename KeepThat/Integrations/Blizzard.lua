-- The icon mask in Blizzard's default bags and bank, on both clients (spec icon-mask). Not an optional
-- integration (no toggle, not gated to Forever), but contained the same way: the hooks are installed
-- through Core/Adapter_Bags.lua, which picks the bag and bank update paths that exist, and the paint
-- callback is guarded, so an error turns it off for the session and is logged.
local _, ns = ...
local A = ns.Adapter

local Blizzard = { KEY = "blizzard" }
ns.Blizzard = Blizzard

function Blizzard.Detect()
    return A.HasBlizzardBags()
end

function Blizzard.Start(ctx)
    local paint = ctx.guard(function(button, bag, slot)
        ns.Overlay.Apply(button, A.ContainerItemID(bag, slot), A.BagLocation(bag), nil, Blizzard.KEY)
    end)
    local paths = A.HookBlizzardBags(paint)
    if #paths == 0 then return false, "no default bag update function to hook" end
    if ns.Log then ns.Log.Record(Blizzard.KEY, "hooked " .. table.concat(paths, ", ")) end
end

ns.Integrations.Register(Blizzard.KEY, { detect = Blizzard.Detect, start = Blizzard.Start, anyClient = true })
