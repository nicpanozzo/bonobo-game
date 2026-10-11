# Conti dello scheletro a pezzi (#195): posizioni e angoli delle ossa, IK a due ossa, matrici dei pezzi.
# Una posa è un dizionario {osso: gradi rispetto al riposo} più lo spostamento della radice in pixel a 2x.
# Gradi positivi = orario, con y in giù, come in tools/blender/esporta_animazioni.py.
import json, math, os


class Scheletro:
    def __init__(self, cartella):
        self.cartella = cartella
        self.rig = json.load(open(os.path.join(cartella, "rig.json")))
        self.ossa = {b["name"]: b for b in self.rig["bones"]}
        self.ordine = [b["name"] for b in self.rig["bones"] if b["deform"]]  # i genitori vengono prima

    def riposo(self, n):
        b = self.ossa[n]
        return math.atan2(b["tail"][1] - b["head"][1], b["tail"][0] - b["head"][0])

    def lunghezza(self, n):
        b = self.ossa[n]
        return math.hypot(b["tail"][0] - b["head"][0], b["tail"][1] - b["head"][1])

    def fk(self, posa, radice=(0.0, 0.0)):
        """{osso: (testa nel mondo, angolo nel mondo in radianti, rotazione rispetto al riposo in radianti)}."""
        mondo = {}
        for n in self.ordine:
            b = self.ossa[n]
            delta = math.radians(posa.get(n, 0.0))
            if b["parent"]:
                ph, pa, pd = mondo[b["parent"]]
                p = self.ossa[b["parent"]]
                lx, ly = b["head"][0] - p["head"][0], b["head"][1] - p["head"][1]
                c, s = math.cos(pd), math.sin(pd)
                testa = (ph[0] + lx * c - ly * s, ph[1] + lx * s + ly * c)
                tot = pd + delta
            else:
                testa = (b["head"][0] + radice[0], b["head"][1] + radice[1])
                tot = delta
            mondo[n] = (testa, self.riposo(n) + tot, tot)
        return mondo

    def punta(self, mondo, n):
        (x, y), a, _ = mondo[n]
        l = self.lunghezza(n)
        return (x + l * math.cos(a), y + l * math.sin(a))

    def due_ossa(self, posa, radice, sopra, sotto, bersaglio, piega):
        """Scarti in gradi di `sopra` e `sotto` che portano la punta di `sotto` sul bersaglio.
        piega +1 o -1: da che parte va la giuntura. Con il bersaglio sotto, +1 la porta in avanti (verso x
        più grandi, come un ginocchio) e -1 indietro (come un gomito con la mano davanti)."""
        m = self.fk(posa, radice)
        (sx, sy), _, tot = m[sopra]
        genitore = tot - math.radians(posa.get(sopra, 0.0))  # rotazione accumulata dal genitore
        l1, l2 = self.lunghezza(sopra), self.lunghezza(sotto)
        dx, dy = bersaglio[0] - sx, bersaglio[1] - sy
        d = max(1e-3, min(l1 + l2 - 0.01, math.hypot(dx, dy)))
        base = math.atan2(dy, dx)
        a1 = base - piega * math.acos(max(-1.0, min(1.0, (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d))))
        a2 = math.atan2(dy - l1 * math.sin(a1), dx - l1 * math.cos(a1))
        off1 = a1 - self.riposo(sopra) - genitore
        off2 = (a2 - a1) - (self.riposo(sotto) - self.riposo(sopra))
        giro = lambda x: (math.degrees(x) + 180) % 360 - 180
        return giro(off1), giro(off2)

    def angolo_mondo(self, posa, radice, n, gradi):
        """Lo scarto di `n` che gli dà l'angolo `gradi` nel mondo (0 = verso destra, 90 = in giù)."""
        m = self.fk(posa, radice)
        _, a, tot = m[n]
        genitore = tot - math.radians(posa.get(n, 0.0))
        return (gradi - math.degrees(self.riposo(n) + genitore) + 180) % 360 - 180

    def matrici(self, posa, radice=(0.0, 0.0)):
        """Per ogni osso la matrice (a, b, c, d, e, f) che porta un punto del disegno a riposo nel mondo:
        x' = a x + c y + e, y' = b x + d y + f."""
        out = {}
        for n, ((hx, hy), _, tot) in self.fk(posa, radice).items():
            rx, ry = self.ossa[n]["head"]
            c, s = math.cos(tot), math.sin(tot)
            out[n] = (c, s, -s, c, hx - (c * rx - s * ry), hy - (s * rx + c * ry))
        return out
