import 'package:aaraapos_pos/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Hindi and Tamil core POS labels are translated', () {
    final hindi = AppStrings(const Locale('hi'));
    final tamil = AppStrings(const Locale('ta'));

    expect(hindi.sell, 'बिक्री');
    expect(hindi.customers, 'ग्राहक');
    expect(tamil.sell, 'விற்பனை');
    expect(tamil.stock, 'இருப்பு');
  });

  test('locale controller accepts reviewed locales only', () {
    final controller = AppLocaleController();
    addTearDown(controller.dispose);

    controller.setLocale(const Locale('hi'));
    expect(controller.locale?.languageCode, 'hi');

    expect(
      () => controller.setLocale(const Locale('te')),
      throwsArgumentError,
    );

    controller.useSystemLocale();
    expect(controller.locale, isNull);
  });

  test('planned languages remain separate from supported locales', () {
    expect(AppStrings.isSupportedCode('en'), isTrue);
    expect(AppStrings.isSupportedCode('hi'), isTrue);
    expect(AppStrings.isSupportedCode('ta'), isTrue);
    expect(AppStrings.isSupportedCode('te'), isFalse);
    expect(AppStrings.plannedLocaleCodes, contains('te'));
  });
}
