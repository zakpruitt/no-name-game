#!/usr/bin/env python3
"""Retime one clip inside a hero GLB without Blender: drop some of its drawings and move the rest, in place.

    python tools/meshy_rig/clip_warp.py <in.glb> <out.glb> <clip> <old:new,...> [--drop=f,f,...] [--fps=30] [--linear]

Round 51 (fluidity lane): the chibi's clips are keyed by chibi_keys.py over a blend that is not on every machine
(the p2 passes' blend), so a timing re-key of one clip is done on the exported GLB instead, and the same keys are
written back into chibi_keys.py so the next full re-key reproduces it.

`old:new` pairs are drawing starts (frames at `fps`, as chibi_keys.py numbers them: the first key is frame 1).
chibi_keys.py exports each drawing as a key on its first frame plus a hold key on the frame before the next drawing,
so every key is a drawing start or a hold end:
  - a key on a listed start moves to its new frame;
  - a key on a `--drop` start (and the hold key that ends it) is removed: the drawing before it holds on to the next
    kept one;
  - a hold end (the frame before a start) moves to one frame before the next kept start;
  - any other key between two anchors is moved linearly between them (`--linear` does that for every key: the
    round-28 heretic's per-frame baked clips);
    past the last anchor every key shifts by that anchor's offset.
Every channel's input accessor is rebuilt (with its min / max); outputs are kept, minus the dropped keys. Only the
named animation changes; every other byte of the JSON and the binary is copied through.
"""
import json
import struct
import sys

FLOAT = 5126


def load(path):
    data = open(path, "rb").read()
    magic, _version, length = struct.unpack("<4sII", data[:12])
    assert magic == b"glTF" and length == len(data), "not a complete GLB"
    jl = struct.unpack("<I", data[12:16])[0]
    doc = json.loads(data[20:20 + jl])
    bl = struct.unpack("<I", data[20 + jl:24 + jl])[0]
    return doc, bytearray(data[28 + jl:28 + jl + bl])


def save(path, doc, blob):
    while len(blob) % 4:
        blob.append(0)
    doc["buffers"][0]["byteLength"] = len(blob)
    js = json.dumps(doc, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    out = struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(js) + 8 + len(blob))
    out += struct.pack("<I4s", len(js), b"JSON") + js + struct.pack("<I4s", len(blob), b"BIN\0") + bytes(blob)
    open(path, "wb").write(out)


NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read(doc, blob, ai):
    a = doc["accessors"][ai]
    bv = doc["bufferViews"][a["bufferView"]]
    assert a["componentType"] == FLOAT and "byteStride" not in bv, "float, tightly packed accessors only"
    n = NCOMP[a["type"]]
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    flat = struct.unpack_from("<%df" % (a["count"] * n), blob, off)
    return [flat[i * n:(i + 1) * n] for i in range(a["count"])], a["type"]


def append(doc, blob, rows, kind, minmax=False):
    while len(blob) % 4:
        blob.append(0)
    flat = [v for r in rows for v in r]
    off = len(blob)
    blob.extend(struct.pack("<%df" % len(flat), *flat))
    doc["bufferViews"].append({"buffer": 0, "byteOffset": off, "byteLength": 4 * len(flat)})
    acc = {"bufferView": len(doc["bufferViews"]) - 1, "componentType": FLOAT, "count": len(rows), "type": kind}
    if minmax:
        acc["min"] = [min(r[i] for r in rows) for i in range(len(rows[0]))]
        acc["max"] = [max(r[i] for r in rows) for i in range(len(rows[0]))]
    doc["accessors"].append(acc)
    return len(doc["accessors"]) - 1


def warp_frame(f, anchors, drops, linear=False):
    """New frame for a key at old frame f, or None to drop it (see the module doc)."""
    keys = sorted(anchors)
    if not linear and f < keys[-1] and abs(f - round(f)) < 1e-3:
        f = round(f)
        starts = sorted(set(keys) | set(drops))
        if f in drops:
            return None
        if f in anchors:
            return float(anchors[f])
        own = max(s for s in starts if s <= f)  # the drawing this key belongs to
        if own in drops:
            return None
        if f + 1 in starts:  # its hold end: up to the next kept drawing
            return float(anchors[min(k for k in keys if k > f)] - 1)
    if f >= keys[-1]:
        return f + anchors[keys[-1]] - keys[-1]
    if f <= keys[0]:
        return f + anchors[keys[0]] - keys[0]
    for a, b in zip(keys, keys[1:]):
        if a <= f <= b:
            return anchors[a] + (f - a) * (anchors[b] - anchors[a]) / (b - a)
    return f


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict((a[2:] + "=").split("=")[:2] for a in sys.argv[1:] if a.startswith("--"))
    src, dst, clip, pairs = args
    fps = float(opts.get("fps", 30))
    drops = {int(x) for x in opts.get("drop", "").split(",") if x}
    anchors = {int(a): int(b) for a, b in (p.split(":") for p in pairs.split(","))}
    doc, blob = load(src)
    anim = next(a for a in doc["animations"] if a["name"] == clip)
    done = {}
    for s in anim["samplers"]:
        key = (s["input"], s["output"])
        if key in done:
            s["input"], s["output"] = done[key]
            continue
        times, _ = read(doc, blob, s["input"])
        vals, kind = read(doc, blob, s["output"])
        per = len(vals) // len(times)  # (CUBICSPLINE stores 3 per key)
        new_t, new_v = [], []
        for i, (t,) in enumerate(times):
            nf = warp_frame(t * fps, anchors, drops, "linear" in opts)
            if nf is None:
                continue
            if new_t and nf / fps <= new_t[-1][0]:
                nf = new_t[-1][0] * fps + 0.01  # keep times strictly increasing
            new_t.append((nf / fps,))
            new_v.extend(vals[i * per:(i + 1) * per])
        done[key] = (append(doc, blob, new_t, "SCALAR", True), append(doc, blob, new_v, kind))
        s["input"], s["output"] = done[key]
    last = max(doc["accessors"][s["input"]]["max"][0] for s in anim["samplers"])
    save(dst, doc, blob)
    print("[warp] %s: %d samplers, now %.2f frames long (%.3f s)" % (clip, len(anim["samplers"]), last * fps, last))


if __name__ == "__main__":
    main()
