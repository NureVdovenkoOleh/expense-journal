/// Важке синхронне обчислення для демонстрації ізолятів.
library;

import 'dart:math' as math;

/// Категорії згенерованих витрат.
const simulationCategories = [
  'Продукти',
  'Транспорт',
  'Кафе',
  'Комунальні',
  'Розваги',
  'Навчання',
  'Здоров’я',
  'Одяг',
];

/// Найбільша сума однієї згенерованої витрати.
const maxSimulatedAmount = 2000.0;

/// Кількість копійок у гривні: суми округлюються до копійок.
const _centsPerUnit = 100;

/// Результат симуляції: кількість витрат, загальна сума й суми за
/// категоріями.
typedef SimulationResult = ({
  int count,
  double total,
  Map<String, double> byCategory,
});

/// Генерує [count] випадкових витрат і рахує суми за категоріями.
///
/// Це навмисно важке синхронне обчислення: мільйони ітерацій без жодного
/// очікування. Поки воно виконується в головному ізоляті, цикл подій
/// стоїть — таймери, потоки й `await` не обслуговуються.
///
/// Генератор випадкових чисел ініціалізується значенням [seed], тому
/// однакові аргументи дають однаковий результат: це дозволяє перевірити,
/// що обчислення в окремому ізоляті дало те саме, що й у головному.
SimulationResult simulateExpenses(int count, {int seed = 1}) {
  final random = math.Random(seed);
  final totals = List<double>.filled(simulationCategories.length, 0);
  for (var i = 0; i < count; i++) {
    final category = random.nextInt(simulationCategories.length);
    final cents = (random.nextDouble() * maxSimulatedAmount * _centsPerUnit)
        .round();
    totals[category] += cents / _centsPerUnit;
  }
  return (
    count: count,
    total: totals.fold(0.0, (sum, value) => sum + value),
    byCategory: {
      for (final (index, name) in simulationCategories.indexed)
        name: totals[index],
    },
  );
}
