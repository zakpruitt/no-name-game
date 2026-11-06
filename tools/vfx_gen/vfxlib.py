"""Drawing kit for Awaken's designed effects (round 43, docs/features/designed-fx.md).

Every frame is painted at SS x its size with Pillow polygons (anti-aliased by the box downsample) into three
float planes, then packed into one RGBA sheet the Godot shaders read:

    R  tone     0 ink, 0.25 deep, 0.5 body, 0.75 light, 1.0 hot: the shader maps it through the element's five
                tones (fx_palette.gd), so one drawing serves every element and the cel bands stay hard.
    G  erode    the order the shape dissolves in (low goes first): the shader's `erode` threshold eats it with an
                ink (or hot) burn line at the edge.
    B  boil     0..1 noise the shader can use to wobble the burn edge between frames (unused by most sheets).
    A  cover    the silhouette.

Shapes are layered painter-style; `Frame.fill(mask, tone, ink=w)` lays a w px ink rim round the shape first,
so each shape is inked over what is beneath it, the way an inker draws overlaps.
"""
import math

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

INK, DEEP, BODY, LIGHT, HOT = 0.0, 0.25, 0.5, 0.75, 1.0
SS = 4  # supersampling


def rng(seed):
    return np.random.default_rng(seed)


def fbm(shape, seed, scales=(32, 12, 5), weights=(0.6, 0.3, 0.1)):
    """Smooth 0..1 noise (sum of blurred white noise)."""
    r = rng(seed)
    out = np.zeros(shape, np.float32)
    for s, w in zip(scales, weights):
        n = ndimage.gaussian_filter(r.random(shape).astype(np.float32), s, mode="wrap")
        n = (n - n.min()) / max(1e-6, n.max() - n.min())
        out += n * w
    return (out - out.min()) / max(1e-6, out.max() - out.min())


# --- curves ---------------------------------------------------------------------------------------------------

def catmull(points, n=8, closed=False):
    """Smooth a polyline through `points` (Catmull-Rom)."""
    p = [np.asarray(q, np.float64) for q in points]
    if len(p) < 3:
        return np.array(p)
    if closed:
        p = [p[-1]] + p + [p[0], p[1]]
    else:
        p = [p[0] * 2 - p[1]] + p + [p[-1] * 2 - p[-2]]
    out = []
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = p[i - 1], p[i], p[i + 1], p[i + 2]
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    if not closed:
        out.append(p[-2])
    return np.array(out)


def wobble_ring(cx, cy, r, seed, amp=0.12, lumps=(3, 5, 9), n=96, squash=1.0, rot=0.0):
    """A closed lumpy outline: r(a) = r (1 + sum amp_k sin(k a + phase))."""
    g = rng(seed)
    ph = g.random(len(lumps)) * math.tau
    am = amp * (0.5 + g.random(len(lumps))) / len(lumps) * 2.0
    pts = []
    for i in range(n):
        a = math.tau * i / n
        k = 1.0 + sum(am[j] * math.sin(lumps[j] * a + ph[j]) for j in range(len(lumps)))
        x, y = math.cos(a) * r * k, math.sin(a) * r * k * squash
        pts.append((cx + x * math.cos(rot) - y * math.sin(rot), cy + x * math.sin(rot) + y * math.cos(rot)))
    return pts


def star(cx, cy, tips, r_in, rot=0.0, bow=0.35, n_edge=6):
    """An impact star with concave (bowed-in) sides. `tips` is a list of tip radii, one per spike, so spikes
    can differ; the valleys sit at r_in. bow 0 = straight sides, 0.5 = deeply curved in."""
    k = len(tips)
    pts = []
    for i in range(k):
        a_tip = rot + math.tau * i / k
        a_val = a_tip + math.pi / k
        a_next = rot + math.tau * (i + 1) / k
        tip = np.array([math.cos(a_tip), math.sin(a_tip)]) * tips[i]
        val = np.array([math.cos(a_val), math.sin(a_val)]) * r_in
        tip2 = np.array([math.cos(a_next), math.sin(a_next)]) * tips[(i + 1) % k]
        for a, b in ((tip, val), (val, tip2)):
            ctrl = (a + b) * 0.5 * (1.0 - bow)  # pulled toward the centre: concave
            for s in range(n_edge):
                t = s / n_edge
                q = (1 - t) ** 2 * a + 2 * (1 - t) * t * ctrl + t * t * b
                pts.append((cx + q[0], cy + q[1]))
    return pts


