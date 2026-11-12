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

- [ ] True joystick with configurable dead zones and sensitivity sliders
- [ ] Inventory slots, weight, scanner and objective items
- [ ] Enemy audio tells, sight checks, spawn director and difficulty scaling
- [ ] Crew revive, downed state and spectator camera
- [ ] Round shop: suit upgrades, battery, medkit, scanner and tools
- [ ] More distinct room layouts, doors, vents and locked compartments

## Milestone 0.3 — art and sound pass

- [ ] Add licensed modular environment packs from Kenney / Quaternius / Poly Pizza
- [ ] Replace procedural robot parts with rigged, attributed robot models where useful
- [ ] Add footsteps, machinery loops, radio interference and enemy cues
- [ ] Add title screen motion, decals, grime, signage and improved VFX
- [ ] Device profiling on low-end Android hardware

## Definition of done

A release candidate is not complete until a debug or release APK installs and launches on physical devices, a host can create a hotspot/LAN session, remote clients can join, loot and enemy events stay synchronized, and the game maintains its target frame rate on the declared minimum device.
