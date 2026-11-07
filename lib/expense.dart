/// Тип запису витрати.
library;

/// Одна витрата з журналу особистих витрат.
///
/// Подана записом (record), а не класом: у лабораторній роботі 1 класи
/// навмисно не використовуються.
typedef Expense = ({
  DateTime date,
  String category,
  double amount,
  String currency,
  String paymentMethod,
  String note,
});
