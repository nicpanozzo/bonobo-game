# Combo di Dr. Micelium

Generato da `npm run combo-lab -- drmicelium` (issue #594): non modificare a mano, rilancia il laboratorio.

Il laboratorio usa la fisica vera: la prima mossa colpisce un Bonobo fermo, poi Dr. Micelium insegue e prova la mossa dopo a ogni tick. **Vera** = entra mentre il bersaglio è ancora stordito, qualunque cosa faccia (fermo, spingendo via o verso di lui, rialzandosi al volo). Le percentuali sono quelle del bersaglio prima del primo colpo, da 0 a 150 a passi di 10.

## Combo del personaggio

- **Bisturi**: light → lightDown → specialSide. Vera a 0-70%. Entra solo se il bersaglio non reagisce a 80-150%.
- **Via del fungo**: light → lightDown → specialDown. Vera a 0-70%. Entra solo se il bersaglio non reagisce a 80-150%.
- **Sutura**: lightUp → lightUp → lightAir. Vera a 60-90%. Entra solo se il bersaglio non reagisce a 0-50, 100-140%.

## Combo note

Le combo che c'erano già (la combo di leggeri e quella di #557), riprovate dal laboratorio.

- **Combo di leggeri (jab)**: light → light → light. Vera a 0-70%. Entra solo se il bersaglio non reagisce a 80-150%.

## Mosse disegnate

| Mossa | Fotogrammi | Fotogramma del colpo |
|---|---|---|
| light | 10 | 2 |
| lightUp | 8 | 2 |
| lightDown | 8 | 2 |
| lightAir | 8 | 2 |
| heavy | 18 | 8 |
| heavyUp | 19 | 7 |
| heavyDown | 18 | 6 |
| heavyAir | 17 | 5 |
| recovery | 6 | 0 |
| specialNeutral | 15 | 5 |
| specialSide | 18 | 3 |
| specialDown | 17 | 1 |
| grab | 15 | 2 |
| throw | 8 | 0 |

Senza disegno proprio: dashAttack (usa heavy).

## Coppie che legano

Solo con mosse già disegnate. La seconda mossa prende per forza dopo la prima.

| Prima | Dopo | Vera a % | Solo se non reagisce a % |
|---|---|---|---|
| light | light | 0-70 | 80-150 |
| light | lightDown | 0-70 | 80-150 |
| light | recovery | 0-70 | 80-150 |
| lightUp | lightUp | 60-150 | 0-50 |
| lightUp | recovery | 70-150 | 0-60 |
| lightUp | lightAir | 120 | 0-110, 130-150 |
| specialSide | light | 110-150 | 0-100 |
| specialSide | lightUp | 120-130 | 0-110, 140-150 |
| specialSide | lightDown | 110-150 | 0-100 |

### Il bersaglio fa in tempo a scappare

La seconda mossa arriva, ma il bersaglio non è più stordito o può uscirne.

- dopo **light**: lightUp (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), specialDown (0-150%), grab (0-150%), lightAir (0-150%), heavyAir (0-150%)
- dopo **lightUp**: light (0-120%), lightDown (0-110%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), specialDown (0-150%), grab (0-110%), heavyAir (0-150%)
- dopo **lightDown**: light (0-150%), lightUp (0-150%), lightDown (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), specialDown (0-150%), grab (0-150%), lightAir (0-130%), heavyAir (0-150%), recovery (60-120%)
- dopo **lightAir**: light (0-150%), lightDown (0-150%), heavy (0-140%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), specialDown (0-150%), grab (0-150%), heavyUp (0-150%), lightUp (0-150%), lightAir (0-90%), heavyAir (0-140%), recovery (0-80%)
- dopo **heavy**: specialNeutral (20-100%), specialSide (20-110%), light (20-60%), lightUp (20-50%), lightDown (20-60%), heavy (20-40%), heavyUp (20-60%), heavyDown (20-60%), specialDown (20-60%), grab (20-60%), heavyAir (20-40%)
- dopo **heavyUp**: lightUp (30-70%), heavy (30-50%), heavyUp (30-50%), heavyDown (30-50%), specialNeutral (30-80%), specialSide (30%), specialDown (30-80%), lightAir (30-70%), heavyAir (30-70%), recovery (30-90%)
- dopo **heavyDown**: heavyDown (30-80%), specialNeutral (30-120%), specialSide (30-130%), light (30-70%), lightUp (30-70%), lightDown (30-80%), heavy (30-60%), heavyUp (30-70%), specialDown (30-80%), grab (30-70%), heavyAir (30-50%)
- dopo **heavyAir**: specialNeutral (0-100%), specialSide (0-110%), heavyDown (0-50%), lightDown (0-50%), specialDown (0-50%), light (0-50%), heavy (0-20%), grab (0-50%), heavyUp (0-50%), lightUp (0-50%), lightAir (0-20%), heavyAir (0-40%)
- dopo **specialNeutral**: light (0-150%), lightUp (0-150%), lightDown (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), specialDown (0-150%), grab (0-150%), recovery (0-150%), heavyAir (0-150%), lightAir (100-150%)
- dopo **specialSide**: heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), specialDown (0-150%), grab (0-150%), recovery (0-80%), heavyAir (0-150%), lightAir (10-150%)
- dopo **specialDown**: specialNeutral (70-150%), specialSide (70-150%), heavyAir (90-110%)
- dopo **throwForward**: specialNeutral (0-110%), specialSide (0-140%), lightDown (0-40%), heavyDown (0-40%), specialDown (0-40%), light (0-40%), heavyUp (0-30%), grab (0-30%), lightUp (0-20%), lightAir (0-20%), heavyAir (0-40%)
- dopo **throwBack**: light (0-70%), lightUp (0-70%), lightDown (0-80%), heavy (0-30%), heavyUp (0-70%), heavyDown (0-70%), specialSide (0-120%), specialDown (0-70%), specialNeutral (0-120%), grab (0-70%), lightAir (0-40%), heavyAir (0-60%), recovery (0-20%)
- dopo **throwUp**: light (0-50%), lightUp (0-100%), lightDown (0-40%), heavy (0-80%), heavyUp (0-80%), heavyDown (0-80%), specialNeutral (0-110%), specialSide (0-100%), specialDown (0-120%), grab (0-40%), lightAir (10-100%), heavyAir (10-110%), recovery (10-120%)
- dopo **throwDown**: light (0-110%), lightDown (0-100%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), specialDown (0-150%), grab (0-100%), lightUp (0-150%), lightAir (20-150%), heavyAir (20-150%), recovery (20-150%)

## Catene che non finiscono mai

Nessuna: nessuna coppia continua a legare oltre 12 colpi.

## Clip che servono

Mosse senza disegno proprio che, disegnate, chiuderebbero queste combo (già vere per la fisica):

- **dashAttack** (oggi usa heavy), 1 combo:
  - specialSide → dashAttack a 140-150%
