/// Розбір рядків журналу витрат без аварійного завершення програми.
library;

import 'expense.dart';

/// Результат розбору одного рядка: витрата або опис помилки.
///
/// Якщо розбір вдався, `expense` містить витрату, а `error` дорівнює
/// `null`; якщо ні — навпаки.
typedef ParseResult = ({Expense? expense, String? error});

/// Розбирає рядок [line] у витрату.
///
/// Сам розбір виконує конструктор [Expense.fromCsv]. Конструктор не може
/// повернути `null`, тому про пошкоджений рядок він повідомляє винятком
/// [FormatException]. Ця функція — єдине місце, де виняток
/// перехоплюється й перетворюється на звичайне значення, так само як
/// `int.tryParse` обгортає `int.parse`.
ParseResult parseExpense(String line) {
  try {
    return (expense: Expense.fromCsv(line), error: null);
  } on FormatException catch (exception) {
    return (expense: null, error: exception.message);
  }
}
