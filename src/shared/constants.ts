// Numeri del gioco condivisi tra client e server.
// Vuoi un gioco più veloce o salti più alti? Si parte da qui.

export const WORLD = {
  width: 1280, // area visibile, pixel
  height: 720,
};

// Arena: un palco principale solido e piattaforme sottili attraversabili dal basso.
export const STAGE = {
  x: 240, // bordo sinistro del palco principale
  width: 800,
  y: 560, // superficie su cui si cammina
  thickness: 80,
};

export const PLATFORMS = [
  { x: 340, width: 200, y: 420 },
  { x: 740, width: 200, y: 420 },
  { x: 540, width: 200, y: 290 },
];

// Zone di espulsione: chi esce da questo rettangolo perde una vita.
export const BLAST_ZONE = {
  left: -250,
  right: WORLD.width + 250,
  top: -350,
  bottom: WORLD.height + 200,
};

export const TICK_RATE = 60; // aggiornamenti della fisica al secondo (server)
export const SEND_RATE = 30; // stati inviati ai client al secondo
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
export const RESPAWN_POINT = { x: WORLD.width / 2, y: 160 };
export const MATCH_RESTART_MS = 5000; // pausa dopo la vittoria prima della nuova partita

export const COLORS = [0xe74c3c, 0x3498db, 0x2ecc71, 0xf1c40f];
