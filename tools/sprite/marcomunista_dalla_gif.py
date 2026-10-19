# Uso: python3 tools/sprite/marcomunista_dalla_gif.py <marco-arti-marziali.gif> <cartella di lavoro>
# Marcomunista animato dalla GIF di arti marziali fornita da Nicola (480x270, 160 fotogrammi, sfondo dipinto).
# 1. scontorno: maschera di rembg (modello isnet-general-use) più l'energia verde, tenuta come smear; i colori
#    semitrasparenti si ripuliscono dallo sfondo, ricostruito come media dei fotogrammi dove il personaggio non c'è;
# 2. Marco è pelato: dove la GIF mostra la nuca coi capelli (fotogrammi girati) diventa pelle;
# 3. specchiato per guardare a destra, rimpicciolito all'altezza delle pose del foglio, contorno chiaro, un PNG per
#    stato in public/assets/characters/marcomunista con i piedi allineati (footY).
# La GIF non va nella repo. Servono Pillow, numpy, scipy e rembg (pip install "rembg[cpu]"), solo per rifarlo.
# Gli stati che la GIF non ha (walk, dash) restano le pose del foglio (#352), allargate al fotogramma nuovo.
import os, sys
import numpy as np
from PIL import Image, ImageSequence
from scipy import ndimage as ndi

GIF, WORK = sys.argv[1], sys.argv[2]
OUT = os.path.join(os.path.dirname(__file__), "../../public/assets/characters/marcomunista")
FW, FH, FOOT_Y = 400, 240, 222  # fotogramma e piedi: copiati in characters.ts
SCALE = 0.84  # Marco della GIF è alto 217 px, le pose del foglio 182
GROUND, CENTER = 247.5, 240  # dove tocca terra e il centro, nella GIF
OUTLINE = np.array([218, 225, 235], np.float32)  # il contorno chiaro delle pose del foglio
OLD = dict(w=304, h=196, foot=182)  # misure delle pose del foglio

R = lambda a, b, s=1: list(range(a, b + 1, s))
# stato -> fotogrammi della GIF. "world": coordinate della GIF (terra fissa, i passi restano dove sono);
# "feet": ogni fotogramma coi piedi su footY (salti, e mosse che nella GIF sono saltelli)
PLAN = {
    "idle": dict(frames=[0, 1, 2, 3, 4, 3, 2, 1], mode="world"),  # respiro, le braccia si aprono appena
    "jump": dict(frames=[83, 84, 85, 86, 87], mode="feet"),
    "fall": dict(frames=[106, 107, 108, 107], mode="feet"),
    "doubleJump": dict(frames=[88, 90, 92, 94, 96, 98, 100, 102], mode="feet"),  # la giravolta con l'anello
    "tumble": dict(frames=[91, 93, 95, 97, 99, 101], mode="feet"),
    "land": dict(frames=[79, 80, 81], mode="world", plain=True),
    "light": dict(frames=[135, 134, 133, 134, 135], mode="world"),  # colpo di palmo
    "heavy": dict(frames=[119, 120, 121, 122, 123, 125, 126, 128, 130, 132, 134], mode="world"),  # calcio con esplosione
    "lightUp": dict(frames=[49, 50, 51, 52, 53, 54], mode="world"),
    "heavyUp": dict(frames=[108, 109, 110, 111, 112, 113], mode="feet"),
    "lightDown": dict(frames=[72, 73, 74, 75, 76], mode="world"),
    "heavyDown": dict(frames=[113, 114, 115, 116, 117, 118, 119], mode="feet"),  # giù di peso, energia a terra
    "lightAir": dict(frames=[84, 85, 86, 87], mode="feet"),
    "heavyAir": dict(frames=[89, 91, 93, 95, 96, 97], mode="feet"),
    "recovery": dict(frames=[109, 110, 111, 112], mode="feet"),
    "specialNeutral": dict(frames=[33, 35, 37, 38, 39, 40, 41, 42], mode="world"),  # spinta in avanti
    "specialDown": dict(frames=[43, 44, 45, 46, 47, 48, 49, 50], mode="world"),  # Rolling: para, mano alla bocca
    "supreme": dict(frames=R(138, 159), mode="world"),  # …COSA?: l'anello, la nuvola (sparisce), il fumo
    "taunt": dict(frames=R(52, 70, 2), mode="world"),  # tai chi con l'energia
    "shield": dict(frames=[26, 28, 30, 32, 30, 28], mode="world"),
    "grab": dict(frames=[135, 134, 133], mode="world"),
    "throw": dict(frames=[39, 40, 41, 42], mode="world"),
    "hit": dict(frames=[46, 47], mode="world", lean=[10, 15], plain=True),  # mano in faccia, piegato all'indietro
}
# plain: senza energia (chi è colpito non fa scie)
PORTRAIT = 0  # fotogramma del ritratto

