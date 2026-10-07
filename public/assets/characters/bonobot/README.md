# Bonobot

Personaggio di test per mosse e abilità, manichino da allenamento (#20) e personaggio giocabile, proposto da Riccardo (GiovannifRana). Statistiche di riferimento: tutto a 1.0 (#13).

## Spritesheet: `bonobot.png`

- Fotogrammi da **256×240 px**, disegnati a 2x: nel gioco si mostrano a metà (`scale: 0.5`), 128×120 px.
- Griglia di 24 colonne e 11 righe, **una riga per animazione**, fotogrammi da sinistra, sfondo trasparente.
- Guarda **a destra**: per andare a sinistra il client lo specchia.
- Il centro del corpo è al centro del fotogramma e i piedi toccano il bordo in basso. Il fotogramma è largo perché il braccio teso dell'attacco leggero arriva lontano.

| Riga | Animazione | Fotogrammi | fps | Ciclo | Note |
|---|---|---|---|---|---|
| 0 | idle | 24 | 12 | sì | respiro, peso che si sposta, braccia a pendolo, fumo |
| 1 | walk | 10 | 24 | sì | galoppo sulle nocche alla velocità di `groundSpeed`: mani e piedi non scivolano |
| 2 | jump | 7 | 24 | no | slancio con le braccia, poi si raccoglie |
| 3 | fall | 12 | 24 | sì | braccia larghe, gambe pronte all'atterraggio |
| 4 | light | 7 | 24 | no | schiaffo di rovescio; colpisce nei fotogrammi 2-4 (40-140 ms) |
| 5 | heavy | 18 | 24 | no | martello a due pugni; colpisce nei fotogrammi 7-10 (260-380 ms) |
| 6 | hit | 8 | 24 | no | contraccolpo, testa e braccia in ritardo |
| 7 | doubleJump | 9 | 24 | no | capriola in avanti che si apre verso la caduta (parte con l'evento `jump` in aria) |
| 8 | tumble | 12 | 24 | sì | rotola all'indietro quando vola via in hitstun, oltre `EFFECTS.tumbleSpeed` |
| 9 | ledge | 24 | 12 | sì | appeso allo spigolo con le mani sopra il bordo e i piedi contro la parete; dondola piano |
| 10 | climb | 10 | 24 | no | si tira su, ginocchio sul palco e in piedi in `LEDGE.climbMs` (400 ms); l'ultimo fotogramma è la posa di riposo |

I tempi dei colpi seguono `light` e `heavy` di `ATTACKS` in `constants.ts`: se cambiano, le animazioni vanno rifatte.

## Come è fatto

- **Sorgente: `bonobot.blend`** (Blender 4.2, cutout 2D): un piano per pezzo appeso a un'armatura di 19 ossa, un'azione per animazione (compresi `double_jump` e `tumble`). Lo spritesheet si rifà dal file stesso con il testo `esporta_spritesheet.py`. Per ora il `.blend` sta sul PC di Riccardo, non nella repo.
- Bonobot è diviso in 18 pezzi appesi a uno scheletro (animazione cutout). Piedi e mani restano piantati con la cinematica inversa; testa, mani e fumo arrivano in ritardo per dare inerzia.
- È un disegno di costruzione a forme semplici, non lo stile finale: quando arriva il disegno vero si sostituiscono i pezzi e le animazioni restano.
- La hitbox di gioco resta quella di `FIGHTER` in `constants.ts` (44×88). Per Bonobot si propone 48×78, da decidere con il passo 1 di #13.
