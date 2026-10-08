// Numeri del gioco condivisi tra client e server.
// Vuoi un gioco più veloce o salti più alti? Si parte da qui.

import type { ChargeSpecial, SpecialSet } from "./characters";
import type { AttackKind, SpecialKind } from "./types";

export const WORLD = {
  width: 1280, // area visibile, pixel
  height: 720,
};

// Palco, piattaforme, zone di espulsione e punti di partenza stanno in stages.ts, uno per arena.

export const TICK_RATE = 60; // aggiornamenti della fisica al secondo (server)
export const SEND_RATE = 30; // stati inviati ai client al secondo
export const MAX_CATCHUP_TICKS = 5; // passi recuperabili in una volta se il server resta indietro
export const MAX_PLAYERS_PER_ROOM = 8; // 4 contro 4 a squadre (#55)

export const FIGHTER = {
  width: 44,
  height: 88,
  groundSpeed: 380, // pixel/s
  airSpeed: 340, // velocità massima orizzontale in aria, pixel/s
  airAccel: 2400, // quanto in fretta si cambia direzione in aria, pixel/s²
  airFriction: 1200, // rallentamento in aria senza tasti premuti, pixel/s²
  jumpSpeed: 860, // pixel/s
  doubleJumpSpeed: 780,
  maxJumps: 2, // salto da terra + salti in aria
  gravity: 2300, // pixel/s²
  maxFallSpeed: 950,
  fastFallSpeed: 1500, // tenendo giù in aria
  dropThroughMs: 200, // per quanto si ignorano le piattaforme dopo aver premuto giù
};

// Scatto con doppio tocco (#199): numeri provvisori, da rivedere al playtest (#22).
// Lo scatto va avanti per circa speed * durationMs = 270 pixel, poi tenendo la direzione si corre
export const DASH = {
  doubleTapMs: 250, // ms entro cui il secondo tocco della stessa direzione fa scattare
  tapMaxMs: 120, // il primo tocco dev'essere breve: chi tiene la direzione più a lungo (camminando, i bot) non scatta
  speed: 900, // pixel/s durante lo scatto (la camminata è FIGHTER.groundSpeed, 380)
  durationMs: 300, // ms di scatto, anche lasciando il tasto
  runSpeed: 560, // pixel/s di corsa tenendo la direzione dopo lo scatto
};

export interface AttackSpec {
  damage: number; // percentuale aggiunta al bersaglio
  baseKnockback: number; // pixel/s anche a 0%
  knockbackGrowth: number; // pixel/s in più per ogni punto di percentuale
  startupMs: number; // attesa prima che il colpo diventi attivo
  activeMs: number; // per quanto tempo il colpo può fare danno
  cooldownMs: number; // tempo dall'inizio del colpo prima di poterne fare un altro
  range: number; // lunghezza della hitbox davanti al personaggio, pixel
  height: number;
  angleDeg: number; // angolo di lancio sopra l'orizzontale
  boxX?: number; // pixel dal centro del personaggio, in avanti, dove comincia la hitbox (di base: metà larghezza)
  boxY?: number; // pixel dai piedi in su dove sta il bordo alto della hitbox, negativo (di base: -70% dell'altezza)
}

