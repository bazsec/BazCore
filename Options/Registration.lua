---------------------------------------------------------------------------
-- BazCore Options: Registration & Window
--
-- Provides the BazCore options window — a large standalone frame with:
--   * Bottom tabs, one per top-level Baz addon
--   * Left sidebar, one item per sub-category of the active addon
--   * Content area on the right
--
-- Addons register via BazCore:RegisterOptionsTable() and
-- BazCore:AddToSettings(). All options are displayed inside BazCore's
-- window — no longer registered with Blizzard's Settings panel.
---------------------------------------------------------------------------

local O = BazCore._Options
local optionsTables = BazCore._optionsTables or {}
BazCore._optionsTables = optionsTables

local window            -- the standalone window (created on demand)
local activeAddon       -- name of the currently active bottom tab
local activeSubcategory -- name of the currently active left sidebar item
local bottomTabs = {}   -- [addonName] = tab frame
local sidebarRows = {}  -- [entryKey] = row frame

local WINDOW_WIDTH   = 1618
local WINDOW_HEIGHT  = 883
local TAB_HEIGHT     = 32
local SIDEBAR_WIDTH  = 200
local SIDEBAR_ROW_H  = 28
local HEADER_HEIGHT  = 52

---------------------------------------------------------------------------
-- Layout helpers
---------------------------------------------------------------------------

