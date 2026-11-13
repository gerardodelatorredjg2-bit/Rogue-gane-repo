# Production roadmap

## Milestone 0.1 — playable LAN foundation

- [x] Godot 4 project, mobile Compatibility renderer
- [x] First-person controller and touch buttons
- [x] Procedural low-poly world builder and six site themes
- [x] Salvage pickups, quota, credits and extraction
- [x] Robot enemy AI with patrol, hunt, attack and procedural limb animation
- [x] ENet host/client session flow and Android export workflow
- [ ] Physical-device LAN test across multiple Android phones
- [ ] Automated APK artifact verification

## Milestone 0.2 — gameplay depth

- [x] Add settings for look sensitivity, WASD/arrow mapping, invert-Y and left-handed mobile layout
- [ ] True joystick with configurable dead zones
- [x] Inventory slots, medkit, flashlight battery and motion scanner
- [x] Droppable items with rigid-body physics and server-validated repickup
- [x] Contract-based stalker difficulty scaling and attack lunge
- [ ] Enemy audio tells, sight checks and spawn director
- [ ] Crew revive, downed state and spectator camera
- [x] Quartermaster shop for services, consumables and ship upgrades
- [x] Hull resistance, cargo capacity and engine speed upgrades with ship visuals
- [ ] More distinct room layouts, doors, vents and locked compartments

## Milestone 0.3 — art and sound pass

- [x] Add a modular procedural drop-ship and industrial horror dressing
- [x] Add a ship service terminal with server-validated suit repair and stamina recharge purchases
- [x] Wire four rigged CC0 robot GLBs into the enemy loader and Android build pipeline
- [x] Add licensed Kenney Space Kit props and Poly Haven CC0 wall textures
- [ ] Replace procedural robot parts with rigged, attributed robot models where useful
- [x] Add a lightweight procedural industrial hum placeholder
- [x] Add Kenney CC0 sci-fi one-shot effects for gameplay/UI and 3D stalker cues
- [ ] Add footsteps, sustained machinery loops and radio interference
- [x] Add industrial warning stripes, service panels, signage and revised telemetry HUD
- [x] Add player profile name, settings panel, audio sliders, FPS/render-scale presets and look sensitivity
- [x] Add three basic crew emotes with LAN synchronization
- [x] Add original ROGUE MACHINES launcher icon and adaptive Android icon variants
- [ ] Add title screen motion, decals, grime and improved VFX
- [ ] Device profiling on low-end Android hardware

## Definition of done

A release candidate is not complete until a debug or release APK installs and launches on physical devices, a host can create a hotspot/LAN session, remote clients can join, loot and enemy events stay synchronized, and the game maintains its target frame rate on the declared minimum device.
