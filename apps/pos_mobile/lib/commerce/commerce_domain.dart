import '../customers/customer_domain.dart';
import '../sell/sale_domain.dart';

enum CommerceChannel { whatsapp, web, phone, manual }

enum CommerceOrderStatus { received, confirmed, ready, completed, cancelled }

class CommerceOrderLine {
  const CommerceOrderLine({
    required this.product,
    required this.quantityMilli,
    required this.quotedUnitPriceMinor,
  });

  final Product product;
  final int quantityMilli;
  final int quotedUnitPriceMinor;

  SaleLineInput toSaleLine() => SaleLineInput(
        product: product,
        quantityMilli: quantityMilli,
      );
}

class LocalCommerceOrder {
  const LocalCommerceOrder({
    required this.id,
    required this.channel,
    required this.status,
    required this.receivedAt,
    required this.lines,
    this.customer,
    this.externalConversationRef,
    this.note,
    this.saleId,
  });

  final String id;
  final CommerceChannel channel;
  final CommerceOrderStatus status;
  final DateTime receivedAt;
  final List<CommerceOrderLine> lines;
  final LocalCustomer? customer;
  final String? externalConversationRef;
  final String? note;
  final String? saleId;

  int get quotedTotalMinor => lines.fold(
        0,
        (sum, line) =>
            sum +
            (line.quotedUnitPriceMinor * line.quantityMilli + 500) ~/ 1000,
      );
}

String commerceChannelValue(CommerceChannel channel) => switch (channel) {
      CommerceChannel.whatsapp => 'whatsapp',
      CommerceChannel.web => 'web',
      CommerceChannel.phone => 'phone',
      CommerceChannel.manual => 'manual',
    };

String commerceChannelLabel(CommerceChannel channel) => switch (channel) {
      CommerceChannel.whatsapp => 'WhatsApp',
      CommerceChannel.web => 'Web',
      CommerceChannel.phone => 'Phone',
      CommerceChannel.manual => 'Manual',
    };

CommerceChannel commerceChannelFromValue(String value) => switch (value) {
      'whatsapp' => CommerceChannel.whatsapp,
      'web' => CommerceChannel.web,
      'phone' => CommerceChannel.phone,
      _ => CommerceChannel.manual,
    };

String commerceOrderStatusValue(CommerceOrderStatus status) => switch (status) {
      CommerceOrderStatus.received => 'received',
      CommerceOrderStatus.confirmed => 'confirmed',
      CommerceOrderStatus.ready => 'ready',
      CommerceOrderStatus.completed => 'completed',
      CommerceOrderStatus.cancelled => 'cancelled',
    };

String commerceOrderStatusLabel(CommerceOrderStatus status) => switch (status) {
      CommerceOrderStatus.received => 'Received',
      CommerceOrderStatus.confirmed => 'Confirmed',
      CommerceOrderStatus.ready => 'Ready',
      CommerceOrderStatus.completed => 'Completed',
      CommerceOrderStatus.cancelled => 'Cancelled',
    };

CommerceOrderStatus commerceOrderStatusFromValue(String value) => switch (value) {
      'confirmed' => CommerceOrderStatus.confirmed,
      'ready' => CommerceOrderStatus.ready,
      'completed' => CommerceOrderStatus.completed,
      'cancelled' => CommerceOrderStatus.cancelled,
      _ => CommerceOrderStatus.received,
    };

CommerceOrderStatus nextCommerceOrderStatus(
  CommerceOrderStatus current,
  String action,
) {
  if (current == CommerceOrderStatus.received && action == 'confirm') {
    return CommerceOrderStatus.confirmed;
  }
  if (current == CommerceOrderStatus.confirmed && action == 'ready') {
    return CommerceOrderStatus.ready;
  }
  if ((current == CommerceOrderStatus.confirmed ||
          current == CommerceOrderStatus.ready) &&
      action == 'complete') {
    return CommerceOrderStatus.completed;
  }
  if ((current == CommerceOrderStatus.received ||
          current == CommerceOrderStatus.confirmed ||
          current == CommerceOrderStatus.ready) &&
      action == 'cancel') {
    return CommerceOrderStatus.cancelled;
  }
  throw StateError(
    'Invalid commerce transition: '
    '${commerceOrderStatusValue(current)} -> $action',
  );
}

bool canSendProactiveWhatsApp({
  required CommunicationConsent consent,
  required bool providerConfigured,
}) {
  return providerConfigured && consent == CommunicationConsent.optedIn;
}
