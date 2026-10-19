# Uso: python3 tools/rig/animazioni_nonnagina.py   (poi rendi_sprite.py per le strisce, export:godot per Godot)
# Le animazioni di Nonna Gina come POSE CHIAVE (#384 B4, rifatte per il rig in tempo reale in #404).
# È un po' curva (HUNCH), cammina piano, e i colpi li dà col mattarello che tiene nella mano vicina (il pezzo "pin"
# di genera_pezzi_lottatore.py, lungo PIN oltre il polso). Tiri e ciabatta con l'altra mano. Scheda: docs/mosse/nonnagina.md.
#
# Ogni stato è una lista di chiavi (tempo, curva, posa). La curva è quella del tratto che ARRIVA alla chiave:
#   lin, in (parte piano), out (arriva piano), io (piano-piano), snap (tiene e poi scatta), back (supera e torna), hold.
# Il tempo degli attacchi è in fasi agganciate ai numeri del server: 0..1 avvio (startupMs), 1..2 hitbox accesa
# (activeMs), 2..3 recupero fino a cooldownMs. Così l'impatto cade quando si accende la hitbox e resta fermo finché è
# accesa, qualunque siano i numeri. Gli altri stati hanno il tempo in ms (cicli o una volta sola).
#
# Scrive due file da una fonte sola:
#   <rig>/chiavi.json      le chiavi, che Godot interpola a tempo reale (rig_view.gd)
#   <rig>/animazioni.json  le stesse chiavi campionate a fotogrammi, per le strisce PNG (rendi_sprite.py): lobby,
#                          ritratto e ripiego senza rig. Le curve qui e in rig_view.gd devono restare uguali.
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
GAME = json.load(open(os.path.join(QUI, "..", "..", "godot", "data", "game.json"), encoding="utf-8"))
_costruisci = A.costruisci


def curva(p):
    q = dict(p)
    for k, v in HUNCH.items():
        q[k] = q.get(k, 0) + v
    return _costruisci(q)


A.costruisci = curva  # anche le pose prese da Bonobot e dai lottatori passano di qui
REST = A.polso({}, "R") | A.polso({}, "L")  # le mani a riposo con la schiena curva
FEET0 = dict(pRx=A.REST["pRx"], pLx=A.REST["pLx"], pRy=A.REST["pRy"], pLy=A.REST["pLy"], pRa=A.REST["pRa"], pLa=A.REST["pLa"])
ZERO = dict(x=0, y=0, hips=0, sp=0, neck=0, head=0, jaw=0, brow=0, lid=0, fR=0, fL=0, tR=0, tL=0, tb=0, tf=0, **FEET0)
CALMA = dict(ZERO, **REST)  # la posa di riposo: ogni colpo ci torna, così il passaggio al fermo non salta
AIR_HANDS = A.polso(A.FALL_POSE(0), "R") | A.polso(A.FALL_POSE(0), "L")
ARIA = dict(ZERO, **{k: v for k, v in A.FALL_POSE(0).items() if not k.startswith("a")}, **AIR_HANDS)
SCHIENA = dict(hLx=-22, hLy=-108, hLa=175, fL=40)  # la mano sulla schiena: dopo un colpo forte si tiene i reni


# ---------------------------------------------------------------- curve (uguali a RigView.ease in rig_view.gd)
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


def fase(ms, spec):
    """Il tempo in fasi (0..3) dopo ms dall'inizio dell'attacco: come RigView.phase in rig_view.gd."""
    s, a = spec["startupMs"], spec["activeMs"]
    tot = max(spec["cooldownMs"], s + a)
    if ms < s:
        return ms / s
    if ms < s + a:
        return 1 + (ms - s) / a
    return min(3.0, 2 + (ms - s - a) / max(1.0, tot - s - a))


# ---------------------------------------------------------------- le chiavi
def chiavi(lista, base=CALMA, aria=False):
    """[(t, curva, posa piatta)] -> [{t, e, bones, root}]: ogni posa parte dalla precedente (i parametri non scritti
    restano), poi passa dalle IK. In aria le gambe stanno raccolte come nella caduta."""
    out, cur = [], dict(base)
    for t, e, p in lista:
        cur = dict(cur, **p)
        b, r = A.costruisci(dict(cur, **A.AIR_LEGS) if aria else cur)
        out.append({"t": t, "e": e, "bones": b, "root": list(r)})
    return out


