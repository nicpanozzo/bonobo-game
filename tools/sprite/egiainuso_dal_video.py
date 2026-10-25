# Uso: python3 tools/sprite/egiainuso_dal_video.py <video.mp4> <cartella di lavoro>
# La skin "Animato" di Egiainuso, dal video di tutte le mosse fatto da Nicola con Google Flow (1280x720, 24 fps,
# 240 fotogrammi, sfondo verde pieno, camera ferma, di profilo verso destra). Lo stesso metodo di bradipo_dal_video.py:
# 1. scontorno col colore: il verde dello sfondo va via, i bordi si ripuliscono togliendo il verde mescolato; lo sputo
#    verde chiaro resta, schiarito e velato, come smear;
# 2. rimpicciolito all'altezza delle pose del foglio (#178), contorno chiaro, un PNG a strisce per stato in
#    public/assets/characters/egiainuso/skins/animato con i piedi allineati (footY).
# Il video non va nella repo. Servono ffmpeg, Pillow, numpy e scipy, solo per rifarlo.
import os, subprocess, sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

VIDEO, WORK = sys.argv[1], sys.argv[2]
OUT = os.path.join(os.path.dirname(__file__), "../../public/assets/characters/egiainuso/skins/animato")
FW, FH, FOOT_Y = 400, 330, 290  # fotogramma e piedi: copiati in characters.ts (alto per l'aura della suprema)
SCALE = 0.476  # l'omino fermo nel video è alto 393 px, nel foglio 187
GROUND, CENTER = 603, 620  # dove tocca terra e il centro del fermo, nel video
BG = np.array([7, 169, 73], np.float32)  # il verde dello sfondo
OUTLINE = np.array([218, 225, 235], np.float32)  # il contorno chiaro delle pose del foglio
TRAIL = np.array([226, 240, 228], np.float32)  # lo sputo e la polvere verde chiara, schiariti

R = lambda a, b, s=1: list(range(a, b + 1, s))
# stato -> fotogrammi del video. "world": coordinate del video (terra fissa, i salti salgono davvero);
# "feet": ogni fotogramma coi piedi su footY (stati in aria, dove l'altezza la decide la fisica)
PLAN = {
    "idle": dict(frames=R(0, 14), mode="world"),  # respiro, lo zaino sobbalza
    "walk": dict(frames=R(15, 25), mode="world"),  # passo sul posto
    "dash": dict(frames=R(26, 32), mode="world"),  # corsa piegato in avanti, con le righe della velocità
    "jump": dict(frames=R(33, 36), mode="feet"),
    "doubleJump": dict(frames=R(36, 46), mode="feet"),  # la capriola
    "tumble": dict(frames=R(37, 45), mode="feet"),
    "fall": dict(frames=[47], mode="feet"),
    "land": dict(frames=R(48, 51), mode="world"),
    "light": dict(frames=R(53, 59), mode="world"),  # pugno dritto
    "lightUp": dict(frames=R(86, 91), mode="world"),  # nel video non c'è: l'inizio del montante
    "lightDown": dict(frames=R(63, 69), mode="world"),  # calcio basso
    "heavy": dict(frames=R(74, 83), mode="world"),  # affondo col pugno e l'onda a zig-zag
    "heavyUp": dict(frames=R(85, 93), mode="world"),  # montante ad arco
    "heavyDown": dict(frames=R(94, 99), mode="world"),  # spazzata bassa
    "lightAir": dict(frames=R(110, 114), mode="feet"),
    "heavyAir": dict(frames=R(103, 109), mode="feet"),  # calcio in aria con l'arco
    "recovery": dict(frames=R(87, 92), mode="feet"),
    "grab": dict(frames=R(120, 124), mode="world"),
    "throw": dict(frames=R(125, 134, 2), mode="world"),
    "specialNeutral": dict(frames=[136, 139, 142, 145, 146, 147, 148, 149, 150, 151, 152], mode="world"),  # Sputo: gonfia le guance e sputa
    "specialSide": dict(frames=R(156, 169), mode="world"),  # Scatto: di spalla, con le righe della velocità
    "specialDown": dict(frames=R(172, 188), mode="world"),  # Contrattacco: il lampo e il pugno di risposta
    "supreme": dict(frames=R(192, 210), mode="world"),  # l'aura nera a zig-zag
    "shield": dict(frames=R(216, 220), mode="world"),  # il cerchio d'inchiostro coi lampi
    "hit": dict(frames=R(222, 228), mode="world"),  # colpito, scatta all'indietro
    "taunt": dict(frames=R(135, 145), mode="world"),  # le guance gonfie, prima dello sputo
}
PORTRAIT = 0  # fotogramma del ritratto


