// Ospitare una serata con un doppio clic (#78): accende il server di gioco, apre un tunnel
// Cloudflare gratuito (niente account, niente porte del router) e prepara il link da mandare
// sul Discord. È il punto d'ingresso del server da scaricare (scripts/build-server.mjs),
// ma va anche da sorgente: npm run host.
import { spawn, type ChildProcess } from "node:child_process";
import { existsSync, unlinkSync, writeFileSync } from "node:fs";
import { networkInterfaces } from "node:os";
import path from "node:path";
import { createInterface } from "node:readline";
import "./index";

const PORT = Number(process.env.PORT) || 3000;
const PAGES_URL = "https://nicpanozzo.github.io/bonobo-game/godot/"; // lo stesso di godot/scripts/main.gd
const TUNNEL_TIMEOUT_MS = 30_000; // oltre questo il tunnel non arriva più: si spiega come giocare in casa
const TUNNEL_ATTEMPTS = 3; // Cloudflare a volte rifiuta un tunnel rapido: si riprova prima di arrendersi (#526)
const TUNNEL_RETRY_MS = 3000; // pausa tra un tentativo del tunnel e il successivo
const RETRY_CHECK_MS = 500; // ogni quanto si guarda se l'app chiede un tunnel nuovo
const ERROR_MAX_CHARS = 120; // l'ultima riga d'errore di cloudflared mostrata a chi ospita

// Dall'app (#308): l'app avvia il server in sottofondo con --app-info=<file> e legge da lì
// stanza e link, quindi niente browser né appunti; con --parent-pid si spegne quando l'app si chiude
function arg(name: string): string | undefined {
  const prefix = `--${name}=`;
  return process.argv.find((a) => a.startsWith(prefix))?.slice(prefix.length);
}
const APP_INFO = arg("app-info");
const PARENT_PID = Number(arg("parent-pid")) || 0;
const PARENT_CHECK_MS = 2000; // ogni quanto si guarda se l'app è ancora aperta
// L'app chiede un tunnel nuovo creando questo file accanto a info.json (pulsante "Riprova il tunnel", #526)
const RETRY_FILE = APP_INFO ? `${APP_INFO}.retry` : undefined;

const room = arg("room") || `serata-${Math.random().toString(36).slice(2, 6)}`;
let tunnel: ChildProcess | undefined;
let tunnelUp = false; // il tunnel è collegato: il link per gli amici è quello di Cloudflare
let tunnelTrying = false; // un giro di tentativi è in corso
let tunnelRound = 0; // cresce a ogni giro e a ogni tentativo: l'app vede che info.json è cambiato anche se il testo è uguale

function line(text = ""): void {
  console.log(text);
}

// Prima il cloudflared messo accanto all'eseguibile nello zip, poi quello installato nel sistema
function cloudflaredPath(): string {
  const exe = process.platform === "win32" ? "cloudflared.exe" : "cloudflared";
  const local = path.join(path.dirname(process.execPath), exe);
  return existsSync(local) ? local : exe;
}

function run(cmd: string, args: string[], input?: string): void {
  try {
    const child = spawn(cmd, args, { stdio: [input === undefined ? "ignore" : "pipe", "ignore", "ignore"], detached: process.platform !== "win32" });
    child.on("error", () => {}); // comando che non c'è: pazienza, il link è comunque scritto qui
    if (input !== undefined) child.stdin?.end(input);
    child.unref();
  } catch {
    // come sopra
  }
}

function copyToClipboard(text: string): void {
  if (process.platform === "win32") run("clip", [], text);
  else if (process.platform === "darwin") run("pbcopy", [], text);
  else run("xclip", ["-selection", "clipboard"], text);
}

function openInBrowser(url: string): void {
  if (process.platform === "win32") run("cmd", ["/c", "start", "", url]);
  else if (process.platform === "darwin") run("open", [url]);
  else run("xdg-open", [url]);
}

function lanAddress(): string | undefined {
  for (const list of Object.values(networkInterfaces())) {
    for (const net of list ?? []) if (net.family === "IPv4" && !net.internal) return net.address;
  }
  return undefined;
}

