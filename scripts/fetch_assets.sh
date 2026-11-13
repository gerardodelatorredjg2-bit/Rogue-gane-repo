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

echo "Imported $(find "$DEST" -name '*.glb' | wc -l) low-poly robot models."
