# Suoni e voci: come mandarli

La guida per chi registra effetti, musica, voci dei personaggi e annunciatore (E13, #16). I file entrano nel gioco senza toccare codice: basta metterli nella cartella giusta con il nome giusto e lanciare `npm run export:godot`. Finché un file manca, il gioco usa i suoni sintetizzati di `godot/scripts/synth.gd`, quindi niente si rompe.

## Dove e con che nome

| Cosa | Cartella e nome | Quando suona |
|---|---|---|
| Effetti | `public/assets/sfx/<evento>_<n>.ogg`, es. `hitHeavy_1.ogg`, `hitHeavy_2.ogg` | al posto della ricetta con lo stesso nome in `audio.gd` (`hitLight`, `hitHeavy`, `jump`, `land`, `ko`, `taunt`...) |
| Musica | `public/assets/music/lobby.ogg`, `public/assets/music/match.ogg` | nella lobby e in partita, in loop |
| Annunciatore | `public/assets/announcer/<frase>.ogg`: `go`, `lastLife`, `tenSeconds`, `game`, `draw` | inizio, ultima vita, dieci secondi, fine partita |
| Voce di un personaggio | `public/assets/characters/<id>/voice/taunt_<n>.ogg`, `ko_<n>.ogg`, `victory_<n>.ogg` | provocazione (tasto T), quando esce dall'arena, quando vince |

- Il numero `_<n>` serve per le varianti: con più file il gioco ne sceglie uno a caso, mai lo stesso due volte di fila.
- `<id>` è l'id del personaggio in `src/shared/characters.ts` (`default`, `egiainuso`, `bonobot`, `elvedeo`...). Le voci in `characters/default/voice/` valgono anche per i personaggi che non hanno le loro.
- Una voce per giocatore alla volta: l'urlo del KO taglia la provocazione. Tra due provocazioni passano almeno 1,5 s (`AUDIO.tauntVoiceCooldownMs` in `constants.ts`), così tenere premuto T non fa spam.

## Formato

- **Ogg Vorbis**, 44,1 kHz. Mono per effetti e voci, stereo per la musica.
- **Durata:** voci e frasi sotto i 2 secondi, effetti il più corti possibile. La musica deve chiudersi bene in loop.
- **Peso:** ogni file sotto i 500 KB.
- **Volume:** circa -16 LUFS integrati, picco sotto -1 dBTP. `npm run audio:check` (serve ffmpeg) misura ogni file e dice quali sono fuori volume.

## Registrare con il telefono

1. Una stanza piccola e piena di cose (vestiti, divano): meno eco. Telefono a 15-20 cm dalla bocca, un po' di lato.
2. Registra 3-4 versioni di ogni battuta: è facile scegliere dopo.
3. In [Audacity](https://www.audacityteam.org/) (gratis): taglia il silenzio prima e dopo, *Effetti > Riduzione rumore* se c'è un fruscio, *Effetti > Normalizzazione volume (loudness)* a -16 LUFS.
4. *File > Esporta > Esporta come OGG*, qualità 5, mono.

## Consenso e crediti

- Una voce entra nel gioco **solo se la persona che la presta è d'accordo per scritto**: un commento suo nella #16 (o nell'issue del suo personaggio) basta.
- Ogni file ha una riga in `public/assets/CREDITS.md`: file, autore, fonte, licenza (CC0 o CC-BY) e il link al commento con il consenso.
- Suoni presi da internet: solo con licenza libera (CC0, CC-BY), con fonte e autore. Niente spezzoni di film, giochi o canzoni.

## Da chiedere al canale

- Chi fa l'annunciatore, e con quali frasi.
- Le battute di provocazione e di vittoria di ogni personaggio: meglio se sono tormentoni del canale.
