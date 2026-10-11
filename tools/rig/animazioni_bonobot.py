# Uso: python3 tools/rig/animazioni_bonobot.py [cartella del rig]
# Le animazioni di Bonobot sullo scheletro nuovo (#195, E7 passo 4). Scrive <rig>/animazioni.json: una chiave
# per fotogramma, con i gradi di ogni osso rispetto al riposo e lo spostamento della radice (pixel a 2x).
# Poi tools/rig/rendi_sprite.py ne fa un PNG per stato.
#
# Fermo, schiaffo e martello vengono dalla prova dello scheletro in Godot (#198), la corsa dal suo scatto
# (galoppo sulle nocche con le IK, rifatto alla velocità della camminata). Le altre sono quelle dello
# spritesheet di prima, portate sulle ossa nuove, più atterraggio e provocazione.
import json, math, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scheletro import Scheletro

RIG = sys.argv[1] if len(sys.argv) > 1 else "public/assets/characters/bonobot/rig"
sk = Scheletro(RIG)
TAU = math.tau
s = math.sin

FPS = 24
FRAME = (336, 368)  # misura del fotogramma, pixel a 2x
FEET = (168, 286)  # dove stanno i piedi nel fotogramma: sotto resta spazio per chi è appeso al bordo
GROUND_SPEED = 380 * 2  # FIGHTER.groundSpeed, in pixel a 2x al secondo


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def ease_out(t):
    t = max(0.0, min(1.0, t))
    return 1 - (1 - t) ** 3


def lerp(a, b, t):
    return a + (b - a) * t


def keyed(points, curve=smooth):
    """Una funzione del tempo che passa per i punti (t, valore), con le curve morbide tra uno e l'altro."""
    def f(t):
        if t <= points[0][0]:
            return points[0][1]
        for (t0, v0), (t1, v1) in zip(points, points[1:]):
            if t <= t1:
                return lerp(v0, v1, curve((t - t0) / (t1 - t0)) if t1 > t0 else 1)
        return points[-1][1]
    return f


# ---------------------------------------------------------------- posa "piatta" -> ossa
# Valori di riposo dello scheletro, letti da rig.json
def _ang(n):
    return math.degrees(sk.riposo(n))


REST = {
    "aRu": _ang("upper_arm_R"), "aRl": _ang("forearm_R"), "aRh": _ang("hand_R"),
    "aLu": _ang("upper_arm_L"), "aLl": _ang("forearm_L"), "aLh": _ang("hand_L"),
    "pRx": sk.ossa["foot_R"]["head"][0], "pRy": sk.ossa["foot_R"]["head"][1], "pRa": _ang("foot_R"),
    "pLx": sk.ossa["foot_L"]["head"][0], "pLy": sk.ossa["foot_L"]["head"][1], "pLa": _ang("foot_L"),
}
BASE = dict(x=0, y=0, spin=0, hips=0, sp=0, neck=0, head=0, jaw=0, brow=0, lid=0, tb=0, tf=0, joint=0,
            fR=0, tR=0, fL=0, tL=0, oR=0, oL=0, pRb=1, pLb=1, **REST)
PIVOT = (0.0, -95.0)  # centro del corpo, per le capriole


