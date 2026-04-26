---------------------------------------------------------------------------
-- BazCore Options: Widget Factories
-- Each factory creates a UI widget and returns (frame, height).
-- Redesigned with larger fonts and cleaner styling.
---------------------------------------------------------------------------

local O = BazCore._Options

---------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------

local function CreateDescriptionWidget(parent, opt, contentWidth)
    local frame = CreateFrame("Frame", nil, parent)
    local font = opt.fontSize == "small" and O.SMALL_FONT or O.DESC_FONT
    local fs = frame:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(font)
    fs:SetPoint("TOPLEFT")
    fs:SetWidth(contentWidth)
    fs:SetJustifyH("LEFT")
    fs:SetText(opt.name or "")
    fs:SetTextColor(unpack(O.TEXT_DESC))
    fs:SetWordWrap(true)
    local h = fs:GetStringHeight() + 4
    frame:SetSize(contentWidth, h)
    return frame, h
end

---------------------------------------------------------------------------
-- Header
---------------------------------------------------------------------------

local function CreateHeaderWidget(parent, opt, contentWidth)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(contentWidth, O.HEADER_HEIGHT)
    local text = frame:CreateFontString(nil, "OVERLAY", O.HEADER_FONT)
    text:SetPoint("LEFT", 0, 0)
    text:SetText(opt.name or "")
    text:SetTextColor(unpack(O.GOLD))
    if opt.name and opt.name ~= "" then
        local line = frame:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetPoint("LEFT", text, "RIGHT", 8, 0)
        line:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
        line:SetColorTexture(unpack(O.HEADER_LINE))
    end
    return frame, O.HEADER_HEIGHT
end

---------------------------------------------------------------------------
-- Toggle (Checkbox)
---------------------------------------------------------------------------

local function CreateToggleWidget(parent, opt, contentWidth)
    local frame = CreateFrame("Frame", nil, parent)
    local cb = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 0, 0)
    cb:SetChecked(opt.get and opt.get() or false)
    cb:SetScript("OnClick", function(self)
        if opt.set then opt.set(nil, self:GetChecked()) end
    end)

    local label = frame:CreateFontString(nil, "OVERLAY", O.LABEL_FONT)
    label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    label:SetText(opt.name or "")

    local totalH = O.WIDGET_HEIGHT
    if opt.desc then
        local desc = frame:CreateFontString(nil, "OVERLAY", O.DESC_FONT)
        desc:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 28, -2)
        desc:SetWidth(contentWidth - 32)
        desc:SetJustifyH("LEFT")
        desc:SetText(opt.desc)
        desc:SetTextColor(unpack(O.TEXT_DESC))
        desc:SetWordWrap(true)
        totalH = totalH + desc:GetStringHeight() + 6
    end

    frame:SetSize(contentWidth, totalH)

    -- Dynamic disabled state
    frame:SetScript("OnShow", function()
        local disabled = O.IsDisabled(opt)
        cb:SetEnabled(not disabled)
        cb:SetChecked(opt.get and opt.get() or false)
        label:SetTextColor(disabled and 0.4 or 0.9, disabled and 0.4 or 0.9, disabled and 0.4 or 0.9)
    end)

    return frame, totalH
end

---------------------------------------------------------------------------
-- Range (Slider)
---------------------------------------------------------------------------

local function CreateRangeWidget(parent, opt, contentWidth)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(contentWidth, 54)

    local label = frame:CreateFontString(nil, "OVERLAY", O.LABEL_FONT)
    label:SetPoint("TOPLEFT", 0, 0)

    local function FormatValue(val)
        if opt.isPercent then return math.floor((val or 0) * 100) .. "%" end
        if opt.format then return string.format(opt.format, val or 0) end
        local step = opt.step or 1
        if step < 1 then return string.format("%.1f", val or 0) end
        return tostring(math.floor(val or 0))
    end

    local val = opt.get and opt.get() or opt.min or 0
    label:SetText((opt.name or "") .. ": " .. FormatValue(val))

    local slider = CreateFrame("Frame", nil, frame, "MinimalSliderWithSteppersTemplate")
    slider:SetPoint("TOPLEFT", 0, -22)
    slider:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    slider:SetHeight(20)

    local minVal = opt.min or 0
    local maxVal = opt.max or 100
    local step = opt.step or 1
    local steps = math.max(1, math.floor((maxVal - minVal) / step))

    slider.Slider:SetMinMaxValues(minVal, maxVal)
    slider.Slider:SetValueStep(step)
    slider.Slider:SetObeyStepOnDrag(true)
    slider.Slider:SetValue(val)

    slider.Slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        if opt.set then opt.set(nil, value) end
        label:SetText((opt.name or "") .. ": " .. FormatValue(value))
    end)

    -- Disabled state
    frame:SetScript("OnShow", function()
        local disabled = O.IsDisabled(opt)
        slider.Slider:SetEnabled(not disabled)
        slider.Back:SetEnabled(not disabled)
        slider.Forward:SetEnabled(not disabled)
        label:SetTextColor(disabled and 0.4 or 0.9, disabled and 0.4 or 0.9, disabled and 0.4 or 0.9)
        local v = opt.get and opt.get() or minVal
        slider.Slider:SetValue(v)
        label:SetText((opt.name or "") .. ": " .. FormatValue(v))
    end)

    return frame, 54
