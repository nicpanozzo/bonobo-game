# Uso: python3 tools/rig/animazioni_nonnagina.py
# Le animazioni di Nonna Gina (#384 B4): parte da quelle dei lottatori della community (animazioni_lottatore.py) e
# rifà le mosse che sono sue. È un po' curva (HUNCH), cammina piano, e i colpi li dà col mattarello che tiene nella
# mano vicina (il pezzo "pin" di genera_pezzi_lottatore.py, lungo PIN oltre il polso). Tiri e ciabatta con l'altra mano.
# La scheda delle mosse è docs/mosse/nonnagina.md. Scrive public/assets/characters/nonnagina/rig/animazioni.json;
# poi rendi_sprite.py fa i PNG.
import json, math, os, sys

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
import animazioni_lottatore as lott
from genera_pezzi_lottatore import PIN

CID = "nonnagina"
RIG = f"public/assets/characters/{CID}/rig"
A = lott.carica(RIG)
A.FRAME = (400, 368)  # più largo degli altri: il mattarello arriva lontano
A.FEET = (200, 286)
HUNCH = dict(sp=8, neck=-3, head=-4)  # la schiena curva della nonna, in ogni posa

_costruisci = A.costruisci


def curva(p):
    q = dict(p)
    for k, v in HUNCH.items():
        q[k] = q.get(k, 0) + v
    return _costruisci(q)


A.costruisci = curva  # anche le animazioni prese da Bonobot e dai lottatori passano di qui
REST = A.polso({}, "R") | A.polso({}, "L")  # le mani a riposo con la schiena curva


def chiavi(keys, n, lag=None):
    return [A.costruisci(p) for p in A.frames_from(keys, n, lag=lag or {"head": 0.6, "tb": 1, "tf": 1.2})]


def idle():
    # il fermo dei lottatori, con la schiena curva aggiunta alle ossa
    out = []
    for b, r in A.idle():
        b = dict(b)
        b["spine_1"] = b.get("spine_1", 0) + 0.3 * HUNCH["sp"]
        b["spine_2"] = b.get("spine_2", 0) + 0.35 * HUNCH["sp"]
        b["spine_3"] = b.get("spine_3", 0) + 0.35 * HUNCH["sp"]
        b["neck"] = b.get("neck", 0) + HUNCH["neck"]
        b["head"] = b.get("head", 0) + HUNCH["head"]
        out.append((b, r))
    return out


def light():
    # Botta di punta col mattarello (avvio 50 ms): lo tira indietro sopra la spalla e lo spinge dritto in avanti
    return chiavi([(0, dict(REST)),
                   (1, dict(y=4, sp=-6, brow=-10, hRx=6, hRy=-140, hRa=-150, tb=-6, tf=4)),
                   (2, dict(x=8, y=2, sp=10, neck=-6, jaw=6, hRx=86, hRy=-104, hRa=0, tb=8, tf=-6)),
                   (4, dict(hRx=90, hRy=-102)),
                   (8, dict(x=0, y=0, sp=0, neck=0, jaw=0, brow=0, tb=0, tf=0, **REST))], 9)


def heavy():
    # Mattarellata a due mani (avvio 320 ms): sulle punte col mattarello dietro la testa, una pausa, giù di peso
    up = dict(y=-6, sp=-14, neck=8, head=6, brow=-16, hRx=-8, hRy=-212, hRa=-125, hLx=-2, hLy=-204, hLa=-115, fL=60, tb=-12, tf=10)
    back = dict(y=6, sp=10, neck=-4, brow=-10, hRx=-22, hRy=-112, hRa=150, hLx=20, hLy=-110, hLa=120, tb=-6, tf=4)
    return chiavi([(0, dict(REST)), (1, back), (6, up), (7, dict(up, y=-8, sp=-16)),
                   (8, dict(x=6, y=12, sp=22, neck=-12, head=-10, jaw=8, hRx=80, hRy=-112, hRa=35, hLx=72, hLy=-112, hLa=35, tb=12, tf=-10)),
                   (11, dict(x=6, y=12, hRx=82, hRy=-108)),
                   (17, dict(x=0, y=0, sp=0, neck=0, head=0, jaw=0, brow=0, fL=0, tb=0, tf=0, **REST))], 18, {"head": 0.8, "tb": 1, "tf": 1.4})


