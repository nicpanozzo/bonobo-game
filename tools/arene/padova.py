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


def fianco(name):
    """Il fianco dell'isola ovale (#378, chiesto da Riccardo: la piattaforma deve sembrare ovale). Il bordo dove si
    cammina resta dritto a y 520, ma il muro sotto è un cilindro visto un po' dall'alto: il piede segue una curva, alto
    70 al centro e sempre più basso verso le punte, i blocchi si stringono dove il muro gira (la stessa pietra di
    riva.png, piegata), e l'ombra cresce ai lati; alle punte il muro gira dietro. Sotto, lo zoccolo di mattoni con gli
    archi che scende nell'acqua del canale. Il gioco ci disegna sopra solo la copertina (bordo.png).
    Prop dietro in x 960, y 700, a 2x: x 60..1860, y 516..700."""
    import numpy as np
    x0, y0, w, h = 60, 516, 1800, 184
    k = 2
    W, H = w * k, h * k
    cx, rx = 960, 880
    tile = np.asarray(Image.open(os.path.join(OUT, "riva.png")).convert("RGBA")).astype(np.float32)
    th, tw = tile.shape[0], tile.shape[1]  # 140×480: 70×240 di mondo
    xs = x0 + (np.arange(W) + 0.5) / k
    d = np.clip((xs - cx) / rx, -1, 1)
    sfac = np.sqrt(1 - d * d)
    wall_bot = 520 + 70 * sfac ** 0.6
    arc = rx * np.arcsin(d)  # la distanza lungo il muro: i blocchi si stringono verso le punte
    out = np.zeros((H, W, 4), np.float32)
    ys = y0 + (np.arange(H) + 0.5) / k
    Y, _ = np.meshgrid(ys, np.arange(W), indexing="ij")
    inside = (Y >= 520) & (Y <= wall_bot[None, :]) & (np.abs(xs - cx)[None, :] <= 860)
    v = (Y - 520) / np.maximum(1e-3, (wall_bot[None, :] - 520)) * (th - 1)
    u = np.mod((arc[None, :] - arc.min()) * k, tw)
    vi = np.clip(v.astype(int), 0, th - 1)
    ui = np.clip(np.broadcast_to(u, vi.shape).astype(int), 0, tw - 1)
    sample = tile[vi, ui]
    shadeK = (0.55 + 0.45 * sfac ** 0.5)[None, :, None]  # il muro gira: verso le punte va in ombra
    sample[..., :3] *= shadeK
    out[inside] = sample[inside]
    img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")
    t = Tela(w, h, origin=(x0, y0), ss=1)
    # lo zoccolo di mattoni sotto il muro, che segue la stessa curva e scende nell'acqua
    brick, brick_s, mortar = (122, 84, 68, 255), (100, 68, 56, 255), (80, 60, 52, 255)
    xs_w = [100 + i * 1720 / 120 for i in range(121)]

    def bot(x, amp):
        dd = max(-1.0, min(1.0, (x - cx) / rx))
        return 520 + amp * (1 - dd * dd) ** 0.3

    top_pts = [(x, bot(x, 70)) for x in xs_w]
    base_pts = [(x, bot(x, 150)) for x in xs_w]
    plinth = top_pts + list(reversed(base_pts))
    bricks = Tela(w, h, origin=(x0, y0), ss=1, bg=brick)
    for row in range(40):
        y = 520 + row * 5
        bricks.line([(x0, y), (x0 + w, y)], fill=mortar, width=0.5)
        off = 0 if row % 2 else 5
        for x in range(x0 + off, x0 + w, 10):
            bricks.line([(x, y), (x, y + 5)], fill=mortar, width=0.4)
    t.paste_inside(bricks, plinth)
    for ax in (380, 700, 1220, 1540):  # gli archi di scarico, a filo dell'acqua
        aw, top = 120, bot(ax, 70) + 8
        t.pieslice(ax - aw / 2, top, ax + aw / 2, top + aw * 0.55, 180, 360, fill=brick_s)
        t.rect(ax - aw / 2, top + aw * 0.27, ax + aw / 2, bot(ax, 150), fill=brick_s)
        for kk in range(11):
            a0, a1 = math.pi * kk / 11, math.pi * (kk + 1) / 11
            rr, r2, cyy = aw / 2, aw / 2 + 8, top + aw * 0.275
            pts = [(ax - rr * math.cos(a0), cyy - rr * 0.5 * math.sin(a0)), (ax - r2 * math.cos(a0), cyy - r2 * 0.5 * math.sin(a0)),
                   (ax - r2 * math.cos(a1), cyy - r2 * 0.5 * math.sin(a1)), (ax - rr * math.cos(a1), cyy - rr * 0.5 * math.sin(a1))]
            t.poly(pts, fill=(150, 142, 128, 255) if kk % 2 else (122, 116, 104, 255), ink=True, width=0.6)
    t.glaze(plinth, (30, 26, 24, 60))  # lo zoccolo sta nell'ombra del muro
    for x in range(110, 1820, 6):  # verso le punte anche lo zoccolo gira in ombra
        dd = abs((x - cx) / rx)
        if dd > 0.75:
            t.glaze([(x, bot(x, 70)), (x + 6, bot(x + 6, 70)), (x + 6, bot(x + 6, 150)), (x, bot(x, 150))], (20, 18, 16, int(110 * (dd - 0.75) / 0.25)))
    t.line(top_pts, fill=(60, 50, 44, 255), width=0.9)
    t.line(base_pts, fill=(60, 50, 44, 255), width=0.9)
    base_img = t.result()
    base_img.alpha_composite(img)
    # le punte: il muro che gira dietro, un quarto d'ovale in ombra tra il bordo e il piede
    tt = Tela(w, h, origin=(x0, y0), ss=1)
    for side in (-1, 1):
        xe = cx + side * 860
        cap = [(xe, 520), (xe + side * 16, 512), (xe + side * 20, 520 + 6), (xe + side * 12, bot(xe, 150) - 4), (xe, bot(xe, 150))]
        tt.poly(cap, fill=(70, 66, 60, 255), ink=True, width=0.8, ink_col=(40, 36, 32, 255))
    tt.img.alpha_composite(base_img)
    tt.img.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).save(os.path.join(OUT, name), optimize=True)
    print("scritto", name, tt.img.size)


def coping(name, w=96, h=10):
    """La copertina chiara sopra le rive: il piano su cui si cammina (il più chiaro), lo spigolo e la faccia
    in ombra, i giunti tra una lastra e l'altra. Bordo calpestabile sempre chiaro (stile, sezione 7)."""
    t = Tela(w, h, wrap=True)
    t.rect(0, 0, w, h * 0.55, fill=EDGE)
    t.rect(0, 0, w, 0.8, fill=(248, 245, 236, 255))
    t.rect(0, h * 0.55, w, h, fill=(196, 189, 174, 255))
    t.rect(0, h * 0.85, w, h, fill=(170, 163, 149, 255))
    t.line([(0, h * 0.55), (w, h * 0.55)], fill=(150, 144, 132, 255), width=0.8)
    for x in (0, w / 2):
        t.line([(x, 0.6), (x, h)], fill=INK, width=1.0)
    t.line([(0, h - 0.6), (w, h - 0.6)], fill=INK, width=1.2)
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


# --- strato lontano: tetti della città, Santa Giustina e la Basilica del Santo ---
def dome(t, cx, base, r, h, fill, sh, ink, ribs=6, lantern=True, statue=False):
    """Cupola: tamburo con le finestrelle, calotta rialzata a costoloni con l'ombra a destra, lanterna."""
    t.rect(cx - r * 0.95, base - r * 0.35, cx + r * 0.95, base, fill=fill, ink=True, width=1.0, ink_col=ink)
    t.rect(cx + r * 0.4, base - r * 0.35, cx + r * 0.95, base, fill=sh)
    for i in range(1, 6):
        wx = cx - r * 0.8 + i * r * 0.27
        t.rect(wx - 1.6, base - r * 0.27, wx + 1.6, base - r * 0.09, fill=ink)
    top = base - r * 0.35
    pts = [(cx - math.cos(math.pi * i / 32) * r, top - math.sin(math.pi * i / 32) * h) for i in range(33)]
    t.poly(pts, fill=fill)
    t.poly([p for p in pts if p[0] >= cx + r * 0.15] + [(cx + r * 0.15, top)], fill=sh)
    for k in range(1, ribs):
        u = -1 + 2 * k / ribs
        t.line([(cx + u * r * math.cos(j / 10 * math.pi / 2), top - h * math.sin(j / 10 * math.pi / 2)) for j in range(11)], fill=ink, width=0.7)
    t.poly(pts, ink=True, width=1.0, ink_col=ink)
    if lantern:
        lt = top - h
        t.rect(cx - r * 0.15, lt - r * 0.3, cx + r * 0.15, lt + 1, fill=fill, ink=True, width=0.9, ink_col=ink)
        t.pieslice(cx - r * 0.17, lt - r * 0.46, cx + r * 0.17, lt - r * 0.16, 180, 360, fill=fill)
        t.line([(cx, lt - r * 0.4), (cx, lt - r * 0.62)], fill=ink, width=1.0)
        if statue:  # la statuina in cima, in sagoma
            t.circle(cx, lt - r * 0.72, 2.2, fill=ink)
            t.line([(cx - 3, lt - r * 0.62), (cx + 3, lt - r * 0.62)], fill=ink, width=1.0)
        else:
            t.circle(cx, lt - r * 0.66, 1.8, fill=ink)


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


