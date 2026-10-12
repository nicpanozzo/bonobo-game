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


def quay_wall():
    """Il muro della riva sul canale (#264): grandi blocchi di pietra d'Istria sfalsati, umidi verso il basso."""
    w, h = 120, 60
    img = Image.new("RGBA", (w, h), (126, 120, 108, 255))
    d = ImageDraw.Draw(img)
    rng = random.Random(9)
    for r in range(2):
        y = r * 30
        off = 0 if r % 2 == 0 else 30
        for x in range(-60 + off, w, 60):
            tone = rng.choice([(132, 126, 114, 255), (122, 116, 104, 255), (138, 131, 118, 255)])
            d.rectangle([x + 1, y + 1, x + 58, y + 28], fill=tone)
            d.rectangle([x + 1, y + 22, x + 58, y + 28], fill=(108, 102, 92, 255))  # ombra piatta del blocco
            d.line([x, y, x, y + 30], fill=(90, 85, 76, 255), width=2)
        d.line([0, y, w, y], fill=(90, 85, 76, 255), width=2)
    save(img, "riva.png")


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


def outlined(d, pts, fill, ink, width=2):
    d.polygon(pts, fill=fill)
    d.line(list(pts) + [pts[0]], fill=ink, width=width, joint="curve")


def dome(d, cx, base, r, h, fill, shade, ink, ribs=6, lantern=True):
    """Cupola bizantina del Santo: calotta rialzata con i costoloni, tamburo e lanterna con la statuina in cima."""
    d.rectangle([cx - r * 0.95, base - r * 0.35, cx + r * 0.95, base], fill=fill, outline=ink, width=2)  # tamburo
    for i in range(1, 6):  # finestrelle del tamburo
        wx = cx - r * 0.8 + i * r * 0.27
        d.rectangle([wx - 2, base - r * 0.28, wx + 2, base - r * 0.08], fill=ink)
    top = base - r * 0.35
    pts = []
    for i in range(33):
        a = math.pi * i / 32
        pts.append((cx - math.cos(a) * r, top - math.sin(a) * h))
    d.polygon(pts, fill=fill)
    d.polygon([p for p in pts if p[0] >= cx] + [(cx, top)], fill=shade)
    d.line(pts, fill=ink, width=2)
    for k in range(1, ribs):  # costoloni
        u = -1 + 2 * k / ribs
        # dal tamburo alla lanterna, curvando come la calotta
        d.line([(cx + u * r * math.cos(t * math.pi / 2), top - h * math.sin(t * math.pi / 2)) for t in [j / 10 for j in range(11)]], fill=ink, width=1)
    if lantern:
        lt = top - h
        d.rectangle([cx - r * 0.16, lt - r * 0.32, cx + r * 0.16, lt + 2], fill=fill, outline=ink, width=2)
        d.pieslice([cx - r * 0.18, lt - r * 0.5, cx + r * 0.18, lt - r * 0.18], 180, 360, fill=fill, outline=ink, width=2)
        d.line([cx, lt - r * 0.34, cx, lt - r * 0.62], fill=ink, width=2)  # la statuina d'angelo, in sagoma
        d.ellipse([cx - 3, lt - r * 0.7, cx + 3, lt - r * 0.6], fill=ink)


