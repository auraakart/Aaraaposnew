export type HardwareDeviceType =
  | "barcode_scanner"
  | "receipt_printer"
  | "cash_drawer"
  | "weighing_scale"
  | "customer_display"
  | "payment_terminal";

export type HardwareConnectionType =
  | "built_in_camera"
  | "keyboard_wedge"
  | "bluetooth"
  | "usb"
  | "network"
  | "provider";

export type HardwareCapability =
  | "scan_barcode"
  | "print_receipt"
  | "open_drawer"
  | "read_weight"
  | "display_total"
  | "take_payment";

export type HardwareDeviceStatus =
  | "configured"
  | "disabled"
  | "unavailable";

export interface HardwareDeviceProfile {
  id: string;
  organizationId: string;
  businessId: string;
  storeId: string;
  terminalId: string;
  type: HardwareDeviceType;
  connectionType: HardwareConnectionType;
  status: HardwareDeviceStatus;
  capabilities: readonly HardwareCapability[];
  configReference?: string;
}

export interface HardwareCommand {
  id: string;
  deviceId: string;
  terminalId: string;
  capability: HardwareCapability;
  idempotencyKey: string;
  sourceEntityType?: string;
  sourceEntityId?: string;
}

const capabilitiesByType: Readonly<
  Record<HardwareDeviceType, ReadonlySet<HardwareCapability>>
> = {
  barcode_scanner: new Set(["scan_barcode"]),
  receipt_printer: new Set(["print_receipt"]),
  cash_drawer: new Set(["open_drawer"]),
  weighing_scale: new Set(["read_weight"]),
  customer_display: new Set(["display_total"]),
  payment_terminal: new Set(["take_payment"])
};

export function validateHardwareDeviceProfile(
  profile: HardwareDeviceProfile
): void {
  for (const [field, value] of Object.entries({
    id: profile.id,
    organizationId: profile.organizationId,
    businessId: profile.businessId,
    storeId: profile.storeId,
    terminalId: profile.terminalId
  })) {
    if (!value.trim()) throw new Error(`${field} is required`);
  }

  if (profile.capabilities.length === 0) {
    throw new Error("Hardware device requires at least one capability");
  }

  const allowed = capabilitiesByType[profile.type];
  for (const capability of profile.capabilities) {
    if (!allowed.has(capability)) {
      throw new Error(
        `${profile.type} cannot declare capability ${capability}`
      );
    }
  }

  const adapterConnection =
    profile.connectionType === "bluetooth" ||
    profile.connectionType === "usb" ||
    profile.connectionType === "network" ||
    profile.connectionType === "provider";

  if (
    profile.status === "configured" &&
    adapterConnection &&
    !profile.configReference?.trim()
  ) {
    throw new Error(
      "Configured external hardware requires a non-secret config reference"
    );
  }
}

export function assertHardwareCommandAllowed(
  profile: HardwareDeviceProfile,
  command: HardwareCommand
): void {
  validateHardwareDeviceProfile(profile);
  if (profile.status !== "configured") {
    throw new Error("Hardware device is not configured");
  }
  if (
    command.deviceId !== profile.id ||
    command.terminalId !== profile.terminalId
  ) {
    throw new Error("Hardware command scope does not match the device");
  }
  if (!profile.capabilities.includes(command.capability)) {
    throw new Error("Hardware device does not support this capability");
  }
  if (!command.id.trim() || !command.idempotencyKey.trim()) {
    throw new Error("Hardware command identity is required");
  }

  if (command.capability === "open_drawer") {
    const allowedSources = new Set(["sale", "cash_movement", "shift"]);
    if (
      !command.sourceEntityType ||
      !command.sourceEntityId ||
      !allowedSources.has(command.sourceEntityType)
    ) {
      throw new Error(
        "Cash drawer commands require sale, cash movement or shift provenance"
      );
    }
  }

  if (command.capability === "print_receipt") {
    const allowedSources = new Set(["sale", "sale_return"]);
    if (
      !command.sourceEntityType ||
      !command.sourceEntityId ||
      !allowedSources.has(command.sourceEntityType)
    ) {
      throw new Error(
        "Receipt print commands require sale or return provenance"
      );
    }
  }
}

export function supportsHardwareCapability(
  profile: HardwareDeviceProfile,
  capability: HardwareCapability
): boolean {
  return (
    profile.status === "configured" &&
    profile.capabilities.includes(capability)
  );
}
