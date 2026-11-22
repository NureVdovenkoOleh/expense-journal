/// Робота з датами витрат: форматування, вік запису, давні записи.
library;

import 'expense.dart';

/// Вік, після якого витрата вважається давньою.
const staleAge = Duration(days: 30);

/// Кількість цифр, якими записують день і місяць.
const _datePartWidth = 2;

/// Методи розширення для дат журналу витрат.
///
/// Розширення додає методи до вбудованого типу [DateTime], не змінюючи
/// й не успадковуючи його: виклик `date.toDisplayDate()` читається
/// природніше, ніж `formatDate(date)`.
extension ExpenseDate on DateTime {
  /// Записує дату у форматі `ДД.ММ.РРРР`.
  String toDisplayDate() {
    final dayText = day.toString().padLeft(_datePartWidth, '0');
    final monthText = month.toString().padLeft(_datePartWidth, '0');
    return '$dayText.$monthText.$year';
  }

  /// Та сама дата без часу доби, в UTC.
  ///
  /// Без цього перехід на літній чи зимовий час додає або забирає
  /// годину, і [Duration.inDays] може помилитися на один день.
  DateTime get dateOnly => DateTime.utc(year, month, day);

  /// Кількість повних днів від цієї дати до [other].
  int daysUntil(DateTime other) => other.dateOnly.difference(dateOnly).inDays;
}

/// Обчислює, скільки повних днів минуло від дати витрати [expense]
/// до [today].
///
/// Якщо [today] не передано, береться поточна дата.
int ageInDays(Expense expense, {DateTime? today}) =>
    expense.date.daysUntil(today ?? DateTime.now());

/// Створює предикат, який перевіряє, чи витрата старша за [age].
///
/// Повернена функція є замиканням: вона захоплює [age] і момент
/// `reference` і користується ними під час кожного виклику, хоча сама
/// [olderThan] на той час уже завершилася.
bool Function(Expense) olderThan(Duration age, {DateTime? today}) {
  final reference = today ?? DateTime.now();
  return (expense) => expense.date.add(age).isBefore(reference);
}
