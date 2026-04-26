---------------------------------------------------------------------------
-- BazCore: UI Module
-- Colors, branded print, backdrop, fade, tooltip, draggable, status bar
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Color Palette
---------------------------------------------------------------------------

BazCore.colors = {
    brand       = { 0.2, 0.6, 1.0 },
    brandHex    = "3399ff",
    bg          = { 0.05, 0.05, 0.08, 0.88 },
    border      = { 0.3, 0.3, 0.35, 0.8 },
    dim         = { 0.5, 0.5, 0.55 },
    success     = { 0.3, 0.85, 0.3 },
    error       = { 1.0, 0.3, 0.3 },
    warning     = { 1.0, 0.8, 0.2 },
    white       = { 1.0, 1.0, 1.0 },
    tank        = { 0.3, 0.5, 1.0 },
    healer      = { 0.3, 0.9, 0.3 },
    dps         = { 0.9, 0.3, 0.3 },
}

-- Standard backdrop definition used across Baz addons
BazCore.backdrop = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

---------------------------------------------------------------------------
-- Branded Print
---------------------------------------------------------------------------

local AddonMixin = BazCore.AddonMixin

function AddonMixin:Print(...)
    local displayName = self.config.title or self.name
    local msg = table.concat({...}, " ")
    print(string.format("|cff%s%s|r: %s", BazCore.colors.brandHex, displayName, msg))
end

function AddonMixin:Printf(fmt, ...)
    local displayName = self.config.title or self.name
    local msg = string.format(fmt, ...)
    print(string.format("|cff%s%s|r: %s", BazCore.colors.brandHex, displayName, msg))
end

-- Static print (not tied to an addon)
function BazCore:Print(...)
    local msg = table.concat({...}, " ")
    print(string.format("|cff%sBazCore|r: %s", self.colors.brandHex, msg))
end

---------------------------------------------------------------------------
-- Panel Factory
-- Creates a BackdropTemplate frame with the standard Baz dark theme
---------------------------------------------------------------------------

function BazCore:CreatePanel(parent, width, height)
    local frame = CreateFrame("Frame", nil, parent or UIParent, "BackdropTemplate")
    if width and height then
        frame:SetSize(width, height)
    end
    frame:SetBackdrop(self.backdrop)
    frame:SetBackdropColor(unpack(self.colors.bg))
    frame:SetBackdropBorderColor(unpack(self.colors.border))
    return frame
end

---------------------------------------------------------------------------
-- Fade Helpers
---------------------------------------------------------------------------

function BazCore:FadeIn(frame, duration, toAlpha)
    duration = duration or 0.3
    toAlpha = toAlpha or 1.0
    if not frame.bazFadeAG then
        frame.bazFadeAG = frame:CreateAnimationGroup()
        frame.bazFadeAnim = frame.bazFadeAG:CreateAnimation("Alpha")
        frame.bazFadeAG:SetScript("OnFinished", function()
            frame:SetAlpha(frame.bazFadeTarget or 1.0)
        end)
    end
    frame.bazFadeAG:Stop()
    frame.bazFadeTarget = toAlpha
    frame.bazFadeAnim:SetFromAlpha(frame:GetAlpha())
    frame.bazFadeAnim:SetToAlpha(toAlpha)
    frame.bazFadeAnim:SetDuration(duration)
    frame.bazFadeAnim:SetSmoothing("IN_OUT")
    frame.bazFadeAG:Play()
end

function BazCore:FadeOut(frame, duration, onComplete)
    duration = duration or 0.3
    if not frame.bazFadeAG then
        frame.bazFadeAG = frame:CreateAnimationGroup()
        frame.bazFadeAnim = frame.bazFadeAG:CreateAnimation("Alpha")
        frame.bazFadeAG:SetScript("OnFinished", function()
            frame:SetAlpha(frame.bazFadeTarget or 0)
            if frame.bazFadeOnComplete then
                frame.bazFadeOnComplete()
                frame.bazFadeOnComplete = nil
            end
        end)
    end
    frame.bazFadeAG:Stop()
    frame.bazFadeTarget = 0
    frame.bazFadeOnComplete = onComplete
    frame.bazFadeAnim:SetFromAlpha(frame:GetAlpha())
    frame.bazFadeAnim:SetToAlpha(0)
    frame.bazFadeAnim:SetDuration(duration)
    frame.bazFadeAnim:SetSmoothing("IN_OUT")
    frame.bazFadeAG:Play()
end

---------------------------------------------------------------------------
-- Tooltip Helper
-- Attaches tooltip show/hide to a frame
---------------------------------------------------------------------------

