<!-- File generato da tools/flow/prompt_flow.py: non modificarlo a mano, cambia lo script e rigeneralo. -->


# Immagini di partenza con le armi (passo 1)

16 immagini: 4 personaggi × 4 armi. Sono la prima e l'ultima immagine delle clip delle armi. La posa **senza** arma non si genera: è il fermo del gioco in `riferimenti/personaggi/` (prova del 3/11).

**Come:** strumento immagini di Flow (Nano Banana), formato **16:9**, 1 risultato. Allega **prima** l'immagine del personaggio e **poi** quella dell'arma, e incolla il prompt.

**Dove vanno:** in `docs/clip-flow/riferimenti/partenze/<personaggio>_<arma>.png`, con una PR (passo 1 del README).

**Scartala se:** colori o proporzioni del personaggio cambiano, l'arma ha un'altra forma o altri colori, c'è un pavimento, un'ombra o una scritta, il personaggio non guarda a destra o non è intero, cambia grandezza o posizione rispetto al riferimento.

## Bradipo Giallo

### `bradipo_spada.png` · Spada al plasma

Allega: [`personaggi/bradipo.png`](riferimenti/personaggi/bradipo.png) e poi [`armi/spada_verde.png`](riferimenti/armi/spada_verde.png).

```text
The first attached image is the character, the second is the weapon. Draw exactly the same character, same size, same position and same style as in the first image, now holding the weapon from the second image with exactly its shape, proportions and colors.

STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the yellow sloth fighter from the reference image. Short and stocky, big round head. Golden-yellow fur (#F0C040), cream face with two dark brown eye bands, small black nose, grumpy determined eyebrows. Spiky hot-pink mohawk (#E03080). Plain black t-shirt with no logo or text. Pale cream belly patch. Three long curved silver claws on each hand, short claws on the feet. Nothing else on him.

WEAPON (must stay identical in every frame): the plasma sword from the reference image. A straight glowing energy blade, solid cyan (#4FD8FF) with a near-white core (#F2FDFF) and a faint cyan halo, rounded tip, no outline on the blade. A metal hilt in steel greys (#A9B0BA, #7F8796): a crown-shaped emitter with three small fins and an amber gem (#F0A93A), a section with vent slots and an amber button, black rubber rings (#2C2F38) between metal ribs, a grooved pommel. The blade is almost as long as the character is tall. The blade is always lit, steady, and never changes color.

POSE: guard stance, holding the hilt at waist height, the blade pointing up and slightly forward, the other hand free and relaxed. He holds it between the claws of the hand nearer to the viewer (still three claws per hand).

FRAMING: identical to the first image: side view in three-quarters, facing right, full body, same size and same place in the frame.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text. No glow or effects around the weapon beyond its own colors.
```

### `bradipo_pistola.png` · Pistola

Allega: [`personaggi/bradipo.png`](riferimenti/personaggi/bradipo.png) e poi [`armi/pistola_verde.png`](riferimenti/armi/pistola_verde.png).

```text
The first attached image is the character, the second is the weapon. Draw exactly the same character, same size, same position and same style as in the first image, now holding the weapon from the second image with exactly its shape, proportions and colors.

STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the yellow sloth fighter from the reference image. Short and stocky, big round head. Golden-yellow fur (#F0C040), cream face with two dark brown eye bands, small black nose, grumpy determined eyebrows. Spiky hot-pink mohawk (#E03080). Plain black t-shirt with no logo or text. Pale cream belly patch. Three long curved silver claws on each hand, short claws on the feet. Nothing else on him.

WEAPON (must stay identical in every frame): the energy pistol from the reference image. A chunky boxy body in light teal (#5C9AA4, shadow #41737C) with a lighter top slide (#7FB6BF) with grip ridges, a glowing amber energy cell (#FFC24A) on the side with small charge notches, small rivets, a short grey barrel (#A6AFB9) with three dark grey cooling fins (#5B6270) and a brass muzzle (#D9B04E). A wooden grip (#94603A, darker #6F4529) with a diamond-checkered panel and a brass screw. About one third of the character's height.

POSE: relaxed stance, holding the pistol with the arm slightly bent, the muzzle pointing forward and slightly down, finger off the trigger. He holds it between the claws of the hand nearer to the viewer (still three claws per hand).

FRAMING: identical to the first image: side view in three-quarters, facing right, full body, same size and same place in the frame.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text. No glow or effects around the weapon beyond its own colors.
```

