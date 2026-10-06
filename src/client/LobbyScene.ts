import Phaser from "phaser";
import { CHARACTERS, getCharacter, type CharacterSpec } from "../shared/characters";
import { WORLD } from "../shared/constants";
import { sanitizeRules } from "../shared/rules";
import { randomCourseId } from "../shared/courseGenerator";
import { randomStageId, seedFromStageId } from "../shared/stageGenerator";
import { getStage, STAGES, type StageSpec } from "../shared/stages";
import { openOptions } from "./OptionsPanel";
import { connect, randomRoom, roomLink, saveProfile, type JoinChoice } from "./network";

// Schermata iniziale: nome, stanza, personaggio e link da mandare agli amici.
// È fatta in HTML sopra il canvas: campi di testo e copia negli appunti
// funzionano meglio così che disegnati in Phaser.

const CSS = `
#lobby { position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; padding: 16px;
  background: radial-gradient(circle at 50% 30%, #2a3d52, #0d1520 70%); z-index: 10; overflow-y: auto; }
#lobby .card { width: min(520px, 100%); background: #16212ecc; border: 2px solid #3a5068; border-radius: 16px;
  padding: 24px; box-shadow: 0 20px 60px #0008; color: #eee; font-family: system-ui, sans-serif; }
#lobby h1 { margin: 0 0 4px; font-size: 40px; letter-spacing: 1px; color: #ffcf4a; text-shadow: 3px 3px 0 #7a3b00; }
#lobby .sub { margin: 0 0 20px; opacity: .7; }
#lobby label { display: block; font-size: 13px; text-transform: uppercase; letter-spacing: 1px; opacity: .8; margin: 14px 0 6px; }
#lobby input { width: 100%; box-sizing: border-box; padding: 10px 12px; font-size: 18px; border-radius: 8px;
  border: 2px solid #3a5068; background: #0d1520; color: #fff; }
#lobby input:focus { outline: none; border-color: #ffcf4a; }
#lobby .row { display: flex; gap: 8px; }
#lobby .row input { flex: 1; min-width: 0; }
#lobby button { padding: 10px 14px; font-size: 16px; border-radius: 8px; border: 0; cursor: pointer; background: #3a5068; color: #fff; }
#lobby button:hover { filter: brightness(1.2); }
#lobby .play { width: 100%; margin-top: 20px; padding: 14px; font-size: 22px; font-weight: bold; background: #e74c3c; }
#lobby .chars { display: flex; gap: 10px; flex-wrap: wrap; }
#lobby .char { width: 96px; padding: 8px; border-radius: 10px; background: #0d1520; border: 2px solid #3a5068; text-align: center; }
#lobby .char.sel { border-color: #ffcf4a; background: #2a2a10; }
#lobby .char .pic { width: 64px; height: 72px; margin: 0 auto 6px; background-repeat: no-repeat; image-rendering: pixelated; }
#lobby .char .box { width: 30px; height: 60px; margin: 6px auto 12px; border-radius: 4px; background: #e74c3c; }
#lobby .stages { display: flex; gap: 10px; flex-wrap: wrap; }
#lobby .stage { width: 140px; padding: 6px; border-radius: 10px; background: #0d1520; border: 2px solid #3a5068; text-align: center; font-size: 13px; }
#lobby .stage.sel { border-color: #ffcf4a; background: #2a2a10; }
#lobby .stage canvas { display: block; width: 128px; height: 72px; margin: 0 auto 4px; border-radius: 6px; }
#lobby .hint { text-transform: none; letter-spacing: 0; opacity: .6; }
#lobby .rules { display: grid; grid-template-columns: repeat(auto-fit, minmax(110px, 1fr)); gap: 8px; }
#lobby .rules select { width: 100%; padding: 8px; font-size: 15px; border-radius: 8px; border: 2px solid #3a5068; background: #0d1520; color: #fff; }
#lobby .rules .ff { display: flex; align-items: center; gap: 6px; font-size: 14px; margin: 0; text-transform: none; letter-spacing: 0; opacity: 1; }
#lobby .rules .ff input { width: auto; }
#lobby .foot { display: flex; justify-content: space-between; margin-top: 14px; font-size: 13px; opacity: .7; }
#lobby .foot span { display: flex; gap: 12px; }
#lobby .foot button { background: none; padding: 0; font-size: 13px; text-decoration: underline; color: #eee; }
#lobby .msg { min-height: 1.2em; font-size: 13px; color: #8fd18f; margin-top: 6px; }
`;

export interface LobbyData {
  defaults: Partial<JoinChoice>;
}

export class LobbyScene extends Phaser.Scene {
  private root?: HTMLDivElement;

  constructor() {
    super("lobby");
  }

