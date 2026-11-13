# ROGUE MACHINES: LOST SIGNAL

Cooperative sci-fi salvage horror for Android and local Wi-Fi.

> Current milestone: expanded playable foundation with a modular drop-ship, industrial horror pass, telemetry HUD and an automated CC0 robot-model import. Built with Godot 4.7, GDScript and the Compatibility renderer for low-end Android devices.

## What is in this repository

- First-person 3D exploration with desktop and touch controls.
- ENet multiplayer: one phone hosts a Wi-Fi/LAN session; other phones join using the host's local IPv4 address.
- Procedurally assembled industrial environments with six selectable site themes.
- Robot stalkers with patrol, pursuit and attack states; the Android workflow downloads four rigged low-poly CC0 robot models and keeps a procedural fallback.
- Salvage pickups, extraction quota, team credits and round progression.
- Modular drop-ship landing bay with an interactive service terminal for suit repairs and stamina refills, plus industrial set dressing, hazard markings, service panels, fog and low-cost lighting.\n- HUD telemetry with suit/stamina bars, quota progress, proximity warning sensor and a quick-access settings panel.
- Persistent player profile name, master/music volume sliders, graphics FPS presets and mouse/touch look sensitivity setting.
- Three crew emotes (dance, wave and cheer) on the mobile HUD; emotes play only while stationary.
- Stalker escalation: later contracts increase enemy movement speed and detection range, with a short attack lunge.\n- A lightweight procedural machine hum as a temporary ambience layer; final music is intentionally left for the project owner.
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

The industrial environment and drop-ship are original procedural geometry. The Android build pipeline fetches four rigged low-poly robot GLBs from Gobkit's CC0 1.0 collection using `scripts/fetch_assets.sh`; the downloaded license is kept beside the models. Additional Kenney, Quaternius, Poly Pizza and Sketchfab assets may be added only after checking each model's license and attribution terms.

## License

Code: MIT. Third-party assets, when added, retain their own original licenses and attribution requirements.