// Le speciali (E10) non sono qui: i loro numeri dipendono dal personaggio (specialAttackSpec in characters.ts)
export const ATTACKS: Record<Exclude<AttackKind, SpecialKind>, AttackSpec> = {
  light: {
    damage: 5,
    baseKnockback: 260,
    knockbackGrowth: 5,
    startupMs: 40,
    activeMs: 100,
    cooldownMs: 280,
    range: 52,
    height: 30,
    angleDeg: 35,
  },
  heavy: {
    damage: 13,
    baseKnockback: 420,
    knockbackGrowth: 11,
    startupMs: 260,
    activeMs: 120,
    cooldownMs: 750,
    range: 70,
    height: 44,
    angleDeg: 42,
  },
  // Attacchi direzionali (#2): valori provvisori, da discutere alla serata di playtest (#22)
  lightUp: { damage: 6, baseKnockback: 280, knockbackGrowth: 5, startupMs: 60, activeMs: 110, cooldownMs: 320, range: 54, height: 48, angleDeg: 85, boxX: -27, boxY: -128 }, // sopra la testa
  lightDown: { damage: 4, baseKnockback: 230, knockbackGrowth: 4.5, startupMs: 50, activeMs: 110, cooldownMs: 300, range: 60, height: 24, angleDeg: 18, boxX: 10, boxY: -24 }, // sgambetto basso
  lightAir: { damage: 6, baseKnockback: 260, knockbackGrowth: 5, startupMs: 50, activeMs: 160, cooldownMs: 320, range: 54, height: 50, angleDeg: 40, boxX: 8, boxY: -72 },
  heavyUp: { damage: 14, baseKnockback: 430, knockbackGrowth: 11.5, startupMs: 280, activeMs: 130, cooldownMs: 800, range: 80, height: 64, angleDeg: 88, boxX: -40, boxY: -144 }, // lancia in verticale
  heavyDown: { damage: 12, baseKnockback: 400, knockbackGrowth: 10, startupMs: 240, activeMs: 140, cooldownMs: 760, range: 88, height: 30, angleDeg: 25, boxX: 8, boxY: -30 }, // spazzata radente
  heavyAir: { damage: 12, baseKnockback: 410, knockbackGrowth: 10.5, startupMs: 200, activeMs: 140, cooldownMs: 700, range: 66, height: 60, angleDeg: 32, boxX: 12, boxY: -82 },
  // Mossa di recupero (#11): la spinta sta in RECOVERY, qui solo il colpetto che dà salendo
  recovery: {
    damage: 4,
    baseKnockback: 300,
    knockbackGrowth: 3,
    startupMs: 0,
    activeMs: 250,
    cooldownMs: 0, // dopo la mossa non si attacca comunque fino all'atterraggio
    range: 40,
    height: 70,
    angleDeg: 80, // quasi in verticale: chi sta sopra il bordo viene spinto via in alto
    boxX: -20, // centrata sul personaggio
    boxY: -100, // dalla testa in su: colpisce chi sta sopra mentre si sale
  },
  // Risalita con attacco dal bordo (#110): si sale durante l'avvio e si colpisce davanti, in basso
  ledgeAttack: { damage: 7, baseKnockback: 330, knockbackGrowth: 4, startupMs: 300, activeMs: 100, cooldownMs: 600, range: 60, height: 40, angleDeg: 30, boxY: -44 },
  // Presa (#109, E8 passo 2): scudo + leggero. Non fa danno: chi entra nel rettangolo viene tenuto (physics/grab.ts)
  grab: { damage: 0, baseKnockback: 0, knockbackGrowth: 0, startupMs: 100, activeMs: 33, cooldownMs: 633, range: 40, height: 40, angleDeg: 0, boxY: -60 },
  // Lanci dalla presa, nella direzione tenuta. angleDeg oltre 90 = all'indietro. La hitbox non conta:
  // il lancio parte subito su chi è tenuto, il rettangolo serve solo a disegnare la mossa
  throwForward: { damage: 8, baseKnockback: 380, knockbackGrowth: 9, startupMs: 0, activeMs: 150, cooldownMs: 300, range: 40, height: 40, angleDeg: 40, boxY: -60 },
  throwBack: { damage: 10, baseKnockback: 400, knockbackGrowth: 10, startupMs: 0, activeMs: 150, cooldownMs: 300, range: 40, height: 40, angleDeg: 135, boxY: -60 }, // il lancio da KO
  throwUp: { damage: 7, baseKnockback: 360, knockbackGrowth: 9.5, startupMs: 0, activeMs: 150, cooldownMs: 300, range: 40, height: 40, angleDeg: 88, boxY: -60 },
  throwDown: { damage: 6, baseKnockback: 300, knockbackGrowth: 6, startupMs: 0, activeMs: 150, cooldownMs: 300, range: 40, height: 40, angleDeg: 70, boxY: -60 }, // apre le combo
};

