---------------------------------------------------------------------------
-- BazCore Options: Registration & Rendering
-- Public API (RegisterOptionsTable, AddToSettings, OpenOptionsPanel,
-- RefreshOptions) plus the main page renderer and canvas system.
---------------------------------------------------------------------------

local O = BazCore._Options
local optionsTables = BazCore._optionsTables or {}
BazCore._optionsTables = optionsTables

---------------------------------------------------------------------------
-- CreateScrollCanvas — reusable scrollable content container
---------------------------------------------------------------------------

local function CreateScrollCanvas(parent)
    local container = CreateFrame("Frame", nil, parent)
    container:SetAllPoints()

    local scroll = CreateFrame("ScrollFrame", nil, container)
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -18, 0)
    scroll:EnableMouseWheel(true)

    local scrollBar = CreateFrame("EventFrame", nil, container, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 4, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 0)
    ScrollUtil.InitScrollFrameWithScrollBar(scroll, scrollBar)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(scroll:GetWidth())
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(self, w)
        content:SetWidth(w)
    end)

    container.scroll = scroll
    container.scrollBar = scrollBar
    container.content = content
    return container
end

---------------------------------------------------------------------------
-- CreateTwoPanelLayout — main page renderer
-- Handles title, icon, subtitle, inline groups, two-panel groups,
-- and flat widget rendering.
---------------------------------------------------------------------------

