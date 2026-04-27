---------------------------------------------------------------------------
-- LibBazWidget-1.0
--
-- Standalone widget registry library distributed via LibStub. Provides a
-- simple publish/subscribe contract between widget *publishers* (any addon
-- that creates a dockable widget) and widget *consumers* (any addon that
-- hosts/displays widgets, e.g. BazWidgetDrawers).
--
-- Publishers call :RegisterWidget(widget) with a table containing at
-- minimum an `id` field. Consumers call :GetWidgets() to enumerate and
-- :RegisterCallback(fn) to be notified when the registry changes.
--
-- No WoW frames, events, or saved variables - pure data registry.
--
-- Widget contract (publishers populate, consumers read):
--   Required:
--     widget.id                 unique string identifier
--     widget.frame              the actual Frame to host
--   Display:
--     widget.label              display label shown in title bars
--     widget.icon               optional texture path or atlas name
--   Sizing:
--     widget.designWidth        native width in pixels (host scales to fit)
--     widget.designHeight       native height in pixels (initial hint)
--   Callbacks (optional):
--     widget:GetDesiredHeight() host asks how tall the widget wants to be
--     widget:GetStatusText()    returns (text, r, g, b) for title bar
--     widget:GetOptionsArgs()   returns AceConfig-style args table
--     widget:OnDock(host)       called when parented into a host slot
--     widget:OnUndock()         called when removed from a host slot
---------------------------------------------------------------------------

local MAJOR, MINOR = "LibBazWidget-1.0", 2
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end  -- already loaded same or newer version

-- Preserve tables across library upgrades so existing references stay valid
lib.registered = lib.registered or {}    -- array of widget tables (insertion order)
lib.byId       = lib.byId       or {}    -- [id] = widget
lib.callbacks  = lib.callbacks  or {}    -- list of listener functions

local registered = lib.registered
local byId       = lib.byId
local callbacks  = lib.callbacks

---------------------------------------------------------------------------
-- Internal: fire all registered callbacks (publisher or consumer may have
-- added them). Errors in one callback don't break others.
---------------------------------------------------------------------------

local function FireCallbacks()
    for _, fn in ipairs(callbacks) do
        pcall(fn)
    end
end

---------------------------------------------------------------------------
-- Publisher API
---------------------------------------------------------------------------

function lib:RegisterWidget(widget)
    if type(widget) ~= "table" or not widget.id then
        error("LibBazWidget-1.0:RegisterWidget requires a widget table with an 'id' field", 2)
    end
    if byId[widget.id] then
        -- Re-registering: replace in place, preserve insertion order
        for i, w in ipairs(registered) do
            if w.id == widget.id then
                registered[i] = widget
                break
            end
        end
    else
        table.insert(registered, widget)
    end
    byId[widget.id] = widget
    FireCallbacks()
end

function lib:UnregisterWidget(id)
    if not byId[id] then return end
    byId[id] = nil
    for i, w in ipairs(registered) do
        if w.id == id then
            table.remove(registered, i)
            break
        end
    end
    FireCallbacks()
end

---------------------------------------------------------------------------
-- Consumer API
---------------------------------------------------------------------------

function lib:GetWidgets()
    return registered
end

function lib:GetWidget(id)
    return byId[id]
end

function lib:RegisterCallback(fn)
    if type(fn) == "function" then
        table.insert(callbacks, fn)
    end
end

---------------------------------------------------------------------------
-- Dormant Widget API
--
-- A dormant widget is one that only appears in the registry when a
-- condition is met. The library manages the register/unregister lifecycle
-- automatically based on game events.
--
-- Usage:
--   LBW:RegisterDormantWidget(widget, {
--       events = { "LFG_UPDATE", "LFG_QUEUE_STATUS_UPDATE", ... },
--       condition = function() return IsQueued() end,
--   })
--
-- When any listed event fires, the condition is re-evaluated. If true
-- and the widget isn't registered, it gets registered. If false and the
-- widget is registered, it gets unregistered. The host reflows via the
-- normal callback mechanism.
--
-- Call :UnregisterDormantWidget(id) to tear down the listener entirely.
---------------------------------------------------------------------------

lib.dormant = lib.dormant or {}  -- [id] = { widget, opts, frame, active }

function lib:RegisterDormantWidget(widget, opts)
    if type(widget) ~= "table" or not widget.id then
        error("LibBazWidget-1.0:RegisterDormantWidget requires a widget table with an 'id' field", 2)
    end
    if not opts or type(opts.condition) ~= "function" then
        error("LibBazWidget-1.0:RegisterDormantWidget requires opts.condition function", 2)
    end

    local id = widget.id

    -- Clean up any previous dormant registration for this id
    if lib.dormant[id] then
        lib:UnregisterDormantWidget(id)
    end

    -- Hidden frame to listen for events
    local listener = CreateFrame("Frame")
    local entry = {
        widget = widget,
        opts = opts,
        frame = listener,
        active = false,
    }
    lib.dormant[id] = entry

    local function Evaluate()
        local shouldBeActive = opts.condition()
        if shouldBeActive and not entry.active then
            entry.active = true
            lib:RegisterWidget(widget)
        elseif not shouldBeActive and entry.active then
            entry.active = false
            lib:UnregisterWidget(id)
        end
    end

    -- Register for specified events
    if opts.events then
        for _, event in ipairs(opts.events) do
            listener:RegisterEvent(event)
        end
    end
    listener:SetScript("OnEvent", function()
        Evaluate()
    end)

    -- Initial evaluation
    Evaluate()
end

function lib:UnregisterDormantWidget(id)
    local entry = lib.dormant[id]
    if not entry then return end

    -- Stop listening
    if entry.frame then
        entry.frame:UnregisterAllEvents()
        entry.frame:SetScript("OnEvent", nil)
        entry.frame:Hide()
    end

    -- Unregister from the widget registry if currently active
    if entry.active then
        lib:UnregisterWidget(id)
    end

    lib.dormant[id] = nil
end

-- Check if a dormant widget is currently active (registered)
function lib:IsDormantWidgetActive(id)
    local entry = lib.dormant[id]
    return entry and entry.active or false
end
