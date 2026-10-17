# Uso: python3 tools/rig/genera_supreme_drop.py [ramarro|mvp]
# I disegni provvisori delle supreme "drop" dei lottatori della community (#13), fatti col codice come quelli di
# Omar (bonobot/omar): quello che cade appeso alla liana, quello che resta a terra e chi scappa dopo il puff.
# Disegnati a 2x (scale 0.5 in characters.ts), a 2 toni con l'inchiostro come gli altri provvisori.
#   ramarro: la suprema di Giovanni fRana, un ramarro gigante appeso per la coda
#   mvp: la suprema di Coach Cartier, il trofeo di MVP; dopo il puff scappa una moneta d'oro (il cashback)
import math, os, sys

from PIL import Image, ImageDraw, ImageFont

INK = (34, 28, 26, 255)
W_INK = 7  # spessore dell'inchiostro, pixel a 2x
OUT = "public/assets/characters/{}/supreme"
# Misure come quelle di Omar: la liana si lega al 62% dell'altezza da sotto di quello che cade
FALL, LAND, RUN, RUN_FRAMES = (300, 330), (360, 270), (440, 140), 4


def canvas(size):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def ell(d, c, r, fill, ink=W_INK):
    d.ellipse([c[0] - r[0], c[1] - r[1], c[0] + r[0], c[1] + r[1]], fill=fill, outline=INK, width=ink)


def limb(d, pts, w, fill):
    # un arto a 2 toni: l'inchiostro più largo sotto, il colore sopra
    d.line(pts, fill=INK, width=w + W_INK, joint="curve")
    d.line(pts, fill=fill, width=w, joint="curve")
    for p in (pts[0], pts[-1]):
        d.ellipse([p[0] - w / 2, p[1] - w / 2, p[0] + w / 2, p[1] + w / 2], fill=fill)


def rotate_pts(pts, c, a):
    ca, sa = math.cos(a), math.sin(a)
    return [(c[0] + (x - c[0]) * ca - (y - c[1]) * sa, c[1] + (x - c[0]) * sa + (y - c[1]) * ca) for x, y in pts]


# ---------- Ramarro ----------
GREEN, GREEN_SH, BELLY = (92, 178, 58, 255), (50, 120, 40, 255), (200, 226, 120, 255)


def ramarro_side(d, x, feet, k, step=0.0, stunned=False):
    # di lato, guarda a destra: k è la scala, step la fase della corsa (0..1)
    s = lambda v: v * k
    body_y = feet - s(34)
    # coda che serpeggia dietro
    tail = [(x - s(40), body_y), (x - s(70), body_y - s(6) + math.sin(step * 6.3) * s(6)), (x - s(96), body_y + s(4)), (x - s(112), body_y - s(8))]
    limb(d, tail, int(s(14)), GREEN)
    # zampe: due dietro e due davanti, alternate nella corsa
    for i, (bx, ph) in enumerate(((-24, 0.0), (26, 0.5))):
        for side in (0, 1):
            a = math.sin((step + ph + side * 0.5) * 2 * math.pi) * 0.7
            hip = (x + s(bx), body_y + s(6))
            foot = (hip[0] + math.sin(a) * s(16), feet - s(2))
            limb(d, [hip, foot], int(s(9)), GREEN_SH if side == 0 else GREEN)
    ell(d, (x, body_y), (s(48), s(20)), GREEN)
    d.ellipse([x - s(34), body_y + s(2), x + s(30), body_y + s(16)], fill=BELLY)
    # testa a punta con l'occhio
    hx = x + s(58)
    d.polygon([(hx - s(20), body_y - s(16)), (hx + s(30), body_y - s(4)), (hx + s(30), body_y + s(4)), (hx - s(20), body_y + s(14))], fill=GREEN, outline=INK, width=W_INK)
    ex, ey = hx + s(6), body_y - s(6)
    if stunned:
        for dx in (-1, 1):
            d.line([(ex - s(6), ey - s(6) * dx), (ex + s(6), ey + s(6) * dx)], fill=INK, width=int(s(3)) + 2)
    else:
        ell(d, (ex, ey), (s(6), s(6)), (250, 248, 236, 255), ink=3)
        d.ellipse([ex, ey - s(3), ex + s(4), ey + s(3)], fill=INK)


def ramarro_falling():
    img, d = canvas(FALL)
    cx, knot = FALL[0] / 2, FALL[1] * 0.38
    # appeso per la coda: la coda sale fino al nodo, il corpo pende a testa in giù, le zampe aperte
    limb(d, [(cx, knot), (cx + 14, knot + 40), (cx - 6, knot + 80), (cx, 210)], 18, GREEN)
    for side in (-1, 1):
        for y, l in ((222, 46), (276, 40)):
            limb(d, [(cx + side * 30, y), (cx + side * (30 + l), y - 18), (cx + side * (40 + l), y - 40)], 13, GREEN)
    ell(d, (cx, 250), (40, 62), GREEN)
    d.ellipse([cx - 22, 214, cx + 22, 290], fill=BELLY)
    # la testa in giù, con la bocca aperta e gli occhi spalancati
    d.polygon([(cx - 30, 296), (cx + 30, 296), (cx + 10, 326), (cx - 10, 326)], fill=GREEN, outline=INK, width=W_INK)
    d.line([(cx - 8, 318), (cx + 8, 318)], fill=(200, 60, 60, 255), width=6)
    for side in (-1, 1):
        ell(d, (cx + side * 18, 302), (9, 9), (250, 248, 236, 255), ink=3)
        d.ellipse([cx + side * 18 - 3, 300, cx + side * 18 + 3, 308], fill=INK)
    return img


