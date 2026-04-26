---------------------------------------------------------------------------
-- BazCore Options: Constants & Shared Helpers
-- Layout dimensions, fonts, colors, backdrops, and utility functions
-- used across all Options modules.
---------------------------------------------------------------------------

BazCore._Options = BazCore._Options or {}
local O = BazCore._Options

---------------------------------------------------------------------------
-- Layout Dimensions
---------------------------------------------------------------------------

O.PAD            = 14
O.WIDGET_HEIGHT  = 32
O.HEADER_HEIGHT  = 28
O.SPACING        = 8
O.LIST_WIDTH     = 180
O.LIST_ITEM_HEIGHT = 28
O.COL_GAP        = 14
O.PANEL_PAD      = 12

---------------------------------------------------------------------------
-- Fonts
---------------------------------------------------------------------------

O.LABEL_FONT     = "GameFontNormalLarge"
O.DESC_FONT      = "GameFontNormalLarge"
O.HEADER_FONT    = "GameFontNormalLarge"
O.LIST_FONT      = "GameFontNormalLarge"
O.SMALL_FONT     = "GameFontHighlight"

---------------------------------------------------------------------------
-- Colors
---------------------------------------------------------------------------

O.GOLD           = { 1, 0.82, 0 }
O.WHITE          = { 1, 1, 1 }
O.DIM            = { 0.6, 0.6, 0.6 }
O.TEXT_NORMAL    = { 0.9, 0.9, 0.9 }
O.TEXT_DESC      = { 0.7, 0.7, 0.7 }
O.PANEL_BG       = { 0.04, 0.04, 0.06, 0.7 }
O.PANEL_BORDER   = { 0.25, 0.25, 0.3, 0.6 }
O.LIST_BG        = { 0.03, 0.03, 0.05, 0.6 }
O.LIST_HOVER     = { 0.1, 0.2, 0.4, 0.3 }
O.LIST_SELECTED  = { 0.15, 0.35, 0.6, 0.6 }
O.HEADER_LINE    = { 0.4, 0.35, 0.2, 0.8 }

---------------------------------------------------------------------------
-- Backdrops
---------------------------------------------------------------------------

O.PANEL_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

O.LIST_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

