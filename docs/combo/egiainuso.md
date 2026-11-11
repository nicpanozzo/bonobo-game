# Combo di Egiainuso

Generato da `npm run combo-lab -- egiainuso` (issue #594): non modificare a mano, rilancia il laboratorio.

Il laboratorio usa la fisica vera: la prima mossa colpisce un Bonobo fermo, poi Egiainuso insegue e prova la mossa dopo a ogni tick. **Vera** = entra mentre il bersaglio è ancora stordito, qualunque cosa faccia (fermo, spingendo via o verso di lui, rialzandosi al volo). Le percentuali sono quelle del bersaglio prima del primo colpo, da 0 a 150 a passi di 10.

## Combo del personaggio

- **Rincorsa**: light → dashAttack. Vera a 70%. Entra solo se il bersaglio non reagisce a 10-60, 80-150%.
- **Travolgente**: heavy → dashAttack. Vera a 10-20%. Entra solo se il bersaglio non reagisce a 0, 30-90%.
- **Tuffo e carica**: lightAir → dashAttack. Vera a 80-100%. Entra solo se il bersaglio non reagisce a 0-70, 110-150%.
- **Sputo in faccia**: light → lightDown → specialNeutral. Vera a 0-50, 70%. Entra solo se il bersaglio non reagisce a 60, 80-150%.

## Combo note

Le combo che c'erano già (la combo di leggeri e quella di #557), riprovate dal laboratorio.

- **Combo di leggeri (jab)**: light → light → light. Vera a 0-70%. Entra solo se il bersaglio non reagisce a 80-150%.

## Mosse disegnate

| Mossa | Fotogrammi | Fotogramma del colpo |
|---|---|---|
| light | 15 | 4 |
| lightUp | 11 | 2 |
| lightDown | 19 | 7 |
| lightAir | 17 | 14 |
| heavy | 16 | 7 |
| heavyUp | 19 | 10 |
| heavyDown | 11 | 3 |
| heavyAir | 12 | 3 |
| dashAttack | 17 | 6 |
| recovery | 12 | 1 |
| specialNeutral | 10 | 5 |
| specialSide | 12 | 4 |
| grab | 5 | 1 |
| throw | 15 | 6 |

Tutte le mosse del laboratorio hanno il loro disegno.

## Coppie che legano

Solo con mosse già disegnate. La seconda mossa prende per forza dopo la prima.

| Prima | Dopo | Vera a % | Solo se non reagisce a % |
|---|---|---|---|
| light | light | 0-70 | 80-150 |
| light | lightDown | 0-50, 70 | 60, 80-150 |
| light | recovery | 0-70 | 80-150 |
| light | dashAttack | 70 | 10-60, 80-150 |
| lightAir | dashAttack | 80-100 | 0-70, 110-150 |
| heavy | dashAttack | 10-20 | 0, 30-90 |
| specialNeutral | light | 140-150 | 0-130 |
| specialNeutral | lightDown | 130-150 | 0-120 |
| specialNeutral | recovery | 110-120 | 0-100 |

### Il bersaglio fa in tempo a scappare

La seconda mossa arriva, ma il bersaglio non è più stordito o può uscirne.

- dopo **light**: lightUp (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), lightAir (0-150%), heavyAir (0-150%)
- dopo **lightAir**: heavy (0-140%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), light (0-150%), lightUp (0-150%), lightDown (0-150%), lightAir (0-90%), heavyAir (0-140%), recovery (0-80%)
- dopo **heavy**: recovery (0-10%), heavy (20-40%), specialNeutral (20-110%), specialSide (20-100%), light (20-50%), lightUp (20-50%), lightDown (20-50%), heavyUp (20-60%), heavyDown (20-60%), grab (20-60%), heavyAir (20-30%)
- dopo **heavyUp**: lightUp (30-70%), heavy (30-50%), heavyUp (30-50%), heavyDown (30-50%), specialNeutral (30-40, 60%), lightAir (30-70%), heavyAir (30-70%), recovery (30-90%)
- dopo **heavyDown**: heavy (30-60%), specialNeutral (30-130%), specialSide (30-120%), light (30-70%), lightUp (30-70%), lightDown (30-70%), heavyUp (30-70%), heavyDown (30-70%), grab (30-70%), heavyAir (30-50%), dashAttack (60-110%)
- dopo **heavyAir**: specialNeutral (0-110%), specialSide (0-100%), heavy (0-20%), grab (0-50%), heavyUp (0-50%), heavyDown (0-50%), light (0-50%), dashAttack (0-90%), lightUp (0-40%), lightDown (0-40%), lightAir (0-20%), heavyAir (0-40%)
- dopo **dashAttack**: heavy (50-90%), specialNeutral (50-110%), specialSide (50-120%), light (50-100%), lightUp (50-90%), lightDown (50-90%), heavyUp (50-100%), heavyDown (50-100%), grab (50-100%), heavyAir (50-70%), dashAttack (90-120%)
- dopo **specialNeutral**: lightUp (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), heavyAir (0-150%), lightAir (0-150%), dashAttack (150%)
- dopo **specialSide**: specialNeutral (70-150%), specialSide (70-130%), dashAttack (80-120%), heavyAir (90%)
- dopo **throwForward**: specialNeutral (0-140%), specialSide (0-110%), heavy (0-10%), dashAttack (0-100%), heavyUp (0-30%), heavyDown (0-30%), grab (0-30%), light (0-20%), lightUp (0-10%), lightAir (0-20%), heavyAir (0-40%)
- dopo **throwBack**: light (0-70%), lightUp (0-60%), lightDown (0-60%), heavy (0-40%), heavyUp (0-70%), heavyDown (0-70%), specialSide (0-120%), specialNeutral (0-120%), grab (0-70%), lightAir (0-40%), heavyAir (0-60%), recovery (0-20%), dashAttack (20-110%)
- dopo **throwUp**: light (0-40%), heavy (0-80%), heavyUp (0-80%), heavyDown (0-80%), specialNeutral (0-100%), specialSide (0-70%), grab (0-40%), lightUp (0-90%), lightDown (0-40%), lightAir (10-90%), heavyAir (10-100%), recovery (10-120%)
- dopo **throwDown**: heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-100%), light (0-100%), lightUp (0-150%), lightDown (0-90%), dashAttack (20-70%), lightAir (20-150%), heavyAir (20-150%), recovery (20-150%)

## Catene che non finiscono mai

Nessuna: nessuna coppia continua a legare oltre 12 colpi.

## Clip che servono

Nessuna: tutte le mosse del laboratorio sono disegnate.
