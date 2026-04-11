---------------------------------------------------------------------------
-- BazCore: OptionsPanel Module
-- Two-panel options renderer: list on left, settings on right
---------------------------------------------------------------------------

local optionsTables = {}
BazCore._optionsTables = optionsTables -- expose for cross-module refresh
local PAD = 12
local WIDGET_HEIGHT = 28
local HEADER_HEIGHT = 24
local SPACING = 6
local LIST_WIDTH = 160
local LIST_ITEM_HEIGHT = 24
local DESC_FONT = "GameFontHighlightSmall"
local LABEL_FONT = "GameFontHighlight"

---------------------------------------------------------------------------
-- Sort args by order
---------------------------------------------------------------------------

local function SortedArgs(args)
    if not args then return {} end
    local sorted = {}
    for key, opt in pairs(args) do
        opt._key = key
        sorted[#sorted + 1] = opt
    end
    table.sort(sorted, function(a, b) return (a.order or 100) < (b.order or 100) end)
    return sorted
end

---------------------------------------------------------------------------
-- Widget Factories — each returns (frame, height)
---------------------------------------------------------------------------

local function CreateDescriptionWidget(parent, opt, contentWidth)
    local frame = CreateFrame("Frame", nil, parent)
    -- Default to medium (GameFontNormal) for all descriptions
    -- Use "small" explicitly for smaller text
    local font = GameFontNormal
    if opt.fontSize == "small" then
        font = GameFontHighlightSmall
    end
    local fs = frame:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(font)
    fs:SetPoint("TOPLEFT")
    fs:SetWidth(contentWidth)
    fs:SetJustifyH("LEFT")
    fs:SetText(opt.name or "")
    fs:SetTextColor(0.8, 0.8, 0.8)
    fs:SetWordWrap(true)
    local h = math.max(fs:GetStringHeight() + 4, 12)
    frame:SetSize(contentWidth, h)
    return frame, h
end

local function CreateHeaderWidget(parent, opt, contentWidth)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(contentWidth, HEADER_HEIGHT)
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", 0, 0)
    text:SetText(opt.name or "")
    text:SetTextColor(1, 0.82, 0)
    if opt.name and opt.name ~= "" then
        local line = frame:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetPoint("LEFT", text, "RIGHT", 8, 0)
        line:SetPoint("RIGHT", frame, "RIGHT")
        line:SetColorTexture(0.4, 0.4, 0.4, 0.4)
    end
    return frame, HEADER_HEIGHT
end

local function IsDisabled(opt)
    if type(opt.disabled) == "function" then return opt.disabled() end
    return opt.disabled
end

local function CreateToggleWidget(parent, opt, contentWidth)
    local height = WIDGET_HEIGHT
    local frame = CreateFrame("Frame", nil, parent)
    local cb = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    -- Anchor top-down so a tall multi-line description doesn't push the
    -- content off the bottom of the frame (a LEFT anchor would center the
    -- checkbox and any wrapped description would overflow below).
    cb:SetPoint("TOPLEFT", 0, -4)
    cb:SetSize(20, 20)
    if opt.get then cb:SetChecked(opt.get()) end
    local label = frame:CreateFontString(nil, "OVERLAY", LABEL_FONT)
    label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    label:SetText(opt.name or "")
    if opt.desc then
        local desc = frame:CreateFontString(nil, "OVERLAY", DESC_FONT)
        desc:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
        desc:SetWidth(contentWidth - 28)
        desc:SetJustifyH("LEFT")
        desc:SetText(opt.desc)
        desc:SetTextColor(0.5, 0.5, 0.5)
        height = height + desc:GetStringHeight() + 2
    end
    frame:SetSize(contentWidth, height)
    cb:SetScript("OnClick", function(self) if opt.set then opt.set(nil, self:GetChecked()) end end)
    if opt.disabled then
        local function ApplyDisabledState()
            local off = IsDisabled(opt)
            cb:SetEnabled(not off)
            label:SetTextColor(off and 0.5 or 1, off and 0.5 or 1, off and 0.5 or 1)
            frame:SetAlpha(off and 0.5 or 1)
        end
        ApplyDisabledState()
        frame:SetScript("OnShow", ApplyDisabledState)
    end
    return frame, height
end

local function CreateRangeWidget(parent, opt, contentWidth)
    local height = 50
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(contentWidth, height)
    local label = frame:CreateFontString(nil, "OVERLAY", LABEL_FONT)
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(opt.name or "")
    local slider = CreateFrame("Frame", nil, frame, "MinimalSliderWithSteppersTemplate")
    slider:SetPoint("TOPLEFT", 0, -18)
    slider:SetWidth(contentWidth - 60)
    slider.Slider:SetMinMaxValues(opt.min or 0, opt.max or 100)
    slider.Slider:SetValueStep(opt.step or 1)
    slider.Slider:SetObeyStepOnDrag(true)
    local currentVal = opt.get and opt.get() or opt.min or 0
    slider.Slider:SetValue(currentVal)
    local valText = frame:CreateFontString(nil, "OVERLAY", LABEL_FONT)
    valText:SetPoint("LEFT", slider, "RIGHT", 8, 0)
    local function FormatValue(v)
        if opt.isPercent then return string.format("%d%%", v * 100)
        elseif opt.step and opt.step < 1 then return string.format("%.2f", v)
        else return tostring(math.floor(v)) end
    end
    valText:SetText(FormatValue(currentVal))
    slider.Slider:SetScript("OnValueChanged", function(_, value)
        local step = opt.step or 1
        value = math.floor(value / step + 0.5) * step
        valText:SetText(FormatValue(value))
        if opt.set then opt.set(nil, value) end
    end)
    if opt.disabled then
        local function ApplyDisabledState()
            local off = IsDisabled(opt)
            slider.Slider:SetEnabled(not off)
            if slider.IncrementButton then slider.IncrementButton:SetEnabled(not off) end
            if slider.DecrementButton then slider.DecrementButton:SetEnabled(not off) end
            label:SetTextColor(off and 0.5 or 1, off and 0.5 or 1, off and 0.5 or 1)
            frame:SetAlpha(off and 0.5 or 1)
        end
        ApplyDisabledState()
        frame:SetScript("OnShow", ApplyDisabledState)
    end
    return frame, height
end

local function CreateInputWidget(parent, opt, contentWidth)
    local height = 46
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(contentWidth, height)
    local label = frame:CreateFontString(nil, "OVERLAY", LABEL_FONT)
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(opt.name or "")
    local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    editBox:SetPoint("TOPLEFT", 0, -16)
    editBox:SetSize(contentWidth - 10, 24)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    if opt.get then editBox:SetText(opt.get() or "") end
    editBox:SetScript("OnEnterPressed", function(self)
        if opt.set then opt.set(nil, self:GetText()) end
        self:ClearFocus()
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        if opt.get then self:SetText(opt.get() or "") end
        self:ClearFocus()
    end)
    return frame, height
end

local function CreateExecuteWidget(parent, opt, contentWidth)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(contentWidth, WIDGET_HEIGHT + 4)
    local btnWidth = math.min(220, contentWidth)
    local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btn:SetPoint("LEFT", 0, 0)
    btn:SetSize(btnWidth, WIDGET_HEIGHT)
    btn:SetText(opt.name or "Execute")
    btn:SetScript("OnClick", function()
        if opt.confirm then
            StaticPopupDialogs["BAZCORE_CONFIRM_EXEC"] = {
                text = opt.confirmText or "Are you sure?",
                button1 = "Yes", button2 = "No",
                OnAccept = function() if opt.func then opt.func() end end,
                timeout = 0, whileDead = true, hideOnEscape = true,
            }
            StaticPopup_Show("BAZCORE_CONFIRM_EXEC")
        else
            if opt.func then opt.func() end
        end
    end)
    if opt.desc then
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(opt.desc, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return frame, WIDGET_HEIGHT + 4
end

local function CreateSelectWidget(parent, opt, contentWidth)
    local height = 46
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(contentWidth, height)
    local label = frame:CreateFontString(nil, "OVERLAY", LABEL_FONT)
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(opt.name or "")
    local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btn:SetPoint("TOPLEFT", 0, -16)
    btn:SetSize(200, 24)
    local function GetCurrentLabel()
        local val = opt.get and opt.get()
        local values = opt.values or {}
        if type(values) == "function" then values = values() end
        if val and val ~= "" and values[val] then
            return values[val]
        end
        -- Check if there are any values at all
        if not next(values) then
            return "|cff666666None available|r"
        end
        return "|cff999999Select...|r"
    end
    btn:SetText(GetCurrentLabel())

    local function HasValues()
        local values = opt.values or {}
        if type(values) == "function" then values = values() end
        return next(values) ~= nil
    end

    btn:SetScript("OnClick", function(self)
        local values = opt.values or {}
        if type(values) == "function" then values = values() end
        if not next(values) then return end
        MenuUtil.CreateContextMenu(self, function(_, rootDescription)
            for value, text in pairs(values) do
                rootDescription:CreateButton(text, function()
                    if opt.set then opt.set(nil, value) end
                    btn:SetText(text)
                end)
            end
        end)
    end)
    return frame, height
end

local widgetFactories = {
    description = CreateDescriptionWidget,
    header      = CreateHeaderWidget,
    toggle      = CreateToggleWidget,
    range       = CreateRangeWidget,
    input       = CreateInputWidget,
    execute     = CreateExecuteWidget,
    select      = CreateSelectWidget,
}

---------------------------------------------------------------------------
-- Clear all children from a frame
---------------------------------------------------------------------------

local function ClearChildren(frame)
    for _, child in pairs({ frame:GetChildren() }) do
        child:Hide()
        child:ClearAllPoints()
        child:SetParent(nil)
    end
    for _, region in pairs({ frame:GetRegions() }) do
        region:Hide()
        region:SetParent(nil)
    end
end

---------------------------------------------------------------------------
-- Render flat widgets (non-group args) into a parent frame
---------------------------------------------------------------------------

local COL_GAP = 12
local PANEL_PAD = 10
local PANEL_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

local function RenderWidgets(parent, args, contentWidth, forceColumns, startY)
    local sorted = SortedArgs(args)
    local yOffset = startY or -PAD

    -- Two-column mode: auto when wide enough, unless forced to 1
    local useTwoCol = (forceColumns ~= 1) and (contentWidth > 500)

    if not useTwoCol then
        -- Single column: simple linear layout
        for _, opt in ipairs(sorted) do
            if opt.type ~= "group" then
                local factory = widgetFactories[opt.type]
                if factory then
                    local widget, h = factory(parent, opt, contentWidth)
                    widget:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset)
                    widget:Show()
                    yOffset = yOffset - h - SPACING
                end
            end
        end
        return yOffset
    end

    -- Two-column with bordered panels
    -- First pass: separate into sections split by full-width items
    local sections = {}
    local currentLeft = {}
    local currentRight = {}
    local col = 1

    for _, opt in ipairs(sorted) do
        if opt.type ~= "group" then
            local fullWidth = (opt.type == "header" or opt.type == "description" or opt.type == "execute")
            if fullWidth then
                if #currentLeft > 0 or #currentRight > 0 then
                    table.insert(sections, { type = "pair", left = currentLeft, right = currentRight })
                    currentLeft, currentRight = {}, {}
                    col = 1
                end
                table.insert(sections, { type = "full", opt = opt })
            else
                if col == 1 then
                    table.insert(currentLeft, opt)
                    col = 2
                else
                    table.insert(currentRight, opt)
                    col = 1
                end
            end
        end
    end
    if #currentLeft > 0 or #currentRight > 0 then
        table.insert(sections, { type = "pair", left = currentLeft, right = currentRight })
    end

    -- Second pass: render sections
    local panelWidth = math.floor((contentWidth - COL_GAP) / 2)
    local innerWidth = panelWidth - PANEL_PAD * 2
    local prevType = nil

    for _, section in ipairs(sections) do
        if section.type == "full" then
            -- Extra gap after a panel pair
            if prevType == "pair" then
                yOffset = yOffset - 4
            end
            local factory = widgetFactories[section.opt.type]
            if factory then
                local widget, h = factory(parent, section.opt, contentWidth)
                widget:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset)
                widget:Show()
                yOffset = yOffset - h - 2
            end
        else
            -- Calculate heights for each panel
            local leftH = PANEL_PAD
            for _, opt in ipairs(section.left) do
                local factory = widgetFactories[opt.type]
                if factory then
                    local _, h = factory(parent, opt, innerWidth)
                    leftH = leftH + h + SPACING
                end
            end
            leftH = math.max(leftH + PANEL_PAD - SPACING, PANEL_PAD * 2)

            local rightH = PANEL_PAD
            for _, opt in ipairs(section.right) do
                local factory = widgetFactories[opt.type]
                if factory then
                    local _, h = factory(parent, opt, innerWidth)
                    rightH = rightH + h + SPACING
                end
            end
            rightH = math.max(rightH + PANEL_PAD - SPACING, PANEL_PAD * 2)

            local maxH = math.max(leftH, rightH)

            -- Left panel
            local leftPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
            leftPanel:SetSize(panelWidth, maxH)
            leftPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset)
            leftPanel:SetBackdrop(PANEL_BACKDROP)
            leftPanel:SetBackdropColor(0.04, 0.04, 0.06, 0.4)
            leftPanel:SetBackdropBorderColor(0.25, 0.25, 0.3, 0.5)
            leftPanel:Show()

            local ly = -PANEL_PAD
            for _, opt in ipairs(section.left) do
                local factory = widgetFactories[opt.type]
                if factory then
                    local widget, h = factory(leftPanel, opt, innerWidth)
                    widget:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", PANEL_PAD, ly)
                    widget:Show()
                    ly = ly - h - SPACING
                end
            end

            -- Right panel
            local rightPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
            rightPanel:SetSize(panelWidth, maxH)
            rightPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + panelWidth + COL_GAP, yOffset)
            rightPanel:SetBackdrop(PANEL_BACKDROP)
            rightPanel:SetBackdropColor(0.04, 0.04, 0.06, 0.4)
            rightPanel:SetBackdropBorderColor(0.25, 0.25, 0.3, 0.5)
            rightPanel:Show()

            local ry = -PANEL_PAD
            for _, opt in ipairs(section.right) do
                local factory = widgetFactories[opt.type]
                if factory then
                    local widget, h = factory(rightPanel, opt, innerWidth)
                    widget:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", PANEL_PAD, ry)
                    widget:Show()
                    ry = ry - h - SPACING
                end
            end

            yOffset = yOffset - maxH - SPACING
        end
        prevType = section.type
    end

    return yOffset
