# BazCore Changelog

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