def special_neutral():
    # Polpetta (avvio 220 ms): la prende dal grembiule con l'altra mano e la lancia ad arco dal basso
    return chiavi([(0, dict(REST)),
                   (1, dict(sp=10, head=6, hLx=30, hLy=-100, hLa=90, fL=60, hRx=40, hRy=-90, hRa=120)),
                   (4, dict(y=6, sp=-4, neck=4, brow=-10, hLx=-40, hLy=-72, hLa=160, fL=60, tb=-6, tf=4)),
                   (5, dict(y=0, sp=12, neck=-6, jaw=8, hLx=74, hLy=-136, hLa=-40, fL=-10, tb=8, tf=-6)),
                   (8, dict(hLx=80, hLy=-146)),
                   (14, dict(sp=0, neck=0, jaw=0, brow=0, fL=0, tb=0, tf=0, **REST))], 15)


def special_side():
    # Ciabatta (avvio 180 ms): se la sfila, la alza dietro la testa e la tira dritta, di braccio
    return chiavi([(0, dict(REST)),
                   (1, dict(y=10, sp=20, neck=-8, hLx=-6, hLy=-40, hLa=100, fL=70, pLx=A.REST["pLx"] - 8)),
                   (3, dict(y=-2, sp=-12, neck=6, head=-6, brow=-14, hLx=-34, hLy=-196, hLa=-130, fL=70, pLx=A.REST["pLx"], tb=-10, tf=8)),
                   (4, dict(x=6, sp=18, neck=-10, head=-6, jaw=8, hLx=96, hLy=-128, hLa=10, fL=-10, tb=10, tf=-8)),
                   (7, dict(hLx=100, hLy=-118)),
                   (12, dict(x=0, sp=0, neck=0, head=0, jaw=0, brow=0, fL=0, tb=0, tf=0, **REST))], 13)


def special_down():
    # Mangia! (contrattacco): il mattarello di traverso davanti, e se la colpiscono risponde con una botta
    guard = dict(sp=-4, brow=-14, hRx=52, hRy=-128, hRa=-95, hLx=60, hLy=-112, hLa=-80, fL=60)
    keys = [(0, dict(REST)), (1, guard)]
    for f in range(2, 9):  # lo scuote, minacciosa, finché la finestra è aperta
        keys.append((f, dict(guard, hRx=52 + (3 if f % 2 else -3), jaw=6 if f % 2 else 0)))
    keys += [(10, dict(x=6, sp=14, neck=-8, jaw=8, hRx=92, hRy=-110, hRa=10, hLx=40, hLy=-100, hLa=90, fL=0)),
             (15, dict(x=0, sp=0, neck=0, jaw=0, brow=0, **REST))]
    return chiavi(keys, 16)


def taunt():
    # Provocazione a 12 fps: alza il mattarello e lo agita brontolando ("Mangia che ti fa bene!")
    out = []
    for f in range(14):
        w = math.tau * f / 7
        k = min(1.0, f / 2) * min(1.0, (13 - f) / 2)
        p = dict(REST)
        p.update(sp=-4 * k, head=6 * math.sin(w) * k, jaw=8 * max(0.0, math.sin(2 * w)) * k, brow=-14 * k,
                 hRx=A.lerp(REST["hRx"], 56, k), hRy=A.lerp(REST["hRy"], -176, k), hRa=A.lerp(REST["hRa"], -80 + 22 * math.sin(2 * w), k),
                 hLx=A.lerp(REST["hLx"], 24, k), hLy=A.lerp(REST["hLy"], -110, k), hLa=A.lerp(REST["hLa"], 140, k))
        out.append(A.costruisci(p))
    return out


def supreme():
    # Pranzo della domenica: si carica, poi tre bracciate di polpette alternando le mani, verso l'alto
    keys = [(0, dict(y=10, sp=16, brow=-16, hRx=30, hRy=-70, hRa=100, hLx=10, hLy=-70, hLa=110, fL=60)), (6, dict(y=10, sp=16, brow=-16, hRx=30, hRy=-70, hRa=100, hLx=10, hLy=-70, hLa=110, fL=60))]
    for i, f in enumerate((9, 15, 21)):
        keys.append((f, dict(y=-4, sp=-12, jaw=10, hRx=60, hRy=-206, hRa=-70, hLx=-20, hLy=-90, hLa=150) if i % 2 == 0
                     else dict(y=-4, sp=-12, jaw=10, hRx=30, hRy=-90, hRa=100, hLx=40, hLy=-210, hLa=-80)))
        keys.append((f + 3, dict(y=6, sp=10, jaw=2, hRx=30, hRy=-80, hRa=100, hLx=10, hLy=-80, hLa=110)))
    keys.append((30, dict(y=0, sp=0, jaw=0, brow=0, fL=0, **REST)))
    return chiavi(keys, 31)


