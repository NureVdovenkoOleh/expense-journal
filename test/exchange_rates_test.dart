import 'dart:convert';
import 'dart:io';

import 'package:expense_journal/expense_journal.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Відповідь НБУ для однієї валюти — так, як її повертає справжня служба.
String _nbuBody(String code, double rate) => jsonEncode([
  {
    'r030': 840,
    'txt': 'Долар США',
    'rate': rate,
    'cc': code,
    'exchangedate': '25.11.2026',
  },
]);

/// Клієнт, який на будь-який запит відповідає [body] з кодом [status].
///
/// `MockClient` з `package:http/testing.dart` не ходить у мережу:
/// він викликає передану функцію й повертає її відповідь.
MockClient _respond(String body, {int status = 200}) => MockClient(
  (request) async => http.Response.bytes(utf8.encode(body), status),
);

void main() {
  group('ExchangeRate.fromJson', () {
    test('розбирає курс і дату у форматі НБУ', () {
      final rate = ExchangeRate.fromJson({
        'cc': 'EUR',
        'rate': 48,
        'exchangedate': '01.12.2026',
      });
      expect(rate.currencyCode, 'EUR');
      expect(rate.rate, 48.0);
      expect(rate.date, DateTime(2026, 12));
    });

    test('кидає FormatException для поля неправильного типу', () {
      expect(
        () => ExchangeRate.fromJson({
          'cc': 'EUR',
          'rate': 'сорок вісім',
          'exchangedate': '01.12.2026',
        }),
        throwsFormatException,
      );
    });
  });

  group('NbuRatesClient', () {
    test('надсилає код валюти й повертає курс', () async {
      late Uri requested;
      final client = MockClient((request) async {
        requested = request.url;
        return http.Response.bytes(utf8.encode(_nbuBody('USD', 41.9)), 200);
      });
      final rate = await NbuRatesClient(client).fetchRate(Currency.usd);
      expect(rate.rate, 41.9);
      expect(requested.query, contains('valcode=USD'));
    });

    test('рівень 1: помилка з\'єднання → RatesConnectionException', () async {
      final client = MockClient(
        (request) => throw http.ClientException('Failed host lookup'),
      );
      await expectLater(
        NbuRatesClient(client).fetchRate(Currency.usd),
        throwsA(isA<RatesConnectionException>()),
      );
    });

    test('рівень 1: SocketException → RatesConnectionException', () async {
      final client = MockClient(
        (request) => throw const SocketException('Network is unreachable'),
      );
      await expectLater(
        NbuRatesClient(client).fetchRate(Currency.usd),
        throwsA(isA<RatesConnectionException>()),
      );
    });

    test('рівень 2: код 503 → RatesHttpException', () async {
      await expectLater(
        NbuRatesClient(_respond('', status: 503)).fetchRate(Currency.usd),
        throwsA(
          isA<RatesHttpException>().having((e) => e.statusCode, 'код', 503),
        ),
      );
    });

    test('рівень 3: HTML замість JSON → RatesFormatException', () async {
      await expectLater(
        NbuRatesClient(_respond('<html>Сторінка</html>'))
            .fetchRate(Currency.usd),
        throwsA(isA<RatesFormatException>()),
      );
    });

    test('рівень 3: порожній масив → RatesFormatException', () async {
      await expectLater(
        NbuRatesClient(_respond('[]')).fetchRate(Currency.usd),
        throwsA(isA<RatesFormatException>()),
      );
    });
  });

  group('команда rates', () {
    late StringBuffer out;
    late StringBuffer err;

    setUp(() {
      out = StringBuffer();
      err = StringBuffer();
    });

    test('друкує офіційні курси обох валют', () async {
      final code = await runCli(
        ['rates'],
        out: out,
        err: err,
        httpClient: () => MockClient((request) async {
          final valcode = request.url.queryParameters['valcode'] ?? '';
          return http.Response.bytes(utf8.encode(_nbuBody(valcode, 42)), 200);
        }),
      );
      expect(code, exitSuccess);
      expect(out.toString(), contains('USD: офіційний 42.0000'));
      expect(out.toString(), contains('EUR: офіційний 42.0000'));
    });

    test('при недоступній службі пише в stderr і повертає 69', () async {
      final code = await runCli(
        ['rates'],
        out: out,
        err: err,
        httpClient: () => _respond('', status: 500),
      );
      expect(code, exitUnavailable);
      expect(err.toString(), contains('кодом 500'));
      expect(out.toString(), isEmpty);
    });

    test('при некоректній відповіді повертає 76', () async {
      final code = await runCli(
        ['rates'],
        out: out,
        err: err,
        httpClient: () => _respond('не json'),
      );
      expect(code, exitProtocolError);
    });
  });
}
