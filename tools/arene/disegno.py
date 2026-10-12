"""Aiuti comuni per disegnare le arene col codice (#280), nello stile del gioco (docs/stile-grafico.md).

- Si disegna in pixel di mondo: le coordinate sono quelle dell'arena, la tela le moltiplica da sola.
- Il file esce a 2x (nel gioco `art.scale: 0.5` o `scale: 0.5`), disegnato a 4x e ridotto: i bordi restano lisci.
- Contorno a inchiostro di spessore costante (circa 3 px nel file a 2x) e ombre piatte a 2 toni.

Uso:
    t = Tela(96, 48)                     # 96×48 pixel di mondo, file 192×96
    t.poly([(0, 0), (10, 0), (5, 8)], fill=PIETRA, ink=True)
    t.save(cartella, "pezzo.png")

Con `wrap=True` la tela è una piastrella che si ripete: quello che esce da un lato rientra da quello opposto.
"""

import math
import os
import random

from PIL import Image, ImageDraw

INK = (30, 26, 23, 255)  # quasi nero, non nero puro
INK_W = 1.5  # spessore dell'inchiostro in pixel di mondo (3 px nel file a 2x)
OUT_SCALE = 2  # pixel del file per pixel di mondo
SUPER = 2  # si disegna a OUT_SCALE × SUPER e si riduce


def shade(col, k=0.82):
    """Il tono d'ombra di un colore: più scuro e un po' più freddo."""
    r, g, b = col[:3]
    a = col[3] if len(col) > 3 else 255
    return (int(r * k), int(g * k), int(min(255, b * k * 1.04)), a)


def light(col, k=1.12):
    r, g, b = col[:3]
    a = col[3] if len(col) > 3 else 255
    return (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)), a)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(4))


def _scale(v, k):
    """Moltiplica per k tutti i numeri di coordinate annidate (liste, tuple)."""
    if isinstance(v, (int, float)):
        return v * k
    return type(v)(_scale(x, k) for x in v) if isinstance(v, tuple) else [_scale(x, k) for x in v]


class Scala:
    """Un ImageDraw che prende coordinate e spessori in pixel di mondo e disegna a k pixel per pixel.
    Serve a riusare a 2x i disegni scritti a 1x (gli strati dello sfondo)."""

    def __init__(self, d, k):
        self._d, self._k = d, k

    def __getattr__(self, name):
        fn = getattr(self._d, name)

        def call(xy, *args, **kw):
            if "width" in kw:
                kw["width"] = max(1, int(round(kw["width"] * self._k)))
            return fn(_scale(xy, self._k), *args, **kw)

        return call


