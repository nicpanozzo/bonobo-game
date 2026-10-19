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
from PIL import Image  # noqa: E402
from pittura import Quadro, bezier, sheet, wobble  # noqa: E402
from disegno import light, shade  # noqa: E402

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


# --- passanti (#288 passo 3b): figure dipinte di profilo, rivolte a destra, con la camminata in 8 fotogrammi ---
SKINS = [(214, 170, 140), (184, 136, 104), (226, 186, 156), (140, 98, 72), (200, 154, 122)]
HAIRS = [(48, 38, 32), (96, 66, 44), (150, 146, 140), (64, 54, 48), (126, 96, 60)]


def _rot(v, a):
    return (v[0] * math.cos(a) - v[1] * math.sin(a), v[0] * math.sin(a) + v[1] * math.cos(a))


def _part(q, pts_or_mask, col, shade_k=0.78, width=None, ink=0.5):
    """Un pezzo del corpo: una pennellata (pts e width) o un poligono, lisciato, colorato, con l'ombra morbida in
    basso a destra (luce dall'alto a sinistra) e il contorno a inchiostro."""
    if width is not None:
        m = q.stroke(q.mask(), pts_or_mask, width)
    elif isinstance(pts_or_mask, list):
        m = q.poly(q.mask(), pts_or_mask)
    else:
        m = pts_or_mask
    m = q.smooth(m, 0.35)
    q.fill(m, col)
    q.fill(q.inner_shadow(m, -1.0, -1.6, 0.9), tuple(int(c * shade_k) for c in col[:3]), 0.85)
    q.fill(q.rim(m, -0.6, -0.9, 0.5), tuple(min(255, int(c * 1.15)) for c in col[:3]), 0.5)
    if ink:
        q.outline(m, ink, INK)
    return m


def person(q, x, base, phase, outfit, run=False, lean=0.0, hold=None, coat=False, skirt=False, hair="corti", cap=None, wreath=False, height=38.0):
    """Una persona di profilo che cammina verso destra. phase da 0 a 1 è il passo: gambe e braccia si alternano,
    con le ginocchia che piegano e il corpo che sale e scende appena. outfit: (giacca, pantaloni, scarpe, pelle,
    capelli). hold: dove vanno le mani ("avanti" per il passeggino, "su" per il giornale, "bastone", "guinzaglio",
    "borsa"). Restituisce la posizione della mano davanti, per attaccarci gli oggetti."""
    jacket, pants, shoes, skin, hair_col = outfit
    H = height
    amp = 0.75 if run else 0.42
    swing = math.sin(phase * math.tau)
    bob = abs(math.cos(phase * math.tau)) * (1.6 if run else 0.8)
    hip = (x, base - H * 0.5 - bob + 0.8)
    sh = (x + lean * H * 0.25, base - H * 0.77 - bob)
    head = (sh[0] + 1.2 + lean * 3, sh[1] - 5.2)
    thigh, shin = H * 0.27, H * 0.25
    legs = []
    for side in (-1, 1):  # -1 gamba dietro, 1 gamba davanti
        a = side * swing * amp
        knee = (hip[0] + math.sin(a) * thigh, hip[1] + math.cos(a) * thigh)
        bend = (0.9 if run else 0.35) * max(0.0, -side * swing) + 0.12
        foot = (knee[0] + math.sin(a - bend) * shin, knee[1] + math.cos(a - bend) * shin)
        legs.append((side, knee, foot))
    arms = []
    for side in (-1, 1):
        a = -side * swing * (0.9 if run else 0.5)
        elbow = (sh[0] + math.sin(a) * H * 0.18, sh[1] + math.cos(a) * H * 0.18)
        hand = (elbow[0] + math.sin(a + (1.4 if run else 0.25)) * H * 0.17, elbow[1] + math.cos(a + (1.4 if run else 0.25)) * H * 0.17)
        arms.append((side, elbow, hand))
    if hold == "avanti":
        arms = [(s, (sh[0] + 4, sh[1] + 5), (sh[0] + 9, sh[1] + 9 + s)) for s, _, _ in arms]
    elif hold == "su":
        arms = [(s, (sh[0] + 3 * s + 1, sh[1] - 4), (sh[0] + 4 * s + 2, sh[1] - 9)) for s, _, _ in arms]
    elif hold == "bastone":
        arms[1] = (1, (sh[0] + 3, sh[1] + 6), (sh[0] + 7, sh[1] + 11))
    elif hold == "guinzaglio":
        arms[1] = (1, (sh[0] + 3, sh[1] + 6), (sh[0] + 8, sh[1] + 9))
    back_col = tuple(int(c * 0.82) for c in jacket)
    # braccio e gamba di dietro, più scuri
    _part(q, [sh, arms[0][1], arms[0][2]], back_col, width=H * 0.075)
    _part(q, [hip, legs[0][1], legs[0][2]], tuple(int(c * 0.82) for c in pants), width=H * 0.09)
    _part(q, q.ellipse(q.mask(), legs[0][2][0] - 1.2, legs[0][2][1] - 1.6, legs[0][2][0] + 3.6, legs[0][2][1] + 0.8), tuple(int(c * 0.8) for c in shoes))
    # busto: dalle spalle ai fianchi, con il cappotto lungo o la gonna
    hem = base - H * (0.22 if coat else 0.42)
    torso = [(sh[0] - H * 0.09, sh[1]), (sh[0] + H * 0.08, sh[1] + 0.5), (hip[0] + H * 0.1, hem), (hip[0] - H * 0.1, hem)]
    if skirt:
        torso = [(sh[0] - H * 0.09, sh[1]), (sh[0] + H * 0.08, sh[1] + 0.5), (hip[0] + H * 0.08, hip[1]), (hip[0] + H * 0.16, base - H * 0.24), (hip[0] - H * 0.14, base - H * 0.24), (hip[0] - H * 0.08, hip[1])]
    # gamba davanti, sotto la giacca
    _part(q, [hip, legs[1][1], legs[1][2]], pants, width=H * 0.09)
    _part(q, q.ellipse(q.mask(), legs[1][2][0] - 1.2, legs[1][2][1] - 1.6, legs[1][2][0] + 3.8, legs[1][2][1] + 0.8), shoes)
    _part(q, torso, jacket)
    q.line([(sh[0] + 1, sh[1] + 2), (hip[0] + 1.5, hem - 1)], 0.35, tuple(int(c * 0.6) for c in jacket), 0.6)  # la piega dei bottoni
    # collo e testa di profilo: nuca, fronte, naso, mento; capelli
    q.fill(q.smooth(q.stroke(q.mask(), [sh, (head[0] - 0.3, head[1] + 2)], H * 0.06), 0.3), skin)
    hm = q.mask()
    q.ellipse(hm, head[0] - 3.6, head[1] - 4.2, head[0] + 3.4, head[1] + 3.8)
    q.poly(hm, [(head[0] + 3.0, head[1] - 0.6), (head[0] + 4.6, head[1] + 0.8), (head[0] + 3.0, head[1] + 1.4)])  # naso
    _part(q, hm, skin)
    q.fill(q.ellipse(q.mask(), head[0] + 1.4, head[1] - 1.1, head[0] + 2.4, head[1] - 0.1), (40, 34, 30))  # occhio
    hair_m = q.mask()
    if hair == "corti":
        q.poly(hair_m, [(head[0] - 3.8, head[1] + 1.5), (head[0] - 3.7, head[1] - 3.2), (head[0] - 1, head[1] - 4.7), (head[0] + 2.6, head[1] - 4.1), (head[0] + 3.4, head[1] - 2.2), (head[0] + 0.5, head[1] - 2.6), (head[0] - 1.2, head[1] + 0.2)])
    elif hair == "lunghi":
        q.poly(hair_m, [(head[0] - 4.2, head[1] + 6.0), (head[0] - 3.9, head[1] - 3.4), (head[0] - 0.6, head[1] - 4.9), (head[0] + 2.8, head[1] - 4.1), (head[0] + 3.4, head[1] - 2.0), (head[0] + 0.2, head[1] - 2.8), (head[0] - 1.4, head[1] + 1.0), (head[0] - 1.6, head[1] + 6.4)])
    elif hair == "chignon":
        q.poly(hair_m, [(head[0] - 3.8, head[1] + 1.0), (head[0] - 3.6, head[1] - 3.4), (head[0] + 0.4, head[1] - 4.8), (head[0] + 3.2, head[1] - 3.2), (head[0] - 0.8, head[1] - 2.4)])
        q.ellipse(hair_m, head[0] - 6.4, head[1] - 4.4, head[0] - 2.4, head[1] - 0.6)
    elif hair == "calvo":
        q.poly(hair_m, [(head[0] - 3.8, head[1] + 1.2), (head[0] - 3.6, head[1] - 1.6), (head[0] - 1.8, head[1] - 0.8), (head[0] - 1.8, head[1] + 1.6)])
    _part(q, hair_m, hair_col, ink=0.4)
    if cap:
        _part(q, [(head[0] - 3.9, head[1] - 2.0), (head[0] - 3.2, head[1] - 4.8), (head[0] + 1.6, head[1] - 5.2), (head[0] + 3.6, head[1] - 3.2), (head[0] + 6.0, head[1] - 2.6), (head[0] + 3.0, head[1] - 2.0)], cap)
    if wreath:  # la corona d'alloro di chi si è appena laureato
        for k in range(8):
            a = math.pi * (1.05 + k * 0.12)
            lx, ly = head[0] + math.cos(a) * 3.9, head[1] - 2.2 + math.sin(a) * 2.5
            _part(q, q.ellipse(q.mask(), lx - 1.3, ly - 0.7, lx + 1.3, ly + 0.7), (110, 138, 84), ink=0.25)
    # braccio davanti con la mano
    _part(q, [sh, arms[1][1], arms[1][2]], jacket, width=H * 0.075)
    hand = arms[1][2]
    _part(q, q.ellipse(q.mask(), hand[0] - 1.3, hand[1] - 1.3, hand[0] + 1.3, hand[1] + 1.3), skin, ink=0.35)
    return hand, arms[0][2], head


