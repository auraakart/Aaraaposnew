import 'sale_domain.dart';

enum RefundMethod { cash, customerCredit, upi, card }

class HeldSale {
  const HeldSale({
    required this.id,
    required this.heldAt,
    required this.lines,
    this.customerId,
    this.customerName,
  });

  final String id;
  final DateTime heldAt;
  final String? customerId;
  final String? customerName;
  final List<SaleLineInput> lines;
}

class ReturnableSale {
  const ReturnableSale({
    required this.saleId,
    required this.invoiceNumber,
    required this.createdAt,
    required this.totalMinor,
    required this.paymentMethod,
    required this.lines,
    this.customerId,
    this.customerName,
  });

  final String saleId;
  final String invoiceNumber;
  final DateTime createdAt;
  final int totalMinor;
  final String paymentMethod;
  final String? customerId;
  final String? customerName;
  final List<ReturnableSaleLine> lines;
}

class ReturnableSaleLine {
  const ReturnableSaleLine({
    required this.saleLineId,
    required this.productId,
    required this.productName,
    required this.soldQuantityMilli,
    required this.returnedQuantityMilli,
    required this.taxableMinor,
    required this.cgstMinor,
    required this.sgstMinor,
    required this.igstMinor,
    required this.taxMinor,
    required this.totalMinor,
  });

  final String saleLineId;
  final String productId;
  final String productName;
  final int soldQuantityMilli;
  final int returnedQuantityMilli;
  final int taxableMinor;
  final int cgstMinor;
  final int sgstMinor;
  final int igstMinor;
  final int taxMinor;
  final int totalMinor;

  int get remainingQuantityMilli => soldQuantityMilli - returnedQuantityMilli;
}

class ReturnLineRequest {
  const ReturnLineRequest({
    required this.saleLineId,
    required this.quantityMilli,
  });

  final String saleLineId;
  final int quantityMilli;
}

class OfflineReturnResult {
  const OfflineReturnResult({
    required this.returnId,
    required this.returnNumber,
    required this.refundMinor,
    required this.refundMethod,
  });

  final String returnId;
  final String returnNumber;
  final int refundMinor;
  final RefundMethod refundMethod;
}

int prorateReturnMinor({
  required int originalMinor,
  required int partQuantityMilli,
  required int originalQuantityMilli,
}) {
  if (originalMinor < 0 ||
      partQuantityMilli < 0 ||
      originalQuantityMilli <= 0) {
    throw ArgumentError('Invalid return proration');
  }
  return (originalMinor * partQuantityMilli + originalQuantityMilli ~/ 2) ~/
      originalQuantityMilli;
}

bool discountRequiresApproval({
  required int lineGrossMinor,
  required int discountMinor,
  required String actorRole,
  int cashierSelfApprovalLimitBps = 500,
}) {
  if (lineGrossMinor <= 0 ||
      discountMinor < 0 ||
      discountMinor > lineGrossMinor ||
      cashierSelfApprovalLimitBps < 0) {
    throw ArgumentError('Invalid discount approval input');
  }
  if (discountMinor == 0 || actorRole == 'owner' || actorRole == 'manager') {
    return false;
  }
  if (actorRole == 'stock_worker') {
    return true;
  }
  final discountBps = discountMinor * 10000 ~/ lineGrossMinor;
  return discountBps > cashierSelfApprovalLimitBps;
}

String refundMethodValue(RefundMethod method) => switch (method) {
      RefundMethod.cash => 'cash',
      RefundMethod.customerCredit => 'customer_credit',
      RefundMethod.upi => 'upi',
      RefundMethod.card => 'card',
    };
