import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../operations/operations_domain.dart';
import '../sell/local_pos_database.dart';
import 'local_auth_domain.dart';

class LocalAccessScreen extends StatefulWidget {
  const LocalAccessScreen({
    required this.database,
    required this.saleContext,
    this.onCurrentCredentialReset,
    super.key,
  });

  final LocalPosDatabase database;
  final LocalSaleContext saleContext;
  final VoidCallback? onCurrentCredentialReset;

  @override
  State<LocalAccessScreen> createState() => _LocalAccessScreenState();
}

class _LocalAccessScreenState extends State<LocalAccessScreen> {
  List<_AccessEmployee> employees = const [];
  bool loading = true;
  bool allowed = false;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final canManage = await widget.database.canReadAudit(widget.saleContext);
    if (!canManage) {
      if (!mounted) return;
      setState(() {
        allowed = false;
        loading = false;
      });
      return;
    }

    final list = await widget.database.listEmployees();
    final current = list.where(
      (employee) => employee.id == widget.saleContext.userId,
    );
    final actorRole =
        current.isEmpty ? EmployeeRole.cashier : current.first.role;

    final next = <_AccessEmployee>[];
    for (final employee in list.where((item) => item.active)) {
      next.add(
        _AccessEmployee(
          employee: employee,
          pinConfigured: await widget.database
              .hasConfiguredLocalCredential(employee.id),
          canManage: _canManage(actorRole, widget.saleContext.userId, employee),
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      employees = next;
      allowed = true;
      loading = false;
    });
  }

  Future<void> setPin(_AccessEmployee item) async {
    final pin = TextEditingController();
    final confirm = TextEditingController();

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          '${item.pinConfigured ? 'Reset' : 'Set'} PIN for '
          '${item.employee.name}',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The PIN protects offline access on this device only.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pin,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              decoration: const InputDecoration(
                labelText: 'New PIN',
                hintText: '4 to 8 digits',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirm,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              decoration: const InputDecoration(
                labelText: 'Confirm PIN',
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
            onPressed: () {
              final value = pin.text.trim();
              if (!isValidLocalPin(value) ||
                  value != confirm.text.trim()) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Enter matching 4 to 8 digit PINs.'),
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Save PIN'),
          ),
        ],
      ),
    );

    if (accepted != true) {
      pin.dispose();
      confirm.dispose();
      return;
    }

    try {
      await widget.database.configureLocalPin(
        context: widget.saleContext,
        employeeId: item.employee.id,
        pin: pin.text.trim(),
      );
      pin.dispose();
      confirm.dispose();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PIN updated for ${item.employee.name}.'),
        ),
      );
      if (item.employee.id == widget.saleContext.userId) {
        widget.onCurrentCredentialReset?.call();
        return;
      }
      await refresh();
    } on Object {
      pin.dispose();
      confirm.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN could not be updated for this employee.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!allowed) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Employee access settings are available only to the Owner or Manager.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.security_outlined),
              title: Text('Local device access'),
              subtitle: Text(
                'PINs stay on this terminal as salted, iterated hashes. '
                'They are not online account passwords and are never synced.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final item in employees)
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person_outline),
                ),
                title: Text(item.employee.name),
                subtitle: Text(
                  '${_roleLabel(item.employee.role)} · '
                  '${item.pinConfigured ? 'PIN configured' : 'No PIN'}',
                ),
                trailing: item.canManage
                    ? TextButton(
                        onPressed: () => setPin(item),
                        child: Text(
                          item.pinConfigured ? 'Reset PIN' : 'Set PIN',
                        ),
                      )
                    : const Icon(Icons.lock_outline),
              ),
            ),
        ],
      ),
    );
  }
}

class _AccessEmployee {
  const _AccessEmployee({
    required this.employee,
    required this.pinConfigured,
    required this.canManage,
  });

  final LocalEmployee employee;
  final bool pinConfigured;
  final bool canManage;
}

bool _canManage(
  EmployeeRole actorRole,
  String actorId,
  LocalEmployee target,
) {
  if (actorRole == EmployeeRole.owner) return true;
  if (actorRole != EmployeeRole.manager) return false;
  if (target.role == EmployeeRole.owner) return false;
  if (target.role == EmployeeRole.manager && target.id != actorId) return false;
  return true;
}

String _roleLabel(EmployeeRole role) => switch (role) {
      EmployeeRole.owner => 'Owner',
      EmployeeRole.manager => 'Manager',
      EmployeeRole.cashier => 'Cashier',
      EmployeeRole.stockWorker => 'Stock worker',
    };
