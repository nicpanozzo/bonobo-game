// Ospitare una serata con un doppio clic (#78): accende il server di gioco, apre un tunnel
// Cloudflare gratuito (niente account, niente porte del router) e prepara il link da mandare
// sul Discord. È il punto d'ingresso del server da scaricare (scripts/build-server.mjs),
// ma va anche da sorgente: npm run host.
import { spawn, type ChildProcess } from "node:child_process";
import { existsSync } from "node:fs";
import { networkInterfaces } from "node:os";
import path from "node:path";
import { createInterface } from "node:readline";
import "./index";

const PORT = Number(process.env.PORT) || 3000;
const PAGES_URL = "https://nicpanozzo.github.io/bonobo-game/godot/"; // lo stesso di godot/scripts/main.gd
const TUNNEL_TIMEOUT_MS = 30_000; // oltre questo il tunnel non arriva più: si spiega come giocare in casa

const room = `serata-${Math.random().toString(36).slice(2, 6)}`;
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

function announce(server: string): void {
  const link = `${PAGES_URL}?room=${encodeURIComponent(room)}&server=${encodeURIComponent(server)}`;
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

// Con il doppio clic la finestra sparirebbe subito: l'errore resta leggibile finché non si preme Invio
process.on("uncaughtException", (err: NodeJS.ErrnoException) => {
  tunnel?.kill();
  line();
  if (err.code === "EADDRINUSE") line(`❌ La porta ${PORT} è già occupata: forse il server è già acceso in un'altra finestra.`);
  else line(`❌ Qualcosa è andato storto: ${err.message}`);
  line("Premi Invio per chiudere.");
  process.stdin.resume();
  process.stdin.once("data", () => process.exit(1));
});
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
process.on("exit", () => tunnel?.kill());

line("Accendo il server di gioco e apro il tunnel, un attimo...");
startTunnel();