def costruisci(p):
    """Dalla posa piatta (vedi BASE) alle ossa: gradi per osso e spostamento della radice.
    Braccia: angoli nel mondo (aRu, aRl, aRh) oppure IK con hRx, hRy (polso), hRa (mano), hRb (piega).
    Gambe: IK con pRx, pRy (caviglia nel mondo), pRa (piede), pRb (piega); oppure angoli nel mondo lRu, lRl, lRf."""
    q = dict(BASE)
    q.update(p)
    th = math.radians(q["spin"])
    c, sn = math.cos(th), math.sin(th)
    px, py = PIVOT
    root = (q["x"] + px - (c * px - sn * py), q["y"] + py - (sn * px + c * py))
    b = {"root": q["spin"], "hips": q["hips"], "spine_1": 0.3 * q["sp"], "spine_2": 0.35 * q["sp"], "spine_3": 0.35 * q["sp"],
         "neck": q["neck"], "head": q["head"], "jaw": q["jaw"], "brow": q["brow"], "lid": q["lid"],
         "tuft_back": q["tb"], "tuft_front": q["tf"], "joint": q["joint"]}
    for S in ("R", "L"):
        up, lo, ha = f"upper_arm_{S}", f"forearm_{S}", f"hand_{S}"
        if f"h{S}x" in q:
            b[up], b[lo] = sk.due_ossa(b, root, up, lo, (q[f"h{S}x"], q[f"h{S}y"]), q.get(f"h{S}b", -1))
            b[ha] = sk.angolo_mondo(b, root, ha, q.get(f"h{S}a", 90))
        else:
            b[up] = sk.angolo_mondo(b, root, up, q[f"a{S}u"])
            b[lo] = sk.angolo_mondo(b, root, lo, q[f"a{S}l"])
            b[ha] = sk.angolo_mondo(b, root, ha, q[f"a{S}h"])
        b[f"fingers_{S}"], b[f"thumb_{S}"] = q[f"f{S}"], q[f"t{S}"]
        th_, sh, ft = f"thigh_{S}", f"shin_{S}", f"foot_{S}"
        if f"l{S}u" in q:
            b[th_] = sk.angolo_mondo(b, root, th_, q[f"l{S}u"])
            b[sh] = sk.angolo_mondo(b, root, sh, q[f"l{S}l"])
            b[ft] = sk.angolo_mondo(b, root, ft, q[f"l{S}f"])
        else:
            b[th_], b[sh] = sk.due_ossa(b, root, th_, sh, (q[f"p{S}x"], q[f"p{S}y"]), q[f"p{S}b"])
            b[ft] = sk.angolo_mondo(b, root, ft, q[f"p{S}a"])
        b[f"toes_{S}"] = q[f"o{S}"]
    return b, root


def frames_from(keys, n, lag=None, loop=False, curve=smooth):
    """keys: [(fotogramma, {parametro: valore})], i parametri non scritti restano quelli della chiave prima.
    lag: {parametro: fotogrammi} di ritardo, per l'inerzia di testa, mani e ciuffi. Restituisce n pose piatte."""
    lag = lag or {}
    full, prev = [], dict(BASE)
    for f, p in keys:
        cur = dict(prev)
        cur.update(p)
        full.append((f, cur))
        prev = cur
    params = set().union(*[k[1].keys() for k in full])

    def at(prm, t):
        if t <= full[0][0]:
            return full[0][1].get(prm, BASE.get(prm, 0))
        for (f0, a), (f1, b) in zip(full, full[1:]):
            if t <= f1:
                u = curve((t - f0) / (f1 - f0)) if f1 > f0 else 1
                return lerp(a.get(prm, BASE.get(prm, 0)), b.get(prm, BASE.get(prm, 0)), u)
        return full[-1][1].get(prm, BASE.get(prm, 0))

    out = []
    for fr in range(n):
        pose = {}
        for prm in params:
            t = fr - lag.get(prm, 0)
            if loop:
                t %= n
            pose[prm] = at(prm, max(0, t))
        out.append(pose)
    return out


# ---------------------------------------------------------------- animazioni a tempo (dalla prova #198)
def anim_t(n, rot, pos=None):
    """n fotogrammi da funzioni del tempo: {osso: f(t) -> gradi}, {"root": f(t) -> (x, y)}."""
    out = []
    for i in range(n):
        t = i / FPS
        b = {k: f(t) for k, f in rot.items()}
        root = pos["root"](t) if pos else (0.0, 0.0)
        out.append((b, root))
    return out


def idle():
    L, n = 2.0, 24  # 2 s a 12 fps
    w = TAU / L
    blink = lambda t: 28.0 if 1.30 < t < 1.42 else 0.0
    rot = {
        "hips": lambda t: 1.5 * s(w * t), "spine_1": lambda t: -1.2 * s(w * t + 0.4),
        "spine_2": lambda t: -1.8 * s(w * t + 0.8), "spine_3": lambda t: -1.2 * s(w * t + 1.2),
        "neck": lambda t: 1.0 * s(w * t + 1.6), "head": lambda t: 2.5 * s(w * t + 2.0),
        "jaw": lambda t: 1.5 * max(0.0, s(w * t * 2)), "lid": blink, "brow": lambda t: 4.0 * max(0.0, s(w * t - 0.5)),
        "tuft_back": lambda t: 4.0 * s(w * t * 2 + 2.6), "tuft_front": lambda t: -3.0 * s(w * t * 2 + 2.9),
        "upper_arm_R": lambda t: 4.0 * s(w * t + 2.2), "forearm_R": lambda t: 3.0 * s(w * t + 2.8), "hand_R": lambda t: 4.0 * s(w * t + 3.3),
        "upper_arm_L": lambda t: 4.0 * s(w * t + 2.6), "forearm_L": lambda t: 3.0 * s(w * t + 3.1),
        "thigh_R": lambda t: -1.5 * s(w * t), "shin_R": lambda t: 2.5 * s(w * t),
        "thigh_L": lambda t: 1.5 * s(w * t), "shin_L": lambda t: -2.0 * s(w * t),
    }
    out = []
    for i in range(n):
        t = i * L / n
        out.append(({k: f(t) for k, f in rot.items()}, (0.0, 1.5 * s(w * t * 2))))
    return out


