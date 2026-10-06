import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'human_models.dart';

// The user owned sticker library. Entries come from three places: the built in
// seed, the user (settings page, GIF tab) and the assistant (save_sticker). The
// assistant picks from it by emotion and context, never at random.

enum StickerKind { emoji, image, gif }

class UserSticker {
  UserSticker({
    required this.id,
    required this.kind,
    required this.value,
    this.name = '',
    List<String>? tags,
    this.emotion = '',
    this.category = 'General',
    this.favorite = false,
    this.uses = 0,
    this.lastUsed = 0,
    int? createdAt,
    this.source = 'user',
    this.thumb = '',
  })  : tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  final String id;
  StickerKind kind;

  /// the glyph for emoji, a file path or an https url for image and gif
  String value;
  String name;
  List<String> tags;

  /// one word mood such as "笑死", "无语", "敷衍"
  String emotion;
  String category;
  bool favorite;
  int uses;
  int lastUsed;
  final int createdAt;

  /// 'seed', 'user' or 'ai'
  String source;

  /// Small still preview of a local image sticker, written next to the
  /// library copy. Empty for emoji, remote urls and anything saved before
  /// thumbs existed, all of which simply render from [value] like before.
  String thumb;

  bool get isRemote => value.startsWith('http');

  String get label => name.isNotEmpty ? name : (tags.isNotEmpty ? tags.first : id);

  bool matches(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return true;
    return name.toLowerCase().contains(s) || emotion.toLowerCase().contains(s) || category.toLowerCase().contains(s) || tags.any((t) => t.toLowerCase().contains(s));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'value': value,
        'name': name,
        'tags': tags,
        'emotion': emotion,
        'category': category,
        'favorite': favorite,
        'uses': uses,
        'lastUsed': lastUsed,
        'createdAt': createdAt,
        'source': source,
        if (thumb.isNotEmpty) 'thumb': thumb,
      };

  factory UserSticker.fromJson(Map<String, dynamic> j) => UserSticker(
        id: j['id'] as String,
        kind: StickerKind.values.firstWhere((e) => e.name == j['kind'], orElse: () => StickerKind.emoji),
        value: j['value'] as String? ?? '',
        name: j['name'] as String? ?? '',
        tags: [for (final e in (j['tags'] as List? ?? const [])) '$e'],
        emotion: j['emotion'] as String? ?? '',
        category: j['category'] as String? ?? 'General',
        favorite: j['favorite'] as bool? ?? false,
        uses: (j['uses'] as num?)?.toInt() ?? 0,
        lastUsed: (j['lastUsed'] as num?)?.toInt() ?? 0,
        createdAt: (j['createdAt'] as num?)?.toInt(),
        source: j['source'] as String? ?? 'user',
        thumb: j['thumb'] as String? ?? '',
      );
}

/// Nothing is seeded any more. The library starts empty, the emoji tab covers
/// the plain glyphs and the assistant only sends what the user or the
/// save_sticker tool put here. Entries a previous build seeded stay in the
/// library, the user can clear them from the settings page in one go.
const String kStickerLibEmptyNote = 'The library is empty, the user has not added a sticker yet.';

class StickerLib {
  final List<UserSticker> items = [];
  final List<String> extraCategories = [];
  var _seq = 0;

  String newId() => 'stk_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${_seq++}';

  void removeAll(Iterable<String> ids) {
    final set = ids.toSet();
    items.removeWhere((s) => set.contains(s.id));
  }

  void setFavorite(Iterable<String> ids, bool on) {
    for (final id in ids) {
      byId(id)?.favorite = on;
    }
  }

  /// Moves stickers into one category, an empty name puts them back to General.
  void moveTo(Iterable<String> ids, String category) {
    final name = category.trim().isEmpty ? 'General' : category.trim();
    for (final id in ids) {
      byId(id)?.category = name;
    }
    if (!extraCategories.contains(name)) extraCategories.add(name);
  }

  List<String> get categories {
    final s = <String>{...extraCategories, for (final i in items) i.category};
    return s.toList()..sort();
  }

  UserSticker? byId(String id) => items.where((s) => s.id == id).firstOrNull;

  UserSticker add({required StickerKind kind, required String value, String name = '', List<String>? tags, String emotion = '', String category = 'General', String source = 'user', String thumb = ''}) {
    // the same image saved twice only merges the tags
    final dup = items.where((s) => s.value == value).firstOrNull;
    if (dup != null) {
      for (final t in tags ?? const <String>[]) {
        if (!dup.tags.contains(t)) dup.tags.add(t);
      }
      if (emotion.isNotEmpty) dup.emotion = emotion;
      return dup;
    }
    final s = UserSticker(id: newId(), kind: kind, value: value, name: name, tags: tags, emotion: emotion, category: category, source: source, thumb: thumb);
    items.add(s);
    return s;
  }

  void remove(String id) => items.removeWhere((s) => s.id == id);

  void markUsed(String id, {int? now}) {
    final s = byId(id);
    if (s == null) return;
    s.uses++;
    s.lastUsed = now ?? DateTime.now().millisecondsSinceEpoch;
  }

