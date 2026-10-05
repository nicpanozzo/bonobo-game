// Numeri del gioco condivisi tra client e server.
// Vuoi un gioco più veloce o salti più alti? Si parte da qui.

export const WORLD = {
  width: 960,
  height: 540,
  floorY: 480, // altezza del pavimento (i piedi del personaggio)
};

export const TICK_RATE = 60; // aggiornamenti della fisica al secondo (server)
export const SEND_RATE = 30; // stati inviati ai client al secondo
export const MAX_PLAYERS_PER_ROOM = 4;

export const FIGHTER = {
  width: 48,
  height: 96,
  speed: 320, // pixel al secondo
  jumpSpeed: 720,
  gravity: 2000,
  maxHp: 100,
};

export const ATTACK = {
  damage: 8,
  range: 56, // quanto si allunga il pugno davanti al personaggio
  height: 32,
  activeMs: 120, // per quanto tempo il colpo può fare danno
  cooldownMs: 350, // tempo minimo tra due colpi
  knockbackX: 420,
  knockbackY: 280,
  hitstunMs: 250, // per quanto tempo chi è colpito non può muoversi
};

export const RESPAWN_MS = 2000;

export const COLORS = [0xe74c3c, 0x3498db, 0x2ecc71, 0xf1c40f];
