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

function BazCore:RenameProfile(addonName, oldName, newName)
    local config = self.addons[addonName]
    if not config then return false end
    local sv = _G[config.savedVariable]
    if not sv or not sv.profiles then return false end

    if not oldName or not newName or oldName == "" or newName == "" then return false end
    if oldName == newName then return true end
    if oldName == DEFAULT_PROFILE then return false end -- can't rename Default
    if sv.profiles[newName] then return false end -- name already taken

    -- Copy data to new key
    sv.profiles[newName] = sv.profiles[oldName]
    sv.profiles[oldName] = nil

    -- Update active profile reference
    if sv.activeProfile == oldName then
        sv.activeProfile = newName
    end

    -- Update assignments
    if sv.assignments then
        for scope, tbl in pairs(sv.assignments) do
            if type(tbl) == "table" then
                for key, assignedProfile in pairs(tbl) do
                    if assignedProfile == oldName then
                        tbl[key] = newName
                    end
                end
            elseif tbl == oldName then
                sv.assignments[scope] = newName
            end
        end
    end

    BazCore:Fire("BAZ_PROFILE_RENAMED", addonName, oldName, newName)
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

    local displayName = config.title or addonName

    -- Force re-render the profiles panel
    local function RefreshProfilesPanel()
        local profileEntry = BazCore._optionsTables and BazCore._optionsTables[addonName .. "-Profiles"]
        if profileEntry and profileEntry.canvas and BazCore._RenderIntoCanvas then
            local tbl = profileEntry.func
            if type(tbl) == "function" then tbl = tbl() end
            if tbl then BazCore._RenderIntoCanvas(profileEntry.canvas, tbl) end
        end
    end

    -- Build a per-profile child group for each profile
    local function BuildProfileArgs()
        local profileList = BazCore:ListProfiles(addonName)
        local profileGroups = {}

        for i, profileName in ipairs(profileList) do
            local isActive = (profileName == BazCore:GetActiveProfile(addonName))
            local isDefault = (profileName == DEFAULT_PROFILE)

            profileGroups["profile_" .. i] = {
                order = i,
                type = "group",
                name = profileName .. (isActive and " |cff00ff00(active)|r" or ""),
                args = {
                    statusHeader = {
                        order = 1,
                        type = "header",
                        name = "Profile: " .. profileName,
                    },
                    rename = {
                        order = 1.5,
                        type = "input",
                        name = isDefault and "Profile Name (cannot rename Default)" or "Profile Name",
                        desc = isDefault and "" or "Type a new name and press Enter to rename",
                        get = function() return profileName end,
                        set = function(_, val)
                            if isDefault then
                                BazCore:Print("Cannot rename the Default profile.")
                                return
                            end
                            if val and val ~= "" and val ~= profileName then
                                if BazCore:RenameProfile(addonName, profileName, val) then
                                    BazCore:Print("Renamed '" .. profileName .. "' to '" .. val .. "'")
                                    RefreshProfilesPanel()
                                else
                                    BazCore:Print("Could not rename: name may already exist.")
                                end
                            end
                        end,
                    },
                    activate = {
                        order = 2,
                        type = "execute",
                        name = isActive and "|cff00ff00Active Profile|r" or "Switch to This Profile",
                        desc = isActive and "This is the current profile" or "Activate this profile",
                        func = function()
                            if not isActive then
                                BazCore:SetActiveProfile(addonName, profileName)
                                BazCore:Print("Switched to profile: " .. profileName)
                                RefreshProfilesPanel()
                            end
                        end,
                    },
                    copyHeader = {
                        order = 10,
                        type = "header",
                        name = "Actions",
                    },
                    copyFrom = {
                        order = 11,
                        type = "select",
                        name = "Copy Settings From",
                        desc = "Overwrite this profile with settings from another",
                        values = function()
                            local vals = {}
                            for _, name in ipairs(BazCore:ListProfiles(addonName)) do
                                if name ~= profileName then
                                    vals[name] = name
                                end
                            end
                            return vals
                        end,
                        get = function() return "" end,
                        set = function(_, val)
                            if BazCore:CopyProfile(addonName, val, profileName) then
                                BazCore:Print("Copied '" .. val .. "' into '" .. profileName .. "'")
                                if isActive then
                                    BazCore:FireProfileChanged(addonName, profileName, profileName)
                                end
                            end
                        end,
                    },
                    resetProfile = {
                        order = 12,
                        type = "execute",
                        name = "Reset to Defaults",
                        desc = "Reset this profile to default settings",
                        confirm = true,
                        confirmText = "Reset '" .. profileName .. "' to defaults?",
                        func = function()
                            BazCore:ResetProfile(addonName, profileName)
                            BazCore:Print("'" .. profileName .. "' reset to defaults.")
                        end,
                    },
                    deleteProfile = {
                        order = 20,
                        type = "execute",
                        name = "|cffff4444Delete This Profile|r",
                        desc = isDefault and "Cannot delete Default profile" or (isActive and "Cannot delete the active profile" or "Permanently delete this profile"),
                        confirm = not (isDefault or isActive),
                        confirmText = "Delete profile '" .. profileName .. "'? This cannot be undone.",
                        func = function()
                            if isDefault then
                                BazCore:Print("Cannot delete the Default profile.")
                            elseif isActive then
                                BazCore:Print("Cannot delete the active profile. Switch first.")
                            else
                                BazCore:DeleteProfile(addonName, profileName)
                                BazCore:Print("Deleted profile: " .. profileName)
                                RefreshProfilesPanel()
                            end
                        end,
                    },
                    assignHeader = {
                        order = 30,
                        type = "header",
                        name = "Auto-Assignment",
                    },
                    assignDesc = {
                        order = 31,
                        type = "description",
                        name = "Automatically use this profile for:",
                    },
                    assignChar = {
                        order = 32,
                        type = "execute",
                        name = "This Character",
                        func = function()
                            BazCore:AssignProfile(addonName, "character", profileName)
                            BazCore:Print("'" .. profileName .. "' assigned to this character.")
                        end,
                    },
                    assignClass = {
                        order = 33,
                        type = "execute",
                        name = "This Class",
                        func = function()
                            BazCore:AssignProfile(addonName, "class", profileName)
                            BazCore:Print("'" .. profileName .. "' assigned to this class.")
                        end,
                    },
                    assignSpec = {
                        order = 34,
                        type = "execute",
                        name = "This Spec",
                        func = function()
                            if BazCore:AssignProfile(addonName, "spec", profileName) then
                                BazCore:Print("'" .. profileName .. "' assigned to this spec.")
                            else
                                BazCore:Print("Could not determine current spec.")
                            end
                        end,
                    },
                },
            }
        end

        return profileGroups
    end

    return {
        name = "Profiles",
        subtitle = displayName .. " profile management",
        type = "group",
        args = {
            newProfile = {
                order = 1,
                type = "execute",
                name = "Create New Profile",
                desc = "Create a new profile",
                func = function()
                    local profiles = BazCore:ListProfiles(addonName)
                    local name = "New Profile"
                    local num = 1
                    local nameExists = true
                    while nameExists do
                        nameExists = false
                        for _, p in ipairs(profiles) do
                            if p == name then
                                nameExists = true
                                num = num + 1
                                name = "New Profile " .. num
                                break
                            end
                        end
                    end
                    BazCore:CreateProfile(addonName, name)
                    BazCore:Print("Created profile: " .. name)
                    RefreshProfilesPanel()
                end,
            },
            profiles = {
                order = 10,
                type = "group",
                name = "Profiles",
                args = BuildProfileArgs(),
            },
        },
    }
end
