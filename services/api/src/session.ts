import {
  type AuthenticatedPrincipal,
  type Role
} from "./security.js";

export type RemoteAuthMethod =
  | "oidc"
  | "passwordless"
  | "service_token";

export interface RemoteSessionClaims {
  sessionId: string;
  subject: string;
  organizationId: string;
  businessIds: readonly string[];
  storeIds: readonly string[];
  role: Role;
  authMethod: RemoteAuthMethod;
  issuedAt: string;
  expiresAt: string;
}

function required(field: string, value: string): void {
  if (!value.trim()) throw new Error(`${field} is required`);
}

export function validateRemoteSessionClaims(
  claims: RemoteSessionClaims,
  now: Date
): void {
  required("sessionId", claims.sessionId);
  required("subject", claims.subject);
  required("organizationId", claims.organizationId);

  if (claims.businessIds.length === 0 || claims.storeIds.length === 0) {
    throw new Error("Remote session requires business and store scope");
  }
  if (
    claims.businessIds.some((value) => !value.trim()) ||
    claims.storeIds.some((value) => !value.trim())
  ) {
    throw new Error("Remote session scope contains an empty identifier");
  }

  const issuedAt = Date.parse(claims.issuedAt);
  const expiresAt = Date.parse(claims.expiresAt);
  const nowMs = now.getTime();
  if (
    Number.isNaN(issuedAt) ||
    Number.isNaN(expiresAt) ||
    Number.isNaN(nowMs)
  ) {
    throw new Error("Remote session timestamps are invalid");
  }
  if (expiresAt <= issuedAt) {
    throw new Error("Remote session expiry must be after issuance");
  }
  if (issuedAt > nowMs + 5 * 60 * 1000) {
    throw new Error("Remote session issuance is too far in the future");
  }
  if (expiresAt <= nowMs) {
    throw new Error("Remote session is expired");
  }
  if (expiresAt - issuedAt > 24 * 60 * 60 * 1000) {
    throw new Error("Remote session lifetime exceeds policy");
  }
}

export function principalFromRemoteSession(
  claims: RemoteSessionClaims,
  now: Date
): AuthenticatedPrincipal {
  validateRemoteSessionClaims(claims, now);
  return {
    userId: claims.subject,
    organizationId: claims.organizationId,
    businessIds: claims.businessIds,
    storeIds: claims.storeIds,
    role: claims.role
  };
}

export function assertRemoteAuthMethod(value: string): RemoteAuthMethod {
  if (
    value !== "oidc" &&
    value !== "passwordless" &&
    value !== "service_token"
  ) {
    throw new Error(
      "Unsupported remote authentication method; local device PIN is not a remote credential"
    );
  }
  return value;
}
