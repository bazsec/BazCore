-- SPDX-License-Identifier: GPL-2.0-or-later
---------------------------------------------------------------------------
-- BazCore: AddonListButton
--
-- Adds an "Addon Options" button to Blizzard's AddOn List window, sitting
-- to the left of the "Reload UI / Okay" button. Clicking it closes the
-- AddOn List and opens the in-game Settings panel so the user can jump
-- to any addon's options page without reopening menus.
---------------------------------------------------------------------------

local function OpenAddonOptions()
    HideUIPanel(AddonList)
    -- Open directly to BazCore's options category - puts the user on the
    -- correct Settings tab with the Baz Suite sidebar expanded and ready.
    if BazCore.OpenOptionsPanel then
        BazCore:OpenOptionsPanel("BazCore")
        return
    end
    -- Fallback if OptionsPanel module isn't loaded
    if SettingsPanel and SettingsPanel.Open then
        SettingsPanel:Open()
    end
end

local function AttachAddonOptionsButton()
    if not AddonList or not AddonList.OkayButton then return end
    if AddonList.BazCoreAddonOptionsButton then return end

    local btn = CreateFrame("Button", "BazCoreAddonOptionsButton", AddonList, "UIPanelButtonTemplate")
    btn:SetText("Addon Options")
    btn:SetSize(AddonList.OkayButton:GetWidth() + 60, AddonList.OkayButton:GetHeight())
    btn:SetPoint("RIGHT", AddonList.OkayButton, "LEFT", -4, 0)
    btn:SetScript("OnClick", OpenAddonOptions)

    AddonList.BazCoreAddonOptionsButton = btn
end

-- AddonList may be load-on-demand depending on the client version. Try at
-- login and also when the Blizzard_AddonList addon loads.
BazCore:QueueForLogin(AttachAddonOptionsButton, "AddonListButton:Attach")
EventUtil.ContinueOnAddOnLoaded("Blizzard_AddonList", AttachAddonOptionsButton)
