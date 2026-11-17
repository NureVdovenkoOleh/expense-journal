import 'package:expense_journal/expense_journal.dart';
import 'package:test/test.dart';

/// Затримка сховища в тестах: достатня, щоб операція була справді
/// асинхронною, але тести не чекали даремно.
const _testLatency = Duration(milliseconds: 10);

/// Створює витрату з ідентифікатором [id] і сумою [amount].
Expense _expense(String id, {double amount = 100}) => Expense(
  id: id,
  date: DateTime(2026, 11, 16),
  category: 'Кафе',
  amount: amount,
  currency: Currency.uah,
  paymentMethod: const Cash(),
);

void main() {
  group('AsyncRepository', () {
    // late — звичайний прийом для setUp: змінна отримує значення перед
    // кожним тестом, тож кожен тест працює зі свіжим сховищем.
    late AsyncRepository<Expense> repository;

    setUp(() {
      repository = AsyncRepository<Expense>(
        seed: [_expense('A1'), _expense('A2')],
        latency: _testLatency,
      );
    });

    test('load повертає збережену сутність', () async {
      final loaded = await repository.load('A1');
      expect(loaded, _expense('A1'));
    });

    test('load повертає null для невідомого ідентифікатора', () async {
      await expectLater(repository.load('ZZ'), completion(isNull));
    });

    test('require повертає сутність або завершується помилкою', () async {
      expect((await repository.require('A2')).id, 'A2');
      await expectLater(
        repository.require('ZZ'),
        throwsA(isA<EntityNotFoundException>()),
      );
    });

    test('Future.wait повертає результати в порядку запитів', () async {
      final loaded = await Future.wait([
        repository.require('A2'),
        repository.require('A1'),
      ]);
      expect(loaded.map((expense) => expense.id), ['A2', 'A1']);
    });

    test('save додає нову сутність', () async {
      await repository.save(_expense('A3'));
      expect(await repository.load('A3'), isNotNull);
      expect(repository.length, 3);
    });

    test('save замінює сутність з тим самим ідентифікатором', () async {
      await repository.save(_expense('A1', amount: 999));
      final loaded = await repository.load('A1');
      expect(loaded?.amount, 999);
      expect(repository.length, 2);
    });

    test('delete видаляє сутність', () async {
      await repository.delete('A1');
      expect(await repository.load('A1'), isNull);
    });

    test(
      'delete завершується помилкою для невідомого ідентифікатора',
      () async {
        await expectLater(
          repository.delete('ZZ'),
          throwsA(
            isA<EntityNotFoundException>().having((e) => e.id, 'id', 'ZZ'),
          ),
        );
      },
    );

    test('loadAll зберігає порядок додавання', () async {
      final all = await repository.loadAll();
      expect(all.map((expense) => expense.id), ['A1', 'A2']);
    });

    test('операція без await ще не виконана на наступному рядку', () async {
      final pending = repository.save(_expense('A3'));
      expect(repository.length, 2);
      await pending;
      expect(repository.length, 3);
    });
  });
}
