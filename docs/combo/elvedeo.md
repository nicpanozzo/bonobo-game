# Combo di Elvedeo

Generato da `npm run combo-lab -- elvedeo` (issue #594): non modificare a mano, rilancia il laboratorio.

Il laboratorio usa la fisica vera: la prima mossa colpisce un Bonobo fermo, poi Elvedeo insegue e prova la mossa dopo a ogni tick. **Vera** = entra mentre il bersaglio è ancora stordito, qualunque cosa faccia (fermo, spingendo via o verso di lui, rialzandosi al volo). Le percentuali sono quelle del bersaglio prima del primo colpo, da 0 a 150 a passi di 10.

## Combo del personaggio

- **Zoccolata**: heavyAir → light. Vera a 50-120%. Entra solo se il bersaglio non reagisce a 0-40, 130-150%.
- **Salto della capra**: light → lightAir. Vera a 80-110%. Entra solo se il bersaglio non reagisce a 0-70, 120-150%.
- **Carica della capra**: heavyAir → lightDown → specialSide. Vera a 60-120%. Entra solo se il bersaglio non reagisce a 0-50, 130-150%.

## Combo note

Le combo che c'erano già (la combo di leggeri e quella di #557), riprovate dal laboratorio.

- **Combo di leggeri (jab)**: light → light → light. Mai vera. Entra solo se il bersaglio non reagisce a 0-120%.

## Mosse disegnate

| Mossa | Fotogrammi | Fotogramma del colpo |
|---|---|---|
| light | 9 | 4 |
| lightUp | 7 | 3 |
| lightDown | 9 | 4 |
| lightAir | 8 | 3 |
| heavy | 11 | 5 |
| heavyUp | 9 | 3 |
| heavyDown | 12 | 3 |
| heavyAir | 15 | 12 |
| recovery | 12 | 3 |
| specialNeutral | 10 | 5 |
| specialSide | 16 | 3 |
| specialDown | 13 | 4 |
| grab | 7 | 3 |
| throw | 7 | 4 |

Senza disegno proprio: dashAttack (usa heavy).

## Coppie che legano

Solo con mosse già disegnate. La seconda mossa prende per forza dopo la prima.

| Prima | Dopo | Vera a % | Solo se non reagisce a % |
|---|---|---|---|
| light | light | 0-70 | 80-150 |
| light | lightAir | 80-110 | 0-70, 120-150 |
| light | recovery | 0-60 | 70-150 |
| heavyAir | light | 50-120 | 0-40, 130-150 |
| heavyAir | lightDown | 60-120 | 0-50, 130-150 |
| heavyAir | lightUp | 90-120 | 0-80, 130-150 |
| heavyAir | lightAir | 60-120 | 0-50, 130-150 |
| heavyAir | heavyAir | 110-120 | 0-100, 130-150 |
| specialNeutral | light | 130-150 | 0-120 |
| specialNeutral | lightDown | 120-130 | 0-110, 140-150 |
| specialNeutral | recovery | 100 | 0-90, 110 |

### Il bersaglio fa in tempo a scappare

La seconda mossa arriva, ma il bersaglio non è più stordito o può uscirne.

- dopo **light**: lightUp (0-150%), lightDown (0-140%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-140%), heavyAir (0-150%), specialDown (20, 70-150%)
- dopo **lightAir**: heavy (0-130%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), light (0-150%), heavyDown (0-150%), lightDown (0-150%), lightUp (0-150%), heavyUp (0-150%), lightAir (0-80%), heavyAir (0-130%), recovery (0-70%), specialDown (0-30, 70-80, 100-110, 130-140%)
- dopo **heavy**: specialNeutral (20-110%), specialSide (20-110%), light (20-50%), lightUp (20-40%), lightDown (20-50%), heavy (20, 40%), heavyUp (20-40%), heavyDown (20-50%), grab (20-50%), heavyAir (20-30%), specialDown (40%)
- dopo **heavyDown**: specialNeutral (30-130%), specialSide (30-130%), light (30-70%), lightUp (30-60%), lightDown (30-60%), heavy (30-50%), heavyUp (30-60%), heavyDown (30-70%), grab (30-70%), heavyAir (30-50%)
- dopo **heavyAir**: specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), heavy (0-150%), heavyDown (0-150%), heavyUp (0-150%), specialDown (0-80, 110, 130-140%), recovery (0-110%)
- dopo **specialNeutral**: lightUp (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-150%), heavyAir (0-150%), lightAir (0-150%), specialDown (30, 60-100, 120-150%)
- dopo **throwForward**: specialNeutral (0-130%), specialSide (0-120%), light (0-20%), heavyDown (0-10%), grab (0-20%), lightAir (0-20%), heavyAir (0-40%)
- dopo **throwBack**: light (0-70%), lightUp (0-60%), lightDown (0-60%), heavy (0-30%), heavyUp (0-60%), heavyDown (0-60%), specialNeutral (0-130%), specialSide (0-120%), grab (0-70%), lightAir (0-40%), heavyAir (0-60%), recovery (0-20%), specialDown (0-10, 30%)
- dopo **throwUp**: light (0-40%), heavy (0-80%), heavyDown (0-80%), specialNeutral (0-120%), specialSide (0-100%), grab (0-40%), lightDown (0-40%), lightUp (0-100%), heavyUp (0-80%), specialDown (10-70%), heavyAir (10-100%), recovery (10-120%), lightAir (10-90%)
- dopo **throwDown**: heavy (0-150%), specialNeutral (0-150%), specialSide (0-150%), grab (0-100%), light (0-100%), heavyDown (0-150%), lightUp (0-140%), lightDown (0-100%), heavyUp (0-150%), lightAir (20-150%), heavyAir (20-150%), recovery (20-150%), specialDown (40, 70-80%)

## Catene che non finiscono mai

Nessuna: nessuna coppia continua a legare oltre 12 colpi.

## Clip che servono

Mosse senza disegno proprio che, disegnate, chiuderebbero queste combo (già vere per la fisica):

- **dashAttack** (oggi usa heavy), 1 combo:
  - heavyAir → dashAttack a 50-120%
