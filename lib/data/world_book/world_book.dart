import 'dart:math' as math;

// The world book: named books of lore entries, bound per persona, injected
// into the request only when their keywords fire.
//
// The shape follows SillyTavern's world info (keys, secondary keys,
// selective logic, constant entries, inclusion groups, @D positions), with
// three additions this project needs:
//
//   1. every book declares a [BookKind], which decides how the block is
//      worded when it reaches the model. A rule the model is told it must
//      obey is followed far more reliably than a rule dropped into an
//      undifferentiated wall of facts, which is the whole point of the book.
//   2. [WorldEntry.priority] plus a character budget in the injector keep a
//      big world from silently crowding the conversation out of the context.
//   3. [WorldEntry.aiEditable] lets the assistant slowly refine its own
//      sheet through a tool, the behaviour the old character card had, but
//      only for the entries that explicitly opt in.

/// How a book's block is framed when injected. The wording is what the model
/// reads, so it is part of the contract rather than decoration.
enum BookKind {
  /// No particular angle: background that is simply true.
  general,

  /// Places, factions, history, objects: the world that exists.
  facts,

  /// What must or must never happen. Framed as orders, because that is what
  /// they are; the model drifts less when a constraint is called one.
  rules,

  /// How to write and speak in this world.
  style,

  /// Who everyone is and how they address each other.
  relations,

  /// Where the conversation is happening right now.
  scenes;

  static BookKind of(String? raw) => values.firstWhere((e) => e.name == raw, orElse: () => general);
}

/// Where a fired entry lands in the request.
enum EntryPosition {
  /// Ahead of the character definition, so it survives a trimmed tail.
  beforeChar,

  /// Behind the character definition, ahead of the live state.
  afterChar,

  /// A turn in the history itself, [WorldEntry.depth] messages back.
  atDepth,

  /// The very end of the system prompt, the author's note slot: the last
  /// thing read before the conversation, so the closest to what is said next.
  bottomNote;

  static EntryPosition of(String? raw) => values.firstWhere((e) => e.name == raw, orElse: () => beforeChar);
}

/// Role of an `atDepth` turn. Providers without a system turn inside the
/// history demote it to a plain user turn, the same rule the persona card's
/// depth injection follows.
enum EntryRole { system, user, assistant;

  static EntryRole of(String? raw) => values.firstWhere((e) => e.name == raw, orElse: () => system);
}

/// How secondary keys modify a primary key hit, matching SillyTavern's
/// selectiveLogic 0..3 with readable names.
enum KeyLogic {
  /// Primary hits AND at least one secondary key hits.
  anySecondary,

  /// Primary hits AND no secondary key hits.
  notAnySecondary,

  /// Primary hits AND every secondary key hits.
  allSecondary,

  /// Primary hits AND not every secondary key hits.
  notAllSecondary;

  static KeyLogic of(String? raw) => values.firstWhere((e) => e.name == raw, orElse: () => anySecondary);
}

/// One piece of lore. An entry only reaches the model when its keys fire,
/// it is marked [constant], or it is pulled in by recursion.
class WorldEntry {
  WorldEntry({
    required this.id,
    this.comment = '',
    this.content = '',
    this.enabled = true,
    this.keys = const [],
    this.secondaryKeys = const [],
    this.logic = KeyLogic.anySecondary,
    this.probability = 1,
    this.caseSensitive = false,
    this.matchWholeWords = false,
    this.useRegex = false,
    this.constant = false,
    this.scanDepth = 0,
    this.position = EntryPosition.beforeChar,
    this.depth = 4,
    this.role = EntryRole.system,
    this.inclusionGroup = '',
    this.groupWeight = 100,
    this.priority = 0,
    this.aiEditable = false,
  });

  final String id;

  /// Label shown in the editor and in front of the content when injected.
  String comment;

  /// The body the model reads.
  String content;

  bool enabled;

  /// Primary keys. Any one of them firing counts as a hit.
  List<String> keys;

