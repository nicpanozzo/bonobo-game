# Uso: python3 tools/sprite/bradipo_dal_video.py <video.mp4> <cartella di lavoro>
# La skin "Bassista" di Bradipo Giallo, dal video di tutte le mosse fatto da Nicola con Google Flow (1280x720, 24 fps,
# 240 fotogrammi, sfondo verde pieno, camera ferma, di profilo verso destra). Come marcomunista_dalla_gif.py, ma col verde:
# 1. scontorno col colore: il verde dello sfondo e l'ombra verde scura sotto i salti vanno via, i bordi si ripuliscono
#    togliendo il verde mescolato; la scia verde chiara della suprema resta, schiarita e velata, come smear;
# 2. rimpicciolito all'altezza delle pose del foglio (#335), contorno chiaro, un PNG a strisce per stato in
#    public/assets/characters/bradipo con i piedi allineati (footY).
# Il video non va nella repo. Servono ffmpeg, Pillow, numpy e scipy, solo per rifarlo.
import os, subprocess, sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

VIDEO, WORK = sys.argv[1], sys.argv[2]
OUT = os.path.join(os.path.dirname(__file__), "../../public/assets/characters/bradipo")
FW, FH, FOOT_Y = 320, 250, 232  # fotogramma e piedi: copiati in characters.ts
SCALE = 0.38  # il bradipo fermo nel video è alto 485 px, nel foglio 184
GROUND, CENTER = 655, 600  # dove tocca terra e il centro del fermo, nel video
BG = np.array([23, 176, 59], np.float32)  # il verde dello sfondo
OUTLINE = np.array([218, 225, 235], np.float32)  # il contorno chiaro delle pose del foglio
TRAIL = np.array([232, 242, 236], np.float32)  # la scia della suprema, schiarita

R = lambda a, b, s=1: list(range(a, b + 1, s))
# stato -> fotogrammi del video. "world": coordinate del video (terra fissa, i salti salgono davvero);
# "feet": ogni fotogramma coi piedi su footY (stati in aria, dove l'altezza la decide la fisica)
PLAN = {
    "idle": dict(frames=R(210, 238, 2), mode="world"),  # respiro, la cresta si muove appena
    "walk": dict(frames=R(4, 17), mode="world"),  # passo sul posto
    "dash": dict(frames=R(14, 19), mode="world"),  # piegato in avanti
    "jump": dict(frames=R(19, 22), mode="feet"),
    "doubleJump": dict(frames=R(22, 29), mode="feet"),  # la capriola
    "tumble": dict(frames=R(23, 28), mode="feet"),
    "fall": dict(frames=R(30, 33), mode="feet"),
    "land": dict(frames=[34, 35], mode="world"),
    "light": dict(frames=R(36, 43), mode="world"),  # artigliata in avanti
    "lightDown": dict(frames=R(44, 49), mode="world"),  # artigliata bassa
    "lightUp": dict(frames=R(75, 80), mode="world"),
    "heavy": dict(frames=R(54, 63), mode="world"),  # affondo col braccio teso
    "heavyDown": dict(frames=R(64, 73), mode="world"),  # artigli a terra, polvere
    "heavyUp": dict(frames=R(74, 82), mode="world"),  # arco verso l'alto saltando
    "lightAir": dict(frames=R(85, 89), mode="feet"),  # braccia aperte
    "heavyAir": dict(frames=R(83, 86), mode="feet"),
    "recovery": dict(frames=R(76, 80), mode="feet"),
    "grab": dict(frames=R(100, 108), mode="world"),
    "throw": dict(frames=R(108, 114), mode="world"),
    "specialNeutral": dict(frames=R(115, 130, 2), mode="world"),  # Ciacole: le mani alla bocca, urla
    "specialSide": dict(frames=R(131, 159, 2), mode="world"),  # Bassline: il riff col basso
    "taunt": dict(frames=R(139, 152), mode="world"),  # il riff, a testa bassa
    "supreme": dict(frames=R(164, 179), mode="world"),  # DEMACIAAA: due giri come Garen col basso a spada, in loop
    "specialDown": dict(frames=R(182, 189), mode="world"),  # Cambio pannolino: si copre e para
    "shield": dict(frames=R(184, 189), mode="world"),
    "hit": dict(frames=R(190, 197), mode="world"),  # colpito, scatta all'indietro
}
PORTRAIT = 210  # fotogramma del ritratto


def frames():
    os.makedirs(f"{WORK}/f", exist_ok=True)
    if not os.path.exists(f"{WORK}/f/000.png"):
        subprocess.run(["ffmpeg", "-v", "error", "-i", VIDEO, "-start_number", "0", f"{WORK}/f/%03d.png"], check=True)
    return lambda i: np.asarray(Image.open(f"{WORK}/f/{i:03d}.png").convert("RGB"), np.float32)


def cut(p):
    """RGBA del bradipo e maschera del corpo (senza scia)."""
    r, g, b = p[..., 0], p[..., 1], p[..., 2]
    d = g - np.maximum(r, b)  # quanto è verde
    trail = (r > 90) & (b > 100) & (d > 25)  # verde chiaro: la scia della suprema (e qualche bordo bianco)
    a = np.clip((48 - d) / 30, 0, 1)  # il verde pieno e l'ombra verde scura spariscono
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
    # ritratto: testa e cresta del fermo, alla risoluzione del video
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