def da_fotogrammi(frames, scelta, fps=None):
    """Chiavi prese da pose già fatte (salti, bordo, capriole di Bonobot e dei lottatori): scelta = [(t, indice, curva)];
    con fps il tempo è l'indice diviso fps, in ms."""
    out = []
    for t, i, e in scelta:
        b, r = frames[i]
        out.append({"t": t if fps is None else i * 1000.0 / fps, "e": e, "bones": b, "root": list(r)})
    return out


def ogni(frames, passo, fps, e="lin"):
    return da_fotogrammi(frames, [(None, i, e) for i in range(0, len(frames), passo)], fps)


def spec(kind):
    """I tempi di un attacco per Nonna Gina, come FighterPose.attack_spec() in Godot."""
    c = GAME["characters"][CID]
    if kind.startswith("special"):
        a = c["specialAttacks"][kind]
    else:
        a = dict(GAME["attacks"][kind], **(c.get("attacks", {}).get(kind) or {}))
    return {k: float(a.get(k) or 0) for k in ("startupMs", "activeMs", "cooldownMs")}


def colpo(kind, lista, aria=False, base=None):
    return {"time": "phase", "spec": spec(kind), "keys": chiavi(lista, base or (ARIA if aria else CALMA), aria)}


def tempo(ms, loop, keys):
    return {"time": "ms", "ms": ms, "loop": loop, "keys": keys}


# ---------------------------------------------------------------- colpi normali (fasi: 0 avvio, 1 impatto, 2 fine hitbox, 3 fine)
def light():
    # Botta di punta (avvio 50 ms): il mattarello tirato indietro sopra la spalla, poi dritto in avanti
    return colpo("light", [
        (0, "lin", dict(y=4, sp=-6, brow=-10, hRx=6, hRy=-140, hRa=-150, tb=-6, tf=4)),
        (0.6, "out", dict(y=5, sp=-9, hRx=0, hRy=-142, hRa=-156)),
        (1, "snap", dict(x=8, y=2, sp=10, neck=-6, jaw=6, brow=-14, hRx=86, hRy=-104, hRa=0, tb=8, tf=-6)),
        (1.2, "out", dict(x=11, sp=13, hRx=94, hRy=-101, hRa=5)),
        (2, "io", dict(x=9, sp=11, hRx=90, hRy=-103, hRa=2)),
        (2.5, "io", dict(x=3, sp=4, jaw=0, hRx=52, hRy=-98, hRa=60, tb=2, tf=-2)),
        (3, "io", CALMA)])


def heavy():
    # Mattarellata a due mani (avvio 320 ms): sulle punte col mattarello dietro la testa, una pausa, giù di peso.
    # Poi resta piegata un attimo e si raddrizza tenendosi la schiena
    up = dict(y=-6, sp=-14, neck=8, head=6, brow=-16, hRx=-8, hRy=-212, hRa=-125, hLx=-2, hLy=-204, hLa=-115, fL=60, tb=-12, tf=10)
    return colpo("heavy", [
        (0, "lin", dict(y=6, sp=10, neck=-4, brow=-10, hRx=-22, hRy=-112, hRa=150, hLx=20, hLy=-110, hLa=120, tb=-6, tf=4)),
        (0.55, "io", up),
        (0.85, "out", dict(up, y=-10, sp=-18, neck=10, hRx=-16, hRy=-214, hLx=-10, hLy=-206, jaw=-4)),
        (1, "snap", dict(x=6, y=12, sp=22, neck=-12, head=-10, jaw=8, hRx=80, hRy=-112, hRa=35, hLx=72, hLy=-112, hLa=35, tb=12, tf=-10)),
        (1.25, "out", dict(y=16, sp=26, hRx=86, hRy=-100, hRa=45, hLx=78, hLy=-100, hLa=45)),
        (2, "io", dict(y=13, sp=23, hRx=82, hRy=-108, hRa=38, hLx=74, hLy=-108, hLa=38)),
        (2.3, "io", dict(y=10, sp=18, head=-4, jaw=2, hRx=70, hRy=-100, hRa=60, hLx=62, hLy=-102, hLa=60, tb=4, tf=-4)),
        (2.7, "io", dict(x=2, y=2, sp=-8, neck=4, head=2, jaw=4, brow=-12, hRx=40, hRy=-90, hRa=110, **SCHIENA)),
        (3, "io", CALMA)])