end

---------------------------------------------------------------------------
-- Check if a group has child groups
---------------------------------------------------------------------------

local function HasChildGroups(args)
    if not args then return false end
    for _, opt in pairs(args) do
        if opt.type == "group" then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- Two-Panel Layout
---------------------------------------------------------------------------

local function CreateTwoPanelLayout(container, optionsTable)
    ClearChildren(container)

    local args = optionsTable.args or {}
    local contentWidth = container:GetWidth()
    if contentWidth <= 0 then contentWidth = 620 end

    -- Categorize args
    local topArgs = {}
    local groupArgs = {}
    local executeArgs = {}
    local sorted = SortedArgs(args)

    -- First pass: check if we have any two-panel groups
    local hasTwoPanelGroups = false
    for _, opt in ipairs(sorted) do
        if opt.type == "group" and HasChildGroups(opt.args) then
            hasTwoPanelGroups = true
            break
        end
    end

    for _, opt in ipairs(sorted) do
        if opt.type == "group" and HasChildGroups(opt.args) then
            groupArgs[#groupArgs + 1] = opt
        elseif hasTwoPanelGroups and opt.type == "execute" then
            -- Only separate execute buttons when there's a two-panel group (for the list panel)
            executeArgs[#executeArgs + 1] = opt
        elseif hasTwoPanelGroups and opt.type == "description" then
            -- Skip descriptions on two-panel pages (subtitle handles it)
        else
            topArgs[#topArgs + 1] = opt
        end
    end

    local yOffset = 0
    local headerHeight = 40

    -- Branded header
    local titleFrame = CreateFrame("Frame", nil, container)
    titleFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, yOffset)
    titleFrame:Show()

    local titleAnchor = titleFrame  -- anchor point for title text
    local titleXOffset = PAD

    -- Addon icon: explicit icon property, or auto-read from TOC IconTexture
    local addonIcon = optionsTable.icon
    if not addonIcon and optionsTable.name then
        addonIcon = C_AddOns.GetAddOnMetadata(optionsTable.name, "IconTexture")
    end

    if addonIcon then
        headerHeight = 48
        local iconFrame = CreateFrame("Frame", nil, titleFrame)
        iconFrame:SetSize(32, 32)
        iconFrame:SetPoint("LEFT", PAD, 0)

        local icon = iconFrame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        -- Handle numeric IDs, interface paths, and addon-relative paths
        local texturePath = addonIcon
        if type(texturePath) == "string" then
            texturePath = tonumber(texturePath) or texturePath
        end
        icon:SetTexture(texturePath)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        -- Rounded border for icon
        local iconBorder = iconFrame:CreateTexture(nil, "OVERLAY")
        iconBorder:SetSize(36, 36)
        iconBorder:SetPoint("CENTER")
        iconBorder:SetAtlas("UI-HUD-ActionBar-IconFrame")

        titleXOffset = PAD + 40
    end

    titleFrame:SetSize(contentWidth, headerHeight)

    local titleText = titleFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("LEFT", titleXOffset, addonIcon and 4 or 0)
    titleText:SetText(optionsTable.name or "")
    titleText:SetTextColor(1, 0.82, 0)

    -- Version: explicit or auto-read from TOC
    local addonVersion = optionsTable.version
    if not addonVersion and optionsTable.name then
        addonVersion = C_AddOns.GetAddOnMetadata(optionsTable.name, "Version")
    end

    if addonVersion then
        local verText = titleFrame:CreateFontString(nil, "OVERLAY", DESC_FONT)
        if addonIcon then
            verText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -1)
        else
            verText:SetPoint("LEFT", titleText, "RIGHT", 8, 0)
        end
        verText:SetText("v" .. addonVersion)
        verText:SetTextColor(0.5, 0.5, 0.5)
    end

    -- Subtitle
    if optionsTable.subtitle then
        local subText = titleFrame:CreateFontString(nil, "OVERLAY", DESC_FONT)
        subText:SetPoint("LEFT", titleText, "RIGHT", 10, 0)
        subText:SetText("- " .. optionsTable.subtitle)
        subText:SetTextColor(0.5, 0.5, 0.5)
    end

    -- Title toggle (right-aligned checkbox in title bar)
    if optionsTable.titleToggle then
        local tt = optionsTable.titleToggle
        local cb = CreateFrame("CheckButton", nil, titleFrame, "UICheckButtonTemplate")
        cb:SetSize(20, 20)
        cb:SetPoint("RIGHT", titleFrame, "RIGHT", -PAD - 4, 0)
        if tt.get then cb:SetChecked(tt.get()) end
        cb:SetScript("OnClick", function(self)
            if tt.set then tt.set(nil, self:GetChecked()) end
        end)
        local cbLabel = titleFrame:CreateFontString(nil, "OVERLAY", DESC_FONT)
        cbLabel:SetPoint("RIGHT", cb, "LEFT", -4, 0)
        cbLabel:SetText(tt.name or "")
        cbLabel:SetTextColor(0.7, 0.7, 0.7)
    end

    -- Separator line
    local titleLine = titleFrame:CreateTexture(nil, "ARTWORK")
    titleLine:SetHeight(1)
    titleLine:SetPoint("BOTTOMLEFT", PAD, 0)
    titleLine:SetPoint("BOTTOMRIGHT", -PAD, 0)
    titleLine:SetColorTexture(0.6, 0.5, 0.2, 0.4)

    yOffset = yOffset - headerHeight - 4

    -- Check if topArgs has any groups
    local hasTopGroups = false
    for _, opt in ipairs(topArgs) do
        if opt.type == "group" then hasTopGroups = true; break end
    end

    -- If all flat (no groups), use RenderWidgets for two-column layout
    if not hasTopGroups and #topArgs > 0 then
        local flatArgs = {}
        for _, opt in ipairs(topArgs) do
            flatArgs[opt._key] = opt
        end
        yOffset = RenderWidgets(container, flatArgs, contentWidth - PAD * 2, nil, yOffset)
    end

    -- Top-level widgets (when groups are present)
    if hasTopGroups then for _, opt in ipairs(topArgs) do
        if opt.type == "group" and opt.inline then
            -- Inline group: bordered panel with header and children
            local panelPad = 10
            local innerWidth = contentWidth - PAD * 2 - panelPad * 2

            -- Measure children height first
            local childHeight = PAD
            local childSorted = SortedArgs(opt.args)
            for _, childOpt in ipairs(childSorted) do
                local factory = widgetFactories[childOpt.type]
                if factory then
                    local _, h = factory(container, childOpt, innerWidth)
                    childHeight = childHeight + h + SPACING
                end
            end
            childHeight = childHeight + HEADER_HEIGHT + 8

            -- Panel frame
            local panel = CreateFrame("Frame", nil, container, "BackdropTemplate")
            panel:SetSize(contentWidth - PAD * 2, childHeight)
            panel:SetPoint("TOPLEFT", container, "TOPLEFT", PAD, yOffset)
            panel:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 },
            })
            panel:SetBackdropColor(0.04, 0.04, 0.06, 0.4)
            panel:SetBackdropBorderColor(0.25, 0.25, 0.3, 0.5)
            panel:Show()

            -- Panel header
            local panelTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            panelTitle:SetPoint("TOPLEFT", panelPad, -panelPad)
            panelTitle:SetText(opt.name or "")
            panelTitle:SetTextColor(1, 0.82, 0)

            local panelLine = panel:CreateTexture(nil, "ARTWORK")
            panelLine:SetHeight(1)
            panelLine:SetPoint("LEFT", panelTitle, "RIGHT", 8, 0)
            panelLine:SetPoint("RIGHT", panel, "RIGHT", -panelPad, 0)
            panelLine:SetColorTexture(0.4, 0.4, 0.4, 0.3)

            -- Render children inside panel
            local innerY = -(panelPad + HEADER_HEIGHT)
            for _, childOpt in ipairs(childSorted) do
                local factory = widgetFactories[childOpt.type]
                if factory then
                    local widget, h = factory(panel, childOpt, innerWidth)
                    widget:SetPoint("TOPLEFT", panel, "TOPLEFT", panelPad, innerY)
                    widget:Show()
                    innerY = innerY - h - SPACING
                end
            end

            yOffset = yOffset - childHeight - SPACING
        elseif opt.type == "group" then
            -- Non-inline group: header + flat children (two-column aware)
            local hdr, hh = CreateHeaderWidget(container, opt, contentWidth - PAD * 2)
            hdr:SetPoint("TOPLEFT", container, "TOPLEFT", PAD, yOffset)
            hdr:Show()
            yOffset = yOffset - hh - SPACING
            if opt.args then
                yOffset = RenderWidgets(container, opt.args, contentWidth - PAD * 2, opt.columns, yOffset)
            end
        else
            local factory = widgetFactories[opt.type]
            if factory then
                local widget, h = factory(container, opt, contentWidth - PAD * 2)
                widget:SetPoint("TOPLEFT", container, "TOPLEFT", PAD, yOffset)
                widget:Show()
                yOffset = yOffset - h - SPACING
            end
        end
    end end -- close hasTopGroups if + for

    -- Two-panel groups
    for _, groupOpt in ipairs(groupArgs) do
        -- Section header
        local hdr, hh = CreateHeaderWidget(container, groupOpt, contentWidth - PAD * 2)
        hdr:SetPoint("TOPLEFT", container, "TOPLEFT", PAD, yOffset)
        hdr:Show()
        yOffset = yOffset - hh - 4

        -- Split frame — anchors to bottom of container to fill space
        local splitFrame = CreateFrame("Frame", nil, container)
        splitFrame:SetPoint("TOPLEFT", container, "TOPLEFT", PAD, yOffset)
        splitFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -PAD, PAD)
        splitFrame:Show()

        -- Left: list panel
        local listBg = CreateFrame("Frame", nil, splitFrame, "BackdropTemplate")
        listBg:SetPoint("TOPLEFT", 0, 0)
        listBg:SetPoint("BOTTOMLEFT", 0, 0)
        listBg:SetWidth(LIST_WIDTH)
        listBg:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        listBg:SetBackdropColor(0.03, 0.03, 0.05, 0.6)
        listBg:SetBackdropBorderColor(0.25, 0.25, 0.3, 0.5)

        -- Execute buttons at top of list (e.g. Create New Bar)
        local listTopY = -6
        for _, execOpt in ipairs(executeArgs) do
            local execBtn = CreateFrame("Button", nil, listBg, "UIPanelButtonTemplate")
            execBtn:SetSize(LIST_WIDTH - 12, 22)
            execBtn:SetPoint("TOPLEFT", listBg, "TOPLEFT", 6, listTopY)
            execBtn:SetText(execOpt.name or "")
            execBtn:SetScript("OnClick", function()
                if execOpt.func then execOpt.func() end
            end)
            local fs = execBtn:GetFontString()
            if fs then fs:SetFontObject("GameFontHighlightSmall") end
            execBtn:Show()
            listTopY = listTopY - 26
        end

        -- List scroll (modern)
        local listScroll = CreateFrame("ScrollFrame", nil, listBg)
        listScroll:SetPoint("TOPLEFT", 4, listTopY - 2)
        listScroll:SetPoint("BOTTOMRIGHT", -14, 4)
        listScroll:EnableMouseWheel(true)

        local listScrollBar = CreateFrame("EventFrame", nil, listBg, "MinimalScrollBar")
        listScrollBar:SetPoint("TOPLEFT", listScroll, "TOPRIGHT", 2, 0)
        listScrollBar:SetPoint("BOTTOMLEFT", listScroll, "BOTTOMRIGHT", 2, 0)
        ScrollUtil.InitScrollFrameWithScrollBar(listScroll, listScrollBar)

        local listContent = CreateFrame("Frame", nil, listScroll)
        listContent:SetWidth(LIST_WIDTH - 22)
        listScroll:SetScrollChild(listContent)

        -- Right: detail panel
        local detailFrame = CreateFrame("Frame", nil, splitFrame, "BackdropTemplate")
        detailFrame:SetPoint("TOPLEFT", listBg, "TOPRIGHT", 4, 0)
        detailFrame:SetPoint("BOTTOMRIGHT", 0, 0)
        detailFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        detailFrame:SetBackdropColor(0.04, 0.04, 0.06, 0.4)
        detailFrame:SetBackdropBorderColor(0.25, 0.25, 0.3, 0.5)

        local detailScroll = CreateFrame("ScrollFrame", nil, detailFrame)
        detailScroll:SetPoint("TOPLEFT", 4, -4)
        detailScroll:SetPoint("BOTTOMRIGHT", -14, 4)
        detailScroll:EnableMouseWheel(true)

        local detailScrollBar = CreateFrame("EventFrame", nil, detailFrame, "MinimalScrollBar")
        detailScrollBar:SetPoint("TOPLEFT", detailScroll, "TOPRIGHT", 2, 0)
        detailScrollBar:SetPoint("BOTTOMLEFT", detailScroll, "BOTTOMRIGHT", 2, 0)
        ScrollUtil.InitScrollFrameWithScrollBar(detailScroll, detailScrollBar)

        local detailContent = CreateFrame("Frame", nil, detailScroll)
        detailContent:SetWidth(detailFrame:GetWidth() - 22)
        detailScroll:SetScrollChild(detailContent)

        -- Gather child groups
        local childGroups = {}
        local childSorted = SortedArgs(groupOpt.args)
        for _, child in ipairs(childSorted) do
            if child.type == "group" then
                childGroups[#childGroups + 1] = child
            end
        end

        local selectedItem = nil
        local listButtons = {}

        local function SelectGroup(index)
            selectedItem = index
            for i, btn in ipairs(listButtons) do
                if i == index then
                    btn.bg:SetColorTexture(0.15, 0.35, 0.6, 0.6)
                    btn.text:SetTextColor(1, 0.82, 0)
                else
                    btn.bg:SetColorTexture(0, 0, 0, 0)
                    btn.text:SetTextColor(0.8, 0.8, 0.8)
                end
            end
            ClearChildren(detailContent)
            local child = childGroups[index]
            if child and child.args then
                local dw = detailContent:GetWidth() - PAD
                if dw <= 0 then dw = 360 end
                local bottomY = RenderWidgets(detailContent, child.args, dw)
                detailContent:SetHeight(math.abs(bottomY) + PAD)
            end
        end

        -- Build list items
        local listY = 0
        for i, child in ipairs(childGroups) do
            local itemBtn = CreateFrame("Button", nil, listContent)
            itemBtn:SetSize(LIST_WIDTH - 26, LIST_ITEM_HEIGHT)
            itemBtn:SetPoint("TOPLEFT", 0, -listY)

            local bg = itemBtn:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0, 0, 0, 0)
            itemBtn.bg = bg

            local text = itemBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("LEFT", 8, 0)
            text:SetText(child.name or ("Item " .. i))
            text:SetTextColor(0.8, 0.8, 0.8)
            itemBtn.text = text

            itemBtn:SetScript("OnClick", function() SelectGroup(i) end)
            itemBtn:SetScript("OnEnter", function(self)
                if selectedItem ~= i then self.bg:SetColorTexture(0.1, 0.2, 0.4, 0.3) end
            end)
            itemBtn:SetScript("OnLeave", function(self)
                if selectedItem ~= i then self.bg:SetColorTexture(0, 0, 0, 0) end
            end)

            listButtons[#listButtons + 1] = itemBtn
            listY = listY + LIST_ITEM_HEIGHT
        end
        listContent:SetHeight(listY)

        -- Auto-select first
        if #childGroups > 0 then
            C_Timer.After(0, function()
                detailContent:SetWidth(detailFrame:GetWidth() - 28)
                SelectGroup(1)
            end)
        end

        detailFrame:SetScript("OnSizeChanged", function(self, w)
            detailContent:SetWidth(w - 28)
            if selectedItem then SelectGroup(selectedItem) end
        end)

        -- Split frame fills to bottom, no need to adjust yOffset further
    end

    -- If no two-panel groups, render any remaining groups flat (two-column aware)
    if #groupArgs == 0 then
        for _, opt in ipairs(sorted) do
            if opt.type == "group" and opt.args then
                local hdr, hh = CreateHeaderWidget(container, opt, contentWidth - PAD * 2)
                hdr:SetPoint("TOPLEFT", container, "TOPLEFT", PAD, yOffset)
                hdr:Show()
                yOffset = yOffset - hh - SPACING
                yOffset = RenderWidgets(container, opt.args, contentWidth - PAD * 2, opt.columns, yOffset)
            end
        end
    end

    container:SetHeight(math.abs(yOffset) + PAD)
end

---------------------------------------------------------------------------
-- ScrollFrame Canvas
---------------------------------------------------------------------------

local function CreateScrollCanvas(name)
    local container = CreateFrame("Frame", name, UIParent)
    container:Hide()

    -- Modern scroll: plain ScrollFrame + MinimalScrollBar
    local scroll = CreateFrame("ScrollFrame", nil, container)
    scroll:SetPoint("TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -14, 4)
    scroll:EnableMouseWheel(true)

    local scrollBar = CreateFrame("EventFrame", nil, container, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 4, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 0)

    ScrollUtil.InitScrollFrameWithScrollBar(scroll, scrollBar)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(scroll:GetWidth() or 600)
    scroll:SetScrollChild(content)

    container.scroll = scroll
    container.scrollBar = scrollBar
    container.content = content

    container:SetScript("OnSizeChanged", function(self, w)
        content:SetWidth(w - 22)
    end)

    return container
end

local function RenderIntoCanvas(container, optionsTable)
    -- Clear both the scroll content and any direct children on the container
    local content = container.content
    ClearChildren(content)

    -- Also clear any previous split frames attached directly to container
    if container.splitFrame then
        container.splitFrame:Hide()
        container.splitFrame:SetParent(nil)
        container.splitFrame = nil
    end
    if container.topFrame then
        container.topFrame:Hide()
        container.topFrame:SetParent(nil)
        container.topFrame = nil
    end

    local contentWidth = container:GetWidth() - 8
    if contentWidth <= 0 then contentWidth = 560 end

    -- Check if we have a two-panel group
    local args = optionsTable.args or {}
    local hasTwoPanel = false
    for _, opt in pairs(args) do
        if opt.type == "group" and HasChildGroups(opt.args) then
            hasTwoPanel = true
            break
        end
    end

    if hasTwoPanel then
        -- Hide the scroll frame — we render directly on the container
        container.scroll:Hide()
        CreateTwoPanelLayout(container, optionsTable)
    else
        -- Simple layout — use the scroll frame
        container.scroll:Show()
        local cw = content:GetWidth()
        if cw <= 0 then cw = 560 end
        CreateTwoPanelLayout(content, optionsTable)
    end
end

-- Expose for cross-module access (Profiles.lua needs to force re-render)
BazCore._RenderIntoCanvas = RenderIntoCanvas

---------------------------------------------------------------------------
-- Standalone Window
---------------------------------------------------------------------------

local standaloneWindow = nil

local function EnsureStandaloneWindow()
    if standaloneWindow then return standaloneWindow end

    local f = CreateFrame("Frame", "BazCoreOptionsWindow", UIParent, "BackdropTemplate")
    f:SetSize(720, 560)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)

    f:SetBackdrop(BazCore.backdrop)
    f:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
    f:SetBackdropBorderColor(0.2, 0.6, 1.0, 0.8)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -12)
    title:SetText("Options")
    title:SetTextColor(0.2, 0.6, 1.0)
    f.title = title

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)

    local canvas = CreateScrollCanvas(nil)
    canvas:SetParent(f)
    canvas:SetPoint("TOPLEFT", 8, -36)
    canvas:SetPoint("BOTTOMRIGHT", -8, 8)
    canvas:Show()
    f.canvas = canvas

    tinsert(UISpecialFrames, "BazCoreOptionsWindow")
    standaloneWindow = f
    return f
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function BazCore:RegisterOptionsTable(addonName, optionsTableOrFunc)
    optionsTables[addonName] = optionsTables[addonName] or {}
    optionsTables[addonName].func = optionsTableOrFunc
