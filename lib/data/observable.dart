import 'dart:collection';

/// Collections that report their own mutation.
///
/// This exists to close a hole in the change notification on [Msg]. A field
/// setter fires when a message is reassigned, which covers `m.recalled = true`,
/// but nothing fires for `m.data['state'] = 'ok'` or `m.edits.add(old)`: those
/// mutate a container in place and no setter on the message ever runs. Both
/// happen, the first in the streaming tool path and the second in the edit path,
/// and either one going unpersisted is a message that changes on screen and
/// reverts after a restart.
///
/// Extending MapBase and ListBase rather than wrapping keeps every read
/// behaviour, including the ones only the SDK implementations get right, and
/// costs one delegate lookup per access.
class ObservableMap<K, V> extends MapBase<K, V> {
  ObservableMap(Map<K, V> source) : _delegate = source;

  ObservableMap.of() : _delegate = <K, V>{};

  final Map<K, V> _delegate;

  /// Assigned by the owner once it exists. Until then mutations are silent,
  /// which is what lets a message be built in its constructor and hooked up
  /// afterwards.
  void Function()? onChange;

  @override
  Iterable<K> get keys => _delegate.keys;

  @override
  V? operator [](Object? key) => _delegate[key];

  @override
  void operator []=(K key, V value) {
    _delegate[key] = value;
    onChange?.call();
  }

  @override
  V? remove(Object? key) {
    final gone = _delegate.remove(key);
    if (gone != null) onChange?.call();
    return gone;
  }

  @override
  void clear() {
    if (_delegate.isEmpty) return;
    _delegate.clear();
    onChange?.call();
  }

  @override
  int get hashCode => _delegate.hashCode;

  @override
  bool operator ==(Object other) => _delegate == other;
}

class ObservableList<E> extends ListBase<E> {
  ObservableList(List<E> source) : _delegate = source;

  ObservableList.of() : _delegate = <E>[];

  final List<E> _delegate;

  /// See [ObservableMap.onChange].
  void Function()? onChange;

  @override
  int get length => _delegate.length;

  @override
  set length(int value) {
    if (value == _delegate.length) return;
    _delegate.length = value;
    onChange?.call();
  }

  @override
  E operator [](int index) => _delegate[index];

  @override
  void operator []=(int index, E value) {
    _delegate[index] = value;
    onChange?.call();
  }

  @override
  void add(E value) {
    _delegate.add(value);
    onChange?.call();
  }

  @override
  void addAll(Iterable<E> values) {
    _delegate.addAll(values);
    onChange?.call();
  }

  @override
  E removeAt(int index) {
    final gone = _delegate.removeAt(index);
    onChange?.call();
    return gone;
  }

  @override
  E removeLast() {
    final gone = _delegate.removeLast();
    onChange?.call();
    return gone;
  }

  @override
  bool remove(Object? value) {
    if (!_delegate.remove(value)) return false;
    onChange?.call();
    return true;
  }

  @override
  void clear() {
    if (_delegate.isEmpty) return;
    _delegate.clear();
    onChange?.call();
  }

  @override
  void insert(int index, E value) {
    _delegate.insert(index, value);
    onChange?.call();
  }

  @override
  void insertAll(int index, Iterable<E> values) {
    _delegate.insertAll(index, values);
    onChange?.call();
  }

  @override
  void removeRange(int start, int end) {
    _delegate.removeRange(start, end);
    onChange?.call();
  }

  @override
  void removeWhere(bool Function(E element) test) {
    final before = _delegate.length;
    _delegate.removeWhere(test);
    if (_delegate.length != before) onChange?.call();
  }

  @override
  void sort([int Function(E a, E b)? compare]) {
    _delegate.sort(compare);
    onChange?.call();
  }
}