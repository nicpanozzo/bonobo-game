#!/usr/bin/env python3
# Uso: python3 tools/flow/prompt_flow.py
# Unica fonte dei prompt per Google Flow (#539). Genera:
#   docs/clip-flow/prompt/<personaggio>.md   tutti i prompt delle clip, pronti da incollare
#   docs/clip-flow/immagini-partenza.md      i prompt delle immagini di partenza con le armi
#   docs/clip-flow/base.md                   il pacchetto base (immagine + 2 clip) dei personaggi ancora senza Flow
#   docs/clip-flow/produzione.md             il foglio di produzione, SOLO se non esiste (poi si aggiorna a mano)
# Per cambiare un prompt si cambia questo file e si rigenera: i .md generati non si toccano a mano.
# Le regole dietro i testi (pause, massimo 2 attacchi, niente effetti) sono in docs/clip-flow/README.md.
import os
import re

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "../.."))
OUT = os.path.join(ROOT, "docs/clip-flow")
FPS = 24  # i video di Flow sono a 24 fotogrammi al secondo
REF = "docs/clip-flow/riferimenti"

# ---------------------------------------------------------------- blocchi fissi

STYLE = {
    "gioco": "STYLE: 2D hand-drawn cartoon animation for a fighting video game, exactly the art style of the reference image: thick black ink outlines, flat cel shading with one shadow tone, clean shapes. Not 3D, not a render, no realistic fur or textures.",
    "illustrato": "STYLE: 2D hand-drawn cartoon illustration animated for a fighting video game, exactly the art style of the reference image: clean dark outlines, cel shading with flat shadow tones, detailed but clean shapes. Not 3D, not a render, not photorealistic.",
    "omino": "STYLE: 2D hand-drawn animation for a fighting video game, exactly the art style of the reference image: a minimal stick figure drawn with thick, even black ink lines and flat fills, no shading, no extra detail. Not 3D, not a render.",
}
SHOT = "SHOT: side view in three-quarters, the character faces right unless the action says otherwise. FRAMING RULE: the whole character (head, hat, hands, feet and everything he carries) always stays completely inside the frame with a wide margin of empty green on every side, even at the top of a jump and at the full reach of a strike; no part of him is ever cut off by or touches the edges of the frame. Locked-off static camera: no camera movement, no zoom, no cuts, no slow motion. The character stays the same size as in the reference image."
BACKGROUND = "BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole frame for the whole clip. No floor, no ground line, no shadow, no dust clouds, no smoke, no particles, no sky, no props."
BACKGROUND_BLOCK = BACKGROUND.replace("no props.", "no props except the grey block described above.")
AVOID = "AVOID: changing the character's colors, face or proportions, extra arms, legs, fingers or heads, {extra}, holding a pose with a limb stretched out, extra accessories, logos, text, subtitles, a second character, any part of the character cut off by or touching the edges of the frame, motion blur, speed lines, sparkles, slash trails, smoke, dust, camera shake. Only the effects explicitly described in ACTION are allowed. No music, no speech."
AVOID_WEAPON = " The weapon never changes shape, color or size, never disappears or duplicates, and stays in the same hand. No muzzle flashes, bullets, lasers, sparks, trails, flames or glow effects coming from the weapon."
ATTACK_RULE = "Every single strike snaps out and is pulled straight back in less than half a second: he never holds a limb stretched out."
START = "From 0 s to 0.5 s he stands still exactly in the pose of the reference image."
HOLD = "From {a} s to {b} s he is back in exactly the pose of the reference image and holds perfectly still, without moving at all."
HOLD_END = "From {a} s to the end of the clip he is back in exactly the pose of the reference image and holds perfectly still."

# finestre di tempo (secondi) per 1, 2 o 3 mosse: dopo ogni mossa una pausa nella posa, da cui lo script taglia
WINDOWS = {1: [(0.5, 6.5)], 2: [(0.5, 2.5), (4.0, 6.0)], 3: [(0.5, 2.0), (3.0, 4.5), (5.5, 7.5)]}

# ---------------------------------------------------------------- personaggi

CHARS = {
    "bradipo": dict(
        code="BR", name="Bradipo Giallo", style="gioco", set="ridotto", wave=1,
        character="CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the yellow sloth fighter from the reference image. Short and stocky, big round head. Golden-yellow fur (#F0C040), cream face with two dark brown eye bands, small black nose, grumpy determined eyebrows. Spiky hot-pink mohawk (#E03080). Plain black t-shirt with no logo or text. Pale cream belly patch. Three long curved silver claws on each hand, short claws on the feet. Nothing else on him.",
        avoid="extra claws, a tail, clothes other than the black t-shirt",
        hold="holds it between the claws of the hand nearer to the viewer (still three claws per hand)",
        note="Ha già gli stati base dal video di Nicola: qui ci sono solo le mosse nuove di #531. Il basso non c'è: scudo e leggero laterale sono con gli artigli, così basta un'immagine di partenza.",
    ),
    "elvedeo": dict(
        code="EL", name="Elvedeo", style="illustrato", set="ridotto", wave=2,
        character="CHARACTER (must stay identical in every frame, same proportions, same colors, same faces): the rasta rider from the reference image, always sitting on his goat. The man: skinny, long face, short beard, round dark sunglasses, long dark-brown dreadlocks with small red, yellow and green beads, a big knitted rasta tam hat with stripes of deep red (#90352D), golden yellow (#E2B85A) and dark forest green (#2F5A2E). An unlit joint in his mouth, never lit, no smoke. Ripped black t-shirt (#261D18), baggy mustard-khaki trousers (#BF9955) with dirt stains, grey crocs (#7E7168). He holds red rope reins in one hand and a long thin wooden staff in the other. A grey pigeon (#625C56, lighter wings #9A8D76) always perched on his shoulder. The goat: white (#F0E0CD) with irregular brown patches (#906E4F), curved grey-brown horns, small goatee, yellow eyes, a red rope collar with a small brass bell.",
        avoid="the man walking on foot or getting off the goat, a second goat, a second bird",
        hold="holds it in the hand that used to hold the staff: in this image there is no staff, and the reins stay in the other hand",
        hold_martello="holds it with both hands: in this image there is no staff and he has let go of the reins",
        note="Ha già fermo, corsa, salto, colpi, speciali e suprema dai video di Nicola: qui ci sono solo le mosse nuove, più doppio salto e pesante in aria. È sempre in sella: in un video vecchio Flow lo aveva messo a piedi. La fascia verde del berretto è verde scuro apposta: controlla che lo scontorno non la buchi.",
    ),
    "marcomunista": dict(
        code="MA", name="Marcomunista", style="illustrato", set="completo", wave=3,
        character="CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the bearded man from the reference image. Stocky, light skin, completely bald under the hat. A fisherman bucket hat with patches of hot pink (#E16393), mint (#A5CEB7) and yellow (#F2C840). Thick black rectangular glasses, a full bushy dark-brown beard (#3B2A20) and mustache, a friendly confident smile. A bright yellow hoodie (#F2C840) with drawstrings and a front pocket, charcoal-grey jeans (#4A484E), white sneakers (#E2E6ED) with pink details (#B75B7A). When he does martial arts his energy is lilac (#C9A7F0), never green.",
        avoid="hair, green energy, a different hat",
        hold="holds it in the hand nearer to the viewer",
        note="Da rifare del tutto: set completo. La sua energia è lilla (come `strikeColor`), mai verde: sparirebbe col verde dello sfondo. Il tormentone \"Viva il comunismo!\" lo mostra il gioco, non la clip.",
    ),
    "egiainuso": dict(
        code="EG", name="Egiainuso", style="omino", set="completo", wave=4,
        character="CHARACTER (must stay identical in every frame, same proportions, same colors): the stick-figure fighter from the reference image. A simple stick figure drawn with thick black lines (#171716). A big round head filled with off-white (#EFEADF), with no eyes, nose or mouth unless the action says so. A black baseball cap with the brim pointing forward. A black backpack on his back. A short thick black line for the body, thin black stick arms and legs, small round black hands and feet. Nothing else on him.",
        avoid="a detailed face, shading, colors other than black and off-white, a realistic body, clothes",
        hold="holds it in the round hand nearer to the viewer, with no fingers drawn",
        note="Da sistemare del tutto: set completo. È un'eccezione alla guida di stile (omino a tratto nero), per questo ha uno STYLE suo. Statistiche, speciale laterale e giù e suprema sono ancora da decidere con Marco: le mosse qui sono proposte.",
    ),
}

# ---------------------------------------------------------------- armi

