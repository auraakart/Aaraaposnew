import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../operations/operations_domain.dart';
import '../sell/local_pos_database.dart';
import 'local_auth_domain.dart';

class LocalSignInScreen extends StatefulWidget {
  const LocalSignInScreen({
    required this.database,
    required this.baseContext,
    required this.onAuthenticated,
    super.key,
  });

  final LocalPosDatabase database;
  final LocalSaleContext baseContext;
  final ValueChanged<LocalAuthenticatedSession> onAuthenticated;

  @override
  State<LocalSignInScreen> createState() => _LocalSignInScreenState();
}

class _LocalSignInScreenState extends State<LocalSignInScreen> {
  final pinController = TextEditingController();
  final confirmController = TextEditingController();

  List<LocalEmployee> employees = const [];
  String? selectedEmployeeId;
  bool loading = true;
  bool firstOwnerSetup = false;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    pinController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final configured = await widget.database.configuredLocalCredentialCount();
    final nextEmployees = configured == 0
        ? await widget.database.listEmployees()
        : await widget.database.listSignInEmployees();
    if (!mounted) return;

    final firstSetup = configured == 0;
    final owner = nextEmployees.where(
      (employee) => employee.id == widget.baseContext.userId,
    );
    setState(() {
      employees = nextEmployees;
      firstOwnerSetup = firstSetup;
      selectedEmployeeId = firstSetup && owner.isNotEmpty
          ? owner.first.id
          : nextEmployees.isEmpty
              ? null
              : nextEmployees.first.id;
      loading = false;
    });
  }

  Future<void> submit() async {
    if (busy) return;
    final employeeId = selectedEmployeeId;
    final pin = pinController.text.trim();
    if (employeeId == null) {
      setState(() => error = 'No employee is available for sign-in.');
      return;
    }
    if (!isValidLocalPin(pin)) {
      setState(() => error = 'Enter a 4 to 8 digit PIN.');
      return;
    }
    if (firstOwnerSetup && pin != confirmController.text.trim()) {
      setState(() => error = 'PINs do not match.');
      return;
    }

    setState(() {
      busy = true;
      error = null;
    });

    try {
      if (firstOwnerSetup) {
        await widget.database.configureLocalPin(
          context: widget.baseContext,
          employeeId: employeeId,
          pin: pin,
        );
      }
      final session = await widget.database.authenticateLocalEmployee(
        baseContext: widget.baseContext,
        employeeId: employeeId,
        pin: pin,
      );
      if (mounted) widget.onAuthenticated(session);
    } on LocalPinAuthException catch (exception) {
      if (!mounted) return;
      setState(() {
        error = switch (exception.code) {
          'PIN_LOCKED' => _lockedMessage(exception.lockedUntil),
          'PIN_NOT_CONFIGURED' => 'This employee does not have a local PIN.',
          'EMPLOYEE_NOT_AVAILABLE' => 'This employee is not available.',
          _ => 'Incorrect PIN. Try again.',
        };
        busy = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        error = firstOwnerSetup
            ? 'Could not create the local PIN.'
            : 'Could not sign in.';
        busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final selected = employees.where(
      (employee) => employee.id == selectedEmployeeId,
    );
    final selectedEmployee = selected.isEmpty ? null : selected.first;

    return Scaffold(
      appBar: AppBar(
        title: Text(firstOwnerSetup ? 'Secure this POS' : 'Employee sign-in'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Icon(
                  firstOwnerSetup
                      ? Icons.lock_outline
                      : Icons.badge_outlined,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  firstOwnerSetup
                      ? 'Create the Owner PIN'
                      : 'Who is using this terminal?',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  firstOwnerSetup
                      ? 'This PIN protects offline access on this device. '
                          'It is never used as an online account password.'
                      : 'Choose your name and enter your local device PIN.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (!firstOwnerSetup)
                  DropdownButtonFormField<String>(
                    initialValue: selectedEmployeeId,
                    decoration: const InputDecoration(
                      labelText: 'Employee',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final employee in employees)
                        DropdownMenuItem(
                          value: employee.id,
                          child: Text(
                            '${employee.name} · ${_roleLabel(employee.role)}',
                          ),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (value) =>
                            setState(() => selectedEmployeeId = value),
                  )
                else
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text(selectedEmployee?.name ?? 'Owner'),
                    subtitle: const Text('Owner · local device setup'),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: pinController,
                  enabled: !busy,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.password],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  onSubmitted: (_) {
                    if (!firstOwnerSetup) submit();
                  },
                  decoration: const InputDecoration(
                    labelText: 'PIN',
                    hintText: '4 to 8 digits',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (firstOwnerSetup) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmController,
                    enabled: !busy,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                    onSubmitted: (_) => submit(),
                    decoration: const InputDecoration(
                      labelText: 'Confirm PIN',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: busy ? null : submit,
                  icon: const Icon(Icons.login),
                  label: Text(
                    busy
                        ? 'Checking…'
                        : firstOwnerSetup
                            ? 'Create PIN & continue'
                            : 'Sign in',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Five failed attempts temporarily lock the employee PIN. '
                  'Local PINs are stored only as salted, iterated hashes.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
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

String _lockedMessage(DateTime? until) {
  if (until == null) return 'PIN is temporarily locked.';
  final minutes = until.difference(DateTime.now().toUtc()).inMinutes + 1;
  return 'Too many attempts. Try again in about '
      '${minutes < 1 ? 1 : minutes} minute(s).';
}