// Presa (#109, E8 passo 2): quanto si tiene, come ci si libera, i colpetti
export const GRAB = {
  whiffLagMs: 500, // ms fermi dopo una presa andata a vuoto (oltre ad avvio e finestra attiva)
  holdBaseMs: 1000, // ms per cui si tiene un bersaglio a 0%...
  holdPerPercentMs: 8, // ...più tanti ms per punto di percentuale
  mashMs: 60, // ogni tasto nuovo premuto da chi è tenuto toglie questi ms alla tenuta
  pummelDamage: 1.5, // percentuale di un colpetto (leggero durante la presa)
  pummelEveryMs: 300, // ms minimi tra due colpetti
  releaseSpeed: 300, // pixel/s con cui ci si allontana quando la presa finisce senza lancio
  holdDistance: 56, // pixel tra il centro di chi tiene e quello di chi è tenuto: un po' di spazio per il braccio
};

// Mosse speciali di chi non ne ha di sue (E10, #111): i numeri della specifica, da playtest (#22).
// I personaggi le cambiano in characters.ts (specials); il tasto e il motore arrivano nei passi 2 e 3
export const DEFAULT_SPECIALS: SpecialSet = {
  neutral: { type: "projectile", name: "Tiro", startupMs: 216, cooldownMs: 550, speed: 700, gravity: 0, lifeMs: 1200, maxAlive: 1, range: 24, height: 16, damage: 6, baseKnockback: 220, knockbackGrowth: 3.5, angleDeg: 30, color: 0xffd84a },
  side: { type: "dash", name: "Scatto", startupMs: 100, durationMs: 250, speed: 900, endLagMs: 300, range: 40, height: 50, damage: 9, baseKnockback: 360, knockbackGrowth: 8, angleDeg: 35 },
  down: { type: "counter", name: "Contrattacco", startupMs: 50, windowMs: 400, endLagMs: 450, minDamage: 8, multiplier: 1.3, range: 60, height: 60, baseKnockback: 450, knockbackGrowth: 9, angleDeg: 40 },
};

// Motore delle speciali (E10): i numeri comuni a tutti i personaggi
export const SPECIAL_MOVES = {
  airBrakeHalfLifeMs: 60, // dopo lo scatto in aria la velocità si dimezza ogni tot ms (a terra ci si ferma subito)
  projectileY: 52, // pixel sopra i piedi da cui parte il proiettile, all'altezza delle mani
};

// La carica di esempio della specifica E10 (10% · 400 + 10/% · 42°, fino a 1.8 = 18%): la useranno i
// personaggi del passo 5 (es. Egiainuso, giù) e i test
export const CHARGE_EXAMPLE: ChargeSpecial = { type: "charge", name: "Carica", minMs: 200, maxMs: 1200, maxMultiplier: 1.8, activeMs: 100, endLagMs: 350, range: 50, height: 50, damage: 10, baseKnockback: 400, knockbackGrowth: 10, angleDeg: 42 };

// Mossa di recupero (#11): in aria K + su dà una spinta verso l'alto, una volta finché
// non si tocca terra o si viene colpiti. Un salto da terra sale di circa 160 pixel, questa di circa 240.
export const RECOVERY = {
  speed: 1050, // velocità verso l'alto, pixel/s
  drift: 300, // velocità orizzontale verso la direzione tenuta, pixel/s
};

// Statistiche dei personaggi (E11, #13): moltiplicatori dei numeri di FIGHTER in characters.ts.
// Il limite tiene i personaggi diversi ma senza che uno rompa le arene o il bilanciamento.
export const CHARACTER_STATS = {
  min: 0.8,
  max: 1.2,
};

// Schivata (#3): con L si è invulnerabili per un attimo e ci si sposta di poco nella direzione tenuta.
// 260 ms a 520 pixel/s = circa 135 pixel, poco più di tre volte la larghezza del lottatore.
export const DODGE = {
  durationMs: 260, // invulnerabilità e spostamento
  speed: 520, // pixel/s nella direzione tenuta (fermi se nessuna)
  cooldownMs: 900, // dall'inizio della schivata alla successiva
};

