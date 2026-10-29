# Uso: python3 tools/rig/genera_oggetti_opus.py   (servono cairosvg e Pillow)
# Gli oggetti di Maestro Opus (characters.ts, scheda in docs/mosse/opus.md), disegnati col codice a 2x (scale 0.5),
# a 2 toni con l'inchiostro come i suoi pezzi (genera_pezzi_opus.py):
#   proiettili/nota.png              Staccato, la speciale neutra: due crome d'oro legate, 4 fotogrammi da 72x72
#   supreme/pianoforte-cade.png      Gran Finale: il pianoforte a coda appeso alla liana (nodo al 38% dall'alto)
#   supreme/pianoforte-a-terra.png   lo stesso, schiantato a terra fino al puff
#   supreme/pianoforte-corre.png     dopo il puff scappa un pianoforte verticale piccolo: 4 fotogrammi da 110x140
# Le misure sono quelle delle altre supreme "drop" (tools/rig/genera_supreme_drop.py).
import io, math, os

import cairosvg
from PIL import Image

OUT = "public/assets/characters/opus"
INK = "#1f1714"
WI = 7  # inchiostro a 2x, come genera_supreme_drop.py
LAC = ("#2c2e3a", "#16171e", "#5a5f78")  # la lacca nera del pianoforte: base, ombra, riflesso
KEYS = ("#f7f3e8", "#d6cfbe")
GOLD = ("#f4c64f", "#c48f22", "#fff1b8")
WOOD = ("#9a6a3c", "#6e4626")


class Tela:
    """Forme SVG a 2 toni: prima l'inchiostro di tutte (una sagoma sola), poi i colori sopra."""

    def __init__(self, w, h):
        self.w, self.h, self.ink, self.fill, self.top, self.uid = w, h, [], [], [], 0

    def forma(self, d, col, light=(3, -4), ink=WI, xf=""):
        base, shade = col[0], col[1]
        self.uid += 1
        if ink:
            self.ink.append(f'<path d="{d}" fill="{INK}" stroke="{INK}" stroke-width="{ink}" stroke-linejoin="round" transform="{xf}"/>')
        c = f"k{self.uid}"
        self.fill.append(f'<g transform="{xf}"><clipPath id="{c}"><path d="{d}"/></clipPath><path d="{d}" fill="{shade}"/>'
                         f'<path d="{d}" fill="{base}" clip-path="url(#{c})" transform="translate({light[0]},{light[1]})"/></g>')

    def linea(self, d, color, w, xf=""):
        self.top.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round" transform="{xf}"/>')

    def sopra(self, svg):
        self.top.append(svg)

    def png(self):
        doc = f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}">{"".join(self.ink + self.fill + self.top)}</svg>'
        return Image.open(io.BytesIO(cairosvg.svg2png(bytestring=doc.encode()))).convert("RGBA")


def rect(x, y, w, h, r=0):
    return f"M{x + r},{y} H{x + w - r} Q{x + w},{y} {x + w},{y + r} V{y + h - r} Q{x + w},{y + h} {x + w - r},{y + h} H{x + r} Q{x},{y + h} {x},{y + h - r} V{y + r} Q{x},{y} {x + r},{y} Z"


def ell(cx, cy, rx, ry):
    return f"M{cx - rx},{cy} A{rx},{ry} 0 1 0 {cx + rx},{cy} A{rx},{ry} 0 1 0 {cx - rx},{cy} Z"


def polyd(pts):
    return "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts) + " Z"


def stella(cx, cy, r, color="#fff1b8"):
    pts = []
    for i in range(8):
        a = -math.pi / 2 + i * math.pi / 4
        rr = r if i % 2 == 0 else r * 0.35
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    return f'<path d="{polyd(pts)}" fill="{color}" stroke="{INK}" stroke-width="1.3"/>'