def ramarro_landed():
    img, d = canvas(LAND)
    ramarro_side(d, LAND[0] / 2 + 20, LAND[1] - 8, 1.7, stunned=True)
    return img


def ramarro_runner():
    img, d = canvas(RUN)
    fw = RUN[0] // RUN_FRAMES
    for i in range(RUN_FRAMES):
        ramarro_side(d, i * fw + fw / 2 + 14, RUN[1] - 6, 0.55, step=i / RUN_FRAMES)
    return img


# ---------- MVP ----------
GOLD, GOLD_SH, GOLD_HI = (240, 190, 50, 255), (190, 130, 20, 255), (255, 236, 150, 255)
WOOD = (110, 70, 40, 255)


def trophy(d, cx, bottom, k, tilt=0.0):
    s = lambda v: v * k
    c = (cx, bottom - s(100))
    P = lambda pts: rotate_pts([(cx + s(x), bottom - s(y)) for x, y in pts], c, tilt)
    # i manici, la coppa, lo stelo, la base di legno con la targhetta
    for side in (-1, 1):
        d.line(P([(side * 46, 170), (side * 72, 168), (side * 72, 136), (side * 40, 122)]), fill=INK, width=int(s(13)) + W_INK, joint="curve")
        d.line(P([(side * 46, 170), (side * 72, 168), (side * 72, 136), (side * 40, 122)]), fill=GOLD, width=int(s(13)), joint="curve")
    d.polygon(P([(-56, 186), (56, 186), (40, 118), (0, 98), (-40, 118)]), fill=GOLD, outline=INK, width=W_INK)
    d.polygon(P([(-40, 180), (-20, 180), (-18, 122), (-30, 128)]), fill=GOLD_HI)
    d.polygon(P([(30, 182), (50, 182), (36, 122), (24, 116)]), fill=GOLD_SH)
    d.polygon(P([(-10, 100), (10, 100), (14, 56), (-14, 56)]), fill=GOLD_SH, outline=INK, width=W_INK)
    d.polygon(P([(-46, 58), (46, 58), (46, 4), (-46, 4)]), fill=WOOD, outline=INK, width=W_INK)
    d.polygon(P([(-30, 46), (30, 46), (30, 16), (-30, 16)]), fill=GOLD, outline=INK, width=4)
    font = ImageFont.load_default(size=int(s(24)))
    tx, ty = P([(0, 31)])[0]
    d.text((tx, ty), "MVP", fill=INK, font=font, anchor="mm")


def coin(d, cx, bottom, k, phase):
    # la moneta che rotola via con le gambette: si stringe girando
    s = lambda v: v * k
    w = s(30) * max(0.25, abs(math.cos(phase * math.pi)))
    cy = bottom - s(56)
    for side, ph in ((-1, 0.0), (1, 0.5)):
        a = math.sin((phase + ph) * 2 * math.pi) * 0.6
        hip = (cx + side * s(8), cy + s(26))
        limb(d, [hip, (hip[0] + math.sin(a) * s(14), bottom - s(4))], int(s(7)), INK[:3] + (255,))
    ell(d, (cx, cy), (w, s(30)), GOLD)
    if w > s(12):
        ell(d, (cx, cy), (w * 0.62, s(19)), GOLD_SH, ink=3)
        d.ellipse([cx - w * 0.3, cy - s(12), cx - w * 0.05, cy - s(4)], fill=GOLD_HI)


def mvp_falling():
    img, d = canvas(FALL)
    cx, knot = FALL[0] / 2, FALL[1] * 0.38
    # il nastro dal nodo al manico, poi il trofeo che pende un po' storto
    d.line([(cx, knot), (cx + 50, knot + 46)], fill=INK, width=12)
    d.line([(cx, knot), (cx + 50, knot + 46)], fill=(200, 40, 60, 255), width=6)
    trophy(d, cx, FALL[1] - 4, 0.95, tilt=0.12)
    return img


def mvp_landed():
    img, d = canvas(LAND)
    trophy(d, LAND[0] / 2, LAND[1] - 4, 1.2)
    for x, y in ((60, 262), (300, 258), (95, 250)):
        ell(d, (x, y), (18, 7), GOLD, ink=4)
    return img


def mvp_runner():
    img, d = canvas(RUN)
    fw = RUN[0] // RUN_FRAMES
    for i in range(RUN_FRAMES):
        coin(d, i * fw + fw / 2, RUN[1] - 4, 1.4, i / RUN_FRAMES)
    return img


SUPREMES = {
    "ramarro": ("giovannifrana", ramarro_falling, ramarro_landed, ramarro_runner),
    "mvp": ("coachcartier", mvp_falling, mvp_landed, mvp_runner),
}

if __name__ == "__main__":
    for name in sys.argv[1:] or SUPREMES:
        char, falling, landed, runner = SUPREMES[name]
        out = OUT.format(char)
        os.makedirs(out, exist_ok=True)
        for kind, fn in (("cade", falling), ("a-terra", landed), ("corre", runner)):
            fn().save(os.path.join(out, f"{name}-{kind}.png"), optimize=True)
        print(f"{name}: {out}")
