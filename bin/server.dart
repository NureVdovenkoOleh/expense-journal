import 'dart:io';

import 'package:expense_journal/expense_journal.dart';
import 'package:shelf/shelf_io.dart' as io;

/// Запускає HTTP-службу журналу витрат.
///
/// Дані завантажуються з файлу журналу (його наповнює команда
/// `dart run expense_journal import`), а кожна зміна одразу
/// зберігається назад у файл. Порт можна задати змінною середовища
/// `PORT`. Зупинка — Ctrl+C.
Future<void> main() async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? defaultPort;
  final storage = JsonFileStorage(defaultDataPath);
  final repository = AsyncRepository<Expense>(
    seed: await storage.load(),
    latency: Duration.zero,
  );

  // Події змін зі сховища (лабораторна робота 3) зберігають журнал у
  // файл: обробникам HTTP не треба знати про файлову систему.
  final subscription = repository.changes.listen((event) async {
    await storage.save(await repository.loadAll());
  });

  final server = await io.serve(
    buildHandler(repository, log: print),
    InternetAddress.loopbackIPv4,
    port,
  );
  print(
    'Служба слухає http://${server.address.host}:${server.port} '
    '(записів: ${repository.length}). Зупинка — Ctrl+C.',
  );

  await ProcessSignal.sigint.watch().first;
  await server.close();
  await subscription.cancel();
  repository.close();
  print('Службу зупинено.');
}