def santa_giustina(t, cx, base):
    """Santa Giustina: la grande facciata di mattoni rimasta grezza, con i buchi delle impalcature, le otto cupole
    basse con le statuine sulle lanterne e il campanile. Più lontana del Santo: più velata."""
    F, S, I = far((160, 120, 100, 255), 0.45), far((136, 102, 86, 255), 0.45), far((80, 66, 62, 255), 0.45)
    P = far((178, 170, 156, 255), 0.45)  # piombo delle cupole
    PS = shade(P, 0.86)
    # le cupole dietro la facciata
    for dx, r in ((-60, 34), (40, 42), (130, 52), (225, 40), (300, 30)):
        dome(t, cx + dx, base - 150, r, r * 1.15, P, PS, I, ribs=4, statue=True)
    t.rect(cx - 100, base - 150, cx + 330, base, fill=F, ink=True, width=1.0, ink_col=I)  # il corpo della chiesa
    t.rect(cx + 200, base - 150, cx + 330, base, fill=S)
    # la facciata grezza, più alta, con i gradini davanti
    fx0, fx1, ftop = cx - 200, cx - 20, base - 230
    t.rect(fx0, ftop, fx1, base, fill=F, ink=True, width=1.1, ink_col=I)
    t.rect(fx0 + 120, ftop, fx1, base, fill=S)
    rng = rand(31)
    for row in range(10):  # buche pontaie in file
        for k in range(8):
            t.rect(fx0 + 10 + k * 21 + (row % 2) * 6, ftop + 12 + row * 21, fx0 + 13 + k * 21 + (row % 2) * 6, ftop + 15 + row * 21, fill=I)
    for i, px in enumerate((fx0 + 30, fx0 + 80, fx0 + 130)):  # tre portali
        t.rect(px, base - (60 if i == 1 else 46), px + 20, base, fill=I)
    t.rect(fx0 - 12, base - 8, fx1 + 12, base, fill=far((190, 182, 168, 255), 0.45), ink=True, width=0.9, ink_col=I)
    # il campanile con la cella e la punta a cono
    tx = cx + 360
    t.rect(tx - 14, base - 300, tx + 14, base, fill=F, ink=True, width=1.0, ink_col=I)
    t.rect(tx + 3, base - 300, tx + 14, base, fill=S)
    for j in range(3):
        t.rect(tx - 5, base - 290 + j * 20, tx + 5, base - 278 + j * 20, fill=I)
    t.poly([(tx - 16, base - 300), (tx + 16, base - 300), (tx, base - 350)], fill=S, ink=True, width=1.0, ink_col=I)


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
    for f in range(floors):
        fy = base - 62 - (f + 1) * fh
        cols = max(2, int((w - 20) / 30))
        step = (w - 20) / cols
        for c in range(cols):
            wx = x + 10 + c * step + step / 2 - 6
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
                if rng.random() < 0.35:
                    lit_rect(t.lights, wx + 1, fy + 11, wx + 11, fy + fh - 9)
                if rng.random() < 0.7:  # persiane aperte, a volte una chiusa
                    if rng.random() < 0.2:
                        t.rect(wx, fy + 10, wx + 12, fy + fh - 8, fill=far(win, 0.15))
                    else:
                        t.rect(wx - 5, fy + 10, wx, fy + fh - 8, fill=far(win, 0.15))
                        t.rect(wx + 12, fy + 10, wx + 17, fy + fh - 8, fill=far(shade(win, 0.85), 0.15))
                t.rect(wx - 2, fy + 8, wx + 14, fy + 10, fill=stone)
                t.rect(wx - 2, fy + fh - 8, wx + 14, fy + fh - 6, fill=stone)
                t.glaze([(wx - 1, fy + fh - 6), (wx + 15, fy + fh - 6), (wx + 16, fy + fh - 3.5), (wx, fy + fh - 3.5)], (30, 26, 24, 70))  # l'ombra del davanzale
        t.line([(x, fy), (x + w, fy)], fill=light(col, 1.08), width=1.0)  # marcapiano: il filo in luce...
        t.glaze([(x, fy + 0.6), (x + w, fy + 0.6), (x + w, fy + 3.6), (x, fy + 3.6)], (30, 26, 24, 55))  # ...e l'ombra sotto
    # il volume (#378): la luce viene da sinistra, quindi la facciata scurisce piano verso destra; il cornicione getta
    # un'ombra larga sotto di sé, e al piede il portico è più scuro (la luce non ci arriva)
    for i in range(8):
        u = i / 8
        t.glaze([(x + w * u, top), (x + w * (u + 1 / 8), top), (x + w * (u + 1 / 8), base - 62), (x + w * u, base - 62)], (30, 26, 34, int(6 + 34 * u)))
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
    for k in range(int(w / 6)):
        t.arc(x + 4 + k * 6, top - 20, x + 10 + k * 6, top - 12, 180, 360, fill=shade(roof, 0.82), width=0.7)
    t.glaze([(x - 5, top - 2), (x + w + 5, top - 2), (x + w + 5, top), (x - 5, top)], (20, 18, 16, 90))  # il sottogronda
    for cxm in (x + w * 0.22, x + w * 0.72):
        if rng.random() < 0.8:
            t.rect(cxm - 4, top - 44, cxm + 4, top - 20, fill=far((134, 98, 80, 255), 0.18), ink=True, width=0.8, ink_col=ink)
            t.poly([(cxm - 11, top - 56), (cxm + 11, top - 56), (cxm + 5, top - 42), (cxm - 5, top - 42)], fill=far((134, 98, 80, 255), 0.18), ink=True, width=0.8, ink_col=ink)
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
    # l'ombra della chioma a terra
    q.fill(q.soften(q.ellipse(q.mask(), x - r * 0.6, base - r * 0.05, x + r * 0.8, base + r * 0.07), r * 0.06), (30, 34, 26), 0.35)


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


def memmia_vista(t, base):
    """Dietro la fontana, dove c'era il palazzo (#378, idea di Nicola): l'Isola Memmia vista dal suo interno. Il canale
    dell'anello curva verso l'alto al centro (la parte più lontana del cerchio sta più in alto), con la sponda di pietra
    davanti e la fila di statue sulla sponda di là; in mezzo il ponticello che porta fuori dall'isola, con la balaustra
    e le statue ai quattro angoli. Le cose più lontane sono più piccole e più velate."""
    x0, x1, cx = VISTA[0], VISTA[1], 960
    half = (x1 - x0) / 2
    top_c = base - 92  # la sponda di là del canale, al centro
    rng = rand(378)

    def arc(x, y_mid):  # y su una curva che al centro sta a y_mid e ai lati scende a base - 50
        u = min(1.0, abs(x - cx) / half)
        return y_mid + (base - 50 - y_mid) * u * u

    xs = [x0 + i * (x1 - x0) / 60 for i in range(61)]
    grass_far = far((92, 108, 80, 255), 0.35)
    stone = far((196, 190, 176, 255), 0.25)
    stone_sh = far((150, 144, 132, 255), 0.25)
    water = far((88, 120, 120, 255), 0.25)
    # la sponda di là: un filo di prato e ghiaia, poi la fila di statue
    t.poly([(x, arc(x, top_c - 9)) for x in xs] + [(x, arc(x, top_c)) for x in reversed(xs)], fill=grass_far)
    t.poly([(x, arc(x, top_c - 2.5)) for x in xs] + [(x, arc(x, top_c)) for x in reversed(xs)], fill=far((176, 168, 150, 255), 0.35))
    for i in range(15):
        x = x0 + 30 + i * (x1 - x0 - 60) / 14
        if abs(x - cx) < 40:
            continue  # lì arriva il ponticello
        u = abs(x - cx) / half
        ring_statue(t, x, arc(x, top_c - 4), 0.42 + 0.22 * u * u, rng, 0.32 - 0.12 * u)
    # il canale, con i riflessi delle statue e del cielo
    t.poly([(x, arc(x, top_c)) for x in xs] + [(x, arc(x, top_c + 11)) for x in reversed(xs)], fill=water)
    for i in range(40):
        x = x0 + 20 + (i * 53) % (x1 - x0 - 40)
        y = arc(x, top_c + 3 + (i % 3) * 2.5)
        t.line([(x - 5, y), (x + 5, y)], fill=far((170, 196, 198, 255), 0.25), width=0.7)
    # la sponda di qua: il cordolo di pietra e il prato fino al vialetto
    t.poly([(x, arc(x, top_c + 11)) for x in xs] + [(x, arc(x, top_c + 15)) for x in reversed(xs)], fill=stone)
    t.poly([(x, arc(x, top_c + 15)) for x in xs] + [(x, base - 49) for x in reversed(xs)], fill=far((70, 88, 64, 255), 0.15))
    t.line([(x, arc(x, top_c + 15)) for x in xs], fill=stone_sh, width=0.8)
    # il ponticello, visto di fronte: il piano che sale e si allontana, le balaustre che convergono, le statue agli angoli
    near_y, far_y = top_c + 15, top_c - 3
    nw, fw = 34, 24  # mezza larghezza davanti e dietro
    deck = [(cx - nw, near_y), (cx - fw, far_y), (cx + fw, far_y), (cx + nw, near_y)]
    t.poly(deck, fill=far((184, 176, 160, 255), 0.25))
    t.poly([(cx - nw, near_y), (cx - fw, far_y), (cx - fw + 3, far_y), (cx - nw + 5, near_y)], fill=stone_sh)
    for side in (-1, 1):  # le balaustre: corrimano e colonnine che si stringono andando via
        rail = [(cx + side * nw, near_y - 12), (cx + side * fw, far_y - 8)]
        for k in range(9):
            u = k / 8
            bx = cx + side * (nw + (fw - nw) * u)
            by = near_y + (far_y - near_y) * u
            hh = 12 - 4 * u
            t.line([(bx, by), (bx, by - hh)], fill=stone_sh, width=1.4 - 0.5 * u)
        t.line(rail, fill=stone, width=2.2)
        t.line([(rail[0][0], rail[0][1] + 1.2), (rail[1][0], rail[1][1] + 1)], fill=stone_sh, width=0.6)
    t.poly(deck, ink=True, width=0.8, ink_col=far((88, 84, 78, 255), 0.25))
    for side in (-1, 1):  # le statue agli angoli del ponte: quelle dietro più piccole
        ring_statue(t, cx + side * (fw + 2), far_y, 0.45, rng, 0.28)
        ring_statue(t, cx + side * (nw + 4), near_y + 1, 0.62, rng, 0.18)


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
    q.fill(lawn, GRASS)
    q.fill(q.grain(lawn, 0.5, 31, 1.6), GRASS_D)
    tufts = q.mask()
    for k in range(2600):
        x, y = rng.uniform(x0, x0 + w), rng.uniform(split, road_top)
        ln = 2 + (y - 600) * 0.015
        q.stroke(tufts, [(x, y), (x + rng.uniform(-1, 1), y - ln)], 0.6 + (y - 600) * 0.003)
    q.fill(q.intersect(tufts, lawn), GRASS_L, 0.8)
    for k in range(5):  # le ombre degli alberi del parco sul prato
        x, y = rng.uniform(x0, x0 + w), rng.uniform(740, 860)
        q.fill(q.intersect(q.soften(q.ellipse(q.mask(), x - 160, y - 22, x + 160, y + 22), 14), lawn), GRASS_D, 0.55)
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
    q.stroke(c, [(x, y + 4) for x, y in arc], 9)
    q.fill(c, (204, 198, 184))
    q.fill(q.inner_shadow(c, 0, -5, 2), (156, 150, 138), 0.85)
    q.fill(q.rim(c, 0, -1, 0.6), (232, 228, 216), 0.7)
    q.outline(c, 0.8, (70, 64, 58))
    # la ringhiera lungo l'ovale: pilastrini con la palla ogni tanto, il ferro battuto in mezzo
    posts, dist, last = [], 0.0, arc[0]
    for p in arc:
        dist += math.hypot(p[0] - last[0], p[1] - last[1])
        last = p
        if not posts or dist >= 150:
            posts.append(p)
            dist = 0.0
    iron = q.mask()
    for (ax, ay), (bx, by) in zip(posts, posts[1:]):
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
    for bx, col, fl in ((260, (150, 60, 50), 1), (330, (60, 84, 120), -1), (1290, (40, 40, 44), 1), (1660, (90, 120, 80), -1)):
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
    for x in (-270, 2190):  # solo fuori dal canale, dove non coprono chi rientra dai lati
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


