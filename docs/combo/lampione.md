# Combo di Lampione

Generato da `npm run combo-lab -- lampione` (issue #594): non modificare a mano, rilancia il laboratorio.

Il laboratorio usa la fisica vera: la prima mossa colpisce un Bonobo fermo, poi Lampione insegue e prova la mossa dopo a ogni tick. **Vera** = entra mentre il bersaglio è ancora stordito, qualunque cosa faccia (fermo, spingendo via o verso di lui, rialzandosi al volo). Le percentuali sono quelle del bersaglio prima del primo colpo, da 0 a 150 a passi di 10.

## Combo del personaggio

- **Tuffo del portiere**: light → lightDown → specialSide. Vera a 0-70%. Entra solo se il bersaglio non reagisce a 80-150%.
- **Ping pong**: light → lightDown → specialNeutral. Vera a 0-70%. Entra solo se il bersaglio non reagisce a 80-150%.
- **Rinvio**: lightUp → lightUp → recovery. Vera a 60-110%. Entra solo se il bersaglio non reagisce a 0-50, 120-150%.

## Combo note

Le combo che c'erano già (la combo di leggeri e quella di #557), riprovate dal laboratorio.

- **Combo di leggeri (jab)**: light → light → light. Mai vera. Entra solo se il bersaglio non reagisce a 0-150%.

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
| grab | 15 | 2 |
| throw | 8 | 0 |

Senza disegno proprio: dashAttack (usa heavy).

## Coppie che legano

Solo con mosse già disegnate. La seconda mossa prende per forza dopo la prima.

| Prima | Dopo | Vera a % | Solo se non reagisce a % |
|---|---|---|---|
| light | light | 0-70 | 80-150 |
| light | lightDown | 0-70 | 80-150 |
| light | recovery | 0-70 | 80-90 |
| lightUp | lightUp | 60-150 | 0-50 |
| lightUp | recovery | 70-150 | 0-60 |
| lightUp | lightAir | 120-140 | 0-110, 150 |
| specialNeutral | light | 110-150 | 0-100 |
| specialNeutral | lightUp | 120-150 | 0-110 |
| specialNeutral | lightDown | 110-150 | 0-100 |
| specialNeutral | lightAir | 110-150 | 0-100 |
| specialNeutral | recovery | 120 | 0-110, 140 |

### Il bersaglio fa in tempo a scappare

La seconda mossa arriva, ma il bersaglio non è più stordito o può uscirne.

- dopo **light**: lightUp (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), lightAir (0-150%), heavyAir (0-150%), heavy (150%)
- dopo **lightUp**: light (0-70%), lightDown (0-110%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-110%), heavyAir (0-150%)
- dopo **lightDown**: light (0-150%), lightUp (0-150%), lightDown (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), lightAir (0-130%), heavyAir (0-130%), heavy (50-150%), recovery (100-120%)
- dopo **lightAir**: light (0-150%), lightDown (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), lightUp (0-150%), heavy (0-150%), heavyAir (0-100%), recovery (0-30%), lightAir (0-90%)
- dopo **heavy**: specialNeutral (20-100%), specialSide (20-100%), light (20-50%), lightUp (20-50%), lightDown (20-50%), heavy (20-30%), heavyUp (20-50%), heavyDown (20-50%), grab (20-50%)
- dopo **heavyUp**: lightUp (30-80%), heavyUp (30-50%), heavyDown (30-50%), specialNeutral (30, 50-80%), recovery (30-100%), lightAir (40-80%), heavyAir (40-90%), specialSide (40-80%)
- dopo **heavyDown**: light (30-80%), lightDown (30-80%), heavy (30-60%), heavyDown (30-80%), specialNeutral (30-130%), specialSide (30-130%), lightUp (30-70%), heavyUp (30-80%), grab (40-80%)
- dopo **heavyAir**: light (0-50%), heavy (0-40%), specialNeutral (0-110%), specialSide (0-110%), heavyDown (0-60%), lightDown (0-60%), grab (0-50%), heavyUp (0-50%), lightUp (0-50%), lightAir (0-20%), heavyAir (0-20%)
- dopo **specialNeutral**: heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), heavyAir (10-150%), heavy (120-150%)
- dopo **specialSide**: specialNeutral (110-150%), specialSide (110-130%)
- dopo **throwForward**: light (0-40%), heavy (0-40%), specialNeutral (0-140%), specialSide (0-120%), lightDown (0-40%), heavyDown (0-40%), heavyUp (0-40%), grab (0-40%), lightUp (0-30%), lightAir (0-20%), heavyAir (0-30%)
- dopo **throwBack**: lightUp (0-70%), lightDown (0-80%), heavyUp (0-70%), heavyDown (0-80%), specialSide (0-120%), specialNeutral (0-120%), grab (0-70%), lightAir (0-40%), heavyAir (0-50%), recovery (0-20%), light (20-80%), heavy (40-60%)
- dopo **throwUp**: light (0-30%), lightUp (0-110%), lightDown (0-40%), heavyUp (0-80%), heavyDown (0-80%), specialNeutral (0-90%), specialSide (0-80%), grab (0-40%), lightAir (10-90%), heavyAir (10-120%), recovery (10-130%)
- dopo **throwDown**: light (0-110%), lightDown (0-100%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-100%), lightUp (0-150%), lightAir (20-150%), heavyAir (20-150%), recovery (20-150%), heavy (50-150%)

## Catene che non finiscono mai

Nessuna: nessuna coppia continua a legare oltre 12 colpi.

## Clip che servono

Mosse senza disegno proprio che, disegnate, chiuderebbero queste combo (già vere per la fisica):

- **dashAttack** (oggi usa heavy), 1 combo:
  - specialNeutral → dashAttack a 150%
