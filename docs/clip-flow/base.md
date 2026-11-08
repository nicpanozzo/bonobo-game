<!-- File generato da tools/flow/prompt_flow.py: non modificarlo a mano, cambia lo script e rigeneralo. -->


# Pacchetto base: prima una base per tutti

Per ogni personaggio che non ha ancora disegni da Flow: **un'immagine di partenza nuova** (Nano Banana, 0 crediti) e **due clip Veo 3.1 Lite** (10 crediti l'una) che coprono le 7 animazioni obbligatorie. Il resto lo fanno i ripieghi di `ANIMATION_FALLBACK`; quando le clip sono nel gioco si tolgono le pose vecchie, come per Egiainuso in #542. Dopo, un giro con le animazioni che si vedono di più (corsa, speciale firma, provocazione), poi le ondate complete del [README](README.md).

**20 crediti a personaggio, 2 personaggi al giorno** coi 50 crediti giornalieri (si azzerano alle 9:00): i 10 che avanzano servono a rifare la clip venuta peggio. I crediti mensili non si toccano.

**Come:** come una clip del README (Frames to video, la stessa immagine come prima e ultima, 16:9, 8 secondi, 1 risultato), ma con **Veo 3.1 Lite**. L'immagine di partenza va in `riferimenti/personaggi/<id>.png`, 16:9, prima delle clip. Lo script di taglio trova le clip con `base_clips()` di `tools/flow/prompt_flow.py`.

**Rifalla se:** il personaggio cambia colori o faccia, una mossa resta a metà o col braccio teso, compaiono effetti, pavimento o un secondo personaggio, la clip non finisce nella posa di partenza.

