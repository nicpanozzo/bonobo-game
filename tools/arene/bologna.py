"""I disegni dell'arena Bologna (#433): "la Rossa" al tramonto, sotto le Due Torri, nello stile di Padova.

Stesso motore di Padova (pittura.py e disegno.py): sagome organiche lisciate, ombre e luci morbide a 2 toni,
contorno a inchiostro e grana a pennello. Fondale più spento dei lottatori, bordo calpestabile chiaro, niente colori
dei giocatori saturi vicino al piano di gioco (docs/stile-grafico.md, sezione 7). Tutto a 2x (art.scale 0.5).

L'arena è alta (2200×2400) e la telecamera sale dalla piazza fino alla cima dell'Asinelli, con la parallasse anche in
verticale (verticalParallax 1): gli strati lontani restano quasi fermi con la telecamera (le colline e il mare di
tetti restano all'orizzonte), quelli vicini scendono quando si sale.

- sfondo-0 (parallasse 0.1): il cielo trasparente (cielo vivo), i colli con San Luca e il suo portico, il mare di tetti
- sfondo-1 (0.4): la città a mezza distanza: San Petronio, le altre torri, la cupola della Vita, i tetti rossi
- sfondo-2 (0.85): i palazzi coi portici attorno alla piazza e la Mercanzia, il marciapiede e il selciato
- decorazioni ferme (parallasse 1): il fusto dell'Asinelli con il montacarichi, i portici ai lati, San Petronio sul
  piedistallo, il cantiere di container della Garisenda, i lampioni e il cartello "Città 30"

La Garisenda non si disegna qui: la disegna il codice, che la fa crollare a 2:30. Qui solo il suo cantiere alla base.

Uso: python3 tools/arene/bologna.py [materiali] [decorazioni] [strati] [vita] [anteprima]  (senza argomenti, tutto)
     python3 tools/arene/bologna.py viste CARTELLA   (vedute di prova composte come nel gioco, per giudicare i disegni)
Scrive in public/assets/stages/bologna/. L'anteprima e le viste leggono l'arena da stages.ts con npx tsx.
"""

import json
import math
import os
import subprocess
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
from disegno import Tela, light, mix, rand, shade  # noqa: E402
from pittura import Quadro, bezier, sheet  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
OUT = os.path.join(ROOT, "public", "assets", "stages", "bologna")
os.makedirs(OUT, exist_ok=True)

INK = (34, 24, 24, 255)  # l'inchiostro, quasi nero e caldo
EDGE = (240, 217, 181, 255)  # = colors.solidEdge: il bordo calpestabile, il più chiaro di tutti
BRICK = (150, 72, 52, 255)  # il mattone delle torri: rosso caldo ma spento
BRICK_D = (116, 54, 42, 255)
MORTAR = (92, 58, 50, 255)
SELENITE = (164, 154, 138, 255)  # i blocchi di selenite delle basi delle torri
WOOD = (146, 104, 64, 255)  # = colors.platform un po' più scuro: balconi e ponteggi
WOOD_D = (104, 72, 46, 255)
WOOD_TOP = (240, 216, 174, 255)
TERRA = (166, 82, 56, 255)  # i coppi dei tetti
STONE = (124, 108, 92, 255)  # l'arenaria della piazza
HAZE = (176, 164, 172, 255)  # la foschia della sera, verso cui sbiadiscono le cose lontane
LIT = (255, 204, 120, 255)  # una finestra accesa
LIT_CORE = (255, 236, 190, 255)

# Gli strati sono centrati sul centro dell'arena (1100, 1200) come vuole il gioco (layer_rect). Le coordinate si
# disegnano "come le vede la telecamera quando guarda il centro dell'arena": quando guarda più in basso (la piazza,
# y 1850) uno strato con parallasse p scende di (1850 - 1200) × (1 - p)
CENTER = (1100, 1200)
LAYERS = [  # file, parallasse, larghezza e altezza in pixel di mondo
    ("sfondo-0.png", 0.1, 2600, 1760),
    ("sfondo-1.png", 0.4, 2600, 1120),
    ("sfondo-2.png", 0.85, 2600, 2420),
]
HORIZON = 1330  # dove i colli toccano il mare di tetti, nello strato 0
MID_BASE = 1530  # il piede delle case dello strato 1
NEAR_BASE = 1778  # il pavimento dei portici dello strato 2: ci camminano i passanti (life.walkers.y)
ROAD_Y = NEAR_BASE + 54  # la strada davanti ai portici (life.traffic.y): il gioco disegna asfalto e marciapiede
LAMPS_NEAR = [-90, 330, 700, 1500, 1880, 2290]  # i lampioni dello strato 2 (life.daycycle.lamps, y = LAMP_FOOT - 101)
LAMP_FOOT = ROAD_Y - 17  # il piede dei lampioni, sul cordolo: il gioco mette la pozza di luce 101 px sotto la lanterna

FACADES = [(170, 76, 54), (188, 108, 62), (196, 142, 78), (178, 94, 70), (150, 70, 52), (200, 160, 98), (184, 120, 92)]
SHUTTERS = [(70, 84, 64), (92, 68, 50), (78, 76, 70)]


def far(col, k):
    """Un colore velato dalla lontananza: k 0 com'è, 1 tutto foschia."""
    c = tuple(col[:3]) + (255,)
    return mix(c, HAZE, k)


