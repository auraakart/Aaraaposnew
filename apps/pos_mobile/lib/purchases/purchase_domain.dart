class LocalSupplier {
  const LocalSupplier({
    required this.id,
    required this.name,
    required this.balanceMinor,
    this.mobile,
    this.gstin,
  });

  final String id;
  final String name;
  final String? mobile;
  final String? gstin;
  final int balanceMinor;
}

class LocalPurchaseOrder {
  const LocalPurchaseOrder({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.orderNumber,
    required this.status,
    required this.orderedAt,
    required this.totalMinor,
    required this.lines,
  });

  final String id;
  final String supplierId;
  final String supplierName;
  final String orderNumber;
  final String status;
  final DateTime orderedAt;
  final int totalMinor;
  final List<LocalPurchaseOrderLine> lines;
}

class LocalPurchaseOrderLine {
  const LocalPurchaseOrderLine({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantityOrderedMilli,
    required this.quantityReceivedMilli,
    required this.unitCostMinor,
    required this.taxMinor,
  });

  final String id;
  final String productId;
  final String productName;
  final int quantityOrderedMilli;
  final int quantityReceivedMilli;
  final int unitCostMinor;
  final int taxMinor;

  int get remainingMilli => quantityOrderedMilli - quantityReceivedMilli;

  int get lineTotalMinor {
    final net = (unitCostMinor * quantityOrderedMilli + 500) ~/ 1000;
    return net + taxMinor;
  }
}

class SupplierLedgerEntry {
  const SupplierLedgerEntry({
    required this.id,
    required this.type,
    required this.amountMinor,
    required this.occurredAt,
    this.note,
  });

  final String id;
  final String type;
  final int amountMinor;
  final DateTime occurredAt;
  final String? note;
}

int purchaseLineTotalMinor({
  required int quantityMilli,
  required int unitCostMinor,
  int taxMinor = 0,
}) {
  if (quantityMilli <= 0 || unitCostMinor <= 0 || taxMinor < 0) {
    throw ArgumentError('Invalid purchase line');
  }
  return (unitCostMinor * quantityMilli + 500) ~/ 1000 + taxMinor;
}
