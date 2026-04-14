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

    -- Left: list panel
    local listBg = CreateFrame("Frame", nil, splitFrame, "BackdropTemplate")
    listBg:SetPoint("TOPLEFT", 0, 0)
    listBg:SetPoint("BOTTOMLEFT", 0, 0)
    listBg:SetWidth(O.LIST_WIDTH)
    listBg:SetBackdrop(O.LIST_BACKDROP)
    listBg:SetBackdropColor(unpack(O.LIST_BG))
    listBg:SetBackdropBorderColor(unpack(O.PANEL_BORDER))

    -- Execute buttons at top of list (e.g. Create New Drawer)
    local listTopY = -6
    for _, execOpt in ipairs(executeArgs or {}) do
        local execBtn = CreateFrame("Button", nil, listBg, "UIPanelButtonTemplate")
        execBtn:SetSize(O.LIST_WIDTH - 12, 24)
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
    listContent:SetWidth(O.LIST_WIDTH - 26)
    listScroll:SetScrollChild(listContent)

    -- Right: detail panel
    local detailFrame = CreateFrame("Frame", nil, splitFrame, "BackdropTemplate")
    detailFrame:SetPoint("TOPLEFT", listBg, "TOPRIGHT", O.COL_GAP, 0)
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

    local selectedItem = container._lastSelectedItem or nil
    local listButtons = {}

    local function SelectGroup(index)
        selectedItem = index
        container._lastSelectedItem = index
        for i, btn in ipairs(listButtons) do
            if i == index then
                -- Selected: gold text, subtle highlight
                btn.bg:SetColorTexture(unpack(O.LIST_SELECTED))
                btn.text:SetTextColor(unpack(O.GOLD))
            else
                -- Deselected: clean text, no background
                btn.bg:SetColorTexture(0, 0, 0, 0)
                btn.text:SetTextColor(unpack(O.GOLD))
                btn.text:SetAlpha(0.7)
            end
        end
        -- Re-select restores full alpha
        if listButtons[index] then
            listButtons[index].text:SetAlpha(1.0)
        end

        O.ClearChildren(detailContent)
        local child = childGroups[index]
        if child and child.args then
            local dw = detailContent:GetWidth() - O.PAD
            if dw <= 0 then dw = 360 end
            local bottomY = O.RenderWidgets(detailContent, child.args, dw)
            detailContent:SetHeight(math.abs(bottomY) + O.PAD)
        end
    end

    -- Build list items (Traveler's Log gold text style)
    local listY = 0
    for i, child in ipairs(childGroups) do
        local itemBtn = CreateFrame("Button", nil, listContent)
        itemBtn:SetSize(O.LIST_WIDTH - 26, O.LIST_ITEM_HEIGHT)
        itemBtn:SetPoint("TOPLEFT", 0, -listY)

        local bg = itemBtn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0)
        itemBtn.bg = bg

        local text = itemBtn:CreateFontString(nil, "OVERLAY", O.LIST_FONT)
        text:SetPoint("LEFT", 8, 0)
        text:SetText(child.name or ("Item " .. i))
        text:SetTextColor(unpack(O.GOLD))
        text:SetAlpha(0.7)
        itemBtn.text = text

        itemBtn:SetScript("OnClick", function() SelectGroup(i) end)
        itemBtn:SetScript("OnEnter", function(self)
            if selectedItem ~= i then
                self.bg:SetColorTexture(unpack(O.LIST_HOVER))
                self.text:SetAlpha(1.0)
            end
        end)
        itemBtn:SetScript("OnLeave", function(self)
            if selectedItem ~= i then
                self.bg:SetColorTexture(0, 0, 0, 0)
                self.text:SetAlpha(0.7)
            end
        end)

        listButtons[#listButtons + 1] = itemBtn
        listY = listY + O.LIST_ITEM_HEIGHT
    end
    listContent:SetHeight(listY)

    -- Auto-select: restore previous selection or first item
    if #childGroups > 0 then
        C_Timer.After(0, function()
            detailContent:SetWidth(detailFrame:GetWidth() - 28)
            local restoreIdx = container._lastSelectedItem
            if not restoreIdx or restoreIdx < 1 or restoreIdx > #childGroups then
                restoreIdx = 1
            end
            SelectGroup(restoreIdx)
        end)
    end

    detailFrame:SetScript("OnSizeChanged", function(self, w)
        detailContent:SetWidth(w - 28)
        if selectedItem then SelectGroup(selectedItem) end
    end)

    return splitFrame
end
