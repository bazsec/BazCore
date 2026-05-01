-- SPDX-License-Identifier: GPL-2.0-or-later
---------------------------------------------------------------------------
-- BazCore: Compartment Module
-- Addon Compartment integration (Dragonflight+ minimap dropdown)
---------------------------------------------------------------------------

local compartmentAnchor = nil

local function OnClick(_, _, _, _, button)
    if button == "LeftButton" then
        if not compartmentAnchor then
            compartmentAnchor = CreateFrame("Frame", nil, UIParent)
        end
        MenuUtil.CreateContextMenu(compartmentAnchor, function(_, rootDescription)
            rootDescription:CreateTitle("Baz Addons")
            local sorted = {}
            for name, config in pairs(BazCore.addons) do
                table.insert(sorted, { name = name, config = config })
            end
            table.sort(sorted, function(a, b) return a.name < b.name end)
            for _, item in ipairs(sorted) do
                rootDescription:CreateButton(item.config.title or item.name, function()
                    BazCore:OpenSettings(item.name)
                end)
            end
        end)
    end
end

local function OnEnter(_, btn)
    GameTooltip:SetOwner(btn, "ANCHOR_NONE")
    GameTooltip:SetPoint("TOPRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    GameTooltip:SetText("Baz Addons", 0.2, 0.6, 1.0)
    for name, config in pairs(BazCore.addons) do
        GameTooltip:AddLine(config.title or name, 0.8, 0.8, 0.8)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click to open settings", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

local function OnLeave()
    GameTooltip:Hide()
end

-- Expose as globals for the TOC AddonCompartment fields
function BazCore_Compartment_OnClick(...)
    OnClick(...)
end

function BazCore_Compartment_OnEnter(...)
    OnEnter(...)
end

function BazCore_Compartment_OnLeave(...)
    OnLeave(...)
end
