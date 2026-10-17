# Uso: python3 tools/rig/genera_pezzi_lottatore.py <id> [<id>...]   (servono cairosvg e Pillow)
# Pezzi provvisori, disegnati col codice, dei lottatori della community (#13) sullo scheletro di Bonobot (#195):
# stesse ossa e stessi nomi dei pezzi, così le animazioni di tools/rig/animazioni_lottatore.py valgono per tutti.
# Ogni lottatore è un LOOK qui sotto: colori dalla sua scheda e qualche dettaglio (capelli, occhiali, collane...).
# Scrive public/assets/characters/<id>/rig/rig.json e rig/pezzi/*.png. I pezzi veri si ridisegnano in Krita
# come spiega docs/scheletro.md, con la stessa misura e lo stesso perno.
import json, math, os, sys
import cairosvg
from PIL import Image

INK = "#1f1714"
W = 3.2  # inchiostro ~3 px a 2x
PAD = 10  # margine trasparente attorno a ogni pezzo
CANVAS = 420
OX, OY = 210, 330
BONOBOT = "public/assets/characters/bonobot/rig/rig.json"

# Colori e dettagli di ogni lottatore. skin/hair/top/bottom/shoes: (base, ombra). hands: guanti o pelle.
# sleeves: "long" (braccio coperto fino al polso) o "short"; shorts: gambe nude sotto i pantaloncini.
LOOKS = {
    # Baldo: grosso, rossiccio rasato, trasandato ma quasi elegante, guanti da portiere (scheda: verde, marrone, rosso)
    "lampione": dict(skin=("#f0c3a0", "#d39a78"), hair=("#c4602f", "#9a4520"), top=("#4f6b3a", "#38502a"),
                     bottom=("#6b4a30", "#4f3622"), shoes=("#3a2a20", "#271c15"), hands=("#e9ec3c", "#b9bd1f"),
                     sleeves="long", hairstyle="buzz", stubble=True, tie="#c0392b", bulk=1.12),
    # Giovanni: bradipo giallo piccoletto, chiacchierone, suona il basso (scheda e #335: #f5c211)
    "bradipo": dict(skin=("#f5c211", "#c99a0a"), fur=True, mask="#fbe7a6", hands=("#5a4632", "#3e3022"),
                    hairstyle="sloth", bulk=0.95),
    # Riccardo: spilungone calciatore, occhiali e capelli a tendina
    "giovannifrana": dict(skin=("#f1c9a8", "#d6a583"), hair=("#6b4a2f", "#4c331f"), top=("#2f7bd6", "#1f5aa3"),
                          bottom=("#f2f2f2", "#c9c9c9"), shoes=("#222222", "#111111"), socks="#2f7bd6",
                          sleeves="short", shorts=True, hairstyle="curtain", glasses=True, number="9", bulk=0.92),
    # Marco: felpa, occhiali, barba e pelato (scheda: nero, rosso e giallo, comunismo)
    "marcomunista": dict(skin=("#efc19b", "#d19c76"), hair=("#4a3428", "#33241b"), top=("#26232a", "#151317"),
                         bottom=("#3b3f4a", "#2a2d35"), shoes=("#b22222", "#861818"), sleeves="long",
                         hairstyle="bald", beard=True, glasses=True, star=True, hood=True),
    # Michele: magro, un po' emo, tutto nero
    "lendmar": dict(skin=("#f3dccb", "#d9bba6"), hair=("#17151a", "#0a090b"), top=("#2b2930", "#18171b"),
                    bottom=("#1e1d22", "#111014"), shoes=("#3a3a40", "#26262a"), sleeves="long",
                    hairstyle="emo", bulk=0.86, eyeliner=True),
    # Gio: chirurgo rasta infettato dai funghi (scheda: bianco, rosso, arancio/marrone, rosa)
    "drmicelium": dict(skin=("#c98f62", "#a46f48"), hair=("#8a5a2b", "#653f1c"), top=("#f4f1ea", "#cfc8ba"),
                       bottom=("#5f7b8a", "#455b66"), shoes=("#3a2e29", "#241b18"), sleeves="long",
                       hairstyle="dreads", coat=True, blood=True, mushrooms=True, joint=True),
    # Griga: l'allenatore alto e muscoloso, afro, tuta verde e gialla, collane d'oro
    "coachcartier": dict(skin=("#6b4630", "#4e3322"), hair=("#1c1512", "#0e0a08"), top=("#1f8a4c", "#156337"),
                         bottom=("#1f8a4c", "#156337"), shoes=("#f4f4f4", "#cfcfcf"), stripe="#f2d02e",
                         sleeves="long", hairstyle="afro", chains=True, bulk=1.08),
}


