import 'dart:convert';
import 'dart:io';

import 'package:expense_journal/expense_journal.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Expense.toJson / fromJson', () {
    // Перші 15 вхідних рядків — коректні витрати з усіма трьома видами
    // оплати й трьома валютами.
    final expenses = rawExpenses.take(15).map(Expense.fromCsv).toList();

    test('після toJson і fromJson витрата рівна початковій', () {
      for (final expense in expenses) {
        expect(Expense.fromJson(expense.toJson()), expense);
      }
    });

    test('переживає перетворення на текст JSON і назад', () {
      final text = jsonEncode([for (final e in expenses) e.toJson()]);
      final decoded = (jsonDecode(text) as List<Object?>)
          .cast<Map<String, Object?>>()
          .map(Expense.fromJson)
          .toList();
      expect(decoded, expenses);
    });

    test('приймає цілу суму з JSON', () {
      final json = expenses.first.toJson()..['amount'] = 100;
      expect(Expense.fromJson(json).amount, 100.0);
    });

    test('кидає FormatException, якщо поле має інший тип', () {
      final json = expenses.first.toJson()..['amount'] = 'сто';
      expect(() => Expense.fromJson(json), throwsFormatException);
    });

    test('кидає FormatException, якщо поля немає', () {
      final json = expenses.first.toJson()..remove('id');
      expect(() => Expense.fromJson(json), throwsFormatException);
    });
  });

  group('JsonFileStorage', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('expense_journal_');
    });

    tearDown(() async {
      await directory.delete(recursive: true);
    });

    test('повертає порожній список, якщо файлу немає', () async {
      final storage = JsonFileStorage(p.join(directory.path, 'none.json'));
      expect(await storage.load(), isEmpty);
    });

    test('зберігає й завантажує витрати, створюючи каталог', () async {
      final expenses = rawExpenses.take(3).map(Expense.fromCsv).toList();
      final storage = JsonFileStorage(
        p.join(directory.path, 'nested', 'expenses.json'),
      );
      await storage.save(expenses);
      expect(await storage.load(), expenses);
    });

    test('кидає FormatException для файлу з некоректним JSON', () async {
      final path = p.join(directory.path, 'broken.json');
      await File(path).writeAsString('{не json');
      await expectLater(JsonFileStorage(path).load(), throwsFormatException);
    });
  });

  group('великий файл', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('expense_journal_');
    });

    tearDown(() async {
      await directory.delete(recursive: true);
    });

    test('readExpenseFile читає файл рядок за рядком', () async {
      final path = p.join(directory.path, 'large.txt');
      await writeSampleFile(path, count: 2500);
      final results = await readExpenseFile(path).toList();
      expect(results, hasLength(2500));
      // Пошкоджено рядки 1000 і 2000.
      expect(results.where((r) => r.error != null), hasLength(2));
    });
  });
}