| Giorno | Personaggio | Immagine di partenza da | Clip | Prima di generare |
|---|---|---|---|---|
| 1 | [Giovanni fRana](#giovannifrana) | il foglio sprite di @Marcomunista nell'ultimo commento di #528 (3/11), scelto da Nicola il 4/11 | [GF-B1](#gf-b1), [GF-B2](#gf-b2) | Aspettare l'ok di Riccardo (@GiovannifRana) in #528 sul foglio scelto da Nicola. |
| 1 | [Lendmar](#lendmar) | il foglio sprite di @Marcomunista in #536, approvato da Nicola il 4/11 | [LE-B1](#le-b1), [LE-B2](#le-b2) | - |
| 2 | [Capt. OrsoBlu](#orsoblu) | l'immagine di partenza nuova, già fatta su Flow il 3/11 (progetto "nov 03 - 23:37"): va salvata nella repo | [OB-B1](#ob-b1), [OB-B2](#ob-b2) | - |
| 2 | [Marcomunista](#marcomunista) | `riferimenti/personaggi/marcomunista.png` (già nella repo) | [MA-B1](#ma-b1), [MA-B2](#ma-b2) | - |
| 3 | [Lampione](#lampione) | lo sprite di oggi (scheda della community, #13) | [LA-B1](#la-b1), [LA-B2](#la-b2) | - |
| 3 | [Dr. Micelium](#drmicelium) | lo sprite di oggi (scheda della community, #13) | [DM-B1](#dm-b1), [DM-B2](#dm-b2) | - |
| 4 | [Electronmaster](#coachcartier) | lo sprite di oggi (scheda della community, #13) | [EM-B1](#em-b1), [EM-B2](#em-b2) | - |
| 4 | [Nonna Gina](#nonnagina) | lo sprite di oggi e la scheda `docs/mosse/nonnagina.md` | [NG-B1](#ng-b1), [NG-B2](#ng-b2) | - |
| 5 | [Maestro Opus](#opus) | lo sprite di oggi e la scheda `docs/mosse/opus.md` | [OP-B1](#op-b1), [OP-B2](#op-b2) | - |
| 5 | [Bonobot](#bonobot) | lo sprite di oggi (Riccardo, #20) | [BB-B1](#bb-b1), [BB-B2](#bb-b2) | Bonobot è di Riccardo: fagli vedere l'immagine prima delle clip. |

<a id="giovannifrana"></a>

## Giorno 1 · Giovanni fRana

**Prima di generare:** Aspettare l'ok di Riccardo (@GiovannifRana) in #528 sul foglio scelto da Nicola.

### Immagine di partenza · `riferimenti/personaggi/giovannifrana.png`

Da: il foglio sprite di @Marcomunista nell'ultimo commento di #528 (3/11), scelto da Nicola il 4/11. Strumento immagini di Flow (Nano Banana), 16:9, 1 risultato; allega il riferimento se c'è.

```text
Draw one original character for a 2D fighting video game, full body, standing in a relaxed fighting stance, side view in three-quarters, facing right. If an image is attached, it only shows who the character is: keep the look, the clothes and the colors, but redraw everything in the style below.

STYLE: 2D hand-drawn cartoon illustration for a fighting video game: thick black ink outlines of even thickness, flat colors with one hard-edged shadow tone, clean round shapes, a very expressive face, normal body proportions with the head not oversized. Not 3D, not a render, no gradients, no realistic textures.

CHARACTER: a sturdy, broad-shouldered young man, a relaxed and cheerful beach brawler. Light tanned skin (#E8B98F), thick messy curly dark brown hair (#3B2618), a short dark brown beard (#3B2618), a confident grin. A short-sleeved red Hawaiian shirt (#C0392B) with big cream-yellow hibiscus flowers (#F1C40F), unbuttoned at the collar. Knee-length beige cargo shorts (#C8B48A). White sneakers (#EDEDED) with short white socks. Bare forearms. Nothing else on him.

FRAMING: full body, the character is about two thirds of the image height, in the middle of the image, feet a little above the bottom edge. Nothing cut off.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text.
```

### GF-B1

**Movimento** · file da consegnare: `GF-B1_movimento.mp4` · Veo 3.1 Lite, Frames to video, prima e ultima immagine `docs/clip-flow/riferimenti/personaggi/giovannifrana.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `idle` | 0.5-2.5 | 12-60 | fermo |
| `walk` | 2.5-4.5 | 60-108 | cammina |
| `jumpSquat` | 5-5.5 | 120-132 | preparazione |
| `jump` | 5.5-6.5 | 132-156 | salto |
| `fall` | 6.5-7.25 | 156-174 | caduta |
| `land` | 7.25-7.5 | 174-180 | atterraggio |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, a sturdy, broad-shouldered young man, a relaxed and cheerful beach brawler. Light tanned skin (#E8B98F), thick messy curly dark brown hair (#3B2618), a short dark brown beard (#3B2618), a confident grin. A short-sleeved red Hawaiian shirt (#C0392B) with big cream-yellow hibiscus flowers (#F1C40F), unbuttoned at the collar. Knee-length beige cargo shorts (#C8B48A). White sneakers (#EDEDED) with short white socks. Bare forearms. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: From 0 s to 0.5 s he stands still exactly in the pose of the reference image. From 0.5 s to 2.5 s he breathes calmly on the spot, shifting his weight slightly from one foot to the other. From 2.5 s to 4.5 s he walks on the spot, without moving forward, four relaxed steps. From 4.5 s to 5 s he is back in exactly the pose of the reference image. From 5 s to 5.5 s he bends his knees deeply (squash). From 5.5 s to 6.5 s he jumps straight up. From 6.5 s to 7.25 s he falls back down, arms out, legs ready, and at 7.25 s he lands on the same spot with a strong squash of the knees. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a ball, a football shirt, glasses, a cigarette, sandals, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

### GF-B2

**Colpi** · file da consegnare: `GF-B2_colpi.mp4` · Veo 3.1 Lite, Frames to video, prima e ultima immagine `docs/clip-flow/riferimenti/personaggi/giovannifrana.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `light` | 0.5-2 | 12-48 | leggero |
| `heavy` | 3-4.5 | 72-108 | pesante |
| `hit` | 5.5-7.5 | 132-180 | colpito |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, a sturdy, broad-shouldered young man, a relaxed and cheerful beach brawler. Light tanned skin (#E8B98F), thick messy curly dark brown hair (#3B2618), a short dark brown beard (#3B2618), a confident grin. A short-sleeved red Hawaiian shirt (#C0392B) with big cream-yellow hibiscus flowers (#F1C40F), unbuttoned at the collar. Knee-length beige cargo shorts (#C8B48A). White sneakers (#EDEDED) with short white socks. Bare forearms. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2 s: one quick straight jab forward with the front fist. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 3 s to 4.5 s: he pulls his fist back for half a second, then throws one big swinging punch forward with his whole body, and steps back. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 3, from 5.5 s to 7.5 s: he is struck hard by an invisible blow: his head and body snap backward, then he recovers. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a ball, a football shirt, glasses, a cigarette, sandals, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

<a id="lendmar"></a>

## Giorno 1 · Lendmar

### Immagine di partenza · `riferimenti/personaggi/lendmar.png`

Da: il foglio sprite di @Marcomunista in #536, approvato da Nicola il 4/11. Strumento immagini di Flow (Nano Banana), 16:9, 1 risultato; allega il riferimento se c'è.

```text
Draw one original character for a 2D fighting video game, full body, standing in a relaxed fighting stance, side view in three-quarters, facing right. If an image is attached, it only shows who the character is: keep the look, the clothes and the colors, but redraw everything in the style below.

STYLE: 2D hand-drawn cartoon illustration for a fighting video game: thick black ink outlines of even thickness, flat colors with one hard-edged shadow tone, clean round shapes, a very expressive face, normal body proportions with the head not oversized. Not 3D, not a render, no gradients, no realistic textures.

CHARACTER: a lean young man dressed all in black, serious and a bit grim. Light skin (#EAC9AE), short dark brown hair (#2A1E18), thick frowning eyebrows, a stern stare. A tall black brimless cap (#141414), slightly crooked. A black long-sleeved button-up shirt (#1A1A1A) tucked into black trousers (#141414) with a black belt and a dull silver buckle (#8A8A8A). Black lace-up boots (#0E0E0E). Nothing else on him.

FRAMING: full body, the character is about two thirds of the image height, in the middle of the image, feet a little above the bottom edge. Nothing cut off.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text.
```

### LE-B1

**Movimento** · file da consegnare: `LE-B1_movimento.mp4` · Veo 3.1 Lite, Frames to video, prima e ultima immagine `docs/clip-flow/riferimenti/personaggi/lendmar.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `idle` | 0.5-2.5 | 12-60 | fermo |
| `walk` | 2.5-4.5 | 60-108 | cammina |
| `jumpSquat` | 5-5.5 | 120-132 | preparazione |
| `jump` | 5.5-6.5 | 132-156 | salto |
| `fall` | 6.5-7.25 | 156-174 | caduta |
| `land` | 7.25-7.5 | 174-180 | atterraggio |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, a lean young man dressed all in black, serious and a bit grim. Light skin (#EAC9AE), short dark brown hair (#2A1E18), thick frowning eyebrows, a stern stare. A tall black brimless cap (#141414), slightly crooked. A black long-sleeved button-up shirt (#1A1A1A) tucked into black trousers (#141414) with a black belt and a dull silver buckle (#8A8A8A). Black lace-up boots (#0E0E0E). Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: From 0 s to 0.5 s he stands still exactly in the pose of the reference image. From 0.5 s to 2.5 s he breathes calmly on the spot, shifting his weight slightly from one foot to the other. From 2.5 s to 4.5 s he walks on the spot, without moving forward, four relaxed steps. From 4.5 s to 5 s he is back in exactly the pose of the reference image. From 5 s to 5.5 s he bends his knees deeply (squash). From 5.5 s to 6.5 s he jumps straight up. From 6.5 s to 7.25 s he falls back down, arms out, legs ready, and at 7.25 s he lands on the same spot with a strong squash of the knees. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, colorful clothes, a smile, a fringe over the eyes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

### LE-B2

**Colpi** · file da consegnare: `LE-B2_colpi.mp4` · Veo 3.1 Lite, Frames to video, prima e ultima immagine `docs/clip-flow/riferimenti/personaggi/lendmar.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `light` | 0.5-2 | 12-48 | leggero |
| `heavy` | 3-4.5 | 72-108 | pesante |
| `hit` | 5.5-7.5 | 132-180 | colpito |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, a lean young man dressed all in black, serious and a bit grim. Light skin (#EAC9AE), short dark brown hair (#2A1E18), thick frowning eyebrows, a stern stare. A tall black brimless cap (#141414), slightly crooked. A black long-sleeved button-up shirt (#1A1A1A) tucked into black trousers (#141414) with a black belt and a dull silver buckle (#8A8A8A). Black lace-up boots (#0E0E0E). Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2 s: one quick straight punch forward with the front hand. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 3 s to 4.5 s: he pulls back for half a second, scowling, then throws one angry, powerful punch forward with his whole body. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 3, from 5.5 s to 7.5 s: he is struck hard by an invisible blow: his head and body snap backward, then he recovers. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, colorful clothes, a smile, a fringe over the eyes, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

<a id="orsoblu"></a>

## Giorno 2 · Capt. OrsoBlu

### Immagine di partenza · `riferimenti/personaggi/orsoblu.png`

Già fatta: l'immagine di partenza nuova, già fatta su Flow il 3/11 (progetto "nov 03 - 23:37"): va salvata nella repo.

### OB-B1

**Movimento** · file da consegnare: `OB-B1_movimento.mp4` · Veo 3.1 Lite, Frames to video, prima e ultima immagine `docs/clip-flow/riferimenti/personaggi/orsoblu.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `idle` | 0.5-2.5 | 12-60 | fermo |
| `walk` | 2.5-4.5 | 60-108 | cammina |
| `jumpSquat` | 5-5.5 | 120-132 | preparazione |
| `jump` | 5.5-6.5 | 132-156 | salto |
| `fall` | 6.5-7.25 | 156-174 | caduta |
| `land` | 7.25-7.5 | 174-180 | atterraggio |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, a stocky grumpy blue bear sea captain standing on two legs. Cobalt-indigo fur (#3B4F9A), lighter blue muzzle and belly (#8FA6D8), big round dark nose, thick frowning eyebrows, scowling mouth. Crooked navy captain's cap (#1F2A44) with a small gold anchor badge (#E0B040). Short mustard-yellow double-breasted pea coat (#D9A520) with brass buttons. Small red neckerchief (#B83A2E). Heavy black sea boots (#2A2A2A). A small upside-down wooden rowboat (#8B5A2B) strapped on his back like a turtle shell, a light wooden oar (#C49A6C) strapped across it. Brass whistle on a cord, small brass spyglass in his belt. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: From 0 s to 0.5 s he stands still exactly in the pose of the reference image. From 0.5 s to 2.5 s he breathes calmly on the spot, shifting his weight slightly from one foot to the other. From 2.5 s to 4.5 s he walks on the spot, without moving forward, four relaxed steps. From 4.5 s to 5 s he is back in exactly the pose of the reference image. From 5 s to 5.5 s he bends his knees deeply (squash). From 5.5 s to 6.5 s he jumps straight up. From 6.5 s to 7.25 s he falls back down, arms out, legs ready, and at 7.25 s he lands on the same spot with a strong squash of the knees. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, an anchor, a chain, a rope, the boat leaving his back, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

### OB-B2

**Colpi** · file da consegnare: `OB-B2_colpi.mp4` · Veo 3.1 Lite, Frames to video, prima e ultima immagine `docs/clip-flow/riferimenti/personaggi/orsoblu.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `light` | 0.5-2 | 12-48 | leggero |
| `heavy` | 3-4.5 | 72-108 | pesante |
| `hit` | 5.5-7.5 | 132-180 | colpito |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, a stocky grumpy blue bear sea captain standing on two legs. Cobalt-indigo fur (#3B4F9A), lighter blue muzzle and belly (#8FA6D8), big round dark nose, thick frowning eyebrows, scowling mouth. Crooked navy captain's cap (#1F2A44) with a small gold anchor badge (#E0B040). Short mustard-yellow double-breasted pea coat (#D9A520) with brass buttons. Small red neckerchief (#B83A2E). Heavy black sea boots (#2A2A2A). A small upside-down wooden rowboat (#8B5A2B) strapped on his back like a turtle shell, a light wooden oar (#C49A6C) strapped across it. Brass whistle on a cord, small brass spyglass in his belt. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2 s: one quick jab forward with his fist, scowling. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 3 s to 4.5 s: he lowers his head for half a second, then rams forward with one powerful shoulder charge, the boat on his back rocking, and steps back. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 3, from 5.5 s to 7.5 s: he is struck hard by an invisible blow: his cap tilts, his head and body snap backward, then he recovers, furious. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, an anchor, a chain, a rope, the boat leaving his back, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

<a id="marcomunista"></a>

## Giorno 2 · Marcomunista

### Immagine di partenza · `riferimenti/personaggi/marcomunista.png`

Già fatta: `riferimenti/personaggi/marcomunista.png` (già nella repo).

### MA-B1

**Movimento** · file da consegnare: `MA-B1_movimento.mp4` · Veo 3.1 Lite, Frames to video, prima e ultima immagine `docs/clip-flow/riferimenti/personaggi/marcomunista.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `idle` | 0.5-2.5 | 12-60 | fermo |
| `walk` | 2.5-4.5 | 60-108 | cammina |
| `jumpSquat` | 5-5.5 | 120-132 | preparazione |
| `jump` | 5.5-6.5 | 132-156 | salto |
| `fall` | 6.5-7.25 | 156-174 | caduta |
| `land` | 7.25-7.5 | 174-180 | atterraggio |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: From 0 s to 0.5 s he stands still exactly in the pose of the reference image. From 0.5 s to 2.5 s he breathes calmly on the spot, shifting his weight slightly from one foot to the other. From 2.5 s to 4.5 s he walks on the spot, without moving forward, four relaxed steps. From 4.5 s to 5 s he is back in exactly the pose of the reference image. From 5 s to 5.5 s he bends his knees deeply (squash). From 5.5 s to 6.5 s he jumps straight up. From 6.5 s to 7.25 s he falls back down, arms out, legs ready, and at 7.25 s he lands on the same spot with a strong squash of the knees. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

### MA-B2

**Colpi** · file da consegnare: `MA-B2_colpi.mp4` · Veo 3.1 Lite, Frames to video, prima e ultima immagine `docs/clip-flow/riferimenti/personaggi/marcomunista.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `light` | 0.5-2 | 12-48 | leggero |
| `heavy` | 3-4.5 | 72-108 | pesante |
| `hit` | 5.5-7.5 | 132-180 | colpito |

```text
STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2 s: one quick open palm strike forward with the front hand. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 3 s to 4.5 s: he pulls back for half a second, then one powerful side kick forward with a small burst of lilac energy at his foot that fades at once. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 3, from 5.5 s to 7.5 s: he is struck by an invisible blow: one hand goes to his face and he bends backward, then recovers. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, hair, green energy, a different hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

<a id="lampione"></a>

## Giorno 3 · Lampione

### Immagine di partenza · `riferimenti/personaggi/lampione.png`

Da: lo sprite di oggi (scheda della community, #13). Strumento immagini di Flow (Nano Banana), 16:9, 1 risultato; allega il riferimento se c'è.

```text
Draw one original character for a 2D fighting video game, full body, standing in a relaxed fighting stance, side view in three-quarters, facing right. If an image is attached, it only shows who the character is: keep the look, the clothes and the colors, but redraw everything in the style below.

STYLE: 2D hand-drawn cartoon illustration for a fighting video game: thick black ink outlines of even thickness, flat colors with one hard-edged shadow tone, clean round shapes, a very expressive face, normal body proportions with the head not oversized. Not 3D, not a render, no gradients, no realistic textures.

CHARACTER: a big, burly, wild and hyper-competitive man. Light skin (#F0C3A0), red-ginger buzz cut (#C4602F), ginger stubble, wide crazy eyes and a big toothy grin. A dark olive-green long-sleeved shirt (#4F6B3A) with a loose red tie (#C0392B), brown trousers (#6B4A30), dark brown shoes (#3A2A20). Bright yellow padded goalkeeper gloves (#E9EC3C) on both hands. Nothing else on him.

FRAMING: full body, the character is about two thirds of the image height, in the middle of the image, feet a little above the bottom edge. Nothing cut off.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text.
```

### LA-B1

**Movimento** · file da consegnare: `LA-B1_movimento.mp4` · Veo 3.1 Lite, Frames to video, prima e ultima immagine `docs/clip-flow/riferimenti/personaggi/lampione.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `idle` | 0.5-2.5 | 12-60 | fermo |
| `walk` | 2.5-4.5 | 60-108 | cammina |
| `jumpSquat` | 5-5.5 | 120-132 | preparazione |
| `jump` | 5.5-6.5 | 132-156 | salto |
| `fall` | 6.5-7.25 | 156-174 | caduta |
| `land` | 7.25-7.5 | 174-180 | atterraggio |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, a big, burly, wild and hyper-competitive man. Light skin (#F0C3A0), red-ginger buzz cut (#C4602F), ginger stubble, wide crazy eyes and a big toothy grin. A dark olive-green long-sleeved shirt (#4F6B3A) with a loose red tie (#C0392B), brown trousers (#6B4A30), dark brown shoes (#3A2A20). Bright yellow padded goalkeeper gloves (#E9EC3C) on both hands. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: From 0 s to 0.5 s he stands still exactly in the pose of the reference image. From 0.5 s to 2.5 s he breathes calmly on the spot, shifting his weight slightly from one foot to the other. From 2.5 s to 4.5 s he walks on the spot, without moving forward, four relaxed steps. From 4.5 s to 5 s he is back in exactly the pose of the reference image. From 5 s to 5.5 s he bends his knees deeply (squash). From 5.5 s to 6.5 s he jumps straight up. From 6.5 s to 7.25 s he falls back down, arms out, legs ready, and at 7.25 s he lands on the same spot with a strong squash of the knees. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a ball, a racket, a hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

### LA-B2

**Colpi** · file da consegnare: `LA-B2_colpi.mp4` · Veo 3.1 Lite, Frames to video, prima e ultima immagine `docs/clip-flow/riferimenti/personaggi/lampione.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `light` | 0.5-2 | 12-48 | leggero |
| `heavy` | 3-4.5 | 72-108 | pesante |
| `hit` | 5.5-7.5 | 132-180 | colpito |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, a big, burly, wild and hyper-competitive man. Light skin (#F0C3A0), red-ginger buzz cut (#C4602F), ginger stubble, wide crazy eyes and a big toothy grin. A dark olive-green long-sleeved shirt (#4F6B3A) with a loose red tie (#C0392B), brown trousers (#6B4A30), dark brown shoes (#3A2A20). Bright yellow padded goalkeeper gloves (#E9EC3C) on both hands. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2 s: one quick straight punch forward with his gloved front hand. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 3 s to 4.5 s: he pulls back for half a second, then dives forward with both gloved fists together like a goalkeeper punching the ball away, and steps back. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 3, from 5.5 s to 7.5 s: he is struck hard by an invisible blow: his head and body snap backward, then he recovers. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a ball, a racket, a hat, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

<a id="drmicelium"></a>

## Giorno 3 · Dr. Micelium

### Immagine di partenza · `riferimenti/personaggi/drmicelium.png`

Da: lo sprite di oggi (scheda della community, #13). Strumento immagini di Flow (Nano Banana), 16:9, 1 risultato; allega il riferimento se c'è.

```text
Draw one original character for a 2D fighting video game, full body, standing in a relaxed fighting stance, side view in three-quarters, facing right. If an image is attached, it only shows who the character is: keep the look, the clothes and the colors, but redraw everything in the style below.

STYLE: 2D hand-drawn cartoon illustration for a fighting video game: thick black ink outlines of even thickness, flat colors with one hard-edged shadow tone, clean round shapes, a very expressive face, normal body proportions with the head not oversized. Not 3D, not a render, no gradients, no realistic textures.

CHARACTER: a rasta trauma surgeon infected by mushrooms. Brown skin (#C98F62), long brown dreadlocks (#8A5A2B) with tiny orange-brown mushrooms (#C9A27A) growing in them and on his shoulders, a calm, wise half-smile. A long white surgeon's coat (#F4F1EA) with a few small red stains (#D23B3B) on the sleeves, open over blue-grey scrubs (#5F7B8A), dark brown shoes (#3A2E29). An unlit joint in his mouth, never lit. Nothing else on him.

FRAMING: full body, the character is about two thirds of the image height, in the middle of the image, feet a little above the bottom edge. Nothing cut off.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text.
```

### DM-B1

**Movimento** · file da consegnare: `DM-B1_movimento.mp4` · Veo 3.1 Lite, Frames to video, prima e ultima immagine `docs/clip-flow/riferimenti/personaggi/drmicelium.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `idle` | 0.5-2.5 | 12-60 | fermo |
| `walk` | 2.5-4.5 | 60-108 | cammina |
| `jumpSquat` | 5-5.5 | 120-132 | preparazione |
| `jump` | 5.5-6.5 | 132-156 | salto |
| `fall` | 6.5-7.25 | 156-174 | caduta |
| `land` | 7.25-7.5 | 174-180 | atterraggio |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, a rasta trauma surgeon infected by mushrooms. Brown skin (#C98F62), long brown dreadlocks (#8A5A2B) with tiny orange-brown mushrooms (#C9A27A) growing in them and on his shoulders, a calm, wise half-smile. A long white surgeon's coat (#F4F1EA) with a few small red stains (#D23B3B) on the sleeves, open over blue-grey scrubs (#5F7B8A), dark brown shoes (#3A2E29). An unlit joint in his mouth, never lit. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: From 0 s to 0.5 s he stands still exactly in the pose of the reference image. From 0.5 s to 2.5 s he breathes calmly on the spot, shifting his weight slightly from one foot to the other. From 2.5 s to 4.5 s he walks on the spot, without moving forward, four relaxed steps. From 4.5 s to 5 s he is back in exactly the pose of the reference image. From 5 s to 5.5 s he bends his knees deeply (squash). From 5.5 s to 6.5 s he jumps straight up. From 6.5 s to 7.25 s he falls back down, arms out, legs ready, and at 7.25 s he lands on the same spot with a strong squash of the knees. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, smoke, a scalpel, a surgical mask, spores, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

### DM-B2

**Colpi** · file da consegnare: `DM-B2_colpi.mp4` · Veo 3.1 Lite, Frames to video, prima e ultima immagine `docs/clip-flow/riferimenti/personaggi/drmicelium.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `light` | 0.5-2 | 12-48 | leggero |
| `heavy` | 3-4.5 | 72-108 | pesante |
| `hit` | 5.5-7.5 | 132-180 | colpito |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, a rasta trauma surgeon infected by mushrooms. Brown skin (#C98F62), long brown dreadlocks (#8A5A2B) with tiny orange-brown mushrooms (#C9A27A) growing in them and on his shoulders, a calm, wise half-smile. A long white surgeon's coat (#F4F1EA) with a few small red stains (#D23B3B) on the sleeves, open over blue-grey scrubs (#5F7B8A), dark brown shoes (#3A2E29). An unlit joint in his mouth, never lit. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2 s: one quick straight punch forward with the front hand. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 3 s to 4.5 s: he pulls back for half a second, then thrusts one open palm forward in a calm, powerful strike. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 3, from 5.5 s to 7.5 s: he is struck hard by an invisible blow: his head and body snap backward, then he recovers. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, smoke, a scalpel, a surgical mask, spores, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

<a id="coachcartier"></a>

## Giorno 4 · Electronmaster

### Immagine di partenza · `riferimenti/personaggi/coachcartier.png`

Da: lo sprite di oggi (scheda della community, #13). Strumento immagini di Flow (Nano Banana), 16:9, 1 risultato; allega il riferimento se c'è.

```text
Draw one original character for a 2D fighting video game, full body, standing in a relaxed fighting stance, side view in three-quarters, facing right. If an image is attached, it only shows who the character is: keep the look, the clothes and the colors, but redraw everything in the style below.

STYLE: 2D hand-drawn cartoon illustration for a fighting video game: thick black ink outlines of even thickness, flat colors with one hard-edged shadow tone, clean round shapes, a very expressive face, normal body proportions with the head not oversized. Not 3D, not a render, no gradients, no realistic textures.

CHARACTER: a tall, muscular sports coach. Dark brown skin (#6B4630), a big round black afro (#1C1512), a confident grin. A shiny green tracksuit (#1F8A4C) with yellow stripes (#F2D02E) down the sleeves and the legs, white sneakers (#F4F4F4), two thick gold chains around his neck (#E0B040). Nothing else on him.

FRAMING: full body, the character is about two thirds of the image height, in the middle of the image, feet a little above the bottom edge. Nothing cut off.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text.
```

### EM-B1

**Movimento** · file da consegnare: `EM-B1_movimento.mp4` · Veo 3.1 Lite, Frames to video, prima e ultima immagine `docs/clip-flow/riferimenti/personaggi/coachcartier.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `idle` | 0.5-2.5 | 12-60 | fermo |
| `walk` | 2.5-4.5 | 60-108 | cammina |
| `jumpSquat` | 5-5.5 | 120-132 | preparazione |
| `jump` | 5.5-6.5 | 132-156 | salto |
| `fall` | 6.5-7.25 | 156-174 | caduta |
| `land` | 7.25-7.5 | 174-180 | atterraggio |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, a tall, muscular sports coach. Dark brown skin (#6B4630), a big round black afro (#1C1512), a confident grin. A shiny green tracksuit (#1F8A4C) with yellow stripes (#F2D02E) down the sleeves and the legs, white sneakers (#F4F4F4), two thick gold chains around his neck (#E0B040). Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: From 0 s to 0.5 s he stands still exactly in the pose of the reference image. From 0.5 s to 2.5 s he breathes calmly on the spot, shifting his weight slightly from one foot to the other. From 2.5 s to 4.5 s he walks on the spot, without moving forward, four relaxed steps. From 4.5 s to 5 s he is back in exactly the pose of the reference image. From 5 s to 5.5 s he bends his knees deeply (squash). From 5.5 s to 6.5 s he jumps straight up. From 6.5 s to 7.25 s he falls back down, arms out, legs ready, and at 7.25 s he lands on the same spot with a strong squash of the knees. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a whistle, a clipboard, a cap, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

### EM-B2

**Colpi** · file da consegnare: `EM-B2_colpi.mp4` · Veo 3.1 Lite, Frames to video, prima e ultima immagine `docs/clip-flow/riferimenti/personaggi/coachcartier.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `light` | 0.5-2 | 12-48 | leggero |
| `heavy` | 3-4.5 | 72-108 | pesante |
| `hit` | 5.5-7.5 | 132-180 | colpito |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, a tall, muscular sports coach. Dark brown skin (#6B4630), a big round black afro (#1C1512), a confident grin. A shiny green tracksuit (#1F8A4C) with yellow stripes (#F2D02E) down the sleeves and the legs, white sneakers (#F4F4F4), two thick gold chains around his neck (#E0B040). Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2 s: one quick straight punch forward with the front hand. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 3 s to 4.5 s: he pulls back for half a second, then throws one powerful uppercut forward and up, his gold chains swinging. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 3, from 5.5 s to 7.5 s: he is struck hard by an invisible blow: his head and body snap backward, then he recovers. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a whistle, a clipboard, a cap, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

<a id="nonnagina"></a>

## Giorno 4 · Nonna Gina

### Immagine di partenza · `riferimenti/personaggi/nonnagina.png`

Da: lo sprite di oggi e la scheda `docs/mosse/nonnagina.md`. Strumento immagini di Flow (Nano Banana), 16:9, 1 risultato; allega il riferimento se c'è.

```text
Draw one original character for a 2D fighting video game, full body, standing in a relaxed fighting stance, side view in three-quarters, facing right. If an image is attached, it only shows who the character is: keep the look, the clothes and the colors, but redraw everything in the style below.

STYLE: 2D hand-drawn cartoon illustration for a fighting video game: thick black ink outlines of even thickness, flat colors with one hard-edged shadow tone, clean round shapes, a very expressive face, normal body proportions with the head not oversized. Not 3D, not a render, no gradients, no realistic textures.

CHARACTER: a short, sturdy Italian grandmother from the countryside, warm but bossy. Light skin (#F2CFB3), grey hair in a tight bun (#DCD9D3), round glasses, rosy cheeks, a stern loving face. A purple cardigan (#7B4F8E), a navy-blue skirt (#3F4A5C) to below the knee, a white apron (#F3EFE6) with a small front pocket, skin-colored stockings (#D8B597), red slippers (#9C3B2E). She always holds a long wooden rolling pin (#C49A6C) in the hand nearer to the viewer. Nothing else on her.

FRAMING: full body, the character is about two thirds of the image height, in the middle of the image, feet a little above the bottom edge. Nothing cut off.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text.
```

### NG-B1

**Movimento** · file da consegnare: `NG-B1_movimento.mp4` · Veo 3.1 Lite, Frames to video, prima e ultima immagine `docs/clip-flow/riferimenti/personaggi/nonnagina.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `idle` | 0.5-2.5 | 12-60 | fermo |
| `walk` | 2.5-4.5 | 60-108 | cammina |
| `jumpSquat` | 5-5.5 | 120-132 | preparazione |
| `jump` | 5.5-6.5 | 132-156 | salto |
| `fall` | 6.5-7.25 | 156-174 | caduta |
| `land` | 7.25-7.5 | 174-180 | atterraggio |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, a short, sturdy Italian grandmother from the countryside, warm but bossy. Light skin (#F2CFB3), grey hair in a tight bun (#DCD9D3), round glasses, rosy cheeks, a stern loving face. A purple cardigan (#7B4F8E), a navy-blue skirt (#3F4A5C) to below the knee, a white apron (#F3EFE6) with a small front pocket, skin-colored stockings (#D8B597), red slippers (#9C3B2E). She always holds a long wooden rolling pin (#C49A6C) in the hand nearer to the viewer. Nothing else on her.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: From 0 s to 0.5 s she stands still exactly in the pose of the reference image. From 0.5 s to 2.5 s she breathes calmly on the spot, shifting her weight slightly from one foot to the other. From 2.5 s to 4.5 s she walks on the spot, without moving forward, four relaxed steps. From 4.5 s to 5 s she is back in exactly the pose of the reference image. From 5 s to 5.5 s she bends her knees deeply (squash). From 5.5 s to 6.5 s she jumps straight up. From 6.5 s to 7.25 s she falls back down, arms out, legs ready, and at 7.25 s she lands on the same spot with a strong squash of the knees. From 7.5 s to the end of the clip she is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a second rolling pin, food, a handbag, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

### NG-B2

**Colpi** · file da consegnare: `NG-B2_colpi.mp4` · Veo 3.1 Lite, Frames to video, prima e ultima immagine `docs/clip-flow/riferimenti/personaggi/nonnagina.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `light` | 0.5-2 | 12-48 | leggero |
| `heavy` | 3-4.5 | 72-108 | pesante |
| `hit` | 5.5-7.5 | 132-180 | colpito |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, a short, sturdy Italian grandmother from the countryside, warm but bossy. Light skin (#F2CFB3), grey hair in a tight bun (#DCD9D3), round glasses, rosy cheeks, a stern loving face. A purple cardigan (#7B4F8E), a navy-blue skirt (#3F4A5C) to below the knee, a white apron (#F3EFE6) with a small front pocket, skin-colored stockings (#D8B597), red slippers (#9C3B2E). She always holds a long wooden rolling pin (#C49A6C) in the hand nearer to the viewer. Nothing else on her.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: she never holds a limb stretched out. From 0 s to 0.5 s she stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2 s: one quick poke forward with the end of her rolling pin. From 2 s to 3 s she is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 3 s to 4.5 s: she raises the rolling pin over her head with both hands for half a second, then brings it down in front of her in one powerful blow. From 4.5 s to 5.5 s she is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 3, from 5.5 s to 7.5 s: she is struck hard by an invisible blow: her head and body snap backward, then she recovers. From 7.5 s to the end of the clip she is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, a second rolling pin, food, a handbag, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

<a id="opus"></a>

## Giorno 5 · Maestro Opus

### Immagine di partenza · `riferimenti/personaggi/opus.png`

Da: lo sprite di oggi e la scheda `docs/mosse/opus.md`. Strumento immagini di Flow (Nano Banana), 16:9, 1 risultato; allega il riferimento se c'è.

```text
Draw one original character for a 2D fighting video game, full body, standing in a relaxed fighting stance, side view in three-quarters, facing right. If an image is attached, it only shows who the character is: keep the look, the clothes and the colors, but redraw everything in the style below.

STYLE: 2D hand-drawn cartoon illustration for a fighting video game: thick black ink outlines of even thickness, flat colors with one hard-edged shadow tone, clean round shapes, a very expressive face, normal body proportions with the head not oversized. Not 3D, not a render, no gradients, no realistic textures.

CHARACTER: a small, pompous bonobo orchestra conductor standing upright. Dark brown-black fur (#2B211C), a pinkish-tan face, hands and feet (#C9A189), a huge wild white mane like Beethoven's (#F2EFE8), a proud chin-up expression. A black tailcoat with long tails (#1A1A22), a white waistcoat and a white bow tie, a red carnation in the buttonhole (#C8323C). Bare bonobo feet, no shoes. In the hand nearer to the viewer an oversized conductor's baton, white with a gold tip (#E0B040), about as long as his arm. Nothing else on him.

FRAMING: full body, the character is about two thirds of the image height, in the middle of the image, feet a little above the bottom edge. Nothing cut off.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text.
```

### OP-B1

**Movimento** · file da consegnare: `OP-B1_movimento.mp4` · Veo 3.1 Lite, Frames to video, prima e ultima immagine `docs/clip-flow/riferimenti/personaggi/opus.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `idle` | 0.5-2.5 | 12-60 | fermo |
| `walk` | 2.5-4.5 | 60-108 | cammina |
| `jumpSquat` | 5-5.5 | 120-132 | preparazione |
| `jump` | 5.5-6.5 | 132-156 | salto |
| `fall` | 6.5-7.25 | 156-174 | caduta |
| `land` | 7.25-7.5 | 174-180 | atterraggio |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, a small, pompous bonobo orchestra conductor standing upright. Dark brown-black fur (#2B211C), a pinkish-tan face, hands and feet (#C9A189), a huge wild white mane like Beethoven's (#F2EFE8), a proud chin-up expression. A black tailcoat with long tails (#1A1A22), a white waistcoat and a white bow tie, a red carnation in the buttonhole (#C8323C). Bare bonobo feet, no shoes. In the hand nearer to the viewer an oversized conductor's baton, white with a gold tip (#E0B040), about as long as his arm. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: From 0 s to 0.5 s he stands still exactly in the pose of the reference image. From 0.5 s to 2.5 s he breathes calmly on the spot, shifting his weight slightly from one foot to the other. From 2.5 s to 4.5 s he walks on the spot, without moving forward, four relaxed steps. From 4.5 s to 5 s he is back in exactly the pose of the reference image. From 5 s to 5.5 s he bends his knees deeply (squash). From 5.5 s to 6.5 s he jumps straight up. From 6.5 s to 7.25 s he falls back down, arms out, legs ready, and at 7.25 s he lands on the same spot with a strong squash of the knees. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, shoes, musical notes, a music stand, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

### OP-B2

**Colpi** · file da consegnare: `OP-B2_colpi.mp4` · Veo 3.1 Lite, Frames to video, prima e ultima immagine `docs/clip-flow/riferimenti/personaggi/opus.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `light` | 0.5-2 | 12-48 | leggero |
| `heavy` | 3-4.5 | 72-108 | pesante |
| `hit` | 5.5-7.5 | 132-180 | colpito |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, a small, pompous bonobo orchestra conductor standing upright. Dark brown-black fur (#2B211C), a pinkish-tan face, hands and feet (#C9A189), a huge wild white mane like Beethoven's (#F2EFE8), a proud chin-up expression. A black tailcoat with long tails (#1A1A22), a white waistcoat and a white bow tie, a red carnation in the buttonhole (#C8323C). Bare bonobo feet, no shoes. In the hand nearer to the viewer an oversized conductor's baton, white with a gold tip (#E0B040), about as long as his arm. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2 s: one quick jab forward with the tip of his baton. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 3 s to 4.5 s: he raises the baton high for half a second, then brings it down in front of him in one grand, dramatic conducting stroke. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 3, from 5.5 s to 7.5 s: he is struck hard by an invisible blow: his head and body snap backward, then he recovers. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, shoes, musical notes, a music stand, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

<a id="bonobot"></a>

## Giorno 5 · Bonobot

**Prima di generare:** Bonobot è di Riccardo: fagli vedere l'immagine prima delle clip.

### Immagine di partenza · `riferimenti/personaggi/bonobot.png`

Da: lo sprite di oggi (Riccardo, #20). Strumento immagini di Flow (Nano Banana), 16:9, 1 risultato; allega il riferimento se c'è.

```text
Draw one original character for a 2D fighting video game, full body, standing in a relaxed fighting stance, side view in three-quarters, facing right. If an image is attached, it only shows who the character is: keep the look, the clothes and the colors, but redraw everything in the style below.

STYLE: 2D hand-drawn cartoon illustration for a fighting video game: thick black ink outlines of even thickness, flat colors with one hard-edged shadow tone, clean round shapes, a very expressive face, normal body proportions with the head not oversized. Not 3D, not a render, no gradients, no realistic textures.

CHARACTER: a cocky, swaggering bonobo standing upright. Black fur (#1E1A18), a pinkish-tan face, ears, hands and feet (#C9A189), a smug grin with half-closed eyes, a messy tuft of hair on top of the head. An unlit joint in the corner of his mouth, never lit. No clothes. Nothing else on him.

FRAMING: full body, the character is about two thirds of the image height, in the middle of the image, feet a little above the bottom edge. Nothing cut off.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text.
```

### BB-B1

**Movimento** · file da consegnare: `BB-B1_movimento.mp4` · Veo 3.1 Lite, Frames to video, prima e ultima immagine `docs/clip-flow/riferimenti/personaggi/bonobot.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `idle` | 0.5-2.5 | 12-60 | fermo |
| `walk` | 2.5-4.5 | 60-108 | cammina |
| `jumpSquat` | 5-5.5 | 120-132 | preparazione |
| `jump` | 5.5-6.5 | 132-156 | salto |
| `fall` | 6.5-7.25 | 156-174 | caduta |
| `land` | 7.25-7.5 | 174-180 | atterraggio |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, a cocky, swaggering bonobo standing upright. Black fur (#1E1A18), a pinkish-tan face, ears, hands and feet (#C9A189), a smug grin with half-closed eyes, a messy tuft of hair on top of the head. An unlit joint in the corner of his mouth, never lit. No clothes. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: From 0 s to 0.5 s he stands still exactly in the pose of the reference image. From 0.5 s to 2.5 s he breathes calmly on the spot, shifting his weight slightly from one foot to the other. From 2.5 s to 4.5 s he walks on the spot, without moving forward, four relaxed steps. From 4.5 s to 5 s he is back in exactly the pose of the reference image. From 5 s to 5.5 s he bends his knees deeply (squash). From 5.5 s to 6.5 s he jumps straight up. From 6.5 s to 7.25 s he falls back down, arms out, legs ready, and at 7.25 s he lands on the same spot with a strong squash of the knees. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, clothes, smoke, a tail, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```

### BB-B2

**Colpi** · file da consegnare: `BB-B2_colpi.mp4` · Veo 3.1 Lite, Frames to video, prima e ultima immagine `docs/clip-flow/riferimenti/personaggi/bonobot.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `light` | 0.5-2 | 12-48 | leggero |
| `heavy` | 3-4.5 | 72-108 | pesante |
| `hit` | 5.5-7.5 | 132-180 | colpito |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, a cocky, swaggering bonobo standing upright. Black fur (#1E1A18), a pinkish-tan face, ears, hands and feet (#C9A189), a smug grin with half-closed eyes, a messy tuft of hair on top of the head. An unlit joint in the corner of his mouth, never lit. No clothes. Nothing else on him.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2 s: one quick straight punch forward with the front hand. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 3 s to 4.5 s: he pulls back for half a second to charge, then throws one powerful strike forward with his whole body. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 3, from 5.5 s to 7.5 s: he is struck hard by an invisible blow: his head and body snap backward, then he recovers. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, clothes, smoke, a tail, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, a treadmill, a floor or any object under his feet, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech.
```