def _obelisk(t, x, base, s, ink):
    """Un obelisco del Prato sul suo piedistallo (#378): dado con la cornice, la palla sotto e l'ago di pietra."""
    stone, stone_sh = (212, 206, 192, 255), (164, 156, 142, 255)
    t.rect(x - 7 * s, base - 16 * s, x + 7 * s, base, fill=stone, ink=True, width=0.6 * s, ink_col=ink)
    t.rect(x + 2 * s, base - 16 * s, x + 7 * s, base, fill=stone_sh)
    t.rect(x - 8.5 * s, base - 18.5 * s, x + 8.5 * s, base - 16 * s, fill=stone, ink=True, width=0.5 * s, ink_col=ink)
    for bx in (-4.5, 4.5):  # le quattro palle agli angoli, due si vedono
        t.circle(x + bx * s, base - 20.5 * s, 2 * s, fill=stone, ink=True, width=0.4 * s, ink_col=ink)
    t.poly([(x - 4 * s, base - 19 * s), (x + 4 * s, base - 19 * s), (x + 1.2 * s, base - 52 * s), (x - 1.2 * s, base - 52 * s)], fill=stone)
    t.poly([(x + 0.5 * s, base - 19 * s), (x + 4 * s, base - 19 * s), (x + 1.2 * s, base - 52 * s), (x + 0.5 * s, base - 52 * s)], fill=stone_sh)
    t.poly([(x - 4 * s, base - 19 * s), (x + 4 * s, base - 19 * s), (x + 1.2 * s, base - 52 * s), (x - 1.2 * s, base - 52 * s)], ink=True, width=0.5 * s, ink_col=ink)
    t.poly([(x - 1.2 * s, base - 52 * s), (x + 1.2 * s, base - 52 * s), (x, base - 56 * s)], fill=stone, ink=True, width=0.4 * s, ink_col=ink)


def _side_bridge(t, p_in, p_out, rng, k=1.0):
    """Un ponte del Prato in prospettiva (#378, come quelli veri): va dalla punta dell'isola (p_in) alla sponda di fuori
    (p_out), sull'asse lungo dell'ovale. Si vede il piano del ponte dall'alto tra i due
    parapetti, quello di là più in alto e quello di qua davanti; sotto il parapetto di qua, la faccia del ponte con
    l'arco sull'acqua, i conci e la chiave; ai quattro capi i piedistalli con gli obelischi, come i ponti est e ovest. k ingrandisce
    tutto il ponte: quelli vicini alla telecamera sono più grandi."""
    stone, stone_sh, stone_l, ink = (230, 226, 216, 255), (176, 170, 158, 255), (246, 244, 236, 255), (84, 78, 72, 255)  # bianchi
    hump = 9 * k
    n = 30

    def along(u, far=False, lift=0.0):  # un punto del ponte: u da 0 (isola) a 1 (sponda), sul bordo di qua o di là
        x = p_in[0] + (p_out[0] - p_in[0]) * u
        y = p_in[1] + (p_out[1] - p_in[1]) * u - hump * math.sin(math.pi * u) ** 0.8 - lift
        if far:  # il bordo di là: più in alto e un po' verso il punto di fuga, al centro dell'arena
            x, y = x + (960 - x) * 0.015, y - 11 * k
        return (x, y)

    near = [along(i / n) for i in range(n + 1)]
    far_ = [along(i / n, True) for i in range(n + 1)]
    # il parapetto di là, dietro al piano: la stessa lastra traforata, vista da dietro e in ombra
    t.poly([(x, y) for x, y in far_] + [(x, y - 8 * k) for x, y in reversed(far_)], fill=stone_sh)
    for i in range(1, n, 1):
        x, y = far_[i]
        t.poly([(x, y - 6.4 * k), (x + 1.2 * k, y - 4 * k), (x, y - 1.6 * k), (x - 1.2 * k, y - 4 * k)], fill=(96, 112, 106, 255))
    t.line([(x, y - 9 * k) for x, y in far_], fill=stone, width=2.2 * k)
    t.line([(x, y - 9.6 * k) for x, y in far_], fill=stone_l, width=0.6 * k)
    # il piano del ponte, visto dall'alto: lastre di pietra
    t.poly(near + list(reversed(far_)), fill=(184, 176, 160, 255))
    for i in range(1, n, 3):
        t.line([near[i], far_[i]], fill=(160, 152, 138, 255), width=0.5 * k)
    # la faccia di qua: dal bordo giù fino all'acqua, con l'arco in mezzo
    water = [(x, y + hump * math.sin(math.pi * i / n) ** 0.8 + 16 * k) for i, (x, y) in enumerate(near)]
    face = near + list(reversed(water))
    t.poly(face, fill=stone)
    arch = []
    for i in range(n + 1):
        u = 0.2 + 0.6 * i / n
        x, y = along(u)
        wy = water[int(u * n)][1]
        arch.append((x, wy - (wy - y - 5 * k) * math.sin(math.pi * (u - 0.2) / 0.6)))
    t.poly([water[int(0.2 * n)]] + arch + [water[int(0.8 * n)]], fill=(48, 64, 60, 255))
    for i in range(2, n - 1, 3):
        x, y = arch[i]
        t.line([(x, y), (x, y - 4 * k)], fill=stone_sh, width=0.7 * k)
    t.line(arch, fill=ink, width=0.8 * k)
    t.line([(x, y + 2.5 * k) for x, y in near], fill=stone_sh, width=2.2 * k)  # la cornice sotto il parapetto
    t.poly(face, ink=True, width=0.8 * k, ink_col=ink)
    for i in range(9):  # il riflesso del ponte nell'acqua
        wx, wy = water[int(n * (0.1 + 0.8 * rng.random()))]
        t.line([(wx - 10 * k, wy + 2 * k + i), (wx + 10 * k, wy + 2 * k + i)], fill=(166, 186, 178, 255) if i % 2 else (60, 78, 72, 255), width=0.6 * k)
    # il parapetto di qua, davanti: una lastra bianca traforata a quadrifogli (come i ponti veri), che segue la gobba
    panel = [(x, y - 1 * k) for x, y in near] + [(x, y - 9 * k) for x, y in reversed(near)]
    t.poly(panel, fill=stone)
    for i in range(1, n, 1):
        x, y = near[i]
        yc = y - 5 * k
        t.poly([(x, yc - 2.6 * k), (x + 1.4 * k, yc), (x, yc + 2.6 * k), (x - 1.4 * k, yc)], fill=(70, 86, 82, 255))  # il traforo
    t.poly(panel, ink=True, width=0.5 * k, ink_col=ink)
    t.line([(x, y - 9 * k) for x, y in near], fill=stone, width=2.6 * k)
    t.line([(x, y - 9.8 * k) for x, y in near], fill=stone_l, width=0.8 * k)
    t.line([(x, y - 7.6 * k) for x, y in near], fill=ink, width=0.5 * k)
    # gli obelischi ai capi: quelli di là più piccoli e più in alto
    for u in (0.0, 1.0):  # gli obelischi alti e bianchi ai capi, come sui ponti est e ovest del Prato
        fx, fy = along(u, True)
        _obelisk(t, fx, fy, 0.85 * k, ink)
        nx, ny = along(u)
        _obelisk(t, nx, ny + 2 * k, 1.0 * k, ink)


