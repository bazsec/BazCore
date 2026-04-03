---------------------------------------------------------------------------
-- BazCore: Core Module
-- Addon registry, lifecycle management, addon objects
---------------------------------------------------------------------------

BazCore = BazCore or {}
BazCore.addons = {}
BazCore.addonObjects = {}
BazCore.VERSION = "001"

---------------------------------------------------------------------------
-- Addon Object Prototype
-- Other modules extend this via BazCore.AddonMixin
---------------------------------------------------------------------------

local AddonMixin = {}
AddonMixin.__index = AddonMixin
BazCore.AddonMixin = AddonMixin

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
        -- Initialize saved variables
        if config.savedVariable then
            local svName = config.savedVariable
            _G[svName] = _G[svName] or {}

            -- Profile init (if Profiles module loaded and profiles enabled)
            if config.profiles and BazCore.InitProfiles then
                BazCore:InitProfiles(name, config)
            elseif config.defaults then
                local sv = _G[svName]
                for k, v in pairs(config.defaults) do
                    if sv[k] == nil then sv[k] = v end
                end
            end
        end

        -- onLoad callback (SV ready, before UI)
        if config.onLoad then
            config.onLoad(addon)
        end

        -- Build settings panel (Settings module)
        if config.options and BazCore.BuildSettingsPanel then
            BazCore:BuildSettingsPanel(name, config)
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