def frames():
    os.makedirs(f"{WORK}/f", exist_ok=True)
    if not os.path.exists(f"{WORK}/f/000.png"):
        subprocess.run(["ffmpeg", "-v", "error", "-i", VIDEO, "-start_number", "0", f"{WORK}/f/%03d.png"], check=True)
    return lambda i: np.asarray(Image.open(f"{WORK}/f/{i:03d}.png").convert("RGB"), np.float32)


def cut(p):
    """RGBA del bradipo e maschera del corpo (senza scia)."""
    r, g, b = p[..., 0], p[..., 1], p[..., 2]
    d = g - np.maximum(r, b)  # quanto è verde
    trail = (r > 90) & (b > 100) & (d > 25)  # verde chiaro: lo sputo e la polvere (e qualche bordo bianco)
    a = np.clip((48 - d) / 30, 0, 1)  # il verde pieno sparisce
    a = np.where(trail, 0.6, a)
    a[a < 0.08] = 0
    lab, n = ndi.label(a > 0.3)
    if n:  # puntini staccati
        sizes = ndi.sum(np.ones_like(a), lab, range(1, n + 1))
        a[np.isin(lab, np.nonzero(sizes < 40)[0] + 1)] = 0
    aa = np.maximum(a, 1e-3)[..., None]
    c = np.where(a[..., None] > 0.97, p, (p - (1 - aa) * BG) / aa)  # toglie il verde mescolato ai bordi
    c[..., 1] = np.minimum(c[..., 1], np.maximum(c[..., 0], c[..., 2]) + 8)  # e quello che resta
    c = np.where(trail[..., None], TRAIL, np.clip(c, 0, 255))
    body = (a > 0.5) & ~trail
    return np.dstack([c, a * 255]), body


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
    # contorno chiaro di 2 px attorno al corpo (non alla scia), sotto il disegno
    ring = ndi.gaussian_filter(ndi.binary_dilation(fb > 0.5, iterations=2).astype(np.float32), 0.6)
    a = frame[..., 3:] / 255
    rgb = frame[..., :3] * a + OUTLINE * ring[..., None] * (1 - a)
    alpha = a[..., 0] + ring * (1 - a[..., 0])
    rgb = rgb / np.maximum(alpha, 1e-3)[..., None]
    out = np.dstack([rgb, alpha * 255]).round().clip(0, 255).astype(np.uint8)
    out[0, 0] = 0  # l'angolo in alto a sinistra trasparente (lo controlla assets.test.ts)
    return out


def save(rgba, path):
    """PNG a 256 colori con l'alfa: a colori pieni i file pesano il triplo."""
    im = Image.fromarray(rgba, "RGBA").quantize(256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
    im.save(path, optimize=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    load = frames()
    cache = {}

    def frame(i):
        if i not in cache:
            cache[i] = cut(load(i))
        return cache[i]

    for state, spec in PLAN.items():
        strip = [place(*frame(i), spec["mode"]) for i in spec["frames"]]
        save(np.concatenate(strip, 1), f"{OUT}/{state}.png")
        print(state, len(strip))
    # ritratto: testa e cappellino del fermo, alla risoluzione del video
    rgba, body = frame(PORTRAIT)
    ys, xs = np.nonzero(body)
    top, xc = ys.min(), int(xs[ys < ys.min() + 120].mean())
    side = 260
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
    save(out, f"{OUT}/portrait.png")


if __name__ == "__main__":
    main()