def basilica_santo(d, cx, base, k=1.0):
    """La Basilica di Sant'Antonio vista da Prato della Valle: facciata a capanna con la loggia e il rosone,
    otto cupole (la conica al centro), i due campanili a minareto e le torrette. Sagoma azzurrata e lontana."""
    # di giorno: mattone spento della chiesa, piombo grigio delle cupole, un po' velati dalla lontananza
    F, S, I = (164, 128, 112, 255), (146, 112, 98, 255), (92, 76, 72, 255)
    L = (178, 144, 128, 255)
    # corpo della chiesa, dietro le cupole
    d.rectangle([cx - 330 * k, base - 150 * k, cx + 330 * k, base], fill=F, outline=I, width=2)
    for i in range(14):  # archetti pensili e finestre del fianco
        wx = cx - 300 * k + i * 45 * k
        d.rectangle([wx, base - 120 * k, wx + 12 * k, base - 70 * k], fill=I)
        d.pieslice([wx, base - 128 * k, wx + 12 * k, base - 112 * k], 180, 360, fill=I)
    # campanili a minareto ai lati dell'abside
    for tx in (cx + 150 * k, cx + 300 * k):
        d.rectangle([tx - 14 * k, base - 430 * k, tx + 14 * k, base], fill=F, outline=I, width=2)
        d.rectangle([tx + 2 * k, base - 430 * k, tx + 14 * k, base], fill=S)
        for j in range(4):  # balconcini a ogni piano
            yy = base - (160 + j * 70) * k
            d.rectangle([tx - 19 * k, yy - 5 * k, tx + 19 * k, yy], fill=L, outline=I, width=1)
            d.rectangle([tx - 4 * k, yy - 40 * k, tx + 4 * k, yy - 14 * k], fill=I)
        d.rectangle([tx - 10 * k, base - 480 * k, tx + 10 * k, base - 430 * k], fill=F, outline=I, width=2)  # cella campanaria
        d.polygon([(tx - 11 * k, base - 480 * k), (tx + 11 * k, base - 480 * k), (tx, base - 540 * k)], fill=S, outline=I)  # punta conica
        d.line([tx, base - 540 * k, tx, base - 556 * k], fill=I, width=2)
    # le cupole: due sulla navata, la conica al centro, poi quelle del transetto e dell'abside
    PB, PS, PL = (150, 158, 166, 255), (128, 136, 146, 255), (166, 172, 180, 255)  # piombo delle cupole
    dome(d, cx - 160 * k, base - 150 * k, 62 * k, 96 * k, PB, PS, I)
    dome(d, cx - 40 * k, base - 150 * k, 66 * k, 104 * k, PB, PS, I)
    dome(d, cx + 230 * k, base - 150 * k, 58 * k, 90 * k, PB, PS, I)
    dome(d, cx + 90 * k, base - 170 * k, 52 * k, 82 * k, PL, PB, I)
    dome(d, cx + 330 * k, base - 140 * k, 40 * k, 60 * k, PB, PS, I)
    # il cono: la cupola conica sopra l'altare
    cone_x, cone_b = cx + 60 * k, base - 210 * k
    d.rectangle([cone_x - 52 * k, cone_b, cone_x + 52 * k, base - 150 * k], fill=F, outline=I, width=2)
    outlined(d, [(cone_x - 50 * k, cone_b), (cone_x + 50 * k, cone_b), (cone_x, cone_b - 190 * k)], PB, I)
    d.polygon([(cone_x, cone_b), (cone_x + 50 * k, cone_b), (cone_x, cone_b - 190 * k)], fill=PS)
    for i in range(1, 5):
        d.line([cone_x - 50 * k + i * 20 * k, cone_b, cone_x, cone_b - 190 * k], fill=I, width=1)
    d.ellipse([cone_x - 6 * k, cone_b - 206 * k, cone_x + 6 * k, cone_b - 190 * k], fill=F, outline=I, width=2)
    # facciata a capanna, davanti a tutto
    fx0, fx1, ftop = cx - 330 * k, cx - 150 * k, base - 290 * k
    outlined(d, [(fx0, base), (fx0, ftop + 60 * k), ((fx0 + fx1) / 2, ftop), (fx1, ftop + 60 * k), (fx1, base)], L, I)
    d.polygon([((fx0 + fx1) / 2, ftop), (fx1, ftop + 60 * k), (fx1, base), ((fx0 + fx1) / 2, base)], fill=F)
    for i in range(4):  # la loggia a quattro archi
        ax = fx0 + 18 * k + i * 38 * k
        d.rectangle([ax, base - 200 * k, ax + 26 * k, base - 160 * k], fill=I)
        d.polygon([(ax, base - 200 * k), (ax + 13 * k, base - 216 * k), (ax + 26 * k, base - 200 * k)], fill=I)
    rx, ry = (fx0 + fx1) / 2, base - 240 * k  # rosone
    d.ellipse([rx - 18 * k, ry - 18 * k, rx + 18 * k, ry + 18 * k], fill=S, outline=I, width=2)
    for a in range(8):
        aa = a * math.pi / 4
        d.line([rx, ry, rx + math.cos(aa) * 16 * k, ry + math.sin(aa) * 16 * k], fill=I, width=1)
    for i in range(3):  # portali
        px = fx0 + 30 * k + i * 50 * k
        d.rectangle([px, base - 70 * k, px + 22 * k, base], fill=I)
        d.pieslice([px, base - 82 * k, px + 22 * k, base - 58 * k], 180, 360, fill=I)
    for tx in (fx0 + 6 * k, fx1 - 6 * k):  # torrette con la guglia ai lati della facciata
        d.rectangle([tx - 7 * k, ftop + 40 * k, tx + 7 * k, base], fill=L, outline=I, width=1)
        d.polygon([(tx - 8 * k, ftop + 40 * k), (tx + 8 * k, ftop + 40 * k), (tx, ftop + 2 * k)], fill=F, outline=I)


