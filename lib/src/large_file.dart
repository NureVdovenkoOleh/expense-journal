/// Робота з великими текстовими файлами витрат.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'expense_data.dart';
import 'expense_parser.dart';

/// Категорії, з яких складаються згенеровані витрати.
const _categories = ['Продукти', 'Транспорт', 'Кафе', 'Розваги', 'Зв’язок'];

/// Способи оплати згенерованих витрат.
const _paymentMethods = [
  'готівка',
  'картка:5375414100009876',
  'картка:4149609012345678',
  'переказ:UA213223130000026007233566001',
];

/// Найбільша сума згенерованої витрати.
const _maxAmount = 2000.0;

/// Кількість днів, на які розкидано дати згенерованих витрат.
const _dayRange = 300;

/// Кожен рядок з таким номером навмисно пошкоджується.
const _damagedEvery = 1000;

/// Перший день, від якого відраховуються дати згенерованих витрат.
final _firstDay = DateTime(2026);

/// Читає файл [path] рядок за рядком і розбирає кожен рядок у витрату.
///
/// Файл не завантажується в пам'ять цілком: `openRead` віддає його
/// частинами байтів, `utf8.decoder` перетворює байти на текст, а
/// `LineSplitter` ділить текст на рядки. У пам'яті водночас лише кілька
/// рядків, тож так можна обробити файл будь-якого розміру. Порожні рядки
/// пропускаються.
Stream<ParseResult> readExpenseFile(String path) =>
    File(path)
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((line) => line.trim().isNotEmpty)
        .map(parseExpense);

/// Створює текстовий файл [path] з [count] згенерованими витратами.
///
/// Кожен рядок з номером, кратним 1000, навмисно пошкоджено, щоб розбір
/// мав що відкидати. Рядки записуються в [IOSink] по одному, тож файл
/// теж не тримається в пам'яті цілком. Повертає кількість записаних
/// рядків.
Future<int> writeSampleFile(
  String path, {
  required int count,
  int seed = 1,
}) async {
  final random = math.Random(seed);
  final sink = File(path).openWrite();
  try {
    for (var i = 1; i <= count; i++) {
      final id = 'G${i.toString().padLeft(7, '0')}';
      final date = _firstDay.add(Duration(days: random.nextInt(_dayRange)));
      final fields = [
        id,
        if (i % _damagedEvery == 0) 'пошкоджена-дата' else _isoDate(date),
        _categories[random.nextInt(_categories.length)],
        (random.nextDouble() * _maxAmount).toStringAsFixed(2),
        'UAH',
        _paymentMethods[random.nextInt(_paymentMethods.length)],
        'Згенеровано',
      ];
      sink.writeln(fields.join(fieldSeparator));
    }
  } finally {
    await sink.close();
  }
  return count;
}

/// Записує дату [value] у форматі `РРРР-ММ-ДД`.
String _isoDate(DateTime value) => value.toIso8601String().split('T').first;
