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

from PIL import Image, ImageDraw, ImageFilter

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
    """Il muro della riva (#264): grandi blocchi di trachite sfalsati, con muschio sui giunti, colature d'acqua,
    qualche crepa e spigolo sbreccato. Piastrella 240×120 di mondo che si ripete nei due versi."""
    W, H, ROW = 240, 120, 40
    t = Tela(W, H, bg=MALTA, wrap=True, wrap_y=True)
    rng = rand(9)
    for r in range(H // ROW):
        y0 = r * ROW
        x = rng.randint(0, 60)
        widths = []
        while sum(widths) < W - 70:
            widths.append(rng.choice([60, 70, 80, 90, 100]))
        widths.append(W - sum(widths))
        for bw in widths:
            tone = mix(TRACHITE, light(TRACHITE, 1.1), rng.random()) if rng.random() < 0.5 else mix(TRACHITE, shade(TRACHITE, 0.92), rng.random())
            x0, x1, y1 = x + 1, x + bw - 1, y0 + ROW - 1
            chip = (rng.choice(["tl", "tr", "bl", "br"]), rng.uniform(4, 8)) if rng.random() < 0.35 else None
            t.block(x0, y0 + 1, x1, y1, tone, side=3, bottom=6, width=1.2, chip=chip, ink_col=(54, 50, 46, 255))  # inchiostro più morbido: il muro sta sotto il piano di gioco
            # segni dello scalpello: due tratti in ombra
            for _ in range(rng.randint(0, 2)):
                sx, sy = rng.uniform(x0 + 8, x1 - 20), rng.uniform(y0 + 8, y1 - 12)
                t.line([(sx, sy), (sx + rng.uniform(8, 16), sy + rng.uniform(-1, 1))], fill=shade(tone, 0.88), width=1.2)
            if rng.random() < 0.2:
                t.crack(rng.uniform(x0 + 10, x1 - 10), y0 + 2, ROW - 8, rng, col=(64, 60, 54, 255))
            # colature scure che scendono dal giunto di sopra
            if rng.random() < 0.45:
                cx = rng.uniform(x0 + 6, x1 - 10)
                long = rng.uniform(16, 32)
                t.glaze([(cx, y0 + 1), (cx + 7, y0 + 1), (cx + 6, y0 + long * 0.7), (cx + 4, y0 + long), (cx + 2, y0 + long * 0.8)], (60, 62, 56, 60))
            # muschio sul bordo di sopra, a ciuffi
            if rng.random() < 0.3:
                mx = rng.uniform(x0 + 4, x1 - 24)
                for k in range(rng.randint(3, 5)):
                    rr = rng.uniform(2.2, 3.6)
                    t.circle(mx + k * 4.5, y0 + 1.5, rr, fill=MUSCHIO if k % 2 else shade(MUSCHIO, 0.85))
            x += bw
    t.save(OUT, "riva.png")


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


def layer(name, draw, lights=None):
    """Uno strato dello sfondo: draw(t) disegna sulla tela in pixel di mondo; il file esce a 2x (art.scale 0.5).
    Con lights, anche l'immagine delle luci della notte (#288): solo i vetri accesi, nello stesso posto."""
    t = Tela(LW, LH, origin=L_ORIGIN, ss=1)
    t.lights = Tela(LW, LH, origin=L_ORIGIN, ss=1) if lights else None
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
    santa_giustina(t, 300, base + 10)
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
        t.rect(ax - 2, base - 50, ax + 4, base, fill=stone)  # colonna
        t.rect(ax - 4, base - 52, ax + 6, base - 48, fill=stone)  # capitello
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
        t.line([(x, fy), (x + w, fy)], fill=sh, width=1.4)  # marcapiano
    # l'ombra a destra e il contorno
    t.rect(x + w - 6, top, x + w, base - 62, fill=sh)
    t.rect(x, top, x + w, base, ink=True, width=1.0, ink_col=ink)
    # cornicione con le mensole e il tetto di coppi
    t.rect(x - 5, top - 8, x + w + 5, top, fill=stone, ink=True, width=0.9, ink_col=ink)
    for mx in range(int(x), int(x + w), 9):
        t.rect(mx, top, mx + 3, top + 3, fill=shade(stone, 0.85))
    roof = far((122, 84, 68, 255), 0.18)
    t.poly([(x - 6, top - 8), (x + w + 6, top - 8), (x + w - 10, top - 22), (x + 10, top - 22)], fill=roof, ink=True, width=0.9, ink_col=ink)
    for k in range(int(w / 6)):
        t.arc(x + 4 + k * 6, top - 20, x + 10 + k * 6, top - 12, 180, 360, fill=shade(roof, 0.82), width=0.7)
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
def plane_tree(t, x, base, r, rng):
    """Un platano: tronco chiaro a chiazze (la corteccia che si stacca), rami e chioma a ciuffi in due toni
    con il contorno a inchiostro attorno alla sagoma."""
    ink = (36, 44, 36, 255)
    bark, bark_s = (150, 146, 124, 255), (112, 110, 94, 255)
    th = r * 1.3
    trunk = [(x - 7, base), (x + 7, base), (x + 4, base - th), (x - 4, base - th)]
    t.poly(trunk, fill=bark)
    t.poly([(x + 1, base), (x + 7, base), (x + 4, base - th), (x + 1, base - th)], fill=bark_s)
    for k in range(6):  # chiazze della corteccia
        py = base - rng.uniform(4, th - 6)
        px = x + rng.uniform(-4, 3)
        t.ellipse(px - 2.5, py - 3.5, px + 2.5, py + 3.5, fill=rng.choice([(176, 172, 146, 255), (96, 100, 84, 255)]))
    t.poly(trunk, ink=True, width=1.0, ink_col=ink)
    for side in (-1, 1):  # rami
        t.line([(x, base - th * 0.8), (x + side * r * 0.5, base - th - r * 0.4)], fill=bark_s, width=3)
    blobs = []
    for i in range(9):
        a = i / 8 * math.pi
        cx, cy = x + math.cos(a) * r * 0.7, base - th - r * 0.45 - math.sin(a) * r * 0.55
        blobs.append((cx, cy, r * rng.uniform(0.38, 0.55)))
    blobs.append((x, base - th - r * 0.5, r * 0.6))
    for cx, cy, rr in blobs:  # prima il contorno, un po' più grande
        t.circle(cx, cy, rr + 1.6, fill=ink)
    for cx, cy, rr in blobs:
        t.circle(cx, cy, rr, fill=(52, 70, 50, 255))
    for cx, cy, rr in blobs:  # la luce in alto a sinistra di ogni ciuffo
        t.circle(cx - rr * 0.22, cy - rr * 0.25, rr * 0.62, fill=(66, 86, 60, 255))


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


def lawn(t):
    base = 560
    rng = rand(11)
    t.rect(-300, base - 50, 2200, base + 70, fill=(58, 72, 54, 255))  # il prato dell'Isola Memmia, spento
    # sotto il prato, giù in basso, la ghiaia chiara del Prato con i vialetti: l'isola ci galleggia sopra (#288)
    t.rect(-300, base + 70, 2200, 1110, fill=(176, 168, 150, 255))
    for k in range(9):
        y = base + 84 + k * 46
        t.line([(-300, y), (2200, y)], fill=(160, 152, 134, 255), width=1.4 + k * 0.3)
    for x in range(-300, 2200, 9):  # sassolini
        y = base + 80 + (x * 37) % 470
        t.circle(x, y, 1.2, fill=(150, 142, 126, 255))
    t.rect(-300, base + 66, 2200, base + 74, fill=(70, 86, 62, 255))  # bordo d'erba
    # l'ombra dell'isola sulla ghiaia, molto più giù: si capisce che la piazza galleggia
    t.glaze([(960 + 760 * math.cos(a), base + 300 + 70 * math.sin(a)) for a in [i * math.tau / 40 for i in range(40)]], (60, 56, 48, 70))
    t.glaze([(960 + 520 * math.cos(a), base + 300 + 46 * math.sin(a)) for a in [i * math.tau / 40 for i in range(40)]], (60, 56, 48, 50))
    # la canaletta lontana con la balaustra e la seconda fila di statue
    t.rect(-300, base - 40, 2200, base - 30, fill=(146, 142, 132, 255))
    for sx in range(-240, 2200, 120):
        small_statue(t, sx, base - 36, rng)
    # platani, poi il vialetto, le panchine e i lampioni davanti
    for tx in range(-230, 2200, 160):  # più fitti dal #288
        plane_tree(t, tx + rng.randint(-40, 40), base - 50, rng.randint(48, 70), rng)
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


def palazzo(name):
    """Il palazzo signorile al centro, dietro il ponte (#280 passo 2), x 740-1180, y 40-480, a 2x.

    Portico a bugnato con i conci sugli archi, mezzanino con le inferriate, piano nobile con la trifora gotica e
    le bifore (le luci di notte stanno su queste finestre: art.life.daycycle.windows), ultimo piano con le persiane,
    cornicione con le mensole, tetto di coppi e camini a imbuto. L'intonaco caldo ha qualche scrostatura che mostra
    i mattoni. I balconi veri sono piattaforme (y 300 e 180): qui ci sono solo le mensole sotto."""
    t = Tela(440, 440, origin=(740, 40))
    lt = Tela(440, 440, origin=(740, 40))  # le luci della notte (#288): solo i vetri accesi, nello stesso posto
    rng = rand(21)
    plaster, plaster_s = (156, 122, 94, 255), (132, 102, 78, 255)
    stone, stone_s = (188, 182, 168, 255), (156, 148, 135, 255)  # un po' più spenta dei balconi, che si calpestano
    dark, glass = (46, 40, 38, 255), (58, 62, 66, 255)
    shutter, shutter_s = (88, 104, 84, 255), (70, 84, 68, 255)
    brick = (132, 84, 66, 255)

    # --- corpo: intonaco, le ombre portate le mettono cornici e balconi ---
    t.rect(760, 110, 1160, 480, fill=plaster)
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

    # --- portico a bugnato (y 380-480) ---
    t.rect(760, 380, 1160, 480, fill=stone)
    for row in range(5):
        y = 380 + row * 20
        off = 0 if row % 2 == 0 else 20
        for x in range(760 - off, 1160, 40):
            x0, x1 = max(760, x), min(1160, x + 40)
            if x1 - x0 > 2:
                t.block(x0 + 0.5, y + 0.5, x1 - 0.5, y + 19.5, mix(stone, stone_s, rng.random() * 0.3), sh=stone_s, bottom=3, side=2, width=0.8)
    for i in range(5):  # archi con i conci a raggiera e la chiave
        ax = 778 + i * 78
        cxa, r = ax + 26, 26
        t.rect(ax, 410, ax + 52, 480, fill=dark)
        t.pieslice(ax, 384, ax + 52, 436, 180, 360, fill=dark)
        t.rect(ax + 4, 446, ax + 48, 480, fill=(54, 48, 44, 255))  # il fondo del portico, appena più chiaro in basso
        for k in range(9):
            a0, a1 = math.pi * k / 9, math.pi * (k + 1) / 9
            out = 10 if k == 4 else 7
            pts = [(cxa - r * math.cos(a0), 410 - r * math.sin(a0)), (cxa - (r + out) * math.cos(a0), 410 - (r + out) * math.sin(a0)),
                   (cxa - (r + out) * math.cos(a1), 410 - (r + out) * math.sin(a1)), (cxa - r * math.cos(a1), 410 - r * math.sin(a1))]
            t.poly(pts, fill=stone if k < 5 else stone_s, ink=True, width=0.8)
        t.line([(ax, 410), (ax, 480)], fill=INK, width=1.2)
        t.line([(ax + 52, 410), (ax + 52, 480)], fill=INK, width=1.2)
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
    t.rect(1150, 112, 1155, 480, fill=(98, 116, 102, 255), ink=True, width=0.8)
    for y in range(140, 480, 60):
        t.rect(1148, y, 1157, y + 3, fill=(70, 80, 72, 255))
    # contorno del palazzo
    t.rect(760, 110, 1160, 480, ink=True, width=1.4)
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


def fountain_back():
    """La fontana dell'Isola Memmia vista di fianco e un po' dall'alto (#288): la vasca tonda di pietra con
    l'acqua, i riflessi e il bocchettone al centro; dietro, i paracarri con la palla e la ringhiera di ferro.
    I piedi sono a (960, 524): la vasca sta sulla piazza, lo zampillo lo disegna il gioco."""
    t = Tela(360, 70, origin=(780, 454))
    cx, rim_y, rx, ry = 960, 508, 152, 15
    # paracarri e ringhiera sul lato lontano: più piccoli e più in alto
    posts = [cx + rx * 1.08 * math.cos(a) for a in (math.pi * 0.08, math.pi * 0.3, math.pi * 0.5, math.pi * 0.7, math.pi * 0.92)]
    ys = [rim_y - ry * 1.15 * math.sin(a) - 6 for a in (math.pi * 0.08, math.pi * 0.3, math.pi * 0.5, math.pi * 0.7, math.pi * 0.92)]
    for k in range(len(posts) - 1):
        railing(t, posts[k], posts[k + 1], ys[k] - 13, ys[k] - 4, curls=True)
    for x, y in zip(posts, ys):
        bollard(t, x, y, 26, stone=(206, 200, 186, 255), sh=(172, 164, 150, 255))
    # il bordo della vasca: anello di pietra, la parte di dietro più scura (in ombra) e il piano chiaro
    t.ellipse(cx - rx - 8, rim_y - ry - 5, cx + rx + 8, rim_y + ry + 5, fill=(214, 208, 194, 255), ink=True, width=1.1)
    t.chord(cx - rx - 8, rim_y - ry - 5, cx + rx + 8, rim_y + ry + 5, 180, 360, fill=(188, 180, 166, 255))
    t.ellipse(cx - rx - 8, rim_y - ry - 5, cx + rx + 8, rim_y + ry + 5, ink=True, width=1.1)
    # l'acqua dipinta (#288): verde acqua spento, più scura sotto il bordo lontano, i riflessi del cielo spezzati
    # dalle increspature, gli anelli d'onda interrotti attorno allo zampillo e la schiuma
    from pittura import Quadro, wobble
    q = Quadro(360, 70, origin=(780, 454))
    wm = q.ellipse(q.mask(), cx - rx, rim_y - ry, cx + rx, rim_y + ry)
    q.fill(wm, WATER)
    q.fill(q.inner_shadow(wm, 0, 7, 3.5), WATER_S, 0.9)
    rng = rand(61)
    for k in range(16):  # riflessi a pennellate orizzontali, interrotte
        y = rim_y - ry * 0.4 + rng.uniform(0, ry * 1.2)
        x0 = cx + rng.uniform(-rx * 0.85, rx * 0.6)
        ln = rng.uniform(10, 40)
        pts = wobble([(x0 + ln * j / 6, y + math.sin(j) * 0.6) for j in range(7)], 0.5, k, closed=False)
        q.fill(q.intersect(q.soften(q.stroke(q.mask(), pts, rng.uniform(0.8, 1.8)), 0.4), wm), WATER_L, rng.uniform(0.35, 0.8))
    for r_ in (22, 38, 56, 78):  # anelli d'onda: archi spezzati, non cerchi
        for j in range(6):
            a0 = j / 6 * math.tau + r_ * 0.1
            arc = [(cx + r_ * math.cos(a0 + i * 0.12), rim_y + 2 + r_ * 0.11 * math.sin(a0 + i * 0.12)) for i in range(5)]
            q.fill(q.intersect(q.soften(q.stroke(q.mask(), arc, 0.7), 0.3), wm), (184, 212, 210), 0.5 - r_ / 200)
    t.img.alpha_composite(q.img)
    # il bocchettone al centro, di bronzo scuro
    t.rect(cx - 6, rim_y - 6, cx + 6, rim_y + 2, fill=(96, 92, 80, 255), ink=True, width=0.9)
    t.ellipse(cx - 8, rim_y - 9, cx + 8, rim_y - 4, fill=(120, 116, 100, 255), ink=True, width=0.8)
    # lo spigolo di pietra davanti, sotto il quale c'è la ghiaia della piazza
    t.rect(cx - rx - 8, rim_y, cx + rx + 8, 524, fill=(198, 192, 178, 255))
    t.rect(cx - rx - 8, 518, cx + rx + 8, 524, fill=(172, 165, 151, 255))
    t.line([(cx - rx - 8, rim_y), (cx - rx - 8, 524)], fill=INK, width=1.1)
    t.line([(cx + rx + 8, rim_y), (cx + rx + 8, 524)], fill=INK, width=1.1)
    t.chord(cx - rx - 8, rim_y - ry - 5, cx + rx + 8, rim_y + ry + 5, 0, 180, fill=(214, 208, 194, 255))
    t.arc(cx - rx - 8, rim_y - ry - 5, cx + rx + 8, rim_y + ry + 5, 0, 180, fill=INK, width=1.1)
    t.arc(cx - rx, rim_y - ry, cx + rx, rim_y + ry, 0, 180, fill=INK, width=1.0)
    t.save(OUT, "fontana.png")


def fountain_front():
    """Il davanti della fontana (#288), davanti ai lottatori e semitrasparente: i tre paracarri vicini con la
    ringhiera bassa. Piedi a (960, 530)."""
    t = Tela(380, 44, origin=(770, 486))
    posts = [802, 880, 960, 1040, 1118]
    for k in range(len(posts) - 1):
        railing(t, posts[k], posts[k + 1], 506, 520)
    for x in posts:
        bollard(t, x, 530, 40)
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
    """Un platano sulla piazza (#288), disegnato con cura: tronco chiaro a chiazze di corteccia, i rami che si
    aprono, la chioma a nuvole di foglie in due toni con il contorno a inchiostro e qualche foglia a mano
    sul bordo. Piedi a (410, 522), la chioma da y 110 a 360: sta sopra le teste e lascia vedere il palco."""
    t = Tela(300, 420, origin=(260, 102))
    rng = rand(51)
    x, base = 410, 522
    bark, bark_s, bark_l, bark_d = (176, 170, 146, 255), (138, 134, 114, 255), (206, 202, 178, 255), (112, 112, 96, 255)
    ink = (36, 40, 32, 255)
    # tronco che si allarga al piede, un po' storto
    trunk = [(x - 13, base), (x - 9, base - 40), (x - 8, base - 120), (x - 12, base - 170), (x + 2, base - 178), (x + 12, base - 168), (x + 8, base - 120), (x + 9, base - 40), (x + 15, base)]
    t.poly(trunk, fill=bark)
    t.poly([(x + 2, base), (x + 2, base - 176), (x + 12, base - 168), (x + 8, base - 120), (x + 9, base - 40), (x + 15, base)], fill=bark_s)
    for k in range(18):  # la corteccia che si stacca a chiazze
        py = base - rng.uniform(6, 165)
        px = x + rng.uniform(-8, 7)
        r = rng.uniform(2.2, 4.5)
        t.poly([(px - r, py), (px - r * 0.3, py - r * 1.3), (px + r, py - r * 0.2), (px + r * 0.2, py + r)], fill=rng.choice([bark_l, bark_d, (156, 160, 132, 255)]))
    t.poly(trunk, ink=True, width=1.2, ink_col=ink)
    # rami principali verso la chioma
    for (dx, dy, ex, ey, w) in ((0, -170, -70, -250, 6), (2, -172, 60, -262, 6), (-6, -140, -100, -200, 4), (6, -150, 96, -214, 4), (0, -175, 6, -290, 5)):
        t.line([(x + dx, base + dy), (x + ex, base + ey)], fill=ink, width=w + 2)
        t.line([(x + dx, base + dy), (x + ex, base + ey)], fill=bark_s, width=w)
    # chioma: nuvole di foglie, prima il contorno, poi l'ombra, poi la luce in alto a sinistra
    blobs = []
    for k in range(16):
        a = math.pi * (0.95 + 1.1 * k / 15)
        cx = x + math.cos(a) * 92 * rng.uniform(0.75, 1.05)
        cy = base - 270 + math.sin(a) * 120 * rng.uniform(0.7, 1.0) * -1 * -1
        blobs.append((cx, min(cy, base - 190), rng.uniform(30, 46)))
    for k in range(7):
        blobs.append((x + rng.uniform(-70, 70), base - 300 + rng.uniform(-40, 40), rng.uniform(34, 48)))
    for cx, cy, r in blobs:
        t.circle(cx, cy, r + 1.8, fill=ink)
    for cx, cy, r in blobs:
        t.circle(cx, cy, r, fill=(56, 76, 52, 255))
    for cx, cy, r in blobs:
        t.circle(cx - r * 0.2, cy - r * 0.24, r * 0.66, fill=(72, 96, 64, 255))
    for cx, cy, r in blobs[::2]:
        t.circle(cx - r * 0.34, cy - r * 0.4, r * 0.3, fill=(90, 116, 76, 255))
    # foglie palmate sul bordo della chioma
    for cx, cy, r in blobs[:16]:
        for j in range(2):
            a = rng.uniform(0, math.tau)
            lx, ly = cx + math.cos(a) * r, cy + math.sin(a) * r
            leaf = [(lx + 4.5 * math.cos(b) * (1 if i % 2 == 0 else 0.45), ly + 4.5 * math.sin(b) * (1 if i % 2 == 0 else 0.45)) for i, b in enumerate([a + i * math.pi / 5 for i in range(10)])]
            t.poly(leaf, fill=(64, 88, 58, 255), ink=True, width=0.6, ink_col=ink)
    # i rametti che si vedono tra le foglie
    for k in range(5):
        sx, sy = x + rng.uniform(-60, 60), base - rng.uniform(230, 320)
        t.line([(sx, sy), (sx + rng.uniform(-14, 14), sy - rng.uniform(10, 20))], fill=bark_d, width=1.6)
    t.save(OUT, name)


if __name__ == "__main__":
    paving()
    quay_wall()
    coping("bordo.png")
    slab()
    statue("statua-ponte.png", 112, 180, "giovane")  # regge la lastra a y 410 dalla piazza a y 520 (+2 di appoggio)
    statue("statua-alta.png", 192, 140, "filosofo")  # regge la lastra a y 330
    statue("statua-piazza.png", 142, 180, "dama")  # regge la lastra a y 380
    palazzo("palazzo.png")
    fountain_back()
    fountain_front()
    foundations()
    plane_tree_prop("platano.png")
    balcony_rail()
    balcony_floor()
    layer("sfondo-0.png", sky, "sfondo-0-luci.png")
    layer("sfondo-1.png", buildings, "sfondo-1-luci.png")
    layer("sfondo-2.png", lawn, "sfondo-2-luci.png")