def light_up():
    # Mattarello all'insù (avvio 60 ms): si abbassa e lo porta sopra la testa da davanti a dietro
    return colpo("lightUp", [
        (0, "lin", dict(y=8, sp=8, neck=4, head=6, brow=-8, hRx=60, hRy=-74, hRa=60, tb=-6, tf=4)),
        (1, "snap", dict(y=-6, sp=-12, neck=-12, head=-26, jaw=6, brow=-14, hRx=26, hRy=-210, hRa=-95, hLx=-6, hLy=-96, hLa=110, tb=10, tf=-8)),
        (1.2, "out", dict(y=-8, hRx=12, hRy=-214, hRa=-112)),
        (2, "io", dict(y=-6, hRx=2, hRy=-208, hRa=-124)),
        (2.5, "io", dict(y=0, sp=-2, head=-8, jaw=0, hRx=30, hRy=-150, hRa=-40)),
        (3, "io", CALMA)])


def light_down():
    # Colpetto alle caviglie (avvio 50 ms): giù sulle ginocchia, il mattarello radente
    feet = dict(pRx=A.REST["pRx"] + 12, pLx=A.REST["pLx"] - 10)
    return colpo("lightDown", [
        (0, "lin", dict(y=20, hips=12, sp=20, neck=-14, head=-10, brow=-10, hRx=20, hRy=-50, hRa=160, hLx=40, hLy=-60, hLa=90, tb=-8, tf=6, **feet)),
        (1, "snap", dict(x=10, y=34, hips=22, sp=34, neck=-26, head=-18, jaw=4, hRx=100, hRy=-26, hRa=5, tb=8, tf=-8)),
        (1.2, "out", dict(x=12, hRx=108, hRy=-22)),
        (2, "io", dict(x=11, hRx=104, hRy=-24)),
        (2.5, "io", dict(x=4, y=18, hips=10, sp=18, neck=-10, head=-6, jaw=0, hRx=60, hRy=-60, hRa=70)),
        (3, "io", CALMA)])


def light_air():
    # Rovescio in aria (avvio 50 ms): le gambe raccolte, il mattarello parte da dietro la spalla
    return colpo("lightAir", [
        (0, "lin", dict(sp=-4, head=-6, brow=-10, hRx=-14, hRy=-138, hRa=-150, tb=-8, tf=6)),
        (1, "snap", dict(sp=10, neck=-6, head=-4, jaw=6, hRx=90, hRy=-110, hRa=-5, hLx=-20, hLy=-92, hLa=150, tb=8, tf=-8)),
        (1.2, "out", dict(sp=13, hRx=96, hRy=-100, hRa=10)),
        (2, "io", dict(sp=11, hRx=94, hRy=-104, hRa=5)),
        (3, "io", ARIA)], aria=True)


def heavy_up():
    # Mattarellata al cielo (avvio 280 ms): giù accucciata col mattarello basso, poi su dritta a braccio teso
    low = dict(y=18, hips=8, sp=18, neck=-6, brow=-12, hRx=60, hRy=-50, hRa=100, hLx=40, hLy=-60, hLa=100, tb=-8, tf=6,
               pRx=A.REST["pRx"] + 8, pLx=A.REST["pLx"] - 8)
    return colpo("heavyUp", [
        (0, "lin", low),
        (0.8, "out", dict(y=26, sp=24, neck=-10, hRx=56, hRy=-40)),
        (1, "snap", dict(y=-10, hips=-4, sp=-12, neck=-10, head=-22, jaw=8, brow=-16, hRx=24, hRy=-206, hRa=-90, hLx=-10, hLy=-120, hLa=150,
                         pRx=A.REST["pRx"], pLx=A.REST["pLx"], tb=14, tf=-12)),
        (1.2, "out", dict(y=-12, hRx=12, hRy=-210, hRa=-104)),
        (2, "io", dict(y=-11, hRx=16, hRy=-208, hRa=-98)),
        (2.5, "io", dict(y=4, sp=4, head=-6, jaw=0, hRx=46, hRy=-140, hRa=-40, hLx=12, hLy=-90, hLa=80)),
        (3, "io", CALMA)])


