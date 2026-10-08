# Uso: python3 tools/rig/genera_animazioni_prova.py  (scrive godot/prototipi/scheletro/bonobot/animazioni.json)
# Animazioni di prova per lo scheletro di Bonobot (fermo, camminata, schiaffo), come chiavi di rotazione
# delle ossa rispetto al riposo (gradi, positivo = orario con y in giù) e spostamenti della radice (pixel a 2x).
# Stesso formato che scrive tools/blender/esporta_animazioni.py.
import json, math, sys

OUT = sys.argv[1] if len(sys.argv) > 1 else "godot/prototipi/scheletro/bonobot"
STEP = 1 / 30  # una chiave ogni 1/30 s: Godot interpola in mezzo, a ogni frame dello schermo


def sample(length, fn, loop=True):
    n = int(round(length / STEP))
    keys = []
    for i in range(n + 1):
        t = i * STEP
        keys.append([round(t, 4), fn(t)])
    return keys


def anim(length, loop, rot, pos=None):
    tracks = {}
    for bone, fn in rot.items():
        tracks.setdefault(bone, {})["rot"] = [[t, round(v, 3)] for t, v in sample(length, fn)]
    for bone, fn in (pos or {}).items():
        tracks.setdefault(bone, {})["pos"] = [[t, round(v[0], 3), round(v[1], 3)] for t, v in sample(length, fn)]
    return {"length": length, "loop": loop, "tracks": tracks}


TAU = math.tau
s = math.sin

# Fermo: respiro, peso che passa da un piede all'altro, braccia a pendolo, fumo, una battuta di ciglia
L = 2.0
w = TAU / L
blink = lambda t: 28.0 if 1.30 < t < 1.42 else 0.0
idle = anim(L, True, {
    "hips": lambda t: 1.5 * s(w * t),
    "spine_1": lambda t: -1.2 * s(w * t + 0.4),
    "spine_2": lambda t: -1.8 * s(w * t + 0.8),
    "spine_3": lambda t: -1.2 * s(w * t + 1.2),
    "neck": lambda t: 1.0 * s(w * t + 1.6),
    "head": lambda t: 2.5 * s(w * t + 2.0),
    "jaw": lambda t: 1.5 * max(0.0, s(w * t * 2)),
    "lid": blink,
    "brow": lambda t: 4.0 * max(0.0, s(w * t - 0.5)),
    "tuft_back": lambda t: 4.0 * s(w * t * 2 + 2.6),
    "tuft_front": lambda t: -3.0 * s(w * t * 2 + 2.9),
    "upper_arm_R": lambda t: 4.0 * s(w * t + 2.2),
    "forearm_R": lambda t: 3.0 * s(w * t + 2.8),
    "hand_R": lambda t: 4.0 * s(w * t + 3.3),
    "upper_arm_L": lambda t: 4.0 * s(w * t + 2.6),
    "forearm_L": lambda t: 3.0 * s(w * t + 3.1),
    "smoke_1": lambda t: 8.0 * s(w * t * 1.5),
    "smoke_2": lambda t: -12.0 * s(w * t * 1.5 + 1.0),
    "thigh_R": lambda t: -1.5 * s(w * t),
    "shin_R": lambda t: 2.5 * s(w * t),
    "thigh_L": lambda t: 1.5 * s(w * t),
    "shin_L": lambda t: -2.0 * s(w * t),
}, {"root": lambda t: (0.0, 1.5 * s(w * t * 2))})

# Camminata spavalda: passo ondeggiato, braccia lunghe che pendolano al contrario delle gambe
L = 0.8
w = TAU / L
walk = anim(L, True, {
    "hips": lambda t: 4.0 * s(w * t),
    "spine_1": lambda t: -2.0 * s(w * t + 0.3),
    "spine_2": lambda t: -2.5 * s(w * t + 0.6),
    "spine_3": lambda t: -2.0 * s(w * t + 0.9),
    "head": lambda t: -3.0 * s(w * t * 2 + 1.0),
    "thigh_R": lambda t: -26.0 * s(w * t),
    "shin_R": lambda t: 18.0 * max(0.0, s(w * t + 1.2)) + 4,
    "foot_R": lambda t: 14.0 * s(w * t - 0.4),
    "toes_R": lambda t: -10.0 * max(0.0, s(w * t + 0.4)),
    "thigh_L": lambda t: 26.0 * s(w * t),
    "shin_L": lambda t: 18.0 * max(0.0, s(w * t + math.pi + 1.2)) + 4,
    "foot_L": lambda t: -14.0 * s(w * t + 0.4),
    "toes_L": lambda t: -10.0 * max(0.0, s(w * t + math.pi + 0.4)),
    "upper_arm_R": lambda t: 22.0 * s(w * t + 0.25),
    "forearm_R": lambda t: 12.0 * s(w * t + 0.7) - 6,
    "hand_R": lambda t: 14.0 * s(w * t + 1.2),
    "fingers_R": lambda t: 10.0 * s(w * t + 1.6),
    "upper_arm_L": lambda t: -22.0 * s(w * t + 0.25),
    "forearm_L": lambda t: -12.0 * s(w * t + 0.7) - 6,
    "hand_L": lambda t: -14.0 * s(w * t + 1.2),
    "tuft_back": lambda t: 6.0 * s(w * t * 2 + 1.5),
    "tuft_front": lambda t: -5.0 * s(w * t * 2 + 1.8),
    "smoke_1": lambda t: 14.0 * s(w * t + 1.0),
    "smoke_2": lambda t: -18.0 * s(w * t + 1.8),
}, {"root": lambda t: (0.0, -4.0 * abs(s(w * t)))})


