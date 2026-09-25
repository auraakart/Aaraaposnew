export const permissions = [
  "sale:create",
  "sale:discount",
  "refund:create",
  "refund:approve",
  "inventory:receive",
  "inventory:count",
  "inventory:adjust",
  "store:read",
  "commerce:read",
  "commerce:manage",
  "transfer:create",
  "transfer:receive",
  "customer:credit",
  "expense:create",
  "shift:manage",
  "employee:manage",
  "audit:read",
  "financial-config:manage"
] as const;

export type Permission = (typeof permissions)[number];
export type Role = "owner" | "manager" | "cashier" | "stock_worker";

const grants: Readonly<Record<Role, ReadonlySet<Permission>>> = {
  owner: new Set(permissions),
  manager: new Set([
    "sale:create",
    "sale:discount",
    "refund:create",
    "refund:approve",
    "inventory:receive",
    "inventory:count",
    "inventory:adjust",
    "store:read",
    "commerce:read",
    "commerce:manage",
    "transfer:create",
    "transfer:receive",
    "customer:credit",
    "expense:create",
    "shift:manage",
    "employee:manage",
    "audit:read"
  ]),
  cashier: new Set([
    "sale:create",
    "sale:discount",
    "refund:create",
    "customer:credit",
    "expense:create",
    "shift:manage"
  ]),
  stock_worker: new Set([
    "inventory:receive",
    "inventory:count",
    "inventory:adjust",
    "store:read",
    "transfer:create",
    "transfer:receive"
  ])
};

export interface AuthenticatedPrincipal {
  userId: string;
  organizationId: string;
  businessIds: readonly string[];
  storeIds: readonly string[];
  role: Role;
}

export interface RequestedScope {
  organizationId: string;
  businessId: string;
  storeId: string;
}

export class AuthorizationError extends Error {
  constructor() {
    super("You do not have permission to perform this action.");
    this.name = "AuthorizationError";
  }
}

export function hasPermission(role: Role, permission: Permission): boolean {
  return grants[role].has(permission);
}

export function assertAuthorized(
  principal: AuthenticatedPrincipal,
  scope: RequestedScope,
  permission: Permission
): void {
  const validScope =
    principal.organizationId === scope.organizationId &&
    principal.businessIds.includes(scope.businessId) &&
    principal.storeIds.includes(scope.storeId);

  if (!validScope || !hasPermission(principal.role, permission)) {
    throw new AuthorizationError();
  }
}
