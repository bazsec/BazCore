---------------------------------------------------------------------------
-- BazCore Memory Page
--
-- Live snapshot of Baz Suite memory consumption. Three new block types
-- plug into the existing options layout engine so the page itself is a
-- plain options table - no custom rendering, no special-case code in
-- Registration.lua. Each block subscribes to a shared sampler that
-- ticks via C_Timer; subscribers self-prune when their frames orphan
-- (i.e. when the user navigates away and ClearChildren orphans them).
---------------------------------------------------------------------------

local O = BazCore._Options
if not O then return end

---------------------------------------------------------------------------
-- Tunables
---------------------------------------------------------------------------

local UPDATE_INTERVAL = 0.5    -- seconds between memory polls
local HISTORY_LEN     = 120    -- 60 seconds of samples at 0.5 Hz
local SUMMARY_HEIGHT  = 78
local ROW_HEIGHT      = 26
local GRAPH_HEIGHT    = 170

---------------------------------------------------------------------------
-- Shared state - populated by the sampler, read by every block.
---------------------------------------------------------------------------

local state = {
    current     = {},   -- [addonName] = currentKB
    peak        = {},   -- [addonName] = peakKB (this session)
    currentTotal = 0,
    peakTotal    = 0,
    history     = {},   -- ring buffer of total samples
    historyHead = 0,    -- last-written index (1-based; 0 means empty)
}
for i = 1, HISTORY_LEN do state.history[i] = 0 end

---------------------------------------------------------------------------
-- Tracked addons - BazCore plus every addon registered through it.
-- Sorted alphabetically with BazCore pinned first so it always sits
-- at the top of the bar list.
---------------------------------------------------------------------------