def dog(q, x, base, phase, col=(120, 88, 60)):
    """Un cagnolino che trotta: corpo, testa con l'orecchio che ballonzola, coda alzata, quattro zampe."""
    trot = math.sin(phase * math.tau * 2)
    for k, lx in enumerate((x - 5, x - 3, x + 4, x + 6)):
        a = (trot if k % 2 else -trot) * 0.5
        _part(q, [(lx, base - 6), (lx + math.sin(a) * 4.5, base - 0.6)], tuple(int(c * (0.8 if k in (1, 3) else 1)) for c in col), width=1.8, ink=0.35)
    body = q.ellipse(q.mask(), x - 8, base - 10, x + 8, base - 4.5)
    _part(q, body, col)
    _part(q, q.ellipse(q.mask(), x + 6, base - 14 + trot * 0.4, x + 12, base - 8.5 + trot * 0.4), col)
    _part(q, [(x + 9.5, base - 12.5), (x + 8, base - 9 + trot), (x + 10, base - 9.5 + trot)], tuple(int(c * 0.7) for c in col), ink=0.3)
    _part(q, [(x - 7.5, base - 8.5), (x - 11, base - 14 - trot)], col, width=1.6, ink=0.3)
    q.fill(q.ellipse(q.mask(), x + 11.2, base - 11.8, x + 12.6, base - 10.6), (30, 26, 24))


def pram(q, x, base):
    """Il passeggino: la navicella con la capotta, il manico e le quattro ruote a raggi."""
    _part(q, [(x - 9, base - 15), (x - 15, base - 24)], (60, 60, 64), width=1.2)
    _part(q, [(x - 9, base - 15), (x + 8, base - 15), (x + 6, base - 8), (x - 7, base - 8)], (92, 104, 110))
    _part(q, [(x - 9, base - 15), (x - 8, base - 22), (x - 2, base - 24), (x + 2, base - 15)], (70, 80, 88))
    for wx in (x - 6, x + 5):
        q.fill(q.ellipse(q.mask(), wx - 3, base - 6, wx + 3, base), (40, 40, 44))
        q.fill(q.ellipse(q.mask(), wx - 1.6, base - 4.6, wx + 1.6, base - 1.4), (140, 140, 140))


def walker_rows():
    """Le righe del foglio dei passanti: (nome, funzione che disegna il fotogramma)."""
    def sheet_row(**kw):
        extra = kw.pop("extra", None)
        def frame(phase):
            q = Quadro(64, 52)
            hand = person(q, 24, 50, phase, **kw)
            if extra:
                extra(q, phase, hand)
            return q.result()
        return frame

    def with_dog(q, phase, hand):
        dog(q, 46, 50, phase)
        h = hand[0]
        q.line([h, (h[0] + 6, h[1] + 4), (55, 39)], 0.4, INK, 0.9)

    def with_pram(q, phase, hand):
        pram(q, 49, 50)

    def with_cane(q, phase, hand):
        h = hand[0]
        q.line([h, (h[0] + 2.5, 50)], 0.9, (96, 70, 46))

    def with_bag(q, phase, hand):
        h = hand[0]
        _part(q, [(h[0] - 2.5, h[1] + 1.5), (h[0] + 3.5, h[1] + 1.5), (h[0] + 4, h[1] + 9), (h[0] - 3, h[1] + 9)], (176, 164, 136))
        q.line([(h[0] + 0.5, h[1] + 2), (h[0] + 0.5, h[1] + 5)], 0.4, (120, 140, 90))  # un porro che spunta

    def with_paper(q, phase, hand):
        h = hand[2]
        _part(q, [(h[0] - 9, h[1] - 7.5), (h[0] + 8, h[1] - 8.5), (h[0] + 7, h[1] - 6), (h[0] - 8, h[1] - 5)], (220, 214, 196))
        for k in range(3):
            q.line([(h[0] - 6 + k * 4, h[1] - 7.2), (h[0] - 4 + k * 4, h[1] - 7.4)], 0.3, (120, 116, 110), 0.8)

    S, H = SKINS, HAIRS
    return [
        ("signore", sheet_row(outfit=((88, 92, 104), (70, 72, 80), (50, 40, 34), S[0], H[2]), coat=True, hair="calvo", cap=(110, 96, 80))),
        ("signora", sheet_row(outfit=((150, 104, 96), (60, 60, 66), (70, 50, 44), S[2], H[1]), skirt=True, hair="chignon")),
        ("cane", sheet_row(outfit=((96, 112, 92), (82, 78, 72), (60, 50, 42), S[1], H[0]), hair="corti", hold="guinzaglio", extra=with_dog)),
        ("corsa", sheet_row(outfit=((150, 156, 164), (54, 58, 70), (210, 210, 206), S[3], H[0]), run=True, lean=0.5, hair="corti")),
        ("passeggino", sheet_row(outfit=((122, 112, 140), (70, 70, 84), (60, 50, 46), S[4], H[4]), hair="lunghi", hold="avanti", extra=with_pram)),
        ("bastone", sheet_row(outfit=((110, 96, 80), (84, 80, 74), (52, 44, 40), S[0], H[2]), coat=True, lean=0.35, hair="calvo", cap=(80, 74, 66), hold="bastone", extra=with_cane)),
        ("laurea", sheet_row(outfit=((54, 58, 70), (48, 50, 58), (40, 34, 30), S[2], H[3]), hair="corti", wreath=True)),
        ("borsa", sheet_row(outfit=((140, 120, 92), (80, 76, 70), (64, 52, 42), S[1], H[1]), skirt=True, hair="lunghi", extra=with_bag)),
        ("giornale", sheet_row(outfit=((104, 100, 92), (66, 66, 70), (50, 42, 36), S[4], H[0]), hair="corti", hold="su", extra=with_paper)),
    ]


def walkers_sheet(frames=8):
    rows = walker_rows()
    imgs = [[fn(i / frames) for i in range(frames)] for _, fn in rows]
    w, h = imgs[0][0].size
    out = Image.new("RGBA", (w * frames, h * len(rows)), (0, 0, 0, 0))
    for r, row in enumerate(imgs):
        for i, im in enumerate(row):
            out.alpha_composite(im, (i * w, r * h))
    out = out.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
    out.save(os.path.join(OUT, "passanti.png"), optimize=True)
    print("scritto passanti.png", out.size, [n for n, _ in rows])


def umbrellas_sheet():
    """Gli ombrelli aperti, quattro colori spenti: la cupola a spicchi con le stecche, il puntale e il manico."""
    frames = []
    for col in ((76, 80, 96), (110, 80, 76), (80, 98, 88), (96, 92, 76)):
        q = Quadro(40, 30)
        m = q.mask()
        top = bezier((3, 18), (6, 6), (34, 6), (37, 18), 16)
        scallop = []
        for k in range(5):
            a, b = 37 - k * 6.8, 37 - (k + 1) * 6.8
            scallop += bezier((a, 18), (a - 1.5, 15.8), (b + 1.5, 15.8), (b, 18), 4)
        q.poly(m, top + scallop)
        _part(q, m, col)
        for k in range(1, 5):
            q.line([(20, 7.5), (37 - k * 6.8, 18)], 0.35, tuple(int(c * 0.7) for c in col), 0.8)
        q.line([(20, 7.5), (20, 4.5)], 0.6, (40, 40, 44))
        q.line([(20, 18), (20, 28), (18.5, 29.5)], 0.55, (40, 40, 44))
        frames.append(q.result())
    sheet(frames, OUT, "ombrelli.png")


# --- il bar dello spritz (#288 passo 3b): tavolino con l'ombrellone, gente seduta, cameriere col vassoio ---
SPRITZ = (214, 120, 60)


def spritz_glass(q, x, y, k=1.0):
    """Il calice dello spritz: coppa con l'arancione, il gambo, la fetta d'arancia e la cannuccia."""
    _part(q, [(x - 1.6 * k, y - 4.2 * k), (x + 1.6 * k, y - 4.2 * k), (x + 1.2 * k, y - 1.2 * k), (x - 1.2 * k, y - 1.2 * k)], SPRITZ, ink=0.3)
    q.line([(x, y - 1.2 * k), (x, y)], 0.3 * k, (200, 210, 214))
    q.line([(x - 1.0 * k, y), (x + 1.0 * k, y)], 0.3 * k, (200, 210, 214))
    q.fill(q.ellipse(q.mask(), x + 0.6 * k, y - 5.4 * k, x + 2.4 * k, y - 3.6 * k), (236, 160, 70))
    q.line([(x - 0.4 * k, y - 4 * k), (x - 1.2 * k, y - 6.4 * k)], 0.25 * k, (60, 120, 90))


def bar_table():
    """L'ombrellone a spicchi color crema con la mantovana a festoni, il palo, il tavolino tondo di marmo con il
    piede di ghisa e due sedie da bistrot. Piedi al centro in basso."""
    q = Quadro(72, 74)
    cx, base = 36, 72
    canvas, stripe = (222, 212, 186), (176, 150, 116)
    _part(q, [(cx, base - 18), (cx, base - 62)], (70, 66, 62), width=1.3)
    top = bezier((cx - 33, base - 52), (cx - 22, base - 66), (cx + 22, base - 66), (cx + 33, base - 52), 18)
    m = q.poly(q.mask(), top + [(cx + 33, base - 50), (cx - 33, base - 50)])
    _part(q, m, canvas)
    for k in (-2, 0, 2):
        q.fill(q.intersect(q.poly(q.mask(), [(cx, base - 64), (cx + k * 11 - 5, base - 50), (cx + k * 11 + 5, base - 50)]), m), stripe, 0.85)
    val = []
    for k in range(6):  # la mantovana a festoni
        a, b = cx - 33 + k * 11, cx - 33 + (k + 1) * 11
        val += bezier((a, base - 50), (a + 2, base - 45), (b - 2, base - 45), (b, base - 50), 5)
    _part(q, val + [(cx + 33, base - 51), (cx - 33, base - 51)], stripe)
    q.fill(q.ellipse(q.mask(), cx - 1.8, base - 67.5, cx + 1.8, base - 64), (90, 84, 76))
    for side in (-1, 1):  # sedie di ferro, di fianco
        sx = cx + side * 15
        q.line([(sx - side * 4, base), (sx - side * 4, base - 10), (sx + side * 4, base - 10), (sx + side * 4, base)], 0.7, (58, 56, 58))
        q.line([(sx + side * 4, base - 10), (sx + side * 5, base - 20)], 0.7, (58, 56, 58))
        q.line([(sx + side * 4.5, base - 15), (sx - side * 1, base - 15)], 0.5, (58, 56, 58))
    q.line([(cx, base - 16), (cx, base - 2)], 1.0, (52, 52, 56))
    _part(q, [(cx - 6, base), (cx + 6, base), (cx + 3, base - 2), (cx - 3, base - 2)], (52, 52, 56), ink=0.3)
    _part(q, q.ellipse(q.mask(), cx - 10, base - 19, cx + 10, base - 15), (226, 222, 214))
    spritz_glass(q, cx - 4, base - 18, 0.9)  # il terzo spritz, ancora pieno
    return q.result()


