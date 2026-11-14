import 'package:expense_journal/expense_journal.dart';
import 'package:test/test.dart';

/// Найпростіша сутність з ідентифікатором: показує, що сховище працює
/// з будь-яким типом, який реалізує [Identifiable], а не лише з витратами.
class _Tag implements Identifiable {
  const _Tag(this.id);

  @override
  final String id;
}

void main() {
  group('Repository<Expense>', () {
    final journal = Repository<Expense>()
      ..addAll(rawExpenses.take(3).map(Expense.fromCsv));

    test('зберігає додані витрати', () {
      expect(journal.length, 3);
      expect(journal.all.map((expense) => expense.id), ['E01', 'E02', 'E03']);
    });

    test('знаходить витрату за ідентифікатором', () {
      expect(journal.findById('E02')?.category, 'Транспорт');
      expect(journal.findById('E99'), isNull);
    });

    test('відбирає витрати за умовою', () {
      final cash = journal.where((e) => e.paymentMethod is Cash);
      expect(cash.single.id, 'E03');
    });
  });

  group('Repository<_Tag>', () {
    test('замінює елемент з тим самим ідентифікатором', () {
      final tags = Repository<_Tag>()
        ..add(const _Tag('a'))
        ..add(const _Tag('a'));
      expect(tags.length, 1);
    });

    test('вилучає елемент', () {
      final tags = Repository<_Tag>()..add(const _Tag('a'));
      expect(tags.remove('a'), isTrue);
      expect(tags.remove('a'), isFalse);
    });
  });
}
