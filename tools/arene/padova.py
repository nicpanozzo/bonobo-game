"""Segnaposto grafici dell'arena Padova (#230): materiali, ringhiere, statue e sfondo, disegnati col codice.

Stile del gioco (docs/stile-grafico.md): contorno a inchiostro, ombre piatte a 2 toni, fondale più spento
dei lottatori, bordo calpestabile chiaro, niente colori dei giocatori saturi vicino al piano di gioco.
Sono segnaposto: chi disegna in Krita può sostituire ogni PNG tenendo lo stesso nome e la stessa misura.
Le foto di Prato della Valle servono solo da riferimento e non entrano nella repo.

Uso: python3 tools/arene/padova.py  (scrive in public/assets/stages/padova/)
"""

import math
import os
import random
import sys

from PIL import Image, ImageDraw

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "public", "assets", "stages", "padova")
os.makedirs(OUT, exist_ok=True)

INK = (30, 26, 23, 255)
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


def paving():
    """Lastricato delle piazze: lastre a file sfalsate, due toni e giunti scuri."""
    w, h = 96, 96
    img = Image.new("RGBA", (w, h), STONE)
    d = ImageDraw.Draw(img)
    rng = random.Random(7)
    row_h = 24
    for r in range(h // row_h):
        y = r * row_h
        off = 0 if r % 2 == 0 else 24
        for x in range(-48 + off, w, 48):
            tone = STONE_LIGHT if rng.random() < 0.35 else STONE
            d.rectangle([x + 1, y + 1, x + 46, y + row_h - 2], fill=tone)
            d.rectangle([x + 1, y + row_h - 6, x + 46, y + row_h - 2], fill=STONE_SHADE)  # ombra piatta in basso
        d.line([0, y, w, y], fill=STONE_SHADE, width=1)
        for x in range(-48 + off, w, 48):
            d.line([x, y, x, y + row_h], fill=STONE_SHADE, width=1)
    save(img, "pietra.png")


def edge(name, w, h, top=EDGE):
    img = Image.new("RGBA", (w, h), top)
    d = ImageDraw.Draw(img)
    d.line([0, h - 1, w, h - 1], fill=INK, width=1)
    d.line([0, 0, w, 0], fill=(250, 247, 238, 255), width=1)
    save(img, name)


def deck():
    """Il ponte, visto di lato: fascia di pietra con la cornice in alto e l'ombra sotto."""
    w, h = 64, 20
    img = Image.new("RGBA", (w, h), DECK)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w, 3], fill=EDGE)
    d.rectangle([0, 12, w, h], fill=DECK_SHADE)
    for x in range(0, w, 32):
        d.line([x, 4, x, h], fill=DECK_SHADE, width=1)
    d.line([0, h - 1, w, h - 1], fill=INK, width=1)
    save(img, "ponte.png")


def stairs():
    w, h = 32, 32
    img = Image.new("RGBA", (w, h), STAIR)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 18, w, h], fill=STAIR_SHADE)
    d.line([16, 0, 16, h], fill=STAIR_SHADE, width=1)
    save(img, "scala.png")
    edge("scala-bordo.png", 32, 5, TREAD)


def balustrade():
    """Ringhiera di Prato della Valle: corrimano, zoccolo, pilastrini e anelli traforati di marmo."""
    w, h = 48, 36
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # corrimano e zoccolo
    d.rectangle([0, 0, w, 5], fill=MARBLE, outline=None)
    d.rectangle([0, 4, w, 6], fill=MARBLE_SHADE)
    d.rectangle([0, h - 6, w, h - 1], fill=MARBLE)
    d.rectangle([0, h - 3, w, h - 1], fill=MARBLE_SHADE)
    d.line([0, 0, w, 0], fill=INK)
    d.line([0, 6, w, 6], fill=INK)
    d.line([0, h - 6, w, h - 6], fill=INK)
    d.line([0, h - 1, w, h - 1], fill=INK)
    # pilastrino (metà a ogni bordo, così ripetendo si unisce)
    for x0, x1 in ((0, 3), (w - 4, w - 1)):
        d.rectangle([x0, 6, x1, h - 6], fill=MARBLE)
    d.line([3, 6, 3, h - 6], fill=INK)
    d.line([w - 4, 6, w - 4, h - 6], fill=INK)
    # anello traforato con il nodo sopra e sotto
    cx, cy, r = w / 2, h / 2, 9
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=INK, width=4)
    d.ellipse([cx - r + 1, cy - r + 1, cx + r - 1, cy + r - 1], outline=MARBLE, width=2)
    d.rectangle([cx - 2, 6, cx + 2, cy - r + 1], fill=MARBLE, outline=INK)
    d.rectangle([cx - 2, cy + r - 1, cx + 2, h - 6], fill=MARBLE, outline=INK)
    save(img, "balaustra.png")


