enum StockMovementType {
  opening,
  receive,
  sale,
  returnIn,
  adjustment,
  damage,
  loss,
  transferIn,
  transferOut,
}

enum StockHealth { healthy, low, outOfStock, negative }

String stockMovementTypeValue(StockMovementType type) => switch (type) {
      StockMovementType.opening => 'opening',
      StockMovementType.receive => 'receive',
      StockMovementType.sale => 'sale',
      StockMovementType.returnIn => 'return_in',
      StockMovementType.adjustment => 'adjustment',
      StockMovementType.damage => 'damage',
      StockMovementType.loss => 'loss',
      StockMovementType.transferIn => 'transfer_in',
      StockMovementType.transferOut => 'transfer_out',
    };

void validateStockMovement({
  required StockMovementType type,
  required int quantityDeltaMilli,
  String? reason,
}) {
  if (quantityDeltaMilli == 0) {
    throw ArgumentError('Stock movement cannot be zero');
  }

  const increaseTypes = {
    StockMovementType.opening,
    StockMovementType.receive,
    StockMovementType.returnIn,
    StockMovementType.transferIn,
  };
  const decreaseTypes = {
    StockMovementType.sale,
    StockMovementType.damage,
    StockMovementType.loss,
    StockMovementType.transferOut,
  };

  if (increaseTypes.contains(type) && quantityDeltaMilli <= 0) {
    throw ArgumentError('This movement must increase stock');
  }
  if (decreaseTypes.contains(type) && quantityDeltaMilli >= 0) {
    throw ArgumentError('This movement must reduce stock');
  }
  if ({
        StockMovementType.adjustment,
        StockMovementType.damage,
        StockMovementType.loss,
      }.contains(type) &&
      (reason == null || reason.trim().isEmpty)) {
    throw ArgumentError('A reason is required');
  }
}

int countAdjustmentDelta({
  required int currentOnHandMilli,
  required int countedMilli,
}) {
  if (countedMilli < 0) {
    throw ArgumentError('Counted stock cannot be negative');
  }
  return countedMilli - currentOnHandMilli;
}

StockHealth stockHealth({
  required int onHandMilli,
  required int reorderLevelMilli,
}) {
  if (reorderLevelMilli < 0) {
    throw ArgumentError('Reorder level cannot be negative');
  }
  if (onHandMilli < 0) return StockHealth.negative;
  if (onHandMilli == 0) return StockHealth.outOfStock;
  if (onHandMilli <= reorderLevelMilli) return StockHealth.low;
  return StockHealth.healthy;
}

String stockHealthLabel(StockHealth health) => switch (health) {
      StockHealth.healthy => 'Available',
      StockHealth.low => 'Running low',
      StockHealth.outOfStock => 'Out of stock',
      StockHealth.negative => 'Check stock',
    };


class LocalInventoryItem {
  const LocalInventoryItem({
    required this.productId,
    required this.name,
    required this.onHandMilli,
    required this.reorderLevelMilli,
    this.barcode,
  });

  final String productId;
  final String name;
  final String? barcode;
  final int onHandMilli;
  final int reorderLevelMilli;

  StockHealth get health => stockHealth(
        onHandMilli: onHandMilli,
        reorderLevelMilli: reorderLevelMilli,
      );
}