-- Returns a sorted array of addon entries that are top-level (no parent).
-- These get bottom tabs in the window.
local function GetTopLevelEntries()
    local entries = {}
    for name, entry in pairs(optionsTables) do
        if not entry.parent and entry.displayName then
            entries[#entries + 1] = { name = name, entry = entry }
        end
    end
    -- BazCore always first, User Manual always last, rest alphabetical
    table.sort(entries, function(a, b)
        if a.name == "BazCore" then return true end
        if b.name == "BazCore" then return false end
        if a.name == "UserManual" then return false end
        if b.name == "UserManual" then return true end
        return a.name < b.name
    end)
    return entries
end

-- Returns a sorted array of sub-category entries for a given parent.
-- Includes the parent itself as the first entry (landing page).
local function GetSubcategoriesFor(parentName)
    local parentEntry = optionsTables[parentName]
    local children = {}
    for name, entry in pairs(optionsTables) do
        if entry.parent == parentName and entry.displayName then
            children[#children + 1] = { key = name, label = entry.displayName }
        end
    end
    -- Sort order:
    --   1. "Settings" first       (the most common landing spot)
    --   2. Other sub-categories   (alphabetical)
    --   3. "User Guide"           (docs near the bottom)
    --   4. "Profiles" last        (least frequently used)
    table.sort(children, function(a, b)
        if a.label == "Settings" then return true end
        if b.label == "Settings" then return false end
        if a.label == "Profiles" then return false end
        if b.label == "Profiles" then return true end
        if a.label == "User Guide" then return false end
        if b.label == "User Guide" then return true end
        return a.label < b.label
    end)

    local list = {}
    -- Show the parent (landing) entry only when:
    --   * it has no children to navigate to, OR
    --   * the parent explicitly opts in via showRoot = true
    -- This means every addon defaults to "click tab -> land on first
    -- sub-category" with no separate landing page in the way.
    -- An explicit hideRoot still wins over showRoot.
    local includeParent = parentEntry
        and not parentEntry.hideRoot
        and (#children == 0 or parentEntry.showRoot)
    if includeParent then
        list[#list + 1] = {
            key = parentName,
            label = parentEntry.displayName or parentName,
            isRoot = true,
        }
    end
    for _, c in ipairs(children) do list[#list + 1] = c end
    return list
end

---------------------------------------------------------------------------
-- Content rendering (reused from list/detail pattern)
---------------------------------------------------------------------------

local function CreateTwoPanelLayout(container, optionsTable)
    local args = optionsTable.args or {}
    local contentWidth = container:GetWidth() or 600

    -- Split args into: topArgs, groupArgs, executeArgs
    local topArgs, groupArgs, executeArgs = {}, {}, {}
    local sortedRoot = O.SortedArgs(args)
    local hasTwoPanelGroups = false

    for _, opt in ipairs(sortedRoot) do
        if opt.type == "group" and opt.inline then
            topArgs[#topArgs + 1] = opt
        elseif opt.type == "group" and not opt.inline and opt.args then
            groupArgs[#groupArgs + 1] = opt
            hasTwoPanelGroups = true
        elseif opt.type == "execute" and not hasTwoPanelGroups then
            executeArgs[#executeArgs + 1] = opt
        else
            topArgs[#topArgs + 1] = opt
        end
    end

    local yOffset = -O.PAD
    local headerHeight = 44

    -- Header
    local titleFrame = CreateFrame("Frame", nil, container)
    titleFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)

    local titleXOffset = O.PAD
    local addonConfig = BazCore.addons and BazCore.addons[optionsTable.name]
    local iconTex = addonConfig and addonConfig.minimap and addonConfig.minimap.icon
    if not iconTex and C_AddOns and C_AddOns.GetAddOnMetadata then
        iconTex = C_AddOns.GetAddOnMetadata(optionsTable.name, "IconTexture")
    end
    if iconTex then
        local addonIcon = titleFrame:CreateTexture(nil, "ARTWORK")
        addonIcon:SetSize(32, 32)
        addonIcon:SetPoint("TOPLEFT", O.PAD, -6)
        addonIcon:SetTexture(iconTex)
        titleXOffset = O.PAD + 40
    end

    local titleText = titleFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOPLEFT", titleXOffset, -6)
    titleText:SetText(optionsTable.name or "")
    titleText:SetTextColor(unpack(O.GOLD))

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

    titleFrame:SetSize(contentWidth, headerHeight)
    yOffset = yOffset - headerHeight

    -- Top-level items
    local hasTopGroups = false
    for _, opt in ipairs(topArgs) do
        if opt.type == "group" and opt.inline then hasTopGroups = true; break end
    end

    if not hasTwoPanelGroups and not hasTopGroups then
        yOffset = O.RenderWidgets(container, args, contentWidth, nil, yOffset)
    else
        for _, opt in ipairs(topArgs) do
            if opt.type == "group" and opt.inline then
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

local function RenderIntoCanvas(container, optionsTable)
    local hasTwoPanelGroups = false
    if optionsTable.args then
        for _, opt in pairs(optionsTable.args) do
            if type(opt) == "table" and opt.type == "group" and not opt.inline and opt.args then
                hasTwoPanelGroups = true
                break
            end
        end
    end

    if container._scrollFrame then
        container._scrollFrame:Hide()
        container._scrollFrame:SetParent(nil)
        container._scrollFrame = nil
        container._renderTarget = nil
    end
    if container._renderTarget then
        O.ClearChildren(container._renderTarget)
    end

    if hasTwoPanelGroups then
        if not container._renderTarget then
            container._renderTarget = CreateFrame("Frame", nil, container)
            container._renderTarget:SetAllPoints()
        end
        local renderTarget = container._renderTarget

        local function Layout()
            O.ClearChildren(renderTarget)
            CreateTwoPanelLayout(renderTarget, optionsTable)
            renderTarget._lastRenderedWidth = renderTarget:GetWidth() or 0
        end

        Layout()

        -- Deferred retry: if the container width hadn't resolved when
        -- we first rendered, re-layout once the layout engine settles.
        C_Timer.After(0, function()
            if not renderTarget:GetParent() then return end
            local w = renderTarget:GetWidth() or 0
            if w > 0 and math.abs(w - (renderTarget._lastRenderedWidth or 0)) > 1 then
                Layout()
            end
        end)

        -- Long-term safety: any future resize re-flows the content
        renderTarget:SetScript("OnSizeChanged", function(self, w)
            if not w or w <= 0 then return end
            if math.abs(w - (renderTarget._lastRenderedWidth or 0)) > 1 then
                Layout()
            end
        end)
    else
        local scroll = CreateFrame("ScrollFrame", nil, container)
        scroll:SetPoint("TOPLEFT", 0, 0)
        scroll:SetPoint("BOTTOMRIGHT", -18, 0)
        scroll:EnableMouseWheel(true)
        container._scrollFrame = scroll

        local scrollBar = CreateFrame("EventFrame", nil, container, "MinimalScrollBar")
        scrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 4, 0)
        scrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 0)
        ScrollUtil.InitScrollFrameWithScrollBar(scroll, scrollBar)
        O.AutoHideScrollbar(scroll, scrollBar)

        local content = CreateFrame("Frame", nil, scroll)
        scroll:SetScrollChild(content)
        container._renderTarget = content

        local function Layout(width)
            if not width or width <= 0 then return end
            content:SetWidth(width)
            O.ClearChildren(content)
            CreateTwoPanelLayout(content, optionsTable)
            -- Track on the SCROLL (per-render fresh frame), not on the
            -- container (shared across renders). Avoids stale guard
            -- preventing legitimate re-layouts on next navigation.
            scroll._lastRenderedWidth = width
        end

        local function ResolveWidth()
            local w = scroll:GetWidth() or 0
            if w <= 0 then w = (container:GetWidth() or 0) - 18 end
            return w
        end

        -- First attempt at the current best-known width
        local initialW = ResolveWidth()
        if initialW > 0 then Layout(initialW) end

        -- Defensive: defer one frame so the layout system has had a
        -- chance to size everything. Re-layout if the resolved width
        -- now differs from what we initially used (or we hadn't laid
        -- out at all yet because width was 0).
        C_Timer.After(0, function()
            if not content:GetParent() then return end  -- destroyed
            local w = ResolveWidth()
            if w > 0 and (not scroll._lastRenderedWidth
                          or math.abs(w - scroll._lastRenderedWidth) > 1) then
                Layout(w)
            end
        end)

        -- Long-term: any future size change re-flows the content
        scroll:SetScript("OnSizeChanged", function(self, w)
            if not w or w <= 0 then return end
            content:SetWidth(w)
            if not scroll._lastRenderedWidth
               or math.abs(w - scroll._lastRenderedWidth) > 1 then
                Layout(w)
            end
        end)
    end
end

BazCore._RenderIntoCanvas = RenderIntoCanvas

---------------------------------------------------------------------------
-- Window construction
---------------------------------------------------------------------------

local function SelectSubcategory(key)
    activeSubcategory = key
    if not window then return end

    -- Update sidebar highlights
    for entryKey, row in pairs(sidebarRows) do
        if entryKey == key then
            row.bg:SetColorTexture(unpack(O.LIST_SELECTED))
            row.text:SetTextColor(unpack(O.GOLD))
            row.text:SetAlpha(1.0)
        else
            row.bg:SetColorTexture(0, 0, 0, 0)
            row.text:SetTextColor(unpack(O.GOLD))
            row.text:SetAlpha(0.7)
        end
    end

    -- Render the selected entry into content area
    local entry = optionsTables[key]
    if not entry then return end
    O.ClearChildren(window.content)

    -- A customRender function takes full control of the content panel.
    -- Used by the User Manual to render its own tree-based layout.
    if type(entry.customRender) == "function" then
        entry.customRender(window.content)
        return
    end

    local tbl = entry.func
    if type(tbl) == "function" then tbl = tbl() end
    if tbl then
        RenderIntoCanvas(window.content, tbl)
    end
end

local function RenderSidebar()
    if not window then return end
    O.ClearChildren(window.sidebar)
    sidebarRows = {}

    local subs = GetSubcategoriesFor(activeAddon)
    local y = -8
    for _, sub in ipairs(subs) do
        local row = CreateFrame("Button", nil, window.sidebar)
        row:SetSize(SIDEBAR_WIDTH - 8, SIDEBAR_ROW_H)
        row:SetPoint("TOPLEFT", 4, y)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0)
        row.bg = bg

        local text = row:CreateFontString(nil, "OVERLAY", O.LIST_FONT)
        text:SetPoint("LEFT", 10, 0)
        text:SetText(sub.label)
        text:SetTextColor(unpack(O.GOLD))
        text:SetAlpha(0.7)
        row.text = text

        local capturedKey = sub.key
        row:SetScript("OnClick", function() SelectSubcategory(capturedKey) end)
        row:SetScript("OnEnter", function(self)
            if activeSubcategory ~= capturedKey then
                self.bg:SetColorTexture(unpack(O.LIST_HOVER))
                self.text:SetAlpha(1.0)
            end
        end)
        row:SetScript("OnLeave", function(self)
            if activeSubcategory ~= capturedKey then
                self.bg:SetColorTexture(0, 0, 0, 0)
                self.text:SetAlpha(0.7)
            end
        end)

        sidebarRows[sub.key] = row
        y = y - SIDEBAR_ROW_H
    end

    -- Default to the root (landing page) entry
    local firstKey = subs[1] and subs[1].key or activeAddon
    SelectSubcategory(firstKey)
end

local function SelectAddon(name)
    activeAddon = name
    if not window then return end

    -- Update bottom tab visuals
    for tabName, tab in pairs(bottomTabs) do
        if tabName == name then
            PanelTemplates_SelectTab(tab)
        else
            PanelTemplates_DeselectTab(tab)
        end
    end

    RenderSidebar()
end

local function RenderBottomTabs()
    if not window then return end
    -- Hide all existing tabs
    for _, tab in pairs(bottomTabs) do
        tab:Hide()
    end
    bottomTabs = {}

    local entries = GetTopLevelEntries()
    local x = 12
    for i, item in ipairs(entries) do
        local tab = CreateFrame("Button", "BazCoreOptionsTab" .. i, window, "PanelTabButtonTemplate")
        tab:SetID(i)
        tab:SetText(item.entry.displayName or item.name)
        tab:SetPoint("TOPLEFT", window, "BOTTOMLEFT", x, 2)
        PanelTemplates_TabResize(tab, 0)

        local capturedName = item.name
        tab:SetScript("OnClick", function(self)
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            SelectAddon(capturedName)
        end)

        bottomTabs[item.name] = tab
        x = x + tab:GetWidth() + 3  -- small gap between tabs
    end
end

local function EnsureWindow()
    if window then return window end

    -- PortraitFrameTemplate = same chrome as PlayerSpellsFrame (Talents/Spec window)
    local f = CreateFrame("Frame", "BazCoreOptionsWindow", UIParent, "PortraitFrameTemplate")
    f:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:SetToplevel(true)
    f:Hide()

    -- Set custom portrait icon (BazCore logo)
    -- The portrait lives at f.PortraitContainer.portrait (named via $parentPortrait)
    local portrait = (f.PortraitContainer and f.PortraitContainer.portrait) or f.portrait
    if portrait then
        portrait:SetTexture("Interface\\AddOns\\BazCore\\Media\\IconRound.png")
    end

    -- Set the title (PortraitFrameTemplate provides SetTitle helper)
    if f.SetTitle then f:SetTitle("BazCore Options") end

    -- Overlay the spec-background atlas on top of the default rocky Bg
    -- to match the Specialization window's darker look
    local specBg = f:CreateTexture(nil, "BACKGROUND", nil, -3)
    specBg:SetAtlas("spec-background")
    specBg:SetPoint("TOPLEFT", 4, -22)
    specBg:SetPoint("BOTTOMRIGHT", -4, 4)

    -- Content area: fills the main body of the window, leaving space
    -- below for the bottom tab strip
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", 10, -64)
    content:SetPoint("BOTTOMRIGHT", -10, 12)
    f.contentWrapper = content

    -- Sidebar (left side of content) — subtle border only so the
    -- PortraitFrameTemplate rocky background shows through
    local sidebar = CreateFrame("Frame", nil, content, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", 0, 0)
    sidebar:SetPoint("BOTTOMLEFT", 0, 0)
    sidebar:SetWidth(SIDEBAR_WIDTH)
    sidebar:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
    })
    sidebar:SetBackdropBorderColor(unpack(O.PANEL_BORDER))
    f.sidebar = sidebar

    -- Vertical divider line between sidebar and content (gold accent)
    local divider = content:CreateTexture(nil, "OVERLAY")
    divider:SetWidth(1)
    divider:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 5, 0)
    divider:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMRIGHT", 5, 0)
    divider:SetColorTexture(0.35, 0.3, 0.18, 0.6)

    -- Content panel (right of sidebar) — also transparent
    local contentPanel = CreateFrame("Frame", nil, content)
    contentPanel:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 12, 0)
    contentPanel:SetPoint("BOTTOMRIGHT", 0, 0)
    f.content = contentPanel

    -- Bottom tab container (hangs below the window, like PlayerSpellsFrame)
    local tabContainer = CreateFrame("Frame", nil, f)
    tabContainer:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, 0)
    tabContainer:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, 0)
    tabContainer:SetHeight(TAB_HEIGHT)
    f.tabContainer = tabContainer

    tinsert(UISpecialFrames, "BazCoreOptionsWindow")

    window = f
    return f
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function BazCore:RegisterOptionsTable(addonName, optionsTableOrFunc)
    optionsTables[addonName] = optionsTables[addonName] or {}
    optionsTables[addonName].func = optionsTableOrFunc