def slab():
    w, h = 64, 12
    img = Image.new("RGBA", (w, h), MARBLE)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w, 3], fill=EDGE)
    d.rectangle([0, 8, w, h], fill=MARBLE_SHADE)
    d.line([0, h - 1, w, h - 1], fill=INK)
    save(img, "lastra.png")


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

    # --- piedistallo tondo: zoccolo, fusto con la targa e la ghirlanda, cornice ---
    ped_h = min(48, total_h * 0.33) * S
    ped_w = 36 * S
    base = H - 1
    def band(y0, y1, half):
        d.rectangle([cx - half, y0, cx + half, y1], fill=MARBLE)
        d.rectangle([cx + half * 0.35, y0, cx + half, y1], fill=MARBLE_SHADE)
        d.rectangle([cx - half, y0, cx + half, y1], outline=INK, width=lw)
    band(base - 7 * S, base, ped_w / 2 + 6 * S)
    band(base - 10 * S, base - 7 * S, ped_w / 2 + 3 * S)
    band(base - ped_h + 9 * S, base - 10 * S, ped_w / 2)
    band(base - ped_h + 5 * S, base - ped_h + 9 * S, ped_w / 2 + 3 * S)
    band(base - ped_h, base - ped_h + 5 * S, ped_w / 2 + 7 * S)
    # targa con l'iscrizione (tratti illeggibili: il nome si sceglie con il gruppo)
    ty0, ty1 = base - ped_h + 14 * S, base - ped_h + 26 * S
    d.rectangle([cx - 12 * S, ty0, cx + 12 * S, ty1], fill=(200, 194, 180, 255), outline=INK, width=lw)
    for row in range(2):
        y = ty0 + (4 + row * 5) * S
        x = cx - 9 * S
        rng = random.Random(len(name) * 7 + row)
        while x < cx + 8 * S:
            seg = rng.randint(2, 4) * S
            d.line([x, y, min(x + seg, cx + 9 * S), y], fill=INK, width=S)
            x += seg + 2 * S
    # ghirlanda sotto la cornice
    gy = base - ped_h + 9 * S
    d.arc([cx - ped_w / 2 + 2 * S, gy - 4 * S, cx - 2 * S, gy + 8 * S], 10, 170, fill=INK, width=lw)
    d.arc([cx + 2 * S, gy - 4 * S, cx + ped_w / 2 - 2 * S, gy + 8 * S], 10, 170, fill=INK, width=lw)

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
    d.polygon([(cx - sh_w * 0.9, sh_y - S), (cx - sh_w * 1.65, sh_y + 16 * S), (cx - sh_w * 1.0, sh_y + 20 * S)], fill=(222, 216, 203, 255), outline=INK)

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


