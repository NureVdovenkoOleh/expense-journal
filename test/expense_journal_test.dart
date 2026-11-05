import 'package:expense_journal/expense_journal.dart';
import 'package:test/test.dart';

void main() {
  test('вхідних рядків не менше 15', () {
    expect(rawExpenses.length, greaterThanOrEqualTo(15));
  });
}
