/// Клас витрати — основна сутність журналу.
library;

import 'currency.dart';
import 'expense_data.dart';
import 'identifiable.dart';
import 'payment_method.dart';

/// Ширина місяця й дня в даті формату `РРРР-ММ-ДД`.
const _dateComponentWidth = 2;

/// Шаблон дати `РРРР-ММ-ДД` з іменованими групами.
final _datePattern = RegExp(r'^(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})$');

/// Поля рядка CSV, ще не перетворені на потрібні типи.
typedef _CsvFields = ({
  String id,
  String date,
  String category,
  String amount,
  String currency,
  String paymentMethod,
  String note,
});

/// Одна витрата з журналу особистих витрат.
///
/// Клас незмінний: усі поля `final`, а «змінити» витрату можна лише
/// створивши новий об'єкт. Дві витрати з однаковими значеннями всіх полів
/// вважаються рівними ([operator ==] і [hashCode] перевизначено).
class Expense implements Identifiable {
  /// Створює витрату з уже перевірених значень.
  const Expense({
    required this.id,
    required this.date,
    required this.category,
    required this.amount,
    required this.currency,
    required this.paymentMethod,
    this.note = '',
  });

  /// Розбирає витрату з рядка формату
  /// `id;дата;категорія;сума;валюта;спосіб оплати;примітка`.
  ///
  /// Іменований конструктор замінює функцію розбору з лабораторної
  /// роботи 1. Конструктор не може повернути `null`, тому для
  /// пошкодженого рядка він кидає [FormatException].
  Expense.fromCsv(String line) : this._fromFields(_splitFields(line));

  /// Перетворює текстові поля [fields] на значення потрібних типів.
  Expense._fromFields(_CsvFields fields)
    : id = fields.id,
      date = _parseDate(fields.date),
      category = fields.category,
      amount = _parseAmount(fields.amount),
      currency = _parseCurrency(fields.currency),
      paymentMethod = PaymentMethod.parse(fields.paymentMethod),
      note = fields.note;

  /// Повертає витрату, розібрану з рядка [line], використовуючи кеш.
  ///
  /// Фабричний конструктор: для рядка, який уже розбирали, повертає
  /// наявний екземпляр замість створення нового. Генеративний конструктор
  /// так не вміє — він завжди створює новий об'єкт.
  factory Expense.cached(String line) =>
      _cache.putIfAbsent(line, () => Expense.fromCsv(line));

  /// Кеш розібраних рядків для [Expense.cached].
  static final _cache = <String, Expense>{};

  @override
  final String id;

  /// Дата витрати.
  final DateTime date;

  /// Категорія витрати, наприклад «Продукти».
  final String category;

  /// Сума у валюті [currency].
  final double amount;

  /// Валюта суми.
  final Currency currency;

  /// Спосіб оплати.
  final PaymentMethod paymentMethod;

  /// Довільна примітка.
  final String note;

  /// Сума в гривнях за умовним курсом валюти.
  double get amountInUah => currency.toUah(amount);

  /// Комісія за оплату у валюті витрати.
  double get fee => paymentMethod.feeFor(amount);

  @override
  bool operator ==(Object other) =>
      other is Expense &&
      other.id == id &&
      other.date == date &&
      other.category == category &&
      other.amount == amount &&
      other.currency == currency &&
      other.paymentMethod == paymentMethod &&
      other.note == note;

  @override
  int get hashCode =>
      Object.hash(id, date, category, amount, currency, paymentMethod, note);

  @override
  String toString() =>
      'Expense($id, ${date.toIso8601String().split('T').first}, '
      '$category, $amount ${currency.code}, ${paymentMethod.describe()})';

  /// Ділить рядок [line] на сім полів.
  static _CsvFields _splitFields(String line) {
    final fields = line.split(fieldSeparator).map((f) => f.trim()).toList();
    return switch (fields) {
      [
        final id,
        final date,
        final category,
        final amount,
        final currency,
        final paymentMethod,
        final note,
      ] =>
        (
          id: id,
          date: date,
          category: category,
          amount: amount,
          currency: currency,
          paymentMethod: paymentMethod,
          note: note,
        ),
      _ => throw FormatException(
        'очікувалося $expectedFieldCount полів, а отримано ${fields.length}',
        line,
      ),
    };
  }

  /// Перетворює [text] на дату, якщо він має формат `РРРР-ММ-ДД` і
  /// позначає день, який справді існує.
  static DateTime _parseDate(String text) {
    final match = _datePattern.firstMatch(text);
    final date = match == null ? null : DateTime.tryParse(text);
    // DateTime.tryParse не відкидає неіснуючі дати, а переносить їх:
    // «2026-02-30» стає 2 березня. Тому звіряємо місяць і день з текстом.
    if (match == null ||
        date == null ||
        match.namedGroup('month') != _twoDigits(date.month) ||
        match.namedGroup('day') != _twoDigits(date.day)) {
      throw FormatException('некоректна дата «$text»', text);
    }
    return date;
  }

  /// Перетворює [text] на суму.
  static double _parseAmount(String text) =>
      double.tryParse(text) ??
      (throw FormatException('сума «$text» не є числом', text));

  /// Знаходить валюту з кодом [code].
  static Currency _parseCurrency(String code) =>
      Currency.tryParse(code) ??
      (throw FormatException('невідома валюта «$code»', code));

  /// Записує [value] двома цифрами з провідним нулем: 3 → «03».
  static String _twoDigits(int value) =>
      value.toString().padLeft(_dateComponentWidth, '0');
}