function BazCore:Tooltip(frame, text, anchor)
    anchor = anchor or "ANCHOR_TOP"

    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, anchor)
        -- Support multi-line via \n
        local lines = { strsplit("\n", text) }
        GameTooltip:SetText(lines[1] or "", 1, 1, 1)
        for i = 2, #lines do
            GameTooltip:AddLine(lines[i], 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

---------------------------------------------------------------------------
-- Draggable Helper
-- Makes a frame movable with position persistence via BazCore settings
---------------------------------------------------------------------------

function BazCore:MakeDraggable(frame, opts)
    -- opts.addonName  (string) addon name for settings
    -- opts.lockKey    (string) setting key for lock state
    -- opts.posXKey    (string) setting key for X position
    -- opts.posYKey    (string) setting key for Y position

    local addonName = opts.addonName
    local lockKey = opts.lockKey
    local posXKey = opts.posXKey or "posX"
    local posYKey = opts.posYKey or "posY"

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)

    frame:SetScript("OnDragStart", function(self)
        if lockKey and BazCore:GetSetting(addonName, lockKey) then return end
        self:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local ux, uy = UIParent:GetCenter()
        BazCore:SetSetting(addonName, posXKey, x - ux)
        BazCore:SetSetting(addonName, posYKey, y - uy)
    end)

    -- Restore position on show
    frame:HookScript("OnShow", function(self)
        local x = BazCore:GetSetting(addonName, posXKey)
        local y = BazCore:GetSetting(addonName, posYKey)
        if x and y then
            self:ClearAllPoints()
            self:SetPoint("CENTER", UIParent, "CENTER", x, y)
        end
    end)
end

---------------------------------------------------------------------------
-- Resize Handle
-- Adds a drag-to-resize grip to any frame
---------------------------------------------------------------------------

function BazCore:MakeResizable(frame, opts)
    -- opts.minScale    (number) minimum scale percentage (default 30)
    -- opts.maxScale    (number) max scale percentage, nil = screen cap
    -- opts.getScale    (function) returns current scale percentage
    -- opts.setScale    (function(pct)) called with new scale percentage
    -- opts.onResize    (function(pct)) called during drag
    -- opts.anchor      (string) "BOTTOMRIGHT" (default) or "BOTTOMLEFT"
    -- opts.parent      (frame) parent for the handle (default = frame)

    local minScale = opts.minScale or 30
    local anchor = opts.anchor or "BOTTOMRIGHT"
    local parent = opts.parent or frame

    local resizer = CreateFrame("Button", nil, parent)
    resizer:SetSize(16, 16)
    resizer:SetPoint(anchor, parent, anchor, anchor == "BOTTOMRIGHT" and -1 or 1, 1)
    resizer:SetFrameStrata("TOOLTIP")
    resizer:SetFrameLevel(999)
    resizer:EnableMouse(true)
    resizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizer:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    local lastX, lastY, currentScale

    resizer:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        lastX, lastY = GetCursorPosition()
        currentScale = opts.getScale and opts.getScale() or 100

        self:SetScript("OnUpdate", function()
            local cx, cy = GetCursorPosition()
            local dx = cx - lastX
            local dy = lastY - cy
            lastX, lastY = cx, cy
            local delta = (dx + dy) * 0.05

            local maxPct = opts.maxScale
            if not maxPct then
                local w, h = frame:GetSize()
                local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
                if w > 0 and h > 0 then
                    maxPct = math.floor(math.min(screenW / w, screenH / h) * 100)
                else
                    maxPct = 200
                end
            end

            currentScale = math.max(minScale, math.min(maxPct, currentScale + delta))
            local rounded = math.floor(currentScale + 0.5)

            if opts.setScale then
                opts.setScale(rounded)
            end
            if opts.onResize then
                opts.onResize(rounded)
            end
        end)
    end)

    resizer:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil)
        if opts.onStop then
            opts.onStop(currentScale and math.floor(currentScale + 0.5) or 100)
        end
    end)

    frame._bazResizer = resizer
    return resizer
end

---------------------------------------------------------------------------
-- Scale From Center
-- Sets a frame's scale while keeping its visual center in the same
-- screen position. Use this instead of raw frame:SetScale().
---------------------------------------------------------------------------

function BazCore:SetScaleFromCenter(frame, newScale, minScale, maxScale)
    minScale = minScale or 0.5
    maxScale = maxScale or 3.0
    newScale = math.max(minScale, math.min(maxScale, newScale))

    -- Capture center in screen pixels
    local cx, cy = frame:GetCenter()
    local oldScale = frame:GetScale()
    if cx and cy then
        cx = cx * oldScale
        cy = cy * oldScale
    end

    frame:SetScale(newScale)

    -- Re-anchor so center stays at the same screen position
    if cx and cy then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / newScale, cy / newScale)
    end

    return newScale
