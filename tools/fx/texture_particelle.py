"""Texture delle particelle degli effetti (#470): sbuffi e fiamme a tre toni, bordo irregolare e sfumato.

Lo stile è "Naturale morbido", scelto da Riccardo sul banco di prova: niente contorno d'inchiostro. Ogni texture ha
un'ombra, un tono base spostato in alto a sinistra (la luce viene da davanti in alto, come in docs/stile-grafico.md)
e una luce più piccola, su una sagoma deformata da quattro onde, con qualche grumo sul bordo. Una maschera radiale
toglie opacità verso fuori, così le particelle si fondono tra loro.

Esce in godot/assets/fx/: <tono>_<forma>_<variante>.png e glow.png (alone bianco per la fusione additiva).
I nomi dei toni e delle forme sono quelli di godot/scripts/particle_fx.gd.

Uso: python3 tools/fx/texture_particelle.py
"""

import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SIZE = 64          # pixel del file; nel gioco la texture si scala alla grandezza della particella
SS = 4             # si disegna a 4x e si riduce: bordi lisci
VARIANTS = 4

# tono -> (luce, base, ombra)
TONES = {
    "dust": ("#fbf5e8", "#e8dabf", "#c4ad8a"),
    "smoke": ("#f7f5fa", "#dedae6", "#ada5ba"),
    "dark": ("#958e9f", "#655f70", "#423d4b"),
    "air": ("#ffffff", "#eef4fb", "#cfdcec"),
    "core": ("#ffffff", "#fff8d6", "#ffe89a"),
    "yellow": ("#fff4b8", "#ffd447", "#f2a52a"),
    "orange": ("#ffd07a", "#ff972c", "#de5e1e"),
    "red": ("#ff9a68", "#e5522a", "#b02f16"),
}
FLAME_TONES = ("core", "yellow", "orange", "red")


def blob(draw, cx, cy, r, color, phases, flame):
    """Una sagoma tonda deformata da quattro onde; la fiamma è allungata verso l'alto."""
    pts = []
    for i in range(96):
        a = i / 96 * math.tau
        rr = r * (1 + 0.13 * math.sin(3 * a + phases[0]) + 0.08 * math.sin(5 * a + phases[1])
                  + 0.05 * math.sin(9 * a + phases[2]) + 0.03 * math.sin(14 * a + phases[3]))
        if flame:
            rr *= 1 + 0.75 * max(0.0, -math.sin(a)) ** 2
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr * (0.9 if flame else 1)))
    draw.polygon(pts, fill=color)


def texture(tone, shape, variant):
    n = SIZE * SS
    rnd = random.Random(variant * 97 + len(tone) * 13 + (7 if shape == "flame" else 5))
    phases = [rnd.random() * 6 for _ in range(4)]
    flame = shape == "flame"
    cx, cy = n / 2, n * (0.62 if flame else 0.5)
    r = n * (0.26 if flame else 0.36)
    light, base, shade = TONES[tone]
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    blob(d, cx, cy, r, shade, phases, flame)
    blob(d, cx - r * 0.1, cy - r * 0.14, r * 0.8, base, phases, flame)
    blob(d, cx - r * 0.26, cy - r * 0.32, r * 0.42, light, phases, flame)
    if not flame:  # piccoli grumi sul bordo: niente sagome perfettamente tonde
        for _ in range(5):
            a = rnd.random() * math.tau
            rr = r * (0.14 + rnd.random() * 0.14)
            x, y = cx + math.cos(a) * r * 0.85, cy + math.sin(a) * r * 0.85
            d.ellipse((x - rr, y - rr, x + rr, y + rr), fill=base if rnd.random() > 0.5 else shade)
    # bordo morbido: maschera radiale (piena dentro, sfuma a zero verso fuori), moltiplicata sull'alfa
    mask = Image.new("L", (n, n), 0)
    md = ImageDraw.Draw(mask)
    inner, outer = r * 0.35, r * (1.9 if flame else 1.25)
    mcx, mcy = cx, cy - (r * 0.2 if flame else 0)
    steps = 48
    for i in range(steps, -1, -1):
        rr = inner + (outer - inner) * i / steps
        f = i / steps
        a = 255 if f < 0.6 else int(255 * (0.85 * (1 - (f - 0.6) / 0.4)))
        md.ellipse((mcx - rr, mcy - rr, mcx + rr, mcy + rr), fill=a)
    mask = mask.filter(ImageFilter.GaussianBlur(SS * 1.5))
    img.putalpha(ImageChops.multiply(img.getchannel("A"), mask))
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def glow():
    """Alone bianco radiale: con la fusione additiva fa il bagliore di scintille, fuoco ed esplosioni."""
    n = SIZE * SS
    img = Image.new("RGBA", (n, n), (255, 255, 255, 0))
    d = ImageDraw.Draw(img)
    for i in range(64, -1, -1):
        rr = n / 2 * i / 64
        d.ellipse((n / 2 - rr, n / 2 - rr, n / 2 + rr, n / 2 + rr), fill=(255, 255, 255, int(255 * (1 - i / 64) ** 1.6)))
    return img.filter(ImageFilter.GaussianBlur(SS * 2)).resize((SIZE, SIZE), Image.LANCZOS)


def main():
    out = os.path.join(os.path.dirname(__file__), "..", "..", "godot", "assets", "fx")
    os.makedirs(out, exist_ok=True)
    for tone in TONES:
        for v in range(VARIANTS):
            texture(tone, "puff", v).save(os.path.join(out, f"{tone}_puff_{v}.png"), optimize=True)
    for tone in FLAME_TONES:
        for v in range(VARIANTS):
            texture(tone, "flame", v).save(os.path.join(out, f"{tone}_flame_{v}.png"), optimize=True)
    glow().save(os.path.join(out, "glow.png"), optimize=True)
    print("texture in", os.path.normpath(out))


if __name__ == "__main__":
    main()
