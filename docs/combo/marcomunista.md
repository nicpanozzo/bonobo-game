# Combo di Marcomunista

Generato da `npm run combo-lab -- marcomunista` (issue #594): non modificare a mano, rilancia il laboratorio.

Il laboratorio usa la fisica vera: la prima mossa colpisce un Bonobo fermo, poi Marcomunista insegue e prova la mossa dopo a ogni tick. **Vera** = entra mentre il bersaglio è ancora stordito, qualunque cosa faccia (fermo, spingendo via o verso di lui, rialzandosi al volo). Le percentuali sono quelle del bersaglio prima del primo colpo, da 0 a 150 a passi di 10.

## Combo del personaggio

- **Slancio rivoluzionario**: heavyUp → recovery. Vera a 10-50%. Entra solo se il bersaglio non reagisce a 0, 60-90%.
- **Falce e martello**: light → lightAir. Vera a 80-130%. Entra solo se il bersaglio non reagisce a 0-70, 140-150%.

## Combo note

Le combo che c'erano già (la combo di leggeri e quella di #557), riprovate dal laboratorio.

- **Combo di leggeri (jab)**: light → light → light. Mai vera. Entra solo se il bersaglio non reagisce a 0-120%.
- **Piano quinquennale**: throwUp → lightAir → lightAir → heavyAir. Mai vera. Entra solo se il bersaglio non reagisce a 40-50%.
- **Piano quinquennale**: throwDown → lightAir → lightAir → heavyAir. Mai vera. Entra solo se il bersaglio non reagisce a 40-120%.

## Mosse disegnate

| Mossa | Fotogrammi | Fotogramma del colpo |
|---|---|---|
| light | 5 | 2 |
| lightUp | 6 | 3 |
| lightDown | 5 | 2 |
| lightAir | 4 | 1 |
| heavy | 11 | 5 |
| heavyUp | 6 | 4 |
| heavyDown | 7 | 3 |
| heavyAir | 6 | 3 |
| recovery | 4 | 0 |
| specialNeutral | 8 | 5 |
| grab | 3 | 2 |
| throw | 4 | 0 |

Senza disegno proprio: dashAttack (usa heavy), specialSide (usa heavy).

## Coppie che legano

Solo con mosse già disegnate. La seconda mossa prende per forza dopo la prima.

| Prima | Dopo | Vera a % | Solo se non reagisce a % |
|---|---|---|---|
| light | light | 40-70 | 0-30, 80-150 |
| light | lightAir | 80-130 | 0-70, 140-150 |
| light | recovery | 60 | 0-50, 70-150 |
| heavyUp | recovery | 10-50 | 0, 60-90 |
| specialNeutral | light | 140-150 | 0-130 |
| specialNeutral | lightDown | 140-150 | 0-130 |
| specialNeutral | lightAir | 130-150 | 0-120 |
| specialNeutral | recovery | 100-130 | 0-90 |

### Il bersaglio fa in tempo a scappare

La seconda mossa arriva, ma il bersaglio non è più stordito o può uscirne.

- dopo **light**: lightUp (0-150%), lightDown (0-140%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), grab (0-140%), heavyAir (0-150%)
- dopo **lightDown**: light (0-150%), lightUp (0-150%), lightDown (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), grab (0-150%), lightAir (0-130%), heavyAir (0-150%), recovery (90-130%)
- dopo **lightAir**: light (0-150%), lightUp (0-150%), lightDown (0-150%), heavy (0-100%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), grab (0-150%), lightAir (0-120%), heavyAir (0-150%), recovery (0-70%)
- dopo **heavy**: specialNeutral (20-110%), light (20-50%), lightUp (20-50%), lightDown (20-50%), heavy (20, 40%), heavyUp (20-50%), heavyDown (20-50%), grab (20-50%), heavyAir (20-40%)
- dopo **heavyUp**: light (20%), lightUp (20-70%), lightDown (20%), heavy (20-50%), heavyUp (20-50%), heavyDown (20-50%), specialNeutral (20-40, 70%), heavyAir (20-80%), lightAir (30-70%)
- dopo **heavyDown**: specialNeutral (30-130%), light (30-70%), lightUp (30-60%), lightDown (30-70%), heavy (30-50%), heavyUp (30-70%), heavyDown (30-70%), grab (30-70%), heavyAir (30-60%)
- dopo **heavyAir**: specialNeutral (30-110%), light (30-50%), lightUp (30-50%), lightDown (30-50%), heavyUp (30-50%), heavyDown (30-50%), grab (30-50%), lightAir (30%), heavyAir (30-50%)
- dopo **specialNeutral**: lightUp (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), grab (0-150%), heavyAir (0-150%)
- dopo **throwForward**: specialNeutral (0-140%), light (0-20%), lightDown (0-10%), heavyUp (0-10%), heavyDown (0-10%), grab (0-20%), lightUp (0-10%), lightAir (0-30%), heavyAir (0-40%)
- dopo **throwBack**: light (0-70%), lightUp (0-60%), lightDown (0-60%), heavy (0-30%), heavyUp (0-60%), heavyDown (0-60%), specialNeutral (0-120%), grab (0-70%), lightAir (0-40%), heavyAir (0-60%), recovery (0-20%)
- dopo **throwUp**: light (0-50%), lightDown (0-40%), heavy (0-80%), heavyUp (0-80%), heavyDown (0-80%), specialNeutral (0-110%), grab (0-40%), lightUp (0-100%), heavyAir (10-110%), recovery (10-120%), lightAir (10-100%)
- dopo **throwDown**: light (0-110%), heavy (0-150%), specialNeutral (0-150%), grab (0-100%), heavyUp (0-150%), heavyDown (0-150%), lightDown (0-100%), lightUp (0-150%), lightAir (20-150%), heavyAir (20-150%), recovery (20-150%)

## Catene che non finiscono mai

Nessuna: nessuna coppia continua a legare oltre 12 colpi.

## Clip che servono

Nessuna clip mancante chiuderebbe una combo vera in più.
