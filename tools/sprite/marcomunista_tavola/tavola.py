import sys, numpy as np
sys.path.insert(0, '/home/claude/marco2')
from PIL import Image, ImageDraw, ImageFont
from lib import to_img

BG = (247, 250, 249, 255)
def font(sz):
    for f in ['/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', '/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf']:
        try: return ImageFont.truetype(f, sz)
        except OSError: pass
    return ImageFont.load_default()

def trimmed(frames, pad=6):
    al = np.max([f[..., 3] for f in frames], 0)
    ys, xs = np.nonzero(al > 8)
    y0, y1, x0, x1 = max(0, ys.min() - pad), ys.max() + pad, max(0, xs.min() - pad), xs.max() + pad
    return [to_img(f[y0:y1, x0:x1]) for f in frames], (y1 - 182)  # distanza fra i piedi e il fondo

def section(name, frames, gap=4, scale=1.0):
    ims, below = trimmed(frames)
    if scale != 1: ims = [i.resize((round(i.width * scale), round(i.height * scale)), Image.LANCZOS) for i in ims]
    w = sum(i.width for i in ims) + gap * (len(ims) - 1)
    h = max(i.height for i in ims)
    F = font(15)
    lw = int(F.getlength(name)) + 16
    W = max(w, lw + 40) + 8
    sec = Image.new('RGBA', (W, h + 34), BG)
    d = ImageDraw.Draw(sec)
    d.rounded_rectangle((2, 2, lw + 2, 26), 6, fill=(225, 229, 238, 255))
    d.text((10, 5), name, font=F, fill=(25, 25, 30, 255))
    d.line((lw + 10, 15, W - 4, 15), fill=(205, 210, 222, 255), width=1)
    x = 4
    for i in ims:
        sec.alpha_composite(i, (x, 34 + h - i.height)); x += i.width + gap
    return sec

def sheet(sections, width=1700, path='out/tavola.png'):
    rows, row, rw = [], [], 0
    for s in sections:
        if row and rw + s.width > width:
            rows.append(row); row, rw = [], 0
        row.append(s); rw += s.width + 20
    if row: rows.append(row)
    H = sum(max(s.height for s in r) + 18 for r in rows) + 20
    W = max(sum(s.width + 20 for s in r) for r in rows) + 20
    out = Image.new('RGBA', (W, H), BG)
    y = 14
    for r in rows:
        x = 14; hh = max(s.height for s in r)
        for s in r:
            out.alpha_composite(s, (x, y + hh - s.height)); x += s.width + 20
        y += hh + 18
    out.convert('RGB').save(path)
    return out