# Fotogrammi girati: colonne (rispetto al centro del cappello) e profondità sotto la tesa dove si vedono i capelli.
# Di faccia la barba resta com'è; di lato e di schiena si tocca solo la nuca
NAPE = {
    91: (-37, 10, 14), 92: (-37, -5, 12), 93: (-37, 15, 20), 94: (-37, 25, 20), 95: (-37, 38, 20),
    96: (-25, 38, 20), 97: (1, 38, 14), 99: (-37, 38, 20), 100: (-37, 38, 20), 101: (-37, 38, 20),
    102: (-9, 38, 18), 103: (8, 38, 12),
}
SKIN = np.array([222, 168, 136], np.float32)  # la pelle della faccia nella GIF
SHADOW = np.array([176, 120, 96], np.float32)  # sotto la tesa


def masks(frames):
    """Maschere di rembg, una volta sola (sono lente): in WORK/rb."""
    os.makedirs(f"{WORK}/rb", exist_ok=True)
    todo = [i for i in range(len(frames)) if not os.path.exists(f"{WORK}/rb/{i:03d}.png")]
    if todo:
        from rembg import remove, new_session
        s = new_session("isnet-general-use")
        for i in todo:
            remove(frames[i], session=s, only_mask=True).save(f"{WORK}/rb/{i:03d}.png")
    return [np.asarray(Image.open(f"{WORK}/rb/{i:03d}.png"), np.float32) / 255 for i in range(len(frames))]


def background(F, M):
    """Lo sfondo dipinto: media dei pixel dove nessun fotogramma ha il personaggio o l'energia."""
    g = F[..., 1] - np.maximum(F[..., 0], F[..., 2])
    w = ((M < 0.02) & (g < 10)).astype(np.float32)
    plate = (F * w[..., None]).sum(0) / np.maximum(w.sum(0), 1)[..., None]
    hole = w.sum(0) == 0
    idx = ndi.distance_transform_edt(hole, return_distances=False, return_indices=True)
    return plate[idx[0], idx[1]]


def cut(p, m, plate):
    # la GIF è retinata: per sfondo ed energia si guarda l'immagine sfocata, senza i puntini
    pb = ndi.gaussian_filter(p, (1.0, 1.0, 0))
    plb = ndi.gaussian_filter(plate, (1.0, 1.0, 0))
    diff = np.abs(pb - plb).max(-1)
    g = pb[..., 1] - np.maximum(pb[..., 0], pb[..., 2])
    e = np.clip((g - 10) / 35, 0, 1) * (pb.mean(-1) > 110) * np.clip((diff - 14) / 40, 0, 1)  # energia verde chiara
    e = ndi.gaussian_filter(e, 0.7)
    # dove rembg è incerto conta anche quanto il pixel si stacca dallo sfondo (niente aloni né erba)
    m = np.where(m < 0.95, np.minimum(m, np.clip((diff - 22) / 35, 0, 1)), m)
    a = np.maximum(m, e)
    a[a < 0.15] = 0
    a[200:, :70] = a[200:, 410:] = 0  # le piante agli angoli in basso
    lab, n = ndi.label(a > 0.3)
    if n:  # puntini staccati
        sizes = ndi.sum(np.ones_like(a), lab, range(1, n + 1))
        a[np.isin(lab, np.nonzero(sizes < 25)[0] + 1)] = 0
    aa = np.maximum(a, 1e-3)[..., None]
    src = np.where((e > m)[..., None], pb, p)  # l'energia col colore sfocato, il corpo nitido
    c = np.clip(np.where(a[..., None] > 0.97, p, (src - (1 - aa) * plb) / aa), 0, 255)
    return np.dstack([c, a * 255])


