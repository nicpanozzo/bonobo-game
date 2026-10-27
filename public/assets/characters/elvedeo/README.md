# Elvedeo

Rasta in groppa a una capra, col piccione sulla spalla: berretto verde, giallo e rosso, dreadlock, occhiali tondi, canna accesa, maglietta nera strappata, pantaloni senape e crocs. Dal 2026-10-27 (Nicola) sostituisce il gatto rasta col bong proposto da @MauroGrecchi in #168, che resta nella storia della repo.

## Mosse

| Tasto | Mossa |
|---|---|
| Speciale neutra | **Piccione**: indica e il piccione parte dalla spalla verso il nemico; in volo è il disegno di `proiettili/piccione.png`, col corpo al centro del rettangolo del colpo |
| Speciale laterale | **Incornata**: la capra gratta il terreno, carica a testa bassa e sbatte |
| Speciale giù | **Calcione**: si carica, poi la capra scalcia all'indietro (il colpo sta dietro) |
| Suprema | **Elefante**: una nuvola di fumo e per poco la capra è un elefante e il piccione un'aquila; il disegno diventa grande il doppio (`grow`), pesta tutto intorno mentre avanza piano. Con la Speciale, una volta sola, parte l'aquila (`proiettili/aquila.png`): scende in picchiata, afferra il primo che tocca, lo porta su e lo molla più in là. Da lì l'elefante usa `proiettili/suprema-senza-aquila.png`, gli stessi fotogrammi con Elvedeo che tende il braccio |

## Fotogrammi

- Formato cartella (E7): un PNG per stato, fotogrammi da **440×300 px** in fila da sinistra, `scale: 0.5`, piedi a `footY: 276`. Largo e alto perché l'elefante e le nuvole escono dalla capra.
- Guarda **a destra**, sfondo trasparente, contorno chiaro di 2 px.

## Come è stato fatto

Dai tre video di Nicola fatti con Google Flow (1280×720, 24 fps), con `tools/sprite/elvedeo_dai_video.py`: i fotogrammi da usare per ogni stato sono nel `PLAN` dello script.

- **Clip 2 (speciali) e clip 3 (suprema)** così come sono. Nella 3 l'elefante a metà si gira a sinistra: quei fotogrammi sono specchiati.
- **Clip 1 (mosse base)**: Flow ha messo Elvedeo a piedi accanto alla capra. Lo script rimonta la capra della clip 1 (girata a destra quando guarda a sinistra) con sopra Elvedeo seduto, ritagliato da un fermo della clip 2, che segue il tronco della capra (centro e inclinazione mediati su cinque fotogrammi, così non trema). Nei colpi col bastone, nella presa, nello scudo e quando viene colpito il busto è quello di Elvedeo a piedi della clip 1, tagliato in vita.
- **Piedi e centro**: ogni mossa rimontata parte col corpo al centro del fotogramma e gli zoccoli su `footY`, come il fermo; la camminata e la corsa sono un passo di galoppo intero (13 fotogrammi) tenuto sul posto, il fermo va avanti e indietro così il ciclo non salta.

- **Uccelli**: il piccione (clip 2) e l'aquila (clip 3, specchiata) sono ritagliati dove volano staccati, centrati sul corpo (la maschera erosa, senza le ali). La suprema senza aquila sostituisce il busto di Elvedeo e l'aquila sopra la vita con il busto col braccio teso di un fotogramma in cui l'aquila è già partita, allineato sul berretto.

I video e le immagini di riferimento non sono nella repo.
