"""I fogli di fotogrammi dello sfondo vivo di Padova (#288 passo 3), dipinti con pittura.py.

Ogni foglio è una fila di fotogrammi della stessa misura, a 2x, letti da godot/scripts/stage_life.gd tramite
art.life.sheets in src/shared/stages.ts. Senza un foglio, il gioco disegna la vecchia forma semplice.

Uso: python3 tools/arene/vita.py  (scrive in public/assets/stages/padova/)
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pittura import Quadro, bezier, sheet, wobble  # noqa: E402

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "public", "assets", "stages", "padova")
os.makedirs(OUT, exist_ok=True)

INK = (44, 46, 58)


# --- nuvole: bianche e dipinte, il gioco le colora con la luce del momento ---
def cloud(seed, W=300, H=130):
    """Una nuvola a cumulo: la base piatta e un po' in ombra, i batuffoli che salgono verso il centro, ognuno con il
    suo ricciolo d'ombra in basso a destra, il bordo illuminato in alto a sinistra e la grana del pennello."""
    q = Quadro(W, H)
    rng = random.Random(seed)
    base = H * 0.86
    m = q.mask()
    q.ellipse(m, W * 0.06, base - H * 0.2, W * 0.94, base + H * 0.06)  # la base allungata
    puffs = []
    n = rng.randint(6, 9)
    for i in range(n):
        u = 0.12 + 0.76 * i / (n - 1) + rng.uniform(-0.04, 0.04)
        bell = math.sin(u * math.pi) ** 0.8
        r = H * (0.14 + 0.24 * bell) * rng.uniform(0.85, 1.1)
        cx = W * u
        cy = base - r * rng.uniform(0.7, 0.95) - H * 0.1 * bell
        puffs.append((cx, cy, r))
        q.ellipse(m, cx - r, cy - r, cx + r, cy + r)
    for _ in range(3):  # qualche batuffolo piccolo in cima, per spezzare la sagoma
        cx, cy, r = rng.choice(puffs[1:-1])
        a = rng.uniform(math.pi * 1.1, math.pi * 1.9)
        rr = r * rng.uniform(0.35, 0.55)
        q.ellipse(m, cx + math.cos(a) * r * 0.7 - rr, cy + math.sin(a) * r * 0.7 - rr, cx + math.cos(a) * r * 0.7 + rr, cy + math.sin(a) * r * 0.7 + rr)
    m = q.smooth(m, H * 0.035)
    q.fill(m, (250, 251, 253))
    # i riccioli: ogni batuffolo fa un'ombra a falce in basso a destra, dove si appoggia al vicino
    for cx, cy, r in puffs:
        pm = q.smooth(q.ellipse(q.mask(), cx - r, cy - r, cx + r, cy + r), r * 0.08)
        q.fill(q.intersect(q.inner_shadow(pm, -r * 0.22, -r * 0.3, r * 0.12), m), (214, 222, 236), 0.75)
    # la pancia in ombra e il bordo in luce
    q.fill(q.inner_shadow(m, 0, -H * 0.24, H * 0.09), (184, 196, 218), 0.9)
    q.fill(q.rim(m, -2.0, -3.0, 1.6), (255, 255, 255), 0.9)
    q.fill(q.grain(m, 0.5, seed, size=3), (214, 222, 236), 0.35)
    q.outline(m, 0.8, (170, 184, 208))
    return q.result()