def bald(rgba, body, frame):
    if frame not in NAPE:
        return rgba
    p = rgba[..., :3]
    pb = ndi.gaussian_filter(p, (0.7, 0.7, 0))
    r, g, b = pb[..., 0], pb[..., 1], pb[..., 2]
    ys, xs = np.nonzero(body)
    top = ys.min()
    head = np.zeros_like(body)
    head[top : top + 75] = True
    hat = (((r > 140) & (b > 70) & (r - g > 50)) | ((b > 110) & (g > 110) & (r < 140) & (b - r > 25))) & head & body
    hat = ndi.binary_opening(hat, iterations=1)
    yellow = (r > 190) & (g > 140) & (b < 120) & (r - b > 90)  # la felpa
    dark = (pb.mean(-1) < 95) & body
    fix = np.zeros_like(body)
    xa, xb, depth = NAPE[frame]
    xc = int(xs[ys < top + 20].mean())
    for x in range(max(0, xc + xa), min(body.shape[1], xc + xb)):
        hy = np.nonzero(hat[:, x])[0]
        if len(hy) == 0:
            continue
        y0 = hy.max() + 1
        yy = np.nonzero(yellow[y0 : y0 + depth, x])[0]
        y1 = y0 + (yy.min() if len(yy) else depth)
        fix[y0:y1, x] = dark[y0:y1, x]
    fix &= ndi.binary_erosion(body, iterations=2)  # il tratto nero del contorno resta
    fix &= ~ndi.binary_dilation(yellow, iterations=1)
    lab, n = ndi.label(fix)
    if n:  # solo le macchie grandi (la nuca), non i tratti sottili
        sizes = ndi.sum(np.ones_like(lab), lab, range(1, n + 1))
        fix = np.isin(lab, np.nonzero(sizes >= 20)[0] + 1)
    dist = ndi.distance_transform_edt(~ndi.binary_dilation(hat, iterations=1))
    t = np.clip((dist - 1) / 5, 0, 1)[..., None]
    out = rgba.copy()
    out[..., :3] = np.where(fix[..., None], SHADOW * (1 - t) + SKIN * t, p)
    return out


def resize(rgba, size):
    im = Image.fromarray(rgba.round().clip(0, 255).astype(np.uint8), "RGBA").convert("RGBa")
    return np.asarray(im.resize(size, Image.LANCZOS).convert("RGBA"), np.float32)


def place(rgba, body, mode, lean=0):
    """Specchia, rimpicciolisce e mette nel fotogramma; poi il contorno chiaro attorno al corpo."""
    rgba, body = rgba[:, ::-1], body[:, ::-1]
    h, w = body.shape
    size = (round(w * SCALE), round(h * SCALE))
    sm = resize(rgba, size)
    sb = np.asarray(Image.fromarray((body * 255).astype(np.uint8)).resize(size, Image.LANCZOS), np.float32) / 255
    dx = FW / 2 - (w - CENTER) * SCALE
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
    if lean:  # piegato all'indietro attorno ai piedi
        piv = (FW / 2, FOOT_Y)
        frame = np.asarray(Image.fromarray(frame.round().clip(0, 255).astype(np.uint8), "RGBA").rotate(lean, Image.BICUBIC, center=piv), np.float32)
        fb = np.asarray(Image.fromarray((fb * 255).astype(np.uint8)).rotate(lean, Image.BICUBIC, center=piv), np.float32) / 255
    # contorno chiaro di 2 px attorno al corpo (non all'energia), sotto il disegno
    ring = ndi.gaussian_filter(ndi.binary_dilation(fb > 0.5, iterations=2).astype(np.float32), 0.6)
    a = frame[..., 3:] / 255
    rgb = frame[..., :3] * a + OUTLINE * ring[..., None] * (1 - a)
    alpha = a[..., 0] + ring * (1 - a[..., 0])
    rgb = rgb / np.maximum(alpha, 1e-3)[..., None]
    out = np.dstack([rgb, alpha * 255]).round().clip(0, 255).astype(np.uint8)
    out[0, 0] = 0  # l'angolo in alto a sinistra trasparente (lo controlla assets.test.ts)
    return out


