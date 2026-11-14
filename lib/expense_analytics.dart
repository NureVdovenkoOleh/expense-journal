/// Конвеєри обробки витрат: фільтрація, перетворення, згортання,
/// групування й сортування.
///
/// Агрегація виконується ланцюжками `where → map → fold`, а не циклами
/// з накопичувальною змінною.
library;

import 'dart:math' as math;

import 'currency.dart';
import 'expense.dart';
import 'expense_parser.dart';
import 'expense_validator.dart';
import 'payment_method.dart';

/// Підсумовування числової ознаки елементів будь-якої колекції.
///
/// Узагальнене розширення вбудованого типу [Iterable]: параметр типу `T`
/// дозволяє викликати [sumOf] для колекції будь-яких елементів.
extension SumOf<T> on Iterable<T> {
  /// Додає значення, які [selector] повертає для кожного елемента.
  ///
  /// Для порожньої колекції повертає 0.
  double sumOf(double Function(T item) selector) =>
      fold(0.0, (total, item) => total + selector(item));
}

/// Повертає витрати з [results], які вдалося розібрати й які пройшли
/// перевірку.
///
/// Параметр [today] передається валідатору; див. [validateExpense].
List<Expense> validExpenses(Iterable<ParseResult> results, {DateTime? today}) =>
    results
        .map((result) => result.expense)
        .nonNulls
        .where((expense) => validateExpense(expense, today: today).isEmpty)
        .toList();

/// Відбирає з [expenses] лише витрати у валюті [currency].
///
/// Конвеєр фільтрації: суми в різних валютах не можна додавати між собою,
/// тому всі агрегатні функції спершу відбирають одну валюту.
Iterable<Expense> inCurrency(
  Iterable<Expense> expenses, {
  required Currency currency,
}) => expenses.where((expense) => expense.currency == currency);

/// Обчислює загальну суму витрат з [expenses] у валюті [currency].
///
/// Конвеєр згортання `where → map → fold`.
double totalAmount(Iterable<Expense> expenses, {required Currency currency}) =>
    inCurrency(expenses, currency: currency)
        .map((expense) => expense.amount)
        .fold(0.0, (total, amount) => total + amount);

/// Обчислює середню витрату з [expenses] у валюті [currency].
///
/// Повертає `null`, якщо витрат у цій валюті немає: ділити на нуль
/// безглуздо.
double? averageAmount(
  Iterable<Expense> expenses, {
  required Currency currency,
}) {
  final count = inCurrency(expenses, currency: currency).length;
  if (count == 0) {
    return null;
  }
  return totalAmount(expenses, currency: currency) / count;
}

/// Знаходить найбільшу витрату з [expenses] у валюті [currency].
///
/// Використано `fold` з початковим значенням `null`, а не `reduce`:
/// `reduce` на порожній колекції кидає виняток.
Expense? largestExpense(
  Iterable<Expense> expenses, {
  required Currency currency,
}) => inCurrency(expenses, currency: currency).fold<Expense?>(
  null,
  (largest, expense) =>
      largest == null || expense.amount > largest.amount ? expense : largest,
);

/// Обчислює загальну суму [expenses] у гривнях за умовним курсом.
///
/// На відміну від [totalAmount], додає витрати в усіх валютах: кожну
/// суму спершу перераховано в гривні методом [Currency.toUah].
double totalInUah(Iterable<Expense> expenses) =>
    expenses.sumOf((expense) => expense.amountInUah);

/// Обчислює сумарну комісію за всіма витратами [expenses] у гривнях.
double totalFeesInUah(Iterable<Expense> expenses) =>
    expenses.sumOf((expense) => expense.currency.toUah(expense.fee));

/// Обчислює мінімальну, максимальну й середню суму витрат [expenses]
/// у валюті [currency].
///
/// Повертає запис із трьох іменованих полів, тобто кілька значень
/// одночасно, або `null`, якщо витрат у цій валюті немає.
({double min, double max, double average})? amountStats(
  Iterable<Expense> expenses, {
  required Currency currency,
}) {
  final amounts = inCurrency(
    expenses,
    currency: currency,
  ).map((expense) => expense.amount).toList();
  if (amounts.isEmpty) {
    return null;
  }
  // Список не порожній, тому reduce тут безпечний.
  return (
    min: amounts.reduce(math.min),
    max: amounts.reduce(math.max),
    average:
        amounts.fold(0.0, (total, amount) => total + amount) / amounts.length,
  );
}

/// Обчислює суму витрат у гривнях для кожного виду оплати
/// (див. [paymentKind]).
Map<String, double> totalsByPaymentKind(Iterable<Expense> expenses) =>
    expenses.fold(<String, double>{}, (totals, expense) {
      totals.update(
        paymentKind(expense.paymentMethod),
        (total) => total + expense.amountInUah,
        ifAbsent: () => expense.amountInUah,
      );
      return totals;
    });

/// Перетворює [expenses] на перелік назв категорій без повторів.
///
/// Конвеєр перетворення: зі списку записів отримуємо множину рядків.
Set<String> categoriesOf(Iterable<Expense> expenses) =>
    expenses.map((expense) => expense.category).toSet();

/// Групує [expenses] за категорією.
Map<String, List<Expense>> groupByCategory(Iterable<Expense> expenses) =>
    expenses.fold(<String, List<Expense>>{}, (groups, expense) {
      groups.putIfAbsent(expense.category, () => []).add(expense);
      return groups;
    });

/// Обчислює суму витрат у валюті [currency] для кожної категорії.
Map<String, double> totalsByCategory(
  Iterable<Expense> expenses, {
  required Currency currency,
}) => groupByCategory(inCurrency(expenses, currency: currency)).map(
  (category, items) =>
      MapEntry(category, totalAmount(items, currency: currency)),
);

/// Порівнює дві витрати за датою.
int compareByDate(Expense a, Expense b) => a.date.compareTo(b.date);

/// Порівнює дві витрати за сумою.
int compareByAmount(Expense a, Expense b) => a.amount.compareTo(b.amount);

/// Повертає новий список із [expenses], відсортований функцією [compare].
///
/// За замовчуванням витрати впорядковуються за датою. Якщо [ascending]
/// дорівнює `false`, порядок змінюється на спадний. Вихідна колекція
/// не змінюється.
List<Expense> sortExpenses(
  Iterable<Expense> expenses, {
  Comparator<Expense> compare = compareByDate,
  bool ascending = true,
}) {
  final Comparator<Expense> ordered = ascending
      ? compare
      : (a, b) => compare(b, a);
  return expenses.toList()..sort(ordered);
}