def _walk_bridge(t, x_in, x_out, rng):
    """Un ponte del Prato dallo schizzo di Riccardo (#378): dalla punta dell'isola alla sponda di fuori, con l'asse
    della passerella sulla stessa linea del piano dove si gioca. Visto un po' dall'alto come la piazza: si vede tutta
    la passerella lastricata (dal parapetto lontano, a y 478, al bordo vicino, a y 522), con una gobba leggera; sotto,
    la faccia di pietra bianca con un arco largo e basso sull'acqua, i conci e la chiave; i parapetti traforati sui due
    bordi e gli obelischi ai capi."""
    stone, stone_sh, stone_l, ink = (230, 226, 216, 255), (176, 170, 158, 255), (246, 244, 236, 255), (84, 78, 72, 255)
    a, b = min(x_in, x_out), max(x_in, x_out)
    n = 40
    far_y, near_y, water, hump = 478, 522, 602, 7

    def gob(u):  # quanto sale la gobba nel punto u (0..1)
        return hump * math.sin(math.pi * u) ** 0.9

    xs = [a + (b - a) * i / n for i in range(n + 1)]
    far = [(x, far_y - gob(i / n)) for i, x in enumerate(xs)]
    near = [(x, near_y - gob(i / n)) for i, x in enumerate(xs)]
    # il parapetto lontano, piccolo e in ombra
    t.poly(far + [(x, y - 9) for x, y in reversed(far)], fill=stone_sh)
    for i in range(1, n):
        x, y = far[i]
        t.poly([(x, y - 7), (x + 1.2, y - 4.5), (x, y - 2), (x - 1.2, y - 4.5)], fill=(96, 112, 106, 255))
    t.line([(x, y - 9.5) for x, y in far], fill=stone, width=2.0)
    # la passerella vista dall'alto: le lastre a file, più strette lontano
    t.poly(far + list(reversed(near)), fill=(204, 198, 184, 255))
    for k, f in enumerate((0.12, 0.27, 0.45, 0.68)):
        t.line([(x, fy + (ny - fy) * f) for (x, fy), (_, ny) in zip(far, near)], fill=(176, 170, 156, 255), width=0.5 + 0.2 * k)
    for i in range(1, n, 2):
        (x0, y0), (x1, y1) = far[i], near[i]
        t.line([(x0, y0), (x1 + (x1 - 960) * 0.01, y1)], fill=(180, 174, 160, 255), width=0.5)
    t.glaze([(x, y) for x, y in far] + [(x, y + 5) for x, y in reversed(far)], (40, 36, 32, 45))  # l'ombra del parapetto
    # la faccia davanti: dal bordo vicino giù fino all'acqua, con l'arco largo e basso
    face = near + [(b, water), (a, water)]
    t.poly(face, fill=stone)
    span, mid = (b - a) * 0.62, (a + b) / 2
    top_arch = near_y + 10
    arch = [(mid - span / 2 + span * i / n, water - (water - top_arch + gob(0.5)) * math.sin(math.pi * i / n) ** 0.7) for i in range(n + 1)]
    t.poly([(mid - span / 2, water + 1)] + arch + [(mid + span / 2, water + 1)], fill=(40, 54, 50, 255))
    t.line([(x + 8, y + 6) for x, y in arch[4:-4]], fill=(64, 80, 74, 255), width=1.4)  # la volta che va in profondità
    for i in range(1, 18):  # i conci attorno all'arco
        u = i / 18
        px, py = arch[int(u * n)]
        nx, ny = -math.cos(math.pi * u), -math.sin(math.pi * u)
        t.line([(px, py), (px + nx * 7, py + ny * 7)], fill=stone_sh, width=0.8)
    kx, ky = arch[n // 2]
    t.poly([(kx - 4, ky - 8), (kx + 4, ky - 8), (kx + 3, ky + 1), (kx - 3, ky + 1)], fill=stone_sh, ink=True, width=0.6, ink_col=ink)
    t.line(arch, fill=ink, width=0.9)
    for y in range(int(near_y + 14), int(water), 12):  # i corsi di pietra della faccia, ai lati dell'arco
        t.line([(a + 2, y), (mid - span / 2 - 2, y)], fill=(204, 198, 184, 255), width=0.5)
        t.line([(mid + span / 2 + 2, y), (b - 2, y)], fill=(204, 198, 184, 255), width=0.5)
    t.line([(x, y + 4) for x, y in near], fill=stone_sh, width=2.6)  # la cornice sotto il bordo
    t.glaze([(b - 10, near_y), (b, near_y), (b, water), (b - 10, water)] if x_in > x_out else [(a, near_y), (a + 10, near_y), (a + 10, water), (a, water)], (40, 36, 32, 45))
    t.poly(face, ink=True, width=0.9, ink_col=ink)
    for i in range(12):  # il riflesso nell'acqua, spezzato
        y = water + 2 + i * 1.8
        t.line([(a + rng.uniform(0, 20), y), (b - rng.uniform(0, 20), y)], fill=(166, 186, 178, 255) if i % 2 else (60, 78, 72, 255), width=0.7)
    # il parapetto vicino, basso, traforato
    t.poly(near + [(x, y - 10) for x, y in reversed(near)], fill=stone)
    for i in range(1, n):
        x, y = near[i]
        t.poly([(x, y - 8), (x + 1.6, y - 5), (x, y - 2), (x - 1.6, y - 5)], fill=(70, 86, 82, 255))
    t.poly(near + [(x, y - 10) for x, y in reversed(near)], ink=True, width=0.5, ink_col=ink)
    t.line([(x, y - 11) for x, y in near], fill=stone, width=2.8)
    t.line([(x, y - 11.8) for x, y in near], fill=stone_l, width=0.8)
    # gli obelischi ai capi: quelli lontani più piccoli
    for x, y in (far[0], far[-1]):
        _obelisk(t, x + (3 if x == a else -3), y, 0.7, ink)
    for x, y in (near[0], near[-1]):
        _obelisk(t, x + (3 if x == a else -3), y + 1, 0.9, ink)


def _walk_bridge_painted(t, x_in, x_out, rng):
    """Il ponte del Prato dallo schizzo di Riccardo (#378), dipinto perché stia dentro la scena e non sembri incollato:
    - la passerella continua il piano dove si gioca e si vede un po' dall'alto, con il bordo lontano che scappa verso
      il centro come le lastre della piazza;
    - dentro l'arco si vede l'acqua del canale che passa sotto e la volta in ombra, non un buco nero;
    - la pietra ha la grana, le macchie, l'umido scuro e le alghe dove tocca l'acqua, e l'ombra sotto la cornice;
    - il ponte getta la sua ombra sull'acqua (la luce viene da sinistra in alto) e si specchia, spezzato dalle onde;
    - il capo verso l'isola entra sotto il bordo della piazza (il gioco ci disegna sopra la copertina), l'altro poggia
      su una spalla di pietra con il gradino sul vialetto della sponda."""
    from pittura import Quadro, bezier
    a, b = min(x_in, x_out), max(x_in, x_out)
    left_side = x_out < x_in  # il ponte di sinistra: verso il centro c'è l'isola a destra
    x0, y0 = a - 30, 446
    w, h = b - a + 60, 220
    q = Quadro(w, h, origin=(x0, y0), scale=t.k)
    ink = (78, 72, 66)
    S, S_SH, S_DK, S_HI = (226, 222, 210), (176, 170, 158), (128, 124, 116), (246, 244, 236)
    WATER, WATER_D = (92, 122, 114), (54, 74, 68)
    far_y, near_y, water, hump = 480, 522, 604, 7
    n = 48

    def gob(u):
        return hump * math.sin(math.pi * u) ** 0.9

    def conv(x):  # il bordo lontano scappa appena verso il centro dell'arena (il punto di fuga)
        return x + (960 - x) * 0.025

    xs = [a + (b - a) * i / n for i in range(n + 1)]
    near = [(x, near_y - gob(i / n)) for i, x in enumerate(xs)]
    far = [(conv(x), far_y - gob(i / n)) for i, x in enumerate(xs)]
    span, mid = (b - a) * 0.6, (a + b) / 2
    arch = [(mid - span / 2 + span * i / n, water - (water - near_y - 14 + gob(0.5)) * math.sin(math.pi * i / n) ** 0.7) for i in range(n + 1)]
    # l'ombra del ponte sull'acqua: la luce viene da sinistra in alto, l'ombra cade a destra e in giù
    sh = q.poly(q.mask(), [(a + 18, water), (b + 26, water), (b + 40, water + 16), (a + 30, water + 16)])
    q.fill(q.soften(sh, 5), (30, 44, 40), 0.35)
    # il riflesso: la faccia capovolta sotto il pelo dell'acqua, spezzata dalle onde
    refl = q.mask()
    for i in range(0, 12):
        y = water + 2 + i * 2.2
        x_a = a + rng.uniform(0, 10) + (span * 0.2 if i < 6 else 0)
        q.stroke(refl, [(x_a, y), (b - rng.uniform(0, 10), y)], 1.2)
    hole = q.poly(q.mask(), [(mid - span / 2, water)] + [(x, 2 * water - y) for x, y in arch] + [(mid + span / 2, water)])
    q.fill(q.minus(q.soften(refl, 0.6), hole), (196, 200, 190), 0.45)
    # il parapetto lontano, piccolo, in ombra, traforato
    fp = q.poly(q.mask(), far + [(x, y - 9) for x, y in reversed(far)])
    q.fill(fp, S_SH)
    holes = q.mask()
    for i in range(1, n):
        x, y = far[i]
        q.poly(holes, [(x, y - 7), (x + 1.1, y - 4.5), (x, y - 2), (x - 1.1, y - 4.5)])
    q.fill(q.intersect(holes, fp), (118, 132, 120))
    q.line([(x, y - 9.5) for x, y in far], 1.8, S)
    q.outline(fp, 0.4, ink)
    # la passerella vista dall'alto, lastricata, con l'ombra del parapetto lontano
    deck = q.poly(q.mask(), far + list(reversed(near)))
    q.fill(deck, (206, 200, 186))
    q.fill(q.grain(deck, 0.3, 61, 0.9), (180, 174, 160), 0.6)
    joints = q.mask()
    for f in (0.15, 0.33, 0.55, 0.8):
        q.stroke(joints, [(fx + (nx - fx) * f, fy + (ny - fy) * f) for (fx, fy), (nx, ny) in zip(far, near)], 0.45 + 0.3 * f)
    for i in range(1, n, 3):
        q.stroke(joints, [far[i], near[i]], 0.45)
    q.fill(q.intersect(joints, deck), (160, 154, 140), 0.85)
    q.fill(q.intersect(q.soften(q.poly(q.mask(), far + [(x, y + 8) for x, y in reversed(far)]), 2), deck), (60, 56, 50), 0.35)
    # dentro l'arco: l'acqua che passa sotto il ponte e la volta in ombra, che va in profondità
    opening = q.poly(q.mask(), [(mid - span / 2, water + 0.5)] + arch + [(mid + span / 2, water + 0.5)])
    q.fill(opening, WATER)
    vault = q.poly(q.mask(), [(x + (mid - x) * 0.06, y + (water - y) * 0.0) for x, y in arch] + [(x + 10, y + 12) for x, y in reversed(arch)])
    q.fill(q.intersect(q.soften(vault, 3), opening), WATER_D, 0.95)
    under = q.poly(q.mask(), [(mid - span / 2, water - 6), (mid + span / 2, water - 6), (mid + span / 2, water + 1), (mid - span / 2, water + 1)])
    q.fill(q.intersect(q.soften(under, 2), opening), (130, 158, 148), 0.6)  # la luce che passa sotto, sul pelo dell'acqua
    rip = q.mask()
    for k in range(8):
        y = water - 2 - k * 2.2
        x = mid + rng.uniform(-span * 0.35, span * 0.3)
        q.stroke(rip, [(x, y), (x + rng.uniform(8, 20), y)], 0.6)
    q.fill(q.intersect(rip, opening), (160, 186, 176), 0.6)
    # la faccia di pietra, dal bordo vicino giù fino all'acqua, meno l'arco
    face = q.minus(q.poly(q.mask(), near + [(b, water), (a, water)]), opening)
    q.fill(face, S)
    q.fill(q.grain(face, 0.35, 62, 0.8), (150, 148, 138), 0.45)  # le macchie del tempo
    damp = Image.new("L", face.size, 0)  # l'umido che sale dall'acqua: più scuro in basso
    bb = face.getbbox()
    if bb:
        gy = Image.new("L", (1, bb[3] - bb[1]))
        for j in range(gy.height):
            u = j / max(1, gy.height - 1)
            gy.putpixel((0, j), int(255 * max(0.0, (u - 0.45) / 0.55) ** 1.5))
        damp.paste(gy.resize((bb[2] - bb[0], bb[3] - bb[1])), (bb[0], bb[1]))
    q.fill(q.intersect(damp, face), (96, 100, 86), 0.7)
    algae = q.poly(q.mask(), [(a, water - 5), (b, water - 5), (b, water), (a, water)])
    q.fill(q.intersect(q.soften(algae, 1), face), (88, 104, 64), 0.8)
    corsi = q.mask()  # i corsi di pietra ai lati dell'arco
    for y in range(int(near_y + 12), int(water - 6), 11):
        q.stroke(corsi, [(a, y), (b, y)], 0.45)
    for i in range(0, n, 4):
        x = xs[i] + (6 if (i // 4) % 2 else 0)
        for y in range(int(near_y + 12), int(water - 6), 22):
            q.stroke(corsi, [(x, y), (x, y + 11)], 0.4)
    q.fill(q.intersect(q.minus(corsi, q.soften(opening, 6)), face), (178, 172, 160), 0.7)
    ring = q.minus(q.poly(q.mask(), [(mid - span / 2 - 9, water)] + [(x + (x - mid) * 0.12, y - 9 * math.sin(math.pi * i / n)) for i, (x, y) in enumerate(arch)] + [(mid + span / 2 + 9, water)]), opening)
    q.fill(ring, (234, 230, 220))
    vj = q.mask()
    for i in range(1, 20):
        u = i / 20
        px, py = arch[int(u * n)]
        nx, ny = -math.cos(math.pi * u) * 1.1, -math.sin(math.pi * u)
        q.stroke(vj, [(px, py), (px + nx * 10, py + ny * 10)], 0.55)
    q.fill(q.intersect(vj, ring), S_DK, 0.8)
    kx, ky = arch[n // 2]
    key = q.poly(q.mask(), [(kx - 4.5, ky - 11), (kx + 4.5, ky - 11), (kx + 3.5, ky + 1), (kx - 3.5, ky + 1)])
    q.fill(key, S_HI)
    q.fill(q.inner_shadow(key, -2, -1, 1), S_SH, 0.9)
    q.outline(key, 0.5, ink)
    q.fill(q.inner_shadow(face, -10, -4, 7), S_SH, 0.55)  # il volume: la faccia gira in ombra verso destra
    corn = q.poly(q.mask(), [(x, y) for x, y in near] + [(x, y + 4) for x, y in reversed(near)])
    q.fill(corn, S_HI)
    q.fill(q.soften(q.poly(q.mask(), [(x, y + 4) for x, y in near] + [(x, y + 10) for x, y in reversed(near)]), 2), (40, 38, 34), 0.35)  # l'ombra sotto la cornice
    q.outline(face, 0.6, ink)
    # il parapetto vicino, traforato: dai buchi si vede la passerella
    np_ = q.poly(q.mask(), near + [(x, y - 11) for x, y in reversed(near)])
    holes = q.mask()
    for i in range(1, n):
        x, y = near[i]
        q.poly(holes, [(x, y - 9), (x + 1.6, y - 5.5), (x, y - 2), (x - 1.6, y - 5.5)])
    panel = q.minus(np_, holes)
    q.fill(panel, S)
    q.fill(q.inner_shadow(panel, 0, -2, 1.2), S_SH, 0.8)
    q.fill(q.intersect(holes, np_), (150, 146, 134))
    q.line([(x, y - 12) for x, y in near], 3.0, S)
    q.line([(x, y - 12.8) for x, y in near], 0.9, S_HI)
    q.outline(np_, 0.45, ink)
    # la spalla sulla sponda di fuori, con il gradino che scende sul vialetto, e l'ombra a terra
    ox = a if left_side else b
    sgn = -1 if left_side else 1
    pier = q.poly(q.mask(), [(ox, near_y - 2), (ox + sgn * 16, near_y - 2), (ox + sgn * 16, water), (ox, water)])
    q.fill(pier, S)
    q.fill(q.grain(pier, 0.35, 63, 0.8), (150, 148, 138), 0.45)
    q.fill(q.inner_shadow(pier, -sgn * 4, -2, 3), S_SH, 0.8)
    q.outline(pier, 0.5, ink)
    step = q.poly(q.mask(), [(ox + sgn * 16, near_y - 2), (ox + sgn * 28, near_y + 2), (ox + sgn * 28, near_y + 6), (ox + sgn * 16, near_y + 6)])
    q.fill(step, S_SH)
    q.outline(step, 0.4, ink)
    ea, eb = sorted((ox + sgn * 4, ox + sgn * 40))
    q.fill(q.soften(q.ellipse(q.mask(), ea, near_y + 2, eb, near_y + 10), 3), (40, 38, 30), 0.3)
    t.img.alpha_composite(q.result(), (int(round((x0 - t.ox) * t.k)), int(round((y0 - t.oy) * t.k))))
    # gli obelischi ai capi, sopra il parapetto: quelli lontani più piccoli
    for x, y in (far[0], far[-1]):
        _obelisk(t, x + (3 if x < mid else -3), y, 0.7, (84, 78, 72, 255))
    for x, y in (near[0], near[-1]):
        _obelisk(t, x + (3 if x < mid else -3), y + 1, 0.9, (84, 78, 72, 255))


def bridges_and_statues(name):
    """Le statue sulla sponda di là del canale e i ponticelli (#378, chiesto da Riccardo): la fila di statue del Prato
    lungo tutto l'ovale, più piccole lontano; il ponticello dietro la fontana visto di fronte, e i due alle punte
    dell'isola visti di fianco, che portano alla sponda di fuori. Sono dietro la piazza: non ci si cammina sopra.
    Prop dietro in x 960, y 640, a 2x: x -420..2340, y 340..640."""
    x0, y0, w, h = -420, 340, 2760, 300
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
    for side in (-1, 1):
        _walk_bridge_painted(t, 960 + side * 856, 960 + side * 1250, rng)
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
    rings = [1.0, 0.9, 0.79, 0.67, 0.54, 0.4, 0.25, 0.1, 0.0]
    base = mix(EDGE, STONE_LIGHT, 0.42)
    far_col = mix(EDGE, STONE, 0.62)
    joints = []
    for i, (fo, fi) in enumerate(zip(rings, rings[1:])):
        fm = (fo + fi) / 2
        n = max(6, int(math.pi * rx * fm / 46))  # lastre dell'anello
        off = (i % 2) * 0.5
        for j in range(n):
            a0 = math.pi * max(0.0, min(1.0, (j + off) / n))
            a1 = math.pi * max(0.0, min(1.0, (j + 1 + off) / n))
            if a1 - a0 < 1e-3:
                continue
            outer = [pt(fo, a0 + (a1 - a0) * u / 4) for u in range(5)]
            inner = [pt(fi, a1 - (a1 - a0) * u / 4) for u in range(5)]
            depth = math.sin((a0 + a1) / 2) * fm  # 0 davanti, 1 in fondo
            row_col = mix(base, far_col, depth)
            col = mix(row_col, shade(row_col, 0.9), rng.random() * 0.6)
            t.poly(outer + inner, fill=col)
            if rng.random() < 0.22:  # qualche lastra consumata, più chiara al centro
                mx, my = pt(fm, (a0 + a1) / 2)
                t.glaze([(mx - 7, my), (mx, my - 1.2), (mx + 7, my), (mx, my + 1.2)], (255, 250, 236, 40))
            joints.append(([pt(fo, a0), pt(fi, a0)], mix(STONE_SHADE, row_col, 0.35), 0.4 + 0.35 * (1 - depth)))
        ring_col = mix(STONE_SHADE, mix(base, far_col, 0.5), 0.35)
        joints.append(([pt(fi, math.pi * u / 80) for u in range(81)], ring_col, 0.5))
    for pts, col, w in joints:
        t.line(pts, fill=col, width=w)
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
    lawn_q = Tela(x1 - x0, y1 - y0, origin=(x0, y0))
    for pts_ in (lawn_pts_l, lawn_pts_r):
        if len(pts_) > 3:
            lawn_q.poly(pts_, fill=(88, 112, 66, 255))
    for k in range(-40, 40):  # le strisce del taglio dell'erba, in diagonale
        xa = cx + k * 46
        lawn_q.glaze([(xa, 520), (xa + 23, 520), (xa + 23 + 40, 460), (xa + 40, 460)], (130, 156, 96, 46) if k % 2 else (40, 60, 30, 30))
    for k in range(2400):
        gx, gy = rng.uniform(x0, x1), rng.uniform(462, 506)
        lawn_q.line([(gx, gy), (gx + rng.uniform(-0.6, 0.6), gy - rng.uniform(1.0, 2.6))], fill=rng.choice([(64, 84, 48, 255), (112, 138, 82, 255)]), width=0.5)
    mask = Image.new("L", t.img.size, 0)
    md = ImageDraw.Draw(mask)
    for pts_ in (lawn_pts_l, lawn_pts_r):
        if len(pts_) > 3:
            md.polygon(t._pts(pts_, 0, 0), fill=255)
    rx_f, ry_f = 238, 25  # l'anello lastricato attorno alla vasca resta pietra
    md.ellipse(t._box((cx - rx_f, 492 - ry_f, cx + rx_f, 492 + ry_f), 0, 0), fill=0)
    t.img.paste(lawn_q.img, (0, 0), mask)
    for pts_ in (lawn_pts_l, lawn_pts_r):
        if len(pts_) > 3:
            t.line(pts_ + [pts_[0]], fill=(150, 144, 130, 255), width=0.9)  # il bordo di pietra delle aiuole
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
    # l'erba sulla piazza (#378, chiesto da Riccardo): le aiuole sotto i platani, con il cordolo, e ciuffi tra le lastre
    for tx, rxa in ((410, 92), (1510, 92)):
        bed = [(tx + rxa * math.cos(u), 508 + 10 * math.sin(u)) for u in [j * math.tau / 48 for j in range(48)]]
        t.poly(bed, fill=(150, 144, 130, 255))
        inner = [(tx + (rxa - 4) * math.cos(u), 508 + 8.4 * math.sin(u)) for u in [j * math.tau / 48 for j in range(48)]]
        t.poly(inner, fill=(84, 104, 64, 255))
        for k in range(420):
            u, rr = rng.uniform(0, math.tau), math.sqrt(rng.random())
            gx, gy = tx + (rxa - 6) * rr * math.cos(u), 508 + 7.4 * rr * math.sin(u)
            t.line([(gx, gy), (gx + rng.uniform(-0.8, 0.8), gy - rng.uniform(1.5, 3.5))], fill=rng.choice([(64, 82, 50, 255), (112, 134, 80, 255), (96, 118, 70, 255)]), width=0.6)
        t.glaze([(tx + 30 + (rxa - 20) * math.cos(u), 509 + 6 * math.sin(u)) for u in [j * math.tau / 32 for j in range(32)]], (30, 36, 24, 50))  # l'ombra della chioma
        t.poly(bed, ink=True, width=0.8, ink_col=(100, 96, 86, 255))
    for k in range(260):  # ciuffi d'erba tra le lastre, più fitti verso i bordi
        a, f = rng.uniform(0, math.pi), rng.uniform(0.3, 1.0) ** 0.5
        gx, gy = pt(f, a)
        if gy > 517:
            continue
        for j in range(3):
            t.line([(gx + j * 0.8, gy), (gx + j * 0.8 + rng.uniform(-0.6, 0.6), gy - rng.uniform(1.2, 2.6))], fill=(92, 114, 66, 255), width=0.5)
    # ombre di contatto: le basi delle statue e i platani poggiano sul lastricato
    for sx, w in ((310, 36), (540, 40), (690, 36), (1230, 36), (1380, 40), (1610, 36), (410, 22), (1510, 22)):
        for i, (ww, al) in enumerate(((w * 1.4, 14), (w * 1.1, 20), (w * 0.8, 26))):
            t.glaze([(sx + math.cos(u) * ww, 515 + math.sin(u) * (3 + i)) for u in [j * math.tau / 24 for j in range(24)]], (40, 36, 32, al))
    t.save(OUT, name, colors=256)


GROUND = 522  # il pavimento dell'isola, dove poggiano palazzo, statue e platani


def palazzo(name):
    """Il palazzo signorile al centro, dietro il ponte (#280 passo 2), x 740-1180, y 40-480, a 2x.

    Portico a bugnato con i conci sugli archi, mezzanino con le inferriate, piano nobile con la trifora gotica e
    le bifore (le luci di notte stanno su queste finestre: art.life.daycycle.windows), ultimo piano con le persiane,
    cornicione con le mensole, tetto di coppi e camini a imbuto. L'intonaco caldo ha qualche scrostatura che mostra
    i mattoni. I balconi veri sono piattaforme (y 300 e 180): qui ci sono solo le mensole sotto.
    Il portico arriva fino al pavimento dell'isola, a y 522 (#300): prima finiva a 480 e il palazzo sembrava sollevato."""
    t = Tela(440, 482, origin=(740, 40))
    lt = Tela(440, 482, origin=(740, 40))  # le luci della notte (#288): solo i vetri accesi, nello stesso posto
    rng = rand(21)
    plaster, plaster_s = (156, 122, 94, 255), (132, 102, 78, 255)
    stone, stone_s = (188, 182, 168, 255), (156, 148, 135, 255)  # un po' più spenta dei balconi, che si calpestano
    dark, glass = (46, 40, 38, 255), (58, 62, 66, 255)
    shutter, shutter_s = (88, 104, 84, 255), (70, 84, 68, 255)
    brick = (132, 84, 66, 255)

    # --- corpo: intonaco, le ombre portate le mettono cornici e balconi ---
    t.rect(760, 110, 1160, GROUND, fill=plaster)
    # scrostature: l'intonaco caduto mostra i mattoni, col bordo chiaro dell'intonaco rotto
    for (px, py, pw, ph) in ((1022, 138, 32, 24), (869, 246, 26, 40), (1012, 338, 24, 26)):
        pts = [(px + pw * u, py + ph * v) for u, v in ((0.1, 0), (0.6, 0.05), (1, 0.3), (0.9, 0.8), (0.5, 1), (0, 0.7))]
        t.poly(pts, fill=brick)
        for k in range(1, 5):
            yy = py + k * ph / 5
            t.line([(px + 2, yy), (px + pw - 2, yy)], fill=shade(brick, 0.75), width=0.6)
        t.poly(pts, ink=True, width=0.8, ink_col=light(plaster, 1.12))
    # lesene d'angolo a conci alternati (cantonali)
    for x0 in (760, 1144):
        for k in range(12):
            y0 = 120 + k * 22
            w = 16 if k % 2 == 0 else 12
            xx = x0 if x0 == 760 else x0 + 16 - w
            t.block(xx, y0, xx + w, y0 + 22, stone, sh=stone_s, bottom=3, width=0.9)

    # --- portico a bugnato (y 380-522), sullo zoccolo ---
    t.rect(760, 380, 1160, GROUND, fill=stone)
    for row in range(7):
        y = 380 + row * 20
        off = 0 if row % 2 == 0 else 20
        for x in range(760 - off, 1160, 40):
            x0, x1 = max(760, x), min(1160, x + 40)
            if x1 - x0 > 2:
                t.block(x0 + 0.5, y + 0.5, x1 - 0.5, y + 19.5, mix(stone, stone_s, rng.random() * 0.3), sh=stone_s, bottom=3, side=2, width=0.8)
    for i in range(5):  # archi con i conci a raggiera e la chiave
        ax = 778 + i * 78
        cxa, r = ax + 26, 26
        t.rect(ax, 410, ax + 52, GROUND, fill=dark)
        t.pieslice(ax, 384, ax + 52, 436, 180, 360, fill=dark)
        t.rect(ax + 4, 470, ax + 48, GROUND, fill=(54, 48, 44, 255))  # il fondo del portico, appena più chiaro in basso
        for k in range(9):
            a0, a1 = math.pi * k / 9, math.pi * (k + 1) / 9
            out = 10 if k == 4 else 7
            pts = [(cxa - r * math.cos(a0), 410 - r * math.sin(a0)), (cxa - (r + out) * math.cos(a0), 410 - (r + out) * math.sin(a0)),
                   (cxa - (r + out) * math.cos(a1), 410 - (r + out) * math.sin(a1)), (cxa - r * math.cos(a1), 410 - r * math.sin(a1))]
            t.poly(pts, fill=stone if k < 5 else stone_s, ink=True, width=0.8)
        t.line([(ax, 410), (ax, GROUND)], fill=INK, width=1.2)
        t.line([(ax + 52, 410), (ax + 52, GROUND)], fill=INK, width=1.2)
        if i == 2:  # la lanterna appesa nell'arco centrale
            t.line([(cxa, 386), (cxa, 400)], fill=INK, width=0.8)
            t.poly([(cxa - 4, 400), (cxa + 4, 400), (cxa + 3, 410), (cxa - 3, 410)], fill=(150, 136, 100, 255), ink=True, width=0.7)

    # --- mezzanino con le inferriate (y 330-370) e il marcapiano ---
    for i in range(6):
        wx = 786 + i * 64
        t.rect(wx - 3, 337, wx + 31, 367, fill=stone, ink=True, width=0.9)
        t.rect(wx, 340, wx + 28, 364, fill=glass)
        if i in (1, 4):  # due finestre del mezzanino accese, con le sbarre davanti alla luce
            lit_rect(lt, wx, 340, wx + 28, 364)
            for b in range(1, 4):
                lt.line([(wx + b * 7, 340), (wx + b * 7, 364)], fill=(30, 28, 26, 255), width=0.9)
            lt.line([(wx, 352), (wx + 28, 352)], fill=(30, 28, 26, 255), width=0.9)
        for b in range(1, 4):
            t.line([(wx + b * 7, 340), (wx + b * 7, 364)], fill=(30, 28, 26, 255), width=0.9)
        t.line([(wx, 352), (wx + 28, 352)], fill=(30, 28, 26, 255), width=0.9)
    t.rect(756, 370, 1164, 380, fill=stone)
    t.rect(756, 376, 1164, 380, fill=stone_s)
    t.rect(756, 370, 1164, 380, ink=True, width=1.0)

    # --- piano nobile (y 204-330): ombra del balcone, mensole, trifora e bifore ---
    t.rect(800, 314, 1120, 322, fill=plaster_s)  # l'ombra sotto il piano del balcone (la piattaforma finisce a 314)
    for i in range(9):
        mx = 806 + i * 38
        t.poly([(mx, 314), (mx + 14, 314), (mx + 14, 318), (mx + 10, 330), (mx + 4, 330), (mx, 318)], fill=stone, ink=True, width=0.9)
        t.poly([(mx + 9, 316), (mx + 14, 316), (mx + 10, 330), (mx + 8, 328)], fill=stone_s)

    def gothic(wx, wy, ww, wh, lights, lit=True):
        # cornice di pietra con il cappello a punta, luci a sesto acuto con le colonnine, quadrilobo in cima
        frame = [(wx - 7, wy + wh), (wx - 7, wy + 6), (wx + ww / 2, wy - 16), (wx + ww + 7, wy + 6), (wx + ww + 7, wy + wh)]
        t.poly(frame, fill=stone, ink=True, width=1.1)
        t.poly([(wx + ww / 2, wy - 16), (wx + ww + 7, wy + 6), (wx + ww + 7, wy + wh), (wx + ww, wy + wh)], fill=stone_s)
        lw_ = ww / lights
        for j in range(lights):
            lx = wx + j * lw_
            pts = [(lx + 3, wy + wh - 3), (lx + 3, wy + 18), (lx + lw_ / 2, wy + 4), (lx + lw_ - 3, wy + 18), (lx + lw_ - 3, wy + wh - 3)]
            t.poly(pts, fill=glass, ink=True, width=0.9)
            if lit:
                lit_window(lt, pts)
            t.poly([(lx + lw_ * 0.55, wy + 14), (lx + lw_ - 4, wy + 22), (lx + lw_ - 4, wy + 30), (lx + lw_ * 0.55, wy + 24)], fill=(76, 82, 86, 255))  # riflesso
            if j:
                t.rect(lx - 1.6, wy + 16, lx + 1.6, wy + wh - 3, fill=stone, ink=True, width=0.7)  # colonnina
        qx, qy = wx + ww / 2, wy - 4
        for a in range(4):
            aa = a * math.pi / 2
            t.circle(qx + math.cos(aa) * 3.2, qy + math.sin(aa) * 3.2, 3.4, fill=stone_s, ink=True, width=0.7)
        t.circle(qx, qy, 2.4, fill=stone_s)
        t.rect(wx - 9, wy + wh - 2, wx + ww + 9, wy + wh + 3, fill=stone, ink=True, width=0.9)  # davanzale
    gothic(905, 212, 110, 84, 3)
    gothic(800, 222, 60, 74, 2)
    gothic(1060, 222, 60, 74, 2, lit=False)
    t.rect(756, 196, 1164, 204, fill=stone)
    t.rect(756, 201, 1164, 204, fill=stone_s)
    t.rect(756, 196, 1164, 204, ink=True, width=1.0)

    # --- ultimo piano (y 112-196): mensole del balconcino, finestre con le persiane aperte e i vasi ---
    t.rect(900, 194, 1020, 200, fill=plaster_s)
    for i in range(5):
        mx = 904 + i * 26
        t.poly([(mx, 194), (mx + 10, 194), (mx + 7, 206), (mx + 3, 206)], fill=stone, ink=True, width=0.8)
    for wx in (790, 850, 940, 990, 1070, 1120):
        t.rect(wx - 4, 124, wx + 20, 128, fill=stone, ink=True, width=0.8)  # cappello
        t.rect(wx - 2, 128, wx + 18, 172, fill=stone, ink=True, width=0.8)
        t.rect(wx, 130, wx + 16, 170, fill=glass)
        if wx in (790, 990, 1120):
            lit_rect(lt, wx, 130, wx + 16, 170)
            lt.line([(wx + 8, 130), (wx + 8, 170)], fill=(120, 90, 50, 255), width=0.8)  # l'infisso
            lt.line([(wx, 146), (wx + 16, 146)], fill=(120, 90, 50, 255), width=0.8)
        t.line([(wx + 8, 130), (wx + 8, 170)], fill=stone_s, width=0.8)
        t.line([(wx, 146), (wx + 16, 146)], fill=stone_s, width=0.8)
        for sx in (wx - 10, wx + 18):  # persiane a stecche
            t.rect(sx, 128, sx + 8, 172, fill=shutter, ink=True, width=0.8)
            t.rect(sx + 5.5, 128, sx + 8, 172, fill=shutter_s)
            for k in range(1, 11):
                t.line([(sx + 1, 128 + k * 4), (sx + 7, 128 + k * 4)], fill=shutter_s, width=0.6)
        t.rect(wx - 4, 172, wx + 20, 175, fill=stone, ink=True, width=0.8)  # davanzale
        if wx in (850, 1070):  # vasi di fiori sul davanzale, colori spenti
            for k in range(3):
                fx = wx + 1 + k * 6
                t.rect(fx, 166, fx + 5, 172, fill=(140, 92, 72, 255), ink=True, width=0.5)
                t.circle(fx + 2.5, 164, 3, fill=(204, 168, 176, 255) if k % 2 else (226, 220, 206, 255))

    # --- cornicione con le mensole e i dentelli, ombra sotto ---
    t.rect(760, 112, 1160, 118, fill=plaster_s)
    t.rect(750, 98, 1170, 112, fill=stone)
    t.rect(750, 108, 1170, 112, fill=stone_s)
    t.rect(750, 98, 1170, 112, ink=True, width=1.2)
    for i in range(27):
        mx = 754 + i * 15.5
        t.poly([(mx, 112), (mx + 6, 112), (mx + 6, 115), (mx + 3, 118), (mx, 118)], fill=stone, ink=True, width=0.6)

    # --- tetto di coppi a file, colmo e camini a imbuto ---
    roof = [(752, 98), (1168, 98), (1130, 64), (790, 64)]
    t.poly(roof, fill=(116, 78, 62, 255))
    t.poly([(1060, 64), (1130, 64), (1168, 98), (1100, 98)], fill=(102, 68, 54, 255))  # la falda in ombra a destra
    for row in range(5):
        y = 70 + row * 6.5
        x0 = 790 - (y - 64) * 38 / 34
        x1 = 1130 + (y - 64) * 38 / 34
        x = x0 + (row % 2) * 4
        while x < x1 - 4:
            t.arc(x, y - 3, x + 8, y + 5, 180, 360, fill=(92, 60, 48, 255), width=0.9)
            x += 8
    t.poly(roof, ink=True, width=1.2)
    t.line([(790, 64), (1130, 64)], fill=INK, width=1.6)
    for cxm in (812, 1110):
        t.rect(cxm - 6, 40, cxm + 6, 68, fill=(132, 96, 78, 255), ink=True, width=1.0)
        t.rect(cxm + 2, 40, cxm + 6, 68, fill=(112, 80, 66, 255))
        t.poly([(cxm - 16, 38), (cxm + 16, 38), (cxm + 8, 52), (cxm - 8, 52)], fill=(132, 96, 78, 255), ink=True, width=1.0)
        t.rect(cxm - 18, 34, cxm + 18, 38, fill=(150, 112, 92, 255), ink=True, width=0.9)

    # --- pluviale di rame, verde spento, con le fascette ---
    t.rect(1150, 112, 1155, GROUND, fill=(98, 116, 102, 255), ink=True, width=0.8)
    for y in range(140, GROUND, 60):
        t.rect(1148, y, 1157, y + 3, fill=(70, 80, 72, 255))
    # contorno del palazzo
    t.rect(756, GROUND - 8, 1164, GROUND, fill=stone_s, ink=True, width=1.0)  # lo zoccolo
    t.rect(760, 110, 1160, GROUND, ink=True, width=1.4)
    t.save(OUT, name)
    lt.save(OUT, name.replace(".png", "-luci.png"))


def balcony_rail():
    """La balaustrata dei balconi del palazzo: colonnine a vaso tra corrimano e zoccolo di pietra."""
    W, H = 24, 30
    stone, sh = (200, 194, 180, 255), (164, 156, 142, 255)
    t = Tela(W, H, wrap=True)
    t.rect(0, 0, W, 4.5, fill=stone)
    t.rect(0, 3.2, W, 4.5, fill=sh)
    t.rect(0, H - 5, W, H, fill=stone)
    t.rect(0, H - 2, W, H, fill=sh)
    for y in (0.5, 4.5, H - 5, H - 0.6):
        t.line([(0, y), (W, y)], fill=INK, width=1.0)
    for cx in (6, 18):  # colonnina a vaso: collo, pancia, piede
        prof = [(0, 1.6), (0.12, 1.6), (0.22, 2.4), (0.45, 4.2), (0.62, 4.0), (0.78, 2.2), (0.9, 2.6), (1.0, 2.6)]
        y0, y1 = 4.5, H - 5
        left = [(cx - w, y0 + (y1 - y0) * k) for k, w in prof]
        right = [(cx + w, y0 + (y1 - y0) * k) for k, w in prof][::-1]
        t.poly(left + right, fill=stone)
        t.poly([(cx + w * 0.2, y0 + (y1 - y0) * k) for k, w in prof] + right, fill=sh)
        t.poly(left + right, ink=True, width=0.9)
    t.save(OUT, "balaustra-balcone.png")


def balcony_floor():
    """Il piano dei balconi: bordo chiaro, cornice con i dentelli come il cornicione del palazzo, ombra sotto."""
    W, H = 48, 14
    stone, sh = (200, 194, 180, 255), (164, 156, 142, 255)
    t = Tela(W, H, bg=stone, wrap=True)
    t.rect(0, 0, W, 3, fill=EDGE)
    t.rect(0, 0, W, 0.7, fill=(248, 245, 236, 255))
    t.line([(0, 3), (W, 3)], fill=INK, width=0.9)
    t.rect(0, 6, W, 7, fill=sh)
    for x in range(0, W, 8):
        t.rect(x + 1.5, 7, x + 5.5, 10.5, fill=stone, ink=True, width=0.7)
    t.rect(0, 10.5, W, H, fill=sh)
    t.line([(0, H - 0.6), (W, H - 0.6)], fill=INK, width=1.2)
    t.save(OUT, "balcone.png")


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


FOUNTAIN = (960, 490, 160, 20)  # la vasca (#378): centro e raggi dell'anello di pietra, nella prospettiva del piano
RING = (960, 494, 198, 24)  # l'anello dei paracarri con la ringhiera attorno alla vasca


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
    I piedi sono a (960, 524); i getti li disegna il gioco e partono dal centro dell'acqua (960, 492)."""
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
    """La metà vicina dei paracarri con la ringhiera attorno alla vasca (#378), davanti ai lottatori e
    semitrasparente: più grandi e più in basso di quelli dietro, fino al bordo dove si cammina. Piedi a (960, 530)."""
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


def foundations():
    """Sotto la piazza sospesa (#288): le fondamenta di mattoni che si stringono a imbuto, con gli archi di
    scarico, i conci di pietra agli spigoli, la roccia che si sbriciola in fondo, l'edera e le radici che pendono.
    Va da x 100 a 1820 e da y 590 (sotto il fianco della piazza) a 760."""
    t = Tela(1720, 170, origin=(100, 590))
    rng = rand(41)
    brick, brick_s, mortar = (126, 86, 70, 255), (104, 70, 58, 255), (84, 62, 54, 255)
    stone, stone_s = (150, 142, 128, 255), (122, 116, 104, 255)
    # il profilo: largo in alto, poi scende a gradoni e si chiude a punta irregolare
    left = [(100, 590), (130, 610), (190, 618), (240, 640), (330, 652), (420, 676), (560, 690), (700, 716), (820, 736), (900, 752)]
    right = [(1820 - (x - 100), y) for x, y in left]
    body = left + [(960, 760)] + right[::-1]
    # i mattoni su una tela a parte, ritagliata nella sagoma: corsi sfalsati, in ombra sotto la piazza
    wall = Tela(1720, 170, origin=(100, 590), bg=brick)
    for row in range(int(170 / 6)):
        y = 592 + row * 6
        wall.line([(100, y), (1820, y)], fill=mortar, width=0.6)
        off = 0 if row % 2 else 6
        for x in range(100 + off, 1820, 12):
            wall.line([(x, y), (x, y + 6)], fill=mortar, width=0.5)
    wall.glaze([(100, 640), (1820, 640), (1820, 760), (100, 760)], (40, 30, 30, 70))
    t.paste_inside(wall, body)
    # archi di scarico ciechi, con i conci di pietra
    for ax in (380, 700, 1220, 1540):
        w, top, bot = 150, 600, 660 if ax in (380, 1540) else 690
        t.rect(ax - w / 2, top + w * 0.3, ax + w / 2, bot, fill=brick_s)
        t.pieslice(ax - w / 2, top, ax + w / 2, top + w * 0.6, 180, 360, fill=brick_s)
        for k in range(11):
            a0, a1 = math.pi * k / 11, math.pi * (k + 1) / 11
            rr, r2 = w / 2, w / 2 + 9
            cy = top + w * 0.3
            pts = [(ax - rr * math.cos(a0), cy - rr * 0.6 * math.sin(a0)), (ax - r2 * math.cos(a0), cy - r2 * 0.6 * math.sin(a0)),
                   (ax - r2 * math.cos(a1), cy - r2 * 0.6 * math.sin(a1)), (ax - rr * math.cos(a1), cy - rr * 0.6 * math.sin(a1))]
            t.poly(pts, fill=stone if k % 2 else stone_s, ink=True, width=0.8)
    # mensoloni di pietra sotto il bordo della piazza
    for x in range(140, 1800, 120):
        t.poly([(x - 10, 590), (x + 10, 590), (x + 6, 604), (x - 6, 604)], fill=stone, ink=True, width=0.8)
        t.poly([(x + 2, 590), (x + 10, 590), (x + 6, 604), (x + 2, 604)], fill=stone_s)
    # la roccia in fondo, che si sbriciola: massi grigi in due toni
    for k in range(26):
        u = k / 25
        x = 760 + u * 400 + rng.uniform(-30, 30)
        y = 730 + (1 - abs(u - 0.5) * 2) * 22 + rng.uniform(-6, 4)
        r = rng.uniform(10, 20)
        pts = [(x + math.cos(a) * r * rng.uniform(0.8, 1.1), y + math.sin(a) * r * 0.7 * rng.uniform(0.8, 1.1)) for a in [i * math.pi / 4 for i in range(8)]]
        t.poly(pts, fill=(118, 112, 104, 255), ink=True, width=0.9)
        t.poly(pts[1:4] + [(x, y)], fill=(96, 92, 86, 255))
    t.poly(body, ink=True, width=1.4)
    # edera e radici che pendono dal bordo e dagli archi, con le foglie a cuore
    for x in list(range(150, 1800, 70)):
        if rng.random() < 0.55:
            continue
        length = rng.uniform(30, 120)
        pts = [(x, 592)]
        for k in range(1, 7):
            pts.append((x + math.sin(k * 0.9 + x) * 6, 592 + length * k / 6))
        if rng.random() < 0.5:
            t.line(pts, fill=(84, 70, 56, 255), width=1.1)  # radice
            continue
        t.line(pts, fill=(56, 74, 50, 255), width=1.0)
        for k, (lx, ly) in enumerate(pts[1:]):
            s = 4.0 if k % 2 else 3.2
            side = 1 if k % 2 else -1
            leaf = [(lx, ly), (lx + side * s * 1.3, ly - s * 0.6), (lx + side * s * 1.6, ly + s * 0.5), (lx + side * s * 0.4, ly + s)]
            t.poly(leaf, fill=(74, 98, 64, 255) if k % 3 else (60, 82, 54, 255), ink=True, width=0.6, ink_col=(30, 40, 28, 255))
    t.save(OUT, "fondamenta.png")


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
    # palazzo(), balcony_rail() e balcony_floor() disegnavano la Padova col palazzo, ora ferma in padova-palazzo (#378)
    fountain_back()
    fountain_front()
    fianco("fianco.png")  # dal #378 al posto di foundations(): l'isola sta nel canale
    plane_tree_prop("platano.png")
    piano("piano.png")
    canal_back("canale-dietro.png")
    ansa("ansa.png")
    bridges_and_statues("ponticelli.png")
    near_bank("primo-piano.png")
    near_statues("statue-primo-piano.png")
    layer("sfondo-0.png", sky, "sfondo-0-luci.png", lift=LIFT[0])
    layer("sfondo-1.png", buildings, "sfondo-1-luci.png", lift=LIFT[1])
    layer("sfondo-2.png", lawn, "sfondo-2-luci.png", lift=LIFT[2])
