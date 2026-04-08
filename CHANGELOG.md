# BazCore Changelog

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