WEAPONS = {
    "spada": dict(name="Spada al plasma", block="WEAPON (must stay identical in every frame): the plasma sword from the reference image. A straight glowing energy blade, solid cyan (#4FD8FF) with a near-white core (#F2FDFF) and a faint cyan halo, rounded tip, no outline on the blade. A metal hilt in steel greys (#A9B0BA, #7F8796): a crown-shaped emitter with three small fins and an amber gem (#F0A93A), a section with vent slots and an amber button, black rubber rings (#2C2F38) between metal ribs, a grooved pommel. The blade is almost as long as the character is tall. The blade is always lit, steady, and never changes color.",
                  pose="guard stance, holding the hilt at waist height, the blade pointing up and slightly forward, the other hand free and relaxed."),
    "pistola": dict(name="Pistola", block="WEAPON (must stay identical in every frame): the energy pistol from the reference image. A chunky boxy body in light teal (#5C9AA4, shadow #41737C) with a lighter top slide (#7FB6BF) with grip ridges, a glowing amber energy cell (#FFC24A) on the side with small charge notches, small rivets, a short grey barrel (#A6AFB9) with three dark grey cooling fins (#5B6270) and a brass muzzle (#D9B04E). A wooden grip (#94603A, darker #6F4529) with a diamond-checkered panel and a brass screw. About one third of the character's height.",
                    pose="relaxed stance, holding the pistol with the arm slightly bent, the muzzle pointing forward and slightly down, finger off the trigger."),
    "lancia": dict(name="Lancia di pietra", block="WEAPON (must stay identical in every frame): the stone spear from the reference image. A leaf-shaped grey-blue stone tip (#BCC6CF, shadow #8995A1) with a central ridge and engraved arrow marks. Two curved bone fangs (#EFE2C4) with dark tips at the base of the tip. A red cloth band (#C2452F) with crossed lacing, and a cream cord with two red beads and hanging feathers striped blue (#2F6F9A) and black (#1D2B3A). A twisted wooden shaft (#8F6D46, darker #6A4E31) with stitched dark leather wraps (#4D3B2B) and a small metal butt cap. A little taller than the character.",
                   pose="standing tall, holding the spear upright beside the body, the butt touching the ground next to the front foot, the stone tip pointing up above the head."),
    "martello": dict(name="Martello a razzo", block="WEAPON (must stay identical in every frame): the rocket hammer from the reference image. A compact chrome hammer head (#EEF1F5, #C3C8CF, #9AA1AB) with one dark panel (#4B5059) engraved with an X, a white light strip, rivets, a rounded block striking face with a hex bolt, and a small rocket at the back with a vent grille, amber striped fins (#F0A030) and a round nozzle. The rocket never fires: no flames. A long thin dark shaft with rings and a ball joint, a light lower grip with rubber stripes and orange accents, a dark blade-shaped pommel. Taller than the character, always held with both hands.",
                     pose="holding the hammer with both hands on the lower grip, the shaft upright in front of the chest, the hammer head up above the head, ready to swing."),
}

# ---------------------------------------------------------------- mosse
# chiave: (nome in italiano, stati del gioco, è un attacco, testo inglese dell'azione)

M = {
    "idle": ("fermo", ["idle"], False, "he breathes calmly on the spot, shifting his weight slightly from one foot to the other"),
    "walk": ("cammina", ["walk"], False, "he walks on the spot, like on a treadmill, four relaxed steps"),
    "light": ("leggero", ["light"], True, "one quick straight punch forward with the front hand"),
    "movimento": ("fermo, cammina, salto", ["idle", "walk", "jumpSquat", "jump", "fall", "land"], False, "From 0.5 s to 2.5 s he breathes calmly on the spot, shifting his weight slightly from one foot to the other. From 2.5 s to 4.5 s he walks on the spot, like on a treadmill, four relaxed steps. From 4.5 s to 5 s he is back in exactly the pose of the reference image. From 5 s to 5.5 s he bends his knees deeply (squash). From 5.5 s to 6.5 s he jumps straight up. From 6.5 s to 7.25 s he falls back down, arms out, legs ready, and at 7.25 s he lands on the same spot with a strong squash of the knees"),
    "crouch": ("accovacciato", ["crouch"], False, "he crouches down low on the spot, knees bent and head lowered, holds it for a moment, then stands up"),
    "taunt": ("provocazione", ["taunt"], False, "he waves one hand at an invisible opponent with a cheeky grin"),
    "turn_skid": ("si gira e frena", ["turn", "skid"], False, "he quickly turns around to face left and back to face right, then brakes hard on the spot as if stopping from a run, feet dug in, leaning back, arms out for balance"),
    "corsa": ("cammina, corre, frena, si gira", ["walk", "dash", "skid", "turn"], False, "From 0.5 s to 2.5 s he walks on the spot, like on a treadmill, four relaxed steps. From 2.5 s to 4.5 s he runs on the spot, like on a treadmill, leaning forward, arms pumping. From 4.5 s to 5.5 s he brakes hard, feet dug in, leaning back, arms out for balance. From 5.5 s to 6.5 s he quickly turns around to face left and turns back to face right"),
    "salto": ("salto completo", ["jumpSquat", "jump", "doubleJump", "fall", "land"], False, "From 0.5 s to 1 s he bends his knees deeply (squash). From 1 s to 2.5 s he jumps straight up. From 2.5 s to 3.5 s, at the top, he does a second jump in mid-air with a forward somersault. From 3.5 s to 5 s he falls back down, arms out, legs ready, and at 5 s he lands on the same spot with a strong squash of the knees"),
    "salti_ridotto": ("preparazione e atterraggio", ["jumpSquat", "land"], False, "he bends his knees deeply for a split second (squash), jumps straight up, falls back down to the same spot and lands with a strong squash of the knees"),
    "salti_doppio": ("preparazione, doppio salto, atterraggio", ["jumpSquat", "doubleJump", "land"], False, "he bends his knees deeply (squash), jumps straight up, does a second jump in mid-air, falls back down to the same spot and lands with a strong squash"),
    "airDodge": ("schivata in aria", ["airDodge"], False, "he jumps straight up; at the top he tucks into a quick twisting spin as if dodging, opens up again and lands on the same spot"),
    "helpless": ("caduta indifesa", ["helpless"], False, "he jumps straight up, and at the top he goes limp: exhausted dazed face, arms and legs flailing loosely, no control while he falls back down and lands on the same spot"),
    "jab": ("jab a 3 colpi", ["light"], True, "three quick separate jabs forward, one every half second: a punch with the front hand, a punch with the other hand, then a short shove with both open palms"),
    "lightSide": ("leggero laterale", ["lightSide"], True, "one quick straight kick forward at waist height"),
    "lightUp": ("leggero su", ["lightUp"], True, "one quick upward strike above his head with one hand, looking up, then the arm comes straight back down"),
    "lightDown": ("leggero giù", ["lightDown"], True, "he crouches and does one quick low sweep forward along the ground with one hand, then stands"),
    "dashAttack": ("attacco in corsa", ["dashAttack"], True, "he runs two quick steps forward and lunges into a flying shoulder charge, then steps back to the same spot"),
    "dashGrab": ("presa in corsa", ["dashGrab"], True, "he runs two quick steps forward and lunges with both hands stretched far out to grab, closes his hands on empty air, then steps back to the same spot"),
    "heavy": ("pesante", ["heavy"], True, "he pulls back for half a second to charge, then throws one powerful strike forward with his whole body"),
    "heavyUp": ("pesante su", ["heavyUp"], True, "he crouches for half a second to charge, then springs up throwing both arms straight above his head, and lands"),
    "heavyDown": ("pesante giù", ["heavyDown"], True, "he crouches for half a second to charge, then strikes the ground on both sides of him at once with a powerful low sweep, and stands"),
    "lightAir": ("aereo neutro", ["lightAir"], True, "he jumps straight up; at the top he spreads arms and legs wide in one quick star-shaped hit, tucks back in and lands on the same spot"),
    "airForward": ("aereo avanti", ["airForward"], True, "he jumps straight up; at the top he swings one arm forward and down in one quick wide arc in front of him, pulls it back, and lands on the same spot"),
    "airBack": ("aereo indietro", ["airBack"], True, "he jumps straight up; at the top, still facing right and without turning around, he kicks backward to the left with both feet together, pulls them back, and lands on the same spot"),
    "airUp": ("aereo su", ["airUp"], True, "he jumps straight up; at the top he swipes one hand in one quick arc over his head from front to back, pulls it back, and lands on the same spot"),
    "airDown": ("aereo giù", ["airDown"], True, "he jumps straight up; at the top he pulls his knees up and stomps straight down with both feet together, pulls them back, and lands on the same spot"),
    "heavyAir": ("pesante in aria", ["heavyAir"], True, "he jumps straight up; at the top he raises both fists together over his head and slams them down in front of him in one hammer blow, then lands on the same spot"),
    "specialNeutral": ("speciale ferma", ["specialNeutral"], True, "he pushes both open palms forward in one strong push; nothing leaves his hands"),
    "specialSide": ("speciale laterale", ["specialSide"], True, "he dashes forward a short distance with his head down, then steps back to the same spot"),
    "specialDown": ("speciale giù", ["specialDown"], True, "he raises both arms in a guard, holds it for a moment, then throws one quick punch forward"),
    "recovery": ("recupero", ["recovery"], True, "he crouches and leaps very high straight up, spinning around his vertical axis with both arms raised, then falls back down and lands on the same spot"),
    "recovery_helpless": ("recupero e caduta indifesa", ["recovery", "helpless"], True, "he crouches and leaps very high straight up, spinning around his vertical axis with both arms raised, then falls back down limp, arms and legs flailing loosely, and lands on the same spot"),
    "stunned": ("stordito", ["stunned"], False, "he is dizzy on the spot: he wobbles and sways, head circling, knees buckling, arms dangling, but never falls"),
    "grab_pummel": ("presa e colpetti", ["grab", "pummel"], True, "he lunges forward and grabs an invisible opponent with both hands at chest height, holds the empty air firmly and headbutts forward twice, then lets go; nothing is drawn in his hands"),
    "pummel": ("colpetti", ["pummel"], True, "he grabs an invisible opponent in front of him with both hands at chest height, holds the empty air firmly and headbutts forward twice, then lets go; nothing is drawn in his hands"),
    "throwForward": ("lancio avanti", ["throwForward"], True, "he grabs an invisible opponent in front of him with both hands and hurls it forward with a strong two-handed push; nothing is drawn in his hands"),
    "throwBack": ("lancio indietro", ["throwBack"], True, "he grabs an invisible opponent in front of him, spins around and hurls it behind himself, then turns back to face right; nothing is drawn in his hands"),
    "throwUp": ("lancio su", ["throwUp"], True, "he grabs an invisible opponent in front of him, lifts it above his head and launches it straight up, looking up; nothing is drawn in his hands"),
    "throwDown": ("lancio giù", ["throwDown"], True, "he grabs an invisible opponent in front of him, slams it down at his feet and stomps on it once with one foot; nothing is drawn under his foot"),
    "shield": ("scudo", ["shield"], False, "he crouches slightly in a firm guard, both forearms raised in front of his face, steady, breathing slowly"),
    "dodge": ("schivata", ["dodge"], False, "he does a quick dodge on the spot, leaning his body back and then returning"),
    "roll": ("rotolata avanti e indietro", ["roll", "ledgeRoll"], False, "he rolls forward along the ground in a tight ball and stands up facing left, then immediately rolls back the other way and stands up facing right"),
    "hit": ("colpito", ["hit"], False, "he is struck hard by an invisible blow: his head and body snap backward, then he recovers"),
    "grabbed": ("tenuto", ["grabbed"], False, "he is lifted off the ground by the scruff of his neck by an invisible hand: his feet dangle, he squirms and kicks, then he is set back down on his feet; nothing is drawn holding him"),
    "tumble_prone_getup": ("lanciato via, a terra, si rialza", ["tumble", "prone", "getup"], False, "he is knocked up into the air as if hit hard, spins head over heels twice with arms and legs spread, falls flat on his back and lies still for a moment, then stands up"),
    "tech": ("rimbalzo", ["tech"], False, "he falls flat on his back; the instant he touches the ground he springs back up to his feet with a quick flip"),
    "getupAttack": ("attacco da terra", ["getupAttack"], True, "he falls flat on his back, then spins on the ground swinging his legs in a full circle around himself, and stands up"),
    "supreme": ("suprema", ["supreme"], True, "his supreme move"),
    "ledge_strike": ("", [], True, "one quick low forward strike"),
}