def seated(outfit, pose, hair):
    """Una persona seduta di profilo, rivolta a destra verso il tavolino: busto, testa, cosce in avanti, gambe giù,
    il braccio con lo spritz. pose: 0 sul tavolo, 1 a metà, 2 alla bocca, 3 brindisi verso il centro."""
    q = Quadro(34, 42)
    jacket, pants, shoes, skin, hair_col = outfit
    base, x = 40, 13
    seat = (x, base - 13)
    sh = (x + 1, base - 26)
    _part(q, [seat, (x + 9, base - 13), (x + 9, base - 1)], pants, width=3.2)  # coscia e gamba davanti
    _part(q, q.ellipse(q.mask(), x + 8, base - 2.2, x + 13, base + 0.4), shoes)
    _part(q, [(sh[0] - 3, sh[1]), (sh[0] + 3, sh[1] + 0.5), (seat[0] + 3.5, seat[1] + 1), (seat[0] - 3.5, seat[1] + 1)], jacket)
    head = (sh[0] + 1.5, sh[1] - 5)
    q.fill(q.smooth(q.stroke(q.mask(), [sh, head], 2.2), 0.3), skin)
    hm = q.ellipse(q.mask(), head[0] - 3.4, head[1] - 4, head[0] + 3.2, head[1] + 3.6)
    q.poly(hm, [(head[0] + 2.8, head[1] - 0.5), (head[0] + 4.3, head[1] + 0.8), (head[0] + 2.8, head[1] + 1.3)])
    _part(q, hm, skin)
    q.fill(q.ellipse(q.mask(), head[0] + 1.2, head[1] - 1.0, head[0] + 2.2, head[1]), (40, 34, 30))
    if hair == "lunghi":
        _part(q, [(head[0] - 4, head[1] + 5.6), (head[0] - 3.7, head[1] - 3.2), (head[0] - 0.5, head[1] - 4.6), (head[0] + 2.7, head[1] - 3.9), (head[0] + 3.2, head[1] - 1.8), (head[0] + 0.2, head[1] - 2.6), (head[0] - 1.4, head[1] + 1), (head[0] - 1.6, head[1] + 6)], hair_col, ink=0.4)
    else:
        _part(q, [(head[0] - 3.6, head[1] + 1.4), (head[0] - 3.5, head[1] - 3), (head[0] - 0.9, head[1] - 4.5), (head[0] + 2.5, head[1] - 3.9), (head[0] + 3.2, head[1] - 2.1), (head[0] + 0.4, head[1] - 2.4), (head[0] - 1.1, head[1] + 0.2)], hair_col, ink=0.4)
    hands = [(x + 9, base - 15), (x + 8, base - 21), (head[0] + 3.5, head[1] + 3), (x + 15, base - 27)]
    elbows = [(x + 4, base - 16), (x + 5, base - 20), (x + 6, base - 21), (x + 8, base - 25)]
    hand, elbow = hands[pose], elbows[pose]
    _part(q, [sh, elbow, hand], jacket, width=2.6)
    _part(q, q.ellipse(q.mask(), hand[0] - 1.2, hand[1] - 1.2, hand[0] + 1.2, hand[1] + 1.2), skin, ink=0.3)
    spritz_glass(q, hand[0] + 0.8, hand[1] + (0.5 if pose < 2 else 1.5), 0.9)
    return q.result()


def bar_sheets():
    sheet([bar_table()], OUT, "bar-tavolo.png")
    outfits = [((150, 104, 96), (64, 64, 70), (70, 50, 44), SKINS[2], HAIRS[1], "lunghi"),
               ((86, 98, 112), (70, 70, 76), (50, 42, 36), SKINS[0], HAIRS[0], "corti"),
               ((122, 132, 100), (84, 78, 70), (60, 48, 40), SKINS[3], HAIRS[3], "corti")]
    rows = [[seated(o[:5], pose, o[5]) for pose in range(4)] for o in outfits]
    w, h = rows[0][0].size
    out = Image.new("RGBA", (w * 4, h * len(rows)), (0, 0, 0, 0))
    for r, row in enumerate(rows):
        for i, im in enumerate(row):
            out.alpha_composite(im, (i * w, r * h))
    out.save(os.path.join(OUT, "bar-seduti.png"), optimize=True)
    print("scritto bar-seduti.png", out.size)
    # il cameriere: camicia bianca, gilet nero, il vassoio alto con tre spritz
    frames = []
    for i in range(8):
        q = Quadro(40, 56)
        hand, back, head = person(q, 18, 54, i / 8, ((226, 222, 214), (40, 40, 44), (30, 28, 28), SKINS[1], HAIRS[0]), hair="corti")
        q.fill(q.smooth(q.poly(q.mask(), [(14.6, 54 - 38 * 0.77), (20.6, 54 - 38 * 0.77), (21, 54 - 38 * 0.5), (14.4, 54 - 38 * 0.5)]), 0.3), (44, 44, 48), 0.9)  # gilet
        tx, ty = head[0] + 7, head[1] - 2
        q.line([(head[0] - 1, head[1] + 6), (tx - 1, ty + 4), (tx, ty + 0.5)], 1.3, (226, 222, 214))
        _part(q, [(tx - 7, ty), (tx + 7, ty), (tx + 6, ty + 1.4), (tx - 6, ty + 1.4)], (170, 170, 166), ink=0.35)
        for gx in (-4, 0, 4):
            spritz_glass(q, tx + gx, ty, 0.8)
        frames.append(q.result())
    sheet(frames, OUT, "cameriere.png")


# --- traffico (#288 passo 3c): macchine, furgone, Vespa, bici, autobus e il tram, dipinti di fianco verso destra ---
GLASS, GLASS_L = (70, 82, 96), (150, 170, 184)


def wheel(q, x, y, r):
    """La ruota: gomma scura, il cerchione chiaro con i bulloni, l'ombra nel passaruota."""
    _part(q, q.ellipse(q.mask(), x - r, y - r, x + r, y + r), (34, 34, 38), ink=0.4)
    _part(q, q.ellipse(q.mask(), x - r * 0.55, y - r * 0.55, x + r * 0.55, y + r * 0.55), (168, 170, 172), ink=0.3)
    for k in range(4):
        a = k * math.pi / 2 + 0.4
        q.fill(q.ellipse(q.mask(), x + math.cos(a) * r * 0.28 - 0.4, y + math.sin(a) * r * 0.28 - 0.4, x + math.cos(a) * r * 0.28 + 0.4, y + math.sin(a) * r * 0.28 + 0.4), (90, 90, 94))


def car(L, H, col, profile, roof=None, rack=False, seed=0):
    """Una macchina di fianco: profilo di Bézier dal paraurti dietro al muso (profile: "500" tonda, "berlina",
    "squadrata", "familiare"), i vetri con il riflesso, le portiere, le maniglie, i fari, le ruote."""
    W = L + 8
    q = Quadro(W, H + 6)
    x0, x1, base = 4, 4 + L, H + 4
    wy = base - H * 0.18  # centro ruote
    r = H * 0.2
    belt = base - H * 0.52  # linea di cintura sotto i vetri
    top = base - H
    if profile == "500":
        body = bezier((x0, base - H * 0.25), (x0 - 1, top + H * 0.1), (x0 + L * 0.35, top - 1), (x0 + L * 0.62, top + H * 0.06), 16) + \
            bezier((x0 + L * 0.62, top + H * 0.06), (x0 + L * 0.8, belt - 2), (x1 + 1, belt), (x1, base - H * 0.25), 12)
        win = [(x0 + L * 0.12, belt), (x0 + L * 0.2, top + H * 0.14), (x0 + L * 0.55, top + H * 0.12), (x0 + L * 0.66, belt)]
    elif profile == "squadrata":
        body = [(x0, base - H * 0.25), (x0, top + H * 0.08), (x0 + L * 0.06, top), (x0 + L * 0.66, top), (x0 + L * 0.76, belt - 1), (x1 - 1, belt + 1), (x1, base - H * 0.25)]
        win = [(x0 + L * 0.06, belt), (x0 + L * 0.08, top + H * 0.1), (x0 + L * 0.62, top + H * 0.1), (x0 + L * 0.71, belt)]
    elif profile == "familiare":
        body = [(x0, base - H * 0.28), (x0 + 1, top + H * 0.06), (x0 + L * 0.06, top), (x0 + L * 0.62, top), (x0 + L * 0.74, belt - 1)] + bezier((x0 + L * 0.74, belt - 1), (x0 + L * 0.85, belt), (x1, belt + 1), (x1, base - H * 0.28), 6)
        win = [(x0 + L * 0.05, belt), (x0 + L * 0.07, top + H * 0.1), (x0 + L * 0.6, top + H * 0.1), (x0 + L * 0.69, belt)]
    else:  # berlina
        body = bezier((x0, base - H * 0.3), (x0, belt - 2), (x0 + L * 0.1, belt - 3), (x0 + L * 0.2, belt - 3), 6) + \
            bezier((x0 + L * 0.2, belt - 3), (x0 + L * 0.28, top), (x0 + L * 0.55, top - 1), (x0 + L * 0.68, belt - 3), 12) + \
            bezier((x0 + L * 0.68, belt - 3), (x0 + L * 0.85, belt - 2), (x1, belt), (x1, base - H * 0.3), 6)
        win = [(x0 + L * 0.22, belt - 1), (x0 + L * 0.3, top + H * 0.12), (x0 + L * 0.53, top + H * 0.11), (x0 + L * 0.64, belt - 1)]
    body = body + [(x1, base - H * 0.15), (x0, base - H * 0.15)]
    m = q.smooth(q.poly(q.mask(), body), 0.5)
    q.fill(m, col)
    q.fill(q.inner_shadow(m, 0, -H * 0.25, H * 0.12), tuple(int(c * 0.72) for c in col), 0.9)  # la fiancata in ombra sotto
    q.fill(q.rim(m, -1, -1.5, 0.8), tuple(min(255, int(c * 1.25)) for c in col), 0.7)
    # i vetri: scuri con il riflesso in diagonale, divisi dal montante
    wm = q.smooth(q.poly(q.mask(), win), 0.3)
    q.fill(wm, GLASS)
    q.fill(q.intersect(q.poly(q.mask(), [(win[0][0] + 4, belt), (win[1][0] + 8, top), (win[1][0] + 13, top), (win[0][0] + 9, belt)]), wm), GLASS_L, 0.6)
    mid = (win[0][0] + win[3][0]) / 2
    q.line([(mid, belt), (mid + 1, top + H * 0.1)], 1.0, col)
    q.outline(wm, 0.4, INK)
    # portiere, maniglie, paraurti, fari
    q.line([(mid, belt), (mid - 1, base - H * 0.2)], 0.35, tuple(int(c * 0.55) for c in col), 0.9)
    q.line([(mid + L * 0.08, belt + 2), (mid + L * 0.12, belt + 2)], 0.5, (60, 60, 64))
    q.line([(mid - L * 0.12, belt + 2), (mid - L * 0.08, belt + 2)], 0.5, (60, 60, 64))
    _part(q, [(x0 - 1, base - H * 0.3), (x0 + 3, base - H * 0.3), (x0 + 3, base - H * 0.16), (x0 - 1, base - H * 0.16)], (130, 130, 132), ink=0.3)
    _part(q, [(x1 - 3, base - H * 0.3), (x1 + 1, base - H * 0.3), (x1 + 1, base - H * 0.16), (x1 - 3, base - H * 0.16)], (130, 130, 132), ink=0.3)
    q.fill(q.ellipse(q.mask(), x1 - 3.5, belt + 1, x1 - 0.5, belt + 3.5), (236, 226, 190))
    q.fill(q.ellipse(q.mask(), x0 + 0.5, belt + 1.5, x0 + 2.5, belt + 3.5), (176, 70, 60))
    q.outline(m, 0.6, INK)
    if rack:  # il portapacchi sul tetto
        q.line([(x0 + L * 0.15, top - 1.5), (x0 + L * 0.6, top - 1.5)], 0.7, (60, 60, 62))
    for wx in (x0 + L * 0.2, x1 - L * 0.2):  # passaruota scuro, poi la ruota
        q.fill(q.ellipse(q.mask(), wx - r * 1.25, wy - r * 1.25, wx + r * 1.25, wy + r * 1.25), (30, 30, 34), 0.8)
        wheel(q, wx, wy, r)
    return q.result()


