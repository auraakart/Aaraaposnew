import 'package:aaraapos_pos/inventory/stock_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quantity parsing uses milli-units without floating point', () {
    expect(parseQuantityToMilli('2'), 2000);
    expect(parseQuantityToMilli('1.5'), 1500);
    expect(parseQuantityToMilli('0.125'), 125);
    expect(parseQuantityToMilli('1.2345'), isNull);
  });

  test('quantity formatting is compact and understandable', () {
    expect(formatQuantity(2000), '2');
    expect(formatQuantity(1500), '1.5');
    expect(formatQuantity(-1250), '-1.25');
  });
}
