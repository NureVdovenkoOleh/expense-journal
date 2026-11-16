// Демонстрації до лабораторної роботи 3: асинхронне сховище.
//
// Запуск: dart run expense_journal:async_demo

import 'package:expense_journal/expense_journal.dart';

/// Ідентифікатор наявної витрати для прикладу завантаження.
const existingId = 'E05';

/// Ідентифікатор, якого у сховищі немає.
const missingId = 'E99';

/// Витрата, яку приклади додають і видаляють.
final extraExpense = Expense(
  id: 'E90',
  date: DateTime(2026, 11, 16),
  category: 'Кафе',
  amount: 85,
  currency: Currency.uah,
  paymentMethod: const Cash(),
  note: 'Чай',
);

/// Точка входу демонстрацій.
Future<void> main() async {
  final repository = AsyncRepository<Expense>(
    seed: validExpenses(rawExpenses.map(parseExpense)),
  );
  await demoRepository(repository);
  await demoForgottenAwait(repository);
}

/// Показує операції сховища й час, який займає кожна з них.
Future<void> demoRepository(AsyncRepository<Expense> repository) async {
  print('--- Асинхронне сховище ---');
  final watch = Stopwatch()..start();

  final found = await repository.load(existingId);
  print('load($existingId): ${watch.elapsedMilliseconds} мс → $found');

  watch.reset();
  await repository.save(extraExpense);
  print(
    'save(${extraExpense.id}): ${watch.elapsedMilliseconds} мс, '
    'записів: ${repository.length}',
  );

  watch.reset();
  await repository.delete(extraExpense.id);
  print(
    'delete(${extraExpense.id}): ${watch.elapsedMilliseconds} мс, '
    'записів: ${repository.length}',
  );

  try {
    await repository.delete(missingId);
  } on EntityNotFoundException catch (exception) {
    print('delete($missingId): помилка — $exception');
  }
}

/// Показує, що змінюється, якщо забути `await`.
Future<void> demoForgottenAwait(AsyncRepository<Expense> repository) async {
  print('\n--- Забутий await ---');
  await repository.save(extraExpense);
  print('Після save з await: записів ${repository.length}');

  // Навмисна помилка для демонстрації: результат delete не дочекано.
  // Без наступного рядка аналізатор видає зауваження unawaited_futures.
  // ignore: unawaited_futures
  repository.delete(extraExpense.id);
  print(
    'Одразу після delete без await: записів ${repository.length} '
    '(видалення ще не відбулося)',
  );

  await Future<void>.delayed(repository.latency * 2);
  print('Після очікування: записів ${repository.length}');
}
