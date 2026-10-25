# Stile grafico di Bonobo Game

La guida per chi disegna lottatori e arene. Serve a far uscire ogni personaggio nello stesso stile e a farlo arrivare nel gioco senza toccare il codice.

**Stato:** proposta di Riccardo (@GiovannifRana), scritta con il passo 1 di E7 ([#41](https://github.com/nicpanozzo/bonobo-game/issues/41), [specifica](evolutive/E7.md)). Diventa la regola dopo il voto del gruppo (vedi [Voto](#voto-del-gruppo) in fondo). Il personaggio di riferimento è **Bonobot** (`public/assets/characters/bonobot/`).

## 1. Tecnica: 2D illustrato

- **Come Brawlhalla:** disegni 2D illustrati, proporzionati e poco cartoon, con linea pulita e ombre a due toni.
- **Niente pixel art:** la camera zooma (`CAMERA.minZoom` 0.7, `maxZoom` 1.3 in `constants.ts`) e la pixel art si scala male; i volti, che contano nei ritratti, si perdono.
- **Niente 3D:** troppo lavoro per un gruppo di amici e per un gioco che gira nel browser.
- **Eccezione:** Capt. OrsoBlu (#40, prima si chiamava Egiainuso) è in pixel art 64×96 ed è un esempio provvisorio. Ridisegnarlo o tenerlo come eccezione si decide con @MauroGrecchi.

## 2. Linea, ombre e colori

- **Contorno a inchiostro** scuro (quasi nero, non nero puro) attorno a ogni pezzo, di spessore costante: circa 3 px nel disegno a 2x.
- **Gli oggetti a terra** (banana, bong, funghi, ...) fanno parte dell'arena (#498): contorno **sottile nella loro tinta scura**, non l'inchiostro, i colori prendono la luce dell'arena (sole e luna, #288) e stanno posati e fermi con la loro ombra. Il contorno chiaro compare solo quando si è abbastanza vicini da raccoglierli.
- **Ombre piatte a 2 toni:** un tono base e un'ombra, con il bordo netto. Niente sfumature, niente texture, niente luce realistica. La luce viene da davanti in alto: l'ombra cade sul dorso e sotto.
- **Colori alla Hades:** pochi accenti saturi su una base più quieta. Ogni personaggio ha **2-3 colori propri**, riconoscibili da lontano.
- **Leggibilità sui fondali scuri:** un personaggio molto scuro (come il pelo di Bonobot) prende un sottile **contorno luminoso** sulla sagoma, oppure un *chroma* più chiaro da scegliere in selezione. Prova: lo screenshot in scala di grigi deve mostrare la sagoma staccata dal fondale.

### Colori riservati ai giocatori

Il colore del giocatore **non tinge mai lo sprite**: sta sull'indicatore sopra la testa, sull'alone ai piedi e nell'HUD. Per questo i colori dei giocatori non vanno usati saturi come colore principale di un personaggio né vicino al piano di gioco delle arene:

| `COLORS` | rosso `#e74c3c`, blu `#3498db`, verde `#2ecc71`, giallo `#f1c40f`, viola `#9b59b6`, arancio `#e67e22`, turchese `#1abc9c`, rosa `#ff6fb5` |
|---|---|
| `COLORS_COLORBLIND` | `#d55e00`, `#0072b2`, `#009e73`, `#f0e442`, `#cc79a7`, `#e69f00`, `#56b4e9`, bianco |

Usati poco, come piccoli accenti (una brace, un bottone), vanno bene.

## 3. Personaggi

- **Corpi proporzionati,** niente testa gigante.
- **Personaggi = noi** (#13): caricatura leggera, volto molto somigliante con un piccolo accento sui tratti tipici. Nome, faccia e voce di una persona entrano nel gioco solo se quella persona è d'accordo.
- **Riconoscibili da lontano:** a zoom minimo il volto non si vede, quindi contano sagoma, capelli, un capo d'abbigliamento o un oggetto simbolo. Il volto si vede nei ritratti (HUD, selezione, vittoria).
- **Test della sagoma:** riempito tutto di nero, il personaggio si distingue dagli altri del roster.

## 4. Misure rispetto alla hitbox

![Misure di Bonobot rispetto alla hitbox](stile-grafico/misure.png)

- La hitbox di gioco è `FIGHTER` in `constants.ts`: **44×88 px di mondo**. Lo sprite è solo grafica: non cambia la hitbox.
- **Il corpo sta dentro la hitbox;** braccia, colpi, capelli, fumo e oggetti possono uscire.
- **Piedi sul bordo basso del fotogramma, al centro** (lì il gioco mette `x` e `y` del lottatore). **Guarda a destra:** per l'altra direzione il gioco specchia il fotogramma.
- **Fotogramma:** tutti della stessa misura, sfondo trasparente. La misura la sceglie chi disegna, abbastanza larga per i colpi: E7 propone 96×112 px di mondo; Bonobot usa **168×184**, perché ha le braccia lunghe e da appeso al bordo il corpo scende sotto i piedi (`footY`).
- **I colpi arrivano dove colpiscono:** nei fotogrammi in cui la hitbox dell'attacco è accesa (`startupMs` e `activeMs` di `ATTACKS`), la mano o l'arma deve stare dentro la sua area (in arancio nella tavola). Sono le stesse aree che Godot disegna durante il colpo e nel pannello dell'allenamento.

## 5. Risoluzione: si disegna a 2x

- Si disegna al **doppio** della misura di mondo e nello spritesheet si scrive `scale: 0.5` (`SpriteSheetSpec` in `characters.ts`). Bonobot: fotogrammi da 336×368 px nel PNG, 168×184 nel gioco.
- **Perché:** a 1080p con lo zoom massimo (1.3) un lottatore occupa circa 170 px sullo schermo; disegnato a 1x si sgrana.
- File singoli **sotto i 5 MB**; Bonobot con 13 animazioni pesa circa 0,9 MB, salvato con una palette di 256 colori.

## 6. Animazione a pezzi (cutout)

![Pose chiave di Bonobot](stile-grafico/pose.png)

- **Tecnica:** il personaggio è diviso in pezzi (testa, busto, braccio, avambraccio, mano...) appesi a uno scheletro. Si anima ruotando le ossa e si esporta lo spritesheet. Quando arriva il disegno definitivo si sostituiscono le immagini dei pezzi e le animazioni restano.
- **Strumento: Blender** (gratis), oppure gli script in `tools/rig`. Lo scheletro è in `rig.json` ([docs/scheletro.md](scheletro.md)) e in Blender si monta con `tools/blender/costruisci_rig.py`. Bonobot oggi è animato in `tools/rig/animazioni_bonobot.py` e disegnato da `tools/rig/rendi_sprite.py`, un PNG per stato.
- **Movenze naturali, non meccaniche:** anticipo prima dei colpi, inerzia (testa, mani e capelli arrivano un attimo dopo il corpo), piedi e mani che restano piantati a terra mentre il corpo si muove, archi nei movimenti.
- **Velocità:** 24 fotogrammi al secondo; le animazioni lente in ciclo (fermo, appeso) possono stare a 12.
- **Colpi a tempo:** negli attacchi si segna `hitFrame`, il fotogramma dell'impatto; il gioco lo fa cadere quando la hitbox si accende.
- **Animazioni obbligatorie** (`AnimationName`): `idle`, `walk`, `jump`, `fall`, `light`, `heavy`, `hit`.
- **Facoltative** (`OptionalAnimationName`; senza si usa quella di ripiego): `doubleJump` (→ `jump`), `tumble` (→ `hit`), `ledge` e `climb` (→ `jump`), `land` e `taunt` (→ `idle`), le varianti degli attacchi (→ `light` o `heavy`)... L'elenco completo è nel [README dei personaggi](../public/assets/characters/README.md).
- **Animare come Smash:** checklist per ogni stato nella sezione qui sotto.
- **Formato:** una cartella per personaggio con **un PNG per stato** (`idle.png`, `walk.png`...), fotogrammi in fila da sinistra; nel blocco del personaggio in `characters.ts` si scrivono solo `fps` e ciclo di ogni stato. Il vecchio formato a foglio unico (una riga per animazione, come Bonobot oggi) funziona ancora. Istruzioni: `public/assets/characters/README.md`.

### Animare come Smash (#384)

In Smash ogni mossa si capisce al primo sguardo e colpisce dove si vede. Le regole che lo rendono possibile:

1. **Parte subito.** Il primo fotogramma cambia già la sagoma rispetto al fermo: chi preme il tasto vede la risposta nello stesso istante. Mai un fotogramma uguale a `idle` all'inizio.
2. **Anticipazione:** prima del colpo il corpo si carica all'indietro (spalla indietro, peso sul piede dietro). Più il colpo è forte, più è ampia.
3. **Fotogramma d'impatto:** è la posa più forte e più leggibile, perché resta ferma per tutto il fermo al colpo (`HITSTOP`). Arto tutto disteso, mano o arma dentro la zona del colpo. Si segna in `hitFrame`.
4. **Smear e archi:** tra anticipazione e impatto un fotogramma con il braccio allungato e sfumato lungo l'arco del movimento; le mani seguono archi, mai linee rette.
5. **Follow-through:** dopo l'impatto il corpo continua il movimento (il braccio passa oltre, il busto ruota) e poi torna alla guardia durante il `cooldownMs`.
6. **Squash & stretch:** schiacciato in preparazione (salto, pesante), allungato nello slancio. Il volume resta lo stesso.
7. **Silhouette diversa per ogni stato:** a sagoma nera, `light`, `heavy`, le varianti in alto, in basso e in aria si distinguono tra loro.
8. **Personalità:** la stessa mossa la fa ogni personaggio a modo suo (un allenatore con il fischietto, uno scienziato con l'ampolla): stessa zona del colpo, posa diversa.
9. **24-30 fotogrammi al secondo**, nessun fotogramma morto: se due fotogrammi di fila sono uguali, uno diventa un passaggio intermedio o si toglie.

**Quanti fotogrammi per fase**, a 24 fps (un fotogramma ≈ 42 ms), con i tempi di `ATTACKS` in `constants.ts`:

| Fase | Tempo | Fotogrammi | Cosa si vede |
|---|---|---|---|
| Avvio colpo leggero (`startupMs` 40-60) | 1 fotogramma | 1-2 | anticipazione corta, poi subito l'impatto |
| Avvio colpo pesante (`startupMs` 200-280) | 5-7 fotogrammi | 5-7 | carica ampia, smear nell'ultimo |
| Colpo attivo (`activeMs` 100-160) | 2-4 fotogrammi | 2-4 | impatto e smear di ritorno |
| Recupero (`cooldownMs` 280-800) | 7-19 fotogrammi | 4-8 | follow-through e ritorno alla guardia (si può andare a 12 fps) |

Cosa fa ogni personaggio in ogni stato si scrive nella [scheda mosse](scheda-mosse.md).

**Checklist per stato:**

- [ ] Il primo fotogramma è diverso da `idle`.
- [ ] C'è un'anticipazione, proporzionata alla forza del colpo.
- [ ] Il fotogramma d'impatto è la posa più ampia e cade su `hitFrame`; la mano o l'arma è dentro la zona del colpo (prova con "Mostra hitbox" in allenamento).
- [ ] Almeno un fotogramma di smear o un arco evidente nei colpi.
- [ ] Follow-through prima del ritorno alla guardia.
- [ ] Squash & stretch dove c'è uno slancio (salto, atterraggio, pesante).
- [ ] La sagoma nera si distingue dagli altri stati e dagli altri personaggi.
- [ ] Nessun fotogramma morto; 24 fps (12 solo per i cicli lenti).

## 7. Arene

Ogni arena ha la sua palette e il suo luogo (#14), con tre regole comuni:

1. **Fondale più spento e più scuro dei personaggi.** Prova: screenshot in scala di grigi, i lottatori devono staccarsi.
2. **Bordo calpestabile sempre chiaro**, così si capisce dove si può stare.
3. **Niente colori dei giocatori saturi vicino al piano di gioco** (vedi la tabella sopra).

I pezzi su cui si cammina possono avere un materiale (`art.skins`, #237): pietra, legno, metallo, ripetuti lungo il pezzo. Valgono le stesse regole:
- il materiale resta più spento dei lottatori;
- il bordo calpestabile (`edge`) è sempre la parte più chiara;
- le decorazioni davanti ai lottatori (ringhiere, statue) sono basse e trasparenti.

Come si scrivono i dati è in [arene.md](arene.md).

## 8. Prima di mandare un personaggio: checklist

- [ ] Stile: contorno a inchiostro, 2 toni, 2-3 colori propri, nessun colore dei giocatori come colore principale.
- [ ] Sagoma nera riconoscibile; si legge sul fondale scuro e in scala di grigi.
- [ ] Disegnato a 2x, `scale: 0.5`; fotogrammi tutti uguali, trasparenti, piedi al centro del bordo basso, guarda a destra.
- [ ] Corpo dentro 44×88 di mondo; nei colpi la mano arriva nell'area dell'attacco nei fotogrammi giusti.
- [ ] Le 7 animazioni obbligatorie; le facoltative se ci sono.
- [ ] PNG sotto i 5 MB, riga in `public/assets/CREDITS.md` (autore, fonte, licenza), il consenso della persona ritratta.
- [ ] `npm run export:godot`, poi provato in Godot (`godot --path godot -- --room=prova --name=A --char=<id>`).

## Riferimenti

Brawlhalla (tecnica, proporzioni, camera) e Hades (palette, inchiostro, ombre piatte). Sono materiale protetto da copyright: si citano e si guardano, **non si mettono nella repo**.

## Voto del gruppo

Il passo 1 di E7 si chiude con il voto del gruppo, linkato nella #41. Sondaggio proposto (24 ore), da lanciare con il permesso di Riccardo:

```bash
npm run discord -- poll "Stile grafico di Bonobo Game: va bene la proposta in docs/stile-grafico.md (2D illustrato alla Brawlhalla, colori alla Hades, animazione a pezzi)?" "Sì, così" "Sì, con qualche modifica (scrivete nella #41)" "No, un'altra direzione"
```
