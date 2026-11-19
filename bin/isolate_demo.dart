// Демонстрації до лабораторної роботи 3: ізоляти.
//
// Запуск: dart run expense_journal:isolate_demo

import 'dart:async';
import 'dart:isolate';

import 'package:expense_journal/expense_journal.dart';

/// Скільки витрат генерує одна симуляція.
const simulatedCount = 20000000;

/// Інтервал таймера, який перевіряє, чи не заблоковано цикл подій.
const tickInterval = Duration(milliseconds: 100);

/// Глобальна змінна: скільки разів запускали симуляцію.
///
/// Використовується в демонстрації того, що ізолят має власну пам'ять.
var simulationRuns = 0;

/// Точка входу демонстрацій.
Future<void> main() async {
  await demoTiming();
  await demoGlobalVariable();
}

/// Вимірює час дії [action] і рахує, скільки разів за цей час спрацював
/// таймер.
///
/// Таймер спрацьовує лише тоді, коли цикл подій вільний. Якщо дія
/// заблокувала головний ізолят, таймер не спрацює жодного разу.
Future<({int ms, int ticks})> measure(Future<void> Function() action) async {
  var ticks = 0;
  final timer = Timer.periodic(tickInterval, (timer) => ticks++);
  final watch = Stopwatch()..start();
  await action();
  watch.stop();
  timer.cancel();
  return (ms: watch.elapsedMilliseconds, ticks: ticks);
}

/// Друкує рядок з результатом вимірювання.
void report(String title, ({int ms, int ticks}) result) {
  print(
    '  $title: ${result.ms} мс, '
    'таймер спрацював ${result.ticks} раз(и)',
  );
}

/// Порівнює обчислення в головному ізоляті та в окремих ізолятах.
Future<void> demoTiming() async {
  print('--- Симуляція $simulatedCount витрат ---');
  SimulationResult? inMain;
  SimulationResult? inIsolate;

  report(
    'Одна симуляція в головному ізоляті',
    await measure(() async => inMain = simulateExpenses(simulatedCount)),
  );
  report(
    'Одна симуляція в Isolate.run',
    await measure(() async {
      inIsolate = await Isolate.run(() => simulateExpenses(simulatedCount));
    }),
  );
  print(
    '  результати однакові: '
    '${inMain?.total == inIsolate?.total} '
    '(сума ${inMain?.total.toStringAsFixed(2)})',
  );

  print('');
  report(
    'Дві симуляції послідовно в головному ізоляті',
    await measure(() async {
      simulateExpenses(simulatedCount);
      simulateExpenses(simulatedCount, seed: 2);
    }),
  );
  report(
    'Дві симуляції одночасно у двох ізолятах',
    await measure(() async {
      await Future.wait([
        Isolate.run(() => simulateExpenses(simulatedCount)),
        Isolate.run(() => simulateExpenses(simulatedCount, seed: 2)),
      ]);
    }),
  );
}

/// Показує, що зміна глобальної змінної в ізоляті не видна ззовні.
Future<void> demoGlobalVariable() async {
  print('\n--- Глобальна змінна та ізолят ---');
  print('  до запуску: simulationRuns = $simulationRuns');
  final insideIsolate = await Isolate.run(() {
    simulationRuns += 1;
    return simulationRuns;
  });
  print('  в ізоляті після збільшення: $insideIsolate');
  print('  у головному ізоляті після: simulationRuns = $simulationRuns');
}
