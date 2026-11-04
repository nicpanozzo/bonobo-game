<!-- File generato da tools/flow/prompt_flow.py: non modificarlo a mano, cambia lo script e rigeneralo. -->

# Egiainuso: prompt delle clip (EG)

Ondata 4 · 29 clip: 21 del personaggio (set completo) e 8 delle armi. Come si generano, si consegnano e si controllano: [README](../README.md).

Da sistemare del tutto: set completo. È un'eccezione alla guida di stile (omino a tratto nero), per questo ha uno STYLE suo. Statistiche, speciale laterale e giù e suprema sono ancora da decidere con Marco: le mosse qui sono proposte.

**Immagini da allegare:**

- clip del personaggio: [`docs/clip-flow/riferimenti/personaggi/egiainuso.png`](../riferimenti/personaggi/egiainuso.png), come prima **e** ultima immagine;
- clip delle armi: `docs/clip-flow/riferimenti/partenze/egiainuso_<arma>.png` (passo 1 del README). La clip del lancio della lancia finisce sulla posa senza arma.

**Impostazioni uguali per tutte:** Veo 3.1 (Lite o Fast, vedi README), 16:9, 8 secondi, 1 risultato.

| Codice | Clip | Stati |
|---|---|---|
| [EG-01](#eg-01) | Fermo | `idle`, `crouch`, `taunt` |
| [EG-02](#eg-02) | Corsa | `walk`, `dash`, `skid`, `turn` |
| [EG-03](#eg-03) | Salto | `jumpSquat`, `jump`, `doubleJump`, `fall`, `land` |
| [EG-04](#eg-04) | Leggeri A | `light`, `lightUp` |
| [EG-05](#eg-05) | Leggeri B | `lightSide`, `lightDown` |
| [EG-06](#eg-06) | Attacchi in corsa | `dashAttack`, `dashGrab` |
| [EG-07](#eg-07) | Pesanti A | `heavy`, `heavyUp` |
| [EG-08](#eg-08) | Pesanti B | `heavyDown`, `airDodge` |
| [EG-09](#eg-09) | Aerei A | `lightAir`, `airForward` |
| [EG-10](#eg-10) | Aerei B | `airBack`, `airUp` |
| [EG-11](#eg-11) | Aerei C | `airDown`, `heavyAir` |
| [EG-12](#eg-12) | Speciali A | `specialNeutral`, `specialSide` |
| [EG-13](#eg-13) | Speciali B | `specialDown`, `recovery+helpless` |
| [EG-14](#eg-14) | Suprema | `supreme` |
| [EG-15](#eg-15) | Presa | `grab+pummel`, `throwForward` |
| [EG-16](#eg-16) | Lanci | `throwBack`, `throwUp` |
| [EG-17](#eg-17) | Colpito | `throwDown`, `hit`, `stunned` |
| [EG-18](#eg-18) | Difesa | `shield`, `dodge`, `roll+ledgeRoll` |
| [EG-19](#eg-19) | A terra A | `tumble+prone+getup` |
| [EG-20](#eg-20) | A terra B | `tech`, `getupAttack`, `grabbed` |
| [EG-21](#eg-21) | Bordo | `ledge`, `climb`, `ledgeAttack` |
| [EG-A1](#eg-a1) | Spada: movimento | `spadaIdle`, `spadaWalk`, `spadaAir` |
| [EG-A2](#eg-a2) | Spada: attacchi | `spadaLight`, `spadaHeavy` |
| [EG-A3](#eg-a3) | Pistola: movimento | `pistolaIdle`, `pistolaWalk`, `pistolaAir` |
| [EG-A4](#eg-a4) | Pistola: attacchi | `pistolaLight`, `pistolaHeavy` |
| [EG-A5](#eg-a5) | Lancia: movimento | `lanciaIdle`, `lanciaWalk`, `lanciaAir` |
| [EG-A6](#eg-a6) | Lancia: attacchi | `lanciaLight`, `lanciaHeavy` |
| [EG-A7](#eg-a7) | Lancia: lancio | `lanciaThrow` |
| [EG-A8](#eg-a8) | Martello | `martelloIdle`, `martelloWalk`, `martelloJump` |

## EG-01

**Fermo** · file da consegnare: `EG-01_fermo.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `idle` | 0.5-2 | 12-48 | fermo |
| `crouch` | 3-4.5 | 72-108 | accovacciato |
| `taunt` | 5.5-7.5 | 132-180 | provocazione |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves, each one followed by a pause in the starting pose. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2 s: he sways gently on his stick legs, breathing. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 3 s to 4.5 s: he folds his stick legs into a low zig-zag crouch, holds it for a moment, then stands up. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 3, from 5.5 s to 7.5 s: he puffs up his cheeks twice (two small round bumps on the sides of his head) and waves one stick arm at an invisible opponent. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EG-02

**Corsa** · file da consegnare: `EG-02_corsa.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `walk` | 0.5-2.5 | 12-60 | cammina, corre, frena, si gira |
| `dash` | 2.5-4.5 | 60-108 | cammina, corre, frena, si gira |
| `skid` | 4.5-5.5 | 108-132 | cammina, corre, frena, si gira |
| `turn` | 5.5-6.5 | 132-156 | cammina, corre, frena, si gira |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: From 0 s to 0.5 s he stands still exactly in the pose of the reference image. From 0.5 s to 2.5 s he walks on the spot, like on a treadmill, four relaxed steps. From 2.5 s to 4.5 s he runs on the spot, like on a treadmill, leaning forward, arms pumping. From 4.5 s to 5.5 s he brakes hard, feet dug in, leaning back, arms out for balance. From 5.5 s to 6.5 s he quickly turns around to face left and turns back to face right. From 7 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EG-03

**Salto** · file da consegnare: `EG-03_salto.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `jumpSquat` | 0.5-1 | 12-24 | salto completo |
| `jump` | 1-2.5 | 24-60 | salto completo |
| `doubleJump` | 2.5-3.5 | 60-84 | salto completo |
| `fall` | 3.5-5 | 84-120 | salto completo |
| `land` | 5-5.5 | 120-132 | salto completo |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: From 0 s to 0.5 s he stands still exactly in the pose of the reference image. From 0.5 s to 1 s he bends his knees deeply (squash). From 1 s to 2.5 s he jumps straight up. From 2.5 s to 3.5 s, at the top, he does a second jump in mid-air with a forward somersault. From 3.5 s to 5 s he falls back down, arms out, legs ready, and at 5 s he lands on the same spot with a strong squash of the knees. From 5.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EG-04

**Leggeri A** · file da consegnare: `EG-04_leggeri-a.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `light` | 0.5-2.5 | 12-60 | jab a 3 colpi |
| `lightUp` | 4-6 | 96-144 | leggero su |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: three quick separate jabs forward, one every half second: a punch, another punch, then a quick little kick. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: one quick punch straight up above his head, then the arm comes straight back down. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EG-05

**Leggeri B** · file da consegnare: `EG-05_leggeri-b.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `lightSide` | 0.5-2.5 | 12-60 | leggero laterale |
| `lightDown` | 4-6 | 96-144 | leggero giù |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: one quick sideways kick forward with his stick leg fully straight. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: one quick low kick sweeping along the ground. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EG-06

**Attacchi in corsa** · file da consegnare: `EG-06_corsa-attacchi.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `dashAttack` | 0.5-2.5 | 12-60 | attacco in corsa |
| `dashGrab` | 4-6 | 96-144 | presa in corsa |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he runs two quick steps forward and slides feet-first along the ground, then stands and steps back to the same spot. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he runs two quick steps forward and lunges with both hands stretched far out to grab, closes his hands on empty air, then steps back to the same spot. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EG-07

**Pesanti A** · file da consegnare: `EG-07_pesanti-a.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `heavy` | 0.5-2.5 | 12-60 | pesante |
| `heavyUp` | 4-6 | 96-144 | pesante su |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he pulls back for half a second, then throws one punch forward with his stick arm stretching out long like a rubber band and snapping back to normal length. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he crouches for half a second, then hops up throwing one punch straight above his head, and lands. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EG-08

**Pesanti B** · file da consegnare: `EG-08_pesanti-b.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `heavyDown` | 0.5-2.5 | 12-60 | pesante giù |
| `airDodge` | 4-6 | 96-144 | schivata in aria |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he drops into a split with both stick legs kicking out to the sides at once, then stands up. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 4 s to 6 s: he jumps straight up; at the top he tucks into a quick twisting spin as if dodging, opens up again and lands on the same spot. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EG-09

**Aerei A** · file da consegnare: `EG-09_aerei-a.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `lightAir` | 0.5-2.5 | 12-60 | aereo neutro |
| `airForward` | 4-6 | 96-144 | aereo avanti |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he jumps straight up; at the top he spreads arms and legs wide in one quick star-shaped hit, tucks back in and lands on the same spot. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he jumps straight up; at the top he swings one arm forward and down in one quick wide arc in front of him, pulls it back, and lands on the same spot. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EG-10

**Aerei B** · file da consegnare: `EG-10_aerei-b.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `airBack` | 0.5-2.5 | 12-60 | aereo indietro |
| `airUp` | 4-6 | 96-144 | aereo su |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he jumps straight up; at the top, still facing right and without turning around, he kicks backward to the left with both feet together, pulls them back, and lands on the same spot. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he jumps straight up; at the top he does one quick headbutt upward with his cap, and lands on the same spot. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EG-11

**Aerei C** · file da consegnare: `EG-11_aerei-c.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `airDown` | 0.5-2.5 | 12-60 | aereo giù |
| `heavyAir` | 4-6 | 96-144 | pesante in aria |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he jumps straight up; at the top he pulls his knees up and stomps straight down with both feet together, pulls them back, and lands on the same spot. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he jumps straight up; at the top he does one quick somersault ending in a kick forward, and lands on the same spot. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EG-12

**Speciali A** · file da consegnare: `EG-12_speciali-a.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `specialNeutral` | 0.5-2.5 | 12-60 | speciale ferma |
| `specialSide` | 4-6 | 96-144 | speciale laterale |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he leans his head back and puffs up his cheeks (two small round bumps on the sides of his head), then leans forward and spits; nothing visible comes out. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he dashes forward a short distance with his head down, then steps back to the same spot. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EG-13

**Speciali B** · file da consegnare: `EG-13_speciali-b.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `specialDown` | 0.5-2.5 | 12-60 | speciale giù |
| `recovery+helpless` | 4-6 | 96-144 | recupero e caduta indifesa |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he raises both stick arms crossed in a guard, holds it for a moment, then throws one quick punch forward. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he spins his arms like a propeller and rises very high straight up, then falls back down limp, stick arms and legs flailing loosely, and lands on the same spot. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EG-14

**Suprema** · file da consegnare: `EG-14_suprema.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `supreme` | 0.5-6.5 | 12-156 | suprema |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: one move. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. From 0.5 s to 6.5 s: he crouches, then a jagged black zig-zag aura flares up around his whole body while he stands with arms spread wide for two seconds, then the aura fades. From 6.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EG-15

**Presa** · file da consegnare: `EG-15_presa.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `grab+pummel` | 0.5-2.5 | 12-60 | presa e colpetti |
| `throwForward` | 4-6 | 96-144 | lancio avanti |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he grabs an invisible opponent in front of him with both round hands, holds the empty air and hits it with two quick knee strikes, then lets go; nothing is drawn in his hands. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he grabs an invisible opponent in front of him and pushes it away with both hands; nothing is drawn in his hands. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EG-16

**Lanci** · file da consegnare: `EG-16_lanci.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `throwBack` | 0.5-2.5 | 12-60 | lancio indietro |
| `throwUp` | 4-6 | 96-144 | lancio su |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he grabs an invisible opponent in front of him, spins around and hurls it behind himself, then turns back to face right; nothing is drawn in his hands. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he grabs an invisible opponent in front of him, lifts it above his head and launches it straight up, looking up; nothing is drawn in his hands. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EG-17

**Colpito** · file da consegnare: `EG-17_colpito.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `throwDown` | 0.5-2 | 12-48 | lancio giù |
| `hit` | 3-4.5 | 72-108 | colpito |
| `stunned` | 5.5-7.5 | 132-180 | stordito |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2 s: he grabs an invisible opponent in front of him, slams it down at his feet and stomps on it once with one foot; nothing is drawn under his foot. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 3 s to 4.5 s: he is struck hard by an invisible blow: his head and body snap backward, then he recovers. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 3, from 5.5 s to 7.5 s: he is dizzy on the spot: he wobbles and sways, head circling, knees buckling, arms dangling, but never falls. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EG-18

**Difesa** · file da consegnare: `EG-18_difesa.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `shield` | 0.5-2 | 12-48 | scudo |
| `dodge` | 3-4.5 | 72-108 | schivata |
| `roll+ledgeRoll` | 5.5-7.5 | 132-180 | rotolata avanti e indietro |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves, each one followed by a pause in the starting pose. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2 s: he crosses both stick arms in front of his face as a guard, steady. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 3 s to 4.5 s: he does a quick dodge on the spot, leaning his body back and then returning. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 3, from 5.5 s to 7.5 s: he rolls forward along the ground in a tight ball and stands up facing left, then immediately rolls back the other way and stands up facing right. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EG-19

**A terra A** · file da consegnare: `EG-19_a-terra-a.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `tumble+prone+getup` | 0.5-6.5 | 12-156 | lanciato via, a terra, si rialza |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: one move, then back to the starting pose. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 6.5 s: he is knocked up into the air as if hit hard, spins head over heels twice with arms and legs spread, falls flat on his back and lies still for a moment, then stands up. From 6.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EG-20

**A terra B** · file da consegnare: `EG-20_a-terra-b.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `tech` | 0.5-2 | 12-48 | rimbalzo |
| `getupAttack` | 3-4.5 | 72-108 | attacco da terra |
| `grabbed` | 5.5-7.5 | 132-180 | tenuto |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2 s: he falls flat on his back; the instant he touches the ground he springs back up to his feet with a quick flip. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 3 s to 4.5 s: he falls flat on his back, then spins on the ground with his stick legs straight out in a full circle, and stands up. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 3, from 5.5 s to 7.5 s: he is lifted off the ground by the scruff of his neck by an invisible hand: his feet dangle, he squirms and kicks, then he is set back down on his feet; nothing is drawn holding him. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EG-21

**Bordo** · file da consegnare: `EG-21_bordo.mp4`

- **Modalità:** Ingredients to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`
- Allega l'immagine come unico ingrediente. Il blocco grigio lo toglie lo script.
| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `ledge` | 0-2 | 0-48 | appeso |
| `climb` | 2-3.5 | 48-84 | si tira su |
| `ledgeAttack` | 4.5-6 | 108-144 | attacco dal bordo |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: a plain flat medium-grey block (#808080, no texture) fills the right third of the frame from the bottom up to the middle of the frame; it never moves. From 0 s to 2 s he hangs by both hands from the top-left corner of the block, his body dangling below the edge, facing right toward the block, swinging slightly. From 2 s to 3.5 s he pulls himself up over the corner and stands on top of the block. From 3.5 s to 4.5 s he drops back down and hangs from the corner again. From 4.5 s to 6 s he flips up onto the top of the block with one quick low forward kick. From 6 s to the end of the clip he stands still on top of the block. Everything stays inside the frame for the whole clip.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props except the grey block described above.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## EG-A1

**Spada: movimento** · file da consegnare: `EG-A1_spada-movimento.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/egiainuso_spada.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/partenze/egiainuso_spada.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `spadaIdle` | 0.5-2 | 12-48 | fermo in guardia |
| `spadaWalk` | 3-4.5 | 72-108 | cammina |
| `spadaAir` | 5.5-7.5 | 132-180 | aereo (in aria) |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

WEAPON (must stay identical in every frame): the plasma sword from the reference image. A straight glowing energy blade, solid cyan (#4FD8FF) with a near-white core (#F2FDFF) and a faint cyan halo, rounded tip, no outline on the blade. A metal hilt in steel greys (#A9B0BA, #7F8796): a crown-shaped emitter with three small fins and an amber gem (#F0A93A), a section with vent slots and an amber button, black rubber rings (#2C2F38) between metal ribs, a grooved pommel. The blade is almost as long as the character is tall. The blade is always lit, steady, and never changes color. He holds it in the round hand nearer to the viewer, with no fingers drawn, exactly as in the first-frame image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves with the sword, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2 s: he stands in guard holding the sword steady, breathing calmly. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 3 s to 4.5 s: he walks on the spot, like on a treadmill, four steps, holding the sword steady. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 3, from 5.5 s to 7.5 s: he jumps straight up; at the top he swings the sword in one quick full circle around himself, then lands on the same spot. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```

## EG-A2

**Spada: attacchi** · file da consegnare: `EG-A2_spada-attacchi.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/egiainuso_spada.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/partenze/egiainuso_spada.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `spadaLight` | 0.5-2.5 | 12-60 | J (leggero) |
| `spadaHeavy` | 4-6 | 96-144 | K (pesante) |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

WEAPON (must stay identical in every frame): the plasma sword from the reference image. A straight glowing energy blade, solid cyan (#4FD8FF) with a near-white core (#F2FDFF) and a faint cyan halo, rounded tip, no outline on the blade. A metal hilt in steel greys (#A9B0BA, #7F8796): a crown-shaped emitter with three small fins and an amber gem (#F0A93A), a section with vent slots and an amber button, black rubber rings (#2C2F38) between metal ribs, a grooved pommel. The blade is almost as long as the character is tall. The blade is always lit, steady, and never changes color. He holds it in the round hand nearer to the viewer, with no fingers drawn, exactly as in the first-frame image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves with the sword, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: two quick horizontal slashes forward with the sword, one from left to right and one back from right to left, each pulled straight back. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he raises the sword above his head with both hands for half a second, then one strong vertical slash downward in front of him, and returns to guard. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```

## EG-A3

**Pistola: movimento** · file da consegnare: `EG-A3_pistola-movimento.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/egiainuso_pistola.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/partenze/egiainuso_pistola.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `pistolaIdle` | 0.5-2 | 12-48 | fermo in guardia |
| `pistolaWalk` | 3-4.5 | 72-108 | cammina |
| `pistolaAir` | 5.5-7.5 | 132-180 | aereo (in aria) |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

WEAPON (must stay identical in every frame): the energy pistol from the reference image. A chunky boxy body in light teal (#5C9AA4, shadow #41737C) with a lighter top slide (#7FB6BF) with grip ridges, a glowing amber energy cell (#FFC24A) on the side with small charge notches, small rivets, a short grey barrel (#A6AFB9) with three dark grey cooling fins (#5B6270) and a brass muzzle (#D9B04E). A wooden grip (#94603A, darker #6F4529) with a diamond-checkered panel and a brass screw. About one third of the character's height. He holds it in the round hand nearer to the viewer, with no fingers drawn, exactly as in the first-frame image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves with the pistol, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2 s: he stands in guard holding the pistol steady, breathing calmly. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 3 s to 4.5 s: he walks on the spot, like on a treadmill, four steps, holding the pistol steady. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 3, from 5.5 s to 7.5 s: he jumps straight up; at the top he points the pistol diagonally down in front of him and his wrist jerks once as if firing, then lands on the same spot. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```

## EG-A4

**Pistola: attacchi** · file da consegnare: `EG-A4_pistola-attacchi.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/egiainuso_pistola.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/partenze/egiainuso_pistola.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `pistolaLight` | 0.5-2.5 | 12-60 | J (leggero) |
| `pistolaHeavy` | 4-6 | 96-144 | K (pesante) |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

WEAPON (must stay identical in every frame): the energy pistol from the reference image. A chunky boxy body in light teal (#5C9AA4, shadow #41737C) with a lighter top slide (#7FB6BF) with grip ridges, a glowing amber energy cell (#FFC24A) on the side with small charge notches, small rivets, a short grey barrel (#A6AFB9) with three dark grey cooling fins (#5B6270) and a brass muzzle (#D9B04E). A wooden grip (#94603A, darker #6F4529) with a diamond-checkered panel and a brass screw. About one third of the character's height. He holds it in the round hand nearer to the viewer, with no fingers drawn, exactly as in the first-frame image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves with the pistol, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he extends the arm straight forward, his wrist jerks once as if firing a quick shot, and the arm comes back. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he grips the pistol with both hands, aims straight forward, his arms jerk up as if firing a strong shot and the recoil pushes him one step back, then he steps forward again. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```

## EG-A5

**Lancia: movimento** · file da consegnare: `EG-A5_lancia-movimento.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/egiainuso_lancia.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/partenze/egiainuso_lancia.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `lanciaIdle` | 0.5-2 | 12-48 | fermo in guardia |
| `lanciaWalk` | 3-4.5 | 72-108 | cammina |
| `lanciaAir` | 5.5-7.5 | 132-180 | aereo (in aria) |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

WEAPON (must stay identical in every frame): the stone spear from the reference image. A leaf-shaped grey-blue stone tip (#BCC6CF, shadow #8995A1) with a central ridge and engraved arrow marks. Two curved bone fangs (#EFE2C4) with dark tips at the base of the tip. A red cloth band (#C2452F) with crossed lacing, and a cream cord with two red beads and hanging feathers striped blue (#2F6F9A) and black (#1D2B3A). A twisted wooden shaft (#8F6D46, darker #6A4E31) with stitched dark leather wraps (#4D3B2B) and a small metal butt cap. A little taller than the character. He holds it in the round hand nearer to the viewer, with no fingers drawn, exactly as in the first-frame image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves with the spear, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2 s: he stands in guard holding the spear steady, breathing calmly. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 3 s to 4.5 s: he walks on the spot, like on a treadmill, four steps, holding the spear steady. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 3, from 5.5 s to 7.5 s: he jumps straight up; at the top he thrusts the spear straight down below him, pulls it back, and lands on the same spot. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```

## EG-A6

**Lancia: attacchi** · file da consegnare: `EG-A6_lancia-attacchi.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/egiainuso_lancia.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/partenze/egiainuso_lancia.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `lanciaLight` | 0.5-2.5 | 12-60 | J (leggero) |
| `lanciaHeavy` | 4-6 | 96-144 | K (pesante) |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

WEAPON (must stay identical in every frame): the stone spear from the reference image. A leaf-shaped grey-blue stone tip (#BCC6CF, shadow #8995A1) with a central ridge and engraved arrow marks. Two curved bone fangs (#EFE2C4) with dark tips at the base of the tip. A red cloth band (#C2452F) with crossed lacing, and a cream cord with two red beads and hanging feathers striped blue (#2F6F9A) and black (#1D2B3A). A twisted wooden shaft (#8F6D46, darker #6A4E31) with stitched dark leather wraps (#4D3B2B) and a small metal butt cap. A little taller than the character. He holds it in the round hand nearer to the viewer, with no fingers drawn, exactly as in the first-frame image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves with the spear, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: two quick thrusts of the spear straight forward, each pulled straight back. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he twirls the spear once above his head, then strikes down in front of him with it, and returns to guard. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```

## EG-A7

**Lancia: lancio** · file da consegnare: `EG-A7_lancia-lancio.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/egiainuso_lancia.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/egiainuso.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `lanciaThrow` | 0.5-2 | 12-48 | lancio |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

WEAPON (must stay identical in every frame): the stone spear from the reference image. A leaf-shaped grey-blue stone tip (#BCC6CF, shadow #8995A1) with a central ridge and engraved arrow marks. Two curved bone fangs (#EFE2C4) with dark tips at the base of the tip. A red cloth band (#C2452F) with crossed lacing, and a cream cord with two red beads and hanging feathers striped blue (#2F6F9A) and black (#1D2B3A). A twisted wooden shaft (#8F6D46, darker #6A4E31) with stitched dark leather wraps (#4D3B2B) and a small metal butt cap. A little taller than the character. He holds it in the round hand nearer to the viewer, with no fingers drawn, exactly as in the first-frame image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: one throw. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. From 0.5 s to 2 s he raises the spear above his shoulder, takes one step forward and throws it hard: the spear leaves his hand and flies out of the frame to the right in a straight line within a quarter of a second. From 2 s to the end of the clip, empty-handed, he goes back to exactly the pose of the last-frame image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never duplicates and leaves the frame only when thrown, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```

## EG-A8

**Martello** · file da consegnare: `EG-A8_martello.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/egiainuso_martello.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/partenze/egiainuso_martello.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `martelloIdle` | 0.5-2.5 | 12-60 | martella fermo |
| `martelloWalk` | 2.5-4.5 | 60-108 | martella camminando |
| `martelloJump` | 4.5-6 | 108-144 | martella saltando |

```text
STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

WEAPON (must stay identical in every frame): the rocket hammer from the reference image. A compact chrome hammer head (#EEF1F5, #C3C8CF, #9AA1AB) with one dark panel (#4B5059) engraved with an X, a white light strip, rivets, a rounded block striking face with a hex bolt, and a small rocket at the back with a vent grille, amber striped fins (#F0A030) and a round nozzle. The rocket never fires: no flames. A long thin dark shaft with rings and a ball joint, a light lower grip with rubber stripes and orange accents, a dark blade-shaped pommel. Taller than the character, always held with both hands. He holds it with both hands on the lower grip, exactly as in the first-frame image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: hammering. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. From 0.5 s to 2.5 s he swings the hammer up over his head and down in front of him with both hands, striking the empty space in front of his feet, about twice per second. From 2.5 s to 4.5 s he keeps hammering the same way while walking on the spot, like on a treadmill. From 4.5 s to 6 s he keeps hammering during one jump straight up, and lands on the same spot. From 6 s to the end of the clip he is back in exactly the pose of the reference image, the hammer upright, and holds perfectly still. The rocket on the hammer never fires.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a detailed face, shading, colors other than black and off-white, a realistic body, clothes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```
