import type { InputState } from "../shared/types";
import { ACTIONS, getSettings } from "./settings";

// Tastiera → InputState, con i tasti scelti nelle opzioni. È l'unica cosa che il client manda al server.
// Si ascoltano direttamente gli eventi del browser: così i tasti si possono riassegnare
// e, se si cambia finestra, niente resta "premuto".
export class KeyboardInput {
  private down = new Set<string>();
  enabled = true; // spento mentre è aperto un menu

  constructor() {
    window.addEventListener("keydown", this.onDown);
    window.addEventListener("keyup", this.onUp);
    window.addEventListener("blur", this.clear);
  }

  destroy() {
    window.removeEventListener("keydown", this.onDown);
    window.removeEventListener("keyup", this.onUp);
    window.removeEventListener("blur", this.clear);
  }

  read(): InputState {
    const b = getSettings().bindings;
    const on = (action: (typeof ACTIONS)[number]) => this.enabled && b[action].some((code) => this.down.has(code));
    return {
      left: on("left"),
      right: on("right"),
      up: on("up"),
      jump: on("up"), // il vecchio client salta con su, come prima di E10
      down: on("down"),
      light: on("light"),
      heavy: on("heavy"),
      taunt: on("taunt"),
      dodge: on("dodge"),
      shield: false, // il vecchio client è congelato: niente scudo (#109)
      special: false, // né speciali (E10)
    };
  }

  private onDown = (e: KeyboardEvent) => {
    if (isTyping(e)) return;
    this.down.add(e.code);
    // Frecce e spazio non devono far scorrere la pagina
    if (Object.values(getSettings().bindings).some((codes) => codes.includes(e.code))) e.preventDefault();
  };

  private onUp = (e: KeyboardEvent) => {
    this.down.delete(e.code);
  };

  clear = () => this.down.clear();
}

function isTyping(e: KeyboardEvent): boolean {
  const t = e.target as HTMLElement | null;
  return !!t && (t.tagName === "INPUT" || t.tagName === "SELECT" || t.tagName === "TEXTAREA");
}

// Nome leggibile di un tasto: "KeyA" → "A", "ArrowLeft" → "←"
export function keyLabel(code: string): string {
  const arrows: Record<string, string> = { ArrowLeft: "←", ArrowRight: "→", ArrowUp: "↑", ArrowDown: "↓" };
  if (arrows[code]) return arrows[code];
  if (code.startsWith("Key")) return code.slice(3);
  if (code.startsWith("Digit")) return code.slice(5);
  if (code === "Space") return "Spazio";
  return code.replace(/^Numpad/, "Num ").replace(/(Left|Right)$/, "");
}