### `bradipo_lancia.png` · Lancia di pietra

Allega: [`personaggi/bradipo.png`](riferimenti/personaggi/bradipo.png) e poi [`armi/lancia_verde.png`](riferimenti/armi/lancia_verde.png).

```text
The first attached image is the character, the second is the weapon. Draw exactly the same character, same size, same position and same style as in the first image, now holding the weapon from the second image with exactly its shape, proportions and colors.

STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the yellow sloth fighter from the reference image. Short and stocky, big round head. Golden-yellow fur (#F0C040), cream face with two dark brown eye bands, small black nose, grumpy determined eyebrows. Spiky hot-pink mohawk (#E03080). Plain black t-shirt with no logo or text. Pale cream belly patch. Three long curved silver claws on each hand, short claws on the feet. Nothing else on him.

WEAPON (must stay identical in every frame): the stone spear from the reference image. A leaf-shaped grey-blue stone tip (#BCC6CF, shadow #8995A1) with a central ridge and engraved arrow marks. Two curved bone fangs (#EFE2C4) with dark tips at the base of the tip. A red cloth band (#C2452F) with crossed lacing, and a cream cord with two red beads and hanging feathers striped blue (#2F6F9A) and black (#1D2B3A). A twisted wooden shaft (#8F6D46, darker #6A4E31) with stitched dark leather wraps (#4D3B2B) and a small metal butt cap. A little taller than the character.

POSE: standing tall, holding the spear upright beside the body, the butt touching the ground next to the front foot, the stone tip pointing up above the head. He holds it between the claws of the hand nearer to the viewer (still three claws per hand).

FRAMING: identical to the first image: side view in three-quarters, facing right, full body, same size and same place in the frame.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text. No glow or effects around the weapon beyond its own colors.
```

### `bradipo_martello.png` · Martello a razzo

Allega: [`personaggi/bradipo.png`](riferimenti/personaggi/bradipo.png) e poi [`armi/martello_verde.png`](riferimenti/armi/martello_verde.png).

```text
The first attached image is the character, the second is the weapon. Draw exactly the same character, same size, same position and same style as in the first image, now holding the weapon from the second image with exactly its shape, proportions and colors.

STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the yellow sloth fighter from the reference image. Short and stocky, big round head. Golden-yellow fur (#F0C040), cream face with two dark brown eye bands, small black nose, grumpy determined eyebrows. Spiky hot-pink mohawk (#E03080). Plain black t-shirt with no logo or text. Pale cream belly patch. Three long curved silver claws on each hand, short claws on the feet. Nothing else on him.

WEAPON (must stay identical in every frame): the rocket hammer from the reference image. A compact chrome hammer head (#EEF1F5, #C3C8CF, #9AA1AB) with one dark panel (#4B5059) engraved with an X, a white light strip, rivets, a rounded block striking face with a hex bolt, and a small rocket at the back with a vent grille, amber striped fins (#F0A030) and a round nozzle. The rocket never fires: no flames. A long thin dark shaft with rings and a ball joint, a light lower grip with rubber stripes and orange accents, a dark blade-shaped pommel. Taller than the character, always held with both hands.

POSE: holding the hammer with both hands on the lower grip, the shaft upright in front of the chest, the hammer head up above the head, ready to swing. He holds it with both hands on the lower grip.

FRAMING: identical to the first image: side view in three-quarters, facing right, full body, same size and same place in the frame.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text. No glow or effects around the weapon beyond its own colors.
```

## Elvedeo

### `elvedeo_spada.png` · Spada al plasma

Allega: [`personaggi/elvedeo.png`](riferimenti/personaggi/elvedeo.png) e poi [`armi/spada_verde.png`](riferimenti/armi/spada_verde.png).

