import 'package:expense_journal/expense_journal.dart';

/// Точка входу: поки що виводить вхідні рядки журналу витрат.
void main(List<String> arguments) {
  print('Вхідних рядків: ${rawExpenses.length}');
  for (final (index, line) in rawExpenses.indexed) {
    print('${index + 1}. $line');
  }
}