def santa_giustina(d, cx, base):
    """Santa Giustina, più lontana: facciata grezza, le otto cupole basse con le statuine e il campanile."""
    F, S, I = (170, 150, 140, 255), (154, 136, 128, 255), (110, 98, 94, 255)  # più lontana: più chiara e velata
    d.rectangle([cx - 230, base - 110, cx + 230, base], fill=F, outline=I, width=2)
    for i, (dx, r) in enumerate([(-170, 34), (-90, 44), (0, 56), (95, 44), (175, 34)]):
        dome(d, cx + dx, base - 110, r, r * 1.2, F, S, I, ribs=4)
    d.rectangle([cx + 250, base - 300, cx + 280, base], fill=F, outline=I, width=2)
    d.rectangle([cx + 254, base - 280, cx + 276, base - 250], fill=I)
    d.polygon([(cx + 247, base - 300), (cx + 283, base - 300), (cx + 265, base - 345)], fill=S, outline=I)


def cloud(d, x, y, w, col, shade):
    for i in range(5):
        cx = x + i * w / 5
        r = w * (0.16 + 0.08 * math.sin(i * 1.7 + x))
        d.ellipse([cx - r, y - r * 0.7, cx + r, y + r * 0.5], fill=col)
    d.ellipse([x - w * 0.05, y - w * 0.02, x + w * 0.85, y + w * 0.1], fill=shade)  # pancia in ombra


def sky(d, W, H):
    # Il cielo lo disegna il gioco (cielo vivo, #267): qui solo le sagome lontane, su fondo trasparente
    base = to_px(0, 470)[1]
    santa_giustina(d, to_px(300, 0)[0], base + 10)
    basilica_santo(d, to_px(1500, 0)[0], base, 0.95)


def palazzo_row(d, x0, x1, base, rng, tones):
    """Una fila di palazzi del centro: portici al piano terra, finestre gotiche, balconcini, tetti e camini a imbuto."""
    x = x0
    while x < x1:
        bw = rng.randint(130, 230)
        floors = rng.randint(3, 4)
        fh = rng.randint(40, 48)
        top = base - 60 - floors * fh
        col = rng.choice(tones)
        shade = tuple(max(0, c - 14) for c in col[:3]) + (255,)
        ink = (40, 38, 36, 255)
        d.rectangle([x, top, x + bw, base], fill=col, outline=ink, width=2)
        d.rectangle([x + bw * 0.72, top, x + bw, base], fill=shade)
        # portico
        d.rectangle([x, base - 60, x + bw, base], fill=shade)
        for ax in range(x + 6, x + bw - 26, 32):
            d.rectangle([ax, base - 44, ax + 24, base], fill=(44, 42, 40, 255))
            d.pieslice([ax, base - 56, ax + 24, base - 32], 180, 360, fill=(44, 42, 40, 255))
            d.line([ax - 4, base - 60, ax - 4, base], fill=ink, width=2)
        # piani con le finestre: gotiche al piano nobile, rettangolari sopra
        for f in range(floors):
            fy = base - 60 - (f + 1) * fh
            for wx in range(x + 14, x + bw - 18, 30):
                if f == 0:
                    d.rectangle([wx, fy + 10, wx + 14, fy + fh - 4], fill=(52, 50, 48, 255))
                    d.polygon([(wx, fy + 10), (wx + 7, fy + 2), (wx + 14, fy + 10)], fill=(52, 50, 48, 255))
                    d.rectangle([wx - 3, fy + fh - 6, wx + 17, fy + fh - 2], fill=(150, 144, 132, 255))  # balconcino
                else:
                    d.rectangle([wx + 2, fy + 10, wx + 12, fy + fh - 8], fill=(56, 54, 50, 255))
                    d.rectangle([wx - 1, fy + 8, wx + 15, fy + 10], fill=(140, 134, 122, 255))
            d.line([x, fy, x + bw, fy], fill=shade, width=2)  # marcapiano
        # tetto di coppi e cornice, camini veneziani a imbuto
        d.rectangle([x - 6, top - 10, x + bw + 6, top], fill=(98, 72, 60, 255), outline=ink, width=2)
        for cxm in (x + bw * 0.25, x + bw * 0.7):
            if rng.random() < 0.8:
                d.rectangle([cxm - 4, top - 34, cxm + 4, top - 10], fill=(110, 84, 70, 255), outline=ink, width=1)
                d.polygon([(cxm - 11, top - 46), (cxm + 11, top - 46), (cxm + 5, top - 32), (cxm - 5, top - 32)], fill=(110, 84, 70, 255), outline=ink)
        x += bw