```text
The first attached image is the character, the second is the weapon. Draw exactly the same character, same size, same position and same style as in the first image, now holding the weapon from the second image with exactly its shape, proportions and colors.

STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same faces): the rasta rider from the reference image, always sitting on his goat. The man: skinny, long face, short beard, round dark sunglasses, long dark-brown dreadlocks with small red, yellow and green beads, a big knitted rasta tam hat with stripes of deep red (#90352D), golden yellow (#E2B85A) and dark forest green (#2F5A2E). An unlit joint in his mouth, never lit, no smoke. Ripped black t-shirt (#261D18), baggy mustard-khaki trousers (#BF9955) with dirt stains, grey crocs (#7E7168). He holds red rope reins in one hand and a long thin wooden staff in the other. A grey pigeon (#625C56, lighter wings #9A8D76) always perched on his shoulder. The goat: white (#F0E0CD) with irregular brown patches (#906E4F), curved grey-brown horns, small goatee, yellow eyes, a red rope collar with a small brass bell.

WEAPON (must stay identical in every frame): the plasma sword from the reference image. A straight glowing energy blade, solid cyan (#4FD8FF) with a near-white core (#F2FDFF) and a faint cyan halo, rounded tip, no outline on the blade. A metal hilt in steel greys (#A9B0BA, #7F8796): a crown-shaped emitter with three small fins and an amber gem (#F0A93A), a section with vent slots and an amber button, black rubber rings (#2C2F38) between metal ribs, a grooved pommel. The blade is almost as long as the character is tall. The blade is always lit, steady, and never changes color.

POSE: sitting on the goat, the goat standing on all four legs facing right; guard stance, holding the hilt at waist height, the blade pointing up and slightly forward, the other hand free and relaxed. He holds it in the hand that used to hold the staff: in this image there is no staff, and the reins stay in the other hand.

FRAMING: identical to the first image: side view in three-quarters, facing right, full body, same size and same place in the frame.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text. No glow or effects around the weapon beyond its own colors.
```

### `elvedeo_pistola.png` · Pistola

Allega: [`personaggi/elvedeo.png`](riferimenti/personaggi/elvedeo.png) e poi [`armi/pistola_verde.png`](riferimenti/armi/pistola_verde.png).

```text
The first attached image is the character, the second is the weapon. Draw exactly the same character, same size, same position and same style as in the first image, now holding the weapon from the second image with exactly its shape, proportions and colors.

STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same faces): the rasta rider from the reference image, always sitting on his goat. The man: skinny, long face, short beard, round dark sunglasses, long dark-brown dreadlocks with small red, yellow and green beads, a big knitted rasta tam hat with stripes of deep red (#90352D), golden yellow (#E2B85A) and dark forest green (#2F5A2E). An unlit joint in his mouth, never lit, no smoke. Ripped black t-shirt (#261D18), baggy mustard-khaki trousers (#BF9955) with dirt stains, grey crocs (#7E7168). He holds red rope reins in one hand and a long thin wooden staff in the other. A grey pigeon (#625C56, lighter wings #9A8D76) always perched on his shoulder. The goat: white (#F0E0CD) with irregular brown patches (#906E4F), curved grey-brown horns, small goatee, yellow eyes, a red rope collar with a small brass bell.

WEAPON (must stay identical in every frame): the energy pistol from the reference image. A chunky boxy body in light teal (#5C9AA4, shadow #41737C) with a lighter top slide (#7FB6BF) with grip ridges, a glowing amber energy cell (#FFC24A) on the side with small charge notches, small rivets, a short grey barrel (#A6AFB9) with three dark grey cooling fins (#5B6270) and a brass muzzle (#D9B04E). A wooden grip (#94603A, darker #6F4529) with a diamond-checkered panel and a brass screw. About one third of the character's height.

POSE: sitting on the goat, the goat standing on all four legs facing right; relaxed stance, holding the pistol with the arm slightly bent, the muzzle pointing forward and slightly down, finger off the trigger. He holds it in the hand that used to hold the staff: in this image there is no staff, and the reins stay in the other hand.

FRAMING: identical to the first image: side view in three-quarters, facing right, full body, same size and same place in the frame.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text. No glow or effects around the weapon beyond its own colors.
```

### `elvedeo_lancia.png` · Lancia di pietra

Allega: [`personaggi/elvedeo.png`](riferimenti/personaggi/elvedeo.png) e poi [`armi/lancia_verde.png`](riferimenti/armi/lancia_verde.png).