# Schiaffo di rovescio (attacco leggero): carica, frusta, ritorno con inerzia
def ease(a, b, k):
    k = max(0.0, min(1.0, k))
    k = k * k * (3 - 2 * k)
    return a + (b - a) * k


def keyed(points):
    def f(t):
        for (t0, v0), (t1, v1) in zip(points, points[1:]):
            if t <= t1:
                return ease(v0, v1, (t - t0) / (t1 - t0) if t1 > t0 else 1)
        return points[-1][1]
    return f


# Schiaffo di rovescio (attacco leggero, avvio 40 ms, colpo fino a 140 ms, attesa 280 ms):
# il peso va indietro, il braccio si carica piegato, poi il gomito si apre a frusta e il polso scatta.
# Busto e testa seguono con un attimo di ritardo, il braccio lontano va al contrario per l'equilibrio
L = 0.42
slap = anim(L, False, {
    "hips": keyed([(0, 0), (0.04, -3), (0.10, 4), (0.20, 3), (0.42, 0)]),
    "spine_1": keyed([(0, 0), (0.04, -2), (0.11, 3), (0.22, 2), (0.42, 0)]),
    "spine_2": keyed([(0, 0), (0.04, -4), (0.11, 6), (0.24, 3), (0.42, 0)]),
    "spine_3": keyed([(0, 0), (0.05, -3), (0.12, 5), (0.26, 2), (0.42, 0)]),
    "neck": keyed([(0, 0), (0.05, 3), (0.12, -6), (0.28, -2), (0.42, 0)]),
    "head": keyed([(0, 0), (0.06, 3), (0.13, -5), (0.30, -1), (0.42, 0)]),
    "brow": keyed([(0, 0), (0.06, -8), (0.20, -8), (0.42, 0)]),
    "clavicle_R": keyed([(0, 0), (0.04, 6), (0.10, -10), (0.24, -4), (0.42, 0)]),
    "upper_arm_R": keyed([(0, 0), (0.04, -30), (0.09, -78), (0.14, -86), (0.26, -50), (0.42, 0)]),
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
    "smoke_1": keyed([(0, 0), (0.12, -20), (0.30, 10), (0.42, 0)]),
    "smoke_2": keyed([(0, 0), (0.14, -30), (0.34, 14), (0.42, 0)]),
}, {"root": lambda t: (keyed([(0, 0), (0.04, -3), (0.10, 7), (0.26, 4), (0.42, 0)])(t), 0.0)})

# Martello a due pugni (attacco pesante, avvio 260 ms, colpo fino a 380 ms, attesa 750 ms):
# si alza sulle punte con le braccia sopra la testa, una pausa in cima, poi giù di peso piegando le ginocchia
L = 0.75
both = lambda pts: keyed(pts)
heavy = anim(L, False, {
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
    "smoke_1": keyed([(0, 0), (0.30, 25), (0.50, -15), (0.75, 0)]),
    "smoke_2": keyed([(0, 0), (0.32, 35), (0.55, -20), (0.75, 0)]),
}, {"root": lambda t: (keyed([(0, 0), (0.26, -4), (0.32, 8), (0.45, 6), (0.75, 0)])(t),
                       keyed([(0, 0), (0.18, -8), (0.26, -9), (0.32, 12), (0.45, 9), (0.75, 0)])(t))})

# Scatto (#198): galoppo sulle nocche come la camminata dello spritesheet di oggi. Il busto si piega in avanti,
# mani e piedi si appoggiano davvero a terra: le pose di braccia e gambe si calcolano con una IK a due ossa
# dai punti d'appoggio (a terra scorrono indietro, in aria tornano avanti ad arco), come farebbe Blender
RIG = json.load(open(f"{OUT}/rig.json"))
BONE = {b["name"]: b for b in RIG["bones"]}


def rest_angle(n):
    b = BONE[n]
    return math.atan2(b["tail"][1] - b["head"][1], b["tail"][0] - b["head"][0])


def blen(n):
    b = BONE[n]
    return math.hypot(b["tail"][0] - b["head"][0], b["tail"][1] - b["head"][1])


