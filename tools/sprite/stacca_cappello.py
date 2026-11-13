#!/usr/bin/env python3
"""Stacca il cappello rosa di Marcomunista dalle strisce (Nicola, 13/11/2026).

Per ogni fotogramma di ogni stato in public/assets/characters/<id>/:
- trova il cappello (rosa fluo con le foglie gialle e il suo contorno) e lo cancella;
- se sotto c'è la testa, ci disegna la cupola calva col colore della pelle;
- scrive in cappello.json ("states") dove stava: [x, y, gradi, larghezza] coi pixel del fotogramma, con l'origine
  sui piedi (centro in basso, footY), come mani.json; null dove non si vede.
Salva anche cappello.png, il cappello del primo fotogramma del fermo (in "image" larghezza del rosa e centro): il gioco lo disegna sopra la testa
quando lo indossa e lo usa come Cappello boomerang quando lo lancia.

Uso: python3 tools/sprite/stacca_cappello.py marcomunista [footY]
Si lancia una volta sola sulle strisce col cappello: rilanciato su strisce già calve non trova niente.
"""
import colorsys
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

cid = sys.argv[1] if len(sys.argv) > 1 else "marcomunista"
FOOT_Y = int(sys.argv[2]) if len(sys.argv) > 2 else 206
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
        # La testa sotto: la pelle appena sotto il cappello
        below = skin[y1 - 1:min(FH, y1 + 7), max(0, x0 - 4):x1 + 5]
        bys, bxs = np.nonzero(below)
        if len(bxs) >= 6:
            hx0, hx1 = bxs.min() + max(0, x0 - 4), bxs.max() + max(0, x0 - 4)
            hw = hx1 - hx0 + 1
            col = np.median(fr[y1 - 1:min(FH, y1 + 7), max(0, x0 - 4):x1 + 5][below][:, :3], axis=0).astype(np.uint8)
            ccx, base = (hx0 + hx1) / 2, y1 + 3
            ra, rb = hw / 2 + 0.5, max(5.0, hw * 0.62)
            for yy in range(int(base - rb) - 1, int(base) + 1):
                for xx in range(int(ccx - ra) - 1, int(ccx + ra) + 2):
                    if not (0 <= yy < FH and 0 <= xx < FW):
                        continue
                    d = ((xx - ccx) / ra) ** 2 + ((yy - base) / rb) ** 2
                    if d <= 1.0 and fr[yy, xx, 3] < 100:
                        fr[yy, xx, :3] = col
                        fr[yy, xx, 3] = 255
            # il contorno: scuro sul bordo della cupola, poi quello chiaro di tutte le pose
            dome = np.zeros((FH, FW), bool)
            for yy in range(int(base - rb) - 1, int(base) + 1):
                for xx in range(int(ccx - ra) - 1, int(ccx + ra) + 2):
                    if 0 <= yy < FH and 0 <= xx < FW and ((xx - ccx) / ra) ** 2 + ((yy - base) / rb) ** 2 <= 1.0:
                        dome[yy, xx] = True
            solid = fr[..., 3] > 100
            edge = dome & dilate(~solid, 1)
            fr[edge, :3] = (col * 0.45).astype(np.uint8)
            halo = dilate(dome, 2) & ~solid & (np.arange(FH)[:, None] <= base)
            fr[halo] = [226, 226, 232, 255]
            # il riflesso della pelata
            hx, hy = int(ccx - ra * 0.3), int(base - rb * 0.6)
            if 0 <= hy < FH and 0 <= hx < FW and fr[hy, hx, 3] > 0:
                fr[hy, hx, :3] = np.minimum(255, col.astype(int) + 70)
        a[:, f * FW:(f + 1) * FW] = fr
    Image.fromarray(a).save(path, optimize=True)
    return pts, hat_crop


def main():
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
    meta = {}
    if hat:
        c, px, py, w = hat
        meta = {"w": int(w), "cx": round(float(px), 1), "cy": round(float(py), 1)}
    (D / "cappello.json").write_text(json.dumps({"image": meta, "states": data}, separators=(",", ":")) + "\n")
    if hat:
        Image.fromarray(c).save(D / "cappello.png", optimize=True)
        print(f"cappello.png {c.shape[1]}x{c.shape[0]}, centro {px:.1f},{py:.1f}, largo {w}")


main()
