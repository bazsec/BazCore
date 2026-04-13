---------------------------------------------------------------------------
-- LibBazWidget-1.0
--
-- Standalone widget registry library distributed via LibStub. Provides a
-- simple publish/subscribe contract between widget *publishers* (any addon
-- that creates a dockable widget) and widget *consumers* (any addon that
-- hosts/displays widgets, e.g. BazDrawer).
--
-- Publishers call :RegisterWidget(widget) with a table containing at
-- minimum an `id` field. Consumers call :GetWidgets() to enumerate and
-- :RegisterCallback(fn) to be notified when the registry changes.
--
-- No WoW frames, events, or saved variables — pure data registry.
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

local MAJOR, MINOR = "LibBazWidget-1.0", 1
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
