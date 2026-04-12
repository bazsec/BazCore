---------------------------------------------------------------------------
-- BazCore: DockableWidget
--
-- Cross-addon registry for dockable widgets that plug into BazDrawer.
-- Any Baz Suite addon can call BazCore:RegisterDockableWidget() and the
-- drawer will pick it up and reflow its slot layout. If BazDrawer isn't
-- installed, the registry still exists but no host consumes it — addons
-- that register widgets should provide their own standalone fallback
-- positioning (Edit Mode frame, etc.) so they work without the drawer.
--
-- Widget contract:
--   widget.id                 unique string identifier (e.g. "bazquesttracker")
--   widget.label              display label ("Quest Tracker")
--   widget.icon               optional texture path or atlas name
--   widget.defaultHeight      initial height hint in pixels
--   widget.frame              the actual Frame to parent into a drawer slot
--   widget:OnDock(host)       optional, called when parented into a slot
--   widget:OnUndock()         optional, called when removed from a slot
--   widget:SetDockedWidth(w)  optional, drawer tells widget its slot width
--   widget:GetDesiredHeight() optional, drawer asks how tall it wants to be
---------------------------------------------------------------------------

local registered = {}        -- array of widget tables (insertion order)
local byId = {}              -- [id] = widget
local callbacks = {}         -- list of functions to call when registry changes

local function FireCallbacks()
    for _, fn in ipairs(callbacks) do
        pcall(fn)
    end
end

function BazCore:RegisterDockableWidget(widget)
    if type(widget) ~= "table" or not widget.id then
        error("BazCore:RegisterDockableWidget requires a widget table with an 'id' field", 2)
    end
    if byId[widget.id] then
        -- Re-registering: replace in place
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

function BazCore:UnregisterDockableWidget(id)
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

function BazCore:GetDockableWidgets()
    return registered
end

function BazCore:GetDockableWidget(id)
    return byId[id]
end

function BazCore:RegisterDockableWidgetCallback(fn)
    if type(fn) == "function" then
        table.insert(callbacks, fn)
    end
end
