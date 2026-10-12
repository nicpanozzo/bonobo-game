"""Cancaro Man, il ciclista arrabbiato di Padova (#270), disegnato col codice dal disegno di Riccardo.

Un signore anziano pelato con la frangia bianca, la faccia rossa che urla "CANCAROOOO!", maglietta rosa, pettorina
catarifrangente, pantaloncini cargo, calzini bianchi e scarpe marroni, su una mountain bike arrugginita con il
campanello. Con una mano fa roteare la catena. Stile del gioco: contorno a inchiostro, ombre piatte a 2 toni.

Scrive un foglio di FRAMES fotogrammi della pedalata, uno accanto all'altro, rivolti a destra (il gioco lo specchia
quando va a sinistra). Ogni fotogramma è FW × FH unità di mondo, salvato a 2 pixel per unità (scale 0.5 nel gioco);
le ruote toccano terra a GROUND. Un disegno vero può sostituirlo, con le stesse misure.

Uso: python3 tools/arene/ciclista.py  (scrive public/assets/stages/padova/ciclista.png)
"""

import math
import os
import sys

from PIL import Image, ImageDraw

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "public", "assets", "stages", "padova")
FRAMES = 8
FW, FH = 150, 160  # unità di mondo
TOP = 24  # spazio sopra la testa per la catena che gira: tutto il disegno scende di tanto
GROUND = 132 + TOP  # dove le gomme toccano terra, nel fotogramma
S = 8  # pixel per unità mentre si disegna; poi si riduce a 2 pixel per unità
OUT_K = 2

INK = (30, 26, 23, 255)
SKIN, SKIN_S = (214, 150, 118, 255), (178, 116, 90, 255)
FACE, FACE_S, FACE_L = (214, 92, 74, 255), (176, 66, 54, 255), (238, 138, 118, 255)
SHIRT, SHIRT_S = (232, 150, 172, 255), (198, 116, 142, 255)
VEST, VEST_S = (196, 216, 66, 255), (160, 180, 46, 255)  # giallo-lime un po' spento: il giallo saturo è di P4
STRIPE = (206, 208, 210, 255)
SHORTS, SHORTS_S = (70, 72, 66, 255), (52, 54, 50, 255)
SOCK = (240, 238, 232, 255)
SHOE, SHOE_S = (132, 90, 56, 255), (104, 70, 44, 255)
HAIR = (236, 236, 230, 255)
FRAME, FRAME_S = (124, 116, 106, 255), (98, 92, 84, 255)
RUST = (156, 92, 50, 255)
TIRE, RIM, SPOKE = (40, 38, 36, 255), (150, 148, 142, 255), (120, 118, 112, 255)
MOUTH, TONGUE, TEETH = (92, 22, 22, 255), (204, 96, 96, 255), (246, 244, 236, 255)
WHITE = (250, 250, 248, 255)
CHAIN, CHAIN_S = (150, 152, 156, 255), (104, 106, 110, 255)

INK_W = 1.3  # spessore dell'inchiostro, in unità di mondo


class Pen:
    def __init__(self, img):
        self.img = img
        self.d = ImageDraw.Draw(img)

    @staticmethod
    def p(x, y):
        return (x * S, (y + TOP) * S)

    def poly(self, pts, fill, ink=True):
        q = [self.p(*pt) for pt in pts]
        self.d.polygon(q, fill=fill)
        if ink:
            self.d.line(q + [q[0]], fill=INK, width=int(INK_W * S), joint="curve")

    def circle(self, c, r, fill, ink=True):
        x, y = c
        box = [self.p(x - r, y - r), self.p(x + r, y + r)]
        if ink:
            o = INK_W / 2
            self.d.ellipse([self.p(x - r - o, y - r - o), self.p(x + r + o, y + r + o)], fill=INK)
        self.d.ellipse(box, fill=fill)

    def ellipse(self, c, rx, ry, fill, ink=True):
        x, y = c
        if ink:
            o = INK_W / 2
            self.d.ellipse([self.p(x - rx - o, y - ry - o), self.p(x + rx + o, y + ry + o)], fill=INK)
        self.d.ellipse([self.p(x - rx, y - ry), self.p(x + rx, y + ry)], fill=fill)

    def line(self, a, b, w, fill):
        self.d.line([self.p(*a), self.p(*b)], fill=fill, width=max(1, int(w * S)))

    def limb(self, a, b, w, fill, ink=True):
        """Un tubo con le estremità tonde: braccia, gambe, tubi della bici."""
        if ink:
            self.d.line([self.p(*a), self.p(*b)], fill=INK, width=int((w + INK_W) * S))
            for c in (a, b):
                self.circle(c, (w + INK_W) / 2, INK, ink=False)
        self.d.line([self.p(*a), self.p(*b)], fill=fill, width=int(w * S))
        for c in (a, b):
            self.circle(c, w / 2, fill, ink=False)

    def arc(self, c, r, a0, a1, w, fill):
        x, y = c
        self.d.arc([self.p(x - r, y - r), self.p(x + r, y + r)], a0, a1, fill=fill, width=max(1, int(w * S)))