def rider_on(q, x, seat_y, outfit, pedal=None, helmet=None):
    """Chi guida la Vespa o pedala: busto un po' in avanti, braccia al manubrio, gamba che spinge il pedale."""
    jacket, pants, shoes, skin, hair = outfit
    sh = (x + 3, seat_y - 12)
    hip = (x, seat_y)
    _part(q, [hip, sh, (sh[0] + 3, sh[1] + 1), (hip[0] + 4, hip[1])], jacket)
    if pedal is not None:
        for side in (-1, 1):
            a = pedal + (0 if side > 0 else math.pi)
            foot = (x + 6 + math.cos(a) * 3.5, seat_y + 11 + math.sin(a) * 3.5)
            knee = (x + 5 + (foot[0] - x) * 0.4, seat_y + 2 - 2 * side)
            _part(q, [hip, knee, foot], pants if side > 0 else tuple(int(c * 0.8) for c in pants), width=2.4)
    else:
        _part(q, [hip, (x + 7, seat_y + 1), (x + 8, seat_y + 9)], pants, width=2.6)
    head = (sh[0] + 1.5, sh[1] - 4.5)
    _part(q, q.ellipse(q.mask(), head[0] - 3, head[1] - 3.4, head[0] + 3, head[1] + 3.2), skin)
    if helmet:
        _part(q, [(head[0] - 3.4, head[1] + 0.5), (head[0] - 3, head[1] - 3), (head[0], head[1] - 4.2), (head[0] + 3, head[1] - 3), (head[0] + 3.4, head[1] - 0.5)], helmet)
    else:
        _part(q, [(head[0] - 3.2, head[1] + 1), (head[0] - 3, head[1] - 2.6), (head[0], head[1] - 3.8), (head[0] + 2.6, head[1] - 2.8), (head[0], head[1] - 2)], hair, ink=0.4)
    _part(q, [sh, (sh[0] + 6, sh[1] + 5), (sh[0] + 11, sh[1] + 4)], jacket, width=2.2)


def vespa_frames():
    out = []
    for i in range(2):
        q = Quadro(40, 42, origin=(0, -8))  # spazio sopra per la testa
        base = 32
        col = (150, 168, 160)  # verde acqua spento, la Vespa classica
        wheel(q, 9, base - 3.5, 3.5)
        wheel(q, 31, base - 3.5, 3.5)
        _part(q, bezier((4, base - 6), (5, base - 15), (14, base - 14), (18, base - 12), 8) + [(26, base - 6)], col)  # la pancia
        _part(q, [(28, base - 4), (31, base - 20), (34, base - 20), (32, base - 4)], col)  # lo scudo
        _part(q, [(26, base - 8), (33, base - 8), (33, base - 5), (26, base - 5)], (60, 62, 66), ink=0.3)  # pedana
        q.line([(32, base - 20), (29, base - 24), (34, base - 24)], 0.8, (60, 60, 64))
        q.fill(q.ellipse(q.mask(), 32.5, base - 23, 35, base - 20.5), (236, 226, 190))
        _part(q, [(7, base - 15), (18, base - 15), (17, base - 13), (8, base - 13)], (60, 46, 40), ink=0.3)  # sella
        rider_on(q, 12, base - 15 + (0.4 if i else 0), ((120, 96, 76), (60, 62, 70), (40, 34, 30), SKINS[1], HAIRS[0]), helmet=(200, 196, 186))
        out.append(q.result())
    return out


def bike_frames(n=4):
    out = []
    for i in range(n):
        q = Quadro(40, 48, origin=(0, -8))
        base = 38
        for wx in (9, 31):
            _part(q, q.ellipse(q.mask(), wx - 6.5, base - 13, wx + 6.5, base), (40, 40, 42), ink=0.3)
            q.fill(q.ellipse(q.mask(), wx - 5.5, base - 12, wx + 5.5, base - 1), (0, 0, 0, 0))
            q.img.paste((0, 0, 0, 0), None, q.ellipse(q.mask(), wx - 5.4, base - 11.9, wx + 5.4, base - 1.1))
            for k in range(6):
                a = k * math.pi / 3 + i * 0.4
                q.line([(wx, base - 6.5), (wx + math.cos(a) * 5.4, base - 6.5 + math.sin(a) * 5.4)], 0.2, (120, 120, 124), 0.8)
        frame = (106, 120, 108)
        q.line([(9, base - 6.5), (19, base - 7), (16, base - 19), (9, base - 6.5)], 1.1, frame)
        q.line([(19, base - 7), (28, base - 19), (16, base - 19)], 1.1, frame)
        q.line([(28, base - 19), (31, base - 6.5)], 1.1, frame)
        q.line([(27, base - 22), (29, base - 21), (31, base - 22)], 0.8, (50, 50, 52))
        _part(q, [(13, base - 21.5), (19, base - 21.5), (18, base - 19.5), (14, base - 19.5)], (50, 40, 36), ink=0.3)
        rider_on(q, 15, base - 21, ((84, 104, 120), (70, 70, 76), (50, 42, 36), SKINS[2], HAIRS[4]), pedal=i / n * math.tau)
        out.append(q.result())
    return out


def bus():
    """L'autobus di città: lungo, con i finestrini, le porte a soffietto, il tetto chiaro e la fascia colorata."""
    L, H = 170, 44
    q = Quadro(L + 6, H + 6)
    x0, x1, base = 3, 3 + L, H + 4
    col, band = (196, 190, 172), (150, 120, 84)
    m = q.smooth(q.poly(q.mask(), [(x0, base - 6), (x0, base - H + 4), (x0 + 3, base - H), (x1 - 6, base - H), (x1, base - H + 6), (x1, base - 6)]), 0.6)
    q.fill(m, col)
    q.fill(q.intersect(q.poly(q.mask(), [(x0, base - 16), (x1, base - 16), (x1, base - 10), (x0, base - 10)]), m), band)
    q.fill(q.inner_shadow(m, 0, -10, 4), (120, 116, 104), 0.8)
    for k in range(7):
        wx = x0 + 6 + k * 22
        wm = q.smooth(q.poly(q.mask(), [(wx, base - 36), (wx + 18, base - 36), (wx + 18, base - 22), (wx, base - 22)]), 0.4)
        q.fill(wm, GLASS)
        q.fill(q.intersect(q.poly(q.mask(), [(wx + 3, base - 22), (wx + 9, base - 36), (wx + 12, base - 36), (wx + 6, base - 22)]), wm), GLASS_L, 0.5)
        if k % 2:
            q.fill(q.ellipse(q.mask(), wx + 7, base - 31, wx + 12, base - 25), (100, 84, 74), 0.8)  # un passeggero
    for dx in (x0 + 50, x1 - 30):  # porte
        _part(q, [(dx, base - 38), (dx + 12, base - 38), (dx + 12, base - 7), (dx, base - 7)], GLASS, ink=0.4)
        q.line([(dx + 6, base - 38), (dx + 6, base - 7)], 0.4, (40, 40, 44))
    q.fill(q.poly(q.mask(), [(x1 - 4, base - 38), (x1, base - 34), (x1, base - 20), (x1 - 4, base - 20)]), GLASS)
    q.fill(q.ellipse(q.mask(), x1 - 3, base - 13, x1, base - 10), (236, 226, 190))
    q.outline(m, 0.7, INK)
    for wx in (x0 + 28, x1 - 34):
        wheel(q, wx, base - 5, 6)
    return q.result()


