# Uso: python3 tools/sprite/elvedeo_dai_video.py <clip1.mp4> <clip2.mp4> <clip3.mp4> <cartella di lavoro> [anteprima.png stato]
# STATI=idle,walk rifà solo quegli stati; STATI=uccelli solo il piccione, l'aquila e la suprema senza aquila
# Elvedeo in groppa alla capra, dai tre video fatti da Nicola con Google Flow (1280x720, 24 fps, 240 fotogrammi,
# sfondo verde pieno, camera ferma, di profilo verso destra). Lo stesso metodo di egiainuso_dal_video.py, con due
# differenze:
# - clip 2 (speciali) e clip 3 (suprema: la capra diventa elefante e il piccione aquila) si usano così come sono;
#   nella 3 l'elefante a metà si gira a sinistra e quei fotogrammi si specchiano;
# - nella clip 1 (mosse base) Flow ha messo Elvedeo a piedi accanto alla capra. Si rimonta: la capra della clip 1
#   (girata a destra se guarda a sinistra) con sopra Elvedeo seduto, ritagliato da un fermo della clip 2, che segue
#   la schiena della capra; nei colpi col bastone il busto è quello di Elvedeo a piedi della clip 1, tagliato in vita.
# Il video non va nella repo. Servono ffmpeg, Pillow, numpy e scipy, solo per rifarlo.
import os, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

CLIPS, WORK = sys.argv[1:4], sys.argv[4]
OUT = os.path.join(os.path.dirname(__file__), "../../public/assets/characters/elvedeo")
FW, FH, FOOT_Y = 440, 300, 276  # fotogramma e piedi: copiati in characters.ts (largo per l'elefante e lo schianto)
SCALE = 0.4  # Elvedeo in sella nel video è alto 525 px, nel fotogramma 210 (105 px di mondo con scale 0.5)
GROUND, CENTER = 650, 620  # dove tocca terra la capra e il centro del fermo, nel video
BG = np.array([10, 167, 76], np.float32)  # il verde dello sfondo
OUTLINE = np.array([236, 230, 214], np.float32)  # il contorno chiaro, come gli altri lottatori

# Elvedeo seduto, ritagliato dal fermo della clip 2: il poligono gira attorno a lui (piccione e piedi compresi)
RIDER_FRAME = 60
RIDER_POLY = [(478, 280), (500, 190), (520, 130), (560, 105), (640, 115), (665, 175), (690, 225), (660, 250), (650, 330),
              (670, 380), (690, 410), (680, 445), (665, 465), (700, 500), (690, 530), (590, 530), (590, 495), (610, 480),
              (600, 460), (560, 430), (530, 420), (515, 400), (510, 330), (490, 300)]
RIDER_SEAT = (560, 412)  # dove si siede, sulla schiena della capra
RIDER_HIP = 345  # sopra questa riga il busto, che nei colpi col bastone si sostituisce
RIDER_K = 1.08  # la capra della clip 1 è un po' più grande di quella della clip 2
TORSO_HIP = 405  # la vita di Elvedeo a piedi nella clip 1, sotto il berretto di tanto (vedi torso())
TORSO_TOP = 105
SPLIT = 595  # nella clip 1 Elvedeo a piedi sta a sinistra di qui, la capra a destra

