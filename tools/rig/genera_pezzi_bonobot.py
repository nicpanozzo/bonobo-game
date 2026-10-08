# Uso: python3 tools/rig/genera_pezzi_bonobot.py  (servono cairosvg e Pillow: pip install cairosvg pillow)
# Genera i pezzi di Bonobot (SVG + PNG ritagliati), rig.json e una tavola di controllo.
# Coordinate "arte": pixel a 2x, origine ai piedi al centro, y in giù, Bonobot guarda a destra.
import json, math, os, sys
import cairosvg
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else "public/assets/characters/bonobot/rig"
os.makedirs(f"{OUT}/pezzi", exist_ok=True)

INK = "#1f1714"
W = 3.2  # inchiostro ~3 px a 2x
FUR, FUR_SH, RIM = "#4a3326", "#2e1f17", "#a08268"
SKIN, SKIN_SH = "#3a2e29", "#241b18"
LIPS = "#c98a8a"
# Arti dalla parte lontana: un tono più scuri, come in ombra
FAR = {"#4a3326": "#3a271d", "#2e1f17": "#221610", "#a08268": "#7a6250", "#3a2e29": "#2c231f", "#241b18": "#1a1311"}

CANVAS = 420  # tela di lavoro: origine dei piedi a (210, 330)
OX, OY = 210, 330


def far(c, is_far):
    return FAR.get(c, c) if is_far else c


def P(x, y):
    return f"{x + OX:.1f},{y + OY:.1f}"


def capsule(a, b, r1, r2, n=14):
    """Poligono di una capsula rastremata da a (raggio r1) a b (raggio r2)."""
    ax, ay = a
    bx, by = b
    ang = math.atan2(by - ay, bx - ax)
    pts = []
    for i in range(n + 1):  # mezzo cerchio in b
        t = ang - math.pi / 2 + math.pi * i / n
        pts.append((bx + math.cos(t) * r2, by + math.sin(t) * r2))
    for i in range(n + 1):  # mezzo cerchio in a
        t = ang + math.pi / 2 + math.pi * i / n
        pts.append((ax + math.cos(t) * r1, ay + math.sin(t) * r1))
    return pts


def poly(pts):
    return " ".join(P(x, y) for x, y in pts)


def ellipse_pts(cx, cy, rx, ry, rot=0.0, n=40):
    c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    out = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x, y = math.cos(t) * rx, math.sin(t) * ry
        out.append((cx + x * c - y * s, cy + x * s + y * c))
    return out


_uid = [0]


def shaded(pts, base, shade, light=(3.0, -3.5), rim=None, furry=0):
    """Forma a 2 toni: ombra su tutto, tono base spostato verso la luce (davanti in alto),
    luce di bordo opzionale sul lato illuminato, inchiostro sopra. furry: ciuffi di pelo sul bordo."""
    _uid[0] += 1
    cid = f"c{_uid[0]}"
    lx, ly = light
    pl = poly(pts)
    shifted = poly([(x + lx, y + ly) for x, y in pts])
    s = f'<clipPath id="{cid}"><polygon points="{pl}"/></clipPath>'
    s += f'<polygon points="{pl}" fill="{shade}"/>'
    s += f'<polygon clip-path="url(#{cid})" points="{shifted}" fill="{base}"/>'
    if rim:
        rim_pts = poly([(x + lx * 2.2, y + ly * 2.2) for x, y in pts])
        s += f'<g clip-path="url(#{cid})"><polygon points="{pl}" fill="none" stroke="{rim}" stroke-width="5"/>'
        s += f'<polygon points="{rim_pts}" fill="{base}"/></g>'
    if furry:
        s += fur_strands(pts, shade, furry)
    _shapes.append(pts)
    return s


_shapes = []  # le sagome del pezzo in costruzione, per il suo livello d'inchiostro