def save(rgba, path):
    """PNG a 256 colori con l'alfa: la GIF è retinata e a colori pieni i file pesano il triplo."""
    im = Image.fromarray(rgba, "RGBA").quantize(256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
    im.save(path, optimize=True)


def widen(path):
    """Una posa del foglio (304x196, piedi a 182) nel fotogramma nuovo, coi piedi allineati."""
    im = Image.open(path).convert("RGBA")
    if im.height == FH:
        return
    n = im.width // OLD["w"]
    out = Image.new("RGBA", (FW * n, FH))
    for k in range(n):
        out.paste(im.crop((k * OLD["w"], 0, (k + 1) * OLD["w"], OLD["h"])), (k * FW + (FW - OLD["w"]) // 2, FOOT_Y - OLD["foot"]))
    out.save(path, optimize=True)


def main():
    gif = Image.open(GIF)
    frames = [f.convert("RGB") for f in ImageSequence.Iterator(gif)]
    F = np.stack([np.asarray(f, np.float32) for f in frames])
    M = np.stack(masks(frames))
    plate = background(F, M)
    cache = {}

    def frame(i):
        if i not in cache:
            cache[i] = bald(cut(F[i], M[i], plate), M[i] > 0.5, i)
        return cache[i]

    for state, spec in PLAN.items():
        leans = spec.get("lean", [0] * len(spec["frames"]))
        strip = []
        for i, lean in zip(spec["frames"], leans):
            rgba = frame(i)
            if spec.get("plain"):
                rgba = rgba.copy()
                rgba[..., 3] = np.minimum(rgba[..., 3], ndi.binary_dilation(M[i] > 0.5, iterations=1) * 255)
            strip.append(place(rgba, M[i], spec["mode"], lean))
        save(np.concatenate(strip, 1), f"{OUT}/{state}.png")
        print(state, len(strip))
    for state in ("walk", "dash"):
        widen(f"{OUT}/{state}.png")
    # ritratto: testa e spalle del fermo, alla risoluzione della GIF
    rgba = frame(PORTRAIT)[:, ::-1]
    body = (M[PORTRAIT] > 0.5)[:, ::-1]
    ys, xs = np.nonzero(body)
    top, xc = ys.min(), int(xs[ys < ys.min() + 20].mean())
    side = 104
    crop = np.zeros((side, side, 4), np.float32)
    x0 = xc - side // 2
    crop[2:] = rgba[top : top + side - 2, x0 : x0 + side]
    por = resize(crop, (146, 146))
    a = por[..., 3] / 255
    ring = ndi.gaussian_filter(ndi.binary_dilation(a > 0.5, iterations=2).astype(np.float32), 0.6)
    canvas = np.zeros((150, 150, 4), np.float32)
    rgb = por[..., :3] * a[..., None] + OUTLINE * ring[..., None] * (1 - a[..., None])
    al = a + ring * (1 - a)
    canvas[2:148, 2:148, :3] = rgb / np.maximum(al, 1e-3)[..., None]
    canvas[2:148, 2:148, 3] = al * 255
    save(canvas.round().clip(0, 255).astype(np.uint8), f"{OUT}/portrait.png")


if __name__ == "__main__":
    main()