```text
The first attached image is the character, the second is the weapon. Draw exactly the same character, same size, same position and same style as in the first image, now holding the weapon from the second image with exactly its shape, proportions and colors.

STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same faces): the rasta rider from the reference image, always sitting on his goat. The man: skinny, long face, short beard, round dark sunglasses, long dark-brown dreadlocks with small red, yellow and green beads, a big knitted rasta tam hat with stripes of deep red (#90352D), golden yellow (#E2B85A) and dark forest green (#2F5A2E). An unlit joint in his mouth, never lit, no smoke. Ripped black t-shirt (#261D18), baggy mustard-khaki trousers (#BF9955) with dirt stains, grey crocs (#7E7168). He holds red rope reins in one hand and a long thin wooden staff in the other. A grey pigeon (#625C56, lighter wings #9A8D76) always perched on his shoulder. The goat: white (#F0E0CD) with irregular brown patches (#906E4F), curved grey-brown horns, small goatee, yellow eyes, a red rope collar with a small brass bell.

WEAPON (must stay identical in every frame): the stone spear from the reference image. A leaf-shaped grey-blue stone tip (#BCC6CF, shadow #8995A1) with a central ridge and engraved arrow marks. Two curved bone fangs (#EFE2C4) with dark tips at the base of the tip. A red cloth band (#C2452F) with crossed lacing, and a cream cord with two red beads and hanging feathers striped blue (#2F6F9A) and black (#1D2B3A). A twisted wooden shaft (#8F6D46, darker #6A4E31) with stitched dark leather wraps (#4D3B2B) and a small metal butt cap. A little taller than the character.

POSE: sitting on the goat, the goat standing on all four legs facing right; holding the spear upright beside the body, the butt resting on the goat's shoulder, the stone tip pointing up above the head. He holds it in the hand that used to hold the staff: in this image there is no staff, and the reins stay in the other hand.

FRAMING: identical to the first image: side view in three-quarters, facing right, full body, same size and same place in the frame.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text. No glow or effects around the weapon beyond its own colors.
```

### `elvedeo_martello.png` · Martello a razzo

Allega: [`personaggi/elvedeo.png`](riferimenti/personaggi/elvedeo.png) e poi [`armi/martello_verde.png`](riferimenti/armi/martello_verde.png).

```text
The first attached image is the character, the second is the weapon. Draw exactly the same character, same size, same position and same style as in the first image, now holding the weapon from the second image with exactly its shape, proportions and colors.

STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same faces): the rasta rider from the reference image, always sitting on his goat. The man: skinny, long face, short beard, round dark sunglasses, long dark-brown dreadlocks with small red, yellow and green beads, a big knitted rasta tam hat with stripes of deep red (#90352D), golden yellow (#E2B85A) and dark forest green (#2F5A2E). An unlit joint in his mouth, never lit, no smoke. Ripped black t-shirt (#261D18), baggy mustard-khaki trousers (#BF9955) with dirt stains, grey crocs (#7E7168). He holds red rope reins in one hand and a long thin wooden staff in the other. A grey pigeon (#625C56, lighter wings #9A8D76) always perched on his shoulder. The goat: white (#F0E0CD) with irregular brown patches (#906E4F), curved grey-brown horns, small goatee, yellow eyes, a red rope collar with a small brass bell.

WEAPON (must stay identical in every frame): the rocket hammer from the reference image. A compact chrome hammer head (#EEF1F5, #C3C8CF, #9AA1AB) with one dark panel (#4B5059) engraved with an X, a white light strip, rivets, a rounded block striking face with a hex bolt, and a small rocket at the back with a vent grille, amber striped fins (#F0A030) and a round nozzle. The rocket never fires: no flames. A long thin dark shaft with rings and a ball joint, a light lower grip with rubber stripes and orange accents, a dark blade-shaped pommel. Taller than the character, always held with both hands.

POSE: sitting on the goat, the goat standing on all four legs facing right; holding the hammer with both hands on the lower grip, the shaft upright in front of the chest, the hammer head up above the head, ready to swing. He holds it with both hands: in this image there is no staff and he has let go of the reins.

FRAMING: identical to the first image: side view in three-quarters, facing right, full body, same size and same place in the frame.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text. No glow or effects around the weapon beyond its own colors.
```

## Marcomunista

### `marcomunista_spada.png` · Spada al plasma

Allega: [`personaggi/marcomunista.png`](riferimenti/personaggi/marcomunista.png) e poi [`armi/spada_verde.png`](riferimenti/armi/spada_verde.png).

