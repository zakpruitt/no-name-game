#!/usr/bin/env python3
"""Copy comic enemy GLBs into assets/comic, moving the `g` attribute to where Godot reads it.

The Blender exports carry two colour attributes: COLOR_0 is a constant white and
COLOR_1 is `g`, which comic_emit.gdshader steps its tones along. Godot's importer
only reads COLOR_0, so each primitive's two accessors are swapped in the JSON chunk.

    python tools/comic_glb.py [--env] [src_dir] [name ...]

src_dir defaults to the kit's output in the integration checkout; no names = every
.glb there. --env takes the dungeon pieces (out/env -> assets/comic/dungeon); those
already export `g` as their only colour attribute, so nothing needs swapping.
A mesh node named like a joint is renamed <name>_mesh: Godot's importer keeps node
names unique and gives the clash to the joint, so the hero's `head` bone arrived as
`head_2` and every attachment to it silently failed.
Refuses a file whose header length doesn't match (an export mid-write).
Run `godot --headless --import --path .` afterwards.
"""
import json
import os
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KIT_OUT = os.path.join(ROOT, "..", "awaken", "vendor_src", "shaman_redesign", "comic_poc", "out")


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
    joints = {i for skin in doc.get("skins", []) for i in skin["joints"]}
    joint_names = {doc["nodes"][i].get("name") for i in joints}
    for i, node in enumerate(doc.get("nodes", [])):
        if i not in joints and node.get("name") in joint_names:
            node["name"] += "_mesh"
    body = json.dumps(doc, separators=(",", ":")).encode()
    body += b" " * (-len(body) % 4)
    rest = data[20 + json_len:]
    total = 12 + 8 + len(body) + len(rest)
    return struct.pack("<4sII", b"glTF", 2, total) + struct.pack("<I4s", len(body), b"JSON") + body + rest, swapped


def main():
    args = sys.argv[1:]
    env = "--env" in args
    if env:
        args.remove("--env")
    src = args[0] if args else os.path.join(KIT_OUT, "env" if env else "enemies")
    dest = os.path.join(ROOT, "assets", "comic", "dungeon") if env else os.path.join(ROOT, "assets", "comic")
    names = args[1:] or sorted(f[:-4] for f in os.listdir(src) if f.endswith(".glb"))
    os.makedirs(dest, exist_ok=True)
    for name in names:
        with open(os.path.join(src, name + ".glb"), "rb") as f:
            out, swapped = convert(f.read(), name)
        with open(os.path.join(dest, name + ".glb"), "wb") as f:
            f.write(out)
        print("%-12s %8d bytes, %d primitives swapped" % (name, len(out), swapped))


if __name__ == "__main__":
    main()
