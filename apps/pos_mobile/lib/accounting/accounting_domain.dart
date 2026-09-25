enum AccountingRegisterKind {
  sales,
  returns,
  purchases,
  expenses,
  customerCredit,
  supplierLedger,
}

class AccountingTaxBreakdown {
  const AccountingTaxBreakdown({
    required this.taxableMinor,
    required this.cgstMinor,
    required this.sgstMinor,
    required this.igstMinor,
    required this.unclassifiedTaxMinor,
  });

  final int taxableMinor;
  final int cgstMinor;
  final int sgstMinor;
  final int igstMinor;
  final int unclassifiedTaxMinor;

  int get totalTaxMinor =>
      cgstMinor + sgstMinor + igstMinor + unclassifiedTaxMinor;
}

class AccountingExportRow {
  const AccountingExportRow({
    required this.kind,
    required this.sourceId,
    required this.occurredAt,
    required this.description,
    required this.balanceEffect,
    required this.grossMinor,
    required this.discountMinor,
    required this.tax,
    required this.totalMinor,
    this.documentNumber,
    this.partyName,
    this.paymentMethod,
    this.status,
  });

  final AccountingRegisterKind kind;
  final String sourceId;
  final String? documentNumber;
  final DateTime occurredAt;
  final String? partyName;
  final String description;
  final String balanceEffect;
  final int grossMinor;
  final int discountMinor;
  final AccountingTaxBreakdown tax;
  final int totalMinor;
  final String? paymentMethod;
  final String? status;
}

class AccountingExportManifest {
  const AccountingExportManifest({
    required this.rowCount,
    required this.salesMinor,
    required this.returnsMinor,
    required this.purchasesMinor,
    required this.expensesMinor,
    required this.customerCreditMinor,
    required this.supplierLedgerMinor,
    required this.taxableMinor,
    required this.cgstMinor,
    required this.sgstMinor,
    required this.igstMinor,
    required this.unclassifiedTaxMinor,
  });

  final int rowCount;
  final int salesMinor;
  final int returnsMinor;
  final int purchasesMinor;
  final int expensesMinor;
  final int customerCreditMinor;
  final int supplierLedgerMinor;
  final int taxableMinor;
  final int cgstMinor;
  final int sgstMinor;
  final int igstMinor;
  final int unclassifiedTaxMinor;
}

String accountingRegisterValue(AccountingRegisterKind kind) => switch (kind) {
      AccountingRegisterKind.sales => 'sales',
      AccountingRegisterKind.returns => 'returns',
      AccountingRegisterKind.purchases => 'purchases',
      AccountingRegisterKind.expenses => 'expenses',
      AccountingRegisterKind.customerCredit => 'customer_credit',
      AccountingRegisterKind.supplierLedger => 'supplier_ledger',
    };

String accountingRegisterLabel(AccountingRegisterKind kind) => switch (kind) {
      AccountingRegisterKind.sales => 'Sales',
      AccountingRegisterKind.returns => 'Returns',
      AccountingRegisterKind.purchases => 'Purchases',
      AccountingRegisterKind.expenses => 'Expenses',
      AccountingRegisterKind.customerCredit => 'Customer Credit',
      AccountingRegisterKind.supplierLedger => 'Supplier Ledger',
    };

void validateAccountingRow(AccountingExportRow row) {
  if (row.sourceId.trim().isEmpty || row.description.trim().isEmpty) {
    throw ArgumentError('Accounting source and description are required');
  }
  final values = [
    row.grossMinor,
    row.discountMinor,
    row.tax.taxableMinor,
    row.tax.cgstMinor,
    row.tax.sgstMinor,
    row.tax.igstMinor,
    row.tax.unclassifiedTaxMinor,
    row.totalMinor,
  ];
  if (values.any((value) => value < 0)) {
    throw ArgumentError('Accounting amounts cannot be negative');
  }
  if (row.discountMinor > row.grossMinor) {
    throw ArgumentError('Accounting discount cannot exceed gross');
  }

  final taxBearing = row.kind == AccountingRegisterKind.sales ||
      row.kind == AccountingRegisterKind.returns ||
      row.kind == AccountingRegisterKind.purchases;
  if (taxBearing &&
      row.tax.taxableMinor + row.tax.totalTaxMinor != row.totalMinor) {
    throw ArgumentError('Taxable amount plus tax must equal total');
  }
}

