# Le animazioni della tavola: ogni stato è una lista di fotogrammi a 1x (400x260, piedi a 246).
# Si combinano più disegni originali (carica, colpo, ritorno) e si muovono a pezzi; gli effetti sono in fx.py.
import sys, math, numpy as np
sys.path.insert(0, '/home/claude/marco2')
from engine import Rig, finish, tf2x, layer_tf, over, Z, PX, PT, FW
from rigs import ALL
import fx

_R = {}
def rig(n):
    if n not in _R: _R[n] = Rig(ALL[n])
    return _R[n]

def _apply(pt, squash, pivot, shift, rotdeg):
    """Dove va un punto (1x, fotogramma originale) con le trasformazioni globali di finish()."""
    import cv2
    px, py = pivot or (FW / 2, 182)
    M = cv2.getRotationMatrix2D((px, py), -rotdeg, 1.0)
    A = np.diag(squash) @ M[:, :2]
    t = np.array([px, py]) - A @ np.array([px, py]) + np.array(shift)
    return A @ np.array(pt) + t

def P(n, pose=None, hide=(), squash=(1, 1), rotdeg=0, shift=(0, 0), pivot=None):
    """Il personaggio in posa, a 2x, con le trasformazioni globali. Se il disegno ha la testa a parte, gli
    schiacciamenti e gli allungamenti toccano solo il corpo: la testa resta il disegno originale e segue il collo."""
    r = rig(n)
    pose = dict(pose or {})
    has_head = any(l['id'] == 'head' for l in r.layers)
    if tuple(squash) == (1, 1) or not has_head or 'head' in hide:
        if hide: pose['_hide'] = tuple(hide)
        return tf2x(r.render(pose), squash=squash, pivot=pivot, shift=shift, rotdeg=rotdeg)
    body = tf2x(r.render(dict(pose, _hide=tuple(hide) + ('head',))), squash=squash, pivot=pivot, shift=shift, rotdeg=rotdeg)
    head = r.render(dict(pose, _hide=tuple(l['id'] for l in r.layers if l['id'] != 'head')))
    if 'neck' in r.joints:
        Pp, _ = r.posed(pose)
        neck = (Pp['neck'][0] - PX, Pp['neck'][1] - PT)
    else:
        ys, xs = np.nonzero(head[..., 3] > 128)
        neck = (xs.mean() / Z - PX, ys.max() / Z - PT)
    d = _apply(neck, squash, pivot, shift, rotdeg) - _apply(neck, (1, 1), pivot, shift, rotdeg)
    # la testa si schiaccia appena (un terzo), per non staccarsi dal corpo senza deformare la faccia
    hs = (1 + (squash[0] - 1) * 0.0, 1 + (squash[1] - 1) * 0.0)
    head = tf2x(head, squash=hs, pivot=pivot, shift=(shift[0] + d[0], shift[1] + d[1]), rotdeg=rotdeg)
    return over(body, head)

def L(n, lid, **lt):
    """Uno strato di un disegno (per esempio l'arco rosa) trasformato da solo."""
    lay = next(l for l in rig(n).layers if l['id'] == lid)['rgba']
    return layer_tf(lay, **lt) if lt else lay

def F(char, under=(), top=(), soft_under=(), soft_over=(), glow=None):
    img = fx.stack(*under, char, *top)
    out = finish(img)
    if glow: out = over(fx.glow1x(out, glow[0], r=glow[1], a=glow[2]), out)
    for s in soft_under: out = over(s, out)
    for s in soft_over: out = over(out, s)
    return out

def shake(i, a=1.5):
    return (a * math.sin(i * 2.7), a * 0.5 * math.cos(i * 3.9))

FOOT = 182

# ---------------- movimento ----------------

def idle(n=8):
    out = []
    for i in range(n):
        t = i / n * 2 * math.pi
        b = (1 - math.cos(t)) / 2
        smoke = []
        for k in range(4):
            u = (i / n + k / 4) % 1                       # ogni sbuffo sale e si allarga
            smoke.append((201 + 6 * u + 2.5 * math.sin(6.28 * u + k), 62 - 34 * u, 1.8 + 4.5 * u, 0.55 * (1 - u) ** 1.3))
        out.append(F(P('IDLE', {'neck': -1.5 * b + 0.6, 'chest': 0.4 * b}, squash=(1 + 0.012 * b, 1 - 0.02 * b)),
                     soft_over=[fx.soft_dots(smoke, (200, 202, 212), 1.4)]))
    return out