def tram():
    """Il tram di Padova come nella foto di Riccardo (#288): blu, a quattro casse con i soffietti, il muso tondo con il
    grande parabrezza inclinato, la fascia dei finestrini scura incorniciata di blu, le porte, la gonna più scura
    che nasconde le ruote gommate, il tetto grigio con le carenature e il pantografo. Blu un po' spento: sta in
    fondo alla strada, dietro al palco."""
    L, H = 300, 52
    q = Quadro(L + 12, H + 24)
    x0, base = 4, H + 22
    blue, blue_d, blue_l = (52, 100, 160), (36, 70, 118), (92, 140, 196)
    roof = (176, 180, 186)
    segs = [(x0, x0 + 78), (x0 + 82, x0 + 152), (x0 + 156, x0 + 226), (x0 + 230, x0 + 304)]
    for k, (a, b) in enumerate(segs):
        nose = k == 3
        top = base - H
        if nose:  # il muso tondo con il parabrezza inclinato
            pts = [(a, top + 2), (b - 22, top + 2)] + bezier((b - 22, top + 2), (b - 6, top + 3), (b + 2, base - 30), (b + 3, base - 14), 10) + [(b + 1, base - 4), (a, base - 4)]
        else:
            pts = [(a, top + 2), (b, top + 2), (b, base - 4), (a, base - 4)]
        m = q.smooth(q.poly(q.mask(), pts), 0.6)
        q.fill(m, blue)
        q.fill(q.intersect(q.poly(q.mask(), [(a, base - 13), (b + 4, base - 13), (b + 4, base - 4), (a, base - 4)]), m), blue_d)  # la gonna
        q.fill(q.inner_shadow(m, 0, -8, 3.5), blue_d, 0.7)
        q.fill(q.rim(m, -1, -2, 1.2), blue_l, 0.8)
        # la fascia dei finestrini, scura, con i montanti blu e il riflesso
        wx0, wx1 = a + 5, (b - 26 if nose else b - 5)
        wm = q.smooth(q.poly(q.mask(), [(wx0, base - 44), (wx1, base - 44), (wx1, base - 20), (wx0, base - 20)]), 0.4)
        q.fill(wm, (40, 50, 66))
        for gx in range(int(wx0) + 3, int(wx1) - 4, 16):
            q.fill(q.intersect(q.poly(q.mask(), [(gx, base - 20), (gx + 6, base - 44), (gx + 9, base - 44), (gx + 3, base - 20)]), wm), (120, 146, 170), 0.5)
            q.line([(gx + 13, base - 44), (gx + 13, base - 20)], 0.8, blue)
        q.fill(q.ellipse(q.mask(), wx0 + 8, base - 33, wx0 + 13, base - 27), (110, 92, 80), 0.8)  # un passeggero
        q.outline(wm, 0.4, INK)
        if nose:
            ws = q.smooth(q.poly(q.mask(), [(b - 24, base - 44)] + bezier((b - 21, base - 44), (b - 8, base - 43), (b - 1, base - 34), (b + 1, base - 24), 8) + [(b - 24, base - 22)]), 0.4)
            q.fill(ws, (46, 58, 76))
            q.fill(q.intersect(q.poly(q.mask(), [(b - 18, base - 22), (b - 10, base - 44), (b - 6, base - 44), (b - 13, base - 22)]), ws), (140, 166, 190), 0.6)
            q.outline(ws, 0.4, INK)
            q.fill(q.ellipse(q.mask(), b - 4, base - 12, b, base - 9), (236, 230, 200))  # fanale
            q.line([(b - 30, base - 9), (b - 8, base - 9)], 0.6, (210, 200, 160), 0.8)  # la striscia gialla del muso
        else:
            dx = (a + b) / 2 - 7  # la porta, con i vetri
            _part(q, [(dx, base - 45), (dx + 14, base - 45), (dx + 14, base - 5), (dx, base - 5)], blue_d, ink=0.4)
            for ddx in (dx + 2, dx + 8):
                q.fill(q.poly(q.mask(), [(ddx, base - 42), (ddx + 4, base - 42), (ddx + 4, base - 16), (ddx, base - 16)]), (52, 64, 82))
        # il tetto grigio con la carenatura
        _part(q, [(a + 3, top + 2), (b - (20 if nose else 3), top + 2), (b - (24 if nose else 6), top - 3), (a + 6, top - 3)], roof, ink=0.4)
        q.outline(m, 0.7, INK)
    for a in (x0 + 78, x0 + 152, x0 + 226):  # soffietti scuri
        _part(q, [(a, base - H + 6), (a + 4, base - H + 6), (a + 4, base - 6), (a, base - 6)], (54, 58, 66), ink=0.3)
    pc = x0 + 117  # il pantografo
    q.line([(pc - 10, base - H - 3), (pc + 2, base - H - 18), (pc + 12, base - H - 3)], 0.8, (60, 60, 62))
    q.line([(pc - 7, base - H - 18), (pc + 11, base - H - 18)], 1.0, (60, 60, 62))
    return q.result()


def traffic_sheets():
    cars = [car(64, 26, c, p, rack=r) for c, p, r in (
        ((206, 196, 168), "500", False), ((150, 154, 156), "squadrata", False), ((112, 124, 140), "berlina", False),
        ((130, 140, 116), "familiare", True), ((160, 120, 108), "berlina", False), ((96, 98, 104), "squadrata", True))]
    sheet(cars, OUT, "auto.png")
    vans = [car(82, 36, c, "squadrata", rack=r) for c, r in (((196, 192, 182), False), ((150, 160, 170), True))]
    sheet(vans, OUT, "furgone.png")
    sheet(vespa_frames(), OUT, "vespa.png")
    sheet(bike_frames(), OUT, "bici.png")
    sheet([bus()], OUT, "bus.png")
    sheet([tram()], OUT, "tram.png")


# --- l'acqua della fontana (#288 passo 3d): lo zampillo a riposo e il getto alto, dipinti e semitrasparenti ---
FOAM = (244, 250, 250)
AQUA = (196, 226, 228)


def _water_column(q, cx, base, h, w, phase, seed):
    """Una colonna d'acqua: filetti che ondeggiano, si gonfiano e si spezzano, il cuore più chiaro, la corona
    che si apre in cima e ricade in filetti e gocce dentro una nebbiolina, e la schiuma irregolare dove l'acqua
    torna nella vasca."""
    rng = random.Random(seed)
    col = q.mask()
    for k in range(12):
        u = (k / 11 - 0.5)
        width = w * rng.uniform(0.05, 0.12)
        for j in range(16):  # ogni filetto è fatto di tratti con lo spessore che cambia: l'acqua non è un tubo
            v0, v1 = j / 16, (j + 1) / 16
            if rng.random() < 0.08:
                continue  # un filetto che si spezza
            wob = math.sin(v0 * 11 + phase * math.tau + k * 1.3)
            p0 = (cx + w * (0.5 - 0.25 * v0) * u + wob * 1.4, base - h * v0)
            p1 = (cx + w * (0.5 - 0.25 * v1) * u + math.sin(v1 * 11 + phase * math.tau + k * 1.3) * 1.4, base - h * v1)
            q.stroke(col, [p0, p1], width * (0.7 + 0.6 * abs(math.sin(v0 * 7 + k + phase * 5))))
    q.fill(q.soften(col, 0.5), AQUA, 0.6)
    core = q.mask()
    for j in range(10):
        v0, v1 = j / 10, (j + 1) / 10
        q.stroke(core, [(cx - w * 0.04 + math.sin(v0 * 9 + phase * 6) * 0.8, base - h * v0), (cx - w * 0.04 + math.sin(v1 * 9 + phase * 6) * 0.8, base - h * v1)], w * (0.08 + 0.05 * math.sin(v0 * 13 + phase * 7)))
    q.fill(q.soften(core, 0.8), FOAM, 0.9)
    # la nebbiolina attorno alla colonna e alla corona
    mist = q.mask()
    q.ellipse(mist, cx - w * 0.9, base - h - 14, cx + w * 0.9, base - h + 22)
    q.poly(mist, [(cx - w * 0.6, base), (cx + w * 0.6, base), (cx + w * 0.3, base - h), (cx - w * 0.3, base - h)])
    q.fill(q.soften(mist, 6), (255, 255, 255), 0.22)
    # la corona: si apre a ombrello e ricade, filetti che si assottigliano
    for k in range(14):
        side = -1 if k % 2 else 1
        reach = w * rng.uniform(0.5, 1.0)
        fall = h * rng.uniform(0.1, 0.32)
        top = (cx + side * 1.5, base - h)
        pts = bezier(top, (cx + side * reach * 0.4, base - h - 7), (cx + side * reach * 0.9, base - h - 3), (cx + side * reach, base - h + fall), 12)
        upto = int(len(pts) * (0.5 + 0.5 * ((phase + k * 0.13) % 1.0)))
        m = q.mask()
        for j in range(upto - 1):
            q.stroke(m, [pts[j], pts[j + 1]], 2.2 * (1 - j / len(pts)) + 0.5)
        q.fill(q.soften(m, 0.35), FOAM, 0.85)
    for k in range(int(18 + w * 0.25)):  # gocce che cadono, un po' allungate
        side = rng.choice((-1, 1))
        u = (phase * 1.7 + k * 0.137) % 1.0
        x = cx + side * w * rng.uniform(0.3, 0.95) * (0.4 + u * 0.6)
        y = base - h + h * 0.9 * u * u
        r = rng.uniform(0.6, 1.4) * (1 - 0.4 * u)
        q.fill(q.soften(q.ellipse(q.mask(), x - r, y - r * 1.6, x + r, y + r * 1.2), 0.3), FOAM, 0.9 - 0.4 * u)
    # la schiuma alla base: tante bolle unite e lisciate in una macchia irregolare
    foam = q.mask()
    for k in range(18):
        fx = cx + rng.uniform(-w * 0.75, w * 0.75) + math.sin(phase * math.tau + k) * 1.2
        r = rng.uniform(1.5, 4.0)
        q.ellipse(foam, fx - r * 1.4, base - r * 1.6, fx + r * 1.4, base + 0.8)
    foam = q.smooth(foam, 0.7)
    q.fill(foam, FOAM, 0.85)
    q.fill(q.inner_shadow(foam, 0, -1.5, 0.8), AQUA, 0.6)


def fountain_water_sheets():
    idle = []
    for i in range(6):
        q = Quadro(110, 96)
        _water_column(q, 55, 92, 66, 42, i / 6, 3)
        idle.append(q.result())
    sheet(idle, OUT, "zampillo.png")
    jet = []
    for i in range(4):
        q = Quadro(150, 350)
        _water_column(q, 75, 344, 318, 70, i / 4, 7)
        jet.append(q.result())
    sheet(jet, OUT, "getto.png")


# --- la ruota d'acqua (#378, idea di Nicola): le tazze di marmo portate in giro dagli spruzzi ---
MARBLE_TOP = (234, 228, 214)  # il piano della tazza, dove si sta: il più chiaro (stile, sezione 7)
MARBLE = (206, 200, 186)
MARBLE_DARK = (150, 144, 132)