def knee(hip, foot, l1, l2, forward=1):
    """Ginocchio tra anca e piede (due segmenti lunghi l1 e l2), piegato in avanti."""
    dx, dy = foot[0] - hip[0], foot[1] - hip[1]
    dist = min(math.hypot(dx, dy), l1 + l2 - 0.01)
    a = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
    h = math.sqrt(max(0.0, l1 * l1 - a * a))
    ux, uy = dx / dist, dy / dist
    mx, my = hip[0] + ux * a, hip[1] + uy * a
    # le due soluzioni: si sceglie quella con il ginocchio più avanti (x più grande)
    k1 = (mx - uy * h, my + ux * h)
    k2 = (mx + uy * h, my - ux * h)
    return k1 if (k1[0] - k2[0]) * forward > 0 else k2


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


# --- la bici: misure fisse, in unità di mondo ---
RH, FHUB, WR = (32, 108), (118, 108), 23  # mozzi e raggio delle ruote
BB = (66, 112)  # movimento centrale
ST = (57, 74)  # cima del tubo del sedile
HT, HB = (101, 70), (105, 86)  # tubo dello sterzo
CRANK = 10
HIP = (55, 66)
L_THIGH, L_SHIN = 29, 30


def wheel(pen, hub, spin):
    pen.circle(hub, WR, TIRE)
    pen.circle(hub, WR - 3.2, RIM, ink=False)
    pen.circle(hub, WR - 4.6, (0, 0, 0, 0), ink=False)
    # tacchetti della gomma da mountain bike
    for i in range(28):
        a = i / 28 * math.tau + spin * 0.3
        p0 = (hub[0] + math.cos(a) * WR, hub[1] + math.sin(a) * WR)
        p1 = (hub[0] + math.cos(a) * (WR + 1.3), hub[1] + math.sin(a) * (WR + 1.3))
        pen.line(p0, p1, 1.4, TIRE)
    for i in range(12):  # raggi, uno storto
        a = i / 12 * math.tau + spin
        end = (hub[0] + math.cos(a) * (WR - 4), hub[1] + math.sin(a) * (WR - 4))
        if i == 5:
            end = (end[0] + 1.5, end[1] - 1.0)
        pen.line(hub, end, 0.5, SPOKE)
    pen.circle(hub, 2.4, FRAME_S)