// Scudo (#109, E8 passo 1): si tiene con I a terra. Assorbe il danno dei colpi al posto della percentuale,
// si consuma da solo e si ricarica abbassato; a 0 si rompe e si resta storditi. Valori della specifica, da playtest (#22).
export const SHIELD = {
  maxHp: 50, // punti di scudo pieno
  drainPerSec: 9, // punti persi al secondo tenendolo alzato: pieno si rompe da solo in ~5,5 s
  regenPerSec: 6, // punti recuperati al secondo da abbassato
  raiseMs: 33, // ms tra la pressione e lo scudo che para (2 frame)
  dropMs: 116, // ms fermi dopo averlo abbassato (7 frame)
  stunBaseMs: 33, // ms fermi sullo scudo dopo un colpo parato...
  stunPerDamageMs: 13, // ...più tanti ms per punto di danno (leggero ~100 ms, pesante ~200 ms)
  pushBase: 150, // pixel/s di scivolata all'indietro per un colpo parato...
  pushPerDamage: 25, // ...più tanti pixel/s per punto di danno
  pushFriction: 2000, // pixel/s²: quanto in fretta si ferma la scivolata
  breakStunMs: 2500, // ms storditi e colpibili dopo la rottura
  breakPopSpeed: 900, // pixel/s del saltino in alto quando si rompe
  hpAfterBreak: 30, // punti di scudo con cui si riparte dopo la rottura
};

// Bordo del palco (#110): in aria, scendendo, ci si aggrappa agli spigoli in alto dei blocchi pieni.
// L'invulnerabilità vale solo per la prima presa dopo aver toccato terra o essere stati colpiti.
export const LEDGE = {
  grabBoxX: 36, // distanza massima in orizzontale tra la mano e lo spigolo, pixel
  grabBoxY: 48, // distanza massima in verticale tra la mano e lo spigolo, pixel
  hangOffsetY: 56, // da appesi i piedi stanno tanti pixel sotto lo spigolo (la mano è lì)
  invulnMs: 800, // invulnerabilità della prima presa
  maxGrabs: 3, // prese senza toccare terra: alla successiva non ci si aggrappa più
  regrabMs: 300, // dopo essersi staccati non ci si riaggrappa per questo tempo
  maxHangMs: 5000, // dopo tanto tempo appesi si cade
  actionableMs: 66, // da appesi i tasti contano solo dopo questo tempo (4 frame)
  climbMs: 400, // risalita normale, tenendo verso il palco
  climbInvulnMs: 300,
  jumpInvulnMs: 100, // salto dal bordo
  rollMs: 500, // rotolata sul palco, con la schivata
  rollDistance: 150, // pixel oltre il bordo dove finisce la rotolata
  rollInvulnMs: 400,
};

export const HITSTUN_PER_KNOCKBACK = 0.35; // ms di stordimento per ogni pixel/s di knockback
export const HITSTUN_AIR_DRAG = 0.985; // rallentamento per tick mentre si vola via

// Hitstop (#15): quando un colpo entra attaccante e bersaglio si fermano per un istante,
// più a lungo se il colpo è forte. Il bersaglio parte in volo solo dopo.
export const HITSTOP = {
  baseMs: 30, // anche il colpo più debole si sente
  perDamageMs: 6, // ms in più per ogni punto di danno: leggero (5) = 60 ms, pesante (13) = 108 ms
  maxMs: 200,
};

export const STOCKS = 3; // vite per partita
export const RESPAWN_MS = 1500; // attesa dopo aver perso una vita
export const RESPAWN_INVULNERABLE_MS = 1500;
export const MATCH_RESTART_MS = 5000; // pausa dopo la vittoria prima della nuova partita

export const COLORS = [0xe74c3c, 0x3498db, 0x2ecc71, 0xf1c40f, 0x9b59b6, 0xe67e22, 0x1abc9c, 0xff6fb5];

// Generatore di arene casuali (stageGenerator.ts). Le altezze tengono conto del salto:
// un salto da terra sale di circa 160 pixel, con il doppio salto quasi 300.
export const STAGE_GEN = {
  groundY: [520, 600], // altezza della superficie principale, pixel
  groundThickness: [60, 100],
  singleWidth: [560, 880], // larghezza del palco unico
  islandWidth: [260, 380], // larghezza di ogni isola
  islandGap: [120, 220], // vuoto tra le isole: ci si cade dentro
  islandsChance: 0.4, // probabilità di avere due isole invece di un palco unico
  platformWidth: [160, 240],
  tierStep: [115, 150], // distanza in altezza tra un piano e quello sotto
  secondTierChance: 0.6,
};