def _tazza(phase):
    """Una tazza di marmo vista un po' dall'alto, come quelle delle fontane: il piano largo con un velo d'acqua, il
    labbro con la modanatura, il fondo che si stringe verso il bottone dove batte lo spruzzo, e l'acqua che trabocca
    dal bordo in filetti e gocce. Il piano su cui si sta è a y 0, largo 120 (la piattaforma); fotogramma 150×48."""
    q = Quadro(150, 48, origin=(-75, -12))
    ink = (70, 66, 60)
    # il fondo: una coppa che si stringe, con due anelli scolpiti
    bowl = q.mask()
    left = bezier((-60, 3), (-52, 14), (-24, 20), (-11, 26), 16)
    q.poly(bowl, left + [(-x, y) for x, y in reversed(left)])
    q.ellipse(bowl, -12, 22, 12, 30)  # il bottone sotto
    bowl = q.smooth(bowl, 0.8)
    q.fill(bowl, MARBLE)
    q.fill(q.inner_shadow(bowl, -14, -6, 6), MARBLE_DARK, 0.85)
    q.fill(q.rim(bowl, -2, -1, 1.5), MARBLE_TOP, 0.6)
    rings = q.mask()
    for y, w in ((9, 52), (17, 30)):
        q.stroke(rings, bezier((-w, y - 1), (-w * 0.5, y + 2.2), (w * 0.5, y + 2.2), (w, y - 1), 12), 0.7)
    q.fill(q.intersect(rings, bowl), MARBLE_DARK, 0.9)
    q.outline(bowl, 0.7, ink)
    # il labbro: lo spessore davanti, poi il piano ovale visto dall'alto
    lip = q.mask()
    q.ellipse(lip, -63, -4.5, 63, 7)
    q.fill(lip, MARBLE)
    q.fill(q.inner_shadow(lip, 0, -3, 1.5), MARBLE_DARK, 0.7)
    top = q.mask()
    q.ellipse(top, -63, -5, 63, 3.5)
    q.fill(top, MARBLE_TOP)
    q.fill(q.inner_shadow(top, -8, 0, 4), MARBLE, 0.6)
    q.outline(q.union(lip, top), 0.75, ink)
    # il velo d'acqua sul piano, con i riflessi che scorrono
    film = q.ellipse(q.mask(), -55, -3.6, 55, 2.2)
    q.fill(film, AQUA, 0.45)
    shine = q.mask()
    for k in range(5):
        x = -48 + ((phase * 40 + k * 23) % 96)
        q.stroke(shine, [(x - 5, -1.2 + (k % 2)), (x + 5, -1.6 + (k % 2))], 0.6)
    q.fill(q.intersect(q.soften(shine, 0.3), film), FOAM, 0.9)
    # l'acqua che trabocca: filetti ai lati e davanti, e gocce che cadono
    rng = random.Random(378)
    falls = q.mask()
    for side in (-1, 1):
        for k in range(3):
            x0 = side * (60 - k * 2.2)
            drop = 10 + 8 * ((phase + k * 0.33 + (side > 0) * 0.5) % 1.0)
            q.stroke(falls, bezier((x0, 1.5), (x0 + side * 2.5, 4), (x0 + side * 3, 8), (x0 + side * 2.6, 1.5 + drop), 8), 0.9 - 0.2 * k)
    for x0 in (-34, -8, 21, 44):
        drop = 4 + 7 * ((phase * 1.3 + x0 * 0.07) % 1.0)
        q.stroke(falls, [(x0, 6.5), (x0 + 0.4, 6.5 + drop)], 0.6)
    q.fill(q.soften(falls, 0.35), FOAM, 0.75)
    for k in range(10):
        u = (phase + k * 0.173) % 1.0
        side = -1 if k % 2 else 1
        x = side * rng.uniform(40, 66)
        y = 6 + 26 * u * u
        r = 0.9 * (1 - 0.4 * u)
        q.fill(q.soften(q.ellipse(q.mask(), x - r, y - r * 1.5, x + r, y + r), 0.25), FOAM, 0.85 - 0.5 * u)
    return q.result()


def tazza_sheet():
    frames = [_tazza(i / 4) for i in range(4)]
    sheet(frames, OUT, "tazza.png")
    # la tazza in cima alla giostra (#378), larga 180: la stessa tazza allargata, il piano resta alla stessa altezza
    big = [f.resize((420, f.height), Image.LANCZOS) for f in frames]
    sheet(big, OUT, "tazza-grande.png")


# --- il canale dell'Isola Memmia (#378, idea di Riccardo): acqua stagnante e chi ci galleggia ---
def canal_tile():
    """Una striscia d'acqua stagnante larga 960 e alta 300 (pixel di mondo) che si ripete in orizzontale: il pelo
    dell'acqua in cima con la patina d'alghe, le lenti d'acqua e qualche foglia, i riflessi chiari del cielo appena
    sotto, poi il verde torbido che si scurisce andando giù. Semitrasparente in cima: chi ci cade si vede sparire."""
    W, H = 960, 300
    q = Quadro(W, H)
    rng = random.Random(3780)
    # la tinta: dal verde oliva del pelo al verde bottiglia del fondo, sempre più coprente (una sfumatura continua)
    grad = Image.new("RGBA", (1, q.size[1]))
    for py in range(q.size[1]):
        u = py / max(1, q.size[1] - 1)
        col = tuple(int(a + (b - a) * u) for a, b in zip((88, 118, 104), (38, 56, 50)))
        grad.putpixel((0, py), col + (int(196 + 50 * u),))
    q.img.alpha_composite(grad.resize(q.size, Image.NEAREST))

    def twice(draw):  # ogni cosa vicino al bordo si disegna anche dall'altra parte: la striscia si ripete senza giunta
        for dx in (-W, 0, W):
            draw(dx)

    # i riflessi del cielo: pennellate orizzontali chiare, più fitte sotto il pelo
    refl = q.mask()
    for k in range(70):
        x = rng.uniform(0, W)
        y = 6 + rng.uniform(0, 1) ** 2 * 120
        ln = rng.uniform(14, 60) * (1 - y / 200)
        wdt = rng.uniform(0.6, 1.6)
        twice(lambda dx, x=x, y=y, ln=ln, wdt=wdt: q.stroke(refl, [(x + dx, y), (x + dx + ln * 0.5, y + 0.4), (x + dx + ln, y)], wdt))
    q.fill(q.soften(refl, 0.6), (176, 194, 178), 0.38)
    # mulinelli scuri sotto, appena accennati
    swirl = q.mask()
    for k in range(18):
        x, y = rng.uniform(0, W), rng.uniform(40, H)
        rx, ry = rng.uniform(30, 90), rng.uniform(4, 10)
        twice(lambda dx, x=x, y=y, rx=rx, ry=ry: q.ellipse(swirl, x + dx - rx, y - ry, x + dx + rx, y + ry))
    q.fill(q.soften(swirl, 6), (24, 34, 26), 0.35)
    # il pelo dell'acqua: una riga chiara che ondeggia, e la patina d'alghe a chiazze
    line = q.mask()
    pts = [(x, 4 + 0.9 * math.sin(x / 37 * math.tau / 26 * 2) + 0.5 * math.sin(x / 11)) for x in range(-10, W + 11, 6)]
    q.stroke(line, pts, 1.3)
    q.fill(q.soften(line, 0.4), (206, 218, 190), 0.85)
    scum = q.mask()
    for k in range(26):
        x = rng.uniform(0, W)
        w = rng.uniform(12, 70)
        y = rng.uniform(4, 13)
        for j in range(int(w / 6) + 1):
            px, r = x + rng.uniform(-w / 2, w / 2), rng.uniform(2, 5)
            twice(lambda dx, px=px, y=y, r=r: q.ellipse(scum, px + dx - r * 1.8, y - r * 0.5, px + dx + r * 1.8, y + r * 0.5))
    scum = q.smooth(scum, 0.8)
    q.fill(scum, (128, 138, 70), 0.75)
    q.fill(q.inner_shadow(scum, 0, -1, 0.8), (92, 104, 52), 0.7)
    q.fill(q.rim(scum, 0, -1, 0.6), (176, 184, 110), 0.6)
    dots = q.mask()  # lenti d'acqua
    for k in range(160):
        x, y = rng.uniform(0, W), 4 + rng.uniform(0, 1) ** 2 * 14
        r = rng.uniform(0.6, 1.3)
        twice(lambda dx, x=x, y=y, r=r: q.ellipse(dots, x + dx - r * 1.4, y - r * 0.6, x + dx + r * 1.4, y + r * 0.6))
    q.fill(dots, (150, 164, 82), 0.85)
    for k in range(9):  # foglie dei platani cadute nel canale
        x, y = rng.uniform(0, W), rng.uniform(5, 12)
        a = rng.uniform(-0.5, 0.5)
        leaf = q.mask()
        r = rng.uniform(3, 5)
        shape = [(x + math.cos(a) * r * 1.6 * math.cos(u) - math.sin(a) * r * 0.5 * math.sin(u), y + math.sin(a) * r * 1.6 * math.cos(u) * 0.4 + r * 0.45 * math.sin(u)) for u in [j * math.tau / 14 for j in range(14)]]
        twice(lambda dx, shape=shape: q.poly(leaf, [(px + dx, py) for px, py in shape]))
        q.fill(leaf, rng.choice([(150, 112, 62), (126, 98, 56), (168, 134, 74)]), 0.95)
        q.outline(leaf, 0.35, (70, 56, 40))
    out = q.result().quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
    out.save(os.path.join(OUT, "canale.png"), optimize=True)
    print("scritto canale.png", out.size)
    return out


def _bike_frame(phase):
    """La bici tutta rovinata che galleggia a malapena: coricata e storta, una ruota piegata a otto che spunta
    dall'acqua con i raggi rotti, il telaio arrugginito, il manubrio che punta in alto con una manopola strappata,
    la sella sfondata, la catena che penzola e un ciuffo d'alghe. Linea di galleggiamento al 60% del fotogramma."""
    q = Quadro(130, 60, origin=(-65, -36))  # y 0 = pelo dell'acqua
    rust, rust_d, rust_l = (150, 82, 50), (98, 56, 40), (196, 120, 70)
    ink = (40, 34, 30)
    tilt = 0.06 * math.sin(phase * math.tau)

    def rot(x, y):
        return (x * math.cos(tilt) - y * math.sin(tilt), x * math.sin(tilt) + y * math.cos(tilt))

    def wheel(cx, cy, rx, ry, bend, seed):
        rng = random.Random(seed)
        rim = q.mask()
        pts = [rot(cx + rx * math.cos(u) * (1 + bend * math.sin(2 * u)), cy + ry * math.sin(u)) for u in [j * math.tau / 40 for j in range(41)]]
        q.stroke(rim, pts, 2.0)
        q.fill(rim, (70, 70, 72))
        q.fill(q.rim(rim, -0.6, -0.6, 0.4), (150, 150, 150), 0.7)
        spokes = q.mask()
        for k in range(14):
            if rng.random() < 0.35:
                continue  # raggi rotti
            u = k * math.tau / 14
            ln = rng.uniform(0.5, 1.0)
            q.stroke(spokes, [rot(cx, cy), rot(cx + rx * ln * math.cos(u), cy + ry * ln * math.sin(u))], 0.4)
        q.fill(spokes, (120, 118, 112), 0.9)
        hub = q.ellipse(q.mask(), *rot(cx - 2.5, cy - 2.5), *rot(cx + 2.5, cy + 2.5))
        q.fill(hub, rust)

    wheel(-30, -4, 22, 15, 0.12, 1)  # la ruota davanti, storta, spunta quasi tutta
    wheel(32, 6, 22, 9, 0.04, 2)  # quella dietro, quasi sott'acqua
    frame = q.mask()
    for a, b in (((-30, -4), (-8, -20)), ((-8, -20), (22, -16)), ((22, -16), (32, 6)), ((-8, -20), (8, 4)), ((8, 4), (32, 6)), ((8, 4), (22, -16))):
        q.stroke(frame, [rot(*a), rot(*b)], 2.6)
    q.stroke(frame, [rot(-8, -20), rot(-12, -30), rot(-6, -33)], 2.0)  # lo sterzo che punta in alto
    q.stroke(frame, [rot(-14, -34), rot(2, -31)], 1.8)  # il manubrio storto
    q.stroke(frame, [rot(22, -16), rot(24, -24)], 2.0)  # il reggisella
    q.fill(frame, rust)
    q.fill(q.grain(frame, 0.6, 5, 0.8), rust_d)
    q.fill(q.rim(frame, -0.6, -0.8, 0.5), rust_l, 0.7)
    q.outline(frame, 0.5, ink)
    seat = q.mask()
    q.poly(seat, [rot(17, -26), rot(31, -27), rot(30, -23), rot(19, -22)])
    q.fill(seat, (52, 44, 40))
    q.line([rot(21, -25), rot(26, -23.5)], 0.6, (170, 150, 120))  # l'imbottitura che esce
    q.outline(seat, 0.4, ink)
    grip = q.mask()
    q.stroke(grip, [rot(-14, -34), rot(-18, -35)], 2.2)
    q.fill(grip, (60, 60, 64))
    q.line([rot(2, -31), rot(5, -29), rot(4, -26)], 0.5, (60, 60, 64))  # la manopola strappata che penzola
    chain = q.mask()
    q.stroke(chain, [rot(8, 4), rot(10, 10), rot(14, 12), rot(20, 10)], 0.7)
    q.fill(chain, (60, 54, 50))
    algae = q.mask()  # un ciuffo d'alghe appeso alla ruota
    for k in range(5):
        x0 = -40 + k * 2.2
        q.stroke(algae, [rot(x0, -10), rot(x0 - 1, -4), rot(x0 + 0.5, 1)], 0.8)
    q.fill(algae, (96, 120, 62), 0.9)
    return q.result()