def bike(pen, f):
    spin = f / FRAMES * math.tau * 2.75  # le ruote girano più dei pedali
    wheel(pen, RH, spin)
    wheel(pen, FHUB, spin)
    # parafango posteriore storto
    pen.arc(RH, WR + 3, 196, 292, 2.2, INK)
    pen.arc(RH, WR + 3, 198, 290, 1.2, (168, 160, 150, 255))
    # disco del freno anteriore e pinza
    pen.circle(FHUB, 7.5, (186, 186, 182, 255))
    for i in range(6):
        a = i / 6 * math.tau + spin
        pen.circle((FHUB[0] + math.cos(a) * 5, FHUB[1] + math.sin(a) * 5), 0.9, (120, 120, 116, 255), ink=False)
    pen.poly([(FHUB[0] - 9, FHUB[1] - 6), (FHUB[0] - 4, FHUB[1] - 9), (FHUB[0] - 2, FHUB[1] - 6), (FHUB[0] - 7, FHUB[1] - 3)], (60, 58, 56, 255))
    # forcella ammortizzata
    pen.limb(HB, (109, 96), 4.2, FRAME_S)
    pen.limb((109, 96), FHUB, 2.6, (150, 146, 140, 255))
    # telaio arrugginito
    pen.limb(BB, RH, 3.0, FRAME_S)  # fodero basso
    pen.limb(ST, RH, 2.4, FRAME_S)  # fodero alto
    pen.limb(BB, HB, 4.6, FRAME)  # tubo obliquo
    pen.limb(ST, HT, 3.8, FRAME)  # tubo orizzontale
    pen.limb(BB, ST, 4.0, FRAME)  # tubo del sedile
    pen.limb(HT, HB, 4.6, FRAME)
    for c in [(80, 100), (90, 92), (72, 74), (88, 72), (62, 94), (46, 96)]:  # ruggine
        pen.circle(c, 1.4, RUST, ink=False)
    pen.circle((84, 96), 0.9, RUST, ink=False)
    # catena e corone
    pen.line((BB[0], BB[1] - 8.5), (RH[0], RH[1] - 4.5), 1.0, (90, 70, 56, 255))
    pen.line((BB[0], BB[1] + 8.5), (RH[0], RH[1] + 4.5), 1.0, (90, 70, 56, 255))
    pen.circle(RH, 4.5, (110, 104, 96, 255))
    pen.circle(BB, 8.5, (126, 122, 116, 255))
    for i in range(16):
        a = i / 16 * math.tau
        pen.circle((BB[0] + math.cos(a) * 8.5, BB[1] + math.sin(a) * 8.5), 0.8, (96, 92, 88, 255), ink=False)
    pen.circle(BB, 3, FRAME_S)
    # attacco, manubrio rialzato, campanello
    pen.limb(HT, (100, 62), 3.0, FRAME_S)
    pen.limb((93, 62), (106, 59), 2.2, (70, 68, 64, 255))
    pen.circle((102, 58.5), 1.8, (196, 190, 160, 255))  # il campanello
    # sella sfondata
    pen.limb(ST, (55, 70), 2.0, (150, 146, 140, 255))
    pen.poly([(44, 69), (64, 67.5), (67, 70.5), (60, 72.5), (47, 72.5)], (60, 54, 50, 255))
    pen.line((48, 69.5), (60, 68.8), 0.6, (110, 100, 92, 255))  # la cucitura scucita


def pedal_points(f):
    a = f / FRAMES * math.tau  # in senso orario, come quando si va a destra
    near = (BB[0] + math.cos(a) * CRANK, BB[1] + math.sin(a) * CRANK)
    far = (BB[0] - math.cos(a) * CRANK, BB[1] - math.sin(a) * CRANK)
    return near, far


