// Демонстрації до лабораторної роботи 3: види потоків і конвеєр
// трансформації.
//
// Запуск: dart run expense_journal:pipeline_demo

import 'package:expense_journal/expense_journal.dart';

/// Затримка операцій сховища в цих демонстраціях.
const latency = Duration(milliseconds: 50);

/// Інтервал між елементами потоку.
const itemInterval = Duration(milliseconds: 50);

/// Скільки витрат бере широкомовний приклад.
const broadcastCount = 3;

/// Скільки елементів пропускає конвеєр.
const pipelineCount = 3;

/// Точка входу демонстрацій.
Future<void> main() async {
  final expenses = validExpenses(rawExpenses.map(parseExpense));
  final repository = AsyncRepository<Expense>(seed: expenses, latency: latency);

  await demoSingleSubscription(repository);
  await demoBroadcast(
    AsyncRepository<Expense>(seed: expenses.take(broadcastCount)),
  );
  await demoPipeline(repository);
  repository.close();
}

/// Показує помилку повторної підписки на потік одноразової підписки.
Future<void> demoSingleSubscription(AsyncRepository<Expense> repository) async {
  print('--- Потік одноразової підписки ---');
  final first = repository.changes.listen((event) {});
  print('  перша підписка: успішно');
  try {
    final second = repository.changes.listen((event) {});
    await second.cancel();
  } on StateError catch (error) {
    print('  друга підписка: $error');
  }
  await first.cancel();
}

/// Показує, що широкомовний потік дозволяє кілька слухачів.
Future<void> demoBroadcast(AsyncRepository<Expense> repository) async {
  print('\n--- Широкомовний потік ---');
  final broadcast = repository
      .watchAll(interval: itemInterval)
      .asBroadcastStream();

  final first = broadcast.listen((e) => print('  слухач A отримав ${e.id}'));
  final second = broadcast.listen((e) => print('  слухач B отримав ${e.id}'));

  // asFuture завершується разом із потоком; після цього обидві підписки
  // явно скасовано.
  await Future.wait([first.asFuture<void>(), second.asFuture<void>()]);
  await first.cancel();
  await second.cancel();
  print('  обидва слухачі отримали всі ${repository.length} витрати');
}

/// Генератор, який повідомляє, коли його зупинили.
Stream<Expense> tracedWatch(AsyncRepository<Expense> repository) async* {
  try {
    yield* repository.watchAll(interval: itemInterval);
  } finally {
    print('  [генератор] зупинено');
  }
}

/// Будує конвеєр where → map → take над потоком витрат.
Future<void> demoPipeline(AsyncRepository<Expense> repository) async {
  print('\n--- Конвеєр where → map → take ---');
  print(
    '  у сховищі ${repository.length} витрат; потрібні перші '
    '$pipelineCount оплати карткою',
  );

  final lines = tracedWatch(repository)
      .where((expense) => expense.paymentMethod is CardPayment)
      .map(
        (expense) =>
            '${expense.date.toDisplayDate()} ${expense.category}: '
            '${expense.amount} ${expense.currency.code}',
      )
      .take(pipelineCount);

  await for (final line in lines) {
    print('  $line');
  }
  print('  конвеєр завершився');
}