  create(data: LobbyData) {
    const d = data.defaults ?? {};
    let characterId = getCharacter(d.characterId).id;
    const saved = getStage(d.stageId);
    let stageId = saved.goal ? getStage(undefined).id : saved.id; // i percorsi della Corsa non sono arene da scegliere

    if (!document.getElementById("lobby-style")) {
      const style = document.createElement("style");
      style.id = "lobby-style";
      style.textContent = CSS;
      document.head.append(style);
    }

    const root = document.createElement("div");
    root.id = "lobby";
    root.innerHTML = `
      <form class="card" autocomplete="off">
        <h1>BONOBO GAME</h1>
        <p class="sub">Il picchiaduro del nostro Discord</p>
        <label for="lobby-name">Nome</label>
        <input id="lobby-name" maxlength="16" required />
        <label for="lobby-room">Stanza</label>
        <div class="row">
          <input id="lobby-room" maxlength="24" required />
          <button type="button" data-act="random" title="Stanza nuova">🎲</button>
          <button type="button" data-act="copy">Copia link</button>
        </div>
        <div class="msg" data-msg></div>
        <label>Lottatore</label>
        <div class="chars" data-chars></div>
        <label data-stage-label>Arena <span class="hint">(la sceglie chi crea la stanza)</span></label>
        <div class="stages" data-stages></div>
        <p class="hint" data-course-note hidden>In Corsa si gioca su un percorso lungo, nuovo a ogni stanza: vince chi arriva prima al traguardo.</p>
        <label>Regole <span class="hint">(anche queste le sceglie chi crea la stanza)</span></label>
        <div class="rules">
          <select id="lobby-mode" title="Modalità">
            <option value="ffa">Tutti contro tutti</option>
            <option value="teams">Squadre</option>
            <option value="flag">Bandiera (a squadre)</option>
            <option value="race">Corsa (platformer)</option>
          </select>
          <select id="lobby-stocks" title="Vite">
            ${[1, 2, 3, 4, 5].map((n) => `<option value="${n}">${n} ${n === 1 ? "vita" : "vite"}</option>`).join("")}
          </select>
          <select id="lobby-time" title="Tempo">
            <option value="0">Senza tempo</option>
            <option value="120">2 minuti</option>
            <option value="180">3 minuti</option>
            <option value="300">5 minuti</option>
          </select>
          <label class="ff"><input type="checkbox" id="lobby-ff" /> Fuoco amico</label>
        </div>
        <button class="play" type="submit">Gioca</button>
        <div class="foot">
          <span>Mandate a tutti lo stesso link per giocare insieme</span>
          <span>
            <button type="button" data-act="options">Opzioni</button>
            <button type="button" data-act="credits" hidden>Crediti</button>
          </span>
        </div>
      </form>`;
    document.body.append(root);
    this.root = root;

    const $ = <T extends HTMLElement>(sel: string) => root.querySelector(sel) as T;
    const nameInput = $<HTMLInputElement>("#lobby-name");
    const roomInput = $<HTMLInputElement>("#lobby-room");
    const msg = $<HTMLDivElement>("[data-msg]");
    nameInput.value = d.name ?? "";
    const rules = sanitizeRules(d.rules);
    const modeSel = $<HTMLSelectElement>("#lobby-mode");
    const stocksSel = $<HTMLSelectElement>("#lobby-stocks");
    const timeSel = $<HTMLSelectElement>("#lobby-time");
    const ffBox = $<HTMLInputElement>("#lobby-ff");
    modeSel.value = rules.mode;
    stocksSel.value = String(Math.min(5, rules.stocks));
    timeSel.value = [0, 120, 180, 300].includes(rules.timeLimitSec) ? String(rules.timeLimitSec) : "0";
    ffBox.checked = rules.friendlyFire;
    // Il fuoco amico ha senso solo a squadre; in Bandiera le vite diventano i punti per vincere
    const syncFf = () => {
      const team = modeSel.value === "teams" || modeSel.value === "flag";
      ffBox.parentElement!.style.visibility = team ? "visible" : "hidden";
      // In Corsa le vite non contano e l'arena è un percorso generato
      const race = modeSel.value === "race";
      stocksSel.style.display = race ? "none" : "";
      for (const sel of ["[data-stage-label]", "[data-stages]"]) $<HTMLElement>(sel).style.display = race ? "none" : "";
      $<HTMLElement>("[data-course-note]").hidden = !race;
      const flag = modeSel.value === "flag";
      for (const o of stocksSel.options) o.text = `${o.value} ${flag ? (o.value === "1" ? "punto" : "punti") : o.value === "1" ? "vita" : "vite"}`;
    };
    modeSel.addEventListener("change", syncFf);
    syncFf();
    roomInput.value = d.room ?? randomRoom();

    // Un riquadro per ogni personaggio di characters.ts
    const chars = $<HTMLDivElement>("[data-chars]");
    const drawChars = () => {
      chars.replaceChildren(...Object.values(CHARACTERS).map((c) => charCard(c, c.id === characterId)));
    };
    chars.addEventListener("click", (e) => {
      const el = (e.target as HTMLElement).closest<HTMLButtonElement>("[data-char]");
      if (!el) return;
      characterId = el.dataset.char!;
      drawChars();
    });
    drawChars();

    // Le arene di stages.ts più una generata a caso: cliccandola di nuovo se ne genera un'altra
    const stages = $<HTMLDivElement>("[data-stages]");
    let randomId = seedFromStageId(stageId) !== null ? stageId : randomStageId();
    const drawStages = () => {
      const cards = Object.values(STAGES).map((st) => stageCard(st, st.id, st.name, st.id === stageId));
      cards.push(stageCard(getStage(randomId), randomId, "Casuale 🎲", randomId === stageId));
      stages.replaceChildren(...cards);
    };
    stages.addEventListener("click", (e) => {
      const el = (e.target as HTMLElement).closest<HTMLButtonElement>("[data-stage]");
      if (!el) return;
      if (el.dataset.stage === randomId && stageId === randomId) randomId = randomStageId();
      stageId = seedFromStageId(el.dataset.stage!) !== null ? randomId : el.dataset.stage!;
      drawStages();
    });
    drawStages();

    const cleanRoom = () => roomInput.value.toLowerCase().replace(/[^a-z0-9-]/g, "").slice(0, 24);

    root.addEventListener("click", async (e) => {
      const act = (e.target as HTMLElement).closest<HTMLElement>("[data-act]")?.dataset.act;
      if (act === "random") roomInput.value = randomRoom();
      if (act === "copy") {
        const link = roomLink(cleanRoom() || randomRoom());
        try {
          await navigator.clipboard.writeText(link);
          msg.textContent = "Link copiato: incollalo sul Discord";
        } catch {
          // Senza permesso per gli appunti (http, browser vecchi) lo mostriamo da copiare a mano
          msg.textContent = link;
        }
      }
      if (act === "credits") this.scene.start("credits");
      if (act === "options") openOptions();
    });

    // Il pulsante dei crediti compare quando esiste la loro scena (#24)
    if (this.scene.manager.keys["credits"]) $<HTMLButtonElement>('[data-act="credits"]').hidden = false;

    $<HTMLFormElement>("form").addEventListener("submit", (e) => {
      e.preventDefault();
      const choice: JoinChoice = {
        name: nameInput.value.trim().slice(0, 16) || "Bonobo",
        room: cleanRoom() || randomRoom(),
        characterId,
        stageId: modeSel.value === "race" ? randomCourseId() : stageId,
        rules: {
          mode: modeSel.value === "teams" || modeSel.value === "flag" || modeSel.value === "race" ? modeSel.value : "ffa",
          stocks: Number(stocksSel.value),
          timeLimitSec: Number(timeSel.value),
          friendlyFire: ffBox.checked,
        },
      };
      saveProfile(choice);
      this.scene.start("game", { socket: connect(), ...choice });
    });

    if (!nameInput.value) nameInput.focus();
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => this.removeDom());
    this.events.once(Phaser.Scenes.Events.DESTROY, () => this.removeDom());
  }

  private removeDom() {
    this.root?.remove();
    this.root = undefined;
  }
}

