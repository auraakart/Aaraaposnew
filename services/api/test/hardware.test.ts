import test from "node:test";
import assert from "node:assert/strict";
import {
  assertHardwareCommandAllowed,
  supportsHardwareCapability,
  validateHardwareDeviceProfile,
  type HardwareDeviceProfile
} from "../src/hardware.js";

const cameraScanner: HardwareDeviceProfile = {
  id: "camera-1",
  organizationId: "org-1",
  businessId: "business-1",
  storeId: "store-1",
  terminalId: "terminal-1",
  type: "barcode_scanner",
  connectionType: "built_in_camera",
  status: "configured",
  capabilities: ["scan_barcode"]
};

test("built-in camera may expose only scanner capability", () => {
  assert.doesNotThrow(() => validateHardwareDeviceProfile(cameraScanner));
  assert.equal(
    supportsHardwareCapability(cameraScanner, "scan_barcode"),
    true
  );
});

test("external configured hardware requires config reference", () => {
  assert.throws(() =>
    validateHardwareDeviceProfile({
      ...cameraScanner,
      id: "printer-1",
      type: "receipt_printer",
      connectionType: "bluetooth",
      capabilities: ["print_receipt"]
    })
  );
});

test("cash drawer command requires financial provenance", () => {
  const drawer: HardwareDeviceProfile = {
    ...cameraScanner,
    id: "drawer-1",
    type: "cash_drawer",
    connectionType: "usb",
    capabilities: ["open_drawer"],
    configReference: "terminal-device:drawer-1"
  };

  assert.throws(() =>
    assertHardwareCommandAllowed(drawer, {
      id: "command-1",
      deviceId: "drawer-1",
      terminalId: "terminal-1",
      capability: "open_drawer",
      idempotencyKey: "drawer-command-1"
    })
  );

  assert.doesNotThrow(() =>
    assertHardwareCommandAllowed(drawer, {
      id: "command-2",
      deviceId: "drawer-1",
      terminalId: "terminal-1",
      capability: "open_drawer",
      idempotencyKey: "drawer-command-2",
      sourceEntityType: "sale",
      sourceEntityId: "sale-1"
    })
  );
});

test("receipt print command cannot be attached to arbitrary source", () => {
  const printer: HardwareDeviceProfile = {
    ...cameraScanner,
    id: "printer-1",
    type: "receipt_printer",
    connectionType: "network",
    capabilities: ["print_receipt"],
    configReference: "terminal-device:printer-1"
  };

  assert.throws(() =>
    assertHardwareCommandAllowed(printer, {
      id: "command-1",
      deviceId: "printer-1",
      terminalId: "terminal-1",
      capability: "print_receipt",
      idempotencyKey: "print-command-1",
      sourceEntityType: "customer",
      sourceEntityId: "customer-1"
    })
  );
});