```text
The first attached image is the character, the second is the weapon. Draw exactly the same character, same size, same position and same style as in the first image, now holding the weapon from the second image with exactly its shape, proportions and colors.

STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the man from the reference image, a sly, laid-back stoner. Stocky, light skin, completely bald with a shiny scalp. A small snug bucket hat sitting low on his head, fluorescent hot pink (#FF3FA4) with a pattern of small neon lime-yellow cannabis leaves (#E4FF3A). Thin round wire glasses, a short trimmed dark-brown beard (#3B2A20) and mustache, half-closed heavy-lidded eyes and a sly lazy half-smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green. The small pink hat stays firmly on his head for the whole clip and never disappears: he takes it off only when the action says so, and then it stays visible in his hand or in the air until he puts it back on.

WEAPON (must stay identical in every frame): the plasma sword from the reference image. A straight glowing energy blade, solid cyan (#4FD8FF) with a near-white core (#F2FDFF) and a faint cyan halo, rounded tip, no outline on the blade. A metal hilt in steel greys (#A9B0BA, #7F8796): a crown-shaped emitter with three small fins and an amber gem (#F0A93A), a section with vent slots and an amber button, black rubber rings (#2C2F38) between metal ribs, a grooved pommel. The blade is almost as long as the character is tall. The blade is always lit, steady, and never changes color.

POSE: guard stance, holding the hilt at waist height, the blade pointing up and slightly forward, the other hand free and relaxed. He holds it in the hand nearer to the viewer.

FRAMING: identical to the first image: side view in three-quarters, facing right, full body, same size and same place in the frame.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text. No glow or effects around the weapon beyond its own colors.
```

### `marcomunista_pistola.png` · Pistola

Allega: [`personaggi/marcomunista.png`](riferimenti/personaggi/marcomunista.png) e poi [`armi/pistola_verde.png`](riferimenti/armi/pistola_verde.png).

```text
The first attached image is the character, the second is the weapon. Draw exactly the same character, same size, same position and same style as in the first image, now holding the weapon from the second image with exactly its shape, proportions and colors.

STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the man from the reference image, a sly, laid-back stoner. Stocky, light skin, completely bald with a shiny scalp. A small snug bucket hat sitting low on his head, fluorescent hot pink (#FF3FA4) with a pattern of small neon lime-yellow cannabis leaves (#E4FF3A). Thin round wire glasses, a short trimmed dark-brown beard (#3B2A20) and mustache, half-closed heavy-lidded eyes and a sly lazy half-smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green. The small pink hat stays firmly on his head for the whole clip and never disappears: he takes it off only when the action says so, and then it stays visible in his hand or in the air until he puts it back on.

WEAPON (must stay identical in every frame): the energy pistol from the reference image. A chunky boxy body in light teal (#5C9AA4, shadow #41737C) with a lighter top slide (#7FB6BF) with grip ridges, a glowing amber energy cell (#FFC24A) on the side with small charge notches, small rivets, a short grey barrel (#A6AFB9) with three dark grey cooling fins (#5B6270) and a brass muzzle (#D9B04E). A wooden grip (#94603A, darker #6F4529) with a diamond-checkered panel and a brass screw. About one third of the character's height.

POSE: relaxed stance, holding the pistol with the arm slightly bent, the muzzle pointing forward and slightly down, finger off the trigger. He holds it in the hand nearer to the viewer.

FRAMING: identical to the first image: side view in three-quarters, facing right, full body, same size and same place in the frame.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text. No glow or effects around the weapon beyond its own colors.
```

### `marcomunista_lancia.png` · Lancia di pietra

Allega: [`personaggi/marcomunista.png`](riferimenti/personaggi/marcomunista.png) e poi [`armi/lancia_verde.png`](riferimenti/armi/lancia_verde.png).