def leg(pen, pedal, near):
    ankle = (pedal[0] - 2.5, pedal[1] - 4.5)
    k = knee(HIP, ankle, L_THIGH, L_SHIN)
    skin, shorts, sock, shoe = (SKIN, SHORTS, SOCK, SHOE) if near else (SKIN_S, SHORTS_S, (200, 198, 192, 255), SHOE_S)
    pen.limb(k, ankle, 5.4, skin)  # stinco, con il polpaccio
    calf = lerp(k, ankle, 0.35)
    pen.ellipse((calf[0] - 1.6, calf[1]), 3.4, 4.6, skin, ink=False)
    pen.limb(lerp(k, ankle, 0.72), ankle, 5.6, sock)  # calzino bianco tirato su
    pen.limb(HIP, lerp(HIP, k, 0.62), 9.0, shorts)  # coscia nei pantaloncini cargo
    pen.limb(lerp(HIP, k, 0.55), k, 6.4, skin)  # il ginocchio scoperto
    pen.limb(lerp(HIP, k, 0.3), lerp(HIP, k, 0.66), 8.6, shorts, ink=False)
    hem = lerp(HIP, k, 0.68)  # l'orlo dei pantaloncini
    nx, ny = -(k[1] - HIP[1]), k[0] - HIP[0]
    nl = math.hypot(nx, ny)
    pen.line((hem[0] - nx / nl * 4.6, hem[1] - ny / nl * 4.6), (hem[0] + nx / nl * 4.6, hem[1] + ny / nl * 4.6), 1.6, INK)
    if near:
        mid = lerp(HIP, k, 0.4)  # la tasca laterale
        pen.poly([(mid[0] - 3, mid[1] - 2.5), (mid[0] + 3, mid[1] - 3), (mid[0] + 3.5, mid[1] + 2.5), (mid[0] - 2.5, mid[1] + 3)], (96, 84, 62, 255))
    # scarpa: tallone dietro la caviglia, punta oltre il pedale
    pen.poly([(ankle[0] - 3.5, ankle[1] - 1), (ankle[0] + 2, ankle[1] - 2.5), (pedal[0] + 7.5, pedal[1] - 1), (pedal[0] + 8, pedal[1] + 1.8), (ankle[0] - 3.5, pedal[1] + 2)], shoe)
    pen.line((ankle[0] - 3, pedal[1] + 1.4), (pedal[0] + 7.6, pedal[1] + 1.4), 0.8, (60, 44, 32, 255))  # suola


def crank(pen, pedal):
    pen.limb(BB, pedal, 2.2, (70, 68, 64, 255))
    pen.poly([(pedal[0] - 3, pedal[1] - 0.8), (pedal[0] + 3, pedal[1] - 0.8), (pedal[0] + 3, pedal[1] + 1.2), (pedal[0] - 3, pedal[1] + 1.2)], (60, 58, 56, 255))


def torso(pen):
    # maglietta rosa: schiena dritta, spalle tonde, pancetta davanti
    shirt = [(47, 66), (50, 54), (58, 41), (66, 34), (76, 30), (83, 33), (87, 41), (89.5, 52), (88, 61), (82, 67), (68, 70), (54, 71)]
    pen.poly(shirt, SHIRT)
    pen.poly([(83, 33), (87, 41), (89.5, 52), (88, 61), (82, 67), (78, 67), (84, 50)], SHIRT_S, ink=False)
    # pettorina: si disegna su un livello a parte, con le strisce ritagliate dentro
    vest = [(51, 64), (55, 50), (62, 40), (68, 36.5), (72, 43), (80, 43.5), (82.5, 37), (86, 42), (88.5, 52), (87, 60), (81.5, 66), (68, 68.5), (54, 69)]
    layer = Image.new("RGBA", pen.img.size, (0, 0, 0, 0))
    lp = Pen(layer)
    lp.poly(vest, VEST, ink=False)
    lp.poly([(82.5, 37), (86, 42), (88.5, 52), (87, 60), (81.5, 66), (77, 67), (83, 50)], VEST_S, ink=False)
    for y0 in (52, 60):  # strisce catarifrangenti grigie
        lp.poly([(40, y0), (95, y0 - 2), (95, y0 + 1), (40, y0 + 3)], STRIPE, ink=False)
        lp.line((40, y0 + 0.4), (95, y0 - 1.6), 0.4, (236, 238, 240, 255))
    mask = Image.new("L", pen.img.size, 0)
    ImageDraw.Draw(mask).polygon([Pen.p(*pt) for pt in vest], fill=255)
    pen.img.paste(layer, (0, 0), mask)
    q = [Pen.p(*pt) for pt in vest]
    pen.d.line(q + [q[0]], fill=INK, width=int(INK_W * S), joint="curve")
    pen.circle((78, 47), 1.0, (60, 62, 58, 255))  # bottone a pressione della pettorina
    pen.poly([(79, 55), (85, 54.5), (85.5, 59.5), (79.5, 60)], VEST_S)  # tasca


