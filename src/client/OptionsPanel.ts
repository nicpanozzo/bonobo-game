import { keyLabel } from "./input";
import { ACTIONS, getSettings, resetSettings, updateSettings, type Action, type Bindings } from "./settings";

// Il menu opzioni, in HTML sopra il gioco: lo aprono la lobby e il menu di pausa.

const LABELS: Record<Action, string> = {
  left: "Sinistra",
  right: "Destra",
  up: "Salto",
  down: "Giù / scendi",
  light: "Attacco leggero",
  heavy: "Attacco pesante",
  taunt: "Provocazione",
};

const SLOTS = 2; // tasti per azione mostrati nel menu

const CSS = `
.ui-overlay { position: fixed; inset: 0; z-index: 30; display: flex; align-items: center; justify-content: center; padding: 16px;
  background: #000a; font-family: system-ui, sans-serif; color: #eee; overflow-y: auto; }
.ui-card { width: min(560px, 100%); max-height: calc(100vh - 32px); overflow-y: auto; box-sizing: border-box; background: #16212e;
  border: 2px solid #3a5068; border-radius: 16px; padding: 20px 24px; box-shadow: 0 20px 60px #000a; }
.ui-card h2 { margin: 0 0 12px; color: #ffcf4a; }
.ui-card h3 { margin: 18px 0 8px; font-size: 13px; text-transform: uppercase; letter-spacing: 1px; opacity: .8; }
.ui-card button { padding: 8px 12px; font-size: 15px; border-radius: 8px; border: 0; cursor: pointer; background: #3a5068; color: #fff; }
.ui-card button:hover { filter: brightness(1.2); }
.ui-card .primary { background: #e74c3c; font-weight: bold; }
.ui-row { display: grid; grid-template-columns: 140px 1fr 44px; align-items: center; gap: 10px; margin: 6px 0; }
.ui-row input[type=range] { width: 100%; }
.ui-keys { display: grid; grid-template-columns: 140px repeat(${SLOTS}, 1fr); gap: 6px 10px; align-items: center; }
.ui-keys button { min-width: 0; background: #0d1520; border: 2px solid #3a5068; }
.ui-keys button.wait { border-color: #ffcf4a; color: #ffcf4a; }
.ui-actions { display: flex; justify-content: space-between; gap: 8px; margin-top: 20px; flex-wrap: wrap; }
.ui-menu { display: flex; flex-direction: column; gap: 10px; }
.ui-menu button { padding: 12px; font-size: 18px; }
.ui-note { font-size: 13px; opacity: .7; margin: 8px 0 0; }
`;

export function ensureUiStyle() {
  if (document.getElementById("ui-style")) return;
  const style = document.createElement("style");
  style.id = "ui-style";
  style.textContent = CSS;
  document.head.append(style);
}

export function openOptions(onClose?: () => void) {
  ensureUiStyle();
  const root = document.createElement("div");
  root.className = "ui-overlay";
  root.innerHTML = `
    <div class="ui-card" role="dialog" aria-label="Opzioni">
      <h2>Opzioni</h2>
      <h3>Audio</h3>
      <div data-volumes></div>
      <label class="ui-row"><span>Musica</span><input type="checkbox" data-music /><span></span></label>
      <h3>Tasti</h3>
      <div class="ui-keys" data-keys></div>
      <p class="ui-note">Clicca un tasto e premi quello nuovo. Canc lo toglie, Esc annulla.</p>
      <div class="ui-actions">
        <button type="button" data-act="reset">Ripristina</button>
        <button type="button" class="primary" data-act="close">Fatto</button>
      </div>
    </div>`;
  document.body.append(root);

  const volumes = root.querySelector<HTMLDivElement>("[data-volumes]")!;
  const music = root.querySelector<HTMLInputElement>("[data-music]")!;
  const keys = root.querySelector<HTMLDivElement>("[data-keys]")!;
  let waiting: { action: Action; slot: number } | null = null;

  const VOLUMES = [
    ["masterVolume", "Generale"],
    ["sfxVolume", "Effetti"],
    ["musicVolume", "Musica"],
  ] as const;

  const draw = () => {
    const s = getSettings();
    volumes.replaceChildren(
      ...VOLUMES.map(([key, label]) => {
        const row = document.createElement("label");
        row.className = "ui-row";
        row.innerHTML = `<span>${label}</span><input type="range" min="0" max="100" /><span></span>`;
        const range = row.querySelector("input")!;
        const value = row.querySelector("span:last-child")!;
        range.value = String(Math.round(s[key] * 100));
        value.textContent = range.value;
        range.addEventListener("input", () => {
          value.textContent = range.value;
          updateSettings({ [key]: Number(range.value) / 100 });
        });
        return row;
      }),
    );
    music.checked = s.musicOn;
    keys.replaceChildren(
      ...ACTIONS.flatMap((action) => {
        const name = document.createElement("span");
        name.textContent = LABELS[action];
        const buttons = Array.from({ length: SLOTS }, (_, slot) => {
          const b = document.createElement("button");
          b.type = "button";
          const isWaiting = waiting?.action === action && waiting.slot === slot;
          const code = s.bindings[action][slot];
          b.textContent = isWaiting ? "Premi un tasto..." : code ? keyLabel(code) : "—";
          b.className = isWaiting ? "wait" : "";
          b.addEventListener("click", () => {
            waiting = { action, slot };
            draw();
          });
          return b;
        });
        return [name, ...buttons];
      }),
    );
  };

  music.addEventListener("change", () => updateSettings({ musicOn: music.checked }));

  // In ascolto prima del gioco (capture): mentre il menu è aperto i tasti servono solo qui
  const onKey = (e: KeyboardEvent) => {
    e.stopPropagation();
    if (!waiting) {
      if (e.code === "Escape") close();
      return;
    }
    e.preventDefault();
    if (e.code !== "Escape") assign(waiting.action, waiting.slot, e.code === "Delete" || e.code === "Backspace" ? null : e.code);
    waiting = null;
    draw();
  };
  window.addEventListener("keydown", onKey, true);

  const close = () => {
    window.removeEventListener("keydown", onKey, true);
    root.remove();
    onClose?.();
  };

  root.addEventListener("click", (e) => {
    const act = (e.target as HTMLElement).closest<HTMLElement>("[data-act]")?.dataset.act;
    if (act === "close") close();
    if (act === "reset") {
      resetSettings();
      draw();
    }
  });

  draw();
}

// Un tasto fa una sola azione: se era già usato altrove, lì si toglie
function assign(action: Action, slot: number, code: string | null) {
  const current = getSettings().bindings;
  const next = Object.fromEntries(ACTIONS.map((a) => [a, current[a].filter((c) => c !== code)])) as Bindings;
  const list = [...current[action].filter((c) => c !== code)];
  if (code) list[slot] = code;
  else list.splice(slot, 1);
  next[action] = list.filter(Boolean).slice(0, 3);
  updateSettings({ bindings: next });
}
