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
  // ---------------------------------------------------------- auto backup

  void _loadAutoBackup() {
    final sp = _sp;
    autoBackup
      ..mode = sp.getString('autoBackup.mode') ?? 'change'
      ..intervalMin = sp.getInt('autoBackup.intervalMin') ?? 720
      ..windowStart = sp.getInt('autoBackup.windowStart') ?? 180
      ..windowEnd = sp.getInt('autoBackup.windowEnd') ?? 300
      ..lastAt = sp.getInt('autoBackup.lastAt') ?? 0
      ..lastHash = sp.getInt('autoBackup.lastHash') ?? 0;
  }

  /// Persists the policy; turning a mode on kicks an immediate write so the
  /// switch never sits on an empty promise.
  Future<void> setAutoBackup({String? mode, int? intervalMin, int? windowStart, int? windowEnd}) async {
    final ab = autoBackup;
    if (mode != null) ab.mode = mode;
    if (intervalMin != null) ab.intervalMin = intervalMin;
    if (windowStart != null) ab.windowStart = windowStart;
    if (windowEnd != null) ab.windowEnd = windowEnd;
    final sp = _sp;
    await sp.setString('autoBackup.mode', ab.mode);
    await sp.setInt('autoBackup.intervalMin', ab.intervalMin);
    await sp.setInt('autoBackup.windowStart', ab.windowStart);
    await sp.setInt('autoBackup.windowEnd', ab.windowEnd);
    if (ab.enabled) await backupNow();
    bump();
  }

  /// A cheap content fingerprint: ids, message counts and last message times
  /// catch new and edited messages without paying for a full export first.
  int _backupFingerprint() {
    var h = 17;
    for (final c in chats) {
      h = (h * 31 + c.id.hashCode) & 0x7fffffff;
      h = (h * 31 + c.msgs.length) & 0x7fffffff;
      h = (h * 31 + (c.msgs.isEmpty ? 0 : c.msgs.last.time)) & 0x7fffffff;
    }
    h = (h * 31 + personas.length) & 0x7fffffff;
    return h;
  }

  Future<void> _autoBackupTick() async {
    if (_backupRunning) return;
    final ab = autoBackup;
    final sink = _backupSink;
    if (!ab.enabled || sink == null) return;
    final now = DateTime.now();
    final fp = _backupFingerprint();
    final changed = _backupDirty || fp != ab.lastHash;
    if (!ab.shouldRun(now, dataChanged: changed)) return;
    _backupRunning = true;
    _backupDirty = false;
    try {
      final json = await exportBackupString();
      await sink.write(json);
      ab.noteSuccess(now, fp);
      await _sp.setInt('autoBackup.lastAt', ab.lastAt);
      await _sp.setInt('autoBackup.lastHash', ab.lastHash);
      bump();
      // the curated document and the full snapshot share one schedule: same
      // policy, same overwrite rule, one dirty mark. the zip gets its own
      // guard so a failure there never rewrites the json backup's bookkeeping
      try {
        await _writeFullBackup();
      } catch (_) {}
    } catch (_) {
      // a failed backup must never surface as an app error; the next tick
      // retries, and the change mode keeps the dirty mark via the fingerprint
    } finally {
      _backupRunning = false;
    }
  }

  /// Rebuilds the whole data directory snapshot and overwrites the shared
  /// copy. Runs right after the JSON write inside the same guard so the two
  /// artifacts can never disagree about which schedule they follow.
  Future<void> _writeFullBackup() async {
    final sink = _fullSink;
    if (sink == null) return;
    final bytes = await FullBackup.build();
    await sink.write(bytes);
  }

  /// The full zip backup a reinstall can offer. Null when none exists.
  Future<Uint8List?> readFullBackup() async {
    final sink = _fullSink;
    if (sink == null) return null;
    try {
      final raw = await sink.read();
      return raw == null || raw.isEmpty ? null : raw;
    } catch (_) {
      return null;
    }
  }

  /// Whether a full zip backup file exists at all, readable or not.
  Future<bool> hasFullBackupFile() async {
    final sink = _fullSink;
    if (sink == null) return false;
    try {
      return await sink.exists();
    } catch (_) {
      return false;
    }
  }

  /// Forces a write immediately, whatever the schedule says.
  Future<void> backupNow() async {
    _backupDirty = true;
    autoBackup.lastAt = 0;
    await _autoBackupTick();
  }

  /// The backup an onboarding restore can offer. Null when none exists.
  Future<String?> readAutoBackup() async {
    final sink = _backupSink;
    if (sink == null) return null;
    try {
      final raw = await sink.read();
      return raw == null || raw.isEmpty ? null : raw;
    } catch (_) {
      return null;
    }
  }

  /// Whether a backup file exists at all, even one this fresh install cannot
  /// read directly. Drives the manual-pick offer in onboarding.
  Future<bool> hasAutoBackupFile() async {
    final sink = _backupSink;
    if (sink == null) return false;
    try {
      return await sink.exists();
    } catch (_) {
      return false;
    }
  }

  /// Test seam: point the auto backup at a directory sink so a tick can be
  /// verified end to end without the MediaStore channel.
  @visibleForTesting
  set debugBackupSink(BackupSink? sink) => _backupSink = sink;

  /// Test seam for the full zip backup, same idea as [debugBackupSink].
  @visibleForTesting
  set debugFullBackupSink(FullBackupSink? sink) => _fullSink = sink;

  /// The document to hand the user. Carries the provider keys in `secrets`:
  /// a backup whose restore leaves every provider unconfigured is no backup.
  Future<String> exportBackupString() async => buildBackup(
        chats: chats.map((c) => c.toJson()).toList(),
        personas: personas.map((p) => p.toJson()).toList(),
        stickers: human == null ? null : jsonDecode(human!.exportStickers()) as Map<String, dynamic>,
        memory: human == null ? null : jsonDecode(human!.exportMemory()) as Map<String, dynamic>,
        settings: exportSettings(),
        ai: _ai?.settings.toJson(),
        images: await _backupImages(),
        human: human == null
            ? null
            : {
                'settings': human!.settings.toJson(),
                'wallet': human!.wallet.toJson(),
                'tasks': human!.scheduler.toJson(),
              },
        secrets: _ai?.apiKeys.isEmpty == false ? Map<String, dynamic>.of(_ai!.apiKeys) : null,
      );

  /// One entry per local image a persona avatar or a sticker points at.
  /// Anything unreadable or unreasonably large is skipped rather than failing
  /// the whole backup: a restore without one avatar still beats no backup.
  Future<Map<String, dynamic>> _backupImages() async {
    final paths = <String>{};
    for (final p in personas) {
      if (p.avatarPath.isNotEmpty && !p.avatarPath.startsWith('http')) paths.add(p.avatarPath);
    }
    final h = human;
    if (h != null) {
      for (final s in h.stickers.items) {
        if (!s.isRemote) {
          if (s.value.isNotEmpty) paths.add(s.value);
          if (s.thumb.isNotEmpty) paths.add(s.thumb);
        }
      }
    }
    final out = <String, dynamic>{};
    for (final path in paths) {
      try {
        final f = File(path);
        if (!await f.exists()) continue;
        final len = await f.length();
        if (len > 4 * 1024 * 1024) continue;
        out[path] = {'b64': base64Encode(await f.readAsBytes()), 'name': p.basename(path)};
      } catch (_) {
        // one bad file must not cost the rest of the backup
      }
    }
    return out;
  }

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
  ///
  /// Local images come back first: every reference in the document points at
  /// the path the old install used, so the bytes land under the same relative
  /// spot of this install's documents directory and the maps are rewritten
  /// before a single object is built.
  Future<BackupReport> importBackupString(String raw, {required bool overwrite}) async {
    final doc = parseBackup(raw);
    final report = BackupReport();

    final remap = await _restoreImages(doc.images, report);

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
        _remapRef(j, 'avatarPath', remap);
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
          final env = jsonDecode(jsonEncode(doc.stickers)) as Map<String, dynamic>;
          final items = (env['items'] as List?) ?? const [];
          for (final e in items) {
            if (e is! Map) continue;
            _remapRef(e, 'value', remap);
            _remapRef(e, 'thumb', remap);
          }
          report.stickers = h.importStickers(jsonEncode(env), overwrite: overwrite);
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

      final hm = doc.human;
      if (hm != null) {
        try {
          final sj = hm['settings'];
          if (sj is Map) h.settings = HumanSettings.fromJson(Map<String, dynamic>.from(sj));
          final wj = hm['wallet'];
          if (wj is Map) h.wallet.loadJson(Map<String, dynamic>.from(wj));
          final tj = hm['tasks'];
          if (tj is List) h.scheduler.loadJson(tj);
          h.changed();
          report.human = true;
        } catch (_) {
          report.warnings.add('the humanize settings, could not be read');
        }
      }
    }

    report.settings = _applySettings(doc.settings);

    final ai = _ai;
    if (ai != null) {
      if (doc.ai != null) {
        try {
          // providers and the chain come back together with the secrets below,
          // so a restored provider is working, not just present
          ai.update((_) => sanitizeAiSettings(doc.ai!));
          report.ai = true;
        } catch (_) {
          report.warnings.add('the model configuration, could not be read');
        }
      }
      final secrets = doc.secrets;
      if (secrets != null) {
        for (final e in secrets.entries) {
          final v = e.value;
          if (v is String && v.isNotEmpty) {
            ai.saveApiKey(e.key, v);
            report.secrets++;
          }
        }
      }
    }

    chatsChanged();
    return report;
  }

  /// Writes every embedded image into this install's documents directory and
  /// returns the old path -> new path map. Entries that fail to write keep
  /// their old path in the map untouched, which leaves the reference broken
  /// the way it already was, not half rewritten.
  Future<Map<String, String>> _restoreImages(Map<String, dynamic>? images, BackupReport report) async {
    if (images == null || images.isEmpty) return const {};
    final base = await getApplicationDocumentsDirectory();
    final remap = <String, String>{};
    for (final e in images.entries) {
      try {
        final v = e.value;
        if (v is! Map) continue;
        final b64 = v['b64'];
        if (b64 is! String || b64.isEmpty) continue;
        final name = (v['name'] as String?)?.isNotEmpty == true ? v['name'] as String : 'img_${remap.length}.bin';
        // keep the old subdir (avatars/, stickers/...) when it is visible in
        // the path, so restored files sit where the app expects its own art
        final old = e.key.replaceAll('\\', '/');
        final marker = '/documents/';
        final rel = old.contains(marker) ? old.substring(old.indexOf(marker) + marker.length) : 'restored/$name';
        final f = File('${base.path}/$rel');
        final d = f.parent;
        if (!await d.exists()) await d.create(recursive: true);
        await f.writeAsBytes(base64Decode(b64), flush: true);
        remap[e.key] = f.path;
        report.images++;
      } catch (_) {
        report.warnings.add('an embedded image, could not be written');
      }
    }
    return remap;
  }

  static void _remapRef(Map<dynamic, dynamic> json, String key, Map<String, String> remap) {
    final v = json[key];
    if (v is String && remap.containsKey(v)) json[key] = remap[v];
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