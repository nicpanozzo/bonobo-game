<!-- File generato da tools/flow/prompt_flow.py: non modificarlo a mano, cambia lo script e rigeneralo. -->

# Bradipo Giallo: prompt delle clip (BR)

Ondata 1 · 22 clip: 14 del personaggio (solo le mosse nuove) e 8 delle armi. Come si generano, si consegnano e si controllano: [README](../README.md).

Ha già gli stati base dal video di Nicola: qui ci sono solo le mosse nuove di #531. Il basso non c'è: scudo e leggero laterale sono con gli artigli, così basta un'immagine di partenza.

**Immagini da allegare:**

- clip del personaggio: [`docs/clip-flow/riferimenti/personaggi/bradipo.png`](../riferimenti/personaggi/bradipo.png), come prima **e** ultima immagine;
- clip delle armi: `docs/clip-flow/riferimenti/partenze/bradipo_<arma>.png` (passo 1 del README). La clip del lancio della lancia finisce sulla posa senza arma.

**Impostazioni uguali per tutte:** Veo 3.1 (Lite o Fast, vedi README), 16:9, 8 secondi, 1 risultato.

| Codice | Clip | Stati |
|---|---|---|
| [BR-01](#br-01) | Fermo | `crouch`, `taunt`, `turn+skid` |
| [BR-02](#br-02) | Salti | `jumpSquat+land`, `airDodge`, `helpless` |
| [BR-03](#br-03) | Attacchi in corsa | `dashAttack`, `dashGrab` |
| [BR-04](#br-04) | Aerei A | `airForward`, `airUp` |
| [BR-05](#br-05) | Aerei B | `airBack`, `airDown` |
| [BR-06](#br-06) | Recupero | `recovery`, `stunned` |
| [BR-07](#br-07) | Presa | `pummel`, `throwForward` |
| [BR-08](#br-08) | Lanci A | `throwBack`, `throwUp` |
| [BR-09](#br-09) | Lanci B | `throwDown`, `grabbed` |
| [BR-10](#br-10) | Guardia | `shield`, `lightSide` |
| [BR-11](#br-11) | Difesa | `dodge`, `roll+ledgeRoll` |
| [BR-12](#br-12) | A terra A | `tumble+prone+getup` |
| [BR-13](#br-13) | A terra B | `tech`, `getupAttack` |
| [BR-14](#br-14) | Bordo | `ledge`, `climb`, `ledgeAttack` |
| [BR-A1](#br-a1) | Spada: movimento | `spadaIdle`, `spadaWalk`, `spadaAir` |
| [BR-A2](#br-a2) | Spada: attacchi | `spadaLight`, `spadaHeavy` |
| [BR-A3](#br-a3) | Pistola: movimento | `pistolaIdle`, `pistolaWalk`, `pistolaAir` |
| [BR-A4](#br-a4) | Pistola: attacchi | `pistolaLight`, `pistolaHeavy` |
| [BR-A5](#br-a5) | Lancia: movimento | `lanciaIdle`, `lanciaWalk`, `lanciaAir` |
| [BR-A6](#br-a6) | Lancia: attacchi | `lanciaLight`, `lanciaHeavy` |
| [BR-A7](#br-a7) | Lancia: lancio | `lanciaThrow` |
| [BR-A8](#br-a8) | Martello | `martelloIdle`, `martelloWalk`, `martelloJump` |

## BR-01

**Fermo** · file da consegnare: `BR-01_fermo.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/bradipo.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/bradipo.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `crouch` | 0.5-2 | 12-48 | accovacciato |
| `taunt` | 3-4.5 | 72-108 | provocazione |
| `turn+skid` | 5.5-7.5 | 132-180 | si gira e frena |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the yellow sloth fighter from the reference image. Short and stocky, big round head. Golden-yellow fur (#F0C040), cream face with two dark brown eye bands, small black nose, grumpy determined eyebrows. Spiky hot-pink mohawk (#E03080). Plain black t-shirt with no logo or text. Pale cream belly patch. Three long curved silver claws on each hand, short claws on the feet. Nothing else on him.

SHOT: side view in three-quarters, full body always inside the frame, the character faces right unless the action says otherwise. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves, each one followed by a pause in the starting pose. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2 s: he crouches down low on the spot, knees bent and head lowered, holds it for a moment, then stands up. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 3 s to 4.5 s: he headbangs twice, his mohawk bouncing, then raises one hand making the rock horns sign with his claws and sticks his tongue out, laughing. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 3, from 5.5 s to 7.5 s: he quickly turns around to face left and back to face right, then brakes hard on the spot as if stopping from a run, feet dug in, leaning back, arms out for balance. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, extra claws, a tail, clothes other than the black t-shirt, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## BR-02

**Salti** · file da consegnare: `BR-02_salti.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/bradipo.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/bradipo.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `jumpSquat+land` | 0.5-2 | 12-48 | preparazione e atterraggio |
| `airDodge` | 3-4.5 | 72-108 | schivata in aria |
| `helpless` | 5.5-7.5 | 132-180 | caduta indifesa |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the yellow sloth fighter from the reference image. Short and stocky, big round head. Golden-yellow fur (#F0C040), cream face with two dark brown eye bands, small black nose, grumpy determined eyebrows. Spiky hot-pink mohawk (#E03080). Plain black t-shirt with no logo or text. Pale cream belly patch. Three long curved silver claws on each hand, short claws on the feet. Nothing else on him.

SHOT: side view in three-quarters, full body always inside the frame, the character faces right unless the action says otherwise. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves, each one followed by a pause in the starting pose. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2 s: he bends his knees deeply for a split second (squash), jumps straight up, falls back down to the same spot and lands with a strong squash of the knees. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 3 s to 4.5 s: he jumps straight up; at the top he tucks into a quick twisting spin as if dodging, opens up again and lands on the same spot. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 3, from 5.5 s to 7.5 s: he jumps straight up, and at the top he goes limp: exhausted dazed face, arms and legs flailing loosely, no control while he falls back down and lands on the same spot. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, extra claws, a tail, clothes other than the black t-shirt, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## BR-03

**Attacchi in corsa** · file da consegnare: `BR-03_corsa-attacchi.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/bradipo.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/bradipo.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `dashAttack` | 0.5-2.5 | 12-60 | attacco in corsa |
| `dashGrab` | 4-6 | 96-144 | presa in corsa |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the yellow sloth fighter from the reference image. Short and stocky, big round head. Golden-yellow fur (#F0C040), cream face with two dark brown eye bands, small black nose, grumpy determined eyebrows. Spiky hot-pink mohawk (#E03080). Plain black t-shirt with no logo or text. Pale cream belly patch. Three long curved silver claws on each hand, short claws on the feet. Nothing else on him.

SHOT: side view in three-quarters, full body always inside the frame, the character faces right unless the action says otherwise. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he sprints two steps forward, dives low and slides forward on his belly with both claw hands stretched in front of him, then gets back up and steps back to the same spot. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he runs two quick steps forward and lunges with both claw hands stretched far out to grab, sliding a little on his feet, closes his claws on empty air, then steps back to the same spot. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, extra claws, a tail, clothes other than the black t-shirt, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## BR-04

**Aerei A** · file da consegnare: `BR-04_aerei-a.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/bradipo.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/bradipo.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `airForward` | 0.5-2.5 | 12-60 | aereo avanti |
| `airUp` | 4-6 | 96-144 | aereo su |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the yellow sloth fighter from the reference image. Short and stocky, big round head. Golden-yellow fur (#F0C040), cream face with two dark brown eye bands, small black nose, grumpy determined eyebrows. Spiky hot-pink mohawk (#E03080). Plain black t-shirt with no logo or text. Pale cream belly patch. Three long curved silver claws on each hand, short claws on the feet. Nothing else on him.

SHOT: side view in three-quarters, full body always inside the frame, the character faces right unless the action says otherwise. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he jumps straight up; at the top he swings both claw hands forward and down in one quick wide arc in front of him, pulls them back, and lands on the same spot. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he jumps straight up; at the top he swipes one claw hand in one quick arc over his head from front to back, pulls it back, and lands on the same spot. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, extra claws, a tail, clothes other than the black t-shirt, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## BR-05

**Aerei B** · file da consegnare: `BR-05_aerei-b.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/bradipo.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/bradipo.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `airBack` | 0.5-2.5 | 12-60 | aereo indietro |
| `airDown` | 4-6 | 96-144 | aereo giù |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the yellow sloth fighter from the reference image. Short and stocky, big round head. Golden-yellow fur (#F0C040), cream face with two dark brown eye bands, small black nose, grumpy determined eyebrows. Spiky hot-pink mohawk (#E03080). Plain black t-shirt with no logo or text. Pale cream belly patch. Three long curved silver claws on each hand, short claws on the feet. Nothing else on him.

SHOT: side view in three-quarters, full body always inside the frame, the character faces right unless the action says otherwise. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he jumps straight up; at the top, still facing right and without turning around, he kicks backward to the left with both feet together, pulls them back, and lands on the same spot. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he jumps straight up; at the top he pulls his knees up and stomps straight down with both feet together, pulls them back, and lands on the same spot. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, extra claws, a tail, clothes other than the black t-shirt, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## BR-06

**Recupero** · file da consegnare: `BR-06_recupero.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/bradipo.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/bradipo.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `recovery` | 0.5-2.5 | 12-60 | recupero |
| `stunned` | 4-6 | 96-144 | stordito |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the yellow sloth fighter from the reference image. Short and stocky, big round head. Golden-yellow fur (#F0C040), cream face with two dark brown eye bands, small black nose, grumpy determined eyebrows. Spiky hot-pink mohawk (#E03080). Plain black t-shirt with no logo or text. Pale cream belly patch. Three long curved silver claws on each hand, short claws on the feet. Nothing else on him.

SHOT: side view in three-quarters, full body always inside the frame, the character faces right unless the action says otherwise. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he crouches and leaps straight up, spinning around his vertical axis like a drill with both claw hands raised above his head, then falls back down and lands on the same spot. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 4 s to 6 s: he is dizzy on the spot: he wobbles and sways, head circling, knees buckling, arms dangling, but never falls. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, extra claws, a tail, clothes other than the black t-shirt, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## BR-07

**Presa** · file da consegnare: `BR-07_presa.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/bradipo.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/bradipo.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `pummel` | 0.5-2.5 | 12-60 | colpetti |
| `throwForward` | 4-6 | 96-144 | lancio avanti |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the yellow sloth fighter from the reference image. Short and stocky, big round head. Golden-yellow fur (#F0C040), cream face with two dark brown eye bands, small black nose, grumpy determined eyebrows. Spiky hot-pink mohawk (#E03080). Plain black t-shirt with no logo or text. Pale cream belly patch. Three long curved silver claws on each hand, short claws on the feet. Nothing else on him.

SHOT: side view in three-quarters, full body always inside the frame, the character faces right unless the action says otherwise. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he grabs an invisible opponent in front of him with both hands at chest height, holds the empty air firmly and headbutts forward twice, then lets go; nothing is drawn in his hands. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he grabs an invisible opponent in front of him with both hands and hurls it forward with a strong two-handed push; nothing is drawn in his hands. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, extra claws, a tail, clothes other than the black t-shirt, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## BR-08

**Lanci A** · file da consegnare: `BR-08_lanci-a.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/bradipo.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/bradipo.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `throwBack` | 0.5-2.5 | 12-60 | lancio indietro |
| `throwUp` | 4-6 | 96-144 | lancio su |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the yellow sloth fighter from the reference image. Short and stocky, big round head. Golden-yellow fur (#F0C040), cream face with two dark brown eye bands, small black nose, grumpy determined eyebrows. Spiky hot-pink mohawk (#E03080). Plain black t-shirt with no logo or text. Pale cream belly patch. Three long curved silver claws on each hand, short claws on the feet. Nothing else on him.

SHOT: side view in three-quarters, full body always inside the frame, the character faces right unless the action says otherwise. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he grabs an invisible opponent in front of him, spins around and hurls it behind himself, then turns back to face right; nothing is drawn in his hands. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he grabs an invisible opponent in front of him, lifts it above his head and launches it straight up, looking up; nothing is drawn in his hands. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, extra claws, a tail, clothes other than the black t-shirt, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## BR-09

**Lanci B** · file da consegnare: `BR-09_lanci-b.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/bradipo.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/bradipo.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `throwDown` | 0.5-2.5 | 12-60 | lancio giù |
| `grabbed` | 4-6 | 96-144 | tenuto |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the yellow sloth fighter from the reference image. Short and stocky, big round head. Golden-yellow fur (#F0C040), cream face with two dark brown eye bands, small black nose, grumpy determined eyebrows. Spiky hot-pink mohawk (#E03080). Plain black t-shirt with no logo or text. Pale cream belly patch. Three long curved silver claws on each hand, short claws on the feet. Nothing else on him.

SHOT: side view in three-quarters, full body always inside the frame, the character faces right unless the action says otherwise. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he grabs an invisible opponent in front of him, slams it down at his feet and stomps on it once with one foot; nothing is drawn under his foot. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 4 s to 6 s: he is lifted off the ground by the scruff of his neck by an invisible hand: his feet dangle, he squirms and kicks, then he is set back down on his feet; nothing is drawn holding him. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, extra claws, a tail, clothes other than the black t-shirt, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## BR-10

**Guardia** · file da consegnare: `BR-10_guardia.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/bradipo.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/bradipo.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `shield` | 0.5-2.5 | 12-60 | scudo |
| `lightSide` | 4-6 | 96-144 | leggero laterale |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the yellow sloth fighter from the reference image. Short and stocky, big round head. Golden-yellow fur (#F0C040), cream face with two dark brown eye bands, small black nose, grumpy determined eyebrows. Spiky hot-pink mohawk (#E03080). Plain black t-shirt with no logo or text. Pale cream belly patch. Three long curved silver claws on each hand, short claws on the feet. Nothing else on him.

SHOT: side view in three-quarters, full body always inside the frame, the character faces right unless the action says otherwise. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2.5 s: he crouches slightly and crosses both clawed forearms in front of his face as a guard, steady, breathing slowly, eyes narrowed. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: one quick forward jab, thrusting both claw hands forward together like a spear. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, extra claws, a tail, clothes other than the black t-shirt, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## BR-11

**Difesa** · file da consegnare: `BR-11_difesa.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/bradipo.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/bradipo.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `dodge` | 0.5-2.5 | 12-60 | schivata |
| `roll+ledgeRoll` | 4-6 | 96-144 | rotolata avanti e indietro |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the yellow sloth fighter from the reference image. Short and stocky, big round head. Golden-yellow fur (#F0C040), cream face with two dark brown eye bands, small black nose, grumpy determined eyebrows. Spiky hot-pink mohawk (#E03080). Plain black t-shirt with no logo or text. Pale cream belly patch. Three long curved silver claws on each hand, short claws on the feet. Nothing else on him.

SHOT: side view in three-quarters, full body always inside the frame, the character faces right unless the action says otherwise. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2.5 s: he does a quick dodge on the spot, leaning his body back and then returning. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 4 s to 6 s: he rolls forward along the ground in a tight ball and stands up facing left, then immediately rolls back the other way and stands up facing right. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, extra claws, a tail, clothes other than the black t-shirt, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## BR-12

**A terra A** · file da consegnare: `BR-12_a-terra-a.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/bradipo.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/bradipo.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `tumble+prone+getup` | 0.5-6.5 | 12-156 | lanciato via, a terra, si rialza |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the yellow sloth fighter from the reference image. Short and stocky, big round head. Golden-yellow fur (#F0C040), cream face with two dark brown eye bands, small black nose, grumpy determined eyebrows. Spiky hot-pink mohawk (#E03080). Plain black t-shirt with no logo or text. Pale cream belly patch. Three long curved silver claws on each hand, short claws on the feet. Nothing else on him.

SHOT: side view in three-quarters, full body always inside the frame, the character faces right unless the action says otherwise. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: one move, then back to the starting pose. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 6.5 s: he is knocked up into the air as if hit hard, spins head over heels twice with arms and legs spread, falls flat on his back and lies still for a moment, then stands up. From 6.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, extra claws, a tail, clothes other than the black t-shirt, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## BR-13

**A terra B** · file da consegnare: `BR-13_a-terra-b.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/bradipo.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/bradipo.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `tech` | 0.5-2.5 | 12-60 | rimbalzo |
| `getupAttack` | 4-6 | 96-144 | attacco da terra |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the yellow sloth fighter from the reference image. Short and stocky, big round head. Golden-yellow fur (#F0C040), cream face with two dark brown eye bands, small black nose, grumpy determined eyebrows. Spiky hot-pink mohawk (#E03080). Plain black t-shirt with no logo or text. Pale cream belly patch. Three long curved silver claws on each hand, short claws on the feet. Nothing else on him.

SHOT: side view in three-quarters, full body always inside the frame, the character faces right unless the action says otherwise. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2.5 s: he falls flat on his back; the instant he touches the ground he springs back up to his feet with a quick flip. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he falls flat on his back, then spins around on the ground swinging both claw hands in a full circle around himself, and stands up. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, extra claws, a tail, clothes other than the black t-shirt, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## BR-14

**Bordo** · file da consegnare: `BR-14_bordo.mp4`

- **Modalità:** Ingredients to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/bradipo.png`
- Allega l'immagine come unico ingrediente. Il blocco grigio lo toglie lo script.
| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `ledge` | 0-2 | 0-48 | appeso |
| `climb` | 2-3.5 | 48-84 | si tira su |
| `ledgeAttack` | 4.5-6 | 108-144 | attacco dal bordo |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the yellow sloth fighter from the reference image. Short and stocky, big round head. Golden-yellow fur (#F0C040), cream face with two dark brown eye bands, small black nose, grumpy determined eyebrows. Spiky hot-pink mohawk (#E03080). Plain black t-shirt with no logo or text. Pale cream belly patch. Three long curved silver claws on each hand, short claws on the feet. Nothing else on him.

SHOT: side view in three-quarters, full body always inside the frame, the character faces right unless the action says otherwise. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: a plain flat medium-grey block (#808080, no texture) fills the right third of the frame from the bottom up to the middle of the frame; it never moves. From 0 s to 2 s he hangs by both hands from the top-left corner of the block, his body dangling below the edge, facing right toward the block, swinging slightly. From 2 s to 3.5 s he pulls himself up over the corner and stands on top of the block. From 3.5 s to 4.5 s he drops back down and hangs from the corner again. From 4.5 s to 6 s he flips up onto the top of the block with one quick low forward claw swipe. From 6 s to the end of the clip he stands still on top of the block. Everything stays inside the frame for the whole clip.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props except the grey block described above.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, extra claws, a tail, clothes other than the black t-shirt, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## BR-A1

**Spada: movimento** · file da consegnare: `BR-A1_spada-movimento.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/bradipo_spada.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/partenze/bradipo_spada.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `spadaIdle` | 0.5-2 | 12-48 | fermo in guardia |
| `spadaWalk` | 3-4.5 | 72-108 | cammina |
| `spadaAir` | 5.5-7.5 | 132-180 | aereo (in aria) |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the yellow sloth fighter from the reference image. Short and stocky, big round head. Golden-yellow fur (#F0C040), cream face with two dark brown eye bands, small black nose, grumpy determined eyebrows. Spiky hot-pink mohawk (#E03080). Plain black t-shirt with no logo or text. Pale cream belly patch. Three long curved silver claws on each hand, short claws on the feet. Nothing else on him.

WEAPON (must stay identical in every frame): the plasma sword from the reference image. A straight glowing energy blade, solid cyan (#4FD8FF) with a near-white core (#F2FDFF) and a faint cyan halo, rounded tip, no outline on the blade. A metal hilt in steel greys (#A9B0BA, #7F8796): a crown-shaped emitter with three small fins and an amber gem (#F0A93A), a section with vent slots and an amber button, black rubber rings (#2C2F38) between metal ribs, a grooved pommel. The blade is almost as long as the character is tall. The blade is always lit, steady, and never changes color. He holds it between the claws of the hand nearer to the viewer (still three claws per hand), exactly as in the first-frame image.

SHOT: side view in three-quarters, full body always inside the frame, the character faces right unless the action says otherwise. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves with the sword, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2 s: he stands in guard holding the sword steady, breathing calmly. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 3 s to 4.5 s: he walks on the spot, like on a treadmill, four steps, holding the sword steady. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 3, from 5.5 s to 7.5 s: he jumps straight up; at the top he swings the sword in one quick full circle around himself, then lands on the same spot. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, extra claws, a tail, clothes other than the black t-shirt, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```

## BR-A2

**Spada: attacchi** · file da consegnare: `BR-A2_spada-attacchi.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/bradipo_spada.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/partenze/bradipo_spada.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `spadaLight` | 0.5-2.5 | 12-60 | J (leggero) |
| `spadaHeavy` | 4-6 | 96-144 | K (pesante) |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the yellow sloth fighter from the reference image. Short and stocky, big round head. Golden-yellow fur (#F0C040), cream face with two dark brown eye bands, small black nose, grumpy determined eyebrows. Spiky hot-pink mohawk (#E03080). Plain black t-shirt with no logo or text. Pale cream belly patch. Three long curved silver claws on each hand, short claws on the feet. Nothing else on him.

WEAPON (must stay identical in every frame): the plasma sword from the reference image. A straight glowing energy blade, solid cyan (#4FD8FF) with a near-white core (#F2FDFF) and a faint cyan halo, rounded tip, no outline on the blade. A metal hilt in steel greys (#A9B0BA, #7F8796): a crown-shaped emitter with three small fins and an amber gem (#F0A93A), a section with vent slots and an amber button, black rubber rings (#2C2F38) between metal ribs, a grooved pommel. The blade is almost as long as the character is tall. The blade is always lit, steady, and never changes color. He holds it between the claws of the hand nearer to the viewer (still three claws per hand), exactly as in the first-frame image.

SHOT: side view in three-quarters, full body always inside the frame, the character faces right unless the action says otherwise. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves with the sword, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: two quick horizontal slashes forward with the sword, one from left to right and one back from right to left, each pulled straight back. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he raises the sword above his head with both hands for half a second, then one strong vertical slash downward in front of him, and returns to guard. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, extra claws, a tail, clothes other than the black t-shirt, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```

## BR-A3

**Pistola: movimento** · file da consegnare: `BR-A3_pistola-movimento.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/bradipo_pistola.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/partenze/bradipo_pistola.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `pistolaIdle` | 0.5-2 | 12-48 | fermo in guardia |
| `pistolaWalk` | 3-4.5 | 72-108 | cammina |
| `pistolaAir` | 5.5-7.5 | 132-180 | aereo (in aria) |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the yellow sloth fighter from the reference image. Short and stocky, big round head. Golden-yellow fur (#F0C040), cream face with two dark brown eye bands, small black nose, grumpy determined eyebrows. Spiky hot-pink mohawk (#E03080). Plain black t-shirt with no logo or text. Pale cream belly patch. Three long curved silver claws on each hand, short claws on the feet. Nothing else on him.

WEAPON (must stay identical in every frame): the energy pistol from the reference image. A chunky boxy body in light teal (#5C9AA4, shadow #41737C) with a lighter top slide (#7FB6BF) with grip ridges, a glowing amber energy cell (#FFC24A) on the side with small charge notches, small rivets, a short grey barrel (#A6AFB9) with three dark grey cooling fins (#5B6270) and a brass muzzle (#D9B04E). A wooden grip (#94603A, darker #6F4529) with a diamond-checkered panel and a brass screw. About one third of the character's height. He holds it between the claws of the hand nearer to the viewer (still three claws per hand), exactly as in the first-frame image.

SHOT: side view in three-quarters, full body always inside the frame, the character faces right unless the action says otherwise. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves with the pistol, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2 s: he stands in guard holding the pistol steady, breathing calmly. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 3 s to 4.5 s: he walks on the spot, like on a treadmill, four steps, holding the pistol steady. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 3, from 5.5 s to 7.5 s: he jumps straight up; at the top he points the pistol diagonally down in front of him and his wrist jerks once as if firing, then lands on the same spot. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, extra claws, a tail, clothes other than the black t-shirt, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```

## BR-A4

**Pistola: attacchi** · file da consegnare: `BR-A4_pistola-attacchi.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/bradipo_pistola.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/partenze/bradipo_pistola.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `pistolaLight` | 0.5-2.5 | 12-60 | J (leggero) |
| `pistolaHeavy` | 4-6 | 96-144 | K (pesante) |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the yellow sloth fighter from the reference image. Short and stocky, big round head. Golden-yellow fur (#F0C040), cream face with two dark brown eye bands, small black nose, grumpy determined eyebrows. Spiky hot-pink mohawk (#E03080). Plain black t-shirt with no logo or text. Pale cream belly patch. Three long curved silver claws on each hand, short claws on the feet. Nothing else on him.

WEAPON (must stay identical in every frame): the energy pistol from the reference image. A chunky boxy body in light teal (#5C9AA4, shadow #41737C) with a lighter top slide (#7FB6BF) with grip ridges, a glowing amber energy cell (#FFC24A) on the side with small charge notches, small rivets, a short grey barrel (#A6AFB9) with three dark grey cooling fins (#5B6270) and a brass muzzle (#D9B04E). A wooden grip (#94603A, darker #6F4529) with a diamond-checkered panel and a brass screw. About one third of the character's height. He holds it between the claws of the hand nearer to the viewer (still three claws per hand), exactly as in the first-frame image.

SHOT: side view in three-quarters, full body always inside the frame, the character faces right unless the action says otherwise. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves with the pistol, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he extends the arm straight forward, his wrist jerks once as if firing a quick shot, and the arm comes back. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he grips the pistol with both hands, aims straight forward, his arms jerk up as if firing a strong shot and the recoil pushes him one step back, then he steps forward again. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, extra claws, a tail, clothes other than the black t-shirt, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```

## BR-A5

**Lancia: movimento** · file da consegnare: `BR-A5_lancia-movimento.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/bradipo_lancia.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/partenze/bradipo_lancia.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `lanciaIdle` | 0.5-2 | 12-48 | fermo in guardia |
| `lanciaWalk` | 3-4.5 | 72-108 | cammina |
| `lanciaAir` | 5.5-7.5 | 132-180 | aereo (in aria) |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the yellow sloth fighter from the reference image. Short and stocky, big round head. Golden-yellow fur (#F0C040), cream face with two dark brown eye bands, small black nose, grumpy determined eyebrows. Spiky hot-pink mohawk (#E03080). Plain black t-shirt with no logo or text. Pale cream belly patch. Three long curved silver claws on each hand, short claws on the feet. Nothing else on him.

WEAPON (must stay identical in every frame): the stone spear from the reference image. A leaf-shaped grey-blue stone tip (#BCC6CF, shadow #8995A1) with a central ridge and engraved arrow marks. Two curved bone fangs (#EFE2C4) with dark tips at the base of the tip. A red cloth band (#C2452F) with crossed lacing, and a cream cord with two red beads and hanging feathers striped blue (#2F6F9A) and black (#1D2B3A). A twisted wooden shaft (#8F6D46, darker #6A4E31) with stitched dark leather wraps (#4D3B2B) and a small metal butt cap. A little taller than the character. He holds it between the claws of the hand nearer to the viewer (still three claws per hand), exactly as in the first-frame image.

SHOT: side view in three-quarters, full body always inside the frame, the character faces right unless the action says otherwise. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves with the spear, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2 s: he stands in guard holding the spear steady, breathing calmly. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 3 s to 4.5 s: he walks on the spot, like on a treadmill, four steps, holding the spear steady. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 3, from 5.5 s to 7.5 s: he jumps straight up; at the top he thrusts the spear straight down below him, pulls it back, and lands on the same spot. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, extra claws, a tail, clothes other than the black t-shirt, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```

## BR-A6

**Lancia: attacchi** · file da consegnare: `BR-A6_lancia-attacchi.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/bradipo_lancia.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/partenze/bradipo_lancia.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `lanciaLight` | 0.5-2.5 | 12-60 | J (leggero) |
| `lanciaHeavy` | 4-6 | 96-144 | K (pesante) |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the yellow sloth fighter from the reference image. Short and stocky, big round head. Golden-yellow fur (#F0C040), cream face with two dark brown eye bands, small black nose, grumpy determined eyebrows. Spiky hot-pink mohawk (#E03080). Plain black t-shirt with no logo or text. Pale cream belly patch. Three long curved silver claws on each hand, short claws on the feet. Nothing else on him.

WEAPON (must stay identical in every frame): the stone spear from the reference image. A leaf-shaped grey-blue stone tip (#BCC6CF, shadow #8995A1) with a central ridge and engraved arrow marks. Two curved bone fangs (#EFE2C4) with dark tips at the base of the tip. A red cloth band (#C2452F) with crossed lacing, and a cream cord with two red beads and hanging feathers striped blue (#2F6F9A) and black (#1D2B3A). A twisted wooden shaft (#8F6D46, darker #6A4E31) with stitched dark leather wraps (#4D3B2B) and a small metal butt cap. A little taller than the character. He holds it between the claws of the hand nearer to the viewer (still three claws per hand), exactly as in the first-frame image.

SHOT: side view in three-quarters, full body always inside the frame, the character faces right unless the action says otherwise. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves with the spear, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: two quick thrusts of the spear straight forward, each pulled straight back. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he twirls the spear once above his head, then strikes down in front of him with it, and returns to guard. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, extra claws, a tail, clothes other than the black t-shirt, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```

## BR-A7

**Lancia: lancio** · file da consegnare: `BR-A7_lancia-lancio.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/bradipo_lancia.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/bradipo.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `lanciaThrow` | 0.5-2 | 12-48 | lancio |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the yellow sloth fighter from the reference image. Short and stocky, big round head. Golden-yellow fur (#F0C040), cream face with two dark brown eye bands, small black nose, grumpy determined eyebrows. Spiky hot-pink mohawk (#E03080). Plain black t-shirt with no logo or text. Pale cream belly patch. Three long curved silver claws on each hand, short claws on the feet. Nothing else on him.

WEAPON (must stay identical in every frame): the stone spear from the reference image. A leaf-shaped grey-blue stone tip (#BCC6CF, shadow #8995A1) with a central ridge and engraved arrow marks. Two curved bone fangs (#EFE2C4) with dark tips at the base of the tip. A red cloth band (#C2452F) with crossed lacing, and a cream cord with two red beads and hanging feathers striped blue (#2F6F9A) and black (#1D2B3A). A twisted wooden shaft (#8F6D46, darker #6A4E31) with stitched dark leather wraps (#4D3B2B) and a small metal butt cap. A little taller than the character. He holds it between the claws of the hand nearer to the viewer (still three claws per hand), exactly as in the first-frame image.

SHOT: side view in three-quarters, full body always inside the frame, the character faces right unless the action says otherwise. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: one throw. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. From 0.5 s to 2 s he raises the spear above his shoulder, takes one step forward and throws it hard: the spear leaves his hand and flies out of the frame to the right in a straight line within a quarter of a second. From 2 s to the end of the clip, empty-handed, he goes back to exactly the pose of the last-frame image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, extra claws, a tail, clothes other than the black t-shirt, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never duplicates and leaves the frame only when thrown, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```

## BR-A8

**Martello** · file da consegnare: `BR-A8_martello.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/bradipo_martello.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/partenze/bradipo_martello.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `martelloIdle` | 0.5-2.5 | 12-60 | martella fermo |
| `martelloWalk` | 2.5-4.5 | 60-108 | martella camminando |
| `martelloJump` | 4.5-6 | 108-144 | martella saltando |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the yellow sloth fighter from the reference image. Short and stocky, big round head. Golden-yellow fur (#F0C040), cream face with two dark brown eye bands, small black nose, grumpy determined eyebrows. Spiky hot-pink mohawk (#E03080). Plain black t-shirt with no logo or text. Pale cream belly patch. Three long curved silver claws on each hand, short claws on the feet. Nothing else on him.

WEAPON (must stay identical in every frame): the rocket hammer from the reference image. A compact chrome hammer head (#EEF1F5, #C3C8CF, #9AA1AB) with one dark panel (#4B5059) engraved with an X, a white light strip, rivets, a rounded block striking face with a hex bolt, and a small rocket at the back with a vent grille, amber striped fins (#F0A030) and a round nozzle. The rocket never fires: no flames. A long thin dark shaft with rings and a ball joint, a light lower grip with rubber stripes and orange accents, a dark blade-shaped pommel. Taller than the character, always held with both hands. He holds it with both hands on the lower grip, exactly as in the first-frame image.

SHOT: side view in three-quarters, full body always inside the frame, the character faces right unless the action says otherwise. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: hammering. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. From 0.5 s to 2.5 s he swings the hammer up over his head and down in front of him with both hands, striking the empty space in front of his feet, about twice per second. From 2.5 s to 4.5 s he keeps hammering the same way while walking on the spot, like on a treadmill. From 4.5 s to 6 s he keeps hammering during one jump straight up, and lands on the same spot. From 6 s to the end of the clip he is back in exactly the pose of the reference image, the hammer upright, and holds perfectly still. The rocket on the hammer never fires.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, extra claws, a tail, clothes other than the black t-shirt, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```