R = lambda a, b, s=1: list(range(a, b + 1, s))
g = lambda *ii: [("g", i) for i in ii]  # capra della clip 1 con Elvedeo seduto
w = lambda *ii: [("w", i) for i in ii]  # come g, con la capra tenuta al centro: il trotto e il galoppo sul posto
t = lambda *ii: [("t", i) for i in ii]  # come g, col busto di Elvedeo della clip 1 (i colpi col bastone)
s = lambda *ii: [("s", i) for i in ii]  # clip 2
u = lambda *ii: [("u", i) for i in ii]  # clip 3
m = lambda *ii: [("m", i) for i in ii]  # clip 3 specchiata (l'elefante girato a sinistra)
n = lambda *ii: [("n", i) for i in ii]  # come u, senza l'aquila sul braccio: è partita con la U (vedi no_eagle())
nm = lambda *ii: [("nm", i) for i in ii]  # come m, senza l'aquila
# stato -> fotogrammi. "world": coordinate del video (terra fissa); "feet": piedi su footY (stati in aria)
PLAN = {
    # fuma, la capra rumina: avanti e indietro, così il ciclo non salta (nel video la capra scivola piano)
    "idle": dict(frames=s(*R(0, 18, 2), *range(16, 0, -2)), mode="world"),
    # un passo di galoppo intero (nella clip 1 si ripete ogni 13 fotogrammi, da 32 a 44): lento cammina, veloce corre
    "walk": dict(frames=w(*R(32, 44)), mode="world"),
    "dash": dict(frames=w(*R(32, 44)), mode="world"),
    "jump": dict(frames=g(48, 52, 56), mode="feet"),
    "fall": dict(frames=g(60, 64), mode="feet"),
    "land": dict(frames=g(68, 72), mode="world"),
    "light": dict(frames=t(*R(74, 90, 2)), mode="world"),  # colpetto col bastone in avanti
    "lightUp": dict(frames=t(*R(86, 98, 2)), mode="world"),  # il bastone in alto
    "lightDown": dict(frames=g(*R(76, 92, 2)), mode="world"),  # la testatina della capra
    "heavy": dict(frames=g(*R(98, 118, 2)), mode="world"),  # s'impenna e pesta con gli zoccoli
    "heavyUp": dict(frames=t(*R(116, 132, 2)), mode="world"),  # l'arco col bastone sopra la testa
    "heavyDown": dict(frames=g(*R(120, 142, 2)), mode="world"),  # scalcia
    "lightAir": dict(frames=g(*R(132, 146, 2)), mode="feet"),  # calcio in aria con gli zoccoli davanti
    "grab": dict(frames=t(*R(162, 174, 2)), mode="world"),
    "throw": dict(frames=t(*R(174, 186, 2)), mode="world"),
    "shield": dict(frames=t(178, 180, 182), mode="world"),  # le braccia incrociate davanti alla faccia
    "hit": dict(frames=t(*R(186, 194, 2)), mode="world"),
    "tumble": dict(frames=g(*R(194, 206, 2)), mode="feet"),  # rotola via con la capra
    "taunt": dict(frames=u(*R(0, 33, 3)), mode="world"),  # una boccata e la nuvola di fumo
    # Piccione: indica e il piccione parte. Quando si stacca dalla spalla lo disegna il gioco come proiettile
    # (piccione.png): qui resta solo Elvedeo
    "specialNeutral": dict(frames=s(18, 20, 22, 24, 26) + [("p", i) for i in R(30, 38, 2)], mode="world"),
    "specialSide": dict(frames=s(76, 82, 88, 94, 100, 106, 112, 116, 120, 122, 124, 126, 128, 132, 136, 140), mode="world"),  # Incornata
    "specialDown": dict(frames=s(*R(160, 196, 3)), mode="world"),  # Calcione: la nuvola dietro
    # Elefante: la boccata e la nuvola, l'elefante con l'aquila che barrisce e pesta, la proboscide, la nuvola
    "supreme": dict(frames=u(4, 12, 20, 28, 36, 44, 52) + u(64, 80, 88, 92, 96) + m(108, 112, 116) + u(200, 212, 224), mode="world"),
}
# La suprema dopo che con la U è partita l'aquila: gli stessi fotogrammi, ma Elvedeo col braccio teso e niente aquila.
# Non è uno stato: il gioco la scambia con "supreme" (SpinSupreme.eagle.after in characters.ts)
AFTER_EAGLE = dict(frames=u(4, 12, 20, 28, 36, 44, 52) + n(64, 80, 88, 92, 96) + nm(108, 112, 116) + u(200, 212, 224), mode="world")
PORTRAIT = ("s", 0)