def light():
    # Schiaffo di rovescio (avvio 40 ms, colpo fino a 140 ms, attesa 280 ms): il peso va indietro, il braccio
    # si carica piegato, poi il gomito si apre a frusta e il polso scatta. In gioco i tempi li stira hitFrame.
    L = 0.42
    rot = {
        "hips": keyed([(0, 0), (0.04, -3), (0.10, 4), (0.20, 3), (0.42, 0)]),
        "spine_1": keyed([(0, 0), (0.04, -2), (0.11, 3), (0.22, 2), (0.42, 0)]),
        "spine_2": keyed([(0, 0), (0.04, -4), (0.11, 6), (0.24, 3), (0.42, 0)]),
        "spine_3": keyed([(0, 0), (0.05, -3), (0.12, 5), (0.26, 2), (0.42, 0)]),
        "neck": keyed([(0, 0), (0.05, 3), (0.12, -6), (0.28, -2), (0.42, 0)]),
        "head": keyed([(0, 0), (0.06, 3), (0.13, -5), (0.30, -1), (0.42, 0)]),
        "brow": keyed([(0, 0), (0.06, -8), (0.20, -8), (0.42, 0)]),
        "clavicle_R": keyed([(0, 0), (0.04, 6), (0.10, -10), (0.24, -4), (0.42, 0)]),
        "upper_arm_R": keyed([(0, 0), (0.04, -28), (0.09, -58), (0.14, -64), (0.26, -40), (0.42, 0)]),
        "forearm_R": keyed([(0, 0), (0.04, -105), (0.09, -8), (0.14, 6), (0.26, -25), (0.42, 0)]),
        "hand_R": keyed([(0, 0), (0.04, -25), (0.10, 25), (0.15, 30), (0.30, 5), (0.42, 0)]),
        "fingers_R": keyed([(0, 0), (0.05, 30), (0.10, -10), (0.16, 20), (0.42, 0)]),
        "thumb_R": keyed([(0, 0), (0.05, 20), (0.11, -15), (0.42, 0)]),
        "upper_arm_L": keyed([(0, 0), (0.05, -6), (0.11, 14), (0.26, 6), (0.42, 0)]),
        "forearm_L": keyed([(0, 0), (0.11, 10), (0.42, 0)]),
        "thigh_R": keyed([(0, 0), (0.04, 3), (0.10, -8), (0.26, -4), (0.42, 0)]),
        "shin_R": keyed([(0, 0), (0.10, 8), (0.26, 4), (0.42, 0)]),
        "foot_R": keyed([(0, 0), (0.10, 2), (0.42, 0)]),
        "thigh_L": keyed([(0, 0), (0.10, 6), (0.42, 0)]),
        "shin_L": keyed([(0, 0), (0.10, -4), (0.42, 0)]),
        "tuft_back": keyed([(0, 0), (0.08, -10), (0.18, 8), (0.42, 0)]),
        "tuft_front": keyed([(0, 0), (0.09, 8), (0.20, -6), (0.42, 0)]),
    }
    rx = keyed([(0, 0), (0.04, -3), (0.10, 7), (0.26, 4), (0.42, 0)])
    return anim_t(int(round(L * FPS)), rot, {"root": lambda t: (rx(t), 0.0)})