def loggia_amulea(d, lx, base):
    """La Loggia Amulea: mattone rosso spento, archi gotici a due ordini, pilastri bianchi e la merlatura chiara."""
    ink = (44, 34, 32, 255)
    brick, brick_s, white = (118, 80, 68, 255), (100, 68, 58, 255), (176, 168, 154, 255)
    top = base - 270
    d.rectangle([lx, top, lx + 340, base], fill=brick, outline=ink, width=2)
    d.rectangle([lx + 240, top, lx + 340, base], fill=brick_s)
    for row, (y0, y1) in enumerate([(top + 34, top + 128), (base - 112, base)]):
        for i in range(7):
            ax = lx + 12 + i * 46
            d.rectangle([ax - 6, y0 - 6, ax - 2, y1], fill=white)  # pilastrini bianchi a strisce
            d.rectangle([ax, y0 + 22, ax + 34, y1], fill=(66, 44, 40, 255))
            d.polygon([(ax, y0 + 22), (ax + 17, y0), (ax + 34, y0 + 22)], fill=(66, 44, 40, 255))
            d.arc([ax - 3, y0 - 3, ax + 37, y0 + 40], 200, 340, fill=white, width=3)
    d.rectangle([lx, top + 128, lx + 340, top + 140], fill=white)  # balaustra del primo piano
    for i in range(34):
        d.rectangle([lx + 4 + i * 10, top + 129, lx + 7 + i * 10, top + 139], fill=brick_s)
    d.rectangle([lx - 6, top - 16, lx + 346, top], fill=white, outline=ink, width=2)  # merlatura bianca
    for i in range(22):
        d.rectangle([lx - 4 + i * 16, top - 30, lx + 6 + i * 16, top - 16], fill=white, outline=ink, width=1)


def buildings(d, W, H):
    base = int(to_px(0, 540)[1])
    rng = random.Random(3)
    tones = [(118, 104, 84, 255), (124, 98, 78, 255), (110, 104, 92, 255), (128, 112, 86, 255), (104, 92, 82, 255)]
    palazzo_row(d, -40, W + 40, base, rng, tones)
    loggia_amulea(d, int(to_px(520, 0)[0]), base)
    # bancarelle del mercato davanti ai portici, a destra
    mx0 = int(to_px(1420, 0)[0])
    for i, mx in enumerate(range(mx0, mx0 + 520, 74)):
        col = (172, 170, 162, 255) if i % 2 == 0 else (150, 152, 146, 255)
        d.polygon([(mx, base - 40), (mx + 34, base - 64), (mx + 68, base - 40)], fill=col, outline=(60, 58, 54, 255))
        d.rectangle([mx + 4, base - 40, mx + 64, base - 8], fill=(80, 76, 70, 255))
        for b in range(4):  # merce sui banchi
            d.ellipse([mx + 8 + b * 14, base - 22, mx + 18 + b * 14, base - 12], fill=rng.choice([(140, 110, 80, 255), (120, 124, 100, 255), (150, 130, 96, 255)]))
    # tavolini del bar con lo spritz arancione, sotto la loggia
    for tx in range(int(to_px(560, 0)[0]), int(to_px(820, 0)[0]), 46):
        d.ellipse([tx - 12, base - 26, tx + 12, base - 20], fill=(160, 154, 140, 255))
        d.line([tx, base - 20, tx, base - 4], fill=(60, 58, 54, 255), width=2)
        d.rectangle([tx - 4, base - 34, tx - 1, base - 26], fill=(196, 120, 64, 255))  # lo spritz
        d.rectangle([tx + 3, base - 33, tx + 6, base - 26], fill=(196, 120, 64, 255))


