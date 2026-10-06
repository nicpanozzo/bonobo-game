// Secchiello di gettoni (#105): ogni messaggio costa un gettone, i gettoni tornano a ritmo costante.
// Un client normale non se ne accorge; uno che manda migliaia di messaggi al secondo viene scartato.
export class TokenBucket {
  private tokens: number;
  private last: number;

  constructor(
    private readonly perSecond: number,
    private readonly burst: number,
    now: number,
  ) {
    this.tokens = burst;
    this.last = now;
  }

  // true se il messaggio passa
  take(now: number): boolean {
    this.tokens = Math.min(this.burst, this.tokens + ((now - this.last) / 1000) * this.perSecond);
    this.last = now;
    if (this.tokens < 1) return false;
    this.tokens -= 1;
    return true;
  }
}

// Tiene il conto di quanto a lungo un client resta oltre il limite, per chiuderlo se insiste
export class Flood {
  private since: number | null = null;

  constructor(private readonly maxMs: number) {}

  // Da chiamare a ogni messaggio: true se il client va chiuso
  record(allowed: boolean, now: number): boolean {
    if (allowed) {
      this.since = null;
      return false;
    }
    this.since ??= now;
    return now - this.since >= this.maxMs;
  }
}

// IP vero di chi si collega. Dietro il tunnel di host.ts (o il proxy di Render) tutti arrivano da un indirizzo
// di casa nostra: solo allora ci si fida delle intestazioni che dicono chi c'è davvero dall'altra parte.
const PRIVATE = /^(::1$|127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.|f[cd][0-9a-f]{2}:)/i;
export function clientIp(address: string, headers: Record<string, string | string[] | undefined>): string {
  const ip = address.replace(/^::ffff:/i, "");
  if (!PRIVATE.test(ip)) return ip;
  const header = (name: string) => {
    const v = headers[name];
    return (Array.isArray(v) ? v[0] : v)?.split(",")[0].trim().slice(0, 64);
  };
  return header("cf-connecting-ip") || header("x-forwarded-for") || ip;
}

// Limiti per IP (#105 passo 3): connessioni aperte insieme e stanze nuove al minuto
export class IpLimits {
  private open = new Map<string, number>();
  private created = new Map<string, number[]>();

  constructor(
    private readonly maxConnections: number,
    private readonly roomsPerMinute: number,
  ) {}

  // true se la connessione è ammessa; se lo è va chiusa con disconnect()
  connect(ip: string): boolean {
    const n = this.open.get(ip) ?? 0;
    if (n >= this.maxConnections) return false;
    this.open.set(ip, n + 1);
    return true;
  }

  disconnect(ip: string) {
    const n = (this.open.get(ip) ?? 1) - 1;
    if (n > 0) this.open.set(ip, n);
    else this.open.delete(ip);
  }

  // true se questo IP può creare un'altra stanza adesso
  createRoom(ip: string, now: number): boolean {
    const recent = (this.created.get(ip) ?? []).filter((t) => now - t < 60_000);
    if (recent.length >= this.roomsPerMinute) {
      this.created.set(ip, recent);
      return false;
    }
    recent.push(now);
    this.created.set(ip, recent);
    return true;
  }

  // Dimentica gli IP senza stanze recenti, perché la mappa non cresca per sempre
  prune(now: number) {
    for (const [ip, times] of this.created) if (times.every((t) => now - t >= 60_000)) this.created.delete(ip);
  }
}
