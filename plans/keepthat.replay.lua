-- Replay hooks for plans/keepthat.yaml (CheckThat tests/replay.lua). The replay writes only CheckThat's own debug
-- log, so these actions write the KeepThat debug lines (KeepThatDB.global.log) and facts that a tester's actions
-- produce, in the wording docs/contracts.md fixes, then settle the step. A reworded line fails the replay here.
-- Usage, from ../wow-checkthat: luajit tests/replay_plan.lua ../wow-keepthat/build/keepthat.ct ../wow-keepthat/plans/keepthat.replay.lua
local LINES = {
    ["kt.s1.1"] = { "[checkthat] started", "[checkthat] entries registered: 7" },
    ["kt.s2.1"] = { "[tooltip] line added 12360 via postcall" },
    ["kt.s2.2"] = { "[tooltip] line skipped 12360: already on this tooltip" },
    ["kt.s2.4"] = { "[tooltip] line added 12359 via postcall" },
    ["kt.s3.1"] = { "[toast] shown 12359", "[toast] sound auction on Master" },
    ["kt.s3.3"] = { "[toast] shown 14047", "[toast] sound Bell on Master" },
    ["kt.s4.1"] = { "[blizzard] hooked ContainerFrame:UpdateItems" },
    ["kt.s4.2"] = { "[merchant] hooked MerchantFrame_UpdateMerchantInfo", "[merchant] tinted 1 of 10 on page 1",
        "[merchant] tinted 2 of 8 on page 2" },
    ["kt.s4.3"] = { "[merchant] tinted 1 of 1 on buyback" },
    ["kt.s5.1"] = { "[auctionator] export tailoring leveling: 3 items" },
    ["kt.s5.3"] = { "[auctionator] estimate off", "[auctionator] estimate on",
        "[auctionator] estimate tailoring: 123456 copper, 3 priced, 0 unknown" },
    ["kt.s6.1"] = { "[options] opened home" },
    ["kt.s6.2"] = { "[options] launcher closed the game's Options and opened materials", "[options] opened materials" },
    ["kt.s6.4"] = { "[toast] move started", "[toast] move done at BOTTOM 12 -34", "[toast] shown 2589" },
    ["kt.s7.1"] = { "[demo] started: toasts=3 tooltip=true tint=true", "[demo] ended" },
    ["kt.s8.1"] = { "[stock] bank counted: 4 materials", "[stock] mailbox counted: 2 materials" },
    ["kt.s9.1"] = { "[skills] cooking=54; collapsed headers: Secondary Skills" },
    ["kt.s9.2"] = { "[professionjournal] off: 0 materials listed", "[professionjournal] on: 12 materials listed" },
    ["kt.s10.1"] = { "[recipes] tailoring complete=true known=40", "[recipes] recipe probe: tailoring source=window rows=50"
        .. " complete=true filtered=false collapsed=0 unkeyed=0 stale=0 rank=300 mismatches=0 api agrees=40 disagrees=0"
        .. " unknown=0; unlisted=0 api true=40" },
}
local FACTS = {
    ["kt.s1.1"] = { { "entry.version", 700 } },
    ["kt.s3.1"] = { { "toast.seq", 1 } },
    ["kt.s3.3"] = { { "toast.seq", 2 } },
    ["kt.s5.1"] = { { "export.items", 3 } },
    ["kt.s5.3"] = { { "estimate.copper", 123456 } },
    ["kt.s9.2"] = { { "pj.listed", 12 } },
}

local log = {}
local function act(R)
    local env = R.App.env
    env.KeepThatDB = env.KeepThatDB or { global = { log = log } }
    for _, line in ipairs(LINES[R.step.id] or {}) do log[#log + 1] = line end
    for _, f in ipairs(FACTS[R.step.id] or {}) do R.ns.Facts.Report("KeepThat", f[1], f[2]) end
    if R.step.auto then
        -- The tester's /reload after the action (reload: after_action).
        local run = R.App.Current()
        local rec = run and run.steps[R.step.id]
        local attempt = rec and rec.attempts[#rec.attempts]
        if R.step.reload == "after_action" and attempt then attempt.reloaded = true end
        if not R.App.AutoSettle() then error(R.step.id .. ": the automatic step did not settle") end
    else
        local ok, why = R.press("pass")
        if not ok then error(R.step.id .. ": the pass press was refused: " .. tostring(why)) end
    end
end

local action = setmetatable({}, { __index = function() return act end })
return { action = action }
