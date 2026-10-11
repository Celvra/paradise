import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/anim.dart';
import '../core/overlays.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/store.dart';
import '../data/world_book/injector.dart';
import '../data/world_book/world_book.dart';
import '../data/world_book/world_import.dart';
import '../data/world_book/world_store.dart';
import '../l10n/x.dart';
import 'ai_widgets.dart';
import 'human_pages.dart' show hAsk, hOpen;
import 'tg_cells.dart';

// The world book pages: books, their entries, the per role binding and a
// sandbox that shows what a given conversation would pull in.
//
// Everything is built from the same Telegram cells the rest of settings
// uses, so the pages feel like the app rather than like a bolted on form.
// Edits apply as they are made, the way the humanize settings pages do: a
// world book is small data, and a half typed entry that is lost to a back
// gesture is a bug report nobody can reproduce.

/// Entry point, from settings and from a role's own pages.
void openWorldBooks(BuildContext c) => hOpen(c, const WorldBooksPage());

/// The enum labels. They live in dart rather than in the arb files because
/// they are a closed set over an enum, and one message per enum value would
/// be 13 methods that all say nothing the switch does not say already.
String wbKindLabel(AppLocalizations l, BookKind k) => switch (k) {
      BookKind.general => l.worldBookKindLabelGeneral,
      BookKind.facts => l.worldBookKindLabelFacts,
      BookKind.rules => l.worldBookKindLabelRules,
      BookKind.style => l.worldBookKindLabelStyle,
      BookKind.relations => l.worldBookKindLabelRelations,
      BookKind.scenes => l.worldBookKindLabelScenes,
    };

String wbPositionLabel(AppLocalizations l, EntryPosition p) => switch (p) {
      EntryPosition.beforeChar => l.worldBookPositionLabelBeforeChar,
      EntryPosition.afterChar => l.worldBookPositionLabelAfterChar,
      EntryPosition.atDepth => l.worldBookPositionLabelAtDepth,
      EntryPosition.bottomNote => l.worldBookPositionLabelBottomNote,
    };

String wbPositionSub(AppLocalizations l, EntryPosition p) => switch (p) {
      EntryPosition.beforeChar => l.worldBookPositionSubBeforeChar,
      EntryPosition.afterChar => l.worldBookPositionSubAfterChar,
      EntryPosition.atDepth => l.worldBookPositionSubAtDepth,
      EntryPosition.bottomNote => l.worldBookPositionSubBottomNote,
    };

String wbLogicLabel(AppLocalizations l, KeyLogic k) => switch (k) {
      KeyLogic.anySecondary => l.worldBookLogicLabelAnySecondary,
      KeyLogic.notAnySecondary => l.worldBookLogicLabelNotAnySecondary,
      KeyLogic.allSecondary => l.worldBookLogicLabelAllSecondary,
      KeyLogic.notAllSecondary => l.worldBookLogicLabelNotAllSecondary,
    };

String wbLogicSub(AppLocalizations l, KeyLogic k) => switch (k) {
      KeyLogic.anySecondary => l.worldBookLogicSubAnySecondary,
      KeyLogic.notAnySecondary => l.worldBookLogicSubNotAnySecondary,
      KeyLogic.allSecondary => l.worldBookLogicSubAllSecondary,
      KeyLogic.notAllSecondary => l.worldBookLogicSubNotAllSecondary,
    };

String wbRoleLabel(AppLocalizations l, EntryRole r) => switch (r) {
      EntryRole.system => l.worldBookRoleLabelSystem,
      EntryRole.user => l.worldBookRoleLabelUser,
      EntryRole.assistant => l.worldBookRoleLabelAssistant,
    };

/// Settings row subtitle: how much world is loaded.
String worldBookSummary(Store st, AppLocalizations l) {
  if (st.worldBooks.books.isEmpty) return l.worldBookEmpty;
  var entries = 0;
  var on = 0;
  for (final b in st.worldBooks.books) {
    entries += b.entries.length;
    if (b.enabled) on++;
  }
  return l.worldBookSummary(on, entries);
}

// ------------------------------------------------------------------ picker

/// Multi-select for the role binding, mirroring the skill picker. Returns
/// null when cancelled, otherwise the new list (possibly empty).
Future<List<String>?> pickWorldBooks(BuildContext context, List<String>? current) async {
  final picked = await Navigator.of(context).push<List<String>>(TgRoute(
    builder: (_) => WorldBookPickerPage(selected: current == null ? <String>[] : [...current]),
  ));
  return picked;
}

class WorldBookPickerPage extends StatefulWidget {
  const WorldBookPickerPage({super.key, required this.selected});
  final List<String> selected;