def video_frames(n, clip):
    d = f"{WORK}/c{n}"
    os.makedirs(d, exist_ok=True)
    if not os.path.exists(f"{d}/000.png"):
        subprocess.run(["ffmpeg", "-v", "error", "-i", clip, "-start_number", "0", f"{d}/%03d.png"], check=True)
    return lambda i: Image.open(f"{d}/{i:03d}.png").convert("RGB")


C1, C2, C3 = (video_frames(n + 1, c) for n, c in enumerate(CLIPS))


def fg(im):
    p = np.asarray(im, np.float32)
    return p[..., 1] - np.maximum(p[..., 0], p[..., 2]) < 35


def components(mask):
    lab, n = ndi.label(mask)
    if not n:
        return lab, []
    idx = range(1, n + 1)
    sizes = ndi.sum(mask, lab, idx)
    cx = [c[1] for c in ndi.center_of_mass(mask, lab, idx)]
    return lab, list(zip(idx, sizes, cx))


def goat(i):
    """La capra della clip 1 girata a destra (immagine, maschera). Elvedeo a piedi sta a sinistra della capra."""
    im = C1(i)
    mask = fg(im)
    mask[:, :SPLIT] = False  # la capra non va mai a sinistra di qui, Elvedeo a piedi sì col bastone
    lab, comps = components(mask)
    best = max(comps, key=lambda c: c[1])
    mask = ndi.binary_fill_holes(lab == best[0])
    ys, xs = np.nonzero(mask)
    head_up = xs[ys < ys.min() + 25].mean()  # le corna sono il punto più alto: da che parte sta la testa
    if head_up < xs.mean():
        shift = int(round(2 * xs.mean() - (im.width - 1)))  # specchiata sul posto
        im = Image.fromarray(np.roll(np.asarray(im)[:, ::-1], shift, 1))
        mask = np.roll(mask[:, ::-1], shift, 1)
    return im, mask


def axis(mask):
    """Centro e inclinazione del tronco della capra: solo la parte alta, perché le zampe che corrono non lo spostino."""
    ys, xs = np.nonzero(mask)
    top = ys < ys.min() + 0.55 * (ys.max() - ys.min())
    ys, xs = ys[top], xs[top]
    c = np.array([xs.mean(), ys.mean()])
    w, v = np.linalg.eigh(np.cov(np.stack([xs - c[0], ys - c[1]])))
    ax = v[:, 1] if v[0, 1] >= 0 else -v[:, 1]
    return c, np.arctan2(ax[1], ax[0])


def rider():
    """Elvedeo seduto dal fermo della clip 2 (RGBA): tutto e solo le gambe."""
    im = C2(RIDER_FRAME)
    poly = Image.new("L", im.size, 0)
    ImageDraw.Draw(poly).polygon(RIDER_POLY, fill=255)
    a = np.asarray(poly, np.float32) / 255 * fg(im)
    full = np.dstack([np.asarray(im, np.float32), a * 255])
    legs = full.copy()
    legs[:RIDER_HIP, :, 3] = 0
    return full, legs


def torso(i):
    """Il busto di Elvedeo a piedi nella clip 1, tagliato in vita (RGBA) e la sua vita (x, y)."""
    im = C1(i)
    mask = fg(im)
    mask[:, SPLIT:] = False  # lui, il bastone e il piccione, non la capra
    lab, comps = components(mask)
    mask = np.isin(lab, [c[0] for c in comps if c[1] > 150])
    ys, xs = np.nonzero(mask)
    hip_y = ys.min() + (TORSO_HIP - TORSO_TOP)  # chinato o no, la vita sta sotto il berretto di tanto
    row = xs[(ys > hip_y - 30) & (ys < hip_y - 10)]
    hip = (float(np.median(row)) if len(row) else float(xs.mean()), float(hip_y))
    a = mask.astype(np.float32)
    a[int(hip_y) + 15 :] = 0  # sotto la vita: le gambe in piedi non servono
    a[int(hip_y) - 5 : int(hip_y) + 15] *= np.linspace(1, 0, 20)[:, None]  # sfuma sulla camicia di sotto
    return np.dstack([np.asarray(im, np.float32), a * 255]), hip