# --- uccelli: i fotogrammi del battito d'ali, rivolti a destra (il gioco li specchia) ---
def _bird(q, cx, cy, flap, body_col, wing_col, tip_col, belly=None, length=30, span=26, tail="fan", seed=1):
    """Un uccello in volo visto un po' da sotto, con le ali aperte a gabbiano (la sagoma a M che si riconosce da
    lontano). Le ali battono con flap da -1 (giù) a 1 (su): il gomito sale, la punta scende e risale. Il corpo a
    fuso va verso destra con la coda a sinistra. Contorno a inchiostro e ombre morbide."""
    lift = flap * span * 0.45
    wings = []
    for side in (-1, 1):
        sh = (cx + side * 1.5, cy - 0.5)
        elbow = (cx + side * span * 0.42, cy - 5 - lift * 0.55)
        tip = (cx + side * span, cy + 1 - lift)
        lead = bezier(sh, (cx + side * span * 0.2, cy - 4 - lift * 0.4), (elbow[0] - side * 3, elbow[1] - 1), elbow, 8)
        lead += bezier(elbow, (elbow[0] + side * span * 0.2, elbow[1] - 1), (tip[0] - side * span * 0.15, tip[1] - 2), tip, 8)[1:]
        trail = bezier(tip, (tip[0] - side * span * 0.25, tip[1] + 4), (cx + side * span * 0.35, cy + 3 - lift * 0.3), (cx + side * 1.5, cy + 2.5), 10)
        w = q.smooth(q.poly(q.mask(), lead + trail), 0.5)
        wings.append((w, tip, side))
    for w, tip, side in wings:
        q.fill(w, wing_col if side > 0 else tuple(int(c * 0.86) for c in wing_col))
        tipm = q.ellipse(q.mask(), tip[0] - span * 0.24, tip[1] - span * 0.16, tip[0] + span * 0.24, tip[1] + span * 0.16)
        q.fill(q.intersect(q.soften(tipm, 0.7), w), tip_col)
        q.fill(q.inner_shadow(w, 0, -2.5, 1.1), (0, 0, 0), 0.22)
        q.outline(w, 0.55, INK)
    # corpo a fuso con la testa a destra e la coda a sinistra
    body = q.mask()
    top = bezier((cx - length * 0.5, cy), (cx - length * 0.2, cy - 3.5), (cx + length * 0.25, cy - 4), (cx + length * 0.5, cy - 0.5), 14)
    bot = bezier((cx + length * 0.5, cy - 0.5), (cx + length * 0.3, cy + 4), (cx - length * 0.2, cy + 4), (cx - length * 0.5, cy), 14)
    q.poly(body, top + bot)
    if tail == "fork":
        q.poly(body, [(cx - length * 0.4, cy - 1), (cx - length * 0.95, cy - 4), (cx - length * 0.62, cy), (cx - length * 0.95, cy + 3.5), (cx - length * 0.4, cy + 1.5)])
    else:
        q.poly(body, [(cx - length * 0.4, cy - 1.5), (cx - length * 0.7, cy - 3), (cx - length * 0.72, cy + 2.5), (cx - length * 0.4, cy + 1.5)])
    body = q.smooth(body, 0.6)
    q.fill(body, body_col)
    if belly:
        q.fill(q.inner_shadow(body, 0, -2.5, 1.0), belly)
    q.fill(q.inner_shadow(body, -1, -2, 1.2), (0, 0, 0), 0.2)
    q.outline(body, 0.6, INK)
    q.fill(q.ellipse(q.mask(), cx + length * 0.36 - 0.8, cy - 2.2, cx + length * 0.36 + 0.8, cy - 0.6), INK)


def gull_frames(n=8):
    out = []
    for i in range(n):
        q = Quadro(80, 48, origin=(-8, 0))
        flap = math.sin(i / n * math.tau)
        _bird(q, 34, 26, flap, (238, 238, 234), (156, 162, 172), (48, 48, 52), length=30, span=34)
        # becco giallo spento
        q.fill(q.poly(q.mask(), [(48.5, 25), (53, 26), (48.5, 27)]), (206, 172, 82))
        out.append(q.result())
    return out


def swallow_frames(n=4):
    out = []
    for i in range(n):
        q = Quadro(64, 40)
        flap = [1.0, 0.2, -0.9, 0.2][i]
        _bird(q, 32, 20, flap, (40, 46, 72), (36, 42, 66), (26, 30, 48), belly=(232, 226, 214), length=20, span=26, tail="fork")
        q.fill(q.ellipse(q.mask(), 38.5, 17.8, 41.5, 20.6), (150, 84, 60))  # la gola rossiccia
        out.append(q.result())
    return out