def heavy_down():
    # Il mattarello rotolato radente (avvio 280 ms): si carica indietro, poi si butta in avanti bassa
    return colpo("heavyDown", [
        (0, "lin", dict(x=-8, y=14, sp=6, neck=2, brow=-14, hRx=-40, hRy=-120, hRa=-140, hLx=-30, hLy=-110, hLa=-130, tb=-10, tf=8)),
        (0.8, "out", dict(x=-11, y=18, sp=4, hRx=-46, hRy=-126, hLx=-36, hLy=-116)),
        (1, "snap", dict(x=14, y=40, hips=24, sp=40, neck=-36, head=-24, jaw=6, hRx=112, hRy=-28, hRa=0, hLx=96, hLy=-24, hLa=8,
                         pRx=A.REST["pRx"] + 30, pLx=A.REST["pLx"] - 22, tb=12, tf=-10)),
        (1.25, "out", dict(x=18, hRx=122, hRy=-24)),
        (2, "io", dict(x=16, hRx=118, hRy=-26)),
        (2.5, "io", dict(x=8, y=24, hips=12, sp=24, neck=-18, head=-10, jaw=0, hRx=70, hRy=-60, hRa=40, hLx=60, hLy=-70, hLa=60)),
        (2.8, "io", dict(x=2, y=4, hips=0, sp=-6, neck=2, head=0, brow=-10, hRx=34, hRy=-86, hRa=100, pRx=A.REST["pRx"], pLx=A.REST["pLx"], **SCHIENA)),
        (3, "io", CALMA)])


def heavy_air():
    # Mattarellata in aria (avvio 200 ms): il mattarello sopra la testa a due mani, poi giù in avanti
    return colpo("heavyAir", [
        (0, "lin", dict(sp=-10, neck=6, head=6, brow=-14, hRx=-10, hRy=-220, hRa=-120, hLx=-16, hLy=-200, hLa=-110, fL=60, tb=-12, tf=10)),
        (0.8, "out", dict(sp=-14, hRx=-18, hRy=-222, hLx=-22, hLy=-204)),
        (1, "snap", dict(sp=22, neck=-14, head=-12, jaw=8, hRx=104, hRy=-100, hRa=30, hLx=96, hLy=-96, hLa=35, tb=12, tf=-10)),
        (1.2, "out", dict(sp=26, hRx=108, hRy=-88, hRa=40, hLx=100, hLy=-86)),
        (2, "io", dict(sp=24, hRx=106, hRy=-92, hLx=98, hLy=-90)),
        (3, "io", ARIA)], aria=True)


def recovery():
    # Il recupero (subito attivo, 250 ms): sale avvitandosi a braccia alzate, dalle pose dei lottatori
    f = A.recovery()
    return {"time": "phase", "spec": spec("recovery"),
            "keys": da_fotogrammi(f, [(0, 0, "lin"), (1, 0, "hold"), (1.5, 3, "io"), (2, 5, "io"), (3, 5, "hold")])}


def grab():
    # Presa (avvio 100 ms): apre le mani, si allunga di scatto, le chiude e tira a sé; l'ultima chiave resta finché tiene
    return colpo("grab", [
        (0, "lin", dict(x=-4, sp=-4, brow=-10, hRx=40, hRy=-100, hRa=40, hLx=30, hLy=-96, hLa=40, fR=-10, fL=-10)),
        (1, "snap", A.GRAB_REACH),
        (1.3, "out", dict(fR=60, fL=60, tR=30)),
        (2, "io", dict(x=8)),
        (3, "io", A.GRAB_HOLD)])


def throw():
    # I quattro lanci (subito, 300 ms): dalla presa le braccia si aprono come per scagliare, poi al fermo
    f = A.throw()
    return {"time": "phase", "spec": spec("throwForward"),
            "keys": da_fotogrammi(f, [(0, 0, "lin"), (1, 0, "hold"), (2, 2, "out"), (3, 7, "io")])}


