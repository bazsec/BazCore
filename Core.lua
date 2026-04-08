---------------------------------------------------------------------------
-- BazCore: Core Module
-- Addon registry, lifecycle management, addon objects
---------------------------------------------------------------------------

BazCore = BazCore or {}
BazCore.addons = {}
BazCore.addonObjects = {}
BazCore.VERSION = C_AddOns.GetAddOnMetadata("BazCore", "Version") or "?"

---------------------------------------------------------------------------
-- Addon Object Prototype
-- Other modules extend this via BazCore.AddonMixin
---------------------------------------------------------------------------

local AddonMixin = {}
AddonMixin.__index = AddonMixin
BazCore.AddonMixin = AddonMixin

function AddonMixin:GetSetting(key)
    if self.db and self.db.profile then return self.db.profile[key] end
end

function AddonMixin:SetSetting(key, value)
    if self.db and self.db.profile then self.db.profile[key] = value end
end

---------------------------------------------------------------------------
-- Lifecycle: PLAYER_LOGIN queue
---------------------------------------------------------------------------

local loginReady = false
local loginQueue = {}

local lifecycleFrame = CreateFrame("Frame")
lifecycleFrame:RegisterEvent("PLAYER_LOGIN")
lifecycleFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        loginReady = true
        for _, fn in ipairs(loginQueue) do
            fn()
        end
        wipe(loginQueue)
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

function BazCore:QueueForLogin(fn)
    if loginReady then
        fn()
    else
        table.insert(loginQueue, fn)
    end
end

---------------------------------------------------------------------------
-- Addon Registration
---------------------------------------------------------------------------

function BazCore:RegisterAddon(name, config)
    self.addons[name] = config

    -- Create addon object with convenience methods
    local addon = setmetatable({
        name = name,
        config = config,
        loaded = false,
    }, AddonMixin)
    self.addonObjects[name] = addon

    -- Deferred init on ADDON_LOADED
    EventUtil.ContinueOnAddOnLoaded(name, function()
        -- Initialize saved variables (for addons that still have their own SV, e.g. BNC history)
        if config.savedVariable then
            local svName = config.savedVariable
            _G[svName] = _G[svName] or {}

            if not config.profiles and config.defaults then
                local sv = _G[svName]
                for k, v in pairs(config.defaults) do
                    if sv[k] == nil then sv[k] = v end
                end
            end
        end

        -- Unified profile setup: addon data lives in BazCoreDB.profiles
        if config.profiles and BazCore.InitAddonProfile then
            -- Migrate old per-addon SV profiles into BazCoreDB (one-time)
            if config.savedVariable and BazCore.MigrateAddonProfiles then
                BazCore:MigrateAddonProfiles(name, config.savedVariable)
            end

            -- Ensure addon section exists with defaults in active profile
            BazCore:InitAddonProfile(name, config)

            -- Auto-wire addon.db.profile proxy
            if BazCore.CreateDBProxy then
                addon.db = BazCore:CreateDBProxy(name)
            end
        end

        -- onLoad callback (SV ready, before UI)
        if config.onLoad then
            config.onLoad(addon)
        end


        -- Register slash commands (Commands module)
        if config.slash and BazCore.RegisterCommands then
            BazCore:RegisterCommands(name, config)
        end

        -- Register minimap entry (MinimapButton module)
        if config.minimap and BazCore.RegisterMinimapEntry then
            BazCore:RegisterMinimapEntry(name, config.minimap)
        end

        addon.loaded = true

        -- onReady callback (after SV + UI init + PLAYER_LOGIN)
        if config.onReady then
            BazCore:QueueForLogin(function()
                config.onReady(addon)
            end)
        end
    end)

    return addon
end

function BazCore:GetAddon(name)
    return self.addonObjects[name]
end

---------------------------------------------------------------------------
-- BazCore's own settings page (registered after all modules load)
---------------------------------------------------------------------------

-- Initialize unified profile structure early (before addons load)
EventUtil.ContinueOnAddOnLoaded("BazCore", function()
    BazCoreDB = BazCoreDB or {}
    if BazCore.InitProfiles then
        BazCore:InitProfiles()
    end
end)

