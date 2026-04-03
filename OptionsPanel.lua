---------------------------------------------------------------------------
-- BazCore: OptionsPanel Module
-- Rich options table renderer (replaces AceConfig + AceConfigDialog)
-- Supports: group, toggle, range, select, input, execute, description, header
---------------------------------------------------------------------------

local optionsTables = {}  -- [addonName] = { func, category, frame, parentName }

local PAD = 12
local WIDGET_HEIGHT = 28
local HEADER_HEIGHT = 24
local SPACING = 6
local DESC_FONT = "GameFontHighlightSmall"
local LABEL_FONT = "GameFontHighlight"

---------------------------------------------------------------------------
-- Utility: sort args by order
---------------------------------------------------------------------------

local function SortedArgs(args)
    if not args then return {} end
    local sorted = {}
    for key, opt in pairs(args) do
        opt._key = key
        table.insert(sorted, opt)
    end
    table.sort(sorted, function(a, b)
        return (a.order or 100) < (b.order or 100)
    end)
    return sorted
end

---------------------------------------------------------------------------
-- Widget Factories
-- Each returns (frame, height)
---------------------------------------------------------------------------

local function CreateDescriptionWidget(parent, opt, contentWidth)
    local fs = parent:CreateFontString(nil, "OVERLAY", DESC_FONT)
    fs:SetWidth(contentWidth)
    fs:SetJustifyH("LEFT")
    fs:SetText(opt.name or "")
    if opt.fontSize == "medium" then
        fs:SetFontObject(GameFontNormal)
    end
    fs:SetWordWrap(true)
    local h = fs:GetStringHeight()
    return fs, math.max(h, 8)
end

local function CreateHeaderWidget(parent, opt, contentWidth)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(contentWidth, HEADER_HEIGHT)

    -- Header text
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", 0, 0)
    text:SetText(opt.name or "")
    text:SetTextColor(0.2, 0.6, 1.0)

    -- Divider line
    if opt.name and opt.name ~= "" then
        local line = frame:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetPoint("LEFT", text, "RIGHT", 8, 0)
        line:SetPoint("RIGHT", frame, "RIGHT")
        line:SetColorTexture(0.3, 0.3, 0.35, 0.6)
    end

    return frame, HEADER_HEIGHT
end

local function CreateToggleWidget(parent, opt, contentWidth)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(contentWidth, WIDGET_HEIGHT)

    local cb = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    cb:SetPoint("LEFT", 0, 0)
    cb:SetSize(20, 20)

    if opt.get then
        cb:SetChecked(opt.get())
    end

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
        local extra = desc:GetStringHeight()
        frame:SetHeight(WIDGET_HEIGHT + extra)
    end

    cb:SetScript("OnClick", function(self)
        if opt.set then
            opt.set(nil, self:GetChecked())
        end
    end)

    return frame, frame:GetHeight()
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
        if opt.isPercent then
            return string.format("%d%%", v * 100)
        elseif opt.step and opt.step < 1 then
            return string.format("%.2f", v)
        else
            return tostring(math.floor(v))
        end
    end
    valText:SetText(FormatValue(currentVal))

    slider.Slider:SetScript("OnValueChanged", function(_, value)
        local step = opt.step or 1
        value = math.floor(value / step + 0.5) * step
        valText:SetText(FormatValue(value))
        if opt.set then
            opt.set(nil, value)
        end
    end)

    if opt.desc then
        local desc = frame:CreateFontString(nil, "OVERLAY", DESC_FONT)
        desc:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -4)
        desc:SetWidth(contentWidth)
        desc:SetJustifyH("LEFT")
        desc:SetText(opt.desc)
        desc:SetTextColor(0.5, 0.5, 0.5)
        height = height + desc:GetStringHeight() + 4
        frame:SetHeight(height)
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

    if opt.get then
        editBox:SetText(opt.get() or "")
    end

    editBox:SetScript("OnEnterPressed", function(self)
        if opt.set then
            opt.set(nil, self:GetText())
        end
        self:ClearFocus()
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        if opt.get then
            self:SetText(opt.get() or "")
        end
        self:ClearFocus()
    end)

    return frame, height
