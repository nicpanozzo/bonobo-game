// Impacchetta il server di gioco (src/server/host.ts) in un solo eseguibile, da scaricare
// e aprire con un doppio clic (#78). Usa le "single executable applications" di Node:
// esbuild mette tutto il codice in un file, che poi viene iniettato in una copia di node.
//
//   node scripts/build-server.mjs                         per il sistema su cui gira
//   node scripts/build-server.mjs --target win --node node.exe --out build/server/bonobo-server.exe
//
// Il binario di node passato con --node deve avere la stessa versione di quello che lancia lo script.
import { execFileSync } from "node:child_process";
import { copyFileSync, chmodSync, mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import { build } from "esbuild";

const args = Object.fromEntries(
  process.argv.slice(2).flatMap((arg, i, all) => (arg.startsWith("--") ? [[arg.slice(2), all[i + 1]]] : [])),
);
const target = args.target ?? { win32: "win", darwin: "mac" }[process.platform] ?? "linux";
const nodeBinary = args.node ?? process.execPath;
const dir = "build/server";
const out = args.out ?? path.join(dir, target === "win" ? "bonobo-server.exe" : "bonobo-server");

mkdirSync(dir, { recursive: true });
mkdirSync(path.dirname(out), { recursive: true });

// 1. Tutto il server in un file CommonJS (il formato che Node sa iniettare)
await build({
  entryPoints: ["src/server/host.ts"],
  outfile: path.join(dir, "host.cjs"),
  bundle: true,
  platform: "node",
  format: "cjs",
  target: "node22",
  // Moduli nativi facoltativi di ws: se mancano ws usa la sua versione in JavaScript
  external: ["bufferutil", "utf-8-validate"],
  // Serve solo per la cartella dist/ in produzione, che l'eseguibile non usa
  define: { "import.meta.url": '"file:///bonobo-server"' },
  logLevel: "warning",
});

// 2. Il blob da iniettare
writeFileSync(
  path.join(dir, "sea-config.json"),
  JSON.stringify({
    main: path.join(dir, "host.cjs"),
    output: path.join(dir, "sea-prep.blob"),
    disableExperimentalSEAWarning: true,
    // Senza cache né snapshot il blob va bene per ogni sistema: si costruisce tutto da Linux
    useCodeCache: false,
    useSnapshot: false,
  }),
);
execFileSync(process.execPath, ["--experimental-sea-config", path.join(dir, "sea-config.json")], { stdio: "inherit" });

// 3. Una copia di node con il blob dentro
copyFileSync(nodeBinary, out);
chmodSync(out, 0o755);
if (target === "mac" && process.platform === "darwin") execFileSync("codesign", ["--remove-signature", out]);
execFileSync(
  "npx",
  [
    "--yes",
    "postject@1.0.0-alpha.6",
    out,
    "NODE_SEA_BLOB",
    path.join(dir, "sea-prep.blob"),
    "--sentinel-fuse",
    "NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2",
    ...(target === "mac" ? ["--macho-segment-name", "NODE_SEA"] : []),
  ],
  { stdio: "inherit", shell: process.platform === "win32" },
);
// Sul Mac un eseguibile senza firma non parte nemmeno: basta quella "ad hoc"
if (target === "mac" && process.platform === "darwin") execFileSync("codesign", ["--sign", "-", out]);

console.log(`Server pronto: ${out}`);
