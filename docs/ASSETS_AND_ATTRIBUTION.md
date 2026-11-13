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
- [ ] Additional modular environment packs and props.
- [ ] External enemy animation states (idle / hunt / attack / death) mapped to gameplay AI states.
- [ ] Physical-device profiling after asset import.

## Attribution register

| File | Creator | Source URL | License | Required attribution |
|---|---|---|---|---|
| minion-a01.glb | Gobkit / Alsomind Tech Co., Ltd. | https://github.com/Ariescar/gobkit-free-assets/tree/main/minion | CC0 1.0 | None |
| minion-b01.glb | Gobkit / Alsomind Tech Co., Ltd. | https://github.com/Ariescar/gobkit-free-assets/tree/main/minion | CC0 1.0 | None |
| minion-c01.glb | Gobkit / Alsomind Tech Co., Ltd. | https://github.com/Ariescar/gobkit-free-assets/tree/main/minion | CC0 1.0 | None |
| minion-d01.glb | Gobkit / Alsomind Tech Co., Ltd. | https://github.com/Ariescar/gobkit-free-assets/tree/main/minion | CC0 1.0 | None |
