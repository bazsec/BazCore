---------------------------------------------------------------------------
-- BazCore: Profiles Module
-- Named profile system with per-character/class/spec assignment
---------------------------------------------------------------------------

local DEFAULT_PROFILE = "Default"

-- Profile change callbacks per addon
local profileCallbacks = {} -- [addonName] = { handler1, handler2, ... }

---------------------------------------------------------------------------
-- Character Identity
---------------------------------------------------------------------------

local function GetCharacterKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    return name and realm and (name .. " - " .. realm) or "Unknown"
end

local function GetClassKey()
    local _, class = UnitClass("player")
    return class or "UNKNOWN"
end

local function GetSpecKey()
    local class = GetClassKey()
    local specIndex = GetSpecialization()
    if not specIndex then return nil end
    local _, specName = GetSpecializationInfo(specIndex)
    return specName and (class .. ":" .. specName) or nil
end

---------------------------------------------------------------------------
-- Profile Initialization
-- Called from Core.lua during ADDON_LOADED when profiles = true
---------------------------------------------------------------------------

function BazCore:InitProfiles(addonName, config)
    local svName = config.savedVariable
    local sv = _G[svName]

    -- Ensure profile structure exists
    if not sv.profiles then
        sv.profiles = {}
    end
    if not sv.assignments then
        sv.assignments = {}
    end

    -- Create Default profile from defaults if it doesn't exist
    if not sv.profiles[DEFAULT_PROFILE] then
        sv.profiles[DEFAULT_PROFILE] = {}
        if config.defaults then
            for k, v in pairs(config.defaults) do
                if type(v) == "table" then
                    sv.profiles[DEFAULT_PROFILE][k] = CopyTable(v)
                else
                    sv.profiles[DEFAULT_PROFILE][k] = v
                end
            end
        end
    end

    -- Resolve which profile this character should use
    sv.activeProfile = self:ResolveProfile(addonName) or DEFAULT_PROFILE

    -- Ensure the resolved profile exists
    if not sv.profiles[sv.activeProfile] then
        sv.profiles[sv.activeProfile] = {}
        if config.defaults then
            for k, v in pairs(config.defaults) do
                if type(v) == "table" then
                    sv.profiles[sv.activeProfile][k] = CopyTable(v)
                else
                    sv.profiles[sv.activeProfile][k] = v
                end
            end
        end
    end

    -- Create proxy table that reads/writes to the active profile
    -- Settings.lua uses this so the Settings API always hits the right profile
    local proxy = setmetatable({}, {
        __index = function(_, key)
            local profile = sv.profiles[sv.activeProfile]
            return profile and profile[key]
        end,
        __newindex = function(_, key, value)
            local profile = sv.profiles[sv.activeProfile]
            if profile then
                profile[key] = value
            end
        end,
        -- pairs() support for iteration
        __pairs = function(_)
            return next, sv.profiles[sv.activeProfile] or {}, nil
        end,
    })
    config._settingsProxy = proxy

    -- Fill in any missing defaults in the active profile
    local activeProfile = sv.profiles[sv.activeProfile]
    if config.defaults and activeProfile then
        for k, v in pairs(config.defaults) do
            if activeProfile[k] == nil then
                if type(v) == "table" then
                    activeProfile[k] = CopyTable(v)
                else
                    activeProfile[k] = v
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Profile Resolution
-- Determines which profile a character should use based on assignments
---------------------------------------------------------------------------

function BazCore:ResolveProfile(addonName)
    local config = self.addons[addonName]
    if not config then return DEFAULT_PROFILE end
    local sv = _G[config.savedVariable]
    if not sv or not sv.assignments then return DEFAULT_PROFILE end

    local assignments = sv.assignments

    -- Priority 1: Character-specific
    local charKey = GetCharacterKey()
    if assignments[charKey] then
        return assignments[charKey]
    end

    -- Priority 2: Class + Spec
    local specKey = GetSpecKey()
    if specKey and assignments[specKey] then
        return assignments[specKey]
    end

    -- Priority 3: Class only
    local classKey = GetClassKey()
    if assignments[classKey] then
        return assignments[classKey]
    end

    -- Priority 4: Default
    return DEFAULT_PROFILE
end

---------------------------------------------------------------------------
-- Profile Management API
---------------------------------------------------------------------------

function BazCore:GetActiveProfile(addonName)
    local config = self.addons[addonName]
    if not config then return nil end
    local sv = _G[config.savedVariable]
    return sv and sv.activeProfile or DEFAULT_PROFILE
end

function BazCore:SetActiveProfile(addonName, profileName)
    local config = self.addons[addonName]
    if not config then return false end
    local sv = _G[config.savedVariable]
    if not sv or not sv.profiles[profileName] then return false end

    local oldProfile = sv.activeProfile
    sv.activeProfile = profileName

    -- Fill defaults into newly activated profile
    local profile = sv.profiles[profileName]
    if config.defaults then
        for k, v in pairs(config.defaults) do
            if profile[k] == nil then
                if type(v) == "table" then
                    profile[k] = CopyTable(v)
                else
                    profile[k] = v
                end
            end
        end
    end

    -- Fire callbacks
    self:FireProfileChanged(addonName, profileName, oldProfile)
    return true
