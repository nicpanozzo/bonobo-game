# Egiainuso

L'omino col cappellino e lo zaino del foglio delle pose di @Marcomunista ([#178](https://github.com/nicpanozzo/bonobo-game/issues/178)). Il nome era della creatura blu sulla barchetta, che ora si chiama Capt. OrsoBlu (`../orsoblu/`).

## Sprite: animazioni dal video (E7)

Le animazioni vengono dai video fatti da Nicola con Google Flow (il video di tutte le mosse del 25/10 e le clip dedicate EG-01..EG-19 del 6–8/11), con le pose del foglio di Marco come riferimento. Prima l'animato era una skin ("Animato") accanto alle pose ferme ritagliate dal foglio: le pose ferme sono state tolte e l'animato è diventato lo sprite di base.

- **Una striscia per stato**, fotogrammi da **400×330 px** coi piedi a 290 (`footY`) e `scale: 0.5`.
- La speciale neutra è lo sputo.
- **Eccezione alla style guide:** è un disegno a tratto nero su fondo bianco, non illustrato a 2 toni. La faccia è riempita di bianco; **niente contorno chiaro** attorno al corpo (tolto il 2026-11-04: in gioco sembrava uno scontorno sbagliato).
- `portrait.png`: testa e cappellino, per lobby e HUD.

## Rifarlo

```bash
python3 tools/sprite/egiainuso_dal_video.py <video.mp4> <cartella di lavoro>
npm run export:godot
```

Se cambia la misura dei fotogrammi, va ricopiata in `characters.ts`.

## Da chiedere a Marco

- Il foglio l'hai fatto tu o con un generatore di immagini? Con che licenza lo dai al gioco?
- Che statistiche (velocità, salto, peso) e che mosse speciali vuoi per Egiainuso?
