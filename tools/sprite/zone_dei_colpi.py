# Le zone dei colpi dove arriva il disegno (#243 passo 6): per ogni personaggio guarda il fotogramma d'impatto di
# ogni colpo normale e sposta la zona sulla punta del colpo (mano, piede, arma), dentro ATTACK_TWEAK.
# Uso: python3 tools/sprite/zone_dei_colpi.py [id ...]   (dopo npm run export:godot; serve Pillow)
# Stampa le zone (range, height, boxX, boxY) dei colpi di `attacks:` da copiare nel personaggio in src/shared/characters.ts. Danni e tempi non li tocca.
# Stampa anche `hurtbox:`, il corpo che si può colpire, misurato sulla sagoma del fermo.
# Lo stesso conto lo rifà test_sprite_checks.gd: se un disegno cambia e la punta esce dalla zona, il test lo dice.
import json
import math
import sys

from PIL import Image, ImageChops

game = json.load(open("godot/data/game.json", encoding="utf-8"))
FW, FH = game["fighter"]["width"], game["fighter"]["height"]
ATT = game["attacks"]
MAX = 0.3  # ATTACK_TWEAK.maxChange
MARGIN = 6  # pixel di mondo oltre la punta: il colpo prende chi la tocca appena
TIP = 8  # pixel di mondo dalla punta che contano come "la parte che colpisce"
MIN_RUN = 3  # pixel del PNG opachi in una colonna o riga perché non sia un capello o una sbavatura
UP = ("lightUp", "heavyUp")
STRIKES = ["light", "heavy", "lightUp", "lightDown", "lightAir", "heavyUp", "heavyDown", "heavyAir", "dashAttack"]


def clamp(v, base):  # intero, sempre dentro ATTACK_TWEAK
    return max(math.ceil(base * (1 - MAX)), min(math.floor(base * (1 + MAX)), round(v)))


def mask(sprite, state):
    a = sprite["animations"][state]
    src = sprite["animations"][a.get("src", state)]
    hit = int(src.get("hitFrame", int(src["frames"]) - 1))
    img = Image.open("godot/data/%s/%s.png" % (sprite["dir"], a.get("src", state))).convert("RGBA")
    w, h = sprite["frameWidth"], sprite["frameHeight"]
    # con activeEnd (#506) la zona copre tutti i fotogrammi mostrati mentre il colpo prende, non solo l'impatto
    alpha_img = img.crop((hit * w, 0, hit * w + w, h)).getchannel("A")
    for f in range(hit + 1, int(src.get("activeEnd", hit)) + 1):
        alpha_img = ImageChops.lighter(alpha_img, img.crop((f * w, 0, f * w + w, h)).getchannel("A"))
    alpha = alpha_img.load()
    s = float(sprite.get("scale", 1.0))
    foot = float(sprite.get("footY", h))
    # punti opachi in pixel di mondo, rispetto ai piedi, guardando a destra
    return [((x - w / 2) * s, (y - foot) * s, x, y) for y in range(h) for x in range(w) if alpha[x, y] > 128]


def median(v):
    return sorted(v)[len(v) // 2]


def fit(points, kind):
    base = ATT[kind]
    if kind in UP:
        rows = {}
        for p in points:
            rows[p[3]] = rows.get(p[3], 0) + 1
        top = min(p[1] for p in points if rows[p[3]] >= MIN_RUN)
        # la zona si centra sulla punta (la mano o l'arma più in alto), non su tutta la sagoma
        cx = median([p[0] for p in points if p[1] <= top + TIP])
        rng, h = base["range"], base["height"]
        return {"range": rng, "height": h, "boxX": round(cx - rng / 2), "boxY": round(top - MARGIN)}
    # si cerca la punta all'altezza della zona di ATTACKS: così la testa sporta in avanti non conta come pugno
    y0 = base.get("boxY", -FH * 0.7)
    band = [p for p in points if y0 <= p[1] <= y0 + base["height"]] or points
    points = band
    cols = {}
    for p in points:
        cols[p[2]] = cols.get(p[2], 0) + 1
    tip = max(p[0] for p in points if cols[p[2]] >= MIN_RUN)
    cy = median([p[1] for p in points if p[0] >= tip - TIP])
    end = tip + MARGIN
    rng = clamp(end, base["range"])  # la zona parte al più dal centro del corpo
    h = base["height"]
    return {"range": rng, "height": h, "boxX": round(end - rng), "boxY": round(min(-h, cy - h / 2))}


def hurtbox(sprite):
    w, h = sprite["frameWidth"], sprite["frameHeight"]
    a = sprite["animations"]["idle"]
    img = Image.open("godot/data/%s/%s.png" % (sprite["dir"], a.get("src", "idle"))).convert("RGBA")
    alpha = img.crop((0, 0, w, h)).getchannel("A").load()
    s = float(sprite.get("scale", 1.0))
    cols = [sum(alpha[x, y] > 128 for y in range(h)) for x in range(w)]
    rows = [y for y in range(h) if sum(alpha[x, y] > 128 for x in range(w)) >= MIN_RUN]
    # le colonne con poco disegno (coda, capelli, fumo) non fanno corpo
    wide = [x for x in range(w) if cols[x] >= 0.25 * max(cols)]
    return round((max(wide) - min(wide)) * s), round((float(sprite.get("footY", h)) - min(rows)) * s)


def main(only):
    for cid, c in game["characters"].items():
        sprite = c.get("sprite")
        if not isinstance(sprite, dict) or "dir" not in sprite or (only and cid not in only):
            continue
        print("  // %s" % cid)
        print("    hurtbox: { width: %d, height: %d }," % hurtbox(sprite))
        print("    attacks: {")
        for kind in STRIKES:
            if kind not in sprite["animations"]:
                continue
            z = fit(mask(sprite, kind), kind)
            print("      %s: { range: %d, height: %d, boxX: %d, boxY: %d }," % (kind, z["range"], z["height"], z["boxX"], z["boxY"]))
        print("    },")


if __name__ == "__main__":
    main(sys.argv[1:])
