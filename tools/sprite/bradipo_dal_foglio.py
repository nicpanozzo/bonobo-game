# Uso: python3 tools/sprite/bradipo_dal_foglio.py <foglio.png> [cartella di uscita]
# Bradipo Giallo dal foglio delle pose a colori di @Marcomunista (#335): 24 pose in una griglia 6×4 col nome sotto,
# come quello di Egiainuso (egiainuso_dal_foglio.py), ma colorato. Qui non basta prendere il tratto scuro: si
# toglie il fondo bianco riempiendolo dai bordi, così la faccia bianca (chiusa dal tratto) resta. Poi un
# contorno chiaro per i fondali scuri e un PNG per stato nel formato a cartella (E7), con i piedi allineati.
# Il foglio non va nella repo: si passa da fuori. Servono Pillow, numpy e scipy.
import json, os, sys
import numpy as np
from PIL import Image
from scipy import ndimage

SRC = sys.argv[1]
OUT = sys.argv[2] if len(sys.argv) > 2 else "public/assets/characters/bradipo"
COLS, ROWS = 6, 4
LABEL_Y = [266, 517, 754, 974]  # dove stanno i nomi delle pose, riga per riga
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
    "specialNeutral": ["Pummel"],  # le Ciacole: le mani alla bocca
    "specialDown": ["Shield"],  # il contrattacco
    "supreme": ["Final Smash"],
}
HEIGHT = 176  # altezza del fermo nel PNG: con scale 0.5 il bradipo è alto come la hitbox (88 a 1x)
RIM = (214, 222, 232)  # contorno chiaro, per i fondali scuri
RIM_PX = 3
PAD = 8


def pose_images(sheet):
    rgb = np.asarray(sheet, dtype=np.int16)
    lo, hi = rgb.min(axis=2), rgb.max(axis=2)
    paper = (lo > 222) & (hi - lo < 28)  # bianco o quasi, poco colorato
    # il fondo è la carta collegata ai bordi: la faccia bianca è chiusa dal tratto e resta
    lab_p, _ = ndimage.label(paper)
    edge = np.unique(np.concatenate([lab_p[0], lab_p[-1], lab_p[:, 0], lab_p[:, -1]]))
    fg = ~np.isin(lab_p, edge[edge > 0])
    lab, _ = ndimage.label(fg, structure=np.ones((3, 3)))
    objs = ndimage.find_objects(lab)
    H, W = fg.shape
    cells = {}
    for i, sl in enumerate(objs):
        if sl is None:
            continue
        y0, y1, x0, x1 = sl[0].start, sl[0].stop, sl[1].start, sl[1].stop
        cy, cx = (y0 + y1) / 2, (x0 + x1) / 2
        row = next((r for r in range(ROWS) if cy < LABEL_Y[r] + 16), ROWS - 1)
        col = min(COLS - 1, int(cx / (W / COLS)))
        if abs(cy - LABEL_Y[row]) < 16 and y1 - y0 < 30:
            continue  # il nome della posa
        cells.setdefault((row, col), []).append(i + 1)
    out = {}
    for (row, col), ids in cells.items():
        sizes = {k: int((lab == k).sum()) for k in ids}
        ids = [k for k in ids if sizes[k] > 12]  # puntini sparsi
        person = max(sizes, key=sizes.get)  # il componente più grande è il bradipo, gli altri sono effetti
        mask = np.isin(lab, ids)
        ys, xs = np.nonzero(mask)
        y0, y1, x0, x1 = ys.min() - PAD, ys.max() + PAD + 1, xs.min() - PAD, xs.max() + PAD + 1
        m = mask[y0:y1, x0:x1]
        c = rgb[y0:y1, x0:x1].astype(np.float32)
        # bordo morbido: i pixel del fondo appena fuori dal tratto prendono un po' di alfa dalla loro ombra
        ring = ndimage.binary_dilation(m, iterations=1) & ~m
        shade = np.clip((250 - c.min(axis=2)) / 40.0, 0, 1)
        alpha = np.where(m, 1.0, np.where(ring, shade, 0.0))
        # la carta chiusa dal tratto resta bianca (la faccia, il pupazzetto lanciato: sotto i 2000 px), tranne la
        # bolla dello scudo (6600 px), che diventa velata: se no sembra un muro bianco
        inner, n = ndimage.label(m & paper[y0:y1, x0:x1])
        for k in range(1, n + 1):
            region = inner == k
            if region.sum() > 4000:
                alpha[region] = 0.3
        sil = alpha > 0.15
        rim = ndimage.binary_dilation(sil, iterations=RIM_PX) & ~sil
        out_c = np.where(rim[..., None], np.array(RIM, np.float32), c)
        out_a = np.maximum(alpha, rim * (200 / 255.0))
        im = Image.fromarray(np.dstack([out_c, out_a * 255]).clip(0, 255).astype(np.uint8), "RGBA")
        py, px = np.nonzero((lab == person)[y0:y1, x0:x1])
        out[NAMES[row][col]] = (im, (float(px.mean()), float(py.max())), float(py.max() - py.min()))
    return out


def main():
    sheet = Image.open(SRC).convert("RGB")
    poses = pose_images(sheet)
    scale = HEIGHT / poses["Idle"][2]
    # "Idle*": il fermo piegato all'indietro, per il colpito
    im, (fx, fy), h = poses["Idle"]
    big = Image.new("RGBA", (im.width + 80, im.height + 40), (0, 0, 0, 0))
    big.alpha_composite(im, (40, 20))
    hit = big.rotate(14, resample=Image.BICUBIC, center=(fx + 40, fy + 20), translate=(-6, 0))
    poses["Idle*"] = (hit, (fx + 40 - 6, fy + 20), h)
    used = {n for names in STATES.values() for n in names}
    left = right = up = down = 0
    for name in used:
        im, (fx, fy), _ = poses[name]
        bb = im.getchannel("A").getbbox()
        left, right = max(left, fx - bb[0]), max(right, bb[2] - fx)
        up, down = max(up, fy - bb[1]), max(down, bb[3] - fy)
    half = int(max(left, right) * scale) + 4
    fw, foot = 2 * half, int(up * scale) + 4
    fh = foot + int(down * scale) + 4
    fw, fh = fw + fw % 2, fh + fh % 2
    os.makedirs(OUT, exist_ok=True)
    for state, names in STATES.items():
        strip = Image.new("RGBA", (fw * len(names), fh), (0, 0, 0, 0))
        for i, name in enumerate(names):
            im, (fx, fy), _ = poses[name]
            im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
            strip.alpha_composite(im, (i * fw + round(half - fx * scale), round(foot - fy * scale)))
        strip.save(os.path.join(OUT, f"{state}.png"), optimize=True)
    # il ritratto: la testa con la cresta, dal fermo
    im, (fx, fy), _ = poses["Idle"]
    bb = im.getchannel("A").getbbox()
    side = int((bb[2] - bb[0]) * 1.15)
    cx = (bb[0] + bb[2]) // 2 + 4
    im.crop((cx - side // 2, bb[1] - 6, cx + side // 2, bb[1] - 6 + side)).resize((150, 150), Image.LANCZOS).save(os.path.join(OUT, "portrait.png"), optimize=True)
    print(json.dumps({"frameWidth": fw, "frameHeight": fh, "footY": foot, "states": {k: len(v) for k, v in STATES.items()}}))


if __name__ == "__main__":
    main()
