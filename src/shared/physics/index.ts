// Logica di gioco "pura": niente rete, niente grafica.
// Gira sul server; in futuro può girare anche sul client per la predizione.
// Ogni parte ha il suo file, così chi lavora sul movimento non tocca gli attacchi:
//   fighter.ts   stato del lottatore e creazione
//   movement.ts  corsa, salti, gravità (#3, #11)
//   attacks.ts   attacchi e colpi (#2, #15)
//   stage.ts     contatto con l'arena, KO e respawn (#14)
//   elements.ts  ascensori e trappole (#14)
//   ledge.ts     bordo del palco (#110)
//   shield.ts    scudo e stordimento (#109)
//   grab.ts      presa, colpetti e lanci (#109)
//   specials.ts  mosse speciali per personaggio (E10)
//   projectiles.ts  proiettili delle speciali (E10)
//   supreme.ts   barra della suprema (#101)
//   tech.ts      rialzata al volo dopo un colpo
//   companion.ts il compagno che segue il lottatore (#369)
//   arcade.ts    power-up Tetris e Pac-Man (#427)
//   timed.ts     pezzi a tempo e fasi dell'arena (#433)
//   stations.ts  postazioni: bombarda e munizioni (#433)
//   bassanese.ts il Bassanese chiamato col telefono

import { isArcade, playPacman, playTetris, stepArcade } from "./arcade";
import { resolveHits, tryStartAttack, updateAttack } from "./attacks";
import { stepBassanese } from "./bassanese";
import { stepCompanion } from "./companion";
import { applyJets, carryRider, resolveHazards } from "./elements";
import { pressPads } from "./pads";
import { tickBuffer, type Fighter, type PhysicsContext } from "./fighter";
import { grabbing, inGrab, resolveGrabs, stepGrabs } from "./grab";
import { swapTripInput, tickPowerup } from "./items";
import { holdLedge, remapLedges, tryGrabLedge } from "./ledge";
import { applyControls, applyGravity, startLanding, stepLag, tickCoyote } from "./movement";
import { holdShield } from "./shield";
import { stepProjectiles } from "./projectiles";
import { cancelSpecial, specialing } from "./specials";
import { endDash } from "./dash";
import { collideWithStage, liftOutOfZone, loseStock, outOfBlastZone, respawn } from "./stage";
export { platformSurfaceY } from "./stage";
import { burstFire, stepRewinds, supreming, tickSupreme, tryComboSupreme } from "./supreme";
import { landTech, tickTech } from "./tech";
import { stageAt } from "./timed";
import { freezePrize, stepStations, useStation } from "./stations";

export * from "./fighter";
export { resolveHits } from "./attacks";
export { floodPhase, hazardActive, hazardRect, jetPhase, moverHere, moverOn, moverPlace, moverPosition, padFx, travelDirection, travelPhase, type FloodPhase, type JetPhase, type TravelPhase } from "./elements";
export { swingAngle } from "./elements";
export { ledgesOf } from "./ledge";
export { baseStage, phaseAt, phaseIndexAt, pieceOn, stageAt, stageIsTimed } from "./timed";
export { freezePrize, prizeLeader } from "./stations";