// Percorsi della modalità Corsa (#57, courseGenerator.ts). Distanze in pixel.
// Un salto da fermo copre circa 250 pixel in orizzontale e sale di 160: i valori restano sotto.
export const COURSE = {
  length: 6000, // dalla partenza al traguardo, circa cinque schermi
  startWidth: 640, // blocco di partenza, ci stanno tutti e otto
  goalWidth: 480, // blocco del traguardo
  gap: [80, 220], // vuoto tra un appoggio e il successivo
  rise: 120, // quanto più in alto può stare l'appoggio successivo
  y: [280, 560], // altezze possibili della superficie (più in basso le coprirebbe l'HUD)
  solidWidth: [220, 560], // blocchi pieni
  platformWidth: [140, 220], // piattaforme sottili sospese sul vuoto
  platformChance: 0.4, // probabilità che il prossimo appoggio sia sottile
  checkpointEvery: 1100, // distanza minima tra due checkpoint
  respawnHeight: 120, // si ricompare un po' sopra il checkpoint
};

// Squadre (#17): una tonalità per ogni compagno (fino a 4 contro 4), così i compagni si distinguono tra loro
export const TEAM_COLORS: Record<1 | 2, number[]> = {
  1: [0xe74c3c, 0xff9a8a, 0xb03020, 0xff6f5e],
  2: [0x3498db, 0x8fd0ff, 0x1f5f9a, 0x5dade2],
};
// Bandiera (#56): chi porta la bandiera è più lento, così ha bisogno dei compagni
export const FLAG = {
  carrierSpeed: 0.85, // frazione della velocità normale, a terra e in aria
};

export const TEAM_NAMES: Record<1 | 2, string> = { 1: "Rossa", 2: "Blu" };

// Palette per daltonici (E14, opzioni → Accessibilità), dai colori di Okabe e Ito: il client Godot
// sostituisce COLORS[i] con COLORS_COLORBLIND[i] (e lo stesso per le squadre). Il server non cambia.
export const COLORS_COLORBLIND = [0xd55e00, 0x0072b2, 0x009e73, 0xf0e442, 0xcc79a7, 0xe69f00, 0x56b4e9, 0xffffff];
export const TEAM_COLORS_COLORBLIND: Record<1 | 2, number[]> = {
  1: [0xd55e00, 0xffd27a, 0x9e5a00, 0xe69f00], // arancioni: il primo è COLORS_COLORBLIND[0], come nell'originale
  2: [0x0072b2, 0x8ccff5, 0x003f63, 0x56b4e9], // blu
};

// Audio (#6): volumi di partenza, da 0 a 1. Ognuno poi li cambia nelle opzioni.
export const AUDIO = {
  master: 0.8,
  sfx: 0.7,
  music: 0.35,
  musicBpm: 132, // velocità della musica sintetizzata, battiti al minuto
  hitLoudPercent: 120, // da questa percentuale in su i colpi suonano al massimo
  voices: 0.8, // volume di partenza delle voci (E13): personaggi e annunciatore
  musicFadeMs: 1500, // dissolvenza tra la musica della lobby e quella della partita
  duckDb: -8, // di quanto scende la musica su un KO (E13), decibel
  duckMs: 1200, // in quanto tempo risale dopo il KO
  sameSoundMax: 3, // copie dello stesso suono che possono partire insieme...
  sameSoundWindowMs: 60, // ...entro questi ms: nelle mischie a 4 il resto si salta
  targetLufs: -16, // loudness integrata a cui devono stare i file (npm run audio:check)
  lufsTolerance: 2, // LU di scarto accettati
  maxPeakDb: -1, // picco massimo dei file, dBTP
  // Annunciatore (E13 passo 4): public/assets/announcer/<frase>.ogg. Più alta la priorità, prima parla;
  // da announcerInterrupt in su interrompe la frase in corso e svuota la coda
  announcerPriority: { go: 1, tenSeconds: 1, lastLife: 2, game: 3, draw: 3 } as Record<string, number>,
  announcerInterrupt: 3,
  announcerMaxWaitMs: 1500, // una frase rimasta in coda più di così non si dice più: sarebbe fuori tempo
  announcerTimeWarningMs: 10000, // "Dieci secondi!" quando il tempo rimasto scende sotto questa soglia, ms
};

