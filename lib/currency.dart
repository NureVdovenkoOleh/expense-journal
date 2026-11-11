/// Валюти, у яких ведеться журнал витрат.
library;

/// Валюта витрати з умовним курсом до гривні.
///
/// Перелічення з членами: кожне значення має символ і курс, а метод
/// [toUah] дозволяє додавати суми в різних валютах.
enum Currency {
  /// Українська гривня.
  uah(symbol: '₴', rateToUah: 1),

  /// Долар США.
  usd(symbol: r'$', rateToUah: 41.5),

  /// Євро.
  eur(symbol: '€', rateToUah: 48.2);

  /// Створює значення перелічення із символом [symbol] і курсом
  /// [rateToUah].
  const Currency({required this.symbol, required this.rateToUah});

  /// Символ валюти для звіту.
  final String symbol;

  /// Умовний курс: скільки гривень коштує одна одиниця валюти.
  ///
  /// Курс зафіксовано в коді, бо програма не звертається до мережі.
  final double rateToUah;

  /// Трилітерний код валюти за ISO 4217, наприклад `UAH`.
  String get code => name.toUpperCase();

  /// Перераховує суму [amount] у цій валюті в гривні.
  double toUah(double amount) => amount * rateToUah;

  /// Повертає валюту з кодом [code] або `null`, якщо такої немає.
  static Currency? tryParse(String code) =>
      values.where((currency) => currency.code == code).firstOrNull;
}