RIDER = None
GOAT0 = None
POSES = {}


def stamp(canvas, rgba, src_pt, dst_pt, k, angle):
    """Incolla rgba (scalato di k, ruotato di angle attorno a src_pt) con src_pt su dst_pt."""
    im = Image.fromarray(rgba.round().clip(0, 255).astype(np.uint8), "RGBA")
    im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
    big = Image.new("RGBA", (3000, 2000), (0, 0, 0, 0))
    big.paste(im, (round(1500 - src_pt[0] * k), round(1000 - src_pt[1] * k)))
    big = big.rotate(-np.degrees(angle), center=(1500, 1000), resample=Image.BICUBIC)
    x0, y0 = round(1500 - dst_pt[0]), round(1000 - dst_pt[1])
    canvas.alpha_composite(big.crop((x0, y0, x0 + canvas.width, y0 + canvas.height)))


def goat_at(i, centered):
    """La capra del fotogramma i: immagine e maschera già spostate dove sta nel gioco (centro e terra come il fermo)."""
    c0, _, _, shift0 = GOAT0
    im, mask = goat(i)
    dx, dy = shift0
    if centered is True:  # nella clip 1 la capra che galoppa avanza nel fotogramma: qui resta sul posto, come nel gioco
        dx += c0[0] - axis(mask)[0][0]
    elif centered is not None:  # una mossa: la capra parte dal centro al primo fotogramma e poi si muove come nel video
        dx += c0[0] - axis(goat(centered)[1])[0][0]
    dx, dy = int(round(dx)), int(round(dy))
    im = Image.fromarray(np.roll(np.asarray(im), (dy, dx), (0, 1)))
    return im, np.roll(mask, (dy, dx), (0, 1))


def pose(i, centered):
    """Centro e inclinazione del tronco, mediati sui fotogrammi vicini: il video trema, Elvedeo in sella no."""
    near = []
    for j in range(i - 2, i + 3):
        key = (j, centered)
        if key not in POSES:
            try:
                POSES[key] = axis(goat_at(j, centered)[1])
            except (FileNotFoundError, ValueError):
                POSES[key] = None
        if POSES[key] is not None:
            near.append(POSES[key])
    c = np.mean([n[0] for n in near], 0)
    a = float(np.mean([n[1] for n in near]))
    own = POSES[(i, centered)]
    return np.array([own[0][0], c[1]]) if centered is True else c, a


def mounted(i, with_torso, centered=None):
    global RIDER, GOAT0
    if RIDER is None:
        RIDER = rider()
        im0, m0 = goat(0)
        c0, a0 = axis(m0)
        xs = np.nonzero(m0.any(0))[0]
        sx = int(xs.min() + 0.32 * (xs.max() - xs.min()))  # la sella: a un terzo dalla coda, come nella clip 2
        seat0 = np.array([sx, np.nonzero(m0[:, sx])[0].min() + 8.0])
        # il fermo rimontato va dove sta il fermo della clip 2: corpo intero (capra e Elvedeo) centrato su CENTER,
        # zoccoli sulla terra GROUND
        GOAT0 = (c0, a0, seat0, (0.0, 0.0))
        probe = compose(im0, m0, c0, a0, False, 0)
        middle = lambda im: np.nonzero(fg(im).sum(0) >= 30)[0].mean()  # le colonne piene: corpo, non coda o fumo
        GOAT0 = (c0, a0, seat0, (middle(C2(RIDER_FRAME)) - middle(probe), GROUND - np.nonzero(m0.any(1))[0].max()))
    im, mask = goat_at(i, centered)
    c, a = pose(i, centered)
    return compose(im, mask, c, a, with_torso, i)


