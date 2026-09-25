import 'package:flutter/material.dart';

import '../sell/local_pos_database.dart';
import 'inventory_domain.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({
    required this.database,
    required this.saleContext,
    super.key,
  });

  final LocalPosDatabase database;
  final LocalSaleContext saleContext;

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List<LocalInventoryItem> items = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final value = await widget.database.listInventory();
    if (!mounted) return;
    setState(() {
      items = value;
      loading = false;
    });
  }

  Future<void> receive(LocalInventoryItem item) async {
    final value = await _quantityDialog(
      title: 'Receive ${item.name}',
      action: 'Receive',
    );
    if (value == null || value <= 0) return;
    await widget.database.recordStockMovement(
      context: widget.saleContext,
      productId: item.productId,
      type: StockMovementType.receive,
      quantityDeltaMilli: value,
    );
    await refresh();
  }

  Future<void> count(LocalInventoryItem item) async {
    final value = await _quantityDialog(
      title: 'Count ${item.name}',
      action: 'Save count',
    );
    if (value == null) return;
    await widget.database.countStock(
      context: widget.saleContext,
      productId: item.productId,
      countedMilli: value,
      reason: 'Stock count',
    );
    await refresh();
  }

  Future<void> reduce(
    LocalInventoryItem item,
    StockMovementType type,
    String label,
  ) async {
    final value = await _quantityDialog(
      title: '$label ${item.name}',
      action: 'Record',
    );
    if (value == null || value <= 0) return;
    await widget.database.recordStockMovement(
      context: widget.saleContext,
      productId: item.productId,
      type: type,
      quantityDeltaMilli: -value,
      reason: label,
    );
    await refresh();
  }

  Future<void> setReorder(LocalInventoryItem item) async {
    final value = await _quantityDialog(
      title: 'Low-stock alert for ${item.name}',
      action: 'Save',
      initial: item.reorderLevelMilli,
    );
    if (value == null) return;
    await widget.database.setReorderLevel(
      productId: item.productId,
      reorderLevelMilli: value,
    );
    await refresh();
  }

  Future<int?> _quantityDialog({
    required String title,
    required String action,
    int? initial,
  }) async {
    final controller = TextEditingController(
      text: initial == null ? '' : formatQuantity(initial),
    );
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Quantity',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = parseQuantityToMilli(controller.text);
              if (value != null) Navigator.pop(dialogContext, value);
            },
            child: Text(action),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return const Center(
        child: Text('No products yet. Add products from Sell first.'),
      );
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Card(
            child: ListTile(
              leading: Icon(_icon(item.health)),
              title: Text(item.name),
              subtitle: Text(_message(item)),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'receive') await receive(item);
                  if (value == 'count') await count(item);
                  if (value == 'damage') {
                    await reduce(item, StockMovementType.damage, 'Damaged');
                  }
                  if (value == 'loss') {
                    await reduce(item, StockMovementType.loss, 'Lost');
                  }
                  if (value == 'reorder') await setReorder(item);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'receive', child: Text('Receive stock')),
                  PopupMenuItem(value: 'count', child: Text('Count stock')),
                  PopupMenuItem(
                    value: 'damage',
                    child: Text('Record damaged stock'),
                  ),
                  PopupMenuItem(value: 'loss', child: Text('Record lost stock')),
                  PopupMenuItem(
                    value: 'reorder',
                    child: Text('Set low-stock alert'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

String _message(LocalInventoryItem item) {
  final quantity = formatQuantity(item.onHandMilli);
  if (item.health == StockHealth.low) {
    return 'Only $quantity left — buy more';
  }
  if (item.health == StockHealth.outOfStock) {
    return 'Out of stock — buy more';
  }
  if (item.health == StockHealth.negative) {
    return 'Stock is below zero — check count';
  }
  return '$quantity available';
}

IconData _icon(StockHealth health) {
  if (health == StockHealth.healthy) return Icons.check_circle_outline;
  if (health == StockHealth.low) return Icons.inventory_2_outlined;
  if (health == StockHealth.outOfStock) return Icons.remove_circle_outline;
  return Icons.error_outline;
}

String formatQuantity(int milli) {
  final sign = milli < 0 ? '-' : '';
  final absolute = milli.abs();
  final whole = absolute ~/ 1000;
  final fraction = (absolute % 1000).toString().padLeft(3, '0');
  if (fraction == '000') return '$sign$whole';
  final trimmed = fraction.replaceFirst(RegExp(r'0+$'), '');
  return '$sign$whole.$trimmed';
}

int? parseQuantityToMilli(String value) {
  final text = value.trim();
  if (!RegExp(r'^\d+(\.\d{0,3})?$').hasMatch(text)) return null;
  final parts = text.split('.');
  final whole = int.parse(parts.first);
  final fraction = parts.length == 1 ? '000' : parts[1].padRight(3, '0');
  return whole * 1000 + int.parse(fraction);
}
