// Numeri del gioco condivisi tra client e server.
// Vuoi un gioco più veloce o salti più alti? Si parte da qui.

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
}

export const ATTACKS: Record<"light" | "heavy", AttackSpec> = {
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

// Audio (#6): volumi di partenza, da 0 a 1. Ognuno poi li cambia nelle opzioni.
export const AUDIO = {
  master: 0.8,
  sfx: 0.7,
  music: 0.35,
  musicBpm: 132, // velocità della musica sintetizzata, battiti al minuto
  hitLoudPercent: 120, // da questa percentuale in su i colpi suonano al massimo
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
  koBeamMs: 750, // durata del raggio colorato di un KO
  koBeamLength: 1400, // pixel: quanto entra nello schermo il raggio del KO
  koBeamWidth: 150, // pixel: larghezza del raggio dove finisce (all'uscita è una punta)
  percentShakeMs: 280, // durata del tremolio della percentuale dopo un colpo
  percentShakePerDamage: 0.6, // pixel di tremolio per ogni punto di danno preso
  percentShakeMax: 9, // pixel: tremolio massimo della percentuale
};