def compose(im, mask, c, a, with_torso, i):
    c0, a0, seat0, (sx0, sy0) = GOAT0
    da = float(np.clip(a - a0, -0.5, 0.5))  # la capra s'inclina: Elvedeo con lei, ma non si capovolge
    rot = np.array([[np.cos(da), -np.sin(da)], [np.sin(da), np.cos(da)]])
    seat = c + rot @ (seat0 + (sx0, sy0) - (c0 + (sx0, sy0)))
    canvas = Image.new("RGBA", im.size, (*BG.astype(int), 255))
    canvas.alpha_composite(Image.fromarray(np.dstack([np.asarray(im), mask * 255]).astype(np.uint8), "RGBA"))
    full, legs = RIDER
    if not with_torso:
        stamp(canvas, full, RIDER_SEAT, seat, RIDER_K, da)
        return canvas.convert("RGB")
    stamp(canvas, legs, RIDER_SEAT, seat, RIDER_K, da)
    body, hip = torso(i)
    body = np.roll(body, (int(round(sy0)), int(round(sx0))), (0, 1))
    hip = (hip[0] + sx0, hip[1] + sy0)
    # la vita del seduto, nello stesso riferimento della sella
    rider_hip = np.array([535.0, RIDER_HIP]) - np.array(RIDER_SEAT)
    stamp(canvas, body, hip, seat + rot @ (rider_hip * RIDER_K), RIDER_K * 0.95, da)
    return canvas.convert("RGB")


def mirrored(i):
    """Un fotogramma della clip 3 specchiato, col corpo centrato dove stava l'elefante girato a destra."""
    im = C3(i)
    xs = np.nonzero(fg(im).any(0))[0]
    shift = int(round(647 - (im.width - 1 - (xs.min() + xs.max()) / 2)))  # 647: il centro dell'elefante girato a destra
    return Image.fromarray(np.roll(np.asarray(im)[:, ::-1], shift, 1))


def alone(im):
    """Il fotogramma con solo il pezzo più grande (Elvedeo sulla capra): via il piccione in volo e il fumo staccato."""
    lab, comps = components(fg(im))
    keep = lab == max(comps, key=lambda c: c[1])[0]
    p = np.asarray(im).copy()
    p[~ndi.binary_dilation(keep, iterations=3)] = BG.astype(np.uint8)
    return Image.fromarray(p)


PIGEON_FRAMES = R(32, 38)  # nella clip 2 il piccione vola staccato verso destra (prima tocca il braccio teso)
PIGEON_W, PIGEON_H, PIGEON_K = 128, 110, 0.55  # fotogramma del proiettile e quanto si rimpicciolisce dal video
# nella clip 3 l'aquila vola staccata dall'elefante (girato a sinistra) tra 165 e 173 (prima si tuffa): specchiata guarda a destra,
# con gli artigli avanti. Avanti e indietro, così le ali battono
EAGLE_FRAMES = [*R(169, 173), *range(172, 169, -1)]
EAGLE_W, EAGLE_H, EAGLE_K = 280, 320, 0.7  # più grande del piccione: è l'aquila dell'elefante cresciuto


def flyer(im, pick, w, h, k):
    """Un uccello in volo staccato dal resto: fotogramma w x h col corpo al centro, rimpicciolito di k, col contorno.
    Il centro è quello del corpo (la maschera erosa: via le ali), così il disegno non balla sul rettangolo del colpo."""
    rgba, body = cut(im)
    lab, comps = components(body)
    bird = lab == max([c for c in comps if pick(c)], key=lambda c: c[1])[0]
    core = ndi.binary_erosion(bird, iterations=12)
    cy, cx = ndi.center_of_mass(core if core.any() else bird)
    rgba = rgba * ndi.binary_dilation(bird, iterations=3)[..., None]
    size = (round(rgba.shape[1] * k), round(rgba.shape[0] * k))
    sm = np.pad(resize(rgba, size), ((h, h), (w, w), (0, 0)))
    x0, y0 = round(cx * k + w - w / 2), round(cy * k + h - h / 2)  # + il margine aggiunto
    f = sm[y0 : y0 + h, x0 : x0 + w]
    a = f[..., 3] / 255
    ring = ndi.gaussian_filter(ndi.binary_dilation(a > 0.5, iterations=2).astype(np.float32), 0.6)
    al = a + ring * (1 - a)
    rgb = (f[..., :3] * a[..., None] + OUTLINE * ring[..., None] * (1 - a[..., None])) / np.maximum(al, 1e-3)[..., None]
    fr = np.dstack([rgb, al * 255]).round().clip(0, 255).astype(np.uint8)
    fr[0, 0] = 0
    return fr


