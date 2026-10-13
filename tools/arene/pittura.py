"""Motore pittorico per i disegni delle arene (#288 passo 3): niente cerchi e rettangoli che si vedono.

Le forme si costruiscono come **maschere** (immagini in scala di grigi): si uniscono pezzi grossolani, poi si
**lisciano** (sfocatura e soglia) e ne esce una sagoma organica. Dalla sagoma stessa si calcolano le ombre e le luci
morbide (la sagoma spostata verso la luce e sottratta), il contorno a inchiostro (la sagoma allargata) e la grana
a pennello. Si dipinge versando un colore attraverso una maschera.

Le coordinate sono in pixel di mondo, come in disegno.Tela; il file esce a 2x, disegnato a 4x e ridotto.

    q = Quadro(120, 60)
    m = q.mask()
    q.ellipse(m, 10, 10, 60, 40); q.ellipse(m, 40, 5, 100, 45)
    m = q.smooth(m, 4)                    # una sagoma sola, morbida
    q.fill(m, (240, 244, 248))
    q.fill(q.inner_shadow(m, 0, -8, 6), (190, 200, 216), 0.8)   # ombra in basso, luce dall'alto
    q.outline(m, 1.2, (60, 64, 80))
    q.save(cartella, "nuvola.png")
"""

import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT_SCALE = 2
SUPER = 2


def bezier(p0, p1, p2, p3, n=16):
    """I punti di una curva di Bézier cubica, da p0 a p3."""
    out = []
    for i in range(n + 1):
        t = i / n
        a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t * t, t ** 3
        out.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return out


def wobble(pts, amount, seed, closed=True):
    """Fa tremare un contorno come una linea a mano: ogni punto si sposta di poco, in modo morbido."""
    rng = random.Random(seed)
    n = len(pts)
    phases = [rng.uniform(0, math.tau) for _ in range(3)]
    out = []
    for i, (x, y) in enumerate(pts):
        u = i / max(1, n - (0 if closed else 1))
        dx = sum(math.sin(u * math.tau * (k + 2) + phases[k]) for k in range(3)) / 3 * amount
        dy = sum(math.cos(u * math.tau * (k + 3) + phases[k]) for k in range(3)) / 3 * amount
        out.append((x + dx, y + dy))
    return out


