# Tavola delle animazioni di Marcomunista (skin "Fumetto", #421)

Anima i **disegni originali** di Marco (le pose del foglio #352, commit fe77b42) a pezzi: la testa resta sempre il
disegno originale (si muove rigida), braccia e gambe si piegano con una deformazione rigida morbida (MLS), e gli
effetti (archi rosa, scintille, polvere, scie, aura) sono strati a parte.

- `rigs.py`: scheletro e strati di ogni disegno; `anim.py`: i fotogrammi di ogni animazione; `fx.py`: gli effetti.
- Lavori in corso: i percorsi sono quelli della sessione (`lib.SRC` = cartella con i PNG di fe77b42).

```bash
mkdir -p src && for f in $(git ls-tree --name-only fe77b42 public/assets/characters/marcomunista/); do git show fe77b42:$f > src/$(basename $f); done
pip install numpy scipy pillow opencv-python-headless
python3 render_all.py && python3 finale.py
```
