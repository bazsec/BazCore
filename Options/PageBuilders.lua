---------------------------------------------------------------------------
-- BazCore Options: Page Builders
-- Standardized page generators: Landing, Modules, GlobalOptions
---------------------------------------------------------------------------

local O = BazCore._Options

---------------------------------------------------------------------------
-- CreateLandingPage
-- Builds a standardized landing/manual page with description, features,
-- quick guide, and slash commands sections.
---------------------------------------------------------------------------

function BazCore:CreateLandingPage(addonName, content)
    local args = {}
    local order = 1

    if content.description then
        args.desc = {
            order = order,
            type = "description",
            name = content.description,
        }
        order = order + 1
    end

    if content.features then
        args.featuresHeader = {
            order = order,
            type = "header",
            name = "Features",
        }
        order = order + 1
        -- Colorize all-caps lines as gold sub-headers
        local featText = content.features:gsub("([^\n]*)\n", function(line)
            if line:match("^%u[%u%s%&%-]+$") then
                return "|cffffd700" .. line .. "|r\n"
            end
            return line .. "\n"
        end)
        args.features = {
            order = order,
            type = "description",
            name = featText,
            fontSize = "small",
        }
        order = order + 1
    end

    if content.guide then
        args.guideHeader = {
            order = 20,
            type = "header",
            name = "Quick Guide",
        }

        local guideLines = {}
        for _, entry in ipairs(content.guide) do
            -- Strip leading numbers like "1. " or "13. "
            local title = entry[1]:upper():gsub("^%d+%.%s*", "")
            guideLines[#guideLines + 1] = "|cffffd700" .. title .. "|r\n" .. entry[2]
        end
        local guideText = table.concat(guideLines, "\n\n")
        args.guideText = {
            order = 21,
            type = "description",
            name = guideText,
            fontSize = "small",
        }
    end

    -- Slash Commands
    if content.commands then
        args.commandsHeader = {
            order = 40,
            type = "header",
            name = "Slash Commands",
        }
        local cmdLines = {}
        for _, cmd in ipairs(content.commands) do
            cmdLines[#cmdLines + 1] = "|cff00ff00" .. cmd[1] .. "|r - " .. cmd[2]
        end
        args.commandsList = {
            order = 41,
            type = "description",
            name = table.concat(cmdLines, "\n"),
        }
    end

    return {
        name = addonName,
        type = "group",
        args = args,
    }
end

---------------------------------------------------------------------------
-- CreateModulesPage
-- Flat list of enable/disable toggles for modules/widgets.
---------------------------------------------------------------------------

function BazCore:CreateModulesPage(addonName, config)
    local args = {}

    if config.description then
        args.desc = {
            order = 1,
            type = "description",
            name = config.description,
            fontSize = "small",
        }
    end

    local modules = config.getModules and config.getModules() or {}
    table.sort(modules, function(a, b)
        return (a.name or a.id or "") < (b.name or b.id or "")
    end)

    for i, mod in ipairs(modules) do
        local id = mod.id
        args["mod_" .. id] = {
            order = 10 + i,
            type = "toggle",
            name = mod.name or id,
            desc = mod.desc,
            get = function()
                if config.isEnabled then return config.isEnabled(id) end
                return true
            end,
            set = function(_, val)
                if config.setEnabled then config.setEnabled(id, val) end
            end,
        }
    end

    return {
        name = config.title or "Modules",
        type = "group",
        args = args,
    }
end

---------------------------------------------------------------------------
-- CreateGlobalOptionsPage
-- Per-key override toggles that cascade to all widgets/modules.
---------------------------------------------------------------------------

function BazCore:CreateGlobalOptionsPage(addonName, config)
    local args = {}
    local order = 1

    args.desc = {
        order = order,
        type = "description",
        name = "Global overrides apply to all widgets at once. Enable an override to force its value across every widget, regardless of per-widget settings.",
        fontSize = "small",
    }
    order = order + 1

    for _, def in ipairs(config.overrides or {}) do
        local key = def.key

        args["hdr_" .. key] = {
            order = order,
            type = "header",
            name = def.label or key,
        }
        order = order + 1

        args["enable_" .. key] = {
            order = order,
            type = "toggle",
            name = "Override all modules",
            desc = "When enabled, this value overrides the per-widget setting for '" .. (def.label or key) .. "'.",
            get = function()
                local overrides = config.getOverrides()
                return overrides[key] and overrides[key].enabled or false
            end,
            set = function(_, val)
                config.setOverride(key, "enabled", val)
                BazCore:RefreshOptions(addonName .. "-GlobalOptions")
            end,
        }
        order = order + 1

        if def.type == "toggle" then
            args["val_" .. key] = {
                order = order,
                type = "toggle",
                name = def.label or key,
                get = function()
                    local overrides = config.getOverrides()
                    if overrides[key] and overrides[key].value ~= nil then
                        return overrides[key].value
                    end
                    return def.default
                end,
                set = function(_, val)
                    config.setOverride(key, "value", val)
                end,
                disabled = function()
                    local overrides = config.getOverrides()
                    return not (overrides[key] and overrides[key].enabled)
                end,
            }
        elseif def.type == "range" then
            args["val_" .. key] = {
                order = order,
                type = "range",
                name = def.label or key,
                min = def.min or 0,
                max = def.max or 100,
                step = def.step or 1,
                get = function()
                    local overrides = config.getOverrides()
                    if overrides[key] and overrides[key].value ~= nil then
                        return overrides[key].value
                    end
                    return def.default or def.min or 0
                end,
                set = function(_, val)
                    config.setOverride(key, "value", val)
                end,
                disabled = function()
                    local overrides = config.getOverrides()
                    return not (overrides[key] and overrides[key].enabled)
                end,
            }
        end
        order = order + 1
    end

    return {
        name = "Global Options",
        type = "group",
        args = args,
    }
end
