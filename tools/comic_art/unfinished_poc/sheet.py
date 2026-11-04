# Tiles the blockout's cells: current above, new below. 1:1 pixels are the game's real size at 1080p.
import os
from PIL import Image, ImageDraw
D = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out')
C = os.path.join(D, 'cells')
N = ['idle_front', 'idle_34', 'idle_back', 'run_side', 'run_away', 'ready', 'chop', 'spin']
w, h = Image.open(os.path.join(C, 'cur_idle_front.png')).size
def sheet(names, rows, out):
    S = Image.new('RGB', (w * len(names), (h + 18) * len(rows)), (0, 0, 0)); dr = ImageDraw.Draw(S)
    for r, (label, pre, suf) in enumerate(rows):
        for c, n in enumerate(names):
            S.paste(Image.open(os.path.join(C, '%s_%s%s.png' % (pre, n, suf))).convert('RGB'), (c * w, r * (h + 18) + 18))
            dr.text((c * w + 4, r * (h + 18) + 4), '%s  %s' % (label, n), fill=(255, 255, 255))
    S.save(os.path.join(D, out)); print(out, S.size)
T = [('CURRENT', 'cur', ''), ('NEW', 'new', '')]
K = [('CURRENT', 'cur', '_black'), ('NEW', 'new', '_black')]
for tag, names in (('a', N[:3]), ('b', N[3:6]), ('c', N[6:])):
    sheet(names, T, 'sheet_%s.png' % tag)
    sheet(names, K, 'sheet_black_%s.png' % tag)
# the real read: three cells at game size, then 3x with hard pixels, to judge the design rather than the render
Z = Image.open(os.path.join(C, 'new_idle_front.png')).convert('RGB')
b = (w // 2 - 170, h // 2 - 150, w // 2 + 170, h // 2 + 150)
Y = Image.new('RGB', (340 * 3 * 2 + 10, 300 * 3), (0, 0, 0))
Y.paste(Image.open(os.path.join(C, 'cur_idle_front.png')).convert('RGB').crop(b).resize((1020, 900), Image.NEAREST), (0, 0))
Y.paste(Z.crop(b).resize((1020, 900), Image.NEAREST), (1030, 0))
Y.save(os.path.join(D, 'zoom_front.png'))
