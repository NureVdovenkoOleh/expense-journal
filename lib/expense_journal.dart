/// Журнал особистих витрат: розбір, перевірка, аналітика, збереження
/// та обмін даними.
///
/// Це фасад пакета — єдиний файл, який імпортують `bin/`, тести й
/// інші пакети. Реалізацію розміщено в `lib/src/`: за домовленістю
/// Dart файли звідти не імпортують напряму, тож структуру `src/` можна
/// змінювати, не ламаючи коду, що використовує пакет. Назовні видно
/// лише те, що перелічено нижче в директивах `export`.
///
/// Історія проєкту:
/// - лабораторна робота 1 — функції, колекції, рядки, дати;
/// - лабораторна робота 2 — класи, ієрархії, домішки, узагальнення;
/// - лабораторна робота 3 — асинхронність, потоки, ізоляти;
/// - лабораторна робота 4 — структура пакета, файли, HTTP, служба.
library;

// Директиви впорядковано за абеткою (правило directives_ordering).
export 'src/async_repository.dart';
export 'src/cli.dart';
export 'src/currency.dart';
export 'src/expense.dart';
export 'src/expense_analytics.dart';
export 'src/expense_data.dart';
export 'src/expense_dates.dart';
export 'src/expense_parser.dart';
export 'src/expense_report.dart';
export 'src/expense_simulation.dart';
export 'src/expense_validator.dart';
export 'src/identifiable.dart';
export 'src/json_storage.dart';
export 'src/large_file.dart';
export 'src/payment_method.dart';
export 'src/repository.dart';
