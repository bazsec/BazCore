-- SPDX-License-Identifier: GPL-2.0-or-later
---------------------------------------------------------------------------
-- BazCore: DockableWidget
--
-- Thin compatibility shim that delegates to LibBazWidget-1.0 when
-- available. All existing code calling BazCore:RegisterDockableWidget()
-- continues to work - the shim just forwards to the standalone library.
--
-- If LibBazWidget-1.0 is not installed, the shim falls back to a local
-- inline registry (identical behavior to pre-library versions) so
-- BazCore is never hard-dependent on the library addon.
--
-- Widget contract (see LibBazWidget-1.0 for full documentation):
--   widget.id                 unique string identifier
--   widget.label              display label
--   widget.icon               optional texture path or atlas name
--   widget.frame              the actual Frame to parent into a host slot
--   widget:OnDock(host)       optional, called when parented into a slot
--   widget:OnUndock()         optional, called when removed from a slot
--   widget:GetDesiredHeight() optional, host asks how tall it wants to be
--   widget:GetStatusText()    optional, returns (text, r, g, b) for title
---------------------------------------------------------------------------

local LBW = LibStub and LibStub("LibBazWidget-1.0", true)

if LBW then
    ---------------------------------------------------------------------------
    -- LibBazWidget available - delegate everything
    ---------------------------------------------------------------------------
    function BazCore:RegisterDockableWidget(widget)
        LBW:RegisterWidget(widget)
    end

    function BazCore:UnregisterDockableWidget(id)
        LBW:UnregisterWidget(id)
    end

    function BazCore:GetDockableWidgets()
        return LBW:GetWidgets()
    end

    function BazCore:GetDockableWidget(id)
        return LBW:GetWidget(id)
    end

    function BazCore:RegisterDockableWidgetCallback(fn)
        LBW:RegisterCallback(fn)
    end
else
    ---------------------------------------------------------------------------
    -- Fallback: inline registry (identical to pre-library behavior)
    ---------------------------------------------------------------------------
    local registered = {}
    local byId = {}
    local callbacks = {}

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
end
