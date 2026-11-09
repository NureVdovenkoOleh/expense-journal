/// Робота з датами витрат: форматування, вік запису, давні записи.
library;

import 'expense.dart';

/// Вік, після якого витрата вважається давньою.
const staleAge = Duration(days: 30);

/// Кількість цифр, якими записують день і місяць.
const _datePartWidth = 2;

/// Записує [date] у форматі `ДД.ММ.РРРР`.
String formatDate(DateTime date) {
  final day = date.day.toString().padLeft(_datePartWidth, '0');
  final month = date.month.toString().padLeft(_datePartWidth, '0');
  return '$day.$month.${date.year}';
}

/// Обчислює, скільки повних днів минуло від дати витрати [expense]
/// до [today].
///
/// Якщо [today] не передано, береться поточна дата.
int ageInDays(Expense expense, {DateTime? today}) {
  final reference = _dateOnly(today ?? DateTime.now());
  final Duration age = reference.difference(_dateOnly(expense.date));
  return age.inDays;
}

/// Створює предикат, який перевіряє, чи витрата старша за [age].
///
/// Повернена функція є замиканням: вона захоплює [age] і момент
/// `reference` і користується ними під час кожного виклику, хоча сама
/// [olderThan] на той час уже завершилася.
bool Function(Expense) olderThan(Duration age, {DateTime? today}) {
  final reference = today ?? DateTime.now();
  return (expense) => expense.date.add(age).isBefore(reference);
}

/// Відкидає час доби й переводить [date] в UTC.
///
/// Без цього перехід на літній чи зимовий час додає або забирає годину,
/// і [Duration.inDays] може помилитися на один день.
DateTime _dateOnly(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);
