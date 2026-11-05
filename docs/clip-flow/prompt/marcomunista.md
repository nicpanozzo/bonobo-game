<!-- File generato da tools/flow/prompt_flow.py: non modificarlo a mano, cambia lo script e rigeneralo. -->

# Marcomunista: prompt delle clip (MA)

Ondata 3 · 29 clip: 21 del personaggio (set completo) e 8 delle armi. Come si generano, si consegnano e si controllano: [README](../README.md).

Da rifare del tutto: set completo. La sua energia è lilla (come `strikeColor`), mai verde: sparirebbe col verde dello sfondo. Il tormentone "Viva il comunismo!" lo mostra il gioco, non la clip.

**Immagini da allegare:**

- clip del personaggio: [`docs/clip-flow/riferimenti/personaggi/marcomunista.png`](../riferimenti/personaggi/marcomunista.png), come prima **e** ultima immagine;
- clip delle armi: `docs/clip-flow/riferimenti/partenze/marcomunista_<arma>.png` (passo 1 del README). La clip del lancio della lancia finisce sulla posa senza arma.

**Impostazioni uguali per tutte:** Veo 3.1 (Lite o Fast, vedi README), 16:9, 8 secondi, 1 risultato.

| Codice | Clip | Stati |
|---|---|---|
| [MA-01](#ma-01) | Fermo | `idle`, `crouch`, `taunt` |
| [MA-02](#ma-02) | Corsa | `walk`, `dash`, `skid`, `turn` |
| [MA-03](#ma-03) | Salto | `jumpSquat`, `jump`, `doubleJump`, `fall`, `land` |
| [MA-04](#ma-04) | Leggeri A | `light`, `lightUp` |
| [MA-05](#ma-05) | Leggeri B | `lightSide`, `lightDown` |
| [MA-06](#ma-06) | Attacchi in corsa | `dashAttack`, `dashGrab` |
| [MA-07](#ma-07) | Pesanti A | `heavy`, `heavyUp` |
| [MA-08](#ma-08) | Pesanti B | `heavyDown`, `airDodge` |
| [MA-09](#ma-09) | Aerei A | `lightAir`, `airForward` |
| [MA-10](#ma-10) | Aerei B | `airBack`, `airUp` |
| [MA-11](#ma-11) | Aerei C | `airDown`, `heavyAir` |
| [MA-12](#ma-12) | Speciali A | `specialNeutral`, `specialSide` |
| [MA-13](#ma-13) | Speciali B | `specialDown`, `recovery+helpless` |
| [MA-14](#ma-14) | Suprema | `supreme` |
| [MA-15](#ma-15) | Presa | `grab+pummel`, `throwForward` |
| [MA-16](#ma-16) | Lanci | `throwBack`, `throwUp` |
| [MA-17](#ma-17) | Colpito | `throwDown`, `hit`, `stunned` |
| [MA-18](#ma-18) | Difesa | `shield`, `dodge`, `roll+ledgeRoll` |
| [MA-19](#ma-19) | A terra A | `tumble+prone+getup` |
| [MA-20](#ma-20) | A terra B | `tech`, `getupAttack`, `grabbed` |
| [MA-21](#ma-21) | Bordo | `ledge`, `climb`, `ledgeAttack` |
| [MA-A1](#ma-a1) | Spada: movimento | `spadaIdle`, `spadaWalk`, `spadaAir` |
| [MA-A2](#ma-a2) | Spada: attacchi | `spadaLight`, `spadaHeavy` |
| [MA-A3](#ma-a3) | Pistola: movimento | `pistolaIdle`, `pistolaWalk`, `pistolaAir` |
| [MA-A4](#ma-a4) | Pistola: attacchi | `pistolaLight`, `pistolaHeavy` |
| [MA-A5](#ma-a5) | Lancia: movimento | `lanciaIdle`, `lanciaWalk`, `lanciaAir` |
| [MA-A6](#ma-a6) | Lancia: attacchi | `lanciaLight`, `lanciaHeavy` |
| [MA-A7](#ma-a7) | Lancia: lancio | `lanciaThrow` |
| [MA-A8](#ma-a8) | Martello | `martelloIdle`, `martelloWalk`, `martelloJump` |

## MA-01

**Fermo** · file da consegnare: `MA-01_fermo.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `idle` | 0.5-2 | 12-48 | fermo |
| `crouch` | 3-4.5 | 72-108 | accovacciato |
| `taunt` | 5.5-7.5 | 132-180 | provocazione |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves, each one followed by a pause in the starting pose. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2 s: he breathes calmly in a relaxed martial-arts stance, his open hands drifting apart slightly. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 3 s to 4.5 s: he sinks into a low kung fu horse stance, holds it for a moment, then stands up. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 3, from 5.5 s to 7.5 s: he performs a slow tai chi movement, his hands circling in front of his chest with a soft glow of lilac energy between them, then the glow fades. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## MA-02

**Corsa** · file da consegnare: `MA-02_corsa.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `walk` | 0.5-2.5 | 12-60 | cammina, corre, frena, si gira |
| `dash` | 2.5-4.5 | 60-108 | cammina, corre, frena, si gira |
| `skid` | 4.5-5.5 | 108-132 | cammina, corre, frena, si gira |
| `turn` | 5.5-6.5 | 132-156 | cammina, corre, frena, si gira |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: From 0 s to 0.5 s he stands still exactly in the pose of the reference image. From 0.5 s to 2.5 s he walks on the spot, without moving forward, four relaxed steps. From 2.5 s to 4.5 s he runs on the spot, without moving forward, leaning forward, arms pumping. From 4.5 s to 5.5 s he brakes hard and skids to a stop still facing right (he does NOT turn around yet), feet dug in, leaning back, arms out for balance. From 5.5 s to 6.5 s he quickly turns around to face left and turns back to face right. From 7 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## MA-03

**Salto** · file da consegnare: `MA-03_salto.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `jumpSquat` | 0.5-1 | 12-24 | salto completo |
| `jump` | 1-2.5 | 24-60 | salto completo |
| `doubleJump` | 2.5-3.5 | 60-84 | salto completo |
| `fall` | 3.5-5 | 84-120 | salto completo |
| `land` | 5-5.5 | 120-132 | salto completo |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: From 0 s to 0.5 s he stands still exactly in the pose of the reference image. From 0.5 s to 1 s he bends his knees deeply (squash). From 1 s to 2.5 s he jumps straight up. From 2.5 s to 3.5 s, at the top, he does a second jump spinning around once in mid-air inside a thin ring of lilac energy that fades at once. From 3.5 s to 5 s he falls back down, arms out, and at 5 s he lands on the same spot in a low crouch. From 5.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## MA-04

**Leggeri A** · file da consegnare: `MA-04_leggeri-a.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `light` | 0.5-2.5 | 12-60 | jab a 3 colpi |
| `lightUp` | 4-6 | 96-144 | leggero su |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: three quick separate palm strikes forward, one every half second: an open palm strike with the front hand, one with the other hand, then a short shove with both palms. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: one quick upward palm strike above his head, looking up, then the arm comes straight back down. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## MA-05

**Leggeri B** · file da consegnare: `MA-05_leggeri-b.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `lightSide` | 0.5-2.5 | 12-60 | leggero laterale |
| `lightDown` | 4-6 | 96-144 | leggero giù |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: one quick straight front kick forward at waist height. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he drops into a low crouch and does one quick low palm strike forward near the ground, then stands. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## MA-06

**Attacchi in corsa** · file da consegnare: `MA-06_corsa-attacchi.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `dashAttack` | 0.5-2.5 | 12-60 | attacco in corsa |
| `dashGrab` | 4-6 | 96-144 | presa in corsa |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he runs two quick steps forward into a flying kick, then lands and steps back to the same spot. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he runs two quick steps forward and lunges with both hands stretched far out to grab, closes his hands on empty air, then steps back to the same spot. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## MA-07

**Pesanti A** · file da consegnare: `MA-07_pesanti-a.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `heavy` | 0.5-2.5 | 12-60 | pesante |
| `heavyUp` | 4-6 | 96-144 | pesante su |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he pulls back for half a second, then one powerful side kick forward with a small burst of lilac energy at his foot that fades at once. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he crouches for half a second, then thrusts both arms to the sky with a short flash of lilac energy above his hands that fades at once. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## MA-08

**Pesanti B** · file da consegnare: `MA-08_pesanti-b.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `heavyDown` | 0.5-2.5 | 12-60 | pesante giù |
| `airDodge` | 4-6 | 96-144 | schivata in aria |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he drops his weight down for half a second, then slams both palms toward the ground and a small wave of lilac energy runs along the ground on both sides and fades at once. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 4 s to 6 s: he jumps straight up; at the top he tucks into a quick twisting spin as if dodging, opens up again and lands on the same spot. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## MA-09

**Aerei A** · file da consegnare: `MA-09_aerei-a.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `lightAir` | 0.5-2.5 | 12-60 | aereo neutro |
| `airForward` | 4-6 | 96-144 | aereo avanti |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he jumps straight up; at the top he spreads arms and legs wide in a quick martial-arts star pose, tucks back in and lands on the same spot. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he jumps straight up; at the top he does one quick flying kick forward, pulls the leg back, and lands on the same spot. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## MA-10

**Aerei B** · file da consegnare: `MA-10_aerei-b.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `airBack` | 0.5-2.5 | 12-60 | aereo indietro |
| `airUp` | 4-6 | 96-144 | aereo su |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he jumps straight up; at the top, still facing right and without turning around, he does one quick kung fu kick backward to the left, pulls the leg back, and lands on the same spot. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he jumps straight up; at the top he does one quick scissor kick upward, and lands on the same spot. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## MA-11

**Aerei C** · file da consegnare: `MA-11_aerei-c.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `airDown` | 0.5-2.5 | 12-60 | aereo giù |
| `heavyAir` | 4-6 | 96-144 | pesante in aria |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he jumps straight up; at the top he punches straight down below him, pulls the fist back, and lands on the same spot. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he jumps straight up; at the top he spins once with a ring of lilac energy around his waist that fades at once, and lands on the same spot. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## MA-12

**Speciali A** · file da consegnare: `MA-12_speciali-a.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `specialNeutral` | 0.5-2.5 | 12-60 | speciale ferma |
| `specialSide` | 4-6 | 96-144 | speciale laterale |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he pushes both open palms forward in one strong martial-arts push; nothing leaves his hands. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he slides quickly forward a short distance with one palm strike, then steps back to the same spot. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## MA-13

**Speciali B** · file da consegnare: `MA-13_speciali-b.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `specialDown` | 0.5-2.5 | 12-60 | speciale giù |
| `recovery+helpless` | 4-6 | 96-144 | recupero e caduta indifesa |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he raises both open hands in a parry, holds the guard for a moment, then brings one hand to his mouth as if smoking. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he thrusts both arms to the sky and rises very high straight up with a short trail of lilac energy under his feet, then falls back down limp, arms and legs flailing loosely, and lands on the same spot. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## MA-14

**Suprema** · file da consegnare: `MA-14_suprema.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `supreme` | 0.5-6.5 | 12-156 | suprema |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: one move. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. From 0.5 s to 6.5 s: he raises both hands to his head in shock; a ring of lilac energy spreads around his waist; then a small lilac cloud wraps around him for a moment and fades away, leaving him standing. From 6.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## MA-15

**Presa** · file da consegnare: `MA-15_presa.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `grab+pummel` | 0.5-2.5 | 12-60 | presa e colpetti |
| `throwForward` | 4-6 | 96-144 | lancio avanti |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he lunges forward and grabs an invisible opponent with both hands, holds the empty air firmly and strikes twice with his palm, then lets go; nothing is drawn in his hands. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he grabs an invisible opponent in front of him and pushes it away with a strong two-palm push; nothing is drawn in his hands. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## MA-16

**Lanci** · file da consegnare: `MA-16_lanci.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `throwBack` | 0.5-2.5 | 12-60 | lancio indietro |
| `throwUp` | 4-6 | 96-144 | lancio su |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he grabs an invisible opponent in front of him and turns like a judo throw, flinging it behind him over his shoulder, then turns back to face right; nothing is drawn in his hands. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he grabs an invisible opponent in front of him and launches it straight up with an upward palm strike, looking up; nothing is drawn in his hands. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## MA-17

**Colpito** · file da consegnare: `MA-17_colpito.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `throwDown` | 0.5-2 | 12-48 | lancio giù |
| `hit` | 3-4.5 | 72-108 | colpito |
| `stunned` | 5.5-7.5 | 132-180 | stordito |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2 s: he grabs an invisible opponent in front of him and pushes it down to the ground with both palms; nothing is drawn. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 3 s to 4.5 s: he is struck by an invisible blow: one hand goes to his face and he bends backward, then recovers. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 3, from 5.5 s to 7.5 s: he is dizzy on the spot: he wobbles and sways, head circling, knees buckling, arms dangling, but never falls. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## MA-18

**Difesa** · file da consegnare: `MA-18_difesa.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `shield` | 0.5-2 | 12-48 | scudo |
| `dodge` | 3-4.5 | 72-108 | schivata |
| `roll+ledgeRoll` | 5.5-7.5 | 132-180 | rotolata avanti e indietro |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves, each one followed by a pause in the starting pose. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2 s: he holds both open hands low in front of him in a calm martial-arts guard, steady, breathing slowly. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 3 s to 4.5 s: he does a quick dodge on the spot, leaning his body back and then returning. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 3, from 5.5 s to 7.5 s: he rolls forward along the ground in a tight ball and stands up facing left, then immediately rolls back the other way and stands up facing right. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## MA-19

**A terra A** · file da consegnare: `MA-19_a-terra-a.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `tumble+prone+getup` | 0.5-6.5 | 12-156 | lanciato via, a terra, si rialza |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: one move, then back to the starting pose. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 6.5 s: he is knocked up into the air as if hit hard, spins head over heels twice with arms and legs spread, falls flat on his back and lies still for a moment, then stands up. From 6.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## MA-20

**A terra B** · file da consegnare: `MA-20_a-terra-b.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `tech` | 0.5-2 | 12-48 | rimbalzo |
| `getupAttack` | 3-4.5 | 72-108 | attacco da terra |
| `grabbed` | 5.5-7.5 | 132-180 | tenuto |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2 s: he falls flat on his back; the instant he touches the ground he springs back up to his feet with a quick flip. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 3 s to 4.5 s: he falls flat on his back, then spins on the ground in a breakdance windmill kick, legs swinging in a full circle, and stands up. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 3, from 5.5 s to 7.5 s: he is lifted off the ground by the scruff of his neck by an invisible hand: his feet dangle, he squirms and kicks, then he is set back down on his feet; nothing is drawn holding him. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## MA-21

**Bordo** · file da consegnare: `MA-21_bordo.mp4`

- **Modalità:** Ingredients to video
- **Prima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`
- Allega l'immagine come unico ingrediente. Il blocco grigio lo toglie lo script.
| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `ledge` | 0-2 | 0-48 | appeso |
| `climb` | 2-3.5 | 48-84 | si tira su |
| `ledgeAttack` | 4.5-6 | 108-144 | attacco dal bordo |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: a plain flat medium-grey block (#808080, no texture) fills the right third of the frame from the bottom up to the middle of the frame; it never moves. From 0 s to 2 s he hangs by both hands from the top-left corner of the block, his body dangling below the edge, facing right toward the block, swinging slightly. From 2 s to 3.5 s he pulls himself up over the corner and stands on top of the block. From 3.5 s to 4.5 s he drops back down and hangs from the corner again. From 4.5 s to 6 s he flips up onto the top of the block with one quick low forward kick. From 6 s to the end of the clip he stands still on top of the block. Everything stays inside the frame for the whole clip.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props except the grey block described above.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

## MA-A1

**Spada: movimento** · file da consegnare: `MA-A1_spada-movimento.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/marcomunista_spada.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/partenze/marcomunista_spada.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `spadaIdle` | 0.5-2 | 12-48 | fermo in guardia |
| `spadaWalk` | 3-4.5 | 72-108 | cammina |
| `spadaAir` | 5.5-7.5 | 132-180 | aereo (in aria) |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

WEAPON (must stay identical in every frame): the plasma sword from the reference image. A straight glowing energy blade, solid cyan (#4FD8FF) with a near-white core (#F2FDFF) and a faint cyan halo, rounded tip, no outline on the blade. A metal hilt in steel greys (#A9B0BA, #7F8796): a crown-shaped emitter with three small fins and an amber gem (#F0A93A), a section with vent slots and an amber button, black rubber rings (#2C2F38) between metal ribs, a grooved pommel. The blade is almost as long as the character is tall. The blade is always lit, steady, and never changes color. He holds it in the hand nearer to the viewer, exactly as in the first-frame image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves with the sword, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2 s: he stands in guard holding the sword steady, breathing calmly. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 3 s to 4.5 s: he walks on the spot, without moving forward, four steps, holding the sword steady. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 3, from 5.5 s to 7.5 s: he jumps straight up; at the top he swings the sword in one quick full circle around himself, then lands on the same spot. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```

## MA-A2

**Spada: attacchi** · file da consegnare: `MA-A2_spada-attacchi.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/marcomunista_spada.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/partenze/marcomunista_spada.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `spadaLight` | 0.5-2.5 | 12-60 | J (leggero) |
| `spadaHeavy` | 4-6 | 96-144 | K (pesante) |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

WEAPON (must stay identical in every frame): the plasma sword from the reference image. A straight glowing energy blade, solid cyan (#4FD8FF) with a near-white core (#F2FDFF) and a faint cyan halo, rounded tip, no outline on the blade. A metal hilt in steel greys (#A9B0BA, #7F8796): a crown-shaped emitter with three small fins and an amber gem (#F0A93A), a section with vent slots and an amber button, black rubber rings (#2C2F38) between metal ribs, a grooved pommel. The blade is almost as long as the character is tall. The blade is always lit, steady, and never changes color. He holds it in the hand nearer to the viewer, exactly as in the first-frame image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves with the sword, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: two quick horizontal slashes forward with the sword, one from left to right and one back from right to left, each pulled straight back. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he raises the sword above his head with both hands for half a second, then one strong vertical slash downward in front of him, and returns to guard. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```

## MA-A3

**Pistola: movimento** · file da consegnare: `MA-A3_pistola-movimento.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/marcomunista_pistola.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/partenze/marcomunista_pistola.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `pistolaIdle` | 0.5-2 | 12-48 | fermo in guardia |
| `pistolaWalk` | 3-4.5 | 72-108 | cammina |
| `pistolaAir` | 5.5-7.5 | 132-180 | aereo (in aria) |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

WEAPON (must stay identical in every frame): the energy pistol from the reference image. A chunky boxy body in light teal (#5C9AA4, shadow #41737C) with a lighter top slide (#7FB6BF) with grip ridges, a glowing amber energy cell (#FFC24A) on the side with small charge notches, small rivets, a short grey barrel (#A6AFB9) with three dark grey cooling fins (#5B6270) and a brass muzzle (#D9B04E). A wooden grip (#94603A, darker #6F4529) with a diamond-checkered panel and a brass screw. About one third of the character's height. He holds it in the hand nearer to the viewer, exactly as in the first-frame image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves with the pistol, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2 s: he stands in guard holding the pistol steady, breathing calmly. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 3 s to 4.5 s: he walks on the spot, without moving forward, four steps, holding the pistol steady. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 3, from 5.5 s to 7.5 s: he jumps straight up; at the top he points the pistol diagonally down in front of him and his wrist jerks once as if firing, then lands on the same spot. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```

## MA-A4

**Pistola: attacchi** · file da consegnare: `MA-A4_pistola-attacchi.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/marcomunista_pistola.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/partenze/marcomunista_pistola.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `pistolaLight` | 0.5-2.5 | 12-60 | J (leggero) |
| `pistolaHeavy` | 4-6 | 96-144 | K (pesante) |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

WEAPON (must stay identical in every frame): the energy pistol from the reference image. A chunky boxy body in light teal (#5C9AA4, shadow #41737C) with a lighter top slide (#7FB6BF) with grip ridges, a glowing amber energy cell (#FFC24A) on the side with small charge notches, small rivets, a short grey barrel (#A6AFB9) with three dark grey cooling fins (#5B6270) and a brass muzzle (#D9B04E). A wooden grip (#94603A, darker #6F4529) with a diamond-checkered panel and a brass screw. About one third of the character's height. He holds it in the hand nearer to the viewer, exactly as in the first-frame image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves with the pistol, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: he extends the arm straight forward, his wrist jerks once as if firing a quick shot, and the arm comes back. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he grips the pistol with both hands, aims straight forward, his arms jerk up as if firing a strong shot and the recoil pushes him one step back, then he steps forward again. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```

## MA-A5

**Lancia: movimento** · file da consegnare: `MA-A5_lancia-movimento.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/marcomunista_lancia.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/partenze/marcomunista_lancia.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `lanciaIdle` | 0.5-2 | 12-48 | fermo in guardia |
| `lanciaWalk` | 3-4.5 | 72-108 | cammina |
| `lanciaAir` | 5.5-7.5 | 132-180 | aereo (in aria) |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

WEAPON (must stay identical in every frame): the stone spear from the reference image. A leaf-shaped grey-blue stone tip (#BCC6CF, shadow #8995A1) with a central ridge and engraved arrow marks. Two curved bone fangs (#EFE2C4) with dark tips at the base of the tip. A red cloth band (#C2452F) with crossed lacing, and a cream cord with two red beads and hanging feathers striped blue (#2F6F9A) and black (#1D2B3A). A twisted wooden shaft (#8F6D46, darker #6A4E31) with stitched dark leather wraps (#4D3B2B) and a small metal butt cap. A little taller than the character. He holds it in the hand nearer to the viewer, exactly as in the first-frame image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves with the spear, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2 s: he stands in guard holding the spear steady, breathing calmly. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 3 s to 4.5 s: he walks on the spot, without moving forward, four steps, holding the spear steady. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 3, from 5.5 s to 7.5 s: he jumps straight up; at the top he thrusts the spear straight down below him, pulls it back, and lands on the same spot. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```

## MA-A6

**Lancia: attacchi** · file da consegnare: `MA-A6_lancia-attacchi.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/marcomunista_lancia.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/partenze/marcomunista_lancia.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `lanciaLight` | 0.5-2.5 | 12-60 | J (leggero) |
| `lanciaHeavy` | 4-6 | 96-144 | K (pesante) |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

WEAPON (must stay identical in every frame): the stone spear from the reference image. A leaf-shaped grey-blue stone tip (#BCC6CF, shadow #8995A1) with a central ridge and engraved arrow marks. Two curved bone fangs (#EFE2C4) with dark tips at the base of the tip. A red cloth band (#C2452F) with crossed lacing, and a cream cord with two red beads and hanging feathers striped blue (#2F6F9A) and black (#1D2B3A). A twisted wooden shaft (#8F6D46, darker #6A4E31) with stitched dark leather wraps (#4D3B2B) and a small metal butt cap. A little taller than the character. He holds it in the hand nearer to the viewer, exactly as in the first-frame image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves with the spear, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2.5 s: two quick thrusts of the spear straight forward, each pulled straight back. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he twirls the spear once above his head, then strikes down in front of him with it, and returns to guard. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```

## MA-A7

**Lancia: lancio** · file da consegnare: `MA-A7_lancia-lancio.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/marcomunista_lancia.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/personaggi/marcomunista.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `lanciaThrow` | 0.5-2 | 12-48 | lancio |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

WEAPON (must stay identical in every frame): the stone spear from the reference image. A leaf-shaped grey-blue stone tip (#BCC6CF, shadow #8995A1) with a central ridge and engraved arrow marks. Two curved bone fangs (#EFE2C4) with dark tips at the base of the tip. A red cloth band (#C2452F) with crossed lacing, and a cream cord with two red beads and hanging feathers striped blue (#2F6F9A) and black (#1D2B3A). A twisted wooden shaft (#8F6D46, darker #6A4E31) with stitched dark leather wraps (#4D3B2B) and a small metal butt cap. A little taller than the character. He holds it in the hand nearer to the viewer, exactly as in the first-frame image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: one throw. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. From 0.5 s to 2 s he raises the spear above his shoulder, takes one step forward and throws it hard: the spear leaves his hand and flies out of the frame to the right in a straight line within a quarter of a second. From 2 s to the end of the clip, empty-handed, he goes back to exactly the pose of the last-frame image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never duplicates and leaves the frame only when thrown, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```

## MA-A8

**Martello** · file da consegnare: `MA-A8_martello.mp4`

- **Modalità:** Frames to video
- **Prima immagine:** `docs/clip-flow/riferimenti/partenze/marcomunista_martello.png`
- **Ultima immagine:** `docs/clip-flow/riferimenti/partenze/marcomunista_martello.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `martelloIdle` | 0.5-2.5 | 12-60 | martella fermo |
| `martelloWalk` | 2.5-4.5 | 60-108 | martella camminando |
| `martelloJump` | 4.5-6 | 108-144 | martella saltando |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

WEAPON (must stay identical in every frame): the rocket hammer from the reference image. A compact chrome hammer head (#EEF1F5, #C3C8CF, #9AA1AB) with one dark panel (#4B5059) engraved with an X, a white light strip, rivets, a rounded block striking face with a hex bolt, and a small rocket at the back with a vent grille, amber striped fins (#F0A030) and a round nozzle. The rocket never fires: no flames. A long thin dark shaft with rings and a ball joint, a light lower grip with rubber stripes and orange accents, a dark blade-shaped pommel. Taller than the character, always held with both hands. He holds it with both hands on the lower grip, exactly as in the first-frame image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: hammering. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. From 0.5 s to 2.5 s he swings the hammer up over his head and down in front of him with both hands, striking the empty space in front of his feet, about twice per second. From 2.5 s to 4.5 s he keeps hammering the same way while walking on the spot, without moving forward. From 4.5 s to 6 s he keeps hammering during one jump straight up, and lands on the same spot. From 6 s to the end of the clip he is back in exactly the pose of the reference image, the hammer upright, and holds perfectly still. The rocket on the hammer never fires.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon.
```