// Un passo di simulazione per un lottatore (dtMs = durata del tick)
export function stepFighter(f: Fighter, dtMs: number, ctx: PhysicsContext): void {
  const dt = dtMs / 1000;

  if (f.eliminated) return;
  // Disconnesso con il posto tenuto (#107): fermo dov'è, intoccabile, nessun timer avanza
  if (f.away) {
    f.vx = f.vy = 0;
    f.attackActive = false;
    f.invulnerable = true;
    f.prevInput = f.input;
    return;
  }
  if (f.respawning) {
    cancelSpecial(f); // si rientra liberi, anche dopo essere usciti con uno scatto o caricando
    f.supremeTimer = 0;
    f.respawnTimer -= dtMs;
    if (f.respawnTimer <= 0) respawn(f, ctx);
    tickBuffer(f, dtMs); // un tasto premuto mentre si rientra non scatta molto dopo
    f.prevInput = f.input;
    return;
  }

  // L'ascensore porta anche chi è fermo per un colpo
  carryRider(f, dtMs, ctx);

  // Hitstop (#15): tutto resta fermo, timer compresi. prevInput non si aggiorna,
  // così un tasto premuto durante il fermo vale al primo passo dopo.
  if (f.hitstopTimer > 0) {
    f.hitstopTimer = Math.max(0, f.hitstopTimer - dtMs);
    return;
  }
  f.cooldownTimer = Math.max(0, f.cooldownTimer - dtMs);
  f.hitstunTimer = Math.max(0, f.hitstunTimer - dtMs);
  f.invulnerableTimer = Math.max(0, f.invulnerableTimer - dtMs);
  f.dropTimer = Math.max(0, f.dropTimer - dtMs);
  f.dodgeTimer = Math.max(0, f.dodgeTimer - dtMs);
  f.dodgeCooldown = Math.max(0, f.dodgeCooldown - dtMs);
  f.hazardTimer = Math.max(0, f.hazardTimer - dtMs);
  f.regrabTimer = Math.max(0, f.regrabTimer - dtMs);
  tickCoyote(f, dtMs);
  tickSupreme(f, dtMs); // #101: anche il tempo carica la barra
  tickTech(f, dtMs); // rialzata al volo: lo scudo premuto in volo da storditi
  tickBuffer(f, dtMs);
  f.hitstun = f.hitstunTimer > 0;
  tickPowerup(f, dtMs, ctx); // #231
  f.invulnerable = f.invulnerableTimer > 0 || (f.powerup === "fiore" && f.powerupMs > 0) || isArcade(f); // il bong (#302) non protegge
  // A Tetris (#427) si è assenti: fermi dove si era, i tasti guidano il pezzo
  if (f.powerup === "tetris") {
    f.vx = f.vy = 0;
    playTetris(f, dtMs, ctx);
    f.prevInput = f.input;
    return;
  }
  // Da Pac-Man (#427) niente controlli né gravità: si va dritti attraverso tutto
  if (f.powerup === "pacman") {
    playPacman(f, dtMs, ctx);
    f.prevInput = f.input;
    return;
  }
  // Alla postazione (#433) si sta fermi dove si è, e i tasti guidano la bombarda o le munizioni
  if (useStation(f, dtMs, ctx)) {
    if (outOfBlastZone(f, ctx)) loseStock(f, ctx); // una fase nuova può lasciarla fuori dall'arena
    f.prevInput = f.input;
    return;
  }
  if (f.hitstun) f.ledgeGrabs = 0; // un colpo ridà le prese del bordo (#110)

  // Nella presa (#109) si sta fermi: la posizione di chi è tenuto la decide stepGrabs
  if (inGrab(f)) {
    f.jumpRising = false;
    f.prevInput = f.input;
    return;
  }

  // Appesi al bordo si resta fermi: niente controlli, attacchi né gravità
  if (holdLedge(f, dtMs, ctx)) {
    f.jumpRising = false; // il salto dal bordo non si accorcia lasciando il tasto
    f.prevInput = f.input;
    return;
  }

  updateAttack(f, dtMs);
  burstFire(f, dtMs, ctx); // le raffiche di IRA di Lendmar (#358)
  // Suprema propria (#102): appesi alla liana, fermi dove si è
  if (supreming(f, dtMs)) {
    endDash(f); // la suprema ferma lo scatto (#199)
    f.jumpRising = false;
    f.prevInput = f.input;
    return;
  }
  tryComboSupreme(f, ctx); // Speciale + Pesante con la barra piena: anche sopra la speciale appena partita
  // Durante la presa, sullo scudo o storditi niente controlli né attacchi
  if (!grabbing(f, dtMs, ctx) && !specialing(f, dtMs, ctx) && !stepLag(f, dtMs, ctx) && !holdShield(f, dtMs, ctx)) {
    applyControls(f, dt, ctx);
    tryStartAttack(f, ctx);
  } else {
    endDash(f); // scudo, presa o speciale fermano lo scatto (#199)
    f.jumpRising = false; // il salto corto vale solo per la spinta del salto
  }
  applyGravity(f, dt);

  const prevY = f.y;
  const wasOnGround = f.onGround;
  f.x += f.vx * dt;
  f.y += f.vy * dt;

  collideWithStage(f, prevY, ctx, dtMs);
  if (f.onGround && !wasOnGround) startLanding(f); // #384 A3
  landTech(f, wasOnGround, ctx);

  if (f.onGround && f.hitstun) f.vx *= 0.8; // attrito quando si atterra stordito

  if (outOfBlastZone(f, ctx)) loseStock(f, ctx);

  f.prevInput = f.input;
}

// Un tick intero: l'arena va avanti, tutti si muovono, poi si risolvono i colpi e le trappole
// stageMs: quanto avanza l'arena (piattaforme, musica), che va a tempo vero anche quando il combattimento è rallentato
export function stepWorld(fighters: Fighter[], dtMs: number, ctx: PhysicsContext, stageMs = dtMs): void {
  ctx.timeMs = (ctx.timeMs ?? 0) + stageMs;
  // Pezzi a tempo e fasi (#433): da qui in poi ctx.stage è l'arena com'è adesso (la stessa, se non cambia)
  const view = stageAt(ctx.stage, ctx.timeMs, freezePrize(ctx));
  if (view !== ctx.stage) {
    const shrinks = view.blastZone.bottom < ctx.stage.blastZone.bottom;
    remapLedges(fighters, ctx.stage, view);
    ctx.stage = view;
    if (shrinks) liftOutOfZone(fighters, ctx); // la zuffa di Bologna stringe il fondo: chi è già sotto non è un KO
  }
  const firstEvent = ctx.events.length; // da qui gli eventi di questo tick (i bottoni sonori guardano gli atterraggi)
  stepGrabs(fighters, dtMs, ctx);
  const tripping = swapTripInput(fighters); // funghetti (#302): destra e sinistra invertite solo per il passo
  for (const f of fighters) stepFighter(f, dtMs, ctx);
  for (const f of tripping) f.powerup = "trip";
  swapTripInput(tripping);
  for (const f of tripping) if (f.powerupMs <= 0) f.powerup = null;
  for (const f of fighters) if (!f.away) tryGrabLedge(f, fighters, ctx);
  for (const f of fighters) stepCompanion(f, dtMs, ctx); // il beagle di Lampione (#369)
  resolveHits(fighters, ctx);
  stepProjectiles(fighters, dtMs, ctx);
  stepRewinds(fighters, dtMs, ctx); // …COSA? di Marcomunista (#358)
  resolveGrabs(fighters, ctx); // dopo i colpi: un colpo nello stesso tick vince sulla presa
  resolveHazards(fighters, ctx);
  applyJets(fighters, ctx, dtMs); // getti d'acqua (#253)
  pressPads(fighters, ctx, firstEvent); // bottoni sonori (#423)
  stepArcade(fighters, dtMs, ctx); // pezzi del Tetris e bocconi di Pac-Man (#427)
  stepBassanese(fighters, dtMs, ctx); // il Bassanese chiamato col telefono
  stepStations(fighters, dtMs, ctx, firstEvent); // postazioni e palle di mortadella (#433), dopo colpi e prese
}
