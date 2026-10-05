// Il sacco da allenamento: una versione giocattolo delle regole del gioco, solo nel browser.
// I numeri sono copiati da src/shared/constants.ts della PR #10: se cambiano là, aggiornali qui.
// Non è il gioco vero: niente rete, un solo giocatore, fisica semplificata.

const WORLD = { width: 1280, height: 720 };
const STAGE = { x: 240, width: 800, y: 560, thickness: 80 };
const PLATFORMS = [
  { x: 340, width: 200, y: 420 },
  { x: 740, width: 200, y: 420 },
  { x: 540, width: 200, y: 290 },
];
const BLAST_ZONE = { left: -250, right: WORLD.width + 250, top: -350, bottom: WORLD.height + 200 };
const FIGHTER = {
  width: 44, height: 88,
  groundSpeed: 380, airSpeed: 340, airAccel: 2400, airFriction: 1200, // pixel/s e pixel/s²
  jumpSpeed: 860, doubleJumpSpeed: 780, maxJumps: 2,
  gravity: 2300, maxFallSpeed: 950, fastFallSpeed: 1500,
  dropThroughMs: 200,
};
const ATTACKS = {
  light: { damage: 5, baseKnockback: 260, knockbackGrowth: 5, startupMs: 40, activeMs: 100, cooldownMs: 280, range: 52, height: 30, angleDeg: 35 },
  heavy: { damage: 13, baseKnockback: 420, knockbackGrowth: 11, startupMs: 260, activeMs: 120, cooldownMs: 750, range: 70, height: 44, angleDeg: 42 },
};
const HITSTUN_PER_KNOCKBACK = 0.35; // ms per pixel/s
const HITSTUN_AIR_DRAG = 0.985; // per tick a 60 Hz
const RESPAWN_POINT = { x: WORLD.width / 2, y: 160 };
const PIXELS_PER_METER = 40; // solo per dare un numero simpatico al lancio
const RECORD_KEY = 'bonobo-sacco-record';

const KEYMAP = {
  KeyA: 'left', ArrowLeft: 'left', KeyD: 'right', ArrowRight: 'right',
  KeyW: 'jump', ArrowUp: 'jump', Space: 'jump', KeyS: 'down', ArrowDown: 'down',
  KeyJ: 'light', KeyK: 'heavy',
};

function createBody(x) {
  return { x, y: STAGE.y, vx: 0, vy: 0, onGround: true, jumpsLeft: FIGHTER.maxJumps, facing: 1, dropTimer: 0, hitstun: 0, attack: null, cooldown: 0, percent: 0 };
}

function surfaces(body) {
  const list = [{ x: STAGE.x, width: STAGE.width, y: STAGE.y }];
  if (body.dropTimer <= 0) list.push(...PLATFORMS);
  return list;
}

function onPlatform(body) {
  return PLATFORMS.some((p) => body.y === p.y && body.x >= p.x && body.x <= p.x + p.width);
}

// Gravità, movimento e atterraggio, uguale per giocatore e sacco
function integrate(body, dt, fastFall) {
  const dtMs = dt * 1000;
  body.dropTimer = Math.max(0, body.dropTimer - dtMs);
  if (body.hitstun > 0) {
    body.hitstun = Math.max(0, body.hitstun - dtMs);
    body.vx *= HITSTUN_AIR_DRAG ** (dt * 60);
  }
  const maxFall = fastFall ? FIGHTER.fastFallSpeed : FIGHTER.maxFallSpeed;
  body.vy = Math.min(body.vy + FIGHTER.gravity * dt, Math.max(body.vy, maxFall));
  const prevY = body.y;
  body.x += body.vx * dt;
  body.y += body.vy * dt;
  body.onGround = false;
  if (body.vy >= 0) {
    for (const s of surfaces(body)) {
      if (prevY <= s.y && body.y >= s.y && body.x >= s.x && body.x <= s.x + s.width) {
        body.y = s.y;
        body.vy = 0;
        body.onGround = true;
        body.jumpsLeft = FIGHTER.maxJumps;
        if (body.hitstun > 0) body.vx *= 0.5; // atterrare spegne un po' il volo
        break;
      }
    }
  }
}

