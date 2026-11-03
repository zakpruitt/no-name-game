# python clip_sheet.py CLIP [cols] [every] [fps]: tiles out/clip/CLIP into out/clip_CLIP.png and writes out/clip_CLIP.gif
import os, sys
from PIL import Image, ImageDraw
HERE = os.path.dirname(os.path.abspath(__file__))
clip = sys.argv[1]; cols = int(sys.argv[2]) if len(sys.argv) > 2 else 6
every = int(sys.argv[3]) if len(sys.argv) > 3 else 3; fps = int(sys.argv[4]) if len(sys.argv) > 4 else 15
d = os.path.join(HERE, 'out', 'clip', clip)
names = sorted(os.listdir(d))
im = [Image.open(os.path.join(d, n)).convert('RGB') for n in names]
pick = list(zip(names, im))[::every]
w, h = im[0].size
rows = (len(pick) + cols - 1) // cols
S = Image.new('RGB', (w * cols, h * rows))
dr = ImageDraw.Draw(S)
for i, (n, m) in enumerate(pick):
    S.paste(m, (i % cols * w, i // cols * h)); dr.text((i % cols * w + 4, i // cols * h + 4), n[:-4], fill=(255, 255, 255))
S.save(os.path.join(HERE, 'out', 'clip_%s.png' % clip))
im[0].save(os.path.join(HERE, 'out', 'clip_%s.gif' % clip), save_all=True, append_images=im[1:], duration=int(1000 / fps), loop=0)
print(S.size, len(im))