  @override
  State<WorldBookPickerPage> createState() => _WorldBookPickerState();
}

class _WorldBookPickerState extends State<WorldBookPickerPage> {
  late Set<String> _ids = widget.selected.toSet();

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final st = Store.of(context);
    final mq = MediaQuery.of(context);
    return TgSettingsPage(
      title: l.worldBookBindPicker,
      builder: (c, _) {
        final p = c.p;
        return Stack(children: [
          ListenableBuilder(
            listenable: st.worldBooks,
            builder: (c, _) {
              final all = st.worldBooks.books;
              return ListView(
                physics: const ClampingScrollPhysics(),
                // the button is pinned below, so the list stops above it
                padding: EdgeInsets.only(bottom: mq.padding.bottom + 96),
                children: [
                  if (all.isEmpty)
                    TgSection(footer: l.worldBookEmptyBody, children: [
                      TgTextCell(title: l.worldBookEmpty, divider: false),
                    ]),
                  // one card for the whole list, the way every other picker in
                  // the app reads: a section per book made the page explode into
                  // a stack of floating rows with gaps between them
                  if (all.isNotEmpty)
                    TgSection(footer: l.worldBookBindSub, children: [
                      for (var i = 0; i < all.length; i++)
                        TgCheckCell(
                          icon: Ic.book,
                          title: all[i].name,
                          subtitle: _bookSub(c, st.worldBooks, all[i]),
                          value: _ids.contains(all[i].id),
                          divider: i == all.length - 1,
                          onChanged: (v) => setState(() {
                            if (v) {
                              _ids.add(all[i].id);
                            } else {
                              _ids.remove(all[i].id);
                            }
                          }),
                        ),
                    ]),
                ],
              );
            },
          ),
          // the large bottom button, the way the persona card ends: pinned,
          // over a fade, so a short list does not leave it floating mid page
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, mq.padding.bottom + 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [p.gray.withAlpha(0), p.gray, p.gray],
                  stops: const [0, .35, 1],
                ),
              ),
              child: TgButton(
                label: l.actionSave,
                onTap: () => Navigator.of(context).pop(_ids.toList()),
              ),
            ),
          ),
        ]);
      },
    );
  }

  String _bookSub(BuildContext c, WorldStore store, WorldBook b) {
    final l = c.l;
    return '${l.worldBookEntries(b.entries.length)} · ${wbKindLabel(l, b.kind)}';
  }
}

// -------------------------------------------------------------- book list