def _drunk_frame(phase):
    """Il tizio ubriaco che dorme a galla a pancia in su: berretto di lana, barba sfatta e naso rosso, la bocca aperta
    che russa, la canottiera macchiata sulla pancia che spunta dall'acqua, una mano che tiene ancora la bottiglia
    fuori dall'acqua, l'altra che galleggia, i piedi con una scarpa sola. Linea di galleggiamento al 60%."""
    q = Quadro(140, 60, origin=(-62, -36))  # y 0 = pelo dell'acqua; testa a sinistra
    ink = (40, 34, 30)
    skin, skin_d = (204, 158, 128), (164, 118, 96)
    lift = math.sin(phase * math.tau)  # il braccio con la bottiglia sale e scende piano
    # le gambe in jeans, quasi tutte sotto
    legs = q.mask()
    q.stroke(legs, [(20, -2), (44, 0), (62, 2)], 7)
    q.stroke(legs, [(20, 2), (42, 5), (60, 7)], 7)
    q.fill(legs, (62, 78, 104))
    q.fill(q.inner_shadow(legs, 0, -2, 1.5), (40, 52, 74), 0.8)
    q.outline(legs, 0.5, ink)
    shoe = q.ellipse(q.mask(), 59, -5, 70, 3)  # una scarpa sola
    q.fill(shoe, (58, 48, 42))
    q.outline(shoe, 0.45, ink)
    foot = q.ellipse(q.mask(), 58, 3, 67, 9)  # l'altro piede col calzino bucato
    q.fill(foot, (150, 146, 136))
    q.fill(q.ellipse(q.mask(), 63, 4.5, 65, 6.5), skin)
    # la pancia con la canottiera
    belly = q.mask()
    q.poly(belly, bezier((-16, 2), (-12, -14), (14, -16), (24, 2), 16))
    q.ellipse(belly, -18, -6, 26, 6)
    belly = q.smooth(belly, 1.2)
    q.fill(belly, (214, 208, 190))
    q.fill(q.inner_shadow(belly, -4, -5, 3), (170, 162, 144), 0.8)
    stains = q.mask()
    for x, y, r in ((-2, -8, 3), (8, -10, 2.2), (14, -5, 2.6)):
        q.ellipse(stains, x - r, y - r * 0.7, x + r, y + r * 0.7)
    q.fill(q.soften(stains, 0.6), (170, 140, 90), 0.55)
    q.fill(q.ellipse(q.mask(), 4, -14.5, 9, -11.5), skin)  # l'ombelico che spunta
    q.outline(belly, 0.55, ink)
    # il braccio che galleggia, aperto
    arm = q.mask()
    q.stroke(arm, [(-10, -2), (-4, 6), (6, 9)], 5)
    q.fill(arm, skin)
    q.fill(q.inner_shadow(arm, 0, -2, 1.2), skin_d, 0.8)
    q.outline(arm, 0.45, ink)
    # la testa col berretto, la barba e il naso rosso, la bocca aperta
    head = q.mask()
    q.ellipse(head, -40, -14, -18, 4)
    q.fill(head, skin)
    q.fill(q.inner_shadow(head, -3, -3, 2), skin_d, 0.8)
    beard = q.mask()
    q.ellipse(beard, -30, -6, -17, 4)
    q.fill(q.intersect(beard, head), (96, 82, 70), 0.75)
    q.fill(q.grain(q.intersect(beard, head), 0.9, 9, 0.6), (60, 50, 44))
    cap = q.mask()
    q.poly(cap, bezier((-44, 2), (-50, -10), (-42, -18), (-32, -14), 12) + [(-36, 0)])
    q.fill(cap, (150, 64, 52))
    q.fill(q.inner_shadow(cap, -2, -2, 1.2), (110, 44, 38), 0.8)
    q.outline(q.union(head, cap), 0.55, ink)
    q.fill(q.ellipse(q.mask(), -28, -15, -23, -10), (206, 104, 92))  # il naso rosso
    q.fill(q.ellipse(q.mask(), -22, -8, -19, -4), (70, 40, 40))  # la bocca aperta
    q.line([(-31, -10), (-28, -10.6)], 0.6, ink)  # l'occhio chiuso
    # l'altro braccio alzato con la bottiglia di vetro verde
    bx, by = -6, -18 - 4 * lift
    arm2 = q.mask()
    q.stroke(arm2, [(-12, -6), (-12, -14 - 2 * lift), (bx, by)], 4.4)
    q.fill(arm2, skin)
    q.fill(q.inner_shadow(arm2, -1.5, 0, 1), skin_d, 0.8)
    q.outline(arm2, 0.45, ink)
    bottle = q.mask()
    q.poly(bottle, [(bx - 2, by - 1), (bx + 2.5, by - 2), (bx + 9, by - 13), (bx + 7, by - 15), (bx + 1, by - 5)])
    q.fill(bottle, (64, 120, 70))
    q.fill(q.rim(bottle, -0.6, -0.6, 0.4), (150, 200, 150), 0.7)
    q.outline(bottle, 0.45, ink)
    # russa: le zeta che salgono e svaniscono
    for k in range(2):
        u = (phase + k * 0.5) % 1.0
        zx, zy, zs = -20 + 10 * u, -20 - 16 * u, 2.4 + 1.6 * u
        zz = q.mask()
        q.stroke(zz, [(zx, zy), (zx + zs, zy), (zx, zy + zs), (zx + zs, zy + zs)], 0.7)
        q.fill(zz, (240, 240, 236), 0.9 * (1 - u))
    return q.result()


def _crown(phase, seed=11):
    """La corona dove il getto batte sotto la tazza (#378, dallo schizzo di Riccardo): l'acqua si apre a ombrello e
    ricade ai due lati in pochi rami grossi che si piegano verso il basso come le foglie di una palma, pieni alla
    radice e sempre più sottili, finché si rompono in gocce, dentro una nebbiolina. Il punto da cui parte (dove arriva
    il getto) è in x 0, y 0."""
    q = Quadro(180, 110, origin=(-90, -14))
    rng = random.Random(seed)
    mist = q.mask()
    q.ellipse(mist, -70, -12, 70, 40)
    q.fill(q.soften(mist, 12), (255, 255, 255), 0.2)
    fronds = []
    for side in (-1, 1):
        for k in range(4):  # quattro rami per parte, dal più corto e ripido al più lungo e aperto
            reach = 34 + k * 14 + rng.uniform(-4, 4)
            drop = 26 + k * 10 + rng.uniform(-4, 6)
            lift = 9 - k * 1.5 + rng.uniform(-1, 1)
            fronds.append((side, reach, drop, lift, k))
    for side, reach, drop, lift, k in fronds:
        p0 = (side * 2, 0)
        pts = bezier(p0, (side * reach * 0.3, -lift), (side * reach * 0.85, -lift * 0.5), (side * reach, drop), 22)
        grow = 0.7 + 0.3 * ((phase + k * 0.29 + (side > 0) * 0.5) % 1.0)  # ogni ramo si allunga e si rompe a tempo suo
        upto = max(4, int(len(pts) * grow))
        body = q.mask()
        for j in range(upto - 1):
            q.stroke(body, [pts[j], pts[j + 1]], 15.0 * (1 - j / len(pts)) ** 1.1 + 2.2)
        body = q.smooth(body, 0.5)
        q.fill(body, AQUA, 0.85)
        q.fill(q.inner_shadow(body, 0, -2.5, 1.5), (150, 196, 208), 0.6)  # sotto, in ombra
        core = q.mask()
        for j in range(upto - 1):
            q.stroke(core, [(pts[j][0], pts[j][1] - 1.2), (pts[j + 1][0], pts[j + 1][1] - 1.2)], 5.0 * (1 - j / len(pts)) + 0.8)
        q.fill(q.soften(core, 0.5), FOAM, 0.95)
        q.outline(body, 0.35, (120, 170, 186))
        # dove il ramo si rompe: grosse gocce che continuano a cadere
        ex, ey = pts[upto - 1]
        for d in range(4):
            u = (phase * 2 + k * 0.17 + d * 0.25) % 1.0
            x, y = ex + side * 4 * u, ey + 5 + 34 * u * u
            r = 3.2 * (1 - 0.4 * u)
            dm = q.soften(q.ellipse(q.mask(), x - r, y - r * 1.6, x + r, y + r), 0.3)
            q.fill(dm, FOAM, 0.95 - 0.5 * u)
    foam = q.mask()  # il ribollire dove l'acqua batte
    for k in range(12):
        x, r = rng.uniform(-14, 14), rng.uniform(3, 6)
        q.ellipse(foam, x - r, -r - rng.uniform(0, 3), x + r, r * 0.7)
    foam = q.smooth(foam, 0.8)
    q.fill(foam, FOAM, 0.95)
    q.fill(q.inner_shadow(foam, 0, 1.5, 1), AQUA, 0.6)
    return q.result()