def arch():
    """Il fianco del ponte sotto il piano: pietra tra il piano curvo e l'arco, con le spalle ai lati. 1x."""
    x0, x1, y_top, y_bot = 720, 1200, 492, 692
    W, H = x1 - x0, y_bot - y_top
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def deck_y(x):
        u = max(-1, min(1, (x - 960) / 240))
        return 520 - 25 * (1 - u * u)

    cx, cy, rx, ry = 960, 692, 205, 148  # apertura dell'arco
    for x in range(W):
        wx = x0 + x
        top = deck_y(wx) - y_top
        dx = (wx - cx) / rx
        open_top = cy - ry * math.sqrt(max(0, 1 - dx * dx)) - y_top if abs(dx) < 1 else H
        if open_top > top:
            col = DECK if (x // 20 + int(top) // 18) % 2 == 0 else DECK_SHADE
            d.line([x, top, x, open_top], fill=DECK_SHADE if wx > 960 else DECK)
    # conci dell'arco e contorno
    pts = []
    for i in range(41):
        a = math.pi * i / 40
        pts.append((cx - rx * math.cos(a) - x0, cy - ry * math.sin(a) - y_top))
    d.line(pts, fill=INK, width=3)
    for i in range(1, 12):
        a = math.pi * i / 12
        p0 = (cx - rx * math.cos(a) - x0, cy - ry * math.sin(a) - y_top)
        p1 = (cx - (rx + 16) * math.cos(a) - x0, cy - (ry + 16) * math.sin(a) - y_top)
        d.line([p0, p1], fill=INK, width=2)
    for x in (0, W - 1):
        d.line([x, 0, x, H], fill=INK, width=3)
    save(img, "arco-ponte.png")


def layer(name, draw, W=2440, H=1480):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw(ImageDraw.Draw(img), W, H)
    save(img, name)


# Gli strati sono centrati sul centro dell'arena (960, 360): il pixel (u, v) è nel mondo a (960 - W/2 + u, 360 - H/2 + v)
def to_px(wx, wy, W=2440, H=1480):
    return wx - 960 + W / 2, wy - 360 + H / 2


SIL = (66, 74, 94, 255)  # sagome lontane: spente, più chiare del cielo ma più scure dei lottatori
SIL_SHADE = (57, 65, 85, 255)
SIL_LIGHT = (84, 92, 112, 255)
SIL_WIN = (47, 55, 73, 255)


def dome(d, cx, top_y, r, drum_h, lantern=True):
    """Cupola bizantina su tamburo, con la lanterna e la croce: metà in ombra, bordo chiaro a sinistra."""
    base = top_y + r + drum_h
    d.rectangle([cx - r * 0.82, top_y + r, cx + r * 0.82, base], fill=SIL)  # tamburo
    d.rectangle([cx + r * 0.2, top_y + r, cx + r * 0.82, base], fill=SIL_SHADE)
    for wx in range(int(cx - r * 0.6), int(cx + r * 0.6), max(6, int(r * 0.35))):  # finestrelle del tamburo
        d.rectangle([wx, top_y + r + drum_h * 0.3, wx + max(2, r * 0.1), top_y + r + drum_h * 0.75], fill=SIL_WIN)
    d.pieslice([cx - r, top_y, cx + r, top_y + 2 * r], 180, 360, fill=SIL)
    d.pieslice([cx - r, top_y, cx + r, top_y + 2 * r], 270, 360, fill=SIL_SHADE)
    d.arc([cx - r, top_y, cx + r, top_y + 2 * r], 190, 250, fill=SIL_LIGHT, width=2)
    for k in (-0.5, 0, 0.5):  # costoloni
        d.line([cx + k * r * 0.9, top_y + r * (1 - math.sqrt(1 - (k * 0.9) ** 2)), cx + k * r * 0.95, top_y + r], fill=SIL_SHADE, width=1)
    if lantern:
        lw, lh = max(3, r * 0.18), max(6, r * 0.35)
        d.rectangle([cx - lw, top_y - lh, cx + lw, top_y + 2], fill=SIL)
        d.ellipse([cx - lw * 1.2, top_y - lh - lw * 1.2, cx + lw * 1.2, top_y - lh + lw], fill=SIL)
        d.line([cx, top_y - lh - lw * 1.2, cx, top_y - lh - lw * 1.2 - r * 0.45], fill=SIL, width=2)  # croce
        d.line([cx - r * 0.1, top_y - lh - lw * 1.2 - r * 0.32, cx + r * 0.1, top_y - lh - lw * 1.2 - r * 0.32], fill=SIL, width=2)


def bell_tower(d, cx, base, h, w):
    """Campanile snello del Santo: fusto ottagonale con le cornici, due balconi e la cuspide a punta."""
    top = base - h
    d.rectangle([cx - w / 2, top + w * 2, cx + w / 2, base], fill=SIL)
    d.rectangle([cx + w * 0.1, top + w * 2, cx + w / 2, base], fill=SIL_SHADE)
    for k in (0.35, 0.6):  # cornici e balconi
        y = top + h * k
        d.rectangle([cx - w * 0.8, y, cx + w * 0.8, y + 4], fill=SIL_LIGHT)
        d.rectangle([cx - w * 0.3, y - 14, cx + w * 0.3, y - 4], fill=SIL_WIN)  # cella delle campane
    d.rectangle([cx - w * 0.7, top + w * 2 - 4, cx + w * 0.7, top + w * 2], fill=SIL_LIGHT)
    d.polygon([(cx - w * 0.55, top + w * 2), (cx + w * 0.55, top + w * 2), (cx, top - w * 1.4)], fill=SIL)  # cuspide
    d.polygon([(cx, top + w * 2), (cx + w * 0.55, top + w * 2), (cx, top - w * 1.4)], fill=SIL_SHADE)
    d.ellipse([cx - 3, top - w * 1.4 - 6, cx + 3, top - w * 1.4], fill=SIL)
    d.line([cx, top - w * 1.4 - 6, cx, top - w * 1.4 - 18], fill=SIL, width=2)


def basilica_del_santo(d, cx, base):
    """La Basilica di Sant'Antonio (il Santo) in sagoma dettagliata: facciata a capanna con la loggetta e i
    pinnacoli, il corpo della chiesa, le sette cupole, la cupola conica al centro e i due campanili a minareto."""
    # campanili, dietro a tutto
    bell_tower(d, cx - 95, base - 120, 300, 16)
    bell_tower(d, cx + 95, base - 120, 300, 16)
    # corpo della chiesa
    d.rectangle([cx - 230, base - 150, cx + 260, base], fill=SIL)
    d.rectangle([cx + 40, base - 150, cx + 260, base], fill=SIL_SHADE)
    for wx in range(int(cx - 220), int(cx + 250), 26):  # finestre a sesto acuto della navata
        d.rectangle([wx, base - 110, wx + 8, base - 70], fill=SIL_WIN)
        d.polygon([(wx, base - 110), (wx + 4, base - 118), (wx + 8, base - 110)], fill=SIL_WIN)
    # cupole: due file, la conica al centro
    for dx, r, lift in [(-150, 34, 0), (-75, 40, 10), (75, 40, 10), (150, 34, 0), (220, 30, -10), (-30, 36, 30), (40, 36, 30)]:
        dome(d, cx + dx, base - 150 - 2 * r - 26 - lift, r, 26)
    # la cupola conica sopra l'incrocio
    cbase = base - 150 - 40
    d.rectangle([cx - 46, cbase - 50, cx + 46, cbase], fill=SIL)
    d.rectangle([cx + 10, cbase - 50, cx + 46, cbase], fill=SIL_SHADE)
    for wx in range(int(cx - 38), int(cx + 38), 14):
        d.rectangle([wx, cbase - 40, wx + 5, cbase - 14], fill=SIL_WIN)
    d.polygon([(cx - 52, cbase - 50), (cx + 52, cbase - 50), (cx, cbase - 210)], fill=SIL)
    d.polygon([(cx, cbase - 50), (cx + 52, cbase - 50), (cx, cbase - 210)], fill=SIL_SHADE)
    d.line([cx - 52, cbase - 50, cx, cbase - 210], fill=SIL_LIGHT, width=2)
    dome(d, cx, cbase - 236, 10, 6)  # lanterna in cima al cono
    # facciata a capanna, davanti
    fx0, fx1, ftop = cx - 110, cx + 110, base - 200
    d.rectangle([fx0, ftop + 60, fx1, base], fill=SIL_LIGHT)
    d.polygon([(fx0 - 6, ftop + 62), (cx, ftop - 6), (fx1 + 6, ftop + 62)], fill=SIL_LIGHT)
    d.polygon([(cx, ftop - 6), (fx1 + 6, ftop + 62), (fx1, base), (cx + 30, base)], fill=SIL)
    for ax in range(int(fx0 + 16), int(fx1 - 16), 18):  # loggetta ad archetti sotto il timpano
        d.rectangle([ax, ftop + 70, ax + 10, ftop + 92], fill=SIL_WIN)
        d.pieslice([ax, ftop + 64, ax + 10, ftop + 76], 180, 360, fill=SIL_WIN)
    d.ellipse([cx - 22, ftop + 20, cx + 22, ftop + 62], fill=SIL_WIN)  # rosone
    d.ellipse([cx - 12, ftop + 30, cx + 12, ftop + 52], fill=SIL)
    for px in (cx - 70, cx, cx + 70):  # portali a lunetta
        d.rectangle([px - 18, base - 70, px + 18, base], fill=SIL_WIN)
        d.pieslice([px - 18, base - 88, px + 18, base - 52], 180, 360, fill=SIL_WIN)
    for px in (fx0 - 4, fx1 + 4):  # pinnacoli ai lati della facciata
        d.rectangle([px - 6, ftop + 30, px + 6, base], fill=SIL_LIGHT)
        d.polygon([(px - 7, ftop + 30), (px + 7, ftop + 30), (px, ftop - 4)], fill=SIL_LIGHT)
    d.line([cx, ftop - 6, cx, ftop - 30], fill=SIL_LIGHT, width=3)  # croce sul timpano
    d.line([cx - 8, ftop - 22, cx + 8, ftop - 22], fill=SIL_LIGHT, width=3)


def santa_giustina(d, cx, base):
    """Santa Giustina sul Prato: facciata grezza e le cupole con le statue in cima, più piccola e lontana."""
    d.rectangle([cx - 200, base - 110, cx + 200, base], fill=SIL_SHADE)
    for dx, r in [(-130, 34), (-40, 44), (60, 52), (150, 36)]:
        dome(d, cx + dx, base - 110 - 2 * r - 18, r, 18)
    d.rectangle([cx + 230, base - 300, cx + 262, base], fill=SIL_SHADE)  # campanile
    d.polygon([(cx + 226, base - 300), (cx + 266, base - 300), (cx + 246, base - 345)], fill=SIL_SHADE)


def sky(d, W, H):
    d.rectangle([0, 0, W, H], fill=SKY)
    for i, c in enumerate([(47, 57, 77), (52, 62, 82), (58, 66, 86)]):
        y = to_px(0, 120 + i * 110)[1]
        d.rectangle([0, y, W, H], fill=c + (255,))
    # nuvole basse, a strati piatti
    rng = random.Random(5)
    for _ in range(14):
        x, y = rng.uniform(0, W), to_px(0, rng.uniform(-200, 220))[1]
        w = rng.uniform(160, 380)
        for k in range(3):
            d.ellipse([x + k * w * 0.25, y - 18 - k * 6, x + k * w * 0.25 + w * 0.6, y + 14], fill=(60, 70, 92, 255))
        d.rectangle([x + w * 0.1, y, x + w * 0.9, y + 10], fill=(60, 70, 92, 255))
    base = to_px(0, 480)[1]
    santa_giustina(d, to_px(1420, 0)[0], base)
    basilica_del_santo(d, to_px(640, 0)[0], base)


def buildings(d, W, H):
    base = int(to_px(0, 540)[1])
    rng = random.Random(3)
    x = 0
    facades = [(84, 78, 68), (78, 72, 63), (90, 82, 70), (74, 70, 64)]
    while x < W:
        bw = rng.randint(120, 220)
        bh = rng.randint(150, 230)
        col = rng.choice(facades) + (255,)
        top = base - bh
        d.rectangle([x, top, x + bw, base], fill=col)
        d.rectangle([x - 4, top - 8, x + bw + 4, top], fill=(64, 60, 54, 255))  # tetto
        # portici: archi al piano terra, finestre sopra
        for ax in range(x + 10, x + bw - 20, 30):
            d.rectangle([ax, base - 46, ax + 20, base], fill=(46, 44, 42, 255))
            d.ellipse([ax, base - 56, ax + 20, base - 36], fill=(46, 44, 42, 255))
            for wy in range(top + 20, base - 70, 34):
                d.rectangle([ax + 5, wy, ax + 14, wy + 16], fill=(58, 55, 50, 255))
        x += bw
    # Loggia Amulea: archi gotici, terracotta spenta (il rosso saturo è di P1)
    lx = int(to_px(560, 0)[0])
    top = base - 250
    d.rectangle([lx, top, lx + 320, base], fill=(112, 78, 66, 255))
    d.rectangle([lx - 6, top - 14, lx + 326, top], fill=(150, 140, 126, 255))
    for row, (y0, y1) in enumerate([(top + 30, top + 110), (base - 100, base)]):
        for ax in range(lx + 14, lx + 300, 44):
            d.rectangle([ax, y0 + 20, ax + 30, y1], fill=(66, 46, 40, 255))
            d.polygon([(ax, y0 + 20), (ax + 15, y0), (ax + 30, y0 + 20)], fill=(66, 46, 40, 255))
    # tende bianche del mercato davanti ai portici
    for mx in range(int(to_px(1450, 0)[0]), int(to_px(1450, 0)[0]) + 420, 70):
        d.polygon([(mx, base - 30), (mx + 30, base - 52), (mx + 60, base - 30)], fill=(150, 148, 142, 255))
        d.rectangle([mx + 4, base - 30, mx + 56, base], fill=(70, 68, 64, 255))


def lawn(d, W, H):
    base = int(to_px(0, 560)[1])
    d.rectangle([0, base - 40, W, base + 70], fill=(56, 70, 52, 255))  # il prato dell'Isola Memmia, spento
    d.rectangle([0, base + 70, W, H], fill=(34, 40, 52, 255))  # sotto il palco: il buio, non il prato
    rng = random.Random(11)
    for tx in range(40, W, 210):  # alberi
        x = tx + rng.randint(-40, 40)
        r = rng.randint(50, 80)
        d.rectangle([x - 6, base - 80, x + 6, base - 30], fill=(44, 40, 34, 255))
        d.ellipse([x - r, base - 80 - 2 * r, x + r, base - 60], fill=(44, 58, 44, 255))
    for sx in range(90, W, 150):  # seconda fila di statue, piccole e grigie
        d.rectangle([sx - 10, base - 70, sx + 10, base - 40], fill=(128, 124, 116, 255))
        d.rectangle([sx - 6, base - 112, sx + 6, base - 70], fill=(138, 134, 126, 255))
        d.ellipse([sx - 6, base - 126, sx + 6, base - 112], fill=(138, 134, 126, 255))
    d.rectangle([0, base - 40, W, base - 32], fill=(150, 146, 136, 255))  # balaustra bassa del canale lontano


if __name__ == "__main__":
    paving()
    edge("bordo.png", 96, 8)
    deck()
    stairs()
    balustrade()
    slab()
    statue("statua-ponte.png", 112, 180, "giovane")  # regge la lastra a y 410 dalla piazza a y 520 (+2 di appoggio)
    statue("statua-alta.png", 192, 140, "filosofo")  # regge la lastra a y 330
    statue("statua-piazza.png", 142, 180, "dama")  # regge la lastra a y 380
    # Le due statue giganti nel canale (dal fondo a y 690) che reggono la lastra centrale a y 250
    statue("statua-gigante-a.png", 442, 110, "giovane")
    statue("statua-gigante-b.png", 442, 110, "filosofo")
    arch()
    layer("sfondo-0.png", sky)
    layer("sfondo-1.png", buildings)
    layer("sfondo-2.png", lawn)
