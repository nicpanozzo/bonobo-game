// Controllo del volume dei file audio (E13 passo 5): loudness integrata e picco di ogni file registrato,
// misurati con ffmpeg (filtro ebur128). Esce con errore se un file è fuori da AUDIO.targetLufs ± AUDIO.lufsTolerance
// o supera AUDIO.maxPeakDb. Senza file non c'è niente da controllare e passa.
// Uso: npm run audio:check (serve ffmpeg installato)

import { execFileSync, spawnSync } from "node:child_process";
import { existsSync, readdirSync } from "node:fs";
import { extname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { AUDIO } from "../src/shared/constants";

const assets = fileURLToPath(new URL("../public/assets/", import.meta.url));
const AUDIO_EXT = new Set([".ogg", ".wav"]);

// Le cartelle dell'audio, come in scripts/export-godot.ts
const dirs = ["sfx", "music", "announcer"];
if (existsSync(join(assets, "characters"))) {
  for (const id of readdirSync(join(assets, "characters"))) dirs.push(`characters/${id}/voice`);
}
const files = dirs.flatMap((d) =>
  existsSync(join(assets, d)) ? readdirSync(join(assets, d)).filter((f) => AUDIO_EXT.has(extname(f))).map((f) => `${d}/${f}`) : [],
);

if (files.length === 0) {
  console.log("Nessun file audio in public/assets: niente da controllare.");
  process.exit(0);
}
try {
  execFileSync("ffmpeg", ["-version"], { stdio: "ignore" });
} catch {
  console.error("Serve ffmpeg per misurare i file (https://ffmpeg.org).");
  process.exit(2);
}

// ebur128 stampa alla fine un riassunto con "I: -16.2 LUFS" e "Peak: -1.3 dBFS"
function measure(path: string): { lufs: number; peak: number } {
  const run = spawnSync("ffmpeg", ["-hide_banner", "-nostats", "-i", path, "-af", "ebur128=peak=true", "-f", "null", "-"], { encoding: "utf8" });
  const summary = run.stderr.slice(run.stderr.lastIndexOf("Summary:"));
  const lufs = Number(/I:\s+(-?[\d.]+|-inf) LUFS/.exec(summary)?.[1] ?? NaN);
  const peak = Number(/Peak:\s+(-?[\d.]+|-inf) dBFS/.exec(summary)?.[1] ?? NaN);
  return { lufs, peak };
}

let bad = 0;
console.log(`Obiettivo ${AUDIO.targetLufs} LUFS ± ${AUDIO.lufsTolerance}, picco sotto ${AUDIO.maxPeakDb} dB\n`);
console.log("file".padEnd(48) + "LUFS".padStart(8) + "picco".padStart(8));
for (const f of files) {
  const { lufs, peak } = measure(join(assets, f));
  const problems = [];
  if (!(Math.abs(lufs - AUDIO.targetLufs) <= AUDIO.lufsTolerance)) problems.push(lufs < AUDIO.targetLufs ? "troppo piano" : "troppo forte");
  if (!(peak <= AUDIO.maxPeakDb)) problems.push("picco troppo alto");
  if (problems.length) bad++;
  console.log(f.padEnd(48) + lufs.toFixed(1).padStart(8) + peak.toFixed(1).padStart(8) + (problems.length ? `  ${problems.join(", ")}` : ""));
}
if (bad) {
  console.error(`\n${bad} file da sistemare: normalizzali con Audacity (Effetti → Normalizzazione del volume) o ffmpeg -af loudnorm.`);
  process.exit(1);
}
