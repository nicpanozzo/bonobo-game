# Il modello per chi disegna un lottatore (E7 passo 5): public/assets/characters/_modello/.
# Uso: python3 tools/sprite/modello_sprite.py   (dopo npm run export:godot; serve Pillow)
# Legge le misure da godot/data/game.json (cioè da constants.ts), così se cambiano hitbox o colpi basta rilanciarlo.
# Scrive, a 2x come gli sprite (scale: 0.5):
#   modello.png  un fotogramma: sagoma della hitbox, piedi, direzione, zone del leggero e del pesante
#   colpi.png    una striscia con le 8 varianti d'attacco, ognuna con la sua zona e i ms in cui è accesa
import json
import os

from PIL import Image, ImageDraw, ImageFont

OUT = "public/assets/characters/_modello"
game = json.load(open("godot/data/game.json", encoding="utf-8"))
FW_WORLD, FH_WORLD = 200, 160  # fotogramma di mondo che contiene tutte le zone dei colpi
S = 2  # si disegna a 2x
FW, FH = FW_WORLD * S, FH_WORLD * S
HB_W, HB_H = game["fighter"]["width"], game["fighter"]["height"]
ATT = game["attacks"]

INK = (40, 34, 40, 255)
BODY = (120, 130, 150, 90)
BODY_LINE = (90, 100, 125, 230)
GRID = (120, 130, 150, 40)
FEET = (40, 150, 90, 255)
FACE = (60, 110, 200, 255)
HIT = {"light": (240, 150, 40), "heavy": (220, 60, 50)}  # arancio come nella tavola della guida, rosso per il pesante

try:
    font = ImageFont.truetype("DejaVuSans.ttf", 13)
    bold = ImageFont.truetype("DejaVuSans-Bold.ttf", 14)
except OSError:
    font = bold = ImageFont.load_default()


def box(name):
    """Zona del colpo in pixel del fotogramma (a 2x), come attackBox in physics/attacks.ts, guardando a destra."""
    a = ATT[name]
    x0 = a["boxX"] if a.get("boxX") is not None else HB_W / 2
    y0 = a["boxY"] if a.get("boxY") is not None else -HB_H * 0.7
    cx, fy = FW / 2, FH
    return (cx + x0 * S, fy + y0 * S, cx + (x0 + a["range"]) * S, fy + (y0 + a["height"]) * S)


def dashed(d, x0, y0, x1, y1, color, step=8):
    for (ax, ay, bx, by) in [(x0, y0, x1, y0), (x1, y0, x1, y1), (x1, y1, x0, y1), (x0, y1, x0, y0)]:
        n = max(1, int(max(abs(bx - ax), abs(by - ay)) / step))
        for i in range(0, n, 2):
            t0, t1 = i / n, min(1, (i + 1) / n)
            d.line([(ax + (bx - ax) * t0, ay + (by - ay) * t0), (ax + (bx - ax) * t1, ay + (by - ay) * t1)], fill=color, width=1)


def frame(d, ox, title=None):
    """Il fondo comune: bordo, griglia ogni 16 px di mondo, hitbox, piedi, direzione."""
    for x in range(0, FW, 16 * S):
        d.line([(ox + x, 0), (ox + x, FH)], fill=GRID)
    for y in range(FH, 0, -16 * S):
        d.line([(ox, y), (ox + FW, y)], fill=GRID)
    dashed(d, ox, 0, ox + FW - 1, FH - 1, (120, 120, 120, 200))
    cx = ox + FW / 2
    d.rectangle([cx - HB_W, FH - HB_H * S, cx + HB_W - 1, FH - 1], fill=BODY, outline=BODY_LINE, width=2)
    d.text((cx, FH - HB_H * S + 8), f"hitbox\n{HB_W}×{HB_H}", fill=BODY_LINE, font=font, anchor="ma", align="center")
    # i piedi: il punto del lottatore, al centro del bordo basso
    d.line([(cx - 14, FH - 1), (cx + 14, FH - 1)], fill=FEET, width=3)
    d.line([(cx, FH - 14), (cx, FH - 1)], fill=FEET, width=3)
    d.text((cx + 16, FH - 18), "piedi", fill=FEET, font=font)
    # la direzione
    d.line([(cx - 30, 14), (cx + 26, 14)], fill=FACE, width=3)
    d.polygon([(cx + 34, 14), (cx + 22, 7), (cx + 22, 21)], fill=FACE)
    d.text((cx + 40, 6), "guarda a destra", fill=FACE, font=font)
    if title:
        d.text((ox + 8, 6), title, fill=INK, font=bold)


def hit(d, ox, name, color, label, below=False):
    x0, y0, x1, y1 = box(name)
    d.rectangle([ox + x0, y0, ox + x1 - 1, y1 - 1], fill=color + (60,), outline=color + (255,), width=2)
    if below:  # la scritta nell'angolo in basso a destra, se in alto la copre un'altra zona
        d.text((ox + x1 - 5, y1 - 4), label, fill=color + (255,), font=font, anchor="rd")
    else:
        d.text((ox + x0 + 4, y0 + 3), label, fill=color + (255,), font=font)


os.makedirs(OUT, exist_ok=True)

# modello.png: un fotogramma
img = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
frame(d, 0)
hit(d, 0, "heavy", HIT["heavy"], "heavy", below=True)
hit(d, 0, "light", HIT["light"], "light")
img.save(os.path.join(OUT, "modello.png"), optimize=True)

# colpi.png: le varianti, una per fotogramma
VARIANTS = ["light", "lightUp", "lightDown", "lightAir", "heavy", "heavyUp", "heavyDown", "heavyAir"]
strip = Image.new("RGBA", (FW * len(VARIANTS), FH), (0, 0, 0, 0))
d = ImageDraw.Draw(strip)
for i, name in enumerate(VARIANTS):
    a = ATT[name]
    ox = i * FW
    frame(d, ox, name)
    color = HIT["heavy" if name.startswith("heavy") else "light"]
    hit(d, ox, name, color, f"{a['startupMs']}–{a['startupMs'] + a['activeMs']} ms")
strip.save(os.path.join(OUT, "colpi.png"), optimize=True)
print(json.dumps({"frame": [FW, FH], "files": ["modello.png", "colpi.png"]}))
