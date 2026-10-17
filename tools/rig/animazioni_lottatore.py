# Uso: python3 tools/rig/animazioni_lottatore.py <id> [<id>...]
# Le animazioni dei lottatori della community (#13) sullo scheletro di Bonobot: sono quelle di
# tools/rig/animazioni_bonobot.py, tranne la corsa. Chi non è una scimmia non galoppa sulle nocche:
# camminata, scatto e speciale di lato diventano una corsa in piedi, con le braccia che oscillano.
# Scrive public/assets/characters/<id>/rig/animazioni.json; poi rendi_sprite.py fa i PNG.
import json, math, os, sys

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)


def carica(rig):
    """Il modulo delle animazioni di Bonobot, con lo scheletro del lottatore (le IK usano le sue misure)."""
    import importlib
    sys.argv = [sys.argv[0], rig]
    if "animazioni_bonobot" in sys.modules:
        return importlib.reload(sys.modules["animazioni_bonobot"])
    return importlib.import_module("animazioni_bonobot")


def corsa(A, n, speed, duty, lean=8, bob=5, lift=26, swing=38):
    """Corsa in piedi alla velocità `speed` (pixel a 2x al secondo): i piedi a terra scorrono indietro, in aria
    tornano avanti ad arco; le braccia piegate oscillano in opposizione alle gambe."""
    L = n / A.FPS
    stride = duty * L * speed
    phase = {"R": 0.0, "L": 0.5}

    def passo(t, ph, center):
        p = ((t / L) + ph) % 1.0
        front = center + stride / 2
        if p < duty:
            return (front - stride * p / duty, 0.0)
        k = (p - duty) / (1 - duty)
        return (front - stride + stride * A.smooth(k), -lift * math.sin(math.pi * k))

    out = []
    for i in range(n):
        t = i / A.FPS
        w = math.tau * t / L
        pose = dict(hips=lean * 0.5, sp=lean + 2 * A.s(2 * w), neck=-lean * 0.6, head=-lean * 0.5 + 2 * A.s(2 * w + 1),
                    y=-bob * abs(A.s(w)))
        corpo, radice = A.costruisci(pose)
        m = A.sk.fk(corpo, radice)
        for S in ("R", "L"):
            hx = m[f"thigh_{S}"][0][0]
            x, y = passo(t, phase[S], hx + 6)
            pose[f"p{S}x"], pose[f"p{S}y"], pose[f"p{S}b"] = x, y - 12, 1
            pose[f"p{S}a"] = A.REST[f"p{S}a"] - (25 if y < -2 else 0)
            # braccio opposto alla gamba: avanti quando la gamba dello stesso lato va indietro
            a = 85 - swing * math.sin(w + math.pi * (phase[S] * 2 + 1))
            pose[f"a{S}u"], pose[f"a{S}l"], pose[f"a{S}h"] = a, a - 75, a - 70
            pose[f"f{S}"] = 60
        pose["tb"] = 10 + 6 * A.s(2 * w)
        pose["tf"] = -6 * A.s(2 * w + 0.5)
        out.append(pose)
    return [A.costruisci(p) for p in out]


def special_side(A):
    # Scatto speciale in piedi: si carica indietro, due giri di corsa più veloce, poi frena
    wind = [(0, dict(A.REST_HANDS)),
            (2, dict(y=14, hips=10, sp=22, neck=-8, head=-6, brow=-16, aRu=150, aRl=120, aRh=110, aLu=40, aLl=-30, aLh=-30,
                     pRx=A.REST["pRx"] - 6, pLx=A.REST["pLx"] - 14, tb=-10, tf=8))]
    run = corsa(A, n=6, speed=820 * 2, duty=0.3, lean=20, bob=4, lift=24, swing=48)
    brake = [(0, dict(x=-6, y=10, hips=6, sp=10, neck=-8, head=-8, brow=-10, aRu=20, aRl=-10, aRh=-10, aLu=30, aLl=0, aLh=0,
                      pRx=A.REST["pRx"] + 18, pLx=A.REST["pLx"] - 6, tb=12, tf=-10)),
             (2, dict(x=0, y=0, hips=0, sp=0, neck=0, head=0, brow=0, pRx=A.REST["pRx"], pLx=A.REST["pLx"], tb=0, tf=0, **A.REST_HANDS))]
    return ([A.costruisci(p) for p in A.frames_from(wind, 3)] + run + run
            + [A.costruisci(p) for p in A.frames_from(brake, 3, lag={"head": 0.6, "tb": 1, "tf": 1.2})])


def genera(cid):
    rig = f"public/assets/characters/{cid}/rig"
    A = carica(rig)
    anims = dict(A.ANIMS)
    del anims["supreme"]  # Omar e la liana sono solo di Bonobot: gli altri usano la suprema di base
    anims["walk"] = (lambda: corsa(A, n=8, speed=A.GROUND_SPEED, duty=0.36), A.FPS, True, None)
    anims["dash"] = (lambda: corsa(A, n=8, speed=560 * 2, duty=0.36, lean=16, bob=6, lift=30, swing=46), A.FPS, True, None)
    anims["specialSide"] = (lambda: special_side(A), A.FPS, False, 3)
    data = {"character": cid, "frame": list(A.FRAME), "feet": list(A.FEET),
            "units": "ossa in gradi rispetto al riposo (positivo = orario, y in giù); radice in pixel a 2x", "animations": {}}
    for name, (fn, fps, loop, hit_frame) in anims.items():
        frames = fn()
        an = {"fps": fps, "loop": loop, "frames": [{"bones": {k: round(v, 3) for k, v in b.items()}, "root": [round(r[0], 3), round(r[1], 3)]} for b, r in frames]}
        if hit_frame is not None:
            an["hitFrame"] = hit_frame
        data["animations"][name] = an
    A.controlla_colpi(data)
    out = os.path.join(rig, "animazioni.json")
    json.dump(data, open(out, "w"), separators=(",", ":"))
    print("scritto", out)


if __name__ == "__main__":
    ids = sys.argv[1:]
    for cid in ids:
        genera(cid)
