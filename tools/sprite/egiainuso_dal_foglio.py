# Uso: python3 tools/sprite/egiainuso_dal_foglio.py <foglio.png> [cartella di uscita]
# Il nuovo Egiainuso (#178) dal foglio delle pose di @Marcomunista: 24 pose in una griglia 6×4, con il nome sotto.
# Ritaglia ogni posa, toglie il fondo bianco, riempie di bianco le parti chiuse (la faccia), aggiunge un
# contorno chiaro perché il tratto nero si legga sui fondali scuri (docs/stile-grafico.md) e scrive un PNG per
# stato nel formato a cartella (E7), con i piedi allineati. Il foglio non va nella repo: si passa da fuori.
# Servono Pillow, numpy e scipy (pip install pillow numpy scipy).
import json, os, sys
import numpy as np
from PIL import Image
from scipy import ndimage

SRC = sys.argv[1]
OUT = sys.argv[2] if len(sys.argv) > 2 else "public/assets/characters/egiainuso"
COLS, ROWS = 6, 4
LABEL_Y = [262, 510, 752, 980]  # dove stanno i nomi delle pose, riga per riga
NAMES = [
    ["Idle", "Walk", "Run", "Dash", "Jump", "Fall"],
    ["Crouch", "Shield", "Grab", "Pummel", "Throw (forward)", "Throw (back)"],
    ["Up Tilt", "Side Tilt", "Down Tilt", "Up Smash", "Side Smash", "Down Smash"],
    ["Neutral Air", "Forward Air", "Back Air", "Up Air", "Down Air", "Final Smash"],
]
# stato del gioco -> pose del foglio (più di una = animazione in ciclo)
STATES = {
    "idle": ["Idle"],
    "walk": ["Walk", "Run"],
    "jump": ["Jump"],
    "fall": ["Fall"],
    "light": ["Side Tilt"],
    "heavy": ["Side Smash"],
    "hit": ["Idle*"],  # nel foglio non c'è: il fermo piegato all'indietro
    "land": ["Crouch"],
    "dash": ["Dash"],
    "lightUp": ["Up Tilt"],
    "lightDown": ["Down Tilt"],
    "lightAir": ["Neutral Air"],
    "heavyUp": ["Up Smash"],
    "heavyDown": ["Down Smash"],
    "heavyAir": ["Forward Air"],
    "recovery": ["Up Air"],
    "shield": ["Shield"],
    "grab": ["Grab"],
    "throw": ["Throw (forward)"],
    "supreme": ["Final Smash"],
}
SCALE = 0.95  # le pose del foglio sono alte circa 185 px: così l'omino è poco più alto della hitbox (88 a 1x)
INK = (24, 22, 26)  # inchiostro quasi nero, non nero puro
FACE = (246, 241, 232)
RIM = (214, 222, 232)  # contorno chiaro, per i fondali scuri
RIM_PX = 3
PAD = 8