function outOfBlastZone(body) {
  return body.x < BLAST_ZONE.left || body.x > BLAST_ZONE.right || body.y < BLAST_ZONE.top || body.y > BLAST_ZONE.bottom;
}

function attackBox(f) {
  const spec = ATTACKS[f.attack.kind];
  const x = f.facing === 1 ? f.x + FIGHTER.width / 2 : f.x - FIGHTER.width / 2 - spec.range;
  return { x, y: f.y - FIGHTER.height * 0.7, w: spec.range, h: spec.height };
}

function bodyBox(f) {
  return { x: f.x - FIGHTER.width / 2, y: f.y - FIGHTER.height, w: FIGHTER.width, h: FIGHTER.height };
}

function overlap(a, b) {
  return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
}

export function startDemo(canvas) {
  const ctx = canvas.getContext('2d');
  const scale = canvas.width / WORLD.width;
  const hud = {
    pct: document.getElementById('bag-pct'),
    kos: document.getElementById('bag-kos'),
    record: document.getElementById('bag-record'),
  };
  canvas.tabIndex = 0;

  const input = { left: false, right: false, jump: false, down: false, light: false, heavy: false };
  const prev = { ...input };
  const player = createBody(460);
  const bag = createBody(820);
  bag.facing = -1;
  const popups = []; // scritte che salgono e svaniscono
  let kos = 0;
  let record = 0;
  try {
    record = Number(localStorage.getItem(RECORD_KEY)) || 0;
  } catch {
    // niente localStorage: il record vale solo per questa visita
  }

  function popup(text, x, y, color) {
    popups.push({ text, x, y, color, life: 1 });
  }

  function updateHud() {
    hud.pct.textContent = `${Math.round(bag.percent)}%`;
    hud.kos.textContent = String(kos);
    hud.record.textContent = `${record.toFixed(1)} m`;
  }

  // ---- input da tastiera, solo quando il riquadro ha il focus, così la pagina scorre normalmente
  canvas.addEventListener('keydown', (e) => {
    const key = KEYMAP[e.code];
    if (!key) return;
    e.preventDefault();
    input[key] = true;
  });
  canvas.addEventListener('keyup', (e) => {
    const key = KEYMAP[e.code];
    if (key) input[key] = false;
  });
  canvas.addEventListener('blur', () => Object.keys(input).forEach((k) => (input[k] = false)));
  canvas.addEventListener('pointerdown', () => canvas.focus());

  // ---- input touch: dopo il primo tocco il riquadro resta "attivo" anche tra un tasto e l'altro
  let touched = false;
  for (const button of document.querySelectorAll('.touch button')) {
    const key = button.dataset.key;
    const set = (on) => (e) => {
      e.preventDefault();
      input[key] = on;
      if (on) touched = true;
      button.classList.toggle('on', on);
    };
    button.addEventListener('pointerdown', set(true));
    button.addEventListener('pointerup', set(false));
    button.addEventListener('pointercancel', set(false));
    button.addEventListener('pointerleave', set(false));
  }

  const pressed = (k) => input[k] && !prev[k];

  function stepPlayer(dt) {
    const f = player;
    f.cooldown = Math.max(0, f.cooldown - dt * 1000);
    if (f.attack) f.attack.t += dt * 1000;
    if (f.attack && f.attack.t > ATTACKS[f.attack.kind].startupMs + ATTACKS[f.attack.kind].activeMs) f.attack = null;

    const dir = (input.right ? 1 : 0) - (input.left ? 1 : 0);
    if (f.hitstun <= 0) {
      if (dir !== 0 && !f.attack) f.facing = dir;
      if (f.onGround) {
        f.vx = dir * FIGHTER.groundSpeed;
      } else if (dir !== 0) {
        f.vx = Math.max(-FIGHTER.airSpeed, Math.min(FIGHTER.airSpeed, f.vx + dir * FIGHTER.airAccel * dt));
      } else {
        const slow = FIGHTER.airFriction * dt;
        f.vx = Math.abs(f.vx) <= slow ? 0 : f.vx - Math.sign(f.vx) * slow;
      }
      if (pressed('jump') && f.jumpsLeft > 0) {
        f.vy = -(f.onGround ? FIGHTER.jumpSpeed : FIGHTER.doubleJumpSpeed);
        f.jumpsLeft -= 1;
        f.onGround = false;
      }
      if (pressed('down') && f.onGround && onPlatform(f)) {
        f.dropTimer = FIGHTER.dropThroughMs;
        f.y += 1;
        f.onGround = false;
      }
      for (const kind of ['light', 'heavy']) {
        if (pressed(kind) && f.cooldown <= 0) {
          f.attack = { kind, t: 0, hit: false };
          f.cooldown = ATTACKS[kind].cooldownMs;
        }
      }
    }
    integrate(f, dt, input.down && !f.onGround && f.vy > 0);
    if (outOfBlastZone(f)) {
      Object.assign(f, createBody(RESPAWN_POINT.x), { y: RESPAWN_POINT.y, onGround: false });
      popup('Ops!', RESPAWN_POINT.x, RESPAWN_POINT.y - 120, '#a9bdb1');
    }
  }

  function resolveHit() {
    const a = player.attack;
    if (!a || a.hit) return;
    const spec = ATTACKS[a.kind];
    if (a.t < spec.startupMs || a.t > spec.startupMs + spec.activeMs) return;
    if (!overlap(attackBox(player), bodyBox(bag))) return;
    a.hit = true;
    // Stessa formula del gioco: il danno si aggiunge prima, poi più percentuale = più volo
    bag.percent = Math.min(999, bag.percent + spec.damage);
    const knockback = spec.baseKnockback + spec.knockbackGrowth * bag.percent;
    const angle = (spec.angleDeg * Math.PI) / 180;
    bag.vx = player.facing * Math.cos(angle) * knockback;
    bag.vy = -Math.sin(angle) * knockback;
    bag.onGround = false;
    bag.hitstun = knockback * HITSTUN_PER_KNOCKBACK;
    const meters = knockback / PIXELS_PER_METER;
    popup(a.kind === 'heavy' ? 'POW!' : 'pam', bag.x, bag.y - FIGHTER.height - 20, a.kind === 'heavy' ? '#f7c948' : '#f3f1e7');
    if (meters > record) {
      record = meters;
      try {
        localStorage.setItem(RECORD_KEY, String(record));
      } catch {
        // vedi sopra
      }
    }
    updateHud();
  }

  function stepBag(dt) {
    integrate(bag, dt, false);
    // Il sacco a terra si ferma piano
    if (bag.onGround && bag.hitstun <= 0) bag.vx *= 0.8 ** (dt * 60);
    if (outOfBlastZone(bag)) {
      kos += 1;
      const x = Math.max(40, Math.min(WORLD.width - 40, bag.x));
      const y = Math.max(60, Math.min(WORLD.height - 40, bag.y));
      popup('FUORI!', x, y, '#e74c3c');
      Object.assign(bag, createBody(RESPAWN_POINT.x + 200), { y: RESPAWN_POINT.y, onGround: false, facing: -1 });
      updateHud();
    }
  }

  // ---- disegno

  function drawBody(f, color, isBag) {
    const b = bodyBox(f);
    ctx.fillStyle = color;
    if (isBag) {
      ctx.beginPath();
      ctx.roundRect(b.x - 4, b.y, b.w + 8, b.h, 18);
      ctx.fill();
      ctx.strokeStyle = '#6b4f2a';
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.moveTo(b.x, b.y + 24);
      ctx.lineTo(b.x + b.w, b.y + 24);
      ctx.moveTo(b.x, b.y + b.h - 24);
      ctx.lineTo(b.x + b.w, b.y + b.h - 24);
      ctx.stroke();
      ctx.fillStyle = '#f3f1e7';
      ctx.font = 'bold 30px Bungee, Impact, sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText(`${Math.round(f.percent)}%`, f.x, b.y - 14);
      return;
    }
    ctx.beginPath();
    ctx.roundRect(b.x, b.y, b.w, b.h, 10);
    ctx.fill();
    // occhi che guardano dove si colpisce
    ctx.fillStyle = '#fff';
    const eyeX = f.x + f.facing * 8;
    ctx.fillRect(eyeX - 10, b.y + 16, 8, 10);
    ctx.fillRect(eyeX + 2, b.y + 16, 8, 10);
    if (f.attack) {
      const spec = ATTACKS[f.attack.kind];
      const active = f.attack.t >= spec.startupMs;
      const box = attackBox(f);
      ctx.fillStyle = active ? 'rgba(247, 201, 72, .85)' : 'rgba(247, 201, 72, .25)';
      ctx.beginPath();
      ctx.roundRect(box.x, box.y, box.w, box.h, 8);
      ctx.fill();
    }
  }

  function draw(focused) {
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.fillStyle = '#0b1612';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.setTransform(scale, 0, 0, scale, 0, 0);

    // palco e piattaforme
    ctx.fillStyle = '#2f5442';
    ctx.beginPath();
    ctx.roundRect(STAGE.x, STAGE.y, STAGE.width, STAGE.thickness, 12);
    ctx.fill();
    ctx.fillStyle = '#4b7d63';
    for (const p of PLATFORMS) {
      ctx.beginPath();
      ctx.roundRect(p.x, p.y, p.width, 10, 5);
      ctx.fill();
    }

    drawBody(bag, '#c8a165', true);
    drawBody(player, '#e74c3c', false);

    ctx.textAlign = 'center';
    for (const p of popups) {
      ctx.globalAlpha = Math.max(0, p.life);
      ctx.fillStyle = p.color;
      ctx.font = '36px Bungee, Impact, sans-serif';
      ctx.fillText(p.text, p.x, p.y);
    }
    ctx.globalAlpha = 1;

    if (!focused) {
      ctx.fillStyle = 'rgba(11, 22, 18, .55)';
      ctx.fillRect(0, 0, WORLD.width, WORLD.height);
      ctx.fillStyle = '#f7c948';
      ctx.font = '44px Bungee, Impact, sans-serif';
      ctx.fillText(matchMedia('(pointer: coarse)').matches ? 'Usa i tasti qui sotto' : 'Clicca qui per giocare', WORLD.width / 2, 250);
      ctx.fillStyle = '#f3f1e7';
      ctx.font = '26px Nunito, sans-serif';
      ctx.fillText('A D muovi · W salta · J leggero · K pesante', WORLD.width / 2, 300);
    }
  }

  // ---- ciclo: fisica a passo fisso 60 Hz come sul server, disegno a ogni frame
  const STEP = 1 / 60;
  let acc = 0;
  let last = performance.now();
  let visible = true;
  new IntersectionObserver(([entry]) => (visible = entry.isIntersecting)).observe(canvas);

  function frame(now) {
    acc = Math.min(acc + (now - last) / 1000, 0.25);
    last = now;
    if (visible) {
      while (acc >= STEP) {
        stepPlayer(STEP);
        resolveHit();
        stepBag(STEP);
        Object.assign(prev, input);
        for (const p of popups) {
          p.life -= STEP * 1.2;
          p.y -= 60 * STEP;
        }
        acc -= STEP;
      }
      while (popups.length && popups[0].life <= 0) popups.shift();
      draw(document.activeElement === canvas || touched);
    } else {
      acc = 0;
    }
    requestAnimationFrame(frame);
  }

  updateHud();
  requestAnimationFrame(frame);
}