# mosse proprie di ogni personaggio (solo il testo inglese; nome e stati restano quelli di M)
OVR = {
    "bradipo": {
        "taunt": "he headbangs twice, his mohawk bouncing, then raises one hand making the rock horns sign with his claws and sticks his tongue out, laughing",
        "dashAttack": "he sprints two steps forward, dives low and slides forward on his belly with both claw hands stretched in front of him, then gets back up and steps back to the same spot",
        "dashGrab": "he runs two quick steps forward and lunges with both claw hands stretched far out to grab, sliding a little on his feet, closes his claws on empty air, then steps back to the same spot",
        "airForward": "he jumps straight up; at the top he swings both claw hands forward and down in one quick wide arc in front of him, pulls them back, and lands on the same spot",
        "airUp": "he jumps straight up; at the top he swipes one claw hand in one quick arc over his head from front to back, pulls it back, and lands on the same spot",
        "recovery": "he crouches and leaps straight up, spinning around his vertical axis like a drill with both claw hands raised above his head, then falls back down and lands on the same spot",
        "shield": "he crouches slightly and crosses both clawed forearms in front of his face as a guard, steady, breathing slowly, eyes narrowed",
        "lightSide": "one quick forward jab, thrusting both claw hands forward together like a spear",
        "getupAttack": "he falls flat on his back, then spins around on the ground swinging both claw hands in a full circle around himself, and stands up",
        "ledge_strike": "one quick low forward claw swipe",
    },
    "elvedeo": {
        "crouch": "the goat bends its legs and crouches low while he leans forward over its neck, they hold it for a moment, then they stand up",
        "taunt": "he grins and taps the unlit joint in his mouth, while the pigeon on his shoulder puffs up its chest and bobs its head",
        "turn_skid": "the goat quickly turns around to face left and back to face right, then brakes hard on the spot as if stopping from a gallop, hooves dug in, while he leans back holding the reins",
        "salti_doppio": "the goat bends its legs (squash) and jumps straight up with him on its back, does a second jump in mid-air kicking out with its hind legs, falls back down and lands on the same spot with a strong squash",
        "airDodge": "the goat jumps straight up with him on its back; at the top it tucks its legs and they do a quick twisting spin as if dodging, then they land on the same spot",
        "helpless": "the goat jumps straight up with him on its back; at the top they both go limp, he slumps off balance with a dazed face, the goat's legs dangle loosely, and they fall back down and land on the same spot",
        "dashAttack": "the goat charges two quick strides forward and he strikes forward with his staff, then they step back to the same spot",
        "dashGrab": "the goat charges two quick strides forward and he leans out reaching far with his free hand to grab, closes it on empty air, then they step back to the same spot",
        "airForward": "the goat jumps straight up with him on its back; at the top he swings his staff forward and down in one quick arc in front of them, pulls it back, and they land on the same spot",
        "airBack": "the goat jumps straight up with him on its back; at the top the goat kicks backward to the left with both hind legs, pulls them back, and they land on the same spot",
        "airUp": "the goat jumps straight up with him on its back; at the top he twirls his staff once above his head, and they land on the same spot",
        "airDown": "the goat jumps straight up with him on its back; at the top the goat stomps straight down with all four hooves together, and they land on the same spot",
        "heavyAir": "the goat jumps straight up with him on its back; at the top he raises his staff high with both hands and brings it down in one big overhead blow in front of them, and they land on the same spot",
        "recovery": "the goat crouches and makes one huge leap straight up like a mountain ibex with him on its back, and they fall back down and land on the same spot",
        "stunned": "they are both dizzy on the spot: the goat wobbles on unsteady legs, he sways in the saddle with his head circling, but they never fall",
        "pummel": "he grabs an invisible opponent in front of the goat with his free hand and hits it twice with the butt of his staff, then lets go; nothing is drawn in his hand",
        "throwForward": "he grabs an invisible opponent in front of the goat with his free hand and shoves it away forward with his staff; nothing is drawn in his hand",
        "throwBack": "he grabs an invisible opponent in front of the goat and passes it behind them, and the goat kicks it away backward with both hind legs; nothing is drawn",
        "throwUp": "he grabs an invisible opponent in front of the goat, and the goat tosses it straight up with a quick upward butt of its horns; nothing is drawn",
        "throwDown": "he grabs an invisible opponent in front of the goat and slams it down in front of them, and the goat stomps on it once with its front hooves; nothing is drawn",
        "grabbed": "he is pulled up by the back of his t-shirt by an invisible hand, half lifted out of the saddle, while the goat kicks its legs in the air; then he drops back into the saddle; nothing is drawn holding him",
        "shield": "he holds his staff crosswise in front of himself as a guard while the goat lowers its head and braces, steady",
        "lightSide": "one quick poke forward with the tip of his staff",
        "dodge": "the goat makes a quick hop to the side and back, with him on its back",
        "roll": "the goat dashes quickly forward a short distance staying low, then dashes back to the same spot, with him on its back",
        "tumble_prone_getup": "they are knocked up into the air as if hit hard and spin around once together, then the goat falls and lies down on its belly with him slumped forward on its neck, they hold still for a moment, then the goat gets up with him still riding",
        "tech": "the goat falls on its belly with him on its back; the instant it touches the ground it springs back up onto its hooves",
        "getupAttack": "the goat lies down on its belly, then gets up kicking out all around with its legs while he swings his staff in a circle",
        "ledge_strike": "one quick staff swing forward, low",
    },
    "marcomunista": {
        "idle": "he breathes calmly in a relaxed martial-arts stance, his open hands drifting apart slightly",
        "crouch": "he sinks into a low kung fu horse stance, holds it for a moment, then stands up",
        "taunt": "he performs a slow tai chi movement, his hands circling in front of his chest with a soft glow of lilac energy between them, then the glow fades",
        "salto": "From 0.5 s to 1 s he bends his knees deeply (squash). From 1 s to 2.5 s he jumps straight up. From 2.5 s to 3.5 s, at the top, he does a second jump spinning around once in mid-air inside a thin ring of lilac energy that fades at once. From 3.5 s to 5 s he falls back down, arms out, and at 5 s he lands on the same spot in a low crouch",
        "jab": "three quick separate palm strikes forward, one every half second: an open palm strike with the front hand, one with the other hand, then a short shove with both palms",
        "lightSide": "one quick straight front kick forward at waist height",
        "lightUp": "one quick upward palm strike above his head, looking up, then the arm comes straight back down",
        "lightDown": "he drops into a low crouch and does one quick low palm strike forward near the ground, then stands",
        "dashAttack": "he runs two quick steps forward into a flying kick, then lands and steps back to the same spot",
        "heavy": "he pulls back for half a second, then one powerful side kick forward with a small burst of lilac energy at his foot that fades at once",
        "heavyUp": "he crouches for half a second, then thrusts both arms to the sky with a short flash of lilac energy above his hands that fades at once",
        "heavyDown": "he drops his weight down for half a second, then slams both palms toward the ground and a small wave of lilac energy runs along the ground on both sides and fades at once",
        "lightAir": "he jumps straight up; at the top he spreads arms and legs wide in a quick martial-arts star pose, tucks back in and lands on the same spot",
        "airForward": "he jumps straight up; at the top he does one quick flying kick forward, pulls the leg back, and lands on the same spot",
        "airBack": "he jumps straight up; at the top, still facing right and without turning around, he does one quick kung fu kick backward to the left, pulls the leg back, and lands on the same spot",
        "airUp": "he jumps straight up; at the top he does one quick scissor kick upward, and lands on the same spot",
        "airDown": "he jumps straight up; at the top he punches straight down below him, pulls the fist back, and lands on the same spot",
        "heavyAir": "he jumps straight up; at the top he spins once with a ring of lilac energy around his waist that fades at once, and lands on the same spot",
        "specialNeutral": "he pushes both open palms forward in one strong martial-arts push; nothing leaves his hands",
        "specialSide": "he slides quickly forward a short distance with one palm strike, then steps back to the same spot",
        "specialDown": "he raises both open hands in a parry, holds the guard for a moment, then brings one hand to his mouth as if smoking",
        "recovery_helpless": "he thrusts both arms to the sky and rises very high straight up with a short trail of lilac energy under his feet, then falls back down limp, arms and legs flailing loosely, and lands on the same spot",
        "supreme": "he raises both hands to his head in shock; a ring of lilac energy spreads around his waist; then a small lilac cloud wraps around him for a moment and fades away, leaving him standing",
        "grab_pummel": "he lunges forward and grabs an invisible opponent with both hands, holds the empty air firmly and strikes twice with his palm, then lets go; nothing is drawn in his hands",
        "throwForward": "he grabs an invisible opponent in front of him and pushes it away with a strong two-palm push; nothing is drawn in his hands",
        "throwBack": "he grabs an invisible opponent in front of him and turns like a judo throw, flinging it behind him over his shoulder, then turns back to face right; nothing is drawn in his hands",
        "throwUp": "he grabs an invisible opponent in front of him and launches it straight up with an upward palm strike, looking up; nothing is drawn in his hands",
        "throwDown": "he grabs an invisible opponent in front of him and pushes it down to the ground with both palms; nothing is drawn",
        "shield": "he holds both open hands low in front of him in a calm martial-arts guard, steady, breathing slowly",
        "hit": "he is struck by an invisible blow: one hand goes to his face and he bends backward, then recovers",
        "getupAttack": "he falls flat on his back, then spins on the ground in a breakdance windmill kick, legs swinging in a full circle, and stands up",
        "ledge_strike": "one quick low forward kick",
    },
    "egiainuso": {
        "idle": "he sways gently on his stick legs, breathing",
        "crouch": "he folds his stick legs into a low zig-zag crouch, holds it for a moment, then stands up",
        "taunt": "he puffs up his cheeks twice (two small round bumps on the sides of his head) and waves one stick arm at an invisible opponent",
        "jab": "three quick separate jabs forward, one every half second: a punch, another punch, then a quick little kick",
        "lightSide": "one quick sideways kick forward with his stick leg fully straight",
        "lightUp": "one quick punch straight up above his head, then the arm comes straight back down",
        "lightDown": "one quick low kick sweeping along the ground",
        "dashAttack": "he runs two quick steps forward and slides feet-first along the ground, then stands and steps back to the same spot",
        "heavy": "he pulls back for half a second, then throws one punch forward with his stick arm stretching out long like a rubber band and snapping back to normal length",
        "heavyUp": "he crouches for half a second, then hops up throwing one punch straight above his head, and lands",
        "heavyDown": "he drops into a split with both stick legs kicking out to the sides at once, then stands up",
        "airUp": "he jumps straight up; at the top he does one quick headbutt upward with his cap, and lands on the same spot",
        "heavyAir": "he jumps straight up; at the top he does one quick somersault ending in a kick forward, and lands on the same spot",
        "specialNeutral": "he leans his head back and puffs up his cheeks (two small round bumps on the sides of his head), then leans forward and spits; nothing visible comes out",
        "specialSide": "he dashes forward a short distance with his head down, then steps back to the same spot",
        "specialDown": "he raises both stick arms crossed in a guard, holds it for a moment, then throws one quick punch forward",
        "recovery_helpless": "he spins his arms like a propeller and rises very high straight up, then falls back down limp, stick arms and legs flailing loosely, and lands on the same spot",
        "supreme": "he crouches, then a jagged black zig-zag aura flares up around his whole body while he stands with arms spread wide for two seconds, then the aura fades",
        "grab_pummel": "he grabs an invisible opponent in front of him with both round hands, holds the empty air and hits it with two quick knee strikes, then lets go; nothing is drawn in his hands",
        "throwForward": "he grabs an invisible opponent in front of him and pushes it away with both hands; nothing is drawn in his hands",
        "shield": "he crosses both stick arms in front of his face as a guard, steady",
        "getupAttack": "he falls flat on his back, then spins on the ground with his stick legs straight out in a full circle, and stands up",
        "ledge_strike": "one quick low forward kick",
    },
}