BazCore:QueueForLogin(function()
    if not BazCore.RegisterOptionsTable then return end

    BazCoreDB = BazCoreDB or {}
    BazCoreDB.minimap = BazCoreDB.minimap or { hide = false }

    BazCoreDB.welcomeMessage = BazCoreDB.welcomeMessage == nil and true or BazCoreDB.welcomeMessage

    -- Landing page
    BazCore:RegisterOptionsTable("BazCore", function()
        local landing = BazCore:CreateLandingPage("BazCore", {
            subtitle = "Shared framework",
            description = "Shared framework library for the Baz Suite of addons. " ..
                "Provides profiles, settings panels, Edit Mode integration, events, " ..
                "slash commands, minimap button, and UI utilities.",
            features = "Declarative addon registration with lifecycle management. " ..
                "Profile system with per-character/class/spec assignment. " ..
                "Two-column options panel with branded headers. " ..
                "Edit Mode framework with grid snapping and settings popup. " ..
                "Object pooling, timers, animations, and string safety utilities.",
        })

        -- Add dynamic Baz Suite versions and memory sections
        local versionLines = {}
        local sorted = {}
        for name, config in pairs(BazCore.addons) do
            sorted[#sorted + 1] = { name = config.title or name, toc = config.savedVariable and name }
        end
        table.sort(sorted, function(a, b) return a.name < b.name end)
        for _, info in ipairs(sorted) do
            local ver = "?"
            if info.toc then
                ver = C_AddOns.GetAddOnMetadata(info.toc, "Version") or "?"
            end
            versionLines[#versionLines + 1] = "|cffffffff" .. info.name .. "|r v" .. ver
        end

        UpdateAddOnMemoryUsage()
        local totalMem = 0
        local memLines = {}
        local memAddons = { "BazCore" }
        for name in pairs(BazCore.addons) do
            memAddons[#memAddons + 1] = name
        end
        table.sort(memAddons)
        for _, name in ipairs(memAddons) do
            local mem = GetAddOnMemoryUsage(name)
            if mem and mem > 0 then
                totalMem = totalMem + mem
                local display = C_AddOns.GetAddOnMetadata(name, "Title") or name
                memLines[#memLines + 1] = string.format("|cffffffff%s|r — %.0f KB", display, mem)
            end
        end
        memLines[#memLines + 1] = string.format("|cff3399ffTotal|r — %.0f KB", totalMem)

        landing.args.suiteHeader = { order = 30, type = "header", name = "Baz Suite" }
        landing.args.versionList = { order = 31, type = "description", name = "|cff3399ffBazCore|r v" .. BazCore.VERSION .. "\n" .. table.concat(versionLines, "\n") }
        landing.args.memHeader = { order = 40, type = "header", name = "Memory Usage" }
        landing.args.memList = { order = 41, type = "description", name = table.concat(memLines, "\n") }
        landing.args.memRefresh = { order = 42, type = "execute", name = "Refresh Memory", func = function() BazCore:RefreshOptions("BazCore") end }

        return landing
    end)
    BazCore:AddToSettings("BazCore", "BazCore")

    -- Settings subcategory
    BazCore:RegisterOptionsTable("BazCore-Settings", function()
        return {
            name = "Settings",
            type = "group",
            args = {
                minimapBtn = {
                    order = 1,
                    type = "toggle",
                    name = "Show Minimap Button",
                    desc = "Show or hide the shared Baz minimap button",
                    get = function() return not BazCoreDB.minimap.hide end,
                    set = function(_, val)
                        BazCoreDB.minimap.hide = not val
                        if val then
                            BazCore:ShowMinimapButton()
                        else
                            BazCore:HideMinimapButton()
                        end
                    end,
                },
                welcomeMsg = {
                    order = 2,
                    type = "toggle",
                    name = "Show Welcome Messages",
                    desc = "Show addon loaded messages in chat on login",
                    get = function() return BazCoreDB.welcomeMessage end,
                    set = function(_, val) BazCoreDB.welcomeMessage = val end,
                },
            },
        }
    end)
    BazCore:AddToSettings("BazCore-Settings", "Settings", "BazCore")

    -- Profiles subcategory (unified for all Baz Suite addons)
    if BazCore.GetProfileOptionsTable then
        BazCore:RegisterOptionsTable("BazCore-Profiles", function()
            return BazCore:GetProfileOptionsTable()
        end)
        BazCore:AddToSettings("BazCore-Profiles", "Profiles", "BazCore")
    end
end)

---------------------------------------------------------------------------
-- Do Not Disturb: environmental state check
-- Returns true if player is in combat or an encounter is active
---------------------------------------------------------------------------

local encounterActive = false

local dndFrame = CreateFrame("Frame")
dndFrame:RegisterEvent("ENCOUNTER_START")
dndFrame:RegisterEvent("ENCOUNTER_END")
dndFrame:SetScript("OnEvent", function(_, event)
    encounterActive = (event == "ENCOUNTER_START")
end)

function BazCore:IsDND()
    return InCombatLockdown() or encounterActive
end

---------------------------------------------------------------------------
-- Notification Bridge
-- Routes to BazNotificationCenter if installed, nil otherwise
---------------------------------------------------------------------------

function BazCore:PushNotification(data)
    if BazNotificationCenter and BazNotificationCenter.Push then
        return BazNotificationCenter:Push(data)
    end
end
