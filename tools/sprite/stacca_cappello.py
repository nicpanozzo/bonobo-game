#!/usr/bin/env python3
"""Stacca il cappello rosa di Marcomunista dalle strisce (Nicola, 13/11/2026).

Per ogni fotogramma di ogni stato in public/assets/characters/<id>/:
- trova il cappello (rosa fluo con le foglie gialle e il suo contorno) e lo cancella;
- se sotto c'è la testa, ci disegna la cupola calva col colore della pelle;
- scrive in cappello.json ("states") dove stava: [x, y, gradi, larghezza] coi pixel del fotogramma, con l'origine
  sui piedi (centro in basso, footY), come mani.json; null dove non si vede.
Salva anche cappello.png, il cappello del primo fotogramma del fermo (in "image" larghezza del rosa e centro): il gioco lo disegna sopra la testa
quando lo indossa e lo usa come Cappello boomerang quando lo lancia.

Uso: python3 tools/sprite/stacca_cappello.py marcomunista [footY] [--controlla]
Con --controlla non tocca le strisce: ricontrolla solo i punti di cappello.json su quelle già calve
(toglie quelli lontani dal corpo, gira di 180 gradi quelli a testa in giù).
Si lancia una volta sola sulle strisce col cappello: rilanciato su strisce già calve non trova niente.
"""
import colorsys
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
cid = ARGS[0] if ARGS else "marcomunista"
FOOT_Y = int(ARGS[1]) if len(ARGS) > 1 else 206
D = Path("public/assets/characters") / cid
FW, FH = 400, 240


def hsv(a):
    rgb = a[..., :3].astype(float) / 255
    mx, mn = rgb.max(-1), rgb.min(-1)
    d = mx - mn + 1e-9
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    s = np.where(mx > 0, d / (mx + 1e-9), 0)
    return h, s, mx


def dilate(m, n=1):
    out = m.copy()
    for _ in range(n):
        o = out.copy()
        o[1:] |= out[:-1]; o[:-1] |= out[1:]; o[:, 1:] |= out[:, :-1]; o[:, :-1] |= out[:, 1:]
        out = o
    return out


def hat_masks(fr):
    h, s, v = hsv(fr)
    alpha = fr[..., 3] > 100
    pink = alpha & (((h > 300) | (h < 5)) & (s > 0.45) & (v > 0.45))
    if pink.sum() < 10:
        return None
    ys, xs = np.nonzero(pink)
    # il pezzo rosa più grosso: niente dettagli rosa delle scarpe lontani dal cappello
    cy, cx = np.median(ys), np.median(xs)
    near = (np.abs(ys - cy) < 22) & (np.abs(xs - cx) < 26)
    keep = np.zeros_like(pink)
    keep[ys[near], xs[near]] = True
    pink = keep
    if pink.sum() < 10:
        return None
    ys, xs = np.nonzero(pink)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    box = np.zeros_like(pink)
    box[max(0, y0 - 2):y1 + 3, max(0, x0 - 2):x1 + 3] = True
    skin = alpha & (h > 8) & (h < 45) & (s > 0.15) & (s < 0.65) & (v > 0.55)
    # tutto quello che sta nel riquadro del cappello e non è pelle: rosa, foglie, contorno scuro e chiaro
    region = np.zeros_like(pink)
    region[max(0, y0 - 6):y1 + 2, max(0, x0 - 5):x1 + 6] = True
    full = region & (fr[..., 3] > 0) & ~(skin & ~dilate(pink, 1)) # anche i bordi semitrasparenti
    full &= dilate(pink, 6)
    return full, pink, (x0, y0, x1, y1), skin


# La calotta calva presa da un fotogramma della clip calva (in-attesa/hatBounce.png, fotogramma 0): dalla cima
# della testa fino a sopra le sopracciglia, col contorno chiaro. bottom: larghezza della testa all'ultima riga
DOME_SRC = ("in-attesa/hatBounce.png", 0, 15)  # file, fotogramma, righe dalla cima del contorno


def dome_patch():
    src, f, rows = DOME_SRC
    a = np.array(Image.open(D / src).convert("RGBA"))[:, f * FW:(f + 1) * FW]
    al = a[..., 3] > 0
    ys, xs = np.nonzero(al)
    top = ys.min()
    # solo la testa: le colonne della testa alla riga più bassa della calotta
    row = np.nonzero(a[top + rows, :, 3] > 100)[0]
    runs = np.split(row, np.nonzero(np.diff(row) > 1)[0] + 1)
    head = runs[0]
    hx0, hx1 = head.min() - 3, head.max() + 3
    p = a[top:top + rows + 1, hx0:hx1 + 1].copy()
    return p, head.max() - head.min() + 1, (head.min() + head.max()) / 2 - hx0


DOME = None


