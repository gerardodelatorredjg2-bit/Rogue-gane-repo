# ROGUE MACHINES: LOST SIGNAL

Cooperative sci-fi salvage horror for Android and local Wi-Fi.

> Current milestone: expanded playable foundation with a modular drop-ship, industrial horror pass, telemetry HUD and an automated CC0 robot-model import. Built with Godot 4.7, GDScript and the Compatibility renderer for low-end Android devices.

## What is in this repository

- First-person 3D exploration with desktop and touch controls.
- ENet multiplayer: one phone hosts a Wi-Fi/LAN session; other phones join using the host's local IPv4 address.
- Procedurally assembled industrial environments with six selectable site themes.
- Robot stalkers with patrol, line-of-sight pursuit, search memory, attack lunge, horror overlays and positional audio; the Android workflow downloads four rigged CC0 robot models plus Kenney props.
- Salvage pickups, extraction quota, team credits and escalating contracts (quota +1 each shift, extra stalkers on later shifts).
- Personal inventory with medkits, flashlight cells and motion scanner; items can be used, dropped with rigid-body physics and picked up again.
- Expanded ship quartermaster: suit repair, stamina, medkits, batteries, scanner, hull reinforcement, cargo racks and engine tuning. Team upgrades affect damage resistance, inventory capacity, movement speed and visible ship modules.
- Modular drop-ship landing bay with interactive quartermaster, service terminal, hazard markings, service panels, fog and low-cost lighting; visible armor, cargo-rack and engine modules change as the crew buys upgrades.
- HUD telemetry with suit/stamina bars, quota progress, proximity warning sensor and a quick-access settings panel.
- Persistent player profile name, master/music volume sliders, graphics render-scale/FPS presets, look sensitivity, WASD/arrow-key selection, inverted vertical look and left-handed mobile controls.
- Three synchronized crew emotes (dance, wave and cheer) on the mobile HUD; basic articulated suit walk cycles and nameplates display across LAN.
- The Android build fetches Kenney Space Kit CC0 modular props, Poly Haven 1K CC0 rusty-metal PBR diffuse/roughness maps and Kenney CC0 sci-fi OGG effects.
- Stalker escalation: later contracts increase enemy movement speed and detection range, with a short attack lunge.
- A lightweight procedural machine hum as a temporary ambience layer; final music is intentionally left for the project owner.
- GitHub Actions workflow for Android APK export.

## Build with Godot

1. Install Godot **4.7 stable** and its matching export templates.
2. Open `project.godot`.
3. Run `bash scripts/fetch_assets.sh` to fetch the robot models, then run the project (F6/F5). If you skip the download, the enemies use their procedural fallback meshes.

## Android build

The repository includes an Android export preset and a GitHub Actions workflow. Pushes to `main` and manual workflow dispatch trigger an Android build. The workflow uploads a debug APK as an artifact when the export environment is available.

For a local build, configure the Android SDK and JDK 17 in Godot Editor Settings, install the matching Android export templates, then export the **Android** preset to `build/RogueMachines.apk`.

## LAN play

1. Connect every phone to the same Wi-Fi network or to the host phone's hotspot.
2. On the host, open **HOST LAN** and leave the game open.
3. Other players choose **JOIN LAN** and enter the host phone's local IPv4 address (for example `192.168.43.1`).
4. The default UDP port is **28960**. Do not use mobile data isolation or guest Wi-Fi client isolation.

LAN support depends on the Android device and hotspot allowing peer-to-peer traffic. The game does not require an online account or a central server.

## Controls

- PC: WASD move, mouse look, Shift sprint, Space jump, E interact, F flashlight, Esc release mouse.
- Mobile: on-screen directional controls, swipe to look, action buttons on the HUD.

## Current scope and honest status

This is an actively developed game project, not a claim of a finished commercial release. The current milestone focuses on the gameplay loop, LAN foundation and a first player-customization/settings pass. Enemy navigation, mobile-device compatibility, networking under real Wi-Fi conditions, and the APK must still be tested on physical devices before calling the build production-ready.

## Asset policy

The industrial environment and drop-ship combine original procedural geometry with licensed assets. `scripts/fetch_assets.sh` downloads Gobkit robot GLBs, Kenney Space Kit props and sci-fi sounds (CC0), plus Poly Haven's Rusty Painted Metal 1K PBR maps (CC0). Exact sources and license notes are listed in `docs/ASSETS_AND_ATTRIBUTION.md`.

## License

Code: MIT. Third-party assets, when added, retain their own original licenses and attribution requirements.
