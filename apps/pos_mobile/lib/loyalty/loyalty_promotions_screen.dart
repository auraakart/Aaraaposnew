import 'package:flutter/material.dart';

import '../sell/local_pos_database.dart';
import '../sell/sale_domain.dart';
import 'loyalty_domain.dart';

class LoyaltyPromotionsScreen extends StatefulWidget {
  const LoyaltyPromotionsScreen({
    required this.database,
    required this.saleContext,
    super.key,
  });

  final LocalPosDatabase database;
  final LocalSaleContext saleContext;

  @override
  State<LoyaltyPromotionsScreen> createState() =>
      _LoyaltyPromotionsScreenState();
}

class _LoyaltyPromotionsScreenState extends State<LoyaltyPromotionsScreen> {
  LoyaltyProgram? program;
  List<LocalPromotion> promotions = const [];
  List<Product> products = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final nextProgram = await widget.database.loyaltyProgram();
    final nextPromotions = await widget.database.listPromotions();
    final nextProducts = await widget.database.listProducts();
    if (!mounted) return;
    setState(() {
      program = nextProgram;
      promotions = nextPromotions;
      products = nextProducts;
      loading = false;
    });
  }

  Future<void> configureLoyalty() async {
    final current = program!;
    final points = TextEditingController(
      text: current.pointsPer100Rupees.toString(),
    );
    final value = TextEditingController(
      text: (current.redemptionMinorPerPoint / 100).toStringAsFixed(2),
    );
    final cap = TextEditingController(
      text: (current.maxRedemptionBps / 100).toStringAsFixed(0),
    );
    var enabled = current.enabled;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Loyalty settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable loyalty'),
                  subtitle: const Text(
                    'Points are earned on settled customer sales.',
                  ),
                  value: enabled,
                  onChanged: (next) =>
                      setDialogState(() => enabled = next),
                ),
                TextField(
                  controller: points,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Points earned per ₹100',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: value,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Discount value per point ₹',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cap,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Maximum bill redemption %',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Pay Later sales do not earn points while unpaid. '
                  'Point redemption is limited to tax-inclusive carts and cannot stack with another discount.',
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
                final pointRate = int.tryParse(points.text.trim());
                final valueMinor = _parseMoney(value.text);
                final capPercent = double.tryParse(cap.text.trim());
                if (pointRate == null ||
                    valueMinor == null ||
                    capPercent == null ||
                    capPercent < 0 ||
                    capPercent > 100) {
                  return;
                }
                final next = LoyaltyProgram(
                  enabled: enabled,
                  pointsPer100Rupees: pointRate,
                  redemptionMinorPerPoint: valueMinor,
                  maxRedemptionBps: (capPercent * 100).round(),
                );
                try {
                  await widget.database.updateLoyaltyProgram(
                    context: widget.saleContext,
                    program: next,
                  );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                } on ArgumentError {
                  // Invalid values remain in the dialog for correction.
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    points.dispose();
    value.dispose();
    cap.dispose();
    if (saved == true) await refresh();
  }

  Future<void> addPromotion() async {
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add products before creating an offer.')),
      );
      return;
    }

    final name = TextEditingController();
    final value = TextEditingController();
    final minimum = TextEditingController(text: '0');
    var type = 'percentage';
    var productId = '__all__';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create offer'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Offer name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Offer type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'percentage',
                      child: Text('Percentage off'),
                    ),
                    DropdownMenuItem(
                      value: 'fixed',
                      child: Text('Fixed amount off'),
                    ),
                  ],
                  onChanged: (next) {
                    if (next != null) setDialogState(() => type = next);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: value,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText:
                        type == 'percentage' ? 'Discount %' : 'Discount ₹',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minimum,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Minimum bill ₹',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: productId,
                  decoration: const InputDecoration(labelText: 'Applies to'),
                  items: [
                    const DropdownMenuItem(
                      value: '__all__',
                      child: Text('All products'),
                    ),
                    for (final product in products)
                      DropdownMenuItem(
                        value: product.id,
                        child: Text(product.name),
                      ),
                  ],
                  onChanged: (next) {
                    if (next != null) {
                      setDialogState(() => productId = next);
                    }
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Offers run for 30 days by default. Only one best offer is applied to a bill; offers never silently stack.',
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
                final minMinor = _parseMoney(minimum.text);
                final promotionValue = type == 'percentage'
                    ? _parsePercentBps(value.text)
                    : _parseMoney(value.text);
                if (name.text.trim().isEmpty ||
                    minMinor == null ||
                    promotionValue == null ||
                    promotionValue <= 0) {
                  return;
                }
                final now = DateTime.now().toUtc();
                await widget.database.addPromotion(
                  context: widget.saleContext,
                  name: name.text,
                  type: type,
                  value: promotionValue,
                  startsAt: now,
                  endsAt: now.add(const Duration(days: 30)),
                  minBasketMinor: minMinor,
                  productIds:
                      productId == '__all__' ? const [] : [productId],
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Create offer'),
            ),
          ],
        ),
      ),
    );

    name.dispose();
    value.dispose();
    minimum.dispose();
    if (saved == true) await refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (loading || program == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final settings = program!;

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.stars_outlined),
              title: Text(
                settings.enabled ? 'Loyalty enabled' : 'Loyalty disabled',
              ),
              subtitle: Text(
                settings.enabled
                    ? '${settings.pointsPer100Rupees} point(s) per ₹100 • '
                        '${formatInr(settings.redemptionMinorPerPoint)} discount value per point'
                    : 'Customers are not earning points.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: configureLoyalty,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Offers',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: addPromotion,
                icon: const Icon(Icons.add),
                label: const Text('New offer'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (promotions.isEmpty)
            const Card(
              child: ListTile(
                title: Text('No offers yet'),
                subtitle: Text(
                  'Create a simple product or basket offer when needed.',
                ),
              ),
            ),
          for (final promotion in promotions)
            Card(
              child: SwitchListTile(
                value: promotion.active,
                onChanged: (active) async {
                  await widget.database.setPromotionActive(
                    context: widget.saleContext,
                    promotionId: promotion.id,
                    active: active,
                  );
                  await refresh();
                },
                title: Text(promotion.name),
                subtitle: Text(_promotionDescription(promotion, products)),
                secondary: const Icon(Icons.local_offer_outlined),
              ),
            ),
        ],
      ),
    );
  }
}

String _promotionDescription(
  LocalPromotion promotion,
  List<Product> products,
) {
  final value = promotion.type == 'percentage'
      ? '${(promotion.value / 100).toStringAsFixed(
          promotion.value % 100 == 0 ? 0 : 2,
        )}% off'
      : '${formatInr(promotion.value)} off';
  final appliesTo = promotion.productIds.isEmpty
      ? 'all products'
      : products
          .where((product) => promotion.productIds.contains(product.id))
          .map((product) => product.name)
          .join(', ');
  return '$value • $appliesTo • ends '
      '${promotion.endsAt.toLocal().day}/${promotion.endsAt.toLocal().month}';
}

int? _parseMoney(String value) {
  final text = value.trim().replaceAll(',', '');
  if (!RegExp(r'^\d+(\.\d{0,2})?$').hasMatch(text)) return null;
  final parts = text.split('.');
  final rupees = int.parse(parts.first);
  final paise = parts.length == 1 ? '00' : parts[1].padRight(2, '0');
  return rupees * 100 + int.parse(paise);
}

int? _parsePercentBps(String value) {
  final percent = double.tryParse(value.trim());
  if (percent == null || percent <= 0 || percent > 100) return null;
  return (percent * 100).round();
}
