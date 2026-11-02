#!/usr/bin/env python3
"""Copy comic enemy GLBs into assets/comic, moving the `g` attribute to where Godot reads it.

The Blender exports carry two colour attributes: COLOR_0 is a constant white and
COLOR_1 is `g`, which comic_emit.gdshader steps its tones along. Godot's importer
only reads COLOR_0, so each primitive's two accessors are swapped in the JSON chunk.

    python tools/comic_glb.py [src_dir] [name ...]

src_dir defaults to the kit's output in the integration checkout; no names = every
.glb there. Refuses a file whose header length doesn't match (an export mid-write).
Run `godot --headless --import --path .` afterwards.
"""
import json
import os
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_SRC = os.path.join(ROOT, "..", "awaken", "vendor_src", "shaman_redesign", "comic_poc", "out", "enemies")
DEST = os.path.join(ROOT, "assets", "comic")


def convert(data, name):
    magic, version, length = struct.unpack("<4sII", data[:12])
    if magic != b"glTF" or version != 2 or length != len(data):
        raise SystemExit("%s: not a complete GLB (header says %d bytes, file has %d)" % (name, length, len(data)))
    json_len, json_type = struct.unpack("<I4s", data[12:20])
    if json_type != b"JSON":
        raise SystemExit("%s: first chunk isn't JSON" % name)
    doc = json.loads(data[20:20 + json_len])
    swapped = 0
    for mesh in doc.get("meshes", []):
        for prim in mesh["primitives"]:
            attrs = prim["attributes"]
            if "COLOR_1" in attrs:
                attrs["COLOR_0"], attrs["COLOR_1"] = attrs["COLOR_1"], attrs["COLOR_0"]
                swapped += 1
    body = json.dumps(doc, separators=(",", ":")).encode()
    body += b" " * (-len(body) % 4)
    rest = data[20 + json_len:]
    total = 12 + 8 + len(body) + len(rest)
    return struct.pack("<4sII", b"glTF", 2, total) + struct.pack("<I4s", len(body), b"JSON") + body + rest, swapped


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SRC
    names = sys.argv[2:] or sorted(f[:-4] for f in os.listdir(src) if f.endswith(".glb"))
    os.makedirs(DEST, exist_ok=True)
    for name in names:
        with open(os.path.join(src, name + ".glb"), "rb") as f:
            out, swapped = convert(f.read(), name)
        with open(os.path.join(DEST, name + ".glb"), "wb") as f:
            f.write(out)
        print("%-12s %8d bytes, %d primitives swapped" % (name, len(out), swapped))


if __name__ == "__main__":
    main()
