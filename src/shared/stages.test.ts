import assert from "node:assert/strict";
import { existsSync, statSync } from "node:fs";
import { describe, it } from "node:test";
import { CHARACTERS, characterStats } from "./characters";
import { AUDIO, CAMERA, MAX_PLAYERS_PER_ROOM, TICK_RATE, WORLD } from "./constants";
import { createFighter, stepWorld, type PhysicsContext } from "./physics";
import { hazardActive, moverPosition } from "./physics/elements";
import { courseSteps, generateCourse } from "./courseGenerator";
import { generateStage, seedFromStageId } from "./stageGenerator";
import { JUMP_HEIGHT, reachable, SIDE_REACH, stageCheckData } from "./stageCheck";
import { CHORD_NAME, getStage, STAGE_MUSIC_LEADS, STAGES, stageArtFiles, stageWidth, type StageMusic, type StageSpec } from "./stages";

function checkStage(stage: StageSpec) {
  for (const p of [...stage.solids, ...stage.platforms]) {
    assert.ok(p.x >= 0 && p.x + p.width <= stageWidth(stage), `${stage.id}: dentro il mondo`);
    assert.ok(p.y > 0 && p.y < WORLD.height, `${stage.id}: altezza valida`);
  }
  if (!stage.goal) {
    for (const p of stage.platforms) assert.ok(reachable(stage, p), `${stage.id}: piattaforma a ${p.x},${p.y} irraggiungibile`);
  }
  assert.ok(stage.spawns.length >= MAX_PLAYERS_PER_ROOM, `${stage.id}: una partenza per giocatore`);
  assert.deepEqual(cameraProblems(stage), [], stage.id);
  // Piattaforme ad arco (#244): una curva dolce, che si cammina senza staccarsi (pendenza ai bordi al massimo 1:2)
  for (const p of stage.platforms) {
    if (p.arch !== undefined) assert.ok(p.arch > 0 && p.arch <= p.width / 8, `${stage.id}: arco di ${p.arch} troppo ripido per una piattaforma larga ${p.width}`);
    // Piattaforme inclinate (#246): al massimo ripide come una scala (1:1), e non anche ad arco
    if (p.y2 !== undefined) {
      assert.ok(p.arch === undefined, `${stage.id}: una piattaforma è ad arco o inclinata, non tutte e due`);
      assert.ok(Math.abs(p.y2 - p.y) <= p.width, `${stage.id}: rampa troppo ripida (${p.y} → ${p.y2} su ${p.width})`);
    }
  }

  // Chi parte da ogni punto di partenza resta fermo sul palco
  const ctx: PhysicsContext = { stage, events: [] };
  const fighters = stage.spawns.map((_, i) =>
    createFighter({ id: `p${i}`, name: "", characterId: "default", color: 0, team: 0, index: i, stocks: 3 }, stage),
  );
  for (let t = 0; t < 30; t++) stepWorld(fighters, 1000 / TICK_RATE, ctx);
  for (const f of fighters) assert.ok(f.onGround && !f.respawning, `${stage.id}: partenza ${f.id} sul palco`);
}

// La musica di un'arena (E12 passo 4): i problemi, uno per riga, o niente se il preset è valido
function musicProblems(music: StageMusic): string[] {
  const problems: string[] = [];
  if (!(music.bpm >= AUDIO.musicBpmMin && music.bpm <= AUDIO.musicBpmMax)) problems.push(`bpm ${music.bpm} fuori da ${AUDIO.musicBpmMin}-${AUDIO.musicBpmMax}`);
  if (music.chords.length < 1 || music.chords.length > 8) problems.push("da 1 a 8 accordi");
  for (const c of music.chords) if (!CHORD_NAME.test(c)) problems.push(`accordo "${c}" sconosciuto (es. "C", "F#", "Bbm")`);
  if (!STAGE_MUSIC_LEADS.includes(music.lead)) problems.push(`timbro "${music.lead}" sconosciuto`);
  return problems;
}