# ---------------------------------------------------------------- elenco delle clip
# (slug, titolo, mosse). "ledge" e "supreme" hanno un testo loro.

SETS = {
    "ridotto": [
        ("fermo", "Fermo", ["crouch", "taunt", "turn_skid"]),
        ("salti", "Salti", ["salti_ridotto", "airDodge", "helpless"]),
        ("corsa-attacchi", "Attacchi in corsa", ["dashAttack", "dashGrab"]),
        ("aerei-a", "Aerei A", ["airForward", "airUp"]),
        ("aerei-b", "Aerei B", ["airBack", "airDown"]),
        ("recupero", "Recupero", ["recovery", "stunned"]),
        ("presa", "Presa", ["pummel", "throwForward"]),
        ("lanci-a", "Lanci A", ["throwBack", "throwUp"]),
        ("lanci-b", "Lanci B", ["throwDown", "grabbed"]),
        ("guardia", "Guardia", ["shield", "lightSide"]),
        ("difesa", "Difesa", ["dodge", "roll"]),
        ("a-terra-a", "A terra A", ["tumble_prone_getup"]),
        ("a-terra-b", "A terra B", ["tech", "getupAttack"]),
        ("bordo", "Bordo", ["ledge"]),
    ],
    "completo": [
        ("fermo", "Fermo", ["idle", "crouch", "taunt"]),
        ("corsa", "Corsa", ["corsa"]),
        ("salto", "Salto", ["salto"]),
        ("leggeri-a", "Leggeri A", ["jab", "lightUp"]),
        ("leggeri-b", "Leggeri B", ["lightSide", "lightDown"]),
        ("corsa-attacchi", "Attacchi in corsa", ["dashAttack", "dashGrab"]),
        ("pesanti-a", "Pesanti A", ["heavy", "heavyUp"]),
        ("pesanti-b", "Pesanti B", ["heavyDown", "airDodge"]),
        ("aerei-a", "Aerei A", ["lightAir", "airForward"]),
        ("aerei-b", "Aerei B", ["airBack", "airUp"]),
        ("aerei-c", "Aerei C", ["airDown", "heavyAir"]),
        ("speciali-a", "Speciali A", ["specialNeutral", "specialSide"]),
        ("speciali-b", "Speciali B", ["specialDown", "recovery_helpless"]),
        ("suprema", "Suprema", ["supreme"]),
        ("presa", "Presa", ["grab_pummel", "throwForward"]),
        ("lanci", "Lanci", ["throwBack", "throwUp"]),
        ("colpito", "Colpito", ["throwDown", "hit", "stunned"]),
        ("difesa", "Difesa", ["shield", "dodge", "roll"]),
        ("a-terra-a", "A terra A", ["tumble_prone_getup"]),
        ("a-terra-b", "A terra B", ["tech", "getupAttack", "grabbed"]),
        ("bordo", "Bordo", ["ledge"]),
    ],
}
# Elvedeo: il doppio salto e il pesante in aria mancano ai suoi video
VARIANTS = {"elvedeo": {"salti": ["salti_doppio", "airDodge", "helpless"], "recupero": ["recovery", "heavyAir", "stunned"]}}

# ---------------------------------------------------------------- clip delle armi (uguali per tutti)