```text
The first attached image is the character, the second is the weapon. Draw exactly the same character, same size, same position and same style as in the first image, now holding the weapon from the second image with exactly its shape, proportions and colors.

STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the man from the reference image, a sly, laid-back stoner. Stocky, light skin, completely bald with a shiny scalp. A small snug bucket hat sitting low on his head, fluorescent hot pink (#FF3FA4) with a pattern of small neon lime-yellow cannabis leaves (#E4FF3A). Thin round wire glasses, a short trimmed dark-brown beard (#3B2A20) and mustache, half-closed heavy-lidded eyes and a sly lazy half-smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green. The small pink hat stays firmly on his head for the whole clip and never disappears: he takes it off only when the action says so, and then it stays visible in his hand or in the air until he puts it back on.

WEAPON (must stay identical in every frame): the stone spear from the reference image. A leaf-shaped grey-blue stone tip (#BCC6CF, shadow #8995A1) with a central ridge and engraved arrow marks. Two curved bone fangs (#EFE2C4) with dark tips at the base of the tip. A red cloth band (#C2452F) with crossed lacing, and a cream cord with two red beads and hanging feathers striped blue (#2F6F9A) and black (#1D2B3A). A twisted wooden shaft (#8F6D46, darker #6A4E31) with stitched dark leather wraps (#4D3B2B) and a small metal butt cap. A little taller than the character.

POSE: standing tall, holding the spear upright beside the body, the butt touching the ground next to the front foot, the stone tip pointing up above the head. He holds it in the hand nearer to the viewer.

FRAMING: identical to the first image: side view in three-quarters, facing right, full body, same size and same place in the frame.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text. No glow or effects around the weapon beyond its own colors.
```

### `marcomunista_martello.png` · Martello a razzo

Allega: [`personaggi/marcomunista.png`](riferimenti/personaggi/marcomunista.png) e poi [`armi/martello_verde.png`](riferimenti/armi/martello_verde.png).

```text
The first attached image is the character, the second is the weapon. Draw exactly the same character, same size, same position and same style as in the first image, now holding the weapon from the second image with exactly its shape, proportions and colors.

STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.

CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the man from the reference image, a sly, laid-back stoner. Stocky, light skin, completely bald with a shiny scalp. A small snug bucket hat sitting low on his head, fluorescent hot pink (#FF3FA4) with a pattern of small neon lime-yellow cannabis leaves (#E4FF3A). Thin round wire glasses, a short trimmed dark-brown beard (#3B2A20) and mustache, half-closed heavy-lidded eyes and a sly lazy half-smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green. The small pink hat stays firmly on his head for the whole clip and never disappears: he takes it off only when the action says so, and then it stays visible in his hand or in the air until he puts it back on.

WEAPON (must stay identical in every frame): the rocket hammer from the reference image. A compact chrome hammer head (#EEF1F5, #C3C8CF, #9AA1AB) with one dark panel (#4B5059) engraved with an X, a white light strip, rivets, a rounded block striking face with a hex bolt, and a small rocket at the back with a vent grille, amber striped fins (#F0A030) and a round nozzle. The rocket never fires: no flames. A long thin dark shaft with rings and a ball joint, a light lower grip with rubber stripes and orange accents, a dark blade-shaped pommel. Taller than the character, always held with both hands.

POSE: holding the hammer with both hands on the lower grip, the shaft upright in front of the chest, the hammer head up above the head, ready to swing. He holds it with both hands on the lower grip.

FRAMING: identical to the first image: side view in three-quarters, facing right, full body, same size and same place in the frame.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text. No glow or effects around the weapon beyond its own colors.
```

## Egiainuso

### `egiainuso_spada.png` · Spada al plasma

Allega: [`personaggi/egiainuso.png`](riferimenti/personaggi/egiainuso.png) e poi [`armi/spada_verde.png`](riferimenti/armi/spada_verde.png).

```text
The first attached image is the character, the second is the weapon. Draw exactly the same character, same size, same position and same style as in the first image, now holding the weapon from the second image with exactly its shape, proportions and colors.

STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

WEAPON (must stay identical in every frame): the plasma sword from the reference image. A straight glowing energy blade, solid cyan (#4FD8FF) with a near-white core (#F2FDFF) and a faint cyan halo, rounded tip, no outline on the blade. A metal hilt in steel greys (#A9B0BA, #7F8796): a crown-shaped emitter with three small fins and an amber gem (#F0A93A), a section with vent slots and an amber button, black rubber rings (#2C2F38) between metal ribs, a grooved pommel. The blade is almost as long as the character is tall. The blade is always lit, steady, and never changes color.

POSE: guard stance, holding the hilt at waist height, the blade pointing up and slightly forward, the other hand free and relaxed. He holds it in the round hand nearer to the viewer, with no fingers drawn.

FRAMING: identical to the first image: side view in three-quarters, facing right, full body, same size and same place in the frame.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text. No glow or effects around the weapon beyond its own colors.
```