def walk(n=12):
    out = []
    A = 21
    for i in range(n):
        ph = i / n
        pose = {}
        for side, off in (('F', 0.0), ('B', 0.5)):
            p = (ph + off) % 1
            th = -A * math.cos(2 * math.pi * p)
            knee = 36 * math.sin(math.pi * (p - 0.5) / 0.5) if p >= 0.5 else 5 * math.sin(math.pi * p / 0.5)
            ank = (-10 + 28 * math.sin(math.pi * (p - 0.3) / 0.4)) if 0.3 <= p <= 0.7 else -10 * math.cos(2 * math.pi * p)
            pose['hip' + side] = th; pose['knee' + side] = knee; pose['ank' + side] = ank - knee * 0.45
        bob = abs(math.sin(2 * math.pi * ph))
        pose['_root'] = (0, -2.8 * bob)
        pose['neck'] = 1.6 * math.sin(4 * math.pi * ph + 0.6)
        pose['chest'] = 1.2 * math.sin(2 * math.pi * ph)
        out.append(F(P('IDLE', grounded('IDLE', pose, lift=2.5 * bob), rotdeg=1.5)))
    return out

def run_pose(ph):
    """Corsa a forbice attorno al disegno: le gambe si chiudono e si riaprono, le braccia pompano, il corpo rimbalza."""
    w = math.cos(2 * math.pi * ph)               # 1: aperte come nel disegno, -1: chiuse sotto il corpo
    k = (1 - w) / 2
    up = math.sin(2 * math.pi * ph)
    return {
        'hipF': 26 * k, 'kneeF': 22 * k + 10 * max(0, up), 'ankF': 12 * k,
        'hipB': -30 * k, 'kneeB': 30 * k, 'ankB': -10 * k,
        'shoF': 24 * k - 6, 'elbF': -18 * k, 'shoB': -26 * k + 4, 'elbB': 10 * k,
        'neck': 2.5 * up, 'chest': 2 * up,
    }

def grounded(rn, pose, feet=('ankB', 'toeB', 'ankF', 'toeF'), lift=0.0):
    """Sposta la radice perché il piede più basso tocchi terra come nel disegno (meno lift, per i passi in volo)."""
    r = rig(rn)
    rest = max(r.joints[f][1] for f in feet)
    p = dict(pose); p['_root'] = (p.get('_root', (0, 0))[0], 0)
    P_, _ = r.posed(p)
    low = max(P_[f][1] for f in feet)
    p['_root'] = (p['_root'][0], rest - low - lift)
    return p

def run(n=8):
    out = []
    for i in range(n):
        ph = i / n
        lift = 7 * max(0, -math.cos(2 * math.pi * ph))              # in alto quando le gambe sono chiuse
        body = P('RUN', grounded('RUN', run_pose(ph), lift=lift), rotdeg=3)
        puff = fx.dust_ring(92, FOOT, (ph * 2) % 1, n=2, side='back', spread=22, r0=5, seed=i) if i % 2 == 0 else None
        out.append(F(body, under=[puff]))
    return out

def dash():
    d0 = P('LAND', squash=(1.07, 0.9))
    d1 = P('DASH', squash=(1.08, 0.95), shift=(-6, 0), pivot=(130, FOOT))
    d2 = P('DASH', shift=(4, 0))
    d3 = P('DASH', {'_lt': {'fx': dict(a=0.6, sx=0.7, c=(110, 80))}}, shift=(8, 0), rotdeg=-3, pivot=(130, FOOT))
    d4 = P('RUN', run_pose(0.0), rotdeg=4, shift=(6, 0))
    d5 = P('RUN', run_pose(0.25), shift=(4, 0))
    return [
        F(d0, under=[fx.dust_ring(150, FOOT, 0.0, n=3, side='back', spread=18)]),
        F(d1, under=[fx.ghost(d1, 0.25, t=(-22, 0)), fx.ghost(d1, 0.4, t=(-11, 0)), fx.dust_ring(110, FOOT, 0.3, side='back', spread=40)],
          top=[fx.speed_lines([(40, 70, 90, 70), (30, 90, 85, 92), (45, 112, 92, 113)])]),
        F(d2, under=[fx.ghost(d2, 0.3, t=(-12, 0)), fx.dust_ring(105, FOOT, 0.6, side='back', spread=46, seed=2)]),
        F(d3, under=[fx.dust_ring(100, FOOT, 0.9, side='back', spread=50, seed=3)]),
        F(d4), F(d5)]

