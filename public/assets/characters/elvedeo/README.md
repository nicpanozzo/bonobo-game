# Elvedeo

Rasta in groppa a una capra, col piccione sulla spalla: berretto verde, giallo e rosso, dreadlock, occhiali tondi, canna accesa, maglietta nera strappata, pantaloni senape e crocs. Dal 2026-10-27 (Nicola) sostituisce il gatto rasta col bong proposto da @MauroGrecchi in #168, che resta nella storia della repo.

## Mosse

| Tasto | Mossa |
|---|---|
| Speciale neutra | **Piccione**: indica e il piccione vola dritto contro il nemico |
| Speciale laterale | **Incornata**: la capra gratta il terreno, carica a testa bassa e sbatte |
| Speciale giù | **Calcione**: si carica, poi la capra scalcia all'indietro (il colpo sta dietro) |
| Suprema | **Elefante**: una nuvola di fumo e per poco la capra è un elefante e il piccione un'aquila; pesta tutto intorno mentre avanza piano |

## Fotogrammi

- Formato cartella (E7): un PNG per stato, fotogrammi da **440×300 px** in fila da sinistra, `scale: 0.5`, piedi a `footY: 276`. Largo e alto perché l'elefante e le nuvole escono dalla capra.
- Guarda **a destra**, sfondo trasparente, contorno chiaro di 2 px.

## Come è stato fatto

Dai tre video di Nicola fatti con Google Flow (1280×720, 24 fps), con `tools/sprite/elvedeo_dai_video.py`: i fotogrammi da usare per ogni stato sono nel `PLAN` dello script.

- **Clip 2 (speciali) e clip 3 (suprema)** così come sono. Nella 3 l'elefante a metà si gira a sinistra: quei fotogrammi sono specchiati.
- **Clip 1 (mosse base)**: Flow ha messo Elvedeo a piedi accanto alla capra. Lo script rimonta la capra della clip 1 (girata a destra quando guarda a sinistra) con sopra Elvedeo seduto, ritagliato da un fermo della clip 2, che segue l'inclinazione della schiena. Nei colpi col bastone, nella presa, nello scudo e quando viene colpito il busto è quello di Elvedeo a piedi della clip 1, tagliato in vita.

I video e le immagini di riferimento non sono nella repo.
