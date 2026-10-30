# Uso: python3 tools/rig/animazioni_opus.py   (dopo genera_pezzi_opus.py; poi rendi_sprite.py per le strisce)
# Le animazioni di Maestro Opus come POSE CHIAVE, nello stile di animazioni_nonnagina.py: ogni stato è una lista di
# chiavi (tempo, curva, posa piatta). Negli attacchi il tempo è in fasi agganciate ai numeri del server: 0..1 avvio
# (startupMs), 1..2 colpo acceso (activeMs), 2..3 recupero fino a cooldownMs; negli altri stati è in ms.
# Combatte dirigendo: la bacchetta (pezzo "baton" di genera_pezzi_opus.py) è il prolungamento della mano destra, lunga
# BATON oltre il polso, e la punta d'oro è quella che colpisce. In guardia tiene il tempo con la bacchetta e l'altra
# mano sul fianco; le code del frac (osso coat_tail, parametro "ct") svolazzano in ritardo. Scheda: docs/mosse/opus.md.
# Scrive <rig>/animazioni.json: le chiavi campionate a fotogrammi, come le mostra Godot (FighterPose.sprite_frame).
import json, math, os, sys

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
import animazioni_lottatore as lott
from genera_pezzi_opus import BATON, S

CID = "opus"
RIG = f"public/assets/characters/{CID}/rig"
A = lott.carica(RIG)
A.FRAME = (380, 380)  # largo e alto: la bacchetta tesa arriva lontano, anche sopra la testa
A.FEET = (190, 296)  # sotto i piedi c'è posto per il corpo di chi è appeso al bordo
TIP = BATON * S  # la punta della bacchetta, pixel a 2x dal polso lungo la mano
GAME = json.load(open(os.path.join(QUI, "..", "..", "godot", "data", "game.json"), encoding="utf-8"))
_costruisci = A.costruisci
s = math.sin
TAU = math.tau


def costruisci(p):
    b, r = _costruisci(p)
    b["coat_tail"] = p.get("ct", 0.0)  # positivo: le code si alzano all'indietro
    return b, r


A.costruisci = costruisci  # anche le pose prese da Bonobot (salto, bordo, presa...) passano di qui

FEET0 = dict(pRx=A.REST["pRx"], pLx=A.REST["pLx"], pRy=A.REST["pRy"], pLy=A.REST["pLy"], pRa=A.REST["pRa"], pLa=A.REST["pLa"])
ZERO = dict(x=0, y=0, spin=0, hips=0, sp=0, neck=0, head=0, jaw=0, brow=0, lid=0, fR=0, fL=0, tR=0, tL=0, tb=0, tf=0, ct=0, **FEET0)
# In guardia: petto in fuori e mento in su, la bacchetta pronta all'altezza della spalla, la sinistra sul fianco
GUARD = dict(ZERO, sp=-5, neck=-3, head=-8, brow=-6, hRx=46, hRy=-120, hRa=-52, hRb=-1, fR=70, tR=30,
             hLx=-10, hLy=-96, hLa=100, hLb=1, fL=40, pRx=A.REST["pRx"] + 4, pLx=A.REST["pLx"] - 4)
AIR_LEGS = dict(lRu=34, lRl=124, lRf=20, lLu=54, lLl=128, lLf=26)  # ginocchia su: in aria si vede che non tocca terra
ARIA = dict({k: v for k, v in GUARD.items() if not k.startswith("p")}, **AIR_LEGS, ct=30, tb=8)
GAME_CH = GAME["characters"].get(CID, {})


# ---------------------------------------------------------------- curve e chiavi (come animazioni_nonnagina.py)
def ease(e, u):
    u = max(0.0, min(1.0, u))
    if e == "in":
        return u ** 3
    if e == "out":
        return 1 - (1 - u) ** 3
    if e == "io":
        return u * u * (3 - 2 * u)
    if e == "snap":
        return u ** 4
    if e == "back":
        c1 = 1.70158
        return 1 + (c1 + 1) * (u - 1) ** 3 + c1 * (u - 1) ** 2
    if e == "hold":
        return 1.0 if u >= 1 else 0.0
    return u


def chiavi(lista, base=GUARD):
    """[(t, curva, posa piatta)] -> [{t, e, bones, root}]: ogni posa parte dalla precedente, poi passa dalle IK."""
    out, cur = [], dict(base)
    for t, e, p in lista:
        cur = dict(cur, **p)
        b, r = A.costruisci(cur)
        out.append({"t": t, "e": e, "bones": b, "root": list(r)})
    return out


def da_fotogrammi(frames, scelta, fps=None):
    return [{"t": t if fps is None else i * 1000.0 / fps, "e": e, "bones": frames[i][0], "root": list(frames[i][1])} for t, i, e in scelta]


def ogni(frames, passo, fps, e="lin"):
    return da_fotogrammi(frames, [(None, i, e) for i in range(0, len(frames), passo)], fps)


def spec(kind):
    """I tempi di un attacco per Opus, come FighterPose.attack_spec() in Godot."""
    if kind == "supreme":
        a = GAME_CH["supremeAttack"]
    elif kind.startswith("special"):
        a = GAME_CH["specialAttacks"][kind]
    else:
        a = dict(GAME["attacks"][kind], **(GAME_CH.get("attacks", {}).get(kind) or {}))
    return {k: float(a.get(k) or 0) for k in ("startupMs", "activeMs", "cooldownMs")}


def colpo(kind, lista, base=None):
    return {"time": "phase", "spec": spec(kind), "keys": chiavi(lista, base or GUARD)}


def tempo(ms, loop, keys):
    return {"time": "ms", "ms": ms, "loop": loop, "keys": keys}


def girato(p):
    """Gli angoli nel mondo di braccia e gambe ruotati con la capriola (spin), così girano insieme al corpo."""
    q = dict(p)
    for k in ("aRu", "aRl", "aRh", "aLu", "aLl", "aLh", "lRu", "lRl", "lRf", "lLu", "lLl", "lLf"):
        if k in q:
            q[k] = q[k] + q.get("spin", 0)
    return q