def stroke(path, widths, cap=True):
    """Polygon round a polyline, width per point (list or callable of 0..1). Tapered ends come from the widths;
    `cap` rounds the ends that are still wide."""
    p = np.asarray(path, np.float64)
    m = len(p)
    if callable(widths):
        w = np.array([widths(i / max(1, m - 1)) for i in range(m)])
    else:
        w = np.interp(np.linspace(0, 1, m), np.linspace(0, 1, len(widths)), widths)
    d = np.gradient(p, axis=0)
    d /= np.maximum(1e-6, np.linalg.norm(d, axis=1))[:, None]
    nrm = np.stack([-d[:, 1], d[:, 0]], 1)
    left = p + nrm * (w[:, None] * 0.5)
    right = p - nrm * (w[:, None] * 0.5)
    pts = list(map(tuple, left))
    if cap and w[-1] > 1.0:
        a0 = math.atan2(nrm[-1, 1], nrm[-1, 0])
        for s in range(1, 8):
            a = a0 - math.pi * s / 8
            pts.append((p[-1, 0] + math.cos(a) * w[-1] * 0.5, p[-1, 1] + math.sin(a) * w[-1] * 0.5))
    pts += list(map(tuple, right[::-1]))
    if cap and w[0] > 1.0:
        a0 = math.atan2(-nrm[0, 1], -nrm[0, 0])
        for s in range(1, 8):
            a = a0 - math.pi * s / 8
            pts.append((p[0, 0] + math.cos(a) * w[0] * 0.5, p[0, 1] + math.sin(a) * w[0] * 0.5))
    return pts


def jag_path(a, b, seg, jag, seed, keep_ends=True):
    """A lightning zigzag from a to b: segments of about `seg`, each corner pushed sideways by up to jag*seg."""
    g = rng(seed)
    a, b = np.asarray(a, float), np.asarray(b, float)
    L = np.linalg.norm(b - a)
    d = (b - a) / L
    nrm = np.array([-d[1], d[0]])
    # uneven steps (0.45-1.6 x seg), sides mostly alternating, amplitudes from small kinks to big elbows
    ts = [0.0]
    while ts[-1] < L:
        ts.append(ts[-1] + seg * (0.45 + 1.15 * g.random() ** 1.5))
    ts = np.array(ts[1:-1]) / L
    pts = [a]
    side = 1.0
    for t in ts:
        if t > 0.97:
            break
        side = -side if g.random() < 0.72 else side
        amp = (0.15 + 0.85 * g.random() ** 0.7) * jag * seg
        pts.append(a + (b - a) * t + nrm * side * amp)
    pts.append(b)
    return np.array(pts)


def poly_mask(polys, S):
    im = Image.new("L", (S, S), 0)
    dr = ImageDraw.Draw(im)
    for poly in polys:
        if len(poly) >= 3:
            dr.polygon([(float(x), float(y)) for x, y in poly], fill=255)
    return np.asarray(im, np.float32) / 255.0


def ellipse_mask(cx, cy, rx, ry, S):
    im = Image.new("L", (S, S), 0)
    ImageDraw.Draw(im).ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=255)
    return np.asarray(im, np.float32) / 255.0


def grow(mask, px):
    """The mask pushed out by px (supersampled px): for ink rims."""
    if px <= 0:
        return mask
    inside = mask > 0.5
    d = ndimage.distance_transform_edt(~inside)
    return np.clip(px + 0.5 - d, 0.0, 1.0).astype(np.float32) if True else None


def shrink(mask, px):
    inside = mask > 0.5
    d = ndimage.distance_transform_edt(inside)
    return np.clip(d - px + 0.5, 0.0, 1.0).astype(np.float32)


