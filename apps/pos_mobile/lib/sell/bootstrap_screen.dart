import 'package:flutter/material.dart';

import 'local_pos_database.dart';

class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({
    required this.database,
    required this.onComplete,
    super.key,
  });

  final LocalPosDatabase database;
  final ValueChanged<LocalSaleContext> onComplete;

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  final businessController = TextEditingController();
  final storeController = TextEditingController(text: 'Main Store');
  bool saving = false;
  String? error;

  @override
  void dispose() {
    businessController.dispose();
    storeController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) {
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final context = await widget.database.bootstrapOwner(
        businessName: businessController.text,
        storeName: storeController.text,
      );
      if (mounted) {
        widget.onComplete(context);
      }
    } on Object {
      if (mounted) {
        setState(() {
          error = 'Enter your business and store name.';
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up AaraaPOS')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Start billing in minutes',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'This creates a local offline store. Online account linking and synchronization can be completed later.',
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: businessController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Business name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: storeController,
                  onSubmitted: (_) => save(),
                  decoration: const InputDecoration(
                    labelText: 'Store name',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: const Icon(Icons.storefront),
                  label: Text(saving ? 'Creating store…' : 'Create store'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