### `egiainuso_pistola.png` · Pistola

Allega: [`personaggi/egiainuso.png`](riferimenti/personaggi/egiainuso.png) e poi [`armi/pistola_verde.png`](riferimenti/armi/pistola_verde.png).

```text
The first attached image is the character, the second is the weapon. Draw exactly the same character, same size, same position and same style as in the first image, now holding the weapon from the second image with exactly its shape, proportions and colors.

STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

WEAPON (must stay identical in every frame): the energy pistol from the reference image. A chunky boxy body in light teal (#5C9AA4, shadow #41737C) with a lighter top slide (#7FB6BF) with grip ridges, a glowing amber energy cell (#FFC24A) on the side with small charge notches, small rivets, a short grey barrel (#A6AFB9) with three dark grey cooling fins (#5B6270) and a brass muzzle (#D9B04E). A wooden grip (#94603A, darker #6F4529) with a diamond-checkered panel and a brass screw. About one third of the character's height.

POSE: relaxed stance, holding the pistol with the arm slightly bent, the muzzle pointing forward and slightly down, finger off the trigger. He holds it in the round hand nearer to the viewer, with no fingers drawn.

FRAMING: identical to the first image: side view in three-quarters, facing right, full body, same size and same place in the frame.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text. No glow or effects around the weapon beyond its own colors.
```

### `egiainuso_lancia.png` · Lancia di pietra

Allega: [`personaggi/egiainuso.png`](riferimenti/personaggi/egiainuso.png) e poi [`armi/lancia_verde.png`](riferimenti/armi/lancia_verde.png).

```text
The first attached image is the character, the second is the weapon. Draw exactly the same character, same size, same position and same style as in the first image, now holding the weapon from the second image with exactly its shape, proportions and colors.

STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

WEAPON (must stay identical in every frame): the stone spear from the reference image. A leaf-shaped grey-blue stone tip (#BCC6CF, shadow #8995A1) with a central ridge and engraved arrow marks. Two curved bone fangs (#EFE2C4) with dark tips at the base of the tip. A red cloth band (#C2452F) with crossed lacing, and a cream cord with two red beads and hanging feathers striped blue (#2F6F9A) and black (#1D2B3A). A twisted wooden shaft (#8F6D46, darker #6A4E31) with stitched dark leather wraps (#4D3B2B) and a small metal butt cap. A little taller than the character.

POSE: standing tall, holding the spear upright beside the body, the butt touching the ground next to the front foot, the stone tip pointing up above the head. He holds it in the round hand nearer to the viewer, with no fingers drawn.

FRAMING: identical to the first image: side view in three-quarters, facing right, full body, same size and same place in the frame.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text. No glow or effects around the weapon beyond its own colors.
```

### `egiainuso_martello.png` · Martello a razzo

Allega: [`personaggi/egiainuso.png`](riferimenti/personaggi/egiainuso.png) e poi [`armi/martello_verde.png`](riferimenti/armi/martello_verde.png).

```text
The first attached image is the character, the second is the weapon. Draw exactly the same character, same size, same position and same style as in the first image, now holding the weapon from the second image with exactly its shape, proportions and colors.

STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.

CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.

WEAPON (must stay identical in every frame): the rocket hammer from the reference image. A compact chrome hammer head (#EEF1F5, #C3C8CF, #9AA1AB) with one dark panel (#4B5059) engraved with an X, a white light strip, rivets, a rounded block striking face with a hex bolt, and a small rocket at the back with a vent grille, amber striped fins (#F0A030) and a round nozzle. The rocket never fires: no flames. A long thin dark shaft with rings and a ball joint, a light lower grip with rubber stripes and orange accents, a dark blade-shaped pommel. Taller than the character, always held with both hands.

POSE: holding the hammer with both hands on the lower grip, the shaft upright in front of the chest, the hammer head up above the head, ready to swing. He holds it with both hands on the lower grip.

FRAMING: identical to the first image: side view in three-quarters, facing right, full body, same size and same place in the frame.

BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text. No glow or effects around the weapon beyond its own colors.
```
