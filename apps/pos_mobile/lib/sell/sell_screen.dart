import 'package:flutter/material.dart';

import '../customers/customer_domain.dart';
import '../loyalty/loyalty_domain.dart';
import '../payments/payment_domain.dart';
import '../payments/payment_method_sheet.dart';
import 'barcode_scanner_screen.dart';
import 'local_pos_database.dart';
import 'receipt_output.dart';
import 'return_domain.dart';
import 'sale_domain.dart';

class SellScreen extends StatefulWidget {
  const SellScreen({
    required this.database,
    required this.saleContext,
    super.key,
  });

  final LocalPosDatabase database;
  final LocalSaleContext saleContext;

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  final searchController = TextEditingController();
  final Map<String, int> quantitiesMilli = {};
  final Map<String, int> discountsMinor = {};
  final Map<String, String> discountSources = {};
  final Map<String, String> discountReferences = {};
  final Map<String, Product> cartProducts = {};
  String? appliedPromotionName;
  List<Product> products = const [];
  bool loading = true;
  int pendingSync = 0;
  LocalCustomer? selectedCustomer;

  @override
  void initState() {
    super.initState();
    refreshProducts();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> refreshProducts([String query = '']) async {
    final loaded = await widget.database.listProducts(query: query);
    final pending = await widget.database.pendingOutboxCount();
    if (!mounted) {
      return;
    }
    setState(() {
      products = loaded;
      pendingSync = pending;
      loading = false;
    });
  }

  List<SaleLineInput> get cartLines {
    final lines = <SaleLineInput>[];
    for (final entry in quantitiesMilli.entries) {
      final product = cartProducts[entry.key];
      if (product != null && entry.value > 0) {
        lines.add(
          SaleLineInput(
            product: product,
            quantityMilli: entry.value,
            discountMinor: discountsMinor[entry.key] ?? 0,
            discountSource: discountSources[entry.key],
            discountReferenceId: discountReferences[entry.key],
          ),
        );
      }
    }
    return lines;
  }

  SaleTotals? get totals {
    final lines = cartLines;
    if (lines.isEmpty) {
      return null;
    }
    return priceSale(lines, widget.saleContext.taxMode);
  }

  void _clearDynamicDiscountsInState() {
    final promoted = discountSources.entries
        .where(
          (entry) =>
              entry.value == 'promotion' || entry.value == 'loyalty',
        )
        .map((entry) => entry.key)
        .toList();
    for (final productId in promoted) {
      discountsMinor.remove(productId);
      discountSources.remove(productId);
      discountReferences.remove(productId);
    }
    if (promoted.isNotEmpty) {
      appliedPromotionName = null;
    }
  }

  void add(Product product) {
    setState(() {
      _clearDynamicDiscountsInState();
      cartProducts[product.id] = product;
      quantitiesMilli.update(
        product.id,
        (value) => value + 1000,
        ifAbsent: () => 1000,
      );
    });
  }

  void removeOne(Product product) {
    setState(() {
      _clearDynamicDiscountsInState();
      final next = (quantitiesMilli[product.id] ?? 0) - 1000;
      if (next <= 0) {
        quantitiesMilli.remove(product.id);
        discountsMinor.remove(product.id);
        discountSources.remove(product.id);
        discountReferences.remove(product.id);
        cartProducts.remove(product.id);
      } else {
        quantitiesMilli[product.id] = next;
      }
    });
  }

  Future<void> showAddProduct() async {
    final name = TextEditingController();
    final price = TextEditingController();
    final barcode = TextEditingController();
    var taxRateBps = 0;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add product'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Product name'),
                    ),
                    TextField(
                      controller: price,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Selling price ₹',
                      ),
                    ),
                    TextField(
                      controller: barcode,
                      decoration: const InputDecoration(
                        labelText: 'Barcode (optional)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: taxRateBps,
                      decoration: const InputDecoration(labelText: 'GST rate'),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('0%')),
                        DropdownMenuItem(value: 500, child: Text('5%')),
                        DropdownMenuItem(value: 1200, child: Text('12%')),
                        DropdownMenuItem(value: 1800, child: Text('18%')),
                        DropdownMenuItem(value: 2800, child: Text('28%')),
                      ],
                      onChanged: (value) {
                        setDialogState(() => taxRateBps = value ?? 0);
                      },
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
                    final priceMinor = parseRupeesToMinor(price.text);
                    if (name.text.trim().isEmpty || priceMinor == null) {
                      return;
                    }
                    try {
                      await widget.database.addProduct(
                        name: name.text,
                        unitPriceMinor: priceMinor,
                        barcode: barcode.text,
                        taxRateBps: taxRateBps,
                      );
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, true);
                      }
                    } on Object {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not add product. Check barcode and values.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    name.dispose();
    price.dispose();
    barcode.dispose();
    if (created == true) {
      await refreshProducts(searchController.text);
    }
  }

  Future<void> scanBarcode() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const BarcodeScannerScreen(),
      ),
    );
    if (!mounted || barcode == null) return;

    final matches = await widget.database.listProducts(query: barcode);
    if (!mounted) return;
    if (matches.length == 1) {
      add(matches.single);
      searchController.clear();
      await refreshProducts();
      return;
    }
    searchController.text = barcode;
    await refreshProducts(barcode);
    if (matches.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No product found for this barcode.')),
      );
    }
  }

  Future<void> setDiscount(Product product) async {
    final quantity = quantitiesMilli[product.id] ?? 0;
    if (quantity <= 0) return;
    final grossMinor =
        (product.unitPriceMinor * quantity + 500) ~/ 1000;
    final controller = TextEditingController(
      text: (discountsMinor[product.id] ?? 0) == 0
          ? ''
          : ((discountsMinor[product.id] ?? 0) / 100).toStringAsFixed(2),
    );
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Discount • ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Line amount ${formatInr(grossMinor)}'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Discount ₹',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 0),
            child: const Text('Remove discount'),
          ),
          FilledButton(
            onPressed: () {
              final value = parseRupeesToMinor(controller.text);
              if (value == null || value > grossMinor) return;
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    setState(() {
      _clearDynamicDiscountsInState();
      if (result == 0) {
        discountsMinor.remove(product.id);
        discountSources.remove(product.id);
        discountReferences.remove(product.id);
      } else {
        discountsMinor[product.id] = result;
        discountSources[product.id] = 'manual';
        discountReferences.remove(product.id);
        appliedPromotionName = null;
      }
    });
  }

  Future<void> redeemLoyalty() async {
    final customer = selectedCustomer;
    final saleTotals = totals;
    if (customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a customer to use loyalty points.')),
      );
      return;
    }
    if (saleTotals == null) return;
    if (discountsMinor.values.any((value) => value > 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loyalty points cannot be stacked with another discount.'),
        ),
      );
      return;
    }
    if (cartProducts.values.any(
      (product) => product.taxPriceMode != TaxPriceMode.inclusive,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Loyalty redemption is currently available only for tax-inclusive items.',
          ),
        ),
      );
      return;
    }

    final program = await widget.database.loyaltyProgram();
    final balance = await widget.database.customerLoyaltyBalance(customer.id);
    if (!mounted) return;
    if (!program.enabled || balance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No loyalty points are available to use.')),
      );
      return;
    }

    final maximum = maxLoyaltyRedemption(
      saleMinor: saleTotals.totalMinor,
      availablePoints: balance,
      requestedPoints: balance,
      program: program,
    );
    if (maximum.points <= 0 || maximum.amountMinor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This bill is too small to redeem points.')),
      );
      return;
    }

    final controller = TextEditingController(text: '${maximum.points}');
    final requested = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Use loyalty points'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$balance points available'),
            const SizedBox(height: 8),
            Text(
              'Up to ${maximum.points} points can be used on this bill.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Points to use',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value <= 0) return;
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Use points'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (requested == null || !mounted) return;

    final redemption = maxLoyaltyRedemption(
      saleMinor: saleTotals.totalMinor,
      availablePoints: balance,
      requestedPoints: requested,
      program: program,
    );
    if (redemption.points <= 0 || redemption.amountMinor <= 0) return;

    final grossByProduct = <String, int>{};
    var totalGross = 0;
    for (final entry in quantitiesMilli.entries) {
      final product = cartProducts[entry.key];
      if (product == null) continue;
      final gross = (product.unitPriceMinor * entry.value + 500) ~/ 1000;
      grossByProduct[entry.key] = gross;
      totalGross += gross;
    }
    if (totalGross <= 0) return;

    setState(() {
      _clearDynamicDiscountsInState();
      var allocated = 0;
      final entries = grossByProduct.entries.toList();
      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];
        final share = i == entries.length - 1
            ? redemption.amountMinor - allocated
            : redemption.amountMinor * entry.value ~/ totalGross;
        if (share <= 0) continue;
        discountsMinor[entry.key] = share;
        discountSources[entry.key] = 'loyalty';
        discountReferences[entry.key] = customer.id;
        allocated += share;
      }
      appliedPromotionName = null;
    });
  }

  Future<void> applyBestOffer() async {
    if (cartLines.isEmpty) return;
    final hasManualDiscount = discountSources.values.any(
      (source) => source != 'promotion',
    );
    if (hasManualDiscount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Remove manual discounts before applying an offer.'),
        ),
      );
      return;
    }

    setState(_clearDynamicDiscountsInState);
    final evaluation = await widget.database.bestPromotionForLines(cartLines);
    if (!mounted) return;
    if (evaluation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active offer applies to this bill.')),
      );
      return;
    }

    setState(() {
      for (final entry in evaluation.lineDiscounts.entries) {
        if (entry.value <= 0) continue;
        discountsMinor[entry.key] = entry.value;
        discountSources[entry.key] = 'promotion';
        discountReferences[entry.key] = evaluation.promotion.id;
      }
      appliedPromotionName = evaluation.promotion.name;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${evaluation.promotion.name} applied: '
          '${formatInr(evaluation.discountMinor)} off',
        ),
      ),
    );
  }

  Future<void> holdCurrentSale() async {
    final lines = cartLines;
    if (lines.isEmpty) return;
    await widget.database.holdSale(
      lines: lines,
      customerId: selectedCustomer?.id,
    );
    if (!mounted) return;
    setState(() {
      quantitiesMilli.clear();
      discountsMinor.clear();
      discountSources.clear();
      discountReferences.clear();
      appliedPromotionName = null;
      cartProducts.clear();
      selectedCustomer = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bill held. You can resume it later.')),
    );
  }

  Future<void> resumeHeldSale() async {
    final held = await widget.database.listHeldSales();
    if (!mounted) return;
    if (held.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No held bills.')),
      );
      return;
    }

    final selected = await showDialog<HeldSale>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Resume held bill'),
        children: [
          for (final sale in held)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, sale),
              child: ListTile(
                leading: const Icon(Icons.pause_circle_outline),
                title: Text(
                  sale.customerName == null
                      ? 'Guest bill'
                      : sale.customerName!,
                ),
                subtitle: Text(
                  '${sale.lines.length} item'
                  '${sale.lines.length == 1 ? '' : 's'} • '
                  '${sale.heldAt.toLocal()}',
                ),
              ),
            ),
        ],
      ),
    );
    if (selected == null) return;
    final resumed = await widget.database.resumeHeldSale(selected.id);
    LocalCustomer? customer;
    if (resumed.customerId != null) {
      final matches = await widget.database.listCustomers();
      for (final item in matches) {
        if (item.id == resumed.customerId) {
          customer = item;
          break;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      quantitiesMilli.clear();
      discountsMinor.clear();
      discountSources.clear();
      discountReferences.clear();
      appliedPromotionName = null;
      cartProducts.clear();
      for (final line in resumed.lines) {
        cartProducts[line.product.id] = line.product;
        quantitiesMilli[line.product.id] = line.quantityMilli;
        discountsMinor[line.product.id] = line.discountMinor;
        if (line.discountSource != null) {
          discountSources[line.product.id] = line.discountSource!;
        }
        if (line.discountReferenceId != null) {
          discountReferences[line.product.id] = line.discountReferenceId!;
        }
      }
      selectedCustomer = customer;
    });
  }

  Future<void> chooseCustomer() async {
    final customers = await widget.database.listCustomers();
    if (!mounted) return;

    final selected = await showDialog<LocalCustomer?>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Choose customer'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext),
            child: const ListTile(
              leading: Icon(Icons.person_outline),
              title: Text('Guest checkout'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          for (final customer in customers)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, customer),
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(customer.name),
                subtitle: Text(
                  [
                    if (customer.creditBalanceMinor > 0)
                      '${formatInr(customer.creditBalanceMinor)} due',
                    if (customer.loyaltyPoints > 0)
                      '${customer.loyaltyPoints} points',
                  ].isEmpty
                      ? 'No balance'
                      : [
                          if (customer.creditBalanceMinor > 0)
                            '${formatInr(customer.creditBalanceMinor)} due',
                          if (customer.loyaltyPoints > 0)
                            '${customer.loyaltyPoints} points',
                        ].join(' • '),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (customers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Add customers from the Customers tab first.'),
            ),
        ],
      ),
    );

    if (!mounted) return;
    setState(() => selectedCustomer = selected);
  }

  Future<int?> chooseCreditDays() {
    return showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('When should payment be due?'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 7),
            child: const Text('7 days'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 14),
            child: const Text('14 days'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 30),
            child: const Text('30 days'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 0),
            child: const Text('No due date'),
          ),
        ],
      ),
    );
  }

  Future<void> completeSale(
    OfflineSaleResult result, {
    required String title,
  }) async {
    if (!mounted) return;
    setState(() {
      quantitiesMilli.clear();
      discountsMinor.clear();
      discountSources.clear();
      discountReferences.clear();
      appliedPromotionName = null;
      cartProducts.clear();
      selectedCustomer = null;
    });
    await refreshProducts(searchController.text);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SelectableText(result.receiptText),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await ClipboardReceiptOutputAdapter().output(result.receiptText);
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Receipt copied.')),
                );
              }
            },
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copy'),
          ),
          TextButton.icon(
            onPressed: () =>
                SystemShareReceiptOutputAdapter().output(result.receiptText),
            icon: const Icon(Icons.share_outlined),
            label: const Text('Share'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('New sale'),
          ),
        ],
      ),
    );
  }

  Future<void> checkout() async {
    final saleTotals = totals;
    if (saleTotals == null) return;

    final methods = <PaymentMethod>{PaymentMethod.cash};
    if (selectedCustomer != null) {
      methods.add(PaymentMethod.customerCredit);
    }

    final paymentChoice = await showPaymentMethodSheet(
      context,
      availableMethods: methods,
      splitEnabled: false,
    );
    if (!mounted || paymentChoice == null) return;

    if (paymentChoice == PaymentChoice.customerCredit) {
      final customer = selectedCustomer;
      if (customer == null) return;
      final days = await chooseCreditDays();
      if (!mounted || days == null) return;
      final dueDate = days == 0
          ? null
          : DateTime.now().toUtc().add(Duration(days: days));
      try {
        final result = await widget.database.finalizeCustomerCreditSale(
          context: widget.saleContext,
          lines: cartLines,
          customerId: customer.id,
          dueDate: dueDate,
        );
        await completeSale(
          result,
          title: '${customer.name}: ${formatInr(result.totalMinor)} due',
        );
      } on Object {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Credit sale was not saved. Try again.')),
          );
        }
      }
      return;
    }

    if (paymentChoice != PaymentChoice.cash) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This payment method needs a configured provider.'),
        ),
      );
      return;
    }

    final exact = saleTotals.totalMinor;
    final quick500 = exact <= 50000 ? 50000 : null;
    final quick1000 = exact <= 100000 ? 100000 : null;
    final other = TextEditingController();

    final tendered = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bill ${formatInr(exact)}',
                style: Theme.of(sheetContext).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text('Cash received'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, exact),
                    child: Text('Exact ${formatInr(exact)}'),
                  ),
                  if (quick500 != null)
                    FilledButton.tonal(
                      onPressed: () => Navigator.pop(sheetContext, quick500),
                      child: const Text('₹500'),
                    ),
                  if (quick1000 != null)
                    FilledButton.tonal(
                      onPressed: () => Navigator.pop(sheetContext, quick1000),
                      child: const Text('₹1000'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: other,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Other amount ₹',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  final value = parseRupeesToMinor(other.text);
                  if (value != null && value >= exact) {
                    Navigator.pop(sheetContext, value);
                  }
                },
                child: const Text('Take cash'),
              ),
            ],
          ),
        ),
      ),
    );
    other.dispose();

    if (tendered == null) return;

    try {
      final result = await widget.database.finalizeCashSale(
        context: widget.saleContext,
        lines: cartLines,
        tenderedMinor: tendered,
        customerId: selectedCustomer?.id,
      );
      await completeSale(
        result,
        title: 'Return ${formatInr(result.changeMinor)}',
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sale was not saved. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final saleTotals = totals;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: SearchBar(
                  controller: searchController,
                  hintText: 'Search name or scan barcode',
                  leading: const Icon(Icons.search),
                  onSubmitted: refreshProducts,
                  onChanged: (value) {
                    if (value.isEmpty) {
                      refreshProducts();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Scan barcode',
                onPressed: scanBarcode,
                icon: const Icon(Icons.qr_code_scanner),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Add product',
                onPressed: showAddProduct,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: chooseCustomer,
                icon: const Icon(Icons.person_outline),
                label: Text(
                  selectedCustomer == null
                      ? 'Guest customer'
                      : selectedCustomer!.name,
                ),
              ),
              OutlinedButton.icon(
                onPressed: totals == null ? null : holdCurrentSale,
                icon: const Icon(Icons.pause_circle_outline),
                label: const Text('Hold'),
              ),
              OutlinedButton.icon(
                onPressed: resumeHeldSale,
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Resume'),
              ),
              OutlinedButton.icon(
                onPressed: totals == null ? null : applyBestOffer,
                icon: const Icon(Icons.local_offer_outlined),
                label: Text(
                  appliedPromotionName == null
                      ? 'Apply offer'
                      : appliedPromotionName!,
                ),
              ),
              OutlinedButton.icon(
                onPressed: totals == null ? null : redeemLoyalty,
                icon: const Icon(Icons.stars_outlined),
                label: Text(
                  selectedCustomer?.loyaltyPoints == null ||
                          selectedCustomer!.loyaltyPoints == 0
                      ? 'Use points'
                      : '${selectedCustomer!.loyaltyPoints} points',
                ),
              ),
            ],
          ),
        ),
        if (pendingSync > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.cloud_upload_outlined, size: 18),
                const SizedBox(width: 6),
                Text(
                  '$pendingSync bill${pendingSync == 1 ? '' : 's'} waiting to sync',
                ),
              ],
            ),
          ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : products.isEmpty
                  ? const Center(
                      child: Text(
                        'No products yet. Tap + to add your first product.',
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        mainAxisExtent: 170,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        final quantity = quantitiesMilli[product.id] ?? 0;
                        return Card(
                          child: InkWell(
                            onTap: () => add(product),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: Text(
                                      product.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    formatInr(product.unitPriceMinor),
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                  if (quantity > 0)
                                    Row(
                                      children: [
                                        IconButton(
                                          tooltip: 'Remove one',
                                          onPressed: () => removeOne(product),
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            '${quantity ~/ 1000}',
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Add one',
                                          onPressed: () => add(product),
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Discount',
                                          onPressed: () => setDiscount(product),
                                          icon: const Icon(
                                            Icons.percent_outlined,
                                          ),
                                        ),
                                      ],
                                    ),
                                  if ((discountsMinor[product.id] ?? 0) > 0)
                                    Text(
                                      discountSources[product.id] == 'promotion'
                                          ? 'Offer: ${formatInr(discountsMinor[product.id]!)} off'
                                          : discountSources[product.id] == 'loyalty'
                                              ? 'Loyalty: ${formatInr(discountsMinor[product.id]!)} off'
                                              : 'Discount ${formatInr(discountsMinor[product.id]!)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: saleTotals == null ? null : checkout,
              style: const ButtonStyle(
                minimumSize: WidgetStatePropertyAll(Size.fromHeight(56)),
              ),
              child: Text(
                saleTotals == null
                    ? 'Add items to bill'
                    : 'Pay ${formatInr(saleTotals.totalMinor)}',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

int? parseRupeesToMinor(String value) {
  final normalized = value.trim().replaceAll(',', '');
  if (!RegExp(r'^\d+(\.\d{0,2})?$').hasMatch(normalized)) {
    return null;
  }
  final parts = normalized.split('.');
  final rupees = int.parse(parts.first);
  final paiseText = parts.length == 1 ? '00' : parts[1].padRight(2, '0');
  return rupees * 100 + int.parse(paiseText);
}
