# Motore: un disegno originale di Marco diviso in strati, uno scheletro con le giunture e una deformazione
# rigida morbida (MLS, Schaefer 2006) per strato. La testa si muove rigida: i pixel del disegno restano quelli.
import numpy as np, cv2, math
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
from lib import load, FW, FH, OUTLINE

Z = 2                               # si lavora a 2x e si torna a 1x alla fine
PX, PT = 48, 64                     # margine attorno al fotogramma originale: 400x260, piedi a 246
CW, CH = FW + 2 * PX, FH + PT
INK = np.array([12., 10., 12.])

def premul_resize(rgba, size):
    a = rgba[..., 3:] / 255
    ch = [cv2.resize(np.ascontiguousarray(c), size, interpolation=cv2.INTER_LANCZOS4 if size[0] > rgba.shape[1] else cv2.INTER_AREA)
          for c in np.moveaxis(np.concatenate([rgba[..., :3] * a, rgba[..., 3:]], -1), -1, 0)]
    out = np.stack(ch, -1); al = np.clip(out[..., 3], 0, 255)
    rgb = out[..., :3] / np.maximum(al / 255, 1e-4)[..., None]
    return np.dstack([np.clip(rgb, 0, 255), al]).astype(np.float32)

def poly_mask(polys, shape, ss=4):
    H, W = shape
    im = Image.new('L', (W * ss, H * ss), 0); d = ImageDraw.Draw(im)
    for p in polys:
        d.polygon([((x + PX) * Z * ss, (y + PT) * Z * ss) for x, y in p], fill=255)
    return np.asarray(im.resize((W, H), Image.BOX), np.float32) / 255

def mls_map(src, dst, shape, alpha=1.0):
    """Mappa all'indietro per cv2.remap: per ogni pixel di arrivo, da dove prenderlo. src, dst: (n,2) in px 2x."""
    H, W = shape
    q = np.array(dst, np.float64); p = np.array(src, np.float64)
    if np.allclose(q, p):
        return None
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float64)
    v = xs + 1j * ys
    qc = q[:, 0] + 1j * q[:, 1]; pc = p[:, 0] + 1j * p[:, 1]
    d2 = np.abs(v[..., None] - qc) ** 2
    w = 1.0 / np.maximum(d2, 1e-3) ** alpha
    sw = w.sum(-1)
    qs = (w * qc).sum(-1) / sw; ps = (w * pc).sum(-1) / sw
    qh = qc - qs[..., None]; ph = pc - ps[..., None]
    m = (w * np.conj(qh) * ph).sum(-1)
    m = m / np.maximum(np.abs(m), 1e-9)
    f = (v - qs) * m + ps
    return f.real.astype(np.float32), f.imag.astype(np.float32)

def rot(v, deg):
    a = math.radians(deg); c, s = math.cos(a), math.sin(a)
    return (v[0] * c - v[1] * s, v[0] * s + v[1] * c)

def layer_tf(rgba, a=1.0, s=1.0, r=0.0, t=(0, 0), c=None, sx=None, sy=None, flip=False):
    """Trasforma uno strato attorno al centro c (1x): opacità a, scala s (o sx, sy), rotazione r gradi, spostamento t."""
    H, W = rgba.shape[:2]
    if c is None:
        ys, xs = np.nonzero(rgba[..., 3] > 8)
        c = ((xs.min() + xs.max()) / 2 / Z - PX, (ys.min() + ys.max()) / 2 / Z - PT) if len(xs) else (FW / 2, FH / 2)
    cx, cy = (c[0] + PX) * Z, (c[1] + PT) * Z
    sx_, sy_ = (sx if sx is not None else s), (sy if sy is not None else s)
    if flip: sx_ = -sx_
    if (sx_, sy_, r, tuple(t)) != (1, 1, 0, (0, 0)):
        R = cv2.getRotationMatrix2D((0, 0), -r, 1.0)[:, :2]
        A = R @ np.diag([sx_, sy_])
        tt = np.array([cx, cy]) - A @ np.array([cx, cy]) + np.array(t) * Z
        M = np.hstack([A, tt[:, None]])
        a_ = rgba[..., 3:] / 255
        pm = np.concatenate([rgba[..., :3] * a_, rgba[..., 3:]], -1)
        pm = cv2.warpAffine(pm, M, (W, H), flags=cv2.INTER_CUBIC, borderValue=0)
        al = np.clip(pm[..., 3], 0, 255)
        rgba = np.dstack([np.clip(pm[..., :3] / np.maximum(al / 255, 1e-4)[..., None], 0, 255), al]).astype(np.float32)
    if a != 1.0:
        rgba = rgba.copy(); rgba[..., 3] *= a
    return rgba

