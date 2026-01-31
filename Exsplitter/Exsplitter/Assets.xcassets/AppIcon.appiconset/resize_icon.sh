#!/bin/bash
# Resize image.png to all App Icon sizes. Run from Exsplitter/Exsplitter/ or pass paths.
set -e
SRC="${1:-$(dirname "$0")/../../image.png}"
OUT="$(dirname "$0")"
# sips -z height width src --out dst
sips -z 20 20 "$SRC" --out "$OUT/Icon-App-20x20@1x.png"
sips -z 29 29 "$SRC" --out "$OUT/Icon-App-29x29@1x.png"
sips -z 40 40 "$SRC" --out "$OUT/Icon-App-20x20@2x.png"
cp "$OUT/Icon-App-20x20@2x.png" "$OUT/Icon-App-40x40@1x.png"
sips -z 58 58 "$SRC" --out "$OUT/Icon-App-29x29@2x.png"
sips -z 60 60 "$SRC" --out "$OUT/Icon-App-20x20@3x.png"
sips -z 76 76 "$SRC" --out "$OUT/Icon-App-76x76@1x.png"
sips -z 80 80 "$SRC" --out "$OUT/Icon-App-40x40@2x.png"
sips -z 87 87 "$SRC" --out "$OUT/Icon-App-29x29@3x.png"
sips -z 120 120 "$SRC" --out "$OUT/Icon-App-40x40@3x.png"
cp "$OUT/Icon-App-40x40@3x.png" "$OUT/Icon-App-60x60@2x.png"
sips -z 152 152 "$SRC" --out "$OUT/Icon-App-76x76@2x.png"
sips -z 167 167 "$SRC" --out "$OUT/Icon-App-83.5x83.5@2x.png"
sips -z 180 180 "$SRC" --out "$OUT/Icon-App-60x60@3x.png"
sips -z 1024 1024 "$SRC" --out "$OUT/Icon-App-1024x1024.png"
echo "App icons generated from $(basename "$SRC")"
