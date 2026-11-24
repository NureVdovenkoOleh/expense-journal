/// Командний рядок застосунку: команди, опції, коди завершення.
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'currency.dart';
import 'expense.dart';
import 'expense_analytics.dart';
import 'expense_data.dart';
import 'expense_parser.dart';
import 'expense_report.dart';
import 'expense_validator.dart';
import 'json_storage.dart';
import 'large_file.dart';
import 'repository.dart';

/// Назва виконуваного файлу в довідці.
const executableName = 'expense_journal';

/// Шлях до файлу журналу за замовчуванням.
///
/// Побудовано через `p.join`, а не рядком `'data/expenses.json'`: так
/// роздільник буде правильним і у Windows (`\`), і в Linux (`/`).
final defaultDataPath = p.join('data', 'expenses.json');

/// Шлях до згенерованого великого файлу за замовчуванням.
final defaultLargeFilePath = p.join('data', 'large_expenses.txt');

/// Кількість рядків, які генерує команда `generate` за замовчуванням.
const defaultGenerateCount = 100000;

/// Скільки помилок розбору команда `import` показує поіменно.
const shownErrorCount = 5;

/// Код завершення: успіх.
const exitSuccess = 0;

/// Код завершення: неправильні аргументи командного рядка.
///
/// Значення взято з BSD `sysexits.h` (EX_USAGE), як і два наступні.
const exitUsage = 64;

/// Код завершення: некоректні вхідні дані (EX_DATAERR).
const exitDataError = 65;

/// Код завершення: помилка читання чи запису файлу (EX_IOERR).
const exitIoError = 74;

/// Запускає застосунок з аргументами [arguments] і повертає код
/// завершення.
///
/// Звичайний вивід іде в [out], повідомлення про помилки — в [err]. За
/// замовчуванням це `stdout` і `stderr`; тести передають власні буфери,
/// щоб перевірити вивід, не запускаючи окремий процес.
Future<int> runCli(
  List<String> arguments, {
  StringSink? out,
  StringSink? err,
}) async {
  final output = out ?? stdout;
  final errors = err ?? stderr;
  final runner = buildCommandRunner(output, errors);
  try {
    return await runner.run(arguments) ?? exitSuccess;
  } on UsageException catch (exception) {
    errors
      ..writeln(exception.message)
      ..writeln()
      ..writeln(exception.usage);
    return exitUsage;
  } on FormatException catch (exception) {
    errors.writeln('Некоректні дані: ${exception.message}');
    return exitDataError;
  } on FileSystemException catch (exception) {
    errors.writeln(
      'Помилка файлу: ${exception.message} (${exception.path ?? '—'})',
    );
    return exitIoError;
  }
}

/// Створює набір команд застосунку з глобальною опцією `--data`.
CommandRunner<int> buildCommandRunner(StringSink out, StringSink err) =>
    CommandRunner<int>(executableName, 'Журнал особистих витрат.')
      ..argParser.addOption(
        'data',
        abbr: 'd',
        help: 'Файл журналу у форматі JSON.',
        valueHelp: 'шлях',
        defaultsTo: defaultDataPath,
      )
      ..addCommand(ImportCommand(out, err))
      ..addCommand(ListCommand(out, err))
      ..addCommand(ReportCommand(out, err))
      ..addCommand(GenerateCommand(out, err))
      ..addCommand(StatsCommand(out, err));

/// Спільна основа команд: потоки виводу й доступ до аргументів.
abstract class JournalCommand extends Command<int> {
  /// Створює команду, яка пише в [out] і [err].
  JournalCommand(this.out, this.err);

  /// Потік звичайного виводу.
  final StringSink out;

  /// Потік повідомлень про помилки.
  final StringSink err;

  /// Аргументи поточного запуску команди.
  ///
  /// `CommandRunner` заповнює `argResults` перед викликом `run`, тож
  /// усередині `run` значення завжди є.
  ArgResults get args =>
      argResults ?? (throw StateError('команду запущено поза CommandRunner'));

  /// Сховище, на яке вказує глобальна опція `--data`.
  JsonFileStorage get storage =>
      JsonFileStorage(globalResults?.option('data') ?? defaultDataPath);
}

/// Команда `import`: додає витрати до журналу.
class ImportCommand extends JournalCommand {
  /// Створює команду, яка пише в [out] і [err].
  ImportCommand(super.out, super.err);

  @override
  String get name => 'import';

  @override
  String get description =>
      'Додає до журналу витрати з текстового файлу (по одній на рядок) '
      'або, якщо файл не вказано, вбудовані приклади.';

  @override
  String get invocation => '$executableName import [файл]';

