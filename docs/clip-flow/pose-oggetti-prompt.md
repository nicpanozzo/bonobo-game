<!-- File generato da tools/flow/prompt_flow.py: non modificarlo a mano, cambia lo script e rigeneralo. -->


# Pose con gli oggetti: prompt

Lo standard (perché il segnaposto magenta, punti di presa, inquadratura, stati) è in [pose-oggetti.md](pose-oggetti.md). Qui ci sono solo i prompt, generati da `tools/flow/prompt_flow.py`.

**Ordine:** prima le immagini di partenza (Nano Banana, 0 crediti), poi le clip (Veo 3.1 Lite, 10 crediti l'una), Frames to video con l'immagine della presa come prima **e** ultima immagine, 16:9, 8 secondi, 1 risultato.

## Capt. OrsoBlu

### Immagini di partenza

Strumento immagini di Flow, 16:9, 1 risultato. Allega [`personaggi/orsoblu.png`](riferimenti/personaggi/orsoblu.png) e incolla il prompt. Salva in `docs/clip-flow/riferimenti/partenze/orsoblu_<presa>.png`.

**Scartala se:** il personaggio cambia, i piedi si spostano, l'oggetto non è magenta pieno o ha dettagli, c'è altro magenta o rosa nell'immagine, qualcosa tocca il bordo.

#### `orsoblu_bastone.png` · Bastone

```text
The attached image is the character. Draw exactly the same character, same size, same position of the feet in the frame and same style; change only the pose of the arms (and legs where the pose says so) and add the magenta object described below.

STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, a stocky grumpy blue bear sea captain standing on two legs. Cobalt-indigo fur (#3B4F9A), lighter blue muzzle and belly (#8FA6D8), big round dark nose, thick frowning eyebrows, scowling mouth. Crooked navy captain's cap (#1F2A44) with a small gold anchor badge (#E0B040). Short mustard-yellow double-breasted pea coat (#D9A520) with brass buttons. Small red neckerchief (#B83A2E). Heavy black sea boots (#2A2A2A). A small upside-down wooden rowboat (#8B5A2B) strapped on his back like a turtle shell, a light wooden oar (#C49A6C) strapped across it. Brass whistle on a cord, small brass spyglass in his belt. Nothing else on him.

OBJECT: a plain straight stick of solid flat magenta (#FF00FF), about as long as his arm, thick as a broom handle, with a thin black outline and no details, no shading. It is a placeholder that will be replaced in the game: keep it perfectly plain and flat.

POSE: he holds the magenta stick by its lower end in the hand nearer to the viewer, fist at his waist, the stick pointing up and forward at 45 degrees; the other fist raised in his usual guard. Keep his face, clothes and everything he carries exactly as in the attached image.

FRAMING: identical to the attached image: side view in three-quarters, facing right, full body, same size and same place in the frame. Everything, including the magenta object, stays inside the image with a wide margin of empty green on every side.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text.
```

#### `orsoblu_mira.png` · Mira

```text
The attached image is the character. Draw exactly the same character, same size, same position of the feet in the frame and same style; change only the pose of the arms (and legs where the pose says so) and add the magenta object described below.

STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, a stocky grumpy blue bear sea captain standing on two legs. Cobalt-indigo fur (#3B4F9A), lighter blue muzzle and belly (#8FA6D8), big round dark nose, thick frowning eyebrows, scowling mouth. Crooked navy captain's cap (#1F2A44) with a small gold anchor badge (#E0B040). Short mustard-yellow double-breasted pea coat (#D9A520) with brass buttons. Small red neckerchief (#B83A2E). Heavy black sea boots (#2A2A2A). A small upside-down wooden rowboat (#8B5A2B) strapped on his back like a turtle shell, a light wooden oar (#C49A6C) strapped across it. Brass whistle on a cord, small brass spyglass in his belt. Nothing else on him.

OBJECT: a small plain block of solid flat magenta (#FF00FF), the size of a brick, with no details, no shading. It is a placeholder that will be replaced in the game: keep it perfectly plain and flat.

POSE: he holds the magenta block in the hand nearer to the viewer at chest height, elbow bent, the block pointing straight forward to the right like a pistol; the other hand supports his wrist. Keep his face, clothes and everything he carries exactly as in the attached image.

FRAMING: identical to the attached image: side view in three-quarters, facing right, full body, same size and same place in the frame. Everything, including the magenta object, stays inside the image with a wide margin of empty green on every side.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text.
```

#### `orsoblu_palla.png` · Palla

```text
The attached image is the character. Draw exactly the same character, same size, same position of the feet in the frame and same style; change only the pose of the arms (and legs where the pose says so) and add the magenta object described below.

STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, a stocky grumpy blue bear sea captain standing on two legs. Cobalt-indigo fur (#3B4F9A), lighter blue muzzle and belly (#8FA6D8), big round dark nose, thick frowning eyebrows, scowling mouth. Crooked navy captain's cap (#1F2A44) with a small gold anchor badge (#E0B040). Short mustard-yellow double-breasted pea coat (#D9A520) with brass buttons. Small red neckerchief (#B83A2E). Heavy black sea boots (#2A2A2A). A small upside-down wooden rowboat (#8B5A2B) strapped on his back like a turtle shell, a light wooden oar (#C49A6C) strapped across it. Brass whistle on a cord, small brass spyglass in his belt. Nothing else on him.

OBJECT: a small plain ball of solid flat magenta (#FF00FF), the size of an orange, with no details, no shading. It is a placeholder that will be replaced in the game: keep it perfectly plain and flat.

POSE: he holds the magenta ball in the hand nearer to the viewer at hip height, arm relaxed; the other fist raised in his usual guard. Keep his face, clothes and everything he carries exactly as in the attached image.

FRAMING: identical to the attached image: side view in three-quarters, facing right, full body, same size and same place in the frame. Everything, including the magenta object, stays inside the image with a wide margin of empty green on every side.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text.
```

#### `orsoblu_peso.png` · Peso

```text
The attached image is the character. Draw exactly the same character, same size, same position of the feet in the frame and same style; change only the pose of the arms (and legs where the pose says so) and add the magenta object described below.

STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, a stocky grumpy blue bear sea captain standing on two legs. Cobalt-indigo fur (#3B4F9A), lighter blue muzzle and belly (#8FA6D8), big round dark nose, thick frowning eyebrows, scowling mouth. Crooked navy captain's cap (#1F2A44) with a small gold anchor badge (#E0B040). Short mustard-yellow double-breasted pea coat (#D9A520) with brass buttons. Small red neckerchief (#B83A2E). Heavy black sea boots (#2A2A2A). A small upside-down wooden rowboat (#8B5A2B) strapped on his back like a turtle shell, a light wooden oar (#C49A6C) strapped across it. Brass whistle on a cord, small brass spyglass in his belt. Nothing else on him.

OBJECT: a big plain cube of solid flat magenta (#FF00FF), about as wide as his shoulders, with no details, no shading. It is a placeholder that will be replaced in the game: keep it perfectly plain and flat.

POSE: he holds the magenta cube high above his head with both arms, elbows slightly bent, knees bent under the weight, the cube resting on both palms. Keep his face, clothes and everything he carries exactly as in the attached image.

FRAMING: identical to the attached image: side view in three-quarters, facing right, full body, same size and same place in the frame. Everything, including the magenta object, stays inside the image with a wide margin of empty green on every side.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text.
```

#### `orsoblu_sella.png` · Sella

```text
The attached image is the character. Draw exactly the same character, same size, same position of the feet in the frame and same style; change only the pose of the arms (and legs where the pose says so) and add the magenta object described below.

STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, a stocky grumpy blue bear sea captain standing on two legs. Cobalt-indigo fur (#3B4F9A), lighter blue muzzle and belly (#8FA6D8), big round dark nose, thick frowning eyebrows, scowling mouth. Crooked navy captain's cap (#1F2A44) with a small gold anchor badge (#E0B040). Short mustard-yellow double-breasted pea coat (#D9A520) with brass buttons. Small red neckerchief (#B83A2E). Heavy black sea boots (#2A2A2A). A small upside-down wooden rowboat (#8B5A2B) strapped on his back like a turtle shell, a light wooden oar (#C49A6C) strapped across it. Brass whistle on a cord, small brass spyglass in his belt. Nothing else on him.

OBJECT: a flat plain board of solid flat magenta (#FF00FF), as long as his body is tall and as thick as a hand, with no wheels, no details, no shading. It is a placeholder that will be replaced in the game: keep it perfectly plain and flat.

POSE: he stands on the magenta board, which lies flat and horizontal under both boots, knees bent, arms slightly out for balance, like a surfer. Keep his face, clothes and everything he carries exactly as in the attached image.

FRAMING: identical to the attached image: side view in three-quarters, facing right, full body, same size and same place in the frame. Everything, including the magenta object, stays inside the image with a wide margin of empty green on every side.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text.
```

### Clip

| Codice | Clip | Categorie | Stati |
|---|---|---|---|
| [OB-O1](#ob-o1) | Impugnatura | impugnatura | `gripIdle`, `gripWalk`, `gripLight`, `gripHeavy` |
| [OB-O2](#ob-o2) | Sparo | sparo | `aimIdle`, `aimWalk`, `aimShoot`, `aimCharge` |
| [OB-O3](#ob-o3) | Lancio e consumo | lancio, consumo | `itemHold`, `itemThrow`, `itemThrowUp`, `itemEat` |
| [OB-O4](#ob-o4) | Peso | peso | `carryIdle`, `carryWalk`, `carryToss` |
| [OB-O5](#ob-o5) | Cavalcatura | cavalcatura | `rideIdle`, `rideDash`, `rideHop` |

### OB-O1

**Impugnatura** · file da consegnare: `OB-O1_impugnatura.mp4` · Veo 3.1 Lite, Frames to video, prima e ultima immagine `docs/clip-flow/riferimenti/partenze/orsoblu_bastone.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `gripIdle` | 0-0.5 | 0-12 | fermo con l'oggetto |
| `gripWalk` | 0.5-2 | 12-48 | cammina con l'arma |
| `gripLight` | 3-4.5 | 72-108 | colpo leggero |
| `gripHeavy` | 5.5-7.5 | 132-180 | colpo forte |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, a stocky grumpy blue bear sea captain standing on two legs. Cobalt-indigo fur (#3B4F9A), lighter blue muzzle and belly (#8FA6D8), big round dark nose, thick frowning eyebrows, scowling mouth. Crooked navy captain's cap (#1F2A44) with a small gold anchor badge (#E0B040). Short mustard-yellow double-breasted pea coat (#D9A520) with brass buttons. Small red neckerchief (#B83A2E). Heavy black sea boots (#2A2A2A). A small upside-down wooden rowboat (#8B5A2B) strapped on his back like a turtle shell, a light wooden oar (#C49A6C) strapped across it. Brass whistle on a cord, small brass spyglass in his belt. Nothing else on him.

OBJECT: a plain straight stick of solid flat magenta (#FF00FF), about as long as his arm, thick as a broom handle, with a thin black outline and no details, no shading, exactly as in the reference image. He holds the magenta stick by its lower end in the hand nearer to the viewer, fist at his waist, the stick pointing up and forward at 45 degrees; the other fist raised in his usual guard in the reference image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves with the magenta stick, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out at the end. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2 s: he marches on the spot like on a treadmill, holding the magenta stick in the same way. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 3 s to 4.5 s: one quick forward thrust with the magenta stick, the tip jabbing straight forward at chest height, then pulled straight back. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 3, from 5.5 s to 7.5 s: he raises the magenta stick over his head with both hands for half a second, then smashes it down in front of him in one powerful blow, and returns the stick to the hand nearer to the viewer. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props other than the magenta stick.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, an anchor, a chain, a rope, the boat leaving his back, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The magenta stick never changes shape, color or size, never disappears, duplicates or bends, never leaves his hand and is always drawn in the same flat magenta (#FF00FF); nothing else in the image is magenta or pink. No glow, trails or effects around it.
```

### OB-O2

**Sparo** · file da consegnare: `OB-O2_sparo.mp4` · Veo 3.1 Lite, Frames to video, prima e ultima immagine `docs/clip-flow/riferimenti/partenze/orsoblu_mira.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `aimIdle` | 0-0.5 | 0-12 | fermo con l'oggetto |
| `aimWalk` | 0.5-2 | 12-48 | cammina mirando |
| `aimShoot` | 3-4.5 | 72-108 | spara |
| `aimCharge` | 5.5-7.5 | 132-180 | carica e getto |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, a stocky grumpy blue bear sea captain standing on two legs. Cobalt-indigo fur (#3B4F9A), lighter blue muzzle and belly (#8FA6D8), big round dark nose, thick frowning eyebrows, scowling mouth. Crooked navy captain's cap (#1F2A44) with a small gold anchor badge (#E0B040). Short mustard-yellow double-breasted pea coat (#D9A520) with brass buttons. Small red neckerchief (#B83A2E). Heavy black sea boots (#2A2A2A). A small upside-down wooden rowboat (#8B5A2B) strapped on his back like a turtle shell, a light wooden oar (#C49A6C) strapped across it. Brass whistle on a cord, small brass spyglass in his belt. Nothing else on him.

OBJECT: a small plain block of solid flat magenta (#FF00FF), the size of a brick, with no details, no shading, exactly as in the reference image. He holds the magenta block in the hand nearer to the viewer at chest height, elbow bent, the block pointing straight forward to the right like a pistol; the other hand supports his wrist in the reference image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves with the magenta block, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out at the end. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2 s: he marches on the spot like on a treadmill, keeping the magenta block pointed forward. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 3 s to 4.5 s: he fires two quick shots: each time his hand kicks up a little with the recoil and comes straight back, the block always pointing forward. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 3, from 5.5 s to 7.5 s: he braces his legs and grips the magenta block with both hands, trembling with effort for one second, then a big recoil pushes him half a step back, and he steps forward again. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props other than the magenta block.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, an anchor, a chain, a rope, the boat leaving his back, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The magenta block never changes shape, color or size, never disappears, duplicates or bends, never leaves his hand and is always drawn in the same flat magenta (#FF00FF); nothing else in the image is magenta or pink. No glow, trails or effects around it.
```

### OB-O3

**Lancio e consumo** · file da consegnare: `OB-O3_lancio-consumo.mp4` · Veo 3.1 Lite, Frames to video, prima e ultima immagine `docs/clip-flow/riferimenti/partenze/orsoblu_palla.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `itemHold` | 0-0.5 | 0-12 | fermo con l'oggetto |
| `itemThrow` | 0.5-2 | 12-48 | lancia avanti |
| `itemThrowUp` | 3-4.5 | 72-108 | lancia in alto |
| `itemEat` | 5.5-7.5 | 132-180 | mangia o beve |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, a stocky grumpy blue bear sea captain standing on two legs. Cobalt-indigo fur (#3B4F9A), lighter blue muzzle and belly (#8FA6D8), big round dark nose, thick frowning eyebrows, scowling mouth. Crooked navy captain's cap (#1F2A44) with a small gold anchor badge (#E0B040). Short mustard-yellow double-breasted pea coat (#D9A520) with brass buttons. Small red neckerchief (#B83A2E). Heavy black sea boots (#2A2A2A). A small upside-down wooden rowboat (#8B5A2B) strapped on his back like a turtle shell, a light wooden oar (#C49A6C) strapped across it. Brass whistle on a cord, small brass spyglass in his belt. Nothing else on him.

OBJECT: a small plain ball of solid flat magenta (#FF00FF), the size of an orange, with no details, no shading, exactly as in the reference image. He holds the magenta ball in the hand nearer to the viewer at hip height, arm relaxed; the other fist raised in his usual guard in the reference image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 3 short separate moves with the magenta ball, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out at the end. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Attack 1, from 0.5 s to 2 s: he winds up and throws overhand forward with the hand holding the magenta ball, one big throwing motion, but the ball never leaves his hand. From 2 s to 3 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 3 s to 4.5 s: he throws straight up toward the sky with the hand holding the magenta ball, but the ball never leaves his hand. From 4.5 s to 5.5 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 3, from 5.5 s to 7.5 s: he brings the magenta ball to his mouth, takes two big greedy bites and chews with his cheeks puffed, pleased; the ball keeps exactly its shape. From 7.5 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props other than the magenta ball.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, an anchor, a chain, a rope, the boat leaving his back, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The magenta ball never changes shape, color or size, never disappears, duplicates or bends, never leaves his hand and is always drawn in the same flat magenta (#FF00FF); nothing else in the image is magenta or pink. No glow, trails or effects around it.
```

### OB-O4

**Peso** · file da consegnare: `OB-O4_peso.mp4` · Veo 3.1 Lite, Frames to video, prima e ultima immagine `docs/clip-flow/riferimenti/partenze/orsoblu_peso.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `carryIdle` | 0-0.5 | 0-12 | fermo con l'oggetto |
| `carryWalk` | 0.5-2.5 | 12-60 | cammina col peso |
| `carryToss` | 4-6 | 96-144 | scaglia il peso |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, a stocky grumpy blue bear sea captain standing on two legs. Cobalt-indigo fur (#3B4F9A), lighter blue muzzle and belly (#8FA6D8), big round dark nose, thick frowning eyebrows, scowling mouth. Crooked navy captain's cap (#1F2A44) with a small gold anchor badge (#E0B040). Short mustard-yellow double-breasted pea coat (#D9A520) with brass buttons. Small red neckerchief (#B83A2E). Heavy black sea boots (#2A2A2A). A small upside-down wooden rowboat (#8B5A2B) strapped on his back like a turtle shell, a light wooden oar (#C49A6C) strapped across it. Brass whistle on a cord, small brass spyglass in his belt. Nothing else on him.

OBJECT: a big plain cube of solid flat magenta (#FF00FF), about as wide as his shoulders, with no details, no shading, exactly as in the reference image. He holds the magenta cube high above his head with both arms, elbows slightly bent, knees bent under the weight, the cube resting on both palms in the reference image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves with the magenta cube, each one followed by a pause in the starting pose. Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out at the end. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2.5 s: he trudges on the spot like on a treadmill under the heavy magenta cube, wobbling a little, the cube always above his head. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Attack 2, from 4 s to 6 s: he leans back, then heaves the magenta cube forward and down with both arms as if hurling it, arms ending stretched forward, but the cube never leaves his hands; then he lifts it back above his head. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props other than the magenta cube.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, an anchor, a chain, a rope, the boat leaving his back, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The magenta cube never changes shape, color or size, never disappears, duplicates or bends, never leaves his hands and is always drawn in the same flat magenta (#FF00FF); nothing else in the image is magenta or pink. No glow, trails or effects around it.
```

### OB-O5

**Cavalcatura** · file da consegnare: `OB-O5_cavalcatura.mp4` · Veo 3.1 Lite, Frames to video, prima e ultima immagine `docs/clip-flow/riferimenti/partenze/orsoblu_sella.png`

| Stato | Secondi | Fotogrammi | Cosa fa |
|---|---|---|---|
| `rideIdle` | 0-0.5 | 0-12 | fermo con l'oggetto |
| `rideDash` | 0.5-2.5 | 12-60 | va forte |
| `rideHop` | 4-6 | 96-144 | salta sulla tavola |

```text
STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, a stocky grumpy blue bear sea captain standing on two legs. Cobalt-indigo fur (#3B4F9A), lighter blue muzzle and belly (#8FA6D8), big round dark nose, thick frowning eyebrows, scowling mouth. Crooked navy captain's cap (#1F2A44) with a small gold anchor badge (#E0B040). Short mustard-yellow double-breasted pea coat (#D9A520) with brass buttons. Small red neckerchief (#B83A2E). Heavy black sea boots (#2A2A2A). A small upside-down wooden rowboat (#8B5A2B) strapped on his back like a turtle shell, a light wooden oar (#C49A6C) strapped across it. Brass whistle on a cord, small brass spyglass in his belt. Nothing else on him.

OBJECT: a flat plain board of solid flat magenta (#FF00FF), as long as his body is tall and as thick as a hand, with no wheels, no details, no shading, exactly as in the reference image. He stands on the magenta board, which lies flat and horizontal under both boots, knees bent, arms slightly out for balance, like a surfer in the reference image.

SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image.

ACTION: 2 short separate moves with the magenta board, each one followed by a pause in the starting pose. From 0 s to 0.5 s he stands still exactly in the pose of the reference image. Move 1, from 0.5 s to 2.5 s: he crouches low and leans far forward as if speeding along on the board, coat flapping, the board staying flat under his boots, then straightens up again. From 2.5 s to 4 s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all. Move 2, from 4 s to 6 s: he jumps straight up with the board stuck under his boots, the board rising with him and staying flat, and lands back on the same spot. From 6 s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props other than the magenta board.

AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, an anchor, a chain, a rope, the boat leaving his back, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech. The magenta board never changes shape, color or size, never disappears, duplicates or bends, never leaves the board under his boots and is always drawn in the same flat magenta (#FF00FF); nothing else in the image is magenta or pink. No glow, trails or effects around it.
```