# ---------------------------------------------------------------- Staccato: due crome legate
def nota():
    fw, n = 72, 4
    sheet = Image.new("RGBA", (fw * n, fw), (0, 0, 0, 0))
    for i in range(n):
        t = Tela(fw, fw)
        a = 8 * math.sin(i / n * math.tau)  # ondeggia mentre vola
        k = 1 + 0.06 * math.cos(i / n * math.tau)
        xf = f"translate(36,38) rotate({a:.1f}) scale({k:.3f},{2 - k:.3f}) translate(-36,-38)"
        t.forma(ell(22, 50, 9, 6.5) + " " + ell(46, 44, 9, 6.5), GOLD, light=(1.5, -2), ink=6, xf=xf)
        t.forma(polyd([(28, 50), (32, 50), (32, 18), (28, 19)]) + " " + polyd([(52, 44), (56, 44), (56, 12), (52, 13)]), GOLD, light=(1, 0), ink=6, xf=xf)
        t.forma(polyd([(28, 16), (56, 9), (56, 19), (28, 26)]), GOLD, light=(0, -2), ink=6, xf=xf)  # la trave
        t.linea("M17,47 Q20,44 24,45 M41,41 Q44,38 48,39", GOLD[2], 2.2, xf=xf)
        t.sopra(stella(12 + 4 * (i % 2), 14 + 3 * ((i + 1) % 2), 6 if i % 2 else 4))
        t.sopra(stella(62, 60, 4 if i % 2 else 6))
        sheet.alpha_composite(t.png(), (i * fw, 0))
    return sheet


# ---------------------------------------------------------------- il pianoforte a coda, di lato con il coperchio aperto
def coda(t, x0, y0, s=1.0, legs=(0, 0, 0), lid=0.0, crack=0.0):
    """Il pianoforte a coda con la tastiera a destra: cassa, coperchio aperto, tre gambe con le rotelle d'oro.
    x0, y0: l'angolo in alto a sinistra della cassa; legs: gradi di ogni gamba; lid: gradi in più del coperchio;
    crack: la cassa spezzata in mezzo (0 intera, 1 piegata a V)."""
    S = lambda v: v * s
    L, Hc = S(250), S(46)
    # gambe (dietro la cassa)
    for gx, ga in zip((S(24), S(122), S(222)), legs):
        cx, cy = x0 + gx, y0 + Hc - S(4)
        xf = f"rotate({ga},{cx},{cy})"
        t.forma(polyd([(cx - S(11), cy), (cx + S(11), cy), (cx + S(6), cy + S(84)), (cx - S(6), cy + S(84))]), LAC, light=(S(3), 0), xf=xf)
        t.forma(polyd([(cx - S(13), cy + S(8)), (cx + S(13), cy + S(8)), (cx + S(12), cy + S(16)), (cx - S(12), cy + S(16))]), GOLD, light=(0, -1), ink=4, xf=xf)
        t.forma(ell(cx, cy + S(90), S(8), S(7)), GOLD, light=(1, -2), ink=4, xf=xf)
    # la lira dei pedali, tra la gamba di mezzo e la tastiera
    px = x0 + S(176)
    t.forma(polyd([(px - S(10), y0 + Hc), (px + S(10), y0 + Hc), (px + S(6), y0 + Hc + S(54)), (px - S(6), y0 + Hc + S(54))]), LAC, light=(2, 0))
    t.forma(rect(px - S(14), y0 + Hc + S(52), S(28), S(8), S(3)), GOLD, light=(0, -1), ink=4)
    # il coperchio aperto, dietro la cassa: un'ala che sale verso la coda, retta dall'asta
    hx, hy = x0 + L - S(56), y0 + S(10)
    xf = f"rotate({-lid},{hx},{hy})"
    t.forma(polyd([(hx, hy), (x0 + S(14), y0 + S(10)), (x0 + S(4), y0 - S(64)), (x0 + S(40), y0 - S(80)), (hx - S(10), y0 - S(26))]), LAC, light=(S(3), S(3)), xf=xf)
    t.linea(f"M{x0 + S(22)},{y0 - S(58)} L{x0 + S(44)},{y0 - S(70)} M{x0 + S(30)},{y0 - S(40)} L{hx - S(30)},{y0 - S(16)}", LAC[2], S(3.5), xf=xf)
    t.linea(f"M{x0 + S(84)},{y0 + S(4)} L{x0 + S(70)},{y0 - S(52)}", INK, S(8))
    t.linea(f"M{x0 + S(84)},{y0 + S(4)} L{x0 + S(70)},{y0 - S(52)}", GOLD[1], S(3.5))
    # la cassa: dritta o spezzata a V
    mid = x0 + L * 0.5
    if crack > 0:
        drop = S(26) * crack
        left = polyd([(x0, y0 + S(4)), (mid - S(6), y0 + drop), (mid + S(4), y0 + Hc + drop), (x0 + S(8), y0 + Hc)])
        right = polyd([(mid + S(6), y0 + drop + S(4)), (x0 + L, y0), (x0 + L, y0 + Hc), (mid - S(2), y0 + Hc + drop)])
        t.forma(left, LAC, light=(S(3), -S(4)))
        t.forma(right, LAC, light=(S(3), -S(4)))
        t.linea(f"M{mid - S(6)},{y0 + drop - S(2)} L{mid + S(2)},{y0 + drop + S(14)} L{mid - S(6)},{y0 + drop + S(24)} L{mid + S(4)},{y0 + Hc + drop}", INK, S(3))
    else:
        t.forma(rect(x0, y0, L, Hc, S(14)), LAC, light=(S(3), -S(4)))
        t.linea(f"M{x0 + S(22)},{y0 + S(12)} H{x0 + L - S(70)}", LAC[2], S(3.5))
    # la tastiera che sporge a destra: tasti bianchi e neri sulla faccia
    kx, ky = x0 + L - S(48), y0 + S(12)
    t.forma(rect(kx, ky, S(64), S(22), S(4)), LAC, light=(S(2), -S(2)))
    t.forma(rect(kx + S(6), ky + S(4), S(56), S(12), S(2)), KEYS, light=(0, -S(2)), ink=4)
    for j in range(5):
        t.sopra(f'<rect x="{kx + S(10 + j * 10)}" y="{ky + S(4)}" width="{S(5)}" height="{S(7)}" fill="{INK}"/>')
    t.sopra(f'<rect x="{x0 + S(96)}" y="{y0 + S(22)}" width="{S(40)}" height="{S(12)}" rx="{S(3)}" fill="{GOLD[0]}" stroke="{INK}" stroke-width="2"/>')
    t.sopra(f'<text x="{x0 + S(116)}" y="{y0 + S(31.5)}" text-anchor="middle" font-family="DejaVu Serif" font-style="italic" font-weight="bold" font-size="{S(9.5)}" fill="{INK}">Opus</text>')


