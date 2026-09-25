export type AccountingRegisterKind =
  | "sales"
  | "returns"
  | "purchases"
  | "expenses"
  | "customer_credit"
  | "supplier_ledger";

export interface AccountingTaxBreakdown {
  taxableMinor: number;
  cgstMinor: number;
  sgstMinor: number;
  igstMinor: number;
  unclassifiedTaxMinor: number;
}

export interface AccountingExportRow {
  kind: AccountingRegisterKind;
  sourceId: string;
  documentNumber?: string;
  occurredAt: string;
  partyName?: string;
  description: string;
  grossMinor: number;
  discountMinor: number;
  tax: AccountingTaxBreakdown;
  totalMinor: number;
  paymentMethod?: string;
  status?: string;
}

export interface AccountingExportManifest {
  rowCount: number;
  salesMinor: number;
  returnsMinor: number;
  purchasesMinor: number;
  expensesMinor: number;
  customerCreditMinor: number;
  supplierLedgerMinor: number;
  taxableMinor: number;
  cgstMinor: number;
  sgstMinor: number;
  igstMinor: number;
  unclassifiedTaxMinor: number;
}

function assertNonNegativeSafeInteger(value: number, field: string): void {
  if (!Number.isSafeInteger(value) || value < 0) {
    throw new Error(`${field} must be a non-negative safe integer`);
  }
}

export function validateAccountingExportRow(row: AccountingExportRow): void {
  if (!row.sourceId.trim() || !row.description.trim()) {
    throw new Error("Accounting export source and description are required");
  }
  if (Number.isNaN(Date.parse(row.occurredAt))) {
    throw new Error("Accounting export occurredAt must be an ISO date-time");
  }

  for (const [field, value] of Object.entries({
    grossMinor: row.grossMinor,
    discountMinor: row.discountMinor,
    taxableMinor: row.tax.taxableMinor,
    cgstMinor: row.tax.cgstMinor,
    sgstMinor: row.tax.sgstMinor,
    igstMinor: row.tax.igstMinor,
    unclassifiedTaxMinor: row.tax.unclassifiedTaxMinor,
    totalMinor: row.totalMinor
  })) {
    assertNonNegativeSafeInteger(value, field);
  }

  if (row.discountMinor > row.grossMinor) {
    throw new Error("Accounting export discount cannot exceed gross");
  }

  const taxMinor =
    row.tax.cgstMinor +
    row.tax.sgstMinor +
    row.tax.igstMinor +
    row.tax.unclassifiedTaxMinor;
  if (row.kind !== "expenses" && row.kind !== "supplier_ledger") {
    if (row.tax.taxableMinor + taxMinor !== row.totalMinor) {
      throw new Error(
        "Taxable amount plus tax must equal accounting row total"
      );
    }
  }
}

export function buildAccountingManifest(
  rows: readonly AccountingExportRow[]
): AccountingExportManifest {
  const manifest: AccountingExportManifest = {
    rowCount: rows.length,
    salesMinor: 0,
    returnsMinor: 0,
    purchasesMinor: 0,
    expensesMinor: 0,
    customerCreditMinor: 0,
    supplierLedgerMinor: 0,
    taxableMinor: 0,
    cgstMinor: 0,
    sgstMinor: 0,
    igstMinor: 0,
    unclassifiedTaxMinor: 0
  };

  for (const row of rows) {
    validateAccountingExportRow(row);
    manifest.taxableMinor += row.tax.taxableMinor;
    manifest.cgstMinor += row.tax.cgstMinor;
    manifest.sgstMinor += row.tax.sgstMinor;
    manifest.igstMinor += row.tax.igstMinor;
    manifest.unclassifiedTaxMinor += row.tax.unclassifiedTaxMinor;

    switch (row.kind) {
      case "sales":
        manifest.salesMinor += row.totalMinor;
        break;
      case "returns":
        manifest.returnsMinor += row.totalMinor;
        break;
      case "purchases":
        manifest.purchasesMinor += row.totalMinor;
        break;
      case "expenses":
        manifest.expensesMinor += row.totalMinor;
        break;
      case "customer_credit":
        manifest.customerCreditMinor += row.totalMinor;
        break;
      case "supplier_ledger":
        manifest.supplierLedgerMinor += row.totalMinor;
        break;
    }
  }

  return manifest;
}

function safeSpreadsheetText(value: string): string {
  const normalized = value.replace(/[\r\n]+/g, " ").trim();
  return /^[=+\-@]/.test(normalized) ? `'${normalized}` : normalized;
}

function csvCell(value: string | number | undefined): string {
  const text = safeSpreadsheetText(value === undefined ? "" : String(value));
  return `"${text.replaceAll('"', '""')}"`;
}

export function accountingRowsToCsv(
  rows: readonly AccountingExportRow[]
): string {
  const header = [
    "Register",
    "Source ID",
    "Document Number",
    "Occurred At",
    "Party",
    "Description",
    "Gross Minor",
    "Discount Minor",
    "Taxable Minor",
    "CGST Minor",
    "SGST Minor",
    "IGST Minor",
    "Unclassified Tax Minor",
    "Total Minor",
    "Payment Method",
    "Status"
  ];

  const lines = [header.map(csvCell).join(",")];

  for (const row of rows) {
    validateAccountingExportRow(row);
    lines.push(
      [
        row.kind,
        row.sourceId,
        row.documentNumber,
        row.occurredAt,
        row.partyName,
        row.description,
        row.grossMinor,
        row.discountMinor,
        row.tax.taxableMinor,
        row.tax.cgstMinor,
        row.tax.sgstMinor,
        row.tax.igstMinor,
        row.tax.unclassifiedTaxMinor,
        row.totalMinor,
        row.paymentMethod,
        row.status
      ]
        .map(csvCell)
        .join(",")
    );
  }

  return lines.join("\n");
}