# ---------------------------------------------------------------- colpi normali (fasi: 0 avvio, 1 impatto, 2 fine colpo, 3 fine)
def light():
    # Stoccata di bacchetta: la tira indietro vicino all'orecchio e la scocca dritta in avanti, sul piede davanti
    return colpo("light", [
        (0, "lin", dict(x=-3, sp=-10, head=-10, brow=-14, hRx=12, hRy=-150, hRa=-150, fR=80, tb=-6, tf=6, ct=-6)),
        (1, "snap", dict(x=7, sp=12, neck=-6, head=-6, jaw=5, hRx=62, hRy=-118, hRa=-4, pRx=A.REST["pRx"] + 16, tb=8, tf=-8, ct=18)),
        (1.4, "out", dict(x=9, hRx=66, hRy=-116, hRa=2)),
        (2, "io", dict(x=8, hRx=64, hRy=-117, hRa=0)),
        (2.5, "io", dict(x=3, sp=2, jaw=0, hRx=46, hRy=-128, hRa=-30, pRx=A.REST["pRx"] + 8, tb=0, tf=0, ct=6)),
        (3, "io", GUARD)])


def heavy():
    # "Fortissimo": in punta di piedi con la bacchetta a due mani dietro la testa, una pausa, poi giù di peso in avanti.
    # La criniera vola, le code del frac si alzano. Poi resta piegato e si rialza scrollando la testa, soddisfatto
    up = dict(y=-8, sp=-18, neck=8, head=-4, brow=-18, jaw=6, hRx=-6, hRy=-196, hRa=-150, hLx=-2, hLy=-190, hLa=-150, hLb=-1, fL=80,
              pRx=A.REST["pRx"] - 2, tb=-16, tf=12, ct=-10)
    return colpo("heavy", [
        (0, "lin", dict(y=8, sp=12, neck=-4, brow=-12, hRx=20, hRy=-108, hRa=130, hLx=14, hLy=-104, hLa=130, hLb=-1, fL=80, tb=-4, tf=4)),
        (0.55, "io", up),
        (0.85, "out", dict(up, y=-12, sp=-22, neck=10, hRx=-12, hRy=-198, hLx=-8, hLy=-192, jaw=8)),
        (1, "snap", dict(x=8, y=12, sp=26, neck=-10, head=-6, jaw=12, brow=-20, hRx=62, hRy=-108, hRa=22, hLx=56, hLy=-104, hLa=24,
                         pRx=A.REST["pRx"] + 22, pLx=A.REST["pLx"] - 10, tb=18, tf=-14, ct=40)),
        (1.3, "out", dict(y=15, sp=30, hRx=66, hRy=-100, hRa=32, hLx=60, hLy=-96, hLa=34, ct=46)),
        (2, "io", dict(y=13, sp=28, hRx=64, hRy=-104, hRa=28, hLx=58, hLy=-100, hLa=30, ct=30)),
        (2.4, "io", dict(y=10, sp=20, head=4, jaw=2, hRx=56, hRy=-88, hRa=70, hLx=40, hLy=-94, hLa=80, tb=4, tf=-4, ct=12)),
        (2.75, "io", dict(x=2, y=2, sp=-6, neck=-4, head=-14, jaw=4, brow=-16, lid=14, hRx=40, hRy=-130, hRa=-50, hLx=-10, hLy=-96, hLa=100, hLb=1, fL=40,
                          pRx=GUARD["pRx"], pLx=GUARD["pLx"], tb=-14, tf=10, ct=0)),
        (3, "io", GUARD)])


def light_up():
    # Colpetto all'insù: dal basso davanti la bacchetta passa sopra la testa e punta il cielo, sulle punte
    return colpo("lightUp", [
        (0, "lin", dict(y=6, sp=8, head=4, brow=-8, hRx=56, hRy=-92, hRa=30, tb=-4, tf=4)),
        (1, "snap", dict(y=-6, sp=-14, neck=-10, head=-24, jaw=6, brow=-16, hRx=20, hRy=-186, hRa=-96, hLx=-20, hLy=-110, hLa=150, hLb=-1,
                         pRy=A.REST["pRy"] - 6, pRa=A.REST["pRa"] - 20, tb=12, tf=-10, ct=-8)),
        (1.3, "out", dict(y=-8, hRx=12, hRy=-190, hRa=-104)),
        (2, "io", dict(y=-7, hRx=10, hRy=-188, hRa=-108)),
        (2.5, "io", dict(y=0, sp=-6, head=-12, jaw=0, hRx=30, hRy=-160, hRa=-70, pRy=A.REST["pRy"], pRa=A.REST["pRa"], tb=0, tf=0)),
        (3, "io", GUARD)])


def light_down():
    # Bacchettata alle caviglie: giù di colpo su un ginocchio, la bacchetta radente in avanti
    feet = dict(pRx=A.REST["pRx"] + 18, pLx=A.REST["pLx"] - 14)
    return colpo("lightDown", [
        (0, "lin", dict(y=18, hips=10, sp=18, neck=-12, head=-10, brow=-10, hRx=30, hRy=-84, hRa=150, hLx=-30, hLy=-100, hLa=170, hLb=-1, tb=-8, tf=6, **feet)),
        (1, "snap", dict(x=8, y=34, hips=20, sp=30, neck=-22, head=-14, jaw=4, hRx=70, hRy=-40, hRa=12, tb=8, tf=-8, ct=24)),
        (1.3, "out", dict(x=10, hRx=74, hRy=-38, hRa=16)),
        (2, "io", dict(x=9, hRx=72, hRy=-39, hRa=14)),
        (2.5, "io", dict(x=3, y=16, hips=8, sp=14, neck=-8, head=-8, jaw=0, hRx=50, hRy=-90, hRa=-20, ct=8)),
        (3, "io", GUARD)])


