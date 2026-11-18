/// Асинхронне сховище: імітація повільного джерела даних.
library;

import 'dart:async';

import 'identifiable.dart';
import 'repository.dart';

/// Затримка однієї операції сховища за замовчуванням.
const defaultLatency = Duration(milliseconds: 300);

/// Інтервал між елементами потоку [AsyncRepository.watchAll].
const defaultInterval = Duration(milliseconds: 100);

/// Подія зміни вмісту сховища.
///
/// Запечатаний клас: обробник подій може розібрати їх `switch` без
/// гілки `default`.
sealed class RepositoryEvent<T> {
  /// Створює подію; викликається лише з підтипів.
  const RepositoryEvent();
}

/// Сутність збережено: додано нову або замінено наявну.
final class ItemSaved<T> extends RepositoryEvent<T> {
  /// Створює подію збереження сутності [item].
  const ItemSaved(this.item);

  /// Збережена сутність.
  final T item;

  @override
  String toString() => 'збережено $item';
}

/// Сутність видалено.
final class ItemDeleted<T> extends RepositoryEvent<T> {
  /// Створює подію видалення сутності з ідентифікатором [id].
  const ItemDeleted(this.id);

  /// Ідентифікатор видаленої сутності.
  final String id;

  @override
  String toString() => 'видалено $id';
}

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

  /// Джерело подій про зміни.
  ///
  /// Контролер одноразової підписки: події, додані до появи слухача,
  /// накопичуються в буфері й не губляться. Звідси й ризик: якщо
  /// контролер ніколи не закрити, а потік ніколи не прослухати, буфер
  /// житиме стільки, скільки сховище. Тому є метод [close].
  final StreamController<RepositoryEvent<T>> _changes =
      StreamController<RepositoryEvent<T>>();

  /// Потік подій про зміни вмісту сховища.
  ///
  /// Потік одноразової підписки: слухати його можна лише один раз.
  Stream<RepositoryEvent<T>> get changes => _changes.stream;

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

  /// Повертає сутність з ідентифікатором [id].
  ///
  /// На відміну від [load], не повертає `null`: якщо сутності немає,
  /// [Future] завершується помилкою [EntityNotFoundException].
  Future<T> require(String id) async {
    await _wait();
    return _store.findById(id) ?? (throw EntityNotFoundException(id));
  }

  /// Видає сутності по одній з інтервалом [interval], як у міру
  /// надходження з мережі.
  ///
  /// Генератор `async*` лінивий: його тіло починає виконуватися лише
  /// тоді, коли на потік хтось підписався. Коли перебір закінчено,
  /// потік закривається сам — закривати його вручну не потрібно.
  Stream<T> watchAll({Duration interval = defaultInterval}) async* {
    // Знімок вмісту: зміни сховища під час перебору його не зламають.
    for (final item in _store.all.toList()) {
      await Future<void>.delayed(interval);
      yield item;
    }
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
    _changes.add(ItemSaved(item));
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
    _changes.add(ItemDeleted(id));
  }

  /// Закриває потік змін: після цього слухач отримає подію завершення,
  /// а контролер звільнить буфер.
  ///
  /// Результат `_changes.close()` навмисно не дочікується: для потоку,
  /// який ніхто не слухав, він не завершився б ніколи.
  void close() => unawaited(_changes.close());

  /// Імітує час відповіді джерела даних.
  Future<void> _wait() => Future<void>.delayed(latency);
}
