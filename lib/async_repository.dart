/// Асинхронне сховище: імітація повільного джерела даних.
library;

import 'identifiable.dart';
import 'repository.dart';

/// Затримка однієї операції сховища за замовчуванням.
const defaultLatency = Duration(milliseconds: 300);

/// Помилка: у сховищі немає сутності з потрібним ідентифікатором.
class EntityNotFoundException implements Exception {
  /// Створює помилку для ідентифікатора [id].
  const EntityNotFoundException(this.id);

  /// Ідентифікатор, за яким нічого не знайдено.
  final String id;

  @override
  String toString() => 'запису з ідентифікатором «$id» немає у сховищі';
}

/// Асинхронне сховище сутностей предметної області.
///
/// Імітує базу даних або мережеву службу: кожна операція спершу чекає
/// [latency], а вже потім виконується, і тому повертає [Future]. Справжні
/// файли й мережа з'являться в лабораторній роботі 4; інтерфейс класу
/// при цьому не зміниться.
///
/// Самі дані зберігає синхронне сховище [Repository] з лабораторної
/// роботи 2 — цей клас лише додає до нього очікування.
class AsyncRepository<T extends Identifiable> {
  /// Створює сховище з початковими елементами [seed].
  ///
  /// Затримку [latency] можна зменшити, щоб тести не чекали даремно.
  AsyncRepository({
    Iterable<T> seed = const [],
    this.latency = defaultLatency,
  }) {
    _store.addAll(seed);
  }

  /// Затримка кожної операції.
  final Duration latency;

  final Repository<T> _store = Repository<T>();

  /// Кількість елементів просто зараз, без очікування.
  ///
  /// Потрібна, щоб побачити стан сховища до завершення операції, яку
  /// забули дочекатися.
  int get length => _store.length;

  /// Повертає сутність з ідентифікатором [id] або `null`, якщо її немає.
  Future<T?> load(String id) async {
    await _wait();
    return _store.findById(id);
  }

  /// Повертає всі сутності в порядку додавання.
  Future<List<T>> loadAll() async {
    await _wait();
    return _store.all.toList();
  }

  /// Зберігає [item]; сутність з таким самим ідентифікатором замінюється.
  Future<void> save(T item) async {
    await _wait();
    _store.add(item);
  }

  /// Видаляє сутність з ідентифікатором [id].
  ///
  /// Якщо такої сутності немає, повернений [Future] завершується
  /// помилкою [EntityNotFoundException].
  Future<void> delete(String id) async {
    await _wait();
    if (!_store.remove(id)) {
      throw EntityNotFoundException(id);
    }
  }

  /// Імітує час відповіді джерела даних.
  Future<void> _wait() => Future<void>.delayed(latency);
}