end

---------------------------------------------------------------------------
-- StatusBar Factory
-- Creates a styled status bar with optional label and value text
---------------------------------------------------------------------------

function BazCore:CreateStatusBar(parent, opts)
    opts = opts or {}
    local width = opts.width or 200
    local height = opts.height or 14
    local color = opts.color or { 0.3, 0.85, 0.3 }
    local bgColor = opts.bgColor or { 0.1, 0.1, 0.12, 0.8 }
    local texture = opts.texture or "Interface\\TargetingFrame\\UI-StatusBar"
    local minVal = opts.min or 0
    local maxVal = opts.max or 1

    local bar = CreateFrame("StatusBar", nil, parent or UIParent)
    bar:SetSize(width, height)
    bar:SetStatusBarTexture(texture)
    bar:SetStatusBarColor(unpack(color))
    bar:SetMinMaxValues(minVal, maxVal)
    bar:SetValue(opts.value or minVal)

    -- Background
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(bgColor))
    bar.bg = bg

    -- Optional label (left side)
    if opts.label then
        local label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", 4, 0)
        label:SetText(opts.label)
        label:SetTextColor(1, 1, 1)
        bar.label = label
    end

    -- Optional value text (right side)
    if opts.valueText then
        local valText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        valText:SetPoint("RIGHT", -4, 0)
        valText:SetTextColor(1, 1, 1)
        bar.valueText = valText
    end

    -- Convenience: update color
    function bar:SetColor(r, g, b)
        self:SetStatusBarColor(r, g, b)
    end

    -- Convenience: update value text
    function bar:SetValueText(text)
        if self.valueText then
            self.valueText:SetText(text)
        end
    end

    return bar
end

---------------------------------------------------------------------------
-- Portrait Window
--
-- Spawns a Frame using Blizzard's PortraitFrameFlatTemplate — the same
-- gold-ornate-bordered window with a portrait circle in the top-left
-- corner that the combined bag, character pane, and most major
-- Blizzard panels use. Centralised here so any Baz addon wanting a
-- Blizzard-styled window gets:
--
--   * Title bar with portrait icon + close button
--   * Drag-by-frame movement
--   * Optional position persistence (per-addon setting key)
--   * Optional ESC-close via UISpecialFrames
--
-- Usage:
--   local f = BazCore:CreatePortraitWindow("BazFooFrame", {
--       title          = "Foo",
--       portrait       = 5160585,            -- texture path or fileID
--       width          = 360,
--       height         = 400,
--       savedAddon     = addon,              -- BazCore addon handle for persistence
--       savedKey       = "position",         -- setting key on that addon
--       uiSpecialFrame = true,               -- register for ESC close
--       strata         = "MEDIUM",           -- optional, defaults MEDIUM
--   })
--
-- Returns the Frame ready to populate.
---------------------------------------------------------------------------

function BazCore:CreatePortraitWindow(globalName, opts)
    opts = opts or {}

    local f = CreateFrame("Frame", globalName, UIParent, "PortraitFrameFlatTemplate")
    f:SetSize(opts.width or 360, opts.height or 400)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:SetFrameStrata(opts.strata or "MEDIUM")
    f:SetToplevel(true)
    f:RegisterForDrag("LeftButton")
    f:Hide()

    -- Title + portrait. PortraitFrameMixin adds these as methods on
    -- frames that inherit from PortraitFrameBaseTemplate.
    if opts.title and f.SetTitle then
        f:SetTitle(opts.title)
    end
    if opts.portrait and f.SetPortraitToAsset then
        f:SetPortraitToAsset(opts.portrait)
    end

    -- Position handling. With savedAddon + savedKey we restore the
    -- last-used position on creation and persist on drag-stop.
    -- Without them the frame is just centred and drag is ephemeral.
    local savedAddon = opts.savedAddon
    local savedKey   = opts.savedKey
    do
        f:ClearAllPoints()
        local saved = savedAddon and savedKey and savedAddon:GetSetting(savedKey) or nil
        if saved and saved.point then
            f:SetPoint(saved.point, UIParent, saved.relPoint or saved.point,
                       saved.x or 0, saved.y or 0)
        else
            f:SetPoint("CENTER")
        end
    end

    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if savedAddon and savedKey then
            local point, _, relPoint, x, y = self:GetPoint()
            savedAddon:SetSetting(savedKey, {
                point    = point,
                relPoint = relPoint,
                x        = x,
                y        = y,
            })
        end
    end)

    -- ESC closes via Blizzard's UISpecialFrames mechanism.
    if opts.uiSpecialFrame and globalName then
        tinsert(UISpecialFrames, globalName)
    end

    return f
end