def heavy():
    # Martello a due pugni (avvio 260 ms, colpo fino a 380 ms, attesa 750 ms): sulle punte con le braccia
    # sopra la testa, una pausa in cima, poi giù di peso piegando le ginocchia
    L = 0.75
    rot = {
        "hips": keyed([(0, 0), (0.18, -6), (0.26, -6), (0.31, 10), (0.40, 9), (0.75, 0)]),
        "spine_1": keyed([(0, 0), (0.18, -6), (0.26, -7), (0.31, 8), (0.42, 7), (0.75, 0)]),
        "spine_2": keyed([(0, 0), (0.19, -8), (0.26, -9), (0.32, 12), (0.44, 9), (0.75, 0)]),
        "spine_3": keyed([(0, 0), (0.20, -6), (0.26, -7), (0.32, 8), (0.46, 6), (0.75, 0)]),
        "neck": keyed([(0, 0), (0.20, 8), (0.27, 9), (0.33, -10), (0.50, -6), (0.75, 0)]),
        "head": keyed([(0, 0), (0.20, 6), (0.27, 6), (0.34, -8), (0.52, -4), (0.75, 0)]),
        "jaw": keyed([(0, 0), (0.22, 6), (0.32, -2), (0.75, 0)]),
        "brow": keyed([(0, 0), (0.22, -12), (0.50, -12), (0.75, 0)]),
        "upper_arm_R": keyed([(0, 0), (0.16, -150), (0.26, -160), (0.31, -70), (0.40, -62), (0.75, 0)]),
        "forearm_R": keyed([(0, 0), (0.16, -40), (0.26, -30), (0.31, -4), (0.40, 0), (0.75, 0)]),
        "hand_R": keyed([(0, 0), (0.18, -20), (0.30, 10), (0.40, 8), (0.75, 0)]),
        "fingers_R": keyed([(0, 0), (0.12, 60), (0.70, 60), (0.75, 0)]),
        "upper_arm_L": keyed([(0, 0), (0.17, -145), (0.26, -155), (0.31, -66), (0.41, -58), (0.75, 0)]),
        "forearm_L": keyed([(0, 0), (0.17, -45), (0.26, -34), (0.31, -6), (0.41, 0), (0.75, 0)]),
        "fingers_L": keyed([(0, 0), (0.12, 60), (0.70, 60), (0.75, 0)]),
        "thigh_R": keyed([(0, 0), (0.18, 6), (0.26, 6), (0.32, -22), (0.45, -16), (0.75, 0)]),
        "shin_R": keyed([(0, 0), (0.18, -6), (0.26, -6), (0.32, 30), (0.45, 22), (0.75, 0)]),
        "foot_R": keyed([(0, 0), (0.18, 12), (0.26, 12), (0.32, -8), (0.75, 0)]),
        "thigh_L": keyed([(0, 0), (0.18, 6), (0.26, 6), (0.32, -20), (0.45, -14), (0.75, 0)]),
        "shin_L": keyed([(0, 0), (0.18, -6), (0.26, -6), (0.32, 28), (0.45, 20), (0.75, 0)]),
        "foot_L": keyed([(0, 0), (0.18, 12), (0.26, 12), (0.32, -8), (0.75, 0)]),
        "tuft_back": keyed([(0, 0), (0.24, -12), (0.36, 14), (0.55, -4), (0.75, 0)]),
        "tuft_front": keyed([(0, 0), (0.25, 10), (0.37, -12), (0.56, 4), (0.75, 0)]),
    }
    rx = keyed([(0, 0), (0.26, -4), (0.32, 8), (0.45, 6), (0.75, 0)])
    ry = keyed([(0, 0), (0.18, -8), (0.26, -9), (0.32, 12), (0.45, 9), (0.75, 0)])
    return anim_t(int(round(L * FPS)), rot, {"root": lambda t: (rx(t), ry(t))})


