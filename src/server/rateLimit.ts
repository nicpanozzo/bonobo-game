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
