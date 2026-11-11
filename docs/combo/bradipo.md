# Combo di Bradipo Giallo

Generato da `npm run combo-lab -- bradipo` (issue #594): non modificare a mano, rilancia il laboratorio.

Il laboratorio usa la fisica vera: la prima mossa colpisce un Bonobo fermo, poi Bradipo Giallo insegue e prova la mossa dopo a ogni tick. **Vera** = entra mentre il bersaglio è ancora stordito, qualunque cosa faccia (fermo, spingendo via o verso di lui, rialzandosi al volo). Le percentuali sono quelle del bersaglio prima del primo colpo, da 0 a 150 a passi di 10.

## Combo del personaggio

- **Giro di basso**: lightUp → lightUp. Vera a 60-150%. Entra solo se il bersaglio non reagisce a 0-50%.
- **Slap**: heavyUp → lightUp. Vera a 0-30%. Entra solo se il bersaglio non reagisce a 40-70%.
- **Bassline**: light → lightDown → specialSide. Vera a 0-70%. Entra solo se il bersaglio non reagisce a 80-150%.
- **Ciacole**: light → lightDown → specialNeutral. Vera a 0-70%. Entra solo se il bersaglio non reagisce a 80-150%.

## Combo note

Le combo che c'erano già (la combo di leggeri e quella di #557), riprovate dal laboratorio.

- **Combo di leggeri (jab)**: light → light → light. Vera a 0-70%. Entra solo se il bersaglio non reagisce a 80-150%.

## Mosse disegnate

| Mossa | Fotogrammi | Fotogramma del colpo |
|---|---|---|
| light | 8 | 2 |
| lightUp | 6 | 1 |
| lightDown | 6 | 0 |
| lightAir | 5 | 1 |
| heavy | 10 | 2 |
| heavyUp | 9 | 2 |
| heavyDown | 10 | 2 |
| heavyAir | 4 | 0 |
| recovery | 5 | 0 |
| specialNeutral | 8 | 3 |
| specialSide | 15 | 5 |
| grab | 9 | 5 |
| throw | 7 | 0 |

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
| heavyUp | lightUp | 0-30 | 40-70 |
| heavyUp | recovery | 10-50 | 0, 60-90 |
| specialNeutral | light | 90-150 | 0-80 |
| specialNeutral | lightUp | 110-150 | 0-100 |
| specialNeutral | lightDown | 90-150 | 0-80 |
| specialNeutral | lightAir | 90-150 | 0-80 |
| specialNeutral | recovery | 150 | 0-140 |

### Il bersaglio fa in tempo a scappare

La seconda mossa arriva, ma il bersaglio non è più stordito o può uscirne.

- dopo **light**: lightUp (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), lightAir (0-150%), heavyAir (0-150%)
- dopo **lightUp**: light (0-120%), lightDown (0-110%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-110%), lightAir (0-150%), heavyAir (0-150%)
- dopo **lightDown**: light (0-150%), lightUp (0-150%), lightDown (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), lightAir (0-140%), heavyAir (0-150%), recovery (90-140%)
- dopo **lightAir**: light (0-150%), lightDown (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), lightUp (0-150%), heavyAir (0-150%), recovery (0-40, 70-80%), lightAir (0-100%)
- dopo **heavy**: specialNeutral (20-90%), specialSide (20-110%), light (20-70%), lightUp (20-60%), lightDown (20-60%), heavy (20-50%), heavyUp (20-60%), heavyDown (20-60%), grab (20-60%), heavyAir (20-40%)
- dopo **heavyUp**: light (20%), heavy (20-50%), heavyUp (20-50%), heavyDown (20-50%), specialNeutral (20%), specialSide (20-40, 70%), lightDown (20%), grab (20%), heavyAir (20-80%), lightAir (30-70%)
- dopo **heavyDown**: light (30-80%), heavy (30-70%), specialNeutral (30-110%), specialSide (30-130%), lightUp (30-80%), lightDown (30-80%), heavyUp (30-80%), heavyDown (30-80%), grab (30, 50-80%), heavyAir (30-60%)
- dopo **heavyAir**: specialNeutral (0-80%), specialSide (0-110%), light (0-60%), heavy (0-40%), heavyDown (0-50%), grab (0-50%), lightDown (0-50%), heavyUp (0-50%), lightUp (0-50%), lightAir (0-20%), heavyAir (0-30%)
- dopo **specialNeutral**: heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), heavyAir (0-150%)
- dopo **specialSide**: light (0-150%), lightUp (0-150%), lightDown (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), heavyAir (0-150%), lightAir (70-150%)
- dopo **throwForward**: specialNeutral (0-90%), specialSide (0-150%), light (0-50%), heavyDown (0-40%), lightDown (0-40%), heavyUp (0-40%), grab (0-40%), lightUp (0-40%), lightAir (0-30%), heavyAir (0-40%)
- dopo **throwBack**: light (0-90%), lightUp (0-80%), lightDown (0-80%), heavy (0-50, 70%), heavyUp (0-80%), heavyDown (0-80%), specialSide (0-130%), specialNeutral (0-110%), grab (0-80%), lightAir (0-50%), heavyAir (0-60%), recovery (0-20%)
- dopo **throwUp**: light (0-40%), lightUp (0-100%), lightDown (0-40%), heavy (0-80%), heavyUp (0-80%), heavyDown (0-80%), specialNeutral (0-100%), specialSide (0-110%), grab (0-40%), lightAir (10-80, 100%), heavyAir (10-110%), recovery (10-120%)
- dopo **throwDown**: light (0-100%), lightDown (0-100%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-100%), lightUp (0-150%), lightAir (20-150%), heavyAir (20-150%), recovery (20-150%)

## Catene che non finiscono mai

Nessuna: nessuna coppia continua a legare oltre 12 colpi.

## Clip che servono

Mosse senza disegno proprio che, disegnate, chiuderebbero queste combo (già vere per la fisica):

- **dashAttack** (oggi usa heavy), 1 combo:
  - lightAir → dashAttack a 80-90%
