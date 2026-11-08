import 'package:expense_journal/expense_journal.dart';

/// Валюта, у якій виводиться статистика.
const reportCurrency = 'UAH';

/// Кількість знаків після коми для сум.
const amountFractionDigits = 2;

/// Кількість найбільших витрат у виводі.
const topCount = 3;

/// Точка входу: розбирає, перевіряє й агрегує журнал витрат.
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

  final expenses = validExpenses(results);
  print('Коректних витрат: ${expenses.length}');
  print('Категорії: ${categoriesOf(expenses).join(', ')}');

  final total = totalAmount(expenses, currency: reportCurrency);
  final average = averageAmount(expenses, currency: reportCurrency);
  final largest = largestExpense(expenses, currency: reportCurrency);
  print('\nВитрати в $reportCurrency');
  print('Разом: ${_money(total)}');
  if (average != null) {
    print('Середня витрата: ${_money(average)}');
  }
  if (largest != null) {
    print('Найбільша: ${largest.category}, ${_money(largest.amount)}');
  }

  print('\nЗа категоріями ($reportCurrency):');
  final totals = totalsByCategory(expenses, currency: reportCurrency);
  for (final MapEntry(key: category, value: sum) in totals.entries) {
    print('  $category: ${_money(sum)}');
  }

  print('\nТоп-$topCount найбільших витрат ($reportCurrency):');
  final byAmount = sortExpenses(
    inCurrency(expenses, currency: reportCurrency),
    compare: compareByAmount,
    ascending: false,
  );
  for (final expense in byAmount.take(topCount)) {
    print('  ${expense.category}: ${_money(expense.amount)}');
  }

  print('\nНайновіші витрати:');
  final byDate = sortExpenses(expenses, ascending: false);
  for (final expense in byDate.take(topCount)) {
    print('  ${expense.date} ${expense.category}');
  }
}

/// Форматує [amount] з двома знаками після коми.
String _money(double amount) => amount.toStringAsFixed(amountFractionDigits);
