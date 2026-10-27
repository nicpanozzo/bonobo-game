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
export const SEND_RATE = 60; // stati inviati ai client al secondo: uno per tick, il movimento degli altri arriva prima e più fluido
export const SNAPSHOT_CLOCK_RESYNC_MS = 100; // ms: oltre questo scarto dall'ora vera l'ora degli snapshot si riallinea (#320)
export const GAME_SPEED = 0.9; // velocità del combattimento rispetto all'orologio vero: 0.9 = un po' più lento, come Smash (sondaggio di #384, A4). L'arena e il tempo della partita restano veri
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
  dropHoldMs: 133, // ms (8 fotogrammi) di giù tenuto a terra, senza attaccare, prima di scendere da una sottile: giù + attacco resta sopra
  coyoteMs: 80, // ms dopo essere scesi dal bordo camminando in cui il salto vale ancora come salto da terra
  shortHopCut: 0.45, // lasciando il salto mentre si sale la velocità verso l'alto si moltiplica per questo: salto corto
  hitstunDriftAccel: 700, // pixel/s²: tenendo una direzione mentre si vola via si corregge un po' la traiettoria
  archSnapPx: 8, // pixel: camminando su una piattaforma ad arco (#244) si resta attaccati alla curva se il dislivello in un passo è entro questo
  slopeSnapStepPx: 20, // pixel orizzontali in un passo, scatto compreso: sulle rampe (#246) l'aggancio cresce di pendenza × questo
  // Ritmo di salti e atterraggi come Smash (#384 A3, valori di Riccardo)
  jumpSquatMs: 50, // ms (3 fotogrammi a 60 Hz) a terra prima di staccarsi; lasciando il salto prima della fine si fa il salto corto
  landingLagMs: 33, // ms (2 fotogrammi) fermi dopo un atterraggio normale; dopo un attacco in aria vale landingLagMs dell'attacco
};

// Scatto con doppio tocco (#199): numeri provvisori, da rivedere al playtest (#22).
// Lo scatto va avanti per circa speed * durationMs = 270 pixel, poi tenendo la direzione si corre
export const DASH = {
  doubleTapMs: 250, // ms entro cui il secondo tocco della stessa direzione fa scattare
  tapMaxMs: 120, // il primo tocco dev'essere breve: chi tiene la direzione più a lungo (camminando, i bot) non scatta
  speed: 900, // pixel/s durante lo scatto (la camminata è FIGHTER.groundSpeed, 380)
  durationMs: 300, // ms di scatto, anche lasciando il tasto
  runSpeed: 560, // pixel/s di corsa tenendo la direzione dopo lo scatto
  byTap: false, // il doppio tocco fa scattare: spento per ora, faceva scivolare senza volerlo (Nicola, 14 ottobre 2026)
  attackSlide: 640, // pixel/s in avanti durante l'attacco in corsa (ATTACKS.dashAttack), fino alla fine del colpo attivo
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
  outward?: boolean; // colpo ad area (#102): lancia lontano dal centro di chi colpisce, non dalla parte in cui guarda
  bothSides?: boolean; // la hitbox va anche dietro, specchiata: davanti e dietro arriva a boxX + range dal centro
  landingLagMs?: number; // ms fermi se si atterra mentre è in corso, partito in aria (#384 A3); senza, FIGHTER.landingLagMs
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
  lightUp: { damage: 6, baseKnockback: 280, knockbackGrowth: 5, startupMs: 60, activeMs: 110, cooldownMs: 320, range: 54, height: 48, angleDeg: 85, boxX: -27, boxY: -128, landingLagMs: 100 }, // sopra la testa; in aria 6 fotogrammi di pausa atterrando
  lightDown: { damage: 4, baseKnockback: 230, knockbackGrowth: 4.5, startupMs: 50, activeMs: 110, cooldownMs: 300, range: 60, height: 24, angleDeg: 18, boxX: 10, boxY: -24 }, // sgambetto basso
  lightAir: { damage: 6, baseKnockback: 260, knockbackGrowth: 5, startupMs: 50, activeMs: 160, cooldownMs: 320, range: 54, height: 50, angleDeg: 40, boxX: 8, boxY: -72, landingLagMs: 100 }, // 6 fotogrammi di pausa atterrando
  heavyUp: { damage: 14, baseKnockback: 430, knockbackGrowth: 11.5, startupMs: 280, activeMs: 130, cooldownMs: 800, range: 80, height: 64, angleDeg: 88, boxX: -40, boxY: -144, landingLagMs: 167 }, // lancia in verticale; in aria 10 fotogrammi di pausa atterrando
  heavyDown: { damage: 12, baseKnockback: 400, knockbackGrowth: 10, startupMs: 240, activeMs: 140, cooldownMs: 760, range: 88, height: 30, angleDeg: 25, boxX: 8, boxY: -30, bothSides: true, outward: true }, // spazzata radente dai due lati, come lo smash in giù di Smash
  heavyAir: { damage: 12, baseKnockback: 410, knockbackGrowth: 10.5, startupMs: 200, activeMs: 140, cooldownMs: 700, range: 66, height: 60, angleDeg: 32, boxX: 12, boxY: -82, landingLagMs: 200 }, // 12 fotogrammi di pausa atterrando
  // Attacco in corsa: il pesante tenendo la corsa (DASH.attackSlide), più veloce del pesante ma meno forte
  dashAttack: { damage: 10, baseKnockback: 400, knockbackGrowth: 9, startupMs: 100, activeMs: 160, cooldownMs: 620, range: 58, height: 44, angleDeg: 45 },
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
  // Suprema di base (#101), di tutti finché il personaggio non ha la sua (Bonobot: #102): un colpo largo
  // che prende davanti e un po' dietro, con un avvio lungo in cui si è invulnerabili (SUPREME.invulnerableMs)
  supreme: { damage: 20, baseKnockback: 620, knockbackGrowth: 12, startupMs: 350, activeMs: 200, cooldownMs: 1000, range: 190, height: 130, angleDeg: 45, boxX: -60, boxY: -130 },
};

// Colpi caricati alla Smash: il pesante a terra (anche su e giù) tenuto premuto si ferma all'inizio e si carica,
// al rilascio parte più forte. Come gli smash attack di Smash Ultimate (fino a 1.4 dopo un secondo)
export const SMASH_CHARGE = {
  maxMs: 1000, // ms di carica massima: arrivati qui il colpo parte da solo
  maxMultiplier: 1.4, // danno e knockback a carica piena (cresce in modo lineare da 1)
  kinds: ["heavy", "heavyUp", "heavyDown"] as AttackKind[], // gli attacchi che si caricano, solo da terra
};

