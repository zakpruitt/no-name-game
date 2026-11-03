# Tiles the close cells, and reports how much of the hero's body glows at game size (the plan allows about 8%).
import os
from PIL import Image
D = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out')
N = ['front', 'back', 'left', 'run', 'chop', 'spin']
S = Image.new('RGB', (620 * 3, 620 * 2))
for i, n in enumerate(N):
    S.paste(Image.open(os.path.join(D, 'close', n + '.png')).convert('RGB'), (i % 3 * 620, i // 3 * 620))
S.save(os.path.join(D, 'closeup.png'))
for cell in ('idle_front', 'idle_34', 'idle_back', 'run_side'):
    col = Image.open(os.path.join(D, 'cells', 'new_%s.png' % cell)).convert('RGB')
    blk = Image.open(os.path.join(D, 'cells', 'new_%s_black.png' % cell)).convert('L')
    sil = glow = 0
    for c, k in zip(col.getdata(), blk.getdata()):
        if k < 128:
            sil += 1
            if c[1] > 170 and c[2] > 140 and c[0] < 190: glow += 1
    print(cell, 'silhouette px', sil, 'glow px', glow, '%.1f%%' % (100 * glow / sil))
