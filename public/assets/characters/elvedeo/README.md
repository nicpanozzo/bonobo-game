# Elvedeo

Gatto rasta grassottello: berretto a righe, dreadlock, canna sempre accesa, pancia e jeans. Attacca con una nuvola di fumo verde e con il bong. Proposto da @MauroGrecchi in #168. È un personaggio inventato, non la caricatura di un membro.

## Eccezione provvisoria alla style guide

Come Capt. OrsoBlu, Elvedeo per ora **non segue** [docs/stile-grafico.md](../../../../docs/stile-grafico.md):

- **risoluzione bassa:** il foglio originale ha lottatori alti circa 72 px, qui ingranditi 2,5 volte con un filtro morbido; da vicino si vede sgranato;
- **stile diverso:** proporzioni chibi, linea e ombre dipinte invece di inchiostro e due toni piatti;
- **colori rasta** (rosso, giallo, verde saturi) vicini ai colori riservati ai giocatori (`COLORS` in `constants.ts`).

Una proposta di ridisegno nello stile comune è in una PR a parte (Parte di #168): si fa solo se Mauro è d'accordo.

## Fotogrammi

- Formato cartella (E7): un PNG per stato, fotogrammi da **360×200 px** in fila da sinistra, `scale: 0.5` → 180×100 px di mondo. Il corpo è alto circa 89 px di mondo, come la hitbox (88).
- Guarda **a destra**, piedi al centro del bordo basso, sfondo trasparente.

| Stato | Fotogrammi | Dal foglio di Mauro | Note |
|---|---|---|---|
| `idle` | 24 | riga 0 | fuma, a 12 fps |
| `walk` | 10 | riga 1 | a quattro zampe |
| `jump` | 7 | riga 2, fotogrammi 4-7 e i primi tre del gruppo a destra | slancio e salita |
| `fall` | 2 | riga 2, gli ultimi due a destra | braccia larghe, in ciclo |
| `light` | 6 | riga 4, i primi 6 | soffia la nuvola verde; `hitFrame: 2` |
| `heavy` | 8 | riga 5, fotogrammi 2-9 | alza il bong e lo abbatte; `hitFrame: 6` |
| `hit` | 8 | riga 6 | |
| `tumble` | 12 | riga 3 | rotola quando vola via |

Gli altri stati usano il ripiego (`ANIMATION_FALLBACK` in `characters.ts`).

**Non usati:** l'ultimo fotogramma della nuvola (il getto grande, non sta nel fotogramma senza allargarlo a tutti), il secondo colpo di bong con il bong che si rompe e i tre fotogrammi dopo (riga 5, da 10 in poi). Potrebbero servire per una speciale (E10) o per `heavyDown`.

## Come è stato fatto

Dal JPEG di #168 (1888×560, la scacchiera grigia era dipinta nell'immagine): scacchiera tolta in automatico, poi uno script Python (Pillow, SciPy) che

1. pela i bordi grigi rimasti dalla scacchiera e toglie la scritta in basso a destra;
2. trova i fotogrammi come macchie separate in ogni riga; nella riga della nuvola separa il fumo (verde salvia) dal corpo, così ogni nuvola resta col suo fotogramma;
3. mette i piedi al centro del bordo basso e ingrandisce ×2,5 con filtro bicubico (alfa premoltiplicato).

Il foglio originale e lo spritesheet senza scacchiera sono nella storia del branch `riccardo/elvedeo` (commit "Elvedeo: spritesheet di partenza di Mauro").

## Da chiedere a Mauro

- Ha una versione PNG con trasparenza vera, o a risoluzione più alta?
- Con che strumento l'ha fatto e con che licenza (per `CREDITS.md`)?
- Come si chiamano le righe del foglio (le abbiamo indovinate)?