def plane_tree(d, x, base, r, rng):
    trunk = (72, 64, 54, 255)
    d.polygon([(x - 7, base), (x + 7, base), (x + 4, base - r * 1.3), (x - 4, base - r * 1.3)], fill=trunk)
    for i in range(7):
        a = i / 6 * math.pi
        cx, cy = x + math.cos(a) * r * 0.6, base - r * 1.5 - math.sin(a) * r * 0.5
        rr = r * rng.uniform(0.45, 0.65)
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=(50, 66, 50, 255))
    for i in range(4):  # chioma in luce
        cx, cy = x - r * 0.3 + i * r * 0.15, base - r * 1.85 + i * 4
        d.ellipse([cx - r * 0.3, cy - r * 0.25, cx + r * 0.3, cy + r * 0.25], fill=(60, 78, 58, 255))


def lamp(d, x, base, h):
    ink = (40, 40, 40, 255)
    d.rectangle([x - 2, base - h, x + 2, base], fill=(54, 54, 56, 255))
    d.rectangle([x - 6, base - 8, x + 6, base], fill=(54, 54, 56, 255))
    d.polygon([(x - 9, base - h), (x + 9, base - h), (x + 6, base - h - 18), (x - 6, base - h - 18)], fill=(150, 140, 110, 255), outline=ink)
    d.polygon([(x - 10, base - h - 18), (x + 10, base - h - 18), (x, base - h - 28)], fill=(54, 54, 56, 255))


def small_statue(d, x, base, rng):
    m, sh, ink = (150, 146, 136, 255), (128, 124, 116, 255), (70, 68, 64, 255)
    d.rectangle([x - 11, base - 36, x + 11, base], fill=m, outline=ink, width=1)
    d.rectangle([x - 14, base - 40, x + 14, base - 36], fill=m, outline=ink, width=1)
    pose = rng.random()
    d.polygon([(x - 7, base - 40), (x + 7, base - 40), (x + 5, base - 84), (x - 5, base - 84)], fill=m, outline=ink)
    d.polygon([(x + 1, base - 40), (x + 7, base - 40), (x + 5, base - 84), (x + 1, base - 84)], fill=sh)
    d.ellipse([x - 5, base - 96, x + 5, base - 84], fill=m, outline=ink)
    if pose < 0.5:
        d.line([x - 5, base - 80, x - 13, base - 96], fill=m, width=3)  # braccio alzato
    else:
        d.line([x + 5, base - 80, x + 12, base - 62], fill=m, width=3)


def lawn(d, W, H):
    base = int(to_px(0, 560)[1])
    rng = random.Random(11)
    d.rectangle([0, base - 50, W, base + 70], fill=(56, 70, 52, 255))  # il prato dell'Isola Memmia, spento
    # oltre il prato: la riva lontana del canale esterno e la sua acqua (#264), non il vuoto
    d.rectangle([0, base + 70, W, base + 150], fill=(118, 112, 100, 255))
    for bx in range(0, W, 60):
        d.line([bx, base + 70, bx, base + 150], fill=(98, 93, 84, 255), width=2)
    d.line([0, base + 110, W, base + 110], fill=(98, 93, 84, 255), width=2)
    d.rectangle([0, base + 70, W, base + 76], fill=(170, 164, 150, 255))
    d.rectangle([0, base + 150, W, H], fill=(70, 98, 104, 255))
    for wy in range(base + 170, H, 40):  # riflessi
        for wx in range((wy * 7) % 90, W, 180):
            d.line([wx, wy, wx + 50, wy], fill=(96, 126, 130, 255), width=2)
    for x in range(0, W, 7):  # erba a ciuffi sul bordo
        d.line([x, base - 50, x + 2, base - 56 - (x * 7 % 5)], fill=(64, 80, 58, 255), width=1)
    for i, tx in enumerate(range(30, W, 230)):  # platani
        plane_tree(d, tx + rng.randint(-50, 50), base - 50, rng.randint(46, 70), rng)
    # vialetto, panchine e lampioni
    d.rectangle([0, base - 50, W, base - 44], fill=(120, 114, 102, 255))
    for bx in range(160, W, 380):
        d.rectangle([bx, base - 62, bx + 40, base - 56], fill=(92, 72, 56, 255))
        d.rectangle([bx + 2, base - 56, bx + 6, base - 50], fill=(54, 54, 56, 255))
        d.rectangle([bx + 34, base - 56, bx + 38, base - 50], fill=(54, 54, 56, 255))
    for lx in range(90, W, 300):
        lamp(d, lx, base - 50, 92)
    # la canaletta lontana con la seconda fila di statue sui piedistalli e la balaustra
    d.rectangle([0, base - 40, W, base - 30], fill=(140, 136, 126, 255))
    for sx in range(60, W, 120):
        small_statue(d, sx, base - 36, rng)
    # dettaglio nascosto: un papiro di laurea appeso a un lampione
    px = 90 + 300 * 3
    d.rectangle([px + 3, base - 120, px + 9, base - 104], fill=(212, 204, 180, 255), outline=(60, 56, 50, 255))
    d.line([px + 2, base - 112, px + 10, base - 112], fill=(150, 40, 40, 255), width=2)