end

-- Build a stub canvas for Blizzard's Settings panel. Shows the addon
-- title, version, and a big "Open Options" button that launches our
-- standalone window with the correct tab active.
local function CreateBlizzardStub(addonName, displayName)
    local canvas = CreateFrame("Frame")

    local title = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
    title:SetPoint("CENTER", 0, 80)
    title:SetText(displayName or addonName)
    title:SetTextColor(1, 0.82, 0)

    -- Version
    local version
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        version = C_AddOns.GetAddOnMetadata(addonName, "Version")
    end
    if version then
        local vtext = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        vtext:SetPoint("CENTER", 0, 40)
        vtext:SetText("Version: " .. version)
        vtext:SetTextColor(0.7, 0.7, 0.7)
    end

    local desc = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    desc:SetPoint("CENTER", 0, 0)
    desc:SetText("BazCore options have moved to their own window.")
    desc:SetTextColor(0.9, 0.9, 0.9)

    local btn = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
    btn:SetSize(220, 36)
    btn:SetPoint("CENTER", 0, -50)
    btn:SetText("Open Options")
    local fs = btn:GetFontString()
    if fs then fs:SetFontObject("GameFontNormalLarge") end
    btn:SetScript("OnClick", function()
        -- Defer to next frame to escape Blizzard's secure code path,
        -- then hide their panel and open ours. SettingsPanel:Close() is
        -- a secure call that taints if invoked from inside an addon click.
        C_Timer.After(0, function()
            if SettingsPanel and SettingsPanel:IsShown() then
                SettingsPanel:Hide()
            end
            BazCore:OpenOptionsPanel(addonName)
        end)
    end)

    return canvas