def jump():
    return [
        F(P('LAND', squash=(1.08, 0.86)), under=[fx.dust_ring(150, FOOT, 0.1, n=3)]),
        F(P('JUMP', {'shoB': 25, 'shoF': -20}, squash=(0.9, 1.14), shift=(0, -8)), under=[fx.dust_ring(150, FOOT, 0.45)]),
        F(P('JUMP', {'shoB': 8, 'shoF': -6}, squash=(0.95, 1.06), shift=(0, -26)), under=[fx.dust_ring(150, FOOT, 0.85, seed=2)]),
        F(P('JUMP', shift=(0, -38))),
        F(P('JUMP', {'shoB': -25, 'elbB': -10, 'shoF': 25, 'elbF': 10}, shift=(0, -44), rotdeg=3)),
        F(P('LIGHTAIR', {'shoB': 25, 'shoF': -25}, shift=(0, -46), rotdeg=4)),
    ]

def fall():
    out = []
    for i in range(4):
        w = math.sin(i / 4 * 2 * math.pi)
        out.append(F(P('JUMP', {'shoB': -20 * w, 'elbB': -15 * w, 'shoF': 22 * w, 'elbF': 15 * w, 'neck': 3 * w},
                       rotdeg=-4 + 4 * w, shift=(0, -20))))
    for i, r in enumerate((-6, -14, -22, -30)):
        out.append(F(P('FALL', rotdeg=r, pivot=(160, 140), shift=(0, -10 - 2 * i))))
    return out

def crouch():
    return [F(P('IDLE')), F(P('IDLE', {'neck': -2}, squash=(1.04, 0.93))), F(P('LAND', squash=(0.97, 1.04))),
            F(P('LAND', squash=(1.03, 0.97))), F(P('LAND'))]

def grab():
    g1 = P('GRAB', {'shoF': -6, 'elbF': 4}, squash=(1.09, 0.97), shift=(6, 0), pivot=(120, FOOT))
    return [
        F(P('IDLE', {'neck': -3}, rotdeg=-6, shift=(-4, 0), squash=(1.03, 0.96))),
        F(g1, under=[fx.ghost(g1, 0.3, t=(-14, 0))]),
        F(P('GRAB', shift=(3, 0))),
        F(P('GRAB', {'elbF': 10, 'wriF': 12})),
    ]

def pummel():
    hit = P('GRAB', {'shoF': -8, 'elbF': 6}, rotdeg=4, shift=(4, 0), pivot=(120, FOOT))
    return [
        F(P('GRAB')),
        F(P('GRAB', {'shoF': 28, 'elbF': -40, 'neck': -3}, rotdeg=-3, shift=(-3, 0), pivot=(120, FOOT))),
        F(hit, top=[fx.star(236, 108, 13, rot=10)]),
        F(P('GRAB', {'shoF': 4}, rotdeg=1, shift=(1, 0), pivot=(120, FOOT)), top=[fx.sparks(236, 108, 6, 8, 16, seed=4)]),
    ]

def throw_f():
    om = lambda **k: L('THROW', 'fx', **k)
    body = P('THROW', hide=('fx', 'lines'))
    return [
        F(P('GRAB'), top=[om(t=(-14, 6), s=0.95, r=-10)]),
        F(P('GRAB', {'shoF': 30, 'elbF': -35}, rotdeg=-9, shift=(-8, 0), pivot=(120, FOOT)), top=[om(t=(-36, 10), r=-25)]),
        F(P('THROW', hide=('fx',)), under=[fx.ghost(body, 0.3, t=(-10, 0))], top=[om(t=(-14, 0), r=-8)]),
        F(P('THROW'), top=[fx.speed_lines([(190, 80, 215, 80), (192, 120, 212, 121)])]),
        F(body, top=[om(t=(55, -18), r=40, a=0.85), fx.speed_lines([(232, 92, 262, 84), (236, 120, 266, 114)])]),
    ]

def throw_b():
    omr = lambda **k: L('THROW', 'fx', flip=True, **k)
    return [
        F(P('GRAB'), top=[L('THROW', 'fx', t=(-14, 6), s=0.95, r=-10)]),
        F(P('GRAB', {'shoF': -55, 'elbF': -20, 'neck': -4}, rotdeg=-8, shift=(-4, 0), pivot=(120, FOOT)), top=[omr(t=(-40, -100), r=-60)]),
        F(P('HEAVYUP', hide=('fx',), rotdeg=-12, shift=(-8, 0), pivot=(140, FOOT)), top=[omr(t=(-112, -128), r=-130)]),
        F(P('HIT', rotdeg=-8, shift=(-6, 0)), top=[omr(t=(-205, -50), r=-200), fx.speed_lines([(150, 40, 120, 30), (150, 70, 118, 64)])]),
        F(P('IDLE', rotdeg=-3), top=[omr(t=(-265, -10), r=-250, a=0.7)]),
    ]

