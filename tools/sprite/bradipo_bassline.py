# Uso: python3 tools/sprite/bradipo_bassline.py
# La posa della Bassline di Bradipo Giallo (specialSide), che nel foglio di @Marcomunista (#335) non c'è: la posa
# ferma del foglio col basso a tracolla, nello stile del foglio (inchiostro nero spesso, colori pieni, bordo chiaro),
# e le onde viola della mossa davanti. Disegnato 4 volte più grande e rimpicciolito, per i bordi morbidi.
import math

from PIL import Image, ImageDraw, ImageFilter

SRC = "public/assets/characters/bradipo/idle.png"
OUT = "public/assets/characters/bradipo/specialSide.png"
K = 4  # sovracampionamento
INK = (20, 16, 16, 255)
BODY = (226, 33, 138, 255)  # il fucsia della cresta
BODY_SH = (160, 18, 98, 255)
WOOD = (150, 96, 52, 255)
FUR = (245, 194, 17, 255)
WAVE = (180, 140, 255, 255)  # 0xb48cff, il colore della Bassline in characters.ts
INK_W = 5


def rot(pts, c, a):
    ca, sa = math.cos(a), math.sin(a)
    return [(c[0] + (x - c[0]) * ca - (y - c[1]) * sa, c[1] + (x - c[0]) * sa + (y - c[1]) * ca) for x, y in pts]


def ellipse_pts(c, rx, ry, a, n=48):
    return rot([(c[0] + rx * math.cos(t * 2 * math.pi / n), c[1] + ry * math.sin(t * 2 * math.pi / n)) for t in range(n)], c, a)


def S(pts):
    return [(x * K, y * K) for x, y in pts]


def blob(d, pts, fill, w=INK_W):
    d.polygon(S(pts), fill=fill)
    d.line(S(pts + pts[:1]), fill=INK, width=w * K, joint="curve")


def paw(d, c, r):
    blob(d, ellipse_pts(c, r, r * 0.8, 0), FUR, 4)
    for i in (-1, 0, 1):  # gli artigli
        x, y = c[0] + i * r * 0.55, c[1] - r * 0.6
        d.line(S([(x, y), (x + 2, y - 5)]), fill=INK, width=3 * K)


def main():
    base = Image.open(SRC).convert("RGBA")
    w, h = base.size
    over = Image.new("RGBA", (w * K, h * K), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    a = math.radians(-28)  # il basso sale verso destra
    body_c = (142, 138)
    # il manico, poi la paletta con le chiavi
    neck_end = (body_c[0] + 112 * math.cos(a), body_c[1] + 112 * math.sin(a))
    nx, ny = -math.sin(a) * 5, math.cos(a) * 5
    neck = [(body_c[0] + nx, body_c[1] + ny), (neck_end[0] + nx, neck_end[1] + ny), (neck_end[0] - nx, neck_end[1] - ny), (body_c[0] - nx, body_c[1] - ny)]
    blob(d, neck, WOOD, 4)
    head_c = (neck_end[0] + 10 * math.cos(a), neck_end[1] + 10 * math.sin(a))
    blob(d, ellipse_pts(head_c, 13, 8, a), INK, 2)
    for t in (-6, 0, 6):
        px, py = head_c[0] + t * math.cos(a), head_c[1] + t * math.sin(a)
        d.ellipse(S([(px - 2.5 - nx * 1.4, py - 2.5 - ny * 1.4), (px + 2.5 - nx * 1.4, py + 2.5 - ny * 1.4)]), fill=(230, 230, 230, 255))
    # il corpo a due lobi, come un Precision
    for c, rx, ry in (((body_c[0] - 16, body_c[1] + 6), 24, 20), ((body_c[0] + 6, body_c[1] - 4), 19, 15)):
        blob(d, ellipse_pts(c, rx, ry, a), BODY)
    d.polygon(S(ellipse_pts((body_c[0] - 22, body_c[1] + 12), 12, 7, a)), fill=BODY_SH)
    d.polygon(S(ellipse_pts((body_c[0] - 4, body_c[1] + 2), 9, 5, a)), fill=INK)  # il pick-up
    for t in (-2.5, 2.5):  # le corde
        sx, sy = -math.sin(a) * t, math.cos(a) * t
        d.line(S([(body_c[0] - 18 + sx, body_c[1] + 10 + sy), (neck_end[0] + sx, neck_end[1] + sy)]), fill=(240, 240, 240, 255), width=K)
    # le zampe: una sul manico, una che pizzica
    paw(d, (neck_end[0] - 34 * math.cos(a), neck_end[1] - 34 * math.sin(a) + 3), 9)
    paw(d, (body_c[0] - 6, body_c[1] + 10), 9)
    # le onde viola della Bassline davanti
    for i, r in enumerate((22, 34, 46)):
        box = [(240 - r, 84 - r), (240 + r, 84 + r)]
        d.arc(S(box), -40, 40, fill=INK, width=(9 - i) * K)
        d.arc(S(box), -40, 40, fill=WAVE, width=(5 - i) * K)
    over = over.resize((w, h), Image.LANCZOS)
    # il bordo chiaro intorno, come nel foglio
    rim = over.split()[3].filter(ImageFilter.MaxFilter(5))
    halo = Image.new("RGBA", (w, h), (240, 236, 246, 0))
    halo.putalpha(rim.point(lambda v: 210 if v > 40 else 0))
    out = Image.alpha_composite(base, halo)
    out = Image.alpha_composite(out, over)
    out.save(OUT, optimize=True)
    print(OUT, out.size)


if __name__ == "__main__":
    main()
