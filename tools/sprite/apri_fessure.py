# Riapre le fessure strette riempite dal contorno chiaro (#506, segnalato da Riccardo): gli script dei video
# (bradipo_dal_video.py, egiainuso_dal_video.py) mettono 2 px di contorno chiaro attorno al corpo, e dove tra braccio
# e corpo o tra le gambe c'erano meno di ~4 px i due contorni si toccavano e riempivano il buco di bianco.
# Lavora sui PNG già fatti (i video non sono nella repo): il contorno chiaro che sta dentro una fessura diventa
# trasparente, quello lungo i bordi resta. Gli script dei video ora non lo rifanno.
# Uso: python3 tools/sprite/apri_fessure.py public/assets/characters/bradipo public/assets/characters/egiainuso/skins/animato
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

OUTLINE = np.array([218, 225, 235], np.float32)  # il contorno chiaro degli script dei video
TOL = 10  # distanza di colore dal contorno: gli artigli grigi di Bradipo stanno a più di 20
GAP = 3  # pixel: si riaprono le fessure larghe fino a 2 * GAP, cioè quelle che il contorno aveva chiuso
MIN_HOLE = 12  # pixel: i buchi più piccoli sono puntini dentro la polvere o le nuvole chiare, non fessure


def light_rim(rgba):
    """I pixel del contorno chiaro: vicini al suo colore e azzurrini (lo sputo e la scia sono verdini)."""
    rgb = rgba[..., :3].astype(np.float32)
    near = np.abs(rgb - OUTLINE).max(-1) < TOL
    return near & (rgb[..., 2] >= rgb[..., 1] - 1) & (rgba[..., 3] > 0)


def gaps(body):
    """Dove la chiusura del corpo riempie: le fessure strette tra due parti del disegno."""
    return ndi.binary_closing(body, iterations=GAP, border_value=0) & ~body


def open_frame(rgba):
    rim = light_rim(rgba)
    body = (rgba[..., 3] > 127) & ~rim
    hole = rim & gaps(body)
    lab, n = ndi.label(hole)
    if n:
        sizes = ndi.sum(hole, lab, range(1, n + 1))
        hole &= np.isin(lab, np.nonzero(sizes >= MIN_HOLE)[0] + 1)
    out = rgba.copy()
    out[hole] = 0
    return out, int(hole.sum())


def open_strip(path, fw):
    im = np.array(Image.open(path).convert("RGBA"))
    out = im.copy()
    total = 0
    for x in range(0, im.shape[1], fw):  # fotogramma per fotogramma: la chiusura non passa da uno all'altro
        out[:, x:x + fw], n = open_frame(im[:, x:x + fw])
        total += n
    if total:
        # come save() negli script dei video: 256 colori con l'alfa
        q = Image.fromarray(out, "RGBA").quantize(256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
        q.save(path, optimize=True)
    return total


def frame_width(folder):
    import json
    game = json.load(open("godot/data/game.json", encoding="utf-8"))
    rel = os.path.relpath(folder, "public").replace(os.sep, "/")
    for c in game["characters"].values():
        for sprite in [c.get("sprite")] + [s["sprite"] for s in (c.get("skins") or {}).values()]:
            if isinstance(sprite, dict) and sprite.get("dir") == rel:
                return int(sprite["frameWidth"])
    raise SystemExit("%s non è la cartella di nessuno sprite in godot/data/game.json (npm run export:godot?)" % folder)


def main(folders):
    for folder in folders:
        fw = frame_width(folder)
        for name in sorted(os.listdir(folder)):
            if name.endswith(".png") and name != "portrait.png":
                n = open_strip(os.path.join(folder, name), fw)
                if n:
                    print("%s/%s: %d pixel riaperti" % (folder, name, n))


if __name__ == "__main__":
    main(sys.argv[1:])
