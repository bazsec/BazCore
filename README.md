<h1 align="center">BazCore</h1>

<p align="center">
  <strong>Shared framework for Baz addons</strong><br/>
  A lightweight, zero-dependency foundation library for World of Warcraft addon development.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/WoW-12.0%20Midnight-blue" alt="WoW Version"/>
  <img src="https://img.shields.io/badge/License-GPL%20v2-green" alt="License"/>
  <img src="https://img.shields.io/badge/Version-001-orange" alt="Version"/>
</p>

---

## What is BazCore?

BazCore is a shared framework library that provides common functionality for all Baz addons. It replaces the need for Ace3, LibStub, LibButtonGlow, LibDBIcon, and other third-party libraries with a single, purpose-built dependency.

**For addon users:** Install BazCore alongside any Baz addon that requires it. It runs silently in the background.

**For addon developers:** BazCore provides a declarative API for addon lifecycle, events, settings, profiles, slash commands, UI components, animations, keybinds, serialization, and more.

---

## Modules

| Module | Replaces | Description |
|--------|----------|-------------|
| **Core** | AceAddon | Addon registry, lifecycle management, addon object prototype |
| **Events** | AceEvent, CallbackHandler | Unified WoW event + custom event system with per-addon registration |
| **Settings** | — | Dragonflight+ vertical layout settings panel builder |
| **Profiles** | AceDB, AceDBOptions | Named profile system with per-character/class/spec assignment |
| **Commands** | AceConsole | Declarative slash command framework with auto-generated help |
| **UI** | — | Colors, branded print, backdrop factory, fade helpers, tooltip, draggable, status bars |
| **Timers** | — | Managed timers, throttle, debounce, cooldown with per-addon cleanup |
| **Format** | — | Money, time, number, and text formatting utilities |
| **Locale** | — | Simple localization system with passthrough fallback |
| **Menu** | — | Declarative context menu wrapper around MenuUtil |
| **Animations** | — | Reusable animation presets: pulse, bounce, flash, slide |
| **MinimapButton** | LibDBIcon, LibDataBroker | Single shared minimap button for all Baz addons |
| **ButtonGlow** | LibButtonGlow | Spell proc overlay glow effect using animation groups |
| **Compartment** | — | Addon Compartment integration (Dragonflight+ minimap dropdown) |
| **Keybinds** | — | Override keybinding framework with capture UI |
| **EditMode** | — | Helpers for integrating frames with Blizzard's Edit Mode |
| **Serialization** | AceSerializer | Table serialization + Base64 encoding for import/export |
| **OptionsPanel** | AceConfig, AceGUI | Rich options table renderer (AceConfig-style replacement) |

---

## For Addon Developers

### Registering an Addon

```lua
BazCore:RegisterAddon("MyAddon", {
    title = "My Addon",
    savedVariable = "MyAddonSV",
    defaults = {
        enabled = true,
        scale = 1.0,
    },
    OnInitialize = function(addon)
        -- Called on ADDON_LOADED
    end,
    OnEnable = function(addon)
        -- Called on PLAYER_LOGIN
    end,
})
```

### Events

```lua
local addon = BazCore:GetAddon("MyAddon")
addon:On("PLAYER_TARGET_CHANGED", function() ... end)
addon:Fire("MY_CUSTOM_EVENT", data)
```

### Settings

```lua
local value = BazCore:GetSetting("MyAddon", "scale")
BazCore:SetSetting("MyAddon", "scale", 1.5)
```

### Slash Commands

```lua
-- Declared in addon config
commands = {
    { cmd = "toggle", desc = "Toggle addon", handler = function(addon) ... end },
    { cmd = "reset", desc = "Reset settings", handler = function(addon) ... end },
}
```

---

## Installation

Install BazCore alongside any Baz addon that lists it as a dependency.

Extract to `World of Warcraft/_retail_/Interface/AddOns/BazCore/`

---

## Compatibility

| | |
|---|---|
| **WoW Version** | Retail 12.0.1 (Midnight) |
| **Dependencies** | None — completely standalone |
| **API Safety** | Uses modern Midnight APIs, animation groups for fades, Settings.VarType enums |

---

## License

BazCore is licensed under the [GNU General Public License v2](LICENSE) (GPL v2).

---

<p align="center">
  <sub>Built by <strong>Baz4k</strong></sub>
</p>
