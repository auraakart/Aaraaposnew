import test from "node:test";
import assert from "node:assert/strict";
import {
  accountingRowsToCsv,
  buildAccountingManifest,
  type AccountingExportRow
} from "../src/accounting.js";

const sale: AccountingExportRow = {
  kind: "sales",
  sourceId: "sale-1",
  documentNumber: "INV-1",
  occurredAt: "2026-09-25T10:00:00Z",
  partyName: "Ramesh",
  description: "Retail sale",
  balanceEffect: "increase",
  grossMinor: 11800,
  discountMinor: 0,
  tax: {
    taxableMinor: 10000,
    cgstMinor: 900,
    sgstMinor: 900,
    igstMinor: 0,
    unclassifiedTaxMinor: 0
  },
  totalMinor: 11800,
  paymentMethod: "cash",
  status: "finalized"
};

test("accounting manifest preserves register and GST totals", () => {
  assert.deepEqual(buildAccountingManifest([sale]), {
    rowCount: 1,
    salesMinor: 11800,
    returnsMinor: 0,
    purchasesMinor: 0,
    expensesMinor: 0,
    customerCreditMinor: 0,
    supplierLedgerMinor: 0,
    salesTaxableMinor: 10000,
    salesCgstMinor: 900,
    salesSgstMinor: 900,
    salesIgstMinor: 0,
    returnsTaxableMinor: 0,
    returnsCgstMinor: 0,
    returnsSgstMinor: 0,
    returnsIgstMinor: 0,
    purchaseTaxableMinor: 0,
    purchaseCgstMinor: 0,
    purchaseSgstMinor: 0,
    purchaseIgstMinor: 0,
    purchaseUnclassifiedTaxMinor: 0
  });
});

test("accounting rows reject broken tax arithmetic", () => {
  assert.throws(() =>
    buildAccountingManifest([
      {
        ...sale,
        totalMinor: 11799
      }
    ])
  );
});

test("CSV neutralizes spreadsheet formula injection", () => {
  const csv = accountingRowsToCsv([
    {
      ...sale,
      partyName: "=HYPERLINK(\"https://bad.example\")",
      description: "+SUM(1,2)"
    }
  ]);
  assert.match(csv, /'=HYPERLINK/);
  assert.match(csv, /'\+SUM/);
});