def light_air():
    # Rovescio in aria: le gambe raccolte, la bacchetta parte da dietro la spalla e taglia in avanti
    return colpo("lightAir", [
        (0, "lin", dict(sp=-6, head=-10, brow=-12, hRx=-6, hRy=-150, hRa=-160, tb=-8, tf=6)),
        (1, "snap", dict(sp=12, neck=-6, head=-4, jaw=6, hRx=54, hRy=-116, hRa=-14, hLx=-30, hLy=-110, hLa=170, hLb=-1, tb=10, tf=-8, ct=40)),
        (1.3, "out", dict(sp=15, hRx=58, hRy=-108, hRa=0)),
        (2, "io", dict(sp=13, hRx=56, hRy=-112, hRa=-6)),
        (3, "io", ARIA)], base=ARIA)


def heavy_up():
    # "Crescendo": giù accucciato con la bacchetta a due mani tra le ginocchia, poi su dritto a braccia tese, sulle punte
    low = dict(y=22, hips=10, sp=22, neck=-8, head=-6, brow=-14, hRx=40, hRy=-44, hRa=60, hLx=34, hLy=-48, hLa=60, hLb=-1, fL=80,
               pRx=A.REST["pRx"] + 8, pLx=A.REST["pLx"] - 10, tb=-8, tf=6)
    return colpo("heavyUp", [
        (0, "lin", dict(y=8, sp=8, neck=-4, head=-4, brow=-10, hRx=54, hRy=-84, hRa=40, hLx=40, hLy=-80, hLa=50, hLb=-1, fL=80, tb=-4, tf=4)),
        (0.6, "io", low),
        (0.85, "out", dict(low, y=30, sp=28, neck=-12, hRx=36, hRy=-36)),
        (1, "snap", dict(y=-14, hips=-4, sp=-14, neck=-12, head=-26, jaw=10, brow=-18, hRx=14, hRy=-196, hRa=-92, hLx=8, hLy=-186, hLa=-92,
                         pRx=A.REST["pRx"], pLx=A.REST["pLx"], pRy=A.REST["pRy"] - 8, pLy=A.REST["pLy"] - 8, pRa=A.REST["pRa"] - 30, pLa=A.REST["pLa"] - 30,
                         tb=16, tf=-14, ct=-20)),
        (1.3, "out", dict(y=-16, hRx=10, hRy=-198, hRa=-96, hLx=4, hLy=-188)),
        (2, "io", dict(y=-15, hRx=12, hRy=-197, hRa=-94)),
        (2.5, "io", dict(y=2, sp=-4, head=-10, jaw=2, hRx=34, hRy=-160, hRa=-60, hLx=-10, hLy=-96, hLa=100, hLb=1, fL=40,
                         pRy=A.REST["pRy"], pLy=A.REST["pLy"], pRa=A.REST["pRa"], pLa=A.REST["pLa"], tb=0, tf=0, ct=0)),
        (3, "io", GUARD)])


def heavy_down():
    # Spaccata alla Fred Astaire: si carica girato indietro, poi giù in affondo con la bacchetta radente davanti e
    # l'altra mano che spazza dietro (il colpo prende dai due lati)
    return colpo("heavyDown", [
        (0, "lin", dict(x=-2, y=4, sp=-2, head=-8, brow=-12, hRx=20, hRy=-168, hRa=-100, hLx=-16, hLy=-110, hLa=-170, hLb=-1, tb=-4, tf=4)),
        (0.6, "io", dict(x=-6, y=10, sp=-8, neck=4, head=-6, brow=-14, hRx=-30, hRy=-150, hRa=-150, hLx=-24, hLy=-120, hLa=-160, tb=-10, tf=8)),
        (0.85, "out", dict(x=-10, y=16, sp=-13, hRx=-38, hRy=-150, hRa=-160, hLx=-30, hLy=-124)),
        (1, "snap", dict(x=10, y=44, hips=8, sp=22, neck=-16, head=-12, jaw=8, brow=-18, hRx=84, hRy=-40, hRa=8, hLx=-62, hLy=-46, hLa=170, hLb=1, fL=0,
                         pRx=A.REST["pRx"] + 52, pLx=A.REST["pLx"] - 44, pRa=A.REST["pRa"] + 10, pLa=A.REST["pLa"] - 30, tb=14, tf=-12, ct=50)),
        (1.3, "out", dict(x=12, hRx=88, hRy=-36, hLx=-66, hLy=-42)),
        (2, "io", dict(x=11, hRx=86, hRy=-38, hLx=-64, hLy=-44)),
        (2.5, "io", dict(x=4, y=22, hips=4, sp=12, neck=-8, head=-8, jaw=0, hRx=56, hRy=-90, hRa=-20, hLx=-20, hLy=-80, hLa=120,
                         pRx=A.REST["pRx"] + 20, pLx=A.REST["pLx"] - 16, pRa=A.REST["pRa"], pLa=A.REST["pLa"], ct=16)),
        (3, "io", GUARD)])


def heavy_air():
    # "Fortissimo" in aria: la bacchetta a due mani sopra la testa, poi giù in avanti
    return colpo("heavyAir", [
        (0, "lin", dict(sp=-2, head=-6, brow=-12, hRx=30, hRy=-168, hRa=-90, hLx=20, hLy=-160, hLa=-90, hLb=-1, fL=80, tb=-4, tf=4, ct=20)),
        (0.6, "io", dict(sp=-12, neck=6, head=0, brow=-16, hRx=-8, hRy=-196, hRa=-140, hLx=-4, hLy=-188, hLa=-140, tb=-12, tf=10, ct=10)),
        (0.85, "out", dict(sp=-17, hRx=-16, hRy=-196, hRa=-155, hLx=-12, hLy=-190)),
        (1, "snap", dict(sp=24, neck=-12, head=-8, jaw=10, hRx=58, hRy=-104, hRa=26, hLx=52, hLy=-100, hLa=28, tb=12, tf=-10, ct=55)),
        (1.3, "out", dict(sp=28, hRx=60, hRy=-94, hRa=36, hLx=54, hLy=-90, hLa=38)),
        (2, "io", dict(sp=26, hRx=59, hRy=-98, hRa=30, hLx=53, hLy=-94)),
        (3, "io", ARIA)], base=ARIA)


