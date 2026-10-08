# Tavola modello per ridisegnare i pezzi di un lottatore in Krita (#195): ogni pezzo con la sua sagoma
# provvisoria in trasparenza, il perno (dove si attacca all'osso), la direzione dell'osso e la misura.
# Uso: python3 tools/rig/modello_pezzi.py public/assets/characters/bonobot/rig   (serve Pillow)
# Scrive <cartella>/modello-pezzi.png (tutti i pezzi in una tavola) e <cartella>/modello/<pezzo>.png, uno per
# pezzo, ingranditi x4 rispetto ai PNG dei pezzi (che sono già a 2x): in Krita si apre il modello del pezzo,
# si disegna su un livello nuovo, si nasconde il modello e si esporta al 25% in pezzi/<pezzo>.png.
import json
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

D = sys.argv[1] if len(sys.argv) > 1 else "public/assets/characters/bonobot/rig"
Z = 2  # ingrandimento della tavola
CELL_W, CELL_H, COLS = 230, 250, 6
rig = json.load(open(os.path.join(D, "rig.json"), encoding="utf-8"))
bones = {b["name"]: b for b in rig["bones"]}
# solo il lato vicino: quelli lontani (_L) sono gli stessi pezzi, un tono più scuri
pieces = [p for p in rig["pieces"] if not p["name"].endswith("_L")]
order = ["head", "jaw", "brow", "lid", "tuft_back", "tuft_front", "joint", "neck", "shoulders", "chest", "belly", "pelvis",
         "upper_arm_R", "forearm_R", "hand_R", "fingers_R", "thumb_R", "thigh_R", "shin_R", "foot_R", "toes_R"]
pieces.sort(key=lambda p: order.index(p["name"]) if p["name"] in order else 99)
rows = math.ceil(len(pieces) / COLS)
sheet = Image.new("RGBA", (COLS * CELL_W, rows * CELL_H + 60), (246, 243, 236, 255))
draw = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype("DejaVuSans.ttf", 15)
    small = ImageFont.truetype("DejaVuSans.ttf", 12)
except OSError:
    font = small = ImageFont.load_default()
draw.text((12, 14), f"{rig['character']}: pezzi da ridisegnare (tavola ingrandita x{Z}; esportare ogni pezzo al 50%, misure in px del PNG)", fill=(40, 30, 25), font=font)
draw.text((12, 36), "+ rosso = perno sull'osso (non spostarlo)   freccia blu = direzione dell'osso   riquadro = misura del PNG", fill=(90, 80, 70), font=small)

for i, p in enumerate(pieces):
    cx, cy = (i % COLS) * CELL_W, (i // COLS) * CELL_H + 60
    w, h = p["width"] * Z, p["height"] * Z
    ox, oy = cx + (CELL_W - w) // 2, cy + 34 + (CELL_H - 60 - h) // 2
    draw.rectangle([cx + 4, cy + 4, cx + CELL_W - 4, cy + CELL_H - 4], outline=(210, 200, 185))
    draw.rectangle([ox, oy, ox + w, oy + h], outline=(160, 150, 140))
    for key, alpha in (("ink", 70), ("image", 110)):
        if key in p:
            im = Image.open(os.path.join(D, p[key])).convert("RGBA").resize((w, h), Image.NEAREST)
            a = im.getchannel("A").point(lambda v: v * alpha // 255)
            im.putalpha(a)
            sheet.alpha_composite(im, (ox, oy))
    b = bones[p["bone"]]
    hx, hy = (b["head"][0] - p["x"]) * Z + ox, (b["head"][1] - p["y"]) * Z + oy
    ang = math.atan2(b["tail"][1] - b["head"][1], b["tail"][0] - b["head"][0])
    L = min(60, math.hypot(b["tail"][0] - b["head"][0], b["tail"][1] - b["head"][1]) * Z)
    tx, ty = hx + math.cos(ang) * L, hy + math.sin(ang) * L
    draw.line([hx, hy, tx, ty], fill=(40, 110, 220), width=2)
    for s in (-1, 1):
        a2 = ang + math.pi + s * 0.45
        draw.line([tx, ty, tx + math.cos(a2) * 9, ty + math.sin(a2) * 9], fill=(40, 110, 220), width=2)
    draw.line([hx - 7, hy, hx + 7, hy], fill=(220, 40, 40), width=2)
    draw.line([hx, hy - 7, hx, hy + 7], fill=(220, 40, 40), width=2)
    label = p["name"] + ("  (+ _L)" if p["name"].endswith("_R") else "")
    draw.text((cx + 10, cy + 10), label, fill=(40, 30, 25), font=font)
    draw.text((cx + 10, cy + CELL_H - 24), f"{p['width']}×{p['height']} px · perno {round(b['head'][0] - p['x'])},{round(b['head'][1] - p['y'])}", fill=(110, 100, 90), font=small)

# Un modello per pezzo, a misura x4 del PNG finale (comodo per disegnare i dettagli): sagoma provvisoria,
# perno e osso, stesso margine. In Krita si esporta al 25%
ZT = 4
os.makedirs(os.path.join(D, "modello"), exist_ok=True)
for p in rig["pieces"]:
    if p["name"].endswith("_L"):
        continue
    w, h = p["width"] * ZT, p["height"] * ZT
    tpl = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for key, alpha in (("ink", 60), ("image", 90)):
        if key in p:
            im = Image.open(os.path.join(D, p[key])).convert("RGBA").resize((w, h), Image.LANCZOS)
            im.putalpha(im.getchannel("A").point(lambda v, a=alpha: v * a // 255))
            tpl.alpha_composite(im)
    d = ImageDraw.Draw(tpl)
    b = bones[p["bone"]]
    hx, hy = (b["head"][0] - p["x"]) * ZT, (b["head"][1] - p["y"]) * ZT
    ang = math.atan2(b["tail"][1] - b["head"][1], b["tail"][0] - b["head"][0])
    L = math.hypot(b["tail"][0] - b["head"][0], b["tail"][1] - b["head"][1]) * ZT
    d.line([hx, hy, hx + math.cos(ang) * L, hy + math.sin(ang) * L], fill=(40, 110, 220, 200), width=3)
    d.line([hx - 14, hy, hx + 14, hy], fill=(220, 40, 40, 230), width=3)
    d.line([hx, hy - 14, hx, hy + 14], fill=(220, 40, 40, 230), width=3)
    d.rectangle([0, 0, w - 1, h - 1], outline=(160, 150, 140, 160))
    tpl.save(os.path.join(D, "modello", p["name"].replace("_R", "") + ".png"))

out = os.path.join(D, "modello-pezzi.png")
sheet.save(out)
print("scritto", out, sheet.size)
