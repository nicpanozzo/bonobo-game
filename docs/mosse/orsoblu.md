# Capt. OrsoBlu, versione 2: scheda mosse e prompt per Flow (OB)

> Scheda e prompt di Capt. OrsoBlu v2, scelti con Nicola il 3/11/2026. Le clip OB-01, 02, 03, 07 sono già nel gioco (#544).

Scelte di Nicola (3/11/2026). Personaggio originale di @MauroGrecchi (#37): barchetta e remo restano.
I prompt seguono il metodo di Riccardo in `docs/clip-flow/README.md` (PR #540): Frames to video, Veo 3.1, 16:9, 8 secondi, 1 risultato, prima e ultima immagine uguali, al massimo 3 mosse per clip (al massimo 2 attacchi) con 1-1,5 s di pausa nella posa, sfondo verde `#17B03B`, niente effetti. Quando #540 è unita, OrsoBlu si aggiunge a `tools/flow/prompt_flow.py` e questi prompt si rigenerano da lì.

## Il personaggio in una riga

Un orso blu capitano di mare, **burbero e pignolo**, che tratta l'arena come la sua nave e insulta tutti. Gira a piedi con la **barchetta rovesciata in spalla** come un guscio. La mossa fondamentale è **l'ancora a catena usata come una ragnatela**: si appende di qua e di là e oscilla, come la corda di Spelunky ma molto più mobile.

## La meccanica fondamentale: l'ancora-ragnatela

| Tasto | Nome | Cosa fa |
|---|---|---|
| Su (recupero) | **Arrembaggio!** | Spara l'ancora in diagonale verso dove tieni. Se pianta in una piattaforma, un bordo o un muro resta appeso e oscilla come un pendolo. Avanti/indietro: slancio. Su: si arrampica accorciando la catena. Giù: si cala. Salto: si stacca tenendo lo slancio. Attacco: calcio di stivale in oscillazione. |
| Laterale | **Avanti tutta!** | Da appeso: riavvolge la catena e sfreccia verso l'ancora come su una teleferica, travolgendo chi c'è in mezzo, poi si aggrappa al bordo. Da libero: spallata in avanti. |
| Neutra | **Tutti a bordo!** | La stessa ancora sparata dritta in avanti: se prende qualcuno lo tira verso il capitano. |

**Nel gioco da #547** (`src/shared/physics/anchor.ts`, numeri in `ANCHOR` di `constants.ts`): Pesante + su in aria spara l'ancora (solo su quasi in verticale, su + direzione in diagonale), 2 lanci prima di toccare terra, sgancio da solo dopo 3 s, Scudo lascia andare, un colpo stacca; arrampicandosi fino a uno spigolo ci si aggrappa al bordo. Da provare al playtest: spinta extra staccandosi nel punto più alto. Avanti tutta! è la speciale laterale: da appeso sfreccia verso l'ancora già attiva (poi resta appeso in cima, col Salto si fa la fionda), da libero è la spallata. Tutti a bordo! (Speciale neutra) spara l'ancora quasi dritta in avanti: in aria ci si appende a muri e bordi davanti, da terra la catena tira fin lì (Nicola, 4/11/2026). Se l'ancora prende qualcuno lo tira verso di lui (6%).

**I comandi dell'ancora (Nicola, 5/11/2026: tutto sullo Speciale, si deve piantare nelle piattaforme)**

| Tasti | Cosa fa |
|---|---|
| Speciale | ancora dritta in avanti (Tutti a bordo!): prende muri, bordi e chi ha davanti, che tira a sé |
| Speciale + su | ancora in alto; con su + una direzione in diagonale. La mira va da sola verso lo spigolo o la piattaforma più vicina |
| Pesante + su in aria | il recupero comune: come Speciale + su, così funziona anche con i comandi di tutti |
| Da terra, ancora piantata | la catena lo tira fin lì; su una piattaforma ci si ritrova sopra |
| Appeso: avanti / indietro | slancio lungo l'arco del pendolo |
| Appeso: su / giù | si avvicina (arrampica) o si allontana (cala); arrivato a una piattaforma ci sale sopra, a uno spigolo si aggrappa al bordo |
| Appeso: Speciale | Avanti tutta!: sfreccia verso l'ancora travolgendo chi c'è in mezzo, poi sale sulla piattaforma |
| Appeso: Salto | si stacca con lo slancio, una spinta in alto e verso la direzione tenuta |
| Appeso: Scudo | lascia andare |
| Appeso: Leggero / Pesante | calcio in oscillazione (attacco in aria) |
| Speciale + direzione, senza ancora | Avanti tutta!: la spallata |
| Speciale + giù | Mina di bordo |

Si resta appesi al massimo 4 s, con 2 lanci prima di toccare terra.

**Ancora e catena le disegna il gioco** (come l'aquila di Elvedeo): nelle clip lui mima il lancio e stringe una catena invisibile, "nothing is drawn". Servono a parte gli sprite di ancora, catena e mina.

## Le altre mosse

| Stato | Cosa fa |
|---|---|
| specialDown, **Mina di bordo** (nel gioco da #547, disegno provvisorio: un pallino scuro) | posa a terra una piccola mina navale coi baffi; esplode quando qualcuno ci passa sopra. Una alla volta |
| supreme, **Tempesta!** (nel gioco da #547, suprema "storm": rollio, onde, pioggia e timone provvisori disegnati da Godot) | l'arena rolla come una nave nella tempesta, tutti scivolano tranne lui, piantato al timone a gambe larghe, che insulta tutti a nuvolette ("Mozzi d'acqua dolce!", "Sacchi di sardine!", "Branco di triglie lesse!"). Timone e nuvolette li disegna il gioco |
| light / lightUp / lightDown / lightAir | scappellotto col berretto / botta di cannocchiale in alto / calcio di stivale alle caviglie / giravolta col cannocchiale |
| heavy / heavyUp / heavyDown / heavyAir | colpo di remo / barchetta sopra la testa come un ombrello / barchetta sbattuta a terra come una campana, dai due lati / mulinello col remo |
| dashAttack | si tuffa a pancia in giù sulla barchetta e scivola come uno slittino |
| shield | si rintana sotto la barchetta rovesciata, fuori solo gli stivali |
| taunt | fischietto, poi indica: "Tu! Lava il ponte!" |
| grab, throw | per il bavero, lanciato come un sacco di patate |
| hit, tumble | il berretto vola via, lui lo riacchiappa brontolando |

## Passo 0 · L'immagine di partenza (Nano Banana, 16:9)

Il disegno nuovo non c'è ancora, quindi prima si fa la posa di partenza, che poi è prima e ultima immagine di tutte le clip. Allega `orsoblu-vecchio-verde.png` (il fermo di oggi ingrandito, solo per chi è) e incolla:

```text
Redesign the pixel-art blue bear in the attached image as a hand-drawn 2D cartoon fighter for a fighting video game. Keep who he is: a blue bear sailor with a small wooden rowboat and an oar. Do NOT keep the pixel-art look.

STYLE: a mix of a classic Italian newspaper comic strip and a whimsical European fantasy-novel ink illustration: bold black ink outlines of even thickness, flat colors with one hard-edged shadow tone, light from front-top, round friendly shapes, very expressive grumpy face, a little fine ink hatching only on the wooden boat and oar. Not 3D, not a render, no gradients, no realistic fur or textures.

CHARACTER: an original stocky anthropomorphic blue bear, a grumpy and fussy old sea captain, standing upright on two legs, body proportioned, head not oversized. Cobalt-indigo fur (#3B4F9A), lighter blue muzzle and belly (#8FA6D8), big round dark nose, thick frowning eyebrows, small stern eyes, scowling mouth. Crooked navy peaked captain's cap (#1F2A44) with a small gold anchor badge (#E0B040). Short mustard-yellow double-breasted pea coat (#D9A520) with brass buttons, open over the belly. Small red neckerchief (#B83A2E). Heavy black sea boots (#2A2A2A). On his back, strapped like a turtle shell, a small upside-down wooden rowboat (#8B5A2B) with a light wooden oar (#C49A6C) strapped across it. A brass whistle on a cord around his neck, a small brass spyglass tucked in his belt, a coiled iron chain hanging at his hip. Nothing else on him.

POSE AND SHOT: full body, side view in three-quarters facing right, fighting-game guard stance: feet apart, fists up in front of the chest, chin down, glaring. Centered, feet near the bottom of the frame, the character fills about two thirds of the frame height.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame. No floor, no shadow, no props, no text.
```

Controllo: blu diverso dal blu dei giocatori (`#3498db`), niente verde addosso, barchetta e remo ben leggibili, faccia burbera. Salvala come `docs/clip-flow/riferimenti/personaggi/orsoblu.png`.

## I blocchi fissi delle clip

Ogni clip = STYLE + CHARACTER + SHOT + ACTION + BACKGROUND + AVOID. Cambia solo ACTION.

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: bold black ink outlines, flat cel shading with one shadow tone, clean round shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the grumpy blue bear sea captain from the reference image. Stocky, standing on two legs. Cobalt-indigo fur (#3B4F9A), lighter blue muzzle and belly (#8FA6D8), big round dark nose, thick frowning eyebrows, scowling mouth. Crooked navy captain's cap (#1F2A44) with a small gold anchor badge (#E0B040). Short mustard-yellow double-breasted pea coat (#D9A520) with brass buttons. Small red neckerchief (#B83A2E). Heavy black sea boots (#2A2A2A). A small upside-down wooden rowboat (#8B5A2B) strapped on his back like a turtle shell, a light wooden oar (#C49A6C) strapped across it. Brass whistle on a cord, small brass spyglass in his belt, coiled iron chain at his hip. Nothing else on him.

SHOT: side view in three-quarters, full body always inside the frame, the character faces right unless the action says otherwise. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

[ACTION della clip]

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no water, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, losing the cap or the boat unless the action says so, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, speech balloons, a second character, a visible anchor or chain flying through the air, motion blur, speed lines, sparkles, slash trails, smoke, dust, water splashes, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

Ogni ACTION inizia con: *"From 0 s to 0.5 s he stands still exactly in the pose of the reference image."* e dopo ogni mossa: *"From X s to Y s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all."* Nelle clip con attacchi, subito dopo la prima frase: *"Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out."*

## Le clip

### OB-01 · Ancora A (la più importante) · `OB-01_ancora-a.mp4`

| Stato | Secondi | Cosa fa |
|---|---|---|
| `recovery` | 0.5-2 | lancio dell'ancora in alto |
| `anchorHang` (nuovo) | 3-5 | appeso che oscilla |
| `anchorClimb` (nuovo) | 6-7.5 | si arrampica sulla catena |

```text
ACTION: 3 short separate moves, each one followed by a pause in the starting pose. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2 s: he grabs the coiled chain at his hip, swings his arm once overhead and hurls it diagonally up and forward toward the top right, then leans back pulling hard with both paws on an invisible taut chain going up to the top right; nothing is drawn in the air. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 3 s to 5 s: he raises both paws above his head gripping an invisible vertical chain, his boots lift slightly off the ground and he swings gently forward and back like a pendulum, legs dangling, scowling; then he lets go and lands on the same spot. From 5 s to 6 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 3, from 6 s to 7.5 s: gripping an invisible vertical chain above his head, he pulls himself up hand over hand twice, boots kicking, then drops back down onto the same spot. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.
```

### OB-02 · Ancora B · `OB-02_ancora-b.mp4`

| Stato | Secondi | Cosa fa |
|---|---|---|
| `specialSide` | 0.5-2 | teleferica verso l'ancora |
| `doubleJump` | 3-4.5 | si stacca con una capriola |
| `specialNeutral` | 5.5-7 | ancora dritta in avanti e strattone |

```text
ACTION: 3 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2 s: both paws gripping an invisible chain angled up to the top right, he yanks it hard and shoots a short way diagonally up and forward with his body stretched straight like a torpedo, one paw holding his cap down, mouth open shouting, then drops back down to the same spot. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 3 s to 4.5 s: he jumps up with both paws raised as if letting go of a rope, does one tight forward somersault in the air with the boat on his back, and lands on the same spot. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 5.5 s to 7 s: he throws his right paw straight forward at chest height as if hurling something, then yanks it back toward his chest with both paws with a mean grin; nothing is drawn in the air. From 7 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.
```

### OB-03 … OB-13 · le altre (stesso schema, ACTION da scrivere con le stesse frasi fisse)

| Codice | Clip | Stati e cosa fanno |
|---|---|---|
| OB-03 | Fermo | `idle` braccia conserte, batte lo stivale, sbuffa dal naso · `walk` passi rigidi da marcia, petto in fuori · `taunt` soffia nel fischietto a guance gonfie, poi punta il dito avanti |
| OB-04 | Salti | `jumpSquat+jump` si accuccia e salta dritto · `fall` braccia che mulinano, si tiene il berretto · `land` atterra pesante e si raddrizza sbuffando |
| OB-05 | Leggeri A | `light` si toglie il berretto e lo sbatte in avanti · `lightUp` cannocchiale puntato dritto in su |
| OB-06 | Leggeri B | `lightDown` calcio basso di stivale alle caviglie · `lightAir` in salto, giravolta col cannocchiale |
| OB-07 | Pesanti A | `heavy` remo dalla schiena, caricato dietro la testa e calato in avanti · `heavyUp` alza la barchetta sopra la testa come un ombrello |
| OB-08 | Pesanti B | `heavyDown` sbatte la barchetta rovesciata a terra davanti a sé come una campana · `heavyAir` in salto, remo che gira attorno al corpo come un'elica |
| OB-09 | Corsa | `dash` corre sul posto chinato, mano sul berretto · `dashAttack` si tuffa a pancia in giù sulla barchetta e scivola avanti come uno slittino |
| OB-10 | Speciali | `specialDown` si china e posa a terra qualcosa con cura, poi indietreggia piano (la mina la disegna il gioco) · `supreme` a gambe larghe, stringe un timone invisibile e sbraita agitando il pugno |
| OB-11 | Difesa | `shield` si accuccia sotto la barchetta, fuori solo stivali e occhi · `grab` afferra per il bavero un avversario invisibile · `throw` lo fa girare e lo lancia come un sacco di patate |
| OB-12 | Colpito | `hit` indietro di scatto, il berretto vola via · `tumble` capriole all'indietro con la barca che gira · `grabbed` sollevato per il bavero, scalcia e agita il pugno |
| OB-13 | Bordo (Ingredients to video) | `ledge` appeso al bordo con le zampe, stivali contro il muro · `climb` risale sul bordo |

## Sprite da disegnare a parte (Nano Banana, sfondo verde)

Ancora di ferro con un pezzo di catena; un tratto di catena orizzontale che si ripete senza stacco; mina navale tonda con le punte, baffi neri arricciati e faccia imbronciata; il timone della suprema; una nuvoletta da fumetto vuota (gli insulti li scrive il gioco).