# ---------------- colpi a terra ----------------

def up_tilt():
    return [
        F(P('LAND', squash=(1.05, 0.92))),
        F(P('LIGHTUP', {'_lt': {'fx': dict(s=1.15)}}, squash=(0.94, 1.08)), top=[fx.star(196, 40, 9, rot=20)]),
        F(P('LIGHTUP', {'_lt': {'fx': dict(s=1.4, a=0.55)}})),
        F(P('LIGHTUP', hide=('fx',), squash=(1.02, 0.98))),
    ]

def side_tilt():
    hit = P('LIGHT', squash=(1.08, 0.98), shift=(8, 0), pivot=(130, FOOT))
    return [
        F(P('SPN', rotdeg=-5, shift=(-6, 0), squash=(1.03, 0.97))),
        F(hit, under=[fx.ghost(hit, 0.3, t=(-16, 0))], top=[fx.star(248, 112, 12, rot=8)]),
        F(P('LIGHT', shift=(3, 0)), top=[fx.sparks(246, 112, 7, 9, 18, seed=3)]),
        F(P('LIGHT', {'shoF': 16, 'elbF': -20, 'wriF': 6})),
    ]

def down_tilt():
    return [
        F(P('LAND', squash=(1.02, 0.97))),
        F(P('LIGHTDOWN', {'_lt': {'fx': dict(s=0.75)}}, squash=(1.06, 0.96), shift=(3, 0)), top=[fx.star(212, 172, 8)]),
        F(P('LIGHTDOWN', {'_lt': {'fx': dict(s=1.25)}}), under=[fx.dust_ring(218, FOOT, 0.4, n=3, side='front', spread=24)]),
        F(P('LIGHTDOWN', {'_lt': {'fx': dict(s=1.55, a=0.35)}}), under=[fx.dust_ring(218, FOOT, 0.8, n=3, side='front', spread=28)]),
    ]

CHG = ((255, 90, 190), 5, 0.55)

def charge_fx(cx, cy, i, n=6, r=34):
    pts = []
    for k in range(n):
        a = 2 * math.pi * k / n + i * 0.7
        rr = r * (1 - 0.3 * ((i + k) % 3) / 3)
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a), 5.0))
    return fx.twinkles(pts, color=(255, 120, 200))

def up_smash():
    return [
        F(P('LAND', squash=(1.07, 0.88), shift=shake(1)), top=[charge_fx(150, 110, 0)], glow=CHG),
        F(P('LAND', squash=(1.08, 0.87), shift=shake(2)), top=[charge_fx(150, 110, 1, r=20)], glow=CHG),
        F(P('HEAVYUP', {'_lt': {'fx': dict(s=1.1)}}, squash=(0.92, 1.12), shift=(0, -6)), top=[fx.star(186, 40, 12, rot=15)]),
        F(P('HEAVYUP', {'_lt': {'fx': dict(s=1.35, a=0.5)}}, shift=(0, -3))),
    ]

def side_smash():
    hit = P('HEAVY', squash=(1.1, 0.98), shift=(10, 0), pivot=(100, FOOT))
    return [
        F(P('SPN', rotdeg=-11, shift=(-12, 0), squash=(1.04, 0.95)), top=[charge_fx(150, 120, 0)], glow=CHG),
        F(P('SPN', rotdeg=-13, shift=(-14 + shake(3)[0], 0), squash=(1.05, 0.94)), top=[charge_fx(150, 120, 1, r=20)], glow=CHG),
        F(hit, under=[fx.ghost(hit, 0.22, t=(-28, 0)), fx.ghost(hit, 0.35, t=(-14, 0))], top=[fx.star(240, 122, 14, rot=12)]),
        F(P('HEAVY', {'_lt': {'fx': dict(s=1.3, a=0.5, c=(240, 130))}}, shift=(4, 0))),
    ]

