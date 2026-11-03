# Effetti disegnati col codice nello stile dei disegni originali: tratto nero, colori pieni, rosa di Marco.
# Coordinate a 1x nel fotogramma originale (304x196, piedi a 182); si disegnano a 2x come il personaggio.
import math, random, numpy as np, cv2
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage as ndi
from engine import Z, PX, PT, CW, CH, over

S = 4                               # sovracampionamento del disegno (rispetto a 1x)
INK = (14, 12, 14, 255)
PINK = (255, 58, 170, 255)
PINK_L = (255, 170, 220, 255)
WHITE = (255, 255, 255, 255)
CLOUD = (240, 238, 232, 255)
CLOUD_S = (205, 205, 210, 255)
GOLD = (255, 205, 40)

def _canvas():
    return Image.new('RGBA', (CW * S, CH * S), (0, 0, 0, 0))

def _p(x, y):
    return ((x + PX) * S, (y + PT) * S)

def _to2x(im):
    return np.asarray(im.resize((CW * Z, CH * Z), Image.LANCZOS), np.float32)

def empty():
    return np.zeros((CH * Z, CW * Z, 4), np.float32)

def stack(*layers):
    out = empty()
    for l in layers:
        if l is not None: out = over(out, l)
    return out

def speed_lines(lines, w=1.6, color=INK):
    """Linee di velocità affusolate: (x0, y0, x1, y1), spesse in x1."""
    im = _canvas(); d = ImageDraw.Draw(im)
    for x0, y0, x1, y1 in lines:
        dx, dy = x1 - x0, y1 - y0; L = math.hypot(dx, dy) or 1
        nx, ny = -dy / L, dx / L
        pts = [_p(x0, y0), _p(x1 + nx * w, y1 + ny * w), _p(x1 + dx / L * w, y1 + dy / L * w), _p(x1 - nx * w, y1 - ny * w)]
        d.polygon(pts, fill=color)
    return _to2x(im)

def dust(puffs, ink=1.3):
    """Nuvolette di polvere: (x, y, r). Inchiostro fuori, bianco sporco dentro, ombra sotto."""
    im = _canvas(); d = ImageDraw.Draw(im)
    for x, y, r in puffs:
        R = r + ink
        d.ellipse([_p(x - R, y - R), _p(x + R, y + R)], fill=INK)
    for x, y, r in puffs:
        d.ellipse([_p(x - r, y - r), _p(x + r, y + r)], fill=CLOUD_S)
    for x, y, r in puffs:
        d.ellipse([_p(x - r * 0.92, y - r), _p(x + r * 0.8, y + r * 0.55)], fill=CLOUD)
    return _to2x(im)

def dust_ring(x, y, t, n=5, spread=34, r0=7.0, side='both', seed=1):
    """Polvere che parte dai piedi: si allarga e sale (t da 0 a 1) e sparisce sfumando."""
    rnd = random.Random(seed); puffs = []
    sides = (-1, 1) if side == 'both' else ((-1,) if side == 'back' else (1,))
    for sgn in sides:
        for i in range(n):
            k = (i + 1) / n
            px = x + sgn * (5 + spread * k * (0.35 + 0.8 * t)) + rnd.uniform(-2, 2)
            py = y - 4 - 8 * k * t + rnd.uniform(-1, 1)
            r = r0 * (0.55 + 0.6 * t) * (1.25 - 0.5 * k)
            puffs.append((px, py, r))
    out = dust(puffs)
    out[..., 3] *= max(0.0, 1 - t ** 2.2)
    return out

def star(x, y, r, rot=0, n=8, inner=0.45, fill=WHITE, rim=PINK, ink=1.4):
    """Stella d'impatto: punte rosa, cuore bianco, contorno nero."""
    im = _canvas(); d = ImageDraw.Draw(im)
    def pts(R, k):
        out = []
        for i in range(n * 2):
            a = math.radians(rot) + math.pi * i / n
            rr = R if i % 2 == 0 else R * k
            out.append(_p(x + rr * math.cos(a), y + rr * math.sin(a)))
        return out
    d.polygon(pts(r + ink, inner), fill=INK)
    d.polygon(pts(r, inner), fill=rim)
    d.polygon(pts(r * 0.55, inner * 1.1), fill=fill)
    return _to2x(im)

def sparks(x, y, n, r0, r1, rot=0, w=1.4, color=PINK, seed=0):
    """Schegge che partono da un punto: tratti rosa col bordo nero."""
    rnd = random.Random(seed); im = _canvas(); d = ImageDraw.Draw(im)
    segs = []
    for i in range(n):
        a = math.radians(rot) + 2 * math.pi * i / n + rnd.uniform(-0.2, 0.2)
        a0, a1 = r0 * rnd.uniform(0.85, 1.1), r1 * rnd.uniform(0.8, 1.15)
        segs.append((x + a0 * math.cos(a), y + a0 * math.sin(a), x + a1 * math.cos(a), y + a1 * math.sin(a)))
    for sx, sy, ex, ey in segs:
        d.line([_p(sx, sy), _p(ex, ey)], fill=INK, width=int((w + 1.4) * S))
    for sx, sy, ex, ey in segs:
        d.line([_p(sx, sy), _p(ex, ey)], fill=color, width=int(w * S))
    return _to2x(im)

