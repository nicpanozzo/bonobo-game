<!-- File generato da tools/flow/prompt_flow.py: non modificarlo a mano, cambia lo script e rigeneralo. -->

# Elvedeo: prompt delle clip (EL)

Ondata 2 · 22 clip: 14 del personaggio (solo le mosse nuove) e 8 delle armi. Come si generano, si consegnano e si controllano: [README](../README.md).

Ha già fermo, corsa, salto, colpi, speciali e suprema dai video di Nicola: qui ci sono solo le mosse nuove, più doppio salto e pesante in aria. È sempre in sella: in un video vecchio Flow lo aveva messo a piedi. La fascia verde del berretto è verde scuro apposta: controlla che lo scontorno non la buchi.

**Immagini da allegare:**

- clip del personaggio: [`docs/clip-flow/riferimenti/personaggi/elvedeo.png`](../riferimenti/personaggi/elvedeo.png), come prima **e** ultima immagine;
- clip delle armi: `docs/clip-flow/riferimenti/partenze/elvedeo_<arma>.png` (passo 1 del README). La clip del lancio della lancia finisce sulla posa senza arma.

**Impostazioni uguali per tutte:** Veo 3.1 (Lite o Fast, vedi README), 16:9, 8 secondi, 1 risultato.

| Codice | Clip | Stati |
|---|---|---|
| [EL-01](#el-01) | Fermo | `crouch`, `taunt`, `turn+skid` |
| [EL-02](#el-02) | Salti | `jumpSquat+doubleJump+land`, `airDodge`, `helpless` |
| [EL-03](#el-03) | Attacchi in corsa | `dashAttack`, `dashGrab` |
| [EL-04](#el-04) | Aerei A | `airForward`, `airUp` |
| [EL-05](#el-05) | Aerei B | `airBack`, `airDown` |
| [EL-06](#el-06) | Recupero | `recovery`, `heavyAir`, `stunned` |
| [EL-07](#el-07) | Presa | `pummel`, `throwForward` |
| [EL-08](#el-08) | Lanci A | `throwBack`, `throwUp` |
| [EL-09](#el-09) | Lanci B | `throwDown`, `grabbed` |
| [EL-10](#el-10) | Guardia | `shield`, `lightSide` |
| [EL-11](#el-11) | Difesa | `dodge`, `roll+ledgeRoll` |
| [EL-12](#el-12) | A terra A | `tumble+prone+getup` |
| [EL-13](#el-13) | A terra B | `tech`, `getupAttack` |
| [EL-14](#el-14) | Bordo | `ledge`, `climb`, `ledgeAttack` |
| [EL-A1](#el-a1) | Spada: movimento | `spadaIdle`, `spadaWalk`, `spadaAir` |
| [EL-A2](#el-a2) | Spada: attacchi | `spadaLight`, `spadaHeavy` |
| [EL-A3](#el-a3) | Pistola: movimento | `pistolaIdle`, `pistolaWalk`, `pistolaAir` |
| [EL-A4](#el-a4) | Pistola: attacchi | `pistolaLight`, `pistolaHeavy` |
| [EL-A5](#el-a5) | Lancia: movimento | `lanciaIdle`, `lanciaWalk`, `lanciaAir` |
| [EL-A6](#el-a6) | Lancia: attacchi | `lanciaLight`, `lanciaHeavy` |
| [EL-A7](#el-a7) | Lancia: lancio | `lanciaThrow` |
| [EL-A8](#el-a8) | Martello | `martelloIdle`, `martelloWalk`, `martelloJump` |

## EL-01

**Fermo** · file da consegnare: `EL-01_fermo.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/elvedeo.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/elvedeo.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `crouch` | 0.5-2 | 12-48 | accovacciato |
| `taunt` | 3-4.5 | 72-108 | provocazione |
| `turn+skid` | 5.5-7.5 | 132-180 | si gira e frena |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same faces): the rasta rider from the reference image, always sitting on his goat. The man: skinny, long face, short beard, round dark sunglasses, long dark-brown dreadlocks with small red, yellow and green beads, a big knitted rasta tam hat with stripes of deep red (#90352D), golden yellow (#E2B85A) and dark forest green (#2F5A2E). An unlit joint in his mouth, never lit, no smoke. Ripped black t-shirt (#261D18), baggy mustard-khaki trousers (#BF9955) with dirt stains, grey crocs (#7E7168). He holds red rope reins in one hand and a long thin wooden staff in the other. A grey pigeon (#625C56, lighter wings #9A8D76) always perched on his shoulder. The goat: white (#F0E0CD) with irregular brown patches (#906E4F), curved grey-brown horns, small goatee, yellow eyes, a red rope collar with a small brass bell.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves, each one followed by a pause in the starting pose. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2 s: the goat bends its legs and crouches low while he leans forward over its neck, they hold it for a moment, then they stand up. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 3 s to 4.5 s: he grins and taps the unlit joint in his mouth, while the pigeon on his shoulder puffs up its chest and bobs its head. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 3, from 5.5 s to 7.5 s: the goat quickly turns around to face left and back to face right, then brakes hard on the spot as if stopping from a gallop, hooves dug in, while he leans back holding the reins. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, the man walking on foot or getting off the goat, a second goat, a second bird, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EL-02

**Salti** · file da consegnare: `EL-02_salti.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/elvedeo.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/elvedeo.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `jumpSquat+doubleJump+land` | 0.5-2 | 12-48 | preparazione, doppio salto, atterraggio |
| `airDodge` | 3-4.5 | 72-108 | schivata in aria |
| `helpless` | 5.5-7.5 | 132-180 | caduta indifesa |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same faces): the rasta rider from the reference image, always sitting on his goat. The man: skinny, long face, short beard, round dark sunglasses, long dark-brown dreadlocks with small red, yellow and green beads, a big knitted rasta tam hat with stripes of deep red (#90352D), golden yellow (#E2B85A) and dark forest green (#2F5A2E). An unlit joint in his mouth, never lit, no smoke. Ripped black t-shirt (#261D18), baggy mustard-khaki trousers (#BF9955) with dirt stains, grey crocs (#7E7168). He holds red rope reins in one hand and a long thin wooden staff in the other. A grey pigeon (#625C56, lighter wings #9A8D76) always perched on his shoulder. The goat: white (#F0E0CD) with irregular brown patches (#906E4F), curved grey-brown horns, small goatee, yellow eyes, a red rope collar with a small brass bell.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves, each one followed by a pause in the starting pose. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2 s: the goat bends its legs (squash) and jumps straight up with him on its back, does a second jump in mid-air kicking out with its hind legs, falls back down and lands on the same spot with a strong squash. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 3 s to 4.5 s: the goat jumps straight up with him on its back; at the top it tucks its legs and they do a quick twisting spin as if dodging, then they land on the same spot. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 3, from 5.5 s to 7.5 s: the goat jumps straight up with him on its back; at the top they both go limp, he slumps off balance with a dazed face, the goat's legs dangle loosely, and they fall back down and land on the same spot. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, the man walking on foot or getting off the goat, a second goat, a second bird, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EL-03

**Attacchi in corsa** · file da consegnare: `EL-03_corsa-attacchi.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/elvedeo.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/elvedeo.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `dashAttack` | 0.5-2.5 | 12-60 | attacco in corsa |
| `dashGrab` | 4-6 | 96-144 | presa in corsa |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same faces): the rasta rider from the reference image, always sitting on his goat. The man: skinny, long face, short beard, round dark sunglasses, long dark-brown dreadlocks with small red, yellow and green beads, a big knitted rasta tam hat with stripes of deep red (#90352D), golden yellow (#E2B85A) and dark forest green (#2F5A2E). An unlit joint in his mouth, never lit, no smoke. Ripped black t-shirt (#261D18), baggy mustard-khaki trousers (#BF9955) with dirt stains, grey crocs (#7E7168). He holds red rope reins in one hand and a long thin wooden staff in the other. A grey pigeon (#625C56, lighter wings #9A8D76) always perched on his shoulder. The goat: white (#F0E0CD) with irregular brown patches (#906E4F), curved grey-brown horns, small goatee, yellow eyes, a red rope collar with a small brass bell.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: the goat charges two quick strides forward and he strikes forward with his staff, then they step back to the same spot. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: the goat charges two quick strides forward and he leans out reaching far with his free hand to grab, closes it on empty air, then they step back to the same spot. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, the man walking on foot or getting off the goat, a second goat, a second bird, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EL-04

**Aerei A** · file da consegnare: `EL-04_aerei-a.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/elvedeo.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/elvedeo.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `airForward` | 0.5-2.5 | 12-60 | aereo avanti |
| `airUp` | 4-6 | 96-144 | aereo su |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same faces): the rasta rider from the reference image, always sitting on his goat. The man: skinny, long face, short beard, round dark sunglasses, long dark-brown dreadlocks with small red, yellow and green beads, a big knitted rasta tam hat with stripes of deep red (#90352D), golden yellow (#E2B85A) and dark forest green (#2F5A2E). An unlit joint in his mouth, never lit, no smoke. Ripped black t-shirt (#261D18), baggy mustard-khaki trousers (#BF9955) with dirt stains, grey crocs (#7E7168). He holds red rope reins in one hand and a long thin wooden staff in the other. A grey pigeon (#625C56, lighter wings #9A8D76) always perched on his shoulder. The goat: white (#F0E0CD) with irregular brown patches (#906E4F), curved grey-brown horns, small goatee, yellow eyes, a red rope collar with a small brass bell.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: the goat jumps straight up with him on its back; at the top he swings his staff forward and down in one quick arc in front of them, pulls it back, and they land on the same spot. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: the goat jumps straight up with him on its back; at the top he twirls his staff once above his head, and they land on the same spot. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, the man walking on foot or getting off the goat, a second goat, a second bird, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EL-05

**Aerei B** · file da consegnare: `EL-05_aerei-b.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/elvedeo.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/elvedeo.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `airBack` | 0.5-2.5 | 12-60 | aereo indietro |
| `airDown` | 4-6 | 96-144 | aereo giù |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same faces): the rasta rider from the reference image, always sitting on his goat. The man: skinny, long face, short beard, round dark sunglasses, long dark-brown dreadlocks with small red, yellow and green beads, a big knitted rasta tam hat with stripes of deep red (#90352D), golden yellow (#E2B85A) and dark forest green (#2F5A2E). An unlit joint in his mouth, never lit, no smoke. Ripped black t-shirt (#261D18), baggy mustard-khaki trousers (#BF9955) with dirt stains, grey crocs (#7E7168). He holds red rope reins in one hand and a long thin wooden staff in the other. A grey pigeon (#625C56, lighter wings #9A8D76) always perched on his shoulder. The goat: white (#F0E0CD) with irregular brown patches (#906E4F), curved grey-brown horns, small goatee, yellow eyes, a red rope collar with a small brass bell.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: the goat jumps straight up with him on its back; at the top the goat kicks backward to the left with both hind legs, pulls them back, and they land on the same spot. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: the goat jumps straight up with him on its back; at the top the goat stomps straight down with all four hooves together, and they land on the same spot. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, the man walking on foot or getting off the goat, a second goat, a second bird, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EL-06

**Recupero** · file da consegnare: `EL-06_recupero.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/elvedeo.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/elvedeo.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `recovery` | 0.5-2 | 12-48 | recupero |
| `heavyAir` | 3-4.5 | 72-108 | pesante in aria |
| `stunned` | 5.5-7.5 | 132-180 | stordito |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same faces): the rasta rider from the reference image, always sitting on his goat. The man: skinny, long face, short beard, round dark sunglasses, long dark-brown dreadlocks with small red, yellow and green beads, a big knitted rasta tam hat with stripes of deep red (#90352D), golden yellow (#E2B85A) and dark forest green (#2F5A2E). An unlit joint in his mouth, never lit, no smoke. Ripped black t-shirt (#261D18), baggy mustard-khaki trousers (#BF9955) with dirt stains, grey crocs (#7E7168). He holds red rope reins in one hand and a long thin wooden staff in the other. A grey pigeon (#625C56, lighter wings #9A8D76) always perched on his shoulder. The goat: white (#F0E0CD) with irregular brown patches (#906E4F), curved grey-brown horns, small goatee, yellow eyes, a red rope collar with a small brass bell.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2 s: the goat crouches and makes one huge leap straight up like a mountain ibex with him on its back, and they fall back down and land on the same spot. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 3 s to 4.5 s: the goat jumps straight up with him on its back; at the top he raises his staff high with both hands and brings it down in one big overhead blow in front of them, and they land on the same spot. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 3, from 5.5 s to 7.5 s: they are both dizzy on the spot: the goat wobbles on unsteady legs, he sways in the saddle with his head circling, but they never fall. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, the man walking on foot or getting off the goat, a second goat, a second bird, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EL-07

**Presa** · file da consegnare: `EL-07_presa.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/elvedeo.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/elvedeo.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `pummel` | 0.5-2.5 | 12-60 | colpetti |
| `throwForward` | 4-6 | 96-144 | lancio avanti |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same faces): the rasta rider from the reference image, always sitting on his goat. The man: skinny, long face, short beard, round dark sunglasses, long dark-brown dreadlocks with small red, yellow and green beads, a big knitted rasta tam hat with stripes of deep red (#90352D), golden yellow (#E2B85A) and dark forest green (#2F5A2E). An unlit joint in his mouth, never lit, no smoke. Ripped black t-shirt (#261D18), baggy mustard-khaki trousers (#BF9955) with dirt stains, grey crocs (#7E7168). He holds red rope reins in one hand and a long thin wooden staff in the other. A grey pigeon (#625C56, lighter wings #9A8D76) always perched on his shoulder. The goat: white (#F0E0CD) with irregular brown patches (#906E4F), curved grey-brown horns, small goatee, yellow eyes, a red rope collar with a small brass bell.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he grabs an invisible opponent in front of the goat with his free hand and hits it twice with the butt of his staff, then lets go; nothing is drawn in his hand. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he grabs an invisible opponent in front of the goat with his free hand and shoves it away forward with his staff; nothing is drawn in his hand. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, the man walking on foot or getting off the goat, a second goat, a second bird, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EL-08

**Lanci A** · file da consegnare: `EL-08_lanci-a.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/elvedeo.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/elvedeo.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `throwBack` | 0.5-2.5 | 12-60 | lancio indietro |
| `throwUp` | 4-6 | 96-144 | lancio su |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same faces): the rasta rider from the reference image, always sitting on his goat. The man: skinny, long face, short beard, round dark sunglasses, long dark-brown dreadlocks with small red, yellow and green beads, a big knitted rasta tam hat with stripes of deep red (#90352D), golden yellow (#E2B85A) and dark forest green (#2F5A2E). An unlit joint in his mouth, never lit, no smoke. Ripped black t-shirt (#261D18), baggy mustard-khaki trousers (#BF9955) with dirt stains, grey crocs (#7E7168). He holds red rope reins in one hand and a long thin wooden staff in the other. A grey pigeon (#625C56, lighter wings #9A8D76) always perched on his shoulder. The goat: white (#F0E0CD) with irregular brown patches (#906E4F), curved grey-brown horns, small goatee, yellow eyes, a red rope collar with a small brass bell.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he grabs an invisible opponent in front of the goat and passes it behind them, and the goat kicks it away backward with both hind legs; nothing is drawn. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he grabs an invisible opponent in front of the goat, and the goat tosses it straight up with a quick upward butt of its horns; nothing is drawn. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, the man walking on foot or getting off the goat, a second goat, a second bird, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EL-09

**Lanci B** · file da consegnare: `EL-09_lanci-b.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/elvedeo.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/elvedeo.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `throwDown` | 0.5-2.5 | 12-60 | lancio giù |
| `grabbed` | 4-6 | 96-144 | tenuto |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same faces): the rasta rider from the reference image, always sitting on his goat. The man: skinny, long face, short beard, round dark sunglasses, long dark-brown dreadlocks with small red, yellow and green beads, a big knitted rasta tam hat with stripes of deep red (#90352D), golden yellow (#E2B85A) and dark forest green (#2F5A2E). An unlit joint in his mouth, never lit, no smoke. Ripped black t-shirt (#261D18), baggy mustard-khaki trousers (#BF9955) with dirt stains, grey crocs (#7E7168). He holds red rope reins in one hand and a long thin wooden staff in the other. A grey pigeon (#625C56, lighter wings #9A8D76) always perched on his shoulder. The goat: white (#F0E0CD) with irregular brown patches (#906E4F), curved grey-brown horns, small goatee, yellow eyes, a red rope collar with a small brass bell.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he grabs an invisible opponent in front of the goat and slams it down in front of them, and the goat stomps on it once with its front hooves; nothing is drawn. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 4 s to 6 s: he is pulled up by the back of his t-shirt by an invisible hand, half lifted out of the saddle, while the goat kicks its legs in the air; then he drops back into the saddle; nothing is drawn holding him. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, the man walking on foot or getting off the goat, a second goat, a second bird, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EL-10

**Guardia** · file da consegnare: `EL-10_guardia.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/elvedeo.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/elvedeo.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `shield` | 0.5-2.5 | 12-60 | scudo |
| `lightSide` | 4-6 | 96-144 | leggero laterale |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same faces): the rasta rider from the reference image, always sitting on his goat. The man: skinny, long face, short beard, round dark sunglasses, long dark-brown dreadlocks with small red, yellow and green beads, a big knitted rasta tam hat with stripes of deep red (#90352D), golden yellow (#E2B85A) and dark forest green (#2F5A2E). An unlit joint in his mouth, never lit, no smoke. Ripped black t-shirt (#261D18), baggy mustard-khaki trousers (#BF9955) with dirt stains, grey crocs (#7E7168). He holds red rope reins in one hand and a long thin wooden staff in the other. A grey pigeon (#625C56, lighter wings #9A8D76) always perched on his shoulder. The goat: white (#F0E0CD) with irregular brown patches (#906E4F), curved grey-brown horns, small goatee, yellow eyes, a red rope collar with a small brass bell.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2.5 s: he holds his staff crosswise in front of himself as a guard while the goat lowers its head and braces, steady. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: one quick poke forward with the tip of his staff. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, the man walking on foot or getting off the goat, a second goat, a second bird, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EL-11

**Difesa** · file da consegnare: `EL-11_difesa.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/elvedeo.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/elvedeo.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `dodge` | 0.5-2.5 | 12-60 | schivata |
| `roll+ledgeRoll` | 4-6 | 96-144 | rotolata avanti e indietro |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same faces): the rasta rider from the reference image, always sitting on his goat. The man: skinny, long face, short beard, round dark sunglasses, long dark-brown dreadlocks with small red, yellow and green beads, a big knitted rasta tam hat with stripes of deep red (#90352D), golden yellow (#E2B85A) and dark forest green (#2F5A2E). An unlit joint in his mouth, never lit, no smoke. Ripped black t-shirt (#261D18), baggy mustard-khaki trousers (#BF9955) with dirt stains, grey crocs (#7E7168). He holds red rope reins in one hand and a long thin wooden staff in the other. A grey pigeon (#625C56, lighter wings #9A8D76) always perched on his shoulder. The goat: white (#F0E0CD) with irregular brown patches (#906E4F), curved grey-brown horns, small goatee, yellow eyes, a red rope collar with a small brass bell.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2.5 s: the goat makes a quick hop to the side and back, with him on its back. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 4 s to 6 s: the goat dashes quickly forward a short distance staying low, then dashes back to the same spot, with him on its back. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, the man walking on foot or getting off the goat, a second goat, a second bird, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EL-12

**A terra A** · file da consegnare: `EL-12_a-terra-a.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/elvedeo.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/elvedeo.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `tumble+prone+getup` | 0.5-6.5 | 12-156 | lanciato via, a terra, si rialza |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same faces): the rasta rider from the reference image, always sitting on his goat. The man: skinny, long face, short beard, round dark sunglasses, long dark-brown dreadlocks with small red, yellow and green beads, a big knitted rasta tam hat with stripes of deep red (#90352D), golden yellow (#E2B85A) and dark forest green (#2F5A2E). An unlit joint in his mouth, never lit, no smoke. Ripped black t-shirt (#261D18), baggy mustard-khaki trousers (#BF9955) with dirt stains, grey crocs (#7E7168). He holds red rope reins in one hand and a long thin wooden staff in the other. A grey pigeon (#625C56, lighter wings #9A8D76) always perched on his shoulder. The goat: white (#F0E0CD) with irregular brown patches (#906E4F), curved grey-brown horns, small goatee, yellow eyes, a red rope collar with a small brass bell.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: one move, then back to the starting pose. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 6.5 s: they are knocked up into the air as if hit hard and spin around once together, then the goat falls and lies down on its belly with him slumped forward on its neck, they hold still for a moment, then the goat gets up with him still riding. From 6.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, the man walking on foot or getting off the goat, a second goat, a second bird, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EL-13

**A terra B** · file da consegnare: `EL-13_a-terra-b.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/elvedeo.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/elvedeo.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `tech` | 0.5-2.5 | 12-60 | rimbalzo |
| `getupAttack` | 4-6 | 96-144 | attacco da terra |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same faces): the rasta rider from the reference image, always sitting on his goat. The man: skinny, long face, short beard, round dark sunglasses, long dark-brown dreadlocks with small red, yellow and green beads, a big knitted rasta tam hat with stripes of deep red (#90352D), golden yellow (#E2B85A) and dark forest green (#2F5A2E). An unlit joint in his mouth, never lit, no smoke. Ripped black t-shirt (#261D18), baggy mustard-khaki trousers (#BF9955) with dirt stains, grey crocs (#7E7168). He holds red rope reins in one hand and a long thin wooden staff in the other. A grey pigeon (#625C56, lighter wings #9A8D76) always perched on his shoulder. The goat: white (#F0E0CD) with irregular brown patches (#906E4F), curved grey-brown horns, small goatee, yellow eyes, a red rope collar with a small brass bell.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2.5 s: the goat falls on its belly with him on its back; the instant it touches the ground it springs back up onto its hooves. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: the goat lies down on its belly, then gets up kicking out all around with its legs while he swings his staff in a circle. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, the man walking on foot or getting off the goat, a second goat, a second bird, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EL-14

**Bordo** · file da consegnare: `EL-14_bordo.mp4`

- **Modalità:** Ingredients to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/elvedeo.png`
- Allega l'immagine come unico ingrediente. Il blocco grigio lo toglie lo script.
| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `ledge` | 0-2 | 0-48 | appeso |
| `climb` | 2-3.5 | 48-84 | si tira su |
| `ledgeAttack` | 4.5-6 | 108-144 | attacco dal bordo |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same faces): the rasta rider from the reference image, always sitting on his goat. The man: skinny, long face, short beard, round dark sunglasses, long dark-brown dreadlocks with small red, yellow and green beads, a big knitted rasta tam hat with stripes of deep red (#90352D), golden yellow (#E2B85A) and dark forest green (#2F5A2E). An unlit joint in his mouth, never lit, no smoke. Ripped black t-shirt (#261D18), baggy mustard-khaki trousers (#BF9955) with dirt stains, grey crocs (#7E7168). He holds red rope reins in one hand and a long thin wooden staff in the other. A grey pigeon (#625C56, lighter wings #9A8D76) always perched on his shoulder. The goat: white (#F0E0CD) with irregular brown patches (#906E4F), curved grey-brown horns, small goatee, yellow eyes, a red rope collar with a small brass bell.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: a plain flat medium-grey block (#808080, no texture) fills the right third of the frame from the bottom up to the middle of the frame; it never moves. From 0 s to 2 s the goat hangs by its front hooves from the top-left corner of the block, with him holding on to its neck and the staff, facing right toward the block, swinging slightly. From 2 s to 3.5 s they pull up over the corner and stand on top of the block. From 3.5 s to 4.5 s they drop back down and hang from the corner again. From 4.5 s to 6 s they flip up onto the top of the block with one quick staff swing forward, low. From 6 s to the end of the clip they stand still on top of the block. Everything stays inside the frame for the whole clip.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props except the grey block described above.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, the man walking on foot or getting off the goat, a second goat, a second bird, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EL-A1

**Spada: movimento** · file da consegnare: `EL-A1_spada-movimento.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/elvedeo_spada.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/partenze/elvedeo_spada.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `spadaIdle` | 0.5-2 | 12-48 | fermo in guardia |
| `spadaWalk` | 3-4.5 | 72-108 | cammina |
| `spadaAir` | 5.5-7.5 | 132-180 | aereo (in aria) |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same faces): the rasta rider from the reference image, always sitting on his goat. The man: skinny, long face, short beard, round dark sunglasses, long dark-brown dreadlocks with small red, yellow and green beads, a big knitted rasta tam hat with stripes of deep red (#90352D), golden yellow (#E2B85A) and dark forest green (#2F5A2E). An unlit joint in his mouth, never lit, no smoke. Ripped black t-shirt (#261D18), baggy mustard-khaki trousers (#BF9955) with dirt stains, grey crocs (#7E7168). He holds red rope reins in one hand and a long thin wooden staff in the other. A grey pigeon (#625C56, lighter wings #9A8D76) always perched on his shoulder. The goat: white (#F0E0CD) with irregular brown patches (#906E4F), curved grey-brown horns, small goatee, yellow eyes, a red rope collar with a small brass bell.

WEAPON (must stay identical in every frame): the plasma sword from the reference image. A straight glowing energy blade, solid cyan (#4FD8FF) with a near-white core (#F2FDFF) and a faint cyan halo, rounded tip, no outline on the blade. A metal hilt in steel greys (#A9B0BA, #7F8796): a crown-shaped emitter with three small fins and an amber gem (#F0A93A), a section with vent slots and an amber button, black rubber rings (#2C2F38) between metal ribs, a grooved pommel. The blade is almost as long as the character is tall. The blade is always lit, steady, and never changes color. He holds it in the hand that used to hold the staff: in this image there is no staff, and the reins stay in the other hand, exactly as in the first-frame image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves with the sword, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2 s: he stands in guard holding the sword steady, breathing calmly. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 3 s to 4.5 s: the goat walks on the spot, like on a treadmill, four steps, while he keeps holding the sword steady. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 3, from 5.5 s to 7.5 s: the goat jumps straight up with him on its back; at the top he swings the sword in one quick full circle around himself, then they land on the same spot. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, the man walking on foot or getting off the goat, a second goat, a second bird, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```

## EL-A2

**Spada: attacchi** · file da consegnare: `EL-A2_spada-attacchi.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/elvedeo_spada.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/partenze/elvedeo_spada.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `spadaLight` | 0.5-2.5 | 12-60 | J (leggero) |
| `spadaHeavy` | 4-6 | 96-144 | K (pesante) |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same faces): the rasta rider from the reference image, always sitting on his goat. The man: skinny, long face, short beard, round dark sunglasses, long dark-brown dreadlocks with small red, yellow and green beads, a big knitted rasta tam hat with stripes of deep red (#90352D), golden yellow (#E2B85A) and dark forest green (#2F5A2E). An unlit joint in his mouth, never lit, no smoke. Ripped black t-shirt (#261D18), baggy mustard-khaki trousers (#BF9955) with dirt stains, grey crocs (#7E7168). He holds red rope reins in one hand and a long thin wooden staff in the other. A grey pigeon (#625C56, lighter wings #9A8D76) always perched on his shoulder. The goat: white (#F0E0CD) with irregular brown patches (#906E4F), curved grey-brown horns, small goatee, yellow eyes, a red rope collar with a small brass bell.

WEAPON (must stay identical in every frame): the plasma sword from the reference image. A straight glowing energy blade, solid cyan (#4FD8FF) with a near-white core (#F2FDFF) and a faint cyan halo, rounded tip, no outline on the blade. A metal hilt in steel greys (#A9B0BA, #7F8796): a crown-shaped emitter with three small fins and an amber gem (#F0A93A), a section with vent slots and an amber button, black rubber rings (#2C2F38) between metal ribs, a grooved pommel. The blade is almost as long as the character is tall. The blade is always lit, steady, and never changes color. He holds it in the hand that used to hold the staff: in this image there is no staff, and the reins stay in the other hand, exactly as in the first-frame image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves with the sword, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: two quick horizontal slashes forward with the sword, one from left to right and one back from right to left, each pulled straight back. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he raises the sword above his head with both hands for half a second, then one strong vertical slash downward in front of him, and returns to guard. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, the man walking on foot or getting off the goat, a second goat, a second bird, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```

## EL-A3

**Pistola: movimento** · file da consegnare: `EL-A3_pistola-movimento.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/elvedeo_pistola.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/partenze/elvedeo_pistola.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `pistolaIdle` | 0.5-2 | 12-48 | fermo in guardia |
| `pistolaWalk` | 3-4.5 | 72-108 | cammina |
| `pistolaAir` | 5.5-7.5 | 132-180 | aereo (in aria) |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same faces): the rasta rider from the reference image, always sitting on his goat. The man: skinny, long face, short beard, round dark sunglasses, long dark-brown dreadlocks with small red, yellow and green beads, a big knitted rasta tam hat with stripes of deep red (#90352D), golden yellow (#E2B85A) and dark forest green (#2F5A2E). An unlit joint in his mouth, never lit, no smoke. Ripped black t-shirt (#261D18), baggy mustard-khaki trousers (#BF9955) with dirt stains, grey crocs (#7E7168). He holds red rope reins in one hand and a long thin wooden staff in the other. A grey pigeon (#625C56, lighter wings #9A8D76) always perched on his shoulder. The goat: white (#F0E0CD) with irregular brown patches (#906E4F), curved grey-brown horns, small goatee, yellow eyes, a red rope collar with a small brass bell.

WEAPON (must stay identical in every frame): the energy pistol from the reference image. A chunky boxy body in light teal (#5C9AA4, shadow #41737C) with a lighter top slide (#7FB6BF) with grip ridges, a glowing amber energy cell (#FFC24A) on the side with small charge notches, small rivets, a short grey barrel (#A6AFB9) with three dark grey cooling fins (#5B6270) and a brass muzzle (#D9B04E). A wooden grip (#94603A, darker #6F4529) with a diamond-checkered panel and a brass screw. About one third of the character's height. He holds it in the hand that used to hold the staff: in this image there is no staff, and the reins stay in the other hand, exactly as in the first-frame image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves with the pistol, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2 s: he stands in guard holding the pistol steady, breathing calmly. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 3 s to 4.5 s: the goat walks on the spot, like on a treadmill, four steps, while he keeps holding the pistol steady. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 3, from 5.5 s to 7.5 s: the goat jumps straight up with him on its back; at the top he points the pistol diagonally down in front of him and his wrist jerks once as if firing, then they land on the same spot. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, the man walking on foot or getting off the goat, a second goat, a second bird, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```

## EL-A4

**Pistola: attacchi** · file da consegnare: `EL-A4_pistola-attacchi.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/elvedeo_pistola.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/partenze/elvedeo_pistola.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `pistolaLight` | 0.5-2.5 | 12-60 | J (leggero) |
| `pistolaHeavy` | 4-6 | 96-144 | K (pesante) |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same faces): the rasta rider from the reference image, always sitting on his goat. The man: skinny, long face, short beard, round dark sunglasses, long dark-brown dreadlocks with small red, yellow and green beads, a big knitted rasta tam hat with stripes of deep red (#90352D), golden yellow (#E2B85A) and dark forest green (#2F5A2E). An unlit joint in his mouth, never lit, no smoke. Ripped black t-shirt (#261D18), baggy mustard-khaki trousers (#BF9955) with dirt stains, grey crocs (#7E7168). He holds red rope reins in one hand and a long thin wooden staff in the other. A grey pigeon (#625C56, lighter wings #9A8D76) always perched on his shoulder. The goat: white (#F0E0CD) with irregular brown patches (#906E4F), curved grey-brown horns, small goatee, yellow eyes, a red rope collar with a small brass bell.

WEAPON (must stay identical in every frame): the energy pistol from the reference image. A chunky boxy body in light teal (#5C9AA4, shadow #41737C) with a lighter top slide (#7FB6BF) with grip ridges, a glowing amber energy cell (#FFC24A) on the side with small charge notches, small rivets, a short grey barrel (#A6AFB9) with three dark grey cooling fins (#5B6270) and a brass muzzle (#D9B04E). A wooden grip (#94603A, darker #6F4529) with a diamond-checkered panel and a brass screw. About one third of the character's height. He holds it in the hand that used to hold the staff: in this image there is no staff, and the reins stay in the other hand, exactly as in the first-frame image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves with the pistol, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he extends the arm straight forward, his wrist jerks once as if firing a quick shot, and the arm comes back. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he grips the pistol with both hands, aims straight forward, his arms jerk up as if firing a strong shot and the recoil pushes the goat one step back, then the goat steps forward again. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, the man walking on foot or getting off the goat, a second goat, a second bird, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```

## EL-A5

**Lancia: movimento** · file da consegnare: `EL-A5_lancia-movimento.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/elvedeo_lancia.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/partenze/elvedeo_lancia.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `lanciaIdle` | 0.5-2 | 12-48 | fermo in guardia |
| `lanciaWalk` | 3-4.5 | 72-108 | cammina |
| `lanciaAir` | 5.5-7.5 | 132-180 | aereo (in aria) |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same faces): the rasta rider from the reference image, always sitting on his goat. The man: skinny, long face, short beard, round dark sunglasses, long dark-brown dreadlocks with small red, yellow and green beads, a big knitted rasta tam hat with stripes of deep red (#90352D), golden yellow (#E2B85A) and dark forest green (#2F5A2E). An unlit joint in his mouth, never lit, no smoke. Ripped black t-shirt (#261D18), baggy mustard-khaki trousers (#BF9955) with dirt stains, grey crocs (#7E7168). He holds red rope reins in one hand and a long thin wooden staff in the other. A grey pigeon (#625C56, lighter wings #9A8D76) always perched on his shoulder. The goat: white (#F0E0CD) with irregular brown patches (#906E4F), curved grey-brown horns, small goatee, yellow eyes, a red rope collar with a small brass bell.

WEAPON (must stay identical in every frame): the stone spear from the reference image. A leaf-shaped grey-blue stone tip (#BCC6CF, shadow #8995A1) with a central ridge and engraved arrow marks. Two curved bone fangs (#EFE2C4) with dark tips at the base of the tip. A red cloth band (#C2452F) with crossed lacing, and a cream cord with two red beads and hanging feathers striped blue (#2F6F9A) and black (#1D2B3A). A twisted wooden shaft (#8F6D46, darker #6A4E31) with stitched dark leather wraps (#4D3B2B) and a small metal butt cap. A little taller than the character. He holds it in the hand that used to hold the staff: in this image there is no staff, and the reins stay in the other hand, exactly as in the first-frame image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves with the spear, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2 s: he stands in guard holding the spear steady, breathing calmly. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 3 s to 4.5 s: the goat walks on the spot, like on a treadmill, four steps, while he keeps holding the spear steady. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 3, from 5.5 s to 7.5 s: the goat jumps straight up with him on its back; at the top he thrusts the spear straight down below him, pulls it back, and they land on the same spot. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, the man walking on foot or getting off the goat, a second goat, a second bird, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```

## EL-A6

**Lancia: attacchi** · file da consegnare: `EL-A6_lancia-attacchi.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/elvedeo_lancia.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/partenze/elvedeo_lancia.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `lanciaLight` | 0.5-2.5 | 12-60 | J (leggero) |
| `lanciaHeavy` | 4-6 | 96-144 | K (pesante) |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same faces): the rasta rider from the reference image, always sitting on his goat. The man: skinny, long face, short beard, round dark sunglasses, long dark-brown dreadlocks with small red, yellow and green beads, a big knitted rasta tam hat with stripes of deep red (#90352D), golden yellow (#E2B85A) and dark forest green (#2F5A2E). An unlit joint in his mouth, never lit, no smoke. Ripped black t-shirt (#261D18), baggy mustard-khaki trousers (#BF9955) with dirt stains, grey crocs (#7E7168). He holds red rope reins in one hand and a long thin wooden staff in the other. A grey pigeon (#625C56, lighter wings #9A8D76) always perched on his shoulder. The goat: white (#F0E0CD) with irregular brown patches (#906E4F), curved grey-brown horns, small goatee, yellow eyes, a red rope collar with a small brass bell.

WEAPON (must stay identical in every frame): the stone spear from the reference image. A leaf-shaped grey-blue stone tip (#BCC6CF, shadow #8995A1) with a central ridge and engraved arrow marks. Two curved bone fangs (#EFE2C4) with dark tips at the base of the tip. A red cloth band (#C2452F) with crossed lacing, and a cream cord with two red beads and hanging feathers striped blue (#2F6F9A) and black (#1D2B3A). A twisted wooden shaft (#8F6D46, darker #6A4E31) with stitched dark leather wraps (#4D3B2B) and a small metal butt cap. A little taller than the character. He holds it in the hand that used to hold the staff: in this image there is no staff, and the reins stay in the other hand, exactly as in the first-frame image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves with the spear, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: two quick thrusts of the spear straight forward, each pulled straight back. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he twirls the spear once above his head, then strikes down in front of him with it, and returns to guard. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, the man walking on foot or getting off the goat, a second goat, a second bird, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```

## EL-A7

**Lancia: lancio** · file da consegnare: `EL-A7_lancia-lancio.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/elvedeo_lancia.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/elvedeo.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `lanciaThrow` | 0.5-2 | 12-48 | lancio |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same faces): the rasta rider from the reference image, always sitting on his goat. The man: skinny, long face, short beard, round dark sunglasses, long dark-brown dreadlocks with small red, yellow and green beads, a big knitted rasta tam hat with stripes of deep red (#90352D), golden yellow (#E2B85A) and dark forest green (#2F5A2E). An unlit joint in his mouth, never lit, no smoke. Ripped black t-shirt (#261D18), baggy mustard-khaki trousers (#BF9955) with dirt stains, grey crocs (#7E7168). He holds red rope reins in one hand and a long thin wooden staff in the other. A grey pigeon (#625C56, lighter wings #9A8D76) always perched on his shoulder. The goat: white (#F0E0CD) with irregular brown patches (#906E4F), curved grey-brown horns, small goatee, yellow eyes, a red rope collar with a small brass bell.

WEAPON (must stay identical in every frame): the stone spear from the reference image. A leaf-shaped grey-blue stone tip (#BCC6CF, shadow #8995A1) with a central ridge and engraved arrow marks. Two curved bone fangs (#EFE2C4) with dark tips at the base of the tip. A red cloth band (#C2452F) with crossed lacing, and a cream cord with two red beads and hanging feathers striped blue (#2F6F9A) and black (#1D2B3A). A twisted wooden shaft (#8F6D46, darker #6A4E31) with stitched dark leather wraps (#4D3B2B) and a small metal butt cap. A little taller than the character. He holds it in the hand that used to hold the staff: in this image there is no staff, and the reins stay in the other hand, exactly as in the first-frame image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: one throw. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. From 0.5 s to 2 s he raises the spear above his shoulder, leans forward in the saddle and throws it hard: the spear leaves his hand and flies out of the frame to the right in a straight line within a quarter of a second. From 2 s to the end of the clip, empty-handed, he goes back to exactly the pose of the last-frame image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, the man walking on foot or getting off the goat, a second goat, a second bird, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never duplicates and leaves the frame only when thrown, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```

## EL-A8

**Martello** · file da consegnare: `EL-A8_martello.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/elvedeo_martello.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/partenze/elvedeo_martello.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `martelloIdle` | 0.5-2.5 | 12-60 | martella fermo |
| `martelloWalk` | 2.5-4.5 | 60-108 | martella camminando |
| `martelloJump` | 4.5-6 | 108-144 | martella saltando |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same faces): the rasta rider from the reference image, always sitting on his goat. The man: skinny, long face, short beard, round dark sunglasses, long dark-brown dreadlocks with small red, yellow and green beads, a big knitted rasta tam hat with stripes of deep red (#90352D), golden yellow (#E2B85A) and dark forest green (#2F5A2E). An unlit joint in his mouth, never lit, no smoke. Ripped black t-shirt (#261D18), baggy mustard-khaki trousers (#BF9955) with dirt stains, grey crocs (#7E7168). He holds red rope reins in one hand and a long thin wooden staff in the other. A grey pigeon (#625C56, lighter wings #9A8D76) always perched on his shoulder. The goat: white (#F0E0CD) with irregular brown patches (#906E4F), curved grey-brown horns, small goatee, yellow eyes, a red rope collar with a small brass bell.

WEAPON (must stay identical in every frame): the rocket hammer from the reference image. A compact chrome hammer head (#EEF1F5, #C3C8CF, #9AA1AB) with one dark panel (#4B5059) engraved with an X, a white light strip, rivets, a rounded block striking face with a hex bolt, and a small rocket at the back with a vent grille, amber striped fins (#F0A030) and a round nozzle. The rocket never fires: no flames. A long thin dark shaft with rings and a ball joint, a light lower grip with rubber stripes and orange accents, a dark blade-shaped pommel. Taller than the character, always held with both hands. He holds it with both hands: in this image there is no staff and he has let go of the reins, exactly as in the first-frame image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: hammering. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. From 0.5 s to 2.5 s he swings the hammer up over his head and down in front of him with both hands, striking the empty space in front of his feet, about twice per second. From 2.5 s to 4.5 s he keeps hammering the same way while the goat walks on the spot, like on a treadmill. From 4.5 s to 6 s he keeps hammering during one jump of the goat straight up, and they land on the same spot. From 6 s to the end of the clip he is back in exactly the pose of the reference image, the hammer upright, and holds perfectly still. The rocket on the hammer never fires.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, the man walking on foot or getting off the goat, a second goat, a second bird, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```
