import 'package:expense_journal/expense_journal.dart';
import 'package:test/test.dart';

/// Рядок з усіма полями, на якому перевіряється розбір.
const _transferLine =
    'E05;2026-09-18;Комунальні;1630.75;UAH;'
    'переказ:UA213223130000026007233566001;Оплата за вересень';

void main() {
  group('Expense.fromCsv', () {
    test('розбирає всі поля', () {
      final expense = Expense.fromCsv(_transferLine);
      expect(expense.id, 'E05');
      expect(expense.date, DateTime(2026, 9, 18));
      expect(expense.amount, 1630.75);
      expect(expense.currency, Currency.uah);
      expect(expense.paymentMethod, isA<BankTransfer>());
      expect(expense.note, 'Оплата за вересень');
    });

    test('кидає FormatException для кожного пошкодженого рядка', () {
      final damaged = rawExpenses.where((line) {
        final id = line.split(fieldSeparator).first;
        return const {'E16', 'E17', 'E18', 'E19', 'E20', 'E21'}.contains(id);
      });
      expect(damaged, hasLength(6));
      for (final line in damaged) {
        expect(() => Expense.fromCsv(line), throwsFormatException);
      }
    });

    test('перераховує долари в гривні', () {
      final expense = Expense.fromCsv(
        'E04;2026-09-14;Навчання;10;USD;готівка;Курс',
      );
      expect(expense.amountInUah, closeTo(415, 0.001));
    });
  });

  group('Expense.cached', () {
    test('повертає той самий екземпляр для того самого рядка', () {
      expect(
        identical(Expense.cached(_transferLine), Expense.cached(_transferLine)),
        isTrue,
      );
    });

    test('fromCsv щоразу створює новий екземпляр', () {
      expect(
        identical(
          Expense.fromCsv(_transferLine),
          Expense.fromCsv(_transferLine),
        ),
        isFalse,
      );
    });
  });

  group('рівність', () {
    final first = Expense.fromCsv(_transferLine);
    final second = Expense.fromCsv(_transferLine);

    test('дві витрати з однаковими полями рівні', () {
      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('Set містить лише одну з двох однакових витрат', () {
      expect({first, second}, hasLength(1));
    });

    test('витрати з різними id не рівні', () {
      final other = Expense.fromCsv(_transferLine.replaceFirst('E05', 'E99'));
      expect(first == other, isFalse);
    });
  });
}