def down_smash():
    return [
        F(P('LIGHTUP', hide=('fx',), squash=(0.96, 1.05), shift=shake(1)), top=[charge_fx(150, 100, 0)], glow=CHG),
        F(P('HEAVYDOWN', {'_lt': {'fx': dict(s=0.85, c=(220, 182))}}, squash=(1.08, 0.92)), under=[fx.dust_ring(205, FOOT, 0.3, side='both', spread=36)],
          top=[fx.star(196, 170, 10)]),
        F(P('HEAVYDOWN', {'_lt': {'fx': dict(s=1.25, c=(220, 182))}}), under=[fx.dust_ring(205, FOOT, 0.7, side='both', spread=44, seed=2)]),
        F(P('HEAVYDOWN', {'_lt': {'fx': dict(s=1.45, a=0.35, c=(220, 182))}}), under=[fx.dust_ring(205, FOOT, 1.0, side='both', spread=48, seed=3)]),
    ]

# ---------------- in aria ----------------

def nair():
    return [
        F(P('LIGHTAIR', {'shoB': 30, 'shoF': -30}, rotdeg=-10, shift=(0, -30))),
        F(P('LIGHTAIR', rotdeg=0, shift=(0, -30)), under=[fx.crescent(150, 82, 62, 200, 340, 11), fx.crescent(150, 82, 62, 20, 160, 11)]),
        F(P('LIGHTAIR', {'shoB': -12, 'shoF': 12}, rotdeg=12, shift=(0, -30)),
          under=[fx.crescent(150, 82, 64, 250, 340, 7, line=False), fx.crescent(150, 82, 64, 70, 160, 7, line=False)]),
    ]

def fair():
    hit = P('HEAVYAIR', squash=(1.07, 0.97), shift=(4, -30))
    return [
        F(P('JUMP', {'shoF': -30, 'shoB': -10}, rotdeg=-8, shift=(-4, -30))),
        F(hit, under=[fx.ghost(hit, 0.3, t=(-12, 0))]),
        F(P('HEAVYAIR', {'_lt': {'fx': dict(s=1.3, a=0.5, c=(232, 116))}}, shift=(2, -30))),
    ]

def bair():
    arc = lambda **k: L('HEAVYAIR', 'fx', flip=True, **k)
    return [
        F(P('LIGHTAIR', {'shoB': 25, 'elbB': 15, 'shoF': -15}, rotdeg=6, shift=(0, -30))),
        F(P('LIGHTAIR', {'shoB': -12, 'shoF': 10}, rotdeg=-4, shift=(4, -30)), top=[arc(t=(-160, -30))]),
        F(P('LIGHTAIR', {'shoB': -6}, rotdeg=-2, shift=(2, -30)), top=[arc(t=(-166, -30), s=1.25, a=0.5)]),
    ]

def uair():
    return [
        F(P('JUMP', {'shoF': 20, 'shoB': 20}, rotdeg=-5, shift=(0, -30))),
        F(P('RECOVERY', {'_lt': {'fx': dict(s=1.05)}}, squash=(0.93, 1.09), shift=(0, -36)), top=[fx.star(186, 40, 11)]),
        F(P('RECOVERY', {'_lt': {'fx': dict(s=1.3, a=0.5)}}, shift=(0, -38))),
    ]

def dair():
    spikes = lambda **k: L('HEAVYDOWN', 'fx', **k)
    return [
        F(P('LAND', squash=(0.95, 1.05), shift=(0, -40))),
        F(P('LAND', squash=(1.06, 0.92), shift=(0, -34)), under=[spikes(t=(-60, 2), s=1.0), spikes(t=(-110, 2), s=1.0, flip=True)]),
        F(P('LAND', shift=(0, -36)), under=[spikes(t=(-60, 2), s=1.3, a=0.5), spikes(t=(-110, 2), s=1.3, a=0.5, flip=True)]),
    ]

def landing():
    return [
        F(P('JUMP', {'shoB': -10, 'shoF': 10}, shift=(0, -10))),
        F(P('LAND', squash=(1.12, 0.84)), under=[fx.dust_ring(150, FOOT, 0.2)]),
        F(P('LAND', squash=(0.97, 1.03)), under=[fx.dust_ring(150, FOOT, 0.6, seed=2)]),
        F(P('LAND', squash=(1.02, 0.98)), under=[fx.dust_ring(150, FOOT, 0.95, seed=3)]),
        F(P('IDLE')),
    ]