  /// Second gate on top of the primary hit, combined through [logic].
  List<String> secondaryKeys;

  KeyLogic logic;

  /// 0..1 chance a hit is kept. 1 always injects.
  double probability;

  bool caseSensitive;

  /// Whole words only, so "arc" does not fire inside "architect".
  bool matchWholeWords;

  bool useRegex;

  /// Always injected, keys or no keys. For the facts that must never be
  /// missing: who the character is, what world this is.
  bool constant;

  /// How many of the most recent messages are scanned, 0 means all of them.
  int scanDepth;

  EntryPosition position;

  /// Messages back from the newest one, for [EntryPosition.atDepth].
  int depth;

  EntryRole role;

  /// Entries sharing a group fire together as one: the member with the
  /// highest [groupWeight] wins and the rest are dropped, which is how a
  /// season or a relationship stage replaces an earlier one instead of
  /// stacking with it.
  String inclusionGroup;

  int groupWeight;

  /// Order among the survivors. Higher survives a tight budget.
  int priority;

  /// Whether the model may refine this entry itself through the world book
  /// tool. Off by default: a sheet the user wrote is the user's.
  bool aiEditable;

  bool get hasKeys => keys.any((k) => k.trim().isNotEmpty);

  /// Nothing can ever fire this entry, whatever its keys say.
  bool get isDormant => !enabled || (!constant && !hasKeys);

  /// Rough size used against the injector budget.
  int get budgetCost => content.length + comment.length + 8;

  WorldEntry copy({String? id}) => WorldEntry(
        id: id ?? this.id,
        comment: comment,
        content: content,
        enabled: enabled,
        keys: [...keys],
        secondaryKeys: [...secondaryKeys],
        logic: logic,
        probability: probability,
        caseSensitive: caseSensitive,
        matchWholeWords: matchWholeWords,
        useRegex: useRegex,
        constant: constant,
        scanDepth: scanDepth,
        position: position,
        depth: depth,
        role: role,
        inclusionGroup: inclusionGroup,
        groupWeight: groupWeight,
        priority: priority,
        aiEditable: aiEditable,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (comment.isNotEmpty) 'comment': comment,
        'content': content,
        'enabled': enabled,
        'keys': keys,
        if (secondaryKeys.isNotEmpty) 'secondaryKeys': secondaryKeys,
        if (logic != KeyLogic.anySecondary) 'logic': logic.name,
        if (probability != 1) 'probability': probability,
        if (caseSensitive) 'caseSensitive': true,
        if (matchWholeWords) 'matchWholeWords': true,
        if (useRegex) 'useRegex': true,
        if (constant) 'constant': true,
        if (scanDepth != 0) 'scanDepth': scanDepth,
        if (position != EntryPosition.beforeChar) 'position': position.name,
        if (position == EntryPosition.atDepth) 'depth': depth,
        if (position == EntryPosition.atDepth) 'role': role.name,
        if (inclusionGroup.trim().isNotEmpty) 'group': inclusionGroup,
        if (inclusionGroup.trim().isNotEmpty) 'groupWeight': groupWeight,
        if (priority != 0) 'priority': priority,
        if (aiEditable) 'aiEditable': true,
      };

