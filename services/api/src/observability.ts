import { randomUUID } from "node:crypto";

export type LogLevel = "info" | "warn" | "error";

export interface RequestContext {
  requestId: string;
  method: string;
  path: string;
  startedAtMs: number;
}

export interface StructuredLogRecord {
  timestamp: string;
  level: LogLevel;
  event: string;
  requestId?: string;
  method?: string;
  path?: string;
  statusCode?: number;
  durationMs?: number;
  details?: Readonly<Record<string, unknown>>;
}

const safeRequestId = /^[A-Za-z0-9._:-]{1,128}$/;
const sensitiveKey =
  /(password|secret|token|authorization|cookie|cvv|card_number|pan_number|mobile|phone|email|address|receipt|note|payload|body)/i;

export function normalizeRequestId(raw: string | undefined): string {
  const value = raw?.trim();
  if (value && safeRequestId.test(value)) return value;
  return randomUUID();
}

export function requestPath(rawUrl: string | undefined): string {
  if (!rawUrl) return "/";
  try {
    return new URL(rawUrl, "http://localhost").pathname || "/";
  } catch {
    return "/";
  }
}

export function createRequestContext(input: {
  requestIdHeader?: string;
  method?: string;
  url?: string;
  nowMs?: number;
}): RequestContext {
  return {
    requestId: normalizeRequestId(input.requestIdHeader),
    method: (input.method ?? "UNKNOWN").toUpperCase(),
    path: requestPath(input.url),
    startedAtMs: input.nowMs ?? Date.now()
  };
}

export function redactLogDetails(
  value: Readonly<Record<string, unknown>>
): Readonly<Record<string, unknown>> {
  const output: Record<string, unknown> = {};

  for (const [key, item] of Object.entries(value)) {
    if (sensitiveKey.test(key)) {
      output[key] = "[REDACTED]";
      continue;
    }

    if (Array.isArray(item)) {
      output[key] = item.map((entry) =>
        entry !== null && typeof entry === "object" && !Array.isArray(entry)
          ? redactLogDetails(entry as Readonly<Record<string, unknown>>)
          : entry
      );
      continue;
    }

    if (item !== null && typeof item === "object") {
      output[key] = redactLogDetails(
        item as Readonly<Record<string, unknown>>
      );
      continue;
    }

    output[key] = item;
  }

  return output;
}

export function buildStructuredLog(input: {
  level: LogLevel;
  event: string;
  now?: Date;
  request?: RequestContext;
  statusCode?: number;
  durationMs?: number;
  details?: Readonly<Record<string, unknown>>;
}): StructuredLogRecord {
  if (!/^[a-z0-9_.-]{1,80}$/.test(input.event)) {
    throw new Error("Structured log event name is invalid");
  }
  if (
    input.durationMs !== undefined &&
    (!Number.isFinite(input.durationMs) || input.durationMs < 0)
  ) {
    throw new Error("Log duration must be a non-negative finite number");
  }

  return {
    timestamp: (input.now ?? new Date()).toISOString(),
    level: input.level,
    event: input.event,
    ...(input.request === undefined
      ? {}
      : {
          requestId: input.request.requestId,
          method: input.request.method,
          path: input.request.path
        }),
    ...(input.statusCode === undefined
      ? {}
      : { statusCode: input.statusCode }),
    ...(input.durationMs === undefined
      ? {}
      : { durationMs: Math.round(input.durationMs) }),
    ...(input.details === undefined
      ? {}
      : { details: redactLogDetails(input.details) })
  };
}

export function writeStructuredLog(
  record: StructuredLogRecord,
  write: (line: string) => void = (line) => process.stdout.write(line)
): void {
  write(JSON.stringify(record) + "\n");
}

export function processHealth(input: {
  requestId: string;
  uptimeSeconds?: number;
}): {
  status: "ok";
  service: "aaraapos-api";
  scope: "process";
  uptimeSeconds: number;
  requestId: string;
} {
  const uptime = input.uptimeSeconds ?? process.uptime();
  return {
    status: "ok",
    service: "aaraapos-api",
    scope: "process",
    uptimeSeconds: Math.max(0, Math.floor(uptime)),
    requestId: input.requestId
  };
}
