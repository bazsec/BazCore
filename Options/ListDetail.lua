---------------------------------------------------------------------------
-- BazCore Options: List/Detail Split Panel
-- Gold text links on dark background (Traveler's Log style).
-- Left list, right detail. Used by Widgets, Drawers, BazBars bars, etc.
---------------------------------------------------------------------------

local O = BazCore._Options

---------------------------------------------------------------------------
-- Build a list/detail split panel inside a container.
-- groupOpt: the group option containing child groups
-- container: parent frame
-- contentWidth: available width
-- yOffset: starting Y position
-- executeArgs: optional buttons above the list (Create New, etc.)
-- Returns: new yOffset after the split panel
---------------------------------------------------------------------------

function O.BuildListDetailPanel(container, groupOpt, contentWidth, yOffset, executeArgs)
    -- Split frame: anchors to bottom of container to fill space
    local splitFrame = CreateFrame("Frame", nil, container)
    splitFrame:SetPoint("TOPLEFT", container, "TOPLEFT", O.PAD, yOffset)
    splitFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -O.PAD, O.PAD)
    splitFrame:Show()

    -- List width via the shared resolver (28 % / 200-320 px) so the
    -- standard list/detail panel matches the User Manual exactly.
    local containerW = container:GetWidth() or contentWidth or 600
    local listW = O.ResolveListWidth(containerW)

    -- Left: list panel
    local listBg = CreateFrame("Frame", nil, splitFrame, "BackdropTemplate")
    listBg:SetPoint("TOPLEFT", 0, 0)
    listBg:SetPoint("BOTTOMLEFT", 0, 0)
    listBg:SetWidth(listW)
    listBg:SetBackdrop(O.LIST_BACKDROP)
    listBg:SetBackdropColor(unpack(O.LIST_BG))
    listBg:SetBackdropBorderColor(unpack(O.PANEL_BORDER))

    -- Execute buttons at top of list (e.g. Create New Drawer)
    local listTopY = -6
    for _, execOpt in ipairs(executeArgs or {}) do
        local execBtn = CreateFrame("Button", nil, listBg, "UIPanelButtonTemplate")
        execBtn:SetSize(listW - 12, 24)
        execBtn:SetPoint("TOPLEFT", listBg, "TOPLEFT", 6, listTopY)
        execBtn:SetText(execOpt.name or "")
        execBtn:SetScript("OnClick", function()
            if execOpt.func then execOpt.func() end
        end)
        local fs = execBtn:GetFontString()
        if fs then fs:SetFontObject("GameFontHighlightSmall") end
        execBtn:Show()
        listTopY = listTopY - 28
    end

    -- List scroll
    local listScroll = CreateFrame("ScrollFrame", nil, listBg)
    listScroll:SetPoint("TOPLEFT", 4, listTopY - 2)
    listScroll:SetPoint("BOTTOMRIGHT", -14, 4)
    listScroll:EnableMouseWheel(true)

    local listScrollBar = CreateFrame("EventFrame", nil, listBg, "MinimalScrollBar")
    listScrollBar:SetPoint("TOPLEFT", listScroll, "TOPRIGHT", 2, 0)
    listScrollBar:SetPoint("BOTTOMLEFT", listScroll, "BOTTOMRIGHT", 2, 0)
    ScrollUtil.InitScrollFrameWithScrollBar(listScroll, listScrollBar)

    local listContent = CreateFrame("Frame", nil, listScroll)
    listContent:SetWidth(listW - 26)
    listScroll:SetScrollChild(listContent)
    O.AutoHideScrollbar(listScroll, listScrollBar)

    -- Right: detail panel
    local detailFrame = CreateFrame("Frame", nil, splitFrame, "BackdropTemplate")
    detailFrame:SetPoint("TOPLEFT", listBg, "TOPRIGHT", O.PAGE_LIST_GAP, 0)
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

    -- Build child groups list
    local childSorted = O.SortedArgs(groupOpt.args)
    local childGroups = {}
    for _, child in ipairs(childSorted) do
        if child.type == "group" then
            childGroups[#childGroups + 1] = child
        end
    end

    -- Detect source-based grouping. When ANY child group declares a
    -- `source`, switch to collapsible-section rendering: one header
    -- per source, children listed under it. Without this, all the
    -- child groups would render flat — fine for short lists but
    -- noisy for wide lists like the BWD Widgets page once a user
    -- has many LDB feeds installed.
    local hasSourceGrouping = false
    for _, child in ipairs(childGroups) do
        if child.source then hasSourceGrouping = true break end
    end

    -- Selection is tracked by the child's `name` string (stable across
    -- list rebuilds when sections are expanded/collapsed). Falls back
    -- to nil if the previously selected item no longer exists.
    local selectedKey = container._lastSelectedItem
    -- Legacy: older sessions stored an integer index. Drop it — the
    -- restore path below will pick the first available group instead.
    if type(selectedKey) ~= "string" then selectedKey = nil end

    -- Per-source collapse state survives within the panel's lifetime
    -- (resets on /reload). Storing in `container` matches how
    -- _lastSelectedItem already persists across page navigations.
    container._collapsedSources = container._collapsedSources or {}

    local listButtons = {}     -- list of clickable child rows (filtered by collapse state)
    local rowsByChild = {}     -- [child] = button, for highlight updates

    local function GetChildByKey(key)
        if not key then return nil end
        for _, c in ipairs(childGroups) do
            if c.name == key then return c end
        end
    end

    local function SelectGroup(child)
        if not child then return end
        selectedKey = child.name
        container._lastSelectedItem = selectedKey

        for c, btn in pairs(rowsByChild) do
            if c == child then
                btn.bg:SetColorTexture(unpack(O.LIST_SELECTED))
                btn.text:SetTextColor(unpack(O.GOLD))
                btn.text:SetAlpha(1.0)
            else
                btn.bg:SetColorTexture(0, 0, 0, 0)
                btn.text:SetTextColor(unpack(O.GOLD))
                btn.text:SetAlpha(0.7)
            end
        end

        O.ClearChildren(detailContent)
        if child.args then
            local dw = detailContent:GetWidth() - O.PAD
            if dw <= 0 then dw = 360 end
            local bottomY = O.RenderWidgets(detailContent, child.args, dw)
            detailContent:SetHeight(math.abs(bottomY) + O.PAD)
        end
    end

    -- Builds one clickable child row. xIndent shifts the text right so
    -- grouped children read as visually nested under their header.
    -- Selection chrome is the same Blizzard-style gold-gradient band
    -- the User Manual tree uses (via O.BuildSelectionHighlight) so
    -- both layouts read as cohesive across the suite.
    local function BuildChildRow(child, listY, xIndent)
        local itemBtn = CreateFrame("Button", nil, listContent)
        itemBtn:SetSize(listW - 26, O.LIST_ITEM_HEIGHT)
        itemBtn:SetPoint("TOPLEFT", 0, -listY)

        -- Subtle hover background for non-selected rows. Selection
        -- itself uses the gradient highlight; the bg texture stays
        -- as a fallback / hover surface only.
        local hover = itemBtn:CreateTexture(nil, "BACKGROUND")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.05)
        hover:Hide()
        itemBtn.hover = hover

        local hlGroup = O.BuildSelectionHighlight(itemBtn, O.LIST_ITEM_HEIGHT)
        O.ShowHighlightGroup(hlGroup, child.name == selectedKey)
        itemBtn.hlGroup = hlGroup

        local text = itemBtn:CreateFontString(nil, "OVERLAY", O.LIST_FONT)
        text:SetPoint("LEFT", xIndent or 8, 0)
        text:SetPoint("RIGHT", -4, 0)
        text:SetJustifyH("LEFT")
        text:SetText(child.name or "?")
        if child.name == selectedKey then
            text:SetTextColor(1, 1, 1)         -- white when selected
            text:SetAlpha(1.0)
        else
            text:SetTextColor(unpack(O.GOLD))  -- gold otherwise
            text:SetAlpha(0.75)
        end
        itemBtn.text = text

        itemBtn:SetScript("OnClick", function() SelectGroup(child) end)
        itemBtn:SetScript("OnEnter", function(self)
            if child.name ~= selectedKey then
                self.hover:Show()
                self.text:SetAlpha(1.0)
            end
        end)
        itemBtn:SetScript("OnLeave", function(self)
            if child.name ~= selectedKey then
                self.hover:Hide()
                self.text:SetAlpha(0.75)
            end
        end)

        listButtons[#listButtons + 1] = itemBtn
        rowsByChild[child] = itemBtn
        return itemBtn
    end

    local RenderList  -- forward declaration so the section-header click can call it

    -- Builds a clickable section header with the same Blizzard
    -- plus/minus toggle textures the User Manual tree uses, so the
    -- two collapsible-list patterns in BazCore feel consistent.
    local function BuildSectionHeader(source, count, listY)
        local headerBtn = CreateFrame("Button", nil, listContent)
        headerBtn:SetSize(listW - 26, O.LIST_ITEM_HEIGHT)
        headerBtn:SetPoint("TOPLEFT", 0, -listY)

        local hover = headerBtn:CreateTexture(nil, "BACKGROUND")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.05)
        hover:Hide()

        local collapsed = container._collapsedSources[source] or false
        local arrow = headerBtn:CreateTexture(nil, "OVERLAY")
        arrow:SetSize(14, 14)
        arrow:SetPoint("LEFT", 6, 0)
        arrow:SetTexture(collapsed
            and "Interface\\Buttons\\UI-PlusButton-Up"
            or  "Interface\\Buttons\\UI-MinusButton-Up")

        local label = headerBtn:CreateFontString(nil, "OVERLAY", O.LIST_FONT)
        label:SetPoint("LEFT", arrow, "RIGHT", 6, 0)
        label:SetText(source .. "  |cff888888(" .. count .. ")|r")
        label:SetTextColor(unpack(O.GOLD))

        headerBtn:SetScript("OnEnter", function() hover:Show() end)
        headerBtn:SetScript("OnLeave", function() hover:Hide() end)
        headerBtn:SetScript("OnClick", function()
            container._collapsedSources[source] = not container._collapsedSources[source]
            RenderList()
        end)
        return headerBtn
    end

    RenderList = function()
        O.ClearChildren(listContent)
        listButtons = {}
        rowsByChild = {}

        local listY = 0

        if hasSourceGrouping then
            -- Bucket children by source, preserving each source's first
            -- appearance order so the same input produces a stable list.
            local bySource, sourceOrder = {}, {}
            for _, child in ipairs(childGroups) do
                local src = child.source or "Other"
                if not bySource[src] then
                    bySource[src] = {}
                    sourceOrder[#sourceOrder + 1] = src
                end
                table.insert(bySource[src], child)
            end

            for _, src in ipairs(sourceOrder) do
                BuildSectionHeader(src, #bySource[src], listY)
                listY = listY + O.LIST_ITEM_HEIGHT
                if not container._collapsedSources[src] then
                    for _, child in ipairs(bySource[src]) do
                        BuildChildRow(child, listY, 22)  -- indented under header
                        listY = listY + O.LIST_ITEM_HEIGHT
                    end
                end
            end
        else
            -- Flat list (legacy behaviour for pages without source-tagged
            -- children, e.g. Drawers).
            for _, child in ipairs(childGroups) do
                BuildChildRow(child, listY, 8)
                listY = listY + O.LIST_ITEM_HEIGHT
            end
        end

        listContent:SetHeight(math.max(listY, 1))
    end

    RenderList()

    -- Auto-select: restore previous selection or pick the first child
    if #childGroups > 0 then
        C_Timer.After(0, function()
            detailContent:SetWidth(detailFrame:GetWidth() - 28)
            local restore = GetChildByKey(selectedKey) or childGroups[1]
            -- If the restored child sits inside a collapsed source,
            -- expand that source so the user sees their selection.
            if hasSourceGrouping and restore.source
               and container._collapsedSources[restore.source] then
                container._collapsedSources[restore.source] = false
                RenderList()
            end
            SelectGroup(restore)
        end)
    end

    detailFrame:SetScript("OnSizeChanged", function(self, w)
        detailContent:SetWidth(w - 28)
        local cur = GetChildByKey(selectedKey)
        if cur then SelectGroup(cur) end
    end)

    return splitFrame
end
