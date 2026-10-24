// Corsa, controllo in aria, salti, caduta veloce e gravità.

import { characterStats } from "../characters";
import { ATTACKS, BONG, DASH, DODGE, FIGHTER, FLAG, HITSTUN_AIR_DRAG, POWERUP, RECOVERY, SLICK, SPORE } from "../constants";
import { attackSpecFor, startAttack } from "./attacks";
import { endDash, stepDash } from "./dash";
import { consume, pressed, type Fighter, type PhysicsContext } from "./fighter";
import { onPuddle } from "./projectiles";
import { attackMoveFactor } from "./supreme";

// Cosa fa il lottatore con i tasti premuti (solo se non è stordito)
export function applyControls(f: Fighter, dt: number, ctx: PhysicsContext): void {
  const dir = (f.input.right ? 1 : 0) - (f.input.left ? 1 : 0);

  if (f.hitstun) {
    endDash(f);
    f.jumpRising = false;
    if (!f.onGround) {
      f.vx *= HITSTUN_AIR_DRAG;
      // Influenza: tenendo una direzione si corregge un po' il volo, così chi sa dove andare sopravvive di più
      f.vx += dir * FIGHTER.hitstunDriftAccel * dt;
    }
    return;
  }

  // Salto corto: lasciando il tasto mentre si sale si perde parte della spinta
  if (f.jumpRising) {
    if (f.vy >= 0) f.jumpRising = false;
    else if (!f.input.jump && f.shortHop) {
      f.vy *= FIGHTER.shortHopCut;
      f.jumpRising = false;
    }
  }

  // Schivata (#3): mentre dura si scivola alla velocità decisa all'inizio, senza controlli né attacchi
  if (f.dodgeTimer > 0) {
    endDash(f);
    return;
  }
  // In aria lo scudo schiva, come in Smash (a terra scudo + direzione rotola, shield.ts)
  const airShield = !f.onGround && f.input.shield && !f.prevInput.shield;
  if ((pressed(f, "dodge") || airShield) && !f.attack && f.dodgeCooldown === 0 && (f.onGround || !f.airDodgeUsed)) {
    consume(f, "dodge");
    f.dodgeTimer = DODGE.durationMs;
    f.dodgeCooldown = DODGE.cooldownMs;
    f.invulnerableTimer = Math.max(f.invulnerableTimer, DODGE.durationMs);
    f.invulnerable = true;
    f.vx = dir * DODGE.speed;
    if (!f.onGround) {
      f.airDodgeUsed = true;
      f.vy = 0; // in aria ci si ferma un attimo, come in Brawlhalla
    }
    if (dir !== 0) f.facing = dir as 1 | -1;
    ctx.events.push({ type: "dodge", id: f.id, x: Math.round(f.x), y: Math.round(f.y), air: !f.onGround });
    return;
  }
  const stats = characterStats(f.characterId);
  const speed = (f.carrier ? FLAG.carrierSpeed : 1) * (f.powerup === "fiore" ? POWERUP.speedMult : f.powerup === "spore" ? SPORE.speedMult : 1); // la bandiera pesa, il fiore rilassa (#231), le spore rallentano (#358)
  // Durante un attacco da terra si resta fermi, in aria si mantiene lo slancio
  const dashSpeed = stepDash(f, dir, dt * 1000, ctx); // scatto e corsa (#199)
  if (f.onGround && dashSpeed !== null) {
    f.vx = dashSpeed * speed;
  } else if (f.onGround) {
    // fermi durante gli attacchi, tranne la scivolata dell'attacco in corsa e la suprema che gira (#358)
    const want = f.attack
      ? (attackSlide(f) + dir * FIGHTER.groundSpeed * stats.speed * attackMoveFactor(f)) * speed
      : dir * FIGHTER.groundSpeed * stats.speed * speed;
    // sopra una pozza dell'IRA (#13) non si frena né si parte di colpo: si scivola
    const slip = SLICK.accel * dt;
    f.vx = onPuddle(f, ctx) ? f.vx + Math.max(-slip, Math.min(slip, want - f.vx)) : want;
  } else if (dir !== 0) {
    f.vx += dir * FIGHTER.airAccel * dt;
    const max = FIGHTER.airSpeed * stats.airSpeed * speed;
    f.vx = Math.max(-max, Math.min(max, f.vx));
  } else {
    const slow = FIGHTER.airFriction * dt;
    f.vx = Math.abs(f.vx) <= slow ? 0 : f.vx - Math.sign(f.vx) * slow;
  }
  if (dir !== 0 && !f.attack) f.facing = dir as 1 | -1;

  // Recupero (#11): in aria, K premuto tenendo su. Vince sul salto se i due tasti arrivano insieme.
  if (!f.onGround && !f.attack && !f.recoveryUsed && f.input.up && pressed(f, "heavy")) {
    f.vy = -RECOVERY.speed;
    f.vx = dir * RECOVERY.drift;
    f.recoveryUsed = true;
    f.helpless = true;
    f.jumpRising = false; // la spinta ora è del recupero: lasciare il salto non la accorcia
    startAttack(f, "recovery", ctx);
    return;
  }

  // Salto e doppio salto. Da terra prima la preparazione (#384 A3): ci si stacca in stepLag
  if (pressed(f, "jump") && f.jumpsLeft > 0 && f.onGround) {
    consume(f, "jump");
    f.jumpSquatTimer = FIGHTER.jumpSquatMs;
  } else if (pressed(f, "jump") && f.jumpsLeft > 0) {
    consume(f, "jump"); // una pressione = un salto solo
    const fromGround = f.onGround || f.coyoteTimer > 0; // appena scesi dal bordo vale ancora da terra
    ctx.events.push({ type: "jump", id: f.id, x: Math.round(f.x), y: Math.round(f.y), air: !fromGround });
    f.vy = -(fromGround ? FIGHTER.jumpSpeed : FIGHTER.doubleJumpSpeed) * stats.jump;
    f.jumpsLeft -= 1;
    f.onGround = false;
    f.coyoteTimer = 0;
    f.jumpRising = true;
  }

  // Giù: attraversa le piattaforme sottili, in aria cade più veloce
  if (pressed(f, "down")) {
    f.dropTimer = FIGHTER.dropThroughMs;
    f.dropFromY = f.y;
  }

  // Provocazione: solo da fermi a terra, la usano voci e animazioni (#16)
  if (pressed(f, "taunt") && f.onGround && !f.attack) ctx.events.push({ type: "taunt", id: f.id });
}