def put_dome(fr, cx, y1, deg, hole):
    global DOME
    if DOME is None:
        DOME = dome_patch()
    patch, pw, pcx = DOME
    # la testa sotto il cappello: il pezzo pieno della riga sotto la tesa che sta sotto il cappello
    for yb in range(int(y1) + 1, min(FH, int(y1) + 6)):
        row = np.nonzero(fr[yb, :, 3] > 100)[0]
        if len(row) == 0:
            continue
        runs = np.split(row, np.nonzero(np.diff(row) > 1)[0] + 1)
        run = min(runs, key=lambda r: abs((r.min() + r.max()) / 2 - cx))
        if run.min() - 4 <= cx <= run.max() + 4 and 8 <= len(run) <= 60:
            break
    else:
        return
    k = len(run) / pw
    ph, pwid = patch.shape[:2]
    img = Image.fromarray(patch).resize((max(1, round(pwid * k)), max(1, round(ph * k))), Image.NEAREST)
    # ruota intorno al centro della riga di base, come il cappello
    bx, by = pcx * k, img.size[1] - 1
    pad = max(img.size) * 2
    canvas = Image.new("RGBA", (pad * 2, pad * 2))
    canvas.paste(img, (int(pad - bx), int(pad - by)))
    canvas = canvas.rotate(-deg, resample=Image.NEAREST, center=(pad, pad))
    c = np.array(canvas)
    ox, oy = int(round((run.min() + run.max()) / 2 - pad)), int(yb + 1 - pad)
    ys, xs = np.nonzero(c[..., 3] > 0)
    for y, x in zip(ys, xs):
        X, Y = x + ox, y + oy
        if 0 <= X < FW and 0 <= Y < FH and Y <= yb + 1 and fr[Y, X, 3] < 100:
            fr[Y, X] = c[y, x]
    # i puntini delle foglie rimasti intorno alla testa
    near = dilate(hole, 3)
    solid = fr[..., 3] > 0
    lab, n = ndimage.label(solid)
    for i in range(1, n + 1):
        comp = lab == i
        if comp.sum() < 14 and (comp & near).any():
            fr[comp] = 0


def frames_of(img):
    return img.size[0] // FW


def process_state(path, hat_img_out=None):
    img = Image.open(path).convert("RGBA")
    a = np.array(img)
    pts = []
    hat_crop = None
    for f in range(frames_of(img)):
        fr = a[:, f * FW:(f + 1) * FW]
        m = hat_masks(fr)
        if m is None:
            pts.append(None)
            continue
        full, pink, (x0, y0, x1, y1), skin = m
        ys, xs = np.nonzero(pink)
        cxh, cyh = xs.mean(), ys.mean()
        cov = np.cov(np.stack([xs - cxh, ys - cyh])) if len(xs) > 2 else np.eye(2)
        w_, v_ = np.linalg.eigh(cov)
        ax = v_[:, int(np.argmax(w_))]
        deg = math.degrees(math.atan2(ax[1], ax[0]))
        if deg > 90: deg -= 180
        if deg < -90: deg += 180
        deg = max(-40.0, min(40.0, deg))
        pts.append([round(cxh - FW / 2, 1), round(cyh - FOOT_Y, 1), round(deg, 1), int(x1 - x0 + 1)])
        if hat_crop is None:
            fy, fx = np.nonzero(full)
            c = fr[fy.min():fy.max() + 1, fx.min():fx.max() + 1].copy()
            c[..., 3] = np.where(full[fy.min():fy.max() + 1, fx.min():fx.max() + 1], c[..., 3], 0)
            hat_crop = (c, cxh - fx.min(), cyh - fy.min(), x1 - x0 + 1)
        # Cancella il cappello
        fr[full] = 0
        # La pelata: la calotta vera dei fotogrammi calvi (clip hatBounce), larga quanto la testa sotto il cappello
        # e inclinata come il cappello; riempie solo il vuoto lasciato dal cappello, la faccia resta quella disegnata
        put_dome(fr, (x0 + x1) / 2, y1, deg, full)
        a[:, f * FW:(f + 1) * FW] = fr
    Image.fromarray(a).save(path, optimize=True)
    return pts, hat_crop


def check(data):
    """Un punto vale se sta sulla testa: vicino al corpo (il cappello caduto per terra nella clip no).
    A testa in giù (punto sotto il centro del corpo) il cappello si gira."""
    for state, pts in data.items():
        a = np.array(Image.open(D / f"{state}.png").convert("RGBA"))
        for f, p in enumerate(pts):
            if not p:
                continue
            fr = a[:, f * FW:(f + 1) * FW, 3] > 100
            ys, xs = np.nonzero(fr)
            if len(xs) == 0:
                pts[f] = None
                continue
            x, y = p[0] + FW / 2, p[1] + FOOT_Y
            if np.min((xs - x) ** 2 + (ys - y) ** 2) > 8 ** 2:
                pts[f] = None
                continue
            if y > ys.mean() + 10 and abs(p[2]) <= 90:
                p[2] = round(p[2] + 180.0, 1)
    return data


def main():
    if "--controlla" in sys.argv:
        j = json.loads((D / "cappello.json").read_text())
        j["states"] = check(j["states"])
        (D / "cappello.json").write_text(json.dumps(j, separators=(",", ":")) + "\n")
        print("punti ricontrollati")
        return
    data = {}
    hat = None
    order = sorted(D.glob("*.png"), key=lambda p: (p.stem != "idle", p.stem))
    for p in order:
        if p.stem == "portrait":
            continue
        pts, crop = process_state(p)
        if any(pts):
            data[p.stem] = pts
        if p.stem == "idle" and crop is not None:
            hat = crop
        print(f"{p.stem}: cappello in {sum(1 for x in pts if x)} fotogrammi su {len(pts)}")
    data = check(data)
    meta = {}
    if hat:
        c, px, py, w = hat
        meta = {"w": int(w), "cx": round(float(px), 1), "cy": round(float(py), 1)}
    (D / "cappello.json").write_text(json.dumps({"image": meta, "states": data}, separators=(",", ":")) + "\n")
    if hat:
        Image.fromarray(c).save(D / "cappello.png", optimize=True)
        print(f"cappello.png {c.shape[1]}x{c.shape[0]}, centro {px:.1f},{py:.1f}, largo {w}")


main()