def aerial_fall():
    out = []
    for i in range(4):
        w = math.sin(i / 4 * 2 * math.pi)
        lines = fx.vlines([96 + 9 * k + (i * 5) % 7 for k in range(13) if k not in (5, 6, 7)], -10 + 4 * i, 170 - 3 * i, seed=i)
        body = P('JUMP', {'shoB': -15 * w, 'shoF': 15 * w, 'neck': 2 * w}, shift=(0, -10), rotdeg=2 * w) if i % 2 == 0 else \
            P('LIGHTAIR', {'shoB': 35, 'shoF': -35}, shift=(0, -12), rotdeg=-2)
        out.append(F(body, under=[lines]))
    return out

# ---------------- super ----------------

def aura(frame1x, lvl):
    return fx.glow1x(frame1x, (255, 210, 60), r=4 + 3 * lvl, a=0.35 + 0.2 * lvl)

def final_smash():
    out = []
    for i, lvl in enumerate((0.4, 0.8, 1.2)):
        body = P('IDLE' if i < 2 else 'LIGHTUP', None if i < 2 else {}, hide=() if i < 2 else ('fx',), shift=shake(i, 1 + i))
        fl = fx.flames(150, 150, 96, 120, 7 + 2 * i, i / 3, seed=i)
        f = F(body, under=[fl])
        out.append(over(aura(f, lvl), f) if True else f)
    flash = P('LIGHTUP', hide=('fx',))
    flash[..., :3] = flash[..., :3] * 0.25 + np.array([255, 245, 200]) * 0.75
    f = F(flash, under=[fx.star(150, 100, 95, n=12, inner=0.6, fill=(255, 250, 220, 255), rim=(255, 210, 60, 255))])
    out.append(over(aura(f, 1.6), f))
    oms = ['om0', 'om1', 'om2', 'om3', 'om4']
    dirs = {'om0': (-1, -0.6), 'om1': (-1, 0.3), 'om2': (1, -0.3), 'om3': (1, 0.4), 'om4': (0.8, -1)}
    for j, t in enumerate((0.0, 0.5, 1.0, 1.6)):
        lt = {o: dict(t=(dirs[o][0] * 40 * t, dirs[o][1] * 40 * t), r=dirs[o][0] * 60 * t, a=max(0.0, 1 - 0.45 * max(0, t - 0.6))) for o in oms}
        s = 0.86 + 0.07 * min(j, 2)
        body = P('SUPREME', {'_lt': lt}, squash=(s, s), pivot=(150, 182))
        tw = fx.twinkles([(150 + 95 * math.cos(a + j * 0.5), 100 + 62 * math.sin(a + j * 0.5), 4) for a in np.linspace(0, 2 * math.pi, 7)[:-1]])
        f = F(body, top=[tw])
        out.append(over(aura(f, 0.6 + 0.2 * (j % 2)), f))
    return out

# ---------------- per il gioco ----------------

def hit():
    return [F(P('HIT', rotdeg=-7, shift=(-5, 0)), top=[fx.star(178, 110, 14, rot=5)]),
            F(P('HIT', rotdeg=-12, shift=(-9, 0))), F(P('HIT', rotdeg=-5, shift=(-3, 0)))]

def shield():
    return [F(P('SHIELD', {'_lt': {'fx': dict(a=a, s=s, c=(180, 105))}})) for a, s in ((1.0, 1.0), (0.8, 1.03), (0.9, 0.98))]

def taunt():
    up = lambda **k: P('LIGHTUP', hide=('fx',), **k)
    return [F(P('IDLE')), F(P('LAND', squash=(1.03, 0.94))), F(up(squash=(0.95, 1.07))),
            F(up(), top=[fx.twinkles([(200, 28, 5), (214, 44, 3.5), (186, 22, 3)], color=(255, 120, 200))]), F(up())]

SECTIONS = [
    ('Idle', idle), ('Walk', walk), ('Run', run), ('Dash', dash), ('Jump', jump), ('Fall', fall),
    ('Crouch', crouch), ('Grab', grab), ('Pummel', pummel), ('Throw (forward)', throw_f), ('Throw (back)', throw_b),
    ('Up Tilt', up_tilt), ('Side Tilt', side_tilt), ('Down Tilt', down_tilt), ('Up Smash', up_smash), ('Side Smash', side_smash), ('Down Smash', down_smash),
    ('Neutral Air', nair), ('Forward Air', fair), ('Back Air', bair), ('Up Air', uair), ('Down Air', dair),
    ('Landing', landing), ('Aerial Fall', aerial_fall), ('Final Smash', final_smash),
    ('Hit', hit), ('Shield', shield), ('Taunt', taunt),
]