# Trasformazione dei disegni: testa e decorazioni del busto si disegnano nelle coordinate di Bonobot e si portano
# al loro posto sullo scheletro umano (spostate e ingrandite attorno a un perno)
XF = [None]


def tf(x, y):
    if XF[0] is None:
        return x, y
    (bx, by), (hx, hy), k = XF[0]
    return hx + (x - bx) * k, hy + (y - by) * k


def sc(r):
    return r * (XF[0][2] if XF[0] else 1.0)


def P(x, y):
    x, y = tf(x, y)
    return f"{x + OX:.1f},{y + OY:.1f}"


def capsule(a, b, r1, r2, n=14):
    """Poligono di una capsula rastremata da a (raggio r1) a b (raggio r2)."""
    ax, ay = a
    bx, by = b
    ang = math.atan2(by - ay, bx - ax)
    pts = []
    for i in range(n + 1):
        t = ang - math.pi / 2 + math.pi * i / n
        pts.append((bx + math.cos(t) * r2, by + math.sin(t) * r2))
    for i in range(n + 1):
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


def darker(hexcol, k=0.82):
    r, g, b = (int(hexcol[i:i + 2], 16) for i in (1, 3, 5))
    return "#%02x%02x%02x" % (int(r * k), int(g * k), int(b * k))


class Disegno:
    """I pezzi di un lottatore: forme a due toni, con le sagome raccolte per il livello d'inchiostro."""

    def __init__(self):
        self.uid = 0
        self.shapes = []
        self.pieces = []

    def shaded(self, pts, base, shade, light=(3.0, -3.5), furry=0, outline=True):
        self.uid += 1
        cid = f"c{self.uid}"
        lx, ly = light
        pl = poly(pts)
        shifted = poly([(x + lx, y + ly) for x, y in pts])
        s = f'<clipPath id="{cid}"><polygon points="{pl}"/></clipPath>'
        s += f'<polygon points="{pl}" fill="{shade}"/>'
        s += f'<polygon clip-path="url(#{cid})" points="{shifted}" fill="{base}"/>'
        if furry:
            s += fur_strands(pts, shade, furry)
        if outline:
            self.shapes.append([tf(x, y) for x, y in pts])
        return s

    def piece(self, name, bone, z, svg, own=False):
        self.pieces.append((name, bone, z, svg, list(self.shapes), own))
        self.shapes.clear()


