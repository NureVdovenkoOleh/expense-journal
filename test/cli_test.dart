import 'dart:io';

import 'package:expense_journal/expense_journal.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late String dataPath;
  late StringBuffer out;
  late StringBuffer err;

  /// Запускає застосунок з файлом журналу в тимчасовому каталозі.
  Future<int> run(List<String> arguments) =>
      runCli(['--data', dataPath, ...arguments], out: out, err: err);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('expense_journal_');
    dataPath = p.join(directory.path, 'expenses.json');
    out = StringBuffer();
    err = StringBuffer();
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('невідома команда завершується кодом 64 і пише в stderr', () async {
    expect(await run(['unknown']), exitUsage);
    expect(err.toString(), contains('unknown'));
    expect(out.toString(), isEmpty);
  });

  test('недопустиме значення опції завершується кодом 64', () async {
    expect(await run(['list', '--currency', 'XYZ']), exitUsage);
  });

  test('import без файлу додає 15 вбудованих витрат', () async {
    expect(await run(['import']), exitSuccess);
    expect(out.toString(), contains('Усього в журналі: 15'));
    expect(err.toString(), contains('Пропущено рядок 16'));
    expect(await JsonFileStorage(dataPath).load(), hasLength(15));
  });

  test('повторний import не дублює витрати', () async {
    await run(['import']);
    await run(['import']);
    expect(await JsonFileStorage(dataPath).load(), hasLength(15));
  });

  test('list фільтрує за категорією й валютою', () async {
    await run(['import']);
    out.clear();
    expect(
      await run(['list', '--category', 'Розваги', '--currency', 'USD']),
      exitSuccess,
    );
    expect(out.toString(), contains('Знайдено витрат: 1'));
  });

  test('report для порожнього журналу завершується кодом 65', () async {
    expect(await run(['report']), exitDataError);
    expect(err.toString(), contains('Журнал порожній'));
  });

  test('generate і stats обробляють великий файл', () async {
    final large = p.join(directory.path, 'large.txt');
    expect(await run(['generate', '-n', '3000', '-o', large]), exitSuccess);
    out.clear();
    expect(await run(['stats', large]), exitSuccess);
    expect(out.toString(), contains('Коректних рядків: 2997, пошкоджених: 3'));
  });

  test('generate з некоректною кількістю завершується кодом 64', () async {
    expect(await run(['generate', '--count', 'багато']), exitUsage);
  });

  test('stats для відсутнього файлу завершується кодом 74', () async {
    final missing = p.join(directory.path, 'missing.txt');
    expect(await run(['stats', missing]), exitIoError);
    expect(err.toString(), contains('Помилка файлу'));
  });
}
