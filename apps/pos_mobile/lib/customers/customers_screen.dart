import 'package:flutter/material.dart';

import '../sell/local_pos_database.dart';
import '../sell/sale_domain.dart';
import 'customer_domain.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({
    required this.database,
    required this.saleContext,
    super.key,
  });

  final LocalPosDatabase database;
  final LocalSaleContext saleContext;

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<LocalCustomer> customers = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final next = await widget.database.listCustomers();
    if (!mounted) return;
    setState(() {
      customers = next;
      loading = false;
    });
  }

  Future<void> addCustomer() async {
    final name = TextEditingController();
    final mobile = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: mobile,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile number (optional)',
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
              await widget.database.addCustomer(
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

  Future<void> collect(LocalCustomer customer) async {
    final amount = TextEditingController();
    final collected = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Collect from ${customer.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Customer owes ${formatInr(customer.creditBalanceMinor)}',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Cash received ₹',
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
                  value > customer.creditBalanceMinor) {
                return;
              }
              await widget.database.collectCustomerCredit(
                context: widget.saleContext,
                customerId: customer.id,
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
    if (collected == true) await refresh();
  }

  Future<void> showStatement(LocalCustomer customer) async {
    final entries = await widget.database.customerCreditEntries(customer.id);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
              customer.name,
              style: Theme.of(sheetContext).textTheme.headlineSmall,
            ),
            Text(
              'Balance ${formatInr(customer.creditBalanceMinor)}',
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              const ListTile(title: Text('No customer credit history yet.')),
            for (final entry in entries.reversed)
              ListTile(
                leading: Icon(
                  entry.type == CreditEntryType.payment
                      ? Icons.payments_outlined
                      : Icons.receipt_long_outlined,
                ),
                title: Text(
                  entry.type == CreditEntryType.payment
                      ? 'Payment received'
                      : 'Credit sale',
                ),
                subtitle: Text(_date(entry.occurredAt)),
                trailing: Text(
                  entry.type == CreditEntryType.payment
                      ? '-${formatInr(entry.amountMinor)}'
                      : '+${formatInr(entry.amountMinor)}',
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: refresh,
        child: customers.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 160),
                  Center(
                    child: Text(
                      'No customers yet. Guest checkout still works normally.',
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: customers.length,
                itemBuilder: (context, index) {
                  final customer = customers[index];
                  return Card(
                    child: ListTile(
                      onTap: () => showStatement(customer),
                      title: Text(customer.name),
                      subtitle: Text(_subtitle(customer)),
                      trailing: customer.creditBalanceMinor > 0
                          ? FilledButton.tonal(
                              onPressed: () => collect(customer),
                              child: const Text('Collect'),
                            )
                          : const Icon(Icons.chevron_right),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addCustomer,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add customer'),
      ),
    );
  }
}

String _subtitle(LocalCustomer customer) {
  final parts = <String>[];
  if (customer.mobile != null) parts.add(customer.mobile!);
  if (customer.creditBalanceMinor > 0) {
    parts.add('${formatInr(customer.creditBalanceMinor)} due');
  }
  if (customer.loyaltyPoints > 0) {
    parts.add('${customer.loyaltyPoints} loyalty points');
  }
  if (customer.overdueMinor > 0) {
    parts.add('${formatInr(customer.overdueMinor)} overdue');
  }
  if (customer.lastPurchaseAt != null) {
    parts.add('Last purchase ${_date(customer.lastPurchaseAt!)}');
  }
  return parts.isEmpty ? 'No purchases yet' : parts.join(' • ');
}

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year}';
}

int? _parseMoney(String value) {
  final text = value.trim().replaceAll(',', '');
  if (!RegExp(r'^\d+(\.\d{0,2})?$').hasMatch(text)) return null;
  final parts = text.split('.');
  final rupees = int.parse(parts.first);
  final paise = parts.length == 1 ? '00' : parts[1].padRight(2, '0');
  return rupees * 100 + int.parse(paise);
}
