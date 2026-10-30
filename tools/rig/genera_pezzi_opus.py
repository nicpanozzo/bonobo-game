# Uso: python3 tools/rig/genera_pezzi_opus.py   (servono cairosvg e Pillow; poi animazioni_opus.py e rendi_sprite.py)
# I pezzi di Maestro Opus, il bonobo direttore d'orchestra (inventato da Claude per Davide): frac nero con le code,
# panciotto e farfallino bianchi, garofano rosso, criniera bianca alla Beethoven, piedi nudi da bonobo e una
# bacchetta enorme con la punta d'oro. Scheda: docs/mosse/opus.md.
# Stesse ossa dei lottatori in piedi (genera_pezzi_lottatore.py), rimpicciolite di S perché è piccoletto, più un osso
# suo: le code del frac (coat_tail, figlio di hips), che animazioni_opus.py fa svolazzare.
# Scrive public/assets/characters/opus/rig/rig.json e rig/pezzi/*.png, nel formato di docs/scheletro.md.
import json, math, os, sys

import cairosvg
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from genera_pezzi_lottatore import BONOBOT, CANVAS, INK, OX, OY, PAD, W, capsule, darker, ellipse_pts, human_bones

CID = "opus"
OUT = f"public/assets/characters/{CID}/rig"
S = 0.9  # piccoletto: tutto lo scheletro umano al 90%
BATON = 78  # lunghezza della bacchetta oltre il polso, pixel a 2x prima di S (la usa anche animazioni_opus.py)
TAIL = ((-13, -112), (-22, -58))  # l'osso delle code del frac, prima di S

# I colori: 2 toni (base, ombra) e un filo di luce sul bordo illuminato (rim) per staccarsi dai fondali scuri
FUR = ("#6a4631", "#45291b", "#a27a5c")
FACE = ("#4b3a34", "#33261f", "#7d655a")
MUZZLE = ("#7f6457", "#5f4639")
LIPS = "#d0868a"
COAT = ("#2b2f44", "#1a1c2a", "#5d6690")
SATIN = ("#454c6c", "#30354d")
SHIRT = ("#f7f4ec", "#d3cdc0")
HAIR = ("#f7f5ef", "#cbc6bc")
GOLD = ("#f4c64f", "#c48f22", "#fff1b8")
ROSE = ("#c22f45", "#8c1d30")
BATON_WOOD = ("#fbfaf6", "#d6d2c8")
CORK = ("#c99a5c", "#9a6e3a")


def P(x, y):
    return f"{x * S + OX:.1f},{y * S + OY:.1f}"


def poly(pts):
    return " ".join(P(x, y) for x, y in pts)


class Disegno:
    """I pezzi: forme a due toni con un filo di luce, e le sagome raccolte per il livello d'inchiostro."""

    def __init__(self):
        self.uid, self.shapes, self.pieces = 0, [], []

    def shaded(self, pts, col, light=(3.0, -3.5), outline=True):
        base, shade = col[0], col[1]
        rim = col[2] if len(col) > 2 else None
        self.uid += 1
        cid = f"c{self.uid}"
        lx, ly = light
        pl = poly(pts)
        s = f'<clipPath id="{cid}"><polygon points="{pl}"/></clipPath><polygon points="{pl}" fill="{shade}"/>'
        if rim:  # il bordo verso la luce prende un filo chiaro, poi la base lo copre lasciandone solo il margine
            s += f'<g clip-path="url(#{cid})"><polygon points="{pl}" fill="none" stroke="{rim}" stroke-width="5"/>'
            s += f'<polygon points="{poly([(x + lx * 2.0, y + ly * 2.0) for x, y in pts])}" fill="{base}"/></g>'
        s += f'<polygon clip-path="url(#{cid})" points="{poly([(x + lx, y + ly) for x, y in pts])}" fill="{base}"/>'
        if outline:
            self.shapes.append(list(pts))
        return s

    def piece(self, name, bone, z, svg, own=False):
        self.pieces.append((name, bone, z, svg, list(self.shapes), own))
        self.shapes.clear()


def flat(pts, fill, w=1.8, stroke=INK):
    return f'<polygon points="{poly(pts)}" fill="{fill}" stroke="{stroke}" stroke-width="{w}" stroke-linejoin="round"/>'


def line(a, b, color, w):
    return f'<path d="M{P(*a)} L{P(*b)}" stroke="{color}" stroke-width="{w}" stroke-linecap="round" fill="none"/>'


