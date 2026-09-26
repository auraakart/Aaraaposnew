import 'package:flutter/material.dart';

import '../operations/operations_domain.dart';
import '../sell/local_pos_database.dart';
import '../sell/return_domain.dart';
import '../sell/sale_domain.dart';

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({
    required this.database,
    required this.saleContext,
    super.key,
  });

  final LocalPosDatabase database;
  final LocalSaleContext saleContext;

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  final searchController = TextEditingController();
  List<ReturnableSale> sales = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> refresh([String query = '']) async {
    final next = await widget.database.listReturnableSales(query: query);
    if (!mounted) return;
    setState(() {
      sales = next;
      loading = false;
    });
  }

  Future<void> returnFromSale(ReturnableSale sale) async {
    ReturnableSaleLine? selectedLine;
    final quantity = TextEditingController();
    final reason = TextEditingController(text: 'Customer return');

    final request = await showDialog<ReturnLineRequest>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Return • ${sale.invoiceNumber}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final line in sale.lines)
                  ListTile(
                    selected: selectedLine?.saleLineId == line.saleLineId,
                    leading: Icon(
                      selectedLine?.saleLineId == line.saleLineId
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    onTap: () {
                      setDialogState(() {
                        selectedLine = line;
                        quantity.text =
                            _formatQuantity(line.remainingQuantityMilli);
                      });
                    },
                    title: Text(line.productName),
                    subtitle: Text(
                      '${_formatQuantity(line.remainingQuantityMilli)} can be returned',
                    ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: quantity,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Quantity to return',
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
                const SizedBox(height: 12),
                const Text(
                  'Refund follows the original payment. Pay Later returns reduce unpaid credit first; any already-paid amount is refunded in cash.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final line = selectedLine;
                final milli = _parseQuantity(quantity.text);
                if (line == null ||
                    milli == null ||
                    milli <= 0 ||
                    milli > line.remainingQuantityMilli ||
                    reason.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  ReturnLineRequest(
                    saleLineId: line.saleLineId,
                    quantityMilli: milli,
                  ),
                );
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );

    if (request == null || !mounted) {
      quantity.dispose();
      reason.dispose();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm return'),
        content: Text(
          'This will restore stock and create an immutable refund record.\n\n'
          'Reason: ${reason.text.trim()}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm refund'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      quantity.dispose();
      reason.dispose();
      return;
    }

    final reasonText = reason.text.trim();
    final selectedForApproval = selectedLine!;

    try {
      final result = await widget.database.processReturn(
        context: widget.saleContext,
        saleId: sale.saleId,
        requests: [request],
        reason: reasonText,
      );
      quantity.dispose();
      reason.dispose();
      await refresh(searchController.text);
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Return ${result.returnNumber} saved'),
          content: Text(
            'Refund total: ${formatInr(result.refundMinor)}\n'
            'Cash refund: ${formatInr(result.cashRefundMinor)}\n'
            'Credit reduced: ${formatInr(result.creditReversalMinor)}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } on Object catch (error) {
      final requiresApproval = error.toString().contains('Manager approval');
      var message = 'Return could not be saved. Check the bill and try again.';

      if (requiresApproval) {
        final expectedRefund = prorateReturnMinor(
          originalMinor: selectedForApproval.totalMinor,
          partQuantityMilli: request.quantityMilli,
          originalQuantityMilli: selectedForApproval.soldQuantityMilli,
        );
        final fingerprint = buildApprovalFingerprint(
          actionType: 'refund',
          entityId: sale.saleId,
          facts: [
            '${request.saleLineId}:${request.quantityMilli}',
            'amount:$expectedRefund',
          ],
        );
        try {
          await widget.database.requestApproval(
            context: widget.saleContext,
            actionType: 'refund',
            entityType: 'sale',
            entityId: sale.saleId,
            actionFingerprint: fingerprint,
            requestedAmountMinor: expectedRefund,
            reason:
                'Refund ${formatInr(expectedRefund)} • ${sale.invoiceNumber} • $reasonText',
          );
          message =
              'Approval request sent. Retry this refund after the Owner or Manager approves it.';
        } on Object {
          message =
              'Approval is required, but the request could not be saved. Try again.';
        }
      } else if (error.toString().contains('Provider refund')) {
        message =
            'This payment provider is not configured for refunds yet.';
      }

      quantity.dispose();
      reason.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SearchBar(
            controller: searchController,
            hintText: 'Find bill number or customer',
            leading: const Icon(Icons.search),
            onSubmitted: refresh,
            onChanged: (value) {
              if (value.isEmpty) refresh();
            },
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : sales.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No refundable bills found.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: sales.length,
                      itemBuilder: (context, index) {
                        final sale = sales[index];
                        return Card(
                          child: ListTile(
                            onTap: () => returnFromSale(sale),
                            leading: const Icon(Icons.receipt_long_outlined),
                            title: Text(sale.invoiceNumber),
                            subtitle: Text(
                              '${sale.customerName ?? 'Guest'} • '
                              '${sale.lines.length} refundable item'
                              '${sale.lines.length == 1 ? '' : 's'}',
                            ),
                            trailing: Text(formatInr(sale.totalMinor)),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
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
