import 'package:expense_journal/expense_journal.dart';

/// Точка входу: розбирає й перевіряє вхідні рядки журналу витрат.
void main(List<String> arguments) {
  final results = rawExpenses.map(parseExpense).toList();
  print('Вхідних рядків: ${results.length}');

  for (final (index, (:expense, :error)) in results.indexed) {
    final lineNumber = index + 1;
    if (expense == null) {
      print('Рядок $lineNumber пропущено: $error');
      continue;
    }
    final violations = validateExpense(expense);
    if (violations.isNotEmpty) {
      print('Рядок $lineNumber не пройшов перевірку: ${violations.join('; ')}');
    }
  }

  final validExpenses = results
      .map((result) => result.expense)
      .nonNulls
      .where((expense) => validateExpense(expense).isEmpty)
      .toList();
  print('Коректних витрат: ${validExpenses.length}');
}