# ---------------------------------------------------------------- corsa: galoppo sulle nocche (dallo scatto di #198)
def walk():
    # Mani e piedi si appoggiano davvero: a terra scorrono indietro alla velocità della camminata
    # (FIGHTER.groundSpeed), in aria tornano avanti ad arco. Busto piegato in avanti, testa su.
    n = 8  # 1/3 di secondo a 24 fps
    L = n / FPS
    duty = 0.28  # quanto del giro un appoggio sta a terra: corto, perché le gambe sono corte e la corsa veloce
    stride = duty * L * GROUND_SPEED
    phase = {"R_leg": 0.00, "L_leg": 0.10, "R_arm": 0.50, "L_arm": 0.60}

    def path(t, ph, center, lift):
        p = ((t / L) + ph) % 1.0
        front = center + stride / 2
        if p < duty:
            return (front - stride * p / duty, 0.0)
        k = (p - duty) / (1 - duty)
        return (front - stride + stride * smooth(k), -lift * math.sin(math.pi * k))

    out = []
    for i in range(n):
        t = i / FPS
        w = TAU * t / L
        pose = dict(hips=26 + 3 * s(w), sp=26 + 4 * s(w + 0.6), neck=-30, head=-24 + 3 * s(w + 1.6), y=16 - 6 * abs(s(w + 0.3)))
        corpo, radice = costruisci(pose)
        m = sk.fk(corpo, radice)
        for S in ("R", "L"):
            hx = m[f"thigh_{S}"][0][0]
            x, y = path(t, phase[f"{S}_leg"], hx + 4, 24)
            pose[f"p{S}x"], pose[f"p{S}y"], pose[f"p{S}b"] = x, y - 12, 1
            pose[f"p{S}a"] = REST[f"p{S}a"] - (30 if y < -2 else 0)
            sx = m[f"upper_arm_{S}"][0][0]
            x, y = path(t, phase[f"{S}_arm"], sx + 18, 30)
            pose[f"h{S}x"], pose[f"h{S}y"], pose[f"h{S}b"] = x, y - 34, -1
            pose[f"h{S}a"] = 90  # mano dritta, sulle nocche
            pose[f"f{S}"] = 80
        pose["tb"] = 12 + 6 * s(2 * w)
        pose["tf"] = -6 * s(2 * w + 0.5)
        out.append(pose)
    return [costruisci(p) for p in out]


# ---------------------------------------------------------------- salto, caduta, doppio salto (dallo spritesheet di prima)
FALL_POSE = lambda w: dict(
    y=-8, sp=3 + 1.5 * s(w), neck=-2, head=-4 + 2 * s(w - 0.8),
    aRu=-28 + 7 * s(w), aRl=-10 + 11 * s(w - 0.7), aRh=10 + 12 * s(w - 1.3),
    aLu=-140 + 6 * s(w + 1.2), aLl=-155 + 9 * s(w + 0.6), aLh=-165 + 10 * s(w),
    lRu=68 + 4 * s(w), lRl=112 + 4 * s(w - 0.6), lRf=28,
    lLu=84 + 4 * s(w + 1.5), lLl=110 + 4 * s(w + 0.9), lLf=32,
    tb=10 + 6 * s(w), tf=-6 * s(w + 0.5), joint=-4)


def jump():
    keys = [
        (0, dict(y=-14, sp=-5, neck=-4, head=-6, aRu=-48, aRl=-55, aRh=-60, aLu=-120, aLl=-128, aLh=-130,
                 lRu=96, lRl=100, lRf=55, lLu=102, lLl=106, lLf=62, tb=-14, tf=10)),
        (3, dict(sp=0, aRu=-30, aRl=-12, aRh=0, aLu=-105, aLl=-95, aLh=-80,
                 lRu=55, lRl=118, lRf=40, lLu=70, lLl=120, lLf=45, tb=-6, tf=4)),
        (6, dict(sp=8, neck=2, head=4, aRu=5, aRl=40, aRh=60, aLu=-70, aLl=-40, aLh=-20,
                 lRu=15, lRl=105, lRf=25, lLu=30, lLl=112, lLf=30, tb=4, tf=-2)),
    ]
    return [costruisci(p) for p in frames_from(keys, 7, lag={"aRh": 1, "aLh": 1, "head": 1, "tb": 1, "tf": 1})]


def fall():
    n = 12
    return [costruisci(FALL_POSE(TAU * f / n)) for f in range(n)]


def double_jump():
    n = 9
    tuck = dict(sp=28, neck=10, head=10, aRu=40, aRl=-60, aRh=-40, aLu=25, aLl=-70, aLh=-50,
                lRu=-20, lRl=95, lRf=10, lLu=-5, lLl=100, lLf=15, tb=20, tf=-10)
    out = []
    for f in range(n):
        u = f / (n - 1)
        p = dict(tuck)
        p["spin"] = 360 * ease_out(u)
        p["y"] = -30 - 10 * math.sin(math.pi * u) + 22 * smooth((u - 0.75) / 0.25)
        if u > 0.75:  # si apre verso la caduta
            k = smooth((u - 0.75) / 0.25)
            for key, v in FALL_POSE(0).items():
                p[key] = lerp(p.get(key, BASE.get(key, 0)), v, k)
        out.append(costruisci(p))
    return out


