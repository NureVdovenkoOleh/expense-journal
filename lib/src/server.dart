/// HTTP-служба журналу витрат на основі пакета shelf.
library;

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'async_repository.dart';
import 'currency.dart';
import 'expense.dart';
import 'expense_report.dart';
import 'expense_validator.dart';

/// Порт служби за замовчуванням.
const defaultPort = 8080;

/// Заголовки відповіді з JSON.
///
/// Кодування вказано явно: без `charset=utf-8` деякі клієнти прочитали б
/// кирилицю як Latin-1. `shelf` кодує рядкове тіло відповіді в UTF-8,
/// тож заголовок і тіло узгоджені.
const jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

/// Створює відповідь з тілом [body], закодованим у JSON, і кодом
/// [status].
Response jsonResponse(Object? body, {int status = 200, String? location}) =>
    Response(
      status,
      body: jsonEncode(body),
      headers: {...jsonHeaders, 'location': ?location},
    );

/// Створює відповідь-помилку з кодом [status] і поясненням [message].
///
/// Тіло завжди має вигляд `{"error": "..."}`, щоб клієнт міг однаково
/// обробляти всі помилки.
Response errorResponse(int status, String message) =>
    jsonResponse({'error': message}, status: status);

/// Перетворює витрату [expense] на JSON для відповіді служби.
///
/// На відміну від [Expense.toJson], який служить для збереження у файл,
/// публічне представлення не розкриває платіжних реквізитів: спосіб
/// оплати подано як `картка •••• 9876`, а номери карток у примітці
/// замасковано. Будь-хто, хто має доступ до служби, бачить лише те, що
/// бачив би у текстовому звіті.
Map<String, Object?> publicJson(Expense expense) => {
  ...expense.toJson(),
  'paymentMethod': expense.paymentMethod.describe(),
  'note': maskCardNumbers(expense.note),
};

/// Проміжний обробник, який записує кожен запит у журнал [log].
///
/// Проміжний обробник (Middleware) — це функція, що загортає інший
/// обробник: вона бачить запит до нього й відповідь після нього, тому
/// журналювання не доводиться дублювати в кожному маршруті. Рядок
/// журналу: метод, шлях, код відповіді й час обробки.
Middleware requestLogger(void Function(String message) log) =>
    (Handler inner) => (Request request) async {
      final watch = Stopwatch()..start();
      final response = await inner(request);
      log(
        '${request.method} /${request.url} → ${response.statusCode} '
        '(${watch.elapsedMilliseconds} мс)',
      );
      return response;
    };

/// Створює обробник HTTP-служби над сховищем [repository].
///
/// Маршрути:
/// - `GET /items` — перелік витрат; фільтри в параметрах запиту:
///   `category`, `currency`, `minAmount`;
/// - `GET /items/<id>` — одна витрата або 404;
/// - `POST /items` — створення витрати з тіла JSON; 201, 400 або 409.
///
/// Будь-який інший шлях дає 404. Кожен запит записується в [log].
/// Обробник — звичайна функція `Request → Response`, тому тести
/// викликають його напряму, не запускаючи сервер і не відкриваючи порт.
Handler buildHandler(
  AsyncRepository<Expense> repository, {
  required void Function(String message) log,
}) {
  final router = Router()
    ..get('/items', (Request request) => _listItems(repository, request))
    ..get(
      '/items/<id>',
      (Request request, String id) => _getItem(repository, id),
    )
    ..post('/items', (Request request) => _createItem(repository, request))
    // Останній маршрут перехоплює всі інші шляхи й методи: Router
    // перевіряє маршрути в порядку оголошення. Без нього Router
    // відповів би 404 звичайним текстом, а не JSON.
    ..all(
      '/<ignored|.*>',
      (Request request, String ignored) =>
          errorResponse(404, 'маршрут не знайдено'),
    );

  return const Pipeline()
      .addMiddleware(requestLogger(log))
      .addHandler(router.call);
}

/// `GET /items`: перелік витрат з фільтрацією.
///
/// Некоректне значення фільтра — це помилка клієнта (400), а не
/// порожній результат: інакше друкарська помилка в `currency=UDS`
/// мовчки давала б порожній список.
Future<Response> _listItems(
  AsyncRepository<Expense> repository,
  Request request,
) async {
  final query = request.url.queryParameters;

  final currencyCode = query['currency'];
  final currency = currencyCode == null
      ? null
      : Currency.tryParse(currencyCode);
  if (currencyCode != null && currency == null) {
    return errorResponse(400, 'невідома валюта «$currencyCode»');
  }

  final minAmountText = query['minAmount'];
  final minAmount = minAmountText == null
      ? null
      : double.tryParse(minAmountText);
  if (minAmountText != null && minAmount == null) {
    return errorResponse(400, 'minAmount має бути числом');
  }

  final category = query['category'];
  final items = (await repository.loadAll()).where(
    (expense) =>
        (category == null || expense.category == category) &&
        (currency == null || expense.currency == currency) &&
        (minAmount == null || expense.amount >= minAmount),
  );
  return jsonResponse([for (final expense in items) publicJson(expense)]);
}

/// `GET /items/<id>`: одна витрата або 404.
Future<Response> _getItem(
  AsyncRepository<Expense> repository,
  String id,
) async => switch (await repository.load(id)) {
  final Expense expense => jsonResponse(publicJson(expense)),
  null => errorResponse(404, 'витрати «$id» немає'),
};

/// `POST /items`: створення витрати.
///
/// Коди відповіді розрізняють причини невдачі:
/// - 400 — тіло не є JSON, бракує полів, поле має неправильний тип або
///   значення недопустиме (від'ємна сума, дата з майбутнього);
/// - 409 — витрата з таким ідентифікатором уже є: запит сам по собі
///   коректний, але суперечить поточному стану сховища.
Future<Response> _createItem(
  AsyncRepository<Expense> repository,
  Request request,
) async {
  final Expense expense;
  try {
    final decoded = jsonDecode(await request.readAsString());
    if (decoded is! Map<String, Object?>) {
      return errorResponse(400, 'тіло запиту має бути об\'єктом JSON');
    }
    expense = Expense.fromJson(decoded);
  } on FormatException catch (exception) {
    return errorResponse(400, 'некоректне тіло запиту: ${exception.message}');
  }

  final violations = validateExpense(expense);
  if (violations.isNotEmpty) {
    return errorResponse(400, violations.join('; '));
  }
  if (await repository.load(expense.id) != null) {
    return errorResponse(409, 'витрата «${expense.id}» вже існує');
  }

  await repository.save(expense);
  return jsonResponse(
    publicJson(expense),
    status: 201,
    location: '/items/${expense.id}',
  );
}