def recovery():
    # Il recupero: sale avvitandosi come un ballerino, braccia in alto e bacchetta al cielo
    return colpo("recovery", [
        (0, "lin", dict(y=-6, sp=-10, head=-18, jaw=6, brow=-14, hRx=14, hRy=-190, hRa=-90, hLx=-6, hLy=-186, hLa=-90, hLb=-1, fL=20, **AIR_LEGS, ct=-30, tb=10, tf=-6)),
        (1, "hold", {}),
        (1.5, "io", dict(sp=-6, hRx=20, hRy=-186, hRa=-80, ct=-20)),
        (2, "io", dict(sp=0, head=-10, jaw=2, hRx=30, hRy=-170, hRa=-70, hLx=-30, hLy=-150, hLa=-160, ct=10)),
        (3, "io", ARIA)], base=ARIA)


def grab():
    # Presa: apre le mani, si allunga di scatto, le chiude e tira a sé; l'ultima chiave resta finché tiene
    return colpo("grab", [
        (0, "lin", dict(x=-4, sp=-4, brow=-10, hRx=40, hRy=-100, hRa=20, hLx=30, hLy=-96, hLa=30, hLb=-1, fR=-10, fL=-10)),
        (1, "snap", dict(A.GRAB_REACH, ct=20)),
        (1.3, "out", dict(fR=60, fL=60, tR=30)),
        (2, "io", dict(x=8)),
        (3, "io", dict(A.GRAB_HOLD, ct=6))])


def throw():
    f = A.throw()
    return {"time": "phase", "spec": spec("throwForward"), "keys": da_fotogrammi(f, [(0, 0, "lin"), (1, 0, "hold"), (2, 2, "out"), (3, 7, "io")])}


# ---------------------------------------------------------------- speciali e suprema
def special_neutral():
    # Staccato: alza la bacchetta, la sinistra aperta chiama l'orchestra, poi il gesto secco: la nota parte dalla punta
    return colpo("specialNeutral", [
        (0, "lin", dict(sp=-6, head=-10, brow=-12, hRx=30, hRy=-170, hRa=-110, hLx=40, hLy=-150, hLa=-60, hLb=-1, fL=-20, tL=-20, tb=-4, tf=4)),
        (0.5, "io", dict(y=-2, sp=-12, neck=4, head=-14, hRx=18, hRy=-178, hRa=-140, hLx=46, hLy=-158, hLa=-70)),
        (0.85, "out", dict(sp=-14, hRx=14, hRy=-180, hRa=-150)),
        (1, "snap", dict(y=2, sp=10, neck=-6, head=-4, jaw=8, brow=-18, hRx=60, hRy=-124, hRa=-8, fR=80, hLx=20, hLy=-110, hLa=120, ct=20, tb=10, tf=-8)),
        (2, "hold", {}),
        (2.3, "out", dict(sp=12, hRx=62, hRy=-118, hRa=4)),
        (2.7, "io", dict(sp=2, jaw=2, brow=-8, hRx=44, hRy=-130, hRa=-40, hLx=-10, hLy=-96, hLa=100, hLb=1, fL=40, tL=0, ct=6)),
        (3, "io", GUARD)])


def special_side():
    # Glissando: si abbassa e scivola in avanti su un ginocchio, la bacchetta tesa come un fioretto e l'altra mano alta
    # dietro (posa da schermidore); finito lo scatto si rialza aggiustandosi il frac
    slide = dict(x=6, y=30, hips=-6, sp=-8, neck=-4, head=-12, jaw=6, brow=-16, hRx=68, hRy=-84, hRa=-2, fR=80,
                 hLx=-34, hLy=-156, hLa=-120, hLb=-1, fL=-10, pRx=A.REST["pRx"] + 46, pRa=A.REST["pRa"] - 6,
                 pLx=A.REST["pLx"] - 34, pLy=A.REST["pLy"] - 2, pLa=A.REST["pLa"] + 40, tb=22, tf=-14, ct=70)
    return colpo("specialSide", [
        (0, "lin", dict(y=12, sp=14, neck=-6, brow=-12, hRx=20, hRy=-120, hRa=150, hLx=10, hLy=-140, hLa=-100, hLb=-1, tb=-8, tf=6)),
        (0.7, "io", dict(y=18, sp=18, hRx=10, hRy=-116, hLx=2, hLy=-150)),
        (1, "snap", slide),
        (1.5, "io", dict(slide, tb=16, tf=-10, ct=60)),
        (2, "io", dict(slide, tb=20, tf=-14, ct=70)),
        (2.4, "out", dict(x=2, y=14, sp=6, hRx=50, hRy=-110, hRa=-40, hLx=20, hLy=-128, hLa=-60, pRx=A.REST["pRx"] + 20, pLx=A.REST["pLx"] - 14,
                          pLy=A.REST["pLy"], pLa=A.REST["pLa"], tb=4, tf=-2, ct=20)),
        (2.75, "io", dict(x=0, y=2, sp=-6, head=-14, jaw=4, brow=-14, hRx=34, hRy=-136, hRa=-60, hLx=14, hLy=-128, hLa=-170, hLb=-1, fL=80, ct=4)),  # si sistema il frac
        (3, "io", GUARD)])