// Riquadro con il disegno in piccolo dell'arena
function stageCard(stage: StageSpec, id: string, label: string, selected: boolean): HTMLButtonElement {
  const el = document.createElement("button");
  el.type = "button";
  el.className = `stage${selected ? " sel" : ""}`;
  el.dataset.stage = id;
  const canvas = document.createElement("canvas");
  canvas.width = 256;
  canvas.height = 144;
  const g = canvas.getContext("2d");
  if (g) {
    const k = canvas.width / WORLD.width;
    const hex = (c: number) => `#${c.toString(16).padStart(6, "0")}`;
    g.fillStyle = hex(stage.colors.sky);
    g.fillRect(0, 0, canvas.width, canvas.height);
    g.fillStyle = hex(stage.colors.solid);
    for (const s of stage.solids) g.fillRect(s.x * k, s.y * k, s.width * k, s.height * k);
    g.fillStyle = hex(stage.colors.platform);
    for (const p of stage.platforms) g.fillRect(p.x * k, p.y * k, p.width * k, 3);
  }
  const name = document.createElement("div");
  name.textContent = label;
  el.append(canvas, name);
  return el;
}

function charCard(c: CharacterSpec, selected: boolean): HTMLButtonElement {
  const el = document.createElement("button");
  el.type = "button";
  el.className = `char${selected ? " sel" : ""}`;
  el.dataset.char = c.id;
  const pic = document.createElement("div");
  if (c.sprite) {
    // Primo fotogramma dello spritesheet, ridotto per stare nel riquadro
    const scale = Math.min(64 / c.sprite.frameWidth, 72 / c.sprite.frameHeight);
    pic.className = "pic";
    pic.style.backgroundImage = `url("${c.sprite.path}")`;
    pic.style.backgroundSize = `${c.sprite.columns * c.sprite.frameWidth * scale}px auto`;
    pic.style.width = `${c.sprite.frameWidth * scale}px`;
    pic.style.height = `${c.sprite.frameHeight * scale}px`;
  } else {
    pic.className = "box";
  }
  const name = document.createElement("div");
  name.textContent = c.name;
  el.append(pic, name);
  return el;
}