def fk(offsets, root_off):
    """Posizione e angolo nel mondo di ogni osso, dati gli scarti di rotazione (gradi) e lo spostamento della radice."""
    world = {}
    for b in RIG["bones"]:
        n = b["name"]
        if not b["deform"]:
            continue
        a = rest_angle(n)
        if b["parent"]:
            ph, pa = world[b["parent"]]
            pr = rest_angle(b["parent"])
            lx, ly = b["head"][0] - BONE[b["parent"]]["head"][0], b["head"][1] - BONE[b["parent"]]["head"][1]
            c, sn = math.cos(pa - pr), math.sin(pa - pr)
            head = (ph[0] + lx * c - ly * sn, ph[1] + lx * sn + ly * c)
            ang = pa + (a - pr)
        else:
            head = (b["head"][0] + root_off[0], b["head"][1] + root_off[1])
            ang = a
        ang += math.radians(offsets.get(n, 0.0))
        world[n] = (head, ang)
    return world


def two_bone(offsets, root_off, upper, lower, target, bend):
    """Scarti (gradi) di upper e lower per portare la fine di lower su target. bend: +1 o -1, da che parte si piega."""
    w = fk(offsets, root_off)
    (sx, sy), parent_ang = w[upper][0], w[upper][1] - math.radians(offsets.get(upper, 0.0))
    l1, l2 = blen(upper), blen(lower)
    dx, dy = target[0] - sx, target[1] - sy
    d = max(1e-3, min(l1 + l2 - 0.01, math.hypot(dx, dy)))
    base = math.atan2(dy, dx)
    a1 = base + bend * math.acos(max(-1, min(1, (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d))))
    a2 = math.atan2(dy - l1 * math.sin(a1), dx - l1 * math.cos(a1))
    # dagli angoli nel mondo agli scarti rispetto al riposo
    off1 = math.degrees(a1 - parent_ang)
    off2 = math.degrees((a2 - a1) - (rest_angle(lower) - rest_angle(upper)))
    wrap = lambda x: (x + 180) % 360 - 180
    return wrap(off1), wrap(off2)


L = 0.36
w = TAU / L
LEAN = {"hips": 26, "spine_1": 14, "spine_2": 8, "spine_3": 4, "neck": -30, "head": -24}
STEPS = {  # fase, da dove a dove scorre a terra (x), pixel a 2x dal punto sotto il corpo
    "R_leg": (0.00, 18, -62), "L_leg": (0.12, 6, -74),
    "R_arm": (0.50, 108, 40), "L_arm": (0.62, 96, 28),
}


def foot_path(t, phase, front, back, lift):
    p = ((t / L) + phase) % 1.0
    if p < 0.55:  # a terra: scorre indietro
        k = p / 0.55
        return (front + (back - front) * k, 0.0)
    k = (p - 0.55) / 0.45  # in aria: torna avanti ad arco
    return (back + (front - back) * k, -lift * math.sin(math.pi * k))


def dash_pose(t):
    off = {n: v + 3 * s(w * t + i * 0.4) for i, (n, v) in enumerate(LEAN.items())}
    root = (0.0, 8 - 6 * abs(s(w * t + 0.3)))
    for side in ("R", "L"):
        f, a, b = STEPS[f"{side}_leg"]
        tx, ty = foot_path(t, f, a, b, 26)
        off[f"thigh_{side}"], off[f"shin_{side}"] = two_bone(off, root, f"thigh_{side}", f"shin_{side}", (tx - 2, ty - 12), -1)
        off[f"foot_{side}"] = -off[f"thigh_{side}"] - off[f"shin_{side}"] - LEAN["hips"] + (14 if ty < -2 else 0)
        f, a, b = STEPS[f"{side}_arm"]
        tx, ty = foot_path(t, f, a, b, 34)
        off[f"upper_arm_{side}"], off[f"forearm_{side}"] = two_bone(off, root, f"upper_arm_{side}", f"forearm_{side}", (tx, ty - 34), 1)
        # mano sulle nocche: verticale, dita piegate sotto
        off[f"hand_{side}"] = -(off[f"upper_arm_{side}"] + off[f"forearm_{side}"] + sum(LEAN[k] for k in ("hips", "spine_1", "spine_2", "spine_3")))
        off[f"fingers_{side}"] = 80.0
    off["tuft_back"] = 12 + 6 * s(w * t * 2)
    off["tuft_front"] = -6 * s(w * t * 2 + 0.5)
    off["smoke_1"] = 50 + 6 * s(w * t)
    off["smoke_2"] = 35 + 10 * s(w * t + 1)
    return off, root


frames = [dash_pose(i * STEP) for i in range(int(round(L / STEP)) + 1)]
dash = {"length": L, "loop": True, "tracks": {}}
for n in frames[0][0]:
    dash["tracks"][n] = {"rot": [[round(i * STEP, 4), round(f[0][n], 3)] for i, f in enumerate(frames)]}
dash["tracks"].setdefault("root", {})["pos"] = [[round(i * STEP, 4), round(f[1][0], 3), round(f[1][1], 3)] for i, f in enumerate(frames)]

json.dump({"character": "bonobot", "units": "gradi rispetto al riposo; radice in pixel a 2x", "animations": {"idle": idle, "walk": walk, "light": slap, "heavy": heavy, "dash": dash}},
          open(f"{OUT}/animazioni.json", "w"), separators=(",", ":"))
print("ok")
