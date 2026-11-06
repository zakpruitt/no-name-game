#!/usr/bin/env python3
"""Put a new body (and optionally new weapon meshes) into a hero GLB, leaving the rig and clips alone.

    python tools/hero_build/glb_swap.py <base.glb> <build_dir> <out.glb>

<build_dir> is hero_v2.py's output: body.npz (glTF-space arrays, joints by bone name), palette.npy
(the flat swatch texture) and, when present, weapons.npz (one entry per weapon mesh, same layout,
replacing the GLB's mesh of that name). Every node, the skin (joints and inverse bind matrices) and
every animation are copied unchanged, so clip timings, bone names and rest transforms are exactly the
base's. The body mesh keeps its node name (`heretic`) and its material (P_HereticPaint); its texture
becomes the PNG palette. The binary chunk is repacked so the old body's buffers don't linger.
"""
import io
import json
import struct
import sys

import numpy as np
from PIL import Image

FLOAT, U8, U16, U32 = 5126, 5121, 5123, 5125
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
DT = {FLOAT: np.float32, U8: np.uint8, U16: np.uint16, U32: np.uint32}


def load(path):
    data = open(path, "rb").read()
    magic, version, length = struct.unpack("<4sII", data[:12])
    assert magic == b"glTF" and length == len(data), "not a complete GLB"
    jl = struct.unpack("<I", data[12:16])[0]
    doc = json.loads(data[20:20 + jl])
    bl = struct.unpack("<I", data[20 + jl:24 + jl])[0]
    return doc, data[28 + jl:28 + jl + bl]


def view_bytes(doc, blob, vi):
    bv = doc["bufferViews"][vi]
    o = bv.get("byteOffset", 0)
    return blob[o:o + bv["byteLength"]]


class Packer:
    def __init__(self):
        self.views, self.chunks, self.size = [], [], 0

    def add(self, raw, target=None, stride=None):
        pad = (-self.size) % 4
        if pad:
            self.chunks.append(bytes(pad))
            self.size += pad
        v = {"buffer": 0, "byteOffset": self.size, "byteLength": len(raw)}
        if target:
            v["target"] = target
        if stride:
            v["byteStride"] = stride
        self.views.append(v)
        self.chunks.append(raw)
        self.size += len(raw)
        return len(self.views) - 1


def repack(doc, blob, new_prims):
    """new_prims: mesh index -> (attrs {name: ndarray}, indices ndarray). Returns doc, bin."""
    pk = Packer()
    accessors = []
    view_map = {}

    def old_acc(i):
        a = dict(doc["accessors"][i])
        vi = a["bufferView"]
        if vi not in view_map:
            bv = doc["bufferViews"][vi]
            view_map[vi] = pk.add(view_bytes(doc, blob, vi), bv.get("target"), bv.get("byteStride"))
        a["bufferView"] = view_map[vi]
        accessors.append(a)
        return len(accessors) - 1

    def new_acc(arr, typ, comp, target, minmax=False):
        arr = np.ascontiguousarray(arr.astype(DT[comp]))
        vi = pk.add(arr.tobytes(), target)
        a = {"bufferView": vi, "componentType": comp, "count": int(arr.shape[0]), "type": typ}
        if minmax:
            a["min"] = [float(x) for x in arr.min(axis=0)]
            a["max"] = [float(x) for x in arr.max(axis=0)]
        accessors.append(a)
        return len(accessors) - 1

    for mi, mesh in enumerate(doc["meshes"]):
        for prim in mesh["primitives"]:
            if mi in new_prims:
                attrs, idx = new_prims[mi]
                prim["attributes"] = {
                    "POSITION": new_acc(attrs["pos"], "VEC3", FLOAT, 34962, True),
                    "NORMAL": new_acc(attrs["nrm"], "VEC3", FLOAT, 34962),
                    "TEXCOORD_0": new_acc(attrs["uv"], "VEC2", FLOAT, 34962),
                    "JOINTS_0": new_acc(attrs["joints"], "VEC4", U8 if attrs["joints"].max() < 256 else U16, 34962),
                    "WEIGHTS_0": new_acc(attrs["weights"], "VEC4", FLOAT, 34962),
                }
                if "col" in attrs:
                    prim["attributes"]["COLOR_0"] = new_acc(attrs["col"], "VEC4", FLOAT, 34962)
                comp = U16 if attrs["pos"].shape[0] < 65536 else U32
                prim["indices"] = new_acc(idx.reshape(-1), "SCALAR", comp, 34963)
                prim.pop("targets", None)
            else:
                prim["attributes"] = {k: old_acc(v) for k, v in prim["attributes"].items()}
                if "indices" in prim:
                    prim["indices"] = old_acc(prim["indices"])
    for sk in doc.get("skins", []):
        if "inverseBindMatrices" in sk:
            sk["inverseBindMatrices"] = old_acc(sk["inverseBindMatrices"])
    for an in doc.get("animations", []):
        for s in an["samplers"]:
            s["input"] = old_acc(s["input"])
            s["output"] = old_acc(s["output"])
    for img in doc.get("images", []):
        if "_png" in img:
            img["bufferView"] = pk.add(img.pop("_png"))
        elif "bufferView" in img:
            img["bufferView"] = pk.add(view_bytes(doc, blob, img["bufferView"]))
    doc["accessors"] = accessors
    doc["bufferViews"] = pk.views
    out = b"".join(pk.chunks)
    out += bytes((-len(out)) % 4)
    doc["buffers"] = [{"byteLength": len(out)}]
    return doc, out


