# Bonobot

Personaggio di test per mosse e abilità, manichino da allenamento (#20) e personaggio giocabile, proposto da Riccardo (GiovannifRana). Statistiche di riferimento: tutto a 1.0 (#13).

## `bonobot.png` (provvisorio)

- Immagine ferma, **senza animazioni**: in `characters.ts` tutte le animazioni usano l'unico fotogramma. Serve a vedere Bonobot nel gioco e a provare misure e verso.
- 106×170 px, disegnata a 2x: nel gioco si mostra a metà (`scale: 0.5`), circa 53×85 px.
- Guarda **a destra**: per andare a sinistra il client la specchia.
- Il centro del corpo è al centro dell'immagine e i piedi toccano il bordo in basso (lo spazio vuoto a sinistra compensa il muso e la canna che sporgono in avanti).
- È un disegno di costruzione a forme semplici, non lo stile finale: verrà sostituito dallo spritesheet animato.

La hitbox di gioco resta quella di `FIGHTER` in `constants.ts` (44×88). Per Bonobot si propone 48×78, da decidere con il passo 1 di #13.
