import 'package:expense_journal/expense_journal.dart';
import 'package:test/test.dart';

void main() {
  group('Currency', () {
    test('знаходить валюту за кодом', () {
      expect(Currency.tryParse('USD'), Currency.usd);
    });

    test('повертає null для невідомого коду', () {
      expect(Currency.tryParse('XYZ'), isNull);
    });

    test('перераховує суму в гривні', () {
      expect(Currency.usd.toUah(10), closeTo(415, 0.001));
      expect(Currency.uah.toUah(10), 10);
    });
  });
}
