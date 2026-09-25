# V2.7 — Hardware & Device Foundation

## Purpose

V2.7 creates a common, terminal-scoped hardware capability model while keeping vendor SDKs outside the AaraaPOS business domain.

This milestone does **not** claim that physical hardware has been certified or tested.

## Device types

The architecture supports:
- barcode scanner
- receipt printer
- cash drawer
- weighing scale
- customer display
- payment terminal

Supported connection categories:
- built-in camera
- keyboard/wedge
- Bluetooth
- USB
- network
- provider-managed

## Capability model

Capabilities are explicit:
- scan barcode
- print receipt
- open cash drawer
- read weight
- display total
- take payment

A device cannot claim a capability that does not belong to its declared device type.

External Bluetooth/USB/network/provider devices marked configured require a non-secret configuration reference.

Secrets, credentials and regulated payment information are not stored in the device profile.

## Command provenance

Sensitive hardware actions carry:
- command ID
- device ID
- terminal ID
- capability
- idempotency key
- source entity type/ID when required

Cash drawer open requires provenance from:
- Sale
- Cash Movement
- Shift

Receipt printing requires provenance from:
- Sale
- Sale Return

This prevents arbitrary business code from issuing untraceable drawer/receipt commands.

## Flutter adapter boundaries

AaraaPOS now has explicit adapter contracts for:
- receipt printer
- cash drawer
- weighing scale
- customer display
- payment terminal

Unconfigured implementations fail explicitly.

They never return simulated hardware success.

Existing camera scanning remains the only direct application-level device integration in the current repository.

Keyboard/wedge scanning can continue to feed the existing barcode/search input.

## Readiness UX

More → Hardware & Devices displays capability readiness:

**App ready**
- camera barcode scanning
- keyboard/wedge barcode input path

**Adapter ready**
- receipt printer contract

**Needs integration**
- cash drawer
- weighing scale
- customer display
- payment terminal

The screen deliberately separates software readiness from physical-device certification.

## Server persistence

Migration `0016_hardware_devices.sql` adds:

### hardware_device_profile
- tenant/business/store/terminal scope
- device type
- connection type
- status
- capability list
- non-secret configuration reference
- lifecycle timestamps

### hardware_command_audit
- terminal/device scope
- capability
- source provenance
- requested/succeeded/failed/cancelled state
- idempotency key
- error code
- timestamp

Both tables use tenant row-level security.

## Payment terminals

Payment terminals remain coupled to the V1.1/V2.4 payment-provider contracts.

A hardware terminal can initiate a provider flow only after a real payment provider/device integration exists.

AaraaPOS does not handle card credentials or mark a payment captured because a hardware command was requested.

## Testing

Backend tests cover:
- device/capability compatibility
- external configured devices requiring configuration references
- drawer provenance
- receipt-print provenance

Flutter tests cover:
- truthful readiness states
- source-evidence validation
- unconfigured adapters failing instead of simulating success

## External boundary

Not claimed:
- Bluetooth printer SDK
- USB printer SDK
- ESC/POS device certification
- cash-drawer electrical/protocol integration
- weighing-scale protocol integration
- customer-display SDK integration
- payment-terminal/acquirer integration
- physical Android device compatibility certification
- production permission/device pairing workflows

These require selected hardware vendors and physical testing.
