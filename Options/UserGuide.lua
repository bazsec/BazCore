---------------------------------------------------------------------------
-- BazCore Options: User Manual
--
-- Hosts the User Manual bottom tab. Any BazCore-compatible addon can
-- register its user guide via BazCore:RegisterUserGuide(addonName, guide).
-- Each registered guide becomes a sub-category in the User Manual tab.
--
-- Guide format:
--   {
--       title = "BazCore",                 -- optional; defaults to addonName
--       intro = "Lead paragraph.",         -- optional; shown above page list
--       pages = {                           -- optional tree of pages
--           {
--               title = "Overview",
--               text  = "Page body...",     -- supports \n\n paragraph breaks
--               children = {                -- optional sub-pages (one level)
--                   { title = "Sub Topic", text = "..." },
--               },
--           },
--           ...
--       },
--       -- Backward-compat: a flat sections list still works
--       sections = {
--           { heading = "...", text = "..." },
--       },
--   }
--
-- Text supports WoW escape codes (|cffxxxxxx...|r for colors). Use
-- \n for line breaks, \n\n for paragraph breaks.
---------------------------------------------------------------------------

local O = BazCore._Options

local guides = {}      -- [addonName] = guide table
local guideState = {}  -- [addonName] = { expanded = {[key]=true}, selectedKey = "1" }

local TREE_ROW_H   = 26
local PAGE_LIST_PCT = 0.28   -- inner list width as % of content panel
local PAGE_LIST_MIN = 200
local PAGE_LIST_MAX = 320
local PAGE_LIST_GAP = 14

---------------------------------------------------------------------------
-- Tree helpers
---------------------------------------------------------------------------

