# Combo di Electronmaster

Generato da `npm run combo-lab -- coachcartier` (issue #594): non modificare a mano, rilancia il laboratorio.

Il laboratorio usa la fisica vera: la prima mossa colpisce un Bonobo fermo, poi Electronmaster insegue e prova la mossa dopo a ogni tick. **Vera** = entra mentre il bersaglio è ancora stordito, qualunque cosa faccia (fermo, spingendo via o verso di lui, rialzandosi al volo). Le percentuali sono quelle del bersaglio prima del primo colpo, da 0 a 150 a passi di 10.

## Combo del personaggio

- **Schema alla lavagna**: light → lightDown → specialSide. Vera a 0-70%. Entra solo se il bersaglio non reagisce a 80-150%.
- **Cashback**: light → lightDown → specialNeutral. Vera a 0-70%. Entra solo se il bersaglio non reagisce a 80-150%.
- **Esercizio**: heavyUp → lightUp. Vera a 10-30%. Entra solo se il bersaglio non reagisce a 0, 40-70%.

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
| heavyUp | lightUp | 10-30 | 0, 40-70 |
| heavyUp | recovery | 10-50 | 0, 60-90 |
| specialSide | light | 100-150 | 0-90 |
| specialSide | lightUp | 150 | 0-140 |
| specialSide | lightDown | 100-150 | 0-90 |

### Il bersaglio fa in tempo a scappare

La seconda mossa arriva, ma il bersaglio non è più stordito o può uscirne.

- dopo **light**: lightUp (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), lightAir (0-150%), heavyAir (0-150%)
- dopo **lightDown**: light (0-150%), lightUp (0-150%), lightDown (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), lightAir (0-120%), recovery (0-110%), heavyAir (0-150%)
- dopo **lightAir**: light (0-150%), lightDown (0-150%), heavy (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), heavyUp (0-150%), lightUp (0-150%), lightAir (0-90%), heavyAir (0-130%), recovery (0-70%)
- dopo **heavy**: light (20-80%), lightDown (20-80%), heavy (20-60%), heavyDown (20-80%), specialNeutral (20-70%), specialSide (20-110%), grab (20-70%), lightUp (20-70%), heavyUp (20-70%), heavyAir (20-30%)
- dopo **heavyUp**: light (20%), lightDown (20%), heavy (20-50%), heavyUp (20-50%), heavyDown (20-50%), specialNeutral (20-90%), specialSide (20-70%), heavyAir (20-70%), lightAir (30-70%)
- dopo **heavyDown**: light (30-100%), lightDown (30-100%), heavy (30-80%), heavyUp (30-90%), heavyDown (30-100%), specialNeutral (30-90%), specialSide (30-130%), grab (30-40, 60-90%), lightUp (30-90%), heavyAir (30-50%)
- dopo **heavyAir**: specialSide (0-110%), lightDown (0-70%), heavyDown (0-70%), light (0-70%), heavy (0-50%), specialNeutral (0-60%), grab (0-60%), heavyUp (0-60%), lightUp (0-60%), lightAir (0-20%), heavyAir (0-30%), recovery (0%)
- dopo **specialSide**: heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), recovery (0-70%), heavyAir (0-140%), lightAir (0-140%)
- dopo **throwForward**: specialSide (0-140%), heavyDown (0-60%), light (0-60%), lightDown (0-60%), specialNeutral (0-60%), heavyUp (0-40%), grab (0-50%), lightUp (0-40%), lightAir (0-20%), heavyAir (0-30%)
- dopo **throwBack**: light (0-90%), lightUp (0-80%), lightDown (0-90%), heavy (0-70%), heavyUp (0-80%), heavyDown (0-90%), specialNeutral (0-90%), specialSide (0-120%), grab (0-90%), lightAir (0-40%), heavyAir (0-50%), recovery (0-20%)
- dopo **throwUp**: light (0-50%), lightUp (0-100%), lightDown (0-40%), heavy (0-80%), heavyUp (0-80%), heavyDown (0-80%), specialNeutral (0-120%), specialSide (0-100%), grab (0-40%), lightAir (10-90%), heavyAir (10-110%), recovery (10-120%)
- dopo **throwDown**: light (0-110%), lightDown (0-100%), heavy (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-100%), heavyUp (0-150%), lightUp (0-140%), lightAir (20-150%), heavyAir (20-150%), recovery (20-120%)

## Catene che non finiscono mai

Nessuna: nessuna coppia continua a legare oltre 12 colpi.

## Clip che servono

Nessuna clip mancante chiuderebbe una combo vera in più.
