# Asset sourcing and attribution

## Imported robot models

The Android build and the local helper script fetch four standalone rigged low-poly GLB models from Gobkit's public sample collection:

- Creator / source: Gobkit / Alsomind Tech Co., Ltd.
- Repository: https://github.com/Ariescar/gobkit-free-assets
- Asset folder: https://github.com/Ariescar/gobkit-free-assets/tree/main/minion
- Files: `minion-a01.glb`, `minion-b01.glb`, `minion-c01.glb`, `minion-d01.glb`
- License: CC0 1.0 Universal (public domain dedication)
- License text: https://github.com/Ariescar/gobkit-free-assets/blob/main/LICENSE
- Integration: `scripts/fetch_assets.sh` downloads the files to `assets/models/robots/`; `scripts/enemy.gd` loads the matching model by enemy variant and falls back to procedural geometry when files are absent.
- Animation note: the GLB models include rigged animation data. The game currently starts the first imported AnimationPlayer clip; gameplay state-specific retargeting remains a follow-up task.

The downloaded CC0 license is stored as `assets/models/robots/LICENSE-CC0.txt`. The GLB files are fetched at build time rather than committed as opaque binary blobs, so local developers can reproduce the import with the same script.

## Added industrial environment, PBR and sound assets

### Kenney Space Kit props
- Creator / source: Kenney.
- Official pack: https://kenney.nl/assets/space-kit
- GLB mirror used by the import script: https://github.com/Hidencod/tge-assets/tree/main/packs/space-kit
- Models: `barrels.glb`, `machine-generator.glb`, `machine-wireless.glb`, `corridor-detailed.glb`, `corridor-wall.glb`, `pipe-straight.glb`, `craft-cargoa.glb`, `astronauta.glb`.
- License: CC0 1.0 (Kenney states all game assets on its asset pages are public-domain/CC0).
- Integration: `scripts/fetch_assets.sh` fetches the GLBs into `assets/models/kenney/`; `scripts/world_builder.gd` places a curated subset as industrial props on the six maps.
- The download helper stores a project-side CC0 license note in `assets/models/kenney/LICENSE-CC0.txt`.

### Poly Haven Rusty Painted Metal
- Creator: Amal Kumar.
- Source: https://polyhaven.com/a/rusty_painted_metal
- Maps: diffuse and roughness, 1K JPEG.
- License: CC0 1.0 Universal.
- Integration: `scripts/fetch_assets.sh` fetches the maps into `assets/textures/industrial/`; `scripts/world_builder.gd` uses them on the bulkheads and corridor walls.
- License note: `assets/textures/industrial/LICENSE-CC0.txt`.

### Kenney Sci-fi Sounds
- Creator / source: Kenney.
- Official pack: https://kenney.nl/assets/sci-fi-sounds
- Contents: 70 OGG effects (engines, lasers, impacts, explosions and digital sounds).
- License: Creative Commons CC0.
- Integration: `scripts/fetch_assets.sh` extracts OGG files into `assets/audio/kenney_sci_fi/`; `scripts/game.gd` uses them for loot, terminal, inventory and damage feedback, while `scripts/enemy.gd` plays positional alert and attack cues.
- Kenney's licensing FAQ says its game assets may be used in commercial projects and attribution is optional: https://kenney.nl/support.

## Additional asset libraries to evaluate

- Kenney: https://kenney.nl/assets — many packs are CC0; verify the specific pack.
- Quaternius: https://quaternius.com/ — low-poly characters, monsters and environment packs; verify the license on each pack.
- Poly Pizza: https://poly.pizza/ — license and attribution are listed per model; use CC0 where possible and record CC-BY credits.
- Sketchfab: https://sketchfab.com/ — use downloadable filters and inspect each model's exact Creative Commons license.
- itch.io: https://itch.io/game-assets — each creator sets the terms; "free" does not automatically mean redistributable.
- OpenGameArt: https://opengameart.org/ — license terms vary by asset.

## Import rules

1. Prefer CC0 for models that will ship in the APK and source distribution.
2. For CC-BY, keep creator name, source URL, license version and attribution text in this file.
3. Never download or redistribute a model marked non-commercial, editorial-only, or "no derivatives" without confirming that the intended use is permitted.
4. Keep models low-poly, use embedded/compressed textures, and test Android import size and frame time.
5. Do not use a Sketchfab or itch.io model just because its preview is downloadable; inspect the license on the individual asset page.

## Current asset status

- [x] Original procedural industrial environment and drop-ship geometry.
- [x] Four external CC0 robot models wired into the enemy loader and Android build download step.
- [x] Kenney Space Kit modular sci-fi props added to the six maps.
- [x] Poly Haven CC0 1K rusty metal PBR diffuse/roughness maps applied to industrial walls.
- [x] Kenney CC0 sci-fi sound effects wired to pickups, purchases, damage and stalker cues.
- [ ] External enemy animation states (idle / hunt / attack / death) mapped to gameplay AI states.
- [ ] Physical-device profiling after asset import.

## Attribution register

| File | Creator | Source URL | License | Required attribution |
|---|---|---|---|---|
| minion-a01.glb | Gobkit / Alsomind Tech Co., Ltd. | https://github.com/Ariescar/gobkit-free-assets/tree/main/minion | CC0 1.0 | None |
| minion-b01.glb | Gobkit / Alsomind Tech Co., Ltd. | https://github.com/Ariescar/gobkit-free-assets/tree/main/minion | CC0 1.0 | None |
| minion-c01.glb | Gobkit / Alsomind Tech Co., Ltd. | https://github.com/Ariescar/gobkit-free-assets/tree/main/minion | CC0 1.0 | None |
| minion-d01.glb | Gobkit / Alsomind Tech Co., Ltd. | https://github.com/Ariescar/gobkit-free-assets/tree/main/minion | CC0 1.0 | None |
| Kenney Space Kit GLBs (8 files listed above) | Kenney | https://kenney.nl/assets/space-kit | CC0 1.0 | None |
| Rusty Painted Metal diffuse + roughness 1K | Amal Kumar / Poly Haven | https://polyhaven.com/a/rusty_painted_metal | CC0 1.0 | None |
| Sci-Fi Sounds (70 OGG files) | Kenney | https://kenney.nl/assets/sci-fi-sounds | CC0 1.0 | None |