local function GetTrackedAddons()
    local list = { "BazCore" }
    local seen = { BazCore = true }
    for name in pairs(BazCore.addons or {}) do
        if not seen[name] then
            list[#list + 1] = name
            seen[name] = true
        end
    end
    table.sort(list, function(a, b)
        if a == "BazCore" then return true end
        if b == "BazCore" then return false end
        return a < b
    end)
    return list
end

local function GetAddonDisplayName(name)
    local config = BazCore.addons and BazCore.addons[name]
    if config and config.title then return config.title end
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(name, "Title") or name
    end
    return name
end

local function FormatKB(kb)
    if not kb then return "-" end
    if kb >= 1024 then return string.format("%.2f MB", kb / 1024) end
    return string.format("%.0f KB", kb)
end

---------------------------------------------------------------------------
-- Sampler - runs once via C_Timer, no per-block polling. Subscribers
-- pass a frame + refresh callback; on every tick we call each callback
-- whose frame is still parented (ClearChildren reparents to nil, which
-- is our cue to drop the subscription).
---------------------------------------------------------------------------

local subscribers = {}

local function Subscribe(frame, refresh)
    subscribers[#subscribers + 1] = { frame = frame, refresh = refresh }
    refresh()  -- paint once immediately so the block isn't blank
end

local function CollectSample()
    if UpdateAddOnMemoryUsage then UpdateAddOnMemoryUsage() end

    local total = 0
    for _, name in ipairs(GetTrackedAddons()) do
        local kb = (GetAddOnMemoryUsage and GetAddOnMemoryUsage(name)) or 0
        state.current[name] = kb
        if (state.peak[name] or 0) < kb then state.peak[name] = kb end
        total = total + kb
    end
    state.currentTotal = total
    if state.peakTotal < total then state.peakTotal = total end

    state.historyHead = (state.historyHead % HISTORY_LEN) + 1
    state.history[state.historyHead] = total
end

local function Tick()
    CollectSample()

    -- Iterate, calling live subscribers and dropping orphaned ones.
    -- ClearChildren reparents to nil so :GetParent() reports nil for
    -- frames whose page was unloaded - easy liveness signal.
    local live = {}
    for _, sub in ipairs(subscribers) do
        if sub.frame and sub.frame:GetParent() then
            sub.refresh()
            live[#live + 1] = sub
        end
    end
    subscribers = live
end

-- Start sampling at file load. Cheap (~tens of microseconds per tick)
-- and means the graph already has data populated when the user first
-- opens the page rather than starting blank for 60 seconds.
CollectSample()
if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(UPDATE_INTERVAL, Tick)
end

---------------------------------------------------------------------------
-- Public-ish API: reset peak counters (wired into the page's button).
---------------------------------------------------------------------------

local function ResetPeaks()
    state.peakTotal = state.currentTotal
    for name, kb in pairs(state.current) do
        state.peak[name] = kb
    end
    Tick()  -- paint immediately rather than waiting for the next interval
end

---------------------------------------------------------------------------
-- Block: memSummary
--
-- Big card at the top of the page. Title on the left, big total value
-- on the right, peak text below the value, fill-bar showing the
-- current/peak ratio across the bottom.
---------------------------------------------------------------------------

local function CreateMemSummaryWidget(parent, opt, contentWidth)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(contentWidth, SUMMARY_HEIGHT)
    frame:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile     = true, tileSize = 16, edgeSize = 8,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.04, 0.04, 0.06, 0.85)
    frame:SetBackdropBorderColor(0.4, 0.35, 0.2, 0.85)

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("TOPLEFT", 16, -12)
    label:SetText("TOTAL")
    label:SetTextColor(1, 0.82, 0)

    local sub = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
    sub:SetText("Combined Baz Suite memory")
    sub:SetTextColor(0.65, 0.65, 0.65)

    local totalVal = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
    totalVal:SetPoint("RIGHT", -20, 8)
    totalVal:SetText("...")
    totalVal:SetTextColor(0.4, 0.85, 1)

    local peakLbl = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    peakLbl:SetPoint("TOPRIGHT", totalVal, "BOTTOMRIGHT", 0, -2)
    peakLbl:SetText("peak: ...")
    peakLbl:SetTextColor(0.7, 0.7, 0.7)

    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetPoint("BOTTOMLEFT", 16, 12)
    bar:SetPoint("BOTTOMRIGHT", -16, 12)
    bar:SetHeight(8)
    bar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
    bar:SetStatusBarColor(0.3, 0.7, 1, 0.85)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    local barBg = bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    barBg:SetColorTexture(0, 0, 0, 0.4)

    Subscribe(frame, function()
        totalVal:SetText(FormatKB(state.currentTotal))
        peakLbl:SetText("peak: " .. FormatKB(state.peakTotal))
        local pct = (state.peakTotal > 0) and (state.currentTotal / state.peakTotal) or 0
        bar:SetValue(pct)
    end)

    return frame, SUMMARY_HEIGHT
end

---------------------------------------------------------------------------
-- Block: memBarList
--
-- One row per tracked addon: name on the left, fill bar in the middle,
-- KB readout on the right, percent of total in a fixed column. Rows
-- are anchored alphabetically (BazCore pinned first); we update text
-- and bar values per tick rather than reordering.
---------------------------------------------------------------------------

local LABEL_W   = 160
local PCT_W     = 56
local VALUE_W   = 80
local ROW_GAP_X = 8
local ROW_PAD   = 6  -- vertical padding between rows

local function CreateMemBarListWidget(parent, opt, contentWidth)
    local addons = GetTrackedAddons()
    local rowCount = #addons
    local height = rowCount * ROW_HEIGHT + math.max(0, rowCount - 1) * 2 + ROW_PAD * 2

    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(contentWidth, height)
    frame:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile     = true, tileSize = 16, edgeSize = 8,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.04, 0.04, 0.06, 0.7)
    frame:SetBackdropBorderColor(0.4, 0.35, 0.2, 0.85)

    local rows = {}
    for i, name in ipairs(addons) do
        local row = CreateFrame("Frame", nil, frame)
        row:SetSize(contentWidth - 16, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 8, -ROW_PAD - (i - 1) * (ROW_HEIGHT + 2))

        -- Name (left)
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.label:SetPoint("LEFT", 6, 0)
        row.label:SetWidth(LABEL_W)
        row.label:SetJustifyH("LEFT")
        row.label:SetText(GetAddonDisplayName(name))
        if name == "BazCore" then
            row.label:SetTextColor(1, 0.82, 0)
        end

        -- Fill bar (middle, stretches)
        local bar = CreateFrame("StatusBar", nil, row)
        bar:SetPoint("LEFT", row.label, "RIGHT", ROW_GAP_X, 0)
        bar:SetPoint("RIGHT", -PCT_W - VALUE_W - ROW_GAP_X * 2 - 6, 0)
        bar:SetHeight(12)
        bar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
        bar:SetStatusBarColor(0.3, 0.7, 1, 0.85)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        row.bar = bar

        local barBg = bar:CreateTexture(nil, "BACKGROUND")
        barBg:SetAllPoints()
        barBg:SetColorTexture(0, 0, 0, 0.4)

        -- KB / MB readout (right of bar)
        row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.value:SetPoint("LEFT", bar, "RIGHT", ROW_GAP_X, 0)
        row.value:SetWidth(VALUE_W)
        row.value:SetJustifyH("RIGHT")
        row.value:SetText("...")

        -- Percent of total (far right)
        row.pct = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.pct:SetPoint("LEFT", row.value, "RIGHT", ROW_GAP_X, 0)
        row.pct:SetWidth(PCT_W)
        row.pct:SetJustifyH("RIGHT")
        row.pct:SetTextColor(0.65, 0.65, 0.65)
        row.pct:SetText("...")

        rows[name] = row
    end

    Subscribe(frame, function()
        local total = state.currentTotal
        local maxV = 0
        for _, name in ipairs(addons) do
            local kb = state.current[name] or 0
            if kb > maxV then maxV = kb end
        end
        if maxV < 1 then maxV = 1 end

        for _, name in ipairs(addons) do
            local row = rows[name]
            local kb = state.current[name] or 0
            row.value:SetText(FormatKB(kb))
            row.bar:SetValue(kb / maxV)
            local pct = (total > 0) and (kb / total * 100) or 0
            row.pct:SetText(string.format("%.0f%%", pct))

            -- Colour the bar based on this addon's slice of the total
            -- so heavy addons stand out at a glance.
            if pct >= 40 then
                row.bar:SetStatusBarColor(1.00, 0.50, 0.30, 0.85)   -- warm amber
            elseif pct >= 20 then
                row.bar:SetStatusBarColor(1.00, 0.80, 0.30, 0.85)   -- gold
            else
                row.bar:SetStatusBarColor(0.30, 0.70, 1.00, 0.85)   -- blue (default)
            end
        end
    end)

    return frame, height
end

---------------------------------------------------------------------------
-- Block: memGraph
--
-- Time-series histogram of the total memory readings over the last
-- HISTORY_LEN samples. Pool of vertical bar textures, one per slot -
-- we never recreate textures, just resize them per tick.
---------------------------------------------------------------------------

local function CreateMemGraphWidget(parent, opt, contentWidth)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(contentWidth, GRAPH_HEIGHT)
    frame:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile     = true, tileSize = 16, edgeSize = 8,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.04, 0.04, 0.06, 0.85)
    frame:SetBackdropBorderColor(0.4, 0.35, 0.2, 0.85)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", 16, -10)
    title:SetText("Total memory - last 60 seconds")
    title:SetTextColor(0.9, 0.9, 0.9)

    -- Rolling-window max, shown next to the title.
    local maxLbl = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    maxLbl:SetPoint("TOPRIGHT", -16, -10)
    maxLbl:SetTextColor(0.7, 0.7, 0.7)
    maxLbl:SetText("...")

    -- X-axis labels: oldest sample on the left, newest on the right.
    local oldestLbl = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    oldestLbl:SetPoint("BOTTOMLEFT", 16, 8)
    oldestLbl:SetTextColor(0.45, 0.45, 0.45)
    oldestLbl:SetText("60s ago")

    local newestLbl = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    newestLbl:SetPoint("BOTTOMRIGHT", -16, 8)
    newestLbl:SetTextColor(0.45, 0.45, 0.45)
    newestLbl:SetText("now")

    -- Plot area
    local plot = CreateFrame("Frame", nil, frame)
    plot:SetPoint("TOPLEFT", 16, -32)
    plot:SetPoint("BOTTOMRIGHT", -16, 22)

    -- Faint horizontal grid lines at 25% / 50% / 75% of the plot.
    for _, frac in ipairs({ 0.25, 0.5, 0.75 }) do
        local g = plot:CreateTexture(nil, "BACKGROUND")
        g:SetHeight(1)
        g:SetPoint("LEFT", 0, 0)
        g:SetPoint("RIGHT", 0, 0)
        -- Anchor by fraction from the bottom; OnSizeChanged would
        -- recompute these if the plot resized, but our plot is
        -- fixed-size after creation, so a one-shot anchor is fine.
        g:ClearAllPoints()
        g:SetPoint("BOTTOMLEFT", 0, 0)
        g:SetPoint("BOTTOMRIGHT", 0, 0)
        g:SetColorTexture(1, 1, 1, 0.06)
        plot._grid = plot._grid or {}
        plot._grid[#plot._grid + 1] = { tex = g, frac = frac }
    end

    -- Bar pool
    local bars = {}
    for i = 1, HISTORY_LEN do
        local bar = plot:CreateTexture(nil, "ARTWORK")
        bar:SetColorTexture(0.3, 0.7, 1, 0.7)
        bar:SetHeight(0.001)
        bars[i] = bar
    end

    -- Lay out the bars + grid lines once we know the plot's pixel size.
    -- Plot size resolves only after the frame has been parented and
    -- positioned, so we defer to the first OnSizeChanged.
    local laidOut = false
    local function LayoutGraph()
        local w = plot:GetWidth() or 0
        local h = plot:GetHeight() or 0
        if w < 1 or h < 1 then return end

        local barW = w / HISTORY_LEN
        for i = 1, HISTORY_LEN do
            bars[i]:ClearAllPoints()
            bars[i]:SetPoint("BOTTOMLEFT", (i - 1) * barW, 0)
            bars[i]:SetWidth(math.max(barW - 0.5, 0.5))
        end
        for _, g in ipairs(plot._grid or {}) do
            g.tex:ClearAllPoints()
            g.tex:SetPoint("BOTTOMLEFT", 0, h * g.frac)
            g.tex:SetPoint("BOTTOMRIGHT", 0, h * g.frac)
        end
        laidOut = true
    end
    plot:HookScript("OnSizeChanged", LayoutGraph)

    Subscribe(frame, function()
        if not laidOut then LayoutGraph() end
        local h = plot:GetHeight() or 0
        if h < 1 then return end

        -- Find the max sample in the window so we scale bars to fit.
        -- Using the rolling max (rather than peakTotal) means a brief
        -- spike doesn't permanently flatten the rest of the graph.
        local maxV = 1
        for _, v in ipairs(state.history) do
            if v > maxV then maxV = v end
        end

        -- Walk from oldest to newest. historyHead is the LAST written
        -- index, so the next slot ((head % N) + 1) is the oldest.
        local head = state.historyHead
        for plotIdx = 1, HISTORY_LEN do
            local readIdx = ((head + plotIdx - 1) % HISTORY_LEN) + 1
            local v = state.history[readIdx] or 0
            local bh = (v / maxV) * h
            bars[plotIdx]:SetHeight(math.max(bh, 0.001))

            -- Newest bar gets the bright accent colour; older bars dim.
            if plotIdx == HISTORY_LEN then
                bars[plotIdx]:SetColorTexture(1.00, 0.82, 0.30, 0.95)
            else
                bars[plotIdx]:SetColorTexture(0.30, 0.70, 1.00, 0.6)
            end
        end

        maxLbl:SetText(FormatKB(maxV))
    end)

    return frame, GRAPH_HEIGHT
end

---------------------------------------------------------------------------
-- Block: memGrowthList
--
-- Per-addon growth-rate readout sourced from BazCore's persistent
-- memory log. Sorted descending by KB-grown-this-window so the
-- biggest "leakers" (or just biggest growers) sit at the top.
-- Refreshes on each Tick, same cadence as the live blocks above.
---------------------------------------------------------------------------

local GROWTH_WINDOW_SEC = 3600   -- 1 hour
local MAX_GROWTH_ROWS   = 8
local GROWTH_ROW_H      = 22

local function CreateMemGrowthListWidget(parent, opt, contentWidth)
    local headerH    = 22
    local emptyH     = 22
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile     = true, tileSize = 16, edgeSize = 8,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.04, 0.04, 0.06, 0.7)
    frame:SetBackdropBorderColor(0.4, 0.35, 0.2, 0.85)

    local header = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    header:SetPoint("TOPLEFT", 16, -10)
    header:SetText("Top growers (last hour)")
    header:SetTextColor(0.9, 0.9, 0.9)

    local windowLbl = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    windowLbl:SetPoint("TOPRIGHT", -16, -10)
    windowLbl:SetTextColor(0.55, 0.55, 0.55)
    windowLbl:SetText("waiting for data...")

    local empty = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    empty:SetPoint("TOPLEFT", 16, -10 - headerH)
    empty:SetTextColor(0.6, 0.6, 0.6)
    empty:SetText("Waiting for at least 2 minutes of samples...")

    local rowPool = {}
    local function AcquireRow(i)
        local row = rowPool[i]
        if row then return row end
        row = CreateFrame("Frame", nil, frame)
        row:SetSize(contentWidth - 32, GROWTH_ROW_H)

        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.name:SetPoint("LEFT", 0, 0)
        row.name:SetWidth(160)
        row.name:SetJustifyH("LEFT")

        row.delta = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.delta:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
        row.delta:SetWidth(110)
        row.delta:SetJustifyH("RIGHT")

        row.rate = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.rate:SetPoint("LEFT", row.delta, "RIGHT", 8, 0)
        row.rate:SetWidth(120)
        row.rate:SetJustifyH("RIGHT")
        row.rate:SetTextColor(0.7, 0.7, 0.7)

        row.now = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.now:SetPoint("LEFT", row.rate, "RIGHT", 8, 0)
        row.now:SetJustifyH("RIGHT")
        row.now:SetTextColor(0.5, 0.5, 0.5)

        rowPool[i] = row
        return row
    end

    Subscribe(frame, function()
        if not BazCore.GetMemoryGrowth then
            empty:SetText("Memory log not loaded yet.")
            empty:Show()
            for _, r in pairs(rowPool) do r:Hide() end
            frame:SetSize(contentWidth, headerH + emptyH + 16)
            return
        end

        local growth, oldestT, latestT = BazCore:GetMemoryGrowth(GROWTH_WINDOW_SEC)
        if not growth or #growth == 0 then
            empty:Show()
            for _, r in pairs(rowPool) do r:Hide() end
            windowLbl:SetText("waiting for data...")
            frame:SetSize(contentWidth, headerH + emptyH + 16)
            return
        end

        empty:Hide()
        if oldestT and latestT then
            local mins = math.max(1, math.floor((latestT - oldestT) / 60))
            windowLbl:SetText(string.format("over last %d min", mins))
        end

        local shown = math.min(MAX_GROWTH_ROWS, #growth)
        local y = -10 - headerH
        for i = 1, shown do
            local g   = growth[i]
            local row = AcquireRow(i)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 16, y)
            row:Show()

            row.name:SetText(GetAddonDisplayName(g.name))
            local sign = g.deltaKB >= 0 and "+" or ""
            row.delta:SetText(string.format("%s%s", sign, FormatKB(math.abs(g.deltaKB))))

            -- Colour: red for noticeable positive growth, green for
            -- shrinkage (gc'd a chunk), grey near zero.
            if g.deltaKB > 200 then
                row.delta:SetTextColor(1.00, 0.50, 0.30)   -- warm amber
            elseif g.deltaKB > 50 then
                row.delta:SetTextColor(1.00, 0.85, 0.40)   -- gold
            elseif g.deltaKB < -50 then
                row.delta:SetTextColor(0.50, 0.95, 0.50)   -- green
            else
                row.delta:SetTextColor(0.65, 0.65, 0.65)   -- neutral
            end

            row.rate:SetText(string.format("%s%.1f KB/h", sign, math.abs(g.ratePerHour)))
            row.now:SetText("now " .. FormatKB(g.latestKB))
            y = y - GROWTH_ROW_H
        end
        for i = shown + 1, #rowPool do rowPool[i]:Hide() end

        frame:SetSize(contentWidth, headerH + shown * GROWTH_ROW_H + 20)
    end)

    -- Initial size before any data; the Subscribe callback fixes it.
    frame:SetSize(contentWidth, headerH + emptyH + 16)
    return frame, headerH + MAX_GROWTH_ROWS * GROWTH_ROW_H + 20
end

---------------------------------------------------------------------------
-- Block: memEventList
--
-- Recent annotated events with the corresponding memory total. Helps
-- the user correlate "what was happening when this addon spiked" -
-- combat starts, zone changes, /reloads.
---------------------------------------------------------------------------

local EVENT_ROW_H = 20
local MAX_EVENT_ROWS = 10

local EVENT_LABELS = {
    login        = "|cff8ce0ffLogin|r",
    reload       = "|cffffd700/reload|r",
    loading      = "|cffaaaaaaLoading|r",
    combat_start = "|cffff8c5cCombat start|r",
    combat_end   = "|cff90ee90Combat end|r",
    zone         = "|cffd0a8ffZone|r",
}

local function CreateMemEventListWidget(parent, opt, contentWidth)
    local headerH = 22
    local emptyH  = 22
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile     = true, tileSize = 16, edgeSize = 8,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.04, 0.04, 0.06, 0.7)
    frame:SetBackdropBorderColor(0.4, 0.35, 0.2, 0.85)

    local header = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    header:SetPoint("TOPLEFT", 16, -10)
    header:SetText("Recent events")
    header:SetTextColor(0.9, 0.9, 0.9)

    local empty = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    empty:SetPoint("TOPLEFT", 16, -10 - headerH)
    empty:SetTextColor(0.6, 0.6, 0.6)
    empty:SetText("No events recorded yet.")

    local rowPool = {}
    local function AcquireRow(i)
        local row = rowPool[i]
        if row then return row end
        row = CreateFrame("Frame", nil, frame)
        row:SetSize(contentWidth - 32, EVENT_ROW_H)

        row.tstr = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.tstr:SetPoint("LEFT", 0, 0)
        row.tstr:SetWidth(70)
        row.tstr:SetJustifyH("LEFT")
        row.tstr:SetTextColor(0.55, 0.55, 0.55)

        row.type = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.type:SetPoint("LEFT", row.tstr, "RIGHT", 8, 0)
        row.type:SetWidth(140)
        row.type:SetJustifyH("LEFT")

        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.label:SetPoint("LEFT", row.type, "RIGHT", 8, 0)
        row.label:SetWidth(220)
        row.label:SetJustifyH("LEFT")
        row.label:SetTextColor(0.75, 0.75, 0.75)
        row.label:SetWordWrap(false)

        row.mem = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.mem:SetPoint("RIGHT", 0, 0)
        row.mem:SetJustifyH("RIGHT")
        row.mem:SetTextColor(0.55, 0.55, 0.55)

        rowPool[i] = row
        return row
    end

    Subscribe(frame, function()
        if not BazCore.GetMemoryEvents then
            empty:Show()
            for _, r in pairs(rowPool) do r:Hide() end
            frame:SetSize(contentWidth, headerH + emptyH + 16)
            return
        end

        local events = BazCore:GetMemoryEvents()
        local hist   = BazCore.GetMemoryHistory and BazCore:GetMemoryHistory() or {}
        if #events == 0 then
            empty:Show()
            for _, r in pairs(rowPool) do r:Hide() end
            frame:SetSize(contentWidth, headerH + emptyH + 16)
            return
        end
        empty:Hide()

        -- Build a quick lookup from sample timestamp -> total KB so we
        -- can show the memory reading at the moment of each event
        -- without rescanning history per row.
        local memAt = {}
        for _, s in ipairs(hist) do memAt[s.t] = s.total end

        -- Walk newest-first (events are stored chronologically; reverse).
        local count = math.min(MAX_EVENT_ROWS, #events)
        local y = -10 - headerH
        for i = 1, count do
            local e = events[#events - i + 1]
            local row = AcquireRow(i)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 16, y)
            row:Show()

            row.tstr:SetText(date("%H:%M:%S", e.t))
            row.type:SetText(EVENT_LABELS[e.type] or e.type or "?")
            row.label:SetText(e.label or "")
            local kb = e.sampleT and memAt[e.sampleT]
            row.mem:SetText(kb and FormatKB(kb) or "")
            y = y - EVENT_ROW_H
        end
        for i = count + 1, #rowPool do rowPool[i]:Hide() end

        frame:SetSize(contentWidth, headerH + count * EVENT_ROW_H + 20)
    end)

    frame:SetSize(contentWidth, headerH + emptyH + 16)
    return frame, headerH + MAX_EVENT_ROWS * EVENT_ROW_H + 20
end

---------------------------------------------------------------------------
-- Register the block factories
---------------------------------------------------------------------------

O.widgetFactories.memSummary    = CreateMemSummaryWidget
O.widgetFactories.memBarList    = CreateMemBarListWidget
O.widgetFactories.memGraph      = CreateMemGraphWidget
O.widgetFactories.memGrowthList = CreateMemGrowthListWidget
O.widgetFactories.memEventList  = CreateMemEventListWidget

-- Mark the new types as full-width so the layout engine never tries
-- to pair them in a two-column section.
if O.RegisterFullWidthBlockType then
    O.RegisterFullWidthBlockType("memSummary")
    O.RegisterFullWidthBlockType("memBarList")
    O.RegisterFullWidthBlockType("memGraph")
    O.RegisterFullWidthBlockType("memGrowthList")
    O.RegisterFullWidthBlockType("memEventList")
end

---------------------------------------------------------------------------
-- Page registration
---------------------------------------------------------------------------

local function GetMemoryPage()
    return {
        name = "Memory",
        type = "group",
        args = {
            intro = {
                order = 1,
                type  = "lead",
                text  = "Live snapshot of Baz Suite memory consumption. " ..
                        "The summary + graph below cover the last 60 " ..
                        "seconds in real time. The Trends section uses " ..
                        "the persistent log (one sample per minute, kept " ..
                        "across /reload) to show longer-term growth and " ..
                        "what was happening when each addon spiked.",
            },
            summary = {
                order = 2,
                type  = "memSummary",
            },
            perAddonHeader = {
                order = 10,
                type  = "h2",
                name  = "Per Addon",
            },
            barList = {
                order = 11,
                type  = "memBarList",
            },
            graphHeader = {
                order = 20,
                type  = "h2",
                name  = "Total Over Time",
            },
            graph = {
                order = 21,
                type  = "memGraph",
            },
            trendsHeader = {
                order = 30,
                type  = "h2",
                name  = "Trends (persistent log)",
            },
            trendsLead = {
                order = 31,
                type  = "lead",
                text  = "Sampled once per minute and persisted to your character DB. " ..
                        "Survives /reload, so a peak that happens overnight is still " ..
                        "here in the morning. Use the dump button below to copy the " ..
                        "full TSV log into chat for offline analysis.",
            },
            growthList = {
                order = 32,
                type  = "memGrowthList",
            },
            eventList = {
                order = 33,
                type  = "memEventList",
            },
            actionsHeader = {
                order = 40,
                type  = "h2",
                name  = "Actions",
            },
            gcButton = {
                order = 41,
                type  = "execute",
                name  = "Force Garbage Collect",
                desc  = "Runs Lua's garbage collector and triggers an addon-memory snapshot. Useful for confirming a recent action's memory footprint actually freed.",
                width = "half",
                func  = function()
                    collectgarbage("collect")
                    Tick()
                end,
            },
            resetPeaksButton = {
                order = 42,
                type  = "execute",
                name  = "Reset Peaks",
                desc  = "Resets the per-addon peak counters and the total peak to the current values.",
                width = "half",
                func  = ResetPeaks,
            },
            dumpButton = {
                order = 43,
                type  = "execute",
                name  = "Dump Log to Chat",
                desc  = "Prints the full persistent memory log (TSV - tab-separated values) to chat. Copy and paste into a spreadsheet for analysis, or share in a bug report. Slash equivalent: /bazmem dump.",
                width = "half",
                func  = function()
                    if BazCore.DumpMemoryLog then BazCore:DumpMemoryLog() end
                end,
            },
            resetLogButton = {
                order = 44,
                type  = "execute",
                name  = "Reset Log",
                desc  = "Wipes the persistent memory log. Use this before reproducing a memory issue so the log only captures the relevant timeframe.",
                width = "half",
                func  = function()
                    if BazCore.ResetMemoryLog then BazCore:ResetMemoryLog() end
                end,
            },
        },
    }
end

local PAGE_KEY = "BazCore-Memory"
BazCore:RegisterOptionsTable(PAGE_KEY, GetMemoryPage)
BazCore:AddToSettings(PAGE_KEY, "Memory Usage", "BazCore")
