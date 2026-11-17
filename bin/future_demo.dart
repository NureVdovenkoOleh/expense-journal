// Демонстрації до лабораторної роботи 3: групи асинхронних операцій
// і помилки в них.
//
// Запуск: dart run expense_journal:future_demo

import 'dart:async';

import 'package:expense_journal/expense_journal.dart';

/// Тривалість однієї операції сховища в цих демонстраціях.
const operationTime = Duration(milliseconds: 500);

/// Ідентифікатори трьох наявних витрат.
const existingIds = ['E01', 'E05', 'E09'];

/// Ідентифікатор, якого у сховищі немає.
const missingId = 'E99';

/// Три запити, другий з яких завершиться помилкою.
const idsWithMissing = ['E01', missingId, 'E09'];

/// Точка входу демонстрацій.
Future<void> main() async {
  final repository = AsyncRepository<Expense>(
    seed: validExpenses(rawExpenses.map(parseExpense)),
    latency: operationTime,
  );
  await demoSequentialAndConcurrent(repository);
  await demoGroupErrors(repository);
  await demoUncaughtError(repository);
}

/// Порівнює послідовне й одночасне виконання трьох операцій.
Future<void> demoSequentialAndConcurrent(
  AsyncRepository<Expense> repository,
) async {
  print('--- Три операції по ${operationTime.inMilliseconds} мс ---');
  final watch = Stopwatch()..start();

  // Кожен await чекає завершення попередньої операції.
  for (final id in existingIds) {
    await repository.require(id);
  }
  print('Послідовно (три await): ${watch.elapsedMilliseconds} мс');

  watch.reset();
  // Усі три операції запущено одразу; чекаємо, доки завершаться всі.
  final loaded = await Future.wait(existingIds.map(repository.require));
  print(
    'Одночасно (Future.wait): ${watch.elapsedMilliseconds} мс, '
    'отримано ${loaded.length} витрати',
  );
}

/// Показує, що відомо про помилку в групі операцій у двох випадках.
Future<void> demoGroupErrors(AsyncRepository<Expense> repository) async {
  print('\n--- Помилка в одній із трьох операцій ---');

  print('Future.wait:');
  try {
    await Future.wait(idsWithMissing.map(repository.require));
  } on EntityNotFoundException catch (exception) {
    // Доступна лише сама помилка: результати двох успішних операцій
    // втрачено, і невідомо, яка за номером операція не вдалася.
    print('  спіймано лише помилку: $exception');
  }

  print('Розширення .wait:');
  try {
    await idsWithMissing.map(repository.require).wait;
  } on ParallelWaitError<List<Expense?>, List<AsyncError?>> catch (error) {
    // Доступний стан кожної операції: values містить результати
    // успішних (null на місці невдалої), errors — помилки невдалих.
    for (final (index, id) in idsWithMissing.indexed) {
      final failure = error.errors[index];
      print(
        failure == null
            ? '  $id: успіх → ${error.values[index]}'
            : '  $id: помилка → ${failure.error}',
      );
    }
  }
}

/// Показує, що `try/catch` навколо виклику без `await` не ловить помилку.
Future<void> demoUncaughtError(AsyncRepository<Expense> repository) async {
  print('\n--- try/catch без await ---');
  final reported = Completer<void>();

  // runZonedGuarded перехоплює помилки, яких ніхто не спіймав. Без нього
  // така помилка аварійно завершила б програму з текстом
  // «Unhandled exception».
  runZonedGuarded(
    () {
      try {
        // Навмисна помилка для демонстрації: delete не дочекано.
        // ignore: discarded_futures
        repository.delete(missingId);
        print('  блок try завершився, catch не спрацював');
      } on EntityNotFoundException {
        print('  цей рядок не виконається ніколи');
      }
    },
    (error, stackTrace) {
      print(
        '  через ${operationTime.inMilliseconds} мс '
        'неспіймана помилка: $error',
      );
      reported.complete();
    },
  );
  await reported.future;

  print('Те саме з await:');
  try {
    await repository.delete(missingId);
  } on EntityNotFoundException catch (exception) {
    print('  catch спрацював: $exception');
  }
}