local function CreateTwoPanelLayout(container, optionsTable)
    local args = optionsTable.args or {}
    local contentWidth = container:GetWidth() or 600

    -- Split args into: topArgs, groupArgs (with child groups), executeArgs
    local topArgs, groupArgs, executeArgs = {}, {}, {}
    local sortedRoot = O.SortedArgs(args)
    local hasTwoPanelGroups = false

    for _, opt in ipairs(sortedRoot) do
        if opt.type == "group" and opt.inline then
            topArgs[#topArgs + 1] = opt
        elseif opt.type == "group" and not opt.inline and opt.args then
            -- Any non-inline group with an args table is a list/detail candidate
            -- (even if currently empty — the list just shows no items)
            groupArgs[#groupArgs + 1] = opt
            hasTwoPanelGroups = true
        elseif opt.type == "execute" and not hasTwoPanelGroups then
            executeArgs[#executeArgs + 1] = opt
        else
            topArgs[#topArgs + 1] = opt
        end
    end

    -- Header section (title, icon, version, subtitle)
    local yOffset = -O.PAD
    local headerHeight = 44

    local titleFrame = CreateFrame("Frame", nil, container)
    titleFrame:SetSize(contentWidth, headerHeight)
    titleFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    titleFrame:Show()

    local titleAnchor = CreateFrame("Frame", nil, titleFrame)
    titleAnchor:SetAllPoints()

    local titleXOffset = O.PAD
    local addonIcon = nil

    -- Try to get addon icon from config or TOC metadata
    local addonConfig = BazCore.addons and BazCore.addons[optionsTable.name]
    local iconTex = addonConfig and addonConfig.minimap and addonConfig.minimap.icon
    if not iconTex and C_AddOns and C_AddOns.GetAddOnMetadata then
        iconTex = C_AddOns.GetAddOnMetadata(optionsTable.name, "IconTexture")
    end
    if iconTex then
        addonIcon = titleFrame:CreateTexture(nil, "ARTWORK")
        addonIcon:SetSize(32, 32)
        addonIcon:SetPoint("TOPLEFT", O.PAD, -6)
        addonIcon:SetTexture(iconTex)
        titleXOffset = O.PAD + 40
    end

    local titleText = titleFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOPLEFT", titleXOffset, -6)
    titleText:SetText(optionsTable.name or "")
    titleText:SetTextColor(unpack(O.GOLD))

    -- Version
    local addonVersion = addonConfig and addonConfig.version
    if not addonVersion and optionsTable.name then
        addonVersion = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(optionsTable.name, "Version")
    end
    if addonVersion then
        local versionText = titleFrame:CreateFontString(nil, "OVERLAY", O.SMALL_FONT)
        versionText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -2)
        versionText:SetText("v" .. addonVersion)
        versionText:SetTextColor(unpack(O.DIM))
        headerHeight = headerHeight + 6
    end

    local titleLine = titleFrame:CreateTexture(nil, "ARTWORK")
    titleLine:SetHeight(1)
    titleLine:SetPoint("BOTTOMLEFT", O.PAD, 0)
    titleLine:SetPoint("BOTTOMRIGHT", -O.PAD, 0)
    titleLine:SetColorTexture(unpack(O.HEADER_LINE))

    titleFrame:SetHeight(headerHeight)
    yOffset = yOffset - headerHeight

    -- Top-level args (non-group items, inline groups)
    local hasTopGroups = false
    for _, opt in ipairs(topArgs) do
        if opt.type == "group" and opt.inline then
            hasTopGroups = true
            break
        end
    end

    if not hasTwoPanelGroups and not hasTopGroups then
        -- Simple flat page: render everything with RenderWidgets
        yOffset = O.RenderWidgets(container, args, contentWidth, nil, yOffset)
    else
        -- Render top-level items first
        for _, opt in ipairs(topArgs) do
            if opt.type == "group" and opt.inline then
                -- Inline group: bordered panel with header + children
                local hdr, hh = O.widgetFactories.header(container, opt, contentWidth - O.PAD * 2)
                hdr:SetPoint("TOPLEFT", container, "TOPLEFT", O.PAD, yOffset)
                hdr:Show()
                yOffset = yOffset - hh - O.SPACING

                if opt.args then
                    yOffset = O.RenderWidgets(container, opt.args, contentWidth - O.PAD * 2, opt.columns, yOffset)
                end
            elseif opt.type == "group" then
                local hdr, hh = O.widgetFactories.header(container, opt, contentWidth - O.PAD * 2)
                hdr:SetPoint("TOPLEFT", container, "TOPLEFT", O.PAD, yOffset)
                hdr:Show()
                yOffset = yOffset - hh - O.SPACING
                if opt.args then
                    yOffset = O.RenderWidgets(container, opt.args, contentWidth - O.PAD * 2, opt.columns, yOffset)
                end
            elseif opt.type ~= "group" then
                local factory = O.widgetFactories[opt.type]
                if factory then
                    local widget, h = factory(container, opt, contentWidth - O.PAD * 2)
                    widget:SetPoint("TOPLEFT", container, "TOPLEFT", O.PAD, yOffset)
                    widget:Show()
                    yOffset = yOffset - h - O.SPACING
                end
            end
        end
    end

    -- Two-panel groups (list/detail)
    for _, groupOpt in ipairs(groupArgs) do
        -- Section header (skip if name is empty)
        if groupOpt.name and groupOpt.name ~= "" then
            local hdr, hh = O.widgetFactories.header(container, groupOpt, contentWidth - O.PAD * 2)
            hdr:SetPoint("TOPLEFT", container, "TOPLEFT", O.PAD, yOffset)
            hdr:Show()
            yOffset = yOffset - hh - 4
        end

        O.BuildListDetailPanel(container, groupOpt, contentWidth, yOffset, executeArgs)
    end

    container:SetHeight(math.abs(yOffset) + O.PAD)
end

---------------------------------------------------------------------------
-- RenderIntoCanvas — universal renderer
---------------------------------------------------------------------------

local function RenderIntoCanvas(container, optionsTable)
    -- Check if this page has list/detail groups (they handle own scrolling)
    local hasTwoPanelGroups = false
    if optionsTable.args then
        for _, opt in pairs(optionsTable.args) do
            if type(opt) == "table" and opt.type == "group" and not opt.inline and opt.args then
                hasTwoPanelGroups = true
                break
            end
        end
    end

    -- Clean up previous render
    if container._scrollFrame then
        container._scrollFrame:Hide()
        container._scrollFrame:SetParent(nil)
        container._scrollFrame = nil
        container._renderTarget = nil
    end
    if container._renderTarget then
        O.ClearChildren(container._renderTarget)
    end
    if container.splitFrame then
        container.splitFrame:Hide()
        container.splitFrame:SetParent(nil)
        container.splitFrame = nil
    end

    if hasTwoPanelGroups then
        -- List/detail pages: render directly into container (no scroll needed,
        -- the list/detail panels handle their own scrolling)
        if not container._renderTarget then
            container._renderTarget = CreateFrame("Frame", nil, container)
            container._renderTarget:SetAllPoints()
        end
        O.ClearChildren(container._renderTarget)
        CreateTwoPanelLayout(container._renderTarget, optionsTable)
    else
        -- Scrollable pages (landing, settings, modules, etc.)
        local scroll = CreateFrame("ScrollFrame", nil, container)
        scroll:SetPoint("TOPLEFT", 0, 0)
        scroll:SetPoint("BOTTOMRIGHT", -18, 0)
        scroll:EnableMouseWheel(true)
        container._scrollFrame = scroll

        local scrollBar = CreateFrame("EventFrame", nil, container, "MinimalScrollBar")
        scrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 4, 0)
        scrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 0)
        ScrollUtil.InitScrollFrameWithScrollBar(scroll, scrollBar)

        local content = CreateFrame("Frame", nil, scroll)
        content:SetWidth(scroll:GetWidth())
        scroll:SetScrollChild(content)

        scroll:SetScript("OnSizeChanged", function(self, w)
            content:SetWidth(w)
        end)

        container._renderTarget = content
        -- Pass a known width since content frame isn't sized yet.
        -- The scroll area is canvas width minus scrollbar space (18px).
        local knownWidth = container:GetWidth() - 18
        if knownWidth <= 0 then knownWidth = 600 end
        content:SetWidth(knownWidth)
        CreateTwoPanelLayout(content, optionsTable)
    end
end

BazCore._RenderIntoCanvas = RenderIntoCanvas

---------------------------------------------------------------------------
-- Standalone Window
---------------------------------------------------------------------------

local standaloneWindow

local function EnsureStandaloneWindow()
    if standaloneWindow then return standaloneWindow end

    local f = CreateFrame("Frame", "BazCoreOptionsWindow", UIParent, "BackdropTemplate")
    f:SetSize(700, 550)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    f:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
    f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetTextColor(unpack(O.GOLD))
    f.title = title

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    f.canvas = CreateScrollCanvas(f)
    f.canvas:SetPoint("TOPLEFT", 12, -40)
    f.canvas:SetPoint("BOTTOMRIGHT", -12, 12)

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
    if not entry then return end

    -- Plain frame — Blizzard's Settings system handles parenting.
    local canvas = CreateFrame("Frame")
    entry.canvas = canvas

    local function DoRender()
        local tbl = entry.func
        if type(tbl) == "function" then tbl = tbl() end
        if tbl and canvas:GetWidth() > 0 then
            RenderIntoCanvas(canvas, tbl)
            canvas._rendered = true
        end
    end

    local function OnShow()
        canvas._rendered = false
        -- Delay slightly so Blizzard's layout system has sized the canvas
        C_Timer.After(0, DoRender)
    end

    if parentName then
        local parentEntry = optionsTables[parentName]
        if parentEntry and parentEntry.category then
            local sub = Settings.RegisterCanvasLayoutSubcategory(parentEntry.category, canvas, displayName)
            entry.category = sub
            entry.categoryID = sub:GetID()
        end
    else
        local category = Settings.RegisterCanvasLayoutCategory(canvas, displayName)
        Settings.RegisterAddOnCategory(category)
        entry.category = category
        entry.categoryID = category:GetID()
    end

    canvas:SetScript("OnShow", OnShow)
    canvas:SetScript("OnSizeChanged", function()
        if canvas:IsShown() and not canvas._rendered then
            DoRender()
        end
    end)
    entry.onShow = OnShow
end

function BazCore:OpenOptionsPanel(addonName)
    local entry = optionsTables[addonName]
    if entry and entry.category then
        -- Try GetID first (returns numeric ID in Midnight)
        local ok, err = pcall(function()
            Settings.OpenToCategory(entry.category:GetID())
        end)
        if ok then return end
        -- Fallback: try passing the category object
        ok = pcall(function()
            Settings.OpenToCategory(entry.category)
        end)
        if ok then return end
    end

    local win = EnsureStandaloneWindow()
    win.title:SetText(addonName)
    local tbl = entry and entry.func
    if type(tbl) == "function" then tbl = tbl() end
    if tbl then RenderIntoCanvas(win.canvas, tbl) end
    win:Show()
    win:Raise()
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