def write(path, doc, binary):
    js = json.dumps(doc, separators=(",", ":")).encode()
    js += b" " * ((-len(js)) % 4)
    total = 12 + 8 + len(js) + 8 + len(binary)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<I4s", len(js), b"JSON") + js)
        f.write(struct.pack("<I4s", len(binary), b"BIN\x00") + binary)


def prim_arrays(npz, prefix, joint_index):
    names = npz[prefix + "joints"]
    joints = np.vectorize(joint_index.__getitem__)(names).astype(np.int32)
    return {"pos": npz[prefix + "pos"], "nrm": npz[prefix + "nrm"], "uv": npz[prefix + "uv"],
            "joints": joints, "weights": npz[prefix + "weights"]}, npz[prefix + "idx"]


def main():
    base, build, out = sys.argv[1:4]
    doc, blob = load(base)
    skin = doc["skins"][0]
    joint_index = {doc["nodes"][j]["name"]: k for k, j in enumerate(skin["joints"])}
    mesh_of_node = {n["name"]: n["mesh"] for n in doc["nodes"] if "mesh" in n}
    new = {}
    body = np.load(build + "/body.npz")
    new[mesh_of_node["heretic"]] = prim_arrays(body, "", joint_index)
    try:
        weapons = np.load(build + "/weapons.npz")
    except FileNotFoundError:
        weapons = None
    if weapons is not None:
        for key in weapons.files:
            if key.endswith("|pos"):
                name = key[:-4]
                new[mesh_of_node[name]] = prim_arrays(weapons, name + "|", joint_index)
    # the palette replaces the body's texture (PNG: flat swatches must not pick up JPEG noise)
    pal = np.load(build + "/palette.npy")
    buf = io.BytesIO()
    Image.fromarray(pal).save(buf, "PNG")
    mat = next(m for m in doc["materials"] if m["name"] == "P_HereticPaint")
    tex = doc["textures"][mat["pbrMetallicRoughness"]["baseColorTexture"]["index"]]
    img = doc["images"][tex["source"]]
    img.pop("bufferView", None)
    img["mimeType"] = "image/png"
    img["name"] = "hero_palette"
    img["_png"] = buf.getvalue()
    doc["samplers"][tex.get("sampler", 0)] = {"magFilter": 9728, "minFilter": 9728}  # nearest: swatches stay flat
    doc, binary = repack(doc, blob, new)
    write(out, doc, binary)
    tris = {doc["meshes"][m]["name"]: int(a[1].size // 3) for m, a in new.items()}
    print("[glb_swap] wrote %s (%d bytes), replaced %s" % (out, 12 + len(binary), tris))


if __name__ == "__main__":
    main()