def save(img, name, colors=None):
    if colors:
        img = img.quantize(colors=colors, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
    img.save(os.path.join(OUT, name), optimize=True)
    print("scritto", name, img.size)


# --- aiuti di pittura ---
def rect(q, m, x0, y0, x1, y1):
    q.poly(m, [(x0, y0), (x1, y0), (x1, y1), (x0, y1)])
    return m


def arch(q, m, x0, x1, ys, yb, pointed=False):
    """Un'apertura ad arco nella maschera m: l'arco parte a ys, il fondo è a yb. Tonda o a sesto acuto."""
    r = (x1 - x0) / 2
    mx = (x0 + x1) / 2
    if pointed:
        top = bezier((x0, ys), (x0, ys - r * 0.9), (mx - r * 0.25, ys - r * 1.45), (mx, ys - r * 1.65), 10)
        top += [(2 * mx - x, y) for x, y in reversed(top)]
    else:
        top = [(mx - math.cos(math.pi * i / 16) * r, ys - math.sin(math.pi * i / 16) * r) for i in range(17)]
    q.poly(m, [(x0, yb), *top, (x1, yb)])
    return m


def paint(q, m, col, ink=INK, shadow=6.0, grain=0.22, seed=0, rim=True, ow=0.8):
    """Una massa dipinta come a Padova: colore, grana a pennello, ombra morbida a destra (la luce viene da sinistra
    in alto), luce sul bordo e contorno a inchiostro."""
    q.fill(m, col)
    if grain:
        q.fill(q.grain(m, grain, seed, 1.3), shade(col, 0.76))
    if shadow:
        q.fill(q.inner_shadow(m, -shadow, 0, shadow * 0.55), shade(col, 0.74), 0.9)
    if rim:
        q.fill(q.rim(m, -1.6, -1.6, 1.2), light(col, 1.16), 0.7)
    if ow:
        q.outline(m, ow, ink)


def courses(q, m, y0, y1, step, col, opacity, joints=0.0, seed=0):
    """I corsi dei mattoni dentro la sagoma: righe sottili e, con joints (la lunghezza del mattone), i giunti sfalsati."""
    lines = q.mask()
    d = ImageDraw.Draw(lines)
    rng = rand(seed)
    w = max(1, int(q.k * 0.3))
    y, row = y0, 0
    while y > y1:
        d.line([q._p(q.ox, y), q._p(q.ox + q.w, y)], fill=255, width=w)
        if joints:
            off = (joints / 2 if row % 2 else 0) + rng.uniform(-0.5, 0.5)
            x = q.ox + off
            while x < q.ox + q.w:
                d.line([q._p(x, y), q._p(x, y - step)], fill=255, width=w)
                x += joints
        y -= step
        row += 1
    q.fill(q.intersect(lines.filter(ImageFilter.GaussianBlur(0.6)), m), col, opacity)


def stamp(t, q):
    """Incolla un Quadro dipinto sulla tela di uno strato (stessa scala), tagliando quello che esce."""
    img = q.result() if q.ss != 1 else q.img
    dx, dy = int(round((q.ox - t.ox) * t.k)), int(round((q.oy - t.oy) * t.k))
    if dx < 0:
        img, dx = img.crop((-dx, 0, img.size[0], img.size[1])), 0
    if dy < 0:
        img, dy = img.crop((0, -dy, img.size[0], img.size[1])), 0
    if dx >= t.img.size[0] or dy >= t.img.size[1] or img.size[0] == 0 or img.size[1] == 0:
        return
    t.img.alpha_composite(img, dest=(dx, dy))


def patch(t, x0, y0, x1, y1):
    """Un Quadro sulla tela di uno strato: stessa scala, senza sovracampionamento (gli strati sono grandi)."""
    return Quadro(x1 - x0, y1 - y0, origin=(x0, y0), scale=t.k, ss=1)


def lit(t, x0, y0, x1, y1, arched=False):
    """Un vetro acceso nell'immagine delle luci (#288): il colore caldo e, dentro, il centro più chiaro."""
    if t.lights is None:
        return
    t.lights.rect(x0, y0, x1, y1, fill=LIT)
    if arched:
        t.lights.ellipse(x0, y0 - (x1 - x0) / 2, x1, y0 + (x1 - x0) / 2, fill=LIT)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    t.lights.rect(cx - (x1 - x0) * 0.25, cy - (y1 - y0) * 0.28, cx + (x1 - x0) * 0.25, cy + (y1 - y0) * 0.28, fill=LIT_CORE)


# ======================================================================================================
# I materiali del palco (#237): piastrelle a 2x che si ripetono, a 2 toni con l'inchiostro
# ======================================================================================================
def edge_strip(name, col=EDGE, w=64, h=6):
    """La striscia del bordo calpestabile: chiara, con il filo d'ombra sotto e qualche giunto."""
    t = Tela(w, h, bg=col, wrap=True)
    t.rect(0, h - 1.6, w, h, fill=shade(col, 0.72))
    t.rect(0, 0, w, 1.0, fill=light(col, 1.05))
    for x in range(0, w, 32):
        t.line([(x, 0.5), (x, h - 1.6)], fill=shade(col, 0.82), width=0.6)
    rng = rand(len(name))
    for _ in range(10):
        x = rng.uniform(0, w)
        t.rect(x, rng.uniform(1.5, h - 3), x + rng.uniform(1, 3), rng.uniform(2, h - 2), fill=shade(col, 0.92))
    t.save(OUT, name)


def piazza_skin():
    """Il fianco della piazza sotto il bordo, alto quanto il pezzo (400): grossi conci di arenaria a file sfalsate,
    più piccoli e più scuri andando giù, fino all'ombra della cantina. Più scuro del bordo e dei lottatori."""
    W, H = 128, 400
    t = Tela(W, H, bg=(58, 46, 44, 255), wrap=True)
    rng = rand(31)
    tones = [STONE, (128, 110, 94, 255), (116, 100, 88, 255), (126, 102, 88, 255)]
    y, r, bh = 0, 0, 34
    while y < H:
        dark = min(1.0, y / H * 1.25)
        off = (r % 2) * 32
        for x in range(off - 64, W, 64):
            tone = mix(rng.choice(tones), (50, 40, 40, 255), dark * 0.85)
            t.block(x + 1, y + 1, x + 63, y + bh - 1, tone, side=3, bottom=5, width=1.0, chip=(rng.choice(["br", "tl", "bl"]), 5) if rng.random() < 0.4 else None, ink_col=(46, 34, 32, 255))
            for _ in range(5):
                px, py = x + rng.uniform(4, 58), y + rng.uniform(4, bh - 8)
                t.ellipse(px, py, px + rng.uniform(1, 3), py + rng.uniform(0.6, 1.6), fill=shade(tone, 0.9))
        y += bh
        r += 1
        bh = max(26, bh - 1)
    t.glaze([(0, 0), (W, 0), (W, 14), (0, 14)], (20, 12, 14, 90))  # l'ombra del bordo sporgente
    t.save(OUT, "piazza.png", colors=128)


def base_skin():
    """Le basi delle torri: blocchi di selenite grigio-crema con i cristalli che luccicano e i giunti di malta."""
    W, H = 96, 60
    t = Tela(W, H, bg=(96, 86, 78, 255), wrap=True, wrap_y=True)
    rng = rand(41)
    y = 0
    for r in range(3):
        x = rng.uniform(-30, 0)
        while x < W:
            w = rng.uniform(26, 44)
            tone = mix(SELENITE, (180, 170, 152, 255), rng.random())
            t.block(x + 0.8, y + 0.8, x + w - 0.8, y + 19.2, tone, side=2.5, bottom=4, width=0.9, chip=("br", 4) if rng.random() < 0.3 else None, ink_col=(70, 60, 56, 255))
            for _ in range(4):
                px, py = x + rng.uniform(3, w - 4), y + rng.uniform(3, 14)
                t.poly([(px, py), (px + 1.6, py + 0.6), (px + 0.4, py + 1.8)], fill=light(tone, 1.12))
            x += w
        y += 20
    t.save(OUT, "base.png")


def bricks_skin(name, W=64, H=24, seed=51, slit=False):
    """Un muro di mattoni a corsi sfalsati: ogni mattone col suo tono, il giunto di malta, l'ombra sotto."""
    t = Tela(W, H, bg=MORTAR, wrap=True)
    rng = rand(seed)
    bh = 6
    for r in range(int(math.ceil(H / bh))):
        y = r * bh
        off = 0 if r % 2 == 0 else 8
        for x in range(off - 16, W, 16):
            tone = mix(BRICK, rng.choice([BRICK_D, (172, 92, 64, 255), (140, 70, 56, 255), BRICK]), rng.random() * 0.7)
            t.rect(x + 0.6, y + 0.6, x + 15.4, y + bh - 0.6, fill=tone)
            t.rect(x + 0.6, y + bh - 1.8, x + 15.4, y + bh - 0.6, fill=shade(tone, 0.8))
            if rng.random() < 0.25:
                t.rect(x + 3, y + 1.5, x + 6, y + 2.5, fill=light(tone, 1.1))
    t.rect(0, H - 3, W, H, fill=(60, 36, 32, 255))  # l'ombra sotto il pezzo
    t.line([(0, H - 3), (W, H - 3)], fill=INK, width=0.8)
    t.save(OUT, name)


def merlon_skin():
    """Un merlo dell'Asinelli (largo 70, alto 80): mattoni, la feritoia, il lato destro in ombra, l'inchiostro."""
    W, H = 70, 80
    t = Tela(W, H)
    rng = rand(61)
    t.rect(1, 0, W - 1, H, fill=BRICK)
    for r in range(int(H / 6) + 1):
        y = r * 6
        off = 0 if r % 2 == 0 else 8
        for x in range(off - 16, W, 16):
            tone = mix(BRICK, rng.choice([BRICK_D, (172, 92, 64, 255), (140, 70, 56, 255)]), rng.random() * 0.6)
            t.rect(max(1, x + 0.6), y + 0.6, min(W - 1, x + 15.4), min(H, y + 5.4), fill=tone)
    t.poly([(W - 14, 0), (W - 1, 0), (W - 1, H), (W - 14, H)], fill=(98, 46, 38, 150))
    t.glaze([(W - 14, 0), (W - 1, 0), (W - 1, H), (W - 14, H)], (60, 26, 24, 90))
    t.rect(W / 2 - 3, 24, W / 2 + 3, 56, fill=(36, 22, 22, 255))  # la feritoia
    t.rect(1, H - 6, W - 1, H, fill=(84, 42, 36, 255))
    t.rect(1, 0, W - 1, H, ink=True, width=1.4)
    t.save(OUT, "merlo.png")


def wood_skin():
    """La trave dei balconi e dei ponteggi (spessa 14): due assi chiare sopra, la testa della trave in ombra sotto,
    le venature, i chiodi e le teste dei travetti."""
    W, H = 64, 14
    t = Tela(W, H, bg=WOOD, wrap=True)
    rng = rand(71)
    t.rect(0, 8, W, H, fill=WOOD_D)
    for x in range(0, W, 32):  # le teste dei travetti
        t.rect(x + 12, 8, x + 20, H, fill=shade(WOOD_D, 0.8))
        t.rect(x + 12, 8, x + 20, H, ink=True, width=0.6)
    for _ in range(8):
        x = rng.uniform(0, W)
        y = rng.uniform(2, 6.5)
        t.line([(x, y), (x + rng.uniform(6, 16), y + rng.uniform(-0.6, 0.6))], fill=shade(WOOD, 0.8), width=0.5)
    for x in (2, 34):
        t.line([(x, 0), (x, 8)], fill=shade(WOOD, 0.7), width=0.7)
        t.circle(x + 3, 4, 0.7, fill=(60, 50, 44, 255))
    t.line([(0, 8), (W, 8)], fill=INK, width=0.8)
    t.line([(0, H - 0.5), (W, H - 0.5)], fill=INK, width=1.0)
    t.save(OUT, "legno.png")


def sill_skin():
    """Il davanzale delle finestre delle torri (spesso 12): pietra chiara modanata con l'ombra sotto."""
    W, H = 64, 12
    t = Tela(W, H, bg=(168, 158, 142, 255), wrap=True)
    t.rect(0, 6, W, 9, fill=(142, 132, 118, 255))
    t.rect(0, 9, W, H, fill=(96, 84, 76, 255))
    t.line([(0, 6), (W, 6)], fill=(110, 100, 90, 255), width=0.6)
    t.line([(0, 9), (W, 9)], fill=INK, width=0.7)
    for x in (10, 40):
        t.line([(x, 0), (x, 6)], fill=(130, 120, 108, 255), width=0.5)
    t.line([(0, H - 0.5), (W, H - 0.5)], fill=INK, width=0.9)
    t.save(OUT, "davanzale.png")


def portico_skin():
    """Il pavimento rialzato del portico (spesso 18): la lastra di pietra con la cornice e i dentelli in ombra."""
    W, H = 64, 18
    t = Tela(W, H, bg=(150, 132, 112, 255), wrap=True)
    t.rect(0, 7, W, 11, fill=(124, 108, 92, 255))
    for x in range(0, W, 8):
        t.rect(x + 1, 11, x + 5, 15, fill=(116, 100, 86, 255))
        t.rect(x + 5, 11, x + 8, 15, fill=(70, 56, 50, 255))
    t.rect(0, 15, W, H, fill=(64, 50, 46, 255))
    t.line([(0, 7), (W, 7)], fill=(96, 82, 72, 255), width=0.6)
    t.line([(0, H - 0.5), (W, H - 0.5)], fill=INK, width=0.9)
    t.save(OUT, "portico.png")


def coppi_skin():
    """Il tetto del portico (spesso 22) visto di fronte: i canali di coppi con la luce a sinistra e l'ombra a destra,
    la gronda con le bocche scure dei coppi e il filo d'ombra sotto."""
    W, H = 48, 22
    t = Tela(W, H, bg=TERRA, wrap=True)
    rng = rand(81)
    for x in range(0, W, 8):
        tone = mix(TERRA, rng.choice([(184, 100, 68, 255), (150, 72, 52, 255), (176, 96, 72, 255)]), rng.random() * 0.6)
        t.rect(x, 0, x + 8, 15, fill=tone)
        t.rect(x + 5, 0, x + 8, 15, fill=shade(tone, 0.78))
        t.rect(x + 1, 0, x + 2.6, 15, fill=light(tone, 1.12))
        t.chord(x - 0.2, 12, x + 8.2, 19, 0, 180, fill=shade(tone, 0.85))
        t.ellipse(x + 1.4, 13.2, x + 6.6, 17.6, fill=(44, 26, 24, 255))  # la bocca del coppo
    t.rect(0, 18.5, W, H, fill=(70, 40, 34, 255))
    t.line([(0, H - 0.5), (W, H - 0.5)], fill=INK, width=0.9)
    t.save(OUT, "coppi.png")


def skins():
    edge_strip("bordo.png")
    edge_strip("bordo-legno.png", col=WOOD_TOP, h=6)
    edge_strip("bordo-coppi.png", col=(234, 196, 160, 255), h=5)
    piazza_skin()
    base_skin()
    bricks_skin("mattoni.png")
    merlon_skin()
    wood_skin()
    sill_skin()
    portico_skin()
    coppi_skin()


# ======================================================================================================
# Le decorazioni ferme: in pixel di mondo, a 2x, con i piedi (centro del lato basso) dove dice stages.ts
# ======================================================================================================
ASINELLI = (1290, 820, 1830, 1945)  # il riquadro della decorazione, in pixel di mondo: piedi a (1560, 1945)


def asinelli():
    """Il fusto dell'Asinelli dietro i suoi pezzi (#433): mattoni a corsi, le buche pontaie, le feritoie, le due
    finestre ad arco sopra i davanzali (piattaforme 14 e 18), la selenite alla base con la rocchetta merlata, la
    corona di beccatelli fino a y 980 (dove poggia il tetto della zuffa), il parafulmine in cima e, a destra, il
    traliccio del montacarichi. I merli no: sono pezzi che lampeggiano, e un merlo dipinto resterebbe lì."""
    x0, y0, x1, y1 = ASINELLI
    q = Quadro(x1 - x0, y1 - y0, origin=(x0, y0))
    lt = Quadro(x1 - x0, y1 - y0, origin=(x0, y0))
    rng = rand(101)
    L, R = 1335, 1665  # il fusto alla base, si stringe un poco salendo
    top = 1036

    def side(y, s):
        u = (1940 - y) / (1940 - top)
        return (L + 10 * u) if s < 0 else (R - 10 * u)

    # il traliccio del montacarichi, dietro a tutto: due montanti, le diagonali e le staffe verso la torre
    mast = q.mask()
    mx0, mx1 = 1738, 1772
    for x in (mx0, mx1):
        q.stroke(mast, [(x, 1942), (x, 1070)], 2.2)
    y = 1940
    while y > 1080:
        q.stroke(mast, [(mx0, y), (mx1, y - 30)], 1.1)
        q.stroke(mast, [(mx0, y - 30), (mx1, y - 30)], 1.0)
        y -= 30
    for yy in range(1880, 1080, -180):  # le staffe che lo legano alla torre
        q.stroke(mast, [(side(yy, 1) - 4, yy), (mx0, yy)], 1.6)
    q.poly(mast, [(mx0 - 8, 1070), (mx1 + 8, 1070), (mx1 + 8, 1040), (mx0 - 8, 1040)])  # l'argano in cima
    q.fill(mast, (96, 100, 104))
    q.fill(q.shift(q.soften(mast, 0.6), 0.8, 0.8), (40, 40, 44), 0.35)
    q.outline(mast, 0.5, INK)

    # il fusto
    shaft = q.poly(q.mask(), [(side(1942, -1), 1942), (side(top, -1), top), (side(top, 1), top), (side(1942, 1), 1942)])
    holes = q.mask()
    # le due finestre ad arco, sopra i davanzali dei pezzi 14 (y 1580) e 18 (y 1100), da x 1370 a 1470
    for sill, h in ((1580, 84), (1100, 58)):
        arch(q, holes, 1384, 1456, sill - h + 36, sill)
    # le feritoie, poche e strette
    slits = [(1600, 1450), (1420, 1780), (1590, 1880), (1405, 1290), (1610, 1050), (1450, 1660), (1600, 1300)]
    for sx, sy in slits:
        q.poly(holes, [(sx - 3, sy), (sx + 3, sy), (sx + 3, sy - 22), (sx, sy - 25), (sx - 3, sy - 22)])
    body = q.minus(shaft, holes)
    paint(q, body, BRICK, shadow=26, grain=0.3, seed=7, ow=0)
    courses(q, body, 1940, top, 5.2, (78, 40, 34), 0.32, joints=14, seed=3)
    # le chiazze: mattoni rifatti più chiari e più scuri, le colature della pioggia
    for _ in range(26):
        cx, cy = rng.uniform(L, R), rng.uniform(top + 20, 1930)
        blob = q.ellipse(q.mask(), cx - rng.uniform(10, 30), cy - rng.uniform(8, 26), cx + rng.uniform(10, 30), cy + rng.uniform(8, 26))
        q.fill(q.intersect(q.soften(blob, 6), body), rng.choice([(172, 96, 70), (108, 52, 40), (160, 86, 62)]), 0.35)
    streaks = q.mask()
    for _ in range(18):
        sx = rng.uniform(L + 6, R - 6)
        sy = rng.uniform(top, 1800)
        q.stroke(streaks, [(sx, sy), (sx + rng.uniform(-2, 2), sy + rng.uniform(60, 200))], rng.uniform(2, 5))
    q.fill(q.intersect(q.soften(streaks, 3), body), (60, 34, 30), 0.25)
    # le buche pontaie: file di quadratini scuri, dove si infilavano i ponteggi quando la costruirono
    putlog = q.mask()
    for row, yy in enumerate(range(1900, top + 30, -64)):
        for xx in range(int(L + 26 + (row % 2) * 30), int(R - 16), 60):
            if rng.random() < 0.8:
                rect(q, putlog, xx, yy, xx + 5, yy + 5)
    q.fill(q.intersect(putlog, body), (40, 22, 20))
    # la base di selenite
    sel = q.intersect(rect(q, q.mask(), L - 4, 1868, R + 4, 1942), shaft)
    sel = q.union(sel, rect(q, q.mask(), L - 4, 1868, R + 4, 1942))
    paint(q, sel, SELENITE, shadow=14, grain=0.3, seed=9, ow=0)
    joints = q.mask()
    for yy in (1886, 1905, 1924):
        q.stroke(joints, [(L - 4, yy), (R + 4, yy)], 0.7)
    for i, yy in enumerate((1868, 1886, 1905, 1924)):
        for xx in range(int(L + (i % 2) * 22), int(R), 44):
            q.stroke(joints, [(xx, yy), (xx, yy + 18)], 0.6)
    q.fill(q.intersect(joints, sel), (92, 84, 78), 0.9)
    q.outline(sel, 0.7, INK)
    # le finestre: il buio dentro, il davanzale lo mette il pezzo, l'intradosso di mattoni chiari
    inside = q.intersect(holes, shaft)
    q.fill(inside, (34, 22, 24))
    q.fill(q.intersect(q.shift(q.soften(inside, 3), 4, 4), inside), (70, 46, 42), 0.5)
    for sill, h in ((1580, 84), (1100, 58)):
        ring = q.minus(arch(q, q.mask(), 1378, 1462, sill - h + 36, sill), arch(q, q.mask(), 1384, 1456, sill - h + 36, sill))
        q.fill(ring, (190, 120, 88))
        q.outline(ring, 0.5, INK)
        lt.fill(arch(q, lt.mask(), 1388, 1452, sill - h + 38, sill - 2), LIT[:3], 0.85)
    for sx, sy in slits:
        if rng.random() < 0.5:
            lt.fill(lt.poly(lt.mask(), [(sx - 2.4, sy - 2), (sx + 2.4, sy - 2), (sx + 2.4, sy - 21), (sx - 2.4, sy - 21)]), LIT[:3])
    q.outline(q.minus(shaft, sel), 1.2, INK)

    # la rocchetta merlata alla base, a sinistra: il portichetto quattrocentesco con i merli a coda di rondine
    rk = rect(q, q.mask(), 1338, 1858, 1498, 1942)
    for mx in range(1342, 1496, 26):
        q.poly(rk, [(mx, 1858), (mx + 14, 1858), (mx + 14, 1842), (mx + 10, 1846), (mx + 7, 1840), (mx + 4, 1846), (mx, 1842)])
    rk_holes = q.mask()
    for ax in (1350, 1404, 1458):
        arch(q, rk_holes, ax, ax + 34, 1902, 1942)
    rkb = q.minus(rk, rk_holes)
    paint(q, rkb, (164, 86, 62), shadow=10, grain=0.25, seed=13, ow=1.0)
    courses(q, rkb, 1942, 1840, 4.6, (80, 42, 36), 0.3, joints=12, seed=4)
    q.fill(q.intersect(rk_holes, rk), (40, 26, 26))
    q.outline(q.intersect(rk_holes, rk), 0.6, INK)
    for ax in (1350, 1404, 1458):
        lt.fill(arch(q, lt.mask(), ax + 5, ax + 29, 1906, 1938), (236, 170, 96), 0.55)

    # la corona: le mensole (beccatelli) con gli archetti, che sporgono fino al parapetto su cui poggia il tetto
    crown = q.poly(q.mask(), [(side(top, -1), top + 8), (1300, 1000), (1300, 982), (1700, 982), (1700, 1000), (side(top, 1), top + 8)])
    paint(q, crown, (162, 84, 60), shadow=12, grain=0.25, seed=17, ow=0)
    corb = q.mask()
    for cx in range(1306, 1700, 22):
        q.poly(corb, [(cx, 1000), (cx + 12, 1000), (cx + 9, 1026), (cx + 3, 1026)])
    q.fill(q.intersect(corb, q.mask(255)), (120, 60, 46))
    arcs = q.mask()
    for cx in range(1306, 1690, 22):
        arch(q, arcs, cx + 12, cx + 22, 1008, 1022)
    q.fill(arcs, (44, 26, 26))
    q.fill(rect(q, q.mask(), 1298, 982, 1702, 990), (196, 168, 140))  # la cornice di pietra sotto il tetto
    q.outline(q.union(crown, corb), 1.1, INK)

    # il parafulmine sulla cima, dove cade il fulmine della zuffa (trappola "fulmine", x 1450-1570)
    rod = q.stroke(q.mask(), [(1510, 982), (1510, 846)], 2.0)
    q.stroke(rod, [(1500, 900), (1520, 900)], 1.2)
    q.stroke(rod, [(1503, 870), (1517, 870)], 1.0)
    q.ellipse(rod, 1507, 842, 1513, 848)
    q.fill(rod, (70, 66, 66))
    q.outline(rod, 0.5, INK)
    qsave(q, "asinelli.png", dim=(0.9, 0.86, 0.9))
    save(lt.result(), "asinelli-luci.png", 64)


def portico_house():
    """Il palazzo col portico ai lati della piazza (pezzi 0-3): il passaggio rialzato a y 1880 tra x 100 e 280, le
    colonne con gli archi, il tetto di coppi a y 1760 (lo mette il materiale), sopra la facciata con le persiane
    verdi, il cornicione e il tetto. Sotto la piazza, a sinistra di x 100, il basamento scende fino a y 2520 e copre
    il vuoto ai lati. Disegnato per il lato sinistro, a destra è specchiato (flip)."""
    X0, Y0, X1, Y1 = -220, 1330, 310, 2520
    q = Quadro(X1 - X0, Y1 - Y0, origin=(X0, Y0))
    lt = Quadro(X1 - X0, Y1 - Y0, origin=(X0, Y0))
    rng = rand(111)
    wall_col = (176, 96, 62, 255)
    # il basamento sotto la piazza: grossi conci che scuriscono andando giù
    plinth = rect(q, q.mask(), X0, 1998, 112, Y1)
    paint(q, plinth, (104, 84, 72, 255), shadow=10, grain=0.3, seed=3, ow=0)
    j = q.mask()
    for k, yy in enumerate(range(2030, Y1, 34)):
        q.stroke(j, [(X0, yy), (112, yy)], 0.8)
        for xx in range(X0 + (k % 2) * 30, 112, 60):
            q.stroke(j, [(xx, yy - 34), (xx, yy)], 0.7)
    q.fill(q.intersect(j, plinth), (58, 46, 42), 0.9)
    ramp = Image.linear_gradient("L").resize(q.size)
    q.fill(q.intersect(ramp, plinth), (24, 18, 20), 0.75)
    q.outline(plinth, 1.0, INK)
    # la facciata sopra il portico
    fac_top = 1410
    fac = rect(q, q.mask(), X0, fac_top, 300, 1772)
    holes = q.mask()
    wins = []
    for fl, fy in enumerate((1688, 1590, 1492)):
        for wx in (-170, -80, 10, 100, 190):
            w, h = 34, 56 if fl < 2 else 46
            wins.append((wx, fy - h, wx + w, fy))
            rect(q, holes, wx, fy - h, wx + w, fy)
    facb = q.minus(fac, holes)
    paint(q, facb, wall_col, shadow=18, grain=0.28, seed=5, ow=0)
    # le chiazze dell'intonaco e le colature
    for _ in range(14):
        cx, cy = rng.uniform(X0, 300), rng.uniform(fac_top, 1760)
        q.fill(q.intersect(q.soften(q.ellipse(q.mask(), cx - 30, cy - 20, cx + 30, cy + 20), 8), facb), rng.choice([(196, 118, 76), (150, 78, 54)]), 0.3)
    st = q.mask()
    for wx0, wy0, wx1, wy1 in wins:
        q.stroke(st, [(wx0 + 8, wy1), (wx0 + 9, wy1 + rng.uniform(10, 26))], 3)
    q.fill(q.intersect(q.soften(st, 2), facb), (90, 50, 40), 0.25)
    # i marcapiani chiari e il cornicione con le mensole
    for yy in (1700, 1602):
        band = rect(q, q.mask(), X0, yy, 300, yy + 6)
        paint(q, band, (204, 170, 130, 255), shadow=0, grain=0.1, seed=yy, rim=False, ow=0.5)
    corn = rect(q, q.mask(), X0, fac_top - 16, 308, fac_top)
    paint(q, corn, (196, 156, 116, 255), shadow=0, grain=0.15, seed=8, rim=False, ow=0.7)
    for cx in range(X0 + 6, 300, 18):
        q.fill(rect(q, q.mask(), cx, fac_top - 6, cx + 6, fac_top), (90, 62, 50))
    roof = q.poly(q.mask(), [(X0, fac_top - 16), (314, fac_top - 16), (290, fac_top - 50), (X0, fac_top - 50)])
    paint(q, roof, TERRA, shadow=8, grain=0.25, seed=9, ow=0.9)
    rl = q.mask()
    for xx in range(X0, 314, 9):
        q.stroke(rl, [(xx, fac_top - 48), (xx + 1, fac_top - 17)], 0.8)
    q.fill(q.intersect(rl, roof), (120, 58, 44), 0.6)
    # i comignoli
    for cx in (-120, 150):
        ch = rect(q, q.mask(), cx, fac_top - 92, cx + 20, fac_top - 40)
        q.poly(ch, [(cx - 5, fac_top - 92), (cx + 25, fac_top - 92), (cx + 22, fac_top - 100), (cx - 2, fac_top - 100)])
        paint(q, ch, (150, 80, 60, 255), shadow=6, grain=0.2, seed=cx, ow=0.8)
    # le finestre: vetri scuri, le persiane verdi aperte, il davanzale chiaro
    for i, (wx0, wy0, wx1, wy1) in enumerate(wins):
        q.fill(rect(q, q.mask(), wx0, wy0, wx1, wy1), (40, 34, 40))
        q.line([((wx0 + wx1) / 2, wy0), ((wx0 + wx1) / 2, wy1)], 0.8, (110, 96, 84))
        q.line([(wx0, wy0 + (wy1 - wy0) * 0.4), (wx1, wy0 + (wy1 - wy0) * 0.4)], 0.8, (110, 96, 84))
        sh = SHUTTERS[i % 2]
        closed = rng.random() < 0.3
        for s in ((-1, 1) if not closed else (0,)):
            if closed:
                sm = rect(q, q.mask(), wx0, wy0, wx1, wy1)
            else:
                sx = wx0 - 15 if s < 0 else wx1 + 1
                sm = rect(q, q.mask(), sx, wy0, sx + 14, wy1)
            paint(q, sm, sh + (255,), shadow=3, grain=0.15, seed=i, rim=False, ow=0.6)
            sl = q.mask()
            for yy in range(int(wy0 + 4), int(wy1), 4):
                q.stroke(sl, [(wx0 - 16, yy), (wx1 + 16, yy)], 0.4)
            q.fill(q.intersect(sl, sm), shade(sh + (255,), 0.7), 0.8)
        q.fill(rect(q, q.mask(), wx0 - 4, wy1, wx1 + 4, wy1 + 4), (214, 192, 160))
        if not closed and rng.random() < 0.55:
            lt.fill(rect(q, lt.mask(), wx0 + 1, wy0 + 1, wx1 - 1, wy1 - 1), LIT[:3], 0.9)
    q.outline(q.union(fac, corn), 1.2, INK)

    # il portico: il fondo in ombra con la porta e la vetrina, le colonne, gli archi, il soffitto
    back = rect(q, q.mask(), X0, 1772, 300, 1998)
    paint(q, back, (120, 70, 52, 255), shadow=0, grain=0.25, seed=12, rim=False, ow=0)
    q.fill(back, (30, 18, 22), 0.45)
    door = arch(q, q.mask(), 150, 196, 1830, 1880)
    q.fill(door, (52, 36, 34))
    q.outline(door, 0.6, INK)
    shop = rect(q, q.mask(), -60, 1812, 60, 1878)
    q.fill(shop, (64, 56, 58))
    q.outline(shop, 0.6, INK)
    lt.fill(rect(q, lt.mask(), -56, 1816, 56, 1874), (240, 186, 110), 0.7)
    lt.fill(rect(q, lt.mask(), 154, 1832, 192, 1878), (240, 186, 110), 0.45)
    # il basamento del passaggio rialzato, sotto il pavimento del pezzo 0 (y 1880-1898)
    podium = rect(q, q.mask(), X0, 1896, 300, 1998)
    paint(q, podium, (138, 116, 96, 255), shadow=10, grain=0.3, seed=14, ow=0)
    pj = q.mask()
    for yy in (1930, 1964):
        q.stroke(pj, [(X0, yy), (300, yy)], 0.7)
    for k, yy in enumerate((1896, 1930, 1964)):
        for xx in range(X0 + (k % 2) * 24, 300, 48):
            q.stroke(pj, [(xx, yy), (xx, yy + 34)], 0.6)
    q.fill(q.intersect(pj, podium), (80, 66, 58), 0.9)
    q.fill(arch(q, q.mask(), 196, 232, 1950, 1996), (36, 26, 26))  # la finestrella della cantina
    q.outline(podium, 1.0, INK)
    # colonne e archi tra il passaggio (1880) e il tetto (1760)
    arcade = rect(q, q.mask(), X0, 1764, 300, 1880)
    openings = q.mask()
    cols = [-190, -100, -10, 92, 186, 280]
    for a, b in zip(cols, cols[1:]):
        arch(q, openings, a + 9, b - 9, 1828, 1880)
    arc_m = q.minus(arcade, openings)
    paint(q, arc_m, (196, 132, 82, 255), shadow=8, grain=0.25, seed=15, ow=1.1)
    for c in cols:  # i capitelli e le basi delle colonne
        q.fill(rect(q, q.mask(), c - 12, 1826, c + 12, 1832), (214, 190, 156))
        q.fill(rect(q, q.mask(), c - 11, 1872, c + 11, 1880), (160, 136, 112))
    q.fill(q.intersect(q.soften(rect(q, q.mask(), X0, 1830, 300, 1846), 6), openings), (20, 12, 14), 0.35)
    # una lanterna appesa sotto un arco
    lan = rect(q, q.mask(), 40, 1840, 52, 1856)
    q.stroke(lan, [(46, 1832), (46, 1840)], 0.8)
    q.fill(lan, (60, 56, 52))
    lt.fill(q.soften(lt.ellipse(lt.mask(), 30, 1826, 62, 1870), 6), (255, 210, 140), 0.6)
    lt.fill(rect(q, lt.mask(), 42, 1843, 50, 1854), LIT_CORE[:3])
    qsave(q, "portico-casa.png", dim=(0.8, 0.77, 0.84))
    res = lt.result()
    save(res, "portico-casa-luci.png", 64)
    save(res.transpose(Image.FLIP_LEFT_RIGHT), "portico-casa-luci-dx.png", 64)  # le luci non si specchiano da sole


def statue():
    """San Petronio sul piedistallo, al centro della piazza (#433): il vescovo con la mitra e il piviale, il
    pastorale nella destra e nella sinistra il modellino della città con le Due Torri. Pietra spenta, dietro al
    gioco. Larga 130, alta 290 di mondo, con i piedi a (1150, 2000)."""
    W, H = 130, 290
    q = Quadro(W, H, origin=(-W / 2, -H))  # x 0 al centro, y 0 a terra
    stone = (150, 142, 128, 255)
    # il piedistallo: zoccolo, dado con la lapide, cornice
    ped = q.mask()
    rect(q, ped, -50, -22, 50, 0)
    rect(q, ped, -40, -150, 40, -22)
    rect(q, ped, -48, -166, 48, -150)
    rect(q, ped, -36, -176, 36, -166)
    paint(q, ped, (132, 118, 102, 255), shadow=10, grain=0.3, seed=3, ow=1.0)
    for yy in (-22, -150, -166):
        q.line([(-48, yy), (48, yy)], 0.7, INK)
    plate = rect(q, q.mask(), -26, -120, 26, -60)
    paint(q, plate, (172, 160, 140, 255), shadow=4, grain=0.15, seed=4, rim=False, ow=0.7)
    for k in range(4):
        q.line([(-18, -108 + k * 12), (18 - (k % 2) * 8, -108 + k * 12)], 0.7, (110, 100, 90))
    # il santo
    fig = q.mask()
    q.poly(fig, bezier((-24, -176), (-28, -200), (-20, -236), (-13, -250), 10) + bezier((13, -250), (20, -236), (28, -200), (24, -176), 10))  # il piviale
    q.ellipse(fig, -9, -266, 9, -246)  # la testa
    q.poly(fig, [(-8, -262), (-5, -284), (0, -280), (5, -284), (8, -262)])  # la mitra
    q.stroke(fig, [(-16, -230), (-30, -214)], 7)  # il braccio destro col pastorale
    q.stroke(fig, [(16, -230), (26, -218)], 7)  # il braccio sinistro che regge la città
    fig = q.smooth(fig, 1.0)
    paint(q, fig, stone, shadow=7, grain=0.3, seed=5, ow=1.0)
    folds = q.mask()
    for x in (-14, -6, 4, 12):
        q.stroke(folds, [(x, -236), (x * 1.5, -180)], 1.0)
    q.fill(q.intersect(q.soften(folds, 0.8), fig), shade(stone, 0.7), 0.7)
    q.fill(q.intersect(q.poly(q.mask(), [(-7, -262), (7, -262), (6, -268), (-6, -268)]), fig), shade(stone, 0.8))
    # il pastorale col ricciolo
    cro = q.stroke(q.mask(), [(-31, -176), (-31, -262)], 2.0)
    q.stroke(cro, [(-31, -262), (-27, -270), (-21, -266), (-23, -260)], 1.8)
    q.fill(cro, shade(stone, 0.85))
    q.outline(cro, 0.5, INK)
    # il modellino della città: le mura, le case e le Due Torri, una dritta e una storta
    city = q.mask()
    rect(q, city, 18, -232, 40, -220)
    q.poly(city, [(28, -232), (32, -232), (31, -262), (29, -262)])
    q.poly(city, [(34, -232), (37, -232), (39, -252), (36, -252)])
    paint(q, city, light(stone, 1.06), shadow=2, grain=0.15, seed=6, rim=False, ow=0.6)
    qsave(q, "statua.png")


def containers():
    """Il cantiere della Garisenda (#433): il recinto di container attorno alla base, uno in fila all'altro, in
    colori spenti (ruggine, grigio-azzurro, verde, crema), con le nervature, le porte con le barre, la rete del
    cantiere sopra e il cartello dei lavori. Largo 660, alto 92 di mondo, piedi a (700, 1942)."""
    W, H = 660, 92
    q = Quadro(W, H, origin=(370, 1850))
    rng = rand(121)
    cols = [(122, 70, 56), (88, 100, 110), (92, 104, 82), (156, 146, 126), (118, 80, 60)]
    x = 372
    i = 0
    while x < 1028:
        w = 124 if i % 3 else 96
        x1 = min(1028, x + w)
        col = cols[i % len(cols)] + (255,)
        box = rect(q, q.mask(), x, 1888, x1, 1942)
        paint(q, box, col, shadow=6, grain=0.3, seed=i, ow=1.0)
        rib = q.mask()
        for xx in range(int(x + 4), int(x1 - 2), 5):
            q.stroke(rib, [(xx, 1891), (xx, 1939)], 1.0)
        q.fill(q.intersect(rib, box), shade(col, 0.72), 0.7)
        q.fill(rect(q, q.mask(), x, 1888, x1, 1892), light(col, 1.15))
        q.fill(rect(q, q.mask(), x, 1938, x1, 1942), shade(col, 0.6))
        if i % 2 == 0:  # le porte con le barre di chiusura
            for bx in (x1 - 22, x1 - 12):
                q.line([(bx, 1892), (bx, 1938)], 1.2, (60, 56, 52))
        # la ruggine colata
        for _ in range(3):
            sx = rng.uniform(x + 6, x1 - 6)
            q.fill(q.intersect(q.soften(q.stroke(q.mask(), [(sx, 1892), (sx, 1892 + rng.uniform(10, 30))], 3), 2), box), (100, 56, 40), 0.4)
        x = x1 + 2
        i += 1
    # la rete del cantiere sopra i container, coi pali
    net = q.mask()
    for px in range(380, 1030, 70):
        q.stroke(net, [(px, 1888), (px, 1856)], 1.4)
    q.stroke(net, [(376, 1858), (1026, 1858)], 1.2)
    q.fill(net, (80, 80, 82))
    mesh = rect(q, q.mask(), 376, 1860, 1026, 1888)
    q.fill(mesh, (176, 104, 72), 0.4)  # arancio spento e trasparente, lontano dall'arancio dei giocatori
    grid = q.mask()
    for xx in range(376, 1026, 5):
        q.stroke(grid, [(xx, 1860), (xx + 4, 1888)], 0.3)
    q.fill(q.intersect(grid, mesh), (120, 66, 48), 0.5)
    # il cartello dei lavori
    sign = q.poly(q.mask(), [(590, 1882), (610, 1882), (600, 1864)])
    q.fill(sign, (206, 176, 92))
    q.outline(sign, 0.6, INK)
    q.line([(600, 1870), (600, 1877)], 1.0, INK)
    qsave(q, "cantiere.png")


def lamp_post():
    """Il lampione di ghisa della piazza: palo scanalato verde scuro con la base, il braccio a ricciolo e la lanterna.
    La tela è larga per tenere anche l'alone della luce di sera (lampione-luci.png, stessa misura)."""
    W, H = 90, 180
    q = Quadro(W, H, origin=(-W / 2, -H))
    lt = Quadro(W, H, origin=(-W / 2, -H))
    iron = (50, 58, 54, 255)
    m = q.mask()
    q.poly(m, [(-8, 0), (8, 0), (6, -14), (-6, -14)])
    q.poly(m, [(-3, -14), (3, -14), (2, -140), (-2, -140)])
    q.ellipse(m, -5, -146, 5, -136)
    q.stroke(m, [(0, -140), (6, -150), (14, -150)], 1.6)
    q.poly(m, [(8, -146), (22, -146), (20, -164), (10, -164)])  # la lanterna
    q.poly(m, [(7, -164), (23, -164), (15, -172)])
    paint(q, m, iron, shadow=2, grain=0.1, seed=1, rim=True, ow=0.8)
    glass = q.poly(q.mask(), [(10, -149), (20, -149), (19, -162), (11, -162)])
    q.fill(glass, (150, 140, 110))
    lt.fill(q.soften(lt.ellipse(lt.mask(), -14, -186, 44, -126), 9), (255, 200, 120), 0.55)
    lt.fill(lt.poly(lt.mask(), [(10.5, -149.5), (19.5, -149.5), (18.6, -161.5), (11.4, -161.5)]), LIT_CORE[:3])
    qsave(q, "lampione.png")
    save(lt.result(), "lampione-luci.png", 64)


def sign_30():
    """Il cartello "Città 30" (#433, la battuta del gruppo): il tondo del limite con il bordo rosso spento, sotto la
    targa bianca con la scritta, sul palo grigio. Generico, senza stemmi. Piedi a terra."""
    W, H = 60, 150
    q = Quadro(W, H, origin=(-W / 2, -H))
    pole = q.poly(q.mask(), [(-1.6, 0), (1.6, 0), (1.6, -118), (-1.6, -118)])
    paint(q, pole, (120, 122, 124, 255), shadow=1, grain=0, seed=1, ow=0.6)
    disc = q.ellipse(q.mask(), -19, -146, 19, -108)
    q.fill(disc, (176, 60, 52))
    q.fill(q.ellipse(q.mask(), -14, -141, 14, -113), (224, 218, 204))
    q.outline(disc, 0.8, INK)
    plate = rect(q, q.mask(), -22, -104, 22, -84)
    q.fill(plate, (224, 218, 204))
    q.outline(plate, 0.8, INK)
    img = q.img
    d = ImageDraw.Draw(img)
    try:
        bold = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", int(q.k * 15))
        small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", int(q.k * 6.2))
    except OSError:
        bold = small = ImageFont.load_default()
    d.text(q._p(0, -127), "30", fill=(36, 30, 30, 255), font=bold, anchor="mm")
    d.text(q._p(0, -94), "CITTÀ 30", fill=(36, 30, 30, 255), font=small, anchor="mm")
    qsave(q, "cartello.png")


def qsave(q, name, colors=256, dim=None):
    """Salva un Quadro con la palette ridotta (le decorazioni grandi pesano meno di un terzo). dim spegne i colori
    (r, g, b da 0 a 1): le decorazioni grandi restano dietro ai pezzi del palco (stile grafico, sezione 7)."""
    img = q.result()
    if dim:
        r, g, b, a = img.split()
        img = Image.merge("RGBA", (r.point(lambda v: int(v * dim[0])), g.point(lambda v: int(v * dim[1])), b.point(lambda v: int(v * dim[2])), a))
    save(img, name, colors)


def props():
    asinelli()
    portico_house()
    statue()
    containers()
    lamp_post()
    sign_30()


# ======================================================================================================
# Lo sfondo: tre strati a 2x, disegnati in coordinate di mondo
# ======================================================================================================
DIM = {"sfondo-1.png": (0.9, 0.88, 0.94), "sfondo-2.png": (0.84, 0.81, 0.88)}  # gli strati vicini più spenti del palco


def layer(name, parallax, LW, LH, draw):
    origin = (CENTER[0] - LW / 2, CENTER[1] - LH / 2)
    t = Tela(LW, LH, origin=origin, ss=1)
    t.lights = Tela(LW, LH, origin=origin, ss=1)
    draw(t)
    if name in DIM:  # più spento e un po' più freddo: i pezzi del palco devono staccarsi (stile grafico, sezione 7)
        r, g, b, a = t.img.split()
        k = DIM[name]
        t.img = Image.merge("RGBA", (r.point(lambda v: int(v * k[0])), g.point(lambda v: int(v * k[1])), b.point(lambda v: int(v * k[2])), a))
    t.save(OUT, name, colors=256)
    t.lights.save(OUT, name.replace(".png", "-luci.png"), colors=64)


def sky_far(t):
    """Lo strato più lontano: il cielo è trasparente (lo dipinge il gioco), poi i colli bolognesi in foschia con il
    santuario di San Luca e il suo portico che sale a zig-zag, e sotto l'orizzonte il mare di tetti rossi della città
    vista dall'alto, sempre più grandi e meno velati verso il basso."""
    x0, x1 = t.ox, t.ox + t.w
    bottom = t.oy + t.h
    rng = rand(201)
    # i colli: tre file, la più lontana più velata
    for k, (base, amp, col, seed) in enumerate(((HORIZON - 50, 170, (118, 118, 136), 3), (HORIZON - 18, 120, (100, 108, 100), 5), (HORIZON + 6, 70, (92, 96, 82), 7))):
        q = patch(t, x0, base - amp - 60, x1, HORIZON + 30)
        m = q.mask()
        pts = [(x0, HORIZON + 30)]
        r = rand(seed)
        ph = [r.uniform(0, 6.28) for _ in range(3)]
        for i in range(0, 121):
            x = x0 + (x1 - x0) * i / 120
            u = x / 700.0
            y = base - amp * (0.55 + 0.25 * math.sin(u * 1.3 + ph[0]) + 0.15 * math.sin(u * 3.1 + ph[1]) + 0.05 * math.sin(u * 7.7 + ph[2]))
            if k == 0 and 250 < x < 750:  # il Colle della Guardia, dove sta San Luca
                y -= 70 * math.exp(-((x - 470) / 150) ** 2)
            pts.append((x, y))
        pts.append((x1, HORIZON + 30))
        q.poly(m, pts)
        m = q.smooth(m, 3)
        colh = far(col, 0.55 - k * 0.12)
        paint(q, m, colh, ink=far((60, 56, 70), 0.6), shadow=10, grain=0.25, seed=seed, ow=0.6)
        if k > 0:  # i boschi e le ville: macchie più scure
            spots = q.mask()
            for _ in range(60):
                sx = r.uniform(x0, x1)
                sy = r.uniform(base - amp * 0.4, HORIZON + 10)
                q.ellipse(spots, sx - r.uniform(6, 18), sy - r.uniform(3, 8), sx + r.uniform(6, 18), sy + r.uniform(3, 8))
            q.fill(q.intersect(q.soften(spots, 2), m), shade(colh, 0.82), 0.6)
        stamp(t, q)
        if k == 0:
            san_luca(t, 470, base - amp * 0.62 - 62)
    # il mare di tetti: file sempre più grandi verso il basso
    y = HORIZON
    row = 0
    while y < bottom:
        hgt = 10 + (y - HORIZON) * 0.07
        k = max(0.32, 0.78 - (y - HORIZON) / 1400)
        x = x0 - rng.uniform(0, 40)
        while x < x1:
            w = rng.uniform(2.4, 4.6) * hgt
            wall = far(rng.choice(FACADES), k)
            roof = far(rng.choice([(150, 78, 58), (162, 90, 64), (138, 72, 56), (156, 96, 72)]), k)
            ink = far((60, 40, 40), k)
            top = y - hgt
            t.rect(x, top + hgt * 0.35, x + w, y + 2, fill=wall)
            t.rect(x + w * 0.7, top + hgt * 0.35, x + w, y + 2, fill=shade(wall, 0.84))
            t.poly([(x - 1, top + hgt * 0.4), (x + w * 0.1, top), (x + w * 0.9, top), (x + w + 1, top + hgt * 0.4)], fill=roof)
            t.poly([(x + w * 0.55, top), (x + w * 0.9, top), (x + w + 1, top + hgt * 0.4), (x + w * 0.55, top + hgt * 0.4)], fill=shade(roof, 0.84))
            t.line([(x - 1, top + hgt * 0.4), (x + w + 1, top + hgt * 0.4)], fill=ink, width=0.5 + hgt * 0.015)
            nwin = int(w / (hgt * 0.7)) if hgt > 14 else 0
            for i in range(nwin):
                wx = x + (i + 0.5) * w / max(1, nwin) - hgt * 0.06
                wy = top + hgt * 0.55
                t.rect(wx, wy, wx + hgt * 0.12, wy + hgt * 0.2, fill=far((50, 40, 44), k))
                if rng.random() < 0.28:
                    t.lights.rect(wx, wy, wx + hgt * 0.12, wy + hgt * 0.2, fill=(236, 186, 112, 255))
            if rng.random() < 0.025 and y < HORIZON + 260:  # una torre lontana
                tw, th = hgt * 0.5, hgt * rng.uniform(4, 7)
                tx = x + w / 2
                t.rect(tx - tw / 2, y - th, tx + tw / 2, y, fill=far(BRICK, k))
                t.rect(tx, y - th, tx + tw / 2, y, fill=far(BRICK_D, k))
                t.rect(tx - tw * 0.7, y - th - hgt * 0.12, tx + tw * 0.7, y - th, fill=far(BRICK, k))
            x += w + rng.uniform(-2, 3)
        y += hgt * 0.62
        row += 1
    # la foschia sopra l'orizzonte del mare di tetti: una velatura che sale piano
    q = patch(t, x0, HORIZON - 30, x1, HORIZON + 140)
    ramp = Image.linear_gradient("L").transpose(Image.FLIP_TOP_BOTTOM).resize(q.size)
    q.fill(ramp, HAZE[:3], 0.45)
    stamp(t, q)


def san_luca(t, cx, base):
    """Il santuario della Madonna di San Luca sul colle: la cupola ellittica sul tamburo, i due campaniletti, il
    pronao, e il portico lunghissimo che scende a zig-zag dal colle verso la città, con le finestrelle accese."""
    q = patch(t, cx - 260, base - 80, cx + 340, HORIZON + 10)
    pink = far((206, 150, 126), 0.42)
    m = q.mask()
    rect(q, m, cx - 40, base - 26, cx + 40, base)  # il corpo
    q.ellipse(m, cx - 28, base - 58, cx + 28, base - 14)  # la cupola
    rect(q, m, cx - 4, base - 70, cx + 4, base - 54)  # la lanterna
    for s in (-1, 1):
        rect(q, m, cx + s * 44 - 6, base - 46, cx + s * 44 + 6, base)
        q.poly(m, [(cx + s * 44 - 7, base - 46), (cx + s * 44 + 7, base - 46), (cx + s * 44, base - 56)])
    q.poly(m, [(cx - 16, base - 26), (cx + 16, base - 26), (cx, base - 38)])
    paint(q, m, pink, ink=far((70, 50, 56), 0.5), shadow=6, grain=0.2, seed=3, ow=0.6)
    # il portico: una striscia chiara a zig-zag con le arcate scure
    path = [(cx + 30, base), (cx + 120, base + 30), (cx + 60, base + 62), (cx + 180, base + 96), (cx + 140, base + 128), (cx + 300, HORIZON - 4)]
    band = q.mask()
    for a, b in zip(path, path[1:]):
        q.stroke(band, [a, b], 4.5)
    q.fill(band, far((214, 170, 130), 0.4))
    dots = q.mask()
    for a, b in zip(path, path[1:]):
        n = int(math.hypot(b[0] - a[0], b[1] - a[1]) / 5)
        for i in range(n):
            u = i / n
            px, py = a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u
            q.ellipse(dots, px - 1, py - 0.6, px + 1, py + 1.6)
            if i % 7 == 0:
                t.lights.rect(px - 0.8, py - 0.4, px + 0.8, py + 1.2, fill=(240, 196, 120, 255))
    q.fill(q.intersect(dots, band), far((90, 60, 56), 0.4))
    stamp(t, q)
    for wx in (cx - 30, cx - 12, cx + 12, cx + 30):
        t.lights.rect(wx - 1.5, base - 18, wx + 1.5, base - 10, fill=(240, 196, 120, 255))


def tower(t, cx, base, w, h, col, crown, seed, haze):
    """Una torre medievale della città: il fusto di mattoni che si stringe un poco, le buche pontaie, le feritoie
    e la cima: "beccatelli" (mensole e parapetto, come la Prendiparte), "merli" a coda di rondine (Accursio, con
    l'orologio), "tetto" (il cappello di coppi) o "dritta" (mozzata)."""
    q = patch(t, cx - w, base - h - 60, cx + w, base + 2)
    rng = rand(seed)
    c = far(col, haze)
    ink = far((50, 30, 30), haze * 0.8)
    m = q.poly(q.mask(), [(cx - w / 2, base), (cx - w / 2 + w * 0.06, base - h), (cx + w / 2 - w * 0.06, base - h), (cx + w / 2, base)])
    top = base - h
    if crown == "beccatelli":
        q.poly(m, [(cx - w * 0.56, top - 4), (cx + w * 0.56, top - 4), (cx + w * 0.44, top + 10), (cx - w * 0.44, top + 10)])
        rect(q, m, cx - w * 0.56, top - 18, cx + w * 0.56, top - 4)
        rect(q, m, cx - w * 0.25, top - 34, cx + w * 0.25, top - 18)
    elif crown == "merli":
        rect(q, m, cx - w * 0.54, top - 14, cx + w * 0.54, top + 2)
        n = 4
        for i in range(n):
            mx = cx - w * 0.54 + (i + 0.5) * w * 1.08 / n
            q.poly(m, [(mx - w * 0.09, top - 14), (mx + w * 0.09, top - 14), (mx + w * 0.09, top - 26), (mx, top - 20), (mx - w * 0.09, top - 26)])
    elif crown == "tetto":
        q.poly(m, [(cx - w * 0.5, top), (cx + w * 0.5, top), (cx, top - w * 0.8)])
    paint(q, m, c, ink=ink, shadow=w * 0.28, grain=0.25, seed=seed, ow=0.7)
    courses(q, m, base, top, 4.5, shade(c, 0.6), 0.22)
    holes = q.mask()
    for yy in range(int(base - 30), int(top + 20), -38):
        for xx in (cx - w * 0.22, cx + w * 0.18):
            if rng.random() < 0.7:
                rect(q, holes, xx, yy, xx + 2.4, yy + 2.4)
    q.fill(holes, far((40, 24, 24), haze))
    for _ in range(3):
        sx, sy = cx + rng.uniform(-w * 0.25, w * 0.25), rng.uniform(top + 30, base - 40)
        q.fill(rect(q, q.mask(), sx - 1.6, sy, sx + 1.6, sy + 12), far((34, 22, 22), haze))
        if rng.random() < 0.6:
            t.lights.rect(sx - 1.4, sy + 1, sx + 1.4, sy + 11, fill=LIT)
    if crown == "merli":  # l'orologio della torre del palazzo comunale
        clk = q.ellipse(q.mask(), cx - w * 0.22, top + 18, cx + w * 0.22, top + 18 + w * 0.44)
        q.fill(clk, far((222, 206, 170), haze))
        q.outline(clk, 0.5, ink)
        if t.lights is not None:
            t.lights.ellipse(cx - w * 0.2, top + 19, cx + w * 0.2, top + 17 + w * 0.44, fill=(250, 226, 170, 255))
    stamp(t, q)


def house_row(t, x_from, x_to, base, hmin, hmax, haze, seed, lit_p=0.3, scale=1.0):
    """Una fila di case a mezza distanza: facciate rosse, arancio e ocra con le finestre, i portici in basso,
    i tetti di coppi a falda e i comignoli. Ogni casa è dipinta con la sua ombra e il contorno."""
    rng = rand(seed)
    x = x_from
    while x < x_to:
        w = rng.uniform(70, 150) * scale
        h = rng.uniform(hmin, hmax)
        col = far(rng.choice(FACADES), haze)
        roof = far(rng.choice([(160, 78, 54), (174, 92, 62), (146, 70, 52)]), haze)
        ink = far((50, 32, 32), haze * 0.8)
        top = base - h
        q = patch(t, x - 8, top - 40 * scale, x + w + 8, base + 2)
        m = rect(q, q.mask(), x, top, x + w, base)
        holes = q.mask()
        fh = 34 * scale
        bays = max(2, int(w / (26 * scale)))
        bw = w / bays
        ph = 40 * scale  # il portico
        for i in range(bays):
            arch(q, holes, x + i * bw + bw * 0.14, x + (i + 1) * bw - bw * 0.14, base - ph * 0.55, base)
        wins = []
        fy = base - ph - 10 * scale
        while fy - fh * 0.6 > top + 8 * scale:
            for i in range(bays):
                wx = x + i * bw + bw * 0.34
                wins.append((wx, fy - fh * 0.55, wx + bw * 0.32, fy))
                rect(q, holes, *wins[-1])
            fy -= fh
        body = q.minus(m, holes)
        paint(q, body, col, ink=ink, shadow=w * 0.12, grain=0.25, seed=int(x), ow=0)
        q.fill(q.intersect(holes, m), far((44, 32, 36), haze))
        sh = far(rng.choice(SHUTTERS), haze)
        for wx0, wy0, wx1, wy1 in wins:
            if rng.random() < 0.5:
                q.fill(rect(q, q.mask(), wx0 - (wx1 - wx0) * 0.45, wy0, wx0, wy1), sh)
                q.fill(rect(q, q.mask(), wx1, wy0, wx1 + (wx1 - wx0) * 0.45, wy1), sh)
            elif rng.random() < lit_p:
                lit(t, wx0 + 0.5, wy0 + 0.5, wx1 - 0.5, wy1 - 0.5)
        for i in range(bays):
            if rng.random() < lit_p * 0.8:
                lit(t, x + i * bw + bw * 0.2, base - ph * 0.5, x + (i + 1) * bw - bw * 0.2, base - 2)
        # il cornicione e il tetto
        rr = q.poly(q.mask(), [(x - 5 * scale, top), (x + w + 5 * scale, top), (x + w - 6 * scale, top - 18 * scale), (x + 6 * scale, top - 18 * scale)])
        paint(q, rr, roof, ink=ink, shadow=5, grain=0.25, seed=int(x) + 1, rim=True, ow=0.6)
        rl = q.mask()
        for xx in range(int(x), int(x + w), max(3, int(6 * scale))):
            q.stroke(rl, [(xx, top - 17 * scale), (xx, top - 1)], 0.5)
        q.fill(q.intersect(rl, rr), shade(roof, 0.8), 0.6)
        if rng.random() < 0.7:
            chx = x + rng.uniform(0.15, 0.8) * w
            ch = rect(q, q.mask(), chx, top - 32 * scale, chx + 8 * scale, top - 10 * scale)
            rect(q, ch, chx - 2 * scale, top - 36 * scale, chx + 10 * scale, top - 31 * scale)
            paint(q, ch, far((140, 74, 56), haze), ink=ink, shadow=2, grain=0, seed=int(x) + 2, ow=0.5)
        q.outline(m, 0.7, ink)
        stamp(t, q)
        x += w + rng.uniform(-4, 2)


def san_petronio(t, cx, base, W, haze):
    """La facciata di San Petronio vista da lontano: la basilica enorme col frontone basso, in basso il marmo rosa
    e bianco a riquadri con i tre portali, in alto il mattone grezzo mai finito con le buche, e dietro la navata."""
    H = W * 0.86
    q = patch(t, cx - W * 0.62, base - H - 40, cx + W * 0.62, base + 2)
    brick = far((160, 98, 72), haze)
    marble = far((214, 192, 180), haze)
    pink = far((200, 150, 140), haze)
    ink = far((60, 40, 40), haze * 0.8)
    top = base - H
    m = q.mask()
    # la navata dietro, più alta della facciata ai lati
    q.poly(m, [(cx - W * 0.5, base), (cx - W * 0.5, base - H * 0.62), (cx - W * 0.25, base - H * 0.74), (cx - W * 0.22, base - H * 0.86),
               (cx, top), (cx + W * 0.22, base - H * 0.86), (cx + W * 0.25, base - H * 0.74), (cx + W * 0.5, base - H * 0.62), (cx + W * 0.5, base)])
    paint(q, m, brick, ink=ink, shadow=W * 0.08, grain=0.35, seed=3, ow=0.8)
    courses(q, m, base, top, 4, shade(brick, 0.7), 0.18)
    holes = q.mask()
    for yy in range(int(base - H * 0.42), int(top + 10), -16):
        for xx in range(int(cx - W * 0.46), int(cx + W * 0.46), 18):
            rect(q, holes, xx, yy, xx + 2.4, yy + 2.4)
    q.fill(q.intersect(holes, m), far((60, 36, 32), haze), 0.8)
    # il marmo: la fascia bassa a riquadri rosa e bianchi
    mb = q.intersect(rect(q, q.mask(), cx - W * 0.5, base - H * 0.4, cx + W * 0.5, base), m)
    q.fill(mb, marble)
    panels = q.mask()
    for i in range(12):
        x0 = cx - W * 0.5 + i * W / 12
        rect(q, panels, x0 + W * 0.012, base - H * 0.36, x0 + W / 12 - W * 0.012, base - H * 0.08)
    q.fill(q.intersect(panels, mb), pink, 0.8)
    pil = q.mask()
    for i in range(1, 12):
        rect(q, pil, cx - W * 0.5 + i * W / 12 - 1.4, base - H * 0.4, cx - W * 0.5 + i * W / 12 + 1.4, base)
    q.fill(pil, light(marble, 1.06))
    q.fill(q.inner_shadow(mb, -W * 0.06, 0, W * 0.03), shade(marble, 0.78), 0.8)
    # i tre portali
    for px, pw, ph in ((cx, W * 0.16, H * 0.36), (cx - W * 0.3, W * 0.08, H * 0.22), (cx + W * 0.3, W * 0.08, H * 0.22)):
        door = arch(q, q.mask(), px - pw / 2, px + pw / 2, base - ph + pw / 2, base)
        frame = arch(q, q.mask(), px - pw / 2 - 4, px + pw / 2 + 4, base - ph + pw / 2, base)
        q.fill(frame, light(marble, 1.08))
        q.outline(frame, 0.6, ink)
        q.fill(door, far((54, 40, 42), haze))
        lit(t, px - pw * 0.3, base - ph * 0.6, px + pw * 0.3, base - 2)
    q.outline(mb, 0.6, ink)
    stamp(t, q)


def dome(t, cx, base, r, haze):
    """La cupola di Santa Maria della Vita: il tamburo con le finestre, la calotta di piombo, la lanterna."""
    q = patch(t, cx - r * 1.3, base - r * 2.6, cx + r * 1.3, base + 2)
    drum = rect(q, q.mask(), cx - r, base - r * 0.9, cx + r, base)
    paint(q, drum, far((196, 150, 110), haze), ink=far((60, 40, 40), haze), shadow=r * 0.4, grain=0.2, seed=3, ow=0.6)
    for i in range(5):
        wx = cx - r * 0.8 + i * r * 0.4
        q.fill(arch(q, q.mask(), wx - 2.5, wx + 2.5, base - r * 0.6, base - r * 0.3), far((44, 34, 38), haze))
        lit(t, wx - 2, base - r * 0.6, wx + 2, base - r * 0.32, arched=True)
    cap = q.mask()
    q.poly(cap, bezier((cx - r * 1.05, base - r * 0.9), (cx - r * 1.05, base - r * 1.9), (cx - r * 0.3, base - r * 2.0), (cx, base - r * 2.0), 16) +
           bezier((cx, base - r * 2.0), (cx + r * 0.3, base - r * 2.0), (cx + r * 1.05, base - r * 1.9), (cx + r * 1.05, base - r * 0.9), 16))
    rect(q, cap, cx - r * 0.14, base - r * 2.4, cx + r * 0.14, base - r * 1.95)
    paint(q, cap, far((120, 128, 130), haze), ink=far((50, 44, 50), haze), shadow=r * 0.5, grain=0.2, seed=4, ow=0.6)
    ribs = q.mask()
    for k in range(-2, 3):
        q.stroke(ribs, [(cx + k * r * 0.42, base - r * 0.92), (cx + k * r * 0.12, base - r * 1.95)], 0.8)
    q.fill(q.intersect(ribs, cap), far((160, 166, 166), haze), 0.7)
    stamp(t, q)


def city_mid(t):
    """Lo strato di mezzo: la città a mezza distanza. Una prima fila di case alta dietro, le torri (la Prendiparte con
    la corona di beccatelli, la torre dell'orologio merlata, l'Azzoguidi, una con il tetto), la facciata di San
    Petronio a sinistra e la cupola della Vita a destra, e una seconda fila di case davanti, più vicina e più bassa."""
    x0, x1 = t.ox, t.ox + t.w
    house_row(t, x0, x1, MID_BASE - 70, 110, 170, 0.5, 301, lit_p=0.25, scale=0.7)
    tower(t, 640, MID_BASE - 40, 46, 420, (150, 78, 58), "beccatelli", 11, 0.42)  # la Prendiparte
    tower(t, 1700, MID_BASE - 40, 40, 380, (156, 84, 60), "dritta", 12, 0.44)  # l'Azzoguidi
    tower(t, 160, MID_BASE - 40, 48, 320, (164, 90, 62), "merli", 13, 0.46)  # la torre dell'orologio
    tower(t, 2150, MID_BASE - 40, 36, 290, (150, 80, 60), "tetto", 14, 0.48)
    san_petronio(t, 390, MID_BASE - 30, 300, 0.36)
    dome(t, 1960, MID_BASE - 60, 50, 0.38)
    house_row(t, x0, x1, MID_BASE + 120, 150, 230, 0.28, 302, lit_p=0.3, scale=0.85)
    # sotto, fino al fondo dello strato: il buio delle strade e dei cortili, coperto dallo strato vicino
    q = patch(t, x0, MID_BASE + 116, x1, t.oy + t.h)
    q.fill(q.mask(255), far((70, 50, 50), 0.3))
    stamp(t, q)


def mercanzia(t, cx, base):
    """Il Palazzo della Mercanzia, accanto alle Due Torri: gotico di mattoni, la loggia a due grandi archi acuti sui
    pilastri, sopra il balconcino di marmo col baldacchino, le bifore acute e la merlatura in cima."""
    W, H = 220, 330
    q = patch(t, cx - W / 2 - 10, base - H - 30, cx + W / 2 + 10, base + 2)
    brick = (166, 78, 56, 255)
    ink = (44, 28, 28, 255)
    top = base - H
    m = rect(q, q.mask(), cx - W / 2, top, cx + W / 2, base)
    for i in range(7):  # i merli
        mx = cx - W / 2 + (i + 0.5) * W / 7
        q.poly(m, [(mx - 10, top), (mx + 10, top), (mx + 10, top - 20), (mx, top - 13), (mx - 10, top - 20)])
    holes = q.mask()
    for ax in (cx - W / 2 + 14, cx + 6):
        arch(q, holes, ax, ax + W / 2 - 20, base - 120, base, pointed=True)
    for bx in (cx - W / 2 + 22, cx + W / 2 - 66):
        for k in (0, 1):
            arch(q, holes, bx + k * 23, bx + k * 23 + 18, base - 300, base - 236, pointed=True)
    body = q.minus(m, holes)
    paint(q, body, brick, ink=ink, shadow=26, grain=0.3, seed=21, ow=1.0)
    courses(q, body, base, top - 20, 4.6, (90, 46, 38), 0.22, joints=12, seed=21)
    # la fascia di archetti sotto la merlatura e il fregio di cotto
    fr = q.mask()
    for i in range(14):
        ax = cx - W / 2 + i * W / 14
        arch(q, fr, ax + 2, ax + W / 14 - 2, top + 20, top + 26)
    q.fill(fr, (90, 44, 38))
    # la loggia: il buio con la volta, i pilastri chiari
    q.fill(q.intersect(holes, m), (38, 24, 26))
    q.fill(q.intersect(q.shift(q.soften(holes, 6), 8, 8), holes), (84, 52, 46), 0.4)
    for ax in (cx - W / 2 + 14, cx + 6):
        ring = q.minus(arch(q, q.mask(), ax - 5, ax + W / 2 - 15, base - 120, base, pointed=True), arch(q, q.mask(), ax, ax + W / 2 - 20, base - 120, base, pointed=True))
        q.fill(ring, (204, 170, 136))
        q.outline(ring, 0.6, ink)
        lit(t, ax + W / 4 - 16, base - 70, ax + W / 4 - 4, base - 54)  # la lanterna sotto la volta
    # il balcone di marmo col baldacchino
    bal = q.mask()
    rect(q, bal, cx - 30, base - 186, cx + 30, base - 176)
    q.poly(bal, [(cx - 30, base - 176), (cx + 30, base - 176), (cx + 18, base - 166), (cx - 18, base - 166)])
    q.poly(bal, [(cx - 26, base - 236), (cx + 26, base - 236), (cx, base - 268)])
    rect(q, bal, cx - 26, base - 236, cx - 22, base - 186)
    rect(q, bal, cx + 22, base - 236, cx + 26, base - 186)
    paint(q, bal, (214, 200, 180, 255), ink=ink, shadow=6, grain=0.15, seed=22, ow=0.8)
    q.fill(rect(q, q.mask(), cx - 20, base - 232, cx + 20, base - 188), (50, 36, 38))
    lit(t, cx - 16, base - 228, cx + 16, base - 190)
    for bx in (cx - W / 2 + 22, cx + W / 2 - 66):
        for k in (0, 1):
            lit(t, bx + k * 23 + 2, base - 290, bx + k * 23 + 16, base - 238)
    stamp(t, q)


def palazzo(t, x, w, base, rng, floors=3):
    """Un palazzo col portico su via Rizzoli: archi tondi sulle colonne, il fondo del portico in ombra con le vetrine,
    i piani con le finestre e le persiane, i marcapiani, il cornicione con le mensole, il tetto e i comignoli."""
    fh = rng.uniform(66, 76)
    ph = rng.uniform(92, 104)
    top = base - ph - floors * fh - 10
    q = patch(t, x - 10, top - 70, x + w + 10, base + 2)
    col = rng.choice(FACADES) + (255,)
    col = mix(col, (96, 70, 70, 255), 0.12)  # un po' più spento: sta dietro al palco
    ink = (40, 28, 28, 255)
    m = rect(q, q.mask(), x, top, x + w, base)
    holes = q.mask()
    bays = max(2, int(round(w / 74)))
    bw = w / bays
    cw = bw * 0.18
    for i in range(bays):
        arch(q, holes, x + i * bw + cw / 2, x + (i + 1) * bw - cw / 2, base - ph + (bw - cw) / 2, base)
    wins = []
    for f in range(floors):
        fy = base - ph - 12 - f * fh
        for i in range(bays):
            ww = bw * 0.32
            wh = fh * (0.6 if f < floors - 1 else 0.48)
            wx = x + i * bw + (bw - ww) / 2
            wins.append((wx, fy - wh, wx + ww, fy))
            rect(q, holes, *wins[-1])
    body = q.minus(m, holes)
    paint(q, body, col, ink=ink, shadow=w * 0.1, grain=0.3, seed=int(x) + 5, ow=0)
    for _ in range(int(w / 40)):
        cx, cy = rng.uniform(x, x + w), rng.uniform(top, base - ph)
        q.fill(q.intersect(q.soften(q.ellipse(q.mask(), cx - 24, cy - 16, cx + 24, cy + 16), 7), body), rng.choice([light(col, 1.1), shade(col, 0.85)]), 0.35)
    for f in range(floors):  # i marcapiani
        yy = base - ph - f * fh
        q.fill(q.intersect(rect(q, q.mask(), x, yy - 4, x + w, yy), m), light(col, 1.14))
    # il portico: il fondo scuro con la volta e le vetrine
    inside = q.intersect(holes, rect(q, q.mask(), x, base - ph, x + w, base))
    q.fill(inside, mix(col, (24, 16, 20, 255), 0.72))
    q.fill(q.intersect(q.shift(q.soften(inside, 8), 10, 10), inside), shade(col, 0.5), 0.45)
    for i in range(bays):
        sx0, sx1 = x + i * bw + bw * 0.24, x + (i + 1) * bw - bw * 0.24
        if rng.random() < 0.7:
            q.fill(rect(q, q.mask(), sx0, base - ph * 0.55, sx1, base - 6), (70, 62, 62))
            lit(t, sx0 + 2, base - ph * 0.55 + 2, sx1 - 2, base - 8)
    for i in range(bays + 1):  # i capitelli
        cx = x + i * bw
        q.fill(q.intersect(rect(q, q.mask(), cx - cw * 0.7, base - ph + (bw - cw) / 2 - 4, cx + cw * 0.7, base - ph + (bw - cw) / 2 + 2), m), light(col, 1.2))
    # le finestre e le persiane
    sh = rng.choice(SHUTTERS)
    for wx0, wy0, wx1, wy1 in wins:
        q.fill(rect(q, q.mask(), wx0, wy0, wx1, wy1), (40, 34, 40))
        q.line([((wx0 + wx1) / 2, wy0), ((wx0 + wx1) / 2, wy1)], 0.7, (100, 90, 84))
        kind = rng.random()
        if kind < 0.45:
            for sx in (wx0 - (wx1 - wx0) * 0.5, wx1):
                sm = rect(q, q.mask(), sx, wy0, sx + (wx1 - wx0) * 0.5, wy1)
                q.fill(sm, sh)
                q.fill(q.inner_shadow(sm, -2, 0, 1), shade(sh, 0.7), 0.8)
                q.outline(sm, 0.4, ink)
            if rng.random() < 0.5:
                lit(t, wx0 + 1, wy0 + 1, wx1 - 1, wy1 - 1)
        elif kind < 0.7:
            sm = rect(q, q.mask(), wx0, wy0, wx1, wy1)
            q.fill(sm, sh)
            sl = q.mask()
            for yy in range(int(wy0 + 3), int(wy1), 3):
                q.stroke(sl, [(wx0, yy), (wx1, yy)], 0.35)
            q.fill(q.intersect(sl, sm), shade(sh, 0.7), 0.8)
        elif rng.random() < 0.6:
            lit(t, wx0 + 1, wy0 + 1, wx1 - 1, wy1 - 1)
        q.fill(rect(q, q.mask(), wx0 - 3, wy1, wx1 + 3, wy1 + 3), light(col, 1.25))
        if rng.random() < 0.15:  # un balconcino di ferro
            q.fill(rect(q, q.mask(), wx0 - 6, wy1 - 12, wx1 + 6, wy1 + 2), (40, 40, 44), 0.6)
    # il cornicione con le mensole e il tetto
    corn = rect(q, q.mask(), x - 4, top - 10, x + w + 4, top + 2)
    paint(q, corn, light(col, 1.15), ink=ink, shadow=0, grain=0.1, seed=int(x), rim=False, ow=0.6)
    for cx in range(int(x), int(x + w), 12):
        q.fill(rect(q, q.mask(), cx, top + 2, cx + 4, top + 7), shade(col, 0.6))
    rr = q.poly(q.mask(), [(x - 8, top - 10), (x + w + 8, top - 10), (x + w - 4, top - 34), (x + 4, top - 34)])
    roof = rng.choice([(160, 78, 54), (172, 90, 60), (150, 72, 52)]) + (255,)
    paint(q, rr, roof, ink=ink, shadow=8, grain=0.25, seed=int(x) + 9, ow=0.7)
    rl = q.mask()
    for xx in range(int(x - 4), int(x + w + 4), 7):
        q.stroke(rl, [(xx, top - 33), (xx, top - 11)], 0.6)
    q.fill(q.intersect(rl, rr), shade(roof, 0.8), 0.6)
    for _ in range(rng.randint(1, 3)):
        chx = x + rng.uniform(0.1, 0.85) * w
        ch = rect(q, q.mask(), chx, top - 62, chx + 12, top - 26)
        rect(q, ch, chx - 3, top - 68, chx + 15, top - 61)
        paint(q, ch, (140, 74, 56, 255), ink=ink, shadow=3, grain=0.1, seed=int(chx), ow=0.6)
    q.outline(m, 1.0, ink)
    stamp(t, q)
    return top


def lamp_far(t, x):
    """Il lampione dello strato vicino (la luce la disegna il gioco: life.daycycle.lamps, 101 px sopra il piede)."""
    foot = LAMP_FOOT
    q = patch(t, x - 14, foot - 120, x + 14, foot + 2)
    m = q.mask()
    q.poly(m, [(x - 4, foot), (x + 4, foot), (x + 2.6, foot - 8), (x - 2.6, foot - 8)])
    rect(q, m, x - 1.4, foot - 96, x + 1.4, foot - 8)
    q.poly(m, [(x - 6, foot - 96), (x + 6, foot - 96), (x + 5, foot - 107), (x - 5, foot - 107)])  # la lanterna, a 101
    q.poly(m, [(x - 7, foot - 107), (x + 7, foot - 107), (x, foot - 113)])
    paint(q, m, (54, 60, 56, 255), shadow=1.5, grain=0, seed=x, ow=0.6)
    q.fill(rect(q, q.mask(), x - 3.6, foot - 105, x + 3.6, foot - 97), (150, 140, 110))
    stamp(t, q)
    if t.lights is not None:
        t.lights.rect(x - 3.4, foot - 104.6, x + 3.4, foot - 97.4, fill=LIT_CORE)


def city_near(t):
    """Lo strato vicino: i palazzi coi portici attorno alla piazza (via Rizzoli e Strada Maggiore), la Mercanzia al
    centro, il marciapiede sotto i portici, e il selciato della piazza che scende fino al fondo dello strato."""
    x0, x1 = t.ox, t.ox + t.w
    rng = rand(401)
    bottom = t.oy + t.h
    # il selciato: lastre di arenaria a file, più grandi verso il basso, con i giunti che fuggono verso il centro
    q = patch(t, x0, NEAR_BASE - 2, x1, bottom)
    ground = q.mask(255)
    q.fill(ground, (112, 98, 88))
    joints = q.mask()
    y = NEAR_BASE + 70
    gap = 14
    while y < bottom:
        q.stroke(joints, [(x0, y), (x1, y)], 0.8)
        y += gap
        gap *= 1.12
    vp = (CENTER[0], NEAR_BASE - 300)
    for xx in range(int(x0) - 2000, int(x1) + 2000, 60):
        a = (vp[0] + (xx - vp[0]) * (370 / (bottom - vp[1])), NEAR_BASE + 70)
        q.stroke(joints, [a, (xx, bottom)], 0.7)
    q.fill(q.intersect(joints, q.poly(q.mask(), [(x0, NEAR_BASE + 70), (x1, NEAR_BASE + 70), (x1, bottom), (x0, bottom)])), (84, 72, 66), 0.8)
    q.fill(q.grain(ground, 0.5, 7, 3), (90, 78, 70), 0.3)
    # il marciapiede sotto i portici, più chiaro, con il cordolo
    side = rect(q, q.mask(), x0, NEAR_BASE - 2, x1, ROAD_Y - 16)
    q.fill(side, (140, 124, 110))
    q.fill(rect(q, q.mask(), x0, ROAD_Y - 18, x1, ROAD_Y - 14), (176, 160, 140))
    # la sera scurisce la piazza lontana verso il fondo (sta sotto il palco)
    ramp = Image.linear_gradient("L").resize(q.size)
    q.fill(ramp, (40, 30, 34), 0.5)
    stamp(t, q)
    # i palazzi, da sinistra a destra, con la Mercanzia al centro
    x = x0 - 30
    while x < 960:
        w = rng.uniform(190, 290)
        if x + w > 960:
            w = max(120, 960 - x)
        palazzo(t, x, w, NEAR_BASE, rng, floors=rng.choice((2, 2, 3, 3)))
        x += w
    mercanzia(t, 1080, NEAR_BASE)
    x = 1200
    while x < x1 + 30:
        w = rng.uniform(190, 290)
        palazzo(t, x, w, NEAR_BASE, rng, floors=rng.choice((2, 2, 3, 3)))
        x += w
    for lx in LAMPS_NEAR:
        lamp_far(t, lx)


def layers():
    for (name, p, LW, LH), draw in zip(LAYERS, (sky_far, city_mid, city_near)):
        layer(name, p, LW, LH, draw)


# ======================================================================================================
# Lo sfondo vivo: i fogli di vita.py (gli stessi di Padova), con il bus arancio di Bologna
# ======================================================================================================
def life_sheets():
    argv = sys.argv
    sys.argv = [argv[0], OUT]  # vita.py prende la cartella dal primo argomento
    try:
        import vita
    finally:
        sys.argv = argv
    vita.OUT = OUT
    sheet([vita.cloud(s) for s in (2, 4, 6, 8)], OUT, "nuvole.png", colors=None)
    sheet(vita.gull_frames(), OUT, "gabbiano.png")
    sheet(vita.swallow_frames(), OUT, "rondine.png")
    sheet(vita.bat_frames(), OUT, "pipistrello.png")
    sheet(vita.pigeon_frames(), OUT, "piccione.png")
    vita.walkers_sheet()
    vita.umbrellas_sheet()
    cars = [vita.car(64, 26, c, p, rack=r) for c, p, r in (
        ((206, 196, 168), "500", False), ((150, 154, 156), "squadrata", False), ((112, 124, 140), "berlina", False),
        ((150, 96, 80), "familiare", False), ((96, 98, 104), "berlina", True))]
    sheet(cars, OUT, "auto.png")
    sheet([vita.car(82, 36, (196, 192, 182), "squadrata")], OUT, "furgone.png")
    sheet(vita.vespa_frames(), OUT, "vespa.png")
    sheet(vita.bike_frames(), OUT, "bici.png")
    sheet([bus_orange(vita)], OUT, "bus.png")


def bus_orange(vita):
    """L'autobus arancio di Bologna, come quelli di una volta, senza scritte né stemmi: lungo, i finestrini, le porte
    a soffietto, il tetto chiaro e la fascia scura. Arancio spento: sta in fondo alla strada, dietro al palco."""
    L, H = 170, 44
    q = Quadro(L + 6, H + 6)
    x0, x1, base = 3, 3 + L, H + 4
    col, band = (196, 116, 64), (120, 70, 48)
    m = q.smooth(q.poly(q.mask(), [(x0, base - 6), (x0, base - H + 4), (x0 + 3, base - H), (x1 - 6, base - H), (x1, base - H + 6), (x1, base - 6)]), 0.6)
    q.fill(m, col)
    q.fill(q.intersect(q.poly(q.mask(), [(x0, base - H), (x1, base - H), (x1, base - H + 5), (x0, base - H + 5)]), m), (214, 200, 180))
    q.fill(q.intersect(q.poly(q.mask(), [(x0, base - 16), (x1, base - 16), (x1, base - 10), (x0, base - 10)]), m), band)
    q.fill(q.inner_shadow(m, 0, -10, 4), (140, 80, 50), 0.8)
    for k in range(7):
        wx = x0 + 6 + k * 22
        wm = q.smooth(q.poly(q.mask(), [(wx, base - 36), (wx + 18, base - 36), (wx + 18, base - 22), (wx, base - 22)]), 0.4)
        q.fill(wm, vita.GLASS)
        q.fill(q.intersect(q.poly(q.mask(), [(wx + 3, base - 22), (wx + 9, base - 36), (wx + 12, base - 36), (wx + 6, base - 22)]), wm), vita.GLASS_L, 0.5)
        if k % 2:
            q.fill(q.ellipse(q.mask(), wx + 7, base - 31, wx + 12, base - 25), (100, 84, 74), 0.8)
    for dx in (x0 + 50, x1 - 30):
        vita._part(q, [(dx, base - 38), (dx + 12, base - 38), (dx + 12, base - 7), (dx, base - 7)], vita.GLASS, ink=0.4)
        q.line([(dx + 6, base - 38), (dx + 6, base - 7)], 0.4, (40, 40, 44))
    q.fill(q.poly(q.mask(), [(x1 - 4, base - 38), (x1, base - 34), (x1, base - 20), (x1 - 4, base - 20)]), vita.GLASS)
    q.fill(q.ellipse(q.mask(), x1 - 3, base - 13, x1, base - 10), (236, 226, 190))
    q.outline(m, 0.7, vita.INK)
    for wx in (x0 + 28, x1 - 34):
        vita.wheel(q, wx, base - 5, 6)
    return q.result()


# ======================================================================================================
# Le vedute: l'arena composta come la disegna il gioco (world_view.gd), per l'anteprima e per giudicare i disegni
# ======================================================================================================
SKY_KEYS = [  # come stage_sky.gd: [fase, cielo in alto, all'orizzonte, luce sulle cose]
    (0.0, (92, 140, 196), (190, 212, 226), (1, 1, 1)),
    (0.15, (98, 138, 190), (218, 208, 190), (1, 0.96, 0.9)),
    (0.25, (84, 84, 140), (248, 148, 88), (1, 0.78, 0.6)),
    (0.31, (40, 42, 92), (160, 82, 108), (0.66, 0.56, 0.72)),
    (0.4, (12, 16, 40), (34, 42, 76), (0.34, 0.38, 0.58)),
    (0.6, (12, 16, 40), (34, 42, 76), (0.34, 0.38, 0.58)),
    (1.0, (92, 140, 196), (190, 212, 226), (1, 1, 1)),
]


def sky_at(phase):
    for a, b in zip(SKY_KEYS, SKY_KEYS[1:]):
        if a[0] <= phase <= b[0]:
            k = (phase - a[0]) / (b[0] - a[0])
            k = k * k * (3 - 2 * k)
            return [tuple(a[i][j] + (b[i][j] - a[i][j]) * k for j in range(3)) for i in (1, 2, 3)]
    return [SKY_KEYS[0][1], SKY_KEYS[0][2], SKY_KEYS[0][3]]


def darkness(phase):
    c = 0.5 - 0.5 * math.cos(phase * math.tau)
    return min(1.0, max(0.0, (c - 0.25) / 0.5))


def load_stage():
    code = "import { STAGES } from './src/shared/stages.ts'; console.log(JSON.stringify(STAGES.bologna))"
    out = subprocess.run(["npx", "tsx", "-e", code], cwd=ROOT, capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


def piece_on(p, t):
    on = p.get("on")
    return on is None or any(a <= t < b for a, b in on)


class Veduta:
    """Un fotogramma del gioco fatto con PIL: cielo vivo, strati con la parallasse, luci della sera, decorazioni,
    pezzi del palco con i materiali. Semplificato (niente sfondo vivo animato), ma con le stesse posizioni."""

    def __init__(self, stage):
        self.stage = stage
        self.art = stage["art"]
        self.cache = {}

    def img(self, name):
        if name not in self.cache:
            self.cache[name] = Image.open(os.path.join(OUT, name)).convert("RGBA")
        return self.cache[name]

    def render(self, view_center, zoom, t_ms, size=(1280, 720), extra_back=()):
        W, H = size
        vw, vh = W / zoom, H / zoom
        vx0, vy0 = view_center[0] - vw / 2, view_center[1] - vh / 2
        k = zoom
        life = self.art.get("life", {})
        dc = life.get("daycycle", {})
        phase = (t_ms / dc.get("cycleMs", 1e12) + dc.get("startAt", 0)) % 1.0
        top, hor, amb = sky_at(phase)
        night = min(1.0, max(0.0, (darkness(phase) - 0.2) / 0.3))
        out = Image.new("RGBA", size)
        grad = Image.linear_gradient("L").resize(size)
        out = Image.composite(Image.new("RGBA", size, tuple(int(c) for c in hor) + (255,)), Image.new("RGBA", size, tuple(int(c) for c in top) + (255,)), grad)
        ambc = tuple(int(255 * c) for c in amb)
        stage_l = tuple(int(255 * (1 + (c - 1) * 0.4)) for c in amb)
        scale = self.art.get("scale", 1)
        vert = self.art.get("verticalParallax", 1)

        def tint(im, col):
            r, g, b, a = im.split()
            rgb = ImageChops.multiply(Image.merge("RGB", (r, g, b)), Image.new("RGB", im.size, col[:3]))
            return Image.merge("RGBA", (*rgb.split(), a))

        def place(im, wx, wy, ww, wh, col=None, alpha=1.0):
            dx0, dy0 = (wx - vx0) * k, (wy - vy0) * k
            dw, dh = ww * k, wh * k
            if dw < 1 or dh < 1 or dx0 > W or dy0 > H or dx0 + dw < 0 or dy0 + dh < 0:
                return
            # si taglia prima la parte che si vede, poi si ridimensiona
            sx = im.width / dw
            sy = im.height / dh
            cx0, cy0 = max(0, -dx0), max(0, -dy0)
            cx1, cy1 = min(dw, W - dx0), min(dh, H - dy0)
            crop = im.crop((int(cx0 * sx), int(cy0 * sy), int(math.ceil(cx1 * sx)), int(math.ceil(cy1 * sy))))
            crop = crop.resize((max(1, int(round(cx1 - cx0))), max(1, int(round(cy1 - cy0)))), Image.LANCZOS)
            if col:
                crop = tint(crop, col)
            if alpha < 1:
                a = crop.getchannel("A").point(lambda v: int(v * alpha))
                crop.putalpha(a)
            out.alpha_composite(crop, (int(round(dx0 + cx0)), int(round(dy0 + cy0))))

        for lay in self.art["layers"]:
            im = self.img(lay["file"])
            p = lay["parallax"]
            lw, lh = im.width * scale, im.height * scale
            cx = 1100 + (view_center[0] - 1100) * (1 - p)
            cy = 1200 + (view_center[1] - 1200) * (1 - p) * vert
            place(im, cx - lw / 2, cy - lh / 2, lw, lh, ambc)
            lights = [ll for ll in dc.get("lightLayers", []) if ll["parallax"] == p]
            if lights and night > 0:
                place(self.img(lights[0]["file"]), cx - lw / 2, cy - lh / 2, lw, lh, None, night)
            if night > 0:
                for lamp in dc.get("lamps", []):
                    if lamp["parallax"] != p:
                        continue
                    lx = lamp["x"] + (view_center[0] - 1100) * (1 - p)
                    ly = lamp["y"] + (view_center[1] - 1200) * (1 - p) * vert
                    for j in range(3):
                        ov = Image.new("RGBA", size)
                        r = (5 + j * 7) * k
                        ImageDraw.Draw(ov).ellipse([(lx - vx0) * k - r, (ly - vy0) * k - r, (lx - vx0) * k + r, (ly - vy0) * k + r], fill=(255, 214, 140, int(255 * (0.32 - j * 0.09) * night)))
                        out.alpha_composite(ov)
        for pr in list(extra_back) + list(self.art.get("props", [])):  # extra_back (la Garisenda) dietro a tutto
            if pr.get("front"):
                continue
            im = self.img(pr["file"]) if isinstance(pr["file"], str) else pr["file"]
            s = pr.get("scale", scale)
            if pr.get("flip"):
                im = im.transpose(Image.FLIP_LEFT_RIGHT)
            place(im, pr["x"] - im.width * s / 2, pr["y"] - im.height * s, im.width * s, im.height * s, ambc, pr.get("opacity", 1))
        if night > 0:
            for lp in dc.get("lightProps", []):
                im = self.img(lp["file"])
                s = lp.get("scale", scale)
                place(im, lp["x"] - im.width * s / 2, lp["y"] - im.height * s, im.width * s, im.height * s, None, night)
        skins = self.art.get("skins", {})

        def skin_for(kind, i):
            name = self.art.get("solidSkin" if kind == "solids" else "platformSkin")
            pcs = self.art.get("pieces", {}).get(kind, [])
            if i < len(pcs):
                name = pcs[i]
            return skins.get(name) if name else None

        def tiled(name, x, y, w, h):
            im = self.img(name)
            tw, th = im.width * scale, im.height * scale
            yy = y
            while yy < y + h - 0.01:
                hh = min(th, y + h - yy)
                xx = x
                while xx < x + w - 0.01:
                    ww = min(tw, x + w - xx)
                    place(im.crop((0, 0, max(1, int(ww / scale)), max(1, int(hh / scale)))), xx, yy, ww, hh, stage_l)
                    xx += tw
                yy += th

        def strip(name, p, height, cols=6.0):
            im = self.img(name)
            src_w = im.width
            x = p["x"]
            end = p["x"] + p["width"]
            curved = p.get("y2") is not None
            cw = cols if curved else p["width"]
            while x < end - 0.01:
                w = min(cw, end - x)
                u = ((x - p["x"]) / scale) % src_w
                yy = surface(p, x + w / 2)
                left, dx = w, x
                while left > 0.01:
                    piece = min(left, (src_w - u) * scale)
                    place(im.crop((int(u), 0, max(int(u) + 1, int(u + piece / scale)), im.height)), dx, yy, piece, height, stage_l)
                    dx += piece
                    left -= piece
                    u = 0
                x += w

        def surface(p, x):
            if p.get("y2") is None:
                return p["y"]
            return p["y"] + (p["y2"] - p["y"]) * (x - p["x"]) / p["width"]

        for i, s in enumerate(self.stage["solids"]):
            if not piece_on(s, t_ms):
                continue
            sk = skin_for("solids", i)
            tiled(sk["file"], s["x"], s["y"], s["width"], s["height"])
            if sk.get("edge"):
                e = self.img(sk["edge"])
                tiled(sk["edge"], s["x"], s["y"], s["width"], min(e.height * scale, s["height"]))
        for i, p in enumerate(self.stage["platforms"]):
            if not piece_on(p, t_ms):
                continue
            sk = skin_for("platforms", i)
            depth = sk.get("depth", 12)
            if p.get("y2") is not None:
                rise = abs(p["y2"] - p["y"])
                n = max(2, int(rise / 14))
                step = p["width"] / n
                bottom = max(p["y"], p["y2"])
                for j in range(n):
                    x0 = p["x"] + step * j
                    tp = max(surface(p, x0), surface(p, x0 + step))
                    h = min(rise / n + 6, bottom - tp)
                    if h > 0:
                        tiled(sk["file"], x0, tp, step + 0.5, h)
                        if sk.get("edge"):
                            tiled(sk["edge"], x0, tp, step + 0.5, min(self.img(sk["edge"]).height * scale, h))
                continue
            strip(sk["file"], p, depth)
            if sk.get("edge"):
                strip(sk["edge"], p, min(self.img(sk["edge"]).height * scale, depth))
        d = ImageDraw.Draw(out)
        for m in self.stage.get("movers", []):
            if not piece_on(m, t_ms):
                continue
            pt = m["path"][0]
            x0, y0 = (pt["x"] - vx0) * k, (pt["y"] - vy0) * k
            d.rectangle([x0, y0, x0 + m["width"] * k, y0 + 10 * k], fill=(120, 96, 70), outline=(240, 217, 181))
        return out


def garisenda_preview():
    """La Garisenda solo per l'anteprima della lobby (nel gioco la disegna il codice, che la fa crollare): il fusto
    di mattoni storto verso sinistra, la selenite alla base, la cima mozzata. Coordinate di mondo."""
    X0, Y0, X1, Y1 = 380, 1120, 1020, 1945
    q = Quadro(X1 - X0, Y1 - Y0, origin=(X0, Y0), ss=1)
    m = q.poly(q.mask(), [(570, 1942), (830, 1942), (812, 1162), (552, 1162)])  # come art.collapse: piede destro a x 830, alta 780, larga 260
    paint(q, m, (146, 74, 56, 255), shadow=30, grain=0.3, seed=5, ow=1.2)
    courses(q, m, 1942, 1150, 5.2, (78, 40, 34), 0.3, joints=14, seed=5)
    sel = q.intersect(rect(q, q.mask(), X0, 1868, X1, 1942), m)
    paint(q, sel, SELENITE, shadow=12, grain=0.3, seed=6, ow=0.8)
    holes = q.mask()
    for yy in range(1880, 1180, -64):  # le buche pontaie, storte come la torre
        u = (1942 - yy) / 790
        for xx in range(0, 5):
            x = 590 - u * 18 + xx * 50
            rect(q, holes, x, yy, x + 5, yy + 5)
    q.fill(q.intersect(holes, m), (40, 22, 20))
    return q.result()


def views(folder):
    """Le vedute di prova: la piazza di giorno, le torri al tramonto, la zuffa sulla cima di notte, e una in grigio."""
    os.makedirs(folder, exist_ok=True)
    st = load_stage()
    v = Veduta(st)
    shots = [
        ("piazza", (1100, 1880), 0.6, 20000),
        ("piazza-vicina", (700, 1880), 1.0, 30000),
        ("torri", (1100, 1400), 0.5, 100000),
        ("crollo", (1100, 1500), 0.5, 156000),
        ("zuffa", (1100, 880), 0.5, 200000),
        ("zuffa-vicina", (1500, 950), 0.9, 260000),
    ]
    for name, c, z, t in shots:
        im = v.render(c, z, t)
        im.convert("RGB").save(os.path.join(folder, f"{name}.png"))
        im.convert("L").save(os.path.join(folder, f"{name}-grigio.png"))
        print("veduta", name)


def preview():
    """L'anteprima della lobby (16:9): le Due Torri al tramonto con i pezzi della seconda fase, già col palco."""
    st = load_stage()
    v = Veduta(st)
    gar = {"file": garisenda_preview(), "x": 700, "y": 1945, "scale": 0.5}
    im = v.render((1100, 1440), 0.56, 120000, size=(1280, 720), extra_back=[gar])
    im = im.convert("RGB").resize((960, 540), Image.LANCZOS)
    im.save(os.path.join(OUT, "anteprima.png"), optimize=True)
    print("scritto anteprima.png", im.size)


if __name__ == "__main__":
    args = sys.argv[1:]
    if args and args[0] == "viste":
        views(args[1] if len(args) > 1 else os.path.join(ROOT, "viste-bologna"))
        sys.exit(0)
    parts = set(args) or {"materiali", "decorazioni", "strati", "vita", "anteprima"}
    if "materiali" in parts:
        skins()
    if "decorazioni" in parts:
        props()
    if "strati" in parts:
        layers()
    if "vita" in parts:
        life_sheets()
    if "anteprima" in parts:
        preview()