  static WorldEntry fromJson(Map<String, dynamic> j) => WorldEntry(
        id: '${j['id'] ?? ''}',
        comment: '${j['comment'] ?? ''}',
        content: '${j['content'] ?? ''}',
        enabled: j['enabled'] as bool? ?? true,
        keys: [for (final e in (j['keys'] as List?) ?? const []) '$e'.trim()]..removeWhere((e) => e.isEmpty),
        secondaryKeys: [for (final e in (j['secondaryKeys'] as List?) ?? const []) '$e'.trim()]..removeWhere((e) => e.isEmpty),
        logic: KeyLogic.of(j['logic'] as String?),
        probability: ((j['probability'] as num?)?.toDouble() ?? 1).clamp(0.0, 1.0),
        caseSensitive: j['caseSensitive'] as bool? ?? false,
        matchWholeWords: j['matchWholeWords'] as bool? ?? false,
        useRegex: j['useRegex'] as bool? ?? false,
        constant: j['constant'] as bool? ?? false,
        scanDepth: (j['scanDepth'] as num?)?.toInt() ?? 0,
        position: EntryPosition.of(j['position'] as String?),
        depth: (j['depth'] as num?)?.toInt() ?? 4,
        role: EntryRole.of(j['role'] as String?),
        inclusionGroup: '${j['group'] ?? ''}',
        groupWeight: (j['groupWeight'] as num?)?.toInt() ?? 100,
        priority: (j['priority'] as num?)?.toInt() ?? 0,
        aiEditable: j['aiEditable'] as bool? ?? false,
      );
}

/// A named collection of entries. A persona binds `List<String>` of these.
class WorldBook {
  WorldBook({
    required this.id,
    required this.name,
    this.description = '',
    this.kind = BookKind.general,
    this.enabled = true,
    List<WorldEntry> entries = const [],
    this.createdAt = 0,
    this.updatedAt = 0,
  }) : entries = List.of(entries);

  final String id;
  String name;
  String description;
  BookKind kind;
  bool enabled;

  /// Owned and mutable: the editor page works on the list in place through
  /// the store, the same way the human settings pages do. The constructor
  /// copies the incoming list, so a book built from `const []` and one built
  /// from a literal are equally safe to add to.
  List<WorldEntry> entries;

  int createdAt;
  int updatedAt;

  int get liveEntries => entries.where((e) => e.enabled).length;

  bool get isEmpty => entries.isEmpty;

