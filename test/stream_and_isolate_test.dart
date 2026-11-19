import 'dart:isolate';

import 'package:expense_journal/expense_journal.dart';
import 'package:test/test.dart';

/// Затримка сховища та інтервал потоку в тестах.
const _testDelay = Duration(milliseconds: 5);

/// Створює витрату з ідентифікатором [id].
Expense _expense(String id) => Expense(
  id: id,
  date: DateTime(2026, 11, 19),
  category: 'Кафе',
  amount: 100,
  currency: Currency.uah,
  paymentMethod: const Cash(),
);

void main() {
  group('види потоків', () {
    late AsyncRepository<Expense> repository;

    setUp(() {
      repository = AsyncRepository<Expense>(
        seed: [_expense('A1'), _expense('A2')],
        latency: _testDelay,
      );
    });

    test('потік changes дозволяє лише одну підписку', () async {
      final subscription = repository.changes.listen((event) {});
      expect(() => repository.changes.listen((event) {}), throwsStateError);
      await subscription.cancel();
    });

    test('широкомовний потік отримують обидва слухачі', () async {
      final broadcast = repository
          .watchAll(interval: _testDelay)
          .asBroadcastStream();
      final first = broadcast.toList();
      final second = broadcast.toList();
      expect(await first, hasLength(2));
      expect(await second, hasLength(2));
    });

    test('take зупиняє потік після потрібної кількості', () async {
      await expectLater(
        repository.watchAll(interval: _testDelay).map((e) => e.id).take(1),
        emitsInOrder(['A1', emitsDone]),
      );
    });
  });

  group('simulateExpenses', () {
    const count = 10000;

    test('сума за категоріями дорівнює загальній сумі', () {
      final result = simulateExpenses(count);
      final sum = result.byCategory.values.fold(0.0, (a, b) => a + b);
      expect(result.count, count);
      expect(sum, closeTo(result.total, 0.001));
    });

    test('однаковий seed дає однаковий результат', () {
      expect(
        simulateExpenses(count, seed: 7).total,
        simulateExpenses(count, seed: 7).total,
      );
    });

    test(
      'Isolate.run повертає те саме, що й виклик у головному ізоляті',
      () async {
        final inIsolate = await Isolate.run(() => simulateExpenses(count));
        expect(inIsolate.total, simulateExpenses(count).total);
      },
    );
  });
}