def over(dst, src):
    """src sopra dst, RGBA non premoltiplicati della stessa misura."""
    a = src[..., 3:] / 255; b = dst[..., 3:] / 255
    al = a + b * (1 - a)
    rgb = (src[..., :3] * a + dst[..., :3] * b * (1 - a)) / np.maximum(al, 1e-4)
    return np.concatenate([rgb, al * 255], -1).astype(np.float32)

class Rig:
    """spec: src (nome, fotogramma), joints {nome: (x, y, genitore)}, layers dal basso: id, poly | rest, handles,
    fill (poligoni copiati dal disegno anche se di altri), inpaint (poligoni ricostruiti), ink, claim (ordine)."""
    def __init__(self, spec):
        self.spec = spec
        base = load(*spec['src']) if isinstance(spec['src'], tuple) else spec['src']
        self.H, self.W = CH * Z, CW * Z
        base = np.pad(base, ((PT, 0), (PX, PX), (0, 0)))
        self.img = premul_resize(base, (self.W, self.H))
        self.joints = {n: (x + PX, y + PT, p) for n, (x, y, p) in spec['joints'].items()}
        self.layers = []
        A = self.img[..., 3] / 255
        shape = (self.H, self.W)
        free = np.ones(shape, np.float32)
        owned = {}
        for lid in spec.get('claim', []):
            L = next(l for l in spec['layers'] if l['id'] == lid)
            m = (poly_mask(L['poly'], shape) > 0.5).astype(np.float32) if L.get('poly') else np.zeros(shape, np.float32)
            if 'color' in L: m = m * L['color'](self.img)
            for polys, fn in L.get('also', []):
                e = (poly_mask(polys, shape) > 0.5).astype(np.float32)
                if fn is not None: e = e * fn(self.img)
                m = np.maximum(m, e)
            m = m * free; owned[lid] = owned.get(lid, 0) + m; free = free - m
        for L in spec['layers']:
            if L.get('rest'): owned[L['id']] = free
        self._owned = owned
        for L in spec['layers']:
            m = owned.get(L['id'], np.zeros(shape, np.float32))
            rgb = self.img[..., :3].copy(); al = A * m
            if L.get('fill'):
                f = poly_mask(L['fill'], shape)
                al = np.maximum(al, A * f)
            if L.get('inpaint'):
                # si ricostruisce solo dove i pixel erano di altri strati, e solo col colore pieno (niente inchiostro)
                hole = (poly_mask(L['inpaint'], shape) > 0.5) & (al < 0.5)
                known = al > 0.9
                dark = rgb.max(-1) < 90
                near = ndi.binary_dilation(hole, iterations=10)
                mask = (hole | (near & ~known) | (near & dark)).astype(np.uint8)
                src8 = np.clip(rgb, 0, 255).astype(np.uint8)
                filled = cv2.inpaint(src8, mask, 9, cv2.INPAINT_TELEA).astype(np.float32)
                ring = ndi.binary_dilation(hole, iterations=10) & known & (rgb.max(-1) > 140)
                if ring.any():
                    col = np.median(rgb[ring], 0)
                    filled = filled * 0.25 + col * 0.75
                filled = cv2.GaussianBlur(filled, (0, 0), 1.5)
                rgb = np.where(hole[..., None], filled, self.img[..., :3])
                al = np.where(hole, 1.0, al)
            if L.get('rest'):
                # sottofondo: lo strato di base si allunga di qualche pixel sotto testa e arti, col suo colore pieno,
                # così quando un pezzo si muove non si apre un buco sullo sfondo
                tgt = [k for k in owned if k != L['id'] and k.startswith(('head', 'arm'))]   # non sotto gambe ed effetti
                others = sum((owned[k] for k in tgt), np.zeros(shape, np.float32))
                own = al > 0.5
                band = ndi.binary_dilation(own, iterations=L.get('under_px', 6) * Z) & ~own & (others > 0.5) & (A > 0.5)
                if 'head' in owned:
                    # sotto la testa solo all'altezza del collo: altrove il sottofondo sporgerebbe negli allungamenti
                    hy = np.nonzero((owned['head'] > 0.5).any(1))[0]
                    if len(hy):
                        neck_band = np.zeros(shape, bool); neck_band[max(0, hy.max() - 36 * Z):] = True
                        band &= ~((owned['head'] > 0.5) & ~neck_band)
                if band.any():
                    near = ndi.binary_dilation(band, iterations=8) & own & (rgb.max(-1) > 140)
                    col = np.median(rgb[near], 0) if near.any() else np.median(rgb[own], 0)
                    rgb = np.where(band[..., None], col, rgb); al = np.where(band, 1.0, al)
            if L.get('vignette'):
                v = L['vignette'] * Z
                # ellisse inscritta nel fotogramma originale: niente bordi dritti né angoli
                yy, xx = np.mgrid[0:shape[0], 0:shape[1]].astype(np.float32)
                cx, cy = (PX + FW / 2) * Z, (PT + FH / 2) * Z
                e = 1 - ((xx - cx) / (FW / 2 * Z)) ** 2 - ((yy - cy) / (FH / 2 * Z)) ** 2
                al = al * np.clip(e / (v / (FH / 2 * Z)), 0, 1) ** 1.2
            if L.get('ink', True):
                keep = poly_mask(L['noink'], shape) if L.get('noink') else None
                rgb, al = self.ink(rgb, al, L.get('ink_w', 1.25), keep)
            self.layers.append(dict(L, rgba=np.dstack([rgb, al * 255]).astype(np.float32)))

    def ink(self, rgb, al, w, keep=None):
        """Ripassa d'inchiostro il bordo dello strato (i tagli diventano tratti come gli altri); non dove keep."""
        solid = al > 0.5
        dist = ndi.distance_transform_edt(solid)
        band = np.clip((w * Z + 0.5 - dist), 0, 1) * solid
        if keep is not None: band = band * (1 - keep)
        rgb = rgb * (1 - band[..., None]) + INK * band[..., None]
        return rgb, al

    def posed(self, pose):
        """Posizioni delle giunture: pose = {giuntura: gradi}, '_root': (dx, dy), '_rootrot': (gradi, giuntura)."""
        J = self.joints
        acc, P = {}, {}
        def go(n):
            if n in P: return P[n]
            x, y, par = J[n]
            if par is None:
                dx, dy = pose.get('_root', (0, 0))
                P[n] = (x + dx, y + dy); acc[n] = pose.get(n, 0) + pose.get('_rootrot', 0)
            else:
                px, py = go(par)
                rx, ry = J[par][0], J[par][1]
                v = rot((x - rx, y - ry), acc[par])
                P[n] = (px + v[0], py + v[1]); acc[n] = acc[par] + pose.get(n, 0)
            return P[n]
        for n in J: go(n)
        return P, acc

    def handles(self, names, P):
        src, dst = [], []
        J = self.joints
        for i, n in enumerate(names):
            src.append(J[n][:2]); dst.append(P[n])
            if i + 1 < len(names):  # punti in mezzo ai segmenti: tengono rigido l'osso
                m = names[i + 1]
                for t in (0.33, 0.66):
                    src.append(tuple(np.add(J[n][:2], t * np.subtract(J[m][:2], J[n][:2]))))
                    dst.append(tuple(np.add(P[n], t * np.subtract(P[m], P[n]))))
        return np.array(src) * Z, np.array(dst) * Z

    def render(self, pose, extra=None, order=None):
        """Compone gli strati in posa; extra = {id strato: funzione(rgba) -> rgba} per ritocchi a mano."""
        P, acc = self.posed(pose)
        out = np.zeros((self.H, self.W, 4), np.float32)
        layers = self.layers
        if order: layers = sorted(layers, key=lambda l: order.index(l['id']) if l['id'] in order else -1)
        for L in layers:
            if pose.get('_hide', ()) and L['id'] in pose['_hide']: continue
            rgba = L['rgba']
            hs = L.get('handles')
            if hs:
                s, d = self.handles(hs, P)
                if len(s) == 1 or L.get('rigid'):
                    # rigido: due punti lontani bastano a dare rotazione e spostamento esatti
                    s, d = self.handles(hs[:2], P) if len(hs) > 1 else (s, d)
                mp = mls_map(s, d, (self.H, self.W))
                if mp is not None:
                    rgba = cv2.remap(rgba, mp[0], mp[1], cv2.INTER_CUBIC, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
                    rgba[..., 3] = np.clip(rgba[..., 3], 0, 255); rgba[..., :3] = np.clip(rgba[..., :3], 0, 255)
            lt = pose.get('_lt', {}).get(L['id'])
            if lt:
                rgba = layer_tf(rgba, **lt)
            if extra and L['id'] in extra: rgba = extra[L['id']](rgba)
            out = over(out, rgba)
        return out

def tf2x(rgba2x, squash=(1, 1), pivot=None, shift=(0, 0), rotdeg=0):
    return finish(rgba2x, squash, pivot, shift, rotdeg, outline=None)

def finish(rgba2x, squash=(1, 1), pivot=None, shift=(0, 0), rotdeg=0, outline=True):
    """Schiacciamento/rotazione globali, ritorno a 1x e contorno chiaro di 2 px come i disegni originali."""
    H, W = rgba2x.shape[:2]
    if squash != (1, 1) or rotdeg or shift != (0, 0):
        px, py = (pivot or (FW / 2, 182))
        px, py = (px + PX) * Z, (py + PT) * Z
        M = cv2.getRotationMatrix2D((px, py), -rotdeg, 1.0)
        M[0] *= squash[0]; M[1] *= squash[1]
        M[0, 2] += px * (1 - squash[0]) * 0 ; M[1, 2] += 0
        # scala attorno al perno: x' = sx*(x-px)+px
        A = np.array([[squash[0], 0], [0, squash[1]]]) @ M[:, :2]
        t = np.array([px, py]) - A @ np.array([px, py]) + np.array(shift) * Z
        M2 = np.hstack([A, t[:, None]])
        a = rgba2x[..., 3:] / 255
        pm = np.concatenate([rgba2x[..., :3] * a, rgba2x[..., 3:]], -1)
        pm = cv2.warpAffine(pm, M2, (W, H), flags=cv2.INTER_CUBIC, borderValue=0)
        al = np.clip(pm[..., 3], 0, 255)
        rgba2x = np.dstack([np.clip(pm[..., :3] / np.maximum(al / 255, 1e-4)[..., None], 0, 255), al])
    if outline is None: return rgba2x
    small = premul_resize(rgba2x, (W // Z, H // Z))
    if not outline: return small
    a = small[..., 3] / 255
    solid = a > 0.45
    ring = ndi.gaussian_filter(ndi.binary_dilation(solid, iterations=2).astype(np.float32), 0.55)
    rgb = small[..., :3] * a[..., None] + OUTLINE * ring[..., None] * (1 - a[..., None])
    al = a + ring * (1 - a)
    rgb = rgb / np.maximum(al, 1e-3)[..., None]
    return np.dstack([rgb, al * 255]).astype(np.float32)
