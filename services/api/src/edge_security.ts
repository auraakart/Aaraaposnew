export interface CorsPolicy {
  allowedOrigins: ReadonlySet<string>;
}

export interface CorsDecision {
  allowed: boolean;
  headers: Readonly<Record<string, string>>;
}

export interface RateLimitDecision {
  allowed: boolean;
  limit: number;
  remaining: number;
  resetAtEpochSeconds: number;
}

interface RateBucket {
  count: number;
  resetAtMs: number;
}

export class FixedWindowRateLimiter {
  private readonly buckets = new Map<string, RateBucket>();

  constructor(
    private readonly limit = 120,
    private readonly windowMs = 60_000,
    private readonly maxKeys = 10_000
  ) {
    if (!Number.isSafeInteger(limit) || limit <= 0) {
      throw new Error("rate limit must be a positive safe integer");
    }
    if (!Number.isSafeInteger(windowMs) || windowMs < 1000) {
      throw new Error("rate limit window must be at least one second");
    }
    if (!Number.isSafeInteger(maxKeys) || maxKeys <= 0) {
      throw new Error("rate limiter maxKeys must be a positive safe integer");
    }
  }

  check(key: string, nowMs: number): RateLimitDecision {
    if (!key.trim()) throw new Error("rate limit key is required");
    if (!Number.isFinite(nowMs) || nowMs < 0) {
      throw new Error("rate limit time is invalid");
    }

    this.pruneExpired(nowMs);

    let bucket = this.buckets.get(key);
    if (bucket === undefined || nowMs >= bucket.resetAtMs) {
      if (this.buckets.size >= this.maxKeys) {
        const oldestKey = this.buckets.keys().next().value as
          | string
          | undefined;
        if (oldestKey !== undefined) this.buckets.delete(oldestKey);
      }

      bucket = {
        count: 0,
        resetAtMs: nowMs + this.windowMs
      };
      this.buckets.set(key, bucket);
    }

    bucket.count += 1;
    const remaining = Math.max(0, this.limit - bucket.count);
    return {
      allowed: bucket.count <= this.limit,
      limit: this.limit,
      remaining,
      resetAtEpochSeconds: Math.ceil(bucket.resetAtMs / 1000)
    };
  }

  private pruneExpired(nowMs: number): void {
    for (const [key, bucket] of this.buckets) {
      if (nowMs >= bucket.resetAtMs) {
        this.buckets.delete(key);
      }
    }
  }
}

function isLocalDevelopmentOrigin(url: URL): boolean {
  return (
    url.protocol === "http:" &&
    (url.hostname === "localhost" || url.hostname === "127.0.0.1")
  );
}

function normalizeOrigin(raw: string): string {
  const trimmed = raw.trim();
  if (!trimmed) throw new Error("CORS origin cannot be empty");

  let url: URL;
  try {
    url = new URL(trimmed);
  } catch {
    throw new Error(`Invalid CORS origin: ${trimmed}`);
  }

  if (
    url.username ||
    url.password ||
    url.pathname !== "/" ||
    url.search ||
    url.hash
  ) {
    throw new Error(`CORS origin must contain only scheme/host/port: ${trimmed}`);
  }

  if (url.protocol !== "https:" && !isLocalDevelopmentOrigin(url)) {
    throw new Error(
      `CORS origin must use HTTPS except localhost development: ${trimmed}`
    );
  }

  return url.origin;
}

export function parseAllowedOrigins(raw: string | undefined): ReadonlySet<string> {
  if (raw === undefined || !raw.trim()) return new Set();

  const origins = raw
    .split(",")
    .map((value) => normalizeOrigin(value));

  return new Set(origins);
}

export function evaluateCors(
  originHeader: string | undefined,
  policy: CorsPolicy,
  preflight: boolean
): CorsDecision {
  if (originHeader === undefined) {
    return { allowed: true, headers: {} };
  }

  let origin: string;
  try {
    origin = normalizeOrigin(originHeader);
  } catch {
    return { allowed: false, headers: { vary: "Origin" } };
  }

  if (!policy.allowedOrigins.has(origin)) {
    return { allowed: false, headers: { vary: "Origin" } };
  }

  return {
    allowed: true,
    headers: {
      "access-control-allow-origin": origin,
      vary: "Origin",
      ...(preflight
        ? {
            "access-control-allow-methods": "GET, POST, OPTIONS",
            "access-control-allow-headers":
              "Authorization, Content-Type, X-Request-ID",
            "access-control-max-age": "600"
          }
        : {})
    }
  };
}

export function apiSecurityHeaders(): Readonly<Record<string, string>> {
  return {
    "cache-control": "no-store",
    "content-security-policy":
      "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'",
    "cross-origin-resource-policy": "same-site",
    "referrer-policy": "no-referrer",
    "x-content-type-options": "nosniff",
    "x-frame-options": "DENY"
  };
}

export function isJsonContentType(value: string | undefined): boolean {
  if (value === undefined) return false;
  const mediaType = value.split(";", 1)[0]?.trim().toLowerCase();
  return mediaType === "application/json";
}

export function rateLimitHeaders(
  decision: RateLimitDecision
): Readonly<Record<string, string>> {
  return {
    "ratelimit-limit": String(decision.limit),
    "ratelimit-remaining": String(decision.remaining),
    "ratelimit-reset": String(decision.resetAtEpochSeconds)
  };
}