// Combo di leggeri (jab di Smash): a terra il leggero premuto di nuovo subito dopo il primo continua la combo,
// anche durante l'attesa del colpo. Il secondo tiene vicino, il terzo è il finale che lancia
export const JAB = {
  windowMs: 220, // ms dopo la fine di un colpo della combo in cui il leggero premuto fa il colpo dopo
  steps: [
    { damage: 3, baseKnockback: 150, knockbackGrowth: 1, startupMs: 40, activeMs: 90, cooldownMs: 280, range: 54, height: 30, angleDeg: 20 }, // il secondo: tiene vicino
    { damage: 6, baseKnockback: 380, knockbackGrowth: 6.5, startupMs: 70, activeMs: 110, cooldownMs: 420, range: 64, height: 40, angleDeg: 38 }, // il finale: lancia
  ] as AttackSpec[],
};

// Rialzata al volo (tech di Smash e Brawlhalla): lanciati da un colpo, premere scudo poco prima di toccare terra
// fa rialzare subito, fermi o rotolando nella direzione tenuta, invece di restare storditi a terra
export const TECH = {
  windowMs: 330, // ms prima di toccare terra in cui lo scudo premuto vale (20 fotogrammi, come Smash)
  lockoutMs: 670, // ms dopo una pressione in cui un'altra non vale: premere a caso non basta
  rollSpeed: 520, // pixel/s della rotolata con una direzione tenuta
  rollMs: 300, // ms di rotolata (o di rialzata sul posto)
  invulnerableMs: 330, // ms intoccabili dopo la rialzata
};