def path(d, stroke=INK, w=2.0, fill="none"):
    return f'<path d="{d}" stroke="{stroke}" stroke-width="{w}" fill="{fill}" stroke-linecap="round" stroke-linejoin="round"/>'


def dot(c, r, fill, ink=0.0):
    st = f' stroke="{INK}" stroke-width="{ink}"' if ink else ""
    return f'<circle cx="{c[0] * S + OX:.1f}" cy="{c[1] * S + OY:.1f}" r="{r * S:.2f}" fill="{fill}"{st}/>'


def quad(*pts):
    """Un percorso chiuso di curve: M p0 Q c1 p1 Q c2 p2 ..."""
    d = f"M{P(*pts[0])}"
    for i in range(1, len(pts) - 1, 2):
        d += f" Q{P(*pts[i])} {P(*pts[i + 1])}"
    return d + " Z"


def curve_pts(*pts, n=8):
    """I punti di una spezzata di curve quadratiche (p0, c1, p1, c2, p2...), per le sagome con l'inchiostro."""
    out = [pts[0]]
    for i in range(1, len(pts) - 1, 2):
        a, c, b = pts[i - 1], pts[i], pts[i + 1]
        for k in range(1, n + 1):
            t = k / n
            out.append(((1 - t) ** 2 * a[0] + 2 * (1 - t) * t * c[0] + t * t * b[0], (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * c[1] + t * t * b[1]))
    return out


def genera():
    os.makedirs(f"{OUT}/pezzi", exist_ok=True)
    base_rig = json.load(open(BONOBOT, encoding="utf-8"))
    bones = human_bones(base_rig["bones"])
    # le code del frac: un osso in più, figlio dei fianchi, che le animazioni fanno svolazzare in ritardo
    i = next(k for k, b in enumerate(bones) if b["name"] == "spine_1")
    bones.insert(i, {**next(b for b in bones if b["name"] == "hips"), "name": "coat_tail", "parent": "hips",
                     "head": list(TAIL[0]), "tail": list(TAIL[1])})
    H = {b["name"]: tuple(b["head"]) for b in bones}
    T = {b["name"]: tuple(b["tail"]) for b in bones}
    d = Disegno()

    def far(col, f):
        return tuple(darker(c, 0.78) for c in col) if f else col

    def along(a, b, k):
        ln = math.hypot(b[0] - a[0], b[1] - a[1])
        return (a[0] + (b[0] - a[0]) / ln * k, a[1] + (b[1] - a[1]) / ln * k)

    def arm(side, z0):
        f = side == "L"
        own = not f
        coat, fur, shirt = far(COAT, f), far(FUR, f), far(SHIRT, f)
        d.piece(f"upper_arm_{side}", f"upper_arm_{side}", z0, d.shaded(capsule(H[f"upper_arm_{side}"], T[f"upper_arm_{side}"], 8.5, 7.2), coat), own)
        a, b = H[f"forearm_{side}"], T[f"forearm_{side}"]
        s = d.shaded(capsule(a, b, 7.2, 6.4), coat)
        # il polsino bianco della camicia che esce dalla manica
        s += d.shaded(capsule(along(a, b, 24), along(a, b, 30.5), 6.6, 6.0, n=8), shirt, light=(1, -1), outline=False)
        s += dot(along(a, b, 27), 1.5, GOLD[0] if not f else darker(GOLD[0]))
        d.piece(f"forearm_{side}", f"forearm_{side}", z0 + 1, s, own)
        d.piece(f"thumb_{side}", f"thumb_{side}", z0 + 2, d.shaded(capsule(H[f"thumb_{side}"], T[f"thumb_{side}"], 3.4, 2.8), fur, light=(1, -1)), own)
        d.piece(f"hand_{side}", f"hand_{side}", z0 + 3, d.shaded(capsule(H[f"hand_{side}"], T[f"hand_{side}"], 6.4, 6.8), fur, light=(1.5, -2)), own)
        if not f:  # la bacchetta: impugnatura di sughero nel pugno, asta bianca lunga e la punta d'oro
            (ax, ay), (bx, by) = H["hand_R"], T["hand_R"]
            ln = math.hypot(bx - ax, by - ay)
            ux, uy = (bx - ax) / ln, (by - ay) / ln
            at = lambda k: (ax + ux * k, ay + uy * k)
            s = d.shaded(capsule(at(16), at(BATON - 6), 2.4, 1.5, n=8), BATON_WOOD, light=(0.5, -0.6))
            s += d.shaded(ellipse_pts(*at(BATON - 3), 3.6, 3.6, n=16), GOLD, light=(0.8, -0.8))
            s += dot((at(BATON - 3)[0] + 0.9, at(BATON - 3)[1] - 1.2), 1.1, GOLD[2])
            s += d.shaded(capsule(at(6), at(17), 4.4, 3.6, n=10), CORK, light=(0.8, -1.0))
            d.piece("baton", "hand_R", z0 + 3.5, s, own)
        fx, fy = H[f"fingers_{side}"]
        tx, ty = T[f"fingers_{side}"]
        s = d.shaded(capsule((fx, fy), (tx, ty), 6.4, 5.0), fur, light=(1.5, -1.5))
        for kk in (-3.0, 0.0, 3.0):
            s += line((fx + kk + 1.5, fy + 3), (tx + kk * 0.6, ty + 2), "#2a1a12", 1.4)
        d.piece(f"fingers_{side}", f"fingers_{side}", z0 + 4, s, own)

    def leg(side, z0):
        f = side == "L"
        own = not f
        pants, fur = far(COAT, f), far(FUR, f)
        a, b = H[f"thigh_{side}"], T[f"thigh_{side}"]
        s = d.shaded(capsule(a, b, 10.5, 8.5), pants)
        s += line((a[0] + 1, a[1] + 8), (b[0] + 1, b[1] - 2), far(SATIN, f)[0], 2.6)  # la riga di raso dei pantaloni
        d.piece(f"thigh_{side}", f"thigh_{side}", z0, s, own)
        a, b = H[f"shin_{side}"], T[f"shin_{side}"]
        s = d.shaded(capsule(a, b, 8.5, 7.6), pants)
        s += line((a[0] + 1, a[1] + 2), (b[0] + 1, b[1] - 6), far(SATIN, f)[0], 2.6)
        d.piece(f"shin_{side}", f"shin_{side}", z0 + 1, s, own)
        # piedi nudi da bonobo sotto i pantaloni del frac: pelo sul dorso, pianta chiara
        d.piece(f"foot_{side}", f"foot_{side}", z0 + 2, d.shaded(capsule(H[f"foot_{side}"], T[f"foot_{side}"], 7.2, 6.6), fur, light=(1.5, -2)), own)
        a, b = H[f"toes_{side}"], T[f"toes_{side}"]
        s = d.shaded(capsule(a, b, 6.0, 4.6), fur, light=(1, -1.5))
        s += line((a[0] - 4, a[1] + 4.2), (b[0] + 3, b[1] + 3.6), far(MUZZLE, f)[0], 2.4)  # la pianta
        s += line((b[0] - 3, b[1] - 1), (b[0] - 3.5, b[1] + 3), "#2a1a12", 1.2)
        d.piece(f"toes_{side}", f"toes_{side}", z0 + 3, s, own)

    # ---------------------------------------------------------------- dietro: braccio e gamba lontani, code del frac
    arm("L", 0)
    leg("L", 6)
    (hx, hy), (tx, ty) = TAIL
    tails = curve_pts((hx + 6, hy - 2), (hx - 6, hy + 14), (tx - 2, ty + 2), (tx + 4, ty + 6), (tx + 6, ty - 6),
                      (hx + 2, hy + 30), (hx + 10, hy + 4))
    s = d.shaded(tails, COAT, light=(2, -2))
    s += path(f"M{P(hx + 2, hy + 10)} Q{P(hx - 2, hy + 34)} {P(tx + 3, ty + 2)}", COAT[1], 2.2)  # lo spacco tra le due code
    d.piece("coat_tail", "coat_tail", 10, s)

    # ---------------------------------------------------------------- corpo: pantaloni, panciotto, frac, camicia
    d.piece("pelvis", "hips", 20, d.shaded(ellipse_pts(-2, -96, 16.5, 13.5, -5), COAT, light=(4, 0)))
    s = d.shaded(ellipse_pts(1, -113, 16.5, 12.5, -8), COAT, light=(5, 0))
    # davanti il frac è tagliato in vita: si vede la punta del panciotto bianco
    s += flat([(6, -124), (19, -124), (18, -110), (12, -102), (6, -108)], SHIRT[0], 1.6)
    s += line((9, -110), (16, -110), SHIRT[1], 1.4)
    d.piece("belly", "spine_1", 21, s)
    s = d.shaded(ellipse_pts(5, -132, 19.5, 15.5, -12), COAT, light=(5, 0))
    s += flat([(12, -147), (25, -146), (24, -128), (19, -118), (11, -121)], SHIRT[0], 1.6)  # lo sparato della camicia
    s += path(f"M{P(12, -146)} Q{P(16, -132)} {P(11, -120)}", SATIN[0], 3.2)  # il risvolto di raso
    for y in (-140, -132):
        s += dot((20, y), 1.5, GOLD[0], 0.8)  # i bottoncini d'oro dello sparato
    # il garofano rosso all'occhiello
    for a in range(5):
        t = a * math.tau / 5
        s += dot((9 + 2.6 * math.cos(t), -138 + 2.6 * math.sin(t)), 2.4, ROSE[0], 0.9)
    s += dot((9, -138), 1.8, ROSE[1])
    s += path(f"M{P(9, -135)} L{P(8, -129)}", "#3f7a3a", 1.6)
    d.piece("chest", "spine_2", 22, s)
    s = d.shaded(ellipse_pts(8, -146, 16.5, 9.5, -15), COAT, light=(3, -2))
    s += flat([(15, -153), (24, -151), (22, -144), (15, -146)], SHIRT[0], 1.5)  # il colletto ad ali
    d.piece("shoulders", "spine_3", 23, s)
    d.piece("neck", "neck", 24, d.shaded(capsule(H["neck"], T["neck"], 7.0, 7.0), FUR))
    # il farfallino bianco, davanti al collo
    nx, ny = 20, -151
    s = flat([(nx, ny), (nx - 6, ny - 5), (nx - 7, ny + 4)], SHIRT[0], 1.6) + flat([(nx, ny), (nx + 6, ny - 5), (nx + 7, ny + 4)], SHIRT[0], 1.6)
    s += flat(ellipse_pts(nx, ny, 2.4, 2.6, n=12), SHIRT[1], 1.4)
    d.piece("bowtie", "neck", 24.6, s, own=True)
    leg("R", 30)

    # ---------------------------------------------------------------- testa: muso da bonobo, criniera bianca
    # Dietro la testa la massa della criniera, nel pezzo della testa; i ciuffi sono pezzi a parte che seguono in ritardo
    s = d.shaded(curve_pts((4, -168), (-6, -186), (8, -200), (22, -210), (36, -199), (40, -190), (30, -186),
                           (16, -184), (10, -168)), HAIR, light=(2, -2))
    s += d.shaded(ellipse_pts(23, -178, 18.5, 19.5, -6), FACE)
    s += flat(ellipse_pts(11, -176, 4.6, 6.4, -10), FACE[1], 1.8)  # l'orecchio scuro
    s += path(f"M{P(10, -178)} Q{P(13, -176)} {P(10.5, -172)}", INK, 1.2)
    # il muso chiaro che sporge in avanti, le narici
    s += d.shaded(ellipse_pts(39, -168, 13.5, 9.5, 8), MUZZLE, light=(1.5, -2))
    s += dot((49.5, -171), 1.3, INK) + dot((46.5, -171.5), 1.2, INK)
    # l'occhio furbo, mezzo chiuso dalla palpebra (pezzo "lid")
    s += flat(ellipse_pts(40.5, -177.5, 4.8, 3.9, -4), "#f6f1e6", 1.7)
    s += dot((42, -177.4), 2.3, "#2a160c") + dot((42.8, -178.2), 0.8, "#ffffff")
    # la criniera davanti all'orecchio, con la scriminatura
    s += d.shaded(curve_pts((14, -196), (24, -203), (36, -197), (30, -192), (22, -191), (16, -186), (12, -186)), HAIR, light=(1, -2))
    s += path(f"M{P(18, -196)} Q{P(22, -193)} {P(21, -188)}", HAIR[1], 1.4)
    d.piece("head", "head", 40, s)

    # mascella: il mento chiaro e le labbra rosa, col sorrisetto sicuro di sé
    s = d.shaded(ellipse_pts(42, -158.5, 11, 6.2, 6), MUZZLE, light=(1, -1.5))
    s += path(f"M{P(36, -161)} Q{P(44, -158)} {P(51, -163)}", LIPS, 2.6)
    s += path(f"M{P(36, -161)} Q{P(44, -158)} {P(51, -163)}", INK, 1.1)
    d.piece("jaw", "jaw", 39, s)
    # sopracciglio bianco e cespuglioso, inarcato
    s = path(f"M{P(33, -182.5)} Q{P(39, -188)} {P(47, -183.5)}", INK, W + 4.4)
    s += path(f"M{P(33, -182.5)} Q{P(39, -188)} {P(47, -183.5)}", HAIR[0], 4.2)
    s += path(f"M{P(36, -184.5)} L{P(33, -187)} M{P(41, -186)} L{P(40, -189)}", HAIR[0], 1.8)
    d.piece("brow", "brow", 43, s, own=True)
    # la palpebra: copre la metà alta dell'occhio (aria di superiorità); ruotata, lo chiude
    s = f'<path d="M{P(35.4, -177.8)} Q{P(40.5, -183)} {P(45.6, -178)} Q{P(40.5, -179.8)} {P(35.4, -177.8)} Z" fill="{FACE[0]}" stroke="{INK}" stroke-width="1.5"/>'
    d.piece("lid", "lid", 42, s, own=True)

    def tuft(nm, z, pts):
        d.piece(nm, nm, z, d.shaded(pts, HAIR, light=(1, -1.5)))

    # i ciuffi: la criniera che vola indietro a punte e il ciuffo ribelle davanti
    tuft("tuft_back", 38, curve_pts((14, -200), (2, -212), (-14, -206), (-6, -202), (-22, -194), (-10, -190), (-24, -178),
                                    (-10, -178), (-18, -164), (-4, -170), (6, -166), (8, -184), (14, -200)))
    tuft("tuft_front", 44, curve_pts((22, -198), (30, -214), (46, -212), (38, -208), (44, -202), (36, -200), (30, -194)))
    # la canna e il fumo sono di Bonobot: Opus ha le ossa (joint, smoke_*) ma nessun pezzo
    arm("R", 50)

    # ---------------------------------------------------------------- export, come genera_pezzi_lottatore.py
    def render(svg, p):
        doc = f'<svg xmlns="http://www.w3.org/2000/svg" width="{CANVAS}" height="{CANVAS}">{svg}</svg>'
        cairosvg.svg2png(bytestring=doc.encode(), write_to=p)
        return Image.open(p)

    for f in os.listdir(f"{OUT}/pezzi"):
        os.remove(f"{OUT}/pezzi/{f}")
    pieces_json = []
    for name, bone, z, svg, shapes, own in sorted(d.pieces, key=lambda p: p[2]):
        ink_svg = "".join(f'<polygon points="{poly(sh)}" fill="{INK}" stroke="{INK}" stroke-width="{W * 2}" stroke-linejoin="round"/>' for sh in shapes)
        fill_im = render(svg, f"{OUT}/pezzi/_f.png")
        ink_im = render(ink_svg, f"{OUT}/pezzi/_i.png") if shapes else None
        bbox = fill_im.getbbox() or (OX, OY, OX + 1, OY + 1)
        if ink_im is not None and ink_im.getbbox():
            ib = ink_im.getbbox()
            bbox = (min(bbox[0], ib[0]), min(bbox[1], ib[1]), max(bbox[2], ib[2]), max(bbox[3], ib[3]))
        x0, y0, x1, y1 = bbox[0] - PAD, bbox[1] - PAD, bbox[2] + PAD, bbox[3] + PAD
        fill_im.crop((x0, y0, x1, y1)).save(f"{OUT}/pezzi/{name}.png", optimize=True)
        entry = {"name": name, "bone": bone, "z": z, "image": f"pezzi/{name}.png", "x": x0 - OX, "y": y0 - OY,
                 "width": x1 - x0, "height": y1 - y0}
        if ink_im is not None:
            ink_im.crop((x0, y0, x1, y1)).save(f"{OUT}/pezzi/{name}_ink.png", optimize=True)
            entry["ink"] = f"pezzi/{name}_ink.png"
            entry["inkZ"] = z - 0.5 if own else -100
        pieces_json.append(entry)
    for f in ("_f.png", "_i.png"):
        if os.path.exists(f"{OUT}/pezzi/{f}"):
            os.remove(f"{OUT}/pezzi/{f}")
    scaled = [dict(b, head=[round(v * S, 2) for v in b["head"]], tail=[round(v * S, 2) for v in b["tail"]]) for b in bones]
    rig = {"character": CID, "version": 2, "units": base_rig["units"], "scale": base_rig["scale"], "bones": scaled,
           "ik": base_rig["ik"], "pieces": pieces_json, "portrait": [10, -24]}
    json.dump(rig, open(f"{OUT}/rig.json", "w"), indent=2, ensure_ascii=False)
    print(CID, len(pieces_json), "pezzi")


if __name__ == "__main__":
    genera()