AccountingExportManifest buildAccountingManifest(
  List<AccountingExportRow> rows,
) {
  var sales = 0;
  var returns = 0;
  var purchases = 0;
  var expenses = 0;
  var customerCredit = 0;
  var supplierLedger = 0;
  var taxable = 0;
  var cgst = 0;
  var sgst = 0;
  var igst = 0;
  var unclassified = 0;

  for (final row in rows) {
    validateAccountingRow(row);
    taxable += row.tax.taxableMinor;
    cgst += row.tax.cgstMinor;
    sgst += row.tax.sgstMinor;
    igst += row.tax.igstMinor;
    unclassified += row.tax.unclassifiedTaxMinor;

    switch (row.kind) {
      case AccountingRegisterKind.sales:
        sales += row.totalMinor;
        break;
      case AccountingRegisterKind.returns:
        returns += row.totalMinor;
        break;
      case AccountingRegisterKind.purchases:
        purchases += row.totalMinor;
        break;
      case AccountingRegisterKind.expenses:
        expenses += row.totalMinor;
        break;
      case AccountingRegisterKind.customerCredit:
        customerCredit += row.totalMinor;
        break;
      case AccountingRegisterKind.supplierLedger:
        supplierLedger += row.totalMinor;
        break;
    }
  }

  return AccountingExportManifest(
    rowCount: rows.length,
    salesMinor: sales,
    returnsMinor: returns,
    purchasesMinor: purchases,
    expensesMinor: expenses,
    customerCreditMinor: customerCredit,
    supplierLedgerMinor: supplierLedger,
    taxableMinor: taxable,
    cgstMinor: cgst,
    sgstMinor: sgst,
    igstMinor: igst,
    unclassifiedTaxMinor: unclassified,
  );
}

String accountingRowsToCsv(List<AccountingExportRow> rows) {
  final header = [
    'Register',
    'Source ID',
    'Document Number',
    'Occurred At',
    'Party',
    'Description',
    'Balance Effect',
    'Gross',
    'Discount',
    'Taxable',
    'CGST',
    'SGST',
    'IGST',
    'Unclassified Tax',
    'Total',
    'Payment Method',
    'Status',
  ];

  final output = <String>[header.map(_csvCell).join(',')];
  for (final row in rows) {
    validateAccountingRow(row);
    output.add(
      [
        accountingRegisterValue(row.kind),
        row.sourceId,
        row.documentNumber ?? '',
        row.occurredAt.toUtc().toIso8601String(),
        row.partyName ?? '',
        row.description,
        row.balanceEffect,
        _moneyDecimal(row.grossMinor),
        _moneyDecimal(row.discountMinor),
        _moneyDecimal(row.tax.taxableMinor),
        _moneyDecimal(row.tax.cgstMinor),
        _moneyDecimal(row.tax.sgstMinor),
        _moneyDecimal(row.tax.igstMinor),
        _moneyDecimal(row.tax.unclassifiedTaxMinor),
        _moneyDecimal(row.totalMinor),
        row.paymentMethod ?? '',
        row.status ?? '',
      ].map(_csvCell).join(','),
    );
  }
  return output.join('\n');
}

String _moneyDecimal(int minor) =>
    '${minor ~/ 100}.${(minor % 100).toString().padLeft(2, '0')}';

String _csvCell(Object value) {
  var text = value.toString().replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
  if (RegExp(r'^[=+\-@]').hasMatch(text)) {
    text = "'$text";
  }
  return '"${text.replaceAll('"', '""')}"';
}