# ---------------------------------------------------------------- speciali e suprema
def special_neutral():
    # Polpetta (avvio 220 ms): la prende dal grembiule con l'altra mano, carica dietro e la lancia ad arco dal basso
    return colpo("specialNeutral", [
        (0, "lin", dict(sp=10, head=6, hLx=30, hLy=-100, hLa=90, fL=60, hRx=40, hRy=-90, hRa=120)),
        (0.45, "io", dict(y=6, sp=-4, neck=4, head=0, brow=-10, hLx=-40, hLy=-72, hLa=160, tb=-6, tf=4)),
        (0.8, "out", dict(y=8, sp=-6, hLx=-48, hLy=-66)),
        (1, "snap", dict(y=0, sp=12, neck=-6, jaw=8, hLx=74, hLy=-136, hLa=-40, fL=-10, tb=8, tf=-6)),
        (2, "hold", {}),
        (2.3, "out", dict(sp=14, hLx=84, hLy=-150)),
        (2.7, "io", dict(sp=6, jaw=2, brow=-4, hLx=56, hLy=-118, hLa=20)),
        (3, "io", CALMA)])


def special_side():
    # Ciabatta (avvio 180 ms): se la sfila dal piede, la alza dietro la testa e la tira dritta, di braccio
    return colpo("specialSide", [
        (0, "lin", dict(y=10, sp=20, neck=-8, brow=-10, hLx=-6, hLy=-40, hLa=100, fL=70, pLx=A.REST["pLx"] - 8, pLy=A.REST["pLy"] - 10)),
        (0.45, "io", dict(y=-2, sp=-12, neck=6, head=-6, brow=-14, hLx=-34, hLy=-196, hLa=-130, pLx=A.REST["pLx"], pLy=A.REST["pLy"], tb=-10, tf=8)),
        (0.85, "out", dict(sp=-15, hLx=-42, hLy=-200)),
        (1, "snap", dict(x=6, sp=18, neck=-10, head=-6, jaw=8, hLx=96, hLy=-128, hLa=10, fL=-10, tb=10, tf=-8)),
        (2, "hold", {}),
        (2.3, "out", dict(sp=22, hLx=100, hLy=-112)),
        (2.7, "io", dict(x=2, sp=8, jaw=0, brow=-6, hLx=60, hLy=-100, hLa=60)),
        (3, "io", CALMA)])


def special_down():
    # "Mangia!" (contrattacco): il mattarello di traverso davanti, lo scuote finché la finestra è aperta, poi una botta
    guard = dict(sp=-4, brow=-14, hRx=52, hRy=-128, hRa=-95, hLx=60, hLy=-112, hLa=-80, fL=60)
    shake = [(1 + k / 4, "io", dict(hRx=52 + (4 if k % 2 else -4), jaw=6 if k % 2 else 0, head=2 if k % 2 else -2)) for k in range(1, 4)]
    return colpo("specialDown", [(0, "lin", guard), (1, "out", dict(jaw=4))] + shake + [
        (2, "io", dict(hRx=52, jaw=0, head=0)),
        (2.3, "snap", dict(x=6, sp=14, neck=-8, jaw=8, hRx=92, hRy=-110, hRa=10, hLx=40, hLy=-100, hLa=90, fL=0)),
        (2.55, "out", dict(x=8, sp=16, hRx=96, hRy=-106)),
        (3, "io", CALMA)])


