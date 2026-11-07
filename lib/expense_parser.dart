/// Розбір рядків журналу витрат.
library;

import 'expense.dart';
import 'expense_data.dart';

/// Результат розбору одного рядка: витрата або опис помилки.
///
/// Якщо розбір вдався, `expense` містить витрату, а `error` дорівнює
/// `null`; якщо ні — навпаки.
typedef ParseResult = ({Expense? expense, String? error});

/// Ширина місяця й дня в даті формату `РРРР-ММ-ДД`.
const _dateComponentWidth = 2;

/// Шаблон дати `РРРР-ММ-ДД` з іменованими групами.
final _datePattern = RegExp(r'^(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})$');

/// Розбирає рядок [line] у витрату.
///
/// Функція не кидає винятків: для пошкодженого рядка вона повертає
/// результат, у якому `expense` дорівнює `null`, а `error` пояснює
/// причину.
ParseResult parseExpense(String line) {
  final fields = line.split(fieldSeparator).map((f) => f.trim()).toList();
  if (fields.length != expectedFieldCount) {
    return _failure(
      'очікувалося $expectedFieldCount полів, а отримано ${fields.length}',
    );
  }

  final [dateText, category, amountText, currency, paymentMethod, note] =
      fields;

  final date = _parseDate(dateText);
  if (date == null) {
    return _failure('некоректна дата «$dateText»');
  }

  final amount = double.tryParse(amountText);
  if (amount == null) {
    return _failure('сума «$amountText» не є числом');
  }

  return (
    expense: (
      date: date,
      category: category,
      amount: amount,
      currency: currency,
      paymentMethod: paymentMethod,
      note: note,
    ),
    error: null,
  );
}

/// Створює результат розбору з помилкою [message].
ParseResult _failure(String message) => (expense: null, error: message);

/// Перетворює [text] на дату, якщо він має формат `РРРР-ММ-ДД` і
/// позначає день, який справді існує.
DateTime? _parseDate(String text) {
  final match = _datePattern.firstMatch(text);
  if (match == null) {
    return null;
  }

  final date = DateTime.tryParse(text);
  if (date == null) {
    return null;
  }

  // DateTime.tryParse не відкидає неіснуючі дати, а переносить їх:
  // «2026-02-30» перетворюється на 2 березня. Тому порівнюємо місяць
  // і день отриманої дати з тим, що було записано в тексті.
  final isExistingDay =
      match.namedGroup('month') == _twoDigits(date.month) &&
      match.namedGroup('day') == _twoDigits(date.day);
  return isExistingDay ? date : null;
}

/// Записує [value] двома цифрами з провідним нулем: 3 → «03».
String _twoDigits(int value) =>
    value.toString().padLeft(_dateComponentWidth, '0');
