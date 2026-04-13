# BazCore

![WoW](https://img.shields.io/badge/WoW-12.0_Midnight-blue) ![License](https://img.shields.io/badge/License-GPL_v2-green) ![Version](https://img.shields.io/github/v/tag/bazsec/BazCore?label=Version&color=orange)

Shared framework for the Baz Suite of World of Warcraft addons.

BazCore is the foundation library that powers every addon in the Baz Suite. It handles addon registration, saved variables, unified profiles, settings panels, Edit Mode integration, minimap buttons, slash commands, event dispatching, and more - so each addon can focus on its own features without reinventing boilerplate.

BazCore also embeds [LibBazWidget-1.0](https://github.com/bazsec/LibBazWidget), the standalone widget registry library that powers BazWidgetDrawers' dockable widget system.

***

## Features

### Addon Framework

*   **RegisterAddon** - one-call registration with title, saved variable, defaults, slash commands, minimap button, and lifecycle callbacks
*   **Unified profiles** - one profile controls all Baz Suite addons at once, stored in BazCoreDB
*   **Profile migration** - automatically migrates old per-addon SavedVariables into the unified system

### Settings Panel

*   **Standard page types** - Landing Page, Settings (two-column), List + Detail, Modules, Global Options, and Profiles
*   **Two-column layout** - toggles and sliders auto-arrange into bordered panels when the window is wide enough
*   **Half-width buttons** - execute buttons with `width = "half"` render side by side
*   **Selection persistence** - list/detail panels remember the selected item across refreshes

### Edit Mode Integration

*   **RegisterEditModeFrame** - register any frame as an Edit Mode target with drag, snap, settings popup, and nudge controls
*   **Grid snapping** with live preview lines
*   **Selection sync** - selecting a BazCore frame deselects Blizzard frames and vice versa
*   **Settings popup** with checkboxes, sliders, and action buttons translated from the addon's options

### Dockable Widget API

*   **RegisterDockableWidget** / **UnregisterDockableWidget** - shims through to LibBazWidget-1.0
*   **GetDockableWidgets** / **GetDockableWidget** - query the widget registry
*   **RegisterDockableWidgetCallback** - subscribe to registry changes
*   **Widget contract** - id, label, frame, designWidth, designHeight, plus optional GetDesiredHeight, GetStatusText, GetOptionsArgs, OnDock, OnUndock

### Notification Bridge

*   **RegisterNotificationModule** / **PushNotification** - route notifications through BazNotificationCenter when installed
*   Lazy module registration on first push - no load order worries

### Utilities

*   **Events** - event dispatching and QueueForLogin helper
*   **Timers** - throttle and debounce helpers
*   **ObjectPool** - frame pooling for recycling UI elements
*   **Format** - number formatting, time formatting, safe string handling
*   **Animations** - fade, slide, and scale animation helpers
*   **ButtonGlow** - spell proc glow overlay system
*   **Keybinds** - keybind management with SetOverrideBindingClick
*   **Serialization** - export/import config strings
*   **Locale** - localization stub

***

## Slash Commands

| Command | Description |
| --- | --- |
| `/bazcore` | Open BazCore settings |

***

## Compatibility

*   **WoW Version:** Retail 12.0 (Midnight)
*   **Zero external dependencies** - BazCore depends on nothing except WoW itself
*   **Midnight API Safe** - uses taint-safe patterns throughout
*   **LibStub** - embedded for LibBazWidget-1.0 version negotiation
*   **LibBazWidget-1.0** - embedded standalone widget registry library

***

## The Baz Suite

BazCore powers the following addons:

*   **[BazBars](https://www.curseforge.com/wow/addons/bazbars)** - Custom extra action bars
*   **[BazWidgetDrawers](https://www.curseforge.com/wow/addons/bazwidgetdrawers)** - Slide-out widget drawer
*   **[BazWidgets](https://www.curseforge.com/wow/addons/bazwidgets)** - Widget pack for BazWidgetDrawers
*   **[BazNotificationCenter](https://www.curseforge.com/wow/addons/baznotificationcenter)** - Toast notification system
*   **[BazLootNotifier](https://www.curseforge.com/wow/addons/bazlootnotifier)** - Animated loot popups
*   **[BazDungeonFinder](https://www.curseforge.com/wow/addons/bazdungeonfinder)** - Detached LFG queue bar
*   **[BazFlightZoom](https://www.curseforge.com/wow/addons/bazflightzoom)** - Auto zoom on flying mounts
*   **[BazMap](https://www.curseforge.com/wow/addons/bazmap)** - Resizable map and quest log window
*   **[BazMapPortals](https://www.curseforge.com/wow/addons/bazmapportals)** - Mage portal/teleport map pins

***

## License

BazCore is licensed under the **GNU General Public License v2** (GPL v2).
