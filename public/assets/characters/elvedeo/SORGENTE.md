# Elvedeo: file di partenza (#168)

Spritesheet proposto da @MauroGrecchi nell'issue #168, salvato da Riccardo il 7/10/2026.

- `elvedeo-originale.jpg`: il file così come è arrivato (1888×560, JPEG). **La scacchiera grigia è dipinta nell'immagine**: non c'è trasparenza vera.
- `elvedeo-originale.png`: lo stesso con la scacchiera tolta in automatico (pixel grigi a bassa saturazione collegati allo sfondo → trasparenti). È un punto di partenza: controllare i bordi, il fumo grigio chiaro e i frammenti della riga 6, che possono avere perso pezzi o tenuto aloni.
- Le righe non sono una griglia regolare e i fotogrammi hanno misure diverse: vanno ritagliati e messi su una griglia.
- In basso a destra c'è una scritta ("HD Sprite Sheet - Chubby Rasta Cat…") da togliere.

Righe come appaiono (da confermare con Mauro): 0 fermo (fuma), 1 camminata a quattro zampe, 2 salto / caduta, 3 lanciato (rotola), 4 provocazione o attacco con nuvola di fumo, 5 attacco pesante con il bong che si rompe, 6 colpito o KO.

Da chiedere a Mauro: se esiste la versione PNG con trasparenza vera, e con quale strumento è stato fatto (per la riga nei crediti e la licenza).

Questi file sorgente non vanno in `main`: la PR finale tiene solo lo spritesheet pulito.