def head(pen, f):
    hc = (91, 20)
    rx, ry = 13, 14
    # collo grosso e rosso, spinto in avanti
    pen.limb((80, 33), (88, 28), 8, FACE_S)
    # testa pelata, un po' a uovo, con l'ombra sulla nuca
    pen.ellipse(hc, rx, ry, FACE)
    pen.d.chord([Pen.p(hc[0] - rx, hc[1] - ry), Pen.p(hc[0] + rx, hc[1] + ry)], 115, 205, fill=FACE_S)
    pen.d.arc([Pen.p(hc[0] - 9, hc[1] - 12), Pen.p(hc[0] + 4, hc[1] - 2)], 200, 285, fill=FACE_L, width=int(1.5 * S))  # lucido della pelata
    # frangia bianca: solo sulla nuca e sopra l'orecchio, come nel disegno
    pen.poly([(79, 19), (81.5, 17.5), (84.5, 21), (83, 27), (84.5, 31), (80.5, 31.5), (78.2, 25)], HAIR)
    for y in (21, 24.5, 28):
        pen.line((79.5, y), (82.5, y + 1.2), 0.5, (196, 196, 190, 255))
    # orecchio
    pen.ellipse((86, 23.5), 2.6, 3.9, FACE)
    pen.d.arc([Pen.p(84.4, 21), Pen.p(87.6, 26)], 120, 300, fill=FACE_S, width=int(0.6 * S))
    # rughe della fronte e la vena della rabbia (il segno a croce dei fumetti)
    for i, y in enumerate((7.5, 10.5)):
        pen.d.arc([Pen.p(90 + i, y), Pen.p(100 + i, y + 4)], 200, 330, fill=FACE_S, width=int(0.8 * S))
    vx, vy = 85, 6.5
    for ang in (45, 135, 225, 315):
        r = math.radians(ang)
        pen.line((vx + math.cos(r) * 1.1, vy + math.sin(r) * 1.1), (vx + math.cos(r) * 3.8, vy + math.sin(r) * 3.8), 1.3, (150, 28, 28, 255))
    # sopracciglio bianco cespuglioso, che scende verso il naso
    pen.poly([(89.5, 11.5), (94, 9.8), (101.5, 13.8), (101, 16.2), (94.5, 13.8), (90, 14.2)], HAIR)
    # occhio spalancato e iniettato, pupilla piccola che guarda avanti
    pen.ellipse((97.5, 17.3), 3.2, 2.5, WHITE)
    pen.line((95, 17.8), (96.2, 17.1), 0.3, (220, 120, 110, 255))
    pen.circle((99.4, 17.4), 1.0, INK, ink=False)
    pen.d.arc([Pen.p(94, 18.5), Pen.p(101, 22.5)], 20, 160, fill=FACE_S, width=int(0.6 * S))  # borsa sotto l'occhio
    # naso grosso
    pen.ellipse((104, 21.2), 3.3, 3.0, (224, 104, 86, 255))
    pen.circle((103.2, 22.6), 0.8, (120, 40, 34, 255), ink=False)
    pen.circle((104.8, 20.0), 0.8, FACE_L, ink=False)
    # bocca spalancata che urla CANCAROOOO!, denti di sopra e di sotto
    o = 0.8 * math.sin(f / FRAMES * math.tau * 2)  # trema mentre urla
    mouth = [(92.5, 25.5), (103.5, 25.2), (105, 29), (103, 35.5 + o), (96, 36.5 + o), (92, 31)]
    pen.poly(mouth, MOUTH)
    pen.poly([(93.2, 25.9), (103.2, 25.6), (103.7, 27.4), (93.6, 27.8)], TEETH, ink=False)
    pen.poly([(95.5, 35.6 + o), (102.6, 34.8 + o), (102.4, 33.7 + o), (96, 34.5 + o)], TEETH, ink=False)
    pen.ellipse((98.5, 33 + o), 3.2, 1.4, TONGUE, ink=False)
    q = [Pen.p(*pt) for pt in mouth]
    pen.d.line(q + [q[0]], fill=INK, width=int(INK_W * S), joint="curve")
    pen.d.arc([Pen.p(87, 22), Pen.p(95, 33)], 300, 40, fill=FACE_S, width=int(0.8 * S))  # piega della guancia
    pen.d.arc([Pen.p(93, 35.5), Pen.p(102, 40.5)], 20, 160, fill=FACE_S, width=int(0.8 * S))  # mento


