// Ospitare una serata con un doppio clic (#78): accende il server di gioco, apre un tunnel
// Cloudflare gratuito (niente account, niente porte del router) e prepara il link da mandare
// sul Discord. È il punto d'ingresso del server da scaricare (scripts/build-server.mjs),
// ma va anche da sorgente: npm run host.
import { spawn, type ChildProcess } from "node:child_process";
import { existsSync, writeFileSync } from "node:fs";
import { networkInterfaces } from "node:os";
import path from "node:path";
import { createInterface } from "node:readline";
import "./index";

const PORT = Number(process.env.PORT) || 3000;
const PAGES_URL = "https://nicpanozzo.github.io/bonobo-game/godot/"; // lo stesso di godot/scripts/main.gd
const TUNNEL_TIMEOUT_MS = 30_000; // oltre questo il tunnel non arriva più: si spiega come giocare in casa

// Dall'app (#308): l'app avvia il server in sottofondo con --app-info=<file> e legge da lì
// stanza e link, quindi niente browser né appunti; con --parent-pid si spegne quando l'app si chiude
function arg(name: string): string | undefined {
  const prefix = `--${name}=`;
  return process.argv.find((a) => a.startsWith(prefix))?.slice(prefix.length);
}
const APP_INFO = arg("app-info");
const PARENT_PID = Number(arg("parent-pid")) || 0;
const PARENT_CHECK_MS = 2000; // ogni quanto si guarda se l'app è ancora aperta

const room = arg("room") || `serata-${Math.random().toString(36).slice(2, 6)}`;
let tunnel: ChildProcess | undefined;

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
  return `${PAGES_URL}?room=${encodeURIComponent(room)}&server=${encodeURIComponent(server)}`;
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

function withoutTunnel(reason: string, hint: string): void {
  writeAppInfo("lan", { error: reason });
  const ip = lanAddress();
  line();
  line(`⚠️  ${reason}`);
  line(" Il server è acceso lo stesso, ma solo per chi è nella tua stessa rete (stesso Wi-Fi):");
  line(` nell'app scaricata scrivete nel campo Server  http://${ip ?? "<il tuo IP>"}:${PORT}`);
  line(` ${hint}`);
  line();
}

function startTunnel(): void {
  let found = false;
  let url: string | undefined;
  const timer = setTimeout(() => {
    if (!found) withoutTunnel("Il tunnel non risponde.", "Per giocare con chi è lontano serve internet libero verso Cloudflare: riavvia più tardi.");
  }, TUNNEL_TIMEOUT_MS);
  tunnel = spawn(cloudflaredPath(), ["tunnel", "--no-autoupdate", "--url", `http://localhost:${PORT}`], { stdio: ["ignore", "pipe", "pipe"] });
  tunnel.on("error", () => {
    tunnel?.removeAllListeners("exit");
    clearTimeout(timer);
    found = true;
    withoutTunnel(
      "Non trovo cloudflared, il programma che apre il tunnel.",
      "Riscarica lo zip dal sito e scompattalo tutto: cloudflared deve stare accanto a questo file.",
    );
  });
  tunnel.on("exit", (code) => {
    if (!found) {
      found = true;
      clearTimeout(timer);
      withoutTunnel("Cloudflare non ha aperto il tunnel.", "Per giocare con chi è lontano serve internet libero verso Cloudflare: riavvia più tardi.");
    } else line(`⚠️  Il tunnel si è chiuso (codice ${code}): chi è fuori casa non riesce più a entrare. Riavvia il server per un link nuovo.`);
  });
  // cloudflared scrive l'indirizzo pubblico nel suo log, su stderr
  for (const stream of [tunnel.stdout, tunnel.stderr]) {
    if (!stream) continue;
    createInterface({ input: stream }).on("line", (text) => {
      const match = /https:\/\/[a-z0-9-]+\.trycloudflare\.com/.exec(text);
      if (match) url ??= match[0];
      // Il link si annuncia quando il tunnel è collegato davvero, così chi lo apre subito entra
      if (url && !found && /Registered tunnel connection/.test(text)) {
        found = true;
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

line("Accendo il server di gioco e apro il tunnel, un attimo...");
startTunnel();