# ---------------------------------------------------------------- colpito e lanciato
def hit():
    keys = [
        (0, dict()),
        (1, dict(x=-6, y=3, sp=-20, neck=-6, head=-8, aRu=35, aRl=18, aRh=5, aLu=55, aLl=40, aLh=30, joint=-15,
                 brow=-10, lid=20, tb=-16, tf=12, pRx=REST["pRx"] - 4, pLx=REST["pLx"] - 6)),
        (3, dict(x=-8, y=4, sp=-16, neck=-10, head=-18, aRu=50, aRl=45, aRh=30, aLu=68, aLl=60, aLh=55, lid=28)),
        (7, dict(x=-4, y=3, sp=-6, neck=2, head=8, aRu=78, aRl=92, aRh=95, aLu=92, aLl=90, aLh=92, joint=-6,
                 brow=0, lid=0, tb=2, tf=-2, pRx=REST["pRx"], pLx=REST["pLx"])),
    ]
    return [costruisci(p) for p in frames_from(keys, 8, lag={"head": 1, "aRh": 1, "aLh": 1, "tb": 1, "tf": 1.5}, curve=ease_out)]


def tumble():
    n = 12
    out = []
    for f in range(n):
        u = f / n
        w = TAU * u
        out.append(costruisci(dict(
            spin=-360 * u, y=-36, sp=24, neck=-6 + 6 * s(w), head=-10 + 8 * s(w - 0.7),
            aRu=-20 + 12 * s(2 * w), aRl=60 + 20 * s(2 * w - 0.8), aRh=80 + 20 * s(2 * w - 1.4),
            aLu=175 + 12 * s(2 * w + 1.5), aLl=245 + 18 * s(2 * w + 0.7), aLh=255,
            lRu=-5 + 12 * s(2 * w + 0.5), lRl=90 + 15 * s(2 * w - 0.3), lRf=30,
            lLu=145 + 12 * s(2 * w + 2), lLl=70 + 15 * s(2 * w + 1.2), lLf=40,
            joint=-10, lid=25, tb=18 * s(2 * w), tf=-14 * s(2 * w + 0.6))))
    return out


# ---------------------------------------------------------------- bordo (#110, #171)
# Lo spigolo da appesi: mezza hitbox davanti al centro (22 px = 44 a 2x), LEDGE.hangOffsetY sopra i piedi (56 = 112)
CORNER = (44, -112)
GRIP = 14  # il polso sta sotto lo spigolo: le dita sono agganciate sopra


def _hang_y(pose, target, reach):
    """La y della radice che mette la spalla vicina a `reach` pixel sotto il polso: braccia quasi dritte."""
    best, by = 9e9, 0
    for y in range(40, 220, 2):
        corpo, radice = costruisci(dict(pose, y=y))
        (sx, sy), _, _ = sk.fk(corpo, radice)["upper_arm_R"]
        err = abs(math.hypot(target[0] - sx, target[1] - sy) - reach)
        if err < best:
            best, by = err, y
    return by


_HANG_Y = None


def hang_pose(w=0.0):
    # Appeso con le due mani sullo spigolo, il petto verso la parete, le gambe piegate con i piedi contro il muro
    global _HANG_Y
    cx, cy = CORNER
    k = s(w)
    body = dict(x=16 + 2 * k, hips=-4, sp=-6 + 2 * k, neck=-12, head=-16 + 3 * s(w - 0.8))
    if _HANG_Y is None:
        _HANG_Y = _hang_y(body, (cx - 2, cy + GRIP), 0.94 * (sk.lunghezza("upper_arm_R") + sk.lunghezza("forearm_R")))
    return dict(body, y=_HANG_Y + 1.2 * s(2 * w),
                hRx=cx - 2, hRy=cy + GRIP, hRa=-86, hRb=-1, fR=70,
                hLx=cx - 8, hLy=cy + GRIP + 2, hLa=-88, hLb=-1, fL=70,
                pRx=cx - 2, pRy=cy + 140 + 2 * k, pRa=-30, pRb=1,
                pLx=cx, pLy=cy + 154 - 2 * k, pLa=-20, pLb=1,
                joint=-6, tb=-6 + 4 * s(w - 0.6), tf=4 * s(w - 0.9))


