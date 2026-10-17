# Uso: python3 tools/rig/rendi_tratto.py <cartella rig> <animazioni.json> <cartella di uscita> <stile> [stati,separati,da,virgola]
# Le skin a tratto (#339): le stesse animazioni dello scheletro (animazioni_lottatore.py), disegnate come Egiainuso
# invece che coi pezzi: tratto nero spesso, testa tonda grande, mani a pallino e un contorno chiaro per leggersi sui
# fondali scuri. Scrive un PNG per stato nel formato a cartella (E7) e portrait.png, come rendi_sprite.py.
# Stili: "jax" (Lampione col cappuccio e il lampione come arma, alla Jax di League of Legends).
import json, math, os, sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scheletro import Scheletro
from rendi_sprite import salva

SS = 3  # sovracampionamento: si disegna grande e si rimpicciolisce, per avere i bordi morbidi
INK = (22, 20, 22, 255)
PAPER = (244, 241, 234, 255)  # il bianco della faccia e il contorno chiaro, come Egiainuso
LIMB, BODY = 10, 13  # spessore di braccia/gambe e del busto, pixel del disegno a 2x
OUTLINE = 4  # contorno chiaro, pixel
MAX_STRIP = 8192  # larghezza massima di una striscia, pixel: il limite delle texture su molti telefoni
POLE = 150  # lunghezza del lampione sopra la mano, pixel
# La tela su cui si disegna prima di ritagliare (vedi rendi), larga abbastanza per ogni posa, e dove stanno i piedi
CANVAS, CANVAS_FEET = (900, 800), (450, 560)


class Tratto:
    def __init__(self, sk, stile):
        self.sk, self.stile = sk, stile

    def disegna(self, posa, radice, misura, piedi):
        m = self.sk.fk(posa, radice)
        W, H = misura
        img = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
        glow = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
        d, g = ImageDraw.Draw(img), ImageDraw.Draw(glow)
        P = lambda p: ((p[0] + piedi[0]) * SS, (p[1] + piedi[1]) * SS)
        head = lambda n: P(m[n][0])
        tip = lambda n: P(self.sk.punta(m, n))

        def line(pts, w):
            w = int(w * SS)
            d.line(pts, fill=INK, width=w, joint="curve")
            for x, y in (pts[0], pts[-1]):
                d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=INK)

        def dot(c, r, fill=INK):
            d.ellipse([c[0] - r * SS, c[1] - r * SS, c[0] + r * SS, c[1] + r * SS], fill=fill)

        def leg(S):
            line([head(f"thigh_{S}"), head(f"shin_{S}"), head(f"foot_{S}")], LIMB)
            line([head(f"foot_{S}"), tip(f"foot_{S}")], LIMB + 2)

        def arm(S):
            line([head(f"upper_arm_{S}"), head(f"forearm_{S}"), head(f"hand_{S}")], LIMB)
            dot(head(f"hand_{S}"), 7.5)

        # dietro: braccio e gamba lontani
        arm("L")
        leg("L")
        # il busto, dal bacino al collo, un po' più largo sulle spalle (Jax è grosso)
        line([head("hips"), head("spine_2"), head("neck")], BODY)
        if self.stile == "jax":
            sh = head("spine_3")
            line([(sh[0] - 9 * SS, sh[1] + 2 * SS), (sh[0] + 9 * SS, sh[1] - 2 * SS)], 16)
        leg("R")
        if self.stile == "jax":
            self._lampione(m, P, d, g, line)
        arm("R")
        self._testa(m, P, d, g)
        # il contorno chiaro sotto al tratto, poi la luce del lampione sopra a tutto
        # (allargato alla misura finale: il filtro sul disegno grande è lentissimo)
        img = img.resize((W, H), Image.LANCZOS)
        glow = glow.resize((W, H), Image.LANCZOS)
        a = img.getchannel("A").filter(ImageFilter.MaxFilter(2 * OUTLINE + 1)).filter(ImageFilter.GaussianBlur(0.7))
        base = Image.new("RGBA", img.size, PAPER)
        base.putalpha(a)
        base.alpha_composite(img)
        base.alpha_composite(glow.filter(ImageFilter.GaussianBlur(6)))
        base.alpha_composite(glow)
        return base

    def _testa(self, m, P, d, g):
        (hx, hy), a, _ = m["head"]
        # il centro della testa: a metà dell'osso, poi un po' avanti; la testa è grande come quella di Egiainuso
        L = self.sk.lunghezza("head")
        cx, cy = P((hx + math.cos(a) * L * 0.55 + 4, hy + math.sin(a) * L * 0.55))
        r = 32 * SS
        if self.stile == "jax":
            # cappuccio: la punta che ricade dietro, poi la testa tutta nera (la maschera) con gli occhi accesi
            back = a - math.pi / 2  # perpendicolare all'osso, verso la nuca
            bx, by = cx + math.cos(back) * r * 0.2, cy + math.sin(back) * r * 0.2
            ux, uy = math.cos(a + math.pi), math.sin(a + math.pi)
            d.polygon([(bx - r * 0.95, by - r * 0.1), (bx - r * 1.55 + ux * 4, by + r * 0.55), (bx - r * 0.5, by + r * 0.7)], fill=INK)
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=INK)
            # la fessura della maschera e i due occhi, verso destra (il lottatore guarda a destra)
            ex, ey = cx + r * 0.42, cy - r * 0.05
            for k, (ox, oy) in enumerate(((-0.02, 0.0), (0.42, 0.04))):
                x, y = ex + ox * r, ey + oy * r
                w, h = (r * 0.2, r * 0.11) if k == 0 else (r * 0.13, r * 0.1)
                g.ellipse([x - w * 1.6, y - h * 1.6, x + w * 1.6, y + h * 1.6], fill=(255, 214, 90, 150))
                d.ellipse([x - w, y - h, x + w, y + h], fill=(255, 236, 160, 255))
        else:
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=INK)
            r2 = r - 5 * SS
            d.ellipse([cx - r2, cy - r2, cx + r2, cy + r2], fill=PAPER)

    def _lampione(self, m, P, d, g, line):
        # Il lampione in mano, come il bastone di Jax: l'impugnatura è nella mano. Con il braccio giù il palo sta
        # dritto in su, con il braccio in avanti si piega in avanti, con il braccio alzato lo prolunga (i colpi in alto)
        gx, gy = self.sk.punta(m, "forearm_R")
        th = (math.degrees(m["forearm_R"][1]) + 180) % 360 - 180  # 0 = avanti, 90 = giù, -90 = su
        if th < 0:
            phi = th
        elif th <= 90:
            phi = -20 - th * 45 / 90
        else:
            phi = -65 - (th - 90) * 0.3
        ang = math.radians(phi)
        ux, uy = math.cos(ang), math.sin(ang)
        top = (gx + ux * POLE, gy + uy * POLE)
        bottom = (gx - ux * 40, gy - uy * 40)
        line([P(bottom), P(top)], 8)
        # il piede del palo e il braccio che regge la lanterna
        px, py = -uy, ux  # perpendicolare
        line([P((bottom[0] + px * 7, bottom[1] + py * 7)), P((bottom[0] - px * 7, bottom[1] - py * 7))], 6)
        arm_end = (top[0] + px * 20 + ux * 4, top[1] + py * 20 + uy * 4)
        line([P(top), P(arm_end)], 6)
        # la lanterna: un trapezio nero col vetro acceso, appeso al braccio
        lx, ly = arm_end[0] - ux * 14, arm_end[1] - uy * 14
        c = P((lx, ly))
        s = SS
        q = lambda a_, b_: (c[0] + (a_ * px + b_ * ux) * s, c[1] + (a_ * py + b_ * uy) * s)
        d.polygon([q(-16, 14), q(16, 14), q(10, -15), q(-10, -15)], fill=INK)
        d.polygon([q(-10, 8), q(10, 8), q(6, -10), q(-6, -10)], fill=(255, 226, 120, 255))
        g.ellipse([c[0] - 36 * s, c[1] - 36 * s, c[0] + 36 * s, c[1] + 36 * s], fill=(255, 210, 80, 110))


