"""I disegni dell'arena Padova (#230, #280, #288): l'isola sospesa con la fontana, le statue, il palazzo e lo sfondo.

Stile del gioco (docs/stile-grafico.md): contorno a inchiostro, ombre piatte a 2 toni, fondale più spento
dei lottatori, bordo calpestabile chiaro, niente colori dei giocatori saturi vicino al piano di gioco.
Tutto a 2x: chi disegna in Krita può sostituire ogni PNG tenendo lo stesso nome e la stessa misura.
Le foto di Prato della Valle servono solo da riferimento e non entrano nella repo.

Uso: python3 tools/arene/padova.py  (scrive in public/assets/stages/padova/)
"""

import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(__file__))
from disegno import INK, Tela, light, mix, rand, shade  # noqa: E402

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "public", "assets", "stages", "padova")
os.makedirs(OUT, exist_ok=True)

MARBLE = (214, 208, 194, 255)  # statue e ringhiere: marmo, un po' spento
MARBLE_SHADE = (172, 164, 148, 255)
STONE = (111, 106, 96, 255)  # lastricato delle piazze
STONE_SHADE = (95, 90, 81, 255)
STONE_LIGHT = (125, 119, 108, 255)
EDGE = (232, 226, 210, 255)  # bordo calpestabile, chiaro
DECK = (185, 178, 163, 255)  # ponte
DECK_SHADE = (155, 148, 133, 255)
STAIR = (128, 122, 111, 255)
STAIR_SHADE = (104, 99, 90, 255)
TREAD = (207, 200, 186, 255)
SKY = (43, 52, 70, 255)  # = colors.sky di Padova


def save(img, name):
    img.save(os.path.join(OUT, name), optimize=True)
    print("scritto", name, img.size)


# --- il palco (#280 passo 1): tutto a 2x con disegno.Tela, in pixel di mondo ---
TRACHITE = (122, 116, 104, 255)  # i blocchi delle rive: trachite euganea, grigia e calda
MALTA = (78, 73, 66, 255)  # i giunti
MUSCHIO = (92, 104, 76, 255)  # verde spento, lontano dal verde dei giocatori


def paving():
    """Il lastricato (materiale di riserva delle piazze): lastre di trachite a file sfalsate."""
    t = Tela(96, 96, bg=STONE, wrap=True, wrap_y=True)
    rng = rand(7)
    for r in range(4):
        y = r * 24
        off = 0 if r % 2 == 0 else 24
        for x in range(off - 48, 96, 48):
            tone = mix(STONE, STONE_LIGHT, rng.random() * 0.8)
            t.block(x, y, x + 48, y + 24, tone, side=2, bottom=4, width=1.0, chip=("br", 4) if rng.random() < 0.3 else None)
    t.save(OUT, "pietra.png")


def quay_wall():
    """Il fianco dell'isola, sotto il bordo dove si cammina (#378, chiesto da Riccardo: più bello e dettagliato).
    Dipinto con pittura.py: sotto la copertina una cornice modanata che sporge e fa ombra, poi due corsi di grandi
    blocchi di trachite bugnati, con lo smusso chiaro in alto a sinistra e scuro in basso a destra, la superficie
    butterata e venata, i segni dello scalpello, spigoli sbreccati, crepe, colature scure e muschio sui giunti,
    un anello di ferro arrugginito per legare le barche, e in basso l'umido del canale. Piastrella 240×70 di mondo
    (alta quanto la piazza) che si ripete in orizzontale senza giunta."""
    from pittura import Quadro
    W, H = 240, 70
    q = Quadro(W, H)
    rng = rand(9)

    def wrap(fn):  # ogni cosa si disegna anche a ±W: la piastrella si ripete senza giunta
        for dx in (-W, 0, W):
            fn(dx)

    q.fill(q.mask(255), MALTA)
    # la cornice modanata sotto la copertina: un toro chiaro, un listello e l'ombra che getta sul muro
    band = q.mask()
    q.poly(band, [(0, 9), (W, 9), (W, 17), (0, 17)])
    q.fill(band, (176, 170, 156))
    q.fill(q.inner_shadow(band, 0, -4, 2), (128, 122, 110), 0.9)
    q.fill(q.rim(band, 0, -1, 0.7), (214, 208, 194), 0.8)
    q.line([(0, 13.5), (W, 13.5)], 0.5, (120, 114, 104), 0.8)
    for x in range(0, W, 24):  # i dentelli sotto la cornice
        wrap(lambda dx, x=x: q.line([(x + dx + 6, 17.5), (x + dx + 14, 17.5)], 1.6, (104, 98, 88), 0.9))
    shadow = q.mask()
    q.poly(shadow, [(0, 17), (W, 17), (W, 22), (0, 22)])
    rows = [(19, 44), (44, 70)]
    blocks = []
    for r, (y0, y1) in enumerate(rows):
        x = rng.uniform(0, 40) if r else rng.uniform(40, 80)
        start = x
        while x < start + W:
            bw = rng.choice([52, 60, 68, 76, 84])
            if start + W - (x + bw) < 40:
                bw = start + W - x
            blocks.append((x, y0, x + bw, y1, r))
            x += bw
    for x0, y0, x1, y1, r in blocks:
        tone = mix(TRACHITE, light(TRACHITE, 1.14), rng.random()) if rng.random() < 0.5 else mix(TRACHITE, shade(TRACHITE, 0.9), rng.random())
        m = q.mask()
        bev = 2.6
        chip = rng.random() < 0.35

        def draw(dx, m=m, x0=x0, y0=y0, x1=x1, y1=y1, chip=chip):
            pts = [(x0 + dx + 1.2, y0 + 1.2), (x1 + dx - 1.2, y0 + 1.2), (x1 + dx - 1.2, y1 - 1.2), (x0 + dx + 1.2, y1 - 1.2)]
            if chip:  # uno spigolo sbreccato
                pts[2] = (x1 + dx - 6, y1 - 1.2)
                pts.insert(3, (x1 + dx - 1.2, y1 - 6))
                pts[2], pts[3] = pts[3], pts[2]
            q.poly(m, pts)
        wrap(draw)
        m = q.smooth(m, 0.6)
        q.fill(m, tone[:3])
        q.fill(q.grain(m, 0.32, rng.randint(0, 999), 0.9), shade(tone, 0.82)[:3])
        q.fill(q.rim(m, -bev, -bev, 1.2), light(tone, 1.22)[:3], 0.85)  # lo smusso in luce
        q.fill(q.inner_shadow(m, -bev, -bev, 1.2), shade(tone, 0.68)[:3], 0.9)  # lo smusso in ombra
        # la bugna: il centro del blocco un po' rialzato, più chiaro
        boss = q.mask()
        wrap(lambda dx: q.poly(boss, [(x0 + dx + 7, y0 + 6), (x1 + dx - 7, y0 + 6), (x1 + dx - 7, y1 - 6), (x0 + dx + 7, y1 - 6)]))
        q.fill(q.soften(boss, 3), light(tone, 1.06)[:3], 0.5)
        for _ in range(rng.randint(1, 3)):  # segni dello scalpello
            sx, sy = rng.uniform(x0 + 8, x1 - 20), rng.uniform(y0 + 6, y1 - 6)
            ln = rng.uniform(6, 14)
            wrap(lambda dx, sx=sx, sy=sy, ln=ln: q.line([(sx + dx, sy), (sx + dx + ln, sy + rng.uniform(-0.6, 0.6))], 0.6, shade(tone, 0.75)[:3], 0.7))
        pits = q.mask()  # la trachite butterata
        for _ in range(int((x1 - x0) * 0.5)):
            px, py, pr = rng.uniform(x0 + 3, x1 - 3), rng.uniform(y0 + 3, y1 - 3), rng.uniform(0.3, 0.8)
            wrap(lambda dx, px=px, py=py, pr=pr: q.ellipse(pits, px + dx - pr, py - pr, px + dx + pr, py + pr))
        q.fill(q.intersect(pits, m), shade(tone, 0.6)[:3], 0.6)
        if rng.random() < 0.25:  # una crepa
            cx_, cy_ = rng.uniform(x0 + 10, x1 - 10), y0 + 2
            pts = [(cx_, cy_)]
            for _ in range(5):
                cx_ += rng.uniform(-3, 3)
                cy_ += (y1 - y0 - 4) / 5
                pts.append((cx_, cy_))
            wrap(lambda dx, pts=pts: q.line([(px + dx, py) for px, py in pts], 0.6, (60, 56, 50), 0.8))
        if rng.random() < 0.55:  # colatura scura dal giunto di sopra
            cx_ = rng.uniform(x0 + 6, x1 - 10)
            long = rng.uniform(10, y1 - y0)
            drip = q.mask()
            wrap(lambda dx, cx_=cx_, long=long: q.poly(drip, [(cx_ + dx, y0), (cx_ + dx + 6, y0), (cx_ + dx + 4, y0 + long * 0.8), (cx_ + dx + 2.5, y0 + long), (cx_ + dx + 1, y0 + long * 0.7)]))
            q.fill(q.intersect(q.soften(drip, 1), m), (58, 60, 52), 0.35)
    # muschio sui giunti orizzontali, a ciuffi
    moss = q.mask()
    for _ in range(26):
        mx, my = rng.uniform(0, W), rng.choice([19, 44]) + rng.uniform(-0.5, 1.5)
        for k in range(rng.randint(2, 5)):
            rr = rng.uniform(1.2, 2.6)
            wrap(lambda dx, mx=mx, my=my, k=k, rr=rr: q.ellipse(moss, mx + dx + k * 2.6 - rr, my - rr * 0.8, mx + dx + k * 2.6 + rr, my + rr * 0.8))
    moss = q.smooth(moss, 0.5)
    q.fill(moss, MUSCHIO[:3], 0.95)
    q.fill(q.inner_shadow(moss, -1, -1, 0.6), shade(MUSCHIO, 0.75)[:3], 0.8)
    q.fill(q.rim(moss, -0.6, -0.8, 0.4), (128, 144, 96), 0.7)
    # l'ombra che la cornice getta sul primo corso
    q.fill(q.soften(shadow, 2), (30, 28, 26), 0.45)
    # l'anello di ferro per le barche, arrugginito, con la colatura di ruggine
    rx_, ry_ = 172, 33
    ring = q.mask()
    q.ellipse(ring, rx_ - 4, ry_ - 3, rx_ + 4, ry_ + 3)
    q.fill(ring, (70, 60, 52))
    rust = q.mask()
    q.poly(rust, [(rx_ - 2, ry_ + 6), (rx_ + 2, ry_ + 6), (rx_ + 1.5, ry_ + 20), (rx_ - 0.5, ry_ + 24)])
    q.fill(q.soften(rust, 1), (140, 76, 44), 0.5)
    loop = q.mask()
    q.stroke(loop, [(rx_ + 5.5 * math.cos(u), ry_ + 3 + 6.5 * math.sin(u)) for u in [j * math.tau / 24 for j in range(25)]], 1.4)
    q.fill(loop, (96, 64, 48))
    q.fill(q.rim(loop, -0.5, -0.5, 0.3), (170, 110, 70), 0.7)
    # in basso l'umido del canale: la pietra più scura e una riga di licheni chiari
    damp = q.mask()
    q.poly(damp, [(0, 58), (W, 58), (W, 70), (0, 70)])
    q.fill(q.soften(damp, 3), (40, 46, 38), 0.45)
    lich = q.mask()
    for _ in range(40):
        lx, ly, lr = rng.uniform(0, W), rng.uniform(57, 63), rng.uniform(0.5, 1.2)
        wrap(lambda dx, lx=lx, ly=ly, lr=lr: q.ellipse(lich, lx + dx - lr * 1.5, ly - lr, lx + dx + lr * 1.5, ly + lr))
    q.fill(lich, (176, 180, 150), 0.6)
    q.save(OUT, "riva.png")


FRONT_D = 56  # quanto l'isola sporge davanti alla linea dove si gioca, al centro (#378): la metà vicina dell'ovale


def front_edge_y(x):
    """Il bordo davanti dell'isola ovale (#378, chiesto da Riccardo): al centro sta FRONT_D pixel più giù della linea
    dove si gioca (y 520), e verso le punte risale fino a toccarla, come la metà vicina di un ovale visto dall'alto."""
    d = (x - 960) / 862
    return 520 + FRONT_D * math.sqrt(max(0.0, 1 - d * d))


def paint_gravel(q, m, seed, y_far, y_near, density=1.0):
    """Il terriccio bianco con il ghiaino dei viali del Prato (#378, chiesto da Riccardo), dipinto dentro la maschera m:
    il fondo chiaro battuto con le chiazze più scure e più chiare, i granelli fini e, sopra, i sassolini (più grandi
    vicino, y_near, e più piccoli lontano, y_far), ognuno con la luce in alto e l'ombrina sotto."""
    rng = random.Random(seed)
    q.fill(m, (216, 208, 188))
    q.fill(q.grain(m, 0.55, seed, 3.5), (194, 184, 162), 0.55)  # le chiazze dove la terra è più umida
    q.fill(q.grain(m, 0.8, seed + 1, 0.7), (236, 231, 216), 0.5)
    q.fill(q.grain(m, 0.8, seed + 2, 0.5), (172, 162, 142), 0.35)
    bb = m.getbbox()
    if not bb:
        return
    wx0, wy0 = bb[0] / q.k + q.ox, bb[1] / q.k + q.oy
    wx1, wy1 = bb[2] / q.k + q.ox, bb[3] / q.k + q.oy
    peb, sh, hi = q.mask(), q.mask(), q.mask()
    count = int((wx1 - wx0) * (wy1 - wy0) * 0.35 * density)
    for _ in range(count):
        x, y = rng.uniform(wx0, wx1), rng.uniform(wy0, wy1)
        px, py = q._p(x, y)
        if not (0 <= px < m.size[0] and 0 <= py < m.size[1]) or m.getpixel((int(px), int(py))) < 128:
            continue
        f = max(0.0, min(1.0, (y - y_far) / max(1e-6, y_near - y_far)))
        r = (0.3 + 0.55 * f) * rng.uniform(0.6, 1.3)
        q.ellipse(sh, x - r * 1.1, y - r * 0.2, x + r * 1.3, y + r * 0.8)
        q.ellipse(peb, x - r * 1.2, y - r * 0.7, x + r * 1.2, y + r * 0.6)
        q.ellipse(hi, x - r * 0.8, y - r * 0.6, x + r * 0.2, y - r * 0.1)
    q.fill(q.intersect(sh, m), (150, 140, 120), 0.6)
    peb = q.intersect(peb, m)
    q.fill(peb, (204, 196, 178))
    q.fill(q.intersect(q.grain(peb, 0.9, seed + 3, 0.4), peb), (178, 170, 152), 0.6)
    q.fill(q.intersect(hi, peb), (244, 240, 228), 0.85)


