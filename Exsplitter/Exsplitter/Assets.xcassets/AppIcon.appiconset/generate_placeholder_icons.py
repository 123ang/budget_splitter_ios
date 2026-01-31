#!/usr/bin/env python3
"""
Generate placeholder app icon PNGs for Exsplitter.
Uses only Python standard library (no Pillow). Run once, then archive.
Replace these with real icons later via appicon.co or your designer.
"""
import zlib
import struct
import os

# Blue-ish color (Exsplitter brand feel): R, G, B
FILL = (10, 132, 255)  # ~iOS blue

def png_chunk(chunk_type: bytes, data: bytes) -> bytes:
    chunk_len = struct.pack(">I", len(data))
    to_crc = chunk_type + data
    crc = zlib.crc32(to_crc) & 0xFFFFFFFF
    return chunk_len + chunk_type + data + struct.pack(">I", crc)

def make_png(width: int, height: int) -> bytes:
    signature = b"\x89PNG\r\n\x1a\n"
    ihdr_data = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)  # 8-bit RGB
    ihdr = png_chunk(b"IHDR", ihdr_data)
    # Raw image: each row = filter byte (0) + width * 3 RGB bytes
    raw = []
    for _ in range(height):
        raw.append(0)  # filter
        for _ in range(width):
            raw.extend(FILL)
    raw_bytes = bytes(raw)
    compressed = zlib.compress(raw_bytes, 9)
    idat = png_chunk(b"IDAT", compressed)
    iend = png_chunk(b"IEND", b"")
    return signature + ihdr + idat + iend

# Sizes and filenames from Contents.json (must match exactly)
ICONS = [
    ("Icon-App-20x20@2x.png", 40, 40),
    ("Icon-App-20x20@3x.png", 60, 60),
    ("Icon-App-29x29@2x.png", 58, 58),
    ("Icon-App-29x29@3x.png", 87, 87),
    ("Icon-App-40x40@2x.png", 80, 80),
    ("Icon-App-40x40@3x.png", 120, 120),
    ("Icon-App-60x60@2x.png", 120, 120),  # required 120x120
    ("Icon-App-60x60@3x.png", 180, 180),  # required 180x180
    ("Icon-App-20x20@1x.png", 20, 20),
    ("Icon-App-29x29@1x.png", 29, 29),
    ("Icon-App-40x40@1x.png", 40, 40),
    ("Icon-App-76x76@1x.png", 76, 76),
    ("Icon-App-76x76@2x.png", 152, 152),  # required 152x152
    ("Icon-App-83.5x83.5@2x.png", 167, 167),
    ("Icon-App-1024x1024.png", 1024, 1024),  # App Store required
]

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

def main():
    for filename, w, h in ICONS:
        path = os.path.join(SCRIPT_DIR, filename)
        png = make_png(w, h)
        with open(path, "wb") as f:
            f.write(png)
        print(f"Wrote {filename} ({w}x{h})")
    print("Done. You can now Clean Build (Shift+Cmd+K) and Archive.")

if __name__ == "__main__":
    main()
