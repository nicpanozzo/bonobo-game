# Tavola completa e GIF animata di tutte le animazioni
import sys; sys.path.insert(0, '/home/claude/marco2')
import numpy as np
from PIL import Image, ImageDraw
from tavola import section, sheet, font, BG
from anim import SECTIONS

def frames(name):
    return np.load(f'out/frames_{name.replace(" ", "_").replace("(", "").replace(")", "")}.npy').astype(np.float32)

# tavola: stesse righe della tavola generata, più Hit, Shield e Taunt per il gioco
ROWS = [['Idle', 'Walk'], ['Run', 'Dash'], ['Jump', 'Fall'], ['Crouch', 'Grab', 'Pummel'], ['Throw (forward)', 'Throw (back)'],
        ['Up Tilt', 'Side Tilt', 'Down Tilt'], ['Up Smash', 'Side Smash', 'Down Smash'], ['Neutral Air', 'Forward Air', 'Back Air'],
        ['Up Air', 'Down Air', 'Landing', 'Aerial Fall'], ['Final Smash'], ['Hit', 'Shield', 'Taunt']]
secs = {n: section(n, list(frames(n)), gap=2) for n, _ in SECTIONS}
rows = [[secs[n] for n in r] for r in ROWS]
W = max(sum(s.width for s in r) + 24 * (len(r) - 1) for r in rows) + 40
H = sum(max(s.height for s in r) + 22 for r in rows) + 90
out = Image.new('RGBA', (W, H), BG)
d = ImageDraw.Draw(out)
d.text((22, 18), 'Marcomunista — tavola delle animazioni', font=font(26), fill=(25, 25, 30, 255))
d.text((22, 52), 'Dai disegni originali del foglio di Marco (#352): testa sempre identica, corpo animato a pezzi', font=font(14), fill=(110, 115, 125, 255))
y = 84
for r in rows:
    x = 20; hh = max(s.height for s in r)
    for s in r:
        out.alpha_composite(s, (x, y + hh - s.height)); x += s.width + 24
    y += hh + 22
out.convert('RGB').save('out/marcomunista-tavola.png', optimize=True)
print('tavola', out.size)

# GIF: ogni animazione nella sua casella, al suo ritmo
FPS = {'Idle': 8, 'Walk': 12, 'Run': 12, 'Fall': 10, 'Aerial Fall': 12, 'Shield': 8, 'Final Smash': 8}
names = [n for n, _ in SECTIONS]
cols, cw, chh = 7, 220, 176
rowsN = (len(names) + cols - 1) // cols
T = 48  # fotogrammi della GIF, a 24 al secondo
cells = {}
for n in names:
    fr = frames(n)
    al = fr[..., 3].max(0); ys, xs = np.nonzero(al > 8)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    crop = fr[:, y0:y1, x0:x1]
    sc = min((cw - 10) / crop.shape[2], (chh - 30) / crop.shape[1], 0.62)
    ims = [Image.fromarray(f.clip(0, 255).astype(np.uint8)).resize((max(1, round(crop.shape[2] * sc)), max(1, round(crop.shape[1] * sc))), Image.LANCZOS) for f in crop]
    cells[n] = ims
gif = []
F = font(12)
for t in range(T):
    canvas = Image.new('RGBA', (cols * cw, rowsN * chh), BG)
    dd = ImageDraw.Draw(canvas)
    for i, n in enumerate(names):
        cx, cy = (i % cols) * cw, (i // cols) * chh
        ims = cells[n]; fps = FPS.get(n, 12)
        loop = n in ('Idle', 'Walk', 'Run', 'Fall', 'Aerial Fall', 'Shield')
        k = int(t * fps / 24)
        k = k % len(ims) if loop else min(k % (len(ims) + 4), len(ims) - 1)   # i colpi tengono l'ultima posa un attimo
        im = ims[k]
        canvas.alpha_composite(im, (cx + (cw - im.width) // 2, cy + chh - 6 - im.height))
        dd.text((cx + 6, cy + 4), n, font=F, fill=(60, 64, 74, 255))
    gif.append(canvas.convert('RGB').quantize(255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
gif[0].save('out/marcomunista-animazioni.gif', save_all=True, append_images=gif[1:], duration=1000 // 24, loop=0, optimize=True)
print('gif', gif[0].size)
