# Combo di Lendmar

Generato da `npm run combo-lab -- lendmar` (issue #594): non modificare a mano, rilancia il laboratorio.

Il laboratorio usa la fisica vera: la prima mossa colpisce un Bonobo fermo, poi Lendmar insegue e prova la mossa dopo a ogni tick. **Vera** = entra mentre il bersaglio è ancora stordito, qualunque cosa faccia (fermo, spingendo via o verso di lui, rialzandosi al volo). Le percentuali sono quelle del bersaglio prima del primo colpo, da 0 a 150 a passi di 10.

## Combo del personaggio

- **Sbrocco**: light → lightDown → specialSide. Vera a 0-70%. Entra solo se il bersaglio non reagisce a 80-150%.
- **Fai schifo**: light → lightDown → specialNeutral. Vera a 0-70%. Entra solo se il bersaglio non reagisce a 80-150%.
- **Testata**: lightUp → lightUp → recovery. Vera a 60-120%. Entra solo se il bersaglio non reagisce a 0-50, 130-150%.
- **Calcio in culo**: heavyUp → lightUp. Vera a 10-30%. Entra solo se il bersaglio non reagisce a 0, 40-70%.

## Combo note

Le combo che c'erano già (la combo di leggeri e quella di #557), riprovate dal laboratorio.

- **Combo di leggeri (jab)**: light → light → light. Vera a 0-70%. Entra solo se il bersaglio non reagisce a 80-150%.

## Mosse disegnate

| Mossa | Fotogrammi | Fotogramma del colpo |
|---|---|---|
| light | 16 | 3 |
| lightUp | 8 | 2 |
| lightDown | 8 | 2 |
| lightAir | 8 | 2 |
| heavy | 22 | 9 |
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
| light | recovery | 0-70 | 80-150 |
| lightUp | lightUp | 60-150 | 0-50 |
| lightUp | recovery | 70-150 | 0-60 |
| lightUp | lightAir | 120 | 0-110, 130-150 |
| heavyUp | lightUp | 10-30 | 0, 40-70 |
| heavyUp | recovery | 10-50 | 0, 60-90 |
| specialNeutral | light | 140-150 | 0-130 |
| specialNeutral | lightUp | 150 | 0-140 |
| specialNeutral | recovery | 110-150 | 0-100 |

### Il bersaglio fa in tempo a scappare

La seconda mossa arriva, ma il bersaglio non è più stordito o può uscirne.

- dopo **light**: lightUp (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), lightAir (0-150%), heavyAir (0-150%)
- dopo **lightUp**: light (0-130%), lightDown (0-110%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-110%), heavyAir (0-150%)
- dopo **lightDown**: light (0-150%), lightUp (0-150%), lightDown (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), lightAir (0-130%), heavyAir (0-150%), recovery (60-120%)
- dopo **lightAir**: light (0-150%), lightDown (0-150%), heavy (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), heavyUp (0-150%), lightUp (0-150%), heavyAir (0-140%), recovery (0-80%), lightAir (0-90%)
- dopo **heavy**: heavyDown (20-60%), specialNeutral (20-110%), specialSide (20-110%), light (20-60%), lightUp (20-60%), lightDown (20-60%), heavyUp (20-60%), heavyAir (20-40%), grab (30-60%), heavy (40-50%)
- dopo **heavyUp**: light (20-30%), lightDown (20%), heavy (20-50%), heavyUp (20-50%), heavyDown (20-50%), specialNeutral (20-70%), specialSide (20-30, 60-70%), heavyAir (20-70%), lightAir (30-70%)
- dopo **heavyDown**: lightDown (30-80%), heavyDown (30-80%), specialNeutral (30-130%), specialSide (30-130%), light (30-80%), lightUp (30-70%), heavy (30-60%), heavyUp (30-80%), heavyAir (30-50%), grab (40-80%)
- dopo **heavyAir**: specialSide (0-110%), specialNeutral (0-120%), heavyDown (0-60%), lightDown (0-60%), light (0-50%), heavy (0-40%), grab (0-50%), heavyUp (0-50%), lightUp (0-50%), lightAir (0-20%), heavyAir (0-40%)
- dopo **specialNeutral**: lightDown (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), heavyAir (0-150%), lightAir (10-150%)
- dopo **throwForward**: specialSide (0-130%), specialNeutral (0-130%), lightDown (0-40%), heavyDown (0-40%), light (0-40%), heavyUp (0-40%), grab (0-40%), lightUp (0-30%), lightAir (0-30%), heavyAir (0-40%)
- dopo **throwBack**: light (0-80%), lightUp (0-70%), lightDown (0-80%), heavy (0-40%), heavyUp (0-70%), heavyDown (0-80%), specialSide (0-120%), specialNeutral (0-130%), grab (0-70%), lightAir (0-40%), heavyAir (0-60%), recovery (0-20%)
- dopo **throwUp**: light (0-50%), lightUp (0-100%), lightDown (0-40%), heavy (0-80%), heavyUp (0-80%), heavyDown (0-80%), specialNeutral (0-100%), specialSide (0-90%), grab (0-40%), lightAir (10-100%), heavyAir (10-110%), recovery (10-120%)
- dopo **throwDown**: light (0-110%), lightDown (0-100%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-100%), lightUp (0-150%), lightAir (20-150%), heavyAir (20-150%), recovery (20-150%)

## Catene che non finiscono mai

Nessuna: nessuna coppia continua a legare oltre 12 colpi.

## Clip che servono

Nessuna clip mancante chiuderebbe una combo vera in più.
