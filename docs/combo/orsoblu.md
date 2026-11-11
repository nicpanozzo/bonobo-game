# Combo di Capt. OrsoBlu

Generato da `npm run combo-lab -- orsoblu` (issue #594): non modificare a mano, rilancia il laboratorio.

Il laboratorio usa la fisica vera: la prima mossa colpisce un Bonobo fermo, poi Capt. OrsoBlu insegue e prova la mossa dopo a ogni tick. **Vera** = entra mentre il bersaglio è ancora stordito, qualunque cosa faccia (fermo, spingendo via o verso di lui, rialzandosi al volo). Le percentuali sono quelle del bersaglio prima del primo colpo, da 0 a 150 a passi di 10.

## Combo del personaggio

- **Uomo in mare**: heavy → specialNeutral → light. Vera a 0-40%. Entra solo se il bersaglio non reagisce a 50-100%.
- **Issa la vela**: lightUp → lightUp. Vera a 60-140%. Entra solo se il bersaglio non reagisce a 0-50, 150%.
- **Bordata**: light → lightDown → specialSide. Vera a 0-70%. Entra solo se il bersaglio non reagisce a 80-150%.

## Combo note

Le combo che c'erano già (la combo di leggeri e quella di #557), riprovate dal laboratorio.

- **Combo di leggeri (jab)**: light → light → light. Vera a 0-70%. Entra solo se il bersaglio non reagisce a 80-150%.
- **Arrembaggio**: specialNeutral → light. Vera a 0-150%.
- **Arrembaggio**: specialNeutral → heavy. Mai vera. Entra solo se il bersaglio non reagisce a 0-150%.
- **Arrembaggio**: specialNeutral → specialSide. Vera a 0-150%.

## Mosse disegnate

| Mossa | Fotogrammi | Fotogramma del colpo |
|---|---|---|
| light | 13 | 3 |
| lightUp | 12 | 2 |
| lightDown | 14 | 5 |
| lightAir | 21 | 10 |
| heavy | 17 | 5 |
| heavyUp | 17 | 4 |
| heavyDown | 18 | 7 |
| heavyAir | 17 | 11 |
| specialNeutral | 17 | 2 |
| specialSide | 17 | 3 |

Senza disegno proprio: dashAttack (usa heavy), specialDown (usa heavy), grab (usa light), throw (usa light).

## Coppie che legano

Solo con mosse già disegnate. La seconda mossa prende per forza dopo la prima.

| Prima | Dopo | Vera a % | Solo se non reagisce a % |
|---|---|---|---|
| light | light | 0-70 | 80-150 |
| light | lightDown | 0-70 | 80-150 |
| lightUp | lightUp | 60-140 | 0-50, 150 |
| lightUp | lightAir | 120 | 0-110, 130-150 |
| lightAir | specialNeutral | 40-150 | 0-30 |
| heavy | specialNeutral | 0-60 | 70-100 |
| specialNeutral | light | 0-150 | - |
| specialNeutral | lightUp | 0-150 | - |
| specialNeutral | lightDown | 0-150 | - |
| specialNeutral | specialNeutral | 0-150 | - |
| specialNeutral | lightAir | 0-150 | - |
| specialNeutral | specialSide | 0-150 | - |

### Il bersaglio fa in tempo a scappare

La seconda mossa arriva, ma il bersaglio non è più stordito o può uscirne.

- dopo **light**: lightUp (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), lightAir (0-150%), heavyAir (0-150%)
- dopo **lightUp**: light (0-120%), lightDown (0-110%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), heavyAir (0-150%)
- dopo **lightDown**: light (0-150%), lightUp (0-150%), lightDown (0-150%), heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), specialNeutral (0-150%), specialSide (0-150%), lightAir (0-130%), heavyAir (0-150%)
- dopo **lightAir**: light (0-150%), lightUp (0-150%), heavy (0-120%), heavyDown (0-150%), specialSide (0-150%), lightDown (0-150%), heavyUp (0-150%), lightAir (0-90%), heavyAir (0-130%)
- dopo **heavy**: specialSide (20-90%), light (20-50%), lightUp (20-50%), lightDown (20-50%), heavy (20-30%), heavyUp (20-50%), heavyDown (20-50%), heavyAir (20-30%)
- dopo **heavyUp**: lightUp (30-70%), heavy (30-50%), heavyUp (30-50%), heavyDown (30-50%), lightAir (30-70%), heavyAir (30-70%), specialNeutral (30-50%), specialSide (40, 60%)
- dopo **heavyDown**: specialNeutral (30-120%), specialSide (30-110%), light (30-70%), lightUp (30-70%), lightDown (30-60%), heavy (30-50%), heavyUp (30-60%), heavyDown (30-70%), heavyAir (30-50%)
- dopo **heavyAir**: specialNeutral (0-100%), specialSide (0-90%), heavy (0-10%), light (0-40%), heavyDown (0-50%), lightUp (0-40%), lightDown (0-40%), heavyUp (0-40%), lightAir (0-20%), heavyAir (0-30%)
- dopo **specialNeutral**: heavy (0-150%), heavyUp (0-150%), heavyDown (0-150%), heavyAir (0-150%)
- dopo **specialSide**: specialNeutral (80-130%), specialSide (80-120%)

## Catene che non finiscono mai

- lightAir e specialNeutral (lightAir o specialNeutral per primo, da 30-40%): lega ancora dopo 12 colpi. Da sistemare.
- specialNeutral e specialNeutral (specialNeutral per primo, da 0-150%): lega ancora dopo 12 colpi. Da sistemare.

## Clip che servono

Mosse senza disegno proprio che, disegnate, chiuderebbero queste combo (già vere per la fisica):

- **specialDown** (oggi usa heavy), 5 combo:
  - specialDown → light a 0-20%
  - specialDown → lightUp a 10-150%
  - specialDown → specialNeutral a 0-30, 60-140%
  - specialDown → specialSide a 110-120%
  - specialDown → lightAir a 30-150%
- **dashAttack** (oggi usa heavy), 1 combo:
  - lightAir → dashAttack a 80-90%

Mancano anche, ma oggi non chiudono combo vere: grab, throw.