  @override
  Future<int> run() async {
    final source = switch (args.rest) {
      [] => null,
      [final path] => path,
      _ => throw UsageException('Вкажіть не більше одного файлу.', usage),
    };
    final results = source == null
        ? rawExpenses.map(parseExpense).toList()
        : await readExpenseFile(source).toList();

    final valid = validExpenses(results);
    final errors = [
      for (final (index, (:expense, :error)) in results.indexed)
        if (error != null)
          'рядок ${index + 1}: $error'
        else if (expense != null && validateExpense(expense).isNotEmpty)
          'рядок ${index + 1}: ${validateExpense(expense).join('; ')}',
    ];

    final journal = Repository<Expense>()
      ..addAll(await storage.load())
      ..addAll(valid);
    await storage.save(journal.all);

    out
      ..writeln('Прочитано рядків: ${results.length}')
      ..writeln('Додано або оновлено витрат: ${valid.length}')
      ..writeln('Усього в журналі: ${journal.length}');
    for (final message in errors.take(shownErrorCount)) {
      err.writeln('Пропущено $message');
    }
    if (errors.length > shownErrorCount) {
      err.writeln('… і ще ${errors.length - shownErrorCount} помилок');
    }
    return exitSuccess;
  }
}

/// Команда `list`: друкує витрати з журналу.
class ListCommand extends JournalCommand {
  /// Створює команду, яка пише в [out] і [err].
  ListCommand(super.out, super.err) {
    argParser
      ..addOption(
        'category',
        abbr: 'c',
        help: 'Показати лише витрати цієї категорії.',
      )
      ..addOption(
        'currency',
        help: 'Показати лише витрати в цій валюті.',
        allowed: [for (final currency in Currency.values) currency.code],
      );
  }

  @override
  String get name => 'list';

  @override
  String get description => 'Друкує витрати з журналу.';

  @override
  Future<int> run() async {
    final category = args.option('category');
    final currency = args.option('currency');
    final expenses = (await storage.load()).where(
      (expense) =>
          (category == null || expense.category == category) &&
          (currency == null || expense.currency.code == currency),
    );
    for (final expense in expenses) {
      out.writeln(expense);
    }
    out.writeln('Знайдено витрат: ${expenses.length}');
    return exitSuccess;
  }
}

/// Команда `report`: друкує звіт за журналом.
class ReportCommand extends JournalCommand {
  /// Створює команду, яка пише в [out] і [err].
  ReportCommand(super.out, super.err);

  @override
  String get name => 'report';

  @override
  String get description => 'Друкує текстовий звіт за журналом.';

  @override
  Future<int> run() async {
    final expenses = await storage.load();
    if (expenses.isEmpty) {
      err.writeln('Журнал порожній. Спершу виконайте: $executableName import');
      return exitDataError;
    }
    out.write(buildReport(expenses));
    return exitSuccess;
  }
}

/// Команда `generate`: створює великий текстовий файл для перевірки.
class GenerateCommand extends JournalCommand {
  /// Створює команду, яка пише в [out] і [err].
  GenerateCommand(super.out, super.err) {
    argParser
      ..addOption(
        'count',
        abbr: 'n',
        help: 'Кількість рядків.',
        defaultsTo: '$defaultGenerateCount',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Файл, який буде створено.',
        valueHelp: 'шлях',
        defaultsTo: defaultLargeFilePath,
      );
  }

  @override
  String get name => 'generate';

  @override
  String get description =>
      'Створює текстовий файл із випадковими витратами для перевірки '
      'команди stats.';

  @override
  Future<int> run() async {
    final countText = args.option('count') ?? '$defaultGenerateCount';
    final count = int.tryParse(countText);
    if (count == null || count <= 0) {
      throw UsageException(
        'Кількість рядків має бути додатним числом, а не «$countText».',
        usage,
      );
    }
    final output = args.option('output') ?? defaultLargeFilePath;
    await Directory(p.dirname(output)).create(recursive: true);
    await writeSampleFile(output, count: count);
    out.writeln('Записано $count рядків у $output');
    return exitSuccess;
  }
}

/// Команда `stats`: рахує підсумки великого файлу, не зберігаючи його.
class StatsCommand extends JournalCommand {
  /// Створює команду, яка пише в [out] і [err].
  StatsCommand(super.out, super.err);

  @override
  String get name => 'stats';

  @override
  String get description =>
      'Рахує суми за категоріями для текстового файлу будь-якого розміру, '
      'читаючи його рядок за рядком.';

  @override
  String get invocation => '$executableName stats <файл>';

  @override
  Future<int> run() async {
    final path = switch (args.rest) {
      [final path] => path,
      _ => throw UsageException('Вкажіть рівно один файл.', usage),
    };
    final watch = Stopwatch()..start();
    var valid = 0;
    var damaged = 0;
    final totals = <String, double>{};
    await for (final (:expense, error: _) in readExpenseFile(path)) {
      if (expense == null) {
        damaged++;
        continue;
      }
      valid++;
      totals.update(
        expense.category,
        (total) => total + expense.amountInUah,
        ifAbsent: () => expense.amountInUah,
      );
    }
    out
      ..writeln('Файл: $path')
      ..writeln('Коректних рядків: $valid, пошкоджених: $damaged')
      ..writeln('Час обробки: ${watch.elapsedMilliseconds} мс');
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final MapEntry(key: category, value: total) in sorted) {
      out.writeln('  $category: ${total.toStringAsFixed(2)} UAH');
    }
    return exitSuccess;
  }
}
