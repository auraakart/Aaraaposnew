# V2.15 — Identity & Local Session Foundation

## Purpose

V2.15 closes the mobile/offline identity gap without pretending that a device-local PIN is a cloud account credential.

AaraaPOS now distinguishes:

1. **Local device identity** — who is currently using this offline POS terminal.
2. **Remote authentication** — future server/identity-provider evidence used to call authenticated APIs.

The local PIN is never accepted as remote authentication.

## First-run and migrated-store behavior

After store bootstrap, or after upgrading an existing local store with no configured local credentials:

- the Owner is prompted to create a 4–8 digit local PIN,
- the PIN is confirmed before saving,
- the Owner is signed into an expiring local session,
- the PIN itself is never stored.

Subsequent launches:

- restore a still-valid terminal session, or
- require employee sign-in when the session is absent/expired.

## Local PIN storage

The terminal stores:

- employee ID
- random salt
- PBKDF2-HMAC-SHA256-derived PIN hash
- iteration count
- failed-attempt count
- temporary lock-until timestamp
- update timestamp

Default derivation iterations: 40,000.

The local credential record is **not** added to the sync outbox.

PIN, salt and PIN hash are not written into audit metadata.

## Failed-attempt policy

- Attempts 1–4: sign-in rejected.
- Attempt 5+: PIN temporarily locked for 5 minutes.
- At 10+ failed attempts: lock duration becomes 30 minutes.
- A successful sign-in resets failed-attempt state.

Failed-attempt persistence is committed before the authentication error is returned, so transaction rollback cannot erase the lockout evidence.

## Local session policy

A terminal has at most one active local employee session.

Default session duration: 12 hours.

Maximum allowed local session TTL: 24 hours.

The application:

- restores an unexpired session after restart,
- discards expired/inactive-employee sessions,
- automatically locks when the in-memory session expires,
- exposes **Lock / switch user** in the application bar.

Default landing screens:

- Owner → Home / Business Today
- Manager → Home / Business Today
- Cashier → Sell
- Stock Worker → Stock

Existing domain/database authorization remains the action-security boundary.

## Employee access administration

More → Employee Access lets authorized local users provision/reset employee PINs.

Authority:

- Owner can manage all active employee local PINs.
- Manager can manage Cashier/Stock Worker PINs.
- Manager can reset their own PIN.
- Manager cannot reset Owner PINs.
- Manager cannot reset another Manager PIN.

Resetting the current user’s PIN invalidates the persisted local session and returns the app to sign-in.

## Audit behavior

Safe audit events are generated for:

- local PIN configured/reset
- local session started
- local session ended

Audit metadata contains only non-secret identity/event descriptors.

The credential hash/salt never enters sync payloads.

## Remote authentication boundary

The server defines a separate remote-session contract supporting only:

- OIDC
- passwordless provider evidence
- service token

Remote sessions require:

- session ID
- subject/user identity
- organization scope
- business scope
- store scope
- role
- issue/expiry time
- bounded lifetime

The server explicitly rejects `local_pin` as a remote authentication method.

V2.15 does **not** issue or validate cryptographically signed network tokens because no production identity provider is configured yet.

## Testing

Flutter/domain tests cover:

- PIN format
- salt-dependent hash derivation
- exact PIN verification
- lockout timing
- session expiry semantics

SQLite tests cover:

- initial Owner PIN configuration
- failed-attempt persistence
- fifth-attempt lockout
- locked correct-PIN rejection
- post-lock successful sign-in
- session restore
- explicit session end
- expired session cleanup
- Owner provisioning Cashier PIN
- employee identity replacing Owner actor in session context
- Manager authority boundaries
- local credential never entering the sync outbox

Server tests cover:

- valid remote session → authenticated principal
- expired remote session rejection
- maximum session lifetime
- explicit rejection of local PIN as remote authentication

## External boundary

Not claimed in V2.15:

- production OIDC/passwordless provider
- OTP/SMS/email delivery
- server password storage
- cloud PIN synchronization
- secure-enclave/keystore credential storage
- biometric sign-in
- remote PIN reset
- central session revocation
- device attestation
- production token signing/verification
- multi-device identity federation

Those require production identity infrastructure and platform security integration.
