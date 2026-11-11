# Combo di Maestro Opus

Generato da `npm run combo-lab -- opus` (issue #594): non modificare a mano, rilancia il laboratorio.

Il laboratorio usa la fisica vera: la prima mossa colpisce un Bonobo fermo, poi Maestro Opus insegue e prova la mossa dopo a ogni tick. **Vera** = entra mentre il bersaglio è ancora stordito, qualunque cosa faccia (fermo, spingendo via o verso di lui, rialzandosi al volo). Le percentuali sono quelle del bersaglio prima del primo colpo, da 0 a 150 a passi di 10.

## Combo del personaggio

- **Glissando**: light → lightDown → specialSide. Vera a 0-70%. Entra solo se il bersaglio non reagisce a 80-150%.
- **Staccato**: light → lightDown → specialNeutral. Vera a 0-70%. Entra solo se il bersaglio non reagisce a 80-150%.
- **Da capo**: heavyUp → recovery. Vera a 10-50%. Entra solo se il bersaglio non reagisce a 0, 60-100%.

## Combo note

Le combo che c'erano già (la combo di leggeri e quella di #557), riprovate dal laboratorio.

- **Combo di leggeri (jab)**: light → light → light. Vera a 0-70%. Entra solo se il bersaglio non reagisce a 80-150%.

## Mosse disegnate

| Mossa | Fotogrammi | Fotogramma del colpo |
|---|---|---|
| light | 9 | 2 |
| lightUp | 9 | 2 |
| lightDown | 9 | 2 |
| lightAir | 9 | 2 |
| heavy | 18 | 7 |
| heavyUp | 18 | 7 |
| heavyDown | 18 | 6 |
| heavyAir | 17 | 6 |
| recovery | 8 | 0 |
| specialNeutral | 15 | 5 |
| specialSide | 15 | 4 |
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
| heavyUp | recovery | 10-50 | 0, 60-100 |
| specialNeutral | light | 80-150 | 0-70 |
| specialNeutral | lightDown | 80-150 | 0-70 |
| specialNeutral | specialSide | 130-150 | 0-120 |
| specialNeutral | lightAir | 80-150 | 0-70 |
| specialNeutral | recovery | 130-150 | 0-120 |
| specialNeutral | lightUp | 100-150 | 80-90 |

### Il bersaglio fa in tempo a scappare

La seconda mossa arriva, ma il bersaglio non è più stordito o può uscirne.

- dopo **light**: heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), lightAir (0-150%), heavyAir (0-150%)
- dopo **lightDown**: light (0-150%), lightDown (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), lightAir (0-150%), heavyAir (0-150%), recovery (140%)
- dopo **lightAir**: light (0-150%), lightDown (0-150%), heavy (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), heavyUp (0-150%), heavyAir (0-120%), recovery (0-40%), lightAir (0-120%), lightUp (50-150%)
- dopo **heavy**: light (20-70%), lightDown (20-70%), heavy (20-50%), heavyDown (20-70%), specialNeutral (20-110%), specialSide (20-110%), grab (20-60%), heavyUp (20-60%), lightAir (20-30%), lightUp (50%)
- dopo **heavyUp**: light (20%), lightUp (20-90%), lightDown (20%), heavy (20-50%), heavyUp (20-50%), heavyDown (20-50%), specialNeutral (20-40, 70-80%), specialSide (20%), lightAir (20, 40-90%), heavyAir (40-90%)
- dopo **heavyDown**: light (30-90%), lightDown (30-90%), heavy (30-70%), heavyDown (30-90%), specialNeutral (30-130%), specialSide (30-130%), grab (30-80%), heavyUp (30-80%), lightAir (30-40%)
- dopo **heavyAir**: specialNeutral (0-120%), specialSide (0-110%), lightDown (0-60%), heavyDown (0-60%), light (0-60%), heavy (0-40%), grab (0-60%), heavyUp (0-50%), lightAir (0-30%), heavyAir (0-30%)
- dopo **specialNeutral**: heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), grab (0-150%), heavyAir (80-150%)
- dopo **specialSide**: specialNeutral (80-150%), specialSide (80-150%), heavyAir (100%)
- dopo **throwForward**: specialNeutral (0-140%), specialSide (0-120%), heavyDown (0-50%), light (0-50%), lightDown (0-50%), heavyUp (0-40%), grab (0-40%), lightAir (0-40%), heavyAir (0-40%)
- dopo **throwBack**: light (0-90%), lightDown (0-80%), heavy (0-40, 70%), heavyUp (0-70%), heavyDown (0-80%), specialSide (0-120%), specialNeutral (0-120%), grab (0-80%), lightAir (0-60%), heavyAir (0-50%), recovery (0-20%), lightUp (40-70%)
- dopo **throwUp**: light (0-50%), lightDown (0-40%), heavy (0-80%), heavyUp (0-80%), heavyDown (0-80%), specialNeutral (0-100%), specialSide (0-90%), grab (0-40%), lightUp (10-100%), lightAir (10-100%), heavyAir (10-100, 120%), recovery (10-130%)
- dopo **throwDown**: light (0-110%), lightDown (0-90%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-100%), lightAir (20-150%), heavyAir (20-150%), recovery (20-150%), lightUp (40-150%)

## Catene che non finiscono mai

Nessuna: nessuna coppia continua a legare oltre 12 colpi.

## Clip che servono

Mosse senza disegno proprio che, disegnate, chiuderebbero queste combo (già vere per la fisica):

- **dashAttack** (oggi usa heavy), 2 combo:
  - lightAir → dashAttack a 80-100%
  - specialNeutral → dashAttack a 120-150%
