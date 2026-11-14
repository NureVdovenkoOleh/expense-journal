import 'package:expense_journal/expense_journal.dart';

/// Ідентифікатор витрати, яку програма шукає в сховищі для прикладу.
const lookupId = 'E05';

/// Точка входу: розбирає й перевіряє журнал витрат і друкує звіт.
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

  final journal = Repository<Expense>()..addAll(validExpenses(results));

  print('');
  print(buildReport(journal.all.toList()));

  print('Сховище');
  print('  Записів: ${journal.length}');
  print('  Пошук $lookupId: ${journal.findById(lookupId) ?? 'не знайдено'}');
  final byCard = journal.where((e) => e.paymentMethod is CardPayment);
  print('  Оплачено карткою: ${byCard.length}');
}