class WorldBooksPage extends StatelessWidget {
  const WorldBooksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final st = Store.of(context);
    return TgSettingsPage(
      title: l.worldBookTitle,
      actions: [
        Tap(
          scale: .88,
          onTap: () => _addMenu(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TgIcon(Ic.plus, color: context.p.title, size: 24),
          ),
        ),
      ],
      builder: (c, _) => ListenableBuilder(
        listenable: st.worldBooks,
        builder: (c, _) {
          final store = st.worldBooks;
          final books = store.books;
          return ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              TgSection(footer: l.worldBookIntro, children: [
                if (books.isEmpty)
                  TgTextCell(title: l.worldBookEmpty, subtitle: l.worldBookEmptyBody, divider: false),
                for (var i = 0; i < books.length; i++)
                  TgTextCell(
                    title: books[i].name,
                    subtitle: _sub(c, store, books[i]),
                    icon: Ic.book,
                    trailing: TgSwitch(
                      value: books[i].enabled,
                      onChanged: (v) => st.worldBooks.setEnabled(books[i].id, v),
                    ),
                    divider: i == books.length - 1,
                    onTap: () => hOpen(c, WorldBookPage(bookId: books[i].id)),
                  ),
              ]),
              TgSection(
                header: l.worldBookSettingsHeader,
                // an unlimited budget swaps the explanation for the warning
                // right where the choice is shown
                footer: store.budgetUnlimited ? l.worldBookBudgetUnlimitedNote : l.worldBookBudgetFooter,
                children: [
                  TgTextCell(
                    icon: Ic.textSize,
                    title: l.worldBookBudget,
                    subtitle: store.budgetUnlimited ? l.worldBookBudgetUnlimited : l.worldBookBudgetValue(store.budgetK),
                    value: l.actionEdit,
                    divider: false,
                    onTap: () => _pickBudget(c),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  String _sub(BuildContext c, WorldStore store, WorldBook b) {
    final l = c.l;
    return '${l.worldBookEntries(b.entries.length)} · ${wbKindLabel(l, b.kind)}';
  }

  Future<void> _addMenu(BuildContext context) async {
    final l = context.l;
    final how = await showTgDialog<String>(
      context,
      title: l.worldBookAdd,
      actions: [
        DialogAction(l.actionCancel, null),
        DialogAction(l.worldBookAddNew, 'new'),
        DialogAction(l.worldBookAddPaste, 'paste'),
        DialogAction(l.worldBookAddFile, 'file'),
      ],
    );
    if (how == null || !context.mounted) return;
    if (how == 'new') {
      await _create(context);
    } else if (how == 'paste') {
      await _importPaste(context);
    } else {
      await _importFile(context);
    }
  }

  Future<void> _create(BuildContext context) async {
    final l = context.l;
    final name = await hAsk(context, l.worldBookName, l.worldBookNameHint, initial: l.worldBookDefaultName);
    if (name == null || !context.mounted) return;
    final book = await Store.of(context).worldBooks.create(name: name.trim());
    if (!context.mounted) return;
    hOpen(context, WorldBookPage(bookId: book.id));
  }

  Future<void> _importPaste(BuildContext context) async {
    final l = context.l;
    final text = await hAsk(context, l.worldBookImportTitle, l.worldBookImportHint, lines: 12);
    if (text == null || text.trim().isEmpty || !context.mounted) return;
    try {
      final books = await WorldIo.importInto(Store.of(context).worldBooks, text);
      if (!context.mounted) return;
      showBulletin(context, l.worldBookImported(books.length));
      if (books.isNotEmpty) hOpen(context, WorldBookPage(bookId: books.first.id));
    } on FormatException catch (e) {
      if (context.mounted) showBulletin(context, e.message);
    } catch (_) {
      if (context.mounted) showBulletin(context, l.worldBookInvalid);
    }
  }

  Future<void> _importFile(BuildContext context) async {
    final l = context.l;
    String? raw;
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['json']);
      final path = files.firstOrNull?.path;
      if (path != null) raw = await File(path).readAsString();
    } catch (_) {}
    if (raw == null || raw.trim().isEmpty || !context.mounted) return;
    try {
      final books = await WorldIo.importInto(Store.of(context).worldBooks, raw);
      if (!context.mounted) return;
      showBulletin(context, l.worldBookImported(books.length));
      if (books.isNotEmpty) hOpen(context, WorldBookPage(bookId: books.first.id));
    } catch (e) {
      if (context.mounted) showBulletin(context, e is FormatException ? e.message : l.worldBookInvalid);
    }
  }

  Future<void> _pickBudget(BuildContext context) async {
    final l = context.l;
    final st = Store.of(context).worldBooks;
    const options = [1, 2, 4, 8, 16, 32, 64, WorldStore.unlimited];
    final v = await showAiSelect<int>(
      context,
      title: l.worldBookBudget,
      value: st.budgetK,
      options: [
        for (final k in options)
          (
            value: k,
            label: k == WorldStore.unlimited ? l.worldBookBudgetUnlimited : l.worldBookBudgetValue(k),
            // the option carries its own warning: a world with no cap can
            // crowd the context and pull the role off its own story
            sub: k == WorldStore.unlimited ? l.worldBookBudgetUnlimitedNote : null,
          ),
      ],
    );
    if (v != null) st.setBudget(v);
  }
}

// ------------------------------------------------------------- book detail

class WorldBookPage extends StatelessWidget {
  const WorldBookPage({super.key, required this.bookId});
  final String bookId;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final st = Store.of(context);
    return TgSettingsPage(
      title: l.worldBookTitle,
      actions: [
        Tap(
          scale: .88,
          onTap: () => hOpen(context, WorldSandboxPage(bookId: bookId)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TgIcon(Ic.eye, color: context.p.title, size: 24),
          ),
        ),
      ],
      builder: (c, _) => ListenableBuilder(
        listenable: st.worldBooks,
        builder: (c, _) {
          final book = st.worldBooks.byId(bookId);
          if (book == null) {
            return ListView(children: [
              TgSection(children: [TgTextCell(title: l.worldBookGone, divider: false)]),
            ]);
          }
          final entries = [...book.entries]..sort((a, b) => a.priority.compareTo(b.priority));
          return ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              TgSection(header: l.worldBookBookHeader, footer: l.worldBookBookFooter, children: [
                TgTextCell(
                  title: book.name,
                  subtitle: book.description.isEmpty ? null : book.description,
                  icon: Ic.pencil,
                  divider: true,
                  onTap: () => _rename(c, book),
                ),
                TgTextCell(
                  icon: Ic.palette,
                  title: l.worldBookKind,
                  subtitle: l.worldBookKindHint,
                  value: wbKindLabel(l, book.kind),
                  divider: true,
                  onTap: () => _pickKind(c, book),
                ),
                TgCheckCell(
                  icon: Ic.check,
                  title: l.worldBookEnabled,
                  value: book.enabled,
                  divider: false,
                  onChanged: (v) => st.worldBooks.setEnabled(book.id, v),
                ),
              ]),
              TgSection(
                header: l.worldBookEntriesHeader,
                footer: l.worldBookEntriesFooter(book.entries.length),
                children: [
                  if (entries.isEmpty)
                    TgTextCell(title: l.worldBookEntriesEmpty, subtitle: l.worldBookEntriesEmptyBody, divider: true),
                  for (var i = 0; i < entries.length; i++)
                    TgTextCell(
                      title: entries[i].comment.trim().isEmpty ? l.worldBookEntryUntitled : entries[i].comment.trim(),
                      subtitle: _entrySub(c, entries[i]),
                      icon: entries[i].constant ? Ic.pin : Ic.list,
                      divider: i == entries.length - 1,
                      trailing: TgSwitch(
                        value: entries[i].enabled,
                        onChanged: (v) {
                          final e = entries[i].copy()..enabled = v;
                          st.worldBooks.upsertEntry(book.id, e);
                        },
                      ),
                      onTap: () => hOpen(c, WorldEntryEditorPage(bookId: book.id, entryId: entries[i].id)),
                      onLongPress: () => _deleteEntry(c, book, entries[i]),
                    ),
                  TgTextCell(
                    title: l.worldBookEntryAdd,
                    icon: Ic.plus,
                    divider: false,
                    onTap: () => _addEntry(c, book.id),
                  ),
                ],
              ),
              TgSection(header: l.worldBookDataHeader, children: [
                TgTextCell(
                  title: l.humanExport,
                  icon: Ic.share,
                  subtitle: l.worldBookExportSub,
                  divider: true,
                  onTap: () => _export(c, book),
                ),
                TgTextCell(
                  title: l.worldBookDelete,
                  icon: Ic.trash,
                  color: c.p.danger,
                  divider: false,
                  onTap: () => _deleteBook(c, book),
                ),
              ]),
            ],
          );
        },
      ),
    );
  }

  String _entrySub(BuildContext c, WorldEntry e) {
    final l = c.l;
    final keys = e.keys.isEmpty ? l.worldBookKeysNone : e.keys.join(', ');
    final pos = wbPositionLabel(l, e.position);
    final flags = <String>[
      if (e.constant) l.worldBookConstant,
      if (e.useRegex) l.worldBookEntryRegex,
      if (e.matchWholeWords) l.worldBookEntryWholeWords,
      if (e.aiEditable) l.worldBookEntryAiEditable,
    ];
    final tail = flags.isEmpty ? '' : ' · ${flags.join(' · ')}';
    return '$keys · $pos$tail';
  }

  Future<void> _rename(BuildContext c, WorldBook book) async {
    final l = c.l;
    final name = await hAsk(c, l.worldBookName, l.worldBookNameHint, initial: book.name);
    if (name == null || name.trim().isEmpty) return;
    book.name = name.trim();
    await Store.of(c).worldBooks.put(book);
  }

  Future<void> _pickKind(BuildContext c, WorldBook book) async {
    final l = c.l;
    final v = await showAiSelect<String>(
      c,
      title: l.worldBookKind,
      value: book.kind.name,
      options: [
        for (final k in BookKind.values) (value: k.name, label: wbKindLabel(l, k), sub: wbKindLabel(l, k)),
      ],
    );
    if (v == null) return;
    book.kind = BookKind.of(v);
    await Store.of(c).worldBooks.put(book);
  }

  Future<void> _addEntry(BuildContext c, String bookId) async {
    final l = c.l;
    final st = Store.of(c).worldBooks;
    final tpl = await showAiSelect<String>(
      c,
      title: l.worldBookEntryAdd,
      value: 'blank',
      options: [
        (value: 'blank', label: l.worldBookTplBlank, sub: l.worldBookTplBlankSub),
        (value: 'place', label: l.worldBookTplPlace, sub: l.worldBookTplPlaceSub),
        (value: 'item', label: l.worldBookTplItem, sub: l.worldBookTplItemSub),
        (value: 'rule', label: l.worldBookTplRule, sub: l.worldBookTplRuleSub),
        (value: 'relation', label: l.worldBookTplRelation, sub: l.worldBookTplRelationSub),
        (value: 'style', label: l.worldBookTplStyle, sub: l.worldBookTplStyleSub),
        (value: 'address', label: l.worldBookTplAddress, sub: l.worldBookTplAddressSub),
      ],
    );
    if (tpl == null) return;
    final priority = st.byId(bookId)?.entries.length ?? 0;
    final e = _template(tpl, st.newEntryId(), priority, l);
    await st.upsertEntry(bookId, e);
    if (!c.mounted) return;
    hOpen(c, WorldEntryEditorPage(bookId: bookId, entryId: e.id));
  }

  /// The seven starting points. Each seeds the fields that matter for that
  /// kind of lore so a new entry is one step from done rather than a blank
  /// form, which is what makes a world book worth filling in.
  WorldEntry _template(String tpl, String id, int priority, AppLocalizations l) {
    switch (tpl) {
      case 'place':
        return WorldEntry(id: id, comment: l.worldBookTplPlace, keys: const [], position: EntryPosition.beforeChar, priority: priority);
      case 'item':
        return WorldEntry(id: id, comment: l.worldBookTplItem, keys: const [], position: EntryPosition.beforeChar, priority: priority);
      case 'rule':
        return WorldEntry(id: id, comment: l.worldBookTplRule, content: 'Never do or say: ', keys: const [], position: EntryPosition.beforeChar, priority: priority);
      case 'relation':
        return WorldEntry(id: id, comment: l.worldBookTplRelation, keys: const [], position: EntryPosition.beforeChar, priority: priority);
      case 'style':
        return WorldEntry(id: id, comment: l.worldBookTplStyle, constant: true, keys: const [], position: EntryPosition.afterChar, priority: priority);
      case 'address':
        return WorldEntry(
          id: id,
          comment: l.worldBookTplAddressComment,
          content: 'How you address the user changes with closeness:\n- stranger: \n- acquaintance: \n- close: ',
          constant: true,
          keys: const [],
          position: EntryPosition.beforeChar,
          priority: priority,
        );
      case _:
        return WorldEntry(id: id, keys: const [], position: EntryPosition.beforeChar, priority: priority);
    }
  }

  Future<void> _deleteEntry(BuildContext c, WorldBook book, WorldEntry e) async {
    final l = c.l;
    final r = await showTgDialog<bool>(
      c,
      title: l.worldBookEntryDelete,
      message: e.comment.trim(),
      actions: [
        DialogAction(l.actionCancel, false),
        DialogAction(l.actionDelete, true, danger: true),
      ],
    );
    if (r == true) Store.of(c).worldBooks.removeEntry(book.id, e.id);
  }

  Future<void> _deleteBook(BuildContext c, WorldBook book) async {
    final l = c.l;
    final r = await showTgDialog<bool>(
      c,
      title: l.worldBookDelete,
      message: l.worldBookDeleteMessage(book.name),
      actions: [
        DialogAction(l.actionCancel, false),
        DialogAction(l.actionDelete, true, danger: true),
      ],
    );
    if (r != true) return;
    final st = Store.of(c);
    await st.worldBooks.remove(book.id);
    if (c.mounted) Navigator.of(c).pop();
  }

  Future<void> _export(BuildContext c, WorldBook book) async {
    final l = c.l;
    final json = WorldIo.exportAll([book]);
    unawaited(Clipboard.setData(ClipboardData(text: json)));
    try {
      final saved = await FilePicker.saveFile(
        fileName: '${book.name}-${_stamp()}.json',
        bytes: utf8.encode(json),
        mimeType: 'application/json',
        allowedExtensions: const ['json'],
        dialogTitle: l.humanExport,
      );
      // null is the user backing out, not a failure worth a bulletin
      if (saved == null) return;
      if (c.mounted) showBulletin(c, l.humanSavedCopied);
    } catch (_) {
      if (c.mounted) showBulletin(c, l.humanCopiedClipboard);
    }
  }

  static String _stamp() {
    final d = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}-${two(d.hour)}${two(d.minute)}';
  }
}