def pianoforte_cade():
    W, H = 300, 330
    t = Tela(W, H)
    knot = (W / 2, H * 0.38)
    # la corda dal nodo all'asta del coperchio, poi il pianoforte un po' storto con le gambe che penzolano
    t.linea(f"M{knot[0]},{knot[1]} L{knot[0] - 6},{knot[1] + 40}", INK, 12)
    t.linea(f"M{knot[0]},{knot[1]} L{knot[0] - 6},{knot[1] + 40}", "#557f2e", 6)
    g = Tela(W, H)
    coda(g, 28, 186, s=0.98, legs=(14, -6, 10), lid=6)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    img.alpha_composite(g.png().rotate(-4, resample=Image.BICUBIC, center=(W / 2, 200)))
    img.alpha_composite(t.png())
    return img


def pianoforte_a_terra():
    W, H = 360, 270
    t = Tela(W, H)
    # tasti saltati via, sparsi a terra
    for x, y, a in ((30, 258, -20), (318, 254, 30), (60, 236, 50), (300, 230, -40), (330, 262, 10)):
        t.forma(rect(x - 12, y - 4, 24, 8, 2), KEYS, light=(0, -2), ink=5, xf=f"rotate({a},{x},{y})")
    coda(t, 62, 170, s=0.94, legs=(56, 78, -58), lid=-14, crack=1.0)
    for x, y, r in ((120, 132, 9), (178, 118, 7), (236, 136, 8)):
        t.sopra(stella(x, y, r))
    return t.png()


