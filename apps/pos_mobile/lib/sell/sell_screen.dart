import 'package:flutter/material.dart';

import '../payments/payment_domain.dart';
import '../payments/payment_method_sheet.dart';
import 'local_pos_database.dart';
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
  final Map<String, Product> cartProducts = {};
  List<Product> products = const [];
  bool loading = true;
  int pendingSync = 0;

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
        lines.add(SaleLineInput(product: product, quantityMilli: entry.value));
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

  void add(Product product) {
    setState(() {
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
      final next = (quantitiesMilli[product.id] ?? 0) - 1000;
      if (next <= 0) {
        quantitiesMilli.remove(product.id);
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

  Future<void> checkout() async {
    final saleTotals = totals;
    if (saleTotals == null) {
      return;
    }

    final paymentChoice = await showPaymentMethodSheet(
      context,
      availableMethods: const {PaymentMethod.cash},
      splitEnabled: false,
    );
    if (paymentChoice == null) {
      return;
    }
    if (paymentChoice != PaymentChoice.cash) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This payment method needs a configured provider.'),
          ),
        );
      }
      return;
    }

    final exact = saleTotals.totalMinor;
    final quick500 = exact <= 50000 ? 50000 : null;
    final quick1000 = exact <= 100000 ? 100000 : null;
    final other = TextEditingController();

    final tendered = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
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
        );
      },
    );
    other.dispose();

    if (tendered == null) {
      return;
    }

    try {
      final result = await widget.database.finalizeCashSale(
        context: widget.saleContext,
        lines: cartLines,
        tenderedMinor: tendered,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        quantitiesMilli.clear();
        cartProducts.clear();
      });
      await refreshProducts(searchController.text);
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Return ${formatInr(result.changeMinor)}'),
          content: SelectableText(result.receiptText),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('New sale'),
            ),
          ],
        ),
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
                tooltip: 'Add product',
                onPressed: showAddProduct,
                icon: const Icon(Icons.add),
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
                                      ],
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