end

local function CreateExecuteWidget(parent, opt, contentWidth)
    local frame = CreateFrame("Frame", nil, parent)
    local btnWidth = contentWidth
    if opt.width and opt.width ~= "full" then
        btnWidth = contentWidth * (tonumber(opt.width) or 1)
    end
    frame:SetSize(contentWidth, WIDGET_HEIGHT + 4)

    local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btn:SetPoint("LEFT", 0, 0)
    btn:SetSize(math.min(btnWidth, contentWidth), WIDGET_HEIGHT)
    btn:SetText(opt.name or "Execute")

    btn:SetScript("OnClick", function()
        if opt.confirm then
            local text = opt.confirmText or ("Are you sure?")
            StaticPopupDialogs["BAZCORE_CONFIRM_EXEC"] = {
                text = text,
                button1 = "Yes",
                button2 = "No",
                OnAccept = function()
                    if opt.func then opt.func() end
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
            }
            StaticPopup_Show("BAZCORE_CONFIRM_EXEC")
        else
            if opt.func then opt.func() end
        end
    end)

    -- Tooltip
    if opt.desc then
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(opt.desc, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
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

    -- Dropdown button
    local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btn:SetPoint("TOPLEFT", 0, -16)
    btn:SetSize(200, 24)

    local function GetCurrentLabel()
        local val = opt.get and opt.get()
        local values = opt.values or {}
        if type(values) == "function" then values = values() end
        return values[val] or tostring(val or "")
    end
    btn:SetText(GetCurrentLabel())

    btn:SetScript("OnClick", function(self)
        local values = opt.values or {}
        if type(values) == "function" then values = values() end

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

---------------------------------------------------------------------------
-- Layout Engine
-- Renders a sorted list of options into a parent frame
---------------------------------------------------------------------------

local function ClearChildren(frame)
    -- Hide and release all child frames/fontstrings
    for _, child in pairs({ frame:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    for _, region in pairs({ frame:GetRegions() }) do
        region:Hide()
        region:SetParent(nil)
    end
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

local function RenderGroup(parent, args, contentWidth, yOffset, depth)
    depth = depth or 0
    local sorted = SortedArgs(args)
    local indent = depth * 16

    for _, opt in ipairs(sorted) do
        if opt.type == "group" then
            -- Render group header
            local headerFrame = CreateFrame("Frame", nil, parent)
            headerFrame:SetSize(contentWidth, HEADER_HEIGHT)
            headerFrame:SetPoint("TOPLEFT", PAD + indent, yOffset)

            local headerText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            headerText:SetPoint("LEFT", 0, 0)
            headerText:SetText(opt.name or "")
            headerText:SetTextColor(0.2, 0.6, 1.0)

            local line = headerFrame:CreateTexture(nil, "ARTWORK")
            line:SetHeight(1)
            line:SetPoint("LEFT", headerText, "RIGHT", 8, 0)
            line:SetPoint("RIGHT", headerFrame, "RIGHT")
            line:SetColorTexture(0.3, 0.3, 0.35, 0.6)

            yOffset = yOffset - HEADER_HEIGHT - SPACING

            -- Render group children
            if opt.args then
                yOffset = RenderGroup(parent, opt.args, contentWidth, yOffset, depth + 1)
            end

            yOffset = yOffset - SPACING
        else
            local factory = widgetFactories[opt.type]
            if factory then
                local widget, h = factory(parent, opt, contentWidth - indent)
                if type(widget.SetPoint) == "function" then
                    widget:SetPoint("TOPLEFT", PAD + indent, yOffset)
                else
                    -- FontString — wrap in a holder frame
                    local holder = CreateFrame("Frame", nil, parent)
                    holder:SetSize(contentWidth - indent, h)
                    holder:SetPoint("TOPLEFT", PAD + indent, yOffset)
                    widget:SetParent(holder)
                    widget:ClearAllPoints()
                    widget:SetPoint("TOPLEFT", 0, 0)
                end
                widget:Show()
                yOffset = yOffset - h - SPACING
            end
        end
    end

    return yOffset
end

---------------------------------------------------------------------------
-- Canvas Panel with ScrollFrame
---------------------------------------------------------------------------

local function CreateScrollCanvas(name)
    local container = CreateFrame("Frame", name, UIParent)
    container:Hide()

    local scroll = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -24, 4)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(scroll:GetWidth() or 600)
    scroll:SetScrollChild(content)

    container.scroll = scroll
    container.content = content

    -- Update content width when container resizes
    container:SetScript("OnSizeChanged", function(self, w, h)
        scroll:SetPoint("TOPLEFT", 4, -4)
        scroll:SetPoint("BOTTOMRIGHT", -24, 4)
        content:SetWidth(w - 32)
    end)

    return container
end

local function RenderIntoCanvas(container, optionsTable)
    local content = container.content
    ClearChildren(content)

    local contentWidth = content:GetWidth() - (PAD * 2)
    if contentWidth <= 0 then contentWidth = 560 end

    local yOffset = -PAD
    local args = optionsTable.args or {}

    yOffset = RenderGroup(content, args, contentWidth, yOffset, 0)

    content:SetHeight(math.abs(yOffset) + PAD)
end

---------------------------------------------------------------------------
-- Standalone Options Window
---------------------------------------------------------------------------

local standaloneWindow = nil

local function EnsureStandaloneWindow()
    if standaloneWindow then return standaloneWindow end

    local f = CreateFrame("Frame", "BazCoreOptionsWindow", UIParent, "BackdropTemplate")
    f:SetSize(680, 520)
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

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -12)
    title:SetText("Options")
    title:SetTextColor(0.2, 0.6, 1.0)
    f.title = title

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)

    -- Content area
    local canvas = CreateScrollCanvas(nil)
    canvas:SetParent(f)
    canvas:SetPoint("TOPLEFT", 8, -36)
    canvas:SetPoint("BOTTOMRIGHT", -8, 8)
    canvas:Show()
    f.canvas = canvas

    -- Escape to close
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
            optionsTables[parentName].category, canvas, displayName
        )
    else
        category = Settings.RegisterCanvasLayoutCategory(canvas, displayName)
        Settings.RegisterAddOnCategory(category)
    end

    entry.category = category
    entry.canvas = canvas

    -- Render on first show
    canvas:SetScript("OnShow", function(self)
        local tbl = entry.func
        if type(tbl) == "function" then tbl = tbl() end
        if tbl then
            RenderIntoCanvas(self, tbl)
        end
        self:SetScript("OnShow", function(s)
            -- Re-render each time panel is shown (dynamic content)
            local t = entry.func
            if type(t) == "function" then t = t() end
            if t then RenderIntoCanvas(s, t) end
        end)
    end)
end

function BazCore:OpenOptionsPanel(addonName)
    local entry = optionsTables[addonName]
    if not entry or not entry.func then return end

    -- Try opening in Blizzard Settings first
    if entry.category then
        Settings.OpenToCategory(entry.category:GetID())
        return
    end

    -- Fallback: standalone window
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

    -- Re-render canvas if it exists and is shown
    if entry.canvas and entry.canvas:IsShown() then
        local tbl = entry.func
        if type(tbl) == "function" then tbl = tbl() end
        if tbl then
            RenderIntoCanvas(entry.canvas, tbl)
        end
    end

    -- Re-render standalone window if showing this addon
    if standaloneWindow and standaloneWindow:IsShown() then
        local tbl = entry.func
        if type(tbl) == "function" then tbl = tbl() end
        if tbl then
            RenderIntoCanvas(standaloneWindow.canvas, tbl)
        end
    end
end