def supreme():
    # Pranzo della domenica (suprema a raffiche): si carica col grembiule pieno, poi una bracciata di polpette per ondata,
    # alternando le mani e urlando, l'ultima a due mani. Le chiavi seguono windupMs e waveEveryMs di characters.ts
    sp_ = GAME["characters"][CID]["supreme"]
    w0, dw, n = sp_["windupMs"], sp_["waveEveryMs"], sp_["waves"]
    carica = dict(y=10, sp=16, brow=-16, jaw=0, hRx=30, hRy=-70, hRa=100, hLx=10, hLy=-70, hLa=110, fL=60)
    lancio_R = dict(y=-4, sp=-12, jaw=12, brow=-20, hRx=60, hRy=-206, hRa=-70, hLx=-20, hLy=-90, hLa=150)
    lancio_L = dict(y=-4, sp=-12, jaw=12, brow=-20, hRx=30, hRy=-90, hRa=100, hLx=40, hLy=-210, hLa=-80)
    ricarica = dict(y=6, sp=10, jaw=2, brow=-14, hRx=30, hRy=-80, hRa=100, hLx=10, hLy=-80, hLa=110)
    keys = [(0, "lin", carica), (w0 * 0.75, "out", dict(y=14, sp=20, brow=-18, jaw=4))]
    for i in range(n):
        t = w0 + i * dw
        last = i == n - 1
        lancio = dict(lancio_R, hLx=40, hLy=-210, hLa=-80, y=-8, sp=-16, jaw=14) if last else (lancio_R if i % 2 == 0 else lancio_L)
        keys.append((t, "snap", lancio))
        keys.append((t + 90, "out", dict(lancio, y=lancio["y"] - 3, sp=lancio["sp"] - 3)))  # il braccio resta su: si vede il lancio
        keys.append((t + dw * 0.75, "io", dict(lancio, y=-10, sp=-18) if last else ricarica))
    end = w0 + (n - 1) * dw + sp_["endLagMs"]
    keys.append((end, "io", CALMA))
    return tempo(end + 50, False, chiavi(keys))


# ---------------------------------------------------------------- muoversi, aria, bordo, colpito
def idle():
    # Ferma: il peso che si sposta piano, il mattarello che ondeggia e un battito di ciglia. Il respiro lo fa Godot
    return tempo(2000, True, chiavi([
        (0, "io", {}),
        (700, "io", dict(y=1.5, sp=2, head=3, hRx=REST["hRx"] + 3, hRy=REST["hRy"] - 2, hRa=REST["hRa"] - 8, tb=2, tf=-1)),
        (1250, "io", dict(y=0.5, sp=1, head=1, hRx=REST["hRx"] + 1, hRy=REST["hRy"], hRa=REST["hRa"] - 2, tb=0, tf=0)),
        (1330, "io", dict(lid=28)),
        (1420, "io", dict(lid=0)),
        (1700, "io", dict(y=0, sp=0, head=0, hRx=REST["hRx"], hRy=REST["hRy"], hRa=REST["hRa"]))]))


def walk():
    # Passi corti e curvi: quattro pose del passo dei lottatori, le gambe in fila
    return tempo(10 * 1000 / 24, True, ogni(lott.corsa(A, n=10, speed=A.GROUND_SPEED * 0.85, duty=0.5, lean=10, bob=3, lift=12, swing=16), 2, 24))


def dash():
    return tempo(8 * 1000 / 24, True, ogni(lott.corsa(A, n=8, speed=560 * 2 * 0.85, duty=0.4, lean=18, bob=5, lift=22, swing=34), 2, 24))


def land():
    # Atterra di peso: si schiaccia, supera un poco tornando su e si assesta
    return tempo(250, False, chiavi([
        (0, "lin", dict(y=16, sp=16, neck=-8, head=-8, brow=-8, hRx=34, hRy=-64, hLx=24, hLy=-66, tb=-10, tf=8)),
        (70, "out", dict(y=22, sp=22, head=-12, hRx=36, hRy=-56, hLx=26, hLy=-58, tb=8, tf=-6)),
        (170, "out", dict(y=-2, sp=-3, neck=0, head=2, brow=0, tb=-3, tf=2, **REST)),
        (250, "io", CALMA)]))


def hit():
    # Colpita: il mattarello vola su, la testa indietro; poi si riprende brontolando
    return tempo(8 * 1000 / 24, False, chiavi([
        (0, "lin", dict(x=-8, y=4, sp=-22, neck=-8, head=-14, brow=-12, lid=20, jaw=6, hRx=-10, hRy=-120, hRa=-150, hLx=-20, hLy=-110, hLa=-160,
                        pRx=A.REST["pRx"] - 4, pLx=A.REST["pLx"] - 6, tb=-18, tf=14)),
        (80, "out", dict(x=-10, sp=-26, head=-20, hRx=-14, hRy=-126)),
        (333, "io", dict(x=-4, y=2, sp=-6, neck=0, head=4, brow=0, lid=0, jaw=0, tb=2, tf=-2, pRx=A.REST["pRx"], pLx=A.REST["pLx"], **REST))]))