def special_down():
    # Fermata: la mano aperta in avanti ("silenzio!"), la bacchetta alta e ferma, occhi chiusi e mento su.
    # Tiene la pausa tremando appena; poi l'attacco del "tutti": giù la bacchetta in avanti
    hold = dict(sp=-8, neck=-4, head=-16, brow=-18, lid=24, jaw=-2, hRx=24, hRy=-190, hRa=-100, fR=80,
                hLx=50, hLy=-138, hLa=-90, hLb=-1, fL=-20, tL=-30, tb=-4, tf=4, ct=0)
    shake = [(1 + k / 4, "io", dict(hRx=24 + (3 if k % 2 else -3), hLy=-138 + (2 if k % 2 else -2), head=-16 + (2 if k % 2 else -2))) for k in range(1, 4)]
    return colpo("specialDown", [(0, "lin", hold), (1, "out", dict(jaw=0))] + shake + [
        (2, "io", dict(hRx=24, hLy=-138, head=-16)),
        (2.25, "snap", dict(x=8, sp=18, neck=-8, head=-6, lid=0, jaw=10, brow=-20, hRx=62, hRy=-112, hRa=10, hLx=30, hLy=-104, hLa=110, fL=40, tL=0, tb=12, tf=-10, ct=30)),
        (2.5, "out", dict(x=10, sp=20, hRx=64, hRy=-106, hRa=18)),
        (3, "io", GUARD)])


VINE = (0, -167)  # dove la mano prende la liana, rispetto ai piedi: come Bonobot (supreme_view.gd)


def supreme():
    # Gran Finale (suprema "drop"): salta e afferra la liana col pugno della bacchetta, la tira con tutto il peso, capriola
    # all'indietro, atterra in posa con la bacchetta alta (l'attacco!), e all'impatto del pianoforte dà il colpo
    # di bacchetta più grande della sua vita. Poi l'inchino al pubblico. Fasi: salto, tirata e capriola cadono in
    # leapMs, pullMs e flipMs della suprema; 1 = impatto
    sp_ = GAME_CH["supremeAttack"]
    drop = next(c for k, c in GAME["characters"].items() if k == CID)["supreme"]
    st = float(sp_["startupMs"])
    ph = lambda ms: ms / st
    t_leap, t_pull = ph(drop["leapMs"]), ph(drop["leapMs"] + drop["pullMs"])
    t_flip = ph(drop["leapMs"] + drop["pullMs"] + drop["flipMs"])
    vx, vy = VINE
    keys = [
        (0, "lin", dict(y=20, hips=12, sp=16, neck=-8, head=-10, brow=-16, jaw=4, hRx=10, hRy=-90, hRa=120, hLx=-10, hLy=-80, hLa=130, hLb=-1,
                        pRx=A.REST["pRx"] + 8, pLx=A.REST["pLx"] - 8, tb=-10, tf=8)),
        (t_leap * 0.45, "out", dict(y=-8, hips=-6, sp=-14, neck=-12, head=-26, jaw=8, hRx=vx + 14, hRy=vy - 10, hRa=-80, fR=-10,
                                    hLx=-40, hLy=-120, hLa=-160, fL=-20, **AIR_LEGS, ct=-20, tb=14, tf=-10)),
        (t_leap, "io", dict(y=0, sp=-6, head=-22, hRx=vx + 4, hRy=vy + 6, hRa=-92, fR=80, hLx=-44, hLy=-130, hLa=-170, tb=6, tf=-4, ct=-10)),
        (t_leap + (t_pull - t_leap) * 0.6, "snap", dict(y=0, sp=12, neck=-6, head=-12, jaw=12, brow=-20, hRy=vy + 28, hLx=-50, hLy=-150, hLa=-130,
                                                         lRu=40, lRl=130, lLu=50, lLl=128, ct=20)),
        (t_pull, "io", dict(sp=2, head=-18, jaw=4, hRy=vy + 12)),
    ]
    tuck = dict(sp=28, neck=10, head=10, aRu=-20, aRl=-70, aRh=-80, aLu=30, aLl=-60, aLh=-50, lRu=-20, lRl=95, lRf=10, lLu=-5, lLl=100, lLf=15,
                tb=20, tf=-10, lid=20, ct=30)
    out_keys = chiavi(keys)
    n = 6
    for k in range(1, n + 1):  # la capriola all'indietro, raccolto, la bacchetta tesa che disegna il cerchio
        u = k / n
        p = dict(ZERO, **tuck, spin=-360 * A.smooth(u), y=-34 * math.sin(math.pi * u))
        b, r = A.costruisci(girato(p))
        out_keys.append({"t": t_pull + (t_flip - t_pull) * u, "e": "lin", "bones": b, "root": list(r)})
    cue = dict(GUARD, y=6, sp=-14, neck=-6, head=-22, brow=-20, jaw=4, hRx=30, hRy=-196, hRa=-100, hLx=-30, hLy=-176, hLa=-120, hLb=-1, fL=-20, tL=-20,
               pRx=A.REST["pRx"] + 14, pLx=A.REST["pLx"] - 12, tb=-6, tf=6, ct=-6)
    down = dict(cue, x=8, y=16, sp=30, neck=-12, head=-4, jaw=14, brow=-22, lid=0, hRx=66, hRy=-80, hRa=40, hLx=-50, hLy=-90, hLa=160,
                tb=20, tf=-16, ct=46)
    bow = dict(ZERO, x=-2, y=4, hips=16, sp=48, neck=8, head=18, lid=24, brow=-6, jaw=4, hRx=34, hRy=-104, hRa=170, fR=70,
               hLx=-56, hLy=-112, hLa=-170, hLb=-1, fL=-10, pRx=A.REST["pRx"] + 6, pLx=A.REST["pLx"] - 12, tb=-18, tf=18, ct=-10)
    rest = [
        (t_flip, "out", dict(cue, y=14, sp=6, head=-8, hRx=40, hRy=-120, hRa=-40, hLx=-20, hLy=-110, hLa=170)),
        (t_flip + (1 - t_flip) * 0.45, "io", cue),
        (0.97, "out", dict(cue, y=2, sp=-18, hRx=24, hRy=-200, hRa=-110)),
        (1, "snap", down),
        (1.6, "out", dict(down, y=18, sp=34, hRx=70, hRy=-72, hRa=50)),
        (2, "io", dict(down, y=12, sp=26)),
        (2.4, "io", bow),
        (2.85, "hold", dict(bow, sp=50)),
        (3, "io", GUARD),
    ]
    cur = dict(cue)
    for t, e, p in rest:
        cur = dict(cur, **p)
        b, r = A.costruisci(cur)
        out_keys.append({"t": t, "e": e, "bones": b, "root": list(r)})
    return {"time": "phase", "spec": spec("supreme"), "keys": out_keys}


