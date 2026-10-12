"""La barca del canale esterno di Padova (#273): un barchino veneto di legno con il barcaiolo che voga a poppa.

Stile del gioco: contorno a inchiostro, ombre piatte a 2 toni. FRAMES fotogrammi della vogata, uno accanto
all'altro; ogni fotogramma è FW × FH unità di mondo, salvato a 2 pixel per unità (scale 0.5 nel gioco).
La superficie dove si atterra (larga quanto la piattaforma mobile, DECK_W) sta a DECK_Y, centrata in DECK_CX:
il gioco mette quel punto sul centro della piattaforma. Il barcaiolo sta a poppa, fuori dalla parte calpestabile.

Uso: python3 tools/arene/barca.py  (scrive public/assets/stages/padova/barca.png)
"""

import math
import os
import sys

from PIL import Image, ImageDraw

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "public", "assets", "stages", "padova")
FRAMES = 6
FW, FH = 290, 130  # unità di mondo
DECK_CX, DECK_Y, DECK_W = 150, 92, 160  # centro e quota della superficie calpestabile
S = 8  # pixel per unità mentre si disegna
OUT_K = 2

INK = (30, 26, 23, 255)
WOOD, WOOD_S, WOOD_L = (122, 84, 56, 255), (96, 64, 42, 255), (156, 116, 80, 255)
DECK, DECK_EDGE = (176, 140, 98, 255), (224, 214, 192, 255)  # il bordo calpestabile resta chiaro
SKIN, SKIN_S = (214, 150, 118, 255), (178, 116, 90, 255)
STRAW, STRAW_S = (222, 196, 130, 255), (186, 160, 98, 255)
RIBBON = (60, 64, 76, 255)
STRIPE_A, STRIPE_B = (236, 234, 228, 255), (92, 104, 122, 255)  # righe grigio-blu spente: il blu acceso è di P2
TROUSERS, TROUSERS_S = (52, 54, 58, 255), (40, 42, 46, 255)
OAR, OAR_S = (186, 150, 104, 255), (150, 118, 80, 255)
INK_W = 1.3


class Pen:
    def __init__(self, img):
        self.img = img
        self.d = ImageDraw.Draw(img)

    @staticmethod
    def p(x, y):
        return (x * S, y * S)

    def poly(self, pts, fill, ink=True):
        q = [self.p(*pt) for pt in pts]
        self.d.polygon(q, fill=fill)
        if ink:
            self.d.line(q + [q[0]], fill=INK, width=int(INK_W * S), joint="curve")

    def circle(self, c, r, fill, ink=True):
        x, y = c
        if ink:
            o = INK_W / 2
            self.d.ellipse([self.p(x - r - o, y - r - o), self.p(x + r + o, y + r + o)], fill=INK)
        self.d.ellipse([self.p(x - r, y - r), self.p(x + r, y + r)], fill=fill)

    def line(self, a, b, w, fill):
        self.d.line([self.p(*a), self.p(*b)], fill=fill, width=max(1, int(w * S)))

    def limb(self, a, b, w, fill, ink=True):
        if ink:
            self.d.line([self.p(*a), self.p(*b)], fill=INK, width=int((w + INK_W) * S))
            for c in (a, b):
                self.circle(c, (w + INK_W) / 2, INK, ink=False)
        self.d.line([self.p(*a), self.p(*b)], fill=fill, width=int(w * S))
        for c in (a, b):
            self.circle(c, w / 2, fill, ink=False)


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def hull(pen):
    left, right = DECK_CX - DECK_W / 2, DECK_CX + DECK_W / 2
    # scafo: poppa larga a sinistra (dove sta il barcaiolo), prua slanciata e rialzata a destra
    outline = [(18, DECK_Y - 12), (34, DECK_Y - 4), (right, DECK_Y - 4), (right + 30, DECK_Y - 16), (right + 36, DECK_Y - 22),
               (right + 30, DECK_Y + 6), (right + 8, DECK_Y + 22), (left - 4, DECK_Y + 26), (30, DECK_Y + 18), (20, DECK_Y + 2)]
    pen.poly(outline, WOOD)
    pen.poly([(left - 4, DECK_Y + 26), (right + 8, DECK_Y + 22), (right + 30, DECK_Y + 6), (right + 20, DECK_Y + 14), (left, DECK_Y + 18)], WOOD_S, ink=False)
    for k in (0.33, 0.66):  # assi del fasciame
        y0 = DECK_Y + 2 + k * 20
        pen.line((26 + k * 6, y0), (right + 28 - k * 18, y0 - 10 * (1 - k)), 0.7, WOOD_S)
    pen.line((34, DECK_Y - 3.2), (right, DECK_Y - 3.2), 1.0, WOOD_L)  # il filo chiaro del bordo
    pen.line((right, DECK_Y - 3.2), (right + 34, DECK_Y - 20), 1.0, WOOD_L)
    # piano dove si sta in piedi, con il bordo chiaro
    pen.poly([(left, DECK_Y), (right, DECK_Y), (right, DECK_Y + 4), (left, DECK_Y + 4)], DECK)
    pen.line((left, DECK_Y + 0.6), (right, DECK_Y + 0.6), 1.2, DECK_EDGE)
    for x in range(int(left) + 20, int(right), 20):  # i banchi
        pen.line((x, DECK_Y + 1.5), (x, DECK_Y + 4), 0.6, WOOD_S)
    # pagliolo di poppa, dove sta il barcaiolo, e la forcola (lo scalmo veneziano)
    pen.poly([(22, DECK_Y - 8), (left, DECK_Y - 2), (left, DECK_Y + 2), (24, DECK_Y - 4)], DECK)
    pen.poly([(44, DECK_Y - 4), (47, DECK_Y - 4), (49, DECK_Y - 16), (52, DECK_Y - 18), (49, DECK_Y - 20), (45, DECK_Y - 14)], WOOD_S)
    # lanterna a prua
    lx, ly = right + 30, DECK_Y - 30
    pen.line((right + 33, DECK_Y - 20), (lx, ly + 4), 1.0, INK)
    pen.poly([(lx - 3, ly - 4), (lx + 3, ly - 4), (lx + 4, ly + 4), (lx - 4, ly + 4)], (214, 196, 140, 255))
    pen.poly([(lx - 4, ly - 4), (lx + 4, ly - 4), (lx, ly - 8)], (70, 66, 60, 255))