// Rete lato client: si disegna il passato di qualche ms e si interpola tra due snapshot,
// così il movimento resta fluido anche se i pacchetti arrivano a scatti
export const NET = {
  interpolationDelayMs: 80, // circa due snapshot e mezzo a 30/s
  teleportDistance: 300, // pixel: oltre questo salto (es. respawn) non si interpola
  bufferSize: 30, // snapshot tenuti in memoria (1 secondo)
};

// Telecamera (#12): nelle arene inquadra tutti i lottatori vivi e zooma quando si allontanano.
// Non si allarga mai oltre le zone di espulsione dell'arena.
export const CAMERA = {
  margin: 140, // pixel di aria attorno al gruppo di lottatori
  minZoom: 0.7, // più piccolo = più lontano; 1 = l'arena intera come prima
  maxZoom: 1.3, // quanto si avvicina quando i lottatori sono vicini
  smoothingMs: 220, // più alto = movimenti più morbidi e più lenti
};

// Effetti del client (#15 passi 2 e 3): solo grafica, partono dagli eventi dello snapshot.
// Il knockback di un colpo va da ~260 px/s (leggero a 0%) a oltre 1500 (pesante sopra il 100%).
export const EFFECTS = {
  hitSparkMs: 220, // durata della scintilla di un colpo
  shakeKo: 14, // pixel di scossa a un KO
  shakeDecay: 400, // pixel/s di scossa che si spengono
  shakeFromKnockback: 450, // px/s: sotto questo knockback lo schermo non trema
  shakePerKnockback: 0.01, // pixel di scossa per ogni px/s di knockback oltre la soglia
  shakeMax: 12, // pixel: scossa massima per un colpo
  flashKnockback: 1100, // px/s: da qui in su il colpo fa anche un lampo bianco
  flashMs: 90,
  dustMs: 320, // durata della polvere quando si atterra o si salta da terra
  dustPuffs: 5, // sbuffi di polvere per atterraggio
  trailSpeed: 900, // px/s: chi vola più veloce di così lascia una scia
  trailLength: 6, // posizioni ricordate per la scia (una per frame)
  tumbleSpeed: 650, // px/s: in hitstun e in aria, chi vola più veloce di così si disegna con l'animazione tumble (#103)
  koBeamMs: 750, // durata del raggio colorato di un KO
  koBeamLength: 1400, // pixel: quanto entra nello schermo il raggio del KO
  koBeamWidth: 150, // pixel: larghezza del raggio dove finisce (all'uscita è una punta)
  percentShakeMs: 280, // durata del tremolio della percentuale dopo un colpo
  percentShakePerDamage: 0.6, // pixel di tremolio per ogni punto di danno preso
  percentShakeMax: 9, // pixel: tremolio massimo della percentuale
  shieldFlashMs: 120, // la bolla dello scudo si illumina per tanto dopo un colpo parato (#109)
  shieldBreakShake: 10, // pixel di scossa quando uno scudo si rompe
  shardMs: 550, // durata delle schegge della bolla rotta
  shards: 10, // schegge della bolla rotta
  stunStars: 3, // stelline che girano sopra chi è stordito
};

// Bot del server (#20, src/server/bot.ts): quanto è svelto e quando attacca
export const BOT = {
  jumpAtHeight: 90, // pixel: se il bersaglio sta più in alto di così, salta
  edgeMargin: 40, // pixel: a terra non si avvicina al bordo del palco più di così
  ledgeWaitMaxMs: 1500, // ms: il bot difficile resta appeso al bordo da 0 a tanto prima di risalire (#110)
  ledgeRollNear: 200, // pixel: il difficile preferisce la rotolata se il bersaglio è più vicino di così al bordo
  shieldHoldMs: 300, // ms: il difficile tiene lo scudo per tanto dopo aver visto partire un attacco vicino (#109)
  shieldMinHp: 15, // punti di scudo: sotto questi il difficile non si para più, così non se lo fa rompere
  grabShieldMs: 300, // ms: semplice e difficile afferrano chi tiene lo scudo da più di tanto (E8)
  shootFrom: 300, // pixel: più lontano di così il bot tira il proiettile della speciale (E10)
  dashFrom: 160, // pixel: tra dashFrom e shootFrom scatta verso il bersaglio
  specialEveryMs: 1200, // ms tra una speciale e l'altra del bot
  sparringEveryMs: 1800, // ms tra un attacco e l'altro dello sparring del tutorial (E15): il tempo di alzare lo scudo
  sparringRange: 140, // pixel: lo sparring attacca solo se sei così vicino
};

