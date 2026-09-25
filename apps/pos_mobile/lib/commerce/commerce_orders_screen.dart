import 'package:flutter/material.dart';

import '../customers/customer_domain.dart';
import '../sell/local_pos_database.dart';
import '../sell/sale_domain.dart';
import '../sell/sell_screen.dart';
import 'commerce_domain.dart';

class CommerceOrdersScreen extends StatefulWidget {
  const CommerceOrdersScreen({
    required this.database,
    required this.saleContext,
    super.key,
  });

  final LocalPosDatabase database;
  final LocalSaleContext saleContext;

  @override
  State<CommerceOrdersScreen> createState() => _CommerceOrdersScreenState();
}

class _CommerceOrdersScreenState extends State<CommerceOrdersScreen> {
  List<LocalCommerceOrder> orders = const [];
  List<Product> products = const [];
  List<LocalCustomer> customers = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final nextOrders = await widget.database.listCommerceOrders();
    final nextProducts = await widget.database.listProducts();
    final nextCustomers = await widget.database.listCustomers();
    if (!mounted) return;
    setState(() {
      orders = nextOrders;
      products = nextProducts;
      customers = nextCustomers;
      loading = false;
    });
  }

  Future<void> captureOrder() async {
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add products before capturing an order.')),
      );
      return;
    }

    var channel = CommerceChannel.whatsapp;
    var customerSelection = '__guest__';
    final note = TextEditingController();
    final externalRef = TextEditingController();
    final quantities = <String, int>{};

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Capture customer order'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<CommerceChannel>(
                    initialValue: channel,
                    decoration: const InputDecoration(labelText: 'Received by'),
                    items: const [
                      DropdownMenuItem(
                        value: CommerceChannel.whatsapp,
                        child: Text('WhatsApp'),
                      ),
                      DropdownMenuItem(
                        value: CommerceChannel.phone,
                        child: Text('Phone'),
                      ),
                      DropdownMenuItem(
                        value: CommerceChannel.manual,
                        child: Text('In person / manual'),
                      ),
                    ],
                    onChanged: (next) {
                      if (next != null) {
                        setDialogState(() => channel = next);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: customerSelection,
                    decoration: const InputDecoration(
                      labelText: 'Customer (optional)',
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '__guest__',
                        child: Text('Guest / not linked'),
                      ),
                      for (final customer in customers)
                        DropdownMenuItem<String>(
                          value: customer.id,
                          child: Text(customer.name),
                        ),
                    ],
                    onChanged: (next) {
                      if (next != null) {
                        setDialogState(() => customerSelection = next);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (channel == CommerceChannel.whatsapp)
                    TextField(
                      controller: externalRef,
                      decoration: const InputDecoration(
                        labelText: 'Conversation/reference (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  if (channel == CommerceChannel.whatsapp)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'This records an order received outside AaraaPOS. '
                        'No WhatsApp provider is connected or simulated.',
                      ),
                    ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Items',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final product in products)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(product.name),
                      subtitle: Text(formatInr(product.unitPriceMinor)),
                      leading: IconButton(
                        tooltip: 'Remove one',
                        onPressed: (quantities[product.id] ?? 0) <= 0
                            ? null
                            : () {
                                setDialogState(() {
                                  final next =
                                      (quantities[product.id] ?? 0) - 1000;
                                  if (next <= 0) {
                                    quantities.remove(product.id);
                                  } else {
                                    quantities[product.id] = next;
                                  }
                                });
                              },
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _quantityLabel(quantities[product.id] ?? 0),
                          ),
                          IconButton(
                            tooltip: 'Add one',
                            onPressed: () {
                              setDialogState(() {
                                quantities.update(
                                  product.id,
                                  (value) => value + 1000,
                                  ifAbsent: () => 1000,
                                );
                              });
                            },
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: note,
                    decoration: const InputDecoration(
                      labelText: 'Order note (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: quantities.isEmpty
                  ? null
                  : () async {
                      final lines = <SaleLineInput>[];
                      for (final entry in quantities.entries) {
                        final product = products.firstWhere(
                          (item) => item.id == entry.key,
                        );
                        lines.add(
                          SaleLineInput(
                            product: product,
                            quantityMilli: entry.value,
                          ),
                        );
                      }
                      await widget.database.createCommerceOrder(
                        context: widget.saleContext,
                        channel: channel,
                        lines: lines,
                        customerId: customerSelection == '__guest__'
                            ? null
                            : customerSelection,
                        externalConversationRef: externalRef.text,
                        note: note.text,
                      );
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, true);
                      }
                    },
              child: const Text('Save order'),
            ),
          ],
        ),
      ),
    );

    note.dispose();
    externalRef.dispose();
    if (saved == true) await refresh();
  }

  Future<void> transition(LocalCommerceOrder order, String action) async {
    await widget.database.transitionCommerceOrder(
      context: widget.saleContext,
      orderId: order.id,
      action: action,
    );
    await refresh();
  }

  Future<void> billOrder(LocalCommerceOrder order) async {
    if (order.status == CommerceOrderStatus.received) {
      await widget.database.transitionCommerceOrder(
        context: widget.saleContext,
        orderId: order.id,
        action: 'confirm',
      );
    }

    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Bill customer order')),
          body: SellScreen(
            database: widget.database,
            saleContext: widget.saleContext,
            initialLines: order.lines.map((line) => line.toSaleLine()).toList(),
            initialCustomer: order.customer,
            commerceOrderId: order.id,
          ),
        ),
      ),
    );
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.chat_outlined),
              title: Text('Commerce orders are pre-sale'),
              subtitle: Text(
                'Capturing or confirming an order does not create revenue, payment or stock movement. '
                'Billing still goes through Sell.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: captureOrder,
              icon: const Icon(Icons.add),
              label: const Text('Capture order'),
            ),
          ),
          const SizedBox(height: 16),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (orders.isEmpty)
            const Card(
              child: ListTile(
                title: Text('No commerce orders'),
                subtitle: Text(
                  'Phone or WhatsApp orders can be captured here manually.',
                ),
              ),
            )
          else
            for (final order in orders)
              _OrderCard(
                order: order,
                onConfirm: order.status == CommerceOrderStatus.received
                    ? () => transition(order, 'confirm')
                    : null,
                onReady: order.status == CommerceOrderStatus.confirmed
                    ? () => transition(order, 'ready')
                    : null,
                onBill: order.status == CommerceOrderStatus.received ||
                        order.status == CommerceOrderStatus.confirmed ||
                        order.status == CommerceOrderStatus.ready
                    ? () => billOrder(order)
                    : null,
                onCancel: order.status == CommerceOrderStatus.received ||
                        order.status == CommerceOrderStatus.confirmed ||
                        order.status == CommerceOrderStatus.ready
                    ? () => transition(order, 'cancel')
                    : null,
              ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    this.onConfirm,
    this.onReady,
    this.onBill,
    this.onCancel,
  });

  final LocalCommerceOrder order;
  final VoidCallback? onConfirm;
  final VoidCallback? onReady;
  final VoidCallback? onBill;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.customer?.name ??
                        '${commerceChannelLabel(order.channel)} order',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(commerceOrderStatusLabel(order.status))),
              ],
            ),
            Text(
              '${commerceChannelLabel(order.channel)} • '
              '${order.lines.length} item${order.lines.length == 1 ? '' : 's'} • '
              'quoted ${formatInr(order.quotedTotalMinor)}',
            ),
            if (order.note != null) ...[
              const SizedBox(height: 6),
              Text(order.note!),
            ],
            if (order.saleId != null) ...[
              const SizedBox(height: 6),
              Text('Sale linked: ${order.saleId}'),
            ],
            if (onConfirm != null ||
                onReady != null ||
                onBill != null ||
                onCancel != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onConfirm != null)
                    OutlinedButton(
                      onPressed: onConfirm,
                      child: const Text('Confirm'),
                    ),
                  if (onReady != null)
                    OutlinedButton(
                      onPressed: onReady,
                      child: const Text('Mark ready'),
                    ),
                  if (onBill != null)
                    FilledButton(
                      onPressed: onBill,
                      child: const Text('Bill order'),
                    ),
                  if (onCancel != null)
                    TextButton(
                      onPressed: onCancel,
                      child: const Text('Cancel'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _quantityLabel(int milli) {
  if (milli <= 0) return '0';
  if (milli % 1000 == 0) return '${milli ~/ 1000}';
  final whole = milli ~/ 1000;
  final fraction = (milli % 1000).toString().padLeft(3, '0');
  return '$whole.${fraction.replaceFirst(RegExp(r'0+$'), '')}';
}
