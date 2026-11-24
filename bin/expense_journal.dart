import 'dart:io';

import 'package:expense_journal/expense_journal.dart';

/// Точка входу: передає аргументи командного рядка застосунку.
///
/// Уся логіка живе в бібліотеці (`runCli`), тут лише встановлюється
/// код завершення процесу.
Future<void> main(List<String> arguments) async {
  exitCode = await runCli(arguments);
}