def crescent(cx, cy, r, a0, a1, thick, color=PINK, hl=PINK_L, ink=1.0, line=True):
    """Arco a mezzaluna (la scia rosa dei colpi): spesso al centro, a punta agli estremi."""
    im = _canvas(); d = ImageDraw.Draw(im)
    N = 40
    def ring(rr, tk):
        out, inn = [], []
        for i in range(N + 1):
            t = i / N; a = math.radians(a0 + (a1 - a0) * t)
            th = tk * math.sin(math.pi * t) ** 0.8
            out.append(_p(cx + rr * math.cos(a), cy + rr * math.sin(a)))
            inn.append(_p(cx + (rr - th) * math.cos(a), cy + (rr - th) * math.sin(a)))
        return out + inn[::-1]
    if line:
        d.polygon(ring(r + ink, thick + 2 * ink), fill=INK)
    d.polygon(ring(r, thick), fill=color)
    d.polygon(ring(r - thick * 0.25, thick * 0.35), fill=hl)
    return _to2x(im)

def ghost(char2x, a=0.35, tint=(255, 120, 200), mix=0.55, t=(0, 0)):
    """Scia: il personaggio di un istante prima, colorato e trasparente."""
    g = char2x.copy()
    g[..., :3] = g[..., :3] * (1 - mix) + np.array(tint) * mix
    g[..., 3] *= a
    if t != (0, 0):
        M = np.float32([[1, 0, t[0] * Z], [0, 1, t[1] * Z]])
        g = cv2.warpAffine(g, M, (g.shape[1], g.shape[0]), flags=cv2.INTER_LINEAR, borderValue=0)
    return g

def vlines(xs, y0, y1, color=(150, 215, 255, 255), w=1.0, seed=0):
    """Linee verticali sottili (caduta veloce)."""
    rnd = random.Random(seed); im = _canvas(); d = ImageDraw.Draw(im)
    for x in xs:
        a, b = y0 + rnd.uniform(-8, 8), y1 + rnd.uniform(-10, 10)
        d.line([_p(x, a), _p(x, b)], fill=color, width=int(w * S))
    return _to2x(im)

# --- effetti morbidi, a 1x dopo il contorno chiaro ---

def glow1x(frame1x, color, r=6, strength=1.0, a=0.9):
    """Alone attorno alla sagoma (aura, carica)."""
    al = frame1x[..., 3] / 255
    m = ndi.gaussian_filter((al > 0.3).astype(np.float32), r) * strength
    m = np.clip(m * 1.6, 0, 1) * a
    g = np.zeros_like(frame1x); g[..., :3] = color; g[..., 3] = m * 255
    return g

def soft_dots(points, color, blur=1.2):
    """Puntini morbidi a 1x (fumo, scintille d'oro): (x, y, r, a) nel fotogramma originale."""
    im = Image.new('RGBA', (CW * 4, CH * 4), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    for x, y, r, a in points:
        c = tuple(color[:3]) + (int(255 * a),)
        d.ellipse([((x + PX - r) * 4, (y + PT - r) * 4), ((x + PX + r) * 4, (y + PT + r) * 4)], fill=c)
    im = im.resize((CW, CH), Image.LANCZOS).filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(im, np.float32)

def twinkles(points, color=(255, 236, 140), ink=True):
    """Stelline a 4 punte (oro): (x, y, r)."""
    im = _canvas(); d = ImageDraw.Draw(im)
    for x, y, r in points:
        for rr, c in ((r + 0.9, INK if ink else None), (r, color + (255,))):
            if c is None: continue
            pts = []
            for i in range(8):
                a = math.pi * i / 4
                k = rr if i % 2 == 0 else rr * 0.28
                pts.append(_p(x + k * math.cos(a), y + k * math.sin(a)))
            d.polygon(pts, fill=c)
    return _to2x(im)

def flames(cx, cy, w, h, n, t, seed=0, color=(255, 214, 60), core=(255, 250, 200)):
    """Lingue d'oro che salgono attorno alla sagoma (aura della super)."""
    rnd = random.Random(seed); im = _canvas(); d = ImageDraw.Draw(im)
    for i in range(n):
        x = cx + rnd.uniform(-w / 2, w / 2)
        base = cy + rnd.uniform(-h * 0.1, h * 0.25)
        hh = h * rnd.uniform(0.25, 0.6) * (0.6 + 0.4 * math.sin(t * 6.28 + i))
        ww = rnd.uniform(6, 11)
        sway = rnd.uniform(-6, 6) * math.sin(t * 6.28 + i * 1.7)
        for k, (c, f) in enumerate(((INK, 1.25), (color + (255,), 1.0), (core + (255,), 0.45))):
            pts = [_p(x - ww * f, base), _p(x + sway * 0.5 - ww * 0.4 * f, base - hh * 0.55), _p(x + sway, base - hh * f),
                   _p(x + sway * 0.5 + ww * 0.4 * f, base - hh * 0.5), _p(x + ww * f, base)]
            d.polygon(pts, fill=c)
    return _to2x(im)
