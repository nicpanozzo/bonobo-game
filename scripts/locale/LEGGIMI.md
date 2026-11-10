# Release e controlli della CI dal Mac

Quando GitHub Actions è fermo (per esempio a novembre 2026, con l'account bloccato per il billing), questi script fanno su un Mac quello che fanno `app.yml` e `ci.yml`. Partono da una copia pulita del commit, quindi la tua cartella di lavoro resta com'è. Godot 4.5.1, i modelli di esportazione (~1 GB, solo la prima volta) e node 22 li scaricano da soli in `~/Library/Caches/bonobo-locale`.

Servono un Mac, node con npm e `gh` loggato con il permesso di scrittura sulla repo.

## Pubblicare una nuova versione dell'app

```bash
scripts/locale/rilascio.sh --prova   # costruisce soltanto, i file finiscono in ~/Library/Caches/bonobo-locale/out
scripts/locale/rilascio.sh           # costruisce e pubblica la Release app-<N>
```

Lo script parte da `origin/main` e la versione è l'ultima `app-N` più 1. Costruisce i 9 file della Release: il gioco per Windows, Mac e Linux, il `.pck` con `bonobo-game-version.json`, che serve all'app per aggiornarsi da sola, e il server per i 4 sistemi. Prima di pubblicare controlla che il server per Mac risponda su `/health`. Per partire da un altro commit c'è `--ref <commit>`.

Si pubblica dopo che una o più PR che toccano `godot/` o il server sono entrate in main. L'app già installata si aggiorna da sola alla versione nuova. Il server online (Render) invece si aggiorna a parte.

## Controllare una PR senza CI

```bash
scripts/locale/ci.sh 591           # la PR unita a main, come fa la CI
scripts/locale/ci.sh origin/main   # un branch o un commit
```

Fa girare typecheck, test, il controllo che `godot/data` sia allineato e i budget di prestazioni del server. Poi carica gli script Godot, fa girare i test del client, il budget del client e gli screenshot, che aprono una finestra per qualche secondo. Esce con 0 solo se passa tutto. È lento e consuma token a un agente: fallo girare solo quando serve davvero.

## Quando la CI torna

`app.yml` usa come versione il numero del run di GitHub, che può essere più basso dell'ultima `app-N` pubblicata a mano: in quel caso l'app non si aggiorna. Prima del primo rilascio automatico va sistemato.
