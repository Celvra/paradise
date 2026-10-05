part of 'store.dart';

/// Reads and writes the whole account as one document.
///
/// This is the layer that knows about a [Store]. The format itself lives in
/// `backup.dart` and is pure, so what a file contains can be tested without a
/// database or a device, and what a restore does can be tested without a store.
///
/// A part rather than an extension because an extension cannot reach the store's
/// own fields: the ai config, the save debounce and notifyListeners are all
/// private, and every one of them is needed to finish a restore cleanly.
///
/// A part rather than a plain import because the extension only sees the store's
/// privates from inside the same library, the same trick store_human.dart uses.
extension BackupStore on Store {
  /// The document to hand the user. Never contains an API key.
  String exportBackupString() => buildBackup(
        chats: chats.map((c) => c.toJson()).toList(),
        personas: personas.map((p) => p.toJson()).toList(),
        stickers: human == null ? null : jsonDecode(human!.exportStickers()) as Map<String, dynamic>,
        memory: human == null ? null : jsonDecode(human!.exportMemory()) as Map<String, dynamic>,
        settings: exportSettings(),
        ai: _ai?.settings.toJson(),
      );

  /// The preferences worth carrying to another phone.
  ///
  /// Not a dump of SharedPreferences: that would carry the API keys and the
  /// per chat compaction checkpoints, and a user who reads the file should not
  /// be holding credentials.
  Map<String, dynamic> exportSettings() => {
        'dark': dark,
        'textSize': textSize,
        'bubbleRadius': bubbleRadius,
        'haptics': haptics,
        'countMuted': countMuted,
        'showThinking': showThinking,
        'agentMode': agentMode,
        'agentMaxPass': agentMaxPass,
        'userBio': userBio,
        'locale': localeTag,
        'wallpaperPath': wallpaperPath,
        'wallpaperBlur': wallpaperBlur,
        'wallpaperBubbleGrad': wallpaperBubbleGrad,
        'wallpaperColor': wallpaperColor,
      };

  /// Applies a file.
  ///
  /// Every section is independent and every record is applied on its own, so one
  /// unreadable conversation cannot cost the rest of the backup. That is the
  /// failure this whole change exists to remove: the loader this replaces
  /// wrapped the entire chat list in one try and cleared it on any error.
  BackupReport importBackupString(String raw, {required bool overwrite}) {
    final doc = parseBackup(raw);
    final report = BackupReport();

    final picked = selectChats(doc, chats.map((c) => c.id), overwrite: overwrite);
    report.warnings.addAll(picked.skipped);
    for (final j in picked.take) {
      try {
        final c = Chat.fromJson(j);
        final at = chats.indexWhere((e) => e.id == c.id);
        if (at >= 0) {
          // the old one keeps its listener, the replacement needs its own or
          // later edits to it would never be saved
          _unlisten(chats[at]);
          chats[at] = c;
        } else {
          chats.add(c);
        }
        // createChat does the same, and a chat without it changes without ever
        // reaching storage
        _listen(c);
        report.chats++;
        report.messages += c.msgs.length;
      } catch (e) {
        report.warnings.add('chat ${j['id']}, could not be read');
      }
    }

    for (final j in doc.personas) {
      try {
        final p = UserPersona.fromJson(j);
        if (p.id.isEmpty) continue;
        final at = personas.indexWhere((e) => e.id == p.id);
        if (at >= 0 && !overwrite) continue;
        if (at >= 0) {
          personas[at] = p;
        } else {
          personas.add(p);
        }
        report.personas++;
      } catch (_) {
        report.warnings.add('a persona card, could not be read');
      }
    }

    // The sticker and memory sections are the existing envelopes verbatim, so
    // they go back through the existing importers and a section that is not
    // ours still fails the same way it always has.
    final h = human;
    if (h != null) {
      if (doc.stickers != null) {
        try {
          report.stickers = h.importStickers(jsonEncode(doc.stickers), overwrite: overwrite);
        } on FormatException catch (e) {
          report.warnings.add(e.message);
        }
      }
      if (doc.memory != null) {
        try {
          report.memories = h.importMemory(jsonEncode(doc.memory), overwrite: overwrite);
        } on FormatException catch (e) {
          report.warnings.add(e.message);
        }
      }
    }

    report.settings = _applySettings(doc.settings);

    final ai = _ai;
    if (ai != null && doc.ai != null) {
      try {
        // providers and the chain come back; their secrets do not, so a restored
        // provider is present but unconfigured until a key is entered
        ai.update((_) => sanitizeAiSettings(doc.ai!));
        report.ai = true;
      } catch (_) {
        report.warnings.add('the model configuration, could not be read');
      }
    }

    chatsChanged();
    return report;
  }

  int _applySettings(Map<String, dynamic> s) {
    var n = 0;
    void put<T>(String key, T value, void Function(T) apply) {
      final v = s[key];
      if (v is T) {
        apply(v);
        n++;
      }
    }

    put('dark', dark, setDark);
    put('textSize', textSize, setTextSize);
    put('bubbleRadius', bubbleRadius, setRadius);
    put('haptics', haptics, setHaptics);
    put('countMuted', countMuted, setCountMuted);
    put('showThinking', showThinking, setShowThinking);
    put('agentMode', agentMode, setAgentMode);
    put('agentMaxPass', agentMaxPass, setAgentMaxPass);
    put('userBio', userBio, (v) => setProfile(bio: v));
    put('locale', localeTag ?? '', (v) => setLocale(v.isEmpty ? null : v));
    put('wallpaperPath', wallpaperPath, setWallpaper);
    put('wallpaperBlur', wallpaperBlur, setWallpaperBlur);
    put('wallpaperBubbleGrad', wallpaperBubbleGrad, setWallpaperBubbleGrad);
    // deliberately not setWallpaperColor: that reads as an int and also pushes
    // into the palette, which the caller does once at the end instead
    final wc = s['wallpaperColor'];
    if (wc is int) {
      setWallpaperColor(wc == 0 ? null : wc);
      n++;
    }
    return n;
  }
}