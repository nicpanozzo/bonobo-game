# Uso: python3 tools/rig/rendi_sprite.py <cartella del rig> <animazioni.json> <cartella di uscita> [stato,stato...]
# Disegna i fotogrammi dello scheletro a pezzi (#195) e scrive un PNG per stato (<stato>.png, fotogrammi in fila),
# nel formato a cartella degli sprite (E7). Le chiavi sono quelle di tools/rig/animazioni_bonobot.py:
# gradi per osso rispetto al riposo e spostamento della radice, una chiave per fotogramma.
# Serve Pillow (pip install pillow).
import json, math, os, sys
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scheletro import Scheletro

SS = 2  # si disegna al doppio e poi si rimpicciolisce: bordi lisci anche sui pezzi ruotati


def salva(img, path):
    """PNG con una palette di 256 colori: i disegni a tinte piatte restano uguali e il file pesa un sesto."""
    img.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).save(path, optimize=True)


class Pittore:
    def __init__(self, sk):
        self.sk = sk
        self.strati = []  # (z, osso, immagine premoltiplicata, x, y) dal fondo
        for p in sk.rig["pieces"]:
            img = Image.open(os.path.join(sk.cartella, p["image"])).convert("RGBA")
            self.strati.append((p["z"], p["bone"], img, p["x"], p["y"]))
            if p.get("ink"):
                ink = Image.open(os.path.join(sk.cartella, p["ink"])).convert("RGBA")
                self.strati.append((p.get("inkZ", p["z"] - 0.5), p["bone"], ink, p["x"], p["y"]))
        self.strati.sort(key=lambda s: s[0])
        self.fumo = [e for e in sk.rig.get("effects", []) if e["type"] == "smoke"]

    def disegna(self, posa, radice, misura, piedi, t=0.0):
        """Un fotogramma RGBA di misura (larghezza, altezza); piedi = dove sta l'origine dello scheletro nel fotogramma."""
        W, H = misura[0] * SS, misura[1] * SS
        tela = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        mat = self.sk.matrici(posa, radice)
        fx, fy = piedi
        for _, osso, img, x, y in self.strati:
            a, b, c, d, e, f = mat[osso]
            # dal pixel (u, v) del pezzo al pixel della tela (scalata di SS)
            A = [[a * SS, c * SS], [b * SS, d * SS]]
            tx = (a * x + c * y + e + fx) * SS
            ty = (b * x + d * y + f + fy) * SS
            det = A[0][0] * A[1][1] - A[0][1] * A[1][0]
            ia, ib, ic, id_ = A[1][1] / det, -A[0][1] / det, -A[1][0] / det, A[0][0] / det
            inv = (ia, ib, -(ia * tx + ib * ty), ic, id_, -(ic * tx + id_ * ty))
            pezzo = img.convert("RGBa").transform((W, H), Image.AFFINE, inv, resample=Image.BICUBIC)
            tela = Image.alpha_composite(tela, pezzo.convert("RGBA"))
        for eff in self.fumo:
            self._fumo(tela, posa, radice, piedi, eff, t)
        return tela.resize(misura, Image.LANCZOS)

    def _fumo(self, tela, posa, radice, piedi, eff, t):
        """Tre sbuffi che salgono dalla punta della canna, allargandosi e sbiadendo (in gioco è un effetto)."""
        m = self.sk.fk(posa, radice)
        px, py = self.sk.punta(m, eff["bone"]) if eff.get("at") == "tail" else m[eff["bone"]][0]
        strato = Image.new("RGBA", tela.size, (0, 0, 0, 0))
        g = ImageDraw.Draw(strato)
        for k in range(3):
            eta = (t / 1.1 + k / 3.0) % 1.0
            x = px + piedi[0] - 10 * eta + 3 * math.sin(6.0 * eta + k)
            y = py + piedi[1] - 4 - 46 * eta
            r = 3.5 + 8 * eta
            alfa = int(150 * (1 - eta) ** 1.3)
            g.ellipse([(x - r) * SS, (y - r) * SS, (x + r) * SS, (y + r) * SS], fill=(206, 200, 190, alfa))
        tela.alpha_composite(strato.filter(ImageFilter.GaussianBlur(1.2 * SS)))


def rendi(cartella_rig, file_anim, uscita, solo=None):
    sk = Scheletro(cartella_rig)
    pit = Pittore(sk)
    dati = json.load(open(file_anim))
    misura, piedi = tuple(dati["frame"]), tuple(dati["feet"])
    os.makedirs(uscita, exist_ok=True)
    for nome, an in dati["animations"].items():
        if solo and nome not in solo.split(","):
            continue
        fotogrammi = an["frames"]
        striscia = Image.new("RGBA", (misura[0] * len(fotogrammi), misura[1]), (0, 0, 0, 0))
        for i, fr in enumerate(fotogrammi):
            img = pit.disegna(fr["bones"], fr["root"], misura, piedi, t=i / an["fps"])
            striscia.alpha_composite(img, (i * misura[0], 0))
        salva(striscia, os.path.join(uscita, f"{nome}.png"))
        print(f"{nome}: {len(fotogrammi)} fotogrammi")
    # Il ritratto per lobby e HUD (E11): testa e spalle del primo fotogramma del fermo, quadrato, a 2x
    if "idle" in dati["animations"] and not solo:
        fr = dati["animations"]["idle"]["frames"][0]
        img = pit.disegna(fr["bones"], fr["root"], misura, piedi)
        (hx, hy), _, _ = sk.fk(fr["bones"], fr["root"])["head"]
        lato = 150
        cx, cy = hx + piedi[0] - 4, hy + piedi[1] + 6
        salva(img.crop((int(cx - lato / 2), int(cy - lato / 2), int(cx + lato / 2), int(cy + lato / 2))), os.path.join(uscita, "portrait.png"))
        print("ritratto: portrait.png")


if __name__ == "__main__":
    rendi(*sys.argv[1:5])
