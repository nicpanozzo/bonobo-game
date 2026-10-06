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
export const MAX_PLAYERS_PER_ROOM = 4;

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

export const STOCKS = 3; // vite per partita
export const RESPAWN_MS = 1500; // attesa dopo aver perso una vita
export const RESPAWN_INVULNERABLE_MS = 1500;
export const MATCH_RESTART_MS = 5000; // pausa dopo la vittoria prima della nuova partita

export const COLORS = [0xe74c3c, 0x3498db, 0x2ecc71, 0xf1c40f];

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

// Squadre (#17): due tonalità per squadra, così i compagni si distinguono tra loro
export const TEAM_COLORS: Record<1 | 2, number[]> = {
  1: [0xe74c3c, 0xff9a8a],
  2: [0x3498db, 0x8fd0ff],
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
