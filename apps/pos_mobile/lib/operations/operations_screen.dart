import 'package:flutter/material.dart';

import '../sell/local_pos_database.dart';
import '../sell/sale_domain.dart';
import 'operations_domain.dart';

class OperationsScreen extends StatefulWidget {
  const OperationsScreen({
    required this.database,
    required this.saleContext,
    super.key,
  });

  final LocalPosDatabase database;
  final LocalSaleContext saleContext;

  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  List<LocalEmployee> employees = const [];
  List<LocalExpense> expenses = const [];
  LocalShift? shift;
  int pendingApprovals = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final loadedEmployees = await widget.database.listEmployees();
    final loadedExpenses = await widget.database.listExpenses();
    final current = await widget.database.currentShift();
    final approvals = await widget.database.pendingApprovalCount();
    if (!mounted) return;
    setState(() {
      employees = loadedEmployees;
      expenses = loadedExpenses;
      shift = current;
      pendingApprovals = approvals;
      loading = false;
    });
  }

  Future<void> addEmployee() async {
    final name = TextEditingController();
    final mobile = TextEditingController();
    var role = EmployeeRole.cashier;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add employee'),
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
                  labelText: 'Mobile (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<EmployeeRole>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(
                    value: EmployeeRole.manager,
                    child: Text('Manager'),
                  ),
                  DropdownMenuItem(
                    value: EmployeeRole.cashier,
                    child: Text('Cashier'),
                  ),
                  DropdownMenuItem(
                    value: EmployeeRole.stockWorker,
                    child: Text('Stock worker'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => role = value);
                },
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
                await widget.database.addEmployee(
                  context: widget.saleContext,
                  name: name.text,
                  role: role,
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
      ),
    );
    name.dispose();
    mobile.dispose();
    if (saved == true) await refresh();
  }

  Future<void> openShift() async {
    final activeEmployees = employees.where((employee) => employee.active).toList();
    if (activeEmployees.isEmpty) return;

    var employeeId = activeEmployees.first.id;
    final opening = TextEditingController(text: '0');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Open shift'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: employeeId,
                decoration: const InputDecoration(labelText: 'Employee'),
                items: [
                  for (final employee in activeEmployees)
                    DropdownMenuItem(
                      value: employee.id,
                      child: Text(employee.name),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => employeeId = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: opening,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Opening cash ₹',
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
                final openingMinor = _parseMoney(opening.text);
                if (openingMinor == null) return;
                await widget.database.openShift(
                  context: widget.saleContext,
                  employeeId: employeeId,
                  openingCashMinor: openingMinor,
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Open shift'),
            ),
          ],
        ),
      ),
    );
    opening.dispose();
    if (saved == true) await refresh();
  }

  Future<void> closeShift() async {
    final actual = TextEditingController();
    final closed = await showDialog<LocalShift>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Close shift'),
        content: TextField(
          controller: actual,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Counted cash ₹',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final actualMinor = _parseMoney(actual.text);
              if (actualMinor == null) return;
              final result = await widget.database.closeShift(
                context: widget.saleContext,
                actualClosingCashMinor: actualMinor,
              );
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext, result);
              }
            },
            child: const Text('Close shift'),
          ),
        ],
      ),
    );
    actual.dispose();
    if (closed == null || !mounted) return;
    await refresh();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Shift closed'),
        content: Text(
          'Expected cash: ${formatInr(closed.expectedClosingCashMinor ?? 0)}\n'
          'Counted cash: ${formatInr(closed.actualClosingCashMinor ?? 0)}\n'
          'Difference: ${formatInr(closed.varianceMinor ?? 0)}',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> cashMovement(String type) async {
    final amount = TextEditingController();
    final reason = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(type == 'deposit' ? 'Add cash to drawer' : 'Take cash from drawer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount ₹',
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final amountMinor = _parseMoney(amount.text);
              if (amountMinor == null ||
                  amountMinor <= 0 ||
                  reason.text.trim().isEmpty) {
                return;
              }
              await widget.database.recordCashMovement(
                context: widget.saleContext,
                movementType: type,
                amountMinor: amountMinor,
                reason: reason.text,
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
    amount.dispose();
    reason.dispose();
    if (saved == true) await refresh();
  }

  Future<void> addExpense() async {
    final amount = TextEditingController();
    final note = TextEditingController();
    var category = 'Electricity';
    var method = 'cash';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add expense'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const [
                  DropdownMenuItem(value: 'Rent', child: Text('Rent')),
                  DropdownMenuItem(
                    value: 'Electricity',
                    child: Text('Electricity'),
                  ),
                  DropdownMenuItem(value: 'Transport', child: Text('Transport')),
                  DropdownMenuItem(value: 'Tea/Food', child: Text('Tea/Food')),
                  DropdownMenuItem(
                    value: 'Maintenance',
                    child: Text('Maintenance'),
                  ),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => category = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount ₹',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Paid by'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'upi', child: Text('UPI')),
                  DropdownMenuItem(value: 'card', child: Text('Card')),
                  DropdownMenuItem(value: 'bank', child: Text('Bank')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => method = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
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
                final amountMinor = _parseMoney(amount.text);
                if (amountMinor == null || amountMinor <= 0) return;
                await widget.database.addExpense(
                  context: widget.saleContext,
                  category: category,
                  amountMinor: amountMinor,
                  paymentMethod: method,
                  note: note.text,
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Save expense'),
            ),
          ],
        ),
      ),
    );
    amount.dispose();
    note.dispose();
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
          if (pendingApprovals > 0)
            Card(
              child: ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: Text('$pendingApprovals approval item needs review'),
                subtitle: const Text('Cash variance or another sensitive action.'),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: shift == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'No shift open',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Open a shift to reconcile drawer cash automatically.',
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: openShift,
                          child: const Text('Open shift'),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Shift open • ${shift!.employeeName}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          'Opening cash ${formatInr(shift!.openingCashMinor)}',
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonal(
                              onPressed: () => cashMovement('deposit'),
                              child: const Text('Add cash'),
                            ),
                            FilledButton.tonal(
                              onPressed: () => cashMovement('withdrawal'),
                              child: const Text('Take cash'),
                            ),
                            FilledButton(
                              onPressed: closeShift,
                              child: const Text('Close shift'),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Employees',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton.icon(
                onPressed: addEmployee,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add'),
              ),
            ],
          ),
          for (final employee in employees)
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text(employee.name),
              subtitle: Text(_roleLabel(employee.role)),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Expenses',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton.icon(
                onPressed: addExpense,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          if (expenses.isEmpty)
            const ListTile(title: Text('No expenses recorded yet.')),
          for (final expense in expenses.take(10))
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(expense.category),
              subtitle: Text(expense.paymentMethod.toUpperCase()),
              trailing: Text(formatInr(expense.amountMinor)),
            ),
        ],
      ),
    );
  }
}

String _roleLabel(EmployeeRole role) => switch (role) {
      EmployeeRole.owner => 'Owner',
      EmployeeRole.manager => 'Manager',
      EmployeeRole.cashier => 'Cashier',
      EmployeeRole.stockWorker => 'Stock worker',
    };

int? _parseMoney(String value) {
  final text = value.trim().replaceAll(',', '');
  if (!RegExp(r'^\d+(\.\d{0,2})?$').hasMatch(text)) return null;
  final parts = text.split('.');
  final rupees = int.parse(parts.first);
  final paise = parts.length == 1 ? '00' : parts[1].padRight(2, '0');
  return rupees * 100 + int.parse(paise);
}