def fur_strands(pts, color, n):
    # trattini di pelo verso l'interno, sul lato in ombra (dietro e sotto)
    s = ""
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    step = max(1, len(pts) // n)
    for i in range(0, len(pts), step):
        x, y = pts[i]
        if x - cx > 4 and y - cy < -4:
            continue  # niente sul lato illuminato
        dx, dy = cx - x, cy - y
        d = math.hypot(dx, dy) or 1
        x2, y2 = x + dx / d * 7, y + dy / d * 7
        s += f'<path d="M{P(x, y)} L{P(x2, y2)}" stroke="{color}" stroke-width="2" stroke-linecap="round"/>'
    return s


def line(a, b, color, w):
    return f'<path d="M{P(*a)} L{P(*b)}" stroke="{color}" stroke-width="{w}" stroke-linecap="round" fill="none"/>'


def circle(c, r, fill, stroke=True, w=W):
    st = f' stroke="{INK}" stroke-width="{w}"' if stroke else ""
    return f'<circle cx="{c[0] + OX:.1f}" cy="{c[1] + OY:.1f}" r="{r}" fill="{fill}"{st}/>'


# ---------------------------------------------------------------- ossa
# name, parent, head (x, y), tail (x, y). Coordinate arte a riposo (posa curva, guarda a destra).
BONES = [
    ("root", None, (0, 0), (0, -20)),
    ("hips", "root", (-8, -74), (-4, -94)),
    ("spine_1", "hips", (-4, -94), (4, -114)),
    ("spine_2", "spine_1", (4, -114), (14, -132)),
    ("spine_3", "spine_2", (14, -132), (24, -146)),
    ("neck", "spine_3", (24, -146), (36, -154)),
    ("head", "neck", (36, -154), (50, -172)),
    ("jaw", "head", (48, -156), (68, -150)),
    ("brow", "head", (50, -172), (64, -170)),
    ("lid", "head", (55, -167), (62, -166)),
    ("tuft_back", "head", (34, -176), (16, -168)),
    ("tuft_front", "head", (46, -184), (60, -188)),
    ("joint", "jaw", (66, -151), (86, -147)),
    ("smoke_1", "joint", (86, -147), (90, -168)),
    ("smoke_2", "smoke_1", (90, -168), (86, -190)),
]
for side, dx, dy in (("R", 0, 0), ("L", -14, -2)):  # R = braccio e gamba vicini, L = lontani
    BONES += [
        (f"clavicle_{side}", "spine_3", (18 + dx, -140 + dy), (26 + dx, -134 + dy)),
        (f"upper_arm_{side}", f"clavicle_{side}", (26 + dx, -134 + dy), (32 + dx, -94 + dy)),
        (f"forearm_{side}", f"upper_arm_{side}", (32 + dx, -94 + dy), (38 + dx, -54 + dy)),
        (f"hand_{side}", f"forearm_{side}", (38 + dx, -54 + dy), (42 + dx, -36 + dy)),
        (f"fingers_{side}", f"hand_{side}", (42 + dx, -36 + dy), (46 + dx, -22 + dy)),
        (f"thumb_{side}", f"hand_{side}", (41 + dx, -47 + dy), (50 + dx, -41 + dy)),
        (f"thigh_{side}", "hips", (-8 + dx, -74), (4 + dx, -42)),
        (f"shin_{side}", f"thigh_{side}", (4 + dx, -42), (-2 + dx, -12)),
        (f"foot_{side}", f"shin_{side}", (-2 + dx, -12), (18 + dx, -3)),
        (f"toes_{side}", f"foot_{side}", (18 + dx, -3), (30 + dx, -2)),
    ]
IK = []
for side, dx, dy in (("R", 0, 0), ("L", -14, -2)):
    IK.append({"chain": [f"upper_arm_{side}", f"forearm_{side}"], "target": f"ik_hand_{side}", "pole": f"pole_arm_{side}", "at": [38 + dx, -54 + dy], "poleAt": [10 + dx, -96 + dy]})
    IK.append({"chain": [f"thigh_{side}", f"shin_{side}"], "target": f"ik_foot_{side}", "pole": f"pole_leg_{side}", "at": [-2 + dx, -12], "poleAt": [40 + dx, -44]})

H = {n: h for n, _, h, _ in BONES}
T = {n: t for n, _, _, t in BONES}

# ---------------------------------------------------------------- pezzi
PIECES = []


def piece(name, bone, z, svg, own=False):
    """own: contorno proprio subito dietro al pezzo (davanti al corpo: braccio e gamba vicini);
    altrimenti il contorno va nel livello d'inchiostro comune dietro a tutto, e nel corpo non si vedono giunture"""
    PIECES.append((name, bone, z, svg, list(_shapes), own))
    _shapes.clear()


def arm_pieces(side, z0):
    f = side == "L"
    own = not f
    fu, fs, rim = far(FUR, f), far(FUR_SH, f), far(RIM, f)
    sk, ss = far(SKIN, f), far(SKIN_SH, f)
    piece(f"upper_arm_{side}", f"upper_arm_{side}", z0, shaded(capsule(H[f"upper_arm_{side}"], T[f"upper_arm_{side}"], 14, 11), fu, fs, rim=rim, furry=7), own)
    piece(f"forearm_{side}", f"forearm_{side}", z0 + 1, shaded(capsule(H[f"forearm_{side}"], T[f"forearm_{side}"], 11.5, 9), fu, fs, rim=rim, furry=6), own)
    piece(f"thumb_{side}", f"thumb_{side}", z0 + 2, shaded(capsule(H[f"thumb_{side}"], T[f"thumb_{side}"], 4.5, 3.8), sk, ss, light=(1, -1)), own)
    piece(f"hand_{side}", f"hand_{side}", z0 + 3, shaded(capsule(H[f"hand_{side}"], T[f"hand_{side}"], 9.5, 10), sk, ss, light=(1.5, -2)), own)
    fx, fy = H[f"fingers_{side}"]
    tx, ty = T[f"fingers_{side}"]
    s = shaded(capsule((fx, fy), (tx, ty), 9.5, 7.5), sk, ss, light=(1.5, -1.5))
    for k in (-4.5, 0.0, 4.5):  # dita
        s += line((fx + k + 1.5, fy + 3), (tx + k * 0.6, ty + 2), INK, 1.5)
    piece(f"fingers_{side}", f"fingers_{side}", z0 + 4, s, own)


def leg_pieces(side, z0):
    f = side == "L"
    own = not f
    fu, fs, rim = far(FUR, f), far(FUR_SH, f), far(RIM, f)
    sk, ss = far(SKIN, f), far(SKIN_SH, f)
    piece(f"thigh_{side}", f"thigh_{side}", z0, shaded(capsule(H[f"thigh_{side}"], T[f"thigh_{side}"], 15, 11), fu, fs, rim=rim, furry=7), own)
    piece(f"shin_{side}", f"shin_{side}", z0 + 1, shaded(capsule(H[f"shin_{side}"], T[f"shin_{side}"], 11, 8), fu, fs, rim=rim, furry=5), own)
    piece(f"foot_{side}", f"foot_{side}", z0 + 2, shaded(capsule(H[f"foot_{side}"], T[f"foot_{side}"], 8.5, 7.5), sk, ss, light=(1.5, -2)), own)
    a, b = H[f"toes_{side}"], T[f"toes_{side}"]
    s = shaded(capsule(a, b, 7, 5.5), sk, ss, light=(1, -1.5))
    s += line((a[0] + 3, a[1] - 3), (b[0] - 1, b[1] - 3), INK, 1.4)
    piece(f"toes_{side}", f"toes_{side}", z0 + 3, s, own)


# lontani dietro al corpo
arm_pieces("L", 0)
leg_pieces("L", 6)
# corpo: segmenti sovrapposti con un solo contorno esterno
# l'ombra sta solo sul dorso (luce orizzontale): così dove i segmenti si sovrappongono non si vedono archi
piece("pelvis", "hips", 20, shaded(ellipse_pts(-6, -80, 24, 20, -10), FUR, FUR_SH, light=(6, 0)))
piece("belly", "spine_1", 21, shaded(ellipse_pts(0, -104, 26, 24, -20), FUR, FUR_SH, light=(6, 0)))
piece("chest", "spine_2", 22, shaded(ellipse_pts(14, -128, 32, 27, -32), FUR, FUR_SH, light=(6, 0)))
piece("shoulders", "spine_3", 23, shaded(ellipse_pts(22, -144, 22, 14, -25), FUR, FUR_SH, light=(4, -2), rim=RIM))
piece("neck", "neck", 24, shaded(capsule(H["neck"], T["neck"], 12, 12), FUR, FUR_SH, rim=RIM))
# gamba vicina davanti al corpo
leg_pieces("R", 30)
# testa: calotta, orecchio, muso, occhio
s = shaded(ellipse_pts(42, -168, 21, 19, -10), FUR, FUR_SH, rim=RIM, furry=8)
s += f'<path d="M{P(32, -184)} Q{P(42, -190)} {P(52, -185)}" stroke="{FUR_SH}" stroke-width="3" fill="none" stroke-linecap="round"/>'  # riga in mezzo
ear = ellipse_pts(33, -164, 6, 7.5)
s += f'<polygon points="{poly(ear)}" fill="{SKIN}" stroke="{INK}" stroke-width="2.2"/>'
s += f'<path d="M{P(32, -167)} Q{P(35, -164)} {P(32, -161)}" stroke="{INK}" stroke-width="1.5" fill="none"/>'
muzzle = ellipse_pts(57, -160, 14, 11, 10)
s += shaded(muzzle, SKIN, SKIN_SH, light=(1.5, -2))
s += f'<polygon points="{poly(muzzle)}" fill="none" stroke="{INK}" stroke-width="2.4"/>'
s += circle((65, -163), 1.8, INK, stroke=False) + circle((61, -164), 1.6, INK, stroke=False)
s += f'<path d="M{P(51, -169)} Q{P(56, -172.5)} {P(61, -169.5)} Q{P(56, -166.5)} {P(51, -169)} Z" fill="#e8dccb" stroke="{INK}" stroke-width="1.8"/>'
s += circle((56.5, -169.3), 2.3, "#3b2416", stroke=False) + circle((57.3, -170.1), 0.8, "#fff", stroke=False)
piece("head", "head", 40, s)
# mascella e labbra rosa
s = shaded(capsule((50, -155), (68, -151), 7, 6), SKIN, SKIN_SH, light=(1, -1.5))
s += f'<path d="M{P(53, -155.5)} Q{P(61, -152)} {P(69, -154)}" stroke="{LIPS}" stroke-width="3.2" fill="none" stroke-linecap="round"/>'
piece("jaw", "jaw", 39, s)
# sopracciglio alzato (spavaldo)
s = f'<path d="M{P(49, -173)} Q{P(57, -179)} {P(65, -174)}" stroke="{INK}" stroke-width="{W + 3.5}" fill="none" stroke-linecap="round"/>'
s += f'<path d="M{P(49, -173)} Q{P(57, -179)} {P(65, -174)}" stroke="{FUR_SH}" stroke-width="3.5" fill="none" stroke-linecap="round"/>'
piece("brow", "brow", 43, s, own=True)
# palpebra: copre metà occhio, si chiude per sbattere
s = f'<path d="M{P(50.5, -169.5)} Q{P(56, -174)} {P(61.5, -169.8)} L{P(61.5, -169)} Q{P(56, -170.6)} {P(50.5, -168.8)} Z" fill="{SKIN}" stroke="{INK}" stroke-width="1.6"/>'
piece("lid", "lid", 42, s, own=True)
# ciuffi ai lati della riga
for nm, base, tip, z in (("tuft_back", (34, -176), (14, -168), 38), ("tuft_front", (46, -184), (62, -189), 44)):
    bx, by = base
    tx, ty = tip
    nx, ny = (ty - by) * 0.3, -(tx - bx) * 0.3
    pts = [(bx - nx, by - ny), ((bx + tx) / 2 - nx * 0.5, (by + ty) / 2 - ny * 0.5), (tx, ty), ((bx + tx) / 2 + nx * 0.5 + 2, (by + ty) / 2 + ny * 0.5 + 2), (bx + nx, by + ny)]
    piece(nm, nm, z, shaded(pts, FUR, FUR_SH, light=(1, -1.5), rim=RIM))
# canna: cono di carta chiara, stretto in bocca e largo in punta, con la piega della carta e la brace arancio
a, b = H["joint"], T["joint"]
s = shaded(capsule(a, b, 2.0, 4.4, n=10), "#efe6d6", "#c9bda8", light=(0.5, -0.9))
mx, my = (a[0] * 0.45 + b[0] * 0.55), (a[1] * 0.45 + b[1] * 0.55)
s += line((mx - 1, my - 2.6), (b[0] - 3, b[1] - 3.6), "#cfc2ac", 1.2)  # piega della carta
s += f'<ellipse cx="{b[0] + OX:.1f}" cy="{b[1] + OY:.1f}" rx="2.6" ry="4.4" transform="rotate({math.degrees(math.atan2(b[1]-a[1], b[0]-a[0])):.1f} {b[0]+OX:.1f} {b[1]+OY:.1f})" fill="#e8743a" stroke="{INK}" stroke-width="1.6"/>'
s += circle((b[0] + 0.6, b[1] - 1.2), 1.5, "#ffd27a", stroke=False)
piece("joint", "joint", 45, s, own=True)
# il fumo non è un pezzo disegnato: è un effetto di particelle che parte dalla punta della canna (rig.json: effects)
# braccio vicino davanti a tutto
arm_pieces("R", 50)

# ---------------------------------------------------------------- export
def render(svg, path):
    doc = f'<svg xmlns="http://www.w3.org/2000/svg" width="{CANVAS}" height="{CANVAS}">{svg}</svg>'
    cairosvg.svg2png(bytestring=doc.encode(), write_to=path)
    return Image.open(path)


pieces_json = []
fills = []
inks = []
for name, bone, z, svg, shapes, own in sorted(PIECES, key=lambda p: p[2]):
    ink_svg = "".join(f'<polygon points="{poly(sh)}" fill="{INK}" stroke="{INK}" stroke-width="{W * 2}" stroke-linejoin="round"/>' for sh in shapes)
    fill_im = render(svg, f"{OUT}/pezzi/_f.png")
    ink_im = render(ink_svg, f"{OUT}/pezzi/_i.png") if shapes else None
    bbox = fill_im.getbbox()
    if ink_im is not None:
        ib = ink_im.getbbox()
        bbox = (min(bbox[0], ib[0]), min(bbox[1], ib[1]), max(bbox[2], ib[2]), max(bbox[3], ib[3]))
    x0, y0, x1, y1 = bbox[0] - 1, bbox[1] - 1, bbox[2] + 1, bbox[3] + 1
    fill_im.crop((x0, y0, x1, y1)).save(f"{OUT}/pezzi/{name}.png")
    entry = {"name": name, "bone": bone, "z": z, "image": f"pezzi/{name}.png", "x": x0 - OX, "y": y0 - OY,
             "width": x1 - x0, "height": y1 - y0}
    if ink_im is not None:
        ink_im.crop((x0, y0, x1, y1)).save(f"{OUT}/pezzi/{name}_ink.png")
        entry["ink"] = f"pezzi/{name}_ink.png"
        entry["inkZ"] = z - 0.5 if own else -100  # contorno proprio o comune
    open(f"{OUT}/pezzi/{name}.svg", "w").write(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{x1 - x0}" height="{y1 - y0}"><g transform="translate({-x0},{-y0})">{ink_svg if own else ""}{svg}</g></svg>\n')
    pieces_json.append(entry)
    fills.append((z, svg))
    if ink_svg:
        inks.append((z - 0.5 if own else -100, ink_svg))
for f in ("_f.png", "_i.png"):
    if os.path.exists(f"{OUT}/pezzi/{f}"):
        os.remove(f"{OUT}/pezzi/{f}")

bones_json = []
for name, parent, head, tail in BONES:
    bones_json.append({"name": name, "parent": parent, "head": list(head), "tail": list(tail), "deform": True})
for ik in IK:
    bones_json.append({"name": ik["target"], "parent": "root", "head": ik["at"], "tail": [ik["at"][0] + 8, ik["at"][1]], "deform": False})
    bones_json.append({"name": ik["pole"], "parent": "root", "head": ik["poleAt"], "tail": [ik["poleAt"][0] + 6, ik["poleAt"][1]], "deform": False})

rig = {
    "effects": [{"type": "smoke", "bone": "joint", "at": "tail"}],  # fumo della canna, fatto da chi disegna (Godot, Blender)
    "character": "bonobot",
    "version": 2,
    "units": "pixel a 2x, origine ai piedi al centro, y in giù, guarda a destra",
    "scale": 0.5,
    "bones": bones_json,
    "ik": [{"chain": i["chain"], "target": i["target"], "pole": i["pole"]} for i in IK],
    "pieces": pieces_json,
}
json.dump(rig, open(f"{OUT}/rig.json", "w"), indent=2, ensure_ascii=False)

# tavola: Bonobot montato (grande), lo scheletro sopra, e i pezzi separati
layers = sorted(fills + inks, key=lambda l: l[0])
full = "".join(l[1] for l in layers)
bones_svg = ""
for name, parent, head, tail in BONES:
    col = "#ff4f8b" if name.endswith("_L") else "#29d3ff"
    bones_svg += line(head, tail, col, 2.2) + circle(head, 2.4, col, stroke=False)
Z = 2.2
doc = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{int(CANVAS * Z * 2)}" height="{int(CANVAS * Z * 0.62)}">'
       f'<rect width="100%" height="100%" fill="#6f8796"/>'
       f'<g transform="translate({-CANVAS * Z * 0.02},{-CANVAS * Z * 0.25}) scale({Z})">{full}</g>'
       f'<g transform="translate({CANVAS * Z * 0.98},{-CANVAS * Z * 0.25}) scale({Z})"><g opacity="0.3">{full}</g>{bones_svg}</g></svg>')
cairosvg.svg2png(bytestring=doc.encode(), write_to=f"{OUT}/tavola.png")
print(len([b for b in bones_json if b["deform"]]), "ossa che deformano,", len(bones_json), "in tutto,", len(pieces_json), "pezzi")