# ---------------------------------------------------------------- muoversi, aria, bordo, colpito
def idle():
    # In guardia tiene il tempo: quattro battute di bacchetta in 2 s, il petto che respira, un battito di ciglia
    keys = [(0, "io", {})]
    for b in range(4):
        t = b * 500
        keys.append((t + 110, "out", dict(hRa=-34, hRy=GUARD["hRy"] + 5, head=-6, y=0.8 if b % 2 else 0, tf=-3)))
        keys.append((t + 380, "io", dict(hRa=-60, hRy=GUARD["hRy"], head=-8, y=0, tf=1)))
    keys.insert(6, (1330, "io", dict(lid=28)))
    keys.insert(7, (1420, "io", dict(lid=0)))
    keys.sort(key=lambda k: k[0])
    keys.append((2000, "io", GUARD))
    return tempo(2000, True, chiavi(keys))


def corsa(n, speed, duty, lean, bob, lift, swing, baton, tails, hair=6):
    """Corsa in piedi (come animazioni_lottatore.corsa): la sinistra oscilla, la destra dirige tenendo il tempo."""
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
        w = TAU * t / L
        pose = dict(ZERO, hips=lean * 0.5, sp=lean - 6 + 2 * s(2 * w), neck=-lean * 0.5, head=-8 - lean * 0.3 + 2 * s(2 * w + 1),
                    brow=-8, y=-bob * abs(s(w)), ct=tails + 10 * s(2 * w + 1.2), tb=hair + 6 * s(2 * w + 0.8), tf=-hair * 0.6 - 4 * s(2 * w + 1.1))
        corpo, radice = _costruisci(pose)
        m = A.sk.fk(corpo, radice)
        for side in ("R", "L"):
            hx = m[f"thigh_{side}"][0][0]
            x, y = passo(t, phase[side], hx + 6)
            pose[f"p{side}x"], pose[f"p{side}y"], pose[f"p{side}b"] = x, y - 12, 1
            pose[f"p{side}a"] = A.REST[f"p{side}a"] - (25 if y < -2 else 0)
        a = 85 - swing * math.sin(w + math.pi * 2)
        pose["aLu"], pose["aLl"], pose["aLh"], pose["fL"] = a, a - 75, a - 70, 50
        bx, by, ba = baton
        pose.update(hRx=bx + 4 * s(2 * w), hRy=by - 5 * s(2 * w) - bob * abs(s(w)), hRa=ba + 22 * s(2 * w), hRb=-1, fR=70)
        out.append(A.costruisci(pose))
    return out


def walk():
    # Passetti svelti e impettiti: la bacchetta batte il tempo a ogni passo, le code del frac ballonzolano
    return tempo(10 * 1000 / 24, True, ogni(corsa(10, A.GROUND_SPEED * 1.08, 0.42, 6, 4, 18, 26, (38, -132, -60), 14), 1, 24))


def dash():
    # Corsa: piegato in avanti, la bacchetta puntata avanti come una lancia, criniera e code al vento
    return tempo(8 * 1000 / 24, True, ogni(corsa(8, 560 * 2 * 1.08, 0.36, 20, 6, 30, 44, (52, -112, -14), 55, hair=18), 1, 24))


def jump():
    return tempo(7 * 1000 / 24, False, chiavi([
        (0, "lin", dict(y=10, sp=12, neck=-4, head=-4, hRx=34, hRy=-104, hRa=10, hLx=-20, hLy=-92, hLa=140, ct=-8, tb=-8, tf=6)),
        (110, "out", dict(y=-8, sp=-12, neck=-6, head=-18, jaw=6, hRx=28, hRy=-196, hRa=-80, hLx=-24, hLy=-160, hLa=-130, hLb=-1,
                          lRu=70, lRl=100, lRf=50, lLu=86, lLl=104, lLf=56, ct=-20, tb=-14, tf=10)),
        (290, "io", dict(y=-6, sp=-4, head=-12, jaw=2, hRx=34, hRy=-176, hRa=-70, hLx=-30, hLy=-140, hLa=-150,
                         lRu=40, lRl=122, lRf=30, lLu=62, lLl=116, lLf=34, ct=-10, tb=-4, tf=2))]))


def fall():
    # Cade piano, a braccia aperte come se dirigesse la caduta; criniera e code del frac salgono
    keys = []
    for i in range(4):
        t = i * 125
        k = 1 if i % 2 else -1
        keys.append((t, "io", dict(ARIA, y=-6, sp=4 + 2 * k, head=-10 + 2 * k, hRx=46 + 4 * k, hRy=-166 + 6 * k, hRa=-50 + 10 * k, hRb=-1,
                                   hLx=-36 - 4 * k, hLy=-160 - 6 * k, hLa=-140, hLb=-1, fL=-10, lRu=38 + 8 * k, lLu=56 - 8 * k,
                                   ct=48 + 8 * k, tb=14 + 4 * k, tf=-8 - 3 * k)))
    return tempo(500, True, chiavi(keys))


def double_jump():
    # Piroetta: una capriola in avanti a corpo raccolto con la bacchetta tesa, poi si apre a braccia larghe
    n = 10
    out = []
    for f in range(n):
        u = f / (n - 1)
        p = dict(ZERO, sp=26, neck=8, head=6, aRu=-10, aRl=-20, aRh=-30, aLu=150, aLl=110, aLh=100, fL=-10,
                 lRu=-10, lRl=100, lRf=10, lLu=5, lLl=104, lLf=15, tb=20, tf=-12, ct=40, lid=14, jaw=6)
        p["spin"] = 360 * A.ease_out(u)
        p["y"] = -30 - 10 * math.sin(math.pi * u) + 24 * A.smooth((u - 0.7) / 0.3)
        if u > 0.7:  # si apre verso la caduta
            k = A.smooth((u - 0.7) / 0.3)
            for key, v in dict(sp=4, neck=0, head=-10, aRu=-50, aRl=-40, aRh=-50, aLu=-140, aLl=-150, aLh=-160, lRu=70, lRl=118, lRf=26,
                               lLu=86, lLl=112, lLf=30, ct=48, lid=0, jaw=2).items():
                p[key] = A.lerp(p[key], v, k)
        out.append(A.costruisci(girato(p)))
    return tempo(n * 1000 / 24, False, ogni(out, 1, 24))


