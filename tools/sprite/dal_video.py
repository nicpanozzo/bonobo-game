#!/usr/bin/env python3
# Uso: python3 tools/sprite/dal_video.py <codice> <video.mp4> <cartella di lavoro> [--skin <nome>] [--scrivi]
# Esempio: python3 tools/sprite/dal_video.py BR-01 BR-01_fermo.mp4 /tmp/br01
#
# Lo script di taglio unico per le clip di Google Flow (#539, passo 2; il piano è docs/clip-flow/README.md).
# Una clip combinata (fino a 3 mosse separate da pause nella posa di partenza) diventa una striscia PNG per stato:
# 1. stati e secondi previsti dalla tabella della clip (tools/flow/prompt_flow.py);
# 2. scontorno del verde #17B03B, come bradipo_dal_video.py, con il riflesso verde tolto anche dai colori scuri;
# 3. le mosse sono i tratti fra le pause: fotogrammi la cui sagoma differisce da quella del fotogramma 0 meno di
#    SOGLIA, per almeno PAUSA_MIN fotogrammi di fila. Se le mosse trovate non sono quante previste si usano i secondi
#    della tabella, e il resoconto lo dice;
# 4. rimpicciolito alla grandezza del fermo che il personaggio ha già nel gioco, piedi su footY, contorno chiaro;
# 5. in <cartella>/out le strisce, <cartella>/foglio.png il foglio di controllo da mettere nella PR,
#    <cartella>/resoconto.json fotogrammi usati e hitFrame proposto. Con --scrivi le strisce vanno anche negli asset:
#    gli stati che il gioco conosce in public/assets/characters/<id>/, gli altri in .../<id>/in-attesa/.
# Correzioni a mano dei fotogrammi: tools/sprite/flow_tagli.json, {"BR-01": {"turn": [117, 146]}} (fotogrammi del video).
# Il video non va nella repo. Servono ffmpeg, Pillow, numpy e scipy, solo per rifarlo.
import json, os, re, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "../.."))
sys.dont_write_bytecode = True  # niente __pycache__ in tools/flow
sys.path.insert(0, os.path.join(ROOT, "tools/flow"))
from prompt_flow import BASE, CHARS, FPS, base_clips, clips_of  # noqa: E402

SOGLIA = 0.2  # differenza di sagoma dal fotogramma 0 sotto cui il personaggio è "nella posa" (prova del 3/11)
PAUSA_MIN = 6  # fotogrammi di fila nella posa per contare come pausa (un quarto di secondo)
MOSSA_MIN = 4  # un tratto più corto non è una mossa (un tremolio)
MARGINE = 12  # fotogrammi di tolleranza attorno ai secondi previsti, quando non si trovano le pause
BG = np.array([23, 176, 59], np.float32)  # il verde dello sfondo
OUTLINE = np.array([218, 225, 235], np.float32)  # il contorno chiaro dei personaggi
PEZZO_MIN = 400  # pixel del video: i pezzi staccati più piccoli sono polvere o puntini
# stati in aria: ogni fotogramma coi piedi su footY, perché l'altezza la decide la fisica
IN_ARIA = re.compile(r"^(jump|doubleJump|fall|tumble|recovery|helpless|airDodge|lightAir|heavyAir|air[A-Z].*|.*Air|martelloJump)$")


def die(msg):
    sys.exit(f"dal_video: {msg}")


def args():
    a = sys.argv[1:]
    if len(a) < 3:
        die("uso: dal_video.py <codice> <video.mp4> <cartella di lavoro> [--skin <nome>] [--scrivi]")
    code, video, work = a[:3]
    skin = a[a.index("--skin") + 1] if "--skin" in a else None
    return code.upper(), video, work, skin, "--scrivi" in a


def clip_info(code):
    """Il personaggio e la clip: dalle ondate (CHARS) o dal pacchetto base (BASE, codici XX-B1, XX-B2)."""
    pref = code.split("-")[0]
    found = [(k, clips_of) for k, c in CHARS.items() if c["code"] == pref] + [(k, base_clips) for k, c in BASE.items() if c["code"] == pref]
    if not found:
        die(f"nessun personaggio col codice {pref} in tools/flow/prompt_flow.py")
    for cid, of in found:
        clip = next((c for c in of(cid) if c[0] == code), None)
        if clip:
            return cid, clip
    die(f"nessuna clip {code} per {found[0][0]}")


def sprite_spec(cid, skin):
    """Misure del fotogramma del gioco (da godot/data/game.json, generato da characters.ts)."""
    game = json.load(open(os.path.join(ROOT, "godot/data/game.json")))
    ch = game["characters"][cid]
    spec = ch["skins"][skin]["sprite"] if skin else ch["sprite"]
    return spec