W = {
    "idle": "he stands in guard holding the {w} steady, breathing calmly",
    "walk": "he walks on the spot, like on a treadmill, four steps, holding the {w} steady",
    "spadaAir": "he jumps straight up; at the top he swings the sword in one quick full circle around himself, then lands on the same spot",
    "spadaLight": "two quick horizontal slashes forward with the sword, one from left to right and one back from right to left, each pulled straight back",
    "spadaHeavy": "he raises the sword above his head with both hands for half a second, then one strong vertical slash downward in front of him, and returns to guard",
    "pistolaAir": "he jumps straight up; at the top he points the pistol diagonally down in front of him and his wrist jerks once as if firing, then lands on the same spot",
    "pistolaLight": "he extends the arm straight forward, his wrist jerks once as if firing a quick shot, and the arm comes back",
    "pistolaHeavy": "he grips the pistol with both hands, aims straight forward, his arms jerk up as if firing a strong shot and the recoil pushes him one step back, then he steps forward again",
    "lanciaAir": "he jumps straight up; at the top he thrusts the spear straight down below him, pulls it back, and lands on the same spot",
    "lanciaLight": "two quick thrusts of the spear straight forward, each pulled straight back",
    "lanciaHeavy": "he twirls the spear once above his head, then strikes down in front of him with it, and returns to guard",
}
WCLIPS = [  # (codice, slug, titolo, arma, mosse [(stato, testo)], tipo)
    ("A1", "spada-movimento", "Spada: movimento", "spada", [("spadaIdle", "idle"), ("spadaWalk", "walk"), ("spadaAir", "spadaAir")], "normale"),
    ("A2", "spada-attacchi", "Spada: attacchi", "spada", [("spadaLight", "spadaLight"), ("spadaHeavy", "spadaHeavy")], "normale"),
    ("A3", "pistola-movimento", "Pistola: movimento", "pistola", [("pistolaIdle", "idle"), ("pistolaWalk", "walk"), ("pistolaAir", "pistolaAir")], "normale"),
    ("A4", "pistola-attacchi", "Pistola: attacchi", "pistola", [("pistolaLight", "pistolaLight"), ("pistolaHeavy", "pistolaHeavy")], "normale"),
    ("A5", "lancia-movimento", "Lancia: movimento", "lancia", [("lanciaIdle", "idle"), ("lanciaWalk", "walk"), ("lanciaAir", "lanciaAir")], "normale"),
    ("A6", "lancia-attacchi", "Lancia: attacchi", "lancia", [("lanciaLight", "lanciaLight"), ("lanciaHeavy", "lanciaHeavy")], "normale"),
    ("A7", "lancia-lancio", "Lancia: lancio", "lancia", [("lanciaThrow", None)], "lancio"),
    ("A8", "martello", "Martello", "martello", [("martelloIdle", None), ("martelloWalk", None), ("martelloJump", None)], "martello"),
]
ATTACK_W = {"spadaAir", "spadaLight", "spadaHeavy", "pistolaAir", "pistolaLight", "pistolaHeavy", "lanciaAir", "lanciaLight", "lanciaHeavy"}
W_IT = {"idle": "fermo in guardia", "walk": "cammina", "spadaAir": "aereo (in aria)", "pistolaAir": "aereo (in aria)", "lanciaAir": "aereo (in aria)",
        "spadaLight": "J (leggero)", "pistolaLight": "J (leggero)", "lanciaLight": "J (leggero)", "spadaHeavy": "K (pesante)", "pistolaHeavy": "K (pesante)", "lanciaHeavy": "K (pesante)"}
W_NAMES = {"spada": "sword", "pistola": "pistol", "lancia": "spear", "martello": "hammer"}


def elvedeo_weapon(text):
    # Elvedeo è sempre in sella: si muove la capra
    return (text.replace("he walks on the spot, like on a treadmill, four steps,", "the goat walks on the spot, like on a treadmill, four steps, while he keeps")
            .replace("he jumps straight up;", "the goat jumps straight up with him on its back;")
            .replace("then lands on the same spot", "then they land on the same spot").replace(", and lands on the same spot", ", and they land on the same spot")
            .replace("pushes him one step back, then he steps forward again", "pushes the goat one step back, then the goat steps forward again"))

# ---------------------------------------------------------------- pacchetto base (Nicola, 3/11/2026)
# Prima una base per tutti, poi si raffina: per chi non ha ancora disegni da Flow, un'immagine di partenza nuova
# (Nano Banana, gratis) e due clip Lite che coprono le 7 animazioni obbligatorie; il resto lo fanno i ripieghi
# di ANIMATION_FALLBACK. 20 crediti a personaggio: 2 personaggi al giorno coi 50 crediti giornalieri.

BASE_STYLE = "STYLE: 2D hand-drawn cartoon illustration for a fighting video game: thick black ink outlines of even thickness, flat colors with one hard-edged shadow tone, clean round shapes, a very expressive face, normal body proportions with the head not oversized. Not 3D, not a render, no gradients, no realistic textures."
BASE_PREFIX = "CHARACTER (must stay identical in every frame, same proportions, same colors, same face): the character from the reference image, "

BASE = {
    # day: giorno del piano; look: com'è fatto, in inglese, senza il prefisso; da_fare: cosa manca prima di generare
    "giovannifrana": dict(
        code="GF", name="Giovanni fRana", day=1, style="gioco",
        look="a sturdy, broad-shouldered young man, a relaxed and cheerful beach brawler. Light tanned skin (#E8B98F), thick messy curly dark brown hair (#3B2618), a short dark brown beard (#3B2618), a confident grin. A short-sleeved red Hawaiian shirt (#C0392B) with big cream-yellow hibiscus flowers (#F1C40F), unbuttoned at the collar. Knee-length beige cargo shorts (#C8B48A). White sneakers (#EDEDED) with short white socks. Bare forearms. Nothing else on him.",
        avoid="a ball, a football shirt, glasses, a cigarette, sandals",
        source="il foglio sprite di @Marcomunista nell'ultimo commento di #528 (3/11), scelto da Nicola il 4/11",
        da_fare="Aspettare l'ok di Riccardo (@GiovannifRana) in #528 sul foglio scelto da Nicola.",
    ),
    "lendmar": dict(
        code="LE", name="Lendmar", day=1, style="gioco",
        look="a lean young man dressed all in black, serious and a bit grim. Light skin (#EAC9AE), short dark brown hair (#2A1E18), thick frowning eyebrows, a stern stare. A tall black brimless cap (#141414), slightly crooked. A black long-sleeved button-up shirt (#1A1A1A) tucked into black trousers (#141414) with a black belt and a dull silver buckle (#8A8A8A). Black lace-up boots (#0E0E0E). Nothing else on him.",
        avoid="colorful clothes, a smile, a fringe over the eyes",
        source="il foglio sprite di @Marcomunista in #536, approvato da Nicola il 4/11",
        da_fare="",
    ),
    "orsoblu": dict(
        code="OB", name="Capt. OrsoBlu", day=2, style="gioco",
        look="a stocky grumpy blue bear sea captain standing on two legs. Cobalt-indigo fur (#3B4F9A), lighter blue muzzle and belly (#8FA6D8), big round dark nose, thick frowning eyebrows, scowling mouth. Crooked navy captain's cap (#1F2A44) with a small gold anchor badge (#E0B040). Short mustard-yellow double-breasted pea coat (#D9A520) with brass buttons. Small red neckerchief (#B83A2E). Heavy black sea boots (#2A2A2A). A small upside-down wooden rowboat (#8B5A2B) strapped on his back like a turtle shell, a light wooden oar (#C49A6C) strapped across it. Brass whistle on a cord, small brass spyglass in his belt. Nothing else on him.",
        avoid="an anchor, a chain, a rope, the boat leaving his back",
        source="l'immagine di partenza nuova, già fatta su Flow il 3/11 (progetto \"nov 03 - 23:37\"): va salvata nella repo", ready=True,
        da_fare="",
    ),
    "marcomunista": dict(
        code="MA", name="Marcomunista", day=2, style="illustrato", look=None,
        source="`riferimenti/personaggi/marcomunista.png` (già nella repo)", ready=True,
        da_fare="",
    ),
    "lampione": dict(
        code="LA", name="Lampione", day=3, style="gioco",
        look="a big, burly, wild and hyper-competitive man. Light skin (#F0C3A0), red-ginger buzz cut (#C4602F), ginger stubble, wide crazy eyes and a big toothy grin. A dark olive-green long-sleeved shirt (#4F6B3A) with a loose red tie (#C0392B), brown trousers (#6B4A30), dark brown shoes (#3A2A20). Bright yellow padded goalkeeper gloves (#E9EC3C) on both hands. Nothing else on him.",
        avoid="a ball, a racket, a hat",
        source="lo sprite di oggi (scheda della community, #13)",
        da_fare="",
    ),
    "drmicelium": dict(
        code="DM", name="Dr. Micelium", day=3, style="gioco",
        look="a rasta trauma surgeon infected by mushrooms. Brown skin (#C98F62), long brown dreadlocks (#8A5A2B) with tiny orange-brown mushrooms (#C9A27A) growing in them and on his shoulders, a calm, wise half-smile. A long white surgeon's coat (#F4F1EA) with a few small red stains (#D23B3B) on the sleeves, open over blue-grey scrubs (#5F7B8A), dark brown shoes (#3A2E29). An unlit joint in his mouth, never lit. Nothing else on him.",
        avoid="smoke, a scalpel, a surgical mask, spores",
        source="lo sprite di oggi (scheda della community, #13)",
        da_fare="",
    ),
    "coachcartier": dict(
        code="EM", name="Electronmaster", day=4, style="gioco",
        look="a tall, muscular sports coach. Dark brown skin (#6B4630), a big round black afro (#1C1512), a confident grin. A shiny green tracksuit (#1F8A4C) with yellow stripes (#F2D02E) down the sleeves and the legs, white sneakers (#F4F4F4), two thick gold chains around his neck (#E0B040). Nothing else on him.",
        avoid="a whistle, a clipboard, a cap",
        source="lo sprite di oggi (scheda della community, #13)",
        da_fare="",
    ),
    "nonnagina": dict(
        code="NG", name="Nonna Gina", day=4, style="gioco", she=True,
        look="a short, sturdy Italian grandmother from the countryside, warm but bossy. Light skin (#F2CFB3), grey hair in a tight bun (#DCD9D3), round glasses, rosy cheeks, a stern loving face. A purple cardigan (#7B4F8E), a navy-blue skirt (#3F4A5C) to below the knee, a white apron (#F3EFE6) with a small front pocket, skin-colored stockings (#D8B597), red slippers (#9C3B2E). She always holds a long wooden rolling pin (#C49A6C) in the hand nearer to the viewer. Nothing else on her.",
        avoid="a second rolling pin, food, a handbag",
        source="lo sprite di oggi e la scheda `docs/mosse/nonnagina.md`",
        da_fare="",
    ),
    "opus": dict(
        code="OP", name="Maestro Opus", day=5, style="gioco",
        look="a small, pompous bonobo orchestra conductor standing upright. Dark brown-black fur (#2B211C), a pinkish-tan face, hands and feet (#C9A189), a huge wild white mane like Beethoven's (#F2EFE8), a proud chin-up expression. A black tailcoat with long tails (#1A1A22), a white waistcoat and a white bow tie, a red carnation in the buttonhole (#C8323C). Bare bonobo feet, no shoes. In the hand nearer to the viewer an oversized conductor's baton, white with a gold tip (#E0B040), about as long as his arm. Nothing else on him.",
        avoid="shoes, musical notes, a music stand",
        source="lo sprite di oggi e la scheda `docs/mosse/opus.md`",
        da_fare="",
    ),
    "bonobot": dict(
        code="BB", name="Bonobot", day=5, style="gioco",
        look="a cocky, swaggering bonobo standing upright. Black fur (#1E1A18), a pinkish-tan face, ears, hands and feet (#C9A189), a smug grin with half-closed eyes, a messy tuft of hair on top of the head. An unlit joint in the corner of his mouth, never lit. No clothes. Nothing else on him.",
        avoid="clothes, smoke, a tail",
        source="lo sprite di oggi (Riccardo, #20)",
        da_fare="Bonobot è di Riccardo: fagli vedere l'immagine prima delle clip.",
    ),
}

