# Combo di Giovanni fRana

Generato da `npm run combo-lab -- giovannifrana` (issue #594): non modificare a mano, rilancia il laboratorio.

Il laboratorio usa la fisica vera: la prima mossa colpisce un Bonobo fermo, poi Giovanni fRana insegue e prova la mossa dopo a ogni tick. **Vera** = entra mentre il bersaglio è ancora stordito, qualunque cosa faccia (fermo, spingendo via o verso di lui, rialzandosi al volo). Le percentuali sono quelle del bersaglio prima del primo colpo, da 0 a 150 a passi di 10.

## Combo del personaggio

- **Contropiede**: light → lightDown → specialSide. Vera a 0-70%. Entra solo se il bersaglio non reagisce a 80-150%.
- **Tackle e rigore**: light → lightDown → specialNeutral. Vera a 0-70%. Entra solo se il bersaglio non reagisce a 80-150%.
- **Palleggio**: lightUp → lightUp → lightAir. Vera a 60-80%. Entra solo se il bersaglio non reagisce a 0-50, 90-150%.

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
| lightUp | lightUp | 60-130 | 0-50, 140-150 |
| lightUp | recovery | 70-150 | 0-60 |
| specialNeutral | light | 120-150 | 0-110 |
| specialNeutral | lightUp | 120-140 | 0-110, 150 |

### Il bersaglio fa in tempo a scappare

La seconda mossa arriva, ma il bersaglio non è più stordito o può uscirne.

- dopo **light**: lightUp (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), lightAir (0-150%), heavyAir (0-150%)
- dopo **lightUp**: light (0-120%), lightDown (0-110%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-110%), lightAir (0-150%), heavyAir (0-150%)
- dopo **lightDown**: light (0-150%), lightUp (0-150%), lightDown (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), lightAir (0-150%), recovery (0-110%), heavyAir (0-150%)
- dopo **lightAir**: light (0-150%), lightDown (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), lightUp (0-150%), recovery (0-70%), lightAir (0-80, 110-120%), heavyAir (0-120%)
- dopo **heavy**: light (20-70%), lightDown (20-70%), heavyDown (20-70%), specialNeutral (20-110%), specialSide (20-110%), lightUp (20-60%), heavy (20, 40-50%), heavyUp (20-60%), grab (20-60%), heavyAir (20-30%), lightAir (30%)
- dopo **heavyUp**: lightUp (30-60%), heavy (30-50%), heavyUp (30-50%), heavyDown (30-50%), specialNeutral (30-60%), lightAir (30-60%), heavyAir (30-60%), recovery (30-80%), specialSide (50%)
- dopo **heavyDown**: light (30-80%), lightDown (30-90%), heavyDown (30-90%), specialNeutral (30-130%), specialSide (30-130%), grab (30, 50-80%), lightUp (30-80%), heavy (30-70%), heavyUp (30-80%), heavyAir (30-40%), lightAir (40%)
- dopo **heavyAir**: specialNeutral (0-120%), specialSide (0-110%), lightDown (0-60%), heavyDown (0-60%), light (0-60%), heavy (0-40%), grab (0-60%), heavyUp (0-60%), lightUp (0-50%), lightAir (0-10%), heavyAir (0-30%), recovery (0%)
- dopo **specialNeutral**: lightDown (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), heavyAir (0-110%), lightAir (0-110%), recovery (80-100%)
- dopo **specialSide**: specialNeutral (130-150%)
- dopo **throwForward**: specialNeutral (0-140%), specialSide (0-130%), light (0-40%), lightDown (0-50%), heavyDown (0-50%), heavyUp (0-40%), grab (0-40%), lightUp (0-40%), lightAir (0-20%), heavyAir (0-40%)
- dopo **throwBack**: light (0-80%), lightUp (0-80%), lightDown (0-80%), heavy (0-50, 70%), heavyUp (0-80%), heavyDown (0-80%), specialSide (0-120%), specialNeutral (0-120%), grab (0-80%), lightAir (0-40%), heavyAir (0-60%), recovery (0-20%)
- dopo **throwUp**: light (0-50%), lightUp (0-90%), lightDown (0-40%), heavy (0-80%), heavyUp (0-80%), heavyDown (0-80%), specialNeutral (0-100%), specialSide (0-60, 80%), grab (0-40%), lightAir (10-90%), heavyAir (10-100%), recovery (10-110%)
- dopo **throwDown**: light (0-110%), lightDown (0-100%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-100%), lightUp (0-150%), lightAir (20-150%), heavyAir (20-150%), recovery (20-150%)

## Catene che non finiscono mai

Nessuna: nessuna coppia continua a legare oltre 12 colpi.

## Clip che servono

Nessuna clip mancante chiuderebbe una combo vera in più.
