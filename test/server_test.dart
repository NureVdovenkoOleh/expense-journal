import 'dart:convert';

import 'package:expense_journal/expense_journal.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Базова адреса запитів у тестах; сервер не запускається, тож хост
/// може бути будь-яким.
const _host = 'localhost';

/// Тіло коректної нової витрати для POST.
Map<String, Object?> _newExpense({String id = 'N01', num amount = 120}) => {
  'id': id,
  'date': '2026-11-20',
  'category': 'Кафе',
  'amount': amount,
  'currency': 'UAH',
  'paymentMethod': 'готівка',
  'note': 'Тест',
};

void main() {
  late AsyncRepository<Expense> repository;
  late Handler handler;
  late List<String> log;

  setUp(() {
    repository = AsyncRepository<Expense>(
      seed: validExpenses(rawExpenses.map(parseExpense)),
      latency: Duration.zero,
    );
    log = [];
    handler = buildHandler(repository, log: log.add);
  });

  tearDown(() => repository.close());

  /// Надсилає GET на [path] з параметрами [query].
  Future<Response> get(String path, [Map<String, String>? query]) async =>
      handler(Request('GET', Uri.http(_host, path, query)));

  /// Надсилає POST на `/items` з тілом [body].
  Future<Response> post(String body) async =>
      handler(Request('POST', Uri.http(_host, '/items'), body: body));

  /// Декодує тіло відповіді [response] як JSON.
  Future<Object?> bodyOf(Response response) async =>
      jsonDecode(await response.readAsString());

  group('GET /items', () {
    test('повертає всі витрати з заголовком JSON у UTF-8', () async {
      final response = await get('/items');
      expect(response.statusCode, 200);
      expect(
        response.headers['content-type'],
        'application/json; charset=utf-8',
      );
      expect(await bodyOf(response), hasLength(15));
    });

    test('кирилиця в тілі відповіді не псується', () async {
      final response = await get('/items', {'category': 'Продукти'});
      final text = utf8.decode(await response.read().expand((b) => b).toList());
      expect(text, contains('"category":"Продукти"'));
    });

    test('фільтрує за категорією, валютою й мінімальною сумою', () async {
      final response = await get('/items', {
        'category': 'Продукти',
        'currency': 'UAH',
        'minAmount': '800',
      });
      final ids = [
        for (final item in await bodyOf(response) as List<Object?>)
          (item as Map<String, Object?>)['id'],
      ];
      expect(ids, ['E01', 'E11']);
    });

    test('невідома валюта у фільтрі дає 400', () async {
      expect((await get('/items', {'currency': 'XYZ'})).statusCode, 400);
    });

    test('нечислова minAmount дає 400', () async {
      expect((await get('/items', {'minAmount': 'багато'})).statusCode, 400);
    });
  });

  group('GET /items/<id>', () {
    test('повертає витрату за ідентифікатором', () async {
      final response = await get('/items/E05');
      expect(response.statusCode, 200);
      expect(await bodyOf(response), containsPair('category', 'Комунальні'));
    });

    test('для відсутньої витрати дає 404 з поясненням', () async {
      final response = await get('/items/E99');
      expect(response.statusCode, 404);
      expect(await bodyOf(response), containsPair('error', contains('E99')));
    });
  });

  group('POST /items', () {
    test('створює витрату: 201, location і доступ через GET', () async {
      final response = await post(jsonEncode(_newExpense()));
      expect(response.statusCode, 201);
      expect(response.headers['location'], '/items/N01');
      expect((await get('/items/N01')).statusCode, 200);
    });

    test('тіло не JSON дає 400', () async {
      expect((await post('не json')).statusCode, 400);
    });

    test('масив замість об\'єкта дає 400', () async {
      expect((await post('[1, 2]')).statusCode, 400);
    });

    test('відсутнє поле дає 400', () async {
      final body = _newExpense()..remove('category');
      expect((await post(jsonEncode(body))).statusCode, 400);
    });

    test('від\'ємна сума дає 400 з повідомленням валідатора', () async {
      final response = await post(jsonEncode(_newExpense(amount: -5)));
      expect(response.statusCode, 400);
      expect(await bodyOf(response), containsPair('error', contains('сума')));
    });

    test('наявний ідентифікатор дає 409', () async {
      expect((await post(jsonEncode(_newExpense(id: 'E01')))).statusCode, 409);
    });
  });

  test('відповідь не розкриває номерів карток і рахунків', () async {
    final card = await bodyOf(await get('/items/E01'));
    expect(card, containsPair('paymentMethod', 'картка •••• 9876'));

    final note = await bodyOf(await get('/items/E13'));
    expect(note, containsPair('note', contains('5375 **** **** 9876')));

    final all = await (await get('/items')).readAsString();
    expect(all, isNot(contains('5375414100009876')));
    expect(all, isNot(contains('4141 0000')));
    expect(all, isNot(contains('UA213223130000026007233566001')));
  });

  test('невідомий маршрут дає 404 у форматі JSON', () async {
    final response = await get('/unknown');
    expect(response.statusCode, 404);
    expect(await bodyOf(response), containsPair('error', isNotEmpty));
  });

  test('проміжний обробник записує метод, шлях і код відповіді', () async {
    await get('/items/E99');
    expect(log, [startsWith('GET /items/E99 → 404')]);
  });
}