# le mosse proprie del pacchetto base (OVR vale anche qui; Marcomunista usa le sue di sopra)
OVR_BASE = {
    "orsoblu": {
        "light": "one quick jab forward with his fist, scowling",
        "heavy": "he lowers his head for half a second, then rams forward with one powerful shoulder charge, the boat on his back rocking, and steps back",
        "hit": "he is struck hard by an invisible blow: his cap tilts, his head and body snap backward, then he recovers, furious",
    },
    "marcomunista": {"light": "one quick open palm strike forward with the front hand"},
    "lampione": {
        "light": "one quick straight punch forward with his gloved front hand",
        "heavy": "he pulls back for half a second, then dives forward with both gloved fists together like a goalkeeper punching the ball away, and steps back",
    },
    "giovannifrana": {
        "light": "one quick straight jab forward with the front fist",
        "heavy": "he pulls his fist back for half a second, then throws one big swinging punch forward with his whole body, and steps back",
    },
    "lendmar": {"heavy": "he pulls back for half a second, scowling, then throws one angry, powerful punch forward with his whole body"},
    "nonnagina": {
        "light": "one quick poke forward with the end of her rolling pin",
        "heavy": "she raises the rolling pin over her head with both hands for half a second, then brings it down in front of her in one powerful blow",
    },
    "opus": {
        "light": "one quick jab forward with the tip of his baton",
        "heavy": "he raises the baton high for half a second, then brings it down in front of him in one grand, dramatic conducting stroke",
    },
    "coachcartier": {"heavy": "he pulls back for half a second, then throws one powerful uppercut forward and up, his gold chains swinging"},
    "drmicelium": {"heavy": "he pulls back for half a second, then thrusts one open palm forward in a calm, powerful strike"},
}

# Clip già generate con prompt scritti fuori da questo script (OrsoBlu v2, 3/11/2026): servono solo allo script di
# taglio, che ne legge stati e secondi. (codice: personaggio, slug, titolo, tabella (stato, da s, a s, nome))
FATTE = {
    "OB-01": ("orsoblu", "ancora-a", "Ancora A", [("recovery", .5, 2, "lancia l'ancora"), ("anchorHang", 3, 5, "appeso che oscilla"), ("anchorClimb", 6, 7.5, "si arrampica")]),
    "OB-02": ("orsoblu", "ancora-b", "Ancora B", [("specialSide", .5, 2, "teleferica"), ("doubleJump", 3, 4.5, "capriola"), ("specialNeutral", 5.5, 7, "ancora avanti e strattone")]),
    "OB-03": ("orsoblu", "marcia", "Marcia, fischietto, salto", [("walk", .5, 2, "marcia"), ("taunt", 3, 4.5, "fischietto e dito puntato"), ("jumpSquat+jump+fall+land", 5.5, 7.5, "salto")]),
    "OB-B3": ("orsoblu", "colpi-bassi", "Colpi in alto e in basso", [("lightUp", .5, 2, "pugno in alto"), ("lightDown", 3, 4.5, "spazzata bassa"), ("heavyDown", 5.5, 7.5, "spazzata ai due lati")]),
    "OB-07": ("orsoblu", "remo-barca", "Remo e barca", [("heavy", .5, 2, "remata"), ("heavyUp", 3, 4.5, "barca a ombrello"), ("shield", 5.5, 7.5, "sotto la barca")]),
}

BASE_CLIPS = [  # (codice, slug, titolo, mosse)
    ("B1", "movimento", "Movimento", ["movimento"]),
    ("B2", "colpi", "Colpi", ["light", "heavy", "hit"]),
]

# ---------------------------------------------------------------- composizione

# le mosse in sequenza (una clip sola, senza pause in mezzo): da quando torna fermo, e dove taglia lo script (secondi)
SEQ_CUTS = {
    "corsa": (7, [("walk", .5, 2.5), ("dash", 2.5, 4.5), ("skid", 4.5, 5.5), ("turn", 5.5, 6.5)]),
    "salto": (5.5, [("jumpSquat", .5, 1), ("jump", 1, 2.5), ("doubleJump", 2.5, 3.5), ("fall", 3.5, 5), ("land", 5, 5.5)]),
    "movimento": (7.5, [("idle", .5, 2.5), ("walk", 2.5, 4.5), ("jumpSquat", 5, 5.5), ("jump", 5.5, 6.5), ("fall", 6.5, 7.25), ("land", 7.25, 7.5)]),
}


def fmt(x):
    return ("%g" % x).replace(".", ".")


def move_text(cid, key):
    return OVR_BASE.get(cid, {}).get(key) or OVR.get(cid, {}).get(key, M[key][3])


def compose(cid, moves):
    """ACTION per una clip di mosse: testo e tabella (stato, da s, a s, nome)."""
    if moves == ["ledge"]:
        strike = move_text(cid, "ledge_strike")
        who = "the goat hangs by its front hooves from the top-left corner of the block, with him holding on to its neck and the staff," if cid == "elvedeo" else "he hangs by both hands from the top-left corner of the block, his body dangling below the edge,"
        text = ("ACTION: a plain flat medium-grey block (#808080, no texture) fills the right third of the frame from the bottom up to the middle of the frame; it never moves. "
                f"From 0 s to 2 s {who} facing right toward the block, swinging slightly. From 2 s to 3.5 s {'they pull' if cid == 'elvedeo' else 'he pulls himself'} up over the corner and {'stand' if cid == 'elvedeo' else 'stands'} on top of the block. "
                f"From 3.5 s to 4.5 s {'they drop' if cid == 'elvedeo' else 'he drops'} back down and {'hang' if cid == 'elvedeo' else 'hangs'} from the corner again. From 4.5 s to 6 s {'they flip' if cid == 'elvedeo' else 'he flips'} up onto the top of the block with {strike}. "
                f"From 6 s to the end of the clip {'they stand' if cid == 'elvedeo' else 'he stands'} still on top of the block. Everything stays inside the frame for the whole clip.")
        return text, [("ledge", 0, 2, "appeso"), ("climb", 2, 3.5, "si tira su"), ("ledgeAttack", 4.5, 6, "attacco dal bordo")], True
    seq = len(moves) == 1 and moves[0] in SEQ_CUTS
    parts, table, attack = [START], [], False
    if seq:
        key = moves[0]
        parts.append(move_text(cid, key) + ".")
        hold, cuts = SEQ_CUTS[key]
        parts.append(HOLD_END.format(a=fmt(hold)))
        names = {"idle": "fermo", "walk": "cammina", "jumpSquat": "preparazione", "jump": "salto", "fall": "caduta", "land": "atterraggio"} if key == "movimento" else {}
        table = [(s, a, b, names.get(s, M[key][0])) for s, a, b in cuts]
        return "ACTION: " + " ".join(parts), table, False
    win = WINDOWS[len(moves)]
    for i, (key, (a, b)) in enumerate(zip(moves, win)):
        name, states, att, _ = M[key]
        attack |= att
        t = move_text(cid, key)
        label = "Attack" if att else "Move"
        parts.append(f"{label} {i + 1}, from {fmt(a)} s to {fmt(b)} s: {t}.")
        nxt = win[i + 1][0] if i + 1 < len(win) else None
        parts.append(HOLD.format(a=fmt(b), b=fmt(nxt)) if nxt else HOLD_END.format(a=fmt(b)))
        table.append(("+".join(states), a, b, name))
    intro = f"{len(moves)} short separate moves, each one followed by a pause in the starting pose." if len(moves) > 1 else "one move, then back to the starting pose."
    if attack:
        intro += " " + ATTACK_RULE
    return "ACTION: " + intro + " " + " ".join(parts), table, attack


