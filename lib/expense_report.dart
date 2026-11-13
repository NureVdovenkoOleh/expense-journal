/// Формування текстового звіту за журналом витрат.
library;

import 'currency.dart';
import 'expense.dart';
import 'expense_analytics.dart';
import 'expense_dates.dart';

/// Валюта звіту за замовчуванням.
const defaultCurrency = Currency.uah;

/// Кількість знаків після коми для сум.
const amountFractionDigits = 2;

/// Шаблон номера банківської картки: 16 цифр, можливо розділених
/// пробілами або дефісами по чотири.
final _cardNumberPattern = RegExp(
  r'\b(?<first>\d{4})[ -]?\d{4}[ -]?\d{4}[ -]?(?<last>\d{4})\b',
);

/// Приховує середні вісім цифр номерів карток у тексті [text].
///
/// Наприклад, «4149 6090 1234 5678» стає «4149 **** **** 5678».
String maskCardNumbers(String text) =>
    text.replaceAllMapped(_cardNumberPattern, (match) {
      // Сюди завжди потрапляє RegExpMatch, але параметр має тип Match,
      // у якого немає namedGroup. Перевірка `is!` звужує тип без
      // приведення `as`.
      if (match is! RegExpMatch) {
        return match.group(0) ?? '';
      }
      final first = match.namedGroup('first');
      final last = match.namedGroup('last');
      return '$first **** **** $last';
    });

/// Формує текстовий звіт за витратами [items].
///
/// Звіт містить підсумки у валюті [currency], суми за категоріями,
/// [topCount] витрат з найбільшими сумами (або з найменшими, якщо
/// [ascending] дорівнює `true`) і [topCount] найновіших витрат. Стовпці
/// таблиць розділяються рядком [separator]. Вік записів обчислюється
/// відносно [today]; якщо його не передано, береться поточна дата.
String buildReport(
  List<Expense> items, {
  int topCount = 5,
  bool ascending = false,
  String separator = ' | ',
  Currency currency = defaultCurrency,
  DateTime? today,
}) {
  final reference = today ?? DateTime.now();
  final buffer = StringBuffer()
    ..writeln('ЗВІТ ЗА ЖУРНАЛОМ ВИТРАТ')
    ..writeln('Сформовано: ${formatDate(reference)}')
    ..writeln('Коректних записів: ${items.length}')
    ..writeln()
    ..writeln('Підсумки (${currency.code})')
    ..writeln('  Разом: ${_money(totalAmount(items, currency: currency))}');

  // Функція повертає запис; зразок `case` перевіряє, що він не null,
  // і одразу розкладає його поля на змінні min, max і average.
  if (amountStats(items, currency: currency) case (
    :final min,
    :final max,
    :final average,
  )) {
    buffer
      ..writeln('  Середня витрата: ${_money(average)}')
      ..writeln('  Від ${_money(min)} до ${_money(max)}');
  }
  final largest = largestExpense(items, currency: currency);
  if (largest != null) {
    buffer.writeln(
      '  Найбільша: ${largest.category}, ${_money(largest.amount)}',
    );
  }

  final isStale = olderThan(staleAge, today: reference);
  buffer
    ..writeln('  Усі валюти в гривнях: ${_money(totalInUah(items))}')
    ..writeln('  Комісії банку в гривнях: ${_money(totalFeesInUah(items))}')
    ..writeln(
      '  Записів, давніших за ${staleAge.inDays} днів: '
      '${items.where(isStale).length}',
    )
    ..writeln()
    ..writeln('За категоріями (${currency.code})');

  final totals = totalsByCategory(items, currency: currency).entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final MapEntry(key: category, value: total) in totals) {
    buffer.writeln('  $category: ${_money(total)}');
  }

  buffer
    ..writeln()
    ..writeln('За видом оплати (UAH за курсом)');
  final kinds = totalsByPaymentKind(items).entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final MapEntry(key: kind, value: total) in kinds) {
    buffer.writeln('  $kind: ${_money(total)}');
  }

  final byAmount = sortExpenses(
    inCurrency(items, currency: currency),
    compare: compareByAmount,
    ascending: ascending,
  );
  final order = ascending ? 'Найменші' : 'Найбільші';
  buffer
    ..writeln()
    ..writeln('$order витрати (${currency.code})');
  for (final expense in byAmount.take(topCount)) {
    buffer.writeln(_row(expense, separator: separator, today: reference));
  }

  final byDate = sortExpenses(items, ascending: false);
  buffer
    ..writeln()
    ..writeln('Найновіші витрати');
  for (final expense in byDate.take(topCount)) {
    buffer.writeln(_row(expense, separator: separator, today: reference));
  }

  return buffer.toString();
}

/// Записує витрату [expense] одним рядком таблиці.
String _row(
  Expense expense, {
  required String separator,
  required DateTime today,
}) => [
  formatDate(expense.date),
  expense.category,
  '${_money(expense.amount)} ${expense.currency.code}',
  expense.paymentMethod.describe(),
  '${ageInDays(expense, today: today)} дн. тому',
  maskCardNumbers(expense.note),
].join(separator);

/// Форматує [amount] з двома знаками після коми.
String _money(double amount) => amount.toStringAsFixed(amountFractionDigits);