def palazzo(name):
    """Il palazzo signorile al centro, dietro il ponte: facciata di intonaco caldo, portico, piano nobile con la
    trifora gotica e il balcone largo, ultimo piano con il balconcino. I balconi veri sono piattaforme (y 300 e 180):
    qui c'è solo la facciata, con le mensole sotto i balconi. Disegnato a 2x: x da 740 a 1180, y da 40 a 480."""
    k = 2
    x0, y0, x1, y1 = 740, 40, 1180, 480
    W, H = (x1 - x0) * k, (y1 - y0) * k
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    P = lambda x, y: ((x - x0) * k, (y - y0) * k)
    plaster, plaster_s = (150, 118, 92, 255), (130, 100, 78, 255)
    stone, stone_s = (196, 190, 176, 255), (168, 160, 146, 255)
    dark = (54, 46, 42, 255)
    ink = (34, 28, 26, 255)
    lw = 2 * k
    # corpo e ombra a destra
    d.rectangle([*P(760, 110), *P(1160, 480)], fill=plaster)
    d.rectangle([*P(1060, 110), *P(1160, 480)], fill=plaster_s)
    # bugnato del portico e archi
    d.rectangle([*P(760, 380), *P(1160, 480)], fill=stone)
    for row in range(5):
        y = 380 + row * 20
        d.line([*P(760, y), *P(1160, y)], fill=stone_s, width=k)
    for i in range(5):
        ax = 778 + i * 78
        d.rectangle([*P(ax, 410), *P(ax + 52, 480)], fill=dark)
        d.pieslice([*P(ax, 384), *P(ax + 52, 436)], 180, 360, fill=dark)
        d.arc([*P(ax - 4, 380), *P(ax + 56, 440)], 180, 360, fill=ink, width=lw)
    # mezzanino con le finestrelle quadrate
    for i in range(6):
        wx = 786 + i * 64
        d.rectangle([*P(wx, 340), *P(wx + 28, 364)], fill=dark, outline=ink, width=k)
    d.rectangle([*P(756, 370), *P(1164, 380)], fill=stone, outline=ink, width=k)  # marcapiano
    # mensole sotto il balcone del piano nobile (la piattaforma è a y 300, da x 800 a 1120)
    for i in range(7):
        mx = 812 + i * 48
        d.polygon([P(mx, 300), P(mx + 16, 300), P(mx + 12, 322), P(mx + 4, 322)], fill=stone, outline=ink)
    # piano nobile: trifora gotica al centro, bifore ai lati, con le cornici di pietra
    def gothic(wx, wy, ww, wh, lights):
        d.rectangle([*P(wx - 6, wy - 10), *P(wx + ww + 6, wy + wh)], fill=stone, outline=ink, width=k)
        lw_ = ww / lights
        for j in range(lights):
            lx = wx + j * lw_
            d.rectangle([*P(lx + 3, wy + 16), *P(lx + lw_ - 3, wy + wh - 4)], fill=dark)
            d.polygon([P(lx + 3, wy + 16), P(lx + lw_ / 2, wy), P(lx + lw_ - 3, wy + 16)], fill=dark)
        d.ellipse([*P(wx + ww / 2 - 8, wy - 6), *P(wx + ww / 2 + 8, wy + 10)], fill=stone_s, outline=ink, width=k)  # quadrilobo
    gothic(905, 212, 110, 84, 3)
    gothic(800, 222, 60, 74, 2)
    gothic(1060, 222, 60, 74, 2)
    d.rectangle([*P(756, 196), *P(1164, 204)], fill=stone, outline=ink, width=k)
    # mensole del balconcino in alto (piattaforma a y 180, da x 900 a 1020)
    for i in range(4):
        mx = 908 + i * 30
        d.polygon([P(mx, 180), P(mx + 12, 180), P(mx + 9, 196), P(mx + 3, 196)], fill=stone, outline=ink)
    # ultimo piano: finestre rettangolari con le persiane verdi spente
    for wx in (790, 850, 940, 990, 1070, 1120):
        d.rectangle([*P(wx - 8, 128), *P(wx - 2, 170)], fill=(84, 98, 80, 255))
        d.rectangle([*P(wx + 16, 128), *P(wx + 22, 170)], fill=(84, 98, 80, 255))
        d.rectangle([*P(wx - 2, 128), *P(wx + 16, 170)], fill=dark, outline=ink, width=k)
    # cornicione, tetto di coppi, altana di legno e camini a imbuto
    d.rectangle([*P(750, 100), *P(1170, 112)], fill=stone, outline=ink, width=lw)
    for i in range(26):
        d.rectangle([*P(756 + i * 16, 112), *P(762 + i * 16, 118)], fill=stone_s)  # dentelli
    d.polygon([P(752, 100), P(1168, 100), P(1130, 66), P(790, 66)], fill=(110, 76, 62, 255), outline=ink)
    for i in range(20):
        d.line([*P(796 + i * 18, 70), *P(770 + i * 20, 100)], fill=(94, 64, 52, 255), width=k)
    for cxm in (812, 1110):
        d.rectangle([*P(cxm - 6, 40), *P(cxm + 6, 70)], fill=(126, 92, 76, 255), outline=ink, width=k)
        d.polygon([P(cxm - 16, 40), P(cxm + 16, 40), P(cxm + 8, 54), P(cxm - 8, 54)], fill=(126, 92, 76, 255), outline=ink)
    # contorno del palazzo
    d.rectangle([*P(760, 110), *P(1160, 480)], outline=ink, width=lw)
    save(img, name)