end

-- AddToSettings: register an addon or sub-category with the BazCore options window.
--   addonName   = unique key (used with RegisterOptionsTable)
--   displayName = label shown on the tab / sidebar
--   parentName  = optional; if given, this is a sub-category of that parent addon
function BazCore:AddToSettings(addonName, displayName, parentName)
    local entry = optionsTables[addonName]
    if not entry then return end
    entry.displayName = displayName or addonName
    entry.parent = parentName

    -- Only BazCore registers with Blizzard's Settings panel as a stub.
    -- Other Baz addons are accessed via the BazCore options window's
    -- bottom tabs — no need to clutter Blizzard's AddOn list with all of them.
    if addonName == "BazCore" and not parentName and not entry.blizzardCategory
        and Settings and Settings.RegisterCanvasLayoutCategory then
        local stub = CreateBlizzardStub(addonName, entry.displayName)
        local category = Settings.RegisterCanvasLayoutCategory(stub, entry.displayName)
        Settings.RegisterAddOnCategory(category)
        entry.blizzardCategory = category
        entry.blizzardCanvas = stub
    end

    -- If the window already exists, refresh tabs/sidebar so this entry shows up
    if window and window:IsShown() then
        RenderBottomTabs()
        if activeAddon and not parentName and addonName == activeAddon then
            RenderSidebar()
        elseif activeAddon == parentName then
            RenderSidebar()
        end
    end