  List<UserSticker> search(String q, {String? category, bool favorites = false, StickerKind? kind}) => [
        for (final s in items)
          if (s.matches(q) && (category == null || s.category == category) && (!favorites || s.favorite) && (kind == null || s.kind == kind)) s,
      ];

  List<UserSticker> recent({int limit = 24}) {
    final l = items.where((s) => s.lastUsed > 0).toList()..sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
    return l.take(limit).toList();
  }

  /// The catalogue shown to the model, id plus emotion plus tags, favourites
  /// and often used first so the list stays short. [prio] ids are the
  /// stickers this conversation actually used recently: they win the cut so
  /// a sticker the model sees in the history keeps its meaning available
  /// instead of falling off a long library
  String catalogue({int limit = 40, Set<String>? prio}) {
    final l = [...items]..sort((a, b) => ((prio?.contains(b.id) ?? false ? 1000 : 0) + (b.favorite ? 5 : 0) + b.uses).compareTo((prio?.contains(a.id) ?? false ? 1000 : 0) + (a.favorite ? 5 : 0) + a.uses));
    return l.take(limit).map((s) => '${s.id} [${s.emotion.isEmpty ? '-' : s.emotion}] ${s.tags.take(4).join('/')}${s.kind == StickerKind.emoji ? ' ${s.value}' : ' (${s.kind.name})'}').join('\n');
  }

  /// Chooses a sticker for a mood word or free text. The score is tag and
  /// emotion overlap, a little favour for favourites, a penalty for what was
  /// just used so the same one is not sent twice in a row. The pick among the
  /// top three is random (seeded) so it is not mechanical either.
  UserSticker? pick(String hint, {required double mood, required HumanRandom rng, int? now}) {
    if (items.isEmpty) return null;
    final t = now ?? DateTime.now().millisecondsSinceEpoch;
    final words = hint.toLowerCase().split(RegExp(r'[\s,，、/]+')).where((w) => w.isNotEmpty).toList();
    final scored = <(UserSticker, double)>[];
    for (final s in items) {
      var score = 0.0;
      for (final w in words) {
        if (s.emotion.toLowerCase() == w) score += 3;
        if (s.emotion.toLowerCase().contains(w) || w.contains(s.emotion.toLowerCase()) && s.emotion.isNotEmpty) score += 1.5;
        if (s.tags.any((tag) => tag.toLowerCase() == w)) score += 2;
        if (s.tags.any((tag) => tag.toLowerCase().contains(w) || (w.length > 1 && w.contains(tag.toLowerCase())))) score += 1;
        if (s.name.toLowerCase().contains(w)) score += 1;
      }
      if (words.isEmpty) score += 0.5;
      if (s.favorite) score += 0.4;
      // good mood leans to the cheerful ones, a low mood to the quiet ones
      final cheerful = const {'笑死', '开心', '喜欢', '比心', '坏笑'}.contains(s.emotion);
      final quiet = const {'无语', '敷衍', '委屈', '困'}.contains(s.emotion);
      if (mood >= 65 && cheerful) score += 0.4;
      if (mood <= 40 && quiet) score += 0.4;
      if (t - s.lastUsed < 60000 && s.lastUsed > 0) score -= 2;
      scored.add((s, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final top = scored.take(3).where((e) => e.$2 > 0 || words.isEmpty).toList();
    if (top.isEmpty) return null;
    return top[min(top.length - 1, (rng.next() * top.length).floor())].$1;
  }

  List<Map<String, dynamic>> toJson() => [for (final s in items) s.toJson()];

  void importJson(List<dynamic> raw, {required bool overwrite}) {
    if (overwrite) items.clear();
    final have = items.map((e) => e.id).toSet();
    for (final e in raw) {
      final s = UserSticker.fromJson(Map<String, dynamic>.from(e as Map));
      if (!have.contains(s.id)) items.add(s);
    }
  }
}

/// Writes a small still preview of a local image file to [outPath]. Animated
/// gifs freeze on their first frame. Returns null when the codec cannot read
/// the file (HEIC on some devices): callers then keep the sticker without a
/// thumb, which every render path already falls back for.
Future<String?> makeStickerThumb(String srcPath, String outPath, {int maxSide = 320}) async {
  try {
    final bytes = await File(srcPath).readAsBytes();
    final codec = await instantiateImageCodec(Uint8List.fromList(bytes));
    final frame = await codec.getNextFrame();
    final img = frame.image;
    final longest = max(img.width, img.height);
    ByteData? data;
    if (longest <= maxSide) {
      data = await img.toByteData(format: ImageByteFormat.png);
    } else {
      final scale = maxSide / longest;
      final w = max(1, (img.width * scale).round());
      final h = max(1, (img.height * scale).round());
      final rec = PictureRecorder();
      final cv = Canvas(rec);
      cv.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        Paint()..filterQuality = FilterQuality.medium,
      );
      final pic = rec.endRecording();
      data = await (await pic.toImage(w, h)).toByteData(format: ImageByteFormat.png);
    }
    if (data == null) return null;
    final f = File(outPath);
    await f.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return f.path;
  } catch (_) {
    return null;
  }
}