# ---------------------------------------------------------------- il pianoforte piccolo che scappa
def pianino(t, cx, feet, step):
    a = math.sin(step * math.tau)
    body_y = feet - 34 - 4 * abs(math.cos(step * math.tau))
    # gambette che corrono
    for side, ph in ((0, 0.0), (1, 0.5)):
        sw = math.sin((step + ph) * math.tau)
        hip = (cx - 10 + side * 20, body_y)
        foot = (hip[0] + 14 * sw, feet - 6 - 6 * max(0.0, math.cos((step + ph) * math.tau)))
        col = LAC if side else (LAC[1], "#0e0f14")
        t.forma(polyd([(hip[0] - 4, hip[1]), (hip[0] + 4, hip[1]), (foot[0] + 3, foot[1]), (foot[0] - 3, foot[1])]), col, light=(1, 0), ink=6)
        t.forma(ell(foot[0] + 3, foot[1] + 2, 7, 4), GOLD, light=(1, -1), ink=4)
    lean = 8 + 3 * a
    xf = f"rotate({lean},{cx},{feet - 20})"
    t.forma(rect(cx - 34, body_y - 84, 68, 88, 8), LAC, light=(3, -4), xf=xf)
    t.forma(rect(cx - 38, body_y - 30, 76, 12, 4), LAC, light=(2, -2), xf=xf)
    # la tastiera è la bocca: un sorriso pieno di denti bianchi e neri
    t.forma(rect(cx - 30, body_y - 26, 60, 18, 6), KEYS, light=(0, -2), ink=4, xf=xf)
    for j in range(4):
        t.sopra(f'<rect x="{cx - 24 + j * 14}" y="{body_y - 26}" width="6" height="10" fill="{INK}" transform="{xf}"/>')
    # gli occhi spalancati sul pannello
    for ex in (-13, 13):
        t.forma(ell(cx + ex, body_y - 58, 10, 12), KEYS, light=(1, -1), ink=4, xf=xf)
        t.sopra(f'<circle cx="{cx + ex + 4}" cy="{body_y - 56 + 2 * a}" r="4.5" fill="{INK}" transform="{xf}"/>')
    t.sopra(f'<path d="M{cx - 28},{body_y - 76} L{cx - 4},{body_y - 70} M{cx + 28},{body_y - 76} L{cx + 4},{body_y - 70}" stroke="{INK}" stroke-width="4" stroke-linecap="round" transform="{xf}"/>')
    # gocce di spavento che volano dietro
    t.sopra(f'<path d="M{cx - 46},{body_y - 70 - 4 * a} q-6,8 0,12 q6,-4 0,-12 Z" fill="#bfe3ff" stroke="{INK}" stroke-width="2"/>')


def pianoforte_corre():
    fw, H, n = 110, 140, 4
    img = Image.new("RGBA", (fw * n, H), (0, 0, 0, 0))
    for i in range(n):
        t = Tela(fw, H)
        pianino(t, fw / 2 + 4, H - 6, i / n)
        img.alpha_composite(t.png(), (i * fw, 0))
    return img


# ---------------------------------------------------------------- il ritratto, da vicino
def ritratto():
    """portrait.png più vicino di quello di rendi_sprite.py: la testa con la criniera riempie il riquadro della lobby.
    I pezzi si montano come in Pittore.disegna (rendi_sprite.py), ma ingranditi di K, e si ritaglia attorno alla faccia
    del primo fotogramma del fermo."""
    import json, sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from rendi_sprite import Pittore
    from scheletro import Scheletro
    rig, K, lato = f"{OUT}/rig", 3.0, 118  # lato: pixel del disegno a 2x che finiscono nel ritratto da 150
    sk = Scheletro(rig)
    pit = Pittore(sk)
    fr = json.load(open(f"{rig}/animazioni.json"))["animations"]["idle"]["frames"][0]
    (hx, hy), _, _ = sk.fk(fr["bones"], fr["root"])["head"]
    dx, dy = sk.rig["portrait"]
    cx, cy = hx + dx - 8, hy + dy + 10  # il centro del ritratto, rispetto ai piedi: la criniera intera
    n = int(lato * K)
    tela = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    for _, osso, img, x, y in pit.strati:
        a, b, c, d, e, f = sk.matrici(fr["bones"], fr["root"])[osso]
        m = [[a * K, c * K], [b * K, d * K]]
        tx = (a * x + c * y + e - cx) * K + n / 2
        ty = (b * x + d * y + f - cy) * K + n / 2
        det = m[0][0] * m[1][1] - m[0][1] * m[1][0]
        ia, ib, ic, id_ = m[1][1] / det, -m[0][1] / det, -m[1][0] / det, m[0][0] / det
        inv = (ia, ib, -(ia * tx + ib * ty), ic, id_, -(ic * tx + id_ * ty))
        tela = Image.alpha_composite(tela, img.convert("RGBa").transform((n, n), Image.AFFINE, inv, resample=Image.BICUBIC).convert("RGBA"))
    return tela.resize((150, 150), Image.LANCZOS)


def salva(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)
    print(path, img.size)


if __name__ == "__main__":
    salva(nota(), f"{OUT}/proiettili/nota.png")
    salva(pianoforte_cade(), f"{OUT}/supreme/pianoforte-cade.png")
    salva(pianoforte_a_terra(), f"{OUT}/supreme/pianoforte-a-terra.png")
    salva(pianoforte_corre(), f"{OUT}/supreme/pianoforte-corre.png")
    if os.path.exists(f"{OUT}/rig/animazioni.json"):  # dopo rendi_sprite.py, che scrive il suo ritratto più lontano
        salva(ritratto(), f"{OUT}/portrait.png")
