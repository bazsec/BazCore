---------------------------------------------------------------------------
-- BazCore Memory Log
--
-- Long-term memory sampler. The MemoryPage's live view (60 seconds at
-- 0.5 Hz, in-memory) is great for "is this widget leaking RIGHT NOW"
-- but useless for finding slow drift or correlating growth with
-- gameplay events. This module fills that gap:
--
--   * One snapshot per minute, persisted to BazCoreDB
--   * Per-addon series, not just the combined total
--   * Annotated events (login / reload / combat / zone change) so the
--     user can answer "what changed when this addon spiked?"
--   * Public API consumed by MemoryPage's "Trends & Events" section
--   * Slash command + export hook so the data can be pasted into a
--     spreadsheet or shared in a bug report
--
-- The data is intentionally small: 240 samples (4 hours) of ~10 addons
-- = roughly 30-50 KB in the saved variable, which is negligible next
-- to the in-game memory footprint we're trying to measure.
---------------------------------------------------------------------------

BazCore = BazCore or {}

local MAX_SAMPLES     = 240   -- 4 hours of one-per-minute data
local MAX_EVENTS      = 200   -- ring buffer of recent annotated events
local SAMPLE_INTERVAL = 60    -- seconds between samples

local log = {
    samples   = {},
    head      = 0,            -- last-written sample index
    events    = {},
    eventHead = 0,
}

---------------------------------------------------------------------------
-- Tracked addons - mirrors MemoryPage's tracking list. We resolve this
-- on every snapshot rather than caching so newly-registered addons
-- start showing up immediately.
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
    table.sort(list)
    return list
end

---------------------------------------------------------------------------
-- Persistence - both directions go through BazCoreDB.memLog.
---------------------------------------------------------------------------

local function PersistRef()
    if not BazCoreDB then return nil end
    BazCoreDB.memLog = BazCoreDB.memLog or {
        samples   = {},
        head      = 0,
        events    = {},
        eventHead = 0,
        version   = 1,
    }
    return BazCoreDB.memLog
end

local function Save()
    local p = PersistRef()
    if not p then return end
    p.samples   = log.samples
    p.head      = log.head
    p.events    = log.events
    p.eventHead = log.eventHead
end

local function Restore()
    local p = PersistRef()
    if not p then return end
    log.samples   = p.samples   or {}
    log.head      = p.head      or 0
    log.events    = p.events    or {}
    log.eventHead = p.eventHead or 0
end

---------------------------------------------------------------------------
-- Snapshot - takes a memory reading for every tracked addon and pushes
-- it onto the ring buffer. Called from the periodic ticker AND from
-- the event hook so we always have a "before/after" pair around the
-- interesting moment.
---------------------------------------------------------------------------

local function Snapshot()
    if UpdateAddOnMemoryUsage then UpdateAddOnMemoryUsage() end

    local sample = { t = time(), addons = {}, total = 0 }
    for _, name in ipairs(GetTrackedAddons()) do
        local kb = (GetAddOnMemoryUsage and GetAddOnMemoryUsage(name)) or 0
        sample.addons[name] = kb
        sample.total = sample.total + kb
    end

    log.head = (log.head % MAX_SAMPLES) + 1
    log.samples[log.head] = sample
    Save()
end

---------------------------------------------------------------------------
-- Event annotations - tagged with the current snapshot so the page can
-- show "memory at the moment of <event>". Snapshot first, then push
-- the event referencing the same timestamp.
---------------------------------------------------------------------------

local function PushEvent(evType, label)
    Snapshot()
    log.eventHead = (log.eventHead % MAX_EVENTS) + 1
    log.events[log.eventHead] = {
        t       = time(),
        type    = evType,
        label   = label,
        sampleT = log.samples[log.head] and log.samples[log.head].t,
    }
    Save()
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

