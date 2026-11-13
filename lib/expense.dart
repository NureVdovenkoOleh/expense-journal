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
///
/// Поля й константний конструктор оголошено первинним конструктором
/// (Dart 3.13) прямо в заголовку класу: параметр з `final` одночасно є
/// параметром конструктора й полем класу.
class const Expense({
  /// Унікальний ідентифікатор витрати, наприклад `E05`.
  @override required final String id,

  /// Дата витрати.
  required final DateTime date,

  /// Категорія витрати, наприклад «Продукти».
  required final String category,

  /// Сума у валюті [currency].
  required final double amount,

  /// Валюта суми.
  required final Currency currency,

  /// Спосіб оплати.
  required final PaymentMethod paymentMethod,

  /// Довільна примітка.
  final String note = '',
}) implements Identifiable {
  /// Створює витрату з уже перевірених значень.
  ///
  /// Документаційний коментар класу не документує первинний конструктор,
  /// тому для коментаря конструктора додано порожнє тіло `this;`.
  this;

  /// Розбирає витрату з рядка формату
  /// `id;дата;категорія;сума;валюта;спосіб оплати;примітка`.
  ///
  /// Замінює функцію розбору з лабораторної роботи 1. Клас із первинним
  /// конструктором не може мати інших генеративних конструкторів, які
  /// не перенаправляють виклик, тому це фабричний конструктор. Для
  /// пошкодженого рядка він кидає [FormatException].
  factory Expense.fromCsv(String line) {
    // Деструктуризація запису: кожне поле запису стає локальною змінною.
    final (:id, :date, :category, :amount, :currency, :paymentMethod, :note) =
        _splitFields(line);
    return Expense(
      id: id,
      date: _parseDate(date),
      category: category,
      amount: _parseAmount(amount),
      currency: _parseCurrency(currency),
      paymentMethod: PaymentMethod.parse(paymentMethod),
      note: note,
    );
  }

  /// Повертає витрату, розібрану з рядка [line], використовуючи кеш.
  ///
  /// Фабричний конструктор: для рядка, який уже розбирали, повертає
  /// наявний екземпляр замість створення нового. Генеративний конструктор
  /// так не вміє — він завжди створює новий об'єкт.
  factory Expense.cached(String line) =>
      _cache.putIfAbsent(line, () => Expense.fromCsv(line));

  /// Кеш розібраних рядків для [Expense.cached].
  static final _cache = <String, Expense>{};

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
