import 'package:aaraapos_pos/commerce/commerce_domain.dart';
import 'package:aaraapos_pos/customers/customer_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('commerce lifecycle prevents unsafe status skips', () {
    expect(
      nextCommerceOrderStatus(CommerceOrderStatus.received, 'confirm'),
      CommerceOrderStatus.confirmed,
    );
    expect(
      nextCommerceOrderStatus(CommerceOrderStatus.confirmed, 'ready'),
      CommerceOrderStatus.ready,
    );
    expect(
      nextCommerceOrderStatus(CommerceOrderStatus.ready, 'complete'),
      CommerceOrderStatus.completed,
    );
    expect(
      () => nextCommerceOrderStatus(CommerceOrderStatus.received, 'ready'),
      throwsStateError,
    );
  });

  test('proactive WhatsApp needs provider and explicit opt-in', () {
    expect(
      canSendProactiveWhatsApp(
        consent: CommunicationConsent.optedIn,
        providerConfigured: true,
      ),
      isTrue,
    );
    expect(
      canSendProactiveWhatsApp(
        consent: CommunicationConsent.unknown,
        providerConfigured: true,
      ),
      isFalse,
    );
    expect(
      canSendProactiveWhatsApp(
        consent: CommunicationConsent.optedIn,
        providerConfigured: false,
      ),
      isFalse,
    );
  });
}