def rendi(cartella_rig, file_anim, uscita, stile, solo=None):
    sk = Scheletro(cartella_rig)
    t = Tratto(sk, stile)
    dati = json.load(open(file_anim))
    os.makedirs(uscita, exist_ok=True)
    # Prima si disegna tutto su una tela larga e si tiene solo il ritaglio di ogni fotogramma; poi il fotogramma
    # finale è il più piccolo che li contiene tutti, con i piedi al centro (il lampione alzato va molto in alto)
    tagli, unione = {}, [CANVAS[0], CANVAS[1], 0, 0]
    for nome, an in dati["animations"].items():
        if solo and nome not in solo.split(","):
            continue
        tagli[nome] = []
        for f in an["frames"]:
            img = t.disegna(f["bones"], f["root"], CANVAS, CANVAS_FEET)
            bb = img.getbbox()
            tagli[nome].append((img.crop(bb), bb) if bb else (None, None))
            if bb:
                unione = [min(unione[0], bb[0]), min(unione[1], bb[1]), max(unione[2], bb[2]), max(unione[3], bb[3])]
    fx, fy = CANVAS_FEET
    half = max(fx - unione[0], unione[2] - fx) + 2
    left, top = fx - half, unione[1] - 2
    misura = (2 * half, unione[3] + 2 - top)
    # Le strisce restano sotto MAX_STRIP pixel di larghezza: se serve si rimpicciolisce tutto (k) e nel gioco
    # lo sprite si ingrandisce di altrettanto (scale)
    k = min(1.0, math.floor(20 * MAX_STRIP / (misura[0] * max(len(fr) for fr in tagli.values()))) / 20)
    finale = (round(misura[0] * k), round(misura[1] * k))
    for nome, fr in tagli.items():
        striscia = Image.new("RGBA", (finale[0] * len(fr), finale[1]), (0, 0, 0, 0))
        for i, (img, bb) in enumerate(fr):
            if img is None:
                continue
            fot = Image.new("RGBA", misura, (0, 0, 0, 0))
            fot.alpha_composite(img, (bb[0] - left, bb[1] - top))
            striscia.alpha_composite(fot.resize(finale, Image.LANCZOS) if k < 1 else fot, (i * finale[0], 0))
        salva(striscia, os.path.join(uscita, f"{nome}.png"))
    print(f"da copiare in characters.ts: frameWidth {finale[0]}, frameHeight {finale[1]}, footY {round((fy - top) * k)}, scale {round(0.5 / k, 3)}")
    # il ritratto per lobby e HUD: la testa del primo fotogramma del fermo, come rendi_sprite.py
    if "idle" in dati["animations"] and not solo:
        f = dati["animations"]["idle"]["frames"][0]
        img = t.disegna(f["bones"], f["root"], CANVAS, CANVAS_FEET)
        (hx, hy), _, _ = sk.fk(f["bones"], f["root"])["head"]
        dx, dy = sk.rig.get("portrait", (-4, 6))
        cx, cy, lato = hx + fx + dx, hy + fy + dy, 150
        salva(img.crop((int(cx - lato / 2), int(cy - lato / 2), int(cx + lato / 2), int(cy + lato / 2))), os.path.join(uscita, "portrait.png"))
        print("ritratto: portrait.png")


if __name__ == "__main__":
    rendi(*sys.argv[1:6])