class Quadro:
    def __init__(self, w, h, origin=(0, 0), scale=OUT_SCALE, ss=SUPER):
        self.w, self.h = w, h
        self.ox, self.oy = origin
        self.k = scale * ss
        self.ss = ss
        self.size = (int(round(w * self.k)), int(round(h * self.k)))
        self.img = Image.new("RGBA", self.size, (0, 0, 0, 0))

    # --- coordinate ---
    def _p(self, x, y):
        return ((x - self.ox) * self.k, (y - self.oy) * self.k)

    def _pts(self, pts):
        return [self._p(x, y) for x, y in pts]

    def _r(self, r):
        return max(0.5, r * self.k)

    # --- maschere ---
    def mask(self, fill=0):
        return Image.new("L", self.size, fill)

    def poly(self, m, pts, value=255):
        ImageDraw.Draw(m).polygon(self._pts(pts), fill=value)
        return m

    def ellipse(self, m, x0, y0, x1, y1, value=255):
        ImageDraw.Draw(m).ellipse([*self._p(x0, y0), *self._p(x1, y1)], fill=value)
        return m

    def stroke(self, m, pts, width, value=255):
        """Una pennellata: una linea spessa con le estremità tonde."""
        d = ImageDraw.Draw(m)
        p = self._pts(pts)
        w = int(round(self._r(width)))
        d.line(p, fill=value, width=max(1, w), joint="curve")
        r = w / 2
        for q in (p[0], p[-1]):
            d.ellipse([q[0] - r, q[1] - r, q[0] + r, q[1] + r], fill=value)
        return m

    def smooth(self, m, r):
        """Lisciare: sfoca e taglia a metà. Gli spigoli e le giunture tra i pezzi diventano curve morbide."""
        return m.filter(ImageFilter.GaussianBlur(self._r(r))).point(lambda v: 255 if v >= 128 else 0)

    def soften(self, m, r):
        """Sfumare i bordi di una maschera (per ombre e luci morbide)."""
        return m.filter(ImageFilter.GaussianBlur(self._r(r)))

    def shift(self, m, dx, dy):
        return ImageChops.offset(m, int(round(dx * self.k)), int(round(dy * self.k)))

    def inner_shadow(self, m, dx, dy, blur):
        """L'ombra dentro una sagoma, dalla parte opposta alla luce: la sagoma meno sé stessa spostata verso
        la luce (dx, dy puntano verso la luce), sfumata e tenuta dentro la sagoma."""
        cut = ImageChops.subtract(m, self.shift(m, dx, dy))
        return ImageChops.multiply(self.soften(cut, blur), m)

    def rim(self, m, dx, dy, blur):
        """La luce sul bordo dalla parte della luce (dx, dy puntano verso la luce)."""
        return self.inner_shadow(m, -dx, -dy, blur)

    def intersect(self, a, b):
        return ImageChops.multiply(a, b)

    def union(self, a, b):
        return ImageChops.lighter(a, b)

    def minus(self, a, b):
        return ImageChops.subtract(a, b)

    def grain(self, m, amount, seed, size=1.5):
        """Grana a pennello: una maschera di rumore morbido dentro la sagoma, alta amount (0-1)."""
        rng = random.Random(seed)
        small = (max(1, int(self.size[0] / (size * self.k))), max(1, int(self.size[1] / (size * self.k))))
        noise = Image.new("L", small)
        noise.putdata([int(rng.random() * 255 * amount) for _ in range(small[0] * small[1])])
        noise = noise.resize(self.size, Image.BICUBIC)
        return ImageChops.multiply(noise, m)

    # --- pittura ---
    def fill(self, m, col, opacity=1.0):
        """Versare un colore attraverso una maschera: dove la maschera è bianca il colore copre, dove è grigia vela."""
        r, g, b = col[:3]
        a = col[3] if len(col) > 3 else 255
        layer = Image.new("RGBA", self.size, (r, g, b, 0))
        alpha = m.point(lambda v: int(v * opacity * a / 255))
        layer.putalpha(alpha)
        self.img.alpha_composite(layer)

    def outline(self, m, width, col, inside=False):
        """Il contorno a inchiostro attorno alla sagoma: la sagoma allargata meno la sagoma, ammorbidito appena."""
        px = max(3, int(round(self._r(width))) * 2 + 1)
        if inside:
            ring = ImageChops.subtract(m, m.filter(ImageFilter.MinFilter(px)))
        else:
            ring = ImageChops.subtract(m.filter(ImageFilter.MaxFilter(px)), m)
        self.fill(ring.filter(ImageFilter.GaussianBlur(0.8)), col)

    def line(self, pts, width, col, opacity=1.0):
        m = self.stroke(self.mask(), pts, width)
        self.fill(m.filter(ImageFilter.GaussianBlur(0.7)), col, opacity)

    def result(self):
        if self.ss == 1:
            return self.img
        return self.img.resize((self.size[0] // self.ss, self.size[1] // self.ss), Image.LANCZOS)

    def save(self, folder, name):
        out = self.result()
        out.save(os.path.join(folder, name), optimize=True)
        print("scritto", name, out.size)
        return out


def sheet(frames, folder, name, colors=None):
    """Mette in fila i fotogrammi (immagini della stessa misura) in un foglio, da sinistra a destra."""
    w, h = frames[0].size
    out = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.alpha_composite(f, (i * w, 0))
    if colors:
        out = out.quantize(colors=colors, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
    out.save(os.path.join(folder, name), optimize=True)
    print("scritto", name, out.size, len(frames), "fotogrammi")
    return out