def pigeon():
    """Il piccione che vola, ritagliato dalla clip 2: una striscia di fotogrammi centrati sul corpo."""
    pick = lambda c: c[2] > 760 and c[1] > 300  # a destra di Elvedeo
    return np.concatenate([flyer(C2(i), pick, PIGEON_W, PIGEON_H, PIGEON_K) for i in PIGEON_FRAMES], 1)


def eagle():
    """L'aquila che vola, dalla clip 3 specchiata: guarda a destra come il piccione."""
    pick = lambda c: c[2] < 1279 - 850 and 5000 < c[1] < 80000  # staccata, dietro l'elefante
    flip = lambda i: Image.fromarray(np.asarray(C3(i))[:, ::-1].copy())
    return np.concatenate([flyer(flip(i), pick, EAGLE_W, EAGLE_H, EAGLE_K) for i in EAGLE_FRAMES], 1)


EAGLE_DONOR = 168  # clip 3: l'aquila è appena partita, Elvedeo tende il braccio (specchiato: verso destra)


def beanie(p):
    """Il centro della banda rossa del berretto: da lì si allinea il busto (il collare rosso dell'elefante sta sotto)."""
    q = p.astype(int)
    red = (q[..., 0] > 150) & (q[..., 1] < 90) & (q[..., 2] < 90)
    red[380:] = False
    lab, comps = components(red)
    y, x = ndi.center_of_mass(red, lab, max(comps, key=lambda c: c[1])[0])
    return x, y


def no_eagle(im, clear):
    """Il fotogramma dell'elefante senza l'aquila: via il busto di Elvedeo e l'aquila sopra la vita, al loro posto il
    busto col braccio teso del fotogramma EAGLE_DONOR, allineato sul berretto. clear: fin dove a destra del berretto si
    toglie (nei fotogrammi specchiati l'aquila sta davanti a lui); oltre si incolla solo sul verde (la proboscide alzata)."""
    t = np.asarray(im).copy()
    d = np.asarray(C3(EAGLE_DONOR))[:, ::-1].copy()
    tx, ty = beanie(t)
    dx, dy = beanie(d)
    yy, xx = np.mgrid[0 : t.shape[0], 0 : t.shape[1]]
    waist = yy < ty + 150
    region = waist & (xx > tx - 320) & (xx < tx + clear)
    region |= (yy < ty + 175) & (xx > tx - 320) & (xx < tx - 120)  # la coda dell'aquila scende sotto la vita
    t[region & ndi.binary_dilation(fg(t), iterations=4)] = BG.astype(np.uint8)  # anche il bordo sfumato sul verde
    d = np.roll(d, (int(round(ty - dy)), int(round(tx - dx))), (0, 1))
    q = d.astype(int)
    pigeon_ = (q[..., 2] > q[..., 0] + 6) & (yy > ty + 90) & (xx < tx - 30)  # il piccione sulla groppa del donatore
    paste = fg(d) & waist & (xx > tx - 120) & (xx < tx + 260) & ~ndi.binary_dilation(pigeon_, iterations=4)
    paste &= region | ~fg(t)
    t[paste] = d[paste]
    return Image.fromarray(t)