def rower(pen, f):
    """Il barcaiolo a poppa: paglietta con il nastro, maglia a righe, voga in piedi con il remo lungo."""
    phase = f / FRAMES * math.tau
    lean = math.sin(phase) * 4  # avanti e indietro con la vogata
    foot_a, foot_b = (26, DECK_Y - 7), (34, DECK_Y - 5)
    hip = (30 + lean * 0.4, DECK_Y - 34)
    shoulder = (31 + lean, DECK_Y - 60)
    head = (32 + lean * 1.1, DECK_Y - 71)
    # remo: dalla forcola in giù nell'acqua dietro la barca, impugnato a due mani
    grip = (44 + lean * 1.6, DECK_Y - 50)
    blade_end = (60 + lean * 3, DECK_Y + 30)
    pen.limb(grip, blade_end, 1.8, OAR)
    pen.poly([(blade_end[0] - 2, blade_end[1] - 10), (blade_end[0] + 3, blade_end[1] - 10), (blade_end[0] + 4, blade_end[1] + 4), (blade_end[0] - 3, blade_end[1] + 4)], OAR_S)
    # gambe
    pen.limb(hip, foot_a, 6.0, TROUSERS_S)
    pen.limb(hip, foot_b, 6.0, TROUSERS)
    for ft in (foot_a, foot_b):
        pen.poly([(ft[0] - 3, ft[1] - 1.5), (ft[0] + 4, ft[1] - 1.5), (ft[0] + 4, ft[1] + 1.5), (ft[0] - 3, ft[1] + 1.5)], INK, ink=False)
    # busto con la maglia a righe
    torso = [(hip[0] - 6, hip[1] + 2), (hip[0] + 7, hip[1] + 2), (shoulder[0] + 7, shoulder[1] + 1), (shoulder[0] - 6, shoulder[1])]
    pen.poly(torso, STRIPE_A)
    for i in range(5):
        k = (i + 0.5) / 5.5
        a = lerp(torso[3], torso[0], k)
        b = lerp(torso[2], torso[1], k)
        pen.line(a, b, 1.6, STRIPE_B)
    q = [Pen.p(*pt) for pt in torso]
    pen.d.line(q + [q[0]], fill=INK, width=int(INK_W * S), joint="curve")
    # braccia sul remo
    pen.limb((shoulder[0] + 3, shoulder[1] + 2), grip, 3.6, SKIN)
    pen.limb((shoulder[0] - 2, shoulder[1] + 3), lerp(grip, blade_end, 0.08), 3.6, SKIN_S)
    pen.circle(grip, 2.2, SKIN)
    # testa con la paglietta
    pen.circle(head, 7, SKIN)
    pen.circle((head[0] + 5, head[1] + 1), 1.6, SKIN)  # naso
    pen.line((head[0] + 1.5, head[1] - 1), (head[0] + 3.5, head[1] - 1.2), 0.7, INK)  # occhio socchiuso
    pen.line((head[0] - 1, head[1] + 4), (head[0] + 5, head[1] + 3.6), 1.2, (110, 96, 86, 255))  # baffi
    pen.poly([(head[0] - 11, head[1] - 4), (head[0] + 11, head[1] - 4), (head[0] + 9, head[1] - 2), (head[0] - 9, head[1] - 2)], STRAW)  # tesa
    pen.poly([(head[0] - 6, head[1] - 4), (head[0] + 6, head[1] - 4), (head[0] + 5, head[1] - 10), (head[0] - 5, head[1] - 10)], STRAW)  # cupola
    pen.line((head[0] - 6, head[1] - 5.5), (head[0] + 6, head[1] - 5.5), 1.6, RIBBON)  # il nastro
    pen.line((head[0] + 6, head[1] - 5.5), (head[0] + 9, head[1] - 3 + math.sin(phase) * 1.5), 1.0, RIBBON)


def ripples(pen, f):
    # piccole onde intorno allo scafo, che si spostano con la vogata
    for i in range(4):
        k = ((f + i * 1.5) % FRAMES) / FRAMES
        x = 20 + i * 62 + k * 10
        pen.line((x, DECK_Y + 30), (x + 18, DECK_Y + 30), 1.0, (210, 226, 226, int(200 * (1 - k))))


def frame_image(f):
    img = Image.new("RGBA", (FW * S, FH * S), (0, 0, 0, 0))
    pen = Pen(img)
    ripples(pen, f)
    hull(pen)
    rower(pen, f)
    return img.resize((FW * OUT_K, FH * OUT_K), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    sheet = Image.new("RGBA", (FW * OUT_K * FRAMES, FH * OUT_K), (0, 0, 0, 0))
    for f in range(FRAMES):
        sheet.paste(frame_image(f), (f * FW * OUT_K, 0))
    path = os.path.join(OUT, "barca.png")
    sheet.save(path, optimize=True)
    print("scritto", path, sheet.size, "piede", (DECK_CX * OUT_K, DECK_Y * OUT_K))


if __name__ == "__main__":
    main()
