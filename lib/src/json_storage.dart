/// Збереження журналу витрат у файлі формату JSON.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'expense.dart';

/// Відступ у збереженому файлі: два пробіли, щоб файл було зручно читати.
const _indent = '  ';

/// Файл формату JSON, у якому зберігається журнал витрат.
///
/// Файл містить масив об'єктів — по одному на витрату (див.
/// [Expense.toJson]). Файл невеликий, тому читається й записується
/// цілком; для великих текстових файлів див. `readExpenseFile`.
class JsonFileStorage {
  /// Створює сховище, прив'язане до файлу [path].
  ///
  /// Сам файл не створюється: це відбувається під час першого [save].
  JsonFileStorage(this.path);

  /// Шлях до файлу журналу.
  final String path;

  /// Завантажує витрати з файлу.
  ///
  /// Якщо файлу ще немає, повертає порожній список: журнал просто ще не
  /// вели. Якщо вміст не є коректним JSON або має неочікувану структуру,
  /// кидає [FormatException]; помилки читання файлу (немає доступу
  /// тощо) — [FileSystemException].
  Future<List<Expense>> load() async {
    final file = File(path);
    if (!await file.exists()) {
      return [];
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List<Object?>) {
      throw FormatException('очікувався масив JSON', path);
    }
    return [
      for (final item in decoded)
        if (item is Map<String, Object?>)
          Expense.fromJson(item)
        else
          throw FormatException('елемент масиву не є об\'єктом JSON', item),
    ];
  }

  /// Зберігає [expenses] у файл, замінюючи попередній вміст.
  ///
  /// Каталог файлу створюється, якщо його ще немає.
  Future<void> save(Iterable<Expense> expenses) async {
    await Directory(p.dirname(path)).create(recursive: true);
    final json = const JsonEncoder.withIndent(_indent)
        .convert([for (final expense in expenses) expense.toJson()]);
    await File(path).writeAsString(json);
  }
}