def arm(pen, shoulder, elbow, hand, near):
    skin = SKIN if near else SKIN_S
    pen.limb(shoulder, elbow, 5.6, skin)
    pen.limb(elbow, hand, 5.0, skin)
    pen.limb(shoulder, lerp(shoulder, elbow, 0.5), 7.6, SHIRT if near else SHIRT_S)  # manica corta
    pen.circle(hand, 3.2, skin)


def chain_swing(pen, hand, f):
    """La catena della bici che gira sopra la testa, con la scia del movimento dietro."""
    a = -f / FRAMES * math.tau - 2.2
    length = 26
    for k, w, alpha in ((0.95, 2.6, 120), (0.7, 1.6, 90)):  # scia
        pen.arc(hand, length * k, math.degrees(a) + 15, math.degrees(a) + 100, w, (236, 238, 242, alpha))
    for i in range(11):  # maglie, che si curvano per la forza centrifuga
        t = (i + 0.6) / 11
        bend = 0.3 * t * t
        c = (hand[0] + math.cos(a + bend) * length * t, hand[1] + math.sin(a + bend) * length * t)
        if i % 2 == 0:
            pen.ellipse(c, 2.0, 1.4, CHAIN)
        else:
            pen.ellipse(c, 1.4, 2.0, CHAIN_S)
    pen.circle(hand, 3.2, SKIN)  # le dita chiuse sulla catena


def motion(pen, f):
    # linee di velocità e polvere dietro la ruota posteriore
    for i, y in enumerate((44, 62, 84, 100)):
        x0 = 2 + ((f * 3 + i * 5) % 9)
        pen.line((x0, y), (x0 + 16 - i * 2, y), 0.8, (210, 210, 206, 170))
    for i in range(3):
        k = ((f + i * 3) % FRAMES) / FRAMES
        c = (10 - k * 8 + i * 4, GROUND - TOP - 2 - k * 6)
        pen.circle(c, 2.2 + k * 3, (200, 190, 170, int(170 * (1 - k))), ink=False)


def sweat(pen, f):
    for i in range(3):
        k = ((f + i * 2.7) % FRAMES) / FRAMES
        c = (78 - k * 10 - i * 2, 10 + i * 5 + k * 4)
        pen.d.polygon([Pen.p(c[0] + 1.8, c[1]), Pen.p(c[0] - 0.4, c[1] - 1.4), Pen.p(c[0] - 0.4, c[1] + 1.4)], fill=(200, 230, 246, 255))
        pen.circle(c, 1.2, (200, 230, 246, 255), ink=False)


def frame_image(f):
    img = Image.new("RGBA", (FW * S, FH * S), (0, 0, 0, 0))
    pen = Pen(img)
    near_pedal, far_pedal = pedal_points(f)
    motion(pen, f)
    leg(pen, far_pedal, near=False)
    crank(pen, far_pedal)
    arm(pen, (72, 36), (62, 21), (67, 5), near=False)  # il braccio alzato con la catena
    bike(pen, f)
    crank(pen, near_pedal)
    torso(pen)
    leg(pen, near_pedal, near=True)
    chain_swing(pen, (67, 5), f)  # dietro la testa: quando gira davanti alla faccia la testa la copre
    head(pen, f)
    arm(pen, (80, 38), (91, 50), (96, 61.5), near=True)  # la mano sul manubrio
    sweat(pen, f)
    return img.resize((FW * OUT_K, FH * OUT_K), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    sheet = Image.new("RGBA", (FW * OUT_K * FRAMES, FH * OUT_K), (0, 0, 0, 0))
    for f in range(FRAMES):
        sheet.paste(frame_image(f), (f * FW * OUT_K, 0))
    path = os.path.join(OUT, "ciclista.png")
    sheet.save(path, optimize=True)
    print("scritto", path, sheet.size)


if __name__ == "__main__":
    main()
