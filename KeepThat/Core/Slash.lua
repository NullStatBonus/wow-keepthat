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
    elseif cmd == "settings" then
        local page = rest:lower(); if page == "" then page = "home" end
        local pages = ns.Presentation and ns.Presentation.pages or { home = true, materials = true, integrations = true, appearance = true, advanced = true, about = true }
        if not pages[page] then return { L["Pages: home, materials, integrations, appearance, advanced, about."] } end
        deps.open(page); return {}
    elseif cmd == "get" or cmd == "set" then
        local key, value = rest:match("^(%S+)%s*(.-)$")
        key = key and key:lower()
        if not key or (cmd == "get" and value ~= "") or (cmd == "set" and (value == "" or value:find("%s"))) then
            return { L["Usage: /kt get <key> or /kt set <key> <value>. Use /kt help appearance for keys."] }
        end
        local P = ns.Presentation
        if not P then return { L["Settings are unavailable."] } end
        if cmd == "get" then
            if not P.keys[key] then return { P.Syntax(key) } end
            return { L["%s = %s"]:format(key, P.Value(key)) }
        end
        local _, reply = P.Set(key, value); return { reply }
    elseif cmd == "help" or cmd == "status" then
        local topic = rest:lower()
        if topic ~= "" and topic ~= "appearance" and topic ~= "diagnostics" and topic ~= "domain" then
            return { L["Topics: appearance, diagnostics, domain."] }
        end
        if cmd == "status" then return ns.Presentation and ns.Presentation.Status() or { L["Settings are unavailable."] } end
        if topic == "appearance" then return {
            L["Keys: toast, tooltip, appearance.toast.background-opacity (0-100), appearance.toast.text-opacity (0-100), appearance.toast.scale (50-200), appearance.toast.locked (on|off)."],
            L["Example: /kt set appearance.toast.text-opacity 80. Use /kt preview toast, tooltip, tint or copy; /kt demo shows all samples."] }
        elseif topic == "diagnostics" then return { L["Diagnostics: /kt debug on|off, /kt log, /kt log clear (confirmation required), /kt probe [hover|path <name>]."] }
        elseif topic == "domain" then return { L["Materials: /kt find <name>; /kt settings materials; /kt settings integrations."] } end
        return { L["Help: /kt help appearance, /kt help diagnostics, /kt help domain. Open /kt settings [page], read /kt status [topic], or try /kt demo."] }
    elseif cmd == "preview" then
        local kind = rest:lower()
        if kind ~= "toast" and kind ~= "tooltip" and kind ~= "tint" and kind ~= "copy" then
            return { L["Previews: /kt preview toast, /kt preview tooltip, /kt preview tint, /kt preview copy."] }
        end
        if deps.preview then deps.preview(kind) end
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
    elseif cmd == "demo" and rest == "" then
        -- Always shows the visuals, whatever the settings: sample toasts and a sample tooltip.
        deps.demo()
        return { L["Showing sample toasts, a tooltip and an isolated tint. Hold Shift over the tooltip for details."] }
    elseif cmd == "test" then
        -- One explicit in-game test at a time, like /cvn test <kind> in Closest Vendor.
        local kind = rest:lower()
        if kind == "toast" then
            deps.testToast()
            return { L["Showing one sample loot toast."] }
        elseif kind == "tooltip" then
            deps.testTooltip()
            return { L["Showing a random material tooltip with sample data. Hold Shift over it for the details."] }
        elseif kind == "copy" then
            deps.testCopy()
            return { L["Showing the copy-link box."] }
        end
        return { L["Tests: /kt test toast, /kt test tooltip, /kt test copy. /kt demo shows them all."] }
    elseif cmd == "log" then
        if rest:lower() == "clear" then
            if deps.clearLog then deps.clearLog() end
            return {}
        elseif rest ~= "" then return { L["Usage: /kt log or /kt log clear."] } end
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
        open = function(page) return ns.Options.Open(page) end,
        testToast = function() if ns.Toast and ns.Toast.Demo then pcall(ns.Toast.Demo, 1) end end,
        testToastAll = function() if ns.Toast and ns.Toast.Demo then pcall(ns.Toast.Demo) end end,
        testTooltip = function() if ns.Tooltip.Preview then ns.Tooltip.Preview() end end,
        preview = function(kind)
            if kind == "toast" then deps.testToast()
            elseif kind == "tooltip" then deps.testTooltip()
            elseif kind == "copy" then deps.testCopy()
            elseif kind == "tint" then ns.Adapter.ShowTintSample(addon.db.profile) end
        end,
        clearLog = function()
            if not ns.Adapter.ConfirmClearLog(function() ns.Log.Clear() end) then
                addon:Print(L["Confirmation is unavailable. Diagnostics were retained."])
            end
        end,
        testCopy = function()
            ns.Adapter.ShowCopyBox(L["KeepThat - Wowhead link"], "https://www.wowhead.com/classic/item=12360")
        end,
        demo = function() deps.testToastAll(); deps.testTooltip(); deps.preview("tint") end,
        report = function() return ns.Log.Report() end,
        setDebug = function(on) addon.db.profile.debug = on end,
    }
    addon:RegisterChatCommand("kt", function(args)
        local lines = Slash.Run(args, deps)
        for _, line in ipairs(lines) do addon:Print((line:gsub("|", "||"))) end
    end)
end