def paint_grass(q, m, seed, y_far, y_near, density=1.0):
    """Il prato rasato del Prato (#378, chiesto da Riccardo: un'erba più bella), dipinto dentro la maschera m: il verde
    di fondo, le strisce larghe del taglio, le chiazze più scure e più chiare a due scale, e sopra tanti fili d'erba con
    il piede scuro e la punta chiara (più lunghi vicino, y_near), qualche trifoglio e margheritina, e un filo d'ombra
    lungo i bordi; i fili sul bordo sbordano un poco sul viale, come l'erba vera."""
    rng = random.Random(seed)
    q.fill(m, (74, 100, 56))
    bb = m.getbbox()
    if not bb:
        return
    wx0, wy0 = bb[0] / q.k + q.ox, bb[1] / q.k + q.oy
    wx1, wy1 = bb[2] / q.k + q.ox, bb[3] / q.k + q.oy
    stripes = q.mask()
    k = int((wx0 - 960) // 52) - 2
    while 960 + k * 52 < wx1 + 60:
        if k % 2 == 0:
            xa = 960 + k * 52
            q.poly(stripes, [(xa, wy1 + 4), (xa + 26, wy1 + 4), (xa + 26 + (wy1 - wy0) * 0.35, wy0 - 4), (xa + (wy1 - wy0) * 0.35, wy0 - 4)])
        k += 1
    q.fill(q.intersect(q.soften(stripes, 2.5), m), (100, 128, 70), 0.6)
    q.fill(q.grain(m, 0.6, seed, 5.0), (56, 80, 42), 0.45)
    q.fill(q.grain(m, 0.65, seed + 1, 1.4), (116, 144, 80), 0.45)
    q.fill(q.grain(m, 0.7, seed + 2, 0.6), (60, 86, 44), 0.35)
    grow = m.filter(ImageFilter.MaxFilter(5))
    dark, light, flowers = q.mask(), q.mask(), q.mask()
    count = int((wx1 - wx0) * (wy1 - wy0) * 0.8 * density)
    for _ in range(count):
        x, y = rng.uniform(wx0, wx1), rng.uniform(wy0, wy1 + 2)
        px, py = q._p(x, y)
        if not (0 <= px < m.size[0] and 0 <= py < m.size[1]) or grow.getpixel((int(px), int(py))) < 128:
            continue
        f = max(0.0, min(1.0, (y - y_far) / max(1e-6, y_near - y_far)))
        hgt = (1.0 + 2.4 * f) * rng.uniform(0.7, 1.3)
        lean = rng.uniform(-0.5, 0.5) * hgt
        q.stroke(dark, [(x, y), (x + lean * 0.5, y - hgt * 0.55)], 0.32 + 0.25 * f)
        q.stroke(light, [(x + lean * 0.5, y - hgt * 0.55), (x + lean, y - hgt)], 0.26 + 0.2 * f)
        if rng.random() < 0.006:  # una margheritina o un trifoglio
            r = 0.5 + 0.6 * f
            q.ellipse(flowers, x - r, y - hgt - r * 0.7, x + r, y - hgt + r * 0.7)
    q.fill(q.intersect(dark, grow), (48, 70, 38), 0.8)
    q.fill(q.intersect(light, grow), (134, 164, 90), 0.8)
    q.fill(q.intersect(flowers, grow), (236, 234, 220), 0.85)
    q.fill(q.inner_shadow(m, 0, -2.5, 1.8), (40, 58, 32), 0.4)  # un filo d'ombra dove il prato è un po' più basso


def fianco(name):
    """La metà vicina dell'isola ovale (#378, chiesto da Riccardo: i giocatori combattono su una linea, ma l'isola deve
    sembrare ovale anche davanti). Davanti alla linea dove si gioca (y 520, la copertina la disegna il gioco) l'isola
    continua: una fascia di prato rasato a strisce, vista dall'alto, che si allarga al centro e si chiude verso le punte;
    sul bordo dell'ovale il cordolo bianco con i paracarri bassi; poi il muro a bugne che gira (i blocchi si stringono
    dove il muro curva e vanno in ombra verso le punte) e scende nell'acqua del canale, scuro d'umido e con le alghe.
    Prop dietro in x 960, y 660, a 2x: x 60..1860, y 516..660."""
    import numpy as np
    x0, y0, w, h = 60, 516, 1800, 144
    k = 2
    W, H = w * k, h * k
    cx, rx = 960, 862
    xs = x0 + (np.arange(W) + 0.5) / k
    d = np.clip((xs - cx) / rx, -1, 1)
    sfac = np.sqrt(1 - d * d)
    top = 520 + FRONT_D * sfac  # il bordo davanti, dove comincia il muro
    bottom = 660.0
    tile = np.asarray(Image.open(os.path.join(OUT, "riva.png")).convert("RGBA")).astype(np.float32)
    th, tw = tile.shape[0], tile.shape[1]
    arc = rx * np.arcsin(d)
    ys = y0 + (np.arange(H) + 0.5) / k
    Y = ys[:, None]
    inside = (Y >= top[None, :]) & (Y <= bottom) & (np.abs(xs - cx)[None, :] <= rx)
    v = np.mod((Y - top[None, :]) * k + 18, th)  # i blocchi a bugne, dalla cornice in giù
    u = np.mod((arc[None, :] - arc.min()) * k, tw)
    vi = np.clip(v.astype(int), 0, th - 1)
    ui = np.clip(np.broadcast_to(u, vi.shape).astype(int), 0, tw - 1)
    sample = tile[vi, ui]
    shade_k = (0.5 + 0.5 * sfac ** 0.6)[None, :, None]  # il muro gira: verso le punte va in ombra
    damp = np.clip((Y - 600) / 30, 0, 1)[..., None] * 0.45  # l'umido scuro che sale dall'acqua
    sample[..., :3] = sample[..., :3] * shade_k * (1 - damp) + np.array([40, 52, 40]) * damp
    out = np.zeros((H, W, 4), np.float32)
    out[inside] = sample[inside]
    wall = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")
    # la fascia di prato davanti, vista dall'alto, e il cordolo sul bordo dell'ovale
    t = Tela(w, h, origin=(x0, y0), ss=1)
    pts = [(cx - rx + 2 * rx * i / 120, front_edge_y(cx - rx + 2 * rx * i / 120)) for i in range(121)]
    # il prato davanti e il vialetto in terriccio bianco dal ponte sud alla striscia dove si gioca (#378)
    from pittura import Quadro
    q = Quadro(w, h, origin=(x0, y0), scale=2, ss=1)
    top_m = q.poly(q.mask(), [(cx - rx, 521)] + pts + [(cx + rx, 521)])
    ye = front_edge_y(cx) + 1
    path_m = q.intersect(q.poly(q.mask(), [(cx - 40, 519), (cx + 40, 519), (cx + 48, ye + 1), (cx - 48, ye + 1)]), top_m)
    paint_gravel(q, path_m, 3003, 521, ye)
    paint_grass(q, q.minus(top_m, path_m), 3004, 521, 520 + FRONT_D)
    t.img.alpha_composite(q.img)
    t.glaze([(cx - rx, 521), (cx + rx, 521), (cx + rx, 527), (cx - rx, 527)], (30, 28, 24, 60))  # l'ombra della copertina sul prato
    base = t.img
    base.alpha_composite(wall)
    t.img = base
    t.d = ImageDraw.Draw(t.img)
    t.line([(x, y + 1.5) for x, y in pts], fill=(222, 216, 202, 255), width=3.4)  # il cordolo bianco
    t.line([(x, y + 3.4) for x, y in pts], fill=(150, 144, 132, 255), width=0.8)
    t.line([(x, y - 0.2) for x, y in pts], fill=(90, 84, 76, 255), width=0.6)
    for i in range(1, 16):  # i paracarri bassi lungo il cordolo, più piccoli verso le punte (non davanti al vialetto)
        x = cx - rx + 2 * rx * i / 16
        if abs(x - cx) < 60:
            continue
        y = front_edge_y(x)
        sc = 0.5 + 0.5 * math.sqrt(max(0.0, 1 - ((x - cx) / rx) ** 2))
        bollard(t, x, y + 1, 16 * sc, stone=(214, 208, 194, 255), sh=(170, 164, 150, 255))
    t.save(OUT, name, colors=256)


def coping(name, w=96, h=8):
    """Il bordo dove si cammina (#378): la stessa ghiaia chiara battuta del piano, a filo, appena più chiara (stile,
    sezione 7: il bordo calpestabile è la parte più chiara), senza gradino; un filo di luce sul davanti."""
    t = Tela(w, h, wrap=True)
    rng = rand(7)
    t.rect(0, 0, w, h, fill=(230, 224, 208, 255))
    for k in range(220):
        x, y = rng.uniform(0, w), rng.uniform(0.3, h - 0.3)
        r = rng.uniform(0.18, 0.5)
        t.ellipse(x - r * 1.2, y - r * 0.7, x + r * 1.2, y + r * 0.7, fill=rng.choice([(206, 198, 178, 255), (244, 240, 228, 255), (190, 180, 160, 255)]))
    t.line([(0, h - 0.5), (w, h - 0.5)], fill=(246, 244, 236, 255), width=0.6)
    t.save(OUT, name)


def slab():
    """La lastra retta dalle statue: piano chiaro, listello modanato, fascia di marmo e l'ombra sotto."""
    W, H = 64, 12
    t = Tela(W, H, bg=MARBLE, wrap=True)
    t.rect(0, 0, W, 3, fill=EDGE)
    t.rect(0, 0, W, 0.7, fill=(248, 245, 236, 255))
    t.rect(0, 3, W, 5, fill=(226, 220, 206, 255))
    t.line([(0, 3), (W, 3)], fill=INK, width=0.9)
    t.line([(0, 5), (W, 5)], fill=(150, 142, 128, 255), width=0.8)
    t.rect(0, 8.5, W, H, fill=MARBLE_SHADE)
    t.line([(0, H - 0.6), (W, H - 0.6)], fill=INK, width=1.2)
    t.save(OUT, "lastra.png")


def statue_painted(name, total_h, slab_w, kind):
    """Le statue del Prato che reggono le lastre (#378, dalle foto di Riccardo): marmo d'Istria dipinto in volume, su un
    piedistallo tondo come quelli veri (zoccolo, tori, fusto con la targa e il festone, cornice), e la figura in piedi
    con la veste a pieghe, le braccia alzate che reggono la lastra, la testa scolpita. La luce viene da sinistra in
    alto; il marmo ha le macchie grigie del tempo. kind: "filosofo" (barba, mantello), "giovane" (alloro, toga), "dama"
    (velo, veste lunga). Stessa misura di prima: i piedi in fondo all'immagine, le mani in cima, dove sta la lastra."""
    from pittura import Quadro, bezier
    w = max(slab_w, 76)
    q = Quadro(w, total_h, origin=(-w / 2, -total_h))
    rng = random.Random(len(name) * 31 + len(kind))
    M, M_SH, M_DK, M_HI = (228, 223, 210), (160, 156, 148), (116, 112, 106), (248, 245, 236)
    ink = (66, 62, 58)
    stain = (120, 118, 108)

    def marble(m, light_dx=-1.0, depth=None, seed=0, cyl=False):
        """Il marmo in volume: il tono, l'ombra dalla parte opposta alla luce, la luce sul bordo e le macchie."""
        size = depth if depth is not None else 4.0
        q.fill(m, M)
        if cyl:  # un cilindro: la luce a sinistra (un terzo) sfuma nell'ombra a destra, con il riflesso sul bordo
            bb = m.getbbox()
            if bb:
                gx = Image.new("L", (bb[2] - bb[0], 1))
                for i in range(gx.width):
                    u = i / max(1, gx.width - 1)
                    v = 0.0 if u < 0.3 else min(1.0, (u - 0.3) / 0.55) ** 0.9
                    if u > 0.92:
                        v *= 0.8  # il riflesso sul bordo in ombra
                    gx.putpixel((i, 0), int(255 * v))
                g = Image.new("L", m.size, 0)
                g.paste(gx.resize((gx.width, bb[3] - bb[1])), (bb[0], bb[1]))
                q.fill(q.intersect(g, m), M_SH, 0.95)
                hl = Image.new("L", m.size, 0)
                hx = bb[0] + int((bb[2] - bb[0]) * 0.22)
                ImageDraw.Draw(hl).rectangle([hx - (bb[2] - bb[0]) * 0.06, bb[1], hx + (bb[2] - bb[0]) * 0.06, bb[3]], fill=255)
                q.fill(q.intersect(hl.filter(ImageFilter.GaussianBlur((bb[2] - bb[0]) * 0.05)), m), M_HI, 0.7)
        else:
            q.fill(q.inner_shadow(m, -size, -size * 0.6, size * 0.7), M_SH, 0.9)
        q.fill(q.rim(m, -size * 0.35, -size * 0.35, size * 0.3), M_HI, 0.8)
        q.fill(q.grain(m, 0.28, seed + 7, 0.8), stain, 0.35)
        q.outline(m, 0.55, ink)

    # --- il piedistallo tondo ---
    ped_h = total_h * (0.36 if total_h > 150 else 0.38)
    pw = min(w * 0.42, 40) / 2  # mezza larghezza del fusto
    y = 0.0

    def ring(y0, y1, half, seed, cyl=True):
        m = q.mask()
        q.poly(m, [(-half, y0), (half, y0), (half, y1), (-half, y1)])
        marble(m, depth=(y0 - y1) * 0.3 + 1, seed=seed, cyl=cyl)

    def torus(y0, y1, half, seed):
        m = q.mask()
        q.ellipse(m, -half, y1, half, y0)
        q.poly(m, [(-half + (y0 - y1) / 2, y1), (half - (y0 - y1) / 2, y1), (half - (y0 - y1) / 2, y0), (-half + (y0 - y1) / 2, y0)])
        m = q.smooth(m, 0.4)
        q.fill(m, M)
        q.fill(q.inner_shadow(m, -2, -1.6, 1.2), M_SH, 0.9)
        q.fill(q.rim(m, -0.8, -1.0, 0.6), M_HI, 0.85)
        q.outline(m, 0.5, ink)

    h = ped_h
    ring(0, -h * 0.1, pw + 7, 1, cyl=False)  # lo zoccolo
    torus(-h * 0.1, -h * 0.19, pw + 5, 2)
    torus(-h * 0.19, -h * 0.25, pw + 3, 3)
    shaft = q.mask()
    q.poly(shaft, [(-pw, -h * 0.25), (pw, -h * 0.25), (pw * 0.94, -h * 0.82), (-pw * 0.94, -h * 0.82)])
    marble(shaft, depth=pw * 0.5, seed=4, cyl=True)
    # la targa e il festone di foglie appeso, come sui piedistalli veri
    plate = q.mask()
    q.poly(plate, [(-pw * 0.55, -h * 0.4), (pw * 0.55, -h * 0.4), (pw * 0.55, -h * 0.58), (-pw * 0.55, -h * 0.58)])
    q.fill(plate, M_HI, 0.6)
    q.fill(q.inner_shadow(plate, 1, 1, 0.6), M_SH, 0.9)
    q.outline(plate, 0.4, ink)
    letters = q.mask()
    for row in range(2):
        ly = -h * 0.53 + row * h * 0.07
        lx = -pw * 0.42
        while lx < pw * 0.4:
            seg = rng.uniform(1.0, 2.6)
            q.stroke(letters, [(lx, ly), (min(lx + seg, pw * 0.42), ly)], 0.45)
            lx += seg + 1.0
    q.fill(letters, M_DK, 0.8)
    fest = q.mask()
    pts = bezier((-pw * 0.92, -h * 0.74), (-pw * 0.5, -h * 0.62), (pw * 0.5, -h * 0.62), (pw * 0.92, -h * 0.74), 20)
    for i, (fx, fy) in enumerate(pts):
        r = 1.6 + 0.7 * math.sin(i)
        q.ellipse(fest, fx - r, fy - r * 0.8, fx + r, fy + r * 0.8)
    q.fill(fest, M)
    q.fill(q.inner_shadow(fest, -0.8, -0.8, 0.5), M_SH, 0.95)
    q.fill(q.grain(fest, 0.6, 9, 0.5), M_DK, 0.5)
    q.outline(fest, 0.4, ink)
    torus(-h * 0.82, -h * 0.88, pw + 2, 5)
    ring(-h * 0.88, -h, pw + 5, 6, cyl=False)  # la cornice che sporge
    q.fill(q.soften(q.poly(q.mask(), [(-pw - 2, -h * 0.88), (pw + 2, -h * 0.88), (pw, -h * 0.85), (-pw, -h * 0.85)]), 0.8), (40, 38, 34), 0.35)
    # --- la figura ---
    F = total_h - ped_h  # dai piedi alle mani
    feet = -ped_h
    top = -total_h
    head_r = F * 0.072
    head_cy = top + F * 0.215
    sh_y = head_cy + head_r * 1.75
    sh_w = F * 0.135
    waist_y = sh_y + F * 0.27
    hip = F * 0.025  # posa a riposo: il fianco spinto da una parte, il ginocchio dell'altra gamba avanti
    hem_w = F * (0.2 if kind == "dama" else 0.16)
    knee = (-F * 0.055, feet - F * 0.27)
    # il plinto sotto i piedi
    pl = q.mask()
    q.poly(pl, [(-hem_w - 3, feet), (hem_w + 3, feet), (hem_w + 2, feet - 3), (-hem_w - 2, feet - 3)])
    marble(pl, depth=1.5, seed=10)
    # le braccia alzate: la parte alta che sale in fuori fino al gomito, l'avambraccio che torna su verso la lastra
    elbows, hand_pos = [], []
    for side in (-1, 1):
        elbows.append((side * F * 0.26, head_cy - head_r * 0.1))
        hand_pos.append((side * F * 0.165, top + F * 0.035))
    arms = q.mask()
    for side, (ex, ey), (hx, hy) in zip((-1, 1), elbows, hand_pos):
        shoulder = (side * sh_w * 0.85, sh_y + F * 0.01)
        q.poly(arms, [(shoulder[0] - side * F * 0.02, shoulder[1] - F * 0.04), (ex + side * F * 0.03, ey - F * 0.02),
                      (ex + side * F * 0.012, ey + F * 0.045), (shoulder[0] + side * F * 0.01, shoulder[1] + F * 0.06)])  # il braccio, col deltoide
        q.poly(arms, [(ex + side * F * 0.03, ey - F * 0.02), (hx + side * F * 0.03, hy + F * 0.04), (hx - side * F * 0.015, hy + F * 0.045), (ex - side * F * 0.02, ey + F * 0.03)])
    arms = q.smooth(arms, F * 0.008)
    marble(arms, depth=F * 0.035, seed=11)
    sleeve = q.mask()  # le maniche larghe: la stoffa pende sotto il braccio alzato, dalla spalla al gomito, morbida
    for side, (ex, ey) in zip((-1, 1), elbows):
        sx, sy = side * sh_w * 0.85, sh_y + F * 0.01
        q.poly(sleeve, [(sx, sy - F * 0.03), (ex + side * F * 0.02, ey - F * 0.01)] + bezier((ex + side * F * 0.02, ey + F * 0.03), (ex, ey + F * 0.11), (sx + side * F * 0.02, sy + F * 0.1), (sx - side * F * 0.02, sy + F * 0.06), 10))
    sleeve = q.smooth(sleeve, F * 0.015)
    marble(sleeve, depth=F * 0.03, seed=12)
    sfold = q.mask()
    for side, (ex, ey) in zip((-1, 1), elbows):
        for j in range(3):
            u = (j + 1) / 4
            px, py = ex + (side * sh_w * 0.85 - ex) * u, ey + (sh_y - ey) * u
            q.stroke(sfold, [(px, py + F * 0.01), (px + side * F * 0.01, py + F * 0.08)], F * 0.007)
    q.fill(q.intersect(q.soften(sfold, 0.4), sleeve), M_DK, 0.7)
    hands = q.mask()  # le mani aperte sotto la lastra: il palmo piatto contro il marmo e il polso
    for side, (hx, hy) in zip((-1, 1), hand_pos):
        q.ellipse(hands, hx - F * 0.05, top + 0.4, hx + F * 0.05, top + F * 0.045)
        q.ellipse(hands, hx - F * 0.028, top + F * 0.02, hx + F * 0.028, hy + F * 0.05)
    hands = q.smooth(hands, 0.8)
    marble(hands, depth=1.4, seed=13)
    fingers = q.mask()
    for side, (hx, hy) in zip((-1, 1), hand_pos):
        for j in range(3):
            fx = hx - F * 0.025 + j * F * 0.022
            q.stroke(fingers, [(fx, top + 0.8), (fx, top + F * 0.02)], 0.35)
    q.fill(q.intersect(fingers, hands), M_DK, 0.7)
    # il corpo: spalle tonde, il petto, la vita, il fianco spinto e la veste che si apre fino all'orlo
    body = q.mask()
    left = bezier((-sh_w * 0.55, sh_y - F * 0.015), (-sh_w * 1.15, sh_y), (-sh_w * 0.95, waist_y), (-sh_w * 0.85 + hip, waist_y + F * 0.04), 12) \
        + bezier((-sh_w * 0.85 + hip, waist_y + F * 0.04), (-hem_w * 0.95 + hip, waist_y + F * 0.25), (-hem_w * 1.1, feet - F * 0.12), (-hem_w, feet - 2.5), 12)
    right = bezier((sh_w * 0.55, sh_y - F * 0.015), (sh_w * 1.15, sh_y), (sh_w * 1.0, waist_y), (sh_w * 0.95 + hip, waist_y + F * 0.05), 12) \
        + bezier((sh_w * 0.95 + hip, waist_y + F * 0.05), (hem_w * 1.05 + hip, waist_y + F * 0.3), (hem_w * 1.05, feet - F * 0.1), (hem_w, feet - 2.5), 12)
    hem = [(-hem_w + (2 * hem_w) * i / 14, feet - 2.5 + 1.3 * math.sin(i * 1.4)) for i in range(15)]
    q.poly(body, left + hem + list(reversed(right)))
    body = q.smooth(body, 0.7)
    q.fill(body, M)
    q.fill(q.inner_shadow(body, -F * 0.09, -F * 0.03, F * 0.07), M_SH, 0.95)  # il corpo è tondo: ombra larga a destra
    q.fill(q.inner_shadow(body, -F * 0.03, 0, F * 0.02), M_DK, 0.45)
    q.fill(q.rim(body, -F * 0.012, -F * 0.012, F * 0.01), M_HI, 0.85)
    kn = q.ellipse(q.mask(), knee[0] - F * 0.05, knee[1] - F * 0.06, knee[0] + F * 0.04, knee[1] + F * 0.05)
    q.fill(q.intersect(q.soften(kn, F * 0.02), body), M_HI, 0.7)  # il ginocchio avanti prende la luce
    # le pieghe: cadono dalla vita, si piegano attorno al ginocchio e si aprono sull'orlo; filo di luce accanto
    folds, glints = q.mask(), q.mask()
    n = 9 if kind == "dama" else 7
    for i in range(n):
        u = -0.85 + 1.7 * i / (n - 1)
        x0 = u * sh_w * 0.8 + hip
        x1 = u * hem_w * 0.92 + rng.uniform(-1.2, 1.2)
        bend = (knee[0] - x0) * 0.35 if abs(u + 0.3) < 0.5 else rng.uniform(-1.5, 1.5)
        pts = bezier((x0, waist_y + F * 0.04), (x0 + bend, waist_y + F * 0.2), (x1 - bend * 0.5, feet - F * 0.18), (x1, feet - 3), 16)
        q.stroke(folds, pts, F * (0.014 if i % 2 else 0.009))
        q.stroke(glints, [(px - F * 0.014, py) for px, py in pts], F * 0.006)
    for j in range(4):  # le pieghe a V sul petto sotto le braccia alzate
        yy = sh_y + F * (0.05 + j * 0.05)
        q.stroke(folds, [(-sh_w * 0.7, yy - F * 0.03), (hip * 0.5, yy + F * 0.02), (sh_w * 0.7, yy - F * 0.03)], F * 0.006)
    q.fill(q.intersect(q.soften(folds, F * 0.006), body), M_DK, 0.7)
    q.fill(q.intersect(q.soften(glints, F * 0.004), body), M_HI, 0.75)
    q.outline(body, 0.6, ink)
    belt = q.mask()  # la cintura annodata
    q.poly(belt, [(-sh_w * 0.95 + hip, waist_y + F * 0.02), (sh_w * 1.0 + hip, waist_y + F * 0.01), (sh_w * 1.0 + hip, waist_y + F * 0.045), (-sh_w * 0.95 + hip, waist_y + F * 0.055)])
    q.fill(q.intersect(belt, body), M_SH, 0.85)
    q.fill(q.intersect(q.ellipse(q.mask(), hip - F * 0.03, waist_y + F * 0.01, hip + F * 0.03, waist_y + F * 0.06), body), M_HI, 0.7)
    drape = q.mask()
    if kind == "giovane":  # la toga che scende in diagonale dalla spalla al fianco e ricade
        q.poly(drape, bezier((-sh_w * 1.0, sh_y), (-sh_w * 0.2, sh_y + F * 0.05), (sh_w * 0.6, waist_y), (sh_w * 1.1 + hip, waist_y + F * 0.15), 12)
               + bezier((sh_w * 1.1 + hip, waist_y + F * 0.28), (sh_w * 0.4, waist_y + F * 0.12), (-sh_w * 0.3, sh_y + F * 0.12), (-sh_w * 0.9, sh_y + F * 0.06), 12))
    elif kind == "filosofo":  # il mantello che cade da una spalla fino ai piedi, a grandi pieghe
        q.poly(drape, bezier((sh_w * 0.3, sh_y - F * 0.01), (sh_w * 1.3, sh_y), (hem_w * 1.4, feet - F * 0.3), (hem_w * 1.2, feet - 3), 14)
               + bezier((hem_w * 0.2, feet - 3), (sh_w * 0.4, waist_y + F * 0.2), (sh_w * 0.7, waist_y - F * 0.05), (sh_w * 0.4, sh_y + F * 0.05), 14))
    else:  # il velo che copre la testa, tondo, e scende morbido sulle spalle
        q.ellipse(drape, -head_r * 1.25, head_cy - head_r * 1.3, head_r * 1.25, head_cy + head_r * 0.9)
        q.poly(drape, [(-head_r * 1.2, head_cy), (head_r * 1.2, head_cy)] + bezier((head_r * 1.2, head_cy), (head_r * 1.5, sh_y), (sh_w * 1.15, sh_y + F * 0.04), (sh_w * 1.05, sh_y + F * 0.16), 10)
               + bezier((-sh_w * 1.05, sh_y + F * 0.16), (-sh_w * 1.15, sh_y + F * 0.04), (-head_r * 1.5, sh_y), (-head_r * 1.2, head_cy), 10))
    drape = q.smooth(drape, F * 0.02)
    q.fill(drape, M)
    q.fill(q.inner_shadow(drape, -F * 0.05, -F * 0.03, F * 0.04), M_SH, 0.95)
    q.fill(q.rim(drape, -F * 0.01, -F * 0.012, F * 0.008), M_HI, 0.85)
    dfolds = q.mask()
    for i in range(5):
        u = (i + 0.5) / 5
        if kind == "filosofo":
            pts = bezier((sh_w * (0.5 + 0.6 * u), sh_y + 2), (sh_w * (0.8 + 0.6 * u), waist_y), (hem_w * (0.5 + 0.6 * u), feet - F * 0.2), (hem_w * (0.3 + 0.85 * u), feet - 4), 12)
        elif kind == "giovane":
            pts = [(-sh_w * 0.8 + u * sh_w * 1.2, sh_y + F * 0.02 + u * F * 0.06), (-sh_w * 0.2 + u * sh_w * 1.3, sh_y + F * 0.1 + u * F * 0.12)]
        else:
            pts = bezier((-head_r * 1.1 + u * head_r * 2.2, head_cy - head_r * 0.4), ((-1.2 + 2.4 * u) * head_r * 1.4, head_cy + head_r), ((-1.2 + 2.4 * u) * sh_w, sh_y + F * 0.05), ((-1.25 + 2.5 * u) * sh_w, sh_y + F * 0.19), 10)
        q.stroke(dfolds, pts, F * 0.009)
    q.fill(q.intersect(q.soften(dfolds, 0.4), drape), M_DK, 0.75)
    q.fill(q.grain(drape, 0.25, 30, 0.8), stain, 0.3)
    q.outline(drape, 0.55, ink)
    # i piedi con i sandali, che escono dall'orlo
    for side in (-1, 1):
        fx = side * hem_w * 0.4 + (F * 0.02 if side < 0 else 0)
        fm = q.ellipse(q.mask(), fx - F * 0.045, feet - 4, fx + F * 0.045, feet - 0.6)
        marble(fm, depth=0.8, seed=16)
    # il collo e la testa scolpita
    neck = q.mask()
    q.poly(neck, [(-head_r * 0.42, head_cy + head_r * 0.6), (head_r * 0.42, head_cy + head_r * 0.6), (head_r * 0.6, sh_y + 1), (-head_r * 0.6, sh_y + 1)])
    marble(neck, depth=1.0, seed=17)
    if kind == "filosofo":  # i riccioli dietro la testa
        back = q.ellipse(q.mask(), -head_r * 1.12, head_cy - head_r * 1.12, head_r * 1.12, head_cy + head_r * 0.6)
        marble(back, depth=1.2, seed=18)
        q.fill(q.grain(back, 0.9, 25, 0.45), M_DK, 0.6)
    head = q.mask()  # la testa: ovale con la mascella
    q.poly(head, bezier((0, head_cy - head_r), (-head_r * 1.15, head_cy - head_r), (-head_r * 0.95, head_cy + head_r * 0.7), (0, head_cy + head_r * 1.02), 12)
           + bezier((0, head_cy + head_r * 1.02), (head_r * 0.95, head_cy + head_r * 0.7), (head_r * 1.15, head_cy - head_r), (0, head_cy - head_r), 12))
    q.fill(head, M)
    q.fill(q.inner_shadow(head, -head_r * 0.6, -head_r * 0.2, head_r * 0.45), M_SH, 0.95)
    q.fill(q.rim(head, -head_r * 0.15, -head_r * 0.15, head_r * 0.12), M_HI, 0.8)
    face = q.mask()  # gli incavi degli occhi, l'ombra del naso e sotto il labbro: il volto si legge dalle ombre
    for ex in (-head_r * 0.36, head_r * 0.36):
        q.ellipse(face, ex - head_r * 0.2, head_cy - head_r * 0.22, ex + head_r * 0.2, head_cy + head_r * 0.0)
    q.poly(face, [(head_r * 0.04, head_cy - head_r * 0.08), (head_r * 0.16, head_cy + head_r * 0.36), (head_r * 0.0, head_cy + head_r * 0.36)])
    q.ellipse(face, -head_r * 0.2, head_cy + head_r * 0.54, head_r * 0.22, head_cy + head_r * 0.62)
    q.fill(q.intersect(q.soften(face, head_r * 0.08), head), M_DK, 0.75)
    brow = q.mask()
    q.stroke(brow, [(-head_r * 0.62, head_cy - head_r * 0.3), (head_r * 0.62, head_cy - head_r * 0.3)], head_r * 0.1)
    q.fill(q.intersect(q.soften(brow, head_r * 0.05), head), M_HI, 0.6)
    q.outline(head, 0.5, ink)
    if kind == "filosofo":  # la barba a riccioli
        beard = q.mask()
        q.poly(beard, bezier((-head_r * 0.85, head_cy + head_r * 0.05), (-head_r * 0.95, head_cy + head_r * 1.6), (head_r * 0.95, head_cy + head_r * 1.6), (head_r * 0.85, head_cy + head_r * 0.05), 14))
        q.fill(beard, M)
        q.fill(q.inner_shadow(beard, -head_r * 0.5, -head_r * 0.2, head_r * 0.35), M_SH, 0.95)
        q.fill(q.grain(beard, 0.95, 21, 0.45), M_DK, 0.6)
        q.fill(q.ellipse(q.mask(), -head_r * 0.24, head_cy + head_r * 0.48, head_r * 0.24, head_cy + head_r * 0.58), M_DK, 0.8)
        q.outline(beard, 0.45, ink)
    hair = q.mask()
    if kind == "dama":  # i capelli divisi in mezzo che spuntano dal velo
        q.poly(hair, bezier((-head_r * 0.85, head_cy - head_r * 0.1), (-head_r * 0.9, head_cy - head_r * 0.95), (head_r * 0.9, head_cy - head_r * 0.95), (head_r * 0.85, head_cy - head_r * 0.1), 12) + [(0, head_cy - head_r * 0.55)])
    else:
        q.poly(hair, bezier((-head_r * 0.98, head_cy - head_r * 0.05), (-head_r * 1.05, head_cy - head_r * 1.35), (head_r * 1.05, head_cy - head_r * 1.35), (head_r * 0.98, head_cy - head_r * 0.05), 14) + [(head_r * 0.55, head_cy - head_r * 0.55), (-head_r * 0.55, head_cy - head_r * 0.55)])
    hair = q.smooth(hair, 0.4)
    q.fill(hair, M)
    q.fill(q.inner_shadow(hair, -head_r * 0.4, -head_r * 0.3, head_r * 0.3), M_SH, 0.9)
    q.fill(q.grain(hair, 0.95, 23, 0.4), M_DK, 0.6)
    q.outline(hair, 0.45, ink)
    if kind == "giovane":  # la corona d'alloro, foglia per foglia
        laurel = q.mask()
        for i in range(11):
            a = math.pi * (1.0 + i / 10)
            lx, ly = head_r * 1.0 * math.cos(a), head_cy - head_r * 0.45 + head_r * 0.5 * math.sin(a)
            q.ellipse(laurel, lx - 1.4, ly - 0.75, lx + 1.4, ly + 0.75)
        q.fill(laurel, M)
        q.fill(q.inner_shadow(laurel, -0.6, -0.6, 0.4), M_SH, 0.9)
        q.outline(laurel, 0.35, ink)
    # l'ombra di contatto sulla cornice del piedistallo
    q.fill(q.soften(q.ellipse(q.mask(), -hem_w - 3, feet - 1, hem_w + 6, feet + 2.5), 1.0), (40, 38, 34), 0.35)
    q.save(OUT, name)


def statue(name, total_h, slab_w, kind):
    """Statua del Prato su piedistallo tondo, che regge una lastra sulle mani, con il volto disegnato.

    kind: "filosofo" (barba e capelli ricci), "giovane" (corona d'alloro), "dama" (velo).
    Si disegna a 4x e si riduce a 2x (scale 0.5 nel gioco): i piedi del piedistallo sono in fondo all'immagine,
    le mani in cima, dove sta la lastra. Ombre piatte a 2 toni con la luce da sinistra, contorno a inchiostro."""
    S = 4  # pixel per pixel di mondo nel disegno
    W, H = int(max(slab_w, 76) * S), int(total_h * S)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    lw = 2 * S // 2 + 1  # spessore dell'inchiostro
    cx = W / 2

    def poly(pts, fill, shade_pts=None):
        d.polygon(pts, fill=fill)
        if shade_pts:
            d.polygon(shade_pts, fill=MARBLE_SHADE)
        d.line(pts + [pts[0]], fill=INK, width=lw, joint="curve")

    # --- piedistallo: zoccolo a due gradini, toro, dado con la targa e il festone, cornice che sporge ---
    ped_h = min(48, total_h * 0.33) * S
    ped_w = 36 * S
    base = H - 1
    MID = mix(MARBLE, MARBLE_SHADE, 0.5)

    def band(y0, y1, half, round_=False):
        if round_:  # toro: una fascia tonda, chiara in alto e in ombra sotto
            d.rounded_rectangle([cx - half, y0, cx + half, y1], radius=(y1 - y0) / 2, fill=MARBLE)
            d.rectangle([cx - half + (y1 - y0) / 2, (y0 + y1) / 2, cx + half - (y1 - y0) / 2, y1 - lw / 2], fill=MID)
            d.rounded_rectangle([cx - half, y0, cx + half, y1], radius=(y1 - y0) / 2, outline=INK, width=lw)
            return
        d.rectangle([cx - half, y0, cx + half, y1], fill=MARBLE)
        d.rectangle([cx + half * 0.35, y0, cx + half, y1], fill=MARBLE_SHADE)
        d.rectangle([cx - half, y0, cx + half, y1], outline=INK, width=lw)
    band(base - 5 * S, base, ped_w / 2 + 8 * S)  # gradino basso
    band(base - 9 * S, base - 5 * S, ped_w / 2 + 5 * S)  # gradino alto
    band(base - 13 * S, base - 9 * S, ped_w / 2 + 3 * S, round_=True)  # toro
    band(base - ped_h + 10 * S, base - 13 * S, ped_w / 2)  # dado
    d.rectangle([cx - ped_w / 2, base - ped_h + 10 * S, cx + ped_w / 2, base - ped_h + 12 * S], fill=MARBLE_SHADE)  # ombra sotto la cornice
    band(base - ped_h + 6 * S, base - ped_h + 10 * S, ped_w / 2 + 3 * S, round_=True)  # listello
    band(base - ped_h, base - ped_h + 6 * S, ped_w / 2 + 7 * S)  # cornice
    # targa con l'iscrizione (tratti illeggibili: il nome si sceglie con il gruppo)
    ty0, ty1 = base - ped_h + 17 * S, base - ped_h + 28 * S
    d.rectangle([cx - 11 * S, ty0, cx + 11 * S, ty1], fill=(204, 198, 184, 255), outline=INK, width=lw)
    d.rectangle([cx - 11 * S + lw, ty1 - 2 * S, cx + 11 * S - lw, ty1 - lw], fill=MID)
    for row in range(2):
        y = ty0 + (3.5 + row * 4.5) * S
        x = cx - 8 * S
        rng = random.Random(len(name) * 7 + row)
        while x < cx + 7 * S:
            seg = rng.randint(2, 4) * S
            d.line([x, y, min(x + seg, cx + 8 * S), y], fill=INK, width=S)
            x += seg + 2 * S
    # festone di foglie appeso agli angoli del dado, con i nastri
    fy = base - ped_h + 13 * S
    for side in (-1, 1):
        x0, x1 = (cx - ped_w / 2 + 2 * S, cx) if side < 0 else (cx, cx + ped_w / 2 - 2 * S)
        for k in range(7):
            u = k / 6
            lx = x0 + (x1 - x0) * u
            ly = fy + math.sin(u * math.pi) * 4 * S
            d.ellipse([lx - 2.2 * S, ly - 1.4 * S, lx + 2.2 * S, ly + 1.4 * S], fill=MARBLE if k % 2 else MID, outline=INK, width=max(1, S // 2))
    for x in (cx - ped_w / 2 + 2 * S, cx, cx + ped_w / 2 - 2 * S):
        d.line([x, fy - S, x - S, fy + 4 * S], fill=INK, width=max(1, S // 2))  # nastro

    # --- la figura: dalla cornice alle mani ---
    feet = base - ped_h
    fig = feet  # altezza della figura, mani comprese
    head_r = fig * 0.1
    head_cy = fig * 0.25
    sh_y = head_cy + head_r * 1.5  # spalle
    sh_w = head_r * 1.7
    waist_y = sh_y + (feet - sh_y) * 0.38

    def half_width(y):
        # dalle spalle si stringe alla vita, poi la veste si allarga fino ai piedi
        if y <= waist_y:
            k = (y - sh_y) / (waist_y - sh_y)
            return sh_w * (1 - 0.18 * k)
        k = (y - waist_y) / (feet - waist_y)
        return sh_w * (0.82 + 0.6 * k ** 0.8)

    ys = [sh_y + (feet - sh_y) * i / 24 for i in range(25)]
    left = [(cx - half_width(y), y) for y in ys]
    right = [(cx + half_width(y), y) for y in ys]
    body = right + left[::-1]
    d.polygon(body, fill=MARBLE)
    d.polygon([(cx + half_width(y) * 0.15 + (y - sh_y) * 0.05, y) for y in ys] + right[::-1], fill=MARBLE_SHADE)  # ombra a destra
    d.line(body + [body[0]], fill=INK, width=lw, joint="curve")
    # mantello a toga: dalla spalla sinistra al fianco destro, con il lembo che ricade
    toga = [(cx - sh_w * 0.95, sh_y + S), (cx - sh_w * 0.2, sh_y + S * 2), (cx + half_width(waist_y) * 1.05, waist_y + S * 6), (cx + half_width(waist_y) * 0.9, waist_y + S * 14), (cx - sh_w * 0.4, sh_y + S * 14)]
    d.polygon(toga, fill=(222, 216, 203, 255))
    d.line(toga + [toga[0]], fill=INK, width=lw, joint="curve")
    for i in range(3):  # pieghe del mantello
        t0 = 0.2 + i * 0.25
        a = (toga[0][0] + (toga[2][0] - toga[0][0]) * t0, toga[0][1] + (toga[2][1] - toga[0][1]) * t0)
        d.line([a, (a[0] - 3 * S, a[1] + 10 * S)], fill=INK, width=S)
    # pieghe della veste in ombra piatta: strisce tra una piega e l'altra, sul lato in luce
    for i in range(0, 5, 2):
        fx0, fx1 = -0.75 + i * 0.3, -0.75 + i * 0.3 + 0.13
        ys2 = [waist_y + S * 10 + (feet - waist_y - S * 12) * k / 8 for k in range(9)]
        left_edge = [(cx + fx0 * half_width(y) + math.sin(k * 0.7 + i) * S * 0.7, y) for k, y in enumerate(ys2)]
        right_edge = [(cx + fx1 * half_width(y) + math.sin(k * 0.7 + i) * S * 0.7, y) for k, y in enumerate(ys2)]
        d.polygon(left_edge + right_edge[::-1], fill=mix(MARBLE, MARBLE_SHADE, 0.55))
    # pieghe della veste: linee che scendono ondeggiando fino all'orlo
    rng = random.Random(len(name))
    for i in range(6):
        fx = -0.75 + i * 0.3
        pts = []
        for k in range(9):
            y = waist_y + S * 10 + (feet - waist_y - S * 12) * k / 8
            pts.append((cx + fx * half_width(y) + math.sin(k * 0.7 + i) * S * 0.7, y))
        d.line(pts, fill=INK, width=S if i % 2 else S + 1, joint="curve")
    # ginocchio piegato (contrapposto) sotto la veste
    ky = waist_y + (feet - waist_y) * 0.45
    d.arc([cx + half_width(ky) * 0.05, ky - 6 * S, cx + half_width(ky) * 0.85, ky + 6 * S], 200, 340, fill=INK, width=lw)
    d.line([cx - half_width(feet) - S, feet - S, cx + half_width(feet) + S, feet - S], fill=INK, width=lw)
    for fx in (cx - sh_w * 0.55, cx + sh_w * 0.45):  # punte dei piedi sotto l'orlo
        d.chord([fx - 5 * S, feet - 5 * S, fx + 5 * S, feet + 2 * S], 180, 360, fill=MARBLE, outline=INK, width=S)

    # braccia alzate fino alla lastra: spalla, gomito, polso arrotondati
    hand_dx = min(slab_w * S * 0.3, sh_w * 2.3)
    arm_w = int(head_r * 0.62)
    for side in (-1, 1):
        sh = (cx + side * sh_w * 0.92, sh_y + 3 * S)
        hand = (cx + side * hand_dx, 6 * S)
        elbow = ((sh[0] + hand[0]) / 2 + side * 7 * S, (sh[1] + hand[1]) * 0.55)
        tone = MARBLE if side < 0 else MARBLE_SHADE
        for a, b in ((sh, elbow), (elbow, hand)):
            d.line([a, b], fill=INK, width=arm_w + 2 * lw)
        for c in (sh, elbow, hand):
            r = arm_w / 2 + lw
            d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=INK)
        for a, b in ((sh, elbow), (elbow, hand)):
            d.line([a, b], fill=tone, width=arm_w)
        for c in (sh, elbow):
            r = arm_w / 2
            d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=tone)
        # mano aperta sotto la lastra, con le dita
        d.ellipse([hand[0] - 6 * S, 0, hand[0] + 6 * S, 10 * S], fill=MARBLE, outline=INK, width=S)
        for f in range(4):
            fx = hand[0] - 4.5 * S + f * 3 * S
            d.line([fx, 0, fx, 4 * S], fill=INK, width=max(1, S // 2))
    # manica che ricade dal braccio alzato
    sh_l = (cx - sh_w * 0.92, sh_y + 3 * S)
    hand_l = (cx - hand_dx, 6 * S)
    elbow_l = ((sh_l[0] + hand_l[0]) / 2 - 7 * S, (sh_l[1] + hand_l[1]) * 0.55)
    mid = (sh_l[0] + (elbow_l[0] - sh_l[0]) * 0.55, sh_l[1] + (elbow_l[1] - sh_l[1]) * 0.55)
    sleeve = [(sh_l[0] + 3 * S, sh_l[1] - 3 * S), mid, (mid[0] + 1 * S, mid[1] + 9 * S), (sh_l[0] - 1 * S, sh_l[1] + 14 * S), (sh_l[0] + 4 * S, sh_l[1] + 10 * S)]
    d.polygon(sleeve, fill=(222, 216, 203, 255))
    d.polygon([sleeve[2], sleeve[3], sleeve[4]], fill=mix(MARBLE, MARBLE_SHADE, 0.5))
    d.line(sleeve + [sleeve[0]], fill=INK, width=lw, joint="curve")
    d.line([((sleeve[0][0] + mid[0]) / 2, (sleeve[0][1] + mid[1]) / 2), (sh_l[0] + S, sh_l[1] + 9 * S)], fill=INK, width=S)

    # --- collo, capelli dietro, testa e volto ---
    neck_w = head_r * 0.5
    d.rectangle([cx - neck_w, head_cy + head_r * 0.5, cx + neck_w, sh_y + S * 2], fill=MARBLE, outline=INK, width=S)
    d.rectangle([cx + neck_w * 0.15, head_cy + head_r * 0.5, cx + neck_w - S, sh_y + S], fill=MARBLE_SHADE)
    hx0, hy0, hx1, hy1 = cx - head_r * 0.8, head_cy - head_r, cx + head_r * 0.8, head_cy + head_r * 1.02

    if kind == "dama":  # il velo sta dietro al volto e scende sulle spalle
        veil = [(cx - head_r * 1.2, sh_y + head_r * 0.9), (cx - head_r * 1.05, hy0 + head_r * 0.15), (cx, hy0 - head_r * 0.28), (cx + head_r * 1.05, hy0 + head_r * 0.15), (cx + head_r * 1.3, sh_y + head_r * 1.0)]
        d.polygon(veil, fill=(206, 200, 186, 255))
        d.polygon([(cx, hy0 - head_r * 0.28), (cx + head_r * 1.05, hy0 + head_r * 0.15), (cx + head_r * 1.3, sh_y + head_r * 1.0), (cx + head_r * 0.5, sh_y)], fill=MARBLE_SHADE)
        d.line(veil, fill=INK, width=lw, joint="curve")
        for i in range(3):
            x = cx - head_r * 1.0 + i * head_r * 0.15
            d.line([x, head_cy, x - head_r * 0.1, sh_y + head_r * 0.7], fill=INK, width=S)
    if kind == "filosofo":  # riccioli dietro, prima del volto
        for i in range(11):
            a = math.pi * (0.95 + i * 0.11)
            rx, ry = cx + math.cos(a) * head_r * 0.85, head_cy - head_r * 0.05 + math.sin(a) * head_r * 1.0
            d.ellipse([rx - head_r * 0.24, ry - head_r * 0.24, rx + head_r * 0.24, ry + head_r * 0.24], fill=MARBLE, outline=INK, width=S)

    d.ellipse([hx0, hy0, hx1, hy1], fill=MARBLE)
    d.chord([hx0, hy0, hx1, hy1], 285, 75, fill=MARBLE_SHADE)  # metà del volto in ombra
    d.ellipse([hx0, hy0, hx1, hy1], outline=INK, width=lw)
    for side in (-1, 1):  # orecchie
        ex = cx + side * head_r * 0.82
        d.ellipse([ex - head_r * 0.13, head_cy - head_r * 0.12, ex + head_r * 0.13, head_cy + head_r * 0.32], fill=MARBLE, outline=INK, width=S)
    # occhi a mandorla, senza pupilla come nel marmo, con sopracciglia e palpebre
    ey = head_cy - head_r * 0.02
    for side in (-1, 1):
        ex = cx + side * head_r * 0.34
        d.arc([ex - head_r * 0.26, ey - head_r * 0.36, ex + head_r * 0.26, ey - head_r * 0.06], 200, 340, fill=INK, width=S + 1)
        d.chord([ex - head_r * 0.21, ey - head_r * 0.1, ex + head_r * 0.21, ey + head_r * 0.11], 180, 360, fill=(238, 234, 224, 255))
        d.arc([ex - head_r * 0.21, ey - head_r * 0.1, ex + head_r * 0.21, ey + head_r * 0.11], 180, 360, fill=INK, width=S)
        d.line([ex - head_r * 0.21, ey, ex + head_r * 0.21, ey], fill=INK, width=S)
        d.ellipse([ex - head_r * 0.06, ey - head_r * 0.07, ex + head_r * 0.06, ey + head_r * 0.01], fill=MARBLE_SHADE)  # iride appena incisa
    # naso dritto alla greca, che scende dalla fronte, con l'ombra a destra e le narici
    d.polygon([(cx - head_r * 0.02, ey - head_r * 0.12), (cx + head_r * 0.12, ey + head_r * 0.42), (cx - head_r * 0.1, ey + head_r * 0.44)], fill=MARBLE_SHADE)
    d.line([cx - head_r * 0.04, ey - head_r * 0.12, cx - head_r * 0.1, ey + head_r * 0.42], fill=INK, width=S)
    d.arc([cx - head_r * 0.2, ey + head_r * 0.34, cx + head_r * 0.16, ey + head_r * 0.5], 0, 180, fill=INK, width=S)
    my = ey + head_r * 0.66
    if kind == "filosofo":  # barba piena a riccioli, dalle guance al mento, che lascia scoperta la bocca
        beard = [(cx - head_r * 0.8, ey + head_r * 0.25), (cx - head_r * 0.35, my - head_r * 0.05), (cx + head_r * 0.35, my - head_r * 0.05), (cx + head_r * 0.8, ey + head_r * 0.25), (cx + head_r * 0.55, head_cy + head_r * 1.45), (cx, head_cy + head_r * 1.7), (cx - head_r * 0.55, head_cy + head_r * 1.45)]
        d.polygon(beard, fill=MARBLE)
        d.polygon([(cx, my), (cx + head_r * 0.35, my - head_r * 0.05), (cx + head_r * 0.8, ey + head_r * 0.25), (cx + head_r * 0.55, head_cy + head_r * 1.45), (cx, head_cy + head_r * 1.7)], fill=MARBLE_SHADE)
        d.line(beard + [beard[0]], fill=INK, width=S, joint="curve")
        for row in range(3):
            for i in range(4 - row):
                bx = cx - head_r * (0.42 - row * 0.12) + i * head_r * 0.28
                by = my + head_r * (0.25 + row * 0.3)
                d.arc([bx - head_r * 0.15, by - head_r * 0.1, bx + head_r * 0.15, by + head_r * 0.14], 10, 170, fill=INK, width=S)  # ciocca a riccio
        for side in (-1, 1):  # baffi
            d.arc([cx + min(0, side) * head_r * 0.4, my - head_r * 0.22, cx + max(0, side) * head_r * 0.4, my + head_r * 0.06], 200, 340, fill=INK, width=S + 1)
    # bocca: labbro di sopra, di sotto e l'angolo; mento
    d.line([cx - head_r * 0.2, my, cx + head_r * 0.2, my], fill=INK, width=S)
    d.arc([cx - head_r * 0.13, my - head_r * 0.01, cx + head_r * 0.13, my + head_r * 0.13], 20, 160, fill=INK, width=max(1, S // 2))
    if kind != "filosofo":
        d.arc([cx - head_r * 0.2, my + head_r * 0.14, cx + head_r * 0.2, my + head_r * 0.34], 40, 140, fill=INK, width=max(1, S // 2))
    if kind == "giovane":  # capelli corti a ciocche e corona d'alloro
        d.chord([hx0 - S, hy0 - S, hx1 + S, head_cy + head_r * 0.15], 180, 360, fill=MARBLE, outline=INK, width=S)
        for i in range(7):
            x = hx0 + head_r * 0.15 + i * head_r * 0.22
            d.arc([x - head_r * 0.13, hy0 + head_r * 0.28, x + head_r * 0.13, hy0 + head_r * 0.62], 180, 360, fill=INK, width=S)
        for i in range(11):
            a = math.pi * (1.0 + i * 0.1)
            lx, ly = cx + math.cos(a) * head_r * 0.86, head_cy - head_r * 0.28 + math.sin(a) * head_r * 0.6
            ang = a + math.pi / 2
            lp = [(lx + math.cos(ang) * head_r * 0.2, ly + math.sin(ang) * head_r * 0.2), (lx + math.cos(ang + 1.5) * head_r * 0.07, ly + math.sin(ang + 1.5) * head_r * 0.07), (lx - math.cos(ang) * head_r * 0.2, ly - math.sin(ang) * head_r * 0.2), (lx - math.cos(ang + 1.5) * head_r * 0.07, ly - math.sin(ang + 1.5) * head_r * 0.07)]
            d.polygon(lp, fill=(196, 196, 168, 255), outline=INK)
    if kind == "dama":  # capelli raccolti e scriminatura sotto il velo
        d.chord([hx0, hy0, hx1, head_cy - head_r * 0.25], 180, 360, fill=(222, 216, 203, 255), outline=INK, width=S)
        d.line([cx, hy0 + S, cx, head_cy - head_r * 0.3], fill=INK, width=S)
        for side in (-1, 1):
            d.arc([cx + side * head_r * 0.05 - head_r * 0.45 + side * head_r * 0.35, hy0 + head_r * 0.1, cx + side * head_r * 0.05 + head_r * 0.45 + side * head_r * 0.35, head_cy - head_r * 0.15], 200, 320, fill=INK, width=S)
    if kind == "filosofo":  # riccioli sulla fronte
        for i in range(5):
            x = cx - head_r * 0.48 + i * head_r * 0.24
            d.ellipse([x - head_r * 0.15, hy0 - head_r * 0.05, x + head_r * 0.15, hy0 + head_r * 0.25], fill=MARBLE, outline=INK, width=S)

    out = img.resize((W // 2, H // 2), Image.LANCZOS)  # 2x nel file, scale 0.5 nel gioco
    save(out, name)


# --- lo sfondo (#280 passo 3): tre strati a 2x, disegnati in coordinate di mondo ---
# Gli strati sono centrati sul centro dell'arena (960, 360) e larghi 2440×1480 di mondo: l'angolo in alto a sinistra
# è nel mondo a (-260, -380). Più uno strato è lontano, più i colori vanno verso la foschia e l'inchiostro schiarisce.
LW, LH = 2440, 1480
LIFT = (24, 82, 96)  # quanto sale ogni strato (#300; di più dal #378: piano più profondo e il canale dietro): sfondo-0, 1, 2
L_ORIGIN = (960 - LW / 2, 360 - LH / 2)
HAZE = (176, 190, 202, 255)  # la foschia del giorno, verso cui sbiadiscono le cose lontane


LIT = (255, 206, 120, 255)  # luce calda di una finestra accesa
LIT_CORE = (255, 236, 186, 255)  # il centro, più chiaro


def lit_window(lt, pts):
    """Un vetro acceso nell'immagine delle luci (#288): il colore caldo e, dentro, il centro più chiaro."""
    if lt is None:
        return
    lt.poly(pts, fill=LIT)
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    lt.poly([(cx + (x - cx) * 0.55, cy + (y - cy) * 0.55) for x, y in pts], fill=LIT_CORE)


def lit_rect(lt, x0, y0, x1, y1):
    lit_window(lt, [(x0, y0), (x1, y0), (x1, y1), (x0, y1)])


def layer(name, draw, lights=None, lift=0):
    """Uno strato dello sfondo: draw(t) disegna sulla tela in pixel di mondo; il file esce a 2x (art.scale 0.5).
    Con lights, anche l'immagine delle luci della notte (#288): solo i vetri accesi, nello stesso posto.
    lift (#300): di quanti pixel di mondo sale tutto lo strato. Più è lontano, più la sua terra sta in alto, dietro
    il piano dell'isola: così la prospettiva torna. Le y di stages.ts (passanti, traffico, lampioni) salgono uguali."""
    origin = (L_ORIGIN[0], L_ORIGIN[1] + lift)
    t = Tela(LW, LH, origin=origin, ss=1)
    t.lights = Tela(LW, LH, origin=origin, ss=1) if lights else None
    draw(t)
    t.save(OUT, name, colors=256)
    if lights:
        t.lights.save(OUT, lights, colors=64)


def far(col, k):
    """Un colore velato dalla lontananza: k 0 com'è, 1 tutto foschia."""
    return mix(col, HAZE, k)


def skyline(t, base, rng):
    """La città lontana dietro al Prato: tetti a capanna, comignoli, qualche campanile, tutto in foschia."""
    x = -300
    while x < 2200:
        w = rng.randint(50, 120)
        h = rng.randint(24, 60)
        col = far(rng.choice([(150, 120, 100, 255), (160, 140, 118, 255), (140, 128, 116, 255)]), 0.62)
        roof = far((120, 84, 68, 255), 0.6)
        t.rect(x, base - h, x + w, base, fill=col)
        t.poly([(x - 3, base - h), (x + w * 0.5, base - h - rng.randint(8, 16)), (x + w + 3, base - h)], fill=roof)
        for wx in range(int(x + 8), int(x + w - 8), 14):
            t.rect(wx, base - h + 8, wx + 4, base - h + 15, fill=far((70, 66, 64, 255), 0.6))
            if t.lights is not None and rng.random() < 0.3:
                t.lights.rect(wx, base - h + 8, wx + 4, base - h + 15, fill=(230, 190, 120, 255))
        if rng.random() < 0.15:  # un campanile
            tx = x + w * 0.5
            th = rng.randint(110, 160)
            t.rect(tx - 7, base - th, tx + 7, base - h, fill=col)
            t.rect(tx - 5, base - th + 6, tx + 5, base - th + 20, fill=far((70, 66, 64, 255), 0.55))
            t.poly([(tx - 8, base - th), (tx + 8, base - th), (tx, base - th - 26)], fill=roof)
        x += w + rng.randint(-6, 6)


class _Santo:
    """I colori della Basilica del Santo (#296), già velati dalla lontananza: cotto rosso-ocra, piombo grigio-azzurro,
    pietra bianca di logge e balconi, i cappucci rossi delle torrette e l'oro dell'angelo."""

    def __init__(self, k):
        self.brick = far((180, 106, 80, 255), k)
        self.brick_sh = far((142, 80, 66, 255), k)
        self.lead = far((150, 160, 174, 255), k)
        self.lead_sh = far((108, 118, 136, 255), k)
        self.lead_hi = far((196, 204, 212, 255), k)
        self.stone = far((230, 222, 204, 255), k)
        self.red = far((176, 80, 58, 255), k)
        self.gold = far((232, 188, 84, 255), k)
        self.dark = far((62, 44, 46, 255), k)
        self.ink = far((78, 56, 54, 255), k)


def _rect(q, m, x0, y0, x1, y1):
    q.poly(m, [(x0, y0), (x1, y0), (x1, y1), (x0, y1)])
    return m


def _arch(q, m, x0, x1, ys, yb, pointed=False):
    """Un'apertura ad arco nella maschera m: l'arco parte a ys, il fondo è a yb. Tonda o a sesto acuto."""
    from pittura import bezier
    r = (x1 - x0) / 2
    mx = (x0 + x1) / 2
    if pointed:
        top = bezier((x0, ys), (x0, ys - r * 0.9), (mx - r * 0.25, ys - r * 1.45), (mx, ys - r * 1.65), 10)
        top += [(2 * mx - x, y) for x, y in reversed(top)]
    else:
        top = [(mx - math.cos(math.pi * i / 16) * r, ys - math.sin(math.pi * i / 16) * r) for i in range(17)]
    q.poly(m, [(x0, yb), *top, (x1, yb)])
    return m


def _paint(q, m, col, ink, shadow=8.0, grain=0.22, seed=0, rim=True, ow=0.8):
    """Una massa dipinta: colore, grana a pennello, ombra morbida dalla parte opposta alla luce (che viene da
    sinistra in alto, come nel resto dello sfondo), luce sul bordo e contorno a inchiostro."""
    q.fill(m, col)
    if grain:
        q.fill(q.grain(m, grain, seed, 1.3), shade(col, 0.76))
    if shadow:
        q.fill(q.inner_shadow(m, -shadow, 0, shadow * 0.55), shade(col, 0.74), 0.92)
    if rim:
        q.fill(q.rim(m, -1.6, -1.6, 1.2), light(col, 1.16), 0.75)
    if ow:
        q.outline(m, ow, ink)


def _courses(q, m, y0, y1, step, col, opacity):
    """I corsi dei mattoni: righe orizzontali sottili dentro la sagoma, appena accennate."""
    lines = q.mask()
    d = ImageDraw.Draw(lines)
    y = y0
    while y > y1:
        d.line([q._p(q.ox, y), q._p(q.ox + q.w, y)], fill=255, width=max(1, int(q.k * 0.3)))
        y -= step
    q.fill(q.intersect(lines.filter(ImageFilter.GaussianBlur(0.6)), m), col, opacity)


def _cross(q, x, y, size, col):
    """La croce in cima a una lanterna o a una guglia, con la palla sotto."""
    m = q.mask()
    q.ellipse(m, x - size * 0.32, y - size * 0.32, x + size * 0.32, y + size * 0.32)
    q.stroke(m, [(x, y), (x, y - size * 1.5)], size * 0.16)
    q.stroke(m, [(x - size * 0.42, y - size * 1.08), (x + size * 0.42, y - size * 1.08)], size * 0.16)
    q.fill(m, col)


def _angel(q, x, y, C):
    """L'angelo dorato sulla punta del cono: ali aperte, tunica, il braccio alzato. Piccolo, si legge dalla sagoma."""
    from pittura import bezier
    m = q.mask()
    q.poly(m, [(x - 2.2, y), (x + 2.2, y), (x + 1.4, y - 9), (x - 1.4, y - 9)])  # tunica
    q.ellipse(m, x - 1.6, y - 12.4, x + 1.6, y - 9.2)  # testa
    for s in (-1, 1):  # ali
        q.poly(m, [(x, y - 8), *bezier((x + s * 1, y - 9), (x + s * 5, y - 15), (x + s * 8, y - 12), (x + s * 7, y - 6), 8), (x + s * 1.5, y - 5)])
    q.stroke(m, [(x + 1, y - 8), (x + 3.5, y - 15)], 0.9)  # il braccio alzato
    q.fill(m, C.gold)
    q.fill(q.inner_shadow(m, -1.2, 0, 0.8), shade(C.gold, 0.72), 0.9)
    q.outline(m, 0.45, C.ink)


def _dome(q, cx, top, r, h, C, seed, statue=False):
    """Cupola del Santo: tamburo di mattone con le arcatelle e la cornice bianca, calotta di piombo un po' a ogiva
    con le costolature delle lastre, lanterna bianca con il cappuccio e la croce (o la statuina)."""
    from pittura import bezier
    dh, dr = r * 0.4, r * 0.96
    drum = _rect(q, q.mask(), cx - dr, top - dh, cx + dr, top + 2)
    _paint(q, drum, C.brick, C.ink, shadow=dr * 0.55, seed=seed)
    holes = q.mask()
    for i in range(7):  # le arcatelle girano sul cilindro: strette verso i lati
        th = -1.2 + 2.4 * i / 6
        x = cx + math.sin(th) * dr * 0.9
        w = math.cos(th) * dr * 0.085
        _arch(q, holes, x - w, x + w, top - dh * 0.66, top - dh * 0.2)
    q.fill(q.soften(holes, 0.3), C.dark, 0.8)
    trim = _rect(q, q.mask(), cx - dr - 2.5, top - dh - 3, cx + dr + 2.5, top - dh + 1.5)
    _rect(q, trim, cx - dr - 1, top - dh * 0.14, cx + dr + 1, top - dh * 0.02)
    _paint(q, trim, C.stone, C.ink, shadow=dr * 0.5, grain=0, rim=False, ow=0.5)
    # la calotta
    y0 = top - dh - 2
    left = bezier((cx - r, y0), (cx - r * 1.03, y0 - h * 0.6), (cx - r * 0.44, y0 - h * 0.95), (cx, y0 - h), 24)
    shell = q.mask()
    q.poly(shell, left + [(2 * cx - x, y) for x, y in reversed(left)])
    q.fill(shell, C.lead)
    q.fill(q.inner_shadow(shell, -r * 0.85, -h * 0.05, r * 0.45), C.lead_sh, 0.9)
    glow = q.ellipse(q.mask(), cx - r * 0.72, y0 - h * 0.86, cx - r * 0.06, y0 - h * 0.16)
    q.fill(q.intersect(q.soften(glow, r * 0.2), shell), C.lead_hi, 0.75)
    q.fill(q.grain(shell, 0.12, seed + 1, 1.0), C.lead_sh)
    seams, shine = q.mask(), q.mask()
    for k in range(-6, 7):  # le costolature: i meridiani della calotta, fitti verso i lati
        s = math.sin(k / 7 * math.pi / 2)
        pts = [(cx + (cx - x) * s, y) for x, y in left]
        q.stroke(seams, pts, 0.55)
        q.stroke(shine, [(x - 0.9, y) for x, y in pts], 0.5)
    q.fill(q.intersect(q.soften(shine, 0.3), shell), C.lead_hi, 0.45)
    q.fill(q.intersect(q.soften(seams, 0.25), shell), C.lead_sh, 0.9)
    q.outline(shell, 0.75, C.ink)
    # la lanterna
    lb = y0 - h + r * 0.05
    lw, lh = r * 0.13, r * 0.3
    lan = _rect(q, q.mask(), cx - lw, lb - lh, cx + lw, lb)
    _paint(q, lan, C.stone, C.ink, shadow=lw * 0.8, grain=0, rim=False, ow=0.5)
    slits = q.mask()
    for u in (-0.5, 0.0, 0.5):
        _arch(q, slits, cx + u * lw * 1.4 - lw * 0.18, cx + u * lw * 1.4 + lw * 0.18, lb - lh * 0.7, lb - lh * 0.2)
    q.fill(slits, C.dark, 0.85)
    cap = q.mask()
    capl = bezier((cx - lw * 1.15, lb - lh), (cx - lw * 1.2, lb - lh - lw * 1.2), (cx - lw * 0.3, lb - lh - lw * 1.6), (cx, lb - lh - lw * 2.2), 10)
    q.poly(cap, capl + [(2 * cx - x, y) for x, y in reversed(capl)])
    _paint(q, cap, C.lead, C.ink, shadow=lw * 0.9, grain=0, ow=0.5)
    tip = lb - lh - lw * 2.2
    if statue:
        _angel(q, cx, tip + 0.5, C)
    else:
        _cross(q, cx, tip - 0.5, max(3.0, r * 0.11), C.ink)


def _turret(q, x, yb, h, half, C, seed):
    """Una torretta tonda con il cappuccio a cono rosso: ce ne sono tante attorno alle cupole e sulla facciata."""
    from pittura import bezier
    body = _rect(q, q.mask(), x - half, yb - h, x + half, yb)
    _paint(q, body, C.brick, C.ink, shadow=half * 0.75, seed=seed, ow=0.6)
    holes = q.mask()
    _arch(q, holes, x - half * 0.32, x + half * 0.32, yb - h * 0.72, yb - h * 0.42)
    q.fill(holes, C.dark, 0.85)
    ring = _rect(q, q.mask(), x - half - 1.2, yb - h - 1.6, x + half + 1.2, yb - h + 1.2)
    _paint(q, ring, C.stone, C.ink, shadow=half * 0.6, grain=0, rim=False, ow=0.45)
    capl = bezier((x - half * 1.15, yb - h - 1.6), (x - half * 0.9, yb - h - half * 1.4), (x - half * 0.3, yb - h - half * 2.6), (x, yb - h - half * 3.1), 10)
    cap = q.mask()
    q.poly(cap, capl + [(2 * x - px, py) for px, py in reversed(capl)])
    _paint(q, cap, C.red, C.ink, shadow=half * 0.7, seed=seed + 2, ow=0.55)
    _cross(q, x, yb - h - half * 3.1, max(2.2, half * 0.42), C.ink)


def _campanile(q, tx, base, C, seed):
    """Un campanile a minareto: fusto ottagonale di mattone che si stringe a ogni giro, due logge di pietra bianca
    con il balconcino, la cella con le bifore, il tamburino e la guglia con la croce."""
    from pittura import bezier

    def shaft(y0, y1, half):
        m = _rect(q, q.mask(), tx - half, y1, tx + half, y0)
        _paint(q, m, C.brick, C.ink, shadow=half * 0.75, seed=seed + int(y0), ow=0.7)
        _courses(q, m, y0, y1, 3.2, C.brick_sh, 0.35)
        edges = q.mask()
        for s in (-0.42, 0.42):  # gli spigoli dell'ottagono
            q.stroke(edges, [(tx + s * half * 2, y0), (tx + s * half * 2, y1)], 0.55)
        q.fill(q.intersect(edges, m), C.brick_sh, 0.75)
        return m

    def loggia(y0, y1, half):
        """Il giro di loggette: balaustra sotto, archetti con le colonnine bianche, cornice sopra."""
        m = _rect(q, q.mask(), tx - half, y1, tx + half, y0)
        _paint(q, m, C.stone, C.ink, shadow=half * 0.7, grain=0.1, seed=seed, ow=0.6)
        holes = q.mask()
        for i in range(5):
            th = -1.15 + 2.3 * i / 4
            x = tx + math.sin(th) * half * 0.86
            w = math.cos(th) * half * 0.17
            _arch(q, holes, x - w, x + w, y1 + (y0 - y1) * 0.36, y0 - (y0 - y1) * 0.2)
        q.fill(q.soften(holes, 0.3), C.dark, 0.9)
        rail = _rect(q, q.mask(), tx - half - 3.5, y0 - 5, tx + half + 3.5, y0 + 1)
        _rect(q, rail, tx - half - 2.5, y1 - 2.5, tx + half + 2.5, y1 + 1.5)
        _paint(q, rail, C.stone, C.ink, shadow=half * 0.6, grain=0, rim=False, ow=0.55)
        posts = q.mask()
        for i in range(9):  # i balaustrini del balconcino
            x = tx + math.sin(-1.2 + 2.4 * i / 8) * (half + 3)
            _rect(q, posts, x - 0.35, y0 - 4.2, x + 0.35, y0 - 1.2)
        q.fill(posts, C.dark, 0.5)

    shaft(base, base - 236, 15)
    loggia(base - 236, base - 262, 15)
    shaft(base - 262, base - 352, 13)
    loggia(base - 352, base - 376, 13)
    cell = shaft(base - 376, base - 436, 11.5)
    holes = q.mask()  # la cella delle campane: una bifora per faccia
    for u in (-0.9, 0.0, 0.9):
        w = 3.6 * (1 - abs(u) * 0.55)
        x = tx + u * 11.5 * 0.72
        _arch(q, holes, x - w, x + w, base - 424, base - 386)
    q.fill(q.intersect(holes, cell), C.dark, 0.9)
    q.line([(tx, base - 425), (tx, base - 386)], 0.6, C.stone, 0.8)
    rail = _rect(q, q.mask(), tx - 15, base - 442, tx + 15, base - 436)
    _paint(q, rail, C.stone, C.ink, shadow=8, grain=0, rim=False, ow=0.55)
    drum = _rect(q, q.mask(), tx - 9, base - 456, tx + 9, base - 442)
    _paint(q, drum, C.stone, C.ink, shadow=6, grain=0, rim=False, ow=0.5)
    slits = q.mask()
    for u in (-0.55, 0, 0.55):
        _arch(q, slits, tx + u * 9 - 1.3, tx + u * 9 + 1.3, base - 452, base - 445)
    q.fill(slits, C.dark, 0.85)
    left = bezier((tx - 10.5, base - 455), (tx - 9.5, base - 485), (tx - 3, base - 525), (tx, base - 546), 14)
    spire = q.mask()
    q.poly(spire, left + [(2 * tx - x, y) for x, y in reversed(left)])
    _paint(q, spire, C.lead, C.ink, shadow=7, grain=0.1, seed=seed + 5, ow=0.6)
    seams = q.mask()
    for s in (-0.5, 0, 0.5):
        q.stroke(seams, [(tx + (tx - x) * s, y) for x, y in left], 0.45)
    q.fill(q.intersect(seams, spire), C.lead_sh, 0.8)
    _cross(q, tx, base - 547, 5.5, C.ink)


def _cone(q, cx, top, C):
    """Il cono sopra l'altare: tamburo ottagonale con due giri di arcatelle, la punta di piombo a spicchi e la
    lanterna con l'angelo dorato in cima."""
    from pittura import bezier
    w, dh = 44, 46
    drum = _rect(q, q.mask(), cx - w, top - dh, cx + w, top + 2)
    _paint(q, drum, C.brick, C.ink, shadow=w * 0.6, seed=71)
    _courses(q, drum, top, top - dh, 3.2, C.brick_sh, 0.3)
    holes = q.mask()
    for row, (ys, yb, n) in enumerate(((top - dh * 0.55, top - dh * 0.12, 9), (top - dh * 0.84, top - dh * 0.66, 13))):
        for i in range(n):
            th = -1.25 + 2.5 * i / (n - 1)
            x = cx + math.sin(th) * w * 0.9
            hw = math.cos(th) * w * (0.07 if row == 0 else 0.045)
            _arch(q, holes, x - hw, x + hw, ys, yb)
    q.fill(q.soften(holes, 0.3), C.dark, 0.8)
    edges = q.mask()
    for s in (-0.42, 0.42):
        q.stroke(edges, [(cx + s * w * 2, top), (cx + s * w * 2, top - dh)], 0.7)
    q.fill(q.intersect(edges, drum), C.brick_sh, 0.8)
    trim = _rect(q, q.mask(), cx - w - 3, top - dh - 3.5, cx + w + 3, top - dh + 1.5)
    _rect(q, trim, cx - w - 1, top - dh * 0.6, cx + w + 1, top - dh * 0.55)
    _paint(q, trim, C.stone, C.ink, shadow=w * 0.5, grain=0, rim=False, ow=0.55)
    y0, apex = top - dh - 3, top - dh - 196
    left = bezier((cx - w + 1, y0), (cx - w + 4, y0 - 70), (cx - 15, apex + 60), (cx, apex), 24)
    cone = q.mask()
    q.poly(cone, left + [(2 * cx - x, y) for x, y in reversed(left)])
    q.fill(cone, C.lead)
    q.fill(q.inner_shadow(cone, -w * 0.8, 0, w * 0.4), C.lead_sh, 0.9)
    glow = q.poly(q.mask(), [(cx - w * 0.75, y0), (cx - w * 0.15, y0), (cx - 2, apex + 30)])
    q.fill(q.intersect(q.soften(glow, 8), cone), C.lead_hi, 0.6)
    q.fill(q.grain(cone, 0.12, 72, 1.0), C.lead_sh)
    seams, shine = q.mask(), q.mask()
    for k in range(-4, 5):  # gli spicchi dell'ottagono e le lastre in mezzo
        s = math.sin(k / 5 * math.pi / 2)
        pts = [(cx + (cx - x) * s, y) for x, y in left]
        q.stroke(seams, pts, 0.75 if k % 2 == 0 else 0.45)
        q.stroke(shine, [(x - 1.1, y) for x, y in pts], 0.6)
    for j in range(1, 6):  # le giunture orizzontali delle lastre
        yy = y0 - j * (y0 - apex) / 6.5
        hw = next(cx - x for x, y in left if y <= yy)
        q.stroke(seams, [(cx - hw, yy), (cx + hw, yy)], 0.35)
    q.fill(q.intersect(q.soften(shine, 0.3), cone), C.lead_hi, 0.45)
    q.fill(q.intersect(q.soften(seams, 0.25), cone), C.lead_sh, 0.95)
    q.outline(cone, 0.9, C.ink)
    lan = _rect(q, q.mask(), cx - 5.5, apex - 14, cx + 5.5, apex + 3)
    _paint(q, lan, C.stone, C.ink, shadow=4, grain=0, rim=False, ow=0.5)
    sl = q.mask()
    for u in (-0.5, 0.5):
        _arch(q, sl, cx + u * 6 - 1.2, cx + u * 6 + 1.2, apex - 9, apex - 3)
    q.fill(sl, C.dark, 0.85)
    capl = bezier((cx - 6.5, apex - 14), (cx - 6.5, apex - 19), (cx - 2, apex - 22), (cx, apex - 24), 8)
    cap = q.mask()
    q.poly(cap, capl + [(2 * cx - x, y) for x, y in reversed(capl)])
    _paint(q, cap, C.lead, C.ink, shadow=4, grain=0, ow=0.5)
    _angel(q, cx, apex - 23.5, C)


def _gable_edge(q, pts, C, arches=True):
    """Il bordo di un timpano: la copertina di pietra bianca e, sotto, gli archetti pensili lungo la falda."""
    m = q.mask()
    q.stroke(m, pts, 2.6)
    if arches:
        small = q.mask()
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            n = max(1, int(math.hypot(x1 - x0, y1 - y0) / 6.5))
            for i in range(n):
                u0, u1 = i / n, (i + 1) / n
                ax0, ay0 = x0 + (x1 - x0) * u0, y0 + (y1 - y0) * u0
                ax1, ay1 = x0 + (x1 - x0) * u1, y0 + (y1 - y0) * u1
                mx, my = (ax0 + ax1) / 2, (ay0 + ay1) / 2 + 4.5
                q.stroke(small, [(ax0, ay0 + 2), (mx - 1.2, my), (mx + 1.2, my), (ax1, ay1 + 2)], 0.55)
        q.fill(q.soften(small, 0.25), C.brick_sh, 0.85)
    q.fill(m, C.stone)
    q.outline(m, 0.45, C.ink)


def basilica_santo(t, cx, base):
    """La Basilica di Sant'Antonio vista dal Prato (#296, dalle foto di Riccardo): la facciata a capanna di cotto con
    la loggia bianca ad archetti, il rosone e i quattro arconi; le cupole di piombo un po' a ogiva, a costoloni, sui
    tamburi con le arcatelle; il cono sopra l'altare con l'angelo dorato; i due campanili a minareto con i giri di
    loggette; le torrette con il cappuccio rosso. Dipinta con il motore pittorico (pittura.py) in un riquadro e
    incollata nello strato lontano; i colori sono velati dalla lontananza."""
    from pittura import Quadro
    C = _Santo(0.3)
    x0, y0 = cx - 380, base - 600
    q = Quadro(780, 606, origin=(x0, y0), scale=t.k)
    # i campanili, dietro l'abside
    _campanile(q, cx + 172, base, C, 11)
    _campanile(q, cx + 318, base, C, 23)
    # le cupole di dietro, che spuntano tra le altre
    _dome(q, cx + 150, base - 176, 44, 70, C, 31)
    btop = base - 150
    # il corpo della chiesa: il fianco con le lesene, le finestre a sesto acuto e gli archetti sotto la gronda
    body = _rect(q, q.mask(), cx - 330, btop, cx + 352, base)
    _paint(q, body, C.brick, C.ink, shadow=0, seed=41, ow=0.9)
    _courses(q, body, base, btop, 3.4, C.brick_sh, 0.3)
    apse = _rect(q, q.mask(), cx + 240, btop, cx + 352, base)
    q.fill(q.intersect(apse, body), C.brick_sh, 0.45)
    pil, holes, frames = q.mask(), q.mask(), q.mask()
    for i in range(12):
        px = cx - 300 + i * 56
        _rect(q, pil, px - 4, btop + 12, px + 4, base)
        wx = px + 28
        if wx < cx + 340:
            _arch(q, frames, wx - 9, wx + 9, base - 108, base - 56, pointed=True)
            _arch(q, holes, wx - 6.5, wx + 6.5, base - 106, base - 58, pointed=True)
    q.fill(q.intersect(pil, body), light(C.brick, 1.07))
    q.fill(q.intersect(q.inner_shadow(pil, -2.5, 0, 1), body), C.brick_sh, 0.8)
    q.fill(frames, C.stone, 0.85)
    q.fill(holes, C.dark, 0.9)
    _gable_edge(q, [(cx - 330, btop + 1), (cx + 352, btop + 1)], C)
    # le cupole: due sulla navata, il presbiterio e quella piccola dell'abside, con le torrette in mezzo
    _turret(q, cx - 122, btop - 2, 42, 6.5, C, 51)
    _turret(q, cx + 134, btop - 2, 50, 6.5, C, 52)
    _turret(q, cx + 283, btop - 2, 40, 6, C, 53)
    _dome(q, cx - 188, btop, 60, 98, C, 61)
    _dome(q, cx - 58, btop, 64, 104, C, 62)
    _dome(q, cx + 214, btop, 58, 94, C, 63, statue=True)
    _dome(q, cx + 330, btop + 6, 36, 56, C, 64)
    # il cono, dietro la testata del transetto
    _cone(q, cx + 70, btop - 20, C)
    tr = [(cx + 8, btop + 2), (cx + 8, btop - 40), (cx + 70, btop - 82), (cx + 132, btop - 40), (cx + 132, btop + 2)]
    tm = q.poly(q.mask(), tr)
    _paint(q, tm, C.brick, C.ink, shadow=26, seed=81, ow=0.8)
    _courses(q, tm, btop, btop - 82, 3.4, C.brick_sh, 0.3)
    th = q.mask()
    q.ellipse(th, cx + 58, btop - 54, cx + 82, btop - 30)
    q.fill(th, C.stone)
    q.fill(q.ellipse(q.mask(), cx + 61, btop - 51, cx + 79, btop - 33), C.dark, 0.85)
    spokes = q.mask()
    for a in range(8):
        aa = a * math.pi / 4
        q.stroke(spokes, [(cx + 70, btop - 42), (cx + 70 + math.cos(aa) * 9, btop - 42 + math.sin(aa) * 9)], 0.7)
    q.fill(spokes, C.stone, 0.9)
    q.outline(th, 0.45, C.ink)
    _gable_edge(q, tr[1:4], C)
    # la facciata a capanna, davanti a tutto
    fx0, fx1, ftop = cx - 352, cx - 140, base - 312
    mid = (fx0 + fx1) / 2
    eave = base - 214
    fac = q.poly(q.mask(), [(fx0, base), (fx0, eave), (mid, ftop), (fx1, eave), (fx1, base)])
    _paint(q, fac, C.brick, C.ink, shadow=60, seed=91, ow=1.0)
    _courses(q, fac, base, ftop, 3.4, C.brick_sh, 0.32)
    # i quattro arconi ciechi a sesto acuto, con i tre portali e la lunetta dorata in quello di mezzo
    aw = (fx1 - fx0 - 20) / 4
    recess, frames, doors = q.mask(), q.mask(), q.mask()
    for i in range(4):
        ax0 = fx0 + 10 + i * aw
        _arch(q, frames, ax0 + 1, ax0 + aw - 1, base - 98, base, pointed=True)
        _arch(q, recess, ax0 + 4, ax0 + aw - 4, base - 96, base, pointed=True)
    for i, (dw, dh) in enumerate(((14, 54), (20, 70), (20, 70), (14, 54))):
        dx = fx0 + 10 + (i + 0.5) * aw
        if i in (1, 2):  # il portale grande sta tra i due arconi di mezzo
            continue
        _arch(q, doors, dx - dw / 2, dx + dw / 2, base - dh + dw / 2, base)
    _arch(q, doors, mid - 13, mid + 13, base - 62, base)
    q.fill(frames, light(C.brick, 1.08))
    q.fill(recess, shade(C.brick, 0.86))
    q.fill(q.inner_shadow(recess, 3, 3, 2), shade(C.brick, 0.7), 0.9)
    q.fill(doors, C.dark, 0.92)
    lun = _arch(q, q.mask(), mid - 11, mid + 11, base - 63, base - 54)
    q.fill(lun, C.gold, 0.8)
    q.fill(_rect(q, q.mask(), mid - 13, base - 55, mid + 13, base - 52), C.stone)
    # la loggia bianca che attraversa la facciata
    lg0, lg1 = base - 166, base - 140
    band = _rect(q, q.mask(), fx0 + 2, lg0 - 4, fx1 - 2, lg1 + 3)
    _paint(q, band, C.stone, C.ink, shadow=40, grain=0.08, seed=92, rim=False, ow=0.6)
    holes = q.mask()
    n = 17
    lw = (fx1 - fx0 - 12) / n
    for i in range(n):
        ax = fx0 + 6 + i * lw
        _arch(q, holes, ax + 1.6, ax + lw - 1.6, lg0 + 6, lg1 - 1)
    q.fill(q.soften(holes, 0.3), C.dark, 0.88)
    q.fill(_rect(q, q.mask(), fx0 + 2, lg1 - 1, fx1 - 2, lg1 + 0.6), C.ink, 0.5)
    # il timpano: il rosone, due finestrelle e gli archetti lungo le falde
    rx, ry = mid, base - 236
    ros = q.ellipse(q.mask(), rx - 22, ry - 22, rx + 22, ry + 22)
    _paint(q, ros, C.stone, C.ink, shadow=10, grain=0, rim=False, ow=0.6)
    q.fill(q.ellipse(q.mask(), rx - 18, ry - 18, rx + 18, ry + 18), C.dark, 0.9)
    tracery = q.mask()
    q.ellipse(tracery, rx - 5, ry - 5, rx + 5, ry + 5)
    for a in range(16):
        aa = a * math.pi / 8
        q.stroke(tracery, [(rx + math.cos(aa) * 4, ry + math.sin(aa) * 4), (rx + math.cos(aa) * 17, ry + math.sin(aa) * 17)], 0.9)
    ring = q.minus(q.ellipse(q.mask(), rx - 18, ry - 18, rx + 18, ry + 18), q.ellipse(q.mask(), rx - 15.5, ry - 15.5, rx + 15.5, ry + 15.5))
    q.fill(q.union(tracery, ring), C.stone, 0.95)
    small = q.mask()
    for s in (-1, 1):
        _arch(q, small, rx + s * 46 - 4, rx + s * 46 + 4, base - 210, base - 182, pointed=True)
    q.fill(small, C.dark, 0.88)
    _gable_edge(q, [(fx0 - 2, eave), (mid, ftop - 2), (fx1 + 2, eave)], C)
    # i due contrafforti ai lati, con le torrette ottagonali e il cappuccio rosso
    for s, x in ((-1, fx0 + 2), (1, fx1 - 2)):
        but = _rect(q, q.mask(), x - 7, eave - 32, x + 7, base)
        _paint(q, but, C.brick, C.ink, shadow=6, seed=93 + s, ow=0.7)
        _courses(q, but, base, eave - 32, 3.4, C.brick_sh, 0.3)
        _turret(q, x, eave - 32, 22, 6.5, C, 95 + s)
    # in cima al timpano, un tabernacolo con la croce
    _turret(q, mid, ftop + 4, 14, 4.5, C, 99)
    res = q.result()
    t.img.alpha_composite(res, (int(round((x0 - t.ox) * t.k)), int(round((y0 - t.oy) * t.k))))


def sky(t):
    # Il cielo lo disegna il gioco (cielo vivo, #267): qui solo le sagome lontane, su fondo trasparente
    base = 470
    skyline(t, base + 6, rand(5))
    # santa_giustina() a sinistra si toglie (#378, chiesto da Riccardo): con il Santo a destra si confondevano
    basilica_santo(t, 1500, base)


# --- strato dei portici: palazzi del Prato, Loggia Amulea, mercato ---
FACADES = [(178, 146, 104, 255), (182, 136, 118, 255), (192, 178, 150, 255), (164, 112, 90, 255), (150, 146, 126, 255), (170, 128, 98, 255)]
SHUTTERS = [(88, 104, 84, 255), (110, 84, 64, 255), (96, 100, 96, 255)]


def chimney(t, x, base, kind, rng, ink):
    """Un camino padovano (#378, chiesto da Riccardo: più realistico), dal tetto in su: la canna di mattoni a corsi
    con il lato destro in ombra e la conversa di piombo dove esce dalle tegole; in cima la cornice di mattoni che sporge
    e il cappello: due falde di coppi ("coppi"), una lastra di pietra su quattro mattoni con le bocche nere ("lastra")
    o un vaso di terracotta ("vaso"). Sopra la bocca la fuliggine scura."""
    brick, brick_sh = far((150, 96, 76, 255), 0.18), far((112, 70, 58, 255), 0.18)
    mortar = far((176, 156, 140, 255), 0.18)
    hgt = rng.uniform(20, 28)
    w = rng.uniform(4.2, 5.4)
    top = base - hgt
    t.poly([(x - w - 2.5, base + 1), (x + w + 2.5, base + 1), (x + w + 1.5, base - 2), (x - w - 1.5, base - 2)], fill=far((120, 124, 126, 255), 0.18))  # la conversa
    t.rect(x - w, top, x + w, base, fill=brick)
    t.rect(x + w * 0.25, top, x + w, base, fill=brick_sh)
    for k in range(int(hgt / 2.2)):
        yy = base - 2.2 * (k + 1)
        t.line([(x - w, yy), (x + w, yy)], fill=mortar, width=0.35)
        off = 0 if k % 2 else w * 0.5
        for bx in (x - w + off, x + off):
            if x - w < bx < x + w:
                t.line([(bx, yy), (bx, yy + 2.2)], fill=mortar, width=0.3)
    t.rect(x - w, top, x + w, base, ink=True, width=0.7, ink_col=ink)
    t.rect(x - w - 1.4, top - 2.4, x + w + 1.4, top, fill=brick, ink=True, width=0.6, ink_col=ink)  # la cornice
    t.rect(x + w * 0.3, top - 2.4, x + w + 1.4, top, fill=brick_sh)
    if kind == "coppi":  # due falde di coppi su quattro pilastrini, con le bocche nere sotto
        t.rect(x - w + 0.6, top - 6, x + w - 0.6, top - 2.4, fill=far((40, 34, 32, 255), 0.18))
        for px in (x - w + 0.6, x + w - 2):
            t.rect(px, top - 6, px + 1.4, top - 2.4, fill=brick)
        roof = far((156, 92, 70, 255), 0.18)
        t.poly([(x - w - 2.4, top - 5.4), (x, top - 10.5), (x + w + 2.4, top - 5.4)], fill=roof, ink=True, width=0.6, ink_col=ink)
        t.poly([(x, top - 10.5), (x + w + 2.4, top - 5.4), (x + 0.6, top - 5.4)], fill=shade(roof, 0.78))
        for k in range(1, 4):
            u = k / 4
            t.line([(x - (w + 2.4) * u, top - 10.5 + 5.1 * u), (x - (w + 2.4) * u, top - 5.4)], fill=shade(roof, 0.8), width=0.35)
    elif kind == "lastra":
        t.rect(x - w + 0.6, top - 5, x + w - 0.6, top - 2.4, fill=far((36, 30, 30, 255), 0.18))
        for px in (x - w + 0.6, x - 0.7, x + w - 2):
            t.rect(px, top - 5, px + 1.4, top - 2.4, fill=brick)
        t.rect(x - w - 2, top - 6.4, x + w + 2, top - 5, fill=far((200, 194, 180, 255), 0.18), ink=True, width=0.5, ink_col=ink)
    else:  # il vaso di terracotta che si stringe in cima
        pot = far((176, 108, 80, 255), 0.18)
        t.poly([(x - 2.6, top - 2.4), (x + 2.6, top - 2.4), (x + 1.6, top - 8), (x - 1.6, top - 8)], fill=pot, ink=True, width=0.5, ink_col=ink)
        t.poly([(x + 0.6, top - 2.4), (x + 2.6, top - 2.4), (x + 1.6, top - 8), (x + 0.4, top - 8)], fill=shade(pot, 0.8))
        t.rect(x - 2, top - 9, x + 2, top - 8, fill=pot, ink=True, width=0.4, ink_col=ink)
    t.glaze([(x - w, top - 1), (x + w, top - 1), (x + w * 0.6, top + 4), (x - w * 0.4, top + 3)], (30, 26, 24, 70))  # la fuliggine


def _facade_paint(t, x, w, top, wall_bot, holes, col, rng):
    """L'intonaco dipinto di una casa sopra i portici (#378, chiesto da Riccardo: case con più texture): la luce da
    sinistra che scurisce piano verso destra senza strisce, le chiazze grandi e la grana fine del marmorino, le colature
    scure sotto i davanzali e sotto il cornicione, qualche pezzo d'intonaco caduto con i mattoni sotto, a volte il
    bugnato agli spigoli e il pluviale di rame. holes sono i rettangoli delle finestre, che restano puliti."""
    from pittura import Quadro
    h = wall_bot - top
    q = Quadro(w, h, origin=(x, top), scale=t.k, ss=1)
    wall = q.poly(q.mask(), [(x, top), (x + w, top), (x + w, wall_bot), (x, wall_bot)])
    hm = q.mask()
    for hx0, hy0, hx1, hy1 in holes:
        q.poly(hm, [(hx0, hy0), (hx1, hy0), (hx1, hy1), (hx0, hy1)])
    wm = q.minus(wall, hm)
    seed = rng.randrange(1 << 20)
    # il volume: dalla luce a sinistra all'ombra a destra, una rampa continua
    ramp = Image.linear_gradient("L").rotate(90, expand=True).transpose(Image.FLIP_LEFT_RIGHT).resize(q.size)
    q.fill(q.intersect(ramp, wall), (30, 26, 34), 0.3)
    # le chiazze e la grana dell'intonaco
    q.fill(q.grain(wm, 0.55, seed, 11), shade(col, 0.8), 0.28)
    q.fill(q.grain(wm, 0.5, seed + 1, 6), light(col, 1.12), 0.26)
    q.fill(q.grain(wm, 0.7, seed + 2, 0.9), shade(col, 0.82), 0.3)
    # le colature: sotto i davanzali e giù dal cornicione, dove l'acqua ha lavato il muro
    streaks = q.mask()
    for hx0, hy0, hx1, hy1 in holes:
        for _ in range(2):
            sx = rng.uniform(hx0 + 2, hx1 - 2)
            q.stroke(streaks, [(sx, hy1), (sx + rng.uniform(-0.6, 0.6), hy1 + rng.uniform(6, 18))], rng.uniform(1.6, 3.2))
    for _ in range(int(w / 9)):
        sx = rng.uniform(x + 2, x + w - 2)
        q.stroke(streaks, [(sx, top), (sx + rng.uniform(-1, 1), top + rng.uniform(8, 34))], rng.uniform(1.4, 4.0))
    q.fill(q.intersect(q.soften(streaks, 1.6), wm), (60, 54, 50), 0.22)
    # l'intonaco caduto: i mattoni sotto, l'orlo rotto in luce e la sua ombra
    for _ in range(rng.choice((0, 1, 1, 2))):
        px, py = rng.uniform(x + 12, x + w - 30), rng.uniform(top + 16, wall_bot - 20)
        blob = q.mask()
        for _k in range(4):
            bx, by = px + rng.uniform(0, 18), py + rng.uniform(0, 9)
            q.ellipse(blob, bx - rng.uniform(4, 9), by - rng.uniform(3, 6), bx + rng.uniform(4, 9), by + rng.uniform(3, 6))
        blob = q.intersect(q.smooth(blob, 1.2), wm)
        q.fill(blob, far((150, 96, 78, 255), 0.22))
        courses = q.mask()
        for k in range(14):
            yy = py - 8 + k * 2.4
            q.stroke(courses, [(px - 12, yy), (px + 40, yy)], 0.35)
            off = 0 if k % 2 else 2.6
            for bx in range(int(px - 12 + off), int(px + 40), 5):
                q.stroke(courses, [(bx, yy), (bx, yy + 2.4)], 0.3)
        q.fill(q.intersect(courses, blob), far((196, 176, 156, 255), 0.22), 0.8)
        q.fill(q.inner_shadow(blob, 1.2, 1.2, 0.8), (40, 30, 28), 0.6)  # l'orlo dell'intonaco fa ombra sui mattoni
        rim = q.minus(q.soften(blob, 0.9).point(lambda v: 255 if v > 20 else 0), blob)
        q.fill(q.intersect(rim, wm), light(col, 1.2), 0.7)
    # il bugnato d'angolo: conci chiari alternati, lunghi e corti, con la loro ombra
    if rng.random() < 0.5:
        stone = far((206, 198, 182, 255), 0.2)
        blocks, joints = q.mask(), q.mask()
        k = 0
        yy = wall_bot
        while yy > top + 4:
            for edge, sgn in ((x, 1), (x + w, -1)):
                ln = 11 if k % 2 else 7
                q.poly(blocks, [(edge, yy - 8), (edge + sgn * ln, yy - 8), (edge + sgn * ln, yy), (edge, yy)])
                q.stroke(joints, [(edge, yy - 0.3), (edge + sgn * ln, yy - 0.3)], 0.6)
                q.stroke(joints, [(edge + sgn * ln, yy - 8), (edge + sgn * ln, yy)], 0.6)
            yy -= 8
            k += 1
        blocks = q.intersect(blocks, wall)
        q.fill(blocks, stone, 0.92)
        q.fill(q.intersect(q.grain(blocks, 0.6, seed + 3, 1.2), blocks), shade(stone, 0.85), 0.4)
        q.fill(q.intersect(joints, blocks), (90, 84, 76), 0.8)
    # il pluviale di rame verde che scende dalla gronda
    if rng.random() < 0.6:
        px = x + w - rng.uniform(4, 8) if rng.random() < 0.6 else x + rng.uniform(4, 8)
        pipe = q.stroke(q.mask(), [(px, top), (px, wall_bot)], 1.6)
        q.fill(q.shift(q.soften(pipe, 0.8), 1.2, 0), (30, 26, 24), 0.35)
        q.fill(pipe, far((104, 124, 112, 255), 0.18))
        q.fill(q.stroke(q.mask(), [(px - 0.4, top), (px - 0.4, wall_bot)], 0.4), far((150, 172, 158, 255), 0.18), 0.8)
        for yy in range(int(top + 14), int(wall_bot), 26):
            q.fill(q.stroke(q.mask(), [(px - 1.6, yy), (px + 1.6, yy)], 0.7), (60, 56, 52))
    dx, dy = int(round((x - t.ox) * t.k)), int(round((top - t.oy) * t.k))
    img = q.img
    if dx < 0:
        img, dx = img.crop((-dx, 0, img.size[0], img.size[1])), 0
    t.img.alpha_composite(img, dest=(dx, dy))


def portico_house(t, x, w, base, rng):
    """Un palazzo sopra i portici: archi con le colonne, piani con le finestre e le persiane, qualche balconcino
    in ferro, marcapiani, cornicione con le mensole, tetto di coppi, camini a imbuto e qualche antenna."""
    floors = rng.randint(3, 4)
    fh = rng.randint(40, 46)
    top = base - 62 - floors * fh
    col = far(rng.choice(FACADES), 0.26)  # più velati del palazzo al centro, che è il soggetto
    sh = shade(col, 0.86)
    ink = (52, 46, 44, 255)
    stone = far((196, 188, 172, 255), 0.18)
    t.rect(x, top, x + w, base, fill=col)
    # portico: colonne, archi bui, la lanterna, qualche tenda
    t.rect(x, base - 62, x + w, base, fill=sh)
    n = max(2, int(w / 34))
    aw = w / n
    for k in range(n):
        ax = x + k * aw
        t.rect(ax + 4, base - 44, ax + aw - 4, base, fill=(46, 42, 40, 255))
        t.pieslice(ax + 4, base - 58, ax + aw - 4, base - 30, 180, 360, fill=(46, 42, 40, 255))
        # la profondità del portico (#378): in fondo il muro con la porta, un po' più chiaro, e la volta in ombra
        t.rect(ax + 9, base - 34, ax + aw - 9, base, fill=(70, 64, 58, 255))
        t.rect(ax + aw / 2 - 4, base - 22, ax + aw / 2 + 4, base, fill=(40, 36, 34, 255))
        t.glaze([(ax + 4, base), (ax + 9, base - 2), (ax + 9, base - 34), (ax + 4, base - 44)], (90, 84, 76, 120))  # lo sguancio in luce
        t.rect(ax + 4, base - 3, ax + aw - 4, base, fill=(84, 78, 70, 255))  # il pavimento del portico
        t.rect(ax - 2, base - 50, ax + 4, base, fill=stone)  # colonna
        t.rect(ax - 2, base - 50, ax - 0.5, base, fill=light(stone, 1.1))  # la colonna è tonda: luce a sinistra
        t.rect(ax + 2, base - 50, ax + 4, base, fill=shade(stone, 0.8))  # e ombra a destra
        t.rect(ax - 4, base - 52, ax + 6, base - 48, fill=stone)  # capitello
        t.rect(ax - 4, base - 49, ax + 6, base - 48, fill=shade(stone, 0.8))
        if rng.random() < 0.25:  # tenda a strisce sopra l'arco
            tc = far(rng.choice([(150, 120, 92, 255), (120, 124, 112, 255), (160, 150, 130, 255)]), 0.15)
            t.poly([(ax + 4, base - 50), (ax + aw - 4, base - 50), (ax + aw, base - 40), (ax, base - 40)], fill=tc)
            for s_ in range(1, 4):
                sx = ax + 4 + s_ * (aw - 8) / 4
                t.line([(sx, base - 50), (sx + (s_ - 2) * 1.5, base - 40)], fill=shade(tc, 0.8), width=1.4)
        elif rng.random() < 0.3:
            t.line([(ax + aw / 2, base - 44), (ax + aw / 2, base - 38)], fill=ink, width=0.6)
            t.rect(ax + aw / 2 - 2.5, base - 38, ax + aw / 2 + 2.5, base - 32, fill=(160, 146, 108, 255))
            if t.lights is not None:  # la lanterna del portico accesa e il suo alone sotto l'arco
                t.lights.ellipse(ax + 6, base - 46, ax + aw - 6, base - 6, fill=(150, 110, 60, 255))
                lit_rect(t.lights, ax + aw / 2 - 2.5, base - 38, ax + aw / 2 + 2.5, base - 32)
    t.line([(x, base - 62), (x + w, base - 62)], fill=ink, width=1.0)
    # i piani
    win = rng.choice(SHUTTERS)
    holes = []  # le finestre con le persiane: l'intonaco dipinto dopo non ci va sopra
    glass = far((150, 170, 180, 255), 0.2)
    frame_col = far((214, 208, 196, 255), 0.18)

    def slats(x0, y0, x1, y1, c):  # le stecche delle persiane
        yy = y0 + 1.6
        while yy < y1 - 0.8:
            t.line([(x0 + 0.5, yy), (x1 - 0.5, yy)], fill=shade(c, 0.72), width=0.45)
            yy += 2.0

    for f in range(floors):
        fy = base - 62 - (f + 1) * fh
        cols = max(2, int((w - 20) / 30))
        step = (w - 20) / cols
        for c in range(cols):
            wx = x + 10 + c * step + step / 2 - 6
            holes.append((wx - 5, fy + 3, wx + 17, fy + fh - 3))
            if f == 0 and rng.random() < 0.5:  # piano nobile: finestra ad arco con il balconcino in ferro
                t.rect(wx, fy + 10, wx + 12, fy + fh - 6, fill=(54, 54, 56, 255))
                if rng.random() < 0.45:
                    lit_window(t.lights, [(wx, fy + fh - 6), (wx, fy + 10), (wx + 6, fy + 4), (wx + 12, fy + 10), (wx + 12, fy + fh - 6)])
                t.pieslice(wx, fy + 4, wx + 12, fy + 16, 180, 360, fill=(54, 54, 56, 255))
                t.rect(wx - 3, fy + fh - 6, wx + 15, fy + fh - 4, fill=stone)
                for b in range(4):
                    t.line([(wx - 2 + b * 5.3, fy + fh - 14), (wx - 2 + b * 5.3, fy + fh - 6)], fill=ink, width=0.6)
                t.line([(wx - 3, fy + fh - 14), (wx + 15, fy + fh - 14)], fill=ink, width=0.8)
            else:
                t.rect(wx, fy + 10, wx + 12, fy + fh - 8, fill=(56, 56, 58, 255))
                # la finestra è incassata nel muro (#378): l'ombra dello sguancio a sinistra e in alto, la luce a destra
                t.rect(wx, fy + 10, wx + 2.2, fy + fh - 8, fill=(36, 36, 38, 255))
                t.rect(wx, fy + 10, wx + 12, fy + 12.4, fill=(36, 36, 38, 255))
                t.rect(wx + 10.6, fy + 12, wx + 12, fy + fh - 8, fill=(84, 84, 86, 255))
                # i vetri (#378): il telaio chiaro a croce e il riflesso del cielo di sbieco
                gy0, gy1 = fy + 12.4, fy + fh - 8
                t.glaze([(wx + 2.2, gy0 + (gy1 - gy0) * 0.15), (wx + 7, gy0), (wx + 10.6, gy0), (wx + 2.2, gy1 - (gy1 - gy0) * 0.25)], (*glass[:3], 70))
                t.line([(wx + 6.4, gy0), (wx + 6.4, gy1)], fill=frame_col, width=0.7)
                t.line([(wx + 2.2, gy0 + (gy1 - gy0) * 0.38), (wx + 10.6, gy0 + (gy1 - gy0) * 0.38)], fill=frame_col, width=0.6)
                t.rect(wx + 2.2, gy0, wx + 10.6, gy1, ink=True, width=0.5, ink_col=frame_col)
                if rng.random() < 0.35:
                    lit_rect(t.lights, wx + 1, fy + 11, wx + 11, fy + fh - 9)
                if rng.random() < 0.7:  # persiane aperte, a volte una chiusa
                    if rng.random() < 0.2:
                        t.rect(wx, fy + 10, wx + 12, fy + fh - 8, fill=far(win, 0.15))
                        slats(wx, fy + 10, wx + 12, fy + fh - 8, far(win, 0.15))
                        t.line([(wx + 6, fy + 10), (wx + 6, fy + fh - 8)], fill=shade(far(win, 0.15), 0.6), width=0.6)
                    else:
                        t.rect(wx - 5, fy + 10, wx, fy + fh - 8, fill=far(win, 0.15))
                        t.rect(wx + 12, fy + 10, wx + 17, fy + fh - 8, fill=far(shade(win, 0.85), 0.15))
                        slats(wx - 5, fy + 10, wx, fy + fh - 8, far(win, 0.15))
                        slats(wx + 12, fy + 10, wx + 17, fy + fh - 8, far(shade(win, 0.85), 0.15))
                t.rect(wx - 2, fy + 8, wx + 14, fy + 10, fill=stone)
                t.rect(wx - 2, fy + fh - 8, wx + 14, fy + fh - 6, fill=stone)
                t.glaze([(wx - 1, fy + fh - 6), (wx + 15, fy + fh - 6), (wx + 16, fy + fh - 3.5), (wx, fy + fh - 3.5)], (30, 26, 24, 70))  # l'ombra del davanzale
        t.line([(x, fy), (x + w, fy)], fill=light(col, 1.08), width=1.0)  # marcapiano: il filo in luce...
        t.glaze([(x, fy + 0.6), (x + w, fy + 0.6), (x + w, fy + 3.6), (x, fy + 3.6)], (30, 26, 24, 55))  # ...e l'ombra sotto
    # il volume (#378): la luce viene da sinistra, quindi la facciata scurisce piano verso destra; il cornicione getta
    # un'ombra larga sotto di sé, e al piede il portico è più scuro (la luce non ci arriva)
    _facade_paint(t, x, w, top, base - 62, holes, col, rng)
    t.glaze([(x, top), (x + w, top), (x + w, top + 12), (x, top + 12)], (30, 26, 24, 80))
    t.glaze([(x, top), (x + w, top), (x + w, top + 5), (x, top + 5)], (30, 26, 24, 60))
    t.glaze([(x, base - 62), (x + w, base - 62), (x + w, base - 56), (x, base - 56)], (20, 18, 16, 70))
    t.glaze([(x, base - 8), (x + w, base - 8), (x + w, base), (x, base)], (20, 18, 16, 60))
    # l'ombra a destra e il contorno
    t.rect(x + w - 6, top, x + w, base - 62, fill=sh)
    t.rect(x, top, x + w, base, ink=True, width=1.0, ink_col=ink)
    # cornicione con le mensole e il tetto di coppi
    t.rect(x - 5, top - 8, x + w + 5, top, fill=stone, ink=True, width=0.9, ink_col=ink)
    for mx in range(int(x), int(x + w), 9):
        t.rect(mx, top, mx + 3, top + 3, fill=shade(stone, 0.85))
    roof = far((122, 84, 68, 255), 0.18)
    t.poly([(x - 6, top - 8), (x + w + 6, top - 8), (x + w - 10, top - 22), (x + 10, top - 22)], fill=roof, ink=True, width=0.9, ink_col=ink)
    t.poly([(x + w + 6, top - 8), (x + w - 10, top - 22), (x + w - 30, top - 22), (x + w - 14, top - 8)], fill=shade(roof, 0.8))  # la falda di lato in ombra
    # i coppi a file (#378): i canali che scendono verso la gronda, le file sfalsate, qualche coppo più scuro o
    # più chiaro e il muschio verso la gronda
    for k in range(int((w + 12) / 4.5)):
        xb = x - 6 + k * 4.5
        xt = x + 10 + (xb - (x - 6)) * (w - 20) / (w + 12)
        t.line([(xt, top - 22), (xb, top - 8)], fill=shade(roof, 0.8), width=0.55)
    for r_ in range(1, 5):
        yy = top - 22 + r_ * 2.8
        u = r_ * 2.8 / 14
        xl, xr = x + 10 - 16 * u, x + w - 10 + 16 * u
        for k in range(int((xr - xl) / 4.5)):
            xa = xl + k * 4.5 + (2.2 if r_ % 2 else 0)
            t.arc(xa, yy - 1.6, xa + 4.5, yy + 1.6, 0, 180, fill=shade(roof, 0.84), width=0.45)
    for _ in range(int(w / 10)):
        rx_, ry_ = rng.uniform(x + 6, x + w - 6), rng.uniform(top - 20, top - 10)
        t.rect(rx_, ry_, rx_ + 3.6, ry_ + 2.4, fill=rng.choice((shade(roof, 0.75), light(roof, 1.12), far((116, 112, 80, 255), 0.25))))
    t.glaze([(x - 6, top - 8), (x + w + 6, top - 8), (x + w - 2, top - 12), (x + 2, top - 12)], (92, 98, 70, 60))  # il muschio sulla gronda
    t.glaze([(x - 5, top - 2), (x + w + 5, top - 2), (x + w + 5, top), (x - 5, top)], (20, 18, 16, 90))  # il sottogronda
    for cxm in (x + w * 0.22, x + w * 0.72):
        if rng.random() < 0.8:
            chimney(t, cxm, top - 18, rng.choice(("coppi", "coppi", "lastra", "vaso")), rng, ink)
    if rng.random() < 0.4:  # un'antenna
        ax = x + w * rng.uniform(0.3, 0.6)
        t.line([(ax, top - 22), (ax, top - 60)], fill=ink, width=0.8)
        for k in range(3):
            t.line([(ax - 8 + k * 2, top - 54 + k * 6), (ax + 8 - k * 2, top - 54 + k * 6)], fill=ink, width=0.7)


def loggia_amulea(t, lx, base):
    """La Loggia Amulea: mattone rosso spento, due ordini di archi gotici con le colonnine bianche,
    la balaustra del primo piano e la merlatura a coda di rondine."""
    ink = (52, 38, 34, 255)
    brick, brick_s, white = far((128, 82, 68, 255), 0.15), far((108, 68, 58, 255), 0.15), far((196, 188, 172, 255), 0.15)
    top = base - 270
    t.rect(lx, top, lx + 340, base, fill=brick)
    t.rect(lx + 250, top, lx + 340, base, fill=brick_s)
    for row in range(int(270 / 6)):  # corsi di mattoni appena accennati
        t.line([(lx, top + row * 6), (lx + 340, top + row * 6)], fill=shade(brick, 0.93), width=0.5)
    for (y0, y1) in ((top + 34, top + 128), (base - 112, base)):
        for i in range(7):
            ax = lx + 12 + i * 46
            t.rect(ax - 6, y0 - 6, ax - 1, y1, fill=white)  # pilastrini a strisce bianche e rosse
            for k in range(int((y1 - y0) / 12)):
                t.rect(ax - 6, y0 + k * 12, ax - 1, y0 + k * 12 + 5, fill=brick_s)
            t.rect(ax, y0 + 22, ax + 34, y1, fill=(62, 42, 38, 255))
            t.poly([(ax, y0 + 22), (ax + 17, y0), (ax + 34, y0 + 22)], fill=(62, 42, 38, 255))
            t.arc(ax - 3, y0 - 3, ax + 37, y0 + 42, 200, 340, fill=white, width=2.0)
            t.rect(ax + 15.5, y0 + 18, ax + 18.5, y1, fill=white)  # colonnina in mezzo
        t.rect(lx + 2, y1 - 2, lx + 338, y1, fill=brick_s)
    t.rect(lx, top + 128, lx + 340, top + 140, fill=white)  # balaustra del primo piano
    for i in range(34):
        t.rect(lx + 4 + i * 10, top + 130, lx + 7 + i * 10, top + 138, fill=brick_s)
    t.rect(lx - 6, top - 14, lx + 346, top, fill=white, ink=True, width=1.0, ink_col=ink)
    for i in range(22):  # merli a coda di rondine
        mx = lx - 4 + i * 16
        t.poly([(mx, top - 14), (mx, top - 30), (mx + 4, top - 26), (mx + 8, top - 30), (mx + 8, top - 14)], fill=white, ink=True, width=0.8, ink_col=ink)
    t.rect(lx, top, lx + 340, base, ink=True, width=1.2, ink_col=ink)


def market(t, x0, base, rng):
    """Il mercato davanti ai portici: banchi con le tende a strisce spente e le cassette."""
    for i, mx in enumerate(range(int(x0), int(x0) + 520, 74)):
        tc = far(rng.choice([(176, 170, 158, 255), (150, 156, 148, 255), (166, 148, 130, 255)]), 0.12)
        t.poly([(mx - 2, base - 40), (mx + 34, base - 66), (mx + 70, base - 40)], fill=tc, ink=True, width=0.9, ink_col=(60, 56, 52, 255))
        for k in range(1, 4):
            t.line([(mx + 34, base - 66), (mx - 2 + k * 18, base - 40)], fill=shade(tc, 0.82), width=1.2)
        t.rect(mx + 4, base - 40, mx + 64, base - 10, fill=(84, 78, 70, 255))
        t.rect(mx + 2, base - 24, mx + 66, base - 20, fill=(120, 100, 80, 255))
        for b in range(4):  # cassette di verdura
            bx = mx + 6 + b * 15
            t.rect(bx, base - 32, bx + 13, base - 24, fill=(132, 108, 80, 255))
            for f in range(3):
                t.circle(bx + 2.5 + f * 4, base - 33, 2.4, fill=far(rng.choice([(150, 120, 80, 255), (120, 130, 96, 255), (164, 104, 80, 255), (176, 156, 96, 255)]), 0.15))


def buildings(t):
    base = 540
    rng = rand(3)
    x = -300
    while x < 2200:
        w = rng.randint(130, 220)
        portico_house(t, x, w, base, rng)
        x += w
    loggia_amulea(t, 520, base)
    market(t, 1420, base, rng)


# --- strato del prato: platani, lampioni, panchine, la seconda fila di statue, la riva lontana ---
def paint_tree(q, x, base, r, seed, haze=0.0, th=None):
    """Un platano dipinto (#378: niente dischi piatti), in un pittura.Quadro: il tronco chiaro a chiazze che si apre in
    rami, la chioma fatta di ciuffi che si fondono in una sagoma sola, ogni ciuffo con la sua luce in alto a sinistra e
    l'ombra in basso a destra, l'ombra grande della chioma su sé stessa, qualche buco dove passa il cielo e la grana
    delle foglie. r è il raggio della chioma, base il piede del tronco; haze vela tutto verso la foschia."""
    rng = random.Random(seed)
    th = th if th is not None else r * 1.3
    def c(col):
        return far(col + (255,), haze)[:3]
    ink = c((34, 42, 32))
    bark, bark_s, bark_l = c((168, 162, 138)), c((124, 120, 102)), c((204, 200, 176))
    # tronco e rami
    trunk = q.mask()
    q.poly(trunk, [(x - r * 0.13, base), (x - r * 0.08, base - th * 0.5), (x - r * 0.07, base - th), (x + r * 0.07, base - th), (x + r * 0.08, base - th * 0.5), (x + r * 0.14, base)])
    for sx, ex, ey, wdt in ((-0.02, -0.55, -0.35, 0.07), (0.02, 0.6, -0.4, 0.07), (0.0, -0.1, -0.75, 0.06), (0.0, 0.25, -0.65, 0.05)):
        q.stroke(trunk, [(x + r * sx, base - th * 0.9), (x + r * ex * 0.5, base - th - r * 0.2), (x + r * ex, base - th + r * ey)], r * wdt)
    q.fill(trunk, bark)
    q.fill(q.inner_shadow(trunk, -r * 0.08, 0, r * 0.04), bark_s, 0.9)
    q.fill(q.grain(trunk, 0.6, seed, max(1.2, r * 0.05)), bark_l, 0.7)  # la corteccia che si stacca a chiazze
    q.outline(trunk, max(0.5, r * 0.012), ink)
    # la chioma: tanti ciuffi su un'ellisse, che si fondono in una sagoma sola dal bordo mosso
    cy = base - th - r * 0.5
    tufts = []
    for k in range(18):
        a = rng.uniform(0, math.tau)
        d = rng.random() ** 0.5
        tufts.append((x + math.cos(a) * r * 0.8 * d, cy + math.sin(a) * r * 0.55 * d, r * rng.uniform(0.28, 0.4)))
    crown = q.mask()
    for tx, ty, tr in tufts:
        q.ellipse(crown, tx - tr, ty - tr * 0.85, tx + tr, ty + tr * 0.85)
    q.ellipse(crown, x - r * 0.55, cy - r * 0.35, x + r * 0.55, cy + r * 0.35)  # il cuore pieno: niente buchi in mezzo
    crown = q.smooth(crown, r * 0.03)
    q.fill(crown, c((36, 54, 36)))
    # ogni ciuffo è un volume: la parte in alto a sinistra presa dal sole, sfumata, quella sotto resta in ombra
    for tx, ty, tr in sorted(tufts, key=lambda tt: tt[1]):
        lit = q.ellipse(q.mask(), tx - tr * 0.95, ty - tr * 0.8, tx + tr * 0.55, ty + tr * 0.35)
        q.fill(q.intersect(q.soften(lit, tr * 0.14), crown), c((84, 114, 64)), 0.92)
        hi = q.ellipse(q.mask(), tx - tr * 0.7, ty - tr * 0.65, tx + tr * 0.05, ty - tr * 0.05)
        q.fill(q.intersect(q.soften(hi, tr * 0.12), crown), c((132, 160, 92)), 0.7)
    q.fill(q.inner_shadow(crown, -r * 0.5, -r * 0.4, r * 0.32), c((28, 42, 28)), 0.7)  # l'ombra grande della chioma
    q.fill(q.grain(crown, 0.55, seed + 1, max(1.0, r * 0.035)), c((40, 60, 38)), 0.7)  # la grana delle foglie
    # i rami che si intravedono nella parte bassa della chioma, in ombra
    twigs = q.mask()
    for k in range(6):
        sx = x + rng.uniform(-0.5, 0.5) * r
        sy = cy + r * rng.uniform(0.1, 0.45)
        q.stroke(twigs, [(x, base - th), (sx, sy)], max(0.6, r * 0.022))
    q.fill(q.intersect(twigs, crown), c((70, 64, 52)), 0.85)
    q.outline(crown, max(0.5, r * 0.014), ink)


def plane_tree(t, x, base, r, rng):
    """Un platano lontano dello strato del prato, dipinto con paint_tree e incollato nella tela."""
    from pittura import Quadro
    th = r * 1.3
    x0, y0 = x - r * 1.15, base - th - r * 1.3
    w, h = r * 2.3, th + r * 1.42
    q = Quadro(w, h, origin=(x0, y0), scale=t.k)
    paint_tree(q, x, base, r, rng.randint(0, 99999), 0.12)
    t.img.alpha_composite(q.result(), (int(round((x0 - t.ox) * t.k)), int(round((y0 - t.oy) * t.k))))


def lamp(t, x, base, h):
    """Il lampione del Prato: palo di ghisa con lo zoccolo e la lanterna a quattro vetri col cappello."""
    ink = (36, 36, 38, 255)
    iron = (58, 58, 60, 255)
    t.rect(x - 6, base - 10, x + 6, base, fill=iron, ink=True, width=0.8, ink_col=ink)
    t.poly([(x - 2.4, base - 10), (x + 2.4, base - 10), (x + 1.6, base - h), (x - 1.6, base - h)], fill=iron)
    for k in range(3):
        t.rect(x - 3.4, base - 24 - k * 26, x + 3.4, base - 21 - k * 26, fill=iron)
    t.poly([(x - 8, base - h), (x + 8, base - h), (x + 10, base - h - 18), (x - 10, base - h - 18)], fill=(176, 166, 128, 255), ink=True, width=0.9, ink_col=ink)
    lit_window(getattr(t, "lights", None), [(x - 7, base - h - 1), (x + 7, base - h - 1), (x + 9, base - h - 17), (x - 9, base - h - 17)])
    t.line([(x, base - h), (x, base - h - 18)], fill=ink, width=0.7)
    t.poly([(x - 12, base - h - 18), (x + 12, base - h - 18), (x, base - h - 30)], fill=iron, ink=True, width=0.8, ink_col=ink)
    t.circle(x, base - h - 31, 2, fill=iron)


def small_statue(t, x, base, rng):
    """Una statua della seconda fila, più lontana: piedistallo con la cornice e una figura in posa."""
    m, sh, ink = (164, 160, 148, 255), (138, 134, 124, 255), (76, 74, 70, 255)
    t.rect(x - 11, base - 34, x + 11, base, fill=m, ink=True, width=0.8, ink_col=ink)
    t.rect(x + 3, base - 34, x + 11, base, fill=sh)
    t.rect(x - 14, base - 40, x + 14, base - 34, fill=m, ink=True, width=0.8, ink_col=ink)
    t.rect(x - 14, base - 4, x + 14, base, fill=m, ink=True, width=0.8, ink_col=ink)
    pose = rng.random()
    body = [(x - 8, base - 40), (x + 8, base - 40), (x + 5, base - 72), (x + 6, base - 82), (x - 6, base - 82), (x - 5, base - 72)]
    t.poly(body, fill=m)
    t.poly([(x + 1, base - 40), (x + 8, base - 40), (x + 5, base - 72), (x + 6, base - 82), (x + 1, base - 82)], fill=sh)
    t.poly(body, ink=True, width=0.8, ink_col=ink)
    t.circle(x, base - 88, 5.5, fill=m, ink=True, width=0.8, ink_col=ink)
    if pose < 0.35:  # braccio alzato
        t.line([(x - 5, base - 78), (x - 13, base - 96)], fill=ink, width=3.4)
        t.line([(x - 5, base - 78), (x - 13, base - 96)], fill=m, width=2.0)
    elif pose < 0.7:  # mano sul fianco e libro
        t.line([(x + 5, base - 78), (x + 11, base - 64)], fill=ink, width=3.4)
        t.line([(x + 5, base - 78), (x + 11, base - 64)], fill=m, width=2.0)
        t.rect(x - 11, base - 72, x - 4, base - 64, fill=sh, ink=True, width=0.7, ink_col=ink)
    else:  # mantello che scende di lato
        t.poly([(x - 6, base - 80), (x - 13, base - 46), (x - 7, base - 42)], fill=sh, ink=True, width=0.7, ink_col=ink)


VISTA = (610, 1310)  # dove gli alberi del prato si aprono dietro la fontana (#378), in x dello strato


def ring_statue(t, x, base, s, rng, haze):
    """Una statua dell'anello del Prato, piccola e lontana (s è la scala): piedistallo con la cornice, la figura
    in posa con il braccio, il libro o il mantello, velata dalla lontananza."""
    m, sh, ink = far((206, 200, 186, 255), haze), far((162, 156, 144, 255), haze), far((88, 84, 78, 255), haze)
    w = 0.7 * s
    t.rect(x - 11 * s, base - 30 * s, x + 11 * s, base, fill=m, ink=True, width=w, ink_col=ink)
    t.rect(x + 3 * s, base - 30 * s, x + 11 * s, base, fill=sh)
    t.rect(x - 14 * s, base - 35 * s, x + 14 * s, base - 30 * s, fill=m, ink=True, width=w, ink_col=ink)
    body = [(x - 7 * s, base - 35 * s), (x + 7 * s, base - 35 * s), (x + 4.5 * s, base - 64 * s), (x + 5.5 * s, base - 73 * s), (x - 5.5 * s, base - 73 * s), (x - 4.5 * s, base - 64 * s)]
    t.poly(body, fill=m)
    t.poly([(x + 1 * s, base - 35 * s), (x + 7 * s, base - 35 * s), (x + 4.5 * s, base - 64 * s), (x + 5.5 * s, base - 73 * s), (x + 1 * s, base - 73 * s)], fill=sh)
    t.poly(body, ink=True, width=w, ink_col=ink)
    t.circle(x, base - 78 * s, 5 * s, fill=m, ink=True, width=w, ink_col=ink)
    pose = rng.random()
    if pose < 0.4:
        side = rng.choice((-1, 1))
        t.line([(x + side * 4.5 * s, base - 69 * s), (x + side * 12 * s, base - 86 * s)], fill=ink, width=3.2 * s)
        t.line([(x + side * 4.5 * s, base - 69 * s), (x + side * 12 * s, base - 86 * s)], fill=m, width=1.8 * s)
    elif pose < 0.7:
        t.rect(x - 10 * s, base - 62 * s, x - 3 * s, base - 55 * s, fill=sh, ink=True, width=w, ink_col=ink)
    else:
        t.poly([(x - 5 * s, base - 70 * s), (x - 12 * s, base - 40 * s), (x - 6 * s, base - 37 * s)], fill=sh, ink=True, width=w, ink_col=ink)


# Il bordo di fuori del canale attorno all'isola (#378): un ovale come quello vero, largo abbastanza che chi cade dai
# lati dell'isola (x 100 e 1820) finisca in acqua: al pelo dell'acqua (y 622) il canale va da x -207 a 2127
CANAL_OVAL = (960, 575, 1210, 125)  # dietro l'isola la sponda di là sta a y 450, davanti la ringhiera a 700


WALK = 30  # il vialetto lungo il canale, fuori dall'ovale; oltre c'è il prato del Prato (#378)
GRASS, GRASS_D, GRASS_L = (86, 106, 66), (62, 80, 50), (112, 134, 82)
GRAVEL = (182, 172, 150)


def oval_edge_x(y, side, grow=0.0):
    """Dove sta, alla quota y, il bordo dell'ovale del canale sul lato sinistro (side -1) o destro (1); None fuori.
    Con grow, l'ovale allargato di tanto (il bordo di fuori del vialetto)."""
    cx, cy, rx, ry = CANAL_OVAL
    rx, ry = rx + grow, ry + grow
    d = (y - cy) / ry
    if abs(d) > 1:
        return None
    return cx + side * rx * math.sqrt(1 - d * d)


def ansa(name):
    """Le anse del canale ai lati dell'isola (#378, chiesto da Riccardo): il canale è un anello ovale, quindi ai lati
    la sponda di fuori gira verso di noi e lo chiude attorno alle punte dell'isola. Qui la parte alta delle anse, dietro
    ai lottatori: il lastricato dell'anello di fuori, il cordolo che segue l'ovale con la ringhiera e una statua del
    Prato per parte; in cima sfuma nel prato dello sfondo. La parte bassa la disegna near_bank, davanti.
    Prop dietro in x 960, y 604, a 2x: x -420..2340, y 410..604. Dietro l'isola è il vialetto della sponda di là."""
    x0, y0, w, h = -420, 410, 2760, 194
    t = Tela(w, h, origin=(x0, y0), ss=1)
    rng = rand(3783)
    split = 600
    ys = [y0 + i * (split - y0) / 40 for i in range(41)]
    for side in (-1, 1):
        far = x0 if side < 0 else x0 + w
        edge = []
        for y in ys:
            ex = oval_edge_x(y, side)
            edge.append((ex if ex is not None else 960, y))
        ground = [(far, y0), (far, split)] + [(x, y) for x, y in reversed(edge)]
        t.poly(ground, fill=GRAVEL + (255,))  # il vialetto di ghiaia lungo il canale
        walk = []
        for y in ys:
            ex = oval_edge_x(y, side, WALK)
            walk.append((ex if ex is not None else 960, y))
        lawn_pts = [(far, y0), (far, split)] + [(x, y) for x, y in reversed(walk)]
        t.poly(lawn_pts, fill=GRASS + (255,))  # e oltre il prato, con l'erba a ciuffi e le ombre degli alberi
        for k in range(500):
            y = rng.uniform(y0 + 4, split)
            ex = oval_edge_x(y, side, WALK) or 960
            x = rng.uniform(min(far, ex), max(far, ex))
            if (x - ex) * side < 2:
                continue
            t.line([(x, y), (x + rng.uniform(-1, 1), y - rng.uniform(2, 4))], fill=rng.choice([GRASS_D, GRASS_L]) + (255,), width=0.8)
        for k in range(30):  # sassolini del vialetto
            y = rng.uniform(y0 + 10, split)
            ex, ex2 = oval_edge_x(y, side), oval_edge_x(y, side, WALK)
            if ex is None or ex2 is None:
                continue
            x = rng.uniform(min(ex, ex2), max(ex, ex2))
            t.circle(x, y, 0.8, fill=(150, 142, 124, 255))
        # il cordolo di pietra che segue l'ovale, e la ringhiera con i pilastrini sopra
        curb = [(x - side * 0 + side * 0, y) for x, y in edge if y > y0 + 20]
        t.line([(x + side * 4, y) for x, y in curb], fill=(206, 200, 186, 255), width=5.0)
        t.line([(x, y) for x, y in curb], fill=(110, 104, 94, 255), width=0.9)
        for y in range(int(y0 + 34), split, 18):
            ex = oval_edge_x(y, side)
            if ex is None:
                continue
            px = ex + side * 7
            hh = 14 + (y - y0) * 0.12
            t.rect(px - 2.5, y - hh, px + 2.5, y, fill=(206, 200, 186, 255), ink=True, width=0.6, ink_col=(70, 64, 58, 255))
            t.circle(px, y - hh - 2.6, 2.8, fill=(214, 208, 194, 255), ink=True, width=0.6, ink_col=(70, 64, 58, 255))
            y2 = y + 18
            ex2 = oval_edge_x(y2, side)
            if ex2 is not None and y2 < split:
                px2 = ex2 + side * 7
                hh2 = 14 + (y2 - y0) * 0.12
                t.line([(px, y - hh * 0.75), (px2, y2 - hh2 * 0.75)], fill=IRON, width=1.1)
                t.line([(px, y - hh * 0.2), (px2, y2 - hh2 * 0.2)], fill=IRON, width=0.9)
        # una statua dell'anello per parte, sul piedistallo lungo l'ansa
        sx = 960 + side * 1265
        ring_statue(t, sx, 590, 1.15, rng, 0.08)
    # in cima sfuma nel prato dello sfondo, che sta un po' più lontano
    img = t.img
    fade = Image.new("L", img.size, 255)
    px_fade = int(18 * t.k)
    for py in range(px_fade):
        for_line = int(255 * py / px_fade)
        fade.paste(for_line, (0, py, img.size[0], py + 1))
    alpha = img.getchannel("A")
    from PIL import ImageChops
    img.putalpha(ImageChops.multiply(alpha, fade))
    t.save(OUT, name, colors=256)


def _parked_bike(q, x, ground, col, flip=1):
    """Una bici legata alla ringhiera, di fianco: le ruote, il telaio colorato, la sella, il manubrio e il lucchetto."""
    ink = (36, 32, 30)
    r = 19
    back, front = (x - flip * 30, ground - r), (x + flip * 30, ground - r)
    tires = q.mask()
    for cx, cy in (back, front):
        q.poly(tires, [(cx + r * math.cos(u), cy + r * math.sin(u)) for u in [j * math.tau / 36 for j in range(36)]])
    holes = q.mask()
    for cx, cy in (back, front):
        q.poly(holes, [(cx + (r - 3) * math.cos(u), cy + (r - 3) * math.sin(u)) for u in [j * math.tau / 36 for j in range(36)]])
    q.fill(q.minus(tires, holes), (40, 40, 42))
    spokes = q.mask()
    for cx, cy in (back, front):
        for k in range(10):
            u = k * math.pi / 10
            q.stroke(spokes, [(cx - (r - 3) * math.cos(u), cy - (r - 3) * math.sin(u)), (cx + (r - 3) * math.cos(u), cy + (r - 3) * math.sin(u))], 0.4)
    q.fill(spokes, (150, 150, 150), 0.7)
    bb = (x - flip * 4, ground - r + 2)
    seat_top, head_top = (x - flip * 10, ground - r - 26), (x + flip * 20, ground - r - 26)
    frame = q.mask()
    for p0, p1 in ((back, bb), (bb, seat_top), (seat_top, back), (seat_top, head_top), (bb, head_top), (head_top, front)):
        q.stroke(frame, [p0, p1], 2.8)
    q.stroke(frame, [head_top, (head_top[0] + flip * 2, head_top[1] - 8), (head_top[0] - flip * 6, head_top[1] - 10)], 2.2)
    q.fill(frame, col)
    q.fill(q.rim(frame, -0.6, -0.8, 0.5), light(col, 1.25), 0.7)
    q.outline(frame, 0.5, ink)
    seat = q.mask()
    q.poly(seat, [(seat_top[0] - 9, seat_top[1] - 4), (seat_top[0] + 6, seat_top[1] - 5), (seat_top[0] + 4, seat_top[1] - 1), (seat_top[0] - 8, seat_top[1])])
    q.fill(seat, (44, 38, 34))
    lock = q.mask()  # il lucchetto ad arco che lega la ruota davanti alla ringhiera
    q.stroke(lock, [(front[0], front[1] + 4), (front[0] + flip * 2, front[1] - 14), (front[0] + flip * 8, front[1] - 18)], 2.0)
    q.fill(lock, (170, 150, 60))


def near_bank(name):
    """La sponda di qua del canale (#378, idea di Riccardo), in primo piano davanti a tutto: il cordolo di pietra che
    segue l'ovale del canale (ai lati sale e lo chiude attorno all'isola, dove continua l'ansa disegnata dietro), la
    ringhiera di ferro tra i pilastrini con la palla, qualche bici legata, e poi il lastricato del Prato che viene verso
    di noi. Così il canale resta una striscia stretta come quello vero. Sfocata e un po' in ombra, perché è più vicina
    della scena e non deve rubarle l'occhio. Prop davanti (front) in x 960, y 1100, a 1x: x -400..2320, y 596..1100."""
    from pittura import Quadro
    from PIL import ImageFilter
    x0, y0, w, h = -400, 596, 2720, 504
    q = Quadro(w, h, origin=(x0, y0), scale=1)
    rng = rand(3782)
    split = 600
    # il bordo: la metà bassa dell'ovale, da sinistra a destra
    arc = []
    cx, cy, rx, ry = CANAL_OVAL
    a0 = math.asin((split - cy) / ry)
    for i in range(121):
        a = math.pi - a0 - (math.pi - 2 * a0) * i / 120
        arc.append((cx + rx * math.cos(a), cy + ry * math.sin(a)))
    ground_pts = [(x0, split)] + arc + [(x0 + w, split), (x0 + w, y0 + h), (x0, y0 + h)]
    ground = q.poly(q.mask(), ground_pts)
    q.fill(ground, GRAVEL)  # il vialetto di ghiaia lungo il canale
    walk_arc = []  # il bordo di fuori del vialetto: l'ovale allargato di WALK
    a1 = math.asin(min(1.0, (split - cy) / (ry + WALK)))
    for i in range(121):
        a = math.pi - a1 - (math.pi - 2 * a1) * i / 120
        walk_arc.append((cx + (rx + WALK) * math.cos(a), cy + (ry + WALK) * math.sin(a)))
    road_top = 880
    lawn = q.poly(q.mask(), [(x0, split)] + walk_arc + [(x0 + w, split), (x0 + w, road_top), (x0, road_top)])
    # il prato del parco (#378, Riccardo: niente campo verde vuoto quando la telecamera si allarga): l'erba dipinta
    # come sull'isola, i vialetti di ghiaia che vanno verso il canale come i raggi del Prato, le aiuole fiorite, le
    # siepi basse di bosso e le panchine voltate verso il canale. Tutto basso: davanti alla scena non copre il gioco
    paths = q.mask()
    for xn in (300, 1620):  # i vialetti: larghi vicino, verso il punto di fuga del Prato
        xf = xn + (960 - xn) * (road_top - 640) / (road_top + 420)
        q.poly(paths, [(xf - 16, 630), (xf + 16, 630), (xn + 34, road_top + 2), (xn - 34, road_top + 2)])
    paths = q.intersect(paths, lawn)
    paint_grass(q, q.minus(lawn, paths), 3101, split, road_top, density=0.12)
    paint_gravel(q, paths, 3102, 630, road_top, density=0.25)
    for k in range(5):  # le ombre degli alberi del parco sul prato
        x, y = rng.uniform(x0, x0 + w), rng.uniform(740, 860)
        q.fill(q.intersect(q.soften(q.ellipse(q.mask(), x - 160, y - 22, x + 160, y + 22), 14), lawn), GRASS_D, 0.45)
    for bx, by, bw in ((60, 812, 150), (560, 790, 120), (1360, 790, 120), (1880, 812, 150)):  # le aiuole fiorite
        bed = q.intersect(q.smooth(q.ellipse(q.mask(), bx - bw, by - 16, bx + bw, by + 16), 2), lawn)
        q.fill(bed, (96, 74, 56))
        fl = q.mask()
        frng = random.Random(bx)
        for _ in range(int(bw * 2.2)):
            fx, fy = frng.uniform(bx - bw, bx + bw), frng.uniform(by - 14, by + 14)
            r = frng.uniform(1.6, 3.2)
            q.ellipse(fl, fx - r, fy - r * 0.8, fx + r, fy + r * 0.8)
        q.fill(q.intersect(fl, bed), (70, 104, 60))
        for colf in ((206, 70, 70), (236, 196, 80), (220, 220, 232), (176, 96, 170)):
            fm = q.mask()
            for _ in range(int(bw * 0.5)):
                fx, fy = frng.uniform(bx - bw, bx + bw), frng.uniform(by - 13, by + 13)
                q.ellipse(fm, fx - 1.6, fy - 1.3, fx + 1.6, fy + 1.3)
            q.fill(q.intersect(fm, bed), colf, 0.9)
        q.outline(bed, 0.8, (60, 48, 40))
    for hx in (-240, 180, 760, 1160, 1740, 2160):  # le siepi basse di bosso, tonde
        hy = 742
        hedge = q.smooth(q.union(q.ellipse(q.mask(), hx - 40, hy - 20, hx + 40, hy + 8), q.ellipse(q.mask(), hx - 26, hy - 30, hx + 22, hy)), 2)
        q.fill(q.shift(q.soften(hedge, 4), 4, 8), (30, 40, 24), 0.4)
        q.fill(hedge, (58, 86, 46))
        q.fill(q.grain(hedge, 0.8, hx + 9000, 2.2), (82, 114, 62), 0.6)
        q.fill(q.inner_shadow(hedge, -4, -4, 4), (34, 52, 30), 0.7)
        q.outline(hedge, 0.8, (34, 44, 30))
    for bx in (-60, 460, 1460, 1980):  # le panchine di legno e ghisa, viste da dietro, voltate verso il canale
        by = 716 if abs(bx - 960) < 700 else 706
        wood, iron_c = (126, 92, 62), (40, 40, 42)
        bm, wm_ = q.mask(), q.mask()
        for lx in (bx - 44, bx + 40):
            q.poly(bm, [(lx, by), (lx + 4, by), (lx + 4, by - 26), (lx, by - 26)])
        for k in range(3):  # le doghe dello schienale
            q.poly(wm_, [(bx - 52, by - 30 + k * 6), (bx + 52, by - 30 + k * 6), (bx + 52, by - 26 + k * 6), (bx - 52, by - 26 + k * 6)])
        q.fill(q.shift(q.soften(q.union(bm, wm_), 3), 3, 6), (30, 28, 24), 0.35)
        q.fill(wm_, wood)
        q.fill(q.inner_shadow(wm_, 0, -2, 1), shade((*wood, 255), 0.7)[:3], 0.8)
        q.fill(bm, iron_c)
        q.outline(q.union(bm, wm_), 0.7, (36, 30, 26))
    # la strada che gira attorno al Prato: il marciapiede, l'asfalto vecchio e l'altro marciapiede
    walk2 = q.poly(q.mask(), [(x0, road_top), (x0 + w, road_top), (x0 + w, road_top + 14), (x0, road_top + 14)])
    q.fill(walk2, (188, 180, 164))
    q.fill(q.inner_shadow(walk2, 0, -4, 2), (150, 142, 128), 0.8)
    asphalt = q.poly(q.mask(), [(x0, road_top + 14), (x0 + w, road_top + 14), (x0 + w, road_top + 120), (x0, road_top + 120)])
    # l'asfalto vecchio e chiaro (#378, chiesto da Riccardo): sbiadito, con le toppe più scure, le crepe e un tombino
    q.fill(asphalt, (128, 126, 120))
    q.fill(q.grain(asphalt, 0.45, 33, 1.0), (104, 102, 98))
    q.fill(q.grain(asphalt, 0.35, 34, 2.4), (150, 148, 142))
    patches = q.mask()
    for k in range(14):
        px, py = rng.uniform(x0, x0 + w), rng.uniform(road_top + 20, road_top + 110)
        pw, ph = rng.uniform(40, 160), rng.uniform(10, 34)
        q.poly(patches, [(px, py), (px + pw, py + rng.uniform(-3, 3)), (px + pw + rng.uniform(-6, 6), py + ph), (px + rng.uniform(-6, 6), py + ph)])
    q.fill(q.intersect(patches, asphalt), (106, 104, 100), 0.7)
    cracks = q.mask()
    for k in range(40):
        cx_, cy_ = rng.uniform(x0, x0 + w), rng.uniform(road_top + 18, road_top + 116)
        pts = [(cx_, cy_)]
        for j in range(6):
            cx_ += rng.uniform(4, 14) * rng.choice((-1, 1))
            cy_ += rng.uniform(-4, 4)
            pts.append((cx_, cy_))
        q.stroke(cracks, pts, 0.7)
    q.fill(q.intersect(cracks, asphalt), (70, 68, 66), 0.85)
    for mx in (520, 1480):  # i tombini
        man = q.ellipse(q.mask(), mx - 16, road_top + 60, mx + 16, road_top + 72)
        q.fill(man, (84, 82, 80))
        q.outline(man, 0.8, (50, 48, 46))
    side2 = q.poly(q.mask(), [(x0, road_top + 120), (x0 + w, road_top + 120), (x0 + w, y0 + h), (x0, y0 + h)])
    q.fill(side2, (176, 168, 152))
    # l'ombra del primo piano: più scuro in basso
    grad = Image.new("RGBA", (1, q.size[1]))
    for py in range(q.size[1]):
        y = y0 + py / q.k
        u = max(0.0, min(1.0, (y - 640) / 460))
        grad.putpixel((0, py), (30, 28, 26, int(150 * u ** 0.9)))
    shade_img = Image.new("RGBA", q.size, (0, 0, 0, 0))
    shade_img.alpha_composite(grad.resize(q.size, Image.NEAREST))
    shade_img.putalpha(ImageChops.multiply(shade_img.getchannel("A"), ground))
    q.img.alpha_composite(shade_img)
    # il cordolo di pietra d'Istria lungo l'ovale
    c = q.mask()
    for part in ([p for p in arc if p[0] <= 960 - 96], [p for p in arc if p[0] >= 960 + 96]):
        q.stroke(c, [(x, y + 4) for x, y in part], 9)
    q.fill(c, (204, 198, 184))
    q.fill(q.inner_shadow(c, 0, -5, 2), (156, 150, 138), 0.85)
    q.fill(q.rim(c, 0, -1, 0.6), (232, 228, 216), 0.7)
    q.outline(c, 0.8, (70, 64, 58))
    # la ringhiera lungo l'ovale: pilastrini con la palla ogni tanto, il ferro battuto in mezzo
    gap = (960 - 96, 960 + 96)  # il varco per il ponte sud (#378): la ringhiera si ferma ai suoi capi
    left_arc = [p for p in arc if p[0] <= gap[0]]
    right_arc = [p for p in arc if p[0] >= gap[1]]
    posts, segs = [], []
    for part in (left_arc, right_arc):
        mine, dist, last = [], 0.0, part[0]
        for p in part:
            dist += math.hypot(p[0] - last[0], p[1] - last[1])
            last = p
            if not mine or dist >= 150:
                mine.append(p)
                dist = 0.0
        if mine[-1] != part[-1]:
            mine.append(part[-1])
        posts += mine
        segs += list(zip(mine, mine[1:]))
    iron = q.mask()
    for (ax, ay), (bx, by) in segs:
        q.stroke(iron, [(ax, ay - 24), (bx, by - 24)], 2.4)
        q.stroke(iron, [(ax, ay - 4), (bx, by - 4)], 2.0)
        n = max(2, int(math.hypot(bx - ax, by - ay) / 12))
        for k in range(1, n):
            u = k / n
            px, py = ax + (bx - ax) * u, ay + (by - ay) * u
            q.stroke(iron, [(px, py - 24), (px, py - 4)], 1.1)
        for u in (0.33, 0.66):  # i riccioli a S
            mx, my = ax + (bx - ax) * u, ay + (by - ay) * u - 14
            for side in (-1, 1):
                pts = [(mx + side * 7 * math.cos(t_), my + 5 * math.sin(t_) * side) for t_ in [j * math.pi / 8 for j in range(17)]]
                q.stroke(iron, pts, 1.3)
    q.fill(iron, (44, 42, 44))
    q.fill(q.rim(iron, -0.5, -0.8, 0.4), (110, 108, 104), 0.6)
    # le bici legate alla ringhiera, sul lastricato davanti
    for bx, col, fl in ((570, (150, 60, 50), 1), (640, (60, 84, 120), -1), (1290, (40, 40, 44), 1), (1500, (90, 120, 80), -1)):
        ex = min(arc, key=lambda p: abs(p[0] - bx))
        _parked_bike(q, bx, ex[1] + 22, col, fl)
    pm = q.mask()
    for x, y in posts:
        q.poly(pm, [(x - 7, y + 1), (x + 7, y + 1), (x + 6, y - 30), (x - 6, y - 30)])
        q.poly(pm, [(x - 9, y - 30), (x + 9, y - 30), (x + 9, y - 34), (x - 9, y - 34)])
        q.ellipse(pm, x - 7, y - 48, x + 7, y - 34)
    q.fill(pm, (210, 204, 190))
    q.fill(q.inner_shadow(pm, -5, 0, 3), (150, 144, 132), 0.9)
    q.fill(q.rim(pm, -1, -1, 0.8), (236, 232, 222), 0.7)
    q.outline(pm, 0.8, (70, 64, 58))
    # sfocata e in ombra: è più vicina della scena
    out = q.result().filter(ImageFilter.GaussianBlur(1.6))
    shade_layer = Image.new("RGBA", out.size, (34, 30, 28, 0))
    shade_layer.putalpha(out.getchannel("A").point(lambda a: int(a * 0.22)))
    out.alpha_composite(shade_layer)
    out = out.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)  # leggero (E12: 4 MB per arena)
    out.save(os.path.join(OUT, name), optimize=True)
    print("scritto", name, out.size)


def near_statues(name):
    """Le statue del Prato in primissimo piano (#378, idea di Riccardo), sfocate e trasparenti: una per parte, fuori
    dal canale, dove non coprono il gioco; il gioco le disegna davanti a tutto con opacity. Prop in x 960, y 1100, a 1x."""
    from PIL import ImageFilter
    x0, y0, w, h = -460, 420, 2840, 680
    t = Tela(w, h, origin=(x0, y0), scale=1, ss=2)
    rng = rand(3784)
    for x in (-430, 2350):  # solo fuori dal canale e oltre i ponti, dove non coprono niente
        base = 760 + rng.uniform(-10, 10)
        ring_statue(t, x, base, 3.0, rng, 0.0)
    out = t.result().filter(ImageFilter.GaussianBlur(1.6))
    out.save(os.path.join(OUT, name), optimize=True)
    print("scritto", name, out.size)


def canal_back(name):
    """L'acqua del canale dietro e attorno all'isola (#378): tutto l'interno dell'ovale, dalla sponda di là (y 450) fin
    sotto il pelo dell'acqua davanti; più chiara e azzurrina lontano, con i riflessi del cielo e delle statue, il
    riflesso scuro sotto il cordolo e le lenti d'acqua lungo le sponde. Prop dietro in x 960, y 644, a 2x."""
    x0, y0, w, h = -420, 444, 2760, 200
    t = Tela(w, h, origin=(x0, y0), ss=1)
    cx, cy, rx, ry = CANAL_OVAL
    rng = rand(3785)
    ys = [cy - ry + i * (y0 + h - (cy - ry)) / 60 for i in range(61)]
    for i, (ya, yb) in enumerate(zip(ys, ys[1:])):
        xa_l, xa_r = oval_edge_x(ya, -1), oval_edge_x(ya, 1)
        xb_l, xb_r = oval_edge_x(yb, -1), oval_edge_x(yb, 1)
        if None in (xa_l, xb_l):
            continue
        u = i / 59
        col = mix((112, 140, 132, 255), (74, 100, 92, 255), u ** 0.7)
        t.poly([(xa_l, ya), (xa_r, ya), (xb_r, yb + 0.6), (xb_l, yb + 0.6)], fill=col)
    for k in range(260):  # riflessi del cielo
        y = rng.uniform(cy - ry + 3, y0 + h)
        xl, xr = oval_edge_x(y, -1), oval_edge_x(y, 1)
        if xl is None:
            continue
        x = rng.uniform(xl + 10, xr - 30)
        t.line([(x, y), (x + rng.uniform(8, 30) * (0.5 + (y - 450) / 200), y)], fill=(168, 192, 186, 255), width=0.6)
    top = [(cx + rx * math.cos(a), cy + ry * math.sin(a)) for a in [math.pi + math.pi * i / 120 for i in range(121)]]
    t.line([(x, y + 2) for x, y in top], fill=(70, 92, 86, 255), width=3.0)  # il riflesso scuro sotto la sponda
    for k in range(320):  # lenti d'acqua e alghe lungo le sponde
        a = math.pi + rng.uniform(0.02, 0.98) * math.pi
        x, y = cx + (rx - rng.uniform(2, 14)) * math.cos(a), cy + (ry - rng.uniform(2, 6)) * math.sin(a) + 3
        t.ellipse(x - 1.8, y - 0.5, x + 1.8, y + 0.5, fill=(128, 142, 84, 255))
    t.save(OUT, name, colors=256)


VP = (960, -420)  # il punto di fuga delle linee che vengono verso la telecamera (#378): in alto al centro, lontano


def toward_camera(x_far, y_far, y_near):
    """Dove sta, alla quota y_near, il punto che alla quota y_far è in x_far, su una linea che viene verso la telecamera:
    tutte queste linee scappano verso VP. Restituisce (x_near, quanto è più grande là)."""
    k = (y_near - VP[1]) / (y_far - VP[1])
    return VP[0] + (x_far - VP[0]) * k, k


def front_bridges(name):
    """Il ponte sud in primo piano (#378, come al Prato): dalla piazza di qua del canale alla fontana, al centro. Lo si
    vede di fronte, da sopra, come si vede dalla piazza: la passerella lastricata che si stringe andando verso l'isola
    (le linee scappano verso il punto di fuga in alto al centro), i due parapetti traforati visti da dentro, l'acqua
    del canale ai lati e gli obelischi sul capo vicino. I parapetti cominciano un po' prima della piazza, così non
    coprono i piedi di chi combatte sopra la fontana. Decorazione davanti (front) in x 960, y 780, a 2x."""
    from pittura import Quadro
    x0, y0, w, h = 700, 460, 520, 320
    q = Quadro(w, h, origin=(x0, y0))
    S, S_SH, S_HI = (228, 224, 212), (174, 168, 156), (246, 244, 236)
    ink = (78, 72, 66)
    yf, yn, half_f = 520 + FRONT_D + 2, 704, 50  # dal bordo davanti dell'isola ovale (#378)
    n = 40
    us = [i / n for i in range(n + 1)]

    def edge(off, u):
        y = yf + (yn - yf) * u
        xn, k = toward_camera(960 + off * half_f, yf, y)
        return (xn, y - 6 * math.sin(math.pi * u) ** 0.9)

    def scale(u):
        return toward_camera(960, yf, yf + (yn - yf) * u)[1]

    L = [edge(-1, u) for u in us]
    R = [edge(1, u) for u in us]
    # l'ombra del ponte sull'acqua, a destra (la luce viene da sinistra in alto)
    q.fill(q.soften(q.poly(q.mask(), [(x + 4, y + 6) for x, y in R] + [(x + 22, y + 10) for x, y in reversed(R)]), 4), (30, 44, 40), 0.35)
    deck = q.poly(q.mask(), L + list(reversed(R)))
    # la passerella in sanpietrini tondi (#378, come i ponti del Prato): sassi di trachite tondeggianti messi a file
    # sfalsate, più piccoli lontano, nelle fughe scure; ogni sasso è un piccolo volume con la luce in alto a sinistra,
    # l'ombra in basso a destra e il suo tono, un po' diverso dai vicini
    q.fill(deck, (96, 90, 82))
    crng = rand(3794)
    tones = [q.mask(), q.mask(), q.mask()]
    shades, lights = q.mask(), q.mask()
    y = yf + 1.5
    row = 0
    while y < yn:
        u = (y - yf) / (yn - yf)
        k = scale(u)
        r = 3.2 * k
        lx, _ = edge(-1, u)
        rx_, _ = edge(1, u)
        x = lx + r * (0.6 if row % 2 else 1.6)
        while x < rx_ - r * 0.6:
            rr = r * crng.uniform(0.85, 1.1)
            ry_ = rr * 0.62
            q.ellipse(tones[crng.randrange(3)], x - rr, y - ry_, x + rr, y + ry_)
            q.ellipse(lights, x - rr * 0.75, y - ry_ * 0.85, x + rr * 0.2, y - ry_ * 0.05)
            q.ellipse(shades, x - rr * 0.3, y - ry_ * 0.1, x + rr * 1.0, y + ry_ * 1.0)
            x += rr * 2.15
        y += r * 0.62 * 2.05
        row += 1
    stones = q.intersect(q.union(q.union(tones[0], tones[1]), tones[2]), deck)
    for m_, col in zip(tones, ((182, 174, 160), (166, 160, 148), (196, 188, 172))):
        q.fill(q.intersect(m_, deck), col)
    q.fill(q.intersect(q.soften(shades, 0.5), stones), (120, 114, 104), 0.7)
    q.fill(q.intersect(q.soften(lights, 0.5), stones), (232, 226, 212), 0.75)
    q.fill(q.intersect(q.grain(stones, 0.5, 95, 0.4), stones), (140, 134, 122), 0.35)
    q.fill(q.intersect(q.soften(q.poly(q.mask(), [L[0], R[0], R[4], L[4]]), 3), deck), (40, 38, 34), 0.25)  # sotto il bordo della piazza
    # i due parapetti traforati a cerchi intrecciati, visti da dentro: cominciano poco dopo la piazza, così non coprono
    # i piedi di chi combatte; quello a destra è in ombra; gli obelischi alti sul capo di qua
    start = 1
    _openwork(q, L[start:], 18, ink, face=S, shadow=(170, 164, 152), through=(92, 120, 112), seed=92)
    _openwork(q, R[start:], 18, ink, face=S_SH, shadow=(140, 134, 124), through=(80, 108, 100), seed=93)
    for x, y in (L[-1], R[-1]):
        _obelisk_q(q, x, y + 3, 1.3, 94)
    out = q.result()
    t = Tela(w, h, origin=(x0, y0), ss=1)
    t.img = out
    t.d = ImageDraw.Draw(t.img)
    for x, y in (L[start], R[start]):  # piedistalli bassi verso la piazza
        t.rect(x - 4, y - 10, x + 4, y + 1, fill=(222, 218, 206, 255), ink=True, width=0.6, ink_col=(84, 78, 72, 255))
    t.img.save(os.path.join(OUT, name), optimize=True)
    print("scritto", name, t.img.size)


def _obelisk_q(q, x, base, s, seed=0):
    """Un obelisco del Prato dipinto (#378, dalle foto): il dado quadrato con lo zoccolo e la cornice, il plinto e
    l'ago alto e sottile che si stringe, di pietra d'Istria con la luce a sinistra e le macchie del tempo."""
    S, S_SH, S_HI = (230, 226, 214), (168, 162, 150), (248, 246, 238)
    ink = (80, 74, 68)

    def block(pts, shade=True):
        m = q.poly(q.mask(), pts)
        q.fill(m, S)
        if shade:
            bb = m.getbbox()
            if bb:  # la faccia di destra in ombra: metà blocco
                q.fill(q.inner_shadow(m, -(bb[2] - bb[0]) / q.k * 0.45, 0, 0.6), S_SH, 0.9)
        q.fill(q.grain(m, 0.3, seed + int(x), 0.6), (150, 148, 138), 0.4)
        q.fill(q.rim(m, -0.6, -0.6, 0.4), S_HI, 0.7)
        q.outline(m, 0.45, ink)

    w = 8 * s
    block([(x - w * 1.25, base), (x + w * 1.25, base), (x + w * 1.25, base - 3 * s), (x - w * 1.25, base - 3 * s)])  # lo zoccolo
    block([(x - w, base - 3 * s), (x + w, base - 3 * s), (x + w, base - 19 * s), (x - w, base - 19 * s)])  # il dado
    block([(x - w * 1.2, base - 19 * s), (x + w * 1.2, base - 19 * s), (x + w * 1.2, base - 22 * s), (x - w * 1.2, base - 22 * s)])  # la cornice
    block([(x - w * 0.62, base - 22 * s), (x + w * 0.62, base - 22 * s), (x + w * 0.62, base - 26 * s), (x - w * 0.62, base - 26 * s)])  # il plinto
    needle = [(x - w * 0.5, base - 26 * s), (x + w * 0.5, base - 26 * s), (x + w * 0.16, base - 88 * s), (x, base - 93 * s), (x - w * 0.16, base - 88 * s)]
    block(needle)


def _openwork(q, pts, hgt, ink, face=(228, 224, 212), shadow=(176, 170, 158), through=(150, 168, 172), seed=0):
    """Il parapetto traforato dei ponti del Prato (#378, dalle foto): una lastra di pietra sopra la linea pts (il
    bordo del ponte), alta hgt, divisa in riquadri da pilastrini; in ogni riquadro una catena di cerchi intrecciati
    traforati, da cui si vede quello che c'è dietro (through); sopra il corrimano tondo, sotto lo zoccolo."""
    panel = q.poly(q.mask(), pts + [(x, y - hgt) for x, y in reversed(pts)])
    holes, pils = q.mask(), q.mask()
    total = 0.0
    lens = [0.0]
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        total += math.hypot(bx - ax, by - ay)
        lens.append(total)

    def at(d):
        for i in range(1, len(lens)):
            if lens[i] >= d:
                u = (d - lens[i - 1]) / max(1e-6, lens[i] - lens[i - 1])
                (ax, ay), (bx, by) = pts[i - 1], pts[i]
                return ax + (bx - ax) * u, ay + (by - ay) * u
        return pts[-1]

    r = hgt * 0.2
    step_p = max(hgt * 1.9, 14)  # un pilastrino ogni tanto
    d = 0.0
    while d <= total:
        x, y = at(d)
        q.poly(pils, [(x - r * 0.55, y), (x + r * 0.55, y), (x + r * 0.55, y - hgt), (x - r * 0.55, y - hgt)])
        d += step_p
    d = r * 1.6
    while d < total - r:
        x, y = at(d)
        yc = y - hgt * 0.5
        q.ellipse(holes, x - r * 0.62, yc - r * 0.62, x + r * 0.62, yc + r * 0.62)  # il cerchio traforato
        for sgn in (-1, 1):  # i triangoli fra un cerchio e l'altro, sopra e sotto
            q.poly(holes, [(x + r * 0.85, yc + sgn * r * 0.95), (x + r * 1.15, yc + sgn * r * 0.35), (x + r * 0.55, yc + sgn * r * 0.35)])
        d += r * 1.7
    holes = q.minus(holes, pils)
    stone = q.minus(panel, holes)
    q.fill(stone, face)
    q.fill(q.grain(stone, 0.3, seed, 0.6), (156, 152, 142), 0.4)
    rings = q.minus(q.soften(holes, r * 0.12), holes)  # l'orlo scolpito attorno ai trafori, in ombra
    q.fill(q.intersect(rings, stone), shadow, 0.9)
    q.fill(q.intersect(holes, panel), through)
    q.fill(q.intersect(pils, panel), (238, 234, 224), 0.7)
    q.outline(panel, 0.45, ink)
    rail = q.mask()
    q.stroke(rail, [(x, y - hgt) for x, y in pts], hgt * 0.22)
    q.fill(rail, (240, 236, 226))
    q.fill(q.inner_shadow(rail, 0, -hgt * 0.1, hgt * 0.06), shadow, 0.9)
    q.outline(rail, 0.45, ink)
    base = q.mask()
    q.stroke(base, [(x, y - hgt * 0.06) for x, y in pts], hgt * 0.14)
    q.fill(base, shadow, 0.8)


def _profile_bridge(t, x_in, x_out, rng):
    """Un ponte del Prato visto di fianco (#378, come nelle foto di Riccardo): collega la punta dell'isola, alla
    stessa quota della striscia dove si gioca (y 520), alla piazza di fuori, oltre il canale. Arco ribassato di pietra
    d'Istria con i conci e la chiave, il parapetto traforato a quadrifogli che segue la leggera gobba, la cornice che fa
    ombra, l'umido e le alghe dove tocca l'acqua (y 600), il riflesso spezzato; ai capi gli obelischi sui piedistalli.
    Dipinto con pittura.py e incollato nella tela; è dietro i lottatori e non si attraversa."""
    from pittura import Quadro
    a, b = min(x_in, x_out), max(x_in, x_out)
    x0, y0 = a - 24, 420
    q = Quadro(b - a + 48, 228, origin=(x0, y0), scale=t.k)
    S, S_SH, S_DK, S_HI = (228, 224, 212), (174, 168, 156), (124, 120, 112), (246, 244, 236)
    ink = (78, 72, 66)
    deck, water, hump = 521, 600, 5
    n = 48
    xs = [a + (b - a) * i / n for i in range(n + 1)]
    top = [(x, deck - hump * math.sin(math.pi * i / n) ** 0.9) for i, x in enumerate(xs)]
    span, mid = (b - a) * 0.74, (a + b) / 2
    arch = [(mid - span / 2 + span * i / n, water - (water - deck - 18 + hump) * math.sin(math.pi * i / n) ** 0.55) for i in range(n + 1)]
    opening = q.poly(q.mask(), [(mid - span / 2, water + 1)] + arch + [(mid + span / 2, water + 1)])
    # sotto l'arco si vede il canale che continua (#378, chiesto da Riccardo): l'acqua va via da noi e, siccome il canale
    # è un anello ovale, piega verso il centro dietro l'isola. Le due sponde convergono verso un punto di fuga spostato
    # dalla parte dell'isola; lontano l'acqua è più chiara e riflette il cielo, in fondo si vedono il prato e gli alberi
    # della sponda che gira. In alto la volta del ponte in ombra.
    sg = 1 if mid < 960 else -1  # da che parte sta l'isola (il centro dell'ovale)
    H = water - arch[n // 2][1]
    hz = water - H * 0.5  # l'orizzonte del canale dentro l'arco
    vx = mid + sg * span * 0.28  # il punto di fuga: il canale piega verso l'isola
    left_x, right_x = mid - span / 2, mid + span / 2
    inner_x, outer_x = (right_x, left_x) if sg > 0 else (left_x, right_x)

    def vgrad(y_top, y_bot):  # una maschera che va da pieno in alto (y_top) a vuoto in basso (y_bot)
        g = Image.new("L", q.size, 0)
        dg = ImageDraw.Draw(g)
        ya, yb = q._p(0, y_top)[1], q._p(0, y_bot)[1]
        for py in range(int(ya), int(yb) + 1):
            u = (py - ya) / max(1, yb - ya)
            dg.line([(0, py), (q.size[0], py)], fill=int(255 * (1 - u) ** 1.3))
        return g

    q.fill(opening, (128, 150, 136))  # lontano, sopra l'orizzonte: la sponda che gira, verde di prato e alberi
    trees = q.mask()
    for k in range(7):
        tx = vx + sg * rng.uniform(-span * 0.1, span * 0.3)
        q.ellipse(trees, tx - 9, hz - 15 - rng.uniform(0, 6), tx + 9, hz + 2)
    q.fill(q.intersect(q.soften(trees, 1.5), opening), (96, 120, 92), 0.9)
    farbank = q.poly(q.mask(), [(left_x, hz), (right_x, hz), (right_x, hz - 3), (left_x, hz - 3)])
    q.fill(q.intersect(farbank, opening), (214, 208, 194))  # il cordolo bianco della sponda in fondo
    wat = q.poly(q.mask(), [(left_x, water + 1), (right_x, water + 1), (right_x, hz), (left_x, hz)])
    q.fill(q.intersect(wat, opening), (72, 100, 94))
    q.fill(q.intersect(q.intersect(vgrad(hz, water), wat), opening), (170, 194, 188), 0.9)  # lontano più chiaro
    # le due sponde che convergono verso il punto di fuga: quella di fuori (pietra chiara, in luce) e il muro
    # dell'isola (mattoni in ombra), alte vicino e basse lontano
    for bx, col, hgt in ((outer_x, (206, 200, 186), H * 0.42), (inner_x, (128, 100, 86), H * 0.5)):
        wall = q.poly(q.mask(), [(bx, water + 1), (bx, water - hgt), (vx, hz - 2), (vx, hz)])
        q.fill(q.intersect(wall, opening), col)
        q.fill(q.intersect(q.intersect(vgrad(hz - hgt * 0.2, water), wall), opening), (150, 168, 160), 0.5)  # la foschia lontano
        edge = q.mask()
        q.stroke(edge, [(bx, water - hgt), (vx, hz - 2)], 1.0)
        q.fill(q.intersect(edge, opening), (236, 232, 222) if bx == outer_x else (96, 76, 66))
        refl = q.poly(q.mask(), [(bx, water + 1), (bx + (vx - bx) * 0.05, water + 1), (vx, hz), (vx, hz + 1)])
    # i riflessi del cielo sull'acqua, a pennellate orizzontali più corte e fitte lontano
    rip = q.mask()
    for k in range(26):
        u = rng.random() ** 1.6  # 0 vicino, 1 lontano
        y = water - 2 - u * (water - hz - 3)
        half = (1 - u) * span * 0.18 + 2
        x = rng.uniform(left_x + span * 0.15, right_x - span * 0.15) * (1 - u) + vx * u
        q.stroke(rip, [(x - half, y), (x + half, y)], 0.7 - 0.3 * u)
    q.fill(q.intersect(q.intersect(rip, wat), opening), (200, 220, 214), 0.7)
    # la volta del ponte vista da sotto: una fascia in ombra lungo l'intradosso, più larga dalla parte dell'isola
    vault = q.poly(q.mask(), arch + [(x + sg * 10 * math.sin(math.pi * i / n), y + 12 * math.sin(math.pi * i / n) ** 0.5) for i, (x, y) in reversed(list(enumerate(arch)))])
    q.fill(q.intersect(q.soften(vault, 2.5), opening), (54, 66, 62), 0.85)
    q.fill(q.intersect(q.soften(q.poly(q.mask(), [(left_x, water - 3), (right_x, water - 3), (right_x, water + 1), (left_x, water + 1)]), 1.5), opening), (40, 56, 52), 0.5)  # l'ombra del ponte sull'acqua vicina
    # la faccia del ponte
    face = q.minus(q.poly(q.mask(), top + [(b, water), (a, water)]), opening)
    q.fill(face, S)
    q.fill(q.grain(face, 0.35, 81, 0.8), (150, 148, 138), 0.45)
    damp = q.poly(q.mask(), [(a, water - 16), (b, water - 16), (b, water), (a, water)])
    q.fill(q.intersect(q.soften(damp, 5), face), (96, 102, 82), 0.65)
    q.fill(q.intersect(q.soften(q.poly(q.mask(), [(a, water - 4), (b, water - 4), (b, water), (a, water)]), 1), face), (86, 102, 62), 0.8)
    ring = q.minus(q.poly(q.mask(), [(mid - span / 2 - 10, water)] + [(x + (x - mid) * 0.1, y - 10 * math.sin(math.pi * i / n) ** 0.4) for i, (x, y) in enumerate(arch)] + [(mid + span / 2 + 10, water)]), opening)
    q.fill(q.intersect(ring, face), (236, 232, 222))
    vj = q.mask()
    for i in range(1, 22):
        u = i / 22
        px, py = arch[int(u * n)]
        ang = math.atan2(py - water, px - mid)
        q.stroke(vj, [(px, py), (px + math.cos(ang) * 11, py + math.sin(ang) * 11)], 0.55)
    q.fill(q.intersect(vj, ring), S_DK, 0.75)
    kx, ky = arch[n // 2]
    key = q.poly(q.mask(), [(kx - 4.5, ky - 12), (kx + 4.5, ky - 12), (kx + 3.5, ky + 1), (kx - 3.5, ky + 1)])
    q.fill(key, S_HI)
    q.fill(q.inner_shadow(key, -2, -1, 1), S_SH, 0.9)
    q.outline(key, 0.5, ink)
    q.fill(q.inner_shadow(face, -8, -3, 6), S_SH, 0.5)
    corn = q.poly(q.mask(), top + [(x, y + 5) for x, y in reversed(top)])
    q.fill(corn, S_HI)
    q.fill(q.soften(q.poly(q.mask(), [(x, y + 5) for x, y in top] + [(x, y + 10) for x, y in reversed(top)]), 2), (40, 38, 34), 0.3)
    q.outline(q.union(face, opening), 0.6, ink)
    # il riflesso nell'acqua, spezzato
    refl = q.mask()
    for i in range(12):
        y = water + 2 + i * 2
        q.stroke(refl, [(a + rng.uniform(0, 12), y), (b - rng.uniform(0, 12), y)], 1.0)
    hole_r = q.poly(q.mask(), [(mid - span / 2, water)] + [(x, 2 * water - y) for x, y in arch] + [(mid + span / 2, water)])
    q.fill(q.minus(q.soften(refl, 0.5), hole_r), (198, 202, 192), 0.45)
    # il parapetto traforato a cerchi intrecciati, come quelli veri, e gli obelischi alti ai capi
    _openwork(q, top, 20, ink, seed=83)  # alto come nelle foto: circa un quarto del ponte
    for x in (a + 6, b - 6):
        _obelisk_q(q, x, deck + 1, 1.0, 84)
    t.img.alpha_composite(q.result(), (int(round((x0 - t.ox) * t.k)), int(round((y0 - t.oy) * t.k))))


def bridges_and_statues(name):
    """Le statue sulla sponda di là del canale e i ponticelli (#378, chiesto da Riccardo): la fila di statue del Prato
    lungo tutto l'ovale, più piccole lontano; il ponticello dietro la fontana visto di fronte, e i due alle punte
    dell'isola visti di fianco, che portano alla sponda di fuori. Sono dietro la piazza: non ci si cammina sopra.
    Prop dietro in x 960, y 690, a 2x: x -420..2340, y 340..690."""
    x0, y0, w, h = -420, 340, 2760, 350
    t = Tela(w, h, origin=(x0, y0), ss=1)
    cx, cy, rx, ry = CANAL_OVAL
    rng = rand(3786)
    # la fila di statue sulla sponda di là, lungo l'ovale (non dove arrivano i ponticelli)
    for i in range(34):
        a = math.pi + math.pi * (i + 0.5) / 34
        x, y = cx + (rx + 10) * math.cos(a), cy + (ry + 6) * math.sin(a)
        if abs(x - 960) < 70 or y > 498:  # vicino al ponte nord e ai ponti di fianco niente statue
            continue
        depth = (y - (cy - ry)) / ry  # 0 lontano (dietro), 1 ai lati
        ring_statue(t, x, y, 0.5 + 0.45 * depth, rng, 0.22 - 0.16 * depth)
    # il ponte nord, dietro la fontana, visto di fronte: il piano che sale verso la sponda di là tra i due parapetti a
    # balaustrini, e ai quattro capi i piedistalli con le statue (come il ponte nord del Prato)
    near_y, far_y = 472, 449
    nw, fw = 24, 17
    stone, stone_sh, ink = (200, 194, 180, 255), (154, 148, 136, 255), (80, 74, 68, 255)
    deck = [(960 - nw, near_y), (960 - fw, far_y), (960 + fw, far_y), (960 + nw, near_y)]
    t.poly(deck, fill=(188, 180, 164, 255))
    t.line([(960, near_y), (960, far_y)], fill=(170, 162, 148, 255), width=0.6)
    for side in (-1, 1):
        for k in range(10):
            u = k / 9
            bx, by = 960 + side * (nw + (fw - nw) * u), near_y + (far_y - near_y) * u
            t.line([(bx, by), (bx, by - 9 + 3 * u)], fill=stone_sh, width=1.3 - 0.5 * u)
        t.line([(960 + side * nw, near_y - 10), (960 + side * fw, far_y - 6)], fill=stone, width=2.4)
        t.line([(960 + side * nw, near_y - 10.8), (960 + side * fw, far_y - 6.6)], fill=(232, 228, 216, 255), width=0.7)
        for px, py, sc, hz in ((960 + side * (fw + 3), far_y, 0.42, 0.2), (960 + side * (nw + 4), near_y, 0.55, 0.12)):
            t.rect(px - 6 * sc, py - 14 * sc, px + 6 * sc, py, fill=stone, ink=True, width=0.5, ink_col=ink)
            ring_statue(t, px, py - 14 * sc, sc, rng, hz)
    t.poly(deck, ink=True, width=0.8, ink_col=ink)
    # i ponti est e ovest dallo schizzo di Riccardo (#378): dalla punta dell'isola alla sponda di fuori, con l'asse della
    # passerella sulla linea del piano dove si gioca
    # i ponti est e ovest (#378, come al Prato): sulle punte dell'isola, di fianco, dalla striscia dove si gioca alla
    # piazza di fuori, oltre il canale
    for side in (-1, 1):
        _profile_bridge(t, 960 + side * 862, oval_edge_x(560, side) + side * 30, rng)
    t.save(OUT, name, colors=256)


def lawn(t):
    base = 560
    rng = rand(11)
    t.rect(-300, base - 50, 2200, base - 18, fill=(58, 72, 54, 255))  # il prato dell'Isola Memmia, spento
    # sotto il prato il canale dell'isola (#378, idea di Riccardo): la sponda di pietra e poi l'acqua stagnante che
    # va fino al canale davanti (life.outerWater), più chiara e velata perché più lontana
    t.rect(-300, base - 18, 2200, base - 12, fill=(176, 170, 156, 255))
    t.rect(-300, base - 14, 2200, base - 12, fill=(138, 132, 120, 255))
    t.line([(-300, base - 18), (2200, base - 18)], fill=(90, 86, 78, 255), width=0.8)
    steps = 40
    for i in range(steps):
        y0 = base - 12 + i * (1110 - base + 12) / steps
        y1 = base - 12 + (i + 1) * (1110 - base + 12) / steps + 1
        u = min(1.0, i / 12)
        col = mix((104, 130, 122, 255), (66, 90, 84, 255), u)  # verde acqua torbido: si legge come acqua, non prato
        t.rect(-300, y0, 2200, y1, fill=col)
    t.rect(-300, base - 12, 2200, base - 8, fill=(84, 96, 74, 255))  # il riflesso scuro della sponda
    rng_w = rand(3781)
    for k in range(260):  # alghe e lenti d'acqua vicino alla sponda, riflessi chiari più giù
        x = rng_w.uniform(-300, 2200)
        y = base - 7 + rng_w.uniform(0, 1) ** 2 * 12
        t.ellipse(x - 2.2, y - 0.6, x + 2.2, y + 0.6, fill=(132, 142, 84, 255))
    for k in range(320):  # i riflessi chiari del cielo, a pennellate orizzontali
        x = rng_w.uniform(-300, 2200)
        y = base - 6 + rng_w.uniform(0, 1) ** 1.3 * 120
        t.line([(x, y), (x + rng_w.uniform(8, 30), y)], fill=(156, 182, 176, 255), width=0.6 + rng_w.random() * 0.6)
    # memmia_vista() non serve più: il canale dietro l'isola con le statue e i ponticelli ora sta davanti a questo strato
    # la canaletta lontana con la balaustra e la seconda fila di statue
    t.rect(-300, base - 40, 2200, base - 30, fill=(146, 142, 132, 255))
    for sx in range(-240, 2200, 120):
        if abs(sx - 960) < 50:
            rng.random()  # davanti al ponticello niente statua, ma la serie del caso resta la stessa
            continue
        small_statue(t, sx, base - 36, rng)
    # platani, poi il vialetto, le panchine e i lampioni davanti
    for tx in range(-230, 2200, 160):  # più fitti dal #288
        x, r = tx + rng.randint(-40, 40), rng.randint(48, 70)
        if VISTA[0] - 30 < x < VISTA[1] + 30:
            continue  # dietro la fontana gli alberi si aprono sull'isola (#378)
        plane_tree(t, x, base - 50, r, rng)
    for x in range(-300, 2200, 6):  # erba a ciuffi sul bordo
        t.line([(x, base - 50), (x + 2, base - 56 - (x * 7 % 5))], fill=(70, 86, 62, 255), width=0.8)
    t.rect(-300, base - 50, 2200, base - 44, fill=(124, 118, 106, 255))
    for bx in range(-140, 2200, 380):
        t.rect(bx, base - 63, bx + 42, base - 58, fill=(104, 80, 60, 255), ink=True, width=0.6, ink_col=(50, 44, 40, 255))
        t.rect(bx, base - 70, bx + 42, base - 66, fill=(104, 80, 60, 255), ink=True, width=0.6, ink_col=(50, 44, 40, 255))
        for lx in (bx + 3, bx + 37):
            t.rect(lx, base - 58, lx + 3, base - 50, fill=(54, 54, 56, 255))
    for lx in range(-170, 2200, 300):  # gli stessi x di daycycle.lamps (x - 260)
        lamp(t, lx, base - 50, 92)
    # dettaglio nascosto: un papiro di laurea appeso a un lampione
    px = -170 + 300 * 4
    t.rect(px + 3, base - 122, px + 10, base - 104, fill=(214, 206, 182, 255), ink=True, width=0.6, ink_col=(60, 56, 50, 255))
    t.line([(px + 2, base - 113), (px + 11, base - 113)], fill=(150, 60, 56, 255), width=1.4)


PLAN = (960, 520, 880, 50)  # la pianta dell'isola (#378, chiesto da Riccardo): mezzo ovale dietro il bordo dritto


def piano(name):
    """Il piano dell'isola visto un po' dall'alto (#300; ovale dal #378, come l'Isola Memmia vera): il bordo dove si
    cammina resta dritto a y 520 (il più chiaro, lo disegna bordo.png), e dietro il lastricato è mezzo ovale che al
    centro arriva al ciglio di y 470 e ai lati scende a toccare gli angoli. Le lastre corrono ad anelli attorno al
    centro, più strette dove sono più lontane, con i giunti che vanno verso il centro. Sotto statue e platani
    un'ombra morbida di contatto li appoggia a terra. Prop in x 960, y 524, dietro alle statue."""
    x0, x1, y0, y1 = 70, 1850, 404, 524
    t = Tela(x1 - x0, y1 - y0, origin=(x0, y0))
    cx, cy, rx, ry = PLAN

    def pt(f, a):  # il punto dell'anello f (0 centro, 1 ciglio) all'angolo a (0 a destra, pi a sinistra, pi/2 in fondo)
        return (cx + rx * f * math.cos(a), cy - ry * f * math.sin(a))

    rng = rand(300)
    far_col = mix(EDGE, STONE, 0.62)
    # il piano dell'isola è in terriccio bianco e ghiaino come i viali del Prato (#378, chiesto da Riccardo): la fascia
    # dove si combatte, il viale verso la fontana e l'anello attorno alla vasca; i prati si dipingono sopra
    from pittura import Quadro
    qg = Quadro(x1 - x0, y1 - y0, origin=(x0, y0))
    half = qg.poly(qg.mask(), [pt(1.0, math.pi * u / 160) for u in range(161)])
    paint_gravel(qg, half, 3001, cy - ry, 520)
    t.img.alpha_composite(qg.img)
    # il ciglio dell'ovale: lo spigolo della pietra e un filo d'ombra, poi c'è il canale
    t.line([pt(1.0, math.pi * u / 120) for u in range(121)], fill=shade(far_col, 0.7), width=1.0)
    # l'isola è soprattutto prato (#378, dalle foto di Riccardo): i prati tagliati a strisce dietro la fascia lastricata
    # dove si combatte, lasciando il viale bianco verso la fontana e l'anello lastricato attorno alla vasca
    def in_plan(x, y, inset=0.0):
        dx = (x - cx) / (rx - inset * 8)
        return y < cy - 1 and (y - cy) ** 2 / (ry - inset) ** 2 + dx * dx < 1

    lawn_pts_l, lawn_pts_r = [], []
    for side, pts_ in ((-1, lawn_pts_l), (1, lawn_pts_r)):
        # dal viale (x 960 ± 34) verso la punta, tra la fascia davanti (y 506) e il ciglio (meno il cordolo)
        for i in range(41):
            a = math.pi / 2 - side * (math.pi / 2) * i / 40
            pts_.append((cx + (rx - 26) * math.cos(a), cy - (ry - 3) * math.sin(a)))
        pts_[:] = [(x, y) for x, y in pts_ if abs(x - cx) > 34 and y < 506]
        pts_.append((cx + side * (rx - 60), 506))
        pts_.append((cx + side * 34, 506))
    ql = Quadro(x1 - x0, y1 - y0, origin=(x0, y0))
    lawn_m = ql.mask()
    for pts_ in (lawn_pts_l, lawn_pts_r):
        if len(pts_) > 3:
            ql.poly(lawn_m, pts_)
    rx_f, ry_f = 232, 22  # l'anello in ghiaia attorno alla vasca
    lawn_m = ql.minus(lawn_m, ql.ellipse(ql.mask(), cx - rx_f, 484 - ry_f, cx + rx_f, 484 + ry_f))
    lawn_m = ql.smooth(lawn_m, 0.8)
    paint_grass(ql, lawn_m, 3002, cy - ry, 506)
    t.img.alpha_composite(ql.img)
    # il cordolo bianco sul ciglio dell'isola, con la fila di statue sui piedistalli (l'anello di dentro del Prato)
    t.line([pt(1.0, math.pi * u / 120) for u in range(121)], fill=(220, 214, 200, 255), width=2.4)
    t.line([(x, y + 1.2) for x, y in [pt(1.0, math.pi * u / 120) for u in range(121)]], fill=(150, 144, 130, 255), width=0.7)
    srng = rand(3787)
    for i in range(22):
        a = math.pi * (i + 0.5) / 22
        x, y = pt(1.0, a)
        if abs(x - cx) < 60 or abs(x - cx) > rx - 40:
            continue  # il viale e le punte dove arrivano i ponti
        depth = (cy - y) / ry  # 1 in fondo
        ring_statue(t, x, y + 1, 0.56 - 0.12 * depth, srng, 0.12 + 0.08 * depth)
    # i filari di alberelli sui prati, come lungo i viali dell'isola: più piccoli dove sono più lontani
    from pittura import Quadro
    q = Quadro(x1 - x0, y1 - y0, origin=(x0, y0))
    trees = []
    for side in (-1, 1):
        for j in range(6):
            x = cx + side * (230 + j * 92)
            y = 486 - j * 1.2 + (j % 2) * 2
            trees.append((x, y))
    trees.sort(key=lambda p: p[1])
    for tx_, ty_ in trees:
        hgt = 34 - (500 - ty_) * 0.3
        crown = q.mask()
        trng = random.Random(int(tx_))
        for b in range(9):
            bx = tx_ + trng.uniform(-0.32, 0.32) * hgt * 0.7
            by = ty_ - hgt * (0.45 + trng.uniform(0, 0.5))
            br = hgt * trng.uniform(0.18, 0.28)
            q.ellipse(crown, bx - br, by - br, bx + br, by + br)
        crown = q.smooth(crown, 1.4)
        trunk = q.mask()
        q.stroke(trunk, [(tx_, ty_), (tx_, ty_ - hgt * 0.42)], 2.2)
        q.fill(trunk, (98, 84, 68))
        q.fill(q.soften(q.ellipse(q.mask(), tx_ - hgt * 0.4, ty_ - 2, tx_ + hgt * 0.5, ty_ + 2.5), 1.5), (30, 40, 24), 0.5)
        q.fill(crown, (56, 80, 50))
        q.fill(q.grain(crown, 0.4, int(tx_), 1.0), (40, 60, 38))
        q.fill(q.inner_shadow(crown, -hgt * 0.15, -hgt * 0.1, hgt * 0.1), (34, 50, 32), 0.8)
        q.fill(q.rim(crown, -1.2, -1.4, 1.0), (104, 132, 80), 0.75)
        q.outline(crown, 0.6, (30, 40, 28))
    t.img.alpha_composite(q.img)
    # l'erba sulla piazza (#378, chiesto da Riccardo): sotto i platani l'erba cresce nelle fughe e sfuma nel lastricato,
    # senza cordolo; e ciuffi tra le lastre
    from pittura import Quadro
    qa = Quadro(x1 - x0, y1 - y0, origin=(x0, y0))
    for tx, rxa in ((410, 96), (1510, 96)):
        bed = qa.soften(qa.ellipse(qa.mask(), tx - rxa, 499, tx + rxa, 517), 5)
        qa.fill(bed, (84, 106, 62), 0.9)
        qa.fill(qa.grain(bed, 0.7, tx, 0.7), (110, 134, 78), 0.8)
    t.img.alpha_composite(qa.img)
    for tx, rxa in ((410, 96), (1510, 96)):
        for k in range(520):
            u, rr = rng.uniform(0, math.tau), math.sqrt(rng.random())
            gx, gy = tx + (rxa - 4) * rr * math.cos(u), 508 + 8 * rr * math.sin(u)
            t.line([(gx, gy), (gx + rng.uniform(-0.8, 0.8), gy - rng.uniform(1.5, 3.5))], fill=rng.choice([(64, 82, 50, 255), (112, 134, 80, 255), (96, 118, 70, 255)]), width=0.6)
    # le ombre (#378, chiesto da Riccardo: niente cerchi): quelle lunghe che seguono il sole le disegna il gioco; qui solo
    # il contatto morbido sotto le basi delle statue e, sotto le chiome, la penombra a chiazze delle foglie
    qs = Quadro(x1 - x0, y1 - y0, origin=(x0, y0))
    srng = rand(3792)
    for sx, w in ((310, 36), (540, 40), (690, 36), (1230, 36), (1380, 40), (1610, 36)):
        qs.fill(qs.soften(qs.ellipse(qs.mask(), sx - w * 0.6, 514.5, sx + w * 0.6, 519.5), 1.6), (30, 28, 26), 0.3)
    for tx in (410, 1510):
        dapple = qs.mask()
        for k in range(16):
            bx, by, r = tx + srng.uniform(-90, 90), srng.uniform(500, 515), srng.uniform(10, 22)
            qs.ellipse(dapple, bx - r * 1.6, by - r * 0.3, bx + r * 1.6, by + r * 0.3)
        holes = qs.mask()
        for k in range(22):  # la luce che passa tra le foglie
            bx, by, r = tx + srng.uniform(-80, 80), srng.uniform(501, 514), srng.uniform(2, 5)
            qs.ellipse(holes, bx - r * 1.6, by - r * 0.3, bx + r * 1.6, by + r * 0.3)
        qs.fill(qs.minus(qs.soften(dapple, 3), qs.soften(holes, 1)), (28, 34, 24), 0.22)
    t.img.alpha_composite(qs.img)
    t.save(OUT, name, colors=256)


GROUND = 522  # il pavimento dell'isola, dove poggiano palazzo, statue e platani


# --- l'isola sospesa (#288): fontana dell'Isola Memmia, fondamenta sotto la piazza, platani sulla piazza ---
WATER, WATER_S, WATER_L = (92, 132, 136, 255), (70, 106, 112, 255), (150, 186, 186, 255)  # verde acqua spento, non il blu di P2
IRON = (44, 42, 44, 255)


def bollard(t, x, base, h, stone=MARBLE, sh=MARBLE_SHADE):
    """Il paracarro della fontana: dado di pietra con lo zoccolo, il collarino e la palla in cima."""
    w = h * 0.36
    t.rect(x - w * 0.62, base - h * 0.14, x + w * 0.62, base, fill=stone, ink=True, width=0.9)  # zoccolo
    t.rect(x + w * 0.1, base - h * 0.14, x + w * 0.62, base, fill=sh)
    t.rect(x - w / 2, base - h * 0.72, x + w / 2, base - h * 0.14, fill=stone, ink=True, width=0.9)  # dado
    t.rect(x + w * 0.12, base - h * 0.72, x + w / 2, base - h * 0.14, fill=sh)
    t.rect(x - w * 0.58, base - h * 0.78, x + w * 0.58, base - h * 0.72, fill=stone, ink=True, width=0.8)  # cornice
    t.rect(x - w * 0.22, base - h * 0.84, x + w * 0.22, base - h * 0.78, fill=sh, ink=True, width=0.7)  # collarino
    r = w * 0.48
    cy = base - h * 0.84 - r
    t.circle(x, cy, r, fill=stone)
    t.chord(x - r, cy - r, x + r, cy + r, -60, 110, fill=sh)
    t.circle(x - r * 0.35, cy - r * 0.35, r * 0.22, fill=light(stone, 1.06))
    t.circle(x, cy, r, ink=True, width=0.9)


def railing(t, x0, x1, y_top, y_bot, curls=True):
    """La ringhiera di ferro battuto tra due paracarri: due correnti, i ferri verticali e il riccio in mezzo."""
    t.line([(x0, y_top), (x1, y_top)], fill=IRON, width=1.4)
    t.line([(x0, y_bot), (x1, y_bot)], fill=IRON, width=1.1)
    n = max(2, int((x1 - x0) / 7))
    for k in range(1, n):
        x = x0 + (x1 - x0) * k / n
        t.line([(x, y_top), (x, y_bot)], fill=IRON, width=0.7)
    if curls:
        cx, cy = (x0 + x1) / 2, (y_top + y_bot) / 2
        h = (y_bot - y_top) / 2
        for side in (-1, 1):
            t.arc(cx + side * h * 0.9 - h * 0.9, cy - h * 0.9, cx + side * h * 0.9 + h * 0.9, cy + h * 0.9, 0, 360, fill=IRON, width=1.0)
            t.arc(cx + side * h * 1.6 - h * 0.45, cy - h * 0.45, cx + side * h * 1.6 + h * 0.45, cy + h * 0.45, 0, 300, fill=IRON, width=0.8)


# la vasca (#378): centro e raggi dell'anello di pietra, nella prospettiva del piano. Tutta dietro la linea dove si
# combatte (Riccardo: il ciclista passava attraverso la ringhiera): il davanti dell'anello arriva a y 504, non a 520
FOUNTAIN = (960, 480, 150, 17)
RING = (960, 484, 186, 20)  # l'anello dei paracarri con la ringhiera attorno alla vasca


def _ring_posts(front):
    """I paracarri attorno alla vasca: angoli sull'ovale, metà dietro (front False) o davanti. Più vicini = più grandi
    e più in basso. Restituisce [(x, piede, altezza)] da sinistra a destra."""
    cx, cy, rx, ry = RING
    out = []
    for k in range(10):
        a = math.pi * (k + 0.5) / 10 if front else math.pi + math.pi * (k + 0.5) / 10
        x, y = cx + rx * math.cos(a), cy + ry * math.sin(a)
        out.append((x, y, 20 + 10 * (y - (cy - ry)) / (2 * ry)))
    return sorted(out)


def fountain_back():
    """La fontana dell'Isola Memmia nella prospettiva della piazza (#378, chiesto da Riccardo): la vasca è un ovale
    schiacciato come il lastricato attorno, il lato lontano tocca il ciglio di dietro e il davanti arriva al bordo
    dove si cammina. L'anello di pietra con i giunti, l'orlo interno in ombra sopra l'acqua, la parete curva davanti
    con le macchie d'umido e il muschio; dietro, la metà lontana dei paracarri con la ringhiera, più piccoli.
    I piedi sono a (960, 524); i getti li disegna il gioco e partono dal centro dell'acqua (960, 482)."""
    t = Tela(440, 80, origin=(740, 444))
    cx, cy, rx, ry = FOUNTAIN
    stone, stone_sh, stone_l = (214, 208, 194, 255), (176, 168, 154, 255), (232, 228, 216, 255)

    def oval(cx_, cy_, rx_, ry_, a0=0.0, a1=math.tau, n=48):
        return [(cx_ + rx_ * math.cos(a0 + (a1 - a0) * i / n), cy_ + ry_ * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]

    # la metà lontana dell'anello di paracarri, dietro la vasca
    posts = _ring_posts(False)
    for (x0_, y0_, h0), (x1_, y1_, h1) in zip(posts, posts[1:]):
        railing(t, x0_, x1_, y0_ - h0 * 0.62, y0_ - h0 * 0.2, curls=True)
    for x, y, h in posts:
        bollard(t, x, y, h, stone=(206, 200, 186, 255), sh=(172, 164, 150, 255))
    # l'ombra della vasca sul lastricato, morbida, davanti e a destra (la luce viene da sinistra in alto)
    for i, (grow, al) in enumerate(((10, 20), (6, 28), (3, 36))):
        t.glaze(oval(cx + 6, cy + 10, rx + grow, ry + grow * 0.35), (40, 36, 32, al))
    # la parete curva davanti: dall'orlo giù di 9, con le macchie d'umido e il muschio sul piede
    wall = oval(cx, cy, rx, ry, 0, math.pi) + list(reversed(oval(cx, cy + 9, rx, ry, 0, math.pi)))
    t.poly(wall, fill=stone_sh)
    rng = rand(378)
    for k in range(14):  # le macchie scure d'umido che scendono dall'orlo
        a = rng.uniform(0.15, math.pi - 0.15)
        x, y = cx + rx * math.cos(a), cy + ry * math.sin(a)
        t.glaze([(x - 4, y), (x + 4, y), (x + 3, y + rng.uniform(5, 9)), (x - 2, y + rng.uniform(6, 9))], (90, 92, 76, 60))
    for k in range(40):  # muschio a ciuffi dove la parete tocca terra
        a = rng.uniform(0.1, math.pi - 0.1)
        x, y = cx + rx * math.cos(a), cy + 9 + ry * math.sin(a)
        t.circle(x, y - 1, rng.uniform(1.0, 2.0), fill=MUSCHIO if k % 2 else shade(MUSCHIO, 0.85))
    for k in range(1, 12):  # i giunti tra i conci della parete
        a = math.pi * k / 12
        x, y = cx + rx * math.cos(a), cy + ry * math.sin(a)
        t.line([(x, y), (x, y + 9)], fill=(140, 132, 120, 255), width=0.7)
    t.poly(wall, ink=True, width=1.0, ink_col=(70, 64, 58, 255))
    # l'anello di pietra: il piano dell'orlo, chiaro, e l'orlo interno lontano in ombra sopra l'acqua
    t.poly(oval(cx, cy, rx, ry), fill=stone)
    t.poly(oval(cx, cy, rx - 10, ry - 3.5), fill=stone_sh)
    for k in range(24):  # i giunti radiali dei conci dell'orlo
        a = math.tau * k / 24
        t.line([(cx + (rx - 10) * math.cos(a), cy + (ry - 3.5) * math.sin(a)), (cx + rx * math.cos(a), cy + ry * math.sin(a))], fill=(160, 152, 140, 255), width=0.7)
    t.line(oval(cx, cy, rx - 1.5, ry - 0.6, math.pi * 1.05, math.pi * 1.95, 30), fill=stone_l, width=1.0)  # la luce sul filo dell'orlo
    # l'acqua dipinta: più bassa dell'orlo, in ombra sotto il lato lontano, i riflessi del cielo e gli anelli d'onda
    from pittura import Quadro, wobble
    q = Quadro(440, 80, origin=(740, 444))
    wm = q.poly(q.mask(), oval(cx, cy + 1.5, rx - 12, ry - 4.5))
    q.fill(wm, WATER)
    q.fill(q.inner_shadow(wm, 0, 6, 3), WATER_S, 0.9)
    for k in range(18):
        y = cy - 6 + rng.uniform(0, 14)
        x0 = cx + rng.uniform(-rx * 0.8, rx * 0.6)
        ln = rng.uniform(10, 40)
        pts = wobble([(x0 + ln * j / 6, y + math.sin(j) * 0.4) for j in range(7)], 0.4, k, closed=False)
        q.fill(q.intersect(q.soften(q.stroke(q.mask(), pts, rng.uniform(0.7, 1.5)), 0.4), wm), WATER_L, rng.uniform(0.35, 0.8))
    for r_ in (24, 44, 68, 96):
        for j in range(6):
            a0 = j / 6 * math.tau + r_ * 0.1
            arc = [(cx + r_ * math.cos(a0 + i * 0.12), cy + 2 + r_ * 0.11 * math.sin(a0 + i * 0.12)) for i in range(5)]
            q.fill(q.intersect(q.soften(q.stroke(q.mask(), arc, 0.7), 0.3), wm), (184, 212, 210), 0.5 - r_ / 220)
    t.img.alpha_composite(q.img)
    # l'ugello di bronzo al centro, da cui escono i tre getti
    t.ellipse(cx - 9, cy - 1, cx + 9, cy + 4, fill=(96, 92, 80, 255), ink=True, width=0.8)
    t.ellipse(cx - 6, cy - 3, cx + 6, cy + 1, fill=(124, 118, 100, 255), ink=True, width=0.7)
    t.poly(oval(cx, cy, rx, ry), ink=True, width=1.1, ink_col=(70, 64, 58, 255))
    t.save(OUT, "fontana.png")


def fountain_front():
    """La metà vicina dei paracarri con la ringhiera attorno alla vasca (#378): più grandi e più in basso di quelli
    dietro, ma sempre dietro la linea dove si combatte, quindi dietro ai lottatori. Piedi a (960, 530)."""
    t = Tela(440, 64, origin=(740, 466))
    posts = _ring_posts(True)
    for (x0_, y0_, h0), (x1_, y1_, h1) in zip(posts, posts[1:]):
        hm = (h0 + h1) / 2
        t.line([(x0_, y0_ - h0 * 0.62), (x1_, y1_ - h1 * 0.62)], fill=IRON, width=1.4)
        t.line([(x0_, y0_ - h0 * 0.2), (x1_, y1_ - h1 * 0.2)], fill=IRON, width=1.1)
        n = max(2, int((x1_ - x0_) / 7))
        for k in range(1, n):
            u = k / n
            x = x0_ + (x1_ - x0_) * u
            yt = y0_ - h0 * 0.62 + ((y1_ - h1 * 0.62) - (y0_ - h0 * 0.62)) * u
            yb = y0_ - h0 * 0.2 + ((y1_ - h1 * 0.2) - (y0_ - h0 * 0.2)) * u
            t.line([(x, yt), (x, yb)], fill=IRON, width=0.7)
        mx, my = (x0_ + x1_) / 2, (y0_ + y1_) / 2 - hm * 0.41
        for side in (-1, 1):
            t.arc(mx + side * 4 - 3.5, my - 3.5, mx + side * 4 + 3.5, my + 3.5, 0, 360, fill=IRON, width=0.9)
    for x, y, h in posts:
        bollard(t, x, y, h)
    t.save(OUT, "fontana-davanti.png")


def plane_tree_prop(name):
    """Un platano sulla piazza (#288; dipinto con paint_tree dal #378): piedi a (410, 522), la chioma da y 110 a 360,
    sopra le teste, così lascia vedere il palco."""
    from pittura import Quadro
    q = Quadro(300, 420, origin=(260, 102))
    paint_tree(q, 410, 522, 132, 51, 0.0, th=196)
    q.save(OUT, name)


if __name__ == "__main__":
    paving()
    quay_wall()
    coping("bordo.png")
    slab()
    statue_painted("statua-ponte.png", 112, 180, "giovane")  # regge la lastra a y 410 dalla piazza a y 520 (+2 di appoggio)
    statue_painted("statua-alta.png", 192, 140, "filosofo")  # regge la lastra a y 330
    statue_painted("statua-piazza.png", 142, 180, "dama")  # regge la lastra a y 380
    # palazzo(), balcony_rail(), balcony_floor() e foundations() disegnavano la Padova col palazzo, ora ferma in
    # padova-palazzo (#378): sono nella storia di git, fino al commit ea87a72
    fountain_back()
    fountain_front()
    fianco("fianco.png")  # dal #378 al posto di foundations(): l'isola sta nel canale
    plane_tree_prop("platano.png")
    piano("piano.png")
    canal_back("canale-dietro.png")
    ansa("ansa.png")
    bridges_and_statues("ponticelli.png")
    near_bank("primo-piano.png")
    front_bridges("ponti-davanti.png")
    near_statues("statue-primo-piano.png")
    layer("sfondo-0.png", sky, "sfondo-0-luci.png", lift=LIFT[0])
    layer("sfondo-1.png", buildings, "sfondo-1-luci.png", lift=LIFT[1])
    layer("sfondo-2.png", lawn, "sfondo-2-luci.png", lift=LIFT[2])
