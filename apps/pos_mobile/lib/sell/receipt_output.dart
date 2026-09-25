import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

abstract interface class ReceiptOutputAdapter {
  Future<void> output(String receiptText);
}

class ClipboardReceiptOutputAdapter implements ReceiptOutputAdapter {
  @override
  Future<void> output(String receiptText) {
    return Clipboard.setData(ClipboardData(text: receiptText));
  }
}

class SystemShareReceiptOutputAdapter implements ReceiptOutputAdapter {
  @override
  Future<void> output(String receiptText) async {
    await SharePlus.instance.share(
      ShareParams(text: receiptText),
    );
  }
}

abstract interface class ReceiptPrinterAdapter {
  bool get configured;

  Future<void> printTextReceipt(String receiptText);
}

class UnconfiguredReceiptPrinterAdapter implements ReceiptPrinterAdapter {
  const UnconfiguredReceiptPrinterAdapter();

  @override
  bool get configured => false;

  @override
  Future<void> printTextReceipt(String receiptText) {
    throw StateError('No receipt printer is configured');
  }
}