ATTACCHI = {  # stato: (fotogrammi, fps, ciclo, fotogramma d'impatto). Gli altri restano quelli dei lottatori
    "idle": (idle, 12, True, None),
    "walk": (lambda: lott.corsa(A, n=10, speed=A.GROUND_SPEED * 0.85, duty=0.5, lean=10, bob=3, lift=12, swing=16), A.FPS, True, None),
    "dash": (lambda: lott.corsa(A, n=8, speed=560 * 2 * 0.85, duty=0.4, lean=18, bob=5, lift=22, swing=34), A.FPS, True, None),
    "light": (light, A.FPS, False, 2),
    "heavy": (heavy, A.FPS, False, 8),
    "taunt": (taunt, 12, False, None),
    "specialNeutral": (special_neutral, A.FPS, False, 5),
    "specialSide": (special_side, A.FPS, False, 4),
    "specialDown": (special_down, A.FPS, False, 1),
    "supreme": (supreme, A.FPS, False, None),
}


def controlla(data):
    """Come controlla_colpi() di Bonobot, con la punta del mattarello e le zone ritoccate del personaggio."""
    game = json.load(open(os.path.join(QUI, "..", "..", "godot", "data", "game.json"), encoding="utf-8"))
    own = game["characters"].get(CID, {}).get("attacks", {})
    fw, fh = game["fighter"]["width"], game["fighter"]["height"]
    errori = []
    for stato in A.HIT_ZONES:
        an = data["animations"].get(stato)
        if not an or "hitFrame" not in an:
            continue
        a = dict(game["attacks"][A.HIT_ZONES[stato]], **own.get(stato, {}))
        x0 = (a["boxX"] if a.get("boxX") is not None else fw / 2) * 2
        y0 = (a["boxY"] if a.get("boxY") is not None else -fh * 0.7) * 2
        x1, y1 = x0 + a["range"] * 2, y0 + a["height"] * 2
        fr = an["frames"][an["hitFrame"]]
        m = A.sk.fk(fr["bones"], tuple(fr["root"]))
        (hx, hy), ang, _ = m["hand_R"]
        punte = [A.sk.punta(m, t) for t in A.TIPS + (A.BODY if stato in A.BODY_HITS else [])] + [(hx + PIN * math.cos(ang), hy + PIN * math.sin(ang))]
        if any(x0 <= x <= x1 and y0 <= y <= y1 for x, y in punte):
            print(f"  {stato}: colpisce (zona x {x0:.0f}..{x1:.0f}, y {y0:.0f}..{y1:.0f})")
        else:
            errori.append(f"{stato}: nel fotogramma {an['hitFrame']} niente nella zona x {x0:.0f}..{x1:.0f}, y {y0:.0f}..{y1:.0f}")
    if errori:
        sys.exit("Colpi fuori zona:\n" + "\n".join(errori))


def main():
    anims = dict(A.ANIMS)
    del anims["supreme"]  # quella di Omar è di Bonobot
    anims["specialSide"] = (lambda: lott.special_side(A), A.FPS, False, 3)
    anims.update(ATTACCHI)
    data = {"character": CID, "frame": list(A.FRAME), "feet": list(A.FEET),
            "units": "ossa in gradi rispetto al riposo (positivo = orario, y in giù); radice in pixel a 2x", "animations": {}}
    for name, (fn, fps, loop, hit_frame) in anims.items():
        an = {"fps": fps, "loop": loop, "frames": [{"bones": {k: round(v, 3) for k, v in b.items()}, "root": [round(r[0], 3), round(r[1], 3)]} for b, r in fn()]}
        if hit_frame is not None:
            an["hitFrame"] = hit_frame
        data["animations"][name] = an
    controlla(data)
    out = os.path.join(RIG, "animazioni.json")
    json.dump(data, open(out, "w"), separators=(",", ":"))
    print("scritto", out, {k: len(v["frames"]) for k, v in data["animations"].items()})


if __name__ == "__main__":
    main()