end

function BazCore:AddToSettings(addonName, displayName, parentName)
    local entry = optionsTables[addonName]
    if not entry or not entry.func then return end
    displayName = displayName or addonName

    local canvas = CreateScrollCanvas("BazCoreOptions_" .. addonName)
    local category
    if parentName and optionsTables[parentName] and optionsTables[parentName].category then
        category = Settings.RegisterCanvasLayoutSubcategory(
            optionsTables[parentName].category, canvas, displayName)
    else
        category = Settings.RegisterCanvasLayoutCategory(canvas, displayName)
        Settings.RegisterAddOnCategory(category)
    end

    entry.category = category
    entry.canvas = canvas

    canvas:SetScript("OnShow", function(self)
        local tbl = entry.func
        if type(tbl) == "function" then tbl = tbl() end
        if tbl then RenderIntoCanvas(self, tbl) end
    end)
end

function BazCore:OpenOptionsPanel(addonName)
    local entry = optionsTables[addonName]
    if not entry or not entry.func then return end
    if entry.category then
        Settings.OpenToCategory(entry.category:GetID())
        return
    end
    local win = EnsureStandaloneWindow()
    local tbl = entry.func
    if type(tbl) == "function" then tbl = tbl() end
    if not tbl then return end
    win.title:SetText(tbl.name or addonName)
    RenderIntoCanvas(win.canvas, tbl)
    win:Show()
