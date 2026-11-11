# Combo di Nonna Gina

Generato da `npm run combo-lab -- nonnagina` (issue #594): non modificare a mano, rilancia il laboratorio.

Il laboratorio usa la fisica vera: la prima mossa colpisce un Bonobo fermo, poi Nonna Gina insegue e prova la mossa dopo a ogni tick. **Vera** = entra mentre il bersaglio è ancora stordito, qualunque cosa faccia (fermo, spingendo via o verso di lui, rialzandosi al volo). Le percentuali sono quelle del bersaglio prima del primo colpo, da 0 a 150 a passi di 10.

## Combo del personaggio

- **Mattarello e ciabatta**: light → lightDown → specialSide. Vera a 0-70%. Entra solo se il bersaglio non reagisce a 80-150%.
- **Secondo piatto**: light → lightDown → specialNeutral. Vera a 0-70%. Entra solo se il bersaglio non reagisce a 80-150%.
- **Scappellotto**: heavyUp → lightUp. Vera a 10-40%. Entra solo se il bersaglio non reagisce a 0, 50-70%.

## Combo note

Le combo che c'erano già (la combo di leggeri e quella di #557), riprovate dal laboratorio.

- **Combo di leggeri (jab)**: light → light → light. Vera a 0-70%. Entra solo se il bersaglio non reagisce a 80-150%.

## Mosse disegnate

| Mossa | Fotogrammi | Fotogramma del colpo |
|---|---|---|
| light | 9 | 2 |
| lightUp | 8 | 2 |
| lightDown | 8 | 2 |
| lightAir | 8 | 2 |
| heavy | 18 | 8 |
| heavyUp | 19 | 7 |
| heavyDown | 18 | 6 |
| heavyAir | 17 | 5 |
| recovery | 6 | 0 |
| specialNeutral | 15 | 5 |
| specialSide | 13 | 4 |
| grab | 15 | 2 |
| throw | 8 | 0 |

Senza disegno proprio: dashAttack (usa heavy).

## Coppie che legano

Solo con mosse già disegnate. La seconda mossa prende per forza dopo la prima.

| Prima | Dopo | Vera a % | Solo se non reagisce a % |
|---|---|---|---|
| light | light | 0-70 | 80-150 |
| light | lightDown | 0-70 | 80-150 |
| light | recovery | 0-50 | 60-150 |
| heavyUp | lightUp | 10-40 | 0, 50-70 |
| heavyUp | recovery | 10-50 | 0, 60-80 |
| specialNeutral | light | 90-140 | 0-80, 150 |
| specialNeutral | recovery | 70-130 | 0-60, 150 |
| specialNeutral | lightAir | 140-150 | 0-130 |
| specialNeutral | lightUp | 100-150 | 50-90 |
| specialSide | light | 110-130 | 0-100, 140-150 |
| specialSide | lightDown | 110-120 | 0-100, 130-150 |

### Il bersaglio fa in tempo a scappare

La seconda mossa arriva, ma il bersaglio non è più stordito o può uscirne.

- dopo **light**: heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), lightAir (0-150%), heavyAir (0-150%)
- dopo **lightDown**: light (0-150%), lightDown (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), lightAir (0-130%), recovery (0-110%), heavyAir (0-150%)
- dopo **lightAir**: light (0-150%), lightDown (0-150%), heavy (0-120%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), lightAir (0-90%), heavyAir (0-140%), recovery (0-70%)
- dopo **heavy**: specialSide (30-100%), light (30-40%), lightDown (30-50%), heavyUp (30-40%), heavyDown (30-50%), specialNeutral (30-100%), grab (30-40%), heavyAir (30%)
- dopo **heavyUp**: light (20%), lightDown (20%), heavy (20-50%), heavyUp (20-50%), heavyDown (20-50%), specialNeutral (20-70%), specialSide (20-60%), heavyAir (20-70%), lightAir (30-60%)
- dopo **heavyDown**: light (20-60%), lightDown (20-60%), heavy (20-40%), heavyDown (20-60%), specialNeutral (20-130%), specialSide (20-130%), heavyUp (20-60%), grab (20-60%), heavyAir (20-50%)
- dopo **heavyAir**: specialNeutral (0-110%), specialSide (0-110%), heavyDown (0-50%), lightDown (0-40%), light (0-40%), heavy (0%), grab (0-40%), heavyUp (0-40%), lightAir (0-20%), heavyAir (0-40%)
- dopo **specialNeutral**: lightDown (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), heavyAir (0-150%)
- dopo **specialSide**: heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), heavyAir (0-110%), lightAir (0-120%), lightUp (90-110%)
- dopo **throwForward**: specialNeutral (0-130%), specialSide (0-140%), heavyDown (0-40%), light (0-30%), lightDown (0-30%), heavyUp (0-10%), grab (0-10%), lightAir (0-30%), heavyAir (0-40%)
- dopo **throwBack**: light (0-70%), lightDown (0-70%), heavy (0-30%), heavyUp (0-60%), heavyDown (0-70%), specialSide (0-120%), specialNeutral (0-120%), grab (0-60%), lightAir (0-40%), heavyAir (0-60%), recovery (0-20%)
- dopo **throwUp**: light (0-50%), lightDown (0-40%), heavy (0-80%), heavyUp (0-80%), heavyDown (0-80%), specialNeutral (0-80%), specialSide (0-70%), grab (0-40%), lightUp (10-100%), heavyAir (10-100%), recovery (10-120%), lightAir (10-90%)
- dopo **throwDown**: light (0-110%), lightDown (0-100%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-90%), lightAir (20-150%), heavyAir (20-150%), recovery (20-150%), lightUp (50-150%)

## Catene che non finiscono mai

Nessuna: nessuna coppia continua a legare oltre 12 colpi.

## Clip che servono

Mosse senza disegno proprio che, disegnate, chiuderebbero queste combo (già vere per la fisica):

- **dashAttack** (oggi usa heavy), 2 combo:
  - lightAir → dashAttack a 80%
  - specialSide → dashAttack a 130-150%