def ledge():
    n = 24
    return [costruisci(hang_pose(TAU * f / n)) for f in range(n)]


def climb():
    # 10 fotogrammi = 417 ms: il server porta i piedi dallo spigolo al palco in LEDGE.climbMs (400 ms).
    # Lo spigolo nel fotogramma va da CORNER a 44 dietro i piedi, sul pavimento.
    n = 10
    C = lambda t: (lerp(CORNER[0], -44, t), lerp(CORNER[1], 0, t))
    keys = [(0, hang_pose(0))]
    c = C(3 / 9)  # si tira su: gomiti piegati, petto all'altezza dello spigolo, mani che spingono sul palco
    keys.append((3, dict(x=c[0] - 30, y=c[1] + 150, hips=-6, sp=24, neck=-8, head=-8,
                         hRx=c[0] + 12, hRy=c[1] - 16, hRa=90, hRb=-1, fR=0,
                         hLx=c[0] + 4, hLy=c[1] - 15, hLa=90, hLb=-1, fL=0,
                         pRx=c[0] - 14, pRy=c[1] + 110, pRa=-40, pRb=1,
                         pLx=c[0] - 16, pLy=c[1] + 130, pLa=-30, pLb=1, joint=-4)))
    c = C(6 / 9)  # sopra il palco: un piede appoggiato, l'altra gamba ancora giù
    keys.append((6, dict(x=c[0] + 10, y=c[1] - 2, hips=8, sp=30, neck=-14, head=-10,
                         hRx=c[0] + 64, hRy=c[1] - 16, hRa=90, hRb=-1,
                         hLx=c[0] + 54, hLy=c[1] - 15, hLa=90, hLb=-1,
                         pRx=c[0] + 30, pRy=c[1] - 12, pRa=REST["pRa"], pRb=1,
                         pLx=c[0] - 8, pLy=c[1] + 40, pLa=-30, pLb=1, joint=-2)))
    keys.append((8, dict(x=0, y=6, hips=0, sp=12, neck=-4, head=-2,
                         hRx=40, hRy=-46, hRa=80, hRb=-1, hLx=26, hLy=-48, hLa=80, hLb=-1,
                         pRx=REST["pRx"], pRy=REST["pRy"], pRa=REST["pRa"], pRb=1,
                         pLx=REST["pLx"], pLy=REST["pLy"], pLa=REST["pLa"], pLb=1, joint=0)))
    out = [costruisci(p) for p in frames_from(keys, 9, lag={"head": 0.6, "joint": 0.5})]
    out.append(idle()[0])  # ultimo fotogramma = posa del fermo, così il passaggio non salta
    return out


# ---------------------------------------------------------------- nuove: atterraggio e provocazione
def land():
    # Atterra di peso: ginocchia giù, braccia che scendono e si appoggiano un attimo, poi si raddrizza (150 ms + coda)
    keys = [
        (0, dict(y=6, sp=10, neck=-4, head=-6, aRu=40, aRl=60, aRh=70, aLu=30, aLl=50, aLh=60, tb=-10, tf=8)),
        (1, dict(y=22, hips=6, sp=22, neck=-10, head=-12, aRu=70, aRl=95, aRh=100, aLu=62, aLl=88, aLh=95,
                 fR=30, fL=30, brow=-8, lid=14, tb=10, tf=-10)),
        (3, dict(y=14, hips=4, sp=14, neck=-6, head=-6, aRu=78, aRl=88, aRh=86, aLu=74, aLl=84, aLh=86, fR=10, fL=10, tb=4, tf=-4)),
        (5, dict(y=0, hips=0, sp=0, neck=0, head=0, aRu=REST["aRu"], aRl=REST["aRl"], aRh=REST["aRh"],
                 aLu=REST["aLu"], aLl=REST["aLl"], aLh=REST["aLh"], fR=0, fL=0, brow=0, lid=0, tb=0, tf=0)),
    ]
    return [costruisci(p) for p in frames_from(keys, 6, lag={"head": 0.7, "tb": 1, "tf": 1.2}, curve=ease_out)]