// ---------------------------------------------------------- entry editor

/// One entry, every field. Changes apply as they are made rather than on a
/// save button: the entry is live data shared with the running chat, and a
/// discarded half edit is worse than an edit that was applied early.
class WorldEntryEditorPage extends StatefulWidget {
  const WorldEntryEditorPage({super.key, required this.bookId, this.entryId = ''});
  final String bookId;
  final String entryId;

  @override
  State<WorldEntryEditorPage> createState() => _WorldEntryEditorState();
}

class _WorldEntryEditorState extends State<WorldEntryEditorPage> {
  late WorldEntry _draft;
  late final TextEditingController _comment;
  late final TextEditingController _content;
  late final TextEditingController _group;

  @override
  void initState() {
    super.initState();
    // Store.read rather than Store.of: initState must not register an
    // inherited dependency, and the draft needs the entry it came in for
    // before the first build
    _draft = Store.read(context).worldBooks.byId(widget.bookId)?.entryById(widget.entryId)?.copy() ??
        WorldEntry(id: widget.entryId);
    _comment = TextEditingController(text: _draft.comment);
    _content = TextEditingController(text: _draft.content);
    _group = TextEditingController(text: _draft.inclusionGroup);
    // typed text lands in the draft as it is typed, the same rule the rest
    // of these settings pages follow: no save button to forget to press
    _comment.addListener(() => _apply((e) => e.comment = _comment.text));
    _content.addListener(() => _apply((e) => e.content = _content.text));
    _group.addListener(() => _apply((e) => e.inclusionGroup = _group.text));
  }