def source(f):
    kind, i = f
    if kind == "g":
        return mounted(i, False, FIRST)
    if kind == "t":
        return mounted(i, True, FIRST)
    if kind == "w":
        return mounted(i, False, centered=True)
    if kind == "s":
        return C2(i)
    if kind == "p":
        return alone(C2(i))
    if kind == "u":
        return C3(i)
    if kind == "n":
        return no_eagle(C3(i), 130)
    if kind == "nm":
        return no_eagle(mirrored(i), 240)
    return mirrored(i)


def cut(im):
    """RGBA e maschera del corpo dal fotogramma su verde."""
    p = np.asarray(im, np.float32)
    r, gg, b = p[..., 0], p[..., 1], p[..., 2]
    d = gg - np.maximum(r, b)  # quanto è verde
    a = np.clip((48 - d) / 30, 0, 1)
    a[a < 0.08] = 0
    lab, comps = components(a > 0.3)
    small = [c[0] for c in comps if c[1] < 40]  # puntini staccati
    a[np.isin(lab, small)] = 0
    aa = np.maximum(a, 1e-3)[..., None]
    c = np.where(a[..., None] > 0.97, p, (p - (1 - aa) * BG) / aa)  # toglie il verde mescolato ai bordi
    c[..., 1] = np.minimum(c[..., 1], np.maximum(c[..., 0], c[..., 2]) + 8)
    return np.dstack([np.clip(c, 0, 255), a * 255]), a > 0.5


def resize(rgba, size):
    im = Image.fromarray(rgba.round().clip(0, 255).astype(np.uint8), "RGBA").convert("RGBa")
    return np.asarray(im.resize(size, Image.LANCZOS).convert("RGBA"), np.float32)


def place(rgba, body, mode):
    """Rimpicciolisce e mette nel fotogramma; poi il contorno chiaro attorno al corpo."""
    h, w = body.shape
    size = (round(w * SCALE), round(h * SCALE))
    sm = resize(rgba, size)
    sb = np.asarray(Image.fromarray((body * 255).astype(np.uint8)).resize(size, Image.LANCZOS), np.float32) / 255
    dx = FW / 2 - CENTER * SCALE
    if mode == "feet":
        rows = np.nonzero((sb > 0.5).sum(1) >= 2)[0]
        dy = FOOT_Y - (rows.max() + 1)
    else:
        dy = FOOT_Y - GROUND * SCALE
    dx, dy = round(dx), round(dy)
    frame = np.zeros((FH, FW, 4), np.float32)
    fb = np.zeros((FH, FW), np.float32)
    ys, xs = slice(max(0, dy), min(FH, dy + size[1])), slice(max(0, dx), min(FW, dx + size[0]))
    sy = slice(ys.start - dy, ys.stop - dy)
    sx = slice(xs.start - dx, xs.stop - dx)
    frame[ys, xs] = sm[sy, sx]
    fb[ys, xs] = sb[sy, sx]
    # contorno chiaro di 2 px attorno al corpo, ma non nelle fessure strette (#506, tools/sprite/apri_fessure.py)
    ring = ndi.gaussian_filter(ndi.binary_dilation(fb > 0.5, iterations=2).astype(np.float32), 0.6)
    ring[ndi.binary_closing(fb > 0.5, iterations=3, border_value=0) & (fb <= 0.5)] = 0
    a = frame[..., 3:] / 255
    rgb = frame[..., :3] * a + OUTLINE * ring[..., None] * (1 - a)
    alpha = a[..., 0] + ring * (1 - a[..., 0])
    rgb = rgb / np.maximum(alpha, 1e-3)[..., None]
    # sfuma vicino ai bordi: le nuvole della suprema e dello schianto escono dal fotogramma e non vanno tagliate dritte
    yy, xx = np.mgrid[0:FH, 0:FW]
    alpha *= np.clip(np.minimum(np.minimum(xx, FW - 1 - xx), np.minimum(yy, FH - 1 - yy)) / 16, 0, 1)
    out = np.dstack([rgb, alpha * 255]).round().clip(0, 255).astype(np.uint8)
    out[0, 0] = 0  # l'angolo in alto a sinistra trasparente (lo controlla assets.test.ts)
    return out