-- GetMemoryHistory()
--   Returns the samples in chronological order (oldest first). Each
--   entry is { t, total, addons = { [name] = kb } }.
function BazCore:GetMemoryHistory()
    local out = {}
    for i = 1, MAX_SAMPLES do
        local idx = ((log.head + i - 1) % MAX_SAMPLES) + 1
        local s = log.samples[idx]
        if s then out[#out + 1] = s end
    end
    return out
end

-- GetMemoryEvents()
--   Returns annotated events in chronological order. Each entry:
--   { t, type, label, sampleT }.
function BazCore:GetMemoryEvents()
    local out = {}
    for i = 1, MAX_EVENTS do
        local idx = ((log.eventHead + i - 1) % MAX_EVENTS) + 1
        local e = log.events[idx]
        if e then out[#out + 1] = e end
    end
    return out
end

-- GetMemoryGrowth(windowSec)
--   For each tracked addon, computes (latest_kb - oldest_kb_within_window)
--   over the requested window in seconds. Useful for spotting steady
--   growth (= leaking). Returns an array sorted descending by growth,
--   each entry { name, deltaKB, ratePerHour, latestKB, oldestKB }.
function BazCore:GetMemoryGrowth(windowSec)
    windowSec = windowSec or 3600  -- default: 1 hour
    local hist = self:GetMemoryHistory()
    if #hist < 2 then return {} end

    local now = time()
    local cutoff = now - windowSec

    -- Latest sample
    local latest = hist[#hist]

    -- Find oldest sample inside the window
    local oldest
    for _, s in ipairs(hist) do
        if s.t >= cutoff then
            oldest = s
            break
        end
    end
    if not oldest or oldest == latest then return {} end

    local elapsedHours = math.max((latest.t - oldest.t) / 3600, 1 / 60)

    local out = {}
    for name, kb in pairs(latest.addons) do
        local was = oldest.addons[name] or kb  -- if addon wasn't tracked yet, treat as no growth
        local delta = kb - was
        out[#out + 1] = {
            name        = name,
            latestKB    = kb,
            oldestKB    = was,
            deltaKB     = delta,
            ratePerHour = delta / elapsedHours,
        }
    end
    table.sort(out, function(a, b) return a.deltaKB > b.deltaKB end)
    return out, oldest.t, latest.t
end

-- Quote a CSV field if it could break parsing - i.e. contains a
-- comma or quote. Numbers and timestamps go through as-is.
local function CsvField(v)
    if v == nil then return "" end
    local s = tostring(v)
    if s:find('[",]') then
        return '"' .. s:gsub('"', '""') .. '"'
    end
    return s
end

-- BuildDumpString()
--   Builds the full CSV log as a single string (instead of printing
--   line-by-line). Used by the popup dialog and any future export hook.
local function BuildDumpString()
    local hist = BazCore:GetMemoryHistory()
    if #hist == 0 then return nil end

    -- Collect every addon name across the history so the CSV columns
    -- line up even when an addon was registered partway through.
    local nameSet, nameList = {}, {}
    for _, s in ipairs(hist) do
        for name in pairs(s.addons) do
            if not nameSet[name] then
                nameSet[name] = true
                nameList[#nameList + 1] = name
            end
        end
    end
    table.sort(nameList)

    local lines = {}

    -- Header
    local header = { "time", "total_kb" }
    for _, n in ipairs(nameList) do header[#header + 1] = n end
    lines[#lines + 1] = table.concat(header, ",")

    -- Data rows
    for _, s in ipairs(hist) do
        local row = { date("%Y-%m-%d %H:%M:%S", s.t), string.format("%.0f", s.total) }
        for _, n in ipairs(nameList) do
            row[#row + 1] = string.format("%.0f", s.addons[n] or 0)
        end
        lines[#lines + 1] = table.concat(row, ",")
    end

    -- Events appended after a blank line so a CSV parser can split
    -- them into a separate sheet if desired.
    local events = BazCore:GetMemoryEvents()
    if #events > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "time,type,label"
        for _, e in ipairs(events) do
            lines[#lines + 1] = string.format("%s,%s,%s",
                date("%Y-%m-%d %H:%M:%S", e.t),
                CsvField(e.type),
                CsvField(e.label))
        end
    end

    return table.concat(lines, "\n"), #hist
end

-- DumpMemoryLog()
--   Prints the log to chat as CSV. Kept for /bazmem dump - useful
--   when you want a quick scan of recent rows without the popup.
function BazCore:DumpMemoryLog()
    local content, sampleCount = BuildDumpString()
    if not content then
        print("|cffffd700BazCore:|r memory log is empty - wait for the first sample (samples are taken every minute).")
        return
    end

    print("|cffffd700BazCore Memory Log:|r " .. sampleCount .. " sample(s). Copy lines below into a spreadsheet (CSV):")
    for line in content:gmatch("[^\n]+") do
        print(line)
    end
end

---------------------------------------------------------------------------
-- Popup dialog with a scrollable, selectable EditBox of the full CSV.
-- Friendlier export path than the chat dump: paste-ready, no chat-line
-- spam, full content visible at once. Built lazily on first open.
---------------------------------------------------------------------------

local dumpDialog

local function CreateDumpDialog()
    local f = CreateFrame("Frame", "BazCoreMemoryDumpDialog", UIParent, "BackdropTemplate")
    f:SetSize(640, 460)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(100)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile     = true, tileSize = 16, edgeSize = 16,
        insets   = { left = 5, right = 5, top = 5, bottom = 5 },
    })
    f:SetBackdropColor(0.04, 0.04, 0.06, 0.95)
    f:SetBackdropBorderColor(0.4, 0.35, 0.2, 0.95)
    f:Hide()

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("BazCore Memory Log Export")
    title:SetTextColor(1, 0.82, 0)
    f.title = title

    local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    sub:SetText("CSV format. Click |cffffd700Select All|r then press |cffffd700Ctrl+C|r to copy.")
    sub:SetTextColor(0.75, 0.75, 0.75)

    -- Close X button (top-right)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function() f:Hide() end)

    -- Scroll frame containing the EditBox
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -56)
    scroll:SetPoint("BOTTOMRIGHT", -34, 50)

    local editFrame = CreateFrame("Frame", nil, scroll, "BackdropTemplate")
    editFrame:SetSize(560, 360)
    editFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    editFrame:SetBackdropColor(0, 0, 0, 0.5)
    editFrame:SetBackdropBorderColor(0.3, 0.25, 0.15, 0.7)
    scroll:SetScrollChild(editFrame)

    local editBox = CreateFrame("EditBox", nil, editFrame)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(0)            -- 0 = no limit; large logs need this
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetWidth(540)
    editBox:SetAutoFocus(false)
    editBox:SetPoint("TOPLEFT", 8, -8)
    editBox:SetPoint("BOTTOMRIGHT", -8, 8)
    editBox:SetScript("OnEscapePressed", function() f:Hide() end)
    -- Re-highlight on click so fresh paste flow stays one-step.
    editBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    f.editBox = editBox

    -- Bottom button row
    local copyBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    copyBtn:SetSize(120, 24)
    copyBtn:SetPoint("BOTTOMLEFT", 16, 14)
    copyBtn:SetText("Select All")
    copyBtn:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("LEFT", copyBtn, "RIGHT", 12, 0)
    hint:SetText("then press |cffffd700Ctrl+C|r to copy")
    hint:SetTextColor(0.7, 0.7, 0.7)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(100, 24)
    closeBtn:SetPoint("BOTTOMRIGHT", -16, 14)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Stats (sample count, char count) above the buttons
    local stats = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    stats:SetPoint("BOTTOMLEFT", 16, 38)
    stats:SetTextColor(0.55, 0.55, 0.55)
    f.stats = stats

    -- ESC closes (and free up its slot if multiple dialogs use this).
    table.insert(UISpecialFrames, "BazCoreMemoryDumpDialog")

    return f
end

-- OpenMemoryDumpDialog()
--   Opens (or rebuilds the content of) the export dialog. If the log
--   is empty, surfaces a helpful chat message instead of an empty
--   popup so the user understands what to do.
function BazCore:OpenMemoryDumpDialog()
    local content, sampleCount = BuildDumpString()
    if not content then
        print("|cffffd700BazCore:|r memory log is empty - wait for the first sample (samples are taken every minute).")
        return
    end

    if not dumpDialog then dumpDialog = CreateDumpDialog() end

    dumpDialog.editBox:SetText(content)
    dumpDialog.stats:SetText(string.format("%d sample(s) | %d characters",
        sampleCount, #content))
    dumpDialog:Show()
    dumpDialog:Raise()
    dumpDialog.editBox:SetFocus()
    dumpDialog.editBox:HighlightText()
end

-- ResetMemoryLog()
--   Wipes the persistent log. Bound to a button on the page.
function BazCore:ResetMemoryLog()
    log.samples   = {}
    log.head      = 0
    log.events    = {}
    log.eventHead = 0
    Save()
end

---------------------------------------------------------------------------
-- Event hookup
--
-- We can't register events until the addon is loaded, but we can't
-- access BazCoreDB until PLAYER_LOGIN. The bootstrap below restores
-- the persisted log on login, then takes an immediate snapshot tagged
-- as "login" or "reload" depending on whether the world frame already
-- existed (PLAYER_ENTERING_WORLD's isReload arg gives us this).
---------------------------------------------------------------------------

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:RegisterEvent("PLAYER_REGEN_DISABLED")
boot:RegisterEvent("PLAYER_REGEN_ENABLED")
boot:RegisterEvent("ZONE_CHANGED_NEW_AREA")

local enteredWorldOnce = false

boot:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        Restore()
        if C_Timer and C_Timer.NewTicker then
            C_Timer.NewTicker(SAMPLE_INTERVAL, Snapshot)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isInitial, isReload = ...
        if not enteredWorldOnce then
            enteredWorldOnce = true
            PushEvent(isReload and "reload" or "login")
        else
            -- Loading screens between zones (e.g. portal, instance entry)
            PushEvent("loading", GetMinimapZoneText and GetMinimapZoneText() or nil)
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        PushEvent("combat_start")
    elseif event == "PLAYER_REGEN_ENABLED" then
        PushEvent("combat_end")
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        PushEvent("zone", GetMinimapZoneText and GetMinimapZoneText() or nil)
    end
end)

---------------------------------------------------------------------------
-- Slash command - quick access without opening the panel.
--   /bazmem        - prints a summary of current growth rates
--   /bazmem dump   - dumps the full TSV log
---------------------------------------------------------------------------

SLASH_BAZMEM1 = "/bazmem"
SlashCmdList.BAZMEM = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "export" or msg == "popup" then
        BazCore:OpenMemoryDumpDialog()
        return
    end
    if msg == "dump" then
        BazCore:DumpMemoryLog()
        return
    end
    if msg == "reset" then
        BazCore:ResetMemoryLog()
        print("|cffffd700BazCore:|r memory log cleared.")
        return
    end

    local growth = BazCore:GetMemoryGrowth(3600)
    if #growth == 0 then
        print("|cffffd700BazCore:|r not enough samples yet for a growth estimate (need at least 2 minutes of data).")
        return
    end
    print("|cffffd700BazCore Memory Growth (last hour):|r")
    for i = 1, math.min(8, #growth) do
        local g = growth[i]
        local sign = g.deltaKB >= 0 and "+" or ""
        print(string.format("  %-22s %s%.1f KB  (%s%.1f KB/h)  now %.0f KB",
            g.name, sign, g.deltaKB, sign, g.ratePerHour, g.latestKB))
    end
    print("|cffffd700/bazmem export|r popup CSV, |cffffd700/bazmem dump|r chat CSV, |cffffd700/bazmem reset|r clear log.")
end