def compose_weapon(cid, wc):
    code, slug, title, arma, moves, kind = wc
    wn = W_NAMES[arma]
    if kind == "lancio":
        text = ("ACTION: one throw. " + START + " From 0.5 s to 2 s he raises the spear above his shoulder, takes one step forward and throws it hard: the spear leaves his hand and flies out of the frame to the right in a straight line within a quarter of a second. "
                "From 2 s to the end of the clip, empty-handed, he goes back to exactly the pose of the last-frame image and holds perfectly still.")
        if cid == "elvedeo":
            text = text.replace("takes one step forward and throws", "leans forward in the saddle and throws")
        return text, [("lanciaThrow", 0.5, 2, "lancio")], True
    if kind == "martello":
        walk = "while the goat walks on the spot, like on a treadmill" if cid == "elvedeo" else "while walking on the spot, like on a treadmill"
        jump = "during one jump of the goat straight up, and they land" if cid == "elvedeo" else "during one jump straight up, and lands"
        text = ("ACTION: hammering. " + START + " From 0.5 s to 2.5 s he swings the hammer up over his head and down in front of him with both hands, striking the empty space in front of his feet, about twice per second. "
                f"From 2.5 s to 4.5 s he keeps hammering the same way {walk}. From 4.5 s to 6 s he keeps hammering {jump} on the same spot. "
                "From 6 s to the end of the clip he is back in exactly the pose of the reference image, the hammer upright, and holds perfectly still. The rocket on the hammer never fires.")
        return text, [("martelloIdle", .5, 2.5, "martella fermo"), ("martelloWalk", 2.5, 4.5, "martella camminando"), ("martelloJump", 4.5, 6, "martella saltando")], True
    win = WINDOWS[len(moves)]
    parts, table, attack = [START], [], False
    for i, ((state, wkey), (a, b)) in enumerate(zip(moves, win)):
        att = wkey in ATTACK_W
        attack |= att
        t = W[wkey].format(w=wn)
        if cid == "elvedeo":
            t = elvedeo_weapon(t)
        parts.append(f"{'Attack' if att else 'Move'} {i + 1}, from {fmt(a)} s to {fmt(b)} s: {t}.")
        nxt = win[i + 1][0] if i + 1 < len(win) else None
        parts.append(HOLD.format(a=fmt(b), b=fmt(nxt)) if nxt else HOLD_END.format(a=fmt(b)))
        table.append((state, a, b, W_IT[wkey]))
    intro = f"{len(moves)} short separate moves with the {wn}, each one followed by a pause in the starting pose."
    if attack:
        intro += " " + ATTACK_RULE
    return "ACTION: " + intro + " " + " ".join(parts), table, attack


def held(cid, arma):
    c = CHARS[cid]
    if arma == "martello":
        return c.get("hold_martello", "holds it with both hands on the lower grip")
    return c.get("hold_" + arma, c["hold"])


def prompt(cid, action, weapon=None, block=False, c=None):
    c = c or CHARS[cid]
    blocks = [STYLE[c["style"]], c["character"]]
    if weapon:
        blocks.append(WEAPONS[weapon]["block"] + f" He {held(cid, weapon)}, exactly as in the first-frame image.")
    blocks += [SHOT, action, BACKGROUND_BLOCK if block else BACKGROUND]
    avoid = AVOID.format(extra=c["avoid"])
    if weapon:
        avoid += AVOID_WEAPON
        if weapon == "lancia" and "throws it hard" in action:
            avoid = avoid.replace("never disappears or duplicates", "never duplicates and leaves the frame only when thrown")
    blocks.append(avoid)
    return "\n\n".join(blocks)


def she(text):
    """Testi al femminile (Nonna Gina): he/his/him diventano she/her."""
    for a, b in (("himself", "herself"), ("He", "She"), ("he", "she"), ("his", "her"), ("him", "her")):
        text = re.sub(rf"\b{a}\b", b, text)
    return text


def base_char(cid):
    """Il personaggio del pacchetto base nel formato di CHARS (style, character, avoid)."""
    b = BASE[cid]
    if b["look"] is None:
        return CHARS[cid]
    return dict(style=b["style"], character=BASE_PREFIX + b["look"], avoid=b["avoid"])


def base_clips(cid):
    """Le clip del pacchetto base: (codice, slug, titolo, modalità, prima, ultima, prompt, tabella), come clips_of()."""
    b = BASE[cid]
    ref = f"{REF}/personaggi/{cid}.png"
    out = []
    for code, slug, title, moves in BASE_CLIPS:
        action, table, _ = compose(cid, moves)
        if b.get("she"):
            action = she(action)
        out.append((f"{b['code']}-{code}", slug, title, "Frames to video", ref, ref, prompt(cid, action, c=base_char(cid)), table))
    return out


def base_start_image(cid):
    b = BASE[cid]
    look = b["look"] if b["look"] else CHARS[cid]["character"].split("): ", 1)[1]
    return "\n\n".join([
        "Draw one original character for a 2D fighting video game, full body, standing in a relaxed fighting stance, side view in three-quarters, facing right. If an image is attached, it only shows who the character is: keep the look, the clothes and the colors, but redraw everything in the style below.",
        BASE_STYLE,
        "CHARACTER: " + look,
        "FRAMING: full body, the character is about two thirds of the image height, in the middle of the image, feet a little above the bottom edge. Nothing cut off.",
        "BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text.",
    ])


def frames(a, b):
    return f"{round(a * FPS)}-{round(b * FPS)}"


def clips_of(cid):
    """Tutte le clip di un personaggio: (codice, slug, titolo, modalità, prima, ultima, prompt, tabella)."""
    c = CHARS[cid]
    ref = f"{REF}/personaggi/{cid}.png"
    out = []
    for n, (slug, title, moves) in enumerate(SETS[c["set"]], 1):
        moves = VARIANTS.get(cid, {}).get(slug, moves)
        code = f"{c['code']}-{n:02d}"
        if moves == ["supreme"]:
            text = "ACTION: one move. " + START + f" From 0.5 s to 6.5 s: {move_text(cid, 'supreme')}. " + HOLD_END.format(a="6.5")
            out.append((code, slug, title, "Frames to video", ref, ref, prompt(cid, text), [("supreme", .5, 6.5, "suprema")]))
            continue
        action, table, _ = compose(cid, moves)
        if moves == ["ledge"]:
            out.append((code, slug, title, "Ingredients to video", ref, "nessuna (Ingredients)", prompt(cid, action, block=True), table))
        else:
            out.append((code, slug, title, "Frames to video", ref, ref, prompt(cid, action), table))
    for wc in WCLIPS:
        code, slug, title, arma, _, kind = wc
        action, table, _ = compose_weapon(cid, wc)
        start = f"{REF}/partenze/{cid}_{arma}.png"
        last = ref if kind == "lancio" else start
        out.append((f"{c['code']}-{code}", slug, title, "Frames to video", start, last, prompt(cid, action, weapon=arma), table))
    return out

# ---------------------------------------------------------------- scrittura dei file