// Larghezza e zoom di un'arena (#240): i problemi, uno per riga, o niente
function cameraProblems(stage: StageSpec): string[] {
  const problems: string[] = [];
  if (stage.width !== undefined && stage.width < WORLD.width) problems.push(`width ${stage.width} più stretta dello schermo (${WORLD.width})`);
  const min = stage.camera?.minZoom ?? CAMERA.minZoom;
  const max = stage.camera?.maxZoom ?? CAMERA.maxZoom;
  if (min < CAMERA.stageMinZoomFloor) problems.push(`minZoom ${min} sotto ${CAMERA.stageMinZoomFloor}: lottatori troppo piccoli`);
  if (!(min <= max)) problems.push(`minZoom ${min} più grande di maxZoom ${max}`);
  return problems;
}

describe("arene", () => {
  it("i materiali e le decorazioni nominano solo cose che esistono (#237)", () => {
    for (const stage of Object.values(STAGES)) {
      const art = stage.art;
      if (!art) continue;
      const names = Object.keys(art.skins ?? {});
      const used = [art.solidSkin, art.platformSkin, ...(art.pieces?.solids ?? []), ...(art.pieces?.platforms ?? [])];
      for (const n of used) if (n) assert.ok(names.includes(n), `${stage.id}: materiale "${n}" non definito in skins`);
      assert.ok((art.pieces?.solids?.length ?? 0) <= stage.solids.length, `${stage.id}: più eccezioni che blocchi`);
      assert.ok((art.pieces?.platforms?.length ?? 0) <= stage.platforms.length, `${stage.id}: più eccezioni che piattaforme`);
      for (const p of art.props ?? []) assert.ok(p.opacity === undefined || (p.opacity >= 0 && p.opacity <= 1), `${stage.id}: opacità di ${p.file}`);
      // Animazioni delle trappole (#270): una trappola che esiste, fotogrammi e velocità sensati
      for (const h of art.hazardSprites ?? []) {
        assert.ok(Number.isInteger(h.hazard) && h.hazard >= 0 && h.hazard < (stage.hazards?.length ?? 0), `${stage.id}: ${h.file} per una trappola che non c'è`);
        assert.ok(Number.isInteger(h.frames) && h.frames >= 1 && h.fps > 0, `${stage.id}: fotogrammi e fps di ${h.file}`);
      }
      for (const m of art.moverSprites ?? []) {
        assert.ok(Number.isInteger(m.mover) && m.mover >= 0 && m.mover < (stage.movers?.length ?? 0), `${stage.id}: ${m.file} per una piattaforma mobile che non c'è`);
        assert.ok(Number.isInteger(m.frames) && m.frames >= 1 && m.fps > 0, `${stage.id}: fotogrammi e fps di ${m.file}`);
      }
      // Sfondo vivo (#260): parallassi tra 0 e 1, tempi positivi
      const life = art.life;
      for (const e of [life?.birds, life?.walkers, life?.vehicles, life?.traffic, life?.flyers, life?.bar, ...(life?.daycycle?.lamps ?? [])]) {
        if (e) assert.ok(e.parallax >= 0 && e.parallax <= 1, `${stage.id}: parallasse dello sfondo vivo tra 0 e 1`);
      }
      for (const ms of [life?.birds?.everyMs, life?.vehicles?.everyMs, life?.traffic?.everyMs, life?.planes?.everyMs, life?.daycycle?.cycleMs]) {
        if (life?.daycycle?.startAt !== undefined) assert.ok(life.daycycle.startAt >= 0 && life.daycycle.startAt < 1, `${stage.id}: startAt tra 0 e 1`);
        if (ms !== undefined) assert.ok(ms > 0, `${stage.id}: tempi dello sfondo vivo positivi`);
      }
      if (life?.vehicles) assert.ok(life.vehicles.everyMs > 12000, `${stage.id}: il veicolo impiega 12 s a passare, everyMs deve essere di più`);
      // #278: il traffico ha almeno un tipo e non si accalca; il bar ha almeno un tavolino
      if (life?.traffic) assert.ok(life.traffic.kinds.length > 0 && life.traffic.everyMs >= 1000, `${stage.id}: tipi del traffico e un veicolo al massimo al secondo`);
      if (life?.planes) assert.ok(life.planes.everyMs > 40000, `${stage.id}: l'aereo impiega 40 s a passare, everyMs deve essere di più`);
      if (life?.flyers) assert.ok(Number.isInteger(life.flyers.count) && life.flyers.count > 0, `${stage.id}: quanti uccelli vicini`);
      if (life?.bar) assert.ok(Number.isInteger(life.bar.tables) && life.bar.tables > 0 && life.bar.spacing > 0, `${stage.id}: tavolini del bar`);
    }
  });

  it("le arene fatte a mano sono valide", () => {
    for (const stage of Object.values(STAGES)) checkStage(stage);
  });

  it("un'arena più larga dello schermo, con il suo zoom, è valida (#240)", () => {
    const wide: StageSpec = {
      ...STAGES.palco,
      id: "larga",
      width: 1920,
      camera: { minZoom: 0.6 },
      solids: [{ x: 100, y: 560, width: 1720, height: 80 }],
      platforms: [{ x: 1500, y: 420, width: 200 }],
      spawns: [0.1, 0.9, 0.3, 0.7, 0.2, 0.8, 0.4, 0.6].map((f) => ({ x: 100 + 1720 * f, y: 560 })),
      blastZone: { left: -300, right: 2220, top: -420, bottom: 1000 },
    };
    checkStage(wide);
    assert.deepEqual(cameraProblems({ ...wide, camera: { minZoom: 0.2 } }).length, 1, "zoom troppo lontano");
    assert.deepEqual(cameraProblems({ ...wide, width: 900 }).length, 1, "più stretta dello schermo");
  });

  it("la musica delle arene è un preset valido, e almeno due arene ne hanno una (E12)", () => {
    const withMusic = Object.values(STAGES).filter((s) => s.music);
    assert.ok(withMusic.length >= 2);
    for (const stage of withMusic) assert.deepEqual(musicProblems(stage.music!), [], stage.id);
  });

  it("gli sfondi delle arene ci sono e restano leggeri (E12)", () => {
    const MAX_BYTES = 4 * 1024 * 1024; // per arena, per non appesantire la versione web (rischi in E12)
    const withArt = [...Object.values(STAGES), generateStage(1)].filter((s) => s.art);
    assert.ok(withArt.length >= 1, "almeno Il Palco ha uno sfondo");
    for (const stage of withArt) {
      const art = stage.art!;
      assert.ok(art.layers.length >= 1, `${stage.id}: almeno uno strato`);
      const layers = [...art.layers, ...(art.foreground ? [art.foreground] : [])];
      for (const l of layers) assert.ok(l.parallax >= 0 && l.parallax <= 1, `${stage.id}: parallasse di ${l.file} tra 0 e 1`);
      const v = art.verticalParallax ?? 1; // #400
      assert.ok(v >= 0 && v <= 1, `${stage.id}: parallasse verticale tra 0 e 1`);
      let bytes = 0;
      for (const file of stageArtFiles(art)) { // con materiali e decorazioni (#237)
        const dir = art.dir ?? stage.id;
        const url = new URL(`../../public/assets/stages/${dir}/${file}`, import.meta.url);
        assert.ok(existsSync(url), `${stage.id}: manca public/assets/stages/${dir}/${file}`);
        bytes += statSync(url).size;
      }
      assert.ok(bytes <= MAX_BYTES, `${stage.id}: sfondo di ${(bytes / 1048576).toFixed(1)} MB, oltre i 4 MB`);
    }
  });

  it("il controllo della musica se ne accorge davvero (E12)", () => {
    assert.equal(musicProblems({ bpm: 300, chords: ["H", "Am"], lead: "square" }).length, 2);
    assert.equal(musicProblems({ bpm: 120, chords: [], lead: "organo" as never }).length, 2);
    assert.deepEqual(musicProblems({ bpm: 120, chords: ["C#m", "Bb", "F"], lead: "sine" }), []);
  });

  it("ogni personaggio raggiunge tutte le piattaforme delle arene fatte a mano (E11)", () => {
    for (const id of Object.keys(CHARACTERS)) {
      const { jump, gravity } = characterStats(id);
      for (const stage of Object.values(STAGES)) {
        if (stage.goal) continue;
        for (const p of stage.platforms) assert.ok(reachable(stage, p, (jump * jump) / gravity), `${id} su ${stage.id}: piattaforma a ${p.x},${p.y} irraggiungibile`);
      }
    }
  });

  it("un'arena generata è sempre la stessa per lo stesso seme", () => {
    assert.deepEqual(generateStage(1234), generateStage(1234));
    assert.notDeepEqual(generateStage(1), generateStage(2));
  });

  it("le arene generate sono giocabili", () => {
    for (let seed = 0; seed < 300; seed++) checkStage(generateStage(seed));
  });

  it("getStage riconosce gli id", () => {
    assert.equal(getStage(undefined).id, "palco");
    assert.equal(getStage("non-esiste").id, "palco");
    assert.equal(getStage("isole").id, "isole");
    assert.equal(getStage("casuale-42").id, "casuale-42");
    assert.equal(seedFromStageId("casuale-abc"), null);
  });

  it("i percorsi della Corsa si fanno tutti saltando da un appoggio al successivo", () => {
    for (let seed = 0; seed < 300; seed++) {
      const stage = generateCourse(seed);
      checkStage(stage);
      const steps = courseSteps(stage);
      for (let i = 1; i < steps.length; i++) {
        const [a, b] = [steps[i - 1], steps[i]];
        const gap = b.x - (a.x + a.width);
        assert.ok(gap > 0 && gap <= SIDE_REACH, `${stage.id}: salto ${i} lungo ${gap}`);
        assert.ok(a.y - b.y <= JUMP_HEIGHT * 0.8, `${stage.id}: salto ${i} alto ${a.y - b.y}`);
      }
      const goal = stage.goal!;
      const end = steps[steps.length - 1];
      assert.ok(end.solid && goal.x >= end.x && goal.x + goal.width <= end.x + end.width, `${stage.id}: traguardo sull'ultimo blocco`);
      assert.ok(stageWidth(stage) > WORLD.width * 4, `${stage.id}: lungo qualche schermo`);
      assert.ok(stage.checkpoints!.length >= 3, `${stage.id}: checkpoint`);
      assert.deepEqual(stage.checkpoints!.map((c) => c.x), [...stage.checkpoints!.map((c) => c.x)].sort((x, y) => x - y));
    }
    assert.deepEqual(generateCourse(7), generateCourse(7));
    assert.equal(getStage("corsa-7").id, "corsa-7");
  });

  // Un "giocatore" che va verso l'appoggio successivo e salta al bordo arriva in fondo:
  // la prova vera che i salti misurati sopra si fanno con la fisica del gioco
  it("un giocatore che corre e salta ai bordi arriva al traguardo", () => {
    for (let seed = 0; seed < 200; seed++) {
      const stage = generateCourse(seed);
      const steps = courseSteps(stage);
      const ctx: PhysicsContext = { stage, events: [], unlimitedStocks: true };
      const f = createFighter({ id: "a", name: "", characterId: "default", color: 0, team: 0, index: 0, stocks: 3 }, stage);
      let on = 0; // appoggio su cui si trova (o da cui è saltato)
      let falls = 0;
      for (let t = 0; t < TICK_RATE * 90 && f.x < stage.goal!.x; t++) {
        if (f.onGround) on = Math.max(0, steps.findIndex((s) => f.x + 30 > s.x && f.x - 30 < s.x + s.width && s.y === f.y));
        const here = steps[on];
        const next = steps[on + 1] ?? here;
        let right = true;
        let left = false;
        let up = false;
        if (f.onGround) {
          up = here.x + here.width - f.x < 24 || (next.y < f.y && next.x - f.x < 50);
        } else {
          // In aria si punta il centro dell'appoggio dopo, con il doppio salto se si scende troppo presto
          const aim = next.x + Math.min(next.width / 2, 60);
          right = f.x < aim;
          left = f.x > aim + 40;
          up = f.vy > 0 && f.jumpsLeft > 0 && f.y > next.y - 20 && f.x < next.x;
        }
        // Il salto si tiene mentre si sale, come una persona: un tocco solo farebbe il salto corto
        f.input = { ...f.input, right, left, jump: (up && !f.prevInput.jump) || f.jumpRising };
        stepWorld([f], 1000 / TICK_RATE, ctx);
        if (ctx.events.some((e) => e.type === "ko")) falls++;
        ctx.events = [];
      }
      assert.ok(f.x >= stage.goal!.x, `corsa-${seed}: arrivato a ${Math.round(f.x)} di ${stage.goal!.x}, cadute ${falls}`);
    }
  });

  // L'editor sul sito (E12) è JavaScript senza tipi: lo si carica a runtime, per questo è any
  const loadEditor = (): Promise<any> => import(new URL("../../site/editor/arena.js", import.meta.url).href);

  it("l'editor delle arene fa lo stesso controllo di raggiungibilità dei test (E12)", async () => {
    const editor = await loadEditor();
    const check = stageCheckData();
    const stages = [...Object.values(STAGES), ...Array.from({ length: 100 }, (_, seed) => generateStage(seed))];
    for (const stage of stages) {
      // Ogni piattaforma, anche spostata più in alto, dà la stessa risposta
      for (const p of stage.platforms) {
        for (const dy of [0, 60, 120, 200]) {
          const q = { ...p, y: p.y - dy };
          assert.equal(editor.reachable(stage, q, check), reachable(stage, q), `${stage.id}: ${q.x},${q.y}`);
        }
      }
    }
  });

  it("un'arena copiata dall'editor si incolla in stages.ts e passa i controlli (E12)", async () => {
    const editor = await loadEditor();
    for (const base of [...Object.values(STAGES), generateStage(3), generateStage(17)]) {
      const model = { ...base, id: "nuova", name: "Nuova arena" };
      const spec = editor.toStageSpec(model);
      assert.deepEqual(editor.problems(spec, stageCheckData(), Object.keys(STAGES)), [], base.id);
      // Il testo copiato, valutato come in stages.ts, ridà la stessa arena
      const text: string = editor.toStagesTs(spec);
      const pasted = new Function("WORLD", `return {${text}}`)(WORLD) as Record<string, StageSpec>;
      assert.deepEqual(pasted.nuova, spec);
      checkStage(pasted.nuova);
    }
  });

  it("l'editor segnala le piattaforme irraggiungibili e le partenze impossibili (E12)", async () => {
    const editor = await loadEditor();
    const palco = STAGES.palco;
    const high = editor.toStageSpec({ ...palco, id: "alta", platforms: [...palco.platforms, { x: 100, width: 100, y: 60 }] });
    assert.equal(editor.problems(high, stageCheckData()).length, 1);
    const lopsided = editor.toStageSpec({ ...palco, id: "storta", solids: [{ x: 0, y: 560, width: 500, height: 80 }] });
    assert.deepEqual(lopsided.spawns, []);
    assert.equal(editor.slug("La Città Più Bella!"), "la-citta-piu-bella");
  });

  it("l'editor muove ascensori e accende trappole come la fisica (E12)", async () => {
    const editor = await loadEditor();
    const { movers = [], hazards = [] } = STAGES.fabbrica;
    const loop = { width: 100, path: [{ x: 0, y: 0 }, { x: 300, y: 0 }, { x: 300, y: 200 }], periodMs: 5000, pauseMs: 300, loop: true, offsetMs: 700 };
    for (let t = -3000; t < 20000; t += 137) {
      for (const m of [...movers, loop]) assert.deepEqual(editor.moverPosition(m, t), moverPosition(m, t));
      for (const h of hazards) assert.equal(editor.hazardActive(h, t), hazardActive(h, t));
    }
  });

  it("Proponi apre il modulo Arena nuova con i dati dell'arena (E12)", async () => {
    const editor = await loadEditor();
    const spec = editor.toStageSpec({ ...STAGES.fabbrica, id: "nuova", name: "Il Cantiere" });
    const url = new URL(editor.proposeUrl(spec));
    assert.equal(url.pathname, "/nicpanozzo/bonobo-game/issues/new");
    assert.equal(url.searchParams.get("template"), "arena.yml");
    assert.equal(url.searchParams.get("nome"), "Il Cantiere");
    assert.deepEqual(JSON.parse(url.searchParams.get("dati")!), spec);
    assert.ok(url.href.length < 8000, "sta in un indirizzo");
  });
});