def balcony_rail():
    """Balaustrata dei balconi del palazzo: colonnine a vaso tra corrimano e zoccolo di pietra."""
    w, h = 24, 30
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    stone, shade = (196, 190, 176, 255), (160, 152, 138, 255)
    d.rectangle([0, 0, w, 4], fill=stone)
    d.rectangle([0, h - 5, w, h - 1], fill=stone)
    d.line([0, 0, w, 0], fill=INK)
    d.line([0, 4, w, 4], fill=INK)
    d.line([0, h - 5, w, h - 5], fill=INK)
    d.line([0, h - 1, w, h - 1], fill=INK)
    for cx in (6, 18):  # colonnine a vaso
        d.ellipse([cx - 4, 9, cx + 4, 21], fill=stone, outline=INK)
        d.rectangle([cx - 2, 5, cx + 2, 9], fill=stone, outline=INK)
        d.rectangle([cx - 2, 21, cx + 2, h - 5], fill=stone, outline=INK)
        d.rectangle([cx + 1, 10, cx + 3, 20], fill=shade)
    save(img, "balaustra-balcone.png")


def balcony_floor():
    w, h = 48, 14
    img = Image.new("RGBA", (w, h), (196, 190, 176, 255))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w, 3], fill=EDGE)
    d.rectangle([0, 9, w, h], fill=(160, 152, 138, 255))
    d.line([0, h - 1, w, h - 1], fill=INK)
    save(img, "balcone.png")


if __name__ == "__main__":
    paving()
    quay_wall()
    edge("bordo.png", 96, 8)
    deck()
    stairs()
    balustrade()
    slab()
    statue("statua-ponte.png", 112, 180, "giovane")  # regge la lastra a y 410 dalla piazza a y 520 (+2 di appoggio)
    statue("statua-alta.png", 192, 140, "filosofo")  # regge la lastra a y 330
    statue("statua-piazza.png", 142, 180, "dama")  # regge la lastra a y 380
    arch()
    palazzo("palazzo.png")
    balcony_rail()
    balcony_floor()
    layer("sfondo-0.png", sky)
    layer("sfondo-1.png", buildings)
    layer("sfondo-2.png", lawn)
