/// Перевірка значень витрат на допустимість.
library;

import 'expense.dart';

/// Валюти, у яких дозволено вести журнал.
const supportedCurrencies = {'UAH', 'USD', 'EUR'};

/// Допустимі способи оплати.
const supportedPaymentMethods = {'картка', 'готівка', 'переказ'};

/// Найбільша допустима сума однієї витрати.
const maxAmount = 100000.0;

/// Найменший допустимий рік витрати.
const minYear = 2000;

/// Перевіряє витрату [expense] і повертає перелік виявлених порушень.
///
/// Порожній список означає, що витрата коректна. Дата витрати не може
/// бути пізнішою за [today]; якщо [today] не передано, береться поточна
/// дата.
List<String> validateExpense(Expense expense, {DateTime? today}) {
  final reference = today ?? DateTime.now();
  return [
    if (expense.category.isEmpty) 'не вказано категорію',
    if (expense.amount <= 0) 'сума ${expense.amount} не є додатною',
    if (expense.amount > maxAmount)
      'сума ${expense.amount} перевищує $maxAmount',
    if (!supportedCurrencies.contains(expense.currency))
      'невідома валюта «${expense.currency}»',
    if (!supportedPaymentMethods.contains(expense.paymentMethod))
      'невідомий спосіб оплати «${expense.paymentMethod}»',
    if (expense.date.year < minYear) 'дата раніша за $minYear рік',
    if (expense.date.isAfter(reference)) 'дата витрати ще не настала',
  ];
}
