# Key HUD Tracker (GZDoom / UZDoom Mod)

A lightweight, standalone HUD mod for GZDoom and UZDoom that renders floating holographic markers over uncollected keys in the level—visible directly through walls—to help guide you through complex maps.

## Features

- **3D World-to-Screen Projection**: Uses precise mathematical projections to place key icons exactly where they sit in 3D world space.
- **Hologram Animation**: Icons float smoothly using a sinus-wave hover animation.
- **WolfenDoom & Custom Mod Compatibility**: Detects custom keys dynamically, with fallback checks for classic key sprites (`YKEY`, `BKEY`, `RKEY`, `GKEY`, `SKEY`, `GOLD`, `SILV`) to support total conversions.
- **Smart Duplicate Filtering**: Automatically hides markers for key types that you already have in your inventory.
- **Phantom Filtering**: Direct checks to ignore invisible dummy/helper actors using the `TNT1` sprite.
- **Fully Customizable**: Toggle settings, scales, and opacity directly via the GZDoom options menu or console CVars.

## Configuration CVars

Configure these in the console or through the options menu:

- `key_tracker_enabled` (default: `true`): Enable or disable the HUD tracker.
- `key_tracker_scale` (default: `1.0`): Scale multiplier of the floating key icons.
- `key_tracker_alpha` (default: `0.8`): Opacity of the icons and distance indicators.
- `key_tracker_show_distance` (default: `true`): Renders distance (in meters) directly above each key icon.
- `key_tracker_max_distance` (default: `0.0`): Limit tracking range (in meters). `0.0` means unlimited range.

## Installation

### Loading the Directory
You can load the directory directly in GZDoom/UZDoom using your launcher or command line:
```bash
gzdoom -file "/path/to/KeyHUDTrackerPK3"
```

### Loading as a PK3
You can also package this directory as a `.pk3` file (which is just a renamed `.zip` archive) and load it:
```bash
gzdoom -file KeyHUDTracker.pk3
```
