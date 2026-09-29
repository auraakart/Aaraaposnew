import {
  AuthenticationError,
  AuthenticationUnavailableError,
  type RequestAuthenticator
} from "./authenticator.js";
import { priceSale, type SaleLineInput, type TaxMode } from "./sales.js";
import {
  assertAuthorized,
  AuthorizationError,
  type AuthenticatedPrincipal,
  type RequestedScope
} from "./security.js";

export interface ApiRequest {
  method: string;
  path: string;
  authorizationHeader?: string | undefined;
  bodyText?: string | undefined;
  requestId: string;
  now: Date;
}

export interface ApiResponse {
  statusCode: number;
  body: Readonly<Record<string, unknown>>;
}

export interface ApiHandler {
  handle(request: ApiRequest): Promise<ApiResponse>;
}

class RequestValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "RequestValidationError";
  }
}

function requiredString(
  value: unknown,
  field: string,
  maxLength = 128
): string {
  if (typeof value !== "string") {
    throw new RequestValidationError(`${field} must be a string`);
  }
  const normalized = value.trim();
  if (!normalized || normalized.length > maxLength) {
    throw new RequestValidationError(`${field} is invalid`);
  }
  return normalized;
}

function requiredSafeInteger(
  value: unknown,
  field: string,
  minimum: number,
  maximum: number
): number {
  if (
    typeof value !== "number" ||
    !Number.isSafeInteger(value) ||
    value < minimum ||
    value > maximum
  ) {
    throw new RequestValidationError(`${field} is invalid`);
  }
  return value;
}

function parseObjectBody(bodyText: string | undefined): Record<string, unknown> {
  if (bodyText === undefined || !bodyText.trim()) {
    throw new RequestValidationError("JSON request body is required");
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(bodyText);
  } catch {
    throw new RequestValidationError("Request body is not valid JSON");
  }

  if (
    parsed === null ||
    typeof parsed !== "object" ||
    Array.isArray(parsed)
  ) {
    throw new RequestValidationError("Request body must be a JSON object");
  }
  return parsed as Record<string, unknown>;
}

function parseScope(body: Record<string, unknown>): RequestedScope {
  return {
    organizationId: requiredString(
      body.organizationId,
      "organizationId"
    ),
    businessId: requiredString(body.businessId, "businessId"),
    storeId: requiredString(body.storeId, "storeId")
  };
}

function parseTaxMode(value: unknown): TaxMode {
  if (value !== "intra_state" && value !== "inter_state") {
    throw new RequestValidationError("taxMode is invalid");
  }
  return value;
}

function optionalDiscountSource(
  value: unknown
): SaleLineInput["discountSource"] | undefined {
  if (value === undefined) return undefined;
  if (
    value !== "manual" &&
    value !== "promotion" &&
    value !== "loyalty"
  ) {
    throw new RequestValidationError("discountSource is invalid");
  }
  return value;
}

function parseSaleLine(value: unknown, index: number): SaleLineInput {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new RequestValidationError(`lines[${index}] must be an object`);
  }
  const row = value as Record<string, unknown>;

  const discountSource = optionalDiscountSource(row.discountSource);
  const discountReferenceId =
    row.discountReferenceId === undefined
      ? undefined
      : requiredString(
          row.discountReferenceId,
          `lines[${index}].discountReferenceId`
        );

  return {
    productId: requiredString(
      row.productId,
      `lines[${index}].productId`
    ),
    name: requiredString(row.name, `lines[${index}].name`, 200),
    unitPriceMinor: requiredSafeInteger(
      row.unitPriceMinor,
      `lines[${index}].unitPriceMinor`,
      0,
      Number.MAX_SAFE_INTEGER
    ),
    quantityMilli: requiredSafeInteger(
      row.quantityMilli,
      `lines[${index}].quantityMilli`,
      1,
      1_000_000_000
    ),
    discountMinor: requiredSafeInteger(
      row.discountMinor,
      `lines[${index}].discountMinor`,
      0,
      Number.MAX_SAFE_INTEGER
    ),
    taxRateBps: requiredSafeInteger(
      row.taxRateBps,
      `lines[${index}].taxRateBps`,
      0,
      10000
    ),
    taxPriceMode:
      row.taxPriceMode === "inclusive" ||
      row.taxPriceMode === "exclusive"
        ? row.taxPriceMode
        : (() => {
            throw new RequestValidationError(
              `lines[${index}].taxPriceMode is invalid`
            );
          })(),
    ...(discountSource === undefined ? {} : { discountSource }),
    ...(discountReferenceId === undefined
      ? {}
      : { discountReferenceId })
  };
}

