# BazCore Changelog

## 002 - Options Panel Overhaul
### New Features
- Two-panel options layout: list on left, settings on right
- Inline group panels with bordered sections
- Title bar with subtitle and right-aligned toggle support
- Select widgets show "None available" / "Select..." placeholder text
- Execute buttons capped at 220px width
- Profiles page: per-profile settings with create, switch, copy, delete, reset, auto-assignment
- Live refresh on profile create/delete/switch

### Fixes
- Replaced deprecated UIFrameFadeIn/UIFrameFade with animation groups
- Replaced deprecated OptionsSliderTemplate with MinimalSliderWithSteppersTemplate
- Added combat lockdown checks to keybind operations
- Fixed ClearOverrideBindings nil frame guard
- Settings.VarType enum used instead of raw type strings
- Fixed frame leaks in Menu and Compartment modules
- Animation groups cached per-frame, weak-keyed table for cleanup
- Safe table iteration in Events.UnregisterAll
- Serialization depth limit and cached string globals
- Empty slash command opens settings instead of showing help
- Minimap button sized to match LibDBIcon standard (31px)
