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
-- Traveler's Log + Quest tracker dialogues - two horizontal bands
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
-- Section header chrome - the chapter-divider look used by source-
-- grouped lists in BuildListDetailPanel AND by expandable parent
-- rows in the User Manual tree. Keeping the styling here so both
-- renderers stay in lockstep when the look changes.
--
-- Adds three textures to a header button frame:
--   * Warm-toned dark backdrop fill (BACKGROUND layer)
--   * Thick gold accent bar on the left edge (ARTWORK layer)
--   * Thin gold rule along the bottom, full width (ARTWORK layer)
--
-- The gold rule is anchored at x=0 (no inset on either side) so it
-- meets the accent bar at the bottom-left corner cleanly and reaches
-- the right edge of the backdrop without leaving a gap.
---------------------------------------------------------------------------

function O.BuildSectionHeaderChrome(button)
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.12, 0.09, 0.04, 0.65)

    local accent = button:CreateTexture(nil, "ARTWORK")
    accent:SetWidth(3)
    accent:SetPoint("TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", 0, 0)
    accent:SetColorTexture(1.00, 0.82, 0.00, 0.95)

    local rule = button:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", 0, 0)
    rule:SetColorTexture(1.00, 0.82, 0.00, 0.55)

    return { bg = bg, accent = accent, rule = rule }
end

-- Section-header height is slightly taller than item rows so the
-- chapter-divider backdrop has room to breathe.
O.SECTION_HEADER_HEIGHT = (O.LIST_ITEM_HEIGHT or 28) + 4

---------------------------------------------------------------------------
-- O.RenderListRows — one shared row builder for every list/sidebar in
-- the suite. Pages converted their domain-specific data (tree nodes,
-- option-table groups, top-level sub-categories) into a flat array of
-- row specs and hand it off here, which means visuals + behaviour stay
-- in lockstep across:
--   * The standalone window's left sidebar (Registration.lua)
--   * The User Manual tree (UserGuide.lua)
--   * The list/detail panel (ListDetail.lua)
--
-- Each row spec is a table:
--   {
--     key        = unique string,
--     label      = display text,
--     count      = optional number (rendered as "  (N)" suffix in grey),
--     isParent   = true for chapter-divider headers (BG + accent +
--                  bottom rule + +/- chevron). Default false.
--     expanded   = parent rows: true shows minus, false shows plus.
--                  Ignored for non-parent rows.
--     isSelected = true to draw the gold-gradient highlight + white
--                  text. Parent rows skip the gradient (chapter chrome
--                  is enough) but still get the white text colour.
--     depth      = optional indentation level (0 = flush left).
--     indent     = optional extra pixels of indent on top of depth.
--     onClick    = function() called on left-click.
--     moveUp     = optional function() - when set, paints a small up
--                  arrow button at the right edge of the row. Pass nil
--                  on the topmost row so the arrow renders disabled.
--     moveDown   = optional function() - mirror of moveUp; nil on the
--                  bottommost row to render disabled.
--   }
--
-- opts:
--   width = list-content width in pixels (required).
--
-- Selection styling for parent rows is intentionally NOT optional.
-- Both lists feed the same renderer the same shape of data; if a
-- caller wants the parent to look "selected" it sets isSelected on
-- that row spec. Source headers in the list/detail panel use this
-- the same way User Manual tree parents do, so the two lists always
-- read as one cohesive widget.
---------------------------------------------------------------------------