  WorldBook copy({List<WorldEntry>? entries}) => WorldBook(
        id: id,
        name: name,
        description: description,
        kind: kind,
        enabled: enabled,
        entries: entries ?? [for (final e in this.entries) e.copy()],
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  WorldEntry? entryById(String entryId) {
    for (final e in entries) {
      if (e.id == entryId) return e;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'kind': kind.name,
        'enabled': enabled,
        'entries': [for (final e in entries) e.toJson()],
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  static WorldBook fromJson(Map<String, dynamic> j) => WorldBook(
        id: '${j['id'] ?? ''}',
        name: '${j['name'] ?? ''}',
        description: '${j['description'] ?? ''}',
        kind: BookKind.of(j['kind'] as String?),
        enabled: j['enabled'] as bool? ?? true,
        entries: [for (final e in (j['entries'] as List?) ?? const <WorldEntry>[]) WorldEntry.fromJson(Map<String, dynamic>.from(e as Map))],
        createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
        updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
      );
}

/// One entry that fired, with the book it came from, which is what the
/// injector hands the store.
class WorldHit {
  const WorldHit(this.book, this.entry);

  final WorldBook book;
  final WorldEntry entry;

  bool get constant => entry.constant;

  @override
  bool operator ==(Object other) => other is WorldHit && other.entry.id == entry.id && other.book.id == book.id;

  @override
  int get hashCode => Object.hash(book.id, entry.id);
}

/// Everything that fired for one request, sorted into the slots the request
/// has room for.
class WorldContext {
  WorldContext({
    this.beforeChar = const [],
    this.afterChar = const [],
    this.bottomNote = const [],
    this.atDepth = const [],
  });

  final List<WorldHit> beforeChar;
  final List<WorldHit> afterChar;
  final List<WorldHit> bottomNote;
  final List<WorldHit> atDepth;

  bool get isEmpty => beforeChar.isEmpty && afterChar.isEmpty && bottomNote.isEmpty && atDepth.isEmpty;

  List<WorldHit> of(EntryPosition p) => switch (p) {
        EntryPosition.beforeChar => beforeChar,
        EntryPosition.afterChar => afterChar,
        EntryPosition.bottomNote => bottomNote,
        EntryPosition.atDepth => atDepth,
      };

  int get totalChars => [
        for (final slot in [beforeChar, afterChar, bottomNote, atDepth]) for (final h in slot) h.entry.budgetCost
      ].fold(0, (a, b) => a + b);

  /// The system prompt text for one slot. Empty when nothing fired there.
  String textFor(EntryPosition p) => worldBlock(of(p));

  /// The depth turns, one per hit, ready to splice into the history.
  List<ChatTurnSpec> turns() => [
        for (final h in atDepth)
          ChatTurnSpec(
            roleName: switch (h.entry.role) {
              EntryRole.user => 'user',
              EntryRole.assistant => 'assistant',
              EntryRole.system => 'system',
            },
            text: '[World book: ${h.book.name}${h.entry.comment.isEmpty ? '' : ' / ${h.entry.comment}'}]\n${h.entry.content}',
            depth: h.entry.depth,
          ),
      ];
}

/// A depth turn before it becomes a provider turn: the store already owns
/// ChatTurn, and the injector has no reason to import the provider layer.
class ChatTurnSpec {
  const ChatTurnSpec({required this.roleName, required this.text, this.depth = 4});

  final String roleName;
  final String text;

  /// Messages back from the newest one, as the entry configured it.
  final int depth;
}

/// The header each book kind injects under. Wording matters: a rule framed
/// as an order is followed far more often than one buried in facts.
String kindHeader(BookKind k) => switch (k) {
      BookKind.general => 'WORLD BOOK (background established for this world. Treat it as true and stay consistent with it.)',
      BookKind.facts => 'WORLD FACTS (established background. Treat every line as true.)',
      BookKind.rules => 'WORLD RULES (obey strictly. Violating these makes the reply wrong, not merely less nice.)',
      BookKind.style => 'WORLD STYLE GUIDE (how to write, speak and carry yourself in this world.)',
      BookKind.relations => 'RELATIONSHIP MAP (who everyone is, their stance toward the user, and how they address each other.)',
      BookKind.scenes => 'SCENE (the setting of this conversation. Ground the reply in these concrete details.)',
    };

/// Renders fired hits as one block, grouped per book under its kind header.
///
/// The book name and each entry comment stay in the text on purpose: a line
/// the model can attribute ("the Winter Court says...") is anchored far
/// better than an anonymous one, and it makes an injected fact debuggable
/// for the user reading the trace.
String worldBlock(List<WorldHit> hits) {
  if (hits.isEmpty) return '';
  final byKind = <BookKind, Map<String, List<WorldEntry>>>{};
  for (final h in hits) {
    byKind.putIfAbsent(h.book.kind, () => <String, List<WorldEntry>>{}).putIfAbsent(h.book.name, () => <WorldEntry>[]).add(h.entry);
  }
  // the order of the enum doubles as the order of reading: rules first, the
  // scene last, so the freshest context sits closest to the conversation
  final ordered = BookKind.values.where(byKind.containsKey);
  final out = <String>[];
  for (final k in ordered) {
    final books = byKind[k]!;
    final b = StringBuffer('# ${kindHeader(k)}');
    for (final name in books.keys) {
      final es = books[name]!;
      final sorted = [...es]..sort((a, b2) => b2.priority.compareTo(a.priority));
      b.write('\n## $name');
      for (final e in sorted) {
        final label = e.comment.trim().isEmpty ? '' : '[${e.comment.trim()}] ';
        b.write('\n- $label${e.content.trim()}');
      }
    }
    out.add(b.toString().trimRight());
  }
  return out.join('\n\n');
}

/// Character-sized budget estimate: roughly four characters per token, the
/// usual english rule of thumb, rounded up on purpose. A budget is a guard
/// against a runaway world, not a metering device, so one shared number is
/// enough and a tokenizer call per request would be waste.
int worldBudget(int tokens) => math.max(256, tokens * 4);