// Barra della suprema (#101): da 0 a max. Valori provvisori pensati per arrivare piena circa una volta per vita
// (come la Final Smash con la barra in Smash Ultimate): in una vita si danno e si prendono circa 100 punti di percentuale
// in circa un minuto, cioè 100 * 0.5 + 100 * 0.3 + 60 * 0.3 = 98. Da rivedere al playtest (#22)
export const SUPREME = {
  max: 100,
  perDamageDealt: 0.5, // carica per ogni punto di percentuale dato
  perDamageTaken: 0.3, // carica per ogni punto di percentuale preso: chi è in svantaggio recupera, ma meno di chi colpisce
  perSecond: 0.3, // carica al secondo stando in gioco: da sola riempie la barra in 5 minuti e mezzo
  keepOnKo: true, // la barra resta quando si perde una vita (proposta in #101, da confermare)
  invulnerableMs: 350, // ms invulnerabili dall'inizio della suprema: nessuno la interrompe durante l'avvio
  comboMs: 50, // Speciale + Pesante insieme fanno la suprema: ms entro cui la mossa partita col primo tasto si annulla
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
// personaggi del passo 5 (es. Capt. OrsoBlu, giù) e i test
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

// Colpi normali propri di un personaggio (#384 D2): tempi (avvio, attivo, recupero) e zona (range, height)
// restano entro questa frazione da quelli di ATTACKS, così nessuno diventa un'altra cosa
export const ATTACK_TWEAK = {
  maxChange: 0.3, // ±30%
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
// Come Smash Ultimate (100 ms + 11 ms per punto, massimo 500), perché i colpi pesino (#384 A2, valori di Riccardo)
export const HITSTOP = {
  baseMs: 100, // ms: anche il colpo più debole si sente
  perDamageMs: 11, // ms in più per ogni punto di danno: leggero (5) = 155 ms, pesante (13) = 243 ms
  maxMs: 500, // ms
};

export const STOCKS = 3; // vite per partita
export const RESPAWN_MS = 1500; // attesa dopo aver perso una vita
export const RESPAWN_INVULNERABLE_MS = 1500;
export const PHASE_LIFT_GAP_PX = 70; // px tra chi viene riportato su da una fase che stringe la zona di espulsione (Bologna, zuffa)
export const PHASE_LIFT_MARGIN_PX = 150; // px sopra il nuovo fondo: chi sta già cadendo lì quando la fase lo stringe viene riportato su anche lui
export const MATCH_RESTART_MS = 5000; // pausa dopo la vittoria prima della nuova partita
// Pre-partita: nella stanza si aspetta che tutti dicano "Pronto", poi presentazione e 3, 2, 1, VIA!
export const PREMATCH = {
  introMs: 2500, // ms di presentazione dei lottatori prima del conto alla rovescia, solo alla prima partita
  countdownMs: 3000, // ms del 3, 2, 1: lottatori fermi al loro posto; anche prima di ogni rivincita
  autoStartMs: 60_000, // ms di attesa con almeno due lottatori dopo cui si parte anche senza tutti pronti (client vecchi)
  minFighters: 2, // da soli si gira per l'arena: la partita comincia con almeno tanti lottatori
};

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

// Squadre (#17): una tonalità per ogni compagno (fino a 4 contro 4), così i compagni si distinguono tra loro.
// Fino a MAX_TEAMS squadre (#409); il primo colore di ognuna è quello di COLORS con lo stesso indice
export const MAX_TEAMS = 4; // squadre al massimo in modalità Squadre; in Bandiera sono sempre 2
export const TEAM_COLORS: Record<number, number[]> = {
  1: [0xe74c3c, 0xff9a8a, 0xb03020, 0xff6f5e],
  2: [0x3498db, 0x8fd0ff, 0x1f5f9a, 0x5dade2],
  3: [0x2ecc71, 0xa3f0c0, 0x1e8449, 0x58d68d],
  4: [0xf1c40f, 0xfff08a, 0xb7950b, 0xf7dc6f],
};
// Bandiera (#56): chi porta la bandiera è più lento, così ha bisogno dei compagni
export const FLAG = {
  carrierSpeed: 0.85, // frazione della velocità normale, a terra e in aria
};

export const TEAM_NAMES: Record<number, string> = { 1: "Rossa", 2: "Blu", 3: "Verde", 4: "Gialla" };

// Palette per daltonici (E14, opzioni → Accessibilità), dai colori di Okabe e Ito: il client Godot
// sostituisce COLORS[i] con COLORS_COLORBLIND[i] (e lo stesso per le squadre). Il server non cambia.
export const COLORS_COLORBLIND = [0xd55e00, 0x0072b2, 0x009e73, 0xf0e442, 0xcc79a7, 0xe69f00, 0x56b4e9, 0xffffff];
export const TEAM_COLORS_COLORBLIND: Record<number, number[]> = {
  1: [0xd55e00, 0xffd27a, 0x9e5a00, 0xe69f00], // arancioni: il primo è COLORS_COLORBLIND[0], come nell'originale
  2: [0x0072b2, 0x8ccff5, 0x003f63, 0x56b4e9], // blu
  3: [0x009e73, 0x7fe0c4, 0x005a40, 0x3fc79f], // verdi acqua: il primo è COLORS_COLORBLIND[2]
  4: [0xf0e442, 0xfff6a8, 0xa89c1a, 0xd9cc2a], // gialli: il primo è COLORS_COLORBLIND[3]
};

// Audio (#6): volumi di partenza, da 0 a 1. Ognuno poi li cambia nelle opzioni.
export const AUDIO = {
  master: 0.8,
  sfx: 0.7,
  music: 0.35,
  musicBpm: 132, // velocità della musica sintetizzata, battiti al minuto
  musicBpmMin: 70, // limiti alla velocità della musica di un'arena (E12, StageSpec.music)
  musicBpmMax: 190,
  hitLoudPercent: 120, // da questa percentuale in su i colpi suonano al massimo
  // Il pubblico (sfx/crowdOoh_*, crowdCheer_*): "ooh" sui colpi enormi, urla sui KO e sulla vittoria
  crowdHitDamage: 15, // danno di un colpo da cui il pubblico fa "ooh", punti percentuale
  crowdHitKnockback: 1500, // o spinta da cui fa "ooh", pixel/s
  crowdCooldownMs: 1200, // tra una reazione e l'altra del pubblico, ms (un KO o la vittoria passano sopra)
  voices: 0.8, // volume di partenza delle voci (E13): personaggi e annunciatore
  tauntVoiceCooldownMs: 1500, // attesa minima tra due voci di provocazione dello stesso giocatore (E13 passo 3)
  musicFadeMs: 1500, // dissolvenza tra la musica della lobby e quella della partita
  duckDb: -8, // di quanto scende la musica su un KO (E13), decibel
  duckMs: 1200, // in quanto tempo risale dopo il KO
  sameSoundMax: 3, // copie dello stesso suono che possono partire insieme...
  sameSoundWindowMs: 60, // ...entro questi ms: nelle mischie a 4 il resto si salta
  targetLufs: -16, // loudness integrata a cui devono stare i file (npm run audio:check)
  lufsTolerance: 2, // LU di scarto accettati
  maxPeakDb: -1, // picco massimo dei file, dBTP
  // Sotto questa durata la loudness integrata non si misura (EBU R128 vuole almeno un blocco da 0,4 s, sotto dà -70 LUFS):
  // per i suoni corti (colpi, clic) audio:check guarda solo il picco, che deve stare tra shortMinPeakDb e maxPeakDb
  minLoudnessSeconds: 0.5, // secondi (0,4 è la finestra minima: con un margine i file al confine non danno -70)
  shortMinPeakDb: -12, // picco minimo di un suono corto, dBFS: più basso vuol dire file quasi muto
  // Annunciatore (E13 passo 4): public/assets/announcer/<frase>.ogg. Più alta la priorità, prima parla;
  // da announcerInterrupt in su interrompe la frase in corso e svuota la coda
  announcerPriority: { intro: 1, go: 3, three: 3, two: 3, one: 3, tenSeconds: 1, lastLife: 2, game: 3, draw: 3 } as Record<string, number>, // pre-partita: 3, 2, 1 e VIA si tagliano a vicenda, mai in coda
  announcerInterrupt: 3,
  announcerMaxWaitMs: 1500, // una frase rimasta in coda più di così non si dice più: sarebbe fuori tempo
  announcerTimeWarningMs: 10000, // "Dieci secondi!" quando il tempo rimasto scende sotto questa soglia, ms
};

// Rete lato client: si disegna il passato di qualche ms e si interpola tra due snapshot,
// così il movimento resta fluido anche se i pacchetti arrivano a scatti
export const NET = {
  interpolationDelayMs: 50, // tre snapshot a 60/s: margine per un pacchetto in ritardo, 30 ms meno di prima
  teleportDistance: 300, // pixel: oltre questo salto (es. respawn) non si interpola
  bufferSize: 30, // snapshot tenuti in memoria (1 secondo)
  predictionSmoothMs: 100, // E17: una correzione della predizione si spalma su circa tanto (costante di tempo)
  predictionMaxReplayMs: 500, // E17: oltre questo ritardo dall'ultimo snapshot non si predice, si mostra il server
  ownExtrapolateMaxMs: 50, // E17: il proprio lottatore segue l'ultimo snapshot, spinto avanti con la sua velocità al massimo di tanto
};

// Telecamera (#12): nelle arene inquadra tutti i lottatori vivi e zooma quando si allontanano.
// Non si allarga mai oltre le zone di espulsione dell'arena.
export const CAMERA = {
  margin: 140, // pixel di aria attorno al gruppo di lottatori
  minZoom: 0.7, // più piccolo = più lontano; 1 = l'arena intera come prima
  maxZoom: 1.3, // quanto si avvicina quando i lottatori sono vicini
  smoothingMs: 220, // più alto = movimenti più morbidi e più lenti
  phaseBlendMs: 1000, // ms per portare zoom e pavimento della telecamera ai valori di una nuova fase (#433): niente salti
  stageMinZoomFloor: 0.45, // lo zoom più lontano che un'arena può chiedere con camera.minZoom (#240): oltre, i lottatori diventano troppo piccoli
};

// Effetti del client (#15 passi 2 e 3): solo grafica, partono dagli eventi dello snapshot.
// Il knockback di un colpo va da ~260 px/s (leggero a 0%) a oltre 1500 (pesante sopra il 100%).
export const EFFECTS = {
  phaseBannerMs: 2500, // durata del nome grande a schermo quando comincia una fase dell'arena (#433)
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
  // Reazione procedurale al colpo (#305), solo nel client: lo sprite si piega dove è colpito
  hitReactMs: 420, // durata della reazione, poi lo sprite torna dritto
  hitReactHz: 5, // oscillazioni al secondo della molla che riporta dritti
  hitReactFullKnockback: 1200, // px/s: da qui in su la reazione è piena
  hitReactMinStrength: 0.25, // frazione della reazione piena anche per il colpo più debole
  hitReactTilt: 0.35, // radianti: inclinazione massima (testa all'indietro o gambe portate via)
  hitReactSquash: 0.22, // frazione: schiacciamento massimo per un colpo alla pancia
  hitReactRecoil: 10, // pixel: rinculo massimo lontano da chi colpisce
  hitShakePx: 10, // pixel: quanto trema chi è colpito durante il fermo (HITSTOP), come in Smash
  hitFlash: 0.8, // da 0 a 1: quanto diventa bianco chi è colpito all'inizio del fermo, poi si spegne (#384)
  koZoomKnockback: 1100, // px/s: da qui in su il colpo fa anche un breve zoom della telecamera sul punto d'impatto
  koZoom: 0.08, // frazione: quanto si avvicina la telecamera al massimo dello zoom
  koZoomMs: 320, // durata dello zoom, andata e ritorno
  // Effetti dei colpi guidati dalla fisica (#384 B2), solo nel client
  strikeWidth: 14, // pixel: spessore della scia del colpo leggero (il pesante una volta e mezza)
  sparkPerKnockback: 0.02, // pixel di scintilla in più per ogni px/s di knockback del colpo
  // Squash & stretch del movimento (godot/scripts/motion_feel.gd), solo nel client
  jumpStretch: 0.14, // frazione: quanto si allunga chi salta
  landSquash: 0.16, // frazione: quanto si schiaccia chi atterra
  bounceMs: 220, // durata del rimbalzo, poi lo sprite torna dritto
  bounceHz: 4, // oscillazioni al secondo del rimbalzo
  runLean: 0.12, // radianti: quanto si piega in avanti chi corre alla velocità piena
  speedLinesSpeed: 1000, // px/s: chi è lanciato più veloce di così ha le linee di velocità dietro
  speedLines: 5, // linee di velocità
  speedLinesLength: 70, // pixel: lunghezza massima di una linea di velocità
  hitShakeHz: 30, // tremolii al secondo nel fermo
  impactLines: 8, // linee a raggiera attorno ai colpi forti
  impactLinesKnockback: 700, // px/s: da qui in su il colpo ha le linee a raggiera
  // Effetti a particelle (#470 passo 1, godot/scripts/particle_fx.gd e particle_view.gd), solo nel client
  particleMax: 600, // particelle vive al massimo: oltre, spariscono i gruppi più vecchi (prestazioni con 4 giocatori)
  heavyLandSpeed: 1100, // px/s di caduta: da qui in su l'atterraggio solleva la polvere pesante (caduta veloce o lancio)
  heavyLandPower: 2.2, // quanto è più grande la polvere dell'atterraggio pesante (1 = normale)
  smokeEveryMs: 22, // ogni quanti ms chi vola via forte lascia uno sbuffo di fumo
  brakeSpeed: 140, // px/s: sopra questa velocità a terra, rallentando forte si lascia la scia di frenata
  brakeDecel: 1500, // px/s²: da questo rallentamento in su è una frenata
  brakeEveryMs: 30, // ogni quanti ms nasce uno sbuffetto della frenata
  styleStepMs: 130, // di corsa, ogni quanti ms Marcomunista, Egiainuso e OrsoBlu lasciano un pizzico del loro stile (fighter_fx.gd)
  turnSpeed: 120, // px/s: girandosi a terra più veloci di così si alza uno sbuffo
  airRingMs: 380, // durata dell'anello d'aria del salto in aria
  impactStarMs: 240, // durata della stella d'impatto
  impactStarKoMs: 380, // durata della stella d'impatto di un colpo da KO
  // Esplosione del KO a colonna e nuvoletta della rinascita (#470 passo 2a)
  koColumnInset: 30, // pixel: la colonna del KO parte così dentro il bordo dell'inquadratura
  cloudDescentMs: 900, // la nuvoletta scende dall'alto per tanto e arriva al punto di ritorno quando si ricompare
  // Rallentatore solo grafico (#470 passo 2b, godot/scripts/time_warp.gd): il disegno resta indietro, il server no
  finishSlowFactor: 0.12, // velocità della scena nel colpo che chiude la partita (1 = normale)
  finishSlowMs: 750, // ms reali del colpo decisivo al rallentatore, in negativo e con lo zoom sul colpo
  finishFollowFactor: 0.3, // velocità della scena mentre la telecamera segue chi vola via
  finishFollowMs: 1200, // ms reali in cui si segue chi vola via; se non esce, la scena si rimette in pari
  finishZoom: 0.45, // frazione: quanto stringe la telecamera sul colpo decisivo
  finishMinKnockback: 500, // px/s: sotto, un colpo non si considera nemmeno per il colpo decisivo (decide la previsione del volo)
  finishExtraMs: 0, // ms di slancio dopo lo stordimento che la previsione guarda ancora: 0, chi esce dallo stordimento sul bordo di solito si salva
  gameSlowFactor: 0.25, // velocità della scena sull'ultimo KO
  gameSlowMs: 1400, // ms reali dell'ultimo KO al rallentatore
  gameZoom: 0.35, // frazione: quanto stringe la telecamera dove esce l'ultimo KO
  gameTextMs: 2000, // durata della scritta GAME!
  warpCatchUp: 1.6, // velocità con cui la scena si rimette in pari dopo il rallentatore
  warpMaxDelayMs: 2400, // ms: il disegno non resta indietro più di così
  warpBufferFrames: 200, // snapshot tenuti in memoria (a 60 al secondo, più di warpMaxDelayMs)
  // Leggibilità (#470 passo 3), solo nel client
  fastFallGlintMs: 300, // durata del brillio a stella quando comincia la caduta veloce
  crashPower: 1.3, // grandezza dello sbuffo di uno schianto a terra da storditi (1 = polvere normale)
  crashStarsMs: 1300, // per tanto girano le stelline sopra la testa dopo uno schianto
  steamFromPercent: 60, // da questa percentuale in su sale il vapore
  steamFullPercent: 150, // percentuale a cui il vapore è al massimo
  itemSparkleMs: 500, // stelline dove compare un oggetto
  itemPickMs: 450, // stelline che si stringono su chi raccoglie un oggetto
  // Fase 4, il sapore (#470): esplosioni e fuoco nelle arene
  cannonRecoilPx: 14, // quanto torna indietro la canna della bombarda quando spara, px
  cannonRecoilMs: 450, // quanto ci mette a tornare al suo posto, ms
  ballTrailEveryMs: 30, // uno sbuffo di fumo dietro la palla di mortadella ogni tanti ms
  boomGlowMs: 450, // bagliore arancio dell'esplosione della mortadella, ms
  burnTrailMs: 800, // per quanto chi è preso dal fuoco lascia la scia di fuliggine, ms
  burnEveryMs: 30, // uno sbuffo di fuliggine ogni tanti ms
  // KO stella e KO sullo schermo (#470 fase 4), solo per chi esce dall'alto e mai all'ultimo KO, come in Smash
  koStarChance: 0.3, // probabilità del KO stella (0-1)
  koScreenChance: 0.1, // probabilità del KO sullo schermo (0-1), mai con la modalità calma
  koStarDelayMs: 150, // dopo il KO, prima che lo si veda piccolo nello sfondo, ms
  koStarTravelMs: 900, // quanto vola nello sfondo rimpicciolendo, ms
  koStarTwinkleMs: 520, // la stellina finale, ms
  koScreenDelayMs: 300, // dopo il KO, prima che torni verso lo schermo, ms
  koScreenApproachMs: 220, // quanto ci mette ad arrivare enorme contro il vetro, ms
  koScreenStickMs: 650, // quanto resta spiaccicato, ms
  koScreenSlideMs: 900, // quanto ci mette a scivolare giù, ms
};

// Bot del server (#20, src/server/bot.ts): quanto è svelto e quando attacca
export const BOT = {
  jumpAtHeight: 90, // pixel: se il bersaglio sta più in alto di così, salta
  edgeMargin: 40, // pixel: a terra non si avvicina al bordo del palco più di così
  ledgeWaitMaxMs: 1500, // ms: il bot difficile resta appeso al bordo da 0 a tanto prima di risalire (#110)
  ledgeRollNear: 200, // pixel: il difficile preferisce la rotolata se il bersaglio è più vicino di così al bordo
  shieldHoldMs: 300, // ms: il difficile tiene lo scudo per tanto dopo aver visto partire un attacco vicino (#109)
  shieldMinHp: 15, // punti di scudo: sotto questi il difficile non si para più, così non se lo fa rompere
  grabShieldMs: 150, // ms: semplice e difficile afferrano chi tiene lo scudo da più di tanto (E8). Meno di shieldHoldMs, sennò due difficili si parano e colpiscono a vuoto per sempre (#427)
  shootFrom: 300, // pixel: più lontano di così il bot tira il proiettile della speciale (E10)
  dashFrom: 160, // pixel: tra dashFrom e shootFrom scatta verso il bersaglio
  specialEveryMs: 1200, // ms tra una speciale e l'altra del bot
  sparringEveryMs: 1800, // ms tra un attacco e l'altro dello sparring del tutorial (E15): il tempo di alzare lo scudo
  sparringRange: 140, // pixel: lo sparring attacca solo se sei così vicino
  climbReachPx: 150, // pixel: il bombardiere sale solo su pezzi più alti di così al massimo (un salto ne fa ~160): con di più oscilla
  climbFromPx: 180, // pixel: un bersaglio più in alto di così, sulle torri, si raggiunge arrampicandosi
  climbJumpPx: 70, // pixel: si salta già a questa distanza di lato dal pezzo: tra una scelta e l'altra il bot ne fa ~70 e il bersaglio stretto lo si salterebbe
  climbSidePx: 260, // pixel: e solo se sono così vicini di lato
  gunnerSweepMs: 1500, // ms: il bombardiere alza la canna per questo tempo, poi la abbassa per altrettanto (#433)
};

// Livelli di difficoltà dei bot (#20 passo 3): ?bot=facile, ?bot=semplice, ?bot=difficile
export const BOT_LEVELS = {
  facile: { reactionMs: 320, heavyEvery: 5, dodges: false, shields: false, grabs: false, specials: false, counters: false, supremes: false }, // reactionMs: ogni quanto rivede le scelte
  semplice: { reactionMs: 180, heavyEvery: 3, dodges: false, shields: false, grabs: true, specials: true, counters: false, supremes: true }, // heavyEvery: un pesante ogni tanti attacchi
  difficile: { reactionMs: 90, heavyEvery: 2, dodges: true, shields: true, grabs: true, specials: true, counters: true, supremes: true }, // dodges: schiva i pesanti; shields: si para dagli altri colpi; grabs: afferra chi si para; specials: tira e scatta (E10); counters: un pesante su due lo contrattacca; supremes: lancia la suprema (#102) con qualcuno a tiro
};

// Elementi dinamici delle arene (#14): ascensori e trappole. I loro numeri stanno nei dati dell'arena.
export const HAZARD = {
  cooldownMs: 700, // ms dopo una trappola in cui non se ne prende un'altra (niente colpi a raffica)
  travelFeetPx: 12, // la trappola che viaggia (#229) colpisce solo chi ha i piedi entro questo sotto il suo percorso: sotto il ponte si è al riparo (#253)
};

// Raffiche di vento (#433): i getti con dir spingono di lato, come il vento e non come un muro
export const WIND = {
  accelPxPerS2: 3600, // quanto in fretta la velocità orizzontale di chi è in aria va verso ±speed, pixel/s²
  groundFactor: 0.25, // a terra la spinta è questa frazione di speed (spostamento diretto, i piedi frenano), 0..1
};

// Arena musicale (#423, src/shared/musicStage.ts): come le note del brano muovono e accendono le piattaforme
export const MUSIC_STAGE = {
  liftGlideMs: 140, // ms in cui un ascensore va all'altezza della nota nuova
  slideGlideMs: 450, // ms in cui una navetta va al posto della nota nuova (gli accordi cambiano piano)
  keyMinOnMs: 900, // ms per cui un tasto resta almeno acceso, anche per una nota breve: ci si fa in tempo a salire
  keyMergeMs: 150, // ms: due note dello stesso tasto più vicine di così lo tengono acceso senza buchi
  chordMs: 30, // ms: note che partono più vicine di così sono un accordo, e conta la più bassa
};

// Bottoni sonori (#423, src/shared/physics/pads.ts): attesa ed effetti stanno nei dati dell'arena
export const PAD = {
  heightPx: 14, // quanto sporge il bottone sopra la superficie (disegno)
  hitPx: 60, // px sopra la superficie in cui un colpo lo preme: basta un colpo normale da in piedi accanto
  rampMs: 250, // ms in cui l'effetto entra ed esce: le piattaforme spostate non scattano
  landTolerancePx: 4, // px: chi atterra con i piedi fin qui dalla superficie del bottone lo preme
};

// Postazioni (#433, src/shared/physics/stations.ts): bombarda e munizioni, come in Lovers in a Dangerous Spacetime.
// Valgono quando la postazione nei dati dell'arena non dice altro
export const STATION = {
  standTolerancePx: 4, // px: con i piedi fin qui dalla superficie della postazione ci si è sopra
  reenterMs: 800, // ms dopo l'uscita prima che lo stesso lottatore possa rientrare in una postazione
  aimDegS: 70, // gradi/s di cui gira la canna tenendo su o giù
  aimMinDeg: 5, // gradi sopra l'orizzontale: la mira più bassa
  aimMaxDeg: 60, // gradi sopra l'orizzontale: la mira più alta
  ammoMax: 6, // palle di mortadella che la bombarda tiene al massimo
  startAmmo: 2, // palle nella bombarda a inizio partita
  fireMs: 900, // ms tra un colpo e il prossimo
  pivotPx: 46, // px sopra la superficie del perno della canna
  barrelPx: 56, // px di canna: la palla esce dalla bocca
  ballSpeedPxS: 1050, // pixel/s di uscita della palla
  ballGravityPxS2: 1300, // pixel/s² della palla: fa l'arco
  ballRadiusPx: 15, // raggio della palla, pixel
  ballDamage: 14, // percentuale a chi viene preso
  ballKnockback: 500, // pixel/s di lancio
  ballKnockbackGrowth: 4.5, // pixel/s in più per ogni punto di percentuale del bersaglio
  ballAngleDeg: 40, // angolo di lancio di chi viene preso
  loadMs: 1500, // munizioni: ms di attacco tenuto per caricare una cassa
  deliveryMs: 2500, // munizioni: ms di salita della cassa fino alla bombarda
  crate: 3, // munizioni: palle in una cassa
  gruMoveMs: 120, // gru: ms tra due spostamenti di colonna tenendo destra o sinistra
  gruCooldownMs: 2500, // gru: ms dopo un pezzo lasciato cadere prima che ne penda un altro
  gruMaxBlocks: 16, // gru: blocchi posati che restano per tutta la partita, per gru (circa 4 pezzi); oltre, spariscono come quelli del Tetris
};

// Classifica delle partite (#18, src/server/leaderboard.ts)
export const LEADERBOARD = {
  windowDays: 7, // la pagina /classifica conta le partite degli ultimi 7 giorni
  maxMatches: 2000, // partite tenute nel file, le più vecchie si buttano
};
export const DISCORD_LIMITS = {
  postsPerHour: 20, // risultati delle partite postati sul Discord in un'ora, da tutto il server insieme
  burst: 5, // risultati che possono partire uno dopo l'altro (una serata con più stanze)
};

// Oggetti (#17): cadono dal cielo, si raccolgono con J o K e si lanciano con J o K
// Classi di frequenza degli oggetti che cadono (Nicola, 24 ottobre 2026): ogni oggetto ne ha una, proporzionata a quanto
// cambia la partita. Il numero è il peso nell'estrazione: un comune cade otto volte più spesso di un rarissimo
export const ITEM_RARITY = {
  comune: 8, // piccolo vantaggio, da lanciare (banana)
  normale: 4, // vantaggio a tempo o con un rischio (funghetti, bong)
  raro: 2, // cambia uno scontro: intoccabili, un aiuto che gira l'arena (fiore, Bassanese)
  rarissimo: 1, // cambia la partita per diversi secondi (Tetris, Pac-Man)
  mai: 0, // non cade dal cielo (il funghetto piantato)
};
export type ItemRarity = keyof typeof ITEM_RARITY;

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

// Quanti oggetti cadono, scelto da chi crea la stanza: indice in rules.itemAmount. Il default è "Normali" = ITEM_RULES
export const ITEM_AMOUNTS = [
  { label: "Nessuno", everyMs: 0, maxOnStage: 0 },
  { label: "Pochi", everyMs: 18000, maxOnStage: 1 }, // ms tra un oggetto e l'altro, oggetti in campo insieme
  { label: "Normali", everyMs: ITEM_RULES.spawnEveryMs, maxOnStage: ITEM_RULES.maxOnStage },
  { label: "Tanti", everyMs: 6000, maxOnStage: 4 },
  { label: "Pioggia", everyMs: 2500, maxOnStage: 8 },
];
export const DEFAULT_ITEM_AMOUNT = 2;

// Velocità della barra della suprema, scelta da chi crea la stanza: moltiplica tutta la carica (rules.supremeSpeed)
export const SUPREME_SPEEDS = [
  { mult: 1, label: "Normale" },
  { mult: 1.5, label: "Veloce" },
  { mult: 2, label: "Molto veloce" },
  { mult: 4, label: "Turbo" },
];

// Potenziamenti degli oggetti da consumare (#231): il fiore rende intoccabili ma "rilassati"
export const POWERUP = {
  flowerMs: 8000, // ms di effetto dalla raccolta
  damageMult: 1.3, // danno dei colpi dati mentre si è potenziati
  speedMult: 0.75, // frazione della velocità orizzontale, a terra e in aria (il salto resta uguale)
  endingMs: 1500, // ms finali in cui l'alone lampeggia nel client, per avvisare che sta finendo
};

// Il bong (#302): si carica tenendo J, lasciandolo si è "fatti", J o K soffia la nuvola. Troppo tardi e si crolla
export const BONG = {
  loadMs: 1200, // ms tenendo J per caricarlo; lasciando prima la carica si perde
  highMs: 7000, // ms da fatti prima di crollare se non si soffia
  gravityMult: 0.7, // frazione della gravità da fatti: più leggeri, salti più alti e cadute lente
  stunMs: 2500, // ms tramortiti quando si crolla: fermi e colpibili come con lo scudo rotto
  cloudRadius: 95, // pixel del raggio della nuvola
  cloudOffsetX: 55, // pixel davanti al centro del lottatore dove sta il centro della nuvola
  minDamage: 12, // percentuale della nuvola soffiata subito
  maxDamage: 28, // percentuale della nuvola soffiata all'ultimo: l'effetto cresce col tempo
  minKnockback: 520, // pixel/s di lancio subito
  maxKnockback: 820, // pixel/s di lancio all'ultimo
  knockbackGrowth: 6, // pixel/s in più per ogni punto di percentuale del bersaglio
  angleDeg: 40, // angolo di lancio di chi prende la nuvola
  cooldownMs: 350, // ms dopo la nuvola prima di poter attaccare
};

// I funghetti di Teemo (#302): dal sacchetto giù + J ne pianta uno ai piedi; quasi invisibili agli altri, chi li calpesta "viaggia"
export const FUNGHI = {
  uses: 3, // funghetti in un sacchetto
  armMs: 600, // ms dopo averlo piantato prima che scatti (non lo si calpesta da soli piantandolo)
  lifeMs: 20000, // ms prima che un funghetto piantato sparisca
  damage: 6, // percentuale a chi lo calpesta
  tripMs: 3000, // ms con destra e sinistra invertite
  popVy: 520, // pixel/s verso l'alto: il funghetto che scoppia fa saltellare
  throwSpeed: 650, // pixel/s di un funghetto lanciato con J + destra/sinistra: vola ad arco e si pianta dove cade
  throwLift: 380, // pixel/s verso l'alto del lancio in avanti
  throwUpSpeed: 900, // pixel/s del lancio con J + su
};

// Il fungo di Teemo (idea di Riccardo, #419): si lancia a pallonetto, si piazza dove atterra e dopo un po' gli avversari
// non lo vedono più. Chi ci passa sopra lo fa scoppiare in una nube che avvelena e rallenta tutti gli avversari vicini
export const FUNGO = {
  thrownDamage: 4, // percentuale a chi viene preso dal fungo in volo (poi cade e si piazza lo stesso)
  throwSpeed: 520, // pixel/s in avanti: un pallonetto, più lento della banana (ITEM_RULES.throwSpeed)
  throwLift: 560, // pixel/s verso l'alto del pallonetto
  throwUpSpeed: 900, // pixel/s tenendo su
  gravityMult: 1.35, // il fungo è pesante: in volo cade più in fretta degli altri oggetti
  armMs: 1000, // ms dopo l'atterraggio prima che si armi
  stealthMs: 1800, // ms dopo l'atterraggio in cui è sparito del tutto agli avversari (sfuma da armMs)
  lifeMs: 25000, // ms prima che un fungo piazzato sparisca
  damage: 8, // percentuale dello scoppio
  blastRadius: 70, // pixel: raggio della nube, dal centro del fungo al punto più vicino del corpo
  poisonMs: 6000, // ms di veleno
  poisonTickMs: 500, // ms tra uno scatto di veleno e l'altro
  poisonPerSec: 2, // percentuale al secondo del veleno (12% in tutto con 6 s)
  slowMult: 0.65, // frazione della velocità orizzontale finché dura il veleno, come il rallentamento di Teemo
  bounceVx: 260, // pixel/s in avanti: un fungo che cade su un altro rimbalza nella direzione del lancio
  bounceVy: 420, // pixel/s verso l'alto del rimbalzo
};

// Il filo di Kirschner di Dr. Micelium (#358): chi è infettato dalle spore va più piano, lui picchia più forte.
// Sono potenziamenti come quelli degli oggetti (powerup "spore" e "micelio"), così il client li vede nello snapshot
export const SPORE = {
  ms: 4000, // ms di infezione
  speedMult: 0.6, // frazione della velocità orizzontale, a terra e in aria
};
export const MICELIO = {
  ms: 6000, // ms in cui Dr. Micelium picchia più forte
  damageMult: 1.3, // danno dei colpi dati
  attackSpeedMult: 1.25, // velocità degli attacchi normali (la scheda: "più forte e più veloce")
};

// Il compagno di un lottatore (#369), il beagle di Lampione: come lo segue
export const COMPANION = {
  gapPx: 46, // pixel dietro al padrone dove aspetta
  slackPx: 14, // pixel di distanza da quel posto entro cui sta fermo
  groundAccel: 2600, // pixel/s² a terra
  airAccel: 900, // pixel/s² in aria
  jumpIfAbovePx: 40, // pixel: se il padrone è a terra più in alto di così, salta
  teleportPx: 520, // pixel: più lontano di così torna di colpo accanto al padrone
  lungeSpeed: 800, // pixel/s: lo scatto in avanti del morso, che poi frena
  lungeFriction: 1800, // pixel/s² di frenata dopo lo scatto del morso
  koPercent: 35, // danni dopo cui va KO
  hurtHeight: 50, // pixel: alto così per chi lo colpisce, anche se è più basso, sennò i colpi in piedi gli passano sopra
  koMs: 6000, // ms prima che torni dopo il KO
  hurtMs: 350, // ms in cui vola via colpito, senza seguire
  knockBase: 320, // pixel/s di spinta di un colpo
  knockPerDamage: 22, // pixel/s in più per ogni punto di danno
  bounceVy: 1050, // pixel/s verso l'alto quando il padrone gli rimbalza sopra (il salto è 860)
  waitAirPx: 140, // pixel: se il padrone salta più vicino di così, il compagno aspetta fermo dov'è
  bounceSlackPx: 24, // pixel sotto la sua schiena entro cui chi scende conta come atterrato sopra
  biteReachPx: 110, // pixel: morde solo se all'inizio dell'attacco è più vicino di così al padrone, sennò attacca il padrone
  biteReachYPx: 30, // pixel di dislivello massimo col padrone per mordere al suo posto
};

// Le pozze dell'IRA di Lendmar (#13): la merda che cade su un blocco fa scivolare chi ci passa
export const SLICK = {
  lifeMs: 5000, // ms prima che una pozza sparisca
  width: 70, // pixel
  max: 10, // pozze insieme in tutta l'arena: oltre, sparisce la più vecchia
  landSlackPx: 30, // pixel sotto il bordo del blocco entro cui il proiettile conta come caduto sopra
  accel: 450, // pixel/s²: quanto in fretta si cambia velocità sopra una pozza (a terra di solito è subito)
};

// Il power-up Tetris (#427): chi lo prende si assenta (fermo e intoccabile) e guida pezzi che cadono dall'alto
// dell'arena. Un pezzo colpisce chi tocca e, posato, diventa blocchi solidi per un po'
export const TETRIS = {
  ms: 9000, // ms di partita a Tetris dalla raccolta
  cellPx: 40, // lato di un quadretto, pixel: le colonne sono WORLD.width / cellPx
  spawnY: -40, // pixel: bordo alto del quadretto centrale del pezzo quando compare, appena sopra lo schermo
  nextPieceMs: 800, // ms tra un pezzo posato (o fatto cadere con K) e il prossimo: senza, sarebbe una pioggia continua
  spawnRoomPx: 160, // pixel liberi sotto un pezzo nuovo: se la pila è più alta, compare in un'altra colonna
  fallPxS: 240, // pixel/s di caduta
  softPxS: 800, // pixel/s tenendo giù
  dropPxS: 2400, // pixel/s dopo K: cade di colpo
  repeatMs: 120, // ms tra due spostamenti di colonna tenendo destra o sinistra
  blockMs: 10000, // ms in cui un pezzo posato resta come blocchi solidi
  fadeMs: 1500, // ms finali in cui i blocchi lampeggiano nel client, per avvisare che spariscono
  maxBlocks: 48, // blocchi al massimo nell'arena: oltre, spariscono i più vecchi
  damage: 12, // percentuale a chi viene preso da un pezzo che cade
  knockback: 480, // pixel/s di lancio
  knockbackGrowth: 5, // pixel/s in più per ogni punto di percentuale del bersaglio
  angleDeg: 50, // angolo di lancio
  dropDamage: 18, // percentuale se il pezzo cade di colpo con K: più rischio di mancare, più danno
  dropKnockback: 620, // pixel/s di lancio del pezzo fatto cadere di colpo
  lineCells: 6, // blocchi posati in fila sulla stessa riga che fanno una riga: esplode come nel Tetris vero
  lineDamage: 16, // percentuale a chi sta sopra o dentro una riga che esplode
  lineKnockback: 640, // pixel/s di lancio della riga, quasi in verticale
  lineAngleDeg: 80, // angolo di lancio della riga
  lineReachPx: 80, // pixel sopra la riga in cui si viene presi: chi ci sta in piedi sopra vola via
  returnInvulnerableMs: 600, // ms intoccabili quando si torna in partita
};

// Il power-up Pac-Man (#427): per un po' si è Pac-Man. Niente gravità, si va sempre dritti nella direzione scelta,
// si passa attraverso tutto e si esce da un lato dello schermo per rientrare dall'altro; si è intoccabili e si mangia chi si tocca
export const PACMAN = {
  ms: 8000, // ms da Pac-Man dalla raccolta
  speedPxS: 380, // pixel/s, sempre uguale come nel gioco vero
  radiusPx: 34, // raggio della bocca: chi ci entra col corpo viene mangiato
  damage: 14, // percentuale a chi viene mangiato
  knockback: 560, // pixel/s di lancio
  knockbackGrowth: 6, // pixel/s in più per ogni punto di percentuale del bersaglio
  angleDeg: 45, // angolo di lancio
  eatAgainMs: 1200, // ms prima di poter mangiare di nuovo lo stesso lottatore
  pelletStepPx: 40, // pixel tra due palline sulle superfici (Godot le disegna negli stessi posti, arcade_view.gd)
  pelletAbovePx: 40, // pixel sopra la superficie a cui stanno le palline
  bigPelletEvery: 8, // una pallina grande ogni tante
  speedPerPellet: 0.012, // velocità in più per ogni pallina mangiata, frazione di speedPxS (Nicola, 24 ottobre 2026)
  bigPelletValue: 5, // una pallina grande vale come tante piccole
  maxSpeedMul: 1.8, // la velocità non supera speedPxS per questo
};

// Chiama Bassanese (idea di Nicola, 24 ottobre 2026): un telefono che, raccolto, fa entrare il Bassanese.
// Attraversa tutta l'arena di superficie in superficie, guardandosi in giro come chi cerca qualcosa, e se ne va; fa male a chi tocca, tranne a chi l'ha chiamato
export const BASSANESE = {
  walkPxS: 300, // pixel/s camminando su una superficie
  jumpPxS: 420, // pixel/s in orizzontale nei salti da una superficie all'altra
  jumpMinMs: 380, // ms minimi di un salto, anche corto
  hopPx: 70, // pixel sopra il punto più alto del salto
  endInsetPx: 26, // pixel dal bordo di una superficie dove si ferma
  lookMs: 260, // ms fermo a guardarsi in giro arrivando su una superficie
  minSurfacePx: 60, // le superfici più strette non le visita
  maxSurfaces: 10, // superfici visitate al massimo: nelle arene piene ne sceglie alcune sparse da un lato all'altro
  maxMs: 15000, // ms massimi del giro: nelle arene grandi cammina più svelto
  enterPx: 80, // pixel fuori dall'arena da cui entra e verso cui se ne va
  width: 54, // pixel del corpo che colpisce
  height: 104,
  damage: 11, // percentuale a chi tocca
  knockback: 520, // pixel/s di lancio
  knockbackGrowth: 5, // pixel/s in più per ogni punto di percentuale del bersaglio
  angleDeg: 40, // angolo di lancio, verso dove cammina
  hitAgainMs: 1100, // ms prima di poter colpire di nuovo lo stesso lottatore
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
  speeds: [1, 0.9, 0.8, 0.5, 0.25], // velocità dell'orologio ammesse: 1 normale, 0.9 e 0.8 per provare un gioco più lento (#384), 0.5 e 0.25 rallentatore
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

// Arena Bologna (#433): i tempi dell'arena che cambia, tutti in ms dall'inizio della partita (stageMs)
export const BOLOGNA = {
  towersMs: 45000, // 0:45 comincia "Ognuno sulla sua torre": appaiono le torri e l'ingorgo in via Rizzoli
  collapseMs: 150000, // 2:30 la Garisenda cede: spariscono i suoi pezzi e cadono i mattoni
  collapseFallMs: 4000, // quanto dura la caduta della torre disegnata: finisce a 2:34, quando appare la rampa
  bricksEndMs: 156000, // 2:36 finiscono di cadere i mattoni
  rampMs: 154000, // 2:34 appare la rampa: la torre caduta appoggiata all'Asinelli
  brawlMs: 165000, // 2:45 comincia "La grande zuffa": tutti in cima all'Asinelli
  dustMs: 270000, // 4:30 comincia a salire la polvere
  horizonMs: 900000, // 15 min: fin dove si scrivono le finestre dei pezzi a tempo (oltre non c'è partita)
  liftPeriodMs: 3600000, // un'ora: l'ascensore a chiavi non deve ricominciare dentro una partita
  jamPeriodMs: 4000, // l'ingorgo va a ondate: un giro...
  jamActiveMs: 3000, // ...di cui acceso (poi 1 s di pausa)
  merlonPresentMs: 8000, // i merli della cima ci sono per tanto...
  merlonGoneMs: 1000, // ...e poi spariscono per tanto
  lightningPeriodMs: 20000, // un fulmine sul punto più alto ogni tanto
  lightningWarnMs: 1200, // l'avviso prima del fulmine: la linea tratteggiata dal cielo e il bersaglio che si accende
  windPeriodMs: 16000, // una raffica ogni giro, a sinistra e a destra sfasate di mezzo giro: una ogni 8 s (era 9 s, una ogni 4,5)
  windSpeedPxS: 380, // pixel/s verso cui spinge la raffica chi è in aria (era 600: troppo invadente nella zuffa, Nicola)
  windActiveMs: 1800, // ms di soffio di ogni raffica (era 2500)
  aimMinDeg: 10, // gradi sopra l'orizzontale: la mira più bassa delle bombarde (arriva sulla torre avversaria)
  aimMaxDeg: 60, // gradi sopra l'orizzontale: la mira più alta delle bombarde
  ballSpeedPxS: 800, // pixel/s di uscita delle palle delle bombarde (a 1050 sorvolano la torre avversaria)
  autoAmmoMs: 8000, // ms: una palla in più alle bombarde anche senza casse (1 contro 1)
  awningWidthPx: 80, // le bancarelle col tendone che fa da molla, larghe tanto...
  awningHeightPx: 80, // ...e alte tanto: chi ha i piedi sotto il tendone viene lanciato (Godot lo disegna lì)
  awningSpeedPxS: 1480, // pixel/s verso l'alto: con la gravità di 2300 si sale di circa 480 px (il salto ne fa 160)
  updraftX: 875, // la corrente calda che sale dalle macerie (da 2:34): bordo sinistro, sopra la rampa e a sinistra della gru...
  updraftWidthPx: 90, // ...larga tanto...
  updraftBaseY: 1700, // ...con la base un doppio salto sopra la rampa: camminandoci sotto non ti prende...
  updraftHeightPx: 600, // ...e alta fino all'altezza dei detriti in cima (y 1100)
  updraftSpeedPxS: 420, // pixel/s verso l'alto: lenta, come le correnti di Celeste e Kirby; ridà il recupero
  busFirstMs: 3000, // il primo bus in piazza: si sale sul tetto e porta da una parte all'altra (piattaforma mobile)
  busEveryMs: 14000, // ogni quanto ne parte uno, alternando il verso, finché c'è la piazza (0:45)
  busStopMs: 3000, // la sosta alla fermata in mezzo alla piazza: il momento per salire
  busSpeedPxS: 400, // pixel/s mentre entra ed esce
  bellSwingMs: 4400, // l'altalena della campana tra le torri: un'andata e ritorno completa...
  bellAmplitudeDeg: 38, // ...fino a tanti gradi dalla verticale per parte: agli estremi sfiora la postazione (A) di ogni torre
};