HEAD = "<!-- File generato da tools/flow/prompt_flow.py: non modificarlo a mano, cambia lo script e rigeneralo. -->\n\n"


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def write_character(cid):
    c = CHARS[cid]
    cl = clips_of(cid)
    n_body = len(SETS[c["set"]])
    L = [HEAD, f"# {c['name']}: prompt delle clip ({c['code']})\n",
         f"Ondata {c['wave']} · {len(cl)} clip: {n_body} del personaggio ({c['set'] == 'completo' and 'set completo' or 'solo le mosse nuove'}) e {len(WCLIPS)} delle armi. Come si generano, si consegnano e si controllano: [README](../README.md).\n",
         f"{c['note']}\n",
         "**Immagini da allegare:**\n",
         f"- clip del personaggio: [`{REF}/personaggi/{cid}.png`](../riferimenti/personaggi/{cid}.png), come prima **e** ultima immagine;",
         f"- clip delle armi: `{REF}/partenze/{cid}_<arma>.png` (passo 1 del README). La clip del lancio della lancia finisce sulla posa senza arma.\n",
         "**Impostazioni uguali per tutte:** Veo 3.1 (Lite o Fast, vedi README), 16:9, 8 secondi, 1 risultato.\n",
         "| Codice | Clip | Stati |", "|---|---|---|"]
    for code, slug, title, mode, a, b, p, table in cl:
        L.append(f"| [{code}](#{code.lower()}) | {title} | {', '.join('`' + s + '`' for s, *_ in table)} |")
    L.append("")
    for code, slug, title, mode, a, b, p, table in cl:
        L += [f"## {code}", "", f"**{title}** · file da consegnare: `{code}_{slug}.mp4`", "",
              f"- **Modalità:** {mode}",
              f"- **Prima immagine:** `{a}`" + ("" if mode.startswith("Ingredients") else f"\n- **Ultima immagine:** `{b}`"),
              "" if not mode.startswith("Ingredients") else "- Allega l'immagine come unico ingrediente. Il blocco grigio lo toglie lo script.",
              "| Stato | Secondi | Fotogrammi | Cosa fa |", "|---|---|---|---|"]
        for s, x, y, name in table:
            L.append(f"| `{s}` | {fmt(x)}-{fmt(y)} | {frames(x, y)} | {name} |")
        L += ["", "```text", p, "```", ""]
    write(os.path.join(OUT, "prompt", f"{cid}.md"), "\n".join(L).replace("\n\n\n", "\n\n"))
    return cl


def write_start_images():
    L = [HEAD, "# Immagini di partenza con le armi (passo 1)\n",
         f"16 immagini: {len(CHARS)} personaggi × {len(WEAPONS)} armi. Sono la prima e l'ultima immagine delle clip delle armi. La posa **senza** arma non si genera: è il fermo del gioco in `riferimenti/personaggi/` (prova del 3/11).\n",
         "**Come:** strumento immagini di Flow (Nano Banana), formato **16:9**, 1 risultato. Allega **prima** l'immagine del personaggio e **poi** quella dell'arma, e incolla il prompt.\n",
         f"**Dove vanno:** in `{REF}/partenze/<personaggio>_<arma>.png`, con una PR (passo 1 del README).\n",
         "**Scartala se:** colori o proporzioni del personaggio cambiano, l'arma ha un'altra forma o altri colori, c'è un pavimento, un'ombra o una scritta, il personaggio non guarda a destra o non è intero, cambia grandezza o posizione rispetto al riferimento.\n"]
    for cid, c in CHARS.items():
        L.append(f"## {c['name']}\n")
        for arma, w in WEAPONS.items():
            pose = w["pose"]
            if cid == "elvedeo":
                pose = "sitting on the goat, the goat standing on all four legs facing right; " + pose.replace("standing tall, ", "").replace("the butt touching the ground next to the front foot", "the butt resting on the goat's shoulder")
            text = "\n\n".join([
                "The first attached image is the character, the second is the weapon. Draw exactly the same character, same size, same position and same style as in the first image, now holding the weapon from the second image with exactly its shape, proportions and colors.",
                STYLE[c["style"]], c["character"], w["block"],
                f"POSE: {pose} He {held(cid, arma)}.",
                "FRAMING: identical to the first image: side view in three-quarters, facing right, full body, same size and same place in the frame.",
                "BACKGROUND: one solid flat chroma-key green (#17B03B) filling the whole image. No floor, no ground line, no shadow, no other objects, no text. No glow or effects around the weapon beyond its own colors.",
            ])
            L += [f"### `{cid}_{arma}.png` · {w['name']}\n",
                  f"Allega: [`personaggi/{cid}.png`](riferimenti/personaggi/{cid}.png) e poi [`armi/{arma}_verde.png`](riferimenti/armi/{arma}_verde.png).\n",
                  "```text", text, "```", ""]
    write(os.path.join(OUT, "immagini-partenza.md"), "\n".join(L))


def write_production(allc):
    path = os.path.join(OUT, "produzione.md")
    if os.path.exists(path):
        return False
    L = ["# Foglio di produzione\n",
         "Una riga per clip e per immagine. Lo aggiorna chi lavora, nella PR del suo passo: **Stato** è uno tra `da fare`, `generata`, `consegnata`, `tagliata`, `nel gioco`, `scartata` (per le immagini: `da fare` o `fatta`). Il resto delle istruzioni è nel [README](README.md).\n",
         "Creato da `tools/flow/prompt_flow.py`, che non lo riscrive più: da qui si aggiorna a mano.\n",
         "## Immagini di partenza (passo 1)\n", "| File | Stato | Note |", "|---|---|---|"]
    for cid in CHARS:
        for arma in WEAPONS:
            L.append(f"| `partenze/{cid}_{arma}.png` | da fare | |")
    for cid, cl in allc.items():
        c = CHARS[cid]
        L += ["", f"## Ondata {c['wave']}: {c['name']}\n", "| Codice | Clip | Stato | Tentativi | Modello | Crediti | Commento con l'mp4 | Note |", "|---|---|---|---|---|---|---|---|"]
        for code, slug, title, *_ in cl:
            L.append(f"| {code} | {title} | da fare | | | | | |")
    write(path, "\n".join(L) + "\n")
    return True


def write_base():
    days = sorted({b["day"] for b in BASE.values()})
    L = [HEAD, "# Pacchetto base: prima una base per tutti\n",
         "Per ogni personaggio che non ha ancora disegni da Flow: **un'immagine di partenza nuova** (Nano Banana, 0 crediti) e **due clip Veo 3.1 Lite** (10 crediti l'una) che coprono le 7 animazioni obbligatorie. Il resto lo fanno i ripieghi di `ANIMATION_FALLBACK`; quando le clip sono nel gioco si tolgono le pose vecchie, come per Egiainuso in #542. Dopo, un giro con le animazioni che si vedono di più (corsa, speciale firma, provocazione), poi le ondate complete del [README](README.md).\n",
         "**20 crediti a personaggio, 2 personaggi al giorno** coi 50 crediti giornalieri (si azzerano alle 9:00): i 10 che avanzano servono a rifare la clip venuta peggio. I crediti mensili non si toccano.\n",
         "**Come:** come una clip del README (Frames to video, la stessa immagine come prima e ultima, 16:9, 8 secondi, 1 risultato), ma con **Veo 3.1 Lite**. L'immagine di partenza va in `riferimenti/personaggi/<id>.png`, 16:9, prima delle clip. Lo script di taglio trova le clip con `base_clips()` di `tools/flow/prompt_flow.py`.\n",
         "**Rifalla se:** il personaggio cambia colori o faccia, una mossa resta a metà o col braccio teso, compaiono effetti, pavimento o un secondo personaggio, la clip non finisce nella posa di partenza.\n",
         "| Giorno | Personaggio | Immagine di partenza da | Clip | Prima di generare |", "|---|---|---|---|---|"]
    for cid, b in sorted(BASE.items(), key=lambda kv: kv[1]["day"]):
        codes = ", ".join(f"[{c}](#{c.lower()})" for c, *_ in base_clips(cid))
        L.append(f"| {b['day']} | [{b['name']}](#{cid}) | {b['source']} | {codes} | {b['da_fare'] or '-'} |")
    L.append("")
    for d in days:
        for cid, b in BASE.items():
            if b["day"] != d:
                continue
            L += [f'<a id="{cid}"></a>', "", f"## Giorno {d} · {b['name']}", ""]
            if b["da_fare"]:
                L += [f"**Prima di generare:** {b['da_fare']}", ""]
            L += [f"### Immagine di partenza · `riferimenti/personaggi/{cid}.png`", "",
                  f"Già fatta: {b['source']}." if b.get("ready") else f"Da: {b['source']}. Strumento immagini di Flow (Nano Banana), 16:9, 1 risultato; allega il riferimento se c'è.", ""]
            if not b.get("ready"):
                L += ["```text", base_start_image(cid), "```", ""]
            for code, slug, title, mode, a, z, p, table in base_clips(cid):
                L += [f"### {code}", "", f"**{title}** · file da consegnare: `{code}_{slug}.mp4` · Veo 3.1 Lite, Frames to video, prima e ultima immagine `{a}`", "",
                      "| Stato | Secondi | Fotogrammi | Cosa fa |", "|---|---|---|---|"]
                for st, x, y, name in table:
                    L.append(f"| `{st}` | {fmt(x)}-{fmt(y)} | {frames(x, y)} | {name} |")
                L += ["", "```text", p, "```", ""]
    write(os.path.join(OUT, "base.md"), "\n".join(L))
    return len(BASE_CLIPS) * len(BASE)


def main():
    allc = {cid: write_character(cid) for cid in CHARS}
    write_start_images()
    made = write_production(allc)
    nb = write_base()
    tot = sum(len(v) for v in allc.values())
    print(f"{tot} clip in {len(allc)} file, 16 immagini di partenza, pacchetto base: {nb} clip per {len(BASE)} personaggi" + (", foglio di produzione creato" if made else ""))


if __name__ == "__main__":
    main()