def fur_strands(pts, color, n):
    s = ""
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    step = max(1, len(pts) // n)
    for i in range(0, len(pts), step):
        x, y = pts[i]
        if x - cx > 4 and y - cy < -4:
            continue
        dx, dy = cx - x, cy - y
        d = math.hypot(dx, dy) or 1
        s += f'<path d="M{P(x, y)} L{P(x + dx / d * 7, y + dy / d * 7)}" stroke="{color}" stroke-width="2" stroke-linecap="round"/>'
    return s


def line(a, b, color, w):
    return f'<path d="M{P(*a)} L{P(*b)}" stroke="{color}" stroke-width="{w}" stroke-linecap="round" fill="none"/>'


def circle(c, r, fill, stroke=True, w=W):
    st = f' stroke="{INK}" stroke-width="{w}"' if stroke else ""
    x, y = tf(*c)
    return f'<circle cx="{x + OX:.1f}" cy="{y + OY:.1f}" r="{sc(r):.2f}" fill="{fill}"{st}/>'


def path(d, stroke=INK, w=2.0, fill="none"):
    return f'<path d="{d}" stroke="{stroke}" stroke-width="{w}" fill="{fill}" stroke-linecap="round" stroke-linejoin="round"/>'


# Lo scheletro umano: le stesse ossa di Bonobot (così valgono le sue animazioni), ma in piedi, con le gambe
# più lunghe, le braccia più corte e la testa più grande. Testa e faccia sono quelle di Bonobot portate qui da HEAD
HEAD = ((36, -154), (14, -160), 1.15)  # perno della testa di Bonobot, dove va sull'umano, ingrandimento
CHEST = ((14, -128), (6, -134), 0.7)  # decorazioni del petto (cravatta, stella, numero...)
SHOULDERS = ((22, -144), (9, -150), 0.75)
HEAD_BONES = ("jaw", "brow", "lid", "tuft_back", "tuft_front", "joint", "smoke_1", "smoke_2")


def human_bones(base):
    def at(p, xf):
        (bx, by), (hx, hy), k = xf
        return [round(hx + (p[0] - bx) * k, 2), round(hy + (p[1] - by) * k, 2)]

    pos = {
        "root": ((0, 0), (0, -20)), "hips": ((-2, -92), (0, -110)), "spine_1": ((0, -110), (3, -124)),
        "spine_2": ((3, -124), (6, -138)), "spine_3": ((6, -138), (9, -150)), "neck": ((9, -150), (14, -160)),
        "head": ((14, -160), (24, -182)),
    }
    for side, dx, dy in (("R", 0, 0), ("L", -10, -2)):
        pos.update({
            f"clavicle_{side}": ((6 + dx, -146 + dy), (12 + dx, -142 + dy)),
            f"upper_arm_{side}": ((12 + dx, -142 + dy), (16 + dx, -112 + dy)),
            f"forearm_{side}": ((16 + dx, -112 + dy), (20 + dx, -84 + dy)),
            f"hand_{side}": ((20 + dx, -84 + dy), (22 + dx, -72 + dy)),
            f"fingers_{side}": ((22 + dx, -72 + dy), (24 + dx, -62 + dy)),
            f"thumb_{side}": ((21 + dx, -79 + dy), (28 + dx, -74 + dy)),
            f"thigh_{side}": ((-2 + dx, -92), (2 + dx, -50)),
            f"shin_{side}": ((2 + dx, -50), (0 + dx, -12)),
            f"foot_{side}": ((0 + dx, -12), (16 + dx, -3)),
            f"toes_{side}": ((16 + dx, -3), (26 + dx, -2)),
            f"ik_hand_{side}": ((22 + dx, -72 + dy), (30 + dx, -72 + dy)),
            f"pole_arm_{side}": ((-12 + dx, -112 + dy), (-6 + dx, -112 + dy)),
            f"ik_foot_{side}": ((0 + dx, -12), (8 + dx, -12)),
            f"pole_leg_{side}": ((40 + dx, -50), (46 + dx, -50)),
        })
    out = []
    for b in base:
        b = dict(b)
        if b["name"] in pos:
            b["head"], b["tail"] = [list(v) for v in pos[b["name"]]]
        elif b["name"] in HEAD_BONES:
            b["head"], b["tail"] = at(b["head"], HEAD), at(b["tail"], HEAD)
        else:
            raise SystemExit(f"osso senza posizione umana: {b['name']}")
        out.append(b)
    return out


def genera(cid):
    L = LOOKS[cid]
    out = f"public/assets/characters/{cid}/rig"
    os.makedirs(f"{out}/pezzi", exist_ok=True)
    base_rig = json.load(open(BONOBOT, encoding="utf-8"))
    bones = {b["name"]: b for b in human_bones(base_rig["bones"])}
    H = {n: tuple(b["head"]) for n, b in bones.items()}
    T = {n: tuple(b["tail"]) for n, b in bones.items()}
    k = L.get("bulk", 1.0)  # grossezza di busto e arti
    fur = L.get("fur", False)
    skin, skin_sh = L["skin"]
    top, top_sh = L.get("top", L["skin"])
    bot, bot_sh = L.get("bottom", L["skin"])
    sho, sho_sh = L.get("shoes", L["skin"])
    hand, hand_sh = L.get("hands", L["skin"])
    hair, hair_sh = L.get("hair", L["skin"])
    d = Disegno()

    def far(c, is_far):
        return darker(c) if is_far else c

    def arm(side, z0):
        f = side == "L"
        own = not f
        sleeve = L.get("sleeves", "long")
        up_c = far(top, f), far(top_sh, f)
        lo_c = up_c if sleeve == "long" else (far(skin, f), far(skin_sh, f))
        hd = far(hand, f), far(hand_sh, f)
        furry = 6 if fur else 0
        s = d.shaded(capsule(H[f"upper_arm_{side}"], T[f"upper_arm_{side}"], 9.5 * k, 8 * k), *up_c, furry=furry)
        if L.get("stripe"):
            a, b = H[f"upper_arm_{side}"], T[f"upper_arm_{side}"]
            s += line((a[0] + 7 * k, a[1] + 4), (b[0] + 6 * k, b[1] - 2), far(L["stripe"], f), 3)
        if L.get("coat") and L.get("blood") and not f:
            s += circle((H[f"upper_arm_{side}"][0] + 6, H[f"upper_arm_{side}"][1] + 16), 2.6, "#b3261e", stroke=False)
        d.piece(f"upper_arm_{side}", f"upper_arm_{side}", z0, s, own)
        s = d.shaded(capsule(H[f"forearm_{side}"], T[f"forearm_{side}"], 8 * k, 6.8 * k), *lo_c, furry=furry)
        if L.get("stripe"):
            a, b = H[f"forearm_{side}"], T[f"forearm_{side}"]
            s += line((a[0] + 5.5 * k, a[1] + 2), (b[0] + 5 * k, b[1] - 4), far(L["stripe"], f), 3)
        if sleeve == "long" and not fur:  # polsino
            a, b = H[f"forearm_{side}"], T[f"forearm_{side}"]
            ang = math.atan2(b[1] - a[1], b[0] - a[0])
            cx, cy = b[0] - math.cos(ang) * 5, b[1] - math.sin(ang) * 5
            nx, ny = -math.sin(ang) * 6.8 * k, math.cos(ang) * 6.8 * k
            s += line((cx - nx, cy - ny), (cx + nx, cy + ny), far(top_sh, f), 3)
        d.piece(f"forearm_{side}", f"forearm_{side}", z0 + 1, s, own)
        d.piece(f"thumb_{side}", f"thumb_{side}", z0 + 2, d.shaded(capsule(H[f"thumb_{side}"], T[f"thumb_{side}"], 3.6, 3.0), *hd, light=(1, -1)), own)
        d.piece(f"hand_{side}", f"hand_{side}", z0 + 3, d.shaded(capsule(H[f"hand_{side}"], T[f"hand_{side}"], 7.0, 7.5), *hd, light=(1.5, -2)), own)
        fx, fy = H[f"fingers_{side}"]
        tx, ty = T[f"fingers_{side}"]
        s = d.shaded(capsule((fx, fy), (tx, ty), 7.0, 5.5), *hd, light=(1.5, -1.5))
        for kk in (-3.5, 0.0, 3.5):
            s += line((fx + kk + 1.5, fy + 3), (tx + kk * 0.6, ty + 2), INK if not fur else "#2a1f16", 1.5)
        d.piece(f"fingers_{side}", f"fingers_{side}", z0 + 4, s, own)

    def leg(side, z0):
        f = side == "L"
        own = not f
        pants = far(bot, f), far(bot_sh, f)
        furry = 6 if fur else 0
        shin_c = (far(skin, f), far(skin_sh, f)) if L.get("shorts") else pants
        s = d.shaded(capsule(H[f"thigh_{side}"], T[f"thigh_{side}"], 11.5 * k, 9 * k), *pants, furry=furry)
        if L.get("stripe"):
            a, b = H[f"thigh_{side}"], T[f"thigh_{side}"]
            s += line((a[0] + 8.5 * k, a[1] + 6), (b[0] + 7 * k, b[1] - 2), far(L["stripe"], f), 3)
        d.piece(f"thigh_{side}", f"thigh_{side}", z0, s, own)
        s = d.shaded(capsule(H[f"shin_{side}"], T[f"shin_{side}"], 9 * k, 7 * k), *shin_c, furry=furry)
        if L.get("socks"):  # calzettoni fin sotto il ginocchio
            a, b = H[f"shin_{side}"], T[f"shin_{side}"]
            mid = (a[0] * 0.45 + b[0] * 0.55, a[1] * 0.45 + b[1] * 0.55)
            s += d.shaded(capsule(mid, b, 7.6 * k, 7 * k), far(L["socks"], f), far(darker(L["socks"]), f), outline=False)
        if L.get("stripe"):
            a, b = H[f"shin_{side}"], T[f"shin_{side}"]
            s += line((a[0] + 7 * k, a[1] + 2), (b[0] + 5.5 * k, b[1] - 4), far(L["stripe"], f), 3)
        d.piece(f"shin_{side}", f"shin_{side}", z0 + 1, s, own)
        sh = (far(hand, f), far(hand_sh, f)) if fur else (far(sho, f), far(sho_sh, f))
        d.piece(f"foot_{side}", f"foot_{side}", z0 + 2, d.shaded(capsule(H[f"foot_{side}"], T[f"foot_{side}"], 7.5, 7), *sh, light=(1.5, -2)), own)
        a, b = H[f"toes_{side}"], T[f"toes_{side}"]
        s = d.shaded(capsule(a, b, 6.5, 5), *sh, light=(1, -1.5))
        s += line((a[0] - 2, a[1] + 4), (b[0] + 4, b[1] + 4), darker(sh[1], 0.7), 2)  # suola
        d.piece(f"toes_{side}", f"toes_{side}", z0 + 3, s, own)

    # lontani dietro al corpo
    arm("L", 0)
    leg("L", 6)
    # corpo: bacino coi pantaloni, pancia e petto con la maglia; ombra solo sul dorso
    furry = 8 if fur else 0
    d.piece("pelvis", "hips", 20, d.shaded(ellipse_pts(-2, -96, 18.5 * k, 15, -5), bot, bot_sh, light=(5, 0), furry=furry))
    d.piece("belly", "spine_1", 21, d.shaded(ellipse_pts(1, -113, 18.5 * k, 14, -8), top, top_sh, light=(5, 0), furry=furry))
    s = d.shaded(ellipse_pts(5, -132, 22 * k, 17, -12), top, top_sh, light=(5, 0), furry=furry)
    XF[0] = CHEST
    if L.get("coat"):  # bavero del camice e taschino
        s += path(f"M{P(26, -146)} L{P(30, -126)} L{P(22, -112)}", INK, 1.8)
        s += path(f"M{P(18, -122)} L{P(30, -122)} L{P(29, -114)} L{P(19, -114)} Z", "#bdb5a6", 1.6)
        if L.get("blood"):
            for c, r in (((34, -118), 4.0), ((28, -108), 2.6), ((38, -132), 2.2)):
                s += circle(c, r, "#b3261e", stroke=False)
    if L.get("star"):
        cx, cy, r = 30, -124, 9
        pts = []
        for i in range(10):
            a = -math.pi / 2 + i * math.pi / 5
            rr = r if i % 2 == 0 else r * 0.42
            pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
        s += f'<polygon points="{poly(pts)}" fill="#d62828" stroke="#f2c12e" stroke-width="1.6"/>'
    if L.get("number"):
        tx, ty = tf(14, -118)
        s += f'<text x="{tx + OX:.1f}" y="{ty + OY:.1f}" font-family="DejaVu Sans" font-weight="bold" font-size="{sc(20):.1f}" fill="#ffffff" stroke="{INK}" stroke-width="1">{L["number"]}</text>'
    if L.get("tie"):
        s += f'<polygon points="{poly([(30, -144), (35, -144), (36, -122), (32, -116), (28, -122)])}" fill="{L["tie"]}" stroke="{INK}" stroke-width="1.5"/>'
    if L.get("stripe"):
        s += path(f"M{P(30, -146)} L{P(26, -104)}", L["stripe"], 3)  # zip della giacca
    XF[0] = None
    d.piece("chest", "spine_2", 22, s)
    s = d.shaded(ellipse_pts(8, -146, 18.5 * k, 10, -15), top, top_sh, light=(3, -2), furry=furry)
    XF[0] = SHOULDERS
    if L.get("hood"):
        s += d.shaded(ellipse_pts(14, -150, 13, 9, -20), top_sh, darker(top_sh), light=(2, -1))
    if L.get("chains"):  # collane d'oro
        s += path(f"M{P(20, -150)} Q{P(32, -128)} {P(42, -146)}", "#e6b422", 3.2)
        s += path(f"M{P(18, -150)} Q{P(32, -118)} {P(44, -146)}", "#f2d04a", 2.6)
        s += circle((32, -122), 4.2, "#f2d04a", w=1.4)
    XF[0] = None
    d.piece("shoulders", "spine_3", 23, s)
    neck_c = (skin, skin_sh)
    d.piece("neck", "neck", 24, d.shaded(capsule(H["neck"], T["neck"], 7.5, 7.5), *neck_c, furry=4 if fur else 0))
    # gamba vicina davanti al corpo
    leg("R", 30)

    # testa: tonda e un po' più alta di quella di Bonobot, il naso al posto del muso
    XF[0] = HEAD
    hx, hy = 45, -170
    style = L.get("hairstyle")
    if fur:  # bradipo: testa tonda col pelo, maschera chiara e le macchie scure degli occhi
        s = d.shaded(ellipse_pts(hx, hy, 21, 19, -8), skin, skin_sh, furry=10)
        s += f'<polygon points="{poly(ellipse_pts(53, -168, 14, 11, 8))}" fill="{L["mask"]}"/>'
        s += f'<polygon points="{poly(ellipse_pts(55, -171, 7.5, 4.2, 25))}" fill="#5a4632"/>'
        s += circle((57, -171.5), 2.6, "#1a120c", stroke=False) + circle((57.8, -172.3), 0.9, "#fff", stroke=False)
        s += f'<polygon points="{poly(ellipse_pts(64.5, -165, 3.6, 2.6))}" fill="#3a2a1d"/>'
    else:
        s = d.shaded(ellipse_pts(hx, hy, 18, 20, -6), skin, skin_sh)
        s += f'<polygon points="{poly(ellipse_pts(34, -168, 4.5, 6.5))}" fill="{skin}" stroke="{INK}" stroke-width="2"/>'  # orecchio
        s += path(f"M{P(33.5, -170)} Q{P(36, -168)} {P(33.5, -165.5)}", INK, 1.3)
        nose = [(59, -175), (66, -164), (60, -162.5)]
        s += f'<polygon points="{poly(nose)}" fill="{skin_sh}" stroke="{INK}" stroke-width="1.8" stroke-linejoin="round"/>'
        s += f'<path d="M{P(51, -174)} Q{P(55.5, -177.5)} {P(60, -174.3)} Q{P(55.5, -171.5)} {P(51, -174)} Z" fill="#f4efe6" stroke="{INK}" stroke-width="1.7"/>'
        s += circle((56, -174.2), 2.2, "#3b2416", stroke=False) + circle((56.8, -175), 0.8, "#fff", stroke=False)
        if L.get("eyeliner"):
            s += path(f"M{P(50, -174)} Q{P(55.5, -178.6)} {P(61, -174.6)}", "#0a090b", 2.4)
        if L.get("stubble"):
            s += f'<polygon points="{poly(ellipse_pts(50, -160, 12, 6, 15))}" fill="{hair_sh}" opacity="0.35"/>'
        if style == "buzz":  # rasato rossiccio: una calotta corta
            s += f'<path d="M{P(28, -170)} Q{P(30, -192)} {P(48, -191)} Q{P(60, -189)} {P(61, -180)} Q{P(48, -184)} {P(36, -178)} Q{P(32, -172)} {P(28, -170)} Z" fill="{hair}" opacity="0.85"/>'
            s += path(f"M{P(36, -186)} L{P(38, -183)} M{P(44, -188)} L{P(45, -185)} M{P(52, -187)} L{P(52, -184)}", hair_sh, 1.4)
        if style == "bald":
            s += path(f"M{P(46, -188)} Q{P(54, -188)} {P(57, -183)}", "#ffffff", 2.4)  # luce sulla pelata
        if style in ("curtain", "emo", "dreads", "afro"):
            s += f'<path d="M{P(27, -168)} Q{P(26, -192)} {P(46, -192)} Q{P(62, -191)} {P(62, -180)} L{P(50, -182)} Q{P(38, -182)} {P(33, -172)} Z" fill="{hair}" stroke="{INK}" stroke-width="2"/>'
    d.piece("head", "head", 40, s)

    # mascella: bocca (e barba)
    if fur:
        s = d.shaded(capsule((52, -158), (64, -157), 6.5, 5.5), L["mask"], darker(L["mask"]), light=(1, -1.5))
        s += path(f"M{P(55, -158)} Q{P(60, -154)} {P(65, -158)}", "#3a2a1d", 2.2)
    else:
        s = d.shaded(capsule((48, -157), (60, -156), 7.5, 6.5), skin, skin_sh, light=(1, -1.5))
        if L.get("beard"):
            s += d.shaded(capsule((42, -158), (60, -153), 10, 8), hair, hair_sh, light=(1.5, -1.5))
        s += path(f"M{P(53, -158)} Q{P(58, -155.5)} {P(62, -158.5)}", "#7a3b2e", 2.4)
    d.piece("jaw", "jaw", 39, s)
    # sopracciglio e palpebra
    bc = L["hair"][1] if "hair" in L else "#3a2a1d"
    s = path(f"M{P(50, -179)} Q{P(56, -182)} {P(62, -178.5)}", INK, W + 3)
    s += path(f"M{P(50, -179)} Q{P(56, -182)} {P(62, -178.5)}", bc, 3)
    d.piece("brow", "brow", 43, s, own=True)
    lidc = L["mask"] if fur else skin
    s = f'<path d="M{P(50.5, -174)} Q{P(55.5, -178.4)} {P(60.5, -174.4)} L{P(60.5, -173.6)} Q{P(55.5, -175)} {P(50.5, -173.4)} Z" fill="{lidc}" stroke="{INK}" stroke-width="1.5"/>'
    d.piece("lid", "lid", 42, s, own=True)
    if L.get("glasses"):  # gli occhiali stanno sulla palpebra, che segue la testa
        d.pieces[-1] = ("lid", "lid", 42, s + f'<polygon points="{poly([(48, -179.5), (63, -179.5), (63, -168.5), (48, -168.5)])}" fill="#ffffff" fill-opacity="0.18" stroke="{INK}" stroke-width="2.4" stroke-linejoin="round"/>'
                        + line((48, -175), (36, -173), INK, 2.2), [], True)

    # ciuffi: capelli che seguono i movimenti in ritardo
    def tuft(nm, z, pts, c=hair, cs=hair_sh, own=False):
        d.piece(nm, nm, z, d.shaded(pts, c, cs, light=(1, -1.5)), own)

    if style == "curtain":  # capelli a tendina con la riga in mezzo
        tuft("tuft_back", 38, [(30, -190), (40, -194), (36, -176), (28, -164), (24, -172)])
        tuft("tuft_front", 44, [(44, -194), (58, -192), (64, -184), (60, -174), (54, -184), (46, -186)])
    elif style == "emo":  # frangia lunga che copre mezza faccia
        tuft("tuft_back", 38, [(28, -192), (42, -196), (34, -176), (26, -158), (22, -172)])
        tuft("tuft_front", 44, [(40, -196), (58, -194), (66, -182), (62, -166), (56, -172), (52, -182), (44, -186)])
    elif style == "dreads":  # dreadlock lunghi dietro e una ciocca davanti
        s = ""
        for i, (x0, y0, x1, y1) in enumerate(((34, -190, 18, -150), (30, -184, 14, -158), (40, -192, 26, -146), (28, -178, 12, -166))):
            s += d.shaded(capsule((x0, y0), (x1, y1), 4.8, 4.0, n=8), hair if i % 2 else darker(hair, 0.9), hair_sh)
            if L.get("mushrooms") and i == 2:
                s += f'<polygon points="{poly(ellipse_pts(x1 + 1, y1 + 2, 6, 3.5))}" fill="#e46c8c" stroke="{INK}" stroke-width="1.4"/>'
        d.piece("tuft_back", "tuft_back", 38, s)
        s = d.shaded(capsule((50, -192), (62, -178), 4.6, 3.8, n=8), hair, hair_sh)
        if L.get("mushrooms"):  # funghetti sulla testa
            s += path(f"M{P(44, -192)} L{P(44, -198)}", "#f4efe6", 3)
            s += f'<path d="M{P(37, -197)} Q{P(44, -208)} {P(51, -197)} Z" fill="#d94b4b" stroke="{INK}" stroke-width="1.6"/>'
            s += circle((42, -200), 1.3, "#ffffff", stroke=False) + circle((46.5, -199), 1.0, "#ffffff", stroke=False)
        d.piece("tuft_front", "tuft_front", 44, s)
    elif style == "afro":
        tuft("tuft_back", 38, ellipse_pts(36, -186, 20, 18))
        tuft("tuft_front", 44, ellipse_pts(50, -194, 17, 13))
    elif style == "sloth":  # ciuffi di pelo in testa
        tuft("tuft_back", 38, [(30, -184), (38, -192), (36, -180), (26, -176)], skin, skin_sh)
        tuft("tuft_front", 44, [(44, -190), (54, -194), (50, -184)], skin, skin_sh)
    else:  # rasati e pelati: nessun ciuffo, ma l'osso c'è lo stesso
        s = f'<circle cx="{H["tuft_back"][0] + OX}" cy="{H["tuft_back"][1] + OY}" r="0.1" fill="none"/>'
        d.piece("tuft_back", "tuft_back", 38, s)
        d.piece("tuft_front", "tuft_front", 44, s)
    if L.get("joint"):  # la canna, come quella di Bonobot (il fumo è un effetto)
        a, b = (66, -151), (86, -147)  # coordinate di Bonobot: le porta al posto giusto HEAD
        s = d.shaded(capsule(a, b, 2.0, 4.4, n=10), "#efe6d6", "#c9bda8", light=(0.5, -0.9))
        s += circle(b, 3.4, "#e8743a", w=1.6) + circle((b[0] + 0.6, b[1] - 1.2), 1.5, "#ffd27a", stroke=False)
        d.piece("joint", "joint", 45, s, own=True)
    XF[0] = None
    if fur:  # il basso a tracolla, dietro la schiena
        s = d.shaded([(-16, -146), (-4, -150), (-2, -104), (-10, -96), (-20, -104)], "#b5523b", "#8a3b2a", light=(2, -2))
        s += line((-8, -150), (-10, -186), "#3a2a1d", 4)
        d.piece("bass", "spine_2", 19, s)
    # braccio vicino davanti a tutto
    arm("R", 50)

    # ---------------------------------------------------------------- export
    def render(svg, p):
        doc = f'<svg xmlns="http://www.w3.org/2000/svg" width="{CANVAS}" height="{CANVAS}">{svg}</svg>'
        cairosvg.svg2png(bytestring=doc.encode(), write_to=p)
        return Image.open(p)

    for f in os.listdir(f"{out}/pezzi"):
        os.remove(f"{out}/pezzi/{f}")
    pieces_json = []
    for name, bone, z, svg, shapes, own in sorted(d.pieces, key=lambda p: p[2]):
        ink_svg = "".join(f'<polygon points="{poly(sh)}" fill="{INK}" stroke="{INK}" stroke-width="{W * 2}" stroke-linejoin="round"/>' for sh in shapes)
        fill_im = render(svg, f"{out}/pezzi/_f.png")
        ink_im = render(ink_svg, f"{out}/pezzi/_i.png") if shapes else None
        bbox = fill_im.getbbox() or (OX, OY, OX + 1, OY + 1)
        if ink_im is not None and ink_im.getbbox():
            ib = ink_im.getbbox()
            bbox = (min(bbox[0], ib[0]), min(bbox[1], ib[1]), max(bbox[2], ib[2]), max(bbox[3], ib[3]))
        x0, y0, x1, y1 = bbox[0] - PAD, bbox[1] - PAD, bbox[2] + PAD, bbox[3] + PAD
        fill_im.crop((x0, y0, x1, y1)).save(f"{out}/pezzi/{name}.png", optimize=True)
        entry = {"name": name, "bone": bone, "z": z, "image": f"pezzi/{name}.png", "x": x0 - OX, "y": y0 - OY,
                 "width": x1 - x0, "height": y1 - y0}
        if ink_im is not None:
            ink_im.crop((x0, y0, x1, y1)).save(f"{out}/pezzi/{name}_ink.png", optimize=True)
            entry["ink"] = f"pezzi/{name}_ink.png"
            entry["inkZ"] = z - 0.5 if own else -100
        pieces_json.append(entry)
    for f in ("_f.png", "_i.png"):
        if os.path.exists(f"{out}/pezzi/{f}"):
            os.remove(f"{out}/pezzi/{f}")
    rig = {
        "character": cid,
        "version": 2,
        "units": base_rig["units"],
        "scale": base_rig["scale"],
        "bones": list(bones.values()),
        "ik": base_rig["ik"],
        "pieces": pieces_json,
    }
    if L.get("joint"):
        rig["effects"] = [{"type": "smoke", "bone": "joint", "at": "tail"}]
    rig["portrait"] = [6, -22]  # la testa umana sta più in alto di quella di Bonobot
    json.dump(rig, open(f"{out}/rig.json", "w"), indent=2, ensure_ascii=False)
    print(cid, len(pieces_json), "pezzi")


if __name__ == "__main__":
    for cid in sys.argv[1:] or LOOKS:
        genera(cid)
