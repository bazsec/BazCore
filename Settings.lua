---------------------------------------------------------------------------
-- BazCore: Settings Module
-- Dragonflight+ vertical layout settings panel builder
---------------------------------------------------------------------------

-- Map Lua types to Settings.VarType enum
local function GetVarType(val)
    local t = type(val)
    if t == "boolean" then return Settings.VarType.Boolean end
    if t == "number" then return Settings.VarType.Number end
    if t == "string" then return Settings.VarType.String end
    return Settings.VarType.String
end

---------------------------------------------------------------------------
-- Settings Storage
---------------------------------------------------------------------------

function BazCore:GetSetting(addonName, key)
    local addonObj = self.addonObjects[addonName]
    if addonObj and addonObj.db and addonObj.db.profile then
        local val = addonObj.db.profile[key]
        if val ~= nil then return val end
    end

    local config = self.addons[addonName]
    return config and config.defaults and config.defaults[key]
end

function BazCore:SetSetting(addonName, key, value)
    local config = self.addons[addonName]
    if not config then return end

    local addonObj = self.addonObjects[addonName]
    if addonObj and addonObj.db and addonObj.db.profile then
        addonObj.db.profile[key] = value
    end

    if config.onChange then
        config.onChange(key, value)
    end

    -- Fire event for cross-addon awareness
    BazCore:Fire("BAZ_SETTING_CHANGED", addonName, key, value)
end

function BazCore:OpenSettings(addonName)
    local config = self.addons[addonName]
    if config and config.category then
        Settings.OpenToCategory(config.category:GetID())
    end
end

---------------------------------------------------------------------------
-- AddonMixin convenience methods
---------------------------------------------------------------------------

local AddonMixin = BazCore.AddonMixin

function AddonMixin:GetSetting(key)
    return BazCore:GetSetting(self.name, key)
end

function AddonMixin:SetSetting(key, value)
    BazCore:SetSetting(self.name, key, value)
end

function AddonMixin:OpenSettings()
    BazCore:OpenSettings(self.name)
end

---------------------------------------------------------------------------
-- Settings Panel Builder
---------------------------------------------------------------------------

function BazCore:BuildSettingsPanel(addonName, config)
    local category = Settings.RegisterVerticalLayoutCategory(config.title or addonName)
    config.category = category

    -- Use addon db proxy if available, otherwise raw SV
    local addonObj = self.addonObjects[addonName]
    local sv = (addonObj and addonObj.db and addonObj.db.profile) or _G[config.savedVariable]

    for _, opt in ipairs(config.options) do
        if opt.type == "toggle" then
            local variable = addonName .. "_" .. opt.key
            local defaultVal = config.defaults and config.defaults[opt.key]
            if defaultVal == nil then defaultVal = false end
            local setting = Settings.RegisterAddOnSetting(
                category, variable, opt.key, sv,
                GetVarType(defaultVal), opt.label, defaultVal
            )
            Settings.CreateCheckbox(category, setting, opt.desc or "")
            if config.onChange then
                local key = opt.key
                setting:SetValueChangedCallback(function(_, val)
                    config.onChange(key, val)
                end)
            end

        elseif opt.type == "slider" then
            local variable = addonName .. "_" .. opt.key
            local defaultVal = config.defaults and config.defaults[opt.key]
            if defaultVal == nil then defaultVal = opt.min or 0 end
            local setting = Settings.RegisterAddOnSetting(
                category, variable, opt.key, sv,
                GetVarType(defaultVal), opt.label, defaultVal
            )
            local sliderOpts = Settings.CreateSliderOptions(
                opt.min or 0, opt.max or 100, opt.step or 1
            )
            sliderOpts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
            Settings.CreateSlider(category, setting, sliderOpts, opt.desc or "")
            if config.onChange then
                local key = opt.key
                setting:SetValueChangedCallback(function(_, val)
                    config.onChange(key, val)
                end)
            end

        elseif opt.type == "dropdown" then
            local variable = addonName .. "_" .. opt.key
            local defaultVal = config.defaults and config.defaults[opt.key]
            local setting = Settings.RegisterAddOnSetting(
                category, variable, opt.key, sv,
                GetVarType(defaultVal), opt.label, defaultVal
            )
            local values = opt.values -- { {value, label}, {value, label}, ... }
            local function GetOptions()
                local container = Settings.CreateControlTextContainer()
                for _, entry in ipairs(values) do
                    container:Add(entry[1], entry[2])
                end
                return container:GetData()
            end
            Settings.CreateDropdown(category, setting, GetOptions, opt.desc or "")
            if config.onChange then
                local key = opt.key
                setting:SetValueChangedCallback(function(_, val)
                    config.onChange(key, val)
                end)
            end
        end
    end

    Settings.RegisterAddOnCategory(category)
end