  @override
  void dispose() {
    _comment.dispose();
    _content.dispose();
    _group.dispose();
    super.dispose();
  }

  void _apply(void Function(WorldEntry e) change) {
    change(_draft);
    Store.of(context).worldBooks.upsertEntry(widget.bookId, _draft);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final p = context.p;
    final book = Store.of(context).worldBooks.byId(widget.bookId);
    if (book == null) return const SizedBox.shrink();
    return TgSettingsPage(
      title: l.worldBookEntryTitle,
      builder: (c, _) => ListView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          TgSection(header: l.worldBookEntryBodyHeader, footer: l.worldBookEntryBodyFooter, children: [
            TgEditCell(controller: _comment, hint: l.worldBookEntryCommentHint, label: l.worldBookEntryComment, max: 60),
            TgEditCell(
              controller: _content,
              hint: l.worldBookEntryContentHint,
              label: l.worldBookEntryContent,
              lines: 8,
              max: 8000,
            ),
          ]),
          _KeysField(
            title: l.worldBookEntryKeys,
            hint: l.worldBookEntryKeysHint,
            keys: _draft.keys,
            onChange: (v) => _apply((e) => e.keys = v),
          ),
          _KeysField(
            title: l.worldBookEntrySecondary,
            hint: l.worldBookEntrySecondaryHint,
            keys: _draft.secondaryKeys,
            onChange: (v) => _apply((e) => e.secondaryKeys = v),
          ),
          TgSection(header: l.worldBookEntryTriggerHeader, footer: l.worldBookEntryTriggerFooter, children: [
            TgTextCell(
              icon: Ic.key,
              title: l.worldBookEntryLogic,
              value: wbLogicLabel(l, _draft.logic),
              divider: _draft.secondaryKeys.isEmpty,
              onTap: () async {
                final v = await showAiSelect<String>(
                  c,
                  title: l.worldBookEntryLogic,
                  value: _draft.logic.name,
                  options: [
                    for (final k in KeyLogic.values) (value: k.name, label: wbLogicLabel(l, k), sub: wbLogicSub(l, k)),
                  ],
                );
                if (v != null) _apply((e) => e.logic = KeyLogic.of(v));
              },
            ),
            if (_draft.secondaryKeys.isNotEmpty)
              TgTextCell(
                icon: Ic.check2,
                title: l.worldBookEntryProbability,
                value: '${(_draft.probability * 100).round()}%',
                divider: true,
                onTap: () async {
                  final v = await showAiSelect<int>(
                    c,
                    title: l.worldBookEntryProbability,
                    value: (_draft.probability * 100).round(),
                    options: [
                      for (final pct in const [100, 75, 50, 25, 10]) (value: pct, label: '$pct%', sub: null),
                    ],
                  );
                  if (v != null) _apply((e) => e.probability = v / 100);
                },
              ),
            TgCheckCell(
              icon: Ic.textSize,
              title: l.worldBookEntryCaseSensitive,
              value: _draft.caseSensitive,
              divider: true,
              onChanged: (v) => _apply((e) => e.caseSensitive = v),
            ),
            TgCheckCell(
              icon: Ic.file,
              title: l.worldBookEntryWholeWords,
              value: _draft.matchWholeWords,
              divider: true,
              onChanged: (v) => _apply((e) => e.matchWholeWords = v),
            ),
            TgCheckCell(
              icon: Ic.fileCode,
              title: l.worldBookEntryRegex,
              value: _draft.useRegex,
              divider: false,
              onChanged: (v) => _apply((e) => e.useRegex = v),
            ),
          ]),
          TgSection(header: l.worldBookEntryWhenHeader, footer: l.worldBookEntryWhenFooter, children: [
            TgCheckCell(
              icon: Ic.pin,
              title: l.worldBookConstant,
              subtitle: l.worldBookConstantSub,
              value: _draft.constant,
              divider: true,
              onChanged: (v) => _apply((e) => e.constant = v),
            ),
            TgTextCell(
              icon: Ic.list,
              title: l.worldBookEntryScanDepth,
              value: _draft.scanDepth == 0 ? l.worldBookEntryScanAll : '${_draft.scanDepth}',
              divider: true,
              onTap: () async {
                final v = await showAiSelect<int>(
                  c,
                  title: l.worldBookEntryScanDepth,
                  value: _draft.scanDepth,
                  options: [
                    (value: 0, label: l.worldBookEntryScanAll, sub: null),
                    for (final n in const [2, 5, 10, 20, 40]) (value: n, label: '$n', sub: null),
                  ],
                );
                if (v != null) _apply((e) => e.scanDepth = v);
              },
            ),
            TgTextCell(
              icon: Ic.corner,
              title: l.worldBookEntryPosition,
              value: wbPositionLabel(l, _draft.position),
              divider: true,
              onTap: () async {
                final v = await showAiSelect<String>(
                  c,
                  title: l.worldBookEntryPosition,
                  value: _draft.position.name,
                  options: [
                    for (final k in EntryPosition.values) (
                      value: k.name,
                      label: wbPositionLabel(l, k),
                      sub: wbPositionSub(l, k)
                    ),
                  ],
                );
                if (v != null) _apply((e) => e.position = EntryPosition.of(v));
              },
            ),
            if (_draft.position == EntryPosition.atDepth) ...[
              TgTextCell(
                icon: Ic.list,
                title: l.worldBookEntryDepth,
                value: '${_draft.depth}',
                divider: true,
                onTap: () async {
                  final v = await showAiSelect<int>(
                    c,
                    title: l.worldBookEntryDepth,
                    value: _draft.depth,
                    options: [for (var n = 1; n <= 12; n++) (value: n, label: '$n', sub: null)],
                  );
                  if (v != null) _apply((e) => e.depth = v);
                },
              ),
              TgTextCell(
                icon: Ic.at,
                title: l.worldBookEntryRole,
                value: wbRoleLabel(l, _draft.role),
                divider: true,
                onTap: () async {
                  final v = await showAiSelect<String>(
                    c,
                    title: l.worldBookEntryRole,
                    value: _draft.role.name,
                    options: [
                      for (final k in EntryRole.values) (value: k.name, label: wbRoleLabel(l, k), sub: null),
                    ],
                  );
                  if (v != null) _apply((e) => e.role = EntryRole.of(v));
                },
              ),
            ],
          ]),
          TgSection(header: l.worldBookEntryStackHeader, footer: l.worldBookEntryStackFooter, children: [
            TgEditCell(controller: _group, hint: l.worldBookEntryGroupHint, label: l.worldBookEntryGroup, max: 40),
            TgTextCell(
              icon: Ic.minus,
              title: l.worldBookEntryGroupWeight,
              subtitle: l.worldBookEntryGroupWeightSub,
              value: '${_draft.groupWeight}',
              divider: _draft.inclusionGroup.trim().isEmpty,
              onTap: () async {
                final v = await showAiSelect<int>(
                  c,
                  title: l.worldBookEntryGroupWeight,
                  value: _draft.groupWeight,
                  options: [for (final w in const [0, 25, 50, 100, 150, 200]) (value: w, label: '$w', sub: null)],
                );
                if (v != null) _apply((e) => e.groupWeight = v);
              },
            ),
            // the weight only means something inside a group, so it hides
            // itself until there is a group to weigh against
            if (_draft.inclusionGroup.trim().isEmpty)
              TgTextCell(
                icon: Ic.list,
                title: l.worldBookEntryPriority,
                subtitle: l.worldBookEntryPrioritySub,
                value: '${_draft.priority}',
                divider: true,
                onTap: () async {
                  final v = await showAiSelect<int>(
                    c,
                    title: l.worldBookEntryPriority,
                    value: _draft.priority,
                    options: [for (var n = 0; n <= 20; n++) (value: n, label: '$n', sub: null)],
                  );
                  if (v != null) _apply((e) => e.priority = v);
                },
              ),
            TgCheckCell(
              icon: Ic.ai,
              title: l.worldBookEntryAiEditable,
              subtitle: l.worldBookEntryAiEditableSub,
              value: _draft.aiEditable,
              divider: false,
              onChanged: (v) => _apply((e) => e.aiEditable = v),
            ),
          ]),
          TgSection(children: [
            TgTextCell(
              title: l.worldBookEntryDelete,
              icon: Ic.trash,
              color: p.danger,
              divider: false,
              onTap: () async {
                final r = await showTgDialog<bool>(
                  c,
                  title: l.worldBookEntryDelete,
                  message: _comment.text.trim(),
                  actions: [
                    DialogAction(l.actionCancel, false),
                    DialogAction(l.actionDelete, true, danger: true),
                  ],
                );
                if (r != true) return;
                await Store.of(c).worldBooks.removeEntry(widget.bookId, _draft.id);
                if (c.mounted) Navigator.of(c).pop();
              },
            ),
          ]),
        ],
      ),
    );
  }
}

