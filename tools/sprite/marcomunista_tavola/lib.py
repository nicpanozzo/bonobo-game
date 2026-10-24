# Strumenti per animare Marco a pezzi partendo dai disegni originali (pose del foglio #352).
import numpy as np, cv2, json
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

SRC = '/home/claude/marco2/src'
FW, FH, FOOT = 304, 196, 182          # fotogramma dei disegni originali, piedi a 182
OUTLINE = np.array([214, 222, 233.])  # il contorno chiaro dei disegni originali

def load_raw(name, k=0):
    im = Image.open(f'{SRC}/{name}.png').convert('RGBA')
    return np.asarray(im.crop((k * FW, 0, k * FW + FW, FH)), np.float32)

def strip(rgba):
    """Toglie il contorno chiaro: tutto quello di chiaro e grigio raggiungibile da fuori senza passare dall'inchiostro."""
    a = rgba[..., 3]; c = rgba[..., :3]
    mn, mx = c.min(-1), c.max(-1)
    light = (mn > 150) & ((mx - mn) < 40)
    soft = a < 250
    cand = (a < 8) | ((light | (soft & (mn > 90))) & (a > 0))
    lab, _ = ndi.label(cand)
    outside = np.isin(lab, np.unique(lab[a < 8]))
    out = rgba.copy()
    out[outside] = 0
    # bordo: i pixel d'inchiostro semitrasparenti restano (antialias del tratto nero)
    return out

def load(name, k=0):
    return strip(load_raw(name, k))

def to_img(rgba):
    return Image.fromarray(np.clip(rgba, 0, 255).round().astype(np.uint8), 'RGBA')

def grid_view(rgba, path, step=10, z=4, box=None):
    a = rgba[..., 3]
    ys, xs = np.nonzero(a > 8)
    if box is None: box = (max(0, xs.min() - 6), max(0, ys.min() - 6), min(FW, xs.max() + 7), min(FH, ys.max() + 7))
    x0, y0, x1, y1 = box
    crop = to_img(rgba).crop(box)
    bg = Image.new('RGBA', crop.size, (90, 90, 105, 255)); bg.alpha_composite(crop)
    big = bg.resize((crop.width * z, crop.height * z), Image.NEAREST)
    d = ImageDraw.Draw(big)
    for x in range((x0 // step + 1) * step, x1, step):
        X = (x - x0) * z; d.line([(X, 0), (X, big.height)], fill=(0, 255, 255, 110) if x % 50 else (255, 60, 60, 200))
        d.text((X + 2, 2), str(x), fill=(0, 255, 255))
    for y in range((y0 // step + 1) * step, y1, step):
        Y = (y - y0) * z; d.line([(0, Y), (big.width, Y)], fill=(0, 255, 255, 110) if y % 50 else (255, 60, 60, 200))
        d.text((2, Y + 2), str(y), fill=(0, 255, 255))
    big.save(path)
