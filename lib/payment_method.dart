/// Способи оплати витрат: запечатана ієрархія типів.
library;

/// Роздільник між видом оплати та реквізитами: `картка:5375414100009876`.
const _detailsSeparator = ':';

/// Кількість останніх цифр, які лишаються видимими після маскування.
const _visibleDigits = 4;

/// Умовна комісія банку за переказ — 0,5 % від суми.
const _transferFeeRate = 0.005;

/// Номер картки: рівно 16 цифр.
final _cardNumberPattern = RegExp(r'^\d{16}$');

/// Український IBAN: літери `UA` і 27 цифр.
final _ibanPattern = RegExp(r'^UA\d{27}$');

/// Спосіб оплати витрати.
///
/// Клас запечатаний (`sealed`): усі його підтипи оголошено в цьому файлі,
/// тому `switch` за способом оплати компілятор перевіряє на вичерпність.
sealed class PaymentMethod {
  /// Створює спосіб оплати; викликається лише з підтипів.
  const PaymentMethod();

  /// Розбирає спосіб оплати з тексту: `готівка`,
  /// `картка:<16 цифр>` або `переказ:<IBAN>`.
  ///
  /// Фабричний конструктор: повертає один із підтипів, а для готівки —
  /// завжди той самий константний екземпляр. Якщо текст не відповідає
  /// жодному формату, кидає [FormatException]; щоб отримати `null`
  /// замість винятку, скористайтеся [tryParse].
  factory PaymentMethod.parse(String text) =>
      tryParse(text) ??
      (throw FormatException('невідомий спосіб оплати «$text»', text));

  /// Розбирає спосіб оплати з [text] або повертає `null`.
  static PaymentMethod? tryParse(String text) =>
      switch (text.trim().split(_detailsSeparator)) {
        ['готівка'] => const Cash(),
        ['картка', final number] when _cardNumberPattern.hasMatch(number) =>
          CardPayment(number),
        ['переказ', final iban] when _ibanPattern.hasMatch(iban) =>
          BankTransfer(iban),
        _ => null,
      };

  /// Назва способу оплати українською.
  String get label;

  /// Опис способу оплати для звіту.
  ///
  /// Підтипи з номером рахунку чи картки перевизначають цей метод через
  /// домішку [MaskedNumber].
  String describe() => label;

  /// Обчислює комісію за оплату суми [amount] цим способом.
  double feeFor(double amount);
}

/// Готівкова оплата.
final class Cash extends PaymentMethod {
  /// Створює готівкову оплату.
  const Cash();

  @override
  String get label => 'готівка';

  @override
  bool operator ==(Object other) => other is Cash;

  @override
  int get hashCode => (Cash).hashCode;

  @override
  double feeFor(double amount) => 0;
}

/// Оплата банківською карткою.
final class CardPayment extends PaymentMethod with MaskedNumber {
  /// Створює оплату карткою з номером [number].
  const CardPayment(this.number);

  /// Номер картки — 16 цифр.
  @override
  final String number;

  @override
  String get label => 'картка';

  @override
  double feeFor(double amount) => 0;
}

/// Банківський переказ на рахунок IBAN.
final class BankTransfer extends PaymentMethod with MaskedNumber {
  /// Створює переказ на рахунок [number].
  const BankTransfer(this.number);

  /// IBAN рахунку отримувача.
  @override
  final String number;

  @override
  String get label => 'переказ';

  @override
  double feeFor(double amount) => amount * _transferFeeRate;
}

/// Маскування номера картки чи рахунку у звіті.
///
/// Обмеження `on PaymentMethod` робить дві речі: дозволяє підмішувати
/// домішку лише до способів оплати й відкриває всередині неї доступ до
/// членів [PaymentMethod] — тут до [PaymentMethod.label].
mixin MaskedNumber on PaymentMethod {
  /// Повний номер, який не можна показувати у звіті.
  String get number;

  /// Номер, у якому видно лише останні цифри, наприклад `•••• 9876`.
  String get maskedNumber =>
      '•••• ${number.substring(number.length - _visibleDigits)}';

  @override
  String describe() => '$label $maskedNumber';

  /// Два способи оплати рівні, якщо вони одного типу й мають той самий
  /// номер.
  @override
  bool operator ==(Object other) =>
      other is MaskedNumber &&
      other.runtimeType == runtimeType &&
      other.number == number;

  @override
  int get hashCode => Object.hash(runtimeType, number);
}