def save(rgba, path):
    """PNG a 256 colori con l'alfa: a colori pieni i file pesano il triplo."""
    im = Image.fromarray(rgba, "RGBA").quantize(256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
    im.save(path, optimize=True)


MIDDLE_OFFSET = -3  # il fermo (clip 2) ha il corpo pieno 3 px a sinistra del centro: le mosse rimontate uguale
FIRST = None  # il primo fotogramma della mossa che si sta facendo: lì la capra sta al centro


def strip(state):
    global FIRST
    spec = PLAN[state] if isinstance(state, str) else state
    FIRST = spec["frames"][0][1]
    frames = [place(*cut(source(f)), spec["mode"]) for f in spec["frames"]]
    if spec["frames"][0][0] in "gtw":
        # le mosse rimontate partono con il corpo intero (capra e Elvedeo) al centro del fotogramma, come il fermo
        cols = np.nonzero((frames[0][..., 3] > 128).sum(0) >= 30)[0]
        dx = int(round(FW / 2 + MIDDLE_OFFSET - cols.mean()))
        for f in frames:
            f[:] = np.roll(f, dx, 1)
            if dx > 0:
                f[:, :dx] = 0
            elif dx < 0:
                f[:, dx:] = 0
    return np.concatenate(frames, 1)


def portrait():
    rgba, body = cut(source(PORTRAIT))
    ys, xs = np.nonzero(body)
    top, xc = ys.min(), int(xs[ys < ys.min() + 120].mean())
    side = 230
    crop = np.zeros((side, side, 4), np.float32)
    x0 = xc - side // 2
    crop[6:] = rgba[top : top + side - 6, x0 : x0 + side]
    por = resize(crop, (146, 146))
    a = por[..., 3] / 255
    ring = ndi.gaussian_filter(ndi.binary_dilation(a > 0.5, iterations=2).astype(np.float32), 0.6)
    canvas = np.zeros((150, 150, 4), np.float32)
    rgb = por[..., :3] * a[..., None] + OUTLINE * ring[..., None] * (1 - a[..., None])
    al = a + ring * (1 - a)
    canvas[2:148, 2:148, :3] = rgb / np.maximum(al, 1e-3)[..., None]
    canvas[2:148, 2:148, 3] = al * 255
    out = canvas.round().clip(0, 255).astype(np.uint8)
    out[0, 0] = 0
    return out


def main():
    if len(sys.argv) > 6:  # anteprima di uno stato su sfondo grigio, per scegliere i fotogrammi
        st = strip(sys.argv[6])
        bg = Image.new("RGBA", (st.shape[1], st.shape[0]), (90, 90, 100, 255))
        bg.alpha_composite(Image.fromarray(st, "RGBA"))
        bg.convert("RGB").save(sys.argv[5])
        return
    os.makedirs(OUT, exist_ok=True)
    only = os.environ.get("STATI", "").split(",") if os.environ.get("STATI") else list(PLAN)  # STATI=idle,walk per rifarne alcuni
    for state in [s_ for s_ in only if s_ in PLAN]:
        st = strip(state)
        assert st.shape[1] <= 8192, f"{state}: striscia troppo larga"
        save(st, f"{OUT}/{state}.png")
        print(state, st.shape[1] // FW)
    if "STATI" not in os.environ:
        save(portrait(), f"{OUT}/portrait.png")
    if "STATI" not in os.environ or "uccelli" in only:  # STATI=uccelli: solo piccione, aquila e suprema senza aquila
        os.makedirs(f"{OUT}/proiettili", exist_ok=True)  # fuori dagli stati
        save(pigeon(), f"{OUT}/proiettili/piccione.png")
        save(eagle(), f"{OUT}/proiettili/aquila.png")
        save(strip(AFTER_EAGLE), f"{OUT}/proiettili/suprema-senza-aquila.png")


if __name__ == "__main__":
    main()