def bat_frames(n=4):
    out = []
    for i in range(n):
        q = Quadro(48, 32)
        flap = [1.0, 0.3, -0.8, 0.3][i]
        cx, cy = 24, 18
        m = q.mask()
        for side in (-1, 1):  # le ali a membrana, con il bordo a festoni tra le dita
            tip = (cx + side * 20, cy - 4 - flap * 9)
            up = bezier((cx, cy - 2), (cx + side * 6, cy - 6 - flap * 6), (cx + side * 14, cy - 8 - flap * 9), tip, 10)
            low = []
            for k in range(4):
                a = (tip[0] - side * 5 * k, tip[1] + 2 + k * 1.6 + flap * k)
                b = (tip[0] - side * 5 * (k + 1), tip[1] + 4 + (k + 1) * 1.6 + flap * (k + 1))
                low += bezier(a, (a[0] - side * 1.5, a[1] + 3), (b[0] + side * 1.5, b[1] + 3), b, 4)
            q.poly(m, up + low + [(cx, cy + 3)])
        q.ellipse(m, cx - 4, cy - 5, cx + 4, cy + 5)  # corpo
        q.poly(m, [(cx - 3, cy - 4), (cx - 2, cy - 9), (cx, cy - 5), (cx + 2, cy - 9), (cx + 3, cy - 4)])  # orecchie
        m = q.smooth(m, 0.5)
        q.fill(m, (46, 40, 50))
        q.fill(q.rim(m, -1, -1.5, 0.8), (110, 100, 120), 0.6)
        q.outline(m, 0.5, (20, 18, 24))
        out.append(q.result())
    return out


def pigeon_frames():
    """Il piccione: 2 fotogrammi fermo (testa su, becca) e 4 in volo. Grigio con le barre scure sull'ala e il collo
    con il riflesso verde e viola."""
    out = []
    for peck in (0, 1):
        q = Quadro(48, 32, origin=(-8, -4))  # stessa misura dei fotogrammi in volo
        m = q.mask()
        q.poly(m, bezier((4, 20), (8, 11), (20, 10), (24, 18), 12) + bezier((24, 18), (20, 24), (10, 24), (4, 20), 10))  # corpo
        q.poly(m, [(4, 18), (0, 15), (1, 21), (5, 21)])  # coda
        hx, hy = (25, 9) if not peck else (28, 17)
        q.poly(m, [(19, 14), (hx - 2, hy + 2), (hx + 2, hy + 2), (23, 17)])  # collo
        q.ellipse(m, hx - 3.5, hy - 3.5, hx + 3.5, hy + 3.5)
        m = q.smooth(m, 0.5)
        q.fill(m, (150, 152, 162))
        neck = q.intersect(q.soften(q.ellipse(q.mask(), 18, hy - 2, 27, 19), 1.5), m)
        q.fill(neck, (98, 132, 112), 0.6)
        q.fill(q.intersect(q.soften(q.ellipse(q.mask(), 18, 14, 25, 19), 1.2), m), (128, 98, 140), 0.4)
        q.fill(q.inner_shadow(m, -1, -2.5, 1.2), (60, 62, 74), 0.5)
        for bx in (11, 14):
            q.line([(bx, 15), (bx + 3, 19)], 0.9, (72, 74, 84))
        q.outline(m, 0.6, INK)
        q.fill(q.poly(q.mask(), [(hx + 3, hy - 0.5), (hx + 6, hy + 1), (hx + 3, hy + 1.5)]), (196, 170, 120))
        q.fill(q.ellipse(q.mask(), hx + 0.6, hy - 1.6, hx + 2.2, hy), (196, 110, 60))
        for lx in (12, 16):  # zampe rosa
            q.line([(lx, 23), (lx - 1, 27)], 0.8, (184, 112, 110))
        out.append(q.result())
    for i in range(4):
        q = Quadro(48, 32, origin=(-8, -4))
        flap = [1.0, 0.2, -0.9, 0.2][i]
        _bird(q, 16, 14, flap, (150, 152, 162), (138, 140, 150), (70, 72, 82), length=20, span=18)
        out.append(q.result())
    return out


if __name__ == "__main__":
    sheet([cloud(s) for s in range(1, 9)], OUT, "nuvole.png")
    sheet(gull_frames(), OUT, "gabbiano.png")
    sheet(swallow_frames(), OUT, "rondine.png")
    sheet(bat_frames(), OUT, "pipistrello.png")
    sheet(pigeon_frames(), OUT, "piccione.png")
