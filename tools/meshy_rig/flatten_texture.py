# Flattens a Meshy texture into a few readable colour regions for the cut-tone shader:
# k-means in Lab (lightness weighted down, so a lit and a shadowed patch of one cloth land
# in one cluster), a mode filter to drop speckle, then each pixel takes its cluster's colour
# with a little of the original kept for faces and seams. Islands are found from the mesh's
# UVs so no filter bleeds across them, and every island is padded for mipmaps.
#   python tools/meshy_rig/flatten_texture.py <in.png> <uvtris.npy> <out.png> [k] [keep]
# uvtris.npy: (tris, 3, 2) UVs, from heretic_refine.py's dump (or any loop_triangles dump).
import sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

SRC, UVT, OUT = sys.argv[1:4]
K = int(sys.argv[4]) if len(sys.argv) > 4 else 14
KEEP = float(sys.argv[5]) if len(sys.argv) > 5 else 0.2   # how much original detail survives
L_WEIGHT = 0.45   # lightness counts this much against hue when clustering
MODE_R = 4        # mode filter radius in px
PAD = 12          # px of padding round each island
# Per-cluster nudges after clustering: (Lab centre to match, new lightness floor, saturation gain).
# Dark leather sits too close to the indigo floor; lift the darkest clusters a little.
DARK_FLOOR = 24.0

rgb = np.asarray(Image.open(SRC).convert("RGB"), np.float32) / 255.0
H, W = rgb.shape[:2]

def to_lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
def to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)
M = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
WHITE = np.array([0.95047, 1.0, 1.08883])
def lab(c):
    xyz = to_lin(c) @ M.T / WHITE
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)
def unlab(l):
    fy = (l[..., 0] + 16) / 116
    f = np.stack([fy + l[..., 1] / 500, fy, fy - l[..., 2] / 200], -1)
    xyz = np.where(f > 0.2069, f ** 3, (f - 16 / 116) / 7.787) * WHITE
    return to_srgb(xyz @ np.linalg.inv(M).T)

# ---- islands from the UVs
tris = np.load(UVT)
mimg = Image.new("L", (W, H), 0)
d = ImageDraw.Draw(mimg)
for t in tris:
    d.polygon([(u * W, (1 - v) * H) for u, v in t], fill=255)
mask = np.asarray(mimg) > 0
mask = ndimage.binary_dilation(mask, iterations=1)
print("covered %.1f%%" % (mask.mean() * 100))

# ---- cluster
L = lab(rgb)
F = L * np.array([L_WEIGHT, 1, 1])
pts = F[mask]
rng = np.random.default_rng(7)
samp = pts[rng.choice(len(pts), min(150000, len(pts)), replace=False)]
cent = samp[rng.choice(len(samp), K, replace=False)]
for it in range(30):
    lab_ = np.argmin(((samp[:, None, :] - cent[None]) ** 2).sum(-1), 1)
    new = np.array([samp[lab_ == k].mean(0) if (lab_ == k).any() else cent[k] for k in range(K)])
    if np.abs(new - cent).max() < 0.05:
        break
    cent = new
labels = np.full(H * W, -1, np.int32)
flat_idx = np.where(mask.ravel())[0]
for s in range(0, len(flat_idx), 500000):
    p = F.reshape(-1, 3)[flat_idx[s:s + 500000]]
    labels[flat_idx[s:s + 500000]] = np.argmin(((p[:, None, :] - cent[None]) ** 2).sum(-1), 1)
labels = labels.reshape(H, W)

# ---- mode filter inside the islands
size = 2 * MODE_R + 1
votes = np.stack([ndimage.uniform_filter(((labels == k) & mask).astype(np.float32), size) for k in range(K)], -1)
labels = np.where(mask, votes.argmax(-1), -1)

# ---- colours: each cluster's mean in Lab from the original pixels, darkest lifted
Lr = L.reshape(-1, 3); lr = labels.ravel()
col = np.zeros((K, 3))
for k in range(K):
    sel = lr == k
    col[k] = Lr[sel].mean(0) if sel.any() else 0
    print("cluster %2d  %5.1f%%  Lab %s" % (k, sel.mean() * 100, np.round(col[k], 1)))
col[:, 0] = np.maximum(col[:, 0], DARK_FLOOR)
flatlab = np.where(mask[..., None], col[np.clip(labels, 0, K - 1)], 0)
# keep a little of the original's lightness detail (eyes, mouth, seams) but none of its hue noise
flatlab[..., 0] = flatlab[..., 0] * (1 - KEEP) + L[..., 0] * KEEP
out = unlab(flatlab)

# ---- pad islands outward for mipmaps
_, (iy, ix) = ndimage.distance_transform_edt(~mask, return_indices=True)
far = ndimage.distance_transform_edt(~mask)
pad = (far > 0) & (far <= PAD)
out[pad] = out[iy[pad], ix[pad]]
out[~mask & ~pad] = 0
Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8)).save(OUT)
print("SAVED", OUT)