end

function BazCore:RefreshOptions(addonName)
    local entry = optionsTables[addonName]
    if not entry then return end
    if entry.canvas then
        local tbl = entry.func
        if type(tbl) == "function" then tbl = tbl() end
        if tbl then RenderIntoCanvas(entry.canvas, tbl) end
    end
    if standaloneWindow and standaloneWindow:IsShown() then
        local tbl = entry.func
        if type(tbl) == "function" then tbl = tbl() end
        if tbl then RenderIntoCanvas(standaloneWindow.canvas, tbl) end
    end
end

---------------------------------------------------------------------------
-- Landing Page Builder
-- Standard landing page with Description, Features, Quick Guide, Commands
---------------------------------------------------------------------------

function BazCore:CreateLandingPage(addonName, content)
    local args = {}
    local order = 1

    -- Description
    if content.description then
        args.desc = {
            order = order,
            type = "description",
            name = content.description,
        }
        order = order + 1
    end

    -- Features
    if content.features then
        args.featuresHeader = {
            order = 10,
            type = "header",
            name = "Features",
        }
        args.features = {
            order = 11,
            type = "description",
            name = content.features,
        }
    end

    -- Quick Guide
    if content.guide then
        args.guideHeader = {
            order = 20,
            type = "header",
            name = "Quick Guide",
        }
        for i, entry in ipairs(content.guide) do
            args["guide" .. i] = {
                order = 20 + i,
                type = "description",
                name = "|cffffd700" .. entry[1] .. "|r — " .. entry[2],
            }
        end
    end

    -- Slash Commands
    if content.commands then
        args.commandsHeader = {
            order = 40,
            type = "header",
            name = "Slash Commands",
        }
        local cmdLines = {}
        for _, cmd in ipairs(content.commands) do
            cmdLines[#cmdLines + 1] = "|cff00ff00" .. cmd[1] .. "|r — " .. cmd[2]
        end
        args.commands = {
            order = 41,
            type = "description",
            name = table.concat(cmdLines, "\n"),
        }
    end

    return {
        name = addonName,
        subtitle = content.subtitle,
        type = "group",
        args = args,
    }
end

---------------------------------------------------------------------------
-- Global Options Page Builder
-- Creates a standard "Global Options" page where each override has
-- an enable toggle + a value widget. When enabled, the global value
-- overrides all local (per-module/per-instance) settings of the same key.
--
-- Usage:
--   BazCore:CreateGlobalOptionsPage(addonName, {
--       getOverrides = function() return db.globalOverrides end,
--       setOverride = function(key, field, value) ... end,
--       overrides = {
--           { key = "toastDuration", label = "Toast Duration", type = "slider",
--             default = 5, min = 1, max = 15, step = 1 },
--           { key = "soundEnabled", label = "Play Sound", type = "toggle", default = true },
--       },
--   })
--
-- The getOverrides function should return a table:
--   { [key] = { enabled = bool, value = <any> }, ... }
-- The setOverride function receives (key, "enabled"|"value", newValue).
---------------------------------------------------------------------------

function BazCore:CreateGlobalOptionsPage(addonName, config)
    local args = {}
    local order = 1

    args.desc = {
        order = order,
        type = "description",
        name = "Enable an override to apply it across all modules. " ..
            "When active, the corresponding local setting in each module is ignored.",
        fontSize = "small",
    }
    order = order + 1

    for _, def in ipairs(config.overrides) do
        local key = def.key

        -- Section header
        args[key .. "_header"] = {
            order = order,
            type = "header",
            name = def.label,
        }
        order = order + 1

        -- Override enable toggle
        args[key .. "_enabled"] = {
            order = order,
            type = "toggle",
            name = "Override all modules",
            desc = "When enabled, all modules use the global value below instead of their local setting.",
            get = function()
                local overrides = config.getOverrides()
                return overrides[key] and overrides[key].enabled or false
            end,
            set = function(_, val)
                config.setOverride(key, "enabled", val)
                -- Refresh the page to update disabled states
                BazCore:RefreshOptions(addonName .. "-GlobalOptions")
            end,
        }
        order = order + 1

        -- Value widget (toggle or slider)
        if def.type == "toggle" then
            args[key .. "_value"] = {
                order = order,
                type = "toggle",
                name = def.label,
                get = function()
                    local overrides = config.getOverrides()
                    if overrides[key] and overrides[key].value ~= nil then
                        return overrides[key].value ~= false
                    end
                    return def.default ~= false
                end,
                set = function(_, val)
                    config.setOverride(key, "value", val)
                end,
                disabled = function()
                    local overrides = config.getOverrides()
                    return not (overrides[key] and overrides[key].enabled)
                end,
            }
        elseif def.type == "slider" then
            args[key .. "_value"] = {
                order = order,
                type = "range",
                name = def.label,
                min = def.min or 1,
                max = def.max or 15,
                step = def.step or 1,
                get = function()
                    local overrides = config.getOverrides()
                    if overrides[key] and overrides[key].value ~= nil then
                        return overrides[key].value
                    end
                    return def.default or def.min or 1
                end,
                set = function(_, val)
                    config.setOverride(key, "value", val)
                end,
                disabled = function()
                    local overrides = config.getOverrides()
                    return not (overrides[key] and overrides[key].enabled)
                end,
            }
        end
        order = order + 1
    end

    return {
        name = "Global Options",
        type = "group",
        args = args,
    }
end
