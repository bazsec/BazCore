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
