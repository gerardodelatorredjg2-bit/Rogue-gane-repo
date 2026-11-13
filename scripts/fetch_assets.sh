#!/usr/bin/env bash
set -euo pipefail

DEST="assets/models/robots"
BASE="https://raw.githubusercontent.com/Ariescar/gobkit-free-assets/main/minion"
mkdir -p "$DEST"

for model in minion-a01 minion-b01 minion-c01 minion-d01; do
  echo "Fetching ${model}.glb (Gobkit CC0)"
  curl --fail --location --silent --show-error --retry 3 \
    "$BASE/${model}.glb" \
    --output "$DEST/${model}.glb"
  test -s "$DEST/${model}.glb"
done

curl --fail --location --silent --show-error --retry 3 \
  "https://raw.githubusercontent.com/Ariescar/gobkit-free-assets/main/LICENSE" \
  --output "$DEST/LICENSE-CC0.txt"

# Kenney Space Kit CC0 models (small, self-contained GLBs).
KENNEY_DIR="assets/models/kenney"
KENNEY_BASE="https://raw.githubusercontent.com/Hidencod/tge-assets/main/packs/space-kit"
mkdir -p "$KENNEY_DIR"
for model in barrels machine-generator machine-wireless corridor-detailed corridor-wall pipe-straight craft-cargoa astronauta; do
  echo "Fetching Kenney Space Kit: ${model}.glb"
  curl --fail --location --silent --show-error --retry 3 \
    "$KENNEY_BASE/${model}.glb" --output "$KENNEY_DIR/${model}.glb"
  test -s "$KENNEY_DIR/${model}.glb"
done
cat > "$KENNEY_DIR/LICENSE-CC0.txt" <<'LICENSE'
Kenney Space Kit models
Source pack: https://kenney.nl/assets/space-kit
GLB mirror/catalog: https://github.com/Hidencod/tge-assets
License: Creative Commons Zero 1.0 (CC0).
Kenney's official licensing FAQ confirms the game assets are public-domain/CC0:
https://kenney.nl/support
Attribution is not required; credit is included in this project.
LICENSE

# Poly Haven CC0 PBR maps: 1K JPEGs keep Android download size moderate.
TEXTURE_DIR="assets/textures/industrial"
TEXTURE_BASE="https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/rusty_painted_metal"
mkdir -p "$TEXTURE_DIR"
for map in diff rough; do
  curl --fail --location --silent --show-error --retry 3 \
    "$TEXTURE_BASE/rusty_painted_metal_${map}_1k.jpg" \
    --output "$TEXTURE_DIR/rusty_painted_metal_${map}_1k.jpg"
  test -s "$TEXTURE_DIR/rusty_painted_metal_${map}_1k.jpg"
done
cat > "$TEXTURE_DIR/LICENSE-CC0.txt" <<'LICENSE'
Texture: Rusty Painted Metal
Creator: Amal Kumar
Source: https://polyhaven.com/a/rusty_painted_metal
Maps: diffuse and roughness (1K JPEG).
License: CC0 1.0 Universal.
LICENSE

# Kenney Sci-Fi Sounds: unpack the OGG effects and preserve the ZIP license.
AUDIO_DIR="assets/audio/kenney_sci_fi"
AUDIO_ZIP="${TMPDIR:-/tmp}/kenney_sci-fi-sounds.zip"
mkdir -p "$AUDIO_DIR"
curl --fail --location --silent --show-error --retry 3 \
  "https://kenney.nl/media/pages/assets/sci-fi-sounds/6b296f9ecf-1677589334/kenney_sci-fi-sounds.zip" \
  --output "$AUDIO_ZIP"
unzip -jo "$AUDIO_ZIP" '*.ogg' -d "$AUDIO_DIR" >/dev/null
unzip -jo "$AUDIO_ZIP" 'License.txt' 'license.txt' -d "$AUDIO_DIR" >/dev/null 2>&1 || true
echo "Imported $(find "$KENNEY_DIR" -name '*.glb' | wc -l) Kenney props, $(find "$TEXTURE_DIR" -name '*.jpg' | wc -l) PBR maps and $(find "$AUDIO_DIR" -name '*.ogg' | wc -l) CC0 sci-fi sounds."