def pose_images(sheet):
    g = np.asarray(sheet.convert("L"), dtype=np.float32)
    ink = g < 160
    lab, n = ndimage.label(ink, structure=np.ones((3, 3)))
    objs = ndimage.find_objects(lab)
    cells = {}
    H, W = g.shape
    for i, sl in enumerate(objs):
        if sl is None:
            continue
        y0, y1, x0, x1 = sl[0].start, sl[0].stop, sl[1].start, sl[1].stop
        cy, cx = (y0 + y1) / 2, (x0 + x1) / 2
        # ogni posa sta sopra il suo nome: la riga è quella del primo nome più in basso del centro
        row = next((r for r in range(ROWS) if cy < LABEL_Y[r] + 16), ROWS - 1)
        col = min(COLS - 1, int(cx / (W / COLS)))
        if abs(cy - LABEL_Y[row]) < 16 and y1 - y0 < 30:
            continue  # il nome della posa
        cells.setdefault((row, col), []).append(i + 1)
    out = {}
    for (row, col), ids in cells.items():
        mask = np.isin(lab, ids)
        sizes = {k: int((lab == k).sum()) for k in ids}
        person = max(sizes, key=sizes.get)  # il componente più grande è l'omino, gli altri sono effetti
        ys, xs = np.nonzero(mask)
        y0, y1, x0, x1 = ys.min() - PAD, ys.max() + PAD + 1, xs.min() - PAD, xs.max() + PAD + 1
        crop_g = g[y0:y1, x0:x1]
        crop_m = mask[y0:y1, x0:x1]
        # alfa dal grigio, solo vicino al tratto (il resto del foglio è bianco)
        near = ndimage.binary_dilation(crop_m, iterations=2)
        alpha = np.clip((235 - crop_g) / 175.0, 0, 1) * near
        # parti chiuse dal tratto (la faccia, il pupazzetto lanciato): bianche
        solid = ndimage.binary_dilation(crop_g < 200, iterations=1)
        outside = ndimage.binary_fill_holes(solid) & ~solid
        holes, nh = ndimage.label(outside)
        face = np.zeros_like(solid)
        pm = (lab == person)[y0:y1, x0:x1]
        pys, pxs = np.nonzero(pm)
        head_y = pys.min() + 0.5 * (pys.max() - pys.min())  # la testa sta nella metà alta dell'omino
        for k in range(1, nh + 1):
            region = holes == k
            ry, rx = np.nonzero(region)
            outside_person = rx.mean() < pxs.min() or rx.mean() > pxs.max()  # il pupazzetto lanciato
            if region.sum() > 250 and (ry.mean() < head_y or outside_person):
                face |= region
        face = ndimage.binary_dilation(face, iterations=1) & ~(alpha > 0.6)
        sil = (alpha > 0.15) | face
        rim = ndimage.binary_dilation(sil, iterations=RIM_PX) & ~sil
        h, w = crop_g.shape
        # sotto: contorno chiaro e faccia; sopra: il tratto, con il suo alfa
        base_c = np.zeros((h, w, 3), dtype=np.float32)
        base_a = np.zeros((h, w), dtype=np.float32)
        base_c[rim], base_a[rim] = RIM, 200 / 255.0
        base_c[face], base_a[face] = FACE, 1.0
        out_a = alpha + base_a * (1 - alpha)
        out_c = (np.array(INK, np.float32) * alpha[..., None] + base_c * (base_a * (1 - alpha))[..., None]) / np.maximum(out_a, 1e-4)[..., None]
        img = np.dstack([out_c, out_a * 255])
        im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGBA")
        # piedi e centro dell'omino, nel ritaglio
        py, px = np.nonzero((lab == person)[y0:y1, x0:x1])
        feet = (float(px.mean()), float(py.max()))
        out[NAMES[row][col]] = (im, feet)
    return out


def main():
    sheet = Image.open(SRC).convert("RGB")
    poses = pose_images(sheet)
    # "Idle*": il fermo piegato all'indietro, per il colpito
    im, (fx, fy) = poses["Idle"]
    big = Image.new("RGBA", (im.width + 80, im.height + 40), (0, 0, 0, 0))
    big.alpha_composite(im, (40, 20))
    hit = big.rotate(14, resample=Image.BICUBIC, center=(fx + 40, fy + 20), translate=(-6, 0))
    poses["Idle*"] = (hit, (fx + 40 - 6, fy + 20))
    # misura comune: il fotogramma più largo e più alto attorno a centro e piedi, poi scalato
    left = right = up = down = 0
    for im, (fx, fy) in poses.values():
        bb = im.getchannel("A").getbbox()
        left, right = max(left, fx - bb[0]), max(right, bb[2] - fx)
        up, down = max(up, fy - bb[1]), max(down, bb[3] - fy)
    half = int(max(left, right) * SCALE) + 4
    fw, foot = 2 * half, int(up * SCALE) + 4
    fh = foot + int(down * SCALE) + 4
    fw, fh = fw + fw % 2, fh + fh % 2
    os.makedirs(OUT, exist_ok=True)
    for state, names in STATES.items():
        strip = Image.new("RGBA", (fw * len(names), fh), (0, 0, 0, 0))
        for i, name in enumerate(names):
            im, (fx, fy) = poses[name]
            im = im.resize((round(im.width * SCALE), round(im.height * SCALE)), Image.LANCZOS)
            strip.alpha_composite(im, (i * fw + round(half - fx * SCALE), round(foot - fy * SCALE)))
        strip.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).save(os.path.join(OUT, f"{state}.png"), optimize=True)
    # il ritratto: testa e cappellino del fermo
    im, (fx, fy) = poses["Idle"]
    bb = im.getchannel("A").getbbox()
    side = int((bb[2] - bb[0]) * 1.3)
    cx = (bb[0] + bb[2]) // 2 + 6
    im.crop((cx - side // 2, bb[1] - 6, cx + side // 2, bb[1] - 6 + side)).save(os.path.join(OUT, "portrait.png"), optimize=True)
    print(json.dumps({"frameWidth": fw, "frameHeight": fh, "footY": foot, "states": {k: len(v) for k, v in STATES.items()}}))


if __name__ == "__main__":
    main()
