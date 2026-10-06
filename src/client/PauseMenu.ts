import { ensureUiStyle, openOptions } from "./OptionsPanel";

// Menu con Esc durante la partita. La partita è online e non si ferma: il menu
// spegne solo i tasti di chi lo apre.

export interface PauseActions {
  onResume: () => void;
  onLeave: () => void;
  link: string;
}

export function openPauseMenu(actions: PauseActions): () => void {
  ensureUiStyle();
  const root = document.createElement("div");
  root.className = "ui-overlay";
  root.innerHTML = `
    <div class="ui-card" role="dialog" aria-label="Pausa">
      <h2>Menu</h2>
      <div class="ui-menu">
        <button type="button" class="primary" data-act="resume">Riprendi</button>
        <button type="button" data-act="options">Opzioni</button>
        <button type="button" data-act="copy">Copia link della stanza</button>
        <button type="button" data-act="leave">Esci alla lobby</button>
      </div>
      <p class="ui-note" data-msg>La partita continua mentre il menu è aperto.</p>
    </div>`;
  document.body.append(root);
  const msg = root.querySelector<HTMLElement>("[data-msg]")!;
  let inOptions = false;

  const close = () => {
    window.removeEventListener("keydown", onKey, true);
    root.remove();
  };
  const onKey = (e: KeyboardEvent) => {
    if (inOptions) return;
    e.stopPropagation();
    if (e.code === "Escape") {
      close();
      actions.onResume();
    }
  };
  window.addEventListener("keydown", onKey, true);

  root.addEventListener("click", async (e) => {
    const act = (e.target as HTMLElement).closest<HTMLElement>("[data-act]")?.dataset.act;
    if (act === "resume") {
      close();
      actions.onResume();
    }
    if (act === "options") {
      inOptions = true;
      root.style.display = "none";
      openOptions(() => {
        inOptions = false;
        root.style.display = "";
      });
    }
    if (act === "copy") {
      try {
        await navigator.clipboard.writeText(actions.link);
        msg.textContent = "Link copiato: incollalo sul Discord";
      } catch {
        msg.textContent = actions.link;
      }
    }
    if (act === "leave") {
      close();
      actions.onLeave();
    }
  });
  return close;
}