-- Sort args table by order field, returns array
function O.SortedArgs(args)
    if not args then return {} end
    local sorted = {}
    for key, opt in pairs(args) do
        opt._key = key
        sorted[#sorted + 1] = opt
    end
    table.sort(sorted, function(a, b)
        return (a.order or 100) < (b.order or 100)
    end)
    return sorted
end

-- Check if an option is disabled (supports function or boolean)
function O.IsDisabled(opt)
    if type(opt.disabled) == "function" then return opt.disabled() end
    return opt.disabled or false
end

---------------------------------------------------------------------------
-- Selection highlight (Blizzard-style gold gradient)
--
-- Returns a {textures...} group that the caller toggles via Show()/Hide()
-- when the row's selection state changes. Mirrors the highlight used by
-- Traveler's Log + Quest tracker dialogues — two horizontal bands
-- fading inward to a centre crest, plus thin gold lines at top + bottom
-- that fade to transparent at each edge.
--
-- Used by both the User Manual tree (Options/UserGuide.lua) and the
-- list/detail panel (Options/ListDetail.lua) so selection visuals stay
-- cohesive across every page that uses one of those layouts.
---------------------------------------------------------------------------

function O.BuildSelectionHighlight(row, rowH)
    rowH = rowH or row:GetHeight() or 26
    local rowW = row:GetWidth() or 200
    local halfW = math.floor(rowW / 2)

    local function MakeBand(layer, anchor, fadeFromCenter)
        local tex = row:CreateTexture(nil, layer)
        tex:SetColorTexture(1, 1, 1, 1)
        tex:SetSize(halfW, rowH)
        tex:SetPoint(anchor, 0, 0)
        if fadeFromCenter then
            tex:SetGradient("HORIZONTAL",
                CreateColor(1, 0.82, 0, 0.45),
                CreateColor(1, 0.82, 0, 0))
        else
            tex:SetGradient("HORIZONTAL",
                CreateColor(1, 0.82, 0, 0),
                CreateColor(1, 0.82, 0, 0.45))
        end
        return tex
    end

    local function MakeRule(anchor1, anchor2, fadeFromCenter)
        local tex = row:CreateTexture(nil, "OVERLAY")
        tex:SetColorTexture(1, 1, 1, 1)
        tex:SetSize(halfW, 1)
        tex:SetPoint(anchor1, 0, 0)
        if fadeFromCenter then
            tex:SetGradient("HORIZONTAL",
                CreateColor(1, 0.82, 0, 0.85),
                CreateColor(1, 0.82, 0, 0))
        else
            tex:SetGradient("HORIZONTAL",
                CreateColor(1, 0.82, 0, 0),
                CreateColor(1, 0.82, 0, 0.85))
        end
        return tex
    end

    local bandL = MakeBand("BACKGROUND", "LEFT",  false)
    local bandR = MakeBand("BACKGROUND", "RIGHT", true)
    local topL  = MakeRule("TOPLEFT",     nil, false)
    local topR  = MakeRule("TOPRIGHT",    nil, true)
    local botL  = MakeRule("BOTTOMLEFT",  nil, false)
    local botR  = MakeRule("BOTTOMRIGHT", nil, true)

    return { bandL, bandR, topL, topR, botL, botR }
end

function O.ShowHighlightGroup(group, show)
    for _, t in ipairs(group or {}) do
        if show then t:Show() else t:Hide() end
    end
end

---------------------------------------------------------------------------
-- List/detail layout dimensions — shared so the User Manual tree and
-- the standard list/detail panel resolve to the same widths regardless
-- of the container size. ListDetail used to clamp at 22 % / 180-320 px;
-- the User Manual at 28 % / 200-320. Settling on the User Manual's
-- numbers (it's the reference for visual style across the suite).
---------------------------------------------------------------------------

O.PAGE_LIST_PCT = 0.28
O.PAGE_LIST_MIN = 200
O.PAGE_LIST_MAX = 320
O.PAGE_LIST_GAP = 14

function O.ResolveListWidth(containerWidth)
    local w = math.floor((containerWidth or 600) * O.PAGE_LIST_PCT)
    if w < O.PAGE_LIST_MIN then w = O.PAGE_LIST_MIN end
    if w > O.PAGE_LIST_MAX then w = O.PAGE_LIST_MAX end
    return w
end

---------------------------------------------------------------------------
-- BuildTitleBar — shared header used by both the User Manual page and
-- the standard list/detail page. Includes the addon icon (if available),
-- gold title text, optional version line, and a horizontal rule
-- underneath. Returns (frame, height) so the caller can advance its
-- y-cursor past it.
--
-- opts = {
--   title         = string,         -- displayed as gold large text
--   addonName     = string,          -- used to look up icon + version
--   version       = string,          -- optional override; otherwise
--                                    -- read from the addon's .toc
--   contentWidth  = number,          -- frame width to set
-- }
---------------------------------------------------------------------------

function O.BuildTitleBar(parent, opts)
    opts = opts or {}
    local frame = CreateFrame("Frame", nil, parent)
    local headerHeight = 44
    local titleXOffset = O.PAD

    local addonConfig = opts.addonName and BazCore.addons
        and BazCore.addons[opts.addonName] or nil
    local iconTex = addonConfig and addonConfig.minimap and addonConfig.minimap.icon
    if not iconTex and opts.addonName and C_AddOns and C_AddOns.GetAddOnMetadata then
        iconTex = C_AddOns.GetAddOnMetadata(opts.addonName, "IconTexture")
    end
    if iconTex then
        local addonIcon = frame:CreateTexture(nil, "ARTWORK")
        addonIcon:SetSize(32, 32)
        addonIcon:SetPoint("TOPLEFT", O.PAD, -6)
        addonIcon:SetTexture(iconTex)
        titleXOffset = O.PAD + 40
    end

    local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOPLEFT", titleXOffset, -6)
    titleText:SetText(opts.title or opts.addonName or "")
    titleText:SetTextColor(unpack(O.GOLD))

    local addonVersion = opts.version
        or (addonConfig and addonConfig.version)
    if not addonVersion and opts.addonName and C_AddOns and C_AddOns.GetAddOnMetadata then
        addonVersion = C_AddOns.GetAddOnMetadata(opts.addonName, "Version")
    end
    if addonVersion then
        local versionText = frame:CreateFontString(nil, "OVERLAY", O.SMALL_FONT)
        versionText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -2)
        versionText:SetText("v" .. addonVersion)
        versionText:SetTextColor(unpack(O.DIM))
        headerHeight = headerHeight + 6
    end

    local titleLine = frame:CreateTexture(nil, "ARTWORK")
    titleLine:SetHeight(1)
    titleLine:SetPoint("BOTTOMLEFT", O.PAD, 0)
    titleLine:SetPoint("BOTTOMRIGHT", -O.PAD, 0)
    titleLine:SetColorTexture(unpack(O.HEADER_LINE))

    if opts.contentWidth then
        frame:SetSize(opts.contentWidth, headerHeight)
    else
        frame:SetHeight(headerHeight)
    end
    return frame, headerHeight
end

-- Remove all children from a frame (for re-rendering)
function O.ClearChildren(parent)
    for _, child in ipairs({ parent:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    for _, region in ipairs({ parent:GetRegions() }) do
        region:Hide()
        region:SetParent(nil)
    end
end

-- Check if an args table contains any group-type options
function O.HasChildGroups(args)
    if not args then return false end
    for _, opt in pairs(args) do
        if type(opt) == "table" and opt.type == "group" then
            return true
        end
    end
    return false
end

-- Auto-hide a scroll bar when the content fits without scrolling.
-- Hooks OnValueChanged on the scroll frame so visibility updates live.
function O.AutoHideScrollbar(scrollFrame, scrollBar)
    if not scrollFrame or not scrollBar then return end

    local function Update()
        local child = scrollFrame:GetScrollChild()
        if not child then
            scrollBar:Hide()
            return
        end
        local contentH = child:GetHeight() or 0
        local frameH = scrollFrame:GetHeight() or 0
        if contentH > frameH + 1 then
            scrollBar:Show()
        else
            scrollBar:Hide()
        end
    end

    scrollFrame:HookScript("OnSizeChanged", Update)
    -- Poll briefly after creation so content has settled
    C_Timer.After(0, Update)
    C_Timer.After(0.1, Update)
end
