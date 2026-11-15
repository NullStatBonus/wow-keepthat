-- /kt commands. Run(args, deps) is plain Lua: it returns the lines to print and calls deps for
-- anything that touches the game, so tests can drive it with fakes.
-- deps = { open(), setDebug(on), report(), show(title, text), probe }
local _, ns = ...
local L = ns.L

local Slash = {}
ns.Slash = Slash

function Slash.Run(args, deps)
    local cmd, rest = (args or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    if cmd == "" then
        deps.open()
        return {}
    elseif cmd == "find" then
        if rest == "" then return { L["Usage: /kt find <name>"] } end
        local found = deps.find(rest)
        if #found == 1 then
            local r = found[1]
            -- Hidden by the Home checkboxes: say which one shows it instead of opening a hidden page.
            if r.visible == false then
                if r.flags and r.flags.leveling then
                    return { L["%s is a leveling material. Turn on Leveling materials on Home to see it."]:format(r.name) }
                end
                return { L["%s is an endgame material. Turn on Endgame materials on Home to see it."]:format(r.name) }
            end
            deps.openMaterial(r)
            return {}
        end
        if #found == 0 then return { L['No materials match "%s".']:format(rest) } end
        local lines = {}
        for i = 1, math.min(10, #found) do
            local result = found[i]
            lines[i] = L["%s - %s > %s"]:format(result.name, result.categoryName, result.professionName)
        end
        if #found > 10 then lines[#lines + 1] = L["%d more matches. Refine your search."]:format(#found - 10) end
        return lines
    elseif cmd == "debug" then
        local arg = rest:lower()
        if arg == "on" then
            deps.setDebug(true)
            return { L["Debug recording is on. Type /kt log to see the report."] }
        elseif arg == "off" then
            deps.setDebug(false)
            return { L["Debug recording is off."] }
        end
    elseif cmd == "demo" then
        -- Always shows the visuals, whatever the settings: sample toasts and a sample tooltip.
        deps.demo()
        return { L["Showing sample toasts and a sample tooltip (Arcanite Bar). Hold Shift over it for the details."] }
    elseif cmd == "test" then
        -- One explicit in-game test at a time, like /cvn test <kind> in Closest Vendor.
        local kind = rest:lower()
        if kind == "toast" then
            deps.testToast()
            return { L["Showing one sample loot toast."] }
        elseif kind == "tooltip" then
            deps.testTooltip()
            return { L["Showing a sample tooltip (Arcanite Bar). Hold Shift over it for the details."] }
        elseif kind == "copy" then
            deps.testCopy()
            return { L["Showing the copy-link box."] }
        end
        return { L["Tests: /kt test toast, /kt test tooltip, /kt test copy. /kt demo shows them all."] }
    elseif cmd == "log" then
        deps.show(L["KeepThat debug report"], deps.report())
        return {}
    elseif cmd == "probe" then
        local sub, arg = rest:match("^(%S*)%s*(.-)$")
        if sub:lower() == "hover" then
            deps.show(L["KeepThat probe"], deps.probe.Hover())
        elseif sub:lower() == "path" and arg ~= "" then
            deps.show(L["KeepThat probe"], deps.probe.Path(arg))
        else
            deps.show(L["KeepThat probe"], deps.probe.Run())
        end
        return {}
    end
    return { L["Commands: /kt, /kt find <name>, /kt demo, /kt test <toast|tooltip|copy>, /kt debug on|off, /kt log, /kt probe, /kt probe hover, /kt probe path <name>"] }
end

function Slash.Register(addon)
    local deps
    deps = {
        find = function(query) return ns.Options.Find(query) end,
        openMaterial = function(result) return ns.Options.OpenMaterial(result) end,
        probe = ns.Probe,
        show = function(...) return ns.Export.Show(...) end,
        open = function() return ns.Options.Open() end,
        testToast = function() if ns.Toast and ns.Toast.Demo then pcall(ns.Toast.Demo, 1) end end,
        testToastAll = function() if ns.Toast and ns.Toast.Demo then pcall(ns.Toast.Demo) end end,
        -- A sample classification (both categories) so the tooltip shows KeepThat's lines whatever the
        -- settings and the player's skills are, for 15 seconds.
        testTooltip = function()
            local A = ns.Adapter
            ns.Context.SetDemo(12360, { endgame = { { profession = "blacksmithing", reason = "Best-in-slot crafted gear" } },
                leveling = { { profession = "engineering", need = { low = 20, high = 25, from = 260, to = 300, via = {}, sources = { "Sample guide" } } } } },
                A.Now and A.Now() or 0, 15)
            if A.ShowItemTooltip then A.ShowItemTooltip(12360) end
        end,
        testCopy = function()
            ns.Adapter.ShowCopyBox(L["KeepThat - Wowhead link"], "https://www.wowhead.com/classic/item=12360")
        end,
        demo = function() deps.testToastAll(); deps.testTooltip() end,
        report = function() return ns.Log.Report() end,
        setDebug = function(on) addon.db.profile.debug = on end,
    }
    addon:RegisterChatCommand("kt", function(args)
        local lines = Slash.Run(args, deps)
        for _, line in ipairs(lines) do addon:Print((line:gsub("|", "||"))) end
    end)
end