function roomLink(server: string): string {
  // Il server in chiaro (":" e "/" vanno bene in una query): niente %3A%2F da correggere a mano
  return `${PAGES_URL}?room=${encodeURIComponent(room)}&server=${server}`;
}

// Lo stato per l'app: "ready" con l'indirizzo del tunnel, "lan" solo in casa, "error" se il server non parte
function writeAppInfo(state: "ready" | "lan" | "error", extra: Record<string, string> = {}): void {
  if (!APP_INFO) return;
  const ip = lanAddress();
  const info = { state, room, port: PORT, lanServer: ip ? `http://${ip}:${PORT}` : "", ...extra };
  try {
    writeFileSync(APP_INFO, JSON.stringify(info));
  } catch (err) {
    console.error("non riesco a scrivere il file per l'app:", err);
  }
}

function announce(server: string): void {
  const link = roomLink(server);
  if (APP_INFO) {
    writeAppInfo("ready", { server });
    line(`Serata pronta: ${link}`);
    return;
  }
  copyToClipboard(link);
  line();
  line("==============================================================");
  line(" 🦍  LA SERATA È PRONTA");
  line("==============================================================");
  line();
  line(" Manda questo link sul Discord (è già copiato, basta incollarlo):");
  line();
  line(`   ${link}`);
  line();
  line(" Chi lo apre gioca subito nel browser. Chi ha l'app lo incolla");
  line(" nel campo Server della lobby. Ti si apre il gioco nel browser:");
  line(" entra anche tu.");
  line();
  line(" Lascia aperta questa finestra finché giocate: chiuderla spegne la serata.");
  line("==============================================================");
  line();
  openInBrowser(link);
}

// Senza tunnel si gioca solo in casa. final: i tentativi sono finiti (l'app offre "Riprova il tunnel"),
// altrimenti si sta ancora provando e il link di Cloudflare può arrivare dopo. say: lo si spiega anche nella finestra
function withoutTunnel(reason: string, hint: string, final: boolean, detail = "", say = final): void {
  writeAppInfo("lan", { error: reason, tunnel: final ? "failed" : "trying", round: String(tunnelRound), ...(detail ? { detail } : {}) });
  if (!say) return;
  const ip = lanAddress();
  line();
  line(`⚠️  ${reason}${detail ? ` (${detail})` : ""}`);
  line(" Il server è acceso lo stesso, ma solo per chi è nella tua stessa rete (stesso Wi-Fi):");
  line(` nell'app scaricata scrivete nel campo Server  http://${ip ?? "<il tuo IP>"}:${PORT}`);
  line(` ${hint}`);
  line();
}

const RETRY_HINT = "Per giocare con chi è lontano serve internet libero verso Cloudflare: riprova più tardi.";

// L'ultima riga d'errore di cloudflared, senza data e livello: è il motivo vero quando il tunnel non si apre
function cloudflaredError(text: string): string | undefined {
  const match = /\bERR\s+(.*)$/.exec(text);
  return match ? match[1].trim().slice(0, ERROR_MAX_CHARS) : undefined;
}

