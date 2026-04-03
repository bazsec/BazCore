---------------------------------------------------------------------------
-- BazCore: EditMode Module
-- Helpers for integrating frames with Blizzard's Edit Mode
---------------------------------------------------------------------------

local registeredFrames = {} -- [frame] = config

---------------------------------------------------------------------------
-- Selection Overlay
-- Creates a highlight border around a frame when selected in Edit Mode
---------------------------------------------------------------------------

local function CreateSelectionOverlay(frame)
    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(frame:GetFrameLevel() + 10)
    overlay:Hide()

    -- Selection border using simple colored edges
    local thickness = 2
    local color = { 0.2, 0.6, 1.0, 0.8 }

    local top = overlay:CreateTexture(nil, "OVERLAY")
    top:SetHeight(thickness)
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetColorTexture(unpack(color))

    local bottom = overlay:CreateTexture(nil, "OVERLAY")
    bottom:SetHeight(thickness)
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetColorTexture(unpack(color))

    local left = overlay:CreateTexture(nil, "OVERLAY")
    left:SetWidth(thickness)
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetColorTexture(unpack(color))

    local right = overlay:CreateTexture(nil, "OVERLAY")
    right:SetWidth(thickness)
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetColorTexture(unpack(color))

    -- Label in top-left corner
    local label = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("BOTTOMLEFT", overlay, "TOPLEFT", 2, 4)
    label:SetTextColor(0.2, 0.6, 1.0)
    overlay.label = label

    return overlay
end

---------------------------------------------------------------------------
-- Edit Mode State
---------------------------------------------------------------------------

local isEditMode = false

local function EnterEditMode()
    isEditMode = true
    for frame, config in pairs(registeredFrames) do
        if not frame._bazEditOverlay then
            frame._bazEditOverlay = CreateSelectionOverlay(frame)
        end
        frame._bazEditOverlay.label:SetText(config.label or "")
        frame._bazEditOverlay:Show()

        -- Enable dragging in edit mode
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")

        if config.onEnter then
            config.onEnter(frame)
        end
    end
    BazCore:Fire("BAZ_EDITMODE_ENTER")
end

local function ExitEditMode()
    isEditMode = false
    for frame, config in pairs(registeredFrames) do
        if frame._bazEditOverlay then
            frame._bazEditOverlay:Hide()
        end

        -- Restore lock state if configured
        if config.lockKey then
            local locked = BazCore:GetSetting(config.addonName, config.lockKey)
            if locked then
                frame:EnableMouse(false)
            end
        end

        if config.onExit then
            config.onExit(frame)
        end
    end
    BazCore:Fire("BAZ_EDITMODE_EXIT")
end

-- Listen for Blizzard Edit Mode events
if EventRegistry then
    EventRegistry:RegisterCallback("EditMode.Enter", EnterEditMode)
    EventRegistry:RegisterCallback("EditMode.Exit", ExitEditMode)
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function BazCore:RegisterEditModeFrame(frame, config)
    -- config fields:
    --   label      (string) displayed above frame in edit mode
    --   addonName  (string) for settings access
    --   lockKey    (string) setting key that controls lock state
    --   posXKey    (string) setting key for X position
    --   posYKey    (string) setting key for Y position
    --   onEnter    (function) called when edit mode starts
    --   onExit     (function) called when edit mode ends
    --   onMove     (function) called when frame is moved

    registeredFrames[frame] = config

    -- Set up drag handlers for position saving
    frame:SetScript("OnDragStart", function(self)
        if isEditMode then
            self:StartMoving()
        end
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if config.addonName and config.posXKey then
            local x, y = self:GetCenter()
            local ux, uy = UIParent:GetCenter()
            BazCore:SetSetting(config.addonName, config.posXKey, x - ux)
            BazCore:SetSetting(config.addonName, config.posYKey or "posY", y - uy)
        end
        if config.onMove then
            config.onMove(self)
        end
    end)
end

function BazCore:UnregisterEditModeFrame(frame)
    registeredFrames[frame] = nil
    if frame._bazEditOverlay then
        frame._bazEditOverlay:Hide()
        frame._bazEditOverlay = nil
    end
end

function BazCore:IsEditMode()
    return isEditMode
end
