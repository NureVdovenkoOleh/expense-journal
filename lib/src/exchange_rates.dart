/// Офіційні курси валют Національного банку України.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'currency.dart';

/// Адреса служби курсів НБУ. Ключ автентифікації не потрібен.
final nbuRatesEndpoint = Uri.parse(
  'https://bank.gov.ua/NBUStatService/v1/statdirectory/exchange',
);

/// Скільки чекати на відповідь сервера.
const requestTimeout = Duration(seconds: 10);

/// Шаблон дати НБУ `ДД.ММ.РРРР` з іменованими групами.
final _nbuDatePattern = RegExp(
  r'^(?<day>\d{2})\.(?<month>\d{2})\.(?<year>\d{4})$',
);

/// Офіційний курс однієї валюти на певну дату.
final class ExchangeRate {
  /// Створює курс: одна одиниця валюти [currencyCode] коштує [rate]
  /// гривень на дату [date].
  const ExchangeRate({
    required this.currencyCode,
    required this.rate,
    required this.date,
  });

  /// Створює курс з елемента відповіді НБУ.
  ///
  /// Відповідь має вигляд
  /// `{"r030":840,"txt":"Долар США","rate":41.5,"cc":"USD",
  /// "exchangedate":"25.11.2026"}`. Поля явно приводяться до очікуваних
  /// типів; невідповідність перетворюється на [FormatException].
  factory ExchangeRate.fromJson(Map<String, Object?> json) {
    try {
      return ExchangeRate(
        currencyCode: json['cc'] as String,
        rate: (json['rate'] as num).toDouble(),
        date: _parseNbuDate(json['exchangedate'] as String),
      );
    } on TypeError {
      throw FormatException('неочікувана структура курсу', json);
    }
  }

  /// Трилітерний код валюти, наприклад `USD`.
  final String currencyCode;

  /// Скільки гривень коштує одна одиниця валюти.
  final double rate;

  /// Дата, на яку встановлено курс.
  final DateTime date;

  @override
  String toString() => '$currencyCode: $rate';

  /// Перетворює дату НБУ `ДД.ММ.РРРР` на [DateTime].
  static DateTime _parseNbuDate(String text) {
    final match = _nbuDatePattern.firstMatch(text);
    final [day, month, year] = [
      for (final name in ['day', 'month', 'year'])
        int.tryParse(match?.namedGroup(name) ?? ''),
    ];
    if (day == null || month == null || year == null) {
      throw FormatException('некоректна дата курсу «$text»', text);
    }
    return DateTime(year, month, day);
  }
}

/// Помилка отримання курсів: один із трьох рівнів відмови.
///
/// Запечатаний клас: застосунок розбирає рівні `switch` без `default`.
sealed class RatesException implements Exception {
  /// Створює помилку з описом [message].
  const RatesException(this.message);

  /// Опис помилки для користувача.
  final String message;

  @override
  String toString() => message;
}

/// Рівень 1: з'єднання не встановлено або відповідь не надійшла вчасно.
///
/// Типові причини: немає мережі, ім'я хоста не знайдено, сервер не
/// відповідає. Типові винятки — [SocketException],
/// [http.ClientException], [TimeoutException].
final class RatesConnectionException extends RatesException {
  /// Створює помилку з'єднання з описом [message].
  const RatesConnectionException(super.message);
}

/// Рівень 2: сервер відповів, але кодом, відмінним від 2xx.
final class RatesHttpException extends RatesException {
  /// Створює помилку для коду відповіді [statusCode].
  const RatesHttpException(this.statusCode)
    : super('сервер відповів кодом $statusCode');

  /// Код відповіді HTTP, наприклад 404 чи 503.
  final int statusCode;
}

/// Рівень 3: відповідь 2xx, але тіло не є очікуваним JSON.
///
/// Типова причина — [FormatException] у `jsonDecode` або неочікувана
/// структура даних.
final class RatesFormatException extends RatesException {
  /// Створює помилку формату з описом [message].
  const RatesFormatException(super.message);
}

/// Клієнт служби курсів НБУ.
///
/// HTTP-клієнт передається ззовні, а не створюється всередині: так у
/// тестах його можна підмінити на `MockClient`, який не ходить у мережу.
/// Закриває клієнт той, хто його створив.
class NbuRatesClient {
  /// Створює клієнт, який надсилає запити через [client] на адресу
  /// [endpoint].
  NbuRatesClient(this._client, {Uri? endpoint})
    : endpoint = endpoint ?? nbuRatesEndpoint;

  final http.Client _client;

  /// Адреса служби курсів.
  final Uri endpoint;

  /// Отримує офіційний курс валюти [currency] на сьогодні.
  ///
  /// Кидає [RatesException] одного з трьох рівнів. Успішне завершення
  /// `await _client.get` ще не означає успіху: сервер міг повернути
  /// 404 чи 500, тому код відповіді перевіряється явно.
  Future<ExchangeRate> fetchRate(Currency currency) async {
    final uri = Uri.parse('$endpoint?valcode=${currency.code}&json');

    final http.Response response;
    try {
      response = await _client.get(uri).timeout(requestTimeout);
    } on SocketException catch (exception) {
      throw RatesConnectionException('немає з\'єднання: ${exception.message}');
    } on http.ClientException catch (exception) {
      throw RatesConnectionException('немає з\'єднання: ${exception.message}');
    } on TimeoutException {
      throw RatesConnectionException(
        'сервер не відповів за ${requestTimeout.inSeconds} с',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RatesHttpException(response.statusCode);
    }

    try {
      // Тіло декодується як UTF-8 явно: сервер може не вказати кодування
      // в заголовку, і тоді `response.body` зіпсував би кирилицю.
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return switch (decoded) {
        [final Map<String, Object?> first, ...] => ExchangeRate.fromJson(first),
        [] => throw RatesFormatException(
          'курс ${currency.code} у відповіді відсутній',
        ),
        _ => throw const RatesFormatException('відповідь не є масивом JSON'),
      };
    } on FormatException catch (exception) {
      throw RatesFormatException(
        'некоректне тіло відповіді: ${exception.message}',
      );
    }
  }
}
