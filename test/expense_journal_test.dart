import 'package:expense_journal/expense_journal.dart';
import 'package:test/test.dart';

void main() {
  test('вхідних рядків не менше 15', () {
    expect(rawExpenses.length, greaterThanOrEqualTo(15));
  });

  group('parseExpense', () {
    test('розбирає коректний рядок', () {
      final (:expense, :error) = parseExpense(
        '2026-10-15;Продукти;930.40;UAH;картка;АТБ',
      );
      expect(error, isNull);
      expect(expense?.date, DateTime(2026, 10, 15));
      expect(expense?.amount, 930.40);
    });

    test('відкидає рядок із пропущеним полем', () {
      expect(parseExpense('2026-10-08;Продукти;UAH;картка;-').error, isNotNull);
    });

    test('відкидає нечислову суму', () {
      expect(parseExpense('2026-10-12;Кафе;сто;UAH;картка;-').error, isNotNull);
    });

    test('відкидає дату в іншому форматі', () {
      expect(parseExpense('31.10.2026;Кафе;60;UAH;картка;-').error, isNotNull);
    });

    test('відкидає неіснуючу дату 30 лютого', () {
      expect(parseExpense('2026-02-30;Кафе;75;UAH;картка;-').error, isNotNull);
    });
  });

  group('validateExpense', () {
    final today = DateTime(2026, 11, 7);

    test('не має зауважень до коректної витрати', () {
      final expense = (
        date: DateTime(2026, 10, 15),
        category: 'Продукти',
        amount: 930.40,
        currency: 'UAH',
        paymentMethod: 'картка',
        note: 'АТБ',
      );
      expect(validateExpense(expense, today: today), isEmpty);
    });

    test('знаходить від’ємну суму й невідому валюту', () {
      final expense = (
        date: DateTime(2026, 10, 20),
        category: 'Продукти',
        amount: -150.0,
        currency: 'XYZ',
        paymentMethod: 'картка',
        note: '',
      );
      expect(validateExpense(expense, today: today), hasLength(2));
    });
  });
}
