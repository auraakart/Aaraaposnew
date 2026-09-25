import 'package:flutter/material.dart';

import '../sell/local_pos_database.dart';
import '../sell/sale_domain.dart';
import 'purchase_domain.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({
    required this.database,
    required this.saleContext,
    super.key,
  });

  final LocalPosDatabase database;
  final LocalSaleContext saleContext;

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  List<LocalSupplier> suppliers = const [];
  List<LocalPurchaseOrder> orders = const [];
  List<Product> products = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final loadedSuppliers = await widget.database.listSuppliers();
    final loadedOrders = await widget.database.listPurchaseOrders();
    final loadedProducts = await widget.database.listProducts();
    if (!mounted) return;
    setState(() {
      suppliers = loadedSuppliers;
      orders = loadedOrders;
      products = loadedProducts;
      loading = false;
    });
  }

  Future<void> addSupplier() async {
    final name = TextEditingController();
    final mobile = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add supplier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Supplier name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: mobile,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              await widget.database.addSupplier(
                name: name.text,
                mobile: mobile.text,
              );
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    name.dispose();
    mobile.dispose();
    if (created == true) await refresh();
  }

  Future<void> createOrder() async {
    if (suppliers.isEmpty || products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one supplier and product first.'),
        ),
      );
      return;
    }

    var supplierId = suppliers.first.id;
    var productId = products.first.id;
    final quantity = TextEditingController(text: '1');
    final cost = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create purchase order'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: supplierId,
                  decoration: const InputDecoration(labelText: 'Supplier'),
                  items: [
                    for (final supplier in suppliers)
                      DropdownMenuItem(
                        value: supplier.id,
                        child: Text(supplier.name),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => supplierId = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: productId,
                  decoration: const InputDecoration(labelText: 'Product'),
                  items: [
                    for (final product in products)
                      DropdownMenuItem(
                        value: product.id,
                        child: Text(product.name),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => productId = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: quantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cost,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Cost per unit ₹',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final quantityMilli = _parseQuantity(quantity.text);
                final unitCostMinor = _parseMoney(cost.text);
                if (quantityMilli == null ||
                    quantityMilli <= 0 ||
                    unitCostMinor == null ||
                    unitCostMinor <= 0) {
                  return;
                }
                await widget.database.createPurchaseOrder(
                  context: widget.saleContext,
                  supplierId: supplierId,
                  productId: productId,
                  quantityMilli: quantityMilli,
                  unitCostMinor: unitCostMinor,
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Create order'),
            ),
          ],
        ),
      ),
    );
    quantity.dispose();
    cost.dispose();
    if (created == true) await refresh();
  }

  Future<void> receive(LocalPurchaseOrder order) async {
    await widget.database.receivePurchaseOrder(
      context: widget.saleContext,
      purchaseOrderId: order.id,
    );
    await refresh();
  }

  Future<void> paySupplier(LocalSupplier supplier) async {
    final amount = TextEditingController();
    final paid = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Pay ${supplier.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Outstanding ${formatInr(supplier.balanceMinor)}'),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Payment ₹',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final value = _parseMoney(amount.text);
              if (value == null ||
                  value <= 0 ||
                  value > supplier.balanceMinor) {
                return;
              }
              await widget.database.paySupplier(
                context: widget.saleContext,
                supplierId: supplier.id,
                amountMinor: value,
              );
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Record payment'),
          ),
        ],
      ),
    );
    amount.dispose();
    if (paid == true) await refresh();
  }

  Future<void> returnStock(LocalSupplier supplier) async {
    if (products.isEmpty) return;
    var productId = products.first.id;
    final quantity = TextEditingController();
    final credit = TextEditingController();
    final reason = TextEditingController(text: 'Purchase return');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Return stock to ${supplier.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: productId,
                  decoration: const InputDecoration(labelText: 'Product'),
                  items: [
                    for (final product in products)
                      DropdownMenuItem(
                        value: product.id,
                        child: Text(product.name),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => productId = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: quantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Quantity returned',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: credit,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Supplier credit ₹',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reason,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final quantityMilli = _parseQuantity(quantity.text);
                final creditMinor = _parseMoney(credit.text);
                if (quantityMilli == null ||
                    quantityMilli <= 0 ||
                    creditMinor == null ||
                    creditMinor <= 0 ||
                    reason.text.trim().isEmpty) {
                  return;
                }
                await widget.database.recordPurchaseReturn(
                  context: widget.saleContext,
                  supplierId: supplier.id,
                  productId: productId,
                  quantityMilli: quantityMilli,
                  creditMinor: creditMinor,
                  reason: reason.text,
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Record return'),
            ),
          ],
        ),
      ),
    );
    quantity.dispose();
    credit.dispose();
    reason.dispose();
    if (saved == true) await refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: addSupplier,
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Add supplier'),
              ),
              FilledButton.tonalIcon(
                onPressed: createOrder,
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Create order'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Suppliers', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (suppliers.isEmpty)
            const Card(
              child: ListTile(
                title: Text('No suppliers yet'),
                subtitle: Text('Add a supplier before creating an order.'),
              ),
            ),
          for (final supplier in suppliers)
            Card(
              child: ListTile(
                title: Text(supplier.name),
                subtitle: Text(
                  supplier.balanceMinor > 0
                      ? '${formatInr(supplier.balanceMinor)} to pay'
                      : supplier.balanceMinor < 0
                          ? 'Supplier owes ${formatInr(-supplier.balanceMinor)}'
                          : 'Nothing due',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'pay') paySupplier(supplier);
                    if (value == 'return') returnStock(supplier);
                  },
                  itemBuilder: (_) => [
                    if (supplier.balanceMinor > 0)
                      const PopupMenuItem(
                        value: 'pay',
                        child: Text('Record payment'),
                      ),
                    const PopupMenuItem(
                      value: 'return',
                      child: Text('Return stock'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          Text('Purchase orders', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (orders.isEmpty)
            const Card(
              child: ListTile(
                title: Text('No purchase orders yet'),
                subtitle: Text('Create an order when stock needs replenishing.'),
              ),
            ),
          for (final order in orders)
            Card(
              child: ListTile(
                title: Text('${order.orderNumber} • ${order.supplierName}'),
                subtitle: Text(
                  '${order.lines.first.productName} • '
                  '${_formatQuantity(order.lines.first.quantityOrderedMilli)} ordered • '
                  '${formatInr(order.totalMinor)}',
                ),
                trailing: order.status == 'ordered'
                    ? FilledButton.tonal(
                        onPressed: () => receive(order),
                        child: const Text('Receive'),
                      )
                    : Text(order.status.replaceAll('_', ' ')),
              ),
            ),
        ],
      ),
    );
  }
}

int? _parseMoney(String value) {
  final text = value.trim().replaceAll(',', '');
  if (!RegExp(r'^\d+(\.\d{0,2})?$').hasMatch(text)) return null;
  final parts = text.split('.');
  final rupees = int.parse(parts.first);
  final paise = parts.length == 1 ? '00' : parts[1].padRight(2, '0');
  return rupees * 100 + int.parse(paise);
}

int? _parseQuantity(String value) {
  final text = value.trim();
  if (!RegExp(r'^\d+(\.\d{0,3})?$').hasMatch(text)) return null;
  final parts = text.split('.');
  final whole = int.parse(parts.first);
  final fraction = parts.length == 1 ? '000' : parts[1].padRight(3, '0');
  return whole * 1000 + int.parse(fraction);
}

String _formatQuantity(int milli) {
  final whole = milli ~/ 1000;
  final fraction = (milli % 1000).toString().padLeft(3, '0');
  if (fraction == '000') return '$whole';
  return '$whole.${fraction.replaceFirst(RegExp(r'0+$'), '')}';
}