// Livelli di difficoltà dei bot (#20 passo 3): ?bot=facile, ?bot=semplice, ?bot=difficile
export const BOT_LEVELS = {
  facile: { reactionMs: 320, heavyEvery: 5, dodges: false, shields: false, grabs: false, specials: false, counters: false }, // reactionMs: ogni quanto rivede le scelte
  semplice: { reactionMs: 180, heavyEvery: 3, dodges: false, shields: false, grabs: true, specials: true, counters: false }, // heavyEvery: un pesante ogni tanti attacchi
  difficile: { reactionMs: 90, heavyEvery: 2, dodges: true, shields: true, grabs: true, specials: true, counters: true }, // dodges: schiva i pesanti; shields: si para dagli altri colpi; grabs: afferra chi si para; specials: tira e scatta (E10); counters: un pesante su due lo contrattacca
};

// Elementi dinamici delle arene (#14): ascensori e trappole. I loro numeri stanno nei dati dell'arena.
export const HAZARD = {
  cooldownMs: 700, // ms dopo una trappola in cui non se ne prende un'altra (niente colpi a raffica)
};

// Classifica delle partite (#18, src/server/leaderboard.ts)
export const LEADERBOARD = {
  windowDays: 7, // la pagina /classifica conta le partite degli ultimi 7 giorni
  maxMatches: 2000, // partite tenute nel file, le più vecchie si buttano
};

// Oggetti (#17): cadono dal cielo, si raccolgono con J o K e si lanciano con J o K
export const ITEM_RULES = {
  firstSpawnMs: 6000, // il primo oggetto cade dopo un po' dall'inizio
  spawnEveryMs: 11000, // poi uno ogni tanto
  maxOnStage: 2, // non di più nell'arena contemporaneamente
  dropHeight: 420, // pixel sopra la superficie da cui cade
  pickRange: 40, // pixel orizzontali tra il centro del lottatore e l'oggetto per raccoglierlo
  throwSpeed: 1100, // pixel/s del lancio in avanti
  throwLift: 220, // pixel/s verso l'alto nel lancio in avanti, per un arco
  throwUpSpeed: 1100, // pixel/s tenendo su
  groundFriction: 2400, // pixel/s² di frenata quando un oggetto struscia a terra
  lifeMs: 15000, // a terra senza che nessuno lo prenda sparisce dopo tanto
  knockbackGrowth: 6, // pixel/s di lancio in più per ogni punto di percentuale del bersaglio
  angleDeg: 38, // angolo di lancio di chi viene colpito
  holdOffsetX: 22, // pixel davanti al centro dove si tiene l'oggetto
  holdOffsetY: 52, // pixel sopra i piedi
};

// Limiti della rete (#105): il server non si fida di quello che riceve
export const NET_LIMITS = {
  maxMessageBytes: 16_384, // byte massimi di un messaggio Socket.IO (il predefinito è 1 MB)
  maxStringLength: 64, // caratteri tenuti di ogni stringa ricevuta (nome, stanza, arena...), prima dei tagli più stretti
  inputPerSecond: 120, // messaggi "input" al secondo concessi a un client (il client ne manda solo quando cambia un tasto)
  inputBurst: 30, // messaggi "input" che possono arrivare tutti insieme
  rematchPerSecond: 2, // richieste di rivincita al secondo
  trainingPerSecond: 10, // comandi dell'allenamento al secondo (#113): un cursore della percentuale ne manda tanti
  floodCloseMs: 10_000, // millisecondi di fila oltre il limite dopo cui il client viene chiuso
  maxConnectionsPerIp: 8, // connessioni aperte insieme dallo stesso IP (una stanza piena da una sola casa)
  maxRooms: 50, // stanze aperte in tutto sul server
  newRoomsPerIpPerMinute: 5, // stanze nuove che lo stesso IP può creare in un minuto
  maxNameLength: 16, // caratteri veri (emoji comprese) di un nome
};
export const ROOM_MAX_ERRORS = 3; // errori di fila nel passo di una stanza dopo cui la stanza si chiude
export const RECONNECT_HOLD_MS = 20_000; // millisecondi in cui il posto di chi perde la rete resta tenuto (#107)
export const RECONNECT_RESUME_INVULNERABLE_MS = 1500; // millisecondi di invulnerabilità al rientro dopo una caduta di rete
// Riconnessione nel client Godot (#107, esportati in game.json)
export const RECONNECT = {
  retryDelaysMs: [1000, 2000, 4000, 5000], // attese tra un tentativo e l'altro; dopo l'ultima si resta su quella
  snapshotSilenceMs: 3000, // in partita: senza snapshot per tanto la connessione è data per morta
};
export const PING_INTERVAL_MS = 5000; // ogni quanto il server manda un ping (Socket.IO, predefinito 25 s)
export const PING_TIMEOUT_MS = 5000; // senza risposta al ping per tanto il client è dato per perso (predefinito 20 s)
export const ROOM_IDLE_MS = 15 * 60_000; // millisecondi senza tasti umani dopo cui una stanza si chiude come se fosse vuota