def taunt():
    # Provocazione: alza il mattarello e lo agita brontolando ("Mangia che ti fa bene!"), l'altra mano sul fianco
    ms = 14 * 1000 / 12
    keys = [(0, "lin", {}), (200, "out", dict(sp=-4, brow=-14, jaw=6, hRx=56, hRy=-176, hRa=-80, hLx=24, hLy=-110, hLa=140))]
    for k, t in enumerate((350, 500, 650, 800)):
        keys.append((t, "io", dict(hRa=-50 if k % 2 == 0 else -92, jaw=0 if k % 2 == 0 else 10, head=4 if k % 2 == 0 else -6)))
    keys.append((ms, "io", CALMA))
    return tempo(ms, False, chiavi(keys))


def shield():
    return tempo(1000, True, da_fotogrammi(A.shield(), [(None, 0, "io"), (None, 6, "io")], 12))


STATI = {
    "idle": idle, "walk": walk, "dash": dash, "land": land, "hit": hit, "taunt": taunt, "shield": shield,
    "jump": lambda: tempo(7 * 1000 / 24, False, da_fotogrammi(A.jump(), [(None, 0, "lin"), (None, 3, "out"), (None, 6, "io")], 24)),
    "fall": lambda: tempo(500, True, ogni(A.fall(), 3, 24, "io")),
    "doubleJump": lambda: tempo(9 * 1000 / 24, False, ogni(A.double_jump(), 1, 24)),
    "tumble": lambda: tempo(500, True, ogni(A.tumble(), 2, 24)),
    "ledge": lambda: tempo(2000, True, ogni(A.ledge(), 6, 12, "io")),
    "climb": lambda: tempo(10 * 1000 / 24, False, da_fotogrammi(A.climb(), [(None, i, "io") for i in (0, 3, 6, 8, 9)], 24)),
    "grabbed": lambda: tempo(1000, True, ogni(A.grabbed(), 3, 12, "io")),
    "light": light, "heavy": heavy, "lightUp": light_up, "lightDown": light_down, "lightAir": light_air,
    "heavyUp": heavy_up, "heavyDown": heavy_down, "heavyAir": heavy_air, "recovery": recovery, "grab": grab, "throw": throw,
    "specialNeutral": special_neutral, "specialSide": special_side, "specialDown": special_down, "supreme": supreme,
}
# Le strisce: (fotogrammi, fps, ciclo, fotogramma d'impatto) come in characters.ts; i fotogrammi d'impatto non cambiano
STRISCE = {
    "idle": (24, 12, True, None), "walk": (10, 24, True, None), "jump": (7, 24, False, None), "fall": (12, 24, True, None),
    "light": (9, 24, False, 2), "heavy": (18, 24, False, 8), "hit": (8, 24, False, None), "doubleJump": (9, 24, False, None),
    "tumble": (12, 24, True, None), "ledge": (24, 12, True, None), "climb": (10, 24, False, None), "land": (6, 24, False, None),
    "taunt": (14, 12, False, None), "dash": (8, 24, True, None), "shield": (12, 12, True, None), "grab": (15, 24, False, 2),
    "throw": (8, 24, False, 0), "grabbed": (12, 12, True, None), "lightUp": (8, 24, False, 2), "lightDown": (8, 24, False, 2),
    "lightAir": (8, 24, False, 2), "heavyUp": (19, 24, False, 7), "heavyDown": (18, 24, False, 6), "heavyAir": (17, 24, False, 5),
    "recovery": (6, 24, False, 0), "specialNeutral": (15, 24, False, 5), "specialSide": (13, 24, False, 4),
    "specialDown": (16, 24, False, 1), "supreme": (31, 24, False, None),
}


