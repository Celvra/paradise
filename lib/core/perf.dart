import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Byte-bounded least-recently-used cache.
///
/// Ported from kelivo's `lib/shared/cache/byte_lru_cache.dart`. The budget is
/// decoded memory rather than an entry count: one 400 KiB highlighted code
/// block and four hundred 1 KiB ones are the same number of entries and wildly
/// different amounts of retained memory. An entry larger than the whole budget
/// is refused outright instead of evicting everything else to make room.
final class ByteLruCache<K, V> {
  ByteLruCache({required this.maxBytes, required this.sizeOf}) : assert(maxBytes > 0);

  final int maxBytes;
  final int Function(K key, V value) sizeOf;
  final LinkedHashMap<K, _ByteLruEntry<V>> _entries = LinkedHashMap<K, _ByteLruEntry<V>>();
  int _bytes = 0;
  int _evictions = 0;

  int get bytes => _bytes;
  int get length => _entries.length;
  int get evictions => _evictions;

  V? get(K key) {
    final entry = _entries.remove(key);
    if (entry == null) return null;
    // Re-inserting on read is what makes the map least-recently-used rather
    // than first-in-first-out; `keys.first` is then always the coldest key.
    _entries[key] = entry;
    return entry.value;
  }

  void put(K key, V value) {
    final previous = _entries.remove(key);
    if (previous != null) _bytes -= previous.bytes;
    final bytes = sizeOf(key, value).clamp(0, maxBytes + 1).toInt();
    if (bytes > maxBytes) {
      _evictions += previous == null ? 0 : 1;
      return;
    }
    _entries[key] = _ByteLruEntry<V>(value, bytes);
    _bytes += bytes;
    while (_bytes > maxBytes && _entries.isNotEmpty) {
      final oldestKey = _entries.keys.first;
      final removed = _entries.remove(oldestKey)!;
      _bytes -= removed.bytes;
      _evictions++;
    }
  }

  void clear() {
    _entries.clear();
    _bytes = 0;
  }
}

final class _ByteLruEntry<V> {
  const _ByteLruEntry(this.value, this.bytes);
  final V value;
  final int bytes;
}

/// Per-message streaming fan-out.
///
/// Ported from kelivo's `StreamingContentNotifier`. The store is a
/// `ChangeNotifier` and `Chat.touch()` calls `notifyListeners()`, which
/// rebuilds the entire `ChatPage` — every bubble in the history — once per
/// streamed chunk. Here each in-flight assistant message gets its own
/// [ValueNotifier] so only the one bubble listening to it repaints, and the
/// page only hears about a change when the *shape* of the transcript moves
/// (a message appended, a row added), not when a character arrives.
///
/// The signal is a monotonically increasing revision per message id. Consumers
/// compare the revision they painted against the current one, which keeps the
/// notifier payload allocation-free on the hot path.
class StreamBus {
  final Map<String, ValueNotifier<int>> _revs = <String, ValueNotifier<int>>{};

  /// Bumped when a message's content changed in a way that affects only that
  /// bubble's own pixels.
  ValueNotifier<int> revisionOf(String messageId) => _revs.putIfAbsent(messageId, () => ValueNotifier<int>(0));

  bool has(String messageId) => _revs.containsKey(messageId);

  void bump(String messageId) {
    final n = _revs[messageId];
    if (n == null) return;
    n.value = n.value + 1;
  }

  void drop(String messageId) {
    _revs.remove(messageId)?.dispose();
  }

  /// Retains the given ids and disposes everything else.
  void clear({Set<String> keep = const <String>{}}) {
    _revs.removeWhere((id, n) {
      if (keep.contains(id)) return false;
      n.dispose();
      return true;
    });
  }

  void dispose() {
    for (final n in _revs.values) {
      n.dispose();
    }
    _revs.clear();
  }
}

/// Accumulates streamed deltas without copying the growing prefix per chunk.
///
/// Ported from kelivo's `StreamTextBuffer`. The naive `m.text += delta` is
/// quadratic over a reply: every chunk allocates a string of the whole length
/// so far. Here the pending deltas sit in a [StringBuffer] and the concatenation
/// happens only when a reader actually asks for [value].
class StreamTextBuffer {
  StreamTextBuffer([this._snapshot = '']);

  String _snapshot;
  final StringBuffer _pending = StringBuffer();

  int get length => _snapshot.length + _pending.length;
  bool get isEmpty => length == 0;
  bool get isNotEmpty => !isEmpty;

  void add(String delta) {
    if (delta.isNotEmpty) _pending.write(delta);
  }

  String get value {
    if (_pending.isNotEmpty) {
      _snapshot = _snapshot.isEmpty ? _pending.toString() : '$_snapshot$_pending';
      _pending.clear();
    }
    return _snapshot;
  }

  set value(String text) {
    _snapshot = text;
    _pending.clear();
  }
}