def taunt():
    # Spavaldo: si toglie la canna di bocca, soffia il fumo verso l'avversario con la testa alta,
    # poi si batte il petto due volte e rimette la canna in bocca. 24 fotogrammi a 12 fps = 2 s.
    up = dict(hRx=72, hRy=-152, hRa=-30, hRb=-1, fR=-20, tR=30)  # mano alla bocca, canna tra le dita
    keys = [
        (0, dict()),
        (3, dict(sp=-6, neck=-4, head=-8, **up)),
        (5, dict(sp=-10, neck=-6, head=-18, jaw=8, brow=-14, lid=12, hRx=86, hRy=-140, hRa=10, hRb=-1, fR=-10, tR=20)),
        (9, dict(sp=-12, neck=-8, head=-22, jaw=10, brow=-16, lid=16, hRx=96, hRy=-128, hRa=20, hRb=-1)),
        (11, dict(sp=-4, neck=0, head=-6, jaw=0, brow=-6, lid=0, hRx=40, hRy=-104, hRa=150, hRb=-1, fR=60, tR=0,
                  hLx=34, hLy=-110, hLa=160, hLb=-1, fL=60)),
        (13, dict(sp=-8, head=-10, hRx=16, hRy=-112, hLx=12, hLy=-116)),
        (15, dict(sp=-2, head=-4, hRx=40, hRy=-104, hLx=34, hLy=-110)),
        (17, dict(sp=-8, head=-10, hRx=16, hRy=-112, hLx=12, hLy=-116)),
        (20, dict(sp=-2, head=-2, brow=-8, **up)),
        (23, dict(sp=0, neck=0, head=0, brow=0, lid=0, aRu=REST["aRu"], aRl=REST["aRl"], aRh=REST["aRh"],
                  aLu=REST["aLu"], aLl=REST["aLl"], aLh=REST["aLh"], fR=0, tR=0, fL=0)),
    ]
    frames = frames_from(keys, 24, lag={"head": 0.6, "tb": 1, "tf": 1.2})
    out = []
    for i, p in enumerate(frames):
        # le mani passano dall'IK agli angoli di riposo: prima del fotogramma 3 e dall'ultimo restano a riposo
        if i < 2 or i >= 23:
            for k in [k for k in p if k[0] == "h" and k[1] in "RL"]:
                p.pop(k)
        if i < 11 or i >= 18:
            for k in [k for k in p if k.startswith("hL")]:
                p.pop(k)
        p["tb"] = 6 * s(i * 0.8)
        p["tf"] = -5 * s(i * 0.8 + 0.6)
        out.append(costruisci(p))
    return out


# ---------------------------------------------------------------- tutto
# stato: (fotogrammi, fps, ciclo, fotogramma d'impatto)
ANIMS = {
    "idle": (idle, 12, True, None),
    "walk": (walk, FPS, True, None),
    "jump": (jump, FPS, False, None),
    "fall": (fall, FPS, True, None),
    "light": (light, FPS, False, 2),
    "heavy": (heavy, FPS, False, 8),
    "hit": (hit, FPS, False, None),
    "doubleJump": (double_jump, FPS, False, None),
    "tumble": (tumble, FPS, True, None),
    "ledge": (ledge, 12, True, None),
    "climb": (climb, FPS, False, None),
    "land": (land, FPS, False, None),
    "taunt": (taunt, 12, False, None),
}


def main():
    data = {"character": "bonobot", "frame": list(FRAME), "feet": list(FEET),
            "units": "ossa in gradi rispetto al riposo (positivo = orario, y in giù); radice in pixel a 2x", "animations": {}}
    for name, (fn, fps, loop, hit_frame) in ANIMS.items():
        frames = fn()
        an = {"fps": fps, "loop": loop, "frames": [{"bones": {k: round(v, 3) for k, v in b.items()}, "root": [round(r[0], 3), round(r[1], 3)]} for b, r in frames]}
        if hit_frame is not None:
            an["hitFrame"] = hit_frame
        data["animations"][name] = an
    out = os.path.join(RIG, "animazioni.json")
    json.dump(data, open(out, "w"), separators=(",", ":"))
    print("scritto", out, {k: len(v["frames"]) for k, v in data["animations"].items()})


if __name__ == "__main__":
    main()