function O.RenderListRows(listContent, rows, opts)
    opts = opts or {}
    local width = opts.width
    if not width then return end

    local frames = {}
    local y = 0

    for i, spec in ipairs(rows) do
        local isParent   = spec.isParent and true or false
        local rowH       = isParent and O.SECTION_HEADER_HEIGHT or O.LIST_ITEM_HEIGHT
        local isSelected = spec.isSelected and true or false

        local row = CreateFrame("Button", nil, listContent)
        row:SetSize(width, rowH)
        row:SetPoint("TOPLEFT", 0, -y)
        row:RegisterForClicks("LeftButtonUp")

        if isParent then
            O.BuildSectionHeaderChrome(row)
        end

        -- Subtle hover background (only when not selected).
        local hover = row:CreateTexture(nil, "BACKGROUND", nil, 1)
        hover:SetAllPoints()
        if isParent then
            hover:SetColorTexture(1, 0.82, 0, 0.10)
        else
            hover:SetColorTexture(1, 1, 1, 0.05)
        end
        hover:Hide()
        row.hover = hover

        -- Gold-gradient selection highlight. Skipped on parent rows
        -- because the chapter chrome already gives them their visual
        -- identity; layering the gradient + top/bottom rules would
        -- double-paint the accent + bottom rule.
        local hlGroup
        if not isParent then
            hlGroup = O.BuildSelectionHighlight(row, rowH)
            O.ShowHighlightGroup(hlGroup, isSelected)
        end
        row.hlGroup = hlGroup

        local depth   = spec.depth or 0
        local indent  = 8 + depth * 16 + (spec.indent or 0)

        -- Plus/minus chevron for parent rows. Positioned a hair left
        -- of the text so it doesn't visually float away from the row.
        if isParent then
            local arrow = row:CreateTexture(nil, "OVERLAY")
            arrow:SetSize(14, 14)
            arrow:SetPoint("LEFT", indent - 2, 0)
            arrow:SetTexture(spec.expanded
                and "Interface\\Buttons\\UI-MinusButton-Up"
                or  "Interface\\Buttons\\UI-PlusButton-Up")
            indent = indent + 16
        end

        -- Move-up / move-down arrows on the right edge. Rendered as
        -- child Buttons so clicking an arrow doesn't trigger the row's
        -- OnClick. A nil callback on either side draws the arrow
        -- disabled (greyed out, non-clickable) so the user still sees
        -- the affordance but understands they're at a list boundary.
        -- Only emitted when the spec sets either callback - rows
        -- without ordering (User Manual tree, source headers) skip
        -- the arrows entirely so the right edge stays clean.
        --
        -- Style: same atlas Blizzard uses for WowStyle1ArrowDropdown
        -- (the chevron-button on the FriendsFrame status dropdown).
        -- common-dropdown-a-button is a COMPLETE button graphic - chrome
        -- + chevron baked together - so we use it as the whole button
        -- with no extra backdrop (which is what produced the
        -- "button-in-button" look earlier). Blizzard's mixin swaps
        -- atlas variants for hover / pressed / disabled, mirrored here.
        local rightInset = 4
        if spec.moveUp ~= nil or spec.moveDown ~= nil then
            local function MakeArrow(rotation, callback, anchorRight)
                local btn = CreateFrame("Button", nil, row)
                btn:SetSize(22, 22)
                btn:SetPoint("RIGHT", -anchorRight, 0)
                local tex = btn:CreateTexture(nil, "ARTWORK")
                tex:SetSize(22, 22)
                -- Blizzard's WowStyle1ArrowDropdownTemplate XML anchors
                -- the texture at CENTER y=-2 because the chevron isn't
                -- pixel-centered in the atlas - it sits slightly low.
                -- When we rotate 180 for the up arrow, that asymmetry
                -- flips, so the up texture needs y=+2 to keep its
                -- chevron in the same visual spot. Without this the
                -- two buttons in a row look vertically offset.
                tex:SetPoint("CENTER", 0, (rotation == 0) and -2 or 2)
                tex:SetAtlas("common-dropdown-a-button")
                tex:SetRotation(rotation)
                btn.tex = tex
                if callback then
                    btn:RegisterForClicks("LeftButtonUp")
                    btn:SetScript("OnClick", function() callback() end)
                    btn:SetScript("OnEnter", function(self)
                        self.tex:SetAtlas("common-dropdown-a-button-hover")
                    end)
                    btn:SetScript("OnLeave", function(self)
                        self.tex:SetAtlas("common-dropdown-a-button")
                    end)
                    btn:SetScript("OnMouseDown", function(self)
                        self.tex:SetAtlas("common-dropdown-a-button-pressed")
                    end)
                    btn:SetScript("OnMouseUp", function(self)
                        self.tex:SetAtlas(self:IsMouseOver()
                            and "common-dropdown-a-button-hover"
                            or  "common-dropdown-a-button")
                    end)
                else
                    btn:EnableMouse(false)
                    tex:SetAtlas("common-dropdown-a-button-disabled")
                end
                return btn
            end
            -- Down arrow flush to the right (no rotation - the atlas
            -- points down by default since dropdowns open downward),
            -- up arrow rotated 180 to its left.
            MakeArrow(0,       spec.moveDown, 6)
            MakeArrow(math.pi, spec.moveUp,   32)
            rightInset = 60  -- reserve room so label doesn't overlap arrows
        end

        local labelText = spec.label or ""
        if spec.count then
            labelText = labelText .. "  |cff888888(" .. spec.count .. ")|r"
        end
        local text = row:CreateFontString(nil, "OVERLAY", O.LIST_FONT)
        text:SetPoint("LEFT", indent, 0)
        text:SetPoint("RIGHT", -rightInset, 0)
        text:SetJustifyH("LEFT")
        text:SetText(labelText)
        if isSelected then
            text:SetTextColor(1, 1, 1)
            text:SetAlpha(1.0)
        else
            text:SetTextColor(unpack(O.GOLD))
            text:SetAlpha(0.75)
        end
        row.text = text

        local capturedClick = spec.onClick
        row:SetScript("OnClick", function()
            if capturedClick then capturedClick() end
        end)
        row:SetScript("OnEnter", function(self)
            if not isSelected then
                self.hover:Show()
                self.text:SetAlpha(1.0)
            end
        end)
        row:SetScript("OnLeave", function(self)
            if not isSelected then
                self.hover:Hide()
                self.text:SetAlpha(0.75)
            end
        end)

        frames[i] = row
        y = y + rowH
    end

    return frames, y
end

---------------------------------------------------------------------------
-- List/detail layout dimensions - shared so the User Manual tree and
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
-- BuildTitleBar - shared header used by both the User Manual page and
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
