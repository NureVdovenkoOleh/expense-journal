// Демонстрації до лабораторної роботи 3: потоки даних.
//
// Запуск: dart run expense_journal:stream_demo

import 'dart:async';

import 'package:expense_journal/expense_journal.dart';

/// Затримка операцій сховища в цих демонстраціях.
const latency = Duration(milliseconds: 50);

/// Інтервал між елементами потоку.
const itemInterval = Duration(milliseconds: 100);

/// Пауза, протягом якої на потік навмисно ніхто не підписаний.
const pause = Duration(milliseconds: 500);

/// Скільки витрат взяти зі вхідних даних, щоб вивід був коротким.
const shownCount = 3;

/// Ідентифікатор, якого у сховищі немає.
const missingId = 'E99';

/// Створює додаткову витрату з ідентифікатором [id].
Expense extraExpense(String id) => Expense(
  id: id,
  date: DateTime(2026, 11, 18),
  category: 'Кафе',
  amount: 60,
  currency: Currency.uah,
  paymentMethod: const Cash(),
);

/// Точка входу демонстрацій.
Future<void> main() async {
  final seed = validExpenses(rawExpenses.map(parseExpense)).take(shownCount);
  final repository = AsyncRepository<Expense>(seed: seed, latency: latency);

  await demoGenerator(repository);
  await demoController(repository);
  await demoErrorInStream(seed.toList());
}

/// Генератор з повідомленням на початку тіла: доводить лінивість.
Stream<Expense> tracedWatch(AsyncRepository<Expense> repository) async* {
  print('  [генератор] тіло почало виконуватися');
  yield* repository.watchAll(interval: itemInterval);
}

/// Показує лінивий генератор `async*` і споживання через `await for`.
Future<void> demoGenerator(AsyncRepository<Expense> repository) async {
  print('--- Генератор async* ---');
  final stream = tracedWatch(repository);
  print('  потік створено; ${pause.inMilliseconds} мс підписки немає');
  await Future<void>.delayed(pause);

  print('  підписуємося через await for');
  final watch = Stopwatch()..start();
  await for (final expense in stream) {
    print(
      '  ${watch.elapsedMilliseconds} мс: ${expense.id} ${expense.category}',
    );
  }
  print('  потік завершився сам');
}

/// Показує буфер контролера й явне скасування підписки.
Future<void> demoController(AsyncRepository<Expense> repository) async {
  print('\n--- StreamController: події до підписки ---');
  await repository.save(extraExpense('E91'));
  await repository.save(extraExpense('E92'));
  await repository.delete('E91');
  print('  три події вже додано, а підписки ще немає');

  // listen повертає підписку; її збережено, щоб потім скасувати.
  final subscription = repository.changes.listen(
    (event) => print('  отримано: $event'),
  );
  await Future<void>.delayed(latency);

  await subscription.cancel();
  print('  підписку скасовано');
  await repository.save(extraExpense('E93'));
  print('  подію після скасування додано, але її ніхто не отримав');
  repository.close();
}

/// Створює потік: витрата, помилка, ще одна витрата.
Stream<Expense> streamWithError(List<Expense> items) {
  final controller = StreamController<Expense>()
    ..add(items[0])
    ..addError(const EntityNotFoundException(missingId))
    ..add(items[1]);
  unawaited(controller.close());
  return controller.stream;
}

/// Порівнює реакцію `await for` і `listen` на помилку посеред потоку.
Future<void> demoErrorInStream(List<Expense> items) async {
  print('\n--- Помилка посеред потоку ---');

  print('await for:');
  try {
    await for (final expense in streamWithError(items)) {
      print('  дані: ${expense.id}');
    }
    print('  цикл дійшов до кінця');
  } on EntityNotFoundException catch (error) {
    print('  помилка перервала цикл: $error');
  }

  print('listen з cancelOnError: false:');
  final done = Completer<void>();
  final subscription = streamWithError(items).listen(
    (expense) => print('  дані: ${expense.id}'),
    onError: (Object error) => print('  помилка: $error; потік триває'),
    onDone: () {
      print('  потік завершився');
      done.complete();
    },
    cancelOnError: false,
  );
  await done.future;
  // Явна точка скасування: потік уже завершився, але правило дисципліни
  // вимагає, щоб кожна підписка мала місце, де її скасовують.
  await subscription.cancel();
}