end

function BazCore:CreateProfile(addonName, profileName)
    local config = self.addons[addonName]
    if not config then return false end
    local sv = _G[config.savedVariable]
    if not sv then return false end

    sv.profiles = sv.profiles or {}
    if sv.profiles[profileName] then return false end -- already exists

    -- New profile starts with defaults
    sv.profiles[profileName] = {}
    if config.defaults then
        for k, v in pairs(config.defaults) do
            if type(v) == "table" then
                sv.profiles[profileName][k] = CopyTable(v)
            else
                sv.profiles[profileName][k] = v
            end
        end
    end

    BazCore:Fire("BAZ_PROFILE_CREATED", addonName, profileName)
    return true
end

function BazCore:CopyProfile(addonName, fromName, toName)
    local config = self.addons[addonName]
    if not config then return false end
    local sv = _G[config.savedVariable]
    if not sv or not sv.profiles then return false end

    local source = sv.profiles[fromName]
    if not source then return false end

    -- Create target if it doesn't exist
    if not sv.profiles[toName] then
        sv.profiles[toName] = {}
    end

    -- Deep copy
    wipe(sv.profiles[toName])
    for k, v in pairs(source) do
        if type(v) == "table" then
            sv.profiles[toName][k] = CopyTable(v)
        else
            sv.profiles[toName][k] = v
        end
    end

    BazCore:Fire("BAZ_PROFILE_COPIED", addonName, fromName, toName)
    return true
end

function BazCore:DeleteProfile(addonName, profileName)
    local config = self.addons[addonName]
    if not config then return false end
    local sv = _G[config.savedVariable]
    if not sv or not sv.profiles then return false end

    -- Cannot delete the active profile
    if sv.activeProfile == profileName then return false end
    -- Cannot delete Default
    if profileName == DEFAULT_PROFILE then return false end

    sv.profiles[profileName] = nil

    -- Clean up assignments pointing to deleted profile
    if sv.assignments then
        for scope, assignedProfile in pairs(sv.assignments) do
            if assignedProfile == profileName then
                sv.assignments[scope] = nil
            end
        end
    end

    BazCore:Fire("BAZ_PROFILE_DELETED", addonName, profileName)
    return true
end

function BazCore:ResetProfile(addonName, profileName)
    local config = self.addons[addonName]
    if not config then return false end
    local sv = _G[config.savedVariable]
    if not sv or not sv.profiles then return false end

    profileName = profileName or sv.activeProfile
    local profile = sv.profiles[profileName]
    if not profile then return false end

    wipe(profile)
    if config.defaults then
        for k, v in pairs(config.defaults) do
            if type(v) == "table" then
                profile[k] = CopyTable(v)
            else
                profile[k] = v
            end
        end
    end

    if profileName == sv.activeProfile then
        self:FireProfileChanged(addonName, profileName, profileName)
    end

    BazCore:Fire("BAZ_PROFILE_RESET", addonName, profileName)
    return true
end

function BazCore:ListProfiles(addonName)
    local config = self.addons[addonName]
    if not config then return {} end
    local sv = _G[config.savedVariable]
    if not sv or not sv.profiles then return {} end

    local list = {}
    for name in pairs(sv.profiles) do
        table.insert(list, name)
    end
    table.sort(list)
    return list
end

---------------------------------------------------------------------------
-- Profile Assignment
---------------------------------------------------------------------------

function BazCore:AssignProfile(addonName, scope, profileName)
    -- scope: "character", "class", "spec"
    local config = self.addons[addonName]
    if not config then return false end
    local sv = _G[config.savedVariable]
    if not sv then return false end

    sv.assignments = sv.assignments or {}

    local scopeKey
    if scope == "character" then
        scopeKey = GetCharacterKey()
    elseif scope == "class" then
        scopeKey = GetClassKey()
    elseif scope == "spec" then
        scopeKey = GetSpecKey()
        if not scopeKey then return false end
    else
        return false
    end

    if profileName then
        sv.assignments[scopeKey] = profileName
    else
        sv.assignments[scopeKey] = nil -- clear assignment
    end

    return true
end

---------------------------------------------------------------------------
-- Profile Change Callbacks
---------------------------------------------------------------------------

function BazCore:FireProfileChanged(addonName, newProfile, oldProfile)
    local callbacks = profileCallbacks[addonName]
    if callbacks then
        for _, fn in ipairs(callbacks) do
            fn(newProfile, oldProfile)
        end
    end
    BazCore:Fire("BAZ_PROFILE_CHANGED", addonName, newProfile, oldProfile)
end

-- AddonMixin method
local AddonMixin = BazCore.AddonMixin

function AddonMixin:OnProfileChanged(handler)
    if not profileCallbacks[self.name] then
        profileCallbacks[self.name] = {}
    end
    table.insert(profileCallbacks[self.name], handler)