-- Walk pages tree, producing a flat list of nodes that should be visible
-- given the current expansion state.
-- Each node: { page, key, depth, hasChildren }
local function FlattenVisibleNodes(pages, expanded, depth, parentKey, out)
    out = out or {}
    for i, page in ipairs(pages or {}) do
        local key = parentKey and (parentKey .. "/" .. i) or tostring(i)
        local hasChildren = page.children and #page.children > 0
        out[#out + 1] = { page = page, key = key, depth = depth, hasChildren = hasChildren }
        if hasChildren and expanded[key] then
            FlattenVisibleNodes(page.children, expanded, depth + 1, key, out)
        end
    end
    return out
end

-- Find the first leaf page (used for default selection)
local function FindFirstPageKey(pages, parentKey)
    if not pages or #pages == 0 then return nil end
    return parentKey and (parentKey .. "/1") or "1"
end

-- Look up a page node by its key path (e.g. "1/2")
local function FindPageByKey(pages, key)
    if not pages or not key then return nil end
    local cur = pages
    local node
    for part in string.gmatch(key, "[^/]+") do
        local idx = tonumber(part)
        if not idx or not cur or not cur[idx] then return nil end
        node = cur[idx]
        cur = node.children
    end
    return node
end

---------------------------------------------------------------------------
-- Title bar (mirrors CreateTwoPanelLayout's header)
---------------------------------------------------------------------------

local function BuildTitleBar(parent, addonName, guide, contentWidth)
    local frame = CreateFrame("Frame", nil, parent)
    local headerHeight = 44
    local titleXOffset = O.PAD

    local addonConfig = BazCore.addons and BazCore.addons[addonName]
    local iconTex = addonConfig and addonConfig.minimap and addonConfig.minimap.icon
    if not iconTex and C_AddOns and C_AddOns.GetAddOnMetadata then
        iconTex = C_AddOns.GetAddOnMetadata(addonName, "IconTexture")
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
    titleText:SetText(guide.title or addonName)
    titleText:SetTextColor(unpack(O.GOLD))

    local addonVersion = addonConfig and addonConfig.version
    if not addonVersion and C_AddOns and C_AddOns.GetAddOnMetadata then
        addonVersion = C_AddOns.GetAddOnMetadata(addonName, "Version")
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

    frame:SetSize(contentWidth, headerHeight)
    return frame, headerHeight
end

---------------------------------------------------------------------------
-- Render the page-content panel (right side)
---------------------------------------------------------------------------

-- Convert a page (from the user guide schema) into a normalized list of
-- content blocks. Supports both the new `blocks` field AND the legacy
-- `text`/`sections` fields so existing guides keep working.
local function PageToBlocks(page)
    if not page then return {} end
    if page.blocks then return page.blocks end

    local blocks = {}
    if page.text and page.text ~= "" then
        blocks[#blocks + 1] = { type = "paragraph", text = page.text }
    end
    if page.sections then
        for _, section in ipairs(page.sections) do
            if section.heading and section.heading ~= "" then
                blocks[#blocks + 1] = { type = "h3", text = section.heading }
            end
            if section.text and section.text ~= "" then
                blocks[#blocks + 1] = { type = "paragraph", text = section.text }
            end
        end
    end
    return blocks
end

local function RenderPageContent(parent, page, contentWidth)
    O.ClearChildren(parent)
    if not page then return end

    -- Page title (h1) at top, then the page's blocks
    local headerBlocks = {}
    if page.title and page.title ~= "" then
        headerBlocks[#headerBlocks + 1] = { type = "h1", text = page.title }
    end

    local allBlocks = {}
    for _, b in ipairs(headerBlocks) do allBlocks[#allBlocks + 1] = b end
    for _, b in ipairs(PageToBlocks(page)) do allBlocks[#allBlocks + 1] = b end

    -- Render each block, but keep a list so we can re-flow Y offsets
    -- whenever a collapsible expands/collapses. Without this, blocks
    -- below a collapsible are anchored at fixed Y values measured at
    -- render time, so an opened collapsible overlaps its siblings and
    -- the parent height stays too short for the scroll frame.
    local items = {}
    local innerWidth = contentWidth - O.PAD * 2
    for _, block in ipairs(allBlocks) do
        local factory = O.widgetFactories[block.type]
        if factory then
            local widget, h = factory(parent, block, innerWidth)
            widget:Show()
            items[#items + 1] = { widget = widget, height = h }
        end
    end

    local function Reflow()
        local y = -O.PAD
        for _, item in ipairs(items) do
            item.widget:ClearAllPoints()
            item.widget:SetPoint("TOPLEFT", parent, "TOPLEFT", O.PAD, y)
            -- Read the widget's CURRENT height (collapsibles change
            -- theirs as they animate; everything else stays static).
            local h = item.widget:GetHeight() or item.height
            y = y - h - O.SPACING
        end
        parent:SetHeight(math.abs(y) + O.PAD)
    end

    -- Hook each block's _onHeightChanged so any collapsible that grows
    -- or shrinks triggers a full re-flow. Non-collapsible blocks never
    -- fire the hook — assigning the field is harmless.
    for _, item in ipairs(items) do
        item.widget._onHeightChanged = Reflow
    end

    Reflow()
end

---------------------------------------------------------------------------
-- Tree list rebuild
---------------------------------------------------------------------------

local function RebuildTree(listContent, addonName, guide, listW, onSelect)
    O.ClearChildren(listContent)
    local state = guideState[addonName]
    local nodes = FlattenVisibleNodes(guide.pages, state.expanded, 0)

    local rowWidth = listW - 26
    local halfW = math.floor(rowWidth / 2)

    -- Helper: build the Blizzard-style gold-gradient selection highlight.
    -- Two horizontal halves fade-in/out to the center, plus two thin gold
    -- lines top and bottom that also fade at the edges. Returns a list of
    -- textures so the caller can show/hide them as a group.
    local function BuildSelectionHighlight(row)
        local bandL = row:CreateTexture(nil, "BACKGROUND")
        bandL:SetColorTexture(1, 1, 1, 1)
        bandL:SetSize(halfW, TREE_ROW_H)
        bandL:SetPoint("LEFT", 0, 0)
        bandL:SetGradient("HORIZONTAL",
            CreateColor(1, 0.82, 0, 0),
            CreateColor(1, 0.82, 0, 0.45))

        local bandR = row:CreateTexture(nil, "BACKGROUND")
        bandR:SetColorTexture(1, 1, 1, 1)
        bandR:SetSize(halfW, TREE_ROW_H)
        bandR:SetPoint("RIGHT", 0, 0)
        bandR:SetGradient("HORIZONTAL",
            CreateColor(1, 0.82, 0, 0.45),
            CreateColor(1, 0.82, 0, 0))

        local topL = row:CreateTexture(nil, "OVERLAY")
        topL:SetColorTexture(1, 1, 1, 1)
        topL:SetSize(halfW, 1)
        topL:SetPoint("TOPLEFT")
        topL:SetGradient("HORIZONTAL",
            CreateColor(1, 0.82, 0, 0),
            CreateColor(1, 0.82, 0, 0.85))

        local topR = row:CreateTexture(nil, "OVERLAY")
        topR:SetColorTexture(1, 1, 1, 1)
        topR:SetSize(halfW, 1)
        topR:SetPoint("TOPRIGHT")
        topR:SetGradient("HORIZONTAL",
            CreateColor(1, 0.82, 0, 0.85),
            CreateColor(1, 0.82, 0, 0))

        local botL = row:CreateTexture(nil, "OVERLAY")
        botL:SetColorTexture(1, 1, 1, 1)
        botL:SetSize(halfW, 1)
        botL:SetPoint("BOTTOMLEFT")
        botL:SetGradient("HORIZONTAL",
            CreateColor(1, 0.82, 0, 0),
            CreateColor(1, 0.82, 0, 0.85))

        local botR = row:CreateTexture(nil, "OVERLAY")
        botR:SetColorTexture(1, 1, 1, 1)
        botR:SetSize(halfW, 1)
        botR:SetPoint("BOTTOMRIGHT")
        botR:SetGradient("HORIZONTAL",
            CreateColor(1, 0.82, 0, 0.85),
            CreateColor(1, 0.82, 0, 0))

        return { bandL, bandR, topL, topR, botL, botR }
    end

    local function ShowGroup(group, show)
        for _, t in ipairs(group) do
            if show then t:Show() else t:Hide() end
        end
    end

    local y = 0
    for _, node in ipairs(nodes) do
        local row = CreateFrame("Button", nil, listContent)
        row:SetSize(rowWidth, TREE_ROW_H)
        row:SetPoint("TOPLEFT", 0, -y)
        row:RegisterForClicks("LeftButtonUp")

        local isSelected = (node.key == state.selectedKey)

        -- Subtle hover background (only when not selected)
        local hover = row:CreateTexture(nil, "BACKGROUND")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.05)
        hover:Hide()
        row.hover = hover

        -- Gold-gradient selection highlight (Blizzard-style)
        local hlGroup = BuildSelectionHighlight(row)
        ShowGroup(hlGroup, isSelected)
        row.hlGroup = hlGroup

        local indent = 8 + node.depth * 16

        local arrow
        if node.hasChildren then
            -- Classic Blizzard plus/minus button textures
            arrow = row:CreateTexture(nil, "OVERLAY")
            arrow:SetSize(14, 14)
            arrow:SetPoint("LEFT", indent - 2, 0)
            if state.expanded[node.key] then
                arrow:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")
            else
                arrow:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
            end
            indent = indent + 16
        end

        local text = row:CreateFontString(nil, "OVERLAY", O.LIST_FONT)
        text:SetPoint("LEFT", indent, 0)
        text:SetPoint("RIGHT", -4, 0)
        text:SetJustifyH("LEFT")
        text:SetText(node.page.title or "")
        if isSelected then
            text:SetTextColor(1, 1, 1)         -- white when selected
            text:SetAlpha(1.0)
        else
            text:SetTextColor(unpack(O.GOLD))  -- gold otherwise
            text:SetAlpha(0.75)
        end
        row.text = text

        local capturedKey = node.key
        local capturedHasChildren = node.hasChildren
        local capturedPage = node.page

        row:SetScript("OnClick", function()
            if capturedHasChildren then
                state.expanded[capturedKey] = not state.expanded[capturedKey]
            end
            state.selectedKey = capturedKey
            onSelect(capturedPage)
            RebuildTree(listContent, addonName, guide, listW, onSelect)
        end)

        row:SetScript("OnEnter", function(self)
            if capturedKey ~= state.selectedKey then
                self.hover:Show()
                self.text:SetAlpha(1.0)
            end
        end)
        row:SetScript("OnLeave", function(self)
            if capturedKey ~= state.selectedKey then
                self.hover:Hide()
                self.text:SetAlpha(0.75)
            end
        end)

        y = y + TREE_ROW_H
    end

    listContent:SetHeight(math.max(y, 1))
end

---------------------------------------------------------------------------
-- Convert legacy `sections` to `pages` so everything goes through one
-- code path. Each section becomes a top-level page.
---------------------------------------------------------------------------

local function NormalizeGuide(guide)
    if guide.pages and #guide.pages > 0 then return guide end
    if guide.sections and #guide.sections > 0 then
        local pages = {}
        for _, section in ipairs(guide.sections) do
            pages[#pages + 1] = {
                title = section.heading,
                text  = section.text,
            }
        end
        -- Don't mutate caller's table — clone the relevant fields
        return {
            title    = guide.title,
            intro    = guide.intro,
            pages    = pages,
            sections = guide.sections,  -- preserved for reference
        }
    end
    return guide
end

---------------------------------------------------------------------------
-- Custom renderer: title bar + tree list (left) + content panel (right)
---------------------------------------------------------------------------

local function RenderGuide(container, addonName)
    local rawGuide = guides[addonName]
    if not rawGuide then return end
    local guide = NormalizeGuide(rawGuide)

    guideState[addonName] = guideState[addonName] or { expanded = {}, selectedKey = nil }
    local state = guideState[addonName]

    -- Default selection: first top-level page
    if not state.selectedKey then
        state.selectedKey = FindFirstPageKey(guide.pages)
    end

    local containerW = container:GetWidth() or 800

    -- Title bar at top
    local titleBar, titleH = BuildTitleBar(container, addonName, guide, containerW)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)

    -- Optional intro paragraph below title bar
    local introH = 0
    local introOffset = -titleH
    if guide.intro and guide.intro ~= "" then
        local intro = container:CreateFontString(nil, "OVERLAY")
        intro:SetFontObject(O.DESC_FONT)
        intro:SetPoint("TOPLEFT", O.PAD, introOffset - 4)
        intro:SetWidth(containerW - O.PAD * 2)
        intro:SetJustifyH("LEFT")
        intro:SetText(guide.intro)
        intro:SetTextColor(unpack(O.TEXT_DESC))
        intro:SetWordWrap(true)
        introH = intro:GetStringHeight() + 10
    end

    local belowHeaderY = -titleH - introH

    -- Split frame for list (left) + detail (right)
    local splitFrame = CreateFrame("Frame", nil, container)
    splitFrame:SetPoint("TOPLEFT", 0, belowHeaderY)
    splitFrame:SetPoint("BOTTOMRIGHT", 0, 0)

    -- Compute list width
    local listW = math.floor(containerW * PAGE_LIST_PCT)
    if listW < PAGE_LIST_MIN then listW = PAGE_LIST_MIN end
    if listW > PAGE_LIST_MAX then listW = PAGE_LIST_MAX end

    -- Left list backdrop
    local listBg = CreateFrame("Frame", nil, splitFrame, "BackdropTemplate")
    listBg:SetPoint("TOPLEFT", 0, 0)
    listBg:SetPoint("BOTTOMLEFT", 0, 0)
    listBg:SetWidth(listW)
    listBg:SetBackdrop(O.LIST_BACKDROP)
    listBg:SetBackdropColor(unpack(O.LIST_BG))
    listBg:SetBackdropBorderColor(unpack(O.PANEL_BORDER))

    -- List scroll
    local listScroll = CreateFrame("ScrollFrame", nil, listBg)
    listScroll:SetPoint("TOPLEFT", 4, -6)
    listScroll:SetPoint("BOTTOMRIGHT", -14, 4)
    listScroll:EnableMouseWheel(true)

    local listScrollBar = CreateFrame("EventFrame", nil, listBg, "MinimalScrollBar")
    listScrollBar:SetPoint("TOPLEFT", listScroll, "TOPRIGHT", 2, 0)
    listScrollBar:SetPoint("BOTTOMLEFT", listScroll, "BOTTOMRIGHT", 2, 0)
    ScrollUtil.InitScrollFrameWithScrollBar(listScroll, listScrollBar)
    O.AutoHideScrollbar(listScroll, listScrollBar)

    local listContent = CreateFrame("Frame", nil, listScroll)
    listContent:SetWidth(listW - 26)
    listScroll:SetScrollChild(listContent)

    -- Right detail panel
    local detailFrame = CreateFrame("Frame", nil, splitFrame, "BackdropTemplate")
    detailFrame:SetPoint("TOPLEFT", listBg, "TOPRIGHT", PAGE_LIST_GAP, 0)
    detailFrame:SetPoint("BOTTOMRIGHT", 0, 0)
    detailFrame:SetBackdrop(O.LIST_BACKDROP)
    detailFrame:SetBackdropColor(unpack(O.PANEL_BG))
    detailFrame:SetBackdropBorderColor(unpack(O.PANEL_BORDER))

    local detailScroll = CreateFrame("ScrollFrame", nil, detailFrame)
    detailScroll:SetPoint("TOPLEFT", 4, -4)
    detailScroll:SetPoint("BOTTOMRIGHT", -14, 4)
    detailScroll:EnableMouseWheel(true)

    local detailScrollBar = CreateFrame("EventFrame", nil, detailFrame, "MinimalScrollBar")
    detailScrollBar:SetPoint("TOPLEFT", detailScroll, "TOPRIGHT", 2, 0)
    detailScrollBar:SetPoint("BOTTOMLEFT", detailScroll, "BOTTOMRIGHT", 2, 0)
    ScrollUtil.InitScrollFrameWithScrollBar(detailScroll, detailScrollBar)
    O.AutoHideScrollbar(detailScroll, detailScrollBar)

    local detailContent = CreateFrame("Frame", nil, detailScroll)
    detailContent:SetWidth(detailFrame:GetWidth() - 28)
    detailScroll:SetScrollChild(detailContent)

    local function Select(page)
        local dw = detailContent:GetWidth() - O.PAD
        if dw <= 0 then dw = 360 end
        RenderPageContent(detailContent, page, dw)
    end

    -- Initial tree render
    RebuildTree(listContent, addonName, guide, listW, Select)

    -- Initial content render (deferred so widths settle)
    C_Timer.After(0, function()
        if not detailContent then return end
        detailContent:SetWidth(detailFrame:GetWidth() - 28)
        local page = FindPageByKey(guide.pages, state.selectedKey)
        Select(page)
    end)

    detailFrame:SetScript("OnSizeChanged", function(self, w)
        detailContent:SetWidth(w - 28)
        local page = FindPageByKey(guide.pages, state.selectedKey)
        Select(page)
    end)
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

-- RegisterUserGuide: each addon's guide becomes a "User Guide" sub-category
-- under that addon's own bottom tab. No separate User Manual tab — docs
-- live next to the settings they describe.
function BazCore:RegisterUserGuide(addonName, guide)
    if type(addonName) ~= "string" or addonName == "" then return end
    if type(guide) ~= "table" then return end

    guides[addonName] = guide
    -- Reset view state so a re-registration doesn't strand a stale selection
    guideState[addonName] = { expanded = {}, selectedKey = nil }

    -- Register the guide as a sub-category of the addon itself
    local key = "UserGuide_" .. addonName
    local entry = BazCore._optionsTables[key] or {}
    entry.func = function() return { name = addonName, args = {} } end  -- placeholder
    entry.customRender = function(container)
        RenderGuide(container, addonName)
    end
    BazCore._optionsTables[key] = entry
    BazCore:AddToSettings(key, "User Manual", addonName)

    if BazCore.RefreshOptions then
        BazCore:RefreshOptions(key)
    end
end

BazCore._userGuides = guides

---------------------------------------------------------------------------
-- BazCore's own built-in user guide
---------------------------------------------------------------------------

BazCore:RegisterUserGuide("BazCore", {
    title = "BazCore",
    intro = "BazCore is the shared framework that powers the Baz Suite of World of Warcraft addons. Pick a topic on the left to read about it.",
    pages = {
        {
            title = "Welcome",
            blocks = {
                { type = "lead", text = "BazCore is a framework — it has no visible features on its own. Its job is to host the rest of the Baz Suite addons and provide them with a unified options window, profile system, minimap button, and shared APIs." },
                { type = "note", style = "info", text = "Everything in this manual is registered by an addon when it loads. What you see depends on which Baz addons you have installed." },
                { type = "h2", text = "What you'll find here" },
                { type = "list", items = {
                    "A bottom tab for every Baz addon you have installed",
                    "Per-addon documentation in this User Manual tab",
                    "A unified Profiles system you can configure per-character",
                    "Edit Mode integration for any addon that places frames on screen",
                }},
                { type = "h2", text = "Open commands" },
                { type = "table",
                  columns = { "Command", "Effect" },
                  rows = {
                      { "/bazcore",       "Open this window to BazCore" },
                      { "/bazbars",       "Open with BazBars active" },
                      { "/bwd",           "Open with BazWidgetDrawers active" },
                      { "/bnc",           "Open with BazNotificationCenter active" },
                  },
                },
            },
        },
        {
            title = "The Baz Suite",
            text = "Each Baz addon plugs into this window as a bottom tab. Only BazCore itself appears in Blizzard's AddOn Settings list — its \"Open Options\" button jumps here.",
            children = {
                { title = "BazBars",              text = "Custom extra action bars with full Edit Mode support." },
                { title = "BazWidgetDrawers",     text = "A slide-out drawer that hosts dockable widgets along the side of your screen." },
                { title = "BazWidgets",           text = "A pack of 13 ready-made widgets for BazWidgetDrawers — gold tracker, coordinates, stats, currencies, calculator, to-do list, and more." },
                { title = "BazNotificationCenter", text = "A toast notification system that surfaces important game events as polished popups." },
                { title = "BazLootNotifier",      text = "Animated loot popups that fly across your screen as you pick items up." },
                { title = "BazFlightZoom",        text = "Auto-zooms your camera while you're on a flying mount, then restores it when you land." },
                { title = "BazMap",               text = "A resizable map and quest log window with independent layouts for each game mode." },
                { title = "BazMapPortals",        text = "Mage portal and teleport map pins that show every spell's destination." },
            },
        },
        {
            title = "Opening the Options Window",
            text = "There are several ways to open this window:",
            children = {
                { title = "Minimap Button",  text = "Left-click toggles the default addon. Right-click opens a menu listing every Baz addon — pick one to jump to its tab." },
                { title = "Addon Compartment", text = "The Baz icon in Blizzard's compartment dropdown behaves the same way as the minimap button." },
                { title = "Slash Commands",  text = "|cff00ff00/bazcore|r opens this window directly to BazCore. Each addon also has its own slash command (|cff00ff00/bazbars|r, |cff00ff00/bwd|r, |cff00ff00/bnc|r, etc.) that opens with that addon's tab active." },
            },
        },
        {
            title = "Profiles",
            text = "Every Baz addon supports per-character profiles. You can use the default profile, share settings across characters, or give each character its own configuration.\n\nOpen any addon's |cffffd700Profiles|r sub-category to:\n  • Create a new profile\n  • Switch the active profile for this character\n  • Copy settings from another profile\n  • Reset or delete a profile\n\nProfiles are stored per-addon — switching your BazBars profile doesn't affect your BazWidgetDrawers profile.",
        },
        {
            title = "Global Options",
            text = "Addons with many modules or widgets expose a |cffffd700Global Options|r sub-category. These are overrides that apply to every module at once.\n\nFor example, BazWidgets has per-widget settings for fade alpha, title visibility, and font size. If you enable a global override for \"Title Bar\", every widget hides its title — regardless of its individual setting. Disable the override to return each widget to its own setting.\n\nThis is the fastest way to apply a consistent look across many widgets or bars without editing each one.",
        },
        {
            title = "Edit Mode Integration",
            text = "Baz addons that place frames on-screen (BazBars, BazWidgetDrawers, BazMap) integrate with Blizzard's |cffffd700Edit Mode|r:\n\n  • Frames appear as movable elements when you open Edit Mode\n  • Positions are saved to your active Edit Mode layout\n  • Switching Edit Mode layouts switches frame positions\n  • Anchors and offsets remain editable inside each addon's options for fine-grained control",
        },
        {
            title = "For Addon Authors",
            blocks = {
                { type = "lead", text = "BazCore is a documented public framework. Any addon can depend on it and use its APIs." },
                { type = "h3", text = "Plugging into the Options window" },
                { type = "code", text = "BazCore:RegisterOptionsTable(\"MyAddon\", optionsTable)\nBazCore:AddToSettings(\"MyAddon\", \"My Addon\")" },
                { type = "paragraph", text = "Your addon appears as a bottom tab. Sub-categories register the same way with a parent name passed as the third argument." },
                { type = "h3", text = "User Manual page (this very page!)" },
                { type = "code", text = "BazCore:RegisterUserGuide(\"MyAddon\", {\n    title = \"My Addon\",\n    intro = \"One-line summary.\",\n    pages = {\n        { title = \"Welcome\", blocks = { ... } },\n    },\n})" },
                { type = "h3", text = "Block types you can use in pages" },
                { type = "list", items = {
                    "h1 / h2 / h3 / h4 — heading hierarchy",
                    "paragraph / lead / caption / quote — text styles",
                    "list — bulleted or numbered, supports nesting",
                    "image — texture, atlas, or fileID with caption",
                    "note — tip / info / warning / danger callouts",
                    "code — monospace block for slash commands and macros",
                    "table — header row + data rows",
                    "collapsible — animated expand/collapse with persistent state",
                    "divider / spacer — layout helpers",
                }},
                { type = "collapsible", title = "Try a collapsible", style = "h3", blocks = {
                    { type = "paragraph", text = "Collapsibles persist their state across sessions automatically — give them a |cffffd700key|r to control where the state is stored, or rely on the auto-derived key based on the title." },
                    { type = "note", style = "tip", text = "Collapsibles can contain other collapsibles. Nest as deep as you want." },
                }},
                { type = "h3", text = "Other APIs" },
                { type = "list", items = {
                    "RegisterDockableWidget — host a widget inside BazWidgetDrawers",
                    "Profiles — per-character settings wiring",
                    "MinimapButton — share the Baz minimap button",
                    "EditMode — register frames into Blizzard's Edit Mode",
                }},
                { type = "note", style = "info", text = "See |cffffd700BAZ_SUITE_DEVELOPER_REFERENCE.txt|r in the BazCore folder for the full API reference with code examples." },
            },
        },
    },
})
