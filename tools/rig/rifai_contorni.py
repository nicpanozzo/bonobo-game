# Rifà i contorni a inchiostro (<pezzo>_ink.png) dai pezzi disegnati (#195): la sagoma del pezzo,
# riempita di inchiostro e allargata di LARGO pixel. Da lanciare dopo aver messo in pezzi/ i disegni nuovi.
# Uso: python3 tools/rig/rifai_contorni.py public/assets/characters/bonobot/rig [pezzo ...]   (serve Pillow)
# Senza nomi rifà tutti i contorni; un pezzo senza contorno in rig.json resta senza.
import json
import os
import sys

from PIL import Image, ImageFilter

INK = (31, 23, 20)  # #1f1714, come in docs/stile-grafico.md
LARGO = 3  # pixel nel PNG a 2x, cioè circa 3 px di inchiostro come dice la guida

D = sys.argv[1] if len(sys.argv) > 1 else "public/assets/characters/bonobot/rig"
only = set(sys.argv[2:])
rig = json.load(open(os.path.join(D, "rig.json"), encoding="utf-8"))
for p in rig["pieces"]:
    if "ink" not in p or (only and p["name"] not in only):
        continue
    im = Image.open(os.path.join(D, p["image"])).convert("RGBA")
    alpha = im.getchannel("A").point(lambda v: 255 if v > 24 else 0)
    alpha = alpha.filter(ImageFilter.MaxFilter(LARGO * 2 + 1))
    ink = Image.new("RGBA", im.size, INK + (0,))
    ink.putalpha(alpha.filter(ImageFilter.GaussianBlur(0.6)))  # bordo appena morbido
    ink.save(os.path.join(D, p["ink"]))
    print("rifatto", p["ink"])