/// The chip list a key entry is typed into, one row per key family.
class _KeysField extends StatelessWidget {
  const _KeysField({required this.title, required this.hint, required this.keys, required this.onChange});

  final String title;
  final String hint;
  final List<String> keys;
  final ValueChanged<List<String>> onChange;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final p = context.p;
    return TgSection(
      header: title,
      footer: hint,
      children: [
        if (keys.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(21, 8, 21, 8),
            child: Text(l.worldBookKeysNone, style: TextStyle(color: p.subtitle, fontSize: 14, decoration: TextDecoration.none)),
          ),
        if (keys.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < keys.length; i++)
                  Tap(
                    scale: .95,
                    onTap: () {
                      final next = [...keys]..removeAt(i);
                      onChange(next);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: p.accent.withAlpha(30),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: p.accent, width: .8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(keys[i], style: TextStyle(color: p.accent, fontSize: 14, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
                        const SizedBox(width: 6),
                        TgIcon(Ic.close, color: p.accent, size: 14, stroke: 2),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        TgTextCell(
          title: l.worldBookKeyAdd,
          icon: Ic.plus,
          divider: false,
          onTap: () async {
            final v = await hAsk(context, title, title);
            if (v == null) return;
            final parts = v.split(RegExp('[,,、]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
            if (parts.isEmpty) return;
            onChange([...keys, ...parts]);
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- sandbox

/// What a conversation would pull in, without waiting for a reply.
///
/// The world book is invisible by nature: an entry either fires or it does
/// not, and a user who cannot see which is debugging a black box. Pasting a
/// few lines of a real conversation is the fastest way to find out that a
/// key was misspelled, that a probability never rolls, or that a whole book
/// is fighting for a budget that is too small.
class WorldSandboxPage extends StatefulWidget {
  const WorldSandboxPage({super.key, required this.bookId});
  final String bookId;

  @override
  State<WorldSandboxPage> createState() => _WorldSandboxState();
}

class _WorldSandboxState extends State<WorldSandboxPage> {
  final TextEditingController _input = TextEditingController();
  WorldEval? _eval;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _run() {
    final st = Store.of(context).worldBooks;
    final book = st.byId(widget.bookId);
    if (book == null) return;
    final messages = _input.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    setState(() {
      _eval = WorldInjector.evaluate(
        [book],
        recentMessages: messages,
        budgetChars: st.budgetChars,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final p = context.p;
    final eval = _eval;
    return TgSettingsPage(
      title: l.worldBookSandbox,
      builder: (c, _) => ListView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          TgSection(header: l.worldBookSandboxHeader, footer: l.worldBookSandboxFooter, children: [
            TgEditCell(
              controller: _input,
              hint: l.worldBookSandboxHint,
              lines: 10,
              max: 20000,
              label: l.worldBookSandboxInput,
            ),
            TgTextCell(
              title: l.worldBookSandboxRun,
              icon: Ic.eye,
              divider: false,
              onTap: _run,
            ),
          ]),
          if (eval != null) ...[
            if (eval.context.isEmpty)
              TgSection(children: [TgTextCell(title: l.worldBookSandboxNone, divider: false)]),
            for (final slot in EntryPosition.values)
              if (eval.context.of(slot).isNotEmpty)
                TgSection(
                  header: '${wbPositionLabel(l, slot)} · ${l.worldBookEntries(eval.context.of(slot).length)}',
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(21, 12, 21, 12),
                      child: Text(
                        worldBlock(eval.context.of(slot)),
                        style: TextStyle(color: p.title, fontSize: 13, height: 1.35, decoration: TextDecoration.none),
                      ),
                    ),
                  ],
                ),
            if (eval.dropped.isNotEmpty)
              TgSection(
                header: l.worldBookSandboxDropped,
                footer: l.worldBookBudgetFooter,
                children: [
                  for (final h in eval.dropped)
                    TgTextCell(
                      title: h.entry.comment.trim().isEmpty ? l.worldBookEntryUntitled : h.entry.comment.trim(),
                      subtitle: h.book.name,
                      icon: Ic.close,
                      divider: false,
                    ),
                ],
              ),
            TgSection(children: [
              TgTextCell(
                title: l.worldBookSandboxSpent,
                subtitle: l.worldBookSandboxRecursion(eval.recursionPasses),
                value: '${eval.spent}',
                icon: Ic.info,
                divider: false,
              ),
            ]),
          ],
        ],
      ),
    );
  }
}