end

---------------------------------------------------------------------------
-- Input (EditBox)
---------------------------------------------------------------------------

local function CreateInputWidget(parent, opt, contentWidth)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(contentWidth, 50)

    local label = frame:CreateFontString(nil, "OVERLAY", O.LABEL_FONT)
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(opt.name or "")

    local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    editBox:SetPoint("TOPLEFT", 0, -20)
    editBox:SetSize(math.min(contentWidth, 400), 22)
    editBox:SetAutoFocus(false)
    editBox:SetText(opt.get and opt.get() or "")
    editBox:SetScript("OnEnterPressed", function(self)
        if opt.set then opt.set(nil, self:GetText()) end
        self:ClearFocus()
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        self:SetText(opt.get and opt.get() or "")
        self:ClearFocus()
    end)

    return frame, 50
end

---------------------------------------------------------------------------
-- Execute (Button)
---------------------------------------------------------------------------

local function CreateExecuteWidget(parent, opt, contentWidth)
    local frame = CreateFrame("Frame", nil, parent)
    local isHalf = (opt.width == "half")
    local borderless = opt.borderless
    frame:SetSize(contentWidth, O.WIDGET_HEIGHT + 4)
    local btnWidth = isHalf and contentWidth or math.min(260, contentWidth)
    -- Use if/else; the `and/or` ternary breaks when the true value is nil
    local template
    if borderless then
        template = nil
    else
        template = "UIPanelButtonTemplate"
    end
    local btn = CreateFrame("Button", nil, frame, template)
    btn:SetPoint("LEFT", 0, 0)
    btn:SetSize(btnWidth, O.WIDGET_HEIGHT)
    if borderless then
        -- Static display: just a centered label, no hover, not clickable
        btn:EnableMouse(false)
        btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        btn.label:SetPoint("CENTER")
        btn.label:SetText(opt.name or "")
    else
        btn:SetText(opt.name or "Execute")
    end

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

    -- Disabled state
    frame:SetScript("OnShow", function()
        btn:SetEnabled(not O.IsDisabled(opt))
    end)

    return frame, O.WIDGET_HEIGHT + 4
end

---------------------------------------------------------------------------
-- Select (Dropdown)
---------------------------------------------------------------------------

local function CreateSelectWidget(parent, opt, contentWidth)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(contentWidth, 50)

    local label = frame:CreateFontString(nil, "OVERLAY", O.LABEL_FONT)
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(opt.name or "")

    local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btn:SetPoint("TOPLEFT", 0, -22)
    btn:SetHeight(22)

    -- Measuring FontString — same family as UIPanelButtonTemplate uses,
    -- hidden so it doesn't render. We poke text into it just to read
    -- back the rendered width without disturbing the button's label.
    local probe = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    probe:Hide()

    local function GetValues()
        local v = opt.values
        if type(v) == "function" then v = v() end
        return v or {}
    end

    -- Size the button to the WIDEST value text in the dropdown so the
    -- label never overflows the button chrome (the previous fixed
    -- 200 px cap clipped strings like "Sections (header + grid per
    -- category)"). 24 px of padding accounts for the template's
    -- internal margins on each side; clamped to contentWidth as the
    -- absolute upper bound and 80 px as a sensible lower bound.
    local MIN_W = 80
    local PADDING = 24
    local function ResizeToFitLongest()
        local values = GetValues()
        local maxW = MIN_W
        for _, v in pairs(values) do
            probe:SetText(v)
            local w = probe:GetStringWidth() or 0
            if w > maxW then maxW = w end
        end
        local final = math.min(maxW + PADDING, contentWidth)
        btn:SetWidth(final)
    end

    local function UpdateLabel()
        local val = opt.get and opt.get()
        local values = GetValues()
        btn:SetText(values[val] or val or "Select...")
    end

    UpdateLabel()
    ResizeToFitLongest()

    btn:SetScript("OnClick", function(self)
        local values = GetValues()
        MenuUtil.CreateContextMenu(self, function(owner, rootDescription)
            for k, v in pairs(values) do
                rootDescription:CreateButton(v, function()
                    if opt.set then opt.set(nil, k) end
                    UpdateLabel()
                end)
            end
        end)
    end)

    frame:SetScript("OnShow", function()
        UpdateLabel()
        ResizeToFitLongest()
        btn:SetEnabled(not O.IsDisabled(opt))
    end)

    return frame, 50
end

---------------------------------------------------------------------------
-- Factory Registry
---------------------------------------------------------------------------

O.widgetFactories = {
    description = CreateDescriptionWidget,
    header      = CreateHeaderWidget,
    toggle      = CreateToggleWidget,
    range       = CreateRangeWidget,
    input       = CreateInputWidget,
    execute     = CreateExecuteWidget,
    select      = CreateSelectWidget,
}
