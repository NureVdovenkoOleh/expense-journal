import 'package:expense_journal/expense_journal.dart';
import 'package:test/test.dart';

/// Створює витрату для тестів; задавати треба лише важливі поля.
Expense _expense({
  DateTime? date,
  double amount = 100,
  Currency currency = Currency.uah,
  String category = 'Продукти',
}) => Expense(
  id: 'T1',
  date: date ?? DateTime(2026, 10, 15),
  category: category,
  amount: amount,
  currency: currency,
  paymentMethod: const Cash(),
);

void main() {
  final today = DateTime(2026, 11, 12);

  test('вхідних рядків не менше 15', () {
    expect(rawExpenses.length, greaterThanOrEqualTo(15));
  });

  group('parseExpense', () {
    test('розбирає коректний рядок', () {
      final (:expense, :error) = parseExpense(rawExpenses.first);
      expect(error, isNull);
      expect(expense?.amount, 845.50);
    });

    test('повертає опис помилки замість винятку', () {
      final (:expense, :error) = parseExpense(
        'E19;2026-02-30;Продукти;75;UAH;готівка;-',
      );
      expect(expense, isNull);
      expect(error, contains('2026-02-30'));
    });
  });

  group('validateExpense', () {
    test('не має зауважень до коректної витрати', () {
      expect(validateExpense(_expense(), today: today), isEmpty);
    });

    test('знаходить від’ємну суму', () {
      expect(
        validateExpense(_expense(amount: -150), today: today),
        hasLength(1),
      );
    });

    test('знаходить дату з майбутнього', () {
      final expense = _expense(date: DateTime(2027, 1, 15));
      expect(validateExpense(expense, today: today), hasLength(1));
    });
  });

  group('аналітика', () {
    final expenses = validExpenses(rawExpenses.map(parseExpense), today: today);

    test('відбирає 15 коректних витрат', () {
      expect(expenses, hasLength(15));
    });

    test('рахує суму в гривнях', () {
      expect(
        totalAmount(expenses, currency: Currency.uah),
        closeTo(6254.45, 0.001),
      );
    });

    test('рахує суму всіх валют у гривнях за курсом', () {
      expect(totalInUah(expenses), closeTo(9792.535, 0.001));
    });

    test('рахує комісію за переказами', () {
      expect(totalFeesInUah(expenses), closeTo(11.35375, 0.001));
    });

    test('повертає мінімум, максимум і середнє одним записом', () {
      final stats = amountStats(expenses, currency: Currency.uah);
      expect(stats?.min, 30);
      expect(stats?.max, 1630.75);
      expect(stats?.average, closeTo(521.204, 0.001));
    });

    test('групує суми за видом оплати', () {
      final totals = totalsByPaymentKind(expenses);
      expect(totals['Visa'], closeTo(3538.085, 0.001));
      expect(totals['Mastercard'], closeTo(2815.90, 0.001));
      expect(totals['Готівка'], closeTo(1167.80, 0.001));
      expect(totals['Банківський переказ'], closeTo(2270.75, 0.001));
    });

    test('повертає null для середнього в порожньому списку', () {
      expect(averageAmount(<Expense>[], currency: Currency.uah), isNull);
    });

    test('групує витрати за категорією', () {
      expect(groupByCategory(expenses)['Продукти'], hasLength(3));
    });

    test('сортує за сумою за спаданням', () {
      final sorted = sortExpenses(
        inCurrency(expenses, currency: Currency.uah),
        compare: compareByAmount,
        ascending: false,
      );
      expect(sorted.first.amount, 1630.75);
    });
  });

  group('дати', () {
    final expense = _expense(date: DateTime(2026, 10, 30));

    test('форматує дату як ДД.ММ.РРРР', () {
      expect(formatDate(DateTime(2026, 3, 7)), '07.03.2026');
    });

    test('рахує вік запису в днях', () {
      expect(ageInDays(expense, today: DateTime(2026, 11, 9)), 10);
    });

    test('предикат olderThan запам’ятовує поріг', () {
      final isOld = olderThan(const Duration(days: 7), today: today);
      expect(isOld(expense), isTrue);
    });
  });

  group('звіт', () {
    test('маскує номер картки в примітці', () {
      expect(
        maskCardNumbers('Обід, картка 5375 4141 0000 9876'),
        'Обід, картка 5375 **** **** 9876',
      );
    });

    test('містить підсумок і не показує повних номерів', () {
      final report = buildReport(
        validExpenses(rawExpenses.map(parseExpense), today: today),
        today: today,
      );
      expect(report, contains('Разом: 6254.45'));
      expect(report, contains('•••• 9876'));
      expect(report, isNot(contains('5375414100009876')));
    });
  });
}