class Tela:
    def __init__(self, w, h, bg=(0, 0, 0, 0), wrap=False, wrap_y=False, scale=OUT_SCALE, ss=SUPER):
        self.w, self.h = w, h
        self.k = scale * ss
        self.ss = ss
        self.wrap, self.wrap_y = wrap, wrap_y
        self.img = Image.new("RGBA", (int(round(w * self.k)), int(round(h * self.k))), bg)
        self.d = ImageDraw.Draw(self.img)

    # --- coordinate ---
    def _offsets(self):
        xs = [-self.w, 0, self.w] if self.wrap else [0]
        ys = [-self.h, 0, self.h] if self.wrap_y else [0]
        return [(ox, oy) for ox in xs for oy in ys]

    def _pts(self, pts, ox, oy):
        return [((x + ox) * self.k, (y + oy) * self.k) for x, y in pts]

    def _box(self, box, ox, oy):
        x0, y0, x1, y1 = box
        return [(x0 + ox) * self.k, (y0 + oy) * self.k, (x1 + ox) * self.k, (y1 + oy) * self.k]

    def _w(self, width):
        return max(1, int(round(width * self.k)))

    # --- figure ---
    def poly(self, pts, fill=None, ink=False, width=INK_W, ink_col=INK):
        for ox, oy in self._offsets():
            p = self._pts(pts, ox, oy)
            if fill:
                self.d.polygon(p, fill=fill)
            if ink:
                self.d.line(p + [p[0]], fill=ink_col, width=self._w(width), joint="curve")

    def rect(self, x0, y0, x1, y1, fill=None, ink=False, width=INK_W, ink_col=INK):
        self.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], fill, ink, width, ink_col)

    def line(self, pts, fill=INK, width=INK_W):
        for ox, oy in self._offsets():
            p = self._pts(pts, ox, oy)
            self.d.line(p, fill=fill, width=self._w(width), joint="curve")
            # estremità tonde, come un pennino
            r = self._w(width) / 2
            if r >= 1.5:
                for q in (p[0], p[-1]):
                    self.d.ellipse([q[0] - r, q[1] - r, q[0] + r, q[1] + r], fill=fill)

    def ellipse(self, x0, y0, x1, y1, fill=None, ink=False, width=INK_W, ink_col=INK):
        for ox, oy in self._offsets():
            b = self._box((x0, y0, x1, y1), ox, oy)
            self.d.ellipse(b, fill=fill, outline=ink_col if ink else None, width=self._w(width) if ink else 0)

    def circle(self, cx, cy, r, **kw):
        self.ellipse(cx - r, cy - r, cx + r, cy + r, **kw)

    def arc(self, x0, y0, x1, y1, start, end, fill=INK, width=INK_W):
        for ox, oy in self._offsets():
            self.d.arc(self._box((x0, y0, x1, y1), ox, oy), start, end, fill=fill, width=self._w(width))

    def chord(self, x0, y0, x1, y1, start, end, fill=None, ink=False, width=INK_W):
        for ox, oy in self._offsets():
            self.d.chord(self._box((x0, y0, x1, y1), ox, oy), start, end, fill=fill, outline=INK if ink else None, width=self._w(width) if ink else 0)

    def pieslice(self, x0, y0, x1, y1, start, end, fill=None):
        for ox, oy in self._offsets():
            self.d.pieslice(self._box((x0, y0, x1, y1), ox, oy), start, end, fill=fill)

    def glaze(self, pts, col):
        """Una velatura semitrasparente sopra quello che c'è già (macchie, colature): si fonde, non buca la tela."""
        over = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        od = ImageDraw.Draw(over)
        for ox, oy in self._offsets():
            od.polygon(self._pts(pts, ox, oy), fill=col)
        self.img.alpha_composite(over)

    def paste_inside(self, other, pts):
        """Incolla l'altra tela (stessa misura) solo dentro il poligono pts: serve a ritagliare un fondo in un'apertura."""
        mask = Image.new("L", self.img.size, 0)
        ImageDraw.Draw(mask).polygon(self._pts(pts, 0, 0), fill=255)
        self.img.paste(other.img, (0, 0), mask)

    # --- aiuti di stile ---
    def block(self, x0, y0, x1, y1, base, sh=None, side=0.0, bottom=0.0, ink=True, width=INK_W, chip=None, ink_col=INK):
        """Un blocco di pietra a 2 toni: il tono base, l'ombra piatta sotto (bottom px) e a destra (side px),
        il contorno. chip: (lato, misura) per uno spigolo sbreccato in ombra."""
        sh = sh or shade(base)
        self.rect(x0, y0, x1, y1, fill=base)
        if bottom:
            self.rect(x0, y1 - bottom, x1, y1, fill=sh)
        if side:
            self.poly([(x1 - side, y0 + side), (x1, y0), (x1, y1), (x1 - side, y1)], fill=sh)
        if chip:
            corner, m = chip
            cx = x0 if corner in ("tl", "bl") else x1
            cy = y0 if corner in ("tl", "tr") else y1
            sx = 1 if cx == x0 else -1
            sy = 1 if cy == y0 else -1
            self.poly([(cx, cy), (cx + sx * m, cy), (cx, cy + sy * m)], fill=sh)
        if ink:
            self.rect(x0, y0, x1, y1, ink=True, width=width, ink_col=ink_col)

    def crack(self, x, y, length, rng, width=0.8, col=INK):
        """Una crepa sottile che scende a zig-zag."""
        pts = [(x, y)]
        for _ in range(4):
            x += rng.uniform(-length * 0.25, length * 0.25)
            y += length / 4
            pts.append((x, y))
        self.line(pts, fill=col, width=width)

    def result(self):
        if self.ss == 1:
            return self.img
        return self.img.resize((self.img.width // self.ss, self.img.height // self.ss), Image.LANCZOS)

    def save(self, folder, name, colors=None):
        out = self.result()
        if colors:  # palette ridotta per tenere piccoli i file grandi
            out = out.quantize(colors=colors, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
        out.save(os.path.join(folder, name), optimize=True)
        print("scritto", name, out.size)
        return out


def rand(seed):
    return random.Random(seed)


def wave(t, *phases):
    return sum(math.sin(t * (i + 1) * 1.7 + p) for i, p in enumerate(phases)) / max(1, len(phases))