def land():
    return tempo(250, False, chiavi([
        (0, "lin", dict(y=18, sp=16, neck=-8, head=-6, brow=-8, hRx=48, hRy=-96, hRa=10, hLx=-40, hLy=-110, hLa=170, hLb=-1, ct=40, tb=14, tf=-10)),
        (70, "out", dict(y=24, sp=22, head=-10, hRx=50, hRy=-86, ct=30, tb=-8, tf=6)),
        (170, "out", dict(y=-2, sp=-8, neck=-2, head=-12, brow=-6, hRx=36, hRy=-140, hRa=-64, hLx=-10, hLy=-96, hLa=100, hLb=1, ct=-4, tb=-3, tf=2)),
        (250, "io", GUARD)]))


def hit():
    # Colpito: indietro col mento, bocca aperta, occhi strizzati; la criniera frusta in avanti e la bacchetta vola su
    return tempo(8 * 1000 / 24, False, chiavi([
        (0, "lin", dict(x=-8, y=4, sp=-24, neck=-8, head=-18, brow=-14, lid=26, jaw=10, hRx=-10, hRy=-176, hRa=-150, hLx=-30, hLy=-150, hLa=-160, hLb=-1,
                        fL=-20, pRx=A.REST["pRx"] - 4, pLx=A.REST["pLx"] - 8, tb=18, tf=16, ct=36)),
        (80, "out", dict(x=-10, sp=-28, head=-24, hRx=-14, hRy=-182, ct=44)),
        (333, "io", dict(GUARD, x=-4, y=2, sp=-8, head=-4, lid=6, ct=8))]))


def taunt():
    # L'inchino: un gran gesto con la bacchetta, poi giù a 90 gradi, la bacchetta sul petto e il braccio largo
    # dietro; resta inchinato a raccogliere gli applausi, si rialza col mento in su ("Grazie, grazie, troppo gentili!")
    bow = dict(x=-2, y=4, hips=16, sp=50, neck=8, head=18, lid=24, brow=-4, jaw=4, hRx=34, hRy=-104, hRa=170, fR=70,
               hLx=-58, hLy=-112, hLa=-170, hLb=-1, fL=-10, pRx=A.REST["pRx"] + 6, pLx=A.REST["pLx"] - 14, tb=-20, tf=20, ct=-14)
    return tempo(2000, False, chiavi([
        (0, "lin", {}),
        (260, "out", dict(y=-4, sp=-12, neck=-4, head=-20, brow=-16, jaw=8, hRx=48, hRy=-190, hRa=-130, hLx=-46, hLy=-150, hLa=-150, hLb=-1, fL=-20, tb=-8, tf=6)),
        (420, "io", dict(hRx=40, hRy=-180, hRa=-200)),  # un giro di bacchetta in aria
        (750, "io", bow),
        (1000, "io", dict(sp=54, head=22)),
        (1300, "io", dict(sp=50, head=18)),
        (1550, "out", dict(x=0, y=-2, hips=0, sp=-10, neck=-6, head=-22, lid=12, brow=-18, jaw=6, hRx=36, hRy=-140, hRa=-60, hLx=-10, hLy=-96, hLa=100, hLb=1, fL=40,
                           pRx=GUARD["pRx"], pLx=GUARD["pLx"], tb=10, tf=-8, ct=6)),
        (2000, "io", GUARD)]))


def shield():
    # Dentro la bolla: accucciato, la bacchetta di traverso davanti alla faccia tenuta con le due mani, occhi strizzati
    keys = []
    for i, t in enumerate((0, 500)):
        k = 1 if i else 0
        keys.append((t, "io", dict(y=14 + k * 2, hips=8, sp=16 + k * 2, neck=-4, head=8 + k * 2, brow=-14, lid=18, jaw=-2,
                                   hRx=44, hRy=-150 + k * 2, hRa=-150, hLx=56, hLy=-122 + k * 2, hLa=-120, hLb=-1, fL=80,
                                   pRx=A.REST["pRx"] + 12, pLx=A.REST["pLx"] - 10, tb=4 - 6 * k, tf=-3 + 4 * k, ct=6)))
    return tempo(1000, True, chiavi(keys))


STATI = {
    "idle": idle, "walk": walk, "dash": dash, "land": land, "hit": hit, "taunt": taunt, "shield": shield,
    "jump": jump, "fall": fall, "doubleJump": double_jump,
    "tumble": lambda: tempo(500, True, ogni([(dict(b, coat_tail=40), r) for b, r in A.tumble()], 2, 24)),
    "ledge": lambda: tempo(2000, True, ogni(A.ledge(), 6, 12, "io")),
    "climb": lambda: tempo(10 * 1000 / 24, False, da_fotogrammi(A.climb(), [(None, i, "io") for i in (0, 3, 6, 8, 9)], 24)),
    "grabbed": lambda: tempo(1000, True, ogni(A.grabbed(), 3, 12, "io")),
    "light": light, "heavy": heavy, "lightUp": light_up, "lightDown": light_down, "lightAir": light_air,
    "heavyUp": heavy_up, "heavyDown": heavy_down, "heavyAir": heavy_air, "recovery": recovery, "grab": grab, "throw": throw,
    "specialNeutral": special_neutral, "specialSide": special_side, "specialDown": special_down, "supreme": supreme,
}
# Le strisce: (fotogrammi, fps, ciclo, fotogramma d'impatto, ultimo fotogramma mostrato mentre il colpo prende)
STRISCE = {
    "idle": (24, 12, True, None, None), "walk": (10, 24, True, None, None), "dash": (8, 24, True, None, None),
    "jump": (7, 24, False, None, None), "fall": (12, 24, True, None, None), "doubleJump": (10, 24, False, None, None),
    "land": (6, 24, False, None, None), "hit": (8, 24, False, None, None), "tumble": (12, 24, True, None, None),
    "ledge": (24, 12, True, None, None), "climb": (10, 24, False, None, None), "taunt": (24, 12, False, None, None),
    "shield": (12, 12, True, None, None), "grabbed": (12, 12, True, None, None),
    "grab": (15, 24, False, 2, None), "throw": (8, 24, False, 0, None),
    "light": (9, 24, False, 2, 3), "heavy": (18, 24, False, 7, 9), "lightUp": (9, 24, False, 2, 3), "lightDown": (9, 24, False, 2, 3),
    "lightAir": (9, 24, False, 2, 4), "heavyUp": (18, 24, False, 7, 9), "heavyDown": (18, 24, False, 6, 8), "heavyAir": (17, 24, False, 6, 8),
    "recovery": (8, 24, False, 0, 4), "specialNeutral": (15, 24, False, 5, None), "specialSide": (15, 24, False, 4, 8),
    "specialDown": (16, 24, False, 2, 8), "supreme": (36, 24, False, 24, 25),
}