end

---------------------------------------------------------------------------
-- Auto-Generated Profile Options Table
-- Returns an AceConfig-style options table for OptionsPanel.lua
---------------------------------------------------------------------------

function BazCore:GetProfileOptionsTable(addonName)
    local config = self.addons[addonName]
    if not config then return nil end

    return {
        name = "Profiles",
        type = "group",
        args = {
            desc = {
                order = 1,
                type = "description",
                name = "Manage profiles for " .. (config.title or addonName) .. ". Profiles store all settings and can be assigned per character, class, or specialization.\n",
            },
            currentProfile = {
                order = 2,
                type = "select",
                name = "Active Profile",
                desc = "Select which profile to use",
                values = function()
                    local vals = {}
                    for _, name in ipairs(BazCore:ListProfiles(addonName)) do
                        vals[name] = name
                    end
                    return vals
                end,
                get = function()
                    return BazCore:GetActiveProfile(addonName)
                end,
                set = function(_, val)
                    BazCore:SetActiveProfile(addonName, val)
                end,
            },
            spacer1 = { order = 3, type = "description", name = "\n" },
            newHeader = {
                order = 10,
                type = "header",
                name = "Create Profile",
            },
            newName = {
                order = 11,
                type = "input",
                name = "New Profile Name",
                desc = "Enter a name for the new profile",
                get = function() return "" end,
                set = function(_, val)
                    if val and val ~= "" then
                        if BazCore:CreateProfile(addonName, val) then
                            BazCore:Print("Created profile: " .. val)
                        end
                    end
                end,
            },
            copyHeader = {
                order = 20,
                type = "header",
                name = "Copy / Delete",
            },
            copyFrom = {
                order = 21,
                type = "select",
                name = "Copy From",
                desc = "Select a profile to copy settings from into the active profile",
                values = function()
                    local vals = {}
                    for _, name in ipairs(BazCore:ListProfiles(addonName)) do
                        if name ~= BazCore:GetActiveProfile(addonName) then
                            vals[name] = name
                        end
                    end
                    return vals
                end,
                get = function() return "" end,
                set = function(_, val)
                    local active = BazCore:GetActiveProfile(addonName)
                    if BazCore:CopyProfile(addonName, val, active) then
                        BazCore:Print("Copied profile '" .. val .. "' into '" .. active .. "'")
                        BazCore:FireProfileChanged(addonName, active, active)
                    end
                end,
            },
            deleteProfile = {
                order = 22,
                type = "select",
                name = "Delete Profile",
                desc = "Select a profile to delete (cannot delete active or Default)",
                values = function()
                    local vals = {}
                    local active = BazCore:GetActiveProfile(addonName)
                    for _, name in ipairs(BazCore:ListProfiles(addonName)) do
                        if name ~= active and name ~= DEFAULT_PROFILE then
                            vals[name] = name
                        end
                    end
                    return vals
                end,
                get = function() return "" end,
                set = function(_, val)
                    if BazCore:DeleteProfile(addonName, val) then
                        BazCore:Print("Deleted profile: " .. val)
                    end
                end,
            },
            resetHeader = {
                order = 30,
                type = "header",
                name = "Reset",
            },
            resetProfile = {
                order = 31,
                type = "execute",
                name = "Reset Active Profile",
                desc = "Reset the current profile to default settings",
                confirm = true,
                confirmText = "Are you sure you want to reset the active profile to defaults?",
                func = function()
                    BazCore:ResetProfile(addonName)
                    BazCore:Print("Profile reset to defaults")
                end,
            },
            assignHeader = {
                order = 40,
                type = "header",
                name = "Auto-Assignment",
            },
            assignDesc = {
                order = 41,
                type = "description",
                name = "Assign profiles to automatically activate for specific characters, classes, or specs.\n",
            },
            assignChar = {
                order = 42,
                type = "execute",
                name = "Assign to This Character",
                desc = "Assign the active profile to this character",
                func = function()
                    local active = BazCore:GetActiveProfile(addonName)
                    BazCore:AssignProfile(addonName, "character", active)
                    BazCore:Print("Assigned '" .. active .. "' to this character")
                end,
            },
            assignClass = {
                order = 43,
                type = "execute",
                name = "Assign to This Class",
                desc = "Assign the active profile to all characters of this class",
                func = function()
                    local active = BazCore:GetActiveProfile(addonName)
                    BazCore:AssignProfile(addonName, "class", active)
                    BazCore:Print("Assigned '" .. active .. "' to this class")
                end,
            },
            assignSpec = {
                order = 44,
                type = "execute",
                name = "Assign to This Spec",
                desc = "Assign the active profile to this class and specialization",
                func = function()
                    local active = BazCore:GetActiveProfile(addonName)
                    if BazCore:AssignProfile(addonName, "spec", active) then
                        BazCore:Print("Assigned '" .. active .. "' to this spec")
                    else
                        BazCore:Print("Could not determine current spec")
                    end
                end,
            },
        },
    }
end
