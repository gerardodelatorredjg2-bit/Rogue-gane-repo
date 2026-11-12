# Asset sourcing and attribution

The first playable milestone deliberately uses procedural low-poly meshes, materials, lights and robot parts generated in GDScript. This keeps the build small and avoids accidentally redistributing third-party models without permission.

When replacing procedural props with downloaded models, use the following pipeline:

1. Prefer assets whose individual page explicitly grants CC0 or another license that permits redistribution in a game.
2. Save the source page URL, creator name, license name, and download date in this document before adding the file.
3. Keep the original license text and attribution file alongside the imported asset.
4. Do not assume that every model on a marketplace shares the same license.

## Candidate libraries

- Kenney: https://kenney.nl/assets — many packs are published under CC0; verify the specific pack page and keep its license note.
- Quaternius: https://quaternius.com/ — game-ready low-poly packs; verify the license on each download.
- Poly Pizza: https://poly.pizza/ — check the license and attribution requirements on each model page.
- Sketchfab: https://sketchfab.com/ — filter by downloadable and compatible Creative Commons license; check each model's creator and attribution terms.
- OpenGameArt: https://opengameart.org/ — license terms vary by asset; record the exact license.

## Asset integration targets

- Six industrial environment kits with modular walls, pipes, floor panels, machinery and props.
- Three robot enemy rigs with readable silhouettes and distinct animation cycles.
- First-person salvage scanner, flashlight and extraction terminal.
- Small audio set: machine ambience, footsteps, radio noise, robot alert, impact and extraction cue.

## Attribution register

No external model or sound files have been embedded in this initial milestone. Add a row for every imported asset before merging it:

| File | Creator | Source URL | License | Required attribution |
|---|---|---|---|---|
| — | — | — | — | — |