end

function BazCore:OpenOptionsPanel(addonName)
    EnsureWindow()
    RenderBottomTabs()

    -- Figure out which top-level addon to activate.
    -- If addonName is a sub-category, switch to its parent first, then select the sub-category.
    local entry = optionsTables[addonName]
    local topLevel = addonName
    local subcategory = nil
    if entry and entry.parent then
        topLevel = entry.parent
        subcategory = addonName
    end

    -- If the requested addon isn't registered, fall back to the first top-level
    if not optionsTables[topLevel] or not optionsTables[topLevel].displayName then
        local entries = GetTopLevelEntries()
        if #entries > 0 then
            topLevel = entries[1].name
        end
    end

    SelectAddon(topLevel)
    if subcategory then
        SelectSubcategory(subcategory)
    end

    window:Show()
    window:Raise()
end

function BazCore:RefreshOptions(addonName)
    if not window or not window:IsShown() then return end
    -- Only re-render if the refreshed addon/sub-category is currently showing
    if activeSubcategory == addonName then
        local entry = optionsTables[addonName]
        if not entry then return end
        O.ClearChildren(window.content)
        if type(entry.customRender) == "function" then
            entry.customRender(window.content)
            return
        end
        local tbl = entry.func
        if type(tbl) == "function" then tbl = tbl() end
        if tbl then
            RenderIntoCanvas(window.content, tbl)
        end
    end
end