class Frame:
    """One frame being painted at size*SS."""

    def __init__(self, size):
        self.size = size
        self.S = size * SS
        self.tone = np.zeros((self.S, self.S), np.float32)
        self.alpha = np.zeros((self.S, self.S), np.float32)
        self.order = None  # optional authored erode order (S x S, 0..1)

    @property
    def c(self):
        return self.S / 2.0

    def u(self, v):
        """Frame units (1.0 = half the frame) to supersampled px."""
        return v * self.S / 2.0

    def fill(self, mask, tone, ink=0.0, alpha=1.0):
        """Paint `mask` in `tone` (a value or an S x S array), inked by `ink` px (output px) first."""
        if ink > 0:
            rim = grow(mask, ink * SS)
            self.tone = self.tone * (1 - rim) + INK * rim
            self.alpha = np.maximum(self.alpha, rim * alpha)
        self.tone = self.tone * (1 - mask) + tone * mask
        self.alpha = np.maximum(self.alpha, mask * alpha)

    def poly(self, polys, tone, ink=0.0):
        m = poly_mask(polys if isinstance(polys[0][0], (tuple, list, np.ndarray)) and len(np.shape(polys[0])) == 2 else [polys], self.S)
        self.fill(m, tone, ink)
        return m

    def cut(self, mask):
        """Erase (negative space)."""
        self.alpha *= 1.0 - mask

    def line(self, path, width, tone=INK, taper=(1.0, 1.0)):
        w = width * SS
        m = poly_mask([stroke(path, [w * taper[0], w, w * taper[1]])], self.S)
        self.fill(m, tone)
        return m

    def finish(self):
        """Downsample to (tone, alpha) at output size, tone un-premultiplied and bled into clear pixels."""
        s = self.size
        a = self.alpha.reshape(s, SS, s, SS).mean(axis=(1, 3))
        t = (self.tone * self.alpha).reshape(s, SS, s, SS).mean(axis=(1, 3))
        tone = np.where(a > 1e-4, t / np.maximum(a, 1e-4), 0.0)
        # bleed tone into transparent texels so bilinear filtering at the rim never pulls in black
        empty = a < 0.02
        if empty.any() and (~empty).any():
            idx = ndimage.distance_transform_edt(empty, return_distances=False, return_indices=True)
            tone = tone[idx[0], idx[1]]
        order = None
        if self.order is not None:
            order = self.order.reshape(s, SS, s, SS).mean(axis=(1, 3))
        return np.clip(tone, 0, 1), np.clip(a, 0, 1), order


def erode_field(alpha, seed, mode="edge", noise_w=0.55, scale=1.0, center=None, order=None):
    """G channel: low = dissolves first. 'edge' eats from the outline inward in clumps, 'center' hollows the
    middle out first (impact stars), 'tail' runs along x (strokes: the left end goes first)."""
    s = alpha.shape[0]
    n = fbm(alpha.shape, seed, scales=(max(2, int(10 * scale * s / 256)), max(1, int(4 * scale * s / 256)), 1.5),
            weights=(0.6, 0.3, 0.1))
    if mode == "edge":
        d = ndimage.distance_transform_edt(alpha > 0.35)
        base = d / max(1.0, d.max())
        base = np.sqrt(base)
    elif mode == "center":
        cy, cx = center if center is not None else (s / 2, s / 2)
        yy, xx = np.mgrid[0:s, 0:s]
        r = np.hypot(xx - cx, yy - cy)
        base = r / max(1.0, r[alpha > 0.05].max() if (alpha > 0.05).any() else s / 2)
    elif mode == "tail":
        base = np.tile(np.linspace(0, 1, s), (s, 1))
    else:
        base = np.zeros_like(alpha)
    if order is not None:
        base = order
    g = base * (1 - noise_w) + n * noise_w
    g = (g - g[alpha > 0.05].min()) / max(1e-4, g[alpha > 0.05].max() - g[alpha > 0.05].min()) if (alpha > 0.05).any() else g
    return np.clip(g * 0.96 + 0.03, 0, 1)