# ---------------------------------------------------------------- campionare (uguale a RigView.sample in rig_view.gd)
def campiona(st, t):
    ks = st["keys"]
    loop = st.get("loop", False)
    if t <= ks[0]["t"] and not loop:
        return ks[0]["bones"], ks[0]["root"]
    for a, b in zip(ks, ks[1:]):
        if t < b["t"]:
            return mescola(a, b, (t - a["t"]) / (b["t"] - a["t"]) if b["t"] > a["t"] else 1.0)
    if loop:  # dopo l'ultima chiave si torna alla prima
        a, b = ks[-1], ks[0]
        return mescola(a, b, (t - a["t"]) / max(1e-6, st["ms"] - a["t"] + b["t"]))
    return ks[-1]["bones"], ks[-1]["root"]


def mescola(a, b, u):
    w = ease(b["e"], u)
    giro = lambda d: (d + 180) % 360 - 180
    bones = {k: v + giro(b["bones"].get(k, 0) - v) * w for k, v in a["bones"].items()}
    return bones, [a["root"][i] + (b["root"][i] - a["root"][i]) * w for i in (0, 1)]


def tempo_fotogramma(st, i, n, fps, hit):
    """In che punto delle chiavi cade il fotogramma i della striscia: l'inverso di FighterPose.sprite_frame()."""
    if st["time"] != "phase":
        t = i * 1000.0 / fps
        return t % st["ms"] if st.get("loop") else t
    s = st["spec"]
    start, tot = s["startupMs"], max(s["cooldownMs"], s["startupMs"] + s["activeMs"])
    first = 1 if hit else 0  # fromRest() in characters.ts: con hitFrame la striscia parte dal fotogramma 1
    if i < hit:
        ms = start * max(0, i - first) / max(1, hit - first)
    else:
        ms = start + (tot - start) * (i - hit) / max(1, n - 1 - hit)
    return fase(ms, s)


def controlla(data):
    """Nel fotogramma d'impatto la punta del mattarello (o una mano) è nella zona del colpo, come per Bonobot."""
    own = GAME["characters"][CID].get("attacks", {})
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
        punte = [A.sk.punta(m, t) for t in A.TIPS + (A.BODY if stato in A.BODY_HITS else [])] + [(hx + PIN * math.cos(ang), hy + PIN * math.sin(ang))]
        if any(x0 <= x <= x1 and y0 <= y <= y1 for x, y in punte):
            print(f"  {stato}: colpisce (zona x {x0:.0f}..{x1:.0f}, y {y0:.0f}..{y1:.0f})")
        else:
            errori.append(f"{stato}: nel fotogramma {an['hitFrame']} niente nella zona x {x0:.0f}..{x1:.0f}, y {y0:.0f}..{y1:.0f}")
    if errori:
        sys.exit("Colpi fuori zona:\n" + "\n".join(errori))


def tondo(bones):
    return {k: round(v, 2) for k, v in bones.items()}


def main():
    stati = {name: fn() for name, fn in STATI.items()}
    data = {"character": CID, "frame": list(A.FRAME), "feet": list(A.FEET),
            "units": "ossa in gradi rispetto al riposo (positivo = orario, y in giù); radice in pixel a 2x", "animations": {}}
    for name, (n, fps, loop, hit) in STRISCE.items():
        st = stati[name]
        frames = [campiona(st, tempo_fotogramma(st, i, n, fps, hit)) for i in range(n)]
        an = {"fps": fps, "loop": loop, "frames": [{"bones": tondo(b), "root": [round(r[0], 2), round(r[1], 2)]} for b, r in frames]}
        if hit is not None:
            an["hitFrame"] = hit
        data["animations"][name] = an
    controlla(data)
    json.dump(data, open(os.path.join(RIG, "animazioni.json"), "w"), separators=(",", ":"))
    out = {"character": CID, "units": data["units"] + "; t in fasi (0-3) per gli attacchi, in ms per gli altri", "states": {}}
    for name, st in stati.items():
        st = dict(st, keys=[{"t": round(k["t"], 2), "e": k["e"], "bones": tondo(k["bones"]), "root": [round(k["root"][0], 2), round(k["root"][1], 2)]} for k in st["keys"]])
        out["states"][name] = st
    json.dump(out, open(os.path.join(RIG, "chiavi.json"), "w"), separators=(",", ":"))
    print("scritti animazioni.json e chiavi.json in", RIG, {k: len(v["keys"]) for k, v in stati.items()})


if __name__ == "__main__":
    main()
