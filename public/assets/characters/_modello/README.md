# Modello per disegnare un lottatore

Due PNG a 2x (come gli sprite, `scale: 0.5`), da mettere **sotto** il disegno come livello di guida e da **nascondere prima di esportare**. Non sono un personaggio: il gioco non li usa.

- `modello.png`: un fotogramma da 400×320 px (200×160 di mondo) con la sagoma grigia della hitbox (44×88 di mondo, cioè 88×176 nel PNG), i **piedi** in verde al centro del bordo basso, la freccia **guarda a destra** e le zone del colpo leggero (arancio) e pesante (rosso). La griglia è ogni 16 px di mondo (32 nel PNG).
- `colpi.png`: otto fotogrammi in fila, uno per attacco (`light`, `lightUp`, `lightDown`, `lightAir`, `heavy`, `heavyUp`, `heavyDown`, `heavyAir`). In ognuno c'è la zona del colpo e i millisecondi in cui è accesa: nel fotogramma `hitFrame` la mano o l'arma deve stare lì dentro.

Il fotogramma da 400×320 contiene tutte le zone dei colpi; il tuo può essere più piccolo o più grande (Bonobot usa 336×368), basta che i piedi restino al centro in basso.

Si rigenerano da `constants.ts` con `npm run export:godot` e poi `python3 tools/sprite/modello_sprite.py`: se cambiano hitbox o colpi, il modello li segue.

La guida completa è in [../README.md](../README.md).
