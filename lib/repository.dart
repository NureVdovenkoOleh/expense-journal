/// Узагальнене сховище сутностей з ідентифікатором.
library;

import 'identifiable.dart';

/// Сховище сутностей, які вміють повідомляти власний ідентифікатор.
///
/// Обмеження `T extends Identifiable` дає дві речі. По-перше, усередині
/// класу компілятор знає, що кожен елемент має властивість `id`: без
/// обмеження про `T` відомо лише те, що це `Object?`, і вираз `item.id`
/// не скомпілювався б. По-друге, створити `Repository<int>` чи
/// `Repository<String>` неможливо — помилку видно ще під час компіляції.
class Repository<T extends Identifiable> {
  /// Елементи за ідентифікатором; порядок додавання зберігається.
  final Map<String, T> _items = {};

  /// Кількість елементів у сховищі.
  int get length => _items.length;

  /// Усі елементи в порядку додавання.
  Iterable<T> get all => _items.values;

  /// Додає [item]; елемент з таким самим ідентифікатором замінюється.
  void add(T item) => _items[item.id] = item;

  /// Додає всі елементи з [items].
  void addAll(Iterable<T> items) => items.forEach(add);

  /// Повертає елемент з ідентифікатором [id] або `null`, якщо його немає.
  T? findById(String id) => _items[id];

  /// Повертає елементи, для яких [test] дає `true`.
  Iterable<T> where(bool Function(T item) test) => _items.values.where(test);

  /// Вилучає елемент з ідентифікатором [id]; повертає `true`, якщо він
  /// був у сховищі.
  bool remove(String id) => _items.remove(id) != null;
}
