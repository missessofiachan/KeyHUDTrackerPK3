
# Key HUD Tracker (GZDoom / UZDoom Mod)

A lightweight, standalone HUD mod for GZDoom and UZDoom that renders floating holographic markers over important level objects visible directly through walls to help guide you through complex maps.

Originally built just for uncollected keys, the tracker has been heavily expanded to optionally track **Secrets, Level Exits, Weapons, and the Level Start**.

![GZDoom Compatible](https://img.shields.io/badge/GZDoom-v4.10%2B-blue)

## Features

* **Comprehensive Tracking**: Dynamically tracks Keys, Weapons, Normal/Secret Exits, Level Starts, and undiscovered Secrets (both Sectors and Actors).
* **3D World-to-Screen Projection**: Uses precise mathematical projections to place icons and text exactly where they sit in 3D world space.
* **4K & High-Resolution Support**: Text and shadow outlines dynamically scale based on your screen resolution and user settings, ensuring perfect readability on modern high-res displays.
* **Hologram Animation**: Icons and markers float smoothly using a sinus-wave hover animation.
* **Smart State Filtering**:
* Keys automatically hide if you already have that type in your inventory.
* Secret markers clamp to player eye-level to prevent vertical screen-culling and automatically vanish the exact frame the engine registers them as "found."
* Direct checks ignore invisible dummy/helper actors (phantom filtering).


* **WolfenDoom & Custom Mod Compatibility**: Detects custom keys dynamically, with fallback checks for classic key sprites (`YKEY`, `BKEY`, `RKEY`, `GKEY`, `SKEY`, `GOLD`, `SILV`) to support total conversions.
* **Fully Customizable**: Toggle specific tracking categories, scale, and opacity directly via the console CVars.

## Configuration CVars

Configure these in the console or through a generated options menu:

### Display & Scaling

* `key_tracker_enabled` (default: `true`): Enable or disable the HUD tracker entirely.
* `key_tracker_scale` (default: `1.0`): Scale multiplier for the floating icons and text. (Stacks with automatic resolution scaling).
* `key_tracker_alpha` (default: `0.8`): Opacity of the icons, text, and distance indicators.
* `key_tracker_show_distance` (default: `true`): Renders distance (in meters) directly on the marker.
* `key_tracker_max_distance` (default: `0.0`): Limit tracking range (in meters). `0.0` means unlimited range.

### Tracking Toggles

* `key_tracker_track_secrets` (default: `true`): Toggle tracking for undiscovered secret sectors and secret actors.
* `key_tracker_track_exits` (default: `true`): Toggle tracking for normal and secret level exits.
* `key_tracker_track_entry` (default: `true`): Toggle tracking for the player's initial spawn point.
* `key_tracker_track_weapons` (default: `false`): Toggle tracking for uncollected weapons in the map.

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
