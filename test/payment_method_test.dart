import 'package:expense_journal/expense_journal.dart';
import 'package:test/test.dart';

void main() {
  group('PaymentMethod.parse', () {
    test('для готівки повертає той самий константний екземпляр', () {
      expect(identical(PaymentMethod.parse('готівка'), const Cash()), isTrue);
    });

    test('розбирає картку й маскує номер', () {
      final method = PaymentMethod.parse('картка:5375414100009876');
      expect(method, isA<CardPayment>());
      expect(method.describe(), 'картка •••• 9876');
    });

    test('розбирає переказ і рахує комісію', () {
      final method = PaymentMethod.parse(
        'переказ:UA213223130000026007233566001',
      );
      expect(method, isA<BankTransfer>());
      expect(method.feeFor(1000), closeTo(5, 0.001));
    });

    test('кидає FormatException для невідомого формату', () {
      expect(
        () => PaymentMethod.parse('картка:123'),
        throwsA(isA<FormatException>()),
      );
    });

    test('tryParse повертає null замість винятку', () {
      expect(PaymentMethod.tryParse('біткоїн'), isNull);
    });
  });
}