def known_states():
    src = open(os.path.join(ROOT, "src/shared/characters.ts"), encoding="utf-8").read()
    names = set()
    for arr in ("ANIMATION_NAMES", "OPTIONAL_ANIMATION_NAMES"):
        m = re.search(arr + r"\s*=\s*\[(.*?)\]", src, re.S)
        if m:
            names |= set(re.findall(r'"([A-Za-z]+)"', m.group(1)))
    return names


def reader(video):
    """I fotogrammi del video uno alla volta, RGB float32."""
    probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height", "-of", "csv=p=0", video], capture_output=True, text=True, check=True)
    w, h = map(int, probe.stdout.strip().split(","))
    p = subprocess.Popen(["ffmpeg", "-v", "error", "-i", video, "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
    n = w * h * 3
    while True:
        buf = p.stdout.read(n)
        if len(buf) < n:
            break
        yield np.frombuffer(buf, np.uint8).reshape(h, w, 3).astype(np.float32)
    p.wait()


def cut(p):
    """RGBA del personaggio e maschera del corpo, dal verde pieno."""
    r, g, b = p[..., 0], p[..., 1], p[..., 2]
    d = g - np.maximum(r, b)  # quanto è verde
    a = np.clip((48 - d) / 30, 0, 1)
    a[a < 0.08] = 0
    lab, n = ndi.label(a > 0.3)
    if n:
        sizes = ndi.sum(np.ones_like(a), lab, range(1, n + 1))
        big = int(np.argmax(sizes)) + 1
        drop = [i + 1 for i, s in enumerate(sizes) if s < PEZZO_MIN and i + 1 != big]
        # la polvere: pezzi staccati grigi (poco saturi) all'altezza dei piedi, anche se grandi (frenata, prova del 3/11)
        foot = np.nonzero(lab == big)[0].max()
        sat = (p.max(-1) - p.min(-1)) / np.maximum(p.max(-1), 1)
        for i, s in enumerate(sizes):
            k = i + 1
            if k == big or k in drop:
                continue
            ys = np.nonzero(lab == k)[0]
            if ys.max() > foot - 40 and float(sat[lab == k].mean()) < 0.18:
                drop.append(k)
        a[np.isin(lab, drop)] = 0
    aa = np.maximum(a, 1e-3)[..., None]
    c = np.where(a[..., None] > 0.97, p, (p - (1 - aa) * BG) / aa)  # toglie il verde mescolato ai bordi
    c = np.clip(c, 0, 255)
    lum = c.mean(-1)
    # il riflesso verde: sui colori scuri (mani quasi nere, prova del 3/11) quasi niente verde in più
    room = np.where(lum < 70, 2, 8)
    c[..., 1] = np.minimum(c[..., 1], np.maximum(c[..., 0], c[..., 2]) + room)
    return np.dstack([c, a * 255]), a > 0.5


def small(mask):
    return mask[::2, ::2]


def find_moves(masks):
    m0 = masks[0]
    base = max(1, int(m0.sum()))
    diff = np.array([float((m ^ m0).sum()) / base for m in masks])
    rest = diff < SOGLIA
    runs, i = [], 0
    while i < len(rest):
        j = i
        while j < len(rest) and rest[j] == rest[i]:
            j += 1
        runs.append((bool(rest[i]), i, j - 1))
        i = j
    # le pause corte non contano: si fondono con le mosse vicine
    merged = []
    for is_rest, a, b in runs:
        if is_rest and (b - a + 1) < PAUSA_MIN and 0 < a and b < len(rest) - 1:
            is_rest = False
        if merged and merged[-1][0] == is_rest:
            merged[-1] = (is_rest, merged[-1][1], b)
        else:
            merged.append((is_rest, a, b))
    moves = [(a, b) for r, a, b in merged if not r and b - a + 1 >= MOSSA_MIN]
    return moves, diff


def expected_moves(table):
    """Le mosse previste: voci della tabella con finestre che si toccano = una mossa con più stati."""
    moves = []
    for state, a, b, name in table:
        if moves and abs(moves[-1]["b"] - a) < 1e-6:
            moves[-1]["parts"].append((state, a, b))
            moves[-1]["b"] = b
        else:
            moves.append({"a": a, "b": b, "parts": [(state, a, b)]})
    return moves


def assign(found, expected, n_frames):
    """Fotogrammi [da, a] per ogni stato, più gli avvisi."""
    notes, out = [], {}
    if len(found) == len(expected):
        spans = found
    else:
        # una mossa trovata vale se tocca la finestra prevista di una mossa sola; le altre dai secondi previsti
        win = [(round(e["a"] * FPS), round(e["b"] * FPS)) for e in expected]
        spans = []
        for k, (a, b) in enumerate(win):
            hits = [f for f in found if f[0] <= b + MARGINE and f[1] >= a - MARGINE]
            only = [f for f in hits if sum(1 for (x, y) in win if f[0] <= y + MARGINE and f[1] >= x - MARGINE) == 1]
            if len(only) == 1:
                spans.append(only[0])
            else:
                spans.append((max(0, a - MARGINE // 2), min(n_frames - 1, b + MARGINE // 2)))
                notes.append(f"mossa {k + 1}: pausa non trovata, uso i secondi previsti (fotogrammi {spans[-1][0]}-{spans[-1][1]}), da controllare")
    for e, (fa, fb) in zip(expected, spans):
        parts = []
        for state, a, b in e["parts"]:
            for s in state.split("+"):
                parts.append((s, (b - a) / len(state.split("+"))))
        tot = sum(w for _, w in parts)
        x = fa
        for k, (s, w) in enumerate(parts):
            y = fb if k == len(parts) - 1 else x + round((fb - fa + 1) * w / tot) - 1
            out[s] = [x, y]
            x = y + 1
        if len(parts) > 1 and any("+" in st for st, *_ in e["parts"]):
            notes.append(f"{'+'.join(s for s, _ in parts)}: diviso in parti uguali, da controllare (o correggere in flow_tagli.json)")
    return out, notes


def resize(rgba, size):
    im = Image.fromarray(rgba.round().clip(0, 255).astype(np.uint8), "RGBA").convert("RGBa")
    return np.asarray(im.resize(size, Image.LANCZOS).convert("RGBA"), np.float32)


def place(rgba, body, mode, geo):
    FW, FH, FOOT, SCALE, CENTER, GROUND = geo
    h, w = body.shape
    size = (max(1, round(w * SCALE)), max(1, round(h * SCALE)))
    sm = resize(rgba, size)
    sb = np.asarray(Image.fromarray((body * 255).astype(np.uint8)).resize(size, Image.LANCZOS), np.float32) / 255
    dx = round(FW / 2 - CENTER * SCALE)
    if mode == "feet":
        rows = np.nonzero((sb > 0.5).sum(1) >= 2)[0]
        dy = round(FOOT - (rows.max() + 1)) if len(rows) else round(FOOT - GROUND * SCALE)
    else:
        dy = round(FOOT - GROUND * SCALE)
    frame = np.zeros((FH, FW, 4), np.float32)
    fb = np.zeros((FH, FW), np.float32)
    ys, xs = slice(max(0, dy), min(FH, dy + size[1])), slice(max(0, dx), min(FW, dx + size[0]))
    if ys.start < ys.stop and xs.start < xs.stop:
        frame[ys, xs] = sm[ys.start - dy:ys.stop - dy, xs.start - dx:xs.stop - dx]
        fb[ys, xs] = sb[ys.start - dy:ys.stop - dy, xs.start - dx:xs.stop - dx]
    ring = ndi.gaussian_filter(ndi.binary_dilation(fb > 0.5, iterations=2).astype(np.float32), 0.6)
    ring[ndi.binary_closing(fb > 0.5, iterations=3, border_value=0) & (fb <= 0.5)] = 0  # le fessure restano aperte (#506)
    a = frame[..., 3:] / 255
    rgb = frame[..., :3] * a + OUTLINE * ring[..., None] * (1 - a)
    alpha = a[..., 0] + ring * (1 - a[..., 0])
    rgb = rgb / np.maximum(alpha, 1e-3)[..., None]
    out = np.dstack([rgb, alpha * 255]).round().clip(0, 255).astype(np.uint8)
    out[0, 0] = 0  # l'angolo in alto a sinistra trasparente (lo controlla assets.test.ts)
    touches = bool(fb[0].any() or fb[-1].any() or fb[:, 0].any() or fb[:, -1].any())
    return out, touches


def save(rgba, path):
    im = Image.fromarray(rgba, "RGBA").quantize(256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
    im.save(path, optimize=True)


def game_height(spec):
    """Altezza del corpo nel fermo che il personaggio ha già nel gioco, senza il contorno chiaro."""
    path = os.path.join(ROOT, "public", spec["dir"], "idle.png")
    im = np.asarray(Image.open(path).convert("RGBA"))[:, : spec["frameWidth"], 3]
    rows = np.nonzero((im > 128).sum(1) >= 2)[0]
    return (rows.max() - rows.min() + 1) - 4


def main():
    code, video, work, skin, scrivi = args()
    cid, clip = clip_info(code)
    _, slug, title, mode_flow, _, _, _, table = clip
    spec = sprite_spec(cid, skin)
    os.makedirs(os.path.join(work, "out"), exist_ok=True)
    over = json.load(open(os.path.join(HERE, "flow_tagli.json"))).get(code, {}) if os.path.exists(os.path.join(HERE, "flow_tagli.json")) else {}

    # primo giro: le sagome, per trovare le mosse
    masks = [small(cut(f)[1]) for f in reader(video)]
    if not masks:
        die(f"non riesco a leggere {video}")
    found, diff = find_moves(masks)
    expected = expected_moves(table)
    plan, notes = assign(found, expected, len(masks))
    for s, ab in over.items():
        plan[s] = ab
        notes.append(f"{s}: fotogrammi da flow_tagli.json")

    # misure: il fermo del video (fotogramma 0) alto come il fermo del gioco
    m0 = masks[0]
    ys, xs = np.nonzero(m0)
    v_h = (ys.max() - ys.min() + 1) * 2
    scale = game_height(spec) / v_h
    geo = (spec["frameWidth"], spec["frameHeight"], spec["footY"], scale, xs.mean() * 2, (ys.max() + 1) * 2)

    # secondo giro: solo i fotogrammi che servono
    need = {i for a, b in plan.values() for i in range(max(0, a - 1), min(len(masks), b + 2))}
    full = {}
    for i, f in enumerate(reader(video)):
        if i in need:
            full[i] = cut(f)
    known, report, rows = known_states(), {"codice": code, "clip": title, "personaggio": cid, "scala": round(scale, 4), "avvisi": notes, "stati": {}}, []
    c0 = np.array([xs.mean() * 2, ys.mean() * 2])
    for s, (a, b) in plan.items():
        idx = list(range(max(0, a - 1), min(len(masks), b + 2)))
        mode = "feet" if IN_ARIA.match(s) else "world"
        strip, edge = [], False
        reach = []
        for i in idx:
            img, t = place(*full[i], mode, geo)
            strip.append(img)
            edge |= t
            yy, xx = np.nonzero(full[i][1])
            reach.append(float(np.hypot(xx - c0[0], yy - c0[1]).max()) if len(xx) else 0)
        save(np.concatenate(strip, 1), os.path.join(work, "out", f"{s}.png"))
        hit = int(np.argmax(reach))
        dest = "nel gioco" if s in known else "in-attesa"
        report["stati"][s] = {"fotogrammi_video": [idx[0], idx[-1]], "fotogrammi": len(strip), "fps": FPS, "modo": mode, "hitFrame_proposto": hit, "va_in": dest}
        if edge:
            notes.append(f"{s}: il disegno tocca il bordo del fotogramma, va allargato")
        rows.append((s, strip))
        if scrivi:
            base = os.path.join(ROOT, "public", spec["dir"])
            out_dir = base if s in known else os.path.join(base, "in-attesa")
            os.makedirs(out_dir, exist_ok=True)
            save(np.concatenate(strip, 1), os.path.join(out_dir, f"{s}.png"))
            if s == "throwForward" and "throw" in known:
                save(np.concatenate(strip, 1), os.path.join(base, "throw.png"))

    # foglio di controllo: 8 fotogrammi per stato su grigio
    fw, fh = spec["frameWidth"], spec["frameHeight"]
    sheet = Image.new("RGBA", (8 * fw + 140, len(rows) * fh), (70, 70, 80, 255))
    draw = ImageDraw.Draw(sheet)
    for r, (s, strip) in enumerate(rows):
        draw.text((6, r * fh + 6), s, fill=(255, 255, 255, 255))
        for k, j in enumerate(np.linspace(0, len(strip) - 1, min(8, len(strip))).round().astype(int)):
            sheet.alpha_composite(Image.fromarray(strip[j], "RGBA"), (140 + k * fw, r * fh))
    sheet.convert("RGB").save(os.path.join(work, "foglio.png"))
    report["differenza_dalla_posa"] = [round(float(x), 3) for x in diff]
    json.dump(report, open(os.path.join(work, "resoconto.json"), "w"), indent=1, ensure_ascii=False)
    print(f"{code} {title}: {len(plan)} stati, scala {scale:.3f}")
    for s, v in report["stati"].items():
        print(f"  {s:14} fotogrammi {v['fotogrammi_video'][0]}-{v['fotogrammi_video'][1]} ({v['fotogrammi']}), {v['modo']}, hitFrame {v['hitFrame_proposto']}, {v['va_in']}")
    for n in notes:
        print("  ! " + n)


if __name__ == "__main__":
    main()