def crown_sheet():
    sheet([_crown(i / 6) for i in range(6)], OUT, "corona.png", colors=256)


def floater_sheets():
    sheet([_bike_frame(i / 2) for i in range(2)], OUT, "bici-rotta.png")
    sheet([_drunk_frame(i / 4) for i in range(4)], OUT, "ubriaco.png")


def near_sheets():
    """I passanti e i ciclisti in primissimo piano (#378, idea di Riccardo): gli stessi fogli dello sfondo vivo, sfocati
    come se fossero fuori fuoco davanti alla scena. Si rifanno da passanti.png e bici.png."""
    from PIL import ImageFilter
    for src, dst in (("passanti.png", "passanti-sfocati.png"), ("bici.png", "bici-sfocata.png")):
        im = Image.open(os.path.join(OUT, src)).convert("RGBA")
        blur = im.filter(ImageFilter.GaussianBlur(2.4))
        blur.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).save(os.path.join(OUT, dst), optimize=True)
        print("scritto", dst, im.size)


def _kid(row, phase):
    """Un ragazzo alla ringhiera in primissimo piano (#378, idea di Riccardo), visto di spalle mentre guarda la rissa:
    0 seduto sulla ringhiera che ride, 1 in piedi che indica, 2 che esulta con le braccia, 3 che filma col telefono.
    Felpe, giubbotti, cappellini girati: un gruppetto un po' spaccone. Piedi a (0, 4 dal fondo), fotogramma 70×144."""
    q = Quadro(70, 144, origin=(-35, -140))
    rng = random.Random(400 + row)
    ink = (34, 30, 30)
    skin = rng.choice([(196, 152, 122), (168, 122, 92), (210, 170, 140)])
    hair = rng.choice([(36, 30, 28), (58, 44, 34)])
    top_col = [(112, 112, 116), (70, 80, 60), (40, 40, 46), (52, 62, 94)][row]
    pants = [(70, 76, 96), (50, 50, 54), (40, 40, 44), (84, 86, 90)][row]
    cap = [(150, 52, 44), None, (230, 226, 216), (40, 40, 44)][row]
    bob = math.sin(phase * math.tau) * (1.6 if row in (0, 2) else 0.8)
    sit = row == 0
    hip_y = -30 if sit else -50
    sh_y = hip_y - 40 + bob
    # le gambe (da seduto sono davanti, nascoste dalla schiena: si vedono solo un po')
    legs = q.mask()
    if sit:
        q.stroke(legs, [(-7, hip_y + 2), (-9, hip_y + 18)], 7)
        q.stroke(legs, [(7, hip_y + 2), (9, hip_y + 18)], 7)
    else:
        q.stroke(legs, [(-6, hip_y), (-8, -24), (-9, -3)], 8)
        q.stroke(legs, [(6, hip_y), (8, -24), (9, -3)], 8)
    q.fill(legs, pants)
    q.fill(q.inner_shadow(legs, -3, 0, 2), shade(pants + (255,), 0.75)[:3], 0.8)
    q.outline(legs, 0.6, ink)
    if not sit:
        shoes = q.mask()
        for sx in (-10, 10):
            q.ellipse(shoes, sx - 6, -5, sx + 6, 1)
        q.fill(shoes, (226, 224, 218))
        q.fill(q.inner_shadow(shoes, 0, -2, 1), (170, 168, 160), 0.8)
        q.outline(shoes, 0.5, ink)
    # le braccia secondo la posa
    arms = q.mask()
    l_sh, r_sh = (-13, sh_y + 5), (13, sh_y + 5)
    if row == 0:  # seduto: le mani appoggiate sulla ringhiera ai fianchi
        q.stroke(arms, [l_sh, (-18, hip_y - 8), (-17, hip_y + 2)], 6)
        q.stroke(arms, [r_sh, (18, hip_y - 8), (17, hip_y + 2)], 6)
    elif row == 1:  # indica la rissa, il braccio teso in avanti e in su
        a = 0.15 * math.sin(phase * math.tau * 2)
        q.stroke(arms, [l_sh, (-16, sh_y + 22), (-12, sh_y + 34)], 6)
        q.stroke(arms, [r_sh, (24 + 4 * a, sh_y - 12), (30, sh_y - 26 + 6 * a)], 6)
    elif row == 2:  # esulta: le braccia su a turno
        up = math.sin(phase * math.tau)
        q.stroke(arms, [l_sh, (-20, sh_y - 14 - 6 * up), (-18, sh_y - 32 - 8 * up)], 6)
        q.stroke(arms, [r_sh, (20, sh_y - 14 + 6 * up), (18, sh_y - 32 + 8 * up)], 6)
    else:  # filma: il telefono alto con due mani
        q.stroke(arms, [l_sh, (-10, sh_y - 12), (-4, sh_y - 24)], 6)
        q.stroke(arms, [r_sh, (10, sh_y - 12), (4, sh_y - 24)], 6)
    q.fill(arms, top_col)
    q.fill(q.inner_shadow(arms, -2, 0, 1.5), shade(top_col + (255,), 0.72)[:3], 0.8)
    q.outline(arms, 0.6, ink)
    # la schiena: felpa o giubbotto, con il cappuccio o il colletto
    body = q.mask()
    q.poly(body, [(-15, sh_y), (15, sh_y), (13, hip_y + 4), (-13, hip_y + 4)])
    q.ellipse(body, -16, sh_y - 3, 16, sh_y + 9)
    body = q.smooth(body, 1.2)
    q.fill(body, top_col)
    q.fill(q.inner_shadow(body, -5, -2, 3), shade(top_col + (255,), 0.72)[:3], 0.85)
    q.fill(q.rim(body, -1, -1, 1), light(top_col + (255,), 1.2)[:3], 0.6)
    if row == 0:  # il cappuccio abbassato sulla schiena
        hood = q.ellipse(q.mask(), -9, sh_y - 1, 9, sh_y + 10)
        q.fill(hood, shade(top_col + (255,), 0.85)[:3])
        q.outline(hood, 0.5, ink)
    if row == 2:  # le due righe della tuta lungo le braccia e i fianchi
        q.line([(-13, sh_y + 4), (-12, hip_y)], 1.0, (220, 220, 214), 0.9)
        q.line([(13, sh_y + 4), (12, hip_y)], 1.0, (220, 220, 214), 0.9)
    q.outline(body, 0.7, ink)
    # le mani
    hands = q.mask()
    if row == 1:
        q.ellipse(hands, 28, sh_y - 30, 33, sh_y - 24)
    elif row == 2:
        up = math.sin(phase * math.tau)
        q.ellipse(hands, -21, sh_y - 37 - 8 * up, -15, sh_y - 31 - 8 * up)
        q.ellipse(hands, 15, sh_y - 37 + 8 * up, 21, sh_y - 31 + 8 * up)
    q.fill(hands, skin)
    # la testa da dietro: nuca, orecchie, capelli corti, il cappellino girato
    head = q.mask()
    q.ellipse(head, -8, sh_y - 20, 8, sh_y - 2)
    q.fill(head, skin)
    q.fill(q.ellipse(q.mask(), -8, sh_y - 21, 8, sh_y - 7), hair)
    for ex in (-8.5, 8.5):
        q.fill(q.ellipse(q.mask(), ex - 1.6, sh_y - 12, ex + 1.6, sh_y - 7), skin)
    if cap:
        c = q.mask()
        q.ellipse(c, -8.5, sh_y - 23, 8.5, sh_y - 11)
        q.poly(c, [(-5, sh_y - 13), (5, sh_y - 13), (6, sh_y - 8), (-6, sh_y - 8)])  # la visiera girata dietro
        q.fill(c, cap)
        q.fill(q.inner_shadow(c, -2, -1, 1), shade(cap + (255,), 0.75)[:3], 0.8)
        q.outline(c, 0.5, ink)
    q.outline(head, 0.6, ink)
    if row == 3:  # il telefono: da dietro si vede lo schermo acceso con la rissa dentro
        ph = q.mask()
        q.poly(ph, [(-7, sh_y - 40), (7, sh_y - 40), (7, sh_y - 24), (-7, sh_y - 24)])
        q.fill(ph, (30, 30, 34))
        scr = q.poly(q.mask(), [(-6, sh_y - 39), (6, sh_y - 39), (6, sh_y - 25), (-6, sh_y - 25)])
        q.fill(scr, (150, 190, 214))
        q.fill(q.ellipse(q.mask(), -3 + phase * 3, sh_y - 34, 0 + phase * 3, sh_y - 29), (60, 50, 50))
        q.fill(q.ellipse(q.mask(), 1, sh_y - 33, 4, sh_y - 28), (90, 60, 40))
        q.fill(q.ellipse(q.mask(), -4, sh_y - 27, 4, sh_y - 25.5), (200, 60, 50), 0.9)  # il pallino rosso: sta registrando
        q.fill(q.ellipse(q.mask(), -9, sh_y - 30, -4, sh_y - 24), skin)
        q.fill(q.ellipse(q.mask(), 4, sh_y - 30, 9, sh_y - 24), skin)
    return q.result()


def kids_sheet():
    """Il foglio dei ragazzi alla ringhiera (#378): 4 righe (seduto, indica, esulta, filma) × 6 fotogrammi, sfocati
    come il resto del primissimo piano."""
    from PIL import ImageFilter
    rows = []
    for row in range(4):
        frames = [_kid(row, i / 6) for i in range(6)]
        rows.append(frames)
    fw, fh = rows[0][0].size
    out = Image.new("RGBA", (fw * 6, fh * 4), (0, 0, 0, 0))
    for r, frames in enumerate(rows):
        for i, f in enumerate(frames):
            out.alpha_composite(f, (i * fw, r * fh))
    out = out.filter(ImageFilter.GaussianBlur(1.3))
    out = out.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
    out.save(os.path.join(OUT, "ragazzi.png"), optimize=True)
    print("scritto ragazzi.png", out.size)


if __name__ == "__main__":
    sheet([cloud(s) for s in range(1, 9)], OUT, "nuvole.png")
    sheet(gull_frames(), OUT, "gabbiano.png")
    sheet(swallow_frames(), OUT, "rondine.png")
    sheet(bat_frames(), OUT, "pipistrello.png")
    sheet(pigeon_frames(), OUT, "piccione.png")
    walkers_sheet()
    umbrellas_sheet()
    bar_sheets()
    traffic_sheets()
    fountain_water_sheets()
    tazza_sheet()
    canal_tile()
    floater_sheets()
    crown_sheet()
    near_sheets()
    kids_sheet()
