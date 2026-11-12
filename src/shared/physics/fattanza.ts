// La Fattanza di Marcomunista (Nicola, 12/11/2026): più è fatto più fluttua e più è forte in aria, ma a terra è lento.
// La barra sale stando in aria, coi colpi in aria che prendono, col Rolling riuscito e con la provocazione;
// scende stando a terra e coi colpi forti. A Strafatto (barra piena) dopo strafattoMs crolla: la botta.
// Tenendo Salto in aria mentre scende fluttua col cappello sopra la testa, come un paracadute.
import { getCharacter } from "../characters";
import { FATTANZA } from "../constants";
import type { Fighter, PhysicsContext } from "./fighter";

const max = FATTANZA.perLevel * FATTANZA.levels;

export const hasFattanza = (f: Fighter): boolean => !!getCharacter(f.characterId).fattanza;

// Il livello pieno raggiunto: 0 Lucido, 1 Rilassato, 2 Fatto, 3 Strafatto
export function fattanzaLevel(f: Fighter): number {
  if (!hasFattanza(f)) return 0;
  return Math.min(FATTANZA.levels, Math.floor(f.fattanza / FATTANZA.perLevel));
}

export const fattanzaGravityMult = (f: Fighter): number => FATTANZA.gravityMult[fattanzaLevel(f)];
export const fattanzaGroundSpeedMult = (f: Fighter): number => (f.onGround ? FATTANZA.groundSpeedMult[fattanzaLevel(f)] : 1);
export const fattanzaDamageMult = (f: Fighter): number => (f.onGround ? 1 : FATTANZA.airDamageMult[fattanzaLevel(f)]);

// Aggiunge (o toglie, se negativo) punti; arrivando in cima parte lo Strafatto
export function addFattanza(f: Fighter, points: number): void {
  if (!hasFattanza(f) || f.strafattoMs > 0 && points > 0) return; // a Strafatto la barra resta piena finché non crolla
  const before = fattanzaLevel(f);
  f.fattanza = Math.max(0, Math.min(max, f.fattanza + points));
  if (f.fattanza >= max && before < FATTANZA.levels) f.strafattoMs = FATTANZA.strafattoMs;
  if (f.fattanza < max) f.strafattoMs = 0;
}

// Un colpo subito: quelli forti fanno perdere un livello
export function hurtFattanza(f: Fighter, damage: number): void {
  if (damage >= FATTANZA.bigHit) addFattanza(f, -FATTANZA.perLevel);
}

// Ogni tick: la barra sale in aria e scende a terra; lo Strafatto finisce con la botta
export function tickFattanza(f: Fighter, dtMs: number, ctx: PhysicsContext): void {
  if (!hasFattanza(f)) return;
  if (f.onGround) {
    f.groundMs += dtMs;
    f.floatMs = 0;
    if (f.groundMs > FATTANZA.groundGraceMs && f.strafattoMs === 0) addFattanza(f, -(FATTANZA.groundDrain * dtMs) / 1000);
  } else {
    f.groundMs = 0;
    if (!f.hitstun && f.stunTimer === 0) addFattanza(f, (FATTANZA.airGain * dtMs) / 1000);
  }
  if (f.strafattoMs > 0) {
    f.strafattoMs = Math.max(0, f.strafattoMs - dtMs);
    if (f.strafattoMs === 0) {
      // La botta: barra a zero e un attimo barcollando, come dopo lo scudo rotto
      f.fattanza = 0;
      f.stunTimer = Math.max(f.stunTimer, FATTANZA.bottaMs);
      ctx.events.push({ type: "botta", id: f.id });
    }
  }
}

// Dopo la gravità: tenendo Salto mentre scende fluttua col cappello finché ha fluttuata
export function floatHat(f: Fighter, dtMs: number): void {
  f.floating = false;
  if (!hasFattanza(f) || f.onGround || !f.input.jump || f.hitstun || f.stunTimer > 0 || f.vy < 0) return;
  if (f.ledgeIndex >= 0 || f.anchor || f.helpless) return;
  const level = fattanzaLevel(f);
  if (f.strafattoMs === 0 && f.floatMs >= FATTANZA.floatMs[level]) return;
  f.floating = true;
  f.floatMs += dtMs;
  if (f.vy > FATTANZA.floatFallSpeed) f.vy = FATTANZA.floatFallSpeed;
}