// Preparazione al salto e pausa all'atterraggio (#384 A3), come Smash. true se in questo tick non si comanda
// niente: né movimento, né attacchi, né scudo; i tasti premuti intanto restano nel buffer. Finita la
// preparazione ci si stacca e si comanda già in questo tick: lasciato il salto, applyControls lo accorcia
export function stepLag(f: Fighter, dtMs: number, ctx: PhysicsContext): boolean {
  if (f.hitstun) {
    f.jumpSquatTimer = f.landingTimer = 0;
    return false;
  }
  if (f.landingTimer > 0) {
    f.landingTimer = tickDown(f.landingTimer, dtMs);
    if (f.onGround) f.vx = 0;
    if (f.landingTimer > 0) return true;
  }
  if (f.jumpSquatTimer === 0) return false;
  f.jumpSquatTimer = tickDown(f.jumpSquatTimer, dtMs);
  consume(f, "jump"); // un'altra pressione durante la preparazione non fa il doppio salto appena staccati
  if (f.jumpSquatTimer > 0) return true;
  ctx.events.push({ type: "jump", id: f.id, x: Math.round(f.x), y: Math.round(f.y), air: false });
  f.vy = -FIGHTER.jumpSpeed * characterStats(f.characterId).jump;
  f.jumpsLeft = FIGHTER.maxJumps - 1;
  f.onGround = false;
  f.coyoteTimer = 0;
  f.jumpRising = true;
  return false;
}

// Sotto mezzo millisecondo il tempo è finito: gli snapshot arrotondano i ms e la predizione deve contare gli stessi tick
const tickDown = (ms: number, dtMs: number) => (ms - dtMs > 0.5 ? ms - dtMs : 0);

// Appena atterrati (#384 A3): una pausa breve, o quella dell'attacco in aria in corso, che si interrompe.
// Niente pausa per chi atterra stordito (c'è la rialzata), con lo scudo rotto, schivando o a metà di speciali, suprema o recupero
export function startLanding(f: Fighter): void {
  if (f.hitstun || f.stunTimer > 0 || f.dodgeTimer > 0) return; // lo stordimento dello scudo rotto conta già
  if (!f.attack) {
    f.landingTimer = FIGHTER.landingLagMs;
    return;
  }
  const lag = attackSpecFor(f).landingLagMs;
  if (!f.attackAir || lag === undefined) return;
  f.landingTimer = lag;
  f.attack = null;
  f.attackActive = false;
  f.cooldownTimer = 0; // la pausa prende il posto del resto del colpo
}

// L'attacco in corsa scivola in avanti finché il colpo è attivo, poi ci si ferma; gli altri attacchi da terra stanno fermi
function attackSlide(f: Fighter): number {
  if (f.attack !== "dashAttack") return 0;
  const spec = ATTACKS.dashAttack;
  return f.attackTimer < spec.startupMs + spec.activeMs ? f.facing * DASH.attackSlide : 0;
}

// Finito il tempo di grazia senza saltare, il salto da terra è perso (resta quello in aria)
export function tickCoyote(f: Fighter, dtMs: number): void {
  if (f.coyoteTimer === 0) return;
  f.coyoteTimer = Math.max(0, f.coyoteTimer - dtMs);
  if (f.onGround || f.ledgeIndex >= 0) f.coyoteTimer = 0; // a terra o appesi al bordo non serve più
  else if ((f.coyoteTimer === 0 || f.hitstunTimer > 0) && f.jumpsLeft === FIGHTER.maxJumps) {
    f.coyoteTimer = 0;
    f.jumpsLeft = FIGHTER.maxJumps - 1;
  }
}

export function applyGravity(f: Fighter, dt: number): void {
  const fastFall = f.input.down && !f.hitstun;
  const maxFall = fastFall ? FIGHTER.fastFallSpeed : FIGHTER.maxFallSpeed;
  const high = f.powerup === "bong" ? BONG.gravityMult : 1; // fatti col bong si è più leggeri (#302)
  f.vy = Math.min(f.vy + FIGHTER.gravity * characterStats(f.characterId).gravity * high * dt, f.hitstun ? Infinity : maxFall);
  if (fastFall && !f.onGround && f.vy > 0) f.vy = Math.max(f.vy, maxFall * 0.8);
}
