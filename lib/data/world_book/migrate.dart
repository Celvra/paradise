import 'world_book.dart';

// The one-time move of the old per chat character card into a world book.
//
// The card lived at `chat.human.card` and was injected as one block by the
// humanize prompt, which is why it only ever worked while humanize was on
// and why nothing outside the deepest settings page could reach it. Its
// fields become entries of a book bound to the persona, where the same
// content is editable, shareable across roles, and applies in every reply
// mode.
//
// Everything the card carried comes across. The three stage addresses are
// the one deliberate change: they were stage-aware on the old side (exactly
// one of the three was injected, picked by the relationship stage) and the
// world book has no stage concept, so they arrive as a single entry that
// spells the progression out. The model reads the relationship stage from
// its own state block either way, and seeing how the address changes with
// closeness is more material to play with than the single current line.

/// The plain text fields, in the order the old card showed them.
const _textFields = [
  ('speechStyle', 'Speaking style'),
  ('values', 'Values'),
  ('taboos', 'Taboos'),
];

class LegacyCardSheet {
  const LegacyCardSheet._();

  /// Whether [raw] carries anything worth migrating. Missing, malformed and
  /// all-empty cards all read as nothing to do.
  static bool isEmpty(Map<String, dynamic>? raw) {
    if (raw == null) return true;
    for (final (key, _) in _textFields) {
      if (_text(raw[key]).isNotEmpty) return false;
    }
    final catchphrases = raw['catchphrases'];
    if (catchphrases is List && catchphrases.any((e) => '$e'.trim().isNotEmpty)) return false;
    return _addressProgression(raw) == null;
  }

  /// The entries [raw] becomes. [newEntryId] mints an id per entry, which the
  /// store owns so ids stay unique across imports and migrations alike.
  ///
  /// Every entry is constant: the card was always injected, so an entry that
  /// suddenly needed a keyword to appear would quietly change how the role
  /// plays. The user can key them later; the migration only moves data.
  static List<WorldEntry> entries(Map<String, dynamic>? raw, {required String Function() newEntryId}) {
    if (raw == null) return const [];
    final out = <WorldEntry>[];

    void add(String comment, String content) {
      final body = content.trim();
      if (body.isEmpty) return;
      out.add(WorldEntry(
        id: newEntryId(),
        comment: comment,
        content: body,
        constant: true,
        keys: const [],
        position: EntryPosition.beforeChar,
        priority: out.length,
      ));
    }

    // catchphrases carry the sparing-use note the old prompt line had; the
    // framing is part of the instruction, so it travels with the data
    final catchphrases = raw['catchphrases'];
    if (catchphrases is List) {
      final list = [for (final e in catchphrases) '$e'.trim()]..removeWhere((e) => e.isEmpty);
      add('Catchphrases (use sparingly, not every message)', list.join(' / '));
    }

    for (final (key, comment) in _textFields) {
      if (key == 'taboos') {
        // the old injection prefixed the prohibition for the model
        add(comment, 'Never do or say: ${_text(raw[key])}');
        continue;
      }
      add(comment, _text(raw[key]));
    }

    final addresses = _addressProgression(raw);
    if (addresses != null) {
      out.add(WorldEntry(
        id: newEntryId(),
        comment: 'Address (how you call the user, by closeness)',
        content: addresses,
        constant: true,
        keys: const [],
        position: EntryPosition.beforeChar,
        priority: out.length,
      ));
    }
    return out;
  }

  /// The three addresses as one progression, or null when the card set none.
  static String? _addressProgression(Map<String, dynamic> raw) {
    final stranger = _text(raw['addressStranger']);
    final acquaintance = _text(raw['addressAcquaintance']);
    final close = _text(raw['addressClose']);
    if (stranger.isEmpty && acquaintance.isEmpty && close.isEmpty) return null;
    final b = StringBuffer('How you address the user changes with closeness:');
    void line(String stage, String value) {
      if (value.isNotEmpty) b.write('\n- $stage: $value');
    }

    line('stranger', stranger);
    line('acquaintance', acquaintance);
    line('close', close);
    return b.toString();
  }

  static String _text(Object? v) => v is String ? v.trim() : '';
}