function startTunnel(attempt = 1): void {
  let found = false;
  let connected = false;
  let url: string | undefined;
  let lastError = "";
  tunnelTrying = true;
  tunnelRound++;
  // Il tempo massimo vale dal primo tentativo di un giro: dopo si gioca in casa e il tunnel può arrivare più tardi
  const timer =
    attempt === 1
      ? setTimeout(() => {
          if (!found && tunnelTrying) withoutTunnel("Il tunnel non risponde.", RETRY_HINT, false, "", true);
        }, TUNNEL_TIMEOUT_MS)
      : undefined;
  const fail = (reason: string, hint: string, retry: boolean): void => {
    found = true;
    clearTimeout(timer);
    if (retry && attempt < TUNNEL_ATTEMPTS) {
      line(`⚠️  ${reason} Riprovo (tentativo ${attempt + 1} di ${TUNNEL_ATTEMPTS})...`);
      withoutTunnel(reason, hint, false, lastError);
      setTimeout(() => startTunnel(attempt + 1), TUNNEL_RETRY_MS);
      return;
    }
    tunnelTrying = false;
    withoutTunnel(reason, hint, true, lastError);
  };
  tunnel = spawn(cloudflaredPath(), ["tunnel", "--no-autoupdate", "--url", `http://localhost:${PORT}`], { stdio: ["ignore", "pipe", "pipe"] });
  tunnel.on("error", () => {
    tunnel?.removeAllListeners("exit");
    fail(
      "Non trovo cloudflared, il programma che apre il tunnel.",
      "Riscarica lo zip dal sito e scompattalo tutto: cloudflared deve stare accanto a questo file.",
      false, // senza il programma riprovare non serve
    );
  });
  tunnel.on("exit", (code) => {
    if (!found) {
      fail("Cloudflare non ha aperto il tunnel.", RETRY_HINT, true);
      return;
    }
    if (!connected) return;
    tunnelUp = false;
    line(`⚠️  Il tunnel si è chiuso (codice ${code}): chi è fuori casa non riesce più a entrare. Riavvia il server per un link nuovo.`);
    // L'app torna al link di casa e offre di riprovare
    tunnelRound++;
    writeAppInfo("lan", { error: "Il tunnel si è chiuso.", tunnel: "failed", round: String(tunnelRound) });
  });
  // cloudflared scrive l'indirizzo pubblico nel suo log, su stderr
  for (const stream of [tunnel.stdout, tunnel.stderr]) {
    if (!stream) continue;
    createInterface({ input: stream }).on("line", (text) => {
      lastError = cloudflaredError(text) ?? lastError;
      const match = /https:\/\/[a-z0-9-]+\.trycloudflare\.com/.exec(text);
      if (match) url ??= match[0];
      // Il link si annuncia quando il tunnel è collegato davvero, così chi lo apre subito entra
      if (url && !found && /Registered tunnel connection/.test(text)) {
        found = true;
        connected = true;
        tunnelUp = true;
        tunnelTrying = false;
        clearTimeout(timer);
        announce(url);
      }
    });
  }
}

function shutdown(): void {
  tunnel?.kill();
  process.exit(0);
}

// Con il doppio clic la finestra sparirebbe subito: l'errore resta leggibile finché non si preme Invio.
// Solo per la porta che non si apre: gli altri errori li registra index.ts e il server resta acceso (#105)
process.on("uncaughtException", (err: NodeJS.ErrnoException) => {
  if (err.syscall !== "listen") return;
  tunnel?.kill();
  if (APP_INFO) {
    if (err.code === "EADDRINUSE") writeAppInfo("error", { error: `La porta ${PORT} è già occupata`, busy: "true" });
    else writeAppInfo("error", { error: err.message });
    process.exit(1);
  }
  line();
  if (err.code === "EADDRINUSE") line(`❌ La porta ${PORT} è già occupata: forse il server è già acceso in un'altra finestra.`);
  else line(`❌ Non riesco ad aprire la porta ${PORT}: ${err.message}`);
  line("Premi Invio per chiudere.");
  process.stdin.resume();
  process.stdin.once("data", () => process.exit(1));
});
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
process.on("exit", () => tunnel?.kill());

if (PARENT_PID) {
  setInterval(() => {
    try {
      process.kill(PARENT_PID, 0); // 0: non manda niente, controlla solo che il processo ci sia
    } catch (err) {
      if ((err as NodeJS.ErrnoException).code === "ESRCH") shutdown();
    }
  }, PARENT_CHECK_MS).unref();
}

// "Riprova il tunnel" dall'app: un giro nuovo di tentativi, se non ce n'è già uno e il tunnel non c'è
if (RETRY_FILE) {
  const retryFile = RETRY_FILE;
  setInterval(() => {
    if (!existsSync(retryFile)) return;
    try {
      unlinkSync(retryFile);
    } catch {
      return; // lo si riprende al giro dopo
    }
    if (tunnelUp || tunnelTrying) return;
    line("L'app chiede un tunnel nuovo: riprovo.");
    startTunnel();
    writeAppInfo("lan", { error: "Riprovo il tunnel.", tunnel: "trying", round: String(tunnelRound) });
  }, RETRY_CHECK_MS).unref();
}

line("Accendo il server di gioco e apro il tunnel, un attimo...");
startTunnel();