// Comandi (E6, #108): levetta e avvisi per il client Godot (esportati in game.json), buffer per il server
export const INPUT = {
  stickDeadzone: 0.35, // da 0 a 1: sotto questa inclinazione la levetta (o il grilletto) non conta
  padToastMs: 2000, // millisecondi di "Pad collegato: <nome>" sullo schermo
  bufferMs: 100, // ms in cui un tasto appena premuto (attacchi, salto, schivata) vale ancora se l'azione non può partire subito
};

// Versione del protocollo (E2, #106): sale solo quando types.ts cambia in modo che client e server
// vecchi e nuovi non si capiscono più. La versione del gioco invece sta in package.json.
export const PROTOCOL_VERSION = 1;

// Vibrazione del pad (E6 passo 5): la sente chi colpisce, chi è colpito e chi va KO.
// Forze da 0 a 1; il client Godot le moltiplica per l'opzione "Vibrazione" (debole o forte)
export const RUMBLE = {
  hitMs: 120, // durata per un colpo, millisecondi
  hitMinStrength: 0.25, // forza del colpo più leggero
  hitMaxKnockback: 1400, // pixel/s: da questo knockback in su il colpo vibra al massimo
  attackerScale: 0.5, // chi colpisce sente questa parte della vibrazione di chi è colpito
  koMs: 450, // durata per il proprio KO
  koStrength: 1,
  weakScale: 0.5, // opzione "debole": tutte le forze per questo numero
};

// Prova di bilanciamento senza rete (E11 passo E, npm run balance): ogni personaggio contro gli altri, bot contro bot
export const BALANCE = {
  maxWinRate: 0.6, // sopra questa parte di vittorie un personaggio è troppo forte: npm run balance esce con errore
  generatedStages: 20, // arene casuali giocate oltre a quelle fisse, con semi 1, 2, 3...
  maxMatchSec: 300, // s simulati prima di dare la partita per pari
};

// Controllo delle arene (stageCheck.ts): usato dai test e dall'editor sul sito (E12)
export const STAGE_CHECK = {
  sideReach: 250, // pixel in orizzontale che si coprono comodamente durante un salto
};

// Allenamento (E15, #113): comandi della palestra, accettati solo con un umano nella stanza
export const TRAINING = {
  speeds: [1, 0.5, 0.25], // velocità dell'orologio ammesse: 1 normale, 0.5 e 0.25 rallentatore
  maxPercent: 999, // percentuale massima che si può dare al bot
};

// Budget di prestazioni (E3 passo 4, #83): npm run bench -- --check e bench_client.gd --check escono con errore
// se il migliore di 3 giri lo supera. Largo apposta: le macchine della CI vanno a velocità diverse.
export const PERF_BUDGET = {
  serverStepAvgMs: 0.5, // passo medio della fisica con 8 giocatori (oggi circa 0,03-0,05 ms)
  serverStepWorstMs: 20, // passo peggiore: compresi i picchi di JIT e garbage collector (oggi 2-6 ms)
  snapshotDeflatedBytes: 1200, // snapshot compresso medio con 8 giocatori (oggi circa 590 B)
  clientScriptUs: 6000, // script di world_view e hud per frame, in µs (oggi circa 2400; un frame a 60 fps ne ha 16667)
};