# ---------------------------------------------------------------- campionare
def campiona(st, t):
    ks = st["keys"]
    loop = st.get("loop", False)
    if t <= ks[0]["t"] and not loop:
        return ks[0]["bones"], ks[0]["root"]
    for a, b in zip(ks, ks[1:]):
        if t < b["t"]:
            return mescola(a, b, (t - a["t"]) / (b["t"] - a["t"]) if b["t"] > a["t"] else 1.0)
    if loop:
        a, b = ks[-1], ks[0]
        return mescola(a, b, (t - a["t"]) / max(1e-6, st["ms"] - a["t"] + b["t"]))
    return ks[-1]["bones"], ks[-1]["root"]


def mescola(a, b, u):
    w = ease(b["e"], u)
    giro = lambda d: (d + 180) % 360 - 180
    bones = {k: v + giro(b["bones"].get(k, 0) - v) * w for k, v in a["bones"].items()}
    return bones, [a["root"][i] + (b["root"][i] - a["root"][i]) * w for i in (0, 1)]


def tempo_fotogramma(st, i, n, fps, hit, end):
    """In che punto delle chiavi cade il fotogramma i della striscia: l'inverso di FighterPose.sprite_frame(), che
    stira l'avvio fino a hitFrame, mette hitFrame..activeEnd nella finestra attiva e il resto nel recupero."""
    if st["time"] != "phase":
        t = i * 1000.0 / fps
        return t % st["ms"] if st.get("loop") else t
    if i < hit:  # avvio: le fasi 0..1, campionate verso la fine di ogni fotogramma (si vede la carica)
        return (i + 0.7) / hit
    end = hit if end is None else end
    if i <= end:  # colpo acceso
        return 1 + (i - hit) / (end - hit + 1)
    return 2 + (i - end) / max(1, n - 1 - end)


def controlla(data):
    """Nel fotogramma d'impatto la punta della bacchetta (o una mano, un piede) è nella zona del colpo."""
    own = GAME_CH.get("attacks", {})
    fw, fh = GAME["fighter"]["width"], GAME["fighter"]["height"]
    errori = []
    for stato in A.HIT_ZONES:
        an = data["animations"].get(stato)
        if not an or "hitFrame" not in an:
            continue
        a = dict(GAME["attacks"][A.HIT_ZONES[stato]], **own.get(stato, {}))
        x0 = (a["boxX"] if a.get("boxX") is not None else fw / 2) * 2
        y0 = (a["boxY"] if a.get("boxY") is not None else -fh * 0.7) * 2
        x1, y1 = x0 + a["range"] * 2, y0 + a["height"] * 2
        fr = an["frames"][an["hitFrame"]]
        m = A.sk.fk(fr["bones"], tuple(fr["root"]))
        (hx, hy), ang, _ = m["hand_R"]
        tip = (hx + TIP * math.cos(ang), hy + TIP * math.sin(ang))
        punte = [tip] + [A.sk.punta(m, t) for t in A.TIPS + (A.BODY if stato in A.BODY_HITS else [])]
        if any(x0 <= x <= x1 and y0 <= y <= y1 for x, y in punte):
            print(f"  {stato}: colpisce (punta {tip[0]:.0f}, {tip[1]:.0f}; zona x {x0:.0f}..{x1:.0f}, y {y0:.0f}..{y1:.0f})")
        else:
            errori.append(f"{stato}: nel fotogramma {an['hitFrame']} niente nella zona x {x0:.0f}..{x1:.0f}, y {y0:.0f}..{y1:.0f} (punta {tip[0]:.0f}, {tip[1]:.0f})")
    if errori:
        sys.exit("Colpi fuori zona:\n" + "\n".join(errori))


def main():
    data = {"character": CID, "frame": list(A.FRAME), "feet": list(A.FEET),
            "units": "ossa in gradi rispetto al riposo (positivo = orario, y in giù); radice in pixel a 2x", "animations": {}}
    for name, (n, fps, loop, hit, end) in STRISCE.items():
        st = STATI[name]()
        frames = [campiona(st, tempo_fotogramma(st, i, n, fps, hit, end)) for i in range(n)]
        an = {"fps": fps, "loop": loop, "frames": [{"bones": {k: round(v, 2) for k, v in b.items()}, "root": [round(r[0], 2), round(r[1], 2)]} for b, r in frames]}
        if hit is not None:
            an["hitFrame"] = hit
        if end is not None:
            an["activeEnd"] = end
        data["animations"][name] = an
    controlla(data)
    json.dump(data, open(os.path.join(RIG, "animazioni.json"), "w"), separators=(",", ":"))
    print("scritto", os.path.join(RIG, "animazioni.json"))


if __name__ == "__main__":
    main()
