# Combo di Marcomunista

Generato da `npm run combo-lab -- marcomunista` (issue #594): non modificare a mano, rilancia il laboratorio.

Il laboratorio usa la fisica vera: la prima mossa colpisce un Bonobo fermo, poi Marcomunista insegue e prova la mossa dopo a ogni tick. **Vera** = entra mentre il bersaglio è ancora stordito, qualunque cosa faccia (fermo, spingendo via o verso di lui, rialzandosi al volo). Le percentuali sono quelle del bersaglio prima del primo colpo, da 0 a 150 a passi di 10.

## Combo del personaggio

- **Slancio rivoluzionario**: heavyUp → recovery. Vera a 10-50%. Entra solo se il bersaglio non reagisce a 0, 60-90%.
- **Falce e martello**: light → lightAir. Vera a 80-130%. Entra solo se il bersaglio non reagisce a 0-70, 140-150%.
- **Sol dell'avvenire**: lightAir → lightUp → recovery. Vera a 30-120%. Entra solo se il bersaglio non reagisce a 130-150%.
- **Cappellata**: light → lightDown → specialNeutral. Vera a 10-20%. Entra solo se il bersaglio non reagisce a 0, 30-140%.
- **Mongolfiera**: lightAir → lightAir. Vera a 50-120%. Entra solo se il bersaglio non reagisce a 0-40, 130-150%.

## Combo note

Le combo che c'erano già (la combo di leggeri e quella di #557), riprovate dal laboratorio.

- **Combo di leggeri (jab)**: light → light → light. Mai vera. Entra solo se il bersaglio non reagisce a 0-120%.
- **Piano quinquennale**: throwUp → lightAir → lightAir → heavyAir. Mai vera. Entra solo se il bersaglio non reagisce a 10-100%.
- **Piano quinquennale**: heavyUp → lightAir → lightAir → heavyAir. Mai vera. Entra solo se il bersaglio non reagisce a 30-50%.
- **Piano quinquennale**: throwDown → lightAir → lightAir → heavyAir. Mai vera. Entra solo se il bersaglio non reagisce a 20-140%.

## Mosse disegnate

| Mossa | Fotogrammi | Fotogramma del colpo |
|---|---|---|
| light | 16 | 6 |
| lightUp | 16 | 1 |
| lightDown | 16 | 1 |
| lightAir | 16 | 10 |
| heavy | 16 | 5 |
| heavyUp | 16 | 8 |
| heavyDown | 16 | 6 |
| heavyAir | 16 | 2 |
| dashAttack | 15 | 10 |
| recovery | 20 | 9 |
| specialNeutral | 16 | 9 |
| specialSide | 17 | 7 |
| grab | 16 | 9 |
| throw | 15 | 6 |

Tutte le mosse del laboratorio hanno il loro disegno.

## Coppie che legano

Solo con mosse già disegnate. La seconda mossa prende per forza dopo la prima.

| Prima | Dopo | Vera a % | Solo se non reagisce a % |
|---|---|---|---|
| light | light | 0-70 | 80-150 |
| light | lightDown | 0-20 | 30-140 |
| light | specialNeutral | 120-140 | 0-110, 150 |
| light | recovery | 0-60 | 70-150 |
| light | lightAir | 80-130 | 0-70, 140-150 |
| light | lightUp | 120-130 | 30-110, 140-150 |
| lightAir | recovery | 0-130 | 140-150 |
| lightAir | lightDown | 30-60 | 0-20, 70-150 |
| lightAir | lightAir | 50-120 | 0-40, 130-150 |
| lightAir | lightUp | 30-140 | 150 |
| heavyUp | recovery | 10-50 | 0, 60-90 |

### Il bersaglio fa in tempo a scappare

La seconda mossa arriva, ma il bersaglio non è più stordito o può uscirne.

- dopo **light**: heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), grab (0-140%), heavyAir (0-150%)
- dopo **lightDown**: light (0-150%), lightDown (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), grab (0-150%), lightAir (0-130%), heavyAir (0-150%), recovery (90-130%), dashAttack (120-150%)
- dopo **lightAir**: light (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), grab (0-150%), heavyAir (0-150%)
- dopo **heavy**: light (20-60%), heavy (20, 40%), heavyDown (20-60%), specialNeutral (20-90%), lightDown (20-50%), heavyUp (20-50%), grab (20-50%), heavyAir (20-40%), dashAttack (50-90%)
- dopo **heavyUp**: light (20%), lightUp (20-80%), lightDown (20%), heavy (20-50%), heavyUp (20-50%), heavyDown (20-50%), heavyAir (20-80%), lightAir (30-70%), specialNeutral (50%)
- dopo **heavyDown**: light (30-80%), heavy (30-50%), heavyDown (30-70%), specialNeutral (30-110%), lightDown (30-70%), heavyUp (30-70%), grab (30-70%), heavyAir (30-60%), dashAttack (60-110%)
- dopo **heavyAir**: light (0-50%), lightDown (0-40%), heavy (0-70%), heavyUp (0-70%), heavyDown (0-70%), specialNeutral (0-140%), grab (0-40%), lightAir (0-90%), recovery (0-110%), heavyAir (0-100%), lightUp (20-100%)
- dopo **dashAttack**: light (50-110%), heavy (50-80%), heavyDown (50-100%), specialNeutral (50-110%), lightDown (50-100%), heavyUp (50-90%), grab (50-90%), recovery (50%), heavyAir (50-80%), lightUp (70-90%), dashAttack (90-120%)
- dopo **specialNeutral**: light (0-150%), lightDown (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), grab (0-150%), recovery (0-140%), heavyAir (0-150%), lightAir (100%), lightUp (110-150%), dashAttack (150%)
- dopo **throwForward**: light (0-50%), specialNeutral (0-100%), heavy (0-10%), heavyDown (0-40%), dashAttack (0-90%), lightDown (0-30%), heavyUp (0-30%), grab (0-20%), lightAir (0-30%), heavyAir (0-40%)
- dopo **throwBack**: light (0-80%), lightDown (0-70%), heavy (0-40%), heavyUp (0-70%), heavyDown (0-70%), specialNeutral (0-110%), grab (0-70%), lightAir (0-40%), heavyAir (0-60%), recovery (0-20%), dashAttack (20-110%), lightUp (40%)
- dopo **throwUp**: light (0-50%), lightDown (0-40%), heavy (0-80%), heavyUp (0-80%), heavyDown (0-80%), specialNeutral (0-140%), grab (0-40%), lightUp (10-110%), heavyAir (10-110%), recovery (10-120%), lightAir (10-100%)
- dopo **throwDown**: light (0-110%), lightDown (0-90%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), grab (0-100%), dashAttack (20-80%), lightAir (20-150%), heavyAir (20-150%), recovery (20-150%), lightUp (40-150%)

## Catene che non finiscono mai

Nessuna: nessuna coppia continua a legare oltre 12 colpi.

## Clip che servono

Nessuna: tutte le mosse del laboratorio sono disegnate.