def pack(frames, cols, seed=1, mode="edge", noise_w=0.55, scale=1.0, erode=None):
    """[(tone, alpha, order)] -> RGBA uint8 sheet, `cols` frames a row, row 0 at the top."""
    s = frames[0][0].shape[0]
    rows = math.ceil(len(frames) / cols)
    sheet = np.zeros((rows * s, cols * s, 4), np.float32)
    boil = fbm((s, s), seed + 99, scales=(6, 2, 1))
    for i, (tone, alpha, order) in enumerate(frames):
        r, c = divmod(i, cols)
        g = erode[i] if erode is not None else erode_field(alpha, seed + i * 7, mode, noise_w, scale, order=order)
        sheet[r * s:(r + 1) * s, c * s:(c + 1) * s] = np.stack([tone, g, boil, alpha], -1)
    return (np.clip(sheet, 0, 1) * 255 + 0.5).astype(np.uint8)


def save(sheet, path):
    Image.fromarray(sheet, "RGBA").save(path, optimize=True)


# --- preview (what the shader does, for reading sheets without Godot) -----------------------------------------

PALETTES = {
    "hit": [(0.06, 0.02, 0.02), (0.85, 0.22, 0.03), (1.0, 0.5, 0.08), (1.0, 0.86, 0.32), (1.0, 0.97, 0.82)],
    "earth": [(0.09, 0.02, 0.02), (0.62, 0.12, 0.02), (1.0, 0.38, 0.05), (1.0, 0.76, 0.28), (1.0, 0.95, 0.72)],
    "water": [(0.02, 0.04, 0.12), (0.12, 0.36, 0.78), (0.42, 0.78, 1.0), (0.88, 0.97, 1.0), (1.0, 1.0, 1.0)],
    "wind": [(0.02, 0.07, 0.05), (0.04, 0.42, 0.26), (0.18, 0.86, 0.46), (0.82, 1.0, 0.76), (1.0, 1.0, 0.9)],
    "void": [(0.03, 0.01, 0.06), (0.3, 0.1, 0.56), (0.62, 0.3, 1.0), (1.0, 0.52, 0.95), (1.0, 0.86, 1.0)],
    "boltA": [(0.04, 0.06, 0.0), (0.3, 0.55, 0.02), (0.72, 1.0, 0.14), (0.94, 1.0, 0.6), (1.0, 1.0, 0.94)],
    "boltB": [(0.08, 0.05, 0.0), (0.72, 0.45, 0.0), (1.0, 0.86, 0.12), (1.0, 0.97, 0.62), (1.0, 1.0, 0.96)],
    "air": [(0.06, 0.1, 0.16), (0.45, 0.62, 0.72), (0.8, 0.93, 0.95), (0.95, 1.0, 0.98), (1.0, 1.0, 1.0)],
    "dust": [(0.08, 0.04, 0.06), (0.55, 0.47, 0.42), (0.78, 0.7, 0.6), (0.95, 0.9, 0.8), (1.0, 0.98, 0.92)],
    "gold": [(0.08, 0.04, 0.01), (0.82, 0.48, 0.08), (1.0, 0.78, 0.3), (1.0, 0.93, 0.66), (1.0, 1.0, 0.9)],
}
FLOOR = (0.24, 0.22, 0.36)


def ramp(tone, pal):
    p = np.array(PALETTES[pal], np.float32)
    x = np.clip(tone, 0, 1) * 4.0
    c = np.broadcast_to(p[0], tone.shape + (3,)).copy()
    for k in range(1, 5):
        s = np.clip((x - (k - 0.5)) * 4.0 + 0.5, 0, 1)[..., None]
        c = c * (1 - s) + p[k] * s
    return c


def preview(sheet, pal, erode_steps=(0.0,), bg=FLOOR):
    """The sheet as the shader draws it on the floor colour; one band per erode value."""
    f = sheet.astype(np.float32) / 255.0
    tone, g, a = f[..., 0], f[..., 1], f[..., 3]
    out = []
    for e in erode_steps:
        keep = np.clip((g - e) / 0.03 + 0.5, 0, 1) if e > 0 else np.ones_like(g)
        burn = (1 - np.clip((g - e) / 0.05, 0, 1)) * (e > 0)
        col = ramp(tone, pal)
        col = col * (1 - burn[..., None]) + np.array(PALETTES[pal][0]) * burn[..., None]
        aa = (a * keep)[..., None]
        out.append(col * aa + np.array(bg) * (1 - aa))
    img = np.concatenate(out, 0)
    return Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), "RGB")