function parseSaleQuote(body: Record<string, unknown>): {
  scope: RequestedScope;
  taxMode: TaxMode;
  lines: readonly SaleLineInput[];
} {
  if (!Array.isArray(body.lines) || body.lines.length === 0) {
    throw new RequestValidationError("lines must contain at least one item");
  }
  if (body.lines.length > 500) {
    throw new RequestValidationError("lines exceeds the maximum of 500");
  }

  return {
    scope: parseScope(body),
    taxMode: parseTaxMode(body.taxMode),
    lines: body.lines.map((line, index) => parseSaleLine(line, index))
  };
}

function sessionBody(
  principal: AuthenticatedPrincipal,
  requestId: string
): Readonly<Record<string, unknown>> {
  return {
    requestId,
    userId: principal.userId,
    organizationId: principal.organizationId,
    businessIds: principal.businessIds,
    storeIds: principal.storeIds,
    role: principal.role
  };
}

function errorResponse(
  statusCode: number,
  code: string,
  message: string,
  requestId: string
): ApiResponse {
  return {
    statusCode,
    body: {
      code,
      message,
      requestId
    }
  };
}

export function createApiHandler(input: {
  authenticator: RequestAuthenticator;
}): ApiHandler {
  return {
    async handle(request): Promise<ApiResponse> {
      try {
        if (request.method === "GET" && request.path === "/v1/session") {
          const principal = await input.authenticator.authenticate({
            authorizationHeader: request.authorizationHeader,
            now: request.now,
            requestId: request.requestId
          });
          return {
            statusCode: 200,
            body: sessionBody(principal, request.requestId)
          };
        }

        if (
          request.method === "POST" &&
          request.path === "/v1/sales/quote"
        ) {
          const principal = await input.authenticator.authenticate({
            authorizationHeader: request.authorizationHeader,
            now: request.now,
            requestId: request.requestId
          });
          const payload = parseSaleQuote(parseObjectBody(request.bodyText));
          assertAuthorized(principal, payload.scope, "sale:create");
          const totals = priceSale(payload.lines, payload.taxMode);

          return {
            statusCode: 200,
            body: {
              requestId: request.requestId,
              scope: payload.scope,
              totals
            }
          };
        }

        return errorResponse(
          404,
          "NOT_FOUND",
          "Resource not found.",
          request.requestId
        );
      } catch (error) {
        if (error instanceof AuthenticationUnavailableError) {
          return errorResponse(
            503,
            "AUTHENTICATION_UNAVAILABLE",
            "Remote authentication is not configured.",
            request.requestId
          );
        }
        if (error instanceof AuthenticationError) {
          return errorResponse(
            401,
            "UNAUTHENTICATED",
            "Authentication is required.",
            request.requestId
          );
        }
        if (error instanceof AuthorizationError) {
          return errorResponse(
            403,
            "FORBIDDEN",
            "You do not have permission to perform this action.",
            request.requestId
          );
        }
        if (error instanceof RequestValidationError) {
          return errorResponse(
            400,
            "INVALID_REQUEST",
            error.message,
            request.requestId
          );
        }

        return errorResponse(
          400,
          "INVALID_REQUEST",
          "Request could not be processed.",
          request.requestId
        );
      }
    }
  };
}
