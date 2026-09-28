# V2.10 — Quality & Security Gates

## Purpose

V2.10 hardens the repository-level definition of done without claiming production infrastructure or device builds that do not exist in the repository.

The milestone focuses on low-cost controls that can run on every pull request.

## Repository policy gate

The API quality job now runs:

`npm run policy`

The policy validates:

### Migration safety
- migration filenames use a four-digit ordered prefix
- migration sequence is contiguous
- every migration is transaction-wrapped with BEGIN/COMMIT
- destructive SQL such as DROP TABLE, DROP COLUMN, TRUNCATE or DELETE FROM is rejected unless the migration contains the explicit review marker:
  `-- policy: destructive-reviewed`

The review marker does not make destructive SQL safe by itself. It makes the exception visible and deliberate.

### Dependency-source policy

Node dependencies are rejected when they use:
- latest
- wildcard
- direct HTTP(S)
- git
- file
- GitHub source references

If runtime Node dependencies are introduced, a committed package-lock.json becomes mandatory.

The current API has no runtime dependencies; TypeScript and Node typings remain development-only.

Flutter dependency policy rejects:
- nested git dependency sources
- nested path dependency sources
- unconstrained `any` versions

### Secret/config hygiene

Repository source/database files are scanned for common high-risk committed-secret patterns:
- private keys
- credential-bearing PostgreSQL URLs
- hard-coded password/client-secret/API-key assignments
- OpenAI-style secret tokens

The policy is intentionally narrow to reduce false positives. It is not a substitute for organization-wide secret scanning.

## Dependency vulnerability gate

The API CI resolves the current dependency graph and then runs:

`npm audit --audit-level=high`

High/critical npm vulnerabilities fail the pull request.

GitHub's Dependency Review action was evaluated but the repository Dependency Graph is currently disabled, so V2.10 does not depend on that external repository setting.

This audit is still not fully reproducible until an API lockfile is committed.

## Dependabot

Low-noise weekly dependency updates are configured for:

- npm: `/services/api`
- pub: `/apps/pos_mobile`

Minor and patch updates are grouped, and open automated PRs are capped to reduce maintenance noise.

Major upgrades remain separate decisions because they may require architectural or migration review.

## Existing gates retained

Every PR to develop/main continues to run:
- API repository policy
- TypeScript typecheck
- API tests
- Flutter pub resolution
- Flutter static analysis
- Flutter tests
- foundation baseline checks

Develop pushes continue to run the normal CI suite.

## Explicit repository gaps

### Android build gate

**Closed by V2.17.**

V2.17 committed the Flutter-generated Android platform scaffold and added a real `flutter build apk --debug --no-pub` CI gate.

Production signing and physical-device validation remain separate release/integration work.

### Lockfile reproducibility

**Closed by V2.17.**

V2.17 committed:
- `services/api/package-lock.json`
- `apps/pos_mobile/pubspec.lock`

CI now uses `npm ci` and `flutter pub get --enforce-lockfile`.

## Boundary

Not claimed:
- production SAST/SIEM integration
- organization-wide secret scanning
- SBOM generation
- container/image scanning
- Android APK build/signing
- physical-device testing
- deterministic Flutter dependency lock
- production penetration testing
- compliance certification

These require separate platform/production milestones.
