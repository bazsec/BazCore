# BazCore Changelog

## 026 - DockableWidget API, Modules Page, Minimap Icon Mask
- New `DockableWidget.lua` module exposing the cross-addon dockable widget registry used by BazDrawer
  - `BazCore:RegisterDockableWidget(widget)` — registers a widget to appear in BazDrawer's slot stack
  - `BazCore:UnregisterDockableWidget(id)` — removes a widget from the registry
  - `BazCore:GetDockableWidgets()` / `GetDockableWidget(id)` — read the registry
  - `BazCore:RegisterDockableWidgetCallback(fn)` — subscribe to registry changes
  - Widget contract: `id`, `label`, `designWidth`, `designHeight`, `frame`, and optional `GetDesiredHeight`, `GetStatusText`, `GetOptionsArgs`, `OnDock`, `OnUndock`
- New `BazCore:CreateModulesPage(addonName, config)` helper — builds a standard "Modules" subcategory with a flat list of enable/disable toggles, used by BNC for notification modules and by BazDrawer for dockable widgets
- Minimap button icon now uses a circular alpha mask (`Interface\CHARACTERFRAME\TempPortraitAlphaMask`) so it blends into the tracking border instead of showing as a square inside a ring; icon size bumped 18→20 to fill the new circular frame

## 025 - Addon List Button, Toggle Padding
- Added an "Addon Options" button to Blizzard's AddOn List window that opens directly to the BazCore options category
- Fixed the toggle widget in two-column options panels so multi-line descriptions no longer overflow their card's bottom padding
  - Checkbox now anchors to the top of the widget frame instead of the vertical center

## 024 - Notification Bridge
- Added `BazCore:RegisterNotificationModule(id, info)` for Baz Suite addons to register with BazNotificationCenter
- Added `BazCore:PushNotification(data)` that routes through BNC (no-op if BNC isn't installed)
- Lazy-registers modules on first push so addons don't have to think about load order
- Profile switches now fire a "Profile Changed" toast via the internal `_bazcore` module

## 023 - SetScaleFromCenter, EditMode fixes
- Added BazCore:SetScaleFromCenter() utility for scaling frames from their visual center
- Fixed EditMode position save/restore to use addon object instead of removed Settings module
- Removed references to non-loaded Settings.lua _settingsProxy

## 022 - Unified Profile System
- Profiles now live in BazCoreDB and control all Baz Suite addons at once
- One profile switch changes every addon's configuration together
- Profiles page moved from individual addons into BazCore settings
- Automatic migration of existing per-addon profiles into unified system
- Per-character, per-class, and per-spec profile assignment

## 021 - Global Options Page Builder
- Added BazCore:CreateGlobalOptionsPage() standard page type for global override settings
- Added disabled property support to toggle and range widget factories
- Widgets with disabled=true (or function) gray out and block interaction
- Disabled state re-evaluates on every OnShow for dynamic conditions

## 018 - Audit Fixes
- Auto-wired addon.db profile proxy via CreateDBProxy() in RegisterAddon
- Addons no longer need manual profileProxy boilerplate
- Category changed to "Baz Suite" for addon panel grouping

## 017
- Two-column panel layout now works for flat options pages (no groups required)

## 016 - Options Panel Overhaul
- Two-column bordered panel layout for settings (auto when panel > 500px wide)
- Modern MinimalScrollBar replaces old UIPanelScrollFrameTemplate scroll bars
- Headers use gold/yellow text for visual consistency
- Groups can set `columns = 1` to force single column
- Minimap button menu respects per-addon onClick handler

## 014 - Two-Column Options Panel
- Options panel now auto-uses two-column layout when wide enough (>500px)
- Headers and descriptions span full width across both columns
- Toggles, sliders, inputs, and selects flow into two columns
- Groups can override with `columns = 1` to force single column
- Reduces scrolling on settings pages with many options

## 013 - ObjectPool, DND, Notification Bridge
- Added `BazCore:CreateObjectPool(createFunc, resetFunc)` — reusable object pool for UI recycling
- Added `BazCore:IsDND()` — returns true if in combat or encounter active
- Added `BazCore:PushNotification(data)` — routes to BazNotificationCenter if installed

## 012
- Minimap button now respects hide setting on login/reload

## 011
- SafeString now uses string.format to strip Midnight secret string taint
- tostring() alone does not desecretize strings in Midnight

## 010
- Version now reads from TOC dynamically (no more hardcoded version)
- Minimap tooltip shows BazCore version
- Right-click minimap button opens BazCore settings

## 009
- Settings panel: added Baz Suite version info display
- Settings panel: added welcome message toggle
- Settings panel: added per-addon memory usage with refresh button

## 008
- Added `BazCore:SafeMatch()`, `BazCore:SafeFind()`, `BazCore:SafeString()` for Midnight secret string taint handling

## 007
- Added `BazCore:MakeResizable()` — reusable drag-to-resize handle for any frame
- Supports min/max scale, screen capping, custom get/set callbacks

## 006
- Fixed grid snapping using wrong scale (GetEffectiveScale vs GetScale)
- Snap preview lines and snap-on-drop now align correctly for scaled frames

## 005
- Full Edit Mode framework for all Baz Suite addons
- Blizzard-native nine-slice overlays (cyan highlight, yellow selected)
- Grid snapping with red preview lines during drag
- Selection sync with Blizzard Edit Mode frames
- Configurable settings popup with collapsible sections
- Widget types: slider, checkbox, dropdown, input, nudge, color picker
- Built-in revert and reset position actions
- ESC key closes settings popup
- Smart popup positioning (flips side when near screen edge)
- Dynamic label update API
- Position persistence with effectiveScale compensation

## 004
- Added BazCore settings page (minimap toggle, registered addons list)
- Fixed minimap dropdown not opening addon settings
- Minimap button visibility is now controlled from BazCore settings, not per-addon
