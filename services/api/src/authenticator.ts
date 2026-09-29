import type { AuthenticatedPrincipal } from "./security.js";

export class AuthenticationError extends Error {
  constructor(message = "Authentication is required.") {
    super(message);
    this.name = "AuthenticationError";
  }
}

export class AuthenticationUnavailableError extends Error {
  constructor() {
    super("Remote authentication provider is not configured.");
    this.name = "AuthenticationUnavailableError";
  }
}

export interface AuthenticationInput {
  authorizationHeader?: string | undefined;
  now: Date;
  requestId: string;
}

export interface RequestAuthenticator {
  authenticate(input: AuthenticationInput): Promise<AuthenticatedPrincipal>;
}

export class UnconfiguredRequestAuthenticator
  implements RequestAuthenticator
{
  async authenticate(
    _input: AuthenticationInput
  ): Promise<AuthenticatedPrincipal> {
    throw new AuthenticationUnavailableError();
  }
}
